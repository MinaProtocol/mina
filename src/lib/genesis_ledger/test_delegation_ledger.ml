open Functor.With_private
open Core

include Make (struct
  let accounts =
    (* zeroth account becomes delegatee; first account is a placeholder; second account is delegator *)
    let balances = [0; 0; 5_000_000] in
    List.mapi balances ~f:(fun i b ->
        { balance= b
        ; pk= fst Coda_base.Sample_keypairs.keypairs.(i)
        ; sk= snd Coda_base.Sample_keypairs.keypairs.(i) } )
end)
