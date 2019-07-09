open Core_kernel
open Crypto_params

module Digest = struct
  include Random_oracle_base.Digest
  open Tick0

  module Checked = struct
    type unchecked = t

    type t = Boolean.var array

    let to_bits = Fn.id

    let to_triples t =
      Fold_lib.Fold.(to_list (group3 ~default:Boolean.false_ (of_array t)))

    let constant (unchecked : unchecked) =
      assert (Int.(String.length (unchecked :> string) = length_in_bytes)) ;
      Array.map
        (Blake2.string_to_bits (unchecked :> string))
        ~f:Boolean.var_of_value
  end

  let to_bits (t : t) = Blake2.string_to_bits (t :> string)

  let typ : (Checked.t, t) Typ.t =
    Typ.transport
      (Typ.array ~length:Blake2.digest_size_in_bits Boolean.typ)
      ~there:(fun (t : t) -> Blake2.string_to_bits (t :> string))
      ~back:(fun bs -> of_string (Blake2.bits_to_string bs))
end

let digest_string s =
  Blake2.(digest_string s |> to_raw_string) |> Digest.of_string

let digest_field =
  let field_to_bits x =
    let open Tick0 in
    let n = Bigint.of_field x in
    Array.init Field.size_in_bits ~f:(Bigint.test_bit n)
  in
  fun x -> digest_string (Blake2.bits_to_string (field_to_bits x))

module Checked = struct
  include Snarky_blake2.Make (Tick0)

  let digest_bits bs = blake2s (Array.of_list bs)

  let digest_field x =
    let open Tick0.Let_syntax in
    Tick0.Field.Checked.choose_preimage_var x ~length:Tick0.Field.size_in_bits
    >>= digest_bits
end

let%test_unit "checked-unchecked equality" =
  Quickcheck.test ~trials:10
    (Quickcheck.Generator.list Bool.quickcheck_generator) ~f:(fun bits ->
      Tick0.Test.test_equal ~sexp_of_t:Digest.sexp_of_t
        (Tick0.Typ.list ~length:(List.length bits) Tick0.Boolean.typ)
        Digest.typ Checked.digest_bits
        (fun bs -> digest_string (Blake2.bits_to_string (Array.of_list bs)))
        bits )

let%test_unit "checked-unchecked field" =
  Quickcheck.test ~trials:10 Tick0.Field.gen ~f:(fun bits ->
      Tick0.Test.test_equal ~sexp_of_t:Digest.sexp_of_t Tick0.Field.typ
        Digest.typ Checked.digest_field digest_field bits )
