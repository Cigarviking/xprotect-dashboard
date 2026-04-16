$ErrorActionPreference = 'Stop'

try {
    Import-Module MilestonePSTools -ErrorAction Stop
    
    if (-not (Get-VmsConnection)) {
        Connect-ManagementServer -ServerAddress "localhost" -TrustCertificate
    }
    
    $cameras = Get-VmsCamera | Select-Object Name, Id, IsConnected, IsRecording, Hardware, DevicePath, Created, Modified
    
    $result = @()
    foreach ($cam in $cameras) {
        $hw = $cam.Hardware
        
        $camResult = @{
            id = $cam.Id.ToString()
            name = $cam.Name
            device_path = $cam.DevicePath
            is_connected = $cam.IsConnected
            is_recording = $cam.IsRecording
            hardware_name = if ($hw) { $hw.Name } else { "Unknown" }
            hardware_model = if ($hw) { $hw.Model } else { "Unknown" }
            ip_address = if ($hw) { $hw.Address } else { "Unknown" }
            firmware = if ($hw) { $hw.FirmwareVersion } else { "Unknown" }
            created = if ($cam.Created) { $cam.Created.ToString("yyyy-MM-dd HH:mm:ss") } else { "" }
            modified = if ($cam.Modified) { $cam.Modified.ToString("yyyy-MM-dd HH:mm:ss") } else { "" }
        }
        
        $result += $camResult
    }
    
    $result | ConvertTo-Json -Depth 5
    
} catch {
    @{
        error = $_.Exception.Message
    } | ConvertTo-Json
}
