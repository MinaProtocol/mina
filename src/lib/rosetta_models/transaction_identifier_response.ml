(*
 * This file has been generated by the OCamlClientCodegen generator for openapi-generator.
 *
 * Generated by: https://openapi-generator.tech
 *
 * Schema Transaction_identifier_response.t : TransactionIdentifierResponse contains the transaction_identifier of a transaction that was submitted to either `/construction/hash` or `/construction/submit`. 
 *)

type t =
  { transaction_identifier : Transaction_identifier.t
  ; metadata : Yojson.Safe.t option [@default None]
  }
[@@deriving yojson { strict = false }, show, eq]

(** TransactionIdentifierResponse contains the transaction_identifier of a transaction that was submitted to either `/construction/hash` or `/construction/submit`.  *)
let create (transaction_identifier : Transaction_identifier.t) : t =
  { transaction_identifier; metadata = None }
