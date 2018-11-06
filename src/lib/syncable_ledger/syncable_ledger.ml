open Core
open Async_kernel

let rec funpow n f r = if n > 0 then funpow (n - 1) f (f r) else r

module type S = sig
  type t

  type merkle_tree

  type merkle_path

  type hash

  type root_hash

  type addr

  type diff

  type account

  type index = int

  type answer =
    | Has_hash of addr * hash
    | Contents_are of addr * account list
    | Num_accounts of int * hash
  [@@deriving bin_io, sexp]

  type query = What_hash of addr | What_contents of addr | Num_accounts
  [@@deriving bin_io, sexp]

  module Responder : sig
    type t

    val create : merkle_tree -> (query -> unit) -> t

    val answer_query : t -> query -> answer
  end

  val create : merkle_tree -> parent_log:Logger.t -> t

  val answer_writer : t -> (root_hash * answer) Linear_pipe.Writer.t

  val query_reader : t -> (root_hash * query) Linear_pipe.Reader.t

  val destroy : t -> unit

  val new_goal : t -> root_hash -> unit

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

module type Responder_intf = sig
  type t

  type merkle_tree

  type query

  type answer

  val create : merkle_tree -> (query -> unit) -> t

  val answer_query : t -> query -> answer
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

module Make
    (Addr : Merkle_address.S) (Account : sig
        type t [@@deriving bin_io, sexp]
    end) (Hash : sig
      type t [@@deriving bin_io, sexp, eq]

      include
        Merkle_ledger.Intf.Hash with type account := Account.t and type t := t
    end) (Root_hash : sig
      type t [@@deriving eq, sexp]

      val to_hash : t -> Hash.t
    end)
    (MT : Merkle_ledger.Syncable_intf.S
          with type hash := Hash.t
           and type root_hash := Root_hash.t
           and type addr := Addr.t
           and type account := Account.t) (Subtree_height : sig
        val subtree_height : int
    end) :
  S
  with type merkle_tree := MT.t
   and type hash := Hash.t
   and type root_hash := Root_hash.t
   and type addr := Addr.t
   and type merkle_path := MT.path
   and type account := Account.t = struct
  type diff = unit

  type index = int

  (* TODO #434: This is a waste of memory. *)
  module Valid :
    Validity_intf with type hash := Hash.t and type addr := Addr.t = struct
    type hash_status = Fresh | Stale [@@deriving sexp, eq]

    type hash' = hash_status * Hash.t [@@deriving sexp, eq]

    type tree = Leaf of hash' option | Node of hash' * tree ref * tree ref
    [@@deriving sexp]

    type t = tree ref [@@deriving sexp]

    let create () = ref (Leaf None)

    let set t a (s, h) =
      let rec go node dirs depth =
        match dirs with
        | d :: ds -> (
            let accessor =
              match d with Direction.Left -> fst | Direction.Right -> snd
            in
            match !node with
            | Leaf (Some (Fresh, _)) ->
                failwith
                  "why are we descending into the children of a fresh leaf?"
            | Leaf None ->
                failwith
                  "why are we descending into the unknown? take care of this \
                   leaf first"
            | Leaf (Some (Stale, l)) ->
                (* otherwise we'd have to synthesize hashes *)
                assert (ds = []) ;
                node := Node ((Stale, l), ref (Leaf None), ref (Leaf None)) ;
                go node dirs depth
            | Node (_, l, r) -> (
                let res = go (accessor (l, r)) ds (depth + 1) in
                match !node with
                | Node
                    ( (Stale, h)
                    , {contents= Leaf (Some (Fresh, lh))}
                    , {contents= Leaf (Some (Fresh, rh))} ) ->
                    (* we _must_ check if the hashes match first, because we could be
                       in validation mode and there might be some leftover junk. *)
                    let mh =
                      Hash.merge ~height:(max 0 (MT.depth - depth - 1)) lh rh
                    in
                    if Hash.equal mh h then (
                      node := Leaf (Some (Fresh, h)) ;
                      res )
                    else res
                | _ -> res ) )
        | [] ->
            let changed =
              match !node with
              | Leaf (Some (s', h')) | Node ((s', h'), _, _) ->
                  not @@ Hash.equal h h'
              | Leaf None -> false
            in
            node := Leaf (Some (s, h)) ;
            changed
      in
      go t (Addr.dirs_from_root a) 0

    let get t a =
      let rec go node dirs =
        match dirs with
        | d :: ds -> (
            let accessor =
              match d with Direction.Left -> fst | Direction.Right -> snd
            in
            match !node with
            | Leaf _ -> None
            | Node (_, l, r) -> go (accessor (l, r)) ds )
        | [] -> ( match !node with Leaf c -> c | Node (c, _, _) -> Some c )
      in
      go t (Addr.dirs_from_root a)

    let completely_fresh t =
      match !t with
      | Leaf (Some (Fresh, _)) -> true
      | Node ((Fresh, _), _, _) -> true
      | _ -> false
  end

  type answer =
    | Has_hash of Addr.t * Hash.t
    | Contents_are of Addr.t * Account.t list
    | Num_accounts of int * Hash.t
    (* idea: make this verifiable by including the merkle path to the rightmost account, and verify that
       filling in empty hashes for the rest amounts to the correct hash. *)
  [@@deriving bin_io, sexp]

  type query = What_hash of Addr.t | What_contents of Addr.t | Num_accounts
  [@@deriving bin_io, sexp]

  module Responder = struct
    type t = {mt: MT.t; f: query -> unit}

    let create : MT.t -> (query -> unit) -> t = fun mt f -> {mt; f}

    let answer_query : t -> query -> answer =
     fun {mt; f} q ->
      f q ;
      match q with
      | What_hash a -> Has_hash (a, MT.get_inner_hash_at_addr_exn mt a)
      | What_contents a ->
          Contents_are (a, MT.get_all_accounts_rooted_at_exn mt a)
      | Num_accounts ->
          let len = MT.num_accounts mt in
          let height = Int.ceil_log2 len in
          (* FIXME: bug when height=0 https://github.com/o1-labs/nanobit/issues/365 *)
          let content_root_addr =
            funpow (MT.depth - height)
              (fun a -> Addr.child_exn a Direction.Left)
              (Addr.root ())
          in
          Num_accounts (len, MT.get_inner_hash_at_addr_exn mt content_root_addr)
  end

  type waiting = {expected: Hash.t; children: (Addr.t * Hash.t) list}

  type t =
    { mutable desired_root: Root_hash.t option
    ; tree: MT.t
    ; mutable validity: Valid.t
    ; log: Logger.t
    ; answers: (Root_hash.t * answer) Linear_pipe.Reader.t
    ; answer_writer: (Root_hash.t * answer) Linear_pipe.Writer.t
    ; queries: (Root_hash.t * query) Linear_pipe.Writer.t
    ; query_reader: (Root_hash.t * query) Linear_pipe.Reader.t
    ; waiting_parents: waiting Addr.Table.t
    ; waiting_content: Hash.t Addr.Table.t
    ; mutable validity_listener:
        [`Ok | `Target_changed of Root_hash.t option * Root_hash.t] Ivar.t }

  let desired_root_exn {desired_root; _} = desired_root |> Option.value_exn

  let destroy t =
    Linear_pipe.close_read t.answers ;
    Linear_pipe.close_read t.query_reader

  let answer_writer t = t.answer_writer

  let query_reader t = t.query_reader

  let expect_children : t -> Addr.t -> Hash.t -> unit =
   fun t parent_addr expected ->
    Logger.trace t.log
      !"Expecting children parent %{sexp: Addr.t}, expected: %{sexp: Hash.t}"
      parent_addr expected ;
    Addr.Table.add_exn t.waiting_parents ~key:parent_addr
      ~data:{expected; children= []}

  let expect_content : t -> Addr.t -> Hash.t -> unit =
   fun t addr expected ->
    Logger.trace t.log
      !"Expecting content addr %{sexp: Addr.t}, expected: %{sexp: Hash.t}"
      addr expected ;
    Addr.Table.add_exn t.waiting_content ~key:addr ~data:expected

  (* TODO #435: verify content hash matches expected and blame the peer who gave it to us *)
  let add_content : t -> Addr.t -> Account.t list -> Hash.t Or_error.t =
   fun t addr content ->
    let expected = Addr.Table.find_exn t.waiting_content addr in
    (* TODO #444 should we batch all the updates and do them at the end? *)
    MT.set_all_accounts_rooted_at_exn t.tree addr content ;
    Addr.Table.remove t.waiting_content addr ;
    Ok expected

  let validity_changed_at t a =
    (* TODO #537: This is probably obnoxiously slow. *)
    let filter a' = not @@ Addr.is_parent_of a ~maybe_child:a' in
    Addr.Table.filter_keys_inplace t.waiting_content ~f:filter ;
    Addr.Table.filter_keys_inplace t.waiting_parents ~f:filter

  let add_child_hash_to :
         t
      -> Addr.t
      -> Hash.t
      -> [`Good of (Addr.t * Hash.t) list | `More | `Hash_mismatch] Or_error.t
      =
   fun t child_addr h ->
    (* lots of _exn called on attacker data. it's not clear how to handle these regardless *)
    let open Or_error.Let_syntax in
    let%map parent = Addr.parent child_addr in
    Addr.Table.change t.waiting_parents parent ~f:(function
      | None -> failwith "forgot to expect_children"
      | Some {expected; children} ->
          Some {expected; children= (child_addr, h) :: children} ) ;
    let {expected; children} = Addr.Table.find_exn t.waiting_parents parent in
    let validate addr hash =
      let should_skip =
        match Valid.get t.validity addr with
        | Some (Fresh, vh) -> Hash.equal hash vh
        | _ -> false
      in
      (* we check the validity tree first because the underlying MT hashes might not be current *)
      if should_skip then []
      else if Hash.equal (MT.get_inner_hash_at_addr_exn t.tree addr) hash then (
        if Valid.set t.validity addr (Fresh, hash) then
          validity_changed_at t addr ;
        [] )
      else (
        if Valid.set t.validity addr (Stale, hash) then
          validity_changed_at t addr ;
        [(addr, hash)] )
    in
    match children with
    | [(l1, h1); (l2, h2)] ->
        let (l1, h1), (l2, h2) =
          if List.last_exn (Addr.dirs_from_root l1) = Direction.Left then
            ((l1, h1), (l2, h2))
          else ((l2, h2), (l1, h1))
        in
        let merged = Hash.merge ~height:(MT.depth - Addr.depth l1) h1 h2 in
        if Hash.equal merged expected then (
          Addr.Table.remove t.waiting_parents parent ;
          `Good (List.rev_append (validate l1 h1) (validate l2 h2)) )
        else `Hash_mismatch
    | _ -> `More

  let all_done t res =
    if not (Root_hash.equal (MT.merkle_root t.tree) (desired_root_exn t)) then
      failwith "We finished syncing, but made a mistake somewhere :("
    else Ivar.fill t.validity_listener `Ok ;
    res

  let empty_hash_at_height h =
    let rec go prev ctr =
      if ctr = h then prev else go (Hash.merge ~height:ctr prev prev) (ctr + 1)
    in
    go Hash.empty_account 0

  let complete_with_empties hash start_height result_height =
    let rec go cur_empty prev_hash height =
      if height = result_height then prev_hash
      else
        let cur = Hash.merge ~height prev_hash cur_empty in
        let next_empty = Hash.merge ~height cur_empty cur_empty in
        go next_empty cur (height + 1)
    in
    go (empty_hash_at_height start_height) hash start_height

  let handle_node t addr exp_hash =
    if Addr.depth addr >= MT.depth - Subtree_height.subtree_height then (
      expect_content t addr exp_hash ;
      Linear_pipe.write_without_pushback t.queries
        (desired_root_exn t, What_contents addr) )
    else (
      expect_children t addr exp_hash ;
      Linear_pipe.write_without_pushback t.queries
        (desired_root_exn t, What_hash (Addr.child_exn addr Direction.Left)) ;
      Linear_pipe.write_without_pushback t.queries
        (desired_root_exn t, What_hash (Addr.child_exn addr Direction.Right)) )

  let num_accounts t n content_hash =
    let rh = Root_hash.to_hash (desired_root_exn t) in
    let height = Int.ceil_log2 n in
    (* FIXME: bug when height=0 https://github.com/o1-labs/nanobit/issues/365 *)
    if not (Hash.equal (complete_with_empties content_hash height MT.depth) rh)
    then failwith "reported content hash doesn't match desired root hash!" ;
    (* TODO: punish *)
    MT.make_space_for t.tree n ;
    Addr.Table.clear t.waiting_parents ;
    Addr.Table.clear t.waiting_content ;
    Valid.set t.validity (Addr.root ()) (Stale, rh) |> ignore ;
    handle_node t (Addr.root ()) rh

  (* Assumption: only ever one answer is received for a given query
     When violated, waiting_parents can get junk added to it, which
     will stick around until the SL is destroyed, or else cause a
     node to never be verified *)
  let main_loop t =
    let handle_answer (root_hash, a) =
      Logger.trace t.log !"Handle answer for %{sexp: Root_hash.t}" root_hash ;
      if not (Root_hash.equal root_hash (desired_root_exn t)) then (
        Logger.trace t.log
          !"My desired root was %{sexp: Root_hash.t}, so I'm ignoring %{sexp: \
            Root_hash.t}"
          (desired_root_exn t) root_hash ;
        () )
      else
        let res =
          match a with
          | Has_hash (addr, h') -> (
            match add_child_hash_to t addr h' with
            (* TODO #435: Stick this in a log, punish the sender *)
            | Error e ->
                Logger.faulty_peer t.log
                  !"Got error when trying to add child_hash %{sexp: Hash.t} %s"
                  h' (Error.to_string_hum e) ;
                ()
            | Ok (`Good children_to_verify) ->
                (* TODO #312: Make sure we don't write too much *)
                List.iter children_to_verify ~f:(fun (addr, hash) ->
                    handle_node t addr hash )
            | Ok `More -> () (* wait for the other answer to come in *)
            | Ok `Hash_mismatch ->
                (* just ask again for both children of the parent?
             this is the only case where we can't immediately
             pin blame on a single node. *)
                failwith "figure out how to handle peers lying" )
          | Contents_are (addr, leafs) ->
              let subtree_hash = add_content t addr leafs |> Or_error.ok_exn in
              Valid.set t.validity addr (Fresh, subtree_hash) |> ignore
          | Num_accounts (n, h) -> num_accounts t n h
        in
        if Valid.completely_fresh t.validity then (
          Logger.trace t.log !"We are completely fresh, all done" ;
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
      Ivar.fill_if_empty t.validity_listener
        (`Target_changed (t.desired_root, h)) ;
      t.validity_listener <- Ivar.create () ;
      t.desired_root <- Some h ;
      Valid.set t.validity (Addr.root ()) (Stale, Root_hash.to_hash h)
      |> ignore ;
      Linear_pipe.write_without_pushback t.queries (h, Num_accounts) )
    else Logger.info t.log "new_goal to same hash, not doing anything"

  let wait_until_valid t h =
    if not (Root_hash.equal h (desired_root_exn t)) then
      return (`Target_changed (t.desired_root, h))
    else
      Deferred.map (Ivar.read t.validity_listener) ~f:(function
        | `Target_changed payload -> `Target_changed payload
        | `Ok -> `Ok t.tree )

  let fetch t rh = new_goal t rh ; wait_until_valid t rh

  let create mt ~parent_log =
    let qr, qw = Linear_pipe.create () in
    let ar, aw = Linear_pipe.create () in
    let t =
      { desired_root= None
      ; tree= mt
      ; log= Logger.child parent_log __MODULE__
      ; validity= Valid.create ()
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
