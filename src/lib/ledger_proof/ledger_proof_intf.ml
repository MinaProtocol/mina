open Core_kernel
open Mina_base

module type S = sig
  type t [@@deriving compare, equal, sexp, yojson, hash]

  [%%versioned:
  module Stable : sig
    [@@@no_toplevel_latest_type]

    module V2 : sig
      type nonrec t = t [@@deriving compare, equal, sexp, yojson, hash]

      val to_latest : t -> t
    end
  end]

  val create :
       statement:Mina_state.Snarked_ledger_state.t
    -> sok_digest:Sok_message.Digest.t
    -> proof:Proof.t
    -> t

  val statement_target :
       Mina_state.Snarked_ledger_state.t
    -> ( Frozen_ledger_hash.t
       , Pending_coinbase.Stack_versioned.t
       , Mina_state.Local_state.t )
       Mina_state.Registers.t

  val statement : t -> Mina_state.Snarked_ledger_state.t

  val statement_with_sok : t -> Mina_state.Snarked_ledger_state.With_sok.t

  val statement_with_sok_target :
       Mina_state.Snarked_ledger_state.With_sok.t
    -> ( Frozen_ledger_hash.t
       , Pending_coinbase.Stack_versioned.t
       , Mina_state.Local_state.t )
       Mina_state.Registers.t

  val sok_digest : t -> Sok_message.Digest.t

  val underlying_proof : t -> Proof.t

  val snarked_ledger_hash : t -> Frozen_ledger_hash.t
end
