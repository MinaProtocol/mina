(* receipt.ml *)

[%%import
"/src/config.mlh"]

open Core_kernel

[%%ifdef
consensus_mechanism]

open Snark_params.Tick

[%%else]

open Snark_params_nonconsensus
module Random_oracle = Random_oracle_nonconsensus.Random_oracle

[%%endif]

module Chain_hash = struct
  include Data_hash.Make_full_size ()

  module Base58_check = Base58_check.Make (struct
    let description = "Receipt chain hash"

    let version_byte = Base58_check.Version_bytes.receipt_chain_hash
  end)

  let to_string t =
    Binable.to_string (module Stable.Latest) t |> Base58_check.encode

  let of_string s =
    Base58_check.decode_exn s |> Binable.of_string (module Stable.Latest)

  include Codable.Make_of_string (struct
    type nonrec t = t

    let to_string = to_string

    let of_string = of_string
  end)

  let empty = of_hash Random_oracle.(salt "CodaReceiptEmpty" |> digest)

  let cons payload (t : t) =
    let open Random_oracle in
    hash ~init:Hash_prefix.receipt_chain
      (pack_input
         Input.(
           append
             ( Transaction_union_payload.(
                 to_input (of_user_command_payload payload))
               : (Field.t, bool) Input.t )
             (field (t :> Field.t))))
    |> of_hash

  [%%if
  defined consensus_mechanism]

  module Checked = struct
    let constant (t : t) =
      var_of_hash_packed (Field.Var.constant (t :> Field.t))

    type t = var

    let if_ = if_

    let cons ~payload t =
      let open Random_oracle in
      let open Checked in
      let%bind payload = Transaction_union_payload.Checked.to_input payload in
      make_checked (fun () ->
          hash ~init:Hash_prefix.receipt_chain
            (pack_input Input.(append payload (var_to_input t)))
          |> var_of_hash_packed )
  end

  let%test_unit "checked-unchecked equivalence" =
    let open Quickcheck in
    test ~trials:20 (Generator.tuple2 gen User_command_payload.gen)
      ~f:(fun (base, payload) ->
        let unchecked = cons payload base in
        let checked =
          let comp =
            let open Snark_params.Tick.Checked.Let_syntax in
            let payload =
              Transaction_union_payload.(
                Checked.constant (of_user_command_payload payload))
            in
            let%map res = Checked.cons ~payload (var_of_t base) in
            As_prover.read typ res
          in
          let (), x = Or_error.ok_exn (run_and_check comp ()) in
          x
        in
        assert (equal unchecked checked) )

  let%test_unit "json" =
    Quickcheck.test ~trials:20 gen ~sexp_of:sexp_of_t ~f:(fun t ->
        assert (For_tests.check_encoding ~equal t) )

  [%%endif]
end
