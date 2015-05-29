Set-StrictMode -version Latest

$psvsName = 'poshvs'
$psvsVersion = '1.1.1'
$commandHelp = @{
    'version' = 'Print the version number.';
    'help' = 'Print this help message.';
    'list' = 'Print all detected versions of Visual Studio.';
    'use' = 'Import vcvarsall for a given version of Visual Studio (e.g. 2013, 10.0, etc).';
}
$psvsUsage = "usage $psvsName [--version] [--help] command args
    
optional arguments:
    --version $($commandHelp['version'])
    --help    $($commandHelp['help'])

commands:
    list      $($commandHelp['list'])
    use       $($commandHelp['use'])
"
$listUsage = "usage $psvsName list [--help]
$($commandHelp['list'])

optional arguments:
    --help $($commandHelp['help'])
"
$useUsage = "usage $psvsName use [version] [architecture]
$($commandHelp['use'])

optional arguments:
    --help $($commandHelp['help'])

arguments:
    version      Version of Visual Studio vcvarsall to try and import.
                 (default: latest)
    architecture Tools architecture to load, passed to vcvarsall.
                 (default: $env:PROCESSOR_ARCHITECTURE)
"
$yearVersionMap = @{
    '2015' = '14.0';
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
# returns VC directory in Visual Studio install path (e.g. C:\Program Files (x86)\Microsoft Visual Studio 12.0\VC\)
function getVSInstallPath($version) {
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

# prints a sorted array of visual studio version numbers
function printInstalledVSVersions() {
    $versions = $yearVersionMap.GetEnumerator() | sort @{e={$_.Value -as [Decimal]}; descending=$true} |
        ? {getVSInstallPath $_.Value}
    "Detected Visual Studio Installs:`n"
    $versions | % {"`    Visual Studio " + $_.Key + ' (' + $_.Value + ')'}
}

# returns the highest version of vs installed
function getNewestVSInstallPath() {
    $yearVersionMap.GetEnumerator() | sort @{e={$_.Value -as [Decimal]}; descending=$true} |
        ? {getVSInstallPath $_.Value} | % {$_.Value} | select -first 1
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

# will attempt to use the given VS version
function useVSVersion($version, $architecture) {
    if ($version -eq 'latest') {
        $version = getNewestVSInstallPath
        if (!$version) {
            errorOut 'No version of Visual Studio was found.'
        }
    }

    $vsPath = getVSInstallPath $version
    if (!$vsPath) {
        errorOut "Visual Studio version $version not found."
    }

    $batPath = Join-Path $vsPath 'vcvarsall.bat'
    execBatchFile $batPath $architecture

    "Using Visual Studio $version $architecture"
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

    "$psvsName version $psvsVersion"
    exit 0
}

if (!$commands) {
    $psvsUsage
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
        printInstalledVSVersions
    }
    exit 0
}

if ($commands[0] -eq 'use') {
    $commands.removeAt(0)
    if ($help) {
        $useUsage
        exit 0
    }
    
    $vsVersion = 'latest'
    $architecture = $env:PROCESSOR_ARCHITECTURE.ToLower()
    if ($commands) {
        $vsVersion = $commands[0].ToString().ToLower()
        $commands.removeAt(0)
    }
    if ($commands) {
        $architecture = $commands[0].ToString().ToLower()
        $commands.removeAt(0)
    }
    useVSVersion $vsVersion $architecture
    exit 0
}

invalidArguments $commands
