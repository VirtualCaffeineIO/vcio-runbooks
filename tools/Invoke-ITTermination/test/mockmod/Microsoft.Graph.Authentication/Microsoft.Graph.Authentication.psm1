# Mock of Microsoft.Graph.Authentication for offline testing of Invoke-ITTermination.ps1
# Returns plausible Graph shapes so the script's logic can be exercised without a tenant.

$script:MockTenant = '11111111-2222-3333-4444-555555555555'

$script:Users = @{
    'jdoe@contoso.com' = [pscustomobject]@{
        id = 'aaaaaaaa-0000-0000-0000-000000000001'; userPrincipalName = 'jdoe@contoso.com'
        displayName = 'Jane Doe'; surname = 'Doe'; givenName = 'Jane'; accountEnabled = $true; onPremisesSyncEnabled = $true
        mail = 'jdoe@contoso.com'; createdDateTime = '2019-04-01T00:00:00Z'
        assignedLicenses = @([pscustomobject]@{ skuId = 'sku-e3' })
    }
    'adm-jdoe@contoso.onmicrosoft.com' = [pscustomobject]@{
        id = 'aaaaaaaa-0000-0000-0000-000000000002'; userPrincipalName = 'adm-jdoe@contoso.onmicrosoft.com'
        displayName = 'Jane Doe (Admin)'; surname = 'Doe'; givenName = 'Jane'; accountEnabled = $true; onPremisesSyncEnabled = $false
        mail = $null; createdDateTime = '2019-04-02T00:00:00Z'; assignedLicenses = @()
    }
    'operator@contoso.com' = [pscustomobject]@{
        id = 'bbbbbbbb-0000-0000-0000-000000000009'; userPrincipalName = 'operator@contoso.com'
        displayName = 'Ops Person'; surname = 'Person'; givenName = 'Ops'; accountEnabled = $true; onPremisesSyncEnabled = $true
        mail = 'operator@contoso.com'; createdDateTime = '2018-01-01T00:00:00Z'
        assignedLicenses = @([pscustomobject]@{ skuId = 'sku-e5' })
    }
}

function Get-MgContext {
    [pscustomobject]@{ TenantId = $script:MockTenant; Account = 'operator@contoso.com'; Scopes = @('User.ReadWrite.All') }
}

function Connect-MgGraph { param([string]$TenantId,[string[]]$Scopes,[switch]$UseDeviceAuthentication,[switch]$NoWelcome) }

function Invoke-MgGraphRequest {
    param(
        [string]$Method, [string]$Uri, $Body, [string]$ContentType,
        [string]$OutputType, [hashtable]$Headers
    )

    $script:MockCalls += ,@{ Method = $Method; Uri = $Uri }

    # Writes: acknowledge and return nothing, like Graph does for 204.
    if ($Method -in 'PATCH','DELETE','POST') {
        if ($Uri -match 'roleEligibilityScheduleRequests') {
            return [pscustomobject]@{ id = 'req-1'; status = 'Provisioned' }
        }
        if ($Uri -match 'roleAssignmentScheduleRequests') {
            return [pscustomobject]@{ id = 'areq-1'; status = 'Provisioned' }
        }
        return $null
    }

    switch -Regex ($Uri) {
        # Operator authority. Default: operator holds GA outright.
        # MOCK_OPERATOR_NOROLES=1 flips them to eligible-but-not-active.
        'roleAssignments\?\$filter=principalId eq ''bbbbbbbb' {
            if ($env:MOCK_OPERATOR_NOROLES -eq '1') { return [pscustomobject]@{ value = @() } }
            return [pscustomobject]@{ value = @(
                [pscustomobject]@{ id='ra-op'; principalId='bbbbbbbb-0000-0000-0000-000000000009'
                                   roleDefinitionId='62e90394-69f5-4237-9190-012177145e10' }
            )}
        }
        'roleEligibilityScheduleInstances\?\$filter=principalId eq ''bbbbbbbb' {
            if ($env:MOCK_OPERATOR_NOROLES -eq '1') {
                return [pscustomobject]@{ value = @(
                    [pscustomobject]@{ id='el-op1'; principalId='bbbbbbbb-0000-0000-0000-000000000009'
                        roleDefinitionId='7be44c8a-adaf-4e2a-84d6-ab2649e08a13'; directoryScopeId='/' },
                    [pscustomobject]@{ id='el-op2'; principalId='bbbbbbbb-0000-0000-0000-000000000009'
                        roleDefinitionId='e8611ab8-c189-46e8-94e1-60213ab1f814'; directoryScopeId='/' }
                )}
            }
            return [pscustomobject]@{ value = @() }
        }
        'roleAssignmentScheduleRequests' {
            return [pscustomobject]@{ id='areq-1'; status='Provisioned' }
        }
        '/organization' {
            return [pscustomobject]@{ value = @(
                [pscustomobject]@{
                    id = '11111111-2222-3333-4444-555555555555'
                    displayName = 'Contoso Ltd'
                    verifiedDomains = @(
                        [pscustomobject]@{ name = 'contoso.com';            isDefault = $true  },
                        [pscustomobject]@{ name = 'contoso.onmicrosoft.com'; isDefault = $false }
                    )
                }
            )}
        }
        '/users\?\$search' {
            return [pscustomobject]@{ value = @(
                $script:Users['jdoe@contoso.com'],
                $script:Users['adm-jdoe@contoso.onmicrosoft.com'],
                [pscustomobject]@{
                    id = 'aaaaaaaa-0000-0000-0000-000000000003'
                    userPrincipalName = 'jdoe-test@contoso.onmicrosoft.com'
                    displayName = 'Jane Doe TEST'; surname = 'Doe'; givenName = 'Jane'; accountEnabled = $true
                    onPremisesSyncEnabled = $false; mail = $null; assignedLicenses = @()
                }
            )}
        }
        "roleAssignments\?\`$filter=roleDefinitionId" {
            return [pscustomobject]@{ value = @(
                [pscustomobject]@{ id='ra-ga-1'; principalId='aaaaaaaa-0000-0000-0000-000000000002'; roleDefinitionId='62e90394-69f5-4237-9190-012177145e10' },
                [pscustomobject]@{ id='ra-ga-2'; principalId='cccccccc-0000-0000-0000-00000000000b'; roleDefinitionId='62e90394-69f5-4237-9190-012177145e10' },
                [pscustomobject]@{ id='ra-ga-3'; principalId='dddddddd-0000-0000-0000-00000000000c'; roleDefinitionId='62e90394-69f5-4237-9190-012177145e10' }
            )}
        }
        'roleAssignments\?' {
            if ($env:MOCK_PRIMARY_PRIVILEGED -eq '1' -and $Uri -match "000000000001") {
                return [pscustomobject]@{ value = @(
                    [pscustomobject]@{ id='ra-p1'; principalId='aaaaaaaa-0000-0000-0000-000000000001'
                        roleDefinitionId='62e90394-69f5-4237-9190-012177145e10'; directoryScopeId='/'
                        roleDefinition=[pscustomobject]@{ displayName='Global Administrator' } }
                )}
            }
            if ($Uri -match "000000000002") {
                return [pscustomobject]@{ value = @(
                    [pscustomobject]@{ id='ra-1'; principalId='aaaaaaaa-0000-0000-0000-000000000002'
                        roleDefinitionId='29232cdf-9323-42fd-ade2-1d097af3e4de'; directoryScopeId='/'
                        roleDefinition=[pscustomobject]@{ displayName='Exchange Administrator' } },
                    [pscustomobject]@{ id='ra-2'; principalId='aaaaaaaa-0000-0000-0000-000000000002'
                        roleDefinitionId='3a2c62db-5318-420d-8d74-23affee5d9d5'; directoryScopeId='/'
                        roleDefinition=[pscustomobject]@{ displayName='Intune Administrator' } }
                )}
            }
            return [pscustomobject]@{ value = @() }
        }
        'roleEligibilityScheduleInstances' {
            if ($Uri -match "000000000002") {
                return [pscustomobject]@{ value = @(
                    [pscustomobject]@{ id='el-1'; principalId='aaaaaaaa-0000-0000-0000-000000000002'
                        roleDefinitionId='62e90394-69f5-4237-9190-012177145e10'; directoryScopeId='/'
                        roleDefinition=[pscustomobject]@{ displayName='Global Administrator' } }
                )}
            }
            return [pscustomobject]@{ value = @() }
        }
        '/registeredDevices' {
            if ($Uri -match "000000000001") {
                return [pscustomobject]@{ value = @(
                    [pscustomobject]@{ id='dev-1'; displayName='LAP-JDOE-01'; accountEnabled=$true },
                    [pscustomobject]@{ id='dev-2'; displayName='JDOE-IPHONE'; accountEnabled=$true }
                )}
            }
            return [pscustomobject]@{ value = @() }
        }
        '/ownedObjects' {
            if ($Uri -match "000000000002") {
                return [pscustomobject]@{ value = @(
                    [pscustomobject]@{ '@odata.type'='#microsoft.graph.application'; id='app-1'; displayName='Backup Automation' },
                    [pscustomobject]@{ '@odata.type'='#microsoft.graph.group';       id='grp-1'; displayName='SG-Infra-Admins' }
                )}
            }
            return [pscustomobject]@{ value = @() }
        }
        'managedDevices' {
            if ($Uri -match "000000000001") {
                return [pscustomobject]@{ value = @(
                    [pscustomobject]@{ id='md-1'; deviceName='LAP-JDOE-01'; operatingSystem='Windows'; managedDeviceOwnerType='company'; userId='aaaaaaaa-0000-0000-0000-000000000001' },
                    [pscustomobject]@{ id='md-2'; deviceName='JDOE-IPHONE'; operatingSystem='iOS';     managedDeviceOwnerType='personal'; userId='aaaaaaaa-0000-0000-0000-000000000001' }
                )}
            }
            return [pscustomobject]@{ value = @() }
        }
        '/authentication/methods' {
            return [pscustomobject]@{ value = @(
                [pscustomobject]@{ id='m-1'; '@odata.type'='#microsoft.graph.fido2AuthenticationMethod' }
            )}
        }
        '/devices/' { return [pscustomobject]@{ id='dev-1'; displayName='LAP-JDOE-01'; accountEnabled=$false } }
        '/users/' {
            foreach ($k in $script:Users.Keys) {
                if ($Uri -match [regex]::Escape([uri]::EscapeDataString($k))) { return $script:Users[$k] }
            }
            throw "Mock: user not found in URI $Uri"
        }
    }
    return [pscustomobject]@{ value = @() }
}

$script:MockCalls = @()
function Get-MockCalls { $script:MockCalls }

Export-ModuleMember -Function Get-MgContext, Connect-MgGraph, Invoke-MgGraphRequest, Get-MockCalls
