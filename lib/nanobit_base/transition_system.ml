open Core_kernel
open Snark_params

(* Make sure tests work *)
let%test "trivial" = true

module type S = sig
  open Tick
  type digest_var

  module Update : Snarkable.S

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

module type Tick_keypair_intf = sig
  val verification_key : Tick.Verification_key.t
  val proving_key : Tick.Proving_key.t
end

module type Tock_keypair_intf = sig
  val verification_key : Tock.Verification_key.t
  val proving_key : Tock.Proving_key.t
end

(* Someday:
   Tighten this up. Doing this with all these equalities is kind of a hack, but
   doing it right required an annoying change to the bits intf. *)
module Make
    (Digest : sig
       module Tick
         : (Tick.Snarkable.Bits.Lossy
            with type Packed.var = Tick.Cvar.t
             and type Packed.value = Tick.Pedersen.Digest.t)
       module Tock
         : (Tock.Snarkable.Bits.Lossy with type Packed.value = Tock.Field.t)
     end)
    (Hash : sig
       val hash : Tick.Boolean.var list -> (Digest.Tick.Packed.var, _) Tick.Checked.t
     end)
    (System : S with type digest_var := Digest.Tick.Packed.var)
=
struct
  let step_input () =
    Tick.Data_spec.(
      [ Digest.Tick.Packed.spec (* H(wrap_vk, H(state)) *)
      ])

  let step_input_size = Tick.Data_spec.size (step_input ())

  let wrap_input () =
    Tock.Data_spec.([ Digest.Tock.Packed.spec ])

  module Step_base = struct
    open System

    module Prover_state = struct
      type t =
        { wrap_vk    : Tock_curve.Verification_key.t
        ; prev_proof : Tock_curve.Proof.t
        ; prev_state : State.value
        ; update     : Update.value
        }
      [@@deriving fields]
    end

    open Tick
    open Let_syntax

    let input = step_input

    let wrap_vk_length = 11324

    let wrap_vk_spec =
      Var_spec.list ~length:wrap_vk_length Boolean.spec

    module Verifier =
      Camlsnark.Verifier_gadget.Make(Tick)(Tick_curve)(Tock_curve)
        (struct let input_size = Tock.Data_spec.size (wrap_input ()) end)

    let prev_state_valid wrap_vk prev_state =
      let open Let_syntax in
      with_label "prev_state_valid" begin
        let%bind prev_state_hash =
          State.Checked.hash prev_state
          >>= Digest.Tick.choose_preimage_var
          >>| Digest.Tick.Unpacked.var_to_bits
        in
        let%bind prev_top_hash =
          Hash.hash (wrap_vk @ prev_state_hash)
          >>= Digest.Tick.choose_preimage_var
          >>| Digest.Tick.Unpacked.var_to_bits
        in
        let%map v =
          Verifier.All_in_one.create
            ~verification_key:wrap_vk ~input:prev_top_hash
            As_prover.(map get_state ~f:(fun { Prover_state.prev_proof; wrap_vk } ->
              { Verifier.All_in_one.verification_key=wrap_vk; proof=prev_proof }))
        in
        Verifier.All_in_one.result v
      end

    let testify' spec ~f = testify spec As_prover.(map get_state ~f)

    let main (top_hash : Digest.Tick.Packed.var) =
      with_label "Step.main" begin
        let%bind wrap_vk =
          testify' wrap_vk_spec ~f:(fun { Prover_state.wrap_vk } ->
            Verifier.Verification_key.to_bool_list wrap_vk)
        in
        let%bind prev_state = testify' State.spec ~f:Prover_state.prev_state
        and update          = testify' Update.spec ~f:Prover_state.update
        in
        let%bind (next_state, `Success success) =
          with_label "update" (State.Checked.update prev_state update)
        in
        let%bind state_hash =
          with_label "hash_state" (State.Checked.hash next_state)
        in
        let%bind () =
          with_label "check_top_hash" begin
            let%bind sh = Digest.Tick.(choose_preimage_var state_hash >>| Unpacked.var_to_bits) in
            Hash.hash (wrap_vk @ sh) >>= assert_equal ~label:"equal_to_top_hash" top_hash
          end
        in
        let%bind prev_state_valid = prev_state_valid wrap_vk prev_state in
        let%bind inductive_case_passed =
          with_label "inductive_case_passed" Boolean.(prev_state_valid && success)
        in
        let%bind is_base_case = State.Checked.is_base_hash state_hash in
        with_label "result" begin
          Boolean.Assert.any
            [ is_base_case
            ; inductive_case_passed
            ]
        end
      end
  end

  module Step (Tick_keypair : Tick_keypair_intf) = struct
    include Step_base
    include Tick_keypair
  end

  module type Step_vk_intf = sig
    val verification_key : Tick.Verification_key.t
  end

  module Wrap_base (Step_vk : Step_vk_intf) = struct
    let input = wrap_input

    open Tock

    module Verifier =
      Camlsnark.Verifier_gadget.Make(Tock)(Tock_curve)(Tick_curve)
        (struct let input_size = step_input_size end)

    module Prover_state = struct
      type t =
        { proof : Tick_curve.Proof.t
        }
    end

    let vk_bits =
      Verifier.Verification_key.to_bool_list Step_vk.verification_key

    let main (input : Digest.Tock.Packed.var) =
      let open Let_syntax in
      with_label "Wrap.main" begin
        let%bind v =
          (* The use of choose_preimage here is justified since we feed it to the verifier, which doesn't
             depend on which unpacking is provided. *)
          let%bind input = Digest.Tock.(choose_preimage_var input >>| Unpacked.var_to_bits) in
          let verification_key = List.map vk_bits ~f:Boolean.var_of_value in
          Verifier.All_in_one.create ~verification_key ~input
            As_prover.(map get_state ~f:(fun {Prover_state.proof} ->
              { Verifier.All_in_one.verification_key=Step_vk.verification_key; proof }))
        in
        with_label "verifier_result"
          (Boolean.Assert.is_true (Verifier.All_in_one.result v))
      end
  end

  module Wrap (Step_vk : Step_vk_intf) (Tock_keypair : Tock_keypair_intf) = struct
    include Wrap_base(Step_vk)
    include Tock_keypair
  end
end

