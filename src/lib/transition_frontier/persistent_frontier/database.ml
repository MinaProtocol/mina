open Async_kernel
open Core
open Mina_base
open Frontier_base

(* TODO: bundle together with other writes by sharing batch requests between
 * function calls in this module (#3738) *)

let rec deferred_list_result_iter ls ~f =
  let open Deferred.Result.Let_syntax in
  match ls with
  | [] ->
      return ()
  | h :: t ->
      let%bind () = f h in
      deferred_list_result_iter t ~f

(* TODO: should debug assert garbage checks be added? *)
(* TODO: implement versions with module versioning. For
 * now, this is just stubbed so we can add db migrations
 * later. (#3736) *)
let version = 2

module Schema = struct
  module Keys = struct
    module String = String

    module Prefixed_state_hash = struct
      [%%versioned
      module Stable = struct
        [@@@no_toplevel_latest_type]

        module V1 = struct
          type t =
            Mina_stdlib.Bounded_types.String.Stable.V1.t
            * State_hash.Stable.V1.t

          let to_latest = Fn.id
        end
      end]
    end
  end

  [@@@warning "-22"]

  type _ t =
    | Db_version : int t
    | Transition : State_hash.Stable.V1.t -> Mina_block.Stable.V2.t t
    | Transition_extended :
        State_hash.Stable.V1.t
        -> Extended_block.Stable.V1.t t
    | Arcs : State_hash.Stable.V1.t -> State_hash.Stable.V1.t list t
    (* TODO:
       In hard forks, `Root` should be replaced by `(Root_hash, Root_common)`;
       For now, we try to replace `Root` with `(Root_hash, Root_common)` when:
         1. initializing a new DB.
         2. trying to moving the root.
         3. trying to query `root` or `root_hash`.
       The reason for this is `Root_common` is too big(250MB+);
       Most of the time, we just need the hash, but whole `Root` is being read;
       This combos with `bin_prot` being slow results in 90s bottleneck.
    *)
    | Root : Root_data.Minimal.Stable.V2.t t
    | Root_hash : State_hash.Stable.V1.t t
    | Root_common : Root_data.Common.Stable.V2.t t
    | Best_tip : State_hash.Stable.V1.t t
    | Protocol_states_for_root_scan_state
        : Mina_state.Protocol_state.Value.Stable.V2.t list t

  [@@@warning "+22"]

  let to_string : type a. a t -> string = function
    | Db_version ->
        "Db_version"
    | Transition _ ->
        "Transition _"
    | Transition_extended _ ->
        "Transition_extended _"
    | Arcs _ ->
        "Arcs _"
    | Root ->
        "Root"
    | Root_hash ->
        "Root_hash"
    | Root_common ->
        "Root_common"
    | Best_tip ->
        "Best_tip"
    | Protocol_states_for_root_scan_state ->
        "Protocol_states_for_root_scan_state"

  let binable_data_type (type a) : a t -> a Bin_prot.Type_class.t = function
    | Db_version ->
        [%bin_type_class: int]
    | Transition _ ->
        [%bin_type_class: Mina_block.Stable.Latest.t]
    | Transition_extended _ ->
        [%bin_type_class: Extended_block.Stable.Latest.t]
    | Arcs _ ->
        [%bin_type_class: State_hash.Stable.Latest.t list]
    | Root ->
        [%bin_type_class: Root_data.Minimal.Stable.Latest.t]
    | Root_hash ->
        [%bin_type_class: State_hash.Stable.Latest.t]
    | Root_common ->
        [%bin_type_class: Root_data.Common.Stable.Latest.t]
    | Best_tip ->
        [%bin_type_class: State_hash.Stable.Latest.t]
    | Protocol_states_for_root_scan_state ->
        [%bin_type_class: Mina_state.Protocol_state.Value.Stable.Latest.t list]

  (* HACK: a simple way to derive Bin_prot.Type_class.t for each case of a GADT *)
  let gadt_input_type_class (type data a) :
         (module Binable.S with type t = data)
      -> to_gadt:(data -> a t)
      -> of_gadt:(a t -> data)
      -> a t Bin_prot.Type_class.t =
   fun (module M) ~to_gadt ~of_gadt ->
    let ({ shape; writer = { size; write }; reader = { read; vtag_read } }
          : data Bin_prot.Type_class.t ) =
      [%bin_type_class: M.t]
    in
    { shape
    ; writer =
        { size = Fn.compose size of_gadt
        ; write = (fun buffer ~pos gadt -> write buffer ~pos (of_gadt gadt))
        }
    ; reader =
        { read = (fun buffer ~pos_ref -> to_gadt (read buffer ~pos_ref))
        ; vtag_read =
            (fun buffer ~pos_ref number ->
              to_gadt (vtag_read buffer ~pos_ref number) )
        }
    }

  (* HACK: The OCaml compiler thought the pattern matching in of_gadts was
     non-exhaustive. However, it should not be since I constrained the
     polymorphic type *)
  let[@warning "-8"] binable_key_type (type a) :
      a t -> a t Bin_prot.Type_class.t = function
    | Db_version ->
        gadt_input_type_class
          (module Keys.String)
          ~to_gadt:(fun _ -> Db_version)
          ~of_gadt:(fun Db_version -> "db_version")
    | Transition _ ->
        gadt_input_type_class
          (module Keys.Prefixed_state_hash.Stable.Latest)
          ~to_gadt:(fun (_, hash) -> Transition hash)
          ~of_gadt:(fun (Transition hash) -> ("transition", hash))
    | Arcs _ ->
        gadt_input_type_class
          (module Keys.Prefixed_state_hash.Stable.Latest)
          ~to_gadt:(fun (_, hash) -> Arcs hash)
          ~of_gadt:(fun (Arcs hash) -> ("arcs", hash))
    | Root ->
        gadt_input_type_class
          (module Keys.String)
          ~to_gadt:(fun _ -> Root)
          ~of_gadt:(fun Root -> "root")
    | Root_hash ->
        gadt_input_type_class
          (module Keys.String)
          ~to_gadt:(fun _ -> Root_hash)
          ~of_gadt:(fun Root_hash -> "root_hash")
    | Root_common ->
        gadt_input_type_class
          (module Keys.String)
          ~to_gadt:(fun _ -> Root_common)
          ~of_gadt:(fun Root_common -> "root_common")
    | Best_tip ->
        gadt_input_type_class
          (module Keys.String)
          ~to_gadt:(fun _ -> Best_tip)
          ~of_gadt:(fun Best_tip -> "best_tip")
    | Protocol_states_for_root_scan_state ->
        gadt_input_type_class
          (module Keys.String)
          ~to_gadt:(fun _ -> Protocol_states_for_root_scan_state)
          ~of_gadt:(fun Protocol_states_for_root_scan_state ->
            "protocol_states_in_root_scan_state" )
    | Transition_extended _ ->
        gadt_input_type_class
          (module Keys.Prefixed_state_hash.Stable.Latest)
          ~to_gadt:(fun (_, hash) -> Transition_extended hash)
          ~of_gadt:(fun (Transition_extended hash) ->
            ("transition_extended", hash) )
end

module Error = struct
  type not_found_member =
    [ `Root
    | `Root_hash
    | `Root_common
    | `Best_tip
    | `Frontier_hash
    | `Root_transition
    | `Best_tip_transition
    | `Parent_transition of State_hash.t
    | `New_root_transition
    | `Old_root_transition
    | `Transition of State_hash.t
    | `Arcs of State_hash.t
    | `Protocol_states_for_root_scan_state ]

  type not_found = [ `Not_found of not_found_member ]

  type raised = [ `Raised of Error.t ]

  type t = [ not_found | raised | `Invalid_version ]

  let not_found_message (`Not_found member) =
    let member_name, member_id =
      match member with
      | `Root ->
          ("root", None)
      | `Root_hash ->
          ("root hash", None)
      | `Root_common ->
          ("root common", None)
      | `Best_tip ->
          ("best tip", None)
      | `Frontier_hash ->
          ("frontier hash", None)
      | `Root_transition ->
          ("root transition", None)
      | `Best_tip_transition ->
          ("best tip transition", None)
      | `Parent_transition hash ->
          ("parent transition", Some hash)
      | `New_root_transition ->
          ("new root transition", None)
      | `Old_root_transition ->
          ("old root transition", None)
      | `Transition hash ->
          ("transition", Some hash)
      | `Arcs hash ->
          ("arcs", Some hash)
      | `Protocol_states_for_root_scan_state ->
          ("protocol states in root scan state", None)
    in
    let additional_context =
      Option.map member_id ~f:(fun id ->
          Printf.sprintf " (hash = %s)" (State_hash.raw_hash_bytes id) )
      |> Option.value ~default:""
    in
    Printf.sprintf "%s not found%s" member_name additional_context

  let message = function
    | `Invalid_version ->
        "invalid version"
    | `Not_found _ as err ->
        not_found_message err
    | `Raised err ->
        sprintf "Raised %s" (Error.to_string_hum err)
end

module Rocks = Rocksdb.Serializable.GADT.Make (Schema)

type t = { directory : string; logger : Logger.t; db : Rocks.t }

let create ~logger ~directory =
  if not (Result.is_ok (Unix.access directory [ `Exists ])) then
    Unix.mkdir ~perm:0o766 directory ;
  { directory; logger; db = Rocks.create directory }

let close t = Rocks.close t.db

open Schema
open Rocks

type batch_t = Batch.t

let get_if_exists db ~default ~key =
  match get db ~key with Some x -> x | None -> default

let get db ~key ~error =
  match get db ~key with Some x -> Ok x | None -> Error error

(**
Don't use this when possible. It cost ~90s while get_root_hash cost seconds.
*)
let get_root t =
  [%log' internal t.logger] "Get_root_get_batch_start" ;
  match get_batch t.db ~keys:[ Some_key Root_hash; Some_key Root_common ] with
  | [ Some (Some_key_value (Root_hash, hash))
    ; Some (Some_key_value (Root_common, common))
    ] ->
      [%log' internal t.logger] "Get_root_found_split_keys" ;
      [%log' internal t.logger] "Get_root_of_limited_start" ;
      let result = Ok (Root_data.Minimal.Stable.V2.of_limited ~common hash) in
      [%log' internal t.logger] "Get_root_of_limited_done" ;
      result
  | _ -> (
      [%log' internal t.logger] "Get_root_fallback_to_legacy_Root_key" ;
      match get t.db ~key:Root ~error:(`Not_found `Root) with
      | Ok root ->
          [%log' internal t.logger] "Get_root_legacy_read_done" ;
          (* automatically split Root into (Root_hash, Root_common) *)
          [%log' internal t.logger] "Get_root_split_batch_start" ;
          Batch.with_batch t.db ~f:(fun batch ->
              let hash = Root_data.Minimal.Stable.Latest.hash root in
              let common = Root_data.Minimal.Stable.V2.common root in
              Batch.remove batch ~key:Root ;
              Batch.set batch ~key:Root_hash ~data:hash ;
              Batch.set batch ~key:Root_common ~data:common ) ;
          [%log' internal t.logger] "Get_root_split_batch_done" ;
          Ok root
      | Error _ as e ->
          e )

let get_root_hash t =
  match get t.db ~key:Root_hash ~error:(`Not_found `Root_hash) with
  | Ok hash ->
      Ok hash
  | Error _ ->
      Result.map ~f:Root_data.Minimal.Stable.Latest.hash (get_root t)

let get_transition_do ~error db hash =
  let make_hashes state_body_hash =
    { State_hash.State_hashes.state_hash = hash; state_body_hash }
  in
  match get db ~key:(Transition_extended hash) ~error:() with
  | Ok { block; update_coinbase_stack_and_get_data_result; state_body_hash } ->
      Ok
        ( { With_hash.data = block; hash = make_hashes (Some state_body_hash) }
        , update_coinbase_stack_and_get_data_result )
  | Error _ ->
      let%map.Result block = get db ~key:(Transition hash) ~error in
      ({ With_hash.data = block; hash = make_hashes None }, None)

(* TODO: check that best tip is connected to root *)
(* TODO: check for garbage *)
let check t ~genesis_state_hash =
  Or_error.try_with (fun () ->
      let check_version () =
        match get_if_exists t.db ~key:Db_version ~default:0 with
        | 0 ->
            Error `Not_initialized
        | v when v = version ->
            Ok ()
        | _ ->
            Error `Invalid_version
      in
      (* checks the pointers, frontier hash, and checks pointer references *)
      let check_base () =
        let%bind.Result root_hash =
          Result.map_error (get_root_hash t) ~f:(fun e -> `Corrupt e)
        in
        let%bind.Result best_tip =
          get t.db ~key:Best_tip ~error:(`Corrupt (`Not_found `Best_tip))
        in
        let%bind.Result root_transition =
          get_transition_do
            ~error:(`Corrupt (`Not_found `Root_transition))
            t.db root_hash
        in
        let%bind.Result _ =
          get t.db ~key:Protocol_states_for_root_scan_state
            ~error:(`Corrupt (`Not_found `Protocol_states_for_root_scan_state))
        in
        let%map.Result _ =
          get_transition_do
            ~error:(`Corrupt (`Not_found `Best_tip_transition))
            t.db best_tip
        in
        (root_hash, root_transition)
      in
      let rec check_arcs pred_hash =
        let%bind.Result successors =
          get t.db ~key:(Arcs pred_hash)
            ~error:(`Corrupt (`Not_found (`Arcs pred_hash)))
        in
        List.fold successors ~init:(Ok ()) ~f:(fun acc succ_hash ->
            let%bind.Result () = acc in
            let%bind.Result _ =
              get_transition_do
                ~error:(`Corrupt (`Not_found (`Transition succ_hash)))
                t.db succ_hash
            in
            check_arcs succ_hash )
      in
      ignore check_arcs ;
      let%bind.Result () = check_version () in
      let%bind.Result _root_hash, (root_block, _) = check_base () in
      let root_protocol_state =
        With_hash.data root_block |> Mina_block.Stable.Latest.header
        |> Mina_block.Header.protocol_state
      in
      let%map.Result () =
        let persisted_genesis_state_hash =
          Mina_state.Protocol_state.genesis_state_hash root_protocol_state
        in
        if State_hash.equal persisted_genesis_state_hash genesis_state_hash then
          Ok ()
        else Error (`Genesis_state_mismatch persisted_genesis_state_hash)
      in
      (* let%map () = check_arcs root_hash in *)
      root_protocol_state |> Mina_state.Protocol_state.blockchain_state
      |> Mina_state.Blockchain_state.snarked_ledger_hash )
  |> Result.map_error ~f:(fun err -> `Corrupt (`Raised err))
  |> Result.join

let initialize t ~root_data =
  let root_transition = Root_data.Limited.transition root_data in
  let root_state_hash = Mina_block.Validated.state_hash root_transition in
  [%log' trace t.logger]
    ~metadata:[ ("root_data", Root_data.Limited.to_yojson root_data) ]
    "Initializing persistent frontier database with $root_data" ;
  Batch.with_batch t.db ~f:(fun batch ->
      Batch.set batch ~key:Db_version ~data:version ;
      Batch.set batch ~key:(Transition_extended root_state_hash)
        ~data:
          { block =
              Mina_block.Validated.forget root_transition
              |> With_hash.data |> Mina_block.read_all_proofs_from_disk
          ; update_coinbase_stack_and_get_data_result = None
          ; state_body_hash =
              Mina_block.Validated.state_body_hash root_transition
          } ;
      Batch.set batch ~key:(Arcs root_state_hash) ~data:[] ;
      Batch.set batch ~key:Root_hash ~data:root_state_hash ;
      Batch.set batch ~key:Root_common
        ~data:
          ( root_data |> Root_data.Limited.common
          |> Root_data.Common.read_all_proofs_from_disk ) ;
      Batch.set batch ~key:Best_tip ~data:root_state_hash ;
      Batch.set batch ~key:Protocol_states_for_root_scan_state
        ~data:
          ( Root_data.Limited.protocol_states root_data
          |> List.map ~f:With_hash.data ) )

let find_arcs_and_root t ~(arcs_cache : State_hash.t list State_hash.Table.t)
    ~parent_hashes =
  let f h = Rocks.Key.Some_key (Arcs h) in
  let root_hash = get_root_hash t in
  let arcs = get_batch t.db ~keys:(List.map parent_hashes ~f) in
  let populate res parent_hash arc_opt =
    let%bind.Result () = res in
    match arc_opt with
    | Some (Key.Some_key_value (Arcs _, (data : State_hash.t list))) ->
        State_hash.Table.set arcs_cache ~key:parent_hash ~data ;
        Result.return ()
    | _ ->
        Error (`Not_found (`Arcs parent_hash))
  in
  match root_hash with
  | Ok hash ->
      let%map.Result () =
        List.fold2_exn ~init:(Result.return ()) ~f:populate parent_hashes arcs
      in
      hash
  | _ ->
      Error (`Not_found `Old_root_transition)

let set_transition ~update_coinbase_stack_and_get_data_result ~transition =
  let state_body_hash = Mina_block.Validated.state_body_hash transition in
  let hash = Mina_block.Validated.state_hash transition in
  let transition_unwrapped =
    Mina_block.Validated.forget transition
    |> With_hash.data |> Mina_block.read_all_proofs_from_disk
  in
  fun batch ->
    Batch.set batch ~key:(Transition_extended hash)
      ~data:
        { block = transition_unwrapped
        ; update_coinbase_stack_and_get_data_result =
            Option.map update_coinbase_stack_and_get_data_result
              ~f:
                Staged_ledger.Update_coinbase_stack_and_get_data_result
                .read_all_proofs_from_disk
        ; state_body_hash
        }

let add ~update_coinbase_stack_and_get_data_result ~arcs_cache ~transition =
  let hash = Mina_block.Validated.state_hash transition in
  let parent_hash =
    Mina_block.Validated.header transition
    |> Mina_block.Header.protocol_state
    |> Mina_state.Protocol_state.previous_state_hash
  in
  let parent_arcs = State_hash.Table.find_exn arcs_cache parent_hash in
  State_hash.Table.set arcs_cache ~key:parent_hash ~data:(hash :: parent_arcs) ;
  State_hash.Table.set arcs_cache ~key:hash ~data:[] ;
  fun batch ->
    set_transition ~update_coinbase_stack_and_get_data_result ~transition batch ;
    Batch.set batch ~key:(Arcs hash) ~data:[] ;
    Batch.set batch ~key:(Arcs parent_hash) ~data:(hash :: parent_arcs)

let move_root ~old_root_hash ~new_root ~garbage =
  let new_root_hash =
    (Root_data.Limited.Stable.Latest.hashes new_root).state_hash
  in
  fun batch ->
    Batch.remove batch ~key:Root ;
    Batch.set batch ~key:Root_hash ~data:new_root_hash ;
    Batch.set batch ~key:Root_common
      ~data:(Root_data.Limited.Stable.Latest.common new_root) ;
    Batch.set batch ~key:Protocol_states_for_root_scan_state
      ~data:
        (List.map ~f:With_hash.data
           (Root_data.Limited.Stable.Latest.protocol_states new_root) ) ;
    List.iter (old_root_hash :: garbage) ~f:(fun node_hash ->
        (* because we are removing entire forks of the tree, there is
         * no need to have extra logic to any remove arcs to the node
         * we are deleting since there we are deleting all of a node's
         * parents as well
         *)
        Batch.remove batch ~key:(Transition_extended node_hash) ;
        (* according to rocksdb docs, operation does nothing if
         * the key does not exist *)
        Batch.remove batch ~key:(Transition node_hash) ;
        Batch.remove batch ~key:(Arcs node_hash) )

type get_transition_result =
  { block : Mina_block.Validated.t
  ; update_coinbase_stack_and_get_data_result :
      Staged_ledger.Update_coinbase_stack_and_get_data_result.Stable.Latest.t
      option
  }

let get_transition ~logger ~signature_kind ~proof_cache_db t hash =
  [%log internal] "Database_get_transition_start"
    ~metadata:[ ("state_hash", State_hash.to_yojson hash) ] ;
  let%map.Result block, update_coinbase_stack_and_get_data_result =
    get_transition_do t.db hash ~error:(`Not_found (`Transition hash))
  in
  [%log internal] "Database_read_from_rocksdb_done"
    ~metadata:[ ("state_hash", State_hash.to_yojson hash) ] ;
  let parent_hash =
    block |> With_hash.data |> Mina_block.Stable.Latest.header
    |> Mina_block.Header.protocol_state
    |> Mina_state.Protocol_state.previous_state_hash
  in
  [%log internal] "Database_write_proofs_to_disk_start"
    ~metadata:[ ("state_hash", State_hash.to_yojson hash) ] ;
  let cached_block =
    With_hash.map
      ~f:(Mina_block.write_all_proofs_to_disk ~signature_kind ~proof_cache_db)
      block
  in
  [%log internal] "Database_write_proofs_to_disk_done"
    ~metadata:[ ("state_hash", State_hash.to_yojson hash) ] ;
  (* TODO: the delta transition chain proof is incorrect (same behavior the daemon used to have, but we should probably fix this?) *)
  let result =
    Mina_block.Validated.unsafe_of_trusted_block
      ~delta_block_chain_proof:(Mina_stdlib.Nonempty_list.singleton parent_hash)
      (`This_block_is_trusted_to_be_safe cached_block)
  in
  [%log internal] "Database_get_transition_done"
    ~metadata:[ ("state_hash", State_hash.to_yojson hash) ] ;
  { block = result; update_coinbase_stack_and_get_data_result }

let get_arcs t hash = get t.db ~key:(Arcs hash) ~error:(`Not_found (`Arcs hash))

let get_protocol_states_for_root_scan_state t =
  [%log' internal t.logger] "Get_protocol_states_start" ;
  let result =
    get t.db ~key:Protocol_states_for_root_scan_state
      ~error:(`Not_found `Protocol_states_for_root_scan_state)
  in
  [%log' internal t.logger] "Get_protocol_states_done" ;
  result

let get_best_tip t =
  [%log' internal t.logger] "Get_best_tip_start" ;
  let result = get t.db ~key:Best_tip ~error:(`Not_found `Best_tip) in
  [%log' internal t.logger] "Get_best_tip_done" ;
  result

let set_best_tip data = Batch.set ~key:Best_tip ~data

let rec crawl_successors ~logger ~signature_kind ~proof_cache_db ?max_depth t
    hash ~init ~f =
  let open Deferred.Result.Let_syntax in
  match max_depth with
  | Some 0 ->
      (* Depth limit reached, stop crawling *)
      [%log internal] "Crawl_depth_limit_reached" ;
      Deferred.Result.return ()
  | _ ->
      let remaining_depth = Option.map max_depth ~f:(fun d -> d - 1) in
      [%log internal] "Crawl_get_arcs_start"
        ~metadata:
          [ ("state_hash", State_hash.to_yojson hash)
          ; ( "remaining_depth"
            , `Int (Option.value remaining_depth ~default:(-1)) )
          ] ;
      let%bind successors = Deferred.return (get_arcs t hash) in
      [%log internal] "Crawl_get_arcs_done"
        ~metadata:
          [ ("state_hash", State_hash.to_yojson hash)
          ; ("successor_count", `Int (List.length successors))
          ] ;
      deferred_list_result_iter successors ~f:(fun succ_hash ->
          [%log internal] "Crawl_process_successor_start"
            ~metadata:[ ("state_hash", State_hash.to_yojson succ_hash) ] ;
          let%bind { block; update_coinbase_stack_and_get_data_result } =
            Deferred.return
              (get_transition ~logger ~signature_kind ~proof_cache_db t
                 succ_hash )
          in
          [%log internal] "Crawl_apply_diff_start"
            ~metadata:[ ("state_hash", State_hash.to_yojson succ_hash) ] ;
          let%bind init' =
            Deferred.map
              (f ?update_coinbase_stack_and_get_data_result ~acc:init block)
              ~f:(Result.map_error ~f:(fun err -> `Crawl_error err))
          in
          [%log internal] "Crawl_apply_diff_done"
            ~metadata:[ ("state_hash", State_hash.to_yojson succ_hash) ] ;
          crawl_successors ~logger ~signature_kind ~proof_cache_db
            ?max_depth:remaining_depth t succ_hash ~init:init' ~f )

let with_batch t = Batch.with_batch t.db
