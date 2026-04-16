$ErrorActionPreference = 'Stop'

try {
    Import-Module MilestonePSTools -ErrorAction Stop
    
    if (-not (Get-VmsConnection)) {
        Connect-ManagementServer -ServerAddress "localhost" -TrustCertificate
    }
    
    $auditResults = @()
    $cameras = Get-VmsCamera
    $hardware = Get-VmsHardware
    $users = Get-VmsBasicUser
    $roles = Get-VmsRole
    
    foreach ($cam in $cameras) {
        $hw = $cam.Hardware
        
        if ($hw.FirmwareVersion -and $hw.FirmwareVersion -match '^\d+\.\d+') {
            $version = [version]($matches[0])
            if ($version -lt [version]"3.0.0") {
                $auditResults += @{
                    rule_id = "FIRMWARE_OUTDATED"
                    rule_name = "Firmware updatering kravs"
                    device_id = $cam.Id.ToString()
                    device_name = $cam.Name
                    severity = "Warning"
                    description = "Firmware version $($hw.FirmwareVersion) ar for gammal. Rekommenderad version: 3.0.0 eller senare."
                    recommendation = "Uppdatera kamerans firmware till senaste version."
                }
            }
        }
        
        if (-not $cam.IsConnected) {
            $auditResults += @{
                rule_id = "CAMERA_OFFLINE"
                rule_name = "Kamera offline"
                device_id = $cam.Id.ToString()
                device_name = $cam.Name
                severity = "Critical"
                description = "Kameran ar inte ansluten till systemet."
                recommendation = "Kontrollera natverksanslutning och stromforsorjning."
            }
        }
        
        if ($cam.IsConnected -and -not $cam.IsRecording) {
            $auditResults += @{
                rule_id = "NOT_RECORDING"
                rule_name = "Kamera spelar inte in"
                device_id = $cam.Id.ToString()
                device_name = $cam.Name
                severity = "Warning"
                description = "Kameran ar ansluten men spelar inte in."
                recommendation = "Kontrollera inspelningsschema och licensstatus."
            }
        }
        
        $streamSettings = Get-VmsCameraStream -Camera $cam -ErrorAction SilentlyContinue
        if ($streamSettings) {
            foreach ($stream in $streamSettings) {
                if ($stream.TransportType -eq 'UDP' -or $stream.EncryptionType -eq 'None') {
                    $auditResults += @{
                        rule_id = "UNENCRYPTED_STREAM"
                        rule_name = "Okrypterad videostrom"
                        device_id = $cam.Id.ToString()
                        device_name = $cam.Name
                        severity = "Warning"
                        description = "Videostrommen anvander ingen kryptering eller okrypterat UDP."
                        recommendation = "Aktivera TLS-kryptering for videostrommen."
                    }
                    break
                }
            }
        }
    }
    
    foreach ($hw in $hardware) {
        if (-not $hw.IsEnabled) {
            $auditResults += @{
                rule_id = "HARDWARE_DISABLED"
                rule_name = "Hardware inaktiverad"
                device_id = $hw.Id.ToString()
                device_name = $hw.Name
                severity = "Info"
                description = "Hardvaran ar inaktiverad."
                recommendation = "Aktivera hardvaran om den ska anvandas, eller ta bort den."
            }
        }
        
        $storage = Get-VmsStorage -Hardware $hw -ErrorAction SilentlyContinue
        if ($storage -and $storage.UsedSpacePercent -gt 90) {
            $auditResults += @{
                rule_id = "LOW_STORAGE"
                rule_name = "Lagtt lagringsutrymme"
                device_id = $hw.Id.ToString()
                device_name = $hw.Name
                severity = "Critical"
                description = "Lagringen ar $($storage.UsedSpacePercent)% full."
                recommendation = "Utoka lagringen eller rensa gammal inspelning."
            }
        }
    }
    
    foreach ($role in $roles) {
        $security = Get-VmsRoleOverallSecurity -Role $role -ErrorAction SilentlyContinue
        if ($security) {
            if ($security.CanViewLive -and $security.CanViewRecorded -and $security.CanExport) {
                $auditResults += @{
                    rule_id = "WIDE_ACCESS_ROLE"
                    rule_name = "Bred atkomst-roll"
                    device_id = $role.Id.ToString()
                    device_name = $role.Name
                    severity = "Info"
                    description = "Rollen '$($role.Name)' har fullstandig visning och exportatkomst."
                    recommendation = "Overvag att begransa atkomsten baserat pa arbetsroll."
                }
            }
        }
    }
    
    $loginSettings = Get-LoginSettings -ErrorAction SilentlyContinue
    if ($loginSettings) {
        if ($loginSettings.MaximumPasswordAge -eq 0 -or $loginSettings.MaximumPasswordAge -gt 365) {
            $auditResults += @{
                rule_id = "PASSWORD_POLICY_WEAK"
                rule_name = "Svag losenordspolicy"
                device_id = "SYSTEM"
                device_name = "System-wide"
                severity = "Warning"
                description = "Losenordspolicyn ar inte konfigurerad enligt basta praxis."
                recommendation = "Stall in MaximumPasswordAge till 90 dagar eller mindre."
            }
        }
        
        if (-not $loginSettings.RequireMFA) {
            $auditResults += @{
                rule_id = "MFA_NOT_ENABLED"
                rule_name = "MFA inte aktiverat"
                device_id = "SYSTEM"
                device_name = "System-wide"
                severity = "Critical"
                description = "Multi-Factor Authentication ar inte aktiverat for systemet."
                recommendation = "Aktivera MFA for alla anvandare."
            }
        }
    }
    
    $systemLicense = Get-VmsSystemLicense -ErrorAction SilentlyContinue
    if ($systemLicense) {
        $expiringLicenses = $systemLicense | Where-Object { $_.DaysUntilExpiry -lt 30 -and $_.DaysUntilExpiry -gt 0 }
        foreach ($license in $expiringLicenses) {
            $auditResults += @{
                rule_id = "LICENSE_EXPIRING"
                rule_name = "Licens upphor snart"
                device_id = "LICENSE"
                device_name = $license.FeatureName
                severity = "Warning"
                description = "Licensen '$($license.FeatureName)' upphor om $($license.DaysUntilExpiry) dagar."
                recommendation = "Fornya licensen innan den upphor."
            }
        }
        
        $expiredLicenses = $systemLicense | Where-Object { $_.DaysUntilExpiry -le 0 }
        foreach ($license in $expiredLicenses) {
            $auditResults += @{
                rule_id = "LICENSE_EXPIRED"
                rule_name = "Licens har upphort"
                device_id = "LICENSE"
                device_name = $license.FeatureName
                severity = "Critical"
                description = "Licensen '$($license.FeatureName)' har upphort."
                recommendation = "Fornya licensen omedelbart."
            }
        }
    }
    
    $ntpConfig = Get-VmsSiteInfo -ErrorAction SilentlyContinue
    if ($ntpConfig) {
        if (-not $ntpConfig.NtpServer -or $ntpConfig.NtpServer -eq "") {
            $auditResults += @{
                rule_id = "NTP_NOT_CONFIGURED"
                rule_name = "NTP inte konfigurerat"
                device_id = "SYSTEM"
                device_name = "Management Server"
                severity = "Warning"
                description = "NTP-server ar inte konfigurerad."
                recommendation = "Konfigurera en NTP-server for tidssynkronisering."
            }
        }
    }
    
    $alarmDefinitions = Get-VmsAlarmDefinition -ErrorAction SilentlyContinue
    if ($alarmDefinitions) {
        $inactiveAlarms = $alarmDefinitions | Where-Object { -not $_.IsEnabled }
        if ($inactiveAlarms.Count -gt 0) {
            $auditResults += @{
                rule_id = "INACTIVE_ALARMS"
                rule_name = "Inaktiva larm"
                device_id = "SYSTEM"
                device_name = "System-wide"
                severity = "Info"
                description = "$($inactiveAlarms.Count) larmdefinitioner ar inaktiverade."
                recommendation = "Aktivera eller ta bort oanvanda larmdefinitioner."
            }
        }
    }
    
    $auditResults | ConvertTo-Json -Depth 5
    
} catch {
    @{
        error = $_.Exception.Message
    } | ConvertTo-Json
}
