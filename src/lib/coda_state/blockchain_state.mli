open Core_kernel
open Coda_base
open Fold_lib
open Tuple_lib
open Snark_params.Tick

module Poly : sig
  type ('staged_ledger_hash, 'snarked_ledger_hash, 'time) t =
    { staged_ledger_hash: 'staged_ledger_hash
    ; snarked_ledger_hash: 'snarked_ledger_hash
    ; timestamp: 'time }
  [@@deriving sexp, eq, compare, fields, yojson]

  module Stable :
    sig
      module V1 : sig
        type ('staged_ledger_hash, 'snarked_ledger_hash, 'time) t
        [@@deriving bin_io, sexp, eq, compare, yojson, version]
      end

      module Latest : module type of V1
    end
    with type ('staged_ledger_hash, 'snarked_ledger_hash, 'time) V1.t =
                ('staged_ledger_hash, 'snarked_ledger_hash, 'time) t
end

module Value : sig
  module Stable : sig
    module V1 : sig
      type t =
        ( Staged_ledger_hash.Stable.V1.t
        , Frozen_ledger_hash.Stable.V1.t
        , Block_time.Stable.V1.t )
        Poly.Stable.V1.t
      [@@deriving bin_io, sexp, eq, compare, hash, yojson, version]
    end

    module Latest : module type of V1
  end

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

val length_in_triples : int

val negative_one : Value.t Lazy.t

val genesis : Value.t Lazy.t

val set_timestamp : ('a, 'b, 'c) Poly.t -> 'c -> ('a, 'b, 'c) Poly.t

val fold : Value.t -> bool Triple.t Fold.t

val var_to_triples : var -> (Boolean.var Triple.t list, _) Checked.t

type display = (string, string, string) Poly.t [@@deriving yojson]

val display : Value.t -> display
