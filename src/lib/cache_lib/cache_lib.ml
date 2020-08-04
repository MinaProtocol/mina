[%%import
"/src/config.mlh"]

open Core_kernel
module Intf = Intf

include Impl.Make (struct
  let msg = sprintf "cached item was not consumed (cache name = \"%s\")"

  [%%if
  cache_exceptions]

  let handle_unconsumed_cache_item ~logger:_ ~cache_name =
    let open Error in
    raise (of_string (msg cache_name))

  [%%else]

  let handle_unconsumed_cache_item ~logger ~cache_name =
    [%log error] "Unconsumed item in cache: $cache"
      ~metadata:[("cache", `String (msg cache_name))]

  [%%endif]
end)
