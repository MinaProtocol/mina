[%%import
"/src/config.mlh"]

open Ppxlib
open Asttypes
open Parsetree
open Longident
open Core
module Impl = Pickles.Impls.Pairing_based.Internal_Basic
module Group = Snarky_bn382_backend.G

let group_map_params =
  Group_map.Params.create
    (module Snarky_bn382_backend.Fp)
    Snarky_bn382_backend.G.Params.{a; b}

let group_map_params_structure ~loc =
  let module T = struct
    type t =
      Snarky_bn382_backend.Fp.Stable.Latest.t Group_map.Params.Stable.Latest.t
    [@@deriving bin_io_unversioned]
  end in
  let module E = Ppxlib.Ast_builder.Make (struct
    let loc = loc
  end) in
  let open E in
  [%str
    let params =
      lazy
        (let module T = struct
           type t = Snarky_bn382_backend.Fp.Stable.Latest.t Group_map.Params.t
           [@@deriving bin_io_unversioned]
         end in
        Core.Binable.of_string
          (module T)
          [%e estring (Core.Binable.to_string (module T) group_map_params)])]

let generate_ml_file filename structure =
  let fmt = Format.formatter_of_out_channel (Out_channel.create filename) in
  Pprintast.top_phrase fmt (Ptop_def (structure ~loc:Ppxlib.Location.none))

let () =
  generate_ml_file "group_map_params.ml" group_map_params_structure ;
  ignore (exit 0)
