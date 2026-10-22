open Core_kernel
open Async_kernel
open Pipe_lib
open Network_peer

type Structured_log_events.t += Snarked_ledger_synced
  [@@deriving register_event { msg = "Snarked database sync'd. All done" }]

(** Run f recursively n times, starting with value r.
    e.g. funpow 3 f r = f (f (f r)) *)
let rec funpow n f r = if n > 0 then funpow (n - 1) f (f r) else r

module Query = struct
  [%%versioned
  module Stable = struct
    module V2 = struct
      type 'addr t =
        | What_child_hashes of 'addr * int
            (** What are the hashes of the children of this address? 
            If depth > 1 then we get the leaves of a subtree rooted
            at address and of the given depth. 
            For depth = 1 we have the simplest case with just the 2
            direct children.
            *)
        | What_contents of 'addr
            (** What accounts are at this address? addr must have depth
            tree_depth - account_subtree_height *)
        | Num_accounts
            (** How many accounts are there? Used to size data structure and
            figure out what part of the tree is filled in. *)
      [@@deriving sexp, yojson, hash, compare]
    end

    module V1 = struct
      type 'addr t =
        | What_child_hashes of 'addr
            (** What are the hashes of the children of this address? *)
        | What_contents of 'addr
            (** What accounts are at this address? addr must have depth
            tree_depth - account_subtree_height *)
        | Num_accounts
            (** How many accounts are there? Used to size data structure and
            figure out what part of the tree is filled in. *)
      [@@deriving sexp, yojson, hash, compare]

      let to_latest : 'a t -> 'a V2.t = function
        | What_child_hashes a ->
            What_child_hashes (a, 1)
        | What_contents a ->
            What_contents a
        | Num_accounts ->
            Num_accounts
    end
  end]
end

module Answer = struct
  [%%versioned
  module Stable = struct
    module V2 = struct
      type ('hash, 'account) t =
        | Child_hashes_are of
            'hash Mina_stdlib.Bounded_types.ArrayN4000.Stable.V1.t
            (** The requested addresses' children have these hashes.
            May be any power of 2 number of children, and not necessarily 
            immediate children  *)
        | Contents_are of 'account list
            (** The requested address has these accounts *)
        | Num_accounts of int * 'hash
            (** There are this many accounts and the smallest subtree that
                contains all non-empty nodes has this hash. *)
      [@@deriving sexp, yojson]
    end
  end]
end

type daemon_config = { max_subtree_depth : int; default_subtree_depth : int }

let create_config ~(compile_config : Mina_compile_config.t) ~max_subtree_depth
    ~default_subtree_depth () =
  { max_subtree_depth =
      Option.value ~default:compile_config.sync_ledger_max_subtree_depth
        max_subtree_depth
  ; default_subtree_depth =
      Option.value ~default:compile_config.sync_ledger_default_subtree_depth
        default_subtree_depth
  }

module type CONTEXT = sig
  val logger : Logger.t

  val ledger_sync_config : daemon_config
end

(** A snapshot of how far a ledger sync has progressed, for reporting. *)
module Progress = struct
  type t =
    { targets : int
          (** How many times the sync has been given a new root to reach. *)
    ; target_set_at : Core.Time.t option
          (** When the current target was set. *)
    ; pending_child_hashes : int
          (** How many inner nodes the sync is waiting for the children of. *)
    ; pending_contents : int
          (** How many account subtrees the sync is waiting for the accounts
              of. *)
    ; synced : bool  (** Whether the ledger has reached the current target. *)
    ; answers_accepted : int
          (** How many answers have added to the ledger or confirmed part of
              it. *)
    ; answers_ignored : int
          (** How many answers have arrived for queries the sync no longer
              needed, such as those for an earlier target. *)
    ; answers_rejected : int
          (** How many answers have been invalid, and their queries asked
              again. *)
    ; last_accepted_answer_at : Core.Time.t option
          (** When an answer was last accepted. *)
    ; num_accounts : int option
          (** How many accounts the current target holds, once a peer has
              said. *)
    ; accounts_settled : int
          (** How many of the current target's accounts the ledger is known
              to hold, whether received or already present. *)
    ; accounts_received : int
          (** How many accounts peers have sent, over all targets. *)
    }
end

module type Inputs_base_intf = sig
  module Addr : module type of Merkle_address

  module Account : sig
    type t [@@deriving bin_io, sexp, yojson]
  end

  module Hash : Merkle_ledger.Intf.Hash with type account := Account.t

  module Root_hash : sig
    type t [@@deriving equal, sexp, yojson]

    val to_hash : t -> Hash.t
  end

  val account_subtree_height : int
end

module type Responder_inputs_intf = sig
  include Inputs_base_intf

  module MT :
    Merkle_ledger.Intf.SYNC_CANDIDATE
      with type hash := Hash.t
       and type root_hash := Root_hash.t
       and type addr := Addr.t
       and type account := Account.t
end

module type Inputs_intf = sig
  include Inputs_base_intf

  module MT :
    Merkle_ledger.Intf.SYNC_RECIPIENT
      with type hash := Hash.t
       and type root_hash := Root_hash.t
       and type addr := Addr.t
       and type account := Account.t
end

module type RESPONDER = sig
  type merkle_tree

  type query

  type answer

  module Responder : sig
    type t

    val create :
         merkle_tree
      -> (query -> unit)
      -> context:(module CONTEXT)
      -> trust_system:Trust_system.t
      -> t

    val answer_query :
      t -> query Envelope.Incoming.t -> answer Or_error.t Deferred.t
  end
end

module type S = sig
  type 'a t [@@deriving sexp]

  type merkle_tree

  type merkle_path

  type hash

  type root_hash

  type addr

  type diff

  type account

  type index = int

  type query

  type answer

  include
    RESPONDER
      with type merkle_tree := merkle_tree
       and type query := query
       and type answer := answer

  val create :
       merkle_tree
    -> context:(module CONTEXT)
    -> trust_system:Trust_system.t
    -> 'a t

  val answer_writer :
       'a t
    -> (root_hash * query * answer Envelope.Incoming.t) Linear_pipe.Writer.t

  val query_reader : 'a t -> (root_hash * query) Linear_pipe.Reader.t

  (** The root hash being synced to, or [None] before the first [new_goal]. It
      changes to a new target before any query for that target is written to
      [query_reader], and is closed by [destroy]. *)
  val target : 'a t -> root_hash option Broadcast_pipe.Reader.t

  val destroy : 'a t -> unit

  val new_goal :
       'a t
    -> root_hash
    -> data:'a
    -> equal:('a -> 'a -> bool)
    -> [ `Repeat | `New | `Update_data ]

  val peek_valid_tree : 'a t -> merkle_tree option

  val valid_tree : 'a t -> (merkle_tree * 'a) Deferred.t

  val wait_until_valid :
       'a t
    -> root_hash
    -> [ `Ok of merkle_tree | `Target_changed of root_hash option * root_hash ]
       Deferred.t

  val fetch :
       'a t
    -> root_hash
    -> data:'a
    -> equal:('a -> 'a -> bool)
    -> [ `Ok of merkle_tree | `Target_changed of root_hash option * root_hash ]
       Deferred.t

  val apply_or_queue_diff : 'a t -> diff -> unit

  val merkle_path_at_addr : 'a t -> addr -> merkle_path Or_error.t

  val get_account_at_addr : 'a t -> addr -> account Or_error.t

  (** How far the sync has progressed towards its current target. Until the
      new target's account count arrives, the pending work counted is that of
      the previous target. *)
  val progress : 'a t -> Progress.t

  val handle_num_accounts :
       'a t
    -> int
    -> hash
    -> [ `Success | `Hash_mismatch of hash * hash | `Depth_mismatch of int ]

  module For_test : sig
    val num_accounts_answer : merkle_tree -> int * hash
  end
end

module Make_responder (Inputs : Responder_inputs_intf) : sig
  open Inputs

  include
    RESPONDER
      with type merkle_tree := MT.t
       and type query := Addr.t Query.t
       and type answer := (Hash.t, Account.t) Answer.t

  val intermediate_range : int -> Addr.t -> int -> Addr.t array

  val num_accounts_answer : MT.t -> int * Hash.t
end = struct
  open Inputs

  type answer = (Hash.t, Account.t) Answer.t

  type query = Addr.t Query.t

  (* Provides addresses at an specific depth from this address *)
  let intermediate_range ledger_depth addr i =
    Array.init (1 lsl i) ~f:(fun idx ->
        Addr.extend_exn ~ledger_depth addr ~num_bits:i (Int64.of_int idx) )

  let num_accounts_answer mt =
    let count = MT.num_accounts mt in
    let height = Int.ceil_log2 count in
    (* FIXME: bug when height=0 https://github.com/o1-labs/nanobit/issues/365 *)
    let depth = MT.depth mt in
    let content_root_addr =
      funpow (depth - height)
        (fun a ->
          Addr.child_exn ~ledger_depth:depth a Mina_stdlib.Direction.Left )
        (Addr.root ())
    in
    (count, MT.get_inner_hash_at_addr_exn mt content_root_addr)

  module Responder = struct
    type t =
      { mt : MT.t
      ; f : query -> unit
      ; context : (module CONTEXT)
      ; trust_system : Trust_system.t
      }

    let create :
           MT.t
        -> (query -> unit)
        -> context:(module CONTEXT)
        -> trust_system:Trust_system.t
        -> t =
     fun mt f ~context ~trust_system -> { mt; f; context; trust_system }

    let answer_query :
        t -> query Envelope.Incoming.t -> answer Or_error.t Deferred.t =
     fun { mt; f; context; trust_system } query_envelope ->
      let open (val context) in
      let open Trust_system in
      let ledger_depth = MT.depth mt in
      let sender = Envelope.Incoming.sender query_envelope in
      let query = Envelope.Incoming.data query_envelope in
      f query ;
      let response_or_punish =
        match query with
        | What_contents a ->
            if Addr.height ~ledger_depth a > account_subtree_height then
              Either.Second
                ( Actions.Violated_protocol
                , Some
                    ( "Requested too big of a subtree at once"
                    , [ ("addr", Addr.to_yojson a) ] ) )
            else
              let addresses_and_accounts =
                List.sort ~compare:(fun (addr1, _) (addr2, _) ->
                    Addr.compare addr1 addr2 )
                @@ MT.get_all_accounts_rooted_at_exn mt a
                (* can't actually throw *)
              in
              let addresses, accounts = List.unzip addresses_and_accounts in
              if List.is_empty addresses then
                (* Peer should know what portions of the tree are full from the
                   Num_accounts query. *)
                Either.Second
                  ( Actions.Violated_protocol
                  , Some
                      ("Requested empty subtree", [ ("addr", Addr.to_yojson a) ])
                  )
              else
                let first_address, rest_address =
                  (List.hd_exn addresses, List.tl_exn addresses)
                in
                let missing_address, is_compact =
                  List.fold rest_address
                    ~init:(Addr.next first_address, true)
                    ~f:(fun (expected_address, is_compact) actual_address ->
                      if
                        is_compact
                        && [%equal: Addr.t option] expected_address
                             (Some actual_address)
                      then (Addr.next actual_address, true)
                      else (expected_address, false) )
                in
                if not is_compact then (
                  (* indicates our ledger is invalid somehow. *)
                  [%log fatal]
                    ~metadata:
                      [ ( "missing_address"
                        , Addr.to_yojson (Option.value_exn missing_address) )
                      ; ( "addresses_and_accounts"
                        , `List
                            (List.map addresses_and_accounts
                               ~f:(fun (addr, account) ->
                                 `Tuple
                                   [ Addr.to_yojson addr
                                   ; Account.to_yojson account
                                   ] ) ) )
                      ]
                    "Missing an account at address: $missing_address inside \
                     the list: $addresses_and_accounts" ;
                  assert false )
                else Either.First (Answer.Contents_are accounts)
        | Num_accounts ->
            let count, content_root = num_accounts_answer mt in
            Either.First (Num_accounts (count, content_root))
        | What_child_hashes (a, subtree_depth) -> (
            match subtree_depth with
            | n when n >= 1 -> (
                let subtree_depth =
                  min n ledger_sync_config.max_subtree_depth
                in
                let ledger_depth = MT.depth mt in
                let addresses =
                  intermediate_range ledger_depth a subtree_depth
                in
                match
                  Or_error.try_with (fun () ->
                      let get_hash a = MT.get_inner_hash_at_addr_exn mt a in
                      let hashes = Array.map addresses ~f:get_hash in
                      Answer.Child_hashes_are hashes )
                with
                | Ok answer ->
                    Either.First answer
                | Error e ->
                    [%log error]
                      ~metadata:[ ("error", Error_json.error_to_yojson e) ]
                      "When handling What_child_hashes request, the following \
                       error happended: $error" ;
                    Either.Second
                      ( Actions.Violated_protocol
                      , Some
                          ( "Invalid address in What_child_hashes request"
                          , [ ("addr", Addr.to_yojson a) ] ) ) )
            | _ ->
                [%log error]
                  "When handling What_child_hashes request, the depth was \
                   outside the valid range" ;
                Either.Second
                  ( Actions.Violated_protocol
                  , Some
                      ( "Invalid depth requested in What_child_hashes request"
                      , [ ("addr", Addr.to_yojson a) ] ) ) )
      in

      match response_or_punish with
      | Either.First answer ->
          Deferred.return @@ Ok answer
      | Either.Second action ->
          let%map _ =
            record_envelope_sender trust_system logger sender action
          in
          let err =
            Option.value_map ~default:"Violated protocol" (snd action) ~f:fst
          in
          Or_error.error_string err
  end
end

(*

Every node of the merkle tree is always in one of three states:

- Fresh.
  The current contents for this node in the MT match what we
  expect.
- Stale
  The current contents for this node in the MT do _not_ match
  what we expect.
- Unknown.
  We don't know what to expect yet.


Although every node conceptually has one of these states, and can
make a transition at any time, the syncer operates only along a
"frontier" of the tree, which consists of the deepest Stale nodes.

The goal of the ledger syncer is to make the root node be fresh,
starting from it being stale.

The syncer usually operates exclusively on these frontier nodes
and their direct children. However, the goal hash can change
while the syncer is running, and at that point every non-root node
conceptually becomes Unknown, and we need to restart. However, we
don't need to restart completely: in practice, only small portions
of the merkle tree change between goals, and we can re-use the "Stale"
nodes we already have if the expected hash doesn't change.

*)
(*
Note: while syncing, the underlying ledger is in an
indeterminate state. We're mutating hashes at internal
nodes without updating their children. In fact, we
don't even set all the hashes for the internal nodes!
(When we hit a height=N subtree, we don't do anything
with the hashes in the bottomost N-1 internal nodes).
*)

module Make (Inputs : Inputs_intf) : sig
  open Inputs

  include
    S
      with type merkle_tree := MT.t
       and type hash := Hash.t
       and type root_hash := Root_hash.t
       and type addr := Addr.t
       and type merkle_path := MT.path
       and type account := Account.t
       and type query := Addr.t Query.t
       and type answer := (Hash.t, Account.t) Answer.t
end = struct
  open Inputs

  type diff = unit

  type index = int

  type answer = (Hash.t, Account.t) Answer.t

  type query = Addr.t Query.t

  include Make_responder (Inputs)

  type 'a t =
    { mutable desired_root : Root_hash.t option
    ; mutable auxiliary_data : 'a option
    ; tree : MT.t
    ; trust_system : Trust_system.t
    ; answers :
        (Root_hash.t * query * answer Envelope.Incoming.t) Linear_pipe.Reader.t
    ; answer_writer :
        (Root_hash.t * query * answer Envelope.Incoming.t) Linear_pipe.Writer.t
    ; queries : (Root_hash.t * query) Linear_pipe.Writer.t
    ; query_reader : (Root_hash.t * query) Linear_pipe.Reader.t
    ; target : Root_hash.t option Broadcast_pipe.Reader.t
    ; target_writer : Root_hash.t option Broadcast_pipe.Writer.t
    ; waiting_parents : Hash.t Addr.Table.t
          (** Addresses we are waiting for the children of, and the expected
              hash of the node with the address. *)
    ; waiting_content : Hash.t Addr.Table.t
    ; mutable validity_listener :
        [ `Ok | `Target_changed of Root_hash.t option * Root_hash.t ] Ivar.t
    ; context : (module CONTEXT)
    ; mutable targets : int
    ; mutable target_set_at : Core.Time.t option
    ; mutable answers_accepted : int
    ; mutable answers_ignored : int
    ; mutable answers_rejected : int
    ; mutable last_accepted_answer_at : Core.Time.t option
    ; mutable num_accounts : int option
    ; mutable accounts_settled : int
    ; mutable accounts_received : int
    }

  let t_of_sexp _ = failwith "t_of_sexp: not implemented"

  let sexp_of_t _ = failwith "sexp_of_t: not implemented"

  let desired_root_exn { desired_root; _ } = desired_root |> Option.value_exn

  let destroy t =
    Linear_pipe.close_read t.answers ;
    Linear_pipe.close_read t.query_reader ;
    try Broadcast_pipe.Writer.close t.target_writer
    with Broadcast_pipe.Already_closed _ -> ()

  let answer_writer t = t.answer_writer

  let query_reader t = t.query_reader

  let target t = t.target

  let expect_children : 'a t -> Addr.t -> Hash.t -> unit =
   fun t parent_addr expected ->
    let open (val t.context) in
    [%log trace]
      ~metadata:
        [ ("parent_address", Addr.to_yojson parent_addr)
        ; ("hash", Hash.to_yojson expected)
        ]
      "Expecting children parent $parent_address, expected: $hash" ;
    Addr.Table.set t.waiting_parents ~key:parent_addr ~data:expected

  let expect_content : 'a t -> Addr.t -> Hash.t -> unit =
   fun t addr expected ->
    let open (val t.context) in
    [%log trace]
      ~metadata:
        [ ("address", Addr.to_yojson addr); ("hash", Hash.to_yojson expected) ]
      "Expecting content addr $address, expected: $hash" ;
    Addr.Table.set t.waiting_content ~key:addr ~data:expected

  (** Count the accounts under [addr] as held, once they match the target. *)
  let settle : 'a t -> Addr.t -> unit =
   fun t addr ->
    Option.iter t.num_accounts ~f:(fun num_accounts ->
        let height = Addr.height ~ledger_depth:(MT.depth t.tree) addr in
        let first = Addr.to_int addr lsl height in
        let last = Int.min num_accounts (first + (1 lsl height)) in
        t.accounts_settled <- t.accounts_settled + Int.max 0 (last - first) )

  (* Merges each 2 contigous nodes, halving the size of the array *)
  let merge_siblings : Hash.t array -> index -> Hash.t array =
   fun nodes height ->
    let len = Array.length nodes in
    if len mod 2 <> 0 then failwith "length must be even" ;
    let half_len = len / 2 in
    let f i = Hash.merge ~height nodes.(2 * i) nodes.((2 * i) + 1) in
    Array.init half_len ~f

  (* Assumes nodes to be a power of 2 and merges them into their common root *)
  let rec merge_many : Hash.t array -> index -> Hash.t =
   fun nodes height ->
    let len = Array.length nodes in
    match len with
    | 1 ->
        nodes.(0)
    | _ ->
        let half = merge_siblings nodes height in
        merge_many half (height + 1)

  let merge_many : Hash.t array -> index -> index -> Hash.t =
   fun nodes height subtree_depth ->
    let bottom_height = height - subtree_depth in
    let hash = merge_many nodes bottom_height in
    hash

  (** The hash [addr] would have if [content] were written to the leaves under
      it. As with [MT.set_all_accounts_rooted_at_exn], leaves past the end of
      [content] are empty. *)
  let hash_of_content : 'a t -> Addr.t -> Account.t list -> Hash.t =
   fun t addr content ->
    let height = Addr.height ~ledger_depth:(MT.depth t.tree) addr in
    let content_hashes = Array.of_list_map content ~f:Hash.hash_account in
    let leaf_hashes =
      Array.init (1 lsl height) ~f:(fun i ->
          if i < Array.length content_hashes then content_hashes.(i)
          else Hash.empty_account )
    in
    merge_many leaf_hashes height height

  (** Given an address and the accounts below that address, fill in the tree
      with them. *)
  let add_content :
         'a t
      -> Addr.t
      -> expected:Hash.t
      -> Account.t list
      -> [ `Success
         | `Hash_mismatch of Hash.t * Hash.t  (** expected hash, actual *)
         | `Content_length_mismatch of int * int  (** received, capacity *) ] =
   fun t addr ~expected content ->
    let open (val t.context) in
    let capacity = 1 lsl Addr.height ~ledger_depth:(MT.depth t.tree) addr in
    if List.length content > capacity then
      (* Content longer than the subtree under [addr] is rejected and requeued;
         [addr] stays in [waiting_content] so the retry is accepted. *)
      `Content_length_mismatch (List.length content, capacity)
    else
      let actual = hash_of_content t addr content in
      if Hash.equal actual expected then (
        (* TODO #444 should we batch all the updates and do them at the end? *)
        MT.set_all_accounts_rooted_at_exn t.tree addr content ;
        Addr.Table.remove t.waiting_content addr ;
        settle t addr ;
        t.accounts_received <- t.accounts_received + List.length content ;
        [%log trace]
          ~metadata:
            [ ("address", Addr.to_yojson addr)
            ; ("hash", Hash.to_yojson expected)
            ]
          "Found content addr $address, with hash $hash, removing from waiting \
           content" ;
        `Success )
      else
        (* Content with the wrong hash is rejected and requeued; [addr] stays
           in [waiting_content] so the retry is accepted. *)
        `Hash_mismatch (expected, actual)

  (* Adds the subtree given as the 2^k subtree leaves with the given prefix address *)
  (* Returns next nodes to be checked *)
  let add_subtree :
         'a t
      -> Addr.t
      -> expected:Hash.t
      -> Hash.t array
      -> int
      -> [ `Good of (Addr.t * Hash.t) array
         | `Hash_mismatch of Hash.t * Hash.t
         | `Invalid_length ] =
   fun t addr ~expected nodes requested_depth ->
    let open (val t.context) in
    let len = Array.length nodes in
    let is_power = Int.is_pow2 len in
    let is_more_than_two = len >= 2 in
    let subtree_depth = Int.ceil_log2 len in
    let less_than_requested = subtree_depth <= requested_depth in
    let valid_length = is_power && is_more_than_two && less_than_requested in
    if valid_length then
      let ledger_depth = MT.depth t.tree in
      let merged =
        merge_many nodes (ledger_depth - Addr.depth addr) subtree_depth
      in
      if Hash.equal expected merged then (
        Addr.Table.remove t.waiting_parents addr ;
        let addresses = intermediate_range ledger_depth addr subtree_depth in
        let addresses_and_hashes = Array.zip_exn addresses nodes in

        (* Filter to fetch only those that differ *)
        let should_fetch_children addr hash =
          not @@ Hash.equal (MT.get_inner_hash_at_addr_exn t.tree addr) hash
        in
        let subtrees_to_fetch, subtrees_held =
          addresses_and_hashes
          |> Array.partition_tf ~f:(Tuple2.uncurry should_fetch_children)
        in
        Array.iter subtrees_held ~f:(fun (addr, _) -> settle t addr) ;
        `Good subtrees_to_fetch )
      else `Hash_mismatch (expected, merged)
    else `Invalid_length

  (** [add_content], for the expected hash of [addr], or [`Not_expected] if
      the syncer is not waiting for its content. *)
  let add_content_if_expected t addr content =
    match Addr.Table.find t.waiting_content addr with
    | None ->
        `Not_expected
    | Some expected ->
        ( add_content t addr ~expected content
          :> [ `Success
             | `Hash_mismatch of Hash.t * Hash.t
             | `Content_length_mismatch of int * int
             | `Not_expected ] )

  (** [add_subtree], for the expected hash of [addr], or [`Not_expected] if
      the syncer is not waiting for its children. *)
  let add_subtree_if_expected t addr nodes requested_depth =
    match Addr.Table.find t.waiting_parents addr with
    | None ->
        `Not_expected
    | Some expected ->
        ( add_subtree t addr ~expected nodes requested_depth
          :> [ `Good of (Addr.t * Hash.t) array
             | `Hash_mismatch of Hash.t * Hash.t
             | `Invalid_length
             | `Not_expected ] )

  let all_done t =
    let open (val t.context) in
    if not (Root_hash.equal (MT.merkle_root t.tree) (desired_root_exn t)) then
      failwith "We finished syncing, but made a mistake somewhere :("
    else (
      if Ivar.is_full t.validity_listener then
        [%log error] "Ivar.fill bug is here!" ;
      Ivar.fill t.validity_listener `Ok )

  (** Compute the hash of an empty tree of the specified height. *)
  let empty_hash_at_height =
    let cache =
      Mina_stdlib.Empty_hashes.extensible_cache
        (module Hash)
        ~init_hash:Hash.empty_account
    in
    fun h ->
      assert (
        h >= 0
        || failwith (sprintf "empty_hash_at_height: negative height %d" h) ) ;
      cache h

  (** Given the hash of the smallest subtree that contains all accounts, the
      height of that hash in the tree and the height of the whole tree, compute
      the hash of the whole tree. *)
  let complete_with_empties hash start_height result_height =
    assert (
      start_height <= result_height
      || failwith
           (sprintf "complete_with_empties: start_height %d > result_height %d"
              start_height result_height ) ) ;
    let rec go cur_empty prev_hash height =
      if height = result_height then prev_hash
      else
        let cur = Hash.merge ~height prev_hash cur_empty in
        let next_empty = Hash.merge ~height cur_empty cur_empty in
        go next_empty cur (height + 1)
    in
    go (empty_hash_at_height start_height) hash start_height

  (** Given an address and the hash of the corresponding subtree, start getting
      the children. If the subtree is empty, its accounts are removed instead.
  *)
  let handle_node t addr exp_hash =
    let open (val t.context) in
    let ledger_depth = MT.depth t.tree in
    if
      Hash.equal exp_hash
        (empty_hash_at_height (Addr.height ~ledger_depth addr))
    then (
      MT.set_all_accounts_rooted_at_exn t.tree addr [] ;
      settle t addr )
    else if Addr.depth addr >= ledger_depth - account_subtree_height then (
      expect_content t addr exp_hash ;
      Linear_pipe.write_without_pushback_if_open t.queries
        (desired_root_exn t, What_contents addr) )
    else (
      expect_children t addr exp_hash ;
      Linear_pipe.write_without_pushback_if_open t.queries
        ( desired_root_exn t
        , What_child_hashes (addr, ledger_sync_config.default_subtree_depth) ) )

  (** Handle the initial Num_accounts message, starting the main syncing
      process. *)
  let handle_num_accounts :
         'a t
      -> int
      -> Hash.t
      -> [ `Success
         | `Hash_mismatch of Hash.t * Hash.t
         | `Depth_mismatch of int ] =
   fun t n content_hash ->
    let rh = Root_hash.to_hash (desired_root_exn t) in
    let ledger_depth = MT.depth t.tree in
    (* Reject counts outside (0, 2^ledger_depth]. *)
    if n <= 0 || n > Int.shift_left 1 ledger_depth then
      `Depth_mismatch ledger_depth
    else
      let height = Int.ceil_log2 n in
      (* FIXME: bug when height=0 https://github.com/o1-labs/nanobit/issues/365 *)
      let actual = complete_with_empties content_hash height ledger_depth in
      if Hash.equal actual rh then (
        t.num_accounts <- Some n ;
        t.accounts_settled <- 0 ;
        Addr.Table.clear t.waiting_parents ;
        (* We should use this information to set the empty account slots empty and
           start syncing at the content root. See #1972. *)
        Addr.Table.clear t.waiting_content ;
        handle_node t (Addr.root ()) rh ;
        `Success )
      else `Hash_mismatch (rh, actual)

  module For_test = struct
    let num_accounts_answer = num_accounts_answer
  end

  let main_loop t =
    let open (val t.context) in
    let handle_answer :
           Root_hash.t
           * Addr.t Query.t
           * (Hash.t, Account.t) Answer.t Envelope.Incoming.t
        -> unit Deferred.t =
     fun (root_hash, query, env) ->
      (* NOTE: think about synchronization here. This is deferred now, so
         the t and the underlying ledger can change while processing is
         happening. *)
      let already_done =
        match Ivar.peek t.validity_listener with Some `Ok -> true | _ -> false
      in
      let sender = Envelope.Incoming.sender env in
      let answer = Envelope.Incoming.data env in
      [%log trace]
        ~metadata:
          [ ("root_hash", Root_hash.to_yojson root_hash)
          ; ("query", Query.to_yojson Addr.to_yojson query)
          ]
        "Handle answer for $root_hash" ;
      if not (Root_hash.equal root_hash (desired_root_exn t)) then (
        [%log trace]
          ~metadata:
            [ ("desired_hash", Root_hash.to_yojson (desired_root_exn t))
            ; ("ignored_hash", Root_hash.to_yojson root_hash)
            ]
          "My desired root was $desired_hash, so I'm ignoring $ignored_hash" ;
        t.answers_ignored <- t.answers_ignored + 1 ;
        Deferred.unit )
      else if already_done then (
        (* This can happen if we asked for hashes that turn out to be equal in
           underlying ledger and the target. *)
        [%log debug] "Got sync response when we're already finished syncing" ;
        t.answers_ignored <- t.answers_ignored + 1 ;
        Deferred.unit )
      else
        let open Trust_system in
        (* If a peer misbehaves we still need the information we asked them for,
           so requeue in that case. *)
        let requeue_query () =
          t.answers_rejected <- t.answers_rejected + 1 ;
          (* The target may have changed while the answer was being handled,
             and a query for a root we no longer want must not be reissued. *)
          if Root_hash.equal root_hash (desired_root_exn t) then
            Linear_pipe.write_without_pushback_if_open t.queries
              (root_hash, query)
        in
        (* After the target changes, answers can arrive for queries the syncer
           no longer expects. They are not the sender's fault. *)
        let ignore_answer () =
          [%log debug]
            ~metadata:[ ("query", Query.to_yojson Addr.to_yojson query) ]
            "Ignoring the answer to sync ledger query $query, which is no \
             longer expected" ;
          t.answers_ignored <- t.answers_ignored + 1 ;
          Deferred.unit
        in
        let credit_fulfilled_request () =
          t.answers_accepted <- t.answers_accepted + 1 ;
          t.last_accepted_answer_at <- Some (Core.Time.now ()) ;
          record_envelope_sender t.trust_system logger sender
            ( Actions.Fulfilled_request
            , Some
                ( "sync ledger query $query"
                , [ ("query", Query.to_yojson Addr.to_yojson query) ] ) )
        in
        let%bind _ =
          match (query, answer) with
          | Query.What_contents addr, Answer.Contents_are leaves -> (
              match add_content_if_expected t addr leaves with
              | `Success ->
                  credit_fulfilled_request ()
              | `Not_expected ->
                  ignore_answer ()
              | `Hash_mismatch (expected, actual) ->
                  let%map () =
                    record_envelope_sender t.trust_system logger sender
                      ( Actions.Sent_bad_hash
                      , Some
                          ( "sent accounts $accounts for address $addr, they \
                             hash to $actual but we expected $expected"
                          , [ ( "accounts"
                              , `List (List.map ~f:Account.to_yojson leaves) )
                            ; ("addr", Addr.to_yojson addr)
                            ; ("actual", Hash.to_yojson actual)
                            ; ("expected", Hash.to_yojson expected)
                            ] ) )
                  in
                  requeue_query ()
              | `Content_length_mismatch (received, capacity) ->
                  let%map () =
                    record_envelope_sender t.trust_system logger sender
                      ( Actions.Violated_protocol
                      , Some
                          ( "unexpected number of accounts for $addr"
                          , [ ("received", `Int received)
                            ; ("capacity", `Int capacity)
                            ; ("addr", Addr.to_yojson addr)
                            ] ) )
                  in
                  requeue_query () )
          | Query.Num_accounts, Answer.Num_accounts (count, content_root) -> (
              match handle_num_accounts t count content_root with
              | `Success ->
                  credit_fulfilled_request ()
              | `Depth_mismatch ledger_depth ->
                  let%map () =
                    record_envelope_sender t.trust_system logger sender
                      ( Actions.Violated_protocol
                      , Some
                          ( "Claimed num_accounts $count, but a ledger of \
                             depth $ledger_depth holds at most 2^$ledger_depth \
                             accounts; impossible count"
                          , [ ("count", `Int count)
                            ; ("ledger_depth", `Int ledger_depth)
                            ] ) )
                  in
                  requeue_query ()
              | `Hash_mismatch (expected, actual) ->
                  let%map () =
                    record_envelope_sender t.trust_system logger sender
                      ( Actions.Sent_bad_hash
                      , Some
                          ( "Claimed num_accounts $count, content root hash \
                             $content_root_hash, that implies a root hash of \
                             $actual, we expected $expected"
                          , [ ("count", `Int count)
                            ; ("content_root_hash", Hash.to_yojson content_root)
                            ; ("actual", Hash.to_yojson actual)
                            ; ("expected", Hash.to_yojson expected)
                            ] ) )
                  in
                  requeue_query () )
          | ( Query.What_child_hashes (address, requested_depth)
            , Answer.Child_hashes_are hashes ) -> (
              match
                add_subtree_if_expected t address hashes requested_depth
              with
              | `Not_expected ->
                  ignore_answer ()
              | `Hash_mismatch (expected, actual) ->
                  let%map () =
                    record_envelope_sender t.trust_system logger sender
                      ( Actions.Sent_bad_hash
                      , Some
                          ( "hashes sent for subtree on address $address merge \
                             to $actual_merge but we expected $expected_merge"
                          , [ ("actual_merge", Hash.to_yojson actual)
                            ; ("expected_merge", Hash.to_yojson expected)
                            ] ) )
                  in
                  requeue_query ()
              | `Invalid_length ->
                  let%map () =
                    record_envelope_sender t.trust_system logger sender
                      ( Actions.Sent_bad_hash
                      , Some
                          ( "hashes sent for subtree on address $address must \
                             be a power of 2 in the range 2-2^$depth"
                          , [ ( "depth"
                              , `Int ledger_sync_config.max_subtree_depth )
                            ] ) )
                  in
                  requeue_query ()
              | `Good children_to_verify ->
                  Array.iter children_to_verify ~f:(fun (addr, hash) ->
                      handle_node t addr hash ) ;
                  credit_fulfilled_request () )
          | query, answer ->
              let%map () =
                record_envelope_sender t.trust_system logger sender
                  ( Actions.Violated_protocol
                  , Some
                      ( "Answered question we didn't ask! Query was $query \
                         answer was $answer"
                      , [ ("query", Query.to_yojson Addr.to_yojson query)
                        ; ( "answer"
                          , Answer.to_yojson Hash.to_yojson Account.to_yojson
                              answer )
                        ] ) )
              in
              requeue_query ()
        in
        if
          Root_hash.equal
            (Option.value_exn t.desired_root)
            (MT.merkle_root t.tree)
        then (
          [%str_log trace] Snarked_ledger_synced ;
          all_done t ) ;
        Deferred.unit
    in
    Linear_pipe.iter t.answers ~f:handle_answer

  let new_goal t h ~data ~equal =
    let open (val t.context) in
    let should_skip =
      match t.desired_root with
      | None ->
          false
      | Some h' ->
          Root_hash.equal h h'
    in
    if not should_skip then (
      Option.iter t.desired_root ~f:(fun root_hash ->
          [%log debug]
            ~metadata:
              [ ("old_root_hash", Root_hash.to_yojson root_hash)
              ; ("new_root_hash", Root_hash.to_yojson h)
              ]
            "New_goal: changing target from $old_root_hash to $new_root_hash" ) ;
      Ivar.fill_if_empty t.validity_listener
        (`Target_changed (t.desired_root, h)) ;
      t.validity_listener <- Ivar.create () ;
      t.desired_root <- Some h ;
      t.targets <- t.targets + 1 ;
      t.num_accounts <- None ;
      t.accounts_settled <- 0 ;
      t.target_set_at <- Some (Core.Time.now ()) ;
      ( try don't_wait_for (Broadcast_pipe.Writer.write t.target_writer (Some h))
        with Broadcast_pipe.Already_closed _ -> () ) ;
      t.auxiliary_data <- Some data ;
      Linear_pipe.write_without_pushback_if_open t.queries (h, Num_accounts) ;
      `New )
    else if
      Option.fold t.auxiliary_data ~init:false ~f:(fun _ saved_data ->
          equal data saved_data )
    then (
      [%log debug] "New_goal to same hash, not doing anything" ;
      `Repeat )
    else (
      t.auxiliary_data <- Some data ;
      `Update_data )

  let rec valid_tree t =
    match%bind Ivar.read t.validity_listener with
    | `Ok ->
        return (t.tree, Option.value_exn t.auxiliary_data)
    | `Target_changed _ ->
        valid_tree t

  let peek_valid_tree t =
    Option.bind (Ivar.peek t.validity_listener) ~f:(function
      | `Ok ->
          Some t.tree
      | `Target_changed _ ->
          None )

  let progress t : Progress.t =
    { targets = t.targets
    ; target_set_at = t.target_set_at
    ; pending_child_hashes = Addr.Table.length t.waiting_parents
    ; pending_contents = Addr.Table.length t.waiting_content
    ; synced = Option.is_some (peek_valid_tree t)
    ; answers_accepted = t.answers_accepted
    ; answers_ignored = t.answers_ignored
    ; answers_rejected = t.answers_rejected
    ; last_accepted_answer_at = t.last_accepted_answer_at
    ; num_accounts = t.num_accounts
    ; accounts_settled = t.accounts_settled
    ; accounts_received = t.accounts_received
    }

  let wait_until_valid t h =
    if not (Root_hash.equal h (desired_root_exn t)) then
      return (`Target_changed (t.desired_root, h))
    else
      Deferred.map (Ivar.read t.validity_listener) ~f:(function
        | `Target_changed payload ->
            `Target_changed payload
        | `Ok ->
            `Ok t.tree )

  let fetch t rh ~data ~equal =
    ignore (new_goal t rh ~data ~equal : [ `New | `Repeat | `Update_data ]) ;
    wait_until_valid t rh

  let create mt ~context ~trust_system =
    let qr, qw = Linear_pipe.create () in
    let ar, aw = Linear_pipe.create () in
    let target, target_writer = Broadcast_pipe.create None in
    let t =
      { desired_root = None
      ; auxiliary_data = None
      ; tree = mt
      ; trust_system
      ; answers = ar
      ; answer_writer = aw
      ; queries = qw
      ; query_reader = qr
      ; target
      ; target_writer
      ; waiting_parents = Addr.Table.create ()
      ; waiting_content = Addr.Table.create ()
      ; validity_listener = Ivar.create ()
      ; context
      ; targets = 0
      ; target_set_at = None
      ; answers_accepted = 0
      ; answers_ignored = 0
      ; answers_rejected = 0
      ; last_accepted_answer_at = None
      ; num_accounts = None
      ; accounts_settled = 0
      ; accounts_received = 0
      }
    in
    don't_wait_for (main_loop t) ;
    t

  let apply_or_queue_diff _ _ =
    (* Need some interface for the diffs, not sure the layering is right here. *)
    failwith "todo"

  let merkle_path_at_addr _ = failwith "no"

  let get_account_at_addr _ = failwith "no"
end
