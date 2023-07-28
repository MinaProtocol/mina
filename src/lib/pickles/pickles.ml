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
  module Step_verifier = Step_verifier
  module Ro = Ro

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
        ; feature_flags =
            Plonk_types.(Features.to_full ~or_:Opt.Flag.( ||| ) feature_flags)
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
        type a1 a2 a3 s1 s2_inner.
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

  let%test_module "test no side-loaded" =
    ( module struct
      let () = Tock.Keypair.set_urs_info []

      let () = Tick.Keypair.set_urs_info []

      let () = Backtrace.elide := false

      open Impls.Step

      let () = Snarky_backendless.Snark0.set_eval_constraints true

      (* Currently, a circuit must have at least 1 of every type of constraint. *)
      let dummy_constraints () =
        Impl.(
          let x =
            exists Field.typ ~compute:(fun () -> Field.Constant.of_int 3)
          in
          let g =
            exists Step_main_inputs.Inner_curve.typ ~compute:(fun _ ->
                Tick.Inner_curve.(to_affine_exn one) )
          in
          ignore
            ( SC.to_field_checked'
                (module Impl)
                ~num_bits:16
                (Kimchi_backend_common.Scalar_challenge.create x)
              : Field.t * Field.t * Field.t ) ;
          ignore
            ( Step_main_inputs.Ops.scale_fast g ~num_bits:5 (Shifted_value x)
              : Step_main_inputs.Inner_curve.t ) ;
          ignore
            ( Step_main_inputs.Ops.scale_fast g ~num_bits:5 (Shifted_value x)
              : Step_main_inputs.Inner_curve.t ) ;
          ignore
            ( Step_verifier.Scalar_challenge.endo g ~num_bits:4
                (Kimchi_backend_common.Scalar_challenge.create x)
              : Field.t * Field.t ))

      module No_recursion = struct
        let[@warning "-45"] tag, _, p, Provers.[ step ] =
          Common.time "compile" (fun () ->
              compile_promise () ~public_input:(Input Field.typ)
                ~auxiliary_typ:Typ.unit
                ~branches:(module Nat.N1)
                ~max_proofs_verified:(module Nat.N0)
                ~name:"blockchain-snark"
                ~constraint_constants:
                  (* Dummy values *)
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
                ~choices:(fun ~self:_ ->
                  [ { identifier = "main"
                    ; prevs = []
                    ; feature_flags = Plonk_types.Features.none_bool
                    ; main =
                        (fun { public_input = self } ->
                          dummy_constraints () ;
                          Field.Assert.equal self Field.zero ;
                          { previous_proof_statements = []
                          ; public_output = ()
                          ; auxiliary_output = ()
                          } )
                    }
                  ] ) )

        module Proof = (val p)

        let example =
          let (), (), b0 =
            Common.time "b0" (fun () ->
                Promise.block_on_async_exn (fun () -> step Field.Constant.zero) )
          in
          Or_error.ok_exn
            (Promise.block_on_async_exn (fun () ->
                 Proof.verify_promise [ (Field.Constant.zero, b0) ] ) ) ;
          (Field.Constant.zero, b0)

        let _example_input, _example_proof = example
      end

      module No_recursion_return = struct
        let[@warning "-45"] tag, _, p, Provers.[ step ] =
          Common.time "compile" (fun () ->
              compile_promise () ~public_input:(Output Field.typ)
                ~auxiliary_typ:Typ.unit
                ~branches:(module Nat.N1)
                ~max_proofs_verified:(module Nat.N0)
                ~name:"blockchain-snark"
                ~constraint_constants:
                  (* Dummy values *)
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
                ~choices:(fun ~self:_ ->
                  [ { identifier = "main"
                    ; prevs = []
                    ; feature_flags = Plonk_types.Features.none_bool
                    ; main =
                        (fun _ ->
                          dummy_constraints () ;
                          { previous_proof_statements = []
                          ; public_output = Field.zero
                          ; auxiliary_output = ()
                          } )
                    }
                  ] ) )

        module Proof = (val p)

        let example =
          let res, (), b0 =
            Common.time "b0" (fun () ->
                Promise.block_on_async_exn (fun () -> step ()) )
          in
          assert (Field.Constant.(equal zero) res) ;
          Or_error.ok_exn
            (Promise.block_on_async_exn (fun () ->
                 Proof.verify_promise [ (res, b0) ] ) ) ;
          (res, b0)

        let _example_input, _example_proof = example
      end

      [@@@warning "-60"]

      module Simple_chain = struct
        type _ Snarky_backendless.Request.t +=
          | Prev_input : Field.Constant.t Snarky_backendless.Request.t
          | Proof : (Nat.N1.n, Nat.N1.n) Proof.t Snarky_backendless.Request.t

        let handler (prev_input : Field.Constant.t) (proof : _ Proof.t)
            (Snarky_backendless.Request.With { request; respond }) =
          match request with
          | Prev_input ->
              respond (Provide prev_input)
          | Proof ->
              respond (Provide proof)
          | _ ->
              respond Unhandled

        let[@warning "-45"] _tag, _, p, Provers.[ step ] =
          Common.time "compile" (fun () ->
              compile_promise () ~public_input:(Input Field.typ)
                ~auxiliary_typ:Typ.unit
                ~branches:(module Nat.N1)
                ~max_proofs_verified:(module Nat.N1)
                ~name:"blockchain-snark"
                ~constraint_constants:
                  (* Dummy values *)
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
                ~choices:(fun ~self ->
                  [ { identifier = "main"
                    ; prevs = [ self ]
                    ; feature_flags = Plonk_types.Features.none_bool
                    ; main =
                        (fun { public_input = self } ->
                          let prev =
                            exists Field.typ ~request:(fun () -> Prev_input)
                          in
                          let proof =
                            exists (Typ.Internal.ref ()) ~request:(fun () ->
                                Proof )
                          in
                          let is_base_case = Field.equal Field.zero self in
                          let proof_must_verify = Boolean.not is_base_case in
                          let self_correct = Field.(equal (one + prev) self) in
                          Boolean.Assert.any [ self_correct; is_base_case ] ;
                          { previous_proof_statements =
                              [ { public_input = prev
                                ; proof
                                ; proof_must_verify
                                }
                              ]
                          ; public_output = ()
                          ; auxiliary_output = ()
                          } )
                    }
                  ] ) )

        module Proof = (val p)

        let example =
          let s_neg_one = Field.Constant.(negate one) in
          let b_neg_one : (Nat.N1.n, Nat.N1.n) Proof0.t =
            Proof0.dummy Nat.N1.n Nat.N1.n Nat.N1.n ~domain_log2:14
          in
          let (), (), b0 =
            Common.time "b0" (fun () ->
                Promise.block_on_async_exn (fun () ->
                    step
                      ~handler:(handler s_neg_one b_neg_one)
                      Field.Constant.zero ) )
          in
          Or_error.ok_exn
            (Promise.block_on_async_exn (fun () ->
                 Proof.verify_promise [ (Field.Constant.zero, b0) ] ) ) ;
          let (), (), b1 =
            Common.time "b1" (fun () ->
                Promise.block_on_async_exn (fun () ->
                    step
                      ~handler:(handler Field.Constant.zero b0)
                      Field.Constant.one ) )
          in
          Or_error.ok_exn
            (Promise.block_on_async_exn (fun () ->
                 Proof.verify_promise [ (Field.Constant.one, b1) ] ) ) ;
          (Field.Constant.one, b1)

        let _example_input, _example_proof = example
      end

      module Tree_proof = struct
        type _ Snarky_backendless.Request.t +=
          | No_recursion_input : Field.Constant.t Snarky_backendless.Request.t
          | No_recursion_proof :
              (Nat.N0.n, Nat.N0.n) Proof.t Snarky_backendless.Request.t
          | Recursive_input : Field.Constant.t Snarky_backendless.Request.t
          | Recursive_proof :
              (Nat.N2.n, Nat.N2.n) Proof.t Snarky_backendless.Request.t

        let handler
            ((no_recursion_input, no_recursion_proof) :
              Field.Constant.t * _ Proof.t )
            ((recursion_input, recursion_proof) : Field.Constant.t * _ Proof.t)
            (Snarky_backendless.Request.With { request; respond }) =
          match request with
          | No_recursion_input ->
              respond (Provide no_recursion_input)
          | No_recursion_proof ->
              respond (Provide no_recursion_proof)
          | Recursive_input ->
              respond (Provide recursion_input)
          | Recursive_proof ->
              respond (Provide recursion_proof)
          | _ ->
              respond Unhandled

        let[@warning "-45"] _tag, _, p, Provers.[ step ] =
          Common.time "compile" (fun () ->
              compile_promise () ~public_input:(Input Field.typ)
                ~override_wrap_domain:Pickles_base.Proofs_verified.N1
                ~auxiliary_typ:Typ.unit
                ~branches:(module Nat.N1)
                ~max_proofs_verified:(module Nat.N2)
                ~name:"blockchain-snark"
                ~constraint_constants:
                  (* Dummy values *)
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
                ~choices:(fun ~self ->
                  [ { identifier = "main"
                    ; feature_flags = Plonk_types.Features.none_bool
                    ; prevs = [ No_recursion.tag; self ]
                    ; main =
                        (fun { public_input = self } ->
                          let no_recursive_input =
                            exists Field.typ ~request:(fun () ->
                                No_recursion_input )
                          in
                          let no_recursive_proof =
                            exists (Typ.Internal.ref ()) ~request:(fun () ->
                                No_recursion_proof )
                          in
                          let prev =
                            exists Field.typ ~request:(fun () ->
                                Recursive_input )
                          in
                          let prev_proof =
                            exists (Typ.Internal.ref ()) ~request:(fun () ->
                                Recursive_proof )
                          in
                          let is_base_case = Field.equal Field.zero self in
                          let proof_must_verify = Boolean.not is_base_case in
                          let self_correct = Field.(equal (one + prev) self) in
                          Boolean.Assert.any [ self_correct; is_base_case ] ;
                          { previous_proof_statements =
                              [ { public_input = no_recursive_input
                                ; proof = no_recursive_proof
                                ; proof_must_verify = Boolean.true_
                                }
                              ; { public_input = prev
                                ; proof = prev_proof
                                ; proof_must_verify
                                }
                              ]
                          ; public_output = ()
                          ; auxiliary_output = ()
                          } )
                    }
                  ] ) )

        module Proof = (val p)

        let example1, example2 =
          let s_neg_one = Field.Constant.(negate one) in
          let b_neg_one : (Nat.N2.n, Nat.N2.n) Proof0.t =
            Proof0.dummy Nat.N2.n Nat.N2.n Nat.N2.n ~domain_log2:15
          in
          let (), (), b0 =
            Common.time "tree b0" (fun () ->
                Promise.block_on_async_exn (fun () ->
                    step
                      ~handler:
                        (handler No_recursion.example (s_neg_one, b_neg_one))
                      Field.Constant.zero ) )
          in
          Or_error.ok_exn
            (Promise.block_on_async_exn (fun () ->
                 Proof.verify_promise [ (Field.Constant.zero, b0) ] ) ) ;
          let (), (), b1 =
            Common.time "tree b1" (fun () ->
                Promise.block_on_async_exn (fun () ->
                    step
                      ~handler:
                        (handler No_recursion.example (Field.Constant.zero, b0))
                      Field.Constant.one ) )
          in
          ((Field.Constant.zero, b0), (Field.Constant.one, b1))

        let examples = [ example1; example2 ]

        let _example1_input, _example_proof = example1

        let _example2_input, _example2_proof = example2
      end

      let%test_unit "verify" =
        Or_error.ok_exn
          (Promise.block_on_async_exn (fun () ->
               Tree_proof.Proof.verify_promise Tree_proof.examples ) )

      module Tree_proof_return = struct
        type _ Snarky_backendless.Request.t +=
          | Is_base_case : bool Snarky_backendless.Request.t
          | No_recursion_input : Field.Constant.t Snarky_backendless.Request.t
          | No_recursion_proof :
              (Nat.N0.n, Nat.N0.n) Proof.t Snarky_backendless.Request.t
          | Recursive_input : Field.Constant.t Snarky_backendless.Request.t
          | Recursive_proof :
              (Nat.N2.n, Nat.N2.n) Proof.t Snarky_backendless.Request.t

        let handler (is_base_case : bool)
            ((no_recursion_input, no_recursion_proof) :
              Field.Constant.t * _ Proof.t )
            ((recursion_input, recursion_proof) : Field.Constant.t * _ Proof.t)
            (Snarky_backendless.Request.With { request; respond }) =
          match request with
          | Is_base_case ->
              respond (Provide is_base_case)
          | No_recursion_input ->
              respond (Provide no_recursion_input)
          | No_recursion_proof ->
              respond (Provide no_recursion_proof)
          | Recursive_input ->
              respond (Provide recursion_input)
          | Recursive_proof ->
              respond (Provide recursion_proof)
          | _ ->
              respond Unhandled

        let[@warning "-45"] _tag, _, p, Provers.[ step ] =
          Common.time "compile" (fun () ->
              compile_promise () ~public_input:(Output Field.typ)
                ~override_wrap_domain:Pickles_base.Proofs_verified.N1
                ~auxiliary_typ:Typ.unit
                ~branches:(module Nat.N1)
                ~max_proofs_verified:(module Nat.N2)
                ~name:"blockchain-snark"
                ~constraint_constants:
                  (* Dummy values *)
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
                ~choices:(fun ~self ->
                  [ { identifier = "main"
                    ; feature_flags = Plonk_types.Features.none_bool
                    ; prevs = [ No_recursion_return.tag; self ]
                    ; main =
                        (fun { public_input = () } ->
                          let no_recursive_input =
                            exists Field.typ ~request:(fun () ->
                                No_recursion_input )
                          in
                          let no_recursive_proof =
                            exists (Typ.Internal.ref ()) ~request:(fun () ->
                                No_recursion_proof )
                          in
                          let prev =
                            exists Field.typ ~request:(fun () ->
                                Recursive_input )
                          in
                          let prev_proof =
                            exists (Typ.Internal.ref ()) ~request:(fun () ->
                                Recursive_proof )
                          in
                          let is_base_case =
                            exists Boolean.typ ~request:(fun () -> Is_base_case)
                          in
                          let proof_must_verify = Boolean.not is_base_case in
                          let self =
                            Field.(
                              if_ is_base_case ~then_:zero ~else_:(one + prev))
                          in
                          { previous_proof_statements =
                              [ { public_input = no_recursive_input
                                ; proof = no_recursive_proof
                                ; proof_must_verify = Boolean.true_
                                }
                              ; { public_input = prev
                                ; proof = prev_proof
                                ; proof_must_verify
                                }
                              ]
                          ; public_output = self
                          ; auxiliary_output = ()
                          } )
                    }
                  ] ) )

        module Proof = (val p)

        let example1, example2 =
          let s_neg_one = Field.Constant.(negate one) in
          let b_neg_one : (Nat.N2.n, Nat.N2.n) Proof0.t =
            Proof0.dummy Nat.N2.n Nat.N2.n Nat.N2.n ~domain_log2:15
          in
          let s0, (), b0 =
            Common.time "tree b0" (fun () ->
                Promise.block_on_async_exn (fun () ->
                    step
                      ~handler:
                        (handler true No_recursion_return.example
                           (s_neg_one, b_neg_one) )
                      () ) )
          in
          assert (Field.Constant.(equal zero) s0) ;
          Or_error.ok_exn
            (Promise.block_on_async_exn (fun () ->
                 Proof.verify_promise [ (s0, b0) ] ) ) ;
          let s1, (), b1 =
            Common.time "tree b1" (fun () ->
                Promise.block_on_async_exn (fun () ->
                    step
                      ~handler:
                        (handler false No_recursion_return.example (s0, b0))
                      () ) )
          in
          assert (Field.Constant.(equal one) s1) ;
          ((s0, b0), (s1, b1))

        let examples = [ example1; example2 ]

        let _example1_input, _example1_proof = example1

        let _example2_input, _example2_proof = example2
      end

      let%test_unit "verify" =
        Or_error.ok_exn
          (Promise.block_on_async_exn (fun () ->
               Tree_proof_return.Proof.verify_promise Tree_proof_return.examples )
          )

      module Add_one_return = struct
        let[@warning "-45"] _tag, _, p, Provers.[ step ] =
          Common.time "compile" (fun () ->
              compile_promise ()
                ~public_input:(Input_and_output (Field.typ, Field.typ))
                ~auxiliary_typ:Typ.unit
                ~branches:(module Nat.N1)
                ~max_proofs_verified:(module Nat.N0)
                ~name:"blockchain-snark"
                ~constraint_constants:
                  (* Dummy values *)
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
                ~choices:(fun ~self:_ ->
                  [ { identifier = "main"
                    ; feature_flags = Plonk_types.Features.none_bool
                    ; prevs = []
                    ; main =
                        (fun { public_input = x } ->
                          dummy_constraints () ;
                          { previous_proof_statements = []
                          ; public_output = Field.(add one) x
                          ; auxiliary_output = ()
                          } )
                    }
                  ] ) )

        module Proof = (val p)

        let example =
          let input = Field.Constant.of_int 42 in
          let res, (), b0 =
            Common.time "b0" (fun () ->
                Promise.block_on_async_exn (fun () -> step input) )
          in
          assert (Field.Constant.(equal (of_int 43)) res) ;
          Or_error.ok_exn
            (Promise.block_on_async_exn (fun () ->
                 Proof.verify_promise [ ((input, res), b0) ] ) ) ;
          ((input, res), b0)

        let _example_input, _example_proof = example
      end

      module Auxiliary_return = struct
        let[@warning "-45"] _tag, _, p, Provers.[ step ] =
          Common.time "compile" (fun () ->
              compile_promise ()
                ~public_input:(Input_and_output (Field.typ, Field.typ))
                ~auxiliary_typ:Field.typ
                ~branches:(module Nat.N1)
                ~max_proofs_verified:(module Nat.N0)
                ~name:"blockchain-snark"
                ~constraint_constants:
                  (* Dummy values *)
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
                ~choices:(fun ~self:_ ->
                  [ { identifier = "main"
                    ; feature_flags = Plonk_types.Features.none_bool
                    ; prevs = []
                    ; main =
                        (fun { public_input = input } ->
                          dummy_constraints () ;
                          let sponge =
                            Step_main_inputs.Sponge.create
                              Step_main_inputs.sponge_params
                          in
                          let blinding_value =
                            exists Field.typ ~compute:Field.Constant.random
                          in
                          Step_main_inputs.Sponge.absorb sponge (`Field input) ;
                          Step_main_inputs.Sponge.absorb sponge
                            (`Field blinding_value) ;
                          let result = Step_main_inputs.Sponge.squeeze sponge in
                          { previous_proof_statements = []
                          ; public_output = result
                          ; auxiliary_output = blinding_value
                          } )
                    }
                  ] ) )

        module Proof = (val p)

        let example =
          let input = Field.Constant.of_int 42 in
          let result, blinding_value, b0 =
            Common.time "b0" (fun () ->
                Promise.block_on_async_exn (fun () -> step input) )
          in
          let sponge =
            Tick_field_sponge.Field.create Tick_field_sponge.params
          in
          Tick_field_sponge.Field.absorb sponge input ;
          Tick_field_sponge.Field.absorb sponge blinding_value ;
          let result' = Tick_field_sponge.Field.squeeze sponge in
          assert (Field.Constant.equal result result') ;
          Or_error.ok_exn
            (Promise.block_on_async_exn (fun () ->
                 Proof.verify_promise [ ((input, result), b0) ] ) ) ;
          ((input, result), b0)

        let _example_input, _example_proof = example
      end
    end )

  let%test_module "test uncorrelated bulletproof_challenges" =
    ( module struct
      let () = Backtrace.elide := false

      let () = Snarky_backendless.Snark0.set_eval_constraints true

      module Statement = struct
        type t = unit

        let to_field_elements () = [||]
      end

      module A = Statement
      module A_value = Statement

      let typ = Impls.Step.Typ.unit

      module Branches = Nat.N1
      module Max_proofs_verified = Nat.N2

      let constraint_constants : Snark_keys_header.Constraint_constants.t =
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

      let tag =
        let tagname = "" in
        Tag.create ~kind:Compiled tagname

      let rule : _ Inductive_rule.t =
        let open Impls.Step in
        { identifier = "main"
        ; prevs = [ tag; tag ]
        ; main =
            (fun { public_input = () } ->
              let dummy_proof =
                As_prover.Ref.create (fun () ->
                    Proof0.dummy Nat.N2.n Nat.N2.n Nat.N2.n ~domain_log2:15 )
              in
              { previous_proof_statements =
                  [ { public_input = ()
                    ; proof = dummy_proof
                    ; proof_must_verify = Boolean.false_
                    }
                  ; { public_input = ()
                    ; proof = dummy_proof
                    ; proof_must_verify = Boolean.false_
                    }
                  ]
              ; public_output = ()
              ; auxiliary_output = ()
              } )
        ; feature_flags = Plonk_types.Features.none_bool
        }

      module M = struct
        module IR = Inductive_rule.T (A) (A_value) (A) (A_value) (A) (A_value)

        let max_local_max_proofs_verifieds ~self (type n)
            (module Max_proofs_verified : Nat.Intf with type n = n) branches
            choices =
          let module Local_max_proofs_verifieds = struct
            type t = (int, Max_proofs_verified.n) Vector.t
          end in
          let module M =
            H4.Map (IR) (E04 (Local_max_proofs_verifieds))
              (struct
                module V = H4.To_vector (Int)
                module HT = H4.T (Tag)

                module M =
                  H4.Map (Tag) (E04 (Int))
                    (struct
                      let f (type a b c d) (t : (a, b, c, d) Tag.t) : int =
                        if Type_equal.Id.same t.id self then
                          Nat.to_int Max_proofs_verified.n
                        else
                          let (module M) = Types_map.max_proofs_verified t in
                          Nat.to_int M.n
                    end)

                let f :
                    type a b c d.
                    (a, b, c, d) IR.t -> Local_max_proofs_verifieds.t =
                 fun rule ->
                  let (T (_, l)) = HT.length rule.prevs in
                  Vector.extend_front_exn
                    (V.f l (M.f rule.prevs))
                    Max_proofs_verified.n 0
              end)
          in
          let module V = H4.To_vector (Local_max_proofs_verifieds) in
          let padded = V.f branches (M.f choices) |> Vector.transpose in
          (padded, Maxes.m padded)

        module Lazy_keys = struct
          type t =
            (Impls.Step.Keypair.t * Dirty.t) Lazy.t
            * (Kimchi_bindings.Protocol.VerifierIndex.Fp.t * Dirty.t) Lazy.t

          (* TODO Think this is right.. *)
        end

        let compile :
            (   unit
             -> (Max_proofs_verified.n, Max_proofs_verified.n) Proof.t Promise.t
            )
            * _
            * _ =
          let self = tag in
          let snark_keys_header kind constraint_system_hash =
            { Snark_keys_header.header_version =
                Snark_keys_header.header_version
            ; kind
            ; constraint_constants
            ; commits =
                { mina = Mina_version.commit_id
                ; marlin = Mina_version.marlin_commit_id
                }
            ; length = (* This is a dummy, it gets filled in on read/write. *) 0
            ; commit_date = Mina_version.commit_date
            ; constraint_system_hash
            ; identifying_hash =
                (* TODO: Proper identifying hash. *)
                constraint_system_hash
            }
          in
          let T = Max_proofs_verified.eq in
          let prev_varss_n = Branches.n in
          let prev_varss_length : _ Length.t = S Z in
          let T = Nat.eq_exn prev_varss_n Branches.n in
          let padded, (module Maxes) =
            max_local_max_proofs_verifieds
              (module Max_proofs_verified)
              prev_varss_length [ rule ] ~self:self.id
          in
          let full_signature =
            { Full_signature.padded; maxes = (module Maxes) }
          in
          let feature_flags = Plonk_types.Features.Full.none in
          let actual_feature_flags = Plonk_types.Features.none_bool in
          let wrap_domains =
            let module M =
              Wrap_domains.Make (A) (A_value) (A) (A_value) (A) (A_value)
            in
            M.f full_signature prev_varss_n prev_varss_length ~feature_flags
              ~max_proofs_verified:(module Max_proofs_verified)
          in
          let module Branch_data = struct
            type ('vars, 'vals, 'n, 'm) t =
              ( A.t
              , A_value.t
              , A.t
              , A_value.t
              , A.t
              , A_value.t
              , Max_proofs_verified.n
              , Branches.n
              , 'vars
              , 'vals
              , 'n
              , 'm )
              Step_branch_data.t
          end in
          let proofs_verifieds = Vector.singleton 2 in
          let (T inner_step_data as step_data) =
            Step_branch_data.create ~index:0 ~feature_flags
              ~actual_feature_flags ~max_proofs_verified:Max_proofs_verified.n
              ~branches:Branches.n ~self ~public_input:(Input typ)
              ~auxiliary_typ:typ A.to_field_elements A_value.to_field_elements
              rule ~wrap_domains ~proofs_verifieds
          in
          let step_domains = Vector.singleton inner_step_data.domains in
          let step_keypair =
            let etyp =
              Impls.Step.input ~proofs_verified:Max_proofs_verified.n
                ~wrap_rounds:Tock.Rounds.n
            in
            let (T (typ, _conv, conv_inv)) = etyp in
            let main () () =
              let res = inner_step_data.main ~step_domains () in
              Impls.Step.with_label "conv_inv" (fun () -> conv_inv res)
            in
            let open Impls.Step in
            let k_p =
              lazy
                (let cs =
                   constraint_system ~input_typ:Typ.unit ~return_typ:typ main
                 in
                 let cs_hash = Md5.to_hex (R1CS_constraint_system.digest cs) in
                 ( Type_equal.Id.uid self.id
                 , snark_keys_header
                     { type_ = "step-proving-key"
                     ; identifier = inner_step_data.rule.identifier
                     }
                     cs_hash
                 , inner_step_data.index
                 , cs ) )
            in
            let k_v =
              lazy
                (let id, _header, index, cs = Lazy.force k_p in
                 let digest = R1CS_constraint_system.digest cs in
                 ( id
                 , snark_keys_header
                     { type_ = "step-verification-key"
                     ; identifier = inner_step_data.rule.identifier
                     }
                     (Md5.to_hex digest)
                 , index
                 , digest ) )
            in
            Cache.Step.read_or_generate
              ~prev_challenges:
                (Nat.to_int (fst inner_step_data.proofs_verified))
              [] k_p k_v
              (Snarky_backendless.Typ.unit ())
              typ main
          in
          let step_vks =
            lazy
              (Vector.map [ step_keypair ] ~f:(fun (_, vk) ->
                   Tick.Keypair.vk_commitments (fst (Lazy.force vk)) ) )
          in
          let wrap_main _ =
            let module SC' = SC in
            let open Impls.Wrap in
            let open Wrap_main_inputs in
            let x =
              exists Field.typ ~compute:(fun () -> Field.Constant.of_int 3)
            in
            let y =
              exists Field.typ ~compute:(fun () -> Field.Constant.of_int 0)
            in
            let z =
              exists Field.typ ~compute:(fun () -> Field.Constant.of_int 0)
            in
            let g = Inner_curve.one in
            let sponge = Sponge.create sponge_params in
            Sponge.absorb sponge x ;
            ignore (Sponge.squeeze_field sponge : Field.t) ;
            ignore
              ( SC'.to_field_checked'
                  (module Impl)
                  ~num_bits:16
                  (Kimchi_backend_common.Scalar_challenge.create x)
                : Field.t * Field.t * Field.t ) ;
            ignore
              (Ops.scale_fast g ~num_bits:5 (Shifted_value x) : Inner_curve.t) ;
            ignore
              ( Wrap_verifier.Scalar_challenge.endo g ~num_bits:4
                  (Kimchi_backend_common.Scalar_challenge.create x)
                : Field.t * Field.t ) ;
            for _i = 0 to 64000 do
              assert_r1cs x y z
            done
          in
          let (wrap_pk, wrap_vk), disk_key =
            let open Impls.Wrap in
            let (T (typ, conv, _conv_inv)) = input ~feature_flags () in
            let main x () : unit = wrap_main (conv x) in
            let self_id = Type_equal.Id.uid self.id in
            let disk_key_prover =
              lazy
                (let cs =
                   constraint_system ~input_typ:typ ~return_typ:Typ.unit main
                 in
                 let cs_hash = Md5.to_hex (R1CS_constraint_system.digest cs) in
                 ( self_id
                 , snark_keys_header
                     { type_ = "wrap-proving-key"; identifier = "" }
                     cs_hash
                 , cs ) )
            in
            let disk_key_verifier =
              lazy
                (let id, _header, cs = Lazy.force disk_key_prover in
                 let digest = R1CS_constraint_system.digest cs in
                 ( id
                 , snark_keys_header
                     { type_ = "wrap-verification-key"; identifier = "" }
                     (Md5.to_hex digest)
                 , digest ) )
            in
            let r =
              Common.time "wrap read or generate " (fun () ->
                  Cache.Wrap.read_or_generate ~prev_challenges:2 []
                    disk_key_prover disk_key_verifier typ Typ.unit main )
            in
            (r, disk_key_verifier)
          in
          let wrap_vk = Lazy.map wrap_vk ~f:fst in
          let module S = Step.Make (A) (A_value) (Max_proofs_verified) in
          let prover =
            let f :
                   ( unit * (unit * unit)
                   , unit * (unit * unit)
                   , Nat.N2.n * (Nat.N2.n * unit)
                   , Nat.N1.n * (Nat.N1.n * unit) )
                   Branch_data.t
                -> Lazy_keys.t
                -> unit
                -> (Max_proofs_verified.n, Max_proofs_verified.n) Proof.t
                   Promise.t =
             fun (T b as branch_data) (step_pk, step_vk) () ->
              let (_ : (Max_proofs_verified.n, Maxes.ns) Requests.Wrap.t) =
                Requests.Wrap.create ()
              in
              let _, prev_vars_length = b.proofs_verified in
              let step =
                let wrap_vk = Lazy.force wrap_vk in
                S.f branch_data () ~feature_flags ~prevs_length:prev_vars_length
                  ~self ~public_input:(Input typ)
                  ~auxiliary_typ:Impls.Step.Typ.unit ~step_domains
                  ~self_dlog_plonk_index:wrap_vk.commitments
                  (Impls.Step.Keypair.pk (fst (Lazy.force step_pk)))
                  wrap_vk.index
              in
              let pairing_vk = fst (Lazy.force step_vk) in
              let wrap =
                let wrap_vk = Lazy.force wrap_vk in
                let%bind.Promise proof, (), (), _ =
                  step ~maxes:(module Maxes)
                in
                let proof =
                  { proof with
                    statement =
                      { proof.statement with
                        messages_for_next_wrap_proof =
                          Compile.pad_messages_for_next_wrap_proof
                            (module Maxes)
                            proof.statement.messages_for_next_wrap_proof
                      }
                  }
                in
                let%map.Promise proof =
                  (* The prover for wrapping a proof *)
                  let wrap (type actual_branching)
                      ~(max_proofs_verified : Max_proofs_verified.n Nat.t)
                      (module Max_local_max_proofs_verifieds : Hlist.Maxes.S
                        with type ns = Maxes.ns
                         and type length = Max_proofs_verified.n )
                      ~dlog_plonk_index wrap_main to_field_elements ~pairing_vk
                      ~step_domains:_ ~wrap_domains:_ ~pairing_plonk_indices:_
                      pk
                      ({ statement = prev_statement
                       ; prev_evals = _
                       ; proof
                       ; index = _which_index
                       } :
                        ( _
                        , _
                        , (_, actual_branching) Vector.t
                        , (_, actual_branching) Vector.t
                        , Maxes.ns
                          H1.T
                            (P.Base.Messages_for_next_proof_over_same_field.Wrap)
                          .t
                        , ( ( Tock.Field.t
                            , Tock.Field.t array )
                            Plonk_types.All_evals.t
                          , Max_proofs_verified.n )
                          Vector.t )
                        P.Base.Step.t ) =
                    let prev_messages_for_next_wrap_proof =
                      let module M =
                        H1.Map
                          (P.Base.Messages_for_next_proof_over_same_field.Wrap)
                          (P.Base.Messages_for_next_proof_over_same_field.Wrap
                           .Prepared)
                          (struct
                            let f =
                              P.Base.Messages_for_next_proof_over_same_field
                              .Wrap
                              .prepare
                          end)
                      in
                      M.f prev_statement.messages_for_next_wrap_proof
                    in
                    let prev_statement_with_hashes : _ Types.Step.Statement.t =
                      { proof_state =
                          { prev_statement.proof_state with
                            messages_for_next_step_proof =
                              (* TODO: Careful here... the length of
                                 old_buletproof_challenges inside the messages_for_next_wrap_proof
                                 might not be correct *)
                              Common.hash_messages_for_next_step_proof
                                ~app_state:to_field_elements
                                (P.Base.Messages_for_next_proof_over_same_field
                                 .Step
                                 .prepare ~dlog_plonk_index
                                   prev_statement.proof_state
                                     .messages_for_next_step_proof )
                          }
                      ; messages_for_next_wrap_proof =
                          (let module M =
                             H1.Map
                               (P.Base.Messages_for_next_proof_over_same_field
                                .Wrap
                                .Prepared)
                               (E01 (Digest.Constant))
                               (struct
                                 let f (type n)
                                     (m :
                                       n
                                       P.Base
                                       .Messages_for_next_proof_over_same_field
                                       .Wrap
                                       .Prepared
                                       .t ) =
                                   let T =
                                     Nat.eq_exn max_proofs_verified
                                       (Vector.length
                                          m.old_bulletproof_challenges )
                                   in
                                   Wrap_hack.hash_messages_for_next_wrap_proof
                                     max_proofs_verified m
                               end)
                           in
                          let module V = H1.To_vector (Digest.Constant) in
                          V.f Max_local_max_proofs_verifieds.length
                            (M.f prev_messages_for_next_wrap_proof) )
                      }
                    in
                    let module O = Tick.Oracles in
                    let public_input =
                      tick_public_input_of_statement ~max_proofs_verified
                        prev_statement_with_hashes
                    in
                    let prev_challenges =
                      Vector.map ~f:Ipa.Step.compute_challenges
                        prev_statement.proof_state.messages_for_next_step_proof
                          .old_bulletproof_challenges
                    in
                    let actual_proofs_verified =
                      Vector.length prev_challenges
                    in
                    let lte =
                      Nat.lte_exn actual_proofs_verified
                        (Length.to_nat Max_local_max_proofs_verifieds.length)
                    in
                    let o =
                      let sgs =
                        let module M =
                          H1.Map
                            (P.Base.Messages_for_next_proof_over_same_field.Wrap
                             .Prepared)
                            (E01 (Tick.Curve.Affine))
                            (struct
                              let f :
                                  type n.
                                     n
                                     P.Base
                                     .Messages_for_next_proof_over_same_field
                                     .Wrap
                                     .Prepared
                                     .t
                                  -> _ =
                               fun t -> t.challenge_polynomial_commitment
                            end)
                        in
                        let module V = H1.To_vector (Tick.Curve.Affine) in
                        V.f Max_local_max_proofs_verifieds.length
                          (M.f prev_messages_for_next_wrap_proof)
                      in
                      O.create pairing_vk
                        Vector.(
                          map2 (Vector.trim_front sgs lte) prev_challenges
                            ~f:(fun commitment cs ->
                              { Tick.Proof.Challenge_polynomial.commitment
                              ; challenges = Vector.to_array cs
                              } )
                          |> to_list)
                        public_input proof
                    in
                    let x_hat = O.(p_eval_1 o, p_eval_2 o) in
                    let step_vk, _ = Lazy.force step_vk in
                    let next_statement : _ Types.Wrap.Statement.In_circuit.t =
                      let scalar_chal f =
                        Scalar_challenge.map ~f:Challenge.Constant.of_tick_field
                          (f o)
                      in
                      let sponge_digest_before_evaluations =
                        O.digest_before_evaluations o
                      in
                      let plonk0 =
                        { Types.Wrap.Proof_state.Deferred_values.Plonk.Minimal
                          .alpha = scalar_chal O.alpha
                        ; beta = O.beta o
                        ; gamma = O.gamma o
                        ; zeta = scalar_chal O.zeta
                        ; joint_combiner =
                            Option.map (O.joint_combiner_chal o)
                              ~f:
                                (Scalar_challenge.map
                                   ~f:Challenge.Constant.of_tick_field )
                        ; feature_flags = Plonk_types.Features.none_bool
                        }
                      in
                      let r = scalar_chal O.u in
                      let xi = scalar_chal O.v in
                      let to_field =
                        SC.to_field_constant
                          (module Tick.Field)
                          ~endo:Endo.Wrap_inner_curve.scalar
                      in
                      let module As_field = struct
                        let r = to_field r

                        let xi = to_field xi

                        let zeta = to_field plonk0.zeta

                        let alpha = to_field plonk0.alpha

                        let joint_combiner =
                          Option.map ~f:to_field plonk0.joint_combiner
                      end in
                      let domain =
                        Domain.Pow_2_roots_of_unity
                          step_vk.domain.log_size_of_group
                      in
                      let w = step_vk.domain.group_gen in
                      (* Debug *)
                      [%test_eq: Tick.Field.t] w
                        (Tick.Field.domain_generator
                           ~log2_size:(Domain.log2_size domain) ) ;
                      let zetaw = Tick.Field.mul As_field.zeta w in
                      let tick_plonk_minimal =
                        { plonk0 with
                          zeta = As_field.zeta
                        ; alpha = As_field.alpha
                        ; joint_combiner = As_field.joint_combiner
                        }
                      in
                      let tick_combined_evals =
                        Plonk_checks.evals_of_split_evals
                          (module Tick.Field)
                          proof.openings.evals
                          ~rounds:(Nat.to_int Tick.Rounds.n) ~zeta:As_field.zeta
                          ~zetaw
                      in
                      let tick_domain =
                        Plonk_checks.domain
                          (module Tick.Field)
                          domain ~shifts:Common.tick_shifts
                          ~domain_generator:Backend.Tick.Field.domain_generator
                      in
                      let tick_combined_evals =
                        Plonk_types.Evals.to_in_circuit tick_combined_evals
                      in
                      let tick_env =
                        let module Env_bool = struct
                          type t = bool

                          let true_ = true

                          let false_ = false

                          let ( &&& ) = ( && )

                          let ( ||| ) = ( || )

                          let any = List.exists ~f:Fn.id
                        end in
                        let module Env_field = struct
                          include Tick.Field

                          type bool = Env_bool.t

                          let if_ (b : bool) ~then_ ~else_ =
                            if b then then_ () else else_ ()
                        end in
                        Plonk_checks.scalars_env
                          (module Env_bool)
                          (module Env_field)
                          ~endo:Endo.Step_inner_curve.base
                          ~mds:Tick_field_sponge.params.mds
                          ~srs_length_log2:Common.Max_degree.step_log2
                          ~field_of_hex:(fun s ->
                            Kimchi_pasta.Pasta.Bigint256.of_hex_string s
                            |> Kimchi_pasta.Pasta.Fp.of_bigint )
                          ~domain:tick_domain tick_plonk_minimal
                          tick_combined_evals
                      in
                      let combined_inner_product =
                        let open As_field in
                        Wrap.combined_inner_product
                        (* Note: We do not pad here. *)
                          ~actual_proofs_verified:
                            (Nat.Add.create actual_proofs_verified)
                          { evals = proof.openings.evals; public_input = x_hat }
                          ~r ~xi ~zeta ~zetaw
                          ~old_bulletproof_challenges:prev_challenges
                          ~env:tick_env ~domain:tick_domain
                          ~ft_eval1:proof.openings.ft_eval1
                          ~plonk:tick_plonk_minimal
                      in
                      let chal = Challenge.Constant.of_tick_field in
                      let sg_new, new_bulletproof_challenges, b =
                        let prechals =
                          Array.map (O.opening_prechallenges o) ~f:(fun x ->
                              let x =
                                Scalar_challenge.map
                                  ~f:Challenge.Constant.of_tick_field x
                              in
                              x )
                        in
                        let chals =
                          Array.map prechals ~f:(fun x ->
                              Ipa.Step.compute_challenge x )
                        in
                        let challenge_polynomial =
                          unstage (Wrap.challenge_polynomial chals)
                        in
                        let open As_field in
                        let b =
                          let open Tick.Field in
                          challenge_polynomial zeta
                          + (r * challenge_polynomial zetaw)
                        in
                        let overwritten_prechals =
                          Array.map prechals
                            ~f:
                              (Scalar_challenge.map ~f:(fun _ ->
                                   Challenge.Constant.of_tick_field
                                     (Impls.Step.Field.Constant.of_int 100) ) )
                        in
                        let chals =
                          Array.map overwritten_prechals ~f:(fun x ->
                              Ipa.Step.compute_challenge x )
                        in
                        let sg_new =
                          let urs = Backend.Tick.Keypair.load_urs () in
                          Kimchi_bindings.Protocol.SRS.Fp
                          .batch_accumulator_generate urs 1 chals
                        in
                        let[@warning "-4"] sg_new =
                          match sg_new with
                          | [| Kimchi_types.Finite x |] ->
                              x
                          | _ ->
                              assert false
                        in
                        let overwritten_prechals =
                          Array.map overwritten_prechals
                            ~f:Bulletproof_challenge.unpack
                        in

                        (sg_new, overwritten_prechals, b)
                      in
                      let plonk =
                        let module Field = struct
                          include Tick.Field
                        end in
                        Wrap.Type1.derive_plonk
                          (module Field)
                          ~shift:Shifts.tick1 ~env:tick_env tick_plonk_minimal
                          tick_combined_evals
                      in
                      let shift_value =
                        Shifted_value.Type1.of_field
                          (module Tick.Field)
                          ~shift:Shifts.tick1
                      in
                      let branch_data : Composition_types.Branch_data.t =
                        { proofs_verified =
                            ( match actual_proofs_verified with
                            | Z ->
                                Composition_types.Branch_data.Proofs_verified.N0
                            | S Z ->
                                N1
                            | S (S Z) ->
                                N2
                            | S _ ->
                                assert false )
                        ; domain_log2 =
                            Composition_types.Branch_data.Domain_log2.of_int_exn
                              step_vk.domain.log_size_of_group
                        }
                      in
                      let messages_for_next_wrap_proof :
                          _
                          P.Base.Messages_for_next_proof_over_same_field.Wrap.t
                          =
                        { challenge_polynomial_commitment = sg_new
                        ; old_bulletproof_challenges =
                            Vector.map
                              prev_statement.proof_state.unfinalized_proofs
                              ~f:(fun t ->
                                t.deferred_values.bulletproof_challenges )
                        }
                      in
                      { proof_state =
                          { deferred_values =
                              { xi
                              ; b = shift_value b
                              ; bulletproof_challenges =
                                  Vector.of_array_and_length_exn
                                    new_bulletproof_challenges Tick.Rounds.n
                              ; combined_inner_product =
                                  shift_value combined_inner_product
                              ; branch_data
                              ; plonk =
                                  { plonk with
                                    zeta = plonk0.zeta
                                  ; alpha = plonk0.alpha
                                  ; beta = chal plonk0.beta
                                  ; gamma = chal plonk0.gamma
                                  ; joint_combiner = Opt.nothing
                                  }
                              }
                          ; sponge_digest_before_evaluations =
                              Digest.Constant.of_tick_field
                                sponge_digest_before_evaluations
                          ; messages_for_next_wrap_proof
                          }
                      ; messages_for_next_step_proof =
                          prev_statement.proof_state
                            .messages_for_next_step_proof
                      }
                    in
                    let messages_for_next_wrap_proof_prepared =
                      P.Base.Messages_for_next_proof_over_same_field.Wrap
                      .prepare
                        next_statement.proof_state.messages_for_next_wrap_proof
                    in
                    let%map.Promise next_proof =
                      let (T (input, conv, _conv_inv)) =
                        Impls.Wrap.input ~feature_flags ()
                      in
                      Common.time "wrap proof" (fun () ->
                          Impls.Wrap.generate_witness_conv
                            ~f:(fun { Impls.Wrap.Proof_inputs.auxiliary_inputs
                                    ; public_inputs
                                    } () ->
                              Backend.Tock.Proof.create_async
                                ~primary:public_inputs
                                ~auxiliary:auxiliary_inputs pk
                                ~message:
                                  ( Vector.map2
                                      (Vector.extend_front_exn
                                         prev_statement.proof_state
                                           .messages_for_next_step_proof
                                           .challenge_polynomial_commitments
                                         max_proofs_verified
                                         (Lazy.force Dummy.Ipa.Wrap.sg) )
                                      messages_for_next_wrap_proof_prepared
                                        .old_bulletproof_challenges
                                      ~f:(fun sg chals ->
                                        { Tock.Proof.Challenge_polynomial
                                          .commitment = sg
                                        ; challenges = Vector.to_array chals
                                        } )
                                  |> Wrap_hack.pad_accumulator ) )
                            ~input_typ:input
                            ~return_typ:(Snarky_backendless.Typ.unit ())
                            (fun x () : unit -> wrap_main (conv x))
                            { messages_for_next_step_proof =
                                prev_statement_with_hashes.proof_state
                                  .messages_for_next_step_proof
                            ; proof_state =
                                { next_statement.proof_state with
                                  messages_for_next_wrap_proof =
                                    Wrap_hack.hash_messages_for_next_wrap_proof
                                      max_proofs_verified
                                      messages_for_next_wrap_proof_prepared
                                ; deferred_values =
                                    { next_statement.proof_state.deferred_values with
                                      plonk =
                                        { next_statement.proof_state
                                            .deferred_values
                                            .plonk
                                          with
                                          joint_combiner = None
                                        }
                                    }
                                }
                            } )
                    in
                    ( { proof = Wrap_wire_proof.of_kimchi_proof next_proof.proof
                      ; statement =
                          Types.Wrap.Statement.to_minimal
                            ~to_option:Opt.to_option next_statement
                      ; prev_evals =
                          { Plonk_types.All_evals.evals =
                              { public_input = x_hat
                              ; evals = proof.openings.evals
                              }
                          ; ft_eval1 = proof.openings.ft_eval1
                          }
                      }
                      : _ P.Base.Wrap.t )
                  in
                  wrap ~max_proofs_verified:Max_proofs_verified.n
                    full_signature.maxes ~dlog_plonk_index:wrap_vk.commitments
                    wrap_main A_value.to_field_elements ~pairing_vk
                    ~step_domains:b.domains
                    ~pairing_plonk_indices:(Lazy.force step_vks) ~wrap_domains
                    (Impls.Wrap.Keypair.pk (fst (Lazy.force wrap_pk)))
                    proof
                in
                Proof.T
                  { proof with
                    statement =
                      { proof.statement with
                        messages_for_next_step_proof =
                          { proof.statement.messages_for_next_step_proof with
                            app_state = ()
                          }
                      }
                  }
              in
              wrap
            in
            f step_data step_keypair
          in
          let data : _ Types_map.Compiled.t =
            { branches = Branches.n
            ; feature_flags
            ; proofs_verifieds
            ; max_proofs_verified = (module Max_proofs_verified)
            ; public_input = typ
            ; wrap_key = Lazy.map wrap_vk ~f:Verification_key.commitments
            ; wrap_vk = Lazy.map wrap_vk ~f:Verification_key.index
            ; wrap_domains
            ; step_domains
            }
          in
          Types_map.add_exn self data ;
          (prover, wrap_vk, disk_key)
      end

      let step, wrap_vk, wrap_disk_key = M.compile

      module Proof = struct
        module Max_local_max_proofs_verified = Max_proofs_verified
        include Proof.Make (Max_proofs_verified) (Max_local_max_proofs_verified)

        let _id = wrap_disk_key

        let verification_key = wrap_vk

        let verify ts =
          verify_promise
            (module Max_proofs_verified)
            (module A_value)
            (Lazy.force verification_key)
            ts

        let _statement (T p : t) =
          p.statement.messages_for_next_step_proof.app_state
      end

      let proof_with_stmt =
        let p = Promise.block_on_async_exn (fun () -> step ()) in
        ((), p)

      let%test "should not be able to verify invalid proof" =
        Or_error.is_error
        @@ Promise.block_on_async_exn (fun () ->
               Proof.verify [ proof_with_stmt ] )

      module Recurse_on_bad_proof = struct
        open Impls.Step

        let _dummy_proof =
          Proof0.dummy Nat.N2.n Nat.N2.n Nat.N2.n ~domain_log2:15

        type _ Snarky_backendless.Request.t +=
          | Proof : (Nat.N2.n, Nat.N2.n) Proof0.t Snarky_backendless.Request.t

        let handler (proof : _ Proof0.t)
            (Snarky_backendless.Request.With { request; respond }) =
          match request with
          | Proof ->
              respond (Provide proof)
          | _ ->
              respond Unhandled

        let[@warning "-45"] _tag, _, p, Provers.[ step ] =
          Common.time "compile" (fun () ->
              compile_promise () ~public_input:(Input Typ.unit)
                ~auxiliary_typ:Typ.unit
                ~branches:(module Nat.N1)
                ~max_proofs_verified:(module Nat.N2)
                ~name:"recurse-on-bad" ~constraint_constants
                ~choices:(fun ~self:_ ->
                  [ { identifier = "main"
                    ; feature_flags = Plonk_types.Features.none_bool
                    ; prevs = [ tag; tag ]
                    ; main =
                        (fun { public_input = () } ->
                          let proof =
                            exists (Typ.Internal.ref ()) ~request:(fun () ->
                                Proof )
                          in
                          { previous_proof_statements =
                              [ { public_input = ()
                                ; proof
                                ; proof_must_verify = Boolean.true_
                                }
                              ; { public_input = ()
                                ; proof
                                ; proof_must_verify = Boolean.true_
                                }
                              ]
                          ; public_output = ()
                          ; auxiliary_output = ()
                          } )
                    }
                  ] ) )

        module Proof = (val p)
      end

      let%test "should not be able to create a recursive proof from an invalid \
                proof" =
        try
          let (), (), proof =
            Promise.block_on_async_exn (fun () ->
                Recurse_on_bad_proof.step
                  ~handler:(Recurse_on_bad_proof.handler (snd proof_with_stmt))
                  () )
          in
          Or_error.is_error
          @@ Promise.block_on_async_exn (fun () ->
                 Recurse_on_bad_proof.Proof.verify_promise [ ((), proof) ] )
        with _ -> true
    end )

  let%test_module "adversarial_tests" =
    ( module struct
      [@@@warning "-60"]

      let () = Backtrace.elide := false

      let () = Snarky_backendless.Snark0.set_eval_constraints true

      let%test_module "test domain size too large" =
        ( module Compile.Make_adversarial_test (struct
          let tweak_statement (stmt : _ Import.Types.Wrap.Statement.In_circuit.t)
              =
            (* Modify the statement to use an invalid domain size. *)
            { stmt with
              proof_state =
                { stmt.proof_state with
                  deferred_values =
                    { stmt.proof_state.deferred_values with
                      branch_data =
                        { stmt.proof_state.deferred_values.branch_data with
                          Branch_data.domain_log2 =
                            Branch_data.Domain_log2.of_int_exn
                              (Nat.to_int Kimchi_pasta.Basic.Rounds.Step.n + 1)
                        }
                    }
                }
            }

          let check_verifier_error err =
            (* Convert to JSON to make it easy to parse. *)
            err |> Error_json.error_to_yojson
            |> Yojson.Safe.Util.member "multiple"
            |> Yojson.Safe.Util.to_list
            |> List.find_exn ~f:(fun json ->
                   let error =
                     json
                     |> Yojson.Safe.Util.member "string"
                     |> Yojson.Safe.Util.to_string
                   in
                   String.equal error "domain size is small enough" )
            |> fun _ -> ()
        end) )
    end )

  let%test_module "domain too small" =
    ( module struct
      open Impls.Step

      (* Currently, a circuit must have at least 1 of every type of constraint. *)
      let dummy_constraints () =
        Impl.(
          let x =
            exists Field.typ ~compute:(fun () -> Field.Constant.of_int 3)
          in
          let g =
            exists Step_main_inputs.Inner_curve.typ ~compute:(fun _ ->
                Tick.Inner_curve.(to_affine_exn one) )
          in
          ignore
            ( SC.to_field_checked'
                (module Impl)
                ~num_bits:16
                (Kimchi_backend_common.Scalar_challenge.create x)
              : Field.t * Field.t * Field.t ) ;
          ignore
            ( Step_main_inputs.Ops.scale_fast g ~num_bits:5 (Shifted_value x)
              : Step_main_inputs.Inner_curve.t ) ;
          ignore
            ( Step_main_inputs.Ops.scale_fast g ~num_bits:5 (Shifted_value x)
              : Step_main_inputs.Inner_curve.t ) ;
          ignore
            ( Step_verifier.Scalar_challenge.endo g ~num_bits:4
                (Kimchi_backend_common.Scalar_challenge.create x)
              : Field.t * Field.t ))

      module No_recursion = struct
        let[@warning "-45"] tag, _, p, Provers.[ step ] =
          Common.time "compile" (fun () ->
              compile_promise () ~public_input:(Input Field.typ)
                ~auxiliary_typ:Typ.unit
                ~branches:(module Nat.N1)
                ~max_proofs_verified:(module Nat.N0)
                ~name:"blockchain-snark"
                ~constraint_constants:
                  (* Dummy values *)
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
                ~choices:(fun ~self:_ ->
                  [ { identifier = "main"
                    ; prevs = []
                    ; feature_flags = Plonk_types.Features.none_bool
                    ; main =
                        (fun { public_input = self } ->
                          dummy_constraints () ;
                          Field.Assert.equal self Field.zero ;
                          { previous_proof_statements = []
                          ; public_output = ()
                          ; auxiliary_output = ()
                          } )
                    }
                  ] ) )

        module Proof = (val p)

        let example =
          let (), (), b0 =
            Common.time "b0" (fun () ->
                Promise.block_on_async_exn (fun () -> step Field.Constant.zero) )
          in
          Or_error.ok_exn
            (Promise.block_on_async_exn (fun () ->
                 Proof.verify_promise [ (Field.Constant.zero, b0) ] ) ) ;
          (Field.Constant.zero, b0)

        let example_input, example_proof = example
      end

      module Fake_1_recursion = struct
        let[@warning "-45"] tag, _, p, Provers.[ step ] =
          Common.time "compile" (fun () ->
              compile_promise () ~public_input:(Input Field.typ)
                ~auxiliary_typ:Typ.unit
                ~branches:(module Nat.N1)
                ~max_proofs_verified:(module Nat.N1)
                ~name:"blockchain-snark"
                ~constraint_constants:
                  (* Dummy values *)
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
                ~choices:(fun ~self:_ ->
                  [ { identifier = "main"
                    ; prevs = []
                    ; feature_flags = Plonk_types.Features.none_bool
                    ; main =
                        (fun { public_input = self } ->
                          dummy_constraints () ;
                          Field.Assert.equal self Field.zero ;
                          { previous_proof_statements = []
                          ; public_output = ()
                          ; auxiliary_output = ()
                          } )
                    }
                  ] ) )

        module Proof = (val p)

        let example =
          let (), (), b0 =
            Common.time "b0" (fun () ->
                Promise.block_on_async_exn (fun () -> step Field.Constant.zero) )
          in
          Or_error.ok_exn
            (Promise.block_on_async_exn (fun () ->
                 Proof.verify_promise [ (Field.Constant.zero, b0) ] ) ) ;
          (Field.Constant.zero, b0)

        let example_input, example_proof = example
      end

      module Fake_2_recursion = struct
        let[@warning "-45"] tag, _, p, Provers.[ step ] =
          Common.time "compile" (fun () ->
              compile_promise () ~public_input:(Input Field.typ)
                ~override_wrap_domain:Pickles_base.Proofs_verified.N1
                ~auxiliary_typ:Typ.unit
                ~branches:(module Nat.N1)
                ~max_proofs_verified:(module Nat.N2)
                ~name:"blockchain-snark"
                ~constraint_constants:
                  (* Dummy values *)
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
                ~choices:(fun ~self:_ ->
                  [ { identifier = "main"
                    ; prevs = []
                    ; feature_flags = Plonk_types.Features.none_bool
                    ; main =
                        (fun { public_input = self } ->
                          dummy_constraints () ;
                          Field.Assert.equal self Field.zero ;
                          { previous_proof_statements = []
                          ; public_output = ()
                          ; auxiliary_output = ()
                          } )
                    }
                  ] ) )

        module Proof = (val p)

        let example =
          let (), (), b0 =
            Common.time "b0" (fun () ->
                Promise.block_on_async_exn (fun () -> step Field.Constant.zero) )
          in
          Or_error.ok_exn
            (Promise.block_on_async_exn (fun () ->
                 Proof.verify_promise [ (Field.Constant.zero, b0) ] ) ) ;
          (Field.Constant.zero, b0)

        let example_input, example_proof = example
      end

      [@@@warning "-60"]

      module Simple_chain = struct
        type _ Snarky_backendless.Request.t +=
          | Prev_input : Field.Constant.t Snarky_backendless.Request.t
          | Proof : Side_loaded.Proof.t Snarky_backendless.Request.t
          | Verifier_index :
              Side_loaded.Verification_key.t Snarky_backendless.Request.t

        let handler (prev_input : Field.Constant.t) (proof : _ Proof.t)
            (verifier_index : Side_loaded.Verification_key.t)
            (Snarky_backendless.Request.With { request; respond }) =
          match request with
          | Prev_input ->
              respond (Provide prev_input)
          | Proof ->
              respond (Provide proof)
          | Verifier_index ->
              respond (Provide verifier_index)
          | _ ->
              respond Unhandled

        let side_loaded_tag =
          Side_loaded.create ~name:"foo"
            ~max_proofs_verified:(Nat.Add.create Nat.N2.n)
            ~feature_flags:Plonk_types.Features.none ~typ:Field.typ

        let[@warning "-45"] _tag, _, p, Provers.[ step ] =
          Common.time "compile" (fun () ->
              compile_promise () ~public_input:(Input Field.typ)
                ~auxiliary_typ:Typ.unit
                ~branches:(module Nat.N1)
                ~max_proofs_verified:(module Nat.N1)
                ~name:"blockchain-snark"
                ~constraint_constants:
                  (* Dummy values *)
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
                ~choices:(fun ~self:_ ->
                  [ { identifier = "main"
                    ; prevs = [ side_loaded_tag ]
                    ; feature_flags = Plonk_types.Features.none_bool
                    ; main =
                        (fun { public_input = self } ->
                          let prev =
                            exists Field.typ ~request:(fun () -> Prev_input)
                          in
                          let proof =
                            exists (Typ.Internal.ref ()) ~request:(fun () ->
                                Proof )
                          in
                          let vk =
                            exists (Typ.Internal.ref ()) ~request:(fun () ->
                                Verifier_index )
                          in
                          as_prover (fun () ->
                              let vk = As_prover.Ref.get vk in
                              Side_loaded.in_prover side_loaded_tag vk ) ;
                          let vk =
                            exists Side_loaded_verification_key.typ
                              ~compute:(fun () -> As_prover.Ref.get vk)
                          in
                          Side_loaded.in_circuit side_loaded_tag vk ;
                          let is_base_case = Field.equal Field.zero self in
                          let self_correct = Field.(equal (one + prev) self) in
                          Boolean.Assert.any [ self_correct; is_base_case ] ;
                          { previous_proof_statements =
                              [ { public_input = prev
                                ; proof
                                ; proof_must_verify = Boolean.true_
                                }
                              ]
                          ; public_output = ()
                          ; auxiliary_output = ()
                          } )
                    }
                  ] ) )

        module Proof = (val p)

        let _example1 =
          let (), (), b1 =
            Common.time "b1" (fun () ->
                Promise.block_on_async_exn (fun () ->
                    step
                      ~handler:
                        (handler No_recursion.example_input
                           (Side_loaded.Proof.of_proof
                              No_recursion.example_proof )
                           (Side_loaded.Verification_key.of_compiled
                              No_recursion.tag ) )
                      Field.Constant.one ) )
          in
          Or_error.ok_exn
            (Promise.block_on_async_exn (fun () ->
                 Proof.verify_promise [ (Field.Constant.one, b1) ] ) ) ;
          (Field.Constant.one, b1)

        let _example2 =
          let (), (), b2 =
            Common.time "b2" (fun () ->
                Promise.block_on_async_exn (fun () ->
                    step
                      ~handler:
                        (handler Fake_1_recursion.example_input
                           (Side_loaded.Proof.of_proof
                              Fake_1_recursion.example_proof )
                           (Side_loaded.Verification_key.of_compiled
                              Fake_1_recursion.tag ) )
                      Field.Constant.one ) )
          in
          Or_error.ok_exn
            (Promise.block_on_async_exn (fun () ->
                 Proof.verify_promise [ (Field.Constant.one, b2) ] ) ) ;
          (Field.Constant.one, b2)

        let _example3 =
          let (), (), b3 =
            Common.time "b3" (fun () ->
                Promise.block_on_async_exn (fun () ->
                    step
                      ~handler:
                        (handler Fake_2_recursion.example_input
                           (Side_loaded.Proof.of_proof
                              Fake_2_recursion.example_proof )
                           (Side_loaded.Verification_key.of_compiled
                              Fake_2_recursion.tag ) )
                      Field.Constant.one ) )
          in
          Or_error.ok_exn
            (Promise.block_on_async_exn (fun () ->
                 Proof.verify_promise [ (Field.Constant.one, b3) ] ) ) ;
          (Field.Constant.one, b3)
      end
    end )

  let%test_module "side-loaded with feature flags" =
    ( module struct
      open Impls.Step

      [@@@warning "-60"]

      module Statement = struct
        [@@@warning "-32-34"]

        type t = Field.t

        let to_field_elements x = [| x |]

        module Constant = struct
          type t = Field.Constant.t [@@deriving bin_io]

          [@@@warning "-32"]

          let to_field_elements x = [| x |]
        end
      end

      (* Currently, a circuit must have at least 1 of every type of constraint. *)
      let dummy_constraints () =
        Impl.(
          let x =
            exists Field.typ ~compute:(fun () -> Field.Constant.of_int 3)
          in
          let g =
            exists Step_main_inputs.Inner_curve.typ ~compute:(fun _ ->
                Tick.Inner_curve.(to_affine_exn one) )
          in
          ignore
            ( SC.to_field_checked'
                (module Impl)
                ~num_bits:16
                (Kimchi_backend_common.Scalar_challenge.create x)
              : Field.t * Field.t * Field.t ) ;
          ignore
            ( Step_main_inputs.Ops.scale_fast g ~num_bits:5 (Shifted_value x)
              : Step_main_inputs.Inner_curve.t ) ;
          ignore
            ( Step_main_inputs.Ops.scale_fast g ~num_bits:5 (Shifted_value x)
              : Step_main_inputs.Inner_curve.t ) ;
          ignore
            ( Step_verifier.Scalar_challenge.endo g ~num_bits:4
                (Kimchi_backend_common.Scalar_challenge.create x)
              : Field.t * Field.t ))

      module No_recursion = struct
        let[@warning "-45"] tag, _, p, Provers.[ step ] =
          Common.time "compile" (fun () ->
              compile_promise () ~public_input:(Input Field.typ)
                ~auxiliary_typ:Typ.unit
                ~branches:(module Nat.N1)
                ~max_proofs_verified:(module Nat.N0)
                ~name:"blockchain-snark"
                ~constraint_constants:
                  (* Dummy values *)
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
                ~choices:(fun ~self:_ ->
                  [ { identifier = "main"
                    ; prevs = []
                    ; feature_flags = Plonk_types.Features.none_bool
                    ; main =
                        (fun { public_input = self } ->
                          dummy_constraints () ;
                          Field.Assert.equal self Field.zero ;
                          { previous_proof_statements = []
                          ; public_output = ()
                          ; auxiliary_output = ()
                          } )
                    }
                  ] ) )

        module Proof = (val p)

        let example =
          let (), (), b0 =
            Common.time "b0" (fun () ->
                Promise.block_on_async_exn (fun () -> step Field.Constant.zero) )
          in
          Or_error.ok_exn
            (Promise.block_on_async_exn (fun () ->
                 Proof.verify_promise [ (Field.Constant.zero, b0) ] ) ) ;
          (Field.Constant.zero, b0)

        let example_input, example_proof = example
      end

      module Fake_1_recursion = struct
        let[@warning "-45"] tag, _, p, Provers.[ step ] =
          Common.time "compile" (fun () ->
              compile_promise () ~public_input:(Input Field.typ)
                ~auxiliary_typ:Typ.unit
                ~branches:(module Nat.N1)
                ~max_proofs_verified:(module Nat.N1)
                ~name:"blockchain-snark"
                ~constraint_constants:
                  (* Dummy values *)
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
                ~choices:(fun ~self:_ ->
                  [ { identifier = "main"
                    ; prevs = []
                    ; feature_flags = Plonk_types.Features.none_bool
                    ; main =
                        (fun { public_input = self } ->
                          dummy_constraints () ;
                          Field.Assert.equal self Field.zero ;
                          { previous_proof_statements = []
                          ; public_output = ()
                          ; auxiliary_output = ()
                          } )
                    }
                  ] ) )

        module Proof = (val p)

        let example =
          let (), (), b0 =
            Common.time "b0" (fun () ->
                Promise.block_on_async_exn (fun () -> step Field.Constant.zero) )
          in
          Or_error.ok_exn
            (Promise.block_on_async_exn (fun () ->
                 Proof.verify_promise [ (Field.Constant.zero, b0) ] ) ) ;
          (Field.Constant.zero, b0)

        let example_input, example_proof = example
      end

      module Fake_2_recursion = struct
        let[@warning "-45"] tag, _, p, Provers.[ step ] =
          Common.time "compile" (fun () ->
              compile_promise () ~public_input:(Input Field.typ)
                ~override_wrap_domain:Pickles_base.Proofs_verified.N1
                ~auxiliary_typ:Typ.unit
                ~branches:(module Nat.N1)
                ~max_proofs_verified:(module Nat.N2)
                ~name:"blockchain-snark"
                ~constraint_constants:
                  (* Dummy values *)
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
                ~choices:(fun ~self:_ ->
                  [ { identifier = "main"
                    ; prevs = []
                    ; feature_flags = Plonk_types.Features.none_bool
                    ; main =
                        (fun { public_input = self } ->
                          dummy_constraints () ;
                          Field.Assert.equal self Field.zero ;
                          { previous_proof_statements = []
                          ; public_output = ()
                          ; auxiliary_output = ()
                          } )
                    }
                  ] ) )

        module Proof = (val p)

        let example =
          let (), (), b0 =
            Common.time "b0" (fun () ->
                Promise.block_on_async_exn (fun () -> step Field.Constant.zero) )
          in
          Or_error.ok_exn
            (Promise.block_on_async_exn (fun () ->
                 Proof.verify_promise [ (Field.Constant.zero, b0) ] ) ) ;
          (Field.Constant.zero, b0)

        let example_input, example_proof = example
      end

      [@@@warning "-60"]

      module Simple_chain = struct
        type _ Snarky_backendless.Request.t +=
          | Prev_input : Field.Constant.t Snarky_backendless.Request.t
          | Proof : Side_loaded.Proof.t Snarky_backendless.Request.t
          | Verifier_index :
              Side_loaded.Verification_key.t Snarky_backendless.Request.t

        let handler (prev_input : Field.Constant.t) (proof : _ Proof.t)
            (verifier_index : Side_loaded.Verification_key.t)
            (Snarky_backendless.Request.With { request; respond }) =
          match request with
          | Prev_input ->
              respond (Provide prev_input)
          | Proof ->
              respond (Provide proof)
          | Verifier_index ->
              respond (Provide verifier_index)
          | _ ->
              respond Unhandled

        let maybe_features =
          Plonk_types.Features.(map none ~f:(fun _ -> Opt.Flag.Maybe))

        let side_loaded_tag =
          Side_loaded.create ~name:"foo"
            ~max_proofs_verified:(Nat.Add.create Nat.N2.n)
            ~feature_flags:maybe_features ~typ:Field.typ

        let[@warning "-45"] _tag, _, p, Provers.[ step ] =
          Common.time "compile" (fun () ->
              compile_promise () ~public_input:(Input Field.typ)
                ~auxiliary_typ:Typ.unit
                ~branches:(module Nat.N1)
                ~max_proofs_verified:(module Nat.N1)
                ~name:"blockchain-snark"
                ~constraint_constants:
                  (* Dummy values *)
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
                ~choices:(fun ~self:_ ->
                  [ { identifier = "main"
                    ; prevs = [ side_loaded_tag ]
                    ; feature_flags = Plonk_types.Features.none_bool
                    ; main =
                        (fun { public_input = self } ->
                          let prev =
                            exists Field.typ ~request:(fun () -> Prev_input)
                          in
                          let proof =
                            exists (Typ.Internal.ref ()) ~request:(fun () ->
                                Proof )
                          in
                          let vk =
                            exists (Typ.Internal.ref ()) ~request:(fun () ->
                                Verifier_index )
                          in
                          as_prover (fun () ->
                              let vk = As_prover.Ref.get vk in
                              Side_loaded.in_prover side_loaded_tag vk ) ;
                          let vk =
                            exists Side_loaded_verification_key.typ
                              ~compute:(fun () -> As_prover.Ref.get vk)
                          in
                          Side_loaded.in_circuit side_loaded_tag vk ;
                          let is_base_case = Field.equal Field.zero self in
                          let self_correct = Field.(equal (one + prev) self) in
                          Boolean.Assert.any [ self_correct; is_base_case ] ;
                          { previous_proof_statements =
                              [ { public_input = prev
                                ; proof
                                ; proof_must_verify = Boolean.true_
                                }
                              ]
                          ; public_output = ()
                          ; auxiliary_output = ()
                          } )
                    }
                  ] ) )

        module Proof = (val p)

        let _example1 =
          let (), (), b1 =
            Common.time "b1" (fun () ->
                Promise.block_on_async_exn (fun () ->
                    step
                      ~handler:
                        (handler No_recursion.example_input
                           (Side_loaded.Proof.of_proof
                              No_recursion.example_proof )
                           (Side_loaded.Verification_key.of_compiled
                              No_recursion.tag ) )
                      Field.Constant.one ) )
          in
          Or_error.ok_exn
            (Promise.block_on_async_exn (fun () ->
                 Proof.verify_promise [ (Field.Constant.one, b1) ] ) ) ;
          (Field.Constant.one, b1)

        let _example2 =
          let (), (), b2 =
            Common.time "b2" (fun () ->
                Promise.block_on_async_exn (fun () ->
                    step
                      ~handler:
                        (handler Fake_1_recursion.example_input
                           (Side_loaded.Proof.of_proof
                              Fake_1_recursion.example_proof )
                           (Side_loaded.Verification_key.of_compiled
                              Fake_1_recursion.tag ) )
                      Field.Constant.one ) )
          in
          Or_error.ok_exn
            (Promise.block_on_async_exn (fun () ->
                 Proof.verify_promise [ (Field.Constant.one, b2) ] ) ) ;
          (Field.Constant.one, b2)

        let _example3 =
          let (), (), b3 =
            Common.time "b3" (fun () ->
                Promise.block_on_async_exn (fun () ->
                    step
                      ~handler:
                        (handler Fake_2_recursion.example_input
                           (Side_loaded.Proof.of_proof
                              Fake_2_recursion.example_proof )
                           (Side_loaded.Verification_key.of_compiled
                              Fake_2_recursion.tag ) )
                      Field.Constant.one ) )
          in
          Or_error.ok_exn
            (Promise.block_on_async_exn (fun () ->
                 Proof.verify_promise [ (Field.Constant.one, b3) ] ) ) ;
          (Field.Constant.one, b3)
      end
    end )
end

include Wire_types.Make (Make_sig) (Make_str)
