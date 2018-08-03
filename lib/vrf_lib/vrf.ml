module Make
    (Impl : Snarky.Snark_intf.S)
    (Scalar : sig
      type t
      [@@deriving eq, sexp, bin_io]

      val random : unit -> t

      val add : t -> t -> t

      val mul : t -> t -> t

      type var
      val typ : (var, t) Impl.Typ.t

      module Checked : sig
        open Impl
        module Assert : sig
          val equal : var -> var -> (unit, _) Checked.t
        end
      end
    end)
    (Group : sig
       type t [@@deriving sexp, bin_io]

      val add : t -> t -> t

      val inv : t -> t

      val scale : t -> Scalar.t -> t

      val generator : t

      type var
      val typ : (var, t) Impl.Typ.t

      module Checked : sig
        open Impl

        val add : var -> var -> (var, _) Checked.t

        val inv : var -> var

        val scale_known : t -> Scalar.var -> (var, _) Checked.t

        val scale : var -> Scalar.var -> (var, _) Checked.t

        val generator : var
      end
    end)
    (Message : sig
       open Impl
       type t
       type var
       val typ : (var, t) Typ.t

      (* This hash function can be merely collision-resistant *)
       val hash_to_group : t -> Group.t
       module Checked : sig
         val hash_to_group : var -> (Group.var, _) Checked.t
       end
     end)
    (Output_hash : sig
       type t
       type var
       val typ : (var, t) Impl.Typ.t

       (* I believe this has to be a random oracle *)
       val hash : Message.t -> Group.t -> t
       module Checked : sig
        val hash : Message.var -> Group.var -> (var, _) Impl.Checked.t
       end
     end)
    (Hash : sig
       (* I believe this has to be a random oracle *)
       val hash_for_proof : Message.t -> Group.t -> Group.t -> Group.t -> Scalar.t
       module Checked : sig
        val hash_for_proof : Message.var -> Group.var -> Group.var -> Group.var -> (Scalar.var, _) Impl.Checked.t
       end
     end) : sig
  module Public_key : sig
    type t = Group.t
    type var = Group.var
  end

  module Private_key : sig
    type t = Scalar.t
    type var = Scalar.var
  end

  module Context : sig
    type ('message, 'pk) t_ =
      { message : 'message
      ; public_key : 'pk
      }

    type t = (Message.t, Public_key.t) t_
    type var = (Message.var, Public_key.var) t_
    val typ : (var, t) Impl.Typ.t
  end

  module Evaluation : sig
    type t [@@deriving sexp, bin_io]
    type var
    val typ : (var, t) Impl.Typ.t

    val create : Private_key.t -> Message.t -> t

    val verified_output : t -> Context.t -> Output_hash.t option

    module Checked : sig
      val verified_output : var -> Context.var -> (Output_hash.var, _) Impl.Checked.t
    end
  end
end
 = struct
  module Public_key = Group

  module Context = struct
    type ('message, 'pk) t_ =
      { message : 'message
      ; public_key : 'pk
      }

    type t = (Message.t, Public_key.t) t_
    type var = (Message.var, Public_key.var) t_

    let typ =
      let open Snarky.H_list in
      Impl.Typ.of_hlistable [Message.typ; Public_key.typ]
        ~var_to_hlist:(fun {message; public_key} -> [message; public_key])
        ~var_of_hlist:(fun [message; public_key] -> {message; public_key})
        ~value_to_hlist:(fun {message; public_key} -> [message; public_key])
        ~value_of_hlist:(fun [message; public_key] -> {message; public_key})
  end

  module Private_key = Scalar

  module Evaluation = struct
    module Discrete_log_equality = struct
      type 'scalar t_ =
        { c : 'scalar
        ; s : 'scalar
        }
      [@@deriving sexp, bin_io]

      type t = Scalar.t t_ [@@deriving sexp, bin_io]
      type var = Scalar.var t_

      open Impl

      let typ : (var, t) Typ.t =
        let open Snarky.H_list in
          Typ.of_hlistable [Scalar.typ; Scalar.typ]
            ~var_to_hlist:(fun {c; s} -> [c; s])
            ~var_of_hlist:(fun [c; s] -> {c; s})
            ~value_to_hlist:(fun {c; s} -> [c; s])
            ~value_of_hlist:(fun [c; s] -> {c; s})
    end

    type ('group, 'dleq) t_ = 
      { discrete_log_equality : 'dleq
      ; scaled_message_hash : 'group
      }
    [@@deriving sexp, bin_io]

    type t = (Group.t, Discrete_log_equality.t) t_ [@@deriving sexp, bin_io]
    type var = (Group.var, Discrete_log_equality.var) t_

    let typ : (var, t) Impl.Typ.t =
      let open Snarky.H_list in
      Impl.Typ.of_hlistable [Discrete_log_equality.typ; Group.typ]
        ~var_to_hlist:(fun {discrete_log_equality; scaled_message_hash} -> [discrete_log_equality; scaled_message_hash])
        ~value_to_hlist:(fun {discrete_log_equality; scaled_message_hash} -> [discrete_log_equality; scaled_message_hash])
        ~value_of_hlist:(fun [discrete_log_equality; scaled_message_hash] -> {discrete_log_equality; scaled_message_hash})
        ~var_of_hlist:(fun [discrete_log_equality; scaled_message_hash] -> {discrete_log_equality; scaled_message_hash})

    let create (k : Private_key.t) message : t =
      let public_key = Group.scale Group.generator k in
      let g_message = Message.hash_to_group message in
      let discrete_log_equality : Discrete_log_equality.t =
        let r = Scalar.random () in
        let c =
          Hash.hash_for_proof
            message
            public_key
            Group.(scale generator r)
            Group.(scale g_message r)
        in
        { c
        ; s = Scalar.(add r (mul k c))
        }
      in
      { discrete_log_equality
      ; scaled_message_hash = Group.scale g_message k }
    ;;

    let verified_output ({ scaled_message_hash; discrete_log_equality={c;s} } : t) ({message; public_key} : Context.t) =
      let g = Group.generator in
      let ( + ) = Group.add in
      let ( * ) s g = Group.scale g s in
      let message_hash = Message.hash_to_group message in
      let dleq =
        Scalar.equal c
          (Hash.hash_for_proof message public_key
             ((s * g) + (c * (Group.inv public_key)))
             ((s * message_hash) + (c * (Group.inv scaled_message_hash))))
      in
      if dleq
      then Some (Output_hash.hash message scaled_message_hash)
      else None

    module Checked = struct
      let verified_output
            ({ scaled_message_hash; discrete_log_equality={c;s}} : var)
            ({ message; public_key } : Context.var)
        =
        let open Impl.Let_syntax in
        let%bind () =
          let%bind a =
            (* TODO: Can save one EC add here by passing sg as the initial accumulator
               to scale *)
            let%bind sg = Group.Checked.scale_known Group.generator s
            and neg_c_pk = Group.Checked.(scale (inv public_key) c)
            in
            Group.Checked.add sg neg_c_pk
          and b =
            let%bind sx =
              let%bind message_hash = Message.Checked.hash_to_group message in
              Group.Checked.scale message_hash s
            and neg_cy = Group.Checked.(scale (inv scaled_message_hash) c)
            in
            Group.Checked.add sx neg_cy
          in
          Hash.Checked.hash_for_proof message public_key a b
          >>= Scalar.Checked.Assert.equal c
        in
        (* TODO: This could just hash (message_hash, message_hash^k) instead
          if it were cheaper *)
        Output_hash.Checked.hash message scaled_message_hash
    end
  end
end

open Core

module Bigint_scalar
    (Impl : Snarky.Snark_intf.S)
    (M : sig val modulus : Bigint.t val random : unit -> Bigint.t end) = struct
  let pack bs =
    let pack_char bs =
      Char.of_int_exn
        (List.foldi bs ~init:0 ~f:(fun i acc b ->
              if b then acc lor (1 lsl i) else acc ))
    in
    String.of_char_list
      (List.map ~f:pack_char (List.chunks_of ~length:8 bs))
    |> Z.of_bits |> Bigint.of_zarith_bigint

  include Bigint
  include M

  let test_bit t i = (shift_right t i land one = one)

  let add = (+)

  let mul x y = (x * y) % modulus

  let length_in_bits = Z.log2up (Bigint.to_zarith_bigint (modulus - one))

  open Impl

  type var = Boolean.var list

  let typ : (var, t) Typ.t =
    let open Typ in
    transport (list ~length:length_in_bits Boolean.typ)
      ~there:(fun n ->
        List.init length_in_bits
          ~f:(Z.testbit (to_zarith_bigint n)))
      ~back:pack


  module Checked = struct
    let equal = Bitstring_checked.equal
    module Assert = struct
      let equal = Bitstring_checked.Assert.equal
    end
  end
end

let%test_module "vrf-test" =
  (module (struct
    module Impl = Snarky.Snark.Make(Snarky.Backends.Bn128)
    module Scalar = Bigint_scalar(Impl)(struct
        let modulus = Bigint.of_string "21888242871839275222246405745257275088519243197699903948773788967907889479904"
        let random () = Bigint.random modulus
      end)
    module Curve = Snarky.Curves.Edwards.Make(Impl)(Scalar)
        (struct
          let d = Impl.Field.of_int 17
          let cofactor = Bigint.of_int 7904
          let order = Scalar.modulus
          let generator =
            let conv = Fn.compose Impl.Bigint.(Fn.compose to_field of_bignum_bigint) Bigint.of_string in
            ( conv "20903020017843600640837024932004945828697936805232324317859541396751974241115"
            , conv "5928297205773450620326061200940642731539957901001312077389680166022129346450"
            )
        end)

    module Group = struct
      open Impl
      module T = struct
        type t = Field.t * Field.t
        [@@deriving sexp]
      end
      include T
      include Binable.Of_sexpable(T)

      let add = Curve.add
      let inv (x, y) = (x, Field.negate y)
      let scale = Curve.scale
      let generator = Curve.generator

      type var = Curve.var

      module Checked = struct
        let add = Curve.Checked.add
        let inv (x, y) = (x, Field.Checked.scale y Field.(negate one))
        let scale_known = Curve.Checked.scale_known
        let scale = Curve.Checked.scale
        let generator = Curve.Checked.generator
      end
    end

    module Pedersen = Snarky.Pedersen.Make(Impl)

    module Message = struct
      type t = Curve.t
      type var = Curve.var
      let typ = Curve.typ

      let hash_to_group x = x

      module Checked = struct
        let hash_to_group = Impl.Checked.return
      end
    end

  end))

