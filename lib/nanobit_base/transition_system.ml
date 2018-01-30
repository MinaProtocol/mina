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

(* Someday:
   Tighten this up. Doing this with all these equalities is kind of a hack, but
   doing it right required an annoying change to the bits intf. *)
module Make
    (Digest : sig
       module Tick
         : (Tick.Snarkable.Bits.S
            with type Packed.var = Tick.Cvar.t
             and type Packed.value = Tick.Pedersen.Digest.t)
       module Tock
         : (Tock.Snarkable.Bits.S with type Packed.value = Tock.Field.t)
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

  module Step = struct
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
      with_label "prev_state_valid" begin
        let%bind prev_state_hash =
          State.Checked.hash prev_state
          >>= Digest.Tick.Checked.unpack
          >>| Digest.Tick.Checked.to_bits
        in
        let%bind prev_top_hash =
          Hash.hash (wrap_vk @ prev_state_hash)
          >>= Digest.Tick.Checked.unpack
        in
        let%map v =
          Verifier.All_in_one.create
            ~verification_key:wrap_vk ~input:(Digest.Tick.Checked.to_bits prev_top_hash)
            As_prover.(map get_state ~f:(fun { Prover_state.prev_proof; wrap_vk } ->
              { Verifier.All_in_one.verification_key=wrap_vk; proof=prev_proof }))
        in
        Verifier.All_in_one.result v
      end

    let exists' spec ~f = exists spec As_prover.(map get_state ~f)

    let main (top_hash : Digest.Tick.Packed.var) =
      let%bind wrap_vk =
        exists' wrap_vk_spec ~f:(fun { Prover_state.wrap_vk } ->
          Verifier.Verification_key.to_bool_list wrap_vk)
      in
      let%bind prev_state = exists' State.spec ~f:Prover_state.prev_state
      and update          = exists' Update.spec ~f:Prover_state.update
      in
      let%bind (next_state, `Success success) = State.Checked.update prev_state update in
      let%bind state_hash = State.Checked.hash next_state in
      let%bind () =
        let%bind sh = Digest.Tick.Checked.(unpack state_hash >>| to_bits) in
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

    let keypair = lazy (Tick.generate_keypair (input ()) main)
    let verification_key = Lazy.map ~f:Tick.Keypair.vk keypair
    let proving_key = Lazy.map ~f:Tick.Keypair.pk keypair
  end

  module Wrap = struct
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

    let vk_bits = Lazy.map ~f:Verifier.Verification_key.to_bool_list Step.verification_key

    let main (input : Digest.Tock.Packed.var) =
      let open Let_syntax in
      with_label "Wrap.main" begin
        let%bind v =
          (* The use of unpack here is justified since we feed it to the verifier, which doesn't
             depend on which unpacking is provided. *)
          let%bind input = Digest.Tock.Checked.(unpack input >>| to_bits) in
          let verification_key = List.map (Lazy.force vk_bits) ~f:Boolean.var_of_value in
          Verifier.All_in_one.create ~verification_key ~input
            As_prover.(map get_state ~f:(fun {Prover_state.proof} ->
              { Verifier.All_in_one.verification_key=Lazy.force Step.verification_key; proof }))
        in
        with_label "verifier_result"
          (Boolean.Assert.is_true (Verifier.All_in_one.result v))
      end

    let keypair = lazy (Tock.generate_keypair (input ()) main)
    let verification_key = Lazy.map ~f:Tock.Keypair.vk keypair
    let proving_key = Lazy.map ~f:Tock.Keypair.pk keypair
  end

  let instance_hash =
    let self =
      Lazy.map ~f:Step.Verifier.Verification_key.to_bool_list Wrap.verification_key
    in
    fun state ->
      let open Tick.Pedersen in
      let s = State.create params in
      let s = State.update_fold s (List.fold (Lazy.force self)) in
      let s =
        State.update_fold s
          (List.fold
            (Digest.Bits.to_bits
               (System.State.hash state)))
      in
      State.digest s

  let wrap : Tick.Pedersen.Digest.t -> Tick.Proof.t -> Tock.Proof.t =
    let embed (x : Tick.Field.t) : Tock.Field.t =
      let n = Tick.Bigint.of_field x in
      let rec go pt acc i =
        if i = Tick.Field.size_in_bits
        then acc
        else
          go (Tock.Field.add pt pt)
            (if Tick.Bigint.test_bit n i
            then Tock.Field.add pt acc
            else acc)
            (i + 1)
      in
      go Tock.Field.one Tock.Field.zero 0
    in
    fun hash proof ->
      Tock.prove (Lazy.force Wrap.proving_key) (Wrap.input ())
        { Wrap.Prover_state.proof }
        Wrap.main
        (embed hash)

  let step ~prev_proof ~prev_state block =
    let prev_proof = wrap (instance_hash prev_state) prev_proof in
    let next_state = System.State.update_exn prev_state block in
    Tick.prove (Lazy.force Step.proving_key) (Step.input ())
      { Step.Prover_state.prev_proof
      ; wrap_vk = Lazy.force Wrap.verification_key
      ; prev_state
      ; update = block
      }
      Step.main
      (instance_hash next_state)
end
