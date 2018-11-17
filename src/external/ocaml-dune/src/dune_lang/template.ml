open! Stdune

include Types.Template

let var_enclosers = function
  | Percent      -> "%{", "}"
  | Dollar_brace -> "${", "}"
  | Dollar_paren -> "$(", ")"

module Pp : sig
  val to_string : t -> syntax:Syntax.t -> string
end = struct
  let buf = Buffer.create 16

  let add_var { loc = _; syntax; name; payload } =
    let before, after = var_enclosers syntax in
    Buffer.add_string buf before;
    Buffer.add_string buf name;
    begin match payload with
    | None -> ()
    | Some payload ->
      Buffer.add_char buf ':';
      Buffer.add_string buf payload
    end;
    Buffer.add_string buf after

  (* TODO use the loc for the error *)
  let check_valid_unquoted s ~syntax ~loc:_ =
    if not (Atom.is_valid (Atom.of_string s) syntax) then
      Printf.ksprintf invalid_arg "Invalid text %S in unquoted template" s

  let to_string { parts; quoted; loc } ~syntax =
    Buffer.clear buf;
    if quoted then Buffer.add_char buf '"';
    let commit_text s =
      if s = "" then
        ()
      else if not quoted then begin
        check_valid_unquoted ~loc ~syntax s;
        Buffer.add_string buf s
      end else
        Buffer.add_string buf (Escape.escaped ~syntax s)
    in
    let rec add_parts acc_text = function
      | [] ->
        commit_text acc_text
      | Text s :: rest ->
        add_parts (if acc_text = "" then s else acc_text ^ s) rest
      | Var v :: rest ->
        commit_text acc_text;
        add_var v;
        add_parts "" rest
    in
    add_parts "" parts;
    if quoted then Buffer.add_char buf '"';
    Buffer.contents buf
end

let to_string = Pp.to_string

let string_of_var { loc = _; syntax; name; payload } =
  let before, after = var_enclosers syntax in
  match payload with
  | None -> before ^ name ^ after
  | Some p -> before ^ name ^ ":" ^ p ^ after

let pp syntax ppf t =
  Format.pp_print_string ppf (Pp.to_string ~syntax t)

let pp_split_strings ppf (t : t) =
  let syntax = Syntax.Dune in
  if t.quoted || List.exists t.parts ~f:(function
    | Text s -> String.contains s '\n'
    | Var _ -> false) then begin
    List.iter t.parts ~f:(function
      | Var s ->
        Format.pp_print_string ppf (string_of_var s)
      | Text s ->
        begin match String.split s ~on:'\n' with
        | [] -> assert false
        | [s] -> Format.pp_print_string ppf (Escape.escaped ~syntax s)
        | split ->
          Format.pp_print_list
            ~pp_sep:(fun ppf () -> Format.fprintf ppf "@,\\n")
            Format.pp_print_string ppf
            split
        end
    );
    Format.fprintf ppf "@}\"@]"
  end
  else
    pp syntax ppf t

let remove_locs t =
  { t with
    loc = Loc.none
  ; parts =
      List.map t.parts ~f:(function
        | Var v -> Var { v with loc = Loc.none }
        | Text _ as s -> s)
  }
