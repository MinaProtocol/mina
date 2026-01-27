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

  module Serializable_type : sig
    type raw_serializable := Stable.Latest.t

    [%%versioned:
    module Stable : sig
      module V2 : sig
        type t
      end
    end]

    val to_raw_serializable : Stable.Latest.t -> raw_serializable

    val statement : t -> Mina_state.Snarked_ledger_state.t
  end

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

  val underlying_proof : t -> Proof.t

  val snarked_ledger_hash : t -> Frozen_ledger_hash.t

  module Cached : sig
    type t =
      ( Mina_state.Snarked_ledger_state.With_sok.t
      , Proof_cache_tag.t )
      Proof_carrying_data.t

    val write_proof_to_disk :
      proof_cache_db:Proof_cache_tag.cache_db -> Stable.Latest.t -> t

    val read_proof_from_disk : t -> Stable.Latest.t

    val statement : t -> Mina_state.Snarked_ledger_state.t

    val underlying_proof : t -> Proof_cache_tag.t

    val create :
         statement:Mina_state.Snarked_ledger_state.t
      -> sok_digest:Sok_message.Digest.t
      -> proof:Proof_cache_tag.t
      -> t

    val to_serializable_type : t -> Serializable_type.Stable.Latest.t
  end
end
