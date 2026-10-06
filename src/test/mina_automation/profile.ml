(** A node profile. The binaries resolve theirs at runtime from MINA_PROFILE
    and have no default, so a test that starts one must say which. *)

type t = Dev | Devnet | Lightnet | Mainnet

(** The name node_config reads: ["dev"], ["devnet"], ["lightnet"],
    ["mainnet"]. *)
let to_string = function
  | Dev ->
      "dev"
  | Devnet ->
      "devnet"
  | Lightnet ->
      "lightnet"
  | Mainnet ->
      "mainnet"

(** The environment that selects this profile. *)
let env t = [ ("MINA_PROFILE", to_string t) ]
