(* dummy_derivers.ml -- create no-op derivers *)

open Ppxlib.Deriving

(* arguments *)
let make_args1 a1 = Args.(empty +> a1)
let make_args2 a1 a2 = Args.(make_args1 a1 +> a2)
let make_args3 a1 a2 a3 = Args.(make_args2 a1 a2 +> a3)
let make_args4 a1 a2 a3 a4 = Args.(make_args3 a1 a2 a3 +> a4)

(* type declarations *)
let type_decl_rw0 ~loc:_ ~path:_ (_rec_flag,_type_decls) = []
let type_decl_rw1 ~loc:_ ~path:_ (_rec_flag,_type_decls) _ = []
let type_decl_rw2 ~loc:_ ~path:_ (_rec_flag,_type_decls) _ _ = []
let type_decl_rw3 ~loc:_ ~path:_ (_rec_flag,_type_decls) _ _ _ = []
let type_decl_rw4 ~loc:_ ~path:_ (_rec_flag,_type_decls) _ _ _ _ = []

let make_gen_opt args_opt rw_opt =
  match args_opt, rw_opt with
    Some _,None |
    None, Some _ ->
    failwith "make_gen_opt: must supply both args and rewriter, or neither"
  | None,None -> None
  | Some args,Some rw ->
    Some (Generator.make args rw)

let make_type_decl_no_op name ?str_args ?str_rw ?sig_args ?sig_rw () =
  let str_type_decl_opt = make_gen_opt str_args str_rw in
  let sig_type_decl_opt = make_gen_opt sig_args sig_rw in
  match str_type_decl_opt,sig_type_decl_opt with
  | None,None ->
    failwith "Expected args and generator for either a structure, signature, or both"
  | Some str_type_decl,None ->
    add name ~str_type_decl |> ignore
  | None, Some sig_type_decl ->
    add name ~sig_type_decl |> ignore
  | Some str_type_decl,Some sig_type_decl ->
    add name ~str_type_decl ~sig_type_decl |> ignore

(* type extensions *)
let type_ext_rw0 ~loc:_ ~path:_ _type_ext = []
let type_ext_rw1 ~loc:_ ~path:_ _type_ext _ = []
let type_ext_rw2 ~loc:_ ~path:_ _type_ext _ _ = []
let type_ext_rw3 ~loc:_ ~path:_ _type_ext _ _ _ = []
let type_ext_rw4 ~loc:_ ~path:_ _type_ext _ _ _ _ = []

let make_type_ext_no_op name ?str_args ?str_rw ?sig_args ?sig_rw () =
  let str_type_ext_opt = make_gen_opt str_args str_rw in
  let sig_type_ext_opt = make_gen_opt sig_args sig_rw in
  match str_type_ext_opt,sig_type_ext_opt with
  | None,None ->
    failwith "Expected args and rewriter for either a structure, signature, or both"
  | Some str_type_ext,None ->
    add name ~str_type_ext |> ignore
  | None, Some sig_type_ext ->
    add name ~sig_type_ext |> ignore
  | Some str_type_ext,Some sig_type_ext ->
    add name ~str_type_ext ~sig_type_ext |> ignore

let register_dummies () =
  let register_dummy_type_decl_derivers () =
    let derivers = ["dhall_type";"hlist";"to_enum";"to_representatives";"annot"] in
    (* for structures only, not for signatures *)
    Core_kernel.List.iter derivers ~f:(fun name -> make_type_decl_no_op name ~str_args:Args.empty ~str_rw:type_decl_rw0 ())
  in
  let register_dummy_type_ext_derivers () =
    let register_event_arg = make_args1 Ppxlib.Deriving.Args.(arg "msg" __) in
    (* for structures, one argument, for signatures, no arguments *)
    make_type_ext_no_op "register_event" ~str_args:register_event_arg ~str_rw:type_ext_rw1 ~sig_args:Args.empty ~sig_rw:type_ext_rw0 ()
  in
  register_dummy_type_decl_derivers ();
  register_dummy_type_ext_derivers ()
