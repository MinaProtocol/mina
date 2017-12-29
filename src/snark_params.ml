open Core_kernel

module Main_curve = Camlsnark.Backends.Mnt4
module Main = struct
  include Camlsnark.Snark.Make(Main_curve)

  module Hash_curve = struct
    (* someday: Compute this from the number inside of ocaml *)
    let bit_length = 262

    include Camlsnark.Curves.Edwards.Basic.Make(Field)(struct
        (*
Curve params:
d = 20
cardinality = 475922286169261325753349249653048451545124878135421791758205297448378458996221426427165320
2^3 * 5 * 7 * 399699743 * 4252498232415687930110553454452223399041429939925660931491171303058234989338533 *)

        let d = Field.of_int 20
        let cofactor = 8 * 5 * 7 * 399699743 
        let generator = 
          let f s = Main_curve.Bigint.R.(to_field (of_decimal_string s)) in
          f "327139552581206216694048482879340715614392408122535065054918285794885302348678908604813232",
          f "269570906944652130755537879906638127626718348459103982395416666003851617088183934285066554"
      end)
  end
end

module Other_curve = Camlsnark.Backends.Mnt6
module Other = Camlsnark.Snark.Make(Other_curve)

