module Partial : sig
  module Bin_io : functor (M : Intf.Input.Bin_io_intf) -> sig
    val bin_size_t : M.t Bin_prot.Size.sizer

    val bin_write_t : M.t Bin_prot.Write.writer

    val bin_read_t : M.t Bin_prot.Read.reader

    val __bin_read_t__ : (int -> M.t) Bin_prot.Read.reader

    val bin_shape_t : Bin_prot.Shape.t

    val bin_writer_t : M.t Bin_prot.Type_class.writer

    val bin_reader_t : M.t Bin_prot.Type_class.reader

    val bin_t : M.t Bin_prot.Type_class.t
  end

  module Sexp : functor (M : Intf.Input.Sexp_intf) -> sig
    val t_of_sexp : Base__.Sexp.t -> M.t

    val sexp_of_t : M.t -> Base__.Sexp.t
  end

  module Yojson : functor (M : Intf.Input.Yojson_intf) -> sig
    val to_yojson : M.t -> Yojson.Safe.t

    val of_yojson : Yojson.Safe.t -> M.t Ppx_deriving_yojson_runtime.error_or
  end
end

module Basic : functor (M : Intf.Input.Basic_intf) -> sig
  type t = M.t

  val create : t M.creator
end

module Bin_io : functor (M : Intf.Input.Bin_io_intf) -> sig
  type t = M.t

  val create : t M.creator

  val bin_size_t : t Bin_prot.Size.sizer

  val bin_write_t : t Bin_prot.Write.writer

  val bin_read_t : t Bin_prot.Read.reader

  val __bin_read_t__ : (int -> t) Bin_prot.Read.reader

  val bin_shape_t : Bin_prot.Shape.t

  val bin_writer_t : t Bin_prot.Type_class.writer

  val bin_reader_t : t Bin_prot.Type_class.reader

  val bin_t : t Bin_prot.Type_class.t
end

module Sexp : functor (M : Intf.Input.Sexp_intf) -> sig
  type t = M.t

  val create : t M.creator

  val t_of_sexp : Base__.Sexp.t -> t

  val sexp_of_t : t -> Base__.Sexp.t
end

module Bin_io_and_sexp : functor (M : Intf.Input.Bin_io_and_sexp_intf) -> sig
  type t = M.t

  val create : t M.creator

  val bin_size_t : t Bin_prot.Size.sizer

  val bin_write_t : t Bin_prot.Write.writer

  val bin_read_t : t Bin_prot.Read.reader

  val __bin_read_t__ : (int -> t) Bin_prot.Read.reader

  val bin_shape_t : Bin_prot.Shape.t

  val bin_writer_t : t Bin_prot.Type_class.writer

  val bin_reader_t : t Bin_prot.Type_class.reader

  val bin_t : t Bin_prot.Type_class.t

  val t_of_sexp : Base__.Sexp.t -> t

  val sexp_of_t : t -> Base__.Sexp.t
end

module Bin_io_and_yojson : functor
  (M : Intf.Input.Bin_io_and_yojson_intf)
  -> sig
  type t = M.t

  val create : t M.creator

  val bin_size_t : t Bin_prot.Size.sizer

  val bin_write_t : t Bin_prot.Write.writer

  val bin_read_t : t Bin_prot.Read.reader

  val __bin_read_t__ : (int -> t) Bin_prot.Read.reader

  val bin_shape_t : Bin_prot.Shape.t

  val bin_writer_t : t Bin_prot.Type_class.writer

  val bin_reader_t : t Bin_prot.Type_class.reader

  val bin_t : t Bin_prot.Type_class.t

  val to_yojson : t -> Yojson.Safe.t

  val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or
end

module Full : functor (M : Intf.Input.Full_intf) -> sig
  type t = M.t

  val create : t M.creator

  val bin_size_t : t Bin_prot.Size.sizer

  val bin_write_t : t Bin_prot.Write.writer

  val bin_read_t : t Bin_prot.Read.reader

  val __bin_read_t__ : (int -> t) Bin_prot.Read.reader

  val bin_shape_t : Bin_prot.Shape.t

  val bin_writer_t : t Bin_prot.Type_class.writer

  val bin_reader_t : t Bin_prot.Type_class.reader

  val bin_t : t Bin_prot.Type_class.t

  val t_of_sexp : Base__.Sexp.t -> t

  val sexp_of_t : t -> Base__.Sexp.t

  val to_yojson : t -> Yojson.Safe.t

  val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or
end

module Versioned_v1 : sig
  module Basic_intf : functor
    (M : sig
       val id : string

       module Stable : sig
         module V1 : sig
           type t

           val bin_size_t : t Bin_prot.Size.sizer

           val bin_write_t : t Bin_prot.Write.writer

           val bin_read_t : t Bin_prot.Read.reader

           val __bin_read_t__ : (int -> t) Bin_prot.Read.reader

           val bin_shape_t : Bin_prot.Shape.t

           val bin_writer_t : t Bin_prot.Type_class.writer

           val bin_reader_t : t Bin_prot.Type_class.reader

           val bin_t : t Bin_prot.Type_class.t

           val __versioned__ : unit

           type 'a creator

           val create : t creator

           val map_creator : 'a creator -> f:('a -> 'b) -> 'b creator
         end

         module Latest : sig
           type t = V1.t

           val bin_size_t : t Bin_prot.Size.sizer

           val bin_write_t : t Bin_prot.Write.writer

           val bin_read_t : t Bin_prot.Read.reader

           val __bin_read_t__ : (int -> t) Bin_prot.Read.reader

           val bin_shape_t : Bin_prot.Shape.t

           val bin_writer_t : t Bin_prot.Type_class.writer

           val bin_reader_t : t Bin_prot.Type_class.reader

           val bin_t : t Bin_prot.Type_class.t

           val __versioned__ : unit

           type 'a creator = 'a V1.creator

           val create : t creator

           val map_creator : 'a creator -> f:('a -> 'b) -> 'b creator
         end

         val versions :
           ( int
           * (Core_kernel.Bigstring.t -> pos_ref:int Core_kernel.ref -> V1.t) )
           array

         val bin_read_to_latest_opt :
              Core_kernel.Bin_prot.Common.buf
           -> pos_ref:int Core_kernel.ref
           -> V1.t option
       end

       type t = Stable.V1.t
     end)
    -> sig
    module Stable : sig
      module V1 : sig
        type t = M.t

        val bin_size_t : t Bin_prot.Size.sizer

        val bin_write_t : t Bin_prot.Write.writer

        val bin_read_t : t Bin_prot.Read.reader

        val __bin_read_t__ : (int -> t) Bin_prot.Read.reader

        val bin_shape_t : Bin_prot.Shape.t

        val bin_writer_t : t Bin_prot.Type_class.writer

        val bin_reader_t : t Bin_prot.Type_class.reader

        val bin_t : t Bin_prot.Type_class.t

        val __versioned__ : unit

        type 'a creator = 'a M.Stable.V1.creator

        val create : t creator
      end

      module Latest = V1

      val versions :
        (int * (Core_kernel.Bigstring.t -> pos_ref:int Core_kernel.ref -> V1.t))
        array

      val bin_read_to_latest_opt :
           Core_kernel.Bin_prot.Common.buf
        -> pos_ref:int Core_kernel.ref
        -> V1.t option
    end

    type t = M.t
  end

  module Sexp : functor
    (M : sig
       val id : string

       module Stable : sig
         module V1 : sig
           type t

           val bin_size_t : t Bin_prot.Size.sizer

           val bin_write_t : t Bin_prot.Write.writer

           val bin_read_t : t Bin_prot.Read.reader

           val __bin_read_t__ : (int -> t) Bin_prot.Read.reader

           val bin_shape_t : Bin_prot.Shape.t

           val bin_writer_t : t Bin_prot.Type_class.writer

           val bin_reader_t : t Bin_prot.Type_class.reader

           val bin_t : t Bin_prot.Type_class.t

           val __versioned__ : unit

           type 'a creator

           val create : t creator

           val map_creator : 'a creator -> f:('a -> 'b) -> 'b creator

           val t_of_sexp : Base__.Sexp.t -> t

           val sexp_of_t : t -> Base__.Sexp.t
         end

         module Latest : sig
           type t = V1.t

           val bin_size_t : t Bin_prot.Size.sizer

           val bin_write_t : t Bin_prot.Write.writer

           val bin_read_t : t Bin_prot.Read.reader

           val __bin_read_t__ : (int -> t) Bin_prot.Read.reader

           val bin_shape_t : Bin_prot.Shape.t

           val bin_writer_t : t Bin_prot.Type_class.writer

           val bin_reader_t : t Bin_prot.Type_class.reader

           val bin_t : t Bin_prot.Type_class.t

           val __versioned__ : unit

           type 'a creator = 'a V1.creator

           val create : t creator

           val map_creator : 'a creator -> f:('a -> 'b) -> 'b creator

           val t_of_sexp : Base__.Sexp.t -> t

           val sexp_of_t : t -> Base__.Sexp.t
         end

         val versions :
           ( int
           * (Core_kernel.Bigstring.t -> pos_ref:int Core_kernel.ref -> V1.t) )
           array

         val bin_read_to_latest_opt :
              Core_kernel.Bin_prot.Common.buf
           -> pos_ref:int Core_kernel.ref
           -> V1.t option
       end

       type t = Stable.V1.t
     end)
    -> sig
    module Stable : sig
      module V1 : sig
        type t = M.t

        val bin_size_t : t Bin_prot.Size.sizer

        val bin_write_t : t Bin_prot.Write.writer

        val bin_read_t : t Bin_prot.Read.reader

        val __bin_read_t__ : (int -> t) Bin_prot.Read.reader

        val bin_shape_t : Bin_prot.Shape.t

        val bin_writer_t : t Bin_prot.Type_class.writer

        val bin_reader_t : t Bin_prot.Type_class.reader

        val bin_t : t Bin_prot.Type_class.t

        val __versioned__ : unit

        type 'a creator = 'a M.Stable.V1.creator

        val create : t creator

        val t_of_sexp : Base__.Sexp.t -> t

        val sexp_of_t : t -> Base__.Sexp.t
      end

      module Latest = V1

      val versions :
        (int * (Core_kernel.Bigstring.t -> pos_ref:int Core_kernel.ref -> V1.t))
        array

      val bin_read_to_latest_opt :
           Core_kernel.Bin_prot.Common.buf
        -> pos_ref:int Core_kernel.ref
        -> V1.t option
    end

    type t = M.t
  end

  module Full_compare_eq_hash : functor
    (M : sig
       val id : string

       module Stable : sig
         module V1 : sig
           type t

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

           val hash_fold_t :
             Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

           val hash : t -> Ppx_hash_lib.Std.Hash.hash_value

           type 'a creator

           val create : t creator

           val map_creator : 'a creator -> f:('a -> 'b) -> 'b creator

           val t_of_sexp : Base__.Sexp.t -> t

           val sexp_of_t : t -> Base__.Sexp.t

           val to_yojson : t -> Yojson.Safe.t

           val of_yojson :
             Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or
         end

         module Latest : sig
           type t = V1.t

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

           val hash_fold_t :
             Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

           val hash : t -> Ppx_hash_lib.Std.Hash.hash_value

           type 'a creator = 'a V1.creator

           val create : t creator

           val map_creator : 'a creator -> f:('a -> 'b) -> 'b creator

           val t_of_sexp : Base__.Sexp.t -> t

           val sexp_of_t : t -> Base__.Sexp.t

           val to_yojson : t -> Yojson.Safe.t

           val of_yojson :
             Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or
         end

         val versions :
           ( int
           * (Core_kernel.Bigstring.t -> pos_ref:int Core_kernel.ref -> V1.t) )
           array

         val bin_read_to_latest_opt :
              Core_kernel.Bin_prot.Common.buf
           -> pos_ref:int Core_kernel.ref
           -> V1.t option
       end

       type t = Stable.V1.t

       val compare : t -> t -> int

       val equal : t -> t -> bool

       val hash_fold_t :
         Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

       val hash : t -> Ppx_hash_lib.Std.Hash.hash_value
     end)
    -> sig
    module Stable : sig
      module V1 : sig
        type t = M.t

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

        val hash_fold_t :
          Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

        val hash : t -> Ppx_hash_lib.Std.Hash.hash_value

        type 'a creator = 'a M.Stable.V1.creator

        val create : t creator

        val t_of_sexp : Base__.Sexp.t -> t

        val sexp_of_t : t -> Base__.Sexp.t

        val to_yojson : t -> Yojson.Safe.t

        val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or
      end

      module Latest = V1

      val versions :
        (int * (Core_kernel.Bigstring.t -> pos_ref:int Core_kernel.ref -> V1.t))
        array

      val bin_read_to_latest_opt :
           Core_kernel.Bin_prot.Common.buf
        -> pos_ref:int Core_kernel.ref
        -> V1.t option
    end

    type t = M.t

    val compare : t -> t -> int

    val equal : t -> t -> bool

    val hash_fold_t :
      Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

    val hash : t -> Ppx_hash_lib.Std.Hash.hash_value
  end

  module Full : functor
    (M : sig
       val id : string

       module Stable : sig
         module V1 : sig
           type t

           val bin_size_t : t Bin_prot.Size.sizer

           val bin_write_t : t Bin_prot.Write.writer

           val bin_read_t : t Bin_prot.Read.reader

           val __bin_read_t__ : (int -> t) Bin_prot.Read.reader

           val bin_shape_t : Bin_prot.Shape.t

           val bin_writer_t : t Bin_prot.Type_class.writer

           val bin_reader_t : t Bin_prot.Type_class.reader

           val bin_t : t Bin_prot.Type_class.t

           val __versioned__ : unit

           type 'a creator

           val create : t creator

           val map_creator : 'a creator -> f:('a -> 'b) -> 'b creator

           val t_of_sexp : Base__.Sexp.t -> t

           val sexp_of_t : t -> Base__.Sexp.t

           val to_yojson : t -> Yojson.Safe.t

           val of_yojson :
             Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or
         end

         module Latest : sig
           type t = V1.t

           val bin_size_t : t Bin_prot.Size.sizer

           val bin_write_t : t Bin_prot.Write.writer

           val bin_read_t : t Bin_prot.Read.reader

           val __bin_read_t__ : (int -> t) Bin_prot.Read.reader

           val bin_shape_t : Bin_prot.Shape.t

           val bin_writer_t : t Bin_prot.Type_class.writer

           val bin_reader_t : t Bin_prot.Type_class.reader

           val bin_t : t Bin_prot.Type_class.t

           val __versioned__ : unit

           type 'a creator = 'a V1.creator

           val create : t creator

           val map_creator : 'a creator -> f:('a -> 'b) -> 'b creator

           val t_of_sexp : Base__.Sexp.t -> t

           val sexp_of_t : t -> Base__.Sexp.t

           val to_yojson : t -> Yojson.Safe.t

           val of_yojson :
             Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or
         end

         val versions :
           ( int
           * (Core_kernel.Bigstring.t -> pos_ref:int Core_kernel.ref -> V1.t) )
           array

         val bin_read_to_latest_opt :
              Core_kernel.Bin_prot.Common.buf
           -> pos_ref:int Core_kernel.ref
           -> V1.t option
       end

       type t = Stable.V1.t
     end)
    -> sig
    module Stable : sig
      module V1 : sig
        type t = M.t

        val bin_size_t : t Bin_prot.Size.sizer

        val bin_write_t : t Bin_prot.Write.writer

        val bin_read_t : t Bin_prot.Read.reader

        val __bin_read_t__ : (int -> t) Bin_prot.Read.reader

        val bin_shape_t : Bin_prot.Shape.t

        val bin_writer_t : t Bin_prot.Type_class.writer

        val bin_reader_t : t Bin_prot.Type_class.reader

        val bin_t : t Bin_prot.Type_class.t

        val __versioned__ : unit

        type 'a creator = 'a M.Stable.V1.creator

        val create : t creator

        val t_of_sexp : Base__.Sexp.t -> t

        val sexp_of_t : t -> Base__.Sexp.t

        val to_yojson : t -> Yojson.Safe.t

        val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or
      end

      module Latest = V1

      val versions :
        (int * (Core_kernel.Bigstring.t -> pos_ref:int Core_kernel.ref -> V1.t))
        array

      val bin_read_to_latest_opt :
           Core_kernel.Bin_prot.Common.buf
        -> pos_ref:int Core_kernel.ref
        -> V1.t option
    end

    type t = M.t
  end

  module Yojson : functor
    (M : sig
       val id : string

       module Stable : sig
         module V1 : sig
           type t

           val bin_size_t : t Bin_prot.Size.sizer

           val bin_write_t : t Bin_prot.Write.writer

           val bin_read_t : t Bin_prot.Read.reader

           val __bin_read_t__ : (int -> t) Bin_prot.Read.reader

           val bin_shape_t : Bin_prot.Shape.t

           val bin_writer_t : t Bin_prot.Type_class.writer

           val bin_reader_t : t Bin_prot.Type_class.reader

           val bin_t : t Bin_prot.Type_class.t

           val __versioned__ : unit

           type 'a creator

           val create : t creator

           val map_creator : 'a creator -> f:('a -> 'b) -> 'b creator

           val to_yojson : t -> Yojson.Safe.t

           val of_yojson :
             Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or
         end

         module Latest : sig
           type t = V1.t

           val bin_size_t : t Bin_prot.Size.sizer

           val bin_write_t : t Bin_prot.Write.writer

           val bin_read_t : t Bin_prot.Read.reader

           val __bin_read_t__ : (int -> t) Bin_prot.Read.reader

           val bin_shape_t : Bin_prot.Shape.t

           val bin_writer_t : t Bin_prot.Type_class.writer

           val bin_reader_t : t Bin_prot.Type_class.reader

           val bin_t : t Bin_prot.Type_class.t

           val __versioned__ : unit

           type 'a creator = 'a V1.creator

           val create : t creator

           val map_creator : 'a creator -> f:('a -> 'b) -> 'b creator

           val to_yojson : t -> Yojson.Safe.t

           val of_yojson :
             Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or
         end

         val versions :
           ( int
           * (Core_kernel.Bigstring.t -> pos_ref:int Core_kernel.ref -> V1.t) )
           array

         val bin_read_to_latest_opt :
              Core_kernel.Bin_prot.Common.buf
           -> pos_ref:int Core_kernel.ref
           -> V1.t option
       end

       type t = Stable.V1.t
     end)
    -> sig
    module Stable : sig
      module V1 : sig
        type t = M.t

        val bin_size_t : t Bin_prot.Size.sizer

        val bin_write_t : t Bin_prot.Write.writer

        val bin_read_t : t Bin_prot.Read.reader

        val __bin_read_t__ : (int -> t) Bin_prot.Read.reader

        val bin_shape_t : Bin_prot.Shape.t

        val bin_writer_t : t Bin_prot.Type_class.writer

        val bin_reader_t : t Bin_prot.Type_class.reader

        val bin_t : t Bin_prot.Type_class.t

        val __versioned__ : unit

        type 'a creator = 'a M.Stable.V1.creator

        val create : t creator

        val to_yojson : t -> Yojson.Safe.t

        val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or
      end

      module Latest = V1

      val versions :
        (int * (Core_kernel.Bigstring.t -> pos_ref:int Core_kernel.ref -> V1.t))
        array

      val bin_read_to_latest_opt :
           Core_kernel.Bin_prot.Common.buf
        -> pos_ref:int Core_kernel.ref
        -> V1.t option
    end

    type t = M.t
  end
end

module Yojson : functor (M : Intf.Input.Yojson_intf) -> sig
  type t = M.t

  val create : t M.creator

  val to_yojson : t -> Yojson.Safe.t

  val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or
end
