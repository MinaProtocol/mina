open Core_kernel
open Votie_lib
open Votie_rpcs

module State = struct
  type t =
    { commitments : Voter.Commitment.t list
    ; count : int 
    ; tree : Voter_tree.t option
    }

  let empty = { count=0; commitments = []; tree = None }

  let merkle_root t =
    Voter_tree.merkle_root
      (Voter_tree.of_list ~default:Voter.Commitment.null t)

  let path ~state:s {Path.index} =
    let tree =
      match s.tree with
      | None -> 
        Voter_tree.of_list ~default:Voter.Commitment.null
          (List.rev s.commitments)
      | Some tree -> tree
    in
    (  { s with tree = Some tree },
      List.map (Voter_tree.path_exn tree index) ~f:(function
        | `Left h | `Right h -> h))

  let register ~state:{ tree; count; commitments } (query : Register.query) =
    let index = count in
    match tree with
    | Some _ -> failwith "Cannot register once tree has been computed"
    | None ->
      ( { tree; count = count + 1
        ; commitments = query :: commitments }
      , { Register.index } )
end

open Async

let main () =
  let open Rpc in
  let state = ref State.empty in
  let stateful f =
    fun () q ->
      let (s, r) = f ~state:!state q in
      state := s;
      r
  in
  let implement rpc f =
    Rpc.implement' rpc (stateful f)
  in
  let implementations =
    Implementations.create_exn
      ~on_unknown_rpc:`Close_connection
      ~implementations:
        [ implement Register.rpc State.register
        ; implement Path.rpc State.path
        ]
  in
  let log_error = `Call (fun _ e ->
        eprintf "%s\n" 
          (Exn.to_string e)) in
  let%bind _ =
    Tcp.Server.create
      Tcp.(
        Where_to_listen.bind_to
          (Bind_to_address.Address (Unix.Inet_addr.of_string "0.0.0.0"))
          (Bind_to_port.On_port server_port)
      )
      ~on_handler_error:log_error (fun _ reader writer ->
          Connection.server_with_close reader writer
            ~implementations
            ~connection_state:(fun _ -> ())
            ~on_handshake_error:(`Call (fun e ->
                eprintf "%s\n" (Exn.to_string e);
                Deferred.unit))
        )
  in
  Deferred.never ()

let () =
  Command.async
    ~summary:"Registrar"
    Command.Param.(return main)
  |> Command.run
