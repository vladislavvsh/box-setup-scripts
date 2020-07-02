###############################################################################
#
# https://github.com/JonCubed/boxstarter.git
#
# Description: Boxstarter Script
#
# Install boxstarter:
#
# 	Set-ExecutionPolicy RemoteSigned
#	. { iwr -useb https://boxstarter.org/bootstrapper.ps1 } | iex; Get-Boxstarter -Force
#
# NOTE the "." above is required.
#
# Update App Store first!
# Run this boxstarter by calling the following from **elevated** powershell:
#
#	$cred = Get-Credential
# 	Install-BoxstarterPackage -PackageName https://raw.githubusercontent.com/vladislavvsh/box-setup-scripts/master/BoxStarter.ps1 -Credential $cred -Force
#
# TODO:
# 1. May fail Vs2019DownloadAndInstallExtWithCheckpoint -PackageName "VisualStudioPlatformTeam.ProductivityPowerPack2017"
# 2. KeePass plugin https://github.com/iSnackyCracky/KeePassRDP/releases
###############################################################################

$Env = [Environment]::GetEnvironmentVariable("Env", "Process")

$Boxstarter.RebootOk = $true # Allow reboots
$Boxstarter.NoPassword = $false # machine has login password
$Boxstarter.AutoLogin = $true # Encrypt and temp store password for auto-logins after reboot

$checkpointPrefix = "BoxStarter:Checkpoint:"

# Workaround for nested chocolatey folders resulting in path too long error
$chocoCachePath = "C:\Temp"
New-Item -Path $chocoCachePath -ItemType directory -Force

# Script libs & configs
$contentPath = "$chocoCachePath\Box"
New-Item -Path $contentPath -ItemType directory -Force

Function Get-CheckpointName {
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $CheckpointName
    )
    return "$checkpointPrefix$CheckpointName"
}

Function Set-Checkpoint {
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $CheckpointName,

        [Parameter(Mandatory = $true)]
        [string]
        $CheckpointValue
    )

    $key = Get-CheckpointName $CheckpointName
    [Environment]::SetEnvironmentVariable($key, $CheckpointValue, "Machine") # for reboots
    [Environment]::SetEnvironmentVariable($key, $CheckpointValue, "Process") # for right now
}

Function Get-Checkpoint {
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $CheckpointName
    )

    $key = Get-CheckpointName $CheckpointName
    [Environment]::GetEnvironmentVariable($key, "Process")
}

Function Clear-Checkpoints {
    $checkpointMarkers = Get-ChildItem Env: | Where-Object { $_.name -like "$checkpointPrefix*" } | Select-Object -ExpandProperty name
    foreach ($checkpointMarker in $checkpointMarkers) {
        [Environment]::SetEnvironmentVariable($checkpointMarker, '', "Machine")
        [Environment]::SetEnvironmentVariable($checkpointMarker, '', "Process")
    }
}

Function Use-Checkpoint {
    param(
        [string]
        $CheckpointName,

        [string]
        $SkipMessage,

        [scriptblock]
        $Function
    )

    $checkpoint = Get-Checkpoint -CheckpointName $CheckpointName

    if (-not $checkpoint) {
        $Function.Invoke($Args)

        Set-Checkpoint -CheckpointName $CheckpointName -CheckpointValue 1
    }
    else {
        Write-BoxstarterMessage $SkipMessage
    }
}

Function Update-Path {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
}

Function Vs2019DownloadAndInstallExt() {
	param (
		[Parameter(Mandatory = $true)]
        [string]
        $PackageName
	)

	$vsixInstaller = "C:\Program Files (x86)\Microsoft Visual Studio\2019\Enterprise\Common7\IDE\VSIXInstaller"
	$vsixLocation = "$($env:Temp)\$([guid]::NewGuid()).vsix"
	$baseProtocol = "https:"
	$baseHostName = "marketplace.visualstudio.com"
	$uri = "$($baseProtocol)//$($baseHostName)/items?itemName=$($PackageName)"

	Write-BoxstarterMessage "Grabbing VSIX extension page at $($uri)"
    $content = Invoke-WebRequest -Uri $uri -UseBasicParsing
	$parsedHtml = New-Object -Com "HTMLFile"
	$parsedHtml.IHTMLDocument2_write($content.RawContent)

	Write-BoxstarterMessage "Attempting to find package download url..."
	$anchors = $parsedHtml.getElementsByTagName("a") | Where-Object {$_.getAttributeNode("class").Value -eq "install-button-container"}
	if (-Not $anchors) {
		Write-Error "Could not find download anchor tag on the Visual Studio Extensions page."
		Exit 1
	}

	$anchor = @($anchors)[0]
	$anchor.protocol = $baseProtocol
	$anchor.hostname = $baseHostName

    Write-BoxstarterMessage "Found $($anchor.href). Downloading..."
	Invoke-WebRequest $anchor.href -OutFile $vsixLocation

	if (-Not (Test-Path $vsixLocation)) {
		Write-BoxstarterMessage "Downloaded VSIX file could not be located."
		Exit 1
	}

    Write-BoxstarterMessage "Done."
	Write-BoxstarterMessage "Installing $($PackageName)..."
	Start-Process -Filepath $vsixInstaller -ArgumentList "/q /a /nr $($vsixLocation)" -Wait

    Write-BoxstarterMessage "Done."
	Write-BoxstarterMessage "Cleanup..."
	Remove-Item $vsixLocation
	Write-BoxstarterMessage "Installation of $($PackageName) complete!"
}

Function Vs2019DownloadAndInstallExtWithCheckpoint {
    param(
		[Parameter(Mandatory = $true)]
        [string]
        $PackageName
    )

    Use-Checkpoint `
        -Function ${Function:Vs2019DownloadAndInstallExt} `
        -CheckpointName "Vs2019Ext:$PackageName" `
        -SkipMessage "$PackageName is already installed" `
        $PackageName
}

Function DownloadScriptContent {
	$archive = "$contentPath\master.zip"

	Invoke-WebRequest https://github.com/vladislavvsh/box-setup-scripts/archive/master.zip -UseBasicParsing -OutFile $archive
	Expand-Archive -Force -Path $archive -DestinationPath $contentPath

	Move-Item (Join-Path $contentPath 'box-setup-scripts-master\*') $contentPath
	Remove-Item -Path (Join-Path $contentPath 'box-setup-scripts-master')

	Remove-Item $archive
}

Function DeleteScriptContent {
	Remove-Item -Path $contentPath -Force -Recurse
}

Function WindowsUpdate {
    if (Test-Path env:\BoxStarter:SkipWindowsUpdate) {
        return
	}

	Write-BoxstarterMessage "####################################"
	Write-BoxstarterMessage "# Updating windows"
	Write-BoxstarterMessage "####################################"

    Enable-MicrosoftUpdate
	Install-WindowsUpdate -AcceptEula
}

Function Enable-ChocolateyFeatures {
    choco feature enable --name=allowGlobalConfirmation
}

Function Disable-ChocolateyFeatures {
    choco feature disable --name=allowGlobalConfirmation
}

Function Set-BaseSettings {
	Write-BoxstarterMessage "####################################"
	Write-BoxstarterMessage "# Base Settings"
	Write-BoxstarterMessage "####################################"

    Update-ExecutionPolicy -Policy Unrestricted
}

Function Set-PowerSettings {
	Write-BoxstarterMessage "####################################"
	Write-BoxstarterMessage "# Power Settings"
	Write-BoxstarterMessage "####################################"

	# Turn off hibernation
	powercfg /H OFF

	# Change Power saving options (ac=plugged in dc=battery)
	powercfg -change -monitor-timeout-ac 15
	powercfg -change -monitor-timeout-dc 5
	powercfg -change -standby-timeout-ac 0
	powercfg -change -standby-timeout-dc 30
	powercfg -change -disk-timeout-ac 0
	powercfg -change -disk-timeout-dc 30
	powercfg -change -hibernate-timeout-ac 0
}

Function Install-CoreApps {
	Write-BoxstarterMessage "####################################"
	Write-BoxstarterMessage "# Core Apps"
	Write-BoxstarterMessage "####################################"

	choco install chocolateygui --cacheLocation $chocoCachePath --limitoutput
	choco install shutup10 --cacheLocation $chocoCachePath --limitoutput
	choco install microsoft-windows-terminal --cacheLocation $chocoCachePath --limitoutput
	choco install 7zip.install --cacheLocation $chocoCachePath --limitoutput
	choco install vlc --cacheLocation $chocoCachePath --limitoutput
	choco install paint.net --cacheLocation $chocoCachePath --limitoutput
	choco install adobereader --cacheLocation $chocoCachePath --limitoutput
	choco install sumatrapdf --cacheLocation $chocoCachePath --limitoutput
	choco install dropbox --cacheLocation $chocoCachePath --limitoutput
	choco install sharex --cacheLocation $chocoCachePath --limitoutput
	choco install ffmpeg --cacheLocation $chocoCachePath --limitoutput
	choco install rufus --cacheLocation $chocoCachePath --limitoutput
	choco install notepadplusplus.install --cacheLocation $chocoCachePath --limitoutput
	choco install caffeine --cacheLocation $chocoCachePath --limitoutput
	choco install boostnote --cacheLocation $chocoCachePath --limitoutput
}

Function Install-Browsers {
	Write-BoxstarterMessage "####################################"
	Write-BoxstarterMessage "# Browsers"
	Write-BoxstarterMessage "####################################"

	choco install googlechrome --cacheLocation $chocoCachePath --limitoutput
	choco install tor-browser --cacheLocation $chocoCachePath --limitoutput

	choco pin add -n=googlechrome
}

Function Install-Messengers {
	Write-BoxstarterMessage "####################################"
	Write-BoxstarterMessage "# Messengers"
	Write-BoxstarterMessage "####################################"

	choco install skype --cacheLocation $chocoCachePath --limitoutput
	choco install slack --cacheLocation $chocoCachePath --limitoutput
	choco install telegram.install --cacheLocation $chocoCachePath --limitoutput
	choco install whatsapp --cacheLocation $chocoCachePath --limitoutput
	choco install zoom --cacheLocation $chocoCachePath --limitoutput

	choco pin add -n=skype
}

Function Install-KeePass {
	Write-BoxstarterMessage "####################################"
	Write-BoxstarterMessage "# KeePass"
	Write-BoxstarterMessage "####################################"

	choco install keepass.install --cacheLocation $chocoCachePath --limitoutput
	choco install keepass-plugin-keeagent --cacheLocation $chocoCachePath --limitoutput
	choco install keepass-plugin-keeanywhere --cacheLocation $chocoCachePath --limitoutput
	choco install keepass-keepasshttp --cacheLocation $chocoCachePath --limitoutput
	choco install keepass-rpc --cacheLocation $chocoCachePath --limitoutput
	choco install keepass-plugin-winhello --cacheLocation $chocoCachePath --limitoutput
}

Function Install-VisualStudio2019 {
	Write-BoxstarterMessage "####################################"
	Write-BoxstarterMessage "# Visual Studio 2019"
	Write-BoxstarterMessage "####################################"

	choco install visualstudio2019enterprise --params="--locale en-US --passive --norestart --wait --config $($contentPath)\configs\.vsconfig"
	choco pin add -n=visualstudio2019enterprise
}

Function Install-VisualStudio2019Extensions {
	Write-BoxstarterMessage "####################################"
	Write-BoxstarterMessage "# Visual Studio 2019 Extensions"
	Write-BoxstarterMessage "####################################"

	choco install resharper-ultimate-all --pre --cacheLocation $chocoCachePath --limitoutput

	choco pin add -n=resharper-ultimate-all

	Add-Type -Path "$contentPath\libs\Microsoft.mshtml.dll"

	Vs2019DownloadAndInstallExtWithCheckpoint -PackageName "MadsKristensen.AddNewFile"
	Vs2019DownloadAndInstallExtWithCheckpoint -PackageName "MadsKristensen.TrailingWhitespaceVisualizer"
	Vs2019DownloadAndInstallExtWithCheckpoint -PackageName "MadsKristensen.WebPackTaskRunner"
	Vs2019DownloadAndInstallExtWithCheckpoint -PackageName "MadsKristensen.NPMTaskRunner"
	Vs2019DownloadAndInstallExtWithCheckpoint -PackageName "MadsKristensen.PackageInstaller"
	Vs2019DownloadAndInstallExtWithCheckpoint -PackageName "MadsKristensen.YarnInstaller"
	Vs2019DownloadAndInstallExtWithCheckpoint -PackageName "MadsKristensen.DummyTextGenerator"
	Vs2019DownloadAndInstallExtWithCheckpoint -PackageName "MadsKristensen.MarkdownEditor"
	Vs2019DownloadAndInstallExtWithCheckpoint -PackageName "MadsKristensen.ShowSelectionLength"

	Vs2019DownloadAndInstallExtWithCheckpoint -PackageName "VisualStudioPlatformTeam.PowerCommandsforVisualStudio"
	Vs2019DownloadAndInstallExtWithCheckpoint -PackageName "VisualStudioPlatformTeam.ProductivityPowerPack2017"
	Vs2019DownloadAndInstallExtWithCheckpoint -PackageName "VisualStudioPlatformTeam.VisualStudio2019ColorThemeEditor"
	Vs2019DownloadAndInstallExtWithCheckpoint -PackageName "TomasRestrepo.Viasfora"
	Vs2019DownloadAndInstallExtWithCheckpoint -PackageName "josefpihrt.Roslynator2019"
	Vs2019DownloadAndInstallExtWithCheckpoint -PackageName "SonarSource.SonarLintforVisualStudio2019"
	Vs2019DownloadAndInstallExtWithCheckpoint -PackageName "TomEnglert.ResXManager"
	Vs2019DownloadAndInstallExtWithCheckpoint -PackageName "NikolayBalakin.Outputenhancer"
}

Function Install-VisualStudioCode  {
	Write-BoxstarterMessage "####################################"
	Write-BoxstarterMessage "# Visual Studio Code"
	Write-BoxstarterMessage "####################################"

	choco install vscode --params="/NoDesktopIcon" --cacheLocation $chocoCachePath --limitoutput

	choco pin add -n=vscode

	Update-Path
}

Function Install-VSCodeExtensions {
	Write-BoxstarterMessage "####################################"
	Write-BoxstarterMessage "# Visual Studio Code Extensions"
	Write-BoxstarterMessage "####################################"

    # need to launch vscode so user folders are created as we can install extensions
	$process = Start-Process code -PassThru
	Start-Sleep -s 60
	$process.Close()

	code --install-extension alexanderte.dainty-material-theme-palenight-vscode
	code --install-extension pkief.material-icon-theme
	code --install-extension ms-vscode.csharp
	code --install-extension ms-vscode.powershell
	code --install-extension ms-vscode.azurecli
	code --install-extension ms-mssql.mssql
	code --install-extension ms-vscode-remote.remote-containers
	code --install-extension ms-vscode-remote.remote-ssh
	code --install-extension ms-vscode-remote.remote-ssh-edit
	code --install-extension ms-vscode-remote.remote-wsl
	code --install-extension ms-vscode-remote.vscode-remote-extensionpack
	code --install-extension ms-azuretools.vscode-docker
	code --install-extension humao.rest-client
	code --install-extension shardulm94.trailing-spaces
	code --install-extension dbaeumer.vscode-eslint
	code --install-extension ms-vscode.vscode-typescript-tslint-plugin
	code --install-extension esbenp.prettier-vscode
	code --install-extension eg2.vscode-npm-script
}

Function Install-Git {
	Write-BoxstarterMessage "####################################"
	Write-BoxstarterMessage "# Git"
	Write-BoxstarterMessage "####################################"

	choco install git --params="/GitOnlyOnPath /WindowsTerminal" --cacheLocation $chocoCachePath --limitoutput
	choco install git-credential-manager-for-windows --cacheLocation $chocoCachePath --limitoutput

	choco install git-fork --cacheLocation $chocoCachePath --limitoutput

	choco pin add -n=git-fork

	# set HOME to user profile for git
	[Environment]::SetEnvironmentVariable("HOME", $env:UserProfile, "User")
}

Function Install-CoreDevApps {
	Write-BoxstarterMessage "####################################"
	Write-BoxstarterMessage "# Core Dev Apps"
	Write-BoxstarterMessage "####################################"

	choco install fiddler --cacheLocation $chocoCachePath --limitoutput
	choco install beyondcompare --cacheLocation $chocoCachePath --limitoutput
	choco install beyondcompare-integration --cacheLocation $chocoCachePath --limitoutput
	choco install sql-server-management-studio --cacheLocation $chocoCachePath --limitoutput
	choco install sysinternals --cacheLocation $chocoCachePath --limitoutput
	choco install putty.install --cacheLocation $chocoCachePath --limitoutput
	choco install winscp.install --cacheLocation $chocoCachePath --limitoutput
	choco install curl --cacheLocation $chocoCachePath --limitoutput
	choco install wget --cacheLocation $chocoCachePath --limitoutput
	choco install postman --cacheLocation $chocoCachePath --limitoutput
	choco install openvpn --params "/SELECT_LAUNCH=0" --cacheLocation $chocoCachePath --limitoutput
	choco install azure-cli --cacheLocation $chocoCachePath --limitoutput
	choco install microsoftazurestorageexplorer --cacheLocation $chocoCachePath --limitoutput
}

Function Install-NodeJsAndNpmPackages {
	Write-BoxstarterMessage "####################################"
	Write-BoxstarterMessage "# NodeJs and Npm Packages"
	Write-BoxstarterMessage "####################################"

	choco install nodejs-lts --cacheLocation $chocoCachePath --limitoutput
	choco install typescript
	choco install yarn
}

Function Install-DevFeatures {
	Write-BoxstarterMessage "####################################"
	Write-BoxstarterMessage "# Dev Features"
	Write-BoxstarterMessage "####################################"

	choco install Microsoft-Hyper-V-All -source windowsFeatures --cacheLocation $chocoCachePath --limitoutput
	choco install Containers -source windowsFeatures --cacheLocation $chocoCachePath --limitoutput
	choco install TelnetClient -source windowsFeatures --cacheLocation $chocoCachePath --limitoutput

	choco install Microsoft-Windows-Subsystem-Linux -source windowsFeatures --cacheLocation $chocoCachePath --limitoutput

	# TODO: Move this to choco install once --root is included in that package
	# choco install wsl-ubuntu-1804 --cacheLocation $chocoCachePath --limitoutput
	$appLocation = "$($env:Temp)\Ubuntu.appx"
	Invoke-WebRequest -Uri https://aka.ms/wsl-ubuntu-1804 -OutFile $appLocation -UseBasicParsing
	Add-AppxPackage -Path $appLocation
	Remove-Item $appLocation

	# run the distro once and have it install locally with root user, unset password
	RefreshEnv
	Ubuntu1804 install --root
	Ubuntu1804 run apt update
	Ubuntu1804 run apt upgrade -y
}

Function Install-Docker {
	Write-BoxstarterMessage "####################################"
	Write-BoxstarterMessage "# Docker"
	Write-BoxstarterMessage "####################################"

	choco install docker-desktop --cacheLocation $chocoCachePath --limitoutput
	choco install docker-compose --cacheLocation $chocoCachePath --limitoutput

	choco pin add -n=docker-desktop
	choco pin add -n=docker-compose
}

Function SetUp-PowerShell {
	Write-BoxstarterMessage "####################################"
	Write-BoxstarterMessage "# PowerShell"
	Write-BoxstarterMessage "####################################"

	Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
	Set-PSRepository -Name PSGallery -InstallationPolicy 'Trusted'
	Install-Module -Name 'posh-git' -Scope AllUsers
	Install-Module -Name 'oh-my-posh' -Scope AllUsers
	Install-Module -Name 'AzureRM' -Scope AllUsers
	Install-Module -Name 'Azure' -Scope AllUsers -AllowClobber
}

Write-BoxstarterMessage "Starting setup"

Use-Checkpoint -Function ${Function:DownloadScriptContent} -CheckpointName 'DownloadScriptContent' -SkipMessage 'Download Script Content is already finished'

Use-Checkpoint -Function ${Function:WindowsUpdate} -CheckpointName 'FirstWindowsUpdate' -SkipMessage 'First WindowsUpdate os already finished'

Use-Checkpoint -Function ${Function:Enable-ChocolateyFeatures} -CheckpointName 'InitChoco' -SkipMessage 'Chocolatey features are already configured'

Use-Checkpoint -Function ${Function:Set-BaseSettings} -CheckpointName 'BaseSettings' -SkipMessage 'Base settings are already configured'

Use-Checkpoint -Function ${Function:Set-PowerSettings} -CheckpointName 'PowerSettings' -SkipMessage 'Power settings are already configured'

Write-BoxstarterMessage "Starting installs"

Use-Checkpoint -Function ${Function:Install-CoreApps} -CheckpointName 'CoreApps' -SkipMessage 'Core Apps are already installed'

Use-Checkpoint -Function ${Function:Install-Browsers} -CheckpointName 'Browsers' -SkipMessage 'Browsers are already installed'

Use-Checkpoint -Function ${Function:Install-Messengers} -CheckpointName 'Messengers' -SkipMessage 'Messengers are already installed'

Use-Checkpoint -Function ${Function:Install-KeePass} -CheckpointName 'KeePass' -SkipMessage 'KeePass is already installed'

if ($Env -eq "dev") {
	Use-Checkpoint -Function ${Function:Install-VisualStudio2019} -CheckpointName 'VisualStudio2019' -SkipMessage 'Visual Studio 2019 is already installed'

	Use-Checkpoint -Function ${Function:Install-VisualStudio2019Extensions} -CheckpointName 'VisualStudio2019Extensions' -SkipMessage 'Visual Studio 2019 Extensions are already installed'

	Use-Checkpoint -Function ${Function:Install-VisualStudioCode} -CheckpointName 'VisualStudioCode' -SkipMessage 'Visual Studio Code is already installed'

	Use-Checkpoint -Function ${Function:Install-VSCodeExtensions} -CheckpointName 'VSCodeExtensions' -SkipMessage 'Visual Studio Code Extensions are already installed'

	Use-Checkpoint -Function ${Function:Install-Git} -CheckpointName 'Git' -SkipMessage 'Git is already installed'

	Use-Checkpoint -Function ${Function:Install-CoreDevApps} -CheckpointName 'CoreDevApps' -SkipMessage 'Core Dev Apps are already installed'

	Use-Checkpoint -Function ${Function:Install-NodeJsAndNpmPackages} -CheckpointName 'NodeJsAndNpmPackages' -SkipMessage 'NodeJs And Npm Packages are already installed'

	Use-Checkpoint -Function ${Function:Install-DevFeatures} -CheckpointName 'DevFeatures' -SkipMessage 'Dev Features are already installed'

	Use-Checkpoint -Function ${Function:Install-Docker} -CheckpointName 'Docker' -SkipMessage 'Docker is already installed'

	Use-Checkpoint -Function ${Function:SetUp-PowerShell} -CheckpointName 'SetUp-PowerShell' -SkipMessage 'PowerShell is already configured'
}

# install chocolatey as last choco package
choco install chocolatey --cacheLocation $chocoCachePath --limitoutput
choco install choco-upgrade-all-at --params "'/DAILY:yes /TIME:14:00 /ABORTTIME:16:00'" --cacheLocation $chocoCachePath --limitoutput
choco install choco-cleaner --cacheLocation $chocoCachePath --limitoutput

# re-enable chocolatey default confirmation behaviour
Use-Checkpoint -Function ${Function:Disable-ChocolateyFeatures} -CheckpointName 'DisableChocolatey' -SkipMessage 'Chocolatey features already configured'

if (Test-PendingReboot) { Invoke-Reboot }

# reload path environment variable
Update-Path

# rerun windows update after we have installed everything
Write-BoxstarterMessage "Windows update..."
WindowsUpdate

Clear-Checkpoints

DeleteScriptContent

Write-BoxstarterMessage "Finished"