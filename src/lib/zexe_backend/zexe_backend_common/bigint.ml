open Core
open Snarky_bn382

module type Intf = sig
  type t [@@deriving bin_io, sexp, compare]

  include Intf.Type_with_delete with type t := t

  val length_in_bytes : int

  val to_hex_string : t -> string

  val of_hex_string : string -> t

  val test_bit : t -> int -> bool

  val to_ptr : t -> char Ctypes.ptr

  val of_ptr : char Ctypes.ptr -> t

  val of_data : Bigstring.t -> bitcount:int -> t

  val of_decimal_string : string -> t

  val of_numeral : string -> base:int -> t
end

module type Bindings = sig
  type t

  val delete : t -> unit

  val to_data : t -> char Ctypes.ptr

  val of_data : char Ctypes.ptr -> t

  val compare : t -> t -> Unsigned.UInt8.t

  val test_bit : t -> int -> bool

  val of_decimal_string : string -> t

  val of_numeral : string -> int -> int -> t
end

module Make
    (B : Bindings) (M : sig
        val length_in_bytes : int
    end) : Intf with type t = B.t = struct
  open B

  let delete = delete

  let to_ptr = to_data

  let of_ptr = of_data

  let length_in_bytes = M.length_in_bytes

  type nonrec t = t

  let to_hex_string t =
    let data = to_data t in
    String.concat
      (List.init length_in_bytes ~f:(fun i ->
           sprintf "%02x" (Char.to_int Ctypes.(!@(data +@ i))) ))
    |> sprintf "0x%s"

  let sexp_of_t t = to_hex_string t |> Sexp.of_string

  let to_bigstring t =
    let limbs = to_data t in
    Bigstring.init length_in_bytes ~f:(fun i -> Ctypes.(!@(limbs +@ i)))

  let of_bigstring s =
    let ptr = Ctypes.bigarray_start Ctypes.array1 s in
    let t = of_data ptr in
    Caml.Gc.finalise delete t ; t

  let of_hex_string s =
    assert (s.[0] = '0' && s.[1] = 'x') ;
    of_bigstring (Hex.decode ~pos:2 ~init:Bigstring.init s)

  let%test_unit "hex test" =
    let bytes =
      String.init length_in_bytes ~f:(fun _ -> Char.of_int_exn (Random.int 255))
    in
    let h = "0x" ^ Hex.encode bytes in
    [%test_eq: string] h (to_hex_string (of_hex_string h))

  let t_of_sexp s = of_hex_string (String.t_of_sexp s)

  include Bin_prot.Utils.Of_minimal (struct
    type nonrec t = t

    let bin_shape_t =
      Bin_prot.Shape.basetype
        (Bin_prot.Shape.Uuid.of_string
           (sprintf "zexe_backend_bigint_%d" M.length_in_bytes))
        []

    let __bin_read_t__ _buf ~pos_ref _vint =
      Bin_prot.Common.raise_variant_wrong_type "Bigint.t" !pos_ref

    let bin_size_t _ = M.length_in_bytes

    let bin_write_t buf ~pos t =
      let len = M.length_in_bytes in
      let limbs = to_data t in
      let bs = Ctypes.bigarray_of_ptr Ctypes.array1 len Bigarray.Char limbs in
      Bigstring.blit ~src:bs ~dst:buf ~src_pos:0 ~dst_pos:pos ~len ;
      pos + len

    let bin_read_t buf ~pos_ref =
      let remaining_bytes = Bigstring.length buf - !pos_ref in
      if remaining_bytes < M.length_in_bytes then
        failwithf "Bigint.bin_read_t: Expected %d bytes, got %d"
          M.length_in_bytes remaining_bytes () ;
      let ptr = Ctypes.(bigarray_start array1 buf +@ !pos_ref) in
      let t = of_data ptr in
      Caml.Gc.finalise delete t ;
      pos_ref := M.length_in_bytes + !pos_ref ;
      t
  end)

  let test_bit = test_bit

  let of_data bs ~bitcount =
    assert (bitcount <= length_in_bytes * 8) ;
    of_bigstring bs

  let of_decimal_string = of_decimal_string

  let of_numeral s ~base = of_numeral s (String.length s) base

  let compare x y =
    match Unsigned.UInt8.to_int (compare x y) with 255 -> -1 | x -> x
end
