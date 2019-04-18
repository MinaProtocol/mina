[%%import
"../../config.mlh"]

open Core_kernel
open Snark_params.Tick
open Tuple_lib
open Fold_lib
open Coda_numbers
open Module_version

module type Consensus_state_intf = sig
  module Value : sig
    (* bin_io omitted *)
    type t [@@deriving hash, compare, eq, sexp, to_yojson]

    module Stable :
      sig
        module V1 : sig
          type t
          [@@deriving hash, compare, bin_io, sexp, eq, to_yojson, version]
        end
      end
      with type V1.t = t
  end

  type display [@@deriving yojson]

  include Snarkable.S with type value := Value.t

  val genesis : Value.t

  val length_in_triples : int

  val var_to_triples : var -> (Boolean.var Triple.t list, _) Checked.t

  val fold : Value.t -> bool Triple.t Fold.t

  (** For status *)
  val length : Value.t -> Length.t

  (** For status *)
  val time_hum : Value.t -> string

  val to_lite : (Value.t -> Lite_base.Consensus_state.t) option

  val display : Value.t -> display
end

module Poly = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type ('state_hash, 'body) t =
          {previous_state_hash: 'state_hash; body: 'body}
        [@@deriving eq, ord, bin_io, hash, sexp, to_yojson, version]
      end

      include T
    end

    module Latest = V1
  end

  type ('state_hash, 'body) t = ('state_hash, 'body) Stable.Latest.t =
    {previous_state_hash: 'state_hash; body: 'body}
  [@@deriving sexp]
end

module type S = sig
  module Blockchain_state : Blockchain_state.S

  module Consensus_state : Consensus_state_intf

  module Body : sig
    module Poly : sig
      type ('a, 'b) t [@@deriving sexp]

      module Stable :
        sig
          module V1 : sig
            type ('a, 'b) t [@@deriving bin_io, sexp, version]
          end

          module Latest : module type of V1
        end
        with type ('a, 'b) V1.t = ('a, 'b) t
    end

    module Value : sig
      module Stable : sig
        module V1 : sig
          type t =
            ( Blockchain_state.Value.Stable.V1.t
            , Consensus_state.Value.Stable.V1.t )
            Poly.Stable.V1.t
          [@@deriving bin_io, sexp, to_yojson, version]
        end

        module Latest : module type of V1
      end

      (* bin_io omitted *)
      type t = Stable.Latest.t [@@deriving sexp, to_yojson]
    end

    type var = (Blockchain_state.var, Consensus_state.var) Poly.t

    type ('a, 'b) t = ('a, 'b) Poly.t

    val hash : Value.t -> State_body_hash.t
  end

  module Value : sig
    module Stable : sig
      module V1 : sig
        type t =
          (State_hash.Stable.V1.t, Body.Value.Stable.V1.t) Poly.Stable.V1.t
        [@@deriving sexp, bin_io, compare, eq, to_yojson, version]
      end

      module Latest : module type of V1
    end

    (* bin_io omitted *)
    type t = Stable.Latest.t [@@deriving sexp, compare, eq, to_yojson]

    include Hashable.S with type t := t
  end

  type value = Value.t [@@deriving sexp, to_yojson]

  type var = (State_hash.var, Body.var) Poly.t

  include Snarkable.S with type value := Value.t and type var := var

  val create : previous_state_hash:'a -> body:'b -> ('a, 'b) Poly.t

  val create_value :
       previous_state_hash:State_hash.t
    -> blockchain_state:Blockchain_state.Value.t
    -> consensus_state:Consensus_state.Value.t
    -> Value.t

  val create_var :
       previous_state_hash:State_hash.var
    -> blockchain_state:Blockchain_state.var
    -> consensus_state:Consensus_state.var
    -> var

  val previous_state_hash : ('a, _) Poly.t -> 'a

  val body : (_, 'a) Poly.t -> 'a

  val blockchain_state : (_, ('a, _) Body.t) Poly.t -> 'a

  val consensus_state : (_, (_, 'a) Body.t) Poly.t -> 'a

  val negative_one : Value.t

  val var_to_triples : var -> (Boolean.var Triple.t list, _) Checked.t

  val hash : Value.t -> State_hash.t
end

let fold ~fold_body {Poly.previous_state_hash; body} =
  let open Fold in
  State_hash.fold previous_state_hash +> fold_body body

let hash ~hash_body t =
  Snark_params.Tick.Pedersen.digest_fold Hash_prefix.protocol_state
    (fold ~fold_body:(Fn.compose State_body_hash.fold hash_body) t)
  |> State_hash.of_hash

let crypto_hash = hash

module Make
    (Blockchain_state : Blockchain_state.S)
    (Consensus_state : Consensus_state_intf) :
  S
  with module Blockchain_state = Blockchain_state
   and module Consensus_state = Consensus_state = struct
  module Blockchain_state = Blockchain_state
  module Consensus_state = Consensus_state

  module Body = struct
    module Poly = struct
      module Stable = struct
        module V1 = struct
          module T = struct
            type ('blockchain_state, 'consensus_state) t =
              { blockchain_state: 'blockchain_state
              ; consensus_state: 'consensus_state }
            [@@deriving bin_io, sexp, eq, compare, to_yojson, hash, version]
          end

          include T
        end

        module Latest = V1
      end

      type ('blockchain_state, 'consensus_state) t =
                                                    ( 'blockchain_state
                                                    , 'consensus_state )
                                                    Stable.Latest.t =
        {blockchain_state: 'blockchain_state; consensus_state: 'consensus_state}
      [@@deriving sexp]
    end

    module Value = struct
      module Stable = struct
        module V1 = struct
          module T = struct
            type t =
              ( Blockchain_state.Value.Stable.V1.t
              , Consensus_state.Value.Stable.V1.t )
              Poly.Stable.V1.t
            [@@deriving eq, ord, bin_io, hash, sexp, to_yojson, version]
          end

          include T
          include Registration.Make_latest_version (T)
        end

        module Latest = V1

        module Module_decl = struct
          let name = "protocol_state_body"

          type latest = Latest.t
        end

        module Registrar = Registration.Make (Module_decl)
        module Registered_V1 = Registrar.Register (V1)
      end

      type t = Stable.Latest.t [@@deriving sexp, to_yojson]
    end

    type ('blockchain_state, 'consensus_state) t =
      ('blockchain_state, 'consensus_state) Poly.t

    type value = Value.t [@@deriving sexp, to_yojson]

    type var = (Blockchain_state.var, Consensus_state.var) Poly.t

    let to_hlist {Poly.blockchain_state; consensus_state} =
      H_list.[blockchain_state; consensus_state]

    let of_hlist : (unit, 'bs -> 'cs -> unit) H_list.t -> ('bs, 'cs) Poly.t =
     fun H_list.([blockchain_state; consensus_state]) ->
      {blockchain_state; consensus_state}

    let data_spec = Data_spec.[Blockchain_state.typ; Consensus_state.typ]

    let typ =
      Typ.of_hlistable data_spec ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
        ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

    let fold {Poly.blockchain_state; consensus_state} =
      let open Fold in
      Blockchain_state.fold blockchain_state
      +> Consensus_state.fold consensus_state

    let hash s =
      Snark_params.Tick.Pedersen.digest_fold Hash_prefix.protocol_state_body
        (fold s)
      |> State_body_hash.of_hash

    let var_to_triples {Poly.blockchain_state; consensus_state} =
      let%map blockchain_state =
        Blockchain_state.var_to_triples blockchain_state
      and consensus_state = Consensus_state.var_to_triples consensus_state in
      blockchain_state @ consensus_state

    let hash_checked (t : var) =
      let open Let_syntax in
      var_to_triples t
      >>= Snark_params.Tick.Pedersen.Checked.digest_triples
            ~init:Hash_prefix.protocol_state_body
      >>| State_body_hash.var_of_hash_packed
  end

  module Value = struct
    module Stable = struct
      module V1 = struct
        module T = struct
          type t =
            (State_hash.Stable.V1.t, Body.Value.Stable.V1.t) Poly.Stable.V1.t
          [@@deriving bin_io, sexp, hash, compare, eq, to_yojson, version]
        end

        include T
        include Registration.Make_latest_version (T)
      end

      module Latest = V1

      module Module_decl = struct
        let name = "protocol_state_value"

        type latest = Latest.t
      end

      module Registrar = Registration.Make (Module_decl)
      module Registered_V1 = Registrar.Register (V1)
    end

    (* bin_io omitted *)
    type t = Stable.Latest.t [@@deriving sexp, hash, compare, eq, to_yojson]

    include Hashable.Make (Stable.Latest)
  end

  type value = Value.t [@@deriving sexp, to_yojson]

  type var = (State_hash.var, Body.var) Poly.t

  module Proof = Proof
  module Hash = State_hash

  let create ~previous_state_hash ~body = {Poly.previous_state_hash; body}

  let create' ~previous_state_hash ~blockchain_state ~consensus_state =
    { Poly.previous_state_hash
    ; body= {Body.Poly.blockchain_state; consensus_state} }

  let create_value = create'

  let create_var = create'

  let body {Poly.body; _} = body

  let previous_state_hash {Poly.previous_state_hash; _} = previous_state_hash

  let blockchain_state {Poly.body= {Body.Poly.blockchain_state; _}; _} =
    blockchain_state

  let consensus_state {Poly.body= {Body.Poly.consensus_state; _}; _} =
    consensus_state

  let to_hlist {Poly.previous_state_hash; body} =
    H_list.[previous_state_hash; body]

  let of_hlist : (unit, 'psh -> 'body -> unit) H_list.t -> ('psh, 'body) Poly.t
      =
   fun H_list.([previous_state_hash; body]) -> {previous_state_hash; body}

  let data_spec = Data_spec.[State_hash.typ; Body.typ]

  let typ =
    Typ.of_hlistable data_spec ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
      ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

  let var_to_triples {Poly.previous_state_hash; body} =
    let open Let_syntax in
    let%map previous_state_hash = State_hash.var_to_triples previous_state_hash
    and body_hash =
      Body.hash_checked body >>= State_body_hash.var_to_triples
    in
    previous_state_hash @ body_hash

  let hash = crypto_hash ~hash_body:Body.hash

  [%%if
  call_logger]

  let hash s =
    Coda_debug.Call_logger.record_call "Protocol_state.hash" ;
    hash s

  [%%endif]

  let negative_one =
    { Poly.previous_state_hash=
        State_hash.of_hash Snark_params.Tick.Pedersen.zero_hash
    ; body=
        { Body.Poly.blockchain_state= Blockchain_state.genesis
        ; consensus_state= Consensus_state.genesis } }
end
