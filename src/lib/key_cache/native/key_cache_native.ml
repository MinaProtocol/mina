let linkme : unit =
  Key_cache.set_sync_implementation (module Key_cache_sync) ;
  Key_cache.set_async_implementation (module Key_cache_async)
