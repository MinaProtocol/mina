open Functor.With_private
open Core

include Make (struct
  let accounts =
    (* zeroth account becomes delegatee; first account is a placeholder; second account is delegator *)
    lazy
      (let balances = [0; 0; 5_000_000] in
       let keypairs = Lazy.force Coda_base.Sample_keypairs.keypairs in
       List.mapi balances ~f:(fun i b ->
           {balance= b; pk= fst keypairs.(i); sk= snd keypairs.(i)} ))
end)
