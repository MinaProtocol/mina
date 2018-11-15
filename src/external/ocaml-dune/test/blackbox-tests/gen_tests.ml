open! Stdune

let sprintf = Printf.sprintf

module Sexp = struct
  let fields fields =
    List.map fields ~f:(fun (k, s) ->
      Dune_lang.List (Dune_lang.atom k :: s))

  let strings fields =
    Dune_lang.List (List.map fields ~f:Dune_lang.atom_or_quoted_string)

  let constr name args =
    Dune_lang.List (Dune_lang.atom name :: args)

  let parse s =
    Dune_lang.parse_string ~fname:"gen_tests.ml" ~mode:Single s
    |> Dune_lang.Ast.remove_locs
end

module Platform = struct
  type t = Win | Mac

  open Dune_lang

  let to_string = function
    | Win -> "win"
    | Mac -> "macosx"

  let t t = atom (to_string t)

  let system_var = Sexp.parse "%{ocaml-config:system}"

  let enabled_if = function
    | [] -> None
    | [x] -> Some (List [atom "<>"; system_var; t x])
    | ps ->
      Some (List (
        atom "and"
        :: List.map ps ~f:(fun p -> List [atom "<>"; system_var; t p])
      ))
end

let alias ?enabled_if ?action name ~deps =
  Sexp.constr "alias"
    (Sexp.fields (
       [ "name", [Dune_lang.atom name]
       ; "deps", deps
       ] @ (match action with
         | None -> []
         | Some a -> ["action", [a]])
       @ (match enabled_if with
         | None -> []
         | Some e -> ["enabled_if", [e]])))

module Test = struct
  type t =
    { name           : string
    ; env            : (string * Dune_lang.t) option
    ; skip_ocaml     : string option
    ; skip_platforms : Platform.t list
    ; enabled        : bool
    ; js             : bool
    ; external_deps  : bool
    }

  let make ?env ?skip_ocaml ?(skip_platforms=[]) ?(enabled=true) ?(js=false)
        ?(external_deps=false) name =
    { name
    ; env
    ; skip_ocaml
    ; skip_platforms
    ; external_deps
    ; enabled
    ; js
    }

  let pp_sexp fmt t =
    let open Dune_lang in
    let skip_version =
      match t.skip_ocaml with
      | None -> []
      | Some s -> ["-skip-versions"; s]
    in
    let enabled_if = Platform.enabled_if t.skip_platforms in
    let action =
      List
        [ atom "chdir"
        ; atom (sprintf "test-cases/%s" t.name)
        ; List
            [ atom "progn"
            ; Dune_lang.List
                ([ atom "run"
                 ; Sexp.parse "%{exe:cram.exe}" ]
                 @ (List.map ~f:Dune_lang.atom_or_quoted_string
                      (skip_version @ ["-test"; "run.t"])))
            ; Sexp.strings ["diff?"; "run.t"; "run.t.corrected"]
            ]

        ]
    in
    let action =
      match t.env with
      | None -> action
      | Some (k, v) ->
        List [ atom "setenv"
             ; atom_or_quoted_string k
             ; v
             ; action ] in
    alias t.name
      ?enabled_if
      ~deps:(
        [ Sexp.strings ["package"; "dune"]
        ; Sexp.strings [ "source_tree"
                       ; sprintf "test-cases/%s" t.name]
        ]
      ) ~action
    |> Dune_lang.pp Dune fmt
end

let exclusions =
  let open Test in
  let odoc = make ~external_deps:true ~skip_ocaml:"4.02.3" in
  [ make "js_of_ocaml" ~external_deps:true ~js:true
      ~env:("NODE", Sexp.parse "%{bin:node}")
  ; make "github25" ~env:("OCAMLPATH", Dune_lang.atom "./findlib-packages")
  ; odoc "odoc"
  ; odoc "odoc-unique-mlds"
  ; odoc "github717-odoc-index"
  ; odoc "multiple-private-libs"
  ; make "ppx-rewriter" ~skip_ocaml:"4.02.3" ~external_deps:true
  ; make "output-obj" ~skip_platforms:[Mac; Win] ~skip_ocaml:"<4.06.0"
  ; make "github644" ~external_deps:true
  ; make "private-public-overlap" ~external_deps:true
  ; make "reason" ~external_deps:true
  ; make "menhir"~external_deps:true
  ; make "utop"~external_deps:true
  ; make "configurator" ~skip_platforms:[Win]
  ; make "github764" ~skip_platforms:[Win]
  ; make "gen-opam-install-file" ~external_deps:true
  ; make "scope-ppx-bug" ~external_deps:true
  ; make "findlib-dynload" ~external_deps:true
  (* The next test is disabled as it relies on configured opam
     swtiches and it's hard to get that working properly *)
  ; make "envs-and-contexts" ~external_deps:true ~enabled:false
  ]

let all_tests = lazy (
  Sys.readdir "test-cases"
  |> Array.to_list
  |> List.filter ~f:(fun s -> not (String.contains s '.'))
  |> List.sort ~compare:String.compare
  |> List.map ~f:(fun name ->
    match List.find exclusions ~f:(fun (t : Test.t) -> t.name = name) with
    | None -> Test.make name
    | Some t -> t
  )
)

let pp_group fmt (name, tests) =
  alias name ~deps:(
    (List.map tests ~f:(fun (t : Test.t) ->
       Sexp.strings ["alias"; t.name])))
  |> Dune_lang.pp Dune fmt

let () =
  let tests = Lazy.force all_tests in
  (* The runtest target has a "specoial" definition. It includes all tests
     except for js and disabled tests *)
  tests |> List.iter ~f:(fun t -> Format.printf "%a@.@." Test.pp_sexp t);
  [ "runtest", (fun (t : Test.t) -> not t.js && t.enabled)
  ; "runtest-no-deps", (fun (t : Test.t) -> not t.external_deps && t.enabled)
  ; "runtest-disabled", (fun (t : Test.t) -> not t.enabled)
  ; "runtest-js", (fun (t : Test.t) -> t.js && t.enabled) ]
  |> List.map ~f:(fun (name, predicate) ->
    (name, List.filter tests ~f:predicate))
  |> Format.pp_print_list
       ~pp_sep:(fun fmt () -> Format.fprintf fmt "@.@.")
       pp_group Format.std_formatter
