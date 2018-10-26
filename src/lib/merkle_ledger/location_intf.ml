(* location_intf.ml -- interface file for Location *)

open Core

module type S = sig
  module Addr : Merkle_address.S

  module Prefix : sig
    val generic : Unsigned.UInt8.t

    val account : Unsigned.UInt8.t

    val hash : int -> Unsigned.UInt8.t
  end

  type t = Generic of Bigstring.t | Account of Addr.t | Hash of Addr.t

  include Hashable.S with type t := t

  val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

  val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

  val is_generic : t -> bool

  val is_account : t -> bool

  val is_hash : t -> bool

  val height : t -> int

  val root_hash : t

  val last_direction : Addr.t -> Direction.t

  val build_generic : Bigstring.t -> t

  val parse : Bigstring.t -> (t, unit) Result.t

  val prefix_bigstring : Unsigned.UInt8.t -> Bigstring.t -> Bigstring.t

  val to_path_exn : t -> Addr.t

  val serialize : t -> Bigstring.t

  val parent : t -> t

  val next : t -> t Option.t

  val sibling : t -> t

  val order_siblings : t -> 'a -> 'a -> 'a * 'a
end
