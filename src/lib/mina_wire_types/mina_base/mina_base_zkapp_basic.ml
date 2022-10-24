[%%import "/src/config.mlh"]

module Set_or_keep = struct
  module V1 = struct
    type 'a t = Set of 'a | Keep
  end
end

module Or_ignore = struct
  module V1 = struct
    type 'a t = Check of 'a | Ignore
  end
end

[%%ifdef consensus_mechanism]

module F = struct
  module V1 = struct
    type t = Pickles.Backend.Step.Field.V1.t
  end
end

[%%else]

module F = struct
  module V1 = struct
    type t = Snark_params.Step.Field.V1.t
  end
end

[%%endif]
