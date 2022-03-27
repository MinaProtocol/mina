module Impl = Pickles.Impls.Step

module Payload : sig
  module Poly : sig
    module Stable : sig
      module V1 : sig
        type ('pk, 'token_id, 'nonce, 'fee) t =
          { pk : 'pk; token_id : 'token_id; nonce : 'nonce; fee : 'fee }

        val to_yojson :
             ('pk -> Yojson.Safe.t)
          -> ('token_id -> Yojson.Safe.t)
          -> ('nonce -> Yojson.Safe.t)
          -> ('fee -> Yojson.Safe.t)
          -> ('pk, 'token_id, 'nonce, 'fee) t
          -> Yojson.Safe.t

        val of_yojson :
             (Yojson.Safe.t -> 'pk Ppx_deriving_yojson_runtime.error_or)
          -> (Yojson.Safe.t -> 'token_id Ppx_deriving_yojson_runtime.error_or)
          -> (Yojson.Safe.t -> 'nonce Ppx_deriving_yojson_runtime.error_or)
          -> (Yojson.Safe.t -> 'fee Ppx_deriving_yojson_runtime.error_or)
          -> Yojson.Safe.t
          -> ('pk, 'token_id, 'nonce, 'fee) t
             Ppx_deriving_yojson_runtime.error_or

        val version : int

        val __versioned__ : unit

        val to_hlist :
             ('pk, 'token_id, 'nonce, 'fee) t
          -> (unit, 'pk -> 'token_id -> 'nonce -> 'fee -> unit) H_list.t

        val of_hlist :
             (unit, 'pk -> 'token_id -> 'nonce -> 'fee -> unit) H_list.t
          -> ('pk, 'token_id, 'nonce, 'fee) t

        val t_of_sexp :
             (Ppx_sexp_conv_lib.Sexp.t -> 'pk)
          -> (Ppx_sexp_conv_lib.Sexp.t -> 'token_id)
          -> (Ppx_sexp_conv_lib.Sexp.t -> 'nonce)
          -> (Ppx_sexp_conv_lib.Sexp.t -> 'fee)
          -> Ppx_sexp_conv_lib.Sexp.t
          -> ('pk, 'token_id, 'nonce, 'fee) t

        val sexp_of_t :
             ('pk -> Ppx_sexp_conv_lib.Sexp.t)
          -> ('token_id -> Ppx_sexp_conv_lib.Sexp.t)
          -> ('nonce -> Ppx_sexp_conv_lib.Sexp.t)
          -> ('fee -> Ppx_sexp_conv_lib.Sexp.t)
          -> ('pk, 'token_id, 'nonce, 'fee) t
          -> Ppx_sexp_conv_lib.Sexp.t

        val equal :
             ('pk -> 'pk -> bool)
          -> ('token_id -> 'token_id -> bool)
          -> ('nonce -> 'nonce -> bool)
          -> ('fee -> 'fee -> bool)
          -> ('pk, 'token_id, 'nonce, 'fee) t
          -> ('pk, 'token_id, 'nonce, 'fee) t
          -> bool

        val hash_fold_t :
             (Ppx_hash_lib.Std.Hash.state -> 'pk -> Ppx_hash_lib.Std.Hash.state)
          -> (   Ppx_hash_lib.Std.Hash.state
              -> 'token_id
              -> Ppx_hash_lib.Std.Hash.state)
          -> (   Ppx_hash_lib.Std.Hash.state
              -> 'nonce
              -> Ppx_hash_lib.Std.Hash.state)
          -> (   Ppx_hash_lib.Std.Hash.state
              -> 'fee
              -> Ppx_hash_lib.Std.Hash.state)
          -> Ppx_hash_lib.Std.Hash.state
          -> ('pk, 'token_id, 'nonce, 'fee) t
          -> Ppx_hash_lib.Std.Hash.state

        val compare :
             ('pk -> 'pk -> int)
          -> ('token_id -> 'token_id -> int)
          -> ('nonce -> 'nonce -> int)
          -> ('fee -> 'fee -> int)
          -> ('pk, 'token_id, 'nonce, 'fee) t
          -> ('pk, 'token_id, 'nonce, 'fee) t
          -> int

        module With_version : sig
          type ('pk, 'token_id, 'nonce, 'fee) typ =
            ('pk, 'token_id, 'nonce, 'fee) t

          val bin_shape_typ :
               Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t

          val bin_size_typ :
               'pk Core_kernel.Bin_prot.Size.sizer
            -> 'token_id Core_kernel.Bin_prot.Size.sizer
            -> 'nonce Core_kernel.Bin_prot.Size.sizer
            -> 'fee Core_kernel.Bin_prot.Size.sizer
            -> ('pk, 'token_id, 'nonce, 'fee) typ
               Core_kernel.Bin_prot.Size.sizer

          val bin_write_typ :
               'pk Core_kernel.Bin_prot.Write.writer
            -> 'token_id Core_kernel.Bin_prot.Write.writer
            -> 'nonce Core_kernel.Bin_prot.Write.writer
            -> 'fee Core_kernel.Bin_prot.Write.writer
            -> ('pk, 'token_id, 'nonce, 'fee) typ
               Core_kernel.Bin_prot.Write.writer

          val bin_writer_typ :
               'a Core_kernel.Bin_prot.Type_class.writer
            -> 'b Core_kernel.Bin_prot.Type_class.writer
            -> 'c Core_kernel.Bin_prot.Type_class.writer
            -> 'd Core_kernel.Bin_prot.Type_class.writer
            -> ('a, 'b, 'c, 'd) typ Core_kernel.Bin_prot.Type_class.writer

          val __bin_read_typ__ :
               'pk Core_kernel.Bin_prot.Read.reader
            -> 'token_id Core_kernel.Bin_prot.Read.reader
            -> 'nonce Core_kernel.Bin_prot.Read.reader
            -> 'fee Core_kernel.Bin_prot.Read.reader
            -> (int -> ('pk, 'token_id, 'nonce, 'fee) typ)
               Core_kernel.Bin_prot.Read.reader

          val bin_read_typ :
               'pk Core_kernel.Bin_prot.Read.reader
            -> 'token_id Core_kernel.Bin_prot.Read.reader
            -> 'nonce Core_kernel.Bin_prot.Read.reader
            -> 'fee Core_kernel.Bin_prot.Read.reader
            -> ('pk, 'token_id, 'nonce, 'fee) typ
               Core_kernel.Bin_prot.Read.reader

          val bin_reader_typ :
               'a Core_kernel.Bin_prot.Type_class.reader
            -> 'b Core_kernel.Bin_prot.Type_class.reader
            -> 'c Core_kernel.Bin_prot.Type_class.reader
            -> 'd Core_kernel.Bin_prot.Type_class.reader
            -> ('a, 'b, 'c, 'd) typ Core_kernel.Bin_prot.Type_class.reader

          val bin_typ :
               'a Core_kernel.Bin_prot.Type_class.t
            -> 'b Core_kernel.Bin_prot.Type_class.t
            -> 'c Core_kernel.Bin_prot.Type_class.t
            -> 'd Core_kernel.Bin_prot.Type_class.t
            -> ('a, 'b, 'c, 'd) typ Core_kernel.Bin_prot.Type_class.t

          type ('pk, 'token_id, 'nonce, 'fee) t =
            { version : int; t : ('pk, 'token_id, 'nonce, 'fee) typ }

          val bin_shape_t :
               Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t

          val bin_size_t :
               'pk Core_kernel.Bin_prot.Size.sizer
            -> 'token_id Core_kernel.Bin_prot.Size.sizer
            -> 'nonce Core_kernel.Bin_prot.Size.sizer
            -> 'fee Core_kernel.Bin_prot.Size.sizer
            -> ('pk, 'token_id, 'nonce, 'fee) t Core_kernel.Bin_prot.Size.sizer

          val bin_write_t :
               'pk Core_kernel.Bin_prot.Write.writer
            -> 'token_id Core_kernel.Bin_prot.Write.writer
            -> 'nonce Core_kernel.Bin_prot.Write.writer
            -> 'fee Core_kernel.Bin_prot.Write.writer
            -> ('pk, 'token_id, 'nonce, 'fee) t
               Core_kernel.Bin_prot.Write.writer

          val bin_writer_t :
               'a Core_kernel.Bin_prot.Type_class.writer
            -> 'b Core_kernel.Bin_prot.Type_class.writer
            -> 'c Core_kernel.Bin_prot.Type_class.writer
            -> 'd Core_kernel.Bin_prot.Type_class.writer
            -> ('a, 'b, 'c, 'd) t Core_kernel.Bin_prot.Type_class.writer

          val __bin_read_t__ :
               'pk Core_kernel.Bin_prot.Read.reader
            -> 'token_id Core_kernel.Bin_prot.Read.reader
            -> 'nonce Core_kernel.Bin_prot.Read.reader
            -> 'fee Core_kernel.Bin_prot.Read.reader
            -> (int -> ('pk, 'token_id, 'nonce, 'fee) t)
               Core_kernel.Bin_prot.Read.reader

          val bin_read_t :
               'pk Core_kernel.Bin_prot.Read.reader
            -> 'token_id Core_kernel.Bin_prot.Read.reader
            -> 'nonce Core_kernel.Bin_prot.Read.reader
            -> 'fee Core_kernel.Bin_prot.Read.reader
            -> ('pk, 'token_id, 'nonce, 'fee) t Core_kernel.Bin_prot.Read.reader

          val bin_reader_t :
               'a Core_kernel.Bin_prot.Type_class.reader
            -> 'b Core_kernel.Bin_prot.Type_class.reader
            -> 'c Core_kernel.Bin_prot.Type_class.reader
            -> 'd Core_kernel.Bin_prot.Type_class.reader
            -> ('a, 'b, 'c, 'd) t Core_kernel.Bin_prot.Type_class.reader

          val bin_t :
               'a Core_kernel.Bin_prot.Type_class.t
            -> 'b Core_kernel.Bin_prot.Type_class.t
            -> 'c Core_kernel.Bin_prot.Type_class.t
            -> 'd Core_kernel.Bin_prot.Type_class.t
            -> ('a, 'b, 'c, 'd) t Core_kernel.Bin_prot.Type_class.t

          val create : ('a, 'b, 'c, 'd) typ -> ('a, 'b, 'c, 'd) t
        end

        val bin_read_t :
             'a Core_kernel.Bin_prot.Read.reader
          -> 'b Core_kernel.Bin_prot.Read.reader
          -> 'c Core_kernel.Bin_prot.Read.reader
          -> 'd Core_kernel.Bin_prot.Read.reader
          -> Bin_prot.Common.buf
          -> pos_ref:Bin_prot.Common.pos_ref
          -> ('a, 'b, 'c, 'd) t

        val __bin_read_t__ :
             'a Core_kernel.Bin_prot.Read.reader
          -> 'b Core_kernel.Bin_prot.Read.reader
          -> 'c Core_kernel.Bin_prot.Read.reader
          -> 'd Core_kernel.Bin_prot.Read.reader
          -> Bin_prot.Common.buf
          -> pos_ref:Bin_prot.Common.pos_ref
          -> int
          -> ('a, 'b, 'c, 'd) t

        val bin_size_t :
             'a Core_kernel.Bin_prot.Size.sizer
          -> 'b Core_kernel.Bin_prot.Size.sizer
          -> 'c Core_kernel.Bin_prot.Size.sizer
          -> 'd Core_kernel.Bin_prot.Size.sizer
          -> ('a, 'b, 'c, 'd) t
          -> int

        val bin_write_t :
             'a Core_kernel.Bin_prot.Write.writer
          -> 'b Core_kernel.Bin_prot.Write.writer
          -> 'c Core_kernel.Bin_prot.Write.writer
          -> 'd Core_kernel.Bin_prot.Write.writer
          -> Bin_prot.Common.buf
          -> pos:Bin_prot.Common.pos
          -> ('a, 'b, 'c, 'd) t
          -> Bin_prot.Common.pos

        val bin_shape_t :
             Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t

        val bin_reader_t :
             'a Core_kernel.Bin_prot.Type_class.reader
          -> 'b Core_kernel.Bin_prot.Type_class.reader
          -> 'c Core_kernel.Bin_prot.Type_class.reader
          -> 'd Core_kernel.Bin_prot.Type_class.reader
          -> ('a, 'b, 'c, 'd) t Core_kernel.Bin_prot.Type_class.reader

        val bin_writer_t :
             'a Core_kernel.Bin_prot.Type_class.writer
          -> 'b Core_kernel.Bin_prot.Type_class.writer
          -> 'c Core_kernel.Bin_prot.Type_class.writer
          -> 'd Core_kernel.Bin_prot.Type_class.writer
          -> ('a, 'b, 'c, 'd) t Core_kernel.Bin_prot.Type_class.writer

        val bin_t :
             'a Core_kernel.Bin_prot.Type_class.t
          -> 'b Core_kernel.Bin_prot.Type_class.t
          -> 'c Core_kernel.Bin_prot.Type_class.t
          -> 'd Core_kernel.Bin_prot.Type_class.t
          -> ('a, 'b, 'c, 'd) t Core_kernel.Bin_prot.Type_class.t

        val __ :
          (   'a Core_kernel.Bin_prot.Read.reader
           -> 'b Core_kernel.Bin_prot.Read.reader
           -> 'c Core_kernel.Bin_prot.Read.reader
           -> 'd Core_kernel.Bin_prot.Read.reader
           -> Bin_prot.Common.buf
           -> pos_ref:Bin_prot.Common.pos_ref
           -> ('a, 'b, 'c, 'd) t)
          * (   'e Core_kernel.Bin_prot.Read.reader
             -> 'f Core_kernel.Bin_prot.Read.reader
             -> 'g Core_kernel.Bin_prot.Read.reader
             -> 'h Core_kernel.Bin_prot.Read.reader
             -> Bin_prot.Common.buf
             -> pos_ref:Bin_prot.Common.pos_ref
             -> int
             -> ('e, 'f, 'g, 'h) t)
          * (   'i Core_kernel.Bin_prot.Size.sizer
             -> 'j Core_kernel.Bin_prot.Size.sizer
             -> 'k Core_kernel.Bin_prot.Size.sizer
             -> 'l Core_kernel.Bin_prot.Size.sizer
             -> ('i, 'j, 'k, 'l) t
             -> int)
          * (   'm Core_kernel.Bin_prot.Write.writer
             -> 'n Core_kernel.Bin_prot.Write.writer
             -> 'o Core_kernel.Bin_prot.Write.writer
             -> 'p Core_kernel.Bin_prot.Write.writer
             -> Bin_prot.Common.buf
             -> pos:Bin_prot.Common.pos
             -> ('m, 'n, 'o, 'p) t
             -> Bin_prot.Common.pos)
          * (   Core_kernel.Bin_prot.Shape.t
             -> Core_kernel.Bin_prot.Shape.t
             -> Core_kernel.Bin_prot.Shape.t
             -> Core_kernel.Bin_prot.Shape.t
             -> Core_kernel.Bin_prot.Shape.t)
          * (   'q Core_kernel.Bin_prot.Type_class.reader
             -> 'r Core_kernel.Bin_prot.Type_class.reader
             -> 's Core_kernel.Bin_prot.Type_class.reader
             -> 't Core_kernel.Bin_prot.Type_class.reader
             -> ('q, 'r, 's, 't) t Core_kernel.Bin_prot.Type_class.reader)
          * (   'u Core_kernel.Bin_prot.Type_class.writer
             -> 'v Core_kernel.Bin_prot.Type_class.writer
             -> 'w Core_kernel.Bin_prot.Type_class.writer
             -> 'x Core_kernel.Bin_prot.Type_class.writer
             -> ('u, 'v, 'w, 'x) t Core_kernel.Bin_prot.Type_class.writer)
          * (   'y Core_kernel.Bin_prot.Type_class.t
             -> 'z Core_kernel.Bin_prot.Type_class.t
             -> 'a1 Core_kernel.Bin_prot.Type_class.t
             -> 'b1 Core_kernel.Bin_prot.Type_class.t
             -> ('y, 'z, 'a1, 'b1) t Core_kernel.Bin_prot.Type_class.t)
      end

      module Latest = V1
    end

    type ('pk, 'token_id, 'nonce, 'fee) t =
          ('pk, 'token_id, 'nonce, 'fee) Stable.V1.t =
      { pk : 'pk; token_id : 'token_id; nonce : 'nonce; fee : 'fee }

    val to_yojson :
         ('pk -> Yojson.Safe.t)
      -> ('token_id -> Yojson.Safe.t)
      -> ('nonce -> Yojson.Safe.t)
      -> ('fee -> Yojson.Safe.t)
      -> ('pk, 'token_id, 'nonce, 'fee) t
      -> Yojson.Safe.t

    val of_yojson :
         (Yojson.Safe.t -> 'pk Ppx_deriving_yojson_runtime.error_or)
      -> (Yojson.Safe.t -> 'token_id Ppx_deriving_yojson_runtime.error_or)
      -> (Yojson.Safe.t -> 'nonce Ppx_deriving_yojson_runtime.error_or)
      -> (Yojson.Safe.t -> 'fee Ppx_deriving_yojson_runtime.error_or)
      -> Yojson.Safe.t
      -> ('pk, 'token_id, 'nonce, 'fee) t Ppx_deriving_yojson_runtime.error_or

    val to_hlist :
         ('pk, 'token_id, 'nonce, 'fee) t
      -> (unit, 'pk -> 'token_id -> 'nonce -> 'fee -> unit) H_list.t

    val of_hlist :
         (unit, 'pk -> 'token_id -> 'nonce -> 'fee -> unit) H_list.t
      -> ('pk, 'token_id, 'nonce, 'fee) t

    val t_of_sexp :
         (Ppx_sexp_conv_lib.Sexp.t -> 'pk)
      -> (Ppx_sexp_conv_lib.Sexp.t -> 'token_id)
      -> (Ppx_sexp_conv_lib.Sexp.t -> 'nonce)
      -> (Ppx_sexp_conv_lib.Sexp.t -> 'fee)
      -> Ppx_sexp_conv_lib.Sexp.t
      -> ('pk, 'token_id, 'nonce, 'fee) t

    val sexp_of_t :
         ('pk -> Ppx_sexp_conv_lib.Sexp.t)
      -> ('token_id -> Ppx_sexp_conv_lib.Sexp.t)
      -> ('nonce -> Ppx_sexp_conv_lib.Sexp.t)
      -> ('fee -> Ppx_sexp_conv_lib.Sexp.t)
      -> ('pk, 'token_id, 'nonce, 'fee) t
      -> Ppx_sexp_conv_lib.Sexp.t

    val equal :
         ('pk -> 'pk -> bool)
      -> ('token_id -> 'token_id -> bool)
      -> ('nonce -> 'nonce -> bool)
      -> ('fee -> 'fee -> bool)
      -> ('pk, 'token_id, 'nonce, 'fee) t
      -> ('pk, 'token_id, 'nonce, 'fee) t
      -> bool

    val hash_fold_t :
         (Ppx_hash_lib.Std.Hash.state -> 'pk -> Ppx_hash_lib.Std.Hash.state)
      -> (   Ppx_hash_lib.Std.Hash.state
          -> 'token_id
          -> Ppx_hash_lib.Std.Hash.state)
      -> (Ppx_hash_lib.Std.Hash.state -> 'nonce -> Ppx_hash_lib.Std.Hash.state)
      -> (Ppx_hash_lib.Std.Hash.state -> 'fee -> Ppx_hash_lib.Std.Hash.state)
      -> Ppx_hash_lib.Std.Hash.state
      -> ('pk, 'token_id, 'nonce, 'fee) t
      -> Ppx_hash_lib.Std.Hash.state

    val compare :
         ('pk -> 'pk -> int)
      -> ('token_id -> 'token_id -> int)
      -> ('nonce -> 'nonce -> int)
      -> ('fee -> 'fee -> int)
      -> ('pk, 'token_id, 'nonce, 'fee) t
      -> ('pk, 'token_id, 'nonce, 'fee) t
      -> int
  end

  module Stable : sig
    module V1 : sig
      type t =
        ( Signature_lib.Public_key.Compressed.Stable.V1.t
        , Token_id.Stable.V1.t
        , Mina_numbers.Account_nonce.Stable.V1.t
        , Currency.Fee.Stable.V1.t )
        Poly.t

      val to_yojson : t -> Yojson.Safe.t

      val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

      val version : int

      val __versioned__ : unit

      val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

      val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

      val equal : t -> t -> bool

      val hash_fold_t :
        Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

      val hash : t -> Ppx_hash_lib.Std.Hash.hash_value

      val compare : t -> t -> int

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
      ( int
      * (Core_kernel.Bigstring.t -> pos_ref:int Core_kernel.ref -> Latest.t) )
      array

    val bin_read_to_latest_opt :
         Bin_prot.Common.buf
      -> pos_ref:Bin_prot.Common.pos Core_kernel.ref
      -> Latest.t option

    val __ :
         Bin_prot.Common.buf
      -> pos_ref:Bin_prot.Common.pos Core_kernel.ref
      -> Latest.t option
  end

  type t = Stable.Latest.t

  val to_yojson : t -> Yojson.Safe.t

  val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

  val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

  val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

  val equal : t -> t -> bool

  val hash_fold_t :
    Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

  val hash : t -> Ppx_hash_lib.Std.Hash.hash_value

  val compare : t -> t -> int

  module Checked : sig
    type t =
      ( Signature_lib.Public_key.Compressed.var
      , Token_id.Checked.t
      , Mina_numbers.Account_nonce.Checked.t
      , Currency.Fee.Checked.t )
      Poly.t

    val to_input :
         t
      -> ( Snark_params.Tick.Field.Var.t
         , Snark_params.Tick.Boolean.var )
         Random_oracle.Input.t
  end

  val typ : (Checked.t, t) Pickles.Impls.Step.Typ.t

  val dummy : t

  val to_input : t -> (Snark_params.Tick.Field.t, bool) Random_oracle.Input.t
end

module Stable : sig
  module V1 : sig
    type t =
      { payload : Payload.Stable.V1.t; signature : Signature.Stable.V1.t }

    val to_yojson : t -> Yojson.Safe.t

    val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

    val version : int

    val __versioned__ : unit

    val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

    val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

    val equal : t -> t -> bool

    val hash_fold_t :
      Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

    val hash : t -> Ppx_hash_lib.Std.Hash.hash_value

    val compare : t -> t -> int

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

    val bin_read_t : Bin_prot.Common.buf -> pos_ref:Bin_prot.Common.pos_ref -> t

    val __bin_read_t__ :
      Bin_prot.Common.buf -> pos_ref:Bin_prot.Common.pos_ref -> int -> t

    val bin_size_t : t -> int

    val bin_write_t :
      Bin_prot.Common.buf -> pos:Bin_prot.Common.pos -> t -> Bin_prot.Common.pos

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

type t = Stable.V1.t = { payload : Payload.t; signature : Signature.t }

val to_yojson : t -> Yojson.Safe.t

val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

val equal : t -> t -> bool

val hash_fold_t :
  Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

val hash : t -> Ppx_hash_lib.Std.Hash.hash_value

val compare : t -> t -> int
