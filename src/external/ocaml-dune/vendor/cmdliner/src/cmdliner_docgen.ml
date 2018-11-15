(*---------------------------------------------------------------------------
   Copyright (c) 2011 Daniel C. Bünzli. All rights reserved.
   Distributed under the ISC license, see terms at the end of the file.
   cmdliner v1.0.0
  ---------------------------------------------------------------------------*)

let rev_compare n0 n1 = compare n1 n0
let strf = Printf.sprintf

let esc = Cmdliner_manpage.escape
let term_name t = esc @@ Cmdliner_info.term_name t

let sorted_items_to_blocks ~boilerplate:b items =
  (* Items are sorted by section and then rev. sorted by appearance.
     We gather them by section in correct order in a `Block and prefix
     them with optional boilerplate *)
  let boilerplate = match b with None -> (fun _ -> None) | Some b -> b in
  let mk_block sec acc = match boilerplate sec with
  | None -> (sec, `Blocks acc)
  | Some b -> (sec, `Blocks (b :: acc))
  in
  let rec loop secs sec acc = function
  | (sec', it) :: its when sec' = sec -> loop secs sec (it :: acc) its
  | (sec', it) :: its -> loop (mk_block sec acc :: secs) sec' [it] its
  | [] -> (mk_block sec acc) :: secs
  in
  match items with
  | [] -> []
  | (sec, it) :: its -> loop [] sec [it] its

(* Doc string variables substitutions. *)

let env_info_subst ~subst e = function
| "env" -> Some (strf "$(b,%s)" @@ esc (Cmdliner_info.env_var e))
| id -> subst id

let exit_info_subst ~subst e = function
| "status" -> Some (strf "%d" (fst @@ Cmdliner_info.exit_statuses e))
| "status_max" -> Some (strf "%d" (snd @@ Cmdliner_info.exit_statuses e))
| id -> subst id

let arg_info_subst ~subst a = function
| "docv" ->
    Some (strf "$(i,%s)" @@ esc (Cmdliner_info.arg_docv a))
| "opt" when Cmdliner_info.arg_is_opt a ->
    Some (strf "$(b,%s)" @@ esc (Cmdliner_info.arg_opt_name_sample a))
| "env" as id ->
    begin match Cmdliner_info.arg_env a with
    | Some e -> env_info_subst ~subst e id
    | None -> subst id
    end
| id -> subst id

let term_info_subst ei = function
| "tname" -> Some (strf "$(b,%s)" @@ term_name (Cmdliner_info.eval_term ei))
| "mname" -> Some (strf "$(b,%s)" @@ term_name (Cmdliner_info.eval_main ei))
| _ -> None

(* Command docs *)

let invocation ?(sep = ' ') ei = match Cmdliner_info.eval_kind ei with
| `Simple | `Multiple_main -> term_name (Cmdliner_info.eval_main ei)
| `Multiple_sub ->
    strf "%s%c%s"
      Cmdliner_info.(term_name @@ eval_main ei) sep
      Cmdliner_info.(term_name @@ eval_term ei)

let plain_invocation ei = invocation ei
let invocation ?sep ei = esc @@ invocation ?sep ei

let synopsis_pos_arg a =
  let v = match Cmdliner_info.arg_docv a with "" -> "ARG" | v -> v in
  let v = strf "$(i,%s)" (esc v) in
  let v = (if Cmdliner_info.arg_is_req a then strf "%s" else strf "[%s]") v in
  match Cmdliner_info.(pos_len @@ arg_pos a) with
  | None -> v ^ "..."
  | Some 1 -> v
  | Some n ->
      let rec loop n acc = if n <= 0 then acc else loop (n - 1) (v :: acc) in
      String.concat " " (loop n [])

let synopsis ei = match Cmdliner_info.eval_kind ei with
| `Multiple_main -> strf "$(b,%s) $(i,COMMAND) ..." @@ invocation ei
| `Simple | `Multiple_sub ->
    let rev_cli_order (a0, _) (a1, _) =
      Cmdliner_info.rev_arg_pos_cli_order a0 a1
    in
    let add_pos a acc = match Cmdliner_info.arg_is_opt a with
    | true -> acc
    | false -> (a, synopsis_pos_arg a) :: acc
    in
    let args = Cmdliner_info.(term_args @@ eval_term ei) in
    let pargs = Cmdliner_info.Args.fold add_pos args [] in
    let pargs = List.sort rev_cli_order pargs in
    let pargs = String.concat " " (List.rev_map snd pargs) in
    strf "$(b,%s) [$(i,OPTION)]... %s" (invocation ei) pargs

let cmd_docs ei = match Cmdliner_info.eval_kind ei with
| `Simple | `Multiple_sub -> []
| `Multiple_main ->
    let add_cmd acc t =
      let cmd = strf "$(b,%s)" @@ term_name t in
      (Cmdliner_info.term_docs t, `I (cmd, Cmdliner_info.term_doc t)) :: acc
    in
    let by_sec_by_rev_name (s0, `I (c0, _)) (s1, `I (c1, _)) =
      let c = compare s0 s1 in
      if c <> 0 then c else compare c1 c0 (* N.B. reverse *)
    in
    let cmds = List.fold_left add_cmd [] (Cmdliner_info.eval_choices ei) in
    let cmds = List.sort by_sec_by_rev_name cmds in
    let cmds = (cmds :> (string * Cmdliner_manpage.block) list) in
    sorted_items_to_blocks ~boilerplate:None cmds

(* Argument docs *)

let arg_man_item_label a =
  if Cmdliner_info.arg_is_pos a
  then strf "$(i,%s)" (esc @@ Cmdliner_info.arg_docv a) else
  let fmt_name var = match Cmdliner_info.arg_opt_kind a with
  | Cmdliner_info.Flag -> fun n -> strf "$(b,%s)" (esc n)
  | Cmdliner_info.Opt ->
      fun n ->
        if String.length n > 2
        then strf "$(b,%s)=$(i,%s)" (esc n) (esc var)
        else strf "$(b,%s) $(i,%s)" (esc n) (esc var)
  | Cmdliner_info.Opt_vopt _ ->
      fun n ->
        if String.length n > 2
        then strf "$(b,%s)[=$(i,%s)]" (esc n) (esc var)
        else strf "$(b,%s) [$(i,%s)]" (esc n) (esc var)
  in
  let var = match Cmdliner_info.arg_docv a with "" -> "VAL" | v -> v in
  let names = List.sort compare (Cmdliner_info.arg_opt_names a) in
  let s = String.concat ", " (List.rev_map (fmt_name var) names) in
  s

let arg_to_man_item ~errs ~subst ~buf a =
  let or_env ~value a = match Cmdliner_info.arg_env a with
  | None -> ""
  | Some e ->
      let value = if value then " or" else "absent " in
      strf "%s $(b,%s) env" value (esc @@ Cmdliner_info.env_var e)
  in
  let absent = match Cmdliner_info.arg_absent a with
  | Cmdliner_info.Err -> "required"
  | Cmdliner_info.Val v ->
      match Lazy.force v with
      | "" -> strf "%s" (or_env ~value:false a)
      | v -> strf "absent=%s%s" v (or_env ~value:true a)
  in
  let optvopt = match Cmdliner_info.arg_opt_kind a with
  | Cmdliner_info.Opt_vopt v -> strf "default=%s" v
  | _ -> ""
  in
  let argvdoc = match optvopt, absent with
  | "", "" -> ""
  | s, "" | "", s -> strf " (%s)" s
  | s, s' -> strf " (%s) (%s)" s s'
  in
  let subst = arg_info_subst ~subst a in
  let doc = Cmdliner_info.arg_doc a in
  let doc = Cmdliner_manpage.subst_vars ~errs ~subst buf doc in
  (Cmdliner_info.arg_docs a, `I (arg_man_item_label a ^ argvdoc, doc))

let arg_docs ~errs ~subst ~buf ei =
  let by_sec_by_arg a0 a1 =
    let c = compare (Cmdliner_info.arg_docs a0) (Cmdliner_info.arg_docs a1) in
    if c <> 0 then c else
    match Cmdliner_info.arg_is_opt a0, Cmdliner_info.arg_is_opt a1 with
    | true, true -> (* optional by name *)
        let key names =
          let k = List.hd (List.sort rev_compare names) in
          let k = Cmdliner_base.lowercase k in
          if k.[1] = '-' then String.sub k 1 (String.length k - 1) else k
        in
        compare
          (key @@ Cmdliner_info.arg_opt_names a0)
          (key @@ Cmdliner_info.arg_opt_names a1)
    | false, false -> (* positional by variable *)
        compare
          (Cmdliner_base.lowercase @@ Cmdliner_info.arg_docv a0)
          (Cmdliner_base.lowercase @@ Cmdliner_info.arg_docv a1)
    | true, false -> -1 (* positional first *)
    | false, true -> 1  (* optional after *)
  in
  let keep_arg a acc =
    if not Cmdliner_info.(arg_is_pos a && (arg_docv a = "" || arg_doc a = ""))
    then (a :: acc) else acc
  in
  let args = Cmdliner_info.(term_args @@ eval_term ei) in
  let args = Cmdliner_info.Args.fold keep_arg args [] in
  let args = List.sort by_sec_by_arg args in
  let args = List.rev_map (arg_to_man_item ~errs ~subst ~buf) args in
  sorted_items_to_blocks ~boilerplate:None args

(* Exit statuses doc *)

let exit_boilerplate sec = match sec = Cmdliner_manpage.s_exit_status with
| false -> None
| true -> Some (Cmdliner_manpage.s_exit_status_intro)

let exit_docs ~errs ~subst ~buf ~has_sexit ei =
  let by_sec (s0, _) (s1, _) = compare s0 s1 in
  let add_exit_item acc e =
    let subst = exit_info_subst ~subst e in
    let min, max = Cmdliner_info.exit_statuses e in
    let doc = Cmdliner_info.exit_doc e in
    let label = if min = max then strf "%d" min else strf "%d-%d" min max in
    let item = `I (label, Cmdliner_manpage.subst_vars ~errs ~subst buf doc) in
    Cmdliner_info.(exit_docs e, item) :: acc
  in
  let exits = Cmdliner_info.(term_exits @@ eval_term ei) in
  let exits = List.sort Cmdliner_info.exit_order exits in
  let exits = List.fold_left add_exit_item [] exits in
  let exits = List.stable_sort by_sec (* sort by section *) exits in
  let boilerplate = if has_sexit then None else Some exit_boilerplate in
  sorted_items_to_blocks ~boilerplate exits

(* Environment doc *)

let env_boilerplate sec = match sec = Cmdliner_manpage.s_environment with
| false -> None
| true -> Some (Cmdliner_manpage.s_environment_intro)

let env_docs ~errs ~subst ~buf ~has_senv ei =
  let add_env_item ~subst (seen, envs as acc) e =
    if Cmdliner_info.Envs.mem e seen then acc else
    let seen = Cmdliner_info.Envs.add e seen in
    let var = strf "$(b,%s)" @@ esc (Cmdliner_info.env_var e) in
    let doc = Cmdliner_info.env_doc e in
    let doc = Cmdliner_manpage.subst_vars ~errs ~subst buf doc in
    let envs = (Cmdliner_info.env_docs e, `I (var, doc)) :: envs in
    seen, envs
  in
  let add_arg_env a acc = match Cmdliner_info.arg_env a with
  | None -> acc
  | Some e -> add_env_item ~subst:(arg_info_subst ~subst a) acc e
  in
  let add_env acc e = add_env_item ~subst:(env_info_subst ~subst e) acc e in
  let by_sec_by_rev_name (s0, `I (v0, _)) (s1, `I (v1, _)) =
    let c = compare s0 s1 in
    if c <> 0 then c else compare v1 v0 (* N.B. reverse *)
  in
  (* Arg envs before term envs is important here: if the same is mentioned
     both in an arg and in a term the substs of the arg are allowed. *)
  let args = Cmdliner_info.(term_args @@ eval_term ei) in
  let tenvs = Cmdliner_info.(term_envs @@ eval_term ei) in
  let init = Cmdliner_info.Envs.empty, [] in
  let acc = Cmdliner_info.Args.fold add_arg_env args init in
  let _, envs = List.fold_left add_env acc tenvs in
  let envs = List.sort by_sec_by_rev_name envs in
  let envs = (envs :> (string * Cmdliner_manpage.block) list) in
  let boilerplate = if has_senv then None else Some env_boilerplate in
  sorted_items_to_blocks ~boilerplate envs

(* xref doc *)

let xref_docs ~errs ei =
  let main = Cmdliner_info.(term_name @@ eval_main ei) in
  let to_xref = function
  | `Main -> main, 1
  | `Tool tool -> tool, 1
  | `Page (name, sec) -> name, sec
  | `Cmd c ->
      if Cmdliner_info.eval_has_choice ei c then strf "%s-%s" main c, 1 else
      (Format.fprintf errs "xref %s: no such term name@." c; "doc-err", 0)
  in
  let xref_str (name, sec) = strf "%s(%d)" (esc name) sec in
  let xrefs = Cmdliner_info.(term_man_xrefs @@ eval_term ei) in
  let xrefs = List.fold_left (fun acc x -> to_xref x :: acc) [] xrefs in
  let xrefs = List.(rev_map xref_str (sort rev_compare xrefs)) in
  if xrefs = [] then [] else
  [Cmdliner_manpage.s_see_also, `P (String.concat ", " xrefs)]

(* Man page construction *)

let ensure_s_name ei sm =
  if Cmdliner_manpage.(smap_has_section sm s_name) then sm else
  let tname = invocation ~sep:'-' ei in
  let tdoc = Cmdliner_info.(term_doc @@ eval_term ei) in
  let tagline = if tdoc = "" then "" else strf " - %s" tdoc in
  let tagline = `P (strf "%s%s" tname tagline) in
  Cmdliner_manpage.(smap_append_block sm ~sec:s_name tagline)

let ensure_s_synopsis ei sm =
  if Cmdliner_manpage.(smap_has_section sm ~sec:s_synopsis) then sm else
  let synopsis = `P (synopsis ei) in
  Cmdliner_manpage.(smap_append_block sm ~sec:s_synopsis synopsis)

let insert_term_man_docs ~errs ei sm =
  let buf = Buffer.create 200 in
  let subst = term_info_subst ei in
  let ins sm (s, b) = Cmdliner_manpage.smap_append_block sm s b in
  let has_senv = Cmdliner_manpage.(smap_has_section sm s_environment) in
  let has_sexit = Cmdliner_manpage.(smap_has_section sm s_exit_status) in
  let sm = List.fold_left ins sm (cmd_docs ei) in
  let sm = List.fold_left ins sm (arg_docs ~errs ~subst ~buf ei) in
  let sm = List.fold_left ins sm (exit_docs ~errs ~subst ~buf ~has_sexit ei)in
  let sm = List.fold_left ins sm (env_docs ~errs ~subst ~buf ~has_senv ei) in
  let sm = List.fold_left ins sm (xref_docs ~errs ei) in
  sm

let text ~errs ei =
  let man = Cmdliner_info.(term_man @@ eval_term ei) in
  let sm = Cmdliner_manpage.smap_of_blocks man in
  let sm = ensure_s_name ei sm in
  let sm = ensure_s_synopsis ei sm in
  let sm = insert_term_man_docs ei ~errs sm in
  Cmdliner_manpage.smap_to_blocks sm

let title ei =
  let main = Cmdliner_info.eval_main ei in
  let exec = Cmdliner_base.capitalize (Cmdliner_info.term_name main) in
  let name = Cmdliner_base.uppercase (invocation ~sep:'-' ei) in
  let center_header = esc @@ strf "%s Manual" exec in
  let left_footer =
    let version = match Cmdliner_info.term_version main with
    | None -> "" | Some v -> " " ^ v
    in
    esc @@ strf "%s%s" exec version
  in
  name, 1, "", left_footer, center_header

let man ~errs ei = title ei, text ~errs ei

let pp_man ~errs fmt ppf ei =
  Cmdliner_manpage.print
    ~errs ~subst:(term_info_subst ei) fmt ppf (man ~errs ei)

(* Plain synopsis for usage *)

let pp_plain_synopsis ~errs ppf ei =
  let buf = Buffer.create 100 in
  let subst = term_info_subst ei in
  let syn = Cmdliner_manpage.doc_to_plain ~errs ~subst buf (synopsis ei) in
  Format.fprintf ppf "@[%s@]" syn

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
