open Core_kernel

type t =
  ( Party.t
  , Parties.Digest.Party.t
  , Parties.Digest.Forest.t )
  Parties.Call_forest.t

let empty () = []

let if_ = Parties.value_if

let is_empty = List.is_empty

let pop_exn : t -> (Party.t * t) * t = function
  | { stack_hash = _; elt = { party; calls; party_digest = _ } } :: xs ->
      ((party, calls), xs)
  | _ ->
      failwith "pop_exn"
