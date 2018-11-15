open! Stdune

let parse_sub_systems ~parsing_context sexps =
  List.filter_map sexps ~f:(fun sexp ->
    let name, ver, data =
      Dune_lang.Decoder.(parse (triple string (located Syntax.Version.decode) raw)
                       parsing_context) sexp
    in
    (* We ignore sub-systems that are not internally known. These
       correspond to plugins that are not in use in the current
       workspace. *)
    Option.map (Sub_system_name.get name) ~f:(fun name ->
      (name, (Dune_lang.Ast.loc sexp, ver, data))))
  |> Sub_system_name.Map.of_list
  |> (function
    | Ok x -> x
    | Error (name, _, (loc, _, _)) ->
      Errors.fail loc "%S present twice" (Sub_system_name.to_string name))
  |> Sub_system_name.Map.mapi ~f:(fun name (_, version, data) ->
    let (module M) = Dune_file.Sub_system_info.get name in
    Syntax.check_supported M.syntax version;
    let parsing_context =
      (* We set the syntax to the version used when generating this subsystem.
         We cannot do this for jbuild defined subsystems however since those use
         1.0 as the version. Which would correspond to the dune syntax (because
         subsystems share the syntax of the dune lang) *)
      match Univ_map.find_exn parsing_context (Syntax.key Stanza.syntax) with
      | (0, 0) ->
        parsing_context
      | (_, _) ->
        Univ_map.add parsing_context (Syntax.key M.syntax) (snd version)
    in
    M.T (Dune_lang.Decoder.parse M.parse parsing_context data))

let of_sexp =
  let open Dune_lang.Decoder in
  let version =
    plain_string (fun ~loc -> function
      | "1" -> (0, 0)
      | "2" -> (1, 0)
      | v ->
        of_sexp_errorf loc
          "Unsupported version %S, only version 1 is supported" v)
  in
  sum
    [ "dune",
      (version >>= fun version ->
       set (Syntax.key Stanza.syntax) version
         (let%map parsing_context = get_all
          and sub_systems = list raw
          in
          parse_sub_systems ~parsing_context sub_systems))
    ]

let load fname =
  Io.with_lexbuf_from_file fname ~f:(fun lexbuf ->
    (* Installed dune files are versioned but they don't use the
       [(lang ...)] line which was introduced after. Installed dune
       files in version 1 are using the jbuild syntax and version 2
       are using the dune syntax, so we start by lexing the first
       tokens with the dune lexer until we reach the file version, at
       which point we can decide what lexer to use for the reset of
       the file. *)
    let state = ref 0 in
    let lexer = ref Dune_lang.Lexer.token in
    let lexer lb =
      let token : Dune_lang.Lexer.Token.t = !lexer lb in
      (match !state, token with
       | 0, Lparen -> state := 1
       | 1, Atom (A "dune") -> state := 2
       | 2, Atom (A "1") -> state := 3; lexer := Dune_lang.Lexer.jbuild_token
       | 2, Atom (A "2") -> state := 3; lexer := Dune_lang.Lexer.token
       | 2, Atom (A version) ->
         Errors.fail (Loc.of_lexbuf lexbuf) "Unsupported version %S" version
       | 3, _ -> ()
       | _ ->
         Errors.fail (Loc.of_lexbuf lexbuf)
           "This <lib>.dune file looks invalid, it should \
            contain a S-expression of the form (dune x.y ..)"
      );
      token
    in
    Dune_lang.Decoder.parse of_sexp Univ_map.empty
      (Dune_lang.Parser.parse ~lexer ~mode:Single lexbuf))

let gen ~(dune_version : Syntax.Version.t) confs =
  let sexps =
    Sub_system_name.Map.to_list confs
    |> List.map ~f:(fun (name, (ver, conf)) ->
      let (module M) = Dune_file.Sub_system_info.get name in
      Dune_lang.List [ Dune_lang.atom (Sub_system_name.to_string name)
                ; Syntax.Version.encode ver
                ; conf
                ])
  in
  Dune_lang.List
    [ Dune_lang.unsafe_atom_of_string "dune"
    ; Dune_lang.unsafe_atom_of_string
        (match dune_version with
         | (0, 0) -> "1"
         | (x, _) when x >= 1 -> "2"
         | (_, _) ->
           Exn.code_error "Cannot generate dune with unknown version"
             ["dune_version", Syntax.Version.to_sexp dune_version])
    ; List sexps
    ]
