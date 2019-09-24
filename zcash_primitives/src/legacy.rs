//! Support for legacy transparent addresses and scripts.

use byteorder::{ReadBytesExt, WriteBytesExt};
use std::io::{self, Read, Write};
use std::ops::Shl;

use crate::serialize::Vector;

/// Minimal subset of script opcodes.
enum OpCode {
    // push value
    PushData1 = 0x4c,
    PushData2 = 0x4d,
    PushData4 = 0x4e,

    // stack ops
    Dup = 0x76,

    // bit logic
    Equal = 0x87,
    EqualVerify = 0x88,

    // crypto
    Hash160 = 0xa9,
    CheckSig = 0xac,
}

/// A serialized script, used inside transparent inputs and outputs of a transaction.
#[derive(Debug, Default)]
pub struct Script(pub Vec<u8>);

impl Script {
    pub fn read<R: Read>(mut reader: R) -> io::Result<Self> {
        let script = Vector::read(&mut reader, |r| r.read_u8())?;
        Ok(Script(script))
    }

    pub fn write<W: Write>(&self, mut writer: W) -> io::Result<()> {
        Vector::write(&mut writer, &self.0, |w, e| w.write_u8(*e))
    }
}

impl Shl<OpCode> for Script {
    type Output = Self;

    fn shl(mut self, rhs: OpCode) -> Self {
        self.0.push(rhs as u8);
        self
    }
}

impl Shl<&[u8]> for Script {
    type Output = Self;

    fn shl(mut self, data: &[u8]) -> Self {
        if data.len() < OpCode::PushData1 as usize {
            self.0.push(data.len() as u8);
        } else if data.len() <= 0xff {
            self.0.push(OpCode::PushData1 as u8);
            self.0.push(data.len() as u8);
        } else if data.len() <= 0xffff {
            self.0.push(OpCode::PushData2 as u8);
            self.0.extend(&(data.len() as u16).to_le_bytes());
        } else {
            self.0.push(OpCode::PushData4 as u8);
            self.0.extend(&(data.len() as u32).to_le_bytes());
        }
        self.0.extend(data);
        self
    }
}

/// A transparent address corresponding to either a public key or a `Script`.
#[derive(Debug, PartialEq)]
pub enum TransparentAddress {
    PublicKey([u8; 20]),
    Script([u8; 20]),
}

impl TransparentAddress {
    /// Generate the `scriptPubKey` corresponding to this address.
    pub fn script(&self) -> Script {
        match self {
            TransparentAddress::PublicKey(key_id) => {
                // P2PKH script
                Script::default()
                    << OpCode::Dup
                    << OpCode::Hash160
                    << &key_id[..]
                    << OpCode::EqualVerify
                    << OpCode::CheckSig
            }
            TransparentAddress::Script(script_id) => {
                // P2SH script
                Script::default() << OpCode::Hash160 << &script_id[..] << OpCode::Equal
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::{OpCode, Script, TransparentAddress};

    #[test]
    fn script_opcode() {
        {
            let script = Script::default() << OpCode::PushData1;
            assert_eq!(&script.0, &[OpCode::PushData1 as u8]);
        }
    }

    #[test]
    fn script_pushdata() {
        {
            let script = Script::default() << &[1, 2, 3, 4][..];
            assert_eq!(&script.0, &[4, 1, 2, 3, 4]);
        }

        {
            let short_data = vec![2; 100];
            let script = Script::default() << &short_data[..];
            assert_eq!(script.0[0], OpCode::PushData1 as u8);
            assert_eq!(script.0[1] as usize, 100);
            assert_eq!(&script.0[2..], &short_data[..]);
        }

        {
            let medium_data = vec![7; 1024];
            let script = Script::default() << &medium_data[..];
            assert_eq!(script.0[0], OpCode::PushData2 as u8);
            assert_eq!(&script.0[1..3], &[0x00, 0x04][..]);
            assert_eq!(&script.0[3..], &medium_data[..]);
        }

        {
            let long_data = vec![42; 1_000_000];
            let script = Script::default() << &long_data[..];
            assert_eq!(script.0[0], OpCode::PushData4 as u8);
            assert_eq!(&script.0[1..5], &[0x40, 0x42, 0x0f, 0x00][..]);
            assert_eq!(&script.0[5..], &long_data[..]);
        }
    }

    #[test]
    fn p2pkh() {
        let addr = TransparentAddress::PublicKey([4; 20]);
        assert_eq!(
            &addr.script().0,
            &[
                0x76, 0xa9, 0x14, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04,
                0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x88, 0xac,
            ]
        )
    }

    #[test]
    fn p2sh() {
        let addr = TransparentAddress::Script([7; 20]);
        assert_eq!(
            &addr.script().0,
            &[
                0xa9, 0x14, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07,
                0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x87,
            ]
        )
    }
}
