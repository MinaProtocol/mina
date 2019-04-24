open Core
open Async
open Graphql_async
open Schema
open Pipe_lib
open Coda_base
open Signature_lib

module Make (Program : Coda_inputs.Main_intf) = struct
  open Program
  open Inputs

  module Types = struct
    module Stringable = struct
      (** 64-bit respresentation of public key that is compressed to make snark computation efficent *)
      let public_key = Public_key.Compressed.to_base64

      (** Unix form of time, which is the number of milliseconds that elapsed from January 1, 1970 *)
      let date time =
        Time.to_span_since_epoch time |> Time.Span.to_ms |> Int64.to_string

      (** Javascript only has 53-bit integers so we need to make them into strings  *)
      let uint64 uint64 = Unsigned.UInt64.to_string uint64
    end

    let uint64_field name ~doc =
      field name ~typ:(non_null string)
        ~doc:(sprintf !"%s (%s is uint64 and is coerced as a string" doc name)

    (* TODO: include submitted_at (date) and included_at (date). These two fields are not exposed in the user_command *)
    let payment : (t, User_command.t option) typ =
      obj "payment" ~fields:(fun _ ->
          [ field "nonce" ~typ:(non_null int) ~doc:"Nonce of the transaction"
              ~args:Arg.[]
              ~resolve:(fun _ payment ->
                User_command_payload.nonce @@ User_command.payload payment
                |> Account.Nonce.to_int )
          ; field "sender" ~typ:(non_null string)
              ~doc:"Public key of the sender"
              ~args:Arg.[]
              ~resolve:(fun _ payment ->
                User_command.sender payment |> Stringable.public_key )
          ; field "receiver" ~typ:(non_null string)
              ~doc:"Public key of the receiver"
              ~args:Arg.[]
              ~resolve:(fun _ payment ->
                match
                  User_command_payload.body (User_command.payload payment)
                with
                | Payment {Payment_payload.Poly.receiver; _} ->
                    receiver |> Stringable.public_key
                | Stake_delegation _ ->
                    failwith "Payment should not consist of a stake delegation"
                )
          ; uint64_field "amount" ~doc:"Amount that sender send to receiver"
              ~args:Arg.[]
              ~resolve:(fun _ payment ->
                match
                  User_command_payload.body (User_command.payload payment)
                with
                | Payment {Payment_payload.Poly.amount; _} ->
                    amount |> Currency.Amount.to_uint64 |> Stringable.uint64
                | Stake_delegation _ ->
                    failwith "Payment should not consist of a stake delegation"
                )
          ; uint64_field "fee"
              ~doc:
                "Fee that sender is willing to pay for making the transaction"
              ~args:Arg.[]
              ~resolve:(fun _ payment ->
                User_command.fee payment |> Currency.Fee.to_uint64
                |> Stringable.uint64 )
          ; field "memo" ~typ:(non_null string) ~doc:"Note of the transaction"
              ~args:Arg.[]
              ~resolve:(fun _ payment ->
                User_command_payload.memo @@ User_command.payload payment
                |> User_command_memo.to_string ) ] )

    let snark_fee : (t, Transaction_snark_work.t option) typ =
      obj "snarkFee" ~fields:(fun _ ->
          [ field "snarkCreator" ~typ:(non_null string)
              ~doc:"public key of the snarker"
              ~args:Arg.[]
              ~resolve:(fun _ {Transaction_snark_work.prover; _} ->
                Stringable.public_key prover )
          ; field "fee" ~typ:(non_null string)
              ~doc:"the cost of creating the proof"
              ~args:Arg.[]
              ~resolve:(fun _ {Transaction_snark_work.fee; _} ->
                Currency.Fee.to_uint64 fee |> Unsigned.UInt64.to_string ) ] )

    let block_proposer external_transition =
      let staged_ledger_diff =
        External_transition.staged_ledger_diff external_transition
      in
      staged_ledger_diff.creator

    let block : ('context, External_transition.t option) typ =
      obj "block" ~fields:(fun _ ->
          [ uint64_field "coinbase" ~doc:"Total coinbase awarded to proposer"
              ~args:Arg.[]
              ~resolve:(fun _ external_transition ->
                let staged_ledger_diff =
                  External_transition.staged_ledger_diff external_transition
                in
                staged_ledger_diff |> Staged_ledger_diff.coinbase
                |> Currency.Fee.to_uint64 |> Stringable.uint64 )
          ; field "creator" ~typ:(non_null string)
              ~doc:"Public key of the proposer creating the block"
              ~args:Arg.[]
              ~resolve:(fun _ external_transition ->
                Stringable.public_key @@ block_proposer external_transition )
          ; field "payments" ~doc:"List of payments in the block"
              ~typ:(non_null (list @@ non_null payment))
              ~args:Arg.[]
              ~resolve:(fun _ external_transition ->
                let staged_ledger_diff =
                  External_transition.staged_ledger_diff external_transition
                in
                let user_commands =
                  Staged_ledger_diff.user_commands staged_ledger_diff
                in
                List.filter user_commands
                  ~f:
                    (Fn.compose User_command_payload.is_payment
                       User_command.payload) )
          ; field "snarkFees"
              ~doc:"Fees that a proposer for constructing proofs"
              ~typ:(non_null (list @@ non_null snark_fee))
              ~args:Arg.[]
              ~resolve:(fun _ external_transition ->
                let staged_ledger_diff =
                  External_transition.staged_ledger_diff external_transition
                in
                Staged_ledger_diff.completed_works staged_ledger_diff ) ] )

    let sync_status : ('context, [`Offline | `Synced | `Bootstrap]) typ =
      non_null
        (enum "syncStatus" ~doc:"Sync status as daemon node"
           ~values:
             [ enum_value "BOOTSTRAP" ~value:`Bootstrap
             ; enum_value "SYNCED" ~value:`Synced
             ; enum_value "OFFLINE" ~value:`Offline ])
  end

  module Queries = struct
    open Types

    let sync_state =
      io_field "syncStatus" ~typ:sync_status
        ~args:Arg.[]
        ~resolve:(fun {ctx= coda; _} () ->
          Deferred.return
            (Coda_incremental.Status.Observer.value @@ Program.sync_status coda)
          >>| Result.map_error ~f:Error.to_string_hum )

    let commands = [sync_state]
  end

  module Subscriptions = struct
    let new_sync_update =
      subscription_field "newSyncUpdate"
        ~doc:"Subscribes on sync update from Coda" ~deprecated:NotDeprecated
        ~typ:Types.sync_status
        ~args:Arg.[]
        ~resolve:(fun {ctx= coda; _} ->
          Program.sync_status coda |> Coda_incremental.Status.to_pipe
          |> Deferred.Result.return )

    let new_block =
      subscription_field "newBlock"
        ~doc:
          "Subscribes on a new block created by a proposer with a public key \
           KEY"
        ~typ:(non_null Types.block)
        ~args:Arg.[arg "publicKey" ~typ:(non_null string)]
        ~resolve:(fun {ctx= coda; _} public_key ->
          let public_key = Public_key.Compressed.of_base64_exn public_key in
          (* Pipes that will alert a subscriber of any new blocks throughout the entire time the daemon is on *)
          let global_new_block_reader, global_new_block_writer =
            Pipe.create ()
          in
          let init, _ = Pipe.create () in
          Broadcast_pipe.Reader.fold (Program.transition_frontier coda) ~init
            ~f:(fun acc_pipe -> function
            | None ->
                Deferred.return acc_pipe
            | Some transition_frontier ->
                Pipe.close_read acc_pipe ;
                let new_block_observer =
                  Transition_frontier.new_transition transition_frontier
                in
                let frontier_new_block_reader =
                  Coda_incremental.New_transition.to_pipe new_block_observer
                in
                let filtered_new_block_reader =
                  Pipe.filter_map frontier_new_block_reader
                    ~f:(fun new_block ->
                      let unverified_new_block =
                        External_transition.of_verified new_block
                      in
                      Option.some_if
                        (Public_key.Compressed.equal
                           (Types.block_proposer unverified_new_block)
                           public_key)
                        unverified_new_block )
                in
                Pipe.transfer filtered_new_block_reader global_new_block_writer
                  ~f:Fn.id
                |> don't_wait_for ;
                Deferred.return filtered_new_block_reader )
          |> Deferred.ignore |> don't_wait_for ;
          Deferred.Result.return global_new_block_reader )

    let commands = [new_sync_update]
  end

  let schema =
    Graphql_async.Schema.(
      schema Queries.commands ~subscriptions:Subscriptions.commands)
end
