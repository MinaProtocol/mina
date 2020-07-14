load("@bazel_skylib//rules:common_settings.bzl",
     "bool_flag",
     "string_flag",
     "BuildSettingInfo")

def _coda_test_config_impl(ctx):
    return [DefaultInfo(files = ctx.attr.config[DefaultInfo].files)]

coda_test_config = rule(
    implementation = _coda_test_config_impl,
    # defaults are from src/config/dev.mlh
    attrs = {
        "config": attr.label()
    }
)

def _coda_config_impl(ctx):
    outfile = ctx.actions.declare_file("config.mlh")
    ##FIXME: validate: timestamp, duration
    # proof_level: check, full, none
    print("_coda_config_impl")
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
            "{CONSENSUS_C}": str(ctx.attr.consensus_c[BuildSettingInfo].value),
            "{CONSENSUS_DELTA}": str(ctx.attr.consensus_delta[BuildSettingInfo].value),
            "{SCAN_STATE_WITH_TPS_GOAL}": str(
                ctx.attr.scan_state_with_tps_goal[BuildSettingInfo].value
            ),
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
            "{TIME_OFFSETS}": str(
                ctx.attr.time_offsets[BuildSettingInfo].value,
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
    return [DefaultInfo(files = depset([outfile]))]

coda_config = rule(
    implementation = _coda_config_impl,
    # defaults are from src/config/dev.mlh
    attrs = {
        "ledger_depth": attr.label(default="//src/config/ledger_depth"),
        "curve_size": attr.label(default="//src/config/curve_size"),
        "coinbase": attr.label(default="//src/config/coinbase"),

        "consensus_mechanism": attr.label(default="//src/config/consensus:mechanism"),
        "consensus_k": attr.label(default="//src/config/consensus:k"),
        "consensus_c": attr.label(default="//src/config/consensus:c"),
        "consensus_delta": attr.label(default="//src/config/consensus:delta"),

        # defaults = scan_state/medium.mlh
        "scan_state_with_tps_goal": attr.label(
            default="//src/config/scan_state:with_tps_goal"
        ),
        "scan_state_transaction_capacity_log_2": attr.label(
            default="//src/config/scan_state:txn_capacity_log2"
        ),
        "scan_state_work_delay": attr.label(
            default="//src/config/scan_state:work_delay"
        ),
        ## WARNING: the following is only set by a few include files in scan_state/
        ## It is not set for dev.mlh
        "scan_state_tps_goal_x10": attr.label(
            default="//src/config/scan_state:tps_goal_x10"
        ),

        # debug defaults: debug/level/some.mlh
        "debug_logs": attr.label(default="//src/config/debug:logs"),
        "call_logger": attr.label(default="//src/config/debug:call_logger"),
        "tracing": attr.label(default="//src/config/debug:tracing"),
        "cache_exceptions": attr.label(
            default="//src/config/debug:cache_exceptions"
        ),
        "record_async_backtraces": attr.label(
            default="//src/config/debug:record_async_backtraces"
        ),

        "proof_level":  attr.label(
            default="//src/config/proof_level"
        ),

        "pool_max_size": attr.label(default="//src/config/txn_pool:max_size"),

        "account_creation_fee_int": attr.label(
            default="//src/config/fees:account_creation"
        ),
        "default_transaction_fee": attr.label(
            default="//src/config/fees:txn"
        ),
        "default_snark_worker_fee": attr.label(
            default="//src/config/fees:snark_worker"
        ),
        "minimum_user_command_fee": attr.label(
            default="//src/config/fees:min_user_cmd"
        ),

        "current_protocol_version": attr.label(
            default="//src/config:protocol_version",
        ),

        ## src/config/dev.mlh:
        "time_offsets": attr.label(default = "//src/config:time_offsets"),
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

