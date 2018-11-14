open Core_kernel

module type S = sig
  module Ledger_builder_diff : sig
    type t
  end

  module Snark_transition : Snark_transition.S

  type t [@@deriving sexp, bin_io]

  val create :
       snark_transition:Snark_transition.value
    -> ledger_builder_diff:Ledger_builder_diff.t
    -> t

  val snark_transition : t -> Snark_transition.value

  val ledger_builder_diff : t -> Ledger_builder_diff.t
end

module Make (Ledger_builder_diff : sig
  type t [@@deriving sexp, bin_io]
end)
(Snark_transition : Snark_transition.S) :
  S
  with module Ledger_builder_diff = Ledger_builder_diff
   and module Snark_transition = Snark_transition = struct
  module Ledger_builder_diff = Ledger_builder_diff
  module Snark_transition = Snark_transition

  type t =
    { snark_transition: Snark_transition.value
    ; ledger_builder_diff: Ledger_builder_diff.t }
  [@@deriving sexp, fields, bin_io]

  let create ~snark_transition ~ledger_builder_diff =
    {snark_transition; ledger_builder_diff}
end
