open Stdune
open Stanza.Decoder

type 'a one =
  | Unnamed of 'a
  | Named of string * 'a list

type 'a t = 'a one list

let fold t ~f ~init = List.fold_left ~f:(fun acc x -> f x acc) ~init t

let map t ~f =
  List.map t ~f:(function
    | Unnamed a -> Unnamed (f a)
    | Named (s, xs) -> Named (s, List.map ~f xs))

let to_list =
  List.concat_map ~f:(function
    | Unnamed x -> [x]
    | Named (_, xs) -> xs)

let find t k =
  List.find_map t ~f:(function
    | Unnamed _ -> None
    | Named (k', x) -> Option.some_if (k = k') x)

let empty = []

let singleton x = [Unnamed x]

let to_sexp sexp_of_a bindings =
  Sexp.List (
    List.map bindings ~f:(function
      | Unnamed a -> sexp_of_a a
      | Named (name, bindings) ->
        Sexp.List (Sexp.Encoder.string (":" ^ name) :: List.map ~f:sexp_of_a bindings))
  )

let jbuild elem =
  list (elem >>| fun x -> Unnamed x)

let dune elem =
  parens_removed_in_dune (
    let%map l =
      repeat
        (if_paren_colon_form
           ~then_:(
             let%map values = repeat elem in
             fun (loc, name) ->
               Left (loc, name, values))
           ~else_:(elem >>| fun x -> Right x))
    in
    let rec loop vars acc = function
      | [] -> List.rev acc
      | Right x :: l -> loop vars (Unnamed x :: acc) l
      | Left (loc, name, values) :: l ->
        let vars =
          if not (String.Set.mem vars name) then
            String.Set.add vars name
          else
            of_sexp_errorf loc "Variable %s is defined for the second time."
              name
        in
        loop vars (Named (name, values) :: acc) l
    in
    loop String.Set.empty [] l)

let decode elem =
  switch_file_kind
    ~jbuild:(jbuild elem)
    ~dune:(dune elem)

let encode encode bindings =
  Dune_lang.List (
    List.map bindings ~f:(function
      | Unnamed a -> encode a
      | Named (name, bindings) ->
        Dune_lang.List (Dune_lang.atom (":" ^ name) :: List.map ~f:encode bindings))
  )
