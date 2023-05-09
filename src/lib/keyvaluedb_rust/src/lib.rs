//! # Database
//!
//! Database is a lightweight, single append-only file, key-value store designed as an
//! alternative to RocksDB.
//!
//! ## Storage Format
//!
//! Each entry in the Database has the following structure:
//!
//! ```ignored
//! +------------+-----------+-----------+
//! |    HDR     |    KEY    |   VALUE   |
//! | (17 bytes) | (X bytes) | (X bytes) |
//! +------------+-----------+-----------+
//!       ^
//!       |
//!       |
//! +------------+--------------+-----------+------------+
//! | KEY_LENGTH | VALUE_LENGTH | BITFLAGS  |   CRC32    |
//! | (4 bytes)  | (8 bytes)    | (1 byte)  | (4 bytes)  |
//! +------------+--------------+-----------+------------+
//! ```
//!
//! Where:
//! - `HDR`: A 17 bytes header
//!   - `KEY_LENGTH`: Length of the key, stored in 4 bytes.
//!   - `VALUE_LENGTH`: Length of the value, stored in 8 bytes.
//!   - `BITFLAGS`: A 1 byte bitflags including:
//!      - `key_is_compressed`: A flag indicating if the key is compressed.
//!      - `value_is_compressed`: A flag indicating if the value is compressed.
//!      - `is_removed`: A flag indicating if the entry has been removed.
//!   - `CRC32`: The CRC32 checksum of the entry (including its header), stored in 4 bytes.
//! - `KEY`: The key data
//! - `VALUE`: The value data
//!
//! ## Example Usage
//!
//! Create an instance of MyDatabase:
//!
//! ```rust
//! # use keyvaluedb_rust::Database;
//! # fn usage() -> std::io::Result<()> {
//! # let k = |s: &str| Box::<[u8]>::from(s.as_bytes());
//! # let v = k;
//! let mut db = Database::create("/tmp/my_database")?;
//!
//! // Insert a key-value pair:
//! db.set(k("key1"), v("value1"))?;
//!
//! // Retrieve a value by key:
//! let result = db.get(&k("key1"))?;
//! assert_eq!(result, Some(v("value1")));
//! # Ok(())
//! # }
//! ```

pub mod batch;
pub(self) mod compression;
mod database;
mod ffi;
pub(self) mod lock;

pub use batch::Batch;
pub use database::*;
