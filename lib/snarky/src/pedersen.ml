open Core_kernel

module Make
    (Impl : Snark_intf.S)
    (Curve : sig
      type var = Impl.Cvar.t * Impl.Cvar.t
      type value
      val typ : (var, value) Impl.Typ.t
      val cond_add : value -> to_:var -> if_:Impl.Boolean.var -> (var, _) Impl.Checked.t
    end)
  : sig
    open Impl

    module Digest : sig
      module Unpacked : sig
        type var = Boolean.var list
        type value
        val typ : (var, value) Typ.t
      end

      type var = Cvar.t
      type value = Field.t
      val typ : (var, value) Typ.t

      val choose_preimage : var -> (Unpacked.var, _) Checked.t
    end

    val hash : params:Curve.value array -> init:(int * Curve.var) -> Boolean.var list -> (Curve.var, _) Checked.t
    val digest : Curve.var -> Digest.var
  end
=
struct
  open Impl

  let hash_length = Field.size_in_bits

  module Digest = struct
    module Unpacked = struct
      type var = Boolean.var list
      type value = bool list
      let typ : (var, value) Typ.t = Typ.list Boolean.typ ~length:hash_length
    end

    type var = Cvar.t
    type value = Field.t
    let typ = Typ.field

    let choose_preimage x =
      with_label "Pedersen.Digest.choose_preimage"
        (Checked.choose_preimage ~length:Field.size_in_bits x)
  end

  open Let_syntax

  let hash ~params ~init:(i0, init) bs0 =
    let n = Array.length params in
    let rec go acc i = function
      | [] -> return acc
      | b :: bs ->
        if i = n
        then
          failwithf "Pedersen.hash: Input length (%d) exceeded max (%d)"
            (List.length bs0) n ()
        else
          let%bind acc' = Curve.cond_add params.(i) ~to_:acc ~if_:b in
          go acc' (i + 1) bs
    in
    with_label "Pedersen.hash" (go init i0 bs0)
  ;;

  let digest (x, _) = x
end
