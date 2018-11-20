open Ctypes
open Foreign
open Rocks_common

module Cache =
  struct
    type nonrec t = t
    let t = t

    let get_pointer = get_pointer

    let create_no_gc =
      (* extern rocksdb_cache_t* rocksdb_cache_create_lru(size_t capacity); *)
      foreign
        "rocksdb_cache_create_lru"
        (Views.int_to_size_t @-> returning t)

    let destroy =
      (* extern void rocksdb_cache_destroy(rocksdb_cache_t* cache); *)
      make_destroy t "rocksdb_cache_destroy"

    let create capacity =
      let t = create_no_gc capacity in
      Gc.finalise destroy t;
      t

    let with_t capacity f =
      let t = create_no_gc capacity in
      finalize
        (fun () -> f t)
        (fun () -> destroy t)

    let create_setter property_name property_typ =
      foreign
        ("rocksdb_cache_" ^ property_name)
        (t @-> property_typ @-> returning void)

    let set_capacity = create_setter "set_capacity" int
  end

module Snapshot =
  struct
    type nonrec t = t
    let t = t
  end

module BlockBasedTableOptions =
  struct
    include CreateConstructors(struct
                                  let name = "block_based_table_options"
                                  let constructor = "rocksdb_block_based_options_create"
                                  let destructor  = "rocksdb_block_based_options_destroy"
                                  let setter_prefix = "rocksdb_block_based_options_"
                                end)

    (* extern void rocksdb_block_based_options_set_block_size( *)
    (*     rocksdb_block_based_table_options_t* options, size_t block_size); *)
    let set_block_size =
      create_setter "set_block_size" Views.int_to_size_t

    (* extern void rocksdb_block_based_options_set_block_size_deviation( *)
    (*     rocksdb_block_based_table_options_t* options, int block_size_deviation); *)
    let set_block_size_deviation =
      create_setter "set_block_size_deviation" int

    (* extern void rocksdb_block_based_options_set_block_restart_interval( *)
    (*     rocksdb_block_based_table_options_t* options, int block_restart_interval); *)
    let set_block_restart_interval =
      create_setter "set_block_restart_interval" int

    (* extern void rocksdb_block_based_options_set_filter_policy( *)
    (*     rocksdb_block_based_table_options_t* options, *)
    (*     rocksdb_filterpolicy_t* filter_policy); *)
    (* let set_filter_policy = *)
    (*   create_setter "set_filter_policy" TODO *)

    (* extern void rocksdb_block_based_options_set_no_block_cache( *)
    (*     rocksdb_block_based_table_options_t* options, *)
    (*     unsigned char no_block_cache); *)
    let set_no_block_cache =
      create_setter "set_no_block_cache" Views.bool_to_uchar

    (* extern void rocksdb_block_based_options_set_block_cache( *)
    (*     rocksdb_block_based_table_options_t* options, rocksdb_cache_t* block_cache); *)
    let set_block_cache =
      create_setter "set_block_cache" Cache.t

    (* extern void rocksdb_block_based_options_set_block_cache_compressed( *)
    (*     rocksdb_block_based_table_options_t* options, *)
    (*     rocksdb_cache_t* block_cache_compressed); *)
    let set_block_cache_compressed =
      create_setter "set_block_cache_compressed" Cache.t

    (* extern void rocksdb_block_based_options_set_whole_key_filtering( *)
    (*     rocksdb_block_based_table_options_t*, unsigned char); *)
    let set_whole_key_filtering =
      create_setter "set_whole_key_filtering" Views.bool_to_uchar

    (* extern void rocksdb_block_based_options_set_format_version( *)
    (*     rocksdb_block_based_table_options_t*, int); *)
    let set_format_version =
      create_setter "set_format_version" int

    module IndexType =
      struct
        type t = int
        let binary_search = 0
        let hash_search = 1
      end
    (* enum { *)
    (*   rocksdb_block_based_table_index_type_binary_search = 0, *)
    (*   rocksdb_block_based_table_index_type_hash_search = 1, *)
    (* }; *)
    (* extern void rocksdb_block_based_options_set_index_type( *)
    (*     rocksdb_block_based_table_options_t*, int); // uses one of the above enums *)
    let set_index_type =
      create_setter "set_index_type" int

    (* extern void rocksdb_block_based_options_set_hash_index_allow_collision( *)
    (*     rocksdb_block_based_table_options_t*, unsigned char); *)
    let set_hash_index_allow_collision =
      create_setter "set_hash_index_allow_collision" Views.bool_to_uchar

    (* extern void rocksdb_block_based_options_set_cache_index_and_filter_blocks( *)
    (*     rocksdb_block_based_table_options_t*, unsigned char); *)
    let set_cache_index_and_filter_blocks =
      create_setter "set_cache_index_and_filter_blocks" Views.bool_to_uchar
  end

module Options = struct
  (* extern rocksdb_options_t* rocksdb_options_create(); *)
  (* extern void rocksdb_options_destroy(rocksdb_options_t*\); *)
  module C = CreateConstructors_(struct let name = "options" end)
  include C

  (* extern void rocksdb_options_increase_parallelism( *)
  (*     rocksdb_options_t* opt, int total_threads); *)
  let increase_parallelism = create_setter "increase_parallelism" int

  (* extern void rocksdb_options_optimize_for_point_lookup( *)
  (*     rocksdb_options_t* opt, uint64_t block_cache_size_mb); *)
  let optimize_for_point_lookup =
    create_setter "optimize_for_point_lookup" Views.int_to_uint64_t

  (* extern void rocksdb_options_optimize_level_style_compaction( *)
  (*     rocksdb_options_t* opt, uint64_t memtable_memory_budget); *)
  let optimize_level_style_compaction =
    create_setter "optimize_level_style_compaction" Views.int_to_uint64_t

  (* extern void rocksdb_options_optimize_universal_style_compaction( *)
  (*     rocksdb_options_t* opt, uint64_t memtable_memory_budget); *)
  let optimize_universal_style_compaction =
    create_setter "optimize_universal_style_compaction" Views.int_to_uint64_t

  (* extern void rocksdb_options_set_compaction_filter( *)
  (*     rocksdb_options_t*, *)
  (*     rocksdb_compactionfilter_t*\); *)
  (* extern void rocksdb_options_set_compaction_filter_factory( *)
  (*     rocksdb_options_t*, rocksdb_compactionfilterfactory_t*\); *)
  (* extern void rocksdb_options_set_compaction_filter_factory_v2( *)
  (*     rocksdb_options_t*, *)
  (*     rocksdb_compactionfilterfactoryv2_t*\); *)
  (* extern void rocksdb_options_set_comparator( *)
  (*     rocksdb_options_t*, *)
  (*     rocksdb_comparator_t*\); *)
  (* extern void rocksdb_options_set_merge_operator( *)
  (*     rocksdb_options_t*, *)
  (*     rocksdb_mergeoperator_t*\); *)
  (* extern void rocksdb_options_set_uint64add_merge_operator(rocksdb_options_t*\); *)

  (* extern void rocksdb_options_set_compression_per_level( *)
  (*   rocksdb_options_t* opt, *)
  (*   int* level_values, *)
  (*   size_t num_levels); *)

  (* extern void rocksdb_options_set_create_if_missing( *)
  (*     rocksdb_options_t*, unsigned char); *)
  let set_create_if_missing = create_setter "set_create_if_missing" Views.bool_to_uchar

  (* extern void rocksdb_options_set_create_missing_column_families( *)
  (*     rocksdb_options_t*, unsigned char); *)
  let set_create_missing_column_families =
    create_setter "set_create_missing_column_families" Views.bool_to_uchar

  (* extern void rocksdb_options_set_error_if_exists( *)
  (*     rocksdb_options_t*, unsigned char); *)
  let set_error_if_exists =
    create_setter "set_error_if_exists" Views.bool_to_uchar

  (* extern void rocksdb_options_set_paranoid_checks( *)
  (*     rocksdb_options_t*, unsigned char); *)
  let set_paranoid_checks =
    create_setter "set_paranoid_checks" Views.bool_to_uchar

  (* extern void rocksdb_options_set_env(rocksdb_options_t*, rocksdb_env_t*\); *)
  (* extern void rocksdb_options_set_info_log(rocksdb_options_t*, rocksdb_logger_t*\); *)
  (* extern void rocksdb_options_set_info_log_level(rocksdb_options_t*, int); *)

  (* extern void rocksdb_options_set_write_buffer_size(rocksdb_options_t*, size_t); *)
  let set_write_buffer_size =
    create_setter "set_write_buffer_size" Views.int_to_size_t

  (* extern void rocksdb_options_set_max_open_files(rocksdb_options_t*, int); *)
  let set_max_open_files =
    create_setter "set_max_open_files" int

  (* extern void rocksdb_options_set_max_total_wal_size(rocksdb_options_t* opt, uint64_t n); *)
  let set_max_total_wal_size =
    create_setter "set_max_total_wal_size" Views.int_to_uint64_t

  (* extern void rocksdb_options_set_compression_options( *)
  (*     rocksdb_options_t*, int, int, int); *)
  (* extern void rocksdb_options_set_prefix_extractor( *)
  (*     rocksdb_options_t*, rocksdb_slicetransform_t*\); *)
  (* extern void rocksdb_options_set_num_levels(rocksdb_options_t*, int); *)
  (* extern void rocksdb_options_set_level0_file_num_compaction_trigger( *)
  (*     rocksdb_options_t*, int); *)
  (* extern void rocksdb_options_set_level0_slowdown_writes_trigger( *)
  (*     rocksdb_options_t*, int); *)
  (* extern void rocksdb_options_set_level0_stop_writes_trigger( *)
  (*     rocksdb_options_t*, int); *)
  (* extern void rocksdb_options_set_max_mem_compaction_level( *)
  (*     rocksdb_options_t*, int); *)
  (* extern void rocksdb_options_set_target_file_size_base( *)
  (*     rocksdb_options_t*, uint64_t); *)
  (* extern void rocksdb_options_set_target_file_size_multiplier( *)
  (*     rocksdb_options_t*, int); *)
  (* extern void rocksdb_options_set_max_bytes_for_level_base( *)
  (*     rocksdb_options_t*, uint64_t); *)
  (* extern void rocksdb_options_set_max_bytes_for_level_multiplier( *)
  (*     rocksdb_options_t*, int); *)
  (* extern void rocksdb_options_set_expanded_compaction_factor( *)
  (*     rocksdb_options_t*, int); *)
  (* extern void rocksdb_options_set_max_grandparent_overlap_factor( *)
  (*     rocksdb_options_t*, int); *)
  (* extern void rocksdb_options_set_max_bytes_for_level_multiplier_additional( *)
  (*     rocksdb_options_t*, int* level_values, size_t num_levels); *)
  (* extern void rocksdb_options_enable_statistics(rocksdb_options_t*\); *)

  (* /* returns a pointer to a malloc()-ed, null terminated string */ *)
  (* extern char *rocksdb_options_statistics_get_string(rocksdb_options_t *opt); *)

  (* extern void rocksdb_options_set_max_write_buffer_number(rocksdb_options_t*, int); *)
  let set_max_write_buffer_number =
    create_setter "set_max_write_buffer_number" int

  (* extern void rocksdb_options_set_min_write_buffer_number_to_merge(rocksdb_options_t*, int); *)
  let set_min_write_buffer_number_to_merge =
    create_setter "set_min_write_buffer_number_to_merge" int

  (* extern void rocksdb_options_set_max_write_buffer_number_to_maintain( *)
  (*     rocksdb_options_t*, int); *)
  let set_max_write_buffer_number_to_maintain =
    create_setter "set_max_write_buffer_number_to_maintain" int

  (* extern void rocksdb_options_set_max_background_compactions(rocksdb_options_t*, int); *)
  let set_max_background_compactions =
    create_setter "set_max_background_compactions" int

  (* extern void rocksdb_options_set_max_background_flushes(rocksdb_options_t*, int); *)
  let set_max_background_flushes =
    create_setter "set_max_background_flushes" int

  (* extern void rocksdb_options_set_max_log_file_size(rocksdb_options_t*, size_t); *)
  let set_max_log_file_size =
    create_setter "set_max_log_file_size" Views.int_to_size_t

  (* extern void rocksdb_options_set_log_file_time_to_roll(rocksdb_options_t*, size_t); *)
  let set_log_file_time_to_roll =
    create_setter "set_log_file_time_to_roll" Views.int_to_size_t

  (* extern void rocksdb_options_set_keep_log_file_num(rocksdb_options_t*, size_t); *)
  let set_keep_log_file_num =
    create_setter "set_keep_log_file_num" Views.int_to_size_t

  (* extern ROCKSDB_LIBRARY_API void rocksdb_options_set_recycle_log_file_num( *)
  (*     rocksdb_options_t*, size_t); *)
  let set_recycle_log_file_num =
    create_setter "set_recycle_log_file_num" Views.int_to_size_t

  (* extern void rocksdb_options_set_soft_rate_limit(rocksdb_options_t*, double); *)
  let set_soft_rate_limit =
    create_setter "set_soft_rate_limit" float

  (* extern void rocksdb_options_set_hard_rate_limit(rocksdb_options_t*, double); *)
  let set_hard_rate_limit =
    create_setter "set_hard_rate_limit" float

  (* extern void rocksdb_options_set_rate_limit_delay_max_milliseconds( *)
  (*     rocksdb_options_t*, unsigned int); *)
  let set_rate_limit_delay_max_milliseconds =
    create_setter "set_rate_limit_delay_max_milliseconds" Views.int_to_uint_t

  (* extern void rocksdb_options_set_max_manifest_file_size( *)
  (*     rocksdb_options_t*, size_t); *)
  let set_max_manifest_file_size =
    create_setter "set_max_manifest_file_size" Views.int_to_size_t

  (* extern void rocksdb_options_set_table_cache_numshardbits( *)
  (*     rocksdb_options_t*, int); *)
  let set_table_cache_numshardbits =
    create_setter "set_table_cache_numshardbits" int

  (* extern void rocksdb_options_set_table_cache_remove_scan_count_limit( *)
  (*     rocksdb_options_t*, int); *)
  let set_table_cache_remove_scan_count_limit =
    create_setter "set_table_cache_remove_scan_count_limit" int

  (* extern void rocksdb_options_set_arena_block_size( *)
  (*     rocksdb_options_t*, size_t); *)
  let set_arena_block_size =
    create_setter "set_arena_block_size" Views.int_to_size_t

  (* extern void rocksdb_options_set_use_fsync( *)
  (*     rocksdb_options_t*, int); *)
  let set_use_fsync =
    create_setter "set_use_fsync" Views.bool_to_int

  (* extern void rocksdb_options_set_db_log_dir( *)
  (*     rocksdb_options_t*, const char*\); *)
  (* extern void rocksdb_options_set_wal_dir( *)
  (*     rocksdb_options_t*, const char*\); *)

  (* extern void rocksdb_options_set_WAL_ttl_seconds( *)
  (*     rocksdb_options_t*, uint64_t); *)
  let set_WAL_ttl_seconds =
    create_setter "set_WAL_ttl_seconds" Views.int_to_uint64_t

  (* extern void rocksdb_options_set_WAL_size_limit_MB( *)
  (*     rocksdb_options_t*, uint64_t); *)
  let set_WAL_size_limit_MB =
    create_setter "set_WAL_size_limit_MB" Views.int_to_uint64_t

  (* extern void rocksdb_options_set_manifest_preallocation_size( *)
  (*     rocksdb_options_t*, size_t); *)
  let set_manifest_preallocation_size =
    create_setter "set_manifest_preallocation_size" Views.int_to_size_t

  (* extern void rocksdb_options_set_purge_redundant_kvs_while_flush( *)
  (*     rocksdb_options_t*, unsigned char); *)
  let set_purge_redundant_kvs_while_flush =
    create_setter "set_purge_redundant_kvs_while_flush" Views.bool_to_uchar

  (* extern void rocksdb_options_set_use_direct_reads( *)
  (*     rocksdb_options_t*, unsigned char); *)
  let set_use_direct_reads =
    create_setter "set_use_direct_reads" Views.bool_to_uchar

  (* extern void rocksdb_options_set_allow_mmap_reads( *)
  (*     rocksdb_options_t*, unsigned char); *)
  let set_allow_mmap_reads =
    create_setter "set_allow_mmap_reads" Views.bool_to_uchar

  (* extern void rocksdb_options_set_allow_mmap_writes( *)
  (*     rocksdb_options_t*, unsigned char); *)
  let set_allow_mmap_writes =
    create_setter "set_allow_mmap_writes" Views.bool_to_uchar

  (* extern void rocksdb_options_set_is_fd_close_on_exec( *)
  (*     rocksdb_options_t*, unsigned char); *)
  let set_is_fd_close_on_exec =
    create_setter "set_is_fd_close_on_exec" Views.bool_to_uchar

  (* extern void rocksdb_options_set_skip_log_error_on_recovery( *)
  (*     rocksdb_options_t*, unsigned char); *)
  let set_skip_log_error_on_recovery =
    create_setter "set_skip_log_error_on_recovery" Views.bool_to_uchar

  (* extern void rocksdb_options_set_stats_dump_period_sec( *)
  (*     rocksdb_options_t*, unsigned int); *)
  let set_stats_dump_period_sec =
    create_setter "set_stats_dump_period_sec" Views.int_to_uint_t

  (* extern void rocksdb_options_set_advise_random_on_open( *)
  (*     rocksdb_options_t*, unsigned char); *)
  let set_advise_random_on_open =
    create_setter "set_advise_random_on_open" Views.bool_to_uchar

  (* extern void rocksdb_options_set_access_hint_on_compaction_start( *)
  (*     rocksdb_options_t*, int); *)
  let set_access_hint_on_compaction_start =
    create_setter "set_access_hint_on_compaction_start" int

  (* extern void rocksdb_options_set_use_adaptive_mutex( *)
  (*     rocksdb_options_t*, unsigned char); *)
  let set_use_adaptive_mutex =
    create_setter "set_use_adaptive_mutex" Views.bool_to_uchar

  (* extern void rocksdb_options_set_bytes_per_sync( *)
  (*     rocksdb_options_t*, uint64_t); *)
  let set_bytes_per_sync =
    create_setter "set_bytes_per_sync" Views.int_to_uint64_t

  (* extern void rocksdb_options_set_max_sequential_skip_in_iterations( *)
  (*     rocksdb_options_t*, uint64_t); *)
  let set_max_sequential_skip_in_iterations =
    create_setter "set_max_sequential_skip_in_iterations" Views.int_to_uint64_t

  (* extern void rocksdb_options_set_disable_auto_compactions(rocksdb_options_t*, int); *)
  let set_disable_auto_compactions =
    create_setter "set_disable_auto_compactions" int

  (* extern void rocksdb_options_set_delete_obsolete_files_period_micros( *)
  (*     rocksdb_options_t*, uint64_t); *)
  let set_delete_obsolete_files_period_micros =
    create_setter "set_delete_obsolete_files_period_micros" Views.int_to_uint64_t

  (* extern void rocksdb_options_set_max_compaction_bytes(
    rocksdb_options_t*, uint64_t); *)
  let set_max_compaction_bytes =
    create_setter "set_max_compaction_bytes" int

  (* extern void rocksdb_options_prepare_for_bulk_load(rocksdb_options_t*\); *)
  (* extern void rocksdb_options_set_memtable_vector_rep(rocksdb_options_t*\); *)
  (* extern void rocksdb_options_set_hash_skip_list_rep(rocksdb_options_t*, size_t, int32_t, int32_t); *)
  (* extern void rocksdb_options_set_hash_link_list_rep(rocksdb_options_t*, size_t); *)
  (* extern void rocksdb_options_set_plain_table_factory(rocksdb_options_t*, uint32_t, int, double, size_t); *)

  (* extern void rocksdb_options_set_min_level_to_compress(rocksdb_options_t* opt, int level); *)
  let set_min_level_to_compress =
    create_setter "set_min_level_to_compress" int

  (* extern void rocksdb_options_set_max_successive_merges( *)
  (*     rocksdb_options_t*, size_t); *)
  let set_max_successive_merges =
    create_setter "set_max_successive_merges" Views.int_to_size_t

  (* extern void rocksdb_options_set_bloom_locality( *)
  (*     rocksdb_options_t*, uint32_t); *)
  let set_bloom_locality =
    create_setter "set_bloom_locality" Views.int_to_uint32_t

  (* extern void rocksdb_options_set_inplace_update_support( *)
  (*     rocksdb_options_t*, unsigned char); *)
  let set_inplace_update_support =
    create_setter "set_inplace_update_support" Views.bool_to_uchar

  (* extern void rocksdb_options_set_inplace_update_num_locks( *)
  (*     rocksdb_options_t*, size_t); *)
  let set_inplace_update_num_locks =
    create_setter "set_inplace_update_num_locks" Views.int_to_size_t

  (* enum { *)
  (*   rocksdb_no_compression = 0, *)
  (*   rocksdb_snappy_compression = 1, *)
  (*   rocksdb_zlib_compression = 2, *)
  (*   rocksdb_bz2_compression = 3, *)
  (*   rocksdb_lz4_compression = 4, *)
  (*   rocksdb_lz4hc_compression = 5 *)
  (* }; *)
  (* extern void rocksdb_options_set_compression(rocksdb_options_t*, int); *)

  (* enum { *)
  (*   rocksdb_level_compaction = 0, *)
  (*   rocksdb_universal_compaction = 1, *)
  (*   rocksdb_fifo_compaction = 2 *)
  (* }; *)
  (* extern void rocksdb_options_set_compaction_style(rocksdb_options_t*, int); *)
  (* extern void rocksdb_options_set_universal_compaction_options(rocksdb_options_t*, rocksdb_universal_compaction_options_t*\); *)
  (* extern void rocksdb_options_set_fifo_compaction_options(rocksdb_options_t* opt, *)
  (*     rocksdb_fifo_compaction_options_t* fifo); *)

  (* extern void rocksdb_options_set_block_based_table_factory( *)
  (*     rocksdb_options_t *opt, rocksdb_block_based_table_options_t* table_options); *)
  let set_block_based_table_factory =
    create_setter "set_block_based_table_factory" BlockBasedTableOptions.t
end

module WriteOptions = struct
  module C = CreateConstructors_(struct let name = "writeoptions" end)
  include C

  let set_disable_WAL = create_setter "disable_WAL" Views.bool_to_int
  let set_sync = create_setter "set_sync" Views.bool_to_uchar
end

module ReadOptions = struct
  module C = CreateConstructors_(struct let name = "readoptions" end)
  include C

  let set_snapshot = create_setter "set_snapshot" Snapshot.t
end

module FlushOptions = struct
  module C = CreateConstructors_(struct let name = "flushoptions" end)
  include C

  let set_wait = create_setter "set_wait" Views.bool_to_uchar
end

module TransactionOptions = struct
  module C = CreateConstructors_(struct let name = "transaction_options" end)
  include C

  let set_set_snapshot = create_setter "set_set_snapshot" Views.bool_to_uchar
end

module TransactionDbOptions = struct
  module C = CreateConstructors_(struct let name = "transactiondb_options" end)
  include C
end
