#Requires -Modules VMware.PowerCli
# This function captures host node loads and returns it as a object.

function Get-LightestServer {
    <#
    .SYNOPSIS
    
    
    .EXAMPLE
    #>
    [CmdletBinding()]
    [OutputType([psobject])]
    Param()    

    Begin {
        
        # This function gets the host's load measurements.
        function Measure-VMHostLoad {
            Param ([ValidateNotNullOrEmpty()][Parameter(Mandatory = $True)][System.Array]$Servers)
            $Properties = @(
                'Name'
                @{ n = 'CpuLoad'; e = { $_.CpuUsageMhz / $_.CpuTotalMhz } }
                @{ n = 'MemLoad'; e = { $_.MemoryUsageGB / $_.MemoryTotalGB } }
                @{ n = 'Load'; e = { ( ($_.CpuUsageMhz / $_.CpuTotalMhz) + ($_.MemoryUsageGB / $_.MemoryTotalGB)) / 2 } }
            )
            Return $Servers = Select-Object -Property $Properties | Sort-Object -Property 'Load'
        }

        if ((Resolve-DnsName -Name ($Global:DefaultVIServer).Name).IPAddress -eq '129.115.105.92') {
            $Servers = Get-VMHost | Where-Object { $_.Name -like 'vmwjplc1n*' }
        }
        else {
            $Servers = Get-VMHost | Where-Object { $_.Name -like 'vmwsp1*' }
        }
    }
    
    Process {
        foreach ($Server in $Servers) {
            Write-Verbose ('[Select-LightestServer] Server: {0}' -f $Server)
            $Cluster = Get-Cluster -VMHost $Server
            $ClusterHosts = $Cluster | Get-VMHost | Where-Object {$_.ConnectionState -eq 'Connected'}
            $HostLoads = Measure-VMHostLoad -Servers $ClusterHosts
            $AverageLoad = ($HostLoads | Measure-Object -Property 'Load' -Average).Average
            $LightestLoadHosts = ($HostLoads | Where-Object {$_.Load -le $AverageLoad}).Name | ForEach-Object { Get-VMHost $_ }
            Write-Verbose ('[SELECT-LIGHTESTSERVER] Destinations: {0}' -f ($LightestLoadHosts.Name -join ','))
        }
    }

    End {
        New-Object -Property $RandomLightestLoadHost -TypeName psobject {
            $LightestLoadHosts | Where-Object {$_.ConnectionState -eq 'Connected'} | Get-Random
        }
    }
}