(* Fallback values shared by every Rosetta CLI.  See [defaults.mli]. *)

let base_uri = "http://localhost:3087"

let blockchain = "mina"

let network = "testnet"

(* Seconds allowed for one request/response exchange with the Rosetta
   server, measured from sending the request to reading the last byte of
   the response body. *)
let http_timeout = 5.0
