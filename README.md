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

### Architecture

- `architecture.mmd` -- Mermaid diagram showing Endpoint to PROTECT to LiveGrid to Update flows with ports labeled per hop. Render with any Mermaid-compatible viewer or paste into [mermaid.live](https://mermaid.live).

## Troubleshooting Checklist

### Updates Failing

1. Test DNS resolution: `nslookup update.eset.com`
2. Test TCP 443 to update server: `Test-NetConnection update.eset.com -Port 443`
3. Test TCP 80 fallback: `Test-NetConnection update.eset.com -Port 80`
4. If using ESET Bridge/proxy, verify `login.microsoftonline.com:443` is reachable
5. Check `pico.eset.com:443` for micro-update delivery
6. Run `.\Test-ESETReachability.ps1 -Service updates` for a full check

### LiveGrid Not Working

1. Test DNS: `nslookup livegrid.eset.systems`
2. Test TCP 443: `Test-NetConnection c.eset.com -Port 443`
3. Test DNS-based lookups: `nslookup e5.sk` (must resolve)
4. Verify UDP 53 is not blocked outbound to ESET DNS servers
5. Run `.\Test-ESETReachability.ps1 -Service livegrid`

### Activation / License Issues

1. Test `expire.eset.com:443`
2. Test `proxy.eset.com:443` (activation proxy)
3. Test `pki.eset.com:443` (certificate validation)
4. For mobile: test `reg01.eset.com` through `reg04.eset.com`
5. Run `.\Test-ESETReachability.ps1 -Service activation`

### PROTECT Console Cannot Reach Agents

1. Verify EPNS broker connectivity: `Test-NetConnection h1-epnsbroker01.eset.com -Port 8883`
2. For cloud: test `protect.eset.com:443` and your regional endpoint (e.g., `us02.protect.eset.com`)
3. For MDM: test `checkin.<region>.mdm.eset.com:443`
4. Run `.\Test-ESETReachability.ps1 -Service protect-console`

### EDTD / LiveGuard Sandbox Not Processing

1. Test `r.edtd.eset.com:443` (result retrieval)
2. Test `d.edtd.eset.com:443` (file submission)
3. Verify threat telemetry: `Test-NetConnection tsm09.eset.com -Port 443`
4. Run `.\Test-ESETReachability.ps1 -Service edtd`

## Port Reference Summary

| Port | Protocol | Used By |
|------|----------|---------|
| 80/tcp | HTTP | Updates (fallback), repository downloads |
| 443/tcp | HTTPS | All services (primary) |
| 53/udp | DNS | LiveGrid reputation, antispam lookups |
| 8883/tcp | MQTT/TLS | EPNS push notifications |
| 8443/tcp | HTTPS | PROTECT Cloud agent communication |
| 5228/tcp | FCM | Android push via Firebase Cloud Messaging |
| 2195-2196/tcp | APNs | iOS push via Apple Push Notification service |
| 6710-6711/tcp | TCP | Antispam greylisting database |
| 514/tcp | Syslog | PROTECT Cloud syslog forwarding |
| 601/tcp | Syslog/TCP | PROTECT Cloud syslog (reliable) |
| 6514/tcp | Syslog/TLS | PROTECT Cloud syslog (encrypted) |
| 21/tcp | FTP | Legacy FTP access (ftp.eset.sk) |
| 25/tcp | SMTP | Inbound email from ESET notification server |

## Source

Compiled from official ESET documentation and verified against production environments. Primary source: [ESET KB332](https://support.eset.com/en/kb332).

## License

MIT License
