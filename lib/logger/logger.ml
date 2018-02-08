open Core

module Level = struct
  type t =
    | Trace
    | Debug
    | Info
    | Warn
    | Error
    | Fatal
  [@@deriving sexp, bin_io, compare]
end

module Attribute = struct
  type t = string * Sexp.t

  let (^=) k v = (k, v)
end

module Message = struct
  type t =
    { attributes : Sexp.t String.Map.t
    ; level      : Level.t
    ; pid        : Pid.t
    ; host       : string
    ; time       : Time.t
    ; message    : string
    }
  [@@deriving sexp, bin_io]
end

type t =
  { attributes : Sexp.t String.Map.t
  ; level      : Level.t
  ; pid        : Pid.t
  ; host       : string
  }
[@@deriving sexp, bin_io]

let create ?(level=Level.Info) () =
  { attributes = String.Map.empty
  ; pid        = Unix.getpid ()
  ; host       = Unix.gethostname ()
  ; level
  }

let log ?level ?(attrs=[]) t fmt =
  ksprintf
    (fun message ->
       let m : Message.t =
         { attributes =
             List.fold attrs ~init:t.attributes ~f:(fun acc (key, data) ->
               String.Map.set acc ~key ~data)
         ; level = Option.value level ~default:t.level
         ; pid = t.pid
         ; host = t.host
         ; time = Time.now ()
         ; message
         }
       in
       printf !"%{sexp:Message.t}\n" m)
  fmt
;;

let () =
  let open Attribute in
  let t = create () in
  log t "%d" 23;
  log t ~attrs:[ "module" ^= [%sexp_of: string] "logger.ml"; "hello" ^=  [%sexp_of: int] 14]
    "%s = %d\n" "hello" 234;
;;
