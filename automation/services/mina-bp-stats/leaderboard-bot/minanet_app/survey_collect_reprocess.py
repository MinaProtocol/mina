import os
from datetime import datetime, timedelta, timezone
from time import time
import json
import numpy as np
from logger_util import logger
from config import BaseConfig
from google.cloud import storage
from download_batch_files import download_batch_into_memory
import requests
import io
import psycopg2
import psycopg2.extras as extras
import gspread
import pandas as pd
from oauth2client.service_account import ServiceAccountCredentials

connection = psycopg2.connect(
    host=BaseConfig.NEW_POSTGRES_HOST,
    port=BaseConfig.NEW_POSTGRES_PORT,
    database=BaseConfig.NEW_POSTGRES_DB,
    user=BaseConfig.NEW_POSTGRES_USER,
    password=BaseConfig.NEW_POSTGRES_PASSWORD
)

conn_uptime_files = psycopg2.connect(
    host=BaseConfig.POSTGRES_HOST,
    port=BaseConfig.POSTGRES_PORT,
    database=BaseConfig.POSTGRES_DB,
    user=BaseConfig.POSTGRES_USER,
    password=BaseConfig.POSTGRES_PASSWORD
)


start_time = time()
NODE_DATA_BLOCK_HEIGHT = 'nodeData.blockHeight'
NODE_DATA_BLOCK_STATE_HASH = 'nodeData.block.stateHash'
ERROR = 'Error: {0}'


def execute_node_record_batch(conn, df, page_size=100):

    tuples = [tuple(x) for x in df.to_numpy()]
    query = """INSERT INTO node_record_table ( block_producer_key,updated_at) 
            VALUES ( %s,  %s ) ON CONFLICT (block_producer_key) DO NOTHING """
    cursor = conn.cursor()
    try:

        extras.execute_batch(cursor, query, tuples, page_size)
        logger.info('insert into node record table')
    except (Exception, psycopg2.DatabaseError) as error:
        logger.error(ERROR.format(error))
        cursor.close()
        raise error
    finally:
        conn.commit()
        cursor.close()
    return 0


def execute_point_record_batch(conn, df, page_size=100):

    tuples = [tuple(x) for x in df.to_numpy()]
    query = """INSERT INTO point_record_table ( file_name,file_timestamps,blockchain_epoch, node_id, state_hash,blockchain_height,
                amount,created_at,bot_log_id) 
            VALUES ( %s, %s,  %s, (SELECT id FROM node_record_table WHERE block_producer_key= %s), %s, %s, %s,  %s, %s )"""
    try:
        cursor = conn.cursor()
        extras.execute_batch(cursor, query, tuples, page_size)
    except (Exception, psycopg2.DatabaseError) as error:
        logger.error(ERROR.format(error))
        cursor.close()
        raise error
    finally:
        cursor.close()
    return 0


def create_bot_log(conn, values):
    query = """INSERT INTO bot_log_record_table(name_of_file,epoch_time,files_processed,file_timestamps,
    batch_start_epoch,batch_end_epoch) values (%s,%s, %s, %s, %s, %s) RETURNING id """
    try:
        cursor = conn.cursor()
        cursor.execute(query, values)
        result = cursor.fetchone()
        logger.info("insert into bot log record table")
    except (Exception, psycopg2.DatabaseError) as error:
        logger.error(ERROR.format(error))
        conn.rollback()
        cursor.close()
        return -1
    finally:
        cursor.close()
    return result[0]


def connect_to_spreadsheet():
    os.environ["PYTHONIOENCODING"] = "utf-8"
    creds = ServiceAccountCredentials.from_json_keyfile_name(BaseConfig.SPREADSHEET_JSON, BaseConfig.SPREADSHEET_SCOPE)
    client = gspread.authorize(creds)
    sheet = client.open(BaseConfig.SPREADSHEET_NAME)
    sheet_instance = sheet.get_worksheet(0)
    records_data = sheet_instance.get_all_records()
    table_data = pd.DataFrame(records_data)
    return table_data


def get_provider_accounts():
    # read csv
    mina_foundation_df = pd.read_csv(BaseConfig.PROVIDER_ACCOUNT_PUB_KEYS_FILE)
    mina_foundation_df.columns = ['block_producer_key']
    return mina_foundation_df


def update_scoreboard(conn):
    sql = """with score as ( select node_id,count(distinct bot_log_id) total from  point_record_table  prt where
     file_timestamps > current_date - interval '%s' day group by 
    node_id ) update node_record_table nrt set score = total from score s where nrt.id=s.node_id """
    try:
        cursor = conn.cursor()
        cursor.execute(sql, (BaseConfig.UPTIME_DAYS_FOR_SCORE,))
    
    except (Exception, psycopg2.DatabaseError) as error:
        logger.error(ERROR.format(error))
        cursor.close()
        return -1
    finally:
        cursor.close()
    return 0


def update_score_percent(conn):
    # to calculate percentage, first find the number of survey_intervals.
    # the number of rows in blot_log represent number of time survey performed.
    count_query = """select count(1) +1  from bot_log_record_table where file_timestamps > current_date - interval 
    '%s' day """

    sql = """update node_record_table set score_percent = (score / %s ) * %s """
    try:
        cursor = conn.cursor()
        cursor.execute(count_query, (BaseConfig.UPTIME_DAYS_FOR_SCORE,))
        data_count = cursor.fetchall()
        data_count = float(data_count[-1][-1])
        percent = 100
        cursor.execute(sql, (data_count, percent))
    
    except (Exception, psycopg2.DatabaseError) as error:
        logger.error(ERROR.format(error))
        cursor.close()
        return -1
    finally:
        cursor.close()
    return 0

def get_uptime_data_from_table( batch_start, batch_end):
    # file_name, file_timestamps, blockchain_epoch, node_id, state_hash,blockchain_height, amount,created_at,bot_log_id
    query = """select file_name,file_created_at file_timestamps , receivedat receivedAt, blockproducerkey , nodedata_block_statehash , nodedata_blockheight  
        from uptime_file_history ufh where file_created_at between %s and %s """
    try:
        bot_cursor = conn_uptime_files.cursor()
        bot_cursor.execute(query, (batch_start, batch_end))
        result = bot_cursor.fetchall()
        batch_data_df = pd.DataFrame(result, columns=['file_name' , 'file_timestamps', 'receivedAt', 'blockproducerkey' , 'nodedata_block_statehash' , 'nodedata_blockheight'])
        
    except (Exception, psycopg2.DatabaseError) as error:
        logger.error(ERROR.format(error))
    finally:
        bot_cursor.close()
    return batch_data_df

def gcs_main(read_file_interval):
    process_loop_count = 0
    bot_cursor = connection.cursor()
    bot_cursor.execute("SELECT batch_end_epoch FROM bot_log_record_table ORDER BY id DESC limit 1")
    result = bot_cursor.fetchone()
    batch_end_epoch = result[0]
    script_start_time = datetime.fromtimestamp(batch_end_epoch, timezone.utc)
    script_end_time = datetime.now(timezone.utc)
    # read the mina foundation accounts
    foundation_df = get_provider_accounts()
    while script_start_time != script_end_time:
        # get 10 min time for fetching the files
        script_start_epoch = str(script_start_time.timestamp())

        ten_min_add = script_start_time + timedelta(minutes=read_file_interval)
        next_interval_epoch = str(ten_min_add.timestamp())

        # common str for offset
        script_start_time_final = str(script_start_time.date()) + '.' + str(script_start_time.timestamp())
        ten_min_add_final = str(ten_min_add.date()) + '.' + str(ten_min_add.timestamp())
        logger.info('runing for batch: {0} - {1}'.format(script_start_time_final,ten_min_add_final))
    

        # change format for comparison
        script_end_time_var = datetime.strftime(script_end_time, '%Y-%m-%d %H:%M:%S')
        ten_min_add_time_var = datetime.strftime(ten_min_add, '%Y-%m-%d %H:%M:%S')
        if ten_min_add_time_var > script_end_time_var:
            logger.info('all files are processed till date')
            break
        else:
            
            # processing code logic
            master_df = get_uptime_data_from_table( script_start_time, ten_min_add)

            #master_df = master_df.rename(columns={'file_created_at': 'file_timestamps'})
            all_file_count = master_df.shape[0]

            # remove the Mina foundation account from the master_df
            master_df = master_df[~master_df['blockproducerkey'].isin(foundation_df['block_producer_key'])]

            # Filter duplicate entries keyed on (block-producer-pubkey+state_hash)
            unique_statehash_df = master_df.drop_duplicates(['blockproducerkey', 'nodedata_block_statehash'])

            # Find the most common state hash in unique_statehash
            most_common_statehash = unique_statehash_df['nodedata_block_statehash'].value_counts().idxmax()

            point_record_df = master_df.loc[master_df['nodedata_block_statehash'] == most_common_statehash] 
            try:
                # get the id of bot_log to insert in Point_record
                # last Epoch time & last filename
                if not point_record_df.empty:
                    last_file_name = master_df.iloc[-1]['file_name']
                    last_filename_epoch_time = int(master_df.iloc[-1]['receivedAt'])
                    file_timestamp = master_df.iloc[-1]['file_timestamps']
                else:
                    last_file_name = ''
                    last_filename_epoch_time = 0
                    file_timestamp = 0
                values = last_file_name, last_filename_epoch_time, all_file_count, file_timestamp, script_start_time.timestamp(), ten_min_add.timestamp()
                bot_log_id = create_bot_log(connection, values)
                if not point_record_df.empty:
                    # data insertion to node_record_table
                    node_to_insert = point_record_df[['blockproducerkey']]
                    node_to_insert = node_to_insert.rename(columns={'blockproducerkey': 'block_producer_key'})
                    node_to_insert['updated_at'] = datetime.now(timezone.utc)
                    execute_node_record_batch(connection, node_to_insert, 100)

                    #file_name,file_timestamps,blockchain_epoch, node_id, state_hash,blockchain_height, amount,created_at,bot_log_id
                    point_record_df = point_record_df.rename(
                        columns={'receivedAt': 'blockchain_epoch', 'blockproducerkey': 'block_producer_key',
                                 'nodeData.blockHeight': 'blockchain_height',
                                 'nodeData.block.stateHash': 'state_hash'})
                    point_record_df['amount'] = 1
                    point_record_df['created_at'] = datetime.now(timezone.utc)
                    point_record_df['bot_log_id'] = bot_log_id
                    execute_point_record_batch(connection, point_record_df)

                    update_scoreboard(connection)
                    update_score_percent(connection)
            except Exception as error:
                connection.rollback()
                logger.error(ERROR.format(error))
            finally:
                connection.commit()

            process_loop_count += 1
            logger.info('Processed it loop count : {0}'.format(process_loop_count))

            script_start_time = ten_min_add


if __name__ == '__main__':
    time_interval = BaseConfig.SURVEY_INTERVAL_MINUTES
    gcs_main(time_interval)