# Fabric Gateway Administration

Scripts de PowerShell para administrar las políticas de instalación de **On-premises Data Gateways** a nivel tenant en Microsoft Fabric / Power Platform.

## Objetivo

- **Bloquear** la creación de gateways de tipo **Personal** para todos los usuarios del tenant.
- **Restringir** la instalación de gateways de tipo **Standard (Resource)** únicamente a usuarios o grupos autorizados, quienes los instalarán en las VMs designadas.

## Prerequisitos

### PowerShell 7+

Los cmdlets del módulo `DataGateway` requieren **PowerShell 7 o superior**. No funcionan en Windows PowerShell 5.1.

```powershell
# Verificar versión actual
$PSVersionTable.PSVersion

# Instalar PowerShell 7 (si no lo tienes)
winget install --id Microsoft.PowerShell --source winget
```

> Después de instalar, abre una nueva terminal de **pwsh** (no `powershell.exe`).

### Módulos de PowerShell

```powershell
Install-Module "DataGateway" -Scope CurrentUser -Force
Install-Module "Az.Accounts" -Scope CurrentUser -Force
Install-Module "Az.Resources" -Scope CurrentUser -Force
```

### Permisos requeridos

- La cuenta que ejecute los scripts debe ser **Tenant Admin** o **Gateway Admin** en Power Platform.
- Se requiere acceso a **Microsoft Entra ID** (Azure AD) para resolver Object IDs de usuarios/grupos.

## Scripts

### 1. `setup_personal_restricted.ps1`

Bloquea la instalación de gateways personales en todo el tenant.

| Acción | Cmdlet |
|---|---|
| Conectar al servicio | `Login-DataGatewayServiceAccount` |
| Restringir gateways personales | `Set-DataGatewayTenantPolicy -PersonalGatewayInstallPolicy Restricted` |
| Verificar política | `Get-DataGatewayTenantPolicy` |

**Ejecución:**

```powershell
pwsh -File .\setup_personal_restricted.ps1
```

### 2. `setup_standard_policies.ps1`

Restringe los gateways standard (Resource) y autoriza solo a usuarios específicos para instalarlos en las VMs definidas.

| Paso | Acción | Cmdlet |
|---|---|---|
| 1 | Restringir política standard | `Set-DataGatewayTenantPolicy -ResourceGatewayInstallPolicy Restricted` |
| 2 | Resolver Object IDs de usuarios | `Get-AzADUser -UserPrincipalName <UPN>` |
| 3 | Autorizar usuarios para gateway standard | `Set-DataGatewayInstaller -GatewayType Resource -Operation Add` |
| 4 | Verificar configuración | `Get-DataGatewayTenantPolicy` / `Get-DataGatewayInstaller` |

**Configuración:** editar el array `$authorizedUsers` con los UPNs de los usuarios autorizados:

```powershell
$authorizedUsers = @(
    "usuario1@dominio.com"
    "usuario2@dominio.com"
)
```

**Alternativa con grupo de Entra ID:** descomentar la sección de grupo y comentar el array de usuarios individuales:

```powershell
$groupId = (Get-AzADGroup -DisplayName "Gateway Installers").Id
$objectIds = @($groupId)
```

**Ejecución:**

```powershell
pwsh -File .\setup_standard_policies.ps1
```

## Orden de ejecución

```
1. setup_personal_restricted.ps1   → Bloquea gateways personales
2. setup_standard_policies.ps1     → Restringe standard y autoriza usuarios
```

## Valores de política

| Valor | Comportamiento |
|---|---|
| `Open` | Cualquier usuario puede instalar gateways |
| `Restricted` | Solo usuarios autorizados vía `Set-DataGatewayInstaller` |
| `None` | Sin política definida (comportamiento por defecto) |

## Tipos de gateway

| GatewayType | Descripción |
|---|---|
| `Resource` | Gateway standard (on-premises) — se instala en VMs compartidas |
| `Personal` | Gateway personal — uso individual, no recomendado para producción |
| `VirtualNetwork` | Gateway de red virtual (VNet) |

## Verificación post-ejecución

```powershell
# Ver política del tenant
Get-DataGatewayTenantPolicy

# Ver usuarios autorizados
Get-DataGatewayInstaller

# Ver clusters de gateway existentes
Get-DataGatewayCluster
```

## Revertir cambios

```powershell
# Abrir gateways personales de nuevo
Set-DataGatewayTenantPolicy -PersonalGatewayInstallPolicy Open

# Abrir gateways standard de nuevo
Set-DataGatewayTenantPolicy -ResourceGatewayInstallPolicy Open

# Remover un usuario autorizado
$userId = (Get-AzADUser -UserPrincipalName "usuario@dominio.com").Id
Set-DataGatewayInstaller -PrincipalObjectIds $userId -Operation Remove -GatewayType Resource
```

## Referencia

- [Módulo DataGateway - PowerShell](https://learn.microsoft.com/en-us/powershell/module/datagateway/?view=datagateway-ps)
- [Set-DataGatewayTenantPolicy](https://learn.microsoft.com/en-us/powershell/module/datagateway/set-datagatewaytenantpolicy?view=datagateway-ps)
- [Set-DataGatewayInstaller](https://learn.microsoft.com/en-us/powershell/module/datagateway/set-datagatewayinstaller?view=datagateway-ps)
- [Get-DataGatewayInstaller](https://learn.microsoft.com/en-us/powershell/module/datagateway/get-datagatewayinstaller?view=datagateway-ps)
