  $ dune build @old
  ARFLAGS=rsc
  CXX=g++
  CXXFLAGS="-Wall -O3 -g -pthread"
  if ! ${.ARCH_SIXTYFOUR}; then
    CXX="$CXX -m32"
  fi
  ${.MAKE} -s -C libre2 clean
  ${.MAKE} -s -C libre2 \
    ARFLAGS="$ARFLAGS" \
    CXX="$CXX" \
    CXXFLAGS="$CXXFLAGS" \
    obj/libre2$ext_lib obj/so/libre2$ext_dll
  cp libre2/obj/libre2$ext_lib libre2_c_stubs$ext_lib
  cp libre2/obj/so/libre2$ext_dll dllre2_c_stubs$ext_dll
  ${.MAKE} -s -C libre2 clean

  $ dune build @new
  ARFLAGS=rsc
  CXX=g++
  CXXFLAGS="-Wall -O3 -g -pthread"
  if ! ${.ARCH_SIXTYFOUR}; then
    CXX="$CXX -m32"
  fi
  ${.MAKE} -s -C libre2 clean
  ${.MAKE} -s -C libre2 \
    ARFLAGS="$ARFLAGS" \
    CXX="$CXX" \
    CXXFLAGS="$CXXFLAGS" \
    obj/libre2$ext_lib obj/so/libre2$ext_dll
  cp libre2/obj/libre2$ext_lib libre2_c_stubs$ext_lib
  cp libre2/obj/so/libre2$ext_dll dllre2_c_stubs$ext_dll
  ${.MAKE} -s -C libre2 clean

  $ dune build @quoting-test
  normal: A
  raw:    \065
