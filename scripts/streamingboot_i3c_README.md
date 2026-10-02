# AST1040 Streaming Boot (OCP Recovery over I3C + PLDM)

The AST2700 BMC streams the boot images to the AST1040 over I3C14, then
updates the CM4 image over PLDM.

## Requirements

- AST2700 EVB BMC with `CONFIG_I3C_OCP_RECOVERY=y` and `CONFIG_MCTP_TRANSPORT_I3C=y`
- BMC rootfs with `ocp-recovery-tool`, `mctpd`, and `pldmd`
- AST1040 powered on, waiting in the ROM for streaming boot

## Run

```sh
scp -O -r streamingboot-i3c root@<bmc>:/tmp/
ssh root@<bmc> sh /tmp/streamingboot-i3c/run_streaming_boot.sh
```

Pass a different PLDM package as the first argument if needed.
The default is `ast1040-cm4-test.pldm`.

If ssmcu-runtime needs longer to boot before MCTP setup, set `BOOT_WAIT=<sec>`
(default 30), e.g. `BOOT_WAIT=60 sh run_streaming_boot.sh`.

| Step | What runs | Expected |
|---|---|---|
| 1/3 | `ocp-recovery-tool PerformOCPRecovery` (caliptra-fw → auth-manifest → ssmcu-runtime) | `recovery successful` (~27 s) |
| 2/3 | mctpd `SetupEndpoint`, BMC EID 9 → AST1040 EID 10 | `mctp neigh` shows EID 10 |
| 3/3 | pldmd `StartUpdate` | progress reaches 100%, `Active` (~14 s) |
| Done | | `PASS` |

## Files

| File | Purpose |
|---|---|
| `run_streaming_boot.sh` | Test script (runs on the BMC) |
| `caliptra-fw_align_256.bin` | Stage 1: Caliptra FW |
| `ast1040a0-default-auth-manifest.bin` | Stage 2: auth manifest |
| `ssmcu-runtime_align_256.bin` | Stage 3: SSMCU runtime (`test-pldm-streaming-boot`) |
| `ast1040-cm4-test.pldm` | CM4 PLDM package |

All files come from one `bazel build //ast1040/ast1040a0/evb:image-streamingboot-i3c`.
The ROM checks ssmcu-runtime against the auth-manifest, and the CM4 image in the
`.pldm` against the same manifest, so do not mix files from different builds.

## Run manually (without the script)

Run on the BMC, from `/tmp/streamingboot-i3c`.

**1. OCP recovery: stream 3 images over I3C14**

```sh
T="ocp-recovery-tool --i3c -b 14 -p 0xfffe005a10a5"
$T GetDeviceStatus       # 0x03 recovery mode - ready to accept recovery image
$T GetRecoveryStatus     # 0x01 awaiting recovery image

$T PerformOCPRecovery -i caliptra-fw_align_256.bin \
                         ast1040a0-default-auth-manifest.bin \
                         ssmcu-runtime_align_256.bin
# -> recovery successful

$T GetRecoveryStatus     # 0x03 recovery successful
```

**2. MCTP: BMC EID 9 -> AST1040 EID 10** (wait ~30 s after step 1 for ssmcu-runtime to boot)

```sh
mctp link set mctpi3c14 up
mctp link set mctpi3c14 mtu 68
mctp addr add 9 dev mctpi3c14
busctl call au.com.codeconstruct.MCTP1 \
    /au/com/codeconstruct/mctp1/interfaces/mctpi3c14 \
    au.com.codeconstruct.MCTP.BusOwner1 \
    SetupEndpoint ay 6 0xff 0xfe 0x00 0x5a 0x00 0xa5
mctp neigh               # eid 10 ... lladdr ff:fe:00:5a:00:a5
```

**3. PLDM update via pldmd**

```sh
systemctl start pldmd

exec 3< ast1040-cm4-test.pldm
busctl call xyz.openbmc_project.PLDM /xyz/openbmc_project/software/pldm \
    xyz.openbmc_project.Software.Update \
    StartUpdate hs 3 "xyz.openbmc_project.Software.ApplyTime.RequestedApplyTimes.Immediate"
exec 3<&-
# prints: o "/xyz/openbmc_project/software/<OBJ>"

busctl get-property xyz.openbmc_project.PLDM /xyz/openbmc_project/software/<OBJ> \
    xyz.openbmc_project.Software.ActivationProgress Progress
busctl get-property xyz.openbmc_project.PLDM /xyz/openbmc_project/software/<OBJ> \
    xyz.openbmc_project.Software.Activation Activation    # ...Activations.Active
```

## Troubleshooting

| Symptom | Fix |
|---|---|
| `not awaiting recovery image` | AST1040 is already booted or not in the ROM. Power-cycle the AST1040. |
| No `/sys/bus/i3c/devices/14-fffe005a10a5/ocp_recovery` | `echo 14-fffe005a10a5 > /sys/bus/i3c/drivers/ocp-recovery/bind` |
| No `mctpi3c14` | `echo 14-fffe005a00a5 > /sys/bus/i3c/drivers/mctp-i3c/bind` |
| `SetupEndpoint` fails; mctpd log shows `Wrong IID (n-1, expected n)` | MCTP was probed before ssmcu-runtime finished booting. Power-cycle and rerun with a longer `BOOT_WAIT`. |
| `pldmd Software.Update object not found` | Check that pldmd is installed and running: `systemctl status pldmd` |
| Activation `Invalid`; pldmd log shows `Failed to decode pldm package header` | The v1.3 package must have `PackageHeaderFormatRevision` 4. Check `package_header_format_revision` in the PLDM template. |
| BMC dmesg `i3c14: ring 0: Transfer Error` | Expected during AST1040 boot; ignore it. |
