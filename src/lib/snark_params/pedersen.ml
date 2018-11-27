open Core_kernel
open Snark_bits
open Fold_lib
open Tuple_lib

module type S = sig
  type curve

  type curve_vector

  module Digest : sig
    type t [@@deriving bin_io, sexp, eq, hash, compare]

    val size_in_bits : int

    val fold : t -> bool Triple.t Fold.t

    val ( = ) : t -> t -> bool

    module Bits : Bits_intf.S with type t := t

    module Snarkable (Impl : Snark_intf.S) :
      Impl.Snarkable.Bits.Lossy
      with type Packed.var = Impl.Field.Checked.t
       and type Packed.value = Impl.Field.t
       and type Unpacked.value = Impl.Field.t
  end

  module Params : sig
    type t = curve_vector
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
  type t [@@deriving sexp, bin_io, compare, hash]

  include Snarky.Field_intf.S with type t := t
end)
(Bigint : Snarky.Bigint_intf.Extended with type field := Field.t) (Curve : sig
    type t

    val to_coords : t -> Field.t * Field.t

    val zero : t

    val add : t -> t -> t

    val negate : t -> t

    module Vector : Snarky.Vector.S with type elt := t

    val pedersen_inner :
      params:Vector.t -> bits:Bytes.t -> start:int -> triples:int -> t
end) :
  S
  with type curve := Curve.t
   and type Digest.t = Field.t
   and type curve_vector := Curve.Vector.t = struct
  module Digest = struct
    type t = Field.t [@@deriving sexp, bin_io, compare, hash, eq]

    let size_in_bits = Field.size_in_bits

    let ( = ) = equal

    module Snarkable = Bits.Snarkable.Field
    module Bits = Bits.Make_field (Field) (Bigint)

    let fold t = Fold.group3 ~default:false (Bits.fold t)
  end

  module Params = struct
    type t = Curve.Vector.t
  end

  module State = struct
    type t = {triples_consumed: int; acc: Curve.t; params: Params.t}

    let create ?(triples_consumed = 0) ?(init = Curve.zero) params =
      {acc= init; triples_consumed; params}

    let update_fold (t : t) (fold : bool Triple.t Fold.t) =
      let params = t.params in
      let bs = Bitstring.create_bitstring (Curve.Vector.length params) in
      let triples_consumed_here =
        fold.fold ~init:0 ~f:(fun i (b0, b1, b2) ->
            Bitstring.(
              let i = i * 3 in
              put bs i (Bool.to_int b0) ;
              put bs (i + 1) (Bool.to_int b1) ;
              put bs (i + 2) (Bool.to_int b2)) ;
            i + 1 )
      in
      let bits, _, _ = bs in
      let acc =
        Curve.add t.acc
        @@ Curve.pedersen_inner ~params ~bits ~start:t.triples_consumed
             ~triples:triples_consumed_here
      in
      {t with acc; triples_consumed= t.triples_consumed + triples_consumed_here}

    let digest t =
      let x, _y = Curve.to_coords t.acc in
      x

    let salt params s = update_fold (create params) (Fold.string_triples s)
  end

  let hash_fold s fold = State.update_fold s fold

  let digest_fold s fold = State.digest (hash_fold s fold)
end
