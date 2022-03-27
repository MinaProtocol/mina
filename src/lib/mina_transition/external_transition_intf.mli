module type External_transition_common_intf = sig
  type t

  type protocol_version_status =
    { valid_current : bool; valid_next : bool; matches_daemon : bool }

  val protocol_version_status : t -> protocol_version_status

  val protocol_state : t -> Mina_state.Protocol_state.Value.t

  val protocol_state_proof : t -> Mina_base.Proof.t

  val blockchain_state : t -> Mina_state.Blockchain_state.Value.t

  val blockchain_length : t -> Unsigned.UInt32.t

  val consensus_state : t -> Consensus.Data.Consensus_state.Value.t

  val staged_ledger_diff : t -> Staged_ledger_diff.t

  val state_hashes : t -> Mina_base.State_hash.State_hashes.t

  val parent_hash : t -> Mina_base.State_hash.t

  val consensus_time_produced_at : t -> Consensus.Data.Consensus_time.t

  val block_producer : t -> Signature_lib.Public_key.Compressed.t

  val block_winner : t -> Signature_lib.Public_key.Compressed.t

  val coinbase_receiver : t -> Signature_lib.Public_key.Compressed.t

  val supercharge_coinbase : t -> bool

  val transactions :
       constraint_constants:Genesis_constants.Constraint_constants.t
    -> t
    -> Mina_base.Transaction.t Mina_base.With_status.t list

  val commands : t -> Mina_base.User_command.t Mina_base.With_status.t list

  val payments : t -> Mina_base.Signed_command.t Mina_base.With_status.t list

  val completed_works : t -> Transaction_snark_work.t list

  val global_slot : t -> Unsigned.uint32

  val delta_transition_chain_proof :
    t -> Mina_base.State_hash.t * Mina_base.State_body_hash.t list

  val current_protocol_version : t -> Protocol_version.t

  val proposed_protocol_version_opt : t -> Protocol_version.t option

  val accept : t -> unit

  val reject : t -> unit

  val poke_validation_callback : t -> Mina_net2.Validation_callback.t -> unit
end

module type External_transition_base_intf = sig
  type t

  val to_yojson : t -> Yojson.Safe.t

  val t_of_sexp : Sexplib0.Sexp.t -> t

  val sexp_of_t : t -> Sexplib0.Sexp.t

  val equal : t -> t -> bool

  module Stable : sig
    module V1 : sig
      type nonrec t = t

      val bin_size_t : t Bin_prot.Size.sizer

      val bin_write_t : t Bin_prot.Write.writer

      val bin_read_t : t Bin_prot.Read.reader

      val __bin_read_t__ : (int -> t) Bin_prot.Read.reader

      val bin_shape_t : Bin_prot.Shape.t

      val bin_writer_t : t Bin_prot.Type_class.writer

      val bin_reader_t : t Bin_prot.Type_class.reader

      val bin_t : t Bin_prot.Type_class.t

      val __versioned__ : unit

      val t_of_sexp : Sexplib0.Sexp.t -> t

      val sexp_of_t : t -> Sexplib0.Sexp.t
    end

    module Latest = V1

    val versions :
      (int * (Core_kernel.Bigstring.t -> pos_ref:int Core_kernel.ref -> t))
      array

    val bin_read_to_latest_opt :
      Core_kernel.Bin_prot.Common.buf -> pos_ref:int Core_kernel.ref -> t option
  end

  type protocol_version_status =
    { valid_current : bool; valid_next : bool; matches_daemon : bool }

  val protocol_version_status : t -> protocol_version_status

  val protocol_state : t -> Mina_state.Protocol_state.Value.t

  val protocol_state_proof : t -> Mina_base.Proof.t

  val blockchain_state : t -> Mina_state.Blockchain_state.Value.t

  val blockchain_length : t -> Unsigned.UInt32.t

  val consensus_state : t -> Consensus.Data.Consensus_state.Value.t

  val staged_ledger_diff : t -> Staged_ledger_diff.t

  val state_hashes : t -> Mina_base.State_hash.State_hashes.t

  val parent_hash : t -> Mina_base.State_hash.t

  val consensus_time_produced_at : t -> Consensus.Data.Consensus_time.t

  val block_producer : t -> Signature_lib.Public_key.Compressed.t

  val block_winner : t -> Signature_lib.Public_key.Compressed.t

  val coinbase_receiver : t -> Signature_lib.Public_key.Compressed.t

  val supercharge_coinbase : t -> bool

  val transactions :
       constraint_constants:Genesis_constants.Constraint_constants.t
    -> t
    -> Mina_base.Transaction.t Mina_base.With_status.t list

  val commands : t -> Mina_base.User_command.t Mina_base.With_status.t list

  val payments : t -> Mina_base.Signed_command.t Mina_base.With_status.t list

  val completed_works : t -> Transaction_snark_work.t list

  val global_slot : t -> Unsigned.uint32

  val delta_transition_chain_proof :
    t -> Mina_base.State_hash.t * Mina_base.State_body_hash.t list

  val current_protocol_version : t -> Protocol_version.t

  val proposed_protocol_version_opt : t -> Protocol_version.t option

  val accept : t -> unit

  val reject : t -> unit

  val poke_validation_callback : t -> Mina_net2.Validation_callback.t -> unit
end

module type S = sig
  type t

  val to_yojson : t -> Yojson.Safe.t

  val t_of_sexp : Sexplib0.Sexp.t -> t

  val sexp_of_t : t -> Sexplib0.Sexp.t

  val equal : t -> t -> bool

  module Stable : sig
    module V1 : sig
      type nonrec t = t

      val bin_size_t : t Bin_prot.Size.sizer

      val bin_write_t : t Bin_prot.Write.writer

      val bin_read_t : t Bin_prot.Read.reader

      val __bin_read_t__ : (int -> t) Bin_prot.Read.reader

      val bin_shape_t : Bin_prot.Shape.t

      val bin_writer_t : t Bin_prot.Type_class.writer

      val bin_reader_t : t Bin_prot.Type_class.reader

      val bin_t : t Bin_prot.Type_class.t

      val __versioned__ : unit

      val t_of_sexp : Sexplib0.Sexp.t -> t

      val sexp_of_t : t -> Sexplib0.Sexp.t
    end

    module Latest = V1

    val versions :
      (int * (Core_kernel.Bigstring.t -> pos_ref:int Core_kernel.ref -> t))
      array

    val bin_read_to_latest_opt :
      Core_kernel.Bin_prot.Common.buf -> pos_ref:int Core_kernel.ref -> t option
  end

  type protocol_version_status =
    { valid_current : bool; valid_next : bool; matches_daemon : bool }

  val protocol_version_status : t -> protocol_version_status

  val protocol_state : t -> Mina_state.Protocol_state.Value.t

  val protocol_state_proof : t -> Mina_base.Proof.t

  val blockchain_state : t -> Mina_state.Blockchain_state.Value.t

  val blockchain_length : t -> Unsigned.UInt32.t

  val consensus_state : t -> Consensus.Data.Consensus_state.Value.t

  val staged_ledger_diff : t -> Staged_ledger_diff.t

  val state_hashes : t -> Mina_base.State_hash.State_hashes.t

  val parent_hash : t -> Mina_base.State_hash.t

  val consensus_time_produced_at : t -> Consensus.Data.Consensus_time.t

  val block_producer : t -> Signature_lib.Public_key.Compressed.t

  val block_winner : t -> Signature_lib.Public_key.Compressed.t

  val coinbase_receiver : t -> Signature_lib.Public_key.Compressed.t

  val supercharge_coinbase : t -> bool

  val transactions :
       constraint_constants:Genesis_constants.Constraint_constants.t
    -> t
    -> Mina_base.Transaction.t Mina_base.With_status.t list

  val commands : t -> Mina_base.User_command.t Mina_base.With_status.t list

  val payments : t -> Mina_base.Signed_command.t Mina_base.With_status.t list

  val completed_works : t -> Transaction_snark_work.t list

  val global_slot : t -> Unsigned.uint32

  val delta_transition_chain_proof :
    t -> Mina_base.State_hash.t * Mina_base.State_body_hash.t list

  val current_protocol_version : t -> Protocol_version.t

  val proposed_protocol_version_opt : t -> Protocol_version.t option

  val accept : t -> unit

  val reject : t -> unit

  val poke_validation_callback : t -> Mina_net2.Validation_callback.t -> unit

  type external_transition = t

  module Precomputed_block : sig
    module Proof : sig
      type t = Mina_base.Proof.t

      val to_yojson : t -> Yojson.Safe.t

      val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

      val t_of_sexp : Sexplib0.Sexp.t -> t

      val sexp_of_t : t -> Sexplib0.Sexp.t

      val to_bin_string : t -> string

      val of_bin_string : string -> t
    end

    type t =
      { scheduled_time : Block_time.Time.t
      ; protocol_state : Mina_state.Protocol_state.value
      ; protocol_state_proof : Proof.t
      ; staged_ledger_diff : Staged_ledger_diff.t
      ; delta_transition_chain_proof :
          Mina_base.Frozen_ledger_hash.t * Mina_base.Frozen_ledger_hash.t list
      }

    val to_yojson : t -> Yojson.Safe.t

    val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

    val t_of_sexp : Sexplib0.Sexp.t -> t

    val sexp_of_t : t -> Sexplib0.Sexp.t

    module Stable : sig
      module V1 : sig
        type nonrec t = t =
          { scheduled_time : Block_time.Stable.V1.t
          ; protocol_state : Mina_state.Protocol_state.Value.Stable.V1.t
          ; protocol_state_proof : Mina_base.Proof.Stable.V1.t
          ; staged_ledger_diff : Staged_ledger_diff.Stable.V1.t
          ; delta_transition_chain_proof :
              Mina_base.Frozen_ledger_hash.Stable.V1.t
              * Mina_base.Frozen_ledger_hash.Stable.V1.t list
          }

        val bin_size_t : t Bin_prot.Size.sizer

        val bin_write_t : t Bin_prot.Write.writer

        val bin_read_t : t Bin_prot.Read.reader

        val __bin_read_t__ : (int -> t) Bin_prot.Read.reader

        val bin_shape_t : Bin_prot.Shape.t

        val bin_writer_t : t Bin_prot.Type_class.writer

        val bin_reader_t : t Bin_prot.Type_class.reader

        val bin_t : t Bin_prot.Type_class.t

        val __versioned__ : unit

        val to_latest : t -> t
      end

      module Latest = V1

      val versions :
        (int * (Core_kernel.Bigstring.t -> pos_ref:int Core_kernel.ref -> t))
        array

      val bin_read_to_latest_opt :
           Core_kernel.Bin_prot.Common.buf
        -> pos_ref:int Core_kernel.ref
        -> t option
    end

    val of_external_transition :
      scheduled_time:Block_time.Time.t -> external_transition -> t
  end

  module Validation : sig
    type ('a, 'b, 'c, 'd, 'e, 'f, 'g) t =
      ([ `Time_received ] * (unit, 'n) Truth.t)
      * ([ `Genesis_state ] * (unit, 'm) Truth.t)
      * ([ `Proof ] * (unit, 'l) Truth.t)
      * ( [ `Delta_transition_chain ]
        * (Mina_base.State_hash.t Non_empty_list.t, 'k) Truth.t )
      * ([ `Frontier_dependencies ] * (unit, 'j) Truth.t)
      * ([ `Staged_ledger_diff ] * (unit, 'i) Truth.t)
      * ([ `Protocol_versions ] * (unit, 'h) Truth.t)
      constraint 'a = [ `Time_received ] * (unit, 'n) Truth.t
      constraint 'b = [ `Genesis_state ] * (unit, 'm) Truth.t
      constraint 'c = [ `Proof ] * (unit, 'l) Truth.t
      constraint
        'd =
        [ `Delta_transition_chain ]
        * (Mina_base.State_hash.t Non_empty_list.t, 'k) Truth.t
      constraint 'e = [ `Frontier_dependencies ] * (unit, 'j) Truth.t
      constraint 'f = [ `Staged_ledger_diff ] * (unit, 'i) Truth.t
      constraint 'g = [ `Protocol_versions ] * (unit, 'h) Truth.t

    type fully_invalid =
      ( [ `Time_received ] * unit Truth.false_t
      , [ `Genesis_state ] * unit Truth.false_t
      , [ `Proof ] * unit Truth.false_t
      , [ `Delta_transition_chain ]
        * Mina_base.State_hash.t Non_empty_list.t Truth.false_t
      , [ `Frontier_dependencies ] * unit Truth.false_t
      , [ `Staged_ledger_diff ] * unit Truth.false_t
      , [ `Protocol_versions ] * unit Truth.false_t )
      t

    type fully_valid =
      ( [ `Time_received ] * unit Truth.true_t
      , [ `Genesis_state ] * unit Truth.true_t
      , [ `Proof ] * unit Truth.true_t
      , [ `Delta_transition_chain ]
        * Mina_base.State_hash.t Non_empty_list.t Truth.true_t
      , [ `Frontier_dependencies ] * unit Truth.true_t
      , [ `Staged_ledger_diff ] * unit Truth.true_t
      , [ `Protocol_versions ] * unit Truth.true_t )
      t

    type initial_valid =
      ( [ `Time_received ] * unit Truth.true_t
      , [ `Genesis_state ] * unit Truth.true_t
      , [ `Proof ] * unit Truth.true_t
      , [ `Delta_transition_chain ]
        * Mina_base.State_hash.t Non_empty_list.t Truth.true_t
      , [ `Frontier_dependencies ] * unit Truth.false_t
      , [ `Staged_ledger_diff ] * unit Truth.false_t
      , [ `Protocol_versions ] * unit Truth.true_t )
      t

    type almost_valid =
      ( [ `Time_received ] * unit Truth.true_t
      , [ `Genesis_state ] * unit Truth.true_t
      , [ `Proof ] * unit Truth.true_t
      , [ `Delta_transition_chain ]
        * Mina_base.State_hash.t Non_empty_list.t Truth.true_t
      , [ `Frontier_dependencies ] * unit Truth.true_t
      , [ `Staged_ledger_diff ] * unit Truth.false_t
      , [ `Protocol_versions ] * unit Truth.true_t )
      t

    type ('a, 'b, 'c, 'd, 'e, 'f, 'g) with_transition =
      external_transition Mina_base.State_hash.With_state_hashes.t
      * ( [ `Time_received ] * (unit, 'n) Truth.t
        , [ `Genesis_state ] * (unit, 'm) Truth.t
        , [ `Proof ] * (unit, 'l) Truth.t
        , [ `Delta_transition_chain ]
          * (Mina_base.State_hash.t Non_empty_list.t, 'k) Truth.t
        , [ `Frontier_dependencies ] * (unit, 'j) Truth.t
        , [ `Staged_ledger_diff ] * (unit, 'i) Truth.t
        , [ `Protocol_versions ] * (unit, 'h) Truth.t )
        t
      constraint 'a = [ `Time_received ] * (unit, 'n) Truth.t
      constraint 'b = [ `Genesis_state ] * (unit, 'm) Truth.t
      constraint 'c = [ `Proof ] * (unit, 'l) Truth.t
      constraint
        'd =
        [ `Delta_transition_chain ]
        * (Mina_base.State_hash.t Non_empty_list.t, 'k) Truth.t
      constraint 'e = [ `Frontier_dependencies ] * (unit, 'j) Truth.t
      constraint 'f = [ `Staged_ledger_diff ] * (unit, 'i) Truth.t
      constraint 'g = [ `Protocol_versions ] * (unit, 'h) Truth.t

    val fully_invalid : fully_invalid

    val wrap :
         external_transition Mina_base.State_hash.With_state_hashes.t
      -> external_transition Mina_base.State_hash.With_state_hashes.t
         * fully_invalid

    val extract_delta_transition_chain_witness :
         ( [ `Time_received ] * (unit, 'a) Truth.t
         , [ `Genesis_state ] * (unit, 'b) Truth.t
         , [ `Proof ] * (unit, 'c) Truth.t
         , [ `Delta_transition_chain ]
           * Mina_base.State_hash.t Non_empty_list.t Truth.true_t
         , [ `Frontier_dependencies ] * (unit, 'd) Truth.t
         , [ `Staged_ledger_diff ] * (unit, 'e) Truth.t
         , [ `Protocol_versions ] * (unit, 'f) Truth.t )
         t
      -> Mina_base.State_hash.t Non_empty_list.t

    val reset_frontier_dependencies_validation :
         ( [ `Time_received ] * (unit, 'a) Truth.t
         , [ `Genesis_state ] * (unit, 'b) Truth.t
         , [ `Proof ] * (unit, 'c) Truth.t
         , [ `Delta_transition_chain ]
           * (Mina_base.State_hash.t Non_empty_list.t, 'd) Truth.t
         , [ `Frontier_dependencies ] * unit Truth.true_t
         , [ `Staged_ledger_diff ] * (unit, 'e) Truth.t
         , [ `Protocol_versions ] * (unit, 'f) Truth.t )
         with_transition
      -> ( [ `Time_received ] * (unit, 'a) Truth.t
         , [ `Genesis_state ] * (unit, 'b) Truth.t
         , [ `Proof ] * (unit, 'c) Truth.t
         , [ `Delta_transition_chain ]
           * (Mina_base.State_hash.t Non_empty_list.t, 'd) Truth.t
         , [ `Frontier_dependencies ] * unit Truth.false_t
         , [ `Staged_ledger_diff ] * (unit, 'e) Truth.t
         , [ `Protocol_versions ] * (unit, 'f) Truth.t )
         with_transition

    val reset_staged_ledger_diff_validation :
         ( [ `Time_received ] * (unit, 'a) Truth.t
         , [ `Genesis_state ] * (unit, 'b) Truth.t
         , [ `Proof ] * (unit, 'c) Truth.t
         , [ `Delta_transition_chain ]
           * (Mina_base.State_hash.t Non_empty_list.t, 'd) Truth.t
         , [ `Frontier_dependencies ] * (unit, 'e) Truth.t
         , [ `Staged_ledger_diff ] * unit Truth.true_t
         , [ `Protocol_versions ] * (unit, 'f) Truth.t )
         with_transition
      -> ( [ `Time_received ] * (unit, 'a) Truth.t
         , [ `Genesis_state ] * (unit, 'b) Truth.t
         , [ `Proof ] * (unit, 'c) Truth.t
         , [ `Delta_transition_chain ]
           * (Mina_base.State_hash.t Non_empty_list.t, 'd) Truth.t
         , [ `Frontier_dependencies ] * (unit, 'e) Truth.t
         , [ `Staged_ledger_diff ] * unit Truth.false_t
         , [ `Protocol_versions ] * (unit, 'f) Truth.t )
         with_transition

    val forget_validation :
         ( [ `Time_received ] * (unit, 'a) Truth.t
         , [ `Genesis_state ] * (unit, 'b) Truth.t
         , [ `Proof ] * (unit, 'c) Truth.t
         , [ `Delta_transition_chain ]
           * (Mina_base.State_hash.t Non_empty_list.t, 'd) Truth.t
         , [ `Frontier_dependencies ] * (unit, 'e) Truth.t
         , [ `Staged_ledger_diff ] * (unit, 'f) Truth.t
         , [ `Protocol_versions ] * (unit, 'g) Truth.t )
         with_transition
      -> external_transition

    val forget_validation_with_hash :
         ( [ `Time_received ] * (unit, 'a) Truth.t
         , [ `Genesis_state ] * (unit, 'b) Truth.t
         , [ `Proof ] * (unit, 'c) Truth.t
         , [ `Delta_transition_chain ]
           * (Mina_base.State_hash.t Non_empty_list.t, 'd) Truth.t
         , [ `Frontier_dependencies ] * (unit, 'e) Truth.t
         , [ `Staged_ledger_diff ] * (unit, 'f) Truth.t
         , [ `Protocol_versions ] * (unit, 'g) Truth.t )
         with_transition
      -> external_transition Mina_base.State_hash.With_state_hashes.t
  end

  module Initial_validated : sig
    type t =
      external_transition Mina_base.State_hash.With_state_hashes.t
      * Validation.initial_valid

    val compare : t -> t -> int

    val handle_dropped_transition :
      ?pipe_name:string -> logger:Logger.t -> t -> unit

    type protocol_version_status =
      { valid_current : bool; valid_next : bool; matches_daemon : bool }

    val protocol_version_status : t -> protocol_version_status

    val protocol_state : t -> Mina_state.Protocol_state.Value.t

    val protocol_state_proof : t -> Precomputed_block.Proof.t

    val blockchain_state : t -> Mina_state.Blockchain_state.Value.t

    val blockchain_length : t -> Unsigned.UInt32.t

    val consensus_state : t -> Consensus.Data.Consensus_state.Value.t

    val staged_ledger_diff : t -> Staged_ledger_diff.t

    val state_hashes : t -> Mina_base.State_hash.State_hashes.t

    val parent_hash : t -> Mina_base.State_hash.t

    val consensus_time_produced_at : t -> Consensus.Data.Consensus_time.t

    val block_producer : t -> Signature_lib.Public_key.Compressed.t

    val block_winner : t -> Signature_lib.Public_key.Compressed.t

    val coinbase_receiver : t -> Signature_lib.Public_key.Compressed.t

    val supercharge_coinbase : t -> bool

    val transactions :
         constraint_constants:Genesis_constants.Constraint_constants.t
      -> t
      -> Mina_base.Transaction.t Mina_base.With_status.t list

    val commands : t -> Mina_base.User_command.t Mina_base.With_status.t list

    val payments : t -> Mina_base.Signed_command.t Mina_base.With_status.t list

    val completed_works : t -> Transaction_snark_work.t list

    val global_slot : t -> Unsigned.uint32

    val delta_transition_chain_proof :
      t -> Mina_base.State_hash.t * Mina_base.State_body_hash.t list

    val current_protocol_version : t -> Protocol_version.t

    val proposed_protocol_version_opt : t -> Protocol_version.t option

    val accept : t -> unit

    val reject : t -> unit

    val poke_validation_callback : t -> Mina_net2.Validation_callback.t -> unit
  end

  module Almost_validated : sig
    type t =
      external_transition Mina_base.State_hash.With_state_hashes.t
      * Validation.almost_valid

    val compare : t -> t -> int

    type protocol_version_status =
      { valid_current : bool; valid_next : bool; matches_daemon : bool }

    val protocol_version_status : t -> protocol_version_status

    val protocol_state : t -> Mina_state.Protocol_state.Value.t

    val protocol_state_proof : t -> Precomputed_block.Proof.t

    val blockchain_state : t -> Mina_state.Blockchain_state.Value.t

    val blockchain_length : t -> Unsigned.UInt32.t

    val consensus_state : t -> Consensus.Data.Consensus_state.Value.t

    val staged_ledger_diff : t -> Staged_ledger_diff.t

    val state_hashes : t -> Mina_base.State_hash.State_hashes.t

    val parent_hash : t -> Mina_base.State_hash.t

    val consensus_time_produced_at : t -> Consensus.Data.Consensus_time.t

    val block_producer : t -> Signature_lib.Public_key.Compressed.t

    val block_winner : t -> Signature_lib.Public_key.Compressed.t

    val coinbase_receiver : t -> Signature_lib.Public_key.Compressed.t

    val supercharge_coinbase : t -> bool

    val transactions :
         constraint_constants:Genesis_constants.Constraint_constants.t
      -> t
      -> Mina_base.Transaction.t Mina_base.With_status.t list

    val commands : t -> Mina_base.User_command.t Mina_base.With_status.t list

    val payments : t -> Mina_base.Signed_command.t Mina_base.With_status.t list

    val completed_works : t -> Transaction_snark_work.t list

    val global_slot : t -> Unsigned.uint32

    val delta_transition_chain_proof :
      t -> Mina_base.State_hash.t * Mina_base.State_body_hash.t list

    val current_protocol_version : t -> Protocol_version.t

    val proposed_protocol_version_opt : t -> Protocol_version.t option

    val accept : t -> unit

    val reject : t -> unit

    val poke_validation_callback : t -> Mina_net2.Validation_callback.t -> unit
  end

  module Validated : sig
    type t =
      external_transition Mina_base.State_hash.With_state_hashes.t
      * Validation.fully_valid

    val to_yojson : t -> Yojson.Safe.t

    val compare : t -> t -> int

    val equal : t -> t -> bool

    val t_of_sexp : Sexplib0.Sexp.t -> t

    val sexp_of_t : t -> Sexplib0.Sexp.t

    module Stable : sig
      module V2 : sig
        type nonrec t = t

        val to_yojson : t -> Yojson.Safe.t

        val bin_size_t : t Bin_prot.Size.sizer

        val bin_write_t : t Bin_prot.Write.writer

        val bin_read_t : t Bin_prot.Read.reader

        val __bin_read_t__ : (int -> t) Bin_prot.Read.reader

        val bin_shape_t : Bin_prot.Shape.t

        val bin_writer_t : t Bin_prot.Type_class.writer

        val bin_reader_t : t Bin_prot.Type_class.reader

        val bin_t : t Bin_prot.Type_class.t

        val __versioned__ : unit

        val compare : t -> t -> int

        val equal : t -> t -> bool

        val t_of_sexp : Sexplib0.Sexp.t -> t

        val sexp_of_t : t -> Sexplib0.Sexp.t
      end

      module Latest = V2

      module V1 : sig
        type t =
          (external_transition, Mina_base.State_hash.t) With_hash.t
          * Validation.fully_valid

        val to_yojson : t -> Yojson.Safe.t

        val bin_size_t : t Bin_prot.Size.sizer

        val bin_write_t : t Bin_prot.Write.writer

        val bin_read_t : t Bin_prot.Read.reader

        val __bin_read_t__ : (int -> t) Bin_prot.Read.reader

        val bin_shape_t : Bin_prot.Shape.t

        val bin_writer_t : t Bin_prot.Type_class.writer

        val bin_reader_t : t Bin_prot.Type_class.reader

        val bin_t : t Bin_prot.Type_class.t

        val __versioned__ : unit

        val compare : t -> t -> int

        val equal : t -> t -> bool

        val t_of_sexp : Sexplib0.Sexp.t -> t

        val sexp_of_t : t -> Sexplib0.Sexp.t

        val to_latest : t -> V2.t

        val of_v2 : V2.t -> t

        val state_hash : t -> Mina_base.State_hash.t
      end

      val versions :
        (int * (Core_kernel.Bigstring.t -> pos_ref:int Core_kernel.ref -> t))
        array

      val bin_read_to_latest_opt :
           Core_kernel.Bin_prot.Common.buf
        -> pos_ref:int Core_kernel.ref
        -> t option
    end

    type protocol_version_status =
      { valid_current : bool; valid_next : bool; matches_daemon : bool }

    val protocol_version_status : t -> protocol_version_status

    val protocol_state : t -> Mina_state.Protocol_state.Value.t

    val protocol_state_proof : t -> Precomputed_block.Proof.t

    val blockchain_state : t -> Mina_state.Blockchain_state.Value.t

    val blockchain_length : t -> Unsigned.UInt32.t

    val consensus_state : t -> Consensus.Data.Consensus_state.Value.t

    val staged_ledger_diff : t -> Staged_ledger_diff.t

    val state_hashes : t -> Mina_base.State_hash.State_hashes.t

    val parent_hash : t -> Mina_base.State_hash.t

    val consensus_time_produced_at : t -> Consensus.Data.Consensus_time.t

    val block_producer : t -> Signature_lib.Public_key.Compressed.t

    val block_winner : t -> Signature_lib.Public_key.Compressed.t

    val coinbase_receiver : t -> Signature_lib.Public_key.Compressed.t

    val supercharge_coinbase : t -> bool

    val transactions :
         constraint_constants:Genesis_constants.Constraint_constants.t
      -> t
      -> Mina_base.Transaction.t Mina_base.With_status.t list

    val payments : t -> Mina_base.Signed_command.t Mina_base.With_status.t list

    val completed_works : t -> Transaction_snark_work.t list

    val global_slot : t -> Unsigned.uint32

    val delta_transition_chain_proof :
      t -> Mina_base.State_hash.t * Mina_base.State_body_hash.t list

    val current_protocol_version : t -> Protocol_version.t

    val proposed_protocol_version_opt : t -> Protocol_version.t option

    val accept : t -> unit

    val reject : t -> unit

    val poke_validation_callback : t -> Mina_net2.Validation_callback.t -> unit

    val erase :
         t
      -> external_transition Mina_base.State_hash.With_state_hashes.t
         * Mina_base.State_hash.Stable.Latest.t Non_empty_list.Stable.Latest.t

    val create_unsafe :
      external_transition -> [ `I_swear_this_is_safe_see_my_comment of t ]

    val handle_dropped_transition :
      ?pipe_name:string -> logger:Logger.t -> t -> unit

    val commands :
      t -> Mina_base.User_command.Valid.t Mina_base.With_status.t list

    val to_initial_validated : t -> Initial_validated.t

    val state_body_hash : t -> Mina_base.State_body_hash.t
  end

  val create :
       protocol_state:Mina_state.Protocol_state.Value.t
    -> protocol_state_proof:Precomputed_block.Proof.t
    -> staged_ledger_diff:Staged_ledger_diff.t
    -> delta_transition_chain_proof:
         Mina_base.State_hash.t * Mina_base.State_body_hash.t list
    -> validation_callback:Mina_net2.Validation_callback.t
    -> ?proposed_protocol_version_opt:Protocol_version.t
    -> unit
    -> t

  val genesis : precomputed_values:Precomputed_values.t -> Validated.t

  module For_tests : sig
    val create :
         protocol_state:Mina_state.Protocol_state.Value.t
      -> protocol_state_proof:Precomputed_block.Proof.t
      -> staged_ledger_diff:Staged_ledger_diff.t
      -> delta_transition_chain_proof:
           Mina_base.State_hash.t * Mina_base.State_body_hash.t list
      -> validation_callback:Mina_net2.Validation_callback.t
      -> ?proposed_protocol_version_opt:Protocol_version.t
      -> unit
      -> t

    val genesis : precomputed_values:Precomputed_values.t -> Validated.t
  end

  val timestamp : t -> Block_time.t

  val skip_time_received_validation :
       [ `This_transition_was_not_received_via_gossip ]
    -> ( [ `Time_received ] * unit Truth.false_t
       , [ `Genesis_state ] * (unit, 'a) Truth.t
       , [ `Proof ] * (unit, 'b) Truth.t
       , [ `Delta_transition_chain ]
         * (Mina_base.State_hash.t Non_empty_list.t, 'c) Truth.t
       , [ `Frontier_dependencies ] * (unit, 'd) Truth.t
       , [ `Staged_ledger_diff ] * (unit, 'e) Truth.t
       , [ `Protocol_versions ] * (unit, 'f) Truth.t )
       Validation.with_transition
    -> ( [ `Time_received ] * unit Truth.true_t
       , [ `Genesis_state ] * (unit, 'a) Truth.t
       , [ `Proof ] * (unit, 'b) Truth.t
       , [ `Delta_transition_chain ]
         * (Mina_base.State_hash.t Non_empty_list.t, 'c) Truth.t
       , [ `Frontier_dependencies ] * (unit, 'd) Truth.t
       , [ `Staged_ledger_diff ] * (unit, 'e) Truth.t
       , [ `Protocol_versions ] * (unit, 'f) Truth.t )
       Validation.with_transition

  val validate_time_received :
       precomputed_values:Precomputed_values.t
    -> ( [ `Time_received ] * unit Truth.false_t
       , [ `Genesis_state ] * (unit, 'a) Truth.t
       , [ `Proof ] * (unit, 'b) Truth.t
       , [ `Delta_transition_chain ]
         * (Mina_base.State_hash.t Non_empty_list.t, 'c) Truth.t
       , [ `Frontier_dependencies ] * (unit, 'd) Truth.t
       , [ `Staged_ledger_diff ] * (unit, 'e) Truth.t
       , [ `Protocol_versions ] * (unit, 'f) Truth.t )
       Validation.with_transition
    -> time_received:Block_time.t
    -> ( ( [ `Time_received ] * unit Truth.true_t
         , [ `Genesis_state ] * (unit, 'a) Truth.t
         , [ `Proof ] * (unit, 'b) Truth.t
         , [ `Delta_transition_chain ]
           * (Mina_base.State_hash.t Non_empty_list.t, 'c) Truth.t
         , [ `Frontier_dependencies ] * (unit, 'd) Truth.t
         , [ `Staged_ledger_diff ] * (unit, 'e) Truth.t
         , [ `Protocol_versions ] * (unit, 'f) Truth.t )
         Validation.with_transition
       , [> `Invalid_time_received of [ `Too_early | `Too_late of int64 ] ] )
       Core_kernel.Result.t

  val skip_proof_validation :
       [ `This_transition_was_generated_internally ]
    -> ( [ `Time_received ] * (unit, 'a) Truth.t
       , [ `Genesis_state ] * (unit, 'b) Truth.t
       , [ `Proof ] * unit Truth.false_t
       , [ `Delta_transition_chain ]
         * (Mina_base.State_hash.t Non_empty_list.t, 'c) Truth.t
       , [ `Frontier_dependencies ] * (unit, 'd) Truth.t
       , [ `Staged_ledger_diff ] * (unit, 'e) Truth.t
       , [ `Protocol_versions ] * (unit, 'f) Truth.t )
       Validation.with_transition
    -> ( [ `Time_received ] * (unit, 'a) Truth.t
       , [ `Genesis_state ] * (unit, 'b) Truth.t
       , [ `Proof ] * unit Truth.true_t
       , [ `Delta_transition_chain ]
         * (Mina_base.State_hash.t Non_empty_list.t, 'c) Truth.t
       , [ `Frontier_dependencies ] * (unit, 'd) Truth.t
       , [ `Staged_ledger_diff ] * (unit, 'e) Truth.t
       , [ `Protocol_versions ] * (unit, 'f) Truth.t )
       Validation.with_transition

  val skip_delta_transition_chain_validation :
       [ `This_transition_was_not_received_via_gossip ]
    -> ( [ `Time_received ] * (unit, 'a) Truth.t
       , [ `Genesis_state ] * (unit, 'b) Truth.t
       , [ `Proof ] * (unit, 'c) Truth.t
       , [ `Delta_transition_chain ]
         * Mina_base.State_hash.t Non_empty_list.t Truth.false_t
       , [ `Frontier_dependencies ] * (unit, 'd) Truth.t
       , [ `Staged_ledger_diff ] * (unit, 'e) Truth.t
       , [ `Protocol_versions ] * (unit, 'f) Truth.t )
       Validation.with_transition
    -> ( [ `Time_received ] * (unit, 'a) Truth.t
       , [ `Genesis_state ] * (unit, 'b) Truth.t
       , [ `Proof ] * (unit, 'c) Truth.t
       , [ `Delta_transition_chain ]
         * Mina_base.State_hash.t Non_empty_list.t Truth.true_t
       , [ `Frontier_dependencies ] * (unit, 'd) Truth.t
       , [ `Staged_ledger_diff ] * (unit, 'e) Truth.t
       , [ `Protocol_versions ] * (unit, 'f) Truth.t )
       Validation.with_transition

  val skip_genesis_protocol_state_validation :
       [ `This_transition_was_generated_internally ]
    -> ( [ `Time_received ] * (unit, 'a) Truth.t
       , [ `Genesis_state ] * unit Truth.false_t
       , [ `Proof ] * (unit, 'b) Truth.t
       , [ `Delta_transition_chain ]
         * (Mina_base.State_hash.t Non_empty_list.t, 'c) Truth.t
       , [ `Frontier_dependencies ] * (unit, 'd) Truth.t
       , [ `Staged_ledger_diff ] * (unit, 'e) Truth.t
       , [ `Protocol_versions ] * (unit, 'f) Truth.t )
       Validation.with_transition
    -> ( [ `Time_received ] * (unit, 'a) Truth.t
       , [ `Genesis_state ] * unit Truth.true_t
       , [ `Proof ] * (unit, 'b) Truth.t
       , [ `Delta_transition_chain ]
         * (Mina_base.State_hash.t Non_empty_list.t, 'c) Truth.t
       , [ `Frontier_dependencies ] * (unit, 'd) Truth.t
       , [ `Staged_ledger_diff ] * (unit, 'e) Truth.t
       , [ `Protocol_versions ] * (unit, 'f) Truth.t )
       Validation.with_transition

  val validate_genesis_protocol_state :
       genesis_state_hash:Mina_base.State_hash.t
    -> ( [ `Time_received ] * (unit, 'a) Truth.t
       , [ `Genesis_state ] * unit Truth.false_t
       , [ `Proof ] * (unit, 'b) Truth.t
       , [ `Delta_transition_chain ]
         * (Mina_base.State_hash.t Non_empty_list.t, 'c) Truth.t
       , [ `Frontier_dependencies ] * (unit, 'd) Truth.t
       , [ `Staged_ledger_diff ] * (unit, 'e) Truth.t
       , [ `Protocol_versions ] * (unit, 'f) Truth.t )
       Validation.with_transition
    -> ( ( [ `Time_received ] * (unit, 'a) Truth.t
         , [ `Genesis_state ] * unit Truth.true_t
         , [ `Proof ] * (unit, 'b) Truth.t
         , [ `Delta_transition_chain ]
           * (Mina_base.State_hash.t Non_empty_list.t, 'c) Truth.t
         , [ `Frontier_dependencies ] * (unit, 'd) Truth.t
         , [ `Staged_ledger_diff ] * (unit, 'e) Truth.t
         , [ `Protocol_versions ] * (unit, 'f) Truth.t )
         Validation.with_transition
       , [> `Invalid_genesis_protocol_state ] )
       Core_kernel.Result.t

  val validate_proofs :
       ( [ `Time_received ] * (unit, 'a) Truth.t
       , [ `Genesis_state ] * (unit, 'b) Truth.t
       , [ `Proof ] * unit Truth.false_t
       , [ `Delta_transition_chain ]
         * (Mina_base.State_hash.t Non_empty_list.t, 'c) Truth.t
       , [ `Frontier_dependencies ] * (unit, 'd) Truth.t
       , [ `Staged_ledger_diff ] * (unit, 'e) Truth.t
       , [ `Protocol_versions ] * (unit, 'f) Truth.t )
       Validation.with_transition
       list
    -> verifier:Verifier.t
    -> genesis_state_hash:Mina_base.State_hash.t
    -> ( ( [ `Time_received ] * (unit, 'a) Truth.t
         , [ `Genesis_state ] * (unit, 'b) Truth.t
         , [ `Proof ] * unit Truth.true_t
         , [ `Delta_transition_chain ]
           * (Mina_base.State_hash.t Non_empty_list.t, 'c) Truth.t
         , [ `Frontier_dependencies ] * (unit, 'd) Truth.t
         , [ `Staged_ledger_diff ] * (unit, 'e) Truth.t
         , [ `Protocol_versions ] * (unit, 'f) Truth.t )
         Validation.with_transition
         list
       , [> `Invalid_proof | `Verifier_error of Core_kernel.Error.t ] )
       Async_kernel.Deferred.Result.t

  val validate_delta_transition_chain :
       ( [ `Time_received ] * (unit, 'a) Truth.t
       , [ `Genesis_state ] * (unit, 'b) Truth.t
       , [ `Proof ] * (unit, 'c) Truth.t
       , [ `Delta_transition_chain ]
         * Mina_base.State_hash.t Non_empty_list.t Truth.false_t
       , [ `Frontier_dependencies ] * (unit, 'd) Truth.t
       , [ `Staged_ledger_diff ] * (unit, 'e) Truth.t
       , [ `Protocol_versions ] * (unit, 'f) Truth.t )
       Validation.with_transition
    -> ( ( [ `Time_received ] * (unit, 'a) Truth.t
         , [ `Genesis_state ] * (unit, 'b) Truth.t
         , [ `Proof ] * (unit, 'c) Truth.t
         , [ `Delta_transition_chain ]
           * Mina_base.State_hash.t Non_empty_list.t Truth.true_t
         , [ `Frontier_dependencies ] * (unit, 'd) Truth.t
         , [ `Staged_ledger_diff ] * (unit, 'e) Truth.t
         , [ `Protocol_versions ] * (unit, 'f) Truth.t )
         Validation.with_transition
       , [> `Invalid_delta_transition_chain_proof ] )
       Core_kernel.Result.t

  val validate_protocol_versions :
       ( [ `Time_received ] * (unit, 'a) Truth.t
       , [ `Genesis_state ] * (unit, 'b) Truth.t
       , [ `Proof ] * (unit, 'c) Truth.t
       , [ `Delta_transition_chain ]
         * (Mina_base.State_hash.t Non_empty_list.t, 'd) Truth.t
       , [ `Frontier_dependencies ] * (unit, 'e) Truth.t
       , [ `Staged_ledger_diff ] * (unit, 'f) Truth.t
       , [ `Protocol_versions ] * unit Truth.false_t )
       Validation.with_transition
    -> ( ( [ `Time_received ] * (unit, 'a) Truth.t
         , [ `Genesis_state ] * (unit, 'b) Truth.t
         , [ `Proof ] * (unit, 'c) Truth.t
         , [ `Delta_transition_chain ]
           * (Mina_base.State_hash.t Non_empty_list.t, 'd) Truth.t
         , [ `Frontier_dependencies ] * (unit, 'e) Truth.t
         , [ `Staged_ledger_diff ] * (unit, 'f) Truth.t
         , [ `Protocol_versions ] * unit Truth.true_t )
         Validation.with_transition
       , [> `Invalid_protocol_version | `Mismatched_protocol_version ] )
       Core_kernel.Result.t

  module Transition_frontier_validation : functor
    (Transition_frontier : sig
       type t

       module Breadcrumb : sig
         type t

         val validated_transition : t -> Validated.t
       end

       val root : t -> Breadcrumb.t

       val find : t -> Mina_base.State_hash.t -> Breadcrumb.t option
     end)
    -> sig
    val validate_frontier_dependencies :
         ( [ `Time_received ] * (unit, 'a) Truth.t
         , [ `Genesis_state ] * (unit, 'b) Truth.t
         , [ `Proof ] * (unit, 'c) Truth.t
         , [ `Delta_transition_chain ]
           * (Mina_base.State_hash.t Non_empty_list.t, 'd) Truth.t
         , [ `Frontier_dependencies ] * unit Truth.false_t
         , [ `Staged_ledger_diff ] * (unit, 'e) Truth.t
         , [ `Protocol_versions ] * (unit, 'f) Truth.t )
         Validation.with_transition
      -> consensus_constants:Consensus.Constants.t
      -> logger:Logger.t
      -> frontier:Transition_frontier.t
      -> ( ( [ `Time_received ] * (unit, 'a) Truth.t
           , [ `Genesis_state ] * (unit, 'b) Truth.t
           , [ `Proof ] * (unit, 'c) Truth.t
           , [ `Delta_transition_chain ]
             * (Mina_base.State_hash.t Non_empty_list.t, 'd) Truth.t
           , [ `Frontier_dependencies ] * unit Truth.true_t
           , [ `Staged_ledger_diff ] * (unit, 'e) Truth.t
           , [ `Protocol_versions ] * (unit, 'f) Truth.t )
           Validation.with_transition
         , [> `Already_in_frontier
           | `Not_selected_over_frontier_root
           | `Parent_missing_from_frontier ] )
         Core_kernel.Result.t
  end

  val skip_frontier_dependencies_validation :
       [ `This_transition_belongs_to_a_detached_subtree
       | `This_transition_was_loaded_from_persistence ]
    -> ( [ `Time_received ] * (unit, 'a) Truth.t
       , [ `Genesis_state ] * (unit, 'b) Truth.t
       , [ `Proof ] * (unit, 'c) Truth.t
       , [ `Delta_transition_chain ]
         * (Mina_base.State_hash.t Non_empty_list.t, 'd) Truth.t
       , [ `Frontier_dependencies ] * unit Truth.false_t
       , [ `Staged_ledger_diff ] * (unit, 'e) Truth.t
       , [ `Protocol_versions ] * (unit, 'f) Truth.t )
       Validation.with_transition
    -> ( [ `Time_received ] * (unit, 'a) Truth.t
       , [ `Genesis_state ] * (unit, 'b) Truth.t
       , [ `Proof ] * (unit, 'c) Truth.t
       , [ `Delta_transition_chain ]
         * (Mina_base.State_hash.t Non_empty_list.t, 'd) Truth.t
       , [ `Frontier_dependencies ] * unit Truth.true_t
       , [ `Staged_ledger_diff ] * (unit, 'e) Truth.t
       , [ `Protocol_versions ] * (unit, 'f) Truth.t )
       Validation.with_transition

  val validate_staged_ledger_hash :
       [ `Staged_ledger_already_materialized of Mina_base.Staged_ledger_hash.t ]
    -> ( [ `Time_received ] * (unit, 'a) Truth.t
       , [ `Genesis_state ] * (unit, 'b) Truth.t
       , [ `Proof ] * (unit, 'c) Truth.t
       , [ `Delta_transition_chain ]
         * (Mina_base.State_hash.t Non_empty_list.t, 'd) Truth.t
       , [ `Frontier_dependencies ] * (unit, 'e) Truth.t
       , [ `Staged_ledger_diff ] * unit Truth.false_t
       , [ `Protocol_versions ] * (unit, 'f) Truth.t )
       Validation.with_transition
    -> ( ( [ `Time_received ] * (unit, 'a) Truth.t
         , [ `Genesis_state ] * (unit, 'b) Truth.t
         , [ `Proof ] * (unit, 'c) Truth.t
         , [ `Delta_transition_chain ]
           * (Mina_base.State_hash.t Non_empty_list.t, 'd) Truth.t
         , [ `Frontier_dependencies ] * (unit, 'e) Truth.t
         , [ `Staged_ledger_diff ] * unit Truth.true_t
         , [ `Protocol_versions ] * (unit, 'f) Truth.t )
         Validation.with_transition
       , [> `Staged_ledger_hash_mismatch ] )
       Core_kernel.Result.t

  val skip_staged_ledger_diff_validation :
       [ `This_transition_has_a_trusted_staged_ledger ]
    -> ( [ `Time_received ] * (unit, 'a) Truth.t
       , [ `Genesis_state ] * (unit, 'b) Truth.t
       , [ `Proof ] * (unit, 'c) Truth.t
       , [ `Delta_transition_chain ]
         * (Mina_base.State_hash.t Non_empty_list.t, 'd) Truth.t
       , [ `Frontier_dependencies ] * (unit, 'e) Truth.t
       , [ `Staged_ledger_diff ] * unit Truth.false_t
       , [ `Protocol_versions ] * (unit, 'f) Truth.t )
       Validation.with_transition
    -> ( [ `Time_received ] * (unit, 'a) Truth.t
       , [ `Genesis_state ] * (unit, 'b) Truth.t
       , [ `Proof ] * (unit, 'c) Truth.t
       , [ `Delta_transition_chain ]
         * (Mina_base.State_hash.t Non_empty_list.t, 'd) Truth.t
       , [ `Frontier_dependencies ] * (unit, 'e) Truth.t
       , [ `Staged_ledger_diff ] * unit Truth.true_t
       , [ `Protocol_versions ] * (unit, 'f) Truth.t )
       Validation.with_transition

  val skip_protocol_versions_validation :
       [ `This_transition_has_valid_protocol_versions ]
    -> ( [ `Time_received ] * (unit, 'a) Truth.t
       , [ `Genesis_state ] * (unit, 'b) Truth.t
       , [ `Proof ] * (unit, 'c) Truth.t
       , [ `Delta_transition_chain ]
         * (Mina_base.State_hash.t Non_empty_list.t, 'd) Truth.t
       , [ `Frontier_dependencies ] * (unit, 'e) Truth.t
       , [ `Staged_ledger_diff ] * (unit, 'f) Truth.t
       , [ `Protocol_versions ] * unit Truth.false_t )
       Validation.with_transition
    -> ( [ `Time_received ] * (unit, 'a) Truth.t
       , [ `Genesis_state ] * (unit, 'b) Truth.t
       , [ `Proof ] * (unit, 'c) Truth.t
       , [ `Delta_transition_chain ]
         * (Mina_base.State_hash.t Non_empty_list.t, 'd) Truth.t
       , [ `Frontier_dependencies ] * (unit, 'e) Truth.t
       , [ `Staged_ledger_diff ] * (unit, 'f) Truth.t
       , [ `Protocol_versions ] * unit Truth.true_t )
       Validation.with_transition

  module Staged_ledger_validation : sig
    val validate_staged_ledger_diff :
         ?skip_staged_ledger_verification:[ `All | `Proofs ]
      -> ( [ `Time_received ] * (unit, 'a) Truth.t
         , [ `Genesis_state ] * (unit, 'b) Truth.t
         , [ `Proof ] * (unit, 'c) Truth.t
         , [ `Delta_transition_chain ]
           * (Mina_base.State_hash.t Non_empty_list.t, 'd) Truth.t
         , [ `Frontier_dependencies ] * (unit, 'e) Truth.t
         , [ `Staged_ledger_diff ] * unit Truth.false_t
         , [ `Protocol_versions ] * (unit, 'f) Truth.t )
         Validation.with_transition
      -> logger:Logger.t
      -> precomputed_values:Precomputed_values.t
      -> verifier:Verifier.t
      -> parent_staged_ledger:Staged_ledger.t
      -> parent_protocol_state:Mina_state.Protocol_state.value
      -> ( [ `Just_emitted_a_proof of bool ]
           * [ `External_transition_with_validation of
               ( [ `Time_received ] * (unit, 'a) Truth.t
               , [ `Genesis_state ] * (unit, 'b) Truth.t
               , [ `Proof ] * (unit, 'c) Truth.t
               , [ `Delta_transition_chain ]
                 * (Mina_base.State_hash.t Non_empty_list.t, 'd) Truth.t
               , [ `Frontier_dependencies ] * (unit, 'e) Truth.t
               , [ `Staged_ledger_diff ] * unit Truth.true_t
               , [ `Protocol_versions ] * (unit, 'f) Truth.t )
               Validation.with_transition ]
           * [ `Staged_ledger of Staged_ledger.t ]
         , [ `Invalid_staged_ledger_diff of
             [ `Incorrect_target_snarked_ledger_hash
             | `Incorrect_target_staged_ledger_hash ]
             list
           | `Staged_ledger_application_failed of
             Staged_ledger.Staged_ledger_error.t ] )
         Async_kernel.Deferred.Result.t
  end
end
