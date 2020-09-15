open Core_kernel
open Ctypes

let with_prefix = Format.sprintf "%s_%s"

module type Prefix = sig
  val prefix : string -> string
end

module type Type = sig
  type t

  val typ : t typ
end

module type Type_with_finalizer = sig
  include Type

  type 'a result

  type 'a return

  val add_finalizer : (t return -> t return) result
end

module type Prefix_type = sig
  include Prefix

  include Type
end

module type Prefix_type_with_finalizer = sig
  include Prefix

  include Type_with_finalizer
end

module Pair
    (F : Cstubs_applicative.Foreign_applicative)
    (P : Prefix)
    (Elt : Type_with_finalizer
           with type 'a result := 'a F.result
            and type 'a return := 'a F.return) =
struct
  include (
    struct
        type t = unit ptr

        let typ = ptr void
      end :
      Type )

  open F
  open F.Let_syntax

  let prefix = with_prefix (P.prefix "pair")

  let delete = foreign (prefix "delete") (typ @-> returning void)

  let add_finalizer =
    F.map delete ~f:(fun delete x ->
        Caml.Gc.finalise (bind_return ~f:delete) x ;
        x )

  (* Stub out delete to make sure we don't attempt to double-free. *)
  let delete : t -> unit = ignore

  let f i =
    let%map f = foreign (prefix i) (typ @-> returning Elt.typ)
    and add_finalizer = Elt.add_finalizer in
    fun x -> add_finalizer (f x)

  let f0 = f "0"

  let f1 = f "1"
end

module Pair_with_make
    (F : Cstubs_applicative.Foreign_applicative)
    (P : Prefix)
    (Elt : Type_with_finalizer
           with type 'a result := 'a F.result
            and type 'a return := 'a F.return) =
struct
  open F
  open F.Let_syntax
  include Pair (F) (P) (Elt)

  let make =
    let%map make =
      foreign (prefix "make") (Elt.typ @-> Elt.typ @-> returning typ)
    and add_finalizer = add_finalizer in
    fun x y -> add_finalizer (make x y)
end

module Bigint (F : Cstubs_applicative.Foreign_applicative) (P : Prefix) =
struct
  open F
  open F.Let_syntax
  open P

  include (
    struct
        type t = unit ptr

        let typ = ptr void
      end :
      Type )

  let delete = foreign (prefix "delete") (typ @-> returning void)

  let add_finalizer =
    F.map delete ~f:(fun delete x ->
        Caml.Gc.finalise (bind_return ~f:delete) x ;
        x )

  (* Stub out delete to make sure we don't attempt to double-free. *)
  let delete : t -> unit = ignore

  let of_decimal_string =
    let%map of_decimal_string =
      foreign (prefix "of_decimal_string") (string @-> returning typ)
    and add_finalizer = add_finalizer in
    fun s -> add_finalizer (of_decimal_string s)

  let num_limbs = foreign (prefix "num_limbs") (void @-> returning int)

  let to_data = foreign (prefix "to_data") (typ @-> returning (ptr char))

  let of_data =
    let%map of_data = foreign (prefix "of_data") (ptr char @-> returning typ)
    and add_finalizer = add_finalizer in
    fun s -> add_finalizer (of_data s)

  let bytes_per_limb =
    foreign (prefix "bytes_per_limb") (void @-> returning int)

  let div =
    let%map div = foreign (prefix "div") (typ @-> typ @-> returning typ)
    and add_finalizer = add_finalizer in
    fun x y -> add_finalizer (div x y)

  let of_numeral =
    let%map of_numeral =
      foreign (prefix "of_numeral") (string @-> int @-> int @-> returning typ)
    and add_finalizer = add_finalizer in
    fun s i j -> add_finalizer (of_numeral s i j)

  let compare = foreign (prefix "compare") (typ @-> typ @-> returning uint8_t)

  let test_bit = foreign (prefix "test_bit") (typ @-> int @-> returning bool)

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
    (F : Cstubs_applicative.Foreign_applicative)
    (P : Prefix)
    (Index : Type)
    (Urs : Type_with_finalizer
           with type 'a result := 'a F.result
            and type 'a return := 'a F.return)
    (PolyComm : Type_with_finalizer
                with type 'a result := 'a F.result
                 and type 'a return := 'a F.return) =
struct
  include (
    struct
        type t = unit ptr

        let typ = ptr void
      end :
      Type )

  open F
  open F.Let_syntax

  let prefix = P.prefix

  let write = foreign (prefix "write") (typ @-> string @-> returning void)

  let delete = foreign (prefix "delete") (typ @-> returning void)

  let add_finalizer =
    F.map delete ~f:(fun delete x ->
        Caml.Gc.finalise (bind_return ~f:delete) x ;
        x )

  (* Stub out delete to make sure we don't attempt to double-free. *)
  let delete : t -> unit = ignore

  let create =
    let%map create = foreign (prefix "create") (Index.typ @-> returning typ)
    and add_finalizer = add_finalizer in
    fun i -> add_finalizer (create i)

  let urs =
    let%map urs = foreign (prefix "urs") (typ @-> returning Urs.typ)
    and add_finalizer = Urs.add_finalizer in
    fun i -> add_finalizer (urs i)

  let make =
    let%map make =
      foreign (prefix "make")
        ( size_t @-> size_t @-> size_t @-> size_t @-> size_t @-> Urs.typ
        @-> PolyComm.typ @-> PolyComm.typ @-> PolyComm.typ @-> PolyComm.typ
        @-> PolyComm.typ @-> PolyComm.typ @-> PolyComm.typ @-> PolyComm.typ
        @-> PolyComm.typ @-> PolyComm.typ @-> PolyComm.typ @-> PolyComm.typ
        @-> returning typ )
    and add_finalizer = add_finalizer in
    fun ~public_inputs ~variables ~constraints ~nonzero_entries ~max_poly_size
        ~urs ~row_a ~col_a ~val_a ~rc_a ~row_b ~col_b ~val_b ~rc_b ~row_c
        ~col_c ~val_c ~rc_c ->
      add_finalizer
        (make public_inputs variables constraints nonzero_entries max_poly_size
           urs row_a col_a val_a rc_a row_b col_b val_b rc_b row_c col_c val_c
           rc_c)

  let m_poly_comm m f =
    let%map comm =
      foreign
        (prefix (Format.sprintf "%s_%s_comm" m f))
        (typ @-> returning PolyComm.typ)
    and add_finalizer = PolyComm.add_finalizer in
    fun x -> add_finalizer (comm x)

  let ( (a_row_comm, a_col_comm, a_val_comm, a_rc_comm)
      , (b_row_comm, b_col_comm, b_val_comm, b_rc_comm)
      , (c_row_comm, c_col_comm, c_val_comm, c_rc_comm) ) =
    let map3 (a, b, c) f = (f a, f b, f c) in
    let map4 (a, b, c, d) f = (f a, f b, f c, f d) in
    let polys = ("row", "col", "val", "rc") and mats = ("a", "b", "c") in
    map3 mats (fun m -> map4 polys (fun p -> m_poly_comm m p))
end

module PlonkVerifierIndex
    (F : Cstubs_applicative.Foreign_applicative)
    (P : Prefix)
    (Index : Type)
    (Urs : Type_with_finalizer
           with type 'a result := 'a F.result
            and type 'a return := 'a F.return)
    (PolyComm : Type_with_finalizer
                with type 'a result := 'a F.result
                 and type 'a return := 'a F.return)
    (ScalarField : Type_with_finalizer
                   with type 'a result := 'a F.result
                    and type 'a return := 'a F.return) =
struct
  include (
    struct
        type t = unit ptr

        let typ = ptr void
      end :
      Type )

  open F
  open F.Let_syntax

  let prefix = P.prefix

  let delete = foreign (prefix "delete") (typ @-> returning void)

  let add_finalizer =
    F.map delete ~f:(fun delete x ->
        Caml.Gc.finalise (bind_return ~f:delete) x ;
        x )

  (* Stub out delete to make sure we don't attempt to double-free. *)
  let delete : t -> unit = ignore

  let create =
    let%map create = foreign (prefix "create") (Index.typ @-> returning typ)
    and add_finalizer = add_finalizer in
    fun idx -> add_finalizer (create idx)

  let urs =
    let%map urs = foreign (prefix "urs") (typ @-> returning Urs.typ)
    and add_finalizer = Urs.add_finalizer in
    fun t -> add_finalizer (urs t)

  let make =
    let%map make =
      foreign (prefix "make")
        ( size_t @-> size_t @-> Urs.typ @-> PolyComm.typ @-> PolyComm.typ
        @-> PolyComm.typ @-> PolyComm.typ @-> PolyComm.typ @-> PolyComm.typ
        @-> PolyComm.typ @-> PolyComm.typ @-> PolyComm.typ @-> PolyComm.typ
        @-> PolyComm.typ @-> PolyComm.typ @-> PolyComm.typ @-> PolyComm.typ
        @-> PolyComm.typ @-> PolyComm.typ @-> PolyComm.typ @-> PolyComm.typ
        @-> ScalarField.typ @-> ScalarField.typ @-> returning typ )
    and add_finalizer = add_finalizer in
    fun ~max_poly_size ~max_quot_size ~urs ~sigma_comm0 ~sigma_comm1
        ~sigma_comm2 ~ql_comm ~qr_comm ~qo_comm ~qm_comm ~qc_comm ~rcm_comm0
        ~rcm_comm1 ~rcm_comm2 ~psm_comm ~add_comm ~mul1_comm ~mul2_comm
        ~emul1_comm ~emul2_comm ~emul3_comm ~r ~o ->
      add_finalizer
        (make max_poly_size max_quot_size urs sigma_comm0 sigma_comm1
           sigma_comm2 ql_comm qr_comm qo_comm qm_comm qc_comm rcm_comm0
           rcm_comm1 rcm_comm2 psm_comm add_comm mul1_comm mul2_comm emul1_comm
           emul2_comm emul3_comm r o)

  let element name f_typ add_finalizer =
    let%map element = foreign (prefix name) (typ @-> returning f_typ)
    and add_finalizer = add_finalizer in
    fun t -> add_finalizer (element t)

  let sigma_comm_0 = element "sigma_comm_0" PolyComm.typ PolyComm.add_finalizer

  let sigma_comm_1 = element "sigma_comm_1" PolyComm.typ PolyComm.add_finalizer

  let sigma_comm_2 = element "sigma_comm_2" PolyComm.typ PolyComm.add_finalizer

  let ql_comm = element "ql_comm" PolyComm.typ PolyComm.add_finalizer

  let qr_comm = element "qr_comm" PolyComm.typ PolyComm.add_finalizer

  let qo_comm = element "qo_comm" PolyComm.typ PolyComm.add_finalizer

  let qm_comm = element "qm_comm" PolyComm.typ PolyComm.add_finalizer

  let qc_comm = element "qc_comm" PolyComm.typ PolyComm.add_finalizer

  let rcm_comm_0 = element "rcm_comm_0" PolyComm.typ PolyComm.add_finalizer

  let rcm_comm_1 = element "rcm_comm_1" PolyComm.typ PolyComm.add_finalizer

  let rcm_comm_2 = element "rcm_comm_2" PolyComm.typ PolyComm.add_finalizer

  let psm_comm = element "psm_comm" PolyComm.typ PolyComm.add_finalizer

  let add_comm = element "add_comm" PolyComm.typ PolyComm.add_finalizer

  let mul1_comm = element "mul1_comm" PolyComm.typ PolyComm.add_finalizer

  let mul2_comm = element "mul2_comm" PolyComm.typ PolyComm.add_finalizer

  let emul1_comm = element "emul1_comm" PolyComm.typ PolyComm.add_finalizer

  let emul2_comm = element "emul2_comm" PolyComm.typ PolyComm.add_finalizer

  let emul3_comm = element "emul3_comm" PolyComm.typ PolyComm.add_finalizer

  let r = element "r" ScalarField.typ ScalarField.add_finalizer

  let o = element "o" ScalarField.typ ScalarField.add_finalizer
end

module URS
    (F : Cstubs_applicative.Foreign_applicative)
    (P : Prefix)
    (G1Affine : Type_with_finalizer
                with type 'a result := 'a F.result
                 and type 'a return := 'a F.return)
    (ScalarFieldVector : Type) =
struct
  include (
    struct
        type t = unit ptr

        let typ = ptr void
      end :
      Type )

  open P
  open F
  open F.Let_syntax

  let delete = foreign (prefix "delete") (typ @-> returning void)

  let add_finalizer =
    F.map delete ~f:(fun delete x ->
        Caml.Gc.finalise (bind_return ~f:delete) x ;
        x )

  (* Stub out delete to make sure we don't attempt to double-free. *)
  let delete : t -> unit = ignore

  let create =
    let%map create = foreign (prefix "create") (size_t @-> returning typ)
    and add_finalizer = add_finalizer in
    fun sz -> add_finalizer (create sz)

  let read =
    let%map read = foreign (prefix "read") (string @-> returning typ)
    and add_finalizer = add_finalizer in
    fun file -> add_finalizer (read file)

  let write = foreign (prefix "write") (typ @-> string @-> returning void)

  let lagrange_commitment =
    let%map lagrange_commitment =
      foreign
        (prefix "lagrange_commitment")
        (typ @-> size_t @-> size_t @-> returning G1Affine.typ)
    and add_finalizer = G1Affine.add_finalizer in
    fun urs domain_size i ->
      add_finalizer (lagrange_commitment urs domain_size i)

  let commit_evaluations =
    let%map commit_evaluations =
      foreign
        (prefix "commit_evaluations")
        (typ @-> size_t @-> ScalarFieldVector.typ @-> returning G1Affine.typ)
    and add_finalizer = G1Affine.add_finalizer in
    fun urs domain_size evals ->
      add_finalizer (commit_evaluations urs domain_size evals)
end

module Index
    (F : Cstubs_applicative.Foreign_applicative)
    (P : Prefix)
    (Constraint_matrix : Type)
    (PlolyComm : Type)
    (URS : Type) =
struct
  open F
  open F.Let_syntax

  include (
    struct
        type t = unit ptr

        let typ = ptr void
      end :
      Type )

  let prefix = P.prefix

  module M = Constraint_matrix

  let delete = foreign (prefix "delete") (typ @-> returning void)

  let add_finalizer =
    F.map delete ~f:(fun delete x ->
        Caml.Gc.finalise (bind_return ~f:delete) x ;
        x )

  (* Stub out delete to make sure we don't attempt to double-free. *)
  let delete : t -> unit = ignore

  let read =
    let%map read =
      foreign (prefix "read")
        ( URS.typ @-> Constraint_matrix.typ @-> Constraint_matrix.typ
        @-> Constraint_matrix.typ @-> size_t @-> string @-> returning typ )
    and add_finalizer = add_finalizer in
    fun urs a b c public_inputs path ->
      add_finalizer (read urs a b c public_inputs path)

  let write = foreign (prefix "write") (typ @-> string @-> returning void)

  let domain_h_size =
    foreign (prefix "domain_h_size") (typ @-> returning size_t)

  let domain_k_size =
    foreign (prefix "domain_k_size") (typ @-> returning size_t)

  let create =
    let%map create =
      foreign (prefix "create")
        ( M.typ @-> M.typ @-> M.typ @-> size_t @-> size_t @-> URS.typ
        @-> returning typ )
    and add_finalizer = add_finalizer in
    fun a b c vars public_inputs urs ->
      add_finalizer (create a b c vars public_inputs urs)

  let metadata s = foreign (prefix s) (typ @-> returning size_t)

  let num_variables = metadata "num_variables"

  let public_inputs = metadata "public_inputs"

  let nonzero_entries = metadata "nonzero_entries"

  let max_degree = metadata "max_degree"
end

module Plonk_index
    (F : Cstubs_applicative.Foreign_applicative)
    (P : Prefix)
    (Constraint_system : Type)
    (PlolyComm : Type)
    (URS : Type) =
struct
  open F
  open F.Let_syntax

  include (
    struct
        type t = unit ptr

        let typ = ptr void
      end :
      Type )

  let prefix = P.prefix

  let delete = foreign (prefix "delete") (typ @-> returning void)

  let add_finalizer =
    F.map delete ~f:(fun delete x ->
        Caml.Gc.finalise (bind_return ~f:delete) x ;
        x )

  (* Stub out delete to make sure we don't attempt to double-free. *)
  let delete : t -> unit = ignore

  let domain_d1_size =
    foreign (prefix "domain_d1_size") (typ @-> returning size_t)

  let domain_d4_size =
    foreign (prefix "domain_d4_size") (typ @-> returning size_t)

  let domain_d8_size =
    foreign (prefix "domain_d8_size") (typ @-> returning size_t)

  let create =
    let%map create =
      foreign (prefix "create")
        (Constraint_system.typ @-> size_t @-> URS.typ @-> returning typ)
    and add_finalizer = add_finalizer in
    fun cs sz urs -> add_finalizer (create cs sz urs)

  let metadata s = foreign (prefix s) (typ @-> returning size_t)

  let public_inputs = metadata "public_inputs"
end

module Vector
    (F : Cstubs_applicative.Foreign_applicative)
    (P : Prefix)
    (E : Type_with_finalizer
         with type 'a result := 'a F.result
          and type 'a return := 'a F.return) =
struct
  open F
  open F.Let_syntax

  type elt = E.t

  let prefix = with_prefix (P.prefix "vector")

  include (
    struct
        type t = unit ptr

        let typ = ptr void
      end :
      Type )

  let delete = foreign (prefix "delete") (typ @-> returning void)

  let add_finalizer =
    F.map delete ~f:(fun delete x ->
        Caml.Gc.finalise (bind_return ~f:delete) x ;
        x )

  (* Stub out delete to make sure we don't attempt to double-free. *)
  let delete : t -> unit = ignore

  let create =
    let%map create = foreign (prefix "create") (void @-> returning typ)
    and add_finalizer = add_finalizer in
    fun () -> add_finalizer (create ())

  let length = foreign (prefix "length") (typ @-> returning int)

  let emplace_back =
    foreign (prefix "emplace_back") (typ @-> E.typ @-> returning void)

  let get =
    let%map get = foreign (prefix "get") (typ @-> int @-> returning E.typ)
    and add_finalizer = E.add_finalizer in
    fun v i -> add_finalizer (get v i)
end

module Curve
    (F : Cstubs_applicative.Foreign_applicative)
    (P : Prefix)
    (BaseField : Type_with_finalizer
                 with type 'a result := 'a F.result
                  and type 'a return := 'a F.return)
    (ScalarField : Type) =
struct
  open F
  open F.Let_syntax

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

      let delete = foreign (prefix "delete") (typ @-> returning void)

      let add_finalizer =
        F.map delete ~f:(fun delete x ->
            Caml.Gc.finalise (bind_return ~f:delete) x ;
            x )

      (* Stub out delete to make sure we don't attempt to double-free. *)
      let delete : t -> unit = ignore
    end

    module Pair = struct
      module T = Pair_with_make (F) (Prefix) (T)
      include T

      module Vector =
        Vector
          (F)
          (struct
            let prefix = T.prefix
          end)
          (T)
    end

    include T

    let x =
      let%map x = foreign (prefix "x") (typ @-> returning BaseField.typ)
      and add_finalizer = BaseField.add_finalizer in
      fun t -> add_finalizer (x t)

    let y =
      let%map x = foreign (prefix "y") (typ @-> returning BaseField.typ)
      and add_finalizer = BaseField.add_finalizer in
      fun t -> add_finalizer (x t)

    let create =
      let%map create =
        foreign (prefix "create")
          (BaseField.typ @-> BaseField.typ @-> returning typ)
      and add_finalizer = add_finalizer in
      fun x y -> add_finalizer (create x y)

    let is_zero = foreign (prefix "is_zero") (typ @-> returning bool)

    module Vector =
      Vector
        (F)
        (struct
          let prefix = prefix
        end)
        (T)
  end

  let delete = foreign (prefix "delete") (typ @-> returning void)

  let add_finalizer =
    F.map delete ~f:(fun delete x ->
        Caml.Gc.finalise (bind_return ~f:delete) x ;
        x )

  (* Stub out delete to make sure we don't attempt to double-free. *)
  let delete : t -> unit = ignore

  let to_affine_exn =
    let%map to_affine =
      foreign (prefix "to_affine") (typ @-> returning Affine.typ)
    and add_finalizer = Affine.add_finalizer in
    fun t -> add_finalizer (to_affine t)

  let of_affine_coordinates =
    let%map of_affine_coordinates =
      foreign
        (prefix "of_affine_coordinates")
        (BaseField.typ @-> BaseField.typ @-> returning typ)
    and add_finalizer = add_finalizer in
    fun x y -> add_finalizer (of_affine_coordinates x y)

  let add =
    let%map add = foreign (prefix "add") (typ @-> typ @-> returning typ)
    and add_finalizer = add_finalizer in
    fun x y -> add_finalizer (add x y)

  let double =
    let%map double = foreign (prefix "double") (typ @-> returning typ)
    and add_finalizer = add_finalizer in
    fun x -> add_finalizer (double x)

  let scale =
    let%map scale =
      foreign (prefix "scale") (typ @-> ScalarField.typ @-> returning typ)
    and add_finalizer = add_finalizer in
    fun x a -> add_finalizer (scale x a)

  let sub =
    let%map sub = foreign (prefix "sub") (typ @-> typ @-> returning typ)
    and add_finalizer = add_finalizer in
    fun x y -> add_finalizer (sub x y)

  let negate =
    let%map negate = foreign (prefix "negate") (typ @-> returning typ)
    and add_finalizer = add_finalizer in
    fun x -> add_finalizer (negate x)

  let random =
    let%map random = foreign (prefix "random") (void @-> returning typ)
    and add_finalizer = add_finalizer in
    fun () -> add_finalizer (random ())

  let one =
    let%map one = foreign (prefix "one") (void @-> returning typ)
    and add_finalizer = add_finalizer in
    fun () -> add_finalizer (one ())
end

module Pairing_marlin_proof
    (F : Cstubs_applicative.Foreign_applicative)
    (P : Prefix)
    (AffineCurve : Type_with_finalizer
                   with type 'a result := 'a F.result
                    and type 'a return := 'a F.return)
    (ScalarField : Type_with_finalizer
                   with type 'a result := 'a F.result
                    and type 'a return := 'a F.return)
    (Index : Type)
    (VerifierIndex : Type)
    (ScalarFieldVector : Type) =
struct
  open F
  open F.Let_syntax

  let prefix = P.prefix

  module T :
    Type_with_finalizer
    with type 'a result := 'a F.result
     and type 'a return := 'a F.return = struct
    type t = unit ptr

    let typ = ptr void

    let delete = foreign (prefix "delete") (typ @-> returning void)

    let add_finalizer =
      F.map delete ~f:(fun delete x ->
          Caml.Gc.finalise (bind_return ~f:delete) x ;
          x )
  end

  include T
  module Vector = Vector (F) (P) (T)

  module Evals = struct
    include (
      struct
          type t = unit ptr

          let typ = ptr void
        end :
        Type )

    let prefix = with_prefix (P.prefix "evals")

    let delete = foreign (prefix "delete") (typ @-> returning void)

    let add_finalizer =
      F.map delete ~f:(fun delete x ->
          Caml.Gc.finalise (bind_return ~f:delete) x ;
          x )

    (* Stub out delete to make sure we don't attempt to double-free. *)
    let delete : t -> unit = ignore

    let f i =
      let%map f = foreign (prefix i) (typ @-> returning ScalarField.typ)
      and add_finalizer = ScalarField.add_finalizer in
      fun t -> add_finalizer (f t)

    let f0 = f "0"

    let f1 = f "1"

    let f2 = f "2"
  end

  (* Stub out delete to make sure we don't attempt to double-free. *)
  let delete : t -> unit = ignore

  let create =
    let%map create =
      foreign (prefix "create")
        ( Index.typ @-> ScalarFieldVector.typ @-> ScalarFieldVector.typ
        @-> returning typ )
    and add_finalizer = add_finalizer in
    fun i primary_input auxiliary_input ->
      add_finalizer (create i primary_input auxiliary_input)

  let verify =
    foreign (prefix "verify") (VerifierIndex.typ @-> typ @-> returning bool)

  let batch_verify =
    foreign (prefix "batch_verify")
      (VerifierIndex.typ @-> Vector.typ @-> returning bool)

  let make =
    let%map make =
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
    and add_finalizer = add_finalizer in
    fun ~primary_input ~w_comm ~za_comm ~zb_comm ~h1_comm ~g1_comm_0 ~g1_comm_1
        ~h2_comm ~g2_comm_0 ~g2_comm_1 ~h3_comm ~g3_comm_0 ~g3_comm_1 ~proof1
        ~proof2 ~proof3 ~sigma2 ~sigma3 ~w ~za ~zb ~h1 ~g1 ~h2 ~g2 ~h3 ~g3
        ~row_0 ~row_1 ~row_2 ~col_0 ~col_1 ~col_2 ~val_0 ~val_1 ~val_2 ~rc_0
        ~rc_1 ~rc_2 ->
      add_finalizer
        (make primary_input w_comm za_comm zb_comm h1_comm g1_comm_0 g1_comm_1
           h2_comm g2_comm_0 g2_comm_1 h3_comm g3_comm_0 g3_comm_1 proof1
           proof2 proof3 sigma2 sigma3 w za zb h1 g1 h2 g2 h3 g3 row_0 row_1
           row_2 col_0 col_1 col_2 val_0 val_1 val_2 rc_0 rc_1 rc_2)

  let f name f_typ add_finalizer =
    let%map f = foreign (prefix name) (typ @-> returning f_typ)
    and add_finalizer = add_finalizer in
    fun t -> add_finalizer (f t)

  let w_comm = f "w_comm" AffineCurve.typ AffineCurve.add_finalizer

  let za_comm = f "za_comm" AffineCurve.typ AffineCurve.add_finalizer

  let zb_comm = f "zb_comm" AffineCurve.typ AffineCurve.add_finalizer

  let h1_comm = f "h1_comm" AffineCurve.typ AffineCurve.add_finalizer

  let h2_comm = f "h2_comm" AffineCurve.typ AffineCurve.add_finalizer

  let h3_comm = f "h3_comm" AffineCurve.typ AffineCurve.add_finalizer

  module Commitment_with_degree_bound = struct
    include (
      struct
          type t = unit ptr

          let typ = ptr void
        end :
        Type )

    let prefix = with_prefix (P.prefix "commitment_with_degree_bound")

    let delete = foreign (prefix "delete") (typ @-> returning void)

    let add_finalizer =
      F.map delete ~f:(fun delete x ->
          Caml.Gc.finalise (bind_return ~f:delete) x ;
          x )

    (* Stub out delete to make sure we don't attempt to double-free. *)
    let delete : t -> unit = ignore

    let f i =
      let%map f = foreign (prefix i) (typ @-> returning AffineCurve.typ)
      and add_finalizer = AffineCurve.add_finalizer in
      fun t -> add_finalizer (f t)

    let f0 = f "0"

    let f1 = f "1"
  end

  let g1_comm_nocopy =
    f "g1_comm_nocopy" Commitment_with_degree_bound.typ
      Commitment_with_degree_bound.add_finalizer

  let g2_comm_nocopy =
    f "g2_comm_nocopy" Commitment_with_degree_bound.typ
      Commitment_with_degree_bound.add_finalizer

  let g3_comm_nocopy =
    f "g3_comm_nocopy" Commitment_with_degree_bound.typ
      Commitment_with_degree_bound.add_finalizer

  let w_eval = f "w_eval" ScalarField.typ ScalarField.add_finalizer

  let za_eval = f "za_eval" ScalarField.typ ScalarField.add_finalizer

  let zb_eval = f "zb_eval" ScalarField.typ ScalarField.add_finalizer

  let h1_eval = f "h1_eval" ScalarField.typ ScalarField.add_finalizer

  let g1_eval = f "g1_eval" ScalarField.typ ScalarField.add_finalizer

  let h2_eval = f "h2_eval" ScalarField.typ ScalarField.add_finalizer

  let g2_eval = f "g2_eval" ScalarField.typ ScalarField.add_finalizer

  let h3_eval = f "h3_eval" ScalarField.typ ScalarField.add_finalizer

  let g3_eval = f "g3_eval" ScalarField.typ ScalarField.add_finalizer

  let proof1 = f "proof1" AffineCurve.typ AffineCurve.add_finalizer

  let proof2 = f "proof2" AffineCurve.typ AffineCurve.add_finalizer

  let proof3 = f "proof3" AffineCurve.typ AffineCurve.add_finalizer

  let sigma2 = f "sigma2" ScalarField.typ ScalarField.add_finalizer

  let sigma3 = f "sigma3" ScalarField.typ ScalarField.add_finalizer

  let row_evals_nocopy = f "row_evals_nocopy" Evals.typ Evals.add_finalizer

  let col_evals_nocopy = f "col_evals_nocopy" Evals.typ Evals.add_finalizer

  let val_evals_nocopy = f "val_evals_nocopy" Evals.typ Evals.add_finalizer

  let rc_evals_nocopy = f "rc_evals_nocopy" Evals.typ Evals.add_finalizer
end

module Triple
    (F : Cstubs_applicative.Foreign_applicative)
    (P : Prefix)
    (Elt : Type_with_finalizer
           with type 'a result := 'a F.result
            and type 'a return := 'a F.return) =
struct
  include (
    struct
        type t = unit ptr

        let typ = ptr void
      end :
      Type )

  open F
  open F.Let_syntax

  let prefix = with_prefix (P.prefix "triple")

  let delete = foreign (prefix "delete") (typ @-> returning void)

  let add_finalizer =
    F.map delete ~f:(fun delete x ->
        Caml.Gc.finalise (bind_return ~f:delete) x ;
        x )

  (* Stub out delete to make sure we don't attempt to double-free. *)
  let delete : t -> unit = ignore

  let f i =
    let%map f = foreign (prefix i) (typ @-> returning Elt.typ)
    and add_finalizer = Elt.add_finalizer in
    fun t -> add_finalizer (f t)

  let f0 = f "0"

  let f1 = f "1"

  let f2 = f "2"
end

module Dlog_poly_comm
    (F : Cstubs_applicative.Foreign_applicative)
    (P : Prefix) (AffineCurve : sig
        module Underlying : Type

        include
          Type_with_finalizer
          with type 'a result := 'a F.result
           and type 'a return := 'a F.return
           and type t = Underlying.t ptr

        module Vector :
          Type_with_finalizer
          with type 'a result := 'a F.result
           and type 'a return := 'a F.return
    end) =
struct
  include (
    struct
        type t = unit ptr

        let typ = ptr void
      end :
      Type )

  let prefix = P.prefix

  open F
  open F.Let_syntax

  let delete = foreign (prefix "delete") (typ @-> returning void)

  let add_finalizer =
    F.map delete ~f:(fun delete x ->
        Caml.Gc.finalise (bind_return ~f:delete) x ;
        x )

  (* Stub out delete to make sure we don't attempt to double-free. *)
  let delete : t -> unit = ignore

  let unshifted =
    let%map unshifted =
      foreign (prefix "unshifted") (typ @-> returning AffineCurve.Vector.typ)
    and add_finalizer = AffineCurve.Vector.add_finalizer in
    fun t -> add_finalizer (unshifted t)

  let shifted : (t -> AffineCurve.t option return) result =
    let%map shifted =
      foreign (prefix "shifted")
        (typ @-> returning (ptr_opt AffineCurve.Underlying.typ))
    and add_finalizer = AffineCurve.add_finalizer in
    fun t ->
      (* TODO: This is a mess.. *)
      let x = shifted t in
      map_return x ~f:(function
        | Some x_value ->
            add_finalizer (map_return x ~f:(fun _ -> x_value)) |> ignore
        | None ->
            () )
      |> ignore ;
      x

  let make : (AffineCurve.Vector.t -> AffineCurve.t option -> t return) result
      =
    let%map make =
      foreign (prefix "make")
        ( AffineCurve.Vector.typ
        @-> ptr_opt AffineCurve.Underlying.typ
        @-> returning typ )
    and add_finalizer = add_finalizer in
    fun x y -> add_finalizer (make x y)
end

module Dlog_opening_proof
    (F : Cstubs_applicative.Foreign_applicative)
    (P : Prefix)
    (ScalarField : Type_with_finalizer
                   with type 'a result := 'a F.result
                    and type 'a return := 'a F.return) (AffineCurve : sig
        include
          Type_with_finalizer
          with type 'a result := 'a F.result
           and type 'a return := 'a F.return

        module Pair : sig
          module Vector :
            Type_with_finalizer
            with type 'a result := 'a F.result
             and type 'a return := 'a F.return
        end
    end) =
struct
  include (
    struct
        type t = unit ptr

        let typ = ptr void
      end :
      Type )

  let prefix = P.prefix

  open F
  open F.Let_syntax

  let lr =
    let%map lr =
      foreign (prefix "lr") (typ @-> returning AffineCurve.Pair.Vector.typ)
    and add_finalizer = AffineCurve.Pair.Vector.add_finalizer in
    fun t -> add_finalizer (lr t)

  let z1 =
    let%map z1 = foreign (prefix "z1") (typ @-> returning ScalarField.typ)
    and add_finalizer = ScalarField.add_finalizer in
    fun t -> add_finalizer (z1 t)

  let z2 =
    let%map z2 = foreign (prefix "z2") (typ @-> returning ScalarField.typ)
    and add_finalizer = ScalarField.add_finalizer in
    fun t -> add_finalizer (z2 t)

  let delta =
    let%map delta = foreign (prefix "delta") (typ @-> returning AffineCurve.typ)
    and add_finalizer = AffineCurve.add_finalizer in
    fun t -> add_finalizer (delta t)

  let sg =
    let%map sg = foreign (prefix "sg") (typ @-> returning AffineCurve.typ)
    and add_finalizer = AffineCurve.add_finalizer in
    fun t -> add_finalizer (sg t)

  let delete = foreign (prefix "delete") (typ @-> returning void)

  let add_finalizer =
    F.map delete ~f:(fun delete x ->
        Caml.Gc.finalise (bind_return ~f:delete) x ;
        x )

  (* Stub out delete to make sure we don't attempt to double-free. *)
  let delete : t -> unit = ignore
end

module Dlog_marlin_proof
    (F : Cstubs_applicative.Foreign_applicative)
    (P : Prefix) (AffineCurve : sig
        include Type

        module Vector : Type

        module Pair : sig
          include Type

          module Vector : Type
        end
    end)
    (ScalarField : Type_with_finalizer
                   with type 'a result := 'a F.result
                    and type 'a return := 'a F.return)
    (Index : Type)
    (VerifierIndex : Type)
    (ScalarFieldVector : Type_with_finalizer
                         with type 'a result := 'a F.result
                          and type 'a return := 'a F.return)
    (FieldVectorTriple : Type_with_finalizer
                         with type 'a result := 'a F.result
                          and type 'a return := 'a F.return)
    (OpeningProof : Type_with_finalizer
                    with type 'a result := 'a F.result
                     and type 'a return := 'a F.return)
    (PolyComm : Type_with_finalizer
                with type 'a result := 'a F.result
                 and type 'a return := 'a F.return) =
struct
  open F
  open F.Let_syntax

  let prefix = P.prefix

  module T :
    Type_with_finalizer
    with type 'a result := 'a F.result
     and type 'a return := 'a F.return = struct
    type t = unit ptr

    let typ = ptr void

    let delete = foreign (prefix "delete") (typ @-> returning void)

    let add_finalizer =
      F.map delete ~f:(fun delete x ->
          Caml.Gc.finalise (bind_return ~f:delete) x ;
          x )
  end

  include T

  (* Stub out delete to make sure we don't attempt to double-free. *)
  let delete : t -> unit = ignore

  module Vector = Vector (F) (P) (T)

  module Evaluations = struct
    let prefix = with_prefix (prefix "evaluations")

    module T :
      Type_with_finalizer
      with type 'a result := 'a F.result
       and type 'a return := 'a F.return = struct
      type t = unit ptr

      let typ = ptr void

      let delete = foreign (prefix "delete") (typ @-> returning void)

      let add_finalizer =
        F.map delete ~f:(fun delete x ->
            Caml.Gc.finalise (bind_return ~f:delete) x ;
            x )
    end

    (* Stub out delete to make sure we don't attempt to double-free. *)
    let delete : t -> unit = ignore

    include T

    let f s =
      let%map f = foreign (prefix s) (typ @-> returning ScalarFieldVector.typ)
      and add_finalizer = ScalarFieldVector.add_finalizer in
      fun t -> add_finalizer (f t)

    let w = f "w"

    let za = f "za"

    let zb = f "zb"

    let h1 = f "h1"

    let g1 = f "g1"

    let h2 = f "h2"

    let g2 = f "g2"

    let h3 = f "h3"

    let g3 = f "g3"

    let evals s =
      let%map f = foreign (prefix s) (typ @-> returning FieldVectorTriple.typ)
      and add_finalizer = FieldVectorTriple.add_finalizer in
      fun t -> add_finalizer (f t)

    let row_nocopy = evals "row_nocopy"

    let col_nocopy = evals "col_nocopy"

    let val_nocopy = evals "val_nocopy"

    let rc_nocopy = evals "rc_nocopy"

    module Triple =
      Triple
        (F)
        (struct
          let prefix = prefix
        end)
        (T)

    let make =
      let%map make =
        foreign (prefix "make")
          ( ScalarFieldVector.typ @-> ScalarFieldVector.typ
          @-> ScalarFieldVector.typ @-> ScalarFieldVector.typ
          @-> ScalarFieldVector.typ @-> ScalarFieldVector.typ
          @-> ScalarFieldVector.typ @-> ScalarFieldVector.typ
          @-> ScalarFieldVector.typ @-> ScalarFieldVector.typ
          @-> ScalarFieldVector.typ @-> ScalarFieldVector.typ
          @-> ScalarFieldVector.typ @-> ScalarFieldVector.typ
          @-> ScalarFieldVector.typ @-> ScalarFieldVector.typ
          @-> ScalarFieldVector.typ @-> ScalarFieldVector.typ
          @-> ScalarFieldVector.typ @-> ScalarFieldVector.typ
          @-> ScalarFieldVector.typ @-> returning typ )
      and add_finalizer = add_finalizer in
      fun ~w ~za ~zb ~h1 ~g1 ~h2 ~g2 ~h3 ~g3 ~row_0 ~row_1 ~row_2 ~col_0 ~col_1
          ~col_2 ~val_0 ~val_1 ~val_2 ~rc_0 ~rc_1 ~rc_2 ->
        add_finalizer
          (make w za zb h1 g1 h2 g2 h3 g3 row_0 row_1 row_2 col_0 col_1 col_2
             val_0 val_1 val_2 rc_0 rc_1 rc_2)
  end

  let make =
    let%map make =
      foreign (prefix "make")
        ( ScalarFieldVector.typ @-> PolyComm.typ @-> PolyComm.typ
        @-> PolyComm.typ @-> PolyComm.typ @-> PolyComm.typ @-> PolyComm.typ
        @-> PolyComm.typ @-> PolyComm.typ @-> PolyComm.typ @-> ScalarField.typ
        @-> ScalarField.typ @-> AffineCurve.Pair.Vector.typ @-> ScalarField.typ
        @-> ScalarField.typ @-> AffineCurve.typ @-> AffineCurve.typ
        @-> Evaluations.typ @-> Evaluations.typ @-> Evaluations.typ
        @-> ScalarFieldVector.typ @-> AffineCurve.Vector.typ @-> returning typ
        )
    and add_finalizer = add_finalizer in
    fun ~primary_input ~w_comm ~za_comm ~zb_comm ~h1_comm ~g1_comm ~h2_comm
        ~g2_comm ~h3_comm ~g3_comm ~sigma2 ~sigma3 ~lr ~z1 ~z2 ~delta ~sg
        ~evals0 ~evals1 ~evals2 ~prev_challenges ~prev_sgs ->
      add_finalizer
        (make primary_input w_comm za_comm zb_comm h1_comm g1_comm h2_comm
           g2_comm h3_comm g3_comm sigma2 sigma3 lr z1 z2 delta sg evals0
           evals1 evals2 prev_challenges prev_sgs)

  let create =
    let%map create =
      foreign (prefix "create")
        ( Index.typ @-> ScalarFieldVector.typ @-> ScalarFieldVector.typ
        @-> ScalarFieldVector.typ @-> AffineCurve.Vector.typ @-> returning typ
        )
    and add_finalizer = add_finalizer in
    fun ~index ~primary_input ~auxiliary_input ~prev_challenges ~prev_sgs ->
      add_finalizer
        (create index primary_input auxiliary_input prev_challenges prev_sgs)

  let verify =
    foreign (prefix "verify") (VerifierIndex.typ @-> typ @-> returning bool)

  let batch_verify =
    foreign (prefix "batch_verify")
      (VerifierIndex.typ @-> Vector.typ @-> returning bool)

  let f name f_typ add_finalizer =
    let%map f = foreign (prefix name) (typ @-> returning f_typ)
    and add_finalizer = add_finalizer in
    fun t -> add_finalizer (f t)

  let w_comm = f "w_comm" PolyComm.typ PolyComm.add_finalizer

  let za_comm = f "za_comm" PolyComm.typ PolyComm.add_finalizer

  let zb_comm = f "zb_comm" PolyComm.typ PolyComm.add_finalizer

  let h1_comm = f "h1_comm" PolyComm.typ PolyComm.add_finalizer

  let h2_comm = f "h2_comm" PolyComm.typ PolyComm.add_finalizer

  let h3_comm = f "h3_comm" PolyComm.typ PolyComm.add_finalizer

  let g1_comm_nocopy = f "g1_comm_nocopy" PolyComm.typ PolyComm.add_finalizer

  let g2_comm_nocopy = f "g2_comm_nocopy" PolyComm.typ PolyComm.add_finalizer

  let g3_comm_nocopy = f "g3_comm_nocopy" PolyComm.typ PolyComm.add_finalizer

  let evals_nocopy =
    f "evals_nocopy" Evaluations.Triple.typ Evaluations.Triple.add_finalizer

  let proof = f "proof" OpeningProof.typ OpeningProof.add_finalizer

  let sigma2 = f "sigma2" ScalarField.typ ScalarField.add_finalizer

  let sigma3 = f "sigma3" ScalarField.typ ScalarField.add_finalizer
end

module Dlog_plonk_proof
    (F : Cstubs_applicative.Foreign_applicative)
    (P : Prefix) (AffineCurve : sig
        include Type

        module Vector : Type

        module Pair : sig
          include Type

          module Vector : Type
        end
    end)
    (ScalarField : Type_with_finalizer
                   with type 'a result := 'a F.result
                    and type 'a return := 'a F.return)
    (Index : Type)
    (VerifierIndex : Type)
    (ScalarFieldVector : Type_with_finalizer
                         with type 'a result := 'a F.result
                          and type 'a return := 'a F.return)
    (FieldVectorPair : Type)
    (OpeningProof : Type_with_finalizer
                    with type 'a result := 'a F.result
                     and type 'a return := 'a F.return)
    (PolyComm : Type_with_finalizer
                with type 'a result := 'a F.result
                 and type 'a return := 'a F.return) =
struct
  open F
  open F.Let_syntax

  let prefix = P.prefix

  module T :
    Type_with_finalizer
    with type 'a result := 'a F.result
     and type 'a return := 'a F.return = struct
    type t = unit ptr

    let typ = ptr void

    let delete = foreign (prefix "delete") (typ @-> returning void)

    let add_finalizer =
      F.map delete ~f:(fun delete x ->
          Caml.Gc.finalise (bind_return ~f:delete) x ;
          x )
  end

  include T

  (* Stub out delete to make sure we don't attempt to double-free. *)
  let delete : t -> unit = ignore

  module Vector = Vector (F) (P) (T)

  module Evaluations = struct
    let prefix = with_prefix (prefix "evaluations")

    module T :
      Type_with_finalizer
      with type 'a result := 'a F.result
       and type 'a return := 'a F.return = struct
      type t = unit ptr

      let typ = ptr void

      let delete = foreign (prefix "delete") (typ @-> returning void)

      let add_finalizer =
        F.map delete ~f:(fun delete x ->
            Caml.Gc.finalise (bind_return ~f:delete) x ;
            x )
    end

    include T

    let f s =
      let%map f = foreign (prefix s) (typ @-> returning ScalarFieldVector.typ)
      and add_finalizer = ScalarFieldVector.add_finalizer in
      fun t -> add_finalizer (f t)

    let sigma1 = f "sigma1"

    let sigma2 = f "sigma2"

    let l = f "l"

    let r = f "r"

    let o = f "o"

    let z = f "z"

    let t = f "t"

    let f = f "f"

    module Pair =
      Pair
        (F)
        (struct
          let prefix = prefix
        end)
        (T)

    let make =
      let%map make =
        foreign (prefix "make")
          ( ScalarFieldVector.typ @-> ScalarFieldVector.typ
          @-> ScalarFieldVector.typ @-> ScalarFieldVector.typ
          @-> ScalarFieldVector.typ @-> ScalarFieldVector.typ
          @-> ScalarFieldVector.typ @-> ScalarFieldVector.typ @-> returning typ
          )
      and add_finalizer = add_finalizer in
      fun ~l ~r ~o ~z ~t ~f ~sigma1 ~sigma2 ->
        add_finalizer (make l r o z t f sigma1 sigma2)
  end

  let make =
    let%map make =
      foreign (prefix "make")
        ( ScalarFieldVector.typ @-> PolyComm.typ @-> PolyComm.typ
        @-> PolyComm.typ @-> PolyComm.typ @-> PolyComm.typ
        @-> AffineCurve.Pair.Vector.typ @-> PolyComm.typ @-> PolyComm.typ
        @-> AffineCurve.typ @-> AffineCurve.typ @-> Evaluations.typ
        @-> Evaluations.typ @-> returning typ )
    and add_finalizer = add_finalizer in
    fun ~primary_input ~l_comm ~r_comm ~o_comm ~z_comm ~t_comm ~lr ~z1 ~z2
        ~delta ~sg ~evals0 ~evals1 ->
      add_finalizer
        (make primary_input l_comm r_comm o_comm z_comm t_comm lr z1 z2 delta
           sg evals0 evals1)

  let create =
    let%map create =
      foreign (prefix "create")
        ( Index.typ @-> ScalarFieldVector.typ @-> ScalarFieldVector.typ
        @-> returning typ )
    and add_finalizer = add_finalizer in
    fun index primary_input auxiliary_input ->
      add_finalizer (create index primary_input auxiliary_input)

  let verify =
    foreign (prefix "verify") (VerifierIndex.typ @-> typ @-> returning bool)

  let batch_verify =
    foreign (prefix "batch_verify")
      (VerifierIndex.typ @-> Vector.typ @-> returning bool)

  let f name f_typ add_finalizer =
    let%map f = foreign (prefix name) (typ @-> returning f_typ)
    and add_finalizer = add_finalizer in
    fun t -> add_finalizer (f t)

  let l_comm = f "l_comm" PolyComm.typ PolyComm.add_finalizer

  let r_comm = f "r_comm" PolyComm.typ PolyComm.add_finalizer

  let o_comm = f "o_comm" PolyComm.typ PolyComm.add_finalizer

  let z_comm = f "z_comm" PolyComm.typ PolyComm.add_finalizer

  let t_comm = f "t_comm" PolyComm.typ PolyComm.add_finalizer

  let proof = f "proof" OpeningProof.typ OpeningProof.add_finalizer

  let evals_nocopy =
    f "evals_nocopy" Evaluations.Pair.typ Evaluations.Pair.add_finalizer
end

module Pairing_oracles
    (F : Cstubs_applicative.Foreign_applicative)
    (P : Prefix)
    (Field : Type_with_finalizer
             with type 'a result := 'a F.result
              and type 'a return := 'a F.return)
    (VerifierIndex : Type)
    (Proof : Type) =
struct
  include (
    struct
        type t = unit ptr

        let typ = ptr void
      end :
      Type )

  open F
  open F.Let_syntax

  let prefix = P.prefix

  let delete = foreign (prefix "delete") (typ @-> returning void)

  let add_finalizer =
    F.map delete ~f:(fun delete x ->
        Caml.Gc.finalise (bind_return ~f:delete) x ;
        x )

  (* Stub out delete to make sure we don't attempt to double-free. *)
  let delete : t -> unit = ignore

  let create =
    let%map create =
      foreign (prefix "create")
        (VerifierIndex.typ @-> Proof.typ @-> returning typ)
    and add_finalizer = add_finalizer in
    fun i proof -> add_finalizer (create i proof)

  let element name =
    let%map element = foreign (prefix name) (typ @-> returning Field.typ)
    and add_finalizer = Field.add_finalizer in
    fun t -> add_finalizer (element t)

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
    (F : Cstubs_applicative.Foreign_applicative)
    (P : Prefix) (Field : sig
        include
          Type_with_finalizer
          with type 'a result := 'a F.result
           and type 'a return := 'a F.return

        module Vector :
          Type_with_finalizer
          with type 'a result := 'a F.result
           and type 'a return := 'a F.return
    end)
    (VerifierIndex : Type)
    (Proof : Type)
    (FieldVectorTriple : Type_with_finalizer
                         with type 'a result := 'a F.result
                          and type 'a return := 'a F.return) =
struct
  open F
  open F.Let_syntax

  let prefix = P.prefix

  include (
    struct
        type t = unit ptr

        let typ = ptr void

        let delete = foreign (prefix "delete") (typ @-> returning void)

        let add_finalizer =
          F.map delete ~f:(fun delete x ->
              Caml.Gc.finalise (bind_return ~f:delete) x ;
              x )
      end :
      Type_with_finalizer
      with type 'a result := 'a F.result
       and type 'a return := 'a F.return )

  (* Stub out delete to make sure we don't attempt to double-free. *)
  let delete : t -> unit = ignore

  let create =
    let%map create =
      foreign (prefix "create")
        (VerifierIndex.typ @-> Proof.typ @-> returning typ)
    and add_finalizer = add_finalizer in
    fun i proof -> add_finalizer (create i proof)

  let element name =
    let%map element = foreign (prefix name) (typ @-> returning Field.typ)
    and add_finalizer = Field.add_finalizer in
    fun t -> add_finalizer (element t)

  let opening_prechallenges =
    let%map opening_prechallenges =
      foreign
        (prefix "opening_prechallenges")
        (typ @-> returning Field.Vector.typ)
    and add_finalizer = Field.Vector.add_finalizer in
    fun t -> add_finalizer (opening_prechallenges t)

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
    let%map x_hat_nocopy =
      foreign (prefix "x_hat_nocopy") (typ @-> returning FieldVectorTriple.typ)
    and add_finalizer = FieldVectorTriple.add_finalizer in
    fun t -> add_finalizer (x_hat_nocopy t)

  let digest_before_evaluations = element "digest_before_evaluations"
end

module Dlog_plonk_oracles
    (F : Cstubs_applicative.Foreign_applicative)
    (P : Prefix) (Field : sig
        include
          Type_with_finalizer
          with type 'a result := 'a F.result
           and type 'a return := 'a F.return

        module Vector :
          Type_with_finalizer
          with type 'a result := 'a F.result
           and type 'a return := 'a F.return
    end)
    (VerifierIndex : Type)
    (Proof : Type)
    (FieldVectorTriple : Type) =
struct
  open F
  open F.Let_syntax

  let prefix = P.prefix

  include (
    struct
        type t = unit ptr

        let typ = ptr void

        let delete = foreign (prefix "delete") (typ @-> returning void)

        let add_finalizer =
          F.map delete ~f:(fun delete x ->
              Caml.Gc.finalise (bind_return ~f:delete) x ;
              x )
      end :
      Type_with_finalizer
      with type 'a result := 'a F.result
       and type 'a return := 'a F.return )

  (* Stub out delete to make sure we don't attempt to double-free. *)
  let delete : t -> unit = ignore

  let create =
    let%map create =
      foreign (prefix "create")
        (VerifierIndex.typ @-> Proof.typ @-> returning typ)
    and add_finalizer = add_finalizer in
    fun index proof -> add_finalizer (create index proof)

  let element name =
    let%map element = foreign (prefix name) (typ @-> returning Field.typ)
    and add_finalizer = Field.add_finalizer in
    fun t -> add_finalizer (element t)

  let opening_prechallenges =
    let%map opening_prechallenges =
      foreign
        (prefix "opening_prechallenges")
        (typ @-> returning Field.Vector.typ)
    and add_finalizer = Field.Vector.add_finalizer in
    fun t -> add_finalizer (opening_prechallenges t)

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
    (F : Cstubs_applicative.Foreign_applicative)
    (P : Prefix)
    (Bigint : Type_with_finalizer
              with type 'a result := 'a F.result
               and type 'a return := 'a F.return)
    (Usize_vector : Type) =
struct
  open F
  open F.Let_syntax

  let prefix = P.prefix

  module T :
    Type_with_finalizer
    with type 'a result := 'a F.result
     and type 'a return := 'a F.return = struct
    type t = unit ptr

    let typ = ptr void

    let delete = foreign (prefix "delete") (typ @-> returning void)

    let add_finalizer =
      F.map delete ~f:(fun delete x ->
          Caml.Gc.finalise (bind_return ~f:delete) x ;
          x )
  end

  include T

  (* Stub out delete to make sure we don't attempt to double-free. *)
  let delete : t -> unit = ignore

  let size_in_bits = foreign (prefix "size_in_bits") (void @-> returning int)

  let size =
    let%map size = foreign (prefix "size") (void @-> returning Bigint.typ)
    and add_finalizer = Bigint.add_finalizer in
    fun () -> add_finalizer (size ())

  let is_square = foreign (prefix "is_square") (typ @-> returning bool)

  let sqrt =
    let%map sqrt = foreign (prefix "sqrt") (typ @-> returning typ)
    and add_finalizer = add_finalizer in
    fun t -> add_finalizer (sqrt t)

  let random =
    let%map random = foreign (prefix "random") (void @-> returning typ)
    and add_finalizer = add_finalizer in
    fun () -> add_finalizer (random ())

  let of_int =
    let%map of_int = foreign (prefix "of_int") (uint64_t @-> returning typ)
    and add_finalizer = add_finalizer in
    fun i -> add_finalizer (of_int i)

  let to_string = foreign (prefix "to_string") (typ @-> returning string)

  let inv =
    let%map inv = foreign (prefix "inv") (typ @-> returning typ)
    and add_finalizer = add_finalizer in
    fun x -> add_finalizer (inv x)

  let square =
    let%map square = foreign (prefix "square") (typ @-> returning typ)
    and add_finalizer = add_finalizer in
    fun x -> add_finalizer (square x)

  let add =
    let%map add = foreign (prefix "add") (typ @-> typ @-> returning typ)
    and add_finalizer = add_finalizer in
    fun x y -> add_finalizer (add x y)

  let negate =
    let%map negate = foreign (prefix "negate") (typ @-> returning typ)
    and add_finalizer = add_finalizer in
    fun x -> add_finalizer (negate x)

  let mul =
    let%map mul = foreign (prefix "mul") (typ @-> typ @-> returning typ)
    and add_finalizer = add_finalizer in
    fun x y -> add_finalizer (mul x y)

  let div =
    let%map div = foreign (prefix "div") (typ @-> typ @-> returning typ)
    and add_finalizer = add_finalizer in
    fun x y -> add_finalizer (div x y)

  let sub =
    let%map sub = foreign (prefix "sub") (typ @-> typ @-> returning typ)
    and add_finalizer = add_finalizer in
    fun x y -> add_finalizer (sub x y)

  let mut_add = foreign (prefix "mut_add") (typ @-> typ @-> returning void)

  let mut_mul = foreign (prefix "mut_mul") (typ @-> typ @-> returning void)

  let mut_square = foreign (prefix "mut_square") (typ @-> returning void)

  let mut_sub = foreign (prefix "mut_sub") (typ @-> typ @-> returning void)

  let copy = foreign (prefix "copy") (typ @-> typ @-> returning void)

  let rng =
    let%map rng = foreign (prefix "rng") (int @-> returning typ)
    and add_finalizer = add_finalizer in
    fun i -> add_finalizer (rng i)

  let print = foreign (prefix "print") (typ @-> returning void)

  let equal = foreign (prefix "equal") (typ @-> typ @-> returning bool)

  let to_bigint =
    let%map to_bigint =
      foreign (prefix "to_bigint") (typ @-> returning Bigint.typ)
    and add_finalizer = Bigint.add_finalizer in
    fun x -> add_finalizer (to_bigint x)

  let of_bigint =
    let%map of_bigint =
      foreign (prefix "of_bigint") (Bigint.typ @-> returning typ)
    and add_finalizer = add_finalizer in
    fun x -> add_finalizer (of_bigint x)

  let to_bigint_raw =
    let%map to_bigint_raw =
      foreign (prefix "to_bigint_raw") (typ @-> returning Bigint.typ)
    and add_finalizer = Bigint.add_finalizer in
    fun x -> add_finalizer (to_bigint_raw x)

  let to_bigint_raw_noalloc =
    let%map to_bigint_raw_noalloc =
      foreign (prefix "to_bigint_raw_noalloc") (typ @-> returning Bigint.typ)
    in
    fun x ->
      let finalize _y =
        (* Hold a reference to [x] so that it doesn't get GC'd and deleted
           until this is also freed.
        *)
        ignore x
      in
      let y = to_bigint_raw_noalloc x in
      Caml.Gc.finalise finalize y ;
      y

  let of_bigint_raw =
    let%map of_bigint_raw =
      foreign (prefix "of_bigint_raw") (Bigint.typ @-> returning typ)
    and add_finalizer = add_finalizer in
    fun x -> add_finalizer (of_bigint_raw x)

  module Vector = struct
    module T =
      Vector
        (F)
        (struct
          let prefix = prefix
        end)
        (T)

    include T
    module Triple = Triple (F) (T) (T)
  end

  module Constraint_matrix = struct
    open F
    open F.Let_syntax

    module T : Type = struct
      type t = unit ptr

      let typ = ptr void
    end

    include T

    let prefix = with_prefix (prefix "constraint_matrix")

    let delete = foreign (prefix "delete") (typ @-> returning void)

    let add_finalizer =
      F.map delete ~f:(fun delete x ->
          Caml.Gc.finalise (bind_return ~f:delete) x ;
          x )

    (* Stub out delete to make sure we don't attempt to double-free. *)
    let delete : t -> unit = ignore

    let create =
      let%map create = foreign (prefix "create") (void @-> returning typ)
      and add_finalizer = add_finalizer in
      fun () -> add_finalizer (create ())

    let append_row =
      foreign (prefix "append_row")
        (typ @-> Usize_vector.typ @-> Vector.typ @-> returning void)
  end
end

module Plonk_gate_vector
    (F : Cstubs_applicative.Foreign_applicative)
    (P : Prefix)
    (Field_vector : Type) =
struct
  open F
  open F.Let_syntax

  let prefix = with_prefix (P.prefix "circuit_gate_vector")

  include (
    struct
        type t = unit ptr

        let typ = ptr void
      end :
      Type )

  let delete = foreign (prefix "delete") (typ @-> returning void)

  let add_finalizer =
    F.map delete ~f:(fun delete x ->
        Caml.Gc.finalise (bind_return ~f:delete) x ;
        x )

  (* Stub out delete to make sure we don't attempt to double-free. *)
  let delete : t -> unit = ignore

  let create =
    let%map create = foreign (prefix "create") (void @-> returning typ)
    and add_finalizer = add_finalizer in
    fun () -> add_finalizer (create ())

  let length = foreign (prefix "length") (typ @-> returning int)

  let push_gate gate_name =
    let%map push_gate =
      foreign
        (prefix (Printf.sprintf "push_%s" gate_name))
        ( typ @-> size_t @-> size_t @-> size_t @-> size_t @-> size_t @-> size_t
        @-> Field_vector.typ @-> returning void )
    in
    fun t ~l_index ~l_permutation ~r_index ~r_permutation ~o_index
        ~o_permutation v ->
      push_gate t l_index l_permutation r_index r_permutation o_index
        o_permutation v

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
    (F : Cstubs_applicative.Foreign_applicative)
    (P : Prefix)
    (Plonk_gate_vector : Type) =
struct
  open F
  open F.Let_syntax

  include (
    struct
        type t = unit ptr

        let typ = ptr void
      end :
      Type )

  let prefix = with_prefix (P.prefix "constraint_system")

  let delete = foreign (prefix "delete") (typ @-> returning void)

  let add_finalizer =
    F.map delete ~f:(fun delete x ->
        Caml.Gc.finalise (bind_return ~f:delete) x ;
        x )

  (* Stub out delete to make sure we don't attempt to double-free. *)
  let delete : t -> unit = ignore

  let create =
    let%map create =
      foreign (prefix "create")
        (Plonk_gate_vector.typ @-> size_t @-> returning typ)
    and add_finalizer = add_finalizer in
    fun v public -> add_finalizer (create v public)
end

module Full (F : Cstubs_applicative.Foreign_applicative) = struct
  let zexe = with_prefix "zexe"

  module Bigint256 =
    Bigint
      (F)
      (struct
        let prefix = with_prefix (zexe "bigint256")
      end)

  module Bigint384 =
    Bigint
      (F)
      (struct
        let prefix = with_prefix (zexe "bigint384")
      end)

  module Usize_vector =
    Vector
      (F)
      (struct
        let prefix = with_prefix (zexe "usize")
      end)
      (struct
        type t = Unsigned.size_t

        let typ = size_t

        let add_finalizer = F.return Fn.id
      end)

  module Dlog_proof_system (Field : sig
    include
      Prefix_type_with_finalizer
      with type 'a result := 'a F.result
       and type 'a return := 'a F.return

    module Vector : sig
      include
        Prefix_type_with_finalizer
        with type 'a result := 'a F.result
         and type 'a return := 'a F.return

      module Triple :
        Type_with_finalizer
        with type 'a result := 'a F.result
         and type 'a return := 'a F.return
    end

    module Constraint_matrix : Type
  end) (Curve : sig
    include
      Prefix_type_with_finalizer
      with type 'a result := 'a F.result
       and type 'a return := 'a F.return

    module Affine : sig
      module Underlying : Type

      include
        Type_with_finalizer
        with type 'a result := 'a F.result
         and type 'a return := 'a F.return
         and type t = Underlying.t ptr

      module Vector :
        Type_with_finalizer
        with type 'a result := 'a F.result
         and type 'a return := 'a F.return

      module Pair : sig
        include Type

        module Vector :
          Type_with_finalizer
          with type 'a result := 'a F.result
           and type 'a return := 'a F.return
      end
    end
  end) =
  struct
    let prefix = Field.prefix

    module Field_triple = Triple (F) (Field) (Field)

    module Field_opening_proof =
      Dlog_opening_proof
        (F)
        (struct
          let prefix = with_prefix (prefix "opening_proof")
        end)
        (Field)
        (Curve.Affine)

    module Field_poly_comm =
      Dlog_poly_comm
        (F)
        (struct
          let prefix = with_prefix (prefix "poly_comm")
        end)
        (Curve.Affine)

    module Field_urs = struct
      let prefix = with_prefix (prefix "urs")

      include (
        struct
            type t = unit ptr

            let typ = ptr void
          end :
          Type )

      open F
      open F.Let_syntax

      let delete = foreign (prefix "delete") (typ @-> returning void)

      let add_finalizer =
        F.map delete ~f:(fun delete x ->
            Caml.Gc.finalise (bind_return ~f:delete) x ;
            x )

      (* Stub out delete to make sure we don't attempt to double-free. *)
      let delete : t -> unit = ignore

      let create =
        let%map create =
          foreign (prefix "create")
            (size_t @-> size_t @-> size_t @-> returning typ)
        and add_finalizer = add_finalizer in
        fun depth public size -> add_finalizer (create depth public size)

      let read =
        let%map read = foreign (prefix "read") (string @-> returning typ)
        and add_finalizer = add_finalizer in
        fun path -> add_finalizer (read path)

      let write = foreign (prefix "write") (typ @-> string @-> returning void)

      let lagrange_commitment =
        let%map lagrange_commitment =
          foreign
            (prefix "lagrange_commitment")
            (typ @-> size_t @-> size_t @-> returning Field_poly_comm.typ)
        and add_finalizer = Field_poly_comm.add_finalizer in
        fun urs domain_size i ->
          add_finalizer (lagrange_commitment urs domain_size i)

      let commit_evaluations =
        let%map commit_evaluations =
          foreign
            (prefix "commit_evaluations")
            ( typ @-> size_t @-> Field.Vector.typ
            @-> returning Field_poly_comm.typ )
        and add_finalizer = Field_poly_comm.add_finalizer in
        fun urs domain_size evals ->
          add_finalizer (commit_evaluations urs domain_size evals)

      let h =
        let%map h = foreign (prefix "h") (typ @-> returning Curve.Affine.typ)
        and add_finalizer = Curve.Affine.add_finalizer in
        fun t -> add_finalizer (h t)

      let batch_accumulator_check =
        foreign
          (prefix "batch_accumulator_check")
          ( typ @-> Curve.Affine.Vector.typ @-> Field.Vector.typ
          @-> returning bool )

      let b_poly_commitment =
        let%map b_poly_commitment =
          foreign
            (prefix "b_poly_commitment")
            (typ @-> Field.Vector.typ @-> returning Field_poly_comm.typ)
        and add_finalizer = Field_poly_comm.add_finalizer in
        fun urs chals -> add_finalizer (b_poly_commitment urs chals)
    end

    module Field_index =
      Index
        (F)
        (struct
          let prefix = with_prefix (prefix "index")
        end)
        (Field.Constraint_matrix)
        (Field_poly_comm)
        (Field_urs)

    module Field_verifier_index = struct
      include VerifierIndex
                (F)
                (struct
                  let prefix = with_prefix (prefix "verifier_index")
                end)
                (Field_index)
                (Field_urs)
                (Field_poly_comm)

      open F
      open F.Let_syntax

      let read =
        let%map read =
          foreign (prefix "read") (Field_urs.typ @-> string @-> returning typ)
        and add_finalizer = add_finalizer in
        fun urs path -> add_finalizer (read urs path)
    end

    module Field_proof =
      Dlog_marlin_proof
        (F)
        (struct
          let prefix = with_prefix (prefix "proof")
        end)
        (Curve.Affine)
        (Field)
        (Field_index)
        (Field_verifier_index)
        (Field.Vector)
        (Field.Vector.Triple)
        (Field_opening_proof)
        (Field_poly_comm)

    module Field_oracles =
      Dlog_oracles
        (F)
        (struct
          let prefix = with_prefix (prefix "oracles")
        end)
        (Field)
        (Field_verifier_index)
        (Field_proof)
        (Field.Vector.Triple)
  end

  module Plonk_dlog_proof_system
      (P : Prefix) (Field : sig
          include
            Prefix_type_with_finalizer
            with type 'a result := 'a F.result
             and type 'a return := 'a F.return

          module Vector : sig
            include
              Prefix_type_with_finalizer
              with type 'a result := 'a F.result
               and type 'a return := 'a F.return

            module Triple :
              Type_with_finalizer
              with type 'a result := 'a F.result
               and type 'a return := 'a F.return
          end
      end) (Curve : sig
        include Prefix_type

        module Affine : sig
          module Underlying : Type

          include
            Type_with_finalizer
            with type 'a result := 'a F.result
             and type 'a return := 'a F.return
             and type t = Underlying.t ptr

          module Vector :
            Type_with_finalizer
            with type 'a result := 'a F.result
             and type 'a return := 'a F.return

          module Pair : sig
            include
              Type_with_finalizer
              with type 'a result := 'a F.result
               and type 'a return := 'a F.return

            module Vector :
              Type_with_finalizer
              with type 'a result := 'a F.result
               and type 'a return := 'a F.return
          end
        end
      end) =
  struct
    let prefix = Field.prefix

    module Field_triple = Triple (F) (Field) (Field)

    module Field_opening_proof =
      Dlog_opening_proof
        (F)
        (struct
          let prefix = with_prefix (P.prefix "opening_proof")
        end)
        (Field)
        (Curve.Affine)

    module Field_poly_comm =
      Dlog_poly_comm
        (F)
        (struct
          let prefix = with_prefix (prefix "poly_comm")
        end)
        (Curve.Affine)

    module Field_urs = struct
      let prefix = with_prefix (prefix "urs")

      include (
        struct
            type t = unit ptr

            let typ = ptr void
          end :
          Type )

      open F
      open F.Let_syntax

      let delete = foreign (prefix "delete") (typ @-> returning void)

      let add_finalizer =
        F.map delete ~f:(fun delete x ->
            Caml.Gc.finalise (bind_return ~f:delete) x ;
            x )

      (* Stub out delete to make sure we don't attempt to double-free. *)
      let delete : t -> unit = ignore

      let create =
        let%map create =
          foreign (prefix "create")
            (size_t @-> size_t @-> size_t @-> returning typ)
        and add_finalizer = add_finalizer in
        fun depth public size -> add_finalizer (create depth public size)

      let read =
        let%map read = foreign (prefix "read") (string @-> returning typ)
        and add_finalizer = add_finalizer in
        fun path -> add_finalizer (read path)

      let write = foreign (prefix "write") (typ @-> string @-> returning void)

      let lagrange_commitment =
        let%map lagrange_commitment =
          foreign
            (prefix "lagrange_commitment")
            (typ @-> size_t @-> size_t @-> returning Field_poly_comm.typ)
        and add_finalizer = Field_poly_comm.add_finalizer in
        fun urs domain_size i ->
          add_finalizer (lagrange_commitment urs domain_size i)

      let commit_evaluations =
        let%map commit_evaluations =
          foreign
            (prefix "commit_evaluations")
            ( typ @-> size_t @-> Field.Vector.typ
            @-> returning Field_poly_comm.typ )
        and add_finalizer = Field_poly_comm.add_finalizer in
        fun urs domain_size evals ->
          add_finalizer (commit_evaluations urs domain_size evals)

      let h =
        let%map h = foreign (prefix "h") (typ @-> returning Curve.Affine.typ)
        and add_finalizer = Curve.Affine.add_finalizer in
        fun urs -> add_finalizer (h urs)

      let batch_accumulator_check =
        foreign
          (prefix "batch_accumulator_check")
          ( typ @-> Curve.Affine.Vector.typ @-> Field.Vector.typ
          @-> returning bool )

      let b_poly_commitment =
        let%map b_poly_commitment =
          foreign
            (prefix "b_poly_commitment")
            (typ @-> Field.Vector.typ @-> returning Field_poly_comm.typ)
        and add_finalizer = Field_poly_comm.add_finalizer in
        fun urs chals -> add_finalizer (b_poly_commitment urs chals)
    end

    module Gate_vector = Plonk_gate_vector (F) (P) (Field.Vector)
    module Constraint_system = Plonk_constraint_system (F) (P) (Gate_vector)

    module Field_index =
      Plonk_index
        (F)
        (struct
          let prefix = with_prefix (P.prefix "index")
        end)
        (Constraint_system)
        (Field_poly_comm)
        (Field_urs)

    module Field_verifier_index =
      PlonkVerifierIndex
        (F)
        (struct
          let prefix = with_prefix (P.prefix "verifier_index")
        end)
        (Field_index)
        (Field_urs)
        (Field_poly_comm)
        (Field)

    module Field_proof =
      Dlog_plonk_proof
        (F)
        (struct
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

    module Field_oracles =
      Dlog_oracles
        (F)
        (struct
          let prefix = with_prefix (prefix "oracles")
        end)
        (Field)
        (Field_verifier_index)
        (Field_proof)
        (Field.Vector.Triple)
  end

  module Tweedle = struct
    let prefix = with_prefix (zexe "tweedle")

    module Fp =
      Field
        (F)
        (struct
          let prefix = with_prefix (prefix "fp")
        end)
        (Bigint256)
        (Usize_vector)

    module Fq =
      Field
        (F)
        (struct
          let prefix = with_prefix (prefix "fq")
        end)
        (Bigint256)
        (Usize_vector)

    module Dum = struct
      module Field = Fq

      module Curve =
        Curve
          (F)
          (struct
            let prefix = with_prefix (prefix "dum")
          end)
          (Fp)
          (Fq)

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
        Curve
          (F)
          (struct
            let prefix = with_prefix (prefix "dee")
          end)
          (Fq)
          (Fp)

      module Plonk =
        Plonk_dlog_proof_system (struct
            let prefix = with_prefix (prefix "plonk_fp")
          end)
          (Field)
          (Curve)

      include Dlog_proof_system (Field) (Curve)
    end

    module Endo = struct
      let endo typ add_finalizer which =
        let open F in
        let open F.Let_syntax in
        let%map endo = foreign (prefix which) (void @-> returning typ)
        and add_finalizer = add_finalizer in
        fun () -> add_finalizer (endo ())

      module Dee = struct
        let base = endo Fq.typ Fq.add_finalizer "fp_endo_base"

        let scalar = endo Fp.typ Fp.add_finalizer "fp_endo_scalar"
      end

      module Dum = struct
        let base = endo Fp.typ Fp.add_finalizer "fq_endo_base"

        let scalar = endo Fq.typ Fq.add_finalizer "fq_endo_scalar"
      end
    end
  end

  module Bn382 = struct
    let prefix = with_prefix (zexe "bn382")

    module Fp =
      Field
        (F)
        (struct
          let prefix = with_prefix (prefix "fp")
        end)
        (Bigint384)
        (Usize_vector)

    module Fq =
      Field
        (F)
        (struct
          let prefix = with_prefix (prefix "fq")
        end)
        (Bigint384)
        (Usize_vector)

    module G =
      Curve
        (F)
        (struct
          let prefix = with_prefix (prefix "g")
        end)
        (Fp)
        (Fq)

    module G1 =
      Curve
        (F)
        (struct
          let prefix = with_prefix (prefix "g1")
        end)
        (Fq)
        (Fp)

    module Fp_urs = struct
      let prefix = with_prefix (prefix "fp_urs")

      include URS
                (F)
                (struct
                  let prefix = prefix
                end)
                (G1.Affine)
                (Fp.Vector)

      open F
      open F.Let_syntax

      let dummy_opening_check =
        let%map dummy_opening_check =
          foreign
            (prefix "dummy_opening_check")
            (typ @-> returning G1.Affine.Pair.typ)
        and add_finalizer = G1.Affine.Pair.add_finalizer in
        fun t -> add_finalizer (dummy_opening_check t)

      let dummy_degree_bound_checks =
        let%map dummy_degree_bound_checks =
          foreign
            (prefix "dummy_degree_bound_checks")
            (typ @-> Usize_vector.typ @-> returning G1.Affine.Vector.typ)
        and add_finalizer = G1.Affine.Vector.add_finalizer in
        fun t v -> add_finalizer (dummy_degree_bound_checks t v)
    end

    module Fp_index =
      Index
        (F)
        (struct
          let prefix = with_prefix (prefix "fp_index")
        end)
        (Fp.Constraint_matrix)
        (G1.Affine)
        (Fp_urs)

    module Fp_verifier_index = struct
      include VerifierIndex
                (F)
                (struct
                  let prefix = with_prefix (prefix "fp_verifier_index")
                end)
                (Fp_index)
                (Fp_urs)
                (G1.Affine)

      open F
      open F.Let_syntax

      let read =
        let%map read = foreign (prefix "read") (string @-> returning typ)
        and add_finalizer = add_finalizer in
        fun path -> add_finalizer (read path)
    end

    module Fp_proof =
      Pairing_marlin_proof
        (F)
        (struct
          let prefix = with_prefix (prefix "fp_proof")
        end)
        (G1.Affine)
        (Fp)
        (Fp_index)
        (Fp_verifier_index)
        (Fp.Vector)

    module Fp_oracles =
      Pairing_oracles
        (F)
        (struct
          let prefix = with_prefix (prefix "fp_oracles")
        end)
        (Fp)
        (Fp_verifier_index)
        (Fp_proof)

    module Fq_triple = Triple (F) (Fq) (Fq)

    module Fq_opening_proof =
      Dlog_opening_proof
        (F)
        (struct
          let prefix = with_prefix (prefix "fq_opening_proof")
        end)
        (Fq)
        (G.Affine)

    module Fq_poly_comm =
      Dlog_poly_comm
        (F)
        (struct
          let prefix = with_prefix (prefix "fq_poly_comm")
        end)
        (G.Affine)

    module Fq_urs = struct
      let prefix = with_prefix (prefix "fq_urs")

      include (
        struct
            type t = unit ptr

            let typ = ptr void
          end :
          Type )

      open F
      open F.Let_syntax

      let delete = foreign (prefix "delete") (typ @-> returning void)

      let add_finalizer =
        F.map delete ~f:(fun delete x ->
            Caml.Gc.finalise (bind_return ~f:delete) x ;
            x )

      (* Stub out delete to make sure we don't attempt to double-free. *)
      let delete : t -> unit = ignore

      let create =
        let%map create =
          foreign (prefix "create")
            (size_t @-> size_t @-> size_t @-> returning typ)
        and add_finalizer = add_finalizer in
        fun depth public size -> add_finalizer (create depth public size)

      let read =
        let%map read = foreign (prefix "read") (string @-> returning typ)
        and add_finalizer = add_finalizer in
        fun path -> add_finalizer (read path)

      let write = foreign (prefix "write") (typ @-> string @-> returning void)

      let lagrange_commitment =
        let%map lagrange_commitment =
          foreign
            (prefix "lagrange_commitment")
            (typ @-> size_t @-> size_t @-> returning Fq_poly_comm.typ)
        and add_finalizer = Fq_poly_comm.add_finalizer in
        fun urs domain_size i ->
          add_finalizer (lagrange_commitment urs domain_size i)

      let commit_evaluations =
        let%map commit_evaluations =
          foreign
            (prefix "commit_evaluations")
            (typ @-> size_t @-> Fq.Vector.typ @-> returning Fq_poly_comm.typ)
        and add_finalizer = Fq_poly_comm.add_finalizer in
        fun urs domain_size evals ->
          add_finalizer (commit_evaluations urs domain_size evals)

      let h =
        let%map h = foreign (prefix "h") (typ @-> returning G.Affine.typ)
        and add_finalizer = G.Affine.add_finalizer in
        fun urs -> add_finalizer (h urs)

      let b_poly_commitment =
        let%map b_poly_commitment =
          foreign
            (prefix "b_poly_commitment")
            (typ @-> Fq.Vector.typ @-> returning Fq_poly_comm.typ)
        and add_finalizer = Fq_poly_comm.add_finalizer in
        fun urs chals -> add_finalizer (b_poly_commitment urs chals)
    end

    module Fq_index =
      Index
        (F)
        (struct
          let prefix = with_prefix (prefix "fq_index")
        end)
        (Fq.Constraint_matrix)
        (Fq_poly_comm)
        (Fq_urs)

    module Fq_verifier_index = struct
      include VerifierIndex
                (F)
                (struct
                  let prefix = with_prefix (prefix "fq_verifier_index")
                end)
                (Fq_index)
                (Fq_urs)
                (Fq_poly_comm)

      open F
      open F.Let_syntax

      let read =
        let%map read =
          foreign (prefix "read") (Fq_urs.typ @-> string @-> returning typ)
        and add_finalizer = add_finalizer in
        fun urs path -> add_finalizer (read urs path)
    end

    module Fq_proof =
      Dlog_marlin_proof
        (F)
        (struct
          let prefix = with_prefix (prefix "fq_proof")
        end)
        (G.Affine)
        (Fq)
        (Fq_index)
        (Fq_verifier_index)
        (Fq.Vector)
        (Fq.Vector.Triple)
        (Fq_opening_proof)
        (Fq_poly_comm)

    module Fq_oracles =
      Dlog_oracles
        (F)
        (struct
          let prefix = with_prefix (prefix "fq_oracles")
        end)
        (Fq)
        (Fq_verifier_index)
        (Fq_proof)
        (Fq.Vector.Triple)

    module Endo = struct
      let endo typ add_finalizer which =
        let open F in
        let open F.Let_syntax in
        let%map endo = foreign (prefix which) (void @-> returning typ)
        and add_finalizer = add_finalizer in
        fun () -> add_finalizer (endo ())

      module Pairing = struct
        let base = endo Fq.typ Fq.add_finalizer "fp_endo_base"

        let scalar = endo Fp.typ Fp.add_finalizer "fp_endo_scalar"
      end

      module Dlog = struct
        let base = endo Fp.typ Fp.add_finalizer "fq_endo_base"

        let scalar = endo Fq.typ Fq.add_finalizer "fq_endo_scalar"
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
