(rule
  (target dune-linker)
  (enabled_if %{bin-available:lld})
  (action (with-stdout-to dune-linker (echo "lld"))))

(rule
  (target dune-linker)
  (enabled_if (= %{bin-available:lld} false))
  (action (with-stdout-to dune-linker (echo "bfd"))))
