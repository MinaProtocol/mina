open Core

module Get_state_hash =
[%graphql
{|
query get_state_hash {
  blocks {
    state_hash
  }
}

|}]

let () = printf !"Hello Coda"
