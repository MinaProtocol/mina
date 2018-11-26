open Core_kernel
open Util
open Snark_params
open Tuple_lib

module type S = sig
  open Tick

  module Update : Snarkable.S

  module State : sig
    module Hash : sig
      type t [@@deriving sexp]

      type var

      val typ : (var, t) Typ.t

      val var_to_triples : var -> (Boolean.var Triple.t list, _) Checked.t
    end

    type var

    type value [@@deriving sexp]

    val typ : (var, value) Typ.t

    module Checked : sig
      val hash : var -> (Hash.var, _) Checked.t

      val is_base_hash : Hash.var -> (Boolean.var, _) Checked.t

      val update :
           Hash.var * var
        -> Update.var
        -> (Hash.var * var * [`Success of Boolean.var], _) Checked.t
    end
  end
end

module type Tick_keypair_intf = sig
  val keys : Tick.Keypair.t
end

module type Tock_keypair_intf = sig
  val keys : Tock.Keypair.t
end

(* Someday:
   Tighten this up. Doing this with all these equalities is kind of a hack, but
   doing it right required an annoying change to the bits intf. *)
module Make (Digest : sig
  module Tick :
    Tick.Snarkable.Bits.Lossy
    with type Packed.var = Tick.Field.Checked.t
     and type Packed.value = Tick.Pedersen.Digest.t
end)
(System : S) =
struct
  let step_input () =
    Tick.Data_spec.[Digest.Tick.Packed.typ (* H(wrap_vk, H(state)) *)
                   ]

  let step_input_size = Tick.Data_spec.size (step_input ())

  module Step_base = struct
    open System

    module Prover_state = struct
      type t =
        { wrap_vk: Tock_backend.Verification_key.t
        ; prev_proof: Tock_backend.Proof.t
        ; prev_state: State.value
        ; update: Update.value }
      [@@deriving fields]
    end

    open Tick
    open Let_syntax

    let input = step_input

    let wrap_vk_length = 11324

    let wrap_vk_typ = Typ.list ~length:wrap_vk_length Boolean.typ

    module Verifier = Tick.Verifier_gadget

    let wrap_vk_triple_length =
      bit_length_to_triple_length
        Verifier.Verification_key_data.full_bit_length

    let hash_vk_data data =
      let%bind bs =
        Verifier.Verification_key_data.Checked.to_bits data
        >>| Bitstring_lib.Bitstring.pad_to_triple_list ~default:Boolean.false_
      in
      Pedersen.Checked.Section.extend
        (Pedersen.Checked.Section.create
           ~acc:(`Value Hash_prefix.transition_system_snark.acc)
           ~support:
             (Interval_union.of_interval (0, Hash_prefix.length_in_triples)))
        ~start:Hash_prefix.length_in_triples bs

    let compute_top_hash wrap_vk_section state_hash_trips =
      Tick.Pedersen.Checked.Section.extend wrap_vk_section
        ~start:(Hash_prefix.length_in_triples + wrap_vk_triple_length)
        state_hash_trips
      >>| Tick.Pedersen.Checked.Section.to_initial_segment_digest
      >>| Or_error.ok_exn >>| fst

    let prev_state_valid wrap_vk_section wrap_vk wrap_vk_data prev_state_hash =
      let open Let_syntax in
      with_label __LOC__
        (* TODO: Should build compositionally on the prev_state hash (instead of converting to bits) *)
        (let%bind prev_state_hash_trips =
           State.Hash.var_to_triples prev_state_hash
         in
         let%bind prev_top_hash =
           compute_top_hash wrap_vk_section prev_state_hash_trips
           >>= Wrap_input.Checked.tick_field_to_scalars
         in
         let%bind other_wrap_vk_data, result =
           Verifier.All_in_one.check_proof wrap_vk
             ~get_vk:As_prover.(map get_state ~f:Prover_state.wrap_vk)
             ~get_proof:As_prover.(map get_state ~f:Prover_state.prev_proof)
             prev_top_hash
         in
         let%map () =
           Verifier.Verification_key_data.Checked.Assert.equal wrap_vk_data
             other_wrap_vk_data
         in
         result)

    let provide_witness' typ ~f =
      provide_witness typ As_prover.(map get_state ~f)

    let main (top_hash : Digest.Tick.Packed.var) =
      with_label __LOC__
        (let%bind prev_state =
           provide_witness' State.typ ~f:Prover_state.prev_state
         and update = provide_witness' Update.typ ~f:Prover_state.update in
         let%bind prev_state_hash = State.Checked.hash prev_state in
         let%bind next_state_hash, _next_state, `Success success =
           with_label __LOC__
             (State.Checked.update (prev_state_hash, prev_state) update)
         in
         let%bind wrap_vk =
           provide_witness' Verifier.Verification_key.typ
             ~f:(fun {Prover_state.wrap_vk; _} ->
               Verifier.Verification_key.of_verification_key wrap_vk )
         in
         let wrap_vk_data =
           Verifier.Verification_key.Checked.to_full_data wrap_vk
         in
         let%bind wrap_vk_section = hash_vk_data wrap_vk_data in
         let%bind () =
           with_label __LOC__
             (let%bind sh = State.Hash.var_to_triples next_state_hash in
              (* We could be reusing the intermediate state of the hash on sh here instead of
               hashing anew *)
              compute_top_hash wrap_vk_section sh
              >>= Field.Checked.Assert.equal top_hash)
         in
         let%bind prev_state_valid =
           prev_state_valid wrap_vk_section wrap_vk wrap_vk_data
             prev_state_hash
         in
         let%bind inductive_case_passed =
           with_label __LOC__ Boolean.(prev_state_valid && success)
         in
         let%bind is_base_case = State.Checked.is_base_hash next_state_hash in
         with_label __LOC__
           (Boolean.Assert.any [is_base_case; inductive_case_passed]))
  end

  module Step (Tick_keypair : Tick_keypair_intf) = struct
    include Step_base
    include Tick_keypair
  end

  module type Step_vk_intf = sig
    val verification_key : Tick.Verification_key.t
  end

  module Wrap_base (Step_vk : Step_vk_intf) = struct
    open Tock

    let input = Tock.Data_spec.[Wrap_input.typ]

    module Verifier = Tock.Verifier_gadget

    module Prover_state = struct
      type t = {proof: Tick_backend.Proof.t} [@@deriving fields]
    end

    let step_vk_data =
      Verifier.Verification_key_data.full_data_of_verification_key
        Step_vk.verification_key

    let step_vk_bits = Verifier.Verification_key_data.to_bits step_vk_data

    (* TODO: Use an online verifier here *)
    let main (input : Wrap_input.var) =
      let open Let_syntax in
      with_label __LOC__
        (let%bind vk_data, result =
           (* The use of choose_preimage here is justified since we feed it to the verifier, which doesn't
             depend on which unpacking is provided. *)
           let%bind input = Wrap_input.Checked.to_scalar input in
           Verifier.All_in_one.check_proof
             Verifier.Verification_key.(
               Checked.constant (of_verification_key Step_vk.verification_key))
             ~get_vk:(As_prover.return Step_vk.verification_key)
             ~get_proof:As_prover.(map get_state ~f:Prover_state.proof)
             [input]
         in
         let%bind () =
           let open Verifier.Verification_key_data.Checked in
           Assert.equal vk_data (constant step_vk_data)
         in
         with_label __LOC__ (Boolean.Assert.is_true result))
  end

  module Wrap (Step_vk : Step_vk_intf) (Tock_keypair : Tock_keypair_intf) =
  struct
    include Wrap_base (Step_vk)
    include Tock_keypair
  end
end
