open! Stdune
open Import

type styles = Ansi_color.Style.t list

let apply_string styles str =
  sprintf "%s%s%s"
    (Ansi_color.Style.escape_sequence styles)
    str
    (Ansi_color.Style.escape_sequence [])

let colorize =
  let color_combos =
    let open Ansi_color.Color in
    [| Blue,          Bright_green
     ; Red,           Bright_yellow
     ; Yellow,        Blue
     ; Magenta,       Bright_cyan
     ; Bright_green,  Blue
     ; Bright_yellow, Red
     ; Blue,          Yellow
     ; Bright_cyan,   Magenta
    |]
  in
  fun ~key str ->
    let hash = Hashtbl.hash key in
    let fore, back = color_combos.(hash mod (Array.length color_combos)) in
    apply_string [Fg fore; Bg back] str

let stderr_supports_colors = lazy(
  Unix.(isatty stderr) &&
  match Env.get Env.initial "TERM" with
  | None        -> false
  | Some "dumb" -> false
  | Some _      -> true
)

let strip_colors_for_stderr s =
  if Lazy.force stderr_supports_colors then
    s
  else
    Ansi_color.strip s

(* We redirect the output of all commands, so by default the various
   tools will disable colors. Since we support colors in the output of
   commands, we force it via specific environment variables if stderr
   supports colors. *)
let setup_env_for_colors env =
  let set env var value =
    Env.update env ~var ~f:(function
      | None   -> Some value
      | Some s -> Some s)
  in
  let env = set env "OPAMCOLOR"   "always" in
  let env = set env "OCAML_COLOR" "always" in
  env

module Style = struct
  open Ansi_color.Style

  type t =
    | Loc
    | Error
    | Warning
    | Kwd
    | Id
    | Prompt
    | Details
    | Ok
    | Debug

  let to_styles = function
    | Loc     -> [Bold]
    | Error   -> [Bold; Fg Red]
    | Warning -> [Bold; Fg Magenta]
    | Kwd     -> [Bold; Fg Blue]
    | Id      -> [Bold; Fg Yellow]
    | Prompt  -> [Bold; Fg Green]
    | Details -> [Dim; Fg White]
    | Ok      -> [Dim; Fg Green]
    | Debug   -> [Underlined; Fg Bright_cyan]

  let of_string = function
    | "loc"     -> Some Loc
    | "error"   -> Some Error
    | "warning" -> Some Warning
    | "kwd"     -> Some Kwd
    | "id"      -> Some Id
    | "prompt"  -> Some Prompt
    | "details" -> Some Details
    | "ok"      -> Some Ok
    | "debug"   -> Some Debug
    | _         -> None
end

let styles_of_tag s =
  match Style.of_string s with
  | None -> []
  | Some style -> Style.to_styles style

let setup_err_formatter_colors () =
  let open Format in
  if Lazy.force stderr_supports_colors then begin
    List.iter [err_formatter; err_ppf] ~f:(fun ppf ->
      let funcs = pp_get_formatter_tag_functions ppf () in
      pp_set_mark_tags ppf true;
      pp_set_formatter_tag_functions ppf
        { funcs with
          mark_close_tag = (fun _   -> Ansi_color.Style.escape_sequence [])
        ; mark_open_tag  = (fun tag -> Ansi_color.Style.escape_sequence
                                         (styles_of_tag tag))
        })
  end

let output_filename : styles = [Bold; Fg Green]

module Render = Pp.Renderer.Make(struct
    type t = Style.t

    module Handler = struct
      include Ansi_color.Render.Tag.Handler

      let handle t style = handle t (Style.to_styles style)
    end
  end)
