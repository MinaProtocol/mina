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
  val keys : Tick.Groth16.Keypair.t
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
  let step_input () = Tick.Groth16.Data_spec.[Tick.Groth16.Field.typ]

  let step_input_size = Tick.Groth16.Data_spec.size (step_input ())

  module Step_base = struct
    open System

    module Prover_state = struct
      type t =
        { wrap_vk: Tock.Verification_key.t
        ; prev_proof: Tock.Proof.t
        ; prev_state: State.value
        ; update: Update.value }
      [@@deriving fields]
    end

    open Tick
    open Let_syntax

    let input = step_input

    let wrap_vk_length = 11324

    let wrap_vk_typ = Typ.list ~length:wrap_vk_length Boolean.typ

    module Verifier = Tick.Groth_maller_verifier

    let wrap_input_size = Tock.Data_spec.size [Wrap_input.typ]

    let wrap_vk_triple_length =
      Verifier.Verification_key.summary_length_in_bits
        ~twist_extension_degree:3 ~input_size:wrap_input_size
      |> bit_length_to_triple_length

    let hash_vk vk =
      let%bind bs =
        Verifier.Verification_key.(summary (summary_input vk))
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

    let%snarkydef prev_state_valid wrap_vk_section wrap_vk prev_state_hash =
      let open Let_syntax in
      (* TODO: Should build compositionally on the prev_state hash (instead of converting to bits) *)
      let%bind prev_state_hash_trips =
        State.Hash.var_to_triples prev_state_hash
      in
      let%bind prev_top_hash =
        compute_top_hash wrap_vk_section prev_state_hash_trips
        >>= Wrap_input.Checked.tick_field_to_scalars
      in
      let%bind precomp =
        Verifier.Verification_key.Precomputation.create wrap_vk
      in
      let%bind proof =
        provide_witness Verifier.Proof.typ
          As_prover.(
            map get_state
              ~f:
                (Fn.compose Verifier.proof_of_backend_proof
                   Prover_state.prev_proof))
      in
      Verifier.verify wrap_vk precomp prev_top_hash proof

    let provide_witness' typ ~f =
      provide_witness typ As_prover.(map get_state ~f)

    let%snarkydef main (top_hash : Digest.Tick.Packed.var) =
      let%bind prev_state =
        provide_witness' State.typ ~f:Prover_state.prev_state
      and update = provide_witness' Update.typ ~f:Prover_state.update in
      let%bind prev_state_hash = State.Checked.hash prev_state in
      let%bind next_state_hash, _next_state, `Success success =
        with_label __LOC__
          (State.Checked.update (prev_state_hash, prev_state) update)
      in
      let%bind wrap_vk =
        provide_witness'
          (Verifier.Verification_key.typ ~input_size:wrap_input_size)
          ~f:(fun {Prover_state.wrap_vk; _} ->
            Verifier.vk_of_backend_vk wrap_vk )
      in
      let%bind wrap_vk_section = hash_vk wrap_vk in
      let%bind () =
        with_label __LOC__
          (let%bind sh = State.Hash.var_to_triples next_state_hash in
           (* We could be reusing the intermediate state of the hash on sh here instead of
               hashing anew *)
           compute_top_hash wrap_vk_section sh
           >>= Field.Checked.Assert.equal top_hash)
      in
      let%bind prev_state_valid =
        prev_state_valid wrap_vk_section wrap_vk prev_state_hash
      in
      let%bind inductive_case_passed =
        with_label __LOC__ Boolean.(prev_state_valid && success)
      in
      let%bind is_base_case = State.Checked.is_base_hash next_state_hash in
      with_label __LOC__
        (Boolean.Assert.any [is_base_case; inductive_case_passed])
  end

  module Step (Tick_keypair : Tick_keypair_intf) = struct
    include Step_base
    include Tick_keypair
  end

  module type Step_vk_intf = sig
    val verification_key : Tick.Groth16.Verification_key.t
  end

  module Wrap_base (Step_vk : Step_vk_intf) = struct
    open Tock

    let input = Tock.Data_spec.[Wrap_input.typ]

    module Verifier = Tock.Groth_verifier

    module Prover_state = struct
      type t = {proof: Tick.Groth16.Proof.t} [@@deriving fields]
    end

    let step_vk = Verifier.vk_of_backend_vk Step_vk.verification_key

    let step_vk_precomp =
      Verifier.Verification_key.Precomputation.create_constant step_vk

    let step_vk_constant =
      let open Verifier.Verification_key in
      let {query_base; query; delta; alpha_beta} = step_vk in
      { Verifier.Verification_key.query_base=
          Inner_curve.Checked.constant query_base
      ; query= List.map ~f:Inner_curve.Checked.constant query
      ; delta= Pairing.G2.constant delta
      ; alpha_beta= Pairing.Fqk.constant alpha_beta }

    (* TODO: Use an online verifier here *)
    let%snarkydef main (input : Wrap_input.var) =
      let open Let_syntax in
      let%bind result =
        (* The use of choose_preimage here is justified since we feed it to the verifier, which doesn't
             depend on which unpacking is provided. *)
        let%bind input = Wrap_input.Checked.to_scalar input in
        let%bind proof =
          exists Verifier.Proof.typ
            ~compute:
              As_prover.(
                map get_state
                  ~f:
                    (Fn.compose Verifier.proof_of_backend_proof
                       Prover_state.proof))
        in
        Verifier.verify step_vk_constant step_vk_precomp [input] proof
      in
      with_label __LOC__ (Boolean.Assert.is_true result)
  end

  module Wrap (Step_vk : Step_vk_intf) (Tock_keypair : Tock_keypair_intf) =
  struct
    include Wrap_base (Step_vk)
    include Tock_keypair
  end
end
