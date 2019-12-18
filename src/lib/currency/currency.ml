open Core_kernel
module Tick = Snark_params.Tick
module Signed_poly = Signed_poly
include Functor.Make (Tick)

let currency_length = 64

module Fee = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = Unsigned_extended.UInt64.Stable.V1.t
      [@@deriving sexp, compare, hash, eq, yojson]

      let to_latest = Fn.id
    end
  end]

  module T =
    Make
      (Unsigned_extended.UInt64)
      (struct
        let length = currency_length
      end)

  include T
  include Codable.Make_of_int (T)
end

module Amount = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = Unsigned_extended.UInt64.Stable.V1.t
      [@@deriving sexp, compare, hash, eq, yojson]

      let to_latest = Fn.id
    end
  end]

  module T =
    Make
      (Unsigned_extended.UInt64)
      (struct
        let length = currency_length
      end)

  include (
    T :
      module type of T
      with type var = T.var
       and module Signed = T.Signed
       and module Checked := T.Checked )

  include Codable.Make_of_int (T)

  let of_fee (fee : Fee.t) : t = fee

  let to_fee (fee : t) : Fee.t = fee

  let add_fee (t : t) (fee : Fee.t) = add t (of_fee fee)

  module Checked = struct
    include T.Checked

    let of_fee (fee : Fee.var) : var = fee

    let to_fee (t : var) : Fee.var = t

    let add_fee (t : var) (fee : Fee.var) =
      Tick.Field.Var.add (pack_var t) (Fee.pack_var fee) |> unpack_var
  end
end

module Balance = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = Amount.Stable.V1.t [@@deriving sexp, compare, hash, yojson, eq]

      let to_latest = Fn.id
    end
  end]

  include (Amount : Basic with type t = Amount.t with type var = Amount.var)

  let to_amount = Fn.id

  let add_amount = Amount.add

  let sub_amount = Amount.sub

  let ( + ) = add_amount

  let ( - ) = sub_amount

  module Checked = struct
    let add_signed_amount = Amount.Checked.add_signed

    let add_amount = Amount.Checked.add

    let sub_amount = Amount.Checked.sub

    let ( + ) = add_amount

    let ( - ) = sub_amount
  end
end

let%test_module "sub_flagged module" =
  ( module struct
    open Snark_params.Tick

    module type Sub_flagged_S = sig
      type t

      type magnitude = t [@@deriving sexp, compare]

      type var = field Snarky.Cvar.t Snarky.Boolean.t list

      val zero : t

      val ( - ) : t -> t -> t option

      val typ : (var, t) Typ.t

      val gen : t Quickcheck.Generator.t

      module Checked : sig
        val sub_flagged :
          var -> var -> (var * [`Underflow of Boolean.var], 'a) Tick.Checked.t
      end
    end

    let run_test (module M : Sub_flagged_S) =
      let open M in
      let sub_flagged_unchecked (x, y) =
        if x < y then (zero, true) else (Option.value_exn (x - y), false)
      in
      let sub_flagged_checked =
        let f (x, y) =
          Snarky.Checked.map (M.Checked.sub_flagged x y)
            ~f:(fun (r, `Underflow u) -> (r, u))
        in
        Test_util.checked_to_unchecked (Typ.tuple2 typ typ)
          (Typ.tuple2 typ Boolean.typ)
          f
      in
      Quickcheck.test ~trials:100 (Quickcheck.Generator.tuple2 gen gen)
        ~f:(fun p ->
          let m, u = sub_flagged_unchecked p in
          let m_checked, u_checked = sub_flagged_checked p in
          assert (Bool.equal u u_checked) ;
          if not u then [%test_eq: M.magnitude] m m_checked )

    let%test_unit "fee sub_flagged" = run_test (module Fee)

    let%test_unit "amount sub_flagged" = run_test (module Amount)
  end )
