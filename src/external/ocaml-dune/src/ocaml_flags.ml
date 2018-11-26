open! Stdune
open Import
open Build.O

let default_ocamlc_flags   = ["-g"]
let default_ocamlopt_flags = ["-g"]

let dev_mode_warnings =
  "@a" ^
  String.concat ~sep:""
    (List.map ~f:(sprintf "-%d")
       [ 4
       ; 29
       ; 40
       ; 41
       ; 42
       ; 44
       ; 45
       ; 48
       ; 58
       ; 59
       ; 60
       ])

let default_warnings =
  "-40"

let default_flags ~profile =
  if profile = "dev" then
    [ "-w"; dev_mode_warnings ^ default_warnings
    ; "-strict-sequence"
    ; "-strict-formats"
    ; "-short-paths"
    ; "-keep-locs"
    ]
  else
    [ "-w"; default_warnings ]

type t =
  { common     : (unit, string list) Build.t
  ; specific   : (unit, string list) Build.t Mode.Dict.t
  }

let empty =
  let build = Build.arr (fun () -> []) in
  { common   = build
  ; specific = Mode.Dict.make_both build
  }

let of_list l =
  { empty with common = Build.arr (fun () -> l) }

let default ~profile =
  { common = Build.return (default_flags ~profile)
  ; specific =
      { byte   = Build.return default_ocamlc_flags
      ; native = Build.return default_ocamlopt_flags
      }
  }

let make ~flags ~ocamlc_flags ~ocamlopt_flags ~default ~eval =
  let f name x standard =
    Build.memoize name
      (if Ordered_set_lang.Unexpanded.has_special_forms x then
         eval x ~standard
       else
         eval x ~standard:(Build.return []))
  in
  { common = f "common flags" flags default.common
  ; specific =
      { byte   = f "ocamlc flags"   ocamlc_flags   default.specific.byte
      ; native = f "ocamlopt flags" ocamlopt_flags default.specific.native
      }
  }

let get t mode =
  t.common
  &&&
  (Mode.Dict.get t.specific mode)
  >>^ fun (common, specific) ->
  common @ specific

let get_for_cm t ~cm_kind = get t (Mode.of_cm_kind cm_kind)

let append_common t flags = {t with common = t.common >>^ fun l -> l @ flags}

let prepend_common flags t = {t with common = t.common >>^ fun l -> flags @ l}

let common t = t.common

let dump t =
  Build.fanout3 t.common t.specific.byte t.specific.native
  >>^ fun (common, byte, native) ->
  List.map ~f:Dune_lang.Encoder.(pair string (list string))
    [  "flags"         , common
    ; "ocamlc_flags"   , byte
    ; "ocamlopt_flags" , native
    ]
