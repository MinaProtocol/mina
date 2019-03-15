open Core_kernel

module Ast = struct
  type value = Bool of bool | String of string | Int of int

  let bool x = Bool x

  let string x = String x

  let int x = Int x

  type value_exp =
    | Value_lit of value
    | Value_access_string of string
    | Value_access_int of int

  let value_lit x = Value_lit x

  let value_access_string x = Value_access_string x

  let value_access_int x = Value_access_int x

  type cmp_exp =
    | Cmp_eq of value_exp * value_exp
    | Cmp_neq of value_exp * value_exp

  let cmp_eq x y = Cmp_eq (x, y)

  let cmp_neq x y = Cmp_neq (x, y)

  type bool_exp =
    | Bool_lit of bool
    | Bool_cmp of cmp_exp
    | Bool_not of bool_exp
    | Bool_and of bool_exp * bool_exp
    | Bool_or of bool_exp * bool_exp

  let bool_lit x = Bool_lit x

  let bool_cmp x = Bool_cmp x

  let bool_not x = Bool_not x

  let bool_and x y = Bool_and (x, y)

  let bool_or x y = Bool_or (x, y)

  type t = bool_exp
end

module Parser = struct
  open Angstrom

  let is_whitespace = function ' ' | '\n' -> true | _ -> false

  let is_alpha = function 'a' .. 'z' | 'A' .. 'Z' | '_' -> true | _ -> false

  let is_numeric = function '0' .. '9' -> true | _ -> false

  let parens = (char '(', char ')')

  let brackets = (char '[', char ']')

  let ws = skip_while is_whitespace

  (* let ws1 = satisfy is_whitespace *> ws *)
  let alpha_char = satisfy is_alpha

  let numeric_char = satisfy is_numeric

  let pad b p = b *> p <* b

  let wrap (l, r) p = l *> p <* r

  let maybe p = p >>| Option.some <|> return None

  (* string w/ commit on first char *)
  let stringc s =
    assert (String.length s > 0) ;
    let h = s.[0] in
    let t = String.sub s ~pos:1 ~len:(String.length s - 1) in
    lift2 (fun h' t' -> String.of_char h' ^ t') (char h <* commit) (string t)

  let infix p op =
    p
    >>= fun l -> maybe op >>= function Some f -> p >>| f l | None -> return l

  let bool =
    choice [string "true" *> return true; string "false" *> return false]

  let int = take_while1 is_numeric >>| int_of_string

  let text_escape =
    choice (List.map ~f:char ['"'; '\\'; '/'; 'b'; 'n'; 'r'; 't'])
    >>| fun c -> String.of_char_list ['\\'; c]

  let text_component =
    let text_char = alpha_char <|> numeric_char >>| String.of_char in
    char '\\' *> text_escape <|> text_char

  let text = many text_component >>| String.concat ~sep:""

  (* let text1 = many1 text_component >>| String.concat ~sep:"" *)

  let ident =
    lift2
      (fun h t -> String.of_char_list (h :: t))
      alpha_char
      (many (alpha_char <|> numeric_char))

  let str = pad (char '"') text

  let literal = choice [bool >>| Ast.bool; int >>| Ast.int; str >>| Ast.string]

  let value_exp =
    choice
      [ literal >>| Ast.value_lit
      ; char '.' *> ident
        <|> wrap brackets (pad ws str)
        >>| Ast.value_access_string
      ; wrap brackets (pad ws int) >>| Ast.value_access_int ]
    <* commit

  let cmp_exp =
    choice
      [ lift2 Ast.cmp_eq (value_exp <* pad ws (stringc "===")) value_exp
      ; lift2 Ast.cmp_neq (value_exp <* pad ws (stringc "!==")) value_exp ]
    <* commit

  let bool_exp =
    fix (fun bool_exp ->
        let main =
          choice
            [ wrap parens (pad ws bool_exp)
            ; bool >>| Ast.bool_lit
            ; char '!' *> bool_exp >>| Ast.bool_not
            ; cmp_exp >>| Ast.bool_cmp ]
          <* commit
        in
        let infix_op =
          choice
            [ stringc "&&" *> return Ast.bool_and
            ; stringc "||" *> return Ast.bool_or ]
          <* commit
        in
        infix main infix_op )

  let parse = parse_string bool_exp
end

module Interpreter = struct
  open Ast

  let json_value = function
    | Bool b -> `Bool b
    | String s -> `String s
    | Int i -> `Int i

  let access_string json str =
    match json with
    | `Assoc ls -> List.Assoc.find ~equal:String.equal ls str
    | _ -> None

  let access_int json i =
    match json with `List ls -> List.nth ls i | _ -> None

  let interpret_value_exp json = function
    | Value_lit v -> Some (json_value v)
    | Value_access_string s -> access_string json s
    | Value_access_int i -> access_int json i

  let interpret_cmp_exp json = function
    | Cmp_eq (x, y) ->
        Option.map2
          (interpret_value_exp json x)
          (interpret_value_exp json y)
          ~f:( = )
        |> Option.value ~default:false
    | Cmp_neq (x, y) ->
        Option.map2
          (interpret_value_exp json x)
          (interpret_value_exp json y)
          ~f:( <> )
        |> Option.value ~default:false

  let rec interpret_bool_exp json = function
    | Bool_lit b -> b
    | Bool_cmp cmp -> interpret_cmp_exp json cmp
    | Bool_not x -> not (interpret_bool_exp json x)
    | Bool_and (x, y) -> interpret_bool_exp json x && interpret_bool_exp json y
    | Bool_or (x, y) -> interpret_bool_exp json x || interpret_bool_exp json y

  let matches filter json = interpret_bool_exp json filter
end
