open Stdune

exception Invalid_lib_name of string

let encode = Dune_lang.Encoder.string
let decode = Dune_lang.Decoder.string

module Local = struct
  type t = string

  type result =
    | Ok of t
    | Warn of t
    | Invalid

  let valid_char = function
    | 'A'..'Z' | 'a'..'z' | '_' | '0'..'9' -> true
    | _ -> false

  let of_string (name : string) =
    match name with
    | "" -> Invalid
    | (s : string) ->
      if s.[0] = '.' then
        Invalid
      else
        let len = String.length s in
        let rec loop warn i =
          if i = len - 1 then
            if warn then Warn s else Ok s
          else
            let c = String.unsafe_get s i in
            if valid_char c then
              loop warn (i + 1)
            else if c = '.' then
              loop true (i + 1)
            else
              Invalid
        in
        loop false 0

  let of_string_exn s =
    match of_string s with
    | Ok s -> s
    | Warn _
    | Invalid -> raise (Invalid_lib_name s)

  let decode_loc =
    Dune_lang.Decoder.plain_string (fun ~loc s -> (loc, of_string s))

  let encode = Dune_lang.Encoder.string

  let to_sexp = Sexp.Encoder.string

  let pp_quoted fmt t = Format.fprintf fmt "%S" t
  let pp fmt t = Format.fprintf fmt "%s" t

  let invalid_message =
    "invalid library name.\n\
     Hint: library names must be non-empty and composed only of \
     the following characters: 'A'..'Z',  'a'..'z', '_'  or '0'..'9'"

  let wrapped_message =
    sprintf
      "%s.\n\
       This is temporary allowed for libraries with (wrapped false).\
       \nIt will not be supported in the future. \
       Please choose a valid name field."
      invalid_message

  let validate (loc, res) ~wrapped =
    match res, wrapped with
    | Ok s, _ -> s
    | Warn _, true -> Errors.fail loc "%s" wrapped_message
    | Warn s, false -> Errors.warn loc "%s" wrapped_message; s
    | Invalid, _ -> Errors.fail loc "%s" invalid_message

  let to_string s = s
end

let split t =
  match String.split t ~on:'.' with
  | [] -> assert false
  | pkg :: rest -> (Package.Name.of_string pkg, rest)

let pp = Format.pp_print_string

let pp_quoted fmt t = Format.fprintf fmt "%S" t

let compare = String.compare

let to_local = Local.of_string

let to_sexp t = Sexp.Atom t

let to_string t = t

let of_string_exn ~loc:_ s = s

let of_local (_loc, t) = t

type t = string

module Map = Map.Make(String)
module Set = struct
  include Set.Make(String)

  let to_string_list = to_list
end

let root_lib t =
  match String.lsplit2 t ~on:'.' with
  | None -> t
  | Some (p, _) -> p

let package_name t =
  Package.Name.of_string (root_lib t)

let nest x y = sprintf "%s.%s" x y
