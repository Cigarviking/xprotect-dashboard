$ErrorActionPreference = 'Stop'

try {
    Import-Module MilestonePSTools -ErrorAction Stop
    
    if (-not (Get-VmsConnection)) {
        Connect-ManagementServer -ServerAddress "localhost" -TrustCertificate
    }
    
    $rules = Get-VmsRule | Select-Object Id, Name, Description, IsEnabled, Priority, Created, Modified, TriggerType, ActionType
    
    $result = @()
    
    foreach ($rule in $rules) {
        $ruleResult = @{
            id = $rule.Id.ToString()
            name = $rule.Name
            description = $rule.Description
            is_enabled = $rule.IsEnabled
            priority = $rule.Priority
            trigger_type = $rule.TriggerType
            action_type = $rule.ActionType
            created = if ($rule.Created) { $rule.Created.ToString("yyyy-MM-dd HH:mm:ss") } else { "" }
            modified = if ($rule.Modified) { $rule.Modified.ToString("yyyy-MM-dd HH:mm:ss") } else { "" }
        }
        
        $result += $ruleResult
    }
    
    $result | ConvertTo-Json -Depth 5
    
} catch {
    @{
        error = $_.Exception.Message
    } | ConvertTo-Json
}
