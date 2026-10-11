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
- Upstream PR [#25](https://github.com/raspberrypi/windows-drivers/pull/25) (merged 2021-04-06) adds the SDPORT miniport Cleanup and PowerControlCallback hooks and WPP cleanup. PR [#26](https://github.com/raspberrypi/windows-drivers/pull/26) (merged 2021-04-25) changes SdhcSlotInitialize so SDHC_INTERRUPT_ERROR_SIGNAL_ENABLE is written as 0 instead of SDHC_ALL_EVENTS, preventing interrupt signaling before SDPORT is ready. The user's INF and .sys timestamps are 2020-08-20, before both fixes; this strongly suggests a stale pre-fix package, though timestamps alone do not prove exact source provenance.
- The current UEFI ACPI template defines SDC1 with HID/CID BCM2847 and a shared level/high interrupt. The Windows resource collector confirmed the SDC1 ACPI path but did not capture actual live MMIO/IRQ values. The early-interrupt fix is a concrete, source-backed candidate—not a confirmed root cause.
- Issue [#24](https://github.com/raspberrypi/windows-drivers/issues/24) discusses unload failures from both sdport.sys and the miniport. Its discussion distinguishes a Windows sdport.sys bug fixed in Windows build 21343 from a bcm2836sdhc miniport cleanup bug addressed separately by PR #25. The user's Windows build 22621 is newer than 21343; do not attribute the failure to the old sdport unload bug without evidence.
- Static source review is recorded in [SDHC-SOURCE-REVIEW.md](SDHC-SOURCE-REVIEW.md). Next engineering step, if building a candidate, is a reproducible ARM64 build from upstream commit `31c2c748e6358711cd72467b7ad52da08691e54b` or a later reviewed source snapshot containing PR #25 and PR #26. This is distinct from the user's 2020 binary. Do not call the result ready to install until catalog signing is handled explicitly; do not repeat generic signing diagnostics or change Secure Boot/test-signing settings as part of CI. No further user-side commands are needed for the static review.

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

## Next action — fixed-source package validation

Static code findings are in [SDHC-SOURCE-REVIEW.md](SDHC-SOURCE-REVIEW.md). The pinned upstream source `31c2c748e6358711cd72467b7ad52da08691e54b` contains PR #25 cleanup callbacks and PR #26 early-interrupt masking. Run [#38112872885](https://github.com/xpcpp/Rpi_Testing/actions/runs/38112872885) successfully compiled/linked an ARM64 `bcm2836sdhc.sys` and its `ApiValidator` check passed, but WDK's embedded InfVerif hook logged a DLL-load exception; it had no catalog and was unsigned, so it is not install-ready.

A further source check uncovered a separate, critical compatibility issue: the pinned commit's INF omitted `ACPI\\BCM2847`, even though that is the actual SDC1 ID on this Pi 400 and it appears in the user's original INF and the current upstream INF. The corrected workflow now patches this explicit model entry, verifies it in the source and final package INF, then independently runs `InfVerif /u /v`, generates a catalog for Windows 11 22H2 ARM64 (`10_NI_ARM64`), and signs the experimental package with a one-run test certificate. Only the public certificate may be included in the artifact; the ephemeral PFX/private key must never be uploaded.

Run [#38113285423](https://github.com/xpcpp/Rpi_Testing/actions/runs/38113285423) compiled the driver and applied the BCM2847 ID, but the package stage correctly stopped at standalone InfVerif: ERROR(1208), `BasicDriverOk` is not allowed (INF line 29). The directive is a legacy ControlFlags selection hint; Microsoft also removed it from newer driver samples (commit [#1038](https://github.com/microsoft/Windows-driver-samples/commits/main?after=41b5bca9edf38ca02d5d034e9dd2afb99777a609+139)). Workflow commit `23027eeca167a89bb1d2976032a7ebf23deb241a` now removes that directive and retains the Pi 400 `ACPI\\BCM2847` mapping before rerunning InfVerif and package generation. Run [#38127293988](https://github.com/xpcpp/Rpi_Testing/actions/runs/38127293988) is the active validation attempt. Until standalone InfVerif, Inf2Cat, test signing, and signature verification pass, no installable package is available. Do not install the unsigned compile candidate or make Secure Boot/Test Signing changes based on it. Even a successfully built and test-signed host miniport is experimental and will not itself provide the separate CYW43455 WLAN function driver.
 
## Phase tracker

- [x] Initial Windows diagnostics collected and reviewed.
- [x] Linux diagnostics collected and reviewed: SDIO Wi-Fi and Linux V3D path confirmed working.
- [x] Mark previously tested bcm2836sdhc driver as not a candidate to rebuild blindly; removed its reference-build workflow.
- [x] **Phase 1 — Windows baseline/resource and install-history evidence collected.** Device resource values were not exposed by the collector; do not request another generic report.
- [x] **Phase 1 — offline/static source review:** documented pre-fix package evidence, upstream PR #25/#26 fixes, and the pinned-INF ACPI\\BCM2847 mismatch.
- [x] **Phase 1 — ARM64 compile/link smoke build:** produced an unsigned PE32+ ARM64 candidate from the fixed source; physical-device behavior is untested.
- [ ] **Phase 1 — corrected INF/package validation:** independently validate the patched INF, generate the Windows 11 22H2 ARM64 catalog, and verify test signatures; do not install until this stage passes and a recovery/security plan is agreed.
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
