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
  type kind = [ `SHA256 ]

  type ctx =
    { mutable size : int64
    ; b : Bytes.t
    ; h : int32 array }

  val init: unit -> ctx
  val unsafe_feed_bytes: ctx -> By.t -> int -> int -> unit
  val unsafe_feed_bigstring: ctx -> Bi.t -> int -> int -> unit
  val unsafe_get: ctx -> By.t
  val unsafe_get_h : ctx -> int32 array
  val dup: ctx -> ctx
end

module Unsafe : S
= struct
  type kind = [ `SHA256 ]

  type ctx =
    { mutable size : int64
    ; b            : Bytes.t
    ; h            : int32 array }

  let dup ctx =
    { size = ctx.size
    ; b    = By.copy ctx.b
    ; h    = Array.copy ctx.h }

  let init () =
    let b = By.make 128 '\x00' in

    { size = 0L
    ; b
    ; h = [| 0x6a09e667l
           ; 0xbb67ae85l
           ; 0x3c6ef372l
           ; 0xa54ff53al
           ; 0x510e527fl
           ; 0x9b05688cl
           ; 0x1f83d9abl
           ; 0x5be0cd19l |] }

  let k =
    [| 0x428a2f98l; 0x71374491l; 0xb5c0fbcfl; 0xe9b5dba5l; 0x3956c25bl; 0x59f111f1l
     ; 0x923f82a4l; 0xab1c5ed5l; 0xd807aa98l; 0x12835b01l; 0x243185bel; 0x550c7dc3l
     ; 0x72be5d74l; 0x80deb1fel; 0x9bdc06a7l; 0xc19bf174l; 0xe49b69c1l; 0xefbe4786l
     ; 0x0fc19dc6l; 0x240ca1ccl; 0x2de92c6fl; 0x4a7484aal; 0x5cb0a9dcl; 0x76f988dal
     ; 0x983e5152l; 0xa831c66dl; 0xb00327c8l; 0xbf597fc7l; 0xc6e00bf3l; 0xd5a79147l
     ; 0x06ca6351l; 0x14292967l; 0x27b70a85l; 0x2e1b2138l; 0x4d2c6dfcl; 0x53380d13l
     ; 0x650a7354l; 0x766a0abbl; 0x81c2c92el; 0x92722c85l; 0xa2bfe8a1l; 0xa81a664bl
     ; 0xc24b8b70l; 0xc76c51a3l; 0xd192e819l; 0xd6990624l; 0xf40e3585l; 0x106aa070l
     ; 0x19a4c116l; 0x1e376c08l; 0x2748774cl; 0x34b0bcb5l; 0x391c0cb3l; 0x4ed8aa4al
     ; 0x5b9cca4fl; 0x682e6ff3l; 0x748f82eel; 0x78a5636fl; 0x84c87814l; 0x8cc70208l
     ; 0x90befffal; 0xa4506cebl; 0xbef9a3f7l; 0xc67178f2l |]

  let e0 x = Int32.((ror32 x 2) lxor (ror32 x 13) lxor (ror32 x 22))
  let e1 x = Int32.((ror32 x 6) lxor (ror32 x 11) lxor (ror32 x 25))
  let s0 x = Int32.((ror32 x 7) lxor (ror32 x 18) lxor (srl x 3))
  let s1 x = Int32.((ror32 x 17) lxor (ror32 x 19) lxor (srl x 10))

  let sha256_do_chunk
    : type a. be32_to_cpu:(a -> int -> int32) -> ctx -> a -> int -> unit
    = fun ~be32_to_cpu ctx buf off ->
    let a, b, c, d, e, f, g, h, t1, t2 =
      ref ctx.h.(0),
      ref ctx.h.(1),
      ref ctx.h.(2),
      ref ctx.h.(3),
      ref ctx.h.(4),
      ref ctx.h.(5),
      ref ctx.h.(6),
      ref ctx.h.(7),
      ref 0l, ref 0l
    in

    let w = Array.make 64 0l in

    for i = 0 to 15
    do w.(i) <- be32_to_cpu buf (off + i * 4) done;

    let ( -- ) a b = a - b in

    for i = 16 to 63
    do w.(i) <- Int32.((s1 w.(i -- 2)) + w.(i -- 7) + (s0 w.(i -- 15)) + w.(i -- 16)) done;

    let round a b c d e f g h k w =
      let open Int32 in
      t1 := !h + (e1 !e) + (!g lxor (!e land (!f lxor !g))) + k + w;
      t2 := (e0 !a) + ((!a land !b) lor (!c land (!a lor !b)));
      d := !d + !t1;
      h := !t1 + !t2;
    in

    for i = 0 to 7
    do
      round a b c d e f g h k.((i * 8) + 0) w.((i * 8) + 0);
      round h a b c d e f g k.((i * 8) + 1) w.((i * 8) + 1);
      round g h a b c d e f k.((i * 8) + 2) w.((i * 8) + 2);
      round f g h a b c d e k.((i * 8) + 3) w.((i * 8) + 3);
      round e f g h a b c d k.((i * 8) + 4) w.((i * 8) + 4);
      round d e f g h a b c k.((i * 8) + 5) w.((i * 8) + 5);
      round c d e f g h a b k.((i * 8) + 6) w.((i * 8) + 6);
      round b c d e f g h a k.((i * 8) + 7) w.((i * 8) + 7);
    done;

    let open Int32 in
    ctx.h.(0) <- ctx.h.(0) + !a;
    ctx.h.(1) <- ctx.h.(1) + !b;
    ctx.h.(2) <- ctx.h.(2) + !c;
    ctx.h.(3) <- ctx.h.(3) + !d;
    ctx.h.(4) <- ctx.h.(4) + !e;
    ctx.h.(5) <- ctx.h.(5) + !f;
    ctx.h.(6) <- ctx.h.(6) + !g;
    ctx.h.(7) <- ctx.h.(7) + !h;

    ()

  let feed : type a.
       blit:(a -> int -> By.t -> int -> int -> unit)
    -> be32_to_cpu:(a -> int -> int32)
    -> ctx -> a -> int -> int -> unit
    = fun ~blit ~be32_to_cpu ctx buf off len ->
    let idx = ref Int64.(to_int (ctx.size land 0x3FL)) in
    let len = ref len in
    let off = ref off in

    let to_fill = 64 - !idx in

    ctx.size <- Int64.add ctx.size (Int64.of_int !len);

    if !idx <> 0 && !len >= to_fill
    then begin
      blit buf !off ctx.b !idx to_fill;
      sha256_do_chunk ~be32_to_cpu:By.be32_to_cpu ctx ctx.b 0;
      len := !len - to_fill;
      off := !off + to_fill;
      idx := 0;
    end;

    while !len >= 64
    do sha256_do_chunk ~be32_to_cpu ctx buf !off;
      len := !len - 64;
      off := !off + 64;
    done;

    if !len <> 0
    then blit buf !off ctx.b !idx !len;

    ()

  let unsafe_feed_bytes = feed ~blit:By.blit ~be32_to_cpu:By.be32_to_cpu
  let unsafe_feed_bigstring = feed ~blit:By.blit_from_bigstring ~be32_to_cpu:Bi.be32_to_cpu

  let unsafe_get ctx =
    let index = Int64.(to_int (ctx.size land 0x3FL)) in
    let padlen = if index < 56 then 56 - index else (64 + 56) - index in

    let padding = By.init padlen (function 0 -> '\x80' | _ -> '\x00') in

    let bits = By.create 8 in
    By.cpu_to_be64 bits 0 Int64.(ctx.size lsl 3);

    unsafe_feed_bytes ctx padding 0 padlen;
    unsafe_feed_bytes ctx bits 0 8;

    let res = By.create (8 * 4) in

    for i = 0 to 7
    do By.cpu_to_be32 res (i * 4) ctx.h.(i) done;

    res

  let unsafe_get_h ctx = ctx.h
end
