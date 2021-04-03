#![allow(non_snake_case)]
#![allow(non_upper_case_globals)]

use algebra::{pasta::Fp, Zero};
use crate::lookup_table::*;

pub fn init_table() -> Vec<Fp>
{
    let z = Fp::zero();
    let mut table = vec![z; DOMAIN_SIZE];

    // init GF(2^8) XOR and GF(2^128) multiplication tables
    for x in 0..0x100 {for y in 0..0x100
    {
        // GF(2^8) xor
        let xor: u64 = 1 + ((x as u64) << 8) + ((y as u64) << 16) + ((XOR[y | (x << 8)] as u64) << 24);
        table[y | (x << 8)] = Fp::from(xor);
    }}
    for x in 0..0x100 {for y in 0..0x100
    {
        let mul: u64 = (x as u64) + ((y as u64) << 8) + ((MULT[y | (x << 8)] as u64) << 16);
        table[y | (x << 8) + 0x10000] = Fp::from(mul);
    }}
    // GF(2^128) multiplication
    for x in 0..0x100
    {
        let mul: u64 = 2 + ((x as u64) << 8) + ((MUL[x as usize] as u64) << 16);
        table[x as usize + 0x20000] = Fp::from(mul);
    }
    // Sbox
    for x in 0..0x100
    {
        let mul: u64 = 3 + ((x as u64) << 8) + ((Sbox[x as usize] as u64) << 16);
        table[x as usize + 0x20100] = Fp::from(mul);
    }
    // InvSbox
    for x in 0..0x100
    {
        let mul: u64 = 4 + ((x as u64) << 8) + ((InvSbox[x as usize] as u64) << 16);
        table[x as usize + 0x20200] = Fp::from(mul);
    }
    // Xtime2Sbox
    for x in 0..0x100
    {
        let mul: u64 = 5 + ((x as u64) << 8) + ((Xtime2Sbox[x as usize] as u64) << 16);
        table[x as usize + 0x20300] = Fp::from(mul);
    }
    // Xtime3Sbox
    for x in 0..0x100
    {
        let mul: u64 = 6 + ((x as u64) << 8) + ((Xtime3Sbox[x as usize] as u64) << 16);
        table[x as usize + 0x20400] = Fp::from(mul);
    }
    // Xtime9
    for x in 0..0x100
    {
        let mul: u64 = 7 + ((x as u64) << 8) + ((Xtime9[x as usize] as u64) << 16);
        table[x as usize + 0x20500] = Fp::from(mul);
    }
    // XtimeB
    for x in 0..0x100
    {
        let mul: u64 = 8 + ((x as u64) << 8) + ((XtimeB[x as usize] as u64) << 16);
        table[x as usize + 0x20600] = Fp::from(mul);
    }
    // XtimeD
    for x in 0..0x100
    {
        let mul: u64 = 9 + ((x as u64) << 8) + ((XtimeD[x as usize] as u64) << 16);
        table[x as usize + 0x20700] = Fp::from(mul);
    }
    // XtimeE
    for x in 0..0x100
    {
        let mul: u64 = 10 + ((x as u64) << 8) + ((XtimeE[x as usize] as u64) << 16);
        table[x as usize + 0x20800] = Fp::from(mul);
    }
    // Rcon
    for x in 0..11
    {
        let mul: u64 = 11 + ((x as u64) << 8) + ((Rcon[x as usize] as u64) << 16);
        table[x as usize + 0x20900] = Fp::from(mul);
    }
    table
}
