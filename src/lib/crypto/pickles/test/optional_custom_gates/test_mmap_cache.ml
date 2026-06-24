(** Testing
    -------
    Component: Pickles / mmap-backed proving-key cache
    Subject: End-to-end prove + verify while the MINA_USE_MMAP_CACHE code
             path is active. The test is split into two phases that run
             in *separate* OS processes:

             Phase 1 (in-process): compile a trivial circuit, prove+verify,
               and let Pickles write the proving keys to the on-disk cache
               via caml_pasta_f{p,q}_plonk_index_write_cached. The prover
               here works on freshly-generated keys, so it does NOT
               exercise the cache read path.

             Phase 2 (re-exec'd fresh process): compile the same circuit
               again with the populated cache dir. Because this is a new
               process, any in-memory derived state from phase 1 is gone;
               every field read by the prover must come from the mmap'd
               file. Prove + verify here is the real round-trip test.

             This is the shape that reproduces the user-reported wrap-proof
             failure: a fresh run proving against cache that was populated
             by a previous run.
    Invocation: \
      MINA_USE_MMAP_CACHE=1 \
      dune exec src/lib/crypto/pickles/test/optional_custom_gates/test_mmap_cache.exe
*)

open Core_kernel
open Pickles_types
open Pickles.Impls.Step

(* Pull in the native Key_cache implementation; the default Trivial one
   doesn't actually read or write files, which defeats this test. *)
let () = ignore Key_cache_native.linkme

let () = Pickles.Backend.Tick.Keypair.set_urs_info []

let () = Pickles.Backend.Tock.Keypair.set_urs_info []

(* Sanity: the env var must be set for this test to actually exercise the
   mmap path. Without it, the legacy rmp_serde path is used and the test
   passes for reasons unrelated to our code. *)
let () =
  match Sys.getenv_opt "MINA_USE_MMAP_CACHE" with
  | Some ("1" | "true" | "yes") ->
      ()
  | _ ->
      failwith
        "test_mmap_cache requires MINA_USE_MMAP_CACHE=1; the test is a no-op \
         without it"

(* The cache directory is either picked afresh (phase 1, first invocation)
   or inherited from the environment (phase 2, re-exec'd child). Passing it
   via an env var keeps the CLI surface trivial. *)
let cache_dir_env_var = "MINA_MMAP_TEST_CACHE_DIR"

let cache_dir =
  match Sys.getenv_opt cache_dir_env_var with
  | Some d ->
      d
  | None ->
      let tmp = Option.value (Sys.getenv_opt "TMPDIR") ~default:"/tmp" in
      let ns =
        Core.Time_ns.to_int_ns_since_epoch (Core.Time_ns.now ())
        land 0xffff_ffff
      in
      let dir =
        Filename.concat tmp (Printf.sprintf "mina_mmap_cache_test_%d" ns)
      in
      (try Stdlib.Sys.mkdir dir 0o700 with Sys_error _ -> ()) ;
      dir

let is_phase_2 =
  Array.exists Sys.argv ~f:(fun a -> String.equal a "--phase-2")

let cache_spec : Key_cache.Spec.t list =
  [ On_disk { directory = cache_dir; should_write = true } ]

(** A trivial circuit: assert that a witnessed field element equals zero.
    Small enough that keygen is cheap and every prove must pass through
    both Step (Tick/Vesta) and Wrap (Tock/Pallas). *)
let compile_trivial_circuit ~name =
  Pickles.compile ~public_input:(Pickles.Inductive_rule.Input Typ.unit)
    ~auxiliary_typ:Typ.unit ~max_proofs_verified:(module Nat.N0)
    ~cache:cache_spec ~name
    ~choices:(fun ~self:_ ->
      [ { identifier = "trivial"
        ; prevs = []
        ; main =
            (fun _ ->
              let zero =
                exists Field.typ ~compute:(fun () -> Field.Constant.zero)
              in
              Field.Assert.equal zero Field.zero ;
              { previous_proof_statements = []
              ; public_output = ()
              ; auxiliary_output = ()
              } )
        ; feature_flags = Pickles_types.Plonk_types.Features.none_bool
        }
      ] )
    ()

let phase_run ~name =
  Printf.eprintf "\n=== PHASE: %s ===\n%!" name ;
  let _tag, _cache_handle, proof, Pickles.Provers.[ prove ] =
    compile_trivial_circuit ~name:"mmap_cache_trivial"
  in
  let module Proof = (val proof) in
  Printf.eprintf "[%s] calling prover... %!" name ;
  let public_input, (), proof =
    Async.Thread_safe.block_on_async_exn (fun () -> prove ())
  in
  Printf.eprintf "ok\n%!" ;
  Printf.eprintf "[%s] verifying proof... %!" name ;
  Or_error.ok_exn
    (Async.Thread_safe.block_on_async_exn (fun () ->
         Proof.verify [ (public_input, proof) ] ) ) ;
  Printf.eprintf "ok\n%!"

let inspect_cache_files () =
  let entries = Array.to_list (Stdlib.Sys.readdir cache_dir) in
  Printf.eprintf "[cache-dir %s] %d entries\n%!" cache_dir
    (List.length entries) ;
  List.iter entries ~f:(fun name ->
      let path = Filename.concat cache_dir name in
      let size =
        let ic = Stdlib.open_in_bin path in
        let n = Stdlib.in_channel_length ic in
        Stdlib.close_in ic ; n
      in
      let magic =
        if String.is_prefix name ~prefix:"step-"
           || String.is_prefix name ~prefix:"wrap-"
        then
          let ic = Stdlib.open_in_bin path in
          let b = Bytes.create 8 in
          let n = Stdlib.input ic b 0 8 in
          Stdlib.close_in ic ;
          if n = 8 then Some (Bytes.to_string b) else None
        else None
      in
      Printf.eprintf "  %s  size=%d  magic=%s\n%!" name size
        ( match magic with
        | Some s ->
            Printf.sprintf "%S" s
        | None ->
            "(not a proving-key file)" ) )

let () =
  if is_phase_2 then (
    (* Fresh process, inheriting cache_dir via env var. Everything below
       here is what the user's environment does on "a second run of the
       program": compile reads from cache, and the prover runs against
       keys that only ever touched memory via mmap. *)
    Printf.eprintf "test_mmap_cache PHASE 2 (fresh process), cache_dir=%s\n%!"
      cache_dir ;
    inspect_cache_files () ;
    phase_run ~name:"phase-2 (read cache + prove + verify)" ;
    Printf.eprintf "\ntest_mmap_cache: phase 2 SUCCESS\n%!" )
  else (
    Printf.eprintf "test_mmap_cache PHASE 1 (write), cache_dir=%s\n%!"
      cache_dir ;
    phase_run ~name:"phase-1 (keygen + write cache)" ;
    inspect_cache_files () ;
    (* Re-exec ourselves with --phase-2 in a fresh OS process. This is the
       test's load-bearing step: if any bug in the cache round-trip only
       manifests when the proving keys are loaded without the backing
       generator state in memory, the prove in phase 2 will fail. *)
    let cmd =
      Printf.sprintf "%s=1 %s=%s %s --phase-2" "MINA_USE_MMAP_CACHE"
        cache_dir_env_var
        (Filename.quote cache_dir)
        (Filename.quote Sys.executable_name)
    in
    Printf.eprintf "\n=== re-exec'ing for phase 2 ===\n%s\n%!" cmd ;
    let rc = Stdlib.Sys.command cmd in
    if rc <> 0 then
      failwith
        (Printf.sprintf "phase 2 exited with code %d (cache dir: %s)" rc
           cache_dir ) ;
    Printf.eprintf "\ntest_mmap_cache: full round-trip SUCCESS\n%!" )
