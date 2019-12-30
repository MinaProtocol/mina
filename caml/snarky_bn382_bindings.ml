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

  include (
    struct
        type t = unit ptr

        let typ = ptr void
      end :
      Type )

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

  let compare = foreign (prefix "compare") (typ @-> typ @-> returning uint8_t)

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

module Index
    (P : Prefix)
    (Constraint_matrix : Type)
    (G1Affine : Type)
    (F : Ctypes.FOREIGN) =
struct
  open F

  type t = unit ptr

  let typ = ptr void

  let prefix = P.prefix

  module M = Constraint_matrix

  let delete = foreign (prefix "delete") (typ @-> returning void)

  let create =
    foreign (prefix "create")
      (M.typ @-> M.typ @-> M.typ @-> size_t @-> size_t @-> returning typ)

  let m_poly_comm m f =
    foreign
      (prefix (Format.sprintf "%s_%s_comm" m f))
      (typ @-> returning G1Affine.typ)

  let ( (a_row_comm, a_col_comm, a_val_comm)
      , (b_row_comm, b_col_comm, b_val_comm)
      , (c_row_comm, c_col_comm, c_val_comm) ) =
    let map3 (a, b, c) f = (f a, f b, f c) in
    let polys = ("row", "col", "val") and mats = ("a", "b", "c") in
    map3 mats (fun m -> map3 polys (fun p -> m_poly_comm m p))
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

module Curve
    (P : Prefix)
    (BaseField : Type)
    (ScalarField : Type)
    (F : Ctypes.FOREIGN) =
struct
  open F

  let prefix = P.prefix

  include (
    struct
        type t = unit ptr

        let typ = ptr void
      end :
      Type )

  module Affine = struct
    let prefix = with_prefix (prefix "affine")

    include (
      struct
          type t = unit ptr

          let typ = ptr void
        end :
        Type )

    let x = foreign (prefix "x") (typ @-> returning BaseField.typ)

    let y = foreign (prefix "y") (typ @-> returning BaseField.typ)

    let delete = foreign (prefix "delete") (typ @-> returning void)
  end

  let delete = foreign (prefix "delete") (typ @-> returning void)

  let to_affine_exn =
    foreign (prefix "to_affine") (typ @-> returning Affine.typ)

  let of_affine_coordinates =
    foreign
      (prefix "of_affine_coordinates")
      (BaseField.typ @-> BaseField.typ @-> returning typ)

  let add = foreign (prefix "add") (typ @-> typ @-> returning typ)

  let scale =
    foreign (prefix "scale") (typ @-> ScalarField.typ @-> returning typ)

  let sub = foreign (prefix "sub") (typ @-> typ @-> returning typ)

  let negate = foreign (prefix "negate") (typ @-> returning typ)

  let random = foreign (prefix "random") (void @-> returning typ)

  let one = foreign (prefix "one") (void @-> returning typ)
end

module Marlin_proof
    (P : Prefix)
    (AffineCurve : Type)
    (ScalarField : Type)
    (Index : Type)
    (FieldVector : Type)
    (F : Ctypes.FOREIGN) =
struct
  open F

  include (
    struct
        type t = unit ptr

        let typ = ptr void
      end :
      Type )

  module Evals = struct
    include (
      struct
          type t = unit ptr

          let typ = ptr void
        end :
        Type )

    let prefix = with_prefix (P.prefix "evals")

    let f i = foreign (prefix i) (typ @-> returning ScalarField.typ)

    let f0 = f "0"

    let f1 = f "1"

    let f2 = f "2"
  end

  let prefix = P.prefix

  let create =
    foreign (prefix "create")
      (Index.typ @-> FieldVector.typ @-> FieldVector.typ @-> returning typ)

  let delete = foreign (prefix "delete") (typ @-> returning void)

  let f name f_typ = foreign (prefix name) (typ @-> returning f_typ)

  let w_comm = f "w_comm" AffineCurve.typ

  let za_comm = f "za_comm" AffineCurve.typ

  let zb_comm = f "zb_comm" AffineCurve.typ

  let h1_comm = f "h1_comm" AffineCurve.typ

  let g1_comm = f "g1_comm" AffineCurve.typ

  let h2_comm = f "h2_comm" AffineCurve.typ

  let g2_comm = f "g2_comm" AffineCurve.typ

  let h3_comm = f "h3_comm" AffineCurve.typ

  let g3_comm = f "g3_comm" AffineCurve.typ

  let w_eval = f "w_eval" ScalarField.typ

  let za_eval = f "za_eval" ScalarField.typ

  let zb_eval = f "zb_eval" ScalarField.typ

  let h1_eval = f "h1_eval" ScalarField.typ

  let g1_eval = f "g1_eval" ScalarField.typ

  let h2_eval = f "h2_eval" ScalarField.typ

  let g2_eval = f "g2_eval" ScalarField.typ

  let h3_eval = f "h3_eval" ScalarField.typ

  let g3_eval = f "g3_eval" ScalarField.typ

  let proof1 = f "proof1" AffineCurve.typ

  let proof2 = f "proof2" AffineCurve.typ

  let proof3 = f "proof3" AffineCurve.typ

  let sigma2 = f "sigma2" ScalarField.typ

  let sigma3 = f "sigma3" ScalarField.typ

  let row_evals_nocopy = f "row_evals_nocopy" Evals.typ

  let col_evals_nocopy = f "col_evals_nocopy" Evals.typ

  let val_evals_nocopy = f "val_evals_nocopy" Evals.typ
end

module Field
    (P : Prefix)
    (Bigint : Type)
    (Usize_vector : Type)
    (F : Ctypes.FOREIGN) =
struct
  open F

  module T : Type = struct
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

  let of_int = foreign (prefix "of_int") (uint64_t @-> returning typ)

  let to_string = foreign (prefix "to_string") (typ @-> returning string)

  let inv = foreign (prefix "inv") (typ @-> returning typ)

  let square = foreign (prefix "square") (typ @-> returning typ)

  let add = foreign (prefix "add") (typ @-> typ @-> returning typ)

  let negate = foreign (prefix "negate") (typ @-> returning typ)

  let mul = foreign (prefix "mul") (typ @-> typ @-> returning typ)

  let div = foreign (prefix "div") (typ @-> typ @-> returning typ)

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

  module Constraint_matrix = struct
    open F

    module T = struct
      type t = unit ptr

      let typ = ptr void
    end

    include T

    let prefix = with_prefix (prefix "constraint_matrix")

    let create = foreign (prefix "create") (void @-> returning typ)

    let append_row =
      foreign (prefix "append_row")
        (typ @-> Usize_vector.typ @-> Vector.typ @-> returning void)
  end
end

module Full (F : Ctypes.FOREIGN) = struct
  let prefix = with_prefix "camlsnark_bn382"

  module Bigint =
    Bigint (struct
        let prefix = prefix
      end)
      (F)

  module Usize_vector =
    Vector (struct
        let prefix = with_prefix (prefix "usize")
      end)
      (struct
        type t = Unsigned.size_t

        let typ = size_t
      end)
      (F)

  module Fp =
    Field (struct
        let prefix = with_prefix (prefix "fp")
      end)
      (Bigint)
      (Usize_vector)
      (F)

  module Fq =
    Field (struct
        let prefix = with_prefix (prefix "fq")
      end)
      (Bigint)
      (Usize_vector)
      (F)

  module G =
    Curve (struct
        let prefix = with_prefix (prefix "g")
      end)
      (Fp)
      (Fq)
      (F)

  module G1 =
    Curve (struct
        let prefix = with_prefix (prefix "g1")
      end)
      (Fq)
      (Fp)
      (F)

  module Fp_index =
    Index (struct
        let prefix = with_prefix (prefix "fp_index")
      end)
      (Fp.Constraint_matrix)
      (G1.Affine)
      (F)

  module Fp_proof =
    Marlin_proof (struct
        let prefix = with_prefix (prefix "fp_proof")
      end)
      (G1.Affine)
      (Fp)
      (Fp_index)
      (Fp.Vector)
      (F)
end
