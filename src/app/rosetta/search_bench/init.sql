-- Fixture for rosetta_search_bench: the released schema, migrated the way a
-- production archive is, then filled with a synthetic chain.
--
--   psql "$PG_CONN" -f src/app/rosetta/search_bench/init.sql
--
-- Scale with -v (defaults in generate.sql), e.g. -v blocks=2000 for a quick run.

\set ON_ERROR_STOP on

\ir ../../archive/create_schema.sql
\ir ../../archive/upgrade.sql

-- upgrade.sql sets these for its own DDL; the bulk load below must not inherit them
RESET lock_timeout;
RESET statement_timeout;

\ir generate.sql
