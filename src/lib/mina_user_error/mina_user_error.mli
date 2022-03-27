exception Mina_user_error of { message : string; where : string option }

val raisef : ?where:string -> ('a, unit, string, 'b) format4 -> 'a

val raise : ?where:string -> string -> 'a
