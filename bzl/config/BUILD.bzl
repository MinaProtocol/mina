load("@bazel_skylib//rules:common_settings.bzl",
     "bool_flag",
     "int_flag",
     "string_flag", "string_setting",
     "BuildSettingInfo")

def _int_enum_impl(ctx):
    allowed_values = ctx.attr.values
    value = ctx.build_setting_value
    if len(allowed_values) == 0 or value in ctx.attr.values:
        return BuildSettingInfo(value = value)
    else:
        fail("Error setting " + str(ctx.label) + ": invalid value '" + str(value) + "'. Allowed values are " + str(allowed_values))

int_enum_flag = rule(
    doc = "Integer enum flag.",
    implementation = _int_enum_impl,
    build_setting = config.int(flag = True),
    attrs = {
        "values": attr.int_list(
            doc = "The list of allowed values for this setting. An error is raised if any other value is given.",
        ),
    },
)
