open Core_kernel

module Tick = Snark_params.Main

module Pedersen = Snark_params.Main.Pedersen

module Header = struct
  (* TODO: Is there some reason [target] should be in here? *)
  type ('hash, 'time, 'nonce) t_ =
    { previous_block_hash : 'hash
    ; time                : 'time
    ; nonce               : 'nonce
    }
  [@@deriving bin_io, fields]

  type t =
    (Pedersen.Digest.t, Block_time.t, Nonce.t) t_
  [@@deriving bin_io]

  let to_hlist { previous_block_hash; time; nonce } =
      H_list.([ previous_block_hash; time; nonce ])

  let of_hlist =
    let open H_list in
    fun [ previous_block_hash; time; nonce ] ->
      { previous_block_hash; time; nonce }

  let fold_bits { previous_block_hash; time; nonce } ~init ~f =
    let init = Pedersen.Digest.Bits.fold previous_block_hash ~init ~f in
    let init = Block_time.Bits.fold time ~init ~f in
    let init = Nonce.Bits.fold nonce ~init ~f in
    init

  module Snarkable
    (Hash : Tick.Snarkable.S)
    (Time : Tick.Snarkable.S)
    (Nonce : Tick.Snarkable.S)
  = struct
    open Tick

    type var = (Hash.var, Time.var, Nonce.var) t_
    type value = (Hash.value, Time.value, Nonce.value) t_

    let data_spec =
      Data_spec.(
        [ Hash.spec
        ; Time.spec
        ; Nonce.spec
        ])

    let spec : (var, value) Var_spec.t =
      Var_spec.of_hlistable data_spec
        ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
        ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist
  end

  module Packed = Snarkable(Pedersen.Digest.Packed)(Block_time.Packed)(Nonce.Packed)

  module Unpacked = struct
    include Snarkable(Pedersen.Digest.Unpacked)(Block_time.Unpacked)(Nonce.Unpacked)

    let to_bits ({ previous_block_hash; time; nonce } : value) =
      Pedersen.Digest.Unpacked.to_bits previous_block_hash
      @ Block_time.Unpacked.to_bits time
      @ Nonce.Unpacked.to_bits nonce
  end

  module Checked = struct
    let unpack ({ previous_block_hash; time; nonce } : Packed.var)
      =
      let open Tick.Let_syntax in
      let%map previous_block_hash = Pedersen.Digest.Checked.unpack previous_block_hash
      and time = Block_time.Checked.unpack time
      and nonce = Nonce.Checked.unpack nonce
      in
      { previous_block_hash; time; nonce }
    ;;

    let to_bits { previous_block_hash; time; nonce } =
      Pedersen.Digest.Checked.to_bits previous_block_hash
      @ Block_time.Checked.to_bits time
      @ Nonce.Checked.to_bits nonce
  end
end

module Body = struct
  type t = Int64.t
  [@@deriving bin_io]

  include Bits.Snarkable.Int64(Tick)

  module Bits = Bits.Int64
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

type t = (Header.t, Body.t) t_ [@@deriving bin_io]

let hash t =
  let s = Pedersen.State.create Pedersen.params in
  Pedersen.State.update_fold s (fold_bits t);
  Pedersen.State.digest s

let genesis : t =
  { header =
      { previous_block_hash = Pedersen.zero_hash
      ; nonce = Nonce.zero
      ; time = Block_time.of_time Time.epoch
      }
  ; body = Int64.zero
  }

let strongest (a : t) (b : t) : [ `First | `Second ] = failwith "TODO"

(* TODO: Come up with a cleaner way to do this. Maybe use a function instead of functor?
  Or maybe it's worth writing a deriving plugin.
*)
let to_hlist { header; body } = H_list.([ header; body ])
let of_hlist = H_list.(fun [ header; body ] -> { header; body })

module Snarkable(Header : Tick.Snarkable.S)(Body : Tick.Snarkable.S) = struct
  open Tick

  type var = (Header.var, Body.var) t_
  type value = (Header.value, Body.value) t_

  let data_spec = Data_spec.([ Header.spec; Body.spec ])

  let spec : (var, value) Var_spec.t =
    Var_spec.of_hlistable data_spec
      ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
      ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist
end

module Packed = Snarkable(Header.Packed)(Body.Packed)

module Unpacked = struct
  include Snarkable(Header.Unpacked)(Body.Unpacked)

  let to_bits ({ header; body } : value) =
    Header.Unpacked.to_bits header @ Body.Unpacked.to_bits body
end

module Checked = struct
  let unpack ({ header; body } : Packed.var) : (Unpacked.var, _) Tick.Checked.t =
    let open Tick.Let_syntax in
    let%map header = Header.Checked.unpack header
    and body = Body.Checked.unpack body
    in
    { header; body }

  let to_bits { header; body } =
    Header.Checked.to_bits header
    @ Body.Checked.to_bits body
end
