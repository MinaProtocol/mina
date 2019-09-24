use byteorder::{LittleEndian, ReadBytesExt, WriteBytesExt};
use std::io::{self, Read, Write};

const MAX_SIZE: usize = 0x02000000;

struct CompactSize;

impl CompactSize {
    fn read<R: Read>(mut reader: R) -> io::Result<usize> {
        let flag = reader.read_u8()?;
        match if flag < 253 {
            Ok(flag as usize)
        } else if flag == 253 {
            match reader.read_u16::<LittleEndian>()? {
                n if n < 253 => Err(io::Error::new(
                    io::ErrorKind::InvalidInput,
                    "non-canonical CompactSize",
                )),
                n => Ok(n as usize),
            }
        } else if flag == 254 {
            match reader.read_u32::<LittleEndian>()? {
                n if n < 0x10000 => Err(io::Error::new(
                    io::ErrorKind::InvalidInput,
                    "non-canonical CompactSize",
                )),
                n => Ok(n as usize),
            }
        } else {
            match reader.read_u64::<LittleEndian>()? {
                n if n < 0x100000000 => Err(io::Error::new(
                    io::ErrorKind::InvalidInput,
                    "non-canonical CompactSize",
                )),
                n => Ok(n as usize),
            }
        }? {
            s if s > MAX_SIZE => Err(io::Error::new(
                io::ErrorKind::InvalidInput,
                "CompactSize too large",
            )),
            s => Ok(s),
        }
    }

    fn write<W: Write>(mut writer: W, size: usize) -> io::Result<()> {
        match size {
            s if s < 253 => writer.write_u8(s as u8),
            s if s <= 0xFFFF => {
                writer.write_u8(253)?;
                writer.write_u16::<LittleEndian>(s as u16)
            }
            s if s <= 0xFFFFFFFF => {
                writer.write_u8(254)?;
                writer.write_u32::<LittleEndian>(s as u32)
            }
            s => {
                writer.write_u8(255)?;
                writer.write_u64::<LittleEndian>(s as u64)
            }
        }
    }
}

pub struct Vector;

impl Vector {
    pub fn read<R: Read, E, F>(mut reader: R, func: F) -> io::Result<Vec<E>>
    where
        F: Fn(&mut R) -> io::Result<E>,
    {
        let count = CompactSize::read(&mut reader)?;
        (0..count).map(|_| func(&mut reader)).collect()
    }

    pub fn write<W: Write, E, F>(mut writer: W, vec: &[E], func: F) -> io::Result<()>
    where
        F: Fn(&mut W, &E) -> io::Result<()>,
    {
        CompactSize::write(&mut writer, vec.len())?;
        vec.iter().map(|e| func(&mut writer, e)).collect()
    }
}

pub struct Optional;

impl Optional {
    pub fn read<R: Read, T, F>(mut reader: R, func: F) -> io::Result<Option<T>>
    where
        F: Fn(&mut R) -> io::Result<T>,
    {
        match reader.read_u8()? {
            0 => Ok(None),
            1 => Ok(Some(func(&mut reader)?)),
            _ => Err(io::Error::new(
                io::ErrorKind::InvalidInput,
                "non-canonical Option<T>",
            )),
        }
    }

    pub fn write<W: Write, T, F>(mut writer: W, val: &Option<T>, func: F) -> io::Result<()>
    where
        F: Fn(&mut W, &T) -> io::Result<()>,
    {
        match val {
            None => writer.write_u8(0),
            Some(e) => {
                writer.write_u8(1)?;
                func(&mut writer, e)
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn compact_size() {
        macro_rules! eval {
            ($value:expr, $expected:expr) => {
                let mut data = vec![];
                CompactSize::write(&mut data, $value).unwrap();
                assert_eq!(&data[..], &$expected[..]);
                match CompactSize::read(&data[..]) {
                    Ok(n) => assert_eq!(n, $value),
                    Err(e) => panic!("Unexpected error: {:?}", e),
                }
            };
        }

        eval!(0, [0]);
        eval!(1, [1]);
        eval!(252, [252]);
        eval!(253, [253, 253, 0]);
        eval!(254, [253, 254, 0]);
        eval!(255, [253, 255, 0]);
        eval!(256, [253, 0, 1]);
        eval!(256, [253, 0, 1]);
        eval!(65535, [253, 255, 255]);
        eval!(65536, [254, 0, 0, 1, 0]);
        eval!(65537, [254, 1, 0, 1, 0]);

        eval!(33554432, [254, 0, 0, 0, 2]);

        {
            let value = 33554433;
            let encoded = &[254, 1, 0, 0, 2][..];
            let mut data = vec![];
            CompactSize::write(&mut data, value).unwrap();
            assert_eq!(&data[..], encoded);
            assert!(CompactSize::read(encoded).is_err());
        }
    }

    #[test]
    fn vector() {
        macro_rules! eval {
            ($value:expr, $expected:expr) => {
                let mut data = vec![];
                Vector::write(&mut data, &$value, |w, e| w.write_u8(*e)).unwrap();
                assert_eq!(&data[..], &$expected[..]);
                match Vector::read(&data[..], |r| r.read_u8()) {
                    Ok(v) => assert_eq!(v, $value),
                    Err(e) => panic!("Unexpected error: {:?}", e),
                }
            };
        }

        eval!(vec![], [0]);
        eval!(vec![0], [1, 0]);
        eval!(vec![1], [1, 1]);
        eval!(vec![5; 8], [8, 5, 5, 5, 5, 5, 5, 5, 5]);

        {
            // expected = [253, 4, 1, 7, 7, 7, ...]
            let mut expected = vec![7; 263];
            expected[0] = 253;
            expected[1] = 4;
            expected[2] = 1;

            eval!(vec![7; 260], expected);
        }
    }

    #[test]
    fn optional() {
        macro_rules! eval {
            ($value:expr, $expected:expr, $write:expr, $read:expr) => {
                let mut data = vec![];
                Optional::write(&mut data, &$value, $write).unwrap();
                assert_eq!(&data[..], &$expected[..]);
                match Optional::read(&data[..], $read) {
                    Ok(v) => assert_eq!(v, $value),
                    Err(e) => panic!("Unexpected error: {:?}", e),
                }
            };
        }

        macro_rules! eval_u8 {
            ($value:expr, $expected:expr) => {
                eval!($value, $expected, |w, e| w.write_u8(*e), |r| r.read_u8())
            };
        }

        macro_rules! eval_vec {
            ($value:expr, $expected:expr) => {
                eval!(
                    $value,
                    $expected,
                    |w, v| Vector::write(w, v, |w, e| w.write_u8(*e)),
                    |r| Vector::read(r, |r| r.read_u8())
                )
            };
        }

        eval_u8!(None, [0]);
        eval_u8!(Some(0), [1, 0]);
        eval_u8!(Some(1), [1, 1]);
        eval_u8!(Some(5), [1, 5]);

        eval_vec!(None as Option<Vec<_>>, [0]);
        eval_vec!(Some(vec![]), [1, 0]);
        eval_vec!(Some(vec![0]), [1, 1, 0]);
        eval_vec!(Some(vec![1]), [1, 1, 1]);
        eval_vec!(Some(vec![5; 8]), [1, 8, 5, 5, 5, 5, 5, 5, 5, 5]);
    }
}
