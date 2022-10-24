open Core_kernel
open Snark_params.Step

type t [@@deriving sexp, equal, compare, hash, yojson]

include Hashable with type t := t

type value [@@deriving sexp, equal, compare, hash]

type var

val var_of_t : t -> var

val typ : (var, t) Typ.t

val var_to_input : var -> Field.Var.t Random_oracle.Input.Chunked.t

val to_input : t -> Field.t Random_oracle.Input.Chunked.t

val genesis :
     constraint_constants:Genesis_constants.Constraint_constants.t
  -> genesis_ledger_hash:Ledger_hash.t
  -> t

module Stable : sig
  module V1 : sig
    type nonrec t = t
    [@@deriving bin_io, sexp, equal, compare, hash, yojson, version]
  end

  module Latest : module type of V1
end

module Aux_hash : sig
  type t

  module Stable : sig
    module V1 : sig
      type nonrec t = t
      [@@deriving bin_io, sexp, equal, compare, hash, yojson, version]
    end

    module Latest : module type of V1
  end

  val of_bytes : string -> t

  val to_bytes : t -> string

  val to_base58_check : t -> string

  val of_base58_check_exn : string -> t

  val dummy : t
end

module Pending_coinbase_aux : sig
  type t

  module Stable : sig
    module V1 : sig
      type nonrec t = t
      [@@deriving bin_io, sexp, equal, compare, hash, yojson, version]
    end

    module Latest : module type of V1
  end

  val to_base58_check : t -> string

  val of_base58_check_exn : string -> t

  val dummy : t
end

val ledger_hash : t -> Ledger_hash.t

val aux_hash : t -> Aux_hash.t

val pending_coinbase_aux : t -> Pending_coinbase_aux.t

val pending_coinbase_hash : t -> Pending_coinbase.Hash.t

val pending_coinbase_hash_var : var -> Pending_coinbase.Hash.var

val of_aux_ledger_and_coinbase_hash :
  Aux_hash.t -> Ledger_hash.t -> Pending_coinbase.t -> t
