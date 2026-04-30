#=============================================================================
# setup_personal_restricted.ps1
# Bloquea la instalación de gateways personales en el tenant.
# Requiere: Tenant Admin o Gateway Admin.
#=============================================================================

# --- Instalar módulos necesarios (solo la primera vez) ---
# Install-Module "DataGateway" -Scope CurrentUser -Force
# Install-Module "Az.Accounts" -Scope CurrentUser -Force
# Install-Module "Az.Resources" -Scope CurrentUser -Force

# --- Conectar como Tenant Admin ---
Login-DataGatewayServiceAccount

# --- Verificar política actual ---
Write-Host "=== Política actual del tenant ===" -ForegroundColor Cyan
Get-DataGatewayTenantPolicy

# --- Restringir gateways personales (nadie puede instalarlos) ---
Write-Host "`nAplicando restricción de gateways personales..." -ForegroundColor Yellow
Set-DataGatewayTenantPolicy -PersonalGatewayInstallPolicy Restricted

# --- Verificar cambio ---
Write-Host "`n=== Política actualizada ===" -ForegroundColor Green
Get-DataGatewayTenantPolicy