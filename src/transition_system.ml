open Core_kernel

module Main = Snark_params.Main
module Main_curve = Snark_params.Main_curve
module Other = Snark_params.Other
module Other_curve = Snark_params.Other_curve

module type S = sig
  open Snark_params.Main
  type digest_var

  module Update : Snarkable.S
(*

    val apply
      : var
      -> State.var
      -> (State.var * [ `Success of Boolean.var ], _) Checked.t
*)

  module State : sig
    type var
    type value
    val spec : (var, value) Var_spec.t

    val hash : value -> Pedersen.Digest.t

    val update_exn : value -> Update.value -> value

    module Checked : sig
      val hash : var -> (digest_var, _) Checked.t
      val is_base_hash : digest_var -> (Boolean.var, _) Checked.t

      val update : var -> Update.var -> (var * [ `Success of Boolean.var ], _) Checked.t
    end
  end
end

(* Someday:
   Tighten this up. Doing this with all these equalities is kind of a hack, but
   doing it right required an annoying change to the bits intf. *)
module Make
    (Digest : sig
       module Main
         : (Main.Snarkable.Bits.S
            with type Packed.var = Main.Cvar.t
             and type Packed.value = Main.Pedersen.Digest.t)
       module Other
         : (Other.Snarkable.Bits.S with type Packed.value = Other.Field.t)
     end)
    (Hash : sig
       val hash : Main.Boolean.var list -> (Digest.Main.Packed.var, _) Main.Checked.t
     end)
    (System : S with type digest_var := Digest.Main.Packed.var)
=
struct
  let step_input () =
    Main.Data_spec.(
      [ Digest.Main.Packed.spec (* H(wrap_vk, H(state)) *)
      ])

  let step_input_size = Main.Data_spec.size (step_input ())

  let wrap_input () =
    Other.Data_spec.([ Digest.Other.Packed.spec ])

  module Step = struct
    open System

    module Prover_state = struct
      type t =
        { wrap_vk    : Other_curve.Verification_key.t
        ; prev_proof : Other_curve.Proof.t
        ; prev_state : State.value
        ; update     : Update.value
        }
      [@@deriving fields]
    end

    open Main
    open Let_syntax

    let input = step_input

    let wrap_vk_length = 11324

    let wrap_vk_spec =
      Var_spec.list ~length:wrap_vk_length Boolean.spec

    module Verifier =
      Camlsnark.Verifier_gadget.Make(Main)(Main_curve)(Other_curve)
        (struct let input_size = Other.Data_spec.size (wrap_input ()) end)

    let prev_state_valid wrap_vk prev_state =
      with_label "prev_state_valid" begin
        let%bind prev_state_hash =
          State.Checked.hash prev_state
          >>= Digest.Main.Checked.unpack
          >>| Digest.Main.Checked.to_bits
        in
        let%bind prev_top_hash =
          Hash.hash (wrap_vk @ prev_state_hash)
          >>= Digest.Main.Checked.unpack
        in
        let%map v =
          Verifier.All_in_one.create
            ~verification_key:wrap_vk ~input:(Digest.Main.Checked.to_bits prev_top_hash)
            As_prover.(map get_state ~f:(fun { Prover_state.prev_proof; wrap_vk } ->
              { Verifier.All_in_one.verification_key=wrap_vk; proof=prev_proof }))
        in
        Verifier.All_in_one.result v
      end

    let get_witness spec ~f = store spec As_prover.(map get_state ~f)

    let main (top_hash : Digest.Main.Packed.var) =
      let%bind wrap_vk =
        get_witness wrap_vk_spec ~f:(fun { Prover_state.wrap_vk } ->
          Verifier.Verification_key.to_bool_list wrap_vk)
      in
      let%bind prev_state = get_witness State.spec ~f:Prover_state.prev_state
      and update          = get_witness Update.spec ~f:Prover_state.update
      in
      let%bind (next_state, `Success success) = State.Checked.update prev_state update in
      let%bind state_hash = State.Checked.hash next_state in
      let%bind () =
        let%bind sh = Digest.Main.Checked.(unpack state_hash >>| to_bits) in
        Hash.hash (wrap_vk @ sh) >>= assert_equal ~label:"equal_to_top_hash" top_hash
      in
      let%bind prev_state_valid = prev_state_valid wrap_vk prev_state in
      let%bind inductive_case_passed =
        with_label "inductive_case_passed" Boolean.(prev_state_valid && success)
      in
      let%bind is_base_case = State.Checked.is_base_hash state_hash in
      Boolean.Assert.any
        [ is_base_case
        ; inductive_case_passed
        ]

    let verification_key, proving_key =
      let kp = Main.generate_keypair (input ()) main in
      Main.Keypair.vk kp, Main.Keypair.pk kp
  end

  module Wrap = struct
    let input = wrap_input

    open Other

    module Verifier =
      Camlsnark.Verifier_gadget.Make(Other)(Other_curve)(Main_curve)
        (struct let input_size = step_input_size end)

    module Prover_state = struct
      type t =
        { proof : Main_curve.Proof.t
        }
    end

    let vk_bits =
      Verifier.Verification_key.to_bool_list Step.verification_key

    let main (input : Digest.Other.Packed.var) =
      let open Let_syntax in
      with_label "Wrap.main" begin
        let%bind v =
          let%bind input = Digest.Other.Checked.(unpack input >>| to_bits) in
          let verification_key = List.map vk_bits ~f:Boolean.var_of_value in
          Verifier.All_in_one.create ~verification_key ~input
            As_prover.(map get_state ~f:(fun {Prover_state.proof} ->
              { Verifier.All_in_one.verification_key=Step.verification_key; proof }))
        in
        with_label "verifier_result"
          (Boolean.Assert.is_true (Verifier.All_in_one.result v))
      end

    let verification_key, proving_key =
      let kp = Other.generate_keypair (input ()) main in
      Other.Keypair.vk kp, Other.Keypair.pk kp
  end

  let instance_hash =
    let self =
      Step.Verifier.Verification_key.to_bool_list Wrap.verification_key
    in
    fun state ->
      let open Main.Pedersen in
      let s = State.create params in
      State.update_fold s (List.fold self);
      State.update_fold s
        (List.fold
           (Digest.Bits.to_bits
              (System.State.hash state)));
      State.digest s

  let wrap : Main.Pedersen.Digest.t -> Main.Proof.t -> Other.Proof.t =
    let embed (x : Main.Field.t) : Other.Field.t =
      let n = Main.Bigint.of_field x in
      let rec go pt acc i =
        if i = Main.Field.size_in_bits
        then acc
        else
          go (Other.Field.add pt pt)
            (if Main.Bigint.test_bit n i
            then Other.Field.add pt acc
            else acc)
            (i + 1)
      in
      go Other.Field.one Other.Field.zero 0
    in
    fun hash proof ->
      Other.prove Wrap.proving_key (Wrap.input ())
        { Wrap.Prover_state.proof }
        Wrap.main
        (embed hash)

  let step ~prev_proof ~prev_state block =
    let prev_proof = wrap (instance_hash prev_state) prev_proof in
    let next_state = System.State.update_exn prev_state block in
    Main.prove Step.proving_key (Step.input ())
      { Step.Prover_state.prev_proof
      ; wrap_vk = Wrap.verification_key
      ; prev_state
      ; update = block
      }
      Step.main
      (instance_hash next_state)
end
