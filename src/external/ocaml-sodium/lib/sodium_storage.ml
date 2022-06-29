open Ctypes

type bigbytes =
  (char, Bigarray.int8_unsigned_elt, Bigarray.c_layout) Bigarray.Array1.t

module type S = sig
  type t

  type ctype

  val ctype : ctype typ

  val create : int -> t

  val zero : t -> int -> int -> unit

  val blit : t -> int -> t -> int -> int -> unit

  val sub : t -> int -> int -> t

  val length : t -> int

  val len_size_t : t -> PosixTypes.size_t

  val len_ullong : t -> Unsigned.ullong

  val to_ptr : t -> ctype

  val to_bytes : t -> Bytes.t

  val of_bytes : Bytes.t -> t
end

module Bigbytes = struct
  type t = bigbytes

  type ctype = char ptr

  let ctype = ptr char

  open Bigarray

  let create len = Array1.create char c_layout len

  let length str = Array1.dim str

  let len_size_t str = Unsigned.Size_t.of_int (Array1.dim str)

  let len_ullong str = Unsigned.ULLong.of_int (Array1.dim str)

  let to_ptr str = bigarray_start array1 str

  let zero str pos len = Array1.fill (Array1.sub str pos len) '\x00'

  let to_bytes str =
    let str' = Bytes.create (Array1.dim str) in
    Bytes.iteri (fun i _ -> Bytes.set str' i (Array1.unsafe_get str i)) str' ;
    str'

  let of_bytes str =
    let str' = create (Bytes.length str) in
    Bytes.iteri (Array1.unsafe_set str') str ;
    str'

  let sub = Array1.sub

  let blit src srcoff dst dstoff len =
    Array1.blit (Array1.sub src srcoff len) (Array1.sub dst dstoff len)
end

module Bytes = struct
  type t = Bytes.t

  type ctype = Bytes.t ocaml

  let ctype = ocaml_bytes

  let create len = Bytes.create len

  let length byt = Bytes.length byt

  let len_size_t byt = Unsigned.Size_t.of_int (Bytes.length byt)

  let len_ullong byt = Unsigned.ULLong.of_int (Bytes.length byt)

  let to_ptr byt = ocaml_bytes_start byt

  let zero byt pos len = Bytes.fill byt pos len '\x00'

  let to_bytes byt = Bytes.copy byt

  let of_bytes byt = Bytes.copy byt

  let sub = Bytes.sub

  let blit = Bytes.blit
end
