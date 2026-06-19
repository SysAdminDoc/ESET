<#
.SYNOPSIS
    Generates firewall import files from eset-endpoints.json.
.DESCRIPTION
    Reads the master eset-endpoints.json and produces export files for:
    - pfSense / OPNsense alias XML
    - FortiGate address group CLI script
    - Palo Alto address group XML
    - MikroTik RouterOS address-list script
    - Cisco ASA object-group import
    - Windows Firewall (netsh) script
    - Hosts file (allowlist reference)
.NOTES
    Run from the repository root: .\Generate-Exports.ps1
#>

param(
    [string]$JsonPath = (Join-Path $PSScriptRoot 'eset-endpoints.json'),
    [string]$ExportDir = (Join-Path $PSScriptRoot 'exports')
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $JsonPath)) {
    Write-Error "Cannot find $JsonPath"
    return
}

$data = Get-Content $JsonPath -Raw | ConvertFrom-Json
$endpoints = $data.endpoints

if (-not (Test-Path $ExportDir)) {
    New-Item -ItemType Directory -Force -Path $ExportDir | Out-Null
}

# Collect all unique hosts and IPs across all services
$allHosts = @()
$allIPv4 = @()
$allIPv6 = @()

foreach ($ep in $endpoints) {
    $allHosts += $ep.hosts
    $allIPv4 += $ep.ips
    if ($ep.ipv6) { $allIPv6 += $ep.ipv6 }
}

$allHosts = $allHosts | Where-Object { $_ -and $_ -ne '' } | Sort-Object -Unique
$allIPv4 = $allIPv4 | Where-Object { $_ -and $_ -ne '' } | Sort-Object -Unique
$allIPv6 = $allIPv6 | Where-Object { $_ -and $_ -ne '' } | Sort-Object -Unique

# Group by service for per-service exports
$services = $endpoints | Group-Object -Property service

# ============================================================
# 1. pfSense / OPNsense Alias XML
# ============================================================
Write-Host "Generating pfSense/OPNsense alias XML..."

$pfXml = @"
<?xml version="1.0" encoding="UTF-8"?>
<!-- ESET Endpoint Aliases for pfSense / OPNsense -->
<!-- Generated: $(Get-Date -Format 'yyyy-MM-dd') -->
<!-- Import via Diagnostics > Backup & Restore > Restore Configuration Area: Aliases -->
<pfsense>
  <aliases>
"@

foreach ($svc in $services) {
    $svcName = $svc.Name
    $aliasName = "ESET_$($svcName -replace '-','_')"
    $svcHosts = @()
    $svcIPs = @()
    foreach ($ep in $svc.Group) {
        $svcHosts += $ep.hosts | Where-Object { $_ -and $_ -ne '' -and $_ -notlike '*`**' }
        $svcIPs += $ep.ips | Where-Object { $_ -and $_ -ne '' }
    }
    $svcHosts = $svcHosts | Sort-Object -Unique
    $svcIPs = $svcIPs | Sort-Object -Unique

    # FQDN alias
    if ($svcHosts.Count -gt 0) {
        $pfXml += @"

    <alias>
      <name>${aliasName}_FQDN</name>
      <type>urltable_ports</type>
      <descr>ESET $svcName FQDNs</descr>
      <address>$($svcHosts -join ' ')</address>
      <detail>$($svcHosts | ForEach-Object { "ESET $svcName" } | Select-Object -First $svcHosts.Count | Out-String -Stream | ForEach-Object { $_.Trim() } | Where-Object { $_ } )</detail>
    </alias>
"@
    }

    # IP alias
    if ($svcIPs.Count -gt 0) {
        $pfXml += @"

    <alias>
      <name>${aliasName}_IP</name>
      <type>network</type>
      <descr>ESET $svcName IPs</descr>
      <address>$($svcIPs | ForEach-Object { "$_/32" } | Join-String -Separator ' ')</address>
      <detail>$($svcIPs | ForEach-Object { "ESET||" } | Join-String -Separator ' ')</detail>
    </alias>
"@
    }
}

$pfXml += @"

  </aliases>
</pfsense>
"@

$pfXml | Out-File (Join-Path $ExportDir 'pfsense-aliases.xml') -Encoding UTF8

# ============================================================
# 2. FortiGate address group CLI script
# ============================================================
Write-Host "Generating FortiGate CLI script..."

$fgLines = @()
$fgLines += "# ESET Endpoint Address Objects and Groups for FortiGate"
$fgLines += "# Generated: $(Get-Date -Format 'yyyy-MM-dd')"
$fgLines += "# Paste into FortiGate CLI (config system console)"
$fgLines += ""
$fgLines += "config firewall address"

$addrIndex = 0
foreach ($svc in $services) {
    $svcName = $svc.Name
    foreach ($ep in $svc.Group) {
        foreach ($fqdn in ($ep.hosts | Where-Object { $_ -and $_ -ne '' -and $_ -notlike '*`**' })) {
            $addrIndex++
            $objName = "ESET-$svcName-fqdn-$addrIndex"
            $fgLines += "    edit `"$objName`""
            $fgLines += "        set type fqdn"
            $fgLines += "        set fqdn `"$fqdn`""
            $fgLines += "        set comment `"ESET $($ep.category)`""
            $fgLines += "    next"
        }
        foreach ($ip in ($ep.ips | Where-Object { $_ -and $_ -ne '' })) {
            $addrIndex++
            $objName = "ESET-$svcName-ip-$addrIndex"
            $fgLines += "    edit `"$objName`""
            $fgLines += "        set type ipmask"
            $fgLines += "        set subnet $ip/32"
            $fgLines += "        set comment `"ESET $($ep.category)`""
            $fgLines += "    next"
        }
    }
}

$fgLines += "end"
$fgLines += ""
$fgLines += "config firewall addrgrp"

foreach ($svc in $services) {
    $svcName = $svc.Name
    $members = @()
    $idx = 0
    # We need to reconstruct the member names
    $memberAddrIndex = 0
    foreach ($s2 in $services) {
        foreach ($ep in $s2.Group) {
            foreach ($fqdn in ($ep.hosts | Where-Object { $_ -and $_ -ne '' -and $_ -notlike '*`**' })) {
                $memberAddrIndex++
                if ($s2.Name -eq $svcName) {
                    $members += "`"ESET-$svcName-fqdn-$memberAddrIndex`""
                }
            }
            foreach ($ip in ($ep.ips | Where-Object { $_ -and $_ -ne '' })) {
                $memberAddrIndex++
                if ($s2.Name -eq $svcName) {
                    $members += "`"ESET-$svcName-ip-$memberAddrIndex`""
                }
            }
        }
    }

    if ($members.Count -gt 0) {
        $fgLines += "    edit `"ESET-$svcName-group`""
        $fgLines += "        set member $($members -join ' ')"
        $fgLines += "        set comment `"ESET $svcName service endpoints`""
        $fgLines += "    next"
    }
}

$fgLines += "end"

$fgLines | Out-File (Join-Path $ExportDir 'fortigate-addresses.conf') -Encoding UTF8

# ============================================================
# 3. Palo Alto address group XML
# ============================================================
Write-Host "Generating Palo Alto XML..."

$paXml = @"
<?xml version="1.0" encoding="UTF-8"?>
<!-- ESET Endpoint Addresses for Palo Alto Networks -->
<!-- Generated: $(Get-Date -Format 'yyyy-MM-dd') -->
<!-- Import via Device > Setup > Operations > Import named configuration snapshot -->
<config>
  <devices>
    <entry name="localhost.localdomain">
      <vsys>
        <entry name="vsys1">
          <address>
"@

$paGroupMembers = @{}
foreach ($svc in $services) {
    $svcName = $svc.Name
    $paGroupMembers[$svcName] = @()
    foreach ($ep in $svc.Group) {
        foreach ($fqdn in ($ep.hosts | Where-Object { $_ -and $_ -ne '' -and $_ -notlike '*`**' })) {
            $objName = "ESET-$($fqdn -replace '\.', '-')"
            $paGroupMembers[$svcName] += $objName
            $paXml += @"

            <entry name="$objName">
              <fqdn>$fqdn</fqdn>
              <description>ESET $($ep.category)</description>
            </entry>
"@
        }
        foreach ($ip in ($ep.ips | Where-Object { $_ -and $_ -ne '' })) {
            $objName = "ESET-$($ip -replace '\.', '-')"
            $paGroupMembers[$svcName] += $objName
            $paXml += @"

            <entry name="$objName">
              <ip-netmask>$ip/32</ip-netmask>
              <description>ESET $($ep.category)</description>
            </entry>
"@
        }
    }
}

$paXml += @"

          </address>
          <address-group>
"@

foreach ($svc in $services) {
    $svcName = $svc.Name
    $members = $paGroupMembers[$svcName]
    if ($members.Count -gt 0) {
        $paXml += @"

            <entry name="ESET-$svcName">
              <static>
"@
        foreach ($m in $members) {
            $paXml += "                <member>$m</member>`n"
        }
        $paXml += @"
              </static>
              <description>ESET $svcName service endpoints</description>
            </entry>
"@
    }
}

$paXml += @"

          </address-group>
        </entry>
      </vsys>
    </entry>
  </devices>
</config>
"@

$paXml | Out-File (Join-Path $ExportDir 'paloalto-addresses.xml') -Encoding UTF8

# ============================================================
# 4. MikroTik RouterOS address-list script
# ============================================================
Write-Host "Generating MikroTik RouterOS script..."

$mkLines = @()
$mkLines += "# ESET Endpoint Address Lists for MikroTik RouterOS"
$mkLines += "# Generated: $(Get-Date -Format 'yyyy-MM-dd')"
$mkLines += "# Paste into terminal or upload as .rsc script"
$mkLines += ""

foreach ($svc in $services) {
    $svcName = $svc.Name
    $listName = "ESET-$svcName"
    $mkLines += "# --- $svcName ---"
    foreach ($ep in $svc.Group) {
        foreach ($fqdn in ($ep.hosts | Where-Object { $_ -and $_ -ne '' -and $_ -notlike '*`**' })) {
            $mkLines += "/ip firewall address-list add list=$listName address=$fqdn comment=`"$($ep.category)`""
        }
        foreach ($ip in ($ep.ips | Where-Object { $_ -and $_ -ne '' })) {
            $mkLines += "/ip firewall address-list add list=$listName address=$ip comment=`"$($ep.category)`""
        }
    }
    $mkLines += ""
}

$mkLines | Out-File (Join-Path $ExportDir 'mikrotik-addresslist.rsc') -Encoding UTF8

# ============================================================
# 5. Cisco ASA object-group import
# ============================================================
Write-Host "Generating Cisco ASA object-group config..."

$asaLines = @()
$asaLines += "! ESET Endpoint Object Groups for Cisco ASA / Firepower"
$asaLines += "! Generated: $(Get-Date -Format 'yyyy-MM-dd')"
$asaLines += "! Paste into ASA CLI (config mode)"
$asaLines += ""

foreach ($svc in $services) {
    $svcName = $svc.Name
    $groupName = "ESET-$($svcName.ToUpper())"
    $asaLines += "object-group network $groupName"
    $asaLines += " description ESET $svcName service endpoints"
    foreach ($ep in $svc.Group) {
        foreach ($fqdn in ($ep.hosts | Where-Object { $_ -and $_ -ne '' -and $_ -notlike '*`**' })) {
            $asaLines += " network-object host $fqdn"
        }
        foreach ($ip in ($ep.ips | Where-Object { $_ -and $_ -ne '' })) {
            $asaLines += " network-object host $ip"
        }
    }
    $asaLines += ""
}

$asaLines | Out-File (Join-Path $ExportDir 'cisco-asa-objects.txt') -Encoding UTF8

# ============================================================
# 6. Windows Firewall (netsh) script
# ============================================================
Write-Host "Generating Windows Firewall netsh script..."

$wfLines = @()
$wfLines += "@echo off"
$wfLines += "REM ESET Endpoint Firewall Rules for Windows Firewall"
$wfLines += "REM Generated: $(Get-Date -Format 'yyyy-MM-dd')"
$wfLines += "REM Run as Administrator"
$wfLines += ""

foreach ($svc in $services) {
    $svcName = $svc.Name
    $ruleName = "ESET-$svcName"

    # Collect all IPs for this service
    $svcIPs = @()
    $svcPorts = @()
    foreach ($ep in $svc.Group) {
        foreach ($ip in ($ep.ips | Where-Object { $_ -and $_ -ne '' })) {
            $svcIPs += $ip
        }
        foreach ($port in $ep.ports) {
            if ($port -match '^(\d+(?:-\d+)?)/tcp') {
                $svcPorts += $Matches[1]
            }
        }
    }
    $svcIPs = $svcIPs | Sort-Object -Unique
    $svcPorts = $svcPorts | Sort-Object -Unique

    if ($svcIPs.Count -gt 0 -and $svcPorts.Count -gt 0) {
        $ipList = $svcIPs -join ','
        $portList = $svcPorts -join ','
        $wfLines += "REM --- $svcName ---"
        $wfLines += "netsh advfirewall firewall add rule name=`"$ruleName`" dir=out action=allow protocol=tcp remoteip=$ipList remoteport=$portList enable=yes profile=any"
        $wfLines += ""
    }
}

$wfLines | Out-File (Join-Path $ExportDir 'windows-firewall.cmd') -Encoding UTF8

# ============================================================
# 7. Hosts file (allowlist reference)
# ============================================================
Write-Host "Generating hosts file reference..."

$fqdnsLines = @()
$fqdnsLines += "# ESET Endpoint Hosts - Allowlist Reference"
$fqdnsLines += "# Generated: $(Get-Date -Format 'yyyy-MM-dd')"
$fqdnsLines += "# These hosts should be ALLOWED (not blocked) for ESET to function."
$fqdnsLines += "# Add to your DNS allowlist or proxy bypass list."
$fqdnsLines += "#"
$fqdnsLines += "# This is NOT a hosts-file block list. All entries resolve to their"
$fqdnsLines += "# real addresses. This file serves as a reference for which FQDNs"
$fqdnsLines += "# must be reachable from endpoints running ESET products."
$fqdnsLines += ""

foreach ($svc in $services) {
    $svcName = $svc.Name
    $fqdnsLines += "# === $($svcName.ToUpper()) ==="
    foreach ($ep in $svc.Group) {
        foreach ($fqdn in ($ep.hosts | Where-Object { $_ -and $_ -ne '' -and $_ -notlike '*`**' })) {
            $fqdnsLines += $fqdn
        }
    }
    $fqdnsLines += ""
}

$fqdnsLines | Out-File (Join-Path $ExportDir 'eset-allowlist-hosts.txt') -Encoding UTF8

Write-Host ""
Write-Host "Export complete. Files written to: $ExportDir"
Write-Host "  - pfsense-aliases.xml"
Write-Host "  - fortigate-addresses.conf"
Write-Host "  - paloalto-addresses.xml"
Write-Host "  - mikrotik-addresslist.rsc"
Write-Host "  - cisco-asa-objects.txt"
Write-Host "  - windows-firewall.cmd"
Write-Host "  - eset-allowlist-hosts.txt"
