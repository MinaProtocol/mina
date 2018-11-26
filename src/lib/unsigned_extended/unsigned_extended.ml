open Core_kernel
open Snark_params

type uint64 = Unsigned.uint64

module type S = sig
  type t [@@deriving bin_io, sexp, hash, compare, eq]

  val length_in_bits : int

  include Hashable.S with type t := t

  include Unsigned.S with type t := t

  val to_uint64 : t -> uint64

  val of_uint64 : uint64 -> t

  val ( < ) : t -> t -> bool

  val ( > ) : t -> t -> bool

  val ( = ) : t -> t -> bool

  val ( <= ) : t -> t -> bool

  val ( >= ) : t -> t -> bool
end

module type F = functor
  (Unsigned : Unsigned.S)
  (Signed :sig
           
           type t [@@deriving bin_io]
         end)
  (M :sig
      
      val to_signed : Unsigned.t -> Signed.t

      val of_signed : Signed.t -> Unsigned.t

      val to_uint64 : Unsigned.t -> uint64

      val of_uint64 : uint64 -> Unsigned.t

      val length : int
    end)
  -> S with type t = Unsigned.t

module Make_bin_io (M : sig
  type v

  type t

  val bin_t : t Bin_prot.Type_class.t

  val there : v -> t

  val back : t -> v
end) =
struct
  let ( { Bin_prot.Type_class.reader= bin_reader_t
        ; writer= bin_writer_t
        ; shape= bin_shape_t } as bin_t ) =
    Bin_prot.Type_class.cnv Fn.id M.there M.back M.bin_t

  let {Bin_prot.Type_class.read= bin_read_t; vtag_read= __bin_read_t__} =
    bin_reader_t

  let {Bin_prot.Type_class.write= bin_write_t; size= bin_size_t} = bin_writer_t
end

module type Unsigned_intf = Unsigned.S

module Extend
    (Unsigned : Unsigned.S) (Signed : sig
        type t [@@deriving bin_io]
    end) (M : sig
      val to_signed : Unsigned.t -> Signed.t

      val of_signed : Signed.t -> Unsigned.t

      val to_uint64 : Unsigned.t -> uint64

      val of_uint64 : uint64 -> Unsigned.t

      val length : int
    end) : S with type t = Unsigned.t = struct
  ;;
  assert (M.length < Tick.Field.size_in_bits - 3)

  let length_in_bits = M.length

  module T = struct
    include Sexpable.Of_stringable (Unsigned)

    type t = Unsigned.t

    let compare = Unsigned.compare

    let equal t1 t2 = compare t1 t2 = 0

    let hash_fold_t s t = Int64.hash_fold_t s (Unsigned.to_int64 t)

    let hash t = Int64.hash (Unsigned.to_int64 t)
  end

  include T
  include Hashable.Make (T)

  include Bin_prot.Utils.Make_binable (struct
    module Binable = Signed

    type t = Unsigned.t

    let to_binable = M.to_signed

    let of_binable = M.of_signed
  end)

  include (Unsigned : Unsigned_intf with type t := t)

  let to_uint64 = M.to_uint64

  let of_uint64 = M.of_uint64

  let ( < ) x y = compare x y < 0

  let ( > ) x y = compare x y > 0

  let ( = ) x y = compare x y = 0

  let ( <= ) x y = compare x y <= 0

  let ( >= ) x y = compare x y >= 0
end

module UInt64 =
  Extend (Unsigned.UInt64) (Int64)
    (struct
      let length = 64

      let to_signed = Unsigned.UInt64.to_int64

      let of_signed = Unsigned.UInt64.of_int64

      let to_uint64 = Fn.id

      let of_uint64 = Fn.id
    end)

module UInt32 =
  Extend (Unsigned.UInt32) (Int32)
    (struct
      let length = 32

      let to_signed = Unsigned.UInt32.to_int32

      let of_signed = Unsigned.UInt32.of_int32

      let to_uint64 =
        Fn.compose Unsigned.UInt64.of_int64 Unsigned.UInt32.to_int64

      let of_uint64 =
        Fn.compose Unsigned.UInt32.of_int64 Unsigned.UInt64.to_int64
    end)
