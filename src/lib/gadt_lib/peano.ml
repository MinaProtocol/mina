type zero = unit

type 'n succ = unit -> 'n

type _0 = zero

type _1 = _0 succ

type _2 = _1 succ

type _3 = _2 succ

type _4 = _3 succ

type _5 = _4 succ

type _6 = _5 succ

type 'n t = Z : zero t | S : 'n t -> 'n succ t

let _0 = Z

let _1 = S _0

let _2 = S _1

let _3 = S _2

let _4 = S _3

let _5 = S _4

let _6 = S _5
