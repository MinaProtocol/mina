[%%import
"../../config.mlh"]

open Core_kernel
open Coda_base
open Snark_params.Tick

module Poly = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type ('state_hash, 'body) t =
        {previous_state_hash: 'state_hash; body: 'body}
      [@@deriving eq, ord, hash, sexp, to_yojson]
    end
  end]

  type ('state_hash, 'body) t = ('state_hash, 'body) Stable.Latest.t
  [@@deriving sexp]
end

let hash_abstract ~hash_body
    ({previous_state_hash; body} : (State_hash.t, _) Poly.t) =
  let body : State_body_hash.t = hash_body body in
  Random_oracle.hash ~init:Hash_prefix.protocol_state
    [|(previous_state_hash :> Field.t); (body :> Field.t)|]
  |> State_hash.of_hash

module Body = struct
  module Poly = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type ('blockchain_state, 'consensus_state) t =
          { blockchain_state: 'blockchain_state
          ; consensus_state: 'consensus_state }
        [@@deriving bin_io, sexp, eq, compare, to_yojson, hash, version]
      end
    end]

    type ('blockchain_state, 'consensus_state) t =
          ('blockchain_state, 'consensus_state) Stable.Latest.t =
      {blockchain_state: 'blockchain_state; consensus_state: 'consensus_state}
    [@@deriving sexp]
  end

  module Value = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t =
          ( Blockchain_state.Value.Stable.V1.t
          , Consensus.Data.Consensus_state.Value.Stable.V1.t )
          Poly.Stable.V1.t
        [@@deriving eq, ord, bin_io, hash, sexp, to_yojson, version]

        let to_latest = Fn.id
      end
    end]

    type t = Stable.Latest.t [@@deriving sexp, to_yojson]
  end

  type ('blockchain_state, 'consensus_state) t =
    ('blockchain_state, 'consensus_state) Poly.t

  type value = Value.t [@@deriving sexp, to_yojson]

  type var = (Blockchain_state.var, Consensus.Data.Consensus_state.var) Poly.t

  let to_hlist {Poly.blockchain_state; consensus_state} =
    H_list.[blockchain_state; consensus_state]

  let of_hlist : (unit, 'bs -> 'cs -> unit) H_list.t -> ('bs, 'cs) Poly.t =
   fun H_list.[blockchain_state; consensus_state] ->
    {blockchain_state; consensus_state}

  let data_spec =
    Data_spec.[Blockchain_state.typ; Consensus.Data.Consensus_state.typ]

  let typ =
    Typ.of_hlistable data_spec ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
      ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

  let to_input {Poly.blockchain_state; consensus_state} =
    Random_oracle.Input.append
      (Blockchain_state.to_input blockchain_state)
      (Consensus.Data.Consensus_state.to_input consensus_state)

  let var_to_input {Poly.blockchain_state; consensus_state} =
    let blockchain_state = Blockchain_state.var_to_input blockchain_state in
    let%map consensus_state =
      Consensus.Data.Consensus_state.var_to_input consensus_state
    in
    Random_oracle.Input.append blockchain_state consensus_state

  let hash s =
    Random_oracle.hash ~init:Hash_prefix.protocol_state_body
      (Random_oracle.pack_input (to_input s))
    |> State_body_hash.of_hash

  let hash_checked (t : var) =
    let%bind input = var_to_input t in
    make_checked (fun () ->
        Random_oracle.Checked.(
          hash ~init:Hash_prefix.protocol_state_body (pack_input input)
          |> State_body_hash.var_of_hash_packed) )
end

module Value = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        (State_hash.Stable.V1.t, Body.Value.Stable.V1.t) Poly.Stable.V1.t
      [@@deriving sexp, hash, compare, eq, to_yojson]

      let to_latest = Fn.id
    end
  end]

  type t = Stable.Latest.t [@@deriving sexp, hash, compare, eq, to_yojson]

  include Hashable.Make (Stable.Latest)
end

type value = Value.t [@@deriving sexp, to_yojson]

type var = (State_hash.var, Body.var) Poly.t

module Proof = Proof
module Hash = State_hash

let create ~previous_state_hash ~body =
  {Poly.Stable.Latest.previous_state_hash; body}

let create' ~previous_state_hash ~blockchain_state ~consensus_state =
  { Poly.Stable.Latest.previous_state_hash
  ; body= {Body.Poly.blockchain_state; consensus_state} }

let create_value = create'

let create_var = create'

let body {Poly.Stable.Latest.body; _} = body

let previous_state_hash {Poly.Stable.Latest.previous_state_hash; _} =
  previous_state_hash

let blockchain_state
    {Poly.Stable.Latest.body= {Body.Poly.blockchain_state; _}; _} =
  blockchain_state

let consensus_state {Poly.Stable.Latest.body= {Body.Poly.consensus_state; _}; _}
    =
  consensus_state

let to_hlist {Poly.Stable.Latest.previous_state_hash; body} =
  H_list.[previous_state_hash; body]

let of_hlist : (unit, 'psh -> 'body -> unit) H_list.t -> ('psh, 'body) Poly.t =
 fun H_list.[previous_state_hash; body] -> {previous_state_hash; body}

let data_spec = Data_spec.[State_hash.typ; Body.typ]

let typ =
  Typ.of_hlistable data_spec ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
    ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

let hash = hash_abstract ~hash_body:Body.hash

let hash_checked ({previous_state_hash; body} : var) =
  let%bind body = Body.hash_checked body in
  let%map hash =
    make_checked (fun () ->
        Random_oracle.Checked.hash
          ~init:Hash_prefix.protocol_state
          [| Hash.var_to_hash_packed previous_state_hash
           ; State_body_hash.var_to_hash_packed body |]
        |> State_hash.var_of_hash_packed )
  in
  (hash, body)

[%%if
call_logger]

let hash s =
  Coda_debug.Call_logger.record_call "Protocol_state.hash" ;
  hash s

[%%endif]

let negative_one =
  lazy
    { Poly.Stable.Latest.previous_state_hash=
        State_hash.of_hash Snark_params.Tick.Pedersen.zero_hash
    ; body=
        { Body.Poly.blockchain_state= Lazy.force Blockchain_state.negative_one
        ; consensus_state=
            Lazy.force Consensus.Data.Consensus_state.negative_one } }
