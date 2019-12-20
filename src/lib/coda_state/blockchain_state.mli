open Core_kernel
open Coda_base
open Snark_params.Tick

module Poly : sig
  [%%versioned:
  module Stable : sig
    module V1 : sig
      type ('staged_ledger_hash, 'snarked_ledger_hash, 'time) t =
        { staged_ledger_hash: 'staged_ledger_hash
        ; snarked_ledger_hash: 'snarked_ledger_hash
        ; timestamp: 'time }
      [@@deriving sexp, eq, compare, yojson]
    end
  end]

  type ('staged_ledger_hash, 'snarked_ledger_hash, 'time) t =
        ('staged_ledger_hash, 'snarked_ledger_hash, 'time) Stable.Latest.t =
    { staged_ledger_hash: 'staged_ledger_hash
    ; snarked_ledger_hash: 'snarked_ledger_hash
    ; timestamp: 'time }
  [@@deriving sexp, eq, compare, fields, yojson]
end

module Value : sig
  [%%versioned:
  module Stable : sig
    module V1 : sig
      type t =
        ( Staged_ledger_hash.Stable.V1.t
        , Frozen_ledger_hash.Stable.V1.t
        , Block_time.Stable.V1.t )
        Poly.Stable.V1.t
      [@@deriving sexp, eq, compare, hash, yojson]
    end
  end]

  type t = Stable.Latest.t [@@deriving sexp, eq, compare, hash, yojson]
end

include
  Snarkable.S
  with type var =
              ( Staged_ledger_hash.var
              , Frozen_ledger_hash.var
              , Block_time.Unpacked.var )
              Poly.t
   and type value := Value.t

val staged_ledger_hash :
  ('staged_ledger_hash, _, _) Poly.t -> 'staged_ledger_hash

val snarked_ledger_hash :
  (_, 'snarked_ledger_hash, _) Poly.t -> 'snarked_ledger_hash

val timestamp : (_, _, 'time) Poly.t -> 'time

val create_value :
     staged_ledger_hash:Staged_ledger_hash.t
  -> snarked_ledger_hash:Frozen_ledger_hash.t
  -> timestamp:Block_time.t
  -> Value.t

val negative_one : genesis_ledger_hash:Ledger_hash.t -> Value.t

val genesis : genesis_ledger_hash:Ledger_hash.t -> Value.t

val set_timestamp : ('a, 'b, 'c) Poly.t -> 'c -> ('a, 'b, 'c) Poly.t

val to_input : Value.t -> (Field.t, bool) Random_oracle.Input.t

val var_to_input : var -> (Field.Var.t, Boolean.var) Random_oracle.Input.t

type display = (string, string, string) Poly.t [@@deriving yojson]

val display : Value.t -> display
