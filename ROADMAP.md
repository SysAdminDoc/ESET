# ESET Roadmap

Reference lists of ports and addresses needed for ESET Endpoint Security, ESET PROTECT, updates, LiveGrid, EDTD, and licensing. Tracks evolution beyond the initial reference release.

## Planned Features

### Data Quality
- Split `Addresses.txt` / `Domains.txt` into per-service files: `endpoint.txt`, `protect-console.txt`, `updates.txt`, `livegrid.txt`, `edtd.txt`, `activation.txt`
- Machine-readable `eset-endpoints.json` with fields: `service`, `host`, `ports`, `protocol`, `direction`, `notes`, `source`
- Versioned releases that match ESET's published matrix (tag on every ESET KB update)
- Automated diff between new and old releases surfaced in the changelog so firewall admins know exactly what changed

### Automation
- GitHub Action that pulls ESET's official KB endpoint pages weekly and opens a PR if any host/port changed
- Link checker that probes every DNS name and marks NXDOMAIN / CNAME-only entries
- CIDR expansion: resolve every hostname to current IPs daily and produce a CIDR list for firewall admins who can't use FQDN rules
- Geo-resolution: tag each IP with country/ASN so admins running geo-fenced policies can whitelist by ASN

### Output Formats
- pfSense / OPNsense alias export (`.xml`)
- FortiGate address group CLI script
- Palo Alto URL category + address group XML import
- MikroTik RouterOS `/ip firewall address-list` script
- Cisco ASA / Firepower object-group import
- Windows Firewall / WDAC policy snippet
- Simple hosts file include for sinkhole use cases (inverted list of non-ESET hosts is NOT the goal — ESET endpoints should be *allowed*)

### Coverage Expansion
- Include Mac and Linux Endpoint-specific ports (differ from Windows Endpoint in rare cases)
- Include ESET Inspect (on-prem XDR) endpoints
- Include ESET Cloud Office Security (Microsoft 365 / Google Workspace connector) outbound requirements
- Include ESET Protect Deploy endpoints and MDM-push URLs

### Documentation
- Architecture diagrams showing Endpoint → PROTECT → LiveGrid → Update flows with required ports per hop
- Per-port rationale: why each is needed, what breaks without it, typical symptoms
- Troubleshooting checklist: "update failing? test these 4 endpoints in order"
- Migration notes when ESET rotates hostnames (e.g., `update.eset.com` → regional subdomains)

### Packaging
- GitHub Release per update with `.zip` of all formats plus `SHA256SUMS.txt`
- Tag semver in the form `YYYY.MM.N` tied to ESET's doc revision date
- Publish as npm + PyPI package for programmatic consumers (`@sysadmindoc/eset-endpoints`, `eset_endpoints`)

## Competitive Research

- **Official ESET KB "Which ports and addresses are used by my ESET product?"** — The source of truth. This repo exists to track it machine-readably over time. Key to stay honest in Attribution and keep a scraped-diff log.
- **Microsoft 365 URLs and IP address ranges web service** — Gold standard for publishing endpoint lists with a JSON API; mirror their schema (`id`, `urls`, `ips`, `tcpPorts`, `udpPorts`, `expressRoute`, `category`).
- **URLhaus / community threat feeds** — Opposite sign (block lists), but the tooling around publishing + consuming IP/URL lists applies. Adopt their CSV+JSON dual-output pattern.
- **Other vendor endpoint refs (CrowdStrike, SentinelOne, Defender for Endpoint)** — Worth a sibling repo structure so sysadmins who run multi-vendor shops have a consistent toolkit.

## Nice-to-Haves

- Tiny static site that renders the endpoint matrix with filters (product, platform, format) and one-click download
- Terraform / Ansible modules that emit firewall rules for common targets
- PowerShell module: `Get-ESETEndpoints -Product ProtectConsole -Platform Windows -Format pfSense`
- "Testing harness" Docker image that validates connectivity to every endpoint from inside the customer network
- Subscription-free RSS feed on changes so firewall admins can wire an alert
- Companion CRL / OCSP endpoint list for the code-signing certificates ESET binaries use (common cause of slow validation on locked-down networks)

## Open-Source Research (Round 2)

### Related OSS Projects
- **metablaster/WindowsFirewallRuleset** — https://github.com/metablaster/WindowsFirewallRuleset — large curated PowerShell firewall rulesets for Windows; rule-bundle pattern worth mirroring for a ruleset flavor of this reference
- **MScholtes/Firewall-Manager** — https://github.com/MScholtes/Firewall-Manager — PowerShell helpers to export/import/apply WFP rules; useful for turning ESET's port lists into importable rules
- **nextdns/ctrld** — https://github.com/nextdns/ctrld — DNS client with policy/allowlist handling; reference for bundling endpoint allowlists
- **jgraph/drawio** — https://github.com/jgraph/drawio — useful for publishing the port-matrix as an importable network diagram (ESET Protect architecture)
- **PortQry replacements: Test-NetConnection wrappers** — https://github.com/jdhitsolutions/PSScriptTools — idiomatic PowerShell probing for the listed endpoints
- **awesome-firewall** — https://github.com/topics/firewall-rules — curated lists pattern
- **pi-hole/pi-hole** — https://github.com/pi-hole/pi-hole — for structuring a browsable blocklist/allowlist "Adlist" model
- **NirSoft resources (not OSS) + PortQry** — reference only; keep as "see also" links

### Features to Borrow
- Publish the port matrix as a Markdown table AND a machine-readable JSON/YAML ("esp-ports.yaml") so other tools can ingest it (pi-hole Adlists pattern)
- Ship an importable Windows Firewall ruleset `.wfw` and a PowerShell helper `Import-ESETFirewall.ps1` that applies named profiles (metablaster + MScholtes)
- pfSense / OPNsense alias files: pre-built IP + FQDN aliases for each ESET service tier (community pfSense pattern)
- UniFi JSON blob to pre-seed a "ESET Management" firewall group (UniFi-Edge configs on GitHub)
- Intune/Entra MDM Administrative Templates bundle: intune-ready .intunewin for pushing the allowlists to Defender Firewall on endpoints
- Versioned snapshots by ESET product line (ESS, EP, EP Cloud, EEE, ESMC → ESET PROTECT rename) — clarify which set applies to which product generation
- Diagram export: a Mermaid `flowchart` or drawio XML showing client → console → update → cloud flows with the ports labeled on each arrow (drawio)
- Test script: `Test-ESETReachability.ps1` that pings every listed endpoint/port on a host and emits a PASS/FAIL report (Test-NetConnection wrapper)
- Signed manifests so sysadmins can verify the ruleset came from this repo unmodified (Authenticode on the ZIP; optional)
- GitHub Pages site with a searchable/filterable port table (sortable by port/product/direction) for quick reference during incidents

### Patterns & Architectures Worth Studying
- YAML as source-of-truth + generator scripts that emit Markdown + CSV + JSON + PowerShell rules + pfSense aliases (multi-format pattern seen across awesome-firewall projects)
- Profile-based bundling: not "all ESET ports" but "ESET PROTECT console-to-endpoint" etc., so users import only what applies (metablaster's profile-per-machine-role pattern)
- CI-verified reachability: GitHub Action pings ESET's public endpoints weekly; if any fail, open an issue so the list stays current
- Community PR workflow with schema validation — new ports come in as YAML diffs validated in CI, then regenerated everywhere (general awesome-list pattern)
- Clear "last verified against ESET version X" badge per file so consumers know the freshness (any ops-critical reference repo)
