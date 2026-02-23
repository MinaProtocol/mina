# Debian Package Session Scripts

A suite of bash scripts for modifying Debian packages in a session-based workflow. These scripts enable opening a `.deb` package, performing various modifications (insert, replace, remove, move files, and rename the package), and saving the modified package.

## Overview

These scripts provide a safe, session-based approach to modifying Debian packages without permanently altering the original file until you're ready. The workflow follows three main steps:

1. **Open** - Extract a .deb package into a session directory
2. **Modify** - Make changes using the provided helper scripts
3. **Save** - Repack the modified session into a new .deb file

## Quick Start

```bash
# 1. Open a debian package
./deb-session-open.sh mina-devnet_1.0_amd64.deb ./my-session

# 2. Modify the package (examples)
./deb-session-insert.sh ./my-session /var/lib/coda/ ledger.tar.gz
./deb-session-replace.sh ./my-session /etc/mina/config.json new-config.json
./deb-session-rename-package.sh ./my-session mina-devnet-hardfork

# 3. Save the modified package
./deb-session-save.sh ./my-session mina-devnet-hardfork_1.0_amd64.deb --verify
```

## Session Structure

After opening a package, the session directory contains:

```
my-session/
├── metadata.env       # Session metadata (compression type, paths, etc.)
├── debian-binary      # Debian package version
├── control/           # Package control files (Package name, Version, etc.)
└── data/              # Package file contents (modify these)
```

## Scripts Reference

### deb-session-open.sh

Opens a Debian package for modification by extracting it into a session directory.

**Usage:**
```bash
./deb-session-open.sh <input.deb> <session-dir>
```

**Example:**
```bash
./deb-session-open.sh mina-devnet_3.3.0_amd64.deb ./hardfork-session
```

**Notes:**
- Session directory will be created if it doesn't exist
- If session directory exists, it will be cleaned first
- Cannot be a symlink (security restriction)

---

### deb-session-save.sh

Saves a session by repacking the modified files into a `.deb` package.

**Usage:**
```bash
./deb-session-save.sh <session-dir> <output.deb> [--verify]
```

**Example:**
```bash
./deb-session-save.sh ./hardfork-session mina-devnet-hardfork_3.3.0_amd64.deb --verify
```

**Notes:**
- Preserves original compression formats (gz, xz, zst)
- Normalizes file ownership to root:root
- Use `--verify` to validate the package after creation (recommended)

---

### deb-session-insert.sh

Inserts one or more files into the package.

**Usage:**
```bash
./deb-session-insert.sh [-d] <session-dir> <dest-path> <source-file> [<source-file2> ...]
```

**Examples:**
```bash
# Insert multiple files into a directory (trailing / indicates directory)
./deb-session-insert.sh ./my-session /var/lib/coda/ ledger1.tar.gz ledger2.tar.gz

# Insert with explicit directory flag
./deb-session-insert.sh -d ./my-session /var/lib/coda ledger1.tar.gz ledger2.tar.gz

# Insert a single file with specific name
./deb-session-insert.sh ./my-session /var/lib/coda/devnet.json ./new-config.json

# Insert all tarballs from a directory using glob
./deb-session-insert.sh ./my-session /var/lib/coda/ ./ledgers/*.tar.gz
```

**Notes:**
- Use `-d` flag or trailing `/` to treat destination as a directory
- Files keep their original names when inserted into a directory
- Destination directories are created automatically
- File permissions and attributes are preserved

---

### deb-session-replace.sh

Replaces existing files in the package with a new file.

**Usage:**
```bash
./deb-session-replace.sh <session-dir> <path-in-package> <replacement-file>
```

**Examples:**
```bash
# Replace a specific file
./deb-session-replace.sh ./my-session /var/lib/coda/config.json new-config.json

# Replace all files matching a pattern
./deb-session-replace.sh ./my-session "/var/lib/coda/config_*.json" new-config.json

# Replace configuration in /etc
./deb-session-replace.sh ./my-session /etc/mina/genesis_ledger.json new-ledger.json
```

**Notes:**
- Supports wildcard patterns (e.g., `config_*.json`)
- All matching files will be replaced with the same replacement file
- File permissions are set to 0644

---

### deb-session-remove.sh

Removes files matching a pattern from the package.

**Usage:**
```bash
./deb-session-remove.sh <session-dir> <path-pattern>
```

**Examples:**
```bash
# Remove a specific file
./deb-session-remove.sh ./my-session /var/lib/coda/devnet.json

# Remove all files matching a pattern
./deb-session-remove.sh ./my-session "/var/lib/coda/config_*.json"

# Remove all files in a directory
./deb-session-remove.sh ./my-session "/var/lib/coda/old_configs/*"

# Remove all .log files recursively (requires Bash 4.0+)
./deb-session-remove.sh ./my-session "/var/log/mina/**/*.log"
```

**Notes:**
- Supports glob patterns including `**` for recursive matching (Bash 4.0+)
- Only files are removed, not directories
- Removed files cannot be recovered from the session

---

### deb-session-move.sh

Moves or renames a file within the package.

**Usage:**
```bash
./deb-session-move.sh <session-dir> <source-path> <dest-path>
```

**Examples:**
```bash
# Rename a file
./deb-session-move.sh ./my-session /var/lib/coda/devnet.json /var/lib/coda/devnet.old.json

# Move a file to a different directory
./deb-session-move.sh ./my-session /var/lib/coda/config.json /etc/mina/config.json

# Create a backup
./deb-session-move.sh ./my-session /etc/mina/genesis.json /etc/mina/genesis.backup.json
```

**Notes:**
- Both paths should be absolute as they appear when package is installed
- Source file must exist
- Destination directory will be created if it doesn't exist

---

### deb-session-rename-package.sh

Renames the Debian package by updating the Package field in the control file.

**Usage:**
```bash
./deb-session-rename-package.sh <session-dir> <new-package-name>
```

**Examples:**
```bash
# Add hardfork suffix
./deb-session-rename-package.sh ./my-session mina-devnet-hardfork

# Rename for testing
./deb-session-rename-package.sh ./my-session mina-devnet-testing

# Create variant package
./deb-session-rename-package.sh ./my-session mina-mainnet-berkeley
```

**Notes:**
- Only modifies the Package field in the control file
- Version, architecture, and all other metadata remain unchanged
- Package name must follow Debian naming conventions:
  - Start with lowercase letter or digit
  - Contain only lowercase letters, digits, plus (+), minus (-), and dots (.)

---

## Manual Modifications (Advanced)

For advanced users who prefer direct control, you can work directly with the unpacked files using standard shell utilities instead of the helper scripts.

### Working Directly in the Session Directory

```bash
# 1. Open the session
./deb-session-open.sh mina-devnet_1.0_amd64.deb ./my-session

# 2. Navigate to the data directory
cd ./my-session/data

# 3. Use standard shell utilities
# Insert files (use cp)
cp /path/to/ledger.tar.gz ./var/lib/coda/
cp /path/to/config.json ./etc/mina/

# Replace files (use cp to overwrite)
cp /path/to/new-config.json ./var/lib/coda/config.json

# Move/rename files (use mv)
mv ./var/lib/coda/old.json ./var/lib/coda/new.json

# Remove files (use rm)
rm ./var/lib/coda/unwanted.txt
rm ./var/lib/coda/config_*.json  # Remove with wildcard

# 4. Modify control files if needed
cd ../control
vim control  # Edit Package name, Version, etc.

# 5. Return to parent directory and save
cd ../..
./deb-session-save.sh ./my-session output.deb --verify
```

### Manual Approach Example: Creating a Hardfork Package

```bash
#!/bin/bash
set -e

# Open session
./deb-session-open.sh mina-devnet_3.3.0_amd64.deb ./hardfork

cd ./hardfork/data

# Replace config files using standard cp
cp /path/to/hardfork-config.json ./var/lib/coda/config_devnet.json

# Insert new genesis ledger
cp /path/to/hardfork-ledger.tar.gz ./var/lib/coda/

# Remove old files
rm -f ./var/lib/coda/old_*.json

cd ../control

# Rename package by editing control file directly
sed -i 's/^Package: mina-devnet$/Package: mina-devnet-hardfork/' control

cd ../..

# Save the modified package
./deb-session-save.sh ./hardfork mina-devnet-hardfork_3.3.0_amd64.deb --verify
```

### Important Notes for Manual Modifications

**Path Handling:**
- Work from inside `session/data/` directory
- Use **relative paths** (e.g., `./var/lib/coda/file.txt`)
- **Do NOT use absolute paths** with leading `/` when using shell utilities
- Package paths like `/var/lib/coda/file.txt` become `./var/lib/coda/file.txt` in the session

**Safety Considerations:**
- Stay within the `session/data/` directory to avoid modifying system files
- Be careful with wildcards (`rm *.txt`) - they operate on session files, not your system
- The helper scripts include built-in validation; manual approach requires more care
- Test in a temporary session first if you're unsure

**When to Use Manual Approach:**
- You need complex file operations not covered by helper scripts
- You're comfortable with bash and prefer direct control
- You want to use advanced shell features (find, xargs, etc.)
- You need to batch process many files efficiently

**When to Use Helper Scripts:**
- You want automatic path validation and security checks
- You prefer clear, documented operations
- You're less familiar with bash utilities
- You want verification that operations completed successfully

## Common Use Cases

### Creating a Hardfork Package

```bash
#!/bin/bash
set -e

# Open the original package
./deb-session-open.sh mina-devnet_3.3.0_amd64.deb ./hardfork-session

# Replace genesis ledger
./deb-session-replace.sh ./hardfork-session \
  /var/lib/coda/config_*.json \
  ./hardfork-config.json

# Insert new genesis ledger
./deb-session-insert.sh ./hardfork-session \
  /var/lib/coda/ \
  ./hardfork-ledger.tar.gz

# Rename the package
./deb-session-rename-package.sh ./hardfork-session mina-devnet-hardfork

# Save the modified package
./deb-session-save.sh ./hardfork-session \
  mina-devnet-hardfork_3.3.0_amd64.deb \
  --verify

echo "Hardfork package created: mina-devnet-hardfork_3.3.0_amd64.deb"
```

### Updating Configuration Files

```bash
#!/bin/bash
set -e

# Open package
./deb-session-open.sh mina-mainnet_3.3.0_amd64.deb ./config-update

# Replace multiple config files
./deb-session-replace.sh ./config-update /etc/mina/daemon.json new-daemon-config.json
./deb-session-replace.sh ./config-update /etc/mina/peers.txt new-peers.txt

# Save package
./deb-session-save.sh ./config-update mina-mainnet-updated_3.3.0_amd64.deb --verify
```

### Creating a Test Package with Modified Binaries

```bash
#!/bin/bash
set -e

# Open package
./deb-session-open.sh mina-devnet_3.3.0_amd64.deb ./test-session

# Replace the main binary
./deb-session-replace.sh ./test-session /usr/local/bin/mina ./patched-mina

# Rename for testing
./deb-session-rename-package.sh ./test-session mina-devnet-test

# Save
./deb-session-save.sh ./test-session mina-devnet-test_3.3.0_amd64.deb --verify
```

### Cleaning Up Old Files

```bash
#!/bin/bash
set -e

# Open package
./deb-session-open.sh mina-devnet_3.3.0_amd64.deb ./cleanup-session

# Remove old log files
./deb-session-remove.sh ./cleanup-session "/var/log/mina/**/*.log"

# Remove old configuration backups
./deb-session-remove.sh ./cleanup-session "/etc/mina/*.backup"

# Save cleaned package
./deb-session-save.sh ./cleanup-session mina-devnet-clean_3.3.0_amd64.deb --verify
```

## Security Features

All scripts include security protections:

- **Directory Traversal Protection**: Paths with `..` sequences are detected and rejected
- **Symlink Protection**: Session directory cannot be a symlink
- **Path Validation**: All paths are normalized and validated to stay within session directory
- **Safe Defaults**: Scripts use `set -eux -o pipefail` for error handling

## Requirements

- Bash 4.0+ (for globstar support in removal operations)
- Standard Debian tools: `dpkg-deb`, `ar`, `tar`
- Compression tools: `gzip`, `xz`, `zstd` (depending on package compression)

## Testing

Run the test suite to verify all scripts work correctly:

```bash
./tests/run-deb-session-tests.sh
```

The test suite covers:
- Opening and closing sessions
- File insertion (directory and file targets)
- File replacement with wildcards
- File removal with patterns
- File moving/renaming
- Package renaming
- Session verification

## Troubleshooting

### Error: Session directory not found

Make sure you've opened a session first using `deb-session-open.sh`.

### Error: Path escapes session data directory

This is a security protection. Ensure your paths don't contain `..` sequences or other escape attempts.

### Error: No files found matching pattern

Check that:
- The path is absolute (starts with `/`)
- The pattern matches actual files in the package
- You're using the correct wildcard syntax

### Compression errors

Ensure you have the required compression tools installed:
```bash
# For gzip
sudo apt-get install gzip

# For xz
sudo apt-get install xz-utils

# For zstd
sudo apt-get install zstd
```