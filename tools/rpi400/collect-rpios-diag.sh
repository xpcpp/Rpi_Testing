#!/usr/bin/env bash
# Read-only Raspberry Pi OS diagnostics for Pi 400 / Pi 4; does not install packages.
set -u
umask 077
stamp="$(date +%Y%m%d-%H%M%S)"
out="$HOME/rpi400-diagnostics-$stamp"
mkdir -p "$out" || exit 1
run() { local cmd="$1"; shift; if command -v "$cmd" >/dev/null 2>&1; then "$cmd" "$@" 2>&1 || true; else echo "Not installed: $cmd"; fi; }
{
  cat /etc/os-release 2>/dev/null || true
  echo '--- uname ---'; uname -a
  echo '--- model ---'; tr -d '\0' </proc/device-tree/model 2>/dev/null || true; echo
  echo '--- compatible ---'; tr '\0' '\n' </proc/device-tree/compatible 2>/dev/null || true
  echo '--- cmdline ---'; cat /proc/cmdline 2>/dev/null || true
  echo '--- memory ---'; free -h 2>&1 || true
} >"$out/01-system.txt"
{
  echo '--- links ---'; ip -details link 2>&1 || true
  echo '--- addresses/routes ---'; ip address 2>&1 || true; ip route 2>&1 || true
  echo '--- rfkill/iw/nmcli ---'; run rfkill list all; run iw dev; run iw phy; run nmcli device status
  echo '--- net drivers ---'
  for n in /sys/class/net/*; do [ -e "$n" ] || continue; echo "$(basename "$n"): $(readlink -f "$n/device/driver" 2>/dev/null || echo none)"; done
} >"$out/02-network.txt"
{
  echo '--- modules ---'; lsmod 2>&1 || true
  echo '--- brcmfmac ---'; run modinfo brcmfmac
  echo '--- SDIO identities ---'
  find /sys/bus/sdio/devices -maxdepth 2 -type f \( -name vendor -o -name device -o -name class -o -name modalias \) -print -exec sh -c 'printf "  "; cat "$1" 2>/dev/null' sh {} \; 2>&1 || true
  echo '--- Broadcom firmware files ---'; find /lib/firmware/brcm -maxdepth 2 -type f \( -iname '*43455*' -o -iname '*4345*' \) -printf '%p (%s bytes)\n' 2>&1 || true
} >"$out/03-sdio-firmware.txt"
{
  echo '--- /dev/dri ---'; ls -la /dev/dri 2>&1 || true
  echo '--- DRM status ---'; find /sys/class/drm -maxdepth 2 -type f \( -name status -o -name enabled -o -name modes \) -print -exec sh -c 'printf "  "; cat "$1" 2>/dev/null' sh {} \; 2>&1 || true
  echo '--- GPU modules ---'; lsmod 2>&1 | grep -Ei '(^| )(vc4|v3d|drm|gpu)' || true
  echo '--- module info ---'; run modinfo vc4; run modinfo v3d
  echo '--- overlays/vcgencmd ---'; run dtoverlay -l; run vcgencmd version; run vcgencmd get_mem gpu
  echo '--- GL/Vulkan ---'; if command -v glxinfo >/dev/null 2>&1; then glxinfo -B 2>&1 || true; else echo 'glxinfo not installed'; fi
  if command -v vulkaninfo >/dev/null 2>&1; then vulkaninfo --summary 2>&1 || true; else echo 'vulkaninfo not installed'; fi
  echo '--- Mesa/firmware packages ---'; run dpkg-query -W 'mesa-*' libgl1-mesa-dri firmware-brcm80211
} >"$out/04-gpu-display.txt"
{ echo '--- dmesg ---'; dmesg -T 2>&1 || true; } >"$out/05-dmesg.txt"
{ journalctl -k -b --no-pager 2>&1 | grep -Ei 'brcmfmac|43455|cyw|sdio|mmc|vc4|v3d|drm|firmware|gpu|fail|error|timeout' || true; } >"$out/06-filtered-kernel-log.txt"
cat >"$out/SHARE-SAFELY.txt" <<'TXT'
Read-only diagnostic bundle; no packages or system configuration were changed.
Review before sharing for usernames, IP/MAC addresses, SSIDs, device IDs and other identifiers. Saved Wi-Fi passwords are not intentionally collected.
TXT
archive="$out.tar.gz"
tar -czf "$archive" -C "$(dirname "$out")" "$(basename "$out")" && echo "Diagnostics saved to: $archive"
