open Mina_base
open Core_kernel
module M = Consensus.Body_reference.Table

type t =
  { known : ([ `Invalid | `Regular ] * State_hash.Set.t) M.t
  ; removals : State_hash.Set.t M.t
  }

let create () = { known = M.create (); removals = M.create () }

(** Remove reference from body ref to state hash from [known_body_refs].
      
    Triggers body removal from block storage if there are no other transitions
    that refer to the same body in [known_body_refs].
    *)
let remove_reference { known; _ } ~logger ~block_storage body_ref state_hash =
  let body_status_opt =
    Lmdb_storage.Block.get_status ~logger block_storage body_ref
  in
  let need_removal =
    Option.is_some
    @@ let%bind.Option bref_status, shs = M.find known body_ref in
       let shs' = State_hash.Set.remove shs state_hash in
       if State_hash.Set.is_empty shs' then (
         M.remove known body_ref ;
         Option.ignore_m body_status_opt )
       else (
         M.set known ~key:body_ref ~data:(bref_status, shs') ;
         None )
  in
  ( `Body_present (Option.is_some body_status_opt)
  , `Removal_triggered need_removal )

let prune ({ removals; _ } as t) ~logger ~block_storage ~header_storage
    ?body_ref:body_ref_opt state_hash =
  let body_ref_opt =
    match body_ref_opt with
    | None -> (
        match%bind.Option Lmdb_storage.Header.get header_storage state_hash with
        | Invalid { body_ref; _ } ->
            body_ref
        | Header h ->
            Some (Mina_block.Header.body_reference h) )
    | x ->
        x
  in
  let sh_removals =
    let open Option in
    body_ref_opt >>= M.find removals
  in
  match (body_ref_opt, sh_removals) with
  | Some body_ref, Some shs ->
      M.set removals ~key:body_ref ~data:(State_hash.Set.add shs state_hash) ;
      `Removal_triggered None
  | Some body_ref, None ->
      let `Body_present _, `Removal_triggered removal_triggered =
        remove_reference t ~logger ~block_storage body_ref state_hash
      in
      if removal_triggered then
        M.set removals ~key:body_ref ~data:(State_hash.Set.singleton state_hash)
      else Lmdb_storage.Header.remove header_storage state_hash ;
      `Removal_triggered (Option.some_if removal_triggered body_ref)
  | _ ->
      Lmdb_storage.Header.remove header_storage state_hash ;
      `Removal_triggered None

let on_block_body_removed { removals; _ } ~header_storage ids =
  let remove_do = Lmdb_storage.Header.remove header_storage in
  let f =
    Fn.compose
      (Option.iter ~f:(State_hash.Set.iter ~f:remove_do))
      (M.find_and_remove removals)
  in
  List.iter ids ~f

let handle_broken ~logger ~mark_invalid { known; _ } body_ref =
  match M.find known body_ref with
  | None ->
      [%log warn]
        "Failed processing broken body $body_ref: block ref is unknown"
        ~metadata:[ ("body_ref", Consensus.Body_reference.to_yojson body_ref) ]
  | Some (`Invalid, _) ->
      [%log warn]
        "Received broken body update for $body_ref was already invalid"
        ~metadata:[ ("body_ref", Consensus.Body_reference.to_yojson body_ref) ]
  | Some (`Regular, state_hashes) ->
      M.set known ~key:body_ref ~data:(`Invalid, state_hashes) ;
      State_hash.Set.iter state_hashes ~f:mark_invalid

let state_hashes { known; _ } =
  Fn.compose
    (Option.map ~f:(Fn.compose State_hash.Set.to_list snd))
    (M.find known)

let add_new ?(no_log_on_invalid = false) ~logger { known; _ } body_ref
    state_hash =
  M.update known body_ref ~f:(function
    | None ->
        (`Regular, State_hash.Set.singleton state_hash)
    | Some (`Invalid, shs) ->
        if not no_log_on_invalid then
          [%log error]
            "Adding new transition $state_hash referring to body reference \
             $body_ref that is invalid"
            ~metadata:
              [ ("state_hash", State_hash.to_yojson state_hash)
              ; ("body_ref", Consensus.Body_reference.to_yojson body_ref)
              ] ;
        (`Invalid, State_hash.Set.add shs state_hash)
    | Some (`Regular, shs) ->
        (`Regular, State_hash.Set.add shs state_hash) )
