module By = Digestif_by
module Bi = Digestif_bi

module Int32 =
struct
  include Int32

  let ( lsl ) = Int32.shift_left
  let ( lsr ) = Int32.shift_right
  let ( srl ) = Int32.shift_right_logical
  let ( lor ) = Int32.logor
  let ( lxor ) = Int32.logxor
  let ( land ) = Int32.logand
  let ( lnot ) = Int32.lognot
  let ( + ) = Int32.add
  let rol32 a n =
    (a lsl n) lor (srl a (32 - n))
  let ror32 a n =
    (srl a n) lor (a lsl (32 - n))
end

module Int64 =
struct
  include Int64

  let ( land ) = Int64.logand
  let ( lsl ) = Int64.shift_left
end

module type S =
sig
  type kind = [ `MD5 ]

  type ctx =
    { mutable size : int64
    ; b : Bytes.t
    ; h : int32 array }

  val init: unit -> ctx
  val unsafe_feed_bytes: ctx -> By.t -> int -> int -> unit
  val unsafe_feed_bigstring: ctx -> Bi.t -> int -> int -> unit
  val unsafe_get: ctx -> By.t
  val dup: ctx -> ctx
end

module Unsafe : S
= struct
  type kind = [ `MD5 ]

  type ctx =
    { mutable size : int64
    ; b : Bytes.t
    ; h : int32 array }

  let dup ctx =
    { size = ctx.size
    ; b    = By.copy ctx.b
    ; h    = Array.copy ctx.h }

  let init () =
    let b = By.make 64 '\x00' in

    { size = 0L
    ; b
    ; h = [| 0x67452301l
           ; 0xefcdab89l
           ; 0x98badcfel
           ; 0x10325476l |] }

  let f1 x y z = Int32.(z lxor (x land (y lxor z)))
  let f2 x y z = f1 z x y
  let f3 x y z = Int32.(x lxor y lxor z)
  let f4 x y z = Int32.(y lxor (x lor (lnot z)))

  let md5_do_chunk : type a. le32_to_cpu:(a -> int -> int32) -> ctx -> a -> int -> unit
    = fun ~le32_to_cpu ctx buf off ->
    let a, b, c, d =
      ref ctx.h.(0),
      ref ctx.h.(1),
      ref ctx.h.(2),
      ref ctx.h.(3) in

    let w = Array.make 16 0l in

    for i = 0 to 15
    do w.(i) <- le32_to_cpu buf (off + (i * 4)) done;

    let round f a b c d i k s =
      let open Int32 in
      a := !a + (f !b !c !d) + w.(i) + k;
      a := (rol32 !a s);
      a := !a + !b in

    round f1 a b c d 0 0xd76aa478l 7;
    round f1 d a b c 1 0xe8c7b756l 12;
    round f1 c d a b 2 0x242070dbl 17;
    round f1 b c d a 3 0xc1bdceeel 22;
    round f1 a b c d 4 0xf57c0fafl 7;
    round f1 d a b c 5 0x4787c62al 12;
    round f1 c d a b 6 0xa8304613l 17;
    round f1 b c d a 7 0xfd469501l 22;
    round f1 a b c d 8 0x698098d8l 7;
    round f1 d a b c 9 0x8b44f7afl 12;
    round f1 c d a b 10 0xffff5bb1l 17;
    round f1 b c d a 11 0x895cd7bel 22;
    round f1 a b c d 12 0x6b901122l 7;
    round f1 d a b c 13 0xfd987193l 12;
    round f1 c d a b 14 0xa679438el 17;
    round f1 b c d a 15 0x49b40821l 22;

    round f2 a b c d 1 0xf61e2562l 5;
    round f2 d a b c 6 0xc040b340l 9;
    round f2 c d a b 11 0x265e5a51l 14;
    round f2 b c d a 0 0xe9b6c7aal 20;
    round f2 a b c d 5 0xd62f105dl 5;
    round f2 d a b c 10 0x02441453l 9;
    round f2 c d a b 15 0xd8a1e681l 14;
    round f2 b c d a 4 0xe7d3fbc8l 20;
    round f2 a b c d 9 0x21e1cde6l 5;
    round f2 d a b c 14 0xc33707d6l 9;
    round f2 c d a b 3 0xf4d50d87l 14;
    round f2 b c d a 8 0x455a14edl 20;
    round f2 a b c d 13 0xa9e3e905l 5;
    round f2 d a b c 2 0xfcefa3f8l 9;
    round f2 c d a b 7 0x676f02d9l 14;
    round f2 b c d a 12 0x8d2a4c8al 20;

    round f3 a b c d 5 0xfffa3942l 4;
    round f3 d a b c 8 0x8771f681l 11;
    round f3 c d a b 11 0x6d9d6122l 16;
    round f3 b c d a 14 0xfde5380cl 23;
    round f3 a b c d 1 0xa4beea44l 4;
    round f3 d a b c 4 0x4bdecfa9l 11;
    round f3 c d a b 7 0xf6bb4b60l 16;
    round f3 b c d a 10 0xbebfbc70l 23;
    round f3 a b c d 13 0x289b7ec6l 4;
    round f3 d a b c 0 0xeaa127fal 11;
    round f3 c d a b 3 0xd4ef3085l 16;
    round f3 b c d a 6 0x04881d05l 23;
    round f3 a b c d 9 0xd9d4d039l 4;
    round f3 d a b c 12 0xe6db99e5l 11;
    round f3 c d a b 15 0x1fa27cf8l 16;
    round f3 b c d a 2 0xc4ac5665l 23;

    round f4 a b c d 0 0xf4292244l 6;
    round f4 d a b c 7 0x432aff97l 10;
    round f4 c d a b 14 0xab9423a7l 15;
    round f4 b c d a 5 0xfc93a039l 21;
    round f4 a b c d 12 0x655b59c3l 6;
    round f4 d a b c 3 0x8f0ccc92l 10;
    round f4 c d a b 10 0xffeff47dl 15;
    round f4 b c d a 1 0x85845dd1l 21;
    round f4 a b c d 8 0x6fa87e4fl 6;
    round f4 d a b c 15 0xfe2ce6e0l 10;
    round f4 c d a b 6 0xa3014314l 15;
    round f4 b c d a 13 0x4e0811a1l 21;
    round f4 a b c d 4 0xf7537e82l 6;
    round f4 d a b c 11 0xbd3af235l 10;
    round f4 c d a b 2 0x2ad7d2bbl 15;
    round f4 b c d a 9 0xeb86d391l 21;

    let open Int32 in
    ctx.h.(0) <- ctx.h.(0) + !a;
    ctx.h.(1) <- ctx.h.(1) + !b;
    ctx.h.(2) <- ctx.h.(2) + !c;
    ctx.h.(3) <- ctx.h.(3) + !d;

    ()

  let feed : type a.
       blit:(a -> int -> By.t -> int -> int -> unit)
    -> le32_to_cpu:(a -> int -> int32)
    -> ctx -> a -> int -> int -> unit
    = fun ~blit ~le32_to_cpu ctx buf off len ->
    let idx = ref Int64.(to_int (ctx.size land 0x3FL)) in
    let len = ref len in
    let off = ref off in

    let to_fill = 64 - !idx in

    ctx.size <- Int64.add ctx.size (Int64.of_int !len);

    if !idx <> 0 && !len >= to_fill
    then begin
      blit buf !off ctx.b !idx to_fill;
      md5_do_chunk ~le32_to_cpu:By.le32_to_cpu ctx ctx.b 0;
      len := !len - to_fill;
      off := !off + to_fill;
      idx := 0;
    end;

    while !len >= 64
    do md5_do_chunk ~le32_to_cpu ctx buf !off;
       len := !len - 64;
       off := !off + 64;
    done;

    if !len <> 0
    then blit buf !off ctx.b !idx !len;

    ()

  let unsafe_feed_bytes = feed ~blit:By.blit ~le32_to_cpu:By.le32_to_cpu
  let unsafe_feed_bigstring = feed ~blit:By.blit_from_bigstring ~le32_to_cpu:Bi.le32_to_cpu

  let unsafe_get ctx =
    let index = Int64.(to_int (ctx.size land 0x3FL)) in
    let padlen = if index < 56 then 56 - index else (64 + 56) - index in

    let padding = By.init padlen (function 0 -> '\x80' | _ -> '\x00') in

    let bits = By.create 8 in
    By.cpu_to_le64 bits 0 Int64.(ctx.size lsl 3);

    unsafe_feed_bytes ctx padding 0 padlen;
    unsafe_feed_bytes ctx bits 0 8;

    let res = By.create (4 * 4) in

    for i = 0 to 3
    do By.cpu_to_le32 res (i * 4) ctx.h.(i) done;

    res
end
