open Async
open Core
module Cache = Disk_cache.Make (Pickles.Proof.Proofs_verified_2.Stable.Latest)

type cache_db = Cache.t

type t = { cache_id : Cache.id; cache_db : cache_db }

let create_db = Cache.initialize

let unwrap t = Cache.get t.cache_db t.cache_id

let generate cache_db proof =
  let cache_id = Cache.put cache_db proof in
  { cache_id; cache_db }

module For_tests = struct
  let create_db () =
    let open Deferred.Let_syntax in
    Thread_safe.block_on_async_exn (fun () ->
        let%bind db =
          create_db
            (Core.Filename.temp_dir "mina" "proof_cache.lmdb")
            ~logger:(Logger.null ())
        in
        match db with
        | Ok db ->
            return db
        | Error err -> (
            match err with
            | `Initialization_error err ->
                failwithf "cannot initialize db for tests %s"
                  (Error.to_string_hum err) () ) )

  let blockchain_dummy =
    Lazy.map
      ~f:(fun dummy -> generate (create_db ()) dummy)
      Mina_base.Proof.blockchain_dummy

  let transaction_dummy =
    Lazy.map
      ~f:(fun dummy -> generate (create_db ()) dummy)
      Mina_base.Proof.transaction_dummy
end
