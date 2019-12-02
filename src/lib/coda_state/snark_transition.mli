open Core_kernel
open Coda_base

module Poly : sig
  type ( 'blockchain_state
       , 'consensus_transition
       , 'sok_digest
       , 'amount
       , 'proposer_pk )
       t =
    { blockchain_state: 'blockchain_state
    ; consensus_transition: 'consensus_transition
    ; sok_digest: 'sok_digest
    ; supply_increase: 'amount
    ; ledger_proof: Proof.Stable.V1.t option
    ; proposer: 'proposer_pk
    ; coinbase_amount: 'amount }
  [@@deriving sexp, fields]

  module Stable :
    sig
      module V1 : sig
        type ( 'blockchain_state
             , 'consensus_transition
             , 'sok_digest
             , 'amount
             , 'proposer_pk )
             t
        [@@deriving bin_io, sexp, version]
      end

      module Latest : module type of V1
    end
    with type ( 'blockchain_state
              , 'consensus_transition
              , 'sok_digest
              , 'amount
              , 'proposer_pk )
              V1.t =
                ( 'blockchain_state
                , 'consensus_transition
                , 'sok_digest
                , 'amount
                , 'proposer_pk )
                t
end

module Value : sig
  module Stable : sig
    module V1 : sig
      type t =
        ( Blockchain_state.Value.Stable.V1.t
        , Consensus.Data.Consensus_transition.Value.Stable.V1.t
        , Sok_message.Digest.Stable.V1.t
        , Currency.Amount.Stable.V1.t
        , Signature_lib.Public_key.Compressed.Stable.V1.t )
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
  , Sok_message.Digest.Checked.t
  , Currency.Amount.var
  , Signature_lib.Public_key.Compressed.var )
  Poly.t

include
  Snark_params.Tick.Snarkable.S with type value := Value.t and type var := var

val create_value :
     ?sok_digest:Sok_message.Digest.t
  -> ?ledger_proof:Proof.t
  -> supply_increase:Currency.Amount.t
  -> blockchain_state:Blockchain_state.Value.t
  -> consensus_transition:Consensus.Data.Consensus_transition.Value.Stable.V1.t
  -> proposer:Signature_lib.Public_key.Compressed.t
  -> coinbase_amount:Currency.Amount.t
  -> unit
  -> Value.t

val genesis : genesis_ledger:Ledger.t Lazy.t -> Value.t Lazy.t

val blockchain_state :
  ('blockchain_state, _, _, _, _) Poly.t -> 'blockchain_state

val consensus_transition :
  (_, 'consensus_transition, _, _, _) Poly.t -> 'consensus_transition

val sok_digest : (_, _, 'sok_digest, _, _) Poly.t -> 'sok_digest

val supply_increase : (_, _, _, 'amount, _) Poly.t -> 'amount

val coinbase_amount : (_, _, _, 'amount, _) Poly.t -> 'amount

val ledger_proof : _ Poly.t -> Proof.t option

val proposer : (_, _, _, _, 'proposer_pk) Poly.t -> 'proposer_pk
