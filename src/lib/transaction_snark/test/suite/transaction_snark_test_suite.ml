open Core_kernel

let proof_cache = Pickles.Proof_cache.empty ()

let initial_caml_random_state = Caml.Random.get_state ()

let initial_base_random_state = Base.Random.State.copy Base.Random.State.default

let with_random_state ~caml ~base f =
  let caml_random_state = Caml.Random.get_state () in
  let base_random_state = Base.Random.State.copy Base.Random.State.default in
  Caml.Random.set_state caml ;
  Base.Random.set_state base ;
  Exn.protect ~f ~finally:(fun () ->
      Caml.Random.set_state caml_random_state ;
      Base.Random.set_state base_random_state )

(* The seeds that [ppx_inline_test] resets the random state to for each test. *)
let with_inline_test_random_state f =
  with_random_state
    ~caml:(Caml.Random.State.make [| 100; 200; 300 |])
    ~base:(Base.Random.State.make [| 111; 222; 333 |])
    f

let error_on_proof_var = "ERROR_ON_PROOF"

let without_error_on_proof f =
  match Sys.getenv_opt error_on_proof_var with
  | None ->
      f ()
  | Some data ->
      Core.Unix.unsetenv error_on_proof_var ;
      Exn.protect ~f ~finally:(fun () ->
          Core.Unix.putenv ~key:error_on_proof_var ~data )

let make ~name ?proof_cache_json setup =
  Transaction_snark.For_tests.set_proof_cache proof_cache ;
  let suite_proofs =
    match proof_cache_json with
    | None ->
        Pickles.Proof_cache.empty ()
    | Some json ->
        Result.ok_or_failwith @@ Pickles.Proof_cache.of_yojson
        @@ Yojson.Safe.from_string json
  in
  ( match (proof_cache_json, Sys.getenv_opt "PROOF_CACHE_OUT") with
  | Some _, Some dir ->
      at_exit (fun () ->
          Yojson.Safe.to_file (Filename.concat dir (name ^ ".json"))
          @@ Pickles.Proof_cache.to_yojson suite_proofs )
  | None, _ | _, None ->
      () ) ;
  let in_suite f =
    let f () =
      Pickles.Proof_cache.replace_contents proof_cache ~by:suite_proofs ;
      Exn.protect ~f ~finally:(fun () ->
          Pickles.Proof_cache.replace_contents suite_proofs ~by:proof_cache )
    in
    if Option.is_some proof_cache_json then f () else without_error_on_proof f
  in
  let tests = Queue.create () in
  let test test_name f =
    Queue.enqueue tests
      (Alcotest.test_case test_name `Quick (fun () ->
           in_suite (fun () -> with_inline_test_random_state f) ) )
  in
  (* A suite's setup sees the random state that it would at the start of its
     own process. *)
  with_random_state ~caml:(Caml.Random.State.copy initial_caml_random_state)
    ~base:(Base.Random.State.copy initial_base_random_state) (fun () ->
      in_suite (fun () -> setup ~test) ) ;
  (name, Queue.to_list tests)
