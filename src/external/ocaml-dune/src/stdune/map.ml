module type S = Map_intf.S

module Make(Key : Comparable.S) : S with type key = Key.t = struct
  module M = MoreLabels.Map.Make(struct
      type t = Key.t
      let compare a b = Ordering.to_int (Key.compare a b)
    end)

  include struct
    [@@@warning "-32"]

    let find_opt key t =
      match M.find key t with
      | x -> Some x
      | exception Not_found -> None

    let to_opt f t =
      match f t with
      | x -> Some x
      | exception Not_found -> None
    let choose_opt t = to_opt M.choose t
    let min_binding_opt t = to_opt M.min_binding t
    let max_binding_opt t = to_opt M.max_binding t

    let update ~key ~f t =
      match f (find_opt key t) with
      | None -> M.remove key t
      | Some v -> M.add t ~key ~data:v

    let union ~f a b =
      M.merge a b ~f:(fun k a b ->
        match a, b with
        | None  , None   -> None
        | Some v, None
        | None  , Some v -> Some v
        | Some a, Some b -> f k a b)
  end

  include M

  let find key t = find_opt t key

  let mem t k = mem k t
  let add t k v = add ~key:k ~data:v t
  let update t k ~f = update ~key:k ~f t
  let remove t k = remove k t

  let add_multi t key x =
    let l = Option.value (find t key) ~default:[] in
    add t key (x :: l)

  let merge a b ~f = merge a b ~f
  let union a b ~f = union a b ~f

  let compare a b ~compare =
    M.compare a b ~cmp:(fun a b -> Ordering.to_int (compare a b))
    |> Ordering.of_int
  let equal a b ~equal = M.equal a b ~cmp:equal

  let iteri t ~f = iter  t ~f:(fun ~key ~data -> f key data)
  let iter  t ~f = iteri t ~f:(fun _ x -> f x)
  let foldi t ~init ~f = fold  t ~init ~f:(fun ~key ~data acc -> f key data acc)
  let fold  t ~init ~f = foldi t ~init ~f:(fun _ x acc -> f x acc)

  let for_alli   t ~f = for_all    t ~f
  let for_all    t ~f = for_alli   t ~f:(fun _ x -> f x)
  let existsi    t ~f = exists     t ~f
  let exists     t ~f = existsi    t ~f:(fun _ x -> f x)
  let filteri    t ~f = filter     t ~f
  let filter     t ~f = filteri    t ~f:(fun _ x -> f x)
  let partitioni t ~f = partition  t ~f
  let partition  t ~f = partitioni t ~f:(fun _ x -> f x)

  let to_list = bindings

  let of_list =
    let rec loop acc = function
      | [] -> Result.Ok acc
      | (k, v) :: l ->
        match find acc k with
        | None       -> loop (add acc k v) l
        | Some v_old -> Error (k, v_old, v)
    in
    fun l -> loop empty l

  let of_list_map =
    let rec loop f acc = function
      | [] -> Result.Ok acc
      | x :: l ->
        let k, v = f x in
        if not (mem acc k) then
          loop f (add acc k v) l
        else
          Error k
    in
    fun l ~f ->
      match loop f empty l with
      | Ok _ as x -> x
      | Error k ->
        match
          List.filter l ~f:(fun x ->
            match Key.compare (fst (f x)) k with
            | Eq -> true
            | _  -> false)
        with
        | x :: y :: _ -> Error (k, x, y)
        | _ -> assert false

  let of_list_exn l =
    match of_list l with
    | Ok    x -> x
    | Error _ -> invalid_arg "Map.of_list_exn"

  let of_list_reduce l ~f =
    List.fold_left l ~init:empty ~f:(fun acc (key, data) ->
      match find acc key with
      | None   -> add acc key data
      | Some x -> add acc key (f x data))

  let of_list_multi l =
    List.fold_left (List.rev l) ~init:empty ~f:(fun acc (key, data) ->
      add_multi acc key data)

  let keys   t = foldi t ~init:[] ~f:(fun k _ l -> k :: l) |> List.rev
  let values t = foldi t ~init:[] ~f:(fun _ v l -> v :: l) |> List.rev

  let min_binding = min_binding_opt
  let max_binding = max_binding_opt
  let choose      = choose_opt

  let split k t = split t k

  let map  t ~f = map  t ~f
  let mapi t ~f = mapi t ~f

  let filter_mapi t ~f =
    merge t empty ~f:(fun key data _always_none ->
      match data with
      | None      -> assert false
      | Some data -> f key data)
  let filter_map t ~f = filter_mapi t ~f:(fun _ x -> f x)

  let superpose a b =
    union a b ~f:(fun _ _ y -> Some y)
end

let to_sexp to_list f g t =
  Sexp.Encoder.(list (pair f g)) (to_list t)
