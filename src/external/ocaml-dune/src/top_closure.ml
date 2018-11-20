open! Stdune

module type Keys = sig
  type t
  type elt
  val empty : t
  val add : t -> elt -> t
  val mem : t -> elt -> bool
end

module type S = sig
  type key
  val top_closure
    :  key:('a -> key)
    -> deps:('a -> 'a list)
    -> 'a list
    -> ('a list, 'a list) result
end

module Make(Keys : Keys) = struct
  let top_closure ~key ~deps elements =
    let visited = ref Keys.empty in
    let res = ref [] in
    let rec loop elt ~temporarily_marked =
      let key = key elt in
      if Keys.mem temporarily_marked key then
        Error [elt]
      else if not (Keys.mem !visited key) then begin
        visited := Keys.add !visited key;
        let temporarily_marked = Keys.add temporarily_marked key in
        match iter_elts (deps elt) ~temporarily_marked with
        | Ok () -> res := elt :: !res; Ok ()
        | Error l -> Error (elt :: l)
      end else
        Ok ()
    and iter_elts elts ~temporarily_marked =
      match elts with
      | [] -> Ok ()
      | elt :: elts ->
        match loop elt ~temporarily_marked with
        | Error _ as result -> result
        | Ok () -> iter_elts elts ~temporarily_marked
    in
    match iter_elts elements ~temporarily_marked:Keys.empty with
    | Ok () -> Ok (List.rev !res)
    | Error elts -> Error elts
end

module Int    = Make(Int.Set)
module String = Make(String.Set)
