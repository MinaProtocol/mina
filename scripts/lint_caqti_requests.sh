#!/bin/bash

# Caqti caches a prepared statement per request OBJECT, on every connection that
# runs it, for the life of that connection. A request built inside a function
# therefore leaks one prepared statement per call, client side and server side
# both, which is how MinaProtocol/mina#18857 happened.
#
# Mina_caqti's constructors (find_req / find_opt_req / collect_req / exec_req)
# memoise on the SQL text, so code that goes through them cannot leak that way
# whatever the call site does. Its connections accept only the private
# Mina_caqti.query type, so the compiler already rejects a hand-built request --
# this check is the backstop for the ways around that: opening or aliasing
# Caqti_request to build one, or opening a raw Caqti_async connection that would
# take it.
#
# Grep, not the type system, so it must catch every spelling: a bare identifier
# match covers `open Caqti_request`, `module R = Caqti_request`, `include`, and
# every dotted use. Nothing outside mina_caqti.ml has any business naming it.

set -euo pipefail

# the memoising constructors and the interface that states their type
ALLOWED_RE="^src/lib/mina_caqti/mina_caqti\.mli?:"
ALLOWED="src/lib/mina_caqti/mina_caqti.ml{,i}"

status=0

report() {
  echo "Error: $1"
  echo
  echo "$2"
  echo
  status=1
}

# 1. Caqti_request in any form: open, alias, include, dotted use.
requests=$(grep -rn --include='*.ml' --include='*.mli' 'Caqti_request' src/ \
  | grep -Ev "$ALLOWED_RE" || true)

if [[ -n "$requests" ]]; then
  report "Caqti_request must not be named outside ${ALLOWED}." "$requests"
  echo "Build requests with Mina_caqti instead, which shares them:"
  echo "  Caqti_request.Infix.(a ->! b) sql    ->  Mina_caqti.find_req a b sql"
  echo "  Caqti_request.Infix.(a ->? b) sql    ->  Mina_caqti.find_opt_req a b sql"
  echo "  Caqti_request.Infix.(a ->* b) sql    ->  Mina_caqti.collect_req a b sql"
  echo "  Caqti_request.Infix.(a ->. unit) sql ->  Mina_caqti.exec_req a sql"
  echo
  echo "If the SQL text genuinely varies per call (values rendered into it),"
  echo "pass ~oneshot:true: such a query must not be cached."
  echo "To print one, use Mina_caqti.query_to_string."
  echo
fi

# 2. Raw connections, which would accept a request Mina_caqti did not build.
# \b so that Caqti_async.connection, a type these modules may legitimately
# name, is not mistaken for a call to Caqti_async.connect
connects=$(grep -rnE --include='*.ml' --include='*.mli' \
  'Caqti_async\.(connect|connect_pool|with_connection)\b' src/ \
  | grep -Ev "$ALLOWED_RE" || true)

if [[ -n "$connects" ]]; then
  report "Connect through Mina_caqti, not Caqti_async directly." "$connects"
  echo "Use Mina_caqti.connect / Mina_caqti.connect_pool, whose connections"
  echo "accept only requests this library built."
  echo
fi

if [[ $status -eq 0 ]]; then
  echo "OK: Caqti requests and connections all go through Mina_caqti"
fi

exit $status
