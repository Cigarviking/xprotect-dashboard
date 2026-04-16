$ErrorActionPreference = 'Stop'
param(
    [Parameter(Mandatory=$true)]
    [string]$FilePath
)

try {
    Import-Module MilestonePSTools -ErrorAction Stop
    
    if (-not (Get-VmsConnection)) {
        Connect-ManagementServer -ServerAddress "localhost" -TrustCertificate
    }
    
    if (-not (Test-Path $FilePath)) {
        throw "File not found: $FilePath"
    }
    
    $extension = [System.IO.Path]::GetExtension($FilePath).ToLower()
    
    if ($extension -eq '.xlsx' -or $extension -eq '.xls') {
        Import-Module ImportExcel -ErrorAction Stop
        $data = Import-Excel -Path $FilePath -WorksheetName "DeviceGroups"
    } elseif ($extension -eq '.csv') {
        $data = Import-Csv -Path $FilePath
    } else {
        throw "Unsupported file format. Please use .xlsx, .xls, or .csv"
    }
    
    $imported = 0
    $skipped = 0
    $errors = @()
    
    foreach ($row in $data) {
        try {
            $ParentGroup = $row.ParentGroup
            $CameraGroup = $row.CameraGroup
            $DeviceName = $row.Device
            
            if ([string]::IsNullOrWhiteSpace($ParentGroup) -or [string]::IsNullOrWhiteSpace($CameraGroup)) {
                $skipped++
                continue
            }
            
            $existingParent = Get-VmsDeviceGroup -Name $ParentGroup -ErrorAction SilentlyContinue
            if (-not $existingParent) {
                $existingParent = New-VmsDeviceGroup -Name $ParentGroup -Description $row.Description
            }
            
            $existingCameraGroup = Get-VmsDeviceGroup -Name $CameraGroup -ParentGroup $existingParent -ErrorAction SilentlyContinue
            if (-not $existingCameraGroup) {
                $existingCameraGroup = New-VmsDeviceGroup -Name $CameraGroup -ParentGroup $existingParent -Description $row.Description
            }
            
            if (-not [string]::IsNullOrWhiteSpace($DeviceName)) {
                $camera = Get-VmsCamera -Name $DeviceName -ErrorAction SilentlyContinue
                if ($camera) {
                    $members = Get-VmsDeviceGroupMember -Group $existingCameraGroup
                    if ($members.Name -notcontains $DeviceName) {
                        Add-VmsDeviceGroupMember -Group $existingCameraGroup -Device $camera
                        $imported++
                    } else {
                        $skipped++
                    }
                } else {
                    $errors += "Camera not found: $DeviceName"
                }
            }
        } catch {
            $errors += "Error importing row: $($_.Exception.Message)"
        }
    }
    
    @{
        success = $true
        imported = $imported
        skipped = $skipped
        errors = $errors
    } | ConvertTo-Json -Depth 5
    
} catch {
    @{
        success = $false
        error = $_.Exception.Message
    } | ConvertTo-Json
}
