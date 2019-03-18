[%%import
"../../config.mlh"]

open Core_kernel
open Snark_params.Tick
open Tuple_lib
open Fold_lib
open Coda_numbers
open Module_version

module type Consensus_state_intf = sig
  type value [@@deriving hash, compare, bin_io, sexp]

  type display [@@deriving yojson]

  include Snarkable.S with type value := value

  val equal_value : value -> value -> bool

  val compare_value : value -> value -> int

  val genesis : value

  val length_in_triples : int

  val var_to_triples : var -> (Boolean.var Triple.t list, _) Checked.t

  val fold : value -> bool Triple.t Fold.t

  val length : value -> Length.t
  (** For status *)

  val time_hum : value -> string
  (** For status *)

  val to_lite : (value -> Lite_base.Consensus_state.t) option

  val display : value -> display
end

module type S = sig
  module Blockchain_state : Blockchain_state.S

  module Consensus_state : Consensus_state_intf

  module Body : sig
    type ('a, 'b) t [@@deriving bin_io, sexp]

    module Value : sig
      module Stable : sig
        module V1 : sig
          (* TODO : version these pieces *)
          type nonrec t = (Blockchain_state.value, Consensus_state.value) t
          [@@deriving bin_io, sexp]
        end

        module Latest : module type of V1
      end

      (* bin_io omitted *)
      type t = Stable.Latest.t [@@deriving sexp]
    end

    type var = (Blockchain_state.var, Consensus_state.var) t

    val hash : Value.t -> State_body_hash.t
  end

  type ('a, 'body) t [@@deriving bin_io, sexp]

  module Value : sig
    module Stable : sig
      module V1 : sig
        type nonrec t = (State_hash.Stable.V1.t, Body.Value.Stable.V1.t) t
        [@@deriving sexp, bin_io, compare, eq]
      end

      module Latest : module type of V1
    end

    (* bin_io omitted *)
    type t = Stable.Latest.t [@@deriving sexp, compare, eq]

    include Hashable.S with type t := t
  end

  type value = Value.t [@@deriving sexp]

  type var = (State_hash.var, Body.var) t

  include Snarkable.S with type value := Value.t and type var := var

  val create : previous_state_hash:'a -> body:'b -> ('a, 'b) t

  val create_value :
       previous_state_hash:State_hash.t
    -> blockchain_state:Blockchain_state.Value.t
    -> consensus_state:Consensus_state.value
    -> Value.t

  val create_var :
       previous_state_hash:State_hash.var
    -> blockchain_state:Blockchain_state.var
    -> consensus_state:Consensus_state.var
    -> var

  val previous_state_hash : ('a, _) t -> 'a

  val body : (_, 'a) t -> 'a

  val blockchain_state : (_, ('a, _) Body.t) t -> 'a

  val consensus_state : (_, (_, 'a) Body.t) t -> 'a

  val negative_one : Value.t

  val var_to_triples : var -> (Boolean.var Triple.t list, _) Checked.t

  val hash : Value.t -> State_hash.t
end

module T = struct
  type ('state_hash, 'body) t = {previous_state_hash: 'state_hash; body: 'body}
  [@@deriving eq, ord, bin_io, hash, sexp]
end

include T

let fold ~fold_body {previous_state_hash; body} =
  let open Fold in
  State_hash.fold previous_state_hash +> fold_body body

let hash ~hash_body t =
  Snark_params.Tick.Pedersen.digest_fold Hash_prefix.protocol_state
    (fold ~fold_body:(Fn.compose State_body_hash.fold hash_body) t)
  |> State_hash.of_hash

let crypto_hash = hash

module Body = struct
  type ('blockchain_state, 'consensus_state) t =
    {blockchain_state: 'blockchain_state; consensus_state: 'consensus_state}
  [@@deriving eq, ord, bin_io, hash, sexp]
end

module Make
    (Blockchain_state : Blockchain_state.S)
    (Consensus_state : Consensus_state_intf) :
  S
  with module Blockchain_state = Blockchain_state
   and module Consensus_state = Consensus_state
   and type ('a, 'b) t = ('a, 'b) t
   and type ('a, 'b) Body.t = ('a, 'b) Body.t = struct
  module Blockchain_state = Blockchain_state
  module Consensus_state = Consensus_state

  module Body = struct
    include Body

    module Value = struct
      module Stable = struct
        module V1 = struct
          module T = struct
            let version = 1

            type tt = (Blockchain_state.Stable.V1.t, Consensus_state.value) t
            [@@deriving eq, ord, bin_io, hash, sexp]

            type t = tt [@@deriving eq, ord, bin_io, hash, sexp]
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

      type t = Stable.Latest.t [@@deriving sexp]
    end

    type var = (Blockchain_state.var, Consensus_state.var) t

    let to_hlist {blockchain_state; consensus_state} =
      H_list.[blockchain_state; consensus_state]

    let of_hlist : (unit, 'bs -> 'cs -> unit) H_list.t -> ('bs, 'cs) t =
     fun H_list.([blockchain_state; consensus_state]) ->
      {blockchain_state; consensus_state}

    let data_spec = Data_spec.[Blockchain_state.typ; Consensus_state.typ]

    let typ =
      Typ.of_hlistable data_spec ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
        ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

    let fold {blockchain_state; consensus_state} =
      let open Fold in
      Blockchain_state.fold blockchain_state
      +> Consensus_state.fold consensus_state

    let hash s =
      Snark_params.Tick.Pedersen.digest_fold Hash_prefix.protocol_state_body
        (fold s)
      |> State_body_hash.of_hash

    let var_to_triples {blockchain_state; consensus_state} =
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

  include T

  module Value = struct
    module Stable = struct
      module V1 = struct
        module T = struct
          let version = 1

          type t_ = (State_hash.Stable.V1.t, Body.Value.Stable.V1.t) t
          [@@deriving bin_io, sexp, hash, compare, eq]

          type t = t_ [@@deriving bin_io, sexp, hash, compare, eq]
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
    type t = Stable.Latest.t [@@deriving sexp, hash, compare, eq]

    include Hashable.Make (Stable.Latest)
  end

  type value = Value.t [@@deriving sexp]

  type var = (State_hash.var, Body.var) t

  module Proof = Proof
  module Hash = State_hash

  let create ~previous_state_hash ~body = {previous_state_hash; body}

  let create' ~previous_state_hash ~blockchain_state ~consensus_state =
    {previous_state_hash; body= {Body.blockchain_state; consensus_state}}

  let create_value = create'

  let create_var = create'

  let body {body; _} = body

  let previous_state_hash {previous_state_hash; _} = previous_state_hash

  let blockchain_state {body= {Body.blockchain_state; _}; _} = blockchain_state

  let consensus_state {body= {Body.consensus_state; _}; _} = consensus_state

  let to_hlist {previous_state_hash; body} = H_list.[previous_state_hash; body]

  let of_hlist : (unit, 'psh -> 'body -> unit) H_list.t -> ('psh, 'body) t =
   fun H_list.([previous_state_hash; body]) -> {previous_state_hash; body}

  let data_spec = Data_spec.[State_hash.typ; Body.typ]

  let typ =
    Typ.of_hlistable data_spec ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
      ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

  let var_to_triples {previous_state_hash; body} =
    let open Let_syntax in
    let%map previous_state_hash = State_hash.var_to_triples previous_state_hash
    and body_hash =
      Body.hash_checked body >>= State_body_hash.var_to_triples
    in
    previous_state_hash @ body_hash

  let fold t = fold ~fold_body:(Fn.compose State_body_hash.fold Body.hash) t

  let hash = crypto_hash ~hash_body:Body.hash

  [%%if
  call_logger]

  let hash s =
    Coda_debug.Call_logger.record_call "Protocol_state.hash" ;
    hash s

  [%%endif]

  let negative_one =
    { previous_state_hash=
        State_hash.of_hash Snark_params.Tick.Pedersen.zero_hash
    ; body=
        { Body.blockchain_state= Blockchain_state.genesis
        ; consensus_state= Consensus_state.genesis } }
end
