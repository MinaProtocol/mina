module Base = struct
  module type S = sig
    type t
  end
end

module Genesis = struct
  module type S = sig
    include Base.S

    (* TODO *)
  end
end

module type S = sig
  include Base.S

  (* TODO *)
end
