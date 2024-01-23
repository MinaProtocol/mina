open Core_kernel
open Mina_numbers

module type Key = Hashtbl.Key_plain

module type S = sig
  module Key : Key

  type 'a t

  val add :
       'a t
    -> prev_key:Key.t
    -> key:Key.t
    -> length:Length.t
    -> data:'a
    -> [ `Ok | `Duplicate | `Too_old ]

  val path : 'a t -> source:Key.t -> ancestor:Key.t -> 'a list option

  val ancestor_of_depth :
    'a t -> source:Key.t -> depth:int -> (Key.t * 'a list) option

  val create : max_size:int -> 'a t
end

module Make (Key : Key) : S with module Key = Key = struct
  module Key = Key
  module Table = Hashtbl.Make_plain (Key)

  module Node = struct
    type 'a t =
      { value : 'a
      ; key : Key.t
      ; length : Length.t
      ; mutable parent : [ `Node of 'a t | `Key of Key.t ]
      ; mutable children : 'a t list
      }
  end

  type 'a t =
    { table : 'a Node.t Table.t
    ; mutable roots : 'a Node.t list
    ; max_size : int
    ; mutable newest : Length.t option
    }

  let create ~max_size =
    { table = Table.create (); newest = None; roots = []; max_size }

  let lookup_node (t : 'a t) k = Hashtbl.find t.table k

  (* TODO: May have to punish peers who ask for ancestor paths
     that don't exist. *)
  let path t ~source ~ancestor =
    let rec go acc (node : _ Node.t) =
      let acc = node.value :: acc in
      match node.parent with
      | `Key k ->
          if Key.compare k ancestor = 0 then Some acc else None
      | `Node parent ->
          if Key.compare parent.key ancestor = 0 then Some acc
          else go acc parent
    in
    Option.bind (lookup_node t source) ~f:(go [])

  let ancestor_of_depth =
    let rec go acc d (node : _ Node.t) =
      if d = 0 then Some (node.key, acc)
      else
        match node.parent with
        | `Node parent ->
            go (node.value :: acc) (d - 1) parent
        | `Key k ->
            if d = 1 then Some (k, node.value :: acc) else None
    in
    fun t ~source ~depth -> Option.bind (lookup_node t source) ~f:(go [] depth)

  let is_old ~max_size ~newest l =
    Length.to_int newest - Length.to_int l > max_size

  let remove_old_nodes t new_length =
    let rec go (node : _ Node.t) =
      if is_old ~max_size:t.max_size ~newest:new_length node.length then (
        Hashtbl.remove t.table node.key ;
        List.iter node.children ~f:(fun child ->
            child.parent <- `Key node.key ;
            go child ) )
    in
    List.iter t.roots ~f:go

  let is_old t length =
    match t.newest with
    | None ->
        false
    | Some newest ->
        is_old ~max_size:t.max_size ~newest length

  let add t ~prev_key ~key ~length ~data =
    if is_old t length then `Too_old
    else if Hashtbl.mem t.table key then `Duplicate
    else
      let node =
        match lookup_node t prev_key with
        | None ->
            let node =
              { Node.value = data
              ; key
              ; parent = `Key prev_key
              ; children = []
              ; length
              }
            in
            t.roots <- node :: t.roots ;
            node
        | Some parent ->
            let node =
              { Node.value = data
              ; key
              ; parent = `Node parent
              ; children = []
              ; length
              }
            in
            parent.children <- node :: parent.children ;
            node
      in
      Hashtbl.set t.table ~key ~data:node ;
      ( match t.newest with
      | None ->
          t.newest <- Some length
      | Some newest ->
          if Length.(newest < length) then (
            t.newest <- Some length ;
            remove_old_nodes t length ) ) ;
      `Ok
end
