<#
.SYNOPSIS
    Runs the tenant-side half of an IT employee termination, safely and reversibly.

.DESCRIPTION
    Companion tool to the run book "Terminating an IT Employee with Privileged Access".

    Handles every account the person holds (daily driver and privileged admin account),
    in the correct order: admin account first, because it is the one that can undo your work.

    DESIGN PROPERTIES, all deliberate:

      * NOTHING IS EVER DELETED. The script has no DELETE verb against a user object.
        It disables, revokes, and removes role assignments. All of that is reversible.
        Deleting the admin account orphans sole ownerships (subscriptions, app
        registrations, vendor portals), so this tool refuses to be the thing that does it.

      * Report mode is the default. It writes nothing. You must pass a confirmation
        token produced BY the report to run Execute, so you cannot execute blind.

      * Irreversible actions (Intune wipe/retire) are NOT in the default Execute path.
        They require -IncludeDeviceActions and are gated behind their own confirmation.

      * A rollback journal is written before the first change, and -Mode Rollback
        replays it. For the "we ran it against the wrong person" case.

      * Raw Graph calls via Invoke-MgGraphRequest, so the only module required is
        Microsoft.Graph.Authentication, which IS preinstalled in Azure Cloud Shell.
        Get-MgUser and the Intune cmdlets are NOT preinstalled there.

    WHAT THIS TOOL CANNOT DO, and does not pretend to:

      * On-premises Active Directory. Cloud Shell has no line of sight to a domain
        controller. The script GENERATES a signed-off on-prem script for you to run
        on a domain-joined host; it never claims the on-prem half is done.
      * The privileged residue (registrar, backup console, firewalls, vendor portals,
        physical). None of that is an API. It is emitted as a task list in the dossier.
      * Mailbox conversion, unless -IncludeMailbox is passed and ExchangeOnlineManagement
        is available. It is a separate switch because it is a separate failure domain.

.PARAMETER TenantId
    The tenant, as EITHER a verified domain (contoso.com) or the tenant GUID. Both are
    accepted, because Connect-MgGraph accepts both and a human is far more likely to
    type the domain. Asserted against the connected tenant before any write: this is
    the guard against terminating someone in the wrong tenant, which for an MSP is not
    a hypothetical. Aliases: -Tenant, -TenantDomain.

.PARAMETER PrimaryUpn
    The account to TERMINATE: the person's everyday account, the one with the mailbox.
    Aliases: -TerminateUpn, -UserUpn, -User.

    If this or -TenantId is omitted the script asks for it in plain words rather than
    letting PowerShell prompt with a bare parameter name.

.PARAMETER AdminUpn
    The privileged account. Optional when -PrimaryUpn is given, in which case the script
    hunts for it and refuses to proceed in Execute mode if it finds a candidate you did
    not declare.

    It can also be supplied ALONE, with no -PrimaryUpn, for someone who only ever had an
    admin account: contractors, MSP engineers, service admins, test accounts. In that
    mode the admin account anchors the run and no mailbox work is attempted.
    Aliases: -PrivilegedUpn, -AdminAccount.

.PARAMETER SearchName
    Surname or display-name fragment, used to hunt for accounts you did not know about.
    Defaults to the target's surname READ FROM THE DIRECTORY, falling back to the last
    token of their display name. It is not guessed from the UPN, because local parts
    like 'lidiah' have no separator to split on.

.PARAMETER ProtectedUpns
    Accounts this tool must never touch. Break-glass accounts belong here. The
    signed-in operator is added automatically.

.PARAMETER ConfirmationToken
    Produced by Report mode. Required by Execute mode. Binds the run to a specific
    tenant and a specific set of target object IDs.

.PARAMETER InstallPrerequisites
    Install missing modules without prompting. Without it, the script asks; with
    -NonInteractive as well, a missing required module is a hard stop.
    In Cloud Shell, installed modules persist only if a storage account is attached.

.PARAMETER UseDeviceCode
    Force device code sign-in. Auto-selected in Cloud Shell, which has no browser.

.PARAMETER ElevateWithPim
    If the operator holds no standing privilege but IS eligible, activate the roles
    needed and continue. Without it the script stops and tells them to activate.
    It activates the NARROWEST roles that satisfy the run (Privileged Authentication
    Administrator and Privileged Role Administrator), and only reaches for Global
    Administrator if those are not among the eligibilities.

.PARAMETER ElevationHours
    Activation duration. Default 2. Your PIM policy's maximum still wins.

.EXAMPLE
    # First run on a new machine, operator has to PIM up first.
    ./Invoke-ITTermination.ps1 -TenantId <guid> -PrimaryUpn jdoe@contoso.com `
        -AdminUpn adm-jdoe@contoso.onmicrosoft.com -Mode Execute `
        -ConfirmationToken A1B2C3D4E5F6 -InstallPrerequisites -ElevateWithPim

.EXAMPLE
    # 1. Discovery. Writes nothing.
    ./Invoke-ITTermination.ps1 -TenantId <guid> -PrimaryUpn jdoe@contoso.com

.EXAMPLE
    # 2. The cut, using the token the report printed.
    ./Invoke-ITTermination.ps1 -TenantId <guid> -PrimaryUpn jdoe@contoso.com `
        -AdminUpn adm-jdoe@contoso.onmicrosoft.com -Mode Execute -ConfirmationToken A1B2C3D4E5F6

.EXAMPLE
    # 3. Prove it.
    ./Invoke-ITTermination.ps1 -TenantId <guid> -PrimaryUpn jdoe@contoso.com `
        -AdminUpn adm-jdoe@contoso.onmicrosoft.com -Mode Validate

.NOTES
    Version : 1.4.0
    Licence : MIT
    Requires: PowerShell 7.2 or later, Microsoft.Graph.Authentication 2.0+
    Runs in : Azure Cloud Shell (PowerShell 7.4), or any PS7 host

    Windows PowerShell 5.1 is not supported and the #Requires above will stop it.

    Graph API version is pinned to v1.0 throughout. Where an operation only exists in
    beta it is reported, not performed.

    Verified against a mock Graph harness: 27 tests covering the safety gates, the
    admin-first ordering, the PIM elevation path, domain-or-GUID tenant matching, and
    the assertion that no irreversible action is ever journalled as reversible. The
    gate tests assert the REASON a run was refused, not merely that it threw.

    1.4.0  EITHER account may be supplied now, not just the everyday one. Some people
           being terminated only ever had an admin account (contractors, MSP engineers,
           service admins, test accounts); forcing that into the everyday slot
           mislabelled it. Whichever account is given anchors the search term and the
           banner, and the mailbox step is skipped when there is no everyday account.
    1.3.1  The privileged-everyday-account warning now branches on whether an admin
           account was declared, so it stops suggesting the accounts are reversed when
           only one was supplied.
    1.3.0  Prerequisites are checked BEFORE the interactive prompts, so a missing
           module fails before anyone types anything. Active and eligible role NAMES
           are printed, not just a count. An everyday account that holds privileged
           roles is flagged as an anti-pattern or a mislabelled pair. Read-Host is
           null-guarded for redirected stdin.
    1.2.0  Tenant accepts a verified domain as well as the GUID (a domain was a false
           mismatch before). Search term now read from the directory surname instead of
           parsed out of the UPN. Guided plain-language prompts for the tenant and the
           account to terminate. Accounts labelled PRIVILEGED / EVERYDAY in output.
    1.1.0  Prerequisite bootstrap, Cloud Shell detection, PIM self-elevation.
    1.0.0  Initial.
#>

#Requires -Version 7.2

[CmdletBinding()]
param(
    # Accepts a domain (contoso.com) or the tenant GUID. Not mandatory at the binding
    # level on purpose: PowerShell's own prompt just prints the parameter name, which
    # reads like it demands a GUID. The script asks in plain words instead.
    [Alias('Tenant','TenantDomain')]
    [Parameter(HelpMessage = 'Tenant domain (contoso.com) or tenant GUID')]
    [string]   $TenantId,

    # The person being terminated: their normal, everyday account.
    [Alias('TerminateUpn','UserUpn','User')]
    [Parameter(HelpMessage = 'UPN of the account to TERMINATE (their everyday account, the one with the mailbox)')]
    [string]   $PrimaryUpn,

    # Their separate privileged account, if they have one.
    [Alias('PrivilegedUpn','AdminAccount')]
    [Parameter(HelpMessage = 'UPN of their separate ADMIN account, if they have one')]
    [string]   $AdminUpn,

    [string]   $SearchName,
    [ValidateSet('Report','Execute','Validate','Rollback')]
    [string]   $Mode = 'Report',
    [string]   $ConfirmationToken,
    [string[]] $ProtectedUpns = @(),
    [switch]   $IncludeDeviceActions,
    [switch]   $IncludeMailbox,
    [string]   $SharedMailboxDelegate,
    [string]   $OutputPath = (Join-Path (Get-Location) 'termination-dossier'),
    [string]   $RollbackJournal,

    # Prerequisites and authentication
    [switch]   $InstallPrerequisites,
    [switch]   $UseDeviceCode,
    [switch]   $NonInteractive,

    # PIM self-elevation
    [switch]   $ElevateWithPim,
    [int]      $ElevationHours = 2,
    [string]   $ElevationJustification = 'IT employee termination run book'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:Version    = '1.4.0'
$script:GraphBase  = 'https://graph.microsoft.com/v1.0'

# Immutable role template IDs, verified against Microsoft Entra built-in roles.
# Display names are never used for a safety-critical lookup.
$script:RoleGA     = '62e90394-69f5-4237-9190-012177145e10'  # Global Administrator
$script:RolePAA    = '7be44c8a-adaf-4e2a-84d6-ab2649e08a13'  # Privileged Authentication Administrator
$script:RolePRA    = 'e8611ab8-c189-46e8-94e1-60213ab1f814'  # Privileged Role Administrator
$script:Journal    = [System.Collections.Generic.List[object]]::new()
$script:Findings   = [ordered]@{}

#region helpers -----------------------------------------------------------------

function Write-Step {
    param([string]$Message, [ValidateSet('Info','Good','Warn','Bad','Head')][string]$Level = 'Info')
    $colour = @{ Info='Gray'; Good='Green'; Warn='Yellow'; Bad='Red'; Head='Cyan' }[$Level]
    $stamp  = (Get-Date).ToString('HH:mm:ss')
    if ($Level -eq 'Head') { Write-Host '' }
    Write-Host "[$stamp] $Message" -ForegroundColor $colour
}

function Stop-Run {
    param([string]$Reason)
    Write-Step "REFUSING TO PROCEED: $Reason" -Level Bad
    throw $Reason
}

# Graph wrapper with paging. Everything goes through here so the API version,
# error handling, and throttling behaviour are in exactly one place.
function Invoke-Graph {
    param(
        [Parameter(Mandatory)][ValidateSet('GET','POST','PATCH','DELETE')][string]$Method,
        [Parameter(Mandatory)][string]$Uri,
        [object]$Body,
        [switch]$All
    )
    if ($Uri -notmatch '^https://') { $Uri = "$script:GraphBase$Uri" }

    $results = [System.Collections.Generic.List[object]]::new()
    $next    = $Uri

    do {
        $splat = @{ Method = $Method; Uri = $next; OutputType = 'PSObject' }
        if ($PSBoundParameters.ContainsKey('Body') -and $null -ne $Body) {
            $splat.Body        = ($Body | ConvertTo-Json -Depth 10 -Compress)
            $splat.ContentType = 'application/json'
        }
        # ConsistencyLevel is required for $search and advanced $filter/$count.
        if ($next -match '\$search|\$count') { $splat.Headers = @{ ConsistencyLevel = 'eventual' } }

        $attempt = 0
        while ($true) {
            try { $response = Invoke-MgGraphRequest @splat; break }
            catch {
                $status = $null
                try { $status = $_.Exception.Response.StatusCode.value__ } catch { }
                if ($status -in 429, 503, 504 -and $attempt -lt 4) {
                    $wait = [math]::Pow(2, $attempt) * 2
                    Write-Step "Graph returned $status. Backing off ${wait}s." -Level Warn
                    Start-Sleep -Seconds $wait; $attempt++; continue
                }
                throw
            }
        }

        if ($null -eq $response) { break }
        if ($response.PSObject.Properties.Name -contains 'value') {
            foreach ($item in $response.value) { $results.Add($item) }
            $next = if ($All -and $response.PSObject.Properties.Name -contains '@odata.nextLink') {
                $response.'@odata.nextLink'
            } else { $null }
        }
        else { $results.Add($response); $next = $null }
    } while ($next)

    # The comma is load-bearing. A bare `return $results` unrolls the collection,
    # so an empty result set arrives at the caller as $null and every .Count on it
    # throws under StrictMode. Always hand back a real array.
    return ,$results.ToArray()
}

function Get-GraphUser {
    param([Parameter(Mandatory)][string]$Upn)
    try {
        $props = 'id,userPrincipalName,displayName,givenName,surname,accountEnabled,onPremisesSyncEnabled,mail,createdDateTime,assignedLicenses'
        return (Invoke-Graph -Method GET -Uri "/users/$([uri]::EscapeDataString($Upn))?`$select=$props")[0]
    } catch { return $null }
}

# Binds a run to a tenant and an exact target set. Report prints it, Execute demands it.
function Get-ConfirmationToken {
    param([Parameter(Mandatory)][string[]]$ObjectIds)
    $material = ($TenantId + '|' + (($ObjectIds | Sort-Object) -join '|')).ToLowerInvariant()
    $sha      = [System.Security.Cryptography.SHA256]::Create()
    $hash     = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($material))
    return (($hash | ForEach-Object { $_.ToString('x2') }) -join '').Substring(0, 12).ToUpperInvariant()
}

function Get-RoleLabel {
    param([string]$Role)
    if ($Role -eq 'admin') { 'PRIVILEGED ACCOUNT' } else { 'EVERYDAY ACCOUNT' }
}

function Add-Journal {
    param([string]$Action, [string]$Target, [string]$TargetId, [hashtable]$Undo)
    $script:Journal.Add([pscustomobject]@{
        timestamp = (Get-Date).ToString('o')
        action    = $Action
        target    = $Target
        targetId  = $TargetId
        undo      = $Undo
    })
}

#endregion

#region connect and preflight ---------------------------------------------------

Write-Step "Invoke-ITTermination $script:Version | Mode: $Mode" -Level Head

# --- Prerequisite: PowerShell version --------------------------------------
# #Requires above stops PS5.1 outright. Restated here so the reason is visible.
Write-Step "PowerShell $($PSVersionTable.PSVersion) on $($PSVersionTable.Platform ?? 'Windows')"

# --- Prerequisite: are we in Cloud Shell? ----------------------------------
# Cloud Shell has no browser, so the interactive flow cannot complete there.
$inCloudShell = [bool]($env:ACC_CLOUD -or ($env:POWERSHELL_DISTRIBUTION_CHANNEL -match 'CloudShell'))
if ($inCloudShell) { Write-Step 'Azure Cloud Shell detected. Device code flow will be used.' }

# --- Prerequisite: modules --------------------------------------------------
# Cloud Shell preinstalls only a SUBSET of Microsoft.Graph: Authentication,
# Applications, Groups, Identity.DirectoryManagement, Identity.Governance,
# Identity.SignIns, Users.Actions, Users.Functions. Microsoft.Graph.Users and the
# Intune modules are NOT among them, which is exactly why this script calls Graph
# through Invoke-MgGraphRequest and needs only Authentication.
function Initialize-Prerequisite {
    param([Parameter(Mandatory)][string]$Name, [string]$MinimumVersion, [switch]$Optional)

    $have = Get-Module -ListAvailable -Name $Name |
            Sort-Object Version -Descending | Select-Object -First 1
    if ($have -and (-not $MinimumVersion -or $have.Version -ge [version]$MinimumVersion)) {
        Write-Step "  $Name $($have.Version) present" -Level Good
        return $true
    }

    $what = if ($have) { "$Name $($have.Version) is below the required $MinimumVersion" }
            else       { "$Name is not installed" }

    if (-not $InstallPrerequisites) {
        if ($NonInteractive) {
            if ($Optional) { Write-Step "  $what. Skipping (optional)." -Level Warn; return $false }
            Stop-Run "$what. Re-run with -InstallPrerequisites, or install it yourself."
        }
        Write-Step "  $what." -Level Warn
        $answer = Read-Host "  Install $Name now for the current user? [y/N]"
        if ($answer -notmatch '^[Yy]') {
            if ($Optional) { Write-Step "  Skipping $Name." -Level Warn; return $false }
            Stop-Run "$Name is required and was declined."
        }
    }

    try {
        Write-Step "  Installing $Name (CurrentUser scope)..."
        # In Cloud Shell this persists only if a storage account is attached.
        Install-Module -Name $Name -Scope CurrentUser -Force -AllowClobber `
                       -Repository PSGallery -ErrorAction Stop
        Write-Step "  $Name installed" -Level Good
        return $true
    } catch {
        if ($Optional) { Write-Step "  Could not install $Name : $($_.Exception.Message)" -Level Warn; return $false }
        Stop-Run "Could not install $Name : $($_.Exception.Message)"
    }
}

Write-Step 'Checking prerequisites' -Level Head
$null = Initialize-Prerequisite -Name 'Microsoft.Graph.Authentication' -MinimumVersion '2.0.0'
Import-Module Microsoft.Graph.Authentication -ErrorAction Stop

$exoReady = $false
if ($IncludeMailbox) {
    $exoReady = Initialize-Prerequisite -Name 'ExchangeOnlineManagement' -MinimumVersion '3.0.0' -Optional
}
if ($inCloudShell -and $InstallPrerequisites) {
    Write-Step '  Note: Cloud Shell only persists installed modules when a storage account is attached.' -Level Warn
}

# --- Guided input ----------------------------------------------------------
# Ask in plain words rather than letting PowerShell prompt with bare parameter
# names. "TenantId" reads like it demands a GUID and "PrimaryUpn" does not tell
# anyone which account is about to be disabled.
function Read-Required {
    param([Parameter(Mandatory)][string]$Prompt, [string]$Hint, [switch]$AllowEmpty)

    if ($NonInteractive) { return $null }
    if ($Hint) { Write-Host "    $Hint" -ForegroundColor DarkGray }
    $attempts = 0
    while ($true) {
        # Read-Host returns $null when stdin is not a terminal (redirected input, some
        # CI hosts). Cast before trimming or this throws instead of prompting.
        $value = ([string](Read-Host "  $Prompt")).Trim()
        if ($value)      { return $value }
        if ($AllowEmpty) { return $null }
        if (++$attempts -ge 3) {
            Stop-Run "No value supplied for '$Prompt'. If stdin is redirected, pass it as a parameter instead."
        }
        Write-Host '    A value is required.' -ForegroundColor Yellow
    }
}

if (-not $TenantId) {
    if ($NonInteractive) { Stop-Run 'No tenant supplied. Pass -TenantId (a domain such as contoso.com, or the tenant GUID).' }
    Write-Step 'Which tenant?' -Level Head
    $TenantId = Read-Required -Prompt 'Tenant' -Hint 'A domain such as contoso.com, or the tenant GUID. Both work.'
}

# Either account may be supplied, or both, but not neither. Some people being
# terminated have only ever had an admin account: contractors, MSP engineers,
# service admins, test accounts. Forcing that into the "everyday account" slot
# mislabels it and produces a warning that does not apply.
if (-not $PrimaryUpn -and -not $AdminUpn -and -not $NonInteractive) {
    Write-Step 'Who is being terminated?' -Level Head
    $PrimaryUpn = Read-Required -Prompt 'Their EVERYDAY account (Enter if they only have an admin account)' `
                                -Hint 'The one with the mailbox. Example: jdoe@contoso.com' -AllowEmpty

    $adminHint = if ($PrimaryUpn) {
        'Most IT staff have a second, privileged account. Enter to skip and the script will hunt for it.'
    } else {
        'You skipped the everyday account, so name the admin account here.'
    }
    Write-Host "    $adminHint" -ForegroundColor DarkGray
    $AdminUpn = Read-Required -Prompt 'Their ADMIN account' -AllowEmpty:([bool]$PrimaryUpn)
}
elseif (-not $AdminUpn -and -not $NonInteractive) {
    Write-Host '    Most IT staff have a second, privileged account. Enter to skip and the script will hunt for it.' -ForegroundColor DarkGray
    $AdminUpn = Read-Required -Prompt 'Their ADMIN account (optional, Enter to skip)' -AllowEmpty
}

if (-not $PrimaryUpn -and -not $AdminUpn) {
    Stop-Run 'No account supplied. Pass -PrimaryUpn, or -AdminUpn if they only ever had an admin account.'
}

# Least privilege, deliberately. This tool READS authentication methods and managed
# devices; it does not modify them, so it does not ask for write on either. The
# wipe/retire scope is only requested when -IncludeDeviceActions is actually passed,
# so a routine run cannot wipe anything even by accident.
$scopes = @(
    'User.Read.All'                       # discovery
    'User.ReadWrite.All'                  # accountEnabled=false, revokeSignInSessions
    'Directory.Read.All'                  # owned objects, directory context
    'RoleManagement.ReadWrite.Directory'  # read/remove roles and PIM, self-activate
    'Device.ReadWrite.All'                # disable device objects
    'Application.Read.All'                # owned app registrations
    'UserAuthenticationMethod.Read.All'   # report only, never modified here
    'DeviceManagementManagedDevices.Read.All'
)
if ($IncludeDeviceActions) {
    $scopes += 'DeviceManagementManagedDevices.PrivilegedOperations.All'  # wipe / retire
}

# --- Authenticate -----------------------------------------------------------
# Sign in as the person doing the disablement. Delegated auth means their own
# permissions apply, which is the behaviour we want: the script cannot exceed
# the authority of the human running it.
$context = $null
try { $context = Get-MgContext } catch { }

if (-not $context -or $context.TenantId -ne $TenantId) {
    $useDevice = $UseDeviceCode -or $inCloudShell
    if ($useDevice) {
        Write-Step 'Sign in with device code: a URL and code will be printed below.' -Level Head
    } else {
        Write-Step 'A browser window will open for sign-in.' -Level Head
    }
    $connect = @{ TenantId = $TenantId; Scopes = $scopes; NoWelcome = $true }
    if ($useDevice) { $connect.UseDeviceAuthentication = $true }
    Connect-MgGraph @connect
    $context = Get-MgContext
}

# GATE 1: right tenant. For an MSP this is the difference between a termination
# and an incident.
#
# -TenantId accepts EITHER the GUID or any verified domain, because Connect-MgGraph
# accepts both and a human is far more likely to type the domain. Comparing the
# returned GUID against a typed domain is a false mismatch, so resolve the tenant
# and check the supplied value against its id AND its verified domains.
$org = $null
try { $org = (Invoke-Graph -Method GET -Uri '/organization?$select=id,displayName,verifiedDomains')[0] } catch { }

$verifiedDomains = @()
if ($org -and $org.PSObject.Properties.Name -contains 'verifiedDomains') {
    $verifiedDomains = @($org.verifiedDomains | ForEach-Object { $_.name })
}

$tenantMatches = ($context.TenantId -eq $TenantId) -or
                 ($org -and $org.id -eq $TenantId)  -or
                 ($TenantId -in $verifiedDomains)

if (-not $tenantMatches) {
    $known = if ($verifiedDomains.Count) { $verifiedDomains -join ', ' } else { '(could not read verified domains)' }
    Stop-Run ("You are signed in to tenant $($context.TenantId)" +
              $(if ($org) { " ($($org.displayName))" } else { '' }) +
              ", which does not match -TenantId '$TenantId'. " +
              "Verified domains on the connected tenant: $known")
}

$tenantLabel = if ($org) { "$($org.displayName) [$($org.id)]" } else { $context.TenantId }
Write-Step "Tenant asserted: $tenantLabel" -Level Good

$operator = Get-GraphUser -Upn $context.Account
if (-not $operator) { Stop-Run "Cannot resolve the signed-in operator ($($context.Account))." }
Write-Step "Operator: $($operator.userPrincipalName)" -Level Good

# --- Operator authority, and PIM elevation if they are eligible but not active ---
# The common case for a well-run tenant: the operator holds NOTHING standing and
# has to activate before they can do any of this. Detect it, do not fail at the
# first write with an opaque 403.
function Resolve-OperatorAuthority {
    $needed = @(
        @{ Id = $script:RolePAA; Name = 'Privileged Authentication Administrator'; Why = 'disable an admin account and revoke its sessions' }
        @{ Id = $script:RolePRA; Name = 'Privileged Role Administrator';           Why = 'remove role assignments and PIM eligibility' }
    )

    $active = Invoke-Graph -Method GET -All `
        -Uri "/roleManagement/directory/roleAssignments?`$filter=principalId eq '$($operator.id)'"
    $activeIds = @($active | ForEach-Object { $_.roleDefinitionId })

    if ($script:RoleGA -in $activeIds) {
        Write-Step 'Operator holds Global Administrator (active). Authority satisfied.' -Level Good
        return
    }

    $missing = @($needed | Where-Object { $_.Id -notin $activeIds })
    if ($missing.Count -eq 0) {
        Write-Step 'Operator holds the required roles (active).' -Level Good
        return
    }

    foreach ($m in $missing) { Write-Step "Operator lacks ACTIVE '$($m.Name)', needed to $($m.Why)." -Level Warn }

    # Are they eligible? If so this is a PIM activation, not a permissions problem.
    $eligible = @()
    try {
        $eligible = Invoke-Graph -Method GET -All `
            -Uri "/roleManagement/directory/roleEligibilityScheduleInstances?`$filter=principalId eq '$($operator.id)'"
    } catch { Write-Step 'Could not read operator PIM eligibility.' -Level Warn }
    $eligibleIds = @($eligible | ForEach-Object { $_.roleDefinitionId })

    $canElevate = @($missing | Where-Object { $_.Id -in $eligibleIds })
    $gaEligible = ($script:RoleGA -in $eligibleIds)

    if ($canElevate.Count -eq 0 -and -not $gaEligible) {
        Write-Step 'Operator is not eligible for the missing roles either. This run will fail on the first write.' -Level Bad
        Write-Step 'Have someone with the authority run it, or get the eligibility assigned first.' -Level Bad
        if (-not $NonInteractive) {
            $go = Read-Host 'Continue anyway? [y/N]'
            if ($go -notmatch '^[Yy]') { Stop-Run 'Operator lacks the required authority.' }
        }
        return
    }

    # Prefer activating exactly what is missing over reaching for Global Administrator.
    $toActivate = if ($canElevate.Count -gt 0) { $canElevate }
                  else { @(@{ Id = $script:RoleGA; Name = 'Global Administrator'; Why = 'perform this run' }) }

    Write-Step "Operator is ELIGIBLE for: $(($toActivate | ForEach-Object { $_.Name }) -join ', ')" -Level Good

    if (-not $ElevateWithPim) {
        if ($NonInteractive) {
            Stop-Run 'Operator must activate PIM first. Re-run with -ElevateWithPim, or activate in the portal.'
        }
        $go = Read-Host "  Activate via PIM now for $ElevationHours hour(s)? [y/N]"
        if ($go -notmatch '^[Yy]') {
            Stop-Run 'Operator declined PIM activation. Activate in the portal, then re-run.'
        }
    }

    foreach ($role in $toActivate) {
        Write-Step "  Activating $($role.Name)..."
        $body = @{
            action           = 'selfActivate'
            principalId      = $operator.id
            roleDefinitionId = $role.Id
            directoryScopeId = '/'
            justification    = $ElevationJustification
            scheduleInfo     = @{
                startDateTime = (Get-Date).ToUniversalTime().ToString('o')
                expiration    = @{ type = 'AfterDuration'; duration = "PT$($ElevationHours)H" }
            }
        }
        try {
            $req = (Invoke-Graph -Method POST -Uri '/roleManagement/directory/roleAssignmentScheduleRequests' -Body $body)[0]

            # Status handling, per the documented Graph enum. Two traps:
            #  * ScheduleCreated is TRANSITIONAL, not a resting state.
            #  * Granted is the settled status only of a FUTURE-DATED selfActivate.
            #    We always request start=now, so it is transitional here too. If you
            #    ever date-shift scheduleInfo, revisit both.
            #  * An approval-required role never reaches a terminal state without a
            #    human, so PendingApproval is a clean exit, not a failure.
            $done    = @('Provisioned')
            $waiting = @('PendingApproval','PendingAdminDecision')
            $bad     = @('Denied','Failed','Canceled','Revoked')

            $deadline = (Get-Date).AddMinutes(3)
            while ($req.status -notin $done -and (Get-Date) -lt $deadline) {
                if ($req.status -in $waiting) {
                    Write-Step "  $($role.Name) is awaiting approval ($($req.status)). Approve it, then re-run this script." -Level Warn
                    Stop-Run 'PIM activation needs a human approver.'
                }
                if ($req.status -in $bad) { Stop-Run "PIM activation for $($role.Name) ended as $($req.status)." }
                Start-Sleep -Seconds 5
                $req = (Invoke-Graph -Method GET -Uri "/roleManagement/directory/roleAssignmentScheduleRequests/$($req.id)")[0]
            }

            if ($req.status -in $done) { Write-Step "  $($role.Name) activated ($($req.status))" -Level Good }
            else { Stop-Run "PIM activation for $($role.Name) did not settle (last status: $($req.status))." }
        } catch {
            if ($_.Exception.Message -match 'RoleAssignmentExists') {
                Write-Step "  $($role.Name) was already active." -Level Good
            } else { throw }
        }
    }

    # The access token carries the role claims it was minted with, so a token
    # issued before activation does not know about the new role. Re-connect.
    Write-Step '  Refreshing the Graph token so the new role is in scope.'
    $useDevice = $UseDeviceCode -or $inCloudShell
    $reconnect = @{ TenantId = $TenantId; Scopes = $scopes; NoWelcome = $true }
    if ($useDevice) { $reconnect.UseDeviceAuthentication = $true }
    Connect-MgGraph @reconnect
    Write-Step '  Token refreshed.' -Level Good
}

if ($Mode -in 'Execute','Rollback') { Resolve-OperatorAuthority }
else { Write-Step 'Report/Validate mode: read-only, skipping the authority check.' }

# The operator can never be a target. This is the self-lockout guard.
$protected = @($ProtectedUpns) + @($operator.userPrincipalName) |
             Where-Object { $_ } | ForEach-Object { $_.ToLowerInvariant() } | Select-Object -Unique

#endregion

#region discovery ---------------------------------------------------------------

# Derive the search term from the DIRECTORY, not by guessing at the UPN. Parsing a
# local part is unreliable: 'lidiah' has no separator to split on, and stripping a
# leading initial turns it into 'idiah', which matches nobody. Ask Graph instead.
# The anchor is whichever account we were given. It supplies the search term and the
# banner. Usually the everyday account; the admin account when that is all there is.
$anchorUpn  = if ($PrimaryUpn) { $PrimaryUpn } else { $AdminUpn }
$anchorUser = Get-GraphUser -Upn $anchorUpn
if (-not $anchorUser) { Stop-Run "'$anchorUpn' does not resolve in this tenant." }
$primaryUser = if ($PrimaryUpn) { $anchorUser } else { $null }

if (-not $SearchName) {
    $SearchName =
        if ($anchorUser.surname)     { $anchorUser.surname }
        elseif ($anchorUser.displayName -and $anchorUser.displayName -match '\s') {
            ($anchorUser.displayName -split '\s+')[-1]       # last token of the display name
        }
        else { ($anchorUpn -split '@')[0] }                  # last resort, the whole local part
}

Write-Step "TO BE TERMINATED: $($anchorUser.displayName) <$($anchorUser.userPrincipalName)>" -Level Warn
if ($PrimaryUpn -and $AdminUpn) {
    Write-Step "  plus their admin account: $AdminUpn" -Level Warn
}
elseif (-not $PrimaryUpn) {
    Write-Step '  Admin account only. No everyday account was supplied, so no mailbox work will be attempted.' -Level Warn
}
Write-Step "Discovering accounts matching '$SearchName'" -Level Head
if (-not $AdminUpn) {
    Write-Step 'No -AdminUpn declared. Anything the search turns up will be reported as undeclared.' -Level Warn
}

$candidates = @()
try {
    $q = "/users?`$search=`"displayName:$SearchName`" OR `"userPrincipalName:$SearchName`"" +
         "&`$select=id,userPrincipalName,displayName,accountEnabled,onPremisesSyncEnabled,mail,assignedLicenses"
    $candidates = Invoke-Graph -Method GET -Uri $q -All
} catch {
    Write-Step "Search failed ($($_.Exception.Message)). Falling back to declared accounts only." -Level Warn
}

$targets = [System.Collections.Generic.List[object]]::new()
foreach ($upn in @($AdminUpn, $PrimaryUpn) | Where-Object { $_ }) {
    $u = Get-GraphUser -Upn $upn
    if (-not $u) { Stop-Run "Declared account '$upn' does not resolve." }
    if ($u.userPrincipalName.ToLowerInvariant() -in $protected) {
        Stop-Run "'$upn' is a protected account (operator or break-glass). Refusing."
    }
    $roleLabel = if ($AdminUpn -and $upn -eq $AdminUpn) { 'admin' } else { 'primary' }
    $u | Add-Member -NotePropertyName role -NotePropertyValue $roleLabel -Force
    $targets.Add($u)
}

# Undeclared candidates. In Report these are advice; in Execute they are a stop.
$declaredIds = $targets.id
$undeclared  = @($candidates | Where-Object {
    $_.id -notin $declaredIds -and $_.userPrincipalName.ToLowerInvariant() -notin $protected
})

foreach ($c in $undeclared) {
    $sync = if ($c.onPremisesSyncEnabled) { 'synced' } else { 'CLOUD-ONLY' }
    Write-Step "Undeclared account found: $($c.userPrincipalName) [$sync]" -Level Warn
}

# Profile every declared target.
foreach ($t in $targets) {
    Write-Step "Profiling $($t.userPrincipalName) [$(Get-RoleLabel $t.role)]" -Level Head

    $activeRoles = Invoke-Graph -Method GET -All `
        -Uri "/roleManagement/directory/roleAssignments?`$filter=principalId eq '$($t.id)'&`$expand=roleDefinition"

    $eligible = @()
    try {
        $eligible = Invoke-Graph -Method GET -All `
            -Uri "/roleManagement/directory/roleEligibilityScheduleInstances?`$filter=principalId eq '$($t.id)'&`$expand=roleDefinition"
    } catch { Write-Step '  PIM eligible read failed (no P2 licence, or no permission).' -Level Warn }

    $devices  = Invoke-Graph -Method GET -All -Uri "/users/$($t.id)/registeredDevices"
    $owned    = Invoke-Graph -Method GET -All -Uri "/users/$($t.id)/ownedObjects"

    $managed = @()
    try {
        $managed = Invoke-Graph -Method GET -All `
            -Uri "/deviceManagement/managedDevices?`$filter=userId eq '$($t.id)'"
    } catch { Write-Step '  Intune read failed (no licence, or no permission).' -Level Warn }

    $methods = @()
    try { $methods = Invoke-Graph -Method GET -All -Uri "/users/$($t.id)/authentication/methods" } catch { }

    $ownedApps    = @($owned | Where-Object { $_.'@odata.type' -eq '#microsoft.graph.application' })
    $ownedGroups  = @($owned | Where-Object { $_.'@odata.type' -eq '#microsoft.graph.group' })

    $t | Add-Member -NotePropertyName activeRoles     -NotePropertyValue $activeRoles -Force
    $t | Add-Member -NotePropertyName eligibleRoles   -NotePropertyValue $eligible    -Force
    $t | Add-Member -NotePropertyName devices         -NotePropertyValue $devices     -Force
    $t | Add-Member -NotePropertyName managedDevices  -NotePropertyValue $managed     -Force
    $t | Add-Member -NotePropertyName ownedApps       -NotePropertyValue $ownedApps   -Force
    $t | Add-Member -NotePropertyName ownedGroups     -NotePropertyValue $ownedGroups -Force
    $t | Add-Member -NotePropertyName authMethods     -NotePropertyValue $methods     -Force

    Write-Step ("  roles active={0} eligible={1} devices={2} intune={3} ownedApps={4} ownedGroups={5}" -f `
        $activeRoles.Count, $eligible.Count, $devices.Count, $managed.Count, $ownedApps.Count, $ownedGroups.Count)

    # Name the roles. A count is not reviewable, and Report exists to be reviewed.
    foreach ($r in $activeRoles)  { Write-Step "    active:   $($r.roleDefinition.displayName)" }
    foreach ($e in $eligible)     { Write-Step "    eligible: $($e.roleDefinition.displayName)" }

    # The everyday account is not supposed to hold privilege. If it does, either this
    # estate does not separate admin accounts, or the two accounts have been passed the
    # wrong way round. Both are worth stopping to look at.
    if ($t.role -eq 'primary' -and ($activeRoles.Count -gt 0 -or $eligible.Count -gt 0)) {
        $holdsGa = ($script:RoleGA -in @($activeRoles | ForEach-Object { $_.roleDefinitionId })) -or
                   ($script:RoleGA -in @($eligible    | ForEach-Object { $_.roleDefinitionId }))
        Write-Step "  NOTE: this EVERYDAY account holds privileged roles$(if ($holdsGa) { ', including GLOBAL ADMINISTRATOR' })." -Level Warn
        if ($AdminUpn) {
            # Two accounts were declared and the wrong one carries the privilege.
            Write-Step '        You declared a separate admin account, yet the privilege is on this one.' -Level Warn
            Write-Step '        Check that -PrimaryUpn and -AdminUpn are not the wrong way round: the run book cuts the privileged account FIRST.' -Level Warn
        } else {
            # One account doing both jobs. Either the estate does not separate them, or
            # this IS the admin account and was passed in the wrong slot.
            Write-Step '        No separate admin account was declared, so either this estate does not use one,' -Level Warn
            Write-Step '        or this IS their admin account and belongs in -AdminUpn instead.' -Level Warn
            Write-Step '        If they genuinely have only one account, this is fine and the ordering does not matter.' -Level Warn
        }
    }
}

# GATE 2: the last-Global-Administrator guard.
$allGa = Invoke-Graph -Method GET -All `
    -Uri "/roleManagement/directory/roleAssignments?`$filter=roleDefinitionId eq '$script:RoleGA'"
$survivingGa = @($allGa | Where-Object { $_.principalId -notin $targets.id })
$gaLevel = if ($survivingGa.Count -lt 1) { 'Bad' } elseif ($survivingGa.Count -lt 2) { 'Warn' } else { 'Good' }
Write-Step "Global Administrators: $($allGa.Count) total, $($survivingGa.Count) would survive this run" -Level $gaLevel

$token = Get-ConfirmationToken -ObjectIds $targets.id

#endregion

#region report ------------------------------------------------------------------

$null = New-Item -ItemType Directory -Path $OutputPath -Force
$stamp      = (Get-Date).ToString('yyyyMMdd-HHmmss')
$dossierPath = Join-Path $OutputPath "dossier-$stamp.json"

$dossier = [ordered]@{
    tool           = 'Invoke-ITTermination'
    version        = $script:Version
    mode           = $Mode
    generatedUtc   = (Get-Date).ToUniversalTime().ToString('o')
    tenantId       = $TenantId
    operator       = $operator.userPrincipalName
    confirmToken   = $token
    targets        = @($targets | ForEach-Object {
        [ordered]@{
            role            = $_.role
            upn             = $_.userPrincipalName
            id              = $_.id
            accountEnabled  = $_.accountEnabled
            cloudOnly       = -not $_.onPremisesSyncEnabled
            licensed        = ($_.assignedLicenses.Count -gt 0)
            activeRoles     = @($_.activeRoles   | ForEach-Object { $_.roleDefinition.displayName })
            eligibleRoles   = @($_.eligibleRoles | ForEach-Object { $_.roleDefinition.displayName })
            deviceCount     = $_.devices.Count
            intuneDevices   = @($_.managedDevices | ForEach-Object {
                                  @{ name = $_.deviceName; os = $_.operatingSystem; ownership = $_.managedDeviceOwnerType } })
            ownedApps       = @($_.ownedApps   | ForEach-Object { $_.displayName })
            ownedGroups     = @($_.ownedGroups | ForEach-Object { $_.displayName })
            authMethodCount = $_.authMethods.Count
        }
    })
    undeclaredAccounts = @($undeclared | ForEach-Object {
        @{ upn = $_.userPrincipalName; cloudOnly = -not $_.onPremisesSyncEnabled } })
    survivingGlobalAdmins = $survivingGa.Count
    manualTasks = @(
        'On-premises AD: disable and double password reset (see the generated on-prem script)',
        'Azure RBAC: check Access control (IAM) at management group, subscription, resource group',
        'Sole ownerships: reassign before anyone considers deleting an account',
        'Break-glass credentials: rotate, test, reseal',
        'Registrar, DNS, certificate authority accounts: rotate',
        'Backup console and deletion protections: rotate',
        'Hypervisor root: rotate',
        'Firewall, switches, Wi-Fi, NAS, iDRAC/iLO, UPS: rotate this week',
        'App registration client secrets: rotate after reassigning ownership',
        'Vendor and partner portals: remove named accounts',
        'GDAP: remove from the security groups carrying role assignments, per customer',
        'Physical: door codes, alarm codes, keys, hardware tokens'
    )
}

$dossier | ConvertTo-Json -Depth 8 | Set-Content -Path $dossierPath -Encoding utf8
Write-Step "Dossier written: $dossierPath" -Level Good

# The on-prem half this tool cannot reach. Generated, never claimed as done.
$onPremPath = Join-Path $OutputPath "onprem-$stamp.ps1"
$samAccount = ($PrimaryUpn -split '@')[0]
@"
# Generated by Invoke-ITTermination $script:Version on $((Get-Date).ToString('o'))
# RUN THIS ON A DOMAIN-JOINED HOST. Azure Cloud Shell cannot reach a domain controller.
# Review before running. This script is not idempotent by design: read each line.

`$ErrorActionPreference = 'Stop'
Import-Module ActiveDirectory

`$sam = '$samAccount'

Get-ADUser -Identity `$sam -Properties MemberOf, LastLogonDate |
    Format-List Name, Enabled, LastLogonDate, DistinguishedName

Disable-ADAccount -Identity `$sam

# Two resets mitigate pass-the-hash against the old credential.
1..2 | ForEach-Object {
    `$pw = [System.Web.Security.Membership]::GeneratePassword(32, 8)
    Set-ADAccountPassword -Identity `$sam -Reset `
        -NewPassword (ConvertTo-SecureString -AsPlainText `$pw -Force)
}

# Privileged group membership. A disabled account in Domain Admins is one
# re-enable away from domain control.
Get-ADUser -Identity `$sam -Properties MemberOf |
    Select-Object -ExpandProperty MemberOf |
    Where-Object { `$_ -match 'Admins|Operators|Domain Admins|Enterprise Admins|Schema Admins' } |
    ForEach-Object {
        Write-Host "Removing from `$_"
        Remove-ADGroupMember -Identity `$_ -Members `$sam -Confirm:`$false
    }

# DO NOT DELETE THE ACCOUNT. See the run book.
Write-Host 'On-prem steps complete. Record the result in the dossier.'
"@ | Set-Content -Path $onPremPath -Encoding utf8
Write-Step "On-prem script generated (run it elsewhere): $onPremPath" -Level Good

if ($Mode -eq 'Report') {
    Write-Step 'REPORT COMPLETE. Nothing was changed.' -Level Head
    Write-Step "Confirmation token: $token" -Level Good
    Write-Step 'Re-run with -Mode Execute and that token to perform the cut.'
    if ($undeclared.Count -gt 0) {
        Write-Step "$($undeclared.Count) undeclared account(s) found. Declare or protect each one before Execute." -Level Warn
    }
    return
}

#endregion

#region validate ----------------------------------------------------------------

if ($Mode -eq 'Validate') {
    Write-Step 'VALIDATION: asserting resolved state' -Level Head
    $fail = 0
    foreach ($t in $targets) {
        $u = Get-GraphUser -Upn $t.userPrincipalName
        if (-not $u) {
            Write-Step "  $($t.userPrincipalName): DOES NOT RESOLVE. An account this run book says to keep was deleted." -Level Bad
            $fail++; continue
        }
        if ($u.accountEnabled) { Write-Step "  $($t.userPrincipalName): still ENABLED" -Level Bad; $fail++ }
        else                   { Write-Step "  $($t.userPrincipalName): disabled" -Level Good }

        if ($t.activeRoles.Count -gt 0)   { Write-Step "  $($t.userPrincipalName): $($t.activeRoles.Count) active role(s) remain" -Level Bad; $fail++ }
        else                              { Write-Step "  $($t.userPrincipalName): no active roles" -Level Good }

        if ($t.eligibleRoles.Count -gt 0) { Write-Step "  $($t.userPrincipalName): $($t.eligibleRoles.Count) ELIGIBLE role(s) remain" -Level Bad; $fail++ }
        else                              { Write-Step "  $($t.userPrincipalName): no eligible roles" -Level Good }

        foreach ($d in $t.devices) {
            $dev = Invoke-Graph -Method GET -Uri "/devices/$($d.id)?`$select=displayName,accountEnabled"
            if ($dev[0].accountEnabled) { Write-Step "  device '$($dev[0].displayName)': still ENABLED" -Level Bad; $fail++ }
        }
    }
    $verdict      = if ($fail -eq 0) { 'VALIDATION PASSED' } else { "VALIDATION FAILED with $fail finding(s)" }
    $verdictLevel = if ($fail -eq 0) { 'Good' } else { 'Bad' }
    Write-Step $verdict -Level $verdictLevel
    Write-Step 'Still to check by hand: sign-in logs for 24h (including non-interactive), and Azure RBAC at every scope.'
    return
}

#endregion

#region rollback ----------------------------------------------------------------

if ($Mode -eq 'Rollback') {
    if (-not $RollbackJournal -or -not (Test-Path $RollbackJournal)) {
        Stop-Run 'Rollback requires -RollbackJournal pointing at the journal file from the Execute run.'
    }
    $entries = Get-Content $RollbackJournal -Raw | ConvertFrom-Json
    Write-Step "Rolling back $($entries.Count) action(s) from $RollbackJournal" -Level Head
    foreach ($e in ($entries | Sort-Object timestamp -Descending)) {
        try {
            switch ($e.action) {
                'DisableUser'   { Invoke-Graph -Method PATCH -Uri "/users/$($e.targetId)"   -Body @{ accountEnabled = $true } | Out-Null }
                'DisableDevice' { Invoke-Graph -Method PATCH -Uri "/devices/$($e.targetId)" -Body @{ accountEnabled = $true } | Out-Null }
                'RemoveRole'    {
                    Invoke-Graph -Method POST -Uri '/roleManagement/directory/roleAssignments' -Body @{
                        principalId      = $e.undo.principalId
                        roleDefinitionId = $e.undo.roleDefinitionId
                        directoryScopeId = $e.undo.directoryScopeId
                    } | Out-Null
                }
                default { Write-Step "  '$($e.action)' on $($e.target) is NOT reversible. Skipped." -Level Warn; continue }
            }
            Write-Step "  undid $($e.action) on $($e.target)" -Level Good
        } catch { Write-Step "  FAILED to undo $($e.action) on $($e.target): $($_.Exception.Message)" -Level Bad }
    }
    Write-Step 'Rollback complete. Session revocations and device wipes cannot be undone.' -Level Head
    return
}

#endregion

#region execute -----------------------------------------------------------------

# GATE 3: the token must match this exact tenant and target set.
if ($ConfirmationToken -ne $token) {
    Stop-Run "Confirmation token mismatch. Expected '$token' for this target set. Run -Mode Report first and read it."
}
Write-Step 'Confirmation token matched.' -Level Good

# GATE 4: no undeclared accounts may be outstanding.
if ($undeclared.Count -gt 0) {
    Stop-Run "$($undeclared.Count) undeclared account(s) match this person. Pass each as -AdminUpn or -ProtectedUpns before executing."
}

# GATE 5: never orphan the tenant.
if ($survivingGa.Count -lt 1) {
    Stop-Run 'This run would leave the tenant with zero active Global Administrators. Give break-glass an active GA assignment first.'
}

$transcript = Join-Path $OutputPath "transcript-$stamp.txt"
Start-Transcript -Path $transcript -Force | Out-Null

$journalPath = Join-Path $OutputPath "rollback-journal-$stamp.json"
Write-Step "Rollback journal: $journalPath" -Level Good
Write-Step 'EXECUTING. Admin account first.' -Level Head

# Admin account first: it is the one that can undo your work.
$ordered = @($targets | Where-Object { $_.role -eq 'admin' }) + @($targets | Where-Object { $_.role -ne 'admin' })

foreach ($t in $ordered) {
    Write-Step "--- $($t.userPrincipalName) [$(Get-RoleLabel $t.role)]" -Level Head

    # 1. Roles come off BEFORE the disable, so a half-finished run never leaves a
    #    privileged-but-enabled account.
    foreach ($r in $t.activeRoles) {
        try {
            Invoke-Graph -Method DELETE -Uri "/roleManagement/directory/roleAssignments/$($r.id)" | Out-Null
            Add-Journal -Action 'RemoveRole' -Target "$($t.userPrincipalName):$($r.roleDefinition.displayName)" -TargetId $r.id -Undo @{
                principalId      = $t.id
                roleDefinitionId = $r.roleDefinitionId
                directoryScopeId = $r.directoryScopeId
            }
            Write-Step "  removed active role: $($r.roleDefinition.displayName)" -Level Good
        } catch { Write-Step "  FAILED to remove role $($r.roleDefinition.displayName): $($_.Exception.Message)" -Level Bad }
    }

    # 2. Eligible PIM assignments. These survive everything else and reactivate on approval.
    foreach ($e in $t.eligibleRoles) {
        try {
            Invoke-Graph -Method POST -Uri '/roleManagement/directory/roleEligibilityScheduleRequests' -Body @{
                action           = 'adminRemove'
                principalId      = $t.id
                roleDefinitionId = $e.roleDefinitionId
                directoryScopeId = $e.directoryScopeId
                justification    = "Termination run $stamp by $($operator.userPrincipalName)"
            } | Out-Null
            Write-Step "  removed ELIGIBLE role: $($e.roleDefinition.displayName)" -Level Good
        } catch { Write-Step "  FAILED to remove eligible role $($e.roleDefinition.displayName): $($_.Exception.Message)" -Level Bad }
    }

    # 3. Disable, then revoke. Revoking an enabled account just mints fresh tokens.
    try {
        Invoke-Graph -Method PATCH -Uri "/users/$($t.id)" -Body @{ accountEnabled = $false } | Out-Null
        Add-Journal -Action 'DisableUser' -Target $t.userPrincipalName -TargetId $t.id -Undo @{}
        Write-Step '  account disabled' -Level Good
    } catch { Write-Step "  FAILED to disable account: $($_.Exception.Message)" -Level Bad }

    try {
        Invoke-Graph -Method POST -Uri "/users/$($t.id)/revokeSignInSessions" | Out-Null
        Write-Step '  sessions revoked (allow a few minutes to land)' -Level Good
    } catch { Write-Step "  FAILED to revoke sessions: $($_.Exception.Message)" -Level Bad }

    # 4. Device objects. Disabling kills the PRT; it does not touch the data.
    foreach ($d in $t.devices) {
        try {
            Invoke-Graph -Method PATCH -Uri "/devices/$($d.id)" -Body @{ accountEnabled = $false } | Out-Null
            Add-Journal -Action 'DisableDevice' -Target $d.displayName -TargetId $d.id -Undo @{}
            Write-Step "  device disabled: $($d.displayName)" -Level Good
        } catch { Write-Step "  FAILED to disable device $($d.displayName): $($_.Exception.Message)" -Level Bad }
    }

    # 5. Irreversible Intune actions, behind their own switch. Not in the default path.
    if ($IncludeDeviceActions) {
        foreach ($m in $t.managedDevices) {
            $isPersonal = ($m.managedDeviceOwnerType -eq 'personal')
            $verb       = if ($isPersonal) { 'retire' } else { 'wipe' }
            try {
                Invoke-Graph -Method POST -Uri "/deviceManagement/managedDevices/$($m.id)/$verb" | Out-Null
                Write-Step "  $verb issued (IRREVERSIBLE): $($m.deviceName)" -Level Warn
            } catch { Write-Step "  FAILED to $verb $($m.deviceName): $($_.Exception.Message)" -Level Bad }
        }
    }
    elseif ($t.managedDevices.Count -gt 0) {
        Write-Step "  $($t.managedDevices.Count) Intune device(s) NOT actioned. Capture BitLocker and LAPS keys, then re-run with -IncludeDeviceActions." -Level Warn
    }
}

$script:Journal | ConvertTo-Json -Depth 8 | Set-Content -Path $journalPath -Encoding utf8

# Mailbox, separate failure domain, separate switch.
if ($IncludeMailbox -and -not $PrimaryUpn) {
    Write-Step 'Mailbox step SKIPPED: no everyday account was supplied, and admin accounts have no mailbox.' -Level Warn
}
elseif ($IncludeMailbox) {
    if (-not (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
        Write-Step 'ExchangeOnlineManagement not available. Mailbox step SKIPPED. Do it by hand.' -Level Warn
    } else {
        try {
            Import-Module ExchangeOnlineManagement -ErrorAction Stop
            Connect-ExchangeOnline -ShowBanner:$false
            Set-Mailbox   -Identity $PrimaryUpn -Type Shared
            Set-CASMailbox -Identity $PrimaryUpn -ActiveSyncEnabled $false -ImapEnabled $false -PopEnabled $false
            if ($SharedMailboxDelegate) {
                Add-MailboxPermission -Identity $PrimaryUpn -User $SharedMailboxDelegate `
                    -AccessRights FullAccess -AutoMapping $true | Out-Null
            }
            $type      = (Get-Mailbox -Identity $PrimaryUpn).RecipientTypeDetails
            $typeLevel = if ($type -eq 'SharedMailbox') { 'Good' } else { 'Warn' }
            Write-Step "  mailbox type is now: $type" -Level $typeLevel
            Write-Step '  REMINDER: remove the licence only after confirming SharedMailbox, and NEVER delete the anchor account.' -Level Warn
        } catch { Write-Step "  mailbox step FAILED: $($_.Exception.Message). Do it by hand." -Level Bad }
    }
}

Stop-Transcript | Out-Null

Write-Step 'EXECUTE COMPLETE.' -Level Head
Write-Step "Transcript: $transcript"
Write-Step "Rollback:   ./Invoke-ITTermination.ps1 -TenantId $TenantId -PrimaryUpn $PrimaryUpn -Mode Rollback -RollbackJournal $journalPath"
Write-Step ''
Write-Step 'STILL OWED BY A HUMAN:' -Level Warn
Write-Step '  1. Run the generated on-prem script on a domain-joined host'
Write-Step '  2. Azure RBAC at management group, subscription, resource group scope'
Write-Step '  3. Reassign sole ownerships, THEN leave both accounts in place, disabled'
Write-Step '  4. The whole rotation list in the dossier'
Write-Step '  5. Re-run with -Mode Validate, then watch sign-in logs for 24 hours'

#endregion
