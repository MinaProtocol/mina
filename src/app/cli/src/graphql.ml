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
    module Scalars = struct
      let public_key : (t, Public_key.Compressed.t option) typ =
        scalar
          ~doc:
            "64-bit respresentation of public key that is compressed to make \
             snark computation efficent"
          "public_key"
          ~coerce:
            (Fn.compose Yojson.Safe.to_basic Public_key.Compressed.to_yojson)

      let date : (t, Time.t option) typ =
        scalar
          ~doc:
            "String representation of the Unix form of time, which is the \
             number of milliseconds that elapsed from January 1, 1970"
          "time" ~coerce:(fun time ->
            let string_time =
              Time.to_span_since_epoch time
              |> Time.Span.to_ms |> Int64.to_string
            in
            `String string_time )

      let uint64 : (t, Unsigned.UInt64.t option) typ =
        scalar
          ~doc:
            "String representation of Unsigned Int64 (Javascript only has \
             64-bit strings)"
          "uint64" ~coerce:(fun uint64 ->
            `String (Unsigned.UInt64.to_string uint64) )
    end

    (* TODO: include submitted_at (date) and included_at (date). These two fields are not exposed in the user_command *)
    let payment : (t, User_command.t option) typ =
      let open Scalars in
      obj "payment" ~fields:(fun _ ->
          [ field "nonce" ~typ:(non_null int)
              ~args:Arg.[]
              ~resolve:(fun _ payment ->
                User_command_payload.nonce @@ User_command.payload payment
                |> Account.Nonce.to_int )
          ; field "sender" ~typ:(non_null public_key)
              ~args:Arg.[]
              ~resolve:(fun _ payment -> User_command.sender payment)
          ; field "receiver" ~typ:(non_null public_key)
              ~args:Arg.[]
              ~resolve:(fun _ payment ->
                match
                  User_command_payload.body (User_command.payload payment)
                with
                | Payment {Payment_payload.Poly.receiver; _} ->
                    receiver
                | Stake_delegation _ ->
                    failwith "Payment should not consist of a stake delegation"
                )
          ; field "amount" ~typ:(non_null uint64)
              ~args:Arg.[]
              ~resolve:(fun _ payment ->
                match
                  User_command_payload.body (User_command.payload payment)
                with
                | Payment {Payment_payload.Poly.amount; _} ->
                    amount |> Currency.Amount.to_uint64
                | Stake_delegation _ ->
                    failwith "Payment should not consist of a stake delegation"
                )
          ; field "fee" ~typ:(non_null uint64)
              ~args:Arg.[]
              ~resolve:(fun _ payment ->
                User_command.fee payment |> Currency.Fee.to_uint64 )
          ; field "memo" ~typ:(non_null string)
              ~args:Arg.[]
              ~resolve:(fun _ payment ->
                User_command_payload.memo @@ User_command.payload payment
                |> User_command_memo.to_string ) ] )

    let sync_status : ('context, [`Offline | `Synced | `Bootstrap]) typ =
      non_null
        (enum "sync_status" ~doc:"Sync status as daemon node"
           ~values:
             [ enum_value "BOOTSTRAP" ~value:`Bootstrap
             ; enum_value "SYNCED" ~value:`Synced
             ; enum_value "OFFLINE" ~value:`Offline ])
  end

  module Queries = struct
    open Types

    let sync_state =
      io_field "sync_status" ~typ:sync_status
        ~args:Arg.[]
        ~resolve:(fun {ctx= coda; _} () ->
          Deferred.return
            (Inputs.Incr_status.Observer.value @@ Program.sync_status coda)
          >>| Result.map_error ~f:Error.to_string_hum )

    let commands = [sync_state]
  end

  module Subscriptions = struct
    let to_pipe observer =
      let reader, writer =
        Strict_pipe.(create (Buffered (`Capacity 1, `Overflow Drop_head)))
      in
      Incr_status.Observer.on_update_exn observer ~f:(function
        | Initialized value ->
            Strict_pipe.Writer.write writer value
        | Changed (_, value) ->
            Strict_pipe.Writer.write writer value
        | Invalidated ->
            () ) ;
      (Strict_pipe.Reader.to_linear_pipe reader).Linear_pipe.Reader.pipe

    let new_sync_update =
      subscription_field "new_sync_update"
        ~doc:"Subscripts on sync update from Coda" ~deprecated:NotDeprecated
        ~typ:Types.sync_status
        ~args:Arg.[]
        ~resolve:(fun {ctx= coda; _} ->
          Program.sync_status coda |> to_pipe |> Deferred.Result.return )

    let commands = [new_sync_update]
  end

  let schema =
    Graphql_async.Schema.(
      schema Queries.commands ~subscriptions:Subscriptions.commands)
end
