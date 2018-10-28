open Core_kernel
open Coda_numbers
open Coda_base
open Fold_lib
open Signature_lib

module Global_public_key = struct
  let compressed =
    match Signer_private_key.mode with
    | `Dev -> fst Sample_keypairs.keypairs.(0)
    | `Prod ->
        Public_key.Compressed.of_base64_exn
          "KBWuaAm5Sl5jH/dlpiTKQeUUsty/4Rq6Xz2Py2Y2i/VweJmDHwUAAAAB"

  let t = Public_key.decompress_exn compressed
end

module type Inputs_intf = sig
  module Time : Protocols.Coda_pow.Time_intf

  module Ledger_builder_diff : sig
    type t [@@deriving bin_io, sexp]
  end

  module Genesis_ledger : sig
    val t : Coda_base.Ledger.t
  end

  val proposal_interval : Time.Span.t
end

module Make (Inputs : Inputs_intf) :
  Mechanism.S
  with type Internal_transition.Ledger_builder_diff.t =
              Inputs.Ledger_builder_diff.t
   and type External_transition.Ledger_builder_diff.t =
              Inputs.Ledger_builder_diff.t = struct
  open Inputs
  module Ledger_builder_diff = Ledger_builder_diff

  module Local_state = struct
    type t = unit [@@deriving sexp]

    let create () = ()
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

    let create_value blockchain_state =
      { signature=
          Blockchain_state.Signature.sign Signer_private_key.signer_private_key
            blockchain_state }

    let genesis = create_value Blockchain_state.genesis
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
  end

  module Protocol_state =
    Protocol_state.Make (Blockchain_state) (Consensus_state)

  module Snark_transition = Coda_base.Snark_transition.Make (struct
    module Genesis_ledger = Inputs.Genesis_ledger
    module Blockchain_state = Blockchain_state
    module Consensus_data = Consensus_transition_data
  end)

  module Internal_transition =
    Internal_transition.Make (Ledger_builder_diff) (Snark_transition)
  module External_transition =
    External_transition.Make (Ledger_builder_diff) (Protocol_state)

  let generate_transition ~previous_protocol_state ~blockchain_state
      ~local_state:_ ~time:_ ~keypair:_ ~transactions:_ ~ledger:_ ~logger:_ =
    let previous_consensus_state =
      Protocol_state.consensus_state previous_protocol_state
    in
    (* TODO: sign protocol_state instead of blockchain_state *)
    let consensus_transition_data =
      Consensus_transition_data.create_value blockchain_state
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
    Some (protocol_state, consensus_transition_data)

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

  let next_state_checked (state : Consensus_state.var) _state_hash _block =
    let open Consensus_state in
    let open Snark_params.Tick.Let_syntax in
    let%bind length = Length.increment_var state.length in
    let signer_public_key =
      Public_key.Compressed.var_of_t @@ Global_public_key.compressed
    in
    let%map () =
      Public_key.Compressed.Checked.Assert.equal state.signer_public_key
        signer_public_key
    in
    {length; signer_public_key}

  let update_local_state _ ~previous_consensus_state:_ ~next_consensus_state:_
      ~ledger:_ =
    ()

  let select Consensus_state.({length= l1; _})
      Consensus_state.({length= l2; _}) ~logger:_ ~time_received:_ =
    if l1 >= l2 then `Keep else `Take

  let next_proposal now _state ~local_state:_ ~keypair:_ ~logger:_ =
    let open Unix_timestamp in
    let time_since_last_interval =
      rem now (Time.Span.to_ms Inputs.proposal_interval)
    in
    let proposal_time =
      now - time_since_last_interval + Time.Span.to_ms Inputs.proposal_interval
    in
    `Propose proposal_time

  let lock_transition _ _ ~snarked_ledger:_ ~local_state:_ = ()

  let genesis_protocol_state =
    Protocol_state.create_value
      ~previous_state_hash:(Protocol_state.hash Protocol_state.negative_one)
      ~blockchain_state:
        (Snark_transition.genesis |> Snark_transition.blockchain_state)
      ~consensus_state:
        (Consensus_state.update
           (Protocol_state.consensus_state Protocol_state.negative_one))
end
