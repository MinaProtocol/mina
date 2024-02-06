ALTER TABLE zkapp_account_precondition
ADD CONSTRAINT zkapp_account_precondition_unique UNIQUE(balance_id, receipt_chain_hash, delegate_id, state_id, action_state_id, proved_state, is_new, nonce_id);