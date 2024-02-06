-- This sql file is used to patch our own migrated database because we changed the database schema
-- in this PR https://github.com/MinaProtocol/mina/pull/14407 
ALTER TABLE zkapp_permissions RENAME COLUMN set_verification_key TO set_verification_key_auth;
ALTER TABLE zkapp_permissions ADD COLUMN set_verification_key_txn_version int;
UPDATE      zkapp_permissions SET set_verification_key_txn_version = 1;
ALTER TABLE zkapp_permissions ALTER COLUMN set_verification_key_txn_version SET NOT NULL;