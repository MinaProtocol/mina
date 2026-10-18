(** {1 Scale Round State}

    This module defines the state for one round of variable-base scalar
    multiplication (VarBaseMul gate).

    In standard (non-endomorphism) scalar multiplication, we use a
    double-and-add algorithm. Each round processes multiple bits of the
    scalar, accumulating the result.

    {3 See also}

    - {!Plonk_constraint.EC_scale} for the constraint using this type
    - [kimchi/src/circuits/polynomials/varbasemul.rs] for Rust impl *)

open Core_kernel

(** Round state for variable-base scalar multiplication.

    Each round performs double-and-add operations for multiple bits,
    updating accumulated points and the scalar accumulator.

    Type parameter ['a] is the field element type. *)
type 'a t =
  { accs : ('a * 'a) array
        (** Accumulated points: (x, y) pairs for intermediate results *)
  ; bits : 'a array  (** Scalar bits being processed in this round *)
  ; ss : 'a array  (** Slopes for the point additions *)
  ; base : 'a * 'a  (** Base point (x, y) being multiplied *)
  ; n_prev : 'a  (** Accumulated scalar value before this round *)
  ; n_next : 'a  (** Accumulated scalar value after this round *)
  }
[@@deriving sexp, fields, hlist]

let map { accs; bits; ss; base; n_prev; n_next } ~f =
  { accs = Array.map accs ~f:(fun (x, y) -> (f x, f y))
  ; bits = Array.map bits ~f
  ; ss = Array.map ss ~f
  ; base = (f (fst base), f (snd base))
  ; n_prev = f n_prev
  ; n_next = f n_next
  }

let map2 t1 t2 ~f =
  { accs =
      Array.map (Array.zip_exn t1.accs t2.accs) ~f:(fun ((x1, y1), (x2, y2)) ->
          (f x1 x2, f y1 y2) )
  ; bits =
      Array.map (Array.zip_exn t1.bits t2.bits) ~f:(fun (x1, x2) -> f x1 x2)
  ; ss = Array.map (Array.zip_exn t1.ss t2.ss) ~f:(fun (x1, x2) -> f x1 x2)
  ; base = (f (fst t1.base) (fst t2.base), f (snd t1.base) (snd t2.base))
  ; n_prev = f t1.n_prev t2.n_prev
  ; n_next = f t1.n_next t2.n_next
  }

let fold { accs; bits; ss; base; n_prev; n_next } ~f ~init =
  let t = Array.fold accs ~init ~f:(fun acc (x, y) -> f [ x; y ] acc) in
  let t = Array.fold bits ~init:t ~f:(fun acc x -> f [ x ] acc) in
  let t = Array.fold ss ~init:t ~f:(fun acc x -> f [ x ] acc) in
  let t = f [ fst base; snd base ] t in
  let t = f [ n_prev ] t in
  let t = f [ n_next ] t in
  t
