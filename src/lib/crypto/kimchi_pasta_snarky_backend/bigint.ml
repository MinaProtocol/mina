open Core_kernel

module type Bindings = sig
  type t

  val num_limbs : unit -> int

  val bytes_per_limb : unit -> int

  val compare : t -> t -> int

  val div : t -> t -> t

  val test_bit : t -> int -> bool

  val print : t -> unit

  val to_string : t -> string

  val of_numeral : string -> int -> int -> t

  val of_decimal_string : string -> t

  val to_bytes : t -> Bytes.t

  val of_bytes : Bytes.t -> t
end

module type Intf = sig
  type t [@@deriving bin_io, sexp, compare]

  include Bindings with type t := t

  val num_limbs : int

  val bytes_per_limb : int

  val length_in_bytes : int

  val to_hex : t -> string

  val to_hex_string : t -> string

  val of_hex_string : ?reverse:bool -> string -> t

  val of_numeral : string -> base:int -> t
end

module Make
    (B : Bindings) (M : sig
      val length_in_bytes : int
    end) : Intf with type t = B.t = struct
  include B

  let num_limbs = num_limbs ()

  let bytes_per_limb = bytes_per_limb ()

  let length_in_bytes = num_limbs * bytes_per_limb

  let to_hex t =
    let data = to_bytes t in
    String.uppercase (Hex.encode ~reverse:true (Bytes.to_string data))

  let to_hex_string t = "0x" ^ to_hex t

  let sexp_of_t t = to_hex_string t |> Sexp.of_string

  let of_hex_string ?(reverse = true) s =
    if Char.equal s.[0] '0' && (Char.equal s.[1] 'x' || Char.equal s.[1] 'X')
    then
      let s = String.drop_prefix s 2 in
      Option.try_with (fun () -> Hex.decode ~init:Bytes.init ~reverse s)
      |> Option.value_exn ~here:[%here]
      |> of_bytes
    else failwith "Bigint.of_hex_string: Hex string must start with 0x or 0X"

  let t_of_sexp s = of_hex_string (String.t_of_sexp s)

  include Bin_prot.Utils.Of_minimal (struct
    type nonrec t = t

    (* increment if serialization changes *)
    let version = 1

    let bin_shape_t =
      Bin_prot.Shape.basetype
        (Bin_prot.Shape.Uuid.of_string
           (sprintf "kimchi_backend_bigint_%d_V%d" M.length_in_bytes version) )
        []

    let __bin_read_t__ _buf ~pos_ref _vint =
      Bin_prot.Common.raise_variant_wrong_type "Bigint.t" !pos_ref

    let bin_size_t _ = length_in_bytes

    let bin_write_t buf ~pos t =
      let bytes = to_bytes t in
      let len = length_in_bytes in
      Bigstring.From_bytes.blit ~src:bytes ~src_pos:0 ~len:length_in_bytes
        ~dst:buf ~dst_pos:pos ;
      pos + len

    let bin_read_t buf ~pos_ref =
      let remaining_bytes = Bigstring.length buf - !pos_ref in
      let len = length_in_bytes in
      if remaining_bytes < len then
        failwithf "Bigint.bin_read_t: Expected %d bytes, got %d"
          M.length_in_bytes remaining_bytes () ;
      let bytes = Bigstring.To_bytes.sub ~pos:!pos_ref ~len buf in
      pos_ref := len + !pos_ref ;
      of_bytes bytes
  end)

  let of_numeral s ~base = of_numeral s (String.length s) base
end
