## Payout process  
Initial config for Payout process
The application relies on three databases:
     - Mainnet Archive : Uses this to get number of blocks produced and payout transaction details
     - Leaderboard     : Uses this to get Validator/Block producers email addresses
     - Payout          : Uses this to keep track of Payout processing
Use payout_schema.sql to create Payout database

## DB Config:   
	Install postgres   
	Execute SQL statement from payout_schema.sql. This will create tables and initial config data.  

	In payouts_config.py update below properties (All properties are required):  
    Mainnet Archive DB configurations:
	`POSTGRES_ARCHIVE_HOST`			The postgres hostname  
    `POSTGRES_ARCHIVE_PORT`			The postgres port  
    `POSTGRES_ARCHIVE_USER`			The postgres username  
    `POSTGRES_ARCHIVE_PASSWORD`		The postgres password  
    `POSTGRES_ARCHIVE_DB`			The postgres  database name  
	
    Similarly, for Payout DB configurations:
    `POSTGRES_PAYOUT_HOST` 
    `POSTGRES_PAYOUT_PORT` 
    `POSTGRES_PAYOUT_USER` 
    `POSTGRES_PAYOUT_PASSWORD`  
    `POSTGRES_PAYOUT_DB` 

    And lastly, Leaderboard DB configurations:
    `POSTGRES_LEADERBOARD_HOST` 
    `POSTGRES_LEADERBOARD_PORT` 
    `POSTGRES_LEADERBOARD_USER`  
    `POSTGRES_LEADERBOARD_PASSWORD`  
    `POSTGRES_LEADERBOARD_DB` 
	**Note**  If postgres is hosted on different machine, make sure to update "postgresql.conf" 
		and set  "listen_addresses" to appropriate value.  
	  
  
## GCS Credentials Config:	  
	Copy the GCS Credentials JSON file to local folder as payouts_calculate.py script, 
	and update the file name in config.py "CREDENTIAL_PATH"  
	
	`CREDENTIAL_PATH`		**Required** JSON file generated for GCS credentials.  
    `GCS_BUCKET_NAME`		**Required** GCS Bucket name  
	  
## Email Credentials Config:	  
	Update below in config.py
	`SENDGRID_API_KEY`	**Required** Sendgrid API secret key.  
    `FROM_EMAIL`		**Required** From email to be used.
	`TO_EMAILS`			**Required** list of comma separeted email id's to send email to.
	

***
## Creating the Environment file:
	Create .env file and include all required variables into this file
    `LOGGING_LOCATION`          **Required** Path address to save the logging file.
    `COINBASE`                  **Required** Rewards multiplier value.
    `SLOT_WINDOW_VALUE`         **Required** Epoch slot number for performing the calculation.
	`SENDGRID_API_KEY`	    **Required** Sendgrid API secret key.  
    `FROM_EMAIL`		    **Required** sender email to be used.
	`PROVIDER_EMAIL`	    **Required** list of comma separeted email id's to send email with attachment of data summary's to.
	`CREDENTIAL_PATH`           **Required** JSON file generated for GCS credentials.
    `OVERRIDE_EMAIL`              Mail ID for receiving mail's (testing purpose).
    `GCS_BUCKET_NAME`           **Required** Name of GCS bucket. 
    `DELEGATION_ADDRESSS_CSV`   **Required** Delegation address csv file.
    `CALCULATE_EMAIL_TEMPLATE`  **Required** Email template use while sending calculation mail's.
    `VALIDATE_EMAIL_TEMPLATE`   **Required**  Email template use while sending the payments summary mail's.
    `ADDRESS_SUBJECT`           **Required**  Mail subject while sending payment summary mail's.
    `POSTGRES_ARCHIVE_HOST`     **Required**  The Postgres hostname for Archive DB.
    `POSTGRES_ARCHIVE_PORT`     **Required**  The Postgres Port number for Archive DB.
    `POSTGRES_PAYOUT_USER`      **Required**  The Postgres Username for Archive DB.
    `POSTGRES_PAYOUT_PASSWORD`  **Required**  The Postgres Password for Archive DB.
    `POSTGRES_ARCHIVE_DB`       **Required**  The Postgres Database name for Archive DB.
    `POSTGRES_PAYOUT_HOST`      **Required**  The Postgres hostname for Payout DB.
    `POSTGRES_PAYOUT_PORT`      **Required**  The Postgres Port number for Payout DB.
    `POSTGRES_PAYOUT_USER`      **Required**  The Postgres Username for Payout DB.
    `POSTGRES_PAYOUT_PASSWORD`  **Required**  The Postgres Password for Payout DB.
    `POSTGRES_PAYOUT_DB`        **Required**  The Postgres Database name for Payout DB.
    `POSTGRES_LEADERBOARD_HOST` **Required**  The Postgres hostname for Leaderboard DB.
    `POSTGRES_LEADERBOARD_PORT` **Required**  The Postgres Port number for Leaderboard DB.
    `POSTGRES_LEADERBOARD_USER` **Required**  The Postgres Username for Leaderboard DB.
    `POSTGRES_LEADERBOARD_PASSWORD`  **Required**  The Postgres Password for Leaderboard DB.
    `POSTGRES_LEADERBOARD_DB`   **Required**  The Postgres Database name for Leaderboard DB.
Note: You can Refer the env file `payout_config_variables.env` provided in the git repository and provide values based on your environment.

## Setup the env-file:
1. Add all required credential values to file as key-value pair.Refer the payout_config_variables.env file.
2. Provide this .env file while running the docker run command like `docker run --env-file env_file_name image_name`.
### Installing Docker file:
1. Go to the terminal.
2. Type below Commands.
3. * >cd payout-process
   * >docker build -t payout-process .
   * >docker run --env-file payout_config_variables.env -v /var/log/minanet:/var/log/minanet:rw  --name=payout-process -i -t payout-process:latest
4. For Stopping the docker image use below command.
   * > docker stop payout-process && docker rm $_
   
For docker, please update all above properties also copy the credentials (env) file in same folder as 	  
	  
## Checking the Logs:
The log file is created in `/var/log/minanet`  on host machine where you can access the logs.