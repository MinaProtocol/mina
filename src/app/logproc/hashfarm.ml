open Core

let all_pairs (xs : 'a list) (ys : 'b list) : ('a * 'b) list =
  List.bind ~f:(fun x -> List.map ~f:(fun y -> (x, y)) ys) xs

let all_names =
  lazy
    ( all_pairs Hashfarm_wordlists.adjectives
        (all_pairs Hashfarm_wordlists.colors Hashfarm_wordlists.animals)
    |> Array.of_list
    |> Array.map ~f:(fun (a, (b, c)) -> a ^ " " ^ b ^ " " ^ c) )

let used_names : (string, string) Hashtbl.t = Hashtbl.create (module String)

let select_name x =
  let all_names = force all_names in
  let name_for_hash =
    all_names.((String.hash x :> int) % Array.length all_names)
  in
  match Hashtbl.find used_names name_for_hash with
  | Some preimage ->
      if not (String.equal preimage x) then (
        eprintf "FATAL:hashfarm collision\n" ;
        exit 1 )
      else name_for_hash
  | None ->
      Hashtbl.add_exn used_names ~key:name_for_hash ~data:x ;
      name_for_hash

let rec map_data_hashes (sm : Yojson.Safe.json) ~f : Yojson.Safe.json =
  let map_data_hashes = map_data_hashes ~f in
  match sm with
  | `Null | `Bool _ | `Int _ | `Intlit _ | `Float _ | `String _ -> sm
  | `Assoc [("logproc_interp", `String "data_hash"); ("value", `String hash)]
   |`Assoc [("value", `String hash); ("logproc_interp", `String "data_hash")]
    ->
      `String (f hash)
  | `Assoc l -> `Assoc (List.map ~f:(fun (k, v) -> (k, map_data_hashes v)) l)
  | `List l -> `List (List.map ~f:map_data_hashes l)
  | `Tuple l -> `Tuple (List.map ~f:map_data_hashes l)
  | `Variant (map, maybe_json) ->
      `Variant (map, Option.map ~f:map_data_hashes maybe_json)

let fix_data_hashes = map_data_hashes ~f:Fn.id

let translate_json = map_data_hashes ~f:select_name

let translate_msg (msg : Logger.Message.t) =
  { msg with
    metadata= String.Map.map ~f:(map_data_hashes ~f:select_name) msg.metadata
  }
