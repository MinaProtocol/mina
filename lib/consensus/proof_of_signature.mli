module Make (Ledger_builder_diff : sig
  type t [@@deriving sexp]
end) :
  Mechanism.S
