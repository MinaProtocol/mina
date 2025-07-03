(* Test for cache deadlock with finalizers - works with any disk_cache implementation *)

open Core
open Async

(* Create a custom binable module that triggers GC during serialization *)
module Evil_data = struct
  module T = struct
    type t = { value : string; trigger_gc : (unit -> unit) option }
    [@@deriving sexp]
  end

  include T

  (* We convert to/from string for bin_io, injecting our GC trigger during conversion *)
  include
    Binable.Of_binable_without_uuid
      (String)
      (struct
        type nonrec t = t

        let to_binable t =
          (* Trigger GC during serialization if requested *)
          Option.iter t.trigger_gc ~f:(fun f -> f ()) ;
          t.value

        let of_binable value = { value; trigger_gc = None }
      end)
end

module type Cache_intf = sig
  module Make : Disk_cache_intf.F
end

let run_test_with_cache (module Cache_impl : Cache_intf) ~timeout_seconds
    ~tmpdir =
  let module Cache = Cache_impl.Make (Evil_data) in
  let%bind cache_result = Cache.initialize tmpdir ~logger:(Logger.null ()) in
  let cache =
    match cache_result with
    | Ok cache ->
        cache
    | Error (`Initialization_error err) ->
        failwithf "Failed to initialize cache: %s" (Error.to_string_hum err) ()
  in

  (* Create a cache entry that will be garbage collected when serializing "evil"
     data *)
  let entry_ref = ref None in
  let entry_data = { Evil_data.value = "entry"; trigger_gc = None } in
  entry_ref := Some (Cache.put cache entry_data) ;

  (* Create evil data that triggers GC during serialization *)
  let evil_data =
    { Evil_data.value = "evil"
    ; trigger_gc =
        Some
          (fun () ->
            (* Clear reference and trigger GC to run finalizers *)
            entry_ref := None ;
            Core.printf "References cleared, triggering GC...\n%!" ;
            Gc.compact () ;
            Core.printf
              "GC triggered during serialization - finalizers should run now\n\
               %!" )
    }
  in

  (* This put may deadlock if a finalizer runs during serialization *)
  Core.printf "Attempting evil put...\n%!" ;

  (* Run the potentially deadlocking operation with a timeout *)
  let put_with_timeout () =
    let put_deferred =
      In_thread.run (fun () ->
          ignore (Cache.put cache evil_data : Cache.id) ;
          `Success )
    in
    match timeout_seconds with
    | Some timeout ->
        let timeout_span = Core.Time.Span.of_sec timeout in
        Clock.with_timeout timeout_span put_deferred
    | None ->
        let%map result = put_deferred in
        `Result result
  in

  match%bind put_with_timeout () with
  | `Timeout ->
      Core.printf
        "\nDEADLOCK DETECTED: Cache.put timed out after %.1f seconds!\n%!"
        (Option.value_exn timeout_seconds) ;
      Core.printf "This indicates a deadlock in the cache implementation.\n%!" ;
      Core.printf "The finalizer likely tried to acquire a lock during GC.\n%!" ;
      return ()
  | `Result `Success ->
      Core.printf "Evil put completed successfully (no deadlock)\n%!" ;
      Core.printf "\nSUCCESS: Cache does NOT deadlock with finalizers.\n%!" ;
      return ()

let test_cache_deadlock (module Cache_impl : Cache_intf) =
  let open Async in
  let open Deferred.Let_syntax in
  
  (* Read configuration from environment variables *)
  let timeout_seconds = 
    match Sys.getenv "CACHE_DEADLOCK_TEST_TIMEOUT" with
    | Some "" -> None  (* Empty string means no timeout *)
    | Some t -> Some (Float.of_string t)
    | None -> Some 10.0  (* Default 10 second timeout for CI *)
  in
  let database_dir = Sys.getenv "CACHE_DEADLOCK_TEST_DIR" in
  
  Core.printf "\nCache deadlock test\n%!" ;
  Core.printf "===================\n%!" ;
  ( match timeout_seconds with
  | Some t ->
      Core.printf "Timeout: %.1f seconds\n%!" t
  | None ->
      Core.printf "Timeout: disabled (test will hang if deadlock occurs)\n%!" ) ;
  Core.printf "\n%!" ;

  let run_in_dir dir =
    Core.printf "Using database directory: %s\n%!" dir ;
    let%bind () =
      run_test_with_cache
        (module Cache_impl)
        ~timeout_seconds ~tmpdir:dir
    in
    Core.printf "\nTest completed successfully.\n%!" ;
    return ()
  in

  match database_dir with
  | Some dir -> run_in_dir dir
  | None ->
      File_system.with_temp_dir "/tmp/cache_deadlock_test" ~f:run_in_dir
