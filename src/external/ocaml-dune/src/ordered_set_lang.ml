open! Stdune
open! Import

module Ast = struct
  [@@@warning "-37"]
  type expanded = Expanded
  type unexpanded = Unexpanded
  type ('a, _) t =
    | Element : 'a -> ('a, _) t
    | Standard : ('a, _) t
    | Union : ('a, 'b) t list -> ('a, 'b) t
    | Diff : ('a, 'b) t * ('a, 'b) t -> ('a, 'b) t
    | Include : String_with_vars.t -> ('a, unexpanded) t

  let union = function
    | [x] -> x
    | xs  -> Union xs
end

type 'ast generic =
  { ast : 'ast
  ; loc : Loc.t option
  ; context : Univ_map.t (* Parsing context for Dune_lang.Decoder.parse *)
  }

type ast_expanded = (Loc.t * string, Ast.expanded) Ast.t
type t = ast_expanded generic
let loc t = t.loc

module Parse = struct
  open Stanza.Decoder
  open Ast

  let generic ~inc ~elt =
    let open Stanza.Decoder in
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
            Errors.fail loc
              "Invalid use of :include, should be: (:include <filename>)"
          | _ when s.[0] = ':' ->
            Errors.fail loc "undefined symbol %s" s
          | _ ->
            elt
        end
      | List (_, Atom (loc, A s) :: _) -> begin
          match s, kind with
          | ":include", _ -> inc
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

  let with_include ~elt =
    generic ~elt ~inc:(
      sum [ ":include",
            String_with_vars.decode >>| fun s ->
            Include s
          ])

  let without_include ~elt =
    generic ~elt ~inc:(
      enter
        (loc >>= fun loc ->
         Errors.fail loc "(:include ...) is not allowed here"))
end


let decode =
  let open Stanza.Decoder in
  let%map context = get_all
  and (loc, ast) =
    located (Parse.without_include
               ~elt:(plain_string (fun ~loc s -> Ast.Element (loc, s))))
  in
  { ast; loc = Some loc; context }

let is_standard t =
  match (t.ast : ast_expanded) with
  | Ast.Standard -> true
  | _ -> false

module type Value = sig
  type t
  type key
  val key : t -> key
end

module type Key = sig
  type t
  val compare : t -> t -> Ordering.t
  module Map : Map.S with type key = t
end

module type S = sig
  type value
  type 'a map

  val eval
    :  t
    -> parse:(loc:Loc.t -> string -> value)
    -> standard:value list
    -> value list

  val eval_unordered
    :  t
    -> parse:(loc:Loc.t -> string -> value)
    -> standard:value map
    -> value map
end

module Make(Key : Key)(Value : Value with type key = Key.t) = struct
  module type Named_values = sig
    type t

    val singleton : Value.t -> t
    val union : t list -> t
    val diff : t -> t -> t
  end

  module Make(M : Named_values) = struct
    let eval t ~parse ~standard =
      let rec of_ast (t : ast_expanded) =
        let open Ast in
        match t with
        | Element (loc, s) ->
          let x = parse ~loc s in
          M.singleton x
        | Standard -> standard
        | Union elts -> M.union (List.map elts ~f:of_ast)
        | Diff (left, right) ->
          let left  = of_ast left  in
          let right = of_ast right in
          M.diff left right
      in
      of_ast t.ast
  end

  module Ordered = Make(struct
      type t = Value.t list

      let singleton x = [x]
      let union = List.flatten
      let diff a b =
        List.filter a ~f:(fun x ->
          List.for_all b ~f:(fun y ->
            Ordering.neq (Key.compare (Value.key x) (Value.key y))))
    end)

  module Unordered = Make(struct
      type t = Value.t Key.Map.t

      let singleton x = Key.Map.singleton (Value.key x) x

      let union l =
        List.fold_left l ~init:Key.Map.empty ~f:(fun acc t ->
          Key.Map.merge acc t ~f:(fun _name x y ->
            match x, y with
            | Some x, _ | _, Some x -> Some x
            | _ -> None))

      let diff a b =
        Key.Map.merge a b ~f:(fun _name x y ->
          match x, y with
          | Some _, None -> x
          | _ -> None)
    end)

  type value = Value.t
  type 'a map = 'a Key.Map.t

  let eval t ~parse ~standard =
    if is_standard t then
      standard (* inline common case *)
    else
      Ordered.eval t ~parse ~standard

  let eval_unordered t ~parse ~standard =
    if is_standard t then
      standard (* inline common case *)
    else
      Unordered.eval t ~parse ~standard
end

module Make_loc(Key : Key)(Value : Value with type key = Key.t) = struct
  module No_loc = Make(Key)(struct
      type t = Loc.t * Value.t
      type key = Key.t
      let key (_loc, s) = Value.key s
    end)

  let loc_parse f ~loc s = (loc, f ~loc s)

  let eval t ~parse ~standard =
    No_loc.eval t
      ~parse:(loc_parse parse)
      ~standard:(List.map standard ~f:(fun x -> (Loc.none, x)))

  let eval_unordered t ~parse ~standard =
    No_loc.eval_unordered t
      ~parse:(loc_parse parse)
      ~standard:(Key.Map.map standard ~f:(fun x -> (Loc.none, x)))
end

let standard =
  { ast = Ast.Standard
  ; loc = None
  ; context = Univ_map.empty
  }

let field ?(default=standard) ?check name =
  let decode =
    match check with
    | None -> decode
    | Some x -> Dune_lang.Decoder.(>>>) x decode
  in
  Dune_lang.Decoder.field name decode ~default

module Unexpanded = struct
  type ast = (String_with_vars.t, Ast.unexpanded) Ast.t
  type t = ast generic
  let decode : t Dune_lang.Decoder.t =
    let open Stanza.Decoder in
    let%map context = get_all
    and (loc, ast) =
      located (
        Parse.with_include
          ~elt:(String_with_vars.decode >>| fun s -> Ast.Element s))
    in
    { ast
    ; loc = Some loc
    ; context
    }

  let encode t =
    let open Ast in
    let rec loop = function
      | Element s -> String_with_vars.encode s
      | Standard -> Dune_lang.atom ":standard"
      | Union l -> List (List.map l ~f:loop)
      | Diff (a, b) -> List [loop a; Dune_lang.unsafe_atom_of_string "\\"; loop b]
      | Include fn ->
        List [ Dune_lang.unsafe_atom_of_string ":include"
             ; String_with_vars.encode fn
             ]
    in
    loop t.ast

  let standard = standard

  let of_strings ~pos l =
    { ast = Ast.Union (List.map l ~f:(fun x ->
        Ast.Element (String_with_vars.virt_text pos x)))
    ; loc = Some (Loc.of_pos pos)
    ; context = Univ_map.empty
    }

  let field ?(default=standard) ?check name =
    let decode =
      match check with
      | None -> decode
      | Some x -> Dune_lang.Decoder.(>>>) x decode
    in
    Dune_lang.Decoder.field name decode ~default

  let files t ~f =
    let rec loop acc (ast : ast) =
      let open Ast in
      match ast with
      | Element _ | Standard -> acc
      | Include fn -> Path.Set.add acc (f fn)
      | Union l ->
        List.fold_left l ~init:acc ~f:loop
      | Diff (l, r) ->
        loop (loop acc l) r
    in
    let syntax =
      match Univ_map.find t.context (Syntax.key Stanza.syntax) with
      | Some (0, _)-> Dune_lang.Syntax.Jbuild
      | None | Some (_, _) -> Dune
    in
    (syntax, loop Path.Set.empty t.ast)

  let has_special_forms t =
    let rec loop (t : ast) =
      let open Ast in
      match t with
      | Standard | Include _ -> true
      | Element _ -> false
      | Union l ->
        List.exists l ~f:loop
      | Diff (l, r) ->
        loop l ||
        loop r
    in
    loop t.ast

  type position = Pos | Neg

  let fold_strings t ~init ~f =
    let rec loop (t : ast) pos acc =
      let open Ast in
      match t with
      | Standard | Include _ -> acc
      | Element x -> f pos x acc
      | Union l -> List.fold_left l ~init:acc ~f:(fun acc x -> loop x pos acc)
      | Diff (l, r) ->
        let acc = loop l pos acc in
        let pos =
          match pos with
          | Pos -> Neg
          | Neg -> Pos
        in
        loop r pos acc
    in
    loop t.ast Pos init

  let expand t ~dir ~files_contents ~(f : String_with_vars.t -> Value.t list) =
    let context = t.context in
    let f_elems s =
      let loc = String_with_vars.loc s in
      Ast.union
        (List.map (f s) ~f:(fun s -> Ast.Element (loc, Value.to_string ~dir s)))
    in
    let rec expand (t : ast) : ast_expanded =
      let open Ast in
      match t with
      | Element s -> f_elems s
      | Standard -> Standard
      | Include fn ->
        let sexp =
          let path =
            match f fn with
            | [x] -> Value.to_path ~dir x
            | _ ->
              Errors.fail (String_with_vars.loc fn)
                "An unquoted templated expanded to more than one value. \
                 A file path is expected in this position."
          in
          match Path.Map.find files_contents path with
          | Some x -> x
          | None ->
            Exn.code_error
              "Ordered_set_lang.Unexpanded.expand"
              [ "included-file", Path.to_sexp path
              ; "files", Sexp.Encoder.(list Path.to_sexp)
                           (Path.Map.keys files_contents)
              ]
        in
        let open Stanza.Decoder in
        parse
          (Parse.without_include ~elt:(String_with_vars.decode >>| f_elems))
          context
          sexp
      | Union l -> Union (List.map l ~f:expand)
      | Diff (l, r) ->
        Diff (expand l, expand r)
    in
    { t with ast = expand t.ast }
end

module String = Make(struct
    type t = string
    let compare = String.compare
    module Map = String.Map
  end)(struct
    type t = string
    type key = string
    let key x = x
  end)
