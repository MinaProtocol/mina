(* dhall_type.ml -- derive a Dhall type from an OCaml type *)

open Core_kernel

(* based on https://github.com/dhall-lang/dhall-lang/blob/master/standard/type-inference.md *)
type t =
  | Bool
  | Natural
  | Text
  | Integer
  | Double
  | Optional of t
  | List of t
  | Record of (string * t) list
  | Union of (string * t option) list
  | Function of t * t

let rec to_string = function
  | Bool ->
      "Bool"
  | Integer ->
      "Integer"
  | Natural ->
      "Natural"
  | Text ->
      "Text"
  | Double ->
      "Double"
  | Optional t ->
      "Optional (" ^ to_string t ^ ")"
  | List t ->
      "List (" ^ to_string t ^ ")"
  | Record fields ->
      let field_to_string (nm, ty) = nm ^ " : " ^ to_string ty in
      let formatted_fields =
        String.concat ~sep:", " (List.map fields ~f:field_to_string)
      in
      "{ " ^ formatted_fields ^ " }"
  | Union alts ->
      let alt_to_string (nm, ty_opt) =
        match ty_opt with None -> nm | Some ty -> nm ^ " : " ^ to_string ty
      in
      let formatted_alts =
        String.concat ~sep:" | " (List.map alts ~f:alt_to_string)
      in
      "< " ^ formatted_alts ^ " >"
  | Function (t_in, t_out) ->
      to_string t_in ^ " -> " ^ to_string t_out
