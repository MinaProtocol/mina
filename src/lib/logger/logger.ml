open Core
open Async

module Level = struct
  type t = Trace | Debug | Info | Warn | Error | Faulty_peer | Fatal
  [@@deriving sexp, bin_io, compare]
end

module Attribute = struct
  type t = string * Sexp.t

  let ( ^= ) k v = (k, v)
end

module Message = struct
  type t =
    { attributes: Sexp.t String.Map.t
    ; path: string list
    ; level: Level.t
    ; pid: Pid.t
    ; host: string
    ; time: Time.t
    ; location: string option
    ; message: string }
  [@@deriving sexp, bin_io]
end

type t =
  { null: bool
  ; attributes: Sexp.t String.Map.t
  ; pid: Pid.t
  ; host: string
  ; path: string list }
[@@deriving sexp, bin_io]

let create () =
  { attributes= String.Map.empty
  ; null= false
  ; pid= Unix.getpid ()
  ; host= Unix.gethostname ()
  ; path= [] }

let null () =
  let l = create () in
  {l with null= true}

let log ~level ?loc ?(attrs = []) t fmt =
  ksprintf
    (fun message ->
      let m : Message.t =
        { attributes=
            List.fold attrs ~init:t.attributes ~f:(fun acc (key, data) ->
                Map.set acc ~key ~data )
        ; path= t.path
        ; pid= t.pid
        ; host= t.host
        ; time= Time.now ()
        ; level
        ; message
        ; location= loc }
      in
      if t.null then ifprintf stdout ""
      else printf !"%s\n" (Sexp.to_string_mach (Message.sexp_of_t m)) )
    fmt

let extend t attrs =
  { t with
    attributes=
      List.fold attrs ~init:t.attributes ~f:(fun acc (key, data) ->
          Map.set acc ~key ~data ) }

let child t s =
  { t with
    path= s :: t.path
  ; attributes=
      t.attributes
      |> Map.set ~key:"module" ~data:([%sexp_of: string] s)
      |> Map.set ~key:(sprintf "module-%s" s) ~data:([%sexp_of: bool] true) }

type 'a logger =
     ?loc:string
  -> ?attrs:Attribute.t list
  -> t
  -> ('a, unit, string, unit) format4
  -> 'a

let trace ?loc ?attrs t fmt = log ~level:Trace ?loc ?attrs t fmt

let debug ?loc ?attrs t fmt = log ~level:Debug ?loc ?attrs t fmt

let info ?loc ?attrs t fmt = log ~level:Info ?loc ?attrs t fmt

let warn ?loc ?attrs t fmt = log ~level:Warn ?loc ?attrs t fmt

let error ?loc ?attrs t fmt = log ~level:Error ?loc ?attrs t fmt

let fatal ?loc ?attrs t fmt = log ~level:Fatal ?loc ?attrs t fmt

let faulty_peer ?loc ?attrs t fmt = log ~level:Faulty_peer ?loc ?attrs t fmt
