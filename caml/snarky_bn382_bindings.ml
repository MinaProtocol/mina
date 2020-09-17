open Ctypes

let with_prefix = Format.sprintf "%s_%s"

module type Prefix = sig
  val prefix : string -> string
end

module type Type = sig
  type t

  val typ : t typ
end

module type Prefix_type = sig
  include Prefix include Type
end

module Pair (P : Prefix) (Elt : Type) (F : Ctypes.FOREIGN) = struct
  include (
    struct
        type t = unit ptr

        let typ = ptr void
      end :
      Type )

  open F

  let prefix = with_prefix (P.prefix "pair")

  let f i = foreign (prefix i) (typ @-> returning Elt.typ)

  let f0 = f "0"

  let f1 = f "1"
end

module Pair_with_make (P : Prefix) (Elt : Type) (F : Ctypes.FOREIGN) = struct
  open F
  include Pair (P) (Elt) (F)

  let make = foreign (prefix "make") (Elt.typ @-> Elt.typ @-> returning typ)
end

module Bigint (P : Prefix) (F : Ctypes.FOREIGN) = struct
  open F
  open P

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

module VerifierIndex
    (P : Prefix)
    (Index : Type)
    (Urs : Type)
    (PolyComm : Type)
    (F : Ctypes.FOREIGN) =
struct
  include (
    struct
        type t = unit ptr

        let typ = ptr void
      end :
      Type )

  open F

  let prefix = P.prefix

  let write = foreign (prefix "write") (typ @-> string @-> returning void)

  let delete = foreign (prefix "delete") (typ @-> returning void)

  let create = foreign (prefix "create") (Index.typ @-> returning typ)

  let urs = foreign (prefix "urs") (typ @-> returning Urs.typ)

  let make =
    foreign (prefix "make")
      ( size_t @-> size_t @-> size_t @-> size_t @-> size_t @-> Urs.typ
      @-> PolyComm.typ @-> PolyComm.typ @-> PolyComm.typ @-> PolyComm.typ
      @-> PolyComm.typ @-> PolyComm.typ @-> PolyComm.typ @-> PolyComm.typ
      @-> PolyComm.typ @-> PolyComm.typ @-> PolyComm.typ @-> PolyComm.typ
      @-> returning typ )

  let m_poly_comm m f =
    foreign
      (prefix (Format.sprintf "%s_%s_comm" m f))
      (typ @-> returning PolyComm.typ)

  let ( (a_row_comm, a_col_comm, a_val_comm, a_rc_comm)
      , (b_row_comm, b_col_comm, b_val_comm, b_rc_comm)
      , (c_row_comm, c_col_comm, c_val_comm, c_rc_comm) ) =
    let map3 (a, b, c) f = (f a, f b, f c) in
    let map4 (a, b, c, d) f = (f a, f b, f c, f d) in
    let polys = ("row", "col", "val", "rc") and mats = ("a", "b", "c") in
    map3 mats (fun m -> map4 polys (fun p -> m_poly_comm m p))
end

module PlonkVerifierIndex
    (P : Prefix)
    (Index : Type)
    (Urs : Type)
    (PolyComm : Type)
    (ScalarField : Type)
    (F : Ctypes.FOREIGN) =
struct
  include (
    struct
        type t = unit ptr

        let typ = ptr void
      end :
      Type )

  open F

  let prefix = P.prefix

  let create = foreign (prefix "create") (Index.typ @-> returning typ)

  let delete = foreign (prefix "delete") (typ @-> returning void)

  let urs = foreign (prefix "urs") (typ @-> returning Urs.typ)

  let make =
    foreign (prefix "make")
      ( size_t @-> size_t @-> Urs.typ @-> PolyComm.typ @-> PolyComm.typ
      @-> PolyComm.typ @-> PolyComm.typ @-> PolyComm.typ @-> PolyComm.typ
      @-> PolyComm.typ @-> PolyComm.typ @-> PolyComm.typ @-> PolyComm.typ
      @-> PolyComm.typ @-> PolyComm.typ @-> PolyComm.typ @-> PolyComm.typ
      @-> PolyComm.typ @-> PolyComm.typ @-> PolyComm.typ @-> PolyComm.typ
      @-> ScalarField.typ @-> ScalarField.typ @-> returning typ )

  let sigma_comm_0 =
    foreign (prefix "sigma_comm_0") (typ @-> returning PolyComm.typ)

  let sigma_comm_1 =
    foreign (prefix "sigma_comm_1") (typ @-> returning PolyComm.typ)

  let sigma_comm_2 =
    foreign (prefix "sigma_comm_2") (typ @-> returning PolyComm.typ)

  let ql_comm = foreign (prefix "ql_comm") (typ @-> returning PolyComm.typ)

  let qr_comm = foreign (prefix "qr_comm") (typ @-> returning PolyComm.typ)

  let qo_comm = foreign (prefix "qo_comm") (typ @-> returning PolyComm.typ)

  let qm_comm = foreign (prefix "qm_comm") (typ @-> returning PolyComm.typ)

  let rcm_comm_0 =
    foreign (prefix "rcm_comm_0") (typ @-> returning PolyComm.typ)

  let rcm_comm_1 =
    foreign (prefix "rcm_comm_1") (typ @-> returning PolyComm.typ)

  let rcm_comm_2 =
    foreign (prefix "rcm_comm_2") (typ @-> returning PolyComm.typ)

  let add_comm = foreign (prefix "add_comm") (typ @-> returning PolyComm.typ)

  let mul1_comm = foreign (prefix "mul1_comm") (typ @-> returning PolyComm.typ)

  let mul2_comm = foreign (prefix "mul2_comm") (typ @-> returning PolyComm.typ)

  let emul1_comm =
    foreign (prefix "emul1_comm") (typ @-> returning PolyComm.typ)

  let emul2_comm =
    foreign (prefix "emul2_comm") (typ @-> returning PolyComm.typ)

  let emul3_comm =
    foreign (prefix "emul3_comm") (typ @-> returning PolyComm.typ)

  let r = foreign (prefix "r") (typ @-> returning PolyComm.typ)

  let o = foreign (prefix "o") (typ @-> returning PolyComm.typ)
end

module URS
    (P : Prefix)
    (G1Affine : Type)
    (ScalarFieldVector : Type)
    (F : Ctypes.FOREIGN) =
struct
  include (
    struct
        type t = unit ptr

        let typ = ptr void
      end :
      Type )

  open P
  open F

  let create = foreign (prefix "create") (size_t @-> returning typ)

  let read = foreign (prefix "read") (string @-> returning typ)

  let write = foreign (prefix "write") (typ @-> string @-> returning void)

  let lagrange_commitment =
    foreign
      (prefix "lagrange_commitment")
      (typ @-> size_t @-> size_t @-> returning G1Affine.typ)

  let commit_evaluations =
    foreign
      (prefix "commit_evaluations")
      (typ @-> size_t @-> ScalarFieldVector.typ @-> returning G1Affine.typ)
end

module Index
    (P : Prefix)
    (Constraint_matrix : Type)
    (PlolyComm : Type)
    (URS : Type)
    (F : Ctypes.FOREIGN) =
struct
  open F

  include (
    struct
        type t = unit ptr

        let typ = ptr void
      end :
      Type )

  let prefix = P.prefix

  module M = Constraint_matrix

  let read =
    foreign (prefix "read")
      ( URS.typ @-> Constraint_matrix.typ @-> Constraint_matrix.typ
      @-> Constraint_matrix.typ @-> size_t @-> string @-> returning typ )

  let write = foreign (prefix "write") (typ @-> string @-> returning void)

  let delete = foreign (prefix "delete") (typ @-> returning void)

  let domain_h_size =
    foreign (prefix "domain_h_size") (typ @-> returning size_t)

  let domain_k_size =
    foreign (prefix "domain_k_size") (typ @-> returning size_t)

  let create =
    foreign (prefix "create")
      ( M.typ @-> M.typ @-> M.typ @-> size_t @-> size_t @-> URS.typ
      @-> returning typ )

  let metadata s = foreign (prefix s) (typ @-> returning size_t)

  let num_variables = metadata "num_variables"

  let public_inputs = metadata "public_inputs"

  let nonzero_entries = metadata "nonzero_entries"

  let max_degree = metadata "max_degree"
end

module Plonk_index
    (P : Prefix)
    (Constraint_system : Type)
    (PlolyComm : Type)
    (URS : Type)
    (F : Ctypes.FOREIGN) =
struct
  open F

  include (
    struct
        type t = unit ptr

        let typ = ptr void
      end :
      Type )

  let prefix = P.prefix

  let delete = foreign (prefix "delete") (typ @-> returning void)

  let domain_d1_size =
    foreign (prefix "domain_d1_size") (typ @-> returning size_t)

  let domain_d4_size =
    foreign (prefix "domain_d4_size") (typ @-> returning size_t)

  let domain_d8_size =
    foreign (prefix "domain_d8_size") (typ @-> returning size_t)

  let create =
    foreign (prefix "create")
      (Constraint_system.typ @-> size_t @-> URS.typ @-> returning typ)

  let metadata s = foreign (prefix s) (typ @-> returning size_t)

  let public_inputs = metadata "public_inputs"
end

module Vector (P : Prefix) (E : Type) (F : Ctypes.FOREIGN) = struct
  open F

  type elt = E.t

  let prefix = with_prefix (P.prefix "vector")

  include (
    struct
        type t = unit ptr

        let typ = ptr void
      end :
      Type )

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
    module Prefix = struct
      let prefix = with_prefix (prefix "affine")
    end

    open Prefix

    module Underlying : Type = struct
      type t = unit
      let typ = void
    end

    module T = struct
      type t = Underlying.t ptr

      let typ = ptr Underlying.typ
    end

    module Pair = struct
      module T = Pair_with_make (Prefix) (T) (F)
      include T

      module Vector =
        Vector (struct
            let prefix = T.prefix
          end)
          (T)
          (F)
    end

    include T

    let x = foreign (prefix "x") (typ @-> returning BaseField.typ)

    let y = foreign (prefix "y") (typ @-> returning BaseField.typ)

    let create =
      foreign (prefix "create")
        (BaseField.typ @-> BaseField.typ @-> returning typ)

    let delete = foreign (prefix "delete") (typ @-> returning void)

    let is_zero = foreign (prefix "is_zero") (typ @-> returning bool)

    module Vector =
      Vector (struct
          let prefix = prefix
        end)
        (T)
        (F)
  end

  let delete = foreign (prefix "delete") (typ @-> returning void)

  let to_affine_exn =
    foreign (prefix "to_affine") (typ @-> returning Affine.typ)

  let of_affine_coordinates =
    foreign
      (prefix "of_affine_coordinates")
      (BaseField.typ @-> BaseField.typ @-> returning typ)

  let add = foreign (prefix "add") (typ @-> typ @-> returning typ)

  let double = foreign (prefix "double") (typ @-> returning typ)

  let scale =
    foreign (prefix "scale") (typ @-> ScalarField.typ @-> returning typ)

  let sub = foreign (prefix "sub") (typ @-> typ @-> returning typ)

  let negate = foreign (prefix "negate") (typ @-> returning typ)

  let random = foreign (prefix "random") (void @-> returning typ)

  let one = foreign (prefix "one") (void @-> returning typ)
end

module Pairing_marlin_proof
    (P : Prefix)
    (AffineCurve : Type)
    (ScalarField : Type)
    (Index : Type)
    (VerifierIndex : Type)
    (ScalarFieldVector : Type)
    (F : Ctypes.FOREIGN) =
struct
  open F

  module T : Type = struct
    type t = unit ptr

    let typ = ptr void
  end

  include T
  module Vector = Vector (P) (T) (F)

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
      (Index.typ @-> ScalarFieldVector.typ @-> ScalarFieldVector.typ @-> returning typ)

  let verify =
    foreign (prefix "verify")
      (VerifierIndex.typ @-> typ @-> returning bool)

  let batch_verify =
    foreign (prefix "batch_verify")
      (VerifierIndex.typ @-> Vector.typ @-> returning bool)

  let make =
    foreign (prefix "make")
      ( ScalarFieldVector.typ @-> AffineCurve.typ @-> AffineCurve.typ
      @-> AffineCurve.typ @-> AffineCurve.typ @-> AffineCurve.typ
      @-> AffineCurve.typ @-> AffineCurve.typ @-> AffineCurve.typ
      @-> AffineCurve.typ @-> AffineCurve.typ @-> AffineCurve.typ
      @-> AffineCurve.typ @-> AffineCurve.typ @-> AffineCurve.typ
      @-> AffineCurve.typ @-> ScalarField.typ @-> ScalarField.typ
      @-> ScalarField.typ @-> ScalarField.typ @-> ScalarField.typ
      @-> ScalarField.typ @-> ScalarField.typ @-> ScalarField.typ
      @-> ScalarField.typ @-> ScalarField.typ @-> ScalarField.typ
      @-> ScalarField.typ @-> ScalarField.typ @-> ScalarField.typ
      @-> ScalarField.typ @-> ScalarField.typ @-> ScalarField.typ
      @-> ScalarField.typ @-> ScalarField.typ @-> ScalarField.typ
      @-> ScalarField.typ @-> ScalarField.typ @-> ScalarField.typ
      @-> returning typ )

  let delete = foreign (prefix "delete") (typ @-> returning void)

  let f name f_typ = foreign (prefix name) (typ @-> returning f_typ)

  let w_comm = f "w_comm" AffineCurve.typ

  let za_comm = f "za_comm" AffineCurve.typ

  let zb_comm = f "zb_comm" AffineCurve.typ

  let h1_comm = f "h1_comm" AffineCurve.typ

  let h2_comm = f "h2_comm" AffineCurve.typ

  let h3_comm = f "h3_comm" AffineCurve.typ

  module Commitment_with_degree_bound = struct
    include (
      struct
          type t = unit ptr

          let typ = ptr void
        end :
        Type )

    let prefix = with_prefix (P.prefix "commitment_with_degree_bound")

    let f i = foreign (prefix i) (typ @-> returning AffineCurve.typ)

    let f0 = f "0"

    let f1 = f "1"
  end

  let g1_comm_nocopy = f "g1_comm_nocopy" Commitment_with_degree_bound.typ

  let g2_comm_nocopy = f "g2_comm_nocopy" Commitment_with_degree_bound.typ

  let g3_comm_nocopy = f "g3_comm_nocopy" Commitment_with_degree_bound.typ

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

  let rc_evals_nocopy = f "rc_evals_nocopy" Evals.typ
end

module Triple (P : Prefix) (Elt : Type) (F : Ctypes.FOREIGN) = struct
  include (
    struct
        type t = unit ptr

        let typ = ptr void
      end :
      Type )

  open F

  let prefix = with_prefix (P.prefix "triple")

  let f i = foreign (prefix i) (typ @-> returning Elt.typ)

  let f0 = f "0"

  let f1 = f "1"

  let f2 = f "2"
end

module Dlog_poly_comm
    (P : Prefix)
    (AffineCurve : sig
        module Underlying : Type
        include Type with type t = Underlying.t ptr
        module Vector : Type
    end)
    (F : Ctypes.FOREIGN) =
struct
  include (
    struct
        type t = unit ptr

        let typ = ptr void
      end :
      Type )

  let prefix = P.prefix

  open F

  let unshifted = foreign (prefix "unshifted") (typ @-> returning AffineCurve.Vector.typ)

  let shifted : (t -> AffineCurve.t option return) result =
    foreign (prefix "shifted") (typ @-> returning (ptr_opt AffineCurve.Underlying.typ))

  let make : (AffineCurve.Vector.t -> AffineCurve.t option -> t return) result =
    foreign (prefix "make")
      ( AffineCurve.Vector.typ @-> ptr_opt AffineCurve.Underlying.typ
      @-> returning typ )

  let delete = foreign (prefix "delete") (typ @-> returning void)
end

module Dlog_opening_proof
    (P : Prefix)
    (ScalarField : Type) (AffineCurve : sig
        include Type

        module Pair : sig
          module Vector : Type
        end
    end)
    (F : Ctypes.FOREIGN) =
struct
  include (
    struct
        type t = unit ptr

        let typ = ptr void
      end :
      Type )

  let prefix = P.prefix

  open F

  let delete = foreign (prefix "delete") (typ @-> returning void)

  let lr = foreign (prefix "lr") (typ @-> returning AffineCurve.Pair.Vector.typ)

  let z1 = foreign (prefix "z1") (typ @-> returning ScalarField.typ)

  let z2 = foreign (prefix "z2") (typ @-> returning ScalarField.typ)

  let delta = foreign (prefix "delta") (typ @-> returning AffineCurve.typ)

  let sg = foreign (prefix "sg") (typ @-> returning AffineCurve.typ)
end

module Dlog_marlin_proof
    (P : Prefix) (AffineCurve : sig
        include Type

        module Vector : Type

        module Pair : sig
          include Type

          module Vector : Type
        end
    end)
    (ScalarField : Type)
    (Index : Type)
    (VerifierIndex : Type)
    (ScalarFieldVector : Type)
    (FieldVectorTriple : Type)
    (OpeningProof : Type)
    (PolyComm : Type)
    (F : Ctypes.FOREIGN) =
struct
  open F

  module T : Type = struct
    type t = unit ptr

    let typ = ptr void
  end

  include T
  module Vector = Vector (P) (T) (F)

  module Evaluations = struct
    module T : Type = struct
      type t = unit ptr

      let typ = ptr void
    end

    include T

    let prefix = with_prefix (P.prefix "evaluations")

    let f s = foreign (prefix s) (typ @-> returning ScalarFieldVector.typ)

    let w = f "w"

    let za = f "za"

    let zb = f "zb"

    let h1 = f "h1"

    let g1 = f "g1"

    let h2 = f "h2"

    let g2 = f "g2"

    let h3 = f "h3"

    let g3 = f "g3"

    let evals s = foreign (prefix s) (typ @-> returning FieldVectorTriple.typ)

    let row_nocopy = evals "row_nocopy"

    let col_nocopy = evals "col_nocopy"

    let val_nocopy = evals "val_nocopy"

    let rc_nocopy = evals "rc_nocopy"

    module Triple =
      Triple (struct
          let prefix = prefix
        end)
        (T)
        (F)

    let make =
      foreign (prefix "make")
        ( ScalarFieldVector.typ @-> ScalarFieldVector.typ @-> ScalarFieldVector.typ
        @-> ScalarFieldVector.typ @-> ScalarFieldVector.typ @-> ScalarFieldVector.typ
        @-> ScalarFieldVector.typ @-> ScalarFieldVector.typ @-> ScalarFieldVector.typ
        @-> ScalarFieldVector.typ @-> ScalarFieldVector.typ @-> ScalarFieldVector.typ
        @-> ScalarFieldVector.typ @-> ScalarFieldVector.typ @-> ScalarFieldVector.typ
        @-> ScalarFieldVector.typ @-> ScalarFieldVector.typ @-> ScalarFieldVector.typ
        @-> ScalarFieldVector.typ @-> ScalarFieldVector.typ @-> ScalarFieldVector.typ
        @-> returning typ )
  end

  let prefix = P.prefix

  let make =
    foreign (prefix "make")
      ( ScalarFieldVector.typ @-> PolyComm.typ @-> PolyComm.typ
      @-> PolyComm.typ @-> PolyComm.typ @-> PolyComm.typ
      @-> PolyComm.typ @-> PolyComm.typ @-> PolyComm.typ
      @-> PolyComm.typ @-> ScalarField.typ @-> ScalarField.typ
      @-> AffineCurve.Pair.Vector.typ @-> ScalarField.typ @-> ScalarField.typ
      @-> AffineCurve.typ @-> AffineCurve.typ @-> Evaluations.typ
      @-> Evaluations.typ @-> Evaluations.typ @-> ScalarFieldVector.typ
      @-> AffineCurve.Vector.typ @-> returning typ )

  let create =
    foreign (prefix "create")
      ( Index.typ @-> ScalarFieldVector.typ @-> ScalarFieldVector.typ
      @-> ScalarFieldVector.typ @-> AffineCurve.Vector.typ @-> returning typ )

  let verify =
    foreign (prefix "verify")
      (VerifierIndex.typ @-> typ @-> returning bool)

  let batch_verify =
    foreign (prefix "batch_verify")
      (VerifierIndex.typ @-> Vector.typ @-> returning bool)

  let delete = foreign (prefix "delete") (typ @-> returning void)

  let f name f_typ = foreign (prefix name) (typ @-> returning f_typ)

  let w_comm = f "w_comm" PolyComm.typ

  let za_comm = f "za_comm" PolyComm.typ

  let zb_comm = f "zb_comm" PolyComm.typ

  let h1_comm = f "h1_comm" PolyComm.typ

  let h2_comm = f "h2_comm" PolyComm.typ

  let h3_comm = f "h3_comm" PolyComm.typ

  let g1_comm_nocopy = f "g1_comm_nocopy" PolyComm.typ

  let g2_comm_nocopy = f "g2_comm_nocopy" PolyComm.typ

  let g3_comm_nocopy = f "g3_comm_nocopy" PolyComm.typ

  let evals_nocopy = f "evals_nocopy" Evaluations.Triple.typ

  let proof = f "proof" OpeningProof.typ

  let sigma2 = f "sigma2" ScalarField.typ

  let sigma3 = f "sigma3" ScalarField.typ
end

module Dlog_plonk_proof
    (P : Prefix) (AffineCurve : sig
        include Type

        module Vector : Type

        module Pair : sig
          include Type

          module Vector : Type
        end
    end)
    (ScalarField : Type)
    (Index : Type)
    (VerifierIndex : Type)
    (ScalarFieldVector : Type)
    (FieldVectorPair : Type)
    (OpeningProof : Type)
    (PolyComm : Type)
    (F : Ctypes.FOREIGN) =
struct
  open F

  module T : Type = struct
    type t = unit ptr

    let typ = ptr void
  end

  include T
  module Vector = Vector (P) (T) (F)

  module Evaluations = struct
    module T : Type = struct
      type t = unit ptr

      let typ = ptr void
    end

    include T

    let prefix = with_prefix (P.prefix "evaluations")

    let f s = foreign (prefix s) (typ @-> returning ScalarField.typ)

    let l = f "l"

    let r = f "r"

    let o = f "o"

    let z = f "z"

    let t = f "t"

    let f = f "f"

    let sigma1 = f "sigma1"

    let sigma2 = f "sigma2"

    module Pair =
      Pair (struct
          let prefix = prefix
        end)
        (T)
        (F)

    let make =
      foreign (prefix "make")
        ( ScalarField.typ @-> ScalarField.typ @-> ScalarField.typ
        @-> ScalarField.typ @-> ScalarField.typ @-> ScalarField.typ
        @-> ScalarField.typ @-> ScalarField.typ @-> returning typ )
  end

  let prefix = P.prefix

  let make =
    foreign (prefix "make")
      ( ScalarFieldVector.typ @-> PolyComm.typ @-> PolyComm.typ @-> PolyComm.typ
      @-> PolyComm.typ @-> PolyComm.typ @-> AffineCurve.Pair.Vector.typ
      @-> PolyComm.typ @-> PolyComm.typ @-> AffineCurve.typ @-> AffineCurve.typ
      @-> Evaluations.typ @-> Evaluations.typ @-> returning typ )

  let create =
    foreign (prefix "create")
      ( Index.typ @-> ScalarFieldVector.typ @-> ScalarFieldVector.typ
      @-> returning typ )

  let verify =
    foreign (prefix "verify") (VerifierIndex.typ @-> typ @-> returning bool)

  let batch_verify =
    foreign (prefix "batch_verify")
      (VerifierIndex.typ @-> Vector.typ @-> returning bool)

  let delete = foreign (prefix "delete") (typ @-> returning void)

  let f name f_typ = foreign (prefix name) (typ @-> returning f_typ)

  let l_comm = f "l_comm" PolyComm.typ

  let r_comm = f "r_comm" PolyComm.typ

  let o_comm = f "o_comm" PolyComm.typ

  let z_comm = f "z_comm" PolyComm.typ

  let t_comm = f "t_comm" PolyComm.typ

  let proof_comm = f "proof" OpeningProof.typ
end

module Pairing_oracles
    (P : Prefix)
    (Field : Type)
    (VerifierIndex : Type)
    (Proof : Type)
    (F : Ctypes.FOREIGN) =
struct
  include (
    struct
        type t = unit ptr

        let typ = ptr void
      end :
      Type )

  open F

  let prefix = P.prefix

  let delete = foreign (prefix "delete") (typ @-> returning void)

  let create =
    foreign (prefix "create")
      (VerifierIndex.typ @-> Proof.typ @-> returning typ)

  let element name = foreign (prefix name) (typ @-> returning Field.typ)

  let alpha = element "alpha"

  let eta_a = element "eta_a"

  let eta_b = element "eta_b"

  let eta_c = element "eta_c"

  let beta1 = element "beta1"

  let beta2 = element "beta2"

  let beta3 = element "beta3"

  let r_k = element "r_k"

  let batch = element "batch"

  let r = element "r"

  let x_hat_beta1 = element "x_hat_beta1"

  let digest_before_evaluations = element "digest_before_evaluations"
end

module Dlog_oracles
    (P : Prefix) (Field : sig
        include Type

        module Vector : Type
    end)
    (VerifierIndex : Type)
    (Proof : Type)
    (FieldVectorTriple : Type)
    (F : Ctypes.FOREIGN) =
struct
  include (
    struct
        type t = unit ptr

        let typ = ptr void
      end :
      Type )

  open F

  let prefix = P.prefix

  let delete = foreign (prefix "delete") (typ @-> returning void)

  let create =
    foreign (prefix "create")
      (VerifierIndex.typ @-> Proof.typ @-> returning typ)

  let element name = foreign (prefix name) (typ @-> returning Field.typ)

  let opening_prechallenges =
    foreign
      (prefix "opening_prechallenges")
      (typ @-> returning Field.Vector.typ)

  let alpha = element "alpha"

  let eta_a = element "eta_a"

  let eta_b = element "eta_b"

  let eta_c = element "eta_c"

  let beta1 = element "beta1"

  let beta2 = element "beta2"

  let beta3 = element "beta3"

  let polys = element "polys"

  let evals = element "evals"

  let x_hat_nocopy =
    foreign (prefix "x_hat_nocopy") (typ @-> returning FieldVectorTriple.typ)

  let digest_before_evaluations = element "digest_before_evaluations"
end

module Dlog_plonk_oracles
    (P : Prefix) (Field : sig
        include Type

        module Vector : Type
    end)
    (VerifierIndex : Type)
    (Proof : Type)
    (FieldVectorTriple : Type)
    (F : Ctypes.FOREIGN) =
struct
  include (
    struct
        type t = unit ptr

        let typ = ptr void
      end :
      Type )

  open F

  let prefix = P.prefix

  let delete = foreign (prefix "delete") (typ @-> returning void)

  let create =
    foreign (prefix "create")
      (VerifierIndex.typ @-> Proof.typ @-> returning typ)

  let element name = foreign (prefix name) (typ @-> returning Field.typ)

  let opening_prechallenges =
    foreign
      (prefix "opening_prechallenges")
      (typ @-> returning Field.Vector.typ)

  let alpha = element "alpha"

  let beta = element "beta"

  let gamma = element "gamma"

  let zeta = element "zeta"

  let v = element "v"

  let u = element "u"

  let p_eval_1 = element "p_eval1"

  let p_eval_2 = element "p_eval2"
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

  let mut_square = foreign (prefix "mut_square") (typ @-> returning void)

  let mut_sub = foreign (prefix "mut_sub") (typ @-> typ @-> returning void)

  let copy = foreign (prefix "copy") (typ @-> typ @-> returning void)

  let rng = foreign (prefix "rng") (int @-> returning typ)

  let delete = foreign (prefix "delete") (typ @-> returning void)

  let print = foreign (prefix "print") (typ @-> returning void)

  let equal = foreign (prefix "equal") (typ @-> typ @-> returning bool)

  let to_bigint = foreign (prefix "to_bigint") (typ @-> returning Bigint.typ)

  let of_bigint = foreign (prefix "of_bigint") (Bigint.typ @-> returning typ)

  let to_bigint_raw =
    foreign (prefix "to_bigint_raw") (typ @-> returning Bigint.typ)

  let to_bigint_raw_noalloc =
    foreign (prefix "to_bigint_raw_noalloc") (typ @-> returning Bigint.typ)

  let of_bigint_raw =
    foreign (prefix "of_bigint_raw") (Bigint.typ @-> returning typ)

  module Vector =
    Vector (struct
        let prefix = prefix
      end)
      (T)
      (F)

  module Constraint_matrix = struct
    open F

    module T : Type = struct
      type t = unit ptr

      let typ = ptr void
    end

    include T

    let prefix = with_prefix (prefix "constraint_matrix")

    let create = foreign (prefix "create") (void @-> returning typ)

    let delete = foreign (prefix "delete") (typ @-> returning void)

    let append_row =
      foreign (prefix "append_row")
        (typ @-> Usize_vector.typ @-> Vector.typ @-> returning void)
  end
end

module Plonk_gate_vector
    (P : Prefix)
    (Field_vector : Type)
    (F : Ctypes.FOREIGN) =
struct
  open F

  include (
    struct
        type t = unit ptr

        let typ = ptr void
      end :
      Type )

  let prefix = with_prefix (P.prefix "circuit_gate_vector")

  let create = foreign (prefix "create") (void @-> returning typ)

  let delete = foreign (prefix "delete") (typ @-> returning void)

  let length = foreign (prefix "length") (typ @-> returning int)

  let push_gate gate_name =
    foreign
      (prefix (Printf.sprintf "push_%s" gate_name))
      ( typ @-> size_t (* l_index *) @-> size_t (* l_permutation *)
      @-> size_t (* r_index *) @-> size_t (* r_permutation *)
      @-> size_t (* o_index *) @-> size_t (* o_permutation *)
      @-> Field_vector.typ (* constraints vector *) @-> returning void )

  let push_zero = push_gate "zero"

  let push_generic = push_gate "generic"

  let push_poseidon = push_gate "poseidon"

  let push_add1 = push_gate "add1"

  let push_add2 = push_gate "add2"

  let push_vbmul1 = push_gate "vbmul1"

  let push_vbmul2 = push_gate "vbmul2"

  let push_vbmul3 = push_gate "vbmul3"

  let push_endomul1 = push_gate "endomul1"

  let push_endomul2 = push_gate "endomul2"

  let push_endomul3 = push_gate "endomul3"

  let push_endomul4 = push_gate "endomul4"
end

module Plonk_constraint_system
    (P : Prefix)
    (Plonk_gate_vector : Type)
    (F : Ctypes.FOREIGN) =
struct
  open F

  include (
    struct
        type t = unit ptr

        let typ = ptr void
      end :
      Type )

  let prefix = with_prefix (P.prefix "constraint_system")

  let create =
    foreign (prefix "create")
      (Plonk_gate_vector.typ @-> size_t @-> returning typ)

  let delete = foreign (prefix "delete") (typ @-> returning void)
end

module Full (F : Ctypes.FOREIGN) = struct
  let zexe = with_prefix "zexe"

  module Bigint256 =
    Bigint (struct
        let prefix = with_prefix (zexe "bigint256")
      end)
      (F)

  module Bigint384 =
    Bigint (struct
        let prefix = with_prefix (zexe "bigint384")
      end)
      (F)

  module Usize_vector =
    Vector (struct
        let prefix = with_prefix (zexe "usize")
      end)
      (struct
        type t = Unsigned.size_t

        let typ = size_t
      end)
      (F)

  module Dlog_proof_system
      (Field: sig
         include Prefix_type
         module Vector:Prefix_type
         module Constraint_matrix:Type
       end)
      (Curve: sig
         include Prefix_type
         module Affine: sig
            module Underlying : Type
            include Type with type t = Underlying.t ptr
            module Vector: Type
           module Pair : sig
             include Type
             module Vector: Type
           end
          end
       end)
  = struct
    let prefix = Field.prefix 

    module Field_triple = Triple (Field) (Field) (F)

    module Field_vector_triple = Triple (Field.Vector) (Field.Vector) (F)

    module Field_opening_proof =
      Dlog_opening_proof (struct
          let prefix = with_prefix (prefix "opening_proof")
        end)
        (Field)
        (Curve.Affine)
        (F)

    module Field_poly_comm =
      Dlog_poly_comm (struct
          let prefix = with_prefix (prefix "poly_comm")
        end)
        (Curve.Affine)
        (F)

    module Field_urs = struct

      let prefix = with_prefix (prefix "urs")

      include (
        struct
            type t = unit ptr

            let typ = ptr void
          end :
          Type )

      open F

      let create =
        foreign (prefix "create")
          (size_t @-> size_t @-> size_t @-> returning typ)

      let read = foreign (prefix "read") (string @-> returning typ)

      let write = foreign (prefix "write") (typ @-> string @-> returning void)

      let lagrange_commitment =
        foreign
          (prefix "lagrange_commitment")
          (typ @-> size_t @-> size_t @-> returning Field_poly_comm.typ)

      let commit_evaluations =
        foreign
          (prefix "commit_evaluations")
          (typ @-> size_t @-> Field.Vector.typ @-> returning Field_poly_comm.typ)

      let h = foreign (prefix "h") (typ @-> returning Curve.Affine.typ)

      let b_poly_commitment =
        foreign
          (prefix "b_poly_commitment")
          (typ @-> Field.Vector.typ @-> returning Field_poly_comm.typ)
    end

    module Field_index =
      Index (struct
          let prefix = with_prefix (prefix "index")
        end)
        (Field.Constraint_matrix)
        (Field_poly_comm)
        (Field_urs)
        (F)

    module Field_verifier_index = struct
      include VerifierIndex (struct
          let prefix = with_prefix (prefix "verifier_index")
        end)
        (Field_index)
        (Field_urs)
        (Field_poly_comm)
        (F)

      open F

      let read = foreign (prefix "read") (Field_urs.typ @-> string @-> returning typ)
    end

    module Field_proof =
      Dlog_marlin_proof (struct
          let prefix = with_prefix (prefix "proof")
        end)
        (Curve.Affine)
        (Field)
        (Field_index)
        (Field_verifier_index)
        (Field.Vector)
        (Field_vector_triple)
        (Field_opening_proof)
        (Field_poly_comm)
        (F)

    module Field_oracles =
      Dlog_oracles (struct
          let prefix = with_prefix (prefix "oracles")
        end)
        (Field)
        (Field_verifier_index)
        (Field_proof)
        (Field_vector_triple)
        (F)
  end

  module Plonk_dlog_proof_system
      (P : Prefix) (Field : sig
          include Prefix_type

          module Vector : sig
            include Prefix_type

            module Triple : Type
          end
      end) (Curve : sig
        include Prefix_type

        module Affine : sig
          module Underlying : Type

          include Type with type t = Underlying.t ptr

          module Vector : Type

          module Pair : sig
            include Type

            module Vector : Type
          end
        end
      end) =
  struct
    let prefix = Field.prefix

    module Field_triple = Triple (Field) (Field) (F)

    module Field_opening_proof =
      Dlog_opening_proof (struct
          let prefix = with_prefix (P.prefix "opening_proof")
        end)
        (Field)
        (Curve.Affine)
        (F)

    module Field_poly_comm =
      Dlog_poly_comm (struct
          let prefix = with_prefix (prefix "poly_comm")
        end)
        (Curve.Affine)
        (F)

    module Field_urs = struct
      let prefix = with_prefix (prefix "urs")

      include (
        struct
            type t = unit ptr

            let typ = ptr void
          end :
          Type )

      open F

      let create =
        foreign (prefix "create")
          (size_t @-> size_t @-> size_t @-> returning typ)

      let read = foreign (prefix "read") (string @-> returning typ)

      let write = foreign (prefix "write") (typ @-> string @-> returning void)

      let lagrange_commitment =
        foreign
          (prefix "lagrange_commitment")
          (typ @-> size_t @-> size_t @-> returning Field_poly_comm.typ)

      let commit_evaluations =
        foreign
          (prefix "commit_evaluations")
          ( typ @-> size_t @-> Field.Vector.typ
          @-> returning Field_poly_comm.typ )

      let h = foreign (prefix "h") (typ @-> returning Curve.Affine.typ)

      let batch_accumulator_check =
        foreign
          (prefix "batch_accumulator_check")
          ( typ @-> Curve.Affine.Vector.typ @-> Field.Vector.typ
          @-> returning bool )

      let b_poly_commitment =
        foreign
          (prefix "b_poly_commitment")
          (typ @-> Field.Vector.typ @-> returning Field_poly_comm.typ)
    end

    module Gate_vector = Plonk_gate_vector (P) (Field.Vector) (F)
    module Constraint_system = Plonk_constraint_system (P) (Gate_vector) (F)

    module Field_index =
      Plonk_index (struct
          let prefix = with_prefix (P.prefix "index")
        end)
        (Constraint_system)
        (Field_poly_comm)
        (Field_urs)
        (F)

    module Field_verifier_index =
      PlonkVerifierIndex (struct
          let prefix = with_prefix (P.prefix "verifier_index")
        end)
        (Field_index)
        (Field_urs)
        (Field_poly_comm)
        (Field)
        (F)

    module Field_proof =
      Dlog_plonk_proof (struct
          let prefix = with_prefix (P.prefix "proof")
        end)
        (Curve.Affine)
        (Field)
        (Field_index)
        (Field_verifier_index)
        (Field.Vector)
        (Field.Vector.Triple)
        (Field_opening_proof)
        (Field_poly_comm)
        (F)

    module Field_oracles =
      Dlog_oracles (struct
          let prefix = with_prefix (prefix "oracles")
        end)
        (Field)
        (Field_verifier_index)
        (Field_proof)
        (Field.Vector.Triple)
        (F)
  end

  module Tweedle = struct
    let prefix = with_prefix (zexe "tweedle")

    module Fp =
      Field (struct
          let prefix = with_prefix (prefix "fp")
        end)
        (Bigint256)
        (Usize_vector)
        (F)

    module Fq =
      Field (struct
          let prefix = with_prefix (prefix "fq")
        end)
        (Bigint256)
        (Usize_vector)
        (F)

    module Dum = struct
      module Field = Fq

      module Curve = Curve (struct
          let prefix = with_prefix (prefix "dum")
        end)
        (Fp)
        (Fq)
        (F)

      module Plonk =
        Plonk_dlog_proof_system (struct
            let prefix = with_prefix (prefix "plonk_fq")
          end)
          (Field)
          (Curve)

      include Dlog_proof_system (Field) (Curve)
    end

    module Dee = struct
      module Field = Fp

      module Curve =
        Curve (struct
            let prefix = with_prefix (prefix "dee")
          end)
          (Fq)
          (Fp)
          (F)

      module Plonk =
        Plonk_dlog_proof_system (struct
            let prefix = with_prefix (prefix "plonk_fp")
          end)
          (Field)
          (Curve)

      include Dlog_proof_system (Field) (Curve)
    end

    module Endo = struct
      let endo typ which =
        let open F in
        F.foreign (prefix which) (void @-> returning typ)

      module Dee = struct
        let base = endo Fq.typ "fp_endo_base"
        let scalar = endo Fp.typ "fp_endo_scalar"
      end

      module Dum = struct
        let base = endo Fp.typ "fq_endo_base"
        let scalar = endo Fq.typ "fq_endo_scalar"
      end
    end
  end

  module Bn382 = struct
    let prefix = with_prefix (zexe "bn382")

    module Fp =
      Field (struct
          let prefix = with_prefix (prefix "fp")
        end)
        (Bigint384)
        (Usize_vector)
        (F)

    module Fq =
      Field (struct
          let prefix = with_prefix (prefix "fq")
        end)
        (Bigint384)
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

    module Fp_urs = struct
      let prefix = with_prefix (prefix "fp_urs")

      include URS (struct
                  let prefix = prefix
                end)
                (G1.Affine)
                (Fp.Vector)
                (F)

      open F

      let dummy_opening_check =
        foreign
          (prefix "dummy_opening_check")
          (typ @-> returning G1.Affine.Pair.typ)

      let dummy_degree_bound_checks =
        foreign
          (prefix "dummy_degree_bound_checks")
          (typ @-> Usize_vector.typ @-> returning G1.Affine.Vector.typ)
    end

    module Fp_index =
      Index (struct
          let prefix = with_prefix (prefix "fp_index")
        end)
        (Fp.Constraint_matrix)
        (G1.Affine)
        (Fp_urs)
        (F)

    module Fp_verifier_index = struct
      include VerifierIndex (struct
          let prefix = with_prefix (prefix "fp_verifier_index")
        end)
        (Fp_index)
        (Fp_urs)
        (G1.Affine)
        (F)

      open F

      let read = foreign (prefix "read") (string @-> returning typ)
    end

    module Fp_proof =
      Pairing_marlin_proof (struct
          let prefix = with_prefix (prefix "fp_proof")
        end)
        (G1.Affine)
        (Fp)
        (Fp_index)
        (Fp_verifier_index)
        (Fp.Vector)
        (F)

    module Fp_oracles =
      Pairing_oracles (struct
          let prefix = with_prefix (prefix "fp_oracles")
        end)
        (Fp)
        (Fp_verifier_index)
        (Fp_proof)
        (F)

    module Fq_triple = Triple (Fq) (Fq) (F)

    module Fq_vector_triple = Triple (Fq.Vector) (Fq.Vector) (F)

    module Fq_opening_proof =
      Dlog_opening_proof (struct
          let prefix = with_prefix (prefix "fq_opening_proof")
        end)
        (Fq)
        (G.Affine)
        (F)

    module Fq_poly_comm =
      Dlog_poly_comm (struct
          let prefix = with_prefix (prefix "fq_poly_comm")
        end)
        (G.Affine)
        (F)

    module Fq_urs = struct

      let prefix = with_prefix (prefix "fq_urs")

      include (
        struct
            type t = unit ptr

            let typ = ptr void
          end :
          Type )

      open F

      let create =
        foreign (prefix "create")
          (size_t @-> size_t @-> size_t @-> returning typ)

      let read = foreign (prefix "read") (string @-> returning typ)

      let write = foreign (prefix "write") (typ @-> string @-> returning void)

      let lagrange_commitment =
        foreign
          (prefix "lagrange_commitment")
          (typ @-> size_t @-> size_t @-> returning Fq_poly_comm.typ)

      let commit_evaluations =
        foreign
          (prefix "commit_evaluations")
          (typ @-> size_t @-> Fq.Vector.typ @-> returning Fq_poly_comm.typ)

      let h = foreign (prefix "h") (typ @-> returning G.Affine.typ)

      let b_poly_commitment =
        foreign
          (prefix "b_poly_commitment")
          (typ @-> Fq.Vector.typ @-> returning Fq_poly_comm.typ)
    end

    module Fq_index =
      Index (struct
          let prefix = with_prefix (prefix "fq_index")
        end)
        (Fq.Constraint_matrix)
        (Fq_poly_comm)
        (Fq_urs)
        (F)

    module Fq_verifier_index = struct
      include VerifierIndex (struct
          let prefix = with_prefix (prefix "fq_verifier_index")
        end)
        (Fq_index)
        (Fq_urs)
        (Fq_poly_comm)
        (F)

      open F

      let read = foreign (prefix "read") (Fq_urs.typ @-> string @-> returning typ)
    end

    module Fq_proof =
      Dlog_marlin_proof (struct
          let prefix = with_prefix (prefix "fq_proof")
        end)
        (G.Affine)
        (Fq)
        (Fq_index)
        (Fq_verifier_index)
        (Fq.Vector)
        (Fq_vector_triple)
        (Fq_opening_proof)
        (Fq_poly_comm)
        (F)

    module Fq_oracles =
      Dlog_oracles (struct
          let prefix = with_prefix (prefix "fq_oracles")
        end)
        (Fq)
        (Fq_verifier_index)
        (Fq_proof)
        (Fq_vector_triple)
        (F)

    module Endo = struct
      let endo typ which =
        let open F in
        F.foreign (prefix which) (void @-> returning typ)

      module Pairing = struct
        let base = endo Fq.typ "fp_endo_base"
        let scalar = endo Fp.typ "fp_endo_scalar"
      end

      module Dlog = struct
        let base = endo Fp.typ "fq_endo_base"
        let scalar = endo Fq.typ "fq_endo_scalar"
      end
    end

    let batch_pairing_check =
      let open F in
      foreign
        (prefix "batch_pairing_check")
        ( Fp_urs.typ @-> Usize_vector.typ @-> G1.Affine.Vector.typ
        @-> G1.Affine.Vector.typ @-> G1.Affine.Vector.typ
        @-> G1.Affine.Vector.typ @-> returning bool )
  end
  include Bn382
end
