open Core_kernel

module Foo = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        (* can't version arrow type *)
        type t = int -> string [@@deriving version]
      end

      include T
    end
  end
end

module Bar = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type t = Foo.Stable.V1.t [@@deriving version]
      end

      include T
    end
  end
end

module Quux = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        (* tuple of versioned types *)
        type t = Foo.Stable.V1.t * Bar.Stable.V1.t [@@deriving version]
      end

      include T
    end
  end
end

module Bazz = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        (* record of versioned types *)
        type t = {one: Foo.Stable.V1.t; two: Bar.Stable.V1.t}
        [@@deriving version]
      end

      include T
    end
  end
end
