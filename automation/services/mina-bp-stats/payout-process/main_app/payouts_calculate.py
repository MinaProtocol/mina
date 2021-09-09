import pandas as pd
from psycopg2 import extras
import os
import json
import math
from google.cloud import storage
from payouts_config import BaseConfig
import psycopg2
from calculate_email import send_mail
from mail_to_foundation_acc import mail_to_foundation_accounts
from datetime import datetime, timezone, timedelta
from logger_util import logger
from itertools import groupby
import warnings
import sys

warnings.filterwarnings('ignore')

connection_archive = psycopg2.connect(
    host=BaseConfig.POSTGRES_ARCHIVE_HOST,
    port=BaseConfig.POSTGRES_ARCHIVE_PORT,
    database=BaseConfig.POSTGRES_ARCHIVE_DB,
    user=BaseConfig.POSTGRES_ARCHIVE_USER,
    password=BaseConfig.POSTGRES_ARCHIVE_PASSWORD
)
connection_payout = psycopg2.connect(
    host=BaseConfig.POSTGRES_PAYOUT_HOST,
    port=BaseConfig.POSTGRES_PAYOUT_PORT,
    database=BaseConfig.POSTGRES_PAYOUT_DB,
    user=BaseConfig.POSTGRES_PAYOUT_USER,
    password=BaseConfig.POSTGRES_PAYOUT_PASSWORD
)

ERROR = 'Error: {0}'


def get_gcs_client():
    os.environ['GOOGLE_APPLICATION_CREDENTIALS'] = BaseConfig.CREDENTIAL_PATH
    return storage.Client()



def read_staking_json_list():
    storage_client = get_gcs_client()
    bucket = storage_client.get_bucket(BaseConfig.GCS_BUCKET_NAME)
    staking_file_prefix = "staking-"
    blobs = storage_client.list_blobs(bucket, start_offset=staking_file_prefix)
    # convert to string
    file_dict_for_memory = dict()
    for blob in blobs:
        file_dict_for_memory[blob.name] = blob.updated
    sorted_list = [k for k, v in sorted(file_dict_for_memory.items(), key=lambda p: p[1], reverse=False)]
    recent_file = [list(i) for j, i in groupby(sorted_list, lambda a: a.split('-')[1])]
    recent_file = [recent[-1] for recent in recent_file]
    file_name_list_for_memory = [file for file in recent_file if str(file).endswith(".json")]
    return file_name_list_for_memory


def get_last_processed_epoch_from_audit():
    audit_query = '''select epoch_id from payout_audit_log where job_type='calculation' 
                    order by id desc limit 1'''
    last_epoch = 0
    try:
        cursor = connection_payout.cursor()
        cursor.execute(audit_query)
        if cursor.rowcount > 0:
            data_count = cursor.fetchall()
            last_epoch = int(data_count[-1][-1])
    except (Exception, psycopg2.DatabaseError) as error:
        logger.error(ERROR.format(error))
        cursor.close()
        return -1
    finally:
        cursor.close()
    return last_epoch

# determine whether process can run now for given epoch number
def can_run_job(next_epoch):
    next_epoch_end = (int(next_epoch+1) * 7140 * 3) + (100 * 3)
    next_job_time = BaseConfig.GENESIS_DATE + timedelta(minutes=next_epoch_end)
    next_job_time = next_job_time.replace(tzinfo=timezone.utc)
    next_job_time = next_job_time + timedelta(days=1)
    next_job_time= next_job_time.replace(hour=00, minute=30)
    current_time = datetime.now(timezone.utc)
    if next_job_time > current_time:
        result = False
    else:
        result = True
    return result

# this will check audit log table, and will determine last processed epoch
# if no entries found, default to first epoch
def initialize():
    result = 0
    last_epoch = get_last_processed_epoch_from_audit()
    if can_run_job(last_epoch+1) :
        result = main(last_epoch + 1, True)
    else:
        result = last_epoch 
    return result


# for epoch 0 & epoch 1 
#   - have to use same staking ledger 'staking-1'
#   - blocks produced would be for epoch 0 & epoch 1
#   - payment recieved would be for epoch 0 & epoch 1
def is_genesis_epoch(epoch_id):
    return True if int(epoch_id) <2 else False

def read_staking_json_for_epoch(epoch_id):
    storage_client = get_gcs_client()
    bucket = storage_client.get_bucket(BaseConfig.GCS_BUCKET_NAME)
    if is_genesis_epoch(epoch_id):
        staking_file_prefix = "staking-1"
    else:
        staking_file_prefix = "staking-" + str(epoch_id)
    blobs = storage_client.list_blobs(bucket, prefix=staking_file_prefix)
    # convert to string
    ledger_name = ''
    modified_staking_df = pd.DataFrame()
    file_to_read = read_staking_json_list()
    for blob in blobs:
        if blob.name in file_to_read:
            logger.info(blob.name)
            ledger_name = blob.name
            json_data_string = blob.download_as_string()
            json_data_dict = json.loads(json_data_string)
            staking_df = pd.DataFrame(json_data_dict)
            modified_staking_df = staking_df[['pk', 'balance', 'delegate']]
            modified_staking_df['pk'] = modified_staking_df['pk'].astype(str)
            modified_staking_df['balance'] = modified_staking_df['balance'].astype(float)
            modified_staking_df['delegate'] = modified_staking_df['delegate'].astype(str)
    return modified_staking_df, ledger_name


def read_foundation_accounts():
    foundation_account_df = pd.read_csv(BaseConfig.DELEGATION_ADDRESSS_CSV, header=None)
    foundation_account_df.columns = ['pk']
    return foundation_account_df


def insert_data(df, page_size=100):
    tuples = [tuple(x) for x in df.to_numpy()]
    query = '''INSERT INTO  payout_summary (provider_pub_key, winner_pub_key,blocks,payout_amount, 
     payout_balance) VALUES (%s, %s, %s, %s, %s) 
      ON CONFLICT (provider_pub_key,winner_pub_key) 
      DO UPDATE SET payout_amount = payout_summary.payout_amount + EXCLUDED.payout_amount, 
        blocks=EXCLUDED.blocks
      '''
    result = 0
    try:
        cursor = connection_payout.cursor()
        extras.execute_batch(cursor, query, tuples, page_size)
    except (Exception, psycopg2.DatabaseError) as error:
        logger.error(ERROR.format(error))
        connection_payout.rollback()
        cursor.close()
        result = -1
    finally:
        cursor.close()
    return result

def truncate(number, digits=5) -> float:
    stepper = 10.0 ** digits
    return math.trunc(stepper * number) / stepper

def calculate_payout(delegation_record_list, modified_staking_df, foundation_bpk, epoch_id):
    filter_stake_df = modified_staking_df[modified_staking_df['pk'] == foundation_bpk]
    # calculate provider delegates accounts
    delegate_bpk = filter_stake_df['delegate'].values[0]
    delegation_df = modified_staking_df[modified_staking_df['delegate'] == delegate_bpk]
    # total stake
    total_stake = delegation_df['balance'].sum()
    total_stake = truncate(total_stake, 5)

    delegation_record_dict = dict()
    delegation_record_dict['provider_pub_key'] = filter_stake_df['pk'].values[0]
    delegation_record_dict['winner_pub_key'] = filter_stake_df['delegate'].values[0]

    # provider delegation
    provider_delegation = filter_stake_df['balance'].values[0]

    # provider share
    provider_share = provider_delegation / total_stake

    # payout
    payout = (provider_share * 0.95) * BaseConfig.COINBASE

    # calculate blocks produced by delegate
    query = '''WITH RECURSIVE chain AS (
    (SELECT b.id, b.state_hash,parent_id, b.creator_id,b.height,b.global_slot_since_genesis/7140 AS epoch,b.staking_epoch_data_id FROM blocks b WHERE height = (select MAX(height) from blocks)
    ORDER BY timestamp ASC
    LIMIT 1)
    UNION ALL
    SELECT b.id, b.state_hash,b.parent_id, b.creator_id,b.height,b.global_slot_since_genesis/7140 AS epoch,b.staking_epoch_data_id FROM blocks b
    INNER JOIN chain
    ON b.id = chain.parent_id AND chain.id <> chain.parent_id
    ) SELECT count(distinct c.id) as blocks_produced, pk.value as creator
    FROM chain c INNER JOIN blocks_internal_commands bic  on c.id = bic.block_id
    INNER JOIN public_keys pk ON pk.id = c.creator_id
    WHERE pk.value= %s and epoch = %s
    GROUP BY pk.value;
    '''
    cursor = connection_archive.cursor()
    try:
        cursor.execute(query, (delegate_bpk, epoch_id))
        blocks_produced_list = cursor.fetchall()
    except (Exception, psycopg2.DatabaseError) as error:
        logger.error(ERROR.format(error))
        cursor.close()

    blocks_produced = 0
    if blocks_produced_list is not None and len(blocks_produced_list) > 0:
        blocks_produced = blocks_produced_list[0][0]
    delegation_record_dict['blocks'] = blocks_produced

    # calculate total payout
    total_payout = payout * blocks_produced
    total_payout = truncate(total_payout, 5)
    delegation_record_dict['payout_amount'] = total_payout
    delegation_record_dict['payout_balance'] = 0
    delegation_record_list.append(delegation_record_dict)
    delegation_record_df = pd.DataFrame(delegation_record_list)
    return delegation_record_df


def insert_into_audit_table(file_name):
    timestamp = datetime.now(timezone.utc)
    values = timestamp, file_name.split('-')[1], file_name, 'calculation'
    insert_audit_sql = """INSERT INTO payout_audit_log (updated_at, epoch_id, ledger_file_name,job_type) 
        values(%s, %s, %s, %s ) """
    try:
        cursor = connection_payout.cursor()
        cursor.execute(insert_audit_sql, values)
        connection_payout.commit()
    except (Exception, psycopg2.DatabaseError) as error:
        logger.error(ERROR.format(error))
        connection_payout.rollback()
        cursor.close()
    finally:
        cursor.close()
        connection_payout.commit()


def main(epoch_no, do_send_email):
    logger.info("### in payouts_calculate main for epoch {0}".format(epoch_no))
    result = 0
    # get staking json
    modified_staking_df, ledger_name = read_staking_json_for_epoch(epoch_no)
    # TODO : add condition if no file/dataframe found
    #insert_into_staking_ledger(modified_staking_df, epoch_no)
    # get foundation account details
    if not modified_staking_df.empty:
        foundation_accounts_df = read_foundation_accounts()
        foundation_accounts_list = foundation_accounts_df['pk'].to_list()
        i = 0
        delegate_record_df = pd.DataFrame()
        delegation_record_list = list()
        for accounts in foundation_accounts_list:
            delegate_record_df = calculate_payout(delegation_record_list, modified_staking_df, accounts, epoch_no)
            i = i + 1
        result = insert_data(delegate_record_df)
        csv_name=BaseConfig.LOGGING_LOCATION+ 'calculate_summary_'+str(epoch_no)+'.csv'
        delegate_record_df.to_csv(csv_name)
        if result == 0:
            insert_into_audit_table(ledger_name)
        logger.info('payouts_calculate complete records for {0}'.format(i))
        # sending emails after payouts calculation completed
        result = epoch_no
        if do_send_email:
            send_mail(epoch_no, delegate_record_df)
            # send email to provider with list of 0 block producers
            zero_block_producers = delegate_record_df[delegate_record_df['blocks'] == 0]
            zero_block_producers = zero_block_producers[['winner_pub_key']]
            mail_to_foundation_accounts(zero_block_producers, epoch_no)
    else:
        logger.warn("Staking ledger not found for epoch number {0}".format(epoch_no))
    return result


if __name__ == "__main__":
    epoch_no = initialize()
    if epoch_no is not None:
        sys.exit(epoch_no)
    else:
        sys.exit(-1)
