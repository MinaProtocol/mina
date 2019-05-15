open Core
open Async

let command =
  let open Command.Let_syntax in
  let%map_open config_directory = anon ("config-directory" %: string)
  and num_transactions =
    flag "num-transactions"
      ~doc:
        "NUMTRANSACTION is the number of transactions that should be in the \
         database"
      (optional int)
  and num_users =
    flag "num-users"
      ~doc:
        "NUMUSERS is the number of users that are involved in the \
         transactions sent in the database"
      (optional int)
  in
  fun () ->
    let directory = config_directory ^/ "transaction" in
    let open Deferred.Let_syntax in
    let%map () = Unix.mkdir ~p:() directory in
    let _, public_keys =
      Transaction_database.For_tests.populate_database ~directory
        (Option.value ~default:5 num_users)
        (Option.value ~default:1000 num_transactions)
    in
    Core.printf
      !"Generated Database at %s\nHere are the participants' public key:\n%s"
      directory
      ( String.concat ~sep:"\n"
      @@ List.map public_keys ~f:Signature_lib.Public_key.Compressed.to_base64
      )

let () =
  Command.run
  @@ Command.async ~summary:"Mock data for front-end wallet" command
