# Read-only Windows 11 ARM64 / Raspberry Pi 400 diagnostics
$ErrorActionPreference = 'Continue'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$root = Join-Path ([Environment]::GetFolderPath('Desktop')) "RPi400-Diagnostics-$stamp"
New-Item -ItemType Directory -Path $root -Force | Out-Null
function Save-Section([string]$Name, [scriptblock]$Body) {
  try { & $Body 2>&1 | Out-String -Width 240 | Set-Content -LiteralPath (Join-Path $root $Name) -Encoding UTF8 }
  catch { "Collection error: $_" | Set-Content -LiteralPath (Join-Path $root $Name) -Encoding UTF8 }
}
Save-Section '01-system.txt' {
  Get-ComputerInfo | Select-Object WindowsProductName,WindowsVersion,OsBuildNumber,OsArchitecture,CsSystemType,CsModel,CsTotalPhysicalMemory | Format-List
  $PSVersionTable | Format-List
}
Save-Section '02-boot-test-signing.txt' { bcdedit.exe /enum all }
Save-Section '03-pnp-all.txt' {
  Get-PnpDevice -PresentOnly | Sort-Object Class,FriendlyName | Select-Object Status,Class,FriendlyName,InstanceId,Problem | Format-Table -Wrap -AutoSize
}
Save-Section '04-pnp-problems.txt' {
  Get-PnpDevice -PresentOnly | Where-Object { $_.Status -ne 'OK' -or $_.Class -in @('Display','Net','SDHost','System','Unknown') } | Select-Object Status,Class,FriendlyName,InstanceId,Problem | Format-List
}
try {
  $devs = @(Get-PnpDevice -PresentOnly)
  $devs | Select-Object Status,Class,FriendlyName,InstanceId,Problem | Export-Csv -NoTypeInformation -Encoding UTF8 -LiteralPath (Join-Path $root 'pnp-all.csv')
  $focus = foreach ($d in $devs | Where-Object { $_.Status -ne 'OK' -or $_.Class -in @('Display','Net','SDHost','System','Unknown') }) {
    $h=''; $c=''; $p=''
    try { $h=((Get-PnpDeviceProperty -InstanceId $d.InstanceId -KeyName 'DEVPKEY_Device_HardwareIds' -ErrorAction SilentlyContinue).Data -join ' ; ') } catch {}
    try { $c=((Get-PnpDeviceProperty -InstanceId $d.InstanceId -KeyName 'DEVPKEY_Device_CompatibleIds' -ErrorAction SilentlyContinue).Data -join ' ; ') } catch {}
    try { $p=(Get-PnpDeviceProperty -InstanceId $d.InstanceId -KeyName 'DEVPKEY_Device_ProblemCode' -ErrorAction SilentlyContinue).Data } catch {}
    [pscustomobject]@{Status=$d.Status;Class=$d.Class;Name=$d.FriendlyName;InstanceId=$d.InstanceId;Problem=$d.Problem;ProblemCode=$p;HardwareIds=$h;CompatibleIds=$c}
  }
  $focus | Export-Csv -NoTypeInformation -Encoding UTF8 -LiteralPath (Join-Path $root 'pnp-focus-hardware-ids.csv')
} catch { "PnP CSV export failed: $_" | Set-Content (Join-Path $root 'pnp-csv-error.txt') }
Save-Section '05-network-adapters.txt' { Get-NetAdapter -IncludeHidden | Format-List Name,InterfaceDescription,Status,LinkSpeed,MacAddress,DriverInformation,DriverFileName,PnPDeviceID }
Save-Section '06-wlan.txt' { netsh.exe wlan show drivers; netsh.exe wlan show interfaces; netsh.exe wlan show networks mode=bssid }
Save-Section '07-display-drivers.txt' {
  Get-CimInstance Win32_VideoController | Format-List Name,AdapterCompatibility,DriverVersion,DriverDate,Status,VideoModeDescription,CurrentHorizontalResolution,CurrentVerticalResolution
  Get-CimInstance Win32_PnPSignedDriver | Where-Object { $_.DeviceClass -match 'DISPLAY|NET|SYSTEM|SDHOST' -or $_.DeviceName -match 'Broadcom|VideoCore|VC4|Wi.Fi|WLAN|SDIO|Graphics|Raspberry' } | Format-Table DeviceName,DeviceClass,DriverProviderName,DriverVersion,InfName,IsSigned -Wrap
  pnputil.exe /enum-drivers
}
Save-Section '08-problem-devices.txt' { pnputil.exe /enum-devices /problem }
Save-Section '09-driverquery.txt' { driverquery.exe /v /fo table }
try {
  $dx = Join-Path $root '10-dxdiag.txt'
  $exe = Join-Path $env:WINDIR 'System32\dxdiag.exe'
  if (Test-Path $exe) { Start-Process $exe -ArgumentList @('/whql:off','/t',"`"$dx`"") -Wait -WindowStyle Hidden }
} catch { "DXDiag error: $_" | Set-Content (Join-Path $root '10-dxdiag-error.txt') }
@'
Read-only diagnostic bundle; no driver or boot configuration changes were made.
Review before sharing: files may contain computer/device identifiers, MAC/IP addresses, SSIDs and usernames. Saved Wi-Fi passwords are not intentionally collected.
'@ | Set-Content (Join-Path $root 'SHARE-SAFELY.txt') -Encoding UTF8
$zip = "$root.zip"
Compress-Archive -Path (Join-Path $root '*') -DestinationPath $zip -Force
Write-Host "Diagnostics saved to: $zip"
