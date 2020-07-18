open Core_kernel
open Async
open Models

let account_id (`Pk pk) token_id =
  { Account_identifier.address= pk
  ; sub_account= None
  ; metadata= Some (Amount_of.Token_id.encode token_id) }

module Op = struct
  type 'a t = {label: 'a; related_to: 'a option} [@@deriving eq]

  let build ~a_eq ~plan ~f =
    List.mapi plan ~f:(fun i op ->
        let operation_identifier i =
          {Operation_identifier.index= Int64.of_int_exn i; network_index= None}
        in
        let related_operations =
          match op.related_to with
          | Some relate ->
              List.findi plan ~f:(fun _ a -> a_eq relate a.label)
              |> Option.map ~f:(fun (i, _) -> operation_identifier i)
              |> Option.to_list
          | None ->
              []
        in
        f ~related_operations ~operation_identifier:(operation_identifier i) op
    )
end

(* TODO: Populate postgres DB with at least one of each kind of transaction and then make sure ops make sense *)
module User_command_info = struct
  module Kind = struct
    type t =
      [`Payment | `Delegation | `Create_token | `Create_account | `Mint_tokens]
  end

  module Failure_status = struct
    type t = [`Applied | `Failed of string] [@@deriving eq]
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
    ; hash: string
    ; failure_status: Failure_status.t }

  let to_operations ~account_creation_fee ~block_creator_pk (t : t) :
      Operation.t list =
    (* First build a plan. The plan specifies all operations ahead of time so
     * we can later compute indices and relations when we're building the full
     * models.
     *
     * For now, relations will be defined only on the two sides of a given
     * transfer. ie. Source decreases, and receiver increases.
    *)
    let plan : 'a Op.t list =
      (* there is always a fee transfer
       * which has an increase in the receiver and decrease in the source
       * (2 ops)
       * *)
      [ {Op.label= `Fee_payer_dec; related_to= None}
      ; {Op.label= `Fee_receiver_inc; related_to= Some `Fee_payer_dec} ]
      @
      (* TODO: How do we identify account creation fee failures from failure_status? *)
      match t.kind with
      | `Payment -> (
          if Amount_of.Token_id.is_default t.token then
            [{Op.label= `Account_creation_fee_via_payment; related_to= None}]
          else
            []
            @
            (* When amount is not none, we move the amount from source to receiver *)
            match t.amount with
            | Some amount ->
                [ {Op.label= `Payment_source_dec amount; related_to= None}
                ; { Op.label= `Payment_receiver_inc amount
                  ; related_to= Some (`Payment_source_dec amount) } ]
            | None ->
                [] )
      | `Delegation ->
          [{Op.label= `Delegate_change; related_to= None}]
      | `Create_token ->
          [ {Op.label= `Account_creation_fee_via_fee_payer; related_to= None}
          ; {Op.label= `Create_token; related_to= None} ]
      | `Create_account ->
          if Amount_of.Token_id.is_default t.fee_token then
            [{Op.label= `Account_creation_fee_via_fee_payer; related_to= None}]
          else []
      | `Mint_tokens -> (
        (* When amount is not none, we move the amount from source to receiver *)
        match t.amount with
        | Some amount ->
            [{Op.label= `Mint_tokens amount; related_to= None}]
        | None ->
            [] )
    in
    Op.build
      ~a_eq:
        [%eq:
          [ `Fee_payer_dec
          | `Fee_receiver_inc
          | `Payment_source_dec of Unsigned.UInt64.t
          | `Payment_receiver_inc of Unsigned.UInt64.t ]] ~plan
      ~f:(fun ~related_operations ~operation_identifier op ->
        let status, metadata =
          match (op.label, t.failure_status) with
          (* Fee transfers always succeed even if the command fails, if it's in a block.
           * TODO: Reviewer, please check me. *)
          | `Fee_receiver_inc, _ | `Fee_payer_dec, _ ->
              (Operation_statuses.name `Success, None)
          | _, `Applied ->
              (Operation_statuses.name `Success, None)
          | _, `Failed reason ->
              ( Operation_statuses.name `Failed
              , Some (`Assoc [("reason", `String reason)]) )
        in
        let merge_metadata m1 m2 =
          match (m1, m2) with
          | None, None ->
              None
          | Some x, None | None, Some x ->
              Some x
          | Some (`Assoc xs), Some (`Assoc ys) ->
              Some (`Assoc (xs @ ys))
          | _ ->
              failwith "Unexpected pattern"
        in
        match op.label with
        | `Fee_payer_dec ->
            { Operation.operation_identifier
            ; related_operations
            ; status
            ; account= Some (account_id t.fee_payer t.fee_token)
            ; _type= Operation_types.name `Fee_payer_dec
            ; amount= Some Amount_of.(negated @@ token t.fee_token t.fee)
            ; metadata }
        | `Fee_receiver_inc ->
            { Operation.operation_identifier
            ; related_operations
            ; status
            ; account= Some (account_id block_creator_pk t.fee_token)
            ; _type= Operation_types.name `Fee_receiver_inc
            ; amount= Some (Amount_of.token t.fee_token t.fee)
            ; metadata }
        | `Payment_source_dec amount ->
            { Operation.operation_identifier
            ; related_operations
            ; status
            ; account= Some (account_id t.source t.token)
            ; _type= Operation_types.name `Payment_source_dec
            ; amount= Some Amount_of.(negated @@ token t.token amount)
            ; metadata }
        | `Payment_receiver_inc amount ->
            { Operation.operation_identifier
            ; related_operations
            ; status
            ; account= Some (account_id t.source t.token)
            ; _type= Operation_types.name `Payment_receiver_inc
            ; amount= Some (Amount_of.token t.token amount)
            ; metadata }
        | `Account_creation_fee_via_payment ->
            { Operation.operation_identifier
            ; related_operations
            ; status
            ; account= Some (account_id t.receiver t.token)
            ; _type= Operation_types.name `Account_creation_fee_via_payment
            ; amount= Some Amount_of.(negated @@ coda account_creation_fee)
            ; metadata }
        | `Account_creation_fee_via_fee_payer ->
            { Operation.operation_identifier
            ; related_operations
            ; status
            ; account= Some (account_id t.fee_payer t.fee_token)
            ; _type= Operation_types.name `Account_creation_fee_via_fee_payer
            ; amount= Some Amount_of.(negated @@ coda account_creation_fee)
            ; metadata }
        | `Create_token ->
            { Operation.operation_identifier
            ; related_operations
            ; status
            ; account= None
            ; _type= Operation_types.name `Create_token
            ; amount= None
            ; metadata }
        | `Delegate_change ->
            { Operation.operation_identifier
            ; related_operations
            ; status
            ; account= Some (account_id t.source Amount_of.Token_id.default)
            ; _type= Operation_types.name `Delegate_change
            ; amount= None
            ; metadata=
                merge_metadata metadata
                  (Some
                     (`Assoc
                       [ ( "delegate_change_target"
                         , `String
                             (let (`Pk r) = t.receiver in
                              r) ) ])) }
        | `Mint_tokens amount ->
            { Operation.operation_identifier
            ; related_operations
            ; status
            ; account= Some (account_id t.receiver t.token)
            ; _type= Operation_types.name `Mint_tokens
            ; amount= Some (Amount_of.token t.token amount)
            ; metadata=
                merge_metadata metadata
                  (Some
                     (`Assoc
                       [ ( "token_owner_pk"
                         , `String
                             (let (`Pk r) = t.source in
                              r) ) ])) } )

  let dummies =
    [ { kind= `Payment (* default token *)
      ; fee_payer= `Pk "Alice"
      ; source= `Pk "Alice"
      ; token= Unsigned.UInt64.of_int 1
      ; fee= Unsigned.UInt64.of_int 2_000_000_000
      ; receiver= `Pk "Bob"
      ; fee_token= Unsigned.UInt64.of_int 1
      ; nonce= Unsigned.UInt32.of_int 3
      ; amount= Some (Unsigned.UInt64.of_int 2_000_000_000)
      ; failure_status= `Applied
      ; hash= "TXN_1_HASH" }
    ; { kind= `Payment (* failed payment *)
      ; fee_payer= `Pk "Alice"
      ; source= `Pk "Alice"
      ; token= Unsigned.UInt64.of_int 1
      ; fee= Unsigned.UInt64.of_int 2_000_000_000
      ; receiver= `Pk "Bob"
      ; fee_token= Unsigned.UInt64.of_int 1
      ; nonce= Unsigned.UInt32.of_int 3
      ; amount= Some (Unsigned.UInt64.of_int 2_000_000_000)
      ; failure_status= `Failed "Failure"
      ; hash= "TXN_1fail_HASH" }
    ; { kind= `Payment (* custom token *)
      ; fee_payer= `Pk "Alice"
      ; source= `Pk "Alice"
      ; token= Unsigned.UInt64.of_int 3
      ; fee= Unsigned.UInt64.of_int 2_000_000_000
      ; receiver= `Pk "Bob"
      ; fee_token= Unsigned.UInt64.of_int 1
      ; nonce= Unsigned.UInt32.of_int 3
      ; amount= Some (Unsigned.UInt64.of_int 2_000_000_000)
      ; failure_status= `Applied
      ; hash= "TXN_1a_HASH" }
    ; { kind= `Payment (* custom fee-token *)
      ; fee_payer= `Pk "Alice"
      ; source= `Pk "Alice"
      ; token= Unsigned.UInt64.of_int 1
      ; fee= Unsigned.UInt64.of_int 2_000_000_000
      ; receiver= `Pk "Bob"
      ; fee_token= Unsigned.UInt64.of_int 3
      ; nonce= Unsigned.UInt32.of_int 3
      ; amount= Some (Unsigned.UInt64.of_int 2_000_000_000)
      ; failure_status= `Applied
      ; hash= "TXN_1b_HASH" }
    ; { kind= `Delegation
      ; fee_payer= `Pk "Alice"
      ; source= `Pk "Alice"
      ; token= Unsigned.UInt64.of_int 1
      ; fee= Unsigned.UInt64.of_int 2_000_000_000
      ; receiver= `Pk "Bob"
      ; fee_token= Unsigned.UInt64.of_int 1
      ; nonce= Unsigned.UInt32.of_int 3
      ; amount= None
      ; failure_status= `Applied
      ; hash= "TXN_2_HASH" }
    ; { kind= `Create_token
      ; fee_payer= `Pk "Alice"
      ; source= `Pk "Alice"
      ; token= Unsigned.UInt64.of_int 1
      ; fee= Unsigned.UInt64.of_int 2_000_000_000
      ; receiver= `Pk "Bob"
      ; fee_token= Unsigned.UInt64.of_int 1
      ; nonce= Unsigned.UInt32.of_int 3
      ; amount= None
      ; failure_status= `Applied
      ; hash= "TXN_3_HASH" }
    ; { kind= `Create_account
      ; fee_payer= `Pk "Alice"
      ; source= `Pk "Alice"
      ; token= Unsigned.UInt64.of_int 1
      ; fee= Unsigned.UInt64.of_int 2_000_000_000
      ; receiver= `Pk "Bob"
      ; fee_token= Unsigned.UInt64.of_int 1
      ; nonce= Unsigned.UInt32.of_int 3
      ; amount= None
      ; failure_status= `Applied
      ; hash= "TXN_4_HASH" }
    ; { kind= `Mint_tokens
      ; fee_payer= `Pk "Alice"
      ; source= `Pk "Alice"
      ; token= Unsigned.UInt64.of_int 10
      ; fee= Unsigned.UInt64.of_int 2_000_000_000
      ; receiver= `Pk "Bob"
      ; fee_token= Unsigned.UInt64.of_int 1
      ; nonce= Unsigned.UInt32.of_int 3
      ; amount= Some (Unsigned.UInt64.of_int 30_000)
      ; failure_status= `Applied
      ; hash= "TXN_5_HASH" } ]
end

module Internal_command_info = struct
  module Kind = struct
    type t = [`Coinbase | `Fee_transfer] [@@deriving eq]
  end

  type t =
    { kind: Kind.t
    ; receiver: [`Pk of string]
    ; fee: Unsigned.UInt64.t
    ; token: Unsigned.UInt64.t
    ; hash: string }

  let to_operations ~user_commands ~coinbase ~block_creator_pk (t : t) :
      Operation.t list =
    (* We choose to represent fee transfers from txns from the canonical user
     * command that created them so we are able consistently produce the balance
     * changing operations in the mempool or a block.
     *
     * This means we only produce an operation from an internal command if
     * it's a coinbase, or a snark worker fee transfer.
     * *)
    let plan : 'a Op.t list =
      match t.kind with
      | `Coinbase ->
          [{Op.label= `Coinbase_inc; related_to= None}]
      | `Fee_transfer ->
          (* Detect if a fee transfer comes from a snark worker payment by
         * failing to find the user command that caused it *)
          if
            List.find user_commands ~f:(fun (info : User_command_info.t) ->
                Unsigned.UInt64.equal info.fee t.fee
                && Unsigned.UInt64.equal info.token t.token
                && [%eq: [`Pk of string]] info.receiver t.receiver )
            |> Option.is_none
          then
            [ {Op.label= `Fee_payer_dec; related_to= None}
            ; {Op.label= `Fee_receiver_inc; related_to= Some `Fee_payer_dec} ]
          else []
    in
    Op.build ~a_eq:[%eq: [`Coinbase_inc | `Fee_payer_dec | `Fee_receiver_inc]]
      ~plan ~f:(fun ~related_operations ~operation_identifier op ->
        (* All internal commands succeed if they're in blocks *)
        let status = Operation_statuses.name `Success in
        match op.label with
        | `Coinbase_inc ->
            { Operation.operation_identifier
            ; related_operations
            ; status
            ; account=
                Some (account_id block_creator_pk Amount_of.Token_id.default)
            ; _type= Operation_types.name `Coinbase_inc
            ; amount= Some (Amount_of.coda coinbase)
            ; metadata= None }
        | `Fee_payer_dec ->
            { Operation.operation_identifier
            ; related_operations
            ; status
            ; account= Some (account_id block_creator_pk t.token)
            ; _type= Operation_types.name `Fee_payer_dec
            ; amount= Some Amount_of.(negated @@ token t.token t.fee)
            ; metadata= None }
        | `Fee_receiver_inc ->
            { Operation.operation_identifier
            ; related_operations
            ; status
            ; account= Some (account_id t.receiver t.token)
            ; _type= Operation_types.name `Fee_receiver_inc
            ; amount= Some (Amount_of.token t.token t.fee)
            ; metadata= None } )

  let dummies =
    [ { kind= `Coinbase
      ; receiver= `Pk "Eve"
      ; fee= Unsigned.UInt64.of_int 20_000_000_000
      ; token= Unsigned.UInt64.of_int 1
      ; hash= "COINBASE_1" } ]
end

module Block_info = struct
  type t =
    { block_identifier: Block_identifier.t
    ; creator: [`Pk of string]
    ; parent_block_identifier: Block_identifier.t
    ; timestamp: int64
    ; internal_info: Internal_command_info.t list
    ; user_commands: User_command_info.t list }

  let dummy =
    { block_identifier=
        Block_identifier.create (Int64.of_int_exn 4) "STATE_HASH_BLOCK"
    ; creator= `Pk "Eve"
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
      let%bind () =
        env.validate_network_choice ~network_identifier:req.network_identifier
          ~gql_response:res
      in
      (* TODO: Pull account creation fee and coinbase from graphql #5435 *)
      let account_creation_fee = Unsigned.UInt64.of_int 1_000 in
      let coinbase = Unsigned.UInt64.of_int 20_000_000_000 in
      let%map block_info = env.db_block () in
      { Block_response.block=
          { Block.block_identifier= block_info.block_identifier
          ; parent_block_identifier= block_info.parent_block_identifier
          ; timestamp= block_info.timestamp
          ; transactions=
              List.map block_info.internal_info ~f:(fun info ->
                  { Transaction.transaction_identifier=
                      {Transaction_identifier.hash= info.hash}
                  ; operations=
                      Internal_command_info.to_operations
                        ~user_commands:block_info.user_commands ~coinbase
                        ~block_creator_pk:block_info.creator info
                  ; metadata= None } )
              @ List.map block_info.user_commands ~f:(fun info ->
                    { Transaction.transaction_identifier=
                        {Transaction_identifier.hash= info.hash}
                    ; operations=
                        User_command_info.to_operations ~account_creation_fee
                          ~block_creator_pk:block_info.creator info
                    ; metadata= None } )
          ; metadata= None }
      ; other_transactions= [] }
  end

  module Real = Impl (Deferred.Result)

  let%test_module "blocks" =
    ( module struct
      module Mock = Impl (Result)

      (* This test intentionally fails as there has not been time to implement
       * it properly yet *)
      (*
      let%test_unit "all dummies" =
        Test.assert_ ~f:Block_response.to_yojson
          ~expected:
            (Mock.handle ~env:Env.mock
               (Block_request.create
                  (Network_identifier.create "x" "y")
                  (Partial_block_identifier.create ())))
          ~actual:(Result.fail (Errors.create (`Json_parse None)))
    *)
    end )
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
  (* Note: We do not need to implement /block/transaction endpoint because we
   * don't return any "other_transactions" *)
  | _ ->
      Deferred.Result.fail `Page_not_found
