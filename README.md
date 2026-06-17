# ASPEED MCU Firmware Build System

Bazel-based firmware build system for ASPEED MCU platforms.
All tools and source repos are self-contained under this directory.

## Directory Structure

```
aspeed-mcu-fw-hub/
├── MODULE.bazel         # External repo declarations (Bzlmod)
├── BUILD.bazel          # Root (empty)
├── setup.sh             # One-time environment setup
├── setup-github.sh      # Shortcut for external users: setup using GitHub repos
├── repos_github.sh      # Source repo list for GitHub
├── repos_gerrit.sh      # Source repo list for Gerrit (ASPEED internal)
├── clean.sh             # Clean build outputs / environment
├── flags/
│   └── BUILD.bazel      # Ad-hoc override flags
├── bazel/
│   ├── zephyr.bzl       # Rule: zephyr_west_build
│   ├── caliptra.bzl     # Macro: caliptra_targets
│   ├── bmc_pb.bzl       # Macro: bmc_pb_target
│   ├── manifest.bzl     # Macro: manifest_targets
│   └── image.bzl        # Macro: image_targets
├── ast1040/
│   └── ast1040a0/
│       ├── BUILD.bazel
│       └── evb/
│           └── BUILD.bazel
├── ast1080/
│   └── ast1080a0/
│       ├── BUILD.bazel
│       ├── evb/
│       │   └── BUILD.bazel
│       └── dcscm/
│           └── BUILD.bazel
├── caliptra-mcu-sw/     # Cloned by setup.sh
├── cptra_imgtool/       # Cloned by setup.sh
├── bmc-pb/              # Cloned by setup.sh
├── zephyr-workspace/    # west init + west update
├── zephyr-sdk-*/        # Zephyr SDK (downloaded by setup.sh)
├── tools/bazel          # Bazelisk (downloaded by setup.sh)
├── .venv/               # Python venv (west)
├── .cargo/              # Rust/Cargo
├── .rustup/             # Rustup
└── .stage/              # Temporary staging dir (auto-created, gitignored)
```

## First-Time Setup

Source repos are hosted on both GitHub (for external users) and Gerrit (ASPEED internal only).

### External users (GitHub)

```bash
cd aspeed-mcu-fw-hub
source ./setup-github.sh
```

### ASPEED internal (Gerrit)

```bash
cd aspeed-mcu-fw-hub
source ./setup.sh
```

Alternatively, set `REPO_SOURCE` explicitly before running `setup.sh`:

```bash
REPO_SOURCE=github source ./setup.sh   # GitHub
source ./setup.sh                      # Gerrit (default)
```

`setup.sh` steps:
1. Create Python venv + install `west`
2. Install Rust/Cargo under `.cargo/`
3. Download Bazelisk to `tools/bazel` (auto-selects Bazel 9.1.1 via `.bazelversion`)
4. Download Zephyr SDK (version defined in `repos_gerrit.sh` / `repos_github.sh`)
5. Clone `caliptra-mcu-sw`, `cptra_imgtool`, `bmc-pb`
6. `west init` + `west update` for Zephyr workspace

Re-running `setup.sh` is safe - already-done steps are skipped.

## Build

Build outputs are placed under `bazel-bin/<platform>/<chip>/<board>/`.

> **Note:** `bazel build //...` (build all targets at once) is **not supported**.
> Only one board can be built at a time, e.g. `bazel build //ast1040/ast1040a0/evb:image`.

### List all available build targets

```bash
bazel query //...
```

### AST1040 EVB

```bash
bazel build //ast1040/ast1040a0/evb:image
```

### AST1080 EVB

```bash
bazel build //ast1080/ast1080a0/evb:image
```

### AST1080 DCSCM

```bash
bazel build //ast1080/ast1080a0/dcscm:image
```

### Individual targets

| Command                                          | Description                    |
|--------------------------------------------------|--------------------------------|
| `bazel build //ast1040/ast1040a0/evb:cm4`        | Zephyr CM4 firmware            |
| `bazel build //ast1040/ast1040a0/evb:bootmcu`    | Zephyr bootmcu runtime         |
| `bazel build //ast1040/ast1040a0:ssmcu-runtime`  | Caliptra MCU runtime (Rust)    |
| `bazel build //ast1040/ast1040a0:ssmcu-rom`      | Caliptra MCU ROM (Rust)        |
| `bazel build //ast1040/ast1040a0:bmc-pb`         | Copy bmc-pb prebuilt binaries  |
| `bazel build //ast1040/ast1040a0/evb:manifest`   | Create auth flash manifest     |
| `bazel build //ast1040/ast1040a0/evb:image`      | Assemble final flash image     |

### Ad-hoc board/app override

Override the Zephyr board or app at build time without modifying BUILD files:

```bash
bazel build //ast1040/ast1040a0/evb:image \
  --//flags:cm4_zephyr_board=ast1040_evb/ast1040/cm4 \
  --//flags:cm4_zephyr_app=zephyr/samples/hello_world \
  --//flags:bootmcu_zephyr_board=ast1040_evb/ast1040/bootmcu \
  --//flags:bootmcu_zephyr_app=aspeed-zephyr-project/apps/mcu-runtime
```

## Flash Image Layout

```
Offset      Hex          File
0 KB        0x00000000   ssmcu-rom (mcu-rom-*-aspeed-xip.bin)
512 KB      0x00080000   bmc-pb XIP ROM (bootmcu ROM)
1024 KB     0x00100000   aspeed-manifest-flash-image.bin
```

Output: `bazel-bin/<platform>/<chip>/<board>/<platform>.bin` (4 MB, 0xFF-padded)

## Manual West Build

Must run from the repo root. West is installed in the local venv `.venv/zephyr/`,
not the system default, so the venv must be activated before use.

```bash
cd aspeed-mcu-fw-hub
source .venv/zephyr/bin/activate
cd zephyr-workspace
```

Example:

```bash
west build -b ast1040_evb/ast1040/cm4 -d BUILD_DIR zephyr/samples/subsys/shell/shell_module
```

Deactivate when done:

```bash
deactivate
```

## Manual Cargo Build

Must run from the repo root. Cargo and Rustup are installed locally under `.cargo/` and `.rustup/`,
not the system default, so environment variables must be set before use.

```bash
cd aspeed-mcu-fw-hub
export RUSTUP_HOME=$(pwd)/.rustup
export CARGO_HOME=$(pwd)/.cargo
source .cargo/env
```

Example:

```bash
cd caliptra-mcu-sw
cargo xtask runtime-build --platform ast1040
```

## Source Repo Configuration

Two repo config files are provided — use the one matching your access:

| File | Description |
|------|-------------|
| `repos_github.sh` | GitHub — for external users |
| `repos_gerrit.sh` | Gerrit — ASPEED internal only |

Each file defines the remote URL, branch, and optional pinned commit for each cloned repo.
Edit the appropriate file to switch branches or pin to a specific commit before running `setup.sh`.

```bash
# repos_github.sh (example)
CALIPTRA_MCU_SW_REMOTE="https://github.com/AspeedTech-BMC/caliptra-mcu-sw.git"
CALIPTRA_MCU_SW_BRANCH="master"
CALIPTRA_MCU_SW_COMMIT=""        # leave empty to use branch HEAD

CPTRA_IMGTOOL_REMOTE="https://github.com/AspeedTech-BMC/cptra_imgtool.git"
CPTRA_IMGTOOL_BRANCH="master"
CPTRA_IMGTOOL_COMMIT=""

BMC_PB_REMOTE="https://github.com/AspeedTech-BMC/bmc-pb.git"
BMC_PB_BRANCH="master"
BMC_PB_COMMIT=""
```

To pin a repo to a specific commit, set the `_COMMIT` variable:

```bash
CALIPTRA_MCU_SW_COMMIT="abc1234"
```

## Update Source Repos

```bash
# west requires the venv to be activated first
source .venv/zephyr/bin/activate
cd zephyr-workspace && west update
deactivate
cd ..
git -C caliptra-mcu-sw pull
git -C cptra_imgtool pull
git -C bmc-pb pull
```

## Clean

```bash
./clean.sh            # bazel clean --expunge (default)
./clean.sh env        # remove all downloaded tools/env; keep git clones
                      # re-run "source setup.sh" to restore
./clean.sh all        # remove everything including git clones
                      # re-run "source setup.sh" to restore
```

## Supported Platforms

| OS    | Architecture            |
|-------|-------------------------|
| Linux | x86_64                  |
| Linux | aarch64                 |
| macOS | x86_64                  |
| macOS | aarch64 (Apple Silicon) |
