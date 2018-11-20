(*---------------------------------------------------------------------------
   Copyright (c) 2011 Daniel C. Bünzli. All rights reserved.
   Distributed under the ISC license, see terms at the end of the file.
   cmdliner v1.0.0
  ---------------------------------------------------------------------------*)

open Result

module Manpage = Cmdliner_manpage
module Arg = Cmdliner_arg
module Term = struct

  include Cmdliner_term

  (* Deprecated *)

  let man_format = Cmdliner_arg.man_format
  let pure = const

  (* Terms *)

  let ( $ ) = app

  type 'a ret = [ `Ok of 'a | term_escape ]

  let ret (al, v) =
    al, fun ei cl -> match v ei cl with
    | Ok (`Ok v) -> Ok v
    | Ok (`Error _ as err) -> Error err
    | Ok (`Help _ as help) -> Error help
    | Error _ as e -> e

  let term_result ?(usage = false) (al, v) =
    al, fun ei cl -> match v ei cl with
    | Ok (Ok _ as ok) -> ok
    | Ok (Error (`Msg e)) -> Error (`Error (usage, e))
    | Error _ as e -> e

  let cli_parse_result (al, v) =
    al, fun ei cl -> match v ei cl with
    | Ok (Ok _ as ok) -> ok
    | Ok (Error (`Msg e)) -> Error (`Parse e)
    | Error _ as e -> e

  let main_name =
    Cmdliner_info.Args.empty,
    (fun ei _ -> Ok (Cmdliner_info.(term_name @@ eval_main ei)))

  let choice_names =
    let choice_name t = Cmdliner_info.term_name t in
    Cmdliner_info.Args.empty,
    (fun ei _ -> Ok (List.rev_map choice_name (Cmdliner_info.eval_choices ei)))

  (* Term information *)

  type exit_info = Cmdliner_info.exit
  let exit_info = Cmdliner_info.exit

  let exit_status_success = 0
  let exit_status_cli_error = 124
  let exit_status_internal_error = 125
  let default_error_exits =
    [ exit_info exit_status_cli_error ~doc:"on command line parsing errors.";
      exit_info exit_status_internal_error
        ~doc:"on unexpected internal errors (bugs)."; ]

  let default_exits =
    (exit_info exit_status_success ~doc:"on success.") :: default_error_exits

  type env_info = Cmdliner_info.env
  let env_info = Cmdliner_info.env

  type info = Cmdliner_info.term
  let info = Cmdliner_info.term ~args:Cmdliner_info.Args.empty
  let name ti = Cmdliner_info.term_name ti

  (* Evaluation *)

  let err_help s = "Term error, help requested for unknown command " ^ s
  let err_argv = "argv array must have at least one element"
  let err_multi_cmd_def name (a, _) (a', _) =
    Cmdliner_base.err_multi_def ~kind:"command" name Cmdliner_info.term_doc a a'

  type 'a result =
    [ `Ok of 'a | `Error of [`Parse | `Term | `Exn ] | `Version | `Help ]

  let add_stdopts ei =
    let docs = Cmdliner_info.(term_stdopts_docs @@ eval_term ei) in
    let vargs, vers = match Cmdliner_info.(term_version @@ eval_main ei) with
    | None -> Cmdliner_info.Args.empty, None
    | Some _ ->
        let args, _ as vers = Cmdliner_arg.stdopt_version ~docs in
        args, Some vers
    in
    let help = Cmdliner_arg.stdopt_help ~docs in
    let args = Cmdliner_info.Args.union vargs (fst help) in
    let term = Cmdliner_info.(term_add_args (eval_term ei) args) in
    help, vers, Cmdliner_info.eval_with_term ei term

  type 'a eval_result =
    ('a, [ term_escape
         | `Exn of exn * Printexc.raw_backtrace
         | `Parse of string
         | `Std_help of Manpage.format | `Std_version ]) Result.result

  let run ~catch ei cl f = try (f ei cl :> 'a eval_result) with
  | exn when catch ->
      let bt = Printexc.get_raw_backtrace () in
      Error (`Exn (exn, bt))

  let try_eval_stdopts ~catch ei cl help version =
    match run ~catch ei cl (snd help) with
    | Ok (Some fmt) -> Some (Error (`Std_help fmt))
    | Error _ as err -> Some err
    | Ok None ->
        match version with
        | None -> None
        | Some version ->
            match run ~catch ei cl (snd version) with
            | Ok false -> None
            | Ok true -> Some (Error (`Std_version))
            | Error _ as err -> Some err

  let term_eval ~catch ei f args =
    let help, version, ei = add_stdopts ei in
    let term_args = Cmdliner_info.(term_args @@ eval_term ei) in
    let res = match Cmdliner_cline.create term_args args with
    | Error (e, cl) ->
        begin match try_eval_stdopts ~catch ei cl help version with
        | Some e -> e
        | None -> Error (`Error (true, e))
        end
    | Ok cl ->
        match try_eval_stdopts ~catch ei cl help version with
        | Some e -> e
        | None -> run ~catch ei cl f
    in
    ei, res

  let term_eval_peek_opts ei f args =
    let help, version, ei = add_stdopts ei in
    let term_args = Cmdliner_info.(term_args @@ eval_term ei) in
    let v, ret = match Cmdliner_cline.create ~peek_opts:true term_args args with
    | Error (e, cl) ->
        begin match try_eval_stdopts ~catch:true ei cl help version with
        | Some e -> None, e
        | None -> None, Error (`Error (true, e))
        end
    | Ok cl ->
        let ret = run ~catch:true ei cl f in
        let v = match ret with Ok v -> Some v | Error _ -> None in
        match try_eval_stdopts ~catch:true ei cl help version with
        | Some e -> v, e
        | None -> v, ret
    in
    let ret = match ret with
    | Ok v -> `Ok v
    | Error `Std_help _ -> `Help
    | Error `Std_version -> `Version
    | Error `Parse _ -> `Error `Parse
    | Error `Help _ -> `Help
    | Error `Exn _ -> `Error `Exn
    | Error `Error _ -> `Error `Term
    in
    v, ret

  let do_help help_ppf err_ppf ei fmt cmd =
    let ei = match cmd with
    | None -> Cmdliner_info.(eval_with_term ei @@ eval_main ei)
    | Some cmd ->
        try
          let is_cmd t = Cmdliner_info.term_name t = cmd in
          let cmd = List.find is_cmd (Cmdliner_info.eval_choices ei) in
          Cmdliner_info.eval_with_term ei cmd
        with Not_found -> invalid_arg (err_help cmd)
    in
    let _, _, ei = add_stdopts ei (* may not be the originally eval'd term *) in
    Cmdliner_docgen.pp_man ~errs:err_ppf fmt help_ppf ei

  let do_result help_ppf err_ppf ei = function
  | Ok v -> `Ok v
  | Error res ->
      match res with
      | `Std_help fmt -> Cmdliner_docgen.pp_man err_ppf fmt help_ppf ei; `Help
      | `Std_version -> Cmdliner_msg.pp_version help_ppf ei; `Version
      | `Parse err -> Cmdliner_msg.pp_err_usage err_ppf ei ~err; `Error `Parse
      | `Help (fmt, cmd) -> do_help help_ppf err_ppf ei fmt cmd; `Help
      | `Exn (e, bt) -> Cmdliner_msg.pp_backtrace err_ppf ei e bt; `Error `Exn
      | `Error (usage, err) ->
          (if usage
           then Cmdliner_msg.pp_err_usage err_ppf ei ~err
           else Cmdliner_msg.pp_err err_ppf ei ~err);
          `Error `Term

  (* API *)

  let env_default v = try Some (Sys.getenv v) with Not_found -> None
  let remove_exec argv =
    try List.tl (Array.to_list argv) with Failure _ -> invalid_arg err_argv

  let eval
      ?help:(help_ppf = Format.std_formatter)
      ?err:(err_ppf = Format.err_formatter)
      ?(catch = true) ?(env = env_default) ?(argv = Sys.argv) ((al, f), ti) =
    let term = Cmdliner_info.term_add_args ti al in
    let ei = Cmdliner_info.eval ~term ~main:term ~choices:[] ~env in
    let args = remove_exec argv in
    let ei, res = term_eval ~catch ei f args in
    do_result help_ppf err_ppf ei res

  let choose_term main choices = function
  | [] -> Ok (main, [])
  | maybe :: args' as args ->
      if String.length maybe > 1 && maybe.[0] = '-' then Ok (main, args) else
      let index =
        let add acc (choice, _ as c) =
          let name = Cmdliner_info.term_name choice in
          match Cmdliner_trie.add acc name c with
          | `New t -> t
          | `Replaced (c', _) -> invalid_arg (err_multi_cmd_def name c c')
        in
        List.fold_left add Cmdliner_trie.empty choices
      in
      match Cmdliner_trie.find index maybe with
      | `Ok choice -> Ok (choice, args')
      | `Not_found ->
          let all = Cmdliner_trie.ambiguities index "" in
          let hints = Cmdliner_suggest.value maybe all in
          Error (Cmdliner_base.err_unknown ~kind:"command" maybe ~hints)
      | `Ambiguous ->
          let ambs = Cmdliner_trie.ambiguities index maybe in
          let ambs = List.sort compare ambs in
          Error (Cmdliner_base.err_ambiguous ~kind:"command" maybe ~ambs)

  let eval_choice
      ?help:(help_ppf = Format.std_formatter)
      ?err:(err_ppf = Format.err_formatter)
      ?(catch = true) ?(env = env_default) ?(argv = Sys.argv)
      main choices =
    let to_term_f ((al, f), ti) = Cmdliner_info.term_add_args ti al, f in
    let choices_f = List.rev_map to_term_f choices in
    let main_f = to_term_f main in
    let choices = List.rev_map fst choices_f in
    let main = fst main_f in
    match choose_term main_f choices_f (remove_exec argv) with
    | Error err ->
        let ei = Cmdliner_info.eval ~term:main ~main ~choices ~env in
        Cmdliner_msg.pp_err_usage err_ppf ei ~err; `Error `Parse
    | Ok ((chosen, f), args) ->
        let ei = Cmdliner_info.eval ~term:chosen ~main ~choices ~env in
        let ei, res = term_eval ~catch ei f args in
        do_result help_ppf err_ppf ei res

  let eval_peek_opts
      ?(version_opt = false) ?(env = env_default) ?(argv = Sys.argv)
      ((args, f) : 'a t) =
    let version = if version_opt then Some "dummy" else None in
    let term = Cmdliner_info.term ~args ?version "dummy" in
    let ei = Cmdliner_info.eval ~term ~main:term ~choices:[] ~env  in
    (term_eval_peek_opts ei f (remove_exec argv) :> 'a option * 'a result)

  (* Exits *)

  let exit_status_of_result ?(term_err = 1) = function
  | `Ok _ | `Help | `Version -> exit_status_success
  | `Error `Term -> term_err
  | `Error `Exn -> exit_status_internal_error
  | `Error `Parse -> exit_status_cli_error

  let exit_status_of_status_result ?term_err = function
  | `Ok n -> n
  | r -> exit_status_of_result ?term_err r

  let exit ?term_err r = Pervasives.exit (exit_status_of_result ?term_err r)
  let exit_status ?term_err r =
    Pervasives.exit (exit_status_of_status_result ?term_err r)

end

(*---------------------------------------------------------------------------
   Copyright (c) 2011 Daniel C. Bünzli

   Permission to use, copy, modify, and/or distribute this software for any
   purpose with or without fee is hereby granted, provided that the above
   copyright notice and this permission notice appear in all copies.

   THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
   WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
   MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
   ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
   WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
   ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
   OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
  ---------------------------------------------------------------------------*)
