load("@bazel_skylib//rules:common_settings.bzl",
     "bool_flag",
     "string_flag",
     "BuildSettingInfo")

def _mina_test_config_impl(ctx):
    return [DefaultInfo(files = ctx.attr.config[DefaultInfo].files)]

mina_test_config = rule(
    implementation = _mina_test_config_impl,
    # defaults are from src/config/dev.mlh
    attrs = {
        "config": attr.label()
    }
)

def _mina_config_impl(ctx):
    outfile = ctx.actions.declare_file("config.mlh")
    ##FIXME: validate: timestamp, duration
    # proof_level: check, full, none
    runfiles = ctx.runfiles(files = [outfile])
    ctx.actions.expand_template(
        output = outfile,
        template = ctx.file._template,
        substitutions = {
            "{PROFILE}": ctx.label.name,
            "{LEDGER_DEPTH}": str(
                ctx.attr.ledger_depth[BuildSettingInfo].value
            ),
            "{CURVE_SIZE}": str(ctx.attr.curve_size[BuildSettingInfo].value),
            "{COINBASE}": str(ctx.attr.coinbase[BuildSettingInfo].value),
            "{CONSENSUS_MECHANISM}": ctx.attr.consensus_mechanism[BuildSettingInfo].value,
            "{CONSENSUS_K}": str(ctx.attr.consensus_k[BuildSettingInfo].value),
            "{CONSENSUS_DELTA}": str(ctx.attr.consensus_delta[BuildSettingInfo].value),
            "{CONSENSUS_SLOTS_PER_EPOCH}": str(ctx.attr.consensus_slots_per_epoch[BuildSettingInfo].value),
            "{CONSENSUS_SLOTS_PER_SUBWINDOW}": str(ctx.attr.consensus_slots_per_subwindow[BuildSettingInfo].value),
            "{CONSENSUS_SUBWINDOWS_PER_WINDOW}": str(ctx.attr.consensus_subwindows_per_window[BuildSettingInfo].value),
            "{SCAN_STATE_WITH_TPS_GOAL}": str(
                ctx.attr.scan_state_with_tps_goal[BuildSettingInfo].value
            ).lower(),
            "{SCAN_STATE_TPS_GOAL_X10}": str(
                ctx.attr.scan_state_tps_goal_x10[BuildSettingInfo].value
            ),
            "{SCAN_STATE_TRANSACTION_CAPACITY_LOG_2}": str(
                ctx.attr.scan_state_transaction_capacity_log_2[BuildSettingInfo].value
            ),
            "{SCAN_STATE_WORK_DELAY}": str(
                ctx.attr.scan_state_work_delay[BuildSettingInfo].value
            ),
            "{DEBUG_LOGS}": str(
                ctx.attr.debug_logs[BuildSettingInfo].value
            ).lower(),
            "{CALL_LOGGER}": str(
                ctx.attr.call_logger[BuildSettingInfo].value
            ).lower(),
            "{TRACING}": str(
                ctx.attr.tracing[BuildSettingInfo].value
            ).lower(),
            "{CACHE_EXCEPTIONS}": str(
                ctx.attr.cache_exceptions[BuildSettingInfo].value
            ).lower(),
            "{RECORD_ASYNC_BACKTRACES}": str(
                ctx.attr.record_async_backtraces[BuildSettingInfo].value
            ).lower(),

            "{PROOF_LEVEL}": ctx.attr.proof_level[BuildSettingInfo].value,
            "{POOL_MAX_SIZE}": str(ctx.attr.pool_max_size[BuildSettingInfo].value),

            "{ACCOUNT_CREATION_FEE_INT}": str(
                ctx.attr.account_creation_fee_int[BuildSettingInfo].value
            ),
            "{DEFAULT_TRANSACTION_FEE}": str(
                ctx.attr.default_transaction_fee[BuildSettingInfo].value
            ),
            "{DEFAULT_SNARK_WORKER_FEE}": str(
                ctx.attr.default_snark_worker_fee[BuildSettingInfo].value
            ),
            "{MINIMUM_USER_COMMAND_FEE}": str(
                ctx.attr.minimum_user_command_fee[BuildSettingInfo].value
            ),

            "{CURRENT_PROTOCOL_VERSION}": str(
                ctx.attr.current_protocol_version[BuildSettingInfo].value
            ),
            "{SUPERCHARGED_COINBASE_FACTOR}": str(
                ctx.attr.supercharged_coinbase_factor[BuildSettingInfo].value
            ),
            "{FEATURE_TOKENS}": str(
                ctx.attr.feature_tokens[BuildSettingInfo].value
            ).lower(),
            "{FEATURE_SNAPPS}": str(
                ctx.attr.feature_snapps[BuildSettingInfo].value
            ).lower(),

            "{TIME_OFFSETS}": str(
                ctx.attr.time_offsets[BuildSettingInfo].value,
            ).lower(),
            "{PLUGINS}": str(
                ctx.attr.plugins[BuildSettingInfo].value,
            ).lower(),
            "{FAKE_HASH}": str(ctx.attr.fake_hash[BuildSettingInfo].value).lower(),
            "{GENESIS_LEDGER}": ctx.attr.genesis_ledger[BuildSettingInfo].value,
            "{GENESIS_STATE_TIMESTAMP}":
            ctx.attr.genesis_state_timestamp[BuildSettingInfo].value,
            "{BLOCK_WINDOW_DURATION}": str(
                ctx.attr.block_window_duration[BuildSettingInfo].value,
            ),
            "{INTEGRATION_TESTS}": str(
                ctx.attr.integration_tests[BuildSettingInfo].value
            ).lower(),
            "{FORCE_UPDATES}": str(
                ctx.attr.force_updates[BuildSettingInfo].value
            ).lower(),
            "{DOWNLOAD_SNARK_KEYS}": str(
                ctx.attr.download_snark_keys[BuildSettingInfo].value
            ).lower(),
            "{MOCK_FRONTEND_DATA}": str(
                ctx.attr.mock_frontend_data[BuildSettingInfo].value
            ).lower(),
            "{PRINT_VERSIONED_TYPES}": str(
                ctx.attr.print_versioned_types[BuildSettingInfo].value,
            ).lower(),
            "{DAEMON_EXPIRY}": ctx.attr.daemon_expiry[BuildSettingInfo].value,
            "{TEST_FULL_EPOCH}": str(
                ctx.attr.test_full_epoch[BuildSettingInfo].value
            ).lower()
        },
    )
    return [DefaultInfo(files = depset([outfile]), runfiles=runfiles)]

mina_config = rule(
    implementation = _mina_config_impl,
    # defaults are from src/config/dev.mlh
    attrs = {
        # [%%import "/src/config/ledger_depth/small.mlh"]
        #   [%%define ledger_depth 10]
        "ledger_depth": attr.label(default="//src/config/ledger_depth:small"),

        # [%%import "/src/config/curve/medium.mlh"]
        #   [%%define curve_size 255]
        "curve_size": attr.label(default="//src/config/curve_size:medium"),

        # [%%import "/src/config/coinbase/standard.mlh"]
        #   [%%define coinbase "20"]
        "coinbase": attr.label(default="//src/config/coinbase:standard"),

        # [%%import "/src/config/supercharged_coinbase_factor/two.mlh"]
        #   [%%define supercharged_coinbase_factor 2 ]
        "supercharged_coinbase_factor": attr.label(
            default="//src/config/coinbase:supercharged_factor",
        ),

        # [%%import "/src/config/consensus/postake_short.mlh"]
        #   [%%define consensus_mechanism "proof_of_stake"]
        #   [%%define k 24]
        #   [%%define delta 0]
        #   [%%define slots_per_epoch 576]
        #   [%%define slots_per_sub_window 2]
        #   [%%define sub_windows_per_window 3]
        "consensus_mechanism": attr.label(default="//src/config/consensus:mechanism"),
        "consensus_k": attr.label(default="//src/config/consensus/k:short"),
        "consensus_delta": attr.label(default="//src/config/consensus/delta:short"),
        "consensus_slots_per_epoch": attr.label(default="//src/config/consensus/epoch/slots:short"),
        "consensus_slots_per_subwindow": attr.label(
            default="//src/config/consensus/window/subwindows:short"),
        "consensus_subwindows_per_window": attr.label(
            default="//src/config/consensus/window/subwindows/slots:short"),

        # [%%import "/src/config/scan_state/medium.mlh"]
        #   [%%define scan_state_with_tps_goal false]
        #   [%%define scan_state_transaction_capacity_log_2 3]
        #   [%%define scan_state_work_delay 2]
        "scan_state_with_tps_goal": attr.label(
            default="//src/config/scan_state/tps_goal:medium"
            # default="//src/config/scan_state/medium/tps_goal:disabled"
        ),
        "scan_state_transaction_capacity_log_2": attr.label(
            default="//src/config/scan_state/txn_capacity/log2:medium"
            # default="//src/config/scan_state/medium/txn_capacity:log2"
        ),
        "scan_state_work_delay": attr.label(
            # default="//src/config/scan_state/medium:work_delay"
            default="//src/config/scan_state/work_delay:medium"
        ),
        ## WARNING: the following is only set by a few include files in scan_state/
        ## It is not set for dev.mlh (=> scan_state/medium.mlh
        # point5tps.mlh:  [%%define scan_state_tps_goal_x10 5]
        "scan_state_tps_goal_x10": attr.label(
            default="//src/config/scan_state/tps_goal/x10:medium"
        ),

        # [%%import "/src/config/debug_level/some.mlh"]
        #   [%%define debug_logs false]
        #   [%%define call_logger false]
        #   [%%define tracing true]
        #   [%%define cache_exceptions true]
        #   [%%define record_async_backtraces false]
        "debug_logs": attr.label(default="//src/config/debug/some:disable_logs"),
        "call_logger": attr.label(default="//src/config/debug/some:disable_call_logger"),
        "tracing": attr.label(default="//src/config/debug/some:enable_tracing"),
        "cache_exceptions": attr.label(
            default="//src/config/debug/some:enable_cache_exceptions"
        ),
        "record_async_backtraces": attr.label(
            default="//src/config/debug/some:disable_record_async_backtraces"
        ),

        # [%%import "/src/config/proof_level/check.mlh"]
        #   [%%define proof_level "check"]
        "proof_level":  attr.label( default="//src/config/proof_level:check" ),

        # [%%import "/src/config/txpool_size.mlh"]
        #   [%%define pool_max_size 3000]
        "pool_max_size": attr.label(default="//src/config/txn_pool/size:max"),

        # [%%import "/src/config/account_creation_fee/high.mlh"]
        #   [%%define account_creation_fee_int "2"]
        "account_creation_fee_int": attr.label(
            default="//src/config/fees/account_creation:high"
        ),
        # [%%import "/src/config/amount_defaults/standard.mlh"]
        #   [%%define default_transaction_fee "5"]
        #   [%%define default_snark_worker_fee "1"]
        #   [%%define minimum_user_command_fee "2"]
        "default_transaction_fee": attr.label( default="//src/config/fees/txn:standard" ),
        "default_snark_worker_fee": attr.label( default="//src/config/fees/snark_worker:standard" ),
        "minimum_user_command_fee": attr.label( default="//src/config/fees/user_cmd/standard:min" ),

        # [%%import "/src/config/protocol_version/current.mlh"]
        "current_protocol_version": attr.label(
            default="//src/config/protocol/version:current",
        ),

        # [%%import "/src/config/features/dev.mlh"]
        #   [%%define feature_tokens true]
        #   [%%define feature_snapps true]
        "feature_tokens": attr.label(
            default="//src/config/features/tokens:dev",
        ),
        "feature_snapps": attr.label(
            default="//src/config/features/snapps:dev",
        ),


        ## src/config/dev.mlh:
        "time_offsets": attr.label(default = "//src/config:time_offsets"),
        "plugins": attr.label(default = "//src/config:plugins"),
        "fake_hash": attr.label(default = "//src/config:with_fake_hash"),
        "genesis_ledger": attr.label(
            default = "//src/config/genesis/ledger" # default: "test"
        ),
        "genesis_state_timestamp": attr.label(
            default = "//src/config/genesis:state_timestamp"
        ),
        "block_window_duration": attr.label(
            default = "//src/config:block_window_duration"
        ),
        "integration_tests": attr.label(
            default = "//src/config:integration_tests"
        ),
        "force_updates": attr.label(default = "//src/config:force_updates"),
        "download_snark_keys": attr.label(default = "//src/config:download_snark_keys"),
        "mock_frontend_data": attr.label(
            default = "//src/config:mock_frontend_data"
        ),
        "print_versioned_types": attr.label(
            default = "//src/config:print_versioned_types"
        ),
        "daemon_expiry": attr.label(
            default = "//src/config:daemon_expiry"
        ),
        "test_full_epoch": attr.label(
            default = "//src/config:test_full_epoch"
        ),

        "_template": attr.label(
            allow_single_file = True,
            default="config.mlh.tpl"
        )
    },
)

