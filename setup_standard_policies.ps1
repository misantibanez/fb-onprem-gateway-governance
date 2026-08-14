#=============================================================================
# setup_standard_policies_groups.ps1
# Restringe gateways standard (Resource) a usuarios autorizados.
# Soporta usuarios individuales y grupos de Entra ID.
# Los grupos se expanden a sus usuarios miembros, incluyendo grupos anidados.
# Solo estos usuarios podrán instalar gateways en las VMs definidas.
# Requiere: Tenant Admin o Gateway Admin.
#=============================================================================

# --- Conectar a Azure AD (para resolver Object IDs) ---
Connect-AzAccount

# --- Conectar al servicio de Data Gateway ---
pwsh
Login-DataGatewayServiceAccount

# --- 1. Restringir la política de gateways standard a nivel tenant ---
Write-Host "Restringiendo política de gateway standard..." -ForegroundColor Yellow
Set-DataGatewayTenantPolicy -ResourceGatewayInstallPolicy Restricted

# --- 2. Definir identidades autorizadas ---
# Usuarios individuales por UPN. Dejar @() si no se necesitan usuarios directos.
$authorizedUsers = @(
    "usuario2@dominio.co"
    # "usuario3@dominio.com"
)

# Grupos de Entra ID por DisplayName.
# Todos sus usuarios miembros serán autorizados. También se procesan grupos anidados.
$authorizedGroups = @(
    # "Gateway Installers"
    # "Otro Grupo Autorizado"
)

# Colección final de Object IDs de usuarios, evitando duplicados.
$objectIds = [System.Collections.Generic.HashSet[string]]::new()

# Mantiene registro de grupos procesados para evitar ciclos en grupos anidados.
$processedGroupIds = [System.Collections.Generic.HashSet[string]]::new()

function Add-AuthorizedUser {
    param(
        [Parameter(Mandatory = $true)]
        [string]$UserObjectId,

        [string]$Source = "usuario directo"
    )

    $user = Get-AzADUser -ObjectId $UserObjectId -ErrorAction SilentlyContinue

    if ($user) {
        if ($objectIds.Add([string]$user.Id)) {
            $displayName = if ($user.UserPrincipalName) { $user.UserPrincipalName } else { $user.DisplayName }
            Write-Host "  Usuario: $displayName -> $($user.Id) [$Source]" -ForegroundColor Gray
        }
        return $true
    }

    return $false
}

function Add-AuthorizedGroupMembers {
    param(
        [Parameter(Mandatory = $true)]
        [string]$GroupObjectId,

        [Parameter(Mandatory = $true)]
        [string]$GroupName
    )

    # Evitar volver a procesar el mismo grupo (y posibles ciclos).
    if (-not $processedGroupIds.Add($GroupObjectId)) {
        return
    }

    Write-Host "  Procesando grupo: $GroupName -> $GroupObjectId" -ForegroundColor Cyan

    $members = Get-AzADGroupMember -GroupObjectId $GroupObjectId -ErrorAction SilentlyContinue

    if (-not $members) {
        Write-Warning "  El grupo '$GroupName' no tiene miembros o no se pudieron consultar."
        return
    }

    foreach ($member in $members) {
        $memberId = [string]$member.Id

        # Primero intentar resolver el miembro como usuario.
        if (Add-AuthorizedUser -UserObjectId $memberId -Source "grupo: $GroupName") {
            continue
        }

        # Si no es usuario, intentar resolverlo como grupo anidado.
        $nestedGroup = Get-AzADGroup -ObjectId $memberId -ErrorAction SilentlyContinue
        if ($nestedGroup) {
            Add-AuthorizedGroupMembers `
                -GroupObjectId ([string]$nestedGroup.Id) `
                -GroupName $nestedGroup.DisplayName
            continue
        }

        Write-Warning "  Miembro no compatible u objeto no resuelto: $memberId (grupo '$GroupName')"
    }
}

# --- 2A. Resolver usuarios individuales ---
foreach ($upn in $authorizedUsers) {
    if ([string]::IsNullOrWhiteSpace($upn)) {
        continue
    }

    $user = Get-AzADUser -UserPrincipalName $upn -ErrorAction SilentlyContinue

    if ($user) {
        [void]$objectIds.Add([string]$user.Id)
        Write-Host "  Usuario directo: $upn -> $($user.Id)" -ForegroundColor Gray
    } else {
        Write-Warning "  No se encontró el usuario: $upn"
    }
}

# --- 2B. Resolver grupos y expandir sus usuarios miembros ---
foreach ($groupName in $authorizedGroups) {
    if ([string]::IsNullOrWhiteSpace($groupName)) {
        continue
    }

    $groups = @(Get-AzADGroup -DisplayName $groupName -ErrorAction SilentlyContinue)

    if ($groups.Count -eq 0) {
        Write-Warning "  No se encontró el grupo: $groupName"
        continue
    }

    if ($groups.Count -gt 1) {
        Write-Warning "  Se encontraron varios grupos con DisplayName '$groupName'. Se procesarán todos. Para máxima precisión, use nombres de grupo únicos."
    }

    foreach ($group in $groups) {
        Add-AuthorizedGroupMembers `
            -GroupObjectId ([string]$group.Id) `
            -GroupName $group.DisplayName
    }
}

# Convertir HashSet a array para Set-DataGatewayInstaller.
$principalObjectIds = @($objectIds)

# --- 3. Asignar permisos de instalación de gateway standard (Resource) ---
if ($principalObjectIds.Count -gt 0) {
    Write-Host "`nAsignando permisos de gateway standard a $($principalObjectIds.Count) usuario(s)..." -ForegroundColor Yellow

    Set-DataGatewayInstaller `
        -PrincipalObjectIds $principalObjectIds `
        -Operation Add `
        -GatewayType Resource

    Write-Host "Permisos asignados correctamente." -ForegroundColor Green
} else {
    Write-Warning "No se resolvieron usuarios autorizados. No se asignaron permisos."
}

# --- 4. Verificar configuración final ---
Write-Host "`n=== Política del tenant ===" -ForegroundColor Cyan
Get-DataGatewayTenantPolicy

Write-Host "`n=== Instaladores autorizados ===" -ForegroundColor Cyan
Get-DataGatewayInstaller
