module By = Digestif_by
module Bi = Digestif_bi

module type S =
sig
  type ctx
  type kind = [ `RMD160 ]

  val init: unit -> ctx
  val unsafe_feed_bytes: ctx -> By.t -> int -> int -> unit
  val unsafe_feed_bigstring: ctx -> Bi.t -> int -> int -> unit
  val unsafe_get: ctx -> By.t
  val dup: ctx -> ctx
end

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

module Unsafe : S
= struct
  type kind = [ `RMD160 ]

  type ctx =
    { s         : int32 array
    ; mutable n : int
    ; h         : int32 array
    ; b         : Bytes.t }

  let dup ctx =
    { s = Array.copy ctx.s
    ; n = ctx.n
    ; h = Array.copy ctx.h
    ; b = By.copy ctx.b }

  let init () =
    let b = By.make 64 '\x00' in

    { s = [| 0l; 0l; |]
    ; n = 0
    ; b
    ; h = [| 0x67452301l
           ; 0xefcdab89l
           ; 0x98badcfel
           ; 0x10325476l
           ; 0xc3d2e1f0l |] }

  let f x y z = Int32.(x lxor y lxor z)
  let g x y z = Int32.((x land y) lor ((lnot x) land z))
  let h x y z = Int32.((x lor (lnot y)) lxor z)
  let i x y z = Int32.((x land z) lor (y land (lnot z)))
  let j x y z = Int32.(x lxor (y lor (lnot z)))

  let ff a b c d e x s =
    let open Int32 in
    a := !a + (f !b !c !d) + x;
    a := (rol32 !a s) + !e;
    c := (rol32 !c 10)

  let gg a b c d e x s =
    let open Int32 in
    a := !a + (g !b !c !d) + x + 0x5a827999l;
    a := (rol32 !a s) + !e;
    c := (rol32 !c 10)

  let hh a b c d e x s =
    let open Int32 in
    a := !a + (h !b !c !d) + x + 0x6ed9eba1l;
    a := (rol32 !a s) + !e;
    c := (rol32 !c 10)

  let ii a b c d e x s =
    let open Int32 in
    a := !a + (i !b !c !d) + x + 0x8f1bbcdcl;
    a := (rol32 !a s) + !e;
    c := (rol32 !c 10)

  let jj a b c d e x s =
    let open Int32 in
    a := !a + (j !b !c !d) + x + 0xa953fd4el;
    a := (rol32 !a s) + !e;
    c := (rol32 !c 10)

  let fff a b c d e x s =
    let open Int32 in
    a := !a + (f !b !c !d) + x;
    a := (rol32 !a s) + !e;
    c := (rol32 !c 10)

  let ggg a b c d e x s =
    let open Int32 in
    a := !a + (g !b !c !d) + x + 0x7a6d76e9l;
    a := (rol32 !a s) + !e;
    c := (rol32 !c 10)

  let hhh a b c d e x s =
    let open Int32 in
    a := !a + (h !b !c !d) + x + 0x6d703ef3l;
    a := (rol32 !a s) + !e;
    c := (rol32 !c 10)

  let iii a b c d e x s =
    let open Int32 in
    a := !a + (i !b !c !d) + x + 0x5c4dd124l;
    a := (rol32 !a s) + !e;
    c := (rol32 !c 10)

  let jjj a b c d e x s =
    let open Int32 in
    a := !a + (j !b !c !d) + x + 0x50a28be6l;
    a := (rol32 !a s) + !e;
    c := (rol32 !c 10)

  let rmd160_do_chunk : type a.
       le32_to_cpu:(a -> int -> int32)
    -> ctx -> a -> int -> unit
    = fun ~le32_to_cpu ctx buff off ->
    let aa, bb, cc, dd, ee, aaa, bbb, ccc, ddd, eee =
      ref ctx.h.(0),
      ref ctx.h.(1),
      ref ctx.h.(2),
      ref ctx.h.(3),
      ref ctx.h.(4),
      ref ctx.h.(0),
      ref ctx.h.(1),
      ref ctx.h.(2),
      ref ctx.h.(3),
      ref ctx.h.(4)
    in

    let w = Array.make 16 0l in

    for i = 0 to 15
    do w.(i) <- le32_to_cpu buff (off + (i * 4)) done;

    (ff aa bb cc dd ee w.( 0) 11);
    (ff ee aa bb cc dd w.( 1) 14);
    (ff dd ee aa bb cc w.( 2) 15);
    (ff cc dd ee aa bb w.( 3) 12);
    (ff bb cc dd ee aa w.( 4)  5);
    (ff aa bb cc dd ee w.( 5)  8);
    (ff ee aa bb cc dd w.( 6)  7);
    (ff dd ee aa bb cc w.( 7)  9);
    (ff cc dd ee aa bb w.( 8) 11);
    (ff bb cc dd ee aa w.( 9) 13);
    (ff aa bb cc dd ee w.(10) 14);
    (ff ee aa bb cc dd w.(11) 15);
    (ff dd ee aa bb cc w.(12)  6);
    (ff cc dd ee aa bb w.(13)  7);
    (ff bb cc dd ee aa w.(14)  9);
    (ff aa bb cc dd ee w.(15)  8);

    (gg ee aa bb cc dd w.( 7)  7);
    (gg dd ee aa bb cc w.( 4)  6);
    (gg cc dd ee aa bb w.(13)  8);
    (gg bb cc dd ee aa w.( 1) 13);
    (gg aa bb cc dd ee w.(10) 11);
    (gg ee aa bb cc dd w.( 6)  9);
    (gg dd ee aa bb cc w.(15)  7);
    (gg cc dd ee aa bb w.( 3) 15);
    (gg bb cc dd ee aa w.(12)  7);
    (gg aa bb cc dd ee w.( 0) 12);
    (gg ee aa bb cc dd w.( 9) 15);
    (gg dd ee aa bb cc w.( 5)  9);
    (gg cc dd ee aa bb w.( 2) 11);
    (gg bb cc dd ee aa w.(14)  7);
    (gg aa bb cc dd ee w.(11) 13);
    (gg ee aa bb cc dd w.( 8) 12);

    (hh dd ee aa bb cc w.( 3) 11);
    (hh cc dd ee aa bb w.(10) 13);
    (hh bb cc dd ee aa w.(14)  6);
    (hh aa bb cc dd ee w.( 4)  7);
    (hh ee aa bb cc dd w.( 9) 14);
    (hh dd ee aa bb cc w.(15)  9);
    (hh cc dd ee aa bb w.( 8) 13);
    (hh bb cc dd ee aa w.( 1) 15);
    (hh aa bb cc dd ee w.( 2) 14);
    (hh ee aa bb cc dd w.( 7)  8);
    (hh dd ee aa bb cc w.( 0) 13);
    (hh cc dd ee aa bb w.( 6)  6);
    (hh bb cc dd ee aa w.(13)  5);
    (hh aa bb cc dd ee w.(11) 12);
    (hh ee aa bb cc dd w.( 5)  7);
    (hh dd ee aa bb cc w.(12)  5);

    (ii cc dd ee aa bb w.( 1) 11);
    (ii bb cc dd ee aa w.( 9) 12);
    (ii aa bb cc dd ee w.(11) 14);
    (ii ee aa bb cc dd w.(10) 15);
    (ii dd ee aa bb cc w.( 0) 14);
    (ii cc dd ee aa bb w.( 8) 15);
    (ii bb cc dd ee aa w.(12)  9);
    (ii aa bb cc dd ee w.( 4)  8);
    (ii ee aa bb cc dd w.(13)  9);
    (ii dd ee aa bb cc w.( 3) 14);
    (ii cc dd ee aa bb w.( 7)  5);
    (ii bb cc dd ee aa w.(15)  6);
    (ii aa bb cc dd ee w.(14)  8);
    (ii ee aa bb cc dd w.( 5)  6);
    (ii dd ee aa bb cc w.( 6)  5);
    (ii cc dd ee aa bb w.( 2) 12);

    (jj bb cc dd ee aa w.( 4)  9);
    (jj aa bb cc dd ee w.( 0) 15);
    (jj ee aa bb cc dd w.( 5)  5);
    (jj dd ee aa bb cc w.( 9) 11);
    (jj cc dd ee aa bb w.( 7)  6);
    (jj bb cc dd ee aa w.(12)  8);
    (jj aa bb cc dd ee w.( 2) 13);
    (jj ee aa bb cc dd w.(10) 12);
    (jj dd ee aa bb cc w.(14)  5);
    (jj cc dd ee aa bb w.( 1) 12);
    (jj bb cc dd ee aa w.( 3) 13);
    (jj aa bb cc dd ee w.( 8) 14);
    (jj ee aa bb cc dd w.(11) 11);
    (jj dd ee aa bb cc w.( 6)  8);
    (jj cc dd ee aa bb w.(15)  5);
    (jj bb cc dd ee aa w.(13)  6);

    (jjj aaa bbb ccc ddd eee w.( 5)  8);
    (jjj eee aaa bbb ccc ddd w.(14)  9);
    (jjj ddd eee aaa bbb ccc w.( 7)  9);
    (jjj ccc ddd eee aaa bbb w.( 0) 11);
    (jjj bbb ccc ddd eee aaa w.( 9) 13);
    (jjj aaa bbb ccc ddd eee w.( 2) 15);
    (jjj eee aaa bbb ccc ddd w.(11) 15);
    (jjj ddd eee aaa bbb ccc w.( 4)  5);
    (jjj ccc ddd eee aaa bbb w.(13)  7);
    (jjj bbb ccc ddd eee aaa w.( 6)  7);
    (jjj aaa bbb ccc ddd eee w.(15)  8);
    (jjj eee aaa bbb ccc ddd w.( 8) 11);
    (jjj ddd eee aaa bbb ccc w.( 1) 14);
    (jjj ccc ddd eee aaa bbb w.(10) 14);
    (jjj bbb ccc ddd eee aaa w.( 3) 12);
    (jjj aaa bbb ccc ddd eee w.(12)  6);

    (iii eee aaa bbb ccc ddd w.( 6)  9);
    (iii ddd eee aaa bbb ccc w.(11) 13);
    (iii ccc ddd eee aaa bbb w.( 3) 15);
    (iii bbb ccc ddd eee aaa w.( 7)  7);
    (iii aaa bbb ccc ddd eee w.( 0) 12);
    (iii eee aaa bbb ccc ddd w.(13)  8);
    (iii ddd eee aaa bbb ccc w.( 5)  9);
    (iii ccc ddd eee aaa bbb w.(10) 11);
    (iii bbb ccc ddd eee aaa w.(14)  7);
    (iii aaa bbb ccc ddd eee w.(15)  7);
    (iii eee aaa bbb ccc ddd w.( 8) 12);
    (iii ddd eee aaa bbb ccc w.(12)  7);
    (iii ccc ddd eee aaa bbb w.( 4)  6);
    (iii bbb ccc ddd eee aaa w.( 9) 15);
    (iii aaa bbb ccc ddd eee w.( 1) 13);
    (iii eee aaa bbb ccc ddd w.( 2) 11);

    (hhh ddd eee aaa bbb ccc w.(15)  9);
    (hhh ccc ddd eee aaa bbb w.( 5)  7);
    (hhh bbb ccc ddd eee aaa w.( 1) 15);
    (hhh aaa bbb ccc ddd eee w.( 3) 11);
    (hhh eee aaa bbb ccc ddd w.( 7)  8);
    (hhh ddd eee aaa bbb ccc w.(14)  6);
    (hhh ccc ddd eee aaa bbb w.( 6)  6);
    (hhh bbb ccc ddd eee aaa w.( 9) 14);
    (hhh aaa bbb ccc ddd eee w.(11) 12);
    (hhh eee aaa bbb ccc ddd w.( 8) 13);
    (hhh ddd eee aaa bbb ccc w.(12)  5);
    (hhh ccc ddd eee aaa bbb w.( 2) 14);
    (hhh bbb ccc ddd eee aaa w.(10) 13);
    (hhh aaa bbb ccc ddd eee w.( 0) 13);
    (hhh eee aaa bbb ccc ddd w.( 4)  7);
    (hhh ddd eee aaa bbb ccc w.(13)  5);

    (ggg ccc ddd eee aaa bbb w.( 8) 15);
    (ggg bbb ccc ddd eee aaa w.( 6)  5);
    (ggg aaa bbb ccc ddd eee w.( 4)  8);
    (ggg eee aaa bbb ccc ddd w.( 1) 11);
    (ggg ddd eee aaa bbb ccc w.( 3) 14);
    (ggg ccc ddd eee aaa bbb w.(11) 14);
    (ggg bbb ccc ddd eee aaa w.(15)  6);
    (ggg aaa bbb ccc ddd eee w.( 0) 14);
    (ggg eee aaa bbb ccc ddd w.( 5)  6);
    (ggg ddd eee aaa bbb ccc w.(12)  9);
    (ggg ccc ddd eee aaa bbb w.( 2) 12);
    (ggg bbb ccc ddd eee aaa w.(13)  9);
    (ggg aaa bbb ccc ddd eee w.( 9) 12);
    (ggg eee aaa bbb ccc ddd w.( 7)  5);
    (ggg ddd eee aaa bbb ccc w.(10) 15);
    (ggg ccc ddd eee aaa bbb w.(14)  8);

    (fff bbb ccc ddd eee aaa w.(12)  8);
    (fff aaa bbb ccc ddd eee w.(15)  5);
    (fff eee aaa bbb ccc ddd w.(10) 12);
    (fff ddd eee aaa bbb ccc w.( 4)  9);
    (fff ccc ddd eee aaa bbb w.( 1) 12);
    (fff bbb ccc ddd eee aaa w.( 5)  5);
    (fff aaa bbb ccc ddd eee w.( 8) 14);
    (fff eee aaa bbb ccc ddd w.( 7)  6);
    (fff ddd eee aaa bbb ccc w.( 6)  8);
    (fff ccc ddd eee aaa bbb w.( 2) 13);
    (fff bbb ccc ddd eee aaa w.(13)  6);
    (fff aaa bbb ccc ddd eee w.(14)  5);
    (fff eee aaa bbb ccc ddd w.( 0) 15);
    (fff ddd eee aaa bbb ccc w.( 3) 13);
    (fff ccc ddd eee aaa bbb w.( 9) 11);
    (fff bbb ccc ddd eee aaa w.(11) 11);

    let open Int32 in

    ddd := !ddd + !cc + ctx.h.(1); (* final result for h[0]. *)
    ctx.h.(1) <- ctx.h.(2) + !dd + !eee;
    ctx.h.(2) <- ctx.h.(3) + !ee + !aaa;
    ctx.h.(3) <- ctx.h.(4) + !aa + !bbb;
    ctx.h.(4) <- ctx.h.(0) + !bb + !ccc;
    ctx.h.(0) <- !ddd;

    ()

  exception Leave

  let feed : type a.
       le32_to_cpu:(a -> int -> int32)
    -> blit:(a -> int -> By.t -> int -> int -> unit)
    -> ctx -> a -> int -> int -> unit
    = fun ~le32_to_cpu ~blit ctx buf off len ->
    let t = ref ctx.s.(0) in
    let off = ref off in
    let len = ref len in

    ctx.s.(0) <- Int32.add !t (Int32.of_int (!len lsl 3));

    if ctx.s.(0) < !t
    then ctx.s.(1) <- Int32.(ctx.s.(1) + 1l);

    ctx.s.(1) <- Int32.add ctx.s.(1) (Int32.of_int (!len lsr 29));

    try
      if ctx.n <> 0
      then begin
        let t = 64 - ctx.n in

        if !len < t
        then begin
          blit buf !off ctx.b ctx.n !len;
          ctx.n <- ctx.n + !len;
          raise Leave
        end;

        blit buf !off ctx.b ctx.n t;
        rmd160_do_chunk ~le32_to_cpu:By.le32_to_cpu ctx ctx.b 0;
        off := !off + t;
        len := !len - t;
      end;

      while !len >= 64
      do rmd160_do_chunk ~le32_to_cpu ctx buf !off;
         off := !off + 64;
         len := !len - 64;
      done;

      blit buf !off ctx.b 0 !len;
      ctx.n <- !len;
    with Leave -> ()

  let unsafe_feed_bytes ctx buf off len = feed ~blit:By.blit ~le32_to_cpu:By.le32_to_cpu ctx buf off len
  let unsafe_feed_bigstring ctx buf off len = feed ~blit:By.blit_from_bigstring ~le32_to_cpu:Bi.le32_to_cpu ctx buf off len

  let unsafe_get ctx =
    let i = ref (ctx.n + 1) in
    let res = By.create (5 * 4) in
    By.set ctx.b ctx.n '\x80';

    if !i > 56
    then begin
      By.fill ctx.b !i (64 - !i) '\x00';
      rmd160_do_chunk ~le32_to_cpu:By.le32_to_cpu ctx ctx.b 0;
      i := 0;
    end;

    By.fill ctx.b !i (56 - !i) '\x00';
    By.cpu_to_le32 ctx.b 56 ctx.s.(0);
    By.cpu_to_le32 ctx.b 60 ctx.s.(1);
    rmd160_do_chunk ~le32_to_cpu:By.le32_to_cpu ctx ctx.b 0;

    for i = 0 to 4
    do By.cpu_to_le32 res (i * 4) ctx.h.(i) done;

    res
end
