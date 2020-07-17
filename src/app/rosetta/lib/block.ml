open Core_kernel
open Async
open Models

(* TODO: Populate postgres DB with at least one of each kind of transaction and then make sure ops make sense *)
module User_command_info = struct
  module Kind = struct
    type t =
      [`Payment | `Delegation | `Create_token | `Create_account | `Mint_tokens]
  end

  type t =
    { kind: Kind.t
    ; fee_payer: [`Pk of string]
    ; source: [`Pk of string]
    ; receiver: [`Pk of string]
    ; fee_token: Unsigned.UInt64.t
    ; token: Unsigned.UInt64.t
    ; fee: Unsigned.UInt64.t
    ; nonce: Unsigned.UInt32.t
    ; amount: Unsigned.UInt64.t option
    ; hash: string }

  module Op = struct
    type 'a t = {label: 'a; related_to: 'a option} [@@deriving eq]
  end

  let account_id (`Pk pk) token_id =
    { Account_identifier.address= pk
    ; sub_account= None
    ; metadata= Some (Amount_of.Token_id.encode token_id) }

  let to_operations block_creator_pk (t : t) : Operation.t list =
    (* First build a plan. The plan specifies all operations ahead of time so
     * we can later compute indices and relations when we're building the full
     * models.
     *
     * For now, relations will be defined only on the two sides of a given
     * transfer. ie. Source decreases, and receiver increases.
    *)
    let plan : 'a Op.t list =
      (* there is always a fee transfer
       * which has a increase in the receiver and decrease in the source (2 ops)
       * *)
      [ {Op.label= `Fee_payer_dec; related_to= None}
      ; {Op.label= `Fee_creator_inc; related_to= Some `Fee_payer_dec} ]
      @
      (* When amount is not none, we move the amount from source to receiver *)
      match t.amount with
      | Some amount ->
          [ {Op.label= `Payment_source_dec amount; related_to= None}
          ; { Op.label= `Payment_receiver_inc amount
            ; related_to= Some (`Payment_source_dec amount) } ]
      | None ->
          []
      (* TODO: Add all other ops (conditionally, to the plan depending on the kind) *)
    in
    List.mapi plan ~f:(fun i op ->
        let operation_identifier i =
          {Operation_identifier.index= Int64.of_int_exn i; network_index= None}
        in
        let related_operations =
          match op.related_to with
          | Some relate ->
              List.findi plan ~f:(fun _ a ->
                  [%eq:
                    [ `Fee_payer_dec
                    | `Fee_creator_inc
                    | `Payment_source_dec of Unsigned.UInt64.t
                    | `Payment_receiver_inc of Unsigned.UInt64.t ]] relate
                    a.label )
              |> Option.map ~f:(fun (i, _) -> operation_identifier i)
              |> Option.to_list
          | None ->
              []
        in
        let status = Operation_statuses.name `Success in
        match op.label with
        | `Fee_payer_dec ->
            { Operation.operation_identifier= operation_identifier i
            ; related_operations
            ; status
            ; account= Some (account_id t.fee_payer t.fee_token)
            ; _type= Operation_types.name `Fee_payer_dec
            ; amount= Some (Amount_of.token t.fee_token t.fee)
            ; metadata= None }
        | `Fee_creator_inc ->
            { Operation.operation_identifier= operation_identifier i
            ; related_operations
            ; status
            ; account= Some (account_id block_creator_pk t.fee_token)
            ; _type= Operation_types.name `Fee_creator_inc
            ; amount= Some (Amount_of.token t.fee_token t.fee)
            ; metadata= None }
        | `Payment_source_dec amount ->
            { Operation.operation_identifier= operation_identifier i
            ; related_operations
            ; status
            ; account= Some (account_id t.source t.token)
            ; _type= Operation_types.name `Payment_source_dec
            ; amount= Some (Amount_of.token t.token amount)
            ; metadata= None }
        | `Payment_receiver_inc amount ->
            { Operation.operation_identifier= operation_identifier i
            ; related_operations
            ; status
            ; account= Some (account_id t.source t.token)
            ; _type= Operation_types.name `Payment_source_dec
            ; amount= Some (Amount_of.token t.token amount)
            ; metadata= None } )

  (* 
        { Operation.operation_identifier=
            {Operation_identifier.index= i; network_index= None}
        ; related_operations=
            [ ( match op.related_to with
              | Some relate ->
                  List.findi ~f:(fun _ a ->
                      if [%eq: int] 1 2 then failwith "A" else failwith "B" )
              | None ->
                  None ) ]
        ; account=
            ( match op with
            | `Fee_payer_dec ->
                Some (account_id t.fee_payer t.fee_token)
            | `Fee_receiver_inc ->
                Some (account_id block_creator_pk t.fee_token)
            | `Payment_source_dec _ ->
                Some (account_id t.source t.token)
            | `Payment_receiver_inc _ ->
                Some (account_id t.receiver t.token) )
        ; status= Operation_statuses.operation `Success
        ; _type=
            Operation_types.name
              ( match op with
              | `Fee_payer_dec ->
                  `Fee_payer_dec
              | `Fee_receiver_inc ->
                  `Fee_receiver_inc
              | `Payment_source_dec _ ->
                  `Payment_source_dec
              | `Payment_receiver_inc _ ->
                  `Payment_receiver_inc )
        ; amount= 
          Amount_of.token t.fee_token t.fee
        ; metadata= None } ) *)

  let dummies =
    [ { kind= `Payment
      ; fee_payer= `Pk "Alice"
      ; source= `Pk "Alice"
      ; token= Unsigned.UInt64.of_int 1
      ; fee= Unsigned.UInt64.of_int 2_000_000_000
      ; receiver= `Pk "Bob"
      ; fee_token= Unsigned.UInt64.of_int 1
      ; nonce= Unsigned.UInt32.of_int 3
      ; amount= Some (Unsigned.UInt64.of_int 2_000_000_000)
      ; hash= "TXN_1_HASH" } ]
end

module Internal_command_info = struct
  type t =
    { receiver: [`Pk of string]
    ; fee: Unsigned.UInt64.t
    ; token: Unsigned.UInt32.t }

  let dummies =
    [ { receiver= `Pk "Alice"
      ; fee= Unsigned.UInt64.of_int 2_000_000_000
      ; token= Unsigned.UInt32.of_int 1 }
    ; { receiver= `Pk "Bob"
      ; fee= Unsigned.UInt64.of_int 20_000_000_000
      ; token= Unsigned.UInt32.of_int 1 } ]
end

module Block_info = struct
  type t =
    { block_identifier: Block_identifier.t
    ; parent_block_identifier: Block_identifier.t
    ; timestamp: int64
    ; internal_info: Internal_command_info.t list
    ; user_commands: User_command_info.t list }

  let dummy =
    { block_identifier=
        Block_identifier.create (Int64.of_int_exn 4) "STATE_HASH_BLOCK"
    ; parent_block_identifier=
        Block_identifier.create (Int64.of_int_exn 3) "STATE_HASH_PARENT"
    ; timestamp= Int64.of_int_exn 1594937771
    ; internal_info= Internal_command_info.dummies
    ; user_commands= User_command_info.dummies }
end

module Specific = struct
  module Env = struct
    (* All side-effects go in the env so we can mock them out later *)
    module T (M : Monad_fail.S) = struct
      type 'gql t =
        { gql: unit -> ('gql, Errors.t) M.t
        ; db_block: unit -> (Block_info.t, Errors.t) M.t
        ; validate_network_choice: 'gql Network.Validate_choice.Impl(M).t }
    end

    (* The real environment does things asynchronously *)
    module Real = T (Deferred.Result)

    (* But for tests, we want things to go fast *)
    module Mock = T (Result)

    let real :
        db:(module Caqti_async.CONNECTION) -> graphql_uri:Uri.t -> 'gql Real.t
        =
     fun ~db:_ ~graphql_uri ->
      { gql= (fun () -> Graphql.query (Network.Get_network.make ()) graphql_uri)
      ; db_block= (fun () -> failwith "Figure out how to do the sql")
      ; validate_network_choice= Network.Validate_choice.Real.validate }

    let mock : 'gql Mock.t =
      { gql=
          (fun () ->
            (* TODO: Add variants to cover every branch *)
            Result.return @@ object end )
      ; db_block= (fun () -> Result.return @@ Block_info.dummy)
      ; validate_network_choice= Network.Validate_choice.Mock.succeed }
  end

  module Impl (M : Monad_fail.S) = struct
    module E = Env.T (M)

    let handle :
        env:'gql E.t -> Block_request.t -> (Block_response.t, Errors.t) M.t =
     fun ~env req ->
      let open M.Let_syntax in
      (* TODO: Support alternate tokens *)
      let%bind res = env.gql () in
      let%map () =
        env.validate_network_choice ~network_identifier:req.network_identifier
          ~gql_response:res
      in
      failwith "TODO"
  end

  module Real = Impl (Deferred.Result)
end

let router ~graphql_uri ~logger:_ ~db (route : string list) body =
  let (module Db : Caqti_async.CONNECTION) = db in
  let open Async.Deferred.Result.Let_syntax in
  match route with
  | [] ->
      let%bind req =
        Errors.Lift.parse ~context:"Request" @@ Block_request.of_yojson body
        |> Errors.Lift.wrap
      in
      let%map res =
        Specific.Real.handle ~env:(Specific.Env.real ~db ~graphql_uri) req
        |> Errors.Lift.wrap
      in
      Block_response.to_yojson res
  | _ ->
      Deferred.Result.fail `Page_not_found
