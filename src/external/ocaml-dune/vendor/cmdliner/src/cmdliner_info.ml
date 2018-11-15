(*---------------------------------------------------------------------------
   Copyright (c) 2011 Daniel C. Bünzli. All rights reserved.
   Distributed under the ISC license, see terms at the end of the file.
   cmdliner v1.0.0
  ---------------------------------------------------------------------------*)


let new_id =       (* thread-safe UIDs, Oo.id (object end) was used before. *)
  let c = ref 0 in
  fun () ->
    let id = !c in
    incr c; if id > !c then assert false (* too many ids *) else id

(* Environments *)

type env =                     (* information about an environment variable. *)
  { env_id : int;                              (* unique id for the env var. *)
    env_var : string;                                       (* the variable. *)
    env_doc : string;                                               (* help. *)
    env_docs : string; }              (* title of help section where listed. *)

let env
    ?docs:(env_docs = Cmdliner_manpage.s_environment)
    ?doc:(env_doc = "See option $(opt).") env_var =
  { env_id = new_id (); env_var; env_doc; env_docs }

let env_var e = e.env_var
let env_doc e = e.env_doc
let env_docs e = e.env_docs


module Env = struct
  type t = env
  let compare a0 a1 = (compare : int -> int -> int) a0.env_id a1.env_id
end

module Envs = Set.Make (Env)
type envs = Envs.t

(* Arguments *)

type arg_absence = Err | Val of string Lazy.t
type opt_kind = Flag | Opt | Opt_vopt of string

type pos_kind =                  (* information about a positional argument. *)
  { pos_rev : bool;         (* if [true] positions are counted from the end. *)
    pos_start : int;                           (* start positional argument. *)
    pos_len : int option }    (* number of arguments or [None] if unbounded. *)

let pos ~rev:pos_rev ~start:pos_start ~len:pos_len =
  { pos_rev; pos_start; pos_len}

let pos_rev p = p.pos_rev
let pos_start p = p.pos_start
let pos_len p = p.pos_len

type arg =                     (* information about a command line argument. *)
  { id : int;                                 (* unique id for the argument. *)
    absent : arg_absence;                            (* behaviour if absent. *)
    env : env option;                               (* environment variable. *)
    doc : string;                                                   (* help. *)
    docv : string;                (* variable name for the argument in help. *)
    docs : string;                    (* title of help section where listed. *)
    pos : pos_kind;                                  (* positional arg kind. *)
    opt_kind : opt_kind;                               (* optional arg kind. *)
    opt_names : string list;                        (* names (for opt args). *)
    opt_all : bool; }                          (* repeatable (for opt args). *)

let dumb_pos = pos ~rev:false ~start:(-1) ~len:None

let arg ?docs ?(docv = "") ?(doc = "") ?env names =
  let dash n = if String.length n = 1 then "-" ^ n else "--" ^ n in
  let opt_names = List.map dash names in
  let docs = match docs with
  | Some s -> s
  | None ->
      match names with
      | [] -> Cmdliner_manpage.s_arguments
      | _ -> Cmdliner_manpage.s_options
  in
  { id = new_id (); absent = Val (lazy ""); env; doc; docv; docs;
    pos = dumb_pos; opt_kind = Flag; opt_names; opt_all = false; }

let arg_id a = a.id
let arg_absent a = a.absent
let arg_env a = a.env
let arg_doc a = a.doc
let arg_docv a = a.docv
let arg_docs a = a.docs
let arg_pos a = a.pos
let arg_opt_kind a = a.opt_kind
let arg_opt_names a = a.opt_names
let arg_opt_all a = a.opt_all
let arg_opt_name_sample a =
  (* First long or short name (in that order) in the list; this
     allows the client to control which name is shown *)
  let rec find = function
  | [] -> List.hd a.opt_names
  | n :: ns -> if (String.length n) > 2 then n else find ns
  in
  find a.opt_names

let arg_make_req a = { a with absent = Err }
let arg_make_all_opts a = { a with opt_all = true }
let arg_make_opt ~absent ~kind:opt_kind a = { a with absent; opt_kind }
let arg_make_opt_all ~absent ~kind:opt_kind a =
  { a with absent; opt_kind; opt_all = true  }

let arg_make_pos ~pos a = { a with pos }
let arg_make_pos_abs ~absent ~pos a = { a with absent; pos }

let arg_is_opt a = a.opt_names <> []
let arg_is_pos a = a.opt_names = []
let arg_is_req a = a.absent = Err

let arg_pos_cli_order a0 a1 =              (* best-effort order on the cli. *)
  let c = compare (a0.pos.pos_rev) (a1.pos.pos_rev) in
  if c <> 0 then c else
  if a0.pos.pos_rev
  then compare a1.pos.pos_start a0.pos.pos_start
  else compare a0.pos.pos_start a1.pos.pos_start

let rev_arg_pos_cli_order a0 a1 = arg_pos_cli_order a1 a0

module Arg = struct
  type t = arg
  let compare a0 a1 = (compare : int -> int -> int) a0.id a1.id
end

module Args = Set.Make (Arg)
type args = Args.t

(* Exit info *)

type exit =
  { exit_statuses : int * int;
    exit_doc : string;
    exit_docs : string; }

let exit
    ?docs:(exit_docs = Cmdliner_manpage.s_exit_status)
    ?doc:(exit_doc = "undocumented") ?max min =
  let max = match max with None -> min | Some max -> max in
  { exit_statuses = (min, max); exit_doc; exit_docs }

let exit_statuses e = e.exit_statuses
let exit_doc e = e.exit_doc
let exit_docs e = e.exit_docs
let exit_order e0 e1 = compare e0.exit_statuses e1.exit_statuses

(* Term info *)

type term_info =
  { term_name : string;                                 (* name of the term. *)
    term_version : string option;                (* version (for --version). *)
    term_doc : string;                      (* one line description of term. *)
    term_docs : string;     (* title of man section where listed (commands). *)
    term_sdocs : string; (* standard options, title of section where listed. *)
    term_exits : exit list;                      (* exit codes for the term. *)
    term_envs : env list;               (* env vars that influence the term. *)
    term_man : Cmdliner_manpage.block list;                (* man page text. *)
    term_man_xrefs : Cmdliner_manpage.xref list; }        (* man cross-refs. *)

type term =
  { term_info : term_info;
    term_args : args; }

let term
    ?args:(term_args = Args.empty) ?man_xrefs:(term_man_xrefs = [])
    ?man:(term_man = []) ?envs:(term_envs = []) ?exits:(term_exits = [])
    ?sdocs:(term_sdocs = Cmdliner_manpage.s_options)
    ?docs:(term_docs = "COMMANDS") ?doc:(term_doc = "") ?version:term_version
    term_name =
  let term_info =
    { term_name; term_version; term_doc; term_docs; term_sdocs; term_exits;
      term_envs; term_man; term_man_xrefs }
  in
  { term_info; term_args }

let term_name t = t.term_info.term_name
let term_version t = t.term_info.term_version
let term_doc t = t.term_info.term_doc
let term_docs t = t.term_info.term_docs
let term_stdopts_docs t = t.term_info.term_sdocs
let term_exits t = t.term_info.term_exits
let term_envs t = t.term_info.term_envs
let term_man t = t.term_info.term_man
let term_man_xrefs t = t.term_info.term_man_xrefs
let term_args t = t.term_args

let term_add_args t args =
  { t with term_args = Args.union args t.term_args }

(* Eval info *)

type eval =                     (* information about the evaluation context. *)
  { term : term;                                    (* term being evaluated. *)
    main : term;                                               (* main term. *)
    choices : term list;                                (* all term choices. *)
    env : string -> string option }          (* environment variable lookup. *)

let eval ~term ~main ~choices ~env = { term; main; choices; env }
let eval_term e = e.term
let eval_main e = e.main
let eval_choices e = e.choices
let eval_env_var e v = e.env v

let eval_kind ei =
  if ei.choices = [] then `Simple else
  if (ei.term.term_info.term_name == ei.main.term_info.term_name)
  then `Multiple_main else `Multiple_sub

let eval_with_term ei term = { ei with term }

let eval_has_choice e cmd =
  let is_cmd t = t.term_info.term_name = cmd in
  List.exists is_cmd e.choices

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
