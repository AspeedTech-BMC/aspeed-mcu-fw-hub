# Copyright (c) 2026 ASPEED Technology Inc.
# SPDX-License-Identifier: MIT

ZEPHYR_SDK_VER="0.16.9"

# West workspace manifest repo — initialized via "west init" instead of plain
# git clone, so it is not included in REPOS and cannot use _clone_repo.
ASPEED_ZEPHYR_PROJECT_REMOTE="https://github.com/AspeedTech-BMC/aspeed-zephyr-project.git"
ASPEED_ZEPHYR_PROJECT_BRANCH="aspeed-master"
ASPEED_ZEPHYR_PROJECT_COMMIT=""

REPOS=("caliptra-mcu-sw" "cptra_imgtool" "bmc-pb")

CALIPTRA_MCU_SW_REMOTE="https://github.com/AspeedTech-BMC/caliptra-mcu-sw.git"
CALIPTRA_MCU_SW_BRANCH="aspeed-main-2.1-rt"
CALIPTRA_MCU_SW_COMMIT=""

CPTRA_IMGTOOL_REMOTE="https://github.com/AspeedTech-BMC/cptra_imgtool.git"
CPTRA_IMGTOOL_BRANCH="master"
CPTRA_IMGTOOL_COMMIT=""

BMC_PB_REMOTE="https://github.com/AspeedTech-BMC/bmc-pb.git"
BMC_PB_BRANCH="master"
BMC_PB_COMMIT=""
