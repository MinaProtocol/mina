open Core
open Curve_choice

module Tock_random_oracle =
  Random_oracle_make.Make
    (Tock_runner)
    (struct
      let alpha = Random_oracle_make.N13
    end)
    (Sponge_params.Tock)

module Tick_backend = struct
  module Full = Cycle.Mnt4

  module Bowe_gabizon = struct
    let bg_salt =
      lazy
        (Tock_random_oracle.salt (Hash_prefixes.bowe_gabizon_hash :> string))

    let bg_params =
      Group_map.Params.create
        (module Tock0.Field)
        ~a:Tock_backend.Inner_curve.Coefficients.a
        ~b:Tock_backend.Inner_curve.Coefficients.b

    include Snarky.Libsnark.Make_bowe_gabizon
              (Full)
              (Bowe_gabizon_hash.Make (struct
                module Field = Tock0.Field

                module Fqe = struct
                  type t = Full.Fqe.t

                  let to_list x =
                    let v = Full.Fqe.to_vector x in
                    List.init (Field.Vector.length v) ~f:(Field.Vector.get v)
                end

                module G1 = Full.G1
                module G2 = Full.G2

                let group_map =
                  Group_map.to_group (module Field) ~params:bg_params

                let hash xs =
                  Tock_random_oracle.hash ~init:(Lazy.force bg_salt) xs
              end))

    module Field = Full.Field
    module Bigint = Full.Bigint
    module Var = Full.Var
    module R1CS_constraint = Full.R1CS_constraint

    module R1CS_constraint_system = struct
      include Full.R1CS_constraint_system

      let finalize = swap_AB_if_beneficial
    end

    module Linear_combination = Full.Linear_combination

    let field_size = Full.field_size
  end

  include Bowe_gabizon

  module Inner_curve = struct
    include Cycle.Mnt6.G1

    let find_y x =
      let ( + ) = Field.add in
      let ( * ) = Field.mul in
      let y2 = (x * Field.square x) + (Coefficients.a * x) + Coefficients.b in
      if Field.is_square y2 then Some (Field.sqrt y2) else None

    let point_near_x x =
      let rec go x = function
        | Some y ->
            of_affine (x, y)
        | None ->
            let x' = Field.(add one x) in
            go x' (find_y x')
      in
      go x (find_y x)
  end

  module Inner_twisted_curve = Cycle.Mnt6.G2
end

module Tick0 = Snarky.Snark.Make (Tick_backend)
