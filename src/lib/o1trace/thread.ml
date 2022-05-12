open Core
open Async

type t = { name : string; mutable state : Univ_map.t } [@@deriving sexp_of]

type thread = t [@@deriving sexp_of]

module Graph = struct
  module G = Graph.Imperative.Digraph.Concrete (String)
  include G

  include Graph.Graphviz.Dot (struct
    include G

    let graph_attributes _ = [ `Rankdir `LeftToRight ]

    let default_vertex_attributes _ = []

    let vertex_name = Fn.id

    let vertex_attributes _ = []

    let get_subgraph _ = None

    let default_edge_attributes _ = []

    let edge_attributes _ = []
  end)
end

(* TODO: could combine these into a single data structure with custom thread comparator, but I don't care enough *)
let graph = Graph.create ()

let threads : t String.Table.t = String.Table.create ()

let register name =
  match Hashtbl.find threads name with
  | Some thread ->
      thread
  | None ->
      let thread = { name; state = Univ_map.empty } in
      Hashtbl.set threads ~key:name ~data:thread ;
      Graph.add_vertex graph name ;
      thread

let name { name; _ } = name

let load_state thread id = Univ_map.find thread.state id

let set_state thread id value =
  thread.state <- Univ_map.set thread.state id value

let iter_threads ~f = Hashtbl.iter threads ~f

let dump_thread_graph () =
  let buf = Buffer.create 1024 in
  Graph.fprint_graph (Format.formatter_of_buffer buf) graph ;
  Stdlib.Buffer.to_bytes buf

module Fiber = struct
  include Hashable.Make (struct
    type t = string list [@@deriving compare, hash, sexp]
  end)

  let next_id = ref 1

  type t = { id : int; parent : t option; thread : thread } [@@deriving sexp_of]

  let ctx_id : t Type_equal.Id.t = Type_equal.Id.create ~name:"fiber" sexp_of_t

  let fibers : t Table.t = Table.create ()

  let rec fiber_key name parent =
    name
    :: Option.value_map parent ~default:[] ~f:(fun p ->
           fiber_key p.thread.name p.parent )

  let register name parent =
    let key = fiber_key name parent in
    match Hashtbl.find fibers key with
    | Some fiber ->
        fiber
    | None ->
        let thread = register name in
        let fiber = { id = !next_id; parent; thread } in
        incr next_id ;
        Hashtbl.set fibers ~key ~data:fiber ;
        Option.iter parent ~f:(fun p -> Graph.add_edge graph p.thread.name name) ;
        fiber

  let apply_to_context t ctx =
    let ctx = Execution_context.with_tid ctx t.id in
    Execution_context.with_local ctx ctx_id (Some t)

  let of_context ctx = Execution_context.find_local ctx ctx_id
end

let of_context ctx =
  let%map.Option fiber = Fiber.of_context ctx in
  fiber.thread
