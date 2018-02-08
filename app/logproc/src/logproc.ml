open Core

module Color = struct
  type t =
    | Black
    | Red
    | Green
    | Yellow
    | Blue
    | Magenta
    | Cyan
    | White

  let to_int = function
    | Black -> 0 | Red     -> 1 | Green -> 2 | Yellow -> 3
    | Blue  -> 4 | Magenta -> 5 | Cyan  -> 6 | White  -> 7

  let color color text =
    sprintf "\027[38;5;%dm%s\027[0m" (to_int color) text
end

let color_of_level : Logger.Level.t -> Color.t = function
  | Trace -> Blue
  | Debug -> Green
  | Info -> Cyan
  | Warn -> Yellow
  | Error -> Red
  | Fatal -> Magenta

let colored_level level =
  Color.color (color_of_level level) (sprintf !"%{sexp:Logger.Level.t}" level)

let pretty_print_message
      { Logger.Message.attributes
      ; path
      ; level
      ; pid
      ; host
      ; time
      ; location
      ; message
      }
  =
  printf !"[%{Time}] %s (%{Pid} on %s): %s\n"
    time
    (colored_level level)
    pid
    host
    message;
  if not (Map.is_empty attributes)
  then begin
    printf !"%{sexp:Sexp.t String.Map.t}\n" attributes
  end
;;

