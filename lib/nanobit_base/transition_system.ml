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

    type t [@@deriving sexp]

    val typ : (var, t) Typ.t

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

  module Tock : Tock.Snarkable.Bits.Lossy with type Packed.value = Tock.Field.t
end)
(System : S) =
struct
  let step_input () =
    Tick.Data_spec.[Digest.Tick.Packed.typ (* H(wrap_vk, H(state)) *)
                   ]

  let step_input_size = Tick.Data_spec.size (step_input ())

  let wrap_input () = Tock.Data_spec.[Digest.Tock.Packed.typ]

  module Step_base = struct
    open System

    module Prover_state = struct
      type t =
        { wrap_vk: Tock_curve.Verification_key.t
        ; prev_proof: Tock_curve.Proof.t
        ; prev_state: State.t
        ; update: Update.value }
      [@@deriving fields]
    end

    open Tick
    open Let_syntax

    let input = step_input

    let wrap_vk_length = 11324

    let wrap_vk_typ = Typ.list ~length:wrap_vk_length Boolean.typ

    module Verifier =
      Snarky.Gm_verifier_gadget.Mnt4 (Tick)
        (struct
          let input_size = Tock.Data_spec.size (wrap_input ())
        end)

    let wrap_vk_triple_length =
      bit_length_to_triple_length Verifier.Verification_key_data.bit_length

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
        ~start:Hash_prefix.length_in_triples
        bs

    let compute_top_hash wrap_vk_section state_hash_trips =
      Tick.Pedersen.Checked.Section.extend wrap_vk_section
        ~start:(Hash_prefix.length_in_triples + wrap_vk_triple_length)
        state_hash_trips
      >>| Tick.Pedersen.Checked.Section.to_initial_segment_digest >>| Or_error.ok_exn
      >>| fst

    let prev_state_valid wrap_vk_section wrap_vk_data prev_state_hash =
      let open Let_syntax in
      with_label __LOC__
        (* TODO: Should build compositionally on the prev_state hash (instead of converting to bits) *)
        (let%bind prev_state_hash_trips =
           State.Hash.var_to_triples prev_state_hash
         in
         let%bind prev_top_hash =
           compute_top_hash wrap_vk_section prev_state_hash_trips
           >>= Digest.Tick.choose_preimage_var
           >>| Digest.Tick.Unpacked.var_to_bits
         in
         let%bind other_wrap_vk_data, result =
           Verifier.All_in_one.
           choose_verification_key_data_and_proof_and_check_result
             prev_top_hash
             As_prover.(
               map get_state ~f:(fun {Prover_state.prev_proof; wrap_vk} ->
                   { Verifier.All_in_one.verification_key= wrap_vk
                   ; proof= prev_proof } ))
         in
         let%map () =
           Verifier.Verification_key_data.Checked.Assert.equal wrap_vk_data
             other_wrap_vk_data
         in
         result)

    let provide_witness' typ ~f =
      provide_witness typ As_prover.(map get_state ~f)

    let main (top_hash: Digest.Tick.Packed.var) =
      with_label __LOC__
        (let%bind prev_state =
           provide_witness' State.typ ~f:Prover_state.prev_state
         and update = provide_witness' Update.typ ~f:Prover_state.update in
         let%bind prev_state_hash = State.Checked.hash prev_state in
         let%bind next_state_hash, next_state, `Success success =
           with_label __LOC__
             (State.Checked.update (prev_state_hash, prev_state) update)
         in
         let%bind wrap_vk_data =
           provide_witness' Verifier.Verification_key_data.typ ~f:
             (fun {Prover_state.wrap_vk; _} ->
               Verifier.Verification_key_data.of_verification_key wrap_vk )
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
           prev_state_valid wrap_vk_section wrap_vk_data prev_state_hash
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
    let input = wrap_input

    open Tock

    module Verifier =
      Snarky.Gm_verifier_gadget.Mnt6 (Tock)
        (struct
          let input_size = step_input_size
        end)

    module Prover_state = struct
      type t = {proof: Tick_curve.Proof.t}
    end

    let step_vk_data =
      Verifier.Verification_key_data.of_verification_key
        Step_vk.verification_key

    let step_vk_bits = Verifier.Verification_key_data.to_bits step_vk_data

    (* TODO: Use an online verifier here *)
    let main (input: Digest.Tock.Packed.var) =
      let open Let_syntax in
      with_label __LOC__
        (let%bind vk_data, result =
           (* The use of choose_preimage here is justified since we feed it to the verifier, which doesn't
             depend on which unpacking is provided. *)
           let%bind input =
             Digest.Tock.(choose_preimage_var input >>| Unpacked.var_to_bits)
           in
           Verifier.All_in_one.
           choose_verification_key_data_and_proof_and_check_result input
             As_prover.(
               map get_state ~f:(fun {Prover_state.proof} ->
                   { Verifier.All_in_one.verification_key=
                       Step_vk.verification_key
                   ; proof } ))
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
