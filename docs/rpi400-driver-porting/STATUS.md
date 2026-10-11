# Raspberry Pi 400 Windows ARM64 driver work — status

**Updated:** 2026-10-11  
**Scope:** built-in CYW43455 Wi-Fi, Raspberry Pi platform devices, and VideoCore/V3D graphics.

## Current phase

**Phase 1 — platform mapping and reproducible ARM64 reference build (in progress).** The Windows baseline ZIP has been reviewed. No new driver has been installed. The reference build has not yet been verified by CI.

## Findings from Windows diagnostics

- Windows ARM64, OS build **22621**, Raspberry Pi 400, about 4 GiB RAM; DXDiag reports **UEFI Firmware v1.53**.
- Display uses **Microsoft Basic Display Driver**, WDDM 1.3. This shows basic display output, not hardware 3D acceleration.
- Code 28 devices: **ACPI\BCM2847\0**, **ACPI\BCM2835\0**, **ACPI\BCM2850\0**, **ACPI\BCM2854\0**, **ACPI\BCM2848\0**, **ACPI\PNP0C06\2&DABA3FF&0**.
- The installed inventory includes **bcmemmc2.inf**, RPIQ, GPIO, I2C, SPI, PWM, Ethernet, Bluetooth and HDMI audio. It did not show **bcm2836sdhc.sys** or **vchiq.sys** in the collected inventory.
- The built-in CYW43455 is not shown as a working Windows WLAN adapter in this report.

## Source mappings verified against pinned upstream source

Source: [raspberrypi/windows-drivers](https://github.com/raspberrypi/windows-drivers/tree/88ee238c9debecce810d208cac1e5f36add3d2a1), commit **88ee238c9debecce810d208cac1e5f36add3d2a1**.

| Windows ID | Upstream source | Current interpretation / action |
|---|---|---|
| **ACPI\BCM2847** | [bcm2836sdhc.inf](https://github.com/raspberrypi/windows-drivers/blob/88ee238c9debecce810d208cac1e5f36add3d2a1/drivers/sd/bcm2836/bcm2836sdhc/bcm2836sdhc.inf) | Exact INF match for Arasan SD/SDIO host controller; first ARM64 reference-build candidate. Do not install until resources, package/signing and recovery path are reviewed. |
| **ACPI\BCM2835** | [vchiq.inf](https://github.com/raspberrypi/windows-drivers/blob/88ee238c9debecce810d208cac1e5f36add3d2a1/drivers/misc/vchiq/vchiq.inf) | Exact INF match for VCHIQ, but published Windows-on-Raspberry status calls VCHIQ not working. Not a proposed fix yet. |
| **ACPI\BCM2850**, **ACPI\BCM2854**, **ACPI\BCM2848**, **ACPI\PNP0C06** | Not mapped yet | Collect device resources, parent relations and compatible IDs before assigning driver functions. |

An INF match does not prove that a driver starts correctly or makes internal WLAN work. The new GitHub Actions workflow builds the existing upstream bcm2836sdhc project for ARM64 and uploads a **reference-only** artifact. It is not assumed to be signed or safe to install.

## Phase tracker

- [ ] **Phase 0 — baseline/recovery:** Windows diagnostics reviewed; confirm a known-good recovery route. Collect Linux diagnostics too if Raspberry Pi OS is available on this Pi 400.
- [ ] **Phase 1 — platform mapping:** collect detailed resources/relations and identify the four unmapped ACPI/PNP devices; verify SDIO-host enumeration.
- [ ] **Phase 1A — reference build:** CI build of pinned upstream bcm2836sdhc ARM64 project; result pending.
- [ ] **Phase 2 — built-in CYW43455 WLAN:** verify SDIO enumeration/firmware path, then design a Windows-native driver. Linux brcmfmac is a reference, not a Windows-buildable .sys driver.
- [ ] **Phase 3 — graphics diagnosis:** inspect the roskmd.sys / VC4/V3D path. Published status calls the GPU driver unfinished; display output alone is not 3D acceleration.
- [ ] **Phase 4 — real 3D acceleration:** longer-term work requiring a working WDDM render KMD and a compatible user-mode graphics implementation.

## Next evidence needed

1. Run tools/rpi400/Collect-WindowsPiResources.ps1 in an elevated PowerShell session and share RPi400-Hardware-Resources-*.zip. This collector is read-only and focuses on Raspberry Pi ACPI/platform, display and SD-host devices.
2. If Raspberry Pi OS is available on this same Pi 400, run tools/rpi400/collect-rpios-diag.sh there and share its .tar.gz; otherwise skip it.
3. Keep a known-good boot/recovery route and backup before any driver installation. This workflow deliberately does not install drivers.

## References

- [Windows on Raspberry Pi driver status](https://github.com/worproject/RPi-Windows-Drivers)
- [Raspberry Pi Windows driver source](https://github.com/raspberrypi/windows-drivers)
- [Microsoft ARM64 driver build guidance](https://learn.microsoft.com/en-us/windows-hardware/drivers/develop/building-arm64-drivers)
- [Microsoft WiFiCx](https://learn.microsoft.com/en-us/windows-hardware/drivers/netcx/wifi-wdf-class-extension-wificx)
