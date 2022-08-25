module Tick = struct
  module Field = struct
    type t = Pasta_bindings.Fp.t
  end

  module Inner_curve = struct
    type t = Pasta_bindings.Pallas.t

    module Scalar = struct
      type t = Pasta_bindings.Fq.t
    end
  end
end

module Tock = struct
  module Field = struct
    type t = Pasta_bindings.Fq.t
  end

  module Inner_curve = struct
    type t = Pasta_bindings.Vesta.t

    module Scalar = struct
      type t = Pasta_bindings.Fp.t
    end
  end
end
