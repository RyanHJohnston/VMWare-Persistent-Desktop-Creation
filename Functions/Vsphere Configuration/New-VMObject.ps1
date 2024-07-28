#Requires -Modules VMware.PowerCli
# This function captures host node loads and returns it as a object.

# Function is the actually creation piece.
function New-VMObject {
    <#
        .SYNOPSIS
        

        .EXAMPLE


    #>

    [CmdletBinding()]
    [OutputType([psobject])]
    Param (
        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory = $True)]
        [string]
        $VMName,

        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory = $True)]
        [string]
        $vSphere,

        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory = $True)]
        [string]
        $ConnectionServer,

        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory = $True)]
        [String]
        $ClusterType
    )

    process {
        if ($ClusterType -eq "VDIVC") {
            # vdivc cluster
            $NewVMAttributes = @{
                Name                = $VMName
                Location            = (Get-Folder 'Virtual Center')
                Template            = (Get-Template 'PAW ESET Template v1.2')
                DataStore           = (Get-DataStore 'vsanDatastore')
                NetworkName         = (Get-VDPortgroup -Name 'DPortGroup Staff VLAN 322 (Student DHCP)')
                VMHost              = (Get-VMHost (Select-LightestServer).Name)
                OSCustomizationSpec = 'ESE Paw Creation'
                ResourcePool        = (Get-ResourcePool 'HEERF') # not sure if resource pool is correct, make necessary changes
            }

            $NewVM = New-VM @NewVMAttributes
        }
        elseif ($ClusterType -eq "SP1") {
            # sp1 cluster
            $NewVMAttributes = @{
                Name                = $VMName
                Location            = (Get-Folder 'Virtual Center')
                Template            = (Get-Template 'ESEPaws-2/7/24-Snapshot3')
                Datastore           = (Get-Datastore 'VxRail-Virtual-SAN-Datastore-958dad88-6864-42f6-bbd6-acc30a6f4ee7')
                NetworkName         = (Get-VDPortgroup -Name 'VDI 2.0 Production Guest Overlay 1')
                VMHost              = (Get-VMHost (Select-LightestServer).Name)
                OSCustomizationSpec = 'ESE Paw Creation'
                ResourcePool        = (Get-ResourcePool 'HEERF')
            }

            $NewVM = New-VM @NewVMAttributes
        }
        else {
            Write-Debug "[Create-NewVM] Specified cluster could not be found"
            return $null
        }

        # Output details for machine
        Write-Verbose "[Create-NewVM] New Virtual Machine Details: $($NewVM | ConvertTo-Json)"
        New-Object -Property $ReturnedObject -TypeName psobject [ordered] @{
            Name         = $VMName
            Server       = $ConnectionServer
            VmTemplate   = $NewVM.Template.ToString()
            Folder       = $NewVM.Location.ToString()
            Datastore    = $NewVM.DataStore.ToString()
            Network      = $NewVM.NetworkName.ToString()
            Spec         = $NewVM.OSCustomizationSpec.ToString()
            ResourcePool = $NewVM.ResourcePool.ToString()
        }

    }

}