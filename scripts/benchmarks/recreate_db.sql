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
  value numeric(10,2) NOT NULL,
  timestamp timestamp without time zone NOT NULL,
  build_id character(200),
  CONSTRAINT fk_test
    FOREIGN KEY(test_id) 
	    REFERENCES TEST(id)
);

CREATE TABLE THRESHOLD
(
  id serial PRIMARY KEY,
  from_build_id character(200),
  red float not null,
  yellow float not null,
  comment character(200),
  CONSTRAINT fk_test
    FOREIGN KEY(test_id) 
	    REFERENCES TEST(id)
);

CREATE TABLE CONFIG
(
  setting character(200) UNIQUE,
  value int
)

-- BOOTSTRAP_PHASE = 3 