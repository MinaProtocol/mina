open Core_kernel
open Snark_params

module Pedersen = Tick.Pedersen

module Header = struct
  module Stable = struct
    module V1 = struct
      type ('hash, 'time, 'nonce) t_ =
        { previous_block_hash : 'hash
        ; time                : 'time
        ; nonce               : 'nonce
        }
      [@@deriving bin_io, fields]

      type t =
        (Pedersen.Digest.t, Block_time.Stable.V1.t, Nonce.Stable.V1.t) t_
      [@@deriving bin_io]
    end
  end

  include Stable.V1

  let to_hlist { previous_block_hash; time; nonce } =
      H_list.([ previous_block_hash; time; nonce ])

  let of_hlist : (unit, 'h -> 't -> 'n -> unit) H_list.t -> ('h, 't, 'n) t_ =
    let open H_list in
    fun [ previous_block_hash; time; nonce ] ->
      { previous_block_hash; time; nonce }

  let fold_bits { previous_block_hash; time; nonce } ~init ~f =
    let init = Pedersen.Digest.Bits.fold previous_block_hash ~init ~f in
    let init = Block_time.Bits.fold time ~init ~f in
    let init = Nonce.Bits.fold nonce ~init ~f in
    init

  let data_spec =
    Tick.Data_spec.(
      [ Pedersen.Digest.Unpacked.typ
      ; Block_time.Unpacked.typ
      ; Nonce.Unpacked.typ
      ])

  type var = (Pedersen.Digest.Unpacked.var, Block_time.Unpacked.var, Nonce.Unpacked.var) t_
  type value = (Pedersen.Digest.Unpacked.value, Block_time.Unpacked.value, Nonce.Unpacked.value) t_

  let to_bits ({ previous_block_hash; time; nonce } : t) =
    Pedersen.Digest.Bits.to_bits previous_block_hash
    @ Block_time.Bits.to_bits time
    @ Nonce.Bits.to_bits nonce

  let var_to_bits { previous_block_hash; time; nonce } =
    Pedersen.Digest.Unpacked.var_to_bits previous_block_hash
    @ Block_time.Unpacked.var_to_bits time
    @ Nonce.Unpacked.var_to_bits nonce

  let typ : (var, value) Tick.Typ.t =
    Tick.Typ.of_hlistable data_spec
      ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
      ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist
end

module Body = struct
  module Stable = struct
    module V1 = struct
      (* Logically this really should have the proof in it, but right now we
         just pass that off to libsnark's verifier gadget separately. In the
         future when we reimplement the verifier gadget for the groth snark,
         we should have the proof in here. *)
      type 'ledger_hash t_ =
        { target_ledger_hash : 'ledger_hash
        }
      [@@deriving bin_io, sexp]

      type t = Ledger_hash.Stable.V1.t t_ [@@deriving bin_io, sexp]
    end
  end

  include Stable.V1

  let bit_length = 64

  type var = Ledger_hash.var t_
end

type ('header, 'body) t_ =
  { header : 'header
  ; body   : 'body
  }
[@@deriving bin_io]

let fold_bits { header; body } ~init ~f =
  let init = Header.fold_bits header ~init ~f in
  let init = Body.Bits.fold body ~init ~f in
  init
;;

module Stable = struct
  module V1 = struct
    type t = (Header.Stable.V1.t, Body.Stable.V1.t) t_ [@@deriving bin_io]
  end
end

include Stable.V1

let hash t =
  let s = Pedersen.State.create Pedersen.params in
  Pedersen.State.update_fold s (fold_bits t)
  |> Pedersen.State.digest

let genesis : t =
  let time =
    Time.of_date_ofday ~zone:Time.Zone.utc (Date.create_exn ~y:2018 ~m:Month.Feb ~d:1)
      Time.Ofday.start_of_day
    |> Block_time.of_time
  in
  { header =
      { previous_block_hash = Pedersen.zero_hash
      ; nonce = Nonce.zero
      ; time
      }
  ; body = Int64.one
  }

(* TODO: Come up with a cleaner way to do this. Maybe use a function instead of functor?
  Or maybe it's worth writing a deriving plugin.
*)
let to_hlist { header; body } = H_list.([ header; body ])
let of_hlist : (unit, 'h -> 'b -> unit) H_list.t -> ('h, 'b) t_ =
  H_list.(fun [ header; body ] -> { header; body })

type var = (Header.var, Body.Unpacked.var) t_
type value = (Header.value, Body.Unpacked.value) t_

let data_spec = Tick.Data_spec.([ Header.typ; Body.Unpacked.typ ])

let typ : (var, value) Tick.Typ.t =
  Tick.Typ.of_hlistable data_spec
    ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
    ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

let to_bits ({ header; body } : value) =
  Header.to_bits header @ Body.Bits.to_bits body

let var_to_bits { header; body } =
  Header.var_to_bits header
  @ Body.Unpacked.var_to_bits body
