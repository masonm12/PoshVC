Set-StrictMode -version Latest

$psvcVersion = '1.0.0'
$commandHelp = @{
    'version' = 'Print the version number.';
    'help' = 'Print this help message.';
    'list' = 'Print all detected versions of Visual C.';
    'use' = 'Import vcvarsall for a given version of Visual C (e.g. 2013, 10.0, etc).';
}
$psvcUsage = "usage psvc [--version] [--help] command args
    
optional arguments:
    --version $($commandHelp['version'])
    --help    $($commandHelp['help'])

commands:
    list      $($commandHelp['list'])
    use       $($commandHelp['use'])
"
$listUsage = "usage psvc list [--help]
$($commandHelp['list'])

optional arguments:
    --help $($commandHelp['help'])
"
$useUsage = "usage psvc use [version] [architecture]
$($commandHelp['use'])

optional arguments:
    --help $($commandHelp['help'])

arguments:
    version      Version of Visual C vcvarsall to try and import.
                 (default: latest)
    architecture Tools architecture to load, passed to vcvarsall.
                 (default: $env:PROCESSOR_ARCHITECTURE)
"
$yearVersionMap = @{
    '2013' = '12.0';
    '2012' = '11.0';
    '2010' = '10.0';
    '2008' = '9.0';
}

# returns registry root (wow6432node, etc)
function getSoftwareRegRoot() {
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
    $versions | % {"`    Visual Studio " + $_.Key + ' (' + $_.Value + ')'}
}

# returns the highest version of vc installed
function getNewestVCInstallPath() {
    $yearVersionMap.GetEnumerator() | sort @{e={$_.Value -as [Decimal]}; descending=$true} |
        ? {getVCInstallPath $_.Value} | % {$_.Value} | select -first 1
}

# executes a batch file, and captures the environment variable settings
function execBatchFile($file, $arguments = '') {
    try {
        $ErrorActionPreference = "Stop" # Make all errors terminating
        $cmd = "`"$file`" $arguments & set"
        cmd /c $cmd | % {$prop, $val = $_.split('='); Set-Item -path env:$prop -value $val}
    }
    # see if the command with not set gives useful info
    catch {
        $host.ui.WriteErrorLine("Error calling $file $arguments")
        $cmd = "`"$file`" $arguments"
        cmd /c $cmd
    }
    finally {
        $ErrorActionPreference = "Continue" # restore default
    }
}

# writes out a message, and exits
function errorOut($message) {
    $host.ui.WriteErrorLine($message)
    exit 1
}

function invalidArguments($arguments = $args) {
    errorOut "Invalid arguments $arguments"
}

# will attempt to use the given VC version
function useVCVersion($version, $architecture) {
    if ($version -eq 'latest') {
        $version = getNewestVCInstallPath
        if (!$version) {
            errorOut 'No version of Visual C was found.'
        }
    }

    $vcPath = getVCInstallPath $version
    if (!$vcPath) {
        errorOut "Visual C version $version not found."
    }

    $batPath = Join-Path $vcPath 'vcvarsall.bat'
    execBatchFile $batPath $architecture
}

# checks if a value exists in an array list
# then removes it
function checkAndPop($arrayList, $value) {
    if ($arrayList -contains $value) {
        $arrayList.remove($value)
        $true
    }
}

# time to parse some args!
$commands = New-Object System.Collections.ArrayList
$commands.addRange($args)
$version = $(checkAndPop $commands '--version') -or $(checkAndPop $commands 'version')
$help = $(checkAndPop $commands '--help') -or $(checkAndPop $commands 'help')

if ($version) {
    if ($help -or $commands) {
        invalidArguments
    }

    "psvc version $psvcVersion"
    exit 0
}

if (!$commands) {
    $psvcUsage
    exit 0
}

if ($commands[0] -eq 'list') {
    $commands.removeAt(0)
    if ($help) {
        $listUsage
    }
    elseif ($commands) {
        invalidArguments $commands
    }
    else {
        printInstalledVCVersions
    }
    exit 0
}

if ($commands[0] -eq 'use') {
    $commands.removeAt(0)
    if ($help) {
        $useUsage
        exit 0
    }
    
    $vcVersion = 'latest'
    $architecture = $env:PROCESSOR_ARCHITECTURE
    if ($commands) {
        $vcVersion = $commands[0]
        $commands.removeAt(0)
    }
    if ($commands) {
        $architecture = $commands[0]
        $commands.removeAt(0)
    }
    useVCVersion $vcVersion $architecture
    exit 0
}
