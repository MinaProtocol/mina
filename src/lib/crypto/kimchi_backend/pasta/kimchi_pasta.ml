module Basic = Kimchi_pasta_basic

module Pallas_based_plonk = struct
  module Field = Pallas_based_plonk.Field
  module Curve = Pallas_based_plonk.Curve
  module Bigint = Pallas_based_plonk.Bigint

  let field_size = Pallas_based_plonk.field_size

  module Verification_key = Pallas_based_plonk.Verification_key
  module Rounds_vector = Pallas_based_plonk.Rounds_vector
  module Rounds = Pallas_based_plonk.Rounds
  module Keypair = Pallas_based_plonk.Keypair
  module Proof = Pallas_based_plonk.Proof
  module Proving_key = Pallas_based_plonk.Proving_key
  module Oracles = Pallas_based_plonk.Oracles

  (* stuff we get from bindings *)
  module Cvar = struct
    include Snarky_bindings.Fq.Cvar

    module Unsafe = struct
      let of_index = of_index_unsafe
    end

    let eval _ _ = failwith "TODO"

    let ( + ) = add

    let ( - ) = sub

    let ( * ) c x = scale x c
  end

  module R1CS_constraint_system = struct
    include Snarky_bindings.Fq.Constraint_system

    (* TODO: not really elegant, might want to just change the type to bytes and use what we're being given instead of converting to md5 *)
    let digest sys =
      let bytes = digest sys in
      Core_kernel.Md5.digest_bytes bytes
  end

  module Run_state = struct
    include Snarky_bindings.Fq.State

    include
      Kimchi_backend_common.Constraints.Make (Field) (Cvar)
        (struct
          type nonrec t = t
        end)
  end
end

module Vesta_based_plonk = struct
  module Field = Vesta_based_plonk.Field
  module Curve = Vesta_based_plonk.Curve
  module Bigint = Vesta_based_plonk.Bigint

  let field_size = Vesta_based_plonk.field_size

  module Verification_key = Vesta_based_plonk.Verification_key
  module Rounds_vector = Vesta_based_plonk.Rounds_vector
  module Rounds = Vesta_based_plonk.Rounds
  module Keypair = Vesta_based_plonk.Keypair
  module Proof = Vesta_based_plonk.Proof
  module Proving_key = Vesta_based_plonk.Proving_key
  module Oracles = Vesta_based_plonk.Oracles

  (* stuff we get from bindings *)
  module Cvar = struct
    include Snarky_bindings.Fp.Cvar

    module Unsafe = struct
      let of_index = of_index_unsafe
    end

    let eval _ _ = failwith "TODO"

    let ( + ) = add

    let ( - ) = sub

    let ( * ) c x = scale x c
  end

  module Run_state = Snarky_bindings.Fp.State

  module R1CS_constraint_system = struct
    include Snarky_bindings.Fp.Constraint_system

    (* TODO: not really elegant, might want to just change the type to bytes and use what we're being given instead of converting to md5 *)
    let digest sys =
      let bytes = digest sys in
      Core_kernel.Md5.digest_bytes bytes

    include
      Kimchi_backend_common.Constraints.Make (Field) (Cvar)
        (struct
          type nonrec t = t
        end)
  end
end

module Pasta = struct
  module Rounds = Pasta.Rounds
  module Bigint256 = Pasta.Bigint256
  module Fp = Pasta.Fp
  module Fq = Pasta.Fq
  module Vesta = Pasta.Vesta
  module Pallas = Pasta.Pallas
end
