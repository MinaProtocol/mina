(** Dune S-expression AST, pretty-printing, parsing,
    and structural comparison. *)

type t = Atom of string | List of t list | Comment of string

let atom s = Atom s

let list l = List l

let ( @: ) name children = List (Atom name :: children)

let needs_quoting s =
  s = "" || String.contains s ' ' || String.contains s '\n'
  || String.contains s '\t' || String.contains s '"' || String.contains s '('
  || String.contains s ')' || String.contains s ';'

let pp_atom fmt s =
  if needs_quoting s then Format.fprintf fmt "%S" s
  else Format.fprintf fmt "%s" s

let rec pp fmt = function
  | Atom s ->
      pp_atom fmt s
  | Comment c ->
      Format.fprintf fmt "; %s" c
  | List [] ->
      Format.fprintf fmt "()"
  | List items ->
      Format.fprintf fmt "@[<v 1>(" ;
      List.iteri
        (fun i item ->
          if i > 0 then Format.fprintf fmt "@," ;
          pp fmt item )
        items ;
      Format.fprintf fmt ")@]"

let pp_toplevel fmt stanzas =
  List.iteri
    (fun i s ->
      if i > 0 then Format.fprintf fmt "@,@," ;
      pp fmt s )
    stanzas ;
  Format.fprintf fmt "@."

let to_string stanzas =
  let buf = Buffer.create 4096 in
  let fmt = Format.formatter_of_buffer buf in
  Format.pp_set_margin fmt 80 ;
  pp_toplevel fmt stanzas ;
  Format.pp_print_flush fmt () ;
  Buffer.contents buf

type token = LPAREN | RPAREN | STRING of string | COMMENT_TOK of string

let tokenize input =
  let len = String.length input in
  let tokens = ref [] in
  let i = ref 0 in
  while !i < len do
    let c = input.[!i] in
    match c with
    | ' ' | '\t' | '\n' | '\r' ->
        incr i
    | '(' ->
        tokens := LPAREN :: !tokens ;
        incr i
    | ')' ->
        tokens := RPAREN :: !tokens ;
        incr i
    | ';' ->
        (* line comment *)
        let start = !i + 1 in
        while !i < len && input.[!i] <> '\n' do
          incr i
        done ;
        let comment = String.trim (String.sub input start (!i - start)) in
        if comment <> "" then tokens := COMMENT_TOK comment :: !tokens
    | '"' ->
        (* quoted string *)
        incr i ;
        let buf = Buffer.create 64 in
        while !i < len && input.[!i] <> '"' do
          if input.[!i] = '\\' && !i + 1 < len then (
            incr i ;
            ( match input.[!i] with
            | 'n' ->
                Buffer.add_char buf '\n'
            | 't' ->
                Buffer.add_char buf '\t'
            | '\\' ->
                Buffer.add_char buf '\\'
            | '"' ->
                Buffer.add_char buf '"'
            | c ->
                Buffer.add_char buf '\\' ; Buffer.add_char buf c ) ;
            incr i )
          else (
            Buffer.add_char buf input.[!i] ;
            incr i )
        done ;
        if !i < len then incr i ;
        (* skip closing quote *)
        tokens := STRING (Buffer.contents buf) :: !tokens
    | _ ->
        (* unquoted atom *)
        let start = !i in
        while
          !i < len
          && input.[!i] <> ' '
          && input.[!i] <> '\t'
          && input.[!i] <> '\n'
          && input.[!i] <> '\r'
          && input.[!i] <> '('
          && input.[!i] <> ')'
          && input.[!i] <> ';'
          && input.[!i] <> '"'
        do
          incr i
        done ;
        let s = String.sub input start (!i - start) in
        tokens := STRING s :: !tokens
  done ;
  List.rev !tokens

let parse_tokens tokens =
  let tokens = ref tokens in
  let rec parse_one () =
    match !tokens with
    | [] ->
        None
    | LPAREN :: rest -> (
        tokens := rest ;
        let items = parse_many () in
        match !tokens with
        | RPAREN :: rest ->
            tokens := rest ;
            Some (List items)
        | _ ->
            (* unclosed paren, best effort *)
            Some (List items) )
    | RPAREN :: _ ->
        None
    | STRING s :: rest ->
        tokens := rest ;
        Some (Atom s)
    | COMMENT_TOK c :: rest ->
        tokens := rest ;
        Some (Comment c)
  and parse_many () =
    match parse_one () with None -> [] | Some item -> item :: parse_many ()
  in
  parse_many ()

let parse_string input =
  let tokens = tokenize input in
  parse_tokens tokens

let parse_file path =
  let ic = open_in path in
  let n = in_channel_length ic in
  let s = Bytes.create n in
  really_input ic s 0 n ;
  close_in ic ;
  parse_string (Bytes.to_string s)

let rec strip_comments = function
  | Atom _ as a ->
      Some a
  | Comment _ ->
      None
  | List items ->
      let items' = List.filter_map strip_comments items in
      Some (List items')

let strip_comments_list l = List.filter_map strip_comments l

(** Get the "key" of a dune field for set-based comparison.
    E.g. [(name foo)] has key ["name"]. *)
let field_key = function List (Atom key :: _) -> Some key | _ -> None

(** Check if a stanza is a keyed stanza (library, executable,
    rule, etc.) where field order doesn't matter. *)
let is_keyed_stanza = function
  | List (Atom key :: _) ->
      List.mem key
        [ "library"
        ; "executable"
        ; "test"
        ; "rule"
        ; "install"
        ; "env"
        ; "inline_tests"
        ; "foreign_stubs"
        ; "preprocess"
        ; "instrumentation"
        ]
  | _ ->
      false

(** Find a field by key in a list. *)
let find_field key fields =
  List.find_opt (fun f -> field_key f = Some key) fields

(** Check if a field should be compared as a set
    (order-insensitive). *)
let is_set_field = function
  | List (Atom key :: _) ->
      List.mem key [ "libraries"; "pps" ]
  | _ ->
      false

(** Compare atoms as strings for sorting. *)
let atom_name = function Atom s -> s | List (Atom s :: _) -> s | _ -> ""

let sort_atoms items =
  List.sort (fun a b -> String.compare (atom_name a) (atom_name b)) items

(** Field-order-insensitive equality for stanzas.
    For keyed stanzas, compare fields as sets.
    For set fields (libraries, pps), compare as sets.
    For other lists, compare element-by-element.
    Atom x and List [Atom x] are considered equal to handle
    dune syntax variations like
    [(library_flags -linkall)] vs [(library_flags (-linkall))]. *)
let rec equal a b =
  match (a, b) with
  | Atom s1, Atom s2 ->
      s1 = s2
  | Comment _, _ | _, Comment _ ->
      true
  | Atom s, List [ Atom s2 ] | List [ Atom s2 ], Atom s ->
      s = s2
  | List l1, List l2 ->
      let l1 = strip_comments_list l1 in
      let l2 = strip_comments_list l2 in
      if is_keyed_stanza a || is_keyed_stanza b then equal_fields l1 l2
      else if is_set_field a || is_set_field b then equal_set l1 l2
      else
        (* Handle (field (a b c)) == (field a b c) equivalence
           for ordered set language expressions like modules *)
        let unwrap l =
          match l with Atom k :: [ List inner ] -> Atom k :: inner | _ -> l
        in
        let l1' = unwrap l1 in
        let l2' = unwrap l2 in
        List.length l1' = List.length l2' && List.for_all2 equal l1' l2'
  | _ ->
      false

and equal_set l1 l2 =
  (* First element is the field name (e.g. "libraries") *)
  match (l1, l2) with
  | Atom k1 :: rest1, Atom k2 :: rest2 when k1 = k2 ->
      let s1 = sort_atoms rest1 in
      let s2 = sort_atoms rest2 in
      List.length s1 = List.length s2 && List.for_all2 equal s1 s2
  | _ ->
      List.length l1 = List.length l2 && List.for_all2 equal l1 l2

and name_implied_by_public_name keyed =
  (* Check if (name X) is implied by (public_name Y) where
     deriving Y gives X. In dune, name is optional when it
     can be inferred from public_name. *)
  match (find_field "name" keyed, find_field "public_name" keyed) with
  | ( Some (List [ Atom "name"; Atom n ])
    , Some (List [ Atom "public_name"; Atom pn ]) ) ->
      let derived =
        String.map (fun c -> if c = '.' || c = '-' then '_' else c) pn
      in
      n = derived
  | _ ->
      false

and field_is_implied key keyed_self keyed_other =
  (* A field in keyed_self is "implied" (and thus OK to skip)
     if it's (name X) missing from keyed_other but derivable
     from (public_name Y) in keyed_other. *)
  key = "name"
  && find_field "name" keyed_other = None
  && name_implied_by_public_name keyed_self

and equal_fields l1 l2 =
  (* First element is the stanza kind (e.g. "library") *)
  match (l1, l2) with
  | [], [] ->
      true
  | Atom k1 :: rest1, Atom k2 :: rest2 when k1 = k2 ->
      (* Compare remaining fields as sets *)
      let keyed1, unkeyed1 =
        List.partition (fun f -> field_key f <> None) rest1
      in
      let keyed2, unkeyed2 =
        List.partition (fun f -> field_key f <> None) rest2
      in
      (* Every keyed field in l1 has a match in l2 *)
      List.for_all
        (fun f1 ->
          match field_key f1 with
          | None ->
              true
          | Some k -> (
              match find_field k keyed2 with
              | Some f2 ->
                  equal f1 f2
              | None ->
                  field_is_implied k keyed1 keyed2 ) )
        keyed1
      (* And vice versa *)
      && List.for_all
           (fun f2 ->
             match field_key f2 with
             | None ->
                 true
             | Some k ->
                 find_field k keyed1 <> None || field_is_implied k keyed2 keyed1
             )
           keyed2
      (* Unkeyed items match positionally *)
      && List.length unkeyed1 = List.length unkeyed2
      && List.for_all2 equal unkeyed1 unkeyed2
  | _ ->
      List.length l1 = List.length l2 && List.for_all2 equal l1 l2

let equal_stanzas a b =
  let a = strip_comments_list a in
  let b = strip_comments_list b in
  List.length a = List.length b && List.for_all2 equal a b

let rec diff a b =
  match (a, b) with
  | Atom s1, Atom s2 ->
      if s1 = s2 then None else Some (Printf.sprintf "atom %S vs %S" s1 s2)
  | Comment _, _ | _, Comment _ ->
      None
  | List l1, List l2 ->
      let l1 = strip_comments_list l1 in
      let l2 = strip_comments_list l2 in
      if is_keyed_stanza a || is_keyed_stanza b then diff_fields l1 l2
      else if is_set_field a || is_set_field b then diff_set l1 l2
      else if List.length l1 <> List.length l2 then
        Some
          (Printf.sprintf "list length %d vs %d" (List.length l1)
             (List.length l2) )
      else
        List.fold_left2
          (fun acc a b -> match acc with Some _ -> acc | None -> diff a b)
          None l1 l2
  | Atom _, List _ ->
      Some "atom vs list"
  | List _, Atom _ ->
      Some "list vs atom"

and diff_fields l1 l2 =
  match (l1, l2) with
  | Atom k1 :: rest1, Atom k2 :: rest2 when k1 = k2 -> (
      let keyed1 = List.filter (fun f -> field_key f <> None) rest1 in
      let keyed2 = List.filter (fun f -> field_key f <> None) rest2 in
      (* Find fields in l1 missing from l2 *)
      let missing =
        List.find_opt
          (fun f1 ->
            match field_key f1 with
            | None ->
                false
            | Some k ->
                find_field k keyed2 = None
                && not (field_is_implied k keyed1 keyed2) )
          keyed1
      in
      match missing with
      | Some f ->
          Some
            (Printf.sprintf
               "field %s: present in generated but missing in original"
               (match field_key f with Some k -> k | None -> "?") )
      | None -> (
          (* Find fields in l2 missing from l1 *)
          let extra =
            List.find_opt
              (fun f2 ->
                match field_key f2 with
                | None ->
                    false
                | Some k ->
                    find_field k keyed1 = None
                    && not (field_is_implied k keyed2 keyed1) )
              keyed2
          in
          match extra with
          | Some f ->
              Some
                (Printf.sprintf
                   "field %s: missing in generated but present in original"
                   (match field_key f with Some k -> k | None -> "?") )
          | None ->
              (* All fields present, check values *)
              List.fold_left
                (fun acc f1 ->
                  match acc with
                  | Some _ ->
                      acc
                  | None -> (
                      match field_key f1 with
                      | None ->
                          None
                      | Some k -> (
                          match find_field k keyed2 with
                          | Some f2 ->
                              diff f1 f2
                          | None ->
                              None ) ) )
                None keyed1 ) )
  | _ ->
      if List.length l1 <> List.length l2 then
        Some
          (Printf.sprintf "stanza list length %d vs %d" (List.length l1)
             (List.length l2) )
      else None

and diff_set l1 l2 =
  match (l1, l2) with
  | Atom k1 :: rest1, Atom k2 :: rest2 when k1 = k2 -> (
      let s1 = sort_atoms rest1 in
      let s2 = sort_atoms rest2 in
      if List.length s1 <> List.length s2 then
        Some
          (Printf.sprintf "%s: %d vs %d items" k1 (List.length s1)
             (List.length s2) )
      else
        (* Find first element in s1 not in s2 *)
        let missing =
          List.find_opt (fun a -> not (List.exists (fun b -> equal a b) s2)) s1
        in
        match missing with
        | Some m ->
            Some
              (Printf.sprintf "%s: %s in generated but not in original" k1
                 (atom_name m) )
        | None -> (
            let extra =
              List.find_opt
                (fun b -> not (List.exists (fun a -> equal a b) s1))
                s2
            in
            match extra with
            | Some e ->
                Some
                  (Printf.sprintf "%s: %s in original but not in generated" k1
                     (atom_name e) )
            | None ->
                None ) )
  | _ ->
      None
