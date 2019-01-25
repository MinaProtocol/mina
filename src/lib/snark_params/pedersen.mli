[%%import "../../config.mlh"]

open Core_kernel
open Snark_bits
open Fold_lib
open Tuple_lib

[%%if fake_hash]

open Coda_digestif

[%%endif]

module type S = sig
  type curve

  module Digest : sig
    type t [@@deriving bin_io, sexp, eq, hash, compare]

    val size_in_bits : int

    val fold : t -> bool Triple.t Fold.t

    val ( = ) : t -> t -> bool

    module Bits : Bits_intf.S with type t := t

    module Snarkable (Impl : Snark_intf.S) :
      Impl.Snarkable.Bits.Lossy
      with type Packed.var = Impl.Field.Var.t
       and type Packed.value = Impl.Field.t
       and type Unpacked.value = Impl.Field.t
  end

  module Params : sig
    type t = curve Quadruple.t array
  end

  module State : sig
    type chunk_table_fun = unit -> curve array array

    [%%if fake_hash]

    type t =
      { triples_consumed: int
      ; acc: curve
      ; params: Params.t
      ; ctx: Digestif.SHA256.ctx
      ; get_chunk_table: chunk_table_fun }
    [%%else]

    type t =
      { triples_consumed: int
      ; acc: curve
      ; params: Params.t
      ; get_chunk_table: chunk_table_fun }
    [%%endif]

    val create :
         ?triples_consumed:int
      -> ?init:curve
      -> Params.t
      -> get_chunk_table:chunk_table_fun
      -> t

    val update_fold_chunked : t -> bool Triple.t Fold.t -> t
    (** use precomputed table of curve values *)

    val update_fold_unchunked : t -> bool Triple.t Fold.t -> t
    (** compute hash one triple at a time *)

    val update_fold : t -> bool Triple.t Fold.t -> t
    (** dispatches to chunked or unchunked (default) version *)

    val set_chunked_fold : bool -> unit
    (** use chunked folding iff b; called by daemon startup to use chunked version *)

    val digest : t -> Digest.t

    val salt : Params.t -> get_chunk_table:chunk_table_fun -> string -> t
  end

  val hash_fold : State.t -> bool Triple.t Fold.t -> State.t

  val digest_fold : State.t -> bool Triple.t Fold.t -> Digest.t
end

module Make (Field : sig
  type t [@@deriving sexp, bin_io, compare, hash, eq]

  include Snarky.Field_intf.S with type t := t

  val project : bool list -> t
end)
(Bigint : Snarky.Bigint_intf.Extended with type field := Field.t) (Curve : sig
    type t

    val to_affine_coordinates : t -> Field.t * Field.t

    val zero : t

    val add : t -> t -> t

    val negate : t -> t
end) : S with type curve := Curve.t and type Digest.t = Field.t
