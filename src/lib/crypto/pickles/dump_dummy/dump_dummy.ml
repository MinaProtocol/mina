(* Dump dummy values by forcing the production Dummy/Unfinalized modules
   with Ro tracing enabled. Every Ro.tock/tick/chal call prints its key
   to stderr. The actual production values are printed to stdout.

   Usage:
     dune exec src/lib/crypto/pickles/dump_dummy/dump_dummy.exe \
       > packages/pickles/test/fixtures/dummy_values.txt

   The trace (on stderr) shows the exact Ro call sequence.
   The fixture (on stdout) shows the values used by production circuits. *)

let () =
  (* Initialize SRS for compute_sg *)
  Pickles.Backend.Tock.Keypair.set_urs_info [] ;
  Pickles.Backend.Tick.Keypair.set_urs_info [] ;
  (* Enable Ro trace logging to stderr *)
  Pickles.Ro.enable_trace ()

open Core_kernel
module Dummy = Pickles__Dummy
module Unfinalized = Pickles__Unfinalized

let fp s v = Format.printf "%s: %s@." s (Kimchi_pasta.Pasta.Fp.to_string v)
let fq s v = Format.printf "%s: %s@." s (Kimchi_pasta.Pasta.Fq.to_string v)

let () =
  (* Force production values in the same order as module initialization.
     Wrap challenges are eager (already computed), Step challenges are eager,
     then lazy values are forced on demand. *)

  (* 1. Wrap IPA challenges (eager — already fired during Dummy module init) *)
  let wrap_expanded = Lazy.force Dummy.Ipa.Wrap.challenges_computed in
  List.iteri (Pickles_types.Vector.to_list wrap_expanded) ~f:(fun i v ->
    fq (sprintf "wrap_challenge_expanded_%d" i) v) ;

  (* 2. Step IPA challenges (eager — already fired during Dummy module init) *)
  let step_expanded = Lazy.force Dummy.Ipa.Step.challenges_computed in
  List.iteri (Pickles_types.Vector.to_list step_expanded) ~f:(fun i v ->
    fp (sprintf "step_challenge_expanded_%d" i) v) ;

  (* 3. Wrap IPA sg (lazy, forces SRS computation) *)
  let wrap_sg = Lazy.force Dummy.Ipa.Wrap.sg in
  let (x, y) = wrap_sg in
  fp "wrap_sg_x" x ;
  fp "wrap_sg_y" y ;

  (* 4. Step IPA sg (lazy, forces SRS computation) *)
  let step_sg = Lazy.force Dummy.Ipa.Step.sg in
  let (x, y) = step_sg in
  fq "step_sg_x" x ;
  fq "step_sg_y" y ;

  (* 5. Unfinalized.Constant.dummy (lazy, forces Dummy.evals internally) *)
  let unfinalized = Lazy.force Unfinalized.Constant.dummy in
  let dv = unfinalized.deferred_values in

  (* Extract expanded zeta/alpha from the dummy for debugging *)
  let expand_sc sc = Pickles__Common.Ipa.Wrap.endo_to_field sc in
  fq "unfinalized.zeta_expanded" (expand_sc dv.plonk.zeta) ;
  fq "unfinalized.alpha_expanded" (expand_sc dv.plonk.alpha) ;

  let sv2 (Plonkish_prelude.Shifted_value.Type2.Shifted_value v) = v in
  fq "unfinalized.plonk.perm" (sv2 dv.plonk.perm) ;
  fq "unfinalized.plonk.zeta_to_srs_length" (sv2 dv.plonk.zeta_to_srs_length) ;
  fq "unfinalized.plonk.zeta_to_domain_size" (sv2 dv.plonk.zeta_to_domain_size) ;
  fq "unfinalized.combined_inner_product" (sv2 dv.combined_inner_product) ;
  fq "unfinalized.b" (sv2 dv.b) ;

  let digest_fq =
    let module D = Pickles__Import.Digest in
    D.Constant.to_tock_field unfinalized.sponge_digest_before_evaluations in
  fq "unfinalized.sponge_digest" digest_fq ;

  (* 6. Step-side deferred values via expand_deferred.
     Construct a dummy Wrap proof (proof.ml:dummy) and run
     Wrap_deferred_values.expand_deferred to get the exact Type1 shifted
     values that the Step circuit would see.  This uses the library function
     directly — no reimplementation of the math. *)
  let module Proof = Pickles__Proof in
  let module WDV = Pickles__Wrap_deferred_values in
  let (Proof.T dummy_proof) =
    Proof.dummy Pickles_types.Nat.N2.n Pickles_types.Nat.N2.n ~domain_log2:15
  in
  let step_deferred = WDV.expand_deferred
    ~zk_rows:3
    ~evals:dummy_proof.prev_evals
    ~old_bulletproof_challenges:
      dummy_proof.statement.messages_for_next_step_proof.old_bulletproof_challenges
    ~proof_state:dummy_proof.statement.proof_state
  in
  (* Intermediate values: expanded plonk challenges and challenges_digest.
     These depend on the Ro chal sequence, so dump them for PureScript to load
     as inputs to the expand_deferred computation. *)
  let module Challenge = Pickles__Import.Challenge in
  let sc_step sc = Pickles__Common.Ipa.Step.endo_to_field sc in
  let chal_to_fp c = Challenge.Constant.to_tick_field c in
  let plonk0 = dummy_proof.statement.proof_state.deferred_values.plonk in
  fp "step_input.plonk.alpha" (sc_step plonk0.alpha) ;
  fp "step_input.plonk.beta" (chal_to_fp plonk0.beta) ;
  fp "step_input.plonk.gamma" (chal_to_fp plonk0.gamma) ;
  fp "step_input.plonk.zeta" (sc_step plonk0.zeta) ;

  (* challenges_digest: sponge(expanded old_bulletproof_challenges) *)
  let old_bpc =
    dummy_proof.statement.messages_for_next_step_proof.old_bulletproof_challenges in
  let old_bpc_expanded =
    Pickles_types.Vector.map ~f:Pickles__Common.Ipa.Step.compute_challenges old_bpc in
  let challenges_digest =
    let open Pickles__Tick_field_sponge.Field in
    let sponge = create Pickles__Tick_field_sponge.params in
    Pickles_types.Vector.iter old_bpc_expanded ~f:(Pickles_types.Vector.iter ~f:(absorb sponge)) ;
    squeeze sponge
  in
  fp "step_input.challenges_digest" challenges_digest ;

  (* Expanded old_bulletproof_challenges: 2 copies of 15 Fp values each *)
  Array.iteri (Pickles_types.Vector.to_array old_bpc_expanded) ~f:(fun i chals ->
    Array.iteri (Pickles_types.Vector.to_array chals) ~f:(fun j v ->
      fp (sprintf "step_input.old_bp_chals.%d.%d" i j) v)) ;

  (* ft_eval0 via production Wrap.combined_inner_product internals.
     Calls the same code path as expand_deferred. *)
  let tick_plonk_minimal =
    let plonk0 = dummy_proof.statement.proof_state.deferred_values.plonk in
    { Composition_types.Wrap.Proof_state.Deferred_values.Plonk.Minimal.
      zeta = sc_step plonk0.zeta ; alpha = sc_step plonk0.alpha
    ; beta = chal_to_fp plonk0.beta ; gamma = chal_to_fp plonk0.gamma
    ; joint_combiner = None
    ; feature_flags = Pickles_types.Plonk_types.Features.none_bool } in
  let step_domain =
    Composition_types.Branch_data.domain
      dummy_proof.statement.proof_state.deferred_values.branch_data in
  let tick_domain =
    Plonk_checks.domain (module Backend.Tick.Field) step_domain
      ~shifts:Pickles__Common.tick_shifts
      ~domain_generator:Backend.Tick.Field.domain_generator in
  let tick_combined_evals =
    Plonk_checks.evals_of_split_evals (module Backend.Tick.Field)
      dummy_proof.prev_evals.evals.evals
      ~rounds:(Pickles_types.Nat.to_int Backend.Tick.Rounds.n)
      ~zeta:tick_plonk_minimal.zeta
      ~zetaw:Backend.Tick.Field.(tick_plonk_minimal.zeta
        * domain_generator ~log2_size:(Pickles_base.Domain.log2_size step_domain)) in
  let tick_env =
    let module B = struct type t = bool let true_ = true let false_ = false
      let ( &&& ) = ( && ) let ( ||| ) = ( || )
      let any = List.exists ~f:Fn.id end in
    let module F = struct include Backend.Tick.Field type bool = B.t
      let if_ b ~then_ ~else_ = if b then then_ () else else_ () end in
    Plonk_checks.scalars_env (module B) (module F)
      ~endo:Pickles__Endo.Step_inner_curve.base
      ~mds:Pickles__Tick_field_sponge.params.mds
      ~srs_length_log2:Pickles__Common.Max_degree.step_log2 ~zk_rows:3
      ~field_of_hex:(fun s ->
        Kimchi_pasta.Pasta.Bigint256.of_hex_string s |> Kimchi_pasta.Pasta.Fp.of_bigint)
      ~domain:tick_domain tick_plonk_minimal
      (Pickles_types.Plonk_types.Evals.to_in_circuit tick_combined_evals) in
  let module PC_Type1 =
    Plonk_checks.Make (Plonkish_prelude.Shifted_value.Type1)
      (Plonk_checks.Scalars_tokens_interpreter.Tick) in
  let ft_eval0 =
    PC_Type1.ft_eval0 (module Backend.Tick.Field)
      tick_plonk_minimal ~env:tick_env ~domain:tick_domain
      (Pickles_types.Plonk_types.Evals.to_in_circuit tick_combined_evals)
      (fst dummy_proof.prev_evals.evals.public_input) in
  fp "step_deferred.ft_eval0" ft_eval0 ;

  let sv1 (Plonkish_prelude.Shifted_value.Type1.Shifted_value v) = v in
  fp "step_deferred.plonk.perm" (sv1 step_deferred.plonk.perm) ;
  fp "step_deferred.plonk.zeta_to_srs_length" (sv1 step_deferred.plonk.zeta_to_srs_length) ;
  fp "step_deferred.plonk.zeta_to_domain_size" (sv1 step_deferred.plonk.zeta_to_domain_size) ;
  fp "step_deferred.combined_inner_product" (sv1 step_deferred.combined_inner_product) ;
  fp "step_deferred.b" (sv1 step_deferred.b) ;

  (* xi: raw 128-bit challenge packed as Fp (for SizedF 128 in PureScript) *)
  fp "step_deferred.xi_packed" (Challenge.Constant.to_tick_field step_deferred.xi.inner) ;

  (* xi expanded via endo (for debugging) *)
  let expand_sc_step sc = Pickles__Common.Ipa.Step.endo_to_field sc in
  fp "step_deferred.xi_expanded" (expand_sc_step step_deferred.xi) ;

  (* sponge_digest_before_evaluations: from proof.ml:dummy's proof_state *)
  let step_sponge_digest =
    let module D = Pickles__Import.Digest in
    D.Constant.to_tick_field dummy_proof.statement.proof_state.sponge_digest_before_evaluations in
  fp "step_deferred.sponge_digest" step_sponge_digest ;

  (* 7. Dummy proof prev_evals (Tick.Field / Fp).
     These are the tick()-derived polynomial evaluations that expand_deferred
     processes. Dumped so PureScript can load them and run the computation. *)
  let pe = dummy_proof.prev_evals in
  fp "prev_evals.ft_eval1" pe.ft_eval1 ;

  let (pi_z, pi_oz) = pe.evals.public_input in
  Array.iteri pi_z ~f:(fun j v -> fp (sprintf "prev_evals.public_input.zeta.%d" j) v) ;
  Array.iteri pi_oz ~f:(fun j v -> fp (sprintf "prev_evals.public_input.omega_zeta.%d" j) v) ;

  let ev = pe.evals.evals in

  (* Helper for single eval pairs *)
  let dump_eval name (z, oz) =
    Array.iteri z ~f:(fun j v -> fp (sprintf "prev_evals.%s.zeta.%d" name j) v) ;
    Array.iteri oz ~f:(fun j v -> fp (sprintf "prev_evals.%s.omega_zeta.%d" name j) v)
  in
  let dump_eval_vec name vec =
    Array.iteri (Pickles_types.Vector.to_array vec) ~f:(fun i pair ->
      dump_eval (sprintf "%s.%d" name i) pair)
  in

  dump_eval_vec "w" ev.w ;
  dump_eval_vec "coefficients" ev.coefficients ;
  dump_eval "z" ev.z ;
  dump_eval_vec "s" ev.s ;
  dump_eval "generic_selector" ev.generic_selector ;
  dump_eval "poseidon_selector" ev.poseidon_selector ;
  dump_eval "complete_add_selector" ev.complete_add_selector ;
  dump_eval "mul_selector" ev.mul_selector ;
  dump_eval "emul_selector" ev.emul_selector ;
  dump_eval "endomul_scalar_selector" ev.endomul_scalar_selector
