open Core_kernel
open Coda_base

module Poly : sig
  type ( 'blockchain_state
       , 'consensus_transition
       , 'amount
       , 'producer_pk
       , 'pending_coinbase_action )
       t =
    { blockchain_state: 'blockchain_state
    ; consensus_transition: 'consensus_transition
    ; coinbase_receiver: 'producer_pk
    ; coinbase_amount: 'amount
    ; pending_coinbase_action: 'pending_coinbase_action }
  [@@deriving sexp, fields]

  module Stable :
    sig
      module V1 : sig
        type ( 'blockchain_state
             , 'consensus_transition
             , 'amount
             , 'producer_pk
             , 'pending_coinbase_action )
             t
        [@@deriving bin_io, sexp, version]
      end

      module Latest : module type of V1
    end
    with type ( 'blockchain_state
              , 'consensus_transition
              , 'amount
              , 'producer_pk
              , 'pending_coinbase_action )
              V1.t =
                ( 'blockchain_state
                , 'consensus_transition
                , 'amount
                , 'producer_pk
                , 'pending_coinbase_action )
                t
end

module Value : sig
  module Stable : sig
    module V1 : sig
      type t =
        ( Blockchain_state.Value.Stable.V1.t
        , Consensus.Data.Consensus_transition.Value.Stable.V1.t
        , Currency.Amount.Stable.V1.t
        , Signature_lib.Public_key.Compressed.Stable.V1.t
        , Pending_coinbase.Update.Action.Stable.V1.t )
        Poly.Stable.V1.t
      [@@deriving bin_io, sexp, to_yojson, version]
    end

    module Latest : module type of V1
  end

  type t = Stable.Latest.t [@@deriving to_yojson, sexp]
end

type value = Value.t

type var =
  ( Blockchain_state.var
  , Consensus.Data.Consensus_transition.var
  , Currency.Amount.var
  , Signature_lib.Public_key.Compressed.var
  , Pending_coinbase.Update.Action.var )
  Poly.t

include
  Snark_params.Tick.Snarkable.S with type value := Value.t and type var := var

val create_value :
     blockchain_state:Blockchain_state.Value.t
  -> consensus_transition:Consensus.Data.Consensus_transition.Value.Stable.V1.t
  -> coinbase_receiver:Signature_lib.Public_key.Compressed.t
  -> coinbase_amount:Currency.Amount.t
  -> pending_coinbase_action:Pending_coinbase.Update.Action.t
  -> unit
  -> Value.t

val genesis :
     constraint_constants:Genesis_constants.Constraint_constants.t
  -> genesis_ledger:Ledger.t Lazy.t
  -> Value.t

val consensus_transition :
  (_, 'consensus_transition, _, _, _) Poly.t -> 'consensus_transition

val coinbase_amount : (_, _, 'amount, _, _) Poly.t -> 'amount

val coinbase_receiver : (_, _, _, 'producer_pk, _) Poly.t -> 'producer_pk

val pending_coinbase_action :
  (_, _, _, _, 'pending_coinbase_action) Poly.t -> 'pending_coinbase_action

val blockchain_state :
  ('blockchain_state, _, _, _, _) Poly.t -> 'blockchain_state
