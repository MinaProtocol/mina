module Make
(Ledger_proof : sig
  type t [@@deriving bin_io, sexp]
end)
(Ledger_builder_diff : sig
  type t [@@deriving sexp]
end) :
  Mechanism.S
