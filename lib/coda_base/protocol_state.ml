open Core_kernel
open Snark_params.Tick
open Tuple_lib
open Fold_lib
open Coda_numbers

module type Consensus_state_intf = sig
  type value [@@deriving hash, compare, bin_io, sexp]

  include Snarkable.S with type value := value

  val equal_value : value -> value -> bool

  val compare_value : value -> value -> int

  val genesis : value

  val length_in_triples : int

  val var_to_triples : var -> (Boolean.var Triple.t list, _) Checked.t

  val fold : value -> bool Triple.t Fold.t

  val length : value -> Length.t
  (** For status *)
end

module type S = sig
  module Consensus_state : Consensus_state_intf

  type ('a, 'b, 'c) t [@@deriving bin_io, sexp]

  type value =
    (State_hash.Stable.V1.t, Blockchain_state.value, Consensus_state.value) t
  [@@deriving bin_io, sexp]

  type var = (State_hash.var, Blockchain_state.var, Consensus_state.var) t

  include Snarkable.S with type value := value and type var := var

  include Hashable.S with type t := value

  val equal_value : value -> value -> bool

  val compare_value : value -> value -> int

  val create_value :
       previous_state_hash:State_hash.Stable.V1.t
    -> blockchain_state:Blockchain_state.t
    -> consensus_state:Consensus_state.value
    -> value

  val create_var :
       previous_state_hash:State_hash.var
    -> blockchain_state:Blockchain_state.var
    -> consensus_state:Consensus_state.var
    -> var

  val previous_state_hash : ('a, _, _) t -> 'a

  val blockchain_state : (_, 'a, _) t -> 'a

  val consensus_state : (_, _, 'a) t -> 'a

  val negative_one : value

  val length_in_triples : int

  val var_to_triples : var -> (Boolean.var Triple.t list, _) Checked.t

  val hash : value -> State_hash.Stable.V1.t
end

module Make (Consensus_state : Consensus_state_intf) :
  S with module Consensus_state = Consensus_state =
struct
  module Consensus_state = Consensus_state

  type ('state_hash, 'blockchain_state, 'consensus_state) t =
    { previous_state_hash: 'state_hash
    ; blockchain_state: 'blockchain_state
    ; consensus_state: 'consensus_state }
  [@@deriving eq, ord, bin_io, hash, sexp]

  module Value = struct
    type value =
      (State_hash.Stable.V1.t, Blockchain_state.value, Consensus_state.value) t
    [@@deriving bin_io, sexp, hash, compare]

    type t = value [@@deriving bin_io, sexp, hash, compare]
  end

  type value = Value.t [@@deriving bin_io, sexp, hash, compare]

  include Hashable.Make (Value)

  type var = (State_hash.var, Blockchain_state.var, Consensus_state.var) t

  module Proof = Proof
  module Hash = State_hash

  let equal_value =
    equal State_hash.equal Blockchain_state.equal Consensus_state.equal_value

  let create ~previous_state_hash ~blockchain_state ~consensus_state =
    {previous_state_hash; blockchain_state; consensus_state}

  let create_value = create

  let create_var = create

  let previous_state_hash {previous_state_hash; _} = previous_state_hash

  let blockchain_state {blockchain_state; _} = blockchain_state

  let consensus_state {consensus_state; _} = consensus_state

  let to_hlist {previous_state_hash; blockchain_state; consensus_state} =
    H_list.[previous_state_hash; blockchain_state; consensus_state]

  let of_hlist :
      (unit, 'psh -> 'bs -> 'cs -> unit) H_list.t -> ('psh, 'bs, 'cs) t =
   fun H_list.([previous_state_hash; blockchain_state; consensus_state]) ->
    {previous_state_hash; blockchain_state; consensus_state}

  let data_spec =
    Data_spec.[State_hash.typ; Blockchain_state.typ; Consensus_state.typ]

  let typ =
    Typ.of_hlistable data_spec ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
      ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

  let var_to_triples {previous_state_hash; blockchain_state; consensus_state} =
    let open Let_syntax in
    let%map previous_state_hash = State_hash.var_to_triples previous_state_hash
    and blockchain_state = Blockchain_state.var_to_triples blockchain_state
    and consensus_state = Consensus_state.var_to_triples consensus_state in
    previous_state_hash @ blockchain_state @ consensus_state

  let length_in_triples =
    State_hash.length_in_triples + Blockchain_state.length_in_triples
    + Consensus_state.length_in_triples

  let fold {previous_state_hash; blockchain_state; consensus_state} =
    let open Fold in
    State_hash.fold previous_state_hash
    +> Blockchain_state.fold blockchain_state
    +> Consensus_state.fold consensus_state

  let hash s =
    Snark_params.Tick.Pedersen.digest_fold Hash_prefix.protocol_state (fold s)
    |> State_hash.of_hash

  let negative_one =
    { previous_state_hash=
        State_hash.of_hash Snark_params.Tick.Pedersen.zero_hash
    ; blockchain_state= Blockchain_state.genesis
    ; consensus_state= Consensus_state.genesis }
end

let%test_module "Protocol_state tests" =
  ( module struct
    open Currency

    module Consensus_state = struct
      type ('amount, 'ledger_hash) t =
        {amount: 'amount; ledger_hash: 'ledger_hash}
      [@@deriving hash, compare, bin_io, sexp, eq]

      type value = (Amount.t, Ledger_hash.t) t
      [@@deriving hash, compare, bin_io, sexp, eq]

      type var = (Amount.var, Ledger_hash.var) t

      let genesis =
        { amount= Amount.of_int 0
        ; ledger_hash= Ledger_hash.of_hash Snark_params.Tick.Pedersen.zero_hash
        }

      let to_hlist {amount; ledger_hash} = H_list.[amount; ledger_hash]

      let of_hlist :
             (unit, 'amount -> 'ledger_hash -> unit) H_list.t
          -> ('amount, 'ledger_hash) t =
       fun H_list.([amount; ledger_hash]) -> {amount; ledger_hash}

      let data_spec = Snark_params.Tick.Data_spec.[Amount.typ; Ledger_hash.typ]

      let typ =
        Snark_params.Tick.Typ.of_hlistable data_spec ~var_to_hlist:to_hlist
          ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
          ~value_of_hlist:of_hlist

      let fold {amount; ledger_hash} =
        Fold.(Amount.fold amount +> Ledger_hash.fold ledger_hash)

      let var_to_triples {amount; ledger_hash} =
        let open Snark_params.Tick.Let_syntax in
        let%map ledger_hash_triples = Ledger_hash.var_to_triples ledger_hash in
        Amount.var_to_triples amount @ ledger_hash_triples

      let length_in_triples =
        Amount.length_in_triples + Ledger_hash.length_in_triples

      let length _ = Length.of_int 0
    end

    module Protocol_state = Make (Consensus_state)

    let%test_unit "profile hashes" =
      let state =
        Protocol_state.create_value
          ~previous_state_hash:(State_hash.of_hash State_hash.zero)
          ~blockchain_state:
            (Blockchain_state.create_value
               ~ledger_builder_hash:Ledger_builder_hash.dummy
               ~ledger_hash:
                 (Frozen_ledger_hash.of_hash
                    Snark_params.Tick.Pedersen.zero_hash)
               ~timestamp:(Block_time.now ()))
          ~consensus_state:Consensus_state.genesis
      in
      for i = 0 to 100 do ignore (Protocol_state.hash state) done

    (*
      let gen =
        let open Quickcheck.Generator.Let_syntax in
        let%map previous_state_hash = State_hash.gen
        and blockchain_state = Blockchain_state.gen
        and consensus_state = Consensus_state.gen in
        Protocol_state.create_value
          ~previous_state_hash
          ~blockchain_state
          ~consensus_state
      in
      Quickcheck.test gen (fun s -> ignore (Protocol_state.hash s))
         *)
  end )
