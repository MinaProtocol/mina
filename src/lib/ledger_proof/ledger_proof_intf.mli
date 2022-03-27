module type S = sig
  type t

  val to_yojson : t -> Yojson.Safe.t

  val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

  val compare : t -> t -> int

  val equal : t -> t -> bool

  val t_of_sexp : Sexplib0.Sexp.t -> t

  val sexp_of_t : t -> Sexplib0.Sexp.t

  val hash_fold_t :
    Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

  val hash : t -> Ppx_hash_lib.Std.Hash.hash_value

  module Stable : sig
    module V1 : sig
      type nonrec t = t

      val to_yojson : t -> Yojson.Safe.t

      val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

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

      val hash_fold_t :
        Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

      val hash : t -> Ppx_hash_lib.Std.Hash.hash_value

      val to_latest : t -> t

      val of_latest : t -> (t, 'a) Core_kernel.Result.t
    end

    module Latest = V1

    val versions :
      (int * (Core_kernel.Bigstring.t -> pos_ref:int Core_kernel.ref -> t))
      array

    val bin_read_to_latest_opt :
      Core_kernel.Bin_prot.Common.buf -> pos_ref:int Core_kernel.ref -> t option
  end

  val create :
       statement:Transaction_snark.Statement.t
    -> sok_digest:Mina_base.Sok_message.Digest.t
    -> proof:Mina_base.Proof.t
    -> t

  val statement_target :
    Transaction_snark.Statement.t -> Mina_base.Frozen_ledger_hash.t

  val statement : t -> Transaction_snark.Statement.t

  val sok_digest : t -> Mina_base.Sok_message.Digest.t

  val underlying_proof : t -> Mina_base.Proof.t
end
