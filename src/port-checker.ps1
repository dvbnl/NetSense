<#
.SYNOPSIS
This scripts provides the Port Checker tool for NetSense.

.NOTES
Author: DVBNL
Version: 1.0
Created: 07/07/2023
Last Updated: .

.VERSION HISTORY
1.0 - Initial release
#>

# <IMPORT WPF>
#region
# .NET FRAMEWORK CLASSES IMPORT
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms

# XAML
[xml]$XAML = Get-Content "port-checker.xaml"
$XAML.Window.RemoveAttribute('x:Class')
$XAML.Window.RemoveAttribute('mc:Ignorable')
$XAMLReader = [System.Xml.XmlNodeReader]::new($XAML)
$MainWindow = [Windows.Markup.XamlReader]::Load($XAMLReader)

# UI ELEMENTS IMPORTEREN
$nsManager = New-Object System.Xml.XmlNamespaceManager($XAMLReader.NameTable)
$nsManager.AddNamespace("x", "http://schemas.microsoft.com/winfx/2006/xaml")

$XAML.SelectNodes("//*[@x:Name]", $nsManager) | ForEach-Object {
    $variableName = "port_$($_.Name)"
    $variableValue = $MainWindow.FindName($_.Name)
    Set-Variable -Name $variableName -Value $variableValue
}
#endregion

# <FUNCTIONS>
function PortQueryOld {
    $port_portcheckResultLog.Items.Clear()

    # USER INPUT FIELDS
    $DestHost = $port_portcheckHost.Text
    $DestPort = $port_portcheckPort.Text
    $DestProto = $port_portcheckProtocol.SelectedItem.Content

    # PORT CHECK
    $timeoutMilliseconds = 1000

    try {
        if ($DestProto -eq "TCP") {
            $socket = New-Object System.Net.Sockets.TcpClient
        }
        elseif ($DestProto -eq "UDP") {
            $socket = New-Object System.Net.Sockets.UdpClient
        }

        $result = $socket.BeginConnect($DestHost, $DestPort, $null, $null)
        $success = $result.AsyncWaitHandle.WaitOne($timeoutMilliseconds, $false)

        if ($success) {
            $port_portcheckResultLog.Items.Add("Port $DestPort/$DestProto on $DestHost is open")
            $port_portcheckResultLog.ForeGround = "Green"
        }
        else {
            $port_portcheckResultLog.Items.Add("Port $DestPort/$DestProto on $DestHost is closed")
            $port_portcheckResultLog.ForeGround = "Red"
        }

        $socket.Close()
    }
    catch {
        $port_portcheckResultLog.Items.Add("Fout: $_")
        $port_portcheckResultLog.ForeGround = "Red"
    }
}
function PortQuery {
    $port_portcheckResultLog.Items.Clear()

    # USER INPUT FIELDS
    $DestHost = $port_portcheckHost.Text
    $DestPort = $port_portcheckPort.Text
    $DestProto = $port_portcheckProtocol.SelectedItem.Content

    try {
        if ($DestProto -eq "TCP") {
            # PORT CHECK
            $timeoutMilliseconds = 1000
            $socket = New-Object System.Net.Sockets.TcpClient
            $result = $socket.BeginConnect($DestHost, $DestPort, $null, $null)
            $success = $result.AsyncWaitHandle.WaitOne($timeoutMilliseconds, $false)

            if ($success) {
                $port_portcheckResultLog.Items.Add("Port $DestPort/$DestProto on $DestHost is open")
                $port_portcheckResultLog.ForeGround = "Green"
            }
            else {
                $port_portcheckResultLog.Items.Add("Port $DestPort/$DestProto on $DestHost is closed")
                $port_portcheckResultLog.ForeGround = "Red"
            }
        }
        elseif ($DestProto -eq "UDP") {
            $UdpTest = .\PortQry.exe -n $DestHost -p $DestProto -e $DestPort -nr
            $FinalUDP = ($UDPTest | Select-String -Pattern ': ').Line -replace '.*: '

            if ($FinalUDP -like 'LISTENING') {
                $port_portcheckResultLog.Items.Add("Port $DestPort/$DestProto on $DestHost is open")
                $port_portcheckResultLog.ForeGround = "Green"
            }
            else {
                $port_portcheckResultLog.Items.Add("Port $DestPort/$DestProto on $DestHost is closed")
                $port_portcheckResultLog.ForeGround = "Red"
            }
        }
    }
    catch {
        $port_portcheckResultLog.Items.Add("Fout: $_")
        $port_portcheckResultLog.ForeGround = "Red"
    }
}

# BUTTON CLICKS
$port_portcheckRun.Add_Click({
        PortQuery
    })

$MainWindow.ShowDialog() | Out-Null