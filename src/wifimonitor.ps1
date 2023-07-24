<#
.SYNOPSIS
This scripts provides the WiFi Analyzer tool for NetSense based on netsh-wlanmon by mackenziewifi.

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
[xml]$XAML = Get-Content "wifimonitor.xaml"
$XAML.Window.RemoveAttribute('x:Class')
$XAML.Window.RemoveAttribute('mc:Ignorable')
$XAMLReader = [System.Xml.XmlNodeReader]::new($XAML)
$MainWindow = [Windows.Markup.XamlReader]::Load($XAMLReader)

# UI ELEMENTS IMPORTEREN
$nsManager = New-Object System.Xml.XmlNamespaceManager($XAMLReader.NameTable)
$nsManager.AddNamespace("x", "http://schemas.microsoft.com/winfx/2006/xaml")

$XAML.SelectNodes("//*[@x:Name]", $nsManager) | ForEach-Object {
    $variableName = "wifi_$($_.Name)"
    $variableValue = $MainWindow.FindName($_.Name)
    Set-Variable -Name $variableName -Value $variableValue
}
#endregion

# <FUNCTIONS>
function GetAdapters {
    # CLEAR PREVIOUS INTERFACE LIST
    $wifi_wlanlist.Items.Clear()

    # GET ADAPTERS
    $wifiadapters = netsh wlan show interfaces | Select-String 'Description\s+:' | ForEach-Object { $_.Line -replace 'Description\s+:\s+' }

    # ADD INTERFACES TO COMBOBOX
    Foreach ($Interface in $wifiadapters) {
        $wifi_wlanlist.Items.Add($Interface)
    }
}
function ConnectionState {
    # GET SELECTED INTERFACE
    $SelectedInterface = $wifi_wlanlist.SelectedItem

    # GET STATE
    $wifistate = netsh wlan show interfaces $SelectedInterface | Select-String 'State\s+:' | ForEach-Object { $_.Line -replace 'State\s+:\s+' }

    # SET STATE COLOUR
    if ($wifistate -like "*connected*") {
        $wifi_connectionIndicator.Fill = "Green"
        $wifi_connectedField.Text = "Connected:"
    }

    # UPDATE GUI
    [System.Windows.Forms.Application]::DoEvents()
}
function WiFiProperties {
    # GET SELECTED INTERFACE
    $SelectedInterface = $wifi_wlanlist.SelectedItem

    # GET PROPERTIES
    $wifiproperties = netsh wlan show interfaces $SelectedInterface

    # PROPERTIES WI-FI ADAPTER
    $wifi_interfaceMAC.Text = netsh wlan show interfaces $wifi_wlanlist.SelectedItem | Select-String 'Physical address\s+:' | ForEach-Object { $_.Line -replace 'Physical address\s+:\s+' }
    $wifi_interfaceRadio.Text = netsh wlan show interfaces $wifi_wlanlist.SelectedItem | Select-String 'Radio type\s+:' | ForEach-Object { $_.Line -replace 'Radio type\s+:\s+' }

    # PROPERTIES NETWORK
    $wifi_ssidField.Text = $wifiproperties | Select-String 'SSID' | ForEach-Object { $_.ToString() -replace '.*:\s*', '' } | Select-Object -First 1
    $wifi_bssidField.Text = $wifiproperties | Select-String 'BSSID\s+:' | ForEach-Object { $_.Line -replace 'BSSID\s+:\s+' } | ForEach-Object { $_.Replace(' ', '') }
    $wifi_authField.Text = $wifiproperties | Select-String 'Authentication\s+:' | ForEach-Object { $_.Line -replace 'Authentication\s+:\s+' }
    $wifi_cipherfield.Text = $wifiproperties | Select-String 'Cipher\s+:' | ForEach-Object { $_.Line -replace 'Cipher\s+:\s+' }
    $wifi_channelField.Content = $wifiproperties | Select-String 'Channel\s+:' | ForEach-Object { $_.Line -replace 'Channel\s+:\s+' }

    # PROPERTIES RSSI
    $wifi_bandField.Text = $wifiproperties | Select-String 'Band\s+:' | ForEach-Object { $_.Line -replace 'Band\s+:' }
    $wifi_signalPercentage.Text = $wifiproperties | Select-String 'Signal' | ForEach-Object { $_.ToString() -replace '.*:\s*', '' }
    $wifi_txDataField.Text = $wifiproperties | Select-String 'Transmit rate' | ForEach-Object { $_.ToString() -replace '.*:\s*', '' }
    $wifi_rxDataField.Text = $wifiproperties | Select-String 'Receive rate' | ForEach-Object { $_.ToString() -replace '.*:\s*', '' }

    # UPDATE GUI
    [System.Windows.Forms.Application]::DoEvents()

}
function LogWrite($OldBSSID, $BSSID) {
    # SET LOCATIE VARIABLE
    $SelectedFolder = $wifi_logLocation.Content
    
    if ($wifi_LogCheckBox.IsChecked -eq $true) {
        $DateTag = (Get-Date -format "dd-MMM-yyyy HH:mm:ss")
        $DatumFile = (Get-Date -format "dd-MMM-yyyy")
        "Roaming Event on $DateTag - from $PreviousBSSID --> $CurrentBSSID" | Out-File -FilePath "$SelectedFolder\Roaming Log - $DatumFile.txt" -Append
    }
}

function LogLocation {
    # INSTANCE LOG FOLDER BROWSER
    $folderBrowserDialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $result = $folderBrowserDialog.ShowDialog()
        
    # FOLDER VERIFY
    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        $SelectedFolder = $folderBrowserDialog.SelectedPath
        $wifi_logLocation.Content = "$SelectedFolder"
        $wifi_logLocation.Foreground = "Purple"
        
        # ENABLE CHECKBOX NA INSTELLEN LOCATIE
        $wifi_LogCheckBox.IsEnabled = $true
    }
}

# LOAD ADAPTERS
GetAdapters

# BUTTONS
$wifi_refreshInterfaces.Add_Click({
        GetAdapters
    })
$wifi_startWifiMon.Add_Click({
        # ENABLE STOP BUTTON
        $wifi_stopWiFiMon.IsEnabled = $true
        $wifi_startWifiMon.IsEnabled = $false

        # CHANGE CONNECTIONSTATE IF CLICKED
        ConnectionState

        # EMPTY BSSID
        $PreviousBSSID = $null

        # START LOOP MONITORING
        while ($wifi_connectedField.Text -ne "Disconnected:") {
            if ($wifi_wlanlist.SelectedItem) {
                # SET TIMESTAMP
                $DateCurrent = Get-Date
                $wifi_timestampMon.Content = "Timestamp: $DateCurrent"

                # FILL PROPERTIES
                $PreviousBSSID = $wifi_bssidField.Text
                WiFiProperties
                $CurrentBSSID = $wifi_bssidField.Text

                # ROAMING TRIGGER + LOGGING
                if (($CurrentBSSID -ne $PreviousBSSID) -and ($PreviousBSSID -ne '')) {
                    # GET ROAMINGNUMBER
                    $RoamItems = $wifi_roamingResult.Items.Count
                    $RoamNumber = $RoamItems + 1

                    # LOG IN GUI BOX
                    $DateLogging = Get-Date
                    $RoamingEvent = "#$RoamNumber Roaming event on $DateLogging from $PreviousBSSID --> $CurrentBSSID"
                    $wifi_roamingResult.Items.Add($RoamingEvent)

                    # LOG TO LOGFILE
                    LogWrite -OldBSSID "$PreviousBSSID" -BSSID "$CurrentBSSID"

                    # UPDATE ROAMCOUNT
                    $countfield = $RoamItems + 1
                    $wifi_roamCountField.Text = "$countfield"
                }
            }

            # INTERVAL FUNCTION
            $intervalSeconds = [int]$wifi_IntervalValue.Text
            Start-Sleep -Seconds $intervalSeconds
        }
        
    })
$wifi_stopWiFiMon.Add_Click({
        # BUTTON SWAP + CLEAR TIMESTAMP
        $wifi_startWiFiMon.IsEnabled = $true
        $wifi_stopWiFiMon.IsEnabled = $false
        $wifi_timestampMon.Content = ""
        $wifi_connectionIndicator.Fill = "Red"
        $wifi_connectedField.Text = "Disconnected:"
    })
$wifi_logSetLocation.Add_Click({
        LogLocation
    })

# SHOW DIALOG
$MainWindow.ShowDialog() | Out-Null