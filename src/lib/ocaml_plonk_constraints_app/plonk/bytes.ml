open Core
open Snarky
open Zexe_backend_common.Plonk_plookup_constraint_system
open Stdint

module Constraints (Intf : Snark_intf.Run with type prover_state = unit) = struct
  open Intf

  let xor (b1 : Field.t) (b2 : Field.t) : Field.t =
    let bytes = exists (Snarky.Typ.array 5 Field.typ) ~compute:As_prover.(fun () ->
      let b1 = read_var b1 in
      let b2 = read_var b2 in
      let bit1 = Intf.Bigint.of_field b1 in
      let bit2 = Intf.Bigint.of_field b2 in
      let x = ref Int.(0) in
      for i = 0 to 7 do
        let bit = if Intf.Bigint.(test_bit bit1 i = test_bit bit2 i) then 0 else 1 in
        x := Int.(!x + (bit lsl i));
      done;
      let b3 = read_var (Field.of_int !x) in

      [|
        one;
        b1;
        b2;
        b3;
        one + b1*(of_int 256) + b2*(of_int 65536) + b3*(of_int 16777216)
      |]
    )
    in
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
    for i = 0 to 128 do
        if Uint128.logand y (Uint128.shift_left o (127-i)) = zr then
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
      let b3 = Field.Constant.of_int !b3 in
      let b4 = Field.Constant.of_int !b4 in
      [|
        b1;
        b2;
        b3;
        b4;
        b1 + b2*(of_int 256) + b3*(of_int 65536) + b4*(of_int 16777216)
      |]
    )
    in
    Intf.assert_
      [{
        basic= Plonk_constraint.T (Bytes_lookup { bytes }) ;
        annotation= None
      }];
    (bytes.(2), bytes.(3))

end
