module Context = struct
  type ('message, 'pk) t = {message: 'message; public_key: 'pk}
  [@@deriving sexp]
end

module Make
    (Impl : Snarky.Snark_intf.S) (Scalar : sig
        type t [@@deriving eq, sexp, bin_io]

        val random : unit -> t

        val add : t -> t -> t

        val mul : t -> t -> t

        type var

        val typ : (var, t) Impl.Typ.t

        module Checked : sig
          open Impl

          val to_bits : var -> Boolean.var Bitstring_lib.Bitstring.Lsb_first.t

          module Assert : sig
            val equal : var -> var -> (unit, _) Checked.t
          end
        end
    end) (Group : sig
      type t [@@deriving sexp, bin_io]

      val add : t -> t -> t

      val negate : t -> t

      val scale : t -> Scalar.t -> t

      val generator : t

      type var

      val typ : (var, t) Impl.Typ.t

      module Checked :
        Snarky.Curves.Weierstrass_checked_intf
        with module Impl := Impl
         and type t := t
         and type var := var
    end) (Message : sig
      open Impl

      type t [@@deriving sexp]

      type var

      val typ : (var, t) Typ.t

      (* This hash function can be merely collision-resistant *)

      val hash_to_group : t -> Group.t

      module Checked : sig
        val hash_to_group : var -> (Group.var, _) Checked.t
      end
    end) (Output_hash : sig
      type t

      type var

      (* I believe this has to be a random oracle *)

      val hash : Message.t -> Group.t -> t

      module Checked : sig
        val hash : Message.var -> Group.var -> (var, _) Impl.Checked.t
      end
    end) (Hash : sig
      (* I believe this has to be a random oracle *)

      val hash_for_proof :
        Message.t -> Group.t -> Group.t -> Group.t -> Scalar.t

      module Checked : sig
        val hash_for_proof :
             Message.var
          -> Group.var
          -> Group.var
          -> Group.var
          -> (Scalar.var, _) Impl.Checked.t
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
    type t = (Message.t, Public_key.t) Context.t [@@deriving sexp]

    type var = (Message.var, Public_key.var) Context.t

    val typ : (var, t) Impl.Typ.t
  end

  module Evaluation : sig
    type t [@@deriving sexp, bin_io]

    type var

    val typ : (var, t) Impl.Typ.t

    val create : Private_key.t -> Message.t -> t

    val verified_output : t -> Context.t -> Output_hash.t option

    module Checked : sig
      val verified_output :
           (module Group.Checked.Shifted.S with type t = 'shifted)
        -> var
        -> Context.var
        -> (Output_hash.var, _) Impl.Checked.t
    end
  end
end = struct
  module Public_key = Group

  module Context = struct
    type t = (Message.t, Public_key.t) Context.t [@@deriving sexp]

    type var = (Message.var, Public_key.var) Context.t

    let typ =
      let open Snarky.H_list in
      Impl.Typ.of_hlistable
        [Message.typ; Public_key.typ]
        ~var_to_hlist:(fun {Context.message; public_key} ->
          [message; public_key] )
        ~var_of_hlist:(fun [message; public_key] -> {message; public_key})
        ~value_to_hlist:(fun {Context.message; public_key} ->
          [message; public_key] )
        ~value_of_hlist:(fun [message; public_key] -> {message; public_key})
  end

  module Private_key = Scalar

  module Evaluation = struct
    module Discrete_log_equality = struct
      type 'scalar t_ = {c: 'scalar; s: 'scalar} [@@deriving sexp, bin_io]

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
      {discrete_log_equality: 'dleq; scaled_message_hash: 'group}
    [@@deriving sexp, bin_io]

    type t = (Group.t, Discrete_log_equality.t) t_ [@@deriving sexp, bin_io]

    type var = (Group.var, Discrete_log_equality.var) t_

    let typ : (var, t) Impl.Typ.t =
      let open Snarky.H_list in
      Impl.Typ.of_hlistable
        [Discrete_log_equality.typ; Group.typ]
        ~var_to_hlist:(fun {discrete_log_equality; scaled_message_hash} ->
          [discrete_log_equality; scaled_message_hash] )
        ~value_to_hlist:(fun {discrete_log_equality; scaled_message_hash} ->
          [discrete_log_equality; scaled_message_hash] )
        ~value_of_hlist:(fun [discrete_log_equality; scaled_message_hash] ->
          {discrete_log_equality; scaled_message_hash} )
        ~var_of_hlist:(fun [discrete_log_equality; scaled_message_hash] ->
          {discrete_log_equality; scaled_message_hash} )

    let create (k : Private_key.t) message : t =
      let public_key = Group.scale Group.generator k in
      let message_hash = Message.hash_to_group message in
      let discrete_log_equality : Discrete_log_equality.t =
        let r = Scalar.random () in
        let c =
          Hash.hash_for_proof message public_key
            Group.(scale generator r)
            Group.(scale message_hash r)
        in
        {c; s= Scalar.(add r (mul k c))}
      in
      {discrete_log_equality; scaled_message_hash= Group.scale message_hash k}

    let verified_output
        ({scaled_message_hash; discrete_log_equality= {c; s}} : t)
        ({message; public_key} : Context.t) =
      let g = Group.generator in
      let ( + ) = Group.add in
      let ( * ) s g = Group.scale g s in
      let message_hash = Message.hash_to_group message in
      let dleq =
        Scalar.equal c
          (Hash.hash_for_proof message public_key
             ((s * g) + (c * Group.negate public_key))
             ((s * message_hash) + (c * Group.negate scaled_message_hash)))
      in
      if dleq then Some (Output_hash.hash message scaled_message_hash)
      else None

    module Checked = struct
      let verified_output (type shifted)
          ((module Shifted) as shifted :
            (module Group.Checked.Shifted.S with type t = shifted))
          ({scaled_message_hash; discrete_log_equality= {c; s}} : var)
          ({message; public_key} : Context.var) =
        let open Impl.Let_syntax in
        let%bind () =
          let%bind a =
            (* s * g - c * public_key *)
            let%bind sg =
              Group.Checked.scale_known shifted Group.generator
                (Scalar.Checked.to_bits s) ~init:Shifted.zero
            in
            Group.Checked.(
              scale shifted (negate public_key) (Scalar.Checked.to_bits c)
                ~init:sg)
            >>= Shifted.unshift_nonzero
          and b =
            (* s * H(m) - c * scaled_message_hash *)
            let%bind sx =
              let%bind message_hash = Message.Checked.hash_to_group message in
              Group.Checked.scale shifted message_hash
                (Scalar.Checked.to_bits s) ~init:Shifted.zero
            in
            Group.Checked.(
              scale shifted
                (negate scaled_message_hash)
                (Scalar.Checked.to_bits c) ~init:sx)
            >>= Shifted.unshift_nonzero
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
    (Impl : Snarky.Snark_intf.S) (M : sig
        val modulus : Bigint.t

        val random : unit -> Bigint.t
    end) =
struct
  let pack bs =
    let pack_char bs =
      Char.of_int_exn
        (List.foldi bs ~init:0 ~f:(fun i acc b ->
             if b then acc lor (1 lsl i) else acc ))
    in
    String.of_char_list (List.map ~f:pack_char (List.chunks_of ~length:8 bs))
    |> Z.of_bits |> Bigint.of_zarith_bigint

  include Bigint
  include M

  let gen = gen_incl zero (modulus - one)

  let test_bit t i = shift_right t i land one = one

  let add x y =
    let z = x + y in
    if z < modulus then z else z - modulus

  let%test_unit "add is correct" =
    Quickcheck.test (Quickcheck.Generator.tuple2 gen gen) ~f:(fun (x, y) ->
        assert (equal (add x y) ((x + y) % modulus)) )

  let mul x y = x * y % modulus

  let length_in_bits = Z.log2up (Bigint.to_zarith_bigint (modulus - one))

  let to_bits n = List.init length_in_bits ~f:(test_bit n)

  let of_bits bs =
    List.fold_left bs ~init:(zero, one) ~f:(fun (acc, pt) b ->
        ((if b then add acc pt else acc), add pt pt) )
    |> fst

  let%test_unit "of_bits . to_bits = identity" =
    Quickcheck.test gen ~f:(fun x -> assert (equal x (of_bits (to_bits x))))

  open Impl

  type var = Boolean.var list

  let typ : (var, t) Typ.t =
    let open Typ in
    transport
      (list ~length:length_in_bits Boolean.typ)
      ~there:(fun n ->
        List.init length_in_bits ~f:(Z.testbit (to_zarith_bigint n)) )
      ~back:pack

  module Checked = struct
    let equal = Bitstring_checked.equal

    module Assert = struct
      let equal = Bitstring_checked.Assert.equal
    end
  end
end

let%test_module "vrf-test" =
  ( module struct
    (* Nothing in here is secure, it's just for the test *)
    module Impl = Snarky.Snark.Make (Snarky.Backends.Mnt4.GM)
    module Other_impl = Snarky.Snark.Make (Snarky.Backends.Mnt6.GM)
    module B = Bigint

    module Scalar = struct
      include Snarky.Libsnark.Mnt6.Field

      let of_bits = Other_impl.Field.project

      include (Other_impl.Field : Sexpable.S with type t := t)

      include Binable.Of_sexpable (Other_impl.Field)

      let length_in_bits = size_in_bits

      open Impl

      type var = Boolean.var list

      let typ =
        Typ.transport
          (Typ.list ~length:size_in_bits Boolean.typ)
          ~there:Other_impl.Field.unpack ~back:Other_impl.Field.project

      let gen : t Quickcheck.Generator.t =
        Quickcheck.Generator.map
          (B.gen_incl B.one B.(Other_impl.Field.size - one))
          ~f:(fun x -> Other_impl.Bigint.(to_field (of_bignum_bigint x)))

      module Checked = struct
        let to_bits xs = Bitstring_lib.Bitstring.Lsb_first.of_list xs

        module Assert = struct
          let equal a b = Bitstring_checked.Assert.equal a b
        end
      end
    end

    (*
    module Scalar =
      Bigint_scalar (Impl)
        (struct
          let modulus =
            Bigint.of_string
              "4252498232415687930110553454452223399041429939925660931491171303058234989338533"

          let random () = Bigint.random modulus
        end)

    module Curve =
      Snarky.Curves.Edwards.Make (Impl) (Scalar)
        (struct
          let d = Impl.Field.of_int 20

          let cofactor =
            Bigint.(of_int 8 * of_int 5 * of_int 7 * of_int 399699743)

          let order = Scalar.modulus

          let generator =
            let conv =
              Fn.compose
                Impl.Bigint.(Fn.compose to_field of_bignum_bigint)
                Bigint.of_string
            in
            ( conv
                "327139552581206216694048482879340715614392408122535065054918285794885302348678908604813232"
            , conv
                "269570906944652130755537879906638127626718348459103982395416666003851617088183934285066554"
            )
        end) *)

    module Curve = struct
      open Impl

      type var = Field.Checked.t * Field.Checked.t

      include Snarky.Libsnark.Mnt6.Group

      module Checked = struct
        include Snarky.Curves.Make_weierstrass_checked (Impl) (Scalar)
                  (struct
                    include Snarky.Libsnark.Mnt6.Group

                    let scale = scale_field
                  end)
                  (Snarky.Libsnark.Curves.Mnt6.G1.Coefficients)

        let add_known_unsafe t x = add_unsafe t (constant x)
      end

      let typ = Checked.typ
    end

    module Group = struct
      open Impl

      module T = struct
        type t = Curve.t

        include Sexpable.Of_sexpable (struct
                    type t = Field.t * Field.t [@@deriving sexp]
                  end)
                  (struct
                    type t = Curve.t

                    let to_sexpable = Curve.to_coords

                    let of_sexpable = Curve.of_coords
                  end)
      end

      include T
      include Binable.Of_sexpable (T)

      let equal = Curve.equal

      let zero = Curve.zero

      let add = Curve.add

      let negate = Curve.negate

      let scale = Curve.scale_field

      let generator = Curve.one

      type var = Curve.var

      let typ = Curve.typ

      let to_bits (t : t) =
        let x, y = Curve.to_coords t in
        List.hd_exn (Field.unpack y) :: Field.unpack x

      let gen =
        let open Quickcheck.Generator.Let_syntax in
        let%map s = Scalar.gen in
        scale generator s

      let%test_unit "inv works" =
        Quickcheck.test gen ~f:(fun x ->
            let res = add x (negate x) in
            if not (equal res zero) then
              failwithf
                !"inv failured, x = %{sexp:t}, x + inv x = %{sexp:t}, \
                  expected %{sexp:t}"
                x res zero () )

      let%test_unit "scaling associates" =
        let open Quickcheck in
        test ~trials:50 (Generator.tuple2 Scalar.gen Scalar.gen)
          ~f:(fun (a, b) ->
            assert (
              equal
                (scale generator (Scalar.mul a b))
                (scale (scale generator a) b) ) )

      module Checked = struct
        include Curve.Checked

        let to_bits ((x, y) : var) =
          let open Let_syntax in
          let%map x =
            Field.Checked.choose_preimage_var ~length:Field.size_in_bits x
          and y =
            Field.Checked.choose_preimage_var ~length:Field.size_in_bits y
          in
          List.hd_exn y :: x
      end
    end

    let params =
      Array.init (5 * Impl.Field.size_in_bits) ~f:(fun _ ->
          let t = Curve.random () in
          let tt = Curve.double t in
          (t, tt, Curve.add t tt, Curve.double tt) )

    module Pedersen =
      Snarky.Pedersen.Make (Impl) (Curve)
        (struct
          let params = params
        end)

    module Message = struct
      open Impl

      type t = Curve.t

      include Sexpable.Of_sexpable (struct
                  type t = Field.t * Field.t [@@deriving sexp]
                end)
                (struct
                  type t = Curve.t

                  let to_sexpable = Curve.to_coords

                  let of_sexpable = Curve.of_coords
                end)

      type var = Curve.var

      let typ = Curve.typ

      let hash_to_group x = x

      module Checked = struct
        let hash_to_group = Impl.Checked.return
      end
    end

    let rec bits_to_triples ~default = function
      | b0 :: b1 :: b2 :: bs -> (b0, b1, b2) :: bits_to_triples ~default bs
      | [] -> []
      | [b] -> [(b, default, default)]
      | [b1; b2] -> [(b1, b2, default)]

    let hash_bits bits =
      List.foldi ~init:Curve.zero (bits_to_triples ~default:false bits)
        ~f:(fun i acc triple ->
          Curve.add acc
            (Snarky.Pedersen.local_function ~negate:Curve.negate params.(i)
               triple) )
      |> Curve.to_coords |> fst

    let hash_bits_checked bits =
      let open Impl.Let_syntax in
      Pedersen.hash
        ~init:(0, `Value Curve.zero)
        (bits_to_triples bits ~default:Impl.Boolean.false_)
      >>| Pedersen.digest

    module Output_hash = struct
      type t = Impl.Field.t

      type var = Pedersen.Digest.var

      let hash message pt = hash_bits (Group.to_bits message @ Group.to_bits pt)

      module Checked = struct
        let hash message pt =
          let open Impl.Let_syntax in
          let%bind message = Group.Checked.to_bits message
          and pt = Group.Checked.to_bits pt in
          hash_bits_checked (message @ pt)
      end
    end

    module Hash = struct
      open Impl
      open Let_syntax

      let hash_for_proof m g1 g2 g3 =
        let x = hash_bits (List.concat_map ~f:Group.to_bits [m; g1; g2; g3]) in
        Scalar.of_bits (List.take (Field.unpack x) Scalar.length_in_bits)

      module Checked = struct
        let hash_for_proof m g1 g2 g3 =
          let%bind bs =
            Checked.List.map ~f:Group.Checked.to_bits [m; g1; g2; g3]
            >>| List.concat
          in
          hash_bits_checked bs >>= Pedersen.Digest.choose_preimage
          >>| fun xs ->
          List.take (xs :> Boolean.var list) Scalar.length_in_bits
      end
    end

    module Vrf = Make (Impl) (Scalar) (Group) (Message) (Output_hash) (Hash)

    let%test_unit "completeness" =
      let gen =
        let open Quickcheck.Generator.Let_syntax in
        let%map private_key = Scalar.gen and message = Group.gen in
        (private_key, Group.(scale generator private_key), message)
      in
      Quickcheck.test gen ~trials:50 ~f:(fun (priv, public_key, message) ->
          let eval = Vrf.Evaluation.create priv message in
          let ctx : Vrf.Context.t = {message; public_key} in
          if not (Option.is_some (Vrf.Evaluation.verified_output eval ctx))
          then
            failwithf
              !"%{sexp:Vrf.Context.t}, %{sexp:Vrf.Evaluation.t}"
              ctx eval () )
  end )
