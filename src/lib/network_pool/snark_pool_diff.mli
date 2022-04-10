module Work = Transaction_snark_work.Statement
module Ledger_proof = Ledger_proof
module Work_info = Transaction_snark_work.Info

module Rejected : sig
  module Stable : sig
    module V1 : sig
      type t = unit

      val to_yojson : t -> Yojson.Safe.t

      val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

      val version : int

      val __versioned__ : t

      val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

      val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

      val to_latest : 'a -> 'a

      module With_version : sig
        type typ = t

        val bin_shape_typ : Core_kernel.Bin_prot.Shape.t

        val bin_size_typ : typ Core_kernel.Bin_prot.Size.sizer

        val bin_write_typ : typ Core_kernel.Bin_prot.Write.writer

        val bin_writer_typ : typ Core_kernel.Bin_prot.Type_class.writer

        val __bin_read_typ__ : (int -> typ) Core_kernel.Bin_prot.Read.reader

        val bin_read_typ : typ Core_kernel.Bin_prot.Read.reader

        val bin_reader_typ : typ Core_kernel.Bin_prot.Type_class.reader

        val bin_typ : typ Core_kernel.Bin_prot.Type_class.t

        type t = { version : int; t : typ }

        val bin_shape_t : Core_kernel.Bin_prot.Shape.t

        val bin_size_t : t Core_kernel.Bin_prot.Size.sizer

        val bin_write_t : t Core_kernel.Bin_prot.Write.writer

        val bin_writer_t : t Core_kernel.Bin_prot.Type_class.writer

        val __bin_read_t__ : (int -> t) Core_kernel.Bin_prot.Read.reader

        val bin_read_t : t Core_kernel.Bin_prot.Read.reader

        val bin_reader_t : t Core_kernel.Bin_prot.Type_class.reader

        val bin_t : t Core_kernel.Bin_prot.Type_class.t

        val create : typ -> t
      end

      val bin_read_t :
        Bin_prot.Common.buf -> pos_ref:Bin_prot.Common.pos_ref -> t

      val __bin_read_t__ :
        Bin_prot.Common.buf -> pos_ref:Bin_prot.Common.pos_ref -> int -> t

      val bin_size_t : t -> int

      val bin_write_t :
           Bin_prot.Common.buf
        -> pos:Bin_prot.Common.pos
        -> t
        -> Bin_prot.Common.pos

      val bin_shape_t : Core_kernel.Bin_prot.Shape.t

      val bin_reader_t : t Core_kernel.Bin_prot.Type_class.reader

      val bin_writer_t : t Core_kernel.Bin_prot.Type_class.writer

      val bin_t : t Core_kernel.Bin_prot.Type_class.t

      val __ :
        (Bin_prot.Common.buf -> pos_ref:Bin_prot.Common.pos_ref -> t)
        * (Bin_prot.Common.buf -> pos_ref:Bin_prot.Common.pos_ref -> int -> t)
        * (t -> int)
        * (   Bin_prot.Common.buf
           -> pos:Bin_prot.Common.pos
           -> t
           -> Bin_prot.Common.pos)
        * Core_kernel.Bin_prot.Shape.t
        * t Core_kernel.Bin_prot.Type_class.reader
        * t Core_kernel.Bin_prot.Type_class.writer
        * t Core_kernel.Bin_prot.Type_class.t
    end

    module Latest = V1

    val versions :
      (int * (Core_kernel.Bigstring.t -> pos_ref:int Core_kernel.ref -> V1.t))
      array

    val bin_read_to_latest_opt :
         Bin_prot.Common.buf
      -> pos_ref:Bin_prot.Common.pos Core_kernel.ref
      -> V1.t option

    val __ :
         Bin_prot.Common.buf
      -> pos_ref:Bin_prot.Common.pos Core_kernel.ref
      -> V1.t option
  end

  type t = Stable.V1.t

  val to_yojson : t -> Yojson.Safe.t

  val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

  val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

  val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t
end

module Make : functor
  (Transition_frontier : Core_kernel.T)
  (Pool : sig
     type t

     val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

     val label : string

     type transition_frontier_diff

     module Config : sig
       type t

       val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t
     end

     val handle_transition_frontier_diff :
       transition_frontier_diff -> t -> Rejected.t Async_kernel.Deferred.t

     val create :
          constraint_constants:Genesis_constants.Constraint_constants.t
       -> consensus_constants:Consensus.Constants.t
       -> time_controller:Block_time.Controller.t
       -> frontier_broadcast_pipe:
            Transition_frontier.t Core_kernel.Option.t
            Pipe_lib.Broadcast_pipe.Reader.t
       -> config:Config.t
       -> logger:Logger.t
       -> tf_diff_writer:
            ( transition_frontier_diff
            , Pipe_lib.Strict_pipe.synchronous
            , Rejected.t Async_kernel.Deferred.t )
            Pipe_lib.Strict_pipe.Writer.t
       -> t

     val make_config :
          trust_system:Trust_system.t
       -> verifier:Verifier.t
       -> disk_location:string
       -> Config.t

     val add_snark :
          ?is_local:bool
       -> t
       -> work:Transaction_snark_work.Statement.t
       -> proof:Ledger_proof.t One_or_two.t
       -> fee:Mina_base.Fee_with_prover.t
       -> [ `Added | `Statement_not_referenced ] Async_kernel.Deferred.t

     val request_proof :
          t
       -> Transaction_snark_work.Statement.t
       -> Ledger_proof.t One_or_two.t Priced_proof.t option

     val verify_and_act :
          t
       -> work:
            Transaction_snark_work.Statement.t
            * Ledger_proof.t One_or_two.t Priced_proof.t
       -> sender:Network_peer.Envelope.Sender.t
       -> bool Async_kernel.Deferred.t

     val snark_pool_json : t -> Yojson.Safe.t

     val all_completed_work : t -> Transaction_snark_work.Info.t list

     val get_logger : t -> Logger.t
   end)
  -> sig
  type t =
    | Add_solved_work of
        Transaction_snark_work.Statement.t
        * Ledger_proof.t One_or_two.t Priced_proof.t
    | Empty

  val compare : t -> t -> int

  type verified = t

  val compare_verified : verified -> verified -> int

  type compact =
    { work : Transaction_snark_work.Statement.t
    ; fee : Currency.Fee.t
    ; prover : Signature_lib.Public_key.Compressed.t
    }

  val compact_to_yojson : compact -> Yojson.Safe.t

  val compact_of_yojson :
    Yojson.Safe.t -> compact Ppx_deriving_yojson_runtime.error_or

  val hash_fold_compact :
    Ppx_hash_lib.Std.Hash.state -> compact -> Ppx_hash_lib.Std.Hash.state

  val hash_compact : compact -> Ppx_hash_lib.Std.Hash.hash_value

  val to_yojson : verified -> Yojson.Safe.t

  val t_of_sexp : Sexplib0.Sexp.t -> verified

  val sexp_of_t : verified -> Sexplib0.Sexp.t

  val verified_to_yojson : verified -> Yojson.Safe.t

  val sexp_of_verified : verified -> Ppx_sexp_conv_lib.Sexp.t

  val verified_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> verified

  type rejected

  val rejected_to_yojson : rejected -> Yojson.Safe.t

  val sexp_of_rejected : rejected -> Ppx_sexp_conv_lib.Sexp.t

  val rejected_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> rejected

  val empty : verified

  val reject_overloaded_diff : verified -> rejected

  val size : verified -> int

  val verified_size : verified -> int

  val score : verified -> int

  val max_per_15_seconds : int

  val summary : verified -> string

  val verify :
       Pool.t
    -> verified Network_peer.Envelope.Incoming.t
    -> verified Network_peer.Envelope.Incoming.t
       Async_kernel.Deferred.Or_error.t

  val unsafe_apply :
       Pool.t
    -> verified Network_peer.Envelope.Incoming.t
    -> ( verified * rejected
       , [ `Locally_generated of verified * rejected
         | `Other of Core_kernel.Error.t ] )
       Core_kernel.Result.t
       Async_kernel.Deferred.t

  val is_empty : verified -> bool

  val to_compact : verified -> compact option

  val compact_json : verified -> Yojson.Safe.t option

  val of_result :
       ( ('a, 'b, 'c) Snark_work_lib.Work.Single.Spec.t
         Snark_work_lib.Work.Spec.t
       , Ledger_proof.t )
       Snark_work_lib.Work.Result.t
    -> verified
end
