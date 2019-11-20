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
# Run this boxstarter by calling the following from **elevated** powershell:
#
#	Add-Type -Path C:\Program Files (x86)\Microsoft.NET\Primary Interop Assemblies\Microsoft.mshtml.dll
#	$cred = Get-Credential
# 	Install-BoxstarterPackage -PackageName https://raw.githubusercontent.com/vladislavvsh/box-setup-scripts/master/BoxStarter.ps1 -Credential $cred –Force
#
###############################################################################

$Boxstarter.RebootOk = $true # Allow reboots
$Boxstarter.NoPassword = $false # machine has login password
$Boxstarter.AutoLogin = $true # Encrypt and temp store password for auto-logins after reboot

$checkpointPrefix = 'BoxStarter:Checkpoint:'

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

function Update-Path {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
}

Function ConvertTo-NormalHTML {
    param([Parameter(Mandatory = $true, ValueFromPipeline = $true)]$HTML)

	Add-Type -Path C:\Temp\Microsoft.mshtml.dll

    $NormalHTML = New-Object -Com "HTMLFile"
    $NormalHTML.IHTMLDocument2_write($HTML.RawContent)
    return $NormalHTML
}

Function Vs2019DownloadAndInstallExt($packageName) {
	$ErrorActionPreference = "Stop"
    $vsixInstaller = "C:\Program Files (x86)\Microsoft Visual Studio\2019\Enterprise\Common7\IDE\VSIXInstaller"
	$vsixLocation = "$($env:Temp)\$([guid]::NewGuid()).vsix"
	$baseProtocol = "https:"
	$baseHostName = "marketplace.visualstudio.com"
	$uri = "$($baseProtocol)//$($baseHostName)/items?itemName=$($packageName)"

	Write-BoxstarterMessage "Grabbing VSIX extension page at $($uri)"
    $content = Invoke-WebRequest -Uri $uri -UseBasicParsing
    $parsedHtml = ConvertTo-NormalHTML -HTML $content

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
	Write-BoxstarterMessage "Installing $($packageName)..."
	Start-Process -Filepath $vsixInstaller -ArgumentList "/q /a $($vsixLocation)" -Wait

    Write-BoxstarterMessage "Done."
	Write-BoxstarterMessage "Cleanup..."
	Remove-Item $vsixLocation
	Write-BoxstarterMessage "Installation of $($packageName) complete!"
}

Function WindowsUpdate {
    if (Test-Path env:\BoxStarter:SkipWindowsUpdate) {
        return
    }

    Enable-MicrosoftUpdate
    Install-WindowsUpdate -AcceptEula
    #if (Test-PendingReboot) { Invoke-Reboot }
}

function Enable-ChocolateyFeatures {
    choco feature enable --name=allowGlobalConfirmation
}

function Disable-ChocolateyFeatures {
    choco feature disable --name=allowGlobalConfirmation
}

function Set-BaseSettings {
	Write-BoxstarterMessage "####################################"
	Write-BoxstarterMessage "# Base Settings"
	Write-BoxstarterMessage "####################################"

    Update-ExecutionPolicy -Policy Unrestricted
}

Function SetUp-PowerShell {
	Write-BoxstarterMessage "####################################"
	Write-BoxstarterMessage "# PowerShell"
	Write-BoxstarterMessage "####################################"

	Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
	Set-PSRepository -Name PSGallery -InstallationPolicy 'Trusted'
}

Function Install-DevFeatures {
	Write-BoxstarterMessage "####################################"
	Write-BoxstarterMessage "# Dev Features"
	Write-BoxstarterMessage "####################################"

	choco install Microsoft-Windows-Subsystem-Linux -source windowsFeatures --limitoutput
	choco install wsl-ubuntu-1804 --limitoutput

	choco install Microsoft-Hyper-V-All -source windowsFeatures --limitoutput
	choco install Containers -source windowsFeatures --limitoutput
	choco install TelnetClient -source windowsFeatures --limitoutput
}

Function Install-Docker {
	Write-BoxstarterMessage "####################################"
	Write-BoxstarterMessage "# Docker"
	Write-BoxstarterMessage "####################################"

	choco install docker-desktop --limitoutput
	choco install docker-compose --limitoutput

	choco pin add -n=docker-desktop
	choco pin add -n=docker-compose
}

Function Install-Git {
	Write-BoxstarterMessage "####################################"
	Write-BoxstarterMessage "# Git"
	Write-BoxstarterMessage "####################################"

	#git.install?
	choco install git --params="/GitOnlyOnPath /WindowsTerminal" --limitoutput
	choco install git-credential-manager-for-windows --limitoutput
	choco install poshgit --limitoutput
	choco install sourcetree --limitoutput

	choco pin add -n=sourcetree
}

Function Install-VisualStudio2019 {
	Write-BoxstarterMessage "####################################"
	Write-BoxstarterMessage "# Visual Studio 2019"
	Write-BoxstarterMessage "####################################"

	$path = "$($env:Temp)\$([guid]::NewGuid())"
	$archive = "$($path)\master.zip"

	Invoke-WebRequest https://github.com/vladislavvsh/box-setup-scripts/archive/master.zip -UseBasicParsing -OutFile $archive
	Expand-Archive -Path $archive -DestinationPath $path

	Move-Item (Join-Path $path 'box-setup-scripts-master\*') $path
	Remove-Item -Path (Join-Path $path 'box-setup-scripts-master')

	choco install visualstudio2019enterprise --params="--locale en-US --passive --norestart --wait --config $($path)\configs\.vsconfig"
	choco pin add -n=visualstudio2019enterprise

	Remove-Item -Path $archive
	Remove-Item -Path $path
}

Function Install-VisualStudio2019Extensions {
	Write-BoxstarterMessage "####################################"
	Write-BoxstarterMessage "# Visual Studio 2019 Extensions"
	Write-BoxstarterMessage "####################################"

	choco install resharper-platform --limitoutput

	choco pin add -n=resharper-platform

	Vs2019DownloadAndInstallExt("MadsKristensen.AddNewFile")
	Vs2019DownloadAndInstallExt("MadsKristensen.TrailingWhitespaceVisualizer")
	Vs2019DownloadAndInstallExt("MadsKristensen.WebPackTaskRunner")
	Vs2019DownloadAndInstallExt("MadsKristensen.NPMTaskRunner")
	Vs2019DownloadAndInstallExt("MadsKristensen.PackageInstaller")
	Vs2019DownloadAndInstallExt("MadsKristensen.YarnInstaller")
	Vs2019DownloadAndInstallExt("MadsKristensen.DummyTextGenerator")
	Vs2019DownloadAndInstallExt("MadsKristensen.MarkdownEditor")
	Vs2019DownloadAndInstallExt("MadsKristensen.ShowSelectionLength")

	Vs2019DownloadAndInstallExt("VisualStudioPlatformTeam.PowerCommandsforVisualStudio")
	Vs2019DownloadAndInstallExt("VisualStudioPlatformTeam.ProductivityPowerPack2017")
	Vs2019DownloadAndInstallExt("VisualStudioPlatformTeam.VisualStudio2019ColorThemeEditor")
	Vs2019DownloadAndInstallExt("EWoodruff.VisualStudioSpellCheckerVS2017andLater")
	Vs2019DownloadAndInstallExt("TomasRestrepo.Viasfora")
	Vs2019DownloadAndInstallExt("josefpihrt.Roslynator2019")
	Vs2019DownloadAndInstallExt("SonarSource.SonarLintforVisualStudio2019")
	Vs2019DownloadAndInstallExt("TomEnglert.ResXManager")
	Vs2019DownloadAndInstallExt("SergeyVlasov.VisualCommander")
	Vs2019DownloadAndInstallExt("PavelSamokha.TargetFrameworkMigrator")
	Vs2019DownloadAndInstallExt("NikolayBalakin.Outputenhancer")
}

Function Install-VisualStudioCode  {
	Write-BoxstarterMessage "####################################"
	Write-BoxstarterMessage "# Visual Studio Code"
	Write-BoxstarterMessage "####################################"

	#vscode.install?
	choco install vscode --params="/NoDesktopIcon" --limitoutput

	choco pin add -n=vscode

	Update-Path
}

Function Install-VSCodeExtensions {
	Write-BoxstarterMessage "####################################"
	Write-BoxstarterMessage "# Visual Studio Code Extensions"
	Write-BoxstarterMessage "####################################"

    # need to launch vscode so user folders are created as we can install extensions
	$process = Start-Process code -PassThru
	Start-Sleep -s 10
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
}

Function Install-AzureTools {
	Write-BoxstarterMessage "####################################"
	Write-BoxstarterMessage "# Azure Tools"
	Write-BoxstarterMessage "####################################"

	Install-Module -Name AzureRM -Scope AllUsers
	Install-Module -Name Azure -Scope AllUsers -AllowClobber
	choco install azure-cli --limitoutput
	choco install microsoftazurestorageexplorer --limitoutput

	choco pin add -n=microsoftazurestorageexplorer
}

Function Install-CoreDevApps {
	Write-BoxstarterMessage "####################################"
	Write-BoxstarterMessage "# Core Dev Apps"
	Write-BoxstarterMessage "####################################"

	choco install fiddler --limitoutput
	choco install beyondcompare --limitoutput
	choco install beyondcompare-integration --limitoutput
	choco install sql-server-management-studio --limitoutput
	choco install sysinternals --limitoutput

	choco install putty.install --limitoutput
	choco install winscp.install --limitoutput
	choco install curl --limitoutput
	choco install wget --limitoutput
	choco install postman --limitoutput
	choco install openvpn --params "/SELECT_LAUNCH=0" --limitoutput

	choco pin add -n=fiddler
	choco pin add -n=beyondcompare
	choco pin add -n=sql-server-management-studio
}

function Install-NodeJsAndNpmPackages {
	Write-BoxstarterMessage "####################################"
	Write-BoxstarterMessage "# NodeJs and Npm Packages"
	Write-BoxstarterMessage "####################################"

	choco install nodejs-lts --limitoutput
    npm install -g typescript
    npm install -g yarn
}

Function Install-CoreApps {
	Write-BoxstarterMessage "####################################"
	Write-BoxstarterMessage "# Core Apps"
	Write-BoxstarterMessage "####################################"

	choco install chocolateygui --limitoutput
	choco install microsoft-windows-terminal --limitoutput
	choco install 7zip.install --limitoutput
	choco install vlc --limitoutput
	choco install paint.net --limitoutput
	choco install adobereader --limitoutput
	choco install dropbox --limitoutput
	choco install sharex --limitoutput
	choco install ffmpeg --limitoutput
	choco install rufus --limitoutput
	choco install notepadplusplus.install --limitoutput
	choco install caffeine --limitoutput

	choco pin add -n=vlc
	choco pin add -n="paint.net"
	choco pin add -n=dropbox
	choco pin add -n=sharex
	choco pin add -n="notepadplusplus.install"
}

Function Install-Browsers {
	Write-BoxstarterMessage "####################################"
	Write-BoxstarterMessage "# Browsers"
	Write-BoxstarterMessage "####################################"

	choco install firefox --limitoutput
	choco install tor-browser --limitoutput

	choco pin add -n=firefox
	choco pin add -n=tor-browser
}

Function Install-Messengers {
	Write-BoxstarterMessage "####################################"
	Write-BoxstarterMessage "# Messengers"
	Write-BoxstarterMessage "####################################"

	choco install skype --limitoutput
	choco install slack --limitoutput
	choco install telegram.install --limitoutput
	choco install whatsapp --limitoutput

	choco pin add -n=skype
	choco pin add -n="telegram.install"
}

Function Install-KeePass {
	Write-BoxstarterMessage "####################################"
	Write-BoxstarterMessage "# KeePass"
	Write-BoxstarterMessage "####################################"

	choco install keepass.install --limitoutput
	choco install keepass-plugin-keeagent --limitoutput
	choco install keepass-plugin-keeanywhere --limitoutput
	choco install keepass-keepasshttp --limitoutput
	choco install keepass-plugin-rdp --limitoutput
	choco install keepass-rpc --limitoutput
	choco install keepass-plugin-enhancedentryview --limitoutput
}

Write-BoxstarterMessage "Starting setup"
WindowsUpdate

# disable chocolatey default confirmation behaviour (no need for --yes)
Use-Checkpoint -Function ${Function:Enable-ChocolateyFeatures} -CheckpointName 'InitChoco' -SkipMessage 'Chocolatey features already configured'

Use-Checkpoint -Function ${Function:Set-BaseSettings} -CheckpointName 'BaseSettings' -SkipMessage 'Base settings are already configured'

Use-Checkpoint -Function ${Function:SetUp-PowerShell} -CheckpointName 'SetUp-PowerShell' -SkipMessage 'PowerShell is already configured'

Write-BoxstarterMessage "Starting installs"

Use-Checkpoint -Function ${Function:Install-DevFeatures} -CheckpointName 'DevFeatures' -SkipMessage 'Dev Features are already installed'

if (Test-PendingReboot) { Invoke-Reboot }

Use-Checkpoint -Function ${Function:Install-Docker} -CheckpointName 'Docker' -SkipMessage 'Docker is already installed'

if (Test-PendingReboot) { Invoke-Reboot }

Use-Checkpoint -Function ${Function:Install-Git} -CheckpointName 'Git' -SkipMessage 'Git is already installed'

Use-Checkpoint -Function ${Function:Install-VisualStudio2019} -CheckpointName 'VisualStudio2019' -SkipMessage 'Visual Studio 2019 is already installed'

if (Test-PendingReboot) { Invoke-Reboot }

Use-Checkpoint -Function ${Function:Install-VisualStudio2019Extensions} -CheckpointName 'VisualStudio2019Extensions' -SkipMessage 'Visual Studio 2019 Extensions are already installed'

Use-Checkpoint -Function ${Function:Install-VisualStudioCode} -CheckpointName 'VisualStudioCode' -SkipMessage 'Visual Studio Code is already installed'

Use-Checkpoint -Function ${Function:Install-VSCodeExtensions} -CheckpointName 'VSCodeExtensions' -SkipMessage 'Visual Studio Code Extensions are already installed'

Use-Checkpoint -Function ${Function:Install-AzureTools} -CheckpointName 'AzureTools' -SkipMessage 'Azure Tools are already installed'

Use-Checkpoint -Function ${Function:Install-CoreDevApps} -CheckpointName 'CoreDevApps' -SkipMessage 'Core Dev Apps are already installed'

if (Test-PendingReboot) { Invoke-Reboot }

Use-Checkpoint -Function ${Function:Install-NodeJsAndNpmPackages} -CheckpointName 'NodeJsAndNpmPackages' -SkipMessage 'NodeJs And Npm Packages are already installed'

Use-Checkpoint -Function ${Function:Install-CoreApps} -CheckpointName 'CoreApps' -SkipMessage 'Core Apps are already installed'

if (Test-PendingReboot) { Invoke-Reboot }

Use-Checkpoint -Function ${Function:Install-Browsers} -CheckpointName 'Browsers' -SkipMessage 'Browsers are already installed'

Use-Checkpoint -Function ${Function:Install-Messengers} -CheckpointName 'Messengers' -SkipMessage 'Messengers are already installed'

Use-Checkpoint -Function ${Function:Install-KeePass} -CheckpointName 'KeePass' -SkipMessage 'KeePass is already installed'

# install chocolatey as last choco package
choco install chocolatey --limitoutput

# re-enable chocolatey default confirmation behaviour
Use-Checkpoint -Function ${Function:Disable-ChocolateyFeatures} -CheckpointName 'DisableChocolatey' -SkipMessage 'Chocolatey features already configured'

if (Test-PendingReboot) { Invoke-Reboot }

# reload path environment variable
Update-Path

# set HOME to user profile for git
[Environment]::SetEnvironmentVariable("HOME", $env:UserProfile, "User")

# rerun windows update after we have installed everything
Write-BoxstarterMessage "Windows update..."
WindowsUpdate

Clear-Checkpoints

Write-BoxstarterMessage "Finished"
