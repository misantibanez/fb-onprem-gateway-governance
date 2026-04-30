#=============================================================================
# setup_standard_policies.ps1
# Restringe gateways standard (Resource) a usuarios autorizados.
# Solo estos usuarios podrán instalar gateways en las VMs definidas.
# Requiere: Tenant Admin o Gateway Admin.
#=============================================================================

# --- Conectar a Azure AD (para resolver Object IDs) ---
Connect-AzAccount

# --- Conectar al servicio de Data Gateway ---
Login-DataGatewayServiceAccount

# --- 1. Restringir la política de gateways standard a nivel tenant ---
Write-Host "Restringiendo política de gateway standard..." -ForegroundColor Yellow
Set-DataGatewayTenantPolicy -ResourceGatewayInstallPolicy Restricted

# --- 2. Definir usuarios autorizados para instalar gateways standard ---
# Agregar UPNs de los usuarios o el grupo que tendrán permiso
$authorizedUsers = @(
    "usuario2@dominio.co"
    # "usuario2@dominio.com"
    # "usuario3@dominio.com"
)

# Resolver Object IDs
$objectIds = @()
foreach ($upn in $authorizedUsers) {
    $user = Get-AzADUser -UserPrincipalName $upn
    if ($user) {
        $objectIds += $user.Id
        Write-Host "  Resuelto: $upn -> $($user.Id)" -ForegroundColor Gray
    } else {
        Write-Warning "  No se encontró el usuario: $upn"
    }
}

# --- ALTERNATIVA: Usar un grupo de Entra ID en lugar de usuarios individuales ---
# $groupId = (Get-AzADGroup -DisplayName "Gateway Installers").Id
# $objectIds = @($groupId)

# --- 3. Asignar permisos de instalación de gateway standard (Resource) ---
if ($objectIds.Count -gt 0) {
    Write-Host "`nAsignando permisos de gateway standard a $($objectIds.Count) identidad(es)..." -ForegroundColor Yellow
    Set-DataGatewayInstaller -PrincipalObjectIds $objectIds -Operation Add -GatewayType Resource
    Write-Host "Permisos asignados correctamente." -ForegroundColor Green
} else {
    Write-Warning "No se resolvieron usuarios. No se asignaron permisos."
}

# --- 4. Verificar configuración final ---
Write-Host "`n=== Política del tenant ===" -ForegroundColor Cyan
Get-DataGatewayTenantPolicy

Write-Host "`n=== Instaladores autorizados ===" -ForegroundColor Cyan
Get-DataGatewayInstaller
