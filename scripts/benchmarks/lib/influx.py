import logging
import os
import subprocess
import time
from pathlib import Path

import influxdb_client

logger = logging.getLogger(__name__)


class HeaderColumn:
    """
        Specialized column class for influx upload.
        It accepts influx_kind [string,double,tag..] and pos which helps find it in csv when parsing
    """

    def __init__(self, name, influx_kind, pos):
        self.name = name
        self.influx_kind = influx_kind
        self.pos = pos


class MeasurementColumn(HeaderColumn):
    """
        Column header which represents influx measurement header
    """

    def __init__(self, name, pos):
        HeaderColumn.__init__(self, name, influx_kind="measurement", pos=pos)


class FieldColumn(HeaderColumn):
    """
        Column header which represents influx field header.
        It has additional unit field which can be formatted as part of name
        Currently field is always a double (there was no need so far for different type)
    """

    def __init__(self, name, pos, unit=None):
        HeaderColumn.__init__(self, name, influx_kind="double", pos=pos)
        self.unit = unit

    def __str__(self):
        if self.unit:
            return f"{self.name} [{self.unit}]"
        else:
            return f"{self.name}"

    def format_unit(self):
        return f"[{self.unit}]"


class TagColumn(HeaderColumn):
    """
        Specialized header for inglux tag
    """

    def __init__(self, name, pos):
        HeaderColumn.__init__(self, name, influx_kind="tag", pos=pos)


class Influx:
    """
        Influx helper which wraps influx cli and python api
        It requires INFLUX_* env vars to be set
        and raises RuntimeException if they are not defined
    """

    host = "INFLUX_HOST"
    token = "INFLUX_TOKEN"
    org = "INFLUX_ORG"
    bucket = "INFLUX_BUCKET_NAME"

    @staticmethod
    def check_envs():
        if Influx.host not in os.environ:
            raise RuntimeError(f"{Influx.host} env var not defined")
        if Influx.token not in os.environ:
            raise RuntimeError(f"{Influx.token} env var not defined")
        if Influx.org not in os.environ:
            raise RuntimeError(f"{Influx.org} env var not defined")
        if Influx.bucket not in os.environ:
            raise RuntimeError(f"{Influx.bucket} env var not defined")

    def __init__(self, moving_average_size=10):
        Influx.check_envs()
        self.client = influxdb_client.InfluxDBClient(
            url=os.environ[Influx.host],
            token=os.environ[Influx.token],
            org=os.environ[Influx.org],
            bucket=os.environ[Influx.bucket])
        self.moving_average_size = moving_average_size

    def __get_moving_average_query(self, name, branch, field, branch_header):
        """
            Constructs moving average query from influx for comparison purposes
        """

        bucket = os.environ[Influx.bucket]
        return f"from(bucket: \"{bucket}\") \
                |>  range(start: -10d)   \
                |> filter (fn: (r) => (r[\"{branch_header.name}\"] == \"{branch}\" ) \
                                       and r._measurement == \"{name}\"   \
                                       and r._field == \"{field}\" ) \
                |> keep(columns: [\"_value\"]) \
                |> movingAverage(n:{self.moving_average_size}) "

    def query_moving_average(self, name, branch, field, branch_header):
        """
            Retrieves moving average from influx db for particular
            branch and field
        """

        query = self.__get_moving_average_query(name, branch, field,
                                                branch_header)
        logger.debug(f"running influx query: {query}")
        query_api = self.client.query_api()
        return query_api.query(query)

    def upload_csv(self, file):
        """
            Uploads csv to influx db. File need to be formatter according to influx requirements:
            https://docs.influxdata.com/influxdb/cloud/reference/syntax/annotated-csv/

            WARNING: InfluxDb write api is not very friendly with csv which contains more than measurement
            in csv file (which is our case). I decided to use influx cli as it supports multiple measurements in
            single csv file.
            Unfortunately influx cli has nasty issue when calling from python similar to:
            (similar to hanging queries problem: https://community.influxdata.com/t/influxdb-hanging-queries/1522).
            My workaround is to use --http-debug flag, then read output of command and if there is 204 status code
            returned i kill influx cli
        """

        if not Path(file).is_file():
            raise RuntimeError(f"cannot find {file}")

        if not open(file).readline().rstrip().startswith("#datatype"):
            raise RuntimeError(
                f"{file} is badly formatted and not eligible for uploading to influx db. "
                f"see more at https://docs.influxdata.com/influxdb/cloud/reference/syntax/annotated-csv/"
            )

        process = subprocess.Popen([
            "influx", "write", "--http-debug", "--format=csv", f"--file={file}"
        ],
            stderr=subprocess.PIPE)

        timeout = time.time() + 60  # 1  minute
        while True:
            line = process.stderr.readline()
            if b"HTTP/2.0 204 No Content" in line or time.time() > timeout:
                process.kill()
                break

        logger.info(f"{file} uploaded to influx db")
