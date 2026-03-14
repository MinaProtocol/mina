# Proposal: Fix Graceful Shutdown and Systemd Integration

## Problems

### Exit Code Bug
Daemon exits with code 130 on SIGTERM. Systemd treats non-zero exit as failure -> restart loop.

**Root cause**: `src/app/cli/src/init/mina_run.ml` line ~860: `Async.shutdown 130` is called for ALL terminating signals. Code 130 is conventionally for SIGINT only.

### Inconsistent Shutdown Paths
- Signal handler: calls `log_shutdown` (dumps transition frontier dot files) then exits
- `mina client stop-daemon`: calls `exit 0` directly from RPC handler, skipping `log_shutdown`
- These should be the same path

### Systemd Service File
`scripts/mina.service` is minimal --- missing production hardening. No archive service file exists.

## Proposed Changes

### 1. Fix exit codes

```ocaml
(* Map signal to correct exit code *)
let exit_code = match signal with
  | Signal.term -> 0   (* graceful stop *)
  | Signal.int  -> 130 (* Ctrl-C *)
  | _           -> 128 (* other signals *)
```

### 2. Unify shutdown paths

Make `stop-daemon` RPC trigger the same shutdown handler as SIGTERM.

### 3. Harden systemd service

```ini
[Unit]
Description=Mina Protocol Daemon
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=mina
Group=mina
ExecStart=/usr/local/bin/mina daemon --config-dir /var/lib/mina
ExecStop=/usr/local/bin/mina client stop-daemon
Restart=on-failure
RestartSec=30
TimeoutStartSec=900
TimeoutStopSec=60
LimitNOFILE=65536
LimitNPROC=65536
LimitSTACK=67108864
PrivateTmp=yes
NoNewPrivileges=yes
ProtectSystem=full
StandardOutput=journal
StandardError=journal
SyslogIdentifier=mina

[Install]
WantedBy=multi-user.target
```

### 4. Create archive service file

```ini
[Unit]
Description=Mina Archive Node
After=postgresql.service network-online.target
Requires=postgresql.service

[Service]
Type=simple
User=mina
Group=mina
ExecStart=/usr/local/bin/mina-archive run --postgres-uri ... --server-port 3086
Restart=on-failure
RestartSec=10
TimeoutStopSec=30
LimitNOFILE=65536
StandardOutput=journal
StandardError=journal
SyslogIdentifier=mina-archive

[Install]
WantedBy=multi-user.target
```

### 5. Remove dot-file generation from normal shutdown

Only dump transition frontier visualizations on crash, not on normal SIGTERM/stop.

## Files to Modify

- `src/app/cli/src/init/mina_run.ml` --- exit code fix, unified shutdown
- `scripts/mina.service` --- hardened service file
- `scripts/mina-archive.service` --- new file

## Effort Estimate

Small --- 1-2 days.
