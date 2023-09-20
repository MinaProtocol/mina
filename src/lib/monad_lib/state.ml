open Core_kernel

module Base = struct
  type ('a, 's) t = 's -> 'a * 's

  let return a s = (a, s)

  let map = `Custom (fun m ~f s -> m s |> Tuple.T2.map_fst ~f)

  let bind m ~f s =
    let a, s' = m s in
    f a s'
end

include Monad.Make2 (Base)

type ('a, 's) t = ('a, 's) Base.t

let run_state (type a s) (m : (a, s) t) (s : s) : a * s = m s

let eval_state m = Fn.compose fst (run_state m)

let exec_state m = Fn.compose snd (run_state m)

let get : ('s, 's) t = fun s -> (s, s)

let getf (f : 's -> 'a) : ('a, 's) t = fun s -> (f s, s)

let put s : (unit, 's) t = fun _ -> ((), s)

let modify ~f : (unit, 's) t = fun s -> ((), f s)

let with_state (f : 's -> 'a * 's) : ('a, 's) t = f

let rec fold_m ~(f : 'b -> 'a -> ('b, 's) t) ~(init : 'b) :
    'a list -> ('b, 's) t = function
  | [] ->
      return init
  | x :: xs ->
      let open Let_syntax in
      let%bind b = f init x in
      fold_m ~f ~init:b xs

let map_m ~(f : 'a -> ('b, 's) t) (xs : 'a list) : ('b list, 's) t =
  let open Let_syntax in
  let%map ys =
    fold_m ~init:[] ~f:(fun acc x -> map ~f:(fun y -> y :: acc) (f x)) xs
  in
  List.rev ys

let filter_map_m ~(f : 'a -> ('b option, 's) t) (xs : 'a list) : ('b list, 's) t
    =
  let open Let_syntax in
  let append acc = function None -> acc | Some y -> y :: acc in
  let%map ys = fold_m ~init:[] ~f:(fun acc x -> map ~f:(append acc) (f x)) xs in
  List.rev ys

let concat_map_m ~(f : 'a -> ('b list, 's) t) (xs : 'a list) : ('b list, 's) t =
  fold_m ~init:[] ~f:(fun acc x -> map ~f:(List.append acc) (f x)) xs

module Trans (M : Monad.S) = struct
  module Base = struct
    type ('a, 's) t = 's -> ('a * 's) M.t

    let return a s = M.return (a, s)

    let map =
      `Custom
        (fun m ~f s ->
          let open M.Let_syntax in
          let%map a, s' = m s in
          (f a, s') )

    let bind m ~f s =
      let open M.Let_syntax in
      let%bind a, s' = m s in
      f a s'
  end

  include Base
  include Monad.Make2 (Base)

  let get : ('s, 's) t = fun s -> M.return (s, s)

  let getf f s = M.map ~f:(fun (a, s) -> (f a, s)) @@ get s

  let put s : (unit, 's) t = fun _ -> M.return ((), s)

  let modify ~f s = M.return ((), f s)

  let run_state (type a s) (m : (a, s) t) (s : s) : (a * s) M.t = m s

  let eval_state m s = M.map ~f:fst (run_state m s)

  let exec_state m s = M.map ~f:snd (run_state m s)

  let lift : 'a M.t -> ('a, 's) t = fun m s -> M.map m ~f:(fun a -> (a, s))
end
