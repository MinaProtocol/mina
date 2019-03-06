open Functor.With_private
open Core

(* TODO: generate new keypairs before public testnet *)
include Make (struct
  let accounts =
    let balances =
      [ 5_000_000
      ; 5_000_000
      ; 5_000_000
      ; 5_000_000
      ; 5_000_000
      ; 1_000
      ; 1_000
      ; 1_000
      ; 1_000
      ; 1_000
      ; 1_000
      ; 1_000
      ; 1_000
      ; 1_000
      ; 1_000
      ; 1_000
      ; 1_000
      ; 1_000 ]
    in
    List.mapi balances ~f:(fun i b ->
        { balance= b
        ; pk= fst Coda_base.Sample_keypairs.keypairs.(i)
        ; sk= snd Coda_base.Sample_keypairs.keypairs.(i) } )
end)
