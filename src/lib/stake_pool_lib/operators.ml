open Core_kernel

let ( -! ) x y = Option.value_exn (Currency.Amount.sub x y)

let ( +! ) x y = Option.value_exn (Currency.Amount.add x y)

let ( +~ ) x y = Option.value_exn (Currency.Amount.Signed.add x y)
