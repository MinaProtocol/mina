open Async
open Caqti_async
open Pipe_lib
open Coda_base
open Coda_transition
open Signature_lib

module User_command = struct
  (*
    let t =
        let encode t =
          ( if User_command_payload.is_payment t
            then "payment"
            else "delegation"
          , ( User_command.sender t |> Public_key.Compressed.to_base58_check
            , ( User_command.)))
*)

end

let add_block (module Conn : CONNECTION)
    ({data= block; hash} : (External_transition.t, State_hash.t) With_hash.t) =
  let open Deferred.Result.Let_syntax in
  let transactions = External_transition.transactions block in
  let%bind () = Conn.start () in
  let%bind ids =
    Deferred.Result.all
      (Core.List.map transactions ~f:(function
        | User_command user_command_checked ->
            let user_command =
              User_command.forget_check user_command_checked
            in
            let hash =
              Transaction_hash.hash_user_command user_command
              |> Transaction_hash.to_base58_check
            in
            let%bind transaction_id =
              Conn.find
                (Caqti_request.find Caqti_type.string Caqti_type.int
                   "INSERT INTO transactions (hash) VALUES (?) RETURNING id")
                hash
            in
            (*
            let%bind _user_command_id =
                Conn.find
                  (Caqti_request.find Caqti_type.)
            *)
            failwith "..."
        | Fee_transfer fee_transfer ->
            failwith "..."
        | Coinbase coinbase ->
            failwith "..." ))
  in
  Conn.commit ()

let run t reader =
  Strict_pipe.Reader.iter reader ~f:(function
    | Diff.Transition_frontier (Breadcrumb_added {block; _}) ->
        failwith "..."
    | Transition_frontier _ ->
        failwith "..."
    | Transaction_pool {added; _} ->
        failwith "..." )
