open Core_kernel
open Mina_base

module type S = sig
  module Poly : sig
    type 'a t
  end

  type t = Proof.t Poly.t [@@deriving compare, equal, sexp, yojson, hash]

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
    -> proof:'p
    -> 'p Poly.t

  val statement_target :
       Mina_state.Snarked_ledger_state.t
    -> ( Frozen_ledger_hash.t
       , Pending_coinbase.Stack_versioned.t
       , Mina_state.Local_state.t )
       Mina_state.Registers.t

  val statement : _ Poly.t -> Mina_state.Snarked_ledger_state.t

  val statement_with_sok :
    _ Poly.t -> Mina_state.Snarked_ledger_state.With_sok.t

  val statement_with_sok_target :
       Mina_state.Snarked_ledger_state.With_sok.t
    -> ( Frozen_ledger_hash.t
       , Pending_coinbase.Stack_versioned.t
       , Mina_state.Local_state.t )
       Mina_state.Registers.t

  val sok_digest : _ Poly.t -> Sok_message.Digest.t

  val underlying_proof : 'p Poly.t -> 'p

  val snarked_ledger_hash : _ Poly.t -> Frozen_ledger_hash.t

  module Cached : sig
    type t = Proof_cache_tag.t Poly.t

    val generate :
      proof_cache_db:Proof_cache_tag.cache_db -> Stable.Latest.t -> t

    val unwrap : t -> Stable.Latest.t
  end
end
