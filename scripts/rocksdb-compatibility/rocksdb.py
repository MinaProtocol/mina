from cffi import FFI
from contextlib import contextmanager

ffi = FFI()

ffi.cdef("""
typedef struct rocksdb_t rocksdb_t;
typedef struct rocksdb_options_t rocksdb_options_t;
typedef struct rocksdb_readoptions_t rocksdb_readoptions_t;
typedef struct rocksdb_iterator_t rocksdb_iterator_t;

rocksdb_options_t* rocksdb_options_create(void);
void rocksdb_options_destroy(rocksdb_options_t*);
void rocksdb_options_set_create_if_missing(rocksdb_options_t*, unsigned char);

rocksdb_t* rocksdb_open(const rocksdb_options_t* options, const char* name, char** errptr);
void rocksdb_close(rocksdb_t* db);

rocksdb_readoptions_t* rocksdb_readoptions_create(void);
void rocksdb_readoptions_destroy(rocksdb_readoptions_t*);

rocksdb_iterator_t* rocksdb_create_iterator(rocksdb_t* db, const rocksdb_readoptions_t* options);
void rocksdb_iter_destroy(rocksdb_iterator_t* iter);
void rocksdb_iter_seek_to_first(rocksdb_iterator_t* iter);
unsigned char rocksdb_iter_valid(const rocksdb_iterator_t* iter);
void rocksdb_iter_next(rocksdb_iterator_t* iter);
const char* rocksdb_iter_key(const rocksdb_iterator_t* iter, size_t* klen);
const char* rocksdb_iter_value(const rocksdb_iterator_t* iter, size_t* vlen);
""")

# Load the library
rocksdb = ffi.dlopen("librocksdb.so")

@contextmanager
def rocksdb_options(create_if_missing=False):
    opts = rocksdb.rocksdb_options_create()
    rocksdb.rocksdb_options_set_create_if_missing(opts, int(create_if_missing))
    try:
        yield opts
    finally:
        rocksdb.rocksdb_options_destroy(opts)

@contextmanager
def open_db(path, options):
    err_ptr = ffi.new("char**")
    db = rocksdb.rocksdb_open(options, path.encode('utf-8'), err_ptr)
    if err_ptr[0] != ffi.NULL:
        raise RuntimeError("Open error: " + ffi.string(err_ptr[0]).decode())
    try:
        yield db
    finally:
        rocksdb.rocksdb_close(db)

@contextmanager
def read_iter(db):
    ropts = rocksdb.rocksdb_readoptions_create()
    iter_ = rocksdb.rocksdb_create_iterator(db, ropts)
    try:
        yield iter_
    finally:
        rocksdb.rocksdb_iter_destroy(iter_)
        rocksdb.rocksdb_readoptions_destroy(ropts)

def test(path, rounds):
    """
    Iterate over a RocksDB database and print key-value pairs in hexadecimal.

    Args:
        path (str): Path to the RocksDB database.
        rounds (int): Number of key-value pairs to read from the start of the database.

    Behavior:
        - Opens the database in read-only mode (does not create a new DB).
        - Uses a RocksDB iterator to traverse from the first key.
        - Prints each key-value pair as hexadecimal strings.
        - Stops early if the iterator reaches the end of the DB before 'rounds' entries.
    """
    with rocksdb_options(create_if_missing=False) as opts, open_db(path, opts) as db, read_iter(db) as it:
        rocksdb.rocksdb_iter_seek_to_first(it)
        for _ in range(rounds):
            if not rocksdb.rocksdb_iter_valid(it):
                break

            klen = ffi.new("size_t*")
            vlen = ffi.new("size_t*")
            key_ptr = rocksdb.rocksdb_iter_key(it, klen)
            val_ptr = rocksdb.rocksdb_iter_value(it, vlen)

            key_buf = ffi.buffer(key_ptr, klen[0])
            val_buf = ffi.buffer(val_ptr, vlen[0])
            print(f"Found KV-pair: {key_buf[:].hex()} -> {val_buf[:].hex()}")

            rocksdb.rocksdb_iter_next(it)
