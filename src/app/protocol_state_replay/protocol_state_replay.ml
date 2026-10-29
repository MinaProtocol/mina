(** Replay [Mina_block.Validation.check_protocol_state] over precomputed
    blocks, and mutation-test it.

    Every block in the input directory whose parent is also present is
    checked against that parent. Offline there is no staged ledger, so the
    staged ledger hash and the emitted ledger proof's statement are taken
    from the block; everything else is derived as in the daemon.

    For a sample of blocks, each leaf of the protocol state's JSON is
    perturbed in turn and the check is rerun, recording which mutations it
    rejects. *)

open Core
open Mina_base
open Mina_state

let logger = Logger.null ()

(* Only what the replay needs is kept, so that thousands of blocks fit in
   memory; the JSON is re-read for the blocks that are mutation-tested. *)
type block =
  { path : string
  ; protocol_state : Protocol_state.Value.t
  ; state_hash : State_hash.t
  ; body_reference : Consensus.Body_reference.t
  ; epoch_count : int
  ; in_seed_update_range : bool
  }

let read_json path = Yojson.Safe.from_file path

let parse_latest json =
  Result.bind (Mina_block.Precomputed.Versioned.of_yojson json) ~f:(fun v ->
      Result.of_option ~error:"not the latest version"
        (Option.map (Mina_block.Precomputed.Versioned.latest v) ~f:(fun p ->
             (v, p) ) ) )

let constraint_constants =
  lazy
    (let (module G) = Genesis_constants.profiled () in
     G.constraint_constants )

let ledger_proof_statement ~parent ~child =
  let stmt s =
    Blockchain_state.ledger_proof_statement (Protocol_state.blockchain_state s)
  in
  let child_stmt = stmt child in
  if Snarked_ledger_state.equal (stmt parent) child_stmt then None
  else Some child_stmt

(* The protocol state mutations leave the body alone, so the body reference
   is computed once per block; the daemon has it already computed by the time
   it runs the check. *)
let check ~(parent : block) ~(child : block) ~ledger_proof_statement
    (child_state : Protocol_state.Value.t) =
  Mina_block.Validation.check_protocol_state ~logger
    ~constraint_constants:(Lazy.force constraint_constants)
    ~parent_protocol_state:parent.protocol_state
    ~parent_state_hash:parent.state_hash ~ledger_proof_statement
    ~staged_ledger_hash:
      (Blockchain_state.staged_ledger_hash
         (Protocol_state.blockchain_state child_state) )
    ~body_reference:child.body_reference child_state

(* Leaves of a JSON value, with their paths. *)
let rec leaves ~path (json : Yojson.Safe.t) =
  match json with
  | `Assoc xs ->
      List.concat_map xs ~f:(fun (k, v) -> leaves ~path:(path @ [ `K k ]) v)
  | `List xs ->
      List.concat_mapi xs ~f:(fun i v -> leaves ~path:(path @ [ `I i ]) v)
  | leaf ->
      [ (path, leaf) ]

let rec get (json : Yojson.Safe.t) path =
  match (path, json) with
  | [], _ ->
      Some json
  | `K k :: rest, `Assoc xs ->
      Option.bind (List.Assoc.find xs ~equal:String.equal k) ~f:(fun v ->
          get v rest )
  | `I i :: rest, `List xs ->
      Option.bind (List.nth xs i) ~f:(fun v -> get v rest)
  | _ ->
      None

let rec set (json : Yojson.Safe.t) path v : Yojson.Safe.t =
  match (path, json) with
  | [], _ ->
      v
  | `K k :: rest, `Assoc xs ->
      `Assoc
        (List.map xs ~f:(fun (k', x) ->
             if String.equal k k' then (k', set x rest v) else (k', x) ) )
  | `I i :: rest, `List xs ->
      `List (List.mapi xs ~f:(fun j x -> if i = j then set x rest v else x))
  | _ ->
      failwith "set: bad path"

let path_to_string path =
  String.concat (List.map path ~f:(function `K k -> "." ^ k | `I _ -> "[]"))

(* A different but well-formed value for a leaf: numbers are incremented,
   booleans flipped, and other strings (hashes, keys) replaced by the value
   at the same path in another block or, for fields that are constant along
   the chain, by another leaf of [state] with the same Base58 version prefix
   (so the same type). *)
let perturb ~others ~state ~path (leaf : Yojson.Safe.t) =
  match leaf with
  | `Bool b ->
      Some (`Bool (not b))
  | `String s -> (
      match
        Option.some_if
          ((not (String.is_empty s)) && String.for_all s ~f:Char.is_digit)
          s
        |> Option.bind ~f:(fun s ->
               Option.try_with (fun () -> Int64.of_string s) )
      with
      | Some n ->
          Some (`String (Int64.to_string (Int64.succ n)))
      | None -> (
          let differing = function
            | `String s' when not (String.equal s s') ->
                Some (`String s')
            | _ ->
                None
          in
          let same_type (_, v) =
            match v with
            | `String s' ->
                String.length s' = String.length s
                && String.equal (String.prefix s' 2) (String.prefix s 2)
            | _ ->
                false
          in
          match
            List.find_map others ~f:(fun other ->
                Option.bind (get other path) ~f:differing )
          with
          | Some v ->
              Some v
          | None ->
              List.find_map
                (List.filter (leaves ~path:[] state) ~f:same_type)
                ~f:(fun (_, v) -> differing v) ) )
  | `Int n ->
      Some (`Int (n + 1))
  | _ ->
      None

let consensus_field json name =
  get json
    [ `K "data"; `K "protocol_state"; `K "body"; `K "consensus_state"; name ]

let json_int = function
  | Some (`String s) ->
      Int.of_string s
  | _ ->
      failwith "expected a numeric string"

(* As [Consensus.Slot.in_seed_update_range]: the first two thirds of the
   epoch. *)
let in_seed_update_range json =
  let slot = consensus_field json (`K "curr_global_slot_since_hard_fork") in
  let field k = json_int (Option.bind slot ~f:(fun s -> get s [ `K k ])) in
  let slots_per_epoch = field "slots_per_epoch" in
  field "slot_number" % slots_per_epoch < slots_per_epoch / 3 * 2

let load_block path =
  let json = read_json path in
  match parse_latest json with
  | Error e ->
      Error (sprintf "%s: %s" path e)
  | Ok (versioned, precomputed) ->
      Ok
        { path
        ; protocol_state = precomputed.protocol_state
        ; state_hash =
            (Mina_block.Precomputed.Versioned.state_hashes versioned).state_hash
        ; body_reference =
            Staged_ledger_diff.Body.compute_reference
              ~tag:Mina_net2.Bitswap_tag.(to_enum Body)
              (Staged_ledger_diff.Body.Stable.Latest.create
                 precomputed.staged_ledger_diff )
        ; epoch_count = json_int (consensus_field json (`K "epoch_count"))
        ; in_seed_update_range = in_seed_update_range json
        }

let epoch_changed ~parent ~child = parent.epoch_count <> child.epoch_count

let percentile sorted p =
  let n = Array.length sorted in
  sorted.(Int.min (n - 1) (Float.iround_down_exn (p *. Float.of_int n)))

let main ~dir ~mutation_sample ~repeats () =
  let files =
    Stdlib.Sys.readdir dir |> Array.to_list
    |> List.filter ~f:(String.is_suffix ~suffix:".json")
    |> List.sort ~compare:String.compare
  in
  let loaded = List.map files ~f:(fun f -> load_block (dir ^/ f)) in
  let blocks = List.filter_map loaded ~f:Result.ok in
  let load_errors =
    List.filter_map loaded ~f:(function Error e -> Some e | Ok _ -> None)
  in
  printf "files %d, loaded %d, not loaded %d\n%!" (List.length files)
    (List.length blocks) (List.length load_errors) ;
  List.iteri load_errors ~f:(fun i e -> if i < 5 then printf "  %s\n" e) ;
  let by_hash = State_hash.Table.create () in
  List.iter blocks ~f:(fun b -> Hashtbl.set by_hash ~key:b.state_hash ~data:b) ;
  let pairs =
    List.filter_map blocks ~f:(fun child ->
        let parent_hash =
          Protocol_state.previous_state_hash child.protocol_state
        in
        Option.map (Hashtbl.find by_hash parent_hash) ~f:(fun parent ->
            (parent, child) ) )
  in
  printf "pairs with parent present %d\n%!" (List.length pairs) ;
  let n_ok = ref 0 in
  let failures = String.Table.create () in
  let epoch_changes = ref 0 in
  let in_seed_range = ref 0 in
  let proofs_emitted = ref 0 in
  let times = ref [] in
  List.iter pairs ~f:(fun (parent, child) ->
      if epoch_changed ~parent ~child then incr epoch_changes ;
      if child.in_seed_update_range then incr in_seed_range ;
      let ledger_proof_statement =
        ledger_proof_statement ~parent:parent.protocol_state
          ~child:child.protocol_state
      in
      if Option.is_some ledger_proof_statement then incr proofs_emitted ;
      let check = check ~parent ~child ~ledger_proof_statement in
      let result = check child.protocol_state in
      let samples =
        List.init repeats ~f:(fun _ ->
            let start = Time_ns.now () in
            ignore (check child.protocol_state : unit Or_error.t) ;
            Time_ns.Span.to_us (Time_ns.diff (Time_ns.now ()) start) )
        |> List.sort ~compare:Float.compare
      in
      times := List.nth_exn samples (repeats / 2) :: !times ;
      match result with
      | Ok () ->
          incr n_ok
      | Error e ->
          let key = Error.to_string_hum e in
          Hashtbl.update failures key ~f:(fun l ->
              State_hash.to_base58_check child.state_hash
              :: Option.value l ~default:[] ) ) ;
  printf
    "checked %d: ok %d, rejected %d (epoch changes %d, in seed update range \
     %d, ledger proof emitted %d)\n"
    (List.length pairs) !n_ok
    (List.length pairs - !n_ok)
    !epoch_changes !in_seed_range !proofs_emitted ;
  Hashtbl.iteri failures ~f:(fun ~key ~data ->
      printf "  %d x %s\n    e.g. %s\n" (List.length data) key
        (List.hd_exn data) ) ;
  ( match !times with
  | [] ->
      ()
  | ts ->
      let sorted = Array.of_list ts in
      Array.sort sorted ~compare:Float.compare ;
      printf
        "check time per block (median of %d runs each), us: min %.1f p50 %.1f \
         p90 %.1f p99 %.1f max %.1f\n"
        repeats sorted.(0) (percentile sorted 0.5) (percentile sorted 0.9)
        (percentile sorted 0.99)
        sorted.(Array.length sorted - 1) ) ;
  (* Mutation test, on evenly spaced pairs plus every epoch change. *)
  let n_pairs = List.length pairs in
  let step = Int.max 1 (n_pairs / Int.max 1 mutation_sample) in
  let sample =
    List.filteri pairs ~f:(fun i (parent, child) ->
        i % step = 0 || epoch_changed ~parent ~child )
  in
  let others =
    List.filter_mapi blocks ~f:(fun i b ->
        if i % 97 = 0 then
          get (read_json b.path) [ `K "data"; `K "protocol_state" ]
        else None )
  in
  let stats = String.Table.create () in
  List.iter sample ~f:(fun (parent, child) ->
      let child_json = read_json child.path in
      let state_path = [ `K "data"; `K "protocol_state" ] in
      let state_json = Option.value_exn (get child_json state_path) in
      List.iter (leaves ~path:[] state_json) ~f:(fun (path, leaf) ->
          match perturb ~others ~state:state_json ~path leaf with
          | None ->
              ()
          | Some v -> (
              let mutated = set child_json (state_path @ path) v in
              let key = path_to_string path in
              let record outcome =
                Hashtbl.update stats key ~f:(fun c ->
                    let r, a, u = Option.value c ~default:(0, 0, 0) in
                    match outcome with
                    | `Rejected ->
                        (r + 1, a, u)
                    | `Accepted ->
                        (r, a + 1, u)
                    | `Unparseable ->
                        (r, a, u + 1) )
              in
              match parse_latest mutated with
              | Error _ ->
                  record `Unparseable
              | Ok (_, precomputed) -> (
                  (* As the daemon: the emitted proof's statement is
                     independent of the block's claimed state. *)
                  let ledger_proof_statement =
                    ledger_proof_statement ~parent:parent.protocol_state
                      ~child:child.protocol_state
                  in
                  match
                    check ~parent ~child ~ledger_proof_statement
                      precomputed.protocol_state
                  with
                  | Ok () ->
                      record `Accepted
                  | Error _ ->
                      record `Rejected ) ) ) ) ;
  printf
    "\nmutation test over %d blocks: path, rejected, accepted, unparseable\n"
    (List.length sample) ;
  Hashtbl.to_alist stats
  |> List.sort ~compare:(fun (a, _) (b, _) -> String.compare a b)
  |> List.iter ~f:(fun (k, (r, a, u)) ->
         printf "  %-80s %5d %5d %5d%s\n" k r a u
           (if a > 0 then "  <- accepted" else "") )

let () =
  let dir = Sys.get_argv () |> Fn.flip Array.get 1 in
  let mutation_sample =
    Option.value_map (Sys.getenv "MUTATION_SAMPLE") ~default:40 ~f:Int.of_string
  in
  let repeats =
    Option.value_map (Sys.getenv "REPEATS") ~default:11 ~f:Int.of_string
  in
  main ~dir ~mutation_sample ~repeats ()
