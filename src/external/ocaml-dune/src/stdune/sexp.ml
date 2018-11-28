module Array = ArrayLabels
module List = ListLabels
module String = StringLabels

type t =
  | Atom of string
  | List of t list

(* XXX otherwise the dependency isn't recorded by bootstrap *)
module Sexp_intf = Sexp_intf

module Encoder = struct
  type sexp = t
  type 'a t = 'a -> sexp

  let unit () = List []
  let string s = Atom s
  let int i = Atom (string_of_int i)
  let float f = Atom (string_of_float f)
  let bool b = Atom (string_of_bool b)
  let pair fa fb (a, b) = List [fa a; fb b]
  let triple fa fb fc (a, b, c) = List [fa a; fb b; fc c]
  let list f l = List (List.map l ~f)
  let array f a = list f (Array.to_list a)
  let option f = function
    | None -> List []
    | Some x -> List [f x]

  let record l =
    List (List.map l ~f:(fun (n, v) -> List [Atom n; v]))

  let unknown _ = Atom "<unknown>"

  let constr name = function
    | [] -> Atom name
    | args -> List (Atom name :: args)
end

let rec to_string = function
  | Atom s -> Escape.quote_if_needed s
  | List l ->
    Printf.sprintf "(%s)"
      (List.map ~f:to_string l
       |> String.concat ~sep:" ")

let rec pp ppf = function
  | Atom s ->
    Format.pp_print_string ppf (Escape.quote_if_needed s)
  | List [] ->
    Format.pp_print_string ppf "()"
  | List (first :: rest) ->
    Format.pp_open_box ppf 1;
    Format.pp_print_string ppf "(";
    Format.pp_open_hvbox ppf 0;
    pp ppf first;
    List.iter rest ~f:(fun sexp ->
      Format.pp_print_space ppf ();
      pp ppf sexp);
    Format.pp_close_box ppf ();
    Format.pp_print_string ppf ")";
    Format.pp_close_box ppf ()
