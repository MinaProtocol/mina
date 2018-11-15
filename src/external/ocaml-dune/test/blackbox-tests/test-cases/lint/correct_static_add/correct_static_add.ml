let detect_static_add = object
  inherit Ppxlib.Ast_traverse.iter as super

  method! expression e =
    match e with
    | { pexp_desc =
          Pexp_apply
            ( {pexp_desc = Pexp_ident {txt = Lident "+"; _}; _}
            , [ (Nolabel, {pexp_desc = Pexp_constant (Pconst_integer (a, None)); _})
              ; (Nolabel, {pexp_desc = Pexp_constant (Pconst_integer (b, None)); _})
              ]
            )
      ; pexp_loc = loc
      ; _
      } ->
      let sum = int_of_string a + int_of_string b in
      let repl = string_of_int sum in
      Ppxlib.Driver.register_correction ~loc ~repl
    | _ -> super#expression e
end

let impl s =
  detect_static_add#structure s; s

let () =
  Ppxlib.Driver.register_transformation
    "detect_static_add"
    ~impl
