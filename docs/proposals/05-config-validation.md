# Proposal: Configuration Validation and Documentation

## Problems

1. No way to validate config before starting (multi-minute boot wasted on typos)
2. Unknown keys in `daemon.json` are silently ignored (misspellings go undetected)
3. No JSON Schema for `daemon.json`
4. Config precedence is complex and undocumented
5. `--print-config` doesn't exist --- operators can't see the resolved configuration

## Proposed Changes

### 1. `mina daemon --validate-config`

Parses all config files, applies CLI flag overrides, and prints the fully-resolved configuration as JSON. Exits 0 if valid, non-zero with error messages if not.

```bash
$ mina daemon --validate-config --config-file daemon.json
Config validation passed.
Resolved configuration:
{
  "daemon": {
    "client_port": 8301,
    "rest_port": 3085,
    "external_port": 8302,
    ...
  }
}
```

### 2. Warn on unknown config keys

Change `yojson_strip_fields` behavior to log a warning for each unrecognized key:

```
[WARN] Unknown key "peerListUrl" in daemon.json (did you mean "peer_list_url"?)
```

This catches typos immediately without breaking backward compatibility.

### 3. `daemon.json` JSON Schema

Create `docs/daemon-json-schema.json` --- a formal JSON Schema for the daemon config file. This enables:
- IDE autocompletion
- CI validation
- Documentation generation

### 4. Document config precedence

Add to `docs/daemon.md`:
```
Configuration precedence (highest to lowest):
1. CLI flags
2. MINA_CONFIG_FILE environment variable
3. --config-file flags (last wins)
4. <conf_dir>/daemon.json
5. Installed package config
6. Compiled defaults
```

## Files to Modify

- `src/app/cli/src/cli_entrypoint/mina_cli_entrypoint.ml` --- add `--validate-config` and `--print-config`
- `src/lib/runtime_config/` --- add unknown-key warnings
- `docs/daemon-json-schema.json` --- new file
- `docs/daemon.md` --- update with precedence documentation

## Effort Estimate

Medium --- 3-5 days.
