open Core_kernel
open Async_kernel

module Base = struct
  module type S = sig
    module Security : Protocols.Coda_pow.Security_intf

    module Private_key : Protocols.Coda_pow.Private_key_intf

    module Public_key :
      Protocols.Coda_pow.Public_key_intf with module Private_key = Private_key

    module State_hash : sig
      type t [@@deriving eq, sexp, compare, bin_io]

      val to_bits : t -> bool list

      val to_bytes : t -> string
    end

    module Ledger_hash : sig
      type t [@@deriving eq, bin_io, sexp, eq]
    end

    module Frozen_ledger_hash : sig
      type t [@@deriving eq, bin_io, sexp, eq]
    end

    module Ledger_builder_hash : sig
      type t [@@deriving eq, sexp, compare]

      val ledger_hash : t -> Ledger_hash.t
    end

    module Ledger_builder_diff : sig
      type t [@@deriving sexp, bin_io]

      module With_valid_signatures_and_proofs : sig
        type t
      end
    end

    module Ledger : sig
      type t

      val copy : t -> t

      val merkle_root : t -> Ledger_hash.t
    end

    module Ledger_builder_aux_hash : sig
      type t [@@deriving sexp]
    end

    module Protocol_state_proof : sig
      type t
    end

    module Consensus_mechanism : sig
      module Local_state : sig
        type t
      end

      module Consensus_state : sig
        type value
      end

      module Blockchain_state : sig
        type value [@@deriving eq]

        val ledger_hash : value -> Frozen_ledger_hash.t

        val ledger_builder_hash : value -> Ledger_builder_hash.t
      end

      module Protocol_state : sig
        type value [@@deriving sexp]

        val create_value :
             previous_state_hash:State_hash.t
          -> blockchain_state:Blockchain_state.value
          -> consensus_state:Consensus_state.value
          -> value

        val previous_state_hash : value -> State_hash.t

        val blockchain_state : value -> Blockchain_state.value

        val consensus_state : value -> Consensus_state.value

        val equal_value : value -> value -> bool

        val hash : value -> State_hash.t

        val to_string_record : value -> string
      end

      module External_transition : sig
        type t [@@deriving bin_io, eq, compare, sexp]

        val protocol_state : t -> Protocol_state.value

        val protocol_state_proof : t -> Protocol_state_proof.t

        val ledger_builder_diff : t -> Ledger_builder_diff.t
      end

      (* This checks the SNARKs in State/LB and does the transition *)

      val select :
           existing:Consensus_state.value
        -> candidate:Consensus_state.value
        -> logger:Logger.t
        -> time_received:Unix_timestamp.t
        -> [`Keep | `Take]

      val lock_transition :
           ?proposer_public_key:Public_key.Compressed.t
        -> Consensus_state.value
        -> Consensus_state.value
        -> snarked_ledger:(unit -> Ledger.t Or_error.t)
        -> local_state:Local_state.t
        -> unit
    end

    module Ledger_proof_statement : sig
      type t

      val target : t -> Frozen_ledger_hash.t
    end

    module Ledger_proof : sig
      type t

      val statement : t -> Ledger_proof_statement.t
    end

    module Ledger_builder :
      Protocols.Coda_pow.Ledger_builder_base_intf
      with type ledger_builder_hash := Ledger_builder_hash.t
       and type frozen_ledger_hash := Frozen_ledger_hash.t
       and type valid_diff :=
                  Ledger_builder_diff.With_valid_signatures_and_proofs.t
       and type diff := Ledger_builder_diff.t
       and type ledger_proof := Ledger_proof.t
       and type ledger := Ledger.t
       and type ledger_builder_aux_hash := Ledger_builder_aux_hash.t

    module Tip :
      Protocols.Coda_pow.Tip_intf
      with type ledger_builder := Ledger_builder.t
       and type protocol_state := Consensus_mechanism.Protocol_state.value
       and type protocol_state_proof := Protocol_state_proof.t
       and type external_transition :=
                  Consensus_mechanism.External_transition.t

    val verify_blockchain :
         Protocol_state_proof.t
      -> Consensus_mechanism.Protocol_state.value
      -> bool Deferred.Or_error.t
  end
end

module Synchronizing = struct
  module type S = sig
    include Base.S

    module Sync_ledger : sig
      type t

      type answer [@@deriving bin_io]

      type query [@@deriving bin_io]

      module Responder : sig
        type t

        val create : Ledger.t -> (query -> unit) -> t

        val answer_query : t -> query -> answer
      end

      val create : Ledger.t -> parent_log:Logger.t -> t

      val answer_writer : t -> (Ledger_hash.t * answer) Linear_pipe.Writer.t

      val query_reader : t -> (Ledger_hash.t * query) Linear_pipe.Reader.t

      val destroy : t -> unit

      val fetch :
           t
        -> Ledger_hash.t
        -> [ `Ok of Ledger.t
           | `Target_changed of Ledger_hash.t option * Ledger_hash.t ]
           Deferred.t
    end

    module Net : sig
      include
        Coda_lib.Ledger_builder_io_intf
        with type sync_ledger_query := Sync_ledger.query
         and type sync_ledger_answer := Sync_ledger.answer
         and type ledger_builder_hash := Ledger_builder_hash.t
         and type ledger_builder_aux := Ledger_builder.Aux.t
         and type ledger_hash := Ledger_hash.t
         and type protocol_state := Consensus_mechanism.Protocol_state.value
    end
  end
end

module type S = sig
  include Synchronizing.S

  module Store : Storage.With_checksum_intf with type location = string
end
