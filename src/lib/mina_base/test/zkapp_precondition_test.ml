(** {1 ClosedInterval tests} *)

let closed_interval_roundtrip_json () =
  let open Fields_derivers_zkapps.Derivers in
  let v =
    { Mina_base.Zkapp_precondition.Closed_interval.lower = 10; upper = 100 }
  in
  let full = o () in
  let _a : _ Unified_input.t =
    Mina_base.Zkapp_precondition.Closed_interval.deriver ~name:"Int" int full
  in
  let result = !(full#of_json) (!(full#to_json) v) in
  Alcotest.(check bool)
    "roundtrip json" true
    (Mina_base.Zkapp_precondition.Closed_interval.equal Int.equal result v)

(** {1 Numeric tests} *)

let numeric_roundtrip_json () =
  (* Test that Numeric.deriver correctly serializes a Numeric.t value.
     Since we can't easily create the wrapper type T here without ppx_annot,
     we test the underlying Account.deriver which uses Numeric internally. *)
  let b = Currency.Balance.of_nanomina_int_exn 1000 in
  let predicate : Mina_base.Zkapp_precondition.Account.t =
    { Mina_base.Zkapp_precondition.Account.accept with
      balance =
        Mina_base.Zkapp_basic.Or_ignore.Check
          { Mina_base.Zkapp_precondition.Closed_interval.lower = b; upper = b }
    }
  in
  let module Fd = Fields_derivers_zkapps.Derivers in
  let full = Mina_base.Zkapp_precondition.Account.deriver (Fd.o ()) in
  let result = predicate |> Fd.to_json full |> Fd.of_json full in
  Alcotest.(check bool)
    "roundtrip json" true
    (Mina_base.Zkapp_precondition.Account.equal predicate result)

(** {1 Account precondition tests} *)

let account_json_roundtrip () =
  let b = Currency.Balance.of_nanomina_int_exn 1000 in
  let predicate : Mina_base.Zkapp_precondition.Account.t =
    { Mina_base.Zkapp_precondition.Account.accept with
      balance =
        Mina_base.Zkapp_basic.Or_ignore.Check
          { Mina_base.Zkapp_precondition.Closed_interval.lower = b; upper = b }
    ; action_state =
        Mina_base.Zkapp_basic.Or_ignore.Check
          (Snark_params.Tick.Field.of_int 99)
    ; proved_state = Mina_base.Zkapp_basic.Or_ignore.Check true
    }
  in
  let module Fd = Fields_derivers_zkapps.Derivers in
  let full = Mina_base.Zkapp_precondition.Account.deriver (Fd.o ()) in
  let result = predicate |> Fd.to_json full |> Fd.of_json full in
  Alcotest.(check bool)
    "json roundtrip" true
    (Mina_base.Zkapp_precondition.Account.equal predicate result)

(** {1 Protocol_state.Epoch_data tests} *)

let epoch_data_json_roundtrip () =
  let f = Mina_base.Zkapp_basic.Or_ignore.Check Snark_params.Tick.Field.one in
  let u = Mina_numbers.Length.zero in
  let a = Currency.Amount.zero in
  let predicate : Mina_base.Zkapp_precondition.Protocol_state.Epoch_data.t =
    { Mina_base.Epoch_data.Poly.ledger =
        { Mina_base.Epoch_ledger.Poly.hash = f
        ; total_currency =
            Mina_base.Zkapp_basic.Or_ignore.Check
              { Mina_base.Zkapp_precondition.Closed_interval.lower = a
              ; upper = a
              }
        }
    ; seed = f
    ; start_checkpoint = f
    ; lock_checkpoint = f
    ; epoch_length =
        Mina_base.Zkapp_basic.Or_ignore.Check
          { Mina_base.Zkapp_precondition.Closed_interval.lower = u; upper = u }
    }
  in
  let module Fd = Fields_derivers_zkapps.Derivers in
  let full =
    Mina_base.Zkapp_precondition.Protocol_state.Epoch_data.deriver (Fd.o ())
  in
  let result = predicate |> Fd.to_json full |> Fd.of_json full in
  Alcotest.(check bool)
    "json roundtrip" true
    (Mina_base.Zkapp_precondition.Protocol_state.Epoch_data.equal predicate
       result )

(** {1 Protocol_state tests} *)

let protocol_state_json_roundtrip () =
  let predicate : Mina_base.Zkapp_precondition.Protocol_state.t =
    Mina_base.Zkapp_precondition.Protocol_state.accept
  in
  let module Fd = Fields_derivers_zkapps.Derivers in
  let full = Mina_base.Zkapp_precondition.Protocol_state.deriver (Fd.o ()) in
  let result = predicate |> Fd.to_json full |> Fd.of_json full in
  Alcotest.(check bool)
    "json roundtrip" true
    (Mina_base.Zkapp_precondition.Protocol_state.equal predicate result)
