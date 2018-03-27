open Core
open Snark_params
open Tick
open Let_syntax

module Make_bin_io
    (M : sig
       type v
       type t
       val bin_t : t Bin_prot.Type_class.t
       val there : v -> t
       val back : t -> v
     end) = struct

  let ({ Bin_prot.Type_class.
          reader = bin_reader_t
        ; writer = bin_writer_t
        ; shape = bin_shape_t
        } as bin_t)
    =
    Bin_prot.Type_class.cnv Fn.id M.there M.back M.bin_t

  let { Bin_prot.Type_class.read = bin_read_t; vtag_read = __bin_read_t__ } = bin_reader_t
  let { Bin_prot.Type_class.write = bin_write_t; size = bin_size_t } = bin_writer_t
end

module type Basic = sig
  type t
  [@@deriving sexp, compare, eq]

  module Stable : sig
    module V1 : sig
      type nonrec t = t
      [@@deriving bin_io, sexp, compare, eq]
    end
  end

  include Bits_intf.S with type t := t

  val zero : t

  val of_string : string -> t
  val to_string : t -> string

  type var
  val typ : (var, t) Typ.t

  val of_int : int -> t

  val var_of_t : t -> var

  val var_to_bits : var -> Boolean.var list
end

module type S = sig
  include Basic

  val add : t -> t -> t option
  val sub : t -> t -> t option
  val (+) : t -> t -> t option
  val (-) : t -> t -> t option

  module Checked : sig
    val add : var -> var -> (var, _) Checked.t
    val sub : var -> var -> (var, _) Checked.t
    val (+) : var -> var -> (var, _) Checked.t
    val (-) : var -> var -> (var, _) Checked.t
  end
end

module Make
    (Unsigned : Unsigned.S)
    (Signed : sig type t [@@deriving bin_io] end)
    (M : sig
       val to_signed : Unsigned.t -> Signed.t
       val of_signed : Signed.t -> Unsigned.t
       val length : int
     end)
    : S with type t = Unsigned.t
= struct
  assert (M.length < Tick.Field.size_in_bits - 1)

  module Stable = struct
    module V1 = struct
      type t = Unsigned.t

      let compare = Unsigned.compare
      let equal t1 t2 = compare t1 t2 = 0

      include Make_bin_io(struct
          type v = Unsigned.t
          type t = Signed.t [@@deriving bin_io]
          let there = M.to_signed
          let back = M.of_signed
        end)
      include Sexpable.Of_stringable(Unsigned)
    end
  end

  include Stable.V1

  let of_int = Unsigned.of_int
  let of_string = Unsigned.of_string
  let to_string = Unsigned.to_string

  module Vector = struct
    include M
    include Unsigned
    let empty = zero
    let get t i = Infix.((t lsr i) land one = one)
    let set v i b =
      if b
      then Infix.(v lor (one lsl i))
      else Infix.(v land (lognot (one lsl i)))
  end

  include (Bits.Vector.Make(Vector) : Bits_intf.S with type t := t)

  include Bits.Snarkable.Small_bit_vector(Tick)(Vector)

  include Unpacked

  let zero = Unsigned.zero

  let sub x y =
    if compare x y < 0
    then None
    else Some (Unsigned.sub x y)

  let add x y =
    let z = Unsigned.add x y in
    if compare z x < 0
    then None
    else Some z

  let (+) = add
  let (-) = sub

  let var_of_t t =
    List.init (M.length) (fun i -> Boolean.var_of_value (Vector.get t i))

  module Checked = struct
    let sub (x : Unpacked.var) (y : Unpacked.var) =
      unpack_var (Cvar.sub (pack_var x) (pack_var y))

    let add (x : Unpacked.var) (y : Unpacked.var) =
      unpack_var (Cvar.add (pack_var x) (pack_var y))

    let (-) = sub
    let (+) = add
  end
end

module Amount = Make(Unsigned.UInt64)(Int64)(struct
    let length = 64
    let to_signed = Unsigned.UInt64.to_int64
    let of_signed = Unsigned.UInt64.of_int64
  end)

module Fee = Make(Unsigned.UInt32)(Int32)(struct
    let length = 32
    let to_signed = Unsigned.UInt32.to_int32
    let of_signed = Unsigned.UInt32.of_int32
  end)

module Balance = struct
  include (Amount : Basic with type t = Amount.t and type var = Amount.var)

  let add_amount = Amount.add
  let sub_amount = Amount.sub
  let (+) = add_amount
  let (-) = sub_amount

  module Checked = struct
    let add_amount = Amount.Checked.add
    let sub_amount = Amount.Checked.sub
    let (+) = add_amount
    let (-) = sub_amount
  end
end
