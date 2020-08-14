open Core_kernel

let sexp_of_t sexp_of_a t = [%sexp_of: a list] (DynArray.to_list t)

let t_of_sexp a_of_sexp ls = DynArray.of_list ([%of_sexp: a list] ls)

module Arr = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type 'a t = 'a array
    end
  end]
end

[%%versioned_binable
module Stable = struct
  module V1 = struct
    type 'a t = 'a DynArray.t

    include Binable.Of_binable1
              (Arr.Stable.V1)
              (struct
                type 'a t = 'a DynArray.t

                let to_binable = DynArray.to_array

                let of_binable = DynArray.of_array
              end)
  end
end]
