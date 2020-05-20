(* logging_events.ml -- structured logging events *)

(* metadata is a list of pairs (field,types), where field is a string naming the metadata item, and
    types is a list of strings representing type constructors
   id is the SHA1 hash of name
*)
type t =
  { name: string
  ; message: string
  ; metadata: (string * string list) list
  ; id: string }

(* examples, not real events; TODO: populate with real events *)

(* with metadata *)
[%%declare_event
Received_blocks
, "Received blocks $blocks from $node"
, [(blocks : string list); (node : string)]]

(* no metadata *)
[%%declare_event
Bootstrap_complete, "Bootstrap_complete"]
