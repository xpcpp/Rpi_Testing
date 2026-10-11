# Raspberry Pi 400 Windows ARM64 driver work — status

**Updated:** 2026-10-11  
**Scope:** built-in CYW43455 Wi-Fi, Raspberry Pi platform devices, and VideoCore/V3D graphics. **TP-Link USB Wi-Fi is out of scope.**

## Current phase

**Phase 1 — identify the actual platform/bus blockers before writing or installing anything.** The Windows baseline ZIP has been reviewed. No new driver has been installed in this phase.

**Explicit stop:** the user has already tested the upstream Arasan SDHC driver (bcm2836sdhc) previously and confirmed it did not work. Do not spend more time rebuilding/reinstalling it as a presumed fix. Its temporary CI build workflow has been removed.

## Windows baseline evidence

- Windows ARM64, OS build **22621**, Raspberry Pi 400, about 4 GiB RAM; DXDiag reports **UEFI Firmware v1.53**.
- Display uses **Microsoft Basic Display Driver**, WDDM 1.3. This proves basic display output, not hardware 3D acceleration.
- Code 28 devices: **ACPI\BCM2847\0**, **ACPI\BCM2835\0**, **ACPI\BCM2850\0**, **ACPI\BCM2854\0**, **ACPI\BCM2848\0**, **ACPI\PNP0C06\2&DABA3FF&0**.
- The installed inventory includes **bcmemmc2.inf**, RPIQ, GPIO, I2C, SPI, PWM, Ethernet, Bluetooth and HDMI audio. The report did not show **bcm2836sdhc.sys** or **vchiq.sys** in the collected driver inventory.
- The built-in CYW43455 is not shown as a working Windows WLAN adapter in this report.

## Source research — do not confuse a matching INF with a working driver

Pinned source reference: [raspberrypi/windows-drivers](https://github.com/raspberrypi/windows-drivers/tree/88ee238c9debecce810d208cac1e5f36add3d2a1), commit 88ee238c9debecce810d208cac1e5f36add3d2a1.

| Windows ID | Source match | Decision |
|---|---|---|
| **ACPI\BCM2847** | [bcm2836sdhc.inf](https://github.com/raspberrypi/windows-drivers/blob/88ee238c9debecce810d208cac1e5f36add3d2a1/drivers/sd/bcm2836/bcm2836sdhc/bcm2836sdhc.inf) | User says this driver was tested previously and did not work. **Do not rebuild or reinstall as the next step.** Capture actual device resources/parent relations and figure out why it is non-working only if that becomes necessary to the SDIO/WLAN path. |
| **ACPI\BCM2835** | [vchiq.inf](https://github.com/raspberrypi/windows-drivers/blob/88ee238c9debecce810d208cac1e5f36add3d2a1/drivers/misc/vchiq/vchiq.inf) | INF matches VCHIQ, but published Windows-on-Raspberry status marks VCHIQ not working. Not treated as a fix. |
| **ACPI\BCM2850**, **ACPI\BCM2854**, **ACPI\BCM2848**, **ACPI\PNP0C06** | Not established | Need device resources, parent/child relations, hardware/compatible IDs and problem status before guessing their functions. |

An INF match does not prove that a device starts correctly, owns the required resources, or enables internal WLAN. Linux brcmfmac is a protocol/initialization reference for CYW43455, not code that can be compiled directly into a Windows .sys.

## Next action — collect evidence, not another driver build

Run this read-only collector from an **elevated PowerShell** session. It records resources, parent relations, compatible IDs, problem status and the display/SD-host stack into a Desktop ZIP:

    Set-ExecutionPolicy -Scope Process Bypass
    .\tools\rpi400\Collect-WindowsPiResources.ps1

Upload the generated RPi400-Hardware-Resources-*.zip here. No drivers or settings are changed by the script.

If Raspberry Pi OS is available on this same Pi 400, the optional tools/rpi400/collect-rpios-diag.sh output is also useful: it establishes whether Linux sees the CYW43455 SDIO function, which firmware it loads, and whether vc4/v3d hardware rendering is available. Skip this if Linux is not available; don't install another OS just for this request.

## Phase tracker

- [x] Initial Windows diagnostics collected and reviewed.
- [x] Mark previously tested bcm2836sdhc driver as **not a candidate to rebuild blindly**; removed its reference-build workflow.
- [ ] **Phase 1 — platform/bus mapping:** collect detailed resources and identify the four unmapped ACPI/PNP entries; establish whether internal CYW43455 is enumerated on SDIO.
- [ ] **Phase 2 — built-in CYW43455 Wi-Fi:** after bus/firmware evidence, assess a Windows-native driver design using WiFiCx/KMDF/NetAdapterCx. Advanced monitor/injection features are not in the initial scope.
- [ ] **Phase 3 — GPU diagnosis:** distinguish display-only output from actual VideoCore/V3D rendering; audit available Windows roskmd.sys materials and Linux/Mesa references.
- [ ] **Phase 4 — real 3D acceleration:** long-term implementation requiring a working WDDM render kernel driver and compatible user-mode graphics runtime; not a build-only task.

## References

- [Windows on Raspberry Pi driver status](https://github.com/worproject/RPi-Windows-Drivers)
- [Raspberry Pi Windows driver source](https://github.com/raspberrypi/windows-drivers)
- [Linux Broadcom driver](https://github.com/torvalds/linux/tree/master/drivers/net/wireless/broadcom/brcm80211/brcmfmac)
- [Raspberry Pi Linux](https://github.com/raspberrypi/linux)
- [Mesa V3D](https://docs.mesa3d.org/drivers/v3d.html)
- [Microsoft WiFiCx](https://learn.microsoft.com/en-us/windows-hardware/drivers/netcx/wifi-wdf-class-extension-wificx)
- [Microsoft ARM64 driver builds](https://learn.microsoft.com/en-us/windows-hardware/drivers/develop/building-arm64-drivers)
