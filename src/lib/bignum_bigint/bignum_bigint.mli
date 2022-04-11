type t = Bigint.t

val of_float : float -> t

val to_float : t -> float

val of_int_exn : int -> t

val to_int_exn : t -> int

type comparator_witness = Bigint.comparator_witness

val validate_positive : t Base__.Validate.check

val validate_non_negative : t Base__.Validate.check

val validate_negative : t Base__.Validate.check

val validate_non_positive : t Base__.Validate.check

val is_positive : t -> bool

val is_non_negative : t -> bool

val is_negative : t -> bool

val is_non_positive : t -> bool

val sign : t -> Base__.Sign0.t

val to_string_hum : ?delimiter:char -> t -> string

val zero : t

val one : t

val minus_one : t

val ( + ) : t -> t -> t

val ( - ) : t -> t -> t

val ( * ) : t -> t -> t

val ( ** ) : t -> t -> t

val neg : t -> t

val ( ~- ) : t -> t

val ( /% ) : t -> t -> t

val ( % ) : t -> t -> t

val ( / ) : t -> t -> t

val rem : t -> t -> t

val ( // ) : t -> t -> float

val ( land ) : t -> t -> t

val ( lor ) : t -> t -> t

val ( lxor ) : t -> t -> t

val lnot : t -> t

val ( lsl ) : t -> int -> t

val ( asr ) : t -> int -> t

val round :
  ?dir:[ `Down | `Nearest | `Up | `Zero ] -> t -> to_multiple_of:t -> t

val round_towards_zero : t -> to_multiple_of:t -> t

val round_down : t -> to_multiple_of:t -> t

val round_up : t -> to_multiple_of:t -> t

val round_nearest : t -> to_multiple_of:t -> t

val abs : t -> t

val succ : t -> t

val pred : t -> t

val pow : t -> t -> t

val bit_and : t -> t -> t

val bit_or : t -> t -> t

val bit_xor : t -> t -> t

val bit_not : t -> t

val popcount : t -> int

val shift_left : t -> int -> t

val shift_right : t -> int -> t

val decr : t Base__.Import.ref -> unit

val incr : t Base__.Import.ref -> unit

val of_int32_exn : int32 -> t

val to_int32_exn : t -> int32

val of_int64_exn : int64 -> t

val of_nativeint_exn : nativeint -> t

val to_nativeint_exn : t -> nativeint

val of_float_unchecked : float -> t

module O = Bigint.O

val typerep_of_t : t Typerep_lib.Std_internal.Typerep.t

val typename_of_t : t Typerep_lib.Typename.t

module Hex = Bigint.Hex

val bin_shape_t : Bin_prot.Shape.t

val t_of_sexp : Sexplib0.Sexp.t -> t

val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

val of_string : string -> t

val to_string : t -> string

val pp : Base__.Formatter.t -> t -> unit

val ( >= ) : t -> t -> bool

val ( <= ) : t -> t -> bool

val ( = ) : t -> t -> bool

val ( > ) : t -> t -> bool

val ( < ) : t -> t -> bool

val ( <> ) : t -> t -> bool

val equal : t -> t -> bool

val compare : t -> t -> int

val min : t -> t -> t

val max : t -> t -> t

val ascending : t -> t -> int

val descending : t -> t -> int

val between : t -> low:t -> high:t -> bool

val clamp_exn : t -> min:t -> max:t -> t

val clamp : t -> min:t -> max:t -> t Base__.Or_error.t

val validate_lbound : min:t Base__.Maybe_bound.t -> t Base__.Validate.check

val validate_ubound : max:t Base__.Maybe_bound.t -> t Base__.Validate.check

val validate_bound :
     min:t Base__.Maybe_bound.t
  -> max:t Base__.Maybe_bound.t
  -> t Base__.Validate.check

module Replace_polymorphic_compare = Bigint.Replace_polymorphic_compare

val comparator : (t, comparator_witness) Core_kernel__.Comparator.comparator

module Map = Bigint.Map
module Set = Bigint.Set

val hash_fold_t :
  Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

val hash : t -> Ppx_hash_lib.Std.Hash.hash_value

val hashable : t Core_kernel__.Hashtbl.Hashable.t

module Table = Bigint.Table
module Hash_set = Bigint.Hash_set
module Hash_queue = Bigint.Hash_queue

val quickcheck_generator : t Base_quickcheck.Generator.t

val quickcheck_observer : t Base_quickcheck.Observer.t

val quickcheck_shrinker : t Base_quickcheck.Shrinker.t

val gen_incl : t -> t -> t Base_quickcheck.Generator.t

val gen_uniform_incl : t -> t -> t Base_quickcheck.Generator.t

val gen_log_uniform_incl : t -> t -> t Base_quickcheck.Generator.t

val gen_log_incl : t -> t -> t Base_quickcheck.Generator.t

val to_int64_exn : t -> Core_kernel.Int64.t

val to_int : t -> int option

val to_int32 : t -> Core_kernel.Int32.t option

val to_int64 : t -> Core_kernel.Int64.t option

val to_nativeint : t -> nativeint option

val of_int : int -> t

val of_int32 : Core_kernel.Int32.t -> t

val of_int64 : Core_kernel.Int64.t -> t

val of_nativeint : nativeint -> t

val to_zarith_bigint : t -> Bigint__.Zarith.Z.t

val of_zarith_bigint : Bigint__.Zarith.Z.t -> t

val random : ?state:Core_kernel.Random.State.t -> t -> t

val gen_positive : t Core_kernel.Quickcheck.Generator.t

val gen_negative : t Core_kernel.Quickcheck.Generator.t

module Stable = Bigint.Stable
module Unstable = Bigint.Unstable

val bin_size_t : t Core_kernel.Bin_prot.Size.sizer [@@deprecated "X"]

val bin_write_t : t Core_kernel.Bin_prot.Write.writer [@@deprecated "X"]

val bin_read_t : t Core_kernel.Bin_prot.Read.reader [@@deprecated "X"]

val __bin_read_t__ : (int -> t) Core_kernel.Bin_prot.Read.reader
  [@@deprecated "X"]

val bin_writer_t : t Core_kernel.Bin_prot.Type_class.writer [@@deprecated "X"]

val bin_reader_t : t Core_kernel.Bin_prot.Type_class.reader [@@deprecated "X"]

val bin_t : t Core_kernel.Bin_prot.Type_class.t [@@deprecated "X"]

val of_bool : bool -> t

val of_bit_fold_lsb : bool Fold_lib.Fold.t -> t

val of_bits_lsb : bool list -> t
