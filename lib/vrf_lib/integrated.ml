module Make
    (Impl : Snarky.Snark_intf.S)
    (Scalar : sig
       type var
     end)
    (Group : sig
       type var

       val scale : var -> Scalar.var -> (var, _) Impl.Checked.t

       val scale_generator : Scalar.var -> (var, _) Impl.Checked.t

       module Assert : sig
         val equal : var -> var -> (unit, _) Impl.Checked.t
       end
     end)
    (Message : sig
       type var
       val hash_to_group : var -> (Group.var, _) Impl.Checked.t
     end)
    (Output_hash : sig
       type var
       val hash : Message.var -> Group.var -> (var, _) Impl.Checked.t
     end)
  : sig
    val eval : private_key:Scalar.var -> Message.var -> (Output_hash.var, _) Impl.Checked.t

    val eval_and_check_public_key
      : private_key:Scalar.var
      -> public_key:Group.var
      -> Message.var
      -> (Output_hash.var, _) Impl.Checked.t
  end = struct

  open Impl
  open Let_syntax

  let eval ~private_key m =
    let%bind h = Message.hash_to_group m in
    let%bind u = Group.scale h private_key in
    Output_hash.hash m u

  let eval_and_check_public_key ~private_key ~public_key message =
    let%bind () =
      Group.scale_generator private_key >>= Group.Assert.equal public_key
    in
    eval ~private_key message
end


