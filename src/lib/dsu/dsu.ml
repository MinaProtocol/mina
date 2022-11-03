open Core_kernel

let min_capacity = 64

module type Data = sig
  type t

  val merge : t -> t -> t
end

(* Id 0 set is configured with unreachably large rank to be always
     chosen when ranks are compared *)
let infinity_rank = Int.max_value lsr 1

(** DSU data structure with ability to remove sets fromt he structure.contents
    
    For more information on design and usage of the DSU, see:
    https://www.notion.so/minaprotocol/Bit-catchup-algorithm-8a3fa7a2630c46d98505b25ebb20c8e7#e364c78e09c74c03835bc7ed8634dc47
*)
module Make (Key : Hashtbl.Key) (D : Data) = struct
  type element_t = { data : D.t option; parent : int; rank : int }

  module KeyMap = Hashtbl.Make (Key)

  type t =
    { mutable arr : element_t array
    ; mutable next_id : int
    ; mutable occupancy : int
    ; key_to_id : int KeyMap.t
    }

  let init_array =
    Array.init ~f:(fun i ->
        { data = None; parent = i; rank = (if i = 0 then infinity_rank else 0) } )

  let create () =
    { arr = init_array min_capacity
    ; next_id = 1
    ; occupancy = 1
    ; key_to_id = KeyMap.create ()
    }

  let rec find_set ~id arr =
    let el = Array.get arr id in
    if id = el.parent then id
    else
      let parent = find_set ~id:el.parent arr in
      Array.set arr id { el with parent } ;
      parent

  (** Rebuild array in-place: all remaining elements
      will point to itself, map will be updated.
      Returns count of roots in the new structure (excluding id 0)
  *)
  let rebuild ~key_to_id arr =
    (* 1. Map entries to the root set *)
    Hashtbl.map_inplace key_to_id ~f:(fun id -> find_set ~id arr) ;
    let roots = ref 0 in

    (* 2. Remove entries pointing to set 0 *)
    Hashtbl.filter_inplace key_to_id ~f:(fun id -> id <> 0) ;

    (* 3. Copy [data], [rank] to new locations use [parent] field to store new ids *)
    Array.iteri arr ~f:(fun i { data; rank; parent = old_parent } ->
        if old_parent = i then (
          roots := !roots + 1 ;
          Array.set arr i { data; rank; parent = !roots } ;
          let dst_el = Array.get arr !roots in
          Array.set arr !roots { dst_el with data; rank } ) ) ;

    (* 4. Replace old ids with new ids in mapping *)
    Hashtbl.map_inplace key_to_id ~f:(fun id -> (Array.get arr id).parent) ;

    (* 5. Set parent values for new sets *)
    for i = 1 to !roots do
      let dst_el = Array.get arr i in
      Array.set arr !roots { dst_el with parent = i }
    done ;

    !roots

  let resize ~inc ({ key_to_id; _ } as t) =
    let roots = rebuild ~key_to_id t.arr in
    let c' = Int.max min_capacity (Int.ceil_pow2 (roots + 1 + inc) lsl 1) in
    t.next_id <- roots + 1 ;
    t.occupancy <- t.next_id ;
    if c' <> Array.length t.arr then (
      let arr' = init_array c' in
      for i = 1 to roots do
        Array.set arr' i (Array.get t.arr i)
      done ;
      t.arr <- arr' )

  let allocate_id t =
    if t.next_id = Array.length t.arr then resize ~inc:1 t ;
    let id = t.next_id in
    t.next_id <- id + 1 ;
    id

  let rank ~id t = (Array.get t.arr id).rank

  let union_sets t a b =
    let a = find_set t.arr ~id:a in
    let b = find_set t.arr ~id:b in
    let update a b =
      (* a's rank is >= b's rank *)
      let a_el = Array.get t.arr a in
      let b_el = Array.get t.arr b in
      Array.set t.arr b { b_el with parent = a; data = None } ;
      if a_el.rank = b_el.rank then
        Array.set t.arr a
          { a_el with
            rank = a_el.rank + 1
          ; data = Option.map2 ~f:D.merge a_el.data b_el.data
          }
    in
    if a <> b then
      if rank ~id:a t < rank ~id:b t then update b a else update a b

  let add_exn ~key ~data t =
    let id = allocate_id t in
    Hashtbl.add_exn ~key ~data:id t.key_to_id ;
    Array.set t.arr id { data = Some data; parent = id; rank = 0 } ;
    t.occupancy <- t.occupancy + 1

  let remove ~key t =
    Option.iter (Hashtbl.find_and_remove t.key_to_id key) ~f:(fun id ->
        union_sets t id 0 ;
        t.occupancy <- t.occupancy - 1 ;
        if
          Array.length t.arr > min_capacity
          && t.occupancy lsl 2 < Array.length t.arr
        then resize ~inc:0 t )

  let get ~key t =
    let%bind.Option id = Hashtbl.find t.key_to_id key in
    (Array.get t.arr @@ find_set ~id t.arr).data

  let union ~a ~b t =
    let a_set = Option.value ~default:0 (Hashtbl.find t.key_to_id a) in
    let b_set = Option.value ~default:0 (Hashtbl.find t.key_to_id b) in
    union_sets t a_set b_set
end
