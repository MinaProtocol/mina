open Core_kernel
open Banlist_lib

module Punishment_record :
  Banlist.Punishment.Record.S
  with type time := Time.t
   and type score := Banlist.Score.t

include
  Banlist.S
  with type peer := Host_and_port.t
   and type record := Punishment_record.t
   and type offense := Banlist.Offense.t

val create : suspicious_dir:string -> punished_dir:string -> t
