#!/bin/sh
# AST1040 streaming boot + PLDM CM4 update, run on the AST2700 BMC.
#   1) OCP recovery over I3C14: caliptra-fw -> auth-manifest -> ssmcu-runtime
#   2) MCTP endpoint setup (BMC EID 9 -> AST1040 EID 10) via mctpd
#   3) PLDM firmware update via pldmd (Software.Update.StartUpdate)
set -eu

DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PLDM_PKG="${1:-$DIR/ast1040-cm4-test.pldm}"

BUS=14
RECOVERY_PID=0xfffe005a10a5
MCTP_IF=mctpi3c14
LOCAL_EID=9
TARGET_EID=10
UPDATE_TIMEOUT=600
# ssmcu-runtime needs time to boot before its MCTP endpoint is usable; probing
# too early leaves mctpd's IIDs permanently one response behind.
BOOT_WAIT="${BOOT_WAIT:-30}"

OCP="ocp-recovery-tool --i3c -b $BUS -p $RECOVERY_PID"
PLDM=xyz.openbmc_project.PLDM

step() { printf '\n==== %s\n' "$*"; }
die() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

for f in caliptra-fw_align_256.bin ast1040a0-default-auth-manifest.bin \
         ssmcu-runtime_align_256.bin; do
    [ -f "$DIR/$f" ] || die "missing $DIR/$f"
done
[ -f "$PLDM_PKG" ] || die "missing $PLDM_PKG"

step "1/3 OCP recovery: streaming 3 images over I3C$BUS"
echo 1 > /sys/bus/i3c/devices/14c2e000.i3c14/rescan 2>/dev/null || true
sleep 1
$OCP GetRecoveryStatus | grep -q "awaiting recovery image" ||
    die "AST1040 not awaiting recovery image ($OCP GetRecoveryStatus)"
$OCP PerformOCPRecovery -i \
    "$DIR/caliptra-fw_align_256.bin" \
    "$DIR/ast1040a0-default-auth-manifest.bin" \
    "$DIR/ssmcu-runtime_align_256.bin"
echo "waiting ${BOOT_WAIT}s for ssmcu-runtime to boot..."
sleep "$BOOT_WAIT"

step "2/3 MCTP: EID $LOCAL_EID -> EID $TARGET_EID on $MCTP_IF"
mctp link set $MCTP_IF up
mctp link set $MCTP_IF mtu 68           # AST1040 RX buffer: 68 + PEC
mctp addr show | grep -qw $LOCAL_EID || mctp addr add $LOCAL_EID dev $MCTP_IF
busctl call au.com.codeconstruct.MCTP1 \
    /au/com/codeconstruct/mctp1/interfaces/$MCTP_IF \
    au.com.codeconstruct.MCTP.BusOwner1 \
    SetupEndpoint ay 6 0xff 0xfe 0x00 0x5a 0x00 0xa5 ||
    die "SetupEndpoint failed (runtime not up yet? retry with BOOT_WAIT=<longer>)"
mctp neigh show | grep -qw $TARGET_EID || die "EID $TARGET_EID not configured"

step "3/3 PLDM update via pldmd: $(basename "$PLDM_PKG")"
systemctl is-active --quiet pldmd || systemctl restart pldmd
i=0
until busctl introspect $PLDM /xyz/openbmc_project/software/pldm 2>/dev/null |
      grep -q 'xyz\.openbmc_project\.Software\.Update '; do
    i=$((i + 1)); [ $i -le 30 ] || die "pldmd Software.Update object not found"
    sleep 1
done

exec 3< "$PLDM_PKG"
OBJ=$(busctl call $PLDM /xyz/openbmc_project/software/pldm \
      xyz.openbmc_project.Software.Update StartUpdate hs 3 \
      "xyz.openbmc_project.Software.ApplyTime.RequestedApplyTimes.Immediate" |
      awk '{print $2}' | tr -d '"')
exec 3<&-
[ -n "$OBJ" ] || die "StartUpdate returned no object"
echo "activation object: $OBJ"

i=0
while :; do
    ACT=$(busctl get-property $PLDM "$OBJ" \
          xyz.openbmc_project.Software.Activation Activation 2>/dev/null |
          awk '{print $2}' | tr -d '"')
    PROG=$(busctl get-property $PLDM "$OBJ" \
           xyz.openbmc_project.Software.ActivationProgress Progress 2>/dev/null |
           awk '{print $2}')
    printf '\rprogress: %s%%  %s   ' "${PROG:-?}" "${ACT##*.}"
    case "$ACT" in
        *.Active) echo; break ;;
        *.Failed|*.Invalid) echo; die "activation $ACT" ;;
    esac
    i=$((i + 1)); [ $i -le $UPDATE_TIMEOUT ] || { echo; die "timeout"; }
    sleep 1
done

printf '\nPASS: AST1040 streaming boot + PLDM CM4 update done\n'
