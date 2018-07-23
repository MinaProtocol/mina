open Ppxlib
open Asttypes
open Parsetree
open Longident
open Core
open Common.Blockchain_state

let expr_of_t ~loc
    ({ next_difficulty
     ; previous_state_hash
     ; ledger_builder_hash
     ; ledger_hash
     ; strength
     ; timestamp }:
      t) =
  let open Nanobit_base in
  let ident str = Loc.make loc (Longident.parse str) in
  let module E = Ppxlib.Ast_builder.Make (struct
    let loc = loc
  end) in
  let open E in
  let e (type a) name (module M : Sexpable.S with type t = a) (x: a) =
    [%expr
      [%e pexp_ident (ident (sprintf "Nanobit_base.%s.t_of_sexp" name))]
        [%e Ppx_util.expr_of_sexp ~loc (M.sexp_of_t x)]]
  in
  [%expr
    { Nanobit_base.Blockchain_state.next_difficulty=
        [%e e "Target" (module Target) next_difficulty]
    ; previous_state_hash=
        [%e e "State_hash" (module State_hash) previous_state_hash]
    ; ledger_builder_hash=
        [%e
          e "Ledger_builder_hash"
            (module Ledger_builder_hash)
            ledger_builder_hash]
    ; ledger_hash= [%e e "Ledger_hash" (module Ledger_hash) ledger_hash]
    ; strength= [%e e "Strength" (module Strength) strength]
    ; timestamp= [%e e "Block_time" (module Block_time) timestamp] }]

let genesis_time =
  Time.of_date_ofday ~zone:Time.Zone.utc
    (Date.create_exn ~y:2018 ~m:Month.Feb ~d:2)
    Time.Ofday.start_of_day
  |> Nanobit_base.Block_time.of_time

let negative_one =
  let open Nanobit_base in
  let next_difficulty : Target.Unpacked.value =
    if Insecure.initial_difficulty then Target.max
    else
      Target.of_bigint
        Bignum_bigint.(Target.(to_bigint max) / pow (of_int 2) (of_int 4))
  in
  let timestamp =
    Block_time.of_time
      (Time.sub (Block_time.to_time genesis_time) Time.Span.second)
  in
  { Blockchain_state.next_difficulty
  ; previous_state_hash=
      State_hash.of_hash Snark_params.Tick.Pedersen.zero_hash
  ; ledger_builder_hash= Ledger_builder_hash.dummy
  ; ledger_hash= Ledger.merkle_root Genesis_ledger.ledger
  ; strength= Strength.zero
  ; timestamp }

let genesis_block, zero =
  let open Nanobit_base in
  let block =
    let open Block in
    { header= {Block.Header.nonce= Nonce.of_int 0; time= genesis_time}
    ; body=
        { Block.Body.proof= None
        ; ledger_builder_hash= Ledger_builder_hash.dummy
        ; target_hash= Ledger.(merkle_root Genesis_ledger.ledger) } }
  in
  let zero = update_unchecked negative_one block in
  let rec find_ok_nonce i =
    if Or_error.is_ok (Proof_of_work.create zero i) then i
    else find_ok_nonce (Block.Nonce.succ i)
  in
  let nonce = find_ok_nonce Block.Nonce.zero in
  ({block with header= {block.header with nonce}}, zero)

let genesis_block_expr ~loc =
  let module E = Ppxlib.Ast_builder.Make (struct
    let loc = loc
  end) in
  let open E in
  let open Nanobit_base in
  [%expr
    { Nanobit_base.Block.header=
        { Nanobit_base.Block.Header.nonce=
            Nanobit_base.Block.Nonce.of_int
              [%e eint (Unsigned.UInt64.to_int genesis_block.header.nonce)]
        ; time=
            Nanobit_base.Block_time.t_of_sexp
              [%e
                Ppx_util.expr_of_sexp ~loc
                  (Block_time.sexp_of_t genesis_block.header.time)] }
    ; body=
        { Nanobit_base.Block.Body.proof= None
        ; ledger_builder_hash= Nanobit_base.Ledger_builder_hash.dummy
        ; target_hash=
            Nanobit_base.Ledger.merkle_root Nanobit_base.Genesis_ledger.ledger
        } }]

let main () =
  let target = Sys.argv.(1) in
  let fmt = Format.formatter_of_out_channel (Out_channel.create target) in
  let loc = Ppxlib.Location.none in
  let structure =
    [%str
      let genesis_block = [%e genesis_block_expr ~loc]

      let negative_one = [%e expr_of_t ~loc negative_one]

      let zero = [%e expr_of_t ~loc zero]]
  in
  Pprintast.top_phrase fmt (Ptop_def structure) ;
  exit 0

let () = main ()
