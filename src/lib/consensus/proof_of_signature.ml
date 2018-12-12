[%%import
"../../config.mlh"]

open Core_kernel
open Coda_numbers
open Coda_base
open Fold_lib
open Signature_lib

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

module type Inputs_intf = sig
  module Time : Protocols.Coda_pow.Time_intf

  module Genesis_ledger : sig
    val t : Coda_base.Ledger.t
  end

  val proposal_interval : Time.Span.t
end

module Make (Inputs : Inputs_intf) : Intf.S = struct
  open Inputs

  module Local_state = struct
    type t = unit [@@deriving sexp]

    let create _ = ()
  end

  module Prover_state = struct
    include Unit

    let handler _ _ = Snarky.Request.unhandled
  end

  module Proposal_data = struct
    include Private_key

    let prover_state _ = ()
  end

  module Blockchain_state =
    Coda_base.Blockchain_state.Make (Inputs.Genesis_ledger)
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
        ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
        ~value_of_hlist:of_hlist

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

    type value = (Length.t, Public_key.Compressed.t) t_
    [@@deriving bin_io, sexp, hash, compare]

    type var = (Length.Unpacked.var, Public_key.Compressed.var) t_

    let equal_value = equal_t_ Length.equal Public_key.Compressed.equal

    let length_in_triples =
      Length.length_in_triples + Public_key.Compressed.length_in_triples

    let genesis =
      {length= Length.zero; signer_public_key= Global_public_key.compressed}

    let to_hlist {length; signer_public_key} =
      H_list.[length; signer_public_key]

    let of_hlist :
           (unit, 'length -> 'public_key -> unit) H_list.t
        -> ('length, 'public_key) t_ =
     fun H_list.([length; signer_public_key]) -> {length; signer_public_key}

    let data_spec =
      let open Snark_params.Tick.Data_spec in
      [Length.Unpacked.typ; Public_key.Compressed.typ]

    let typ : (var, value) Snark_params.Tick.Typ.t =
      Snark_params.Tick.Typ.of_hlistable data_spec ~var_to_hlist:to_hlist
        ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
        ~value_of_hlist:of_hlist

    let var_to_triples {length; signer_public_key} =
      let open Snark_params.Tick.Let_syntax in
      let%map public_key_triples =
        Public_key.Compressed.var_to_triples signer_public_key
      in
      Length.Unpacked.var_to_triples length @ public_key_triples

    let fold {length; signer_public_key} =
      Fold.(Length.fold length +> Public_key.Compressed.fold signer_public_key)

    let update state =
      { length= Length.succ state.length
      ; signer_public_key= Global_public_key.compressed }

    let length t = t.length

    let to_lite =
      Some
        (fun {length; signer_public_key} ->
          { Lite_base.Consensus_state.length= Lite_compat.length length
          ; signer_public_key= Lite_compat.public_key signer_public_key } )

    let to_string_record t =
      Printf.sprintf "{length|%s}" (Length.to_string t.length)
  end

  module Protocol_state =
    Protocol_state.Make (Blockchain_state) (Consensus_state)

  module Snark_transition = Coda_base.Snark_transition.Make (struct
    module Genesis_ledger = Inputs.Genesis_ledger
    module Blockchain_state = Blockchain_state
    module Consensus_data = Consensus_transition_data
    module Prover_state = Prover_state
  end)

  module For_tests = struct
    let gen_consensus_state ~gen_slot_advancement:_ ~previous_protocol_state
        ~snarked_ledger_hash:_ : Consensus_state.value Quickcheck.Generator.t =
      let open Consensus_state in
      let prev =
        Protocol_state.consensus_state (With_hash.data previous_protocol_state)
      in
      Quickcheck.Let_syntax.return
        { length= Length.succ prev.length
        ; signer_public_key= prev.signer_public_key }
  end

  let block_interval_ms = Time.Span.to_ms proposal_interval

  let generate_transition ~previous_protocol_state ~blockchain_state ~time:_
      ~proposal_data ~transactions:_ ~snarked_ledger_hash:_ ~supply_increase:_
      ~logger:_ =
    let previous_consensus_state =
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

  let is_valid _ ~time_received:_ = true

  let is_transition_valid_checked (transition : Snark_transition.var) =
    let Consensus_transition_data.({signature}) =
      Snark_transition.consensus_data transition
    in
    let open Snark_params.Tick.Let_syntax in
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
    let open Snark_params.Tick.Let_syntax in
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

  let select ~existing:Consensus_state.({length= l1; _})
      ~candidate:Consensus_state.({length= l2; _}) ~logger:_ ~time_received:_ =
    if Length.compare l1 l2 >= 0 then `Keep else `Take

  let next_proposal now _state ~local_state:_ ~keypair ~logger:_ =
    let open Unix_timestamp in
    let time_since_last_interval =
      rem now (Time.Span.to_ms Inputs.proposal_interval)
    in
    let proposal_time =
      now - time_since_last_interval + Time.Span.to_ms Inputs.proposal_interval
    in
    `Propose (proposal_time, keypair.Keypair.private_key)

  let lock_transition ?proposer_public_key:_ _ _ ~snarked_ledger:_
      ~local_state:_ =
    ()

  let genesis_protocol_state =
    Protocol_state.create_value
      ~previous_state_hash:(Protocol_state.hash Protocol_state.negative_one)
      ~blockchain_state:
        (Snark_transition.genesis |> Snark_transition.blockchain_state)
      ~consensus_state:
        (Consensus_state.update
           (Protocol_state.consensus_state Protocol_state.negative_one))
end
