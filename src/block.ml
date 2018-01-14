open Core_kernel

module Pedersen = Pedersen.Main

module Header = struct
  (* TODO: Is there some reason [target] should be in here? *)
  type ('hash, 'time, 'nonce, 'strength) t_ =
    { previous_block_hash : 'hash
    ; time                : 'time
    ; nonce               : 'nonce
    ; strength            : 'strength
    }
  [@@deriving bin_io, fields]

  type t =
    (Pedersen.Digest.t, Block_time.t, Nonce.t, Strength.t) t_
  [@@deriving bin_io]

  let to_hlist { previous_block_hash; time; nonce; strength } =
      H_list.([ previous_block_hash; time; nonce; strength ])

  let of_hlist =
    let open H_list in
    fun [ previous_block_hash; time; nonce; strength ] ->
      { previous_block_hash; time; nonce; strength }

  let fold_bits { previous_block_hash; time; nonce; strength } ~init ~f =
    let init = Pedersen.Digest.Bits.fold previous_block_hash ~init ~f in
    let init = Block_time.Bits.fold time ~init ~f in
    let init = Nonce.Bits.fold nonce ~init ~f in
    let init = Strength.Bits.fold strength ~init ~f in
    init
end

module Body = struct
  type t = Int64.t
  [@@deriving bin_io]

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
      ; strength = Strength.zero
      ; nonce = Nonce.zero
      ; time = Block_time.of_time Time.epoch
      }
  ; body = Int64.zero
  }

let strongest (a : t) (b : t) : [ `First | `Second ] = failwith "TODO"

(* TODO: Come up with a cleaner way to do this. Maybe use a function instead of functor?
  Or maybe it's worth writing a deriving plugin.
*)
module Snarkable
    (Impl : Snark_intf.S)
    (Hash : Impl.Snarkable.Bits.S)
    (Time : Impl.Snarkable.Bits.S)
    (Nonce : Impl.Snarkable.Bits.S)
    (Strength : Impl.Snarkable.Bits.S)
= struct
  open Impl

  module Header = struct
    open Header

    module Make
      (Hash : Snarkable.S)
      (Time : Snarkable.S)
      (Nonce : Snarkable.S)
      (Strength : Snarkable.S)
    = struct
      type var = (Hash.var, Time.var, Nonce.var, Strength.var) t_
      type value = (Hash.value, Time.value, Nonce.value, Strength.value) t_

      let data_spec =
        Data_spec.(
          [ Hash.spec
          ; Time.spec
          ; Nonce.spec
          ; Strength.spec
          ])

      let spec : (var, value) Var_spec.t =
        Var_spec.of_hlistable data_spec
          ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
          ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist
    end

    module Packed = Make(Hash.Packed)(Time.Packed)(Nonce.Packed)(Strength.Packed)
    module Unpacked = struct
      include Make(Hash.Unpacked)(Time.Unpacked)(Nonce.Unpacked)(Strength.Unpacked)

      let to_bits { previous_block_hash; time; nonce; strength } =
        previous_block_hash @ time @  nonce @ strength
    end

    module Checked = struct
      let unpack
            { previous_block_hash; time; nonce; strength }
        =
        let open Let_syntax in
        let%map previous_block_hash = Hash.Checked.unpack previous_block_hash
        and time = Time.Checked.unpack time
        and nonce = Nonce.Checked.unpack nonce
        and strength = Strength.Checked.unpack strength
        in
        { previous_block_hash; time; nonce; strength }
      ;;
    end

  end

  module Body = Bits.Snarkable.Int64(Impl)

  let to_hlist { header; body } = H_list.([ header; body ])
  let of_hlist = H_list.(fun [ header; body ] -> { header; body })

  module Make(Header : Snarkable.S)(Body : Snarkable.S) = struct
    type var = (Header.var, Body.var) t_
    type value = (Header.value, Body.value) t_

    let data_spec = Data_spec.([ Header.spec; Body.spec ])

    let spec : (var, value) Var_spec.t =
      Var_spec.of_hlistable data_spec
        ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
        ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist
  end

  module Packed = Make(Header.Packed)(Body.Packed)
  module Unpacked = struct
    include Make(Header.Unpacked)(Body.Unpacked)

    let to_bits { header; body } =
      Header.Unpacked.to_bits header @ body
  end

  module Checked = struct
    let unpack { header; body } =
      let open Let_syntax in
      let%map header = Header.Checked.unpack header
      and body = Body.Checked.unpack body
      in
      { header; body }
  end
end
