open Core_kernel

module T = struct
  module Store = Key_cache_unix.Sync

  let run_in_thread f = Async.In_thread.run f

  let store ~read ~write =
    Store.Disk_storable.simple
      (fun name -> name)
      (fun _name ~path ->
        Or_error.try_with_join (fun () ->
            match read path with
            | Some urs ->
                Ok urs
            | None ->
                Or_error.errorf
                  "Could not read the URS from disk; its format did not match \
                   the expected format"))
      (fun _ urs path -> Or_error.try_with (fun () -> write urs path))
end

let () = Zexe_backend_platform_specific.set (module T)

let linkme = ()
