use std::{
    collections::HashMap,
    fs::{File, OpenOptions},
    io::{BufReader, BufWriter, Seek, SeekFrom, Write},
    path::{Path, PathBuf},
};

use std::io::ErrorKind::{InvalidData, Other, UnexpectedEof};

use super::{
    batch::Batch,
    compression::{compress, decompress, MaybeCompressed},
    lock::LockedFile,
};

pub(super) type Key = Box<[u8]>;
pub(super) type Value = Box<[u8]>;
pub(super) type Offset = u64;

pub type Uuid = String;

const KEY_IS_COMPRESSED_BIT: u8 = 1 << 0;
const VALUE_IS_COMPRESSED_BIT: u8 = 1 << 1;
const IS_REMOVED_BIT: u8 = 1 << 2;

const BUFFER_DEFAULT_CAPACITY: usize = 4096;

const DATABASE_VERSION: u64 = 1;
const DATABASE_VERSION_NBYTES: usize = 8;

pub struct Database {
    uuid: Uuid,
    /// Index of keys to their values offset
    index: HashMap<Key, Offset>,
    /// Points to end of file
    current_file_offset: Offset,
    file: BufWriter<LockedFile>,
    /// Read buffer
    buffer: Vec<u8>,
    /// Filename of the inner file
    filename: PathBuf,
}

/// Compute crc32 of an entry
///
/// This is used to verify data corruption
fn compute_crc32(header: &EntryHeader, key_bytes: &[u8], value_bytes: &[u8]) -> u32 {
    let bool_to_byte = |b| if b { 1 } else { 0 };

    let is_removed = bool_to_byte(header.is_removed);
    let key_is_compressed = bool_to_byte(header.key_is_compressed);
    let value_is_compressed = bool_to_byte(header.value_is_compressed);

    let mut crc32: crc32fast::Hasher = Default::default();

    crc32.update(&header.key_length.to_le_bytes());
    crc32.update(&header.value_length.to_le_bytes());
    crc32.update(&[key_is_compressed, value_is_compressed, is_removed]);
    crc32.update(key_bytes);
    if !header.is_removed {
        crc32.update(value_bytes);
    };

    crc32.finalize()
}

/// Header for each entry in the database
#[derive(Debug)]
struct EntryHeader {
    key_length: u32,
    value_length: u64,
    key_is_compressed: bool,
    value_is_compressed: bool,
    is_removed: bool,
    crc32: u32,
}

impl EntryHeader {
    /// Number of bytes the `EntryHeader` occupies on disk
    pub const NBYTES: usize = 17;

    /// Returns key + value length
    fn entry_length(&self) -> std::io::Result<u64> {
        (self.key_length as u64)
            .checked_add(self.value_length)
            .ok_or_else(|| std::io::Error::from(InvalidData))
    }

    /// Returns the value offset of this entry
    fn compute_value_offset(&self, header_offset: Offset) -> Option<Offset> {
        header_offset
            .checked_add(self.key_length as u64)?
            .checked_add(EntryHeader::NBYTES as u64)
    }

    /// Convert this header to bytes
    fn to_bytes(&self) -> std::io::Result<[u8; Self::NBYTES]> {
        let set_bit = |cond, bit| if cond { bit } else { 0 };

        let mut bitflags = 0;
        bitflags |= set_bit(self.key_is_compressed, KEY_IS_COMPRESSED_BIT);
        bitflags |= set_bit(self.value_is_compressed, VALUE_IS_COMPRESSED_BIT);
        bitflags |= set_bit(self.is_removed, IS_REMOVED_BIT);

        let bytes = [0; Self::NBYTES];
        let mut bytes = std::io::Cursor::new(bytes);

        bytes.write_all(&self.key_length.to_le_bytes())?;
        bytes.write_all(&self.value_length.to_le_bytes())?;
        bytes.write_all(&[bitflags])?;
        bytes.write_all(&self.crc32.to_le_bytes())?;

        Ok(bytes.into_inner())
    }

    /// Build a `Header` from its entry (key and value)
    fn make(key: &MaybeCompressed, value: &Option<MaybeCompressed>) -> std::io::Result<Self> {
        let to_u64 = |n: usize| n.try_into().map_err(|_| std::io::Error::from(InvalidData));
        let to_u32 = |n: usize| n.try_into().map_err(|_| std::io::Error::from(InvalidData));

        let key_is_compressed = key.is_compressed();
        let key = key.as_ref();

        let value_is_compressed = value
            .as_ref()
            .map(|value| value.is_compressed())
            .unwrap_or(false);

        let key_length: u32 = to_u32(key.len())?;
        let value_length = match value.as_ref() {
            None => 0,
            Some(value) => to_u64(value.as_ref().len())?,
        };
        let is_removed = value.is_none();

        let mut header = EntryHeader {
            key_length,
            key_is_compressed,
            value_length,
            value_is_compressed,
            is_removed,
            crc32: 0, // Set with correct value below
        };

        let crc32 = compute_crc32(
            &header,
            key,
            value.as_ref().map(AsRef::as_ref).unwrap_or(&[]),
        );
        header.crc32 = crc32;

        Ok(header)
    }

    /// Reads a header from a slice of bytes
    ///
    /// Returns an error when the slice is too small
    fn read(bytes: &[u8]) -> std::io::Result<Self> {
        if bytes.len() < Self::NBYTES {
            return Err(UnexpectedEof.into());
        }

        let key_length = read_u32(bytes)?;
        let value_length = read_u64(&bytes[4..])?;
        let bitflags = read_u8(&bytes[12..])?;
        let crc32 = read_u32(&bytes[13..])?;

        let key_is_compressed = (bitflags & KEY_IS_COMPRESSED_BIT) != 0;
        let value_is_compressed = (bitflags & VALUE_IS_COMPRESSED_BIT) != 0;
        let is_removed = (bitflags & IS_REMOVED_BIT) != 0;

        Ok(Self {
            key_length,
            key_is_compressed,
            value_length,
            value_is_compressed,
            is_removed,
            crc32,
        })
    }

    /// Returns an error when the checksum doesn't match
    fn verify_checksum(&self, key_bytes: &[u8], value_bytes: &[u8]) -> std::io::Result<()> {
        let crc32 = compute_crc32(self, key_bytes, value_bytes);

        if crc32 != self.crc32 {
            return Err(InvalidData.into());
        }

        Ok(())
    }
}

fn next_uuid() -> Uuid {
    uuid::Uuid::new_v4().to_string()
}

fn read_u64(slice: &[u8]) -> std::io::Result<u64> {
    slice
        .get(..8)
        .and_then(|slice: &[u8]| slice.try_into().ok())
        .map(u64::from_le_bytes)
        .ok_or_else(|| UnexpectedEof.into())
}

fn read_u32(slice: &[u8]) -> std::io::Result<u32> {
    slice
        .get(..4)
        .and_then(|slice: &[u8]| slice.try_into().ok())
        .map(u32::from_le_bytes)
        .ok_or_else(|| UnexpectedEof.into())
}

fn read_u8(slice: &[u8]) -> std::io::Result<u8> {
    slice
        .get(..1)
        .and_then(|slice: &[u8]| slice.try_into().ok())
        .map(u8::from_le_bytes)
        .ok_or_else(|| UnexpectedEof.into())
}

fn ensure_buffer_length(buffer: &mut Vec<u8>, length: usize) {
    if buffer.len() < length {
        buffer.resize(length, 0)
    }
}

#[cfg(unix)]
fn read_exact_at(file: &mut File, buffer: &mut [u8], offset: Offset) -> std::io::Result<()> {
    use std::os::unix::prelude::FileExt;

    file.read_exact_at(buffer, offset)
}

#[cfg(not(unix))]
fn read_exact_at(file: &mut File, buffer: &mut [u8], offset: Offset) -> std::io::Result<()> {
    use std::io::Read;

    file.seek(SeekFrom::Start(offset))?;
    file.read_exact(buffer)
}

enum CreateMode {
    Regular,
    Temporary,
}

impl Database {
    /// Creates a new instance of the database at the specified directory.
    /// If the directory contains an existing database, its content will be loaded.
    ///
    /// # Arguments
    ///
    /// * `directory` - The path where the database will be created or opened.
    ///
    /// # Returns
    ///
    /// * `Result<Self>` - Returns an instance of the database if successful, otherwise
    ///    returns an error.
    ///
    /// # Errors
    ///
    /// This method will return an error in the following cases:
    ///
    ///   * Unable to open or create the directory.
    ///   * Another process is already using the database.
    ///   * The database is corrupted (when the path contains an existing database).
    ///   * The database version is incompatible
    ///
    pub fn create(directory: impl AsRef<Path>) -> std::io::Result<Self> {
        Self::create_impl(directory, CreateMode::Regular)
    }

    fn create_impl(directory: impl AsRef<Path>, mode: CreateMode) -> std::io::Result<Self> {
        let directory = directory.as_ref();

        let filename = directory.join(match mode {
            CreateMode::Regular => "db",
            CreateMode::Temporary => "db_tmp",
        });

        if filename.try_exists()? {
            if let CreateMode::Temporary = mode {
                std::fs::remove_file(&filename)?;
            } else {
                return Self::reload(filename);
            }
        }

        if !directory.try_exists()? {
            std::fs::create_dir_all(directory)?;
        }

        let mut file = LockedFile::try_open_exclusively(
            &filename,
            OpenOptions::new()
                .read(true)
                .write(true)
                .append(true)
                .create_new(true),
        )?;

        file.write_all(&DATABASE_VERSION.to_le_bytes())?;

        Ok(Self {
            uuid: next_uuid(),
            index: HashMap::with_capacity(128),
            current_file_offset: DATABASE_VERSION_NBYTES as u64,
            file: BufWriter::with_capacity(4 * 1024 * 1024, file), // 4 MB
            buffer: Vec::with_capacity(BUFFER_DEFAULT_CAPACITY),
            filename,
        })
    }

    /// Reload the database at the specified path
    fn reload(filename: PathBuf) -> std::io::Result<Self> {
        use std::io::Read;

        let mut file = LockedFile::try_open_exclusively(
            &filename,
            OpenOptions::new()
                .read(true)
                .write(true)
                .append(true)
                .create_new(false),
        )?;

        let mut current_offset = 0;
        let eof = file.seek(SeekFrom::End(0))?;

        file.seek(SeekFrom::Start(0))?;

        let mut reader = BufReader::with_capacity(4 * 1024 * 1024, file); // 4 MB
        let mut bytes = vec![0; BUFFER_DEFAULT_CAPACITY];

        // Check if the database is the same version
        {
            reader.read_exact(&mut bytes[..DATABASE_VERSION_NBYTES])?;
            let database_version = read_u64(&bytes)?;
            if database_version != DATABASE_VERSION {
                return Err(std::io::Error::new(Other, "Incompatible database"));
            }
            current_offset += DATABASE_VERSION_NBYTES as u64;
        }

        let mut index = HashMap::with_capacity(256);

        while current_offset < eof {
            let header_offset = current_offset;

            ensure_buffer_length(&mut bytes, EntryHeader::NBYTES);
            reader.read_exact(&mut bytes[..EntryHeader::NBYTES])?;

            let header = EntryHeader::read(&bytes)?;
            let entry_length = header.entry_length()? as usize;
            let key_length = header.key_length as usize;

            ensure_buffer_length(&mut bytes, entry_length);
            reader.read_exact(&mut bytes[..entry_length])?;

            ensure_buffer_length(&mut bytes, entry_length);
            let (key_bytes, value_bytes) = bytes[..entry_length].split_at(key_length);

            header.verify_checksum(key_bytes, value_bytes)?;

            let key = decompress(key_bytes, header.key_is_compressed)?;

            if header.is_removed {
                index.remove(&key);
            } else {
                index.insert(key, header_offset);
            }

            current_offset += (EntryHeader::NBYTES + entry_length) as u64;
        }

        if eof != current_offset {
            return Err(UnexpectedEof.into());
        }

        Ok(Self {
            uuid: next_uuid(),
            index,
            current_file_offset: eof,
            file: BufWriter::with_capacity(4 * 1024 * 1024, reader.into_inner()), // 4 MB
            buffer: Vec::with_capacity(BUFFER_DEFAULT_CAPACITY),
            filename,
        })
    }

    /// Retrieves the UUID of the current database instance.
    ///
    /// # Returns
    ///
    /// * `&Uuid` - Returns a reference to the UUID of the instance.
    pub fn get_uuid(&self) -> &Uuid {
        &self.uuid
    }

    /// Closes the current database instance.
    ///
    /// Any usage of this database after this call will return an error.
    pub fn close(&self) {
        // NOTE: `close` is actually implemented at the ffi level, where `Self` is dropped
    }

    fn read_header(&mut self, header_offset: Offset) -> std::io::Result<EntryHeader> {
        ensure_buffer_length(&mut self.buffer, EntryHeader::NBYTES);
        read_exact_at(
            self.file.get_mut(),
            &mut self.buffer[..EntryHeader::NBYTES],
            header_offset,
        )?;

        EntryHeader::read(&self.buffer)
    }

    fn read_value(&mut self, offset: Offset, length: usize) -> std::io::Result<&[u8]> {
        ensure_buffer_length(&mut self.buffer, length);
        read_exact_at(self.file.get_mut(), &mut self.buffer[..length], offset)?;

        Ok(&self.buffer[..length])
    }

    /// Retrieves the value associated with a given key.
    ///
    /// # Arguments
    ///
    /// * `key` - Bytes representing the key to fetch the value of.
    ///
    /// # Returns
    ///
    /// * `Result<Option<Box<[u8]>>>` - Returns an optional values if the key exists;
    ///    otherwise, None. Returns an error if something goes wrong.
    pub fn get(&mut self, key: &[u8]) -> std::io::Result<Option<Value>> {
        // Note: `&mut self` is required for `File::seek`

        let header_offset = match self.index.get(key).copied() {
            Some(header_offset) => header_offset,
            None => return Ok(None),
        };

        let header = self.read_header(header_offset)?;

        let value_offset = header
            .compute_value_offset(header_offset)
            .ok_or_else(|| std::io::Error::from(InvalidData))?;
        let value_length = header.value_length as usize;

        let value = self.read_value(value_offset, value_length)?;

        decompress(value, header.value_is_compressed).map(Some)
    }

    fn set_impl(&mut self, key: Key, value: Option<Value>) -> std::io::Result<()> {
        let is_removed = value.is_none();

        let compressed_key = compress(&key)?;
        let compressed_value = match value.as_ref() {
            Some(value) => Some(compress(value)?),
            None => None,
        };

        let header = EntryHeader::make(&compressed_key, &compressed_value)?;
        let header_offset = self.current_file_offset;

        self.file.write_all(&header.to_bytes()?)?;
        self.file.write_all(compressed_key.as_ref())?;
        if let Some(value) = compressed_value.as_ref() {
            self.file.write_all(value.as_ref())?;
        };

        let buffer_len = EntryHeader::NBYTES as u64 + header.entry_length()?;
        self.current_file_offset += buffer_len;

        // Update index
        if is_removed {
            self.index.remove(&key);
        } else {
            self.index.insert(key, header_offset);
        }

        Ok(())
    }

    /// Adds or updates an entry (key-value pair) in the database.
    ///
    /// # Arguments
    ///
    /// * `key` - Bytes representing the key to store.
    /// * `value` - Bytes representing the value to store.
    ///
    /// # Returns
    ///
    /// * `Result<()>` - Returns () if successful, otherwise returns an error.
    pub fn set(&mut self, key: Key, value: Value) -> std::io::Result<()> {
        self.set_impl(key, Some(value))?;
        self.flush()?;
        Ok(())
    }

    /// Processes multiple entries (key-value pairs) to set and keys to remove in
    /// a single batch operation.
    ///
    /// # Arguments
    ///
    /// * `key_data_pairs` - An iterable of key-value pairs to add or update.
    /// * `remove_keys` - An iterable of keys to remove from the database.
    ///
    /// # Returns
    ///
    /// * `Result<()>` - Returns () if successful, otherwise returns an error.
    pub fn set_batch<KV, R>(&mut self, key_data_pairs: KV, remove_keys: R) -> std::io::Result<()>
    where
        KV: IntoIterator<Item = (Key, Value)>,
        R: IntoIterator<Item = Key>,
    {
        for (key, value) in key_data_pairs {
            self.set_impl(key, Some(value))?;
        }

        for key in remove_keys {
            self.set_impl(key, None)? // empty value
        }

        self.flush()?;

        Ok(())
    }

    /// Fetches a batch of values for the given keys.
    ///
    /// # Arguments
    ///
    /// * `keys` - An iterable of keys to fetch the values of
    ///
    /// # Returns
    ///
    /// * `Result<Vec<Option<Box<[u8]>>>>` - Returns a vector of optional values
    ///    corresponding to each key; if a key is not found, returns None.
    pub fn get_batch<K>(&mut self, keys: K) -> std::io::Result<Vec<Option<Value>>>
    where
        K: IntoIterator<Item = Key>,
    {
        keys.into_iter().map(|key| self.get(&key)).collect()
    }

    /// Creates a new checkpoint, saving a consistent snapshot of the
    /// current state of the database.
    ///
    /// # Arguments
    ///
    /// * `directory` - The path where the checkpoint files will be created.
    ///
    /// # Returns
    ///
    /// * `Result<()>` - Returns () if checkpoint creation is successful,
    ///   otherwise returns an error.
    pub fn make_checkpoint(&mut self, directory: impl AsRef<Path>) -> std::io::Result<()> {
        self.create_checkpoint(directory.as_ref())?;
        Ok(())
    }

    /// Creates a new checkpoint, and instantiates a new database from it.
    ///
    /// # Arguments
    ///
    /// * `directory` - The path where the checkpoint files will be created.
    ///
    /// # Returns
    ///
    /// * `Result<Self>` - Returns a new instance of the database if successful,
    ///   otherwise returns an error.
    pub fn create_checkpoint(&mut self, directory: impl AsRef<Path>) -> std::io::Result<Self> {
        let mut checkpoint = Self::create(directory.as_ref())?;

        let keys: Vec<Key> = self.index.keys().cloned().collect();

        for key in keys {
            let value = self.get(&key)?;
            checkpoint.set_impl(key, value)?;
        }

        checkpoint.flush()?;

        Ok(checkpoint)
    }

    /// Flush writes buffer to fs and call `fsync`
    fn flush(&mut self) -> std::io::Result<()> {
        self.file.flush()?;
        self.file.get_ref().sync_all()
    }

    fn remove_impl(&mut self, key: Key) -> std::io::Result<()> {
        self.set_impl(key, None) // empty value
    }

    /// Removes a key-value pair from the database.
    ///
    /// # Arguments
    ///
    /// * `key` - Bytes representing the key to remove.
    ///
    /// # Returns
    ///
    /// * `Result<()>` - Returns () if the key is removed successfully,
    ///   otherwise returns an error.
    pub fn remove(&mut self, key: Key) -> std::io::Result<()> {
        self.remove_impl(key)?;
        self.flush()
    }

    /// Retrieves all entries (key-value pairs) from the database.
    ///
    /// # Returns
    ///
    /// * `Result<Vec<(Box<[u8]>, Box<[u8]>)>>` - Returns a vector containing
    ///   all key-value pairs as boxed byte arrays. Returns an error if retrieval fails.
    pub fn to_alist(&mut self) -> std::io::Result<Vec<(Key, Value)>> {
        let keys: Vec<Key> = self.index.keys().cloned().collect();

        keys.into_iter()
            .map(|key| {
                Ok((
                    key.clone(),
                    self.get(&key)?
                        .ok_or_else(|| std::io::Error::from(InvalidData))?,
                ))
            })
            .collect()
    }

    /// Processes a pre-built batch of operations, effectively running the batch on the database.
    ///
    /// # Arguments
    ///
    /// * `batch` - A mutable reference to a `Batch` struct containing the operations to execute.
    ///
    /// # Returns
    ///
    /// * `Result<()>` - Returns () if the batch is executed successfully,
    ///   otherwise returns an error.
    pub fn run_batch(&mut self, batch: &mut Batch) -> std::io::Result<()> {
        use super::batch::Action::{Remove, Set};

        for action in batch.take() {
            match action {
                Set(key, value) => self.set_impl(key, Some(value))?,
                Remove(key) => self.remove_impl(key)?,
            }
        }

        self.flush()
    }

    /// Triggers garbage collection for the database, cleaning up obsolete
    /// data and potentially freeing up storage space.
    ///
    /// # Returns
    ///
    /// * `Result<()>` - Returns () if garbage collection is successful,
    ///   otherwise returns an error.
    pub fn gc(&mut self) -> std::io::Result<()> {
        let directory = self.filename.parent().unwrap();
        let mut new_db = Self::create_impl(directory, CreateMode::Temporary)?;

        let keys: Vec<Key> = self.index.keys().cloned().collect();

        for key in keys {
            let value = self.get(&key)?;
            new_db.set_impl(key, value)?;
        }

        new_db.flush()?;

        exchange_file_atomically(&self.filename, &new_db.filename)?;

        new_db.filename = self.filename.clone();
        new_db.uuid = self.uuid.clone();

        *self = new_db;

        Ok(())
    }
}

#[cfg(not(target_os = "linux"))]
fn exchange_file_atomically(db_path: &Path, tmp_path: &Path) -> std::io::Result<()> {
    std::fs::rename(tmp_path, db_path)
}

// `renameat2` is a Linux syscall
#[cfg(target_os = "linux")]
fn exchange_file_atomically(db_path: &Path, tmp_path: &Path) -> std::io::Result<()> {
    use std::os::unix::prelude::OsStrExt;

    let cstr_db_path = std::ffi::CString::new(db_path.as_os_str().as_bytes())?;
    let cstr_db_path = cstr_db_path.as_ptr();

    let cstr_tmp_path = std::ffi::CString::new(tmp_path.as_os_str().as_bytes())?;
    let cstr_tmp_path = cstr_tmp_path.as_ptr();

    // Exchange `db_path` with `tmp_path` atomically
    let result = unsafe {
        libc::syscall(
            libc::SYS_renameat2,
            libc::AT_FDCWD,
            cstr_tmp_path,
            libc::AT_FDCWD,
            cstr_db_path,
            libc::RENAME_EXCHANGE,
        )
    };

    if result != 0 {
        let error = std::io::Error::last_os_error();
        return Err(error);
    }

    // Remove previous file
    std::fs::remove_file(tmp_path)?;

    Ok(())
}

#[cfg(test)]
mod tests {
    use rand::{Fill, Rng};
    use std::{
        path::PathBuf,
        sync::atomic::{AtomicUsize, Ordering::SeqCst},
    };

    use super::*;

    struct TempDir {
        path: PathBuf,
    }

    static DIRECTORY_NUMBER: AtomicUsize = AtomicUsize::new(0);

    impl TempDir {
        fn new() -> Self {
            let next = || DIRECTORY_NUMBER.fetch_add(1, SeqCst);

            let mut number = next();

            let path = loop {
                let directory = format!("/tmp/mina-keyvaluedb-test-{}", number);
                let path = PathBuf::from(directory);

                if !path.exists() {
                    break path;
                }
                number = next();
            };

            std::fs::create_dir_all(&path).unwrap();

            Self { path }
        }

        fn as_path(&self) -> &Path {
            &self.path
        }
    }

    impl Drop for TempDir {
        fn drop(&mut self) {
            if let Err(e) = std::fs::remove_dir_all(&self.path) {
                eprintln!(
                    "[test] Failed to remove temporary directory {:?}: {:?}",
                    self.path, e
                );
            }
        }
    }

    fn key(s: &str) -> Key {
        Box::<[u8]>::from(s.as_bytes())
    }

    fn value(s: &str) -> Value {
        Box::<[u8]>::from(s.as_bytes())
        // s.as_bytes().to_vec()
    }

    fn sorted_vec(mut vec: Vec<(Key, Value)>) -> Vec<(Key, Value)> {
        vec.sort_by_cached_key(|(k, _)| k.clone());
        vec
    }

    #[test]
    fn test_empty_value() {
        let db_dir = TempDir::new();

        let mut db = Database::create(db_dir.as_path()).unwrap();

        db.set(key("a"), value("abc")).unwrap();
        let v = db.get(&key("a")).unwrap().unwrap();
        assert_eq!(v, value("abc"));

        db.set(key("a"), value("")).unwrap();
        let v = db.get(&key("a")).unwrap().unwrap();
        assert_eq!(v, value(""));
    }

    #[test]
    fn test_persistent_removed_value() {
        let db_dir = TempDir::new();

        let first = {
            let mut db = Database::create(db_dir.as_path()).unwrap();

            db.set(key("abcd"), value("abcd")).unwrap();

            db.set(key("a"), value("abc")).unwrap();
            let v = db.get(&key("a")).unwrap().unwrap();
            assert_eq!(v, value("abc"));

            db.set(key("a"), value("")).unwrap();
            let v = db.get(&key("a")).unwrap().unwrap();
            assert_eq!(v, value(""));

            db.remove(key("a")).unwrap();
            let v = db.get(&key("a")).unwrap();
            assert!(v.is_none());

            sorted_vec(db.to_alist().unwrap())
        };

        assert_eq!(first.len(), 1);

        let second = {
            let mut db = Database::create(db_dir.as_path()).unwrap();
            sorted_vec(db.to_alist().unwrap())
        };

        assert_eq!(first, second);
    }

    #[test]
    fn test_get_batch() {
        let db_dir = TempDir::new();

        let mut db = Database::create(db_dir.as_path()).unwrap();

        let (key1, key2, key3): (Key, Key, Key) = (
            "a".as_bytes().into(),
            "b".as_bytes().into(),
            "c".as_bytes().into(),
        );
        let data: Value = value("test");

        db.set(key1.clone(), data.clone()).unwrap();
        db.set(key3.clone(), data.clone()).unwrap();

        let res = db.get_batch([key1, key2, key3]).unwrap();

        assert_eq!(res[0].as_ref().unwrap(), &data);
        assert!(res[1].is_none());
        assert_eq!(res[2].as_ref().unwrap(), &data);
    }

    fn make_random_key_values(nkeys: usize) -> Vec<(Key, Value)> {
        let mut rng = rand::thread_rng();

        let mut key = [0; 32];

        let mut key_values = HashMap::with_capacity(nkeys);

        while key_values.len() < nkeys {
            let key_length: usize = rng.gen_range(2..=32);
            key[..key_length].try_fill(&mut rng).unwrap();

            let i = Box::<[u8]>::from(key_values.len().to_ne_bytes());
            key_values.insert(Box::<[u8]>::from(&key[..key_length]), i);
        }

        let mut key_values: Vec<(Key, Value)> = key_values.into_iter().collect();
        key_values.sort_by_cached_key(|(k, _)| k.clone());
        key_values
    }

    #[test]
    fn test_persistent() {
        let db_dir = TempDir::new();

        let mut rng = rand::thread_rng();
        let nkeys: usize = rng.gen_range(1000..2000);
        let sorted = make_random_key_values(nkeys);

        let first = {
            let mut db = Database::create(db_dir.as_path()).unwrap();
            db.set_batch(sorted.clone(), []).unwrap();
            let mut alist = db.to_alist().unwrap();
            alist.sort_by_cached_key(|(k, _)| k.clone());
            alist
        };

        assert_eq!(sorted, first);

        let second = {
            let mut db = Database::create(db_dir.as_path()).unwrap();
            let mut alist = db.to_alist().unwrap();
            alist.sort_by_cached_key(|(k, _)| k.clone());
            alist
        };

        assert_eq!(first, second);
    }

    #[test]
    fn test_gc() {
        let db_dir = TempDir::new();

        let mut rng = rand::thread_rng();
        let nkeys: usize = rng.gen_range(1000..2000);
        let sorted = make_random_key_values(nkeys);

        let mut db = Database::create(db_dir.as_path()).unwrap();
        db.set_batch(sorted.clone(), []).unwrap();

        (10..50).for_each(|index| {
            db.remove(sorted[index].0.clone()).unwrap();
        });

        let offset = db.current_file_offset;

        let mut alist1 = db.to_alist().unwrap();
        alist1.sort_by_cached_key(|(k, _)| k.clone());

        db.gc().unwrap();
        assert!(offset > db.current_file_offset);

        let mut alist2 = db.to_alist().unwrap();
        alist2.sort_by_cached_key(|(k, _)| k.clone());
        assert_eq!(alist1, alist2);

        db.set(key("a"), value("b")).unwrap();
        assert_eq!(db.get(&key("a")).unwrap().unwrap(), value("b"));
    }

    #[test]
    fn test_to_alist() {
        let db_dir = TempDir::new();

        let mut rng = rand::thread_rng();

        let nkeys: usize = rng.gen_range(1000..2000);

        let sorted = make_random_key_values(nkeys);

        let mut db = Database::create(db_dir.as_path()).unwrap();

        db.set_batch(sorted.clone(), []).unwrap();

        let mut alist = db.to_alist().unwrap();
        alist.sort_by_cached_key(|(k, _)| k.clone());

        assert_eq!(sorted, alist);
    }

    #[test]
    fn test_checkpoint_read() {
        let db_dir = TempDir::new();

        let mut rng = rand::thread_rng();

        let nkeys: usize = rng.gen_range(1000..2000);

        let sorted = make_random_key_values(nkeys);

        let mut db_hashtbl: HashMap<_, _> = sorted.into_iter().collect();
        let mut cp_hashtbl: HashMap<_, _> = db_hashtbl.clone();

        let mut db = Database::create(db_dir.as_path()).unwrap();

        for (key, data) in &db_hashtbl {
            db.set(key.clone(), data.clone()).unwrap();
        }

        let cp_dir = TempDir::new();
        let mut cp = db.create_checkpoint(cp_dir.as_path()).unwrap();

        db_hashtbl.insert(key("db_key"), value("db_data"));
        cp_hashtbl.insert(key("cp_key"), value("cp_data"));

        db.set(key("db_key"), value("db_data")).unwrap();
        cp.set(key("cp_key"), value("cp_data")).unwrap();

        let db_sorted: Vec<_> = sorted_vec(db_hashtbl.into_iter().collect());
        let cp_sorted: Vec<_> = sorted_vec(cp_hashtbl.into_iter().collect());

        let db_alist = sorted_vec(db.to_alist().unwrap());
        let cp_alist = sorted_vec(cp.to_alist().unwrap());

        assert_eq!(db_sorted, db_alist);
        assert_eq!(cp_sorted, cp_alist);
    }
}
