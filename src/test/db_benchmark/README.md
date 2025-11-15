# Database Benchmark Suite

A comprehensive benchmark suite comparing four different database/storage implementations for key-value storage with 128KB values.

## Implementations Tested

1. **RocksDB** - LSM tree-based embedded database
2. **LMDB** - Memory-mapped B+ tree database  
3. **Single-file** - One file per key (filesystem-based)
4. **Multi-file** - One file per block, 125 keys per file

## Test Configuration

- **Keys per block**: 125
- **Value size**: 128 KB (131,072 bytes)
- **Warmup phase**: 800 blocks (100,000 keys, ~12.5 GB data)
- **Write benchmark**: Delete oldest block + Insert new block (steady state)
- **Read benchmark**: Random reads from 100,000 keys

## Usage

### Quick Start

```bash
# Run all benchmarks and generate report
./run_benchmarks.sh
```

This will:
1. Build the benchmark executable using dune
2. Run all benchmarks (write and read operations for each implementation)
3. Generate a detailed report in `benchmark_report.txt`

### Manual Build

```bash
# Build only
$HOME/work/shell dune build src/test/db_benchmark/db_benchmark.exe

# Run with custom options
./_build/default/test/db_benchmark/db_benchmark.exe -ascii -quota 30s
```

### Core_bench Options

The benchmark uses Core_bench which supports various options:

- `-ascii`: Plain text output (default in script)
- `-quota <time>`: How long to run each benchmark (e.g., `10s`, `1m`)
- `-samples <n>`: Number of samples to collect
- `-verbosity <level>`: Control output detail
- `-help`: Show all available options

## Output

### Report File

The `benchmark_report.txt` file contains:

1. **System Information**: CPU, memory, OS details
2. **Test Configuration**: Parameters and setup details
3. **Benchmark Results**: Timing and allocation data
4. **Interpretation Guide**: How to read the results

### Metrics Explained

- **Time/Run**: Average time per operation (lower is better)
- **mWd/Run**: Minor words allocated (GC pressure)
- **mjWd/Run**: Major words allocated
- **Prom/Run**: Promoted words
- **Percentage**: Relative performance vs baseline

## Implementation Details

### RocksDB (`rocksdb_impl.ml`)
- Uses `Rocksdb.Serializable.Make` with integer keys and string values
- LSM tree architecture, optimized for write-heavy workloads
- Automatic background compaction
- Batch writes: Iterates through key-value pairs in a block

### LMDB (`lmdb_impl.ml`)
- Uses `Lmdb_storage.Generic.Read_write` functor
- Memory-mapped files with B+ tree structure
- Initial map size: 256 MB (grows automatically as needed)
- Good for read-heavy workloads
- Batch writes: Iterates through key-value pairs in a block

### Single-file (`single_file_impl.ml`)
- Each key stored in separate file: `<key_id>.val`
- Simple filesystem operations
- High file descriptor usage
- Best for: Small datasets, simple requirements
- Batch writes: Creates one file per key in the block

### Multi-file (`multi_file_impl.ml`)
- One file per block: `<block_id>.block`
- Each file contains 125 keys (128KB × 125 = 16MB per file)
- **Efficient batch writes**: Concatenates all values in memory, writes once with `write_all`
- Reduces file count from 100,000 to 800
- Single write operation per block (no seeking needed)

## Common Module (`common.ml`)

Shared utilities and interfaces:

- `Database` module type: Interface all implementations must satisfy
- `Ops` module: Benchmark operations (write_block, delete_block, read_key)
- Configuration constants
- Temporary directory management

## Customization

To modify test parameters, edit `common.ml`:

```ocaml
let keys_per_block = 125        (* Keys per block *)
let value_size = 128 * 1024     (* 128 KB *)
let warmup_blocks = 800         (* Initial data *)
let steady_state_ops = 800      (* Write iterations *)
let random_read_count = 800000  (* Read iterations *)
```

## Performance Considerations

### Write Performance
- RocksDB: Sequential writes to WAL, batched compaction
- LMDB: In-place updates with copy-on-write
- Single-file: Many small file operations
- Multi-file: Fewer, larger file operations with seeks

### Read Performance
- RocksDB: May require multiple level lookups
- LMDB: Direct B+ tree lookup via mmap
- Single-file: One file open per read
- Multi-file: Seek within larger file

### Space Amplification
- RocksDB: Space amplification from LSM levels
- LMDB: Minimal space overhead, sparse files
- Single-file: Filesystem overhead per file
- Multi-file: Pre-allocated 16MB blocks

## Troubleshooting

### Build Failures

```bash
# Ensure you're using the special shell
$HOME/work/shell dune clean
$HOME/work/shell dune build src/test/db_benchmark
```

### Out of Disk Space

The benchmark writes ~25 GB during steady state (2x 12.5 GB for warmup + operations). Ensure adequate free space.

### Slow Performance

First run may be slower due to:
- OS page cache warming
- Filesystem allocation
- Database initialization

## Files

- `common.ml` - Shared types and utilities
- `rocksdb_impl.ml` - RocksDB implementation
- `lmdb_impl.ml` - LMDB implementation  
- `single_file_impl.ml` - Single-file-per-key implementation
- `multi_file_impl.ml` - Multi-key-per-file implementation
- `db_benchmark.ml` - Main benchmark runner
- `run_benchmarks.sh` - Convenience script
- `dune` - Build configuration

## Extending

To add a new implementation:

1. Create `your_impl.ml` implementing `Common.Database`
2. Add to `db_benchmark.ml` implementations list:
   ```ocaml
   let implementations = [
     ...
     (module Your_impl.Make());
   ]
   ```
3. Rebuild and run

## License

Same as the Mina project.
