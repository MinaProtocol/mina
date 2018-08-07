open Core_kernel
open Snark_params
open Coda_numbers
module Pedersen = Tick.Pedersen

module Nonce = Nat.Make64 ()

module Header = struct
  module Stable = struct
    module V1 = struct
      type ('time, 'nonce) t_ = {time: 'time; nonce: 'nonce}
      [@@deriving bin_io, sexp, fields]

      type t = (Block_time.Stable.V1.t, Nonce.Stable.V1.t) t_
      [@@deriving bin_io, sexp]
    end
  end

  include Stable.V1

  let to_hlist {time; nonce} = H_list.[time; nonce]

  let of_hlist : (unit, 't -> 'n -> unit) H_list.t -> ('t, 'n) t_ =
    H_list.(fun [time; nonce] -> {time; nonce})

  let fold_bits {time; nonce} ~init ~f =
    let init = Block_time.Bits.fold time ~init ~f in
    let init = Nonce.Bits.fold nonce ~init ~f in
    init

  let data_spec = Tick.Data_spec.[Block_time.Unpacked.typ; Nonce.Unpacked.typ]

  type var = (Block_time.Unpacked.var, Nonce.Unpacked.var) t_

  type value = (Block_time.Unpacked.value, Nonce.Unpacked.value) t_

  let to_bits ({time; nonce}: t) =
    Block_time.Bits.to_bits time @ Nonce.Bits.to_bits nonce

  let var_to_bits {time; nonce} =
    Block_time.Unpacked.var_to_bits time @ Nonce.Unpacked.var_to_bits nonce

  let typ : (var, value) Tick.Typ.t =
    Tick.Typ.of_hlistable data_spec ~var_to_hlist:to_hlist
      ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist
end

module Body = struct
  module Stable = struct
    module V1 = struct
      type ('ledger_hash, 'ledger_builder_hash) t_ =
        { target_hash: 'ledger_hash
        ; ledger_builder_hash: 'ledger_builder_hash
        ; proof: Proof.Stable.V1.t option }
      [@@deriving bin_io, sexp]

      type t = (Ledger_hash.Stable.V1.t, Ledger_builder_hash.Stable.V1.t) t_
      [@@deriving bin_io, sexp]
    end
  end

  include Stable.V1

  let fold {target_hash; ledger_builder_hash; proof= _} =
    let open Util in
    Ledger_hash.fold target_hash
    +> Ledger_builder_hash.fold ledger_builder_hash

  (* For now, the var does not track of the proof. This is due to
   how the verifier gadget is currently structured and can be changed
   once the verifier is reimplemented in snarky *)
  type var = (Ledger_hash.var, Ledger_builder_hash.var) t_

  let typ : (var, t) Tick.Typ.t =
    let relevant_data_typ =
      Tick.Typ.(Ledger_hash.typ * Ledger_builder_hash.typ)
    in
    let open Tick.Typ in
    let store t =
      Store.map
        (relevant_data_typ.store (t.target_hash, t.ledger_builder_hash))
        ~f:(fun (target_hash, ledger_builder_hash) ->
          {t with target_hash; ledger_builder_hash} )
    in
    let read t =
      Read.map
        (relevant_data_typ.read (t.target_hash, t.ledger_builder_hash))
        ~f:(fun (target_hash, ledger_builder_hash) ->
          {t with target_hash; ledger_builder_hash} )
    in
    let alloc =
      Alloc.map relevant_data_typ.alloc ~f:
        (fun (target_hash, ledger_builder_hash) ->
          {target_hash; ledger_builder_hash; proof= None} )
    in
    let check t =
      relevant_data_typ.check (t.target_hash, t.ledger_builder_hash)
    in
    {store; read; alloc; check}

  let var_to_bits ({target_hash; ledger_builder_hash; proof= _}: var) :
      (Tick.Boolean.var list, _) Tick.Checked.t =
    let open Tick.Let_syntax in
    let%map target_hash = Ledger_hash.var_to_bits target_hash
    and ledger_builder_hash =
      Ledger_builder_hash.var_to_bits ledger_builder_hash
    in
    target_hash @ ledger_builder_hash
end

module Stable = struct
  module V1 = struct
    type ('header, 'body) t_ = {header: 'header; body: 'body}
    [@@deriving bin_io, sexp]

    type t = (Header.Stable.V1.t, Body.Stable.V1.t) t_
    [@@deriving bin_io, sexp]
  end
end

include Stable.V1

let fold_bits {header; body} ~init ~f =
  let init = Header.fold_bits header ~init ~f in
  let init = Body.fold body ~init ~f in
  init

let hash t =
  let s = Pedersen.State.create Pedersen.params in
  Pedersen.State.update_fold s (fold_bits t) |> Pedersen.State.digest

let to_hlist {header; body} = H_list.[header; body]

let of_hlist : (unit, 'h -> 'b -> unit) H_list.t -> ('h, 'b) t_ =
  H_list.(fun [header; body] -> {header; body})

type var = (Header.var, Body.var) t_

type value = (Header.value, Body.t) t_

let data_spec = Tick.Data_spec.[Header.typ; Body.typ]

let typ : (var, value) Tick.Typ.t =
  Tick.Typ.of_hlistable data_spec ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
    ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

let var_to_bits ({header; body}: var) =
  let open Tick.Let_syntax in
  let%map body_bits = Body.var_to_bits body in
  Header.var_to_bits header @ body_bits

module With_transactions = struct
  module Body = struct
    module Stable = struct
      module V1 = struct
        type t =
          { target_hash: Ledger_hash.Stable.V1.t
          ; ledger_builder_hash: Ledger_builder_hash.Stable.V1.t
          ; proof: Proof.Stable.V1.t option
          ; transactions: Transaction.Stable.V1.t list }
        [@@deriving bin_io, sexp]
      end
    end

    include Stable.V1

    let forget ({target_hash; ledger_builder_hash; proof; _}: t) : Body.t =
      {target_hash; ledger_builder_hash; proof}
  end

  module Stable = struct
    module V1 = struct
      type t = (Header.Stable.V1.t, Body.Stable.V1.t) Stable.V1.t_
      [@@deriving bin_io, sexp]
    end
  end

  type block = t

  include Stable.V1

  let forget (t: t) : block = {t with body= Body.forget t.body}

  let hash t = hash (forget t)
end
