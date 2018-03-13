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

module Make
    (Unsigned : Unsigned.S)
    (Signed : sig type t [@@deriving bin_io] end)
    (M : sig
       val to_signed : Unsigned.t -> Signed.t
       val of_signed : Signed.t -> Unsigned.t
       val length : int
     end)
= struct
  assert (M.length < Tick.Field.size_in_bits - 1)

  type t = Unsigned.t

  include Make_bin_io(struct
      type v = Unsigned.t
      type t = Signed.t [@@deriving bin_io]
      let there = M.to_signed
      let back = M.of_signed
    end)

  include Bits.Snarkable.Small_bit_vector(Tick)(struct
      include M
      include Unsigned
      let empty = zero
      let get t i = Infix.((t lsr i) land one = one)
      let set v i b =
        if b
        then Infix.(v lor (one lsl i))
        else Infix.(v land (lognot (one lsl i)))
    end)

  let zero : Unpacked.var =
    List.init M.length ~f:(fun _ -> Boolean.false_)

  let (-) (x : Unpacked.var) (y : Unpacked.var) =
    unpack_var (Cvar.sub (pack_var x) (pack_var y))

  let (+) (x : Unpacked.var) (y : Unpacked.var) =
    unpack_var (Cvar.add (pack_var x) (pack_var y))
end

module T64 = Make(Unsigned.UInt64)(Int64)(struct
    let length = 64
    let to_signed = Unsigned.UInt64.to_int64
    let of_signed = Unsigned.UInt64.of_int64
  end)

module T32 = Make(Unsigned.UInt32)(Int32)(struct
    let length = 32
    let to_signed = Unsigned.UInt32.to_int32
    let of_signed = Unsigned.UInt32.of_int32
  end)
