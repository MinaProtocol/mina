(* location_intf.ml -- interface file for Location *)

open Core

module type S = sig
  module Addr : module type of Merkle_address

  module Prefix : sig
    val generic : Unsigned.UInt8.t

    val account : Unsigned.UInt8.t

    val hash : ledger_depth:int -> int -> Unsigned.UInt8.t
  end

  type t = Generic of Bigstring.t | Account of Addr.t | Hash of Addr.t
  [@@deriving eq, sexp, hash, compare]

  val is_generic : t -> bool

  val is_account : t -> bool

  val is_hash : t -> bool

  val height : ledger_depth:int -> t -> int

  val root_hash : t

  val last_direction : Addr.t -> Direction.t

  val build_generic : Bigstring.t -> t

  val parse : ledger_depth:int -> Bigstring.t -> (t, unit) Result.t

  val prefix_bigstring : Unsigned.UInt8.t -> Bigstring.t -> Bigstring.t

  val to_path_exn : t -> Addr.t

  val serialize : ledger_depth:int -> t -> Bigstring.t

  val parent : t -> t

  val next : t -> t Option.t

  val prev : t -> t Option.t

  val sibling : t -> t

  val order_siblings : t -> 'a -> 'a -> 'a * 'a

  module Set : Set.S with type Elt.t = t
end
