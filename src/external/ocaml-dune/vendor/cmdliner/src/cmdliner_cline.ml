(*---------------------------------------------------------------------------
   Copyright (c) 2011 Daniel C. Bünzli. All rights reserved.
   Distributed under the ISC license, see terms at the end of the file.
   cmdliner v1.0.0
  ---------------------------------------------------------------------------*)

open Result

(* A command line stores pre-parsed information about the command
   line's arguments in a more structured way. Given the
   Cmdliner_info.arg values mentioned in a term and Sys.argv
   (without exec name) we parse the command line into a map of
   Cmdliner_info.arg values to [arg] values (see below). This map is used by
   the term's closures to retrieve and convert command line arguments
   (see the Cmdliner_arg module). *)

let err_multi_opt_name_def name a a' =
  Cmdliner_base.err_multi_def
    ~kind:"option name" name Cmdliner_info.arg_doc a a'

module Amap = Map.Make (Cmdliner_info.Arg)

type arg =      (* unconverted argument data as found on the command line. *)
| O of (int * string * (string option)) list (* (pos, name, value) of opt. *)
| P of string list

type t = arg Amap.t  (* command line, maps arg_infos to arg value. *)

let get_arg cl a = try Amap.find a cl with Not_found -> assert false
let opt_arg cl a = match get_arg cl a with O l -> l | _ -> assert false
let pos_arg cl a = match get_arg cl a with P l -> l | _ -> assert false

let arg_info_indexes args =
  (* from [args] returns a trie mapping the names of optional arguments to
     their arg_info, a list with all arg_info for positional arguments and
     a cmdline mapping each arg_info to an empty [arg]. *)
  let rec loop optidx posidx cl = function
  | [] -> optidx, posidx, cl
  | a :: l ->
      match Cmdliner_info.arg_is_pos a with
      | true -> loop optidx (a :: posidx) (Amap.add a (P []) cl) l
      | false ->
          let add t name = match Cmdliner_trie.add t name a with
          | `New t -> t
          | `Replaced (a', _) -> invalid_arg (err_multi_opt_name_def name a a')
          in
          let names = Cmdliner_info.arg_opt_names a in
          let optidx = List.fold_left add optidx names in
          loop optidx posidx (Amap.add a (O []) cl) l
  in
  loop Cmdliner_trie.empty [] Amap.empty (Cmdliner_info.Args.elements args)

(* Optional argument parsing *)

let is_opt s = String.length s > 1 && s.[0] = '-'
let is_short_opt s = String.length s = 2 && s.[0] = '-'

let parse_opt_arg s = (* (name, value) of opt arg, assert len > 1. *)
  let l = String.length s in
  if s.[1] <> '-' then (* short opt *)
    if l = 2 then s, None else
    String.sub s 0 2, Some (String.sub s 2 (l - 2)) (* with glued opt arg *)
  else try (* long opt *)
    let i = String.index s '=' in
    String.sub s 0 i, Some (String.sub s (i + 1) (l - i - 1))
  with Not_found -> s, None

let hint_matching_opt optidx s =
  (* hint options that could match [s] in [optidx]. FIXME explain this is
     a bit obscure. *)
  if String.length s <= 2 then [] else
  let short_opt, long_opt =
    if s.[1] <> '-'
    then s, Printf.sprintf "-%s" s
    else String.sub s 1 (String.length s - 1), s
  in
  let short_opt, _ = parse_opt_arg short_opt in
  let long_opt, _ = parse_opt_arg long_opt in
  let all = Cmdliner_trie.ambiguities optidx "-" in
  match List.mem short_opt all, Cmdliner_suggest.value long_opt all with
  | false, [] -> []
  | false, l -> l
  | true, [] -> [short_opt]
  | true, l -> if List.mem short_opt l then l else short_opt :: l

let parse_opt_args ~peek_opts optidx cl args =
  (* returns an updated [cl] cmdline according to the options found in [args]
     with the trie index [optidx]. Positional arguments are returned in order
     in a list. *)
  let rec loop errs k cl pargs = function
  | [] -> List.rev errs, cl, List.rev pargs
  | "--" :: args -> List.rev errs, cl, (List.rev_append pargs args)
  | s :: args ->
      if not (is_opt s) then loop errs (k + 1) cl (s :: pargs) args else
      let name, value = parse_opt_arg s in
      match Cmdliner_trie.find optidx name with
      | `Ok a ->
          let value, args = match value, Cmdliner_info.arg_opt_kind a with
          | Some v, Cmdliner_info.Flag when is_short_opt name ->
              None, ("-" ^ v) :: args
          | Some _, _ -> value, args
          | None, Cmdliner_info.Flag -> value, args
          | None, _ ->
              match args with
              | [] -> None, args
              | v :: rest -> if is_opt v then None, args else Some v, rest
          in
          let arg = O ((k, name, value) :: opt_arg cl a) in
          loop errs (k + 1) (Amap.add a arg cl) pargs args
      | `Not_found when peek_opts -> loop errs (k + 1) cl pargs args
      | `Not_found ->
          let hints = hint_matching_opt optidx s in
          let err = Cmdliner_base.err_unknown ~kind:"option" ~hints name in
          loop (err :: errs) (k + 1) cl pargs args
      | `Ambiguous ->
          let ambs = Cmdliner_trie.ambiguities optidx name in
          let ambs = List.sort compare ambs in
          let err = Cmdliner_base.err_ambiguous "option" name ambs in
          loop (err :: errs) (k + 1) cl pargs args
  in
  let errs, cl, pargs = loop [] 0 cl [] args in
  if errs = [] then Ok (cl, pargs) else
  let err = String.concat "\n" errs in
  Error (err, cl, pargs)

let take_range start stop l =
  let rec loop i acc = function
  | [] -> List.rev acc
  | v :: vs ->
      if i < start then loop (i + 1) acc vs else
      if i <= stop then loop (i + 1) (v :: acc) vs else
      List.rev acc
  in
  loop 0 [] l

let process_pos_args posidx cl pargs =
  (* returns an updated [cl] cmdline in which each positional arg mentioned
     in the list index posidx, is given a value according the list
     of positional arguments values [pargs]. *)
  if pargs = [] then
    let misses = List.filter Cmdliner_info.arg_is_req posidx in
    if misses = [] then Ok cl else
    Error (Cmdliner_msg.err_pos_misses misses, cl)
  else
  let last = List.length pargs - 1 in
  let pos rev k = if rev then last - k else k in
  let rec loop misses cl max_spec = function
  | [] -> misses, cl, max_spec
  | a :: al ->
      let apos = Cmdliner_info.arg_pos a in
      let rev = Cmdliner_info.pos_rev apos in
      let start = pos rev (Cmdliner_info.pos_start apos) in
      let stop = match Cmdliner_info.pos_len apos with
      | None -> pos rev last
      | Some n -> pos rev (Cmdliner_info.pos_start apos + n - 1)
      in
      let start, stop = if rev then stop, start else start, stop in
      let args = take_range start stop pargs in
      let max_spec = max stop max_spec in
      let cl = Amap.add a (P args) cl in
      let misses = match Cmdliner_info.arg_is_req a && args = [] with
      | true -> a :: misses
      | false -> misses
      in
      loop misses cl max_spec al
  in
  let misses, cl, max_spec = loop [] cl (-1) posidx in
  if misses <> [] then Error (Cmdliner_msg.err_pos_misses misses, cl) else
  if last <= max_spec then Ok cl else
  let excess = take_range (max_spec + 1) last pargs in
  Error (Cmdliner_msg.err_pos_excess excess, cl)

let create ?(peek_opts = false) al args =
  let optidx, posidx, cl = arg_info_indexes al in
  match parse_opt_args ~peek_opts optidx cl args with
  | Ok (cl, _) when peek_opts -> Ok cl
  | Ok (cl, pargs) -> process_pos_args posidx cl pargs
  | Error (errs, cl, _) -> Error (errs, cl)

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
