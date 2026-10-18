# Disk Cache Deadlock Tests

This directory contains tests to reproduce and verify the LMDB deadlock issue that occurs when finalizers run during write operations.

## Test Overview

The tests demonstrate that:
- **LMDB cache**: Deadlocks when GC runs finalizers during write operations
- **Filesystem cache**: Does NOT deadlock under the same conditions

## Running the Tests

### Run all disk cache tests
```bash
dune runtest src/lib/disk_cache/
```

### Run just the deadlock tests
```bash
# Run both deadlock tests
dune runtest src/lib/disk_cache/test/

# LMDB deadlock test only
dune exec src/lib/disk_cache/test/test_lmdb_deadlock.exe

# Filesystem control test only
dune exec src/lib/disk_cache/test/test_filesystem_deadlock.exe
```

### Configuration via Environment Variables

- `CACHE_DEADLOCK_TEST_TIMEOUT`: Timeout in seconds (e.g., "5.0"). Default is 10 seconds if not set. Set to empty string ("") to disable timeout.
- `CACHE_DEADLOCK_TEST_DIR`: Custom directory for cache database. If not set, uses temporary directory.

Example:
```bash
# Run with 5 second timeout
CACHE_DEADLOCK_TEST_TIMEOUT=5.0 dune exec src/lib/disk_cache/test/test_lmdb_deadlock.exe

# Run without timeout (will hang if deadlock occurs)
CACHE_DEADLOCK_TEST_TIMEOUT="" dune exec src/lib/disk_cache/test/test_lmdb_deadlock.exe

# Run with custom directory
CACHE_DEADLOCK_TEST_DIR=/tmp/my-test dune runtest src/lib/disk_cache/test/
```

## Expected Behavior

### LMDB Test
When a deadlock is detected (with timeout set):
```
DEADLOCK DETECTED: Cache.put timed out after 5.0 seconds!
This indicates a deadlock in the cache implementation.
The finalizer likely tried to acquire a lock during GC.
```

### Filesystem Test
Should always pass:
```
Evil put completed successfully (no deadlock)

SUCCESS: Cache does NOT deadlock with finalizers.
```

## How It Works

The test creates a "evil" data structure that triggers garbage collection during serialization. This causes finalizers to run while a cache write operation is in progress:

1. Create a cache entry and hold a reference to it
2. Start a new cache write operation
3. During serialization, clear the reference and trigger GC
4. The finalizer attempts to remove the old entry from the cache
5. **LMDB**: Deadlocks trying to acquire write lock it already holds
6. **Filesystem**: Completes successfully (uses simple file deletion)

## File Structure

- `test_cache_deadlock.ml`: Shared test logic (library)
- `test_lmdb_deadlock.ml`: LMDB deadlock test
- `test_filesystem_deadlock.ml`: Filesystem control test
- `dune`: Test configuration
