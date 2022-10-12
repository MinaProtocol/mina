
type t = {
    rosetta_host : string [@default "localhost"];
    rosetta_port : int [@default 3087];
  } [@@deriving make]

val rosetta_url : t -> string -> Uri.t
