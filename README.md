# Lenovo Legion Pro 7 16IRX8H (82WQ) — Linux fixes

Firmware and driver workarounds for the Legion Pro 7 16IRX8H (machine type 82WQ),
verified on BIOS **KWCN51WW** with kernel 7.2.9 (Gentoo), NVIDIA open driver
615.78.08, discrete-GPU (MUX) mode.

| Fix | Type | Fixes |
|---|---|---|
| `acpi/pnot-fix` | SSDT override | `PNOT` AE_NOT_FOUND on AC plug/unplug and thermal events |
| `acpi/etmd-fix` | SSDT override | `\_TZ.ETMD` AE_NOT_FOUND aborting `IETM._OSC` (DPTF handshake) at every boot |
| `acpi/wm00-fix` | SSDT override | `WM00` AE_NOT_FOUND on brightness keys |
| `edid/` | EDID override | Corrupted internal-panel EDID reads: 640x400 boots, black screen after resume |
| `patches/` | Kernel patch | TAS2781 speaker amps discarding valid factory calibration |

```
acpi/       SSDT sources (.dsl) and compiled tables (.aml)
edid/       EDID of the internal panel (CSOT MNG007DA2-3, 2560x1600@240)
patches/    kernel patch, laid out for /etc/portage/patches
config/     dracut config and the kernel command line parameter
```

## ACPI overrides

The BIOS calls three objects that don't exist in any of its tables. Each call
aborts the calling method with `AE_NOT_FOUND`. The overrides are small SSDTs
that the kernel loads from the initramfs (`CONFIG_ACPI_TABLE_UPGRADE=y`), on
top of the firmware's tables. Nothing is flashed, and removing them restores
stock behaviour.

### pnot-fix — `\_SB.PC00.LPCB.PNOT`

```
ACPI BIOS Error (bug): Could not resolve symbol [\_SB.PC00.LPCB.EC0._Q38.PNOT], AE_NOT_FOUND
ACPI Error: Aborting method \_SB.PC00.LPCB.EC0._Q38 due to previous error (AE_NOT_FOUND)
```

EC events `_Q1D` (thermal level change), `_Q37` (AC plugged in) and `_Q38` (AC
unplugged) end with `PNOT ()`, Intel's reference "processor notify" method.
Lenovo's firmware implements it as `\SPNT` (SSDT16), which the DSDT already
calls elsewhere, but never defines `PNOT`. The override defines `PNOT` as a
wrapper around `\SPNT`, which sends Notify 0x80/0x81 to every CPU.

Effect: the error is gone and the CPU notifications are delivered. With
intel_pstate in HWP mode the kernel doesn't act on `_PPC`, so the CPU behaves
the same; it only matters with `acpi-cpufreq` or `intel_pstate=no_hwp`.

### etmd-fix — `\_TZ.ETMD`

```
ACPI BIOS Error (bug): Could not resolve symbol [\_TZ.ETMD], AE_NOT_FOUND
ACPI Error: Aborting method \_SB.IETM._OSC due to previous error (AE_NOT_FOUND)
```

When thermald registers as the passive-cooling handler, the kernel's int3400
driver calls `IETM._OSC`. The firmware writes `\_TZ.ETMD`, left over from
Intel's reference thermal-zone code that Lenovo removed, and aborts before it
updates the trip values and returns. The kernel then fails thermald's request
with `-EPERM`. The override defines `ETMD` with Intel's default, so `_OSC`
completes.

Effect: the DPTF capability handshake succeeds. The firmware moves its own
passive trip (`APSV`) to 110 °C, Intel's standard "OS handles passive cooling"
value; nothing in ACPI reads it. The CPU still throttles itself at TjMax
(100 °C), and the TCPU zone's critical trip (110 °C, from `TJMX`) is
unchanged.

### wm00-fix — `\_SB.WM00`

```
ACPI BIOS Error (bug): Could not resolve symbol [\_SB.PC00.LPCB.EC0._Q11.WM00], AE_NOT_FOUND
ACPI Error: Aborting method \_SB.PC00.LPCB.EC0._Q11 due to previous error (AE_NOT_FOUND)
```

EC events `_Q11`/`_Q12` (brightness down/up) and `_Q44` end with
`Notify (WM00, 0x80)` after setting `WEID` to 0xF4/0xF5. No `WM00` device
exists, nothing reads `WEID`, and no WMI block on this machine registers
those event IDs. It's leftover code from another model. The override adds
a disabled stub device (`_HID` PNP0C14, `_STA` 0) so the Notify resolves and
is dropped. It shows up as an extra `PNP0C14` entry with status 0 in
`/sys/bus/acpi/devices`, but no platform or WMI device is created.

Effect: no errors on brightness keys. Brightness itself is unchanged; the
display and `VPC0` notifications earlier in the same handlers already ran.

### Install

```sh
mkdir -p /etc/acpi_override
cp acpi/*.aml /etc/acpi_override/
cp config/dracut.conf.d/acpi-override.conf /etc/dracut.conf.d/
dracut --force --kver "$(uname -r)"
```

Verify after reboot:

```sh
journalctl -k -b | grep -E "Table Upgrade|ACPI.*Error"
# ACPI: Table Upgrade: install [SSDT-   TOM- ETMDFIX]
# ACPI: Table Upgrade: install [SSDT-   TOM- PNOTFIX]
# ACPI: Table Upgrade: install [SSDT-   TOM- WM00FIX]
```

To rebuild from source: `iasl -tc acpi/<name>.dsl` (ACPICA, `sys-power/iasl`).

**After a BIOS update**, check the boot log for `AE_ALREADY_EXISTS`. If Lenovo
has fixed one of these, remove the matching `.aml` from `/etc/acpi_override`
and rerun dracut.

## EDID override

In discrete-GPU mode the NVIDIA driver drives the internal panel. It
occasionally reads the panel's EDID back corrupted, giving a 640x400 desktop
at boot, KWin `EDID colorimetry … is invalid`, or a black/flickering screen
(including the TTY) after resume from suspend. `edid/` holds a known-good
copy read from the panel (CSOT MNG007DA2-3: 2560x1600, 60 Hz in the base
block, 240 Hz in the DisplayID block, valid checksums).

`drm.edid_firmware` makes DRM use the file instead of reading the panel. The
open NVIDIA driver honours it (`nvidia-drm` calls
`drm_edid_override_connector_update`). The override only applies to the
`eDP-1` connector, so external monitors on HDMI/DP/USB-C still read their own
EDIDs. In hybrid MUX mode the Intel driver also names the internal panel
`eDP-1`, so the override stays correct.

### Install

```sh
install -Dm644 edid/legion-edp-csot-mng007da2-3.bin /lib/firmware/edid/legion-edp.bin
cp config/dracut.conf.d/edid-override.conf /etc/dracut.conf.d/
dracut --force --kver "$(uname -r)"
```

Then add the parameter in `config/kernel-cmdline/edid-override.txt` to the
kernel command line (for systemd-boot, the `options` line of the loader
entry). The file has to be in the initramfs because `nvidia-drm` loads there.

Verify after reboot:

```sh
journalctl -k -b | grep "Loading firmware: edid/legion-edp.bin"
```

The line appears on every probe of the panel, including on resume.

Only use this EDID with this exact panel; remove the parameter if the panel
is replaced.

## TAS2781 calibration patch

`patches/sys-kernel/gentoo-sources/0001-tas2781-accept-unwritten-v1-cali-crc.patch`

The speakers use TI TAS2781 smart amplifiers (codec SSID 17aa:3884). Their
per-unit factory calibration is stored in a UEFI variable in the V1 layout.
This BIOS writes the calibration records but leaves the trailing timestamp
and CRC words zero, so the kernel logs `V1 CRC error`, discards the valid
calibration, and runs the speaker-protection algorithm on generic defaults.

The patch accepts the data only when the CRC was **never written**, never
when it's wrong:
- both the timestamp and CRC words must be zero, and
- every device record that will be used must contain non-zero data.

An erased or never-calibrated block is still rejected. When it applies, the
kernel logs:

```
tas2781-hda i2c-TIAS2781:00: tas2781_cali_v1_crc_unwritten: BIOS left V1 calibration CRC unwritten, using data as-is
```

On Gentoo, copy it to `/etc/portage/patches/sys-kernel/gentoo-sources/` and
re-emerge the kernel sources. On other distributions, apply it to the
kernel tree before building.

## Known remaining firmware messages (harmless)

These are logged on this machine but are handled by the kernel or don't
affect anything:

- `[Firmware Bug]: TSC ADJUST … force to 0`: the kernel resets the BIOS's
  TSC offset.
- `i2c_designware … DSDT uses known not-working I2C bus speed 400000, forcing
  it to 100000`: kernel quirk.
- `ACPI(PEGP) defines _DOD but not _DOS`: warning only.
- On resume: `Unexpected lid state reported by firmware`,
  `xhci_hcd 0000:39:00.0: xHC error in resume … Reinit` (Thunderbolt USB
  controller), and `spd5118 … error -6` (DDR5 temperature sensors).

The `_Q77`/`SNTM`/`RTCM` "No handler for Region [SystemCMOS]" flood reported
on older kernels (after resume, every second) needs no override on current
kernels: `drivers/acpi/x86/cmos_rtc.c` installs the CMOS handler for
`ACPI000E` (the `\_SB.AWAC` Time and Alarm device) as well as the legacy RTC.
Verified on 7.2.9 with no `_Q77` errors across AC changes and suspend/resume.
