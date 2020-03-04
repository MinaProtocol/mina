(* transaction_union_tag.ml *)

[%%import
"/src/config.mlh"]

open Core_kernel

[%%ifdef
consensus_mechanism]

open Snark_params.Tick

[%%endif]

type t = Payment | Stake_delegation | Mint | Fee_transfer | Coinbase
[@@deriving enum, eq, sexp]

let gen =
  Quickcheck.Generator.map (Int.gen_incl min max) ~f:(fun i ->
      Option.value_exn (of_enum i) )

module Bits = struct
  type t = bool * bool * bool

  [%%ifdef
  consensus_mechanism]

  type var = Boolean.var * Boolean.var * Boolean.var

  let typ = Typ.tuple3 Boolean.typ Boolean.typ Boolean.typ

  let constant (b1, b2, b3) =
    Boolean.(var_of_value b1, var_of_value b2, var_of_value b3)

  let to_bits (b1, b2, b3) = [b1; b2; b3]

  let to_input t = Random_oracle.Input.bitstring (to_bits t)

  [%%endif]
end

module Unpacked = struct
  module Poly = struct
    type 'bool t =
      { is_payment: 'bool
      ; is_stake_delegation: 'bool
      ; is_mint: 'bool
      ; is_fee_transfer: 'bool
      ; is_coinbase: 'bool
      ; is_user_command: 'bool }
  end

  type t = bool Poly.t

  let empty : t =
    { is_payment= false
    ; is_stake_delegation= false
    ; is_mint= false
    ; is_fee_transfer= false
    ; is_coinbase= false
    ; is_user_command= false }

  let payment = {empty with is_payment= true; is_user_command= true}

  let stake_delegation =
    {empty with is_stake_delegation= true; is_user_command= true}

  let mint = {empty with is_mint= true; is_user_command= true}

  let fee_transfer = {empty with is_fee_transfer= true; is_user_command= false}

  let coinbase = {empty with is_coinbase= true; is_user_command= false}

  let of_bits_t : Bits.t -> t = function
    | true, false, false ->
        payment
    | true, false, true ->
        stake_delegation
    | true, true, false ->
        mint
    | false, false, false ->
        fee_transfer
    | false, false, true ->
        coinbase
    | _ ->
        raise (Invalid_argument "Transaction_union_tag.Unpacked.of_bits_t")

  let to_bits_t : t -> Bits.t = function
    | { is_payment= true
      ; is_stake_delegation= false
      ; is_mint= false
      ; is_fee_transfer= false
      ; is_coinbase= false
      ; is_user_command= true } ->
        (true, false, false)
    | { is_payment= false
      ; is_stake_delegation= true
      ; is_mint= false
      ; is_fee_transfer= false
      ; is_coinbase= false
      ; is_user_command= true } ->
        (true, false, true)
    | { is_payment= false
      ; is_stake_delegation= false
      ; is_mint= true
      ; is_fee_transfer= false
      ; is_coinbase= false
      ; is_user_command= true } ->
        (true, true, false)
    | { is_payment= false
      ; is_stake_delegation= false
      ; is_mint= false
      ; is_fee_transfer= true
      ; is_coinbase= false
      ; is_user_command= false } ->
        (false, false, false)
    | { is_payment= false
      ; is_stake_delegation= false
      ; is_mint= false
      ; is_fee_transfer= false
      ; is_coinbase= true
      ; is_user_command= false } ->
        (false, false, true)
    | _ ->
        raise (Invalid_argument "Transaction_union_tag.Unpacked.to_bits_t")

  [%%ifdef
  consensus_mechanism]

  type var = Boolean.var Poly.t

  let to_bits_var
      ({ is_payment= _100
       ; is_stake_delegation
       ; is_mint
       ; is_fee_transfer= _000
       ; is_coinbase
       ; is_user_command } :
        var) : (Bits.var, _) Checked.t =
    let open Checked.Let_syntax in
    let b1 = is_user_command in
    let b2 = is_mint in
    let%map b3 = Boolean.(is_stake_delegation || is_coinbase) in
    (b1, b2, b3)

  [%%endif]

  let to_bits t = Bits.to_bits (to_bits_t t)

  [%%ifdef
  consensus_mechanism]

  let constant
      ({ is_payment
       ; is_stake_delegation
       ; is_mint
       ; is_fee_transfer
       ; is_coinbase
       ; is_user_command } :
        t) : var =
    { is_payment= Boolean.var_of_value is_payment
    ; is_stake_delegation= Boolean.var_of_value is_stake_delegation
    ; is_mint= Boolean.var_of_value is_mint
    ; is_fee_transfer= Boolean.var_of_value is_fee_transfer
    ; is_coinbase= Boolean.var_of_value is_coinbase
    ; is_user_command= Boolean.var_of_value is_user_command }

  let is_payment ({is_payment; _} : var) = is_payment

  let is_stake_delegation ({is_stake_delegation; _} : var) =
    is_stake_delegation

  let is_mint ({is_mint; _} : var) = is_mint

  let is_fee_transfer ({is_fee_transfer; _} : var) = is_fee_transfer

  let is_coinbase ({is_coinbase; _} : var) = is_coinbase

  let is_user_command ({is_user_command; _} : var) = is_user_command

  module Checked = struct
    let to_bits t = Checked.map (to_bits_var t) ~f:Bits.to_bits

    let to_input t = Checked.map (to_bits t) ~f:Random_oracle.Input.bitstring
  end

  let typ : (var, t) Typ.t =
    let open Typ in
    { alloc=
        Alloc.Let_syntax.(
          let%bind is_payment = alloc Boolean.typ in
          let%bind is_stake_delegation = alloc Boolean.typ in
          let%bind is_mint = alloc Boolean.typ in
          let%bind is_fee_transfer = alloc Boolean.typ in
          let%bind is_coinbase = alloc Boolean.typ in
          let%map is_user_command = alloc Boolean.typ in
          { Poly.is_payment
          ; is_stake_delegation
          ; is_mint
          ; is_fee_transfer
          ; is_coinbase
          ; is_user_command })
    ; store=
        Store.Let_syntax.(
          fun { is_payment
              ; is_stake_delegation
              ; is_mint
              ; is_fee_transfer
              ; is_coinbase
              ; is_user_command } ->
            let%bind is_payment = store Boolean.typ is_payment in
            let%bind is_stake_delegation =
              store Boolean.typ is_stake_delegation
            in
            let%bind is_mint = store Boolean.typ is_mint in
            let%bind is_fee_transfer = store Boolean.typ is_fee_transfer in
            let%bind is_coinbase = store Boolean.typ is_coinbase in
            let%map is_user_command = store Boolean.typ is_user_command in
            { Poly.is_payment
            ; is_stake_delegation
            ; is_mint
            ; is_fee_transfer
            ; is_coinbase
            ; is_user_command })
    ; read=
        Read.Let_syntax.(
          fun { is_payment
              ; is_stake_delegation
              ; is_mint
              ; is_fee_transfer
              ; is_coinbase
              ; is_user_command } ->
            let%bind is_payment = read Boolean.typ is_payment in
            let%bind is_stake_delegation =
              read Boolean.typ is_stake_delegation
            in
            let%bind is_mint = read Boolean.typ is_mint in
            let%bind is_fee_transfer = read Boolean.typ is_fee_transfer in
            let%bind is_coinbase = read Boolean.typ is_coinbase in
            let%map is_user_command = read Boolean.typ is_user_command in
            { Poly.is_payment
            ; is_stake_delegation
            ; is_mint
            ; is_fee_transfer
            ; is_coinbase
            ; is_user_command })
    ; check=
        (fun { is_payment
             ; is_stake_delegation
             ; is_mint
             ; is_fee_transfer
             ; is_coinbase
             ; is_user_command } ->
          let%bind () =
            [%with_label "Only one tag is set"]
              (Boolean.Assert.exactly_one
                 [ is_payment
                 ; is_stake_delegation
                 ; is_mint
                 ; is_fee_transfer
                 ; is_coinbase ])
          in
          [%with_label "User command flag is correctly set"]
            (Boolean.Assert.exactly_one
               [is_user_command; is_fee_transfer; is_coinbase]) ) }

  [%%endif]
end

let unpacked_t_of_t = function
  | Payment ->
      Unpacked.payment
  | Stake_delegation ->
      Unpacked.stake_delegation
  | Mint ->
      Unpacked.mint
  | Fee_transfer ->
      Unpacked.fee_transfer
  | Coinbase ->
      Unpacked.coinbase

let to_bits tag = Unpacked.to_bits (unpacked_t_of_t tag)

let to_input tag = Random_oracle.Input.bitstring (to_bits tag)

[%%ifdef
consensus_mechanism]

let t_of_unpacked_t : Unpacked.t -> t = function
  | { is_payment= true
    ; is_stake_delegation= false
    ; is_mint= false
    ; is_fee_transfer= false
    ; is_coinbase= false
    ; is_user_command= true } ->
      Payment
  | { is_payment= false
    ; is_stake_delegation= true
    ; is_mint= false
    ; is_fee_transfer= false
    ; is_coinbase= false
    ; is_user_command= true } ->
      Stake_delegation
  | { is_payment= false
    ; is_stake_delegation= false
    ; is_mint= true
    ; is_fee_transfer= false
    ; is_coinbase= false
    ; is_user_command= true } ->
      Mint
  | { is_payment= false
    ; is_stake_delegation= false
    ; is_mint= false
    ; is_fee_transfer= true
    ; is_coinbase= false
    ; is_user_command= false } ->
      Fee_transfer
  | { is_payment= false
    ; is_stake_delegation= false
    ; is_mint= false
    ; is_fee_transfer= false
    ; is_coinbase= true
    ; is_user_command= false } ->
      Coinbase
  | _ ->
      raise (Invalid_argument "Transaction_union_tag.t_of_unpacked_t")

let bits_t_of_t tag = Unpacked.to_bits_t (unpacked_t_of_t tag)

let t_of_bits_t tag = t_of_unpacked_t (Unpacked.of_bits_t tag)

let unpacked_of_t tag = Unpacked.constant (unpacked_t_of_t tag)

let bits_of_t tag = Bits.constant (bits_t_of_t tag)

let unpacked_typ =
  Typ.transport Unpacked.typ ~there:unpacked_t_of_t ~back:t_of_unpacked_t

let bits_typ = Typ.transport Bits.typ ~there:bits_t_of_t ~back:t_of_bits_t

let%test_module "predicates" =
  ( module struct
    let test_predicate checked unchecked =
      let checked x = Checked.return (checked x) in
      for i = min to max do
        Test_util.test_equal unpacked_typ Boolean.typ checked unchecked
          (Option.value_exn (of_enum i))
      done

    let one_of xs t = List.mem xs ~equal t

    let%test_unit "is_payment" =
      test_predicate Unpacked.is_payment (( = ) Payment)

    let%test_unit "is_stake_delegation" =
      test_predicate Unpacked.is_stake_delegation (( = ) Stake_delegation)

    let%test_unit "is_mint" = test_predicate Unpacked.is_mint (( = ) Mint)

    let%test_unit "is_fee_transfer" =
      test_predicate Unpacked.is_fee_transfer (( = ) Fee_transfer)

    let%test_unit "is_coinbase" =
      test_predicate Unpacked.is_coinbase (( = ) Coinbase)

    let%test_unit "is_user_command" =
      test_predicate Unpacked.is_user_command
        (one_of [Payment; Stake_delegation; Mint])

    let%test_unit "bit_representation" =
      for i = min to max do
        Test_util.test_equal unpacked_typ Bits.typ Unpacked.to_bits_var
          bits_t_of_t
          (Option.value_exn (of_enum i))
      done
  end )

[%%endif]
