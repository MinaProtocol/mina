open Core_kernel

module Foo = struct
  module Bar = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        (* "option" misspelled *)
        type t = int optin [@@deriving yojson]

        let to_latest = Fn.id
      end
    end]
  end
end
