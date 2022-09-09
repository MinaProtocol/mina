--
-- PostgreSQL database dump
--

-- Dumped from database version 10.21 (Ubuntu 10.21-0ubuntu0.18.04.1)
-- Dumped by pg_dump version 13.1 (Ubuntu 13.1-1.pgdg18.04+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: archive; Type: DATABASE; Schema: -;
--

CREATE DATABASE archive WITH TEMPLATE = template0 ENCODING = 'UTF8' LC_COLLATE = 'en_US.UTF-8' LC_CTYPE = 'en_US.UTF-8';


ALTER DATABASE archive

\connect archive

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: call_type_type; Type: TYPE; Schema: public;
--

CREATE TYPE public.call_type_type AS ENUM (
    'call',
    'delegate_call'
);




--
-- Name: chain_status_type; Type: TYPE; Schema: public;
--

CREATE TYPE public.chain_status_type AS ENUM (
    'canonical',
    'orphaned',
    'pending'
);



--
-- Name: internal_command_type; Type: TYPE; Schema: public;
--

CREATE TYPE public.internal_command_type AS ENUM (
    'fee_transfer_via_coinbase',
    'fee_transfer',
    'coinbase'
);




--
-- Name: transaction_status; Type: TYPE; Schema: public;
--

CREATE TYPE public.transaction_status AS ENUM (
    'applied',
    'failed'
);




--
-- Name: user_command_type; Type: TYPE; Schema: public;
--

CREATE TYPE public.user_command_type AS ENUM (
    'payment',
    'delegation'
);




--
-- Name: zkapp_auth_required_type; Type: TYPE; Schema: public;
--

CREATE TYPE public.zkapp_auth_required_type AS ENUM (
    'none',
    'either',
    'proof',
    'signature',
    'both',
    'impossible'
);




--
-- Name: zkapp_authorization_kind_type; Type: TYPE; Schema: public;
--

CREATE TYPE public.zkapp_authorization_kind_type AS ENUM (
    'proof',
    'signature',
    'none_given'
);




--
-- Name: zkapp_precondition_type; Type: TYPE; Schema: public;
--

CREATE TYPE public.zkapp_precondition_type AS ENUM (
    'full',
    'nonce',
    'accept'
);




SET default_tablespace = '';

--
-- Name: account_identifiers; Type: TABLE; Schema: public;
--

CREATE TABLE public.account_identifiers (
    id integer NOT NULL,
    public_key_id integer NOT NULL,
    token_id integer NOT NULL
);




--
-- Name: account_identifiers_id_seq; Type: SEQUENCE; Schema: public;
--

CREATE SEQUENCE public.account_identifiers_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;




--
-- Name: account_identifiers_id_seq; Type: SEQUENCE OWNED BY; Schema: public;
--

ALTER SEQUENCE public.account_identifiers_id_seq OWNED BY public.account_identifiers.id;


--
-- Name: accounts_accessed; Type: TABLE; Schema: public;
--

CREATE TABLE public.accounts_accessed (
    ledger_index integer NOT NULL,
    block_id integer NOT NULL,
    account_identifier_id integer NOT NULL,
    token_symbol_id integer NOT NULL,
    balance text NOT NULL,
    nonce bigint NOT NULL,
    receipt_chain_hash text NOT NULL,
    delegate_id integer,
    voting_for_id integer NOT NULL,
    timing_id integer,
    permissions_id integer NOT NULL,
    zkapp_id integer
);




--
-- Name: accounts_created; Type: TABLE; Schema: public;
--

CREATE TABLE public.accounts_created (
    block_id integer NOT NULL,
    account_identifier_id integer NOT NULL,
    creation_fee text NOT NULL
);




--
-- Name: blocks; Type: TABLE; Schema: public;
--

CREATE TABLE public.blocks (
    id integer NOT NULL,
    state_hash text NOT NULL,
    parent_id integer,
    parent_hash text NOT NULL,
    creator_id integer NOT NULL,
    block_winner_id integer NOT NULL,
    snarked_ledger_hash_id integer NOT NULL,
    staking_epoch_data_id integer NOT NULL,
    next_epoch_data_id integer NOT NULL,
    min_window_density bigint NOT NULL,
    total_currency text NOT NULL,
    ledger_hash text NOT NULL,
    height bigint NOT NULL,
    global_slot_since_hard_fork bigint NOT NULL,
    global_slot_since_genesis bigint NOT NULL,
    "timestamp" text NOT NULL,
    chain_status public.chain_status_type NOT NULL
);




--
-- Name: blocks_id_seq; Type: SEQUENCE; Schema: public;
--

CREATE SEQUENCE public.blocks_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;




--
-- Name: blocks_id_seq; Type: SEQUENCE OWNED BY; Schema: public;
--

ALTER SEQUENCE public.blocks_id_seq OWNED BY public.blocks.id;


--
-- Name: blocks_internal_commands; Type: TABLE; Schema: public;
--

CREATE TABLE public.blocks_internal_commands (
    block_id integer NOT NULL,
    internal_command_id integer NOT NULL,
    sequence_no integer NOT NULL,
    secondary_sequence_no integer NOT NULL,
    status public.transaction_status NOT NULL,
    failure_reason text
);




--
-- Name: blocks_user_commands; Type: TABLE; Schema: public;
--

CREATE TABLE public.blocks_user_commands (
    block_id integer NOT NULL,
    user_command_id integer NOT NULL,
    sequence_no integer NOT NULL,
    status public.transaction_status NOT NULL,
    failure_reason text
);




--
-- Name: blocks_zkapp_commands; Type: TABLE; Schema: public;
--

CREATE TABLE public.blocks_zkapp_commands (
    block_id integer NOT NULL,
    zkapp_command_id integer NOT NULL,
    sequence_no integer NOT NULL,
    status public.transaction_status NOT NULL,
    failure_reasons_ids integer[]
);




--
-- Name: epoch_data; Type: TABLE; Schema: public;
--

CREATE TABLE public.epoch_data (
    id integer NOT NULL,
    seed text NOT NULL,
    ledger_hash_id integer NOT NULL,
    total_currency text NOT NULL,
    start_checkpoint text NOT NULL,
    lock_checkpoint text NOT NULL,
    epoch_length bigint NOT NULL
);




--
-- Name: epoch_data_id_seq; Type: SEQUENCE; Schema: public;
--

CREATE SEQUENCE public.epoch_data_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;




--
-- Name: epoch_data_id_seq; Type: SEQUENCE OWNED BY; Schema: public;
--

ALTER SEQUENCE public.epoch_data_id_seq OWNED BY public.epoch_data.id;


--
-- Name: internal_commands; Type: TABLE; Schema: public;
--

CREATE TABLE public.internal_commands (
    id integer NOT NULL,
    typ public.internal_command_type NOT NULL,
    receiver_id integer NOT NULL,
    fee text NOT NULL,
    hash text NOT NULL
);




--
-- Name: internal_commands_id_seq; Type: SEQUENCE; Schema: public;
--

CREATE SEQUENCE public.internal_commands_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;




--
-- Name: internal_commands_id_seq; Type: SEQUENCE OWNED BY; Schema: public;
--

ALTER SEQUENCE public.internal_commands_id_seq OWNED BY public.internal_commands.id;


--
-- Name: public_keys; Type: TABLE; Schema: public;
--

CREATE TABLE public.public_keys (
    id integer NOT NULL,
    value text NOT NULL
);




--
-- Name: public_keys_id_seq; Type: SEQUENCE; Schema: public;
--

CREATE SEQUENCE public.public_keys_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;




--
-- Name: public_keys_id_seq; Type: SEQUENCE OWNED BY; Schema: public;
--

ALTER SEQUENCE public.public_keys_id_seq OWNED BY public.public_keys.id;


--
-- Name: snarked_ledger_hashes; Type: TABLE; Schema: public;
--

CREATE TABLE public.snarked_ledger_hashes (
    id integer NOT NULL,
    value text NOT NULL
);




--
-- Name: snarked_ledger_hashes_id_seq; Type: SEQUENCE; Schema: public;
--

CREATE SEQUENCE public.snarked_ledger_hashes_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;




--
-- Name: snarked_ledger_hashes_id_seq; Type: SEQUENCE OWNED BY; Schema: public;
--

ALTER SEQUENCE public.snarked_ledger_hashes_id_seq OWNED BY public.snarked_ledger_hashes.id;


--
-- Name: timing_info; Type: TABLE; Schema: public;
--

CREATE TABLE public.timing_info (
    id integer NOT NULL,
    account_identifier_id integer NOT NULL,
    initial_minimum_balance text NOT NULL,
    cliff_time bigint NOT NULL,
    cliff_amount text NOT NULL,
    vesting_period bigint NOT NULL,
    vesting_increment text NOT NULL
);




--
-- Name: timing_info_id_seq; Type: SEQUENCE; Schema: public;
--

CREATE SEQUENCE public.timing_info_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;




--
-- Name: timing_info_id_seq; Type: SEQUENCE OWNED BY; Schema: public;
--

ALTER SEQUENCE public.timing_info_id_seq OWNED BY public.timing_info.id;


--
-- Name: token_symbols; Type: TABLE; Schema: public;
--

CREATE TABLE public.token_symbols (
    id integer NOT NULL,
    value text NOT NULL
);




--
-- Name: token_symbols_id_seq; Type: SEQUENCE; Schema: public;
--

CREATE SEQUENCE public.token_symbols_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;




--
-- Name: token_symbols_id_seq; Type: SEQUENCE OWNED BY; Schema: public;
--

ALTER SEQUENCE public.token_symbols_id_seq OWNED BY public.token_symbols.id;


--
-- Name: tokens; Type: TABLE; Schema: public;
--

CREATE TABLE public.tokens (
    id integer NOT NULL,
    value text NOT NULL,
    owner_public_key_id integer,
    owner_token_id integer
);




--
-- Name: tokens_id_seq; Type: SEQUENCE; Schema: public;
--

CREATE SEQUENCE public.tokens_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;




--
-- Name: tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: public;
--

ALTER SEQUENCE public.tokens_id_seq OWNED BY public.tokens.id;


--
-- Name: user_commands; Type: TABLE; Schema: public;
--

CREATE TABLE public.user_commands (
    id integer NOT NULL,
    typ public.user_command_type NOT NULL,
    fee_payer_id integer NOT NULL,
    source_id integer NOT NULL,
    receiver_id integer NOT NULL,
    nonce bigint NOT NULL,
    amount text,
    fee text NOT NULL,
    valid_until bigint,
    memo text NOT NULL,
    hash text NOT NULL
);




--
-- Name: user_commands_id_seq; Type: SEQUENCE; Schema: public;
--

CREATE SEQUENCE public.user_commands_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;




--
-- Name: user_commands_id_seq; Type: SEQUENCE OWNED BY; Schema: public;
--

ALTER SEQUENCE public.user_commands_id_seq OWNED BY public.user_commands.id;


--
-- Name: voting_for; Type: TABLE; Schema: public;
--

CREATE TABLE public.voting_for (
    id integer NOT NULL,
    value text NOT NULL
);




--
-- Name: voting_for_id_seq; Type: SEQUENCE; Schema: public;
--

CREATE SEQUENCE public.voting_for_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;




--
-- Name: voting_for_id_seq; Type: SEQUENCE OWNED BY; Schema: public;
--

ALTER SEQUENCE public.voting_for_id_seq OWNED BY public.voting_for.id;


--
-- Name: zkapp_account_precondition; Type: TABLE; Schema: public;
--

CREATE TABLE public.zkapp_account_precondition (
    id integer NOT NULL,
    kind public.zkapp_precondition_type NOT NULL,
    precondition_account_id integer,
    nonce bigint
);




--
-- Name: zkapp_account_precondition_id_seq; Type: SEQUENCE; Schema: public;
--

CREATE SEQUENCE public.zkapp_account_precondition_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;




--
-- Name: zkapp_account_precondition_id_seq; Type: SEQUENCE OWNED BY; Schema: public;
--

ALTER SEQUENCE public.zkapp_account_precondition_id_seq OWNED BY public.zkapp_account_precondition.id;


--
-- Name: zkapp_accounts; Type: TABLE; Schema: public;
--

CREATE TABLE public.zkapp_accounts (
    id integer NOT NULL,
    app_state_id integer NOT NULL,
    verification_key_id integer NOT NULL,
    zkapp_version bigint NOT NULL,
    sequence_state_id integer NOT NULL,
    last_sequence_slot bigint NOT NULL,
    proved_state boolean NOT NULL,
    zkapp_uri_id integer NOT NULL
);




--
-- Name: zkapp_accounts_id_seq; Type: SEQUENCE; Schema: public;
--

CREATE SEQUENCE public.zkapp_accounts_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;




--
-- Name: zkapp_accounts_id_seq; Type: SEQUENCE OWNED BY; Schema: public;
--

ALTER SEQUENCE public.zkapp_accounts_id_seq OWNED BY public.zkapp_accounts.id;


--
-- Name: zkapp_amount_bounds; Type: TABLE; Schema: public;
--

CREATE TABLE public.zkapp_amount_bounds (
    id integer NOT NULL,
    amount_lower_bound text NOT NULL,
    amount_upper_bound text NOT NULL
);




--
-- Name: zkapp_amount_bounds_id_seq; Type: SEQUENCE; Schema: public;
--

CREATE SEQUENCE public.zkapp_amount_bounds_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;




--
-- Name: zkapp_amount_bounds_id_seq; Type: SEQUENCE OWNED BY; Schema: public;
--

ALTER SEQUENCE public.zkapp_amount_bounds_id_seq OWNED BY public.zkapp_amount_bounds.id;


--
-- Name: zkapp_balance_bounds; Type: TABLE; Schema: public;
--

CREATE TABLE public.zkapp_balance_bounds (
    id integer NOT NULL,
    balance_lower_bound text NOT NULL,
    balance_upper_bound text NOT NULL
);




--
-- Name: zkapp_balance_bounds_id_seq; Type: SEQUENCE; Schema: public;
--

CREATE SEQUENCE public.zkapp_balance_bounds_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;




--
-- Name: zkapp_balance_bounds_id_seq; Type: SEQUENCE OWNED BY; Schema: public;
--

ALTER SEQUENCE public.zkapp_balance_bounds_id_seq OWNED BY public.zkapp_balance_bounds.id;


--
-- Name: zkapp_commands; Type: TABLE; Schema: public;
--

CREATE TABLE public.zkapp_commands (
    id integer NOT NULL,
    zkapp_fee_payer_body_id integer NOT NULL,
    zkapp_other_parties_ids integer[] NOT NULL,
    memo text NOT NULL,
    hash text NOT NULL
);




--
-- Name: zkapp_commands_id_seq; Type: SEQUENCE; Schema: public;
--

CREATE SEQUENCE public.zkapp_commands_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;




--
-- Name: zkapp_commands_id_seq; Type: SEQUENCE OWNED BY; Schema: public;
--

ALTER SEQUENCE public.zkapp_commands_id_seq OWNED BY public.zkapp_commands.id;


--
-- Name: zkapp_epoch_data; Type: TABLE; Schema: public;
--

CREATE TABLE public.zkapp_epoch_data (
    id integer NOT NULL,
    epoch_ledger_id integer,
    epoch_seed text,
    start_checkpoint text,
    lock_checkpoint text,
    epoch_length_id integer
);




--
-- Name: zkapp_epoch_data_id_seq; Type: SEQUENCE; Schema: public;
--

CREATE SEQUENCE public.zkapp_epoch_data_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;




--
-- Name: zkapp_epoch_data_id_seq; Type: SEQUENCE OWNED BY; Schema: public;
--

ALTER SEQUENCE public.zkapp_epoch_data_id_seq OWNED BY public.zkapp_epoch_data.id;


--
-- Name: zkapp_epoch_ledger; Type: TABLE; Schema: public;
--

CREATE TABLE public.zkapp_epoch_ledger (
    id integer NOT NULL,
    hash_id integer,
    total_currency_id integer
);




--
-- Name: zkapp_epoch_ledger_id_seq; Type: SEQUENCE; Schema: public;
--

CREATE SEQUENCE public.zkapp_epoch_ledger_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;




--
-- Name: zkapp_epoch_ledger_id_seq; Type: SEQUENCE OWNED BY; Schema: public;
--

ALTER SEQUENCE public.zkapp_epoch_ledger_id_seq OWNED BY public.zkapp_epoch_ledger.id;


--
-- Name: zkapp_events; Type: TABLE; Schema: public;
--

CREATE TABLE public.zkapp_events (
    id integer NOT NULL,
    element_ids integer[] NOT NULL
);




--
-- Name: zkapp_events_id_seq; Type: SEQUENCE; Schema: public;
--

CREATE SEQUENCE public.zkapp_events_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;




--
-- Name: zkapp_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public;
--

ALTER SEQUENCE public.zkapp_events_id_seq OWNED BY public.zkapp_events.id;


--
-- Name: zkapp_fee_payer_body; Type: TABLE; Schema: public;
--

CREATE TABLE public.zkapp_fee_payer_body (
    id integer NOT NULL,
    account_identifier_id integer NOT NULL,
    fee text NOT NULL,
    valid_until bigint,
    nonce bigint NOT NULL
);




--
-- Name: zkapp_fee_payer_body_id_seq; Type: SEQUENCE; Schema: public;
--

CREATE SEQUENCE public.zkapp_fee_payer_body_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;




--
-- Name: zkapp_fee_payer_body_id_seq; Type: SEQUENCE OWNED BY; Schema: public;
--

ALTER SEQUENCE public.zkapp_fee_payer_body_id_seq OWNED BY public.zkapp_fee_payer_body.id;


--
-- Name: zkapp_global_slot_bounds; Type: TABLE; Schema: public;
--

CREATE TABLE public.zkapp_global_slot_bounds (
    id integer NOT NULL,
    global_slot_lower_bound bigint NOT NULL,
    global_slot_upper_bound bigint NOT NULL
);




--
-- Name: zkapp_global_slot_bounds_id_seq; Type: SEQUENCE; Schema: public;
--

CREATE SEQUENCE public.zkapp_global_slot_bounds_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;




--
-- Name: zkapp_global_slot_bounds_id_seq; Type: SEQUENCE OWNED BY; Schema: public;
--

ALTER SEQUENCE public.zkapp_global_slot_bounds_id_seq OWNED BY public.zkapp_global_slot_bounds.id;


--
-- Name: zkapp_length_bounds; Type: TABLE; Schema: public;
--

CREATE TABLE public.zkapp_length_bounds (
    id integer NOT NULL,
    length_lower_bound bigint NOT NULL,
    length_upper_bound bigint NOT NULL
);




--
-- Name: zkapp_length_bounds_id_seq; Type: SEQUENCE; Schema: public;
--

CREATE SEQUENCE public.zkapp_length_bounds_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;




--
-- Name: zkapp_length_bounds_id_seq; Type: SEQUENCE OWNED BY; Schema: public;
--

ALTER SEQUENCE public.zkapp_length_bounds_id_seq OWNED BY public.zkapp_length_bounds.id;


--
-- Name: zkapp_network_precondition; Type: TABLE; Schema: public;
--

CREATE TABLE public.zkapp_network_precondition (
    id integer NOT NULL,
    snarked_ledger_hash_id integer,
    timestamp_id integer,
    blockchain_length_id integer,
    min_window_density_id integer,
    total_currency_id integer,
    curr_global_slot_since_hard_fork integer,
    global_slot_since_genesis integer,
    staking_epoch_data_id integer,
    next_epoch_data_id integer
);




--
-- Name: zkapp_network_precondition_id_seq; Type: SEQUENCE; Schema: public;
--

CREATE SEQUENCE public.zkapp_network_precondition_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;




--
-- Name: zkapp_network_precondition_id_seq; Type: SEQUENCE OWNED BY; Schema: public;
--

ALTER SEQUENCE public.zkapp_network_precondition_id_seq OWNED BY public.zkapp_network_precondition.id;


--
-- Name: zkapp_nonce_bounds; Type: TABLE; Schema: public;
--

CREATE TABLE public.zkapp_nonce_bounds (
    id integer NOT NULL,
    nonce_lower_bound bigint NOT NULL,
    nonce_upper_bound bigint NOT NULL
);




--
-- Name: zkapp_nonce_bounds_id_seq; Type: SEQUENCE; Schema: public;
--

CREATE SEQUENCE public.zkapp_nonce_bounds_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;




--
-- Name: zkapp_nonce_bounds_id_seq; Type: SEQUENCE OWNED BY; Schema: public;
--

ALTER SEQUENCE public.zkapp_nonce_bounds_id_seq OWNED BY public.zkapp_nonce_bounds.id;


--
-- Name: zkapp_other_party; Type: TABLE; Schema: public;
--

CREATE TABLE public.zkapp_other_party (
    id integer NOT NULL,
    body_id integer NOT NULL,
    authorization_kind public.zkapp_authorization_kind_type NOT NULL
);




--
-- Name: zkapp_other_party_body; Type: TABLE; Schema: public;
--

CREATE TABLE public.zkapp_other_party_body (
    id integer NOT NULL,
    account_identifier_id integer NOT NULL,
    update_id integer NOT NULL,
    balance_change text NOT NULL,
    increment_nonce boolean NOT NULL,
    events_id integer NOT NULL,
    sequence_events_id integer NOT NULL,
    call_data_id integer NOT NULL,
    call_depth integer NOT NULL,
    zkapp_network_precondition_id integer NOT NULL,
    zkapp_account_precondition_id integer NOT NULL,
    use_full_commitment boolean NOT NULL,
    caller public.call_type_type NOT NULL
);




--
-- Name: zkapp_other_party_body_id_seq; Type: SEQUENCE; Schema: public;
--

CREATE SEQUENCE public.zkapp_other_party_body_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;




--
-- Name: zkapp_other_party_body_id_seq; Type: SEQUENCE OWNED BY; Schema: public;
--

ALTER SEQUENCE public.zkapp_other_party_body_id_seq OWNED BY public.zkapp_other_party_body.id;


--
-- Name: zkapp_other_party_id_seq; Type: SEQUENCE; Schema: public;
--

CREATE SEQUENCE public.zkapp_other_party_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;




--
-- Name: zkapp_other_party_id_seq; Type: SEQUENCE OWNED BY; Schema: public;
--

ALTER SEQUENCE public.zkapp_other_party_id_seq OWNED BY public.zkapp_other_party.id;


--
-- Name: zkapp_party_failures; Type: TABLE; Schema: public;
--

CREATE TABLE public.zkapp_party_failures (
    id integer NOT NULL,
    index integer NOT NULL,
    failures text[] NOT NULL
);




--
-- Name: zkapp_party_failures_id_seq; Type: SEQUENCE; Schema: public;
--

CREATE SEQUENCE public.zkapp_party_failures_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;




--
-- Name: zkapp_party_failures_id_seq; Type: SEQUENCE OWNED BY; Schema: public;
--

ALTER SEQUENCE public.zkapp_party_failures_id_seq OWNED BY public.zkapp_party_failures.id;


--
-- Name: zkapp_permissions; Type: TABLE; Schema: public;
--

CREATE TABLE public.zkapp_permissions (
    id integer NOT NULL,
    edit_state public.zkapp_auth_required_type NOT NULL,
    send public.zkapp_auth_required_type NOT NULL,
    receive public.zkapp_auth_required_type NOT NULL,
    set_delegate public.zkapp_auth_required_type NOT NULL,
    set_permissions public.zkapp_auth_required_type NOT NULL,
    set_verification_key public.zkapp_auth_required_type NOT NULL,
    set_zkapp_uri public.zkapp_auth_required_type NOT NULL,
    edit_sequence_state public.zkapp_auth_required_type NOT NULL,
    set_token_symbol public.zkapp_auth_required_type NOT NULL,
    increment_nonce public.zkapp_auth_required_type NOT NULL,
    set_voting_for public.zkapp_auth_required_type NOT NULL
);




--
-- Name: zkapp_permissions_id_seq; Type: SEQUENCE; Schema: public;
--

CREATE SEQUENCE public.zkapp_permissions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;




--
-- Name: zkapp_permissions_id_seq; Type: SEQUENCE OWNED BY; Schema: public;
--

ALTER SEQUENCE public.zkapp_permissions_id_seq OWNED BY public.zkapp_permissions.id;


--
-- Name: zkapp_precondition_accounts; Type: TABLE; Schema: public;
--

CREATE TABLE public.zkapp_precondition_accounts (
    id integer NOT NULL,
    balance_id integer,
    nonce_id integer,
    receipt_chain_hash text,
    delegate_id integer,
    state_id integer NOT NULL,
    sequence_state_id integer,
    proved_state boolean,
    is_new boolean
);




--
-- Name: zkapp_precondition_accounts_id_seq; Type: SEQUENCE; Schema: public;
--

CREATE SEQUENCE public.zkapp_precondition_accounts_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;




--
-- Name: zkapp_precondition_accounts_id_seq; Type: SEQUENCE OWNED BY; Schema: public;
--

ALTER SEQUENCE public.zkapp_precondition_accounts_id_seq OWNED BY public.zkapp_precondition_accounts.id;


--
-- Name: zkapp_sequence_states; Type: TABLE; Schema: public;
--

CREATE TABLE public.zkapp_sequence_states (
    id integer NOT NULL,
    element0 integer NOT NULL,
    element1 integer NOT NULL,
    element2 integer NOT NULL,
    element3 integer NOT NULL,
    element4 integer NOT NULL
);




--
-- Name: zkapp_sequence_states_id_seq; Type: SEQUENCE; Schema: public;
--

CREATE SEQUENCE public.zkapp_sequence_states_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;




--
-- Name: zkapp_sequence_states_id_seq; Type: SEQUENCE OWNED BY; Schema: public;
--

ALTER SEQUENCE public.zkapp_sequence_states_id_seq OWNED BY public.zkapp_sequence_states.id;


--
-- Name: zkapp_state_data; Type: TABLE; Schema: public;
--

CREATE TABLE public.zkapp_state_data (
    id integer NOT NULL,
    field text NOT NULL
);




--
-- Name: zkapp_state_data_array; Type: TABLE; Schema: public;
--

CREATE TABLE public.zkapp_state_data_array (
    id integer NOT NULL,
    element_ids integer[] NOT NULL
);




--
-- Name: zkapp_state_data_array_id_seq; Type: SEQUENCE; Schema: public;
--

CREATE SEQUENCE public.zkapp_state_data_array_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;




--
-- Name: zkapp_state_data_array_id_seq; Type: SEQUENCE OWNED BY; Schema: public;
--

ALTER SEQUENCE public.zkapp_state_data_array_id_seq OWNED BY public.zkapp_state_data_array.id;


--
-- Name: zkapp_state_data_id_seq; Type: SEQUENCE; Schema: public;
--

CREATE SEQUENCE public.zkapp_state_data_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;




--
-- Name: zkapp_state_data_id_seq; Type: SEQUENCE OWNED BY; Schema: public;
--

ALTER SEQUENCE public.zkapp_state_data_id_seq OWNED BY public.zkapp_state_data.id;

--
-- Name: zkapp_states; Type: TABLE; Schema: public;
--

CREATE TABLE public.zkapp_states (
    id integer NOT NULL,
    element0 integer NOT NULL,
    element1 integer NOT NULL,
    element2 integer NOT NULL,
    element3 integer NOT NULL,
    element4 integer NOT NULL,
    element5 integer NOT NULL,
    element6 integer NOT NULL,
    element7 integer NOT NULL
);




--
-- Name: zkapp_states_id_seq; Type: SEQUENCE; Schema: public;
--

CREATE SEQUENCE public.zkapp_states_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;




--
-- Name: zkapp_states_id_seq; Type: SEQUENCE OWNED BY; Schema: public;
--

ALTER SEQUENCE public.zkapp_states_id_seq OWNED BY public.zkapp_states.id;


--
-- Name: zkapp_states; Type: TABLE; Schema: public;
--

CREATE TABLE public.zkapp_states_nullable (
    id integer NOT NULL,
    element0 integer,
    element1 integer,
    element2 integer,
    element3 integer,
    element4 integer,
    element5 integer,
    element6 integer,
    element7 integer
);




--
-- Name: zkapp_states_id_seq; Type: SEQUENCE; Schema: public;
--

CREATE SEQUENCE public.zkapp_states_nullable_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;




--
-- Name: zkapp_states_id_seq; Type: SEQUENCE OWNED BY; Schema: public;
--

ALTER SEQUENCE public.zkapp_states_nullable_id_seq OWNED BY public.zkapp_states_nullable.id;


--
-- Name: zkapp_timestamp_bounds; Type: TABLE; Schema: public;
--

CREATE TABLE public.zkapp_timestamp_bounds (
    id integer NOT NULL,
    timestamp_lower_bound text NOT NULL,
    timestamp_upper_bound text NOT NULL
);




--
-- Name: zkapp_timestamp_bounds_id_seq; Type: SEQUENCE; Schema: public;
--

CREATE SEQUENCE public.zkapp_timestamp_bounds_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;




--
-- Name: zkapp_timestamp_bounds_id_seq; Type: SEQUENCE OWNED BY; Schema: public;
--

ALTER SEQUENCE public.zkapp_timestamp_bounds_id_seq OWNED BY public.zkapp_timestamp_bounds.id;


--
-- Name: zkapp_timing_info; Type: TABLE; Schema: public;
--

CREATE TABLE public.zkapp_timing_info (
    id integer NOT NULL,
    initial_minimum_balance text NOT NULL,
    cliff_time bigint NOT NULL,
    cliff_amount text NOT NULL,
    vesting_period bigint NOT NULL,
    vesting_increment text NOT NULL
);




--
-- Name: zkapp_timing_info_id_seq; Type: SEQUENCE; Schema: public;
--

CREATE SEQUENCE public.zkapp_timing_info_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;




--
-- Name: zkapp_timing_info_id_seq; Type: SEQUENCE OWNED BY; Schema: public;
--

ALTER SEQUENCE public.zkapp_timing_info_id_seq OWNED BY public.zkapp_timing_info.id;


--
-- Name: zkapp_token_id_bounds; Type: TABLE; Schema: public;
--

CREATE TABLE public.zkapp_token_id_bounds (
    id integer NOT NULL,
    token_id_lower_bound text NOT NULL,
    token_id_upper_bound text NOT NULL
);




--
-- Name: zkapp_token_id_bounds_id_seq; Type: SEQUENCE; Schema: public;
--

CREATE SEQUENCE public.zkapp_token_id_bounds_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;




--
-- Name: zkapp_token_id_bounds_id_seq; Type: SEQUENCE OWNED BY; Schema: public;
--

ALTER SEQUENCE public.zkapp_token_id_bounds_id_seq OWNED BY public.zkapp_token_id_bounds.id;


--
-- Name: zkapp_updates; Type: TABLE; Schema: public;
--

CREATE TABLE public.zkapp_updates (
    id integer NOT NULL,
    app_state_id integer NOT NULL,
    delegate_id integer,
    verification_key_id integer,
    permissions_id integer,
    zkapp_uri_id integer,
    token_symbol_id integer,
    timing_id integer,
    voting_for_id integer
);




--
-- Name: zkapp_updates_id_seq; Type: SEQUENCE; Schema: public;
--

CREATE SEQUENCE public.zkapp_updates_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;




--
-- Name: zkapp_updates_id_seq; Type: SEQUENCE OWNED BY; Schema: public;
--

ALTER SEQUENCE public.zkapp_updates_id_seq OWNED BY public.zkapp_updates.id;


--
-- Name: zkapp_uris; Type: TABLE; Schema: public;
--

CREATE TABLE public.zkapp_uris (
    id integer NOT NULL,
    value text NOT NULL
);




--
-- Name: zkapp_uris_id_seq; Type: SEQUENCE; Schema: public;
--

CREATE SEQUENCE public.zkapp_uris_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;




--
-- Name: zkapp_uris_id_seq; Type: SEQUENCE OWNED BY; Schema: public;
--

ALTER SEQUENCE public.zkapp_uris_id_seq OWNED BY public.zkapp_uris.id;


--
-- Name: zkapp_verification_keys; Type: TABLE; Schema: public;
--

CREATE TABLE public.zkapp_verification_keys (
    id integer NOT NULL,
    verification_key text NOT NULL,
    hash text NOT NULL
);




--
-- Name: zkapp_verification_keys_id_seq; Type: SEQUENCE; Schema: public;
--

CREATE SEQUENCE public.zkapp_verification_keys_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;




--
-- Name: zkapp_verification_keys_id_seq; Type: SEQUENCE OWNED BY; Schema: public;
--

ALTER SEQUENCE public.zkapp_verification_keys_id_seq OWNED BY public.zkapp_verification_keys.id;


--
-- Name: account_identifiers id; Type: DEFAULT; Schema: public;
--

ALTER TABLE ONLY public.account_identifiers ALTER COLUMN id SET DEFAULT nextval('public.account_identifiers_id_seq'::regclass);


--
-- Name: blocks id; Type: DEFAULT; Schema: public;
--

ALTER TABLE ONLY public.blocks ALTER COLUMN id SET DEFAULT nextval('public.blocks_id_seq'::regclass);


--
-- Name: epoch_data id; Type: DEFAULT; Schema: public;
--

ALTER TABLE ONLY public.epoch_data ALTER COLUMN id SET DEFAULT nextval('public.epoch_data_id_seq'::regclass);


--
-- Name: internal_commands id; Type: DEFAULT; Schema: public;
--

ALTER TABLE ONLY public.internal_commands ALTER COLUMN id SET DEFAULT nextval('public.internal_commands_id_seq'::regclass);


--
-- Name: public_keys id; Type: DEFAULT; Schema: public;
--

ALTER TABLE ONLY public.public_keys ALTER COLUMN id SET DEFAULT nextval('public.public_keys_id_seq'::regclass);


--
-- Name: snarked_ledger_hashes id; Type: DEFAULT; Schema: public;
--

ALTER TABLE ONLY public.snarked_ledger_hashes ALTER COLUMN id SET DEFAULT nextval('public.snarked_ledger_hashes_id_seq'::regclass);


--
-- Name: timing_info id; Type: DEFAULT; Schema: public;
--

ALTER TABLE ONLY public.timing_info ALTER COLUMN id SET DEFAULT nextval('public.timing_info_id_seq'::regclass);


--
-- Name: token_symbols id; Type: DEFAULT; Schema: public;
--

ALTER TABLE ONLY public.token_symbols ALTER COLUMN id SET DEFAULT nextval('public.token_symbols_id_seq'::regclass);


--
-- Name: tokens id; Type: DEFAULT; Schema: public;
--

ALTER TABLE ONLY public.tokens ALTER COLUMN id SET DEFAULT nextval('public.tokens_id_seq'::regclass);


--
-- Name: user_commands id; Type: DEFAULT; Schema: public;
--

ALTER TABLE ONLY public.user_commands ALTER COLUMN id SET DEFAULT nextval('public.user_commands_id_seq'::regclass);


--
-- Name: voting_for id; Type: DEFAULT; Schema: public;
--

ALTER TABLE ONLY public.voting_for ALTER COLUMN id SET DEFAULT nextval('public.voting_for_id_seq'::regclass);


--
-- Name: zkapp_account_precondition id; Type: DEFAULT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_account_precondition ALTER COLUMN id SET DEFAULT nextval('public.zkapp_account_precondition_id_seq'::regclass);


--
-- Name: zkapp_accounts id; Type: DEFAULT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_accounts ALTER COLUMN id SET DEFAULT nextval('public.zkapp_accounts_id_seq'::regclass);


--
-- Name: zkapp_amount_bounds id; Type: DEFAULT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_amount_bounds ALTER COLUMN id SET DEFAULT nextval('public.zkapp_amount_bounds_id_seq'::regclass);


--
-- Name: zkapp_balance_bounds id; Type: DEFAULT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_balance_bounds ALTER COLUMN id SET DEFAULT nextval('public.zkapp_balance_bounds_id_seq'::regclass);


--
-- Name: zkapp_commands id; Type: DEFAULT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_commands ALTER COLUMN id SET DEFAULT nextval('public.zkapp_commands_id_seq'::regclass);


--
-- Name: zkapp_epoch_data id; Type: DEFAULT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_epoch_data ALTER COLUMN id SET DEFAULT nextval('public.zkapp_epoch_data_id_seq'::regclass);


--
-- Name: zkapp_epoch_ledger id; Type: DEFAULT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_epoch_ledger ALTER COLUMN id SET DEFAULT nextval('public.zkapp_epoch_ledger_id_seq'::regclass);


--
-- Name: zkapp_events id; Type: DEFAULT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_events ALTER COLUMN id SET DEFAULT nextval('public.zkapp_events_id_seq'::regclass);


--
-- Name: zkapp_fee_payer_body id; Type: DEFAULT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_fee_payer_body ALTER COLUMN id SET DEFAULT nextval('public.zkapp_fee_payer_body_id_seq'::regclass);


--
-- Name: zkapp_global_slot_bounds id; Type: DEFAULT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_global_slot_bounds ALTER COLUMN id SET DEFAULT nextval('public.zkapp_global_slot_bounds_id_seq'::regclass);


--
-- Name: zkapp_length_bounds id; Type: DEFAULT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_length_bounds ALTER COLUMN id SET DEFAULT nextval('public.zkapp_length_bounds_id_seq'::regclass);


--
-- Name: zkapp_network_precondition id; Type: DEFAULT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_network_precondition ALTER COLUMN id SET DEFAULT nextval('public.zkapp_network_precondition_id_seq'::regclass);


--
-- Name: zkapp_nonce_bounds id; Type: DEFAULT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_nonce_bounds ALTER COLUMN id SET DEFAULT nextval('public.zkapp_nonce_bounds_id_seq'::regclass);


--
-- Name: zkapp_other_party id; Type: DEFAULT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_other_party ALTER COLUMN id SET DEFAULT nextval('public.zkapp_other_party_id_seq'::regclass);


--
-- Name: zkapp_other_party_body id; Type: DEFAULT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_other_party_body ALTER COLUMN id SET DEFAULT nextval('public.zkapp_other_party_body_id_seq'::regclass);


--
-- Name: zkapp_party_failures id; Type: DEFAULT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_party_failures ALTER COLUMN id SET DEFAULT nextval('public.zkapp_party_failures_id_seq'::regclass);


--
-- Name: zkapp_permissions id; Type: DEFAULT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_permissions ALTER COLUMN id SET DEFAULT nextval('public.zkapp_permissions_id_seq'::regclass);


--
-- Name: zkapp_precondition_accounts id; Type: DEFAULT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_precondition_accounts ALTER COLUMN id SET DEFAULT nextval('public.zkapp_precondition_accounts_id_seq'::regclass);


--
-- Name: zkapp_sequence_states id; Type: DEFAULT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_sequence_states ALTER COLUMN id SET DEFAULT nextval('public.zkapp_sequence_states_id_seq'::regclass);


--
-- Name: zkapp_state_data id; Type: DEFAULT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_state_data ALTER COLUMN id SET DEFAULT nextval('public.zkapp_state_data_id_seq'::regclass);


--
-- Name: zkapp_state_data_array id; Type: DEFAULT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_state_data_array ALTER COLUMN id SET DEFAULT nextval('public.zkapp_state_data_array_id_seq'::regclass);


--
-- Name: zkapp_states id; Type: DEFAULT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_states ALTER COLUMN id SET DEFAULT nextval('public.zkapp_states_id_seq'::regclass);


--
-- Name: zkapp_states id; Type: DEFAULT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_states_nullable ALTER COLUMN id SET DEFAULT nextval('public.zkapp_states_nullable_id_seq'::regclass);


--
-- Name: zkapp_timestamp_bounds id; Type: DEFAULT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_timestamp_bounds ALTER COLUMN id SET DEFAULT nextval('public.zkapp_timestamp_bounds_id_seq'::regclass);


--
-- Name: zkapp_timing_info id; Type: DEFAULT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_timing_info ALTER COLUMN id SET DEFAULT nextval('public.zkapp_timing_info_id_seq'::regclass);


--
-- Name: zkapp_token_id_bounds id; Type: DEFAULT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_token_id_bounds ALTER COLUMN id SET DEFAULT nextval('public.zkapp_token_id_bounds_id_seq'::regclass);


--
-- Name: zkapp_updates id; Type: DEFAULT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_updates ALTER COLUMN id SET DEFAULT nextval('public.zkapp_updates_id_seq'::regclass);


--
-- Name: zkapp_uris id; Type: DEFAULT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_uris ALTER COLUMN id SET DEFAULT nextval('public.zkapp_uris_id_seq'::regclass);


--
-- Name: zkapp_verification_keys id; Type: DEFAULT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_verification_keys ALTER COLUMN id SET DEFAULT nextval('public.zkapp_verification_keys_id_seq'::regclass);


--
-- Data for Name: account_identifiers; Type: TABLE DATA; Schema: public;
--

COPY public.account_identifiers (id, public_key_id, token_id) FROM stdin;
1	2	1
2	3	1
3	4	1
4	5	1
5	1	1
6	6	1
7	7	1
\.


--
-- Data for Name: accounts_accessed; Type: TABLE DATA; Schema: public;
--

COPY public.accounts_accessed (ledger_index, block_id, account_identifier_id, token_symbol_id, balance, nonce, receipt_chain_hash, delegate_id, voting_for_id, timing_id, permissions_id, zkapp_id) FROM stdin;
5	1	1	1	0	293	2mzaNmmgKfkbziZZgGhdyMjYXgpnLDSZb3zsMmR7atQudvXuXFDn	2	1	1	1	\N
2	1	2	1	1000000000000000000	30	2n28bLJpCLPYEgNqp7rQosEHQdfqSzBSjwX52jMDZbe34d9wExef	3	1	2	2	\N
1	1	3	1	1000000000000000000	0	2mzhRazYextcWnQ81n5CGTrFD2Rx5dAS6rYjAeYCEyfhUjZUzYFy	1	1	3	3	\N
3	1	4	1	100000000000000000	1	2n16Uzkm9ABP5XHKJj81zD3EnbURJf5GykKxhNRrspMus1NNeXvL	5	1	4	4	\N
0	1	5	1	1000000000000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	1	1	5	3	\N
4	1	6	1	0	907	2n1VHJxAsZy8krLNTbTocdwMh2XLEexuz1Y21QJgMVNQjDGCqhKk	6	1	6	3	\N
5	2	1	1	14000000000	293	2mzaNmmgKfkbziZZgGhdyMjYXgpnLDSZb3zsMmR7atQudvXuXFDn	2	1	1	1	\N
2	2	2	1	999999982500000000	44	2n1qKQpPxZ6dgRThwTiJJL5g3Rjc1srZqXRMwyhAzJ1NRn733mPF	3	1	2	2	\N
5	3	1	1	28000000000	293	2mzaNmmgKfkbziZZgGhdyMjYXgpnLDSZb3zsMmR7atQudvXuXFDn	2	1	1	1	\N
2	3	2	1	999999965000000000	58	2n22YNTTd6tBke6uDtG2gHjZXjKoYqegQ11Z9jNx9P4Rnb3As14o	3	1	2	2	\N
5	4	1	1	42000000000	293	2mzaNmmgKfkbziZZgGhdyMjYXgpnLDSZb3zsMmR7atQudvXuXFDn	2	1	1	1	\N
2	4	2	1	999999947500000000	72	2mzyVwjutC1anYhsKV7HA2kfi9aF6cF51PYb2hmRg558cibcK4dh	3	1	2	2	\N
5	5	1	1	48000000000	293	2mzaNmmgKfkbziZZgGhdyMjYXgpnLDSZb3zsMmR7atQudvXuXFDn	2	1	1	1	\N
2	5	2	1	999999940000000000	78	2n1369k7n6h45hPjXYxrj5n3dxYGurG2k3x6xisEDGBaZFjovinx	3	1	2	2	\N
5	17	1	1	56000000000	293	2mzaNmmgKfkbziZZgGhdyMjYXgpnLDSZb3zsMmR7atQudvXuXFDn	2	1	1	1	\N
2	17	2	1	999999930000000000	86	2n29txn199rGAakn2Y1BVvj3SquAG8njLkLN9rcjvR1aK4UVJFmF	3	1	2	2	\N
6	17	7	1	9000000000	0	2n1fFmqwGbMqbeDwEjQZXoiEU9YfL7XsRENXYv4U83SUcvEBVRT1	7	1	7	5	1
0	17	5	1	999999986400000000	2	2n2DqVVxHDNUQG7SuXf855SNyjMuBBHoMDHVuRH2iifCQ1uD77Wn	1	1	5	3	\N
5	18	1	1	65000000000	293	2mzaNmmgKfkbziZZgGhdyMjYXgpnLDSZb3zsMmR7atQudvXuXFDn	2	1	1	1	\N
2	18	2	1	999999918750000000	95	2n1DaCAMMLmrU2589wMCW4hyX7X6vy1V11PtE2bpueWud5Hvqw8k	3	1	2	2	\N
0	18	5	1	999999986600000000	2	2n2DqVVxHDNUQG7SuXf855SNyjMuBBHoMDHVuRH2iifCQ1uD77Wn	1	1	5	3	\N
2	19	2	1	999999918750000000	95	2n1DaCAMMLmrU2589wMCW4hyX7X6vy1V11PtE2bpueWud5Hvqw8k	3	1	2	2	\N
5	20	1	1	78000000000	293	2mzaNmmgKfkbziZZgGhdyMjYXgpnLDSZb3zsMmR7atQudvXuXFDn	2	1	1	1	\N
2	20	2	1	999999902500000000	108	2n1DaHBDefDqgWQzABW87QcZawvGmkqJpbiMkewgVLfWjKQKBhrF	3	1	2	2	\N
6	20	7	1	9000000000	0	2n1kz3cmjPotKVE4h699V86d1Va6FqnWNpEwH1ypntVxS2HJn9tB	7	1	7	5	2
0	20	5	1	999999982400000000	3	2n1sv6F33ojLoRweogGK87GDyAkeVSUUstPTmMT1NEFDsrQVZ6aX	1	1	5	3	\N
5	21	1	1	92000000000	293	2mzaNmmgKfkbziZZgGhdyMjYXgpnLDSZb3zsMmR7atQudvXuXFDn	2	1	1	1	\N
2	21	2	1	999999885000000000	122	2mzX3Abv4A8G75Cm7zRrQDRPmnMbFXguPL6haTJaLGuUzud9YyiD	3	1	2	2	\N
0	21	5	1	999999983600000000	3	2n1sv6F33ojLoRweogGK87GDyAkeVSUUstPTmMT1NEFDsrQVZ6aX	1	1	5	3	\N
\.


--
-- Data for Name: accounts_created; Type: TABLE DATA; Schema: public;
--

COPY public.accounts_created (block_id, account_identifier_id, creation_fee) FROM stdin;
17	7	1000000000
\.


--
-- Data for Name: blocks; Type: TABLE DATA; Schema: public;
--

COPY public.blocks (id, state_hash, parent_id, parent_hash, creator_id, block_winner_id, snarked_ledger_hash_id, staking_epoch_data_id, next_epoch_data_id, min_window_density, total_currency, ledger_hash, height, global_slot_since_hard_fork, global_slot_since_genesis, "timestamp", chain_status) FROM stdin;
1	3NLt1r77r7z7VEX4tACzHc9qC9Rz5GqYSXtufFhpE85tWVoYrx8z	\N	3NLeQxhRU3qHv34vHNUwD2ht9gzW3ioAGqBmVwXjYhsSDHPuBDQn	1	1	1	1	2	77	3100000000000000000	jwygs7rxLrSg7hHkMcHzG66R6c1Ve9vJRyrvrVpS9bKcT4iC7Qy	1	0	0	1659993000000	canonical
2	3NLPC2srDPVxrf4TqpsznL7CTeT6B8pPZYwNCHyizxaSznu6XoUA	1	3NLt1r77r7z7VEX4tACzHc9qC9Rz5GqYSXtufFhpE85tWVoYrx8z	3	3	1	1	3	77	3100000000000000000	jxv79AJoBRBWaT7WcvKChaqucR9BqrAzc6Ya3cZAnbxn94RCKqY	2	22	22	1659993660000	pending
3	3NLxg96L88SBKKVgWgxcDLpTbCFfftbzCMepbhTBrHxLAcTiv4An	2	3NLPC2srDPVxrf4TqpsznL7CTeT6B8pPZYwNCHyizxaSznu6XoUA	3	3	1	1	4	77	3100000000000000000	jx3EPWuSmaoMGYbtEoMYHVkhbBNDr2cFuGqY1dAYrcuukQket64	3	24	24	1659993720000	pending
4	3NKAwzwaGhdXYs2iEJPj7cnfgfcRkHmRo9kFfB2DRdUM4NsmNnk8	3	3NLxg96L88SBKKVgWgxcDLpTbCFfftbzCMepbhTBrHxLAcTiv4An	3	3	1	1	5	77	3100000000000000000	jwj33aFA7iunt1GuDzDBVd4tzLkHsXWXUQsq7KgNWL2GZovkaCv	4	26	26	1659993780000	pending
5	3NKPsYafv3sqCRymAw3hyYbdnpR1rkz5uESW46gA1pme1isBQ8z9	4	3NKAwzwaGhdXYs2iEJPj7cnfgfcRkHmRo9kFfB2DRdUM4NsmNnk8	3	3	1	1	6	77	3100000000000000000	jxHvVw6rNcY4DoYutEGkwBH78XqDUce4NuEzfWZxKiE7QKjfWug	5	28	28	1659993840000	pending
6	3NLr8y5CxQST5f5QK7LdfL9J1Bnuu5c5iZJ4YPTCfDyWmCKbEX4b	5	3NKPsYafv3sqCRymAw3hyYbdnpR1rkz5uESW46gA1pme1isBQ8z9	3	3	1	1	7	77	3100000000000000000	jwWs7Mg1i63LEAYRUnkjzsqJvnUMmtWW9SC88jcM55k3PZ4A7c7	6	31	31	1659993930000	pending
7	3NKvv85heSwz5rwAbT7KFxrHZoGGnmwZHhBW952t5Waq1yM3YtS5	6	3NLr8y5CxQST5f5QK7LdfL9J1Bnuu5c5iZJ4YPTCfDyWmCKbEX4b	3	3	1	1	8	77	3100000000000000000	jwWs7Mg1i63LEAYRUnkjzsqJvnUMmtWW9SC88jcM55k3PZ4A7c7	7	33	33	1659993990000	pending
8	3NLAtWGLyAsD9biM2tx6djxKGaUR8FwWm3VCFSmSZNxej2mWu4ck	7	3NKvv85heSwz5rwAbT7KFxrHZoGGnmwZHhBW952t5Waq1yM3YtS5	3	3	1	1	9	77	3100000000000000000	jwWs7Mg1i63LEAYRUnkjzsqJvnUMmtWW9SC88jcM55k3PZ4A7c7	8	36	36	1659994080000	pending
9	3NKbHF74kYziUcz9ZWM46NDPjLX2PfcKUfAUArTnrBvXAbCmTtj2	8	3NLAtWGLyAsD9biM2tx6djxKGaUR8FwWm3VCFSmSZNxej2mWu4ck	3	3	1	1	10	77	3100000000000000000	jwWs7Mg1i63LEAYRUnkjzsqJvnUMmtWW9SC88jcM55k3PZ4A7c7	9	41	41	1659994230000	pending
10	3NLa1kjXbughbC7wtHwu5v6PTGeog7nFNQfqefvq8FXbP6LjkhBh	9	3NKbHF74kYziUcz9ZWM46NDPjLX2PfcKUfAUArTnrBvXAbCmTtj2	3	3	1	1	11	77	3100000000000000000	jwWs7Mg1i63LEAYRUnkjzsqJvnUMmtWW9SC88jcM55k3PZ4A7c7	10	42	42	1659994260000	pending
11	3NKuxCfPPzdyYuJkMNF2F4EbYyfHE5Mfm9mfjcWxwHUBjfmEfAjd	10	3NLa1kjXbughbC7wtHwu5v6PTGeog7nFNQfqefvq8FXbP6LjkhBh	3	3	1	1	12	77	3100000000000000000	jwWs7Mg1i63LEAYRUnkjzsqJvnUMmtWW9SC88jcM55k3PZ4A7c7	11	44	44	1659994320000	pending
12	3NLSX5JHft5cMgzBP3qdaf4ejPux3g6RwSNpBdihUndCzk35ZcyL	11	3NKuxCfPPzdyYuJkMNF2F4EbYyfHE5Mfm9mfjcWxwHUBjfmEfAjd	3	3	1	1	13	77	3100000000000000000	jwWs7Mg1i63LEAYRUnkjzsqJvnUMmtWW9SC88jcM55k3PZ4A7c7	12	46	46	1659994380000	pending
13	3NKvChb8G72hQBHzr7nn7AHrafGopf4xkzNk3bzZPjd1cDgS1LF6	12	3NLSX5JHft5cMgzBP3qdaf4ejPux3g6RwSNpBdihUndCzk35ZcyL	3	3	1	1	14	77	3100000000000000000	jwWs7Mg1i63LEAYRUnkjzsqJvnUMmtWW9SC88jcM55k3PZ4A7c7	13	47	47	1659994410000	pending
14	3NKUXRQ1G7XeZ9itcp766STsZD9EjDcf3mpYT3X7AsMrgArSq4s8	13	3NKvChb8G72hQBHzr7nn7AHrafGopf4xkzNk3bzZPjd1cDgS1LF6	3	3	1	1	15	77	3100000000000000000	jwWs7Mg1i63LEAYRUnkjzsqJvnUMmtWW9SC88jcM55k3PZ4A7c7	14	48	48	1659994440000	pending
15	3NLVZy6T83Jn1pfdcwz6GSmirP8SQYSV6Fwv2gCuKpLDcyQP13mH	14	3NKUXRQ1G7XeZ9itcp766STsZD9EjDcf3mpYT3X7AsMrgArSq4s8	3	3	1	1	16	77	3100000000000000000	jwWs7Mg1i63LEAYRUnkjzsqJvnUMmtWW9SC88jcM55k3PZ4A7c7	15	49	49	1659994470000	pending
16	3NLCqsJpwVxSC7gKUVEkCb3PmCvf3CcX52CtSG3xjhcSzopg5NZJ	15	3NLVZy6T83Jn1pfdcwz6GSmirP8SQYSV6Fwv2gCuKpLDcyQP13mH	3	3	1	1	17	77	3100000000000000000	jwWs7Mg1i63LEAYRUnkjzsqJvnUMmtWW9SC88jcM55k3PZ4A7c7	16	50	50	1659994500000	pending
17	3NLjjx7dm6Bc3D5bc2cNAecuPyhYum9PoX7DYUHGYvS3qc551j1M	16	3NLCqsJpwVxSC7gKUVEkCb3PmCvf3CcX52CtSG3xjhcSzopg5NZJ	3	3	1	1	18	77	3100000000000000000	jxTEKWT4TzqfwTM1GVPQQstzspM79jQDh6kr4h4yh7nxF2XUKeg	17	56	56	1659994680000	pending
18	3NKmDH5RAujPGiX76vwhV6HFsAjN2vvkHjkQcveExvDywyykLeaL	17	3NLjjx7dm6Bc3D5bc2cNAecuPyhYum9PoX7DYUHGYvS3qc551j1M	3	3	1	1	19	77	3100000000000000000	jwE7UX5hnkdU3ixaT9qMp8nNbpQMVoF3JTcFfYC3zDx5eDhSUYa	18	57	57	1659994710000	pending
19	3NLJ3QfoaRBs2sMj2dpx1dYAgQoe9tLAFNb19ijBnyzAWafF1KBm	18	3NKmDH5RAujPGiX76vwhV6HFsAjN2vvkHjkQcveExvDywyykLeaL	3	3	1	1	20	77	3100000000000000000	jwE7UX5hnkdU3ixaT9qMp8nNbpQMVoF3JTcFfYC3zDx5eDhSUYa	19	60	60	1659994800000	pending
20	3NL1XVgg2DAjSjVStzXmeQnRunV7Pp1B4cYQ27VtN3Q6esAZ5ufp	19	3NLJ3QfoaRBs2sMj2dpx1dYAgQoe9tLAFNb19ijBnyzAWafF1KBm	3	3	1	1	21	77	3100000000000000000	jxPGrPkYKZdZR37z9R3tQ41YNtME7NNH6A3Gc1pPs7NJPBapE7Y	20	65	65	1659994950000	pending
21	3NKKXz5f8zUEb5PyoW1faVfJqsHnBvzrK58XJdxoNGaMenfWcw5w	20	3NL1XVgg2DAjSjVStzXmeQnRunV7Pp1B4cYQ27VtN3Q6esAZ5ufp	3	3	1	1	22	77	3100000000000000000	jxB6TZLAwf3QetUjojQSR71U7fJNWPMgi5NccspAdJoPkFgJL7i	21	68	68	1659995040000	pending
\.


--
-- Data for Name: blocks_internal_commands; Type: TABLE DATA; Schema: public;
--

COPY public.blocks_internal_commands (block_id, internal_command_id, sequence_no, secondary_sequence_no, status, failure_reason) FROM stdin;
2	1	14	0	failed	Update_not_permitted_balance
2	2	15	0	failed	Update_not_permitted_balance
3	1	14	0	failed	Update_not_permitted_balance
3	2	15	0	failed	Update_not_permitted_balance
4	1	14	0	failed	Update_not_permitted_balance
4	2	15	0	failed	Update_not_permitted_balance
5	1	6	0	failed	Update_not_permitted_balance
5	3	7	0	failed	Update_not_permitted_balance
17	4	7	0	failed	Update_not_permitted_balance
17	5	7	1	applied	\N
17	6	10	0	applied	\N
17	7	10	0	failed	Update_not_permitted_balance
17	8	11	0	applied	\N
18	6	9	0	applied	\N
18	7	9	0	failed	Update_not_permitted_balance
18	9	10	0	failed	Update_not_permitted_balance
18	10	10	1	applied	\N
19	1	0	0	failed	Update_not_permitted_balance
20	6	14	0	applied	\N
20	7	14	0	failed	Update_not_permitted_balance
20	11	15	0	failed	Update_not_permitted_balance
20	12	15	1	applied	\N
21	6	14	0	applied	\N
21	7	14	0	failed	Update_not_permitted_balance
21	13	15	0	failed	Update_not_permitted_balance
21	14	15	1	applied	\N
\.


--
-- Data for Name: blocks_user_commands; Type: TABLE DATA; Schema: public;
--

COPY public.blocks_user_commands (block_id, user_command_id, sequence_no, status, failure_reason) FROM stdin;
2	1	0	applied	\N
2	2	1	applied	\N
2	3	2	applied	\N
2	4	3	applied	\N
2	5	4	applied	\N
2	6	5	applied	\N
2	7	6	applied	\N
2	8	7	applied	\N
2	9	8	applied	\N
2	10	9	applied	\N
2	11	10	applied	\N
2	12	11	applied	\N
2	13	12	applied	\N
2	14	13	applied	\N
3	15	0	applied	\N
3	16	1	applied	\N
3	17	2	applied	\N
3	18	3	applied	\N
3	19	4	applied	\N
3	20	5	applied	\N
3	21	6	applied	\N
3	22	7	applied	\N
3	23	8	applied	\N
3	24	9	applied	\N
3	25	10	applied	\N
3	26	11	applied	\N
3	27	12	applied	\N
3	28	13	applied	\N
4	29	0	applied	\N
4	30	1	applied	\N
4	31	2	applied	\N
4	32	3	applied	\N
4	33	4	applied	\N
4	34	5	applied	\N
4	35	6	applied	\N
4	36	7	applied	\N
4	37	8	applied	\N
4	38	9	applied	\N
4	39	10	applied	\N
4	40	11	applied	\N
4	41	12	applied	\N
4	42	13	applied	\N
5	43	0	applied	\N
5	44	1	applied	\N
5	45	2	applied	\N
5	46	3	applied	\N
5	47	4	applied	\N
5	48	5	applied	\N
17	49	1	applied	\N
17	50	2	applied	\N
17	51	3	applied	\N
17	52	4	applied	\N
17	53	5	applied	\N
17	54	6	applied	\N
17	55	8	applied	\N
17	56	9	applied	\N
18	57	0	applied	\N
18	58	1	applied	\N
18	59	2	applied	\N
18	60	3	applied	\N
18	61	4	applied	\N
18	62	5	applied	\N
18	63	6	applied	\N
18	64	7	applied	\N
18	65	8	applied	\N
20	66	1	applied	\N
20	67	2	applied	\N
20	68	3	applied	\N
20	69	4	applied	\N
20	70	5	applied	\N
20	71	6	applied	\N
20	72	7	applied	\N
20	73	8	applied	\N
20	74	9	applied	\N
20	75	10	applied	\N
20	76	11	applied	\N
20	77	12	applied	\N
20	78	13	applied	\N
21	79	0	applied	\N
21	80	1	applied	\N
21	81	2	applied	\N
21	82	3	applied	\N
21	83	4	applied	\N
21	84	5	applied	\N
21	85	6	applied	\N
21	86	7	applied	\N
21	87	8	applied	\N
21	88	9	applied	\N
21	89	10	applied	\N
21	90	11	applied	\N
21	91	12	applied	\N
21	92	13	applied	\N
\.


--
-- Data for Name: blocks_zkapp_commands; Type: TABLE DATA; Schema: public;
--

COPY public.blocks_zkapp_commands (block_id, zkapp_command_id, sequence_no, status, failure_reasons_ids) FROM stdin;
17	1	0	applied	\N
20	2	0	applied	\N
\.


--
-- Data for Name: epoch_data; Type: TABLE DATA; Schema: public;
--

COPY public.epoch_data (id, seed, ledger_hash_id, total_currency, start_checkpoint, lock_checkpoint, epoch_length) FROM stdin;
1	2va9BGv9JrLTtrzZttiEMDYw1Zj6a6EHzXjmP9evHDTG3oEquURA	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	1
2	2vc1zQHJx2xN72vaR4YDH31KwFSr5WHSEH2dzcfcq8jxBPcGiJJA	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLeQxhRU3qHv34vHNUwD2ht9gzW3ioAGqBmVwXjYhsSDHPuBDQn	2
3	2vaoYJMbGeaCKC1Y964DYdQJf4KUAM2x95jxRtfSQLChyNYaMt38	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLt1r77r7z7VEX4tACzHc9qC9Rz5GqYSXtufFhpE85tWVoYrx8z	3
4	2vc5S4ETjcLmVj3ai8aEyWBqXVgvoR7x5iYHjaPVNdbiYEvAD6xB	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLPC2srDPVxrf4TqpsznL7CTeT6B8pPZYwNCHyizxaSznu6XoUA	4
5	2vaquGxFkbUNT2qBBp2qo2BkUw5NYGEAX6AG6zb11hXgwVERkfCf	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLxg96L88SBKKVgWgxcDLpTbCFfftbzCMepbhTBrHxLAcTiv4An	5
6	2vagXwVoN6a6is1xj3T7KeuMUgZJ18MUMfeiZhoEEv2mNWnZ3sXy	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKAwzwaGhdXYs2iEJPj7cnfgfcRkHmRo9kFfB2DRdUM4NsmNnk8	6
7	2vbjR9Ghbc8HWdAq1feu6PfXD8FV81cvNjVJbJE6LTN5oiCptRKr	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKPsYafv3sqCRymAw3hyYbdnpR1rkz5uESW46gA1pme1isBQ8z9	7
8	2vbRDgZ499F3NARGUFv4ZEsqoXsWQqHwbNvk8rH7nw5WrTqgw5TA	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLr8y5CxQST5f5QK7LdfL9J1Bnuu5c5iZJ4YPTCfDyWmCKbEX4b	8
9	2vb8xzFxVcQzpJBQtKMvHzEvGDR9XvY2ovXJzJ8U9CaLQrcmjW9N	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKvv85heSwz5rwAbT7KFxrHZoGGnmwZHhBW952t5Waq1yM3YtS5	9
10	2vbNmcxhZEDnuq7SWq2c45UeStNyN522L3KB2PMvUZKV8uWH5bQA	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLAtWGLyAsD9biM2tx6djxKGaUR8FwWm3VCFSmSZNxej2mWu4ck	10
11	2vab6uRnQR8MRn1CcuzFhTYzpXacPaC99EuRP4Bfj8WLPr7AcxCE	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKbHF74kYziUcz9ZWM46NDPjLX2PfcKUfAUArTnrBvXAbCmTtj2	11
12	2vbhbxY1dFoTFtkztfsF6ZPedLNnvH7chqbxWXofYk1z55rsxG8p	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLa1kjXbughbC7wtHwu5v6PTGeog7nFNQfqefvq8FXbP6LjkhBh	12
13	2vaFY4nw4LgmCbQAgLVw9uaHArjeNF2u7aD9RCjUc8KzAAUayjk4	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKuxCfPPzdyYuJkMNF2F4EbYyfHE5Mfm9mfjcWxwHUBjfmEfAjd	13
14	2vbUSAnGMnmFmW5fY3qg41ZwW6FPPJAC28NtHdFiR5e7wBJ77Fv3	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLSX5JHft5cMgzBP3qdaf4ejPux3g6RwSNpBdihUndCzk35ZcyL	14
15	2vawCNLq4GC4Hj5NMWuDkfJTTRmRD3dDgKFSUzmKw1Lr56DtQWD3	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKvChb8G72hQBHzr7nn7AHrafGopf4xkzNk3bzZPjd1cDgS1LF6	15
16	2vbrkuYB6jyEV1mYSE47ysRgykjA5YJE8JqjmtUzzaCmpPiisjWH	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKUXRQ1G7XeZ9itcp766STsZD9EjDcf3mpYT3X7AsMrgArSq4s8	16
17	2vb65YA8q1V71uE5czXVJvsgZidwPw2ssKvNcPzUKhw9dprCHwt8	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLVZy6T83Jn1pfdcwz6GSmirP8SQYSV6Fwv2gCuKpLDcyQP13mH	17
18	2vbCUqiwPYceaVDCPXAiPh3wnYbTkpwDmSEvgr9QnEqub9KBgYBr	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLCqsJpwVxSC7gKUVEkCb3PmCvf3CcX52CtSG3xjhcSzopg5NZJ	18
19	2vbvcyAVAqwWuqXnrSfRYJBSzaPCoHeUnom3gg2B38fNvVuGV9GK	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLjjx7dm6Bc3D5bc2cNAecuPyhYum9PoX7DYUHGYvS3qc551j1M	19
20	2vbG5QuX7USejRQD5ezkvqz7zu4TheR2uMUy4utkX6ZaTHNDvqpa	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKmDH5RAujPGiX76vwhV6HFsAjN2vvkHjkQcveExvDywyykLeaL	20
21	2vbbga57BuMCXfN4NA4DBpQva7qno4Tmav1zwKCQQhxj5AdwBgCy	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLJ3QfoaRBs2sMj2dpx1dYAgQoe9tLAFNb19ijBnyzAWafF1KBm	21
22	2vbc2MstFxMuQNDMGKeksUjmsBjYoszPtwqxP2sQPKa2PE3PAcLm	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NL1XVgg2DAjSjVStzXmeQnRunV7Pp1B4cYQ27VtN3Q6esAZ5ufp	22
\.


--
-- Data for Name: internal_commands; Type: TABLE DATA; Schema: public;
--

COPY public.internal_commands (id, typ, receiver_id, fee, hash) FROM stdin;
1	coinbase	2	1440000000000	CkpZPC8P5wJ5zoMsUnwQ4yzMggpeifgXEtKG8L1qmsSZqAUaTGyHj
2	fee_transfer	2	3500000000	CkpaKi6CtGXrNuB8NgSpH3wFkqeUNadD1BiXk41PpdGcHUnsRLYV7
3	fee_transfer	2	1500000000	CkpZGU5BN9RcNywUqbNQ6ZUDmWM4MAAK9PcnTYASi7LXuKAbfMYQQ
4	fee_transfer	2	5700000000	CkpYwUmWjt4kE6YjJvmL9DNN2t2bwdas9E5kwhPEhZ1LV4WGcD5rQ
5	fee_transfer	5	800000000	CkpZYU1V9igeBcMzLgw7hSBPDvUJrKSzLKKzRXe2CQsnYc3sFmNAy
6	fee_transfer_via_coinbase	5	100000000	CkpZn74H3AFg759yTDZHD262L1ge1Qw9mnpSALcARPYK6Q2caYJav
7	coinbase	2	1440000000000	CkpYaa2YH3qBxFsnfANLv7LX6bFTLVaPGBS4D3MnbdtRWvysHQh1w
8	fee_transfer	5	500000000	CkpZU7ympNPDWaoLyEACkvsaSaYfoK6bw3vhqp8GLVUoWGHnGHNqi
9	fee_transfer	2	2150000000	CkpZeeDUcvAG2uFWqC5yraH9AyyLx6CsTbYFYkkiqg78zffe6XCLu
10	fee_transfer	5	100000000	CkpZn74H3AFg759yTDZHD262L1ge1Qw9mnpSALcARPYK6Q2caYJav
11	fee_transfer	2	7550000000	CkpYsrxzTgJ86XCxu6MFUkxyAVN6pHRXSLoKLNQ5xZdvkwvcCsfFY
12	fee_transfer	5	700000000	CkpZTai4Rc8WMBsG4faaue92amBWxqK8PZtRPEsEguD7ZE5PEji49
13	fee_transfer	2	2400000000	CkpZvybgvr57HU7N5SeypiFVQiH5TyVe3xap7QuE2AKAwmKiXsD1A
14	fee_transfer	5	1100000000	CkpZdMrssEfU2ZDCZULbp7yuCmo2PYQvDTGBwd6yiigfS8JHAnBrb
\.


--
-- Data for Name: public_keys; Type: TABLE DATA; Schema: public;
--

COPY public.public_keys (id, value) FROM stdin;
1	B62qiy32p8kAKnny8ZFwoMhYpBppM1DWVCqAPBYNcXnsAHhnfAAuXgg
2	B62qjW4wkRcDv3Z6GWd83LK4NcGe6id4fKPmNybjFSDvCDs5uizf8Lj
3	B62qrbENDJv8qrQ5sJoGhzmA7rxT571StwTzqZ8veiPMh5guLcPQ6XW
4	B62qjJwgq7kNXYHXQsMeyiMWL7fHsnPeuAiPfYd3yTor3eKpK8VV1gG
5	B62qjwvvHoM9RVt9onMpSMS5rFzhy3jjXY1Q9JU7HyHW4oWFEbWpghe
6	B62qpgJJN3ZE56rVN8Q8Gx6XsGMkiESqDnnjAC8AtLrkioxqo2gD4wt
7	B62qnxpzcsqdhZS5W4AAjhWTKANVo2i3FXUwkb647tqzChzo7VtTw6N
\.


--
-- Data for Name: snarked_ledger_hashes; Type: TABLE DATA; Schema: public;
--

COPY public.snarked_ledger_hashes (id, value) FROM stdin;
1	jxEzgdFtsDh5AFv7YBMERSDvfCDoNfqHMtBamAtS6XgNhhvSsFu
\.


--
-- Data for Name: timing_info; Type: TABLE DATA; Schema: public;
--

COPY public.timing_info (id, account_identifier_id, initial_minimum_balance, cliff_time, cliff_amount, vesting_period, vesting_increment) FROM stdin;
1	1	0	0	0	0	0
2	2	0	0	0	0	0
3	3	0	0	0	0	0
4	4	0	0	0	0	0
5	5	0	0	0	0	0
6	6	0	0	0	0	0
7	7	0	0	0	0	0
\.


--
-- Data for Name: token_symbols; Type: TABLE DATA; Schema: public;
--

COPY public.token_symbols (id, value) FROM stdin;
1	
\.


--
-- Data for Name: tokens; Type: TABLE DATA; Schema: public;
--

COPY public.tokens (id, value, owner_public_key_id, owner_token_id) FROM stdin;
1	wSHV2S4qX9jFsLjQo8r1BsMLH2ZRKsZx6EJd1sbozGPieEC4Jf	\N	\N
\.


--
-- Data for Name: user_commands; Type: TABLE DATA; Schema: public;
--

COPY public.user_commands (id, typ, fee_payer_id, source_id, receiver_id, nonce, amount, fee, valid_until, memo, hash) FROM stdin;
1	payment	2	2	1	30	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZcwMTKuth1tPqomkFeYmsSkbqXNvzr9PsZKs6yTZDpvn7BwJpR
2	payment	2	2	1	31	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZgMW3vCgskUnMLzLUngHKADPw72bWYWEeeCYmBsd9be1Nwtmzq
3	payment	2	2	1	32	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZm3VfGE7AU8mMo2YZosE1VodqQYzZHzNc61xJvFTbhXbASbWUC
4	payment	2	2	1	33	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZzYEUEqL5cfsWy9DA5GJLuQCYPnY5vXtANqcupUEPyChqzASko
5	payment	2	2	1	34	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYky7f8mo9uBCsE5ez1XdsyUqoKfQ5E4AUHRPSCnrC8X3EJV1qe
6	payment	2	2	1	35	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYq44uQtoCCcYhpfUw87UsuU3Aw3A6ZUtiDozNNXnj7bSyKjuJL
7	payment	2	2	1	36	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZgT33r4MvyDtAW6XfWgRUjmKAFpXE8feupXWagfMSdsvo8262R
8	payment	2	2	1	37	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYtm1t5MDKH1jBzGsNkPWP998aGQmeMfikL3cPq5botNjPPG6a6
9	payment	2	2	1	38	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYSe1MWuRmZNuY3R91eF66oEfvUx9hmGSR5XUroAGdmP4FvtCoU
10	payment	2	2	1	39	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZ21DR7h1F6tSP2NyGTBxSLYSEeWfF8vo872fKSuDVV51N4dSoV
11	payment	2	2	1	40	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZntWcPNogDM5KYrnQL2Rj6bzW1TLciANdWsj8HJn7E2j3RUj8G
12	payment	2	2	1	41	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYZKsQdRyt9WnRjaghSTfy9KoKHFuohX1P3dpn9JdC2sT3VDfLD
13	payment	2	2	1	42	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZfu7ufuMkjwY4rtijB1nBBhnME8ZAXdyyFrV4gymDRJwcKiVCA
14	payment	2	2	1	43	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYVVFzVBPDFqHkonmyNVSHmeMEp5ym2veDL89PHvw3AgX7xK27d
15	payment	2	2	1	44	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZzAbxgNz3H7wvcwEmBhVgxFkh9GTKVjP85oDPF6uX3Aj1sDr2L
16	payment	2	2	1	45	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZvF1QABMUwA8XL45zHiGfkoeUrwjBw9BviU49RAWt63nE3h5UW
17	payment	2	2	1	46	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYhbJvdb5f4ysvr1TcBYnxBncDbtpFhtdTLaseUj2Fs9EyLr2f8
18	payment	2	2	1	47	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZR6ESGbFoGuixF8NPf6QdPozenHDeQkYHfpaKrnELppaRyP7EJ
19	payment	2	2	1	48	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	Ckpa1s7WCb2vmjDoHrTsbogH9NcLXmkAS8uWFH9ytkoiMp2ZEdoM5
20	payment	2	2	1	49	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZfZ6ZHdEYBQ4Jp7DUVpSeVMb1s5eFNfD2L5uEN5xnKAUdyyejC
21	payment	2	2	1	50	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	Ckpa8aVVrEi92XRTBHmL2NotNDx1R6uEUFLzpGipuw3Y6zhKxqGZQ
22	payment	2	2	1	51	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYrSWXURWySMQiw2MvYhoakAkn5f368qKEHV47dUmwSCuTREVPa
23	payment	2	2	1	52	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZHP9GJpiw2bKZoDcEQJKrPqmKzWQsMJpJ53irkMmha61Pohxt8
24	payment	2	2	1	53	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZcAz2jyQPPUF4NMHy1Dwi5eE9QXEG2N9yRcecLYGkgm8pMEYrd
25	payment	2	2	1	54	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZbPuvFqxvHxG8zYDLNYdyxvCzZKYn76GnCxxzeZQWqiE5QQ1Fb
26	payment	2	2	1	55	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYpeQa49E7JPnexpHxSWHECJjBxKMT5s3pDKwEYzpMDwgjAG6eN
27	payment	2	2	1	56	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZZxWZQtBoGAbpMitEGkt7rUnD119ngn9kYyjuhbU9UPnX23SdN
28	payment	2	2	1	57	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYQxyPWd3aU5hXBehBDFDVE3hVikTVTVHeCTKbw36YDbXUPLU1a
29	payment	2	2	1	58	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZJ8CnmRen6T5whqXzXvYZC3D4K8z3bEgNAohg2WbLTDZf2bM1F
30	payment	2	2	1	59	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYqumCeThbqvvRVxEQkR63GHKURvTuEfbvoNt5m4zomjpXB2uzN
31	payment	2	2	1	60	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpaHsE7LnDXwBoYrXRmCyMy41Xk19DWXh466w5H7fh1g2HLEUpd3
32	payment	2	2	1	61	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZwjtpZeGESh4144PA4AeeyVH5y4sDWrLxUCwQWjn3BmN7ffgHF
33	payment	2	2	1	62	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYhQ3VGA3UWKdnmPDeUwPTsyU86QQQoaQtWUpgHd5XjvqWfRRtE
34	payment	2	2	1	63	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZkTDDyf4x6CYdvYeKaSgMDMxPA4cTAbTvGMaxh3RnUSMnsn5eq
35	payment	2	2	1	64	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYj27sorWMRE7qyLbSYK2Nw7A6hJtL24VVz5hijuggD1Paxj7QA
36	payment	2	2	1	65	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZqvsH5taCpQvSFJSLTo5AnMub8CgKSPavjdEN8p9DwDXWjZEwj
37	payment	2	2	1	66	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZhCCVrWZpY5RmjkoRRyYSuCCkGSBfKRxzyAz6ppejvtZCccq7o
38	payment	2	2	1	67	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYsQPvFftWSuSWyWn7HbjsZZhzCNTFqYkoum7ujGusT7CXF9aTW
39	payment	2	2	1	68	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpaAWDXxXgjoxMhPodfpdMTNK6ie19CrMLFr3oAWy3Ntn3UL9Ncr
40	payment	2	2	1	69	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZ1MNgS8tcjtkNKPtaWyNgx2TKpbqJjHCUc8EVfLvCoFnXroXyx
41	payment	2	2	1	70	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZD3Cssh5EgYSJeZLW3px39H8JSW9cSoYDwfPaJMRD33gRp7aeD
42	payment	2	2	1	71	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYp2MSr7g3RyYbVFL3YHXAV5EPbPehejHKXowWxVuksEv5Rj2xT
49	payment	2	2	1	78	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZVprp3KT13Mq5XMjKFnWPbkBTFBb5TZSuewScYXd7ySB1pSyHw
50	payment	2	2	1	79	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZYF5ZJ9WbezrZ69HvVugHTFmWa6DizL7Do1fGjiz8LgWG3eztX
51	payment	2	2	1	80	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZEecYdQjLL8YYf9rz1ga3ca1eEP28s2MfFFoth7z69dDQcJvjU
52	payment	2	2	1	81	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpaLVsGCBZm9v4WbAEpiq3EvnTfJ54Hc6K2msWKrng4cqegWfWZe
53	payment	2	2	1	82	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZjBXZs8YrXGYkGXBqhcffAMN3fjcKTfq9s6iwjBJbLku7NGCvV
54	payment	2	2	1	83	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpaFAnbGH9RVwEL2joY9ob2PB6wZJqPqck4f894f27gvaomqk1ys
55	payment	2	2	1	84	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	Ckpa5zfx64HwBBPEXmyGNuLeTum99McZDLwUu3Z8pG6Xm2naMrTaW
56	payment	2	2	1	85	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYX9a4ruQto2MM1QUoxmyxn9Zy6q78ptL8z15UcADJ53t3zRBF7
43	payment	2	2	1	72	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZ3ySbK1Tg5gXjSCrgDN8TLWeFGZuNoPdQD8Aanty7wNRz9UYJt
44	payment	2	2	1	73	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZPTSrFMVw4paRnn3EpZMES3yTfCykSPen9T9o6fNhe3VRPmb4z
45	payment	2	2	1	74	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZwT4Y4R9mbVWZ83mV7m1s5Ug6PetTqcnAR1ZvH8fSg5ydPN755
46	payment	2	2	1	75	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZoMDq6wxzcyx6V3YEkaoaPeRbeegYBPCiHn7BudNibkostp8by
47	payment	2	2	1	76	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZEU2BgNvaueVYzg2TQsxzUW9sbwo2XSBJBEnz9uV9ktvdu977j
48	payment	2	2	1	77	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpaFsVhwiFSbcLvx8PUBdz4BTPXRTorvPAy17ccPmKe8CM18sKjf
57	payment	2	2	1	86	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZt7utjG2pa3YfEpMcifjq14CzN2smskqe4guRBtfw4TLkcGPfM
58	payment	2	2	1	87	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZCkhrHpXzYHXmWbkk44hHVPWUEN2339kN78BRyETtEkozJ8Uxm
59	payment	2	2	1	88	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZkmARnZoSECahVQ2f1PQxRiqmspEgFRYyxayB3Y2FkFciiXQHy
60	payment	2	2	1	89	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZsR2AC7bg9Ek4iXbiHpb4n38gP6PAAmTYUJy5JRVoTsanBQPHe
61	payment	2	2	1	90	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZJRYfsVk99nCs5FT8CNY49jkZZjHKq3D2m1jdRzPmz6RNtKqPf
62	payment	2	2	1	91	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYv2eAegmHbAeT2gWk6DHr7UVtadA8YweCraPPzhDCyYVKjcrtc
63	payment	2	2	1	92	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpaEpzDQAffkhzaHf8SMwv6d5cvffdPRyyJnK9PPim5cUE3UsQx3
64	payment	2	2	1	93	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZ2iETvkCuDpN6bsJ7t89DqxruUrYAbDKwdpDK5vuEp9cidLvmg
65	payment	2	2	1	94	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZ84jRi6qGGrUvTxxk6PifTjcJdig9PPY5JMpxgb5LeSpNCYetz
66	payment	2	2	1	95	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	Ckpa8REFiVx38SeMiMhdGe9rT5BgQfWiibpEPiQKCpGRwCHhRBUiH
67	payment	2	2	1	96	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpaJgQzdst18g5PDHFqMbtNCRH1qJ3zrgP82yMfGHfMsBCPKFvsd
68	payment	2	2	1	97	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYmReWvwNAf99ihvk9tQCFg42QFZrZBLw37hCbHtYTKfq2WzQ5j
69	payment	2	2	1	98	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYYjfLDuPrCypV4Ji9CNCSQirZC9UGyiDhRkW3mFhmPTAvLGfSP
70	payment	2	2	1	99	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYXru4DvYHDgkya8oznstT9vPonndkRymz2XCbEauHWRGEzfpvq
71	payment	2	2	1	100	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZjovc4Rqw1eg4P1X6EJ73ZTcZaxZ81RtDBboMUyMTCRwdSAjM5
72	payment	2	2	1	101	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYWJAoSTFpSNkvRE23LuZyzsPkiw8PT85nvJ49xvyuD9dETgStQ
73	payment	2	2	1	102	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZgQfYqRa6SZwpWuR9wFD6dp3acv9FMmDmexKZBoXeZiLibHnUj
74	payment	2	2	1	103	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZdB7cSGhB14dv8ykLGNfwByBKbovkASL1Eq2pUN8h6zV9Yz9dn
75	payment	2	2	1	104	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZcj6M5RMh3ZTqt8iwvuL5eU8hY2yzyts4xwx17UC5hVX8U1j7G
76	payment	2	2	1	105	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZDj45Cpun3fUvd2FTtkGEWdE9eEzfcYqFfkxkFRA5x1erjK8LK
77	payment	2	2	1	106	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpaCyKUCyKgLB8PeW3uPPijGggsgpKjrztJGgrwtMYnb7vvqWyAe
78	payment	2	2	1	107	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZoJtBLwsHGofhqRBo32r7U32KMV9DUcmdtAFmESghVKjADmv93
79	payment	2	2	1	108	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYndcQcRUeaFhrYAj5nUds1CK7UzxHjRbvhRTgVRjvDzvEqJr9v
80	payment	2	2	1	109	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZmFopPfcLDqr8zgNzyYhGtFcS3DRS6j4FJcpvMF7VFHets23XT
81	payment	2	2	1	110	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpaB7EpR9QxS8PRE4nS2H24NGoFC5K7pC9Ero2DggrJnXJtfhv3f
82	payment	2	2	1	111	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	Ckpa8P4xaPqUwJ3bSX9tEPvkGmWccdaBBvbEuwW66qTEnzmGkiS9b
83	payment	2	2	1	112	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZcU4EuUsZ1uSseaNGapgiA9mfSCMwVQvPHKUtHXQRSNFByCV5w
84	payment	2	2	1	113	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZ6FecHVT1nGUkh9FJ2gcuu8sEpDfuzAWriKwnQLQAaD7UQunNy
85	payment	2	2	1	114	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZnKwcLkQNFWSVq4naS95qpuqSSr6u48yPqhQqC2s6S7HQ8diyf
86	payment	2	2	1	115	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZDQsu93Sj9vobyjzrLuUbVDEvd6nqYmi9sxxeA1K1hCqZHLjQW
87	payment	2	2	1	116	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZuZkWJtvFBPFE4zkmLbWQSn6VUWmtjnzxBYHnRK5Khxk9UqaBS
88	payment	2	2	1	117	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZovJ2f2YhCY3JGPTPVaDC5SFKAvgfGC36Gq6RnRVwKbNZ4cTZa
89	payment	2	2	1	118	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZLdu3bgJUTju4p4242i24yecrhrja8a3wWT1B6cVPm4eFi7gS8
90	payment	2	2	1	119	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZFqr2T1KmK3hdevbVapuuxLb8CAt1EjnFDUgGN7V98tmB3JopB
91	payment	2	2	1	120	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZahmVhTybTbSNnRRUvkgJN8Qg58h7dD16vqR6uDMJnLgfu4yG8
92	payment	2	2	1	121	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpaAEULv26JzaTpLFHdjYoj977pUFaWabFqyi1QgQypF3UwznCd5
\.


--
-- Data for Name: voting_for; Type: TABLE DATA; Schema: public;
--

COPY public.voting_for (id, value) FROM stdin;
1	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x
\.


--
-- Data for Name: zkapp_account_precondition; Type: TABLE DATA; Schema: public;
--

COPY public.zkapp_account_precondition (id, kind, precondition_account_id, nonce) FROM stdin;
1	nonce	\N	1
2	accept	\N	\N
\.


--
-- Data for Name: zkapp_accounts; Type: TABLE DATA; Schema: public;
--

COPY public.zkapp_accounts (id, app_state_id, verification_key_id, zkapp_version, sequence_state_id, last_sequence_slot, proved_state, zkapp_uri_id) FROM stdin;
1	2	1	0	1	0	f	1
2	3	1	0	1	0	t	1
\.


--
-- Data for Name: zkapp_amount_bounds; Type: TABLE DATA; Schema: public;
--

COPY public.zkapp_amount_bounds (id, amount_lower_bound, amount_upper_bound) FROM stdin;
\.


--
-- Data for Name: zkapp_balance_bounds; Type: TABLE DATA; Schema: public;
--

COPY public.zkapp_balance_bounds (id, balance_lower_bound, balance_upper_bound) FROM stdin;
\.


--
-- Data for Name: zkapp_commands; Type: TABLE DATA; Schema: public;
--

COPY public.zkapp_commands (id, zkapp_fee_payer_body_id, zkapp_other_parties_ids, memo, hash) FROM stdin;
1	1	{1,2}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYRd1tx6mK7EESUupbre4dZC2md4Kek83bGTkMUemj7BZYpopN3
2	2	{3}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZ7bYXtifVFfuDoEZVtPpFq9MgNwmhBnR3jqNMknRRMD5Qdy8EC
\.


--
-- Data for Name: zkapp_epoch_data; Type: TABLE DATA; Schema: public;
--

COPY public.zkapp_epoch_data (id, epoch_ledger_id, epoch_seed, start_checkpoint, lock_checkpoint, epoch_length_id) FROM stdin;
1	1	\N	\N	\N	\N
\.


--
-- Data for Name: zkapp_epoch_ledger; Type: TABLE DATA; Schema: public;
--

COPY public.zkapp_epoch_ledger (id, hash_id, total_currency_id) FROM stdin;
1	\N	\N
\.


--
-- Data for Name: zkapp_events; Type: TABLE DATA; Schema: public;
--

COPY public.zkapp_events (id, element_ids) FROM stdin;
1	{}
\.


--
-- Data for Name: zkapp_fee_payer_body; Type: TABLE DATA; Schema: public;
--

COPY public.zkapp_fee_payer_body (id, account_identifier_id, fee, valid_until, nonce) FROM stdin;
1	5	5000000000	\N	0
2	5	5000000000	\N	2
\.


--
-- Data for Name: zkapp_global_slot_bounds; Type: TABLE DATA; Schema: public;
--

COPY public.zkapp_global_slot_bounds (id, global_slot_lower_bound, global_slot_upper_bound) FROM stdin;
\.


--
-- Data for Name: zkapp_length_bounds; Type: TABLE DATA; Schema: public;
--

COPY public.zkapp_length_bounds (id, length_lower_bound, length_upper_bound) FROM stdin;
\.


--
-- Data for Name: zkapp_network_precondition; Type: TABLE DATA; Schema: public;
--

COPY public.zkapp_network_precondition (id, snarked_ledger_hash_id, timestamp_id, blockchain_length_id, min_window_density_id, total_currency_id, curr_global_slot_since_hard_fork, global_slot_since_genesis, staking_epoch_data_id, next_epoch_data_id) FROM stdin;
1	\N	\N	\N	\N	\N	\N	\N	1	1
\.


--
-- Data for Name: zkapp_nonce_bounds; Type: TABLE DATA; Schema: public;
--

COPY public.zkapp_nonce_bounds (id, nonce_lower_bound, nonce_upper_bound) FROM stdin;
\.


--
-- Data for Name: zkapp_other_party; Type: TABLE DATA; Schema: public;
--

COPY public.zkapp_other_party (id, body_id, authorization_kind) FROM stdin;
1	1	signature
2	2	signature
3	3	proof
\.


--
-- Data for Name: zkapp_other_party_body; Type: TABLE DATA; Schema: public;
--

COPY public.zkapp_other_party_body (id, account_identifier_id, update_id, balance_change, increment_nonce, events_id, sequence_events_id, call_data_id, call_depth, zkapp_network_precondition_id, zkapp_account_precondition_id, use_full_commitment, caller) FROM stdin;
1	5	1	-10000000000	t	1	1	1	0	1	1	f	call
2	7	2	9000000000	f	1	1	1	0	1	2	t	call
3	7	3	0	f	1	1	1	0	1	2	t	call
\.


--
-- Data for Name: zkapp_party_failures; Type: TABLE DATA; Schema: public;
--

COPY public.zkapp_party_failures (id, index, failures) FROM stdin;
\.


--
-- Data for Name: zkapp_permissions; Type: TABLE DATA; Schema: public;
--

COPY public.zkapp_permissions (id, edit_state, send, receive, set_delegate, set_permissions, set_verification_key, set_zkapp_uri, edit_sequence_state, set_token_symbol, increment_nonce, set_voting_for) FROM stdin;
1	signature	signature	none	signature	proof	signature	none	signature	signature	none	none
2	signature	signature	signature	signature	signature	signature	none	none	none	none	none
3	signature	signature	none	signature	signature	signature	none	none	none	none	none
4	signature	signature	proof	signature	signature	signature	none	none	none	none	none
5	proof	signature	none	signature	signature	signature	signature	proof	signature	signature	signature
\.


--
-- Data for Name: zkapp_precondition_accounts; Type: TABLE DATA; Schema: public;
--

COPY public.zkapp_precondition_accounts (id, balance_id, nonce_id, receipt_chain_hash, delegate_id, state_id, sequence_state_id, proved_state, is_new) FROM stdin;
\.


--
-- Data for Name: zkapp_sequence_states; Type: TABLE DATA; Schema: public;
--

COPY public.zkapp_sequence_states (id, element0, element1, element2, element3, element4) FROM stdin;
1	2	2	2	2	2
\.


--
-- Data for Name: zkapp_state_data; Type: TABLE DATA; Schema: public;
--

COPY public.zkapp_state_data (id, field) FROM stdin;
1	0
2	19777675955122618431670853529822242067051263606115426372178827525373304476695
3	1
4	2
5	3
6	4
7	5
8	6
9	7
10	8
\.


--
-- Data for Name: zkapp_state_data_array; Type: TABLE DATA; Schema: public;
--

COPY public.zkapp_state_data_array (id, element_ids) FROM stdin;
\.


--
-- Data for Name: zkapp_states; Type: TABLE DATA; Schema: public;
--

COPY public.zkapp_states (id, element0, element1, element2, element3, element4, element5, element6, element7) FROM stdin;
2	1	1	1	1	1	1	1	1
3	3	4	5	6	7	8	9	10
\.


--
-- Data for Name: zkapp_states; Type: TABLE DATA; Schema: public;
--

COPY public.zkapp_states_nullable (id, element0, element1, element2, element3, element4, element5, element6, element7) FROM stdin;
1	\N	\N	\N	\N	\N	\N	\N	\N
2	1	1	1	1	1	1	1	1
3	3	4	5	6	7	8	9	10
\.


--
-- Data for Name: zkapp_timestamp_bounds; Type: TABLE DATA; Schema: public;
--

COPY public.zkapp_timestamp_bounds (id, timestamp_lower_bound, timestamp_upper_bound) FROM stdin;
\.


--
-- Data for Name: zkapp_timing_info; Type: TABLE DATA; Schema: public;
--

COPY public.zkapp_timing_info (id, initial_minimum_balance, cliff_time, cliff_amount, vesting_period, vesting_increment) FROM stdin;
\.


--
-- Data for Name: zkapp_token_id_bounds; Type: TABLE DATA; Schema: public;
--

COPY public.zkapp_token_id_bounds (id, token_id_lower_bound, token_id_upper_bound) FROM stdin;
\.


--
-- Data for Name: zkapp_updates; Type: TABLE DATA; Schema: public;
--

COPY public.zkapp_updates (id, app_state_id, delegate_id, verification_key_id, permissions_id, zkapp_uri_id, token_symbol_id, timing_id, voting_for_id) FROM stdin;
1	1	\N	\N	\N	\N	\N	\N	\N
2	1	\N	1	5	\N	\N	\N	\N
3	3	\N	\N	\N	\N	\N	\N	\N
\.


--
-- Data for Name: zkapp_uris; Type: TABLE DATA; Schema: public;
--

COPY public.zkapp_uris (id, value) FROM stdin;
1	
\.


--
-- Data for Name: zkapp_verification_keys; Type: TABLE DATA; Schema: public;
--

COPY public.zkapp_verification_keys (id, verification_key, hash) FROM stdin;
1	AqJyDj+A/KZcqMKQ1y2tsFf4mQbiFMCd8yyV0VW1+Xcv1FbOpS2KTBXTvnqbGYS8Bf916KTnUQ4sYXXx0Su5yAyja+HiSqpKaYJQcvfmOv6g7twxq09+QUIqYcIS6YH3BVNEGJzHvVWroe7/qbuRJO0KPjNavTDyH5xT9Ck6530PkIXgjXHyAvSXwdIDGZztIQggs3+NRM2wGDltEKh1njyac7QKwwVDw+gjrdX6TwWAjCCezWoSbvDz0y95rfM9ALjQ9FKRgb2zbAzrsEoV7WmylbKL4Ub4/5s5//rCAUgXTsy44KeBqAjGnj3n4C4qKwu8WJm/+rmUrS1GXgOgVi1/gz+WdUtdeznhskQIoQB/nd827sJ3HVc3RuwyC7wBA/KHQysAUeWQPtC3JxzM8++W0uNkZYTNea4pUHeOl28oPxaKgvIWbqK+mwTpiQAZs4k5Ixv8Syav+SuuNE1dWhRvxHpdCpjr+mNFaVLUfZDvvt/UUVpUGfsc+QAXpHktObvH/TRYyHJSOxhwtXBC/CKgLJCMPdYA+vY14baVQPwIzXYy5SOrpWmHCS3GSC27+lVnjUxZ4p9rmhvJ7xVUawUAJNj/8IIX+p6TMZ9XbEOihw0ZNGQJzDGIrE/g2eB3AiTEAWEG24HEkdKyxkKCZ1INOJ/WmXUgHdbHPUbmX1s5CrotBBdfDMYXkeKNtApHpwPdgo6L8LUZ9GeN1MUZuzIg1tJWJ27qxxDm3WjNN9w6yiY8nSDy6byoBU028jrUdB3vWzbwbblnUrK1gmT1CrgRWhaEkoqZvNJWh1tAY//0Dgd36L3iYBPwSMRlhBSaMykY2EZ2AvPml85GZnxHQUQSsniwB8IHCrR+fpWD6nidPhjjMIso8nHNlSR10xu6Bgw60HwdTpl7Dv75PHg5KEHgXeHuQEZ/aMky2qh47U95EljBjjJ2Tpd2kRZVLNdFJjebTMLuQ44W9/gTpNzMWksoJdf0qTy3M0/JOreC96EUY7WxE55Fp8KY04NegNnxkAejmr3Zt1n5mOKmKYYWqYxlE5NVSPvrSSmKT79XGLiTOf/+7HbWFyqvXr6ZUQejC69rGQiTk34Mpvgi6h0cXh0oZMRYs/TH9hp7UOE3U7fIaDjlzRH6fq0dtnN8a9+CHxPPrX5FlZpKtFKVr+Wa3uJcDE+Yn5aEpEtgJYZy+ow8Mn2ZIQRiHQFsuyHQqMeNSv6bI0kd5AVFi8EgDd0OrTwJ/NO+hoKu7u4Ef3OQ5hhITz/NZm7U2OBPHzZruO1p3hPyWryQfG9vHKCp/xn1af/THR8tNb0MN7/kdEW0En+1OEY6yqXTozMwHx+TPlExjcIBz1vAI/fbWwSdzM1UvV0pYbxUvfxHX6EqTbY9m3zatytOe9Do5UODZkD9VQdZ7QAZlGpw9qFxrPr/KG/gSxgRlg9i0NWZgmO2Chlg62hyBL9k9zVImbs8JYzzQmk5crE3/0VIKBMa1YQSA1byD5Y5QKjMzkaaZ93MjkJp/YjApsv9Jz/60g9K9VT1M8qyfCXhPjsO6ZWpd0Kc4MghKFV1m00jYP3aiV4/LTtofnuiGCO0RNBjdlRKMEUBR6XJ7oYmtYDHjxBSjno9/cTGk7QD+fbK9Ap9O/XL0dPQUib3A3zyUWxDuLGQ+uVR/onzVCnpjTLLhEhZR0VQncwuCwFOgU454SXQj7HF5ScM9WbkGD00JyCAI31FJ5W5EL8CQ4c8NwcrVGF2WyOqTyR30kAPoN9ezM7H6oQ9mjpedymIyizx6bkCEn2XaTuoaK9dTTwBztQ0x38jyhC0pUDRwDL6rjKNfP8AGVPUgKVagwk1J4Mb/0yuBqw6v0QDyYTwSBGydhVNv9mz92KjfwdJGKQTABQ8MmAq4k4cIM5Du1ztHtwaW8sUIArmJKvTvCOPJ3kqy2JEJqVWdlHDXTylRB17lO0ZGgp1GPTGmxxyekMctiIBjxBGl8OO6T8RUk7CziN6zCvCCTdCWmPgBGxaaZNMMwLyqRwt3nmvaho0N7QEBWVDe3uTTaY3H8I8ya2KCBw0IZws7Ihvsl9xk6yAUlVIUjwEf7M6RrAh9DsrKURl5DO7le57yvyh1jVwvN1q9hDV89f/b1e5gykI3QYrBSxBDyOlPvAYJvdIQKFPgUkBmcjmmBbvwp8dWrItey493I8wtpDQ/cbGzD5sp2lMDCpEQZYLkN1F4e3WAb9HEGT5OxyvKGSBWARks3BuqayhF6f25hAaH9S/V4/3GlWFSBBYFiheP7MR89SQ8tuONVX7xlhKqCybFotEeFCPllt0a/QWiD7lanuvUFPuJywNvkaLL6P714hl+UtXyiBNT+zzwy4UYH5LFg4f6G/Bcm2IsaX2eCm4t8Ikd1ULY8IQ7phHNw==	2558979205992526995075710955454945773620238701172507927380015714474888082276
\.


--
-- Name: account_identifiers_id_seq; Type: SEQUENCE SET; Schema: public;
--

SELECT pg_catalog.setval('public.account_identifiers_id_seq', 7, true);


--
-- Name: blocks_id_seq; Type: SEQUENCE SET; Schema: public;
--

SELECT pg_catalog.setval('public.blocks_id_seq', 21, true);


--
-- Name: epoch_data_id_seq; Type: SEQUENCE SET; Schema: public;
--

SELECT pg_catalog.setval('public.epoch_data_id_seq', 22, true);


--
-- Name: internal_commands_id_seq; Type: SEQUENCE SET; Schema: public;
--

SELECT pg_catalog.setval('public.internal_commands_id_seq', 14, true);


--
-- Name: public_keys_id_seq; Type: SEQUENCE SET; Schema: public;
--

SELECT pg_catalog.setval('public.public_keys_id_seq', 7, true);


--
-- Name: snarked_ledger_hashes_id_seq; Type: SEQUENCE SET; Schema: public;
--

SELECT pg_catalog.setval('public.snarked_ledger_hashes_id_seq', 1, true);


--
-- Name: timing_info_id_seq; Type: SEQUENCE SET; Schema: public;
--

SELECT pg_catalog.setval('public.timing_info_id_seq', 7, true);


--
-- Name: token_symbols_id_seq; Type: SEQUENCE SET; Schema: public;
--

SELECT pg_catalog.setval('public.token_symbols_id_seq', 1, true);


--
-- Name: tokens_id_seq; Type: SEQUENCE SET; Schema: public;
--

SELECT pg_catalog.setval('public.tokens_id_seq', 1, true);


--
-- Name: user_commands_id_seq; Type: SEQUENCE SET; Schema: public;
--

SELECT pg_catalog.setval('public.user_commands_id_seq', 92, true);


--
-- Name: voting_for_id_seq; Type: SEQUENCE SET; Schema: public;
--

SELECT pg_catalog.setval('public.voting_for_id_seq', 1, true);


--
-- Name: zkapp_account_precondition_id_seq; Type: SEQUENCE SET; Schema: public;
--

SELECT pg_catalog.setval('public.zkapp_account_precondition_id_seq', 2, true);


--
-- Name: zkapp_accounts_id_seq; Type: SEQUENCE SET; Schema: public;
--

SELECT pg_catalog.setval('public.zkapp_accounts_id_seq', 2, true);


--
-- Name: zkapp_amount_bounds_id_seq; Type: SEQUENCE SET; Schema: public;
--

SELECT pg_catalog.setval('public.zkapp_amount_bounds_id_seq', 1, false);


--
-- Name: zkapp_balance_bounds_id_seq; Type: SEQUENCE SET; Schema: public;
--

SELECT pg_catalog.setval('public.zkapp_balance_bounds_id_seq', 1, false);


--
-- Name: zkapp_commands_id_seq; Type: SEQUENCE SET; Schema: public;
--

SELECT pg_catalog.setval('public.zkapp_commands_id_seq', 2, true);


--
-- Name: zkapp_epoch_data_id_seq; Type: SEQUENCE SET; Schema: public;
--

SELECT pg_catalog.setval('public.zkapp_epoch_data_id_seq', 1, true);


--
-- Name: zkapp_epoch_ledger_id_seq; Type: SEQUENCE SET; Schema: public;
--

SELECT pg_catalog.setval('public.zkapp_epoch_ledger_id_seq', 1, true);


--
-- Name: zkapp_events_id_seq; Type: SEQUENCE SET; Schema: public;
--

SELECT pg_catalog.setval('public.zkapp_events_id_seq', 1, true);


--
-- Name: zkapp_fee_payer_body_id_seq; Type: SEQUENCE SET; Schema: public;
--

SELECT pg_catalog.setval('public.zkapp_fee_payer_body_id_seq', 2, true);


--
-- Name: zkapp_global_slot_bounds_id_seq; Type: SEQUENCE SET; Schema: public;
--

SELECT pg_catalog.setval('public.zkapp_global_slot_bounds_id_seq', 1, false);


--
-- Name: zkapp_length_bounds_id_seq; Type: SEQUENCE SET; Schema: public;
--

SELECT pg_catalog.setval('public.zkapp_length_bounds_id_seq', 1, false);


--
-- Name: zkapp_network_precondition_id_seq; Type: SEQUENCE SET; Schema: public;
--

SELECT pg_catalog.setval('public.zkapp_network_precondition_id_seq', 1, true);


--
-- Name: zkapp_nonce_bounds_id_seq; Type: SEQUENCE SET; Schema: public;
--

SELECT pg_catalog.setval('public.zkapp_nonce_bounds_id_seq', 1, false);


--
-- Name: zkapp_other_party_body_id_seq; Type: SEQUENCE SET; Schema: public;
--

SELECT pg_catalog.setval('public.zkapp_other_party_body_id_seq', 3, true);


--
-- Name: zkapp_other_party_id_seq; Type: SEQUENCE SET; Schema: public;
--

SELECT pg_catalog.setval('public.zkapp_other_party_id_seq', 3, true);


--
-- Name: zkapp_party_failures_id_seq; Type: SEQUENCE SET; Schema: public;
--

SELECT pg_catalog.setval('public.zkapp_party_failures_id_seq', 1, false);


--
-- Name: zkapp_permissions_id_seq; Type: SEQUENCE SET; Schema: public;
--

SELECT pg_catalog.setval('public.zkapp_permissions_id_seq', 5, true);


--
-- Name: zkapp_precondition_accounts_id_seq; Type: SEQUENCE SET; Schema: public;
--

SELECT pg_catalog.setval('public.zkapp_precondition_accounts_id_seq', 1, false);


--
-- Name: zkapp_sequence_states_id_seq; Type: SEQUENCE SET; Schema: public;
--

SELECT pg_catalog.setval('public.zkapp_sequence_states_id_seq', 1, true);


--
-- Name: zkapp_state_data_array_id_seq; Type: SEQUENCE SET; Schema: public;
--

SELECT pg_catalog.setval('public.zkapp_state_data_array_id_seq', 1, false);


--
-- Name: zkapp_state_data_id_seq; Type: SEQUENCE SET; Schema: public;
--

SELECT pg_catalog.setval('public.zkapp_state_data_id_seq', 10, true);


--
-- Name: zkapp_states_id_seq; Type: SEQUENCE SET; Schema: public;
--

SELECT pg_catalog.setval('public.zkapp_states_id_seq', 3, true);


--
-- Name: zkapp_states_nullable_id_seq; Type: SEQUENCE SET; Schema: public;
--

SELECT pg_catalog.setval('public.zkapp_states_nullable_id_seq', 3, true);


--
-- Name: zkapp_timestamp_bounds_id_seq; Type: SEQUENCE SET; Schema: public;
--

SELECT pg_catalog.setval('public.zkapp_timestamp_bounds_id_seq', 1, false);


--
-- Name: zkapp_timing_info_id_seq; Type: SEQUENCE SET; Schema: public;
--

SELECT pg_catalog.setval('public.zkapp_timing_info_id_seq', 1, false);


--
-- Name: zkapp_token_id_bounds_id_seq; Type: SEQUENCE SET; Schema: public;
--

SELECT pg_catalog.setval('public.zkapp_token_id_bounds_id_seq', 1, false);


--
-- Name: zkapp_updates_id_seq; Type: SEQUENCE SET; Schema: public;
--

SELECT pg_catalog.setval('public.zkapp_updates_id_seq', 3, true);


--
-- Name: zkapp_uris_id_seq; Type: SEQUENCE SET; Schema: public;
--

SELECT pg_catalog.setval('public.zkapp_uris_id_seq', 1, true);


--
-- Name: zkapp_verification_keys_id_seq; Type: SEQUENCE SET; Schema: public;
--

SELECT pg_catalog.setval('public.zkapp_verification_keys_id_seq', 1, true);


--
-- Name: account_identifiers account_identifiers_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.account_identifiers
    ADD CONSTRAINT account_identifiers_pkey PRIMARY KEY (id);


--
-- Name: account_identifiers account_identifiers_public_key_id_token_id_key; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.account_identifiers
    ADD CONSTRAINT account_identifiers_public_key_id_token_id_key UNIQUE (public_key_id, token_id);


--
-- Name: accounts_accessed accounts_accessed_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.accounts_accessed
    ADD CONSTRAINT accounts_accessed_pkey PRIMARY KEY (block_id, account_identifier_id);


--
-- Name: accounts_created accounts_created_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.accounts_created
    ADD CONSTRAINT accounts_created_pkey PRIMARY KEY (block_id, account_identifier_id);


--
-- Name: blocks_internal_commands blocks_internal_commands_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.blocks_internal_commands
    ADD CONSTRAINT blocks_internal_commands_pkey PRIMARY KEY (block_id, internal_command_id, sequence_no, secondary_sequence_no);


--
-- Name: blocks blocks_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.blocks
    ADD CONSTRAINT blocks_pkey PRIMARY KEY (id);


--
-- Name: blocks blocks_state_hash_key; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.blocks
    ADD CONSTRAINT blocks_state_hash_key UNIQUE (state_hash);


--
-- Name: blocks_user_commands blocks_user_commands_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.blocks_user_commands
    ADD CONSTRAINT blocks_user_commands_pkey PRIMARY KEY (block_id, user_command_id, sequence_no);


--
-- Name: blocks_zkapp_commands blocks_zkapp_commands_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.blocks_zkapp_commands
    ADD CONSTRAINT blocks_zkapp_commands_pkey PRIMARY KEY (block_id, zkapp_command_id, sequence_no);


--
-- Name: epoch_data epoch_data_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.epoch_data
    ADD CONSTRAINT epoch_data_pkey PRIMARY KEY (id);


--
-- Name: internal_commands internal_commands_hash_typ_key; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.internal_commands
    ADD CONSTRAINT internal_commands_hash_typ_key UNIQUE (hash, typ);


--
-- Name: internal_commands internal_commands_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.internal_commands
    ADD CONSTRAINT internal_commands_pkey PRIMARY KEY (id);


--
-- Name: public_keys public_keys_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.public_keys
    ADD CONSTRAINT public_keys_pkey PRIMARY KEY (id);


--
-- Name: public_keys public_keys_value_key; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.public_keys
    ADD CONSTRAINT public_keys_value_key UNIQUE (value);


--
-- Name: snarked_ledger_hashes snarked_ledger_hashes_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.snarked_ledger_hashes
    ADD CONSTRAINT snarked_ledger_hashes_pkey PRIMARY KEY (id);


--
-- Name: snarked_ledger_hashes snarked_ledger_hashes_value_key; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.snarked_ledger_hashes
    ADD CONSTRAINT snarked_ledger_hashes_value_key UNIQUE (value);


--
-- Name: timing_info timing_info_account_identifier_id_key; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.timing_info
    ADD CONSTRAINT timing_info_account_identifier_id_key UNIQUE (account_identifier_id);


--
-- Name: timing_info timing_info_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.timing_info
    ADD CONSTRAINT timing_info_pkey PRIMARY KEY (id);


--
-- Name: token_symbols token_symbols_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.token_symbols
    ADD CONSTRAINT token_symbols_pkey PRIMARY KEY (id);


--
-- Name: tokens tokens_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.tokens
    ADD CONSTRAINT tokens_pkey PRIMARY KEY (id);


--
-- Name: tokens tokens_value_key; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.tokens
    ADD CONSTRAINT tokens_value_key UNIQUE (value);


--
-- Name: user_commands user_commands_hash_key; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.user_commands
    ADD CONSTRAINT user_commands_hash_key UNIQUE (hash);


--
-- Name: user_commands user_commands_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.user_commands
    ADD CONSTRAINT user_commands_pkey PRIMARY KEY (id);


--
-- Name: voting_for voting_for_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.voting_for
    ADD CONSTRAINT voting_for_pkey PRIMARY KEY (id);


--
-- Name: zkapp_account_precondition zkapp_account_precondition_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_account_precondition
    ADD CONSTRAINT zkapp_account_precondition_pkey PRIMARY KEY (id);


--
-- Name: zkapp_accounts zkapp_accounts_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_accounts
    ADD CONSTRAINT zkapp_accounts_pkey PRIMARY KEY (id);


--
-- Name: zkapp_amount_bounds zkapp_amount_bounds_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_amount_bounds
    ADD CONSTRAINT zkapp_amount_bounds_pkey PRIMARY KEY (id);


--
-- Name: zkapp_balance_bounds zkapp_balance_bounds_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_balance_bounds
    ADD CONSTRAINT zkapp_balance_bounds_pkey PRIMARY KEY (id);


--
-- Name: zkapp_commands zkapp_commands_hash_key; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_commands
    ADD CONSTRAINT zkapp_commands_hash_key UNIQUE (hash);


--
-- Name: zkapp_commands zkapp_commands_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_commands
    ADD CONSTRAINT zkapp_commands_pkey PRIMARY KEY (id);


--
-- Name: zkapp_epoch_data zkapp_epoch_data_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_epoch_data
    ADD CONSTRAINT zkapp_epoch_data_pkey PRIMARY KEY (id);


--
-- Name: zkapp_epoch_ledger zkapp_epoch_ledger_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_epoch_ledger
    ADD CONSTRAINT zkapp_epoch_ledger_pkey PRIMARY KEY (id);


--
-- Name: zkapp_events zkapp_events_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_events
    ADD CONSTRAINT zkapp_events_pkey PRIMARY KEY (id);


--
-- Name: zkapp_fee_payer_body zkapp_fee_payer_body_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_fee_payer_body
    ADD CONSTRAINT zkapp_fee_payer_body_pkey PRIMARY KEY (id);


--
-- Name: zkapp_global_slot_bounds zkapp_global_slot_bounds_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_global_slot_bounds
    ADD CONSTRAINT zkapp_global_slot_bounds_pkey PRIMARY KEY (id);


--
-- Name: zkapp_length_bounds zkapp_length_bounds_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_length_bounds
    ADD CONSTRAINT zkapp_length_bounds_pkey PRIMARY KEY (id);


--
-- Name: zkapp_network_precondition zkapp_network_precondition_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_network_precondition
    ADD CONSTRAINT zkapp_network_precondition_pkey PRIMARY KEY (id);


--
-- Name: zkapp_nonce_bounds zkapp_nonce_bounds_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_nonce_bounds
    ADD CONSTRAINT zkapp_nonce_bounds_pkey PRIMARY KEY (id);


--
-- Name: zkapp_other_party_body zkapp_other_party_body_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_other_party_body
    ADD CONSTRAINT zkapp_other_party_body_pkey PRIMARY KEY (id);


--
-- Name: zkapp_other_party zkapp_other_party_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_other_party
    ADD CONSTRAINT zkapp_other_party_pkey PRIMARY KEY (id);


--
-- Name: zkapp_party_failures zkapp_party_failures_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_party_failures
    ADD CONSTRAINT zkapp_party_failures_pkey PRIMARY KEY (id);


--
-- Name: zkapp_permissions zkapp_permissions_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_permissions
    ADD CONSTRAINT zkapp_permissions_pkey PRIMARY KEY (id);


--
-- Name: zkapp_precondition_accounts zkapp_precondition_accounts_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_precondition_accounts
    ADD CONSTRAINT zkapp_precondition_accounts_pkey PRIMARY KEY (id);


--
-- Name: zkapp_sequence_states zkapp_sequence_states_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_sequence_states
    ADD CONSTRAINT zkapp_sequence_states_pkey PRIMARY KEY (id);


--
-- Name: zkapp_state_data_array zkapp_state_data_array_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_state_data_array
    ADD CONSTRAINT zkapp_state_data_array_pkey PRIMARY KEY (id);


--
-- Name: zkapp_state_data zkapp_state_data_field_key; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_state_data
    ADD CONSTRAINT zkapp_state_data_field_key UNIQUE (field);


--
-- Name: zkapp_state_data zkapp_state_data_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_state_data
    ADD CONSTRAINT zkapp_state_data_pkey PRIMARY KEY (id);


--
-- Name: zkapp_states zkapp_states_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_states
    ADD CONSTRAINT zkapp_states_pkey PRIMARY KEY (id);


--
-- Name: zkapp_states_nullable zkapp_states_nullable_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_states_nullable
    ADD CONSTRAINT zkapp_states_nullable_pkey PRIMARY KEY (id);


--
-- Name: zkapp_timestamp_bounds zkapp_timestamp_bounds_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_timestamp_bounds
    ADD CONSTRAINT zkapp_timestamp_bounds_pkey PRIMARY KEY (id);


--
-- Name: zkapp_timing_info zkapp_timing_info_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_timing_info
    ADD CONSTRAINT zkapp_timing_info_pkey PRIMARY KEY (id);


--
-- Name: zkapp_token_id_bounds zkapp_token_id_bounds_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_token_id_bounds
    ADD CONSTRAINT zkapp_token_id_bounds_pkey PRIMARY KEY (id);


--
-- Name: zkapp_updates zkapp_updates_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_updates
    ADD CONSTRAINT zkapp_updates_pkey PRIMARY KEY (id);


--
-- Name: zkapp_uris zkapp_uris_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_uris
    ADD CONSTRAINT zkapp_uris_pkey PRIMARY KEY (id);


--
-- Name: zkapp_uris zkapp_uris_value_key; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_uris
    ADD CONSTRAINT zkapp_uris_value_key UNIQUE (value);


--
-- Name: zkapp_verification_keys zkapp_verification_keys_hash_key; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_verification_keys
    ADD CONSTRAINT zkapp_verification_keys_hash_key UNIQUE (hash);


--
-- Name: zkapp_verification_keys zkapp_verification_keys_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_verification_keys
    ADD CONSTRAINT zkapp_verification_keys_pkey PRIMARY KEY (id);


--
-- Name: zkapp_verification_keys zkapp_verification_keys_verification_key_key; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_verification_keys
    ADD CONSTRAINT zkapp_verification_keys_verification_key_key UNIQUE (verification_key);


--
-- Name: idx_accounts_accessed_block_account_identifier_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_accounts_accessed_block_account_identifier_id ON public.accounts_accessed USING btree (account_identifier_id);


--
-- Name: idx_accounts_accessed_block_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_accounts_accessed_block_id ON public.accounts_accessed USING btree (block_id);


--
-- Name: idx_accounts_created_block_account_identifier_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_accounts_created_block_account_identifier_id ON public.accounts_created USING btree (account_identifier_id);


--
-- Name: idx_accounts_created_block_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_accounts_created_block_id ON public.accounts_created USING btree (block_id);


--
-- Name: idx_blocks_creator_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_blocks_creator_id ON public.blocks USING btree (creator_id);


--
-- Name: idx_blocks_height; Type: INDEX; Schema: public;
--

CREATE INDEX idx_blocks_height ON public.blocks USING btree (height);


--
-- Name: idx_blocks_internal_commands_block_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_blocks_internal_commands_block_id ON public.blocks_internal_commands USING btree (block_id);


--
-- Name: idx_blocks_internal_commands_internal_command_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_blocks_internal_commands_internal_command_id ON public.blocks_internal_commands USING btree (internal_command_id);


--
-- Name: idx_blocks_internal_commands_secondary_sequence_no; Type: INDEX; Schema: public;
--

CREATE INDEX idx_blocks_internal_commands_secondary_sequence_no ON public.blocks_internal_commands USING btree (secondary_sequence_no);


--
-- Name: idx_blocks_internal_commands_sequence_no; Type: INDEX; Schema: public;
--

CREATE INDEX idx_blocks_internal_commands_sequence_no ON public.blocks_internal_commands USING btree (sequence_no);


--
-- Name: idx_blocks_parent_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_blocks_parent_id ON public.blocks USING btree (parent_id);


--
-- Name: idx_blocks_user_commands_block_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_blocks_user_commands_block_id ON public.blocks_user_commands USING btree (block_id);


--
-- Name: idx_blocks_user_commands_sequence_no; Type: INDEX; Schema: public;
--

CREATE INDEX idx_blocks_user_commands_sequence_no ON public.blocks_user_commands USING btree (sequence_no);


--
-- Name: idx_blocks_user_commands_user_command_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_blocks_user_commands_user_command_id ON public.blocks_user_commands USING btree (user_command_id);


--
-- Name: idx_blocks_zkapp_commands_block_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_blocks_zkapp_commands_block_id ON public.blocks_zkapp_commands USING btree (block_id);


--
-- Name: idx_blocks_zkapp_commands_sequence_no; Type: INDEX; Schema: public;
--

CREATE INDEX idx_blocks_zkapp_commands_sequence_no ON public.blocks_zkapp_commands USING btree (sequence_no);


--
-- Name: idx_blocks_zkapp_commands_zkapp_command_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_blocks_zkapp_commands_zkapp_command_id ON public.blocks_zkapp_commands USING btree (zkapp_command_id);


--
-- Name: idx_chain_status; Type: INDEX; Schema: public;
--

CREATE INDEX idx_chain_status ON public.blocks USING btree (chain_status);


--
-- Name: idx_token_symbols_value; Type: INDEX; Schema: public;
--

CREATE INDEX idx_token_symbols_value ON public.token_symbols USING btree (value);


--
-- Name: idx_voting_for_value; Type: INDEX; Schema: public;
--

CREATE INDEX idx_voting_for_value ON public.voting_for USING btree (value);


--
-- Name: account_identifiers account_identifiers_public_key_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.account_identifiers
    ADD CONSTRAINT account_identifiers_public_key_id_fkey FOREIGN KEY (public_key_id) REFERENCES public.public_keys(id) ON DELETE CASCADE;


--
-- Name: account_identifiers account_identifiers_token_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.account_identifiers
    ADD CONSTRAINT account_identifiers_token_id_fkey FOREIGN KEY (token_id) REFERENCES public.tokens(id) ON DELETE CASCADE;


--
-- Name: accounts_accessed accounts_accessed_account_identifier_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.accounts_accessed
    ADD CONSTRAINT accounts_accessed_account_identifier_id_fkey FOREIGN KEY (account_identifier_id) REFERENCES public.account_identifiers(id);


--
-- Name: accounts_accessed accounts_accessed_block_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.accounts_accessed
    ADD CONSTRAINT accounts_accessed_block_id_fkey FOREIGN KEY (block_id) REFERENCES public.blocks(id);


--
-- Name: accounts_accessed accounts_accessed_delegate_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.accounts_accessed
    ADD CONSTRAINT accounts_accessed_delegate_id_fkey FOREIGN KEY (delegate_id) REFERENCES public.public_keys(id);


--
-- Name: accounts_accessed accounts_accessed_permissions_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.accounts_accessed
    ADD CONSTRAINT accounts_accessed_permissions_id_fkey FOREIGN KEY (permissions_id) REFERENCES public.zkapp_permissions(id);


--
-- Name: accounts_accessed accounts_accessed_timing_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.accounts_accessed
    ADD CONSTRAINT accounts_accessed_timing_id_fkey FOREIGN KEY (timing_id) REFERENCES public.timing_info(id);


--
-- Name: accounts_accessed accounts_accessed_token_symbol_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.accounts_accessed
    ADD CONSTRAINT accounts_accessed_token_symbol_id_fkey FOREIGN KEY (token_symbol_id) REFERENCES public.token_symbols(id);


--
-- Name: accounts_accessed accounts_accessed_voting_for_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.accounts_accessed
    ADD CONSTRAINT accounts_accessed_voting_for_id_fkey FOREIGN KEY (voting_for_id) REFERENCES public.voting_for(id);


--
-- Name: accounts_accessed accounts_accessed_zkapp_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.accounts_accessed
    ADD CONSTRAINT accounts_accessed_zkapp_id_fkey FOREIGN KEY (zkapp_id) REFERENCES public.zkapp_accounts(id);


--
-- Name: accounts_created accounts_created_account_identifier_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.accounts_created
    ADD CONSTRAINT accounts_created_account_identifier_id_fkey FOREIGN KEY (account_identifier_id) REFERENCES public.account_identifiers(id);


--
-- Name: accounts_created accounts_created_block_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.accounts_created
    ADD CONSTRAINT accounts_created_block_id_fkey FOREIGN KEY (block_id) REFERENCES public.blocks(id);


--
-- Name: blocks blocks_block_winner_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.blocks
    ADD CONSTRAINT blocks_block_winner_id_fkey FOREIGN KEY (block_winner_id) REFERENCES public.public_keys(id);


--
-- Name: blocks blocks_creator_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.blocks
    ADD CONSTRAINT blocks_creator_id_fkey FOREIGN KEY (creator_id) REFERENCES public.public_keys(id);


--
-- Name: blocks_internal_commands blocks_internal_commands_block_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.blocks_internal_commands
    ADD CONSTRAINT blocks_internal_commands_block_id_fkey FOREIGN KEY (block_id) REFERENCES public.blocks(id) ON DELETE CASCADE;


--
-- Name: blocks_internal_commands blocks_internal_commands_internal_command_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.blocks_internal_commands
    ADD CONSTRAINT blocks_internal_commands_internal_command_id_fkey FOREIGN KEY (internal_command_id) REFERENCES public.internal_commands(id) ON DELETE CASCADE;


--
-- Name: blocks blocks_next_epoch_data_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.blocks
    ADD CONSTRAINT blocks_next_epoch_data_id_fkey FOREIGN KEY (next_epoch_data_id) REFERENCES public.epoch_data(id);


--
-- Name: blocks blocks_parent_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.blocks
    ADD CONSTRAINT blocks_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.blocks(id);


--
-- Name: blocks blocks_snarked_ledger_hash_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.blocks
    ADD CONSTRAINT blocks_snarked_ledger_hash_id_fkey FOREIGN KEY (snarked_ledger_hash_id) REFERENCES public.snarked_ledger_hashes(id);


--
-- Name: blocks blocks_staking_epoch_data_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.blocks
    ADD CONSTRAINT blocks_staking_epoch_data_id_fkey FOREIGN KEY (staking_epoch_data_id) REFERENCES public.epoch_data(id);


--
-- Name: blocks_user_commands blocks_user_commands_block_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.blocks_user_commands
    ADD CONSTRAINT blocks_user_commands_block_id_fkey FOREIGN KEY (block_id) REFERENCES public.blocks(id) ON DELETE CASCADE;


--
-- Name: blocks_user_commands blocks_user_commands_user_command_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.blocks_user_commands
    ADD CONSTRAINT blocks_user_commands_user_command_id_fkey FOREIGN KEY (user_command_id) REFERENCES public.user_commands(id) ON DELETE CASCADE;


--
-- Name: blocks_zkapp_commands blocks_zkapp_commands_block_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.blocks_zkapp_commands
    ADD CONSTRAINT blocks_zkapp_commands_block_id_fkey FOREIGN KEY (block_id) REFERENCES public.blocks(id) ON DELETE CASCADE;


--
-- Name: blocks_zkapp_commands blocks_zkapp_commands_zkapp_command_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.blocks_zkapp_commands
    ADD CONSTRAINT blocks_zkapp_commands_zkapp_command_id_fkey FOREIGN KEY (zkapp_command_id) REFERENCES public.zkapp_commands(id) ON DELETE CASCADE;


--
-- Name: epoch_data epoch_data_ledger_hash_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.epoch_data
    ADD CONSTRAINT epoch_data_ledger_hash_id_fkey FOREIGN KEY (ledger_hash_id) REFERENCES public.snarked_ledger_hashes(id);


--
-- Name: internal_commands internal_commands_receiver_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.internal_commands
    ADD CONSTRAINT internal_commands_receiver_id_fkey FOREIGN KEY (receiver_id) REFERENCES public.account_identifiers(id);


--
-- Name: timing_info timing_info_account_identifier_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.timing_info
    ADD CONSTRAINT timing_info_account_identifier_id_fkey FOREIGN KEY (account_identifier_id) REFERENCES public.account_identifiers(id);


--
-- Name: tokens tokens_owner_public_key_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.tokens
    ADD CONSTRAINT tokens_owner_public_key_id_fkey FOREIGN KEY (owner_public_key_id) REFERENCES public.public_keys(id) ON DELETE CASCADE;


--
-- Name: tokens tokens_owner_token_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.tokens
    ADD CONSTRAINT tokens_owner_token_id_fkey FOREIGN KEY (owner_token_id) REFERENCES public.tokens(id);


--
-- Name: user_commands user_commands_fee_payer_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.user_commands
    ADD CONSTRAINT user_commands_fee_payer_id_fkey FOREIGN KEY (fee_payer_id) REFERENCES public.account_identifiers(id);


--
-- Name: user_commands user_commands_receiver_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.user_commands
    ADD CONSTRAINT user_commands_receiver_id_fkey FOREIGN KEY (receiver_id) REFERENCES public.account_identifiers(id);


--
-- Name: user_commands user_commands_source_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.user_commands
    ADD CONSTRAINT user_commands_source_id_fkey FOREIGN KEY (source_id) REFERENCES public.account_identifiers(id);


--
-- Name: zkapp_account_precondition zkapp_account_precondition_precondition_account_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_account_precondition
    ADD CONSTRAINT zkapp_account_precondition_precondition_account_id_fkey FOREIGN KEY (precondition_account_id) REFERENCES public.zkapp_precondition_accounts(id);


--
-- Name: zkapp_accounts zkapp_accounts_app_state_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_accounts
    ADD CONSTRAINT zkapp_accounts_app_state_id_fkey FOREIGN KEY (app_state_id) REFERENCES public.zkapp_states(id);


--
-- Name: zkapp_accounts zkapp_accounts_sequence_state_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_accounts
    ADD CONSTRAINT zkapp_accounts_sequence_state_id_fkey FOREIGN KEY (sequence_state_id) REFERENCES public.zkapp_sequence_states(id);


--
-- Name: zkapp_accounts zkapp_accounts_verification_key_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_accounts
    ADD CONSTRAINT zkapp_accounts_verification_key_id_fkey FOREIGN KEY (verification_key_id) REFERENCES public.zkapp_verification_keys(id);


--
-- Name: zkapp_accounts zkapp_accounts_zkapp_uri_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_accounts
    ADD CONSTRAINT zkapp_accounts_zkapp_uri_id_fkey FOREIGN KEY (zkapp_uri_id) REFERENCES public.zkapp_uris(id);


--
-- Name: zkapp_commands zkapp_commands_zkapp_fee_payer_body_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_commands
    ADD CONSTRAINT zkapp_commands_zkapp_fee_payer_body_id_fkey FOREIGN KEY (zkapp_fee_payer_body_id) REFERENCES public.zkapp_fee_payer_body(id);


--
-- Name: zkapp_epoch_data zkapp_epoch_data_epoch_ledger_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_epoch_data
    ADD CONSTRAINT zkapp_epoch_data_epoch_ledger_id_fkey FOREIGN KEY (epoch_ledger_id) REFERENCES public.zkapp_epoch_ledger(id);


--
-- Name: zkapp_epoch_data zkapp_epoch_data_epoch_length_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_epoch_data
    ADD CONSTRAINT zkapp_epoch_data_epoch_length_id_fkey FOREIGN KEY (epoch_length_id) REFERENCES public.zkapp_length_bounds(id);


--
-- Name: zkapp_epoch_ledger zkapp_epoch_ledger_hash_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_epoch_ledger
    ADD CONSTRAINT zkapp_epoch_ledger_hash_id_fkey FOREIGN KEY (hash_id) REFERENCES public.snarked_ledger_hashes(id);


--
-- Name: zkapp_epoch_ledger zkapp_epoch_ledger_total_currency_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_epoch_ledger
    ADD CONSTRAINT zkapp_epoch_ledger_total_currency_id_fkey FOREIGN KEY (total_currency_id) REFERENCES public.zkapp_amount_bounds(id);


--
-- Name: zkapp_fee_payer_body zkapp_fee_payer_body_account_identifier_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_fee_payer_body
    ADD CONSTRAINT zkapp_fee_payer_body_account_identifier_id_fkey FOREIGN KEY (account_identifier_id) REFERENCES public.account_identifiers(id);


--
-- Name: zkapp_network_precondition zkapp_network_precondition_blockchain_length_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_network_precondition
    ADD CONSTRAINT zkapp_network_precondition_blockchain_length_id_fkey FOREIGN KEY (blockchain_length_id) REFERENCES public.zkapp_length_bounds(id);


--
-- Name: zkapp_network_precondition zkapp_network_precondition_curr_global_slot_since_hard_for_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_network_precondition
    ADD CONSTRAINT zkapp_network_precondition_curr_global_slot_since_hard_for_fkey FOREIGN KEY (curr_global_slot_since_hard_fork) REFERENCES public.zkapp_global_slot_bounds(id);


--
-- Name: zkapp_network_precondition zkapp_network_precondition_global_slot_since_genesis_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_network_precondition
    ADD CONSTRAINT zkapp_network_precondition_global_slot_since_genesis_fkey FOREIGN KEY (global_slot_since_genesis) REFERENCES public.zkapp_global_slot_bounds(id);


--
-- Name: zkapp_network_precondition zkapp_network_precondition_min_window_density_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_network_precondition
    ADD CONSTRAINT zkapp_network_precondition_min_window_density_id_fkey FOREIGN KEY (min_window_density_id) REFERENCES public.zkapp_length_bounds(id);


--
-- Name: zkapp_network_precondition zkapp_network_precondition_next_epoch_data_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_network_precondition
    ADD CONSTRAINT zkapp_network_precondition_next_epoch_data_id_fkey FOREIGN KEY (next_epoch_data_id) REFERENCES public.zkapp_epoch_data(id);


--
-- Name: zkapp_network_precondition zkapp_network_precondition_snarked_ledger_hash_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_network_precondition
    ADD CONSTRAINT zkapp_network_precondition_snarked_ledger_hash_id_fkey FOREIGN KEY (snarked_ledger_hash_id) REFERENCES public.snarked_ledger_hashes(id);


--
-- Name: zkapp_network_precondition zkapp_network_precondition_staking_epoch_data_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_network_precondition
    ADD CONSTRAINT zkapp_network_precondition_staking_epoch_data_id_fkey FOREIGN KEY (staking_epoch_data_id) REFERENCES public.zkapp_epoch_data(id);


--
-- Name: zkapp_network_precondition zkapp_network_precondition_timestamp_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_network_precondition
    ADD CONSTRAINT zkapp_network_precondition_timestamp_id_fkey FOREIGN KEY (timestamp_id) REFERENCES public.zkapp_timestamp_bounds(id);


--
-- Name: zkapp_network_precondition zkapp_network_precondition_total_currency_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_network_precondition
    ADD CONSTRAINT zkapp_network_precondition_total_currency_id_fkey FOREIGN KEY (total_currency_id) REFERENCES public.zkapp_amount_bounds(id);


--
-- Name: zkapp_other_party_body zkapp_other_party_body_account_identifier_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_other_party_body
    ADD CONSTRAINT zkapp_other_party_body_account_identifier_id_fkey FOREIGN KEY (account_identifier_id) REFERENCES public.account_identifiers(id);


--
-- Name: zkapp_other_party_body zkapp_other_party_body_call_data_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_other_party_body
    ADD CONSTRAINT zkapp_other_party_body_call_data_id_fkey FOREIGN KEY (call_data_id) REFERENCES public.zkapp_state_data(id);


--
-- Name: zkapp_other_party_body zkapp_other_party_body_events_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_other_party_body
    ADD CONSTRAINT zkapp_other_party_body_events_id_fkey FOREIGN KEY (events_id) REFERENCES public.zkapp_events(id);


--
-- Name: zkapp_other_party zkapp_other_party_body_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_other_party
    ADD CONSTRAINT zkapp_other_party_body_id_fkey FOREIGN KEY (body_id) REFERENCES public.zkapp_other_party_body(id);


--
-- Name: zkapp_other_party_body zkapp_other_party_body_sequence_events_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_other_party_body
    ADD CONSTRAINT zkapp_other_party_body_sequence_events_id_fkey FOREIGN KEY (sequence_events_id) REFERENCES public.zkapp_events(id);


--
-- Name: zkapp_other_party_body zkapp_other_party_body_update_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_other_party_body
    ADD CONSTRAINT zkapp_other_party_body_update_id_fkey FOREIGN KEY (update_id) REFERENCES public.zkapp_updates(id);


--
-- Name: zkapp_other_party_body zkapp_other_party_body_zkapp_account_precondition_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_other_party_body
    ADD CONSTRAINT zkapp_other_party_body_zkapp_account_precondition_id_fkey FOREIGN KEY (zkapp_account_precondition_id) REFERENCES public.zkapp_account_precondition(id);


--
-- Name: zkapp_other_party_body zkapp_other_party_body_zkapp_network_precondition_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_other_party_body
    ADD CONSTRAINT zkapp_other_party_body_zkapp_network_precondition_id_fkey FOREIGN KEY (zkapp_network_precondition_id) REFERENCES public.zkapp_network_precondition(id);


--
-- Name: zkapp_precondition_accounts zkapp_precondition_accounts_balance_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_precondition_accounts
    ADD CONSTRAINT zkapp_precondition_accounts_balance_id_fkey FOREIGN KEY (balance_id) REFERENCES public.zkapp_balance_bounds(id);


--
-- Name: zkapp_precondition_accounts zkapp_precondition_accounts_delegate_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_precondition_accounts
    ADD CONSTRAINT zkapp_precondition_accounts_delegate_id_fkey FOREIGN KEY (delegate_id) REFERENCES public.public_keys(id);


--
-- Name: zkapp_precondition_accounts zkapp_precondition_accounts_nonce_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_precondition_accounts
    ADD CONSTRAINT zkapp_precondition_accounts_nonce_id_fkey FOREIGN KEY (nonce_id) REFERENCES public.zkapp_nonce_bounds(id);


--
-- Name: zkapp_precondition_accounts zkapp_precondition_accounts_sequence_state_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_precondition_accounts
    ADD CONSTRAINT zkapp_precondition_accounts_sequence_state_id_fkey FOREIGN KEY (sequence_state_id) REFERENCES public.zkapp_state_data(id);


--
-- Name: zkapp_precondition_accounts zkapp_precondition_accounts_state_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_precondition_accounts
    ADD CONSTRAINT zkapp_precondition_accounts_state_id_fkey FOREIGN KEY (state_id) REFERENCES public.zkapp_states_nullable(id);


--
-- Name: zkapp_updates zkapp_updates_app_state_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_updates
    ADD CONSTRAINT zkapp_updates_app_state_id_fkey FOREIGN KEY (app_state_id) REFERENCES public.zkapp_states_nullable(id);


--
-- Name: zkapp_updates zkapp_updates_delegate_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_updates
    ADD CONSTRAINT zkapp_updates_delegate_id_fkey FOREIGN KEY (delegate_id) REFERENCES public.public_keys(id);


--
-- Name: zkapp_updates zkapp_updates_permissions_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_updates
    ADD CONSTRAINT zkapp_updates_permissions_id_fkey FOREIGN KEY (permissions_id) REFERENCES public.zkapp_permissions(id);


--
-- Name: zkapp_updates zkapp_updates_timing_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_updates
    ADD CONSTRAINT zkapp_updates_timing_id_fkey FOREIGN KEY (timing_id) REFERENCES public.zkapp_timing_info(id);


--
-- Name: zkapp_updates zkapp_updates_token_symbol_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_updates
    ADD CONSTRAINT zkapp_updates_token_symbol_id_fkey FOREIGN KEY (token_symbol_id) REFERENCES public.token_symbols(id);


--
-- Name: zkapp_updates zkapp_updates_verification_key_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_updates
    ADD CONSTRAINT zkapp_updates_verification_key_id_fkey FOREIGN KEY (verification_key_id) REFERENCES public.zkapp_verification_keys(id);


--
-- Name: zkapp_updates zkapp_updates_voting_for_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_updates
    ADD CONSTRAINT zkapp_updates_voting_for_id_fkey FOREIGN KEY (voting_for_id) REFERENCES public.voting_for(id);


--
-- Name: zkapp_updates zkapp_updates_zkapp_uri_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.zkapp_updates
    ADD CONSTRAINT zkapp_updates_zkapp_uri_id_fkey FOREIGN KEY (zkapp_uri_id) REFERENCES public.zkapp_uris(id);


--
-- PostgreSQL database dump complete
--

