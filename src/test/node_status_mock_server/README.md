# Node Status Mock Server

A lightweight HTTP server that collects node-status and node-error reports
sent by the Mina daemon via `--node-status-url` / `--node-error-url`.

## Purpose

Used by the `node-status-report` command-line test
(`src/test/command_line_tests/`) to verify that the daemon actually sends
status reports when configured.

## Usage

```bash
# Build
dune build src/test/node_status_mock_server/node_status_mock_server.exe

# Run
_build/default/src/test/node_status_mock_server/node_status_mock_server.exe --port 19876
```

## Routes

| Method | Path                 | Description                                    |
|--------|----------------------|------------------------------------------------|
| POST   | `/node-status`       | Stores the request body as a status payload    |
| POST   | `/node-error`        | Stores the request body as an error payload    |
| GET    | `/collected-status`  | Returns all status payloads as a JSON array    |
| GET    | `/collected-errors`  | Returns all error payloads as a JSON array     |
| GET    | `/health`            | Returns `200 OK` (readiness probe)             |

## Example

```bash
# Post a status report
curl -X POST http://localhost:19876/node-status \
  -d '{"data":{"sync_status":"Synced","peer_id":"abc123"}}'

# Retrieve collected reports
curl http://localhost:19876/collected-status
# => ["{\"data\":{\"sync_status\":\"Synced\",\"peer_id\":\"abc123\"}}"]
```
