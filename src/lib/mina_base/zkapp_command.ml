open Core_kernel
open Signature_lib

module Poly = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type 'account_updates t =
            'account_updates Mina_wire_types.Mina_base.Zkapp_command.V1.T.t =
        { fee_payer : Account_update.Fee_payer.Stable.V1.t
        ; account_updates : 'account_updates
        ; memo : Signed_command_memo.Stable.V1.t
        }
      [@@deriving annot, sexp, compare, equal, hash, yojson, fields]

      let to_latest = Fn.id
    end
  end]
end

module Graphql_repr = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = Account_update.Graphql_repr.Stable.V1.t list Poly.Stable.V1.t
      [@@deriving sexp, compare, equal, hash, yojson]

      let to_latest = Fn.id
    end
  end]
end

module Simple = struct
  (* For easily constructing values *)
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = Account_update.Simple.Stable.V1.t list Poly.Stable.V1.t
      [@@deriving sexp, compare, equal, hash, yojson]

      let to_latest = Fn.id
    end
  end]
end

module Call_forest = Zkapp_call_forest_base
module Digest = Call_forest.Digest

type ('account_update, 'account_update_digest, 'forest_digest) with_forest =
  ('account_update, 'account_update_digest, 'forest_digest) Call_forest.t Poly.t
[@@deriving sexp, compare, equal, hash, yojson]

module T = struct
  type t =
    (Account_update.t, Digest.Account_update.t, Digest.Forest.t) with_forest
  [@@deriving sexp_of, to_yojson]

  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    [@@@with_top_version_tag]

    (* DO NOT DELETE VERSIONS!
       so we can always get transaction hashes from old transaction ids
       the version linter should be checking this

       IF YOU CREATE A NEW VERSION:
       update Transaction_hash.hash_of_transaction_id to handle it
       add hash_zkapp_command_vn for that version
    *)

    module V1 = struct
      type t =
        (Account_update.Stable.V1.t, unit, unit) Call_forest.Stable.V1.t
        Poly.Stable.V1.t
      [@@deriving sexp, compare, equal, hash, yojson]

      let to_latest = Fn.id

      let of_graphql_repr (t : Graphql_repr.t) : t =
        { fee_payer = t.fee_payer
        ; memo = t.memo
        ; account_updates =
            Call_forest.of_account_updates_map t.account_updates
              ~f:Account_update.of_graphql_repr
              ~account_update_depth:(fun (p : Account_update.Graphql_repr.t) ->
                p.body.call_depth )
        }

      let to_graphql_repr (t : t) : Graphql_repr.t =
        { fee_payer = t.fee_payer
        ; memo = t.memo
        ; account_updates =
            t.account_updates
            |> Call_forest.to_account_updates_map
                 ~f:(fun ~depth account_update ->
                   Account_update.to_graphql_repr account_update
                     ~call_depth:depth )
        }

      let gen =
        let open Quickcheck.Generator in
        let open Let_syntax in
        let gen_call_forest =
          fixed_point (fun self ->
              let%bind calls_length = small_non_negative_int in
              list_with_length calls_length
                (let%map account_update = Account_update.gen and calls = self in
                 { With_stack_hash.stack_hash = ()
                 ; elt =
                     { Call_forest.Tree.account_update
                     ; account_update_digest = ()
                     ; calls
                     }
                 } ) )
        in
        let open Quickcheck.Let_syntax in
        let%map fee_payer = Account_update.Fee_payer.gen
        and account_updates = gen_call_forest
        and memo = Signed_command_memo.gen in
        { Poly.fee_payer; account_updates; memo }

      let shrinker : t Quickcheck.Shrinker.t =
        Quickcheck.Shrinker.create (fun t ->
            let shape = Call_forest.shape t.Poly.account_updates in
            Sequence.map
              (Quickcheck.Shrinker.shrink Call_forest.Shape.quickcheck_shrinker
                 shape ) ~f:(fun shape' ->
                { t with
                  account_updates = Call_forest.mask t.account_updates shape'
                } ) )
    end
  end]
end

module Serializable_type = struct
  type raw_serializable = T.Stable.Latest.t

  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        ( Account_update.Serializable_type.Stable.V1.t
        , unit
        , unit )
        Call_forest.Stable.V1.t
        Poly.Stable.V1.t

      let to_latest = Fn.id
    end
  end]

  let to_raw_serializable (w : t) : raw_serializable =
    { fee_payer = w.fee_payer
    ; memo = w.memo
    ; account_updates =
        Call_forest.map ~f:Account_update.Serializable_type.to_raw_serializable
          w.account_updates
    }
end

include T

let write_all_proofs_to_disk ~signature_kind ~proof_cache_db
    (w : Stable.Latest.t) : t =
  { fee_payer = w.fee_payer
  ; memo = w.memo
  ; account_updates =
      Call_forest.map
        ~f:(Account_update.write_all_proofs_to_disk ~proof_cache_db)
      @@ Call_forest.accumulate_hashes
           ~hash_account_update:(Digest.Account_update.create ~signature_kind)
           w.account_updates
  }

let read_all_proofs_from_disk (t : t) : Stable.Latest.t =
  { fee_payer = t.fee_payer
  ; memo = t.memo
  ; account_updates =
      Call_forest.map ~f:Account_update.read_all_proofs_from_disk
      @@ Call_forest.forget_hashes t.account_updates
  }

let to_serializable_type (w : t) : Serializable_type.t =
  { fee_payer = w.fee_payer
  ; memo = w.memo
  ; account_updates =
      Call_forest.map ~f:Account_update.to_serializable_type
        (Call_forest.forget_hashes w.account_updates)
  }

let forget_digests_and_proofs_and_aux
    ({ fee_payer; memo; account_updates } : _ with_forest) =
  { Poly.fee_payer
  ; memo
  ; account_updates =
      Call_forest.forget_hashes_and_proofs_and_aux account_updates
  }

[%%define_locally Stable.Latest.(gen)]

let of_simple ~signature_kind ~proof_cache_db (w : Simple.t) : t =
  { fee_payer = w.fee_payer
  ; memo = w.memo
  ; account_updates =
      Call_forest.of_account_updates w.account_updates
        ~account_update_depth:(fun (p : Account_update.Simple.t) ->
          p.body.call_depth )
      |> Call_forest.map
           ~f:
             (Fn.compose
                (Account_update.write_all_proofs_to_disk ~proof_cache_db)
                Account_update.of_simple )
      |> Call_forest.accumulate_hashes
           ~hash_account_update:(Digest.Account_update.create ~signature_kind)
  }

let to_simple (t : t) : Simple.t =
  { fee_payer = t.fee_payer
  ; memo = t.memo
  ; account_updates =
      Call_forest.map ~f:Account_update.read_all_proofs_from_disk
        t.account_updates
      |> Call_forest.to_account_updates_map
           ~f:(fun ~depth { Account_update.Poly.body = b; authorization; aux }
              ->
             { Account_update.Poly.authorization
             ; body =
                 { Account_update.Body.Simple.public_key =
                     b.Account_update.Body.public_key
                 ; token_id = b.token_id
                 ; update = b.update
                 ; balance_change = b.balance_change
                 ; increment_nonce = b.increment_nonce
                 ; events = b.events
                 ; actions = b.actions
                 ; call_data = b.call_data
                 ; preconditions = b.preconditions
                 ; use_full_commitment = b.use_full_commitment
                 ; implicit_account_creation_fee =
                     b.implicit_account_creation_fee
                 ; may_use_token = b.may_use_token
                 ; call_depth = depth
                 ; authorization_kind = b.authorization_kind
                 }
             ; aux
             } )
  }

let all_account_updates ~signature_kind t : _ Call_forest.t =
  let p = t.Poly.fee_payer in
  let body = Account_update.Body.of_fee_payer p.body in
  let account_update =
    Account_update.with_aux ~body
      ~authorization:(Control.Poly.Signature p.authorization)
  in
  let fee_payer_digest : Digest.Account_update.t =
    Digest.Account_update.create ~signature_kind account_update
  in
  let tree : _ Call_forest.Tree.t =
    { account_update; account_update_digest = fee_payer_digest; calls = [] }
  in
  Call_forest.cons_tree tree t.account_updates

let fee (t : (_, _, _) with_forest) : Currency.Fee.t = t.fee_payer.body.fee

let fee_payer_account_update (t : (_, _, _) with_forest) = t.fee_payer

let applicable_at_nonce (t : (_, _, _) with_forest) : Account.Nonce.t =
  t.fee_payer.body.nonce

let target_nonce_on_success
    (t : ((Account_update.Body.t, _, _) Account_update.Poly.t, _, _) with_forest)
    : Account.Nonce.t =
  let base_nonce = Account.Nonce.succ (applicable_at_nonce t) in
  let fee_payer_pubkey = t.fee_payer.body.public_key in
  let fee_payer_account_update_increments =
    List.count (Call_forest.to_list t.account_updates) ~f:(fun p ->
        Public_key.Compressed.equal p.body.public_key fee_payer_pubkey
        && p.body.increment_nonce )
  in
  Account.Nonce.add base_nonce
    (Account.Nonce.of_int fee_payer_account_update_increments)

let nonce_increments
    (t : ((Account_update.Body.t, _, _) Account_update.Poly.t, _, _) with_forest)
    : int Public_key.Compressed.Map.t =
  let base_increments =
    Public_key.Compressed.Map.of_alist_exn [ (t.fee_payer.body.public_key, 1) ]
  in
  List.fold_left (Call_forest.to_list t.account_updates) ~init:base_increments
    ~f:(fun incr_map account_update ->
      if account_update.body.increment_nonce then
        Map.update incr_map account_update.body.public_key
          ~f:(Option.value_map ~default:1 ~f:(( + ) 1))
      else incr_map )

let fee_token (_t : (_, _, _) with_forest) = Token_id.default

let fee_payer (t : (_, _, _) with_forest) =
  Account_id.create t.fee_payer.body.public_key (fee_token t)

let extract_vks (t : (_, _, _) with_forest) :
    (Account_id.t * Verification_key_wire.t) List.t =
  Call_forest.fold ~init:[] t.account_updates ~f:(fun acc p ->
      match Account_update.verification_key_update_to_option p with
      | Zkapp_basic.Set_or_keep.Set (Some vk) ->
          (Account_update.account_id p, vk) :: acc
      | _ ->
          acc )

let account_updates_list (t : (_, _, _) with_forest) :
    _ Account_update.Poly.t list =
  Call_forest.fold t.account_updates ~init:[] ~f:(Fn.flip List.cons) |> List.rev

let all_account_updates_list' ~of_fee_payer ~of_account_update
    (t : (_, _, _) with_forest) : _ list =
  Call_forest.fold t.account_updates
    ~init:[ of_fee_payer (fee_payer_account_update t) ]
    ~f:(Fn.flip (Fn.compose List.cons of_account_update))
  |> List.rev

let all_account_updates_list (t : (_, _, _) with_forest) :
    _ Account_update.Poly.t list =
  all_account_updates_list' ~of_fee_payer:Account_update.of_fee_payer
    ~of_account_update:Fn.id t

let fee_excess (t : (_, _, _) with_forest) =
  Fee_excess.of_single (fee_token t, Currency.Fee.Signed.of_unsigned (fee t))

(* always `Accessed` for fee payer *)
let account_access_statuses (t : (_, _, _) with_forest)
    (status : Transaction_status.t) =
  let init = [ (fee_payer t, `Accessed) ] in
  let status_sym =
    match status with Applied -> `Accessed | Failed _ -> `Not_accessed
  in
  Call_forest.fold t.account_updates ~init ~f:(fun acc p ->
      (Account_update.account_id p, status_sym) :: acc )
  |> List.rev |> List.stable_dedup

let accounts_referenced (t : (_, _, _) with_forest) =
  List.map (account_access_statuses t Applied) ~f:(fun (acct_id, _status) ->
      acct_id )

let fee_payer_pk (t : (_, _, _) with_forest) = t.fee_payer.body.public_key

let value_if b ~then_ ~else_ = if b then then_ else else_

module Virtual = struct
  module Bool = struct
    type t = bool

    let true_ = true

    let assert_ _ = ()

    let equal = Bool.equal

    let not = not

    let ( || ) = ( || )

    let ( && ) = ( && )
  end

  module Unit = struct
    type t = unit

    let if_ = value_if
  end

  module Ledger = Unit
  module Account = Unit

  module Amount = struct
    open Currency.Amount

    type nonrec t = t

    let if_ = value_if

    module Signed = Signed

    let zero = zero

    let ( - ) (x1 : t) (x2 : t) : Signed.t =
      Option.value_exn Signed.(of_unsigned x1 + negate (of_unsigned x2))

    let ( + ) (x1 : t) (x2 : t) : t = Option.value_exn (add x1 x2)

    let add_signed (x1 : t) (x2 : Signed.t) : t =
      let y = Option.value_exn Signed.(of_unsigned x1 + x2) in
      match y.sgn with Pos -> y.magnitude | Neg -> failwith "add_signed"
  end

  module Token_id = struct
    include Token_id

    let if_ = value_if
  end

  module Zkapp_command = struct
    type t = Account_update.t list

    let if_ = value_if

    type account_update = Account_update.t

    let empty = []

    let is_empty = List.is_empty

    let pop (t : t) = match t with [] -> failwith "pop" | p :: t -> (p, t)
  end
end

module Verifiable : sig
  type t =
    ( Account_update.t
    , (Side_loaded_verification_key.t, Zkapp_basic.F.t) With_hash.t option )
    Call_forest.With_hashes_and_data.t
    Poly.t
  [@@deriving sexp_of]

  val load_vk_from_ledger :
       location_of_account:(Account_id.t -> 'loc option)
    -> get:('loc -> Account.t option)
    -> Zkapp_basic.F.t
    -> Account_id.t
    -> Verification_key_wire.t Or_error.t

  val load_vks_from_ledger :
       location_of_account_batch:
         (Account_id.t list -> (Account_id.t * 'loc option) list)
    -> get_batch:('loc list -> ('loc * Account.t option) list)
    -> Account_id.t list
    -> Verification_key_wire.t Account_id.Map.t

  val create :
       T.t
    -> failed:bool
    -> find_vk:
         (Zkapp_basic.F.t -> Account_id.t -> Verification_key_wire.t Or_error.t)
    -> t Or_error.t

  module type Command_wrapper_intf = sig
    type 'a t

    val unwrap : 'a t -> 'a

    val map : 'a t -> f:('a -> 'b) -> 'b t

    val is_failed : 'a t -> bool
  end

  module type Create_all_intf = sig
    type cache

    module Command_wrapper : Command_wrapper_intf

    val create_all :
      T.t Command_wrapper.t list -> cache -> t Command_wrapper.t list Or_error.t
  end

  module From_unapplied_sequence :
    Create_all_intf
      with type 'a Command_wrapper.t = 'a
       and type cache =
        Verification_key_wire.t Zkapp_basic.F_map.Map.t Account_id.Map.t

  module From_applied_sequence :
    Create_all_intf
      with type 'a Command_wrapper.t = 'a With_status.t
       and type cache = Verification_key_wire.t Account_id.Map.t

  module Serializable : sig
    type t =
      ( Account_update.Stable.Latest.t
      , ( Side_loaded_verification_key.Stable.Latest.t
        , Zkapp_basic.F.Stable.Latest.t )
        With_hash.Stable.Latest.t
        option )
      Call_forest.With_hashes_and_data.Stable.Latest.t
      Poly.Stable.Latest.t
    [@@deriving bin_io]
  end

  val to_serializable : t -> Serializable.t

  val of_serializable :
    proof_cache_db:Proof_cache_tag.cache_db -> Serializable.t -> t
end = struct
  type t =
    ( Account_update.t
    , ( Side_loaded_verification_key.Stable.Latest.t
      , Zkapp_basic.F.Stable.Latest.t )
      With_hash.Stable.Latest.t
      option )
    Call_forest.With_hashes_and_data.Stable.Latest.t
    Poly.Stable.Latest.t
  [@@deriving sexp_of]

  module Serializable = struct
    type t =
      ( ( Account_update.Body.Stable.Latest.t
        , ( Proof.Stable.Latest.t
          , Signature.Stable.Latest.t )
          Control.Poly.Stable.Latest.t )
        Account_update.Without_aux.Stable.Latest.t
      , ( Side_loaded_verification_key.Stable.Latest.t
        , Zkapp_basic.F.Stable.Latest.t )
        With_hash.Stable.Latest.t
        option )
      Call_forest.With_hashes_and_data.Stable.Latest.t
      Poly.Stable.Latest.t
    [@@deriving bin_io_unversioned]
  end

  let to_serializable ({ fee_payer; account_updates; memo } : t) :
      Serializable.t =
    { fee_payer
    ; account_updates =
        Call_forest.map account_updates ~f:(fun (upd, aux) ->
            (Account_update.read_all_proofs_from_disk upd, aux) )
    ; memo
    }

  let of_serializable ~proof_cache_db
      ({ fee_payer; account_updates; memo } : Serializable.t) : t =
    { fee_payer
    ; account_updates =
        Call_forest.map account_updates ~f:(fun (upd, aux) ->
            (Account_update.write_all_proofs_to_disk ~proof_cache_db upd, aux) )
    ; memo
    }

  let ok_if_vk_hash_expected ~got ~expected =
    if not @@ Zkapp_basic.F.equal (With_hash.hash got) expected then
      Error
        (Error.create "Expected vk hash doesn't match hash in vk we received"
           [ ("expected_vk_hash", expected)
           ; ("got_vk_hash", With_hash.hash got)
           ]
           [%sexp_of: (string * Zkapp_basic.F.t) list] )
    else Ok got

  let load_vk_from_ledger ~location_of_account ~get expected_vk_hash account_id
      =
    match
      let open Option.Let_syntax in
      let%bind location = location_of_account account_id in
      let%bind (account : Account.t) = get location in
      let%bind zkapp = account.zkapp in
      zkapp.verification_key
    with
    | Some vk ->
        ok_if_vk_hash_expected ~got:vk ~expected:expected_vk_hash
    | None ->
        let err =
          Error.create "No verification key found for proved account update"
            ("account_id", account_id) [%sexp_of: string * Account_id.t]
        in
        Error err

  let load_vks_from_ledger ~location_of_account_batch ~get_batch account_ids =
    let locations =
      location_of_account_batch account_ids |> List.filter_map ~f:snd
    in
    get_batch locations
    |> List.filter_map ~f:(fun ((_, account) : _ * Account.t option) ->
           let open Option.Let_syntax in
           let account = Option.value_exn account in
           let%bind zkapp = account.zkapp in
           let%map verification_key = zkapp.verification_key in
           (Account.identifier account, verification_key) )
    |> Account_id.Map.of_alist_exn

  (* Ensures that there's a verification_key available for all account_updates
   * and creates a valid command associating the correct keys with each
   * account_id.
   *
   * If an account_update replaces the verification_key (or deletes it),
   * subsequent account_updates use the replaced key instead of looking in the
   * ledger for the key (ie set by a previous transaction).
   *)
  let create ({ fee_payer; account_updates; memo } : T.t) ~failed ~find_vk =
    With_return.with_return (fun { return } ->
        let tbl = Account_id.Table.create () in
        let vks_overridden =
          (* Keep track of the verification keys that have been set so far
             during this transaction.
          *)
          ref Account_id.Map.empty
        in
        let account_updates =
          Call_forest.map account_updates ~f:(fun p ->
              let account_id = Account_update.account_id p in
              let vks_overriden' =
                match Account_update.verification_key_update_to_option p with
                | Zkapp_basic.Set_or_keep.Set vk_next ->
                    Account_id.Map.set !vks_overridden ~key:account_id
                      ~data:vk_next
                | Zkapp_basic.Set_or_keep.Keep ->
                    !vks_overridden
              in
              let () =
                match Account_update.check_authorization p with
                | Ok () ->
                    ()
                | Error _ as err ->
                    return err
              in
              match (p.body.authorization_kind, failed) with
              | Proof vk_hash, false -> (
                  let prioritized_vk =
                    (* only lookup _past_ vk setting, ie exclude the new one we
                     * potentially set in this account_update (use the non-'
                     * vks_overrided) . *)
                    match Account_id.Map.find !vks_overridden account_id with
                    | Some (Some vk) -> (
                        match
                          ok_if_vk_hash_expected ~got:vk ~expected:vk_hash
                        with
                        | Ok vk ->
                            Some vk
                        | Error err ->
                            return (Error err) )
                    | Some None ->
                        (* we explicitly have erased the key *)
                        let err =
                          Error.create
                            "No verification key found for proved account \
                             update: the verification key was removed by a \
                             previous account update"
                            ("account_id", account_id)
                            [%sexp_of: string * Account_id.t]
                        in
                        return (Error err)
                    | None -> (
                        (* we haven't set anything; lookup the vk in the fallback *)
                        match find_vk vk_hash account_id with
                        | Error e ->
                            return (Error e)
                        | Ok vk ->
                            Some vk )
                  in
                  match prioritized_vk with
                  | Some prioritized_vk ->
                      Account_id.Table.update tbl account_id ~f:(fun _ ->
                          With_hash.hash prioritized_vk ) ;
                      (* return the updated overrides *)
                      vks_overridden := vks_overriden' ;
                      (p, Some prioritized_vk)
                  | None ->
                      (* The transaction failed, so we allow the vk to be missing. *)
                      (p, None) )
              | _ ->
                  vks_overridden := vks_overriden' ;
                  (p, None) )
        in
        Ok { Poly.fee_payer; account_updates; memo } )

  module type Cache_intf = sig
    type t

    val find :
         t
      -> account_id:Account_id.t
      -> vk_hash:Zkapp_basic.F.t
      -> Verification_key_wire.t option

    val add : t -> account_id:Account_id.t -> vk:Verification_key_wire.t -> t
  end

  module type Command_wrapper_intf = sig
    type 'a t

    val unwrap : 'a t -> 'a

    val map : 'a t -> f:('a -> 'b) -> 'b t

    val is_failed : 'a t -> bool
  end

  module type Create_all_intf = sig
    type cache

    module Command_wrapper : Command_wrapper_intf

    val create_all :
      T.t Command_wrapper.t list -> cache -> t Command_wrapper.t list Or_error.t
  end

  module Make_create_all
      (Cache : Cache_intf)
      (Command_wrapper : Command_wrapper_intf) :
    Create_all_intf
      with module Command_wrapper := Command_wrapper
       and type cache = Cache.t = struct
    type cache = Cache.t

    let create_all (wrapped_cmds : T.t Command_wrapper.t list)
        (init_cache : Cache.t) : t Command_wrapper.t list Or_error.t =
      Or_error.try_with (fun () ->
          snd (* remove the helper cache we folded with *)
            (List.fold_map wrapped_cmds ~init:init_cache
               ~f:(fun running_cache wrapped_cmd ->
                 let cmd = Command_wrapper.unwrap wrapped_cmd in
                 let cmd_failed = Command_wrapper.is_failed wrapped_cmd in
                 let verified_cmd : t =
                   create cmd ~failed:cmd_failed
                     ~find_vk:(fun vk_hash account_id ->
                       (* first we check if there's anything in the running
                          cache within this chunk so far *)
                       match Cache.find running_cache ~account_id ~vk_hash with
                       | None ->
                           Error
                             (Error.of_string
                                "verification key not found in cache" )
                       | Some vk ->
                           Ok vk )
                   |> Or_error.ok_exn
                 in
                 let running_cache' =
                   (* update the cache if the command is not failed *)
                   if not cmd_failed then
                     List.fold (extract_vks cmd) ~init:running_cache
                       ~f:(fun acc (account_id, vk) ->
                         Cache.add acc ~account_id ~vk )
                   else running_cache
                 in
                 ( running_cache'
                 , Command_wrapper.map wrapped_cmd ~f:(Fn.const verified_cmd) ) )
            ) )
  end

  (* There are 2 situations in which we are converting commands to their verifiable format:
       - we are reasoning about the validity of commands when the sequence is not yet known
       - we are reasoning about the validity of commands when the sequence (and by extension, status) is known
  *)

  module From_unapplied_sequence = struct
    module Cache = struct
      type t = Verification_key_wire.t Zkapp_basic.F_map.Map.t Account_id.Map.t

      let find (t : t) ~account_id ~vk_hash =
        let%bind.Option vks = Map.find t account_id in
        Map.find vks vk_hash

      let add (t : t) ~account_id ~(vk : Verification_key_wire.t) =
        Map.update t account_id ~f:(fun vks_opt ->
            let vks =
              Option.value vks_opt ~default:Zkapp_basic.F_map.Map.empty
            in
            Map.set vks ~key:vk.hash ~data:vk )
    end

    module Command_wrapper : Command_wrapper_intf with type 'a t = 'a = struct
      type 'a t = 'a

      let unwrap t = t

      let map t ~f = f t

      let is_failed _ = false
    end

    include Make_create_all (Cache) (Command_wrapper)
  end

  module From_applied_sequence = struct
    module Cache = struct
      type t = Verification_key_wire.t Account_id.Map.t

      let find (t : t) ~account_id ~vk_hash =
        let%bind.Option vk = Map.find t account_id in
        Option.some_if (Zkapp_basic.F.equal vk_hash vk.hash) vk

      let add (t : t) ~account_id ~vk = Map.set t ~key:account_id ~data:vk
    end

    module Command_wrapper :
      Command_wrapper_intf with type 'a t = 'a With_status.t = struct
      type 'a t = 'a With_status.t

      let unwrap = With_status.data

      let map { With_status.status; data } ~f =
        { With_status.status; data = f data }

      let is_failed { With_status.status; _ } =
        match status with Applied -> false | Failed _ -> true
    end

    include Make_create_all (Cache) (Command_wrapper)
  end
end

let of_verifiable
    ({ Poly.fee_payer; account_updates; memo } :
      _ Call_forest.With_hashes_and_data.t Poly.t ) =
  { Poly.fee_payer
  ; account_updates = Call_forest.map account_updates ~f:fst
  ; memo
  }

module Transaction_commitment = struct
  module Stable = Kimchi_backend.Pasta.Basic.Fp.Stable

  type t = (Stable.Latest.t[@deriving sexp])

  let sexp_of_t = Stable.Latest.sexp_of_t

  let t_of_sexp = Stable.Latest.t_of_sexp

  let empty = Outside_hash_image.t

  let typ = Snark_params.Tick.Field.typ

  let create ~(account_updates_hash : Digest.Forest.t) : t =
    (account_updates_hash :> t)

  let create_complete (t : t) ~memo_hash
      ~(fee_payer_hash : Digest.Account_update.t) =
    Random_oracle.hash ~init:Hash_prefix.account_update_cons
      [| memo_hash; (fee_payer_hash :> t); t |]

  module Checked = struct
    type t = Pickles.Impls.Step.Field.t

    let create ~(account_updates_hash : Digest.Forest.Checked.t) =
      (account_updates_hash :> t)

    let create_complete (t : t) ~memo_hash
        ~(fee_payer_hash : Digest.Account_update.Checked.t) =
      Random_oracle.Checked.hash ~init:Hash_prefix.account_update_cons
        [| memo_hash; (fee_payer_hash :> t); t |]
  end
end

let account_updates_hash (t : _ Poly.t) = Call_forest.hash t.account_updates

let commitment (t : t) : Transaction_commitment.t =
  Transaction_commitment.create ~account_updates_hash:(account_updates_hash t)

(** This module defines weights for each component of a `Zkapp_command.t` element. *)
module Weight = struct
  let account_update : _ Account_update.Poly.t -> int = fun _ -> 1

  let fee_payer (_fp : Account_update.Fee_payer.t) : int = 1

  let account_updates : (_, _, _) Call_forest.t -> int =
    Call_forest.fold ~init:0 ~f:(fun acc p -> acc + account_update p)

  let memo : Signed_command_memo.t -> int = fun _ -> 0
end

let weight (zkapp_command : (_, _, _) with_forest) : int =
  let { Poly.fee_payer; account_updates; memo } = zkapp_command in
  List.sum
    (module Int)
    ~f:Fn.id
    [ Weight.fee_payer fee_payer
    ; Weight.account_updates account_updates
    ; Weight.memo memo
    ]

module type Valid_intf = sig
  type nonrec t = private { zkapp_command : t } [@@deriving sexp_of, to_yojson]

  val to_valid_unsafe :
    T.t -> [> `If_this_is_used_it_should_have_a_comment_justifying_it of t ]

  module For_tests : sig
    val to_valid :
         T.t
      -> failed:bool
      -> find_vk:
           (   Zkapp_basic.F.t
            -> Account_id.t
            -> (Verification_key_wire.t, Error.t) Result.t )
      -> t Or_error.t

    val of_verifiable : Verifiable.t -> t
  end

  val forget : t -> T.t
end

module Valid : Valid_intf = struct
  type t = { zkapp_command : T.t } [@@deriving sexp_of, to_yojson]

  let create zkapp_command : t = { zkapp_command }

  let to_valid_unsafe (t : T.t) :
      [> `If_this_is_used_it_should_have_a_comment_justifying_it of t ] =
    `If_this_is_used_it_should_have_a_comment_justifying_it (create t)

  let forget (t : t) : T.t = t.zkapp_command

  module For_tests = struct
    let of_verifiable (t : Verifiable.t) : t =
      { zkapp_command = of_verifiable t }

    let to_valid (t : T.t) ~failed ~find_vk : t Or_error.t =
      Verifiable.create t ~failed ~find_vk |> Or_error.map ~f:of_verifiable
  end
end

(* so transaction ids have a version tag *)
include Codable.Make_base64 (Stable.Latest.With_top_version_tag)

let account_updates_deriver obj =
  let of_zkapp_command_with_depth (ps : Account_update.Graphql_repr.t list) =
    Call_forest.of_account_updates ps
      ~account_update_depth:(fun (p : Account_update.Graphql_repr.t) ->
        p.body.call_depth )
    |> Call_forest.map ~f:Account_update.of_graphql_repr
  and to_zkapp_command_with_depth ps : Account_update.Graphql_repr.t list =
    ps
    |> Call_forest.to_account_updates_map ~f:(fun ~depth p ->
           Account_update.to_graphql_repr ~call_depth:depth p )
  in
  let open Fields_derivers_zkapps.Derivers in
  let inner = (list @@ Account_update.Graphql_repr.deriver @@ o ()) @@ o () in
  iso ~map:of_zkapp_command_with_depth ~contramap:to_zkapp_command_with_depth
    inner obj

let deriver obj =
  let open Fields_derivers_zkapps.Derivers in
  let open Poly in
  let ( !. ) = ( !. ) ~t_fields_annots in
  Fields.make_creator obj
    ~fee_payer:!.Account_update.Fee_payer.deriver
    ~account_updates:!.account_updates_deriver
    ~memo:!.Signed_command_memo.deriver
  |> finish "ZkappCommand" ~t_toplevel_annots

let arg_typ () = Fields_derivers_zkapps.(arg_typ (deriver @@ Derivers.o ()))

let typ () = Fields_derivers_zkapps.(typ (deriver @@ Derivers.o ()))

let to_json x = Fields_derivers_zkapps.(to_json (deriver @@ Derivers.o ())) x

let of_json x = Fields_derivers_zkapps.(of_json (deriver @@ Derivers.o ())) x

let account_updates_of_json x =
  Fields_derivers_zkapps.(
    of_json
      ((list @@ Account_update.Graphql_repr.deriver @@ o ()) @@ derivers ()))
    x

let zkapp_command_to_json x =
  Fields_derivers_zkapps.(to_json (deriver @@ derivers ())) x

let arg_query_string x =
  Fields_derivers_zkapps.Test.Loop.json_to_string_gql @@ to_json x

let dummy ~signature_kind =
  lazy
    (let account_update =
       Account_update.with_aux ~body:Account_update.Body.dummy
         ~authorization:(Control.Poly.Signature Signature.dummy)
     in
     let fee_payer : Account_update.Fee_payer.t =
       Account_update.Fee_payer.make ~body:Account_update.Body.Fee_payer.dummy
         ~authorization:Signature.dummy
     in
     { Poly.fee_payer
     ; account_updates = Call_forest.cons ~signature_kind account_update []
     ; memo = Signed_command_memo.empty
     } )

module Make_update_group (Input : sig
  type global_state

  type local_state

  type spec

  type connecting_ledger_hash

  val zkapp_segment_of_controls : _ Control.Poly.t list -> spec
end) : sig
  module Zkapp_command_intermediate_state : sig
    type state = { global : Input.global_state; local : Input.local_state }

    type t =
      { kind : [ `Same | `New | `Two_new ]
      ; spec : Input.spec
      ; state_before : state
      ; state_after : state
      ; connecting_ledger : Input.connecting_ledger_hash
      }
  end

  val group_by_zkapp_command_rev :
       ( ( Account_update.Body.t
         , (_, Signature.t) Control.Poly.t
         , 'aux )
         Account_update.Poly.t
       , _
       , _ )
       with_forest
       list
    -> (Input.global_state * Input.local_state * Input.connecting_ledger_hash)
       list
       list
    -> Zkapp_command_intermediate_state.t list
end = struct
  open Input

  module Zkapp_command_intermediate_state = struct
    type state = { global : global_state; local : local_state }

    type t =
      { kind : [ `Same | `New | `Two_new ]
      ; spec : spec
      ; state_before : state
      ; state_after : state
      ; connecting_ledger : connecting_ledger_hash
      }
  end

  (** [group_by_zkapp_command_rev zkapp_commands stmtss] identifies before/after pairs of
      statements, corresponding to account updates for each zkapp_command in [zkapp_commands] which minimize the
      number of snark proofs needed to prove all of the zkapp_command.

      This function is intended to take multiple zkapp transactions as
      its input, which is then converted to a [Account_update.t list list] using
      [List.map ~f:Zkapp_command.zkapp_command]. The [stmtss] argument should
      be a list of the same length, with 1 more state than the number of
      zkapp_command for each transaction.

      For example, two transactions made up of zkapp_command [[p1; p2; p3]] and
      [[p4; p5]] should have the statements [[[s0; s1; s2; s3]; [s3; s4; s5]]],
      where each [s_n] is the state after applying [p_n] on top of [s_{n-1}], and
      where [s0] is the initial state before any of the transactions have been
      applied.

      Each pair is also identified with one of [`Same], [`New], or [`Two_new],
      indicating that the next one ([`New]) or next two ([`Two_new]) [Zkapp_command.t]s
      will need to be passed as part of the snark witness while applying that
      pair.
  *)
  let group_by_zkapp_command_rev (type aux)
      (zkapp_commands :
        ( ( Account_update.Body.t
          , (_, Signature.t) Control.Poly.t
          , aux )
          Account_update.Poly.t
        , _
        , _ )
        with_forest
        list )
      (stmtss : (global_state * local_state * connecting_ledger_hash) list list)
      : Zkapp_command_intermediate_state.t list =
    let intermediate_state ~kind ~spec ~before ~after =
      let global_before, local_before, _ = before in
      let global_after, local_after, connecting_ledger = after in
      { Zkapp_command_intermediate_state.kind
      ; spec
      ; state_before = { global = global_before; local = local_before }
      ; state_after = { global = global_after; local = local_after }
      ; connecting_ledger
      }
    in
    let zkapp_account_updatess =
      []
      :: List.map zkapp_commands ~f:(fun zkapp_command ->
             all_account_updates_list'
               ~of_fee_payer:Account_update.of_fee_payer_no_aux
               ~of_account_update:Account_update.forget_aux zkapp_command )
    in
    let rec group_by_zkapp_command_rev (zkapp_commands : _ list list) stmtss acc
        =
      match (zkapp_commands, stmtss) with
      | ([] | [ [] ]), [ _ ] ->
          (* We've associated statements with all given zkapp_command. *)
          acc
      | ( [ [ { Account_update.Poly.authorization = a1; _ } ] ]
        , [ [ before; after ] ] ) ->
          (* There are no later zkapp_command to pair this one with. Prove it on its
             own.
          *)
          intermediate_state ~kind:`Same
            ~spec:(zkapp_segment_of_controls [ a1 ])
            ~before ~after
          :: acc
      | [ []; [ { authorization = a1; _ } ] ], [ [ _ ]; [ before; after ] ] ->
          (* This account_update is part of a new transaction, and there are no later
             zkapp_command to pair it with. Prove it on its own.
          *)
          intermediate_state ~kind:`New
            ~spec:(zkapp_segment_of_controls [ a1 ])
            ~before ~after
          :: acc
      | ( ({ Account_update.Poly.authorization = Control.Poly.Proof _ as a1; _ }
          :: zkapp_command )
          :: zkapp_commands
        , (before :: (after :: _ as stmts)) :: stmtss ) ->
          (* This account_update contains a proof, don't pair it with other account updates. *)
          group_by_zkapp_command_rev
            (zkapp_command :: zkapp_commands)
            (stmts :: stmtss)
            ( intermediate_state ~kind:`Same
                ~spec:(zkapp_segment_of_controls [ a1 ])
                ~before ~after
            :: acc )
      | ( []
          :: ({ authorization = Proof _ as a1; _ } :: zkapp_command)
             :: zkapp_commands
        , [ _ ] :: (before :: (after :: _ as stmts)) :: stmtss ) ->
          (* This account_update is part of a new transaction, and contains a proof, don't
             pair it with other account updates.
          *)
          group_by_zkapp_command_rev
            (zkapp_command :: zkapp_commands)
            (stmts :: stmtss)
            ( intermediate_state ~kind:`New
                ~spec:(zkapp_segment_of_controls [ a1 ])
                ~before ~after
            :: acc )
      | ( ({ authorization = a1; _ }
          :: ({ authorization = Proof _; _ } :: _ as zkapp_command) )
          :: zkapp_commands
        , (before :: (after :: _ as stmts)) :: stmtss ) ->
          (* The next account_update contains a proof, don't pair it with this account_update. *)
          group_by_zkapp_command_rev
            (zkapp_command :: zkapp_commands)
            (stmts :: stmtss)
            ( intermediate_state ~kind:`Same
                ~spec:(zkapp_segment_of_controls [ a1 ])
                ~before ~after
            :: acc )
      | ( ({ authorization = a1; _ } :: ([] as zkapp_command))
          :: (({ authorization = Proof _; _ } :: _) :: _ as zkapp_commands)
        , (before :: (after :: _ as stmts)) :: stmtss ) ->
          (* The next account_update is in the next transaction and contains a proof,
             don't pair it with this account_update.
          *)
          group_by_zkapp_command_rev
            (zkapp_command :: zkapp_commands)
            (stmts :: stmtss)
            ( intermediate_state ~kind:`Same
                ~spec:(zkapp_segment_of_controls [ a1 ])
                ~before ~after
            :: acc )
      | ( ({ authorization = (Signature _ | None_given) as a1; _ }
          :: { authorization = (Signature _ | None_given) as a2; _ }
             :: zkapp_command )
          :: zkapp_commands
        , (before :: _ :: (after :: _ as stmts)) :: stmtss ) ->
          (* The next two zkapp_command do not contain proofs, and are within the same
             transaction. Pair them.
             Ok to get "use_full_commitment" of [a1] because neither of them
             contain a proof.
          *)
          group_by_zkapp_command_rev
            (zkapp_command :: zkapp_commands)
            (stmts :: stmtss)
            ( intermediate_state ~kind:`Same
                ~spec:(zkapp_segment_of_controls [ a1; a2 ])
                ~before ~after
            :: acc )
      | ( []
          :: ({ authorization = a1; _ }
             :: ({ authorization = Proof _; _ } :: _ as zkapp_command) )
             :: zkapp_commands
        , [ _ ] :: (before :: (after :: _ as stmts)) :: stmtss ) ->
          (* This account_update is in the next transaction, and the next account_update contains a
             proof, don't pair it with this account_update.
          *)
          group_by_zkapp_command_rev
            (zkapp_command :: zkapp_commands)
            (stmts :: stmtss)
            ( intermediate_state ~kind:`New
                ~spec:(zkapp_segment_of_controls [ a1 ])
                ~before ~after
            :: acc )
      | ( []
          :: ({ authorization = (Signature _ | None_given) as a1; _ }
             :: { authorization = (Signature _ | None_given) as a2; _ }
                :: zkapp_command )
             :: zkapp_commands
        , [ _ ] :: (before :: _ :: (after :: _ as stmts)) :: stmtss ) ->
          (* The next two zkapp_command do not contain proofs, and are within the same
             new transaction. Pair them.
             Ok to get "use_full_commitment" of [a1] because neither of them
             contain a proof.
          *)
          group_by_zkapp_command_rev
            (zkapp_command :: zkapp_commands)
            (stmts :: stmtss)
            ( intermediate_state ~kind:`New
                ~spec:(zkapp_segment_of_controls [ a1; a2 ])
                ~before ~after
            :: acc )
      | ( [ { authorization = (Signature _ | None_given) as a1; _ } ]
          :: ({ authorization = (Signature _ | None_given) as a2; _ }
             :: zkapp_command )
             :: zkapp_commands
        , (before :: _after1) :: (_before2 :: (after :: _ as stmts)) :: stmtss )
        ->
          (* The next two zkapp_command do not contain proofs, and the second is within
             a new transaction. Pair them.
             Ok to get "use_full_commitment" of [a1] because neither of them
             contain a proof.
          *)
          group_by_zkapp_command_rev
            (zkapp_command :: zkapp_commands)
            (stmts :: stmtss)
            ( intermediate_state ~kind:`New
                ~spec:(zkapp_segment_of_controls [ a1; a2 ])
                ~before ~after
            :: acc )
      | ( []
          :: ({ authorization = a1; _ } :: zkapp_command)
             :: (({ authorization = Proof _; _ } :: _) :: _ as zkapp_commands)
        , [ _ ] :: (before :: ([ after ] as stmts)) :: (_ :: _ as stmtss) ) ->
          (* The next transaction contains a proof, and this account_update is in a new
             transaction, don't pair it with the next account_update.
          *)
          group_by_zkapp_command_rev
            (zkapp_command :: zkapp_commands)
            (stmts :: stmtss)
            ( intermediate_state ~kind:`New
                ~spec:(zkapp_segment_of_controls [ a1 ])
                ~before ~after
            :: acc )
      | ( []
          :: [ { authorization = (Signature _ | None_given) as a1; _ } ]
             :: ({ authorization = (Signature _ | None_given) as a2; _ }
                :: zkapp_command )
                :: zkapp_commands
        , [ _ ]
          :: [ before; _after1 ]
             :: (_before2 :: (after :: _ as stmts)) :: stmtss ) ->
          (* The next two zkapp_command do not contain proofs, the first is within a
             new transaction, and the second is within another new transaction.
             Pair them.
             Ok to get "use_full_commitment" of [a1] because neither of them
             contain a proof.
          *)
          group_by_zkapp_command_rev
            (zkapp_command :: zkapp_commands)
            (stmts :: stmtss)
            ( intermediate_state ~kind:`Two_new
                ~spec:(zkapp_segment_of_controls [ a1; a2 ])
                ~before ~after
            :: acc )
      | [ [ { authorization = a1; _ } ] ], (before :: after :: _) :: _ ->
          (* This account_update is the final account_update given. Prove it on its own. *)
          intermediate_state ~kind:`Same
            ~spec:(zkapp_segment_of_controls [ a1 ])
            ~before ~after
          :: acc
      | ( [] :: [ { authorization = a1; _ } ] :: [] :: _
        , [ _ ] :: (before :: after :: _) :: _ ) ->
          (* This account_update is the final account_update given, in a new transaction. Prove it
             on its own.
          *)
          intermediate_state ~kind:`New
            ~spec:(zkapp_segment_of_controls [ a1 ])
            ~before ~after
          :: acc
      | _, [] ->
          failwith "group_by_zkapp_command_rev: No statements remaining"
      | ([] | [ [] ]), _ ->
          failwith "group_by_zkapp_command_rev: Unmatched statements remaining"
      | [] :: _, [] :: _ ->
          failwith
            "group_by_zkapp_command_rev: No final statement for current \
             transaction"
      | [] :: _, (_ :: _ :: _) :: _ ->
          failwith
            "group_by_zkapp_command_rev: Unmatched statements for current \
             transaction"
      | [] :: [ _ ] :: _, [ _ ] :: (_ :: _ :: _ :: _) :: _ ->
          failwith
            "group_by_zkapp_command_rev: Unmatched statements for next \
             transaction"
      | [ []; [ _ ] ], [ _ ] :: [ _; _ ] :: _ :: _ ->
          failwith
            "group_by_zkapp_command_rev: Unmatched statements after next \
             transaction"
      | (_ :: _) :: _, ([] | [ _ ]) :: _ | (_ :: _ :: _) :: _, [ _; _ ] :: _ ->
          failwith
            "group_by_zkapp_command_rev: Too few statements remaining for the \
             current transaction"
      | ([] | [ _ ]) :: [] :: _, _ ->
          failwith
            "group_by_zkapp_command_rev: The next transaction has no \
             zkapp_command"
      | [] :: (_ :: _) :: _, _ :: ([] | [ _ ]) :: _
      | [] :: (_ :: _ :: _) :: _, _ :: [ _; _ ] :: _ ->
          failwith
            "group_by_zkapp_command_rev: Too few statements remaining for the \
             next transaction"
      | [ _ ] :: (_ :: _) :: _, _ :: ([] | [ _ ]) :: _ ->
          failwith
            "group_by_zkapp_command_rev: Too few statements remaining for the \
             next transaction"
      | [] :: [ _ ] :: (_ :: _) :: _, _ :: _ :: ([] | [ _ ]) :: _ ->
          failwith
            "group_by_zkapp_command_rev: Too few statements remaining for the \
             transaction after next"
      | ([] | [ _ ]) :: (_ :: _) :: _, [ _ ] ->
          failwith
            "group_by_zkapp_command_rev: No statements given for the next \
             transaction"
      | [] :: [ _ ] :: (_ :: _) :: _, [ _; _ :: _ :: _ ] ->
          failwith
            "group_by_zkapp_command_rev: No statements given for transaction \
             after next"
    in
    group_by_zkapp_command_rev zkapp_account_updatess stmtss []
end

(*Transaction_snark.Zkapp_command_segment.Basic.t*)
type possible_segments = Proved | Signed_single | Signed_pair

module Update_group = Make_update_group (struct
  type local_state = unit

  type global_state = unit

  type connecting_ledger_hash = unit

  type spec = possible_segments

  let zkapp_segment_of_controls controls : spec =
    match controls with
    | [ Control.Poly.Proof _ ] ->
        Proved
    | [ (Signature _ | None_given) ] ->
        Signed_single
    | [ (Signature _ | None_given); (Signature _ | None_given) ] ->
        Signed_pair
    | _ ->
        failwith "zkapp_segment_of_controls: Unsupported combination"
end)

let zkapp_cost ~proof_segments ~signed_single_segments ~signed_pair_segments
    ~(genesis_constants : Genesis_constants.t) () =
  (*10.26*np + 10.08*n2 + 9.14*n1 < 69.45*)
  let proof_cost = genesis_constants.zkapp_proof_update_cost in
  let signed_pair_cost = genesis_constants.zkapp_signed_pair_update_cost in
  let signed_single_cost = genesis_constants.zkapp_signed_single_update_cost in
  Float.(
    (proof_cost * of_int proof_segments)
    + (signed_pair_cost * of_int signed_pair_segments)
    + (signed_single_cost * of_int signed_single_segments))

(* Zkapp_command transactions are filtered using this predicate
   - when adding to the transaction pool
   - in incoming blocks
*)
let valid_size (type aux) ~(genesis_constants : Genesis_constants.t)
    (t :
      ((Account_update.Body.t, _, aux) Account_update.Poly.t, _, _) with_forest
      ) : unit Or_error.t =
  let events_elements events =
    List.fold events ~init:0 ~f:(fun acc event -> acc + Array.length event)
  in
  let statement_tuple = ((), (), ()) in
  let statements, num_event_elements, num_action_elements =
    Call_forest.fold t.account_updates
      ~init:([ statement_tuple ], 0, 0)
      ~f:(fun (acc, num_event_elements, num_action_elements) account_update ->
        let account_update_evs_elements =
          events_elements account_update.body.events
        in
        let account_update_seq_evs_elements =
          events_elements account_update.body.actions
        in
        ( statement_tuple :: acc
        , num_event_elements + account_update_evs_elements
        , num_action_elements + account_update_seq_evs_elements ) )
  in
  let groups =
    Update_group.group_by_zkapp_command_rev [ t ]
      ([ ((), (), ()) ] :: [ ((), (), ()) :: statements ])
  in
  let proof_segments, signed_single_segments, signed_pair_segments =
    List.fold ~init:(0, 0, 0) groups
      ~f:(fun (proof_segments, signed_singles, signed_pairs) { spec; _ } ->
        match spec with
        | Proved ->
            (proof_segments + 1, signed_singles, signed_pairs)
        | Signed_single ->
            (proof_segments, signed_singles + 1, signed_pairs)
        | Signed_pair ->
            (proof_segments, signed_singles, signed_pairs + 1) )
  in
  let cost_limit = genesis_constants.zkapp_transaction_cost_limit in
  let max_event_elements = genesis_constants.max_event_elements in
  let max_action_elements = genesis_constants.max_action_elements in
  let zkapp_cost_within_limit =
    Float.(
      zkapp_cost ~proof_segments ~signed_single_segments ~signed_pair_segments
        ~genesis_constants ()
      < cost_limit)
  in
  let valid_event_elements = num_event_elements <= max_event_elements in
  let valid_action_elements = num_action_elements <= max_action_elements in
  if zkapp_cost_within_limit && valid_event_elements && valid_action_elements
  then Ok ()
  else
    let proof_zkapp_command_err =
      if zkapp_cost_within_limit then None
      else Some (sprintf "zkapp transaction too expensive")
    in
    let events_err =
      if valid_event_elements then None
      else
        Some
          (sprintf "too many event elements (%d, max allowed is %d)"
             num_event_elements max_event_elements )
    in
    let actions_err =
      if valid_action_elements then None
      else
        Some
          (sprintf "too many sequence event elements (%d, max allowed is %d)"
             num_action_elements max_action_elements )
    in
    let err_msg =
      List.filter
        [ proof_zkapp_command_err; events_err; actions_err ]
        ~f:Option.is_some
      |> List.map ~f:(fun opt -> Option.value_exn opt)
      |> String.concat ~sep:"; "
    in
    Error (Error.of_string err_msg)

let has_zero_vesting_period
    (t :
      ( (Account_update.Body.t, 'p, 'aux) Account_update.Poly.t
      , _
      , _ )
      Call_forest.t
      Poly.t ) =
  Call_forest.exists t.account_updates ~f:(fun p ->
      match p.body.update.timing with
      | Keep ->
          false
      | Set { vesting_period; _ } ->
          Mina_numbers.Global_slot_span.(equal zero) vesting_period )

let is_incompatible_version
    (t :
      ( (Account_update.Body.t, 'p, 'aux) Account_update.Poly.t
      , _
      , _ )
      Call_forest.t
      Poly.t ) =
  Call_forest.exists t.account_updates ~f:(fun p ->
      match p.body.update.permissions with
      | Keep ->
          false
      | Set { set_verification_key = _auth, txn_version; _ } ->
          not Mina_numbers.Txn_version.(equal_to_current txn_version) )

let get_transaction_commitments ~signature_kind (zkapp_command : _ Poly.t) =
  let memo_hash = Signed_command_memo.hash zkapp_command.memo in
  let fee_payer_hash =
    Account_update.of_fee_payer zkapp_command.fee_payer
    |> Digest.Account_update.create ~signature_kind
  in
  let account_updates_hash = account_updates_hash zkapp_command in
  let txn_commitment = Transaction_commitment.create ~account_updates_hash in
  let full_txn_commitment =
    Transaction_commitment.create_complete txn_commitment ~memo_hash
      ~fee_payer_hash
  in
  (txn_commitment, full_txn_commitment)

let inner_query =
  lazy
    (Option.value_exn ~message:"Invariant: All projectable derivers are Some"
       Fields_derivers_zkapps.(inner_query (deriver @@ Derivers.o ())) )

module For_tests = struct
  let replace_vk vk (p : (Account_update.Body.t, _, _) Account_update.Poly.t) =
    { p with
      body =
        { p.body with
          update =
            { p.body.update with
              verification_key =
                (* replace dummy vks in vk Setting *)
                ( match p.body.update.verification_key with
                | Set _vk ->
                    Set vk
                | Keep ->
                    Keep )
            }
        ; authorization_kind =
            (* replace dummy vk hashes in authorization kind *)
            ( match p.body.authorization_kind with
            | Proof _vk_hash ->
                Proof (With_hash.hash vk)
            | ak ->
                ak )
        }
    }

  let replace_vks (t : t) vk =
    { t with
      account_updates = Call_forest.map t.account_updates ~f:(replace_vk vk)
    }
end

let%test "latest zkApp version" =
  (* if this test fails, update `Transaction_hash.hash_of_transaction_id`
     for latest version, then update this test
  *)
  Stable.Latest.version = 1
