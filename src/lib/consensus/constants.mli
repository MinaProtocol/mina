module Length = Mina_numbers.Length

module Poly : sig
  module Stable : sig
    module V1 : sig
      type ('length, 'time, 'timespan) t =
        { k : 'length
        ; delta : 'length
        ; slots_per_sub_window : 'length
        ; slots_per_window : 'length
        ; sub_windows_per_window : 'length
        ; slots_per_epoch : 'length
        ; grace_period_end : 'length
        ; epoch_size : 'length
        ; checkpoint_window_slots_per_year : 'length
        ; checkpoint_window_size_in_slots : 'length
        ; block_window_duration_ms : 'timespan
        ; slot_duration_ms : 'timespan
        ; epoch_duration : 'timespan
        ; delta_duration : 'timespan
        ; genesis_state_timestamp : 'time
        }

      val to_yojson :
           ('length -> Yojson.Safe.t)
        -> ('time -> Yojson.Safe.t)
        -> ('timespan -> Yojson.Safe.t)
        -> ('length, 'time, 'timespan) t
        -> Yojson.Safe.t

      val version : int

      val __versioned__ : unit

      val equal :
           ('length -> 'length -> bool)
        -> ('time -> 'time -> bool)
        -> ('timespan -> 'timespan -> bool)
        -> ('length, 'time, 'timespan) t
        -> ('length, 'time, 'timespan) t
        -> bool

      val compare :
           ('length -> 'length -> int)
        -> ('time -> 'time -> int)
        -> ('timespan -> 'timespan -> int)
        -> ('length, 'time, 'timespan) t
        -> ('length, 'time, 'timespan) t
        -> int

      val hash_fold_t :
           (   Ppx_hash_lib.Std.Hash.state
            -> 'length
            -> Ppx_hash_lib.Std.Hash.state)
        -> (Ppx_hash_lib.Std.Hash.state -> 'time -> Ppx_hash_lib.Std.Hash.state)
        -> (   Ppx_hash_lib.Std.Hash.state
            -> 'timespan
            -> Ppx_hash_lib.Std.Hash.state)
        -> Ppx_hash_lib.Std.Hash.state
        -> ('length, 'time, 'timespan) t
        -> Ppx_hash_lib.Std.Hash.state

      val t_of_sexp :
           (Ppx_sexp_conv_lib.Sexp.t -> 'length)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'time)
        -> (Ppx_sexp_conv_lib.Sexp.t -> 'timespan)
        -> Ppx_sexp_conv_lib.Sexp.t
        -> ('length, 'time, 'timespan) t

      val sexp_of_t :
           ('length -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('time -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('timespan -> Ppx_sexp_conv_lib.Sexp.t)
        -> ('length, 'time, 'timespan) t
        -> Ppx_sexp_conv_lib.Sexp.t

      val to_hlist :
           ('length, 'time, 'timespan) t
        -> ( unit
           ,    'length
             -> 'length
             -> 'length
             -> 'length
             -> 'length
             -> 'length
             -> 'length
             -> 'length
             -> 'length
             -> 'length
             -> 'timespan
             -> 'timespan
             -> 'timespan
             -> 'timespan
             -> 'time
             -> unit )
           Snarky_backendless.H_list.t

      val of_hlist :
           ( unit
           ,    'length
             -> 'length
             -> 'length
             -> 'length
             -> 'length
             -> 'length
             -> 'length
             -> 'length
             -> 'length
             -> 'length
             -> 'timespan
             -> 'timespan
             -> 'timespan
             -> 'timespan
             -> 'time
             -> unit )
           Snarky_backendless.H_list.t
        -> ('length, 'time, 'timespan) t

      module With_version : sig
        type ('length, 'time, 'timespan) typ = ('length, 'time, 'timespan) t

        val bin_shape_typ :
             Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t

        val bin_size_typ :
             'length Core_kernel.Bin_prot.Size.sizer
          -> 'time Core_kernel.Bin_prot.Size.sizer
          -> 'timespan Core_kernel.Bin_prot.Size.sizer
          -> ('length, 'time, 'timespan) typ Core_kernel.Bin_prot.Size.sizer

        val bin_write_typ :
             'length Core_kernel.Bin_prot.Write.writer
          -> 'time Core_kernel.Bin_prot.Write.writer
          -> 'timespan Core_kernel.Bin_prot.Write.writer
          -> ('length, 'time, 'timespan) typ Core_kernel.Bin_prot.Write.writer

        val bin_writer_typ :
             'a Core_kernel.Bin_prot.Type_class.writer
          -> 'b Core_kernel.Bin_prot.Type_class.writer
          -> 'c Core_kernel.Bin_prot.Type_class.writer
          -> ('a, 'b, 'c) typ Core_kernel.Bin_prot.Type_class.writer

        val __bin_read_typ__ :
             'length Core_kernel.Bin_prot.Read.reader
          -> 'time Core_kernel.Bin_prot.Read.reader
          -> 'timespan Core_kernel.Bin_prot.Read.reader
          -> (int -> ('length, 'time, 'timespan) typ)
             Core_kernel.Bin_prot.Read.reader

        val bin_read_typ :
             'length Core_kernel.Bin_prot.Read.reader
          -> 'time Core_kernel.Bin_prot.Read.reader
          -> 'timespan Core_kernel.Bin_prot.Read.reader
          -> ('length, 'time, 'timespan) typ Core_kernel.Bin_prot.Read.reader

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

        type ('length, 'time, 'timespan) t =
          { version : int; t : ('length, 'time, 'timespan) typ }

        val bin_shape_t :
             Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t
          -> Core_kernel.Bin_prot.Shape.t

        val bin_size_t :
             'length Core_kernel.Bin_prot.Size.sizer
          -> 'time Core_kernel.Bin_prot.Size.sizer
          -> 'timespan Core_kernel.Bin_prot.Size.sizer
          -> ('length, 'time, 'timespan) t Core_kernel.Bin_prot.Size.sizer

        val bin_write_t :
             'length Core_kernel.Bin_prot.Write.writer
          -> 'time Core_kernel.Bin_prot.Write.writer
          -> 'timespan Core_kernel.Bin_prot.Write.writer
          -> ('length, 'time, 'timespan) t Core_kernel.Bin_prot.Write.writer

        val bin_writer_t :
             'a Core_kernel.Bin_prot.Type_class.writer
          -> 'b Core_kernel.Bin_prot.Type_class.writer
          -> 'c Core_kernel.Bin_prot.Type_class.writer
          -> ('a, 'b, 'c) t Core_kernel.Bin_prot.Type_class.writer

        val __bin_read_t__ :
             'length Core_kernel.Bin_prot.Read.reader
          -> 'time Core_kernel.Bin_prot.Read.reader
          -> 'timespan Core_kernel.Bin_prot.Read.reader
          -> (int -> ('length, 'time, 'timespan) t)
             Core_kernel.Bin_prot.Read.reader

        val bin_read_t :
             'length Core_kernel.Bin_prot.Read.reader
          -> 'time Core_kernel.Bin_prot.Read.reader
          -> 'timespan Core_kernel.Bin_prot.Read.reader
          -> ('length, 'time, 'timespan) t Core_kernel.Bin_prot.Read.reader

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

  type ('length, 'time, 'timespan) t = ('length, 'time, 'timespan) Stable.V1.t =
    { k : 'length
    ; delta : 'length
    ; slots_per_sub_window : 'length
    ; slots_per_window : 'length
    ; sub_windows_per_window : 'length
    ; slots_per_epoch : 'length
    ; grace_period_end : 'length
    ; epoch_size : 'length
    ; checkpoint_window_slots_per_year : 'length
    ; checkpoint_window_size_in_slots : 'length
    ; block_window_duration_ms : 'timespan
    ; slot_duration_ms : 'timespan
    ; epoch_duration : 'timespan
    ; delta_duration : 'timespan
    ; genesis_state_timestamp : 'time
    }

  val to_yojson :
       ('length -> Yojson.Safe.t)
    -> ('time -> Yojson.Safe.t)
    -> ('timespan -> Yojson.Safe.t)
    -> ('length, 'time, 'timespan) t
    -> Yojson.Safe.t

  val equal :
       ('length -> 'length -> bool)
    -> ('time -> 'time -> bool)
    -> ('timespan -> 'timespan -> bool)
    -> ('length, 'time, 'timespan) t
    -> ('length, 'time, 'timespan) t
    -> bool

  val compare :
       ('length -> 'length -> int)
    -> ('time -> 'time -> int)
    -> ('timespan -> 'timespan -> int)
    -> ('length, 'time, 'timespan) t
    -> ('length, 'time, 'timespan) t
    -> int

  val hash_fold_t :
       (Ppx_hash_lib.Std.Hash.state -> 'length -> Ppx_hash_lib.Std.Hash.state)
    -> (Ppx_hash_lib.Std.Hash.state -> 'time -> Ppx_hash_lib.Std.Hash.state)
    -> (Ppx_hash_lib.Std.Hash.state -> 'timespan -> Ppx_hash_lib.Std.Hash.state)
    -> Ppx_hash_lib.Std.Hash.state
    -> ('length, 'time, 'timespan) t
    -> Ppx_hash_lib.Std.Hash.state

  val t_of_sexp :
       (Ppx_sexp_conv_lib.Sexp.t -> 'length)
    -> (Ppx_sexp_conv_lib.Sexp.t -> 'time)
    -> (Ppx_sexp_conv_lib.Sexp.t -> 'timespan)
    -> Ppx_sexp_conv_lib.Sexp.t
    -> ('length, 'time, 'timespan) t

  val sexp_of_t :
       ('length -> Ppx_sexp_conv_lib.Sexp.t)
    -> ('time -> Ppx_sexp_conv_lib.Sexp.t)
    -> ('timespan -> Ppx_sexp_conv_lib.Sexp.t)
    -> ('length, 'time, 'timespan) t
    -> Ppx_sexp_conv_lib.Sexp.t

  val to_hlist :
       ('length, 'time, 'timespan) t
    -> ( unit
       ,    'length
         -> 'length
         -> 'length
         -> 'length
         -> 'length
         -> 'length
         -> 'length
         -> 'length
         -> 'length
         -> 'length
         -> 'timespan
         -> 'timespan
         -> 'timespan
         -> 'timespan
         -> 'time
         -> unit )
       Snarky_backendless.H_list.t

  val of_hlist :
       ( unit
       ,    'length
         -> 'length
         -> 'length
         -> 'length
         -> 'length
         -> 'length
         -> 'length
         -> 'length
         -> 'length
         -> 'length
         -> 'timespan
         -> 'timespan
         -> 'timespan
         -> 'timespan
         -> 'time
         -> unit )
       Snarky_backendless.H_list.t
    -> ('length, 'time, 'timespan) t
end

module Stable : sig
  module V1 : sig
    type t =
      ( Mina_numbers.Length.Stable.V1.t
      , Block_time.Stable.V1.t
      , Block_time.Span.Stable.V1.t )
      Poly.t

    val compare : t -> t -> Ppx_deriving_runtime.int

    val to_yojson : t -> Yojson.Safe.t

    val version : int

    val __versioned__ : unit

    val equal : t -> t -> bool

    val hash_fold_t :
      Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

    val hash : t -> Ppx_hash_lib.Std.Hash.hash_value

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

val compare : t -> t -> Ppx_deriving_runtime.int

val to_yojson : t -> Yojson.Safe.t

val equal : t -> t -> bool

val hash_fold_t :
  Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

val hash : t -> Ppx_hash_lib.Std.Hash.hash_value

val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

type var =
  ( Mina_numbers.Length.Checked.t
  , Block_time.Unpacked.var
  , Block_time.Span.Unpacked.var )
  Poly.t

module type M_intf = sig
  type t

  type length

  type time

  type timespan

  type bool_type

  val constant : int -> t

  val of_length : length -> t

  val to_length : t -> length

  val of_timespan : timespan -> t

  val to_timespan : t -> timespan

  val of_time : time -> t

  val to_time : t -> time

  val zero : t

  val one : t

  val ( / ) : t -> t -> t

  val ( * ) : t -> t -> t

  val ( + ) : t -> t -> t

  val min : t -> t -> t
end

module Constants_UInt32 : sig
  type t

  type length = Mina_numbers.Length.t

  type time = Block_time.t

  type timespan = Block_time.Span.t

  type bool_type

  val constant : int -> t

  val of_length : length -> t

  val to_length : t -> length

  val of_timespan : timespan -> t

  val to_timespan : t -> timespan

  val of_time : time -> t

  val to_time : t -> time

  val zero : t

  val one : t

  val ( / ) : t -> t -> t

  val ( * ) : t -> t -> t

  val ( + ) : t -> t -> t

  val min : t -> t -> t
end

module Constants_checked : sig
  type t

  type length = Mina_numbers.Length.Checked.t

  type time = Block_time.Unpacked.var

  type timespan = Block_time.Span.Unpacked.var

  type bool_type

  val constant : int -> t

  val of_length : length -> t

  val to_length : t -> length

  val of_timespan : timespan -> t

  val to_timespan : t -> timespan

  val of_time : time -> t

  val to_time : t -> time

  val zero : t

  val one : t

  val ( / ) : t -> t -> t

  val ( * ) : t -> t -> t

  val ( + ) : t -> t -> t

  val min : t -> t -> t
end

val create' :
     (module M_intf
        with type length = 'a
         and type time = 'b
         and type timespan = 'c)
  -> constraint_constants:Genesis_constants.Constraint_constants.t
  -> protocol_constants:('a, 'a, 'b) Genesis_constants.Protocol.Poly.t
  -> ('a, 'b, 'c) Poly.t

val create :
     constraint_constants:Genesis_constants.Constraint_constants.t
  -> protocol_constants:Genesis_constants.Protocol.t
  -> t

val for_unit_tests : t lazy_t

val to_protocol_constants :
     ('a, 'b, 'c) Poly.t
  -> ('a, 'a, 'b) Mina_base.Protocol_constants_checked.Poly.t

val data_spec :
  ( 'a
  , 'b
  ,    Constants_checked.length
    -> Constants_checked.length
    -> Constants_checked.length
    -> Constants_checked.length
    -> Constants_checked.length
    -> Constants_checked.length
    -> Constants_checked.length
    -> Constants_checked.length
    -> Constants_checked.length
    -> Constants_checked.length
    -> Constants_checked.timespan
    -> Constants_checked.timespan
    -> Constants_checked.timespan
    -> Constants_checked.timespan
    -> Constants_checked.time
    -> 'a
  ,    Mina_numbers__Length.t
    -> Mina_numbers__Length.t
    -> Mina_numbers__Length.t
    -> Mina_numbers__Length.t
    -> Mina_numbers__Length.t
    -> Mina_numbers__Length.t
    -> Mina_numbers__Length.t
    -> Mina_numbers__Length.t
    -> Mina_numbers__Length.t
    -> Mina_numbers__Length.t
    -> Block_time.Span.Unpacked.value
    -> Block_time.Span.Unpacked.value
    -> Block_time.Span.Unpacked.value
    -> Block_time.Span.Unpacked.value
    -> Block_time.Unpacked.value
    -> 'b
  , Pickles__Impls.Step.Impl.Internal_Basic.Field.t
  , (unit, unit) Pickles__Impls.Step.Impl.Internal_Basic.Checked.t )
  Snark_params.Tick.Data_spec.data_spec

val typ :
  ( ( Constants_checked.length
    , Constants_checked.time
    , Constants_checked.timespan )
    Poly.t
  , ( Mina_numbers__Length.t
    , Block_time.Unpacked.value
    , Block_time.Span.Unpacked.value )
    Poly.t )
  Snark_params.Tick.Typ.t

val to_input : t -> ('a, bool) Random_oracle.Input.t

val gc_parameters :
     t
  -> [> `Acceptable_network_delay of Unsigned.UInt32.t ]
     * [> `Gc_width of Unsigned.UInt32.t ]
     * [> `Gc_width_epoch of Unsigned.UInt32.t ]
     * [> `Gc_width_slot of Unsigned.UInt32.t ]
     * [> `Gc_interval of Unsigned.UInt32.t ]

module Checked : sig
  val to_input :
       var
    -> ( ('a, Snark_params.Tick.Boolean.var) Random_oracle.Input.t
       , 'b )
       Pickles__Impls.Step.Impl.Internal_Basic.Checked.t

  val create :
       constraint_constants:Genesis_constants.Constraint_constants.t
    -> protocol_constants:Mina_base.Protocol_constants_checked.var
    -> (var, 'a) Snark_params.Tick.Checked.t
end
