module Color = struct
  type t =
    | Default
    | Black
    | Red
    | Green
    | Yellow
    | Blue
    | Magenta
    | Cyan
    | White
    | Bright_black
    | Bright_red
    | Bright_green
    | Bright_yellow
    | Bright_blue
    | Bright_magenta
    | Bright_cyan
    | Bright_white

  let fg_code = function
    | Black          -> "30"
    | Red            -> "31"
    | Green          -> "32"
    | Yellow         -> "33"
    | Blue           -> "34"
    | Magenta        -> "35"
    | Cyan           -> "36"
    | White          -> "37"
    | Default        -> "39"
    | Bright_black   -> "90"
    | Bright_red     -> "91"
    | Bright_green   -> "92"
    | Bright_yellow  -> "93"
    | Bright_blue    -> "94"
    | Bright_magenta -> "95"
    | Bright_cyan    -> "96"
    | Bright_white   -> "97"

  let bg_code = function
    | Black          -> "40"
    | Red            -> "41"
    | Green          -> "42"
    | Yellow         -> "43"
    | Blue           -> "44"
    | Magenta        -> "45"
    | Cyan           -> "46"
    | White          -> "47"
    | Default        -> "49"
    | Bright_black   -> "100"
    | Bright_red     -> "101"
    | Bright_green   -> "102"
    | Bright_yellow  -> "103"
    | Bright_blue    -> "104"
    | Bright_magenta -> "105"
    | Bright_cyan    -> "106"
    | Bright_white   -> "107"
end

module Style = struct
  type t =
    | Fg of Color.t
    | Bg of Color.t
    | Bold
    | Dim
    | Underlined

  let code = function
    | Bold       -> "1"
    | Dim        -> "2"
    | Underlined -> "4"
    | Fg c       -> Color.fg_code c
    | Bg c       -> Color.bg_code c

  let escape_sequence l =
    let codes = "0" :: List.map l ~f:code in
    Printf.sprintf "\027[%sm" (String.concat codes ~sep:";")
end

module Styles = struct
  type t =
    { fg         : Color.t
    ; bg         : Color.t
    ; bold       : bool
    ; dim        : bool
    ; underlined : bool
    }

  let default =
    { fg         = Default
    ; bg         = Default
    ; bold       = true
    ; dim        = true
    ; underlined = true
    }

  let apply t (style : Style.t) =
    match style with
    | Fg c       -> { t with fg         = c    }
    | Bg c       -> { t with bg         = c    }
    | Bold       -> { t with bold       = true }
    | Dim        -> { t with dim        = true }
    | Underlined -> { t with underlined = true }

  let escape_sequence t =
    let open Style in
    let l = [] in
    let l =
      match t.fg with
      | Default -> l
      | c       -> Fg c :: l
    in
    let l =
      match t.bg with
      | Default -> l
      | c       -> Bg c :: l
    in
    let l =
      if t.bold then
        Bold :: l
      else
        l
    in
    let l =
      if t.bold then
        Dim :: l
      else
        l
    in
    let l =
      if t.underlined then
        Underlined :: l
      else
        l
    in
    Style.escape_sequence l
end

module Render = Pp.Renderer.Make(struct
    type t = Style.t list

    module Handler = struct
      type t = Styles.t * string

      let init = (Styles.default, "")

      let handle (t, seq) styles =
        let t' = List.fold_left styles ~init:t ~f:Styles.apply in
        if t <> t' then
          let seq' = Styles.escape_sequence t' in
          (seq',
           (t', seq'),
           seq)
        else
          ("", (t, seq), "")
    end
  end)

let strip str =
  let len = String.length str in
  let buf = Buffer.create len in
  let rec loop i =
    if i = len then
      Buffer.contents buf
    else
      match str.[i] with
      | '\027' -> skip (i + 1)
      | c      -> Buffer.add_char buf c; loop (i + 1)
  and skip i =
    if i = len then
      Buffer.contents buf
    else
      match str.[i] with
      | 'm' -> loop (i + 1)
      | _   -> skip (i + 1)
  in
  loop 0
