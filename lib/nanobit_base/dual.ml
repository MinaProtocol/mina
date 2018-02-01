type ('packed, 'unpacked) t =
  { packed   : 'packed
  ; unpacked : 'unpacked
  }

module Make
    (Impl : Camlsnark.Snark_intf.S)
    (Packed : sig
       type var
       type value
       val spec : (var, value) Impl.Var_spec.t
     end)
    (M : sig
       val unpack : Packed.var -> (Impl.Boolean.var list, _) Impl.Checked.t
     end) = struct
  open Impl
  open M

  type var = (Packed.var, Boolean.var list) t
  type value = Packed.value

  let spec =
    let store x =
      let open Var_spec.Store.Let_syntax in
      let%bind packed = Var_spec.store Packed.spec x in
      return packed
    in
    let

end
