open Ppxlib
open Asttypes
open Parsetree
open Longident
open Core
open Coda_numbers

let expr_of_t ~loc
    ({ next_difficulty
     ; previous_state_hash
     ; ledger_builder_hash
     ; ledger_hash
     ; strength
     ; length
     ; timestamp
     ; signer_public_key } :
      t) =
  let open Coda_base in
  let ident str = Loc.make loc (Longident.parse str) in
  let module E = Ppxlib.Ast_builder.Make (struct
    let loc = loc
  end) in
  let open E in
  let n s = "Coda_base." ^ s in
  let e (type a) name (module M : Sexpable.S with type t = a) (x : a) =
    [%expr
      [%e pexp_ident (ident (sprintf "%s.t_of_sexp" name))]
        [%e Ppx_util.expr_of_sexp ~loc (M.sexp_of_t x)]]
  in
  [%expr
    { Coda_base.Blockchain_state.next_difficulty=
        [%e e (n "Target") (module Target) next_difficulty]
    ; previous_state_hash=
        [%e e (n "State_hash") (module State_hash) previous_state_hash]
    ; ledger_builder_hash=
        [%e
          e (n "Ledger_builder_hash")
            (module Ledger_builder_hash)
            ledger_builder_hash]
    ; ledger_hash= [%e e (n "Ledger_hash") (module Ledger_hash) ledger_hash]
    ; strength= [%e e (n "Strength") (module Strength) strength]
    ; length= [%e e "Coda_numbers.Length" (module Length) length]
    ; timestamp= [%e e (n "Block_time") (module Block_time) timestamp]
    ; signer_public_key=
        [%e
          e
            (n "Public_key.Compressed")
            (module Public_key.Compressed)
            signer_public_key] }]

let genesis_time =
  Time.of_date_ofday ~zone:Time.Zone.utc
    (Date.create_exn ~y:2018 ~m:Month.Feb ~d:2)
    Time.Ofday.start_of_day
  |> Coda_base.Block_time.of_time

let negative_one =
  let open Coda_base in
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
  ; length= Length.zero
  ; timestamp
  ; signer_public_key=
      Public_key.compress
      @@ Public_key.of_private_key Global_signer_private_key.t }

let genesis_block, zero =
  let open Coda_base in
  let block =
    let open Block in
    let state_transition_data =
      let open State_transition_data in
      { time= genesis_time
      ; target_hash= Ledger.merkle_root Genesis_ledger.ledger
      ; ledger_builder_hash= Ledger_builder_hash.dummy }
    in
    { auxillary_data=
        (let open Auxillary_data in
        { nonce= Nonce.of_int 0
        ; signature=
            State_transition_data.Signature.sign Global_signer_private_key.t
              state_transition_data })
    ; state_transition_data
    ; proof= None }
  in
  let zero = update_unchecked negative_one block in
  let rec find_ok_nonce i =
    if Or_error.is_ok (Proof_of_work.create zero i) then i
    else find_ok_nonce (Block.Nonce.succ i)
  in
  let nonce = find_ok_nonce Block.Nonce.zero in
  ({block with auxillary_data= {block.auxillary_data with nonce}}, zero)

let genesis_block_expr ~loc =
  let module E = Ppxlib.Ast_builder.Make (struct
    let loc = loc
  end) in
  let open E in
  let open Coda_base in
  [%expr
    { Coda_base.Block.auxillary_data=
        { Coda_base.Block.Auxillary_data.nonce=
            Coda_base.Block.Nonce.of_int
              [%e
                eint
                  (Unsigned.UInt64.to_int genesis_block.auxillary_data.nonce)]
        ; signature=
            Coda_base.Block.State_transition_data.Signature.Signature.t_of_sexp
              [%e
                Ppx_util.expr_of_sexp ~loc
                  (Block.State_transition_data.Signature.Signature.sexp_of_t
                     genesis_block.auxillary_data.signature)] }
    ; state_transition_data=
        { Coda_base.Block.State_transition_data.time=
            Coda_base.Block_time.t_of_sexp
              [%e
                Ppx_util.expr_of_sexp ~loc
                  (Block_time.sexp_of_t
                     genesis_block.state_transition_data.time)]
        ; ledger_builder_hash= Coda_base.Ledger_builder_hash.dummy
        ; target_hash=
            Coda_base.Ledger.merkle_root Coda_base.Genesis_ledger.ledger }
    ; proof= None }]

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
