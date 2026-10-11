# Raspberry Pi 400 / Pi 4 — Windows 11 ARM64 Wi-Fi + GPU research

This directory documents a staged driver-porting investigation and includes **read-only diagnostic collectors**. These files do not install drivers, alter boot configuration, or change system settings.

## Current assessment

- Raspberry Pi 400 is based on BCM2711 and uses the Pi 4 generation of platform hardware.
- The built-in wireless device is the CYW43455 family, typically connected over SDIO. Linux's open-source `brcmfmac` driver is the protocol and initialization reference; Linux code cannot be compiled directly as a Windows `.sys` because it relies on Linux MMC/SDIO, networking and cfg80211 APIs.
- Linux's `vc4` DRM and `v3d` render drivers plus Mesa V3D/V3DV are useful references for the Pi 4 VideoCore VI / V3D 4.2 graphics stack.
- The reviewed Windows-on-Raspberry-Pi driver package does not provide a ready-to-install, fully working CYW43455 WLAN driver or full 3D WDDM acceleration for Pi 4/400. Existing display output alone does **not** prove hardware 3D acceleration.
- PFTF RPi4 provides UEFI/platform support, not a Wi-Fi or GPU driver.
- Raspberry Pi 5 experiments are architecture references only: Pi 5 uses BCM2712 and a different V3D generation, so its driver binaries/register assumptions are not drop-in compatible with Pi 400.
- Test Mode relaxes kernel-driver signing policy for development; it cannot supply missing implementation or fix incorrect device IDs/resources.

## Collect diagnostics

### Windows 11 ARM64

Run PowerShell as Administrator from this folder:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\..\..\tools\rpi400\Collect-WindowsPiDiag.ps1
```

The script creates a ZIP on the current user's Desktop. It collects OS/build/architecture, PnP devices and IDs, problem devices, network/WLAN state, display adapters, installed driver packages, boot/test-signing settings and DXDiag output.

### Raspberry Pi OS

```bash
chmod +x tools/rpi400/collect-rpios-diag.sh
./tools/rpi400/collect-rpios-diag.sh
```

The script creates a `tar.gz` in the home directory with board/kernel information, network and SDIO identities, Broadcom firmware presence, `brcmfmac`, GPU/DRM modules, `/dev/dri`, Mesa/OpenGL/Vulkan tool availability and relevant kernel logs. It does not install tools.

**Privacy:** inspect generated logs before sharing. They may include usernames, MAC/IP addresses, SSIDs, device IDs and computer details. The collectors do not intentionally collect saved Wi-Fi passwords.

## Multi-phase plan

### Phase 0 — baseline and recovery
1. Back up important data and retain a known-good boot/recovery route.
2. Collect Windows and Raspberry Pi OS diagnostics on the same Pi 400.
3. Record Windows build, UEFI release, driver package version and exact missing-device problem codes.
4. Keep Ethernet or a USB network adapter available during internal WLAN development.

**Exit:** reproducible device IDs/status on Windows and confirmed SDIO/GPU stack on Linux.

### Phase 1 — bus, enumeration and platform
- Check whether the SDIO host controller is functioning, then determine whether the CYW43455 function enumerates.
- Compare Windows PnP/ACPI IDs and resources with Linux SDIO/device-tree evidence.
- Do not replace UEFI just because a WLAN or GPU driver is missing.

### Phase 2 — built-in Wi-Fi (first functional target)
- Study upstream Linux `brcmfmac` SDIO transport, firmware startup, control/event protocol, TX/RX, reset and power management.
- Implement a Windows-native driver; evaluate Microsoft WiFiCx with KMDF/NetAdapterCx for the chosen Windows 11 target.
- Check firmware licensing/redistribution separately from host-driver source licensing.
- Build ARM64 and validate in stages: device start → firmware boot → WLAN adapter → scan → WPA2 connection → DHCP/DNS → sustained traffic → reboot and power recovery.

**Acceptance:** Device Manager and `netsh wlan show interfaces` show a functional adapter; scanning and WPA2 connection work reliably. Advanced monitor/injection features are explicitly out of scope for initial bring-up.

### Phase 3 — distinguish display from GPU rendering
- Capture DXDiag and adapter/driver information. Microsoft Basic Display Adapter or framebuffer output is basic display, not proof of 3D acceleration.
- Use Linux `vc4`/`v3d` DRM and Mesa `v3d`/`v3dv` as references for V3D 4.2.
- Audit any existing `roskmd.sys` code and its implementation status before attempting reuse.

### Phase 4 — real 3D acceleration (large project)
A real solution needs a compatible WDDM render kernel-mode driver **and** a user-mode graphics implementation/runtime. An INF, display-only driver, or adapter name alone cannot provide this.
- Investigate clocks/power/reset, MMIO, interrupts, memory/buffer objects, DMA/GPU virtual memory, command submission, synchronization, scheduling and recovery.
- Design a Windows KMD/UMD interface. A Vulkan-first experiment informed by Mesa `v3dv` may be worth evaluating, but Linux DRM assumptions must be replaced/bridged.
- Acceptance ladder: no device-start errors → minimal GPU job completes → Vulkan/OpenGL enumerates hardware implementation → rendering tests pass → sustained 3D stability. Video decode is a separate driver path.

### Phase 5 — GitHub Actions
After real driver source exists, pin a Windows runner and WDK, target **ARM64**, run build/INF/static/package checks, and upload `.sys`, `.inf`, `.cat`, logs and manifest as artifacts. Never commit private signing keys. Keep driver installation/manual hardware tests separate from early CI; build success is not hardware success.

## References

- WOR driver status/releases: https://github.com/worproject/RPi-Windows-Drivers and https://github.com/worproject/RPi-Windows-Drivers/releases
- Raspberry Pi Windows drivers: https://github.com/raspberrypi/windows-drivers
- Pi 4 UEFI: https://github.com/pftf/RPi4 and https://github.com/pftf/RPi4/releases
- Pi 5 reference: https://github.com/erspicu/AprWindowsARMDriverPI5
- Linux Broadcom driver: https://github.com/torvalds/linux/tree/master/drivers/net/wireless/broadcom/brcm80211/brcmfmac
- Raspberry Pi Linux: https://github.com/raspberrypi/linux
- Mesa V3D: https://docs.mesa3d.org/drivers/v3d.html
- Microsoft WiFiCx: https://learn.microsoft.com/en-us/windows-hardware/drivers/netcx/wifi-wdf-class-extension-wificx
- Microsoft ARM64 driver builds: https://learn.microsoft.com/en-us/windows-hardware/drivers/develop/building-arm64-drivers
- Microsoft test signing: https://learn.microsoft.com/en-us/windows-hardware/drivers/install/test-signing

Research status is preliminary. Hardware-specific conclusions must be checked against the diagnostic output and current upstream sources before implementing a driver.
