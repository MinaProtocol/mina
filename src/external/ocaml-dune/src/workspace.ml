open! Stdune
open Stanza.Decoder

(* workspace files use the same version numbers as dune-project files
   for simplicity *)
let syntax = Stanza.syntax

let env_field =
  field_o "env"
    (Syntax.since syntax (1, 1) >>= fun () ->
     Dune_env.Stanza.decode)

module Context = struct
  module Target = struct
    type t =
      | Native
      | Named of string

    let t =
      map string ~f:(function
        | "native" -> Native
        | s        -> Named s)

    let add ts x =
      match x with
      | None -> ts
      | Some t ->
        if List.mem t ~set:ts then
          ts
        else
          ts @ [t]
  end

  module Name = struct
    let t =
      plain_string (fun ~loc name ->
        if name = "" ||
           String.is_prefix name ~prefix:"." ||
           name = "log" ||
           name = "install" ||
           String.contains name '/' ||
           String.contains name '\\' then
          of_sexp_errorf loc
            "%S is not allowed as a build context name" name;
        name)
  end

  module Common = struct
    type t =
      { loc       : Loc.t
      ; profile   : string
      ; targets   : Target.t list
      ; env       : Dune_env.Stanza.t option
      ; toolchain : string option
      }

    let t ~profile =
      let%map env = env_field
      and targets = field "targets" (list Target.t) ~default:[Target.Native]
      and profile = field "profile" string ~default:profile
      and toolchain =
        field_o "toolchain" (Syntax.since syntax (1, 5) >>= fun () -> string)
      and loc = loc
      in
      { targets
      ; profile
      ; loc
      ; env
      ; toolchain
      }
  end

  module Opam = struct
    type t =
      { base    : Common.t
      ; name    : string
      ; switch  : string
      ; root    : string option
      ; merlin  : bool
      }

    let t ~profile ~x =
      let%map base = Common.t ~profile
      and switch = field "switch" string
      and name = field_o "name" Name.t
      and root = field_o "root" string
      and merlin = field_b "merlin"
      in
      let name = Option.value ~default:switch name in
      let base = { base with targets = Target.add base.targets x } in
      { base
      ; switch
      ; name
      ; root
      ; merlin
      }
  end

  module Default = struct
    type t = Common.t

    let t ~profile ~x =
      Common.t ~profile >>| fun t ->
      { t with targets = Target.add t.targets x }
  end

  type t = Default of Default.t | Opam of Opam.t

  let loc = function
    | Default x -> x.loc
    | Opam    x -> x.base.loc

  let t ~profile ~x =
    sum
      [ "default",
        (fields (Default.t ~profile ~x) >>| fun x ->
         Default x)
      ; "opam",
        (fields (Opam.t ~profile ~x) >>| fun x ->
         Opam x)
      ]

  let t ~profile ~x =
    switch_file_kind
      ~jbuild:
        (* jbuild-workspace files *)
        (peek_exn >>= function
         | List (_, List _ :: _) ->
           Dune_lang.Decoder.record (Opam.t ~profile ~x) >>| fun x -> Opam x
         | _ -> t ~profile ~x)
      ~dune:(t ~profile ~x)

  let name = function
    | Default _ -> "default"
    | Opam    o -> o.name

  let targets = function
    | Default x -> x.targets
    | Opam    x -> x.base.targets

  let all_names t =
    let n = name t in
    n :: List.filter_map (targets t) ~f:(function
      | Native -> None
      | Named s -> Some (n ^ "." ^ s))

  let default ?x ?profile () =
    Default
      { loc = Loc.of_pos __POS__
      ; targets = [Option.value x ~default:Target.Native]
      ; profile = Option.value profile
                    ~default:Config.default_build_profile
      ; env = None
      ; toolchain = None
      }
end

type t =
  { merlin_context : string option
  ; contexts       : Context.t list
  ; env            : Dune_env.Stanza.t option
  }

include Versioned_file.Make(struct type t = unit end)
let () = Lang.register syntax ()

let t ?x ?profile:cmdline_profile () =
  Versioned_file.no_more_lang >>= fun () ->
  env_field >>= fun env ->
  field "profile" string ~default:Config.default_build_profile
  >>= fun profile ->
  let profile = Option.value cmdline_profile ~default:profile in
  multi_field "context" (Context.t ~profile ~x)
  >>| fun contexts ->
  let defined_names = ref String.Set.empty in
  let merlin_context =
    List.fold_left contexts ~init:None ~f:(fun acc ctx ->
      let name = Context.name ctx in
      if String.Set.mem !defined_names name then
        Errors.fail (Context.loc ctx)
          "second definition of build context %S" name;
      defined_names := String.Set.union !defined_names
                         (String.Set.of_list (Context.all_names ctx));
      match ctx, acc with
      | Opam { merlin = true; _ }, Some _ ->
        Errors.fail (Context.loc ctx)
          "you can only have one context for merlin"
      | Opam { merlin = true; _ }, None ->
        Some name
      | _ ->
        acc)
  in
  let contexts =
    match contexts with
    | [] -> [Context.default ?x ~profile ()]
    | _  -> contexts
  in
  let merlin_context =
    match merlin_context with
    | Some _ -> merlin_context
    | None ->
      if List.exists contexts
           ~f:(function Context.Default _ -> true | _ -> false) then
        Some "default"
      else
        None
  in
  { merlin_context
  ; contexts = List.rev contexts
  ; env
  }

let t ?x ?profile () = fields (t ?x ?profile ())

let default ?x ?profile () =
  { merlin_context = Some "default"
  ; contexts = [Context.default ?x ?profile ()]
  ; env = None
  }

let load ?x ?profile p =
  let x = Option.map x ~f:(fun s -> Context.Target.Named s) in
  match Which_program.t with
  | Dune ->
    Io.with_lexbuf_from_file p ~f:(fun lb ->
      if Dune_lexer.eof_reached lb then
        default ?x ?profile ()
      else
        let first_line = Dune_lexer.first_line lb in
        parse_contents lb first_line ~f:(fun _lang -> t ?x ?profile ()))
  | Jbuilder ->
    let sexp =
      Dune_lang.Io.load p ~mode:Many_as_one ~lexer:Dune_lang.Lexer.jbuild_token
    in
    parse
      (enter (t ?x ?profile ()))
      (Univ_map.singleton (Syntax.key syntax) (0, 0))
      sexp

let default ?x ?profile () =
  let x = Option.map x ~f:(fun s -> Context.Target.Named s) in
  default ?x ?profile ()

let filename =
  match Which_program.t with
  | Dune     -> "dune-workspace"
  | Jbuilder -> "jbuild-workspace"
