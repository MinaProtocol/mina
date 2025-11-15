# Database Benchmark Suite

A comprehensive benchmark suite comparing four different database/storage implementations for key-value storage with fixed-size values.

## Benchmark description

Benchmark runs two test scenarios per implementation:

1. Write benchmark: Delete oldest block + Insert new block (steady state)
2. Read benchmark: Repeated read from random keys

Write benchmark measures pure write performance, without any read operations.
Read benchmark measures pure read performance, without any write operations.

## Implementations Tested

1. **RocksDB** - LSM tree-based embedded database
2. **LMDB** - Memory-mapped B+ tree database  
3. **Single-file** - One file per key (filesystem-based)
4. **Multi-file** - One file per block, 125 keys per file

## Default Test Configuration

- **Keys per block**: 125
- **Value size**: 128 KB (131,072 bytes)
- **Warmup phase**: 800 blocks (100,000 keys, ~12.5 GB data)
- **Write benchmark**: Delete oldest block + Insert new block (steady state)
- **Read benchmark**: Repeated read from random keys

## Usage

### Manual Build

```bash
# Build only
$HOME/work/shell dune build src/test/db_benchmark/db_benchmark.exe

# Run with custom options
./_build/default/test/db_benchmark/db_benchmark.exe -ascii -quota 30s
```

### Core_bench Options

The benchmark uses Core_bench which supports various options:

- `-ascii`: Plain text output
- `-quota <time>`: How long to run each benchmark (e.g., `10s`, `1m`)
- `-v`: Verbose output
- `-help`: Show all available options

## Output

### Report File

Output is printed to stdout in plain text format. It contains:

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

## Customization

To modify test parameters, provide environment variables:

- `KEYS_PER_BLOCK`: Number of keys per block
- `VALUE_SIZE`: Size of each value in bytes
- `WARMUP_BLOCKS`: Number of blocks to warmup with

## Troubleshooting

### Build Failures

```bash
# Ensure you're using the special shell
$HOME/work/shell dune clean
$HOME/work/shell dune build src/test/db_benchmark
```

### Out of Disk Space

The benchmark writes ~14 GB per run, with two runs per implementation (up to 120 GB total).
Ensure there is enough disk space before running the benchmark.