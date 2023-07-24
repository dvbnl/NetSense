<#
.SYNOPSIS
This scripts provides the monitoring tool for NetSense.

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
[xml]$XAML = Get-Content "hostmonitor.xaml"
$XAML.Window.RemoveAttribute('x:Class')
$XAML.Window.RemoveAttribute('mc:Ignorable')
$XAMLReader = [System.Xml.XmlNodeReader]::new($XAML)
$MainWindow = [Windows.Markup.XamlReader]::Load($XAMLReader)

# UI ELEMENTS IMPORTEREN
$nsManager = New-Object System.Xml.XmlNamespaceManager($XAMLReader.NameTable)
$nsManager.AddNamespace("x", "http://schemas.microsoft.com/winfx/2006/xaml")

$XAML.SelectNodes("//*[@x:Name]", $nsManager) | ForEach-Object {
    $variableName = "monitor_$($_.Name)"
    $variableValue = $MainWindow.FindName($_.Name)
    Set-Variable -Name $variableName -Value $variableValue
}
#endregion

# <FUNCTIONS>
function LogWrite($HostText) {
    # SET LOCATIE VARIABLE
    $SelectedFolder = $monitor_formLogLocationResult.Content
    
    if ($monitor_formLogBox.IsChecked -eq $true) {
        $Datum = (Get-Date -format "dd-MMM-yyyy HH:mm:ss")
        $DatumFile = (Get-Date -format "dd-MMM-yyyy")
        $HostTextNoPrefix = $InputHost -replace "^System\.Windows\.Controls\.TextBox: "
        "$HostTextNoPrefix DOWN -> $Datum" | Out-File -FilePath "$SelectedFolder\Down Hosts - $DatumFile.txt" -Append
    }
}

function LogLocation {
    # INSTANCE LOG FOLDER BROWSER
    $folderBrowserDialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $result = $folderBrowserDialog.ShowDialog()
        
    # FOLDER VERIFY
    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        $SelectedFolder = $folderBrowserDialog.SelectedPath
        $monitor_formLogLocationResult.Content = "$SelectedFolder"
        $monitor_formLogLocationResult.Foreground = "Purple"
        
        # ENABLE CHECKBOX NA INSTELLEN LOCATIE
        $monitor_formLogBox.IsEnabled = $true
    }
}
function PingTest {
    $Hosts = @()
    $Hosts += $monitor_formHosts1
    $Hosts += $monitor_formHosts2
    $Hosts += $monitor_formHosts3
    $Hosts += $monitor_formHosts4
    $Hosts += $monitor_formHosts5

    foreach ($InputHost in $Hosts) {
        if (Test-Connection -ComputerName $InputHost.Text -Quiet -ErrorAction SilentlyContinue -Count 1) {
            # HOST IS UP
            $monitor_formResultsUp.Items.Add("Host " + $InputHost.Text + " is UP")
        }
        Else {
            # HOST IS DOWN
            $Datum = (Get-Date -format "dd-MMM-yyyy HH:mm:ss")
            $monitor_formResultsDown.Items.Add("Host " + $InputHost.Text + " is DOWN on $Datum")
            LogWrite -HostText "+ $InputHost.Text +"
        }
    }
}

# BUTTON ACTIONS
$monitor_formStartButton.Add_Click({
    $monitor_formResultsDown.Items.Clear() # Nieuwe start -> Clear Down hosts vorige run
    # LOOP START
    while ($monitor_formLabelStatus.Content -ne "Stopped") {

        # BUTTON SWAP + SET STATUS
        $monitor_formStartButton.IsEnabled = $false
        $monitor_formStopButton.IsEnabled = $true

        $DateCurrent = Get-Date
        $monitor_formLabelTime.Content = "Last check: $DateCurrent"
        $monitor_formLabelStatus.Content = "Working..."
        $monitor_formLabelStatus.Foreground = "Black"

        [System.Windows.Forms.Application]::DoEvents()
        
        # CLEAR PREV UP RESULTS
        $monitor_formResultsUp.Items.Clear()

        # START FUNCTION
        PingTest
        [System.Windows.Forms.Application]::DoEvents()

        # INTERVAL FUNCTION
        $intervalSeconds = [int]$monitor_formIntervalValue.Text
        Start-Sleep -Seconds $intervalSeconds
    }
    # BUTTON SWAP & STATUS
    $monitor_formStartButton.IsEnabled = $true
    $monitor_formStopButton.IsEnabled = $false
    $monitor_formLabelStatus.Content = ""
})
$monitor_formStopButton.Add_Click({
    $monitor_formLabelStatus.Content = "Stopped"
    $monitor_formLabelStatus.Foreground = "Red"
    # CLEAR PREV UP RESULTS
    $monitor_formResultsUp.Items.Clear()
})
$monitor_formWisResults.Add_Click({
    $monitor_formResultsDown.Items.Clear()
})
$monitor_formLogButtonLocation.Add_Click({
    LogLocation
})

$MainWindow.ShowDialog() | Out-Null