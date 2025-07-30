open Async
open Core

module Mock = struct
  type t = { proof : Bounded_types.String.Stable.V1.t }
  [@@deriving bin_io_unversioned]
end

module type S = sig
  module Cache : sig
    type t

    type id
  end

  val logger : Logger.t

  val simple_write :
       ?additional_checks:
         (Cache.t * Mock.t * Mock.t * Cache.id * Cache.id -> unit)
    -> unit
    -> unit

  val initialization_special_cases : unit -> unit

  val remove_data_on_gc : unit -> unit
end

module type S_extended = sig
  include S

  val simple_write_with_iteration : unit -> unit
end

module Make_impl (Cache : Disk_cache_intf.S with module Data := Mock) :
  S with module Cache := Cache = struct
  let () =
    Core.Backtrace.elide := false ;
    Async.Scheduler.set_record_backtraces true

  let logger = Logger.null ()

  let initialize_cache_or_fail tmpd ~logger =
    let open Deferred.Let_syntax in
    let%bind cache_res = Cache.initialize tmpd ~logger in
    match cache_res with
    | Ok cache ->
        return cache
    | Error _err ->
        failwith "error during initialization"

  let simple_write_impl ?(additional_checks = const ()) tmp_dir =
    let%map cache = initialize_cache_or_fail tmp_dir ~logger in

    let proof1 = Mock.{ proof = "dummy" } in
    let proof2 = Mock.{ proof = "smart" } in

    let id1 = Cache.put cache proof1 in
    let id2 = Cache.put cache proof2 in

    additional_checks (cache, proof1, proof2, id1, id2) ;

    [%test_eq: int] (Cache.count cache) 2
      ~message:"cache should contain only 2 elements" ;

    let proof_from_cache1 = Cache.get cache id1 in
    [%test_eq: string] proof1.proof proof_from_cache1.proof
      ~message:"invalid proof from cache" ;

    let proof_from_cache2 = Cache.get cache id2 in
    [%test_eq: string] proof2.proof proof_from_cache2.proof
      ~message:"invalid proof from cache"

  let simple_write ?additional_checks () =
    Async.Thread_safe.block_on_async_exn
    @@ fun () ->
    File_system.with_temp_dir "disk_cache"
      ~f:(simple_write_impl ?additional_checks)

  let remove_data_on_gc_impl tmp_dir =
    let%map cache = initialize_cache_or_fail tmp_dir ~logger in

    let proof = Mock.{ proof = "dummy" } in

    (let id = Cache.put cache proof in

     [%test_eq: int] (Cache.count cache) 1
       ~message:"cache should contain only 1 element" ;

     let proof_from_cache = Cache.get cache id in
     [%test_eq: string] proof.proof proof_from_cache.proof
       ~message:"invalid proof from cache" ) ;

    Gc.compact () ;

    [%test_eq: int] (Cache.count cache) 0
      ~message:"cache should be empty after garbage collector run"

  let remove_data_on_gc () =
    Async.Thread_safe.block_on_async_exn
    @@ fun () ->
    File_system.with_temp_dir "disk_cache-remove_data_on_gc"
      ~f:remove_data_on_gc_impl

  let initialize_and_expect_failure path ~logger =
    let%bind cache_res = Cache.initialize path ~logger in
    match cache_res with
    | Ok _ ->
        failwith "unexpected initialization success"
    | Error _err ->
        return ()

  let initialization_special_cases_impl tmp_dir =
    (* create a directory with 0x000 permissions and initialize from it *)
    let%bind () =
      let perm_denied_dir = tmp_dir ^/ "permission_denied" in
      Core.Unix.mkdir ~perm:0o000 perm_denied_dir ;
      let unreachable = perm_denied_dir ^/ "some_unreachable_path" in
      initialize_and_expect_failure unreachable ~logger
    in

    (* create a directory, create a symlink to it and initialize from a synlimk *)
    let%bind () =
      let some_dir_name = "some_dir" in
      let some_dir = tmp_dir ^/ some_dir_name in
      Core.Unix.mkdir some_dir ;
      let dir_symlink = tmp_dir ^/ "dir_link" in
      Core.Unix.symlink ~target:some_dir_name ~link_name:dir_symlink ;
      Cache.initialize dir_symlink ~logger
      >>| function
      | Ok _ ->
          ()
      | Error _ ->
          failwith "unexpected initialization failure for dir symlink"
    in

    (* create a symlink to a non-existent file, try to initialize from symlink *)
    let%bind () =
      let corrupt_symlink = tmp_dir ^/ "corrupt_link" in
      Core.Unix.symlink ~target:"doesnt_exist" ~link_name:corrupt_symlink ;
      initialize_and_expect_failure corrupt_symlink ~logger
    in

    (* create a file and initialize from it *)
    let%bind some_file_name =
      let some_file_name = "file.txt" in
      let some_file = tmp_dir ^/ some_file_name in
      Out_channel.write_all some_file ~data:"yo" ;
      initialize_and_expect_failure some_file ~logger >>| const some_file_name
    in

    (* create a symlink to an existing file, try to initialize from symlink *)
    let symlink = tmp_dir ^/ "link" in
    Core.Unix.symlink ~target:some_file_name ~link_name:symlink ;
    initialize_and_expect_failure symlink ~logger

  let initialization_special_cases () =
    Async.Thread_safe.block_on_async_exn
    @@ fun () ->
    File_system.with_temp_dir "disk_cache-invalid-initialization"
      ~f:initialization_special_cases_impl
end

module Make (Disk_cache : Disk_cache_intf.F) :
  S with module Cache := Disk_cache(Mock) = struct
  include Make_impl (Disk_cache (Mock))
end

module Make_extended (Disk_cache : Disk_cache_intf.F_extended) :
  S_extended with module Cache := Disk_cache(Mock) = struct
  module Cache = Disk_cache (Mock)
  include Make_impl (Cache)

  let iteration_checks (cache, proof1, proof2, id1, id2) =
    let id1_not_visited = ref true in
    let id2_not_visited = ref true in
    Cache.iteri cache ~f:(fun id content ->
        let expected_content =
          if id = Cache.int_of_id id1 then (
            assert !id1_not_visited ;
            id1_not_visited := false ;
            proof1 )
          else if id = Cache.int_of_id id2 then (
            assert !id2_not_visited ;
            id2_not_visited := false ;
            proof2 )
          else failwith "unexpected key in iteration"
        in
        [%test_eq: string] content.Mock.proof expected_content.Mock.proof ;
        `Continue ) ;
    assert ((not !id1_not_visited) && not !id2_not_visited)

  let simple_write_with_iteration =
    simple_write ~additional_checks:iteration_checks
end
