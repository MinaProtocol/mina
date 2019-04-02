open Functor.With_private
open Core

(* TODO: generate new keypairs before public testnet *)
include Make (struct
  let accounts =
    let high_balances = List.init 1 ~f:(Fn.const 10_000_000) in
    let low_balances = List.init 17 ~f:(Fn.const 1_000) in
    let balances = high_balances @ low_balances in
    List.mapi balances ~f:(fun i b ->
        { balance= b
        ; pk= fst Coda_base.Sample_keypairs.keypairs.(i)
        ; sk= snd Coda_base.Sample_keypairs.keypairs.(i) } )
end)
