(** A proposed reworking of {!Parallel_scan}.

    This module is not (yet) used anywhere: it exists to pin down a simpler set
    of types for the scan state before the code that manipulates them is
    ported over. Only the pieces of the algorithm that the types are supposed
    to justify are implemented here; the forest-level orchestration is
    described but left to the port.

    {1 What the scan state is}

    A forest of perfect binary trees. Data ([Base] jobs, i.e. transactions
    awaiting a transaction proof) enters at the leaves of the newest tree,
    left to right. Proofs move upwards: two completed children are consumed by
    a [Merge] job, whose result is the input to its parent. When the root of
    the oldest tree is completed, that proof is emitted along with all of the
    data underneath it, and the tree is retired.

    The two constants are

    - [max_base_jobs = 2^depth]: leaves per tree, and the maximum number of
      transactions per block;
    - [delay]: a tree is only worked on every [delay + 1] blocks, giving snark
      workers that long to produce the proofs a block asked for.

    {1 What changed, and why}

    The existing implementation carries five pieces of machinery that this one
    does not.

    {2 The nested-pair tree}

    [Tree.t] is a spine of levels whose payload type doubles at every step
    ([('m * 'm, 'b * 'b) t]). It is a perfect binary tree encoded so that
    perfection is a type-level fact, at the cost that every single traversal
    is polymorphic recursion, needs an explicit [type a b c d.] annotation,
    and has to thread a pair-of-functions/[transpose]/[jobs_split] through
    itself ([map_depth], [update_split], [update_accumulate], ...).

    The payload of level [l] is precisely an array of [2^l] elements, so
    that is what we store: one heap-ordered array for the merge nodes and one
    for the bases. Every traversal becomes an [Array.map]/[Array.foldi] and
    every navigation becomes index arithmetic. This is also the layout we
    want for merkleisation: [merges] is already a Merkle tree's internal-node
    array, in the right order.

    {2 Weights}

    Every node carries a [Weight.t = {base : int; merge : int}] (merge nodes
    carry two: one per child subtree), maintained by [reset_weights] and
    decremented as jobs are routed down. They answer two questions:

    - [base]: how many free leaf slots are under me? Used to route incoming
      data. But data fills leaves strictly left to right, so this is
      determined by a single per-tree cursor.
    - [merge]: how many completed jobs does my subtree still expect? Used to
      route incoming work. But a tree only ever exposes jobs at one level, and
      they are completed strictly left to right, so this too is a single
      per-tree cursor.

    So [Weight.t] and everything that maintains it is replaced by
    [{ filled; level; proved }] below. (This is the change that alters the
    scan state hash, see {!section:compat}.)

    {2 [Job_status.Done] on merge nodes}

    A merge node is marked [Done] once its result has been handed to its
    parent, after which it holds only history: nothing reads it, [update]
    never revisits it, and [with_leaner_trees] rewrites it to [Empty] before
    serialisation and before hashing. So we never build it: completing a merge
    job clears the node. [Job_status] survives only on bases, where it
    genuinely distinguishes "transaction present, proof outstanding" from
    "transaction present, proof already merged upwards" — the data itself must
    be kept either way, to be emitted with the ledger proof.

    {2 Sequence numbers}

    Gone, all of them: [Sequence_number.t], the [seq_no] field on both node
    kinds, [curr_job_seq_no], [incr_sequence_no], [reset_seq_no] and
    [current_job_sequence_number].

    [seq_no] is the block number in which a job was created. Nothing in the
    algorithm ever reads it: across the whole of [parallel_scan.ml] it is only
    written, copied by [map], fed to [hash], and rendered by [Job_view]. There
    is no branch anywhere whose behaviour depends on it. Outside the library
    its only reader is the [seq_no] field of the JSON that
    [snark_job_list_json] produces, which surfaces in exactly two places: the
    [mina client snark-job-list] debugging command, and one error log line in
    [Staged_ledger.apply_diff]. [current_job_sequence_number] is exported by
    the [.mli] and has no callers at all.

    The commit that introduced the field (#1533, "Snark worker delay", Jan
    2019) says as much: "It was initially used to implement the delay-factor
    but now remains just for debugging purposes." The delay factor has been
    positional ever since — a tree's schedule is a function of its index in
    the forest — so the field has been vestigial for its entire life.

    It is not free. It sits in every node; it is hashed, so it is part of
    consensus; and because it is an unbounded counter it drags in
    [reset_seq_no], which walks the whole forest to renumber every job when
    the counter approaches [Int.max_value], plus the test that pins that
    renumbering down.

    If the debugging view is worth keeping, note that all the jobs at one
    level of one tree are created by a single block, so a merge node's number
    is a function of its tree's position and its level and can be printed
    without being stored. Only bases carry information that is not positional,
    since a tree may be filled over several blocks — and a per-tree list of
    block boundaries would capture that in [O(blocks per tree)] rather than
    [O(2^depth)] words, if anyone ever wants it back.

    {2 Polymorphism}

    ['merge] and ['base] are kept. They were not the source of the weight —
    the nested-pair encoding was — and with flat arrays the [map] that
    justifies them (swapping cached for uncached proofs in
    [Transaction_snark_scan_state.write_all_proofs_to_disk]) is two
    [Array.map]s. If merkleisation later wants payload hashing in the
    structure itself, the natural move is a functor over two
    [{type t val hash : t -> Digest.t}]s, but that trade (an awkward
    cross-instance [map]) is not worth making now.

    {1:compat Compatibility}

    Dropping weights, merge [Done] and sequence numbers changes both the
    bin_io shape and the hash — as does {!hash} itself being a Merkle root
    rather than a digest of a flat byte stream, committing to already-proved
    transactions that the current hash skips, and length-prefixing its fields.
    The hash feeds
    [Staged_ledger_hash.Aux_hash]. This is therefore a consensus-visible
    change, for [develop]/a hard fork, not for [compatible]. Merkleisation
    would move the hash anyway.

    {1 Fixed-delay finalisation}

    Today every tree except the newest is completely full, because a new tree
    is only started at the instant the current one fills; the "how many jobs
    are at level [l]" question always has the answer [2^l]. To finalise a tree
    that is only partially filled we need that question answered for a partial
    tree, which is [nodes_at_level] below: the last node of a level may have
    only a left child, in which case it is carried upwards unchanged as
    [Part]. The representation already has a constructor for that, and with
    [filled] recorded per tree the arithmetic is available. What is missing is
    only a decision procedure for when to seal a tree early, plus agreement on
    what the emitted proof means when the tree is not full.

    {1 Status}

    The forest-level orchestration is ported and checked against
    {!Parallel_scan} differentially: the two are driven with the same blocks
    and the same completed work, and are compared on the work they ask for,
    on what {!update} emits, on whether they accept a block at all, and
    node-by-node on the whole forest. They agree at every capacity and delay
    tested, with one exception recorded in the test: at [max_base_jobs = 1]
    the current implementation cannot emit at all and this one can.

    {!hash} is a Merkle tree over the same arrays, maintained as the state
    changes rather than recomputed: see {!section:merkle}. It takes no
    payload-hashing callbacks, and a block's hashing cost is proportional to
    what that block changed instead of to the size of the forest.

    {!job_views} and {!metrics} replace [view_jobs_with_position] and
    [update_metrics]. Node positions in the view are unchanged, and the view
    and the counts are both compared against the current implementation's in
    the tests. What is left in the consumer is the JSON rendering and the
    gauge-setting; see the note at the foot of the file. *)

open Core_kernel

module Job_status = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = Todo | Done [@@deriving equal, sexp]

      let to_latest = Fn.id
    end
  end]

  type t = Stable.Latest.t = Todo | Done [@@deriving equal, sexp]

  let to_string = function Todo -> "Todo" | Done -> "Done"
end

(** A leaf: a transaction awaiting, or having received, its base proof.

    [Full { status = Done; _ }] keeps its [job]: the data is what gets emitted
    alongside the ledger proof when the tree is retired, and what
    [pending_data] reports. *)
module Base_node = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type 'base t =
        | Empty
        | Full of { job : 'base; status : Job_status.Stable.V1.t }
      [@@deriving sexp]
    end
  end]

  type 'base t = 'base Stable.Latest.t =
    | Empty
    | Full of { job : 'base; status : Job_status.t }
  [@@deriving sexp]

  let map t ~f =
    match t with
    | Empty ->
        Empty
    | Full { job; status } ->
        Full { job = f job; status }
end

(** An internal node.

    [Part left] is a node whose left child has been completed but whose right
    child has not. [Full] is a job that can be handed to a worker. There is no
    [Done]: once the result of a merge job has been placed in its parent the
    node is cleared to [Empty]. *)
module Merge_node = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type 'merge t =
        | Empty
        | Part of 'merge
        | Full of { left : 'merge; right : 'merge }
      [@@deriving sexp]
    end
  end]

  type 'merge t = 'merge Stable.Latest.t =
    | Empty
    | Part of 'merge
    | Full of { left : 'merge; right : 'merge }
  [@@deriving sexp]

  let map t ~f =
    match t with
    | Empty ->
        Empty
    | Part x ->
        Part (f x)
    | Full { left; right } ->
        Full { left = f left; right = f right }
end

module Available_job = struct
  type ('merge, 'base) t = Base of 'base | Merge of 'merge * 'merge
  [@@deriving sexp]
end

(** A rendering of one node, for the JSON that [mina client snark-job-list]
    prints.

    Both of the fields the current view carries alongside a job are gone.
    [seq_no] is gone from the state entirely. A merge node's status is always
    [Todo]: a completed merge is cleared, so [Done] is not a thing a merge node
    can be any more. A base's status survives, since it is the one that
    distinguishes a transaction still awaiting its proof from one whose proof
    has already been merged upwards.

    Positions are unchanged: the current view numbers nodes by their index in a
    root-down, left-to-right fold, which is heap order, which is the index into
    these arrays. *)
module Job_view = struct
  module Node = struct
    type 'a t =
      | Base_empty
      | Base_full of { job : 'a; status : Job_status.t }
      | Merge_empty
      | Merge_part of 'a
      | Merge_full of { left : 'a; right : 'a }
    [@@deriving sexp]
  end

  type 'a t = { position : int; value : 'a Node.t } [@@deriving sexp]
end

(** What [update_metrics] reports for one tree.

    The gauge-setting itself stays with the caller. It is three lines per tree,
    it is the only reason the scan state would need to know that Prometheus
    exists, and keeping it out here means this returns numbers rather than
    [unit Or_error.t] — the [Or_error] existed only because the counting walked
    the tree and could raise. None of these counts walks anything now. *)
module Tree_metrics = struct
  type t =
    { available_space : int; base_jobs_todo : int; merge_jobs_todo : int }
  [@@deriving compare, equal, sexp]
end

module Hash = struct
  type t = Digestif.SHA256.t

  let equal = Digestif.SHA256.equal

  let to_raw_string = Digestif.SHA256.to_raw_string

  let of_raw_string = Digestif.SHA256.of_raw_string

  let sexp_of_t t = Sexp.Atom (Digestif.SHA256.to_hex t)

  let t_of_sexp = function
    | Sexp.Atom s ->
        Digestif.SHA256.of_hex s
    | s ->
        raise_s [%message "expected a hex digest" (s : Sexp.t)]
end

(** Digest a sequence of fields.

    Each field is length-prefixed, so that no two different sequences produce
    the same byte stream. The current implementation concatenates its fields
    unprefixed, which makes the encoding ambiguous — the payload digests it
    feeds are caller-supplied strings of unconstrained length. Nothing exploits
    that today, but a commitment ought not to rely on nobody trying. *)
let digest_fields fields =
  List.fold fields ~init:(Digestif.SHA256.init ()) ~f:(fun h field ->
      let h =
        Digestif.SHA256.feed_string h (Int.to_string (String.length field))
      in
      let h = Digestif.SHA256.feed_string h ":" in
      Digestif.SHA256.feed_string h field )
  |> Digestif.SHA256.get

(** How to digest the two payload types.

    Both are expected to be O(1). That is not an accident of this interface:
    the scan state's payloads already carry their own hash
    ([Ledger_proof_with_hash.t] is a [With_hash.t], [Transaction_with_witness.t]
    has a [hash] field) precisely because hashing a ledger proof is not
    something to do per block. It is what makes maintaining the Merkle tree as
    the state changes cheaper than rebuilding it. *)
module Payload_digest = struct
  type ('merge, 'base) t = { merge : 'merge -> string; base : 'base -> string }
end

(** One tree of the forest.

    Levels are numbered from the root: level [0] is the root merge node, level
    [depth] is the bases. Merge level [l] has its nodes at
    [merges.(2^l - 1) .. merges.(2^(l+1) - 2)], i.e. heap order with the root
    at index [0]; the children of [merges.(i)] are [merges.(2i+1)] and
    [merges.(2i+2)], except on the last merge level, whose children are
    [bases.(2i)] and [bases.(2i+1)].

    {2 Invariants}

    - [Array.length bases = 2^depth] and [Array.length merges = 2^depth - 1].
    - [bases.(i) <> Empty] iff [i < filled]: data fills left to right.
    - [level] is the only level with outstanding jobs. Every node strictly
      below it is [Empty] (merge) or [Full Done] (base); every node strictly
      above it is [Empty] or [Part].
    - [proved] many nodes of [level], counting from the left, have had their
      results placed in their parents; the remaining
      [nodes_at_level t level - proved] are the jobs this tree is offering.
      Hence [0 <= proved < nodes_at_level t level] — reaching equality
      immediately advances the tree to [level - 1], or emits if [level = 0].
    - the newest tree of the forest is the only one with [filled < 2^depth],
      and the only one with [level = depth]. (Fixed-delay finalisation relaxes
      the first half of this.) *)
module Tree = struct
  type ('merge, 'base) t =
    { merges : 'merge Merge_node.t array
    ; bases : 'base Base_node.t array
    ; digests : Hash.t array
    ; filled : int
    ; level : int
    ; proved : int
    }
  [@@deriving sexp]

  let depth t = Int.ceil_log2 (Array.length t.bases)

  (** Heap index of node [index] of level [level].

      Levels [0 .. depth - 1] are the merge nodes and index [merges]; level
      [depth] is the bases, which index [bases] directly by [index]. [digests]
      is the whole heap, all [depth + 1] levels of it, so it is indexed by this
      for every level. *)
  let slot ~level ~index = (1 lsl level) - 1 + index

  (** {2:merkle The Merkle tree}

      [digests] is a Merkle tree whose shape {e is} the scan tree: each node
      commits to its own content and to its two children. A base commits to
      its transaction alone.

      A node's status is deliberately not committed here. It does not need to
      be: bases are proved left to right, so [level] and [proved] — which the
      tree digest does commit to — already say exactly which of them are done.

      Unlike the current [hash], a base whose proof is already done is still
      committed to. Today those are skipped outright, so the staged ledger hash
      does not commit to transactions that are about to be emitted alongside a
      ledger proof. Since this hash is changing anyway, that is worth not
      reproducing. *)

  let digest_of_base ~(payload_digest : (_, 'base) Payload_digest.t)
      (node : 'base Base_node.t) =
    match node with
    | Empty ->
        digest_fields [ "base.empty" ]
    | Full { job; status = _ } ->
        digest_fields [ "base.full"; payload_digest.base job ]

  let digest_of_merge ~(payload_digest : ('merge, _) Payload_digest.t) ~left
      ~right (node : 'merge Merge_node.t) =
    let content =
      match node with
      | Empty ->
          [ "merge.empty" ]
      | Part x ->
          [ "merge.part"; payload_digest.merge x ]
      | Full { left; right } ->
          [ "merge.full"
          ; payload_digest.merge left
          ; payload_digest.merge right
          ]
    in
    digest_fields
      (content @ [ Hash.to_raw_string left; Hash.to_raw_string right ])

  (** The digests of a tree with nothing in it. No payloads are involved, so
      this needs no {!Payload_digest.t} — which is what lets {!create} and
      hence {!empty} stay callback-free. *)
  let empty_digests ~depth =
    let digests =
      Array.create ~len:((1 lsl (depth + 1)) - 1) (digest_fields [])
    in
    let base = digest_fields [ "base.empty" ] in
    for index = 0 to (1 lsl depth) - 1 do
      digests.(slot ~level:depth ~index) <- base
    done ;
    for level = depth - 1 downto 0 do
      for index = 0 to (1 lsl level) - 1 do
        digests.(slot ~level ~index) <-
          digest_fields
            [ "merge.empty"
            ; Hash.to_raw_string
                digests.(slot ~level:(level + 1) ~index:(2 * index))
            ; Hash.to_raw_string
                digests.(slot ~level:(level + 1) ~index:((2 * index) + 1))
            ]
      done
    done ;
    digests

  let create ~depth =
    { merges = Array.create ~len:((1 lsl depth) - 1) Merge_node.Empty
    ; bases = Array.create ~len:(1 lsl depth) Base_node.Empty
    ; digests = empty_digests ~depth
    ; filled = 0
    ; level = depth
    ; proved = 0
    }

  (** [f_merge] and [f_base] must preserve payload digests; see {!val:map}. *)
  let map t ~f_merge ~f_base =
    { t with
      merges = Array.map t.merges ~f:(Merge_node.map ~f:f_merge)
    ; bases = Array.map t.bases ~f:(Base_node.map ~f:f_base)
    }

  (** How many nodes level [level] actually has, given that only [filled]
      leaves are occupied. Each node of level [l] spans [2^(depth - l)]
      leaves; a node exists as soon as any of them is occupied. When the tree
      is full this is [2^level].

      The last node may span leaves that will never be filled: it has a left
      child and no right child, and so is carried up as [Part] rather than
      merged. That case cannot arise today, and is what fixed-delay
      finalisation turns on. *)
  let nodes_at_level t ~level =
    let span = 1 lsl (depth t - level) in
    (t.filled + span - 1) / span

  (** Number of jobs this tree is currently offering. *)
  let required_job_count t = nodes_at_level t ~level:t.level - t.proved

  (** Free leaf slots. *)
  let available_space t = Array.length t.bases - t.filled

  (** The jobs sitting at [level]: the nodes that have both their inputs and
      have not yet been completed.

      For [level = t.level] this is exactly the [required_job_count] jobs from
      [t.proved] onwards. For a level above the current one it is the jobs the
      current level has created so far — which is what the scheduling
      prediction in {!work_at} needs, and is empty for a tree whose current
      level has not been started. For a level below the current one it is
      empty, since those nodes have all been cleared. *)
  let jobs_at_level t ~level : ('merge, 'base) Available_job.t list =
    if level < 0 || level > depth t then []
    else if level = depth t then
      Array.to_list t.bases
      |> List.filter_map ~f:(function
           | Base_node.Full { job; status = Todo } ->
               Some (Available_job.Base job)
           | Full { status = Done; _ } | Empty ->
               None )
    else
      List.init (nodes_at_level t ~level) ~f:(fun index ->
          t.merges.(slot ~level ~index) )
      |> List.filter_map ~f:(function
           | Merge_node.Full { left; right } ->
               Some (Available_job.Merge (left, right))
           | Part _ | Empty ->
               None )

  (** Recompute the digests of [from .. until] at [level] and of every
      ancestor of that range, up to the root. Mutates [t.digests], so the
      caller must already own a copy of it.

      Every write this module makes is a contiguous range within a single
      level — data goes into consecutive free leaves, jobs are completed left
      to right, and the results of a completed range land in the contiguous
      range of parents above it. So this is the only invalidation shape there
      is, and it costs [O(width of the range)] hashes rather than the
      [O(size of the forest)] of a rebuild. *)
  let refresh t ~payload_digest ~level ~from ~until =
    let level = ref level and from = ref from and until = ref until in
    let finished = ref (!from > !until) in
    while not !finished do
      for index = !from to !until do
        let digest =
          if !level = depth t then
            digest_of_base ~payload_digest t.bases.(index)
          else
            digest_of_merge ~payload_digest
              ~left:t.digests.(slot ~level:(!level + 1) ~index:(2 * index))
              ~right:
                t.digests.(slot ~level:(!level + 1) ~index:((2 * index) + 1))
              t.merges.(slot ~level:!level ~index)
        in
        t.digests.(slot ~level:!level ~index) <- digest
      done ;
      if !level = 0 then finished := true
      else (
        level := !level - 1 ;
        from := !from / 2 ;
        until := !until / 2 )
    done

  (** Rebuild every digest from the node contents. Only for loading a tree
      whose digests were not serialised, and for checking in tests that the
      incrementally maintained digests are the ones a rebuild would give. *)
  let rebuilt t ~payload_digest =
    let t = { t with digests = Array.copy t.digests } in
    refresh t ~payload_digest ~level:(depth t) ~from:0
      ~until:((1 lsl depth t) - 1) ;
    t

  (** The tree's commitment: its root, and the cursors that say how far it has
      got — which is also what says which of its bases are already proved. *)
  let digest t =
    digest_fields
      [ "tree"
      ; Hash.to_raw_string t.digests.(0)
      ; Int.to_string t.filled
      ; Int.to_string t.level
      ; Int.to_string t.proved
      ]

  (** Add data to the free leaf slots, left to right. *)
  let add_data t ~payload_digest ~data =
    let data = Array.of_list data in
    if Array.length data > available_space t then
      Or_error.errorf "Data count (%d) exceeded available space (%d)"
        (Array.length data) (available_space t)
    else
      let bases = Array.copy t.bases in
      Array.iteri data ~f:(fun i job ->
          bases.(t.filled + i) <- Full { job; status = Todo } ) ;
      let t =
        { t with
          bases
        ; digests = Array.copy t.digests
        ; filled = t.filled + Array.length data
        }
      in
      refresh t ~payload_digest ~level:(depth t)
        ~from:(t.filled - Array.length data)
        ~until:(t.filled - 1) ;
      Ok t

  (** Record [value] as the result of node [index] of [level], by writing it
      into that node's parent. Returns [`Emitted value] when [level] is the
      root, in which case the tree is finished.

      [merges] is mutated, so it must already be a copy owned by the caller. *)
  let place_result ~merges ~level ~index ~value =
    if level = 0 then `Emitted value
    else
      let parent = slot ~level:(level - 1) ~index:(index / 2) in
      let node =
        match (merges.(parent), index land 1) with
        | Merge_node.Empty, 0 ->
            Merge_node.Part value
        | Part left, 1 ->
            Full { left; right = value }
        | _ ->
            failwith "parallel_scan: results arrived out of order"
      in
      merges.(parent) <- node ; `Placed

  (** Consume [results], in order, as the results of the jobs this tree is
      offering. Advances to the next level when the current one runs out, and
      returns the root proof if it reaches one.

      Note how short this is compared to [Tree.update] + [update_split] +
      [reset_weights]: there are no weights to redistribute, and "which nodes
      are being updated" is [t.level] rather than an [update_level] threaded
      down a polymorphic recursion alongside two different behaviours for
      [update_level - 1] and [update_level]. *)
  let complete_jobs t ~payload_digest ~level ~results =
    let open Or_error.Let_syntax in
    if List.is_empty results then Ok (t, None)
    else
      let%map () =
        if level <> t.level then
          Or_error.errorf
            "Completed jobs for level %d of a tree that is at level %d" level
            t.level
        else if List.length results > required_job_count t then
          Or_error.errorf "More work than required: required %d, got %d"
            (required_job_count t) (List.length results)
        else Ok ()
      in
      (* Copy-on-write: the scan state is persistent (the transition frontier
         holds several versions at once), so the arrays are copied before any
         mutation. This is the one thing the flat layout costs relative to the
         nested-pair tree, which shared everything it did not touch: an update
         now copies [2^(depth+1)] words per tree it touches rather than
         [O(depth)]. At [depth = 7] and ~35 trees that is a few tens of
         kilobytes per block. *)
      let merges = Array.copy t.merges
      and bases = Array.copy t.bases
      and digests = Array.copy t.digests in
      let level = ref t.level and proved = ref t.proved in
      let emitted = ref None in
      List.iteri results ~f:(fun i value ->
          let index = t.proved + i in
          (* Clear the completed job. A completed merge node holds nothing
             anyone reads, so it goes straight to [Empty]; a completed base
             keeps its transaction. *)
          if !level = depth t then
            match bases.(index) with
            | Base_node.Full b ->
                bases.(index) <- Full { b with status = Done }
            | Empty ->
                failwith "parallel_scan: completed a base job that is not there"
          else merges.(slot ~level:!level ~index) <- Empty ;
          match place_result ~merges ~level:!level ~index ~value with
          | `Emitted value ->
              emitted := Some value
          | `Placed ->
              if index + 1 = nodes_at_level t ~level:!level then (
                level := !level - 1 ;
                proved := 0 )
              else proved := index + 1 ) ;
      let updated =
        { t with merges; bases; digests; level = !level; proved = !proved }
      in
      let from = t.proved and until = t.proved + List.length results - 1 in
      if t.level < depth t then
        refresh updated ~payload_digest ~level:t.level ~from ~until
      else if depth t > 0 then
        (* Completing a base job changes its status, and status is not
           committed — [level] and [proved] already determine it. So the base
           digests are untouched and only the merge nodes that received the
           results need recomputing. (At [depth = 0] the base is the root and
           the tree is retired, so there is nothing above it to refresh.) *)
        refresh updated ~payload_digest
          ~level:(depth t - 1)
          ~from:(from / 2) ~until:(until / 2) ;
      (updated, !emitted)

  (** Every node of the tree, in heap order, each labelled with its index. *)
  let job_views t ~f_merge ~f_base =
    let merges =
      Array.to_list t.merges
      |> List.mapi ~f:(fun position node ->
             let value =
               match node with
               | Merge_node.Empty ->
                   Job_view.Node.Merge_empty
               | Part x ->
                   Merge_part (f_merge x)
               | Full { left; right } ->
                   Merge_full { left = f_merge left; right = f_merge right }
             in
             { Job_view.position; value } )
    in
    let offset = Array.length t.merges in
    let bases =
      Array.to_list t.bases
      |> List.mapi ~f:(fun i node ->
             let value =
               match node with
               | Base_node.Empty ->
                   Job_view.Node.Base_empty
               | Full { job; status } ->
                   Base_full { job = f_base job; status }
             in
             { Job_view.position = offset + i; value } )
    in
    merges @ bases

  (** Outstanding work, without looking at a single node.

      The jobs still to do at the current level are the ones the schedule has
      not reached, [nodes_at_level - proved]. The results of the ones it has
      reached are sitting in the level above, two to a node, which is where the
      [proved / 2] comes from — those merge nodes are full, and so are jobs in
      their own right. Everything else in the tree is empty or already done. *)
  let metrics t =
    let at_current_level =
      if t.level = depth t then 0
      else nodes_at_level t ~level:t.level - t.proved
    in
    { Tree_metrics.available_space = available_space t
    ; base_jobs_todo = (if t.level = depth t then t.filled - t.proved else 0)
    ; merge_jobs_todo = at_current_level + (t.proved / 2)
    }

  (** All the data in the tree, in order. *)
  let base_jobs t =
    Array.to_list t.bases
    |> List.filter_map ~f:(function
         | Base_node.Full { job; _ } ->
             Some job
         | Empty ->
             None )
end

(** The forest.

    [trees] is ordered newest first. [List.hd trees] is the tree accepting
    data; the rest are being proved.

    Which level a tree is worked at is the tree's own business: it is
    [Tree.level], advanced by [Tree.complete_jobs] when a level runs out.
    Today that agrees with the positional rule the current implementation
    uses — a tree at index [i] of the tail is worked iff
    [(i + 1) mod (delay + 1) = 0], and then at level [depth - i / (delay + 1)]
    — because a tree can only reach a level boundary in the same block that
    the head tree fills, and that block shifts every index by one. The two
    agreeing is worth asserting in tests, but the stored [level] is the
    authority: it is what allows a tree to be sealed on a schedule of its own,
    which is the whole point of fixed-delay finalisation, and it keeps
    "which jobs is this tree offering" answerable from the tree alone rather
    than from its position in a list.

    [acc] is not state so much as the return value of the last [update] that
    emitted something, retained for [last_emitted_value]. *)
type ('merge, 'base) t =
  { trees : ('merge, 'base) Tree.t list (* invariant: non-empty *)
  ; acc : ('merge * 'base list) option
  ; acc_digest : Hash.t
        (* Digest of [acc], maintained by [update]. [acc] holds a whole tree's
           worth of transactions and outlives the block that emitted it, so
           digesting it on demand would put an [O(max_base_jobs)] cost back
           into every call to [hash].

           Caching it only moves that cost to emission blocks, which in steady
           state is every block: it is the one [O(max_base_jobs)] term left in
           maintaining the commitment. Committing to [acc] at all is inherited
           from the current implementation and is arguably wrong — it is the
           previous block's output rather than pending state, and both halves
           of it are in the block already. Dropping it would remove that term,
           but that is a call to make with the consumer, not here. *)
  ; max_base_jobs : int
  ; delay : int
  }
[@@deriving sexp]

let depth t = Int.ceil_log2 t.max_base_jobs

let max_trees t = ((depth t + 1) * (t.delay + 1)) + 1

let digest_of_acc ~(payload_digest : ('merge, 'base) Payload_digest.t)
    (acc : ('merge * 'base list) option) =
  match acc with
  | None ->
      digest_fields [ "acc.none" ]
  | Some (proof, data) ->
      digest_fields
        ( "acc.some" :: payload_digest.merge proof
        :: List.map data ~f:payload_digest.base )

let empty ~max_base_jobs ~delay =
  { trees = [ Tree.create ~depth:(Int.ceil_log2 max_base_jobs) ]
  ; acc = None
  ; acc_digest = digest_fields [ "acc.none" ]
  ; max_base_jobs
  ; delay
  }

(** The commitment to the whole scan state.

    Note what this does {e not} take: the two payload-hashing callbacks that
    the current [hash] needs, and which force it to walk every job in every
    tree on every block. Everything below a tree's root is already committed
    in the tree, so this is a fold over one digest per tree.

    The per-block cost of hashing is therefore proportional to what the block
    changed — the transactions it added and the jobs it completed — rather than
    to the size of the forest. That removes the [delay] and the tree count from
    the cost entirely: a tree the block did not touch contributes a digest it
    already had. *)
let hash t =
  digest_fields
    ( [ "scan_state"
      ; Int.to_string t.max_base_jobs
      ; Int.to_string t.delay
      ; Hash.to_raw_string t.acc_digest
      ]
    (* oldest tree first, matching [pending_data] and [fold_chronological] *)
    @ List.rev_map t.trees ~f:(fun tree ->
          Hash.to_raw_string (Tree.digest tree) ) )

(** Rebuild every cached digest from the state itself.

    The digests are derived, and a serialised scan state should not carry
    them; this is what reconstitutes them on load. It costs
    [O(size of the forest)] once, rather than per block. *)
let rebuilt t ~payload_digest =
  { t with
    trees = List.map t.trees ~f:(Tree.rebuilt ~payload_digest)
  ; acc_digest = digest_of_acc ~payload_digest t.acc
  }

(** Which level, if any, the schedule asks of the tree at [position] in the
    tail of the forest.

    A tree is asked when its position is one before a multiple of [delay + 1],
    so that consecutive asks are [delay + 1] trees apart, and the [k]th tree
    asked is asked at level [depth - k]: the newest is asked for its base
    proofs, the one behind it for the merges above those, and so on down to
    the oldest, which is asked for its root.

    Note that positions shift only when a tree is created, not on every block.
    The schedule is therefore paced by throughput rather than by time, and it
    is the schedule, not the tree, that decides {e when} a level is offered.
    A tree that has completed its level early — which happens when a block
    supplies a full level's worth of work without filling the current tree —
    sits at a level the schedule has not reached, and is asked for nothing
    until it does. That wait is the work delay doing precisely what it is for:
    the jobs it is holding were only just created, and the workers who will
    prove them have not had their [delay] blocks yet.

    [Tree.jobs_at_level] returns nothing when the tree is not at the level
    being asked for, in either direction, so the two can be compared without
    any special casing. *)
let scheduled_level t ~position =
  let period = t.delay + 1 in
  if (position + 1) % period <> 0 then None
  else
    let k = ((position + 1) / period) - 1 in
    if k > depth t then None else Some (depth t - k)

(** All the work the forest asks for, in the order it is offered and must be
    supplied. Replaces [work]/[work_to_do]/[work_for_tree].

    [prepends] is how many new trees from now to look: [0] is the forest as it
    stands, [1] the forest after the current tree has filled and a new one has
    been prepended — where the second half of an overflowing block's data and
    work goes — and larger values are the blocks {!all_work} looks ahead to.
    Prepending shifts every tree one position down the schedule. *)
let work_at t ~prepends =
  let trees, offset =
    if prepends = 0 then (List.tl_exn t.trees, 0) else (t.trees, prepends - 1)
  in
  List.concat_mapi trees ~f:(fun i tree ->
      match scheduled_level t ~position:(i + offset) with
      | None ->
          []
      | Some level ->
          Tree.jobs_at_level tree ~level )

let free_space_on_current_tree t = Tree.available_space (List.hd_exn t.trees)

(** Work for this block and for each of the [delay + 1] blocks after it. *)
let all_work t =
  List.init (t.delay + 2) ~f:(fun prepends -> work_at t ~prepends)
  |> List.filter ~f:(Fn.non List.is_empty)

(** The work a block adding [data_count] transactions must supply.

    Two jobs per occupied slot, except that a block which fills the current
    tree owes all of that tree's outstanding work — the last slot of a tree
    needs only one proof, which is where the [2 * count] budget and the actual
    requirement part company. *)
let work_for_next_update t ~data_count =
  let space = free_space_on_current_tree t in
  let count = min data_count t.max_base_jobs in
  let set1 = work_at t ~prepends:0 in
  if space < count then
    let set2 = List.take (work_at t ~prepends:1) ((count - space) * 2) in
    List.filter [ set1; set2 ] ~f:(Fn.non List.is_empty)
  else
    let set = List.take set1 (2 * count) in
    if List.is_empty set then [] else [ set ]

let check b ~message = if b then Or_error.error_string message else Ok ()

(** Hand [completed_jobs] to the trees the schedule asks, in order, and retire
    the tree whose root they complete.

    Each tree takes as many jobs as it offered — not as many as it has
    outstanding. The two differ for a tree that is ahead of the schedule,
    which offers nothing and so must take nothing; letting it take work meant
    for the tree behind it would misapply both.

    The tree list is rebuilt rather than patched, and a retired tree is simply
    not put back, so there is no "the tree that emits is the oldest one"
    assumption to hold as there is today. *)
let add_merge_jobs t ~payload_digest ~completed_jobs =
  let open Or_error.Let_syntax in
  if List.is_empty completed_jobs then Ok (t, None)
  else
    let required = List.length (work_at t ~prepends:0) in
    let%bind () =
      check
        (List.length completed_jobs > required)
        ~message:
          (sprintf "More work than required: Required- %d got- %d" required
             (List.length completed_jobs) )
    in
    let%bind rev_tail, emitted, _ =
      List.foldi (List.tl_exn t.trees)
        ~init:(Ok ([], None, completed_jobs))
        ~f:(fun position acc tree ->
          let%bind trees, emitted, jobs = acc in
          match scheduled_level t ~position with
          | None ->
              Ok (tree :: trees, emitted, jobs)
          | Some level ->
              let count = List.length (Tree.jobs_at_level tree ~level) in
              let%bind tree, emitted' =
                Tree.complete_jobs tree ~payload_digest ~level
                  ~results:(List.take jobs count)
                |> fun r ->
                Or_error.tag_arg r "Error while adding merge jobs to tree"
                  ("tree_number", position) [%sexp_of: string * int]
              in
              let%map trees, emitted =
                match emitted' with
                | None ->
                    Ok (tree :: trees, emitted)
                | Some proof ->
                    let%map () =
                      check (Option.is_some emitted)
                        ~message:"Two trees emitted a proof in one update"
                    in
                    (* The tree is finished: it leaves the forest, and its
                       transactions leave with the proof. *)
                    (trees, Some (proof, Tree.base_jobs tree))
              in
              (trees, emitted, List.drop jobs count) )
    in
    let trees = List.hd_exn t.trees :: List.rev rev_tail in
    Ok ({ t with trees }, emitted)

(** Put [data] in the free slots of the head tree, starting a new tree if that
    fills it. *)
let add_data t ~payload_digest ~data =
  let open Or_error.Let_syntax in
  if List.is_empty data then Ok t
  else
    let head = List.hd_exn t.trees in
    let space = Tree.available_space head in
    let%map head =
      Tree.add_data head ~payload_digest ~data
      |> Or_error.tag ~tag:"Error while adding base jobs to the tree"
    in
    let trees =
      if List.length data = space then
        Tree.create ~depth:(depth t) :: head :: List.tl_exn t.trees
      else head :: List.tl_exn t.trees
    in
    { t with trees }

(** Add a block's transactions and completed proofs.

    A block that overflows the head tree is two updates in one: the work and
    data that the current forest asks for, then a new tree and the work and
    data the forest asks for once it exists. The second half runs against the
    already-updated forest, so it needs no prediction — the trees the first
    half advanced report their new levels themselves. *)
let update t ~payload_digest ~data ~completed_jobs =
  let open Or_error.Let_syntax in
  let data_count = List.length data in
  let%bind () =
    check
      (data_count > t.max_base_jobs)
      ~message:
        (sprintf "Data count (%d) exceeded maximum (%d)" data_count
           t.max_base_jobs )
  in
  let%bind () =
    let required =
      (List.length (List.concat (work_for_next_update t ~data_count)) + 1) / 2
    in
    let got = (List.length completed_jobs + 1) / 2 in
    check
      (got < required && data_count > t.max_base_jobs - required + got)
      ~message:
        (sprintf "Insufficient jobs (Data count %d): Required- %d got- %d"
           data_count required got )
  in
  let data1, data2 = List.split_n data (free_space_on_current_tree t) in
  let jobs1, jobs2 =
    List.split_n completed_jobs (List.length (work_at t ~prepends:0))
  in
  let%bind t, result = add_merge_jobs t ~payload_digest ~completed_jobs:jobs1 in
  let%bind t = add_data t ~payload_digest ~data:data1 in
  let%bind t, result' =
    add_merge_jobs t ~payload_digest ~completed_jobs:jobs2
  in
  let%bind t = add_data t ~payload_digest ~data:data2 in
  (* Only the forest as it stands can hold a tree that is one job from its
     root, so the second half never emits. The current implementation discards
     this value silently; dropping a ledger proof is not a thing to do
     quietly. *)
  let%bind () =
    check (Option.is_some result')
      ~message:"A proof was emitted after the forest had already advanced"
  in
  let%map () =
    check
      (List.length t.trees > max_trees t)
      ~message:
        (sprintf "Tree list length (%d) exceeded maximum (%d)"
           (List.length t.trees) (max_trees t) )
  in
  let acc = Option.first_some result t.acc in
  let acc_digest =
    if phys_equal acc t.acc then t.acc_digest
    else digest_of_acc ~payload_digest acc
  in
  (result, { t with acc; acc_digest })

(*************** queries ***************)

let all_jobs = all_work

let jobs_for_next_update t = work_for_next_update t ~data_count:t.max_base_jobs

let jobs_for_slots t ~slots = work_for_next_update t ~data_count:slots

(* Note that this is the capacity of a tree, not the space left in the current
   one: a block may always offer [max_base_jobs] transactions, since data that
   does not fit starts a new tree. *)
let free_space t = t.max_base_jobs

let last_emitted_value t = t.acc

let next_on_new_tree t = free_space_on_current_tree t = t.max_base_jobs

(** All the transactions still in the forest, oldest tree first. *)
let pending_data t = List.rev_map t.trees ~f:Tree.base_jobs

(** Each tree's nodes, oldest tree first. Replaces
    [view_jobs_with_position]. *)
let job_views t ~f_merge ~f_base =
  List.rev_map t.trees ~f:(Tree.job_views ~f_merge ~f_base)

(** Per-tree counts for the daemon's gauges, oldest tree first — [tree0] is the
    oldest, as today. Replaces [update_metrics]; see {!Tree_metrics}. *)
let metrics t = List.rev_map t.trees ~f:Tree.metrics

module Space_partition = struct
  type t = { first : int * int; second : (int * int) option } [@@deriving sexp]
end

(** Where [max_base_jobs] transactions would land, and what each part costs, if
    the head tree cannot hold them all. *)
let partition_if_overflowing t : Space_partition.t =
  let space = free_space_on_current_tree t in
  { first = (space, List.length (work_at t ~prepends:0))
  ; second =
      ( if space < t.max_base_jobs then
        let slots = t.max_base_jobs - space in
        Some (slots, min (List.length (work_at t ~prepends:1)) (2 * slots))
      else None )
  }

(** Change the representation of the payloads, keeping the commitment.

    [f_merge] and [f_base] must preserve payload digests. The digests cached
    throughout the forest are carried over untouched, so a function that
    changed one would leave the state committing to something it no longer
    holds. The one use this exists for — swapping proofs between their cached
    and uncached representations in
    [Transaction_snark_scan_state.write_all_proofs_to_disk] — satisfies this by
    construction: the two representations carry the same hash, which is the
    digest. *)
let map t ~f_merge ~f_base =
  { t with
    trees = List.map t.trees ~f:(Tree.map ~f_merge ~f_base)
  ; acc =
      Option.map t.acc ~f:(fun (m, bs) -> (f_merge m, List.map bs ~f:f_base))
  }

(** The state with every payload replaced by that payload's digest.

    This is what a syncing node needs before it can fetch anything: it names
    every payload in the forest, and it commits to the structure holding them.
    It is small — the payloads are gone, and what is left is one digest per
    job plus a tag per node — and it is exactly the input to the root
    computation, so a receiver can check it against the block's staged ledger
    hash before trusting a byte of it:

    {[
      Hash.equal (hash (rebuilt received ~payload_digest:identity)) expected
    ]}

    Note what this is: [map] at a different payload type. The two type
    parameters, which looked like dead weight when the tree was a nest of
    pairs, are what makes the skeleton fall out of the structure rather than
    needing a parallel type and a parallel traversal to maintain alongside it.
    Reassembly is the same function in the other direction, mapping each
    digest to the payload that was fetched for it — and the obligation [map]
    carries, that the functions preserve digests, is discharged in both
    directions by construction. *)
let skeleton t ~(payload_digest : ('merge, 'base) Payload_digest.t) =
  map t ~f_merge:payload_digest.merge ~f_base:payload_digest.base

(** The payload digest of a skeleton, whose payloads {e are} digests. *)
let identity_digest = { Payload_digest.merge = Fn.id; base = Fn.id }

(** Fold over every node of the forest, oldest tree first and, within a tree,
    root downwards then left to right — the order the current
    [fold_chronological] visits, which [Transaction_snark_scan_state] relies on
    to compose statements. Heap order is that order. *)
let fold_chronological t ~init ~f_merge ~f_base =
  List.fold (List.rev t.trees) ~init ~f:(fun acc (tree : _ Tree.t) ->
      let acc = Array.fold tree.merges ~init:acc ~f:f_merge in
      Array.fold tree.bases ~init:acc ~f:f_base )

(** Effectful chronological fold, for callers that need to yield to a
    scheduler part-way — [Transaction_snark_scan_state.scan_statement] verifies
    a whole forest of statements and cannot hold the runtime for the duration.

    Same order as {!fold_chronological}, and stops early on [Stop]. *)
module Make_foldable (M : Monad.S) = struct
  open Container.Continue_or_stop

  let fold_chronological_until t ~init ~f_merge ~f_base ~finish =
    let open M.Let_syntax in
    let rec over_array array index acc ~f =
      if index >= Array.length array then M.return (Continue acc)
      else
        match%bind f acc array.(index) with
        | Continue acc ->
            over_array array (index + 1) acc ~f
        | Stop final ->
            M.return (Stop final)
    in
    let rec over_trees trees acc =
      match trees with
      | [] ->
          M.return (Continue acc)
      | (tree : _ Tree.t) :: rest -> (
          match%bind over_array tree.merges 0 acc ~f:f_merge with
          | Stop final ->
              M.return (Stop final)
          | Continue acc -> (
              match%bind over_array tree.bases 0 acc ~f:f_base with
              | Stop final ->
                  M.return (Stop final)
              | Continue acc ->
                  over_trees rest acc ) )
    in
    match%bind over_trees (List.rev t.trees) init with
    | Continue acc ->
        finish acc
    | Stop final ->
        M.return final
end

(** The stored shape.

    This is not a wire type. The scan state is transferred between nodes by the
    sync protocol, in verified fragments; what remains here is the whole-value
    form the frontier writes to its persistent root and passes around in its
    own diffs. Nothing untrusted parses it.

    So it is unversioned — the persistent frontier's database carries a version
    of its own and discards a store it cannot read — and its arrays are plain
    and unbounded, because the bound existed to stop a peer declaring an array
    it had no intention of sending.

    Converting is explicit rather than a [Binable.Of_binable] because the live
    form knows how to digest a payload and [bin_prot] has nowhere to pass that.
    The consumer already has a boundary in the right place:
    [write_all_proofs_to_disk] turns the stored form into the live one, and
    knows both payload types concretely. *)
module Wire = struct
  module Tree = struct
    type ('merge, 'base) t =
      { merges : 'merge Merge_node.Stable.V1.t array
      ; bases : 'base Base_node.Stable.V1.t array
      ; digests : string array
      ; filled : int
      ; level : int
      ; proved : int
      }
    [@@deriving bin_io_unversioned, sexp]
  end

  type ('merge, 'base) t =
    { trees : ('merge, 'base) Tree.t list
    ; acc : ('merge * 'base list) option
    ; max_base_jobs : int
    ; delay : int
    }
  [@@deriving bin_io_unversioned, sexp]
end

let to_wire (t : ('merge, 'base) t) : ('merge, 'base) Wire.t =
  { trees =
      List.map t.trees ~f:(fun tree ->
          { Wire.Tree.merges = tree.merges
          ; bases = tree.bases
          ; digests = Array.map tree.digests ~f:Hash.to_raw_string
          ; filled = tree.filled
          ; level = tree.level
          ; proved = tree.proved
          } )
  ; acc = t.acc
  ; max_base_jobs = t.max_base_jobs
  ; delay = t.delay
  }

(** The digests are taken from the store rather than recomputed.

    Recomputing them means a SHA256 over every payload's serialisation, and a
    base payload carries its ledger witnesses — so it is the expensive part of
    loading a scan state, and it is work the writer already did. That is only
    safe because this serialisation no longer crosses a trust boundary: a peer
    supplying digests could otherwise name payloads it had not sent, which is
    why the sync protocol recomputes each payload's digest on arrival instead
    of believing the one it was given. *)
let of_wire (w : ('merge, 'base) Wire.t) ~payload_digest : ('merge, 'base) t =
  { trees =
      List.map w.trees ~f:(fun tree ->
          { Tree.merges = tree.merges
          ; bases = tree.bases
          ; digests = Array.map tree.digests ~f:Hash.of_raw_string
          ; filled = tree.filled
          ; level = tree.level
          ; proved = tree.proved
          } )
  ; acc = w.acc
  ; acc_digest = digest_of_acc ~payload_digest w.acc
  ; max_base_jobs = w.max_base_jobs
  ; delay = w.delay
  }

(* Everything is ported except the two adapters that belong to the consumer
   rather than here: [Transaction_snark_scan_state.Job_view.to_yojson], which
   renders {!Job_view.Node.t} for [mina client snark-job-list], and the loop
   that copies {!metrics} into the [Mina_metrics] gauges. *)

let%test_module "port" =
  ( module struct
    (* A common shape for the two implementations' [Available_job.t]s, so that
       the work they offer can be compared directly. *)
    type job = Base of int | Merge of int * int
    [@@deriving compare, equal, sexp]

    let job_done = function Base d -> d | Merge (a, b) -> a + b

    let payload_digest =
      { Payload_digest.merge = Int.to_string; base = Int.to_string }

    let of_old (jobs : (int, int) Parallel_scan.Available_job.t list) =
      List.map jobs ~f:(function
        | Parallel_scan.Available_job.Base d ->
            Base d
        | Merge (a, b) ->
            Merge (a, b) )

    let of_new (jobs : (int, int) Available_job.t list) =
      List.map jobs ~f:(function
        | Available_job.Base d ->
            Base d
        | Merge (a, b) ->
            Merge (a, b) )

    (* Every node of the forest, in [fold_chronological] order, projected to a
       shape both implementations can produce. A [Done] merge node maps to
       [Merge_empty], which is the claim that dropping [Done] loses nothing:
       if that were false, this comparison would fail. *)
    type node =
      | Merge_empty
      | Merge_part of int
      | Merge_full of int * int
      | Base_empty
      | Base_full of int * [ `Proved | `Todo ]
    [@@deriving compare, equal, sexp]

    let old_nodes t =
      Parallel_scan.State.fold_chronological t ~init:[]
        ~f_merge:(fun acc (_weights, job) ->
          ( match job with
          | Parallel_scan.Merge.Job.Empty
          | Full { status = Done; _ } (* cleared by the port *) ->
              Merge_empty
          | Part x ->
              Merge_part x
          | Full { left; right; status = Todo; _ } ->
              Merge_full (left, right) )
          :: acc )
        ~f_base:(fun acc (_weight, job) ->
          ( match job with
          | Parallel_scan.Base.Job.Empty ->
              Base_empty
          | Full { job; status = Todo; _ } ->
              Base_full (job, `Todo)
          | Full { job; status = Done; _ } ->
              Base_full (job, `Proved) )
          :: acc )
      |> List.rev

    let new_nodes t =
      fold_chronological t ~init:[]
        ~f_merge:(fun acc job ->
          ( match job with
          | Merge_node.Empty ->
              Merge_empty
          | Part x ->
              Merge_part x
          | Full { left; right } ->
              Merge_full (left, right) )
          :: acc )
        ~f_base:(fun acc job ->
          ( match job with
          | Base_node.Empty ->
              Base_empty
          | Full { job; status = Todo } ->
              Base_full (job, `Todo)
          | Full { job; status = Done } ->
              Base_full (job, `Proved) )
          :: acc )
      |> List.rev

    (* One node as the view renders it, with the fields the port drops
       projected away, so the two views can be compared position by
       position. *)
    type view =
      | V_base_empty
      | V_base_full of int * [ `Proved | `Todo ]
      | V_merge_empty
      | V_merge_part of int
      | V_merge_full of int * int
    [@@deriving compare, equal, sexp]

    let old_views t =
      List.map
        (Parallel_scan.view_jobs_with_position t Fn.id Fn.id)
        ~f:
          (List.map ~f:(fun { Parallel_scan.Job_view.position; value } ->
               ( position
               , match value with
                 | BEmpty ->
                     V_base_empty
                 | BFull (x, { status = Todo; _ }) ->
                     V_base_full (x, `Todo)
                 | BFull (x, { status = Done; _ }) ->
                     V_base_full (x, `Proved)
                 | MEmpty ->
                     V_merge_empty
                 | MPart x ->
                     V_merge_part x
                 | MFull (_, _, { status = Done; _ }) ->
                     (* cleared by the port *) V_merge_empty
                 | MFull (x, y, { status = Todo; _ }) ->
                     V_merge_full (x, y) ) ) )

    let new_views t =
      List.map
        (job_views t ~f_merge:Fn.id ~f_base:Fn.id)
        ~f:
          (List.map ~f:(fun { Job_view.position; value } ->
               ( position
               , match value with
                 | Base_empty ->
                     V_base_empty
                 | Base_full { job; status = Todo } ->
                     V_base_full (job, `Todo)
                 | Base_full { job; status = Done } ->
                     V_base_full (job, `Proved)
                 | Merge_empty ->
                     V_merge_empty
                 | Merge_part x ->
                     V_merge_part x
                 | Merge_full { left; right } ->
                     V_merge_full (left, right) ) ) )

    (* [Tree.metrics] derives its counts from the cursors alone; this is the
       same thing counted by looking at every node. *)
    let counted_metrics (tree : (int, int) Tree.t) =
      { Tree_metrics.available_space =
          Array.count tree.bases ~f:(function
            | Base_node.Empty ->
                true
            | Full _ ->
                false )
      ; base_jobs_todo =
          Array.count tree.bases ~f:(function
            | Base_node.Full { status = Todo; _ } ->
                true
            | Empty | Full _ ->
                false )
      ; merge_jobs_todo =
          Array.count tree.merges ~f:(function
            | Merge_node.Full _ ->
                true
            | Empty | Part _ ->
                false )
      }

    (* A tree is never behind the schedule: when the schedule asks it for
       level [l] it is at [l], or it has already got past [l] (which happens
       when a block supplies a full level's worth of work without filling the
       current tree) and is waiting for the schedule to catch up. Being
       *behind* would mean jobs the schedule has moved past and will never ask
       for again, and would stall the tree. *)
    let check_levels t =
      [%test_eq: int] (List.hd_exn t.trees).Tree.level (depth t) ;
      List.iteri (List.tl_exn t.trees) ~f:(fun position tree ->
          match scheduled_level t ~position with
          | None ->
              ()
          | Some level ->
              if tree.Tree.level > level then
                raise_s
                  [%message
                    "tree is behind the schedule"
                      (position : int)
                      (tree.Tree.level : int)
                      (level : int)] )

    (* Distinct states must have distinct commitments, and equal states equal
       ones. Keyed on everything the state actually holds. *)
    let state_summary t =
      [%sexp
        ( ( new_nodes t
          , List.map t.trees ~f:(fun tree ->
                (tree.Tree.filled, tree.Tree.level, tree.Tree.proved) )
          , t.acc )
          : node list * (int * int * int) list * (int * int list) option )]

    let populated_state () =
      let max_base_jobs = 8 and delay = 2 in
      let t = ref (empty ~max_base_jobs ~delay) in
      let counter = ref 1 in
      for _ = 1 to 40 do
        let data = List.init max_base_jobs ~f:(fun i -> !counter + i) in
        counter := !counter + max_base_jobs ;
        let work =
          List.concat (work_for_next_update !t ~data_count:max_base_jobs)
        in
        let completed_jobs = List.map (of_new work) ~f:job_done in
        let _, t' =
          Or_error.ok_exn (update !t ~payload_digest ~data ~completed_jobs)
        in
        t := t'
      done ;
      !t

    let run ~max_base_jobs ~delay ~blocks ~size =
      let seen = Hashtbl.create (module String) in
      let seen_hash t =
        let key = Digestif.SHA256.to_hex (hash t) in
        let summary = state_summary t in
        match Hashtbl.find seen key with
        | None ->
            Hashtbl.set seen ~key ~data:summary
        | Some previous ->
            if not (Sexp.equal previous summary) then
              raise_s
                [%message
                  "two different states share a commitment"
                    (previous : Sexp.t)
                    (summary : Sexp.t)]
      in
      let old = ref (Parallel_scan.empty ~max_base_jobs ~delay) in
      let new_ = ref (empty ~max_base_jobs ~delay) in
      let counter = ref 1 in
      for block = 0 to blocks - 1 do
        let n = size block in
        let data = List.init n ~f:(fun i -> !counter + i) in
        counter := !counter + n ;
        let old_work = Parallel_scan.jobs_for_slots !old ~slots:n in
        let new_work = work_for_next_update !new_ ~data_count:n in
        [%test_eq: job list list]
          (List.map old_work ~f:of_old)
          (List.map new_work ~f:of_new) ;
        [%test_eq: job list list]
          (List.map (Parallel_scan.all_jobs !old) ~f:of_old)
          (List.map (all_jobs !new_) ~f:of_new) ;
        let op = Parallel_scan.partition_if_overflowing !old in
        let np = partition_if_overflowing !new_ in
        [%test_eq: (int * int) * (int * int) option] (op.first, op.second)
          (np.first, np.second) ;
        [%test_eq: int list list]
          (Parallel_scan.pending_data !old)
          (pending_data !new_) ;
        [%test_eq: bool]
          (Parallel_scan.next_on_new_tree !old)
          (next_on_new_tree !new_) ;
        let completed_jobs =
          List.map (of_old (List.concat old_work)) ~f:job_done
        in
        (* Agreement includes refusing the same blocks, not just accepting
           them: a [max_base_jobs] of 1 gives a tree with no merge nodes at
           all, which neither implementation can ever drain. *)
        match
          ( Parallel_scan.update ~data ~completed_jobs !old
          , update !new_ ~payload_digest ~data ~completed_jobs )
        with
        | Error _, Error _ ->
            ()
        | Ok _, Error e | Error e, Ok _ ->
            raise_s
              [%message
                "implementations disagree on whether the block is valid"
                  (block : int)
                  (n : int)
                  (e : Error.t)]
        | Ok (old_result, old'), Ok (new_result, new') ->
            [%test_eq: (int * int list) option] old_result new_result ;
            old := old' ;
            new_ := new' ;
            [%test_eq: node list] (old_nodes !old) (new_nodes !new_) ;
            (* the incrementally maintained digests are the ones a rebuild from
               the node contents would produce *)
            if
              not
                (Hash.equal (hash !new_) (hash (rebuilt !new_ ~payload_digest)))
            then
              raise_s
                [%message
                  "incremental digests diverged from a rebuild" (block : int)] ;
            (* changing payload representation without changing digests does not
               move the commitment *)
            if
              not
                (Hash.equal (hash !new_)
                   (hash (map !new_ ~f_merge:Fn.id ~f_base:Fn.id)) )
            then raise_s [%message "map moved the commitment" (block : int)] ;
            seen_hash !new_ ;
            [%test_eq: (int * view) list list] (old_views !old)
              (new_views !new_) ;
            List.iter !new_.trees ~f:(fun tree ->
                [%test_eq: Tree_metrics.t] (counted_metrics tree)
                  (Tree.metrics tree) ) ;
            (* and the counts mean what they meant before *)
            let old_counts =
              List.fold (old_nodes !old) ~init:(0, 0) ~f:(fun (b, m) node ->
                  match node with
                  | Base_full (_, `Todo) ->
                      (b + 1, m)
                  | Merge_full _ ->
                      (b, m + 1)
                  | _ ->
                      (b, m) )
            in
            let new_counts =
              List.fold (metrics !new_) ~init:(0, 0)
                ~f:(fun
                     (b, m)
                     { Tree_metrics.base_jobs_todo; merge_jobs_todo; _ }
                   -> (b + base_jobs_todo, m + merge_jobs_todo) )
            in
            [%test_eq: int * int] old_counts new_counts ;
            [%test_eq: (int * int list) option]
              (Parallel_scan.last_emitted_value !old)
              (last_emitted_value !new_) ;
            [%test_eq: int] (Parallel_scan.free_space !old) (free_space !new_) ;
            check_levels !new_
      done

    let%test_unit "full blocks" =
      List.iter [ 2; 4; 8; 16 ] ~f:(fun max_base_jobs ->
          List.iter [ 0; 1; 2; 3 ] ~f:(fun delay ->
              run ~max_base_jobs ~delay ~blocks:80 ~size:(fun _ ->
                  max_base_jobs ) ) )

    (* [max_base_jobs = 1] is the one configuration where the two do not
       agree, and the port is the one that works. A depth-0 tree is a single
       leaf whose base job is also its root; the current implementation builds
       it as a bare [Tree.Leaf] with no [Node], and [update_split] only ever
       returns a result from a [Node], so no proof is ever emitted and the
       forest grows until [update] refuses the next block. Here the level of a
       leaf-only tree is 0, which [place_result] recognises as the root.

       Mina never runs with a transaction capacity of one, so this is a
       curiosity rather than a bug fix — but it is a divergence, and it should
       be recorded as one rather than tuned out of the comparison. *)
    let%test_unit "single-leaf trees" =
      List.iter [ 0; 1; 2 ] ~f:(fun delay ->
          let t = ref (empty ~max_base_jobs:1 ~delay) in
          for block = 1 to 20 do
            let work = List.concat (work_for_next_update !t ~data_count:1) in
            let completed_jobs = List.map (of_new work) ~f:job_done in
            let result, t' =
              Or_error.ok_exn
                (update !t ~payload_digest ~data:[ block ] ~completed_jobs)
            in
            t := t' ;
            (* every transaction is its own tree, so each is emitted whole,
               [delay + 1] blocks after it was added *)
            if block > delay + 1 then
              [%test_eq: (int * int list) option] result
                (Some (block - delay - 1, [ block - delay - 1 ]))
          done )

    (* The point of maintaining the Merkle tree rather than recomputing it:
       measure the payload digests a block's incremental maintenance needs
       against those a full rebuild of the commitment needs. *)
    let%test_unit "incremental cost" =
      let max_base_jobs = 128 in
      let delay = 2 in
      let calls = ref 0 in
      let count s = incr calls ; s in
      let payload_digest =
        { Payload_digest.merge = (fun x -> count (Int.to_string x))
        ; base = (fun x -> count (Int.to_string x))
        }
      in
      let t = ref (empty ~max_base_jobs ~delay) in
      let counter = ref 1 in
      let step () =
        let data = List.init max_base_jobs ~f:(fun i -> !counter + i) in
        counter := !counter + max_base_jobs ;
        let work =
          List.concat (work_for_next_update !t ~data_count:max_base_jobs)
        in
        let completed_jobs = List.map (of_new work) ~f:job_done in
        let _, t' =
          Or_error.ok_exn (update !t ~payload_digest ~data ~completed_jobs)
        in
        t := t'
      in
      (* run to steady state: the forest is full and a proof comes out every
         block *)
      for _ = 1 to ((depth !t + 1) * (delay + 1)) + 4 do
        step ()
      done ;
      let before = !calls in
      step () ;
      let incremental = !calls - before in
      let before = !calls in
      ignore (hash (rebuilt !t ~payload_digest) : Hash.t) ;
      let rebuild = !calls - before in
      (* Measured at [max_base_jobs = 128], [delay = 2]: 511 payload digests
         to maintain the commitment across a block, against 3963 to rebuild
         it — which is what the current [hash] does every block. The 511 is
         128 for the block's own transactions, 254 for the merge nodes that
         received results, and 129 for [acc]. The margin asserted here is
         loose, so that it measures the shape of the cost rather than the
         exact figure. *)
      if not (incremental * 4 < rebuild) then
        raise_s
          [%message
            "incremental maintenance is not cheaper than rebuilding"
              (incremental : int)
              (rebuild : int)]

    (* A syncing node's whole trust chain, exercised: take the skeleton,
       rebuild its digests from scratch as a receiver would, check that it
       reproduces the commitment in the block, then reassemble the state from
       the skeleton plus payloads fetched by digest and check that it is the
       state we started with. *)
    let check_skeleton_round_trip t =
      let skeleton = skeleton t ~payload_digest in
      (* what a receiver can check before fetching anything *)
      let verified = rebuilt skeleton ~payload_digest:identity_digest in
      if not (Hash.equal (hash verified) (hash t)) then
        raise_s [%message "skeleton does not reproduce the commitment"] ;
      (* the payloads it would then go and fetch, by digest *)
      let payloads = Hashtbl.create (module String) in
      List.iter (new_nodes t) ~f:(function
        | Base_full (job, _) ->
            Hashtbl.set payloads ~key:(payload_digest.base job) ~data:job
        | Merge_full (left, right) ->
            Hashtbl.set payloads ~key:(payload_digest.merge left) ~data:left ;
            Hashtbl.set payloads ~key:(payload_digest.merge right) ~data:right
        | Merge_part x ->
            Hashtbl.set payloads ~key:(payload_digest.merge x) ~data:x
        | Base_empty | Merge_empty ->
            () ) ;
      Option.iter t.acc ~f:(fun (proof, data) ->
          Hashtbl.set payloads ~key:(payload_digest.merge proof) ~data:proof ;
          List.iter data ~f:(fun d ->
              Hashtbl.set payloads ~key:(payload_digest.base d) ~data:d ) ) ;
      let fetch digest = Hashtbl.find_exn payloads digest in
      let reassembled = map verified ~f_merge:fetch ~f_base:fetch in
      [%test_eq: node list] (new_nodes t) (new_nodes reassembled) ;
      if not (Hash.equal (hash reassembled) (hash t)) then
        raise_s [%message "reassembled state has a different commitment"]

    let%test_unit "skeleton round trip" =
      List.iter [ 4; 8 ] ~f:(fun max_base_jobs ->
          List.iter [ 0; 1; 2 ] ~f:(fun delay ->
              let t = ref (empty ~max_base_jobs ~delay) in
              let counter = ref 1 in
              for _ = 1 to 40 do
                let data = List.init max_base_jobs ~f:(fun i -> !counter + i) in
                counter := !counter + max_base_jobs ;
                let work =
                  List.concat
                    (work_for_next_update !t ~data_count:max_base_jobs)
                in
                let completed_jobs = List.map (of_new work) ~f:job_done in
                let _, t' =
                  Or_error.ok_exn
                    (update !t ~payload_digest ~data ~completed_jobs)
                in
                t := t' ;
                check_skeleton_round_trip !t
              done ) )

    (* The closed forms the sync design's scaling estimates rest on, checked
       against the implementation. If a change here invalidates one of these,
       the sizing in sync.md is wrong too. [w] is the work delay, [d] the
       depth, [C = 2^d] the capacity. *)
    let%test_unit "scaling model" =
      List.iter
        [ (7, 2); (9, 2); (8, 1); (6, 3) ]
        ~f:(fun (d, w) ->
          let capacity = 1 lsl d in
          let t = ref (empty ~max_base_jobs:capacity ~delay:w) in
          let counter = ref 1 in
          for _ = 1 to ((d + 1) * (w + 1)) + 6 do
            let data = List.init capacity ~f:(fun i -> !counter + i) in
            counter := !counter + capacity ;
            let work =
              List.concat (work_for_next_update !t ~data_count:capacity)
            in
            let completed_jobs = List.map (of_new work) ~f:job_done in
            let _, t' =
              Or_error.ok_exn (update !t ~payload_digest ~data ~completed_jobs)
            in
            t := t'
          done ;
          let nodes = new_nodes !t in
          let count f = List.count nodes ~f in
          let trees = ((d + 1) * (w + 1)) + 1 in
          (* the forest holds [(d+1)(w+1)] blocks of transactions in flight *)
          [%test_eq: int] (List.length !t.trees) trees ;
          [%test_eq: int] (List.length nodes) (trees * ((1 lsl (d + 1)) - 1)) ;
          [%test_eq: int]
            (count (function Base_full _ -> true | _ -> false))
            ((trees - 1) * capacity) ;
          [%test_eq: int]
            (count (function Merge_full _ -> true | _ -> false))
            ((w + 1) * (capacity - 1)) ;
          (* Only the trees whose base level the schedule has not yet reached
             hold transactions whose proof is outstanding — [w + 1] of them,
             so a [1 / (d + 1)] fraction of all the transactions in flight.
             Everything else is a transaction whose witnesses nothing will
             read again. *)
          [%test_eq: int]
            (count (function Base_full (_, `Todo) -> true | _ -> false))
            ((w + 1) * capacity) )

    (* The wire form drops the digest cache; [of_wire] must put back exactly
       what was there, or a node that restarts would disagree with the chain
       about its own scan state. *)
    let%test_unit "wire round trip" =
      List.iter
        [ (4, 1); (8, 2) ]
        ~f:(fun (max_base_jobs, delay) ->
          let t = ref (empty ~max_base_jobs ~delay) in
          let counter = ref 1 in
          for _ = 1 to 40 do
            let data = List.init max_base_jobs ~f:(fun i -> !counter + i) in
            counter := !counter + max_base_jobs ;
            let work =
              List.concat (work_for_next_update !t ~data_count:max_base_jobs)
            in
            let completed_jobs = List.map (of_new work) ~f:job_done in
            let _, t' =
              Or_error.ok_exn (update !t ~payload_digest ~data ~completed_jobs)
            in
            t := t' ;
            let bytes =
              Binable.to_string
                ( module struct
                  type t = (int, int) Wire.t [@@deriving bin_io]
                end )
                (to_wire !t)
            in
            let back =
              of_wire ~payload_digest
                (Binable.of_string
                   ( module struct
                     type t = (int, int) Wire.t [@@deriving bin_io]
                   end )
                   bytes )
            in
            if not (Hash.equal (hash back) (hash !t)) then
              raise_s [%message "wire round trip changed the commitment"] ;
            (* [of_wire] believes the digests it was given rather than deriving
               them, so the round trip alone would agree with itself even if
               they were wrong. Recomputing is what checks them. *)
            if
              not (Hash.equal (hash (rebuilt back ~payload_digest)) (hash back))
            then
              raise_s [%message "stored digests disagree with recomputed ones"] ;
            [%test_eq: node list] (new_nodes !t) (new_nodes back)
          done )

    (* A tree far wider than the small capacities above. This once hit a
       bounded-array limit that left a node at a capacity of 2^12 unable to
       serialise its own genesis scan state, and the cheap capacities never
       reached it — so the failure was only discoverable by starting a node.
       The stored form is unbounded now, but the case is worth keeping. *)
    let%test_unit "wire round trip at a large capacity" =
      let max_base_jobs = 4096 in
      let t = ref (empty ~max_base_jobs ~delay:1) in
      let counter = ref 1 in
      for _ = 1 to 3 do
        let data = List.init max_base_jobs ~f:(fun i -> !counter + i) in
        counter := !counter + max_base_jobs ;
        let work =
          List.concat (work_for_next_update !t ~data_count:max_base_jobs)
        in
        let completed_jobs = List.map (of_new work) ~f:job_done in
        let _, t' =
          Or_error.ok_exn (update !t ~payload_digest ~data ~completed_jobs)
        in
        t := t'
      done ;
      let wire = to_wire !t in
      let bytes =
        Binable.to_string
          ( module struct
            type t = (int, int) Wire.t [@@deriving bin_io]
          end )
          wire
      in
      let back =
        of_wire ~payload_digest
          (Binable.of_string
             ( module struct
               type t = (int, int) Wire.t [@@deriving bin_io]
             end )
             bytes )
      in
      if not (Hash.equal (hash back) (hash !t)) then
        raise_s [%message "wire round trip changed the commitment"] ;
      if not (Hash.equal (hash (rebuilt back ~payload_digest)) (hash back)) then
        raise_s [%message "stored digests disagree with recomputed ones"]

    (* The effectful fold must visit what the pure one visits, in the same
       order — [scan_statement] composes statements along it. *)
    let%test_unit "monadic fold agrees with the pure one" =
      let module Fold = Make_foldable (Monad.Ident) in
      let t = populated_state () in
      let pure =
        fold_chronological t ~init:[]
          ~f_merge:(fun acc node -> `M node :: acc)
          ~f_base:(fun acc node -> `B node :: acc)
      in
      let monadic =
        Fold.fold_chronological_until t ~init:[]
          ~f_merge:(fun acc node ->
            Container.Continue_or_stop.Continue (`M node :: acc) )
          ~f_base:(fun acc node ->
            Container.Continue_or_stop.Continue (`B node :: acc) )
          ~finish:Fn.id
      in
      [%test_eq: int] (List.length pure) (List.length monadic) ;
      if not (Poly.equal pure monadic) then
        raise_s [%message "monadic fold visited a different sequence"] ;
      (* and [Stop] really stops *)
      let stopped =
        Fold.fold_chronological_until t ~init:0
          ~f_merge:(fun acc _ ->
            if acc >= 3 then Container.Continue_or_stop.Stop acc
            else Continue (acc + 1) )
          ~f_base:(fun acc _ -> Container.Continue_or_stop.Continue (acc + 1))
          ~finish:Fn.id
      in
      [%test_eq: int] stopped 3

    let%test_unit "partial blocks" =
      List.iter [ 2; 4; 8; 16 ] ~f:(fun max_base_jobs ->
          List.iter [ 0; 1; 2; 3 ] ~f:(fun delay ->
              List.iter [ 3; 5; 7 ] ~f:(fun stride ->
                  run ~max_base_jobs ~delay ~blocks:150 ~size:(fun block ->
                      block * stride % (max_base_jobs + 1) ) ) ) )

    let%test_unit "random blocks" =
      Quickcheck.test
        (Quickcheck.Generator.list_with_length 120 (Int.gen_incl 0 8))
        ~trials:40
        ~f:(fun sizes ->
          let sizes = Array.of_list sizes in
          List.iter [ 0; 1; 2; 3 ] ~f:(fun delay ->
              run ~max_base_jobs:8 ~delay ~blocks:(Array.length sizes)
                ~size:(fun block -> sizes.(block)) ) )
  end )
