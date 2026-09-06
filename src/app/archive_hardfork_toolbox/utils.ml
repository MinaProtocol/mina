open Core

(* General-purpose terminal-UI helpers. *)

(* Display width of a UTF-8 string, counting each code point as one column
   (continuation bytes 0b10xxxxxx do not add width). Good enough for the
   box-drawing and arrow glyphs used in tables; it does not account for
   double-width (CJK) characters. *)
let display_width s =
  String.fold s ~init:0 ~f:(fun acc c ->
      if Char.to_int c land 0xC0 = 0x80 then acc else acc + 1 )

(* Right-pad [s] with spaces to [width] display columns (no-op if already wider). *)
let pad_right width s =
  let d = display_width s in
  if d >= width then s else s ^ String.make (width - d) ' '

(* A horizontal rule of [width] "─" box-drawing characters. *)
let hline width = String.concat ~sep:"" (List.init width ~f:(fun _ -> "─"))

(* Render an aligned table with box-drawing column separators and a header rule.
   [columns] pairs each header label with its column width. Each row is its list
   of cells (one per column) plus a trailing suffix rendered outside the last
   column border (e.g. a row marker). Returns the whole table, newline-terminated. *)
let render_table ~columns rows =
  let widths = List.map columns ~f:snd in
  let render_cells cells =
    List.map2_exn cells widths ~f:(fun cell w -> pad_right w cell)
    |> String.concat ~sep:" │ "
  in
  let header = "  " ^ render_cells (List.map columns ~f:fst) in
  let rule = "  " ^ (List.map widths ~f:hline |> String.concat ~sep:"─┼─") in
  let body =
    List.map rows ~f:(fun (cells, suffix) -> "  " ^ render_cells cells ^ suffix)
  in
  String.concat ~sep:"\n" ((header :: rule :: body) @ [ "" ])
