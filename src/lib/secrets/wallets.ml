open Core
open Async
module Secret_keypair = Keypair
open Signature_lib

(* A simple cache on top of the fs *)
type t = {cache: Keypair.t Public_key.Compressed.Table.t; path: string}

(* TODO: Don't just generate bad passwords *)
let password = lazy (Deferred.Or_error.return (Bytes.of_string ""))

let get_path {path; _} public_key =
  let pubkey_str =
    (* TODO: Do we need to version this? *)
    Public_key.Compressed.to_base58_check public_key
    |> String.tr ~target:'/' ~replacement:'x'
  in
  path ^/ pubkey_str

let load ~logger ~disk_location : t Deferred.t =
  let logger =
    Logger.extend logger [("wallets_context", `String "Wallets.get")]
  in
  let path = disk_location ^/ "store" in
  let%bind () = File_system.create_dir path in
  let%bind files = Sys.readdir path >>| Array.to_list in
  let%bind keypairs =
    Deferred.List.filter_map files ~f:(fun file ->
        if Filename.check_suffix file ".pub" then return None
        else
          match%map
            Secret_keypair.read ~privkey_path:(path ^/ file) ~password
          with
          | Ok keypair ->
              Some (keypair.public_key |> Public_key.compress, keypair)
          | Error e ->
              Logger.error logger ~module_:__MODULE__ ~location:__LOC__
                "Error reading key pair at $path/$file: $error"
                ~metadata:
                  [ ("file", `String file)
                  ; ("path", `String path)
                  ; ("error", `String (Error.to_string_hum e)) ] ;
              None )
  in
  let%map () = Unix.chmod path ~perm:0o700 in
  let cache =
    match Public_key.Compressed.Table.of_alist keypairs with
    | `Ok m ->
        m
    | `Duplicate_key _ ->
        failwith "impossible"
  in
  {cache; path}

(** Generates a new private key file for the given keypair *)
let import_keypair t keypair : Public_key.Compressed.t Deferred.t =
  let privkey_path =
    get_path t (Public_key.compress keypair.Keypair.public_key)
  in
  let%bind () = Secret_keypair.write_exn keypair ~privkey_path ~password in
  let%map () = Unix.chmod privkey_path ~perm:0o600 in
  let pk = Public_key.compress keypair.public_key in
  Public_key.Compressed.Table.add_exn t.cache ~key:pk ~data:keypair ;
  pk

(** Generates a new private key file and a keypair *)
let generate_new t : Public_key.Compressed.t Deferred.t =
  let keypair = Keypair.create () in
  import_keypair t keypair

let delete ({cache; _} as t : t) (pk : Public_key.Compressed.t) :
    (unit, [`Not_found]) Deferred.Result.t =
  Hashtbl.remove cache pk ;
  Deferred.Or_error.try_with (fun () -> Unix.remove (get_path t pk))
  |> Deferred.Result.map_error ~f:(fun _ -> `Not_found)

let pks ({cache; _} : t) = Public_key.Compressed.Table.keys cache

let find ({cache; _} : t) ~needle =
  Public_key.Compressed.Table.find cache needle

let%test_module "wallets" =
  ( module struct
    let logger = Logger.create ()

    module Set = Public_key.Compressed.Set

    let%test_unit "get from scratch" =
      Async.Thread_safe.block_on_async_exn (fun () ->
          File_system.with_temp_dir "/tmp/coda-wallets-test" ~f:(fun path ->
              let%bind wallets = load ~logger ~disk_location:path in
              let%map pk = generate_new wallets in
              let keys = Set.of_list (pks wallets) in
              assert (Set.mem keys pk) ;
              assert (find wallets ~needle:pk |> Option.is_some) ) )

    let%test_unit "get from existing file system not-scratch" =
      Backtrace.elide := false ;
      Async.Thread_safe.block_on_async_exn (fun () ->
          File_system.with_temp_dir "/tmp/coda-wallets-test" ~f:(fun path ->
              let%bind wallets = load ~logger ~disk_location:path in
              let%bind pk1 = generate_new wallets in
              let%bind pk2 = generate_new wallets in
              let keys = Set.of_list (pks wallets) in
              assert (Set.mem keys pk1 && Set.mem keys pk2) ;
              (* Get wallets again from scratch *)
              let%map wallets = load ~logger ~disk_location:path in
              let keys = Set.of_list (pks wallets) in
              assert (Set.mem keys pk1 && Set.mem keys pk2) ) )

    let%test_unit "create wallet then delete it" =
      Async.Thread_safe.block_on_async_exn (fun () ->
          File_system.with_temp_dir "/tmp/coda-wallets-test" ~f:(fun path ->
              let%bind wallets = load ~logger ~disk_location:path in
              let%bind pk = generate_new wallets in
              let keys = Set.of_list (pks wallets) in
              assert (Set.mem keys pk) ;
              match%map delete wallets pk with
              | Ok () ->
                  assert (Option.is_none @@ find wallets ~needle:pk)
              | Error _ ->
                  failwith "unexpected" ) )

    let%test_unit "Unable to find wallet" =
      Async.Thread_safe.block_on_async_exn (fun () ->
          File_system.with_temp_dir "/tmp/coda-wallets-test" ~f:(fun path ->
              let%bind wallets = load ~logger ~disk_location:path in
              let keypair = Keypair.create () in
              let%map result =
                delete wallets (Public_key.compress @@ keypair.public_key)
              in
              assert (Result.is_error result) ) )
  end )
