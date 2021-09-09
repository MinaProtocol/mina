## Leaderboard Bot  
Initial config for Leaderboard Bot  
  
  
## DB Config:   
	Install postgres   
	Execute SQL statement from database\tables.sql. This will create tables and initial config data needed by bot.  
	In config.py update below properties (All properties are required):  
	`POSTGRES_HOST`			The postgres hostname  
    `POSTGRES_PORT`			The postgres port  
    `POSTGRES_USER`			The postgres username  
    `POSTGRES_PASSWORD`		The postgres password  
    `POSTGRES_DB`			The postgres  database name  
	
	**Note**  If postgres is hosted on different machine, make sure to update "postgresql.conf" 
		and set  "listen_addresses" to appropriate value.  
	  
  
## GCS Credentials for Uptime data Config:	  
	Copy the GCS Credentials JSON file to local folder as survey_collect.py script, 
	and update the file name in config.py "CREDENTIAL_PATH"  
	
	`CREDENTIAL_PATH`		**Required** JSON file generated for GCS credentials.  
    `GCS_BUCKET_NAME`		**Required** GCS Bucket name  
	  
## Email Credentials Config:	  
	Update below in config.py
	`SENDGRID_API_KEY`		**Required** Sendgrid API secret key.  
    `FROM_EMAIL`			**Required** From email to be used.
	`TO_EMAILS`				**Required** list of comma separeted email id's to send email to.

## Participant application spreadsheet:	  
    `SPREADSHEET_SCOPE` 				['https://spreadsheets.google.com/feeds', 'https://www.googleapis.com/auth/drive']
    `SPREADSHEET_NAME` 					'Mina Foundation Delegation Application (Responses)'
    `SPREADSHEET_JSON` 					GCS credentials json to access applications spreadsheet
	`MAX_THREADS_TO_DOWNLOAD_FILES`		Max number of concurrent threads to download files from GCS Bucket
***
## Setup the env-file
1.Add all required credential value to file as key-value pair.Review the config_variables.env file. 
2.Provide this .env file while running the docker run command.

### Installing Docker file
1. Go to the terminal.
2. Type belowe Commands.
3. * >cd leaderboard-bot
   * >docker build -t leaderborad-bot .
   * >docker run --env-file config_variables.env -i -t leaderborad-bot:latest
    
For docker, please update all above propeties also copy the credetials file in same folder as 	  
	  
	