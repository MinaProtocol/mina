open Core
open Mina_base
open Mina_signature_kind_type

let () =
  let txn = 
    let txn = (Lazy.force (Zkapp_command.dummy ~signature_kind:Testnet)) in 
    { txn with 
      account_updates = 
        Zkapp_command.Call_forest.forget_hashes @@ 
        Zkapp_command.Call_forest.map txn.account_updates ~f:(fun x -> 
          { (Account_update.forget_aux x) with 
            Account_update.Poly.authorization = 
              Mina_base.Control.Poly.Proof (Lazy.force Proof.blockchain_dummy) 
          }
        ) 
    } 
  in
  (* Script to generate a zkApp transaction for testing transaction hash generation.
   * This script creates a dummy zkApp transaction and outputs both the transaction ID
   * and the expected hash in base58check format.
   * 
   * To use this script:
   * 1. Build it: dune build scripts/generate_zkapp_txn.exe
   * 2. Run it: ./_build/default/scripts/generate_zkapp_txn.exe
   * 
   * The output will show:
   * - Transaction ID: Base64-encoded serialized transaction
   * - Expected hash: Base58check-encoded transaction hash
   *)
  
  (* Print the transaction ID *)
  let transaction_id = 
    Binable.to_string (module Mina_base.User_command.Stable.Latest) (Zkapp_command txn) 
    |> Base64.encode 
    |> (function Ok x -> x | Error _ -> "")
  in
  Printf.printf "Transaction ID:\n%s\n\n" transaction_id;
  
  (* Get the hash *)
  let hash = Mina_transaction.Transaction_hash.(hash_command (Zkapp_command txn) |> to_base58_check) in
  Printf.printf "Expected hash:\n%s\n" hash