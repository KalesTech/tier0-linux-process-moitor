# Tier0 Process Monitor

A lightweight Linux process baselining, anomaly detection, and integrity snapshot tool written in Bash.

This project follows a Tier‑0 security mindset:
establish what is normal first, then detect drift and anomalies with minimal assumptions.

---

## Overview

Tier0 Process Monitor provides visibility into:
- Running processes
- Newly observed commands between executions
- Unexpected (non‑whitelisted) commands
- System resource consumption
- Basic file integrity signals

The tool is designed to be:
- Low dependency (Bash + common Unix utilities)
- Forensic‑friendly (immutable collection output)
- Automation‑ready (cron, CI, or systemd compatible)

---

## Key Features

- Full process snapshot using ps
- Whitelist‑based unknown process detection
- Delta detection between consecutive runs
- Lightweight integrity hashing of critical files (SHA‑256)
- CPU and memory “top consumers” capture
- JSON summary output for UI or tooling ingestion
- Separate monitor and collection modes

---

## Operating Modes

### Monitor mode (default)

Intended for periodic execution.  
Tracks new commands since the last run and updates the baseline automatically.

Example:
./tier0_process_monitor.sh --mode monitor

---

### Collect mode

Creates timestamped, immutable snapshots.  
Does not overwrite previous data. Useful for audits or incident response.

Example:
./tier0_process_monitor.sh --mode collect

---

## Output Structure

OS_Monitor/tier0/
├── live_status/
│   ├── process_monitor.log
│   ├── alerts.txt
│   ├── process_summary.json
│   ├── unknown_procs.txt
│   └── ...
└── collection/
    └── 2026-04-06_14-30-55/
        ├── all_processes.txt
        ├── top_cpu.txt
        ├── top_mem.txt
        ├── file_hashes.txt
        └── ...

---

## Alerts and Signals

Notable findings are summarized in alerts.txt, including:
- Unknown processes detected
- New commands since the previous baseline
- Resource usage anomalies

This file is intentionally simple to allow easy ingestion by dashboards, log shippers, or SOC tooling.

---

## JSON Summary Output

A minimal JSON artifact is produced for integration with UIs or downstream tools.

Example:

{
  "timestamp": "2026-04-06_14-30-55",
  "mode": "monitor",
  "unknown_processes": ["unexpected_binary"],
  "new_since_last": ["curl"],
  "top_cpu": [
    "1234 root python3 48.2"
  ]
}

If jq is not installed, the script still produces output using safe fallbacks.

---

## Configuration

The tool uses a local process whitelist file:

known_processes.txt

To initialize:
cp known_processes.example.txt known_processes.txt

This file is intentionally excluded from version control so each environment can define its own baseline.

---

## Security Considerations

- No network access
- Read‑only inspection of system state
- No privilege escalation
- All output written to a user‑controlled directory
- Designed to minimize operational risk

---

## Dependencies

- Bash
- coreutils (ps, grep, sha256sum, comm)
- jq (optional but recommended)

---

## Use Cases

- Host baseline monitoring
- Change detection on shared systems
- Lightweight integrity checks
- Educational security tooling
- Pre‑SIEM signal generation

---

## Future Improvements

- Signed baseline and integrity snapshots
- eBPF or auditd integration
- systemd service support
- Alert forwarding (webhook or syslog)
- Expanded file integrity tracking

---

## License

This project is licensed under the MIT License.
