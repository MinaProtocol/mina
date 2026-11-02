(* The account of the Berkeley era, as precomputed blocks list it in
   [accounts_accessed]. It differs from the current account only in the length
   of its zkApp state. *)

open Core_kernel
module Public_key = Signature_lib.Public_key

module Zkapp_account = struct
  [%%versioned
  module Stable = struct
    module V2 = struct
      type t =
        ( Zkapp_state.Value.Stable.V1.t
        , Mina_base.Verification_key_wire.Stable.V1.t option
        , Mina_numbers.Zkapp_version.Stable.V1.t
        , Mina_base.Zkapp_basic.F.Stable.V1.t
        , Mina_numbers.Global_slot_since_genesis.Stable.V1.t
        , bool
        , Mina_base.Zkapp_account.Zkapp_uri.Stable.V1.t )
        Mina_base.Zkapp_account.Poly.Stable.V3.t
      [@@deriving equal, sexp, yojson]

      let to_latest = Fn.id
    end
  end]

  let to_mesa
      ({ app_state
       ; verification_key
       ; zkapp_version
       ; action_state
       ; last_action_slot
       ; proved_state
       ; zkapp_uri
       } :
        Stable.V2.t ) : Mina_base.Zkapp_account.Stable.Latest.t =
    { app_state = Zkapp_state.Value.to_mesa app_state
    ; verification_key
    ; zkapp_version
    ; action_state
    ; last_action_slot
    ; proved_state
    ; zkapp_uri
    }
end

[%%versioned
module Stable = struct
  module V2 = struct
    type t =
      { public_key : Public_key.Compressed.Stable.V1.t
      ; token_id : Mina_base.Token_id.Stable.V2.t
      ; token_symbol : Mina_base.Account.Token_symbol.Stable.V1.t
      ; balance : Currency.Balance.Stable.V1.t
      ; nonce : Mina_numbers.Account_nonce.Stable.V1.t
      ; receipt_chain_hash : Mina_base.Receipt.Chain_hash.Stable.V1.t
      ; delegate : Public_key.Compressed.Stable.V1.t option
      ; voting_for : Mina_base.State_hash.Stable.V1.t
      ; timing : Mina_base.Account.Timing.Stable.V2.t
      ; permissions : Mina_base.Permissions.Stable.V2.t
      ; zkapp : Zkapp_account.Stable.V2.t option
      }
    [@@deriving equal, sexp, yojson]

    let to_latest = Fn.id
  end
end]

(** Only the zkApp state changes. The Mesa hard fork also rescaled the timings
    of vesting accounts in the ledger, but the Mesa archive migration left the
    accounts already in the archive as they were, and so does this. *)
let to_mesa
    ({ public_key
     ; token_id
     ; token_symbol
     ; balance
     ; nonce
     ; receipt_chain_hash
     ; delegate
     ; voting_for
     ; timing
     ; permissions
     ; zkapp
     } :
      Stable.V2.t ) : Mina_base.Account.Stable.Latest.t =
  { public_key
  ; token_id
  ; token_symbol
  ; balance
  ; nonce
  ; receipt_chain_hash
  ; delegate
  ; voting_for
  ; timing
  ; permissions
  ; zkapp = Option.map zkapp ~f:Zkapp_account.to_mesa
  }
