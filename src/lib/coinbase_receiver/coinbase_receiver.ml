(* coinbase_receiver.ml *)

(* Producer: block producer receives coinbases
   Other: specified account (with default token) receives coinbases
*)

open Signature_lib

type t = [`Producer | `Other of Public_key.Compressed.t]

let resolve ~self : t -> Public_key.Compressed.t = function
  | `Producer ->
      self
  | `Other pk ->
      pk
