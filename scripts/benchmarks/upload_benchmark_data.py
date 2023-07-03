import datetime;
import google.auth
import google.auth.transport.requests
from google.cloud.sql.connector import Connector
from sqlalchemy import create_engine
from sqlalchemy.engine import Engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from google.cloud.sql.connector import Connector, IPTypes

credentials = service_account.Credentials.from_service_account_file(
        env('GOOGLE_APPLICATION_CREDENTIALS'), scopes=SCOPES)

def init_connection_pool(connector: Connector) -> Engine:

    def getconn() -> pg8000.connections.Connection:
        conn: pg8000.connections.Connection = connector.connect(
            "o1labs-192920:us-central1-c:snark-transaction-profiler",
            "pg8000",
            credentials=credentials,
            db="performance"
        )
        return conn

    SQLALCHEMY_DATABASE_URL = "postgresql+pg8000://"

    engine = create_engine(
        SQLALCHEMY_DATABASE_URL , creator=getconn
    )
    return engine

# initialize Cloud SQL Python Connector
connector = Connector()

# create connection pool engine
engine = init_connection_pool(connector)


inspector = inspect(engine)
print(inspector.get_columns('measurement'))


#name = ''
#env = 'CI'
#build_id = env('BUILDKITE_JOB_ID')


#('Snark Profiler','CI',1.00,'2019-07-10 08:25:59','01891b9b-cf69-400e-b6b6-8a08171cc373'),
#('Snark Profiler','CI',1.00,'2019-07-10 04:25:59','01891b9b-cf69-400e-b6b6-8a08171cc373'),
#('Snark Profiler','CI',20.00,'2017-07-10 04:55:59','01891b9b-cf69-400e-b6b6-8a08171cc373');

#insert = 


#now = datetime.now()
#dt_string = now.strftime("%d/%m/%Y %H:%M:%S")


#gcloud spanner databases execute-sql "example-db" \
#    --instance=test-instance
#     --sql=