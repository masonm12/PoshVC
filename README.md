# PoshVS

PowerShell tool to help with Visual Studio consoles.

## Installation

Install with [Scoop](http://scoop.sh) from my personal [Scoop Bucket](https://github.com/masonm12/scoop-personal):

	scoop install poshvs
	
Or install directly:

	scoop install https://raw.githubusercontent.com/masonm12/scoop-personal/master/poshvs.json

## Usage

	poshvs [--version] [--help] command args
	
	optional arguments:
	    --version Print the version number.
	    --help    Print this help message.
	
	commands:
	    list      Print all detected versions of Visual Studio.
	    use       Import vcvarsall for a given version of Visual Studio (e.g. 2013, 10.0, etc).
		
### List

	poshvs list [--help]
	Print all detected versions of Visual Studio.
	
	optional arguments:
	    --help Print this help message.
		
### Use

	poshvs use [version] [architecture]
	Import vcvarsall for a given version of Visual Studio (e.g. 2013, 10.0, etc).
	
	optional arguments:
	    --help Print this help message.
	
	arguments:
	    version      Version of Visual Studio vcvarsall to try and import.
	                 (default: latest)
	    architecture Tools architecture to load, passed to vcvarsall.
	                 (default: current architecture)
