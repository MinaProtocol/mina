open Stdune

module Ast = struct
  type 'a t =
    | Element of 'a
    | Standard
    | Union of 'a t list
    | Diff of 'a t * 'a t

  let decode elt =
    let open Stanza.Decoder in
    let elt = elt >>| fun e -> Element e in
    let rec one (kind : Dune_lang.Syntax.t) =
      peek_exn >>= function
      | Atom (loc, A "\\") -> Errors.fail loc "unexpected \\"
      | (Atom (_, A "") | Quoted_string (_, _)) | Template _ ->
        elt
      | Atom (loc, A s) -> begin
          match s with
          | ":standard" ->
            junk >>> return Standard
          | ":include" ->
            Errors.fail loc ":include isn't supported in the predicate language"
          | _ when s.[0] = ':' ->
            Errors.fail loc "undefined symbol %s" s
          | _ ->
            elt
        end
      | List (_, Atom (loc, A s) :: _) -> begin
          match s, kind with
          | ":include", _ ->
            Errors.fail loc ":include isn't supported in the predicate language"
          | s, Dune when s <> "" && s.[0] <> '-' && s.[0] <> ':' ->
            Errors.fail loc
              "This atom must be quoted because it is the first element \
               of a list and doesn't start with - or :"
          | _ -> enter (many [] kind)
        end
      | List _ -> enter (many [] kind)
    and many acc kind =
      peek >>= function
      | None -> return (Union (List.rev acc))
      | Some (Atom (_, A "\\")) ->
        junk >>> many [] kind >>| fun to_remove ->
        Diff (Union (List.rev acc), to_remove)
      | Some _ ->
        one kind >>= fun x ->
        many (x :: acc) kind
    in
    Stanza.file_kind () >>= fun kind ->
    match kind with
    | Dune -> many [] kind
    | Jbuild -> one kind
end

type t = (string -> bool) Ast.t

let decode : t Dune_lang.Decoder.t =
  let open Stanza.Decoder in
  Ast.decode (Glob.decode >>| Glob.test)

let empty = Ast.Union []

let rec mem t ~standard ~elem =
  match (t : _ Ast.t) with
  | Element f -> f elem
  | Union xs -> List.exists ~f:(mem ~standard ~elem) xs
  | Diff (l, r) ->
    mem l ~standard ~elem && not (mem ~standard ~elem r)
  | Standard -> mem standard ~standard ~elem

let filter (t : t) ~standard elems =
  match t with
  | Union [] -> []
  | _ ->
    (List.filter (Lazy.force elems)
       ~f:(fun elem -> mem t ~standard:standard ~elem))

let union t = Ast.Union t

let of_glob g = Ast.Element (Glob.test g)

let of_string_set s = Ast.Element (String.Set.mem s)
