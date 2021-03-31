open Core
open Snarky
open Zexe_backend_common.Plonk_plookup_constraint_system
open Stdint
open Gcm

module Constraints (Intf : Snark_intf.Run with type prover_state = unit) = struct
  open Intf

  let xor (b1 : Field.t) (b2 : Field.t) : Field.t =
    let open Field in
    let bytes = exists (Snarky.Typ.array 5 typ) ~compute:As_prover.(fun () ->
      let b1 = read_var b1 in
      let b2 = read_var b2 in
      let bit1 = Intf.Bigint.of_field b1 in
      let bit2 = Intf.Bigint.of_field b2 in
      let x = ref Int.(0) in
      for i = 0 to 7 do
        let bit = if Intf.Bigint.(test_bit bit1 i = test_bit bit2 i) then 0 else 1 in
        x := Int.(!x + (bit lsl i));
      done;
      let b3 = of_int !x in

      [|
        one;
        b1;
        b2;
        b3;
        one + b1*(of_int 256) + b2*(of_int 65536) + b3*(of_int 16777216)
      |]
    )
    in
    bytes.(1) <- b1;
    bytes.(2) <- b2;
    Intf.assert_
      [{
        basic= Plonk_constraint.T (Bytes_lookup { bytes }) ;
        annotation= None
      }];
    bytes.(3)

  let mul_gf2128 (x: uint128) (y: uint128) : uint128 =
    let r = Uint128.of_string "0xE1000000000000000000000000000000" in
    let zr = Uint128.of_int 0 in
    let o = Uint128.of_int 1 in
    let z = ref (Uint128.of_int 0) in
    let v = x in
    let v = ref v in
    for i = 0 to 127 do
        if Uint128.logand y (Uint128.shift_left o (127-i)) <> zr then
          z := Uint128.logxor !z !v;
        v := Uint128.logxor (Uint128.shift_right !v 1) (if (Uint128.logand !v o) = zr then zr else r);
    done;
    !z

  let f2b (f: field) : uint128 =
    let f = Intf.Bigint.of_field f in
    let o = Uint128.of_int 1 in
    let x = ref (Uint128.of_int 0) in
    for i = 0 to 7 do
      if (Intf.Bigint.test_bit f i) then
        x := Uint128.(!x + shift_left o Int.(i + 120));
    done;
    !x
  
  let mul (b1 : Field.t) (b2 : Field.t) : (Field.t * Field.t) =
    let bytes = exists (Snarky.Typ.array 5 Field.typ) ~compute:As_prover.(fun () ->
      let b1 = read_var b1 in
      let b2 = read_var b2 in
      let b3 = ref Int.(0) in
      let b4 = ref Int.(0) in
      let z = Uint128.of_int 0 in
      let o = Uint128.of_int 1 in
      let m = mul_gf2128 (f2b b1) (f2b b2) in
      for i = 0 to 7 do
        if (Uint128.logand m (Uint128.shift_left o Int.(i + 120))) <> z then
          b3 := Int.(!b3 + (1 lsl i));
        if (Uint128.logand m (Uint128.shift_left o Int.(i + 112))) <> z then
          b4 := Int.(!b4 + (1 lsl i));
      done;
      let b3 = of_int !b3 in
      let b4 = of_int !b4 in
      [|
        b1;
        b2;
        b3;
        b4;
        b1 + b2*(of_int 256) + b3*(of_int 65536) + b4*(of_int 16777216)
      |]
    )
    in
    bytes.(0) <- b1;
    bytes.(1) <- b2;
    Intf.assert_
      [{
        basic= Plonk_constraint.T (Bytes_lookup { bytes }) ;
        annotation= None
      }];
    (bytes.(2), bytes.(3))
  
  let xtimesp (b : Field.t) : (Field.t * Field.t) =
    let bytes = exists (Snarky.Typ.array 5 Field.typ) ~compute:As_prover.(fun () ->
      let b = read_var b in
      let bits = Intf.Bigint.of_field b in
      let x = ref Int.(0) in
      for i = 0 to 7 do
        if Intf.Bigint.test_bit bits i then
          x := Int.(!x + (1 lsl i));
      done;
      let b23 = of_int Gcm.table.(2).(!x) in
      let bits = Intf.Bigint.of_field b23 in
      let b3 = ref Int.(0) in
      for i = 0 to 7 do
        if Intf.Bigint.test_bit bits Int.(i + 8) then
          b3 := Int.(!b3 + (1 lsl i));
      done;
      let b3 = of_int !b3 in
      let b2 = b23 - (b3 * of_int 256) in

      [|
        of_int 2;
        b;
        b2;
        b3;
        of_int 2 + b*(of_int 256) + b2*(of_int 65536) + b3*(of_int 16777216)
      |]
    )
    in
    bytes.(1) <- b;
    Intf.assert_
      [{
        basic= Plonk_constraint.T (Bytes_lookup { bytes }) ;
        annotation= None
      }];
    (bytes.(2), bytes.(3))
  
  let aesLookup (b : Field.t) (ind: int) : Field.t =
    let bytes = exists (Snarky.Typ.array 5 Field.typ) ~compute:As_prover.(fun () ->
      let b = read_var b in
      let bits = Intf.Bigint.of_field b in
      let x = ref Int.(0) in
      for i = 0 to 7 do
        if Intf.Bigint.test_bit bits i then
          x := Int.(!x + (1 lsl i));
      done;
      let r = of_int Gcm.table.(ind).(!x) in

      [|
        of_int ind;
        b;
        r;
        zero;
        of_int ind + b*(of_int 256) + r*(of_int 65536)
      |]
    )
    in
    bytes.(1) <- b;
    Intf.assert_
      [{
        basic= Plonk_constraint.T (Bytes_lookup { bytes }) ;
        annotation= None
      }];
    bytes.(2)

  let b4tof (b1 : Field.t) (b2 : Field.t) (b3 : Field.t) (b4 : Field.t) : (Field.t) =
    let bytes = exists Field.typ ~compute:As_prover.(fun () ->
      (read_var b1) + (read_var b2)*(of_int 256) + (read_var b3)*(of_int 65536) + (read_var b4)*(of_int 16777216)
    ) in
    let bytes = [|b1; b2; b3; b4; bytes|] in
    Intf.assert_
      [{
        basic= Plonk_constraint.T (Bytes4_tof { bytes }) ;
        annotation= None
      }];
    bytes.(4)

  let b16tof (b1 : Field.t) (b2 : Field.t) (b3 : Field.t) (b4 : Field.t) : (Field.t) =
    let bytes = exists Field.typ ~compute:As_prover.(fun () ->
      let f4 = of_int 4294967296 in
      let f8 = square f4 in
      (read_var b1) +
      (read_var b2) * f4 +
      (read_var b3) * f8 +
      (read_var b4) * f4 * f8
    ) in
    let bytes = [|b1; b2; b3; b4; bytes|] in
    Intf.assert_
      [{
        basic= Plonk_constraint.T (Bytes16_tof { bytes }) ;
        annotation= None
      }];
    bytes.(4)

end
