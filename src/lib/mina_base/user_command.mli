module Poly : sig
  module Stable : sig
    module V1 : sig
      type ('u, 's) t = Signed_command of 'u | Snapp_command of 's

      val to_yojson :
           ('u -> Yojson.Safe.t)
        -> ('s -> Yojson.Safe.t)
        -> ('u, 's) t
        -> Yojson.Safe.t

      val of_yojson :
           (Yojson.Safe.t -> 'u Ppx_deriving_yojson_runtime.error_or)
        -> (Yojson.Safe.t -> 's Ppx_deriving_yojson_runtime.error_or)
        -> Yojson.Safe.t
        -> ('u, 's) t Ppx_deriving_yojson_runtime.error_or

      val version : int

      val __versioned__ : unit

      val t_of_sexp :
           (Ppx_sexp_conv_lib.Sexp.t -> 'u)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 's)
        -> Ppx_sexp_conv_lib.Sexp.t
        -> ('u, 's) t

      val sexp_of_t :
           ('u -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('s -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('u, 's) t
        -> Ppx_sexp_conv_lib.Sexp.t

      val compare :
           ('u -> 'u -> int)
        -> ('s -> 's -> int)
        -> ('u, 's) t
        -> ('u, 's) t
        -> int

      val equal :
           ('u -> 'u -> bool)
        -> ('s -> 's -> bool)
        -> ('u, 's) t
        -> ('u, 's) t
        -> bool

      val hash_fold_t :
           (Ppx_hash_lib.Std.Hash.state -> 'u -> Ppx_hash_lib.Std.Hash.state)
        -> (Ppx_hash_lib.Std.Hash.state -> 's -> Ppx_hash_lib.Std.Hash.state)
        -> Ppx_hash_lib.Std.Hash.state
        -> ('u, 's) t
        -> Ppx_hash_lib.Std.Hash.state

      val to_latest : 'a -> 'a

      module With_version : sig
        type ('u, 's) typ = ('u, 's) t

        val bin_shape_typ :
             Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t

        val bin_size_typ :
             'u Core_kernel.Bin_prot.Size.sizer
          -> 's Core_kernel.Bin_prot.Size.sizer
          -> ('u, 's) typ Core_kernel.Bin_prot.Size.sizer

        val bin_write_typ :
             'u Core_kernel.Bin_prot.Write.writer
          -> 's Core_kernel.Bin_prot.Write.writer
          -> ('u, 's) typ Core_kernel.Bin_prot.Write.writer

        val bin_writer_typ :
             'a Core_kernel.Bin_prot.Type_class.writer
          -> 'b Core_kernel.Bin_prot.Type_class.writer
          -> ('a, 'b) typ Core_kernel.Bin_prot.Type_class.writer

        val __bin_read_typ__ :
             'u Core_kernel.Bin_prot.Read.reader
          -> 's Core_kernel.Bin_prot.Read.reader
          -> (int -> ('u, 's) typ) Core_kernel.Bin_prot.Read.reader

        val bin_read_typ :
             'u Core_kernel.Bin_prot.Read.reader
          -> 's Core_kernel.Bin_prot.Read.reader
          -> ('u, 's) typ Core_kernel.Bin_prot.Read.reader

        val bin_reader_typ :
             'a Core_kernel.Bin_prot.Type_class.reader
          -> 'b Core_kernel.Bin_prot.Type_class.reader
          -> ('a, 'b) typ Core_kernel.Bin_prot.Type_class.reader

        val bin_typ :
             'a Core_kernel.Bin_prot.Type_class.t
          -> 'b Core_kernel.Bin_prot.Type_class.t
          -> ('a, 'b) typ Core_kernel.Bin_prot.Type_class.t

        type ('u, 's) t = { version : int; t : ('u, 's) typ }

        val bin_shape_t :
             Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t

        val bin_size_t :
             'u Core_kernel.Bin_prot.Size.sizer
          -> 's Core_kernel.Bin_prot.Size.sizer
          -> ('u, 's) t Core_kernel.Bin_prot.Size.sizer

        val bin_write_t :
             'u Core_kernel.Bin_prot.Write.writer
          -> 's Core_kernel.Bin_prot.Write.writer
          -> ('u, 's) t Core_kernel.Bin_prot.Write.writer

        val bin_writer_t :
             'a Core_kernel.Bin_prot.Type_class.writer
          -> 'b Core_kernel.Bin_prot.Type_class.writer
          -> ('a, 'b) t Core_kernel.Bin_prot.Type_class.writer

        val __bin_read_t__ :
             'u Core_kernel.Bin_prot.Read.reader
          -> 's Core_kernel.Bin_prot.Read.reader
          -> (int -> ('u, 's) t) Core_kernel.Bin_prot.Read.reader

        val bin_read_t :
             'u Core_kernel.Bin_prot.Read.reader
          -> 's Core_kernel.Bin_prot.Read.reader
          -> ('u, 's) t Core_kernel.Bin_prot.Read.reader

        val bin_reader_t :
             'a Core_kernel.Bin_prot.Type_class.reader
          -> 'b Core_kernel.Bin_prot.Type_class.reader
          -> ('a, 'b) t Core_kernel.Bin_prot.Type_class.reader

        val bin_t :
             'a Core_kernel.Bin_prot.Type_class.t
          -> 'b Core_kernel.Bin_prot.Type_class.t
          -> ('a, 'b) t Core_kernel.Bin_prot.Type_class.t

        val create : ('a, 'b) typ -> ('a, 'b) t
      end

      val bin_read_t :
           'a Core_kernel.Bin_prot.Read.reader
        -> 'b Core_kernel.Bin_prot.Read.reader
        -> Bin_prot.Common.buf
        -> pos_ref:Bin_prot.Common.pos_ref
        -> ('a, 'b) t

      val __bin_read_t__ :
           'a Core_kernel.Bin_prot.Read.reader
        -> 'b Core_kernel.Bin_prot.Read.reader
        -> Bin_prot.Common.buf
        -> pos_ref:Bin_prot.Common.pos_ref
        -> int
        -> ('a, 'b) t

      val bin_size_t :
           'a Core_kernel.Bin_prot.Size.sizer
        -> 'b Core_kernel.Bin_prot.Size.sizer
        -> ('a, 'b) t
        -> int

      val bin_write_t :
           'a Core_kernel.Bin_prot.Write.writer
        -> 'b Core_kernel.Bin_prot.Write.writer
        -> Bin_prot.Common.buf
        -> pos:Bin_prot.Common.pos
        -> ('a, 'b) t
        -> Bin_prot.Common.pos

      val bin_shape_t :
           Core_kernel.Bin_prot.Shape.t
        -> Core_kernel.Bin_prot.Shape.t
        -> Core_kernel.Bin_prot.Shape.t

      val bin_reader_t :
           'a Core_kernel.Bin_prot.Type_class.reader
        -> 'b Core_kernel.Bin_prot.Type_class.reader
        -> ('a, 'b) t Core_kernel.Bin_prot.Type_class.reader

      val bin_writer_t :
           'a Core_kernel.Bin_prot.Type_class.writer
        -> 'b Core_kernel.Bin_prot.Type_class.writer
        -> ('a, 'b) t Core_kernel.Bin_prot.Type_class.writer

      val bin_t :
           'a Core_kernel.Bin_prot.Type_class.t
        -> 'b Core_kernel.Bin_prot.Type_class.t
        -> ('a, 'b) t Core_kernel.Bin_prot.Type_class.t

      val __ :
        (   'a Core_kernel.Bin_prot.Read.reader
         -> 'b Core_kernel.Bin_prot.Read.reader
         -> Bin_prot.Common.buf
         -> pos_ref:Bin_prot.Common.pos_ref
         -> ('a, 'b) t)
        * (   'c Core_kernel.Bin_prot.Read.reader
           -> 'd Core_kernel.Bin_prot.Read.reader
           -> Bin_prot.Common.buf
           -> pos_ref:Bin_prot.Common.pos_ref
           -> int
           -> ('c, 'd) t)
        * (   'e Core_kernel.Bin_prot.Size.sizer
           -> 'f Core_kernel.Bin_prot.Size.sizer
           -> ('e, 'f) t
           -> int)
        * (   'g Core_kernel.Bin_prot.Write.writer
           -> 'h Core_kernel.Bin_prot.Write.writer
           -> Bin_prot.Common.buf
           -> pos:Bin_prot.Common.pos
           -> ('g, 'h) t
           -> Bin_prot.Common.pos)
        * (   Core_kernel.Bin_prot.Shape.t
           -> Core_kernel.Bin_prot.Shape.t
           -> Core_kernel.Bin_prot.Shape.t)
        * (   'i Core_kernel.Bin_prot.Type_class.reader
           -> 'j Core_kernel.Bin_prot.Type_class.reader
           -> ('i, 'j) t Core_kernel.Bin_prot.Type_class.reader)
        * (   'k Core_kernel.Bin_prot.Type_class.writer
           -> 'l Core_kernel.Bin_prot.Type_class.writer
           -> ('k, 'l) t Core_kernel.Bin_prot.Type_class.writer)
        * (   'm Core_kernel.Bin_prot.Type_class.t
           -> 'n Core_kernel.Bin_prot.Type_class.t
           -> ('m, 'n) t Core_kernel.Bin_prot.Type_class.t)
    end

    module Latest = V1
  end

  type ('u, 's) t = ('u, 's) Stable.V1.t =
    | Signed_command of 'u
    | Snapp_command of 's

  val to_yojson :
       ('u -> Yojson.Safe.t)
    -> ('s -> Yojson.Safe.t)
    -> ('u, 's) t
    -> Yojson.Safe.t

  val of_yojson :
       (Yojson.Safe.t -> 'u Ppx_deriving_yojson_runtime.error_or)
    -> (Yojson.Safe.t -> 's Ppx_deriving_yojson_runtime.error_or)
    -> Yojson.Safe.t
    -> ('u, 's) t Ppx_deriving_yojson_runtime.error_or

  val t_of_sexp :
       (Ppx_sexp_conv_lib.Sexp.t -> 'u)
    -> (Ppx_sexp_conv_lib.Sexp.t -> 's)
    -> Ppx_sexp_conv_lib.Sexp.t
    -> ('u, 's) t

  val sexp_of_t :
       ('u -> Ppx_sexp_conv_lib.Sexp.t)
    -> ('s -> Ppx_sexp_conv_lib.Sexp.t)
    -> ('u, 's) t
    -> Ppx_sexp_conv_lib.Sexp.t

  val compare :
    ('u -> 'u -> int) -> ('s -> 's -> int) -> ('u, 's) t -> ('u, 's) t -> int

  val equal :
    ('u -> 'u -> bool) -> ('s -> 's -> bool) -> ('u, 's) t -> ('u, 's) t -> bool

  val hash_fold_t :
       (Ppx_hash_lib.Std.Hash.state -> 'u -> Ppx_hash_lib.Std.Hash.state)
    -> (Ppx_hash_lib.Std.Hash.state -> 's -> Ppx_hash_lib.Std.Hash.state)
    -> Ppx_hash_lib.Std.Hash.state
    -> ('u, 's) t
    -> Ppx_hash_lib.Std.Hash.state
end

type ('u, 's) t_ = ('u, 's) Poly.t =
  | Signed_command of 'u
  | Snapp_command of 's

module Gen_make : functor (C : Signed_command_intf.Gen_intf) -> sig
  val f :
       'a Core_kernel.Quickcheck.Generator.t
    -> ('a, 'b) t_ Core_kernel.Quickcheck.Generator.t

  val payment :
       ?sign_type:[ `Fake | `Real ]
    -> key_gen:
         (Import.Signature_keypair.t * Import.Signature_keypair.t)
         Core_kernel.Quickcheck.Generator.t
    -> ?nonce:Mina_numbers.Account_nonce.t
    -> max_amount:int
    -> ?fee_token:Token_id.t
    -> ?payment_token:Token_id.t
    -> fee_range:int
    -> unit
    -> (C.t, 'a) t_ Core_kernel.Quickcheck.Generator.t

  val payment_with_random_participants :
       ?sign_type:[ `Fake | `Real ]
    -> keys:Import.Signature_keypair.t array
    -> ?nonce:Mina_numbers.Account_nonce.t
    -> max_amount:int
    -> ?fee_token:Token_id.t
    -> ?payment_token:Token_id.t
    -> fee_range:int
    -> unit
    -> (C.t, 'a) t_ Core_kernel.Quickcheck.Generator.t

  val stake_delegation :
       key_gen:
         (Import.Signature_keypair.t * Import.Signature_keypair.t)
         Core_kernel.Quickcheck.Generator.t
    -> ?nonce:Mina_numbers.Account_nonce.t
    -> ?fee_token:Token_id.t
    -> fee_range:int
    -> unit
    -> (C.t, 'a) t_ Core_kernel.Quickcheck.Generator.t

  val stake_delegation_with_random_participants :
       keys:Import.Signature_keypair.t array
    -> ?nonce:Mina_numbers.Account_nonce.t
    -> ?fee_token:Token_id.t
    -> fee_range:int
    -> unit
    -> (C.t, 'a) t_ Core_kernel.Quickcheck.Generator.t

  val sequence :
       ?length:int
    -> ?sign_type:[ `Fake | `Real ]
    -> ( Signature_lib.Keypair.t
       * Currency.Amount.t
       * Mina_numbers.Account_nonce.t
       * Account_timing.t )
       array
    -> (C.t, 'a) t_ list Core_kernel.Quickcheck.Generator.t
end

module Gen : sig
  val f :
       'a Core_kernel.Quickcheck.Generator.t
    -> ('a, 'b) t_ Core_kernel.Quickcheck.Generator.t

  val payment :
       ?sign_type:[ `Fake | `Real ]
    -> key_gen:
         (Import.Signature_keypair.t * Import.Signature_keypair.t)
         Core_kernel.Quickcheck.Generator.t
    -> ?nonce:Mina_numbers.Account_nonce.t
    -> max_amount:int
    -> ?fee_token:Token_id.t
    -> ?payment_token:Token_id.t
    -> fee_range:int
    -> unit
    -> (Signed_command.t, 'a) t_ Core_kernel.Quickcheck.Generator.t

  val payment_with_random_participants :
       ?sign_type:[ `Fake | `Real ]
    -> keys:Import.Signature_keypair.t array
    -> ?nonce:Mina_numbers.Account_nonce.t
    -> max_amount:int
    -> ?fee_token:Token_id.t
    -> ?payment_token:Token_id.t
    -> fee_range:int
    -> unit
    -> (Signed_command.t, 'a) t_ Core_kernel.Quickcheck.Generator.t

  val stake_delegation :
       key_gen:
         (Import.Signature_keypair.t * Import.Signature_keypair.t)
         Core_kernel.Quickcheck.Generator.t
    -> ?nonce:Mina_numbers.Account_nonce.t
    -> ?fee_token:Token_id.t
    -> fee_range:int
    -> unit
    -> (Signed_command.t, 'a) t_ Core_kernel.Quickcheck.Generator.t

  val stake_delegation_with_random_participants :
       keys:Import.Signature_keypair.t array
    -> ?nonce:Mina_numbers.Account_nonce.t
    -> ?fee_token:Token_id.t
    -> fee_range:int
    -> unit
    -> (Signed_command.t, 'a) t_ Core_kernel.Quickcheck.Generator.t

  val sequence :
       ?length:int
    -> ?sign_type:[ `Fake | `Real ]
    -> ( Signature_lib.Keypair.t
       * Currency.Amount.t
       * Mina_numbers.Account_nonce.t
       * Account_timing.t )
       array
    -> (Signed_command.t, 'a) t_ list Core_kernel.Quickcheck.Generator.t
end

module Valid : sig
  module Stable : sig
    module V1 : sig
      type t =
        ( Signed_command.With_valid_signature.Stable.V1.t
        , Snapp_command.Valid.Stable.V1.t )
        t_

      val to_yojson : t -> Yojson.Safe.t

      val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

      val version : int

      val __versioned__ : unit

      val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

      val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

      val compare : t -> t -> int

      val equal : t -> t -> bool

      val hash_fold_t :
        Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

      val hash : t -> Ppx_hash_lib.Std.Hash.hash_value

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

  val compare : t -> t -> int

  val equal : t -> t -> bool

  val hash_fold_t :
    Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

  val hash : t -> Ppx_hash_lib.Std.Hash.hash_value

  module Gen : sig
    val f :
         'a Core_kernel.Quickcheck.Generator.t
      -> ('a, 'b) t_ Core_kernel.Quickcheck.Generator.t

    val payment :
         ?sign_type:[ `Fake | `Real ]
      -> key_gen:
           (Import.Signature_keypair.t * Import.Signature_keypair.t)
           Core_kernel.Quickcheck.Generator.t
      -> ?nonce:Mina_numbers.Account_nonce.t
      -> max_amount:int
      -> ?fee_token:Token_id.t
      -> ?payment_token:Token_id.t
      -> fee_range:int
      -> unit
      -> (Signed_command.With_valid_signature.t, 'a) t_
         Core_kernel.Quickcheck.Generator.t

    val payment_with_random_participants :
         ?sign_type:[ `Fake | `Real ]
      -> keys:Import.Signature_keypair.t array
      -> ?nonce:Mina_numbers.Account_nonce.t
      -> max_amount:int
      -> ?fee_token:Token_id.t
      -> ?payment_token:Token_id.t
      -> fee_range:int
      -> unit
      -> (Signed_command.With_valid_signature.t, 'a) t_
         Core_kernel.Quickcheck.Generator.t

    val stake_delegation :
         key_gen:
           (Import.Signature_keypair.t * Import.Signature_keypair.t)
           Core_kernel.Quickcheck.Generator.t
      -> ?nonce:Mina_numbers.Account_nonce.t
      -> ?fee_token:Token_id.t
      -> fee_range:int
      -> unit
      -> (Signed_command.With_valid_signature.t, 'a) t_
         Core_kernel.Quickcheck.Generator.t

    val stake_delegation_with_random_participants :
         keys:Import.Signature_keypair.t array
      -> ?nonce:Mina_numbers.Account_nonce.t
      -> ?fee_token:Token_id.t
      -> fee_range:int
      -> unit
      -> (Signed_command.With_valid_signature.t, 'a) t_
         Core_kernel.Quickcheck.Generator.t

    val sequence :
         ?length:int
      -> ?sign_type:[ `Fake | `Real ]
      -> ( Signature_lib.Keypair.t
         * Currency.Amount.t
         * Mina_numbers.Account_nonce.t
         * Account_timing.t )
         array
      -> (Signed_command.With_valid_signature.t, 'a) t_ list
         Core_kernel.Quickcheck.Generator.t
  end
end

module Stable : sig
  module V1 : sig
    type t = (Signed_command.Stable.V1.t, Snapp_command.Stable.V1.t) t_

    val to_yojson : t -> Yojson.Safe.t

    val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

    val version : int

    val __versioned__ : unit

    val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

    val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

    val compare : t -> t -> int

    val equal : t -> t -> bool

    val hash_fold_t :
      Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

    val hash : t -> Ppx_hash_lib.Std.Hash.hash_value

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
    (int * (Core_kernel.Bigstring.t -> pos_ref:int Core_kernel.ref -> Latest.t))
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

val compare : t -> t -> int

val equal : t -> t -> bool

val hash_fold_t :
  Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

val hash : t -> Ppx_hash_lib.Std.Hash.hash_value

module Zero_one_or_two : sig
  module Stable : sig
    module V1 : sig
      type 'a t = [ `One of 'a | `Two of 'a * 'a | `Zero ]

      val to_yojson : ('a -> Yojson.Safe.t) -> 'a t -> Yojson.Safe.t

      val of_yojson :
           (Yojson.Safe.t -> 'a Ppx_deriving_yojson_runtime.error_or)
        -> Yojson.Safe.t
        -> 'a t Ppx_deriving_yojson_runtime.error_or

      val version : int

      val __versioned__ : unit

      val __t_of_sexp__ :
        (Ppx_sexp_conv_lib.Sexp.t -> 'a) -> Ppx_sexp_conv_lib.Sexp.t -> 'a t

      val t_of_sexp :
        (Ppx_sexp_conv_lib.Sexp.t -> 'a) -> Ppx_sexp_conv_lib.Sexp.t -> 'a t

      val sexp_of_t :
        ('a -> Ppx_sexp_conv_lib.Sexp.t) -> 'a t -> Ppx_sexp_conv_lib.Sexp.t

      val compare : ('a -> 'a -> int) -> 'a t -> 'a t -> int

      val equal : ('a -> 'a -> bool) -> 'a t -> 'a t -> bool

      val hash_fold_t :
           (Ppx_hash_lib.Std.Hash.state -> 'a -> Ppx_hash_lib.Std.Hash.state)
        -> Ppx_hash_lib.Std.Hash.state
        -> 'a t
        -> Ppx_hash_lib.Std.Hash.state

      module With_version : sig
        type 'a typ = 'a t

        val bin_shape_typ :
          Core_kernel.Bin_prot.Shape.t -> Core_kernel.Bin_prot.Shape.t

        val bin_size_typ :
             'a Core_kernel.Bin_prot.Size.sizer
          -> 'a typ Core_kernel.Bin_prot.Size.sizer

        val bin_write_typ :
             'a Core_kernel.Bin_prot.Write.writer
          -> 'a typ Core_kernel.Bin_prot.Write.writer

        val bin_writer_typ :
             'a Core_kernel.Bin_prot.Type_class.writer
          -> 'a typ Core_kernel.Bin_prot.Type_class.writer

        val __bin_read_typ__ :
             'a Core_kernel.Bin_prot.Read.reader
          -> (int -> 'a typ) Core_kernel.Bin_prot.Read.reader

        val bin_read_typ :
             'a Core_kernel.Bin_prot.Read.reader
          -> 'a typ Core_kernel.Bin_prot.Read.reader

        val bin_reader_typ :
             'a Core_kernel.Bin_prot.Type_class.reader
          -> 'a typ Core_kernel.Bin_prot.Type_class.reader

        val bin_typ :
             'a Core_kernel.Bin_prot.Type_class.t
          -> 'a typ Core_kernel.Bin_prot.Type_class.t

        type 'a t = { version : int; t : 'a typ }

        val bin_shape_t :
          Core_kernel.Bin_prot.Shape.t -> Core_kernel.Bin_prot.Shape.t

        val bin_size_t :
             'a Core_kernel.Bin_prot.Size.sizer
          -> 'a t Core_kernel.Bin_prot.Size.sizer

        val bin_write_t :
             'a Core_kernel.Bin_prot.Write.writer
          -> 'a t Core_kernel.Bin_prot.Write.writer

        val bin_writer_t :
             'a Core_kernel.Bin_prot.Type_class.writer
          -> 'a t Core_kernel.Bin_prot.Type_class.writer

        val __bin_read_t__ :
             'a Core_kernel.Bin_prot.Read.reader
          -> (int -> 'a t) Core_kernel.Bin_prot.Read.reader

        val bin_read_t :
             'a Core_kernel.Bin_prot.Read.reader
          -> 'a t Core_kernel.Bin_prot.Read.reader

        val bin_reader_t :
             'a Core_kernel.Bin_prot.Type_class.reader
          -> 'a t Core_kernel.Bin_prot.Type_class.reader

        val bin_t :
             'a Core_kernel.Bin_prot.Type_class.t
          -> 'a t Core_kernel.Bin_prot.Type_class.t

        val create : 'a typ -> 'a t
      end

      val bin_read_t :
           'a Core_kernel.Bin_prot.Read.reader
        -> Bin_prot.Common.buf
        -> pos_ref:Bin_prot.Common.pos_ref
        -> 'a t

      val __bin_read_t__ :
           'a Core_kernel.Bin_prot.Read.reader
        -> Bin_prot.Common.buf
        -> pos_ref:Bin_prot.Common.pos_ref
        -> int
        -> 'a t

      val bin_size_t : 'a Core_kernel.Bin_prot.Size.sizer -> 'a t -> int

      val bin_write_t :
           'a Core_kernel.Bin_prot.Write.writer
        -> Bin_prot.Common.buf
        -> pos:Bin_prot.Common.pos
        -> 'a t
        -> Bin_prot.Common.pos

      val bin_shape_t :
        Core_kernel.Bin_prot.Shape.t -> Core_kernel.Bin_prot.Shape.t

      val bin_reader_t :
           'a Core_kernel.Bin_prot.Type_class.reader
        -> 'a t Core_kernel.Bin_prot.Type_class.reader

      val bin_writer_t :
           'a Core_kernel.Bin_prot.Type_class.writer
        -> 'a t Core_kernel.Bin_prot.Type_class.writer

      val bin_t :
           'a Core_kernel.Bin_prot.Type_class.t
        -> 'a t Core_kernel.Bin_prot.Type_class.t

      val __ :
        (   'a Core_kernel.Bin_prot.Read.reader
         -> Bin_prot.Common.buf
         -> pos_ref:Bin_prot.Common.pos_ref
         -> 'a t)
        * (   'b Core_kernel.Bin_prot.Read.reader
           -> Bin_prot.Common.buf
           -> pos_ref:Bin_prot.Common.pos_ref
           -> int
           -> 'b t)
        * ('c Core_kernel.Bin_prot.Size.sizer -> 'c t -> int)
        * (   'd Core_kernel.Bin_prot.Write.writer
           -> Bin_prot.Common.buf
           -> pos:Bin_prot.Common.pos
           -> 'd t
           -> Bin_prot.Common.pos)
        * (Core_kernel.Bin_prot.Shape.t -> Core_kernel.Bin_prot.Shape.t)
        * (   'e Core_kernel.Bin_prot.Type_class.reader
           -> 'e t Core_kernel.Bin_prot.Type_class.reader)
        * (   'f Core_kernel.Bin_prot.Type_class.writer
           -> 'f t Core_kernel.Bin_prot.Type_class.writer)
        * (   'g Core_kernel.Bin_prot.Type_class.t
           -> 'g t Core_kernel.Bin_prot.Type_class.t)
    end

    module Latest = V1
  end

  type 'a t = 'a Stable.V1.t

  val to_yojson : ('a -> Yojson.Safe.t) -> 'a t -> Yojson.Safe.t

  val of_yojson :
       (Yojson.Safe.t -> 'a Ppx_deriving_yojson_runtime.error_or)
    -> Yojson.Safe.t
    -> 'a t Ppx_deriving_yojson_runtime.error_or

  val t_of_sexp :
    (Ppx_sexp_conv_lib.Sexp.t -> 'a) -> Ppx_sexp_conv_lib.Sexp.t -> 'a t

  val sexp_of_t :
    ('a -> Ppx_sexp_conv_lib.Sexp.t) -> 'a t -> Ppx_sexp_conv_lib.Sexp.t

  val compare : ('a -> 'a -> int) -> 'a t -> 'a t -> int

  val equal : ('a -> 'a -> bool) -> 'a t -> 'a t -> bool

  val hash_fold_t :
       (Ppx_hash_lib.Std.Hash.state -> 'a -> Ppx_hash_lib.Std.Hash.state)
    -> Ppx_hash_lib.Std.Hash.state
    -> 'a t
    -> Ppx_hash_lib.Std.Hash.state
end

module Verifiable : sig
  module Stable : sig
    module V1 : sig
      type t =
        ( Signed_command.Stable.V1.t
        , Snapp_command.Stable.V1.t
          * Pickles.Side_loaded.Verification_key.Stable.V1.t Zero_one_or_two.t
        )
        t_

      val to_yojson : t -> Yojson.Safe.t

      val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

      val version : int

      val __versioned__ : unit

      val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

      val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

      val compare : t -> t -> int

      val equal : t -> t -> bool

      val hash_fold_t :
        Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

      val hash : t -> Ppx_hash_lib.Std.Hash.hash_value

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

  val compare : t -> t -> int

  val equal : t -> t -> bool

  val hash_fold_t :
    Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

  val hash : t -> Ppx_hash_lib.Std.Hash.hash_value
end

val to_verifiable_exn :
     t
  -> ledger:'a
  -> get:('a -> 'b -> Account.t option)
  -> location_of_account:('a -> Account_id.t -> 'b option)
  -> ( Signed_command.Stable.V1.t
     , Snapp_command.Stable.V1.t
       * [> `One of Side_loaded_verification_key.Stable.V1.t
         | `Two of
           Side_loaded_verification_key.Stable.V1.t
           * Side_loaded_verification_key.Stable.V1.t
         | `Zero ] )
     t_

val to_verifiable :
     t
  -> ledger:'a
  -> get:('a -> 'b -> Account.t option)
  -> location_of_account:('a -> Account_id.t -> 'b option)
  -> ( Signed_command.Stable.V1.t
     , Snapp_command.Stable.V1.t
       * [> `One of Side_loaded_verification_key.Stable.V1.t
         | `Two of
           Side_loaded_verification_key.Stable.V1.t
           * Side_loaded_verification_key.Stable.V1.t
         | `Zero ] )
     t_
     option

val fee_exn : t -> Currency.Fee.t

val minimum_fee : Currency.Fee.Stable.Latest.t

val has_insufficient_fee : t -> bool

val accounts_accessed :
  t -> next_available_token:Token_id.t -> Account_id.t list

val next_available_token : t -> Token_id.t -> Token_id.t

val to_base58_check : t -> string

val fee_payer : t -> Account_id.t

val nonce_exn : t -> Mina_numbers.Account_nonce.t

val check_tokens : t -> bool

val fee_token : t -> Token_id.t

val valid_until : t -> Mina_numbers.Global_slot.t

val forget_check : Valid.t -> t

val to_valid_unsafe :
     t
  -> [> `If_this_is_used_it_should_have_a_comment_justifying_it of
        (Signed_command.With_valid_signature.t, Snapp_command.Stable.V1.t) t_
     ]

val filter_by_participant :
  t list -> Signature_lib.Public_key.Compressed.t -> t list
