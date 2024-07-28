function Set-VMUser {
    param (
        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory = $true)]
        [string]
        $vmName,
        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory = $true)]
        [string]
        $poolName,
        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory = $true)]
        [string]
        $user
    )

    Add-HVDesktop -PoolName $poolName -Machines $vmName -Confirm:$false
}