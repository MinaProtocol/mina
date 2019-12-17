open Core_kernel
open Import
open Snarky
module Coda_base_util = Util
open Snark_params
open Snark_params.Tick
open Let_syntax
open Currency
open Fold_lib

(* A pending coinbase is basically a Merkle tree of "stacks", each of which contains two hashes. The first hash
   is computed from the components in the coinbase via a "push" operation. The second hash, a protocol
   state hash, is computed from the state *body* hash in the coinbase.
   The "add_coinbase" operation takes a coinbase, retrieves the latest stack, or creates a new one, and does
   a push.

   A pending coinbase also contains a stack id, used to determine the chronology of stacks, so we can know
   which is the oldest, and which is the newest stack.

   The name "stack" here is a misnomer: see issue #3226
 *)

module Coinbase_data = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        Public_key.Compressed.Stable.V1.t
        * Amount.Stable.V1.t
        * State_body_hash.Stable.V1.t
      [@@deriving sexp]

      let to_latest = Fn.id
    end
  end]

  type t = Stable.Latest.t

  let of_coinbase (cb : Coinbase.t) : t =
    (cb.proposer, cb.amount, cb.state_body_hash)

  type var = Public_key.Compressed.var * Amount.var * State_body_hash.var

  type value = Stable.Latest.t [@@deriving sexp]

  let var_of_t ((public_key, amount, state_body_hash) : value) =
    ( Public_key.Compressed.var_of_t public_key
    , Amount.var_of_t amount
    , State_body_hash.var_of_t state_body_hash )

  let to_input (pk, amount, state_body_hash) =
    let open Random_oracle.Input in
    List.reduce_exn ~f:append
      [ Public_key.Compressed.to_input pk
      ; bitstring (Amount.to_bits amount)
      ; State_body_hash.to_input state_body_hash ]

  module Checked = struct
    let _constant ((public_key, amount, state_body_hash) : value) =
      ( Public_key.Compressed.var_of_t public_key
      , Amount.var_of_t amount
      , State_body_hash.var_of_t state_body_hash )

    let to_input (public_key, amount, state_body_hash) =
      let open Random_oracle.Input in
      List.reduce_exn ~f:append
        [ Public_key.Compressed.Checked.to_input public_key
        ; bitstring
            (Bitstring_lib.Bitstring.Lsb_first.to_list
               (Amount.var_to_bits amount))
        ; State_body_hash.var_to_input state_body_hash ]
  end

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
      type t [@@deriving bin_io, sexp, to_yojson, compare, version]
    end

    module Latest = V1
  end

  (* bin_io, version omitted *)
  type t = Stable.Latest.t [@@deriving sexp, compare, eq, to_yojson]

  val of_int : int -> t

  val to_int : t -> int

  val zero : t

  val incr_by_one : t -> t Or_error.t

  val to_string : t -> string

  val ( > ) : t -> t -> bool
end = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = int [@@deriving sexp, to_yojson, compare]

      let to_latest = Fn.id
    end
  end]

  type t = Stable.Latest.t [@@deriving sexp, compare, to_yojson]

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

  val var_to_hash_packed : var -> Field.Var.t

  val equal_var : var -> var -> (Boolean.var, _) Tick.Checked.t

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
    let open Random_oracle in
    hash ~init:Hash_prefix.coinbase_stack
      (pack_input (Input.append (Coinbase_data.to_input coinbase) (to_input h)))
    |> of_hash

  let empty =
    of_hash (Pedersen.(State.salt "CoinbaseStack") |> Pedersen.State.digest)

  module Checked = struct
    type t = var

    let push (h : t) (cb : Coinbase_data.var) =
      let open Random_oracle.Checked in
      make_checked (fun () ->
          hash ~init:Hash_prefix.coinbase_stack
            (pack_input
               (Random_oracle.Input.append
                  (Coinbase_data.Checked.to_input cb)
                  (var_to_input h)))
          |> var_of_hash_packed )

    let if_ = if_
  end
end

module Stack_hash = struct
  include Data_hash_binable

  let dummy = of_hash Outside_pedersen_image.t
end

module Coinbase_stack_state = struct
  module Poly = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type 'stack_hash t = {init: 'stack_hash; curr: 'stack_hash}
        [@@deriving sexp, eq, compare, hash, yojson]
      end
    end]

    type 'stack_hash t = 'stack_hash Stable.Latest.t =
      {init: 'stack_hash; curr: 'stack_hash}
    [@@deriving sexp, eq, compare, hash, yojson]
  end

  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = Stack_hash.Stable.V1.t Poly.Stable.V1.t
      [@@deriving sexp, eq, compare, hash, yojson]

      let to_latest = Fn.id
    end
  end]

  type t = Stable.Latest.t [@@deriving sexp, compare, yojson, hash]

  type var = Stack_hash.var Poly.t

  let create ~init : t = {init; curr= init}

  let gen : t Quickcheck.Generator.t =
    let open Quickcheck.Generator.Let_syntax in
    let%map init, curr =
      Quickcheck.Generator.tuple2 Stack_hash.gen Stack_hash.gen
    in
    {Poly.init; curr}

  let to_input (t : t) =
    Random_oracle.Input.append
      (Stack_hash.to_input t.init)
      (Stack_hash.to_input t.curr)

  let var_to_input (t : var) =
    Random_oracle.Input.append
      (Stack_hash.var_to_input t.init)
      (Stack_hash.var_to_input t.curr)

  let var_of_t (t : t) =
    {Poly.init= Stack_hash.var_of_t t.init; curr= Stack_hash.var_of_t t.curr}

  let to_hlist {Poly.init; curr} = H_list.[init; curr]

  let of_hlist :
      (unit, 'state_hash -> 'state_hash -> unit) H_list.t -> 'state_hash Poly.t
      =
   fun H_list.[init; curr] -> {init; curr}

  let data_spec = Snark_params.Tick.Data_spec.[Stack_hash.typ; Stack_hash.typ]

  let typ : (var, t) Typ.t =
    Snark_params.Tick.Typ.of_hlistable data_spec ~var_to_hlist:to_hlist
      ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

  let to_bits (t : t) = Stack_hash.to_bits t.init @ Stack_hash.to_bits t.curr

  let to_bytes (t : t) =
    Stack_hash.to_bytes t.init ^ Stack_hash.to_bytes t.curr

  let equal_var (v1 : var) (v2 : var) =
    let open Tick.Checked.Let_syntax in
    let%bind b1 = Stack_hash.equal_var v1.init v2.init in
    let%bind b2 = Stack_hash.equal_var v1.curr v2.curr in
    Boolean.(b1 && b2)

  let if_ (cond : Tick0.Boolean.var) ~(then_ : var) ~(else_ : var) :
      (var, 'a) Tick0.Checked.t =
    let%bind init = Stack_hash.if_ cond ~then_:then_.init ~else_:else_.init in
    let%map curr = Stack_hash.if_ cond ~then_:then_.curr ~else_:else_.curr in
    {Poly.init; curr}

  (*[%%define_locally
  State_hash.
    (gen, of_hash, to_bits, raw_hash_bytes, equal_var, typ, if_, var_of_t)]*)

  let push (t : t) (state_body_hash : State_body_hash.t) : t =
    (* this is the same computation for combining state hashes and state body hashes as
       `Protocol_state.hash_abstract', not available here because it would create
       a module dependency cycle
     *)
    { t with
      curr=
        Random_oracle.hash ~init:Hash_prefix.protocol_state
          [|(t.curr :> Field.t); (state_body_hash :> Field.t)|]
        |> Stack_hash.of_hash }

  let empty : t = {Poly.init= Stack_hash.dummy; curr= Stack_hash.dummy}

  module Checked = struct
    type t = var

    let push (t : t) (state_body_hash : State_body_hash.var) =
      make_checked (fun () ->
          let curr =
            Random_oracle.Checked.hash ~init:Hash_prefix.protocol_state
              [| Stack_hash.var_to_hash_packed t.curr
               ; State_body_hash.var_to_hash_packed state_body_hash |]
            |> Stack_hash.var_of_hash_packed
          in
          {t with curr} )
  end
end

(* Pending coinbase hash *)
module Hash_builder = struct
  include Data_hash_binable

  let merge ~height (h1 : t) (h2 : t) =
    Random_oracle.hash
      ~init:Hash_prefix.coinbase_merkle_tree.(height)
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
    (*TODO: init and curr should be here and not in coimnbase_stack_state*)
    module Poly = struct
      [%%versioned
      module Stable = struct
        module V1 = struct
          type ('data_stack, 'state_stack) t =
            {data: 'data_stack; state: 'state_stack}
          [@@deriving eq, yojson, hash, sexp, compare]
        end
      end]

      type ('data_stack, 'state_stack) t =
            ('data_stack, 'state_stack) Stable.Latest.t =
        {data: 'data_stack; state: 'state_stack}
      [@@deriving yojson, hash, sexp, compare]
    end

    [%%versioned
    module Stable = struct
      module V1 = struct
        type t =
          ( Coinbase_stack_data.Stable.V1.t
          , Coinbase_stack_state.Stable.V1.t )
          Poly.Stable.V1.t
        [@@deriving eq, yojson, hash, sexp, compare]

        let to_latest = Fn.id
      end
    end]

    (* bin_io, version omitted *)
    type t = Stable.Latest.t [@@deriving yojson, eq, compare, sexp, hash]

    type var = (Coinbase_stack_data.var, Coinbase_stack_state.var) Poly.t

    let to_input ({data; state} : t) =
      Random_oracle.Input.append
        (Coinbase_stack_data.to_input data)
        (Coinbase_stack_state.to_input state)

    let data_hash t =
      Random_oracle.(
        hash ~init:Hash_prefix_states.coinbase_stack (pack_input (to_input t)))
      |> Hash_builder.of_digest

    let var_to_input ({data; state} : var) =
      Random_oracle.Input.append
        (Coinbase_stack_data.var_to_input data)
        (Coinbase_stack_state.var_to_input state)

    let hash_var (t : var) =
      make_checked (fun () ->
          Random_oracle.Checked.(
            hash ~init:Hash_prefix_states.coinbase_stack
              (pack_input (var_to_input t))) )

    let var_of_t t =
      { Poly.data= Coinbase_stack_data.var_of_t t.Poly.data
      ; state= Coinbase_stack_state.var_of_t t.state }

    let gen =
      let open Base_quickcheck.Generator.Let_syntax in
      let%bind data = Coinbase_stack_data.gen in
      let%map state = Coinbase_stack_state.gen in
      {Poly.data; state}

    let to_hlist {Poly.data; state} = H_list.[data; state]

    let of_hlist :
           (unit, 'data -> 'state_hash -> unit) H_list.t
        -> ('data, 'state_hash) Poly.t =
     fun H_list.[data; state] -> {data; state}

    let data_spec =
      Snark_params.Tick.Data_spec.
        [Coinbase_stack_data.typ; Coinbase_stack_state.typ]

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
      @ Coinbase_stack_state.to_bits t.Poly.state

    let to_bytes t =
      Coinbase_stack_data.to_bytes t.Poly.data
      ^ Coinbase_stack_state.to_bytes t.Poly.state

    (*raw_hash_bytes?*)

    let equal_var var1 var2 =
      let open Tick.Checked.Let_syntax in
      let%bind b1 =
        Coinbase_stack_data.equal_var var1.Poly.data var2.Poly.data
      in
      let%bind b2 =
        Coinbase_stack_state.equal_var var1.Poly.state var2.Poly.state
      in
      let open Tick0.Boolean in
      b1 && b2

    let empty =
      {Poly.data= Coinbase_stack_data.empty; state= Coinbase_stack_state.empty}

    let equal_data t1 t2 = Coinbase_stack_data.equal t1.Poly.data t2.Poly.data

    let equal_state_hash t1 t2 = State_hash.equal t1.Poly.state t2.Poly.state

    let push_coinbase t (cb : Coinbase.t) =
      let data = Coinbase_stack_data.push t.Poly.data cb in
      (*let state_hash = Coinbase_stack_state_hash.push t.Poly.state_hash cb in*)
      {t with data}

    let push_state (t : t) (state_body_hash : State_body_hash.t) =
      {t with state= Coinbase_stack_state.push t.state state_body_hash}

    let if_ (cond : Tick0.Boolean.var) ~(then_ : var) ~(else_ : var) :
        (var, 'a) Tick0.Checked.t =
      let%bind data =
        Coinbase_stack_data.Checked.if_ cond ~then_:then_.data
          ~else_:else_.data
      in
      let%map state =
        Coinbase_stack_state.if_ cond ~then_:then_.state ~else_:else_.state
      in
      {Poly.data; state}

    module Checked = struct
      type t = var

      let push_coinbase (t : t) (coinbase : Coinbase_data.var) :
          (t, 'a) Tick0.Checked.t =
        let%map data = Coinbase_stack_data.Checked.push t.data coinbase in
        (*let%map state_hash =
          Coinbase_stack_state_hash.Checked.push t.state_hash coinbase
        in*)
        {t with data}

      let push_state (t : t) (state_body_hash : State_body_hash.var) =
        let%map state =
          Coinbase_stack_state.Checked.push t.state state_body_hash
        in
        {t with state}

      let empty = var_of_t empty

      let if_ = if_
    end
  end

  module Hash = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t = Hash_builder.Stable.V1.t
        [@@deriving eq, compare, sexp, yojson, hash]

        type var = Hash_builder.var

        let to_latest = Fn.id

        let merge = Hash_builder.merge
      end
    end]

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
      , equal_var
      , var_of_t
      , var_of_hash_packed
      , var_to_hash_packed
      , typ )]
  end

  (* the arguments to Sparse_ledger.Make are all versioned; a particular choice of those
     versions yields a version of the result
   *)

  module Merkle_tree = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t =
          ( Hash.Stable.V1.t
          , Stack_id.Stable.V1.t
          , Stack.Stable.V1.t )
          Sparse_ledger_lib.Sparse_ledger.T.Stable.V1.t
        [@@deriving sexp, to_yojson]

        let to_latest = Fn.id
      end
    end]

    module M = Sparse_ledger_lib.Sparse_ledger.Make (Hash) (Stack_id) (Stack)

    [%%define_locally
    M.
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
                  ~init:Hash_prefix.coinbase_merkle_tree.(height)
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

    type _ Request.t +=
      | Coinbase_stack_path : Address.value -> path Request.t
      | Get_coinbase_stack : Address.value -> (Stack.t * path) Request.t
      | Set_coinbase_stack : Address.value * Stack.t -> unit Request.t
      | Find_index_of_newest_stack : Address.value Request.t
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
      (* Question: Do the transaction have the current protocol state? Which means that both the stacks should be updated with the curr (or previous) body hash without the coinbase?) 
    *)
      let%bind addr =
        request_witness Address.typ
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
               Stack.Checked.push stack0 (pk, amount, state_body_hash)
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
      (*when popping stack, if there are no new stacks then update the next stack with this stack (if it is empty) so that we don't lose that infomation while having it constrained. As opposed to storing the stack at the top level of pending coinbase and requesting for that information when adding a coinbase.*)
      (* This will cause two merkle updates one for deleting the current stack and the next updating the next stack with this deleted stack*)
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
    [%%versioned
    module Stable = struct
      module V1 = struct
        type ('tree, 'stack_id) t =
          {tree: 'tree; pos_list: 'stack_id list; new_pos: 'stack_id}
        [@@deriving sexp, to_yojson]
      end
    end]

    type ('tree, 'stack_id) t = ('tree, 'stack_id) Stable.Latest.t =
      {tree: 'tree; pos_list: 'stack_id list; new_pos: 'stack_id}
  end

  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = (Merkle_tree.Stable.V1.t, Stack_id.Stable.V1.t) Poly.Stable.V1.t
      [@@deriving sexp, to_yojson]

      let to_latest = Fn.id
    end
  end]

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
    ; new_pos= Stack_id.zero }

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
        Merkle_tree.get_exn t.tree index )

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
    let%bind stack_before = get_stack t stack_index in
    let stack_after = Stack.push stack_before coinbase in
    let%bind t' = incr_index t ~is_new_stack in
    (* state hash in "after" stack becomes previous state hash at top level *)
    set_stack t' stack_index stack_after

  let update_coinbase_stack (t : t) stack ~is_new_stack =
    let open Or_error.Let_syntax in
    let%bind key = latest_stack_id t ~is_new_stack in
    let%bind stack_index = find_index t key in
    let%bind t' = incr_index t ~is_new_stack in
    set_stack t' stack_index stack

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
            respond @@ Provide index
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
