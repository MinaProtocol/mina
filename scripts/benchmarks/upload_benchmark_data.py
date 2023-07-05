from google.cloud.sql.connector import Connector
import google.auth
import sqlalchemy
import os
from datetime import datetime

credentials, project_id = google.auth.default()
#connector = Connector(credentials=credentials,enable_iam_auth=True)

# initialize Connector object
connector = Connector()

# function to return the database connection object
def getconn():
    conn = connector.connect(
        instance_connection_string="o1labs-192920:us-central1:snark-transaction-profiler",
        driver="pg8000",
        db="performance",
        user="postgres",
        password="postgres"
 #   user="automated-validation@o1labs-192920.iam.gserviceaccount.com"
    )
    return conn

# create connection pool with 'creator' argument to our connection object function
pool = sqlalchemy.create_engine(
    "postgresql+pg8000://",
    creator=getconn,
)

name = 'Snark Profiler'
env = 'CI'
build_id = os.environ['BUILDKITE_JOB_ID']
now = datetime.now()
dt_string = now.strftime("%d/%m/%Y %H:%M:%S")

# connect to connection pool
with pool.connect() as db_conn:

  # insert data into our ratings table
  insert_stmt = sqlalchemy.text(
      "INSERT INTO measurement (test_id, env, value, timestamp, build_id) VALUES (:test_id, :env, :value, :timestamp, :build_id)",
  )

  # insert entries into table
  db_conn.execute(insert_stmt, parameters={"test_id": name, "env": env, "value": 7.5, "timestamp": dt_string, "build_id": build_id })
  db_conn.execute(insert_stmt, parameters={"test_id": name, "env": env, "value": 9.1, "timestamp": dt_string, "build_id": build_id })
  db_conn.execute(insert_stmt, parameters={"test_id": name, "env": env, "value": 8.3, "timestamp": dt_string, "build_id": build_id })

  # commit transactions
  db_conn.commit()

  # query and fetch ratings table
  results = db_conn.execute(sqlalchemy.text("SELECT * FROM measurement")).fetchall()

  # show results
  for row in results:
    print(row)