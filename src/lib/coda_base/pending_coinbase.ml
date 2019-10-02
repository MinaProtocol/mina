open Core_kernel
open Import
open Snarky
module Coda_base_util = Util
open Snark_params
open Snark_params.Tick
open Tuple_lib
open Let_syntax
open Currency
open Fold_lib
open Module_version

(* A pending coinbase is basically a Merkle tree of "stacks", each of which contains two hashes. The first hash
   is computed from the components in the coinbase via a "push" operation. The second hash, a protocol
   state hash, is computed from the state *body* hash in the coinbase, and a previous protocol state hash.
   The "add_coinbase" operation takes a coinbase, retrieves the latest stack, or creates a new one, and does
   a push.

   A pending coinbase also contains a stack id, used to determine the chronology of stacks, so we can know
   which is the oldest, and which is the newest stack.

   Also, a pending coinbase contains a "previous protocol state hash", which is updated whenever we add a
   coinbase. When we add a coinbase to a new stack, which contains a dummy state hash, we insert the previous state
   hash to that stack before a push, so that the state hashes in stacks are always computed from an existing state hash.

   The name "stack" here is a misnomer: see issue #3226
 *)

module Coinbase_data = struct
  type t =
    Public_key.Compressed.Stable.V1.t
    * Amount.Stable.V1.t
    * State_body_hash.Stable.V1.t
  [@@deriving bin_io, sexp]

  let of_coinbase (cb : Coinbase.t) : t =
    (cb.proposer, cb.amount, cb.state_body_hash)

  type var = Public_key.Compressed.var * Amount.var * State_body_hash.var

  type value = t [@@deriving bin_io, sexp]

  let length_in_triples =
    Public_key.Compressed.length_in_triples + Amount.length_in_triples
    + State_body_hash.length_in_triples

  let var_of_t ((public_key, amount, state_body_hash) : value) =
    ( Public_key.Compressed.var_of_t public_key
    , Amount.var_of_t amount
    , State_body_hash.var_of_t state_body_hash )

  let var_to_triples (public_key, amount, state_body_hash) =
    let%bind public_key = Public_key.Compressed.var_to_triples public_key in
    let amount = Amount.var_to_triples amount in
    let%map state_body_hash = State_body_hash.var_to_triples state_body_hash in
    public_key @ amount @ state_body_hash

  let fold ((public_key, amount, state_body_hash) : t) =
    let open Fold in
    Public_key.Compressed.fold public_key
    +> Amount.fold amount
    +> State_body_hash.fold state_body_hash

  let typ : (var, value) Typ.t =
    let spec =
      let open Data_spec in
      [Public_key.Compressed.typ; Amount.typ; State_body_hash.typ]
    in
    let of_hlist
          : 'public_key 'amount 'state_body_hash.    ( unit
                                                     ,    'public_key
                                                       -> 'amount
                                                       -> 'state_body_hash
                                                       -> unit )
                                                     H_list.t
            -> 'public_key * 'amount * 'state_body_hash =
      let open H_list in
      fun [public_key; amount; state_body_hash] ->
        (public_key, amount, state_body_hash)
    in
    let to_hlist (public_key, amount, state_body_hash) =
      H_list.[public_key; amount; state_body_hash]
    in
    Typ.of_hlistable spec ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
      ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

  let empty = (Public_key.Compressed.empty, Amount.zero, State_body_hash.dummy)

  let genesis = empty
end

module Stack_id : sig
  module Stable : sig
    module V1 : sig
      type t [@@deriving bin_io, sexp, to_yojson, compare, eq, version]
    end

    module Latest = V1
  end

  (* bin_io, version omitted *)
  type t = Stable.Latest.t [@@deriving sexp, compare, eq]

  val of_int : int -> t

  val to_int : t -> int

  val zero : t

  val incr_by_one : t -> t Or_error.t

  val to_string : t -> string

  val ( > ) : t -> t -> bool
end = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type t = int [@@deriving sexp, to_yojson, compare, eq, bin_io, version]
      end

      include T
      include Registration.Make_latest_version (T)
    end

    module Latest = V1

    module Module_decl = struct
      let name = "pending_coinbase_stack_id"

      type latest = Latest.t
    end

    module Registrar = Registration.Make (Module_decl)
    module Registered_V1 = Registrar.Register (V1)
  end

  type t = Stable.Latest.t [@@deriving sexp, compare]

  [%%define_locally
  Int.(( > ), to_string, zero, to_int, of_int, equal)]

  let incr_by_one t1 =
    let t2 = t1 + 1 in
    if t2 < t1 then Or_error.error_string "Stack_id overflow" else Ok t2
end

module type Data_hash_binable_intf = sig
  type t = private Field.t [@@deriving sexp, compare, eq, yojson, hash]

  module Stable : sig
    module V1 : sig
      type nonrec t = t
      [@@deriving bin_io, sexp, compare, eq, yojson, hash, version]
    end

    module Latest = V1
  end

  type var

  val var_of_t : t -> var

  val typ : (var, t) Typ.t

  val var_to_triples : var -> (Boolean.var Triple.t list, _) Tick.Checked.t

  val var_to_hash_packed : var -> Field.Var.t

  val length_in_triples : int

  val equal_var : var -> var -> (Boolean.var, _) Tick.Checked.t

  val fold : t -> bool Triple.t Fold.t

  val to_bytes : t -> string

  val to_bits : t -> bool list

  val gen : t Quickcheck.Generator.t
end

module Data_hash_binable = struct
  include Data_hash.Make_full_size ()
end

(* a coinbase stack has two components, data and a state_hash
   we create modules for each component
*)

module Coinbase_stack_data = struct
  include Data_hash_binable

  let push (h : t) cb =
    let coinbase = Coinbase_data.of_coinbase cb in
    Pedersen.digest_fold Hash_prefix.coinbase_stack_data
      Fold.(Coinbase_data.fold coinbase +> fold h)
    |> of_hash

  let empty =
    of_hash (Pedersen.(State.salt "CoinbaseStack") |> Pedersen.State.digest)

  let length_in_bits = List.length @@ to_bits empty

  module Checked = struct
    type t = var

    let push (t : t) (coinbase : Coinbase_data.var) =
      (*Prefix+Coinbase+Current-stack*)
      let init =
        Pedersen.Checked.Section.create
          ~acc:(`Value Hash_prefix.coinbase_stack_data.acc)
          ~support:
            (Interval_union.of_interval (0, Hash_prefix.length_in_triples))
      in
      let start = Hash_prefix.length_in_triples in
      let%bind section =
        let%bind bs = Coinbase_data.var_to_triples coinbase in
        Pedersen.Checked.Section.extend init bs ~start
      in
      let start = start + Coinbase_data.length_in_triples in
      let%bind with_t =
        let%bind bs = Data_hash_binable.var_to_triples t in
        Pedersen.Checked.Section.extend Pedersen.Checked.Section.empty bs
          ~start
      in
      let%map s = Pedersen.Checked.Section.disjoint_union_exn section with_t in
      let digest, _ =
        Pedersen.Checked.Section.to_initial_segment_digest_exn s
      in
      Data_hash_binable.var_of_hash_packed digest

    let if_ = if_
  end
end

module Coinbase_stack_state_hash = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type t = State_hash.Stable.V1.t
        [@@deriving
          bin_io, sexp, eq, compare, hash, yojson, version {unnumbered}]
      end

      include T
    end

    module Latest = V1
  end

  type t = Stable.Latest.t [@@deriving sexp, compare, yojson, hash]

  type var = State_hash.var

  let update_state_hash ~(state_hash : State_hash.t)
      ~(state_body_hash : State_body_hash.t) =
    (* this is the same computation for combining state hashes and state body hashes as
       `Protocol_state.hash_abstract', not available here because it would create
       a module dependency cycle
     *)
    Random_oracle.hash ~init:Hash_prefix.Random_oracle.protocol_state
      [|(state_hash :> Field.t); (state_body_hash :> Field.t)|]
    |> State_hash.of_hash

  [%%define_locally
  State_hash.
    ( fold
    , gen
    , of_hash
    , var_to_triples
    , length_in_triples
    , to_bits
    , raw_hash_bytes
    , equal_var
    , typ
    , if_
    , var_of_t )]

  let push t cb =
    let _, _, state_body_hash = Coinbase_data.of_coinbase cb in
    let state_hash = update_state_hash ~state_hash:t ~state_body_hash in
    Pedersen.digest_fold Hash_prefix.coinbase_stack_state_hash
      Fold.(State_hash.fold state_hash +> fold t)
    |> of_hash

  let empty = State_hash.dummy

  let length_in_bits = List.length @@ to_bits empty

  module Checked = struct
    type t = var

    (* same computation as Protocol_state.hash_checked *)
    let update_state_hash ~(state_hash : State_hash.var)
        ~(state_body_hash : State_body_hash.var) =
      make_checked (fun () ->
          Random_oracle.Checked.hash
            ~init:Hash_prefix.Random_oracle.protocol_state
            [| State_hash.var_to_hash_packed state_hash
             ; State_body_hash.var_to_hash_packed state_body_hash |]
          |> State_hash.var_of_hash_packed )

    let push (t : t) ((_, _, state_body_hash) : Coinbase_data.var) =
      let%bind state_hash = update_state_hash ~state_hash:t ~state_body_hash in
      let%bind update_triples = State_hash.(var_to_triples state_hash) in
      let%bind t_triples = State_hash.(var_to_triples t) in
      let%map digest =
        Pedersen.Checked.digest_triples
          ~init:Hash_prefix.coinbase_stack_state_hash
          (update_triples @ t_triples)
      in
      State_hash.var_of_hash_packed digest
  end
end

(* Pending coinbase hash *)
module Hash_builder = struct
  include Data_hash_binable

  let merge ~height (h1 : t) (h2 : t) =
    Random_oracle.hash
      ~init:Hash_prefix.Random_oracle.coinbase_merkle_tree.(height)
      [|(h1 :> field); (h2 :> field)|]
    |> of_hash

  let empty_hash =
    let open Tick.Pedersen in
    digest_fold (State.create ())
      (Fold.string_triples "Pending coinbases merkle tree")
    |> of_hash

  let of_digest = Fn.compose Fn.id of_hash
end

(* Sparse_ledger.Make is applied more than once in the code, so
   it can't make assumptions about the internal structure of its module
   arguments. Therefore, for modules with a bin_io type passed to the functor,
   that type cannot be in a version module hierarchy. We build the required
   modules for Hash and Stack.
 *)

module Make (Depth : sig
  val depth : int
end) =
struct
  include Depth

  (* Total number of stacks *)
  let max_coinbase_stack_count = Int.pow 2 depth

  module Stack = struct
    module Poly = struct
      module Stable = struct
        module V1 = struct
          module T = struct
            type ('data, 'state_hash) t = {data: 'data; state_hash: 'state_hash}
            [@@deriving bin_io, eq, yojson, hash, sexp, compare, version]
          end

          include T
        end

        module Latest = V1
      end

      type ('data, 'state_hash) t = ('data, 'state_hash) Stable.Latest.t =
        {data: 'data; state_hash: 'state_hash}
      [@@deriving yojson, hash, sexp, compare]
    end

    module Stable = struct
      module V1 = struct
        module T = struct
          type t =
            ( Coinbase_stack_data.Stable.V1.t
            , Coinbase_stack_state_hash.Stable.V1.t )
            Poly.Stable.V1.t
          [@@deriving bin_io, eq, yojson, hash, sexp, compare, version]
        end

        include T
        include Registration.Make_latest_version (T)

        let fold t =
          let open Fold in
          Coinbase_stack_data.fold t.Poly.data
          +> Coinbase_stack_state_hash.fold t.Poly.state_hash

        let data_hash (t : t) =
          Tick.Pedersen.digest_fold Hash_prefix.coinbase_stack (fold t)
          |> Hash_builder.of_digest
      end

      module Latest = V1

      module Module_decl = struct
        let name = "pending_coinbase_stack"

        type latest = Latest.t
      end

      module Registrar = Registration.Make (Module_decl)
      module Registered_V1 = Registrar.Register (V1)
    end

    (* bin_io, version omitted *)
    type t = Stable.Latest.t [@@deriving yojson, eq, compare, sexp, hash]

    [%%define_locally
    Stable.Latest.(fold, data_hash)]

    type var = (Coinbase_stack_data.var, Coinbase_stack_state_hash.var) Poly.t

    let var_of_t t =
      { Poly.data= Coinbase_stack_data.var_of_t t.Poly.data
      ; state_hash= Coinbase_stack_state_hash.var_of_t t.state_hash }

    let gen =
      let open Base_quickcheck.Generator.Let_syntax in
      let%bind data = Coinbase_stack_data.gen in
      let%map state_hash = Coinbase_stack_state_hash.gen in
      {Poly.data; state_hash}

    let to_hlist {Poly.data; state_hash} = H_list.[data; state_hash]

    let of_hlist :
           (unit, 'data -> 'state_hash -> unit) H_list.t
        -> ('data, 'state_hash) Poly.t =
     fun H_list.[data; state_hash] -> {data; state_hash}

    let data_spec =
      Snark_params.Tick.Data_spec.
        [Coinbase_stack_data.typ; Coinbase_stack_state_hash.typ]

    let typ : (var, t) Typ.t =
      Snark_params.Tick.Typ.of_hlistable data_spec ~var_to_hlist:to_hlist
        ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
        ~value_of_hlist:of_hlist

    let num_pad_bits =
      let len = List.length Coinbase_stack_data.(to_bits empty) in
      (3 - (len mod 3)) mod 3

    (* pad to match the triple representation *)
    let pad_bits = List.init num_pad_bits ~f:(fun _ -> false)

    let to_bits t =
      Coinbase_stack_data.to_bits t.Poly.data
      @ pad_bits
      @ Coinbase_stack_state_hash.to_bits t.Poly.state_hash

    let length_in_bits =
      Coinbase_stack_data.length_in_bits + num_pad_bits
      + Coinbase_stack_state_hash.length_in_bits

    let to_bytes t =
      Coinbase_stack_data.to_bytes t.Poly.data
      ^ Coinbase_stack_state_hash.raw_hash_bytes t.Poly.state_hash

    let equal_var var1 var2 =
      let open Tick.Checked.Let_syntax in
      let%bind b1 =
        Coinbase_stack_data.equal_var var1.Poly.data var2.Poly.data
      in
      let%bind b2 =
        Coinbase_stack_state_hash.equal_var var1.Poly.state_hash
          var2.Poly.state_hash
      in
      let open Tick0.Boolean in
      b1 && b2

    let var_to_triples var =
      let open Tick.Checked.Let_syntax in
      let%bind data = Coinbase_stack_data.var_to_triples var.Poly.data in
      let%map state_hash =
        Coinbase_stack_state_hash.var_to_triples var.Poly.state_hash
      in
      data @ state_hash

    let length_in_triples =
      Coinbase_stack_data.length_in_triples
      + Coinbase_stack_state_hash.length_in_triples

    (* Coda_base_util.bit_length_to_triple_length 596 *)
    (* TODO: express in terms of stack components *)

    let empty =
      { Poly.data= Coinbase_stack_data.empty
      ; state_hash= Coinbase_stack_state_hash.empty }

    let equal_data t1 t2 = Coinbase_stack_data.equal t1.Poly.data t2.Poly.data

    let equal_state_hash t1 t2 =
      State_hash.equal t1.Poly.state_hash t2.Poly.state_hash

    let push t (cb : Coinbase.t) =
      let data = Coinbase_stack_data.push t.Poly.data cb in
      let state_hash = Coinbase_stack_state_hash.push t.Poly.state_hash cb in
      {Poly.data; state_hash}

    let hash_var var =
      let%bind triples = var_to_triples var in
      Pedersen.Checked.digest_triples triples ~init:Hash_prefix.coinbase_stack

    let if_ (cond : Tick0.Boolean.var) ~(then_ : var) ~(else_ : var) :
        (var, 'a) Tick0.Checked.t =
      let%bind data =
        Coinbase_stack_data.Checked.if_ cond ~then_:then_.data
          ~else_:else_.data
      in
      let%map state_hash =
        Coinbase_stack_state_hash.if_ cond ~then_:then_.state_hash
          ~else_:else_.state_hash
      in
      {Poly.data; state_hash}

    module Checked = struct
      type t = var

      let push (t : t) (coinbase : Coinbase_data.var) : (t, 'a) Tick0.Checked.t
          =
        let%bind data = Coinbase_stack_data.Checked.push t.data coinbase in
        let%map state_hash =
          Coinbase_stack_state_hash.Checked.push t.state_hash coinbase
        in
        {Poly.data; state_hash}

      let empty = var_of_t empty

      let if_ = if_
    end
  end

  module Hash = struct
    module Stable = struct
      module V1 = struct
        module T = struct
          type t = Hash_builder.Stable.V1.t
          [@@deriving bin_io, eq, compare, sexp, version, yojson, hash]
        end

        include T
        include Registration.Make_latest_version (T)

        type var = Hash_builder.var

        let merge = Hash_builder.merge
      end

      module Latest = V1

      module Module_decl = struct
        let name = "pending_coinbase_hash"

        type latest = Latest.t
      end

      module Registrar = Registration.Make (Module_decl)
      module Registered_V1 = Registrar.Register (V1)
    end

    (* bin_io, version omitted *)
    type t = Stable.Latest.t [@@deriving eq, compare, sexp, yojson, hash]

    type var = Stable.Latest.var

    [%%define_locally
    Stable.Latest.(merge)]

    [%%define_locally
    Hash_builder.
      ( of_digest
      , empty_hash
      , gen
      , to_bits
      , to_bytes
      , fold
      , equal_var
      , length_in_triples
      , var_to_triples
      , var_of_t
      , var_of_hash_packed
      , var_to_hash_packed
      , typ )]
  end

  (* the arguments to Sparse_ledger.Make are all versioned; a particular choice of those
     versions yields a version of the result
   *)

  module V1_make =
    Sparse_ledger_lib.Sparse_ledger.Make (Hash.Stable.V1) (Stack_id.Stable.V1)
      (Stack.Stable.V1)

  module Merkle_tree = struct
    module Stable = struct
      module V1 = struct
        module T = struct
          type t = V1_make.Stable.V1.t
          [@@deriving bin_io, sexp, to_yojson, version {unnumbered}]
        end

        include T
      end

      module Latest = V1
    end

    module Latest_make = V1_make

    [%%define_locally
    Latest_make.
      ( of_hash
      , get_exn
      , path_exn
      , set_exn
      , find_index_exn
      , add_path
      , merkle_root )]
  end

  module Checked = struct
    type var = Hash.Stable.V1.var

    module Merkle_tree =
      Snarky.Merkle_tree.Checked
        (Tick)
        (struct
          type value = Field.t

          type var = Field.Var.t

          let typ = Field.typ

          let merge ~height h1 h2 =
            Tick.make_checked (fun () ->
                Random_oracle.Checked.hash
                  ~init:Hash_prefix.Random_oracle.coinbase_merkle_tree.(height)
                  [|h1; h2|] )

          let assert_equal h1 h2 = Field.Checked.Assert.equal h1 h2

          let if_ = Field.Checked.if_
        end)
        (struct
          include Stack

          type value = t [@@deriving sexp]

          let hash var = hash_var var
        end)

    module Path = Merkle_tree.Path

    type path = Path.value

    module Address = struct
      include Merkle_tree.Address

      let typ = typ ~depth
    end

    module Newest_stack_info = struct
      type t = Address.value * State_hash.t * bool

      type value = t

      type var = Address.var * State_hash.var * Boolean.var

      let typ : (var, value) Typ.t =
        Typ.tuple3 Address.typ State_hash.typ Boolean.typ
    end

    type _ Request.t +=
      | Coinbase_stack_path : Address.value -> path Request.t
      | Get_coinbase_stack : Address.value -> (Stack.t * path) Request.t
      | Set_coinbase_stack : Address.value * Stack.t -> unit Request.t
      | Find_index_of_newest_stack : Newest_stack_info.t Request.t
      | Find_index_of_oldest_stack : Address.value Request.t

    let reraise_merkle_requests (With {request; respond}) =
      match request with
      | Merkle_tree.Get_path addr ->
          respond (Delegate (Coinbase_stack_path addr))
      | Merkle_tree.Set (addr, stack) ->
          respond (Delegate (Set_coinbase_stack (addr, stack)))
      | Merkle_tree.Get_element addr ->
          respond (Delegate (Get_coinbase_stack addr))
      | _ ->
          unhandled

    let get t addr =
      handle
        (Merkle_tree.get_req ~depth (Hash.var_to_hash_packed t) addr)
        reraise_merkle_requests

    let%snarkydef add_coinbase t (pk, amount, state_body_hash) =
      let%bind addr, previous_state_hash, is_new_stack =
        request_witness Newest_stack_info.typ
          As_prover.(map (return ()) ~f:(fun _ -> Find_index_of_newest_stack))
      in
      let equal_to_zero x = Amount.(equal_var x (var_of_t zero)) in
      let chain if_ b ~then_ ~else_ =
        let%bind then_ = then_ and else_ = else_ in
        if_ b ~then_ ~else_
      in
      handle
        (Merkle_tree.modify_req ~depth (Hash.var_to_hash_packed t) addr
           ~f:(fun stack0 ->
             let%bind equal_prev =
               State_hash.equal_var previous_state_hash stack0.state_hash
             in
             let%bind valid_stack_hash =
               Boolean.(if_ is_new_stack ~then_:true_ ~else_:equal_prev)
             in
             let%bind () = Boolean.Assert.is_true valid_stack_hash in
             let%bind stack =
               Stack.Checked.(
                 if_ is_new_stack
                   ~then_:{stack0 with state_hash= previous_state_hash}
                   ~else_:stack0)
             in
             let total_coinbase_amount =
               Currency.Amount.var_of_t Coda_compile_config.coinbase
             in
             let%bind rem_amount =
               Currency.Amount.Checked.sub total_coinbase_amount amount
             in
             let%bind amount1_equal_to_zero = equal_to_zero amount in
             let%bind amount2_equal_to_zero = equal_to_zero rem_amount in
             (* TODO: Optimize here since we are pushing twice to the same stack *)
             let%bind stack_with_amount1 =
               Stack.Checked.push stack (pk, amount, state_body_hash)
             in
             let%bind stack_with_amount2 =
               Stack.Checked.push stack_with_amount1
                 (pk, rem_amount, state_body_hash)
             in
             chain Stack.if_ amount1_equal_to_zero ~then_:(return stack0)
               ~else_:
                 (Stack.if_ amount2_equal_to_zero ~then_:stack_with_amount1
                    ~else_:stack_with_amount2) ))
        reraise_merkle_requests
      >>| Hash.var_of_hash_packed

    let%snarkydef pop_coinbases t ~proof_emitted =
      let%bind addr =
        request_witness Address.typ
          As_prover.(map (return ()) ~f:(fun _ -> Find_index_of_oldest_stack))
      in
      let%bind prev, prev_path =
        request_witness
          Typ.(Stack.typ * Path.typ ~depth)
          As_prover.(
            map (read Address.typ addr) ~f:(fun a -> Get_coinbase_stack a))
      in
      let stack_hash = Stack.hash_var in
      let%bind prev_entry_hash = stack_hash prev in
      let%bind () =
        Merkle_tree.implied_root prev_entry_hash addr prev_path
        >>= Field.Checked.Assert.equal (Hash.var_to_hash_packed t)
      in
      let%bind next =
        Stack.if_ proof_emitted ~then_:Stack.Checked.empty ~else_:prev
      in
      let%bind next_entry_hash = stack_hash next in
      let%bind () =
        perform
          (let open As_prover in
          let open Let_syntax in
          let%map addr = read Address.typ addr
          and next = read Stack.typ next in
          Set_coinbase_stack (addr, next))
      in
      let%map new_root =
        Merkle_tree.implied_root next_entry_hash addr prev_path
      in
      (Hash.var_of_hash_packed new_root, prev)
  end

  module Poly = struct
    module Stable = struct
      module V1 = struct
        module T = struct
          type ('tree, 'stack_id, 'state_hash) t =
            { tree: 'tree
            ; pos_list: 'stack_id list
            ; new_pos: 'stack_id
            ; previous_state_hash: 'state_hash }
          [@@deriving bin_io, sexp, to_yojson, version]
        end

        include T
      end

      module Latest = V1
    end

    type ('tree, 'stack_id, 'state_hash) t =
          ('tree, 'stack_id, 'state_hash) Stable.Latest.t =
      { tree: 'tree
      ; pos_list: 'stack_id list
      ; new_pos: 'stack_id
      ; previous_state_hash: 'state_hash }
  end

  module Stable = struct
    module V1 = struct
      module T = struct
        type t =
          ( Merkle_tree.Stable.V1.t
          , Stack_id.Stable.V1.t
          , State_hash.Stable.V1.t )
          Poly.Stable.V1.t
        [@@deriving bin_io, sexp, to_yojson, version {unnumbered}]
      end

      include T
    end

    module Latest = V1
  end

  type t = Stable.Latest.t [@@deriving sexp, to_yojson]

  let init_hash = Stack.data_hash Stack.empty

  (* this calculation doesn't depend on any inputs *)
  let hash_on_level, root_hash =
    List.fold
      (List.init depth ~f:(fun i -> i + 1))
      ~init:([(0, init_hash)], init_hash)
      ~f:(fun (hashes, (cur_hash : Data_hash_binable.t)) height ->
        let (merged : Hash.t) =
          Hash.merge ~height:(height - 1) cur_hash cur_hash
        in
        ((height, merged) :: hashes, merged) )

  let create_exn' () =
    let rec create_path height path key =
      if height < 0 then path
      else
        let hash =
          Option.value_exn
            (List.Assoc.find ~equal:Int.equal hash_on_level height)
        in
        create_path (height - 1)
          ((if key mod 2 = 0 then `Left hash else `Right hash) :: path)
          (key / 2)
    in
    let rec make_tree t key =
      if Stack_id.( > ) key (Stack_id.of_int @@ (Int.pow 2 depth - 1)) then t
      else
        let path = create_path (depth - 1) [] (Stack_id.to_int key) in
        make_tree
          (Merkle_tree.add_path t path key Stack.empty)
          (Or_error.ok_exn (Stack_id.incr_by_one key))
    in
    { Poly.tree= make_tree (Merkle_tree.of_hash ~depth root_hash) Stack_id.zero
    ; pos_list= []
    ; new_pos= Stack_id.zero
    ; previous_state_hash= Coinbase_stack_state_hash.empty }

  [%%define_locally
  Or_error.(try_with)]

  let create () = try_with (fun () -> create_exn' ())

  let merkle_root (t : t) = Merkle_tree.merkle_root t.tree

  let get_stack (t : t) index =
    try_with (fun () -> Merkle_tree.get_exn t.tree index)

  let path (t : t) index =
    try_with (fun () -> Merkle_tree.path_exn t.tree index)

  let set_stack (t : t) index stack =
    try_with (fun () -> {t with tree= Merkle_tree.set_exn t.tree index stack})

  let find_index (t : t) key =
    try_with (fun () -> Merkle_tree.find_index_exn t.tree key)

  let incr_index (t : t) ~is_new_stack =
    let open Or_error.Let_syntax in
    if is_new_stack then
      let%map new_pos =
        if
          Stack_id.equal t.new_pos
            (Stack_id.of_int (max_coinbase_stack_count - 1))
        then Ok Stack_id.zero
        else Stack_id.incr_by_one t.new_pos
      in
      {t with pos_list= t.new_pos :: t.pos_list; new_pos}
    else Ok t

  let latest_stack_id (t : t) ~is_new_stack =
    if is_new_stack then Ok t.new_pos
    else
      match List.hd t.pos_list with
      | Some x ->
          Ok x
      | None ->
          Or_error.error_string "No Stack_id for the latest stack"

  let latest_stack (t : t) ~is_new_stack =
    let open Or_error.Let_syntax in
    let%bind key = latest_stack_id t ~is_new_stack in
    Or_error.try_with (fun () ->
        let index = Merkle_tree.find_index_exn t.tree key in
        let stack = Merkle_tree.get_exn t.tree index in
        (* special case: use previous state hash if new stack *)
        if is_new_stack then
          {Stack.Poly.data= stack.data; state_hash= t.previous_state_hash}
        else stack )

  let oldest_stack_id (t : t) = List.last t.pos_list

  let remove_oldest_stack_id t =
    match List.rev t with
    | [] ->
        Or_error.error_string "No coinbase stack-with-state-hash to pop"
    | x :: xs ->
        Ok (x, List.rev xs)

  let oldest_stack t =
    let open Or_error.Let_syntax in
    let key = Option.value ~default:Stack_id.zero (oldest_stack_id t) in
    let%bind index = find_index t key in
    get_stack t index

  let add_coinbase t ~coinbase ~is_new_stack =
    let open Or_error.Let_syntax in
    let%bind key = latest_stack_id t ~is_new_stack in
    let%bind stack_index = find_index t key in
    let%bind stack_before0 = get_stack t stack_index in
    let stack_before =
      if is_new_stack then
        (* special case: use previous state hash if new stack *)
        {Stack.Poly.data= stack_before0.data; state_hash= t.previous_state_hash}
      else stack_before0
    in
    let stack_after = Stack.push stack_before coinbase in
    let%bind t' = incr_index t ~is_new_stack in
    (* state hash in "after" stack becomes previous state hash at top level *)
    set_stack
      {t' with previous_state_hash= stack_after.state_hash}
      stack_index stack_after

  (* the stack here has a valid state hash already *)
  let update_coinbase_stack (t : t) stack ~is_new_stack =
    let open Or_error.Let_syntax in
    let%bind key = latest_stack_id t ~is_new_stack in
    let%bind stack_index = find_index t key in
    let%bind t' = incr_index t ~is_new_stack in
    set_stack
      {t' with previous_state_hash= stack.Stack.Poly.state_hash}
      stack_index stack

  let remove_coinbase_stack (t : t) =
    let open Or_error.Let_syntax in
    let%bind oldest_stack, remaining = remove_oldest_stack_id t.pos_list in
    let%bind stack_index = find_index t oldest_stack in
    let%bind stack = get_stack t stack_index in
    let%map t' = set_stack t stack_index Stack.empty in
    (stack, {t' with pos_list= remaining})

  let hash_extra ({pos_list; new_pos; _} : t) =
    let h = Digestif.SHA256.init () in
    let h =
      Digestif.SHA256.feed_string h
        (List.fold pos_list ~init:"" ~f:(fun s a -> s ^ Stack_id.to_string a))
    in
    let h = Digestif.SHA256.feed_string h (Stack_id.to_string new_pos) in
    Digestif.SHA256.(get h |> to_raw_string)

  let handler (t : t) ~is_new_stack =
    let pending_coinbase = ref t in
    let coinbase_stack_path_exn idx =
      List.map
        (path !pending_coinbase idx |> Or_error.ok_exn)
        ~f:(function `Left h -> h | `Right h -> h)
    in
    stage (fun (With {request; respond}) ->
        match request with
        | Checked.Coinbase_stack_path idx ->
            let path =
              (coinbase_stack_path_exn idx :> Pedersen.Digest.t list)
            in
            respond (Provide path)
        | Checked.Find_index_of_oldest_stack ->
            let stack_id =
              Option.value ~default:Stack_id.zero
                (oldest_stack_id !pending_coinbase)
            in
            let index =
              find_index !pending_coinbase stack_id |> Or_error.ok_exn
            in
            respond (Provide index)
        | Checked.Find_index_of_newest_stack ->
            let stack_id =
              match latest_stack_id !pending_coinbase ~is_new_stack with
              | Ok id ->
                  id
              | _ ->
                  Stack_id.zero
            in
            let index =
              find_index !pending_coinbase stack_id |> Or_error.ok_exn
            in
            let previous_state_hash = !pending_coinbase.previous_state_hash in
            respond @@ Provide (index, previous_state_hash, is_new_stack)
        | Checked.Get_coinbase_stack idx ->
            let elt = get_stack !pending_coinbase idx |> Or_error.ok_exn in
            let path =
              (coinbase_stack_path_exn idx :> Pedersen.Digest.t list)
            in
            respond (Provide (elt, path))
        | Checked.Set_coinbase_stack (idx, stack) ->
            pending_coinbase :=
              set_stack !pending_coinbase idx stack |> Or_error.ok_exn ;
            respond (Provide ())
        | _ ->
            unhandled )
end

module T = Make (struct
  let depth = Snark_params.pending_coinbase_depth
end)

include T

let%test_unit "add stack + remove stack = initial tree " =
  let pending_coinbases = ref (create () |> Or_error.ok_exn) in
  let coinbases_gen = Quickcheck.Generator.list_non_empty Coinbase.gen in
  Quickcheck.test coinbases_gen ~trials:50 ~f:(fun cbs ->
      Async.Thread_safe.block_on_async_exn (fun () ->
          let is_new_stack = ref true in
          let init = merkle_root !pending_coinbases in
          let after_adding =
            List.fold cbs ~init:!pending_coinbases ~f:(fun acc coinbase ->
                let t =
                  add_coinbase acc ~coinbase ~is_new_stack:!is_new_stack
                  |> Or_error.ok_exn
                in
                is_new_stack := false ;
                t )
          in
          let _, after_del =
            remove_coinbase_stack after_adding |> Or_error.ok_exn
          in
          pending_coinbases := after_del ;
          assert (Hash.equal (merkle_root after_del) init) ;
          Async.Deferred.return () ) )

module type Pending_coinbase_intf = sig
  type t

  val add_coinbase :
    t -> coinbase:Coinbase.t -> is_new_stack:bool -> t Or_error.t
end

let add_coinbase_with_zero_checks (type t)
    (module T : Pending_coinbase_intf with type t = t) (t : t) ~coinbase
    ~is_new_stack =
  if Amount.equal coinbase.Coinbase.amount Amount.zero then t
  else
    let max_coinbase_amount = Coda_compile_config.coinbase in
    let coinbase' =
      Coinbase.create
        ~amount:
          ( Amount.sub max_coinbase_amount coinbase.amount
          |> Option.value_exn ?here:None ?message:None ?error:None )
        ~proposer:coinbase.proposer ~fee_transfer:None
        ~state_body_hash:coinbase.state_body_hash
      |> Or_error.ok_exn
    in
    let interim_tree =
      T.add_coinbase t ~coinbase ~is_new_stack |> Or_error.ok_exn
    in
    if Amount.equal coinbase'.amount Amount.zero then interim_tree
    else
      T.add_coinbase interim_tree ~coinbase:coinbase' ~is_new_stack:false
      |> Or_error.ok_exn

let%test_unit "Checked_stack = Unchecked_stack" =
  let open Quickcheck in
  test ~trials:20 (Generator.tuple2 Stack.gen Coinbase.gen)
    ~f:(fun (base, cb) ->
      let coinbase_data = Coinbase_data.of_coinbase cb in
      let unchecked = Stack.push base cb in
      let checked =
        let comp =
          let open Snark_params.Tick in
          let cb_var = Coinbase_data.(var_of_t coinbase_data) in
          let%map res = Stack.Checked.push (Stack.var_of_t base) cb_var in
          As_prover.read Stack.typ res
        in
        let (), x = Or_error.ok_exn (run_and_check comp ()) in
        x
      in
      assert (Stack.equal unchecked checked) )

let%test_unit "Checked_tree = Unchecked_tree" =
  let open Quickcheck in
  let pending_coinbases = create () |> Or_error.ok_exn in
  test ~trials:20 Coinbase.gen ~f:(fun coinbase ->
      let coinbase_data = Coinbase_data.of_coinbase coinbase in
      let unchecked =
        add_coinbase_with_zero_checks
          (module T)
          pending_coinbases ~coinbase ~is_new_stack:true
      in
      (* inside the `open' below, Checked means something else, so define this function *)
      let f_add_coinbase = Checked.add_coinbase in
      let checked_merkle_root =
        let comp =
          let open Snark_params.Tick in
          let coinbase_var = Coinbase_data.(var_of_t coinbase_data) in
          let%map result =
            handle
              (f_add_coinbase
                 (Hash.var_of_t (merkle_root pending_coinbases))
                 coinbase_var)
              (unstage (handler pending_coinbases ~is_new_stack:true))
          in
          As_prover.read Hash.typ result
        in
        let (), x = Or_error.ok_exn (run_and_check comp ()) in
        x
      in
      assert (Hash.equal (merkle_root unchecked) checked_merkle_root) )

let%test_unit "Checked_tree = Unchecked_tree after pop" =
  let open Quickcheck in
  test ~trials:20 Coinbase.gen ~f:(fun coinbase ->
      let pending_coinbases = create () |> Or_error.ok_exn in
      let coinbase_data = Coinbase_data.of_coinbase coinbase in
      let unchecked =
        add_coinbase_with_zero_checks
          (module T)
          pending_coinbases ~coinbase ~is_new_stack:true
      in
      (* inside the `open' below, Checked means something else, so define these functions *)
      let f_add_coinbase = Checked.add_coinbase in
      let f_pop_coinbase = Checked.pop_coinbases in
      let checked_merkle_root =
        let comp =
          let open Snark_params.Tick in
          let coinbase_var = Coinbase_data.(var_of_t coinbase_data) in
          let%map result =
            handle
              (f_add_coinbase
                 (Hash.var_of_t (merkle_root pending_coinbases))
                 coinbase_var)
              (unstage (handler pending_coinbases ~is_new_stack:true))
          in
          As_prover.read Hash.typ result
        in
        let (), x = Or_error.ok_exn (run_and_check comp ()) in
        x
      in
      assert (Hash.equal (merkle_root unchecked) checked_merkle_root) ;
      let _, unchecked_after_pop =
        remove_coinbase_stack unchecked |> Or_error.ok_exn
      in
      let checked_merkle_root_after_pop =
        let comp =
          let open Snark_params.Tick in
          let%map current, _previous =
            handle
              (f_pop_coinbase ~proof_emitted:Boolean.true_
                 (Hash.var_of_t checked_merkle_root))
              (unstage (handler unchecked ~is_new_stack:false))
          in
          As_prover.read Hash.typ current
        in
        let (), x = Or_error.ok_exn (run_and_check comp ()) in
        x
      in
      assert (
        Hash.equal
          (merkle_root unchecked_after_pop)
          checked_merkle_root_after_pop ) )

let%test_unit "push and pop multiple stacks" =
  let open Quickcheck in
  let module Pending_coinbase = Make (struct
    let depth = 3
  end) in
  let t_of_coinbases t = function
    | [] ->
        let t' =
          Pending_coinbase.incr_index t ~is_new_stack:true |> Or_error.ok_exn
        in
        (Pending_coinbase.Stack.empty, t')
    | initial_coinbase :: coinbases ->
        let t' =
          Pending_coinbase.add_coinbase t ~coinbase:initial_coinbase
            ~is_new_stack:true
          |> Or_error.ok_exn
        in
        let updated =
          List.fold coinbases ~init:t'
            ~f:(fun pending_coinbases (coinbase : Coinbase.t) ->
              add_coinbase_with_zero_checks
                (module Pending_coinbase)
                pending_coinbases ~coinbase ~is_new_stack:false )
        in
        let new_stack =
          Or_error.ok_exn
          @@ Pending_coinbase.latest_stack updated ~is_new_stack:false
        in
        (new_stack, updated)
  in
  (* Create pending coinbase stacks from coinbase lists and add it to the pending coinbase merkle tree *)
  let add coinbase_lists pending_coinbases =
    List.fold ~init:([], pending_coinbases) coinbase_lists
      ~f:(fun (stacks, pc) coinbases ->
        let new_stack, pc = t_of_coinbases pc coinbases in
        (new_stack :: stacks, pc) )
  in
  (* remove the oldest stack and check if that's the expected one *)
  let remove_check t expected_stack =
    let popped_stack, updated_pending_coinbases =
      Pending_coinbase.remove_coinbase_stack t |> Or_error.ok_exn
    in
    assert (Pending_coinbase.Stack.equal_data popped_stack expected_stack) ;
    updated_pending_coinbases
  in
  let add_remove_check coinbase_lists =
    let pending_coinbases = Pending_coinbase.create_exn' () in
    let rec go coinbase_lists pc =
      if List.is_empty coinbase_lists then ()
      else
        let coinbase_lists' =
          List.take coinbase_lists Pending_coinbase.max_coinbase_stack_count
        in
        let added_stacks, pending_coinbases_updated = add coinbase_lists' pc in
        let pending_coinbases' =
          List.fold ~init:pending_coinbases_updated (List.rev added_stacks)
            ~f:(fun pc expected_stack -> remove_check pc expected_stack)
        in
        let remaining_lists =
          List.drop coinbase_lists Pending_coinbase.max_coinbase_stack_count
        in
        go remaining_lists pending_coinbases'
    in
    go coinbase_lists pending_coinbases
  in
  let coinbase_lists_gen = Quickcheck.Generator.(list (list Coinbase.gen)) in
  test ~trials:100 coinbase_lists_gen ~f:add_remove_check
