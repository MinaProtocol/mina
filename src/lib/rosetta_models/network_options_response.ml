(*
 * This file has been generated by the OCamlClientCodegen generator for openapi-generator.
 *
 * Generated by: https://openapi-generator.tech
 *
 * Schema Network_options_response.t : NetworkOptionsResponse contains information about the versioning of the node and the allowed operation statuses, operation types, and errors. 
 *)

type t = { version : Version.t; allow : Allow.t }
[@@deriving yojson { strict = false }, show, eq]

(** NetworkOptionsResponse contains information about the versioning of the node and the allowed operation statuses, operation types, and errors.  *)
let create (version : Version.t) (allow : Allow.t) : t = { version; allow }
