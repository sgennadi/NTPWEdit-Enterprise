<#
.SYNOPSIS
    Finds offline Windows installations that contain readable SAM and SYSTEM hives.
#>
[CmdletBinding()]
param(
    [switch]$AsJson,
    [string]$OutputPath,
    [switch]$IncludeUsb
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Get-DriveInventory {
    $result = [System.Collections.Generic.List[object]]::new()

    try {
        if (Get-Command Get-Volume -ErrorAction SilentlyContinue) {
            foreach ($volume in @(Get-Volume -ErrorAction Stop | Where-Object DriveLetter)) {
                $diskNumber = $null
                $partitionNumber = $null
                $busType = $null
                try {
                    $partition = $volume | Get-Partition -ErrorAction Stop | Select-Object -First 1
                    $diskNumber = $partition.DiskNumber
                    $partitionNumber = $partition.PartitionNumber
                    $disk = Get-Disk -Number $partition.DiskNumber -ErrorAction Stop
                    $busType = [string]$disk.BusType
                } catch { }

                $result.Add([pscustomobject]@{
                    DriveLetter = [string]$volume.DriveLetter
                    FileSystem = [string]$volume.FileSystem
                    Label = [string]$volume.FileSystemLabel
                    Size = [uint64]$volume.Size
                    DiskNumber = $diskNumber
                    PartitionNumber = $partitionNumber
                    BusType = $busType
                    Source = 'Storage'
                }) | Out-Null
            }
            return $result.ToArray()
        }
    } catch { }

    try {
        foreach ($logical in @(Get-CimInstance Win32_LogicalDisk -ErrorAction Stop | Where-Object DeviceID)) {
            $result.Add([pscustomobject]@{
                DriveLetter = ([string]$logical.DeviceID).Substring(0,1)
                FileSystem = [string]$logical.FileSystem
                Label = [string]$logical.VolumeName
                Size = [uint64]$logical.Size
                DiskNumber = $null
                PartitionNumber = $null
                BusType = $null
                Source = 'CIM'
            }) | Out-Null
        }
        return $result.ToArray()
    } catch { }

    foreach ($drive in [System.IO.DriveInfo]::GetDrives()) {
        try {
            if (-not $drive.IsReady -or $drive.Name -notmatch '^[A-Za-z]:\\$') { continue }
            $result.Add([pscustomobject]@{
                DriveLetter = $drive.Name.Substring(0,1)
                FileSystem = $drive.DriveFormat
                Label = $drive.VolumeLabel
                Size = [uint64]$drive.TotalSize
                DiskNumber = $null
                PartitionNumber = $null
                BusType = [string]$drive.DriveType
                Source = 'DriveInfo'
            }) | Out-Null
        } catch { }
    }
    return $result.ToArray()
}

function Get-BitLockerState {
    param([Parameter(Mandatory=$true)][string]$DriveLetter)
    $state = 'Unknown'
    if (-not (Get-Command manage-bde.exe -ErrorAction SilentlyContinue)) { return $state }
    try {
        $text = (& manage-bde.exe -status "${DriveLetter}:" 2>$null | Out-String)
        if ($text -match '(?im)^\s*Lock Status:\s*Locked\s*$') { return 'Locked' }
        if ($text -match '(?im)^\s*Lock Status:\s*Unlocked\s*$') { return 'Unlocked' }
        if ($text -match '(?im)^\s*Conversion Status:\s*Fully Decrypted\s*$') { return 'NotEncrypted' }
        if ($text -match '(?im)^\s*Percentage Encrypted:\s*0(?:\.0)?%\s*$') { return 'NotEncrypted' }
    } catch { }
    return $state
}

function Get-OfflineWindowsInfo {
    param([Parameter(Mandatory=$true)][string]$SoftwareHive)

    $result = [ordered]@{
        ProductName = 'Windows installation'
        EditionID = $null
        DisplayVersion = $null
        Build = $null
        UBR = $null
        InstallationType = $null
    }
    $mountName = 'NTPW_' + [Guid]::NewGuid().ToString('N')
    $registryPath = "HKLM:\$mountName\Microsoft\Windows NT\CurrentVersion"
    $loaded = $false
    try {
        & reg.exe load "HKLM\$mountName" $SoftwareHive *> $null
        if ($LASTEXITCODE -ne 0) { return [pscustomobject]$result }
        $loaded = $true
        $properties = Get-ItemProperty -LiteralPath $registryPath -ErrorAction SilentlyContinue
        if ($properties) {
            foreach ($name in @('ProductName','EditionID','DisplayVersion','CurrentBuildNumber','UBR','InstallationType')) {
                if ($properties.PSObject.Properties[$name]) {
                    switch ($name) {
                        'CurrentBuildNumber' { $result.Build = [string]$properties.$name }
                        default { $result[$name] = $properties.$name }
                    }
                }
            }
        }
    } catch { }
    finally {
        if ($loaded) {
            [GC]::Collect()
            [GC]::WaitForPendingFinalizers()
            & reg.exe unload "HKLM\$mountName" *> $null
        }
    }
    return [pscustomobject]$result
}

$results = [System.Collections.Generic.List[object]]::new()
foreach ($volume in @(Get-DriveInventory)) {
    $letter = ([string]$volume.DriveLetter).TrimEnd(':').ToUpperInvariant()
    if (-not $letter -or $letter -eq 'X') { continue }
    if (-not $IncludeUsb -and ([string]$volume.BusType -match 'USB|Removable')) { continue }

    $root = "${letter}:\"
    $windowsPath = Join-Path $root 'Windows'
    $configPath = Join-Path $windowsPath 'System32\Config'
    $samPath = Join-Path $configPath 'SAM'
    $systemPath = Join-Path $configPath 'SYSTEM'
    $softwarePath = Join-Path $configPath 'SOFTWARE'
    if (-not (Test-Path -LiteralPath $samPath -PathType Leaf)) { continue }
    if (-not (Test-Path -LiteralPath $systemPath -PathType Leaf)) { continue }

    $windowsInfo = Get-OfflineWindowsInfo -SoftwareHive $softwarePath
    $sizeGB = if ($volume.Size) { [math]::Round(([double]$volume.Size / 1GB), 2) } else { $null }
    $results.Add([pscustomobject]@{
        Index = $results.Count + 1
        DriveLetter = $letter
        WindowsPath = $windowsPath
        ConfigPath = $configPath
        SamPath = $samPath
        SystemHive = $systemPath
        SoftwareHive = $softwarePath
        ProductName = [string]$windowsInfo.ProductName
        EditionID = [string]$windowsInfo.EditionID
        DisplayVersion = [string]$windowsInfo.DisplayVersion
        Build = [string]$windowsInfo.Build
        UBR = $windowsInfo.UBR
        InstallationType = [string]$windowsInfo.InstallationType
        BitLocker = Get-BitLockerState -DriveLetter $letter
        FileSystem = [string]$volume.FileSystem
        VolumeLabel = [string]$volume.Label
        SizeGB = $sizeGB
        DiskNumber = $volume.DiskNumber
        PartitionNumber = $volume.PartitionNumber
        BusType = [string]$volume.BusType
        DiscoverySource = [string]$volume.Source
    }) | Out-Null
}

$data = $results.ToArray()
if ($AsJson -or $OutputPath) {
    $json = ConvertTo-Json -InputObject @($data) -Depth 6
    if ($OutputPath) {
        $parent = Split-Path -Parent $OutputPath
        if ($parent -and -not (Test-Path -LiteralPath $parent)) {
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
        }
        [System.IO.File]::WriteAllText($OutputPath, $json, (New-Object System.Text.UTF8Encoding($false)))
    } else {
        $json
    }
} else {
    $data
}
