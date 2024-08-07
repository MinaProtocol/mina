(*
 * This file has been generated by the OCamlClientCodegen generator for openapi-generator.
 *
 * Generated by: https://openapi-generator.tech
 *
 * Schema Metadata_request.t : A MetadataRequest is utilized in any request where the only argument is optional metadata. 
 *)

type t = { metadata : Yojson.Safe.t option [@default None] }
[@@deriving yojson { strict = false }, show, eq]

(** A MetadataRequest is utilized in any request where the only argument is optional metadata.  *)
let create () : t = { metadata = None }
