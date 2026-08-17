@{
    RootModule        = 'Microsoft.Graph.Authentication.psm1'
    ModuleVersion     = '2.25.0'
    GUID              = 'd1f2a3b4-c5d6-4e7f-8a9b-0c1d2e3f4a5b'
    Author            = 'mock'
    Description       = 'Offline mock for testing'
    FunctionsToExport = @('Get-MgContext','Connect-MgGraph','Invoke-MgGraphRequest','Get-MockCalls')
}
