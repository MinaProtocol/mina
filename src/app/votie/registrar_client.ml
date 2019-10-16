open Core
open Async
open Votie_lib

let config_dir = Sys.getenv_exn "HOME" ^/ ".config" ^/ "votie"

let config_path = config_dir ^/ "config"

module Config = Voter

let recommended_attrs =
  [ "name"
  ; "favorite color"
  ]

let exitf fmt = ksprintf (fun s ->
    eprintf "%s\n" s;
    exit 1) fmt

let create_config () =
  let%map attributes =
    Deferred.List.map ~how:`Sequential recommended_attrs ~f:(fun key ->
        printf "What is your %s? " key;
        match%bind Reader.read_line (Lazy.force Reader.stdin) with
        | `Eof -> exitf "Got EOF"
        | `Ok value -> return {Voter.Attribute. key; value})
  in
  let padding = 
    List.init (attribute_count - List.length attributes)
      ~f:(fun _ -> { Voter.Attribute.key=""; value=""} )
  in
  { Config.private_key = Private_key.create ()
  ; attributes =
      Array.of_list (attributes @ padding)
  }

let ensure_dir dir =
  match%bind Sys.is_directory_exn dir with
  | true -> return ()
  | false -> Unix.mkdir ~p:() dir

let load_or_create_config () =
  match%bind Sys.is_file_exn config_path with
  | true -> Reader.file_contents config_path
    >>| Yojson.Safe.from_string
    >>| Config.of_yojson
    >>| Result.ok_or_failwith
  | false ->
    printf "Initializing config in %s..." config_dir;
    let%bind () = ensure_dir config_dir in
    let%bind config = create_config () in
    let%map () = Writer.save  config_path
                    ~contents:(Yojson.Safe.to_string (Config.to_yojson config))
    in
    config

let dispatch rpc query =
  Tcp.with_connection
    (Tcp.Where_to_connect.of_host_and_port
       { host = Votie_rpcs.server_address; port = Votie_rpcs.server_port } )
    ~timeout:(Time.Span.of_sec 10.)
    (fun _ r w ->
      let open Deferred.Let_syntax in
      match%bind Rpc.Connection.create r w ~connection_state:(fun _ -> ()) with
      | Error exn ->
          exitf !"Error connecting to the registrar on port %d: %s."
            Votie_rpcs.server_port 
            (Exn.to_string exn)
      | Ok conn ->
        match%bind
          Rpc.Rpc.dispatch rpc conn query 
        with
        | Error e ->
          exitf "Got error from registrar: %s" (Core.Error.to_string_hum e)
        | Ok x -> return x)


let register () =
  let%bind config = load_or_create_config () in
  printf "Attempting to register...";
  let%map {index} = dispatch Votie_rpcs.Register.rpc (Config.commit config) in
  Core.printf "Registered with ID %d!\nPlease save this ID for later.\n" index

module Membership_proof = struct
  type t =
    { index : int; path : Hash.t list } [@@deriving yojson]
end

let membership_proofs_dir = config_dir^/ "membership-proofs"

let path index =
  let%bind config = load_or_create_config () in
  printf "Attempting to get membership proof for index %d..." index;
  let%map path = dispatch Votie_rpcs.Path.rpc { index } in
  let%bind () = ensure_dir membership_proofs_dir in
  let root = Voter_tree.implied_root (Config.commit config) index path in
  Writer.save (membership_proofs_dir ^/ Field.to_string root)
    ~contents:(Yojson.Safe.to_string (Membership_proof.to_yojson { index; path }))
