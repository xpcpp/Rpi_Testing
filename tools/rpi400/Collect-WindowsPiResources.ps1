# Read-only second-pass device/resource diagnostics for Raspberry Pi 400 on Windows ARM64.
$ErrorActionPreference = 'Continue'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$desktop = [Environment]::GetFolderPath('Desktop')
$root = Join-Path $desktop "RPi400-Hardware-Resources-$stamp"
New-Item -ItemType Directory -Path $root -Force | Out-Null

$propertyKeys = @(
  'DEVPKEY_Device_HardwareIds',
  'DEVPKEY_Device_CompatibleIds',
  'DEVPKEY_Device_ProblemCode',
  'DEVPKEY_Device_ProblemStatus',
  'DEVPKEY_Device_Service',
  'DEVPKEY_Device_DriverInfPath',
  'DEVPKEY_Device_DriverVersion',
  'DEVPKEY_Device_DriverDate',
  'DEVPKEY_Device_LocationInfo',
  'DEVPKEY_Device_LocationPaths',
  'DEVPKEY_Device_EnumeratorName',
  'DEVPKEY_Device_BusReportedDeviceDesc',
  'DEVPKEY_Device_Manufacturer',
  'DEVPKEY_Device_ClassGuid',
  'DEVPKEY_Device_Parent',
  'DEVPKEY_Device_Resources',
  'DEVPKEY_Device_ResourceRequirements',
  'DEVPKEY_Device_BootConfiguration',
  'DEVPKEY_Device_Address'
)

function Save-Text([string]$Name, [scriptblock]$Body) {
  try {
    & $Body 2>&1 | Out-String -Width 300 | Set-Content -LiteralPath (Join-Path $root $Name) -Encoding UTF8
  } catch {
    "Collection error: $_" | Set-Content -LiteralPath (Join-Path $root $Name) -Encoding UTF8
  }
}

Save-Text '01-system-firmware.txt' {
  Get-ComputerInfo | Select-Object WindowsProductName,WindowsVersion,OsBuildNumber,OsArchitecture,CsSystemType,CsModel,CsTotalPhysicalMemory | Format-List
  Get-CimInstance Win32_BIOS | Select-Object Manufacturer,SMBIOSBIOSVersion,Version,ReleaseDate | Format-List
  Get-CimInstance Win32_BaseBoard | Select-Object Manufacturer,Product,Version | Format-List
}

$devices = @(
  Get-PnpDevice -PresentOnly | Where-Object {
    $_.InstanceId -match '^ACPI\\BCM' -or
    $_.InstanceId -like 'ACPI\PNP0C06*' -or
    $_.InstanceId -like 'ROOT\BASICDISPLAY*' -or
    $_.Class -in @('Display','SDHost') -or
    $_.FriendlyName -match 'Arasan|eMMC|VideoCore|Basic Display|Basic Render|RPIQ|Broadcom GENET|Cypress Bluetooth'
  }
)

$records = foreach ($device in $devices) {
  $values = [ordered]@{}
  foreach ($key in $propertyKeys) {
    try {
      $property = Get-PnpDeviceProperty -InstanceId $device.InstanceId -KeyName $key -ErrorAction Stop
      if ($null -ne $property.Data) { $values[$key] = $property.Data }
    } catch {
      # Unsupported properties are omitted; keep collecting the remaining devices.
    }
  }
  [pscustomobject]@{
    Status = $device.Status
    Class = $device.Class
    FriendlyName = $device.FriendlyName
    InstanceId = $device.InstanceId
    Problem = $device.Problem
    Properties = [pscustomobject]$values
  }
}

$records | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $root '02-device-properties.json') -Encoding UTF8
$records | ForEach-Object {
  $props = $_.Properties
  [pscustomobject]@{
    Status = $_.Status
    Class = $_.Class
    FriendlyName = $_.FriendlyName
    InstanceId = $_.InstanceId
    Problem = $_.Problem
    ProblemCode = $props.DEVPKEY_Device_ProblemCode
    ProblemStatus = $props.DEVPKEY_Device_ProblemStatus
    HardwareIds = (@($props.DEVPKEY_Device_HardwareIds) -join ' ; ')
    CompatibleIds = (@($props.DEVPKEY_Device_CompatibleIds) -join ' ; ')
    Service = $props.DEVPKEY_Device_Service
    DriverInfPath = $props.DEVPKEY_Device_DriverInfPath
    DriverVersion = $props.DEVPKEY_Device_DriverVersion
    LocationInfo = $props.DEVPKEY_Device_LocationInfo
    LocationPaths = (@($props.DEVPKEY_Device_LocationPaths) -join ' ; ')
    Parent = $props.DEVPKEY_Device_Parent
    ResourcesPresent = ($null -ne $props.DEVPKEY_Device_Resources)
    ResourceRequirementsPresent = ($null -ne $props.DEVPKEY_Device_ResourceRequirements)
  }
} | Export-Csv -NoTypeInformation -Encoding UTF8 -LiteralPath (Join-Path $root '03-device-summary.csv')

Save-Text '04-pnputil-relations-drivers.txt' {
  foreach ($device in $devices) {
    "===== $($device.InstanceId) | $($device.FriendlyName) ====="
    pnputil.exe /enum-devices /instanceid $device.InstanceId /relations /drivers 2>&1
    ''
  }
}

Save-Text '05-display-stack.txt' {
  Get-CimInstance Win32_VideoController | Select-Object Name,AdapterCompatibility,DriverVersion,DriverDate,Status,PNPDeviceID,VideoModeDescription,CurrentHorizontalResolution,CurrentVerticalResolution | Format-List
  Get-CimInstance Win32_PnPSignedDriver | Where-Object {
    $_.DeviceClass -match 'DISPLAY|SDHOST|SYSTEM' -and
    $_.DeviceName -match 'Display|Render|Video|Arasan|SD Host|eMMC|RPIQ|Broadcom'
  } | Select-Object DeviceName,DeviceClass,DriverProviderName,DriverVersion,InfName,IsSigned | Format-Table -Wrap
}

@'
Read-only second-pass Raspberry Pi 400 hardware/resource diagnostics.
No drivers, services, boot settings, or device configuration were changed.
The JSON may contain hardware resource ranges, interrupt assignments and device paths. Review before sharing.
'@ | Set-Content -LiteralPath (Join-Path $root 'SHARE-SAFELY.txt') -Encoding UTF8

$zip = "$root.zip"
Compress-Archive -Path (Join-Path $root '*') -DestinationPath $zip -Force
Write-Host "Hardware/resource diagnostics saved to: $zip"
