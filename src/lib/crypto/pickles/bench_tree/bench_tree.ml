(** OCaml counterpart of the PureScript `pickles-bench` suite
 *  (`packages/pickles-bench/` in the snarky repo): the SAME logical
 *  workload — the Tree_proof_return-shaped N=2 rule from
 *  `test_no_sideloaded.ml` (via `dump_tree_proof_return.ml`, of which
 *  this is a copy) plus 2^16 witnessed-zero filler muls so the step
 *  circuit lands in domain 2^16 — under the SAME measurement contract:
 *
 *    - URS/SRS construction and lagrange bases are NOT in any timed
 *      region: one untimed warmup compile (incl. forced keypair
 *      generation) populates them first.
 *    - compile trials: each = full No_recursion_return + Tree compile
 *      PLUS `Cache_handle.generate_or_load` on both handles — pickles
 *      keypairs are lazy, and the PS compile bench creates
 *      prover/verifier indexes eagerly, so the forcing belongs in the
 *      timed window.
 *    - prove trials: NRR example proof and the b0 base proof are
 *      untimed setup (forcing any remaining prover laziness); only the
 *      b1 inductive prove is timed, repeatedly, over the same (s0, b0).
 *
 *  Output: plain wall-clock lines, no profiler.
 *
 *  Run with KIMCHI_DETERMINISTIC_SEED set (the in-tree kimchi-stubs
 *  requires it); do NOT set PICKLES_TRACE_FILE / KIMCHI_WITNESS_DUMP
 *  (their I/O would pollute the timings).
 *)

open Pickles_types

let () = Pickles.Backend.Tock.Keypair.set_urs_info []

let () = Pickles.Backend.Tick.Keypair.set_urs_info []

let filler_iters = 1 lsl 16

let compile_trials = 3

let prove_trials = 5

let now () = Time_ns.now ()

let secs t0 t1 = Time_ns.Span.to_sec (Time_ns.diff t1 t0)

(* ========================================================================
 *  Requests + handler (verbatim from dump_tree_proof_return.ml)
 * ======================================================================== *)

type _ Snarky_backendless.Request.t +=
  | Is_base_case : bool Snarky_backendless.Request.t
  | No_recursion_input :
      Impls.Step.Field.Constant.t Snarky_backendless.Request.t
  | No_recursion_proof :
      Pickles_types.Nat.N0.n Pickles.Proof.t Snarky_backendless.Request.t
  | Recursive_input : Impls.Step.Field.Constant.t Snarky_backendless.Request.t
  | Recursive_proof :
      Pickles_types.Nat.N2.n Pickles.Proof.t Snarky_backendless.Request.t

let handler (is_base_case : bool)
    ((no_recursion_input, no_recursion_proof) :
      Impls.Step.Field.Constant.t * _ Pickles.Proof.t )
    ((recursion_input, recursion_proof) :
      Impls.Step.Field.Constant.t * _ Pickles.Proof.t )
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

(* ========================================================================
 *  One full compile: No_recursion_return (N0 leaf) + Tree (N2, filler),
 *  with keypair generation FORCED (the handles are lazy).
 * ======================================================================== *)

let compile_nrr () =
  Pickles.compile_promise ()
    ~public_input:(Output Impls.Step.Field.typ)
    ~auxiliary_typ:Impls.Step.Typ.unit
    ~max_proofs_verified:(module Nat.N0)
    ~name:"no_recursion_return"
    ~choices:(fun ~self:_ ->
      [ { identifier = "main"
        ; prevs = []
        ; feature_flags = Plonk_types.Features.none_bool
        ; main =
            (fun _ ->
              Promise.return
                { Pickles.Inductive_rule.previous_proof_statements = []
                ; public_output = Impls.Step.Field.zero
                ; auxiliary_output = ()
                } )
        }
      ] )

let compile_tree nrr_tag =
  Pickles.compile_promise ()
    ~public_input:(Output Impls.Step.Field.typ)
    ~override_wrap_domain:Pickles_base.Proofs_verified.N1
    ~auxiliary_typ:Impls.Step.Typ.unit
    ~max_proofs_verified:(module Nat.N2)
    ~name:"bench_tree"
    ~choices:(fun ~self ->
      [ { identifier = "main"
        ; feature_flags = Plonk_types.Features.none_bool
        ; prevs = [ nrr_tag; self ]
        ; main =
            (fun { public_input = () } ->
              let no_recursive_input =
                Impls.Step.exists Impls.Step.Field.typ ~request:(fun () ->
                    No_recursion_input )
              in
              let no_recursive_proof =
                Impls.Step.exists
                  (Impls.Step.Typ.prover_value ())
                  ~request:(fun () -> No_recursion_proof)
              in
              let prev =
                Impls.Step.exists Impls.Step.Field.typ ~request:(fun () ->
                    Recursive_input )
              in
              let prev_proof =
                Impls.Step.exists
                  (Impls.Step.Typ.prover_value ())
                  ~request:(fun () -> Recursive_proof)
              in
              let is_base_case =
                Impls.Step.exists Impls.Step.Boolean.typ ~request:(fun () ->
                    Is_base_case )
              in
              let proof_must_verify = Impls.Step.Boolean.not is_base_case in
              let self_out =
                Impls.Step.Field.(
                  if_ is_base_case ~then_:zero ~else_:(one + prev))
              in
              (* Workload filler, mirroring the PS bench's
               * `mul_ freshZero freshZero` loop: two fresh witnessed
               * zeros and one constrained multiplication per
               * iteration (~half a generic row each), tuned to put
               * the step circuit in domain 2^16. *)
              let fresh_zero () =
                Impls.Step.exists Impls.Step.Field.typ ~compute:(fun () ->
                    Impls.Step.Field.Constant.zero )
              in
              for _ = 1 to filler_iters do
                let z1 = fresh_zero () in
                let z2 = fresh_zero () in
                ignore (Impls.Step.Field.(z1 * z2) : Impls.Step.Field.t)
              done ;
              Promise.return
                { Pickles.Inductive_rule.previous_proof_statements =
                    [ { public_input = no_recursive_input
                      ; proof = no_recursive_proof
                      ; proof_must_verify = Impls.Step.Boolean.true_
                      }
                    ; { public_input = prev
                      ; proof = prev_proof
                      ; proof_must_verify
                      }
                    ]
                ; public_output = self_out
                ; auxiliary_output = ()
                } )
        }
      ] )

let force_keys cache_handle =
  let (_ : _) =
    Promise.block_on_async_exn (fun () ->
        Pickles.Cache_handle.generate_or_load cache_handle )
  in
  ()

(* Compile both programs and force key generation; returns everything
 * the prove group needs. *)
let full_compile () =
  let nrr_tag, nrr_cache, nrr_p, Pickles.Provers.[ nrr_step ] =
    compile_nrr ()
  in
  let _tree_tag, tree_cache, tree_p, Pickles.Provers.[ tree_step ] =
    compile_tree nrr_tag
  in
  force_keys nrr_cache ;
  force_keys tree_cache ;
  (nrr_p, nrr_step, tree_p, tree_step)

(* ========================================================================
 *  Bench driver
 * ======================================================================== *)

let () =
  (* --- untimed warmup: URS + lagrange + first key generation ------- *)
  let t0 = now () in
  let (_ : _) = full_compile () in
  let t1 = now () in
  Printf.printf "[bench] compile warmup (untimed; URS+lagrange): %.1fs\n%!"
    (secs t0 t1) ;
  (* --- group 1: timed compile trials ------------------------------- *)
  let last = ref None in
  for i = 1 to compile_trials do
    let t0 = now () in
    let r = full_compile () in
    let t1 = now () in
    last := Some r ;
    Printf.printf "[bench] compile trial %d/%d: %.1fs\n%!" i compile_trials
      (secs t0 t1)
  done ;
  let nrr_p, nrr_step, tree_p, tree_step = Option.value_exn !last in
  let module NrrProof = (val nrr_p) in
  let module TreeProof = (val tree_p) in
  (* --- group 2 setup (untimed): NRR example proof + b0 -------------- *)
  let t0 = now () in
  let nrr_res, (), nrr_proof =
    Promise.block_on_async_exn (fun () -> nrr_step ())
  in
  assert (Impls.Step.Field.Constant.(equal zero) nrr_res) ;
  let s_neg_one = Impls.Step.Field.Constant.(negate one) in
  let module PickProof = Pickles__Proof in
  (* Dummy self proof for the base case. domain_log2 must equal the
   * compiled step domain (2^16 with the filler). *)
  let b_neg_one : Nat.N2.n Pickles.Proof.t =
    Obj.magic (PickProof.dummy Nat.N2.n Nat.N2.n ~domain_log2:16)
  in
  let s0, (), b0 =
    Promise.block_on_async_exn (fun () ->
        tree_step
          ~handler:
            (handler true (nrr_res, nrr_proof) (s_neg_one, b_neg_one))
          () )
  in
  assert (Impls.Step.Field.Constant.(equal zero) s0) ;
  let t1 = now () in
  Printf.printf "[bench] nrr + b0 prep (untimed): %.1fs\n%!" (secs t0 t1) ;
  (* --- group 2: timed b1 proves ------------------------------------- *)
  let b1_ref = ref None in
  for i = 1 to prove_trials do
    let t0 = now () in
    let s1, (), b1 =
      Promise.block_on_async_exn (fun () ->
          tree_step
            ~handler:(handler false (nrr_res, nrr_proof) (s0, b0))
            () )
    in
    let t1 = now () in
    assert (Impls.Step.Field.Constant.(equal one) s1) ;
    b1_ref := Some (s1, b1) ;
    Printf.printf "[bench] b1 prove trial %d/%d: %.1fs\n%!" i prove_trials
      (secs t0 t1)
  done ;
  (* --- verify gate (untimed) ----------------------------------------- *)
  let s1, b1 = Option.value_exn !b1_ref in
  Or_error.ok_exn
    (Promise.block_on_async_exn (fun () ->
         TreeProof.verify_promise [ (s1, b1) ] ) ) ;
  Printf.printf "[bench] b1 verified OK\n%!"
