open Core_kernel
open Coda_numbers
open Nanobit_base

module Global_keypair = struct
  let private_key =
    "KgAAAAAAAAABKOg4N37Pm4VJevdeUWm/Lc7uPb7ZGWdTfngcSstK/2OsBQAAAAAAAAA="
    |> B64.decode |> Bigstring.of_string |> Private_key.of_bigstring
    |> Or_error.ok_exn

  let public_key = Public_key.of_private_key private_key
end

module Make
(Proof : sig
   type t [@@deriving bin_io, sexp]
 end)
(Ledger_builder_diff : sig
   type t [@@deriving sexp, bin_io]
end) :
  Mechanism.S with module Proof = Proof
   and type Internal_transition.Ledger_builder_diff.t = Ledger_builder_diff.t
   and type External_transition.Ledger_builder_diff.t = Ledger_builder_diff.t
=
struct
  module Proof = Proof
  module Ledger_builder_diff = Ledger_builder_diff

  module Consensus_data = struct
    type 'signature t_ = {signature: 'signature} [@@deriving bin_io, sexp]

    type value = Signature.t t_ [@@deriving bin_io, sexp]

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
          Blockchain_state.Signature.sign Global_keypair.private_key
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

    let equal = equal_t_ Length.equal Public_key.Compressed.equal

    let compare = compare_value

    let bit_length =
      Length.length_in_bits + Public_key.Compressed.length_in_bits

    let genesis =
      { length= Length.zero
      ; signer_public_key= Public_key.compress Global_keypair.public_key }

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

    let var_to_bits {length; signer_public_key} =
      let open Snark_params.Tick.Let_syntax in
      let%map public_key_bits =
        Public_key.Compressed.var_to_bits signer_public_key
      in
      Length.Unpacked.var_to_bits length @ public_key_bits
  end

  module Protocol_state = Protocol_state.Make (Consensus_state)
  module Snark_transition =
    Snark_transition.Make (Consensus_data) (Protocol_state) (Proof)
  module Internal_transition =
    Internal_transition.Make (Ledger_builder_diff) (Snark_transition)
  module External_transition = External_transition.Make(Ledger_builder_diff) (Protocol_state)

  let verify (transition: Snark_transition.var) =
    let Consensus_data.({signature}) =
      Snark_transition.consensus_data transition
    in
    Blockchain_state.Signature.Checked.verifies signature
      (Public_key.var_of_t Global_keypair.public_key)
      ( transition |> Snark_transition.protocol_state
      |> Protocol_state.blockchain_state )

  let update (state: Consensus_state.var) _block =
    let open Consensus_state in
    let open Snark_params.Tick.Let_syntax in
    let%bind length = Length.increment_var state.length in
    let signer_public_key =
      Public_key.Compressed.var_of_t
      @@ Public_key.compress Global_keypair.public_key
    in
    let%map () =
      Public_key.Compressed.assert_equal state.signer_public_key
        signer_public_key
    in
    {length; signer_public_key}

  let update_unchecked _state _transition = failwith "TODO"

  (*
    let consensus_state = () in
    { previous_state_hash= hash state
    ; blockchain_state= Consensus_mechanism.Block.blockchain_state block
    ; consensus_state }
         *)

  let step = Async_kernel.Deferred.Or_error.return

  let select Consensus_state.({length= l1; _})
      Consensus_state.({length= l2; _}) =
    if l1 >= l2 then `Keep else `Take

  let genesis_protocol_state =
    update_unchecked Protocol_state.negative_one Snark_transition.genesis

  let create_consensus_data state =
    (* TODO: sign protocol_state instead of blockchain_state *)
    Some (Consensus_data.create_value (Protocol_state.blockchain_state state))

  let create_consensus_state state =
    let open Consensus_state in
    let {length=old_length; signer_public_key=_} = Protocol_state.consensus_state state in
    {length= Length.succ old_length; signer_public_key= Public_key.compress Global_keypair.public_key}
end
