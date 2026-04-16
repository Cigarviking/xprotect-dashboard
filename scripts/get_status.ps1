$ErrorActionPreference = 'Stop'

try {
    Import-Module MilestonePSTools -ErrorAction Stop
    
    if (-not (Get-VmsConnection)) {
        Connect-ManagementServer -ServerAddress "localhost" -TrustCertificate
    }
    
    $site = Get-VmsSite
    $cameras = Get-VmsCamera
    $hardware = Get-VmsHardware
    $users = Get-VmsBasicUser
    $roles = Get-VmsRole
    $rules = Get-VmsRule
    
    $cameraStats = @{
        total = $cameras.Count
        online = ($cameras | Where-Object { $_.IsConnected }).Count
        recording = ($cameras | Where-Object { $_.IsRecording }).Count
        offline = ($cameras | Where-Object { -not $_.IsConnected }).Count
    }
    
    $storageStats = @()
    foreach ($hw in $hardware) {
        $storage = Get-VmsStorage -Hardware $hw
        $storageStats += @{
            hardware = $hw.Name
            storageUsed = if ($storage) { $storage.UsedSpaceGB } else { 0 }
            storageTotal = if ($storage) { $storage.TotalSpaceGB } else { 0 }
        }
    }
    
    $result = @{
        connected = $true
        serverName = $site.ServerName
        version = $site.Version
        cameras = $cameraStats
        totalUsers = $users.Count
        totalRoles = $roles.Count
        totalRules = $rules.Count
        totalHardware = $hardware.Count
        storage = $storageStats
    }
    
    $result | ConvertTo-Json -Depth 5
    
} catch {
    @{
        connected = $false
        error = $_.Exception.Message
    } | ConvertTo-Json
}
