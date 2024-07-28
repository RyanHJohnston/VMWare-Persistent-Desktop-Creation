# VMware PAW Creation

## Synopsis
This script builds a complete Windows 11 ESE PAW in the SP1 cluster 2 environment, given a specified VM name and user. 

## Requirements
The script does require PowerCLI and Pester modules. It can only be run in an environment that can connect to vSphere.

```powershell
Install-Module -Name VMWare.PowerCLI
Install-Module -Name Pester -Version 5.6.0 -Force
```

## Usage
The script requires a ```VMName``` and ```User``` to assign the the VM to. When naming the VM, follow the naming schemes of ```ESE-VDI-PAW00```.

```powershell
.\New-PawVM.ps1 -VMName 'ESE-VDI-PAW00' -User 'abc123'
```

## Goals
- ### Dynamic Parameters
    - As VDI migrates to the VDI 2.0 environment and Windows 11 desktops, there will be PAWs that require more nuance and customization to meet the needs of the administrator. If needed, the parameters in the script can be manually changed. The script will fail during its units tests if the parameters do not meet the requirements of building a PAW.

- ### Accessibility
    - Although the script might seem complex, it will be properly sectioned to allow administrators/analysts to fork this script and make developments of their own. 
- ### Portability
    - The administrator running this script should only require installing the modules and having a connection to vSphere, they should be able to download these files and run without issue. It should, ideally, be completely hands-off.
- ### Full GUI Integration
    - The ultimate accessible and hands-off tool would have a complete graphical interface with drop-down options to select values for the different parameters. Rather than copying/pasting, or git cloning the repository, it will only require a few clicks to build a full Windows 11 ESE PAW. The goal is to replicate the usability of the graphical user interface of the administrator console provided by VMWare. 

## References
All third-party tools are from this GitHub repository: https://github.com/vmware/PowerCLI-Example-Scripts/tree/master/Modules.