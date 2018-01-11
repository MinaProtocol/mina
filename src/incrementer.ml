open Core_kernel

module type S = sig
  type t = private Bigstring.t
  [@@deriving bin_io, compare]

  val zero : t

  val increment : t -> t

  module Snarkable : functor (Impl : Snark_intf.S) ->
    Impl.Snarkable.Bits.S
end

module Make (ByteLength : sig val byte_length : int end) : S = struct
  type t = Bigstring.t
  [@@deriving bin_io, compare]

  let zero = Bigstring.init ~f:(fun _ -> '\x00') ByteLength.byte_length

  let inc_with_overflow c =
    match Char.to_int c with
    | 255 -> `Carry
    | _ as x -> `NoCarry (Char.of_int_exn (x+1))

  let increment t : t =
    let t' = Bigstring.create ByteLength.byte_length in
    Bigarray.Array1.blit t t';
    let rec go pos =
      let c : char = Bigarray.Array1.get t' pos in
      match inc_with_overflow c with
      | `NoCarry c' -> Bigarray.Array1.set t' pos c'
      | `Carry ->
          Bigarray.Array1.set t' pos '\x00';
          go (pos-1)
    in
    go (ByteLength.byte_length - 1);
    t'

  module Snarkable (Impl : Camlsnark.Snark_intf.S) =
    Bits.Make_bigstring(Impl)(ByteLength)
end

