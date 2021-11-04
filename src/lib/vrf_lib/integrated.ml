module Make
    (Impl : Snarky_backendless.Snark_intf.S) (Scalar : sig
      type value

      type var
    end) (Group : sig
      open Impl

      type value

      type var

      val scale : value -> Scalar.value -> value

      module Checked : sig
        module Assert : sig
          val equal : var -> var -> (unit, _) Checked.t
        end

        val scale_random : var -> Scalar.var -> (var, _) Checked.t

        val scale_generator : Scalar.var -> (var, _) Checked.t
      end
    end) (Message : sig
      type value

      type var

      val hash_to_group :
           constraint_constants:Genesis_constants.Constraint_constants.t
        -> value
        -> Group.value

      module Checked : sig
        val hash_to_group : var -> (Group.var, _) Impl.Checked.t
      end
    end) (Output_hash : sig
      type value

      type var

      val hash :
           constraint_constants:Genesis_constants.Constraint_constants.t
        -> Message.value
        -> Group.value
        -> value

      module Checked : sig
        val hash : Message.var -> Group.var -> (var, _) Impl.Checked.t
      end
    end) : sig
  val eval :
       constraint_constants:Genesis_constants.Constraint_constants.t
    -> private_key:Scalar.value
    -> Message.value
    -> Output_hash.value

  module Checked : sig
    val eval :
         private_key:Scalar.var
      -> Message.var
      -> (Output_hash.var, _) Impl.Checked.t

    val eval_and_check_public_key :
         private_key:Scalar.var
      -> public_key:Group.var
      -> Message.var
      -> (Output_hash.var, _) Impl.Checked.t
  end
end = struct
  open Impl

  let eval ~constraint_constants ~private_key m =
    let h = Message.hash_to_group ~constraint_constants m in
    let u = Group.scale h private_key in
    Output_hash.hash ~constraint_constants m u

  module Checked = struct
    open Let_syntax

    let eval ~private_key m =
      let%bind h = Message.Checked.hash_to_group m in
      let%bind u =
        (* If [private_key] is not sampled honestly (i.e., at random),
           then the in-snark value of the VRF will not match the out of SNARK
           value. That's fine since this SNARK is run only by a block producer,
           so they may screw themselves over so to speak, but it will not cause
           SNARK workers to choke or anything like that.

           Also, it doesn't give any advantage in evaluating the VRF since they
           still only get one chance. *)
        Group.Checked.scale_random h private_key
      in
      Output_hash.Checked.hash m u

    let eval_and_check_public_key ~private_key ~public_key message =
      let%bind () =
        with_label __LOC__
          ( Group.Checked.scale_generator private_key
          >>= Group.Checked.Assert.equal public_key )
      in
      eval ~private_key message
  end
end
