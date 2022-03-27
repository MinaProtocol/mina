module Partial : sig
  module type Bin_io_intf = Core_kernel.Binable.S

  module type Sexp_intf = Core_kernel.Sexpable.S

  module type Yojson_intf = sig
    type t

    val to_yojson : t -> Yojson.Safe.t

    val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or
  end
end

module type Creatable_intf = sig
  type t

  type 'a creator

  val create : t creator
end

module type Higher_order_creatable_intf = sig
  type t

  type 'a creator

  val create : t creator

  val map_creator : 'a creator -> f:('a -> 'b) -> 'b creator
end

module Input : sig
  module type Basic_intf = sig
    val id : string

    type t

    type 'a creator

    val create : t creator

    val map_creator : 'a creator -> f:('a -> 'b) -> 'b creator
  end

  module type Bin_io_intf = sig
    val id : string

    type t

    type 'a creator

    val create : t creator

    val map_creator : 'a creator -> f:('a -> 'b) -> 'b creator

    val bin_size_t : t Bin_prot.Size.sizer

    val bin_write_t : t Bin_prot.Write.writer

    val bin_read_t : t Bin_prot.Read.reader

    val __bin_read_t__ : (int -> t) Bin_prot.Read.reader

    val bin_shape_t : Bin_prot.Shape.t

    val bin_writer_t : t Bin_prot.Type_class.writer

    val bin_reader_t : t Bin_prot.Type_class.reader

    val bin_t : t Bin_prot.Type_class.t
  end

  module type Sexp_intf = sig
    val id : string

    type t

    type 'a creator

    val create : t creator

    val map_creator : 'a creator -> f:('a -> 'b) -> 'b creator

    val t_of_sexp : Base__.Sexp.t -> t

    val sexp_of_t : t -> Base__.Sexp.t
  end

  module type Bin_io_and_sexp_intf = sig
    val id : string

    type t

    type 'a creator

    val create : t creator

    val map_creator : 'a creator -> f:('a -> 'b) -> 'b creator

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

  module type Yojson_intf = sig
    val id : string

    type t

    type 'a creator

    val create : t creator

    val map_creator : 'a creator -> f:('a -> 'b) -> 'b creator

    val to_yojson : t -> Yojson.Safe.t

    val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or
  end

  module type Bin_io_and_yojson_intf = sig
    val id : string

    type t

    type 'a creator

    val create : t creator

    val map_creator : 'a creator -> f:('a -> 'b) -> 'b creator

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

  module type Full_intf = sig
    val id : string

    type t

    type 'a creator

    val create : t creator

    val map_creator : 'a creator -> f:('a -> 'b) -> 'b creator

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
    module type Basic_intf = sig
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

        module Latest = V1

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
    end

    module type Sexp_intf = sig
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

        module Latest = V1

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
    end

    module type Yojson_intf = sig
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

        module Latest = V1

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
    end

    module type Full_compare_eq_hash_intf = sig
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

        module Latest = V1

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
    end

    module type Full_intf = sig
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

        module Latest = V1

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
    end
  end
end

module Output : sig
  module type Basic_intf = Creatable_intf

  module type Bin_io_intf = sig
    type t

    type 'a creator

    val create : t creator

    val bin_size_t : t Bin_prot.Size.sizer

    val bin_write_t : t Bin_prot.Write.writer

    val bin_read_t : t Bin_prot.Read.reader

    val __bin_read_t__ : (int -> t) Bin_prot.Read.reader

    val bin_shape_t : Bin_prot.Shape.t

    val bin_writer_t : t Bin_prot.Type_class.writer

    val bin_reader_t : t Bin_prot.Type_class.reader

    val bin_t : t Bin_prot.Type_class.t
  end

  module type Sexp_intf = sig
    type t

    type 'a creator

    val create : t creator

    val t_of_sexp : Base__.Sexp.t -> t

    val sexp_of_t : t -> Base__.Sexp.t
  end

  module type Bin_io_and_sexp_intf = sig
    type t

    type 'a creator

    val create : t creator

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

  module type Bin_io_and_yojson_intf = sig
    type t

    type 'a creator

    val create : t creator

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

  module type Yojson_intf = sig
    type t

    type 'a creator

    val create : t creator

    val to_yojson : t -> Yojson.Safe.t

    val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or
  end

  module type Full_intf = sig
    type t

    type 'a creator

    val create : t creator

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
    module type Basic_intf = sig
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
        end

        module Latest = V1

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
    end

    module type Sexp_intf = sig
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

          val t_of_sexp : Base__.Sexp.t -> t

          val sexp_of_t : t -> Base__.Sexp.t
        end

        module Latest = V1

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
    end

    module type Yojson_intf = sig
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

          val to_yojson : t -> Yojson.Safe.t

          val of_yojson :
            Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or
        end

        module Latest = V1

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
    end

    module type Full_compare_eq_hash_intf = sig
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

          val t_of_sexp : Base__.Sexp.t -> t

          val sexp_of_t : t -> Base__.Sexp.t

          val to_yojson : t -> Yojson.Safe.t

          val of_yojson :
            Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or
        end

        module Latest = V1

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
    end

    module type Full_intf = sig
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

          val t_of_sexp : Base__.Sexp.t -> t

          val sexp_of_t : t -> Base__.Sexp.t

          val to_yojson : t -> Yojson.Safe.t

          val of_yojson :
            Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or
        end

        module Latest = V1

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
    end
  end
end
