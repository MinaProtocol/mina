open! Stdune

module type S = sig
  type key

  type 'a t

  val for_all : 'a -> 'a t
  val of_mapping
    :  (key list * 'a) list
    -> default:'a
    -> ('a t, key * 'a * 'a) result
  val get : 'a t -> key -> 'a
  val is_constant : _ t -> bool
  val map : 'a t -> f:('a -> 'b) -> 'b t
  val fold : 'a t -> init:'acc -> f:('a -> 'acc -> 'acc) -> 'acc
end

module Make(Key : Comparable.S) : S with type key = Key.t = struct
  module Map = Map.Make(Key)

  type key = Key.t

  type 'a t =
    { map    : int Map.t
    ; values : 'a array
    }

  let for_all x =
    { map    = Map.empty
    ; values = [|x|]
    }

  let of_mapping l ~default =
    let values =
      Array.of_list (default :: List.map l ~f:snd)
    in
    List.mapi l ~f:(fun i (keys, _) ->
      List.map keys ~f:(fun key -> (key, i + 1)))
    |> List.concat
    |> Map.of_list
    |> function
    | Ok map ->
      Ok { map; values }
    | Error (key, x, y) ->
      Error (key, values.(x), values.(y))

  let get t key =
    let index =
      match Map.find t.map key with
      | None   -> 0
      | Some i -> i
    in
    t.values.(index)

  let map t ~f =
    { t with values = Array.map t.values ~f }

  let fold t ~init ~f =
    Array.fold_right t.values ~init ~f

  let is_constant t = Array.length t.values = 1
end
