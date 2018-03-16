open Core
open Snark_params
open Snarky
open Tick

type t = private Pedersen.Digest.t
[@@deriving sexp]

module Stable : sig
  module V1 : sig
    type nonrec t = t
    [@@deriving bin_io, sexp]
  end
end

type var

val typ : (var, t) Typ.t

type path = Pedersen.Digest.t list

type _ Request.t +=
  | Get_path    : Account.Index.t -> path Request.t
  | Set         : Account.Index.t * Account.t -> unit Request.t
  | Empty_entry : (Account.Index.t * path) Request.t
  | Find_index  : Public_key.Compressed.t -> Account.Index.t Request.t

val assert_equal : var -> var -> (unit, _) Checked.t

val modify_account
  : var
  -> Public_key.Compressed.var
  -> f:(Account.var -> (Account.var, 's) Checked.t)
  -> (var, 's) Checked.t

val create_account
  : var
  -> Public_key.Compressed.var
  -> (var, _) Checked.t

val var_to_bits : var -> (Boolean.var list, _) Checked.t
