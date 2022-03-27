module Stable : sig
  module V1 : sig
    type t =
      { delegator : Mina_base.Account.Index.Stable.V1.t
      ; delegator_pk : Signature_lib.Public_key.Compressed.Stable.V1.t
      ; coinbase_receiver_pk : Signature_lib.Public_key.Compressed.Stable.V1.t
      ; ledger : Mina_base.Sparse_ledger.Stable.V1.t
      ; producer_private_key : Signature_lib.Private_key.Stable.V1.t
      ; producer_public_key : Signature_lib.Public_key.Stable.V1.t
      }

    val version : int

    val __versioned__ : unit

    val to_latest : 'a -> 'a

    module With_version : sig
      type typ = t

      val bin_shape_typ : Core.Bin_prot.Shape.t

      val bin_size_typ : typ Core.Bin_prot.Size.sizer

      val bin_write_typ : typ Core.Bin_prot.Write.writer

      val bin_writer_typ : typ Core.Bin_prot.Type_class.writer

      val __bin_read_typ__ : (int -> typ) Core.Bin_prot.Read.reader

      val bin_read_typ : typ Core.Bin_prot.Read.reader

      val bin_reader_typ : typ Core.Bin_prot.Type_class.reader

      val bin_typ : typ Core.Bin_prot.Type_class.t

      type t = { version : int; t : typ }

      val bin_shape_t : Core.Bin_prot.Shape.t

      val bin_size_t : t Core.Bin_prot.Size.sizer

      val bin_write_t : t Core.Bin_prot.Write.writer

      val bin_writer_t : t Core.Bin_prot.Type_class.writer

      val __bin_read_t__ : (int -> t) Core.Bin_prot.Read.reader

      val bin_read_t : t Core.Bin_prot.Read.reader

      val bin_reader_t : t Core.Bin_prot.Type_class.reader

      val bin_t : t Core.Bin_prot.Type_class.t

      val create : typ -> t
    end

    val bin_read_t : Bin_prot.Common.buf -> pos_ref:Bin_prot.Common.pos_ref -> t

    val __bin_read_t__ :
      Bin_prot.Common.buf -> pos_ref:Bin_prot.Common.pos_ref -> int -> t

    val bin_size_t : t -> int

    val bin_write_t :
      Bin_prot.Common.buf -> pos:Bin_prot.Common.pos -> t -> Bin_prot.Common.pos

    val bin_shape_t : Core.Bin_prot.Shape.t

    val bin_reader_t : t Core.Bin_prot.Type_class.reader

    val bin_writer_t : t Core.Bin_prot.Type_class.writer

    val bin_t : t Core.Bin_prot.Type_class.t

    val __ :
      (Bin_prot.Common.buf -> pos_ref:Bin_prot.Common.pos_ref -> t)
      * (Bin_prot.Common.buf -> pos_ref:Bin_prot.Common.pos_ref -> int -> t)
      * (t -> int)
      * (   Bin_prot.Common.buf
         -> pos:Bin_prot.Common.pos
         -> t
         -> Bin_prot.Common.pos)
      * Core.Bin_prot.Shape.t
      * t Core.Bin_prot.Type_class.reader
      * t Core.Bin_prot.Type_class.writer
      * t Core.Bin_prot.Type_class.t
  end

  module Latest = V1

  val versions :
    (int * (Core_kernel.Bigstring.t -> pos_ref:int Core.ref -> V1.t)) array

  val bin_read_to_latest_opt :
       Bin_prot.Common.buf
    -> pos_ref:Bin_prot.Common.pos Core_kernel.ref
    -> V1.t option

  val __ :
       Bin_prot.Common.buf
    -> pos_ref:Bin_prot.Common.pos Core_kernel.ref
    -> V1.t option
end

type t = Stable.V1.t =
  { delegator : Mina_base.Account.Index.t
  ; delegator_pk : Signature_lib.Public_key.Compressed.t
  ; coinbase_receiver_pk : Signature_lib.Public_key.Compressed.t
  ; ledger : Mina_base.Sparse_ledger.t
  ; producer_private_key : Signature_lib.Private_key.t
  ; producer_public_key : Signature_lib.Public_key.t
  }

val to_yojson : t -> Yojson.Safe.t

val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t
