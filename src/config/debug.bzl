load(":BUILD.bzl", "coda_config")
# config/debug.mlh
# [%%import "/src/config/ledger_depth/full.mlh"]
# [%%import "/src/config/curve/medium.mlh"]
# [%%import "/src/config/coinbase/standard.mlh"]
# [%%import "/src/config/consensus/postake_short.mlh"]
# [%%import "/src/config/scan_state/standard.mlh"]
# [%%import "/src/config/debug_level/all.mlh"]
# [%%import "/src/config/proof_level/check.mlh"]
# [%%import "/src/config/txpool_size.mlh"]
# [%%import "/src/config/account_creation_fee/standard.mlh"]
# [%%import "/src/config/amount_defaults/standard.mlh"]
# [%%import "/src/config/protocol_version/current.mlh"]
# [%%import "/src/config/supercharged_coinbase_factor/two.mlh"]

coda_config(
    name = "debug",
    visibility = ["//visibility:public"],

    scan_state_transaction_capacity_log_2 = "//src/config/scan_state/std:txn_capacity_log2", # 7,
    scan_state_work_delay = "//src/config/scan_state/std:work_delay", # 7, # scan_state/standard.mlh
    debug_logs = "//src/config/debug/all:logs",  # debug_level/all.mlh
    call_logger = "//src/config/debug/all:call_logger",
    record_async_backtraces = "//src/config/debug/all:record_async_backtraces",

    account_creation_fee_int = "//src/config/fees/std:account_creation",
    plugins = "//src/config:plugins_false",
    time_offsets = "//src/config:time_offsets_false"
)

