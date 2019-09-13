[%%import
"../../config.mlh"]

[%%if
curve_size = 298]

module Cycle = Snarky.Libsnark.Mnt298
module Snarkette_tick = Snarkette.Mnt6_80
module Snarkette_tock = Snarkette.Mnt4_80

[%%elif
curve_size = 753]

module Cycle = Snarky.Libsnark.Mnt753
module Snarkette_tick = Snarkette.Mnt6753
module Snarkette_tock = Snarkette.Mnt4753

[%%else]

[%%show
curve_size]

[%%error
"invalid value for \"curve_size\""]

[%%endif]

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
