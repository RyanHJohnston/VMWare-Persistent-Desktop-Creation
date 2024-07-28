#Requires -Modules VMWare.PowerCLI
#Requires -Modules Pester

BeforeAll {
    . ../New-PawVM.ps1
}

Describe {
    Context {
        It 'Name test' {
            Get-VM -Name 'ESE-VDI-PAW22' | Should -Be 'ESE-VDI-PAW22'
        }
    }
}