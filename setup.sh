#!/usr/bin/env bash
# Copyright (c) 2026 ASPEED Technology Inc.
# SPDX-License-Identifier: MIT
# Safe to run as both "source ./setup.sh" and ". ./setup.sh".
# All install work runs in a subshell so set -e cannot exit the parent terminal.
# Only the PATH/env exports at the end affect the current shell when sourced.

BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

VENV="$BASE/.venv/zephyr"
CARGO_HOME="$BASE/.cargo"
RUSTUP_HOME="$BASE/.rustup"
TOOLS="$BASE/tools"

_OS=$(uname -s)
_ARCH=$(uname -m)

case "$_OS" in
    Linux)  OS_NAME="linux"  ;;
    Darwin) OS_NAME="macos"  ;;
    *)      echo "ERROR: unsupported OS: $_OS"; return 1 2>/dev/null || exit 1 ;;
esac

case "$_ARCH" in
    x86_64)         ARCH_NAME="x86_64"  ;;
    aarch64|arm64)  ARCH_NAME="aarch64" ;;
    *)              echo "ERROR: unsupported arch: $_ARCH"; return 1 2>/dev/null || exit 1 ;;
esac

# Load version config and repo definitions (used by steps below).
REPO_SOURCE="${REPO_SOURCE:-gerrit}"
echo "Repo source: $REPO_SOURCE"
source "$BASE/repos_${REPO_SOURCE}.sh"
ZEPHYR_SDK_DIR="$BASE/zephyr-sdk-${ZEPHYR_SDK_VER}"
# .bazelignore does not support wildcards, so the zephyr-sdk entry must match
# the exact version directory. Update it here to stay in sync with ZEPHYR_SDK_VER.
sed -i "s|^zephyr-sdk-.*|zephyr-sdk-${ZEPHYR_SDK_VER}|" "$BASE/.bazelignore"

(
set -e
echo "BASE = $BASE  (OS=$OS_NAME  ARCH=$ARCH_NAME)"

# [1] Python venv + west
echo "=== [1/6] Python venv ==="
VENV_FIRST_TIME=false
if [ -f "$VENV/bin/activate" ]; then
    echo "  venv already exists, skipping"
else
    python3 -m venv "$VENV" || exit 1
    source "$VENV/bin/activate"
    pip3 install --quiet --upgrade pip || exit 1
    pip3 install --quiet west || exit 1
    deactivate
    VENV_FIRST_TIME=true
fi
source "$VENV/bin/activate"
echo "  west: $(west --version)"
deactivate

# [2] Rust/Cargo (installed under .cargo + .rustup, no root required)
echo "=== [2/6] Rust ==="
export CARGO_HOME RUSTUP_HOME
if [ ! -f "$CARGO_HOME/bin/cargo" ]; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
        | sh -s -- -y --no-modify-path || exit 1
fi
source "$CARGO_HOME/env"
echo "  rustc: $(rustc --version)"
echo "  cargo: $(cargo --version)"

# [3] Bazelisk — auto-selects Bazel version from .bazelversion
echo "=== [3/6] Bazelisk ==="
mkdir -p "$TOOLS"
if [ ! -f "$TOOLS/bazel" ]; then
    case "${OS_NAME}-${ARCH_NAME}" in
        linux-x86_64)  BZLISK_BIN="bazelisk-linux-amd64"  ;;
        linux-aarch64) BZLISK_BIN="bazelisk-linux-arm64"  ;;
        macos-x86_64)  BZLISK_BIN="bazelisk-darwin-amd64" ;;
        macos-aarch64) BZLISK_BIN="bazelisk-darwin-arm64"  ;;
    esac
    curl -fsSL \
        "https://github.com/bazelbuild/bazelisk/releases/latest/download/${BZLISK_BIN}" \
        -o "$TOOLS/bazel" || exit 1
    chmod +x "$TOOLS/bazel" || exit 1
fi
echo "  bazelisk: $($TOOLS/bazel version 2>&1 | grep -i bazelisk | head -1)"

# [4] Zephyr SDK — selects the correct tarball for OS + arch
echo "=== [4/6] Zephyr SDK ==="
if [ ! -d "$ZEPHYR_SDK_DIR" ]; then
    SDK_TAR="zephyr-sdk-${ZEPHYR_SDK_VER}_${OS_NAME}-${ARCH_NAME}_minimal.tar.xz"
    SDK_URL="https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v${ZEPHYR_SDK_VER}/${SDK_TAR}"
    echo "  downloading $SDK_TAR ..."
    curl -fsSL "$SDK_URL" -o "$BASE/${SDK_TAR}" || exit 1
    tar -xf "$BASE/${SDK_TAR}" -C "$BASE" || exit 1
    rm "$BASE/${SDK_TAR}"
    "$ZEPHYR_SDK_DIR/setup.sh" -t arm-zephyr-eabi -t riscv64-zephyr-elf -h -c || exit 1
    echo "  Zephyr SDK installed: $ZEPHYR_SDK_DIR"
else
    echo "  Zephyr SDK already installed, skipping"
fi

# [5] Clone source repos (skipped if already cloned)
echo "=== [5/6] Clone source repos ==="
_clone_repo() {
    local name=$1 remote=$2 branch=$3 commit=$4
    if [ ! -d "$BASE/$name/.git" ]; then
        echo "  cloning $name @ ${commit:-$branch} ..."
        git clone "$remote" --branch "$branch" "$BASE/$name" || return 1
        if [ -n "$commit" ]; then
            git -C "$BASE/$name" checkout "$commit" || return 1
        fi
    else
        echo "  $name already cloned, skipping"
    fi
}
for name in "${REPOS[@]}"; do
    var=$(echo "$name" | tr '[:lower:]-' '[:upper:]_')
    eval "remote=\$${var}_REMOTE"
    eval "branch=\$${var}_BRANCH"
    eval "commit=\$${var}_COMMIT"
    _clone_repo "$name" "$remote" "$branch" "$commit" || exit 1
done

# [6] Zephyr west workspace
# Layout after setup:
#   zephyr-workspace/aspeed-zephyr-project/  <- manifest repo
#   zephyr-workspace/.west/
#   zephyr-workspace/zephyr/                 <- west update
#   zephyr-workspace/modules/                <- west update
#   zephyr-workspace/bootloader/             <- west update
#   zephyr-workspace/middlewares/            <- west update
echo "=== [6/6] Zephyr west workspace ==="
WEST_WS="$BASE/zephyr-workspace"
source "$VENV/bin/activate"
mkdir -p "$WEST_WS"
if [ ! -d "$WEST_WS/.west" ]; then
    cd "$WEST_WS"
    WEST_INIT_ARGS="-m $ASPEED_ZEPHYR_PROJECT_REMOTE"
    if [ -n "$ASPEED_ZEPHYR_PROJECT_BRANCH" ]; then
        WEST_INIT_ARGS="$WEST_INIT_ARGS --mr $ASPEED_ZEPHYR_PROJECT_BRANCH"
    fi
    west init $WEST_INIT_ARGS || exit 1
    if [ -n "$ASPEED_ZEPHYR_PROJECT_COMMIT" ]; then
        git -C aspeed-zephyr-project checkout "$ASPEED_ZEPHYR_PROJECT_COMMIT"
    fi
    git -C aspeed-zephyr-project submodule update --init || exit 1
    west update || exit 1
    echo "  west workspace created"
else
    cd "$WEST_WS"
    west update || exit 1
    echo "  west workspace updated"
fi

# Install Zephyr Python requirements (only after first west update or if missing)
ZEPHYR_REQS="$WEST_WS/zephyr/scripts/requirements.txt"
REQS_STAMP="$VENV/.zephyr-reqs-installed"
if [ -f "$ZEPHYR_REQS" ] && { [ "$VENV_FIRST_TIME" = true ] || [ ! -f "$REQS_STAMP" ]; }; then
    echo "  installing zephyr python requirements..."
    pip3 install --quiet -r "$ZEPHYR_REQS" || exit 1
    touch "$REQS_STAMP"
    echo "  zephyr requirements installed"
fi
deactivate

cat > "$BASE/.bazelrc.local" << RCEOF
# Auto-generated by setup.sh
build --action_env=MY_BAZEL_BASE=$BASE
build --action_env=CARGO_HOME=$CARGO_HOME
build --action_env=RUSTUP_HOME=$RUSTUP_HOME
build --action_env=ZEPHYR_TOOLCHAIN_VARIANT=zephyr
build --action_env=ZEPHYR_SDK_INSTALL_DIR=$ZEPHYR_SDK_DIR
RCEOF
echo "  .bazelrc.local written"
) || { echo ""; echo "ERROR: setup failed. See messages above."; return 1 2>/dev/null || exit 1; }

export PATH="$TOOLS:$PATH"
export CARGO_HOME="$CARGO_HOME"
export RUSTUP_HOME="$RUSTUP_HOME"
export ZEPHYR_TOOLCHAIN_VARIANT=zephyr
export ZEPHYR_SDK_INSTALL_DIR="$ZEPHYR_SDK_DIR"

echo ""
echo "=== Ready ==="
echo ""
echo "Build:"
echo "  bazel query //...                             # list all available targets"
echo "  bazel build //ast1040/ast1040a0/evb:image     # AST1040 EVB full build"
echo "  bazel build //ast1080/ast1080a0/evb:image     # AST1080 EVB full build"
echo "  bazel build //ast1080/ast1080a0/dcscm:image   # AST1080 DCSCM full build"
echo ""
echo "Pull latest changes:"
echo "  git -C caliptra-mcu-sw pull"
echo "  git -C cptra_imgtool pull"
echo "  git -C bmc-pb pull"
echo "  source .venv/zephyr/bin/activate"
echo "  cd zephyr-workspace && west update"
echo "  deactivate"
echo ""
echo "Clean:"
echo "  ./clean.sh            # bazel clean --expunge"
echo "  ./clean.sh env        # remove tools/env; keep git clones"
echo "  ./clean.sh all        # remove everything including git clones"
