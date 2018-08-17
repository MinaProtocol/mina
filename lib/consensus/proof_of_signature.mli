module Make
(Proof : sig
  type t [@@deriving bin_io, sexp]
end)
(Ledger_builder_diff : sig
   type t [@@deriving sexp, bin_io]
end) :
  Mechanism.S
  with module Proof = Proof
   and type Internal_transition.Ledger_builder_diff.t = Ledger_builder_diff.t
   and type External_transition.Ledger_builder_diff.t = Ledger_builder_diff.t
