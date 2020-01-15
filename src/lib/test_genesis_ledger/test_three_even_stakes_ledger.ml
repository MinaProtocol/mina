open Functor.With_private
open Core

include Make (struct
  let accounts =
    lazy
      (let keypairs = Lazy.force Coda_base.Sample_keypairs.keypairs in
       let balances = [1_000_000; 1_000_000; 1_000_000; 1000; 1000; 1000] in
       List.mapi balances ~f:(fun i b ->
           {balance= b; pk= fst keypairs.(i); sk= snd keypairs.(i)} ))
end)
