<#
.SYNOPSIS
    PowerShell script for managing Windows static routes

.DESCRIPTION
    This script is used to add or remove static route entries in Windows systems.
    It supports using full subnet mask (Mask) or subnet mask length (MaskLen) to specify the mask.
    The script will automatically request administrator privileges to modify the system routing table.

.PARAMETER Add
    Used to add a new route record

.PARAMETER Remove
    Used to remove an existing route record

.PARAMETER Target
    Destination network address

.PARAMETER Mask
    Full format subnet mask (e.g.: 255.255.255.0)

.PARAMETER MaskLen
    Subnet mask length (e.g.: 24 represents 255.255.255.0)

.PARAMETER Gateway
    Gateway address

.EXAMPLE
    RouteManager.ps1 -Add -Target 192.168.12.0 -Mask 255.255.255.0 -Gateway 192.168.31.9
    
.EXAMPLE
    RouteManager.ps1 -Add -Target 192.168.12.0 -MaskLen 24 -Gateway 192.168.31.9
    
.EXAMPLE
    RouteManager.ps1 -Remove -Target 192.168.12.0 -Mask 255.255.255.0 -Gateway 192.168.31.9
#>

[CmdletBinding(DefaultParameterSetName = "None")]
param (
    [Parameter(Mandatory = $true, ParameterSetName = "Add")]
    [switch]$Add,
    
    [Parameter(Mandatory = $true, ParameterSetName = "Remove")]
    [switch]$Remove,
    
    [Parameter(Mandatory = $true, ParameterSetName = "Add")]
    [Parameter(Mandatory = $true, ParameterSetName = "Remove")]
    [ValidatePattern("^(\d{1,3}\.){3}\d{1,3}$")]
    [string]$Target,
    
    [Parameter(ParameterSetName = "Add")]
    [Parameter(ParameterSetName = "Remove")]
    [ValidatePattern("^(\d{1,3}\.){3}\d{1,3}$")]
    [string]$Mask,
    
    [Parameter(ParameterSetName = "Add")]
    [Parameter(ParameterSetName = "Remove")]
    [ValidateRange(0, 32)]
    [int]$MaskLen,
    
    [Parameter(Mandatory = $true, ParameterSetName = "Add")]
    [Parameter(Mandatory = $true, ParameterSetName = "Remove")]
    [ValidatePattern("^(\d{1,3}\.){3}\d{1,3}$")]
    [string]$Gateway
)

# Automatically request administrator privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    # Restart the script with administrator privileges
    $scriptPath = $MyInvocation.MyCommand.Definition
    $arguments = $MyInvocation.BoundParameters.Keys | ForEach-Object { 
        "-$_"; 
        if ($MyInvocation.BoundParameters[$_] -is [switch]) { 
            if ($MyInvocation.BoundParameters[$_].IsPresent) { $null } 
        } else { 
            $MyInvocation.BoundParameters[$_] 
        }
    }
    $arguments += $MyInvocation.UnboundArguments
    
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" $arguments" -Verb RunAs
    exit
}

# Function to validate IP address format
function Test-IPAddress {
    param ([string]$IP)
    
    try {
        $null = [System.Net.IPAddress]::Parse($IP)
        $octets = $IP -split '\.'
        foreach ($octet in $octets) {
            if ([int]$octet -gt 255) {
                return $false
            }
        }
        return $true
    }
    catch {
        return $false
    }
}

# Function to convert mask length to full subnet mask
function ConvertTo-SubnetMask {
    param ([int]$MaskLength)
    
    $mask = [UInt32]([Math]::Pow(2, $MaskLength) - 1) * [Math]::Pow(2, (32 - $MaskLength))
    $bytes = [BitConverter]::GetBytes([UInt32]$mask)
    [Array]::Reverse($bytes)
    return [String]::Join(".", $($bytes | ForEach-Object { [String]$_ }))
}

# Main programme logic starts here
# Validate IP address format
if (-not (Test-IPAddress -IP $Target)) {
    Write-Error "Error: Destination address ($Target) format is invalid"
    exit 1
}

if (-not (Test-IPAddress -IP $Gateway)) {
    Write-Error "Error: Gateway address ($Gateway) format is invalid"
    exit 1
}

# Determine which subnet mask to use
$useMask = $null
if ($Mask) {
    if (-not (Test-IPAddress -IP $Mask)) {
        Write-Error "Error: Subnet mask ($Mask) format is invalid"
        exit 1
    }
    $useMask = $Mask
}
elseif ($MaskLen -ge 0) {
    $useMask = ConvertTo-SubnetMask -MaskLength $MaskLen
}
else {
    Write-Error "Error: You must specify either a subnet mask (Mask) or subnet mask length (MaskLen)"
    exit 1
}

# Execute add or remove route operation
try {
    if ($Add) {
        Write-Verbose "Adding route: Destination=$Target, Mask=$useMask, Gateway=$Gateway"
        $result = route add $Target mask $useMask $Gateway
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Successfully added route: $Target via gateway $Gateway (mask: $useMask)"
        }
        else {
            Write-Error "Failed to add route: $result"
            exit 1
        }
    }
    elseif ($Remove) {
        Write-Verbose "Removing route: Destination=$Target, Mask=$useMask, Gateway=$Gateway"
        $result = route delete $Target mask $useMask
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Successfully removed route: $Target (mask: $useMask)"
        }
        else {
            Write-Error "Failed to remove route: $result"
            exit 1
        }
    }
}
catch {
    Write-Error "An error occurred whilst executing route command: $($_.Exception.Message)"
    exit 1
}
