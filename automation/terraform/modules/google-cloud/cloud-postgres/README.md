# Google Cloud Postgres Deployment

This terraform configuration is used to deploy an instance of Google Cloud Postgres. Although the default configuration works without creating a conflict, it is recommended to deploy the postgres instance as a module within a larger terraform deployment (which passes it unique var values).

The default configuration uses Google Secret Manager to pull in a password for the default `postgres` user. After deployment, the assigned IP addresses, username, and password will be printed to the terminal as shown below:

```
Outputs:

cloud_postgres_ip = tolist([
  {
    "ip_address" = "35.35.35.35" <---- example IP
    "time_to_retire" = ""
    "type" = "PRIMARY"
  },
  {
    "ip_address" = "34.34.34.34" <---- example IP
    "time_to_retire" = ""
    "type" = "OUTGOING"
  },
])
db_password = "PASSWORD_HERE"
db_user = "postgres"
```

The `PRIMARY` IP should be used when connecting to the new instance. By default, not database or schema is defined on the newly deployed db.
