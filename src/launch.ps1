<#
.SYNOPSIS
NetSense is an OpenSource network tool made by DVB that provides a suite of features:
- Port Checker (TCP & UDP)
- Monitoring Tool with logging (Input IP-addresses or hostnames and check if they are up or down)
- WiFi analysis with Roaming Logging (Check WiFi signal strength and roaming between access points)
- Manage Interfaces IP settings (static/DHCP, DHCP, DNS, etc.)

.NOTES
Author: DVBNL
Version: 1.0
Created: 07/07/2023
Last Updated: .

.VERSION HISTORY
1.0 - Initial release
1.1 - Added support for older Windows versions

.CREDITS
- netsh-wlanmon by mackenziewifi
#>

# <IMPORT WPF>
#region
# .NET FRAMEWORK CLASSES IMPORT
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms

# XAML
[xml]$XAML = Get-Content "launch.xaml"
$XAML.Window.RemoveAttribute('x:Class')
$XAML.Window.RemoveAttribute('mc:Ignorable')
$XAMLReader = [System.Xml.XmlNodeReader]$XAML
$MainWindow = [Windows.Markup.XamlReader]::Load($XAMLReader)

# UI ELEMENTS IMPORTEREN
$nsManager = New-Object System.Xml.XmlNamespaceManager($XAMLReader.NameTable)
$nsManager.AddNamespace("x", "http://schemas.microsoft.com/winfx/2006/xaml")

$XAML.SelectNodes("//*[@x:Name]", $nsManager) | ForEach-Object {
    $variableName = "launch_$($_.Name)"
    $variableValue = $MainWindow.FindName($_.Name)
    Set-Variable -Name $variableName -Value $variableValue
}

# SET LOGO
$launch_logo.Source = "$PSScriptRoot\netsense.png"
$launch_bottomlogo.Source = "$PSScriptRoot\dvb-color.png"
#endregion

# <FUNCTIONS>
function GetInterface {
    # CLEAR PREVIOUS INTERFACE LIST
    $launch_interfaceList.Items.Clear()
    # GET INTERFACES
    $Interfaces = Get-NetAdapter
    # ADD INTERFACES TO COMBOBOX
    Foreach ($Interface in $Interfaces) {
        $launch_interfaceList.Items.Add($Interface.Name)
    }
}
function GetCurrentIP {
    # CLEAR CURRENT IP FIELDS
    $launch_ipfieldCurrent.Text = ""
    $launch_subnetfieldCurrent.Text = ""
    $launch_gatewayfieldCurrent.Text = ""
    $launch_dns1fieldCurrent.Text = ""
    $launch_dns2fieldCurrent.Text = ""
    # GET CURRENT IP
    $SelectedInterface = $launch_interfaceList.SelectedItem
    $CurrentIP = Get-NetIPConfiguration -InterfaceAlias $SelectedInterface
    $CurrentSubnet = Get-NetIPAddress -InterfaceAlias $SelectedInterface -AddressFamily IPv4
    # FILL FIELDS
    $launch_ipfieldCurrent.Text = $CurrentIP.IPv4Address
    $launch_subnetfieldCurrent.Text = $CurrentSubnet.PrefixLength
    $launch_gatewayfieldCurrent.Text = $CurrentIP.IPv4DefaultGateway | Select-Object -ExpandProperty NextHop
    $launch_dns1fieldCurrent.Text = $CurrentIP.DNSServer | Select-Object -ExpandProperty ServerAddresses | Select-Object -First 1
    $launch_dns2fieldCurrent.Text = $CurrentIP.DNSServer | Select-Object -ExpandProperty ServerAddresses | Select-Object -Skip 1 | Select-Object -First 1
}
function RemoveIP {
    # INTERFACE
    $SelectedInterface = $launch_interfaceList.SelectedItem

    # REMOVE OTHER IP ADDRESSES
    Remove-NetIPAddress -InterfaceAlias $SelectedInterface -AddressFamily "IPv4" -Confirm:$false

    # REMOVE DEFAULT GATEWAY
    $Routing = Get-NetRoute -InterfaceAlias $SelectedInterface -AddressFamily IPv4 -DestinationPrefix 0.0.0.0/0
    if ($Routing) {
        Remove-NetRoute -InterfaceAlias $SelectedInterface -DestinationPrefix 0.0.0.0/0 -Confirm:$false
    }

    # SET DNS TO DHCP
    Set-DnsClientServerAddress -InterfaceAlias $SelectedInterface -ResetServerAddresses -Confirm:$false
}

# LOAD INTERFACES
GetInterface

# BUTTON CLICKS INTERFACE FUNCTIONS
$launch_refreshInterfaces.Add_Click({
        GetInterface
    })
$launch_getCurrentIP.Add_Click({
        GetCurrentIP
    })
$launch_setSettingsIP.Add_Click({
        # ADMIN RUN CHECK
        if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            $launch_setSettingsWarning.Visibility = "Visible"
            $launch_setSettingsWarning.Content = "Please run NetSense as administrator to change IP settings."
        }
        else {
            if ($launch_dhcpCheckbox.IsChecked) {
                # REMOVE OTHER IP ADDRESSES & CLEAR
                RemoveIP
                # SET DHCP
                $SelectedInterface = $launch_interfaceList.SelectedItem
                $interface = Get-NetAdapter -Name $SelectedInterface
                $interface | Set-NetIPInterface -Dhcp Enabled
                GetCurrentIP
            }
            else {
                # REMOVE OTHER IP ADDRESSES & CLEAR
                RemoveIP

                # GET VALUES
                $IPaddress = $launch_ipfield.Text
                $SubnetAddress = $launch_subnetfield.Text
                $GatewayAddress = $launch_gatewayfield.Text
                $DNS1Address = $launch_dns1field.Text
                $DNS2Address = $launch_dns2field.Text
                $SelectedInterface = $launch_interfaceList.SelectedItem

                # SET CUSTOM IP
                $interface = Get-NetAdapter -Name $SelectedInterface
                $interface | Set-NetIPInterface -Dhcp Disabled
                $interface | New-NetIPAddress -AddressFamily IPv4 -IPAddress "$IPaddress" -PrefixLength $SubnetAddress

                # SET DEFAULT GATEWAY
                $interface | New-NetRoute -DestinationPrefix 0.0.0.0/0 -NextHop $GatewayAddress

                # SET DNS
                Set-DnsClientServerAddress -InterfaceIndex $interface.InterfaceIndex -ServerAddresses "$DNS1Address", "$DNS2Address"
            }
        }
    })

# BUTTON CLICKS LAUNCH TOOLS
$launch_launchPortCheck.Add_Click({
        # OPEN PORT CHECKER TOOL SEPERATE PROCESS
        $portwindow = "powershell.exe"
        $portargs = "-File .\port-checker.ps1"
        $portprocess = New-Object System.Diagnostics.ProcessStartInfo -Property @{
            FileName    = $portwindow
            Arguments   = $portargs
            WindowStyle = "Hidden"
        }
        [System.Diagnostics.Process]::Start($portprocess) | Out-Null
    })
$launch_launchMonitoring.Add_Click({
        # OPEN HOST MONITOR TOOL SEPERATE PROCESS
        $portwindow = "powershell.exe"
        $portargs = "-File .\hostmonitor.ps1"
        $portprocess = New-Object System.Diagnostics.ProcessStartInfo -Property @{
            FileName    = $portwindow
            Arguments   = $portargs
            WindowStyle = "Hidden"
        }
        [System.Diagnostics.Process]::Start($portprocess) | Out-Null
    })
$launch_launchWiFiMon.Add_Click({
        # OPEN WIFI MONITOR TOOL
        $portwindow = "powershell.exe"
        $portargs = "-File .\wifimonitor.ps1"
        $portprocess = New-Object System.Diagnostics.ProcessStartInfo -Property @{
            FileName    = $portwindow
            Arguments   = $portargs
            WindowStyle = "Hidden"
        }
        [System.Diagnostics.Process]::Start($portprocess) | Out-Null
    })

# SHOW DIALOG
$MainWindow.ShowDialog() | Out-Null