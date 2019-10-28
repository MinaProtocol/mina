open Core
open Async
open Coda_base

module Hasura = struct
  type t = {port: int; logger: Logger.t}

  let create (logger, port) = {port; logger}

  let get {port; _} ~key:receipt_chain =
    let graphql =
      Graphql_query.Receipt_chain.Get.make
        ~receipt_chain:(Receipt.Chain_hash.to_string receipt_chain)
        ()
    in
    let%bind response =
      Graphql_client.query_exn graphql port
      >>| fun obj -> obj#receipt_chain_hashes
    in
    let open Deferred.Option.Let_syntax in
    let%bind result =
      Deferred.return
      @@
      match Array.to_list response with
      | [] ->
          None
      | [result] ->
          Some result
      | _ ->
          failwith "Expected to get a result with size of one or less"
    in
    let%map parent_hash =
      let parent_hash_opt =
        Option.map result#receipt_chain_hash ~f:(fun obj -> obj#parent_hash)
      in
      Deferred.return parent_hash_opt
    in
    let payload =
      (* TODO: Receipt chains could actually reference multiple user_commands that have the same payload. 
        Creating receipt chain proofs require a sender's public key  *)
      (result#blocks_user_commands.(0))#user_command_payload
    in
    let user_command_payload = Types.User_command.decode_payload payload in
    Receipt_chain_database.Tree_node.
      {key= receipt_chain; parent= parent_hash; value= user_command_payload}

  let to_alist _ = failwith "Implementation not needed"

  let set_batch _ = failwith "Implementation not needed"

  let remove _ = failwith "Implementation not needed"

  let set _ = failwith "Implementation not needed"

  let close _ =
    failwith
      "Can't close Hasura Requests. This needs to be closed through the \
       archive node"
end

include Receipt_chain_database.Make
          (Deferred)
          (struct
            type t = Logger.t * int
          end)
          (Hasura)
