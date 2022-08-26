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
