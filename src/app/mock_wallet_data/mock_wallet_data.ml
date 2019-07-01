open Core
open Async

let render_keys public_keys =
  String.concat ~sep:"\n"
  @@ List.map public_keys
       ~f:Signature_lib.Public_key.Compressed.to_base58_check

let command =
  let open Command.Let_syntax in
  let%map_open config_directory = anon ("config-directory" %: string)
  and num_transactions =
    flag "num-transactions"
      ~doc:
        "NUMTRANSACTION is the number of transactions recorded in the \
         application"
      (optional int)
  and num_wallets =
    flag "num-wallets"
      ~doc:"NUMWALLETS is the number of wallets in the application"
      (optional int)
  and num_foreign_users =
    flag "num-foreign-users"
      ~doc:
        "NUMFOREIGNUSERS is the number of other users that are not wallets in \
         the application"
      (optional int)
  in
  fun () ->
    let directory = config_directory in
    let open Deferred.Let_syntax in
    let%bind () = Unix.mkdir ~p:() directory in
    let%map _, wallets, foreign_keys =
      Auxiliary_database.Transaction_database.For_tests.populate_database
        ~directory
        ~num_wallets:(Option.value ~default:3 num_wallets)
        ~num_foreign:(Option.value ~default:5 num_foreign_users)
        (Option.value ~default:1000 num_transactions)
    in
    Core.printf !"Generated Database at %s\n" directory ;
    Core.printf "Here are the wallets' public keys:\n%s\n\n"
    @@ render_keys wallets ;
    Core.printf "Here are other public keys:\n%s\n" @@ render_keys foreign_keys

let () =
  Command.run
  @@ Command.async ~summary:"Mock data for wallet application" command
