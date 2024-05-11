module Intf = Intf

include Impl.Make (struct
  let handle_unconsumed_cache_item =
    Mina_compile_config.handle_unconsumed_cache_item
end)
