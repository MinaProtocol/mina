open Core_kernel

  module T = struct
    type t =
      | Var of Name.t
      | Fun_call of Name.t * t list
      | Method_call of t * Name.t * t list
      | Array of t list
      | Struct of (string * t) list
    [@@deriving eq, compare, sexp, hash]
  end

  include T
  include Hashable.Make (T)

  let rec to_rust =
    let seq = String.concat ~sep:", " in
    function
    | Var name ->
        name
    | Fun_call (name, args) ->
        sprintf "%s(%s)" name
          (String.concat ~sep:", " (List.map args ~f:to_rust))
    | Array ts ->
        sprintf "vec![%s]" (seq (List.map ts ~f:to_rust))
    | Struct xs ->
        sprintf "vec![%s]"
          (seq
             (List.map xs ~f:(fun (_name, t) ->
                  (to_rust t) )))
    | Method_call (x, m, args) ->
      sprintf "%s.%s.(%s)"
        (to_rust x) m
        (seq (List.map args ~f:to_rust))

  let rec to_ocaml =
    let seq = String.concat ~sep:"; " in
    function
    | Var name ->
        name
    | Fun_call (name, args) ->
        sprintf "(%s %s)" name
          (String.concat ~sep:" " (List.map args ~f:to_ocaml))
    | Array ts ->
        sprintf "[|%s|]" (seq (List.map ts ~f:to_ocaml))
    | Struct xs ->
        sprintf "{ %s }"
          (seq
             (List.map xs ~f:(fun (name, t) ->
                  sprintf "%s= %s" name (to_ocaml t) )))
    | Method_call _ -> failwith "TODO"

