open Ctypes

let with_prefix = Format.sprintf "%s_%s"

module type Prefix = sig
  val prefix : string -> string
end

module type Type = sig
  type t

  val typ : t typ
end

module Bigint (P : Prefix) (F : Ctypes.FOREIGN) = struct
  open F

  let prefix = with_prefix (P.prefix "bigint")

  type t = unit ptr

  let typ = ptr void

  let of_decimal_string =
    foreign (prefix "of_decimal_string") (string @-> returning typ)

  let num_limbs = foreign (prefix "num_limbs") (void @-> returning int)

  let to_data = foreign (prefix "to_data") (typ @-> returning (ptr char))

  let of_data = foreign (prefix "of_data") (ptr char @-> returning typ)

  let bytes_per_limb =
    foreign (prefix "bytes_per_limb") (void @-> returning int)

  let div = foreign (prefix "div") (typ @-> typ @-> returning typ)

  let of_numeral =
    foreign (prefix "of_numeral") (string @-> int @-> int @-> returning typ)

  let compare = foreign (prefix "compare") (typ @-> typ @-> returning bool)

  let test_bit = foreign (prefix "test_bit") (typ @-> int @-> returning bool)

  let delete = foreign (prefix "delete") (typ @-> returning void)

  let print = foreign (prefix "print") (typ @-> returning void)

  (* The return type of this is __supposed to be__ a C++ Vector<long>.
     We can't build one of these in Rust, so this function just panics when
     called.

     AFAICT, this isn't currently used anywhere anyway.
  *)
  let find_wnaf =
    foreign (prefix "find_wnaf") (size_t @-> typ @-> returning (ptr void))
end

module Vector (P : Prefix) (E : Type) (F : Ctypes.FOREIGN) = struct
  open F

  let prefix = with_prefix (P.prefix "vector")

  type t = unit ptr

  let typ = ptr void

  let create = foreign (prefix "create") (void @-> returning typ)

  let length = foreign (prefix "length") (typ @-> returning int)

  let emplace_back =
    foreign (prefix "emplace_back") (typ @-> E.typ @-> returning void)

  let get = foreign (prefix "get") (typ @-> int @-> returning E.typ)

  let delete = foreign (prefix "delete") (typ @-> returning void)
end

module Field (P : Prefix) (Bigint : Type) (F : Ctypes.FOREIGN) = struct
  open F

  module T = struct
    type t = unit ptr

    let typ = ptr void
  end

  include T

  let prefix = P.prefix

  let size_in_bits = foreign (prefix "size_in_bits") (void @-> returning int)

  let size = foreign (prefix "size") (void @-> returning Bigint.typ)

  let is_square = foreign (prefix "is_square") (typ @-> returning bool)

  let sqrt = foreign (prefix "sqrt") (typ @-> returning typ)

  let random = foreign (prefix "random") (void @-> returning typ)

  let of_int = foreign (prefix "of_int") (int @-> returning typ)

  let inv = foreign (prefix "inv") (typ @-> returning typ)

  let square = foreign (prefix "square") (typ @-> returning typ)

  let add = foreign (prefix "add") (typ @-> typ @-> returning typ)

  let mul = foreign (prefix "mul") (typ @-> typ @-> returning typ)

  let sub = foreign (prefix "sub") (typ @-> typ @-> returning typ)

  let mut_add = foreign (prefix "mut_add") (typ @-> typ @-> returning void)

  let mut_mul = foreign (prefix "mut_mul") (typ @-> typ @-> returning void)

  let mut_sub = foreign (prefix "mut_sub") (typ @-> typ @-> returning void)

  let copy = foreign (prefix "copy") (typ @-> typ @-> returning void)

  let rng = foreign (prefix "rng") (int @-> returning typ)

  let delete = foreign (prefix "delete") (typ @-> returning void)

  let print = foreign (prefix "print") (typ @-> returning void)

  let equal = foreign (prefix "equal") (typ @-> typ @-> returning bool)

  let to_bigint = foreign (prefix "to_bigint") (typ @-> returning Bigint.typ)

  let of_bigint = foreign (prefix "of_bigint") (Bigint.typ @-> returning typ)

  module Vector =
    Vector (struct
        let prefix = prefix
      end)
      (T)
      (F)
end

module Full (F : Ctypes.FOREIGN) = struct
  let prefix = with_prefix "camlsnark_bn382"

  module Bigint = Bigint (struct let prefix = prefix end) (F)

  module Fp =
    Field (struct
        let prefix = with_prefix (prefix "fp")
      end)
      (Bigint)
      (F)

  module Fq =
    Field (struct
        let prefix = with_prefix (prefix "fq")
      end)
      (Bigint)
      (F)
end
