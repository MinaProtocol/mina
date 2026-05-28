(** Mina's production Schnorr verifier
 *  ({!Signature_lib.Schnorr.Chunked.Checked.verifies}) shaped as a
 *  kimchi circuit-system body, plus the matching public-input typ.
 *  Shared by the two dumper exes in [pickles/]:
 *
 *    - [dump_schnorr_verify_circuit/] writes the CS fixture
 *      ([schnorr_verify_step_circuit.{json,labels,gate_labels,
 *      cached_constants}]) the PS pickles-circuit-diffs loop
 *      converges against.
 *
 *    - [dump_schnorr_signature_proof/] runs the same circuit through
 *      a kimchi keypair + prover and writes [vk.serde.json],
 *      [proof.serde.json], [public_input.json] (260 LE-hex fields:
 *      [pk_x, pk_y, r, s_bits[0..254], msg, output_bool]) for the PS
 *      "OCaml-emitted proof verifies under PS" test.
 *
 *  Public input is a flat 259-field array rather than the production
 *  typ tuple3
 *  ([Inner_curve.typ] × [Schnorr.Chunked.Signature.typ] × [Field.typ]):
 *  snarky's [Impl.constraint_system] runs the input typ's [check],
 *  but [Impl.generate_witness_conv] does not. Typs with aux-var-
 *  allocating checks (like [Inner_curve.typ]'s [assert_on_curve])
 *  therefore produce different CS sizes between the compile and
 *  witness passes, and the kimchi prover OOBs in [compute_witness].
 *  With a flat typ (trivial check) and the on-curve + 255 boolean
 *  checks re-emitted inside the body, compile and witness allocate
 *  the same variables. The resulting CS is byte-identical to what
 *  the production typ produces (verified: identical MD5 against the
 *  prior fixture from [Inner_curve.typ × Signature.typ × Field.typ]).
 *
 *  Public-input layout (matches PS
 *  [packages/pickles-circuit-diffs/.../SchnorrVerify.purs]):
 *    [pk_x; pk_y; r; s_bits[0..254]; msg].
 *)

module Impl = Pickles.Impls.Step

let input_size = 259

let input_typ =
  Snark_params.Tick.Typ.array ~length:input_size Snark_params.Tick.Field.typ

let return_typ = Snark_params.Tick.Boolean.typ

let schnorr_verify_circuit (inputs : Snark_params.Tick.Field.Var.t array) () =
  let pk_x = inputs.(0) in
  let pk_y = inputs.(1) in
  let r = inputs.(2) in
  let s_bit_cvars = Core_kernel.List.init 255 ~f:(fun i -> inputs.(3 + i)) in
  let msg = inputs.(258) in
  Impl.run_checked
    Snark_params.Tick.Checked.(
      let pk = (pk_x, pk_y) in
      (* Mirror what [Inner_curve.typ.check] would emit, were the
         production typ used. *)
      let%bind () = Snark_params.Tick.Inner_curve.Checked.Assert.on_curve pk in
      (* Mirror what each [Boolean.typ.check] would emit. *)
      let%bind s_bits =
        Snark_params.Tick.Checked.List.map s_bit_cvars
          ~f:Snark_params.Tick.Boolean.of_field
      in
      let signature : Signature_lib.Schnorr.Chunked.Signature.var =
        (r, Bitstring_lib.Bitstring.Lsb_first.of_list s_bits)
      in
      let%bind (module S) =
        Snark_params.Tick.Inner_curve.Checked.Shifted.create ()
      in
      let m = Random_oracle_input.Chunked.field_elements [| msg |] in
      Signature_lib.Schnorr.Chunked.Checked.verifies
        ~signature_kind:Mina_signature_kind.Mainnet
        (module S)
        signature pk m)
