DROP TABLE IF EXISTS BENCHMARKS;
DROP FUNCTION calculate_avg;

CREATE TABLE BENCHMARKS
(
  id serial PRIMARY KEY,
  test_id character(255) NOT NULL,
  env character(255) NOT NULL,
  value numeric(10,2) NOT NULL,
  timestamp timestamp without time zone NOT NULL,
  build_id character(200),
  average float
);

CREATE OR REPLACE FUNCTION calculate_avg() RETURNS TRIGGER AS $BODY$
  BEGIN
  NEW.average := ( SELECT (SUM(value) + NEW.value) / (COUNT(value) + 1)
                        FROM BENCHMARKS
                        WHERE test_id=NEW.test_id 
                        AND env = NEW.env);

  RETURN NEW;
  END;
  $BODY$
 LANGUAGE plpgsql;

CREATE TRIGGER calculate_avg_trigger  BEFORE INSERT OR UPDATE 
    ON BENCHMARKS FOR EACH ROW 
    EXECUTE PROCEDURE calculate_avg();