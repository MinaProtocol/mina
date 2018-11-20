type t =
  { start : Lexing.position
  ; stop  : Lexing.position
  }

let in_file fn =
  let pos : Lexing.position =
    { pos_fname = fn
    ; pos_lnum  = 1
    ; pos_cnum  = 0
    ; pos_bol   = 0
    }
  in
  { start = pos
  ; stop = pos
  }

let in_dir = in_file

let none = in_file "<none>"

let of_lexbuf lexbuf : t =
  { start = Lexing.lexeme_start_p lexbuf
  ; stop  = Lexing.lexeme_end_p   lexbuf
  }

let sexp_of_position_no_file (p : Lexing.position) =
  let open Sexp.Encoder in
  record
    [ "pos_lnum", int p.pos_lnum
    ; "pos_bol", int p.pos_bol
    ; "pos_cnum", int p.pos_cnum
    ]

let to_sexp t =
  let open Sexp.Encoder in
  record (* TODO handle when pos_fname differs *)
    [ "pos_fname", string t.start.pos_fname
    ; "start", sexp_of_position_no_file t.start
    ; "stop", sexp_of_position_no_file t.stop
    ]

let equal_position
      { Lexing.pos_fname = f_a; pos_lnum = l_a
      ; pos_bol = b_a; pos_cnum = c_a }
      { Lexing.pos_fname = f_b; pos_lnum = l_b
      ; pos_bol = b_b; pos_cnum = c_b }
      =
      f_a = f_b
      && l_a = l_b
      && b_a = b_b
      && c_a = c_b

let equal
      { start = start_a ; stop = stop_a }
      { start = start_b ; stop = stop_b }
  =
  equal_position start_a start_b
  && equal_position stop_a stop_b

let of_pos (fname, lnum, cnum, enum) =
  let pos : Lexing.position =
    { pos_fname = fname
    ; pos_lnum  = lnum
    ; pos_cnum  = cnum
    ; pos_bol   = 0
    }
  in
  { start = pos
  ; stop  = { pos with pos_cnum = enum }
  }

let to_file_colon_line t =
  Printf.sprintf "%s:%d" t.start.pos_fname t.start.pos_lnum

let pp_file_colon_line ppf t =
  Format.pp_print_string ppf (to_file_colon_line t)
