import psycopg2
from datetime import timezone
import datetime
from payouts_config import BaseConfig
import pandas as pd
from sendgrid import SendGridAPIClient
from sendgrid.helpers.mail import Mail, Attachment, FileContent, FileName, FileType, Disposition
from logger_util import logger


connection_leaderboard = psycopg2.connect(
    host=BaseConfig.POSTGRES_LEADERBOARD_HOST,
    port=BaseConfig.POSTGRES_LEADERBOARD_PORT,
    database=BaseConfig.POSTGRES_LEADERBOARD_DB,
    user=BaseConfig.POSTGRES_LEADERBOARD_USER,
    password=BaseConfig.POSTGRES_LEADERBOARD_PASSWORD
)


def get_block_producer_mail(winner_bpk):
    mail_id_sql = """select block_producer_email from node_record_table where block_producer_key = %s"""
    cursor = connection_leaderboard.cursor()
    email = ''
    try:
        cursor.execute(mail_id_sql, (winner_bpk,))
        if cursor.rowcount > 0:
            data = cursor.fetchall()
            email = data[-1][-1]
            if email == '':
                logger.warning("email not found for :".format(winner_bpk))
            if BaseConfig.OVERRIDE_EMAIL:
                    email = BaseConfig.OVERRIDE_EMAIL
    except (Exception, psycopg2.DatabaseError) as error:
        logger.info("Error: {0} ".format(error))
        cursor.close()
    return email

def send_mail(epoch_id, delegate_record_df):
    # read the data from delegation_record_table
    payouts_df = delegate_record_df
    total_minutes = (int(epoch_id+1) * 7140 * 3) + (BaseConfig.SLOT_WINDOW_VALUE * 3)
    deadline_date = BaseConfig.GENESIS_DATE + datetime.timedelta(minutes=total_minutes)
    current_date = datetime.datetime.now()
    day_count = deadline_date - current_date
    day_count = day_count.days
    deadline_date = deadline_date.strftime("%d-%m-%Y %H:%M:%S")

    # reading email template
    f = open(BaseConfig.CALCULATE_EMAIL_TEMPLATE, "r")
    html_text = f.read()
    
    count = 0
    for i in range(payouts_df.shape[0]):
        count = count + 1
        # 0- provider_pub_key, 1- winner_pub_key, 2 -blocks 3- payout_amount
        html_content = html_text
        delegate = payouts_df.iloc[i, 0]
        delegatee = payouts_df.iloc[i, 1]
        # Adding dynamic values into the template
        html_content = html_content.replace("#FOUNDATION_ADDRESS", str(payouts_df.iloc[i, 0]))
        html_content = html_content.replace("#PAYOUT_AMOUNT", str(payouts_df.iloc[i, 3]))
        html_content = html_content.replace("#EPOCH_NO", str(epoch_id)) 
        html_content = html_content.replace("#CURRENT_EPOCH_NO", str(epoch_id+1))
        html_content = html_content.replace("#BLOCK_PRODUCER_ADDRESS", str(payouts_df.iloc[i, 1]))
        html_content = html_content.replace("#DEADLINE_DATE", str(deadline_date))
        html_content = html_content.replace("#DAY_COUNT", str(day_count))

        subject = f"""Delegation from {BaseConfig.ADDRESS_SUBJECT} Address {payouts_df.iloc[i, 0][:7]}...{payouts_df.iloc[i, 0][-4:]} Send Block Rewards in MINAS for Epoch {epoch_id}"""
        block_producer_email = get_block_producer_mail(payouts_df.iloc[i, 1])
        message = Mail(from_email=BaseConfig.FROM_EMAIL,
                       to_emails=block_producer_email,
                       subject=subject,
                       plain_text_content='text',
                       html_content=html_content)
        try:
            sg = SendGridAPIClient(api_key=BaseConfig.SENDGRID_API_KEY)
            response = sg.send(message)
            logger.info('email sent to: delgate:{0}, delgatee: {1}, emailid: {2}, status {3}, messageId: {4}'.format(delegate, delegatee, 
                block_producer_email, response.status_code, response.headers.get_all('X-Message-Id')))           
        except Exception as e:
            logger.error('Error sending email: delgate:{0}, delgatee: {1}, error: {2}'.format(delegate, delegatee, e))
    logger.info("Calculation: epoch number: {0}, emails sent: {1}".format(epoch_id,count))