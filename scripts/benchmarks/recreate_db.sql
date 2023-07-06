DROP TABLE IF EXISTS BENCHMARKS;
DROP FUNCTION calculate_avg;

CREATE TABLE TEST
(
  id serial PRIMARY KEY,
  suite character(255) NOT NULL,
  test character(255) NOT NULL,
  env character(255) NOT NULL
);

CREATE TABLE BENCHMARK
(
  id serial PRIMARY KEY,
  test_id serial FOREIGN KEY(TEST),
  value numeric(10,2) NOT NULL,
  timestamp timestamp without time zone NOT NULL,
  build_id character(200),
);

CREATE TABLE THRESHOLD
(
  id serial PRIMARY KEY,
  test_id serial FOREIGN KEY(TEST), 
  from_build_id character(200),
  red float not null,
  yellow float not null
);

CREATE TABLE CONFIG
(
  setting character(200) UNIQUE,
  value int
)

-- BOOTSTRAP_PHASE = 3 