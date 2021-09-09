import logging
from payouts_config import BaseConfig
from logging.handlers import RotatingFileHandler

log_file = BaseConfig.LOGGING_LOCATION + 'payout.log'
logging.basicConfig(
        handlers=[RotatingFileHandler(filename=log_file, maxBytes=52428800, backupCount=10)],
        format="[%(asctime)s] %(levelname)s [%(module)s.%(funcName)s:%(lineno)d] %(message)s",
        datefmt='%Y-%m-%dT%H:%M:%S')
# Creating an object
logger = logging.getLogger()
# Setting the threshold of logger to DEBUG
logger.setLevel(logging.INFO)

