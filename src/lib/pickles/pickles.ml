(** Pickles implementation *)

(** See documentation of the {!Mina_wire_types} library *)
module Wire_types = Mina_wire_types.Pickles

module Make_sig (A : Wire_types.Types.S) = struct
  module type S =
    Pickles_intf.S
      with type Side_loaded.Verification_key.Stable.V2.t =
        A.Side_loaded.Verification_key.V2.t
       and type ('a, 'b) Proof.t = ('a, 'b) A.Proof.t
end

module Make_str (_ : Wire_types.Concrete) = struct
  module Endo = Endo
  module P = Proof

  module type Statement_intf = Intf.Statement

  module type Statement_var_intf = Intf.Statement_var

  module type Statement_value_intf = Intf.Statement_value

  module Common = Common
  module Scalar_challenge = Scalar_challenge
  module SC = Scalar_challenge
  open Core_kernel
  open Async_kernel
  open Import
  open Pickles_types
  open Poly_types
  open Hlist
  open Common
  open Backend
  module Backend = Backend
  module Sponge_inputs = Sponge_inputs
  module Util = Util
  module Tick_field_sponge = Tick_field_sponge
  module Impls = Impls
  module Inductive_rule = Inductive_rule
  module Tag = Tag
  module Types_map = Types_map
  module Dirty = Dirty
  module Cache_handle = Cache_handle
  module Step_main_inputs = Step_main_inputs
  module Wrap_main_inputs = Wrap_main_inputs
  module Step_verifier = Step_verifier

  exception Return_digest = Compile.Return_digest

  let verify_promise = Verify.verify

  let verify max_proofs_verified statement key proofs =
    verify_promise max_proofs_verified statement key proofs
    |> Promise.to_deferred

  (* This file (as you can see from the mli) defines a compiler which turns an inductive
     definition of a set into an inductive SNARK system for proving using those rules.

     The two ingredients we use are two SNARKs.
     - A step based SNARK for a field Fp, using the group G1/Fq (whose scalar field is Fp)
     - A DLOG based SNARK for a field Fq, using the group G/Fp (whose scalar field is Fq)

     For convenience in this discussion, let's define
      (F_0, G_0) := (Fp, G1)
      (F_1, G_1) := (Fq, G)
     So ScalarField(G_i) = F_i and G_i / F_{1-i}.

     An inductive set A is defined by a sequence of inductive rules.
     An inductive rule is intuitively described by something of the form

     a1 ∈ A1, ..., an ∈ An
       f [ a0, ... a1 ] a
     ----------------------
             a ∈ A

     where f is a snarky function defined over an Impl with Field.t = Fp
     and each Ai is itself an inductive rule (possibly equal to A itself).

     We pursue the "step" then "wrap" approach for proof composition.

     The main source of complexity is that we must "wrap" proofs whose verifiers are
     slightly different.

     The main sources of complexity are twofold:
     1. Each SNARK verifier includes group operations and scalar field operations.
        This is problematic because the group operations use the base field, which is
        not equal to the scalar field.

        Schematically, from the circuit point-of-view, we can say a proof is
     - a sequence of F_0 elements xs_0
     - a sequence of F_1 elelements xs_1
        and a verifier is a pair of "snarky functions"
     - check_0 : F_0 list -> F_1 list -> unit which uses the Impl with Field.t = F_0
     - check_1 : F_0 list -> F_1 list -> unit which uses the Impl with Field.t = F_1
     - subset_00 : 'a list -> 'a list
     - subset_01 : 'a list -> 'a list
     - subset_10 : 'a list -> 'a list
     - subset_11 : 'a list -> 'a list
        and a proof verifies if
        ( check_0 (subset_00 xs_0) (subset_01 xs_1)  ;
          check_1 (subset_10 xs_0) (subset_11 xs_1) )

        When verifying a proof, we perform the parts of the verifier involving group operations
        and expose as public input the scalar-field elements we need to perform the final checks.

        In the F_0 circuit, we witness xs_0 and xs_1,
        execute `check_0 (subset_00 xs_0) (subset_01 xs_1)` and
        expose `subset_10 xs_0` and `subset_11 xs_1` as public inputs.

        So the "public inputs" contain within them an "unfinalized proof".

        Then, the next time we verify that proof within an F_1 circuit we "finalize" those
        unfinalized proofs by running `check_1 xs_0_subset xs_1_subset`.

        I didn't implement it exactly this way (although in retrospect probably I should have) but
        that's the basic idea.

        **The complexity this causes:**
        When you prove a rule that includes k recursive verifications, you expose k unfinalized
        proofs. So, the shape of a statement depends on how many "predecessor statements" it has
        or in other words, how many verifications were performed within it.

        Say we have an inductive set given by inductive rules R_1, ... R_n such that
        each rule R_i has k_i predecessor statements.

        In the "wrap" circuit, we must be able to verify a proof coming from any of the R_i.
        So, we must pad the statement for the proof we're wrapping to have `max_i k_i`
        unfinalized proof components.

     2. The verifier for each R_i looks a little different depending on the complexity of the "step"
        circuit corresponding to R_i has. Namely, it is dependent on the "domains" H and K for this
        circuit.

        So, when the "wrap" circuit proves the statement,
        "there exists some index i in 1,...,n and a proof P such that verifies(P)"
        "verifies(P)" must also take the index "i", compute the correct domain sizes correspond to rule "i"
        and use *that* in the "verifies" computation.
  *)
  open Kimchi_backend
  module Proof = P

  module Statement_with_proof = struct
    type ('s, 'max_width, _) t =
      (* TODO: use Max local max proofs verified instead of max_width *)
      ('max_width, 'max_width) Proof.t
  end

  module Verification_key = struct
    include Verification_key

    module Id = struct
      include Cache.Wrap.Key.Verification

      let dummy_id = Type_equal.Id.(uid (create ~name:"dummy" sexp_of_opaque))

      let dummy : unit -> t =
        let header =
          { Snark_keys_header.header_version = Snark_keys_header.header_version
          ; kind = { type_ = "verification key"; identifier = "dummy" }
          ; constraint_constants =
              { sub_windows_per_window = 0
              ; ledger_depth = 0
              ; work_delay = 0
              ; block_window_duration_ms = 0
              ; transaction_capacity = Log_2 0
              ; pending_coinbase_depth = 0
              ; coinbase_amount = Unsigned.UInt64.of_int 0
              ; supercharged_coinbase_factor = 0
              ; account_creation_fee = Unsigned.UInt64.of_int 0
              ; fork = None
              }
          ; commits = { mina = ""; marlin = "" }
          ; length = 0
          ; commit_date = ""
          ; constraint_system_hash = ""
          ; identifying_hash = ""
          }
        in
        let t = lazy (dummy_id, header, Md5.digest_string "") in
        fun () -> Lazy.force t
    end

    (* TODO: Make async *)
    let load ~cache id =
      Key_cache.Sync.read cache
        (Key_cache.Sync.Disk_storable.of_binable Id.to_string
           (module Verification_key.Stable.Latest) )
        id
      |> Deferred.return
  end

  module type Proof_intf = Compile.Proof_intf

  module Prover = Compile.Prover

  module Side_loaded = struct
    module V = Verification_key

    module Verification_key = struct
      include Side_loaded_verification_key

      let to_input (t : t) =
        to_input ~field_of_int:Impls.Step.Field.Constant.of_int t

      let of_compiled tag : t =
        let d = Types_map.lookup_compiled tag.Tag.id in
        let actual_wrap_domain_size =
          Common.actual_wrap_domain_size
            ~log_2_domain_size:(Lazy.force d.wrap_vk).domain.log_size_of_group
        in
        { wrap_vk = Some (Lazy.force d.wrap_vk)
        ; wrap_index = Lazy.force d.wrap_key
        ; max_proofs_verified =
            Pickles_base.Proofs_verified.of_nat
              (Nat.Add.n d.max_proofs_verified)
        ; actual_wrap_domain_size
        }

      module Max_width = Width.Max
    end

    let in_circuit tag vk =
      Types_map.set_ephemeral tag { index = `In_circuit vk }

    let in_prover tag vk = Types_map.set_ephemeral tag { index = `In_prover vk }

    let create ~name ~max_proofs_verified ~feature_flags ~typ =
      Types_map.add_side_loaded ~name
        { max_proofs_verified
        ; public_input = typ
        ; branches = Verification_key.Max_branches.n
        ; feature_flags
        }

    module Proof = struct
      include Proof.Proofs_verified_max

      let of_proof : _ Proof.t -> t = Wrap_hack.pad_proof
    end

    let verify_promise (type t) ~(typ : (_, t) Impls.Step.Typ.t)
        (ts : (Verification_key.t * t * Proof.t) list) =
      let m =
        ( module struct
          type nonrec t = t

          let to_field_elements =
            let (Typ typ) = typ in
            fun x -> fst (typ.value_to_fields x)
        end : Intf.Statement_value
          with type t = t )
      in
      (* TODO: This should be the actual max width on a per proof basis *)
      let max_proofs_verified =
        (module Verification_key.Max_width : Nat.Intf
          with type n = Verification_key.Max_width.n )
      in
      with_return (fun { return } ->
          List.map ts ~f:(fun (vk, x, p) ->
              let vk : V.t =
                { commitments = vk.wrap_index
                ; index =
                    ( match vk.wrap_vk with
                    | None ->
                        return
                          (Promise.return
                             (Or_error.errorf
                                "Pickles.verify: wrap_vk not found" ) )
                    | Some x ->
                        x )
                ; data =
                    (* This isn't used in verify_heterogeneous, so we can leave this dummy *)
                    { constraints = 0 }
                }
              in
              Verify.Instance.T (max_proofs_verified, m, vk, x, p) )
          |> Verify.verify_heterogenous )

    let verify ~typ ts = verify_promise ~typ ts |> Promise.to_deferred

    let srs_precomputation () : unit =
      let srs = Tock.Keypair.load_urs () in
      List.iter [ 0; 1; 2 ] ~f:(fun i ->
          Kimchi_bindings.Protocol.SRS.Fq.add_lagrange_basis srs
            (Domain.log2_size (Common.wrap_domains ~proofs_verified:i).h) )
  end

  let compile_with_wrap_main_override_promise =
    Compile.compile_with_wrap_main_override_promise

  let compile_promise ?self ?cache ?disk_keys ?return_early_digest_exception
      ?override_wrap_domain ~public_input ~auxiliary_typ ~branches
      ~max_proofs_verified ~name ~constraint_constants ~choices () =
    compile_with_wrap_main_override_promise ?self ?cache ?disk_keys
      ?return_early_digest_exception ?override_wrap_domain ~public_input
      ~auxiliary_typ ~branches ~max_proofs_verified ~name ~constraint_constants
      ~choices ()

  let compile ?self ?cache ?disk_keys ?override_wrap_domain ~public_input
      ~auxiliary_typ ~branches ~max_proofs_verified ~name ~constraint_constants
      ~choices () =
    let self, cache_handle, proof_module, provers =
      compile_promise ?self ?cache ?disk_keys ?override_wrap_domain
        ~public_input ~auxiliary_typ ~branches ~max_proofs_verified ~name
        ~constraint_constants ~choices ()
    in
    let rec adjust_provers :
        type a1 a2 a3 a4 s1 s2_inner.
           (a1, a2, a3, s1, s2_inner Promise.t) H3_2.T(Prover).t
        -> (a1, a2, a3, s1, s2_inner Deferred.t) H3_2.T(Prover).t = function
      | [] ->
          []
      | prover :: tl ->
          (fun ?handler public_input ->
            Promise.to_deferred (prover ?handler public_input) )
          :: adjust_provers tl
    in
    (self, cache_handle, proof_module, adjust_provers provers)

  module Provers = H3_2.T (Prover)
  module Proof0 = Proof
end

include Wire_types.Make (Make_sig) (Make_str)
