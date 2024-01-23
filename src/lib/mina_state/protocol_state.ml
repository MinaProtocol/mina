[%%import "/src/config.mlh"]

open Core_kernel
open Mina_base

[%%ifdef consensus_mechanism]

open Snark_params.Tick

[%%endif]

module Wire_types = Mina_wire_types.Mina_state.Protocol_state

module Make_sig (A : Wire_types.Types.S) = struct
  module type S =
    Protocol_state_intf.Full
      with type ( 'state_hash
                , 'blockchain_state
                , 'consensus_state
                , 'constants )
                Body.Poly.Stable.V1.t =
        ( 'state_hash
        , 'blockchain_state
        , 'consensus_state
        , 'constants )
        A.Body.Poly.V1.t
       and type Body.Value.Stable.V2.t = A.Body.Value.V2.t
       and type ('state_hash, 'body) Poly.Stable.V1.t =
        ('state_hash, 'body) A.Poly.V1.t
       and type Value.Stable.V2.t = A.Value.V2.t
end

module Make_str (A : Wire_types.Concrete) = struct
  module Poly = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type ('state_hash, 'body) t = ('state_hash, 'body) A.Poly.V1.t =
          { previous_state_hash : 'state_hash; body : 'body }
        [@@deriving equal, ord, hash, sexp, yojson, hlist]
      end
    end]
  end

  let hashes_abstract ~hash_body
      ({ previous_state_hash; body } : (State_hash.t, _) Poly.t) =
    let state_body_hash : State_body_hash.t = hash_body body in
    let state_hash =
      Random_oracle.hash ~init:Hash_prefix.protocol_state
        [| (previous_state_hash :> Field.t); (state_body_hash :> Field.t) |]
      |> State_hash.of_hash
    in
    { State_hash.State_hashes.state_hash
    ; state_body_hash = Some state_body_hash
    }

  module Body = struct
    module Poly = struct
      [%%versioned
      module Stable = struct
        module V1 = struct
          type ('state_hash, 'blockchain_state, 'consensus_state, 'constants) t =
                ( 'state_hash
                , 'blockchain_state
                , 'consensus_state
                , 'constants )
                A.Body.Poly.V1.t =
            { genesis_state_hash : 'state_hash
            ; blockchain_state : 'blockchain_state
            ; consensus_state : 'consensus_state
            ; constants : 'constants
            }
          [@@deriving sexp, equal, compare, yojson, hash, version, hlist]
        end
      end]
    end

    module Value = struct
      [%%versioned
      module Stable = struct
        module V2 = struct
          type t =
            ( State_hash.Stable.V1.t
            , Blockchain_state.Value.Stable.V2.t
            , Consensus.Data.Consensus_state.Value.Stable.V2.t
            , Protocol_constants_checked.Value.Stable.V1.t )
            Poly.Stable.V1.t
          [@@deriving equal, ord, bin_io, hash, sexp, yojson, version]

          let to_latest = Fn.id
        end
      end]
    end

    type ('state_hash, 'blockchain_state, 'consensus_state, 'constants) t =
      ('state_hash, 'blockchain_state, 'consensus_state, 'constants) Poly.t

    type value = Value.t [@@deriving sexp, yojson]

    [%%ifdef consensus_mechanism]

    type var =
      ( State_hash.var
      , Blockchain_state.var
      , Consensus.Data.Consensus_state.var
      , Protocol_constants_checked.var )
      Poly.t

    let typ ~constraint_constants =
      Typ.of_hlistable
        [ State_hash.typ
        ; Blockchain_state.typ
        ; Consensus.Data.Consensus_state.typ ~constraint_constants
        ; Protocol_constants_checked.typ
        ]
        ~var_to_hlist:Poly.to_hlist ~var_of_hlist:Poly.of_hlist
        ~value_to_hlist:Poly.to_hlist ~value_of_hlist:Poly.of_hlist

    let to_input
        { Poly.genesis_state_hash : State_hash.t
        ; blockchain_state
        ; consensus_state
        ; constants
        } =
      Random_oracle.Input.Chunked.(
        append
          (Blockchain_state.to_input blockchain_state)
          (Consensus.Data.Consensus_state.to_input consensus_state)
        |> append (field (genesis_state_hash :> Field.t))
        |> append (Protocol_constants_checked.to_input constants))

    let var_to_input
        { Poly.genesis_state_hash
        ; blockchain_state
        ; consensus_state
        ; constants
        } =
      let%map blockchain_state =
        Blockchain_state.var_to_input blockchain_state
      in
      let constants = Protocol_constants_checked.var_to_input constants in
      let consensus_state =
        Consensus.Data.Consensus_state.var_to_input consensus_state
      in
      Random_oracle.Input.Chunked.(
        append blockchain_state consensus_state
        |> append (field (State_hash.var_to_hash_packed genesis_state_hash))
        |> append constants)

    let hash_checked (t : var) =
      let%bind input = var_to_input t in
      make_checked (fun () ->
          Random_oracle.Checked.(
            hash ~init:Hash_prefix.protocol_state_body (pack_input input)
            |> State_body_hash.var_of_hash_packed) )

    let consensus_state { Poly.consensus_state; _ } = consensus_state

    let view_checked (t : var) :
        Zkapp_precondition.Protocol_state.View.Checked.t =
      let module C = Consensus.Proof_of_stake.Exported.Consensus_state in
      let cs : Consensus.Data.Consensus_state.var = t.consensus_state in
      { snarked_ledger_hash =
          Blockchain_state.snarked_ledger_hash t.blockchain_state
      ; blockchain_length = C.blockchain_length_var cs
      ; min_window_density = C.min_window_density_var cs
      ; total_currency = C.total_currency_var cs
      ; global_slot_since_genesis = C.global_slot_since_genesis_var cs
      ; staking_epoch_data = C.staking_epoch_data_var cs
      ; next_epoch_data = C.next_epoch_data_var cs
      }

    [%%endif]

    let hash s =
      Random_oracle.hash ~init:Hash_prefix.protocol_state_body
        (Random_oracle.pack_input (to_input s))
      |> State_body_hash.of_hash

    let view (t : Value.t) : Zkapp_precondition.Protocol_state.View.t =
      let module C = Consensus.Proof_of_stake.Exported.Consensus_state in
      let cs = t.consensus_state in
      { snarked_ledger_hash =
          Blockchain_state.snarked_ledger_hash t.blockchain_state
      ; blockchain_length = C.blockchain_length cs
      ; min_window_density = C.min_window_density cs
      ; total_currency = C.total_currency cs
      ; global_slot_since_genesis = C.global_slot_since_genesis cs
      ; staking_epoch_data = C.staking_epoch_data cs
      ; next_epoch_data = C.next_epoch_data cs
      }

    module For_tests = struct
      let with_consensus_state (t : Value.t) consensus_state =
        { t with consensus_state }
    end
  end

  module Value = struct
    [%%versioned
    module Stable = struct
      module V2 = struct
        type t =
          (State_hash.Stable.V1.t, Body.Value.Stable.V2.t) Poly.Stable.V1.t
        [@@deriving sexp, hash, compare, equal, yojson]

        let to_latest = Fn.id
      end
    end]

    include Hashable.Make (Stable.Latest)
  end

  type value = Value.t [@@deriving sexp, yojson]

  [%%ifdef consensus_mechanism]

  type var = (State_hash.var, Body.var) Poly.t

  [%%endif]

  module Proof = Proof
  module Hash = State_hash

  let create ~previous_state_hash ~body =
    { Poly.Stable.Latest.previous_state_hash; body }

  let create' ~previous_state_hash ~genesis_state_hash ~blockchain_state
      ~consensus_state ~constants =
    { Poly.Stable.Latest.previous_state_hash
    ; body =
        { Body.Poly.genesis_state_hash
        ; blockchain_state
        ; consensus_state
        ; constants
        }
    }

  let create_value = create'

  let body { Poly.Stable.Latest.body; _ } = body

  let previous_state_hash { Poly.Stable.Latest.previous_state_hash; _ } =
    previous_state_hash

  let blockchain_state
      { Poly.Stable.Latest.body = { Body.Poly.blockchain_state; _ }; _ } =
    blockchain_state

  let consensus_state
      { Poly.Stable.Latest.body = { Body.Poly.consensus_state; _ }; _ } =
    consensus_state

  let constants { Poly.Stable.Latest.body = { Body.Poly.constants; _ }; _ } =
    constants

  [%%ifdef consensus_mechanism]

  let create_var = create'

  let typ ~constraint_constants =
    Typ.of_hlistable
      [ State_hash.typ; Body.typ ~constraint_constants ]
      ~var_to_hlist:Poly.to_hlist ~var_of_hlist:Poly.of_hlist
      ~value_to_hlist:Poly.to_hlist ~value_of_hlist:Poly.of_hlist

  let hash_checked ({ previous_state_hash; body } : var) =
    let%bind body = Body.hash_checked body in
    let%map hash =
      make_checked (fun () ->
          Random_oracle.Checked.hash ~init:Hash_prefix.protocol_state
            [| Hash.var_to_hash_packed previous_state_hash
             ; State_body_hash.var_to_hash_packed body
            |]
          |> State_hash.var_of_hash_packed )
    in
    (hash, body)

  let genesis_state_hash_checked ~state_hash state =
    let%bind is_genesis =
      (*if state is in global_slot = 0 then this is the genesis state*)
      Consensus.Data.Consensus_state.is_genesis_state_var
        (consensus_state state)
    in
    (*get the genesis state hash from this state unless the state itself is the
      genesis state*)
    State_hash.if_ is_genesis ~then_:state_hash
      ~else_:state.body.genesis_state_hash

  [%%endif]

  let hashes = hashes_abstract ~hash_body:Body.hash

  let hashes_with_body t ~body_hash =
    hashes_abstract ~hash_body:Fn.id
      { Poly.previous_state_hash = t.Poly.previous_state_hash
      ; body = body_hash
      }

  let genesis_state_hash ?(state_hash = None) state =
    (*If this is the genesis state then simply return its hash
      otherwise return its the genesis_state_hash*)
    if Consensus.Data.Consensus_state.is_genesis_state (consensus_state state)
    then
      match state_hash with
      | None ->
          (hashes state).state_hash
      | Some hash ->
          hash
    else state.body.genesis_state_hash

  [%%if call_logger]

  let hash s =
    Mina_debug.Call_logger.record_call "Protocol_state.hash" ;
    hash s

  [%%endif]

  let negative_one ~genesis_ledger ~genesis_epoch_data ~constraint_constants
      ~consensus_constants ~genesis_body_reference =
    { Poly.Stable.Latest.previous_state_hash =
        State_hash.of_hash Outside_hash_image.t
    ; body =
        { Body.Poly.blockchain_state =
            Blockchain_state.negative_one ~constraint_constants
              ~consensus_constants
              ~genesis_ledger_hash:
                (Mina_ledger.Ledger.merkle_root (Lazy.force genesis_ledger))
              ~genesis_body_reference
        ; genesis_state_hash = State_hash.of_hash Outside_hash_image.t
        ; consensus_state =
            Consensus.Data.Consensus_state.negative_one ~genesis_ledger
              ~genesis_epoch_data ~constants:consensus_constants
              ~constraint_constants
        ; constants =
            Consensus.Constants.to_protocol_constants consensus_constants
        }
    }
end

include Wire_types.Make (Make_sig) (Make_str)
