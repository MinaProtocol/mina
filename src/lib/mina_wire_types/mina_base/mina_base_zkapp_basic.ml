module Set_or_keep = struct
  module V1 = struct
    type 'a t = Set of 'a | Keep
  end
end
