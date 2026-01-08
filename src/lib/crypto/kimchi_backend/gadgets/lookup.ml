open Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint

module Circuit = Kimchi_pasta_snarky_backend.Step_impl

(** Looks up three values (at most 12 bits each).

    BEWARE: it needs in the circuit at least one gate (even if dummy) that uses
    the 12-bit lookup table for it to work. *)
let three_12bit (v0 : Circuit.Field.t) (v1 : Circuit.Field.t)
    (v2 : Circuit.Field.t) : unit =
  let open Circuit in
  with_label "triple_lookup" (fun () ->
      assert_
        (Lookup
           { w0 = Field.one
           ; w1 = v0
           ; w2 = Field.zero
           ; w3 = v1
           ; w4 = Field.zero
           ; w5 = v2
           ; w6 = Field.zero
           } ) ) ;
  ()

(** Check that one value is at most X bits (at most 12), default is 12.

    BEWARE: it needs in the circuit at least one gate (even if dummy) that uses
    the 12-bit lookup table for it to work. *)
let less_than_bits ?(bits = 12) (value : Circuit.Field.t) : unit =
  let open Circuit in
  assert (bits > 0 && bits <= 12) ;
  (* In order to check that a value is less than 2^x bits value < 2^x
     you first check that value < 2^12 bits using the lookup table
     and then that the value * shift < 2^12 where shift = 2^(12-x)
     (because moving shift to the right hand side that gives value < 2^x) *)
  let shift =
    exists Field.typ ~compute:(fun () ->
        let power = Core_kernel.Int.pow 2 (12 - bits) in
        Field.Constant.of_int power )
  in
  three_12bit value Field.(value * shift) Field.zero ;
  ()
