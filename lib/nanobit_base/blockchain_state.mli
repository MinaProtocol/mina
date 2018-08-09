open Core_kernel
open Coda_numbers
open Snark_params
open Tick

type ( 'target
     , 'state_hash
     , 'ledger_builder_hash
     , 'ledger_hash
     , 'strength
     , 'length
     , 'time
     , 'signer_public_key ) t_ =
  { next_difficulty: 'target
  ; previous_state_hash: 'state_hash
  ; ledger_builder_hash: 'ledger_builder_hash
  ; ledger_hash: 'ledger_hash
  ; strength: 'strength
  ; length: 'length
  ; timestamp: 'time
  ; signer_public_key: 'signer_public_key }
[@@deriving fields]

type t =
  ( Target.t
  , State_hash.t
  , Ledger_builder_hash.t
  , Ledger_hash.t
  , Strength.t
  , Length.t
  , Block_time.t
  , Public_key.Compressed.t )
  t_
[@@deriving sexp, eq]

module Stable : sig
  module V1 : sig
    type nonrec ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t_ =
                                                     ( 'a
                                                     , 'b
                                                     , 'c
                                                     , 'd
                                                     , 'e
                                                     , 'f
                                                     , 'g
                                                     , 'h )
                                                     t_ =
      { next_difficulty: 'a
      ; previous_state_hash: 'b
      ; ledger_builder_hash: 'c
      ; ledger_hash: 'd
      ; strength: 'e
      ; length: 'f
      ; timestamp: 'g
      ; signer_public_key: 'h }
    [@@deriving bin_io, sexp, eq]

    type nonrec t =
      ( Target.Stable.V1.t
      , State_hash.Stable.V1.t
      , Ledger_builder_hash.Stable.V1.t
      , Ledger_hash.Stable.V1.t
      , Strength.Stable.V1.t
      , Length.Stable.V1.t
      , Block_time.Stable.V1.t
      , Public_key.Compressed.Stable.V1.t )
      t_
    [@@deriving bin_io, sexp, eq]
  end
end

include Snarkable.S
        with type var =
                    ( Target.Unpacked.var
                    , State_hash.var
                    , Ledger_builder_hash.var
                    , Ledger_hash.var
                    , Strength.Unpacked.var
                    , Length.Unpacked.var
                    , Block_time.Unpacked.var
                    , Public_key.Compressed.var )
                    t_
         and type value = t

module Hash = State_hash

val fold : t -> init:'acc -> f:('acc -> bool -> 'acc) -> 'acc

val to_bits : var -> (Boolean.var list, _) Checked.t

val to_bits_unchecked : t -> bool list

val hash : t -> Hash.t
