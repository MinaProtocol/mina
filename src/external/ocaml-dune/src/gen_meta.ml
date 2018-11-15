open! Stdune
open Import
open Meta

module Pub_name = struct
  type t =
    | Dot of t * string
    | Id  of string

  let parse s =
    let s = Lib_name.to_string s in
    match String.split s ~on:'.' with
    | [] -> assert false
    | x :: l ->
      let rec loop acc l =
        match l with
        | [] -> acc
        | x :: l -> loop (Dot (acc, x)) l
      in
      loop (Id x) l

  let rec root = function
    | Dot (t, _) -> root t
    | Id n       -> n

  let to_list =
    let rec loop acc = function
      | Dot (t, n) -> loop (n :: acc) t
      | Id n       -> n :: acc
    in
    fun t -> loop [] t

  let to_string t = String.concat ~sep:"." (to_list t)
end

let string_of_deps deps =
  Lib_name.Set.to_string_list deps
  |> String.concat ~sep:" "

let rule var predicates action value =
  Rule { var; predicates; action; value }
let requires ?(preds=[]) pkgs =
  rule "requires" preds Set (string_of_deps pkgs)
let ppx_runtime_deps ?(preds=[]) pkgs =
  rule "ppx_runtime_deps" preds Set (string_of_deps pkgs)
let description s = rule "description" []      Set s
let directory   s = rule "directory"   []      Set s
let archive preds s = rule "archive"   preds Set s
let plugin preds  s = rule "plugin"    preds Set s
let archives ?(preds=[]) lib =
  let archives = Lib.archives lib in
  let plugins  = Lib.plugins  lib in
  let make ps =
    String.concat ~sep:" " (List.map ps ~f:Path.basename)
  in
  [ archive (preds @ [Pos "byte"  ]) (make archives.byte  )
  ; archive (preds @ [Pos "native"]) (make archives.native)
  ; plugin  (preds @ [Pos "byte"  ]) (make plugins .byte  )
  ; plugin  (preds @ [Pos "native"]) (make plugins .native)
  ]

let gen_lib pub_name lib ~version =
  let desc =
    match Lib.synopsis lib with
    | Some s -> s
    | None ->
      (* CR-someday jdimino: wut? this looks old *)
      match (pub_name : Pub_name.t) with
      | Dot (p, "runtime-lib") ->
        sprintf "Runtime library for %s" (Pub_name.to_string p)
      | Dot (p, "expander") ->
        sprintf "Expander for %s" (Pub_name.to_string p)
      | _ -> ""
  in
  let preds =
    match Lib.kind lib with
    | Normal -> []
    | Ppx_rewriter | Ppx_deriver -> [Pos "ppx_driver"]
  in
  let lib_deps    = Lib.Meta.requires lib in
  let ppx_rt_deps = Lib.Meta.ppx_runtime_deps lib in
  List.concat
    [ version
    ; [ description desc
      ; requires ~preds lib_deps
      ]
    ; archives ~preds lib
    ; if Lib_name.Set.is_empty ppx_rt_deps then
        []
      else
        [ Comment "This is what dune uses to find out the runtime \
                   dependencies of"
        ; Comment "a preprocessor"
        ; ppx_runtime_deps ppx_rt_deps
        ]
    ; (match Lib.kind lib with
       | Normal -> []
       | Ppx_rewriter | Ppx_deriver ->
         (* Deprecated ppx method support *)
         let no_ppx_driver = Neg "ppx_driver" and no_custom_ppx = Neg "custom_ppx" in
         List.concat
           [ [ Comment "This line makes things transparent for people mixing \
                        preprocessors"
             ; Comment "and normal dependencies"
             ; requires ~preds:[no_ppx_driver]
                 (Lib.Meta.ppx_runtime_deps_for_deprecated_method lib)
             ]
           ; match Lib.kind lib with
           | Normal -> assert false
           | Ppx_rewriter ->
             [ rule "ppx" [no_ppx_driver; no_custom_ppx]
                 Set "./ppx.exe --as-ppx" ]
           | Ppx_deriver ->
             [ rule "requires" [no_ppx_driver; no_custom_ppx] Add
                 "ppx_deriving"
             ; rule "ppxopt" [no_ppx_driver; no_custom_ppx] Set
                 ("ppx_deriving,package:" ^ Pub_name.to_string pub_name)
             ]
           ]
      )
    ; (match Lib.jsoo_runtime lib with
       | [] -> []
       | l  ->
         let root = Pub_name.root pub_name in
         let l = List.map l ~f:Path.basename in
         [ rule "linkopts" [Pos "javascript"] Set
             (List.map l ~f:(sprintf "+%s/%s" root) |> String.concat ~sep:" ")
         ; rule "jsoo_runtime" [] Set
             (String.concat l ~sep:" ")
         ]
      )
    ]

let gen ~package ~version libs =
  let version =
    match version with
    | None -> []
    | Some s -> [rule "version" [] Set s]
  in
  let pkgs =
    List.map libs ~f:(fun lib ->
      let pub_name = Pub_name.parse (Lib.name lib) in
      (pub_name,
       gen_lib pub_name lib ~version))
  in
  let pkgs =
    List.map pkgs ~f:(fun (pn, meta) ->
      match Pub_name.to_list pn with
      | [] -> assert false
      | _package :: path -> (path, meta))
  in
  let pkgs = List.sort pkgs ~compare:(fun (a, _) (b, _) -> compare a b) in
  let rec loop name pkgs =
    let entries, sub_pkgs =
      List.partition_map pkgs ~f:(function
        | ([]    , entries) -> Left  entries
        | (x :: p, entries) -> Right (x, (p, entries)))
    in
    let entries = List.concat entries in
    let subs =
      String.Map.of_list_multi sub_pkgs
      |> String.Map.to_list
      |> List.map ~f:(fun (name, pkgs) ->
        let pkg = loop name pkgs in
        Package { pkg with
                  entries = directory name :: pkg.entries
                })
    in
    { name = Some (Lib_name.of_string_exn ~loc:None name)
    ; entries = entries @ subs
    }
  in
  loop package pkgs
