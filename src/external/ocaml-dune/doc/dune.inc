
(rule
 (with-stdout-to dune-build.1
  (run dune build --help=groff)))

(install
 (section man)
 (package dune)
 (files   dune-build.1))

(rule
 (with-stdout-to dune-clean.1
  (run dune clean --help=groff)))

(install
 (section man)
 (package dune)
 (files   dune-clean.1))

(rule
 (with-stdout-to dune-exec.1
  (run dune exec --help=groff)))

(install
 (section man)
 (package dune)
 (files   dune-exec.1))

(rule
 (with-stdout-to dune-external-lib-deps.1
  (run dune external-lib-deps --help=groff)))

(install
 (section man)
 (package dune)
 (files   dune-external-lib-deps.1))

(rule
 (with-stdout-to dune-help.1
  (run dune help --help=groff)))

(install
 (section man)
 (package dune)
 (files   dune-help.1))

(rule
 (with-stdout-to dune-install.1
  (run dune install --help=groff)))

(install
 (section man)
 (package dune)
 (files   dune-install.1))

(rule
 (with-stdout-to dune-installed-libraries.1
  (run dune installed-libraries --help=groff)))

(install
 (section man)
 (package dune)
 (files   dune-installed-libraries.1))

(rule
 (with-stdout-to dune-printenv.1
  (run dune printenv --help=groff)))

(install
 (section man)
 (package dune)
 (files   dune-printenv.1))

(rule
 (with-stdout-to dune-promote.1
  (run dune promote --help=groff)))

(install
 (section man)
 (package dune)
 (files   dune-promote.1))

(rule
 (with-stdout-to dune-rules.1
  (run dune rules --help=groff)))

(install
 (section man)
 (package dune)
 (files   dune-rules.1))

(rule
 (with-stdout-to dune-runtest.1
  (run dune runtest --help=groff)))

(install
 (section man)
 (package dune)
 (files   dune-runtest.1))

(rule
 (with-stdout-to dune-subst.1
  (run dune subst --help=groff)))

(install
 (section man)
 (package dune)
 (files   dune-subst.1))

(rule
 (with-stdout-to dune-uninstall.1
  (run dune uninstall --help=groff)))

(install
 (section man)
 (package dune)
 (files   dune-uninstall.1))

(rule
 (with-stdout-to dune-unstable-fmt.1
  (run dune unstable-fmt --help=groff)))

(install
 (section man)
 (package dune)
 (files   dune-unstable-fmt.1))

(rule
 (with-stdout-to dune-utop.1
  (run dune utop --help=groff)))

(install
 (section man)
 (package dune)
 (files   dune-utop.1))

