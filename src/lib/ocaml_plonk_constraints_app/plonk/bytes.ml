open Core
open Snarky
open Zexe_backend_common.Plonk_plookup_constraint_system
open Gcm

module Constraints (Intf : Snark_intf.Run with type prover_state = unit) = struct
  open Intf
  
  let f2ind (b1: field) (b2: field) : int =
    let bit1 = Intf.Bigint.of_field b1 in
    let bit2 = Intf.Bigint.of_field b2 in
    let x = ref Int.(0) in
    for i = 0 to 7 do
      if Intf.Bigint.test_bit bit1 i then
        x := Int.(!x + (1 lsl i));
      if Intf.Bigint.test_bit bit2 i then
        x := Int.(!x + (1 lsl (i+8)));
    done;
    !x

  let xor (b1 : Field.t) (b2 : Field.t) : Field.t =
    let open Field in
    let bytes = exists (Snarky.Typ.array 5 typ) ~compute:As_prover.(fun () ->
      let b1 = read_var b1 in
      let b2 = read_var b2 in
      let b3 = of_int Gcm.table.(0).(f2ind b1 b2) in

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
      let b1 = read_var b1 in
      let b2 = read_var b2 in
      let mul = Gcm.table.(1).(f2ind b1 b2) in
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

    let z = (Array.init 16 ~f:(fun _ -> Field.zero)) in
    for i = 0 to 15 do
        for j = 0 to 15 do
            let k = i + j in
            let m0, m1 = Constrained.mul b1.(i) b2.(j) in

            if k < 15 then
            (
                z.(k) <- Constrained.xor z.(k) m0;
                z.(k+1) <- Constrained.xor z.(k+1) m1;
            )
            else if k = 15 then
            (
                let r0, r1 = Constrained.xtimesp m1 in
                z.(0) <- Constrained.xor z.(0) r0;
                z.(1) <- Constrained.xor z.(1) r1;
                z.(15) <- Constrained.xor z.(15) m0;
            )
            else if k < 30 then
            (
                let r00, r01 = Constrained.xtimesp m0 in
                let r10, r11 = Constrained.xtimesp m1 in
                z.(k-16) <- Constrained.xor z.(k-16) r00;
                z.(k-15) <- Constrained.xor z.(k-15) (Constrained.xor r01 r10);
                z.(k-14) <- Constrained.xor z.(k-14) r11;
            )
            else
            (
                let r00, r01 = Constrained.xtimesp m0 in
                let r10, r11 = Constrained.xtimesp m1 in
                let r20, r21 = Constrained.xtimesp r11 in
                z.(0) <- Constrained.xor z.(0) r20;
                z.(1) <- Constrained.xor z.(1) r21;
                z.(14) <- Constrained.xor z.(14) r00;
                z.(15) <- Constrained.xor z.(15) (Constrained.xor r01 r10);
            )
        done;
    done;
    z

end
