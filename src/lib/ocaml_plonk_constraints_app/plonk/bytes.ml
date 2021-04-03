open Core
open Snarky
open Zexe_backend_common.Plonk_plookup_constraint_system
open Stdint
open Gcm

let mul_gf2128 (x: uint128) (y: uint128) : uint128 =
  let r = Uint128.of_string "0xE1000000000000000000000000000000" in
  let zr = Uint128.of_int 0 in
  let o = Uint128.of_int 1 in
  let z = ref (Uint128.of_int 0) in
  let v = x in
  let v = ref v in
  for i = 0 to 127 do
      if Uint128.logand y (Uint128.shift_left o Int.(127-i)) <> zr then
        z := Uint128.logxor !z !v;
      v := Uint128.logxor (Uint128.shift_right !v 1) (if (Uint128.logand !v o) = zr then zr else r);
  done;
  !z

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
        if Intf.Bigint.test_bit bit1 i then
          x := Int.(!x + (1 lsl i));
        if Intf.Bigint.test_bit bit2 i then
          x := Int.(!x + (1 lsl (i+8)));
      done;
      let b3 = of_int Gcm.table.(0).(Int.(!x)) in

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
  
  let mul (b1 : Field.t) (b2 : Field.t) : (Field.t * Field.t) =
    let bytes = exists (Snarky.Typ.array 5 Field.typ) ~compute:As_prover.(fun () ->
      let f2b (f: field) : uint128 =
        let f = Intf.Bigint.of_field f in
        let o = Uint128.of_int 1 in
        let x = ref (Uint128.of_int 0) in
        for i = 0 to 7 do
          if (Intf.Bigint.test_bit f i) then
            x := Uint128.(!x + shift_left o Int.(i + 120));
        done;
        !x
      in
      let b1 = read_var b1 in
      let b2 = read_var b2 in
      let x = ref Int.(0) in
      let bit1 = Intf.Bigint.of_field b1 in
      let bit2 = Intf.Bigint.of_field b2 in
      for i = 0 to 7 do
        if Intf.Bigint.test_bit bit1 i then
          x := Int.(!x + (1 lsl i));
        if Intf.Bigint.test_bit bit2 i then
          x := Int.(!x + (1 lsl (i+8)));
      done;
      let mul = Gcm.table.(1).(Int.(!x)) in
      let b3 = of_int (mul land 255) in
      let b4 = of_int (mul lsr 8) in
      [|
        b1;
        b2;
        b3;
        b4;
        b1 + b2*(of_int 256) + (of_int mul)*(of_int 65536)
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

module Block (Intf : Snark_intf.Run with type prover_state = unit) = struct
  open Intf
  exception BlockArith of string
  
  let xor (b1 : Field.t array) (b2 : Field.t array) : Field.t array =
    let module Constrained = Constraints (Intf) in
    let open Field in
    if (Array.length b1) <> 16 || (Array.length b2) <> 16 then
      raise (BlockArith "Incorrect block size");
    Array.init 16 ~f:(fun i -> Constrained.xor b1.(i) b2.(i))
  
  let mul (b1 : Field.t array) (b2 : Field.t array) : Field.t array =
    let module Constrained = Constraints (Intf) in
    if (Array.length b1) <> 16 || (Array.length b2) <> 16 then
      raise (BlockArith "Incorrect block size");

    let z = ref (Array.init 16 ~f:(fun _ -> Field.zero)) in
    (*
    for i = 0 to 15 do
        for j = 0 to 15 do
            let k = i + j in
            let m = MULT[(x[i] as usize) | ((y[j] as usize) << 8)] in

            if k < 15
            {
                z[k] = xor(z[k], m[0], false);
                z[k+1] = xor(z[k+1], m[1], false);
            }
            else if k == 15
            {
                let r = R[m[1] as usize]; GCMLKPS += 1;
                z[0] = xor(z[0], r[0], false);
                z[1] = xor(z[1], r[1], false);
                z[15] = xor(z[15], m[0], false);
            }
            else if k < 30
            {
                let r0 = R[m[0] as usize];
                let r1 = R[m[1] as usize]; GCMLKPS += 2;
                z[k-16] = xor(z[k-16], r0[0], false);
                z[k-15] = xor(z[k-15], xor(r0[1], r1[0], false), false);
                z[k-14] = xor(z[k-14], r1[1], false);
            }
            else
            {
                let r0 = R[m[0] as usize];
                let r1 = R[m[1] as usize];
                let r2 = R[r1[1] as usize]; GCMLKPS += 3;
                z[0] = xor(z[0], r2[0], false);
                z[1] = xor(z[1], r2[1], false);
                z[14] = xor(z[14], r0[0], false);
                z[15] = xor(z[15], xor(r0[1], r1[0], false), false);
            }
        done;
    done;
    *)
    !z

end
