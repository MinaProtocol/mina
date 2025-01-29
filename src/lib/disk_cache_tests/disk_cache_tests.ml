open Async
open Core

let%test_module "Disk cache tests" =
  ( module struct
    module Mock = struct
      type t = { proof : Bounded_types.String.Stable.V1.t } [@@deriving bin_io]
    end

    module Cache = Disk_cache.Make (Mock)

    let logger = Logger.create ()

    let () =
      Backtrace.elide := false ;
      Async.Scheduler.set_record_backtraces true

    let initialize_cache_or_fail tmpd ~logger =
      let open Deferred.Let_syntax in
      let%bind cache_res = Cache.initialize tmpd ~logger in
      match cache_res with
      | Ok cache ->
          return cache
      | Error _err ->
          failwith "error during initialization"

    let%test_unit "simple_write" =
      Async.Thread_safe.block_on_async_exn (fun () ->
          let open Deferred.Let_syntax in
          File_system.with_temp_dir "/tmp/simple_write" ~f:(fun tmpd ->
              let%bind cache = initialize_cache_or_fail tmpd ~logger in

              let proof1 = Mock.{ proof = "dummy" } in
              let proof2 = Mock.{ proof = "smart" } in

              let id1 = Cache.put cache proof1 in
              let id2 = Cache.put cache proof2 in

              (let id1_not_visited = ref true in
               let id2_not_visited = ref true in
               Cache.iteri cache ~f:(fun id content ->
                   let expected_content =
                     if id = Cache.For_tests.int_of_id id1 then (
                       assert !id1_not_visited ;
                       id1_not_visited := false ;
                       proof1 )
                     else if id = Cache.For_tests.int_of_id id2 then (
                       assert !id2_not_visited ;
                       id2_not_visited := false ;
                       proof2 )
                     else failwith "unexpected key in iteration"
                   in
                   [%test_eq: string] content.proof expected_content.proof ;
                   `Continue ) ;
               assert ((not !id1_not_visited) && not !id2_not_visited) ) ;

              [%test_eq: int] (Cache.count cache) 2
                ~message:"cache should contain only 2 elements" ;

              let proof_from_cache1 = Cache.get cache id1 in
              [%test_eq: string] proof1.proof proof_from_cache1.proof
                ~message:"invalid proof from cache" ;

              let proof_from_cache2 = Cache.get cache id2 in
              [%test_eq: string] proof2.proof proof_from_cache2.proof
                ~message:"invalid proof from cache" ;

              Deferred.unit ) )

    let%test_unit "remove_data_on_gc" =
      Async.Thread_safe.block_on_async_exn (fun () ->
          let open Deferred.Let_syntax in
          File_system.with_temp_dir "/tmp/remove_data_on_gc" ~f:(fun tmpd ->
              let%bind cache = initialize_cache_or_fail tmpd ~logger in

              let proof = Mock.{ proof = "dummy" } in

              (let id = Cache.put cache proof in

               [%test_eq: int] (Cache.count cache) 1
                 ~message:"cache should contain only 1 element" ;

               let proof_from_cache = Cache.get cache id in
               [%test_eq: string] proof.proof proof_from_cache.proof
                 ~message:"invalid proof from cache" ) ;

              Gc.compact () ;

              [%test_eq: int] (Cache.count cache) 0
                ~message:"cache should be empty after garbage collector run" ;

              Deferred.unit ) )
  end )
