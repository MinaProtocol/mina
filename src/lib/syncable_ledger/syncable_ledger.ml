open Core
open Async_kernel
open Pipe_lib

(** Run f recursively n times, starting with value r.
    e.g. funpow 3 f r = f (f (f r)) *)
let rec funpow n f r = if n > 0 then funpow (n - 1) f (f r) else r

module Query = struct
  module Stable = struct
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
      [@@deriving bin_io, sexp, yojson]
    end

    module Latest = V1
  end

  (* bin_io omitted intentionally *)
  type 'addr t = 'addr Stable.Latest.t =
    | What_child_hashes of 'addr
    | What_contents of 'addr
    | Num_accounts
  [@@deriving sexp, yojson]
end

module Answer = struct
  module Stable = struct
    module V1 = struct
      type ('hash, 'account) t =
        | Child_hashes_are of 'hash * 'hash
            (** The requested address's children have these hashes **)
        | Contents_are of 'account list
            (** The requested address has these accounts *)
        | Num_accounts of int * 'hash
            (** There are this many accounts and the smallest subtree that
                contains all non-empty nodes has this hash. *)
      [@@deriving bin_io, sexp, yojson]
    end

    module Latest = V1
  end

  (* bin_io omitted intentionally *)
  type ('hash, 'account) t = ('hash, 'account) Stable.Latest.t =
    | Child_hashes_are of 'hash * 'hash
    | Contents_are of 'account list
    | Num_accounts of int * 'hash
  [@@deriving sexp, yojson]
end

module type Inputs_intf = sig
  module Addr : Merkle_address.S

  module Account : sig
    type t [@@deriving bin_io, sexp, yojson]
  end

  module Hash : Merkle_ledger.Intf.Hash with type account := Account.t

  module Root_hash : sig
    type t [@@deriving eq, sexp, yojson]

    val to_hash : t -> Hash.t
  end

  module MT :
    Merkle_ledger.Syncable_intf.S
    with type hash := Hash.t
     and type root_hash := Root_hash.t
     and type addr := Addr.t
     and type account := Account.t

  val account_subtree_height : int
  (** Fetch all the accounts in subtrees of this size at once, rather than
      recursively one at a time *)
end

module type S = sig
  type t [@@deriving sexp]

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

  module Responder : sig
    type t

    val create : merkle_tree -> (query -> unit) -> logger:Logger.t -> t

    val answer_query : t -> query -> answer option
  end

  val create : merkle_tree -> logger:Logger.t -> t

  val answer_writer :
    t -> (root_hash * query * answer Envelope.Incoming.t) Linear_pipe.Writer.t

  val query_reader : t -> (root_hash * query) Linear_pipe.Reader.t

  val destroy : t -> unit

  val new_goal : t -> root_hash -> [`Repeat | `New]

  val peek_valid_tree : t -> merkle_tree option

  val valid_tree : t -> merkle_tree Deferred.t

  val wait_until_valid :
       t
    -> root_hash
    -> [`Ok of merkle_tree | `Target_changed of root_hash option * root_hash]
       Deferred.t

  val fetch :
       t
    -> root_hash
    -> [`Ok of merkle_tree | `Target_changed of root_hash option * root_hash]
       Deferred.t

  val apply_or_queue_diff : t -> diff -> unit

  val merkle_path_at_addr : t -> addr -> merkle_path Or_error.t

  val get_account_at_addr : t -> addr -> account Or_error.t
end

module type Validity_intf = sig
  type t

  type addr

  type hash

  type hash_status = Fresh | Stale

  type hash' = hash_status * hash [@@deriving eq]

  val create : unit -> t

  val set : t -> addr -> hash' -> bool

  val get : t -> addr -> hash' option

  val completely_fresh : t -> bool
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

  module Responder = struct
    type t = {mt: MT.t; f: query -> unit; logger: Logger.t}

    let create : MT.t -> (query -> unit) -> logger:Logger.t -> t =
     fun mt f ~logger -> {mt; f; logger}

    let answer_query : t -> query -> answer option =
     fun {mt; f; logger} q ->
      f q ;
      match q with
      | What_child_hashes a -> (
        match
          let open Or_error.Let_syntax in
          let%bind lchild = Addr.child a Direction.Left in
          let%map rchild = Addr.child a Direction.Right in
          Answer.Child_hashes_are
            ( MT.get_inner_hash_at_addr_exn mt lchild
            , MT.get_inner_hash_at_addr_exn mt rchild )
        with
        | Ok answer -> Some answer
        | Error _ ->
            (* TODO: punish *)
            Logger.faulty_peer logger ~module_:__MODULE__ ~location:__LOC__
              "Peer requested child hashes of invalid address!" ;
            None )
      | What_contents a ->
          let addresses_and_accounts =
            List.sort ~compare:(fun (addr1, _) (addr2, _) ->
                Addr.compare addr1 addr2 )
            @@ MT.get_all_accounts_rooted_at_exn mt a
          in
          let addresses, accounts = List.unzip addresses_and_accounts in
          if not (List.is_empty addresses) then
            let first_address, rest_address =
              (List.hd_exn addresses, List.tl_exn addresses)
            in
            let missing_address, is_compact =
              List.fold rest_address
                ~init:(Addr.next first_address, true)
                ~f:(fun (expected_address, is_compact) actual_address ->
                  if is_compact && expected_address = Some actual_address then
                    (Addr.next actual_address, true)
                  else (expected_address, false) )
            in
            if not is_compact then
              Logger.error logger ~module_:__MODULE__ ~location:__LOC__
                ~metadata:
                  [ ( "missing_address"
                    , Addr.to_yojson (Option.value_exn missing_address) )
                  ; ( "addresses_and_accounts"
                    , `List
                        (List.map addresses_and_accounts
                           ~f:(fun (addr, account) ->
                             `Tuple
                               [Addr.to_yojson addr; Account.to_yojson account]
                         )) ) ]
                "Missing an account at address: $missing_address inside the \
                 list: $addresses_and_accounts"
            else ()
          else () ;
          Some (Contents_are accounts)
      | Num_accounts ->
          let len = MT.num_accounts mt in
          let height = Int.ceil_log2 len in
          (* FIXME: bug when height=0 https://github.com/o1-labs/nanobit/issues/365 *)
          let content_root_addr =
            funpow (MT.depth - height)
              (fun a -> Addr.child_exn a Direction.Left)
              (Addr.root ())
          in
          Some
            (Num_accounts
               (len, MT.get_inner_hash_at_addr_exn mt content_root_addr))
  end

  type t =
    { mutable desired_root: Root_hash.t option
    ; tree: MT.t
    ; logger: Logger.t
    ; answers:
        (Root_hash.t * query * answer Envelope.Incoming.t) Linear_pipe.Reader.t
    ; answer_writer:
        (Root_hash.t * query * answer Envelope.Incoming.t) Linear_pipe.Writer.t
    ; queries: (Root_hash.t * query) Linear_pipe.Writer.t
    ; query_reader: (Root_hash.t * query) Linear_pipe.Reader.t
    ; waiting_parents: Hash.t Addr.Table.t
          (** Addresses we are waiting for the children of, and the expected
              hash of the node with the address. *)
    ; waiting_content: Hash.t Addr.Table.t
    ; mutable validity_listener:
        [`Ok | `Target_changed of Root_hash.t option * Root_hash.t] Ivar.t }

  let t_of_sexp _ = failwith "t_of_sexp: not implemented"

  let sexp_of_t _ = failwith "sexp_of_t: not implemented"

  let desired_root_exn {desired_root; _} = desired_root |> Option.value_exn

  let destroy t =
    Linear_pipe.close_read t.answers ;
    Linear_pipe.close_read t.query_reader

  let answer_writer t = t.answer_writer

  let query_reader t = t.query_reader

  let expect_children : t -> Addr.t -> Hash.t -> unit =
   fun t parent_addr expected ->
    Logger.trace t.logger ~module_:__MODULE__ ~location:__LOC__
      ~metadata:
        [ ("parent_address", Addr.to_yojson parent_addr)
        ; ("hash", Hash.to_yojson expected) ]
      "Expecting children parent $parent_address, expected: $hash" ;
    Addr.Table.add_exn t.waiting_parents ~key:parent_addr ~data:expected

  let expect_content : t -> Addr.t -> Hash.t -> unit =
   fun t addr expected ->
    Logger.trace t.logger ~module_:__MODULE__ ~location:__LOC__
      ~metadata:
        [("address", Addr.to_yojson addr); ("hash", Hash.to_yojson expected)]
      "Expecting content addr $address, expected: $hash" ;
    Addr.Table.add_exn t.waiting_content ~key:addr ~data:expected

  (* TODO #435: verify content hash matches expected and blame the peer who gave it to us *)

  (** Given an address and the accounts below that address, fill in the tree
      with them. *)
  let add_content : t -> Addr.t -> Account.t list -> Hash.t Or_error.t =
   fun t addr content ->
    let expected = Addr.Table.find_exn t.waiting_content addr in
    (* TODO #444 should we batch all the updates and do them at the end? *)
    MT.set_all_accounts_rooted_at_exn t.tree addr content ;
    Addr.Table.remove t.waiting_content addr ;
    Ok expected

  (** Given an address and the hashes of the children of the corresponding node,
      check the children hash to the expected value. If they do, queue the
      children for retrieval if the values in the underlying ledger don't match
      the hashes we got from the network. *)
  let add_child_hashes_to :
         t
      -> Addr.t
      -> Hash.t
      -> Hash.t
      -> [ `Good of (Addr.t * Hash.t) list
           (** The addresses and expected hashes of the now-retrievable children *)
         | `Hash_mismatch  (** Hash check failed, peer lied. *) ] =
   fun t parent_addr lh rh ->
    let la, ra =
      Option.value_exn ~message:"Tried to fetch a leaf as if it was a node"
        ( Or_error.ok
        @@ Or_error.both
             (Addr.child parent_addr Direction.Left)
             (Addr.child parent_addr Direction.Right) )
    in
    let expected =
      Option.value_exn ~message:"Forgot to wait for a node"
        (Addr.Table.find t.waiting_parents parent_addr)
    in
    let merged_hash =
      (* Height here is the height of the things we're merging, so one less than
         the parent height. *)
      Hash.merge ~height:(MT.depth - Addr.depth parent_addr - 1) lh rh
    in
    if Hash.equal merged_hash expected then (
      (* Fetch the children of a node if the hash in the underlying ledger
         doesn't match what we got. *)
      let should_fetch_children addr hash =
        not @@ Hash.equal (MT.get_inner_hash_at_addr_exn t.tree addr) hash
      in
      let subtrees_to_fetch =
        [(la, lh); (ra, rh)]
        |> List.filter ~f:(Tuple2.uncurry should_fetch_children)
      in
      Addr.Table.remove t.waiting_parents parent_addr ;
      `Good subtrees_to_fetch )
    else `Hash_mismatch

  let all_done t res =
    if not (Root_hash.equal (MT.merkle_root t.tree) (desired_root_exn t)) then
      failwith "We finished syncing, but made a mistake somewhere :("
    else Ivar.fill t.validity_listener `Ok ;
    res

  (** Compute the hash of an empty tree of the specified height. *)
  let empty_hash_at_height h =
    let rec go prev ctr =
      if ctr = h then prev else go (Hash.merge ~height:ctr prev prev) (ctr + 1)
    in
    go Hash.empty_account 0

  (** Given the hash of the smallest subtree that contains all accounts, the
      height of that hash in the tree and the height of the whole tree, compute
      the hash of the whole tree. *)
  let complete_with_empties hash start_height result_height =
    let rec go cur_empty prev_hash height =
      if height = result_height then prev_hash
      else
        let cur = Hash.merge ~height prev_hash cur_empty in
        let next_empty = Hash.merge ~height cur_empty cur_empty in
        go next_empty cur (height + 1)
    in
    go (empty_hash_at_height start_height) hash start_height

  (** Given an address and the hash of the corresponding subtree, start getting
      the children.
  *)
  let handle_node t addr exp_hash =
    if Addr.depth addr >= MT.depth - account_subtree_height then (
      expect_content t addr exp_hash ;
      Linear_pipe.write_without_pushback_if_open t.queries
        (desired_root_exn t, What_contents addr) )
    else (
      expect_children t addr exp_hash ;
      Linear_pipe.write_without_pushback_if_open t.queries
        (desired_root_exn t, What_child_hashes addr) )

  (** Handle the initial Num_accounts message, starting the main syncing
      process. *)
  let handle_num_accounts t n content_hash =
    let rh = Root_hash.to_hash (desired_root_exn t) in
    let height = Int.ceil_log2 n in
    (* FIXME: bug when height=0 https://github.com/o1-labs/nanobit/issues/365 *)
    if not (Hash.equal (complete_with_empties content_hash height MT.depth) rh)
    then failwith "reported content hash doesn't match desired root hash!" ;
    (* TODO: punish *)
    MT.make_space_for t.tree n ;
    Addr.Table.clear t.waiting_parents ;
    (* We should use this information to set the empty account slots empty and
       start syncing at the content root. See #1972. *)
    Addr.Table.clear t.waiting_content ;
    handle_node t (Addr.root ()) rh

  let main_loop t =
    let handle_answer (root_hash, query, env) =
      let already_done =
        match Ivar.peek t.validity_listener with
        | Some `Ok -> true
        | _ -> false
      in
      let answer = Envelope.Incoming.data env in
      Logger.trace t.logger ~module_:__MODULE__ ~location:__LOC__
        ~metadata:[("root_hash", Root_hash.to_yojson root_hash)]
        "Handle answer for $root_hash" ;
      if not (Root_hash.equal root_hash (desired_root_exn t)) then (
        Logger.trace t.logger ~module_:__MODULE__ ~location:__LOC__
          ~metadata:
            [ ("desired_hash", Root_hash.to_yojson (desired_root_exn t))
            ; ("ignored_hash", Root_hash.to_yojson root_hash) ]
          "My desired root was $desired_hash, so I'm ignoring $ignored_hash" ;
        () )
      else if already_done then
        (* This can happen if we asked for hashes that turn out to be equal in
           underlying ledger and the target. *)
        Logger.debug t.logger ~module_:__MODULE__ ~location:__LOC__
          "Got sync response when we're already finished syncing"
      else
        let res =
          match (query, answer) with
          | Query.What_child_hashes addr, Answer.Child_hashes_are (lh, rh) -> (
            match add_child_hashes_to t addr lh rh with
            (* TODO #435: Stick this in a log, punish the sender *)
            | `Hash_mismatch ->
                Logger.faulty_peer t.logger ~module_:__MODULE__
                  ~location:__LOC__
                  ~metadata:
                    [ ("left_child_hash", Hash.to_yojson lh)
                    ; ("right_child_hash", Hash.to_yojson rh)
                    ; ( "sender"
                      , Envelope.Sender.to_yojson
                          (Envelope.Incoming.sender env) ) ]
                  "Peer lied when trying to add child hashes $left_child_hash \
                   and $right_child_hash. Sender was: $sender"
            | `Good children_to_verify ->
                (* TODO #312: Make sure we don't write too much *)
                List.iter children_to_verify ~f:(fun (addr, hash) ->
                    handle_node t addr hash ) )
          | Query.What_contents addr, Answer.Contents_are leaves ->
              (* FIXME untrusted _exn *)
              add_content t addr leaves |> Or_error.ok_exn |> ignore
          | Query.Num_accounts, Answer.Num_accounts (count, content_root) ->
              handle_num_accounts t count content_root
          | query, answer ->
              Logger.faulty_peer t.logger ~module_:__MODULE__ ~location:__LOC__
                ~metadata:
                  [ ( "peer"
                    , Envelope.Sender.to_yojson @@ Envelope.Incoming.sender env
                    )
                  ; ("query", Query.to_yojson Addr.to_yojson query)
                  ; ( "answer"
                    , Answer.to_yojson Hash.to_yojson Account.to_yojson answer
                    ) ]
                "Peer $peer answered question we didn't ask! Query was $query \
                 answer was $answer"
        in
        if
          (not (MT.has_unset_slots t.tree))
          && Root_hash.equal
               (Option.value_exn t.desired_root)
               (MT.merkle_root t.tree)
        then (
          Logger.trace t.logger ~module_:__MODULE__ ~location:__LOC__
            "Snarked database sync'd. All done" ;
          all_done t res )
        else res
    in
    Linear_pipe.iter t.answers ~f:(fun a -> handle_answer a ; Deferred.unit)

  let new_goal t h =
    let should_skip =
      match t.desired_root with
      | None -> false
      | Some h' -> Root_hash.equal h h'
    in
    if not should_skip then (
      Option.iter t.desired_root ~f:(fun root_hash ->
          Logger.info t.logger ~module_:__MODULE__ ~location:__LOC__
            ~metadata:
              [ ("old_root_hash", Root_hash.to_yojson root_hash)
              ; ("new_root_hash", Root_hash.to_yojson h) ]
            "new_goal: changing target from $old_root_hash to $new_root_hash"
      ) ;
      Ivar.fill_if_empty t.validity_listener
        (`Target_changed (t.desired_root, h)) ;
      t.validity_listener <- Ivar.create () ;
      t.desired_root <- Some h ;
      Linear_pipe.write_without_pushback_if_open t.queries (h, Num_accounts) ;
      `New )
    else (
      Logger.info t.logger ~module_:__MODULE__ ~location:__LOC__
        "new_goal to same hash, not doing anything" ;
      `Repeat )

  let rec valid_tree t =
    match%bind Ivar.read t.validity_listener with
    | `Ok -> return t.tree
    | `Target_changed _ -> valid_tree t

  let peek_valid_tree t =
    Option.bind (Ivar.peek t.validity_listener) ~f:(function
      | `Ok -> Some t.tree
      | `Target_changed _ -> None )

  let wait_until_valid t h =
    if not (Root_hash.equal h (desired_root_exn t)) then
      return (`Target_changed (t.desired_root, h))
    else
      Deferred.map (Ivar.read t.validity_listener) ~f:(function
        | `Target_changed payload -> `Target_changed payload
        | `Ok -> `Ok t.tree )

  let fetch t rh =
    new_goal t rh |> ignore ;
    wait_until_valid t rh

  let create mt ~logger =
    let qr, qw = Linear_pipe.create () in
    let ar, aw = Linear_pipe.create () in
    let t =
      { desired_root= None
      ; tree= mt
      ; logger
      ; answers= ar
      ; answer_writer= aw
      ; queries= qw
      ; query_reader= qr
      ; waiting_parents= Addr.Table.create ()
      ; waiting_content= Addr.Table.create ()
      ; validity_listener= Ivar.create () }
    in
    don't_wait_for (main_loop t) ;
    t

  let apply_or_queue_diff _ _ =
    (* Need some interface for the diffs, not sure the layering is right here. *)
    failwith "todo"

  let merkle_path_at_addr _ = failwith "no"

  let get_account_at_addr _ = failwith "no"
end
