open Core

module Context = struct
  type ('message, 'pk) t = { message : 'message; public_key : 'pk }
  [@@deriving sexp, hlist]
end

module Evaluation = struct
  module Discrete_log_equality = struct
    module Poly = struct
      [%%versioned
      module Stable = struct
        module V1 = struct
          type 'scalar t = { c : 'scalar; s : 'scalar } [@@deriving sexp]

          let to_latest = Fn.id
        end
      end]
    end
  end

  module Poly = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type ('group, 'dleq) t =
          { discrete_log_equality : 'dleq; scaled_message_hash : 'group }
        [@@deriving sexp]
      end
    end]
  end
end

module Make
    (Impl : Snarky_backendless.Snark_intf.S) (Scalar : sig
      type t [@@deriving equal, sexp]

      val random : unit -> t

      val add : t -> t -> t

      val mul : t -> t -> t
    end) (Group : sig
      type t [@@deriving sexp]

      val add : t -> t -> t

      val negate : t -> t

      val scale : t -> Scalar.t -> t

      val generator : t
    end) (Message : sig
      type value [@@deriving sexp]

      (* This hash function can be merely collision-resistant *)

      val hash_to_group : value -> Group.t
    end) (Output_hash : sig
      type t

      (* I believe this has to be a random oracle *)

      val hash : Message.value -> Group.t -> t
    end) (Hash : sig
      (* I believe this has to be a random oracle *)

      val hash_for_proof :
        Message.value -> Group.t -> Group.t -> Group.t -> Scalar.t
    end) : sig
  module Public_key : sig
    type t = Group.t
  end

  module Private_key : sig
    type t = Scalar.t
  end

  module Context : sig
    type t = (Message.value, Public_key.t) Context.t [@@deriving sexp]
  end

  module Evaluation : sig
    type t =
      ( Group.t
      , Scalar.t Evaluation.Discrete_log_equality.Poly.t )
      Evaluation.Poly.t
    [@@deriving sexp]

    val create : Private_key.t -> Message.value -> t

    val verified_output : t -> Context.t -> Output_hash.t option
  end
end = struct
  module Public_key = Group

  module Context = struct
    type t = (Message.value, Public_key.t) Context.t [@@deriving sexp]
  end

  module Private_key = Scalar

  module Evaluation = struct
    module Discrete_log_equality = struct
      type 'scalar t_ = 'scalar Evaluation.Discrete_log_equality.Poly.t =
        { c : 'scalar; s : 'scalar }
      [@@deriving sexp, hlist]

      type t = Scalar.t t_ [@@deriving sexp]
    end

    type ('group, 'dleq) t_ = ('group, 'dleq) Evaluation.Poly.t =
      { discrete_log_equality : 'dleq; scaled_message_hash : 'group }
    [@@deriving sexp]

    type t = (Group.t, Discrete_log_equality.t) t_ [@@deriving sexp]

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
        { c; s = Scalar.(add r (mul k c)) }
      in
      { discrete_log_equality
      ; scaled_message_hash = Group.scale message_hash k
      }

    let verified_output
        ({ scaled_message_hash; discrete_log_equality = { c; s } } : t)
        ({ message; public_key } : Context.t) =
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
      if dleq then Some (Output_hash.hash message scaled_message_hash) else None
  end
end

open Core

module Bigint_scalar
    (Impl : Snarky_backendless.Snark_intf.S) (M : sig
      val modulus : Bigint.t

      val random : unit -> Bigint.t
    end) =
struct
  let pack bs =
    let pack_char bs =
      Char.of_int_exn
        (List.foldi bs ~init:0 ~f:(fun i acc b ->
             if b then acc lor (1 lsl i) else acc))
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
        assert (equal (add x y) ((x + y) % modulus)))

  let mul x y = x * y % modulus

  let length_in_bits = Z.log2up (Bigint.to_zarith_bigint (modulus - one))

  let to_bits n = List.init length_in_bits ~f:(test_bit n)

  let of_bits bs =
    List.fold_left bs ~init:(zero, one) ~f:(fun (acc, pt) b ->
        ((if b then add acc pt else acc), add pt pt))
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
        List.init length_in_bits ~f:(Z.testbit (to_zarith_bigint n)))
      ~back:pack

  module Checked = struct
    let equal = Bitstring_checked.equal

    module Assert = struct
      let equal = Bitstring_checked.Assert.equal
    end
  end
end
