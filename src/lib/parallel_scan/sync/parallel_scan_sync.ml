(** The scan state sync protocol, over the types in {!Parallel_scan}.

    See [sync.md] for why this shape and not another. In short: the block
    header commits to the scan state, {!Parallel_scan.hash} is a Merkle
    tree whose shape is the scan state itself, and so a peer can be made to
    prove every piece it sends against something the chain already vouches for.
    Nothing here needs to trust a peer, and no piece is larger than the caller
    chooses to ask for.

    The protocol has three message kinds, each verified against something
    already verified:

    - a {!Manifest}, verified against the block's [aux_hash];
    - a {!Band} — a bounded slice of one tree's skeleton — verified against a
      digest the manifest or an earlier band supplied;
    - the payloads themselves, verified against the digests the bands name.

    Payload transport is deliberately {e not} here. A payload is authenticated
    by [SHA256 bytes = digest] and nothing else, so it needs no help from this
    module; the caller fetches bytes by digest however it likes and hands them
    to {!Builder.add_payload}. What this module owns is the part where the
    structure has to be reconstructed and checked. *)

open Core_kernel
open Parallel_scan
module Tree = Parallel_scan.Private.Tree

(* Digests travel as their raw bytes. The scan state's own [Hash.t] is a
   [Digestif] value, which is convenient in memory and awkward on a wire;
   payload digests are already strings, so using raw strings for both keeps one
   representation rather than two and makes every message [bin_io]-able without
   a parallel set of wire types. [raw]/[unraw] are the only places the two
   meet. *)
let raw = Hash.to_raw_string

let unraw = Digestif.SHA256.of_raw_string

(** Where a node sits in a tree: [level] counts from the root, [index] from the
    left within that level. This is {!Parallel_scan.Tree.slot} split into
    its two components, because a band is addressed by subtree rather than by
    array offset. *)
module Address = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = { level : int; index : int }
      [@@deriving compare, equal, hash, sexp]

      let to_latest = Fn.id
    end
  end]

  type t = Stable.Latest.t = { level : int; index : int }
  [@@deriving compare, equal, hash, sexp]

  let root = { level = 0; index = 0 }

  let child t ~side = { level = t.level + 1; index = (2 * t.index) + side }
end

(** How far a tree has got. Not derivable from the node contents, so it travels
    with the manifest and is checked when the tree's root band arrives. *)
module Cursors = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = { filled : int; level : int; proved : int }
      [@@deriving compare, equal, sexp]

      let to_latest = Fn.id
    end
  end]

  type t = Stable.Latest.t = { filled : int; level : int; proved : int }
  [@@deriving compare, equal, sexp]

  let of_tree (tree : _ Tree.t) =
    { filled = Parallel_scan.Private.Tree.filled tree
    ; level = Parallel_scan.Private.Tree.level tree
    ; proved = Parallel_scan.Private.Tree.proved tree
    }
end

(** The whole forest in about two kilobytes: one digest and three integers per
    tree, plus the parameters and the emitted value.

    This is exactly the input to {!Parallel_scan.hash}, so {!verify}
    recomputes the commitment from it and compares against the block. A peer
    that lies about any of it is caught before a single payload is fetched. *)
module Manifest = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        { max_base_jobs : int
        ; delay : int
        ; acc :
            ( Mina_stdlib.Bounded_types.String.Stable.V1.t
            * Mina_stdlib.Bounded_types.String.Stable.V1.t list )
            option
        ; trees :
            (Mina_stdlib.Bounded_types.String.Stable.V1.t * Cursors.Stable.V1.t)
            list
        }
      [@@deriving sexp]

      let to_latest = Fn.id
    end
  end]

  type t = Stable.Latest.t =
    { max_base_jobs : int
    ; delay : int
    ; acc : (string * string list) option
          (** payload digests of the last emitted proof and its transactions *)
    ; trees : (string * Cursors.t) list  (** oldest first *)
    }
  [@@deriving sexp]

  let of_state (t : _ Parallel_scan.t) ~payload_digest =
    { max_base_jobs = Parallel_scan.Private.max_base_jobs t
    ; delay = Parallel_scan.Private.delay t
    ; acc =
        Option.map (Parallel_scan.Private.acc t) ~f:(fun (proof, data) ->
            ( payload_digest.Payload_digest.merge proof
            , List.map data ~f:payload_digest.Payload_digest.base ) )
    ; trees =
        List.rev_map (Parallel_scan.Private.trees t) ~f:(fun tree ->
            (raw (Tree.digest tree), Cursors.of_tree tree) )
    }

  (** The commitment this manifest describes. Mirrors
      {!Parallel_scan.hash}; the [identity_digest] is because the manifest
      already holds payload digests rather than payloads. *)
  let root (t : t) =
    let acc_digest =
      Parallel_scan.Private.digest_of_acc ~payload_digest:identity_digest t.acc
    in
    Parallel_scan.Private.digest_fields
      ( [ "scan_state"
        ; Int.to_string t.max_base_jobs
        ; Int.to_string t.delay
        ; Hash.to_raw_string acc_digest
        ]
      @ List.map t.trees ~f:(fun (digest, _) -> digest) )

  let verify t ~expected =
    if Hash.equal (root t) expected then Ok ()
    else
      Or_error.error_string
        "scan state manifest does not match the commitment in the block"

  let depth t = Int.ceil_log2 t.max_base_jobs
end

(** A bounded slice of one tree's skeleton: the subtree rooted at [root],
    truncated to [height] levels below it, with the digests of the nodes
    immediately below the slice so that the next request down can be checked
    and so that this one can be folded up to a root digest.

    [height] is the caller's lever over message size. A band holds
    [2^(height+1) - 1] nodes and [2^(height+1)] boundary digests, so the
    request for a whole tree is [{root; height = depth}] and anything smaller
    is a descent. Section 7 of [sync.md] is the argument for having this knob
    at all: at a transaction capacity of 2^18 a whole-tree band is 24MB, which
    is the problem this protocol exists to avoid, one level down. *)
module Band = struct
  module Node = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t =
          | Merge of
              Mina_stdlib.Bounded_types.String.Stable.V1.t
              Merge_node.Stable.V1.t
          | Base of
              Mina_stdlib.Bounded_types.String.Stable.V1.t Base_node.Stable.V1.t
        [@@deriving sexp]

        let to_latest = Fn.id
      end
    end]

    type t = Stable.Latest.t =
      | Merge of string Merge_node.t
      | Base of string Base_node.t
    [@@deriving sexp]
  end

  type node = Node.t =
    | Merge of string Merge_node.t
    | Base of string Base_node.t
  [@@deriving sexp]

  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        { root : Address.Stable.V1.t
        ; height : int
        ; nodes :
            Node.Stable.V1.t Mina_stdlib.Bounded_types.ArrayN4000.Stable.V1.t
        ; boundary :
            Mina_stdlib.Bounded_types.String.Stable.V1.t
            Mina_stdlib.Bounded_types.ArrayN4000.Stable.V1.t
        }
      [@@deriving sexp]

      let to_latest = Fn.id
    end
  end]

  (* [ArrayN4000] caps a band at 4000 nodes, so [height] must stay under 12
     however deep the tree is. That is a bound on the message, which is the
     point of banding — but it is a second place the ceiling has to move if the
     transaction capacity grows past 2^11. *)

  type t = Stable.Latest.t =
    { root : Address.t
    ; height : int
    ; nodes : node array
          (** heap order within the band: the root, then its two children, and
              so on — [2^(height+1) - 1] of them *)
    ; boundary : string array
          (** digests of the [2^(height+1)] nodes one level below the band,
              left to right; empty when the band reaches the base level *)
    }
  [@@deriving sexp]

  (** Index into [nodes] of the node [level_offset] levels below the band's
      root, [index] from the left of that band level. *)
  let offset ~level_offset ~index = (1 lsl level_offset) - 1 + index

  let node_count ~height = (1 lsl (height + 1)) - 1

  (** Fold the band up to the digest of its root node. This is the whole of
      verification: a band is trusted exactly when this matches the digest its
      parent named for it. *)
  let root_digest t ~depth =
    let rec go ~level_offset ~index =
      let absolute = t.root.level + level_offset in
      if level_offset > t.height then unraw t.boundary.(index)
      else
        match t.nodes.(offset ~level_offset ~index) with
        | Base base ->
            Tree.digest_of_base ~payload_digest:identity_digest base
        | Merge merge ->
            if absolute >= depth then
              (* a merge node cannot sit at the base level *)
              failwith "parallel_scan_sync: merge node below the merge levels"
            else
              Tree.digest_of_merge ~payload_digest:identity_digest
                ~left:(go ~level_offset:(level_offset + 1) ~index:(2 * index))
                ~right:
                  (go ~level_offset:(level_offset + 1)
                     ~index:((2 * index) + 1) )
                merge
    in
    go ~level_offset:0 ~index:0

  (** Structural checks that must pass before [root_digest] is even meaningful:
      a peer must not be able to make us index out of bounds. *)
  let check_shape t ~depth =
    let open Or_error.Let_syntax in
    let bottom = t.root.level + t.height in
    let%bind () =
      if
        t.root.level >= 0 && t.height >= 0 && bottom <= depth
        && t.root.index >= 0
        && t.root.index < 1 lsl t.root.level
      then Ok ()
      else Or_error.error_string "band address out of range"
    in
    let%bind () =
      if Array.length t.nodes = node_count ~height:t.height then Ok ()
      else
        Or_error.errorf "band has %d nodes, expected %d" (Array.length t.nodes)
          (node_count ~height:t.height)
    in
    let expected_boundary =
      if bottom = depth then 0 else 1 lsl (t.height + 1)
    in
    if Array.length t.boundary = expected_boundary then Ok ()
    else
      Or_error.errorf "band has %d boundary digests, expected %d"
        (Array.length t.boundary) expected_boundary

  let verify t ~depth ~expected =
    let open Or_error.Let_syntax in
    let%bind () = check_shape t ~depth in
    if Hash.equal (root_digest t ~depth) expected then Ok ()
    else Or_error.error_string "band does not match the digest claimed for it"

  (** Cut this band out of a tree. The producer side; it does no verifying,
      because it is answering rather than asking. *)
  let of_tree (tree : (string, string) Tree.t) ~root ~height =
    let depth = Tree.depth tree in
    let bottom = root.Address.level + height in
    let node ~absolute ~index =
      if absolute = depth then
        Base (Parallel_scan.Private.Tree.bases tree).(index)
      else
        Merge
          (Parallel_scan.Private.Tree.merges tree).(Tree.slot ~level:absolute
                                                      ~index)
    in
    let nodes =
      Array.init (node_count ~height) ~f:(fun _ -> Merge Merge_node.Empty)
    in
    for level_offset = 0 to height do
      let absolute = root.Address.level + level_offset in
      let first = root.Address.index * (1 lsl level_offset) in
      for index = 0 to (1 lsl level_offset) - 1 do
        nodes.(offset ~level_offset ~index) <-
          node ~absolute ~index:(first + index)
      done
    done ;
    let boundary =
      if bottom = depth then [||]
      else
        let absolute = bottom + 1 in
        let first = root.Address.index * (1 lsl (height + 1)) in
        Array.init
          (1 lsl (height + 1))
          ~f:(fun index ->
            raw
              (Tree.digests tree).(Tree.slot ~level:absolute
                                     ~index:(first + index)) )
    in
    { root; height; nodes; boundary }
end

(** What the consumer still wants. *)
module Request = struct
  type t =
    | Band of { tree : int; root : Address.t; height : int }
        (** [tree] indexes the manifest's list, oldest first; the caller turns
            it into the tree digest, which is what a peer is asked for *)
    | Payload of string  (** a payload digest *)
  [@@deriving sexp]
end

(** Reception. Holds the verified manifest and whatever has arrived, refuses
    anything that does not check out, and assembles a scan state once
    everything is in.

    The accumulation deliberately does not happen in a
    {!Parallel_scan.t}: that type has invariants — one live level per tree,
    cursors consistent with the node contents — which a half-received state
    violates. Reception fills option arrays and only builds the real thing at
    the end. *)
module Builder = struct
  type tree =
    { expected : string
    ; cursors : Cursors.t
    ; merges : string Merge_node.t option array
    ; bases : string Base_node.t option array
    ; wanted : (Address.t, string) Hashtbl.t
          (** subtrees still to fetch, and the digest each must produce *)
    }

  type t =
    { manifest : Manifest.t
    ; depth : int
    ; band_height : int
    ; trees : tree array  (** oldest first, matching the manifest *)
    ; payloads : (string, string option) Hashtbl.t
          (** digest -> bytes, [None] until it arrives *)
    }

  (** Verify a manifest against the block's commitment and open a builder on
      it. [band_height] is how much of a tree to ask for at a time. *)
  let create manifest ~expected ~band_height =
    let open Or_error.Let_syntax in
    let%map () = Manifest.verify manifest ~expected in
    let depth = Manifest.depth manifest in
    let trees =
      List.map manifest.trees ~f:(fun (digest, cursors) ->
          let wanted = Hashtbl.create (module Address) in
          Hashtbl.set wanted ~key:Address.root ~data:digest ;
          { expected = digest
          ; cursors
          ; merges = Array.create ~len:((1 lsl depth) - 1) None
          ; bases = Array.create ~len:(1 lsl depth) None
          ; wanted
          } )
      |> Array.of_list
    in
    let payloads = Hashtbl.create (module String) in
    (* the last emitted proof and its transactions are named by the manifest
       rather than by any node, and are just as much a part of the state *)
    Option.iter manifest.acc ~f:(fun (proof, data) ->
        Hashtbl.set payloads ~key:proof ~data:None ;
        List.iter data ~f:(fun digest ->
            Hashtbl.set payloads ~key:digest ~data:None ) ) ;
    { manifest
    ; depth
    ; band_height = Int.min band_height depth
    ; trees
    ; payloads
    }

  let tree_digest t ~tree = t.trees.(tree).expected

  (** Everything still outstanding: the subtrees not yet received, then the
      payloads named by what has been. Bands come first because they are what
      names the payloads. *)
  let wanted t =
    let bands =
      Array.to_list t.trees
      |> List.concat_mapi ~f:(fun tree entry ->
             Hashtbl.keys entry.wanted
             |> List.map ~f:(fun root ->
                    Request.Band
                      { tree
                      ; root
                      ; height = Int.min t.band_height (t.depth - root.level)
                      } ) )
    in
    let payloads =
      Hashtbl.to_alist t.payloads
      |> List.filter_map ~f:(fun (digest, bytes) ->
             Option.some_if (Option.is_none bytes) (Request.Payload digest) )
    in
    bands @ payloads

  (* Every payload digest a node names, so that receiving a band tells us what
     to fetch next. *)
  let payloads_of_node = function
    | Band.Merge Merge_node.Empty | Band.Base Base_node.Empty ->
        []
    | Band.Merge (Part x) ->
        [ x ]
    | Band.Merge (Full { left; right }) ->
        [ left; right ]
    | Band.Base (Full { job; _ }) ->
        [ job ]

  (** Take a band for [tree], having checked it against the digest we were
      promised, and record both its nodes and the subtrees it now points at. *)
  let add_band t ~tree (band : Band.t) =
    let open Or_error.Let_syntax in
    let%bind entry =
      if tree >= 0 && tree < Array.length t.trees then Ok t.trees.(tree)
      else Or_error.errorf "no tree %d in this manifest" tree
    in
    let%bind expected =
      match Hashtbl.find entry.wanted band.root with
      | Some digest ->
          Ok digest
      | None ->
          Or_error.error_string "band for a subtree that was not outstanding"
    in
    (* At the tree root the digest we were promised is the tree digest, which
       covers the cursors as well as the node contents. *)
    let%bind () =
      if Address.equal band.root Address.root then
        let%bind () = Band.check_shape band ~depth:t.depth in
        let node_root = Band.root_digest band ~depth:t.depth in
        let recomputed =
          Parallel_scan.Private.digest_fields
            [ "tree"
            ; Hash.to_raw_string node_root
            ; Int.to_string entry.cursors.filled
            ; Int.to_string entry.cursors.level
            ; Int.to_string entry.cursors.proved
            ]
        in
        if String.equal (raw recomputed) expected then Ok ()
        else
          Or_error.error_string
            "tree root band does not match the tree digest (contents or \
             cursors are wrong)"
      else Band.verify band ~depth:t.depth ~expected:(unraw expected)
    in
    Hashtbl.remove entry.wanted band.root ;
    for level_offset = 0 to band.height do
      let absolute = band.root.level + level_offset in
      let first = band.root.index * (1 lsl level_offset) in
      for index = 0 to (1 lsl level_offset) - 1 do
        let node = band.nodes.(Band.offset ~level_offset ~index) in
        ( match node with
        | Band.Base base ->
            entry.bases.(first + index) <- Some base
        | Band.Merge merge ->
            entry.merges.(Tree.slot ~level:absolute ~index:(first + index)) <-
              Some merge ) ;
        List.iter (payloads_of_node node) ~f:(fun digest ->
            if not (Hashtbl.mem t.payloads digest) then
              Hashtbl.set t.payloads ~key:digest ~data:None )
      done
    done ;
    (* whatever the band stopped short of is the next thing to ask for *)
    let bottom = band.root.level + band.height in
    if bottom < t.depth then
      Array.iteri band.boundary ~f:(fun index digest ->
          let address =
            { Address.level = bottom + 1
            ; index = (band.root.index * (1 lsl (band.height + 1))) + index
            }
          in
          Hashtbl.set entry.wanted ~key:address ~data:digest ) ;
    Ok ()

  (** Take a payload, having checked its bytes against the digest that names
      it. [digest_of_bytes] is how the caller hashes a payload — the same
      function the scan state uses for that payload type. *)
  let add_payload t ~digest_of_bytes ~bytes =
    let digest = digest_of_bytes bytes in
    if not (Hashtbl.mem t.payloads digest) then
      Or_error.error_string "payload that no part of the scan state names"
    else Ok (Hashtbl.set t.payloads ~key:digest ~data:(Some bytes))

  let outstanding t =
    let bands =
      Array.sum (module Int) t.trees ~f:(fun e -> Hashtbl.length e.wanted)
    in
    let payloads = Hashtbl.count t.payloads ~f:Option.is_none in
    (`Bands bands, `Payloads payloads)

  (** How many payloads have arrived, against how many are known to be needed.
      The denominator grows as bands reveal what is underneath them, so early
      on it understates the work left. *)
  let payload_progress t =
    let have = Hashtbl.count t.payloads ~f:Option.is_some in
    (`Received have, `Known (Hashtbl.length t.payloads))

  (** Assemble the scan state. Fails while anything is still outstanding.

      [of_bytes] parses a payload; the two are separate because a merge payload
      and a base payload are different types. Assembly itself is
      {!Parallel_scan.map} over the received skeleton — the same function
      that produced it, run backwards. *)
  let finish t ~merge_of_bytes ~base_of_bytes =
    let open Or_error.Let_syntax in
    let `Bands bands, `Payloads payloads = outstanding t in
    let%bind () =
      if bands = 0 && payloads = 0 then Ok ()
      else
        Or_error.errorf "still waiting on %d bands and %d payloads" bands
          payloads
    in
    let%map trees =
      Array.to_list t.trees
      |> List.map ~f:(fun entry ->
             let%map merges =
               Array.to_list entry.merges
               |> List.map ~f:(function
                    | Some node ->
                        Ok node
                    | None ->
                        Or_error.error_string "a merge node never arrived" )
               |> Or_error.all
             and bases =
               Array.to_list entry.bases
               |> List.map ~f:(function
                    | Some node ->
                        Ok node
                    | None ->
                        Or_error.error_string "a base node never arrived" )
               |> Or_error.all
             in
             let tree =
               Tree.create ~merges:(Array.of_list merges)
                 ~bases:(Array.of_list bases)
                 ~digests:(Tree.empty_digests ~depth:t.depth)
                 ~filled:entry.cursors.filled ~level:entry.cursors.level
                 ~proved:entry.cursors.proved
             in
             Tree.rebuilt tree ~payload_digest:identity_digest )
      |> Or_error.all
    in
    let acc =
      Option.map t.manifest.acc ~f:(fun (proof, data) -> (proof, data))
    in
    let skeleton =
      Parallel_scan.Private.create
        ~trees:(List.rev trees) (* the manifest is oldest first *)
        ~acc ~payload_digest:identity_digest
        ~max_base_jobs:t.manifest.max_base_jobs ~delay:t.manifest.delay
    in
    let fetch of_bytes digest =
      of_bytes (Option.value_exn (Hashtbl.find_exn t.payloads digest))
    in
    map skeleton ~f_merge:(fetch merge_of_bytes) ~f_base:(fetch base_of_bytes)
end

let%test_module "sync" =
  ( module struct
    (* Payloads are ints; their wire bytes are the decimal string and their
       digest is that tagged, so a digest is never accidentally equal to the
       bytes it names. *)
    let payload_digest =
      { Payload_digest.merge = (fun x -> "M" ^ Int.to_string x)
      ; base = (fun x -> "B" ^ Int.to_string x)
      }

    let job_done = function Available_job.Base d -> d | Merge (a, b) -> a + b

    (* A producer: everything a peer would answer from, and nothing else. *)
    module Peer = struct
      type t =
        { skeleton : (string, string) Parallel_scan.t
        ; bytes_of_digest : (string, string) Hashtbl.t
        }

      let create state =
        let bytes_of_digest = Hashtbl.create (module String) in
        let note digest bytes =
          Hashtbl.set bytes_of_digest ~key:digest ~data:bytes
        in
        fold_chronological state ~init:()
          ~f_merge:(fun () node ->
            match node with
            | Merge_node.Empty ->
                ()
            | Part x ->
                note (payload_digest.merge x) (Int.to_string x)
            | Full { left; right } ->
                note (payload_digest.merge left) (Int.to_string left) ;
                note (payload_digest.merge right) (Int.to_string right) )
          ~f_base:(fun () node ->
            match node with
            | Base_node.Empty ->
                ()
            | Full { job; _ } ->
                note (payload_digest.base job) (Int.to_string job) ) ;
        Option.iter (Parallel_scan.Private.acc state) ~f:(fun (proof, data) ->
            note (payload_digest.merge proof) (Int.to_string proof) ;
            List.iter data ~f:(fun d ->
                note (payload_digest.base d) (Int.to_string d) ) ) ;
        { skeleton = skeleton state ~payload_digest; bytes_of_digest }

      (* the manifest is oldest first; [trees] is newest first *)
      let tree t ~index =
        let trees = Parallel_scan.Private.trees t.skeleton in
        List.nth_exn trees (List.length trees - 1 - index)

      let band t ~index ~root ~height =
        Band.of_tree (tree t ~index) ~root ~height

      let payload t digest = Hashtbl.find_exn t.bytes_of_digest digest
    end

    let digest_of_bytes_merge bytes = "M" ^ bytes

    let digest_of_bytes_base bytes = "B" ^ bytes

    (* Drive a whole sync and return the reconstructed state. *)
    let sync state ~band_height =
      let peer = Peer.create state in
      let manifest = Manifest.of_state state ~payload_digest in
      let builder =
        Or_error.ok_exn
          (Builder.create manifest ~expected:(hash state) ~band_height)
      in
      let rec drive rounds =
        if rounds > 200 then failwith "sync did not converge" ;
        match Builder.wanted builder with
        | [] ->
            ()
        | requests ->
            List.iter requests ~f:(function
              | Request.Band { tree; root; height } ->
                  Or_error.ok_exn
                    (Builder.add_band builder ~tree
                       (Peer.band peer ~index:tree ~root ~height) )
              | Request.Payload digest ->
                  if not (Hashtbl.mem peer.Peer.bytes_of_digest digest) then
                    raise_s
                      [%message
                        "peer does not have a payload the state names"
                          (digest : string)
                          ( Hashtbl.keys peer.Peer.bytes_of_digest
                            |> List.sort ~compare:String.compare
                            : string list )] ;
                  let bytes = Peer.payload peer digest in
                  let digest_of_bytes =
                    if Char.equal digest.[0] 'M' then digest_of_bytes_merge
                    else digest_of_bytes_base
                  in
                  Or_error.ok_exn
                    (Builder.add_payload builder ~digest_of_bytes ~bytes) ) ;
            drive (rounds + 1)
      in
      drive 0 ;
      Or_error.ok_exn
        (Builder.finish builder ~merge_of_bytes:Int.of_string
           ~base_of_bytes:Int.of_string )

    (* Run some blocks so the forest is populated and a proof has been
       emitted. *)
    let populated ~max_base_jobs ~delay ~blocks =
      let t = ref (empty ~max_base_jobs ~delay) in
      let counter = ref 1 in
      for _ = 1 to blocks do
        let data = List.init max_base_jobs ~f:(fun i -> !counter + i) in
        counter := !counter + max_base_jobs ;
        let work = List.concat (jobs_for_slots !t ~slots:max_base_jobs) in
        let completed_jobs = List.map work ~f:job_done in
        let _, t' =
          Or_error.ok_exn (update !t ~payload_digest ~data ~completed_jobs)
        in
        t := t'
      done ;
      !t

    let%test_unit "a synced state is the state that was synced" =
      List.iter
        [ (4, 0); (4, 2); (8, 1); (8, 2) ]
        ~f:(fun (max_base_jobs, delay) ->
          let state =
            populated ~max_base_jobs ~delay
              ~blocks:(((Int.ceil_log2 max_base_jobs + 1) * (delay + 1)) + 4)
          in
          (* every band height from one level at a time to the whole tree *)
          List.iter
            (List.init (Int.ceil_log2 max_base_jobs + 1) ~f:(fun h -> h + 1))
            ~f:(fun band_height ->
              let synced = sync state ~band_height in
              if not (Hash.equal (hash synced) (hash state)) then
                raise_s
                  [%message
                    "synced state has a different commitment" (band_height : int)] ;
              [%test_eq: int list list] (pending_data state)
                (pending_data synced) ;
              [%test_eq: (int * int list) option]
                (Parallel_scan.Private.acc state)
                (Parallel_scan.Private.acc synced) ) )

    let%test_unit "a tampered manifest is rejected" =
      let state = populated ~max_base_jobs:4 ~delay:1 ~blocks:20 in
      let manifest = Manifest.of_state state ~payload_digest in
      let expected = hash state in
      (* the honest one is accepted *)
      Or_error.ok_exn (Manifest.verify manifest ~expected) ;
      let tampered =
        [ { manifest with delay = manifest.delay + 1 }
        ; { manifest with trees = List.tl_exn manifest.trees }
        ; { manifest with
            trees =
              List.mapi manifest.trees ~f:(fun i (d, c) ->
                  if i = 0 then (d, { c with Cursors.proved = c.proved + 1 })
                  else (d, c) )
          }
        ; { manifest with acc = None }
        ]
      in
      List.iteri tampered ~f:(fun i m ->
          (* the cursor tamper survives the manifest check by construction —
             the cursors are inside the tree digests, not the forest root — and
             is caught when the tree's root band arrives instead *)
          let caught_here = Or_error.is_error (Manifest.verify m ~expected) in
          let caught_later =
            i = 2
            &&
            match Builder.create m ~expected ~band_height:1 with
            | Error _ ->
                true
            | Ok builder ->
                let peer = Peer.create state in
                Or_error.is_error
                  (Builder.add_band builder ~tree:0
                     (Peer.band peer ~index:0 ~root:Address.root ~height:1) )
          in
          if not (caught_here || caught_later) then
            raise_s [%message "tampered manifest accepted" (i : int)] )

    let%test_unit "a tampered band is rejected" =
      let state = populated ~max_base_jobs:8 ~delay:1 ~blocks:30 in
      let peer = Peer.create state in
      let manifest = Manifest.of_state state ~payload_digest in
      let builder =
        Or_error.ok_exn
          (Builder.create manifest ~expected:(hash state) ~band_height:1)
      in
      let honest = Peer.band peer ~index:0 ~root:Address.root ~height:1 in
      let swap_node (band : Band.t) =
        let nodes = Array.copy band.nodes in
        nodes.(Array.length nodes - 1) <- Band.Merge (Merge_node.Part "M999999") ;
        { band with nodes }
      in
      let swap_boundary (band : Band.t) =
        let boundary = Array.copy band.boundary in
        boundary.(0) <-
          raw (Parallel_scan.Private.digest_fields [ "not the right digest" ]) ;
        { band with boundary }
      in
      let wrong_shape (band : Band.t) =
        { band with nodes = Array.subo band.nodes ~len:1 }
      in
      List.iter
        [ swap_node honest; swap_boundary honest; wrong_shape honest ]
        ~f:(fun band ->
          match Builder.add_band builder ~tree:0 band with
          | Error _ ->
              ()
          | Ok () ->
              raise_s [%message "tampered band accepted"] ) ;
      (* and the honest one still is *)
      Or_error.ok_exn (Builder.add_band builder ~tree:0 honest)

    let%test_unit "an unnamed payload is rejected" =
      let state = populated ~max_base_jobs:4 ~delay:1 ~blocks:20 in
      let manifest = Manifest.of_state state ~payload_digest in
      let builder =
        Or_error.ok_exn
          (Builder.create manifest ~expected:(hash state) ~band_height:2)
      in
      match
        Builder.add_payload builder ~digest_of_bytes:digest_of_bytes_base
          ~bytes:"123456789"
      with
      | Error _ ->
          ()
      | Ok () ->
          raise_s [%message "payload nothing names was accepted"]

    let%test_unit "finish refuses an incomplete state" =
      let state = populated ~max_base_jobs:4 ~delay:1 ~blocks:20 in
      let manifest = Manifest.of_state state ~payload_digest in
      let builder =
        Or_error.ok_exn
          (Builder.create manifest ~expected:(hash state) ~band_height:2)
      in
      match
        Builder.finish builder ~merge_of_bytes:Int.of_string
          ~base_of_bytes:Int.of_string
      with
      | Error _ ->
          ()
      | Ok _ ->
          raise_s [%message "finished with nothing received"]
  end )
