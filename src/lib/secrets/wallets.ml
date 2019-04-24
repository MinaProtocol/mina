open Core
open Async
module Secret_keypair = Keypair
open Signature_lib

(* A simple cache on top of the fs *)
type t = {mutable cache: Keypair.t list; path: string}

(* TODO: Don't just generate bad passwords *)
let password = lazy (Deferred.Or_error.return (Bytes.of_string ""))

let load ~logger ~disk_location : t Deferred.t =
  let logger =
    Logger.extend logger [("wallets_context", `String "Wallets.get")]
  in
  let path = disk_location ^/ "store" in
  let%bind () = File_system.create_dir path in
  let%bind handle = Unix.opendir path in
  let rec go () =
    match%bind Unix.readdir_opt handle with
    | None ->
        return []
    | Some next_file -> (
        if
          next_file = "." || next_file = ".."
          || Filename.check_suffix next_file ".pub"
        then go ()
        else
          match%bind
            Secret_keypair.read ~privkey_path:(path ^/ next_file) ~password
          with
          | Ok keypair ->
              let%bind xs = go () in
              return (keypair :: xs)
          | Error e ->
              Logger.error logger ~module_:__MODULE__ ~location:__LOC__
                "Failed to read %s: %s" path (Error.to_string_hum e) ;
              go () )
  in
  let%bind () = Unix.chmod path ~perm:0o700 in
  let%map keypairs = go () in
  {cache= keypairs; path}

(** Effectfully generates a new private key file and a keypair *)
let generate_new t : Keypair.t Deferred.t =
  let keypair = Keypair.create () in
  let pubkey_str =
    (* TODO: Do we need to version this? *)
    Public_key.Compressed.to_base64 (keypair.public_key |> Public_key.compress)
    |> String.tr ~target:'/' ~replacement:'x'
  in
  let privkey_path = t.path ^/ pubkey_str in
  let%bind () = Secret_keypair.write_exn keypair ~privkey_path ~password in
  let%map () = Unix.chmod privkey_path ~perm:0o600 in
  t.cache <- keypair :: t.cache ;
  keypair

let get ({cache; _} : t) = cache

let%test_module "wallets" =
  ( module struct
    let logger = Logger.create ()

    module Kp_set = Set.Make (struct
      type t = Keypair.t =
        {public_key: Public_key.t; private_key: Private_key.t sexp_opaque}
      [@@deriving sexp]

      let compare a b = Public_key.compare a.public_key b.public_key
    end)

    let%test_unit "get from scratch" =
      Async.Thread_safe.block_on_async_exn (fun () ->
          File_system.with_temp_dir "/tmp/coda-wallets-test" ~f:(fun path ->
              let%bind wallets = load ~logger ~disk_location:path in
              let%map kp = generate_new wallets in
              let kps = Kp_set.of_list (get wallets) in
              assert (Kp_set.mem kps kp) ) )

    let%test_unit "get from existing file system not-scratch" =
      Backtrace.elide := false ;
      Async.Thread_safe.block_on_async_exn (fun () ->
          File_system.with_temp_dir "/tmp/coda-wallets-test" ~f:(fun path ->
              let%bind wallets = load ~logger ~disk_location:path in
              let%bind kp1 = generate_new wallets in
              let%bind kp2 = generate_new wallets in
              let kps = Kp_set.of_list (get wallets) in
              assert (Kp_set.mem kps kp1 && Kp_set.mem kps kp2) ;
              (* Get wallets again from scratch *)
              let%map wallets = load ~logger ~disk_location:path in
              let kps = Kp_set.of_list (get wallets) in
              assert (Kp_set.mem kps kp1 && Kp_set.mem kps kp2) ) )
  end )
