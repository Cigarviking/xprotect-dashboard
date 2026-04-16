$ErrorActionPreference = 'Stop'

try {
    Import-Module MilestonePSTools -ErrorAction Stop
    
    if (-not (Get-VmsConnection)) {
        Connect-ManagementServer -ServerAddress "localhost" -TrustCertificate
    }
    
    $users = Get-VmsBasicUser | Select-Object Id, Name, DisplayName, Email, Domain, IsEnabled, Created, LastLogin, IsBuiltIn, AuthenticationType
    $roles = Get-VmsRole | Select-Object Id, Name, Description, IsBuiltIn
    
    $result = @()
    
    foreach ($user in $users) {
        $userRoles = Get-VmsRoleMember -User $user -ErrorAction SilentlyContinue
        
        $userResult = @{
            id = $user.Id.ToString()
            name = $user.Name
            display_name = $user.DisplayName
            email = $user.Email
            domain = $user.Domain
            is_enabled = $user.IsEnabled
            is_builtin = $user.IsBuiltIn
            authentication_type = $user.AuthenticationType
            created = if ($user.Created) { $user.Created.ToString("yyyy-MM-dd HH:mm:ss") } else { "" }
            last_login = if ($user.LastLogin) { $user.LastLogin.ToString("yyyy-MM-dd HH:mm:ss") } else { "Aldrig" }
            roles = @()
            permissions = @{
                can_view_live = $false
                can_view_recorded = $false
                can_export = $false
                can_delete = $false
                can_configure = $false
            }
        }
        
        foreach ($role in $userRoles) {
            $userResult.roles += $role.Name
            
            $security = Get-VmsRoleOverallSecurity -Role $role -ErrorAction SilentlyContinue
            if ($security) {
                if ($security.CanViewLive) { $userResult.permissions.can_view_live = $true }
                if ($security.CanViewRecorded) { $userResult.permissions.can_view_recorded = $true }
                if ($security.CanExport) { $userResult.permissions.can_export = $true }
                if ($security.CanDelete) { $userResult.permissions.can_delete = $true }
                if ($security.CanConfigure) { $userResult.permissions.can_configure = $true }
            }
        }
        
        if ($user.IsBuiltIn -and $user.Name -eq "Administrator") {
            $userResult.is_critical = $true
        } else {
            $userResult.is_critical = $false
        }
        
        $result += $userResult
    }
    
    @{
        users = $result
        total_users = $result.Count
        total_roles = $roles.Count
        builtin_users = ($result | Where-Object { $_.is_builtin }).Count
        disabled_users = ($result | Where-Object { -not $_.is_enabled }).Count
    } | ConvertTo-Json -Depth 5
    
} catch {
    @{
        error = $_.Exception.Message
    } | ConvertTo-Json
}
