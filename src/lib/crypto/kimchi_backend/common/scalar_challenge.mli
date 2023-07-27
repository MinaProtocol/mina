module Stable : sig
  module V2 : sig
    type 'f t = 'f Kimchi_types.scalar_challenge = { inner : 'f }

    (* pickles required *)
    val to_yojson : ('f -> Yojson.Safe.t) -> 'f t -> Yojson.Safe.t

    (* pickles required *)
    val of_yojson :
         (Yojson.Safe.t -> 'f Ppx_deriving_yojson_runtime.error_or)
      -> Yojson.Safe.t
      -> 'f t Ppx_deriving_yojson_runtime.error_or

    (* pickles required *)
    val bin_shape_t : Bin_prot.Shape.t -> Bin_prot.Shape.t

    (* pickles required *)
    val bin_size_t : 'f Bin_prot.Size.sizer -> 'f t Bin_prot.Size.sizer

    (* pickles required *)
    val bin_write_t : 'f Bin_prot.Write.writer -> 'f t Bin_prot.Write.writer

    (* pickles required *)
    val bin_read_t : 'f Bin_prot.Read.reader -> 'f t Bin_prot.Read.reader

    (* pickles required *)
    val __versioned__ : unit

    (* pickles required *)
    val t_of_sexp :
      (Ppx_sexp_conv_lib.Sexp.t -> 'f) -> Ppx_sexp_conv_lib.Sexp.t -> 'f t

    (* pickles required *)
    val sexp_of_t :
         ('weak5 -> Ppx_sexp_conv_lib.Sexp.t)
      -> 'weak5 t
      -> Ppx_sexp_conv_lib.Sexp.t

    (* pickles required *)
    val compare : ('f -> 'f -> int) -> 'f t -> 'f t -> int

    (* pickles required *)
    val equal : ('f -> 'f -> bool) -> 'f t -> 'f t -> bool

    (* pickles required *)
    val hash_fold_t :
         (Base_internalhash_types.state -> 'f -> Base_internalhash_types.state)
      -> Base_internalhash_types.state
      -> 'f t
      -> Base_internalhash_types.state
  end

  (* pickles required *)
  module Latest = V2
end

(* pickles required *)
type 'f t = 'f Kimchi_types.scalar_challenge = { inner : 'f }

(* pickles required *)
val to_yojson : ('f -> Yojson.Safe.t) -> 'f t -> Yojson.Safe.t

(* pickles required *)
val of_yojson :
     (Yojson.Safe.t -> 'f Ppx_deriving_yojson_runtime.error_or)
  -> Yojson.Safe.t
  -> 'f t Ppx_deriving_yojson_runtime.error_or

(* pickles required *)
val t_of_sexp :
  (Ppx_sexp_conv_lib.Sexp.t -> 'f) -> Ppx_sexp_conv_lib.Sexp.t -> 'f t

(* pickles required *)
val sexp_of_t :
  ('f -> Ppx_sexp_conv_lib.Sexp.t) -> 'f t -> Ppx_sexp_conv_lib.Sexp.t

(* pickles required *)
val compare : ('f -> 'f -> int) -> 'f t -> 'f t -> int

(* pickles required *)
val equal : ('f -> 'f -> bool) -> 'f t -> 'f t -> bool

(* pickles required *)
val hash_fold_t :
     (Base_internalhash_types.state -> 'f -> Base_internalhash_types.state)
  -> Base_internalhash_types.state
  -> 'f t
  -> Base_internalhash_types.state

(* pickles required *)
val create : 'a -> 'a t

(* pickles required *)
val typ :
     ('a, 'b, 'c) Snarky_backendless.Typ.t
  -> ('a t, 'b t, 'c) Snarky_backendless.Typ.t

(* pickles required *)
val map : 'a t -> f:('a -> 'b) -> 'b t
