let match_all_once ~match_list l =
  let pp_error ~reason (name, opt_str) =
    Format.asprintf "%s: %s \"%a\"" reason name
      (Format.pp_print_option ?none:None Format.pp_print_string)
      (Option.map String.escaped opt_str)
  in
  let fail ~reason x = failwith (pp_error ~reason x) in
  (* Warning: O(n^2) *)
  let rec go match_list skipped_list got_list =
    match (match_list, got_list) with
    | [], [] ->
        ()
    | [], got :: _ ->
        fail ~reason:"Unexpected annotation" got
    | expected :: _, [] ->
        fail ~reason:"Missing annotation" expected
    | (expected_name, None) :: expected_tl, (got_name, None) :: got_tl
      when String.equal expected_name got_name ->
        go (List.rev_append skipped_list expected_tl) [] got_tl
    | ( (expected_name, Some expected_value) :: expected_tl
      , (got_name, Some got_value) :: got_tl )
      when String.equal expected_name got_name
           && String.equal expected_value got_value ->
        go (List.rev_append skipped_list expected_tl) [] got_tl
    | expected :: expected_tl, _ ->
        go expected_tl (expected :: skipped_list) got_list
  in
  go match_list [] l

module No_annotations = struct
  type t = { a : int } [@@deriving annot]

  let test () =
    (* Toplevel annotations *)
    (match t_toplevel_annots () with [] -> () | _ -> assert false) ;
    (* Field annotations *)
    (match t_fields_annots "a" with [] -> () | _ -> assert false) ;
    (* Missing field is not resolved *)
    match t_fields_annots "b" with _ -> assert false | exception _ -> ()
end

module Toplevel_doc_comment = struct
  (** This is a doc-comment on the toplevel type. *)
  type t = { a : int } [@@deriving annot]

  let test () =
    (* Toplevel annotations *)
    ( match t_toplevel_annots () with
    | [ ("ocaml.doc", Some " This is a doc-comment on the toplevel type. ") ] ->
        ()
    | _ ->
        assert false ) ;
    (* Field annotations *)
    (match t_fields_annots "a" with [] -> () | _ -> assert false) ;
    (* Missing field is not resolved *)
    match t_fields_annots "b" with _ -> assert false | exception _ -> ()
end

module Toplevel_string_annot = struct
  type t = { a : int } [@@deriving annot] [@@foo "bar"]

  let test () =
    (* Toplevel annotations *)
    ( match t_toplevel_annots () with
    | [ ("foo", Some "bar") ] ->
        ()
    | _ ->
        assert false ) ;
    (* Field annotations *)
    (match t_fields_annots "a" with [] -> () | _ -> assert false) ;
    (* Missing field is not resolved *)
    match t_fields_annots "b" with _ -> assert false | exception _ -> ()
end

module Toplevel_argless_annot = struct
  type t = { a : int } [@@deriving annot] [@@foo]

  let test () =
    (* Toplevel annotations *)
    ( match t_toplevel_annots () with
    | [ ("foo", None) ] ->
        ()
    | _ ->
        assert false ) ;
    (* Field annotations *)
    (match t_fields_annots "a" with [] -> () | _ -> assert false) ;
    (* Missing field is not resolved *)
    match t_fields_annots "b" with _ -> assert false | exception _ -> ()
end

module Toplevel_all = struct
  (** Comment *)
  type t = { a : int } [@@deriving annot] [@@foo "bar"] [@@baz]

  let test () =
    (* Toplevel annotations *)
    match_all_once
      ~match_list:
        [ ("ocaml.doc", Some " Comment "); ("foo", Some "bar"); ("baz", None) ]
      (t_toplevel_annots ()) ;
    (* Field annotations *)
    (match t_fields_annots "a" with [] -> () | _ -> assert false) ;
    (* Missing field is not resolved *)
    match t_fields_annots "b" with _ -> assert false | exception _ -> ()
end

module Field_doc_comment = struct
  type t = { a : int  (** This is a comment on a field *) } [@@deriving annot]

  let test () =
    (* Toplevel annotations *)
    (match t_toplevel_annots () with [] -> () | _ -> assert false) ;
    (* Field annotations *)
    ( match t_fields_annots "a" with
    | [ ("ocaml.doc", Some " This is a comment on a field ") ] ->
        ()
    | _ ->
        assert false ) ;
    (* Missing field is not resolved *)
    match t_fields_annots "b" with _ -> assert false | exception _ -> ()
end

module Fields_doc_comments = struct
  type 'c t =
    { a : int  (** This is a comment on field a *)
    ; b : bool  (** This is a comment on field b *)
    ; c : 'c  (** This is a comment on field c *)
    }
  [@@deriving annot]

  let test () =
    (* Toplevel annotations *)
    (match t_toplevel_annots () with [] -> () | _ -> assert false) ;
    (* Field annotations *)
    ( match t_fields_annots "a" with
    | [ (annot_name, Some str) ] ->
        assert (String.equal annot_name "ocaml.doc") ;
        assert (String.equal str " This is a comment on field a ")
    | _ ->
        assert false ) ;
    ( match t_fields_annots "b" with
    | [ (annot_name, Some str) ] ->
        assert (String.equal annot_name "ocaml.doc") ;
        assert (String.equal str " This is a comment on field b ")
    | _ ->
        assert false ) ;
    ( match t_fields_annots "c" with
    | [ (annot_name, Some str) ] ->
        assert (String.equal annot_name "ocaml.doc") ;
        assert (String.equal str " This is a comment on field c ")
    | _ ->
        assert false ) ;
    (* Missing field is not resolved *)
    match t_fields_annots "d" with _ -> assert false | exception _ -> ()
end

module Field_string_annot = struct
  type t = { a : int [@foo "bar"] } [@@deriving annot]

  let test () =
    (* Toplevel annotations *)
    (match t_toplevel_annots () with [] -> () | _ -> assert false) ;
    (* Field annotations *)
    ( match t_fields_annots "a" with
    | [ ("foo", Some "bar") ] ->
        ()
    | _ ->
        assert false ) ;
    (* Missing field is not resolved *)
    match t_fields_annots "b" with _ -> assert false | exception _ -> ()
end

module Field_argless_annot = struct
  type t = { a : int [@foo] } [@@deriving annot]

  let test () =
    (* Toplevel annotations *)
    (match t_toplevel_annots () with [] -> () | _ -> assert false) ;
    (* Field annotations *)
    ( match t_fields_annots "a" with
    | [ ("foo", None) ] ->
        ()
    | _ ->
        assert false ) ;
    (* Missing field is not resolved *)
    match t_fields_annots "b" with _ -> assert false | exception _ -> ()
end

module Fields_all = struct
  type 'c t =
    { a : int [@foo "bar_a"] [@baz_a]  (** This is a comment on field a *)
    ; b : bool [@foo "bar_b"] [@baz_b]  (** This is a comment on field b *)
    ; c : 'c [@foo "bar_c"] [@baz_c]  (** This is a comment on field c *)
    }
  [@@deriving annot]

  let test () =
    (* Toplevel annotations *)
    (match t_toplevel_annots () with [] -> () | _ -> assert false) ;
    (* Field annotations *)
    match_all_once
      ~match_list:
        [ ("ocaml.doc", Some " This is a comment on field a ")
        ; ("foo", Some "bar_a")
        ; ("baz_a", None)
        ]
      (t_fields_annots "a") ;
    match_all_once
      ~match_list:
        [ ("ocaml.doc", Some " This is a comment on field b ")
        ; ("foo", Some "bar_b")
        ; ("baz_b", None)
        ]
      (t_fields_annots "b") ;
    match_all_once
      ~match_list:
        [ ("ocaml.doc", Some " This is a comment on field c ")
        ; ("foo", Some "bar_c")
        ; ("baz_c", None)
        ]
      (t_fields_annots "c") ;
    (* Missing field is not resolved *)
    match t_fields_annots "d" with _ -> assert false | exception _ -> ()
end

module All = struct
  (** Comment *)
  type 'c t =
    { a : int [@foo "bar"] [@baz]  (** This is a comment on field a *)
    ; b : bool [@foo "bar"] [@baz]  (** This is a comment on field b *)
    ; c : 'c [@foo "bar"] [@baz]  (** This is a comment on field c *)
    }
  [@@deriving annot] [@@foo "bar"] [@@baz]

  let test () =
    (* Toplevel annotations *)
    match_all_once
      ~match_list:
        [ ("ocaml.doc", Some " Comment "); ("foo", Some "bar"); ("baz", None) ]
      (t_toplevel_annots ()) ;
    (* Field annotations *)
    match_all_once
      ~match_list:
        [ ("ocaml.doc", Some " This is a comment on field a ")
        ; ("foo", Some "bar")
        ; ("baz", None)
        ]
      (t_fields_annots "a") ;
    match_all_once
      ~match_list:
        [ ("ocaml.doc", Some " This is a comment on field b ")
        ; ("foo", Some "bar")
        ; ("baz", None)
        ]
      (t_fields_annots "b") ;
    match_all_once
      ~match_list:
        [ ("ocaml.doc", Some " This is a comment on field c ")
        ; ("foo", Some "bar")
        ; ("baz", None)
        ]
      (t_fields_annots "c") ;
    (* Missing field is not resolved *)
    match t_fields_annots "d" with _ -> assert false | exception _ -> ()
end

let test_all () =
  No_annotations.test () ;
  Toplevel_doc_comment.test () ;
  Toplevel_string_annot.test () ;
  Toplevel_argless_annot.test () ;
  Toplevel_all.test () ;
  Field_doc_comment.test () ;
  Fields_doc_comments.test () ;
  Field_string_annot.test () ;
  Field_argless_annot.test () ;
  Fields_all.test () ;
  All.test ()

let () = test_all ()
