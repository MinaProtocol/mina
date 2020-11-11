"""Package variables module.

Package-scoped configuration variable definitions.
"""

PKG_DEBUG_OPT = select({":enable_debug": ["-g"], "//conditions:default": []})
PKG_VERBOSE_OPT = select({":enable_verbose": ["-verbose"], "//conditions:default": []})

PKG_OPTS = PKG_DEBUG_OPT + PKG_VERBOSE_OPT

PKG_INTERFACE_OPTS = PKG_OPTS

PKG_MODULE_OPTS = PKG_OPTS

PKG_ARCHIVE_OPTS = PKG_OPTS

PKG_NS_MODULE_OPTS = PKG_OPTS
