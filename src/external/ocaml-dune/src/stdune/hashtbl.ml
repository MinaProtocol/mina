module type S = Hashtbl_intf.S

include struct
  [@@@warning "-32"]

  let find_opt t key =
    match MoreLabels.Hashtbl.find t key with
    | x -> Some x
    | exception Not_found -> None
end

module Make(H : Hashable.S) = struct
  include MoreLabels.Hashtbl.Make(H)

  include struct
    [@@@warning "-32"]

    let find_opt t key =
      match find t key with
      | x -> Some x
      | exception Not_found -> None
  end

  include struct
    let find = find_opt
    let add t key data = add t ~key ~data

    let find_or_add t key ~f =
      match find t key with
      | Some x -> x
      | None ->
        let x = f key in
        add t key x;
        x

    let foldi t ~init ~f =
      fold t ~init ~f:(fun ~key ~data acc -> f key data acc)
    let fold  t ~init ~f = foldi t ~init ~f:(fun _ x -> f x)
  end

  let of_list l =
    let h = create (List.length l) in
    let rec loop = function
      | [] -> Result.Ok h
      | (k, v) :: xs ->
        begin match find h k with
        | None -> add h k v; loop xs
        | Some v' -> Error (k, v', v)
        end
    in
    loop l

  let of_list_exn l =
    match of_list l with
    | Result.Ok h -> h
    | Error (_, _, _) ->
      Exn.code_error "Hashtbl.of_list_exn duplicate keys" []
end

open MoreLabels.Hashtbl

type nonrec ('a, 'b) t = ('a, 'b) t

let hash = hash
let create = create
let add = add
let replace = replace
let length = length
let remove = remove
let mem = mem
let reset = reset

let find = find_opt

let add t key data = add t ~key ~data

let find_or_add t key ~f =
  match find t key with
  | Some x -> x
  | None ->
    let x = f key in
    add t key x;
    x

let foldi t ~init ~f = fold  t ~init ~f:(fun ~key ~data acc -> f key data acc)
let fold  t ~init ~f = foldi t ~init ~f:(fun _ x -> f x)

let iter t ~f = iter ~f t

let keys t = foldi t ~init:[] ~f:(fun key _ acc -> key :: acc)

let to_sexp (type key) f g t =
  let module M =
    Map.Make(struct
      type t = key
      let compare a b = Ordering.of_int (compare a b)
    end)
  in
  Map.to_sexp M.to_list f g
    (foldi t ~init:M.empty ~f:(fun key data acc ->
       M.add acc key data))
