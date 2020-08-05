open Core_kernel
open Coda_base

module Poly = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
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
      [@@deriving bin_io, to_yojson, sexp, fields, version]
    end
  end]

  type ( 'blockchain_state
       , 'consensus_transition
       , 'amount
       , 'producer_pk
       , 'pending_coinbase_action )
       t =
        ( 'blockchain_state
        , 'consensus_transition
        , 'amount
        , 'producer_pk
        , 'pending_coinbase_action )
        Stable.Latest.t =
    { blockchain_state: 'blockchain_state
    ; consensus_transition: 'consensus_transition
    ; coinbase_receiver: 'producer_pk
    ; coinbase_amount: 'amount
    ; pending_coinbase_action: 'pending_coinbase_action }
  [@@deriving sexp, to_yojson, fields, hlist]
end

module Value = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        ( Blockchain_state.Value.Stable.V1.t
        , Consensus.Data.Consensus_transition.Value.Stable.V1.t
        , Currency.Amount.Stable.V1.t
        , Signature_lib.Public_key.Compressed.Stable.V1.t
        , Pending_coinbase.Update.Action.Stable.V1.t )
        Poly.Stable.V1.t
      [@@deriving sexp, to_yojson]

      let to_latest = Fn.id
    end
  end]

  type t = Stable.Latest.t [@@deriving to_yojson, sexp]
end

[%%define_locally
Poly.
  ( blockchain_state
  , consensus_transition
  , coinbase_receiver
  , coinbase_amount
  , pending_coinbase_action
  , to_hlist
  , of_hlist )]

type value = Value.t

type var =
  ( Blockchain_state.var
  , Consensus.Data.Consensus_transition.var
  , Currency.Amount.var
  , Signature_lib.Public_key.Compressed.var
  , Pending_coinbase.Update.Action.var )
  Poly.t

let create_value ~blockchain_state ~consensus_transition ~coinbase_receiver
    ~coinbase_amount ~pending_coinbase_action () : Value.t =
  { blockchain_state
  ; consensus_transition
  ; coinbase_receiver
  ; coinbase_amount
  ; pending_coinbase_action }

let genesis ~constraint_constants ~genesis_ledger : value =
  let genesis_ledger = Lazy.force genesis_ledger in
  { Poly.blockchain_state=
      Blockchain_state.genesis ~constraint_constants
        ~genesis_ledger_hash:(Ledger.merkle_root genesis_ledger)
        ~snarked_next_available_token:
          (Ledger.next_available_token genesis_ledger)
  ; consensus_transition= Consensus.Data.Consensus_transition.genesis
  ; coinbase_receiver= Signature_lib.Public_key.Compressed.empty
  ; coinbase_amount= Currency.Amount.zero
  ; pending_coinbase_action= Pending_coinbase.Update.Action.Update_none }

let typ =
  let open Snark_params.Tick.Typ in
  of_hlistable ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
    ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist
    [ Blockchain_state.typ
    ; Consensus.Data.Consensus_transition.typ
    ; Signature_lib.Public_key.Compressed.typ
    ; Currency.Amount.typ
    ; Pending_coinbase.Update.Action.typ ]
