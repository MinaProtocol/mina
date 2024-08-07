(*
 * This file has been generated by the OCamlClientCodegen generator for openapi-generator.
 *
 * Generated by: https://openapi-generator.tech
 *
 * Schema Construction_submit_request.t : The transaction submission request includes a signed transaction. 
 *)

type t =
  { network_identifier : Network_identifier.t; signed_transaction : string }
[@@deriving yojson { strict = false }, show, eq]

(** The transaction submission request includes a signed transaction.  *)
let create (network_identifier : Network_identifier.t)
    (signed_transaction : string) : t =
  { network_identifier; signed_transaction }
