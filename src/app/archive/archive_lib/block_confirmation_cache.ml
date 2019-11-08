open Core
open Coda_base

type key = State_hash.t

type block_data = {block_height: int; parent: State_hash.t option}
[@@deriving fields, sexp]

type t = (key, block_data) Hashtbl.t

let create list =
  List.map list ~f:(fun (state_hash, {block_height; parent}) ->
      (state_hash, {block_height; parent}) )
  |> State_hash.Table.of_alist_exn

let rec get_new_entries_to_root t state_hash new_block_height =
  let open Option.Let_syntax in
  match State_hash.Table.find t state_hash with
  | None ->
      let new_value = {block_height= new_block_height; parent= None} in
      [(state_hash, new_value)]
  | Some {block_height; parent= parent_opt} ->
      let new_entry =
        { block_height= Int.max block_height new_block_height
        ; parent= parent_opt }
      in
      if new_block_height >= block_height then
        let subquery =
          Option.value ~default:[]
            (let%map parent = parent_opt in
             get_new_entries_to_root t parent (new_block_height + 1))
        in
        (state_hash, new_entry) :: subquery
      else [(state_hash, new_entry)]

let get_updates t (parent_state_hash, state_hash) block_height =
  let new_entry = {block_height; parent= Some parent_state_hash} in
  let ancestor_entries =
    get_new_entries_to_root t parent_state_hash (block_height + 1)
  in
  (state_hash, new_entry) :: ancestor_entries

let update t (state_hash, `Parent parent_state_hash) block_height =
  let new_updates =
    get_updates t (parent_state_hash, state_hash) block_height
  in
  List.iter new_updates ~f:(fun (key, data) ->
      State_hash.Table.set t ~key ~data ) ;
  new_updates
