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

  type window_table

  type scalar_field

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
    type t = curve array
  end

  val local_function :
    negate:('a -> 'a) -> add:('a -> 'a -> 'a) -> bool Triple.t -> 'a -> 'a

  module State : sig
    type t

    val create : ?triples_consumed:int -> ?init:curve -> unit -> t

    val update_fold_chunked : t -> bool Triple.t Fold.t -> t
    (** use precomputed table of curve values *)

    val update_fold_unchunked : t -> bool Triple.t Fold.t -> t
    (** compute hash one triple at a time *)

    val update_fold : t -> bool Triple.t Fold.t -> t
    (** dispatches to chunked or unchunked (default) version *)

    val set_chunked_fold : bool -> unit
    (** use chunked folding iff b; called by daemon startup to use chunked version *)

    val digest : t -> Digest.t

    val triples_consumed : t -> int

    val acc : t -> curve

    val salt : string -> t

    val acc_of_sections :
         [`Acc of curve * int | `Data of bool Triple.t Fold.t | `Skip of int]
         list
      -> curve
  end

  val hash_fold : State.t -> bool Triple.t Fold.t -> State.t

  val digest_fold : State.t -> bool Triple.t Fold.t -> Digest.t
end

module Make (Inputs : Pedersen_inputs_intf.S) :
  S
  with type curve := Inputs.Curve.t
   and type window_table := Inputs.Curve.Window_table.t
   and type scalar_field := Inputs.Scalar_field.t
   and type Digest.t = Inputs.Field.t
