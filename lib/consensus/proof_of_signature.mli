module type Inputs_intf = sig
  module Proof : sig
    type t [@@deriving bin_io, sexp]
  end

  module Ledger_builder_diff : sig
    type t [@@deriving bin_io, sexp]
  end
end

module Make (Inputs : Inputs_intf) :
  Mechanism.S
  with type Proof.t = Inputs.Proof.t
   and type Internal_transition.Ledger_builder_diff.t = Inputs.Ledger_builder_diff.t
   and type External_transition.Ledger_builder_diff.t = Inputs.Ledger_builder_diff.t
