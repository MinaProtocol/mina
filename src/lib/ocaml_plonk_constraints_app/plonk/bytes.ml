open Core
open Snarky
open Zexe_backend_common.Plonk_plookup_constraint_system

module Constraints (Intf : Snark_intf.Run with type prover_state = unit) = struct
  open Intf

  let xor (b1 : Field.t) (b2 : Field.t) : Field.t =

    let bytes = exists (Snarky.Typ.array 5 Field.typ) ~compute:As_prover.(fun () ->
      let b1 = read_var b1 in
      let b2 = read_var b2 in
      let bit1 = Intf.Bigint.of_field b1 in
      let bit2 = Intf.Bigint.of_field b2 in
      let xor = Int.(0) in
      let x = ref xor in
      for i = 0 to 7 do
        let b1 = Intf.Bigint.test_bit bit1 i in
        let b2 = Intf.Bigint.test_bit bit2 i in
        let bit = if b1 = b2 then 0 else 1 in
        x := Int.(!x + (bit lsl i));
      done;
      let b3 = read_var (Field.of_int 3) in

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

end
