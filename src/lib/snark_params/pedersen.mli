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
    type t [@@deriving bin_io, sexp, eq, hash, compare, yojson]

    (* TODO: assert versioned, for now *)
    val __versioned__ : bool

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
    [%%if fake_hash]

    type t = {triples_consumed: int; acc: curve; ctx: Digestif.SHA256.ctx}

    [%%else]

    type t = {triples_consumed: int; acc: curve}

    [%%endif]

    val create : ?triples_consumed:int -> ?init:curve -> unit -> t

    (** use precomputed table of curve values *)
    val update_fold_chunked : t -> bool Triple.t Fold.t -> t

    (** compute hash one triple at a time *)
    val update_fold_unchunked : t -> bool Triple.t Fold.t -> t

    (** dispatches to chunked or unchunked (default) version *)
    val update_fold : t -> bool Triple.t Fold.t -> t

    (** use chunked folding iff b; called by daemon startup to use chunked version *)
    val set_chunked_fold : bool -> unit

    val digest : t -> Digest.t

    val salt : string -> t
  end

  val hash_fold : State.t -> bool Triple.t Fold.t -> State.t

  val digest_fold : State.t -> bool Triple.t Fold.t -> Digest.t
end

module Make (Inputs : Pedersen_inputs_intf.S) :
  S with type curve := Inputs.Curve.t and type Digest.t = Inputs.Field.t
