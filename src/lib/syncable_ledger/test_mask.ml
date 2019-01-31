open Core

(* Input for testing the interaction between merkle *)

module Make (Input : sig
  val depth : int

  val mask_layers : int
end) =
struct
  open Merkle_ledger_tests.Test_stubs

  module Hash = struct
    type t = Hash.t [@@deriving sexp, hash, compare, bin_io, eq]

    type account = Account.t

    let merge = Hash.merge

    let hash_account = Hash.hash_account

    let to_hash = Fn.id

    let empty_account = hash_account Account.empty
  end

  module Maskable_and_mask =
    Merkle_ledger_tests.Test_mask.Make_maskable_and_mask_with_depth (Input)

  module L = struct
    open Merkle_ledger_tests.Test_stubs
    module Base_db = Maskable_and_mask.Base_db
    module Any_base = Maskable_and_mask.Any_base
    module Base = Any_base.M
    module Mask = Maskable_and_mask.Mask
    module Maskable = Maskable_and_mask.Maskable
    include Mask.Attached

    (* Each account for a layer of a mask will all have the same balance.
    Specifically, the top most layer will have a balance of `balance` and
    every layer afterwards will have it's balance doubled *)
    let load_ledger num_accounts (balance : int) : t * 'a =
      let db = Base_db.create () in
      let maskable = Any_base.cast (module Base_db) db in
      let keys = Key.gen_keys num_accounts in
      (* All the parents will have certain values *)
      let initial_balance_multiplier = (1 lsl Input.mask_layers) * balance in
      List.iter keys ~f:(fun key ->
          let account =
            Account.create key
              (Currency.Balance.of_int (initial_balance_multiplier * 2))
          in
          let action, _ =
            Maskable.get_or_create_account_exn maskable key account
          in
          assert (action = `Added) ) ;
      let mask = Mask.create () in
      let attached_mask = Maskable.register_mask maskable mask in
      (* On the mask, all the children will have different values *)
      let rec construct_layered_masks iter child_balance parent_mask =
        if iter = 0 then (
          assert (balance = child_balance) ;
          parent_mask )
        else
          let parent_base = Any_base.cast (module Mask.Attached) parent_mask in
          let child_mask = Mask.create () in
          let attached_mask = Maskable.register_mask parent_base child_mask in
          List.iter keys ~f:(fun key ->
              let account =
                Account.create key (Currency.Balance.of_int child_balance)
              in
              let action, location =
                Mask.Attached.get_or_create_account_exn attached_mask key
                  account
              in
              match action with
              | `Existed -> Mask.Attached.set attached_mask location account
              | `Added -> failwith "Expected to re-use an existing account" ) ;
          construct_layered_masks (iter - 1) (child_balance / 2) attached_mask
      in
      ( construct_layered_masks Input.mask_layers initial_balance_multiplier
          attached_mask
      , keys )

    type addr = Addr.t

    type account = Account.t

    type hash = Hash.t
  end

  module Root_hash = Hash

  module SL =
    Syncable_ledger.Make (L.Addr) (Account) (Hash) (Hash) (L)
      (struct
        let subtree_height = 3
      end)

  module Hi :
    sig
      type merkle_tree
    end
    with type merkle_tree := L.t =
    SL

  module SR = SL.Responder
end
