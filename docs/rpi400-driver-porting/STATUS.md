# Raspberry Pi 400 Windows ARM64 driver work — status

**Updated:** 2026-10-11  
**Scope:** built-in CYW43455 Wi-Fi, Raspberry Pi platform devices, and VideoCore/V3D graphics. **TP-Link USB Wi-Fi is out of scope.**

## Current phase

**Phase 1 — static review of the Windows SDIO path.** Windows baseline, Windows resource/parent report, Linux diagnostics, and the user's SDHC installation-history/signing-state report have all been reviewed. No more generic diagnostic collection is planned unless static analysis identifies a specific missing datum.

**Explicit stop:** the user has already tested the upstream Arasan SDHC driver (bcm2836sdhc) and confirmed it does not work. Do not ask the user to reinstall/rebuild it, repeat certificate/Test Signing checks, or run another generic collector. Its temporary CI build workflow was removed.

## Windows baseline evidence

- Windows ARM64, OS build **22621**, Raspberry Pi 400, about 4 GiB RAM; DXDiag reports **UEFI Firmware v1.53**.
- Display uses **Microsoft Basic Display Driver**, WDDM 1.3. This proves basic display output, not Windows hardware 3D acceleration.
- Code 28 devices: **ACPI\\BCM2847\\0**, **ACPI\\BCM2835\\0**, **ACPI\\BCM2850\\0**, **ACPI\\BCM2854\\0**, **ACPI\\BCM2848\\0**, **ACPI\\PNP0C06\\2&DABA3FF&0**.
- The installed inventory includes **bcmemmc2.inf**, RPIQ, GPIO, I2C, SPI, PWM, Ethernet, Bluetooth and HDMI audio. The report did not show **bcm2836sdhc.sys** or **vchiq.sys** in the collected driver inventory.
- The built-in CYW43455 is not shown as a working Windows WLAN adapter in this report.

## New Linux baseline evidence

Source bundle: rpi400-diagnostics-20261011-083921.tar.gz.

- OS: Debian GNU/Linux 13 (trixie), kernel **6.18.50+rpt-rpi-v8**, aarch64; board model **Raspberry Pi 400 Rev 1.0**, compatible **brcm,bcm2711**.
- **Built-in Wi-Fi works in Linux.** wlan0 is present on the SDIO bus (parent device mmc1:0001:1), connected to an access point, and has an IPv4 address. The log says **mmc1: new high speed SDIO card at address 0001**.
- Linux brcmfmac successfully probes the Broadcom wireless function and loads firmware reported as **brcm/brcmfmac43456-sdio**; firmware reports chip family BCM4345/9 and version **7.84.17.1**. The bundle also lists brcmfmac43455-sdio.bin and board NVRAM text, plus brcmfmac43456-sdio.bin. This is a working protocol/firmware reference, not a Windows driver that can be reused as-is.
- **Linux GPU acceleration stack is present.** Kernel logs show v3d initialized for fec00000.v3d and vc4 DRM initialized. /dev/dri/card0, /dev/dri/card1, and /dev/dri/renderD128 exist. vulkaninfo reports **V3D 4.2.14.0**, Mesa **V3DV**, Vulkan API 1.3.354; llvmpipe is also listed as a CPU device. This is strong evidence that the Linux V3D render path is available, but says nothing directly about the Windows GPU stack.
- One kernel warning occurred: **vc4-drm gpu: swiotlb buffer is full (sz: 294912 bytes, total 32768 (slots), used 460 (slots))**. Track it only if Linux shows rendering glitches or memory/DMA pressure; alone it is not evidence of the Windows driver problem.
- glxinfo was not installed and vulkaninfo was run without a valid XDG_RUNTIME_DIR, so this bundle does not prove desktop OpenGL rendering or a full graphical-session test. Vulkan device enumeration does identify the V3D Vulkan driver.
- The script's separate SDIO identity section was blank, but kernel logs and wlan0's sysfs parent independently confirm SDIO enumeration and a working driver path.


## Additional Windows SDIO and failed-driver evidence

- The Windows resource report identifies SDC1 as `ACPI\\BCM2847\\0`, ACPI path `_SB.GDV0.SDC1`, parent `ACPI\\ACPI0004\\1`; it remains Code 28 / problem status `0xC0000490`. The collector did not retrieve resource/resource-requirement properties for devices, so it does **not** establish the MMIO range or IRQ assignment.
- SetupAPI history shows the first `bcm2836sdhc.inf` import failing with `0x800B0109` (untrusted root). A later attempt staged the package as `oem22.inf`, selected it for `ACPI\\BCM2847`, configured the service and copied `bcm2836sdhc.sys`; a restart was required. The package was then removed from Driver Store at 03:29. Current report: service not installed, .sys file still exists on disk, device remains Code 28. This history does not prove successful controller start after reboot.
- The read-only signing report found the original catalog/.sys signature chain not trusted by the current trust provider and no explicit `testsigning`/ `nointegritychecks` lines in the captured BCD output. There were no matching Code Integrity or System events in the collected event-log query. Do not treat this as a reason to repeat signing checks; the known driver attempt already failed from the user's perspective.
- Upstream `raspberrypi/windows-drivers` issue [#24](https://github.com/raspberrypi/windows-drivers/issues/24) reports SDHC sample-derived drivers encountering PnP/interrupt disconnect failures when removed, and reports first-boot driver resets on then-current Windows releases. This is a plausible risk to assess in source, **not proof** of the user's exact failure.
- Next work is offline/static: inspect the SDHCI miniport implementation and teardown/interrupt lifecycle, compare the source's resource assumptions with Pi 400 SDC1 ACPI (`_CRS`/IRQ/MMIO) and the already collected diagnostics, then identify a concrete code/compatibility issue before proposing any new build. No further user-side command is required for this review.

## Source research — do not confuse a matching INF with a working driver

Pinned source reference: [raspberrypi/windows-drivers](https://github.com/raspberrypi/windows-drivers/tree/88ee238c9debecce810d208cac1e5f36add3d2a1), commit 88ee238c9debecce810d208cac1e5f36add3d2a1.

| Windows ID | Source match | Decision |
|---|---|---|
| **ACPI\\BCM2847** | [bcm2836sdhc.inf](https://github.com/raspberrypi/windows-drivers/blob/88ee238c9debecce810d208cac1e5f36add3d2a1/drivers/sd/bcm2836/bcm2836sdhc/bcm2836sdhc.inf) | User says this driver was tested previously and did not work. **Do not rebuild or reinstall as the next step.** Only revisit its failure if the Windows SDIO path requires a targeted root-cause investigation. |
| **ACPI\\BCM2835** | [vchiq.inf](https://github.com/raspberrypi/windows-drivers/blob/88ee238c9debecce810d208cac1e5f36add3d2a1/drivers/misc/vchiq/vchiq.inf) | INF matches VCHIQ, but published Windows-on-Raspberry status marks VCHIQ not working. Not treated as a fix. |
| **ACPI\\BCM2850**, **ACPI\\BCM2854**, **ACPI\\BCM2848**, **ACPI\\PNP0C06** | Not established | Need device resources, parent/child relations, hardware/compatible IDs and problem status before guessing their functions. |

An INF match does not prove that a device starts correctly, owns required resources, or enables internal WLAN.

## Current technical interpretation

The Linux evidence confirms that the Pi 400's internal WLAN hardware, SDIO transport, firmware and Linux brcmfmac stack work together on this same hardware. This narrows the Windows problem: the target is not a dead radio, and blindly repeating the known-failing SDHC driver build is not justified. The next investigation should correlate Windows ACPI device resources and SD-host stack with Linux device-tree/SDIO evidence, then decide whether the blocker is Windows host-controller enumeration, child-device enumeration, firmware loading, or the absence of a Windows-native WLAN function driver.

For graphics, Linux provides a practical reference: BCM2711 vc4 display/KMS plus v3d DRM and Mesa V3DV. The Windows side currently only proves Microsoft Basic Display output, so Windows GPU work remains a separate and much larger WDDM KMD + user-mode implementation effort.

## Next action — offline/static driver review

The requested Windows resource/parent report and signing-state report have been uploaded and reviewed. Do not ask the user to run another generic collector or repeat the known-failing installation. Inspect the existing SDHCI miniport lifecycle, interrupt handling, and SDC1 ACPI resource contract first. Only propose a code change/build if this review identifies a concrete hypothesis and a validation plan that does not simply repeat the failed attempt.

## Phase tracker

- [x] Initial Windows diagnostics collected and reviewed.
- [x] Linux diagnostics collected and reviewed: SDIO Wi-Fi and Linux V3D path confirmed working.
- [x] Mark previously tested bcm2836sdhc driver as not a candidate to rebuild blindly; removed its reference-build workflow.
- [x] **Phase 1 — Windows baseline/resource and install-history evidence collected.** Device resource values were not exposed by the collector; do not request another generic report.
- [ ] **Phase 1 — offline/static review:** inspect SDHCI implementation and SDC1 ACPI resource contract; assess upstream interrupt/teardown issue #24 before proposing a distinct experiment.
- [ ] **Phase 2 — built-in CYW43455 Wi-Fi:** after the Windows bus path is understood, design/assess a Windows-native implementation using WiFiCx/KMDF/NetAdapterCx. Advanced monitor/injection features are not in the initial scope.
- [ ] **Phase 3 — GPU diagnosis:** compare Windows display/render stack with Linux vc4/v3d/Mesa evidence and audit available Windows roskmd.sys materials.
- [ ] **Phase 4 — real 3D acceleration:** long-term implementation requiring a working WDDM render kernel driver and compatible user-mode graphics runtime; not a build-only task.

## References

- [Windows on Raspberry Pi driver status](https://github.com/worproject/RPi-Windows-Drivers)
- [Raspberry Pi Windows driver source](https://github.com/raspberrypi/windows-drivers)
- [Linux Broadcom driver](https://github.com/torvalds/linux/tree/master/drivers/net/wireless/broadcom/brcm80211/brcmfmac)
- [Raspberry Pi Linux](https://github.com/raspberrypi/linux)
- [Mesa V3D](https://docs.mesa3d.org/drivers/v3d.html)
- [Microsoft WiFiCx](https://learn.microsoft.com/en-us/windows-hardware/drivers/netcx/wifi-wdf-class-extension-wificx)
- [Microsoft ARM64 driver builds](https://learn.microsoft.com/en-us/windows-hardware/drivers/develop/building-arm64-drivers)
