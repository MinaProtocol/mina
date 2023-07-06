from google.cloud.sql.connector import Connector
import google.auth
import sqlalchemy
import os
from datetime import datetime
from collections import namedtuple
from sqlalchemy.orm import sessionmaker
from sqlalchemy.orm import DeclarativeBase
from sqlalchemy.orm import mapped_column
from typing import List
from typing import Optional
from sqlalchemy import ForeignKey
from sqlalchemy import String
from sqlalchemy.orm import DeclarativeBase
from sqlalchemy.orm import Mapped
from sqlalchemy.orm import mapped_column
from sqlalchemy import DateTime
from sqlalchemy import Numeric
from sqlalchemy import Float
import statistics


grace_value = .2 # in percentage

class Base(DeclarativeBase):
    pass

class Test(Base):
    __tablename__ = "test"
    
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    suite: Mapped[str] = mapped_column(String(255))
    test: Mapped[str] = mapped_column(String(255))
    env: Mapped[str] = mapped_column(String(255))
    benchmarks: Mapped[List["benchmark"]] = relationship(back_populates="test")
    thresholds: Mapped[List["threshold"]] = relationship(back_populates="test")

    def __repr__(self):
        return "<Measurement(suite='%s', test='%s', env='%s')>" % (
            self.suite,
            self.test,
            self.env,
        )

class Benchmark(Base):
    __tablename__ = "benchmark"
    
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    test_id: Mapped[int] = mapped_column(ForeignKey("test.id"))
    test: Mapped["Test"] = relationship(back_populates="benchmarks")
    build_id: Mapped[str] = mapped_column(String(255))
    timestamp: Mapped[datetime]  = mapped_column(DateTime(timezone=False))
    value: Mapped[float] = mapped_column(Numeric(10,2))

    def __repr__(self):
        return "<Measurement(suite='%s', test_id='%s', env='%s', build_id='%s', timestamp='%s', value='%s')>" % (
            self.suite,
            self.test_id,
            self.env,
            self.build_id,
            self.timestamp,
            self.value
        )

class Threshold(Base):
    __tablename__ = "threshold"
    
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    test_id: Mapped[int] = mapped_column(ForeignKey("test.id"))
    test: Mapped["Test"] = relationship(back_populates="thresholds")
    suite: Mapped[str] = mapped_column(String(255))
    test_id: Mapped[str] = mapped_column(String(255))
    env: Mapped[str] = mapped_column(String(255))
    build_id: Mapped[str] = mapped_column(String(255))
    timestamp: Mapped[datetime]  = mapped_column(DateTime(timezone=False))
    value: Mapped[float] = mapped_column(Numeric(10,2))

    def __repr__(self):
        return "<Measurement(suite='%s', test_id='%s', env='%s', build_id='%s', timestamp='%s', value='%s')>" % (
            self.suite,
            self.test_id,
            self.env,
            self.build_id,
            self.timestamp,
            self.value
        )

class Config(Base):
    __tablename__ = "config"
    
    setting: Mapped[str] = mapped_column(primary_key=True)
    value: Mapped[int] = mapped_column(String(255))

    def __repr__(self):
        return "<Config(setting='%s', value='%s')>" % (
            self.setting,
            self.value
        )



class BenchmarkDb:

    def __init__(self):
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
        self.pool = sqlalchemy.create_engine(
            "postgresql+pg8000://",
            creator=getconn,
        )

    def upload_benchmark_data(self,measurements: [Measurement]):
        Session = sessionmaker(bind=self.pool)

        with Session.begin() as session:
            session.add_all(measurements)
            session.flush()

    def check_measurements(self,build_id):
        Session = sessionmaker(bind=self.pool)

        bads = []

        with Session.begin() as session:
            for measurement in session.query(Measurement).filter(Measurement.build_id == build_id):
                history = session.query(Measurement).filter(
                    Measurement.suite == measurement.suite and 
                    Measurement.test_id == measurement.test_id and
                    Measurement.env == measurement.env
                )

                if history.count() < 3:
                    continue

                historic_values = map(lambda m: m.value,history)
                mean = statistics.fmean(historic_values)
                threshold = mean + mean * grace_value

                if measurement.value > threshold:
                    bads.append((measurement,threshold))
        return bads   

     

            