open Core

(** [Visualization] is a set of tools that lets a client visualize complex data
    structures like the transition_frontier *)

let display_prefix_of_string string = String.prefix string 10

let display_short_sexp (type t) (module M : Sexpable.S with type t = t)
    (value : t) =
  value |> [%sexp_of: M.t] |> Sexp.to_string |> display_prefix_of_string

(* converts a json structure into a presentable node in a dot file *)
let rec to_dot (json : Yojson.Safe.t) =
  match json with
  | `Int value ->
      Int.to_string value
  | `String value | `Intlit value ->
      value
  | `Assoc values ->
      List.map values ~f:(fun (key, value) ->
          match value with
          | `Assoc subvalues ->
              sprintf !"{%s|{%s}}" key @@ to_dot (`Assoc subvalues)
          | subvalue ->
              sprintf !"%s:%s" key (to_dot subvalue) )
      |> String.concat ~sep:"|"
  | `List values | `Tuple values ->
      List.map values ~f:(fun value -> to_dot value) |> String.concat ~sep:"|"
  | `Float value ->
      Float.to_string value
  | `Bool value ->
      Bool.to_string value
  | `Variant (key, value) ->
      Option.value_map value ~default:key ~f:(fun some_value ->
          sprintf !"%s:%s" key (to_dot some_value) )
  | `Null ->
      "null"

module type Node_intf = sig
  type t

  type display [@@deriving yojson]

  val display : t -> display

  val equal : t -> t -> bool

  val hash : t -> int

  val compare : t -> t -> int

  val name : t -> string
end

(** Visualizes graph structures. Namely, it assumes that a node can be presented
    in a pretty json form. Using the json form, it interprets the json form
    into dot form using the function, to_dot *)
module Make_ocamlgraph (Node : Node_intf) = struct
  module G = Graph.Persistent.Digraph.ConcreteBidirectional (Node)
  include G

  include Graph.Graphviz.Dot (struct
    include G

    let graph_attributes _ = [`Rankdir `LeftToRight]

    let get_subgraph _ = None

    let default_vertex_attributes _ = [`Shape `Record]

    let vertex_name = Node.name

    let vertex_attributes node =
      let dot_format = to_dot @@ Node.display_to_yojson (Node.display node) in
      [`Label dot_format]

    let default_edge_attributes _ = []

    let edge_attributes _ = []
  end)
end
