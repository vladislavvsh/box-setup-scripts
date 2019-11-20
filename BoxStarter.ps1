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

Function ConvertTo-NormalHTML {
    param([Parameter(Mandatory = $true, ValueFromPipeline = $true)]$HTML)

    $NormalHTML = New-Object -Com "HTMLFile"
    $NormalHTML.IHTMLDocument2_write($HTML.RawContent)
    return $NormalHTML
}

Function VsDownloadAndInstallExt($packageName) {
	$ErrorActionPreference = "Stop"
    $vsixInstaller = "C:\Program Files (x86)\Microsoft Visual Studio\2019\Enterprise\Common7\IDE\VSIXInstaller"
	$vsixLocation = "$($env:Temp)\$([guid]::NewGuid()).vsix"
	$baseProtocol = "https:"
	$baseHostName = "marketplace.visualstudio.com"
	$uri = "$($baseProtocol)//$($baseHostName)/items?itemName=$($packageName)"

	Write-Host "Grabbing VSIX extension page at $($uri)"
    $content = Invoke-WebRequest -Uri $uri -UseBasicParsing
    $parsedHtml = ConvertTo-NormalHTML -HTML $content

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

Write-Host "####################################" -ForegroundColor Yellow
Write-Host "# Started" -ForegroundColor Yellow
Write-Host "####################################" -ForegroundColor Yellow

# Workaround for nested chocolatey folders resulting in path too long error

$ChocoCachePath = "C:\Temp"
New-Item -Path $ChocoCachePath -ItemType directory -Force

# Temporary

Disable-UAC
choco feature enable -n=allowGlobalConfirmation

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

Write-Host "####################################" -ForegroundColor Yellow
Write-Host "# Windows Subsystems/Roles/Features" -ForegroundColor Yellow
Write-Host "####################################" -ForegroundColor Yellow

choco install Microsoft-Windows-Subsystem-Linux -source windowsFeatures --cacheLocation $ChocoCachePath
choco install wsl-ubuntu-1804 --cacheLocation $ChocoCachePath
choco install Microsoft-Hyper-V-All -source windowsFeatures --cacheLocation $ChocoCachePath
choco install Containers -source windowsFeatures --cacheLocation $ChocoCachePath
choco install TelnetClient -source windowsFeatures --cacheLocation $ChocoCachePath

RefreshEnv

Write-Host "####################################" -ForegroundColor Yellow
Write-Host "# Docker" -ForegroundColor Yellow
Write-Host "####################################" -ForegroundColor Yellow

choco install docker-desktop --cacheLocation $ChocoCachePath
choco install docker-compose --cacheLocation $ChocoCachePath

RefreshEnv

choco pin add -n="docker-desktop"
choco pin add -n="docker-compose"

Write-Host "####################################" -ForegroundColor Yellow
Write-Host "# PowerShell" -ForegroundColor Yellow
Write-Host "####################################" -ForegroundColor Yellow

Get-PackageProvider -Name NuGet -ForceBootstrap
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
Install-Module -Name AzureRM -Scope AllUsers
Install-Module -Name Azure -Scope AllUsers -AllowClobber

RefreshEnv

Write-Host "####################################" -ForegroundColor Yellow
Write-Host "# Git" -ForegroundColor Yellow
Write-Host "####################################" -ForegroundColor Yellow

choco install git.install --params="/GitOnlyOnPath /WindowsTerminal" --cacheLocation $ChocoCachePath

RefreshEnv

choco install git-credential-manager-for-windows  --cacheLocation $ChocoCachePath
choco install poshgit --cacheLocation $ChocoCachePath
choco install sourcetree --cacheLocation $ChocoCachePath

RefreshEnv

choco pin add -n="sourcetree"

Write-Host "####################################" -ForegroundColor Yellow
Write-Host "# Visual Studio 2019" -ForegroundColor Yellow
Write-Host "####################################" -ForegroundColor Yellow

choco install visualstudio2019enterprise --params="--locale en-US --passive --norestart --wait --config $($path)\configs\.vsconfig"

RefreshEnv

choco install resharper-platform --cacheLocation $ChocoCachePath

RefreshEnv

choco pin add -n="resharper-platform"

VsDownloadAndInstallExt("MadsKristensen.AddNewFile")
VsDownloadAndInstallExt("MadsKristensen.TrailingWhitespaceVisualizer")
VsDownloadAndInstallExt("MadsKristensen.WebPackTaskRunner")
VsDownloadAndInstallExt("MadsKristensen.NPMTaskRunner")
VsDownloadAndInstallExt("MadsKristensen.PackageInstaller")
VsDownloadAndInstallExt("MadsKristensen.YarnInstaller")
VsDownloadAndInstallExt("MadsKristensen.DummyTextGenerator")
VsDownloadAndInstallExt("MadsKristensen.MarkdownEditor")
VsDownloadAndInstallExt("MadsKristensen.ShowSelectionLength")

VsDownloadAndInstallExt("VisualStudioPlatformTeam.PowerCommandsforVisualStudio")
VsDownloadAndInstallExt("VisualStudioPlatformTeam.ProductivityPowerPack2017")
VsDownloadAndInstallExt("VisualStudioPlatformTeam.VisualStudio2019ColorThemeEditor")
VsDownloadAndInstallExt("EWoodruff.VisualStudioSpellCheckerVS2017andLater")
VsDownloadAndInstallExt("TomasRestrepo.Viasfora")
VsDownloadAndInstallExt("josefpihrt.Roslynator2019")
VsDownloadAndInstallExt("SonarSource.SonarLintforVisualStudio2019")
VsDownloadAndInstallExt("TomEnglert.ResXManager")
VsDownloadAndInstallExt("SergeyVlasov.VisualCommander")
VsDownloadAndInstallExt("PavelSamokha.TargetFrameworkMigrator")
VsDownloadAndInstallExt("NikolayBalakin.Outputenhancer")

RefreshEnv

Write-Host "####################################" -ForegroundColor Yellow
Write-Host "# Visual Studio Code" -ForegroundColor Yellow
Write-Host "####################################" -ForegroundColor Yellow

choco install vscode.install --params="/NoDesktopIcon" --cacheLocation $ChocoCachePath

RefreshEnv

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

choco pin add -n="vscode.install"

Write-Host "####################################" -ForegroundColor Yellow
Write-Host "# Azure" -ForegroundColor Yellow
Write-Host "####################################" -ForegroundColor Yellow

choco install azure-cli --cacheLocation $ChocoCachePath
choco install azcopy --cacheLocation $ChocoCachePath
choco install microsoftazurestorageexplorer --cacheLocation $ChocoCachePath

RefreshEnv

choco pin add -n="microsoftazurestorageexplorer"

Write-Host "####################################" -ForegroundColor Yellow
Write-Host "# Apps" -ForegroundColor Yellow
Write-Host "####################################" -ForegroundColor Yellow

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
choco install beyondcompare-integration --cacheLocation $ChocoCachePath
choco install sql-server-management-studio --cacheLocation $ChocoCachePath
choco install sysinternals --cacheLocation $ChocoCachePath

choco install putty.install --cacheLocation $ChocoCachePath
choco install winscp.install --cacheLocation $ChocoCachePath
choco install curl --cacheLocation $ChocoCachePath
choco install wget --cacheLocation $ChocoCachePath
choco install postman --cacheLocation $ChocoCachePath
choco install openvpn --params "/SELECT_LAUNCH=0" --cacheLocation $ChocoCachePath

RefreshEnv

choco pin add -n="notepadplusplus.install"
choco pin add -n="vlc"
choco pin add -n="paint.net"
choco pin add -n="fiddler"
choco pin add -n="beyondcompare"
choco pin add -n="sql-server-management-studio"

Write-Host "####################################" -ForegroundColor Yellow
Write-Host "# Messengers" -ForegroundColor Yellow
Write-Host "####################################" -ForegroundColor Yellow

choco install skype --cacheLocation $ChocoCachePath
choco install slack --cacheLocation $ChocoCachePath
choco install telegram.install --cacheLocation $ChocoCachePath
choco install whatsapp --cacheLocation $ChocoCachePath

RefreshEnv

choco pin add -n="skype"
choco pin add -n="telegram.install"

Write-Host "####################################" -ForegroundColor Yellow
Write-Host "# Browsers" -ForegroundColor Yellow
Write-Host "####################################" -ForegroundColor Yellow

choco install firefox --cacheLocation $ChocoCachePath
choco install tor-browser --cacheLocation $ChocoCachePath

RefreshEnv

choco pin add -n="firefox"
choco pin add -n="tor-browser"

Write-Host "####################################" -ForegroundColor Yellow
Write-Host "# KeePass" -ForegroundColor Yellow
Write-Host "####################################" -ForegroundColor Yellow

choco install keepass.install --cacheLocation $ChocoCachePath

RefreshEnv

choco install keepass-plugin-keeagent --cacheLocation $ChocoCachePath
choco install keepass-plugin-keeanywhere --cacheLocation $ChocoCachePath
choco install keepass-keepasshttp --cacheLocation $ChocoCachePath
choco install keepass-plugin-rdp --cacheLocation $ChocoCachePath
choco install keepass-rpc --cacheLocation $ChocoCachePath
choco install keepass-plugin-enhancedentryview --cacheLocation $ChocoCachePath

RefreshEnv

Write-Host "####################################" -ForegroundColor Yellow
Write-Host "# Clean up" -ForegroundColor Yellow
Write-Host "####################################" -ForegroundColor Yellow

# Clean up the cache directory

Remove-Item $ChocoCachePath -Recurse

# Restore Temporary Settings

choco feature disable -n=allowGlobalConfirmation
Enable-MicrosoftUpdate
Install-WindowsUpdate -acceptEula
Enable-UAC

Write-Host "####################################" -ForegroundColor Yellow
Write-Host "# Finished" -ForegroundColor Yellow
Write-Host "####################################" -ForegroundColor Yellow
