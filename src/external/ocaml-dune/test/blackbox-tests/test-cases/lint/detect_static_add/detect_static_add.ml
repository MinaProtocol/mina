let mapper =
  let module Ast = Migrate_parsetree.Ast_405 in
  let check_expr : Ast.Parsetree.expression -> _ =
    function
    | { pexp_desc =
          Pexp_apply
            ( {pexp_desc = Pexp_ident {txt = Lident "+"; _}; _}
            , [ (Nolabel, {pexp_desc = Pexp_constant (Pconst_integer (_, None)); _})
              ; (Nolabel, {pexp_desc = Pexp_constant (Pconst_integer (_, None)); _})
              ]
            )
      ; pexp_loc = loc
      ; _
      } ->
      Format.printf
        "%a:\nThis addition can be done statically."
        Ast.Location.print_loc loc
    | _ -> ()
  in
  let id = Ast.Ast_mapper.default_mapper in
  let expr mapper e =
    check_expr e;
    id.expr mapper e
  in
  { id with expr }

let () =
  Migrate_parsetree.Driver.register
    ~name:"detect_static_add"
    Migrate_parsetree.Versions.ocaml_405
    (fun _ _ -> mapper)
