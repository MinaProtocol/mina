(** Command-line arguments of [mina-archive run], as data. Every test engine
    and driver that starts an archive node builds its arguments here. *)

open Core_kernel

type t =
  { postgres_uri : string
  ; server_port : int
  ; config_file : string option
  ; log_json : bool
  }

let create ~postgres_uri ~server_port =
  { postgres_uri; server_port; config_file = None; log_json = false }

let to_list t =
  List.concat
    [ [ "-postgres-uri"; t.postgres_uri ]
    ; [ "-server-port"; Int.to_string t.server_port ]
    ; Option.value_map t.config_file ~default:[] ~f:(fun path ->
          [ "-config-file"; path ] )
    ; (if t.log_json then [ "-log-json" ] else [])
    ]
