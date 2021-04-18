open Core
open Snarky
open Zexe_backend_common.Plonk_plookup_constraint_system
open Gcm

exception BlockArith of string

module Constraints (Intf : Snark_intf.Run with type prover_state = unit) = struct
  open Intf
  
  let f1 = Field.Constant.of_int 256
  let f2 = Field.Constant.of_int 65536
  let f3 = Field.Constant.of_int 16777216
  let f4 = Field.Constant.of_int 4294967296
  let f8 = Field.Constant.square f4
  let f12 = Field.Constant.(f4 * f8)

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
      [|one; b1; b2; b3; one + b1*f1 + b2*f2 + b3*f3|]
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
      [|b1; b2; b3; b4; b1 + b2*f1 + (of_int mul)*f2|]
    )
    in
    bytes.(0) <- b1;
    bytes.(1) <- b2;
    Intf.assert_
      [{
        basic= Plonk_constraint.T (Bytes_lookup { bytes }) ;
        annotation= None
      }];
    (bytes.(3), bytes.(2))
  
  let xtimesp (b : Field.t) : (Field.t * Field.t) =
    let bytes = exists (Snarky.Typ.array 5 Field.typ) ~compute:As_prover.(fun () ->
      let b = read_var b in
      let bits = Intf.Bigint.of_field b in
      let x = ref Int.(0) in
      for i = 0 to 7 do
        if Intf.Bigint.test_bit bits i then
          x := Int.(!x + (1 lsl i));
      done;
      let b23 = Gcm.table.(2).(!x) in
      let b2 = of_int (b23 land 255) in
      let b3 = of_int (b23 lsr 8) in
      [|of_int 2; b; b2; b3; of_int 2 + b*f1 + b2*f2 + b3*f3|]
    )
    in
    bytes.(1) <- b;
    Intf.assert_
      [{
        basic= Plonk_constraint.T (Bytes_lookup { bytes }) ;
        annotation= None
      }];
    (bytes.(3), bytes.(2))
  
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
      [|of_int ind; b; r; zero; of_int ind + b*f1 + r*f2|]
    )
    in
    bytes.(1) <- b;
    Intf.assert_
      [{
        basic= Plonk_constraint.T (Bytes_lookup { bytes }) ;
        annotation= None
      }];
    bytes.(2)

  let b4tof (b : Field.t array) : (Field.t) =
    if (Array.length b) <> 4 then
      raise (BlockArith "Incorrect array length");
    let bytes = exists Field.typ ~compute:As_prover.(fun () ->
      let b = Array.map ~f:(fun x -> read_var x) b in
      b.(0) + b.(1)*f1 + b.(2)*f2 + b.(3)*f3
    ) in
    let bytes = [|b.(0); b.(1); b.(2); b.(3); bytes|] in
    Intf.assert_
      [{
        basic= Plonk_constraint.T (Bytes4_tof { bytes }) ;
        annotation= None
      }];
    bytes.(4)

  let b16tof (b : Field.t array) : (Field.t) =
    if (Array.length b) <> 16 then
      raise (BlockArith "Incorrect block size");
    let b = Array.init 4 ~f:(fun i -> b4tof (Array.sub b (i*4) 4)) in
    let bytes = exists Field.typ ~compute:As_prover.(fun () ->
      let b = Array.map ~f:(fun x -> read_var x) b in
      b.(0) + b.(1)*f4 + b.(2)*f8 + b.(3)*f12
    ) in
    let bytes = [|b.(0); b.(1); b.(2); b.(3); bytes|] in
    Intf.assert_
      [{
        basic= Plonk_constraint.T (Bytes16_tof { bytes }) ;
        annotation= None
      }];
    bytes.(4)

end

module Block (Intf : Snark_intf.Run with type prover_state = unit) = struct
  open Intf
  
  let xor (b1 : Field.t array) (b2 : Field.t array) : Field.t array =
    if (Array.length b1) <> 16 || (Array.length b2) <> 16 then
      raise (BlockArith "Incorrect block size");
    let module Constraints = Constraints (Intf) in
    let open Field in
    Array.init 16 ~f:(fun i -> Constraints.xor b1.(i) b2.(i))
  
  let mul (b1 : Field.t array) (b2 : Field.t array) : Field.t array =
    if (Array.length b1) <> 16 || (Array.length b2) <> 16 then
      raise (BlockArith "Incorrect block size");
    let module Constraints = Constraints (Intf) in

    let z = (Array.init 16 ~f:(fun _ -> Field.zero)) in
    for i = 0 to 15 do
        for j = 0 to 15 do
            let k = i + j in
            let m0, m1 = Constraints.mul b1.(i) b2.(j) in

            if k < 15 then
            (
                z.(k) <- Constraints.xor z.(k) m0;
                z.(k+1) <- Constraints.xor z.(k+1) m1;
            )
            else if k = 15 then
            (
                let r0, r1 = Constraints.xtimesp m1 in
                z.(0) <- Constraints.xor z.(0) r0;
                z.(1) <- Constraints.xor z.(1) r1;
                z.(15) <- Constraints.xor z.(15) m0;
            )
            else if k < 30 then
            (
                let r00, r01 = Constraints.xtimesp m0 in
                let r10, r11 = Constraints.xtimesp m1 in
                z.(k-16) <- Constraints.xor z.(k-16) r00;
                z.(k-15) <- Constraints.xor z.(k-15) (Constraints.xor r01 r10);
                z.(k-14) <- Constraints.xor z.(k-14) r11;
            )
            else
            (
                let r00, r01 = Constraints.xtimesp m0 in
                let r10, r11 = Constraints.xtimesp m1 in
                let r20, r21 = Constraints.xtimesp r11 in
                z.(0) <- Constraints.xor z.(0) r20;
                z.(1) <- Constraints.xor z.(1) r21;
                z.(14) <- Constraints.xor z.(14) r00;
                z.(15) <- Constraints.xor z.(15) (Constraints.xor r01 r10);
            )
        done;
    done;
    z

  (*
    exchanges columns in each of 4 rows
    row0 - unchanged, row1- shifted left 1, 
    row2 - shifted left 2 and row3 - shifted left 3
  *)
  let shiftRows (state : Field.t array) : Field.t array =
    if (Array.length state) <> 16 then
      raise (BlockArith "Incorrect block size");
    let module Constraints = Constraints (Intf) in
    let sbox (ind : Field.t) : Field.t = Constraints.aesLookup ind Gcm.sboxInd in
    (* just substitute row 0 *)
    state.(0) <- sbox state.(0); state.(4) <- sbox state.(4);
    state.(8) <- sbox state.(8); state.(12) <- sbox state.(12);
    (* rotate row 1 *)
    let tmp = sbox state.(1) in state.(1) <- sbox state.(5);
    state.(5) <- sbox state.(9); state.(9) <- sbox state.(13); state.(13) <- tmp;
    (* rotate row 2 *)
    let tmp = sbox state.(2) in state.(2) <- sbox state.(10); state.(10) <- tmp;
    let tmp = sbox state.(6) in state.(6) <- sbox state.(14); state.(14) <- tmp;
    (* rotate row 3 *)
    let tmp = sbox state.(15) in state.(15) <- sbox state.(11);
    state.(11) <- sbox state.(7); state.(7) <- sbox state.(3); state.(3) <- tmp;
    state

  (* recombine and mix each row in a column *)
  let mixSubColumns (state : Field.t array) : Field.t array =
    if (Array.length state) <> 16 then
      raise (BlockArith "Incorrect block size");
    let module Constraints = Constraints (Intf) in
    let xor4 (b1 : Field.t) (b2 : Field.t) (b3 : Field.t) (b4 : Field.t) : Field.t =
      Constraints.xor (Constraints.xor b1 b2) (Constraints.xor b3 b4) in
    let sbox (ind : Field.t) : Field.t = Constraints.aesLookup ind Gcm.sboxInd in
    let xtime2Sbox (ind : Field.t) : Field.t = Constraints.aesLookup ind Gcm.xtime2sboxInd in
    let xtime3Sbox (ind : Field.t) : Field.t = Constraints.aesLookup ind Gcm.xtime3sboxInd in
    let ret = Array.init 16 ~f:(fun _ -> Field.zero) in
    (* mixing column 0 *)
    ret.(0) <- xor4 (xtime2Sbox state.(0)) (xtime3Sbox state.(5)) (sbox state.(10)) (sbox state.(15));
    ret.(1) <- xor4 (sbox state.(0)) (xtime2Sbox state.(5)) (xtime3Sbox state.(10)) (sbox state.(15));
    ret.(2) <- xor4 (sbox state.(0)) (sbox state.(5)) (xtime2Sbox state.(10)) (xtime3Sbox state.(15));
    ret.(3) <- xor4 (xtime3Sbox state.(0)) (sbox state.(5)) (sbox state.(10)) (xtime2Sbox state.(15));
    (* mixing column 1 *)
    ret.(4) <- xor4 (xtime2Sbox state.(4)) (xtime3Sbox state.(9)) (sbox state.(14)) (sbox state.(3));
    ret.(5) <- xor4 (sbox state.(4)) (xtime2Sbox state.(9)) (xtime3Sbox state.(14)) (sbox state.(3));
    ret.(6) <- xor4 (sbox state.(4)) (sbox state.(9)) (xtime2Sbox state.(14)) (xtime3Sbox state.(3));
    ret.(7) <- xor4 (xtime3Sbox state.(4)) (sbox state.(9)) (sbox state.(14)) (xtime2Sbox state.(3));
    (* mixing column 2 *)
    ret.(8) <- xor4 (xtime2Sbox state.(8)) (xtime3Sbox state.(13)) (sbox state.(2)) (sbox state.(7));
    ret.(9) <- xor4 (sbox state.(8)) (xtime2Sbox state.(13)) (xtime3Sbox state.(2)) (sbox state.(7));
    ret.(10) <- xor4 (sbox state.(8)) (sbox state.(13)) (xtime2Sbox state.(2)) (xtime3Sbox state.(7));
    ret.(11) <- xor4 (xtime3Sbox state.(8)) (sbox state.(13)) (sbox state.(2)) (xtime2Sbox state.(7));
    (* mixing column 3 *)
    ret.(12) <- xor4 (xtime2Sbox state.(12)) (xtime3Sbox state.(1)) (sbox state.(6)) (sbox state.(11));
    ret.(13) <- xor4 (sbox state.(12)) (xtime2Sbox state.(1)) (xtime3Sbox state.(6)) (sbox state.(11));
    ret.(14) <- xor4 (sbox state.(12)) (sbox state.(1)) (xtime2Sbox state.(6)) (xtime3Sbox state.(11));
    ret.(15) <- xor4 (xtime3Sbox state.(12)) (sbox state.(1)) (sbox state.(6)) (xtime2Sbox state.(11));
    ret

  (* encrypt one 128 bit block *)
  let encryptBlock (state : Field.t array) (ks : Field.t array array) : Field.t array =
    if (Array.length state) <> 16 || (Array.length ks) <> 11 || (Array.length ks.(0)) <> 16 then
      raise (BlockArith "Incorrect block size");
    let rec round state n =
      if n > 10 then
        state
      else if n = 10 then
        round (xor (shiftRows state) ks.(n)) 11
      else
        round (xor (mixSubColumns state) ks.(n)) Int.(n + 1)
    in
    round (xor state ks.(0)) 1

  (* compute AES key schedule *)
  let expandKey (key : Field.t array) : Field.t array array =
    if (Array.length key) <> 16 then
      raise (BlockArith "Incorrect block size");
    let module Constraints = Constraints (Intf) in
    let sbox (ind : Field.t) : Field.t = Constraints.aesLookup ind Gcm.sboxInd in
    let expkey = Array.init 176 ~f:(fun _ -> Field.zero) in
    let tmp = Array.init 5 ~f:(fun _ -> Field.zero) in
    Array.iteri key ~f:(fun i x -> expkey.(i) <- key.(i));
    for idx = 4 to 43 do
      tmp.(0) <- expkey.(4*idx - 4);
      tmp.(1) <- expkey.(4*idx - 3);
      tmp.(2) <- expkey.(4*idx - 2);
      tmp.(3) <- expkey.(4*idx - 1);
      if idx % 4 = 0 then
      (
          tmp.(4) <- tmp.(3);
          tmp.(3) <- sbox tmp.(0);
          tmp.(0) <- Constraints.xor (sbox tmp.(1)) (Constraints.aesLookup (Field.of_int (idx/4)) Gcm.rconInd);
          tmp.(1) <- sbox tmp.(2);
          tmp.(2) <- sbox tmp.(4);
      );
      expkey.(4*idx+0) <- Constraints.xor expkey.(4*idx - 16 + 0) tmp.(0);
      expkey.(4*idx+1) <- Constraints.xor expkey.(4*idx - 16 + 1) tmp.(1);
      expkey.(4*idx+2) <- Constraints.xor expkey.(4*idx - 16 + 2) tmp.(2);
      expkey.(4*idx+3) <- Constraints.xor expkey.(4*idx - 16 + 3) tmp.(3);
    done;
    Array.init 11 ~f:(fun i -> Array.init 16 ~f:(fun j -> expkey.(16*i+j)))

end
