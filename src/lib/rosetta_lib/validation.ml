open Core_kernel

(* Applicative validation -- like https://hackage.haskell.org/package/validation-1.1/docs/Data-Validation.html   *)
module T = struct
  type ('a, 'b) t = ('a, 'b list) Result.t

  let map = `Custom (fun t ~f -> Result.map ~f t)

  let return a = Result.return a

  let fail e = Result.fail [e]

  let apply ft t =
    match (ft, t) with
    | Ok f, Ok a ->
        Ok (f a)
    | Error es, Ok _ ->
        Error es
    | Ok _, Error es ->
        Error es
    | Error es, Error es' ->
        Error (es @ es')
end

include T
include Applicative.Make2 (T)

module Let_syntax = struct
  let return = return

  module Let_syntax = struct
    let return = return

    let map = map

    let both t1 t2 = apply (map t1 ~f:(fun x y -> (x, y))) t2

    module Open_on_rhs = struct end
  end
end
