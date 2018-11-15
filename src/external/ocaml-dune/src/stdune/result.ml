type ('a, 'error) t = ('a, 'error) Dune_caml.result =
  | Ok    of 'a
  | Error of 'error

let ok x = Ok x

let is_ok = function
  | Ok    _ -> true
  | Error _ -> false

let is_error = function
  | Ok    _ -> false
  | Error _ -> true

let ok_exn = function
  | Ok    x -> x
  | Error e -> raise e

let bind t ~f =
  match t with
  | Ok x -> f x
  | Error _ as t -> t

let map x ~f =
  match x with
  | Ok x -> Ok (f x)
  | Error _ as x -> x

let map_error x ~f =
  match x with
  | Ok _ as res -> res
  | Error x -> Error (f x)

let errorf fmt =
  Printf.ksprintf (fun x -> Error x) fmt

module O = struct
  let ( >>= ) t f = bind t ~f
  let ( >>| ) t f = map  t ~f
end

open O

type ('a, 'error) result = ('a, 'error) t

module List = struct
  let map t ~f =
    let rec loop acc = function
      | [] -> Ok (List.rev acc)
      | x :: xs ->
        f x >>= fun x ->
        loop (x :: acc) xs
    in
    loop [] t

  let all =
    let rec loop acc = function
      | [] -> Ok (List.rev acc)
      | t :: l ->
        t >>= fun x ->
        loop (x :: acc) l
    in
    fun l -> loop [] l

  let concat_map =
    let rec loop f acc = function
      | [] -> Ok (List.rev acc)
      | x :: l ->
        f x >>= fun y ->
        loop f (List.rev_append y acc) l
    in
    fun l ~f -> loop f [] l

  let rec iter t ~f =
    match t with
    | [] -> Ok ()
    | x :: xs ->
      f x >>= fun () ->
      iter xs ~f

  let rec fold_left t ~f ~init =
    match t with
    | [] -> Ok init
    | x :: xs ->
      f init x >>= fun init ->
      fold_left xs ~f ~init
end
