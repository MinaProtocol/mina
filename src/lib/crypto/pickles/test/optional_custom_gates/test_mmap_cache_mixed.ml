(** Testing
    -------
    Component: Pickles / mmap-backed proving-key cache
    Subject: Processes with and without the mmap cache share a cache directory
             without regenerating or rewriting each other's proving keys.
             Each step runs in its own OS process against the same directory:

             1. legacy mode: keygen, writes legacy-format keys;
             2. mmap mode: converts the legacy keys to `.mmap` files without
                keygen, and leaves the legacy files untouched;
             3. legacy mode again: reads the legacy keys without keygen, and
                leaves both sets of files untouched.

             Every step proves and verifies with the keys it loaded.
    Invocation: \
      dune exec src/lib/crypto/pickles/test/optional_custom_gates/test_mmap_cache_mixed.exe
*)

open Core_kernel
open Pickles_types
open Pickles.Impls.Step

let () = ignore Key_cache_native.linkme

let () = Pickles.Backend.Tick.Keypair.set_urs_info []

let () = Pickles.Backend.Tock.Keypair.set_urs_info []

let cache_dir_env_var = "MINA_MMAP_TEST_CACHE_DIR"

let expect_no_keygen =
  Array.mem Sys.argv "--expect-no-keygen" ~equal:String.equal

let is_step = Array.mem Sys.argv "--step" ~equal:String.equal

let fresh_cache_dir () =
  let tmp = Option.value (Sys.getenv_opt "TMPDIR") ~default:"/tmp" in
  let ns =
    Core.Time_ns.to_int_ns_since_epoch (Core.Time_ns.now ()) land 0xffff_ffff
  in
  let dir = Filename.concat tmp (sprintf "mina_mmap_cache_mixed_%d" ns) in
  Stdlib.Sys.mkdir dir 0o700 ; dir

(* One step: compile the circuit against the shared cache, check whether any
   key had to be generated, then prove and verify. *)
let run_step cache_dir =
  let _tag, cache_handle, proof, Pickles.Provers.[ prove ] =
    Pickles.compile ~public_input:(Pickles.Inductive_rule.Input Typ.unit)
      ~auxiliary_typ:Typ.unit
      ~max_proofs_verified:(module Nat.N0)
      ~cache:[ On_disk { directory = cache_dir; should_write = true } ]
      ~name:"mmap_cache_mixed"
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
  in
  let module Proof = (val proof) in
  let dirty =
    Promise.block_on_async_exn (fun () ->
        Pickles.Cache_handle.generate_or_load cache_handle )
  in
  ( match dirty with
  | `Generated_something when expect_no_keygen ->
      failwith "a proving or verification key was generated unexpectedly"
  | `Generated_something | `Cache_hit | `Locally_generated ->
      () ) ;
  let public_input, (), proof =
    Async.Thread_safe.block_on_async_exn (fun () -> prove ())
  in
  Or_error.ok_exn
    (Async.Thread_safe.block_on_async_exn (fun () ->
         Proof.verify [ (public_input, proof) ] ) )

(* The identity of each proving-key file: a rewrite changes the inode (rename)
   or the size and modification time (in-place write). *)
let proving_key_files cache_dir =
  Stdlib.Sys.readdir cache_dir
  |> Array.to_list
  |> List.filter ~f:(fun name ->
         String.is_prefix name ~prefix:"step-"
         || String.is_prefix name ~prefix:"wrap-" )
  |> List.map ~f:(fun name ->
         let st = Core.Unix.stat (Filename.concat cache_dir name) in
         (name, (st.st_ino, st.st_size, st.st_mtime)) )
  |> String.Map.of_alist_exn

let run_child cache_dir ~mmap ~expect_no_keygen =
  let cmd =
    sprintf "MINA_USE_MMAP_CACHE=%d %s=%s %s --step%s"
      (if mmap then 1 else 0)
      cache_dir_env_var (Filename.quote cache_dir)
      (Filename.quote Sys.executable_name)
      (if expect_no_keygen then " --expect-no-keygen" else "")
  in
  let rc = Stdlib.Sys.command cmd in
  if rc <> 0 then failwithf "step exited with code %d: %s" rc cmd ()

let assert_unchanged ~what before after =
  Map.iteri before ~f:(fun ~key ~data ->
      match Map.find after key with
      | Some data' when Poly.equal data data' ->
          ()
      | _ ->
          failwithf "%s: %s was rewritten or removed" what key () )

let () =
  if is_step then run_step (Option.value_exn (Sys.getenv_opt cache_dir_env_var))
  else
    let cache_dir = fresh_cache_dir () in
    let is_mmap name = String.is_suffix name ~suffix:".mmap" in
    run_child cache_dir ~mmap:false ~expect_no_keygen:false ;
    let legacy = proving_key_files cache_dir in
    if
      Map.is_empty legacy
      || Map.existsi legacy ~f:(fun ~key ~data:_ -> is_mmap key)
    then failwith "legacy step did not write only legacy proving keys" ;
    run_child cache_dir ~mmap:true ~expect_no_keygen:true ;
    let after_mmap = proving_key_files cache_dir in
    assert_unchanged ~what:"mmap step" legacy after_mmap ;
    let mmap = Map.filter_keys after_mmap ~f:is_mmap in
    if Map.length mmap <> Map.length legacy then
      failwith "mmap step did not write an mmap file for every proving key" ;
    run_child cache_dir ~mmap:false ~expect_no_keygen:true ;
    assert_unchanged ~what:"second legacy step" after_mmap
      (proving_key_files cache_dir) ;
    eprintf "test_mmap_cache_mixed: SUCCESS\n%!"
