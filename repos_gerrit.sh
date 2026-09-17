# Copyright (c) 2026 ASPEED Technology Inc.
# SPDX-License-Identifier: MIT

ZEPHYR_SDK_VER="0.16.9"

# West workspace manifest repo — initialized via "west init" instead of plain
# git clone, so it is not included in REPOS and cannot use _clone_repo.
ASPEED_ZEPHYR_PROJECT_REMOTE="ssh://gerrit.aspeed.com:29418/aspeed-zephyr-project"
ASPEED_ZEPHYR_PROJECT_BRANCH="aspeed-dev"
ASPEED_ZEPHYR_PROJECT_COMMIT=""

REPOS=("caliptra-mcu-sw" "cptra_imgtool" "bmc-pb")

CALIPTRA_MCU_SW_REMOTE="ssh://gerrit.aspeed.com:29418/caliptra-mcu-sw"
CALIPTRA_MCU_SW_BRANCH="aspeed-dev-2.1-rt"
CALIPTRA_MCU_SW_COMMIT=""

CPTRA_IMGTOOL_REMOTE="ssh://gerrit.aspeed.com:29418/cptra_imgtool"
CPTRA_IMGTOOL_BRANCH="develop"
CPTRA_IMGTOOL_COMMIT=""

BMC_PB_REMOTE="ssh://gerrit.aspeed.com:29418/bmc-pb"
BMC_PB_BRANCH="master"
BMC_PB_COMMIT=""
