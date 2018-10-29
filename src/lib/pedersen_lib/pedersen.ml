open Core_kernel
open Fold_lib
open Tuple_lib

module type S = sig
  type curve

  module Digest : sig
    type t [@@deriving bin_io, sexp, eq]

    val fold_bits : t -> bool Fold.t

    val fold : t -> bool Triple.t Fold.t

    val ( = ) : t -> t -> bool
  end

  module Params : sig
    type t = curve array
  end

  module State : sig
    type t = {triples_consumed: int; acc: curve; params: Params.t}

    val create : ?triples_consumed:int -> ?init:curve -> Params.t -> t

    val update_fold : t -> bool Triple.t Fold.t -> t

    val digest : t -> Digest.t

    val salt : Params.t -> string -> t
  end

  val hash_fold : State.t -> bool Triple.t Fold.t -> State.t

  val digest_fold : State.t -> bool Triple.t Fold.t -> Digest.t
end

module Make (Field : sig
  type t [@@deriving sexp, bin_io, eq]

  val fold_bits : t -> bool Fold.t

  val fold : t -> bool Triple.t Fold.t
end) (Curve : sig
  type t [@@deriving sexp]

  val to_affine_coordinates : t -> Field.t * Field.t

  val zero : t

  val ( + ) : t -> t -> t

  val negate : t -> t
end) : S with type curve := Curve.t and type Digest.t = Field.t = struct
  module Digest = struct
    type t = Field.t [@@deriving sexp, bin_io, eq]

    let fold_bits = Field.fold_bits

    let fold = Field.fold

    let ( = ) = equal
  end

  module Params = struct
    type t = Curve.t array
  end

  module State = struct
    type t = {triples_consumed: int; acc: Curve.t; params: Params.t}

    let create ?(triples_consumed = 0) ?(init = Curve.zero) params =
      {acc= init; triples_consumed; params}

    let local_function params i triple =
      let g = params.(i) in
      let a0, a1, sign = triple in
      let res =
        match (a0, a1) with
        | false, false -> g
        | true, false -> Curve.(g + g)
        | false, true -> Curve.(g + g + g)
        | true, true ->
            let gg = Curve.(g + g) in
            Curve.(gg + gg)
      in
      if sign then Curve.negate res else res

    let update_fold (t : t) (fold : bool Triple.t Fold.t) =
      let params = t.params in
      let acc, triples_consumed =
        fold.fold ~init:(t.acc, t.triples_consumed) ~f:(fun (acc, i) triple ->
            let term = local_function params i triple in
            (Curve.(acc + term), i + 1) )
      in
      {t with acc; triples_consumed}

    let digest t =
      let x, _y = Curve.to_affine_coordinates t.acc in
      x

    let salt params s = update_fold (create params) (Fold.string_triples s)
  end

  let hash_fold s fold = State.update_fold s fold

  let digest_fold s fold = State.digest (hash_fold s fold)
end
