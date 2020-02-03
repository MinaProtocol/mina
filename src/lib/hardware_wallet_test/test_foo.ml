open Coda_base
open Core_kernel
open Snark_params
open Coda_base.Schnorr

(* this format will change in the future *)
type user_command =
  { isDelegation: bool
  ; nonce: Coda_numbers.Account_nonce.t
  ; toAccount: Signature_lib.Public_key.Compressed.t
  ; amount: Currency.Amount.t
  ; fee: Currency.Fee.t
  ; memo: User_command_memo.t
  ; valid_until: Coda_numbers.Global_slot.t }
[@@deriving yojson]

(*
let%test_unit "decoding field" =
  let alphabet =
    B58.make_alphabet
      "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
  in
  let _r =
    Bytes.of_string
      "1147BmBCtyE8AjGS6jkAJbQNXJD7ke6B1eu2aysKZbgs8Vf66VHJQVzYG38VpYwG1Vk1RQQF66i8cKbuxLtvq1zJNQUe9LEJTFvyQU7GP1Moxwwky1A2xkL8oKAv9ySRibs"
    |> B58.decode alphabet |> Bytes.to_string
    |> String.foldi ~init:Bigint.zero ~f:(fun i acc byte ->
           Bigint.(acc lor (of_int (Char.to_int byte) lsl Int.( * ) 8 i)) )
    |> Tick.Bigint.of_bignum_bigint |> Tick.Bigint.to_field
  in
  let _s =
    Bytes.of_string
      "16BRW1tm8VZnDSe7yoDdrZrGbqCvvGNfMHPGNt96PzAti6i9n3fhJKTxRiDEaENaQt1ZctM1Y1cbU95KXm29gdg6qcDX3jvukQ6qLJC8maCY27xPkK6w942Nh9sVRAWQQd"
    |> B58.decode alphabet |> Bytes.to_string
    |> String.foldi ~init:Bigint.zero ~f:(fun i acc byte ->
           Bigint.(acc lor (of_int (Char.to_int byte) lsl Int.( * ) 8 i)) )
    |> Tock.Bigint.of_bignum_bigint |> Tock.Bigint.to_field
  in
  let _x =
    Bytes.of_string
      "115LFY15j2xqcFJXLYvScasi93wyTdmeKPiVgsfzfiBRctYgps77to5Mq4GobohnqQyHxPC7TRMjNL6L4zY259o1SpJPXZYrNARJm7iN9M9rUya6UQJkuf46SosRdEQJwdx"
    |> B58.decode alphabet |> Bytes.to_string
    |> String.foldi ~init:Bigint.zero ~f:(fun i acc byte ->
           Bigint.(acc lor (of_int (Char.to_int byte) lsl Int.( * ) 8 i)) )
    |> Tick.Bigint.of_bignum_bigint |> Tick.Bigint.to_field
  in
  ()
*)

let%test_unit "ledger verify" =
  let _alphabet =
    B58.make_alphabet
      "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
  in
  (* This is the field of the signature
  let r =
    Bytes.of_string
      "185c67vL3ASPZyizDu437EttgFaBcwf8EQY4Mviuk52HvMfYomMfFFvvwwZFVvTbZeD247wCnio3SqNT1UKwQZUJjH8HBhtuSNzD3ddjLbK1Bv7x8CJ3HfzHGLyZLSSeqd"
    |> B58.decode alphabet |> Bytes.to_string
    |> String.foldi ~init:Bigint.zero ~f:(fun i acc byte ->
           Bigint.(acc lor (of_int (Char.to_int byte) lsl Int.( * ) 8 i)) )
    |> Tick.Bigint.of_bignum_bigint |> Tick.Bigint.to_field
  in
  *)
  let r' =
    Tick.Field.of_string
      "37049246888676536624277940042927961618428788376149792986317123306330433385815422707492873454522927193324086785431084478265287281314862109620022073319355254979804798537689576589252733527858659223455800165742255766331929329268112"
  in
  (* This is the scalar of the signature
  let s =
    Bytes.of_string
    "1156cHRSVnLvXE8Z9AxqTgM7UMqBmEY5uFbSc5iNovsQoV8MMukUJ1UpyLxxexRgrL5k1RKPvDNYyqB9MMuj8H67BiRC1x1pGqv3JBJeJnGTyNjh6bQZpXPhBxDpwLMTu2K"
    |> B58.decode alphabet |> Bytes.to_string
    |> String.foldi ~init:Bigint.zero ~f:(fun i acc byte ->
           Bigint.(acc lor (of_int (Char.to_int byte) lsl Int.( * ) 8 i)) )
    |> Tock.Bigint.of_bignum_bigint |> Tock.Bigint.to_field
  in
  *)
  let s' =
    Tock.Field.of_string
      "21439608174574530147998527958172402954839390914729420379151101426764906054760165731081109082410052895171193203956099398701689523873557098430315568764556386029051862935615682874242495595107214402897871117781849735962260316830924"
  in
  (* This is the x of public key
  let x =
    Bytes.of_string
      "115LFY15j2xqcFJXLYvScasi93wyTdmeKPiVgsfzfiBRctYgps77to5Mq4GobohnqQyHxPC7TRMjNL6L4zY259o1SpJPXZYrNARJm7iN9M9rUya6UQJkuf46SosRdEQJwdx"
    |> B58.decode alphabet |> Bytes.to_string
    |> String.foldi ~init:Bigint.zero ~f:(fun i acc byte ->
           Bigint.(acc lor (of_int (Char.to_int byte) lsl Int.( * ) 8 i)) )
    |> Tick.Bigint.of_bignum_bigint |> Tick.Bigint.to_field
  in
  *)
  let x' =
    Tick.Field.of_string
      "10551932552288404268471876784066179540075993514619627475810154681265731503848345236869614822262595684404683450023872748280053822651035682354773112233967924938626433271064352765366912532816572973581508364105657856637532501320032"
  in
  let y' =
    Tick.Field.of_string
      "41396185721063460085667958656928492292262244305644537076418786203838831474688775166371394317334447476021191354079249366422299414575425706623634945421230874239790174420259736648550892231502609508610889111707764651968852198331491"
  in
  let is_odd = true in
  let _pkc = Signature_lib.Public_key.Compressed.Poly.{x= x'; is_odd} in
  let pk = (x', y') in
  let _user_command_string =
    "{\n\
    \    \"isDelegation\": \"False\",\n\
    \        \"nonce\": 37,\n\
    \    \"toAccount\": \
     \"4vsRCVwYndP4qoqb4EFr1UkXGNeYoDufMRQY45VtYgGzhyyRi1wzoogAt1KkxHmC4nFWs4FkKxbQx9X7gNkQhrWzjdfBbzGLecSq6kobsrREck9tdsmDYCHLj7A1Z9PbdehwxF5n6PuobAbL\",\n\
    \    \"amount\": 1000,\n\
    \    \"fee\": 8,\n\
    \    \"valid_until\": 1600,\n\
    \    \"memo\": \"2pmu64f2x97tNiDXMycnLwBSECDKbX77MTXVWVsG8hcRFsedhXDWWq\"\n\
     }"
  in
  let m =
    User_command_payload.Poly.
      { common=
          User_command_payload.Common.Poly.
            { fee= Currency.Fee.of_int 8
            ; nonce= Coda_numbers.Account_nonce.of_int 37
            ; valid_until= Coda_numbers.Global_slot.of_int 1600
            ; memo=
                User_command_memo.of_string
                  "2pmu64f2x97tNiDXMycnLwBSECDKbX77MTXVWVsG8hcRFsedhXDWWq" }
      ; body=
          User_command_payload.Body.Payment
            Payment_payload.Poly.
              { receiver=
                  Signature_lib.Public_key.Compressed.of_base58_check_exn
                    "4vsRCVwYndP4qoqb4EFr1UkXGNeYoDufMRQY45VtYgGzhyyRi1wzoogAt1KkxHmC4nFWs4FkKxbQx9X7gNkQhrWzjdfBbzGLecSq6kobsrREck9tdsmDYCHLj7A1Z9PbdehwxF5n6PuobAbL"
              ; amount= Currency.Amount.of_int 1000 } }
  in
  let input =
    Transaction_union_payload.to_input
    @@ Transaction_union_payload.of_user_command_payload m
  in
  let fs = Random_oracle.pack_input input in
  Array.iter fs ~f:(fun field -> eprintf "%s\n\n" (Tick.Field.to_string field)) ;
  (*
    match
      yojson |> user_command_of_yojson
    with
    | Ok {isDelegation= _; nonce; toAccount; amount; fee; memo; valid_until} ->
        User_command_payload.Poly.
          { common=
              User_command_payload.Common.Poly.{fee; nonce; valid_until; memo}
          ; body=
              User_command_payload.Body.Payment
                Payment_payload.Poly.{receiver= toAccount; amount} }
    | Error e ->
        failwith (e ^ Yojson.Safe. yojson)
*)
  (* let amount = Amount.of_int .. in *)
  (* let m = User_command_payload.create ~fee:(Currency.Fee.of_int ) ~nonce:(Account_nonce.of_int )  ~body:(User_command_payload.Body.Payment { receiver; amount }) in *)
  eprintf "r in test_foo: %s\n" (Snark_params.Tick.Field.to_string r') ;
  eprintf "hello: %s\n"
    (B58.decode _alphabet (Bytes.of_string "Cn8eVZg") |> Bytes.to_string) ;
  eprintf "world: %s\n"
    (B58.encode _alphabet (Bytes.of_string "world") |> Bytes.to_string) ;
  assert (verify (r', s') (Tick.Inner_curve.of_affine pk) m)
