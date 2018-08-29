module Make
    (Impl : Snarky.Snark_intf.S) (Scalar : sig
        type var
    end) (Group : sig
      open Impl

      type var

      module Shifted : sig
        module type S =
          Snarky.Curves.Shifted_intf
          with type ('a, 'b) checked := ('a, 'b) Checked.t
           and type boolean_var := Boolean.var
           and type curve_var := var

        type 'a m = (module S with type t = 'a)
      end

      val scale :
           (module Shifted.S with type t = 'shifted)
        -> var
        -> Scalar.var
        -> init:'shifted
        -> ('shifted, _) Checked.t

      val scale_generator :
           (module Shifted.S with type t = 'shifted)
        -> Scalar.var
        -> init:'shifted
        -> ('shifted, _) Checked.t
    end) (Message : sig
      type var

      val hash_to_group : var -> (Group.var, _) Impl.Checked.t
    end) (Output_hash : sig
      type var

      val hash : Message.var -> Group.var -> (var, _) Impl.Checked.t
    end) : sig
  val eval :
       'shifted Group.Shifted.m
    -> private_key:Scalar.var
    -> Message.var
    -> (Output_hash.var, _) Impl.Checked.t

  val eval_and_check_public_key :
       'shifted Group.Shifted.m
    -> private_key:Scalar.var
    -> public_key:Group.var
    -> Message.var
    -> (Output_hash.var, _) Impl.Checked.t
end = struct
  open Impl
  open Let_syntax

  let eval (type shifted) ((module Shifted): shifted Group.Shifted.m)
      ~private_key m =
    let%bind h = Message.hash_to_group m in
    let%bind u =
      (* This use of unshift_nonzero is acceptable since if h^private_key = 0 then
         the prover had a bad private key *)
      Group.scale (module Shifted) h private_key ~init:Shifted.zero
      >>= Shifted.unshift_nonzero
    in
    Output_hash.hash m u

  let eval_and_check_public_key (type shifted)
      ((module Shifted): shifted Group.Shifted.m) ~private_key ~public_key
      message =
    let%bind () =
      let%bind public_key_shifted = Shifted.(add zero public_key) in
      Group.scale_generator (module Shifted) private_key ~init:Shifted.zero
      >>= Shifted.Assert.equal public_key_shifted
    in
    eval (module Shifted) ~private_key message
end
