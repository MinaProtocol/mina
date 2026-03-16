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
  fq "unfinalized.sponge_digest" digest_fq
