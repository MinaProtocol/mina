open Core
open Signature_lib
open Merkle_ledger
open Mina_base

module Ledger_inner = struct
  module Location_at_depth : Merkle_ledger.Location_intf.S =
    Merkle_ledger.Location

  module Location_binable = struct
    module Arg = struct
      type t = Location_at_depth.t =
        | Generic of Mina_stdlib.Bigstring.Stable.Latest.t
        | Account of Location_at_depth.Addr.Stable.Latest.t
        | Hash of Location_at_depth.Addr.Stable.Latest.t
      [@@deriving bin_io_unversioned, hash, sexp, compare]
    end

    type t = Arg.t =
      | Generic of Mina_stdlib.Bigstring.t
      | Account of Location_at_depth.Addr.t
      | Hash of Location_at_depth.Addr.t
    [@@deriving hash, sexp, compare]

    include Comparable.Make_binable (Arg)
    include Hashable.Make_binable (Arg) [@@deriving sexp, compare, hash, yojson]
  end

  module Kvdb : Intf.Key_value_database with type config := string =
    Rocksdb.Database

  module Hash = struct
    module Arg = struct
      type t = Ledger_hash.Stable.Latest.t
      [@@deriving sexp, compare, hash, bin_io_unversioned]
    end

    module type Intf = sig
      type t [@@deriving sexp, of_sexp, hash, equal, compare, yojson]

      type account

      include Binable.S with type t := t

      include module type of Hashable.Make_binable (Arg)

      val to_base58_check : t -> string

      val merge : height:int -> t -> t -> t

      val hash_account : account -> t

      val empty_account : t
    end

    [%%versioned
    module Stable = struct
      module V1 = struct
        type t = Ledger_hash.Stable.V1.t
        [@@deriving sexp, compare, hash, equal, yojson]

        let (_ : (t, Arg.t) Type_equal.t) = Type_equal.T

        let to_latest = Fn.id

        include Hashable.Make_binable (Arg)

        let to_base58_check = Ledger_hash.to_base58_check

        let merge = Ledger_hash.merge

        let hash_account = Fn.compose Ledger_hash.of_digest Account.digest

        let empty_account =
          Ledger_hash.of_digest (Lazy.force Account.empty_digest)
      end
    end]

    module Unstable = struct
      type t = Ledger_hash.Stable.V1.t
      [@@deriving sexp, compare, hash, equal, yojson, bin_io_unversioned]

      include Hashable.Make_binable (Arg)

      let to_base58_check = Ledger_hash.to_base58_check

      let merge = Ledger_hash.merge

      let hash_account =
        Fn.compose Ledger_hash.of_digest Mina_base.Account.Unstable.digest

      let empty_account =
        Ledger_hash.of_digest (Lazy.force Account.Unstable.empty_digest)
    end

    module Hardfork = struct
      type t = Ledger_hash.Stable.V1.t
      [@@deriving sexp, compare, hash, equal, yojson, bin_io_unversioned]

      include Hashable.Make_binable (Arg)

      let to_base58_check = Ledger_hash.to_base58_check

      let merge = Ledger_hash.merge

      let hash_account =
        Fn.compose Ledger_hash.of_digest Mina_base.Account.Hardfork.digest

      let empty_account =
        Ledger_hash.of_digest (Lazy.force Account.Hardfork.empty_digest)
    end
  end

  module Account = struct
    module type Intf = sig
      type t [@@deriving sexp, of_sexp, equal, compare]

      include Binable.S with type t := t

      val balance : t -> Currency.Balance.t

      val empty : t

      val identifier : t -> Account_id.t

      val token : t -> Token_id.t
    end

    [%%versioned
    module Stable = struct
      module V2 = struct
        type t = Account.Stable.V2.t [@@deriving equal, compare, sexp]

        let to_latest = Fn.id

        let identifier = Account.identifier

        let balance Account.{ balance; _ } = balance

        let empty = Account.empty

        let token = Account.token_id
      end
    end]

    let empty = Stable.Latest.empty

    let initialize = Account.initialize

    module Unstable = struct
      include Mina_base.Account.Unstable

      let token = token_id
    end

    module Hardfork = struct
      include Mina_base.Account.Hardfork

      let token = token_id
    end
  end

  module Make_inputs
      (Account : Account.Intf)
      (Hash : Hash.Intf with type account := Account.t) =
  struct
    module Key = Public_key.Compressed
    module Token_id = Token_id
    module Account_id = Account_id

    module Balance = struct
      include Currency.Balance

      let to_int = to_nanomina_int
    end

    module Account = Account
    module Hash = Hash
    module Kvdb = Kvdb
    module Location = Location_at_depth
    module Location_binable = Location_binable
  end

  module type Account_Db =
    Merkle_ledger.Intf.Ledger.DATABASE
      with module Location = Location_at_depth
      with module Addr = Location_at_depth.Addr
      with type root_hash := Ledger_hash.t
       and type hash := Ledger_hash.t
       and type key := Public_key.Compressed.t
       and type token_id := Token_id.t
       and type token_id_set := Token_id.Set.t
       and type account_id_set := Account_id.Set.t
       and type account_id := Account_id.t

  module Mask_maps = Mask_maps.F (Location_at_depth)

  module Inputs = struct
    include Make_inputs (Account.Stable.Latest) (Hash.Stable.Latest)
    module Mask_maps = Mask_maps
  end

  module Unstable_inputs = Make_inputs (Account.Unstable) (Hash.Unstable)
  module Hardfork_inputs = Make_inputs (Account.Hardfork) (Hash.Hardfork)

  module Db : Account_Db with type account := Account.t = Database.Make (Inputs)

  module Unstable_db : Account_Db with type account := Account.Unstable.t =
    Database.Make (Unstable_inputs)

  module Hardfork_db : Account_Db with type account := Account.Hardfork.t =
    Database.Make (Hardfork_inputs)

  module Null = Null_ledger.Make (Inputs)

  module Any_ledger :
    Merkle_ledger.Intf.Ledger.ANY
      with module Location = Location_at_depth
      with type account := Account.t
       and type key := Public_key.Compressed.t
       and type token_id := Token_id.t
       and type token_id_set := Token_id.Set.t
       and type account_id := Account_id.t
       and type account_id_set := Account_id.Set.t
       and type hash := Hash.t =
    Merkle_ledger.Any_ledger.Make_base (Inputs)

  module Mask :
    Merkle_mask.Masking_merkle_tree_intf.S
      with module Location = Location_at_depth
       and module Attached.Addr = Location_at_depth.Addr
      with type account := Account.t
       and type key := Public_key.Compressed.t
       and type token_id := Token_id.t
       and type token_id_set := Token_id.Set.t
       and type account_id := Account_id.t
       and type account_id_set := Account_id.Set.t
       and type hash := Hash.t
       and type location := Location_at_depth.t
       and type parent := Any_ledger.M.t
       and type maps_t := Mask_maps.t =
  Merkle_mask.Masking_merkle_tree.Make (struct
    include Inputs
    module Base = Any_ledger.M
  end)

  module Maskable :
    Merkle_mask.Maskable_merkle_tree_intf.S
      with module Location = Location_at_depth
      with module Addr = Location_at_depth.Addr
      with type account := Account.t
       and type key := Public_key.Compressed.t
       and type token_id := Token_id.t
       and type token_id_set := Token_id.Set.t
       and type account_id := Account_id.t
       and type account_id_set := Account_id.Set.t
       and type hash := Hash.t
       and type root_hash := Hash.t
       and type unattached_mask := Mask.t
       and type attached_mask := Mask.Attached.t
       and type accumulated_t := Mask.accumulated_t
       and type maps_t := Mask_maps.t
       and type t := Any_ledger.M.t =
  Merkle_mask.Maskable_merkle_tree.Make (struct
    include Inputs
    module Base = Any_ledger.M
    module Mask = Mask

    let mask_to_base m = Any_ledger.cast (module Mask.Attached) m
  end)

  include Mask.Attached
  module Debug = Maskable.Debug

  type maskable_ledger = t

  module Make_converting (Converting_inputs : sig
    val convert : Account.t -> Account.Hardfork.t
  end) :
    Merkle_ledger.Intf.Ledger.Converting.WITH_DATABASE
      with module Location = Location
       and module Addr = Location.Addr
      with type root_hash := Ledger_hash.t
       and type hash := Ledger_hash.t
       and type account := Account.t
       and type key := Signature_lib.Public_key.Compressed.t
       and type token_id := Token_id.t
       and type token_id_set := Token_id.Set.t
       and type account_id := Account_id.t
       and type account_id_set := Account_id.Set.t
       and type converted_account := Account.Hardfork.t
       and type primary_ledger = Db.t
       and type converting_ledger = Hardfork_db.t =
    Converting_merkle_tree.With_database
      (struct
        type converted_account = Account.Hardfork.t

        let convert = Converting_inputs.convert

        let converted_equal = Account.Hardfork.equal

        include Inputs
      end)
      (Db)
      (Hardfork_db)

  let of_any_ledger ledger =
    let mask = Mask.create ~depth:(Any_ledger.M.depth ledger) () in
    Maskable.register_mask ledger mask

  let of_database db =
    let casted = Any_ledger.cast (module Db) db in
    let mask = Mask.create ~depth:(Db.depth db) () in
    Maskable.register_mask casted mask

  (* Mask.Attached.create () fails, can't create an attached mask directly
     shadow create in order to create an attached mask
  *)
  let create ?directory_name ~depth () =
    of_database (Db.create ?directory_name ~depth ())

  let create_ephemeral_with_base ~depth () =
    let maskable = Null.create ~depth () in
    let casted = Any_ledger.cast (module Null) maskable in
    let mask = Mask.create ~depth () in
    (casted, Maskable.register_mask casted mask)

  let create_ephemeral ~depth () =
    let _base, mask = create_ephemeral_with_base ~depth () in
    mask

  (** Create a new empty ledger.

      Warning: This skips mask registration, for use in transaction logic,
      where we always have either 0 or 1 masks, and the mask is always either
      committed or discarded. This function is deliberately not exposed in the
      public API of this module.

      This should *NOT* be used to create a ledger for other purposes.
  *)
  let empty ~depth () =
    let mask = Mask.create ~depth () in
    (* We don't register the mask here. This is only used in transaction logic,
       where we don't want to unregister. Transaction logic is also
       synchronous, so we don't need to worry that our mask will be reparented.
    *)
    Mask.set_parent mask (Any_ledger.cast (module Null) (Null.create ~depth ()))

  (** Create a ledger as a mask on top of the existing ledger.

      Warning: This skips mask registration, for use in transaction logic,
      where we always have either 0 or 1 masks, and the mask is always either
      committed or discarded. This function is deliberately not exposed in the
      public API of this module.

      This should *NOT* be used to create a ledger for other purposes.
  *)
  let create_masked (t : t) : t =
    let mask = Mask.create ~depth:(depth t) () in
    (* We don't register the mask here. This is only used in transaction logic,
       where we don't want to unregister. Transaction logic is also
       synchronous, so we don't need to worry that our mask will be reparented.
    *)
    Mask.set_parent mask (Any_ledger.cast (module Mask.Attached) t)

  (** Apply a mask to a ledger.

      Warning: The first argument is ignored, instead calling [commit]
      directly. This is used to support the different ledger kinds in
      transaction logic, where some of the 'masks' returned by [create_masked]
      do not hold a reference to their parent. This function is deliberately
      not exposed in the public API of this module.

      This should *NOT* be used to apply a mask for other purposes.
  *)
  let apply_mask (_t : t) ~(masked : t) = commit masked

  let with_ledger ~depth ~f =
    let ledger = create ~depth () in
    try
      let result = f ledger in
      close ledger ; result
    with exn -> close ledger ; raise exn

  let with_ephemeral_ledger ~depth ~f =
    let _base_ledger, masked_ledger = create_ephemeral_with_base ~depth () in
    try
      let result = f masked_ledger in
      let (_ : Mask.t) =
        Maskable.unregister_mask_exn ~loc:__LOC__ ~grandchildren:`Recursive
          masked_ledger
      in
      result
    with exn ->
      let (_ : Mask.t) =
        Maskable.unregister_mask_exn ~loc:__LOC__ ~grandchildren:`Recursive
          masked_ledger
      in
      raise exn

  let packed t = Any_ledger.cast (module Mask.Attached) t

  let register_mask t mask =
    let accumulated = Mask.Attached.to_accumulated t in
    Maskable.register_mask ~accumulated (packed t) mask

  let append_maps = Maskable.append_maps

  let get_maps = Maskable.get_maps

  let unsafe_preload_accounts_from_parent =
    Maskable.unsafe_preload_accounts_from_parent

  let unregister_mask_exn ~loc mask = Maskable.unregister_mask_exn ~loc mask

  let remove_and_reparent_exn t t_as_mask =
    Maskable.remove_and_reparent_exn (packed t) t_as_mask

  type unattached_mask = Mask.t

  type attached_mask = Mask.Attached.t

  type accumulated_t = Mask.accumulated_t

  (* inside MaskedLedger, the functor argument has assigned to location, account, and path
     but the module signature for the functor result wants them, so we declare them here *)
  type location = Location.t

  (* TODO: Don't allocate: see Issue #1191 *)
  let fold_until t ~init ~f ~finish =
    let%map.Async.Deferred accounts = to_list t in
    List.fold_until accounts ~init ~f ~finish

  let create_new_account_exn t account_id account =
    let action, _ =
      get_or_create_account t account_id account |> Or_error.ok_exn
    in
    if [%equal: [ `Existed | `Added ]] action `Existed then
      failwith
        (sprintf
           !"Could not create a new account with pk \
             %{sexp:Public_key.Compressed.t}: Account already exists"
           (Account_id.public_key account_id) )

  let create_new_account t account_id account =
    Or_error.try_with (fun () -> create_new_account_exn t account_id account)

  (* shadows definition in MaskedLedger, extra assurance hash is of right type  *)
  let merkle_root t =
    Ledger_hash.of_hash (merkle_root t :> Random_oracle.Digest.t)

  let get_or_create ledger account_id =
    let open Or_error.Let_syntax in
    let%bind action, loc =
      get_or_create_account ledger account_id (Account.initialize account_id)
    in
    let%map account =
      Result.of_option (get ledger loc)
        ~error:
          (Error.of_string
             "get_or_create: Account was not found in the ledger after creation" )
    in
    (action, account, loc)

  let create_empty_exn ledger account_id =
    let start_hash = merkle_root ledger in
    match
      get_or_create_account ledger account_id Account.empty |> Or_error.ok_exn
    with
    | `Existed, _ ->
        failwith "create_empty for a key already present"
    | `Added, new_loc ->
        assert (Ledger_hash.equal start_hash (merkle_root ledger)) ;
        (merkle_path ledger new_loc, Account.empty)

  module Converting_for_tests = struct
    module Converting_ledger :
      Merkle_ledger.Intf.Ledger.Converting.WITH_DATABASE
        with module Location = Location
         and module Addr = Location.Addr
        with type root_hash := Ledger_hash.t
         and type hash := Ledger_hash.t
         and type account := Account.t
         and type key := Signature_lib.Public_key.Compressed.t
         and type token_id := Token_id.t
         and type token_id_set := Token_id.Set.t
         and type account_id := Account_id.t
         and type account_id_set := Account_id.Set.t
         and type converted_account := Account.Hardfork.t
         and type primary_ledger = Db.t
         and type converting_ledger = Hardfork_db.t =
      Converting_merkle_tree.With_database
        (struct
          type converted_account = Account.Hardfork.t

          let convert = Account.Hardfork.of_stable

          let converted_equal = Account.Hardfork.equal

          include Inputs
        end)
        (Db)
        (Hardfork_db)

    let create_converting_with_base ~config ~logger ~depth () =
      let converting_ledger =
        Converting_ledger.create ~config ~logger ~depth ()
      in
      let casted =
        Any_ledger.cast (module Converting_ledger) converting_ledger
      in
      let mask = Mask.create ~depth () in
      ( Maskable.register_mask casted mask
      , Converting_ledger.converting_ledger converting_ledger )

    let[@warning "-32"] with_converting_ledger ~logger ~depth ~f =
      let ledger_and_base =
        create_converting_with_base ~config:Converting_ledger.Config.Temporary
          ~logger ~depth ()
      in
      try
        let result = f ledger_and_base in
        close (fst ledger_and_base) ;
        Ok result
      with exn ->
        close (fst ledger_and_base) ;
        Error (Error.of_exn exn)

    let[@warning "-32"] with_converting_ledger_exn ~logger ~depth ~f =
      with_converting_ledger ~logger ~depth ~f |> Or_error.ok_exn
  end
end

include Ledger_inner
include Mina_transaction_logic.Make (Ledger_inner)

(* use mask to restore ledger after application *)
let merkle_root_after_zkapp_command_exn ~constraint_constants ~global_slot
    ~txn_state_view ledger zkapp_command =
  let signature_kind = Mina_signature_kind.t_DEPRECATED in
  let mask = Mask.create ~depth:(depth ledger) () in
  let masked_ledger = register_mask ledger mask in
  let _applied =
    Or_error.ok_exn
      (apply_zkapp_command_unchecked ~signature_kind ~constraint_constants
         ~global_slot ~state_view:txn_state_view masked_ledger
         (Zkapp_command.Valid.forget zkapp_command) )
  in
  let root = merkle_root masked_ledger in
  ignore (unregister_mask_exn ~loc:__LOC__ masked_ledger : unattached_mask) ;
  root

(* use mask to restore ledger after application *)
let merkle_root_after_user_command_exn ~constraint_constants ~txn_global_slot
    ledger cmd =
  let mask = Mask.create ~depth:(depth ledger) () in
  let masked_ledger = register_mask ledger mask in
  let _applied =
    Or_error.ok_exn
      (apply_user_command ~constraint_constants ~txn_global_slot masked_ledger
         cmd )
  in
  let root = merkle_root masked_ledger in
  ignore (unregister_mask_exn ~loc:__LOC__ masked_ledger : unattached_mask) ;
  root

type init_state =
  ( Signature_lib.Keypair.t
  * Currency.Amount.t
  * Mina_numbers.Account_nonce.t
  * Account_timing.t )
  array
[@@deriving sexp_of]

let gen_initial_ledger_state : init_state Quickcheck.Generator.t =
  let open Quickcheck.Generator.Let_syntax in
  let%bind n_accounts = Int.gen_incl 2 10 in
  let%bind keypairs = Quickcheck_lib.replicate_gen Keypair.gen n_accounts in
  let%bind balances =
    let gen_balance =
      let%map whole_balance = Int.gen_incl 500_000_000 1_000_000_000 in
      Currency.Amount.of_mina_int_exn whole_balance
    in
    Quickcheck_lib.replicate_gen gen_balance n_accounts
  in
  let%bind nonces =
    Quickcheck_lib.replicate_gen
      ( Quickcheck.Generator.map ~f:Mina_numbers.Account_nonce.of_int
      @@ Int.gen_incl 0 1000 )
      n_accounts
  in
  let rec zip3_exn a b c =
    match (a, b, c) with
    | [], [], [] ->
        []
    | x :: xs, y :: ys, z :: zs ->
        (x, y, z, Account_timing.Untimed) :: zip3_exn xs ys zs
    | _ ->
        failwith "zip3 unequal lengths"
  in
  return @@ Array.of_list @@ zip3_exn keypairs balances nonces

let apply_initial_ledger_state : t -> init_state -> unit =
 fun t accounts ->
  Array.iter accounts ~f:(fun (kp, balance, nonce, timing) ->
      let pk_compressed = Public_key.compress kp.public_key in
      let account_id = Account_id.create pk_compressed Token_id.default in
      let account = Account.initialize account_id in
      let account' =
        { account with
          balance =
            Currency.Balance.of_nanomina_int_exn
              (Currency.Amount.to_nanomina_int balance)
        ; nonce
        ; timing
        }
      in
      create_new_account_exn t account_id account' )
