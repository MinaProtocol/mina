[%%import
"../../../config.mlh"]

[%%if
curve_size = 298]

module Cycle = Snarky.Libsnark.Mnt298

[%%elif
curve_size = 753]

module Cycle = Snarky.Libsnark.Mnt753

[%%else]

[%%show
curve_size]

[%%error
"invalid value for \"curve_size\""]

[%%endif]

module Tick_backend = struct
  module Full = Cycle.Mnt4
  include Full.GM

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
            of_affine_coordinates (x, y)
        | None ->
            let x' = Field.(add one x) in
            go x' (find_y x')
      in
      go x (find_y x)
  end

  module Inner_twisted_curve = Cycle.Mnt6.G2
end

module Tick0 = Snarky.Snark.Make (Tick_backend)
