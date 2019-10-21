open Core
open Async
open Votie_lib
open System
module Config = Voter

let recommended_attrs = ["name"; "favorite color"]

let exitf fmt = ksprintf (fun s -> eprintf "%s\n" s ; exit 1) fmt

let create_config () =
  let%map attributes =
    Deferred.List.map ~how:`Sequential recommended_attrs ~f:(fun key ->
        printf "What is your %s? " key ;
        match%bind Reader.read_line (Lazy.force Reader.stdin) with
        | `Eof ->
            exitf "Got EOF"
        | `Ok value ->
            return {Voter.Attribute.key; value} )
  in
  let padding =
    List.init
      (attribute_count - List.length attributes)
      ~f:(fun _ -> {Voter.Attribute.key= ""; value= ""})
  in
  { Config.private_key= Private_key.create ()
  ; attributes= Array.of_list (attributes @ padding) }

let load_or_create_config () =
  match%bind Sys.is_file_exn config_path with
  | true ->
      Reader.file_contents config_path
      >>| Yojson.Safe.from_string >>| Config.of_yojson
      >>| Result.ok_or_failwith
  | false ->
      printf "Initializing config in %s...\n" config_dir ;
      let%bind () = ensure_dir config_dir in
      let%bind config = create_config () in
      let%map () =
        Writer.save config_path
          ~contents:(Yojson.Safe.to_string (Config.to_yojson config))
      in
      config

let dispatch host_and_port rpc query =
  Tcp.with_connection (Tcp.Where_to_connect.of_host_and_port host_and_port)
    ~timeout:(Time.Span.of_sec 10.) (fun _ r w ->
      let open Deferred.Let_syntax in
      match%bind Rpc.Connection.create r w ~connection_state:(fun _ -> ()) with
      | Error exn ->
          exitf
            !"Error connecting to the registrar at %s: %s."
            (Core.Host_and_port.to_string Votie_rpcs.registrar)
            (Exn.to_string exn)
      | Ok conn -> (
          match%bind Rpc.Rpc.dispatch rpc conn query with
          | Error e ->
              exitf "Got error from registrar: %s" (Core.Error.to_string_hum e)
          | Ok x ->
              return x ) )

let dispatch_registrar rpc = dispatch Votie_rpcs.registrar rpc

let dispatch_daemon rpc = dispatch Voter_lib.daemon rpc

let register () =
  let%bind config = load_or_create_config () in
  printf "Attempting to register...\n" ;
  let%map {index} =
    dispatch_registrar Votie_rpcs.Register.rpc (Config.commit config)
  in
  Core.printf "Registered with ID %d!\n" index

let membership_proofs_dir = config_dir ^/ "membership-proofs"

let vote =
  let main election vote =
    let%bind config = load_or_create_config () in
    match%bind
      let open Deferred.Or_error.Let_syntax in
      let%bind index, path =
        dispatch_registrar Votie_rpcs.Path.rpc (Config.commit config)
      in
      dispatch_daemon Voter_lib.Rpcs.Vote.rpc
        { witness= {membership_proof= {index; path}; voter= config}
        ; election
        ; vote }
    with
    | Error e ->
        exitf "%s\n" (Core.Error.to_string_hum e)
    | Ok () ->
        exit 0
  in
  let open Command in
  let open Param in
  Command.async ~summary:"vote on an election"
    Let_syntax.(
      let%map election = anon ("ELECTION" %: string)
      and vote =
        anon ("VOTE" %: Arg_type.of_alist_exn [("yes", Vote.Yes); ("no", No)])
      in
      fun () -> main election vote)

let elections =
  let main () =
    let%map statuses =
      dispatch_daemon Voter_lib.Rpcs.Elections_status.rpc ()
    in
    Ascii_table.simple_list_table
      ["Election"; "Created at"; "# Yes"; "# No"]
      (List.map (Map.to_alist statuses)
         ~f:(fun ({description; timestamp}, {yes; no}) ->
           [ description
           ; Time.to_string timestamp
           ; Int.to_string yes
           ; Int.to_string no ] ))
  in
  Command.async (Command.Param.return main) ~summary:"list active elections"

let register =
  Command.async ~summary:"Register as a voter" (Command.Param.return register)

let () =
  Command.group ~summary:"voter"
    [("register", register); ("elections", elections); ("vote", vote)]
  |> Command.run
