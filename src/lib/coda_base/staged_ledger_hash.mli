open Core
open Fold_lib
open Tuple_lib
open Snark_params.Tick

type t [@@deriving bin_io, sexp, eq, compare, hash]

include Hashable_binable with type t := t

type value [@@deriving bin_io, sexp, eq, compare, hash]

type var

val var_of_t : t -> var

(*val value_of_t : t -> value*)

val typ : (var, t) Typ.t

val var_to_triples : var -> (Boolean.var Triple.t list, _) Checked.t

val length_in_triples : int

val fold : t -> bool Triple.t Fold.t

val genesis : t

module Stable : sig
  module V1 : sig
    type nonrec t = t [@@deriving bin_io, sexp, eq, compare, hash]

    include Hashable_binable with type t := t
  end

  module Latest : module type of V1
end

module Aux_hash : sig
  type t

  module Stable : sig
    module V1 : sig
      type nonrec t = t [@@deriving bin_io, sexp, eq, compare, hash]
    end

    module Latest : module type of V1
  end

  val of_bytes : string -> t

  val to_bytes : t -> string

  val dummy : t
end

(*module Pending_coinbase_extra : sig
  type t

  module Stable : sig
    module V1 : sig
      type nonrec t = t [@@deriving bin_io, sexp, eq, compare, hash]
    end

    module Latest : module type of V1
  end

  val of_bytes : string -> t

  val to_bytes : t -> string

  val dummy : t
end*)

val ledger_hash : t -> Ledger_hash.t

val aux_hash : t -> Aux_hash.t

val pending_coinbase_hash : t -> Pending_coinbase.Hash.t

val pending_coinbase_hash_var : var -> Pending_coinbase.Hash.var

val of_aux_ledger_and_coinbase_hash :
  Aux_hash.t -> Ledger_hash.t -> Pending_coinbase.t -> t
