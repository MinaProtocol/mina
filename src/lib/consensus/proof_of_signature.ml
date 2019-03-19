[%%import
"../../config.mlh"]

[%%if
consensus_mechanism = "proof_of_signature"]

let name = "proof_of_signature"

open Core_kernel
open Coda_numbers
open Coda_base
open Fold_lib
open Signature_lib
module Time = Block_time

module Global_public_key = struct
  [%%if
  global_signer_real]

  let compressed =
    Snark_params.Tick.Inner_curve.one
    |> Non_zero_curve_point.of_inner_curve_exn |> Public_key.compress

  let genesis_private_key = Global_signer_private_key.t

  [%%else]

  let compressed =
    Public_key.compress
      (Genesis_ledger.largest_account_keypair_exn ()).public_key

  let genesis_private_key =
    (Genesis_ledger.largest_account_keypair_exn ()).private_key

  [%%endif]

  let t = Public_key.decompress_exn compressed
end

module Local_state = struct
  type t = unit [@@deriving sexp]

  let create _ = ()
end

module Prover_state = struct
  include Unit

  let precomputed_handler =
    unstage
      (Coda_base.Pending_coinbase.handler
         (Pending_coinbase.create () |> Or_error.ok_exn)
         ~is_new_stack:false)

  let handler ()
      ~pending_coinbase:{ Coda_base.Pending_coinbase_witness.pending_coinbases
                        ; is_new_stack } =
    unstage
      (Coda_base.Pending_coinbase.handler pending_coinbases ~is_new_stack)
end

module Proposal_data = struct
  include Private_key

  let prover_state _ = ()
end

module Blockchain_state = Coda_base.Blockchain_state.Make (Genesis_ledger)
module Lite_compat = Lite_compat.Make (Blockchain_state)

module Consensus_transition_data = struct
  type 'signature t_ = {signature: 'signature} [@@deriving bin_io, sexp]

  type value = Signature.Stable.V1.t t_ [@@deriving bin_io, sexp]

  type var = Signature.var t_

  let to_hlist {signature} = H_list.[signature]

  let of_hlist : (unit, 'signature -> unit) H_list.t -> 'signature t_ =
   fun H_list.([signature]) -> {signature}

  let data_spec =
    Snark_params.Tick.Data_spec.[Blockchain_state.Signature.Signature.typ]

  let typ =
    Snark_params.Tick.Typ.of_hlistable data_spec ~var_to_hlist:to_hlist
      ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

  let create_value ~private_key blockchain_state =
    {signature= Blockchain_state.Signature.sign private_key blockchain_state}

  let genesis =
    { signature=
        Blockchain_state.Signature.sign Global_public_key.genesis_private_key
          Blockchain_state.genesis }
end

module Consensus_state = struct
  type ('length, 'public_key) t_ =
    {length: 'length; signer_public_key: 'public_key}
  [@@deriving eq, bin_io, sexp, hash, compare]

  type display = {length: string} [@@deriving yojson]

  type value = (Length.t, Public_key.Compressed.t) t_
  [@@deriving bin_io, sexp, hash, compare]

  type var = (Length.Unpacked.var, Public_key.Compressed.var) t_

  let equal_value = equal_t_ Length.equal Public_key.Compressed.equal

  let length_in_triples =
    Length.length_in_triples + Public_key.Compressed.length_in_triples

  let genesis =
    {length= Length.zero; signer_public_key= Global_public_key.compressed}

  let to_hlist {length; signer_public_key} = H_list.[length; signer_public_key]

  let of_hlist :
         (unit, 'length -> 'public_key -> unit) H_list.t
      -> ('length, 'public_key) t_ =
   fun H_list.([length; signer_public_key]) -> {length; signer_public_key}

  let data_spec =
    let open Snark_params.Tick.Data_spec in
    [Length.Unpacked.typ; Public_key.Compressed.typ]

  let typ : (var, value) Snark_params.Tick.Typ.t =
    Snark_params.Tick.Typ.of_hlistable data_spec ~var_to_hlist:to_hlist
      ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

  let var_to_triples {length; signer_public_key} =
    let open Snark_params.Tick.Checked.Let_syntax in
    let%map public_key_triples =
      Public_key.Compressed.var_to_triples signer_public_key
    in
    Length.Unpacked.var_to_triples length @ public_key_triples

  let fold {length; signer_public_key} =
    Fold.(Length.fold length +> Public_key.Compressed.fold signer_public_key)

  let update (state : value) =
    { length= Length.succ state.length
    ; signer_public_key= Global_public_key.compressed }

  let length (t : value) = t.length

  let time_hum _ = "<posig has no notion of time>"

  let to_lite =
    Some
      (fun {length; signer_public_key} ->
        { Lite_base.Consensus_state.length= Lite_compat.length length
        ; signer_public_key= Lite_compat.public_key signer_public_key } )

  let display (t : value) : display = {length= Length.to_string t.length}
end

module Protocol_state =
  Protocol_state.Make (Blockchain_state) (Consensus_state)

module Configuration = struct
  type t = {proposal_interval: int} [@@deriving yojson, bin_io]

  let t = {proposal_interval= Constants.block_window_duration_ms}
end

module Snark_transition = Coda_base.Snark_transition.Make (struct
  module Genesis_ledger = Genesis_ledger
  module Blockchain_state = Blockchain_state
  module Consensus_data = Consensus_transition_data
end)

let generate_transition ~previous_protocol_state ~blockchain_state ~time:_
    ~proposal_data ~transactions:_ ~snarked_ledger_hash:_ ~supply_increase:_
    ~logger:_ =
  let previous_consensus_state : Consensus_state.value =
    Protocol_state.consensus_state previous_protocol_state
  in
  (* TODO: sign protocol_state instead of blockchain_state *)
  let consensus_transition_data =
    Consensus_transition_data.create_value ~private_key:proposal_data
      blockchain_state
  in
  let consensus_state =
    let open Consensus_state in
    { length= Length.succ previous_consensus_state.length
    ; signer_public_key= Global_public_key.compressed }
  in
  let protocol_state =
    Protocol_state.create_value
      ~previous_state_hash:(Protocol_state.hash previous_protocol_state)
      ~blockchain_state ~consensus_state
  in
  (protocol_state, consensus_transition_data)

let received_at_valid_time _ ~time_received:_ = true

let is_transition_valid_checked (transition : Snark_transition.var) =
  let Consensus_transition_data.({signature}) =
    Snark_transition.consensus_data transition
  in
  let open Snark_params.Tick.Checked.Let_syntax in
  let%bind (module Shifted) =
    Snark_params.Tick.Inner_curve.Checked.Shifted.create ()
  in
  Blockchain_state.Signature.Checked.verifies
    (module Shifted)
    signature
    (Public_key.var_of_t Global_public_key.t)
    (transition |> Snark_transition.blockchain_state)

let next_state_checked ~(prev_state : Protocol_state.var) ~prev_state_hash:_
    block _supply_increase =
  let open Consensus_state in
  let open Snark_params.Tick.Checked.Let_syntax in
  let prev_state = Protocol_state.consensus_state prev_state in
  let%bind length = Length.increment_var prev_state.length in
  let signer_public_key =
    Public_key.Compressed.var_of_t @@ Global_public_key.compressed
  in
  let%map () =
    Public_key.Compressed.Checked.Assert.equal prev_state.signer_public_key
      signer_public_key
  and success = is_transition_valid_checked block in
  (`Success success, {length; signer_public_key})

let select ~existing:Consensus_state.({length= l1; signer_public_key= _})
    ~candidate:Consensus_state.({length= l2; signer_public_key= _}) ~logger:_ =
  if Length.compare l1 l2 >= 0 then `Keep else `Take

let next_proposal now _state ~local_state:_ ~keypair ~logger:_ =
  let open Unix_timestamp in
  let time_since_last_interval =
    rem now (of_int Constants.block_window_duration_ms)
  in
  let proposal_time =
    now - time_since_last_interval + of_int Constants.block_window_duration_ms
  in
  `Propose (proposal_time, keypair.Keypair.private_key)

let lock_transition _ _ ~local_state:_ ~snarked_ledger:_ = ()

let create_genesis_protocol_state ~blockchain_state =
  let state =
    Protocol_state.create_value
      ~previous_state_hash:(Protocol_state.hash Protocol_state.negative_one)
      ~blockchain_state
      ~consensus_state:
        (Consensus_state.update
           (Protocol_state.consensus_state Protocol_state.negative_one))
  in
  With_hash.of_data ~hash_data:Protocol_state.hash state

let genesis_protocol_state =
  let state =
    Protocol_state.create_value
      ~previous_state_hash:(Protocol_state.hash Protocol_state.negative_one)
      ~blockchain_state:
        (Snark_transition.genesis |> Snark_transition.blockchain_state)
      ~consensus_state:
        (Consensus_state.update
           (Protocol_state.consensus_state Protocol_state.negative_one))
  in
  With_hash.of_data ~hash_data:Protocol_state.hash state

module For_tests = struct
  let gen_consensus_state ~gen_slot_advancement:_ =
    let open Consensus_state in
    Quickcheck.Generator.return
    @@ fun ~previous_protocol_state ~snarked_ledger_hash:_ ->
    let prev : Consensus_state.value =
      Protocol_state.consensus_state (With_hash.data previous_protocol_state)
    in
    {length= Length.succ prev.length; signer_public_key= prev.signer_public_key}

  let create_genesis_protocol_state ledger =
    let root_ledger_hash = Ledger.merkle_root ledger in
    create_genesis_protocol_state
      ~blockchain_state:
        { Blockchain_state.genesis with
          staged_ledger_hash=
            Staged_ledger_hash.(
              of_aux_ledger_and_coinbase_hash Aux_hash.dummy root_ledger_hash
                (Pending_coinbase.create () |> Or_error.ok_exn))
        ; snarked_ledger_hash=
            Frozen_ledger_hash.of_ledger_hash root_ledger_hash }
end

let should_bootstrap ~existing:_ ~candidate:_ = false

let time_hum now = Core_kernel.Time.to_string now

[%%endif]
