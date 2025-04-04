(** Any_ledger lets you use any arbitrary ledger whenever some ledger is
 * required. This uses dynamic dispatch and is equivalent to the notion of
 * consuming a value conforming to an interface in Java.
 *
 * It uses GADTs to type-erase the specific underlying first-class module
 * for some given signature and delegates all function calls.
 *
 * The restriction here is that one cannot conform to some signature that
 * exposes a `create` function because we can't magically pull a conforming
 * module out of thin air. However, one can always just pack any concrete
 * instance with the GADT constructor `witness`.
 *
 * Props to @nholland for showing me this trick.
 * *)

module Make_base (Inputs : Intf.Inputs.Intf) :
  Intf.Ledger.ANY
    with module Location = Inputs.Location
    with type key := Inputs.Key.t
     and type token_id := Inputs.Token_id.t
     and type token_id_set := Inputs.Token_id.Set.t
     and type account_id := Inputs.Account_id.t
     and type hash := Inputs.Hash.t
     and type account_id_set := Inputs.Account_id.Set.t
     and type account := Inputs.Account.t = struct
  open Inputs
  module Location = Location

  module type Base_intf =
    Intf.Ledger.S
      with module Addr = Location.Addr
      with module Location = Location
      with type key := Inputs.Key.t
       and type token_id := Inputs.Token_id.t
       and type token_id_set := Inputs.Token_id.Set.t
       and type account_id := Account_id.t
       and type account_id_set := Account_id.Set.t
       and type hash := Hash.t
       and type root_hash := Hash.t
       and type account := Account.t

  type witness = T : (module Base_intf with type t = 't) * 't -> witness

  let cast (m : (module Base_intf with type t = 'a)) (t : 'a) = T (m, t)

  (** M can be used wherever a base ledger is demanded, construct instances
   * by using the witness constructor directly
   *
   * We delegate to the underlying functions in the base interface mechanically
   *
   * In the future, this should be a `ppx`.
   *)
  module M : Base_intf with type t = witness = struct
    type t = witness

    type index = int

    module Location = Location
    module Path = Merkle_path.Make (Hash)

    type path = Path.t

    module Addr = Location.Addr

    let merkle_path_at_index_exn (T ((module Base), t)) =
      Base.merkle_path_at_index_exn t

    let merkle_path (T ((module Base), t)) = Base.merkle_path t

    let merkle_path_batch (T ((module Base), t)) = Base.merkle_path_batch t

    let wide_merkle_path_batch (T ((module Base), t)) =
      Base.wide_merkle_path_batch t

    let merkle_root (T ((module Base), t)) = Base.merkle_root t

    let get_hash_batch_exn (T ((module Base), t)) = Base.get_hash_batch_exn t

    let index_of_account_exn (T ((module Base), t)) =
      Base.index_of_account_exn t

    let set_at_index_exn (T ((module Base), t)) = Base.set_at_index_exn t

    let get_at_index_exn (T ((module Base), t)) = Base.get_at_index_exn t

    let set_batch ?hash_cache (T ((module Base), t)) =
      Base.set_batch ?hash_cache t

    let set (T ((module Base), t)) = Base.set t

    let get (T ((module Base), t)) = Base.get t

    let get_batch (T ((module Base), t)) = Base.get_batch t

    let get_uuid (T ((module Base), t)) = Base.get_uuid t

    let get_directory (T ((module Base), t)) = Base.get_directory t

    let last_filled (T ((module Base), t)) = Base.last_filled t

    let close (T ((module Base), t)) = Base.close t

    let get_or_create_account (T ((module Base), t)) =
      Base.get_or_create_account t

    let location_of_account (T ((module Base), t)) = Base.location_of_account t

    let location_of_account_batch (T ((module Base), t)) =
      Base.location_of_account_batch t

    let fold_until (T ((module Base), t)) = Base.fold_until t

    let accounts (T ((module Base), t)) = Base.accounts t

    let token_owner (T ((module Base), t)) tid = Base.token_owner t tid

    let tokens (T ((module Base), t)) pk = Base.tokens t pk

    let token_owners (T ((module Base), t)) = Base.token_owners t

    let iteri (T ((module Base), t)) = Base.iteri t

    (* ignored_keys must be Base.Keys.Set.t, but that isn't necessarily the same as Keys.Set.t for the
       Keys passed to this functor; as long as we use the same Keys for all ledgers, this should work
    *)
    let foldi_with_ignored_accounts (T ((module Base), t)) =
      Base.foldi_with_ignored_accounts t

    let foldi (T ((module Base), t)) = Base.foldi t

    let to_list (T ((module Base), t)) = Base.to_list t

    let to_list_sequential (T ((module Base), t)) = Base.to_list_sequential t

    let get_all_accounts_rooted_at_exn (T ((module Base), t)) =
      Base.get_all_accounts_rooted_at_exn t

    let set_all_accounts_rooted_at_exn (T ((module Base), t)) =
      Base.set_all_accounts_rooted_at_exn t

    let set_batch_accounts (T ((module Base), t)) = Base.set_batch_accounts t

    let get_inner_hash_at_addr_exn (T ((module Base), t)) =
      Base.get_inner_hash_at_addr_exn t

    let merkle_path_at_addr_exn (T ((module Base), t)) =
      Base.merkle_path_at_addr_exn t

    let num_accounts (T ((module Base), t)) = Base.num_accounts t

    (* This better be the same depth inside Base or you're going to have a bad
     * time *)
    let depth (T ((module Base), t)) = Base.depth t

    let detached_signal (T ((module Base), t)) = Base.detached_signal t
  end
end
