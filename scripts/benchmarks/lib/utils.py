import subprocess
import logging
from enum import Enum

logger = logging.getLogger(__name__)


def isclose(a, b, rel_tol=1e-09, abs_tol=0.0):
    return abs(a - b) <= max(rel_tol * max(abs(a), abs(b)), abs_tol)


def assert_cmd(cmd, envs=None):
    logger.debug(f"running command {cmd}")
    result = subprocess.run(cmd,
                            stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE,
                            env=envs)

    if result.returncode != 0:
        err = result.stderr.decode("UTF-8")
        logger.error(
            f"{cmd} resulted in errorcode {result.returncode} with message {err}"
        )
        raise RuntimeError(f"cmd failed: {cmd} with stderr: {err}")

    output = result.stdout.decode("UTF-8")
    logger.debug(f"command output: {output}")
    return output

class Range(object):

    def __init__(self, start, end):
        self.start = start
        self.end = end

    def __eq__(self, other):
        return self.start <= other <= self.end

    def __contains__(self, item):
        return self.__eq__(item)

    def __iter__(self):
        yield self

    def __str__(self):
        return '[{0},{1}]'.format(self.start, self.end)


class Format(Enum):
    csv = 'csv'
    text = 'text'

    def __str__(self):
        return self.value
