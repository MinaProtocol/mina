#![allow(non_snake_case)]
#![allow(non_upper_case_globals)]

use algebra::{pasta::Fq, Zero};
use crate::lookup_table::*;

pub fn init_table() -> Vec<Fq>
{
    let mut table = vec![Fq::zero(); 0x40000];

    // init GF(2^8) XOR and GF(2^128) multiplication tables
    for x in 0..0x100 {for y in 0..0x100
    {
        // GF(2^8) xor
        let xor: u64 = 1 + ((x as u64) << 8) + ((y as u64) << 16) + ((XOR[y | (x << 8)] as u64) << 24);
        table[y | (x << 8)] = Fq::from(xor);
    }}
    for x in 0..100 {for y in 0..0x100
    {
        // GF(2^128) multiplication
        let mul: u64 = (x as u64) + ((y as u64) << 8) + ((MULT[y | (x << 8)] as u64) << 16);
        table[y | (x << 8) + 0x10000] = Fq::from(mul);
    }}
    // GF(2^128) multiplication
    for x in 0..0x100
    {
        let mul: u64 = 2 + ((x as u64) << 8) + ((MUL[x as usize] as u64) << 16);
        table[x as usize + 0x20000] = Fq::from(mul);
    }
    // Sbox
    for x in 0..0x100
    {
        let mul: u64 = 3 + ((x as u64) << 8) + ((Sbox[x as usize] as u64) << 16);
        table[x as usize + 0x20100] = Fq::from(mul);
    }
    // InvSbox
    for x in 0..0x100
    {
        let mul: u64 = 4 + ((x as u64) << 8) + ((InvSbox[x as usize] as u64) << 16);
        table[x as usize + 0x20200] = Fq::from(mul);
    }
    // Xtime2Sbox
    for x in 0..0x100
    {
        let mul: u64 = 5 + ((x as u64) << 8) + ((Xtime2Sbox[x as usize] as u64) << 16);
        table[x as usize + 0x20300] = Fq::from(mul);
    }
    // Xtime3Sbox
    for x in 0..0x100
    {
        let mul: u64 = 6 + ((x as u64) << 8) + ((Xtime3Sbox[x as usize] as u64) << 16);
        table[x as usize + 0x20400] = Fq::from(mul);
    }
    // Xtime9
    for x in 0..0x100
    {
        let mul: u64 = 7 + ((x as u64) << 8) + ((Xtime9[x as usize] as u64) << 16);
        table[x as usize + 0x20500] = Fq::from(mul);
    }
    // XtimeB
    for x in 0..0x100
    {
        let mul: u64 = 8 + ((x as u64) << 8) + ((XtimeB[x as usize] as u64) << 16);
        table[x as usize + 0x20600] = Fq::from(mul);
    }
    // XtimeD
    for x in 0..0x100
    {
        let mul: u64 = 9 + ((x as u64) << 8) + ((XtimeD[x as usize] as u64) << 16);
        table[x as usize + 0x20700] = Fq::from(mul);
    }
    // XtimeE
    for x in 0..0x100
    {
        let mul: u64 = 10 + ((x as u64) << 8) + ((XtimeE[x as usize] as u64) << 16);
        table[x as usize + 0x20800] = Fq::from(mul);
    }
    // Rcon
    for x in 0..11
    {
        let mul: u64 = 11 + ((x as u64) << 8) + ((Rcon[x as usize] as u64) << 16);
        table[x as usize + 0x20900] = Fq::from(mul);
    }
    table
}
