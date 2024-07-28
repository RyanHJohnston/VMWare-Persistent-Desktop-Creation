#Requires -Modules VmWare.PowerCli


Param(
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory = $true)]
    [string]
    $Name,
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory = $true)]
    $Server,
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory = $true)]
    [string]
    $VmTemplate,
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory = $true)]
    [string]
    $Folder,
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory = $true)]
    [string]
    $Datastore,
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory = $true)]
    [string]
    $Network,
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory = $false)]
    [string]
    $Spec,
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory = $false)]
    [string]
    $ResourcePool

)
Describe {

    Context {

        It 'Name test' {
            Get-VM -Name $Name | Should -Be $Name 
        }

        It 'Location test' {
            (Get-VM -Location (Get-Folder $Folder) -Name $Name).Name | Should -Be $Name 
        }

        It 'Datastore test' {
            $vmDatastore = Get-Datastore -Name $Datastore
            (Get-VM -Datastore $vmDatastore -Name $Name).Name | Should -Be $Name 
        }

        It 'Network test' {
            (Get-VM -NetworkName (Get-VDPortgroup -Name $Network) -Name $Name).Name | Should -Be $Name
        }

        It 'Template test' {
            $inAD = (Get-ADComputer -Identity $Name).dnshostname 
            [boolean] $inAD | Should -Be $true
        } 

        Context 'Other Servers' -Skip:( !($Server.Contains("128")) ) {
           
            It 'specs config test' {
                ##
            }

            It 'resource pool test' {
                Get-ResourcePool -VM $Name | Should -Be $ResourcePool
            }
        }
    }
}