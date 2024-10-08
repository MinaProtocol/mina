(*
 * This file has been generated by the OCamlClientCodegen generator for openapi-generator.
 *
 * Generated by: https://openapi-generator.tech
 *
 * Schema Mempool_transaction_request.t : A MempoolTransactionRequest is utilized to retrieve a transaction from the mempool. 
 *)

type t =
  { network_identifier : Network_identifier.t
  ; transaction_identifier : Transaction_identifier.t
  }
[@@deriving yojson { strict = false }, show, eq]

(** A MempoolTransactionRequest is utilized to retrieve a transaction from the mempool.  *)
let create (network_identifier : Network_identifier.t)
    (transaction_identifier : Transaction_identifier.t) : t =
  { network_identifier; transaction_identifier }
