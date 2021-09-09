import pandas as pd
import psycopg2
from google.cloud import storage
import os
import json
from payouts_config import BaseConfig
from datetime import datetime, timezone, timedelta
import math
import sys
from validate_email import second_mail
from logger_util import logger
from payout_summary_mail import payout_summary_mail
import warnings

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


def read_delegation_record_table(epoch_no):
    cursor = connection_payout.cursor()
    query = 'select * from payout_summary  '
    try:
        cursor.execute(query, str(epoch_no))
        delegation_record_list = cursor.fetchall()
        delegation_record_df = pd.DataFrame(delegation_record_list,
                                            columns=['provider_pub_key', 'winner_pub_key', 'blocks', 'payout_amount',
                                                     'payout_balance', 'last_delegation_epoch', 'last_slot_validated'])

    except (Exception, psycopg2.DatabaseError) as error:
        logger.error(ERROR.format(error))
        cursor.close()

    return delegation_record_df


def get_gcs_client():
    os.environ['GOOGLE_APPLICATION_CREDENTIALS'] = BaseConfig.CREDENTIAL_PATH
    return storage.Client()


def read_staking_json(epoch_no):
    modified_staking_df = pd.DataFrame()
    storage_client = get_gcs_client()
    # get bucket with name
    bucket = storage_client.get_bucket(BaseConfig.GCS_BUCKET_NAME)
    if is_genesis_epoch(epoch_no):
        staking_file_prefix = "staking-1-" # use first ledger, filter out 10,11,12 and so on ..
    else:
        staking_file_prefix = "staking-" + str(epoch_no)
    blobs = storage_client.list_blobs(bucket, prefix=staking_file_prefix)
    # convert to string
    file_dict_for_memory = dict()
    for blob in blobs:
        file_dict_for_memory[blob.name] = blob.updated

    sorted_list = [k for k, v in sorted(file_dict_for_memory.items(), key=lambda p: p[1], reverse=False)]
    recent_file = sorted_list[-1] 
    blobs = storage_client.list_blobs(bucket, prefix=recent_file)
    for blob in blobs:
        logger.info(blob.name)
        json_data_string = blob.download_as_string()
        json_data_dict = json.loads(json_data_string)
        staking_df = pd.json_normalize(json_data_dict)
        modified_staking_df = staking_df[['pk', 'balance', 'delegate']]
        modified_staking_df['pk'] = modified_staking_df['pk'].astype(str)
        modified_staking_df['balance'] = modified_staking_df['balance'].astype(float)
        modified_staking_df['delegate'] = modified_staking_df['delegate'].astype(str)
    return modified_staking_df


def determine_slot_range_for_validation(epoch_no, last_slot_validated):
    # find entry from summary table for matching winner+provider pub key
    # check last_delegation_epoch
    #  - when NULL           : start = epoch_no-1 * 7140, end = ((epoch_no+1)*7140) +3500
    #  - when < (epoch_no-1) : start = (last_delegation_epoch * 7140)+3500, end = ((epoch_no+1)*7140) +3500
    #  - when == epoch_no    : start = epoch * 7140, end = ((epoch+1)*7140) +3500

    # then fetch the payout transactions for above period for each winner+provider pub key combination
    
    end_slot = ((epoch_no+1) * 7140) + 3500 - 1
    
    if last_slot_validated is not None :
        start_slot = last_slot_validated +1
    else:
        start_slot = 0
    return start_slot, end_slot


def get_record_for_validation(epoch_no):
    cursor = connection_archive.cursor()
    query = '''WITH RECURSIVE chain AS (
    (SELECT b.id, b.state_hash,parent_id, b.creator_id,b.height,b.global_slot_since_genesis,b.global_slot_since_genesis/7140 as epoch,b.staking_epoch_data_id
    FROM blocks b WHERE height = (select MAX(height) from blocks)
    ORDER BY timestamp ASC
    LIMIT 1)
    UNION ALL
    SELECT b.id, b.state_hash,b.parent_id, b.creator_id,b.height,b.global_slot_since_genesis,b.global_slot_since_genesis/7140 as epoch,b.staking_epoch_data_id
    FROM blocks b
    INNER JOIN chain ON b.id = chain.parent_id AND chain.id <> chain.parent_id
    ) SELECT  sum(amount)/power(10,9) as total_pay, pk.value as creator ,epoch
    FROM chain c INNER JOIN blocks_user_commands AS buc on c.id = buc.block_id
    inner join (SELECT * FROM user_commands where type='payment' ) AS uc on
     uc.id = buc.user_command_id and status <>'failed'
    INNER JOIN public_keys as PK ON PK.id = uc.receiver_id 
    GROUP BY pk.value, epoch'''

    try:
        cursor.execute(query)
        validation_record_list = cursor.fetchall()
        validation_record_df = pd.DataFrame(validation_record_list,
                                            columns=['total_pay', 'provider_pub_key', 'epoch'])
    except (Exception, psycopg2.DatabaseError) as error:
        logger.error(ERROR.format(error))
        cursor.close()

    return validation_record_df


def get_record_for_validation_for_single_acc(provider_key, start_slot, end_slot):
    cursor = connection_archive.cursor()
    query = '''WITH RECURSIVE chain AS ( (SELECT b.id, b.state_hash,parent_id, b.creator_id,b.height, 
    b.global_slot_since_genesis,b.global_slot_since_genesis/7140 as epoch,b.staking_epoch_data_id FROM blocks b WHERE 
    height = (select MAX(height) from blocks) ORDER BY timestamp ASC LIMIT 1) 
    UNION ALL SELECT b.id, b.state_hash, 
    b.parent_id, b.creator_id,b.height,b.global_slot_since_genesis,b.global_slot_since_genesis/7140 as epoch, 
    b.staking_epoch_data_id FROM blocks b INNER JOIN chain ON b.id = chain.parent_id AND chain.id <> chain.parent_id 
    ) , whitelist as 
    ( SELECT amount, uc.receiver_id FROM chain c INNER JOIN blocks_user_commands AS buc on c.id = 
    buc.block_id inner join (SELECT * FROM user_commands where type='payment' ) AS uc on uc.id = buc.user_command_id 
    and status <>'failed' Join public_keys as sk on uc.source_id=sk.id where  sk.value not in (select public_key from 
    whitelist_records wr) and global_slot_since_genesis   BETWEEN %s   and %s ) 
    SELECT sum(amount)/power(10,9) as total_pay, pk.value as creator FROM whitelist c INNER JOIN public_keys as PK ON PK.id = c.receiver_id where 
    pk.value = %s GROUP BY pk.value'''

    try:
        cursor.execute(query, (start_slot, end_slot, provider_key))
        validation_record_list = cursor.fetchall()
        validation_record_df = pd.DataFrame(validation_record_list,
                                            columns=['total_pay', 'provider_pub_key'])
    except (Exception, psycopg2.DatabaseError) as error:
        logger.error(ERROR.format(error))
        cursor.close()

    return validation_record_df


def insert_into_audit_table(epoch_no):
    timestamp = datetime.now(timezone.utc)
    values = timestamp, epoch_no, 'validation'
    insert_audit_sql = """INSERT INTO payout_audit_log (updated_at, epoch_id,job_type) 
        values(%s, %s, %s ) """
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

# make sure DB restore is done before validation process
def check_db_restore_status(epoch_no):
    max_blocks = 0
    end_slot = ((epoch_no+1) * 7140) + 3500 - 1
    result = -1
    query = "select max(global_slot_since_genesis) from blocks"
    cursor = connection_archive.cursor()
    try:
        cursor.execute(query)
        data = cursor.fetchall()
        max_blocks = int(data[-1][-1])
    except (Exception, psycopg2.DatabaseError) as error:
        logger.error("Error: {0} ".format(error))
        cursor.close()
    if not end_slot > max_blocks:
        result = 1
    return result


def truncate(number, digits=5) -> float:
    stepper = 10.0 ** digits
    return math.trunc(stepper * number) / stepper


def main(epoch_no, do_send_email):
    result = 0
    logger.info("###### in payout_validation main for epoch: {0}".format(epoch_no))
    delegation_record_df = read_delegation_record_table(epoch_no=epoch_no)
    validation_record_df = get_record_for_validation(epoch_no=epoch_no)
    staking_df = read_staking_json(epoch_no=epoch_no)
    result = check_db_restore_status(epoch_no)
    if not staking_df.empty and result >=0:
        email_rows = []
        payouts_rows = []
        for row in delegation_record_df.itertuples():
            pub_key = getattr(row, "provider_pub_key")
            payout_amount = getattr(row, "payout_amount")
            payout_balance = getattr(row, "payout_balance")
            last_delegation_epoch = getattr(row, 'last_delegation_epoch')
            delegate_pub_key = getattr(row, 'winner_pub_key')
            last_slot_validated = getattr(row, 'last_slot_validated')
            filter_validation_record_df = validation_record_df.loc[validation_record_df['provider_pub_key'] == pub_key]

            if not filter_validation_record_df.empty:
                start_slot, end_slot = determine_slot_range_for_validation(epoch_no, last_slot_validated)
                payout_recieved = get_record_for_validation_for_single_acc(pub_key, start_slot, end_slot)
                total_pay_received = 0
                balance_this_epoch = 0
                if not payout_recieved.empty:
                    total_pay_received = truncate(payout_recieved.iloc[0]['total_pay'],5)
                    balance_this_epoch = payout_amount - total_pay_received
                else:
                    balance_this_epoch = payout_amount
                balance_this_epoch = truncate(balance_this_epoch, 5)    
                new_payout_balance = truncate((payout_amount + payout_balance) - total_pay_received)
                filter_staking_df = staking_df.loc[staking_df['pk'] == pub_key, 'delegate']
                winner_pub_key = filter_staking_df.iloc[0]
                email_rows.append([pub_key, winner_pub_key, payout_amount, total_pay_received])
                payouts_rows.append(
                    [pub_key, winner_pub_key, payout_amount, total_pay_received, balance_this_epoch, new_payout_balance, epoch_no, start_slot, end_slot])
                winner_match = False
                if delegate_pub_key == winner_pub_key:
                    winner_match = True
                logger.debug(
                    '{0} {1} {2} {3} {4} {5} {6} {7}'.format(winner_match, pub_key, delegate_pub_key, winner_pub_key,
                                                             start_slot, end_slot,
                                                             total_pay_received,
                                                             new_payout_balance))

                # update record in payout summary
                query = ''' UPDATE payout_summary SET payout_amount = 0, payout_balance = %s,
                last_delegation_epoch = %s, last_slot_validated = %s
                WHERE provider_pub_key = %s and winner_pub_key = %s
                '''
                try:
                    cursor = connection_payout.cursor()
                    cursor.execute(query, (new_payout_balance, epoch_no, end_slot, pub_key, winner_pub_key))
                except (Exception, psycopg2.DatabaseError) as error:
                    logger.error("Error: {0} ", format(error))
                    connection_payout.rollback()
                    cursor.close()
                    result = -1
                finally:
                    cursor.close()
            else:
                logger.warning("No records found in archive db for pub key: {0}".format(pub_key))
        insert_into_audit_table(epoch_no)
        # sending second mail 24 hours left for making payments back to foundations account
        result = epoch_no
        if do_send_email:
            email_df = pd.DataFrame(email_rows, columns=["provider_pub_key", "winner_pub_key", "payout_amount", "payout_received"])
            second_mail(email_df, epoch_no)

            payout_summary_df = pd.DataFrame(payouts_rows,
                                             columns=['provider_pub_key', 'winner_pub_key', 'payout_amount',
                                                      'payout_received', 'balance_this_epoch', 'payout_balance', 'epoch_no', 'start_slot', 'end_slot']) 
            payout_summary_df = payout_summary_df.rename(columns={'payout_amount': 'payout_obligation', 'payout_balance': 'balance_cumulative'})
            payout_summary_mail(payout_summary_df, epoch_no)
    else:
        logger.warning("Staking ledger not found or archive db not updated for epoch number {0}".format(epoch_no))
        sys.exit(-1)
    return result


def get_last_processed_epoch_from_audit(job_type):
    audit_query = '''select epoch_id from payout_audit_log where job_type=%s 
                    order by id desc limit 1'''
    last_epoch = 0
    values = job_type,
    try:
        cursor = connection_payout.cursor()
        cursor.execute(audit_query, values)
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

# for epoch 0 & epoch 1 
#   - have to use same staking ledger 'staking-1'
#   - blocks produced would be for epoch 0 & epoch 1
#   - payment recieved would be for epoch 0 & epoch 1
def is_genesis_epoch(epoch_id):
    return True if epoch_id<2 else False

# this will check audit log table, and will determine last processed epoch
# if no entries found, default to first epoch
def initialize():
    result = 0
    last_epoch = get_last_processed_epoch_from_audit('validation')
    logger.info(last_epoch)
    if can_run_job(last_epoch+1):
        logger.info(" validation Audit found for epoch {0}".format(last_epoch))
        result = main(last_epoch + 1, True)
    else:
        result = last_epoch 
    return result

# determine whether process can run now for given epoch number
def can_run_job(next_epoch):
    next_epoch_end = (int(next_epoch+1) * 7140 * 3) + (3500 * 3)
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

if __name__ == "__main__":
    epoch_no = initialize()
    if epoch_no is not None:
        sys.exit(epoch_no)
    else:
        sys.exit(-1)
