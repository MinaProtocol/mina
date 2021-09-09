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


def second_mail(email_df, epoch_id):
    payouts_df = email_df
    # email has to be sent after end of epoch+id & 3500 slot added
    total_minutes = ((epoch_id+1) * 7140 * 3) + (BaseConfig.SLOT_WINDOW_VALUE * 3)
    deadline_date = BaseConfig.GENESIS_DATE + datetime.timedelta(minutes=total_minutes)
    deadline_date = deadline_date.strftime("%d-%m-%Y %H:%M:%S")

    # reading email template
    f = open(BaseConfig.VALIDATE_EMAIL_TEMPLATE, "r")
    html_text = f.read()
    count = 1
    for i in range(payouts_df.shape[0]):
        count = count + 1
        # 0- provider_pub_key, 1- winner_pub_key, 2- payout_amount #3 - payout_received
        html_content2 = html_text
        delegate = payouts_df.iloc[i, 0]
        delegatee = payouts_df.iloc[i, 1]
        # Adding dynamic values into the template
        html_content2 = html_content2.replace("#FOUNDATION_ADDRESS", str(payouts_df.iloc[i, 0]))
        html_content2 = html_content2.replace("#PAYOUT_AMOUNT", str(payouts_df.iloc[i, 2]))
        html_content2 = html_content2.replace("#PAYOUT_RECEIVED", str(payouts_df.iloc[i, 3]))
        html_content2 = html_content2.replace("#DEADLINE_DATE", str(deadline_date))
        html_content2 = html_content2.replace("#EPOCH_NO", str(epoch_id)) 
        html_content2 = html_content2.replace("#CURRENT_EPOCH_NO", str(epoch_id+1))
        subject = f"Summary of payments received by {BaseConfig.ADDRESS_SUBJECT} Address {payouts_df.iloc[i, 0][:7]}...{payouts_df.iloc[i, 0][-4:]} for Epoch {epoch_id}"
        block_producer_email = get_block_producer_mail(payouts_df.iloc[i, 1])
        message = Mail(from_email=BaseConfig.FROM_EMAIL,
                       to_emails=block_producer_email,
                       subject=subject,
                       plain_text_content='text',
                       html_content=html_content2)
        try:
            sg = SendGridAPIClient(api_key=BaseConfig.SENDGRID_API_KEY)
            response = sg.send(message)
            logger.info('email sent to: delgate:{0}, delgatee: {1}, emailid: {2}, status {3}, messageId: {4}'.format(delegate, delegatee, 
                block_producer_email, response.status_code, response.headers.get_all('X-Message-Id')))
        except Exception as e:
            logger.error(e)
    logger.info("Validation: epoch number: {0}, emails sent: {1}".format(epoch_id,count))