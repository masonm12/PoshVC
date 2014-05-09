Set-StrictMode -version Latest

$yearVersionMap = @{
    '2013' = '12.0';
    '2012' = '11.0';
    '2010' = '10.0';
    '2008' = '9.0';
}

# returns registry root (wow6432node, etc)
function getSoftwareRegRoot($hkey) {
    $regRoot = 'HKLM:\SOFTWARE\Wow6432Node'
    # if an pointer is 4 bytes, then we're 32-bit!
    if ([IntPtr]::size -eq 4) {
        $regRoot = 'HKLM:\SOFTWARE'
    }

    $regRoot
}

# tests if a property exists on an object
function doesPropertyExist($object, $property) {
    $object.PSObject.Properties.Match($property).Count -ne 0
}

# takes a version (e.g. 12.0, 2013, etc)
# returns VC install path (e.g. C:\Program Files (x86)\Microsoft Visual Studio 12.0\VC\)
function getVCInstallPath($version) {
    $vsRoot = Join-Path $(getSoftwareRegRoot) 'Microsoft\VisualStudio\SxS\VC7'
    # be sure registry entry exists at all
    if (Test-Path $vsRoot) {
        $vsProp = Get-ItemProperty $vsRoot
        if (doesPropertyExist $vsProp $version) {
            $vsProp.$version
        }
        elseif ($yearVersionMap[$version]) {
            $version = $yearVersionMap[$version]
            if (doesPropertyExist $vsProp $version) {
                $vsProp.$version
            }
        }
    }
}

# prints a sorted array of visual c version numbers
function printInstalledVCVersions() {
    $versions = $yearVersionMap.GetEnumerator() | sort @{e={$_.Value -as [Decimal]}; descending=$true} |
        ? {getVCInstallPath $_.Value}
    "Detected Visual Studio Installs:`n"
    $versions | % {"`tVisual Studio " + $_.Key + ' (' + $_.Value + ')'}
}

# returns the highest version of vc installed
function getNewestVCInstallPath() {
    $yearVersionMap.GetEnumerator() | sort @{e={$_.Value -as [Decimal]}; descending=$true} |
        % {getVCInstallPath $_.Value} | ? {$_} | select -first 1
}

# executes a batch file, and captures the environment variable settings
function execBatchFile($file, $args = '') {
    $cmd = "`"$file`" $args & set"
    cmd /c $cmd | % {$prop, $val = $_.split('='); Set-Item -path env:$prop -value $val}
}

$vcPath = getVCInstallPath '2013'
$batPath = Join-Path $vcPath 'vcvarsall.bat'
$arch = $env:PROCESSOR_ARCHITECTURE
execBatchFile $batPath $arch
getNewestVCInstallPath
