open Core_kernel
module State = State

module Make_ext (M : Monad.S) = struct
  type 'a t = 'a M.t

  let rec fold_m ~f ~init = function
    | [] ->
        M.return init
    | x :: xs ->
        let open M.Let_syntax in
        let%bind y = f init x in
        fold_m ~f ~init:y xs

  let map_m ~f xs =
    let open M.Let_syntax in
    fold_m xs ~init:[] ~f:(fun acc x ->
        let%map y = f x in
        y :: acc )
    |> M.map ~f:List.rev

  let concat_map_m ~f xs =
    let open M.Let_syntax in
    fold_m xs ~init:[] ~f:(fun acc x ->
        let%map ys = f x in
        List.append acc ys )

  let iter_m ~f xs = fold_m ~f:(fun () x -> f x) ~init:() xs

  let sequence ms =
    fold_m ms ~init:[] ~f:(fun acc m ->
        let open M.Let_syntax in
        let%map x = m in
        x :: acc )
end

module Make_ext2 (M : Monad.S2) = struct
  type ('a, 'b) t = ('a, 'b) M.t

  let rec fold_m ~f ~init = function
    | [] ->
        M.return init
    | x :: xs ->
        let open M.Let_syntax in
        let%bind y = f init x in
        fold_m ~f ~init:y xs

  let map_m ~f xs =
    let open M.Let_syntax in
    fold_m xs ~init:[] ~f:(fun acc x ->
        let%map y = f x in
        y :: acc )
    |> M.map ~f:List.rev

  let concat_map_m ~f xs =
    let open M.Let_syntax in
    fold_m xs ~init:[] ~f:(fun acc x ->
        let%map ys = f x in
        List.append acc ys )

  let iter_m ~f xs = fold_m ~f:(fun () x -> f x) ~init:() xs

  let sequence ms =
    fold_m ms ~init:[] ~f:(fun acc m ->
        let open M.Let_syntax in
        let%map x = m in
        x :: acc )
end
