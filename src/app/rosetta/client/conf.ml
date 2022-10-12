
type t = {
    rosetta_host : string [@default "localhost"];
    rosetta_port : int [@default 3087];
  } [@@deriving make]

let rosetta_url conf uri =
  Uri.make ~host:conf.rosetta_host ~port:conf.rosetta_port ~path:uri ()
