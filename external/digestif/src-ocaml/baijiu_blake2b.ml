module By = Digestif_by
module Bi = Digestif_bi

module Int32 =
struct
  include Int32

  let ( lsl ) = Int32.shift_left
  let ( lsr ) = Int32.shift_right
  let ( asr ) = Int32.shift_right_logical
  let ( lor ) = Int32.logor
  let ( lxor ) = Int32.logxor
  let ( land ) = Int32.logand
  let ( lnot ) = Int32.lognot
  let ( + ) = Int32.add
  let rol32 a n =
    (a lsl n) lor (a asr (32 - n))
  let ror32 a n =
    (a asr n) lor (a lsl (32 - n))
end

module Int64 =
struct
  include Int64

  let ( land ) = Int64.logand
  let ( lsl ) = Int64.shift_left
  let ( lsr ) = Int64.shift_right
  let ( lor ) = Int64.logor
  let ( asr ) = Int64.shift_right_logical
  let ( lxor ) = Int64.logxor
  let ( + ) = Int64.add

  let rol64 a n =
    (a lsl n) lor (a asr (64 - n))
  let ror64 a n =
    (a asr n) lor (a lsl (64 - n))
end

module type S =
sig
  type ctx
  type kind = [ `BLAKE2B ]

  val init: unit -> ctx
  val with_outlen_and_bytes_key : int -> By.t -> int -> int -> ctx
  val with_outlen_and_bigstring_key : int -> Bi.t -> int -> int -> ctx
  val unsafe_feed_bytes: ctx -> By.t -> int -> int -> unit
  val unsafe_feed_bigstring: ctx -> Bi.t -> int -> int -> unit
  val unsafe_get: ctx -> By.t
  val dup: ctx -> ctx
end

module Unsafe : S
= struct
  type kind = [ `BLAKE2B ]

  type param =
    { digest_length : int
    ; key_length    : int
    ; fanout        : int
    ; depth         : int
    ; leaf_length   : int32
    ; node_offset   : int32
    ; xof_length    : int32
    ; node_depth    : int
    ; inner_length  : int
    ; reserved      : int array
    ; salt          : int array
    ; personal      : int array }

  type ctx =
    { mutable buflen    : int
    ; outlen            : int
    ; mutable last_node : int
    ; buf               : Bytes.t
    ; h                 : int64 array
    ; t                 : int64 array
    ; f                 : int64 array }

  let dup ctx =
    { buflen    = ctx.buflen
    ; outlen    = ctx.outlen
    ; last_node = ctx.last_node
    ; buf       = By.copy ctx.buf
    ; h         = Array.copy ctx.h
    ; t         = Array.copy ctx.t
    ; f         = Array.copy ctx.f }

  let param_to_bytes param =
    let arr =
      [| param.digest_length land 0xFF
       ; param.key_length    land 0xFF
       ; param.fanout        land 0xFF
       ; param.depth         land 0xFF

       (* store to little-endian *)
       ; Int32.(to_int ((param.leaf_length lsr 0) land 0xFFl))
       ; Int32.(to_int ((param.leaf_length lsr 8) land 0xFFl))
       ; Int32.(to_int ((param.leaf_length lsr 16) land 0xFFl))
       ; Int32.(to_int ((param.leaf_length lsr 24) land 0xFFl))

       (* store to little-endian *)
       ; Int32.(to_int ((param.node_offset lsr 0) land 0xFFl))
       ; Int32.(to_int ((param.node_offset lsr 8) land 0xFFl))
       ; Int32.(to_int ((param.node_offset lsr 16) land 0xFFl))
       ; Int32.(to_int ((param.node_offset lsr 24) land 0xFFl))

       (* store to little-endian *)
       ; Int32.(to_int ((param.xof_length lsr 0) land 0xFFl))
       ; Int32.(to_int ((param.xof_length lsr 8) land 0xFFl))
       ; Int32.(to_int ((param.xof_length lsr 16) land 0xFFl))
       ; Int32.(to_int ((param.xof_length lsr 24) land 0xFFl))

       ; param.node_depth land 0xFF
       ; param.inner_length land 0xFF

       ; param.reserved.(0) land 0xFF
       ; param.reserved.(1) land 0xFF
       ; param.reserved.(2) land 0xFF
       ; param.reserved.(3) land 0xFF
       ; param.reserved.(4) land 0xFF
       ; param.reserved.(5) land 0xFF
       ; param.reserved.(6) land 0xFF
       ; param.reserved.(7) land 0xFF
       ; param.reserved.(8) land 0xFF
       ; param.reserved.(9) land 0xFF
       ; param.reserved.(10) land 0xFF
       ; param.reserved.(11) land 0xFF
       ; param.reserved.(12) land 0xFF
       ; param.reserved.(13) land 0xFF

       ; param.salt.(0) land 0xFF
       ; param.salt.(1) land 0xFF
       ; param.salt.(2) land 0xFF
       ; param.salt.(3) land 0xFF
       ; param.salt.(4) land 0xFF
       ; param.salt.(5) land 0xFF
       ; param.salt.(6) land 0xFF
       ; param.salt.(7) land 0xFF
       ; param.salt.(8) land 0xFF
       ; param.salt.(9) land 0xFF
       ; param.salt.(10) land 0xFF
       ; param.salt.(11) land 0xFF
       ; param.salt.(12) land 0xFF
       ; param.salt.(13) land 0xFF
       ; param.salt.(14) land 0xFF
       ; param.salt.(15) land 0xFF

       ; param.personal.(0) land 0xFF
       ; param.personal.(1) land 0xFF
       ; param.personal.(2) land 0xFF
       ; param.personal.(3) land 0xFF
       ; param.personal.(4) land 0xFF
       ; param.personal.(5) land 0xFF
       ; param.personal.(6) land 0xFF
       ; param.personal.(7) land 0xFF
       ; param.personal.(8) land 0xFF
       ; param.personal.(9) land 0xFF
       ; param.personal.(10) land 0xFF
       ; param.personal.(11) land 0xFF
       ; param.personal.(12) land 0xFF
       ; param.personal.(13) land 0xFF
       ; param.personal.(14) land 0xFF
       ; param.personal.(15) land 0xFF |] in

    By.init 64 (fun i -> Char.unsafe_chr (Array.get arr i))

  let default_param =
    { digest_length = 64
    ; key_length    = 0
    ; fanout        = 1
    ; depth         = 1
    ; leaf_length   = 0l
    ; node_offset   = 0l
    ; xof_length    = 0l
    ; node_depth    = 0
    ; inner_length  = 0
    ; reserved      = [| 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; |]
    ; salt          = [| 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; |]
    ; personal      = [| 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; |] }

  let iv =
    [| 0x6a09e667f3bcc908L; 0xbb67ae8584caa73bL
     ; 0x3c6ef372fe94f82bL; 0xa54ff53a5f1d36f1L
     ; 0x510e527fade682d1L; 0x9b05688c2b3e6c1fL
     ; 0x1f83d9abfb41bd6bL; 0x5be0cd19137e2179L |]

  let increment_counter ctx inc =
    let open Int64 in

    ctx.t.(0) <- ctx.t.(0) + inc;
    ctx.t.(1) <- ctx.t.(1) + (if ctx.t.(0) < inc then 1L else 0L)

  let set_lastnode ctx =
    ctx.f.(1) <- Int64.minus_one

  let set_lastblock ctx =
    if ctx.last_node <> 0
    then set_lastnode ctx;

    ctx.f.(0) <- Int64.minus_one

  let init () =
    let buf = By.make 128 '\x00' in

    By.fill buf 0 128 '\x00';

    let ctx =
      { buflen = 0
      ; outlen = default_param.digest_length
      ; last_node = 0
      ; buf
      ; h = Array.make 8 0L
      ; t = Array.make 2 0L
      ; f = Array.make 2 0L } in

    let param_bytes = param_to_bytes default_param in

    for i = 0 to 7
    do ctx.h.(i) <- Int64.(iv.(i) lxor (By.le64_to_cpu param_bytes (i * 8))) done;

    ctx

  let sigma =
    [| [|  0;  1;  2;  3;  4;  5;  6;  7;  8;  9; 10; 11; 12; 13; 14; 15 |]
     ; [| 14; 10;  4;  8;  9; 15; 13;  6;  1; 12;  0;  2; 11;  7;  5;  3 |]
     ; [| 11;  8; 12;  0;  5;  2; 15; 13; 10; 14;  3;  6;  7;  1;  9;  4 |]
     ; [|  7;  9;  3;  1; 13; 12; 11; 14;  2;  6;  5; 10;  4;  0; 15;  8 |]
     ; [|  9;  0;  5;  7;  2;  4; 10; 15; 14;  1; 11; 12;  6;  8;  3; 13 |]
     ; [|  2; 12;  6; 10;  0; 11;  8;  3;  4; 13;  7;  5; 15; 14;  1;  9 |]
     ; [| 12;  5;  1; 15; 14; 13;  4; 10;  0;  7;  6;  3;  9;  2;  8; 11 |]
     ; [| 13; 11;  7; 14; 12;  1;  3;  9;  5;  0; 15;  4;  8;  6;  2; 10 |]
     ; [|  6; 15; 14;  9; 11;  3;  0;  8; 12;  2; 13;  7;  1;  4; 10;  5 |]
     ; [| 10;  2;  8;  4;  7;  6;  1;  5; 15; 11;  9; 14;  3; 12; 13 ; 0 |]
     ; [|  0;  1;  2;  3;  4;  5;  6;  7;  8;  9; 10; 11; 12; 13; 14; 15 |]
     ; [| 14; 10;  4;  8;  9; 15; 13;  6;  1; 12;  0;  2; 11;  7;  5;  3 |] |]

  let compress : type a. le64_to_cpu:(a -> int -> int64) -> ctx -> a -> int -> unit =
    fun ~le64_to_cpu ctx block off ->
    let v = Array.make 16 0L in
    let m = Array.make 16 0L in

    let g r i a_idx b_idx c_idx d_idx =
      let ( ++ ) = (+) in

      let open Int64 in
      v.(a_idx) <- v.(a_idx) + v.(b_idx) + m.(sigma.(r).(2 * i ++ 0));
      v.(d_idx) <- ror64 (v.(d_idx) lxor v.(a_idx)) 32;
      v.(c_idx) <- v.(c_idx) + v.(d_idx);
      v.(b_idx) <- ror64 (v.(b_idx) lxor v.(c_idx)) 24;
      v.(a_idx) <- v.(a_idx) + v.(b_idx) + m.(sigma.(r).(2 * i ++ 1));
      v.(d_idx) <- ror64 (v.(d_idx) lxor v.(a_idx)) 16;
      v.(c_idx) <- v.(c_idx) + v.(d_idx);
      v.(b_idx) <- ror64 (v.(b_idx) lxor v.(c_idx)) 63; in

    let r r =
      g r 0 0 4  8 12;
      g r 1 1 5  9 13;
      g r 2 2 6 10 14;
      g r 3 3 7 11 15;
      g r 4 0 5 10 15;
      g r 5 1 6 11 12;
      g r 6 2 7  8 13;
      g r 7 3 4  9 14; in

    for i = 0 to 15
    do m.(i) <- le64_to_cpu block (off + i * 8);
    done;

    for i = 0 to 7
    do v.(i) <- ctx.h.(i);
    done;

    v.( 8) <- iv.(0);
    v.( 9) <- iv.(1);
    v.(10) <- iv.(2);
    v.(11) <- iv.(3);
    v.(12) <- Int64.(iv.(4) lxor ctx.t.(0));
    v.(13) <- Int64.(iv.(5) lxor ctx.t.(1));
    v.(14) <- Int64.(iv.(6) lxor ctx.f.(0));
    v.(15) <- Int64.(iv.(7) lxor ctx.f.(1));

    r 0;
    r 1;
    r 2;
    r 3;
    r 4;
    r 5;
    r 6;
    r 7;
    r 8;
    r 9;
    r 10;
    r 11;

    let ( ++ ) = (+) in

    for i = 0 to 7
    do ctx.h.(i) <- Int64.(ctx.h.(i) lxor v.(i) lxor v.(i ++ 8)) done;

    ()

  let feed : type a.
       blit:(a -> int -> By.t -> int -> int -> unit)
    -> le64_to_cpu:(a -> int -> int64)
    -> ctx -> a -> int -> int -> unit =
    fun ~blit ~le64_to_cpu ctx buf off len ->
    let in_off = ref off in
    let in_len = ref len in

    if !in_len > 0
    then begin
      let left = ctx.buflen in
      let fill = 128 - left in

      if !in_len > fill
      then begin
        ctx.buflen <- 0;
        blit buf !in_off ctx.buf left fill;
        increment_counter ctx 128L;
        compress ~le64_to_cpu:By.le64_to_cpu ctx ctx.buf 0;
        in_off := !in_off + fill;
        in_len := !in_len - fill;

        while !in_len > 128
        do
          increment_counter ctx 128L;
          compress ~le64_to_cpu ctx buf !in_off;
          in_off := !in_off + 128;
          in_len := !in_len - 128;
        done;
      end;

      blit buf !in_off ctx.buf ctx.buflen !in_len;
      ctx.buflen <- ctx.buflen + !in_len;
    end;

    ()

  let unsafe_feed_bytes = feed ~blit:By.blit ~le64_to_cpu:By.le64_to_cpu
  let unsafe_feed_bigstring = feed ~blit:By.blit_from_bigstring ~le64_to_cpu:Bi.le64_to_cpu

  let with_outlen_and_key ~blit outlen key off len =
    let buf = By.make 128 '\x00' in

    let ctx =
      { buflen = 0
      ; outlen
      ; last_node = 0
      ; buf
      ; h = Array.make 8 0L
      ; t = Array.make 2 0L
      ; f = Array.make 2 0L } in

    let param_bytes = param_to_bytes
        { default_param with digest_length = outlen
                           ; key_length = len } in

    for i = 0 to 7
    do ctx.h.(i) <- Int64.(iv.(i) lxor (By.le64_to_cpu param_bytes (i * 8))) done;

    if len > 0
    then begin
      let block = By.make 128 '\x00' in

      blit key off block 0 len;
      unsafe_feed_bytes ctx block 0 128;
    end;

    ctx

  let with_outlen_and_bytes_key outlen key off len =
    with_outlen_and_key ~blit:By.blit outlen key off len

  let with_outlen_and_bigstring_key outlen key off len =
    with_outlen_and_key ~blit:By.blit_from_bigstring outlen key off len

  let unsafe_get ctx =
    let res = By.make 64 '\x00' in

    increment_counter ctx (Int64.of_int ctx.buflen);
    set_lastblock ctx;
    By.fill ctx.buf ctx.buflen (128 - ctx.buflen) '\x00';
    compress ~le64_to_cpu:By.le64_to_cpu ctx ctx.buf 0;

    for i = 0 to 7
    do By.cpu_to_le64 res (i * 8) ctx.h.(i) done;

    By.sub res 0 ctx.outlen
end
