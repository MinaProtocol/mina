module Global_slot = Mina_numbers.Global_slot

type account_state = [ `Added | `Existed ]

val equal_account_state : account_state -> account_state -> bool

module type Ledger_intf = sig
  type t

  type location

  val get : t -> location -> Account.t option

  val location_of_account : t -> Account_id.t -> location option

  val set : t -> location -> Account.t -> unit

  val get_or_create :
       t
    -> Account_id.t
    -> (account_state * Account.t * location) Core_kernel.Or_error.t

  val get_or_create_account :
       t
    -> Account_id.t
    -> Account.t
    -> (account_state * location) Core_kernel.Or_error.t

  val remove_accounts_exn : t -> Account_id.t list -> unit

  val merkle_root : t -> Ledger_hash.t

  val with_ledger : depth:int -> f:(t -> 'a) -> 'a

  val next_available_token : t -> Token_id.t

  val set_next_available_token : t -> Token_id.t -> unit
end

module Transaction_applied : sig
  module UC = Signed_command

  module Signed_command_applied : sig
    module Common : sig
      module Stable : sig
        module V1 : sig
          type t =
            { user_command : Signed_command.Stable.V1.t With_status.Stable.V1.t
            ; previous_receipt_chain_hash : Receipt.Chain_hash.Stable.V1.t
            ; fee_payer_timing : Account.Timing.Stable.V1.t
            ; source_timing : Account.Timing.Stable.V1.t option
            }

          val version : int

          val __versioned__ : unit

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
            * (   Bin_prot.Common.buf
               -> pos_ref:Bin_prot.Common.pos_ref
               -> int
               -> t)
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
          ( int
          * (Core_kernel.Bigstring.t -> pos_ref:int Core_kernel.ref -> V1.t) )
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

      type t = Stable.V1.t =
        { user_command : Signed_command.t With_status.t
        ; previous_receipt_chain_hash : Receipt.Chain_hash.t
        ; fee_payer_timing : Account.Timing.t
        ; source_timing : Account.Timing.t option
        }

      val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

      val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t
    end

    module Body : sig
      module Stable : sig
        module V1 : sig
          type t =
            | Payment of
                { previous_empty_accounts : Account_id.Stable.V1.t list }
            | Stake_delegation of
                { previous_delegate :
                    Signature_lib.Public_key.Compressed.Stable.V1.t option
                }
            | Create_new_token of { created_token : Token_id.Stable.V1.t }
            | Create_token_account
            | Mint_tokens
            | Failed

          val version : int

          val __versioned__ : unit

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
            * (   Bin_prot.Common.buf
               -> pos_ref:Bin_prot.Common.pos_ref
               -> int
               -> t)
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
          ( int
          * (Core_kernel.Bigstring.t -> pos_ref:int Core_kernel.ref -> V1.t) )
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

      type t = Stable.V1.t =
        | Payment of { previous_empty_accounts : Account_id.t list }
        | Stake_delegation of
            { previous_delegate : Signature_lib.Public_key.Compressed.t option }
        | Create_new_token of { created_token : Token_id.t }
        | Create_token_account
        | Mint_tokens
        | Failed

      val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

      val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t
    end

    module Stable : sig
      module V1 : sig
        type t = { common : Common.t; body : Body.t }

        val version : int

        val __versioned__ : unit

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

    type t = Stable.V1.t = { common : Common.t; body : Body.t }

    val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

    val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t
  end

  module Snapp_command_applied : sig
    module Stable : sig
      module V1 : sig
        type t =
          { accounts :
              (Account_id.Stable.V1.t * Account.Stable.V1.t option) list
          ; command : Snapp_command.Stable.V1.t With_status.Stable.V1.t
          }

        val version : int

        val __versioned__ : unit

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

    type t = Stable.V1.t =
      { accounts : (Account_id.t * Account.t option) list
      ; command : Snapp_command.t With_status.t
      }

    val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

    val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t
  end

  module Command_applied : sig
    module Stable : sig
      module V1 : sig
        type t =
          | Signed_command of Signed_command_applied.t
          | Snapp_command of Snapp_command_applied.t

        val version : int

        val __versioned__ : unit

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

    type t = Stable.V1.t =
      | Signed_command of Signed_command_applied.t
      | Snapp_command of Snapp_command_applied.t

    val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

    val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t
  end

  module Fee_transfer_applied : sig
    module Stable : sig
      module V1 : sig
        type t =
          { fee_transfer : Fee_transfer.Stable.V1.t
          ; previous_empty_accounts : Account_id.Stable.V1.t list
          ; receiver_timing : Account.Timing.Stable.V1.t
          ; balances : Transaction_status.Fee_transfer_balance_data.Stable.V1.t
          }

        val version : int

        val __versioned__ : unit

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

    type t = Stable.V1.t =
      { fee_transfer : Fee_transfer.t
      ; previous_empty_accounts : Account_id.t list
      ; receiver_timing : Account.Timing.t
      ; balances : Transaction_status.Fee_transfer_balance_data.t
      }

    val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

    val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t
  end

  module Coinbase_applied : sig
    module Stable : sig
      module V1 : sig
        type t =
          { coinbase : Coinbase.Stable.V1.t
          ; previous_empty_accounts : Account_id.Stable.V1.t list
          ; receiver_timing : Account.Timing.Stable.V1.t
          ; balances : Transaction_status.Coinbase_balance_data.Stable.V1.t
          }

        val version : int

        val __versioned__ : unit

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

    type t = Stable.V1.t =
      { coinbase : Coinbase.t
      ; previous_empty_accounts : Account_id.t list
      ; receiver_timing : Account.Timing.t
      ; balances : Transaction_status.Coinbase_balance_data.t
      }

    val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

    val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t
  end

  module Varying : sig
    module Stable : sig
      module V1 : sig
        type t =
          | Command of Command_applied.t
          | Fee_transfer of Fee_transfer_applied.t
          | Coinbase of Coinbase_applied.t

        val version : int

        val __versioned__ : unit

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

    type t = Stable.V1.t =
      | Command of Command_applied.t
      | Fee_transfer of Fee_transfer_applied.t
      | Coinbase of Coinbase_applied.t

    val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

    val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t
  end

  module Stable : sig
    module V1 : sig
      type t = { previous_hash : Ledger_hash.Stable.V1.t; varying : Varying.t }

      val version : int

      val __versioned__ : unit

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

  type t = Stable.V1.t = { previous_hash : Ledger_hash.t; varying : Varying.t }

  val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

  val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t
end

module type S = sig
  type ledger

  module Transaction_applied : sig
    module Signed_command_applied : sig
      module Common : sig
        type t = Transaction_applied.Signed_command_applied.Common.t =
          { user_command : Signed_command.t With_status.t
          ; previous_receipt_chain_hash : Receipt.Chain_hash.t
          ; fee_payer_timing : Account.Timing.t
          ; source_timing : Account.Timing.t option
          }

        val t_of_sexp : Sexplib0.Sexp.t -> t

        val sexp_of_t : t -> Sexplib0.Sexp.t
      end

      module Body : sig
        type t = Transaction_applied.Signed_command_applied.Body.t =
          | Payment of { previous_empty_accounts : Account_id.t list }
          | Stake_delegation of
              { previous_delegate : Signature_lib.Public_key.Compressed.t option
              }
          | Create_new_token of { created_token : Token_id.t }
          | Create_token_account
          | Mint_tokens
          | Failed

        val t_of_sexp : Sexplib0.Sexp.t -> t

        val sexp_of_t : t -> Sexplib0.Sexp.t
      end

      type t = Transaction_applied.Signed_command_applied.t =
        { common : Common.t; body : Body.t }

      val t_of_sexp : Sexplib0.Sexp.t -> t

      val sexp_of_t : t -> Sexplib0.Sexp.t
    end

    module Snapp_command_applied : sig
      type t = Transaction_applied.Snapp_command_applied.t =
        { accounts : (Account_id.t * Account.t option) list
        ; command : Snapp_command.t With_status.t
        }

      val t_of_sexp : Sexplib0.Sexp.t -> t

      val sexp_of_t : t -> Sexplib0.Sexp.t
    end

    module Command_applied : sig
      type t = Transaction_applied.Command_applied.t =
        | Signed_command of Signed_command_applied.t
        | Snapp_command of Snapp_command_applied.t

      val t_of_sexp : Sexplib0.Sexp.t -> t

      val sexp_of_t : t -> Sexplib0.Sexp.t
    end

    module Fee_transfer_applied : sig
      type t = Transaction_applied.Fee_transfer_applied.t =
        { fee_transfer : Fee_transfer.t
        ; previous_empty_accounts : Account_id.t list
        ; receiver_timing : Account.Timing.t
        ; balances : Transaction_status.Fee_transfer_balance_data.t
        }

      val t_of_sexp : Sexplib0.Sexp.t -> t

      val sexp_of_t : t -> Sexplib0.Sexp.t
    end

    module Coinbase_applied : sig
      type t = Transaction_applied.Coinbase_applied.t =
        { coinbase : Coinbase.t
        ; previous_empty_accounts : Account_id.t list
        ; receiver_timing : Account.Timing.t
        ; balances : Transaction_status.Coinbase_balance_data.t
        }

      val t_of_sexp : Sexplib0.Sexp.t -> t

      val sexp_of_t : t -> Sexplib0.Sexp.t
    end

    module Varying : sig
      type t = Transaction_applied.Varying.t =
        | Command of Command_applied.t
        | Fee_transfer of Fee_transfer_applied.t
        | Coinbase of Coinbase_applied.t

      val t_of_sexp : Sexplib0.Sexp.t -> t

      val sexp_of_t : t -> Sexplib0.Sexp.t
    end

    type t = Transaction_applied.t =
      { previous_hash : Ledger_hash.t; varying : Varying.t }

    val t_of_sexp : Sexplib0.Sexp.t -> t

    val sexp_of_t : t -> Sexplib0.Sexp.t

    val transaction : t -> Transaction.t With_status.t

    val user_command_status : t -> Transaction_status.t
  end

  val apply_user_command :
       constraint_constants:Genesis_constants.Constraint_constants.t
    -> txn_global_slot:Mina_numbers.Global_slot.t
    -> ledger
    -> Signed_command.With_valid_signature.t
    -> Transaction_applied.Signed_command_applied.t Core_kernel.Or_error.t

  val apply_fee_transfer :
       constraint_constants:Genesis_constants.Constraint_constants.t
    -> txn_global_slot:Mina_numbers.Global_slot.t
    -> ledger
    -> Fee_transfer.t
    -> Transaction_applied.Fee_transfer_applied.t Core_kernel.Or_error.t

  val apply_coinbase :
       constraint_constants:Genesis_constants.Constraint_constants.t
    -> txn_global_slot:Mina_numbers.Global_slot.t
    -> ledger
    -> Coinbase.t
    -> Transaction_applied.Coinbase_applied.t Core_kernel.Or_error.t

  val apply_transaction :
       constraint_constants:Genesis_constants.Constraint_constants.t
    -> txn_state_view:Snapp_predicate.Protocol_state.View.t
    -> ledger
    -> Transaction.t
    -> Transaction_applied.t Core_kernel.Or_error.t

  val merkle_root_after_snapp_command_exn :
       constraint_constants:Genesis_constants.Constraint_constants.t
    -> txn_state_view:Snapp_predicate.Protocol_state.View.t
    -> ledger
    -> Snapp_command.Valid.t
    -> Ledger_hash.t * [ `Next_available_token of Token_id.t ]

  val merkle_root_after_user_command_exn :
       constraint_constants:Genesis_constants.Constraint_constants.t
    -> txn_global_slot:Mina_numbers.Global_slot.t
    -> ledger
    -> Signed_command.With_valid_signature.t
    -> Ledger_hash.t * [ `Next_available_token of Token_id.t ]

  val undo :
       constraint_constants:Genesis_constants.Constraint_constants.t
    -> ledger
    -> Transaction_applied.t
    -> unit Core_kernel.Or_error.t

  val has_locked_tokens :
       global_slot:Mina_numbers.Global_slot.t
    -> account_id:Account_id.t
    -> ledger
    -> bool Core_kernel.Or_error.t

  module For_tests : sig
    val validate_timing_with_min_balance :
         account:Account.t
      -> txn_amount:Currency.Amount.t
      -> txn_global_slot:Mina_numbers.Global_slot.t
      -> (Account.Timing.t * [> `Min_balance of Currency.Balance.t ])
         Core_kernel.Or_error.t

    val validate_timing :
         account:Account.t
      -> txn_amount:Currency.Amount.t
      -> txn_global_slot:Mina_numbers.Global_slot.t
      -> Account.Timing.t Core_kernel.Or_error.t
  end
end

val nsf_tag : string

val min_balance_tag : string

val timing_error_to_user_command_status :
  Base__Error.t -> Transaction_status.Failure.t

val validate_timing_with_min_balance :
     account:
       ( 'a
       , 'b
       , 'c
       , Currency.Balance.Stable.Latest.t
       , 'd
       , 'e
       , 'f
       , 'g
       , ( Mina_numbers.Global_slot.t
         , Currency.Balance.Stable.Latest.t
         , Currency.Amount.t )
         Account.Timing.Poly.t
       , 'h
       , 'i )
       Account.Poly.t
  -> txn_amount:Currency.Amount.Stable.Latest.t
  -> txn_global_slot:Mina_numbers.Global_slot.t
  -> ( ( Mina_numbers.Global_slot.t
       , Currency.Balance.Stable.Latest.t
       , Currency.Amount.t )
       Account.Timing.Poly.t
     * [> `Min_balance of Currency.Balance.Stable.Latest.t ] )
     Core_kernel.Or_error.t

val validate_timing :
     account:
       ( 'a
       , 'b
       , 'c
       , Currency.Balance.Stable.Latest.t
       , 'd
       , 'e
       , 'f
       , 'g
       , ( Mina_numbers.Global_slot.t
         , Currency.Balance.Stable.Latest.t
         , Currency.Amount.t )
         Account.Timing.Poly.t
       , 'h
       , 'i )
       Account.Poly.t
  -> txn_amount:Currency.Amount.Stable.Latest.t
  -> txn_global_slot:Mina_numbers.Global_slot.t
  -> ( ( Mina_numbers.Global_slot.t
       , Currency.Balance.Stable.Latest.t
       , Currency.Amount.t )
       Account.Timing.Poly.t
     , Core_kernel__.Error.t )
     Core_kernel__Result.t

module Make : functor (L : Ledger_intf) -> sig
  module Transaction_applied : sig
    module Signed_command_applied : sig
      module Common : sig
        type t = Transaction_applied.Signed_command_applied.Common.t =
          { user_command : Signed_command.t With_status.t
          ; previous_receipt_chain_hash : Receipt.Chain_hash.t
          ; fee_payer_timing : Account.Timing.t
          ; source_timing : Account.Timing.t option
          }

        val t_of_sexp : Sexplib0.Sexp.t -> t

        val sexp_of_t : t -> Sexplib0.Sexp.t
      end

      module Body : sig
        type t = Transaction_applied.Signed_command_applied.Body.t =
          | Payment of { previous_empty_accounts : Account_id.t list }
          | Stake_delegation of
              { previous_delegate : Signature_lib.Public_key.Compressed.t option
              }
          | Create_new_token of { created_token : Token_id.t }
          | Create_token_account
          | Mint_tokens
          | Failed

        val t_of_sexp : Sexplib0.Sexp.t -> t

        val sexp_of_t : t -> Sexplib0.Sexp.t
      end

      type t = Transaction_applied.Signed_command_applied.t =
        { common : Common.t; body : Body.t }

      val t_of_sexp : Sexplib0.Sexp.t -> t

      val sexp_of_t : t -> Sexplib0.Sexp.t
    end

    module Snapp_command_applied : sig
      type t = Transaction_applied.Snapp_command_applied.t =
        { accounts : (Account_id.t * Account.t option) list
        ; command : Snapp_command.t With_status.t
        }

      val t_of_sexp : Sexplib0.Sexp.t -> t

      val sexp_of_t : t -> Sexplib0.Sexp.t
    end

    module Command_applied : sig
      type t = Transaction_applied.Command_applied.t =
        | Signed_command of Signed_command_applied.t
        | Snapp_command of Snapp_command_applied.t

      val t_of_sexp : Sexplib0.Sexp.t -> t

      val sexp_of_t : t -> Sexplib0.Sexp.t
    end

    module Fee_transfer_applied : sig
      type t = Transaction_applied.Fee_transfer_applied.t =
        { fee_transfer : Fee_transfer.t
        ; previous_empty_accounts : Account_id.t list
        ; receiver_timing : Account.Timing.t
        ; balances : Transaction_status.Fee_transfer_balance_data.t
        }

      val t_of_sexp : Sexplib0.Sexp.t -> t

      val sexp_of_t : t -> Sexplib0.Sexp.t
    end

    module Coinbase_applied : sig
      type t = Transaction_applied.Coinbase_applied.t =
        { coinbase : Coinbase.t
        ; previous_empty_accounts : Account_id.t list
        ; receiver_timing : Account.Timing.t
        ; balances : Transaction_status.Coinbase_balance_data.t
        }

      val t_of_sexp : Sexplib0.Sexp.t -> t

      val sexp_of_t : t -> Sexplib0.Sexp.t
    end

    module Varying : sig
      type t = Transaction_applied.Varying.t =
        | Command of Command_applied.t
        | Fee_transfer of Fee_transfer_applied.t
        | Coinbase of Coinbase_applied.t

      val t_of_sexp : Sexplib0.Sexp.t -> t

      val sexp_of_t : t -> Sexplib0.Sexp.t
    end

    type t = Transaction_applied.t =
      { previous_hash : Ledger_hash.t; varying : Varying.t }

    val t_of_sexp : Sexplib0.Sexp.t -> t

    val sexp_of_t : t -> Sexplib0.Sexp.t

    val transaction : t -> Transaction.t With_status.t

    val user_command_status : t -> Transaction_status.t
  end

  val apply_user_command :
       constraint_constants:Genesis_constants.Constraint_constants.t
    -> txn_global_slot:Mina_numbers.Global_slot.t
    -> L.t
    -> Signed_command.With_valid_signature.t
    -> Transaction_applied.Signed_command_applied.t Core_kernel.Or_error.t

  val apply_fee_transfer :
       constraint_constants:Genesis_constants.Constraint_constants.t
    -> txn_global_slot:Mina_numbers.Global_slot.t
    -> L.t
    -> Fee_transfer.t
    -> Transaction_applied.Fee_transfer_applied.t Core_kernel.Or_error.t

  val apply_coinbase :
       constraint_constants:Genesis_constants.Constraint_constants.t
    -> txn_global_slot:Mina_numbers.Global_slot.t
    -> L.t
    -> Coinbase.t
    -> Transaction_applied.Coinbase_applied.t Core_kernel.Or_error.t

  val apply_transaction :
       constraint_constants:Genesis_constants.Constraint_constants.t
    -> txn_state_view:Snapp_predicate.Protocol_state.View.t
    -> L.t
    -> Transaction.t
    -> Transaction_applied.t Core_kernel.Or_error.t

  val merkle_root_after_snapp_command_exn :
       constraint_constants:Genesis_constants.Constraint_constants.t
    -> txn_state_view:Snapp_predicate.Protocol_state.View.t
    -> L.t
    -> Snapp_command.Valid.t
    -> Ledger_hash.t * [ `Next_available_token of Token_id.t ]

  val merkle_root_after_user_command_exn :
       constraint_constants:Genesis_constants.Constraint_constants.t
    -> txn_global_slot:Mina_numbers.Global_slot.t
    -> L.t
    -> Signed_command.With_valid_signature.t
    -> Ledger_hash.t * [ `Next_available_token of Token_id.t ]

  val undo :
       constraint_constants:Genesis_constants.Constraint_constants.t
    -> L.t
    -> Transaction_applied.t
    -> unit Core_kernel.Or_error.t

  val has_locked_tokens :
       global_slot:Mina_numbers.Global_slot.t
    -> account_id:Account_id.t
    -> L.t
    -> bool Core_kernel.Or_error.t

  module For_tests : sig
    val validate_timing_with_min_balance :
         account:Account.t
      -> txn_amount:Currency.Amount.t
      -> txn_global_slot:Mina_numbers.Global_slot.t
      -> (Account.Timing.t * [> `Min_balance of Currency.Balance.t ])
         Core_kernel.Or_error.t

    val validate_timing :
         account:Account.t
      -> txn_amount:Currency.Amount.t
      -> txn_global_slot:Mina_numbers.Global_slot.t
      -> Account.Timing.t Core_kernel.Or_error.t
  end
end
