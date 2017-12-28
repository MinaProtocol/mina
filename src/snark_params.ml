open Core_kernel

module Main_curve = Camlsnark.Backends.Mnt4
module Main = struct
  include Camlsnark.Snark.Make(Main_curve)

  module Hash_curve = struct
    let bit_length = failwith "TODO"

    include Camlsnark.Curves.Edwards.Basic.Make(Field)(struct
        let d = failwith "TODO"
        let cofactor = failwith "TODO"
        let generator = failwith "TODO"
      end)
  end
end

module Other_curve = Camlsnark.Backends.Mnt6
module Other = Camlsnark.Snark.Make(Other_curve)

