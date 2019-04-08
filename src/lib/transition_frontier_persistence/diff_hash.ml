open Core
open Digestif.SHA256

type nonrec t = t

include Binable.Of_stringable (struct
  type nonrec t = t

  let of_string = of_hex

  let to_string = to_hex
end)

let equal t1 t2 = eq t1 t2

let empty = digest_string ""

let merge t1 string = digestv_string [to_hex t1; string]
