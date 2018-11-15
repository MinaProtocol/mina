open! Stdune

module Atom = Atom
module Template = Template
module Syntax = Syntax

type syntax = Syntax.t = Jbuild | Dune

type t =
  | Atom of Atom.t
  | Quoted_string of string
  | List of t list
  | Template of Template.t

let atom_or_quoted_string s =
  if Atom.is_valid_dune s then
    Atom (Atom.of_string s)
  else
    Quoted_string s

let atom s = Atom (Atom.of_string s)

let unsafe_atom_of_string s = atom s

let rec to_string t ~syntax =
  match t with
  | Atom a -> Atom.print a syntax
  | Quoted_string s -> Escape.quoted s ~syntax
  | List l ->
    Printf.sprintf "(%s)" (List.map l ~f:(to_string ~syntax)
                           |> String.concat ~sep:" ")
  | Template t -> Template.to_string t ~syntax

let rec pp syntax ppf = function
  | Atom s ->
    Format.pp_print_string ppf (Atom.print s syntax)
  | Quoted_string s ->
    Format.pp_print_string ppf (Escape.quoted ~syntax s)
  | List [] ->
    Format.pp_print_string ppf "()"
  | List (first :: rest) ->
    Format.pp_open_box ppf 1;
    Format.pp_print_string ppf "(";
    Format.pp_open_hvbox ppf 0;
    pp syntax ppf first;
    List.iter rest ~f:(fun sexp ->
      Format.pp_print_space ppf ();
      pp syntax ppf sexp);
    Format.pp_close_box ppf ();
    Format.pp_print_string ppf ")";
    Format.pp_close_box ppf ()
  | Template t -> Template.pp syntax ppf t

let pp_quoted =
  let rec loop = function
    | Atom (A s) as t ->
      if Atom.is_valid_dune s then
        t
      else
        Quoted_string s
    | List xs -> List (List.map ~f:loop xs)
    | (Quoted_string _ | Template _) as t -> t
  in
  fun ppf t -> pp Dune ppf (loop t)

let pp_print_quoted_string ppf s =
  let syntax = Dune in
  if String.contains s '\n' then begin
    match String.split s ~on:'\n' with
    | [] -> Format.pp_print_string ppf (Escape.quoted ~syntax s)
    | first :: rest ->
       Format.fprintf ppf "@[<hv 1>\"@{<atom>%s"
         (Escape.escaped ~syntax first);
       List.iter rest ~f:(fun s ->
           Format.fprintf ppf "@,\\n%s" (Escape.escaped ~syntax s));
       Format.fprintf ppf "@}\"@]"
  end else
    Format.pp_print_string ppf (Escape.quoted ~syntax s)

let rec pp_split_strings ppf = function
  | Atom s -> Format.pp_print_string ppf (Atom.print s Syntax.Dune)
  | Quoted_string s -> pp_print_quoted_string ppf s
  | List [] ->
    Format.pp_print_string ppf "()"
  | List (first :: rest) ->
    Format.pp_open_box ppf 1;
    Format.pp_print_string ppf "(";
    Format.pp_open_hvbox ppf 0;
    pp_split_strings ppf first;
    List.iter rest ~f:(fun sexp ->
      Format.pp_print_space ppf ();
      pp_split_strings ppf sexp);
    Format.pp_close_box ppf ();
    Format.pp_print_string ppf ")";
    Format.pp_close_box ppf ()
  | Template t -> Template.pp_split_strings ppf t

type formatter_state =
  | In_atom
  | In_makefile_action
  | In_makefile_stuff

let prepare_formatter ppf =
  let state = ref [] in
  Format.pp_set_mark_tags ppf true;
  let ofuncs = Format.pp_get_formatter_out_functions ppf () in
  let tfuncs = Format.pp_get_formatter_tag_functions ppf () in
  Format.pp_set_formatter_tag_functions ppf
    { tfuncs with
      mark_open_tag  = (function
        | "atom" -> state := In_atom :: !state; ""
        | "makefile-action" -> state := In_makefile_action :: !state; ""
        | "makefile-stuff" -> state := In_makefile_stuff :: !state; ""
        | s -> tfuncs.mark_open_tag s)
    ; mark_close_tag = (function
        | "atom" | "makefile-action" | "makefile-stuff" -> state := List.tl !state; ""
        | s -> tfuncs.mark_close_tag s)
    };
  Format.pp_set_formatter_out_functions ppf
    { ofuncs with
      out_newline = (fun () ->
        match !state with
        | [In_atom; In_makefile_action] ->
          ofuncs.out_string "\\\n\t" 0 3
        | [In_atom] ->
          ofuncs.out_string "\\\n" 0 2
        | [In_makefile_action] ->
          ofuncs.out_string " \\\n\t" 0 4
        | [In_makefile_stuff] ->
          ofuncs.out_string " \\\n" 0 3
        | [] ->
          ofuncs.out_string "\n" 0 1
        | _ -> assert false)
    ; out_spaces = (fun n ->
        ofuncs.out_spaces
          (match !state with
           | In_atom :: _ -> max 0 (n - 2)
           | _ -> n))
    }

module Ast = struct
  type dune_lang = t
  type t =
    | Atom of Loc.t * Atom.t
    | Quoted_string of Loc.t * string
    | Template of Template.t
    | List of Loc.t * t list

  let atom_or_quoted_string loc s =
    match atom_or_quoted_string s with
    | Atom a -> Atom (loc, a)
    | Quoted_string s -> Quoted_string (loc, s)
    | Template _
    | List _ -> assert false

  let loc (Atom (loc, _) | Quoted_string (loc, _) | List (loc, _)
          | Template { loc ; _ }) = loc

  let rec remove_locs t : dune_lang =
    match t with
    | Template t -> Template (Template.remove_locs t)
    | Atom (_, s) -> Atom s
    | Quoted_string (_, s) -> Quoted_string s
    | List (_, l) -> List (List.map l ~f:remove_locs)
end

let rec add_loc t ~loc : Ast.t =
  match t with
  | Atom s -> Atom (loc, s)
  | Quoted_string s -> Quoted_string (loc, s)
  | List l -> List (loc, List.map l ~f:(add_loc ~loc))
  | Template t -> Template { t with loc }

module Parse_error = struct
  include Lexer.Error

  let loc t : Loc.t = { start = t.start; stop = t.stop }
  let message t = t.message
end
exception Parse_error = Lexer.Error

module Lexer = Lexer

module Parser = struct
  let error (loc : Loc.t) message =
    raise (Parse_error
             { start = loc.start
             ; stop  = loc.stop
             ; message
             })

  module Mode = struct
    type 'a t =
      | Single      : Ast.t t
      | Many        : Ast.t list t
      | Many_as_one : Ast.t t

    let make_result : type a. a t -> Lexing.lexbuf -> Ast.t list -> a
      = fun t lexbuf sexps ->
        match t with
        | Single -> begin
          match sexps with
          | [sexp] -> sexp
          | [] -> error (Loc.of_lexbuf lexbuf) "no s-expression found in input"
          | _ :: sexp :: _ ->
            error (Ast.loc sexp) "too many s-expressions found in input"
        end
        | Many -> sexps
        | Many_as_one ->
          match sexps with
          | [] -> List (Loc.in_file lexbuf.lex_curr_p.pos_fname, [])
          | x :: l ->
            let last = List.fold_left l ~init:x ~f:(fun _ x -> x) in
            let loc = { (Ast.loc x) with stop = (Ast.loc last).stop } in
            List (loc, x :: l)
  end

  let rec loop depth lexer lexbuf acc =
    match (lexer lexbuf : Lexer.Token.t) with
    | Atom a ->
      let loc = Loc.of_lexbuf lexbuf in
      loop depth lexer lexbuf (Ast.Atom (loc, a) :: acc)
    | Quoted_string s ->
      let loc = Loc.of_lexbuf lexbuf in
      loop depth lexer lexbuf (Quoted_string (loc, s) :: acc)
    | Template t ->
      let loc = Loc.of_lexbuf lexbuf in
      loop depth lexer lexbuf (Template { t with loc } :: acc)
    | Lparen ->
      let start = Lexing.lexeme_start_p lexbuf in
      let sexps = loop (depth + 1) lexer lexbuf [] in
      let stop = Lexing.lexeme_end_p lexbuf in
      loop depth lexer lexbuf (List ({ start; stop }, sexps) :: acc)
    | Rparen ->
      if depth = 0 then
        error (Loc.of_lexbuf lexbuf)
          "right parenthesis without matching left parenthesis";
      List.rev acc
    | Sexp_comment ->
      let sexps =
        let loc = Loc.of_lexbuf lexbuf in
        match loop depth lexer lexbuf [] with
        | _ :: sexps -> sexps
        | [] -> error loc "s-expression missing after #;"
      in
      List.rev_append acc sexps
    | Eof ->
      if depth > 0 then
        error (Loc.of_lexbuf lexbuf)
          "unclosed parenthesis at end of input";
      List.rev acc

  let parse ~mode ?(lexer=Lexer.token) lexbuf =
    loop 0 lexer lexbuf []
    |> Mode.make_result mode lexbuf
end

let parse_string ~fname ~mode ?lexer str =
  let lb = Lexing.from_string str in
  lb.lex_curr_p <-
    { pos_fname = fname
    ; pos_lnum  = 1
    ; pos_bol   = 0
    ; pos_cnum  = 0
    };
  Parser.parse ~mode ?lexer lb

type dune_lang = t

module Encoder = struct
  type nonrec 'a t = 'a -> t
  let unit () = List []
  let string = atom_or_quoted_string
  let int n = Atom (Atom.of_int n)
  let float f = Atom (Atom.of_float f)
  let bool b = Atom (Atom.of_bool b)
  let pair fa fb (a, b) = List [fa a; fb b]
  let triple fa fb fc (a, b, c) = List [fa a; fb b; fc c]
  let list f l = List (List.map l ~f)
  let array f a = list f (Array.to_list a)
  let option f = function
    | None -> List []
    | Some x -> List [f x]
  let record l =
    List (List.map l ~f:(fun (n, v) -> List [Atom(Atom.of_string n); v]))

  type field = string * dune_lang option

  let field name f ?(equal=(=)) ?default v =
    match default with
    | None -> (name, Some (f v))
    | Some d ->
      if equal d v then
        (name, None)
      else
        (name, Some (f v))
  let field_o name f v = (name, Option.map ~f v)

  let record_fields (l : field list) =
    List (List.filter_map l ~f:(fun (k, v) ->
      Option.map v ~f:(fun v -> List[Atom (Atom.of_string k); v])))

  let unknown _ = unsafe_atom_of_string "<unknown>"
end

module Decoder = struct
  type ast = Ast.t =
    | Atom of Loc.t * Atom.t
    | Quoted_string of Loc.t * string
    | Template of Template.t
    | List of Loc.t * ast list

  type hint =
    { on: string
    ; candidates: string list
    }

  exception Decoder of Loc.t * string * hint option

  let of_sexp_error ?hint loc msg =
    raise (Decoder (loc, msg, hint))
  let of_sexp_errorf ?hint loc fmt =
    Printf.ksprintf (fun msg -> of_sexp_error loc ?hint msg) fmt
  let no_templates ?hint loc fmt =
    Printf.ksprintf (fun msg ->
      of_sexp_error loc ?hint ("No variables allowed " ^ msg)) fmt

  type unparsed_field =
    { values : Ast.t list
    ; entry  : Ast.t
    ; prev   : unparsed_field option (* Previous occurrence of this field *)
    }

  module Name = struct
    type t = string
    let compare a b =
      let alen = String.length a and blen = String.length b in
      match Int.compare alen blen with
      | Eq -> String.compare a b
      | ne -> ne
  end

  module Name_map = Map.Make(Name)

  type values = Ast.t list
  type fields =
    { unparsed : unparsed_field Name_map.t
    ; known    : string list
    }

  (* Arguments are:

     - the location of the whole list
     - the first atom when parsing a constructor or a field
     - the universal map holding the user context
  *)
  type 'kind context =
    | Values : Loc.t * string option * Univ_map.t -> values context
    | Fields : Loc.t * string option * Univ_map.t -> fields context

  type ('a, 'kind) parser =  'kind context -> 'kind -> 'a * 'kind

  type 'a t             = ('a, values) parser
  type 'a fields_parser = ('a, fields) parser

  let return x _ctx state = (x, state)
  let (>>=) t f ctx state =
    let x, state = t ctx state in
    f x ctx state
  let (>>|) t f ctx state =
    let x, state = t ctx state in
    (f x, state)
  let (>>>) a b ctx state =
    let (), state = a ctx state in
    b ctx state
  let map t ~f = t >>| f

  let try_ t f ctx state =
    try
      t ctx state
    with exn ->
      f exn ctx state

  let get_user_context : type k. k context -> Univ_map.t = function
    | Values (_, _, uc) -> uc
    | Fields (_, _, uc) -> uc

  let get key ctx state = (Univ_map.find (get_user_context ctx) key, state)
  let get_all ctx state = (get_user_context ctx, state)

  let set : type a b k. a Univ_map.Key.t -> a -> (b, k) parser -> (b, k) parser
    = fun key v t ctx state ->
      match ctx with
      | Values (loc, cstr, uc) ->
        t (Values (loc, cstr, Univ_map.add uc key v)) state
      | Fields (loc, cstr, uc) ->
        t (Fields (loc, cstr, Univ_map.add uc key v)) state

  let set_many : type a k. Univ_map.t -> (a, k) parser -> (a, k) parser
    = fun map t ctx state ->
      match ctx with
      | Values (loc, cstr, uc) ->
        t (Values (loc, cstr, Univ_map.superpose uc map)) state
      | Fields (loc, cstr, uc) ->
        t (Fields (loc, cstr, Univ_map.superpose uc map)) state

  let loc : type k. k context -> k -> Loc.t * k = fun ctx state ->
    match ctx with
    | Values (loc, _, _) -> (loc, state)
    | Fields (loc, _, _) -> (loc, state)

  let at_eos : type k. k context -> k -> bool = fun ctx state ->
    match ctx with
    | Values _ -> state = []
    | Fields _ -> Name_map.is_empty state.unparsed

  let eos ctx state = (at_eos ctx state, state)

  let if_eos ~then_ ~else_ ctx state =
    if at_eos ctx state then
      then_ ctx state
    else
      else_ ctx state

  let repeat : 'a t -> 'a list t =
    let rec loop t acc ctx l =
      match l with
      | [] -> (List.rev acc, [])
      | _ ->
        let x, l = t ctx l in
        loop t (x :: acc) ctx l
    in
    fun t ctx state -> loop t [] ctx state

  let result : type a k. k context -> a * k -> a =
    fun ctx (v, state) ->
      match ctx with
      | Values (_, cstr, _) -> begin
          match state with
          | [] -> v
          | sexp :: _ ->
            match cstr with
            | None ->
              of_sexp_errorf (Ast.loc sexp) "This value is unused"
            | Some s ->
              of_sexp_errorf (Ast.loc sexp) "Too many argument for %s" s
        end
      | Fields _ -> begin
          match Name_map.choose state.unparsed with
          | None -> v
          | Some (name, { entry; _ }) ->
            let name_loc =
              match entry with
              | List (_, s :: _) -> Ast.loc s
              | _ -> assert false
            in
            of_sexp_errorf ~hint:{ on = name; candidates = state.known }
              name_loc "Unknown field %s" name
        end

  let parse t context sexp =
    let ctx = Values (Ast.loc sexp, None, context) in
    result ctx (t ctx [sexp])

  let capture ctx state =
    let f t =
      result ctx (t ctx state)
    in
    (f, [])

  let end_of_list (Values (loc, cstr, _)) =
    match cstr with
    | None ->
      let loc = { loc with start = loc.stop } in
      of_sexp_errorf loc "Premature end of list"
    | Some s ->
      of_sexp_errorf loc "Not enough arguments for %s" s
  [@@inline never]

  let next f ctx sexps =
    match sexps with
    | [] -> end_of_list ctx
    | sexp :: sexps -> (f sexp, sexps)
  [@@inline always]

  let next_with_user_context f ctx sexps =
    match sexps with
    | [] -> end_of_list ctx
    | sexp :: sexps -> (f (get_user_context ctx) sexp, sexps)
  [@@inline always]

  let peek _ctx sexps =
    match sexps with
    | [] -> (None, sexps)
    | sexp :: _ -> (Some sexp, sexps)
  [@@inline always]

  let peek_exn ctx sexps =
    match sexps with
    | [] -> end_of_list ctx
    | sexp :: _ -> (sexp, sexps)
  [@@inline always]

  let junk = next ignore

  let junk_everything : type k. (unit, k) parser = fun ctx state ->
    match ctx with
    | Values _ -> ((), [])
    | Fields _ -> ((), { state with unparsed = Name_map.empty })

  let keyword kwd =
    next (function
      | Atom (_, s) when Atom.to_string s = kwd -> ()
      | sexp -> of_sexp_errorf (Ast.loc sexp) "'%s' expected" kwd)

  let match_keyword l ~fallback =
    peek >>= function
    | Some (Atom (_, A s)) -> begin
        match List.assoc l s with
        | Some t -> junk >>> t
        | None -> fallback
      end
    | _ -> fallback

  let until_keyword kwd ~before ~after =
    let rec loop acc =
      peek >>= function
      | None -> return (List.rev acc, None)
      | Some (Atom (_, A s)) when s = kwd ->
        junk >>> after >>= fun x ->
        return (List.rev acc, Some x)
      | _ ->
        before >>= fun x ->
        loop (x :: acc)
    in
    loop []

  let plain_string f =
    next (function
      | Atom (loc, A s) | Quoted_string (loc, s) -> f ~loc s
      | Template { loc ; _ } | List (loc, _) ->
        of_sexp_error loc "Atom or quoted string expected")

  let enter t =
    next_with_user_context (fun uc sexp ->
      match sexp with
      | List (loc, l) ->
        let ctx = Values (loc, None, uc) in
        result ctx (t ctx l)
      | sexp ->
        of_sexp_error (Ast.loc sexp) "List expected")

  let if_list ~then_ ~else_ =
    peek_exn >>= function
    | List _ -> then_
    | _ -> else_

  let if_paren_colon_form ~then_ ~else_ =
    peek_exn >>= function
    | List (_, Atom (loc, A s) :: _) when String.is_prefix s ~prefix:":" ->
      let name = String.drop s 1 in
      enter
        (junk >>= fun () ->
         then_ >>| fun f ->
         f (loc, name))
    | _ ->
      else_

  let fix f =
    let rec p = lazy (f r)
    and r ast = (Lazy.force p) ast in
    r

  let loc_between_states : type k. k context -> k -> k -> Loc.t
    = fun ctx state1 state2 ->
      match ctx with
      | Values _ -> begin
          match state1 with
          | sexp :: rest when rest == state2 -> (* common case *)
            Ast.loc sexp
          | [] ->
            let (Values (loc, _, _)) = ctx in
            { loc with start = loc.stop }
          | sexp :: rest ->
            let loc = Ast.loc sexp in
            let rec search last l =
              if l == state2 then
                { loc with stop = (Ast.loc last).stop }
              else
                match l with
                | [] ->
                  let (Values (loc, _, _)) = ctx in
                  { (Ast.loc sexp) with stop = loc.stop }
                | sexp :: rest ->
                  search sexp rest
            in
            search sexp rest
        end
      | Fields _ ->
        let parsed =
          Name_map.merge state1.unparsed state2.unparsed
            ~f:(fun _key before after ->
              match before, after with
              | Some _, None -> before
              | _ -> None)
        in
        match
          Name_map.values parsed
          |> List.map ~f:(fun f -> Ast.loc f.entry)
          |> List.sort ~compare:(fun a b ->
            Int.compare a.Loc.start.pos_cnum b.start.pos_cnum)
        with
        | [] ->
          let (Fields (loc, _, _)) = ctx in
          loc
        | first :: l ->
          let last = List.fold_left l ~init:first ~f:(fun _ x -> x) in
          { first with stop = last.stop }

  let located t ctx state1 =
    let x, state2 = t ctx state1 in
    ((loc_between_states ctx state1 state2, x), state2)

  let raw = next (fun x -> x)

  let unit =
    next
      (function
        | List (_, []) -> ()
        | sexp -> of_sexp_error (Ast.loc sexp) "() expected")

  let basic desc f =
    next (function
      | Template { loc; _ } | List (loc, _) | Quoted_string (loc, _) ->
        of_sexp_errorf loc "%s expected" desc
      | Atom (loc, s)  ->
        match f (Atom.to_string s) with
        | Result.Error () ->
          of_sexp_errorf loc "%s expected" desc
        | Ok x -> x)

  let string = plain_string (fun ~loc:_ x -> x)
  let int =
    basic "Integer" (fun s ->
      match int_of_string s with
      | x -> Ok x
      | exception _ -> Result.Error ())

  let float =
    basic "Float" (fun s ->
      match float_of_string s with
      | x -> Ok x
      | exception _ -> Result.Error ())

  let pair a b =
    enter
      (a >>= fun a ->
       b >>= fun b ->
       return (a, b))

  let triple a b c =
    enter
      (a >>= fun a ->
       b >>= fun b ->
       c >>= fun c ->
       return (a, b, c))

  let list t = enter (repeat t)

  let array t = list t >>| Array.of_list

  let option t =
    enter
      (eos >>= function
       | true -> return None
       | false -> t >>| Option.some)

  let find_cstr cstrs loc name ctx values =
    match List.assoc cstrs name with
    | Some t ->
      result ctx (t ctx values)
    | None ->
      of_sexp_errorf loc
        ~hint:{ on         = name
              ; candidates = List.map cstrs ~f:fst
              }
        "Unknown constructor %s" name

  let sum cstrs =
    next_with_user_context (fun uc sexp ->
      match sexp with
      | Atom (loc, A s) ->
        find_cstr cstrs loc s (Values (loc, Some s, uc)) []
      | Template { loc; _ }
      | Quoted_string (loc, _) ->
        of_sexp_error loc "Atom expected"
      | List (loc, []) ->
        of_sexp_error loc "Non-empty list expected"
      | List (loc, name :: args) ->
        match name with
        | Quoted_string (loc, _) | List (loc, _) | Template { loc; _ } ->
          of_sexp_error loc "Atom expected"
        | Atom (s_loc, A s) ->
          find_cstr cstrs s_loc s (Values (loc, Some s, uc)) args)

  let enum cstrs =
    next (function
      | Quoted_string (loc, _)
      | Template { loc; _ }
      | List (loc, _) -> of_sexp_error loc "Atom expected"
      | Atom (loc, A s) ->
        match List.assoc cstrs s with
        | Some value -> value
        | None ->
          of_sexp_errorf loc
            ~hint:{ on         = s
                  ; candidates = List.map cstrs ~f:fst
                  }
            "Unknown value %s" s)

  let bool = enum [ ("true", true); ("false", false) ]

  let consume name state =
    { unparsed = Name_map.remove state.unparsed name
    ; known    = name :: state.known
    }

  let add_known name state =
    { state with known = name :: state.known }

  let map_validate t ~f ctx state1 =
    let x, state2 = t ctx state1 in
    match f x with
    | Result.Ok x -> (x, state2)
    | Error msg ->
      let loc = loc_between_states ctx state1 state2 in
      of_sexp_errorf loc "%s" msg

  let field_missing loc name =
    of_sexp_errorf loc "field %s missing" name
  [@@inline never]

  let field_present_too_many_times _ name entries =
    match entries with
    | _ :: second :: _ ->
      of_sexp_errorf (Ast.loc second) "Field %S is present too many times"
        name
    | _ -> assert false

  let multiple_occurrences ?(on_dup=field_present_too_many_times) uc name last =
    let rec collect acc x =
      let acc = x.entry :: acc in
      match x.prev with
      | None -> acc
      | Some prev -> collect acc prev
    in
    on_dup uc name (collect [] last)
  [@@inline never]

  let find_single ?on_dup uc state name =
    let res = Name_map.find state.unparsed name in
    (match res with
     | Some ({ prev = Some _; _ } as last) ->
       multiple_occurrences uc name last ?on_dup
     | _ -> ());
    res

  let field name ?default ?on_dup t (Fields (loc, _, uc)) state =
    match find_single uc state name ?on_dup  with
    | Some { values; entry; _ } ->
      let ctx = Values (Ast.loc entry, Some name, uc) in
      let x = result ctx (t ctx values) in
      (x, consume name state)
    | None ->
      match default with
      | Some v -> (v, add_known name state)
      | None -> field_missing loc name

  let field_o name ?on_dup t (Fields (_, _, uc)) state =
    match find_single uc state name ?on_dup with
    | Some { values; entry; _ } ->
      let ctx = Values (Ast.loc entry, Some name, uc) in
      let x = result ctx (t ctx values) in
      (Some x, consume name state)
    | None ->
      (None, add_known name state)

  let field_b_gen field_gen ?check ?on_dup name =
    field_gen name ?on_dup
      (Option.value check ~default:(return ()) >>= fun () ->
       eos >>= function
       | true -> return true
       | _ -> bool)

  let field_b = field_b_gen (field ~default:false)
  let field_o_b = field_b_gen field_o

  let multi_field name t (Fields (_, _, uc)) state =
    let rec loop acc field =
      match field with
      | None -> acc
      | Some { values; prev; entry } ->
        let ctx = Values (Ast.loc entry, Some name, uc) in
        let x = result ctx (t ctx values) in
        loop (x :: acc) prev
    in
    let res = loop [] (Name_map.find state.unparsed name) in
    (res, consume name state)

  let fields t (Values (loc, cstr, uc)) sexps =
    let unparsed =
      List.fold_left sexps ~init:Name_map.empty ~f:(fun acc sexp ->
        match sexp with
        | List (_, name_sexp :: values) -> begin
            match name_sexp with
            | Atom (_, A name) ->
              Name_map.add acc name
                { values
                ; entry = sexp
                ; prev  = Name_map.find acc name
                }
            | List (loc, _) | Quoted_string (loc, _) | Template { loc; _ } ->
              of_sexp_error loc "Atom expected"
          end
        | _ ->
          of_sexp_error (Ast.loc sexp)
            "S-expression of the form (<name> <values>...) expected")
    in
    let ctx = Fields (loc, cstr, uc) in
    let x = result ctx (t ctx { unparsed; known = [] }) in
    (x, [])

  let record t = enter (fields t)

  type kind =
    | Values of Loc.t * string option
    | Fields of Loc.t * string option

  let kind : type k. k context -> k -> kind * k
    = fun ctx state ->
      match ctx with
      | Values (loc, cstr, _) -> (Values (loc, cstr), state)
      | Fields (loc, cstr, _) -> (Fields (loc, cstr), state)

  module Let_syntax = struct
    let ( $ ) f t =
      f >>= fun f ->
      t >>| fun t ->
      f t
    let const = return
  end
end

module type Conv = sig
  type t
  val decode : t Decoder.t
  val encode : t Encoder.t
end

let rec to_sexp = function
  | Atom (A a) -> Sexp.Atom a
  | List s -> List (List.map s ~f:to_sexp)
  | Quoted_string s -> Sexp.Atom s
  | Template t ->
    List
      [ Atom "template"
      ; Atom (Template.to_string ~syntax:Dune t)
      ]

module Io = struct
  let load ?lexer path ~mode =
    Io.with_lexbuf_from_file path ~f:(Parser.parse ~mode ?lexer)
end
