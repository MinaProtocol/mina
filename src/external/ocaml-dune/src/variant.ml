open! Stdune

include Interned.Make(struct
    let initial_size = 256
    let resize_policy = Interned.Conservative
    let order = Interned.Fast
  end)()

let ppx_driver = make "ppx_driver"
let mt         = make "mt"
let mt_posix   = make "mt_posix"
let byte       = make "byte"
let native     = make "native"
let plugin     = make "plugin"
