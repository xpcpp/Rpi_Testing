# Static source review: Raspberry Pi 400 SDC1 / Arasan SDHC

**Date:** 2026-10-11  
**Scope:** Offline analysis only. No device settings or drivers changed.  
**Hardware:** Raspberry Pi 400 / BCM2711, Windows 11 ARM64 build 22621, UEFI reported as v1.53.

## Finding

The package previously present on the user's Windows installation is dated **20 August 2020** (bcm2836sdhc.inf DriverVer 08/20/2020,20.33.30.445; the diagnostic reports the matching .sys timestamp as 20-08-2020 20:34:52). The upstream driver gained at least two relevant fixes in April 2021. Therefore, the package appears to predate the fixes; timestamps alone cannot prove the exact source commit, so this remains a high-confidence lead rather than proof of the runtime failure.

### Fix A — missing miniport cleanup callbacks (PR #25)

Upstream PR [#25, "bcm2836sdhc unload"](https://github.com/raspberrypi/windows-drivers/pull/25) merged on 6 April 2021. It adds InitializationData.Cleanup = SdhcCleanup and InitializationData.PowerControlCallback = SdhcPowerControlCallback, plus WPP cleanup if SdPortInitialize fails. The PR description says sdport.sys calls these callbacks without checking for NULL, and lack of WPP cleanup can cause a later crash during unload.

Source comparison confirms:
- Before PR #25, commit 37f73c151db21901513d75200d6c0d0e30bfc111: those callbacks were not registered.
- After PR #25, merge commit 6d0b5f964bd3bacc87618f0afb74a055380de7c4: callbacks and cleanup are present.
- The driver source at later commit 31c2c748e6358711cd72467b7ad52da08691e54b contains both callbacks.

This unload fix is relevant to driver lifecycle stability; it does **not** by itself explain a WLAN adapter failing to appear.

### Fix B — disable interrupts during early initialization (PR #26)

Upstream PR [#26, "bcm2836sdhc - fix early interrupts"](https://github.com/raspberrypi/windows-drivers/pull/26) merged on 25 April 2021. The source diff changes the SDHC_INTERRUPT_ERROR_SIGNAL_ENABLE write in SdhcSlotInitialize from SDHC_ALL_EVENTS to 0. The status-enable register was already set to zero. The PR explains that SDPORT may not be ready to handle interrupts at that stage, and an interrupt arriving early can make the system crash or hang, particularly when the miniport is loaded after Windows has been running or the IRQ is shared.

Direct source comparison:
- Before PR #26, merge-base 6d0b5f964bd3bacc87618f0afb74a055380de7c4: SDHC_INTERRUPT_ERROR_SIGNAL_ENABLE = SDHC_ALL_EVENTS.
- After PR #26, merge commit 31c2c748e6358711cd72467b7ad52da08691e54b: SDHC_INTERRUPT_ERROR_SIGNAL_ENABLE = 0.
- Current upstream source also has the fixed value 0.

The UEFI ACPI template [Sdhc.asl](https://github.com/tianocore/edk2-platforms/blob/master/Platform/RaspberryPi/AcpiTables/Sdhc.asl) exposes the Arasan controller as SDC1, HID/CID BCM2847, and describes an active-high, level-triggered, **shared** interrupt in _CRS. The user's Windows device's BIOS path is _SB.GDV0.SDC1, matching the SDC1 node name. The uploaded resource collector did not provide actual assigned MMIO/IRQ values, so the current live resource assignment is not independently verified.

This makes the early-interrupt change a concrete, evidence-based candidate for a controlled rebuild, rather than a blind rebuild of the same 2020 package. It still does not prove this was the exact cause of the user's observed failure.

### Additional compatibility blocker — pinned INF lacks the Pi 400 SDC1 ID

A comparison of INF blobs found that the pinned April 2021 merge commit's `bcm2836sdhc.inf` contains only the model entry for `ACPI\\ARASAN`; it omits `ACPI\\BCM2847`. The user's 2020 INF (SetupAPI log line 503) and the current upstream INF blob both list `ACPI\\BCM2847, ACPI\\ARASAN`. Windows sees this device as hardware/compatible ID `ACPI\\BCM2847` (BIOS path `_SB.GDV0.SDC1`). Therefore, rebuilding the pinned INF unchanged would not match the target device, regardless of whether the .sys compiles.

The CI workflow now has an explicit, checked INF model-line patch that adds `ACPI\\BCM2847` before `ACPI\\ARASAN`. It refuses to continue if the expected line or the patch result differs, and the package stage checks the generated INF again before creating a catalog. This is a deliberate compatibility patch beyond the pinned upstream commit and is recorded in the artifact. This model-entry correction does not prove the host miniport will start or enumerate an SDIO child on the Pi 400.

## What the user's logs establish

- First pnputil /add-driver attempt was rejected during catalog trust validation with 0x800B0109.
- A later attempt did successfully import the package as oem22.inf, selected it for ACPI\BCM2847, created the bcm2836sdhc service, and copied the .sys file. SetupAPI then recorded a restart requirement.
- The package was later unstaged and removed from Driver Store. The current sc qc bcm2836sdhc therefore reports that the service does not exist, and the device currently shows Code 28.
- Consequently, the **current** Code 28 is consistent with the package being absent; it is not evidence that this INF can never match the device. The uploaded logs do not prove whether the miniport successfully started after reboot or whether it enumerated an SDIO child before removal.

These findings mean more generic signing checks or a repeat installation of the same binary would not add useful information.

## Important limit: host controller != Wi-Fi driver

The Linux diagnostics prove that the onboard radio works through SDIO with Linux brcmfmac and firmware. The Windows on Raspberry Pi driver's published status still lists CYW43455 WLAN as having **no driver available** ([status matrix](https://github.com/worproject/RPi-Windows-Drivers)). Even a corrected host controller would only establish the SDIO transport/child enumeration; it would **not** provide the missing Windows-native WLAN function driver.

## Decision / next engineering step

1. Do not repeat the user's old 2020 bcm2836sdhc package, and do not repeat the generic signing collector.
2. If proceeding to a build, use a reproducible upstream source snapshot at or after merge commit 31c2c748e6358711cd72467b7ad52da08691e54b, which contains both the cleanup-callback fix and the early-interrupt fix. Keep the result as a distinct candidate and retain build logs/hash manifest.
3. Do not call the candidate an installable/signed release until its package/catalog signature is handled deliberately. Do not change Secure Boot or test-signing settings as part of CI.
4. A future controlled device check needs to answer one question only: after a fixed host driver starts, does Windows enumerate an SDIO function child? If yes, the remaining blocker is a separate CYW43455 Windows function-driver project. No new user-side diagnostics are needed for the present static review.

## References

- [PR #25 — missing cleanup callbacks](https://github.com/raspberrypi/windows-drivers/pull/25)
- [PR #26 — early interrupt workaround](https://github.com/raspberrypi/windows-drivers/pull/26)
- [Source at merge commit after both fixes](https://github.com/raspberrypi/windows-drivers/tree/31c2c748e6358711cd72467b7ad52da08691e54b)
- [Pi UEFI SDC1 ACPI definition](https://github.com/tianocore/edk2-platforms/blob/master/Platform/RaspberryPi/AcpiTables/Sdhc.asl)
- [Windows on Raspberry Pi driver status](https://github.com/worproject/RPi-Windows-Drivers)
