open Core_kernel
open Coda_base
open Snark_params.Tick

module Poly : sig
  [%%versioned:
  module Stable : sig
    module V1 : sig
      type ('staged_ledger_hash, 'snarked_ledger_hash, 'token_id, 'time) t =
        { staged_ledger_hash: 'staged_ledger_hash
        ; snarked_ledger_hash: 'snarked_ledger_hash
        ; snarked_next_available_token: 'token_id
        ; timestamp: 'time }
      [@@deriving sexp, eq, compare, yojson]
    end
  end]

  type ('staged_ledger_hash, 'snarked_ledger_hash, 'token_id, 'time) t =
        ( 'staged_ledger_hash
        , 'snarked_ledger_hash
        , 'token_id
        , 'time )
        Stable.Latest.t =
    { staged_ledger_hash: 'staged_ledger_hash
    ; snarked_ledger_hash: 'snarked_ledger_hash
    ; snarked_next_available_token: 'token_id
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
        , Token_id.Stable.V1.t
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
              , Token_id.var
              , Block_time.Unpacked.var )
              Poly.t
   and type value := Value.t

val staged_ledger_hash :
  ('staged_ledger_hash, _, _, _) Poly.t -> 'staged_ledger_hash

val snarked_ledger_hash :
  (_, 'snarked_ledger_hash, _, _) Poly.t -> 'snarked_ledger_hash

val snarked_next_available_token : (_, _, 'token_id, _) Poly.t -> 'token_id

val timestamp : (_, _, _, 'time) Poly.t -> 'time

val create_value :
     staged_ledger_hash:Staged_ledger_hash.t
  -> snarked_ledger_hash:Frozen_ledger_hash.t
  -> snarked_next_available_token:Token_id.t
  -> timestamp:Block_time.t
  -> Value.t

val negative_one :
     constraint_constants:Genesis_constants.Constraint_constants.t
  -> genesis_ledger_hash:Ledger_hash.t
  -> snarked_next_available_token:Token_id.t
  -> Value.t

val genesis :
     constraint_constants:Genesis_constants.Constraint_constants.t
  -> genesis_ledger_hash:Ledger_hash.t
  -> snarked_next_available_token:Token_id.t
  -> Value.t

val set_timestamp :
     ('staged_ledger_hash, 'snarked_ledger_hash, 'token_id, 'time) Poly.t
  -> 'time
  -> ('staged_ledger_hash, 'snarked_ledger_hash, 'token_id, 'time) Poly.t

val to_input : Value.t -> (Field.t, bool) Random_oracle.Input.t

val var_to_input :
  var -> ((Field.Var.t, Boolean.var) Random_oracle.Input.t, _) Checked.t

type display = (string, string, string, string) Poly.t [@@deriving yojson]

val display : Value.t -> display
