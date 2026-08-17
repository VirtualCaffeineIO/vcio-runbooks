$ErrorActionPreference = 'Stop'
$env:PSModulePath = (Resolve-Path ./test/mockmod).Path + [IO.Path]::PathSeparator + $env:PSModulePath
$T = '11111111-2222-3333-4444-555555555555'
$out = './test/out'
if (Test-Path $out) { Remove-Item $out -Recurse -Force }

function Test-Case { param($Name,[scriptblock]$Body)
  try { & $Body; Write-Host "PASS  $Name" -ForegroundColor Green }
  catch { Write-Host "FAIL  $Name :: $($_.Exception.Message)" -ForegroundColor Red; $script:failed++ }
}
$script:failed = 0

Test-Case 'Report mode completes and writes a dossier' {
  $o = & ./Invoke-ITTermination.ps1 -TenantId $T -PrimaryUpn jdoe@contoso.com `
        -AdminUpn adm-jdoe@contoso.onmicrosoft.com -SearchName Doe -OutputPath $out 6>&1 | Out-String
  if ($o -notmatch 'REPORT COMPLETE')      { throw 'no completion banner' }
  if (-not (Get-ChildItem $out -Filter 'dossier-*.json')) { throw 'no dossier written' }
  if ($o -notmatch 'Confirmation token')   { throw 'no token emitted' }
}

Test-Case 'Report finds the undeclared test account' {
  $o = & ./Invoke-ITTermination.ps1 -TenantId $T -PrimaryUpn jdoe@contoso.com `
        -AdminUpn adm-jdoe@contoso.onmicrosoft.com -SearchName Doe -OutputPath $out 6>&1 | Out-String
  if ($o -notmatch 'jdoe-test@contoso.onmicrosoft.com') { throw 'undeclared account not surfaced' }
  if ($o -notmatch 'CLOUD-ONLY') { throw 'cloud-only flag not surfaced' }
}

Test-Case 'Dossier records the admin account as cloud-only and unlicensed' {
  $d = Get-ChildItem $out -Filter 'dossier-*.json' | Select-Object -First 1
  $j = Get-Content $d.FullName -Raw | ConvertFrom-Json
  $a = $j.targets | Where-Object role -eq 'admin'
  if (-not $a)            { throw 'no admin target in dossier' }
  if (-not $a.cloudOnly)  { throw 'admin not flagged cloud-only' }
  if ($a.licensed)        { throw 'admin flagged licensed' }
  if ($a.eligibleRoles -notcontains 'Global Administrator') { throw 'eligible GA not captured' }
}

Test-Case 'On-prem script generated and refuses to delete' {
  $s = Get-ChildItem $out -Filter 'onprem-*.ps1' | Select-Object -First 1
  if (-not $s) { throw 'no on-prem script' }
  $c = Get-Content $s.FullName -Raw
  if ($c -notmatch 'Disable-ADAccount')      { throw 'no disable' }
  if ($c -notmatch 'DO NOT DELETE')          { throw 'no delete warning' }
  if ($c -match 'Remove-ADUser')             { throw 'on-prem script contains a delete verb' }
}

Test-Case 'GATE: wrong tenant is refused, for the tenant reason' {
  $threw=$false; $msg=''
  try { & ./Invoke-ITTermination.ps1 -TenantId '99999999-9999-9999-9999-999999999999' `
        -PrimaryUpn jdoe@contoso.com -NonInteractive -OutputPath $out 6>&1 | Out-Null }
  catch { $threw=$true; $msg=$_.Exception.Message }
  if (-not $threw) { throw 'wrong tenant was NOT refused' }
  if ($msg -notmatch 'does not match') { throw "refused for the wrong reason: $msg" }
}

Test-Case 'GATE: operator cannot terminate themselves, for the protected reason' {
  $threw=$false; $msg=''
  try { & ./Invoke-ITTermination.ps1 -TenantId $T -PrimaryUpn operator@contoso.com `
        -NonInteractive -OutputPath $out 6>&1 | Out-Null }
  catch { $threw=$true; $msg=$_.Exception.Message }
  if (-not $threw) { throw 'self-termination was NOT refused' }
  if ($msg -notmatch 'protected account') { throw "refused for the wrong reason: $msg" }
}

Test-Case 'GATE: Execute without a token is refused, for the token reason' {
  $threw=$false; $msg=''
  try { & ./Invoke-ITTermination.ps1 -TenantId $T -PrimaryUpn jdoe@contoso.com `
        -AdminUpn adm-jdoe@contoso.onmicrosoft.com -SearchName Doe -Mode Execute `
        -ConfirmationToken 'WRONGTOKEN00' -NonInteractive -OutputPath $out 6>&1 | Out-Null }
  catch { $threw=$true; $msg=$_.Exception.Message }
  if (-not $threw) { throw 'bad token was NOT refused' }
  if ($msg -notmatch 'token mismatch') { throw "refused for the wrong reason: $msg" }
}

Test-Case 'GATE: Execute refused while an undeclared account exists' {
  $o = & ./Invoke-ITTermination.ps1 -TenantId $T -PrimaryUpn jdoe@contoso.com `
        -AdminUpn adm-jdoe@contoso.onmicrosoft.com -SearchName Doe -OutputPath $out 6>&1 | Out-String
  $tok = ([regex]'Confirmation token: ([A-F0-9]{12})').Match($o).Groups[1].Value
  if (-not $tok) { throw 'could not read token' }
  $threw = $false; $msg = ''
  try { & ./Invoke-ITTermination.ps1 -TenantId $T -PrimaryUpn jdoe@contoso.com `
        -AdminUpn adm-jdoe@contoso.onmicrosoft.com -SearchName Doe -Mode Execute -NonInteractive `
        -ConfirmationToken $tok -OutputPath $out 6>&1 | Out-Null }
  catch { $threw = $true; $msg = $_.Exception.Message }
  if (-not $threw) { throw 'undeclared account did NOT block execute' }
  if ($msg -notmatch 'undeclared') { throw "blocked for the wrong reason: $msg" }
}

Test-Case 'Execute runs when the test account is protected, admin account first' {
  $o = & ./Invoke-ITTermination.ps1 -TenantId $T -PrimaryUpn jdoe@contoso.com `
        -AdminUpn adm-jdoe@contoso.onmicrosoft.com -SearchName Doe `
        -ProtectedUpns 'jdoe-test@contoso.onmicrosoft.com' -OutputPath $out 6>&1 | Out-String
  $tok = ([regex]'Confirmation token: ([A-F0-9]{12})').Match($o).Groups[1].Value
  $e = & ./Invoke-ITTermination.ps1 -TenantId $T -PrimaryUpn jdoe@contoso.com `
        -AdminUpn adm-jdoe@contoso.onmicrosoft.com -SearchName Doe `
        -ProtectedUpns 'jdoe-test@contoso.onmicrosoft.com' -Mode Execute -NonInteractive `
        -ConfirmationToken $tok -OutputPath $out 6>&1 | Out-String
  if ($e -notmatch 'EXECUTE COMPLETE') { throw "execute did not complete: $e" }
  $ai = $e.IndexOf('adm-jdoe@contoso.onmicrosoft.com [PRIVILEGED ACCOUNT]')
  $pi = $e.IndexOf('jdoe@contoso.com [EVERYDAY ACCOUNT]')
  if ($ai -lt 0 -or $pi -lt 0) { throw 'could not find both account banners' }
  if ($ai -gt $pi) { throw 'PRIMARY was cut before ADMIN' }
  if ($e -notmatch 'removed ELIGIBLE role: Global Administrator') { throw 'eligible GA not removed' }
  if (-not (Get-ChildItem $out -Filter 'rollback-journal-*.json')) { throw 'no rollback journal' }
}

Test-Case 'Execute did NOT wipe devices without -IncludeDeviceActions' {
  $j = Get-ChildItem $out -Filter 'rollback-journal-*.json' | Select-Object -First 1
  $c = Get-Content $j.FullName -Raw
  if ($c -match 'wipe|retire') { throw 'device actions ran without the switch' }
}

Test-Case 'Rollback journal contains only reversible actions' {
  $j = Get-ChildItem $out -Filter 'rollback-journal-*.json' | Select-Object -First 1
  $e = Get-Content $j.FullName -Raw | ConvertFrom-Json
  $allowed = @('DisableUser','DisableDevice','RemoveRole')
  foreach ($x in $e) { if ($x.action -notin $allowed) { throw "irreversible action journalled: $($x.action)" } }
  if (-not ($e | Where-Object action -eq 'RemoveRole')) { throw 'role removal not journalled' }
  if (-not ($e | Where-Object action -eq 'DisableUser')) { throw 'disable not journalled' }
}

Test-Case 'Script contains no user-delete verb anywhere' {
  $c = Get-Content ./Invoke-ITTermination.ps1 -Raw
  if ($c -match "Method DELETE -Uri ""/users") { throw 'script can delete a user' }
  if ($c -match 'Remove-MgUser') { throw 'script references Remove-MgUser' }
}

Test-Case 'PREFLIGHT: operator with GA passes the authority check' {
  $o = & ./Invoke-ITTermination.ps1 -TenantId $T -PrimaryUpn jdoe@contoso.com `
        -AdminUpn adm-jdoe@contoso.onmicrosoft.com -SearchName Doe `
        -ProtectedUpns 'jdoe-test@contoso.onmicrosoft.com' -OutputPath $out 6>&1 | Out-String
  $tok = ([regex]'Confirmation token: ([A-F0-9]{12})').Match($o).Groups[1].Value
  $e = & ./Invoke-ITTermination.ps1 -TenantId $T -PrimaryUpn jdoe@contoso.com `
        -AdminUpn adm-jdoe@contoso.onmicrosoft.com -SearchName Doe -NonInteractive `
        -ProtectedUpns 'jdoe-test@contoso.onmicrosoft.com' -Mode Execute `
        -ConfirmationToken $tok -OutputPath $out 6>&1 | Out-String
  if ($e -notmatch 'holds Global Administrator') { throw 'GA authority not detected' }
}

Test-Case 'PREFLIGHT: eligible-not-active operator is blocked without -ElevateWithPim' {
  $env:MOCK_OPERATOR_NOROLES = '1'
  try {
    $o = & ./Invoke-ITTermination.ps1 -TenantId $T -PrimaryUpn jdoe@contoso.com `
          -AdminUpn adm-jdoe@contoso.onmicrosoft.com -SearchName Doe `
          -ProtectedUpns 'jdoe-test@contoso.onmicrosoft.com' -OutputPath $out 6>&1 | Out-String
    $tok = ([regex]'Confirmation token: ([A-F0-9]{12})').Match($o).Groups[1].Value
    $threw=$false; $msg=''
    try { & ./Invoke-ITTermination.ps1 -TenantId $T -PrimaryUpn jdoe@contoso.com `
          -AdminUpn adm-jdoe@contoso.onmicrosoft.com -SearchName Doe -NonInteractive `
          -ProtectedUpns 'jdoe-test@contoso.onmicrosoft.com' -Mode Execute `
          -ConfirmationToken $tok -OutputPath $out 6>&1 | Out-Null }
    catch { $threw=$true; $msg=$_.Exception.Message }
    if (-not $threw) { throw 'un-elevated operator was allowed to execute' }
    if ($msg -notmatch 'ElevateWithPim') { throw "blocked for the wrong reason: $msg" }
  } finally { Remove-Item Env:MOCK_OPERATOR_NOROLES -ErrorAction SilentlyContinue }
}

Test-Case 'PREFLIGHT: -ElevateWithPim activates the missing roles and proceeds' {
  $env:MOCK_OPERATOR_NOROLES = '1'
  try {
    $o = & ./Invoke-ITTermination.ps1 -TenantId $T -PrimaryUpn jdoe@contoso.com `
          -AdminUpn adm-jdoe@contoso.onmicrosoft.com -SearchName Doe `
          -ProtectedUpns 'jdoe-test@contoso.onmicrosoft.com' -OutputPath $out 6>&1 | Out-String
    $tok = ([regex]'Confirmation token: ([A-F0-9]{12})').Match($o).Groups[1].Value
    $e = & ./Invoke-ITTermination.ps1 -TenantId $T -PrimaryUpn jdoe@contoso.com `
          -AdminUpn adm-jdoe@contoso.onmicrosoft.com -SearchName Doe -NonInteractive -ElevateWithPim `
          -ProtectedUpns 'jdoe-test@contoso.onmicrosoft.com' -Mode Execute `
          -ConfirmationToken $tok -OutputPath $out 6>&1 | Out-String
    if ($e -notmatch 'ELIGIBLE for')                     { throw 'eligibility not detected' }
    if ($e -notmatch 'Privileged Authentication Administrator activated') { throw 'PAA not activated' }
    if ($e -notmatch 'Privileged Role Administrator activated')           { throw 'PRA not activated' }
    if ($e -notmatch 'Token refreshed')                  { throw 'token not refreshed after elevation' }
    if ($e -notmatch 'EXECUTE COMPLETE')                 { throw 'run did not complete after elevation' }
    if ($e -match 'Global Administrator activated')      { throw 'reached for GA when narrower roles sufficed' }
  } finally { Remove-Item Env:MOCK_OPERATOR_NOROLES -ErrorAction SilentlyContinue }
}

Test-Case 'TENANT: a verified DOMAIN is accepted, not just the GUID' {
  $o = & ./Invoke-ITTermination.ps1 -TenantId 'contoso.com' -PrimaryUpn jdoe@contoso.com `
        -AdminUpn adm-jdoe@contoso.onmicrosoft.com -SearchName Doe -OutputPath $out 6>&1 | Out-String
  if ($o -notmatch 'REPORT COMPLETE') { throw 'domain form was rejected' }
  if ($o -notmatch 'Contoso Ltd')     { throw 'tenant display name not shown' }
}

Test-Case 'TENANT: a wrong domain is still refused, and names the real tenant' {
  $threw=$false; $msg=''
  try { & ./Invoke-ITTermination.ps1 -TenantId 'fabrikam.com' -PrimaryUpn jdoe@contoso.com `
        -NonInteractive -OutputPath $out 6>&1 | Out-Null }
  catch { $threw=$true; $msg=$_.Exception.Message }
  if (-not $threw) { throw 'wrong domain was accepted' }
  if ($msg -notmatch 'contoso\.com') { throw "error does not name the real tenant domains: $msg" }
}

Test-Case 'SEARCH: the search term comes from the directory surname, not UPN guessing' {
  # 'lidiah' style local parts have no separator; the old parser produced 'idiah'.
  $o = & ./Invoke-ITTermination.ps1 -TenantId $T -PrimaryUpn jdoe@contoso.com `
        -AdminUpn adm-jdoe@contoso.onmicrosoft.com -OutputPath $out 6>&1 | Out-String
  if ($o -notmatch "Discovering accounts matching 'Doe'") { throw "search term not taken from surname: $o" }
}

Test-Case 'LABEL: the target is named as TO BE TERMINATED' {
  $o = & ./Invoke-ITTermination.ps1 -TenantId $T -PrimaryUpn jdoe@contoso.com `
        -AdminUpn adm-jdoe@contoso.onmicrosoft.com -SearchName Doe -OutputPath $out 6>&1 | Out-String
  if ($o -notmatch 'TO BE TERMINATED: Jane Doe') { throw 'target not clearly labelled' }
}

Test-Case 'REPORT: active role NAMES are printed, not just a count' {
  $o = & ./Invoke-ITTermination.ps1 -TenantId $T -PrimaryUpn jdoe@contoso.com `
        -AdminUpn adm-jdoe@contoso.onmicrosoft.com -SearchName Doe -OutputPath $out 6>&1 | Out-String
  if ($o -notmatch 'active:   Exchange Administrator') { throw 'role names not listed' }
  if ($o -notmatch 'eligible: Global Administrator')   { throw 'eligible role name not listed' }
}

Test-Case 'REPORT: a privileged EVERYDAY account is flagged as an anti-pattern' {
  $env:MOCK_PRIMARY_PRIVILEGED = '1'
  try {
    $o = & ./Invoke-ITTermination.ps1 -TenantId $T -PrimaryUpn jdoe@contoso.com `
          -AdminUpn adm-jdoe@contoso.onmicrosoft.com -SearchName Doe -OutputPath $out 6>&1 | Out-String
    if ($o -notmatch 'EVERYDAY account holds privileged roles')  { throw 'anti-pattern not flagged' }
    if ($o -notmatch 'GLOBAL ADMINISTRATOR')                     { throw 'GA not called out' }
    if ($o -notmatch 'wrong way round')                          { throw 'two-account hint missing' }
  } finally { Remove-Item Env:MOCK_PRIMARY_PRIVILEGED -ErrorAction SilentlyContinue }
}

Test-Case 'REPORT: a clean everyday account is NOT flagged' {
  $o = & ./Invoke-ITTermination.ps1 -TenantId $T -PrimaryUpn jdoe@contoso.com `
        -AdminUpn adm-jdoe@contoso.onmicrosoft.com -SearchName Doe -OutputPath $out 6>&1 | Out-String
  if ($o -match 'EVERYDAY account holds privileged roles') { throw 'false positive on a clean account' }
}

Test-Case 'REPORT: with NO admin declared, the warning offers the single-account reading' {
  $env:MOCK_PRIMARY_PRIVILEGED = '1'
  try {
    $o = & ./Invoke-ITTermination.ps1 -TenantId $T -PrimaryUpn jdoe@contoso.com -NonInteractive `
          -SearchName Doe -ProtectedUpns 'jdoe-test@contoso.onmicrosoft.com','adm-jdoe@contoso.onmicrosoft.com' `
          -OutputPath $out 6>&1 | Out-String
    if ($o -notmatch 'EVERYDAY account holds privileged roles') { throw 'anti-pattern not flagged' }
    if ($o -notmatch 'belongs in -AdminUpn instead')            { throw 'single-account reading missing' }
    if ($o -match 'wrong way round')                            { throw 'two-account wording shown when no admin declared' }
  } finally { Remove-Item Env:MOCK_PRIMARY_PRIVILEGED -ErrorAction SilentlyContinue }
}

Test-Case 'SINGLE ACCOUNT: -AdminUpn alone is accepted and labelled PRIVILEGED' {
  $o = & ./Invoke-ITTermination.ps1 -TenantId $T -AdminUpn adm-jdoe@contoso.onmicrosoft.com `
        -SearchName Doe -NonInteractive `
        -ProtectedUpns 'jdoe-test@contoso.onmicrosoft.com','jdoe@contoso.com' `
        -OutputPath $out 6>&1 | Out-String
  if ($o -notmatch 'REPORT COMPLETE')                    { throw 'admin-only run did not complete' }
  if ($o -notmatch 'TO BE TERMINATED: Jane Doe \(Admin\)') { throw 'anchor not taken from the admin account' }
  if ($o -notmatch 'Admin account only')                 { throw 'admin-only mode not announced' }
  if ($o -notmatch '\[PRIVILEGED ACCOUNT\]')             { throw 'admin account mislabelled' }
  if ($o -match '\[EVERYDAY ACCOUNT\]')                  { throw 'phantom everyday account profiled' }
}

Test-Case 'SINGLE ACCOUNT: no privileged-everyday warning fires when there is no everyday account' {
  $o = & ./Invoke-ITTermination.ps1 -TenantId $T -AdminUpn adm-jdoe@contoso.onmicrosoft.com `
        -SearchName Doe -NonInteractive `
        -ProtectedUpns 'jdoe-test@contoso.onmicrosoft.com','jdoe@contoso.com' `
        -OutputPath $out 6>&1 | Out-String
  if ($o -match 'EVERYDAY account holds privileged roles') { throw 'anti-pattern warning misfired' }
}

Test-Case 'SINGLE ACCOUNT: neither account supplied is refused clearly' {
  $threw=$false; $msg=''
  try { & ./Invoke-ITTermination.ps1 -TenantId $T -NonInteractive -OutputPath $out 6>&1 | Out-Null }
  catch { $threw=$true; $msg=$_.Exception.Message }
  if (-not $threw) { throw 'run with no accounts was accepted' }
  if ($msg -notmatch 'only ever had an admin account') { throw "unclear message: $msg" }
}

Write-Host ''
if ($script:failed -gt 0) { Write-Host "$($script:failed) TEST(S) FAILED" -ForegroundColor Red; exit 1 }
Write-Host 'ALL TESTS PASSED' -ForegroundColor Green
