# ESET Port & Address Reference

![License](https://img.shields.io/badge/license-MIT-blue)
![Type](https://img.shields.io/badge/type-Reference-informational)

Complete ESET endpoint security port and address reference lists for firewall configuration and network policy management. Essential for sysadmins deploying ESET in managed environments.

## Contents

### Raw Lists

- `Addresses.txt` -- All IP addresses grouped by ESET service category
- `Domains.txt` -- All FQDNs grouped by ESET service category

### Per-Service Files (`services/`)

Split by logical ESET service tier for targeted firewall rules:

| File | Covers |
|------|--------|
| `services/updates.txt` | Detection engine updates, pico updates, product installers |
| `services/endpoint.txt` | Antispam, web control, anti-theft, password manager, ESA, SSL check |
| `services/protect-console.txt` | PROTECT on-prem & cloud, EPNS, MDM, MSP, syslog, ESET Connect |
| `services/livegrid.txt` | LiveGrid reputation, advanced machine learning (Augur) |
| `services/edtd.txt` | EDTD/LiveGuard sandbox, threat telemetry, ESET Inspect (XDR) |
| `services/activation.txt` | Licensing, activation, version checks, PKI, telemetry |

### Machine-Readable Data

- `eset-endpoints.json` -- Structured JSON with fields: `service`, `category`, `hosts`, `ips`, `ipv6`, `ports`, `protocol`, `direction`, `notes`, `source`

### Firewall Export Formats (`exports/`)

Ready-to-import files for common firewall platforms:

| File | Platform |
|------|----------|
| `exports/pfsense-aliases.xml` | pfSense / OPNsense alias import |
| `exports/fortigate-addresses.conf` | FortiGate address object + group CLI |
| `exports/paloalto-addresses.xml` | Palo Alto Networks address group XML |
| `exports/mikrotik-addresslist.rsc` | MikroTik RouterOS `/ip firewall address-list` script |
| `exports/cisco-asa-objects.txt` | Cisco ASA / Firepower object-group config |
| `exports/windows-firewall.cmd` | Windows Firewall `netsh advfirewall` batch script |
| `exports/eset-allowlist-hosts.txt` | Plain FQDN list for DNS allowlists / proxy bypass |

### Tools

- `Generate-Exports.ps1` -- Regenerates all export files from `eset-endpoints.json`
- `Test-ESETReachability.ps1` -- Tests connectivity to every listed endpoint from the current host

## Usage

### Quick Start

Use the per-service files or export files directly. Import into your firewall management tool or reference during ESET deployment.

### Regenerate Exports

After editing `eset-endpoints.json`, regenerate all export formats:

```powershell
.\Generate-Exports.ps1
```

### Test Connectivity

Verify your network can reach all required ESET endpoints:

```powershell
# Test all endpoints (TCP connect)
.\Test-ESETReachability.ps1

# Test only update servers
.\Test-ESETReachability.ps1 -Service updates

# Quick DNS-only check
.\Test-ESETReachability.ps1 -DnsOnly
```

## Source

Compiled from official ESET documentation and verified against production environments. Primary source: [ESET KB332](https://support.eset.com/en/kb332).

## License

MIT License
