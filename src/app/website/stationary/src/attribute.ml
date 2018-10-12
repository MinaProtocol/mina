open Core

type t = string * string
  [@@deriving sexp]

module Input_type = struct
  type t =
    | Text
    | Email

  let to_string = function
    | Text -> "text"
    | Email -> "email"
end

let to_string (k, v) = sprintf "%s=\"%s\"" k (String.escaped v)

let create k v = (k, v)

let class_ c = create "class" c

let href url = create "href" url

let src url = create "src" url

let type_ t = create "type" (Input_type.to_string t)

let placeholder = create "placeholder"
