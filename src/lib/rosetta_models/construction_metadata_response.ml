(*
 * This file has been generated by the OCamlClientCodegen generator for openapi-generator.
 *
 * Generated by: https://openapi-generator.tech
 *
 * Schema Construction_metadata_response.t : The ConstructionMetadataResponse returns network-specific metadata used for transaction construction.  Optionally, the implementer can return the suggested fee associated with the transaction being constructed. The caller may use this info to adjust the intent of the transaction or to create a transaction with a different account that can pay the suggested fee. Suggested fee is an array in case fee payment must occur in multiple currencies. 
 *)

type t = { metadata : Yojson.Safe.t; suggested_fee : Amount.t list }
[@@deriving yojson { strict = false }, show, eq]

(** The ConstructionMetadataResponse returns network-specific metadata used for transaction construction.  Optionally, the implementer can return the suggested fee associated with the transaction being constructed. The caller may use this info to adjust the intent of the transaction or to create a transaction with a different account that can pay the suggested fee. Suggested fee is an array in case fee payment must occur in multiple currencies.  *)
let create (metadata : Yojson.Safe.t) : t = { metadata; suggested_fee = [] }
