(* The account of the Mesa era, as precomputed blocks list it in
   [accounts_accessed]. *)

open Core_kernel
module Public_key = Signature_lib.Public_key

[%%versioned
module Stable = struct
  module V3 = struct
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
      ; zkapp : Zkapp_account.Stable.V3.t option
      }
    [@@deriving equal, sexp, yojson]

    let to_latest = Fn.id
  end
end]

let to_current
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
      Stable.V3.t ) : Mina_base.Account.Stable.Latest.t =
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
  ; zkapp = Option.map zkapp ~f:Zkapp_account.to_current
  }
