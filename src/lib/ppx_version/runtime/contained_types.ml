(* contained_types.ml -- registry of versioned types contained in versioned types *)

open Core_kernel

type path = string

module Contained_type_tbl = Hashtbl.Make (Base.String)

let contained_type_tbl : path list Contained_type_tbl.t =
  Contained_type_tbl.create ()

let find path_to_type = Contained_type_tbl.find contained_type_tbl path_to_type

let iteri ~f = Contained_type_tbl.iteri contained_type_tbl ~f

let register ~(path_to_type : string) ~(contained_type_paths : string list) =
  Contained_type_tbl.add contained_type_tbl ~key:path_to_type
    ~data:contained_type_paths
  |> ignore
