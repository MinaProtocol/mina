open Core
open Snark_params

include Snarky.Test_util.Make(Tick)

let with_randomness r f =
  let s = Caml.Random.get_state () in
  Random.init r;
  try begin
    let x = f () in
    Caml.Random.set_state s;
    x
  end with e -> begin
    Caml.Random.set_state s;
    raise e
  end

