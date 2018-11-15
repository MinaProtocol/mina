open Core_kernel

module type S = sig
  module Ledger_builder_diff : sig
    type t
  end

  module Prover_state : sig
    type t [@@deriving sexp, bin_io]
  end

  module Snark_transition : Snark_transition.S

  type t [@@deriving sexp, bin_io]

  val create :
       snark_transition:Snark_transition.value
    -> prover_state:Prover_state.t
    -> ledger_builder_diff:Ledger_builder_diff.t
    -> t

  val snark_transition : t -> Snark_transition.value

  val prover_state : t -> Prover_state.t

  val ledger_builder_diff : t -> Ledger_builder_diff.t
end

module Make (Ledger_builder_diff : sig
  type t [@@deriving sexp, bin_io]
end)
(Snark_transition : Snark_transition.S) (Prover_state : sig
    type t [@@deriving sexp, bin_io]
end) :
  S
  with module Ledger_builder_diff = Ledger_builder_diff
   and module Snark_transition = Snark_transition
   and module Prover_state = Prover_state = struct
  module Ledger_builder_diff = Ledger_builder_diff
  module Snark_transition = Snark_transition
  module Prover_state = Prover_state

  type t =
    { snark_transition: Snark_transition.value
    ; prover_state: Prover_state.t
    ; ledger_builder_diff: Ledger_builder_diff.t }
  [@@deriving sexp, fields, bin_io]

  let create ~snark_transition ~prover_state ~ledger_builder_diff =
    {snark_transition; ledger_builder_diff; prover_state}
end
