(*
 * This file has been generated by the OCamlClientCodegen generator for openapi-generator.
 *
 * Generated by: https://openapi-generator.tech
 *
 * Schema Amount.t : Amount is some Value of a Currency. It is considered invalid to specify a Value without a Currency. 
 *)

type t =
  { (* Value of the transaction in atomic units represented as an arbitrary-sized signed integer.  For example, 1 BTC would be represented by a value of 100000000.  *)
    value : string
  ; currency : Currency.t
  ; metadata : Yojson.Safe.t option [@default None]
  }
[@@deriving yojson { strict = false }, show, eq]

(** Amount is some Value of a Currency. It is considered invalid to specify a Value without a Currency.  *)
let create (value : string) (currency : Currency.t) : t =
  { value; currency; metadata = None }
