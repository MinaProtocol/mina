open Core
open Votie_rpcs
open Async
open Votie_lib

let get_keypair () =
  let open Universe.Crypto.Run in
  let open System in
  let verification_key_path = config_dir ^/ "verification-key" in
  let proving_key_path = config_dir ^/ "proving-key" in
  let%bind () = ensure_dir config_dir in
  match%bind Sys.file_exists_exn verification_key_path with
  | true ->
      let%map vk =
        Reader.load_bin_prot_exn verification_key_path
          Verification_key.bin_reader_t
      and pk =
        Reader.load_bin_prot_exn verification_key_path Proving_key.bin_reader_t
      in
      Keypair.create ~pk ~vk
  | false ->
      eprintf "Creating keypair...\n%!" ;
      let keys = generate_keypair ~exposing:(Snark.input ()) Snark.main in
      eprintf "done!\n%!" ;
      let pk, vk = Keypair.(pk keys, vk keys) in
      let%bind () =
        Writer.save_bin_prot verification_key_path
          Verification_key.bin_writer_t vk
      in
      let%bind () =
        Writer.save_bin_prot proving_key_path Proving_key.bin_writer_t pk
      in
      return keys

let main () =
  let open Rpc in
  let%bind keypair = get_keypair () in
  let registration_closed = Ivar.create () in
  let state = ref (Registrar_lib.State.empty keypair) in
  let closed_state = ref None in
  let stateful f () q =
    let s, r = f ~state:!state q in
    ( match s with
    | Registrar_lib.State.Closed c ->
        closed_state := Some c ;
        Ivar.fill registration_closed ()
    | Open _ ->
        () ) ;
    state := s ;
    r
  in
  let implement rpc f = Rpc.implement' rpc (stateful f) in
  let subscriptions = ref [] in
  let implementations =
    let open Registrar_lib in
    Implementations.create_exn ~on_unknown_rpc:`Close_connection
      ~implementations:
        [ implement Register.rpc State.register
        ; implement Path.rpc State.path
        ; implement Submit_vote.rpc (fun ~state v ->
              List.iter !subscriptions ~f:(fun w ->
                  Pipe.write_without_pushback w v ) ;
              State.submit_vote ~state v )
        ; State_rpc.implement Votes.rpc (fun _ () ->
              let r, w = Pipe.create () in
              subscriptions := w :: !subscriptions ;
              let%map () = Ivar.read registration_closed in
              Ok ((Option.value_exn !closed_state).elections_state, r) ) ]
  in
  let log_error = `Call (fun _ e -> eprintf "%s\n" (Exn.to_string e)) in
  let%bind _ =
    Tcp.Server.create
      Tcp.(
        Where_to_listen.bind_to
          (Bind_to_address.Address (Unix.Inet_addr.of_string "0.0.0.0"))
          (Bind_to_port.On_port registrar.port))
      ~on_handler_error:log_error
      (fun _ reader writer ->
        Connection.server_with_close reader writer ~implementations
          ~connection_state:(fun _ -> ())
          ~on_handshake_error:
            (`Call
              (fun e ->
                eprintf "%s\n" (Exn.to_string e) ;
                Deferred.unit )) )
  in
  let%bind _ =
    Commander.Command_spec.create_daemon_server
      ~daemon_port:Registrar_lib.Commander.port ~state
      Registrar_lib.Commander.commands
  in
  Deferred.never ()

let () =
  let open Command in
  async ~summary:"Registrar" (Param.return main) |> run
