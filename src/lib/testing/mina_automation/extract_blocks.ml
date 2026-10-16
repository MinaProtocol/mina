(**
Module to run extract_blocks utility for given archive PostgreSQL database.
*)

open Core

module Config = struct
  type range = AllBlocks | Range of (String.t * String.t)

  type t =
    { archive_uri : String.t
    ; range : range
    ; output_folder : String.t option
    ; network : String.t option
    ; include_block_height_in_name : bool
    }

  let to_args t =
    let blocks =
      match t.range with
      | AllBlocks ->
          [ "--all-blocks" ]
      | Range (start_hash, end_hash) ->
          [ "--start-hash"; start_hash; "--end-hash"; end_hash ]
    in
    let maybe_output_folder =
      match t.output_folder with
      | Some folder ->
          [ "--output-folder"; folder ]
      | None ->
          []
    in
    let maybe_network =
      match t.network with
      | Some network ->
          [ "--network"; network ]
      | None ->
          []
    in
    let maybe_include_block_height_in_name =
      match t.include_block_height_in_name with
      | true ->
          [ "--include-block-height-in-name" ]
      | false ->
          []
    in

    [ "--archive-uri"; t.archive_uri ]
    @ maybe_output_folder @ maybe_network @ maybe_include_block_height_in_name
    @ blocks
end

module Paths = struct
  let dune_name = "src/app/extract_blocks/extract_blocks.exe"

  let official_name = "mina-extract-blocks"
end

module Executor = Executor.Make (Paths)

type t = Executor.t

let default = Executor.AutoDetect

let run t ~config = Executor.run t ~args:(Config.to_args config) ()
