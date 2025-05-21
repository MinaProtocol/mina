open Core_kernel
open Async_kernel

module F (Db : Lmdb_storage.Generic.Db) = struct
  type holder = (int, Bigstring.t) Db.t

  let mk_maps { Db.create } =
    create Lmdb_storage.Conv.uint32_be Lmdb.Conv.bigstring

  let config =
    { Lmdb_storage.Generic.default_config with initial_mmap_size = 1 lsl 20 }
end

module Rw = Lmdb_storage.Generic.Read_write (F)
module Ro = Lmdb_storage.Generic.Read_only (F)

let () =
  Backtrace.elide := false ;
  Async.Scheduler.set_record_backtraces true

let test_with_dir f =
  Async.Thread_safe.block_on_async_exn (fun () ->
      let%bind dir = Async.Unix.mkdtemp "lmdb_storage" in
      let%bind result =
        Monitor.protect
          (fun () -> f dir)
          ~finally:(fun () -> File_system.remove_dir dir)
      in
      return result )

let uint32 =
  Base_quickcheck.Generator.int_uniform_inclusive 0 Int32.(to_int_exn max_value)

let init_random_db ?(n = 300) ?(length = 100) dir ~f =
  let env, db = Rw.create dir in
  Quickcheck.test
    (Quickcheck.Generator.both uint32
       (String.gen_with_length length Base_quickcheck.quickcheck_generator_char) )
    ~trials:n
    ~f:(fun (k, v_str) -> f env db k v_str) ;
  (env, db)

(* Test for mmap resize *)
let test_mmap_resize () =
  test_with_dir
  @@ fun dir ->
  let (rw, _) : Rw.t * Rw.holder =
    init_random_db dir ~length:100000 ~f:(fun env db k v_str ->
        let v = Bigstring.of_string v_str in
        Rw.set ~env db k v )
  in
  Rw.close rw ; Deferred.unit

(* Test for iterations with removal and re-opening of database *)
let test_iterations_with_removal_and_reopening () =
  let hm = Hashtbl.create (module Int) in
  let odd_cnt = ref 0 in
  test_with_dir
  @@ fun dir ->
  let env, db =
    init_random_db dir ~f:(fun env db k v_str ->
        let v = Bigstring.of_string v_str in
        Hashtbl.add ~key:k ~data:v hm
        |> function
        | `Duplicate ->
            ()
        | `Ok ->
            if k % 2 = 1 then odd_cnt := !odd_cnt + 1 ;
            Rw.set ~env db k v )
  in

  Hashtbl.iteri hm ~f:(fun ~key ~data ->
      Alcotest.(check bool)
        (Printf.sprintf "Stored value retrieved correctly for key %d" key)
        true
        ( match Rw.get ~env db key with
        | Some retrieved ->
            Bigstring.equal retrieved data
        | None ->
            false ) ) ;

  let cnt = ref 0 in
  Rw.iter ~env db ~f:(fun k data ->
      cnt := !cnt + 1 ;
      Alcotest.(check bool)
        (Printf.sprintf "Data from iteration matches for key %d" k)
        true
        ( match Hashtbl.find hm k with
        | Some expected ->
            Bigstring.equal expected data
        | None ->
            false ) ;
      if k % 2 = 0 then `Remove_continue else `Continue ) ;

  Alcotest.(check int)
    "Iteration count matches hashtable size" (Hashtbl.length hm) !cnt ;

  cnt := 0 ;
  Rw.iter_ro ~env db ~f:(fun k data ->
      Alcotest.(check bool)
        (Printf.sprintf "Read-only iteration data matches for key %d" k)
        true
        ( match Hashtbl.find hm k with
        | Some expected ->
            Bigstring.equal expected data
        | None ->
            false ) ;
      cnt := !cnt + 1 ;
      `Continue ) ;

  Rw.close env ;
  Alcotest.(check int) "Read-only iteration count after removal" !odd_cnt !cnt ;

  (* We cannot explicitly close the environment, but we can create a new read-only one *)
  let env, db = Ro.create dir in

  Hashtbl.iteri hm ~f:(fun ~key ~data ->
      if key % 2 = 1 then
        Alcotest.(check bool)
          (Printf.sprintf "Odd key %d found after reopening" key)
          true
          ( match Ro.get ~env db key with
          | Some retrieved ->
              Bigstring.equal retrieved data
          | None ->
              false )
      else
        Alcotest.(check bool)
          (Printf.sprintf "Even key %d removed after reopening" key)
          true
          (Option.is_none (Ro.get ~env db key)) ) ;

  cnt := 0 ;
  Ro.iter ~env db ~f:(fun k data ->
      Alcotest.(check bool)
        (Printf.sprintf "Data from iteration after reopen matches for key %d" k)
        true
        ( match Hashtbl.find hm k with
        | Some expected ->
            Bigstring.equal expected data
        | None ->
            false ) ;
      cnt := !cnt + 1 ;
      `Continue ) ;

  Ro.close env ;
  Alcotest.(check int) "Iteration count after reopening" !odd_cnt !cnt ;
  Deferred.unit

(* Test for read-only transaction scope operations *)
let test_ro_txn_scope () =
  let hm = Hashtbl.create (module Int) in
  test_with_dir
  @@ fun dir ->
  let (_ : Rw.t * Rw.holder) =
    init_random_db dir ~f:(fun env db k v_str ->
        let v = Bigstring.of_string v_str in
        Hashtbl.add ~key:k ~data:v hm
        |> function `Duplicate -> () | `Ok -> Rw.set ~env db k v )
  in
  let ro_env, ro_db = Ro.create dir in
  let hm_from_iter = Hashtbl.create (module Int) in
  let (_ : Bigstring.t) =
    Ro.with_txn
      ~f:(fun getter ->
        getter.iter_ro
          ~f:(fun key data_from_ro ->
            let data_from_get =
              getter.get ro_db key
              |> Option.value_exn
                   ~message:"cannot find element in get based on iter key"
            in
            Alcotest.(check bool)
              (Printf.sprintf "Data from iter equals data from get for key %d"
                 key )
              true
              (Bigstring.equal data_from_ro data_from_get) ;
            Hashtbl.add_exn ~key ~data:data_from_get hm_from_iter ;
            `Continue )
          ro_db ;
        let first_key, _ =
          Hashtbl.choose hm_from_iter
          |> Option.value_exn ~message:"empty hash table"
        in
        getter.get ro_db first_key
        |> Option.value_exn ~message:"cannot fetch first key from hm after iter"
        )
      ro_env
    |> Option.value_exn ~message:"cannot fetch first key from hm after iter"
  in

  Alcotest.(check bool)
    "Hashtables from original and iter are equal" true
    (let list1 =
       List.sort (Hashtbl.to_alist hm) ~compare:(fun (k1, _) (k2, _) ->
           Int.compare k1 k2 )
     in
     let list2 =
       List.sort (Hashtbl.to_alist hm_from_iter)
         ~compare:(fun (k1, _) (k2, _) -> Int.compare k1 k2)
     in
     List.length list1 = List.length list2
     && List.for_all2_exn list1 list2 ~f:(fun (k1, v1) (k2, v2) ->
            k1 = k2 && Bigstring.equal v1 v2 ) ) ;
  Deferred.return ()

(* Test for read-write transaction scope operations *)
let test_rw_txn_scope () =
  let hm = Hashtbl.create (module Int) in
  test_with_dir
  @@ fun dir ->
  let env, db =
    init_random_db dir ~f:(fun env db k v_str ->
        let v = Bigstring.of_string v_str in
        Hashtbl.add ~key:k ~data:v hm
        |> function `Duplicate -> () | `Ok -> Rw.set ~env db k v )
  in
  Rw.with_txn
    ~f:(fun getter setter ->
      let replacement = Bigstring.of_string "A" in
      setter.iter_rw ~f:(fun _key _data -> `Update_continue replacement) db ;

      getter.iter_ro
        ~f:(fun _key data ->
          Alcotest.(check bool)
            "All data updated to replacement" true
            (Bigstring.equal data replacement) ;
          `Continue )
        db ;

      let first_key, _ =
        Hashtbl.choose hm |> Option.value_exn ~message:"empty hash table"
      in

      let new_replacement = Bigstring.of_string "B" in
      setter.set db first_key new_replacement ;

      let data =
        getter.get db first_key
        |> Option.value_exn ~message:"cannot fetch first key from hm after iter"
      in

      Alcotest.(check bool)
        "First key updated to new value" true
        (Bigstring.equal data new_replacement) )
    env
  |> Option.value_exn ~message:"cannot fetch first key from hm after iter" ;
  Rw.close env ;
  Deferred.return ()

(* Test for iter operation outcomes *)
let test_iter_operations () =
  test_with_dir
  @@ fun dir ->
  let env, db = Rw.create dir in

  List.range 1 7
  |> List.iter ~f:(fun i ->
         let data =
           Char.of_int_exn (64 + i) |> Char.to_string |> Bigstring.of_string
         in
         Rw.set ~env db i data ) ;

  (* `Stop and `Continue on read write iter_ro *)
  let counter = ref 0 in
  Rw.iter_ro ~env
    ~f:(fun k _v -> if k = 4 then `Stop else (incr counter ; `Continue))
    db ;
  Alcotest.(check int)
    "Counter for `Stop and `Continue on read write iter_ro" 3 !counter ;

  (* `Stop and `Continue on read only iter *)
  counter := 0 ;
  let ro_env, ro_db = Ro.create dir in
  Ro.iter ~env:ro_env
    ~f:(fun k _v -> if k = 4 then `Stop else (incr counter ; `Continue))
    ro_db ;
  Alcotest.(check int)
    "Counter for `Stop and `Continue on read only iter" 3 !counter ;

  (* `Remove_continue and `Update_continue `Remove_stop `Continue on iter *)
  counter := 0 ;
  let replacement = Bigstring.of_string "New" in
  Rw.iter ~env
    ~f:(fun k _ ->
      incr counter ;
      match k with
      | 1 ->
          `Remove_continue
      | 2 ->
          `Update_continue replacement
      | 4 ->
          `Remove_stop
      | _ ->
          `Continue )
    db ;

  Alcotest.(check bool)
    "Key 1 removed after `Remove_continue" true
    (Option.is_none (Rw.get ~env db 1)) ;

  Alcotest.(check bool)
    "Key 4 removed after `Remove_stop" true
    (Option.is_none (Rw.get ~env db 4)) ;

  Alcotest.(check int)
    "Counter for `Remove_continue, `Update_continue, `Remove_stop, `Continue" 4
    !counter ;

  (* `Update_stop and `Continue on iter *)
  counter := 0 ;
  Rw.iter ~env
    ~f:(fun k _v ->
      incr counter ;
      match k with 3 -> `Update_stop replacement | _ -> `Continue )
    db ;

  Alcotest.(check int)
    "Counter for `Update_stop and `Continue on iter" 2 !counter ;

  Alcotest.(check bool)
    "Key 3 updated after `Update_stop" true
    ( match Rw.get ~env db 3 with
    | Some v ->
        Bigstring.equal v replacement
    | None ->
        false ) ;

  (* `Stop and `Continue on iter *)
  counter := 0 ;
  Rw.iter ~env
    ~f:(fun k _v ->
      incr counter ;
      match k with 6 -> `Stop | _ -> `Continue )
    db ;
  Alcotest.(check int) "Counter for `Stop and `Continue on iter" 4 !counter ;

  Rw.remove ~env db 5 ;

  counter := 0 ;
  Rw.iter ~env db ~f:(fun _k _ -> incr counter ; `Continue) ;
  Rw.close env ;
  Alcotest.(check int) "Counter for iter after removing key 5" 3 !counter ;
  Deferred.return ()

(* Run all tests *)
let () =
  let open Alcotest in
  run "LMDB Storage"
    [ ( "Basic Operations"
      , [ test_case "MMAP resize" `Quick test_mmap_resize
        ; test_case "Iterations with removal and reopening" `Quick
            test_iterations_with_removal_and_reopening
        ] )
    ; ( "Transaction Operations"
      , [ test_case "Read-only transaction scope" `Quick test_ro_txn_scope
        ; test_case "Read-write transaction scope" `Quick test_rw_txn_scope
        ] )
    ; ( "Iteration Outcomes"
      , [ test_case "Iteration operation outcomes" `Quick test_iter_operations ]
      )
    ]
