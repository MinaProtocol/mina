open Async_kernel

module type S = sig
  include Coda_intf.Inputs_intf

  val max_length : int
end

module type With_breadcrumb_intf = sig
  include Coda_intf.Inputs_intf

  module Breadcrumb :
    Coda_intf.Transition_frontier_breadcrumb_intf
    with type mostly_validated_external_transition :=
                ( [`Time_received] * Truth.true_t
                , [`Proof] * Truth.true_t
                , [`Frontier_dependencies] * Truth.true_t
                , [`Staged_ledger_diff] * Truth.false_t )
                External_transition.Validation.with_transition
     and type external_transition_validated := External_transition.Validated.t
     and type staged_ledger := Staged_ledger.t
     and type verifier := Verifier.t
end

module type With_diff_intf = sig
  include With_breadcrumb_intf

  module Diff :
    Coda_intf.Transition_frontier_diff_intf
    with type breadcrumb := Breadcrumb.t
     and type external_transition_validated := External_transition.Validated.t
     and type scan_state := Staged_ledger.Scan_state.t
end

module type With_base_frontier_intf = sig
  include Coda_intf.Inputs_intf

  module Frontier : sig
    include
      Coda_intf.Transition_frontier_creatable_intf
      with type mostly_validated_external_transition :=
                  ( [`Time_received] * Truth.true_t
                  , [`Proof] * Truth.true_t
                  , [`Frontier_dependencies] * Truth.true_t
                  , [`Staged_ledger_diff] * Truth.false_t )
                  External_transition.Validation.with_transition
       and type external_transition_validated :=
                  External_transition.Validated.t
       and type transaction_snark_scan_state := Staged_ledger.Scan_state.t
       and type staged_ledger := Staged_ledger.t
       and type staged_ledger_diff := Staged_ledger_diff.t
       and type verifier := Verifier.t

    val set_hash_unsafe : t -> [`I_promise_this_is_safe of Hash.t] -> unit

    val hash : t -> Hash.t

    val apply_diffs :
      t -> Diff.Full.E.t list -> [`New_root of Root_identifier.t option]
  end
end

module type With_extensions_intf = sig
  include With_base_frontier_intf

  module Extensions : sig
    include
      Coda_intf.Transition_frontier_extensions_intf
      with type breadcrumb := Frontier.Breadcrumb.t
       and type transition_frontier := Frontier.t
       and type transition_frontier_diff := Frontier.Diff.Lite.E.t

    type t

    val create : Frontier.Breadcrumb.t -> t Deferred.t

    val notify :
         t
      -> frontier:Frontier.t
      -> diffs:Frontier.Diff.Lite.E.t list
      -> unit Deferred.t
  end
end
