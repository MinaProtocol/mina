(* event_declarations.ml *)

open Core_kernel

(* examples only
   TODO: write actual events
*)

(* implicit log message *)
type Structured_events.t += Reached_block_height of {height: int}
  [@@deriving register_event]

(* explicit log message *)
type Structured_events.t += Proof_failure of {why: string}
  [@@deriving register_event {msg= "Proof failed because $why"}]
