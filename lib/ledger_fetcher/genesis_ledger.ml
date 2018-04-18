
module Make
  (Ledger : sig
    type t
    val create : unit -> t
  end)
= struct
  let ledger = Ledger.create ()
end

