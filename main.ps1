<#
.SYNOPSIS
    This script automates the creation of a Windows 11 ESE PAW given a VM name and user. 

.EXAMPLE
    .\New-PawVM.ps1 -VMName 'MyNewVM' -User abc123.sa

.NOTES
    Clusters IP, DNS:
    - 129.115.105.92, vdivc.utsarr.net
    - 10.246.128.25, vmwsp1-vc1.utsarr.net
    - 10.246.128.57, vmwsp1-vc2.utsarr.net
#>

[CmdletBinding()]
Param (
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory = $true)]
    [string]
    $VMName,

    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory = $true)]
    [string]
    $User
)

Begin {
    ######################################## Default Parameters (User-Defined) ########################################
    $vSphereDNS = ''
    $vSphereIP = ''
    $Location = ''
    $Template = ''
    $Datastore = ''
    $NetworkName = ''
    $OSCustomizationSpec = ''
    $ResourcePool = ''
    $HVServerConnection = ''
    $HVDesktopPool = ''
    $HVGlobalDesktopPool = ''



    ######################################## Get Credentials ########################################
    Write-Progress -Activity '[BEGIN] Getting Administrator Credentials'
    $Credentials = Get-Credential -UserName "$env:USERNAME@$env:USERDNSDOMAIN" -Message 'Enter Administrator Password'
    

    ######################################## Importing modules ########################################
    Write-Progress -Activity '[BEGIN] Importing functions and modules.'

    if (-not (Get-Module -Name VMWare*)) {
        Get-Module -ListAvailable VMWare* | Import-Module | Out-Null
    }

    if (-not (Get-Module -Name Pester)) {
        Import-Module -Name Pester -Version 5.6.0
    }

    Import-Module -Name "$PSScriptRoot\Functions\VMWare.HV.Helper"

    foreach ($item in (Get-ChildItem "$PSScriptRoot\Functions\Vsphere Configuration" -Filter '*.ps1' -Recurse -File)) {
        Write-Verbose -Message "[BEGIN] Importing $($item.FullName)"
        . $item.FullName
    }

    ######################################## Connect to vSphere ########################################
    try { 
        Write-Progress -Activity '[BEGIN] Connecting to vSphere server' -Verbose

        Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false

        if ($vSphereDNS) {
            $vSphereIP = (Resolve-DnsName -Name $vSphereDNS).IPAddress
        }
        
        if ($vSphereIP) {
            $vSphereDNS = (Resolve-DnsName -Name $vSphereIP -Type PTR).NameHost
        }

        Connect-VIServer -Server $vSphereDNS -Protocol https -User $Credentials.UserName -Password (New-Object PSCredential 0, $Credentials.Password).GetNetworkCredential().Password
        Connect-HVServer -Server $HVServerConnection -User $Credentials.UserName -Password (New-Object PSCredential 0, $Credentials.Password).GetNetworkCredential().Password
    }
    catch {
        $ErrorMessage = $_
        Write-Warning -Message "[BEGIN] $ErrorMessage"
        Write-Warning -Message "[BEGIN] Exception Type: $($Error[0].Exception.GetType().FullName)"
    }


    ######################################## Helper Functions ########################################
    function Get-LightestServer {
        [CmdletBinding()]
        [OutputType([psobject])]
        Param()    

        Begin {
            # This function gets the host's load measurements.
            function Measure-VMHostLoad {
                [OutputType([VMware.VimAutomation.ViCore.Impl.V1.Inventory.InventoryItemImpl[]])]
                Param (
                    [ValidateNotNullOrEmpty()]
                    [Parameter(Mandatory = $true)]
                    [System.Array]
                    $Servers
                )
    
                foreach ($Server in $Servers) {
                    $Load = [Math]::Round(((($Server.CpuUsageMhz / $Server.CpuTotalMhz) + ($Server.MemoryUsageGB / $Server.MemoryTotalGB)) / 2) + 0.005, 6)
                    Write-Debug -Message "Server $($Server.Name), Load Value: $Load"
                    $Server | Add-Member -MemberType NoteProperty -Name Load -Value $Load -Force
                }

                $Servers | Sort-Object -Descending -Property 'Load'
            }

            $Servers = Get-VMHost | Where-Object { $_.Name -like 'vmwsp1*' }
        }

        Process {
            foreach ($Server in $Servers) {
                Write-Verbose -Message ('[Select-LightestServer] Server: {0}' -f $Server)
                $Cluster = Get-Cluster -VMHost $Server
                $ClusterHosts = $Cluster | Get-VMHost | Where-Object { $_.ConnectionState -eq 'Connected' }
                $HostLoads = Measure-VMHostLoad -Servers $ClusterHosts
                $AverageLoad = ($HostLoads | Measure-Object -Property 'Load' -Average).Average
                $LightestLoadHosts = ($HostLoads | Where-Object { $_.Load -le $AverageLoad }).Name | ForEach-Object { Get-VMHost $_ }
                Write-Verbose -Message ('[SELECT-LIGHTESTSERVER] Destinations: {0}' -f ($LightestLoadHosts.Name -join ','))
            }
    
            $LightestLoadHosts | Where-Object { $_.ConnectionState -eq 'Connected' } | Get-Random
        }
    }

    function New-PawVMObject {
        # This function captures node loads and returns it as an object.
        $NewPawAttributes = @{
            Name                = $VMName
            Location            = (Get-Folder $Location)
            Template            = (Get-Template $Template)
            Datastore           = (Get-Datastore $Datastore)
            NetworkName         = (Get-VDPortgroup $NetworkName)
            VMHost              = (Get-VMHost (Get-LightestServer).Name)
            OSCustomizationSpec = (Get-OSCustomizationSpec $OSCustomizationSpec)
            # ResourcePool = (Get-ResourcePool 'HEERF')
        }

        New-VM @NewPawAttributes        
    }
}


######################################## Execute ########################################
Process {
    Write-Progress "Creating VM: $VMName"

    $Paw = New-PawVMObject

    Write-Progress "Created new VM: $($Paw.Name)"

    Start-Sleep -Seconds 30

    # Pester tests
    # Invoke-Pester ...

    # Start VM
    Write-Progress "Starting VM: $($Paw.Name)" 

    Start-VM -VM $Paw.Name

    # Verify guest customization by looking for relevant events
    Write-Progress -Activity "Verifying that Customization for VM $($Paw.Name) has started" -Verbose
    while ($true) {
        $PawVMEvents = Get-VIEvent -Entity $Paw.Name
        $PawVMStartedEvent = $PawVMEvents | Where-Object { $_.GetType().Name -eq "CustomizationStartedEvent" }
        
        if ($PawVMStartedEvent) {
            break
        } else {
            Start-Sleep -Seconds 5
        }
    }   
    
    Write-Progress -Activity "Customization of VM $($Paw.Name) has started. Checking for Completed Status" -Verbose
    
    while ($true) {
        $PawVMEvents = Get-VIEvent -Entity $Paw.Name
        $PawVMSucceededEvent = $PawVMEvents | Where-Object { $_.GetType().Name -eq "CustomizationSucceeded"}
        $PawVMFailedEvent = $PawVMEvents | Where-Object { $_.GetType().Name -eq "CustomizationFailed" }

        if ($PawVMFailedEvent) {
            Write-Warning -Message "Customization of VM $($Paw.Name) failed" -Verbose
            Write-Warning -Message "FullFormattedMessage: $($PawVMFailedEvent.FullFormattedMessage)"
            return $false
        }

        if ($PawVMSucceededEvent) {
            Write-Debug -Message "Customization Event Successful" -Verbose
            Write-Debug -Message "FullFormattedMessage: $($PawVMSucceededEvent.FullFormattedMessage)"
            break
        }

        Start-Sleep -Seconds 5
    }    

    Write-Progress -Activity "Customization of VM $($Paw.Name) Completed Successfully!" -Verbose
    
    # NOTE: The below Sleep command is to help prevent situations where the post customization reboot is delayed slightly causing the Wait-Tools command to think everything is fine and carrying on with the script before all services are ready
    Start-Sleep -Seconds 30

    Write-Progress "Waiting for VM $($Paw.Name) to complete post-customization reboot" -Verbose
    
    Wait-Tools -VM $Paw.Name -TimeoutSeconds 300

    # NOTE: Another short sleep here to make sure that other services have time to come up after VMWare Tools are ready.
    Start-Sleep -Seconds 30

    Wait-Tools -VM $Paw.Name -TimeoutSeconds 300

    Start-Sleep -Seconds 30

    Write-Progress -Activity "Adding $($Paw.Name) to $HVDesktopPool"
    Add-HVDesktop -PoolName $HVDesktopPool -Machines $Paw.Name
    Start-Sleep -Seconds 15

    Write-Progress -Activity "Adding $User@$env:USERDNSDOMAIN to $HVGlobalDesktopPool" -Verbose
    New-HVEntitlement -User "$User@$env:USERDNSDOMAIN" -ResourceName $HVGlobalDesktopPool -ResourceType GlobalEntitlement
    Start-Sleep -Seconds 10

    Write-Progress -Activity "Adding $User@$env:USERDNSDOMAIN to $HVDesktopPool" 
    New-HVEntitlement -User "$User@$env:USERDNSDOMAIN" -ResourceName $HVDesktopPool -ResourceType Desktop
    Start-Sleep -Seconds 10

    Write-Progress -Activity "Assigning $User@$env:USERDNSDOMAIN to $($Paw.Name)"
    Set-HVMachine -MachineName $Paw.Name -User "$User@$env:USERDNSDOMAIN"
    Start-Sleep -Seconds 10
}


######################################## Disconnect from vSphere ########################################
End {
    Write-Progress -Activity "Disconnecting from Servers" -Verbose
    Start-Sleep -Seconds 10

    Write-Progress -Activity 'Disconnecting from vSphere server' -Verbose
    Disconnect-VIServer -Server $Global:DefaultVIServer.Name -Confirm:$false
    Start-Sleep -Seconds 5

    Write-Progress -Activity "Disconnecting from Horizon Server" -Verbose
    Disconnect-HVServer -Server $Global:DefaultHVServers -Confirm:$false
    Start-Sleep -Seconds 5

    Write-Host "`nVM $($Paw.Name) Creation is Complete. Test User $User's horizon client to see if they have full access to their new PAW." -ForegroundColor Green
}

