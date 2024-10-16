open Core_kernel
module Intf = Intf

include Impl.Make (struct
  let msg = sprintf "cached item was not consumed (cache name = \"%s\")"

  let handle_unconsumed_cache_item ~logger ~cache_exceptions ~cache_name =
    if cache_exceptions then
      let open Error in
      raise (of_string (msg cache_name))
    else
      [%log error] "Unconsumed item in cache: $cache"
        ~metadata:[ ("cache", `String (msg cache_name)) ]
end)
