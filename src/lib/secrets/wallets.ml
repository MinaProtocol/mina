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
    Public_key.Compressed.to_base64 public_key
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
                "Failed to read %s: %s" path (Error.to_string_hum e) ;
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

(** Effectfully generates a new private key file and a keypair *)
let generate_new t : Public_key.Compressed.t Deferred.t =
  let keypair = Keypair.create () in
  let privkey_path = get_path t (Public_key.compress keypair.public_key) in
  let%bind () = Secret_keypair.write_exn keypair ~privkey_path ~password in
  let%map () = Unix.chmod privkey_path ~perm:0o600 in
  let pk = Public_key.compress keypair.public_key in
  Public_key.Compressed.Table.add_exn t.cache ~key:pk ~data:keypair ;
  pk

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
              let%bind kp1 = generate_new wallets in
              let%bind kp2 = generate_new wallets in
              let keys = Set.of_list (pks wallets) in
              assert (Set.mem keys kp1 && Set.mem keys kp2) ;
              (* Get wallets again from scratch *)
              let%map wallets = load ~logger ~disk_location:path in
              let keys = Set.of_list (pks wallets) in
              assert (Set.mem keys kp1 && Set.mem keys kp2) ) )
  end )
