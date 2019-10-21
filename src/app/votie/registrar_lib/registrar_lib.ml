open Core_kernel
open Async
open Votie_lib
open Votie_rpcs

module State = struct
  type closed =
    { tree: Voter_tree.t
    ; elections_state: Elections_state.t
    ; commitments: int Voter.Commitment.Map.t }

  type open_ =
    { commitments: int Voter.Commitment.Map.t
    ; count: int
    ; keypair: Universe.Crypto.Run.Keypair.t }

  type t = Open of open_ | Closed of closed

  let empty keypair =
    Open {count= 0; commitments= Voter.Commitment.Map.empty; keypair}

  let merkle_root t =
    Voter_tree.merkle_root
      (Voter_tree.of_list ~default:Voter.Commitment.null t)

  let path ~state voter =
    match state with
    | Open _ ->
        failwith "Cannot get path before registration is closed"
    | Closed s -> (
        ( state
        , match Map.find s.commitments voter with
          | None ->
              Or_error.errorf "Voter not registered"
          | Some index ->
              Ok
                ( index
                , List.map (Voter_tree.path_exn s.tree index) ~f:(function
                      | `Left h | `Right h -> h ) ) ) )

  let register ~state (query : Register.query) =
    match state with
    | Closed _ ->
        failwith "Registration is closed"
    | Open {keypair; count; commitments} ->
        let index = count in
        ( Open
            { count= count + 1
            ; keypair
            ; commitments= Map.add_exn commitments ~data:index ~key:query }
        , {Register.index} )

  let submit_vote ~state (query : Submit_vote.query) =
    match state with
    | Open _ ->
        failwith "Cannot get path before registration is closed"
    | Closed s -> (
      match Elections_state.add_vote s.elections_state query with
      | Ok es ->
          (Closed {s with elections_state= es}, Ok ())
      | Error e ->
          (Closed s, Error (Votie_lib.Error.to_error e)) )
end

module Commander = struct
  open Commander.Command_spec

  let port = 8001

  let commands =
    let close_registration =
      T
        { name= "close-registration"
        ; param= Command.Param.return ()
        ; bin_query= Unit.bin_t
        ; bin_response= Unit.bin_t
        ; on_response= (fun _ -> Deferred.unit)
        ; handle=
            (fun ~state () ->
              ( match !state with
              | State.Closed _ ->
                  ()
              | Open {count= _; commitments; keypair} ->
                  let tree =
                    Voter_tree.of_list ~default:Voter.Commitment.null
                      ( List.sort (Map.to_alist commitments)
                          ~compare:(fun (_, i) (_, j) -> Int.compare i j)
                      |> List.map ~f:fst )
                  in
                  state :=
                    State.Closed
                      { tree
                      ; commitments
                      ; elections_state=
                          Elections_state.create
                            {keypair; voters_root= Voter_tree.merkle_root tree}
                      } ) ;
              Deferred.unit ) }
    in
    [close_registration]
end
