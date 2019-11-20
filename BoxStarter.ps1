###############################################################################
# https://gist.github.com/ghostinthewires/033276015ba9d58d1f162e7fd47cdbd3
# https://gist.github.com/KZeronimo/3dd360bece3341a322335469a0a813ea
# https://github.com/JonCubed/boxstarter.git
#
# Description: Boxstarter Script
#
# Install boxstarter:
#	. { iwr -useb https://boxstarter.org/bootstrapper.ps1 } | iex; Get-Boxstarter -Force
# NOTE the "." above is required.
#
# Run this boxstarter by calling the following from **elevated** powershell:
#   example: Install-BoxstarterPackage -PackageName https://raw.githubusercontent.com/vladislavvsh/box-setup-scripts/master/BoxStarter.ps1 -DisableReboots
###############################################################################

# Workaround for nested chocolatey folders resulting in path too long error

$ChocoCachePath = "C:\Temp"
New-Item -Path $ChocoCachePath -ItemType directory -Force

# Temporary

Disable-UAC
choco feature enable -n=allowGlobalConfirmation

###############################################################################
# Windows Subsystems/Roles/Features
###############################################################################

choco install Microsoft-Windows-Subsystem-Linux -source windowsFeatures
choco install Microsoft-Hyper-V-All -source windowsFeatures
choco install Containers -source windowsFeatures
choco install TelnetClient -source windowsFeatures

###############################################################################
# Docker
###############################################################################

choco install docker-desktop --cacheLocation $ChocoCachePath
choco install docker-compose --cacheLocation $ChocoCachePath

choco pin add -n=docker-for-windows
choco pin add -n=docker-compose

###############################################################################
# PowerShell
###############################################################################

Get-PackageProvider -Name NuGet -ForceBootstrap
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
Install-Module -Name AzureRM -Scope AllUsers
Install-Module -Name Azure -Scope AllUsers -AllowClobber

###############################################################################
# Git
###############################################################################

choco install git.install --params="'/GitOnlyOnPath /WindowsTerminal'" --cacheLocation $ChocoCachePath
choco install git-credential-manager-for-windows  --cacheLocation $ChocoCachePath
choco install poshgit --cacheLocation $ChocoCachePath
choco install sourcetree --cacheLocation $ChocoCachePath

choco pin add -n=sourcetree

###############################################################################
# Browsers
###############################################################################

choco install firefox --cacheLocation $ChocoCachePath
choco install tor-browser --cacheLocation $ChocoCachePath

choco pin add -n=firefox
choco pin add -n=tor-browser

###############################################################################
# KeePass
###############################################################################

choco install keepass.install --cacheLocation $ChocoCachePath
choco install keepass-plugin-keeagent --cacheLocation $ChocoCachePath
choco install keepass-plugin-keeanywhere --cacheLocation $ChocoCachePath
choco install keepass-keepasshttp --cacheLocation $ChocoCachePath
choco install keepass-plugin-rdp --cacheLocation $ChocoCachePath
choco install keepass-rpc --cacheLocation $ChocoCachePath
choco install keepass-plugin-enhancedentryview --cacheLocation $ChocoCachePath

###############################################################################
# Messengers
###############################################################################

choco install skype --cacheLocation $ChocoCachePath
choco install slack --cacheLocation $ChocoCachePath
choco install telegram.install --cacheLocation $ChocoCachePath
choco install whatsapp --cacheLocation $ChocoCachePath

choco pin add -n=skype
choco pin add -n=telegram.install

###############################################################################
# Azure
###############################################################################

choco install azure-cli --cacheLocation $ChocoCachePath
choco install azcopy --cacheLocation $ChocoCachePath
choco install microsoftazurestorageexplorer --cacheLocation $ChocoCachePath

choco pin add -n=microsoftazurestorageexplorer

###############################################################################
# Apps
###############################################################################

choco install chocolatey --cacheLocation $ChocoCachePath
choco install chocolateygui --cacheLocation $ChocoCachePath
choco install 7zip.install --cacheLocation $ChocoCachePath
choco install notepadplusplus.install --cacheLocation $ChocoCachePath
choco install vlc --cacheLocation $ChocoCachePath
choco install paint.net --cacheLocation $ChocoCachePath
choco install adobereader --cacheLocation $ChocoCachePath
choco install dropbox --cacheLocation $ChocoCachePath
choco install caffeine --cacheLocation $ChocoCachePath

choco install sharex --cacheLocation $ChocoCachePath
choco install ffmpeg --cacheLocation $ChocoCachePath
choco install rufus --cacheLocation $ChocoCachePath

choco install nodejs-lts --cacheLocation $ChocoCachePath
choco install yarn --cacheLocation $ChocoCachePath

choco install microsoft-windows-terminal --cacheLocation $ChocoCachePath
choco install fiddler --cacheLocation $ChocoCachePath
choco install beyondcompare --cacheLocation $ChocoCachePath
choco install sql-server-management-studio --cacheLocation $ChocoCachePath
choco install sysinternals --cacheLocation $ChocoCachePath

choco install putty.install --cacheLocation $ChocoCachePath
choco install winscp.install --cacheLocation $ChocoCachePath
choco install curl --cacheLocation $ChocoCachePath
choco install wget --cacheLocation $ChocoCachePath
choco install postman --cacheLocation $ChocoCachePath
choco install openvpn --params "'/SELECT_LAUNCH=0'" --cacheLocation $ChocoCachePath

choco pin add -n=notepadplusplus.install
choco pin add -n=vlc
choco pin add -n=paint.net
choco pin add -n=fiddler
choco pin add -n=beyondcompare
choco pin add -n=sql-server-management-studio

###############################################################################
# Visual Studio Code
###############################################################################

choco install vscode.install --params="'/NoDesktopIcon'" --cacheLocation $ChocoCachePath

choco pin add -n=vscode.install

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

###############################################################################
# Visual Studio 2019
###############################################################################

# Get configs

$path = "c:\_scripts"
if (Test-Path -Path $path) {
    Remove-Item -Path $path -Recurse
}
Invoke-WebRequest  https://github.com/vladislavvsh/box-setup-scripts/archive/master.zip -UseBasicParsing -OutFile C:\master.zip
Expand-Archive -Path C:\master.zip -DestinationPath $path
Move-Item (Join-Path $path 'box-setup-scripts-master\*') $path
Remove-Item -Path (Join-Path $path 'box-setup-scripts-master')
Remove-Item -Path C:\master.zip

Function DownloadAndInstallExt($packageName) {
	$ErrorActionPreference = "Stop"
    $vsixInstaller = "C:\Program Files (x86)\Microsoft Visual Studio\2019\Enterprise\Common7\IDE\VSIXInstaller"
	$vsixLocation = "$($env:Temp)\$([guid]::NewGuid()).vsix"
	$baseProtocol = "https:"
	$baseHostName = "marketplace.visualstudio.com"
	$uri = "$($baseProtocol)//$($baseHostName)/items?itemName=$($packageName)"

	Write-Host "Grabbing VSIX extension page at $($uri)"
    $content = Invoke-WebRequest -Uri $uri -UseBasicParsing
    $parsedHtml = New-Object -Com "HTMLFile"
    $parsedHTML.IHTMLDocument2_write($content.RawContent)

	Write-Host "Attempting to find package download url..."
	$anchors = $parsedHtml.getElementsByTagName("a") | Where-Object {$_.getAttributeNode("class").Value -eq "install-button-container"}
	if (-Not $anchors) {
		Write-Error "Could not find download anchor tag on the Visual Studio Extensions page."
		Exit 1
	}

	$anchor = @($anchors)[0]
	$anchor.protocol = $baseProtocol
	$anchor.hostname = $baseHostName

    Write-Host "Found $($anchor.href). Downloading..."
	Invoke-WebRequest $anchor.href -OutFile $vsixLocation

	if (-Not (Test-Path $vsixLocation)) {
		Write-Error "Downloaded VSIX file could not be located."
		Exit 1
	}

    Write-Host "Done."
	Write-Host "Installing $($packageName)..."
	Start-Process -Filepath $vsixInstaller -ArgumentList "/q /a $($vsixLocation)" -Wait

    Write-Host "Done."
	Write-Host "Cleanup..."
	Remove-Item $vsixLocation
	Write-Host "Installation of $($packageName) complete!"
}

choco install visualstudio2019enterprise --params="'--locale en-US --lang en-US --passive --norestart --wait --config $($path)\configs\.vsconfig'"

choco install resharper-platform --cacheLocation $ChocoCachePath

choco pin add -n=resharper-platform

DownloadAndInstallExt("MadsKristensen.AddNewFile")
DownloadAndInstallExt("MadsKristensen.TrailingWhitespaceVisualizer")
DownloadAndInstallExt("MadsKristensen.WebPackTaskRunner")
DownloadAndInstallExt("MadsKristensen.NPMTaskRunner")
DownloadAndInstallExt("MadsKristensen.PackageInstaller")
DownloadAndInstallExt("MadsKristensen.YarnInstaller")
DownloadAndInstallExt("MadsKristensen.DummyTextGenerator")
DownloadAndInstallExt("MadsKristensen.MarkdownEditor")
DownloadAndInstallExt("MadsKristensen.ShowSelectionLength")

DownloadAndInstallExt("VisualStudioPlatformTeam.PowerCommandsforVisualStudio")
DownloadAndInstallExt("VisualStudioPlatformTeam.ProductivityPowerPack2017")
DownloadAndInstallExt("VisualStudioPlatformTeam.VisualStudio2019ColorThemeEditor")
DownloadAndInstallExt("EWoodruff.VisualStudioSpellCheckerVS2017andLater")
DownloadAndInstallExt("TomasRestrepo.Viasfora")
DownloadAndInstallExt("josefpihrt.Roslynator2019")
DownloadAndInstallExt("SonarSource.SonarLintforVisualStudio2019")
DownloadAndInstallExt("TomEnglert.ResXManager")
DownloadAndInstallExt("SergeyVlasov.VisualCommander")
DownloadAndInstallExt("PavelSamokha.TargetFrameworkMigrator")
DownloadAndInstallExt("NikolayBalakin.Outputenhancer")

###############################################################################
# Clean up
###############################################################################

# Clean up the cache directory

Remove-Item $ChocoCachePath -Recurse

# Restore Temporary Settings

choco feature disable -n=allowGlobalConfirmation
Enable-MicrosoftUpdate
Install-WindowsUpdate -acceptEula
Enable-UAC
