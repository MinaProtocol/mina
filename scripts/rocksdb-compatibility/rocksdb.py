from cffi import FFI

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


def test(path):
    # --- Open existing DB ---
    options = rocksdb.rocksdb_options_create()
    rocksdb.rocksdb_options_set_create_if_missing(options, 0)  # do not create new DB
    err_ptr = ffi.new("char**")
    db = rocksdb.rocksdb_open(options, path, err_ptr)
    if err_ptr[0] != ffi.NULL:
        raise RuntimeError("Open error: " + ffi.string(err_ptr[0]).decode())
    rocksdb.rocksdb_options_destroy(options)

    # --- Create read options and iterator ---
    ropts = rocksdb.rocksdb_readoptions_create()
    iter_ = rocksdb.rocksdb_create_iterator(db, ropts)

    # --- Iterate over all keys ---
    rocksdb.rocksdb_iter_seek_to_first(iter_)
    for _ in range(10): 
        if not rocksdb.rocksdb_iter_valid(iter_)
        klen = ffi.new("size_t*")
        vlen = ffi.new("size_t*")

        key_ptr = rocksdb.rocksdb_iter_key(iter_, klen)
        val_ptr = rocksdb.rocksdb_iter_value(iter_, vlen)

        # Create buffer views without copying
        key_buf = ffi.buffer(key_ptr, klen[0])
        val_buf = ffi.buffer(val_ptr, vlen[0])

        # key_buf and val_buf behave like bytes, e.g.,
        print(f"Found KV-pair: {key_buf[:].hex()} -> {val_buf[:].hex()}")

        rocksdb.rocksdb_iter_next(iter_)

    # --- Cleanup ---
    rocksdb.rocksdb_iter_destroy(iter_)
    rocksdb.rocksdb_readoptions_destroy(ropts)
    rocksdb.rocksdb_close(db)
