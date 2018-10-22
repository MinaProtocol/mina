open Core_kernel

module Compare = struct
  module type S = sig
    type t
    val compare : t -> t -> int
  end
end

module Simple_hash = struct
  module type S = sig
    type t
    val hash_fold_t :
         Ppx_hash_lib.Std.Hash.state
      -> t
      -> Ppx_hash_lib.Std.Hash.state
    val hash : t -> int
  end
end

module Protocol_object = struct
  module type S = sig
    type t
    include Binable.S with type t := t
    include Equal.S with type t := t
    include Sexpable.S with type t := t
  end

  module Comparable = struct
    module type S = sig
      include S
      include Compare.S with type t := t
    end
  end

  module Hashable = struct
    module type S = sig
      include S
      include Simple_hash.S with type t := t
    end
  end

  module Full = struct
    module type S = sig
      include S
      include Compare.S with type t := t
      include Simple_hash.S with type t := t
    end
  end
end
