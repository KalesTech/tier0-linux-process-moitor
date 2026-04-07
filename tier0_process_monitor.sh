#!/usr/bin/env bash
# tier0_process_monitor.sh
# Tier0 — Process & Integrity monitor
# Usage: ./tier0_process_monitor.sh --mode monitor|collect

set -euo pipefail

# Section 1
MODE="monitor"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode) MODE="${2:-monitor}"; shift 2 ;;
    --mode=*) MODE="${1#*=}"; shift ;;
    -h|--help) echo "Usage: $0 [--mode monitor|collect]"; exit 0 ;;
    *) echo "Unknown arg: $1"; exit 2 ;;
  esac
done

# Section 2
BASE_DIR="${HOME}/OS_Monitor/tier0"
LIVE_DIR="$BASE_DIR/live_status"
COLLECT_DIR="$BASE_DIR/collection"
TIMESTAMP="$(date +%F_%H-%M-%S)"
OUTDIR="$([ "$MODE" = "collect" ] && echo "$COLLECT_DIR/$TIMESTAMP" || echo "$LIVE_DIR")"
mkdir -p "$OUTDIR"

LOG="$OUTDIR/process_monitor.log"
touch "$LOG"

# Section 3
# Simple whitelist - extend as needed
KNOWN_PROCESSES_FILE="$BASE_DIR/known_processes.txt"
mkdir -p "$(dirname "$KNOWN_PROCESSES_FILE")"
# If whitelist file doesn't exist create a minimal one
if [ ! -f "$KNOWN_PROCESSES_FILE" ]; then
  cat > "$KNOWN_PROCESSES_FILE" <<'EOF'
bash
systemd
sshd
sudo
dbus-daemon
Xorg
Wayland
gnome-shell
kwin_x11
sway
python3
code
firefox
chrome
neofetch
ps
top
htop
EOF
fi

# Section 4
log() { printf '[%s] %s\n' "$(date +'%F %T')" "$1" | tee -a "$LOG"; }
success() { printf '[%s] ✓ %s\n' "$(date +'%F %T')" "$1" | tee -a "$LOG"; }
error() { printf '[%s] ✗ %s\n' "$(date +'%F %T')" "$1" | tee -a "$LOG"; }

log "Mode: $MODE"
log "Output dir: $OUTDIR"

# Section 5
# 1) Save full process list
ps aux > "$OUTDIR/all_processes.txt"

# 2) Extract command names (unique), check against whitelist
ps -eo comm --no-headers | sort | uniq > "$OUTDIR/current_cmds.txt"
# produce unknown list
grep -v -F -x -f "$KNOWN_PROCESSES_FILE" "$OUTDIR/current_cmds.txt" > "$OUTDIR/unknown_procs.txt" || true

if [ -s "$OUTDIR/unknown_procs.txt" ]; then
  error "Unknown processes found (see unknown_procs.txt)"
  cat "$OUTDIR/unknown_procs.txt" | tee -a "$LOG"
else
  success "No unknown processes detected"
fi

# 3) Lightweight integrity check: track small list of critical files (expand as needed)
CRITICAL_FILES=("$HOME/.bashrc" "/etc/sudoers" "$HOME/.profile")
: > "$OUTDIR/file_hashes.txt"
for f in "${CRITICAL_FILES[@]}"; do
  if [ -f "$f" ]; then
    sha256sum "$f" >> "$OUTDIR/file_hashes.txt" 2>/dev/null || true
  else
    printf "MISSING: %s\n" "$f" >> "$OUTDIR/file_hashes.txt"
  fi
done

# 4) Delta check (optional) - compares with last run (only in monitor mode)
LAST_RUN="$BASE_DIR/last_process_run.txt"
if [ -f "$LAST_RUN" ]; then
  # show new processes not present in last run
  comm -13 <(sort "$LAST_RUN") <(sort "$OUTDIR/current_cmds.txt") > "$OUTDIR/new_since_last.txt" || true
  if [ -s "$OUTDIR/new_since_last.txt" ]; then
    error "New commands since last run:"
    cat "$OUTDIR/new_since_last.txt" | tee -a "$LOG"
  fi
fi
# update last run list (overwrite)
sort "$OUTDIR/current_cmds.txt" > "$LAST_RUN"

# 5) Quick top consumers (for monitor mode make more frequent)
ps --no-headers -eo pid,ppid,cmd,%mem,%cpu --sort=-%cpu | head -n 15 > "$OUTDIR/top_cpu.txt"
ps --no-headers -eo pid,ppid,cmd,%mem --sort=-%mem | head -n 15 > "$OUTDIR/top_mem.txt"

# 6) Summarize anomalies into a single "alert" file that the UI will read
ALERTS="$OUTDIR/alerts.txt"
: > "$ALERTS"
if [ -s "$OUTDIR/unknown_procs.txt" ]; then
  echo "unknown_processes: $(wc -l < "$OUTDIR/unknown_procs.txt")" >> "$ALERTS"
fi
if [ -s "$OUTDIR/new_since_last.txt" ]; then
  echo "new_commands_since_last: $(wc -l < "$OUTDIR/new_since_last.txt")" >> "$ALERTS"
fi

#Section 6
# write a JSON summary for the UI (live only or also in collect mode)
JSON_SUMMARY="$OUTDIR/process_summary.json"
cat > "$JSON_SUMMARY" <<EOF
{
  "timestamp": "$TIMESTAMP",
  "mode": "$MODE",
  "unknown_processes": $(jq -R -s -c 'split("\n")[:-1]' "$OUTDIR/unknown_procs.txt" 2>/dev/null || echo "[]"),
  "new_since_last": $(jq -R -s -c 'split("\n")[:-1]' "$OUTDIR/new_since_last.txt" 2>/dev/null || echo "[]"),
  "top_cpu": $(jq -R -s -c 'split("\n")[:-1]' "$OUTDIR/top_cpu.txt" 2>/dev/null || echo "[]")
}
EOF

#Section 7
# If jq is missing, produce a fallback summary in plain text
if ! command -v jq >/dev/null 2>&1; then
  log "jq not installed — process_summary.json may contain arrays as strings"
fi

log "Process monitor complete. Output: $OUTDIR"
