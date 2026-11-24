(** A log of the levels at which masks were orphaned, shared by every
    ledger. Each mask keeps its place in the log, and catches up on the entries
    after it before it is used. *)
type t = { mutable tail : (int * t) option }

let last = ref { tail = None }

let current () = !last

let append level =
  let next = { tail = None } in
  !last.tail <- Some (level, next) ;
  last := next
