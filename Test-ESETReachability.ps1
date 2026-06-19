<#
.SYNOPSIS
    Tests connectivity to all ESET endpoints from the current host.
.DESCRIPTION
    Reads eset-endpoints.json and probes every listed hostname and IP
    on its expected port(s). Outputs a PASS/FAIL report per endpoint.
.PARAMETER JsonPath
    Path to eset-endpoints.json. Defaults to the file in the script directory.
.PARAMETER Service
    Filter to test only a specific service (updates, endpoint, protect-console,
    livegrid, edtd, activation). Omit to test all.
.PARAMETER TimeoutMs
    TCP connection timeout in milliseconds. Default: 3000.
.PARAMETER DnsOnly
    If set, only tests DNS resolution (no TCP connect). Useful for quick checks.
.EXAMPLE
    .\Test-ESETReachability.ps1
    .\Test-ESETReachability.ps1 -Service updates
    .\Test-ESETReachability.ps1 -DnsOnly
.NOTES
    Requires PowerShell 5.1+ or PowerShell 7+. No elevated privileges needed
    unless testing inbound ports.
#>

[CmdletBinding()]
param(
    [string]$JsonPath = (Join-Path $PSScriptRoot 'eset-endpoints.json'),
    [ValidateSet('updates','endpoint','protect-console','livegrid','edtd','activation','')]
    [string]$Service = '',
    [int]$TimeoutMs = 3000,
    [switch]$DnsOnly
)

$ErrorActionPreference = 'Continue'

if (-not (Test-Path $JsonPath)) {
    Write-Error "Cannot find $JsonPath"
    return
}

$data = Get-Content $JsonPath -Raw | ConvertFrom-Json

$results = @()
$totalPass = 0
$totalFail = 0
$totalSkip = 0

function Test-TcpPort {
    param(
        [string]$Target,
        [int]$Port,
        [int]$Timeout
    )
    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $connect = $tcp.BeginConnect($Target, $Port, $null, $null)
        $wait = $connect.AsyncWaitHandle.WaitOne($Timeout, $false)
        if ($wait -and $tcp.Connected) {
            $tcp.EndConnect($connect)
            $tcp.Close()
            return $true
        }
        $tcp.Close()
        return $false
    } catch {
        return $false
    }
}

function Test-DnsResolve {
    param([string]$Hostname)
    try {
        $resolved = [System.Net.Dns]::GetHostAddresses($Hostname)
        if ($resolved.Count -gt 0) {
            return @{ Success = $true; Addresses = ($resolved | ForEach-Object { $_.IPAddressToString }) -join ', ' }
        }
        return @{ Success = $false; Addresses = 'No addresses returned' }
    } catch {
        return @{ Success = $false; Addresses = $_.Exception.Message }
    }
}

Write-Host ""
Write-Host "ESET Endpoint Reachability Test" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "Mode: $(if ($DnsOnly) { 'DNS resolution only' } else { "TCP connect (timeout: ${TimeoutMs}ms)" })"
if ($Service) { Write-Host "Filter: $Service" }
Write-Host ""

foreach ($ep in $data.endpoints) {
    if ($Service -and $ep.service -ne $Service) { continue }

    Write-Host "--- $($ep.category) [$($ep.service)] ---" -ForegroundColor Yellow

    # Extract TCP ports
    $tcpPorts = @()
    foreach ($portSpec in $ep.ports) {
        if ($portSpec -match '^(\d+)/tcp') {
            $tcpPorts += [int]$Matches[1]
        } elseif ($portSpec -match '^(\d+)-(\d+)/tcp') {
            $tcpPorts += [int]$Matches[1]  # just test first port in range
        }
    }
    if ($tcpPorts.Count -eq 0) { $tcpPorts = @(443) }
    $testPort = $tcpPorts[0]  # primary port

    # Test hostnames
    foreach ($fqdn in $ep.hosts) {
        if (-not $fqdn -or $fqdn -eq '' -or $fqdn -like '*`**') { continue }

        if ($DnsOnly) {
            $dns = Test-DnsResolve -Hostname $fqdn
            if ($dns.Success) {
                Write-Host "  PASS  $fqdn -> $($dns.Addresses)" -ForegroundColor Green
                $totalPass++
                $results += [PSCustomObject]@{
                    Target = $fqdn; Port = 'DNS'; Status = 'PASS';
                    Service = $ep.service; Category = $ep.category;
                    Detail = $dns.Addresses
                }
            } else {
                Write-Host "  FAIL  $fqdn (DNS: $($dns.Addresses))" -ForegroundColor Red
                $totalFail++
                $results += [PSCustomObject]@{
                    Target = $fqdn; Port = 'DNS'; Status = 'FAIL';
                    Service = $ep.service; Category = $ep.category;
                    Detail = $dns.Addresses
                }
            }
        } else {
            $ok = Test-TcpPort -Target $fqdn -Port $testPort -Timeout $TimeoutMs
            if ($ok) {
                Write-Host "  PASS  ${fqdn}:${testPort}" -ForegroundColor Green
                $totalPass++
            } else {
                Write-Host "  FAIL  ${fqdn}:${testPort}" -ForegroundColor Red
                $totalFail++
            }
            $results += [PSCustomObject]@{
                Target = $fqdn; Port = $testPort; Status = $(if ($ok) {'PASS'} else {'FAIL'});
                Service = $ep.service; Category = $ep.category; Detail = ''
            }
        }
    }

    # Test IPs (skip if DNS-only mode)
    if (-not $DnsOnly) {
        foreach ($ip in $ep.ips) {
            if (-not $ip -or $ip -eq '') { continue }
            $ok = Test-TcpPort -Target $ip -Port $testPort -Timeout $TimeoutMs
            if ($ok) {
                Write-Host "  PASS  ${ip}:${testPort}" -ForegroundColor Green
                $totalPass++
            } else {
                Write-Host "  FAIL  ${ip}:${testPort}" -ForegroundColor Red
                $totalFail++
            }
            $results += [PSCustomObject]@{
                Target = $ip; Port = $testPort; Status = $(if ($ok) {'PASS'} else {'FAIL'});
                Service = $ep.service; Category = $ep.category; Detail = ''
            }
        }
    }
}

Write-Host ""
Write-Host "================================" -ForegroundColor Cyan
Write-Host "Summary" -ForegroundColor Cyan
Write-Host "  Total tested: $($totalPass + $totalFail)"
Write-Host "  PASS: $totalPass" -ForegroundColor Green
Write-Host "  FAIL: $totalFail" -ForegroundColor $(if ($totalFail -gt 0) { 'Red' } else { 'Green' })
Write-Host ""

# Export CSV report
$csvPath = Join-Path $PSScriptRoot "reachability-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv"
$results | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
Write-Host "Report saved to: $csvPath"
