(* TODO NOW: pull over ledger batching code (new impl of `of_ledger_subset_exn`, updated usage of ledgers in staged_ledger.ml) *)
(* TODO: refactor the misleading implementation of Ledger.foldi that confused me so much in the first place. *)

open Core
open Import
open Snark_params.Tick

let dedup_list ls ~comparator =
  let ls', _ =
    List.fold_right ls
      ~init:([], Set.empty comparator)
      ~f:(fun el (acc, seen) ->
        if Set.mem seen el then (acc, seen) else (el :: acc, Set.add seen el))
  in
  ls'

[%%versioned
module Stable = struct
  module V1 = struct
    type t =
      ( Ledger_hash.Stable.V1.t
      , Account_id.Stable.V1.t
      , Account.Stable.V1.t
      , Token_id.Stable.V1.t )
      Sparse_ledger_lib.Sparse_ledger.T.Stable.V1.t
    [@@deriving yojson, sexp]

    let to_latest = Fn.id
  end
end]

module Hash = struct
  include Ledger_hash

  let merge = Ledger_hash.merge
end

module Account = struct
  include Account

  let data_hash = Fn.compose Ledger_hash.of_digest Account.digest
end

module M =
  Sparse_ledger_lib.Sparse_ledger.Make (Hash) (Token_id) (Account_id) (Account)

type account_state = [ `Added | `Existed ] [@@deriving equal]

module L = struct
  type t = M.t ref

  type location = int

  let get : t -> location -> Account.t option =
   fun t loc ->
    Option.try_with (fun () ->
        let account = M.get_exn !t loc in
        if Public_key.Compressed.(equal empty account.public_key) then None
        else Some account)
    |> Option.bind ~f:Fn.id

  let location_of_account : t -> Account_id.t -> location option =
   fun t id -> Option.try_with (fun () -> M.find_index_exn !t id)

  let set : t -> location -> Account.t -> unit =
   fun t loc a -> t := M.set_exn !t loc a

  let get_or_create_exn :
      t -> Account_id.t -> account_state * Account.t * location =
   fun t id ->
    let loc = M.find_index_exn !t id in
    let account = M.get_exn !t loc in
    if Public_key.Compressed.(equal empty account.public_key) then (
      let public_key = Account_id.public_key id in
      let account' : Account.t =
        { account with
          delegate = Some public_key
        ; public_key
        ; token_id = Account_id.token_id id
        }
      in
      set t loc account' ;
      (`Added, account', loc) )
    else (`Existed, account, loc)

  let get_or_create t id = Or_error.try_with (fun () -> get_or_create_exn t id)

  let get_or_create_account :
      t -> Account_id.t -> Account.t -> (account_state * location) Or_error.t =
   fun t id to_set ->
    Or_error.try_with (fun () ->
        let loc = M.find_index_exn !t id in
        let a = M.get_exn !t loc in
        if Public_key.Compressed.(equal empty a.public_key) then (
          set t loc to_set ;
          (`Added, loc) )
        else (`Existed, loc))

  let remove_accounts_exn : t -> Account_id.t list -> unit =
   fun _t _xs -> failwith "remove_accounts_exn: not implemented"

  let merkle_root : t -> Ledger_hash.t = fun t -> M.merkle_root !t

  let with_ledger : depth:int -> f:(t -> 'a) -> 'a =
   fun ~depth:_ ~f:_ -> failwith "with_ledger: not implemented"

  let next_available_token : t -> Token_id.t =
   fun t -> M.next_available_token !t

  let set_next_available_token : t -> Token_id.t -> unit =
   fun t token -> t := { !t with next_available_token = token }
end

module T = Transaction_logic.Make (L)

[%%define_locally
M.
  ( of_hash
  , to_yojson
  , of_yojson
  , get_exn
  , path_exn
  , arm_exn
  , set_exn
  , find_index
  , find_index_exn
  , add_path
  , merkle_root
  , data
  , iteri
  , depth
  , next_available_token
  , next_available_index )]

(* TODO: share this cache globally across modules *)
let empty_hash =
  Empty_hashes.extensible_cache
    (module Ledger_hash)
    ~init_hash:(Ledger_hash.of_digest Account.empty_digest)

let of_root ~depth ~next_available_token ~next_available_index
    (h : Ledger_hash.t) =
  of_hash ~depth ~next_available_token ~next_available_index
    (* TODO: Is this of_digest casting really necessary? What's it doing? *)
    (Ledger_hash.of_digest (h :> Random_oracle.Digest.t))

let of_any_ledger_root ledger =
  let next_available_index =
    match Ledger.Any_ledger.M.last_filled ledger with
    | Some (Ledger.Location.Account addr) ->
        Option.map (Ledger.Addr.next addr) ~f:Ledger.Addr.to_int
    | Some _ ->
        failwith
          "unable to get next available index from ledger: last filled \
           location is invalid"
    | None ->
        Some 0
  in
  of_root
    ~depth:(Ledger.Any_ledger.M.depth ledger)
    ~next_available_token:(Ledger.Any_ledger.M.next_available_token ledger)
    ~next_available_index
    (Ledger.Any_ledger.M.merkle_root ledger)

let of_any_ledger (ledger : Ledger.Any_ledger.witness) =
  Ledger.Any_ledger.M.foldi ledger ~init:(of_any_ledger_root ledger)
    ~f:(fun _addr sparse_ledger account ->
      let loc =
        Option.value_exn
          (Ledger.Any_ledger.M.location_of_account ledger
             (Account.identifier account))
      in
      add_path sparse_ledger
        (Ledger.Any_ledger.M.merkle_path ledger loc)
        (Account.identifier account)
        (Option.value_exn (Ledger.Any_ledger.M.get ledger loc)))

let of_ledger_subset_exn' (ledger : Ledger.t) locs_and_ids =
  let locs, ids = List.unzip locs_and_ids in
  let paths =
    Ledger.merkle_path_batch ledger locs |> List.map ~f:(fun (_, path) -> path)
  in
  let accts =
    Ledger.get_batch ledger locs
    |> List.map ~f:(fun (_, acct) -> Option.value_exn acct)
  in
  List.zip_exn paths (List.zip_exn ids accts)
  |> List.fold_left
       ~init:
         (of_any_ledger_root (Ledger.Any_ledger.cast (module Ledger) ledger))
       ~f:(fun sparse_ledger (path, (id, acct)) ->
         add_path sparse_ledger path id acct)

let of_ledger_subset_exn (ledger : Ledger.t) keys =
  let keys = dedup_list keys ~comparator:(module Account_id) in
  let existing_account_locs_and_ids, missing_account_ids =
    keys
    |> Ledger.location_of_account_batch ledger
    |> List.partition_map ~f:(fun (key, loc_opt) ->
           match loc_opt with Some loc -> `Fst (loc, key) | None -> `Snd key)
  in
  let sparse_ledger =
    of_ledger_subset_exn' ledger existing_account_locs_and_ids
  in
  let new_accounts =
    let l = Ledger.copy ledger in
    missing_account_ids
    |> List.map ~f:(fun id ->
           let account : Account.t = Account.empty in
           let loc =
             Ledger.unsafe_create_account l id account |> Or_error.ok_exn
           in
           let path = Ledger.merkle_path l loc in
           (path, account))
    |> List.zip_exn missing_account_ids
  in
  let sparse_ledger =
    List.fold new_accounts ~init:sparse_ledger
      ~f:(fun sparse_ledger (key, (path, acct)) ->
        add_path sparse_ledger path key acct)
  in
  Debug_assert.debug_assert (fun () ->
      [%test_eq: Ledger_hash.t]
        (Ledger.merkle_root ledger)
        ( (merkle_root sparse_ledger :> Random_oracle.Digest.t)
        |> Ledger_hash.of_hash )) ;
  sparse_ledger

(* TODO: optimize this to batch as well (used during block production) *)
let of_ledger_index_subset_exn (ledger : Ledger.Any_ledger.witness) indexes =
  List.fold indexes ~init:(of_any_ledger_root ledger) ~f:(fun acc i ->
      let account = Ledger.Any_ledger.M.get_at_index_exn ledger i in
      add_path acc
        (Ledger.Any_ledger.M.merkle_path_at_index_exn ledger i)
        (Account.identifier account)
        account)

let%test_unit "of_ledger_subset_exn with keys that don't exist works" =
  let keygen () =
    let privkey = Private_key.create () in
    (privkey, Public_key.of_private_key_exn privkey |> Public_key.compress)
  in
  Ledger.with_ledger
    ~depth:Genesis_constants.Constraint_constants.for_unit_tests.ledger_depth
    ~f:(fun ledger ->
      let _, pub1 = keygen () in
      let _, pub2 = keygen () in
      let aid1 = Account_id.create pub1 Token_id.default in
      let aid2 = Account_id.create pub2 Token_id.default in
      let sl = of_ledger_subset_exn ledger [ aid1; aid2 ] in
      [%test_eq: Ledger_hash.t]
        (Ledger.merkle_root ledger)
        ((merkle_root sl :> Random_oracle.Digest.t) |> Ledger_hash.of_hash))

let next_index ~depth idx =
  if idx >= Sparse_ledger_lib.Sparse_ledger.max_index depth then None
  else Some (idx + 1)

let path_of_arm =
  List.map ~f:(function `Left, _, r -> `Left r | `Right, l, _ -> `Right l)

let left_empty_arm depth =
  let rec loop height =
    if height < 0 then []
    else
      let h = empty_hash height in
      (`Left, h, h) :: loop (height - 1)
  in
  List.rev (loop (depth - 1))

(** Derives the next arm of a merkle tree from the previous arm. Assumes that
    all hashes to the right of the previous arm are derived from empty leaves
    (thus, the next arm is a new arm in the tree). *)
let derive_next_arm_exn prev_arm =
  let is_right = function `Left, _, _ -> false | `Right, _, _ -> true in
  let flip_left ~on_right ~empty_error = function
    | [] ->
        failwith empty_error
    | (`Left, l, r) :: rest ->
        (`Right, l, r) :: rest
    | (`Right, _, _) :: _ ->
        on_right ()
  in
  let rec flip_rights rights height =
    match rights with
    | [] ->
        []
    | (`Right, _, _) :: rest ->
        let h = empty_hash height in
        (`Left, h, h) :: flip_rights rest (height + 1)
    | _ ->
        failwith "this shouldn't happen"
  in
  flip_left prev_arm ~empty_error:"invalid arm" ~on_right:(fun () ->
      let rights_to_flip, rest = List.split_while prev_arm ~f:is_right in
      let rest' =
        flip_left rest ~empty_error:"no space left in ledger"
          ~on_right:(fun () -> failwith "this shouldn't happen")
      in
      flip_rights rights_to_flip 0 @ rest')

let%test_unit "adding paths generated via derive_next_arm_exn does not \
               conflict with the initial merkle root of the ledger" =
  (* initial account to store in the left-most position (just needs to have some hash different than the empty account hash) *)
  let account = { Account.empty with balance = Currency.Balance.of_int 100 } in
  (* right leaning hashes for merkle proof *)
  let path_hashes = List.map [ 0; 1; 2 ] ~f:empty_hash in
  let path = List.map path_hashes ~f:(fun h -> `Left h) in
  let root, _, arm_reversed =
    List.fold_left path_hashes
      ~init:(Ledger_hash.of_digest (Account.digest account), 0, [])
      ~f:(fun (hash, height, acc) path_hash ->
        ( Ledger_hash.merge ~height hash path_hash
        , height + 1
        , (`Left, hash, path_hash) :: acc ))
  in
  let arm = List.rev arm_reversed in
  let ledger =
    of_root ~depth:3
      ~next_available_token:(Token_id.of_uint64 Unsigned_extended.UInt64.one)
      ~next_available_index:(Some 1) root
  in
  let ledger = add_path ledger path (Account.identifier account) account in
  let ledger, _ =
    List.fold_left [ 1; 2; 3; 4; 5; 6; 7 ] ~init:(ledger, arm)
      ~f:(fun (ledger, prev_arm) _ ->
        let next_arm = derive_next_arm_exn prev_arm in
        let ledger =
          add_path ledger (path_of_arm next_arm)
            (Account.identifier Account.empty)
            Account.empty
        in
        (ledger, next_arm))
  in
  [%test_eq: Ledger_hash.t] (merkle_root ledger) root

let of_sparse_ledger_subset_exn base_ledger account_ids =
  let account_ids = dedup_list account_ids ~comparator:(module Account_id) in
  let add_existing_accounts l =
    List.fold_right account_ids ~init:(l, [])
      ~f:(fun id (l, missing_accounts) ->
        match find_index base_ledger id with
        | Some idx ->
            let account = get_exn base_ledger idx in
            let path = path_exn base_ledger idx in
            (add_path l path id account, missing_accounts)
        | None ->
            (l, id :: missing_accounts))
  in
  let add_missing_accounts l missing_account_ids =
    let next_idx =
      Option.value_exn (next_available_index l)
        ~message:"not enough space in ledger"
    in
    let last_arm =
      if next_idx > 0 then arm_exn base_ledger (next_idx - 1)
      else left_empty_arm (depth l)
    in
    let result, _, _ =
      (* TODO: we could just check the remaining available slots in the ledger upfront instead of folding over the index (which is otherwise unused here) *)
      List.fold_left missing_account_ids ~init:(l, last_arm, Some next_idx)
        ~f:(fun (l, prev_arm, idx_opt) id ->
          let idx =
            Option.value_exn idx_opt ~message:"not enough space in ledger"
          in
          let next_arm = derive_next_arm_exn prev_arm in
          ( add_path l (path_of_arm next_arm) id Account.empty
          , next_arm
          , next_index ~depth:(depth l) idx ))
    in
    result
  in
  let result_ledger =
    let ledger =
      of_root ~depth:(depth base_ledger)
        ~next_available_token:(next_available_token base_ledger)
        ~next_available_index:(next_available_index base_ledger)
        (merkle_root base_ledger)
    in
    let ledger, missing_account_ids = add_existing_accounts ledger in
    if List.is_empty missing_account_ids then ledger
    else add_missing_accounts ledger missing_account_ids
  in
  Debug_assert.debug_assert (fun () ->
      [%test_eq: Ledger_hash.t]
        (merkle_root result_ledger)
        (merkle_root base_ledger)) ;
  result_ledger

(* IMPORTANT TODO: rightmost path in parent sparse ledger must exist in order for derivation on new accounts to work *)
(* ^^^ should probably setup a test to ensure the error message is decent *)

(* challenge: computing paths to empty accounts from another sparse ledger
    universal issue: need to have path to last account loaded on any sparse ledger this is called on (read: every sparse ledger)
    options:
    - add accounts to copy of sparse ledger, get paths from that
      issue: add_account_exn doens't work
        - definition as is throws exn when account isn't already indexed as Account.empty
        - logic in sparse ledger is not using the new next_available_index yet (pull code from other branch)
    - compute the path dynamically
      issue: complicated messy code
    - don't load missing accounts at all
      issue: defers computation to later
*)

let%test_module "of_sparse_ledger_subset_exn" =
  ( module struct
    (* TODO: let check_predicates ~expected_accounts ledger = ... *)

    (* Not really a great solution for refining generators, but works ok so long as predicate fails on only a small subset of it's domain. *)
    let gen_until ?(max_retries = 1_000) p g =
      let open Quickcheck.Let_syntax in
      let rec loop n =
        if n < max_retries then
          let%bind x = g in
          if p x then return x else loop (n + 1)
        else
          failwith
            "gen_until: failed to generate a value that matched specified \
             predicate"
      in
      loop 0

    (* Generates a unattached ledger mask with a random amount of accounts, along with a random selection of account
       locations pointing to a subset of accounts in the ledger. *)
    let gen_ledger_with_subset_selection ?(min_size = 1) ?(min_subset_size = 0)
        ?(min_free_space = 0) depth =
      let open Quickcheck.Let_syntax in
      let max_size = Int.pow 2 depth in
      assert (0 <= min_free_space && min_free_space <= max_size) ;
      assert (0 <= min_size && min_size <= max_size - min_free_space) ;
      let%bind size = Int.gen_incl min_size (max_size - min_free_space) in
      let%bind accounts = List.gen_with_length size Account.gen in
      let%map indices =
        gen_until
          (fun l -> List.length l > min_subset_size)
          (List.gen_filtered (List.init size ~f:Fn.id))
      in
      let ledger = Ledger.create_ephemeral ~depth () in
      List.iter accounts ~f:(fun acct ->
          Ledger.create_new_account_exn ledger (Account.identifier acct) acct) ;
      let account_ids =
        List.map indices ~f:(fun i ->
            Ledger.Location.Account
              (Ledger.Addr.of_int_exn ~ledger_depth:depth i)
            |> Ledger.get ledger |> Option.value_exn |> Account.identifier)
      in
      (ledger, account_ids)

    let%test_unit "when all accounts already exist" =
      let depth = 4 in
      Quickcheck.test (gen_ledger_with_subset_selection depth) ~trials:100
        ~f:(fun (ledger, account_ids) ->
          let sl = of_ledger_subset_exn ledger account_ids in
          [%test_result: Ledger_hash.t]
            ~expect:(Ledger.merkle_root ledger)
            (merkle_root @@ of_sparse_ledger_subset_exn sl account_ids))

    let%test_unit "with new accounts" =
      let depth = 4 in
      let gen =
        let open Quickcheck.Let_syntax in
        let%bind num_new_accounts = Int.gen_incl 1 (Int.pow 2 depth - 1) in
        let%bind new_account_ids =
          List.gen_with_length num_new_accounts Account_id.gen
        in
        let%map ledger, existing_account_ids =
          gen_ledger_with_subset_selection ~min_free_space:num_new_accounts
            depth
        in
        (ledger, existing_account_ids @ new_account_ids)
      in
      Quickcheck.test gen ~trials:100 ~f:(fun (ledger, account_ids) ->
          let sl =
            of_ledger_subset_exn ledger
              (ledger |> Ledger.accounts |> Set.elements)
          in
          [%test_result: Ledger_hash.t]
            ~expect:(Ledger.merkle_root ledger)
            (merkle_root @@ of_sparse_ledger_subset_exn sl account_ids))

    let%test_unit "on an empty ledger" =
      let depth = 4 in
      let gen =
        let open Quickcheck.Let_syntax in
        let%bind n = Int.gen_incl 1 (Int.pow 2 depth - 1) in
        List.gen_with_length n Account_id.gen
      in
      Quickcheck.test gen ~trials:100 ~f:(fun account_ids ->
          let ledger = Ledger.create_ephemeral ~depth () in
          let sl = of_ledger_subset_exn ledger [] in
          [%test_result: Ledger_hash.t]
            ~expect:(Ledger.merkle_root ledger)
            (merkle_root @@ of_sparse_ledger_subset_exn sl account_ids))
  end )

let get_or_initialize_exn account_id t idx =
  let account = get_exn t idx in
  if Public_key.Compressed.(equal empty account.public_key) then
    let public_key = Account_id.public_key account_id in
    let token_id = Account_id.token_id account_id in
    let delegate =
      (* Only allow delegation if this account is for the default token. *)
      if Token_id.(equal default) token_id then Some public_key else None
    in
    ( `Added
    , { account with
        delegate
      ; public_key
      ; token_id = Account_id.token_id account_id
      } )
  else (`Existed, account)

let has_locked_tokens_exn ~global_slot ~account_id t =
  let idx = find_index_exn t account_id in
  let _, account = get_or_initialize_exn account_id t idx in
  Account.has_locked_tokens ~global_slot account

let apply_transaction_logic f t x =
  let open Or_error.Let_syntax in
  let t' = ref t in
  let%map app = f t' x in
  (!t', app)

let apply_user_command ~constraint_constants ~txn_global_slot =
  apply_transaction_logic
    (T.apply_user_command ~constraint_constants ~txn_global_slot)

let apply_transaction' = T.apply_transaction

let apply_transaction ~constraint_constants ~txn_state_view =
  apply_transaction_logic
    (T.apply_transaction ~constraint_constants ~txn_state_view)

let merkle_root t = Ledger_hash.of_hash (merkle_root t :> Random_oracle.Digest.t)

let depth t = M.depth t

let handler t =
  let ledger = ref t in
  let path_exn idx =
    List.map (path_exn !ledger idx) ~f:(function `Left h -> h | `Right h -> h)
  in
  stage (fun (With { request; respond }) ->
      match request with
      | Ledger_hash.Get_element idx ->
          let elt = get_exn !ledger idx in
          let path = (path_exn idx :> Random_oracle.Digest.t list) in
          respond (Provide (elt, path))
      | Ledger_hash.Get_path idx ->
          let path = (path_exn idx :> Random_oracle.Digest.t list) in
          respond (Provide path)
      | Ledger_hash.Set (idx, account) ->
          ledger := set_exn !ledger idx account ;
          respond (Provide ())
      | Ledger_hash.Find_index pk ->
          let index = find_index_exn !ledger pk in
          respond (Provide index)
      | _ ->
          unhandled)

let snapp_accounts (ledger : t) (t : Transaction.t) =
  match t with
  | Command (Signed_command _) | Fee_transfer _ | Coinbase _ ->
      (None, None)
  | Command (Snapp_command c) -> (
      let token_id = Snapp_command.token_id c in
      let get pk =
        Option.try_with (fun () ->
            ( find_index_exn ledger (Account_id.create pk token_id)
            |> get_exn ledger )
              .snapp)
        |> Option.join
      in
      match Snapp_command.to_payload c with
      | Zero_proved p ->
          (get p.one.body.pk, get p.two.body.pk)
      | One_proved p ->
          (get p.one.body.pk, get p.two.body.pk)
      | Two_proved p ->
          (get p.one.body.pk, get p.two.body.pk) )
