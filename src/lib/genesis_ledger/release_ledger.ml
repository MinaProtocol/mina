(* TODO: replace with release ledger *)
open Core_kernel

let name = "release"

let balances =
  lazy
    (let high_balances = List.init 1 ~f:(Fn.const 10_000_000) in
     let low_balances = List.init 17 ~f:(Fn.const 1_000) in
     high_balances @ low_balances )
