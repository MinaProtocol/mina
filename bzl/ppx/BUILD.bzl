## ppx_pkg_bzl.mustache
PKG_ALWAYS_LINK_OPT = select({":enable_always_link": ["-linkall"], "//conditions:default": []})
PKG_DEBUG_OPT = select({":enable_debug": ["-g"], "//conditions:default": []})
PKG_THREADS_OPT = select({":enable_threads": ["-thread"], "//conditions:default": []})
PKG_TOOLING_OPT = select({":enable_tooling": ["-bin-annot"], "//conditions:default": []})
PKG_VERBOSE_OPT = select({":enable_verbose": ["-verbose"], "//conditions:default": []})

PKG_PPX_EXECUTABLE_OPTS = PKG_ALWAYS_LINK_OPT + PKG_DEBUG_OPT + PKG_THREADS_OPT + PKG_TOOLING_OPT + PKG_VERBOSE_OPT
