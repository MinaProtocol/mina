(*
 * This file has been generated by the OCamlClientCodegen generator for openapi-generator.
 *
 * Generated by: https://openapi-generator.tech
 *
 * Schema Public_key.t : PublicKey contains a public key byte array for a particular CurveType encoded in hex.  Note that there is no PrivateKey struct as this is NEVER the concern of an implementation. 
 *)

type t =
  { (* Hex-encoded public key bytes in the format specified by the CurveType.  *)
    hex_bytes : string
  ; curve_type : Enums.curvetype
  }
[@@deriving yojson { strict = false }, show, eq]

(** PublicKey contains a public key byte array for a particular CurveType encoded in hex.  Note that there is no PrivateKey struct as this is NEVER the concern of an implementation.  *)
let create (hex_bytes : string) (curve_type : Enums.curvetype) : t =
  { hex_bytes; curve_type }
