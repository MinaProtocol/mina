open Core
open Mina_base.Zkapp_command

let check_two_elements_are_never_the_same () =
  Quickcheck.test ~trials:50 Valid_size.zkapp_type_gen ~f:(fun (x, _y) ->
      [%test_pred: Transaction_commitment.t * Transaction_commitment.t]
        (fun (a, b) -> not (Kimchi_backend.Pasta.Basic.Fp.equal a b))
        (get_transaction_commitments ~signature_kind:Mina_signature_kind.Testnet
           x ) )
