(*
 * This file has been generated by the OCamlClientCodegen generator for openapi-generator.
 *
 * Generated by: https://openapi-generator.tech
 *
 * Schema Block_transaction_response.t : A BlockTransactionResponse contains information about a block transaction. 
 *)

type t = { transaction : Transaction.t }
[@@deriving yojson { strict = false }, show, eq]

(** A BlockTransactionResponse contains information about a block transaction.  *)
let create (transaction : Transaction.t) : t = { transaction }
