(* functor.ml -- functor to produce Curve_size *)

[%%import
"/src/config.mlh"]

[%%if
curve_size = 298]

module type Cycle_S = sig
  module Mnt4 : module type of Snarky.Libsnark.Mnt4

  module Mnt6 : module type of Snarky.Libsnark.Mnt6
end

[%%elif
curve_size = 753]

module type Cycle_S = sig
  module Mnt4 : module type of Snarky.Libsnark.Mnt4753

  module Mnt6 : module type of Snarky.Libsnark.Mnt6753
end

[%%else]

[%%show
curve_size]

[%%error
"invalid value for \"curve_size\""]

[%%endif]

module Make (Cycle : Cycle_S) = struct
  module Tick_full = Cycle.Mnt4
  module Tock_full = Cycle.Mnt6

  module Tick_backend = struct
    module Full = Tick_full
    include Full.Default

    module Inner_curve = struct
      include Tock_full.G1

      let find_y x =
        let ( + ) = Field.add in
        let ( * ) = Field.mul in
        let y2 =
          (x * Field.square x) + (Coefficients.a * x) + Coefficients.b
        in
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

    module Inner_twisted_curve = Tock_full.G2
  end

  module Tick0 = Snarky.Snark.Make (Tick_backend)

  module Runners = struct
    module Tick =
      Snarky.Snark.Run.Make
        (Tick_backend)
        (struct
          type t = unit
        end)
  end
end
