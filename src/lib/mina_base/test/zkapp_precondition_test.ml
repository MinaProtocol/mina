(** Testing
    -------
    Component:  Mina base
    Invocation: dune exec src/lib/mina_base/test/main.exe -- test '^zkApp precondition$'
    Subject:    Test zkApp preconditions.
 *)

open Core_kernel
open Currency
open Snark_params.Tick
open Mina_numbers
open Mina_base
open Zkapp_basic
open Zkapp_precondition

let protocol_state_json_roundtrip () =
  let open Protocol_state in
  let predicate : t = accept in
  let module Fd = Fields_derivers_zkapps.Derivers in
  let full = deriver (Fd.o ()) in
  [%test_eq: t] predicate (predicate |> Fd.to_json full |> Fd.of_json full)

let epoch_data_json_roundtrip () =
  let open Protocol_state.Epoch_data in
  let f = Or_ignore.Check Field.one in
  let u = Length.zero in
  let a = Amount.zero in
  let predicate : t =
    { ledger =
        { Epoch_ledger.Poly.hash = f
        ; total_currency =
            Or_ignore.Check { Closed_interval.lower = a; upper = a }
        }
    ; seed = f
    ; start_checkpoint = f
    ; lock_checkpoint = f
    ; epoch_length = Or_ignore.Check { Closed_interval.lower = u; upper = u }
    }
  in
  let module Fd = Fields_derivers_zkapps.Derivers in
  let full = deriver (Fd.o ()) in
  [%test_eq: t] predicate (predicate |> Fd.to_json full |> Fd.of_json full)

let account_json_roundtrip () =
  let open Account in
  let b = Balance.of_nanomina_int_exn 1000 in
  let predicate : t =
    { accept with
      balance = Or_ignore.Check { Closed_interval.lower = b; upper = b }
    ; action_state = Or_ignore.Check (Field.of_int 99)
    ; proved_state = Or_ignore.Check true
    }
  in
  let module Fd = Fields_derivers_zkapps.Derivers in
  let full = deriver (Fd.o ()) in
  [%test_eq: t] predicate (predicate |> Fd.to_json full |> Fd.of_json full)

module IntClosedInterval = struct
  open Closed_interval

  type t_ = int t [@@deriving sexp, equal, compare]

  (* Note: nonrec doesn't work with ppx-deriving *)
  type t = t_ [@@deriving sexp, equal, compare]

  let v = { lower = 10; upper = 100 }
end

let closed_interval_json_roundtrip () =
  let open Fields_derivers_zkapps.Derivers in
  let full = o () in
  let _a : _ Unified_input.t = Closed_interval.deriver ~name:"Int" int full in
  [%test_eq: IntClosedInterval.t]
    (!(full#of_json) (!(full#to_json) IntClosedInterval.v))
    IntClosedInterval.v

module Int_numeric = struct
  open Numeric

  type t_ = int t [@@deriving sexp, equal, compare]

  (* Note: nonrec doesn't work with ppx-deriving *)
  type t = t_ [@@deriving sexp, equal, compare]
end

module T = struct
  type t = { foo : Int_numeric.t }
  [@@deriving annot, sexp, equal, compare, fields]

  let v : t =
    { foo = Or_ignore.Check { Closed_interval.lower = 10; upper = 100 } }

  let deriver obj =
    let open Numeric in
    let open Fields_derivers_zkapps.Derivers in
    let ( !. ) = ( !. ) ~t_fields_annots in
    Fields.make_creator obj ~foo:!.(deriver "Int" int ("0", "1000"))
    |> finish "T" ~t_toplevel_annots
end

let numeric_roundtrip_json () =
  let open Fields_derivers_zkapps.Derivers in
  let full = o () in
  let _a : _ Unified_input.t = T.deriver full in
  [%test_eq: T.t] (of_json full (to_json full T.v)) T.v
