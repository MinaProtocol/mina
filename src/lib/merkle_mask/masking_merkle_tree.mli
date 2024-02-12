(** Implements a mask in front of a Merkle tree; see RFC 0004 and
    docs/specs/merkle_tree.md *)

(** Builds a Merkle tree mask.

    It's a Merkle tree, with some additional operations.
*)
module Make (I : Inputs_intf.S) :
  Masking_merkle_tree_intf.S
    with module Location = I.Location
     and type parent := I.Base.t
     and type key := I.Key.t
     and type token_id := I.Token_id.t
     and type token_id_set := I.Token_id.Set.t
     and type hash := I.Hash.t
     and type account := I.Account.t
     and type account_id := I.Account_id.t
     and type account_id_set := I.Account_id.Set.t
     and type location := I.Location.t
