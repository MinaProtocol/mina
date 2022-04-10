val validate_int16 :
  Core_kernel__Int.t -> (Core_kernel__Int.t, Core_kernel__.Error.t) Core._result

val int16 : Core_kernel__Int.t Core.Command.Arg_type.t

val public_key_compressed :
  Signature_lib.Public_key.Compressed.t Core.Command.Arg_type.t

val public_key : Signature_lib.Public_key.t Core.Command.Arg_type.t
  [@@deprecated "Use public_key_compressed in commandline args"]

val token_id : Mina_base.Token_id.t Core.Command.Arg_type.t

val receipt_chain_hash : Mina_base.Receipt.Chain_hash.t Core.Command.Arg_type.t

val peer : Core.Host_and_port.t Core.Command.Arg_type.t

val global_slot : Mina_numbers.Global_slot.t Core.Command.Arg_type.t

val txn_fee : Currency.Fee.Stable.Latest.t Core.Command.Arg_type.t

val txn_amount : Currency.Amount.Stable.Latest.t Core.Command.Arg_type.t

val txn_nonce : Mina_base.Account.Nonce.t Core.Command.Arg_type.t

val hd_index : Mina_numbers.Hd_index.t Core.Command.Arg_type.t

val ip_address : Core.Unix.Inet_addr.t Core.Command.Arg_type.t

val cidr_mask : Core.Unix.Cidr.t Core.Command.Arg_type.t

val log_level : Logger.Level.t Core.Command.Arg_type.t

val user_command : Mina_base.Signed_command.t Core.Command.Arg_type.t

module Work_selection_method : sig
  module Stable : sig
    module V1 : sig
      type t = Sequence | Random

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

  type t = Stable.V1.t = Sequence | Random
end

val work_selection_method_val : string -> Work_selection_method.t

val work_selection_method : Work_selection_method.t Core.Command.Arg_type.t

val work_selection_method_to_module :
  Work_selection_method.t -> (module Work_selector.Selection_method_intf)
