open! Stdune
open Import

type 'a t =
  | A        of string
  | As       of string list
  | S        of 'a t list
  | Concat   of string * 'a t list
  | Dep      of Path.t
  | Deps     of Path.t list
  | Target   of Path.t
  | Path     of Path.t
  | Paths    of Path.t list
  | Hidden_deps    of Path.t list
  | Hidden_targets of Path.t list
  | Dyn      of ('a -> Nothing.t t)

let rec add_deps ts set =
  List.fold_left ts ~init:set ~f:(fun set t ->
    match t with
    | Dep fn -> Path.Set.add set fn
    | Deps        fns
    | Hidden_deps fns -> Path.Set.union set (Path.Set.of_list fns)
    | S ts
    | Concat (_, ts) -> add_deps ts set
    | _ -> set)

let rec add_targets ts acc =
  List.fold_left ts ~init:acc ~f:(fun acc t ->
    match t with
    | Target fn  -> fn :: acc
    | Hidden_targets fns -> List.rev_append fns acc
    | S ts
    | Concat (_, ts) -> add_targets ts acc
    | _ -> acc)

let expand ~dir ts x =
  let dyn_deps = ref Path.Set.empty in
  let add_dep path = dyn_deps := Path.Set.add !dyn_deps path in
  let rec loop_dyn : Nothing.t t -> string list = function
    | A s  -> [s]
    | As l -> l
    | Dep fn ->
      add_dep fn;
      [Path.reach fn ~from:dir]
    | Path fn -> [Path.reach fn ~from:dir]
    | Deps fns ->
      List.map fns ~f:(fun fn ->
        add_dep fn;
        Path.reach ~from:dir fn)
    | Paths fns ->
      List.map fns ~f:(Path.reach ~from:dir)
    | S ts -> List.concat_map ts ~f:loop_dyn
    | Concat (sep, ts) -> [String.concat ~sep (loop_dyn (S ts))]
    | Target _ | Hidden_targets _ -> die "Target not allowed under Dyn"
    | Dyn _ -> assert false
    | Hidden_deps l ->
      dyn_deps := Path.Set.union !dyn_deps (Path.Set.of_list l);
      []
  in
  let rec loop = function
    | A s  -> [s]
    | As l -> l
    | (Dep fn | Path fn) -> [Path.reach fn ~from:dir]
    | (Deps fns | Paths fns) -> List.map fns ~f:(Path.reach ~from:dir)
    | S ts -> List.concat_map ts ~f:loop
    | Concat (sep, ts) -> [String.concat ~sep (loop (S ts))]
    | Target fn -> [Path.reach fn ~from:dir]
    | Dyn f -> loop_dyn (f x)
    | Hidden_deps _ | Hidden_targets _ -> []
  in
  let l = List.concat_map ts ~f:loop in
  (l, !dyn_deps)

let quote_args =
  let rec loop quote = function
    | [] -> []
    | arg :: args -> quote :: arg :: loop quote args
  in
  fun quote args -> As (loop quote args)

let of_result = function
  | Ok x -> x
  | Error e -> Dyn (fun _ -> raise e)

let of_result_map res ~f =
  match res with
  | Ok    x -> f x
  | Error e -> Dyn (fun _ -> raise e)
