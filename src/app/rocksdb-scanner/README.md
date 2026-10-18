## RocksDB Hex Utility

This OCaml tool provides a simple interface for exporting and importing RocksDB databases using a human-readable hex-encoded format. It is particularly useful for debugging, inspecting raw binary data, or migrating small-to-medium datasets between environments of incompatible RocksDB versions.

---

### Core Functionality

The utility operates on two primary modes: **Dump** and **Restore**.

#### 1. Dump (`dump`)
Scans an existing RocksDB instance and serializes all key-value pairs into a text file.
* **Format:** `[hex_key] : [hex_value]`
* **Mechanism:** Uses `Rocksdb.Database.to_alist` to pull the entire dataset into memory before writing to disk.
* **Safety:** Includes checks to ensure the source path is a valid directory before attempting to open the database.

#### 2. Restore (`restore`)
Reads a hex-encoded file and populates a RocksDB instance.
* **Batching:** To optimize performance, it uses a `chunk_size` of 256. It buffers records and writes them to RocksDB using `set_batch` rather than individual `set` operations.
* **Parsing:** Uses `Scanf` to pull hex strings from the source file and converts them back into `Bigstring` format.
* **Concurrency:** Leverages `Async` pipes to read the file line-by-line without blocking the main thread.

---

### Usage Guide

#### Command Line Interface

The tool is compiled as a single executable with two subcommands.

**To Export a Database:**
```bash
rocksdb_scanner dump --db-path /path/to/db --output-file dump.hex
```

**To Restore a Database:**
```bash
rocksdb_scanner.exe restore --input-file dump.hex --db-path /path/to/new_db
```
