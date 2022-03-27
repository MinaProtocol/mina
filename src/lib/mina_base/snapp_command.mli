module Impl = Pickles.Impls.Step
module Digest = Random_oracle.Digest
module Predicate = Snapp_predicate

val typ_optional :
     ('a, 'b) Snark_params.Tick.Typ.t
  -> default:'b Core_kernel.Lazy.t
  -> ('a, 'b option) Snark_params.Tick.Typ.t

module Party : sig
  module Update : sig
    module Poly : sig
      module Stable : sig
        module V1 : sig
          type ('state_element, 'pk, 'vk, 'perms) t =
            { app_state : 'state_element Snapp_state.V.Stable.V1.t
            ; delegate : 'pk
            ; verification_key : 'vk
            ; permissions : 'perms
            }

          val to_yojson :
               ('state_element -> Yojson.Safe.t)
            -> ('pk -> Yojson.Safe.t)
            -> ('vk -> Yojson.Safe.t)
            -> ('perms -> Yojson.Safe.t)
            -> ('state_element, 'pk, 'vk, 'perms) t
            -> Yojson.Safe.t

          val of_yojson :
               (   Yojson.Safe.t
                -> 'state_element Ppx_deriving_yojson_runtime.error_or)
            -> (Yojson.Safe.t -> 'pk Ppx_deriving_yojson_runtime.error_or)
            -> (Yojson.Safe.t -> 'vk Ppx_deriving_yojson_runtime.error_or)
            -> (Yojson.Safe.t -> 'perms Ppx_deriving_yojson_runtime.error_or)
            -> Yojson.Safe.t
            -> ('state_element, 'pk, 'vk, 'perms) t
               Ppx_deriving_yojson_runtime.error_or

          val version : int

          val __versioned__ : unit

          val compare :
               ('state_element -> 'state_element -> int)
            -> ('pk -> 'pk -> int)
            -> ('vk -> 'vk -> int)
            -> ('perms -> 'perms -> int)
            -> ('state_element, 'pk, 'vk, 'perms) t
            -> ('state_element, 'pk, 'vk, 'perms) t
            -> int

          val equal :
               ('state_element -> 'state_element -> bool)
            -> ('pk -> 'pk -> bool)
            -> ('vk -> 'vk -> bool)
            -> ('perms -> 'perms -> bool)
            -> ('state_element, 'pk, 'vk, 'perms) t
            -> ('state_element, 'pk, 'vk, 'perms) t
            -> bool

          val t_of_sexp :
               (Ppx_sexp_conv_lib.Sexp.t -> 'state_element)
            -> (Ppx_sexp_conv_lib.Sexp.t -> 'pk)
            -> (Ppx_sexp_conv_lib.Sexp.t -> 'vk)
            -> (Ppx_sexp_conv_lib.Sexp.t -> 'perms)
            -> Ppx_sexp_conv_lib.Sexp.t
            -> ('state_element, 'pk, 'vk, 'perms) t

          val sexp_of_t :
               ('state_element -> Ppx_sexp_conv_lib.Sexp.t)
            -> ('pk -> Ppx_sexp_conv_lib.Sexp.t)
            -> ('vk -> Ppx_sexp_conv_lib.Sexp.t)
            -> ('perms -> Ppx_sexp_conv_lib.Sexp.t)
            -> ('state_element, 'pk, 'vk, 'perms) t
            -> Ppx_sexp_conv_lib.Sexp.t

          val hash_fold_t :
               (   Ppx_hash_lib.Std.Hash.state
                -> 'state_element
                -> Ppx_hash_lib.Std.Hash.state)
            -> (   Ppx_hash_lib.Std.Hash.state
                -> 'pk
                -> Ppx_hash_lib.Std.Hash.state)
            -> (   Ppx_hash_lib.Std.Hash.state
                -> 'vk
                -> Ppx_hash_lib.Std.Hash.state)
            -> (   Ppx_hash_lib.Std.Hash.state
                -> 'perms
                -> Ppx_hash_lib.Std.Hash.state)
            -> Ppx_hash_lib.Std.Hash.state
            -> ('state_element, 'pk, 'vk, 'perms) t
            -> Ppx_hash_lib.Std.Hash.state

          val to_hlist :
               ('state_element, 'pk, 'vk, 'perms) t
            -> ( unit
               ,    'state_element Snapp_state.V.Stable.V1.t
                 -> 'pk
                 -> 'vk
                 -> 'perms
                 -> unit )
               H_list.t

          val of_hlist :
               ( unit
               ,    'state_element Snapp_state.V.Stable.V1.t
                 -> 'pk
                 -> 'vk
                 -> 'perms
                 -> unit )
               H_list.t
            -> ('state_element, 'pk, 'vk, 'perms) t

          module With_version : sig
            type ('state_element, 'pk, 'vk, 'perms) typ =
              ('state_element, 'pk, 'vk, 'perms) t

            val bin_shape_typ :
                 Core_kernel.Bin_prot.Shape.t
              -> Core_kernel.Bin_prot.Shape.t
              -> Core_kernel.Bin_prot.Shape.t
              -> Core_kernel.Bin_prot.Shape.t
              -> Core_kernel.Bin_prot.Shape.t

            val bin_size_typ :
                 'state_element Core_kernel.Bin_prot.Size.sizer
              -> 'pk Core_kernel.Bin_prot.Size.sizer
              -> 'vk Core_kernel.Bin_prot.Size.sizer
              -> 'perms Core_kernel.Bin_prot.Size.sizer
              -> ('state_element, 'pk, 'vk, 'perms) typ
                 Core_kernel.Bin_prot.Size.sizer

            val bin_write_typ :
                 'state_element Core_kernel.Bin_prot.Write.writer
              -> 'pk Core_kernel.Bin_prot.Write.writer
              -> 'vk Core_kernel.Bin_prot.Write.writer
              -> 'perms Core_kernel.Bin_prot.Write.writer
              -> ('state_element, 'pk, 'vk, 'perms) typ
                 Core_kernel.Bin_prot.Write.writer

            val bin_writer_typ :
                 'a Core_kernel.Bin_prot.Type_class.writer
              -> 'b Core_kernel.Bin_prot.Type_class.writer
              -> 'c Core_kernel.Bin_prot.Type_class.writer
              -> 'd Core_kernel.Bin_prot.Type_class.writer
              -> ('a, 'b, 'c, 'd) typ Core_kernel.Bin_prot.Type_class.writer

            val __bin_read_typ__ :
                 'state_element Core_kernel.Bin_prot.Read.reader
              -> 'pk Core_kernel.Bin_prot.Read.reader
              -> 'vk Core_kernel.Bin_prot.Read.reader
              -> 'perms Core_kernel.Bin_prot.Read.reader
              -> (int -> ('state_element, 'pk, 'vk, 'perms) typ)
                 Core_kernel.Bin_prot.Read.reader

            val bin_read_typ :
                 'state_element Core_kernel.Bin_prot.Read.reader
              -> 'pk Core_kernel.Bin_prot.Read.reader
              -> 'vk Core_kernel.Bin_prot.Read.reader
              -> 'perms Core_kernel.Bin_prot.Read.reader
              -> ('state_element, 'pk, 'vk, 'perms) typ
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

            type ('state_element, 'pk, 'vk, 'perms) t =
              { version : int; t : ('state_element, 'pk, 'vk, 'perms) typ }

            val bin_shape_t :
                 Core_kernel.Bin_prot.Shape.t
              -> Core_kernel.Bin_prot.Shape.t
              -> Core_kernel.Bin_prot.Shape.t
              -> Core_kernel.Bin_prot.Shape.t
              -> Core_kernel.Bin_prot.Shape.t

            val bin_size_t :
                 'state_element Core_kernel.Bin_prot.Size.sizer
              -> 'pk Core_kernel.Bin_prot.Size.sizer
              -> 'vk Core_kernel.Bin_prot.Size.sizer
              -> 'perms Core_kernel.Bin_prot.Size.sizer
              -> ('state_element, 'pk, 'vk, 'perms) t
                 Core_kernel.Bin_prot.Size.sizer

            val bin_write_t :
                 'state_element Core_kernel.Bin_prot.Write.writer
              -> 'pk Core_kernel.Bin_prot.Write.writer
              -> 'vk Core_kernel.Bin_prot.Write.writer
              -> 'perms Core_kernel.Bin_prot.Write.writer
              -> ('state_element, 'pk, 'vk, 'perms) t
                 Core_kernel.Bin_prot.Write.writer

            val bin_writer_t :
                 'a Core_kernel.Bin_prot.Type_class.writer
              -> 'b Core_kernel.Bin_prot.Type_class.writer
              -> 'c Core_kernel.Bin_prot.Type_class.writer
              -> 'd Core_kernel.Bin_prot.Type_class.writer
              -> ('a, 'b, 'c, 'd) t Core_kernel.Bin_prot.Type_class.writer

            val __bin_read_t__ :
                 'state_element Core_kernel.Bin_prot.Read.reader
              -> 'pk Core_kernel.Bin_prot.Read.reader
              -> 'vk Core_kernel.Bin_prot.Read.reader
              -> 'perms Core_kernel.Bin_prot.Read.reader
              -> (int -> ('state_element, 'pk, 'vk, 'perms) t)
                 Core_kernel.Bin_prot.Read.reader

            val bin_read_t :
                 'state_element Core_kernel.Bin_prot.Read.reader
              -> 'pk Core_kernel.Bin_prot.Read.reader
              -> 'vk Core_kernel.Bin_prot.Read.reader
              -> 'perms Core_kernel.Bin_prot.Read.reader
              -> ('state_element, 'pk, 'vk, 'perms) t
                 Core_kernel.Bin_prot.Read.reader

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

      type ('state_element, 'pk, 'vk, 'perms) t =
            ('state_element, 'pk, 'vk, 'perms) Stable.V1.t =
        { app_state : 'state_element Snapp_state.V.t
        ; delegate : 'pk
        ; verification_key : 'vk
        ; permissions : 'perms
        }

      val to_yojson :
           ('state_element -> Yojson.Safe.t)
        -> ('pk -> Yojson.Safe.t)
        -> ('vk -> Yojson.Safe.t)
        -> ('perms -> Yojson.Safe.t)
        -> ('state_element, 'pk, 'vk, 'perms) t
        -> Yojson.Safe.t

      val of_yojson :
           (Yojson.Safe.t -> 'state_element Ppx_deriving_yojson_runtime.error_or)
        -> (Yojson.Safe.t -> 'pk Ppx_deriving_yojson_runtime.error_or)
        -> (Yojson.Safe.t -> 'vk Ppx_deriving_yojson_runtime.error_or)
        -> (Yojson.Safe.t -> 'perms Ppx_deriving_yojson_runtime.error_or)
        -> Yojson.Safe.t
        -> ('state_element, 'pk, 'vk, 'perms) t
           Ppx_deriving_yojson_runtime.error_or

      val compare :
           ('state_element -> 'state_element -> int)
        -> ('pk -> 'pk -> int)
        -> ('vk -> 'vk -> int)
        -> ('perms -> 'perms -> int)
        -> ('state_element, 'pk, 'vk, 'perms) t
        -> ('state_element, 'pk, 'vk, 'perms) t
        -> int

      val equal :
           ('state_element -> 'state_element -> bool)
        -> ('pk -> 'pk -> bool)
        -> ('vk -> 'vk -> bool)
        -> ('perms -> 'perms -> bool)
        -> ('state_element, 'pk, 'vk, 'perms) t
        -> ('state_element, 'pk, 'vk, 'perms) t
        -> bool

      val t_of_sexp :
           (Ppx_sexp_conv_lib.Sexp.t -> 'state_element)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'pk)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'vk)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'perms)
        -> Ppx_sexp_conv_lib.Sexp.t
        -> ('state_element, 'pk, 'vk, 'perms) t

      val sexp_of_t :
           ('state_element -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('pk -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('vk -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('perms -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('state_element, 'pk, 'vk, 'perms) t
        -> Ppx_sexp_conv_lib.Sexp.t

      val hash_fold_t :
           (   Ppx_hash_lib.Std.Hash.state
            -> 'state_element
            -> Ppx_hash_lib.Std.Hash.state)
        -> (Ppx_hash_lib.Std.Hash.state -> 'pk -> Ppx_hash_lib.Std.Hash.state)
        -> (Ppx_hash_lib.Std.Hash.state -> 'vk -> Ppx_hash_lib.Std.Hash.state)
        -> (   Ppx_hash_lib.Std.Hash.state
            -> 'perms
            -> Ppx_hash_lib.Std.Hash.state)
        -> Ppx_hash_lib.Std.Hash.state
        -> ('state_element, 'pk, 'vk, 'perms) t
        -> Ppx_hash_lib.Std.Hash.state

      val to_hlist :
           ('state_element, 'pk, 'vk, 'perms) t
        -> ( unit
           , 'state_element Snapp_state.V.t -> 'pk -> 'vk -> 'perms -> unit )
           H_list.t

      val of_hlist :
           ( unit
           , 'state_element Snapp_state.V.t -> 'pk -> 'vk -> 'perms -> unit )
           H_list.t
        -> ('state_element, 'pk, 'vk, 'perms) t
    end

    module Stable : sig
      module V1 : sig
        type t =
          ( Snapp_basic.F.Stable.V1.t Snapp_basic.Set_or_keep.Stable.V1.t
          , Signature_lib.Public_key.Compressed.Stable.V1.t
            Snapp_basic.Set_or_keep.Stable.V1.t
          , ( Pickles.Side_loaded.Verification_key.Stable.V1.t
            , Snapp_basic.F.Stable.V1.t )
            With_hash.Stable.V1.t
            Snapp_basic.Set_or_keep.Stable.V1.t
          , Permissions.Stable.V1.t Snapp_basic.Set_or_keep.Stable.V1.t )
          Poly.t

        val to_yojson : t -> Yojson.Safe.t

        val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

        val version : int

        val __versioned__ : unit

        val compare : t -> t -> int

        val equal : t -> t -> bool

        val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

        val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

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
        * (Core_kernel.Bigstring.t -> pos_ref:int Core_kernel.ref -> Latest.t)
        )
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

    val compare : t -> t -> int

    val equal : t -> t -> bool

    val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

    val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

    val hash_fold_t :
      Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

    val hash : t -> Ppx_hash_lib.Std.Hash.hash_value

    module Checked : sig
      type t =
        ( Pickles.Impls.Step.Field.t Snapp_basic.Set_or_keep.Checked.t
        , Signature_lib.Public_key.Compressed.var
          Snapp_basic.Set_or_keep.Checked.t
        , Pickles.Impls.Step.Field.t Snapp_basic.Set_or_keep.Checked.t
        , Permissions.Checked.t Snapp_basic.Set_or_keep.Checked.t )
        Poly.t

      val to_input :
           t
        -> ( Pickles.Impls.Step.Field.t
           , Snark_params.Tick.Boolean.var )
           Random_oracle_input.t
    end

    val dummy : t

    val to_input : t -> (Snark_params.Tick.Field.t, bool) Random_oracle_input.t

    val typ : unit -> (Checked.t, t) Snark_params.Tick.Typ.t
  end

  module Body : sig
    module Poly : sig
      module Stable : sig
        module V1 : sig
          type ('pk, 'update, 'signed_amount) t =
            { pk : 'pk; update : 'update; delta : 'signed_amount }

          val to_yojson :
               ('pk -> Yojson.Safe.t)
            -> ('update -> Yojson.Safe.t)
            -> ('signed_amount -> Yojson.Safe.t)
            -> ('pk, 'update, 'signed_amount) t
            -> Yojson.Safe.t

          val of_yojson :
               (Yojson.Safe.t -> 'pk Ppx_deriving_yojson_runtime.error_or)
            -> (Yojson.Safe.t -> 'update Ppx_deriving_yojson_runtime.error_or)
            -> (   Yojson.Safe.t
                -> 'signed_amount Ppx_deriving_yojson_runtime.error_or)
            -> Yojson.Safe.t
            -> ('pk, 'update, 'signed_amount) t
               Ppx_deriving_yojson_runtime.error_or

          val version : int

          val __versioned__ : unit

          val to_hlist :
               ('pk, 'update, 'signed_amount) t
            -> (unit, 'pk -> 'update -> 'signed_amount -> unit) H_list.t

          val of_hlist :
               (unit, 'pk -> 'update -> 'signed_amount -> unit) H_list.t
            -> ('pk, 'update, 'signed_amount) t

          val t_of_sexp :
               (Ppx_sexp_conv_lib.Sexp.t -> 'pk)
            -> (Ppx_sexp_conv_lib.Sexp.t -> 'update)
            -> (Ppx_sexp_conv_lib.Sexp.t -> 'signed_amount)
            -> Ppx_sexp_conv_lib.Sexp.t
            -> ('pk, 'update, 'signed_amount) t

          val sexp_of_t :
               ('pk -> Ppx_sexp_conv_lib.Sexp.t)
            -> ('update -> Ppx_sexp_conv_lib.Sexp.t)
            -> ('signed_amount -> Ppx_sexp_conv_lib.Sexp.t)
            -> ('pk, 'update, 'signed_amount) t
            -> Ppx_sexp_conv_lib.Sexp.t

          val equal :
               ('pk -> 'pk -> bool)
            -> ('update -> 'update -> bool)
            -> ('signed_amount -> 'signed_amount -> bool)
            -> ('pk, 'update, 'signed_amount) t
            -> ('pk, 'update, 'signed_amount) t
            -> bool

          val hash_fold_t :
               (   Ppx_hash_lib.Std.Hash.state
                -> 'pk
                -> Ppx_hash_lib.Std.Hash.state)
            -> (   Ppx_hash_lib.Std.Hash.state
                -> 'update
                -> Ppx_hash_lib.Std.Hash.state)
            -> (   Ppx_hash_lib.Std.Hash.state
                -> 'signed_amount
                -> Ppx_hash_lib.Std.Hash.state)
            -> Ppx_hash_lib.Std.Hash.state
            -> ('pk, 'update, 'signed_amount) t
            -> Ppx_hash_lib.Std.Hash.state

          val compare :
               ('pk -> 'pk -> int)
            -> ('update -> 'update -> int)
            -> ('signed_amount -> 'signed_amount -> int)
            -> ('pk, 'update, 'signed_amount) t
            -> ('pk, 'update, 'signed_amount) t
            -> int

          module With_version : sig
            type ('pk, 'update, 'signed_amount) typ =
              ('pk, 'update, 'signed_amount) t

            val bin_shape_typ :
                 Core_kernel.Bin_prot.Shape.t
              -> Core_kernel.Bin_prot.Shape.t
              -> Core_kernel.Bin_prot.Shape.t
              -> Core_kernel.Bin_prot.Shape.t

            val bin_size_typ :
                 'pk Core_kernel.Bin_prot.Size.sizer
              -> 'update Core_kernel.Bin_prot.Size.sizer
              -> 'signed_amount Core_kernel.Bin_prot.Size.sizer
              -> ('pk, 'update, 'signed_amount) typ
                 Core_kernel.Bin_prot.Size.sizer

            val bin_write_typ :
                 'pk Core_kernel.Bin_prot.Write.writer
              -> 'update Core_kernel.Bin_prot.Write.writer
              -> 'signed_amount Core_kernel.Bin_prot.Write.writer
              -> ('pk, 'update, 'signed_amount) typ
                 Core_kernel.Bin_prot.Write.writer

            val bin_writer_typ :
                 'a Core_kernel.Bin_prot.Type_class.writer
              -> 'b Core_kernel.Bin_prot.Type_class.writer
              -> 'c Core_kernel.Bin_prot.Type_class.writer
              -> ('a, 'b, 'c) typ Core_kernel.Bin_prot.Type_class.writer

            val __bin_read_typ__ :
                 'pk Core_kernel.Bin_prot.Read.reader
              -> 'update Core_kernel.Bin_prot.Read.reader
              -> 'signed_amount Core_kernel.Bin_prot.Read.reader
              -> (int -> ('pk, 'update, 'signed_amount) typ)
                 Core_kernel.Bin_prot.Read.reader

            val bin_read_typ :
                 'pk Core_kernel.Bin_prot.Read.reader
              -> 'update Core_kernel.Bin_prot.Read.reader
              -> 'signed_amount Core_kernel.Bin_prot.Read.reader
              -> ('pk, 'update, 'signed_amount) typ
                 Core_kernel.Bin_prot.Read.reader

            val bin_reader_typ :
                 'a Core_kernel.Bin_prot.Type_class.reader
              -> 'b Core_kernel.Bin_prot.Type_class.reader
              -> 'c Core_kernel.Bin_prot.Type_class.reader
              -> ('a, 'b, 'c) typ Core_kernel.Bin_prot.Type_class.reader

            val bin_typ :
                 'a Core_kernel.Bin_prot.Type_class.t
              -> 'b Core_kernel.Bin_prot.Type_class.t
              -> 'c Core_kernel.Bin_prot.Type_class.t
              -> ('a, 'b, 'c) typ Core_kernel.Bin_prot.Type_class.t

            type ('pk, 'update, 'signed_amount) t =
              { version : int; t : ('pk, 'update, 'signed_amount) typ }

            val bin_shape_t :
                 Core_kernel.Bin_prot.Shape.t
              -> Core_kernel.Bin_prot.Shape.t
              -> Core_kernel.Bin_prot.Shape.t
              -> Core_kernel.Bin_prot.Shape.t

            val bin_size_t :
                 'pk Core_kernel.Bin_prot.Size.sizer
              -> 'update Core_kernel.Bin_prot.Size.sizer
              -> 'signed_amount Core_kernel.Bin_prot.Size.sizer
              -> ('pk, 'update, 'signed_amount) t
                 Core_kernel.Bin_prot.Size.sizer

            val bin_write_t :
                 'pk Core_kernel.Bin_prot.Write.writer
              -> 'update Core_kernel.Bin_prot.Write.writer
              -> 'signed_amount Core_kernel.Bin_prot.Write.writer
              -> ('pk, 'update, 'signed_amount) t
                 Core_kernel.Bin_prot.Write.writer

            val bin_writer_t :
                 'a Core_kernel.Bin_prot.Type_class.writer
              -> 'b Core_kernel.Bin_prot.Type_class.writer
              -> 'c Core_kernel.Bin_prot.Type_class.writer
              -> ('a, 'b, 'c) t Core_kernel.Bin_prot.Type_class.writer

            val __bin_read_t__ :
                 'pk Core_kernel.Bin_prot.Read.reader
              -> 'update Core_kernel.Bin_prot.Read.reader
              -> 'signed_amount Core_kernel.Bin_prot.Read.reader
              -> (int -> ('pk, 'update, 'signed_amount) t)
                 Core_kernel.Bin_prot.Read.reader

            val bin_read_t :
                 'pk Core_kernel.Bin_prot.Read.reader
              -> 'update Core_kernel.Bin_prot.Read.reader
              -> 'signed_amount Core_kernel.Bin_prot.Read.reader
              -> ('pk, 'update, 'signed_amount) t
                 Core_kernel.Bin_prot.Read.reader

            val bin_reader_t :
                 'a Core_kernel.Bin_prot.Type_class.reader
              -> 'b Core_kernel.Bin_prot.Type_class.reader
              -> 'c Core_kernel.Bin_prot.Type_class.reader
              -> ('a, 'b, 'c) t Core_kernel.Bin_prot.Type_class.reader

            val bin_t :
                 'a Core_kernel.Bin_prot.Type_class.t
              -> 'b Core_kernel.Bin_prot.Type_class.t
              -> 'c Core_kernel.Bin_prot.Type_class.t
              -> ('a, 'b, 'c) t Core_kernel.Bin_prot.Type_class.t

            val create : ('a, 'b, 'c) typ -> ('a, 'b, 'c) t
          end

          val bin_read_t :
               'a Core_kernel.Bin_prot.Read.reader
            -> 'b Core_kernel.Bin_prot.Read.reader
            -> 'c Core_kernel.Bin_prot.Read.reader
            -> Bin_prot.Common.buf
            -> pos_ref:Bin_prot.Common.pos_ref
            -> ('a, 'b, 'c) t

          val __bin_read_t__ :
               'a Core_kernel.Bin_prot.Read.reader
            -> 'b Core_kernel.Bin_prot.Read.reader
            -> 'c Core_kernel.Bin_prot.Read.reader
            -> Bin_prot.Common.buf
            -> pos_ref:Bin_prot.Common.pos_ref
            -> int
            -> ('a, 'b, 'c) t

          val bin_size_t :
               'a Core_kernel.Bin_prot.Size.sizer
            -> 'b Core_kernel.Bin_prot.Size.sizer
            -> 'c Core_kernel.Bin_prot.Size.sizer
            -> ('a, 'b, 'c) t
            -> int

          val bin_write_t :
               'a Core_kernel.Bin_prot.Write.writer
            -> 'b Core_kernel.Bin_prot.Write.writer
            -> 'c Core_kernel.Bin_prot.Write.writer
            -> Bin_prot.Common.buf
            -> pos:Bin_prot.Common.pos
            -> ('a, 'b, 'c) t
            -> Bin_prot.Common.pos

          val bin_shape_t :
               Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t

          val bin_reader_t :
               'a Core_kernel.Bin_prot.Type_class.reader
            -> 'b Core_kernel.Bin_prot.Type_class.reader
            -> 'c Core_kernel.Bin_prot.Type_class.reader
            -> ('a, 'b, 'c) t Core_kernel.Bin_prot.Type_class.reader

          val bin_writer_t :
               'a Core_kernel.Bin_prot.Type_class.writer
            -> 'b Core_kernel.Bin_prot.Type_class.writer
            -> 'c Core_kernel.Bin_prot.Type_class.writer
            -> ('a, 'b, 'c) t Core_kernel.Bin_prot.Type_class.writer

          val bin_t :
               'a Core_kernel.Bin_prot.Type_class.t
            -> 'b Core_kernel.Bin_prot.Type_class.t
            -> 'c Core_kernel.Bin_prot.Type_class.t
            -> ('a, 'b, 'c) t Core_kernel.Bin_prot.Type_class.t

          val __ :
            (   'a Core_kernel.Bin_prot.Read.reader
             -> 'b Core_kernel.Bin_prot.Read.reader
             -> 'c Core_kernel.Bin_prot.Read.reader
             -> Bin_prot.Common.buf
             -> pos_ref:Bin_prot.Common.pos_ref
             -> ('a, 'b, 'c) t)
            * (   'd Core_kernel.Bin_prot.Read.reader
               -> 'e Core_kernel.Bin_prot.Read.reader
               -> 'f Core_kernel.Bin_prot.Read.reader
               -> Bin_prot.Common.buf
               -> pos_ref:Bin_prot.Common.pos_ref
               -> int
               -> ('d, 'e, 'f) t)
            * (   'g Core_kernel.Bin_prot.Size.sizer
               -> 'h Core_kernel.Bin_prot.Size.sizer
               -> 'i Core_kernel.Bin_prot.Size.sizer
               -> ('g, 'h, 'i) t
               -> int)
            * (   'j Core_kernel.Bin_prot.Write.writer
               -> 'k Core_kernel.Bin_prot.Write.writer
               -> 'l Core_kernel.Bin_prot.Write.writer
               -> Bin_prot.Common.buf
               -> pos:Bin_prot.Common.pos
               -> ('j, 'k, 'l) t
               -> Bin_prot.Common.pos)
            * (   Core_kernel.Bin_prot.Shape.t
               -> Core_kernel.Bin_prot.Shape.t
               -> Core_kernel.Bin_prot.Shape.t
               -> Core_kernel.Bin_prot.Shape.t)
            * (   'm Core_kernel.Bin_prot.Type_class.reader
               -> 'n Core_kernel.Bin_prot.Type_class.reader
               -> 'o Core_kernel.Bin_prot.Type_class.reader
               -> ('m, 'n, 'o) t Core_kernel.Bin_prot.Type_class.reader)
            * (   'p Core_kernel.Bin_prot.Type_class.writer
               -> 'q Core_kernel.Bin_prot.Type_class.writer
               -> 'r Core_kernel.Bin_prot.Type_class.writer
               -> ('p, 'q, 'r) t Core_kernel.Bin_prot.Type_class.writer)
            * (   's Core_kernel.Bin_prot.Type_class.t
               -> 't Core_kernel.Bin_prot.Type_class.t
               -> 'u Core_kernel.Bin_prot.Type_class.t
               -> ('s, 't, 'u) t Core_kernel.Bin_prot.Type_class.t)
        end

        module Latest = V1
      end

      type ('pk, 'update, 'signed_amount) t =
            ('pk, 'update, 'signed_amount) Stable.V1.t =
        { pk : 'pk; update : 'update; delta : 'signed_amount }

      val to_yojson :
           ('pk -> Yojson.Safe.t)
        -> ('update -> Yojson.Safe.t)
        -> ('signed_amount -> Yojson.Safe.t)
        -> ('pk, 'update, 'signed_amount) t
        -> Yojson.Safe.t

      val of_yojson :
           (Yojson.Safe.t -> 'pk Ppx_deriving_yojson_runtime.error_or)
        -> (Yojson.Safe.t -> 'update Ppx_deriving_yojson_runtime.error_or)
        -> (   Yojson.Safe.t
            -> 'signed_amount Ppx_deriving_yojson_runtime.error_or)
        -> Yojson.Safe.t
        -> ('pk, 'update, 'signed_amount) t Ppx_deriving_yojson_runtime.error_or

      val to_hlist :
           ('pk, 'update, 'signed_amount) t
        -> (unit, 'pk -> 'update -> 'signed_amount -> unit) H_list.t

      val of_hlist :
           (unit, 'pk -> 'update -> 'signed_amount -> unit) H_list.t
        -> ('pk, 'update, 'signed_amount) t

      val t_of_sexp :
           (Ppx_sexp_conv_lib.Sexp.t -> 'pk)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'update)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'signed_amount)
        -> Ppx_sexp_conv_lib.Sexp.t
        -> ('pk, 'update, 'signed_amount) t

      val sexp_of_t :
           ('pk -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('update -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('signed_amount -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('pk, 'update, 'signed_amount) t
        -> Ppx_sexp_conv_lib.Sexp.t

      val equal :
           ('pk -> 'pk -> bool)
        -> ('update -> 'update -> bool)
        -> ('signed_amount -> 'signed_amount -> bool)
        -> ('pk, 'update, 'signed_amount) t
        -> ('pk, 'update, 'signed_amount) t
        -> bool

      val hash_fold_t :
           (Ppx_hash_lib.Std.Hash.state -> 'pk -> Ppx_hash_lib.Std.Hash.state)
        -> (   Ppx_hash_lib.Std.Hash.state
            -> 'update
            -> Ppx_hash_lib.Std.Hash.state)
        -> (   Ppx_hash_lib.Std.Hash.state
            -> 'signed_amount
            -> Ppx_hash_lib.Std.Hash.state)
        -> Ppx_hash_lib.Std.Hash.state
        -> ('pk, 'update, 'signed_amount) t
        -> Ppx_hash_lib.Std.Hash.state

      val compare :
           ('pk -> 'pk -> int)
        -> ('update -> 'update -> int)
        -> ('signed_amount -> 'signed_amount -> int)
        -> ('pk, 'update, 'signed_amount) t
        -> ('pk, 'update, 'signed_amount) t
        -> int
    end

    module Stable : sig
      module V1 : sig
        type t =
          ( Signature_lib.Public_key.Compressed.Stable.V1.t
          , Update.Stable.V1.t
          , ( Currency.Amount.Stable.V1.t
            , Sgn.Stable.V1.t )
            Currency.Signed_poly.Stable.V1.t )
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
        * (Core_kernel.Bigstring.t -> pos_ref:int Core_kernel.ref -> Latest.t)
        )
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
        , Update.Checked.t
        , Currency.Amount.Signed.var )
        Poly.t

      val to_input :
           t
        -> ( Snark_params.Tick.Field.Var.t
           , Snark_params.Tick.Boolean.var )
           Random_oracle.Input.t

      val digest : t -> Random_oracle.Checked.Digest.t
    end

    val typ : unit -> (Checked.t, t) Snark_params.Tick.Typ.t

    val dummy : t

    val to_input : t -> (Snark_params.Tick.Field.t, bool) Random_oracle.Input.t

    val digest : t -> Random_oracle.Digest.t

    module Digested : sig
      type t = Random_oracle.Digest.t

      module Checked : sig
        type t = Random_oracle.Checked.Digest.t
      end
    end
  end

  module Predicated : sig
    module Poly : sig
      module Stable : sig
        module V1 : sig
          type ('body, 'predicate) t = { body : 'body; predicate : 'predicate }

          val to_yojson :
               ('body -> Yojson.Safe.t)
            -> ('predicate -> Yojson.Safe.t)
            -> ('body, 'predicate) t
            -> Yojson.Safe.t

          val of_yojson :
               (Yojson.Safe.t -> 'body Ppx_deriving_yojson_runtime.error_or)
            -> (   Yojson.Safe.t
                -> 'predicate Ppx_deriving_yojson_runtime.error_or)
            -> Yojson.Safe.t
            -> ('body, 'predicate) t Ppx_deriving_yojson_runtime.error_or

          val version : int

          val __versioned__ : unit

          val to_hlist :
               ('body, 'predicate) t
            -> (unit, 'body -> 'predicate -> unit) H_list.t

          val of_hlist :
               (unit, 'body -> 'predicate -> unit) H_list.t
            -> ('body, 'predicate) t

          val t_of_sexp :
               (Ppx_sexp_conv_lib.Sexp.t -> 'body)
            -> (Ppx_sexp_conv_lib.Sexp.t -> 'predicate)
            -> Ppx_sexp_conv_lib.Sexp.t
            -> ('body, 'predicate) t

          val sexp_of_t :
               ('body -> Ppx_sexp_conv_lib.Sexp.t)
            -> ('predicate -> Ppx_sexp_conv_lib.Sexp.t)
            -> ('body, 'predicate) t
            -> Ppx_sexp_conv_lib.Sexp.t

          val equal :
               ('body -> 'body -> bool)
            -> ('predicate -> 'predicate -> bool)
            -> ('body, 'predicate) t
            -> ('body, 'predicate) t
            -> bool

          val hash_fold_t :
               (   Ppx_hash_lib.Std.Hash.state
                -> 'body
                -> Ppx_hash_lib.Std.Hash.state)
            -> (   Ppx_hash_lib.Std.Hash.state
                -> 'predicate
                -> Ppx_hash_lib.Std.Hash.state)
            -> Ppx_hash_lib.Std.Hash.state
            -> ('body, 'predicate) t
            -> Ppx_hash_lib.Std.Hash.state

          val compare :
               ('body -> 'body -> int)
            -> ('predicate -> 'predicate -> int)
            -> ('body, 'predicate) t
            -> ('body, 'predicate) t
            -> int

          module With_version : sig
            type ('body, 'predicate) typ = ('body, 'predicate) t

            val bin_shape_typ :
                 Core_kernel.Bin_prot.Shape.t
              -> Core_kernel.Bin_prot.Shape.t
              -> Core_kernel.Bin_prot.Shape.t

            val bin_size_typ :
                 'body Core_kernel.Bin_prot.Size.sizer
              -> 'predicate Core_kernel.Bin_prot.Size.sizer
              -> ('body, 'predicate) typ Core_kernel.Bin_prot.Size.sizer

            val bin_write_typ :
                 'body Core_kernel.Bin_prot.Write.writer
              -> 'predicate Core_kernel.Bin_prot.Write.writer
              -> ('body, 'predicate) typ Core_kernel.Bin_prot.Write.writer

            val bin_writer_typ :
                 'a Core_kernel.Bin_prot.Type_class.writer
              -> 'b Core_kernel.Bin_prot.Type_class.writer
              -> ('a, 'b) typ Core_kernel.Bin_prot.Type_class.writer

            val __bin_read_typ__ :
                 'body Core_kernel.Bin_prot.Read.reader
              -> 'predicate Core_kernel.Bin_prot.Read.reader
              -> (int -> ('body, 'predicate) typ)
                 Core_kernel.Bin_prot.Read.reader

            val bin_read_typ :
                 'body Core_kernel.Bin_prot.Read.reader
              -> 'predicate Core_kernel.Bin_prot.Read.reader
              -> ('body, 'predicate) typ Core_kernel.Bin_prot.Read.reader

            val bin_reader_typ :
                 'a Core_kernel.Bin_prot.Type_class.reader
              -> 'b Core_kernel.Bin_prot.Type_class.reader
              -> ('a, 'b) typ Core_kernel.Bin_prot.Type_class.reader

            val bin_typ :
                 'a Core_kernel.Bin_prot.Type_class.t
              -> 'b Core_kernel.Bin_prot.Type_class.t
              -> ('a, 'b) typ Core_kernel.Bin_prot.Type_class.t

            type ('body, 'predicate) t =
              { version : int; t : ('body, 'predicate) typ }

            val bin_shape_t :
                 Core_kernel.Bin_prot.Shape.t
              -> Core_kernel.Bin_prot.Shape.t
              -> Core_kernel.Bin_prot.Shape.t

            val bin_size_t :
                 'body Core_kernel.Bin_prot.Size.sizer
              -> 'predicate Core_kernel.Bin_prot.Size.sizer
              -> ('body, 'predicate) t Core_kernel.Bin_prot.Size.sizer

            val bin_write_t :
                 'body Core_kernel.Bin_prot.Write.writer
              -> 'predicate Core_kernel.Bin_prot.Write.writer
              -> ('body, 'predicate) t Core_kernel.Bin_prot.Write.writer

            val bin_writer_t :
                 'a Core_kernel.Bin_prot.Type_class.writer
              -> 'b Core_kernel.Bin_prot.Type_class.writer
              -> ('a, 'b) t Core_kernel.Bin_prot.Type_class.writer

            val __bin_read_t__ :
                 'body Core_kernel.Bin_prot.Read.reader
              -> 'predicate Core_kernel.Bin_prot.Read.reader
              -> (int -> ('body, 'predicate) t) Core_kernel.Bin_prot.Read.reader

            val bin_read_t :
                 'body Core_kernel.Bin_prot.Read.reader
              -> 'predicate Core_kernel.Bin_prot.Read.reader
              -> ('body, 'predicate) t Core_kernel.Bin_prot.Read.reader

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

      type ('body, 'predicate) t = ('body, 'predicate) Stable.V1.t =
        { body : 'body; predicate : 'predicate }

      val to_yojson :
           ('body -> Yojson.Safe.t)
        -> ('predicate -> Yojson.Safe.t)
        -> ('body, 'predicate) t
        -> Yojson.Safe.t

      val of_yojson :
           (Yojson.Safe.t -> 'body Ppx_deriving_yojson_runtime.error_or)
        -> (Yojson.Safe.t -> 'predicate Ppx_deriving_yojson_runtime.error_or)
        -> Yojson.Safe.t
        -> ('body, 'predicate) t Ppx_deriving_yojson_runtime.error_or

      val to_hlist :
        ('body, 'predicate) t -> (unit, 'body -> 'predicate -> unit) H_list.t

      val of_hlist :
        (unit, 'body -> 'predicate -> unit) H_list.t -> ('body, 'predicate) t

      val t_of_sexp :
           (Ppx_sexp_conv_lib.Sexp.t -> 'body)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'predicate)
        -> Ppx_sexp_conv_lib.Sexp.t
        -> ('body, 'predicate) t

      val sexp_of_t :
           ('body -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('predicate -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('body, 'predicate) t
        -> Ppx_sexp_conv_lib.Sexp.t

      val equal :
           ('body -> 'body -> bool)
        -> ('predicate -> 'predicate -> bool)
        -> ('body, 'predicate) t
        -> ('body, 'predicate) t
        -> bool

      val hash_fold_t :
           (Ppx_hash_lib.Std.Hash.state -> 'body -> Ppx_hash_lib.Std.Hash.state)
        -> (   Ppx_hash_lib.Std.Hash.state
            -> 'predicate
            -> Ppx_hash_lib.Std.Hash.state)
        -> Ppx_hash_lib.Std.Hash.state
        -> ('body, 'predicate) t
        -> Ppx_hash_lib.Std.Hash.state

      val compare :
           ('body -> 'body -> int)
        -> ('predicate -> 'predicate -> int)
        -> ('body, 'predicate) t
        -> ('body, 'predicate) t
        -> int

      val typ :
           ( unit
           , unit
           , 'a -> 'b -> unit
           , 'c -> 'd -> unit )
           Pickles__Impls.Step.Impl.Internal_Basic.Data_spec.t
        -> (('a, 'b) t, ('c, 'd) t) Snark_params.Tick.Typ.t
    end

    module Proved : sig
      module Stable : sig
        module V1 : sig
          type t = (Body.Stable.V1.t, Snapp_predicate.Stable.V1.t) Poly.t

          val to_yojson : t -> Yojson.Safe.t

          val of_yojson :
            Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

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
          * (Core_kernel.Bigstring.t -> pos_ref:int Core_kernel.ref -> Latest.t)
          )
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

      module Digested : sig
        type t = (Body.Digested.t, Snapp_predicate.Digested.t) Poly.t

        module Checked : sig
          type t =
            (Body.Digested.Checked.t, Snark_params.Tick.Field.Var.t) Poly.t
        end
      end
    end

    module Signed : sig
      module Stable : sig
        module V1 : sig
          type t =
            (Body.Stable.V1.t, Mina_numbers.Account_nonce.Stable.V1.t) Poly.t

          val to_yojson : t -> Yojson.Safe.t

          val of_yojson :
            Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

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
          * (Core_kernel.Bigstring.t -> pos_ref:int Core_kernel.ref -> Latest.t)
          )
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

      module Digested : sig
        type t = (Body.Digested.t, Mina_numbers.Account_nonce.t) Poly.t

        module Checked : sig
          type t =
            ( Body.Digested.Checked.t
            , Mina_numbers.Account_nonce.Checked.t )
            Poly.t
        end
      end

      module Checked : sig
        type t = (Body.Checked.t, Mina_numbers.Account_nonce.Checked.t) Poly.t
      end

      val typ : (Checked.t, t) Snark_params.Tick.Typ.t

      val dummy : t
    end

    module Empty : sig
      module Stable : sig
        module V1 : sig
          type t = (Body.Stable.V1.t, unit) Poly.t

          val to_yojson : t -> Yojson.Safe.t

          val of_yojson :
            Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

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
          * (Core_kernel.Bigstring.t -> pos_ref:int Core_kernel.ref -> Latest.t)
          )
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

      val dummy : t

      val create : Body.Stable.V1.t -> t
    end
  end

  module Authorized : sig
    module Poly : sig
      module Stable : sig
        module V1 : sig
          type ('data, 'auth) t = { data : 'data; authorization : 'auth }

          val to_yojson :
               ('data -> Yojson.Safe.t)
            -> ('auth -> Yojson.Safe.t)
            -> ('data, 'auth) t
            -> Yojson.Safe.t

          val of_yojson :
               (Yojson.Safe.t -> 'data Ppx_deriving_yojson_runtime.error_or)
            -> (Yojson.Safe.t -> 'auth Ppx_deriving_yojson_runtime.error_or)
            -> Yojson.Safe.t
            -> ('data, 'auth) t Ppx_deriving_yojson_runtime.error_or

          val version : int

          val __versioned__ : unit

          val to_hlist :
            ('data, 'auth) t -> (unit, 'data -> 'auth -> unit) H_list.t

          val of_hlist :
            (unit, 'data -> 'auth -> unit) H_list.t -> ('data, 'auth) t

          val t_of_sexp :
               (Ppx_sexp_conv_lib.Sexp.t -> 'data)
            -> (Ppx_sexp_conv_lib.Sexp.t -> 'auth)
            -> Ppx_sexp_conv_lib.Sexp.t
            -> ('data, 'auth) t

          val sexp_of_t :
               ('data -> Ppx_sexp_conv_lib.Sexp.t)
            -> ('auth -> Ppx_sexp_conv_lib.Sexp.t)
            -> ('data, 'auth) t
            -> Ppx_sexp_conv_lib.Sexp.t

          val equal :
               ('data -> 'data -> bool)
            -> ('auth -> 'auth -> bool)
            -> ('data, 'auth) t
            -> ('data, 'auth) t
            -> bool

          val hash_fold_t :
               (   Ppx_hash_lib.Std.Hash.state
                -> 'data
                -> Ppx_hash_lib.Std.Hash.state)
            -> (   Ppx_hash_lib.Std.Hash.state
                -> 'auth
                -> Ppx_hash_lib.Std.Hash.state)
            -> Ppx_hash_lib.Std.Hash.state
            -> ('data, 'auth) t
            -> Ppx_hash_lib.Std.Hash.state

          val compare :
               ('data -> 'data -> int)
            -> ('auth -> 'auth -> int)
            -> ('data, 'auth) t
            -> ('data, 'auth) t
            -> int

          module With_version : sig
            type ('data, 'auth) typ = ('data, 'auth) t

            val bin_shape_typ :
                 Core_kernel.Bin_prot.Shape.t
              -> Core_kernel.Bin_prot.Shape.t
              -> Core_kernel.Bin_prot.Shape.t

            val bin_size_typ :
                 'data Core_kernel.Bin_prot.Size.sizer
              -> 'auth Core_kernel.Bin_prot.Size.sizer
              -> ('data, 'auth) typ Core_kernel.Bin_prot.Size.sizer

            val bin_write_typ :
                 'data Core_kernel.Bin_prot.Write.writer
              -> 'auth Core_kernel.Bin_prot.Write.writer
              -> ('data, 'auth) typ Core_kernel.Bin_prot.Write.writer

            val bin_writer_typ :
                 'a Core_kernel.Bin_prot.Type_class.writer
              -> 'b Core_kernel.Bin_prot.Type_class.writer
              -> ('a, 'b) typ Core_kernel.Bin_prot.Type_class.writer

            val __bin_read_typ__ :
                 'data Core_kernel.Bin_prot.Read.reader
              -> 'auth Core_kernel.Bin_prot.Read.reader
              -> (int -> ('data, 'auth) typ) Core_kernel.Bin_prot.Read.reader

            val bin_read_typ :
                 'data Core_kernel.Bin_prot.Read.reader
              -> 'auth Core_kernel.Bin_prot.Read.reader
              -> ('data, 'auth) typ Core_kernel.Bin_prot.Read.reader

            val bin_reader_typ :
                 'a Core_kernel.Bin_prot.Type_class.reader
              -> 'b Core_kernel.Bin_prot.Type_class.reader
              -> ('a, 'b) typ Core_kernel.Bin_prot.Type_class.reader

            val bin_typ :
                 'a Core_kernel.Bin_prot.Type_class.t
              -> 'b Core_kernel.Bin_prot.Type_class.t
              -> ('a, 'b) typ Core_kernel.Bin_prot.Type_class.t

            type ('data, 'auth) t = { version : int; t : ('data, 'auth) typ }

            val bin_shape_t :
                 Core_kernel.Bin_prot.Shape.t
              -> Core_kernel.Bin_prot.Shape.t
              -> Core_kernel.Bin_prot.Shape.t

            val bin_size_t :
                 'data Core_kernel.Bin_prot.Size.sizer
              -> 'auth Core_kernel.Bin_prot.Size.sizer
              -> ('data, 'auth) t Core_kernel.Bin_prot.Size.sizer

            val bin_write_t :
                 'data Core_kernel.Bin_prot.Write.writer
              -> 'auth Core_kernel.Bin_prot.Write.writer
              -> ('data, 'auth) t Core_kernel.Bin_prot.Write.writer

            val bin_writer_t :
                 'a Core_kernel.Bin_prot.Type_class.writer
              -> 'b Core_kernel.Bin_prot.Type_class.writer
              -> ('a, 'b) t Core_kernel.Bin_prot.Type_class.writer

            val __bin_read_t__ :
                 'data Core_kernel.Bin_prot.Read.reader
              -> 'auth Core_kernel.Bin_prot.Read.reader
              -> (int -> ('data, 'auth) t) Core_kernel.Bin_prot.Read.reader

            val bin_read_t :
                 'data Core_kernel.Bin_prot.Read.reader
              -> 'auth Core_kernel.Bin_prot.Read.reader
              -> ('data, 'auth) t Core_kernel.Bin_prot.Read.reader

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

      type ('data, 'auth) t = ('data, 'auth) Stable.V1.t =
        { data : 'data; authorization : 'auth }

      val to_yojson :
           ('data -> Yojson.Safe.t)
        -> ('auth -> Yojson.Safe.t)
        -> ('data, 'auth) t
        -> Yojson.Safe.t

      val of_yojson :
           (Yojson.Safe.t -> 'data Ppx_deriving_yojson_runtime.error_or)
        -> (Yojson.Safe.t -> 'auth Ppx_deriving_yojson_runtime.error_or)
        -> Yojson.Safe.t
        -> ('data, 'auth) t Ppx_deriving_yojson_runtime.error_or

      val to_hlist : ('data, 'auth) t -> (unit, 'data -> 'auth -> unit) H_list.t

      val of_hlist : (unit, 'data -> 'auth -> unit) H_list.t -> ('data, 'auth) t

      val t_of_sexp :
           (Ppx_sexp_conv_lib.Sexp.t -> 'data)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'auth)
        -> Ppx_sexp_conv_lib.Sexp.t
        -> ('data, 'auth) t

      val sexp_of_t :
           ('data -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('auth -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('data, 'auth) t
        -> Ppx_sexp_conv_lib.Sexp.t

      val equal :
           ('data -> 'data -> bool)
        -> ('auth -> 'auth -> bool)
        -> ('data, 'auth) t
        -> ('data, 'auth) t
        -> bool

      val hash_fold_t :
           (Ppx_hash_lib.Std.Hash.state -> 'data -> Ppx_hash_lib.Std.Hash.state)
        -> (Ppx_hash_lib.Std.Hash.state -> 'auth -> Ppx_hash_lib.Std.Hash.state)
        -> Ppx_hash_lib.Std.Hash.state
        -> ('data, 'auth) t
        -> Ppx_hash_lib.Std.Hash.state

      val compare :
           ('data -> 'data -> int)
        -> ('auth -> 'auth -> int)
        -> ('data, 'auth) t
        -> ('data, 'auth) t
        -> int
    end

    module Proved : sig
      module Stable : sig
        module V1 : sig
          type t = (Predicated.Proved.Stable.V1.t, Control.Stable.V1.t) Poly.t

          val to_yojson : t -> Yojson.Safe.t

          val of_yojson :
            Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

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
          * (Core_kernel.Bigstring.t -> pos_ref:int Core_kernel.ref -> Latest.t)
          )
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
    end

    module Signed : sig
      module Stable : sig
        module V1 : sig
          type t = (Predicated.Signed.Stable.V1.t, Signature.Stable.V1.t) Poly.t

          val to_yojson : t -> Yojson.Safe.t

          val of_yojson :
            Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

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
          * (Core_kernel.Bigstring.t -> pos_ref:int Core_kernel.ref -> Latest.t)
          )
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
    end

    module Empty : sig
      module Stable : sig
        module V1 : sig
          type t = (Predicated.Empty.Stable.V1.t, unit) Poly.t

          val to_yojson : t -> Yojson.Safe.t

          val of_yojson :
            Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

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
          * (Core_kernel.Bigstring.t -> pos_ref:int Core_kernel.ref -> Latest.t)
          )
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
    end
  end
end

module Inner : sig
  module Stable : sig
    module V1 : sig
      type ('one, 'two) t =
        { token_id : Token_id.Stable.V1.t
        ; fee_payment : Other_fee_payer.Stable.V1.t option
        ; one : 'one
        ; two : 'two
        }

      val to_yojson :
           ('one -> Yojson.Safe.t)
        -> ('two -> Yojson.Safe.t)
        -> ('one, 'two) t
        -> Yojson.Safe.t

      val of_yojson :
           (Yojson.Safe.t -> 'one Ppx_deriving_yojson_runtime.error_or)
        -> (Yojson.Safe.t -> 'two Ppx_deriving_yojson_runtime.error_or)
        -> Yojson.Safe.t
        -> ('one, 'two) t Ppx_deriving_yojson_runtime.error_or

      val version : int

      val __versioned__ : unit

      val t_of_sexp :
           (Ppx_sexp_conv_lib.Sexp.t -> 'one)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'two)
        -> Ppx_sexp_conv_lib.Sexp.t
        -> ('one, 'two) t

      val sexp_of_t :
           ('one -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('two -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('one, 'two) t
        -> Ppx_sexp_conv_lib.Sexp.t

      val equal :
           ('one -> 'one -> bool)
        -> ('two -> 'two -> bool)
        -> ('one, 'two) t
        -> ('one, 'two) t
        -> bool

      val hash_fold_t :
           (Ppx_hash_lib.Std.Hash.state -> 'one -> Ppx_hash_lib.Std.Hash.state)
        -> (Ppx_hash_lib.Std.Hash.state -> 'two -> Ppx_hash_lib.Std.Hash.state)
        -> Ppx_hash_lib.Std.Hash.state
        -> ('one, 'two) t
        -> Ppx_hash_lib.Std.Hash.state

      val compare :
           ('one -> 'one -> Core_kernel__.Import.int)
        -> ('two -> 'two -> Core_kernel__.Import.int)
        -> ('one, 'two) t
        -> ('one, 'two) t
        -> Core_kernel__.Import.int

      val two : ('a, 'b) t -> 'b

      val one : ('a, 'b) t -> 'a

      val fee_payment : ('a, 'b) t -> Other_fee_payer.Stable.V1.t option

      val token_id : ('a, 'b) t -> Token_id.Stable.V1.t

      module Fields : sig
        val names : string list

        val two :
          ( [< `Read | `Set_and_create ]
          , ('a, 'two) t
          , 'two )
          Fieldslib.Field.t_with_perm

        val one :
          ( [< `Read | `Set_and_create ]
          , ('one, 'a) t
          , 'one )
          Fieldslib.Field.t_with_perm

        val fee_payment :
          ( [< `Read | `Set_and_create ]
          , ('a, 'b) t
          , Other_fee_payer.Stable.V1.t option )
          Fieldslib.Field.t_with_perm

        val token_id :
          ( [< `Read | `Set_and_create ]
          , ('a, 'b) t
          , Token_id.Stable.V1.t )
          Fieldslib.Field.t_with_perm

        val make_creator :
             token_id:
               (   ( [< `Read | `Set_and_create ]
                   , ('a, 'b) t
                   , Token_id.Stable.V1.t )
                   Fieldslib.Field.t_with_perm
                -> 'c
                -> ('d -> Token_id.Stable.V1.t) * 'e)
          -> fee_payment:
               (   ( [< `Read | `Set_and_create ]
                   , ('f, 'g) t
                   , Other_fee_payer.Stable.V1.t option )
                   Fieldslib.Field.t_with_perm
                -> 'e
                -> ('d -> Other_fee_payer.Stable.V1.t option) * 'h)
          -> one:
               (   ( [< `Read | `Set_and_create ]
                   , ('i, 'j) t
                   , 'i )
                   Fieldslib.Field.t_with_perm
                -> 'h
                -> ('d -> 'k) * 'l)
          -> two:
               (   ( [< `Read | `Set_and_create ]
                   , ('m, 'n) t
                   , 'n )
                   Fieldslib.Field.t_with_perm
                -> 'l
                -> ('d -> 'o) * 'p)
          -> 'c
          -> ('d -> ('k, 'o) t) * 'p

        val create :
             token_id:Token_id.Stable.V1.t
          -> fee_payment:Other_fee_payer.Stable.V1.t option
          -> one:'a
          -> two:'b
          -> ('a, 'b) t

        val map :
             token_id:
               (   ( [< `Read | `Set_and_create ]
                   , ('a, 'b) t
                   , Token_id.Stable.V1.t )
                   Fieldslib.Field.t_with_perm
                -> Token_id.Stable.V1.t)
          -> fee_payment:
               (   ( [< `Read | `Set_and_create ]
                   , ('c, 'd) t
                   , Other_fee_payer.Stable.V1.t option )
                   Fieldslib.Field.t_with_perm
                -> Other_fee_payer.Stable.V1.t option)
          -> one:
               (   ( [< `Read | `Set_and_create ]
                   , ('e, 'f) t
                   , 'e )
                   Fieldslib.Field.t_with_perm
                -> 'g)
          -> two:
               (   ( [< `Read | `Set_and_create ]
                   , ('h, 'i) t
                   , 'i )
                   Fieldslib.Field.t_with_perm
                -> 'j)
          -> ('g, 'j) t

        val iter :
             token_id:
               (   ( [< `Read | `Set_and_create ]
                   , ('a, 'b) t
                   , Token_id.Stable.V1.t )
                   Fieldslib.Field.t_with_perm
                -> unit)
          -> fee_payment:
               (   ( [< `Read | `Set_and_create ]
                   , ('c, 'd) t
                   , Other_fee_payer.Stable.V1.t option )
                   Fieldslib.Field.t_with_perm
                -> unit)
          -> one:
               (   ( [< `Read | `Set_and_create ]
                   , ('e, 'f) t
                   , 'e )
                   Fieldslib.Field.t_with_perm
                -> unit)
          -> two:
               (   ( [< `Read | `Set_and_create ]
                   , ('g, 'h) t
                   , 'h )
                   Fieldslib.Field.t_with_perm
                -> unit)
          -> unit

        val fold :
             init:'a
          -> token_id:
               (   'a
                -> ( [< `Read | `Set_and_create ]
                   , ('b, 'c) t
                   , Token_id.Stable.V1.t )
                   Fieldslib.Field.t_with_perm
                -> 'd)
          -> fee_payment:
               (   'd
                -> ( [< `Read | `Set_and_create ]
                   , ('e, 'f) t
                   , Other_fee_payer.Stable.V1.t option )
                   Fieldslib.Field.t_with_perm
                -> 'g)
          -> one:
               (   'g
                -> ( [< `Read | `Set_and_create ]
                   , ('h, 'i) t
                   , 'h )
                   Fieldslib.Field.t_with_perm
                -> 'j)
          -> two:
               (   'j
                -> ( [< `Read | `Set_and_create ]
                   , ('k, 'l) t
                   , 'l )
                   Fieldslib.Field.t_with_perm
                -> 'm)
          -> 'm

        val map_poly :
             ([< `Read | `Set_and_create ], ('a, 'b) t, 'c) Fieldslib.Field.user
          -> 'c list

        val for_all :
             token_id:
               (   ( [< `Read | `Set_and_create ]
                   , ('a, 'b) t
                   , Token_id.Stable.V1.t )
                   Fieldslib.Field.t_with_perm
                -> bool)
          -> fee_payment:
               (   ( [< `Read | `Set_and_create ]
                   , ('c, 'd) t
                   , Other_fee_payer.Stable.V1.t option )
                   Fieldslib.Field.t_with_perm
                -> bool)
          -> one:
               (   ( [< `Read | `Set_and_create ]
                   , ('e, 'f) t
                   , 'e )
                   Fieldslib.Field.t_with_perm
                -> bool)
          -> two:
               (   ( [< `Read | `Set_and_create ]
                   , ('g, 'h) t
                   , 'h )
                   Fieldslib.Field.t_with_perm
                -> bool)
          -> bool

        val exists :
             token_id:
               (   ( [< `Read | `Set_and_create ]
                   , ('a, 'b) t
                   , Token_id.Stable.V1.t )
                   Fieldslib.Field.t_with_perm
                -> bool)
          -> fee_payment:
               (   ( [< `Read | `Set_and_create ]
                   , ('c, 'd) t
                   , Other_fee_payer.Stable.V1.t option )
                   Fieldslib.Field.t_with_perm
                -> bool)
          -> one:
               (   ( [< `Read | `Set_and_create ]
                   , ('e, 'f) t
                   , 'e )
                   Fieldslib.Field.t_with_perm
                -> bool)
          -> two:
               (   ( [< `Read | `Set_and_create ]
                   , ('g, 'h) t
                   , 'h )
                   Fieldslib.Field.t_with_perm
                -> bool)
          -> bool

        val to_list :
             token_id:
               (   ( [< `Read | `Set_and_create ]
                   , ('a, 'b) t
                   , Token_id.Stable.V1.t )
                   Fieldslib.Field.t_with_perm
                -> 'c)
          -> fee_payment:
               (   ( [< `Read | `Set_and_create ]
                   , ('d, 'e) t
                   , Other_fee_payer.Stable.V1.t option )
                   Fieldslib.Field.t_with_perm
                -> 'c)
          -> one:
               (   ( [< `Read | `Set_and_create ]
                   , ('f, 'g) t
                   , 'f )
                   Fieldslib.Field.t_with_perm
                -> 'c)
          -> two:
               (   ( [< `Read | `Set_and_create ]
                   , ('h, 'i) t
                   , 'i )
                   Fieldslib.Field.t_with_perm
                -> 'c)
          -> 'c list

        module Direct : sig
          val iter :
               ('a, 'b) t
            -> token_id:
                 (   ( [< `Read | `Set_and_create ]
                     , ('c, 'd) t
                     , Token_id.Stable.V1.t )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b) t
                  -> Token_id.Stable.V1.t
                  -> unit)
            -> fee_payment:
                 (   ( [< `Read | `Set_and_create ]
                     , ('e, 'f) t
                     , Other_fee_payer.Stable.V1.t option )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b) t
                  -> Other_fee_payer.Stable.V1.t option
                  -> unit)
            -> one:
                 (   ( [< `Read | `Set_and_create ]
                     , ('g, 'h) t
                     , 'g )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b) t
                  -> 'a
                  -> unit)
            -> two:
                 (   ( [< `Read | `Set_and_create ]
                     , ('i, 'j) t
                     , 'j )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b) t
                  -> 'b
                  -> 'k)
            -> 'k

          val fold :
               ('a, 'b) t
            -> init:'c
            -> token_id:
                 (   'c
                  -> ( [< `Read | `Set_and_create ]
                     , ('d, 'e) t
                     , Token_id.Stable.V1.t )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b) t
                  -> Token_id.Stable.V1.t
                  -> 'f)
            -> fee_payment:
                 (   'f
                  -> ( [< `Read | `Set_and_create ]
                     , ('g, 'h) t
                     , Other_fee_payer.Stable.V1.t option )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b) t
                  -> Other_fee_payer.Stable.V1.t option
                  -> 'i)
            -> one:
                 (   'i
                  -> ( [< `Read | `Set_and_create ]
                     , ('j, 'k) t
                     , 'j )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b) t
                  -> 'a
                  -> 'l)
            -> two:
                 (   'l
                  -> ( [< `Read | `Set_and_create ]
                     , ('m, 'n) t
                     , 'n )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b) t
                  -> 'b
                  -> 'o)
            -> 'o

          val for_all :
               ('a, 'b) t
            -> token_id:
                 (   ( [< `Read | `Set_and_create ]
                     , ('c, 'd) t
                     , Token_id.Stable.V1.t )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b) t
                  -> Token_id.Stable.V1.t
                  -> bool)
            -> fee_payment:
                 (   ( [< `Read | `Set_and_create ]
                     , ('e, 'f) t
                     , Other_fee_payer.Stable.V1.t option )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b) t
                  -> Other_fee_payer.Stable.V1.t option
                  -> bool)
            -> one:
                 (   ( [< `Read | `Set_and_create ]
                     , ('g, 'h) t
                     , 'g )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b) t
                  -> 'a
                  -> bool)
            -> two:
                 (   ( [< `Read | `Set_and_create ]
                     , ('i, 'j) t
                     , 'j )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b) t
                  -> 'b
                  -> bool)
            -> bool

          val exists :
               ('a, 'b) t
            -> token_id:
                 (   ( [< `Read | `Set_and_create ]
                     , ('c, 'd) t
                     , Token_id.Stable.V1.t )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b) t
                  -> Token_id.Stable.V1.t
                  -> bool)
            -> fee_payment:
                 (   ( [< `Read | `Set_and_create ]
                     , ('e, 'f) t
                     , Other_fee_payer.Stable.V1.t option )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b) t
                  -> Other_fee_payer.Stable.V1.t option
                  -> bool)
            -> one:
                 (   ( [< `Read | `Set_and_create ]
                     , ('g, 'h) t
                     , 'g )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b) t
                  -> 'a
                  -> bool)
            -> two:
                 (   ( [< `Read | `Set_and_create ]
                     , ('i, 'j) t
                     , 'j )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b) t
                  -> 'b
                  -> bool)
            -> bool

          val to_list :
               ('a, 'b) t
            -> token_id:
                 (   ( [< `Read | `Set_and_create ]
                     , ('c, 'd) t
                     , Token_id.Stable.V1.t )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b) t
                  -> Token_id.Stable.V1.t
                  -> 'e)
            -> fee_payment:
                 (   ( [< `Read | `Set_and_create ]
                     , ('f, 'g) t
                     , Other_fee_payer.Stable.V1.t option )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b) t
                  -> Other_fee_payer.Stable.V1.t option
                  -> 'e)
            -> one:
                 (   ( [< `Read | `Set_and_create ]
                     , ('h, 'i) t
                     , 'h )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b) t
                  -> 'a
                  -> 'e)
            -> two:
                 (   ( [< `Read | `Set_and_create ]
                     , ('j, 'k) t
                     , 'k )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b) t
                  -> 'b
                  -> 'e)
            -> 'e list

          val map :
               ('a, 'b) t
            -> token_id:
                 (   ( [< `Read | `Set_and_create ]
                     , ('c, 'd) t
                     , Token_id.Stable.V1.t )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b) t
                  -> Token_id.Stable.V1.t
                  -> Token_id.Stable.V1.t)
            -> fee_payment:
                 (   ( [< `Read | `Set_and_create ]
                     , ('e, 'f) t
                     , Other_fee_payer.Stable.V1.t option )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b) t
                  -> Other_fee_payer.Stable.V1.t option
                  -> Other_fee_payer.Stable.V1.t option)
            -> one:
                 (   ( [< `Read | `Set_and_create ]
                     , ('g, 'h) t
                     , 'g )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b) t
                  -> 'a
                  -> 'i)
            -> two:
                 (   ( [< `Read | `Set_and_create ]
                     , ('j, 'k) t
                     , 'k )
                     Fieldslib.Field.t_with_perm
                  -> ('a, 'b) t
                  -> 'b
                  -> 'l)
            -> ('i, 'l) t

          val set_all_mutable_fields : 'a -> unit
        end
      end

      val to_hlist :
           ('one, 'two) t
        -> ( unit
           ,    Token_id.Stable.V1.t
             -> Other_fee_payer.Stable.V1.t option
             -> 'one
             -> 'two
             -> unit )
           H_list.t

      val of_hlist :
           ( unit
           ,    Token_id.Stable.V1.t
             -> Other_fee_payer.Stable.V1.t option
             -> 'one
             -> 'two
             -> unit )
           H_list.t
        -> ('one, 'two) t

      module With_version : sig
        type ('one, 'two) typ = ('one, 'two) t

        val bin_shape_typ :
             Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t

        val bin_size_typ :
             'one Core_kernel.Bin_prot.Size.sizer
          -> 'two Core_kernel.Bin_prot.Size.sizer
          -> ('one, 'two) typ Core_kernel.Bin_prot.Size.sizer

        val bin_write_typ :
             'one Core_kernel.Bin_prot.Write.writer
          -> 'two Core_kernel.Bin_prot.Write.writer
          -> ('one, 'two) typ Core_kernel.Bin_prot.Write.writer

        val bin_writer_typ :
             'a Core_kernel.Bin_prot.Type_class.writer
          -> 'b Core_kernel.Bin_prot.Type_class.writer
          -> ('a, 'b) typ Core_kernel.Bin_prot.Type_class.writer

        val __bin_read_typ__ :
             'one Core_kernel.Bin_prot.Read.reader
          -> 'two Core_kernel.Bin_prot.Read.reader
          -> (int -> ('one, 'two) typ) Core_kernel.Bin_prot.Read.reader

        val bin_read_typ :
             'one Core_kernel.Bin_prot.Read.reader
          -> 'two Core_kernel.Bin_prot.Read.reader
          -> ('one, 'two) typ Core_kernel.Bin_prot.Read.reader

        val bin_reader_typ :
             'a Core_kernel.Bin_prot.Type_class.reader
          -> 'b Core_kernel.Bin_prot.Type_class.reader
          -> ('a, 'b) typ Core_kernel.Bin_prot.Type_class.reader

        val bin_typ :
             'a Core_kernel.Bin_prot.Type_class.t
          -> 'b Core_kernel.Bin_prot.Type_class.t
          -> ('a, 'b) typ Core_kernel.Bin_prot.Type_class.t

        type ('one, 'two) t = { version : int; t : ('one, 'two) typ }

        val bin_shape_t :
             Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t

        val bin_size_t :
             'one Core_kernel.Bin_prot.Size.sizer
          -> 'two Core_kernel.Bin_prot.Size.sizer
          -> ('one, 'two) t Core_kernel.Bin_prot.Size.sizer

        val bin_write_t :
             'one Core_kernel.Bin_prot.Write.writer
          -> 'two Core_kernel.Bin_prot.Write.writer
          -> ('one, 'two) t Core_kernel.Bin_prot.Write.writer

        val bin_writer_t :
             'a Core_kernel.Bin_prot.Type_class.writer
          -> 'b Core_kernel.Bin_prot.Type_class.writer
          -> ('a, 'b) t Core_kernel.Bin_prot.Type_class.writer

        val __bin_read_t__ :
             'one Core_kernel.Bin_prot.Read.reader
          -> 'two Core_kernel.Bin_prot.Read.reader
          -> (int -> ('one, 'two) t) Core_kernel.Bin_prot.Read.reader

        val bin_read_t :
             'one Core_kernel.Bin_prot.Read.reader
          -> 'two Core_kernel.Bin_prot.Read.reader
          -> ('one, 'two) t Core_kernel.Bin_prot.Read.reader

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

  type ('one, 'two) t = ('one, 'two) Stable.V1.t =
    { token_id : Token_id.t
    ; fee_payment : Other_fee_payer.t option
    ; one : 'one
    ; two : 'two
    }

  val to_yojson :
       ('one -> Yojson.Safe.t)
    -> ('two -> Yojson.Safe.t)
    -> ('one, 'two) t
    -> Yojson.Safe.t

  val of_yojson :
       (Yojson.Safe.t -> 'one Ppx_deriving_yojson_runtime.error_or)
    -> (Yojson.Safe.t -> 'two Ppx_deriving_yojson_runtime.error_or)
    -> Yojson.Safe.t
    -> ('one, 'two) t Ppx_deriving_yojson_runtime.error_or

  val t_of_sexp :
       (Ppx_sexp_conv_lib.Sexp.t -> 'one)
    -> (Ppx_sexp_conv_lib.Sexp.t -> 'two)
    -> Ppx_sexp_conv_lib.Sexp.t
    -> ('one, 'two) t

  val sexp_of_t :
       ('one -> Ppx_sexp_conv_lib.Sexp.t)
    -> ('two -> Ppx_sexp_conv_lib.Sexp.t)
    -> ('one, 'two) t
    -> Ppx_sexp_conv_lib.Sexp.t

  val equal :
       ('one -> 'one -> bool)
    -> ('two -> 'two -> bool)
    -> ('one, 'two) t
    -> ('one, 'two) t
    -> bool

  val hash_fold_t :
       (Ppx_hash_lib.Std.Hash.state -> 'one -> Ppx_hash_lib.Std.Hash.state)
    -> (Ppx_hash_lib.Std.Hash.state -> 'two -> Ppx_hash_lib.Std.Hash.state)
    -> Ppx_hash_lib.Std.Hash.state
    -> ('one, 'two) t
    -> Ppx_hash_lib.Std.Hash.state

  val compare :
       ('one -> 'one -> Core_kernel__.Import.int)
    -> ('two -> 'two -> Core_kernel__.Import.int)
    -> ('one, 'two) t
    -> ('one, 'two) t
    -> Core_kernel__.Import.int

  val two : ('a, 'b) t -> 'b

  val one : ('a, 'b) t -> 'a

  val fee_payment : ('a, 'b) t -> Other_fee_payer.t option

  val token_id : ('a, 'b) t -> Token_id.t

  module Fields : sig
    val names : string list

    val two :
      ( [< `Read | `Set_and_create ]
      , ('a, 'two) t
      , 'two )
      Fieldslib.Field.t_with_perm

    val one :
      ( [< `Read | `Set_and_create ]
      , ('one, 'a) t
      , 'one )
      Fieldslib.Field.t_with_perm

    val fee_payment :
      ( [< `Read | `Set_and_create ]
      , ('a, 'b) t
      , Other_fee_payer.t option )
      Fieldslib.Field.t_with_perm

    val token_id :
      ( [< `Read | `Set_and_create ]
      , ('a, 'b) t
      , Token_id.t )
      Fieldslib.Field.t_with_perm

    val make_creator :
         token_id:
           (   ( [< `Read | `Set_and_create ]
               , ('a, 'b) t
               , Token_id.t )
               Fieldslib.Field.t_with_perm
            -> 'c
            -> ('d -> Token_id.t) * 'e)
      -> fee_payment:
           (   ( [< `Read | `Set_and_create ]
               , ('f, 'g) t
               , Other_fee_payer.t option )
               Fieldslib.Field.t_with_perm
            -> 'e
            -> ('d -> Other_fee_payer.t option) * 'h)
      -> one:
           (   ( [< `Read | `Set_and_create ]
               , ('i, 'j) t
               , 'i )
               Fieldslib.Field.t_with_perm
            -> 'h
            -> ('d -> 'k) * 'l)
      -> two:
           (   ( [< `Read | `Set_and_create ]
               , ('m, 'n) t
               , 'n )
               Fieldslib.Field.t_with_perm
            -> 'l
            -> ('d -> 'o) * 'p)
      -> 'c
      -> ('d -> ('k, 'o) t) * 'p

    val create :
         token_id:Token_id.t
      -> fee_payment:Other_fee_payer.t option
      -> one:'a
      -> two:'b
      -> ('a, 'b) t

    val map :
         token_id:
           (   ( [< `Read | `Set_and_create ]
               , ('a, 'b) t
               , Token_id.t )
               Fieldslib.Field.t_with_perm
            -> Token_id.t)
      -> fee_payment:
           (   ( [< `Read | `Set_and_create ]
               , ('c, 'd) t
               , Other_fee_payer.t option )
               Fieldslib.Field.t_with_perm
            -> Other_fee_payer.t option)
      -> one:
           (   ( [< `Read | `Set_and_create ]
               , ('e, 'f) t
               , 'e )
               Fieldslib.Field.t_with_perm
            -> 'g)
      -> two:
           (   ( [< `Read | `Set_and_create ]
               , ('h, 'i) t
               , 'i )
               Fieldslib.Field.t_with_perm
            -> 'j)
      -> ('g, 'j) t

    val iter :
         token_id:
           (   ( [< `Read | `Set_and_create ]
               , ('a, 'b) t
               , Token_id.t )
               Fieldslib.Field.t_with_perm
            -> unit)
      -> fee_payment:
           (   ( [< `Read | `Set_and_create ]
               , ('c, 'd) t
               , Other_fee_payer.t option )
               Fieldslib.Field.t_with_perm
            -> unit)
      -> one:
           (   ( [< `Read | `Set_and_create ]
               , ('e, 'f) t
               , 'e )
               Fieldslib.Field.t_with_perm
            -> unit)
      -> two:
           (   ( [< `Read | `Set_and_create ]
               , ('g, 'h) t
               , 'h )
               Fieldslib.Field.t_with_perm
            -> unit)
      -> unit

    val fold :
         init:'a
      -> token_id:
           (   'a
            -> ( [< `Read | `Set_and_create ]
               , ('b, 'c) t
               , Token_id.t )
               Fieldslib.Field.t_with_perm
            -> 'd)
      -> fee_payment:
           (   'd
            -> ( [< `Read | `Set_and_create ]
               , ('e, 'f) t
               , Other_fee_payer.t option )
               Fieldslib.Field.t_with_perm
            -> 'g)
      -> one:
           (   'g
            -> ( [< `Read | `Set_and_create ]
               , ('h, 'i) t
               , 'h )
               Fieldslib.Field.t_with_perm
            -> 'j)
      -> two:
           (   'j
            -> ( [< `Read | `Set_and_create ]
               , ('k, 'l) t
               , 'l )
               Fieldslib.Field.t_with_perm
            -> 'm)
      -> 'm

    val map_poly :
         ([< `Read | `Set_and_create ], ('a, 'b) t, 'c) Fieldslib.Field.user
      -> 'c list

    val for_all :
         token_id:
           (   ( [< `Read | `Set_and_create ]
               , ('a, 'b) t
               , Token_id.t )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> fee_payment:
           (   ( [< `Read | `Set_and_create ]
               , ('c, 'd) t
               , Other_fee_payer.t option )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> one:
           (   ( [< `Read | `Set_and_create ]
               , ('e, 'f) t
               , 'e )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> two:
           (   ( [< `Read | `Set_and_create ]
               , ('g, 'h) t
               , 'h )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> bool

    val exists :
         token_id:
           (   ( [< `Read | `Set_and_create ]
               , ('a, 'b) t
               , Token_id.t )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> fee_payment:
           (   ( [< `Read | `Set_and_create ]
               , ('c, 'd) t
               , Other_fee_payer.t option )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> one:
           (   ( [< `Read | `Set_and_create ]
               , ('e, 'f) t
               , 'e )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> two:
           (   ( [< `Read | `Set_and_create ]
               , ('g, 'h) t
               , 'h )
               Fieldslib.Field.t_with_perm
            -> bool)
      -> bool

    val to_list :
         token_id:
           (   ( [< `Read | `Set_and_create ]
               , ('a, 'b) t
               , Token_id.t )
               Fieldslib.Field.t_with_perm
            -> 'c)
      -> fee_payment:
           (   ( [< `Read | `Set_and_create ]
               , ('d, 'e) t
               , Other_fee_payer.t option )
               Fieldslib.Field.t_with_perm
            -> 'c)
      -> one:
           (   ( [< `Read | `Set_and_create ]
               , ('f, 'g) t
               , 'f )
               Fieldslib.Field.t_with_perm
            -> 'c)
      -> two:
           (   ( [< `Read | `Set_and_create ]
               , ('h, 'i) t
               , 'i )
               Fieldslib.Field.t_with_perm
            -> 'c)
      -> 'c list

    module Direct : sig
      val iter :
           ('a, 'b) t
        -> token_id:
             (   ( [< `Read | `Set_and_create ]
                 , ('c, 'd) t
                 , Token_id.t )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b) t
              -> Token_id.t
              -> unit)
        -> fee_payment:
             (   ( [< `Read | `Set_and_create ]
                 , ('e, 'f) t
                 , Other_fee_payer.t option )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b) t
              -> Other_fee_payer.t option
              -> unit)
        -> one:
             (   ( [< `Read | `Set_and_create ]
                 , ('g, 'h) t
                 , 'g )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b) t
              -> 'a
              -> unit)
        -> two:
             (   ( [< `Read | `Set_and_create ]
                 , ('i, 'j) t
                 , 'j )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b) t
              -> 'b
              -> 'k)
        -> 'k

      val fold :
           ('a, 'b) t
        -> init:'c
        -> token_id:
             (   'c
              -> ( [< `Read | `Set_and_create ]
                 , ('d, 'e) t
                 , Token_id.t )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b) t
              -> Token_id.t
              -> 'f)
        -> fee_payment:
             (   'f
              -> ( [< `Read | `Set_and_create ]
                 , ('g, 'h) t
                 , Other_fee_payer.t option )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b) t
              -> Other_fee_payer.t option
              -> 'i)
        -> one:
             (   'i
              -> ( [< `Read | `Set_and_create ]
                 , ('j, 'k) t
                 , 'j )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b) t
              -> 'a
              -> 'l)
        -> two:
             (   'l
              -> ( [< `Read | `Set_and_create ]
                 , ('m, 'n) t
                 , 'n )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b) t
              -> 'b
              -> 'o)
        -> 'o

      val for_all :
           ('a, 'b) t
        -> token_id:
             (   ( [< `Read | `Set_and_create ]
                 , ('c, 'd) t
                 , Token_id.t )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b) t
              -> Token_id.t
              -> bool)
        -> fee_payment:
             (   ( [< `Read | `Set_and_create ]
                 , ('e, 'f) t
                 , Other_fee_payer.t option )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b) t
              -> Other_fee_payer.t option
              -> bool)
        -> one:
             (   ( [< `Read | `Set_and_create ]
                 , ('g, 'h) t
                 , 'g )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b) t
              -> 'a
              -> bool)
        -> two:
             (   ( [< `Read | `Set_and_create ]
                 , ('i, 'j) t
                 , 'j )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b) t
              -> 'b
              -> bool)
        -> bool

      val exists :
           ('a, 'b) t
        -> token_id:
             (   ( [< `Read | `Set_and_create ]
                 , ('c, 'd) t
                 , Token_id.t )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b) t
              -> Token_id.t
              -> bool)
        -> fee_payment:
             (   ( [< `Read | `Set_and_create ]
                 , ('e, 'f) t
                 , Other_fee_payer.t option )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b) t
              -> Other_fee_payer.t option
              -> bool)
        -> one:
             (   ( [< `Read | `Set_and_create ]
                 , ('g, 'h) t
                 , 'g )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b) t
              -> 'a
              -> bool)
        -> two:
             (   ( [< `Read | `Set_and_create ]
                 , ('i, 'j) t
                 , 'j )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b) t
              -> 'b
              -> bool)
        -> bool

      val to_list :
           ('a, 'b) t
        -> token_id:
             (   ( [< `Read | `Set_and_create ]
                 , ('c, 'd) t
                 , Token_id.t )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b) t
              -> Token_id.t
              -> 'e)
        -> fee_payment:
             (   ( [< `Read | `Set_and_create ]
                 , ('f, 'g) t
                 , Other_fee_payer.t option )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b) t
              -> Other_fee_payer.t option
              -> 'e)
        -> one:
             (   ( [< `Read | `Set_and_create ]
                 , ('h, 'i) t
                 , 'h )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b) t
              -> 'a
              -> 'e)
        -> two:
             (   ( [< `Read | `Set_and_create ]
                 , ('j, 'k) t
                 , 'k )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b) t
              -> 'b
              -> 'e)
        -> 'e list

      val map :
           ('a, 'b) t
        -> token_id:
             (   ( [< `Read | `Set_and_create ]
                 , ('c, 'd) t
                 , Token_id.t )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b) t
              -> Token_id.t
              -> Token_id.t)
        -> fee_payment:
             (   ( [< `Read | `Set_and_create ]
                 , ('e, 'f) t
                 , Other_fee_payer.t option )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b) t
              -> Other_fee_payer.t option
              -> Other_fee_payer.t option)
        -> one:
             (   ( [< `Read | `Set_and_create ]
                 , ('g, 'h) t
                 , 'g )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b) t
              -> 'a
              -> 'i)
        -> two:
             (   ( [< `Read | `Set_and_create ]
                 , ('j, 'k) t
                 , 'k )
                 Fieldslib.Field.t_with_perm
              -> ('a, 'b) t
              -> 'b
              -> 'l)
        -> ('i, 'l) t

      val set_all_mutable_fields : 'a -> unit
    end
  end

  val to_hlist :
       ('one, 'two) t
    -> ( unit
       , Token_id.t -> Other_fee_payer.t option -> 'one -> 'two -> unit )
       H_list.t

  val of_hlist :
       ( unit
       , Token_id.t -> Other_fee_payer.t option -> 'one -> 'two -> unit )
       H_list.t
    -> ('one, 'two) t
end

module Binable_arg : sig
  module Stable : sig
    module V1 : sig
      type t =
        | Proved_empty of
            ( Party.Authorized.Proved.Stable.V1.t
            , Party.Authorized.Empty.Stable.V1.t option )
            Inner.t
        | Proved_signed of
            ( Party.Authorized.Proved.Stable.V1.t
            , Party.Authorized.Signed.Stable.V1.t )
            Inner.t
        | Proved_proved of
            ( Party.Authorized.Proved.Stable.V1.t
            , Party.Authorized.Proved.Stable.V1.t )
            Inner.t
        | Signed_signed of
            ( Party.Authorized.Signed.Stable.V1.t
            , Party.Authorized.Signed.Stable.V1.t )
            Inner.t
        | Signed_empty of
            ( Party.Authorized.Signed.Stable.V1.t
            , Party.Authorized.Empty.Stable.V1.t option )
            Inner.t

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

      val description : string

      val version_byte : Base58_check.Version_bytes.t

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
    | Proved_empty of
        (Party.Authorized.Proved.t, Party.Authorized.Empty.t option) Inner.t
    | Proved_signed of
        (Party.Authorized.Proved.t, Party.Authorized.Signed.t) Inner.t
    | Proved_proved of
        (Party.Authorized.Proved.t, Party.Authorized.Proved.t) Inner.t
    | Signed_signed of
        (Party.Authorized.Signed.t, Party.Authorized.Signed.t) Inner.t
    | Signed_empty of
        (Party.Authorized.Signed.t, Party.Authorized.Empty.t option) Inner.t

  val to_yojson : t -> Yojson.Safe.t

  val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

  val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

  val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

  val equal : t -> t -> bool

  val hash_fold_t :
    Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

  val hash : t -> Ppx_hash_lib.Std.Hash.hash_value

  val compare : t -> t -> int
end

module Stable = Binable_arg.Stable

type t = Binable_arg.t =
  | Proved_empty of
      (Party.Authorized.Proved.t, Party.Authorized.Empty.t option) Inner.t
  | Proved_signed of
      (Party.Authorized.Proved.t, Party.Authorized.Signed.t) Inner.t
  | Proved_proved of
      (Party.Authorized.Proved.t, Party.Authorized.Proved.t) Inner.t
  | Signed_signed of
      (Party.Authorized.Signed.t, Party.Authorized.Signed.t) Inner.t
  | Signed_empty of
      (Party.Authorized.Signed.t, Party.Authorized.Empty.t option) Inner.t

val to_yojson : t -> Yojson.Safe.t

val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

val equal : t -> t -> bool

val hash_fold_t :
  Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

val hash : t -> Ppx_hash_lib.Std.Hash.hash_value

val compare : t -> t -> int

type transfer =
  { source : Signature_lib.Public_key.Compressed.t
  ; receiver : Signature_lib.Public_key.Compressed.t
  ; amount : Currency.Amount.t
  }

val token_id : t -> Token_id.t

val assert_ :
  bool -> string -> (unit, Core_kernel__.Error.t) Core_kernel._result

val is_non_neg : Currency.Amount.Signed.t -> bool

val is_non_pos : Currency.Amount.Signed.t -> bool

val is_neg : Currency.Amount.Signed.t -> bool

val check_non_positive :
  Currency.Amount.Signed.t -> (unit, Core_kernel__.Error.t) Core_kernel._result

val signed_to_non_positive :
  Currency.Amount.Signed.t -> Currency.Amount.t Base__Or_error.t

val fee_token : t -> Token_id.t

val check_tokens : t -> bool

val native_excess_exn : t -> Account_id.t * Currency.Amount.t

val fee_payer : t -> Account_id.t

val fee_payment : t -> Other_fee_payer.t option

val fee_exn : t -> Currency.Fee.t

val as_transfer : t -> transfer

val native_excess : t -> (Account_id.t * Currency.Amount.t) option

val fee_excess : t -> Fee_excess.t Core_kernel.Or_error.t

val accounts_accessed : t -> Account_id.t list

val next_available_token : t -> Token_id.t -> Token_id.t

module Valid : sig
  module Stable : sig
    module V1 : sig
      type t = Binable_arg.t

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
      (int * (Core_kernel.Bigstring.t -> pos_ref:int Core_kernel.ref -> t))
      array

    val bin_read_to_latest_opt :
         Bin_prot.Common.buf
      -> pos_ref:Bin_prot.Common.pos Core_kernel.ref
      -> t option

    val __ :
         Bin_prot.Common.buf
      -> pos_ref:Bin_prot.Common.pos Core_kernel.ref
      -> t option
  end

  type t = Binable_arg.t

  val to_yojson : t -> Yojson.Safe.t

  val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

  val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

  val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

  val equal : t -> t -> bool

  val hash_fold_t :
    Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

  val hash : t -> Ppx_hash_lib.Std.Hash.hash_value

  val compare : t -> t -> int
end

module Payload : sig
  module Inner : sig
    module Stable : sig
      module V1 : sig
        type ('bool, 'token_id, 'fee_payer_opt, 'one, 'two) t =
          { second_starts_empty : 'bool
          ; second_ends_empty : 'bool
          ; token_id : 'token_id
          ; other_fee_payer_opt : 'fee_payer_opt
          ; one : 'one
          ; two : 'two
          }

        val to_yojson :
             ('bool -> Yojson.Safe.t)
          -> ('token_id -> Yojson.Safe.t)
          -> ('fee_payer_opt -> Yojson.Safe.t)
          -> ('one -> Yojson.Safe.t)
          -> ('two -> Yojson.Safe.t)
          -> ('bool, 'token_id, 'fee_payer_opt, 'one, 'two) t
          -> Yojson.Safe.t

        val of_yojson :
             (Yojson.Safe.t -> 'bool Ppx_deriving_yojson_runtime.error_or)
          -> (Yojson.Safe.t -> 'token_id Ppx_deriving_yojson_runtime.error_or)
          -> (   Yojson.Safe.t
              -> 'fee_payer_opt Ppx_deriving_yojson_runtime.error_or)
          -> (Yojson.Safe.t -> 'one Ppx_deriving_yojson_runtime.error_or)
          -> (Yojson.Safe.t -> 'two Ppx_deriving_yojson_runtime.error_or)
          -> Yojson.Safe.t
          -> ('bool, 'token_id, 'fee_payer_opt, 'one, 'two) t
             Ppx_deriving_yojson_runtime.error_or

        val version : int

        val __versioned__ : unit

        val to_hlist :
             ('bool, 'token_id, 'fee_payer_opt, 'one, 'two) t
          -> ( unit
             ,    'bool
               -> 'bool
               -> 'token_id
               -> 'fee_payer_opt
               -> 'one
               -> 'two
               -> unit )
             H_list.t

        val of_hlist :
             ( unit
             ,    'bool
               -> 'bool
               -> 'token_id
               -> 'fee_payer_opt
               -> 'one
               -> 'two
               -> unit )
             H_list.t
          -> ('bool, 'token_id, 'fee_payer_opt, 'one, 'two) t

        val t_of_sexp :
             (Ppx_sexp_conv_lib.Sexp.t -> 'bool)
          -> (Ppx_sexp_conv_lib.Sexp.t -> 'token_id)
          -> (Ppx_sexp_conv_lib.Sexp.t -> 'fee_payer_opt)
          -> (Ppx_sexp_conv_lib.Sexp.t -> 'one)
          -> (Ppx_sexp_conv_lib.Sexp.t -> 'two)
          -> Ppx_sexp_conv_lib.Sexp.t
          -> ('bool, 'token_id, 'fee_payer_opt, 'one, 'two) t

        val sexp_of_t :
             ('bool -> Ppx_sexp_conv_lib.Sexp.t)
          -> ('token_id -> Ppx_sexp_conv_lib.Sexp.t)
          -> ('fee_payer_opt -> Ppx_sexp_conv_lib.Sexp.t)
          -> ('one -> Ppx_sexp_conv_lib.Sexp.t)
          -> ('two -> Ppx_sexp_conv_lib.Sexp.t)
          -> ('bool, 'token_id, 'fee_payer_opt, 'one, 'two) t
          -> Ppx_sexp_conv_lib.Sexp.t

        val equal :
             ('bool -> 'bool -> bool)
          -> ('token_id -> 'token_id -> bool)
          -> ('fee_payer_opt -> 'fee_payer_opt -> bool)
          -> ('one -> 'one -> bool)
          -> ('two -> 'two -> bool)
          -> ('bool, 'token_id, 'fee_payer_opt, 'one, 'two) t
          -> ('bool, 'token_id, 'fee_payer_opt, 'one, 'two) t
          -> bool

        val hash_fold_t :
             (   Ppx_hash_lib.Std.Hash.state
              -> 'bool
              -> Ppx_hash_lib.Std.Hash.state)
          -> (   Ppx_hash_lib.Std.Hash.state
              -> 'token_id
              -> Ppx_hash_lib.Std.Hash.state)
          -> (   Ppx_hash_lib.Std.Hash.state
              -> 'fee_payer_opt
              -> Ppx_hash_lib.Std.Hash.state)
          -> (   Ppx_hash_lib.Std.Hash.state
              -> 'one
              -> Ppx_hash_lib.Std.Hash.state)
          -> (   Ppx_hash_lib.Std.Hash.state
              -> 'two
              -> Ppx_hash_lib.Std.Hash.state)
          -> Ppx_hash_lib.Std.Hash.state
          -> ('bool, 'token_id, 'fee_payer_opt, 'one, 'two) t
          -> Ppx_hash_lib.Std.Hash.state

        val compare :
             ('bool -> 'bool -> int)
          -> ('token_id -> 'token_id -> int)
          -> ('fee_payer_opt -> 'fee_payer_opt -> int)
          -> ('one -> 'one -> int)
          -> ('two -> 'two -> int)
          -> ('bool, 'token_id, 'fee_payer_opt, 'one, 'two) t
          -> ('bool, 'token_id, 'fee_payer_opt, 'one, 'two) t
          -> int

        module With_version : sig
          type ('bool, 'token_id, 'fee_payer_opt, 'one, 'two) typ =
            ('bool, 'token_id, 'fee_payer_opt, 'one, 'two) t

          val bin_shape_typ :
               Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t

          val bin_size_typ :
               'bool Core_kernel.Bin_prot.Size.sizer
            -> 'token_id Core_kernel.Bin_prot.Size.sizer
            -> 'fee_payer_opt Core_kernel.Bin_prot.Size.sizer
            -> 'one Core_kernel.Bin_prot.Size.sizer
            -> 'two Core_kernel.Bin_prot.Size.sizer
            -> ('bool, 'token_id, 'fee_payer_opt, 'one, 'two) typ
               Core_kernel.Bin_prot.Size.sizer

          val bin_write_typ :
               'bool Core_kernel.Bin_prot.Write.writer
            -> 'token_id Core_kernel.Bin_prot.Write.writer
            -> 'fee_payer_opt Core_kernel.Bin_prot.Write.writer
            -> 'one Core_kernel.Bin_prot.Write.writer
            -> 'two Core_kernel.Bin_prot.Write.writer
            -> ('bool, 'token_id, 'fee_payer_opt, 'one, 'two) typ
               Core_kernel.Bin_prot.Write.writer

          val bin_writer_typ :
               'a Core_kernel.Bin_prot.Type_class.writer
            -> 'b Core_kernel.Bin_prot.Type_class.writer
            -> 'c Core_kernel.Bin_prot.Type_class.writer
            -> 'd Core_kernel.Bin_prot.Type_class.writer
            -> 'e Core_kernel.Bin_prot.Type_class.writer
            -> ('a, 'b, 'c, 'd, 'e) typ Core_kernel.Bin_prot.Type_class.writer

          val __bin_read_typ__ :
               'bool Core_kernel.Bin_prot.Read.reader
            -> 'token_id Core_kernel.Bin_prot.Read.reader
            -> 'fee_payer_opt Core_kernel.Bin_prot.Read.reader
            -> 'one Core_kernel.Bin_prot.Read.reader
            -> 'two Core_kernel.Bin_prot.Read.reader
            -> (int -> ('bool, 'token_id, 'fee_payer_opt, 'one, 'two) typ)
               Core_kernel.Bin_prot.Read.reader

          val bin_read_typ :
               'bool Core_kernel.Bin_prot.Read.reader
            -> 'token_id Core_kernel.Bin_prot.Read.reader
            -> 'fee_payer_opt Core_kernel.Bin_prot.Read.reader
            -> 'one Core_kernel.Bin_prot.Read.reader
            -> 'two Core_kernel.Bin_prot.Read.reader
            -> ('bool, 'token_id, 'fee_payer_opt, 'one, 'two) typ
               Core_kernel.Bin_prot.Read.reader

          val bin_reader_typ :
               'a Core_kernel.Bin_prot.Type_class.reader
            -> 'b Core_kernel.Bin_prot.Type_class.reader
            -> 'c Core_kernel.Bin_prot.Type_class.reader
            -> 'd Core_kernel.Bin_prot.Type_class.reader
            -> 'e Core_kernel.Bin_prot.Type_class.reader
            -> ('a, 'b, 'c, 'd, 'e) typ Core_kernel.Bin_prot.Type_class.reader

          val bin_typ :
               'a Core_kernel.Bin_prot.Type_class.t
            -> 'b Core_kernel.Bin_prot.Type_class.t
            -> 'c Core_kernel.Bin_prot.Type_class.t
            -> 'd Core_kernel.Bin_prot.Type_class.t
            -> 'e Core_kernel.Bin_prot.Type_class.t
            -> ('a, 'b, 'c, 'd, 'e) typ Core_kernel.Bin_prot.Type_class.t

          type ('bool, 'token_id, 'fee_payer_opt, 'one, 'two) t =
            { version : int
            ; t : ('bool, 'token_id, 'fee_payer_opt, 'one, 'two) typ
            }

          val bin_shape_t :
               Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t

          val bin_size_t :
               'bool Core_kernel.Bin_prot.Size.sizer
            -> 'token_id Core_kernel.Bin_prot.Size.sizer
            -> 'fee_payer_opt Core_kernel.Bin_prot.Size.sizer
            -> 'one Core_kernel.Bin_prot.Size.sizer
            -> 'two Core_kernel.Bin_prot.Size.sizer
            -> ('bool, 'token_id, 'fee_payer_opt, 'one, 'two) t
               Core_kernel.Bin_prot.Size.sizer

          val bin_write_t :
               'bool Core_kernel.Bin_prot.Write.writer
            -> 'token_id Core_kernel.Bin_prot.Write.writer
            -> 'fee_payer_opt Core_kernel.Bin_prot.Write.writer
            -> 'one Core_kernel.Bin_prot.Write.writer
            -> 'two Core_kernel.Bin_prot.Write.writer
            -> ('bool, 'token_id, 'fee_payer_opt, 'one, 'two) t
               Core_kernel.Bin_prot.Write.writer

          val bin_writer_t :
               'a Core_kernel.Bin_prot.Type_class.writer
            -> 'b Core_kernel.Bin_prot.Type_class.writer
            -> 'c Core_kernel.Bin_prot.Type_class.writer
            -> 'd Core_kernel.Bin_prot.Type_class.writer
            -> 'e Core_kernel.Bin_prot.Type_class.writer
            -> ('a, 'b, 'c, 'd, 'e) t Core_kernel.Bin_prot.Type_class.writer

          val __bin_read_t__ :
               'bool Core_kernel.Bin_prot.Read.reader
            -> 'token_id Core_kernel.Bin_prot.Read.reader
            -> 'fee_payer_opt Core_kernel.Bin_prot.Read.reader
            -> 'one Core_kernel.Bin_prot.Read.reader
            -> 'two Core_kernel.Bin_prot.Read.reader
            -> (int -> ('bool, 'token_id, 'fee_payer_opt, 'one, 'two) t)
               Core_kernel.Bin_prot.Read.reader

          val bin_read_t :
               'bool Core_kernel.Bin_prot.Read.reader
            -> 'token_id Core_kernel.Bin_prot.Read.reader
            -> 'fee_payer_opt Core_kernel.Bin_prot.Read.reader
            -> 'one Core_kernel.Bin_prot.Read.reader
            -> 'two Core_kernel.Bin_prot.Read.reader
            -> ('bool, 'token_id, 'fee_payer_opt, 'one, 'two) t
               Core_kernel.Bin_prot.Read.reader

          val bin_reader_t :
               'a Core_kernel.Bin_prot.Type_class.reader
            -> 'b Core_kernel.Bin_prot.Type_class.reader
            -> 'c Core_kernel.Bin_prot.Type_class.reader
            -> 'd Core_kernel.Bin_prot.Type_class.reader
            -> 'e Core_kernel.Bin_prot.Type_class.reader
            -> ('a, 'b, 'c, 'd, 'e) t Core_kernel.Bin_prot.Type_class.reader

          val bin_t :
               'a Core_kernel.Bin_prot.Type_class.t
            -> 'b Core_kernel.Bin_prot.Type_class.t
            -> 'c Core_kernel.Bin_prot.Type_class.t
            -> 'd Core_kernel.Bin_prot.Type_class.t
            -> 'e Core_kernel.Bin_prot.Type_class.t
            -> ('a, 'b, 'c, 'd, 'e) t Core_kernel.Bin_prot.Type_class.t

          val create : ('a, 'b, 'c, 'd, 'e) typ -> ('a, 'b, 'c, 'd, 'e) t
        end

        val bin_read_t :
             'a Core_kernel.Bin_prot.Read.reader
          -> 'b Core_kernel.Bin_prot.Read.reader
          -> 'c Core_kernel.Bin_prot.Read.reader
          -> 'd Core_kernel.Bin_prot.Read.reader
          -> 'e Core_kernel.Bin_prot.Read.reader
          -> Bin_prot.Common.buf
          -> pos_ref:Bin_prot.Common.pos_ref
          -> ('a, 'b, 'c, 'd, 'e) t

        val __bin_read_t__ :
             'a Core_kernel.Bin_prot.Read.reader
          -> 'b Core_kernel.Bin_prot.Read.reader
          -> 'c Core_kernel.Bin_prot.Read.reader
          -> 'd Core_kernel.Bin_prot.Read.reader
          -> 'e Core_kernel.Bin_prot.Read.reader
          -> Bin_prot.Common.buf
          -> pos_ref:Bin_prot.Common.pos_ref
          -> int
          -> ('a, 'b, 'c, 'd, 'e) t

        val bin_size_t :
             'a Core_kernel.Bin_prot.Size.sizer
          -> 'b Core_kernel.Bin_prot.Size.sizer
          -> 'c Core_kernel.Bin_prot.Size.sizer
          -> 'd Core_kernel.Bin_prot.Size.sizer
          -> 'e Core_kernel.Bin_prot.Size.sizer
          -> ('a, 'b, 'c, 'd, 'e) t
          -> int

        val bin_write_t :
             'a Core_kernel.Bin_prot.Write.writer
          -> 'b Core_kernel.Bin_prot.Write.writer
          -> 'c Core_kernel.Bin_prot.Write.writer
          -> 'd Core_kernel.Bin_prot.Write.writer
          -> 'e Core_kernel.Bin_prot.Write.writer
          -> Bin_prot.Common.buf
          -> pos:Bin_prot.Common.pos
          -> ('a, 'b, 'c, 'd, 'e) t
          -> Bin_prot.Common.pos

        val bin_shape_t :
             Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t

        val bin_reader_t :
             'a Core_kernel.Bin_prot.Type_class.reader
          -> 'b Core_kernel.Bin_prot.Type_class.reader
          -> 'c Core_kernel.Bin_prot.Type_class.reader
          -> 'd Core_kernel.Bin_prot.Type_class.reader
          -> 'e Core_kernel.Bin_prot.Type_class.reader
          -> ('a, 'b, 'c, 'd, 'e) t Core_kernel.Bin_prot.Type_class.reader

        val bin_writer_t :
             'a Core_kernel.Bin_prot.Type_class.writer
          -> 'b Core_kernel.Bin_prot.Type_class.writer
          -> 'c Core_kernel.Bin_prot.Type_class.writer
          -> 'd Core_kernel.Bin_prot.Type_class.writer
          -> 'e Core_kernel.Bin_prot.Type_class.writer
          -> ('a, 'b, 'c, 'd, 'e) t Core_kernel.Bin_prot.Type_class.writer

        val bin_t :
             'a Core_kernel.Bin_prot.Type_class.t
          -> 'b Core_kernel.Bin_prot.Type_class.t
          -> 'c Core_kernel.Bin_prot.Type_class.t
          -> 'd Core_kernel.Bin_prot.Type_class.t
          -> 'e Core_kernel.Bin_prot.Type_class.t
          -> ('a, 'b, 'c, 'd, 'e) t Core_kernel.Bin_prot.Type_class.t

        val __ :
          (   'a Core_kernel.Bin_prot.Read.reader
           -> 'b Core_kernel.Bin_prot.Read.reader
           -> 'c Core_kernel.Bin_prot.Read.reader
           -> 'd Core_kernel.Bin_prot.Read.reader
           -> 'e Core_kernel.Bin_prot.Read.reader
           -> Bin_prot.Common.buf
           -> pos_ref:Bin_prot.Common.pos_ref
           -> ('a, 'b, 'c, 'd, 'e) t)
          * (   'f Core_kernel.Bin_prot.Read.reader
             -> 'g Core_kernel.Bin_prot.Read.reader
             -> 'h Core_kernel.Bin_prot.Read.reader
             -> 'i Core_kernel.Bin_prot.Read.reader
             -> 'j Core_kernel.Bin_prot.Read.reader
             -> Bin_prot.Common.buf
             -> pos_ref:Bin_prot.Common.pos_ref
             -> int
             -> ('f, 'g, 'h, 'i, 'j) t)
          * (   'k Core_kernel.Bin_prot.Size.sizer
             -> 'l Core_kernel.Bin_prot.Size.sizer
             -> 'm Core_kernel.Bin_prot.Size.sizer
             -> 'n Core_kernel.Bin_prot.Size.sizer
             -> 'o Core_kernel.Bin_prot.Size.sizer
             -> ('k, 'l, 'm, 'n, 'o) t
             -> int)
          * (   'p Core_kernel.Bin_prot.Write.writer
             -> 'q Core_kernel.Bin_prot.Write.writer
             -> 'r Core_kernel.Bin_prot.Write.writer
             -> 's Core_kernel.Bin_prot.Write.writer
             -> 't Core_kernel.Bin_prot.Write.writer
             -> Bin_prot.Common.buf
             -> pos:Bin_prot.Common.pos
             -> ('p, 'q, 'r, 's, 't) t
             -> Bin_prot.Common.pos)
          * (   Core_kernel.Bin_prot.Shape.t
             -> Core_kernel.Bin_prot.Shape.t
             -> Core_kernel.Bin_prot.Shape.t
             -> Core_kernel.Bin_prot.Shape.t
             -> Core_kernel.Bin_prot.Shape.t
             -> Core_kernel.Bin_prot.Shape.t)
          * (   'u Core_kernel.Bin_prot.Type_class.reader
             -> 'v Core_kernel.Bin_prot.Type_class.reader
             -> 'w Core_kernel.Bin_prot.Type_class.reader
             -> 'x Core_kernel.Bin_prot.Type_class.reader
             -> 'y Core_kernel.Bin_prot.Type_class.reader
             -> ('u, 'v, 'w, 'x, 'y) t Core_kernel.Bin_prot.Type_class.reader)
          * (   'z Core_kernel.Bin_prot.Type_class.writer
             -> 'a1 Core_kernel.Bin_prot.Type_class.writer
             -> 'b1 Core_kernel.Bin_prot.Type_class.writer
             -> 'c1 Core_kernel.Bin_prot.Type_class.writer
             -> 'd1 Core_kernel.Bin_prot.Type_class.writer
             -> ('z, 'a1, 'b1, 'c1, 'd1) t
                Core_kernel.Bin_prot.Type_class.writer)
          * (   'e1 Core_kernel.Bin_prot.Type_class.t
             -> 'f1 Core_kernel.Bin_prot.Type_class.t
             -> 'g1 Core_kernel.Bin_prot.Type_class.t
             -> 'h1 Core_kernel.Bin_prot.Type_class.t
             -> 'i1 Core_kernel.Bin_prot.Type_class.t
             -> ('e1, 'f1, 'g1, 'h1, 'i1) t Core_kernel.Bin_prot.Type_class.t)
      end

      module Latest = V1
    end

    type ('bool, 'token_id, 'fee_payer_opt, 'one, 'two) t =
          ('bool, 'token_id, 'fee_payer_opt, 'one, 'two) Stable.V1.t =
      { second_starts_empty : 'bool
      ; second_ends_empty : 'bool
      ; token_id : 'token_id
      ; other_fee_payer_opt : 'fee_payer_opt
      ; one : 'one
      ; two : 'two
      }

    val to_yojson :
         ('bool -> Yojson.Safe.t)
      -> ('token_id -> Yojson.Safe.t)
      -> ('fee_payer_opt -> Yojson.Safe.t)
      -> ('one -> Yojson.Safe.t)
      -> ('two -> Yojson.Safe.t)
      -> ('bool, 'token_id, 'fee_payer_opt, 'one, 'two) t
      -> Yojson.Safe.t

    val of_yojson :
         (Yojson.Safe.t -> 'bool Ppx_deriving_yojson_runtime.error_or)
      -> (Yojson.Safe.t -> 'token_id Ppx_deriving_yojson_runtime.error_or)
      -> (Yojson.Safe.t -> 'fee_payer_opt Ppx_deriving_yojson_runtime.error_or)
      -> (Yojson.Safe.t -> 'one Ppx_deriving_yojson_runtime.error_or)
      -> (Yojson.Safe.t -> 'two Ppx_deriving_yojson_runtime.error_or)
      -> Yojson.Safe.t
      -> ('bool, 'token_id, 'fee_payer_opt, 'one, 'two) t
         Ppx_deriving_yojson_runtime.error_or

    val to_hlist :
         ('bool, 'token_id, 'fee_payer_opt, 'one, 'two) t
      -> ( unit
         , 'bool -> 'bool -> 'token_id -> 'fee_payer_opt -> 'one -> 'two -> unit
         )
         H_list.t

    val of_hlist :
         ( unit
         , 'bool -> 'bool -> 'token_id -> 'fee_payer_opt -> 'one -> 'two -> unit
         )
         H_list.t
      -> ('bool, 'token_id, 'fee_payer_opt, 'one, 'two) t

    val t_of_sexp :
         (Ppx_sexp_conv_lib.Sexp.t -> 'bool)
      -> (Ppx_sexp_conv_lib.Sexp.t -> 'token_id)
      -> (Ppx_sexp_conv_lib.Sexp.t -> 'fee_payer_opt)
      -> (Ppx_sexp_conv_lib.Sexp.t -> 'one)
      -> (Ppx_sexp_conv_lib.Sexp.t -> 'two)
      -> Ppx_sexp_conv_lib.Sexp.t
      -> ('bool, 'token_id, 'fee_payer_opt, 'one, 'two) t

    val sexp_of_t :
         ('bool -> Ppx_sexp_conv_lib.Sexp.t)
      -> ('token_id -> Ppx_sexp_conv_lib.Sexp.t)
      -> ('fee_payer_opt -> Ppx_sexp_conv_lib.Sexp.t)
      -> ('one -> Ppx_sexp_conv_lib.Sexp.t)
      -> ('two -> Ppx_sexp_conv_lib.Sexp.t)
      -> ('bool, 'token_id, 'fee_payer_opt, 'one, 'two) t
      -> Ppx_sexp_conv_lib.Sexp.t

    val equal :
         ('bool -> 'bool -> bool)
      -> ('token_id -> 'token_id -> bool)
      -> ('fee_payer_opt -> 'fee_payer_opt -> bool)
      -> ('one -> 'one -> bool)
      -> ('two -> 'two -> bool)
      -> ('bool, 'token_id, 'fee_payer_opt, 'one, 'two) t
      -> ('bool, 'token_id, 'fee_payer_opt, 'one, 'two) t
      -> bool

    val hash_fold_t :
         (Ppx_hash_lib.Std.Hash.state -> 'bool -> Ppx_hash_lib.Std.Hash.state)
      -> (   Ppx_hash_lib.Std.Hash.state
          -> 'token_id
          -> Ppx_hash_lib.Std.Hash.state)
      -> (   Ppx_hash_lib.Std.Hash.state
          -> 'fee_payer_opt
          -> Ppx_hash_lib.Std.Hash.state)
      -> (Ppx_hash_lib.Std.Hash.state -> 'one -> Ppx_hash_lib.Std.Hash.state)
      -> (Ppx_hash_lib.Std.Hash.state -> 'two -> Ppx_hash_lib.Std.Hash.state)
      -> Ppx_hash_lib.Std.Hash.state
      -> ('bool, 'token_id, 'fee_payer_opt, 'one, 'two) t
      -> Ppx_hash_lib.Std.Hash.state

    val compare :
         ('bool -> 'bool -> int)
      -> ('token_id -> 'token_id -> int)
      -> ('fee_payer_opt -> 'fee_payer_opt -> int)
      -> ('one -> 'one -> int)
      -> ('two -> 'two -> int)
      -> ('bool, 'token_id, 'fee_payer_opt, 'one, 'two) t
      -> ('bool, 'token_id, 'fee_payer_opt, 'one, 'two) t
      -> int

    val typ :
         ( unit
         , unit
         , 'a -> 'a -> 'b -> 'c -> 'd -> 'e -> unit
         , 'f -> 'f -> 'g -> 'h -> 'i -> 'j -> unit )
         Pickles__Impls.Step.Impl.Internal_Basic.Data_spec.t
      -> ( ('a, 'b, 'c, 'd, 'e) t
         , ('f, 'g, 'h, 'i, 'j) t )
         Snark_params.Tick.Typ.t
  end

  module Zero_proved : sig
    module Stable : sig
      module V1 : sig
        type t =
          ( bool
          , Token_id.Stable.V1.t
          , Other_fee_payer.Payload.Stable.V1.t option
          , Party.Predicated.Signed.Stable.V1.t
          , Party.Predicated.Signed.Stable.V1.t )
          Inner.t

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
        * (Core_kernel.Bigstring.t -> pos_ref:int Core_kernel.ref -> Latest.t)
        )
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

    module Digested : sig
      type t =
        ( bool
        , Token_id.t
        , Other_fee_payer.Payload.t option
        , Party.Predicated.Signed.Digested.t
        , Party.Predicated.Signed.Digested.t )
        Inner.t

      module Checked : sig
        type t =
          ( Snark_params.Tick.Boolean.var
          , Token_id.Checked.t
          , ( Snark_params.Tick.Boolean.var
            , Other_fee_payer.Payload.Checked.t )
            Snapp_basic.Flagged_option.t
          , Party.Predicated.Signed.Digested.Checked.t
          , Party.Predicated.Signed.Digested.Checked.t )
          Inner.t
      end
    end

    module Checked : sig
      type t =
        ( Snark_params.Tick.Boolean.var
        , Token_id.Checked.t
        , ( Snark_params.Tick.Boolean.var
          , Other_fee_payer.Payload.Checked.t )
          Snapp_basic.Flagged_option.t
        , Party.Predicated.Signed.Checked.t
        , Party.Predicated.Signed.Checked.t )
        Inner.t

      val digested : t -> Digested.Checked.t
    end

    val typ : (Checked.t, t) Snark_params.Tick.Typ.t
  end

  module One_proved : sig
    module Stable : sig
      module V1 : sig
        type t =
          ( bool
          , Token_id.Stable.V1.t
          , Other_fee_payer.Payload.Stable.V1.t option
          , Party.Predicated.Proved.Stable.V1.t
          , Party.Predicated.Signed.Stable.V1.t )
          Inner.t

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
        * (Core_kernel.Bigstring.t -> pos_ref:int Core_kernel.ref -> Latest.t)
        )
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

    module Digested : sig
      type t =
        ( bool
        , Token_id.t
        , Other_fee_payer.Payload.t option
        , Party.Predicated.Proved.Digested.t
        , Party.Predicated.Signed.Digested.t )
        Inner.t

      module Checked : sig
        type t =
          ( Snark_params.Tick.Boolean.var
          , Token_id.Checked.t
          , ( Snark_params.Tick.Boolean.var
            , Other_fee_payer.Payload.Checked.t )
            Snapp_basic.Flagged_option.t
          , Party.Predicated.Proved.Digested.Checked.t
          , Party.Predicated.Signed.Digested.Checked.t )
          Inner.t
      end
    end
  end

  module Two_proved : sig
    module Stable : sig
      module V1 : sig
        type t =
          ( bool
          , Token_id.Stable.V1.t
          , Other_fee_payer.Payload.Stable.V1.t option
          , Party.Predicated.Proved.Stable.V1.t
          , Party.Predicated.Proved.Stable.V1.t )
          Inner.t

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
        * (Core_kernel.Bigstring.t -> pos_ref:int Core_kernel.ref -> Latest.t)
        )
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

    module Digested : sig
      type t =
        ( bool
        , Token_id.t
        , Other_fee_payer.Payload.t option
        , Party.Predicated.Proved.Digested.t
        , Party.Predicated.Proved.Digested.t )
        Inner.t

      module Checked : sig
        type t =
          ( Snark_params.Tick.Boolean.var
          , Token_id.Checked.t
          , ( Snark_params.Tick.Boolean.var
            , Other_fee_payer.Payload.Checked.t )
            Snapp_basic.Flagged_option.t
          , Party.Predicated.Proved.Digested.Checked.t
          , Party.Predicated.Proved.Digested.Checked.t )
          Inner.t
      end
    end
  end

  module Poly : sig
    module Stable : sig
      module V1 : sig
        type ('zero, 'one, 'two) t =
          | Zero_proved of 'zero
          | One_proved of 'one
          | Two_proved of 'two

        val to_yojson :
             ('zero -> Yojson.Safe.t)
          -> ('one -> Yojson.Safe.t)
          -> ('two -> Yojson.Safe.t)
          -> ('zero, 'one, 'two) t
          -> Yojson.Safe.t

        val of_yojson :
             (Yojson.Safe.t -> 'zero Ppx_deriving_yojson_runtime.error_or)
          -> (Yojson.Safe.t -> 'one Ppx_deriving_yojson_runtime.error_or)
          -> (Yojson.Safe.t -> 'two Ppx_deriving_yojson_runtime.error_or)
          -> Yojson.Safe.t
          -> ('zero, 'one, 'two) t Ppx_deriving_yojson_runtime.error_or

        val version : int

        val __versioned__ : unit

        val t_of_sexp :
             (Ppx_sexp_conv_lib.Sexp.t -> 'zero)
          -> (Ppx_sexp_conv_lib.Sexp.t -> 'one)
          -> (Ppx_sexp_conv_lib.Sexp.t -> 'two)
          -> Ppx_sexp_conv_lib.Sexp.t
          -> ('zero, 'one, 'two) t

        val sexp_of_t :
             ('zero -> Ppx_sexp_conv_lib.Sexp.t)
          -> ('one -> Ppx_sexp_conv_lib.Sexp.t)
          -> ('two -> Ppx_sexp_conv_lib.Sexp.t)
          -> ('zero, 'one, 'two) t
          -> Ppx_sexp_conv_lib.Sexp.t

        val equal :
             ('zero -> 'zero -> bool)
          -> ('one -> 'one -> bool)
          -> ('two -> 'two -> bool)
          -> ('zero, 'one, 'two) t
          -> ('zero, 'one, 'two) t
          -> bool

        val hash_fold_t :
             (   Ppx_hash_lib.Std.Hash.state
              -> 'zero
              -> Ppx_hash_lib.Std.Hash.state)
          -> (   Ppx_hash_lib.Std.Hash.state
              -> 'one
              -> Ppx_hash_lib.Std.Hash.state)
          -> (   Ppx_hash_lib.Std.Hash.state
              -> 'two
              -> Ppx_hash_lib.Std.Hash.state)
          -> Ppx_hash_lib.Std.Hash.state
          -> ('zero, 'one, 'two) t
          -> Ppx_hash_lib.Std.Hash.state

        val compare :
             ('zero -> 'zero -> int)
          -> ('one -> 'one -> int)
          -> ('two -> 'two -> int)
          -> ('zero, 'one, 'two) t
          -> ('zero, 'one, 'two) t
          -> int

        val to_latest : 'a -> 'a

        module With_version : sig
          type ('zero, 'one, 'two) typ = ('zero, 'one, 'two) t

          val bin_shape_typ :
               Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t

          val bin_size_typ :
               'zero Core_kernel.Bin_prot.Size.sizer
            -> 'one Core_kernel.Bin_prot.Size.sizer
            -> 'two Core_kernel.Bin_prot.Size.sizer
            -> ('zero, 'one, 'two) typ Core_kernel.Bin_prot.Size.sizer

          val bin_write_typ :
               'zero Core_kernel.Bin_prot.Write.writer
            -> 'one Core_kernel.Bin_prot.Write.writer
            -> 'two Core_kernel.Bin_prot.Write.writer
            -> ('zero, 'one, 'two) typ Core_kernel.Bin_prot.Write.writer

          val bin_writer_typ :
               'a Core_kernel.Bin_prot.Type_class.writer
            -> 'b Core_kernel.Bin_prot.Type_class.writer
            -> 'c Core_kernel.Bin_prot.Type_class.writer
            -> ('a, 'b, 'c) typ Core_kernel.Bin_prot.Type_class.writer

          val __bin_read_typ__ :
               'zero Core_kernel.Bin_prot.Read.reader
            -> 'one Core_kernel.Bin_prot.Read.reader
            -> 'two Core_kernel.Bin_prot.Read.reader
            -> (int -> ('zero, 'one, 'two) typ) Core_kernel.Bin_prot.Read.reader

          val bin_read_typ :
               'zero Core_kernel.Bin_prot.Read.reader
            -> 'one Core_kernel.Bin_prot.Read.reader
            -> 'two Core_kernel.Bin_prot.Read.reader
            -> ('zero, 'one, 'two) typ Core_kernel.Bin_prot.Read.reader

          val bin_reader_typ :
               'a Core_kernel.Bin_prot.Type_class.reader
            -> 'b Core_kernel.Bin_prot.Type_class.reader
            -> 'c Core_kernel.Bin_prot.Type_class.reader
            -> ('a, 'b, 'c) typ Core_kernel.Bin_prot.Type_class.reader

          val bin_typ :
               'a Core_kernel.Bin_prot.Type_class.t
            -> 'b Core_kernel.Bin_prot.Type_class.t
            -> 'c Core_kernel.Bin_prot.Type_class.t
            -> ('a, 'b, 'c) typ Core_kernel.Bin_prot.Type_class.t

          type ('zero, 'one, 'two) t =
            { version : int; t : ('zero, 'one, 'two) typ }

          val bin_shape_t :
               Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t
            -> Core_kernel.Bin_prot.Shape.t

          val bin_size_t :
               'zero Core_kernel.Bin_prot.Size.sizer
            -> 'one Core_kernel.Bin_prot.Size.sizer
            -> 'two Core_kernel.Bin_prot.Size.sizer
            -> ('zero, 'one, 'two) t Core_kernel.Bin_prot.Size.sizer

          val bin_write_t :
               'zero Core_kernel.Bin_prot.Write.writer
            -> 'one Core_kernel.Bin_prot.Write.writer
            -> 'two Core_kernel.Bin_prot.Write.writer
            -> ('zero, 'one, 'two) t Core_kernel.Bin_prot.Write.writer

          val bin_writer_t :
               'a Core_kernel.Bin_prot.Type_class.writer
            -> 'b Core_kernel.Bin_prot.Type_class.writer
            -> 'c Core_kernel.Bin_prot.Type_class.writer
            -> ('a, 'b, 'c) t Core_kernel.Bin_prot.Type_class.writer

          val __bin_read_t__ :
               'zero Core_kernel.Bin_prot.Read.reader
            -> 'one Core_kernel.Bin_prot.Read.reader
            -> 'two Core_kernel.Bin_prot.Read.reader
            -> (int -> ('zero, 'one, 'two) t) Core_kernel.Bin_prot.Read.reader

          val bin_read_t :
               'zero Core_kernel.Bin_prot.Read.reader
            -> 'one Core_kernel.Bin_prot.Read.reader
            -> 'two Core_kernel.Bin_prot.Read.reader
            -> ('zero, 'one, 'two) t Core_kernel.Bin_prot.Read.reader

          val bin_reader_t :
               'a Core_kernel.Bin_prot.Type_class.reader
            -> 'b Core_kernel.Bin_prot.Type_class.reader
            -> 'c Core_kernel.Bin_prot.Type_class.reader
            -> ('a, 'b, 'c) t Core_kernel.Bin_prot.Type_class.reader

          val bin_t :
               'a Core_kernel.Bin_prot.Type_class.t
            -> 'b Core_kernel.Bin_prot.Type_class.t
            -> 'c Core_kernel.Bin_prot.Type_class.t
            -> ('a, 'b, 'c) t Core_kernel.Bin_prot.Type_class.t

          val create : ('a, 'b, 'c) typ -> ('a, 'b, 'c) t
        end

        val bin_read_t :
             'a Core_kernel.Bin_prot.Read.reader
          -> 'b Core_kernel.Bin_prot.Read.reader
          -> 'c Core_kernel.Bin_prot.Read.reader
          -> Bin_prot.Common.buf
          -> pos_ref:Bin_prot.Common.pos_ref
          -> ('a, 'b, 'c) t

        val __bin_read_t__ :
             'a Core_kernel.Bin_prot.Read.reader
          -> 'b Core_kernel.Bin_prot.Read.reader
          -> 'c Core_kernel.Bin_prot.Read.reader
          -> Bin_prot.Common.buf
          -> pos_ref:Bin_prot.Common.pos_ref
          -> int
          -> ('a, 'b, 'c) t

        val bin_size_t :
             'a Core_kernel.Bin_prot.Size.sizer
          -> 'b Core_kernel.Bin_prot.Size.sizer
          -> 'c Core_kernel.Bin_prot.Size.sizer
          -> ('a, 'b, 'c) t
          -> int

        val bin_write_t :
             'a Core_kernel.Bin_prot.Write.writer
          -> 'b Core_kernel.Bin_prot.Write.writer
          -> 'c Core_kernel.Bin_prot.Write.writer
          -> Bin_prot.Common.buf
          -> pos:Bin_prot.Common.pos
          -> ('a, 'b, 'c) t
          -> Bin_prot.Common.pos

        val bin_shape_t :
             Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t

        val bin_reader_t :
             'a Core_kernel.Bin_prot.Type_class.reader
          -> 'b Core_kernel.Bin_prot.Type_class.reader
          -> 'c Core_kernel.Bin_prot.Type_class.reader
          -> ('a, 'b, 'c) t Core_kernel.Bin_prot.Type_class.reader

        val bin_writer_t :
             'a Core_kernel.Bin_prot.Type_class.writer
          -> 'b Core_kernel.Bin_prot.Type_class.writer
          -> 'c Core_kernel.Bin_prot.Type_class.writer
          -> ('a, 'b, 'c) t Core_kernel.Bin_prot.Type_class.writer

        val bin_t :
             'a Core_kernel.Bin_prot.Type_class.t
          -> 'b Core_kernel.Bin_prot.Type_class.t
          -> 'c Core_kernel.Bin_prot.Type_class.t
          -> ('a, 'b, 'c) t Core_kernel.Bin_prot.Type_class.t

        val __ :
          (   'a Core_kernel.Bin_prot.Read.reader
           -> 'b Core_kernel.Bin_prot.Read.reader
           -> 'c Core_kernel.Bin_prot.Read.reader
           -> Bin_prot.Common.buf
           -> pos_ref:Bin_prot.Common.pos_ref
           -> ('a, 'b, 'c) t)
          * (   'd Core_kernel.Bin_prot.Read.reader
             -> 'e Core_kernel.Bin_prot.Read.reader
             -> 'f Core_kernel.Bin_prot.Read.reader
             -> Bin_prot.Common.buf
             -> pos_ref:Bin_prot.Common.pos_ref
             -> int
             -> ('d, 'e, 'f) t)
          * (   'g Core_kernel.Bin_prot.Size.sizer
             -> 'h Core_kernel.Bin_prot.Size.sizer
             -> 'i Core_kernel.Bin_prot.Size.sizer
             -> ('g, 'h, 'i) t
             -> int)
          * (   'j Core_kernel.Bin_prot.Write.writer
             -> 'k Core_kernel.Bin_prot.Write.writer
             -> 'l Core_kernel.Bin_prot.Write.writer
             -> Bin_prot.Common.buf
             -> pos:Bin_prot.Common.pos
             -> ('j, 'k, 'l) t
             -> Bin_prot.Common.pos)
          * (   Core_kernel.Bin_prot.Shape.t
             -> Core_kernel.Bin_prot.Shape.t
             -> Core_kernel.Bin_prot.Shape.t
             -> Core_kernel.Bin_prot.Shape.t)
          * (   'm Core_kernel.Bin_prot.Type_class.reader
             -> 'n Core_kernel.Bin_prot.Type_class.reader
             -> 'o Core_kernel.Bin_prot.Type_class.reader
             -> ('m, 'n, 'o) t Core_kernel.Bin_prot.Type_class.reader)
          * (   'p Core_kernel.Bin_prot.Type_class.writer
             -> 'q Core_kernel.Bin_prot.Type_class.writer
             -> 'r Core_kernel.Bin_prot.Type_class.writer
             -> ('p, 'q, 'r) t Core_kernel.Bin_prot.Type_class.writer)
          * (   's Core_kernel.Bin_prot.Type_class.t
             -> 't Core_kernel.Bin_prot.Type_class.t
             -> 'u Core_kernel.Bin_prot.Type_class.t
             -> ('s, 't, 'u) t Core_kernel.Bin_prot.Type_class.t)
      end

      module Latest = V1
    end

    type ('zero, 'one, 'two) t = ('zero, 'one, 'two) Stable.V1.t =
      | Zero_proved of 'zero
      | One_proved of 'one
      | Two_proved of 'two

    val to_yojson :
         ('zero -> Yojson.Safe.t)
      -> ('one -> Yojson.Safe.t)
      -> ('two -> Yojson.Safe.t)
      -> ('zero, 'one, 'two) t
      -> Yojson.Safe.t

    val of_yojson :
         (Yojson.Safe.t -> 'zero Ppx_deriving_yojson_runtime.error_or)
      -> (Yojson.Safe.t -> 'one Ppx_deriving_yojson_runtime.error_or)
      -> (Yojson.Safe.t -> 'two Ppx_deriving_yojson_runtime.error_or)
      -> Yojson.Safe.t
      -> ('zero, 'one, 'two) t Ppx_deriving_yojson_runtime.error_or

    val t_of_sexp :
         (Ppx_sexp_conv_lib.Sexp.t -> 'zero)
      -> (Ppx_sexp_conv_lib.Sexp.t -> 'one)
      -> (Ppx_sexp_conv_lib.Sexp.t -> 'two)
      -> Ppx_sexp_conv_lib.Sexp.t
      -> ('zero, 'one, 'two) t

    val sexp_of_t :
         ('zero -> Ppx_sexp_conv_lib.Sexp.t)
      -> ('one -> Ppx_sexp_conv_lib.Sexp.t)
      -> ('two -> Ppx_sexp_conv_lib.Sexp.t)
      -> ('zero, 'one, 'two) t
      -> Ppx_sexp_conv_lib.Sexp.t

    val equal :
         ('zero -> 'zero -> bool)
      -> ('one -> 'one -> bool)
      -> ('two -> 'two -> bool)
      -> ('zero, 'one, 'two) t
      -> ('zero, 'one, 'two) t
      -> bool

    val hash_fold_t :
         (Ppx_hash_lib.Std.Hash.state -> 'zero -> Ppx_hash_lib.Std.Hash.state)
      -> (Ppx_hash_lib.Std.Hash.state -> 'one -> Ppx_hash_lib.Std.Hash.state)
      -> (Ppx_hash_lib.Std.Hash.state -> 'two -> Ppx_hash_lib.Std.Hash.state)
      -> Ppx_hash_lib.Std.Hash.state
      -> ('zero, 'one, 'two) t
      -> Ppx_hash_lib.Std.Hash.state

    val compare :
         ('zero -> 'zero -> int)
      -> ('one -> 'one -> int)
      -> ('two -> 'two -> int)
      -> ('zero, 'one, 'two) t
      -> ('zero, 'one, 'two) t
      -> int
  end

  module Stable : sig
    module V1 : sig
      type t =
        ( Zero_proved.Stable.V1.t
        , One_proved.Stable.V1.t
        , Two_proved.Stable.V1.t )
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

  module Digested : sig
    type t =
      ( Zero_proved.Digested.t
      , One_proved.Digested.t
      , Two_proved.Digested.t )
      Poly.t

    module Checked : sig
      type t =
        ( Zero_proved.Digested.Checked.t
        , One_proved.Digested.Checked.t
        , Two_proved.Digested.Checked.t )
        Poly.t

      val to_input :
           t
        -> ( Snark_params.Tick.Field.Var.t
           , Snark_params.Tick.Boolean.var )
           Random_oracle.Input.t

      val digest : t -> Party.Body.Digested.Checked.t
    end

    val to_input : t -> (Snark_params.Tick.Field.t, bool) Random_oracle.Input.t

    val digest : t -> Party.Body.Digested.t
  end

  val digested : t -> Digested.t
end

val nonce : t -> Mina_numbers.Account_nonce.Stable.V1.t option

val nonce_invariant : t -> unit Core_kernel.Or_error.t

val check : t -> unit Core_kernel.Or_error.t

val to_payload : t -> Payload.t

val signed_signed :
     ?fee_payment:Signature_lib.Schnorr.Private_key.t * Other_fee_payer.Payload.t
  -> token_id:Token_id.t
  -> Signature_lib.Schnorr.Private_key.t * Party.Predicated.Signed.Stable.V1.t
  -> Signature_lib.Schnorr.Private_key.t * Party.Predicated.Signed.Stable.V1.t
  -> t

val signed_empty :
     ?fee_payment:Signature_lib.Schnorr.Private_key.t * Other_fee_payer.Payload.t
  -> ?data2:Party.Predicated.Empty.Stable.V1.t
  -> token_id:Token_id.t
  -> Signature_lib.Schnorr.Private_key.t * Party.Predicated.Signed.Stable.V1.t
  -> t

module Base58_check : sig
  module Base58_check : sig
    val encode : string -> string

    val decode_exn : string -> string

    val decode : string -> string Core_kernel.Or_error.t
  end

  val to_base58_check : t -> string

  val of_base58_check : string -> t Base__Or_error.t

  val of_base58_check_exn : string -> t

  val to_yojson : t -> [> `String of string ]

  val of_yojson : Yojson.Safe.t -> (t, string) Core_kernel.Result.t
end

val to_base58_check : t -> string

val of_base58_check : string -> t Base__Or_error.t

val of_base58_check_exn : string -> t
