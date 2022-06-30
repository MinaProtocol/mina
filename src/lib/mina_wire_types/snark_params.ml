module Tick = struct
  module Field = struct
    type t = Marlin_plonk_bindings_pasta_fp.t
  end

  module Inner_curve = struct
    type t = Marlin_plonk_bindings_pasta_pallas.t

    module Scalar = struct
      type t = Marlin_plonk_bindings_pasta_fq.t
    end
  end
end

module Tock = struct
  module Field = struct
    type t = Marlin_plonk_bindings_pasta_fq.t
  end

  module Inner_curve = struct
    type t = Marlin_plonk_bindings_pasta_vesta.t

    module Scalar = struct
      type t = Marlin_plonk_bindings_pasta_fp.t
    end
  end
end
