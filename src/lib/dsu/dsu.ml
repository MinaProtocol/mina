open Core_kernel

let min_capacity = 64

let infinity_size = Int.max_value lsr 1

type resizing_opt = Double | Half

module type Data = sig
  type t

  val merge : t -> t -> t
end

(** DSU data structure with ability to remove sets fromt he structure.contents
    
    For more information on design and usage of the DSU, see:
    https://www.notion.so/minaprotocol/Bit-catchup-algorithm-8a3fa7a2630c46d98505b25ebb20c8e7#e364c78e09c74c03835bc7ed8634dc47

  Also Read:  https://cp-algorithms.com/data_structures/disjoint_set_union.html
*)
module Dsu (Key : Hashtbl.Key) (D : Data) = struct
  type element = { value : D.t option; parent : int; size : int }

  module KeyMap = Hashtbl.Make (Key)

  type t =
    { mutable arr : element array
    ; mutable next_id : int
    ; mutable key_to_id : int KeyMap.t
    }

  let init_array =
    Array.init ~f:(fun i ->
        { value = None
        ; parent = i
        ; size = (if i = 0 then infinity_size else 0)
        } )

  let create () =
    { arr = init_array min_capacity; next_id = 1; key_to_id = KeyMap.create () }

  let rec find_set ~id arr =
    let el = Array.get arr id in
    if id = el.parent then id
    else
      let parent = find_set ~id:el.parent arr in
      Array.set arr id { el with parent } ;
      parent

  let resize t = function
    | Double ->
        let dsu_size = Array.length t.arr in
        let reallocation_size = dsu_size * 2 in
        let new_arr = init_array reallocation_size in
        (* ocaml for loops are inclusive of the upper bound *)
        for i = 1 to dsu_size - 1 do
          Array.set new_arr i (Array.get t.arr i)
        done ;
        t.arr <- new_arr
    | Half ->
        (* remove all the 0 parents *)
        KeyMap.filter_inplace t.key_to_id ~f:(fun id ->
            let { parent; _ } = t.arr.(id) in
            parent <> 0 ) ;
        let dsu_size = Array.length t.arr in
        let new_key_to_id = KeyMap.create () in
        let reallocation_size = dsu_size / 2 in
        let new_arr = init_array reallocation_size in
        let parent_tbl = Hashtbl.create (module Int) in
        KeyMap.iteri t.key_to_id ~f:(fun ~key ~data ->
            let idx = KeyMap.length new_key_to_id + 1 in
            let element = Array.get t.arr data in
            Array.set new_arr idx element ;
            Hashtbl.set new_key_to_id ~key ~data:idx ;
            if element.size <> 0 then
              Hashtbl.set parent_tbl ~key:element.parent ~data:idx ) ;
        (* loop through all the new keys in the hash tbl and replace the old parents with the new parent indexes*)
        Hashtbl.iteri parent_tbl ~f:(fun ~key ~data ->
            let element = Array.get new_arr data in
            Array.set new_arr data
              { element with parent = Hashtbl.find_exn parent_tbl key } ) ;

        t.arr <- new_arr ;
        t.key_to_id <- new_key_to_id

  let allocate_id t =
    if t.next_id = Array.length t.arr then resize t Double ;
    let id = t.next_id in
    t.next_id <- id + 1 ;
    id

  let size ~id t = (Array.get t.arr id).size

  let union_sets t a b =
    let a = find_set t.arr ~id:a in
    let b = find_set t.arr ~id:b in
    let adopt_parent ~parent ~child =
      let child_el = Array.get t.arr child in
      let parent_el = Array.get t.arr parent in
      let child_set_size = child_el.size in
      Array.set t.arr child { child_el with parent; size = 0 } ;
      Array.set t.arr parent
        { parent_el with size = parent_el.size + child_set_size }
    in
    if a <> b then
      if size ~id:a t < size ~id:b t then adopt_parent ~parent:b ~child:a
      else adopt_parent ~parent:a ~child:b

  let add_exn ~key ~value t =
    let id = allocate_id t in
    Hashtbl.add_exn ~key ~data:id t.key_to_id ;
    Array.set t.arr id { value = Some value; parent = id; size = 1 }

  let remove ~key t =
    Option.iter (Hashtbl.find_and_remove t.key_to_id key) ~f:(fun id ->
        union_sets t id 0 ;
        (* the rest of the items will be updated when we lazily resize *)
        let num_keys = KeyMap.length t.key_to_id in
        if
          Array.length t.arr > min_capacity && num_keys * 4 < Array.length t.arr
        then resize t Half )

  let get ~key t =
    let%bind.Option id = Hashtbl.find t.key_to_id key in
    (Array.get t.arr @@ find_set ~id t.arr).value

  let union ~a ~b t =
    let a_set = Hashtbl.find t.key_to_id a in
    let b_set = Hashtbl.find t.key_to_id b in
    match (a_set, b_set) with
    | None, None | Some _, None | None, Some _ ->
        ()
    | Some a_set, Some b_set ->
        union_sets t a_set b_set

  let capacity t = Array.length t.arr

  let occupancy t = KeyMap.length t.key_to_id + 1

  let get_size ~key t =
    let%bind.Option id = Hashtbl.find t.key_to_id key in
    Some (size ~id t)
end
