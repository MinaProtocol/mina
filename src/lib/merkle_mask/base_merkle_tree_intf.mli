(* base_merkle_tree_intf.ml *)

(** base module type for masking and masked Merkle trees *)
module type S = sig
  type root_hash

  type hash

  type account

  type key

  type t

  module Location : Merkle_ledger.Intf.LOCATION

  module Token_id : Merkle_ledger.Intf.Token_id

  module Account_id :
    Merkle_ledger.Intf.Account_id
      with type key := key
       and type token_id := Token_id.t

  include
    Merkle_ledger.Intf.Ledger.S
      with type root_hash := root_hash
       and type hash := hash
       and type account := account
       and type key := key
       and type token_id := Token_id.t
       and type token_id_set := Token_id.Set.t
       and type account_id := Account_id.t
       and type account_id_set := Account_id.Set.t
       and type t := t
       and module Location := Location

  module Mask_accumulated : sig
    type t =
      { accounts : account Location.Map.t
      ; token_owners : Account_id.t Token_id.Map.t
      ; hashes : hash Location.Addr.Map.t
      ; locations : Location.t Account_id.Map.t
      ; non_existent_accounts : Account_id.Set.t
      }
  end
end
