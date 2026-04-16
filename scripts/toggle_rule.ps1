$ErrorActionPreference = 'Stop'
param(
    [Parameter(Mandatory=$true)]
    [string]$RuleId,
    [Parameter(Mandatory=$true)]
    [string]$Enabled
)

try {
    Import-Module MilestonePSTools -ErrorAction Stop
    
    if (-not (Get-VmsConnection)) {
        Connect-ManagementServer -ServerAddress "localhost" -TrustCertificate
    }
    
    $rule = Get-VmsRule -Id $RuleId -ErrorAction Stop
    
    if ($Enabled -eq "true") {
        $rule.IsEnabled = $true
    } else {
        $rule.IsEnabled = $false
    }
    
    Set-VmsRule -Rule $rule
    
    @{
        success = $true
        message = "Regel '$($rule.Name)' har uppdaterats."
    } | ConvertTo-Json
    
} catch {
    @{
        success = $false
        error = $_.Exception.Message
    } | ConvertTo-Json
}
