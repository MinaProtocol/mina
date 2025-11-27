open Async_kernel
open Core
open Mina_base
open Mina_block
open Frontier_base

(* TODO: cache state body hashes in db to avoid re-hashing on load (#10293) *)

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
open Result.Let_syntax

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

  module Transition = struct
    [%%versioned
    module Stable = struct
      [@@@no_toplevel_latest_type]

      module V3 = struct
        type t =
          | Old_format of Mina_block.Stable.V2.t
          | New_format of Block_data.Full.Stable.V1.t

        let to_latest = Fn.id
      end

      module V2 = struct
        type t = Mina_block.Stable.V2.t =
          { header : Header.Stable.V2.t
          ; body : Staged_ledger_diff.Body.Stable.V1.t
          }

        let to_latest : t -> V3.t = fun block -> Old_format block
      end
    end]

    let header = function
      | Stable.Latest.Old_format block ->
          Mina_block.Stable.V2.header block
      | New_format { header; _ } ->
          header

    let to_validated_block ~signature_kind ~proof_cache_db ~state_hash =
      function
      | Stable.Latest.Old_format transition ->
          Result.return
          @@ Block_data.validated_of_stable ~signature_kind ~proof_cache_db
               ~state_hash transition
      | New_format transition ->
          Block_data.Full.to_validated_block ~signature_kind ~proof_cache_db
            ~state_hash transition
  end

  type _ t =
    | Db_version : int t
    | Transition : State_hash.Stable.V1.t -> Transition.Stable.V3.t t
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
    | Root : Root_data.Minimal.Stable.V3.t t
    | Root_hash : State_hash.Stable.V1.t t
    | Root_common : Root_data.Common.Stable.V3.t t
    | Best_tip : State_hash.Stable.V1.t t
    | Protocol_states_for_root_scan_state
        : Mina_state.Protocol_state.Value.Stable.V2.t list t

  [@@@warning "+22"]

  let to_string : type a. a t -> string = function
    | Db_version ->
        "Db_version"
    | Transition _ ->
        "Transition _"
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
        [%bin_type_class: Transition.Stable.Latest.t]
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
  match get_batch t.db ~keys:[ Some_key Root_hash; Some_key Root_common ] with
  | [ Some (Some_key_value (Root_hash, hash))
    ; Some (Some_key_value (Root_common, common))
    ] ->
      Ok (Root_data.Minimal.of_common common ~state_hash:hash)
  | _ -> (
      match get t.db ~key:Root ~error:(`Not_found `Root) with
      | Ok root ->
          (* automatically split Root into (Root_hash, Root_common) *)
          Batch.with_batch t.db ~f:(fun batch ->
              let hash = Root_data.Minimal.state_hash root in
              let common = Root_data.Minimal.common root in
              Batch.remove batch ~key:Root ;
              Batch.set batch ~key:Root_hash ~data:hash ;
              Batch.set batch ~key:Root_common ~data:common ) ;

          Ok root
      | Error _ as e ->
          e )

let get_root_hash t =
  match get t.db ~key:Root_hash ~error:(`Not_found `Root_hash) with
  | Ok hash ->
      Ok hash
  | Error _ ->
      Result.map ~f:Root_data.Minimal.state_hash (get_root t)

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
        let%bind root_hash =
          Result.map_error (get_root_hash t) ~f:(fun e -> `Corrupt e)
        in
        let%bind best_tip =
          get t.db ~key:Best_tip ~error:(`Corrupt (`Not_found `Best_tip))
        in
        let%bind root_transition =
          get t.db ~key:(Transition root_hash)
            ~error:(`Corrupt (`Not_found `Root_transition))
        in
        let%bind _ =
          get t.db ~key:Protocol_states_for_root_scan_state
            ~error:(`Corrupt (`Not_found `Protocol_states_for_root_scan_state))
        in
        let%map _ =
          get t.db ~key:(Transition best_tip)
            ~error:(`Corrupt (`Not_found `Best_tip_transition))
        in
        (root_hash, root_transition)
      in
      let rec check_arcs pred_hash =
        let%bind successors =
          get t.db ~key:(Arcs pred_hash)
            ~error:(`Corrupt (`Not_found (`Arcs pred_hash)))
        in
        List.fold successors ~init:(Ok ()) ~f:(fun acc succ_hash ->
            let%bind () = acc in
            let%bind _ =
              get t.db ~key:(Transition succ_hash)
                ~error:(`Corrupt (`Not_found (`Transition succ_hash)))
            in
            check_arcs succ_hash )
      in
      let%bind () = check_version () in
      let%bind root_hash, root_block = check_base () in
      let root_protocol_state =
        Transition.header root_block |> Mina_block.Header.protocol_state
      in
      let%bind () =
        let persisted_genesis_state_hash =
          Mina_state.Protocol_state.genesis_state_hash root_protocol_state
        in
        if State_hash.equal persisted_genesis_state_hash genesis_state_hash then
          Ok ()
        else Error (`Genesis_state_mismatch persisted_genesis_state_hash)
      in
      let%map () = check_arcs root_hash in
      Transition.header root_block
      |> Mina_block.Header.protocol_state
      |> Mina_state.Protocol_state.blockchain_state
      |> Mina_state.Blockchain_state.snarked_ledger_hash )
  |> Result.map_error ~f:(fun err -> `Corrupt (`Raised err))
  |> Result.join

let initialize t ~root_data =
  let root_state_hash = root_data.Root_data.state_hash in
  let root_common = Root_data.to_common root_data in
  [%log' trace t.logger]
    ~metadata:[ ("root_data", State_hash.to_yojson root_state_hash) ]
    "Initializing persistent frontier database with $root_data" ;
  Batch.with_batch t.db ~f:(fun batch ->
      Batch.set batch ~key:Db_version ~data:version ;
      Batch.set batch ~key:(Arcs root_state_hash) ~data:[] ;
      Batch.set batch ~key:Root_hash ~data:root_state_hash ;
      Batch.set batch ~key:Root_common ~data:root_common ;
      Batch.set batch ~key:Best_tip ~data:root_state_hash ;
      Batch.set batch ~key:Protocol_states_for_root_scan_state
        ~data:
          ( root_data.protocol_states_for_scan_state
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

let set_transition ~state_hash ~transition_data =
  Batch.set ~key:(Transition state_hash) ~data:(New_format transition_data)

let add ~arcs_cache ~state_hash ~transition_data =
  let parent_hash =
    transition_data.Block_data.Full.Stable.Latest.header
    |> Header.protocol_state |> Mina_state.Protocol_state.previous_state_hash
  in
  let parent_arcs = State_hash.Table.find_exn arcs_cache parent_hash in
  State_hash.Table.set arcs_cache ~key:parent_hash
    ~data:(state_hash :: parent_arcs) ;
  State_hash.Table.set arcs_cache ~key:state_hash ~data:[] ;
  fun batch ->
    set_transition batch ~state_hash ~transition_data ;
    Batch.set batch ~key:(Arcs state_hash) ~data:[] ;
    Batch.set batch ~key:(Arcs parent_hash) ~data:(state_hash :: parent_arcs)

let move_root ~old_root_hash ~new_root ~garbage =
  let new_root_hash = new_root.Root_data.state_hash in
  fun batch ->
    Batch.remove batch ~key:Root ;
    Batch.set batch ~key:Root_hash ~data:new_root_hash ;
    Batch.set batch ~key:Root_common ~data:(Root_data.to_common new_root) ;
    Batch.set batch ~key:Protocol_states_for_root_scan_state
      ~data:(List.map ~f:With_hash.data new_root.protocol_states_for_scan_state) ;
    List.iter (old_root_hash :: garbage) ~f:(fun node_hash ->
        (* because we are removing entire forks of the tree, there is
         * no need to have extra logic to any remove arcs to the node
         * we are deleting since there we are deleting all of a node's
         * parents as well
         *)
        Batch.remove batch ~key:(Transition node_hash) ;
        Batch.remove batch ~key:(Arcs node_hash) )

let get_transition_data ~signature_kind ~proof_cache_db t hash =
  let error = `Not_found (`Transition hash) in
  match%map.Result get t.db ~key:(Transition hash) ~error with
  | Old_format block ->
      Either.First
        (Block_data.validated_of_stable ~signature_kind ~proof_cache_db
           ~state_hash:hash block )
  | New_format transition ->
      Either.Second transition

let get_transition ~signature_kind ~proof_cache_db t hash =
  (* TODO: consider using a more specific error *)
  let error = `Not_found (`Transition hash) in
  let%bind.Result transition_data = get t.db ~key:(Transition hash) ~error in
  Transition.to_validated_block ~signature_kind ~proof_cache_db ~state_hash:hash
    transition_data
  |> Result.map_error ~f:(fun _ -> error)

let get_arcs t hash = get t.db ~key:(Arcs hash) ~error:(`Not_found (`Arcs hash))

let get_protocol_states_for_root_scan_state t =
  get t.db ~key:Protocol_states_for_root_scan_state
    ~error:(`Not_found `Protocol_states_for_root_scan_state)

let get_best_tip t = get t.db ~key:Best_tip ~error:(`Not_found `Best_tip)

let set_best_tip data = Batch.set ~key:Best_tip ~data

let rec crawl_successors ?max_depth ~signature_kind ~proof_cache_db ~init ~f t
    hash =
  let open Deferred.Result.Let_syntax in
  match max_depth with
  | Some 0 ->
      (* Depth limit reached, stop crawling *)
      Deferred.Result.return ()
  | _ ->
      let remaining_depth = Option.map max_depth ~f:(fun d -> d - 1) in
      let%bind successors = Deferred.return (get_arcs t hash) in
      deferred_list_result_iter successors ~f:(fun succ_hash ->
          let%bind transition =
            Deferred.return
              (get_transition_data ~signature_kind ~proof_cache_db t succ_hash)
          in
          let%bind init' =
            Deferred.map
              (f ~state_hash:succ_hash init transition)
              ~f:(Result.map_error ~f:(fun err -> `Crawl_error err))
          in
          crawl_successors ~signature_kind ~proof_cache_db
            ?max_depth:remaining_depth t succ_hash ~init:init' ~f )

let with_batch t = Batch.with_batch t.db
