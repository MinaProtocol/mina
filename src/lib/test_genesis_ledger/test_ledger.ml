open Functor.With_private
open Core

include Make (struct
  let accounts =
    lazy
      (let balances =
         [ 
           10_000_000
          ;10_000_000
          ;10_000_000
          ;10_000_000
          ;10_000_000
          ;10_000_000
          ;10_000_000
          ;10_000_000
          ;10_000_000
          ;10_000_000
          ;10_000_000
          ;10_000_000
          ;10_000_000
          ;10_000_000
          ;10_000_000
         ]
       in
       let keypairs = Lazy.force Coda_base.Sample_keypairs.keypairs in
       List.mapi balances ~f:(fun i b ->
           let pk, sk = keypairs.(i) in
           {pk; sk; balance= b} ))
end)
