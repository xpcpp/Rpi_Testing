# Raspberry Pi 400 / Pi 4 — Windows 11 ARM64 Wi-Fi + GPU research

This directory documents a staged driver-porting investigation and includes **read-only diagnostic collectors**. They do not install drivers or change boot/system settings.

**Current phase and next actions:** see [STATUS.md](STATUS.md). The built-in CYW43455 Wi-Fi device is the WLAN target.

## Assessment

- Raspberry Pi 400 uses BCM2711 / Pi 4 generation platform hardware.
- Built-in CYW43455 wireless is typically connected over SDIO. Linux brcmfmac is a protocol/initialization reference, not code that can be compiled directly into a Windows .sys driver.
- Linux vc4/v3d and Mesa are useful VideoCore VI / V3D 4.2 graphics references.
- The reviewed Windows-on-Raspberry package does not provide a ready-to-install, fully working CYW43455 WLAN driver or full 3D WDDM acceleration for Pi 4/400. Basic display output does **not** prove 3D acceleration.
- Pi 5 experiments are architectural references only; Pi 5 uses BCM2712 and a different V3D generation.

## Windows 11 ARM64 diagnostics

From the repository root, run PowerShell as Administrator:

    Set-ExecutionPolicy -Scope Process Bypass
    .\tools\rpi400\Collect-WindowsPiDiag.ps1

This creates a ZIP on the Desktop with OS/build, PnP IDs/problems, network/WLAN state, display drivers, driver packages, boot/test-signing state and DXDiag output.

For a second pass on ACPI IDs, resources and parent/driver relations:

    Set-ExecutionPolicy -Scope Process Bypass
    .\tools\rpi400\Collect-WindowsPiResources.ps1

This second collector is read-only and focuses on Raspberry Pi ACPI/platform, display and SD-host devices.

## Optional Raspberry Pi OS diagnostics

    chmod +x tools/rpi400/collect-rpios-diag.sh
    ./tools/rpi400/collect-rpios-diag.sh

It creates a .tar.gz in the home directory with board/kernel information, SDIO identities, Broadcom firmware presence, brcmfmac, GPU/DRM modules, /dev/dri, Mesa/OpenGL/Vulkan availability and relevant kernel logs. No tools are installed.

**Privacy:** inspect logs before sharing; they can contain usernames, MAC/IP addresses, SSIDs, device IDs and system details. Saved Wi-Fi passwords are not intentionally collected.

## Multi-phase plan

### Phase 0 — baseline and recovery
Confirm a known-good boot/recovery path, record Windows build/UEFI/driver inventory, and compare Windows and (if available) Linux diagnostics.

### Phase 1 — bus, enumeration and platform
Verify SDIO host and CYW43455 enumeration, compare PnP/ACPI IDs and resources against Linux device-tree evidence, and map all Code 28 devices before any install. Current evidence maps ACPI\BCM2847 to upstream bcm2836sdhc.inf; CI is preparing a reference ARM64 build. ACPI\BCM2835 maps to vchiq.inf, but published status says VCHIQ is not working, so that package is not treated as a fix.

### Phase 2 — built-in CYW43455 WLAN
Study Linux brcmfmac SDIO transport, firmware startup, control/events, TX/RX, reset and power management. Implement a Windows-native driver, evaluating Microsoft WiFiCx with KMDF/NetAdapterCx. Check firmware licensing separately. Validate device start, firmware boot, adapter visibility, scan, WPA2, DHCP/DNS, sustained traffic, reboot and recovery.

### Phase 3 — graphics diagnosis
Distinguish Microsoft Basic Display / framebuffer output from actual GPU rendering. Audit available roskmd.sys materials and use Linux vc4/v3d plus Mesa V3D/V3DV as reference implementations.

### Phase 4 — real 3D acceleration
This is a major project: a compatible WDDM render KMD **and** user-mode graphics implementation/runtime are required. Investigate clocks/power/reset, MMIO, interrupts, memory/buffer management, DMA/GPU virtual memory, command submission, synchronization and recovery. Video decode is separate.

### Phase 5 — GitHub Actions
The first workflow compiles upstream bcm2836sdhc for ARM64 and uploads logs and a reference artifact. Installation is deliberately manual and separate; build success does not prove hardware compatibility or driver functionality. Never commit signing keys.

## References

- Windows on Raspberry Pi driver status: https://github.com/worproject/RPi-Windows-Drivers
- Raspberry Pi Windows driver source: https://github.com/raspberrypi/windows-drivers
- Pi 4 UEFI: https://github.com/pftf/RPi4
- Linux Broadcom driver: https://github.com/torvalds/linux/tree/master/drivers/net/wireless/broadcom/brcm80211/brcmfmac
- Raspberry Pi Linux: https://github.com/raspberrypi/linux
- Mesa V3D: https://docs.mesa3d.org/drivers/v3d.html
- Microsoft WiFiCx: https://learn.microsoft.com/en-us/windows-hardware/drivers/netcx/wifi-wdf-class-extension-wificx
- Microsoft ARM64 driver builds: https://learn.microsoft.com/en-us/windows-hardware/drivers/develop/building-arm64-drivers
- Microsoft test signing: https://learn.microsoft.com/en-us/windows-hardware/drivers/install/test-signing
