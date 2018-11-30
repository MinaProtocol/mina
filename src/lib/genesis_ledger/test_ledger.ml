open Functor.With_private
open Core

include Make (struct
  let accounts =
    let balances =
      [ 10_000_000
      ; 100
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
      ; 1_000
      ; 1_000
      ; 1_000
      ; 1_000 ]
    in
    List.mapi balances ~f:(fun i b ->
        let pk, sk = Coda_base.Sample_keypairs.keypairs.(i) in
        {pk; sk; balance= b} )
end)
