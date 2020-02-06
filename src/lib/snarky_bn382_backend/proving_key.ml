open Core
open Snarky_bn382

type t = Fp_index.t

include Binable.Of_binable
          (Unit)
          (struct
            type t = Fp_index.t

            let to_binable _ = ()

            let of_binable () = failwith "TODO"
          end)

let is_initialized _ = `Yes

let set_constraint_system _ _ = ()

let to_string _ = failwith "TODO"

let of_string _ = failwith "TODO"
