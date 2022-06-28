--
-- PostgreSQL database dump
--

-- Dumped from database version 12.10 (Ubuntu 12.10-0ubuntu0.20.04.1)
-- Dumped by pg_dump version 12.10 (Ubuntu 12.10-0ubuntu0.20.04.1)

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
-- Name: archive; Type: DATABASE; Schema: -; Owner: -
--

CREATE DATABASE archive WITH TEMPLATE = template0 ENCODING = 'UTF8' LC_COLLATE = 'en_US.UTF-8' LC_CTYPE = 'en_US.UTF-8';


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
-- Name: call_type_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.call_type_type AS ENUM (
    'call',
    'delegate_call'
);


--
-- Name: chain_status_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.chain_status_type AS ENUM (
    'canonical',
    'orphaned',
    'pending'
);


--
-- Name: internal_command_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.internal_command_type AS ENUM (
    'fee_transfer_via_coinbase',
    'fee_transfer',
    'coinbase'
);


--
-- Name: user_command_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.user_command_status AS ENUM (
    'applied',
    'failed'
);


--
-- Name: user_command_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.user_command_type AS ENUM (
    'payment',
    'delegation'
);


--
-- Name: zkapp_auth_required_type; Type: TYPE; Schema: public; Owner: -
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
-- Name: zkapp_authorization_kind_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.zkapp_authorization_kind_type AS ENUM (
    'proof',
    'signature',
    'none_given'
);


--
-- Name: zkapp_precondition_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.zkapp_precondition_type AS ENUM (
    'full',
    'nonce',
    'accept'
);


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: account_identifiers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.account_identifiers (
    id integer NOT NULL,
    public_key_id integer NOT NULL,
    token_id integer NOT NULL
);


--
-- Name: account_identifiers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.account_identifiers_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: account_identifiers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.account_identifiers_id_seq OWNED BY public.account_identifiers.id;


--
-- Name: accounts_accessed; Type: TABLE; Schema: public; Owner: -
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
-- Name: accounts_created; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.accounts_created (
    block_id integer NOT NULL,
    account_identifier_id integer NOT NULL,
    creation_fee text NOT NULL
);


--
-- Name: blocks; Type: TABLE; Schema: public; Owner: -
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
-- Name: blocks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.blocks_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: blocks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.blocks_id_seq OWNED BY public.blocks.id;


--
-- Name: blocks_internal_commands; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.blocks_internal_commands (
    block_id integer NOT NULL,
    internal_command_id integer NOT NULL,
    sequence_no integer NOT NULL,
    secondary_sequence_no integer NOT NULL
);


--
-- Name: blocks_user_commands; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.blocks_user_commands (
    block_id integer NOT NULL,
    user_command_id integer NOT NULL,
    sequence_no integer NOT NULL,
    status public.user_command_status NOT NULL,
    failure_reason text
);


--
-- Name: blocks_zkapp_commands; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.blocks_zkapp_commands (
    block_id integer NOT NULL,
    zkapp_command_id integer NOT NULL,
    sequence_no integer NOT NULL,
    status public.user_command_status NOT NULL,
    failure_reasons_ids integer[]
);


--
-- Name: epoch_data; Type: TABLE; Schema: public; Owner: -
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
-- Name: epoch_data_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.epoch_data_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: epoch_data_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.epoch_data_id_seq OWNED BY public.epoch_data.id;


--
-- Name: internal_commands; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.internal_commands (
    id integer NOT NULL,
    typ public.internal_command_type NOT NULL,
    receiver_id integer NOT NULL,
    fee text NOT NULL,
    hash text NOT NULL
);


--
-- Name: internal_commands_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.internal_commands_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: internal_commands_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.internal_commands_id_seq OWNED BY public.internal_commands.id;


--
-- Name: public_keys; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.public_keys (
    id integer NOT NULL,
    value text NOT NULL
);


--
-- Name: public_keys_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.public_keys_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: public_keys_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.public_keys_id_seq OWNED BY public.public_keys.id;


--
-- Name: snarked_ledger_hashes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.snarked_ledger_hashes (
    id integer NOT NULL,
    value text NOT NULL
);


--
-- Name: snarked_ledger_hashes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.snarked_ledger_hashes_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: snarked_ledger_hashes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.snarked_ledger_hashes_id_seq OWNED BY public.snarked_ledger_hashes.id;


--
-- Name: timing_info; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.timing_info (
    id integer NOT NULL,
    account_identifier_id integer NOT NULL,
    initial_balance bigint NOT NULL,
    initial_minimum_balance text NOT NULL,
    cliff_time bigint NOT NULL,
    cliff_amount text NOT NULL,
    vesting_period bigint NOT NULL,
    vesting_increment text NOT NULL
);


--
-- Name: timing_info_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.timing_info_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: timing_info_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.timing_info_id_seq OWNED BY public.timing_info.id;


--
-- Name: token_symbols; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.token_symbols (
    id integer NOT NULL,
    value text NOT NULL
);


--
-- Name: token_symbols_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.token_symbols_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: token_symbols_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.token_symbols_id_seq OWNED BY public.token_symbols.id;


--
-- Name: tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tokens (
    id integer NOT NULL,
    value text NOT NULL,
    owner_public_key_id integer,
    owner_token_id integer
);


--
-- Name: tokens_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tokens_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tokens_id_seq OWNED BY public.tokens.id;


--
-- Name: user_commands; Type: TABLE; Schema: public; Owner: -
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
-- Name: user_commands_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_commands_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_commands_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_commands_id_seq OWNED BY public.user_commands.id;


--
-- Name: voting_for; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.voting_for (
    id integer NOT NULL,
    value text NOT NULL
);


--
-- Name: voting_for_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.voting_for_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: voting_for_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.voting_for_id_seq OWNED BY public.voting_for.id;


--
-- Name: zkapp_account_precondition; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.zkapp_account_precondition (
    id integer NOT NULL,
    kind public.zkapp_precondition_type NOT NULL,
    precondition_account_id integer,
    nonce bigint
);


--
-- Name: zkapp_account_precondition_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.zkapp_account_precondition_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: zkapp_account_precondition_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.zkapp_account_precondition_id_seq OWNED BY public.zkapp_account_precondition.id;


--
-- Name: zkapp_accounts; Type: TABLE; Schema: public; Owner: -
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
-- Name: zkapp_accounts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.zkapp_accounts_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: zkapp_accounts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.zkapp_accounts_id_seq OWNED BY public.zkapp_accounts.id;


--
-- Name: zkapp_amount_bounds; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.zkapp_amount_bounds (
    id integer NOT NULL,
    amount_lower_bound text NOT NULL,
    amount_upper_bound text NOT NULL
);


--
-- Name: zkapp_amount_bounds_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.zkapp_amount_bounds_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: zkapp_amount_bounds_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.zkapp_amount_bounds_id_seq OWNED BY public.zkapp_amount_bounds.id;


--
-- Name: zkapp_balance_bounds; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.zkapp_balance_bounds (
    id integer NOT NULL,
    balance_lower_bound text NOT NULL,
    balance_upper_bound text NOT NULL
);


--
-- Name: zkapp_balance_bounds_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.zkapp_balance_bounds_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: zkapp_balance_bounds_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.zkapp_balance_bounds_id_seq OWNED BY public.zkapp_balance_bounds.id;


--
-- Name: zkapp_commands; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.zkapp_commands (
    id integer NOT NULL,
    zkapp_fee_payer_body_id integer NOT NULL,
    zkapp_other_parties_ids integer[] NOT NULL,
    memo text NOT NULL,
    hash text NOT NULL
);


--
-- Name: zkapp_commands_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.zkapp_commands_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: zkapp_commands_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.zkapp_commands_id_seq OWNED BY public.zkapp_commands.id;


--
-- Name: zkapp_epoch_data; Type: TABLE; Schema: public; Owner: -
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
-- Name: zkapp_epoch_data_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.zkapp_epoch_data_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: zkapp_epoch_data_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.zkapp_epoch_data_id_seq OWNED BY public.zkapp_epoch_data.id;


--
-- Name: zkapp_epoch_ledger; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.zkapp_epoch_ledger (
    id integer NOT NULL,
    hash_id integer,
    total_currency_id integer
);


--
-- Name: zkapp_epoch_ledger_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.zkapp_epoch_ledger_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: zkapp_epoch_ledger_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.zkapp_epoch_ledger_id_seq OWNED BY public.zkapp_epoch_ledger.id;


--
-- Name: zkapp_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.zkapp_events (
    id integer NOT NULL,
    element_ids integer[]
);


--
-- Name: zkapp_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.zkapp_events_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: zkapp_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.zkapp_events_id_seq OWNED BY public.zkapp_events.id;


--
-- Name: zkapp_fee_payer_body; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.zkapp_fee_payer_body (
    id integer NOT NULL,
    account_identifier_id integer NOT NULL,
    fee text NOT NULL,
    valid_until bigint,
    nonce bigint NOT NULL
);


--
-- Name: zkapp_fee_payer_body_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.zkapp_fee_payer_body_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: zkapp_fee_payer_body_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.zkapp_fee_payer_body_id_seq OWNED BY public.zkapp_fee_payer_body.id;


--
-- Name: zkapp_fee_payers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.zkapp_fee_payers (
    id integer NOT NULL,
    body_id integer NOT NULL
);


--
-- Name: zkapp_fee_payers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.zkapp_fee_payers_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: zkapp_fee_payers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.zkapp_fee_payers_id_seq OWNED BY public.zkapp_fee_payers.id;


--
-- Name: zkapp_global_slot_bounds; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.zkapp_global_slot_bounds (
    id integer NOT NULL,
    global_slot_lower_bound bigint NOT NULL,
    global_slot_upper_bound bigint NOT NULL
);


--
-- Name: zkapp_global_slot_bounds_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.zkapp_global_slot_bounds_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: zkapp_global_slot_bounds_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.zkapp_global_slot_bounds_id_seq OWNED BY public.zkapp_global_slot_bounds.id;


--
-- Name: zkapp_length_bounds; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.zkapp_length_bounds (
    id integer NOT NULL,
    length_lower_bound bigint NOT NULL,
    length_upper_bound bigint NOT NULL
);


--
-- Name: zkapp_length_bounds_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.zkapp_length_bounds_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: zkapp_length_bounds_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.zkapp_length_bounds_id_seq OWNED BY public.zkapp_length_bounds.id;


--
-- Name: zkapp_nonce_bounds; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.zkapp_nonce_bounds (
    id integer NOT NULL,
    nonce_lower_bound bigint NOT NULL,
    nonce_upper_bound bigint NOT NULL
);


--
-- Name: zkapp_nonce_bounds_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.zkapp_nonce_bounds_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: zkapp_nonce_bounds_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.zkapp_nonce_bounds_id_seq OWNED BY public.zkapp_nonce_bounds.id;


--
-- Name: zkapp_other_party; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.zkapp_other_party (
    id integer NOT NULL,
    body_id integer NOT NULL,
    authorization_kind public.zkapp_authorization_kind_type NOT NULL
);


--
-- Name: zkapp_other_party_body; Type: TABLE; Schema: public; Owner: -
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
-- Name: zkapp_other_party_body_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.zkapp_other_party_body_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: zkapp_other_party_body_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.zkapp_other_party_body_id_seq OWNED BY public.zkapp_other_party_body.id;


--
-- Name: zkapp_other_party_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.zkapp_other_party_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: zkapp_other_party_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.zkapp_other_party_id_seq OWNED BY public.zkapp_other_party.id;


--
-- Name: zkapp_party_failures; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.zkapp_party_failures (
    id integer NOT NULL,
    index integer NOT NULL,
    failures text[] NOT NULL
);


--
-- Name: zkapp_party_failures_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.zkapp_party_failures_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: zkapp_party_failures_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.zkapp_party_failures_id_seq OWNED BY public.zkapp_party_failures.id;


--
-- Name: zkapp_permissions; Type: TABLE; Schema: public; Owner: -
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
-- Name: zkapp_permissions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.zkapp_permissions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: zkapp_permissions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.zkapp_permissions_id_seq OWNED BY public.zkapp_permissions.id;


--
-- Name: zkapp_precondition_accounts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.zkapp_precondition_accounts (
    id integer NOT NULL,
    balance_id integer,
    nonce_id integer,
    receipt_chain_hash text,
    delegate_id integer,
    state_id integer NOT NULL,
    sequence_state_id integer,
    proved_state boolean
);


--
-- Name: zkapp_precondition_accounts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.zkapp_precondition_accounts_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: zkapp_precondition_accounts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.zkapp_precondition_accounts_id_seq OWNED BY public.zkapp_precondition_accounts.id;


--
-- Name: zkapp_network_precondition; Type: TABLE; Schema: public; Owner: -
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
-- Name: zkapp_network_precondition_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.zkapp_network_precondition_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: zkapp_network_precondition_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.zkapp_network_precondition_id_seq OWNED BY public.zkapp_network_precondition.id;


--
-- Name: zkapp_sequence_states; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.zkapp_sequence_states (
    id integer NOT NULL,
    element_ids integer[]
);


--
-- Name: zkapp_sequence_states_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.zkapp_sequence_states_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: zkapp_sequence_states_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.zkapp_sequence_states_id_seq OWNED BY public.zkapp_sequence_states.id;


--
-- Name: zkapp_state_data; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.zkapp_state_data (
    id integer NOT NULL,
    field text NOT NULL
);


--
-- Name: zkapp_state_data_array; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.zkapp_state_data_array (
    id integer NOT NULL,
    element_ids integer[] NOT NULL
);


--
-- Name: zkapp_state_data_array_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.zkapp_state_data_array_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: zkapp_state_data_array_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.zkapp_state_data_array_id_seq OWNED BY public.zkapp_state_data_array.id;


--
-- Name: zkapp_state_data_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.zkapp_state_data_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: zkapp_state_data_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.zkapp_state_data_id_seq OWNED BY public.zkapp_state_data.id;


--
-- Name: zkapp_states; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.zkapp_states (
    id integer NOT NULL,
    element_ids integer[]
);


--
-- Name: zkapp_states_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.zkapp_states_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: zkapp_states_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.zkapp_states_id_seq OWNED BY public.zkapp_states.id;


--
-- Name: zkapp_timestamp_bounds; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.zkapp_timestamp_bounds (
    id integer NOT NULL,
    timestamp_lower_bound text NOT NULL,
    timestamp_upper_bound text NOT NULL
);


--
-- Name: zkapp_timestamp_bounds_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.zkapp_timestamp_bounds_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: zkapp_timestamp_bounds_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.zkapp_timestamp_bounds_id_seq OWNED BY public.zkapp_timestamp_bounds.id;


--
-- Name: zkapp_timing_info; Type: TABLE; Schema: public; Owner: -
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
-- Name: zkapp_timing_info_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.zkapp_timing_info_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: zkapp_timing_info_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.zkapp_timing_info_id_seq OWNED BY public.zkapp_timing_info.id;


--
-- Name: zkapp_token_id_bounds; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.zkapp_token_id_bounds (
    id integer NOT NULL,
    token_id_lower_bound text NOT NULL,
    token_id_upper_bound text NOT NULL
);


--
-- Name: zkapp_token_id_bounds_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.zkapp_token_id_bounds_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: zkapp_token_id_bounds_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.zkapp_token_id_bounds_id_seq OWNED BY public.zkapp_token_id_bounds.id;


--
-- Name: zkapp_updates; Type: TABLE; Schema: public; Owner: -
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
-- Name: zkapp_updates_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.zkapp_updates_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: zkapp_updates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.zkapp_updates_id_seq OWNED BY public.zkapp_updates.id;


--
-- Name: zkapp_uris; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.zkapp_uris (
    id integer NOT NULL,
    value text NOT NULL
);


--
-- Name: zkapp_uris_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.zkapp_uris_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: zkapp_uris_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.zkapp_uris_id_seq OWNED BY public.zkapp_uris.id;


--
-- Name: zkapp_verification_keys; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.zkapp_verification_keys (
    id integer NOT NULL,
    verification_key text NOT NULL,
    hash text NOT NULL
);


--
-- Name: zkapp_verification_keys_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.zkapp_verification_keys_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: zkapp_verification_keys_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.zkapp_verification_keys_id_seq OWNED BY public.zkapp_verification_keys.id;


--
-- Name: account_identifiers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_identifiers ALTER COLUMN id SET DEFAULT nextval('public.account_identifiers_id_seq'::regclass);


--
-- Name: blocks id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blocks ALTER COLUMN id SET DEFAULT nextval('public.blocks_id_seq'::regclass);


--
-- Name: epoch_data id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.epoch_data ALTER COLUMN id SET DEFAULT nextval('public.epoch_data_id_seq'::regclass);


--
-- Name: internal_commands id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.internal_commands ALTER COLUMN id SET DEFAULT nextval('public.internal_commands_id_seq'::regclass);


--
-- Name: public_keys id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.public_keys ALTER COLUMN id SET DEFAULT nextval('public.public_keys_id_seq'::regclass);


--
-- Name: snarked_ledger_hashes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.snarked_ledger_hashes ALTER COLUMN id SET DEFAULT nextval('public.snarked_ledger_hashes_id_seq'::regclass);


--
-- Name: timing_info id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.timing_info ALTER COLUMN id SET DEFAULT nextval('public.timing_info_id_seq'::regclass);


--
-- Name: token_symbols id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.token_symbols ALTER COLUMN id SET DEFAULT nextval('public.token_symbols_id_seq'::regclass);


--
-- Name: tokens id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tokens ALTER COLUMN id SET DEFAULT nextval('public.tokens_id_seq'::regclass);


--
-- Name: user_commands id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_commands ALTER COLUMN id SET DEFAULT nextval('public.user_commands_id_seq'::regclass);


--
-- Name: voting_for id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.voting_for ALTER COLUMN id SET DEFAULT nextval('public.voting_for_id_seq'::regclass);


--
-- Name: zkapp_account_precondition id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_account_precondition ALTER COLUMN id SET DEFAULT nextval('public.zkapp_account_precondition_id_seq'::regclass);


--
-- Name: zkapp_accounts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_accounts ALTER COLUMN id SET DEFAULT nextval('public.zkapp_accounts_id_seq'::regclass);


--
-- Name: zkapp_amount_bounds id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_amount_bounds ALTER COLUMN id SET DEFAULT nextval('public.zkapp_amount_bounds_id_seq'::regclass);


--
-- Name: zkapp_balance_bounds id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_balance_bounds ALTER COLUMN id SET DEFAULT nextval('public.zkapp_balance_bounds_id_seq'::regclass);


--
-- Name: zkapp_commands id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_commands ALTER COLUMN id SET DEFAULT nextval('public.zkapp_commands_id_seq'::regclass);


--
-- Name: zkapp_epoch_data id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_epoch_data ALTER COLUMN id SET DEFAULT nextval('public.zkapp_epoch_data_id_seq'::regclass);


--
-- Name: zkapp_epoch_ledger id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_epoch_ledger ALTER COLUMN id SET DEFAULT nextval('public.zkapp_epoch_ledger_id_seq'::regclass);


--
-- Name: zkapp_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_events ALTER COLUMN id SET DEFAULT nextval('public.zkapp_events_id_seq'::regclass);


--
-- Name: zkapp_fee_payer_body id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_fee_payer_body ALTER COLUMN id SET DEFAULT nextval('public.zkapp_fee_payer_body_id_seq'::regclass);


--
-- Name: zkapp_fee_payers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_fee_payers ALTER COLUMN id SET DEFAULT nextval('public.zkapp_fee_payers_id_seq'::regclass);


--
-- Name: zkapp_global_slot_bounds id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_global_slot_bounds ALTER COLUMN id SET DEFAULT nextval('public.zkapp_global_slot_bounds_id_seq'::regclass);


--
-- Name: zkapp_length_bounds id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_length_bounds ALTER COLUMN id SET DEFAULT nextval('public.zkapp_length_bounds_id_seq'::regclass);


--
-- Name: zkapp_nonce_bounds id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_nonce_bounds ALTER COLUMN id SET DEFAULT nextval('public.zkapp_nonce_bounds_id_seq'::regclass);


--
-- Name: zkapp_other_party id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_other_party ALTER COLUMN id SET DEFAULT nextval('public.zkapp_other_party_id_seq'::regclass);


--
-- Name: zkapp_other_party_body id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_other_party_body ALTER COLUMN id SET DEFAULT nextval('public.zkapp_other_party_body_id_seq'::regclass);


--
-- Name: zkapp_party_failures id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_party_failures ALTER COLUMN id SET DEFAULT nextval('public.zkapp_party_failures_id_seq'::regclass);


--
-- Name: zkapp_permissions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_permissions ALTER COLUMN id SET DEFAULT nextval('public.zkapp_permissions_id_seq'::regclass);


--
-- Name: zkapp_precondition_accounts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_precondition_accounts ALTER COLUMN id SET DEFAULT nextval('public.zkapp_precondition_accounts_id_seq'::regclass);


--
-- Name: zkapp_network_precondition id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_network_precondition ALTER COLUMN id SET DEFAULT nextval('public.zkapp_network_precondition_id_seq'::regclass);


--
-- Name: zkapp_sequence_states id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_sequence_states ALTER COLUMN id SET DEFAULT nextval('public.zkapp_sequence_states_id_seq'::regclass);


--
-- Name: zkapp_state_data id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_state_data ALTER COLUMN id SET DEFAULT nextval('public.zkapp_state_data_id_seq'::regclass);


--
-- Name: zkapp_state_data_array id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_state_data_array ALTER COLUMN id SET DEFAULT nextval('public.zkapp_state_data_array_id_seq'::regclass);


--
-- Name: zkapp_states id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_states ALTER COLUMN id SET DEFAULT nextval('public.zkapp_states_id_seq'::regclass);


--
-- Name: zkapp_timestamp_bounds id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_timestamp_bounds ALTER COLUMN id SET DEFAULT nextval('public.zkapp_timestamp_bounds_id_seq'::regclass);


--
-- Name: zkapp_timing_info id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_timing_info ALTER COLUMN id SET DEFAULT nextval('public.zkapp_timing_info_id_seq'::regclass);


--
-- Name: zkapp_token_id_bounds id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_token_id_bounds ALTER COLUMN id SET DEFAULT nextval('public.zkapp_token_id_bounds_id_seq'::regclass);


--
-- Name: zkapp_updates id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_updates ALTER COLUMN id SET DEFAULT nextval('public.zkapp_updates_id_seq'::regclass);


--
-- Name: zkapp_uris id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_uris ALTER COLUMN id SET DEFAULT nextval('public.zkapp_uris_id_seq'::regclass);


--
-- Name: zkapp_verification_keys id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_verification_keys ALTER COLUMN id SET DEFAULT nextval('public.zkapp_verification_keys_id_seq'::regclass);


--
-- Data for Name: token_symbols; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.token_symbols (id, value) FROM stdin;
1	
2	BOLSYM
\.


--
-- Data for Name: zkapp_uris; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.zkapp_uris (id, value) FROM stdin;
1	
2	https://www.example.com
\.


--
-- Data for Name: account_identifiers; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.account_identifiers (id, public_key_id, token_id) FROM stdin;
1	1	1
2	2	1
3	3	1
4	4	1
5	6	1
\.


--
-- Data for Name: accounts_accessed; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.accounts_accessed (ledger_index, block_id, account_identifier_id, token_symbol_id, balance, nonce, receipt_chain_hash, delegate_id, voting_for_id, timing_id, permissions_id, zkapp_id) FROM stdin;
4	2	4	1	1440000000000	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	4	1	4	1	\N
2	3	2	1	491250000000	35	2n1LXgNvGt5K9PY8N8XKo4rNTCbnR7UGK4x4DjiqzegYqstLHqgH	2	1	2	1	\N
4	3	4	1	2888750000000	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	4	1	4	1	\N
2	4	2	1	477000000000	92	2n1SfuK7A5VSesBPGJGL1eAM8r7TiCHD8Jbt73Vi4PW49TXv6v6g	2	1	2	1	\N
245	4	5	1	11000000000	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	6	1	5	2	1
4	4	4	1	4331000000000	2	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	4	1	4	1	\N
1	5	1	2	65500000000000	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	2	1	1	3	\N
2	5	2	1	462750000000	149	2mzZbGYZcTNsCgig8uWTV73UgVitY76XbAUz3ZnZn9JL8L3DWpXa	2	1	2	1	\N
4	5	4	1	5785250000000	5	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	4	1	4	1	\N
\.


--
-- Data for Name: accounts_created; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.accounts_created (block_id, account_identifier_id, creation_fee) FROM stdin;
4	5	1000000000
\.


--
-- Data for Name: blocks; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.blocks (id, state_hash, parent_id, parent_hash, creator_id, block_winner_id, snarked_ledger_hash_id, staking_epoch_data_id, next_epoch_data_id, min_window_density, total_currency, ledger_hash, height, global_slot_since_hard_fork, global_slot_since_genesis, "timestamp", chain_status) FROM stdin;
1	3NLDRvvByy2GMYivoFg7FADtNzjqZZ71jX2AZDVdxqtYLusb7AcV	\N	3NKBXHShSYqxwWuxRiFXCSCNKmDVJaEgTHh4FRSYWzMTJ9MRseTC	5	5	1	1	2	77	11616000000065089	jxjJQUU4K3u2yXpLPCFqcYbqA3ZfTrEgn3Gqw96V5rwWRgkGZtr	1	0	0	1651708749987	canonical
2	3NKHwN7Hg65eGsM2fY3kn3m5KvVsK6GVFgAgVNoXDRnCRhr1UVWJ	1	3NLDRvvByy2GMYivoFg7FADtNzjqZZ71jX2AZDVdxqtYLusb7AcV	4	3	1	1	3	77	11616000000065089	jwtggYGqA1qVbLqrpuXoEksBi3ddT7GM1qVAbUMvDg2jz3nMj64	2	1	1	1651708944856	pending
3	3NLejSrDnJMo1BRVSq6fqzZMAupQRiA1eB98yEbh6SNxyiGXWYRJ	2	3NKHwN7Hg65eGsM2fY3kn3m5KvVsK6GVFgAgVNoXDRnCRhr1UVWJ	4	3	1	1	4	77	11616000000065089	jxcKVgdor95eAatRgWe3TZWrweSjxvAwvcZJ1g6TMHb4dcDVU7n	3	2	2	1651709109987	pending
4	3NKRDvPbuYVUX23tMVCMA33U5Qrua6A4EFpTfyu4UJzsa27x97aY	3	3NLejSrDnJMo1BRVSq6fqzZMAupQRiA1eB98yEbh6SNxyiGXWYRJ	4	3	1	1	5	77	11616000000065089	jwztmpmEC61N5QYkaMb1tbiNCDeNVhoyhj8bU7eKV65syUDEqT6	4	3	3	1651709289987	pending
5	3NLuycS3WqnYZBxgLTYBXv8a1qYaS6CSt2ZQ4cG3gi4rvD64yDsg	4	3NKRDvPbuYVUX23tMVCMA33U5Qrua6A4EFpTfyu4UJzsa27x97aY	4	3	1	1	6	77	11616000000065089	jwexhTzbjxHmy7wrbEPLzt3aQKsszzwoq9vYqkgdV43dCh6iq6A	5	4	4	1651709469987	pending
\.


--
-- Data for Name: blocks_internal_commands; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.blocks_internal_commands (block_id, internal_command_id, sequence_no, secondary_sequence_no) FROM stdin;
2	1	0	0
3	1	35	0
3	2	36	0
4	1	58	0
4	3	59	0
5	4	29	0
5	1	61	0
5	5	62	0
\.


--
-- Data for Name: blocks_user_commands; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.blocks_user_commands (block_id, user_command_id, sequence_no, status, failure_reason) FROM stdin;
3	1	0	applied	\N
3	2	1	applied	\N
3	3	2	applied	\N
3	4	3	applied	\N
3	5	4	applied	\N
3	6	5	applied	\N
3	7	6	applied	\N
3	8	7	applied	\N
3	9	8	applied	\N
3	10	9	applied	\N
3	11	10	applied	\N
3	12	11	applied	\N
3	13	12	applied	\N
3	14	13	applied	\N
3	15	14	applied	\N
3	16	15	applied	\N
3	17	16	applied	\N
3	18	17	applied	\N
3	19	18	applied	\N
3	20	19	applied	\N
3	21	20	applied	\N
3	22	21	applied	\N
3	23	22	applied	\N
3	24	23	applied	\N
3	25	24	applied	\N
3	26	25	applied	\N
3	27	26	applied	\N
3	28	27	applied	\N
3	29	28	applied	\N
3	30	29	applied	\N
3	31	30	applied	\N
3	32	31	applied	\N
3	33	32	applied	\N
3	34	33	applied	\N
3	35	34	applied	\N
4	36	1	applied	\N
4	37	2	applied	\N
4	38	3	applied	\N
4	39	4	applied	\N
4	40	5	applied	\N
4	41	6	applied	\N
4	42	7	applied	\N
4	43	8	applied	\N
4	44	9	applied	\N
4	45	10	applied	\N
4	46	11	applied	\N
4	47	12	applied	\N
4	48	13	applied	\N
4	49	14	applied	\N
4	50	15	applied	\N
4	51	16	applied	\N
4	52	17	applied	\N
4	53	18	applied	\N
4	54	19	applied	\N
4	55	20	applied	\N
4	56	21	applied	\N
4	57	22	applied	\N
4	58	23	applied	\N
4	59	24	applied	\N
4	60	25	applied	\N
4	61	26	applied	\N
4	62	27	applied	\N
4	63	28	applied	\N
4	64	29	applied	\N
4	65	30	applied	\N
4	66	31	applied	\N
4	67	32	applied	\N
4	68	33	applied	\N
4	69	34	applied	\N
4	70	35	applied	\N
4	71	36	applied	\N
4	72	37	applied	\N
4	73	38	applied	\N
4	74	39	applied	\N
4	75	40	applied	\N
4	76	41	applied	\N
4	77	42	applied	\N
4	78	43	applied	\N
4	79	44	applied	\N
4	80	45	applied	\N
4	81	46	applied	\N
4	82	47	applied	\N
4	83	48	applied	\N
4	84	49	applied	\N
4	85	50	applied	\N
4	86	51	applied	\N
4	87	52	applied	\N
4	88	53	applied	\N
4	89	54	applied	\N
4	90	55	applied	\N
4	91	56	applied	\N
4	92	57	applied	\N
5	93	3	applied	\N
5	94	4	applied	\N
5	95	5	applied	\N
5	96	6	applied	\N
5	97	7	applied	\N
5	98	8	applied	\N
5	99	9	applied	\N
5	100	10	applied	\N
5	101	11	applied	\N
5	102	12	applied	\N
5	103	13	applied	\N
5	104	14	applied	\N
5	105	15	applied	\N
5	106	16	applied	\N
5	107	17	applied	\N
5	108	18	applied	\N
5	109	19	applied	\N
5	110	20	applied	\N
5	111	21	applied	\N
5	112	22	applied	\N
5	113	23	applied	\N
5	114	24	applied	\N
5	115	25	applied	\N
5	116	26	applied	\N
5	117	27	applied	\N
5	118	28	applied	\N
5	119	30	applied	\N
5	120	31	applied	\N
5	121	32	applied	\N
5	122	33	applied	\N
5	123	34	applied	\N
5	124	35	applied	\N
5	125	36	applied	\N
5	126	37	applied	\N
5	127	38	applied	\N
5	128	39	applied	\N
5	129	40	applied	\N
5	130	41	applied	\N
5	131	42	applied	\N
5	132	43	applied	\N
5	133	44	applied	\N
5	134	45	applied	\N
5	135	46	applied	\N
5	136	47	applied	\N
5	137	48	applied	\N
5	138	49	applied	\N
5	139	50	applied	\N
5	140	51	applied	\N
5	141	52	applied	\N
5	142	53	applied	\N
5	143	54	applied	\N
5	144	55	applied	\N
5	145	56	applied	\N
5	146	57	applied	\N
5	147	58	applied	\N
5	148	59	applied	\N
5	149	60	applied	\N
\.


--
-- Data for Name: blocks_zkapp_commands; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.blocks_zkapp_commands (block_id, zkapp_command_id, sequence_no, status, failure_reasons_ids) FROM stdin;
4	1	0	applied	\N
5	2	0	applied	\N
5	3	1	applied	\N
5	4	2	applied	\N
\.


--
-- Data for Name: epoch_data; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.epoch_data (id, seed, ledger_hash_id, total_currency, start_checkpoint, lock_checkpoint, epoch_length) FROM stdin;
1	2va9BGv9JrLTtrzZttiEMDYw1Zj6a6EHzXjmP9evHDTG3oEquURA	1	11616000000065089	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	1
2	2vc1zQHJx2xN72vaR4YDH31KwFSr5WHSEH2dzcfcq8jxBPcGiJJA	1	11616000000065089	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKBXHShSYqxwWuxRiFXCSCNKmDVJaEgTHh4FRSYWzMTJ9MRseTC	2
3	2vbttHTpkW19NcehYWGYmzu7StqfKwbxzqDQqk3uZDPKshgE661T	1	11616000000065089	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLDRvvByy2GMYivoFg7FADtNzjqZZ71jX2AZDVdxqtYLusb7AcV	3
4	2vb7Srh3yFgB2bAYTnK8H7MNiUwvWqpav9CWYUCsdiUWDBC7zHKC	1	11616000000065089	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKHwN7Hg65eGsM2fY3kn3m5KvVsK6GVFgAgVNoXDRnCRhr1UVWJ	4
5	2vb8SkuwK1KcdW7aF8tt8QrZb7vpsyv5Zg65qMZzBUZeBSr7h6b8	1	11616000000065089	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLejSrDnJMo1BRVSq6fqzZMAupQRiA1eB98yEbh6SNxyiGXWYRJ	5
6	2vaXUEQSBMUAneXPyGEPhNMRd6GDpsAUuqV72idgQVT9mY729PBT	1	11616000000065089	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKRDvPbuYVUX23tMVCMA33U5Qrua6A4EFpTfyu4UJzsa27x97aY	6
\.


--
-- Data for Name: internal_commands; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.internal_commands (id, typ, receiver_id, fee, hash) FROM stdin;
1	coinbase	4	1440000000000	CkpYhMPDHTBcx7ZUvUibDcSGA36xQoQdEFnX9ZpJ9nrn5YZcuPo77
2	fee_transfer	4	8750000000	CkpZXCxaMr2ax84CJma9xLAq9JrfgoYKoFMKTJuTSjZaoEPgg7rjH
3	fee_transfer	4	15250000000	CkpYQF3qR8M1KyBo4tuKeTZhgs9SxRMPfQhKsQ4rpLMrR5C5UnPz3
4	fee_transfer	4	9500000000	CkpZ3PdVUKcWv5D8Zyjqiwh5ToFUmojJ4EQp5aboqkPYKaaH41PpT
5	fee_transfer	4	7750000000	CkpZTh4r9UZDmD1jovoEaxmteSrm8Egm8q7xW1F1oYW9D5pq1g3Zc
\.


--
-- Data for Name: public_keys; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.public_keys (id, value) FROM stdin;
1	B62qj9k4sCvNuVMF6nkyJbFdn4pFeM13v8LWsn8W9v6uLFouzZkWSJG
2	B62qomLRmUYxuYLbUA2q7JB1BpHGVr2wsVw6ExZnEEVtWbf6JuHGURj
3	B62qk9scdPkmeArxyDAFsaXT4tKPH498PvbWZu15JjV14g2XRxMQFi8
4	B62qoxw8SUiXVnLSmqn5Kt23h1yNMiKQ14X6jfJy3rftbhwPpeppXPV
5	B62qiy32p8kAKnny8ZFwoMhYpBppM1DWVCqAPBYNcXnsAHhnfAAuXgg
6	B62qkkabkoqW8K1KS1HKMo8DSdAM8gmEm6R2A91fgJKVwB3JLcFPKy8
\.


--
-- Data for Name: snarked_ledger_hashes; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.snarked_ledger_hashes (id, value) FROM stdin;
1	jxjJQUU4K3u2yXpLPCFqcYbqA3ZfTrEgn3Gqw96V5rwWRgkGZtr
\.


--
-- Data for Name: timing_info; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.timing_info (id, account_identifier_id, initial_balance, initial_minimum_balance, cliff_time, cliff_amount, vesting_period, vesting_increment) FROM stdin;
1	1	65500000000000	0	0	0	0	0
2	2	500000000000	0	0	0	0	0
3	3	11550000000000000	0	0	0	0	0
4	4	0	0	0	0	0	0
5	5	11000000000	0	0	0	0	0
\.


--
-- Data for Name: tokens; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.tokens (id, value, owner_public_key_id, owner_token_id) FROM stdin;
1	wSHV2S4qX9jFsLjQo8r1BsMLH2ZRKsZx6EJd1sbozGPieEC4Jf	\N	\N
\.


--
-- Data for Name: user_commands; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.user_commands (id, typ, fee_payer_id, source_id, receiver_id, nonce, amount, fee, valid_until, memo, hash) FROM stdin;
1	payment	2	2	2	0	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZep4BWTF5u6ckMUqzn71sTnQhSkBntzvrNqdBFZMGFX74Yc7LD
2	payment	2	2	2	1	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZ43iK73SXykR3q8r8vbX6zEPQGDkwoDVW4KNxsTEvZL4nThuje
3	payment	2	2	2	2	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYY3J9KYRuA5gbTcPfeRDg7AdhC2wm9kN2b9S41CHYwmM4xvWDq
4	payment	2	2	2	3	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYyY5igwP6dw85qSQG5RhG4jkNamuCpkbZ7UoAbfbTQykwEN4ed
5	payment	2	2	2	4	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZJ55JJh4WoGbgtapuaktZwzmNymPYNG8mPzLfFsL1Bm1AWsP3X
6	payment	2	2	2	5	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYy9sygmP1RU48o3MpQfjNpCBtCSonW5i7Jjv9T4cf9jaizETzo
7	payment	2	2	2	6	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpaHjKhHYepGbqCgMfsfF1dg9Fmz96kbUVegdbbMgoC5BmWedA96
8	payment	2	2	2	7	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZBQVs1B1ypE6SuXbsDhAG8xbppMeHdRrb7mDtje5vHMQMVHApK
9	payment	2	2	2	8	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYU4FsWAucmgsMi9nkRTejUKzcbWXp95aWDehWMM4NiFo6z2tWq
10	payment	2	2	2	9	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYSzLd2Y5xGZvQ56Bzd2euUzSZsoi3u7MqheJx5YGrTiPY1DdmX
11	payment	2	2	2	10	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYic6afDveAou2zcSeQZNXY6nndZaBh2jGYW8QyN3wDTJj9ySZ8
12	payment	2	2	2	11	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYkHo6UsfcCiHJXjGsdNTryyqk6nbkboxt4AcgssCzTF7svS9eN
13	payment	2	2	2	12	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYXjJ6LnUFH69i836XvGQZqNdcb5uevd61i5BTN1yHhHMY6sHWS
14	payment	2	2	2	13	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZtiJVbJeSzR7B9edAZ5RYu8V9UMbKfpykmX3eELy1eN6pMpBRx
15	payment	2	2	2	14	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZ9L789tFp3o9QGHougj8XxyghyV6wfjvaj7oYkqqSBiY97GAAu
16	payment	2	2	2	15	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYR1ZvdMHDFLYESqgoDMrYrLZTgr3G7cJGB1EkgqfXLDvuKYNdv
17	payment	2	2	2	16	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYxL3wCnM7A7WC5dVvLNSs8FFxS9GwdUPK7Yyt2KQaUUKFrGBK2
18	payment	2	2	2	17	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYdjeAMtvgy5gHjAAxfrLUs6faBh8Zri3GCm2M9dwavC1NFvMBM
19	payment	2	2	2	18	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZkG2gZfvJcb9LRFuLPg8q9zrdXv5WyMnoP8YakjndqYywLuKdR
20	payment	2	2	2	19	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYk113mNNBEDcH8LoR5RZcGGow2zcVqHMBmL9Yds7PtAtaEfzCc
21	payment	2	2	2	20	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZwvigJC55LvFwqJkmxRFYQxGsjWujX4jayp7ter5rUFZXE5ZCi
22	payment	2	2	2	21	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYtmP3ai9ECk1DgLnrCNtPsPCxpQ7GADqFpuM6Pwzv9cUh57Yh1
23	payment	2	2	2	22	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYkHrye6NbhQVsLrkDhytFBPadRSrEWd7yr8Av53UXyRbqCLmcK
24	payment	2	2	2	23	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZFZjC5Po1G89g6tgnumVKzJdvHx8mm5at98Y8xUkZv4LxbQweY
25	payment	2	2	2	24	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZEp5F7wkqbTqdMorDtLrdDGWDjQtwrKx5wU8ucMzuuogRvk4dP
26	payment	2	2	2	25	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpaEUvmzauvnitEffR8ykvqUTDamGuMq3K2RUFVv2igXBZAG7RRT
27	payment	2	2	2	26	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZdwq5EpgDoLBUM8aZsVU1KHLVFPV4adyjjCapCBoE5zm4ckwbH
28	payment	2	2	2	27	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpaKTsvXbkFbhUDjWWrZog7pqerR5oy1v1xWUob9rsSLgYhPHiuT
29	payment	2	2	2	28	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpaF8pgJkW6dpSKvBCd6TRryXwwvCcG7sRVLXarakRSd4bc6qhzm
30	payment	2	2	2	29	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZx6gRMhhSrTWm8azvVgYiz3jgdV58VN8kkNsvJz3CiroY8erzA
31	payment	2	2	2	30	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpaAo6jdAr9EPZsSfQxJmbZ1HnWWUZCJHbw6PjxixqoJfNAr5AHQ
32	payment	2	2	2	31	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZ6oThcd4z6GR8j14AJbJYA3MtEv9CbwgWs9d4qkvqmtLPvnZoD
33	payment	2	2	2	32	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZgXUoPhz96qQgknA4zswhyxxKgpY2St1V7M6GRJaobfjesvRyb
34	payment	2	2	2	33	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZXTqT8gphypQ69frzW6x97RmqmGuatA7DwfYLrcnRvVnDUVrUu
35	payment	2	2	2	34	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpaLFXDcPqCQJvTgnzMT7VvNy3wWF9iMEvT8kgtDkadsaBpThDUu
36	payment	2	2	2	35	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpaJsT2aguptYXmcrdAv6um7ZdMkuto6PmJ835Qo9NQjpB9f834B
37	payment	2	2	2	36	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZmuwqc7VkyneJ3Bz6kz6cFwUZU3i2z4kaQUTGfirzWjJVeJN5b
38	payment	2	2	2	37	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYj873FBQ3eHPD6mcL6yj4x9rp6vG3MY5Zv5mEhANjYMeC151sm
39	payment	2	2	2	38	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZPzUFExFZssTqLFRQdQPodF1uYXN4o9Suustcs77j3VPt5ckYH
40	payment	2	2	2	39	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZajNBRJyDQSFtxn7Jw96Z81YHr1d67Pu3T5QEJycqdJTrPsHvQ
41	payment	2	2	2	40	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpaDxgEG41i1Bd1Q3ZiQfjPtYBkYfNyP3KhDetXQ2M1EhCoHdXd5
42	payment	2	2	2	41	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpaJS3VXjtRQMd8vKs7SkR3CkUP6HMX5FRjmqYiibM92zBuPJNsi
43	payment	2	2	2	42	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZTcWUcKua5KnXzkMprD8JFVYAVZwdnLxtyvXDfsvFJp1UQXbMo
44	payment	2	2	2	43	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZEmidGFkissx6nC3mKwymqPoSbbNx3NzNnZFb1weN5DR6PhUz8
45	payment	2	2	2	44	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZ8F34fLGbGjjXCiCKp8mjD3rPt312qTQwd3xqmApedQT7GVJ8N
46	payment	2	2	2	45	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZu51UvxjFoFxSUayumLxgqHTwfNdkrAeFDHBXAgxWesPpCPhQB
47	payment	2	2	2	46	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpaL4btzFcZiBhioa5nJsvvjNj1vbXCPAUfPBwQ1U9Yz13UV7krG
48	payment	2	2	2	47	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZ3aTtKhTWJCumwiMhnUWeVzV8mtfh8f9SoNe4hRR8dMQBvCqew
49	payment	2	2	2	48	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZZwL2kuG3pcp5FPNBrkkDiAt4NcMhreUpZ21BAvU5RAArq4FvB
50	payment	2	2	2	49	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZqfAyc344EgtT9pQ2zatSe5833qU61KoK7fgLcvPXobmW98WG2
51	payment	2	2	2	50	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZPRwCaGgvcy6Q5oNnXCW4SdZ76XtqQnJn9sd5CfUy6PeeriS3s
52	payment	2	2	2	51	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYYfBGP3gL8gDEmbthYEQ7TCNtAT7xDb4pHhm5SJDmfApE1wkZ5
53	payment	2	2	2	52	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYyLyJFyxRQ62rasBrzFMDuyXV8EqP3xXmcE8sjNfK5MdWgzR14
54	payment	2	2	2	53	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	Ckpa4DcCQeBPszD2ZAnRqNpEW46mmNhLJ42f2jQKRJXcLTFh99kYv
55	payment	2	2	2	54	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYeGvptiYH2cy7q58zELPAszaKrRmKX92sFpsDgR1aExKviK6hx
56	payment	2	2	2	55	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZ726iVXiuxdRQ7DAyL5yCuV9ZkiHgGJbTUNzY7esgDRbjy3AGu
57	payment	2	2	2	56	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpaGMGT8xEJdFhSVopo5Aund4j491z7oLwpnRx2N2mqfs5F2u4B9
58	payment	2	2	2	57	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYwii8ZT3tXKDKp1nuYNxzKNVzcpVLPAR5Y46oQTPHCjp7vCVRw
59	payment	2	2	2	58	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYekZ5bAke925DeGGWrgAxXzhUPrQQY9VZAqnUYxmiDq75dSQP6
60	payment	2	2	2	59	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZ1WqFxPTixQJzu1XQg3u9JtpFrcvQt6XYvXKYgy6jjMP3kX5ZV
61	payment	2	2	2	60	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZuSAHqVWdq6D467miqEuh5c7D7javMGfwiv8ykq9RdhC631xZ2
62	payment	2	2	2	61	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYgaJQE4GmRWNmGK5jZ4V2pi8gVyhfwPx6dfL4yZsu56WNx8mdG
63	payment	2	2	2	62	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZeWfuCUZTyhcJh8eS4w23ywvovjRbuAEME87TetjV524j4b8ME
64	payment	2	2	2	63	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZH8yNsAEDHrEGMMdBXCFxwNCmTHRh2zqgZRSgW9B8Nkecupn1u
65	payment	2	2	2	64	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpaKSjXsD2KzazfFaQVRkUH6thDjoozFjkLijbyk4bwjTjn35HPt
66	payment	2	2	2	65	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYbNv5UXMLee5BMkGwLTWa9Q3ygMaAuohfUma5SyEtmkMWxmJpM
67	payment	2	2	2	66	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZ9q9LB7mNLE2zhMf4NqJmCWZX8XKjRq6i3c79oLhGDCtn9B1fg
68	payment	2	2	2	67	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYSYPY5G2qo1nAhMpZ7oNKBJsHfiTKYLanTWJBquRrx6acH45zE
69	payment	2	2	2	68	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpaKWcfi5mq2YxTR1tzFzxKykJsiT4nVqoCjsvLviAriehQ52FQp
70	payment	2	2	2	69	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYzp3Rb8e8Gpktx2gmD4fHcbqm58YChTuFn6iNoAVSREyGUgSHU
71	payment	2	2	2	70	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZgJ8TB3mPwroghVUfzRQpitRPF4Lk7jrJWWKVFjEoKxA9AMoHs
72	payment	2	2	2	71	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpaA92BBky7DyuXtj7rq7BmXp5g2MoJGCJVq8Fnw3dkFjJsQ6Ms1
73	payment	2	2	2	72	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZgR5zBAsYuuYiKbYMd76JPZT5KaWSn9xDhjNr96cX8v1WrE96d
74	payment	2	2	2	73	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZiZEG2AJQfjvYe2AkBqNwDmXngKRxAxLnmY876bZtXmPQ4uz96
75	payment	2	2	2	74	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZG7Qf9VD7V4Yxz26CBeqeLZNshE7rQBfyByjFFV59ZqHykUynq
76	payment	2	2	2	75	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	Ckpa1vWhay2RnmN5MqSUzDZ8nH4bwe8pHbpde4gHzwgZm5HpcVoqY
77	payment	2	2	2	76	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZ7wYHa7ujczsrXeAjugcUeeyoemr6Sm7oj1Hwhuc22BjkKiS8r
78	payment	2	2	2	77	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZZVf842wiDGthZrgj7aiQETUehjfATsX6m5DP7JVixMsZPMqRo
79	payment	2	2	2	78	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZUD29FSgtqjgXUtbwXqFbfYj36Sw4VrkqrFnR8147sWcUSeE7w
80	payment	2	2	2	79	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZMN7gp7ivPmyM8eGrstHpAteNXkQ7wRNKowW51hNsDhiLP5HZb
81	payment	2	2	2	80	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpaJhFLPCY6Tjt3zeH91Z6rtUeCSEics9eHj9nDb6shTRNVfAkXi
82	payment	2	2	2	81	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpaEbrqh3q5Ggop5EJ7chrhga9KBNrhqKBkxRdzzMYkbvTHnt5ku
83	payment	2	2	2	82	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZ8Ar81jjUyLuqGpwkRzAWBRS3dgw5QckWn1L8mRHs83osRoWLu
84	payment	2	2	2	83	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZ2X2jqS2zJu7N29fYcPRj2dL7Bwn4XEyJF4js8FFvrjikpCMP7
85	payment	2	2	2	84	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpaCgbdEPd5pCqqK1kccH8VoE2YN1iDp4jhMaW5EisWk8kqquj5b
86	payment	2	2	2	85	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYTKmejVn7rpTrjAtjRNyTLqjQPyzPwMtS5bdqxQx22HNiKPnpe
87	payment	2	2	2	86	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZE4rKC38uG8pZui56h6oNkea2XqhvAyiCHcSN11q9s6Ru7ctNZ
88	payment	2	2	2	87	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYRRj7SmuDBw3TTSwRZZNRjq3m7HkNFsNyz3AbuVpjHgRNsz6e6
89	payment	2	2	2	88	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYjHeGfxbFxmY7Vp35WqazhRuXbRQjQem1o8wam75JLssVyHeaK
90	payment	2	2	2	89	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZQwNx3MrJhTnZdicRWGqWSgZirqH7L524j5EgUxHfAmawSsJvD
91	payment	2	2	2	90	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	Ckpa5xR49Wcm99d1MCh91Q1g9a42YS4PpMhaWSQbtphDTQRQehexr
92	payment	2	2	2	91	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZ3YDaJ1mYTiGi3Dgh7nKTeXdyaFGC1aX3eFL5eZpafUw43ojrg
93	payment	2	2	2	92	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZEaJNDGwQH3uag3WzsDwwX58fy1gZy2GrXwwvPWqcDQrzYWmBU
94	payment	2	2	2	93	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpaC4v6XnLfp3N8DQy8vt2TdiFQjcbh92maok3MkENoDwGk48we7
95	payment	2	2	2	94	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZwVfA4fuAc2TBUFeryXtAzqxJ4SYJA8adPcPyZBMZNAsWrcjRK
96	payment	2	2	2	95	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpaBSon4L5wRcqeeFcUNqWfS5dx7QB3Hg6np4wrDbaicB27CuKgA
97	payment	2	2	2	96	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZmmsQJ9Z5F3DFYgoh53o6nyZjuJ7KGjR2MPwZmKsTguNjrh1xr
98	payment	2	2	2	97	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYaegqfd4gs5FSu3eNdoJhCzhD1watd6bvvQuwqP3UEmsoK3Vpo
99	payment	2	2	2	98	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpaB1pVh3uBshsgREEqTCYzjhekV2qJVbCHgnLkKdeLXis6YHJqZ
100	payment	2	2	2	99	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZ8JZ5UbZXRZfLaMhrndjwZr7NWnK2GWZerVvrrPKeWHPjgFWMF
101	payment	2	2	2	100	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	Ckpa2HJL5ibQ3i9eG3VccaBA9ZwxWGiwHtrMogbhq3TkoViKEVyLv
102	payment	2	2	2	101	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZhWx8yB1YAZZFm3Mc37PKrM9kCWF6BuohLztUQaxf14kTe5MVL
103	payment	2	2	2	102	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZJF4NbSBRTcxBFwdZ7BegY6bGepWGiNe9EAFbpQ2FMxpqM8UEH
104	payment	2	2	2	103	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZqexen6swmtGyxZmMrmfAFsLJfe8GETCPzKRpfzuWYiJThiPTf
105	payment	2	2	2	104	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZE2QLyzAVG29cVsN2mLQQpysU7uZFLuDtFiRkDroGtRFV6YZkW
106	payment	2	2	2	105	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpaDad3PFnhJ2W6MYwddxdeKvhL6E4fubUPZEfiDpZQxuLYonhxJ
107	payment	2	2	2	106	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpaHRdvsajJN9aA6zYwEJi4Y5wuWgj3fJkngxVpSDLZrEaoHBjxj
108	payment	2	2	2	107	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYbbKjbAzgwbp3bTPD4AT1vQ48fJbxriePqLMA9HoxzgxmVKW8B
109	payment	2	2	2	108	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZrYCogZx8ZxkCN87JJEkuiaWELid3U4LF8GkeDcbQ1XDTrZcQb
110	payment	2	2	2	109	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	Ckpa6TVXJQfBG4i3Fwovoih1ULFAVieoYJNRpM1sjkx2ALNohT35T
111	payment	2	2	2	110	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpaD31FXFCsfZm2wcwbefq7dozwxza1mgwLJE4WSyb53oKugjiEy
112	payment	2	2	2	111	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYUcCXdmTJvwEcknw9GaUEiXP5vjBCNz9wkwJ2tGjLjs1Gg2WYS
113	payment	2	2	2	112	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYQbQTHCu2fJTtNHwR6muw9aErMvNMi7GxAFv6Gog58dfrACGpS
114	payment	2	2	2	113	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpaEwPRDP9UdbuLeihdb1Ru7EwNavnXXWZ92fLqUSKkK1hqhkgTJ
115	payment	2	2	2	114	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpaDLhaBCGyE8RmUr4PME4ppWFhCw4M9epVhjsAU5Sn19zoWSrJf
116	payment	2	2	2	115	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZaWhccPqVS78cEZ9nYTGDAEpvMQHRfz56bprKR691TEvHjx2uQ
117	payment	2	2	2	116	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZeHM8yb1CQKpNBjYHiSvJaxegYaMLLkqx6cmtj8uBmQqCaCaFJ
118	payment	2	2	2	117	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZUcu5hwteT8pB9jnjiCDwrfeWgmJxBwcC43keR3Yd2wKXYxM5M
119	payment	2	2	2	118	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZw3mmvvF35BnrGYS37hGKetNeGYQYWCmKbFXDvjpuE7sZZHrGV
120	payment	2	2	2	119	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZiuXfoBGo9xMUZUBCrnYtTHyULJFVvpTw2FHKbKYXDTwkaQNLx
121	payment	2	2	2	120	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZ16Vaxs2gPvZcc6NhNTQvG2TuW9YqPV9qaYNgJWbenuQX4HcRy
122	payment	2	2	2	121	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	Ckpa7dq2RggYUfxceT9SL8LUtDjBA1SyUgF5FujnMye7MbQZJbeZa
123	payment	2	2	2	122	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYYwtKKkHYkdPKd1SW5i9w3j3aFG1GHem7mch3YVxKpcNvDNHmB
124	payment	2	2	2	123	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZaEw8r5QUxaZ32NcvheFgFQdcmBQhApa3jisKpnK8di2dqAGys
125	payment	2	2	2	124	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZ2R7dTPhE3WBa2jMnNxB7jwrTefqL4Y9BTDk6wCWMrEn3QYm2K
126	payment	2	2	2	125	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpaJ1AsWwtApCYudhaJA8wDPoXLauSQKmyS52E7BBJMoGpNLkXqq
127	payment	2	2	2	126	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZAvnRB386ym7XiDn9ZCsbkGvjsEou1csHkegKqvbgVg53Vuuq6
128	payment	2	2	2	127	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZUfX8A3XQQW1syxyJpAVai4EAxhtc6d2vZ31xCK4Cmz6g192px
129	payment	2	2	2	128	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYt84PqpVMy1gk3pnRpbGnX4G8vVvWamWUTX7fGRC4UoTa9QU9W
130	payment	2	2	2	129	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpaKX5UoNn68bys8bExQQLCuJjww7PBTByTEYRPaxwXUHrsyUd7W
131	payment	2	2	2	130	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpaBGizm13nLYEZEKu9ivst383Z8JZd2mT12DxSurWWvk8BUjSKK
132	payment	2	2	2	131	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZ1Z4qt8XLevQ1mnxsnvoKrbGj3vJBEN87YgBUe2bETC6SsESZG
133	payment	2	2	2	132	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpaEBpds7anxB4JhG4ysLQba4H1LWdMivnW31gE9r7x3Hjmk7vun
134	payment	2	2	2	133	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYkutiohRus7snUTMQY6CL59SSneqERNdgV6sFWEZUmBbHn81Uv
135	payment	2	2	2	134	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYjYzqAKXPbUtV7aQ5P4UWPfEAbT9fPDmzS2UmCC3zt8ccaCigf
136	payment	2	2	2	135	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZahVrBWTDyjFMxNGAH6cCsXvrMFAiMiLjtxNHABUqGnEs7tWYf
137	payment	2	2	2	136	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZh9qtt11wKkXtUu7BbMhHJtbH5jD7SxcdedhLXsMDfEoTiq4jN
138	payment	2	2	2	137	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZkX5upiAopb82ugnGkSPChKF2CN8HQmbGqTWCcNRyVxsbsCVAi
139	payment	2	2	2	138	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZuDiQ4X5mZAD8LVXtC4qMNYmw4i92CwfcVAMzGCnwrdtdvSD1B
140	payment	2	2	2	139	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZeua56y1yDgSbJsdF6vcyxbeEky9gEejwY9pyupTrKiKu4aQzS
141	payment	2	2	2	140	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpaKrQVX5V2AeUYbiWr9WdcHUaMhem2yem1KJfGZb4iip66XafoQ
142	payment	2	2	2	141	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYo6ZMChW49FjkbvmsKJs25ZEBZ3Dg1vAxMuHS7VuG1kDtd15Vc
143	payment	2	2	2	142	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYSnHjaLYLHZzJ9Kq4fcb7HHiJ3NWnK4jYbWrs8aBsP7kaPed6b
144	payment	2	2	2	143	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYd41BQ5ou6J7k98jgRVndRmoEXFqrv7HTUFF6x2GZct1C6yAkU
145	payment	2	2	2	144	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZKottfn9VDjRrJmDSZgJemkmy14r5puNaJh3SXBvGkCVe1zbSR
146	payment	2	2	2	145	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZdKhArWpWVRYQ9ePcRpYH6VHETc5P56kUG6wLnrBoAMLPKt2h5
147	payment	2	2	2	146	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpaGc4gmKQNNuv6qTKBqCxTpka186oUu1AG8H6quMn1YLUn9aCTW
148	payment	2	2	2	147	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpaAyVF32g8mSXBmFHTYPkAWUs9Z8Xf7tuLDrXQXvV2AscVkBNZX
149	payment	2	2	2	148	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZDpsYNiafgYEd6GJcfEFa4gzs8TG39G8XU2rHoBbyDhBrAK3Nh
\.


--
-- Data for Name: voting_for; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.voting_for (id, value) FROM stdin;
1	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x
\.


--
-- Data for Name: zkapp_account_precondition; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.zkapp_account_precondition (id, kind, precondition_account_id, nonce) FROM stdin;
1	nonce	\N	1
2	accept	\N	\N
\.


--
-- Data for Name: zkapp_accounts; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.zkapp_accounts (id, app_state_id, verification_key_id, zkapp_version, sequence_state_id, last_sequence_slot, proved_state, zkapp_uri_id) FROM stdin;
1	2	1	0	1	0	f	1
\.


--
-- Data for Name: zkapp_amount_bounds; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.zkapp_amount_bounds (id, amount_lower_bound, amount_upper_bound) FROM stdin;
\.


--
-- Data for Name: zkapp_balance_bounds; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.zkapp_balance_bounds (id, balance_lower_bound, balance_upper_bound) FROM stdin;
\.


--
-- Data for Name: zkapp_commands; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.zkapp_commands (id, zkapp_fee_payer_body_id, zkapp_other_parties_ids, memo, hash) FROM stdin;
1	1	{1,2}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZBMeciXqFVuGDtGLHLbhMNKZukmYHoSqMWYYXUWgWxnvX6ZaMu
2	2	{3}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpaFUKBY891HvtBAfMKayPSzyCYcGiqU8Mvs3LWoKBXSBpyG6JEZ
3	3	{4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZqhmFm7hKcpfqa9yFHZbBqNzDNcXpmzyXBMwf4jkuJU9B3L7Q6
4	4	{5}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	Ckpa7B9TqdNHAtnf9UJ2Ysd1pB6xRJuhfo6UbReVj9bckzLGcKpUD
\.


--
-- Data for Name: zkapp_epoch_data; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.zkapp_epoch_data (id, epoch_ledger_id, epoch_seed, start_checkpoint, lock_checkpoint, epoch_length_id) FROM stdin;
1	1	\N	\N	\N	\N
2	2	\N	\N	\N	\N
3	3	\N	\N	\N	\N
4	4	\N	\N	\N	\N
5	5	\N	\N	\N	\N
6	6	\N	\N	\N	\N
7	7	\N	\N	\N	\N
8	8	\N	\N	\N	\N
9	9	\N	\N	\N	\N
10	10	\N	\N	\N	\N
11	11	\N	\N	\N	\N
12	12	\N	\N	\N	\N
13	13	\N	\N	\N	\N
14	14	\N	\N	\N	\N
15	15	\N	\N	\N	\N
16	16	\N	\N	\N	\N
17	17	\N	\N	\N	\N
18	18	\N	\N	\N	\N
\.


--
-- Data for Name: zkapp_epoch_ledger; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.zkapp_epoch_ledger (id, hash_id, total_currency_id) FROM stdin;
1	\N	\N
2	\N	\N
3	\N	\N
4	\N	\N
5	\N	\N
6	\N	\N
7	\N	\N
8	\N	\N
9	\N	\N
10	\N	\N
11	\N	\N
12	\N	\N
13	\N	\N
14	\N	\N
15	\N	\N
16	\N	\N
17	\N	\N
18	\N	\N
\.


--
-- Data for Name: zkapp_events; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.zkapp_events (id, element_ids) FROM stdin;
1	{}
\.


--
-- Data for Name: zkapp_fee_payer_body; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.zkapp_fee_payer_body (id, account_identifier_id, fee, valid_until, nonce) FROM stdin;
1	4	1000000000	\N	0
2	4	1000000000	\N	2
3	4	1000000000	\N	3
4	4	1000000000	\N	4
\.


--
-- Data for Name: zkapp_fee_payers; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.zkapp_fee_payers (id, body_id) FROM stdin;
1	1
2	2
3	3
4	4
\.


--
-- Data for Name: zkapp_global_slot_bounds; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.zkapp_global_slot_bounds (id, global_slot_lower_bound, global_slot_upper_bound) FROM stdin;
\.


--
-- Data for Name: zkapp_length_bounds; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.zkapp_length_bounds (id, length_lower_bound, length_upper_bound) FROM stdin;
\.


--
-- Data for Name: zkapp_nonce_bounds; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.zkapp_nonce_bounds (id, nonce_lower_bound, nonce_upper_bound) FROM stdin;
\.


--
-- Data for Name: zkapp_other_party; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.zkapp_other_party (id, body_id, authorization_kind) FROM stdin;
1	1	signature
2	2	signature
3	3	signature
4	4	signature
5	5	signature
\.


--
-- Data for Name: zkapp_other_party_body; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.zkapp_other_party_body (id, account_identifier_id, update_id, balance_change, increment_nonce, events_id, sequence_events_id, call_data_id, call_depth, zkapp_network_precondition_id, zkapp_account_precondition_id, use_full_commitment, caller) FROM stdin;
1	4	2	-12000000000	t	1	1	1	0	2	1	f	call
2	5	3	11000000000	f	1	1	1	0	3	2	t	call
3	1	5	0	f	1	1	1	0	5	2	t	call
4	1	7	0	f	1	1	1	0	7	2	t	call
5	1	9	0	f	1	1	1	0	9	2	t	call
\.


--
-- Data for Name: zkapp_party_failures; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.zkapp_party_failures (id, index, failures) FROM stdin;
\.


--
-- Data for Name: zkapp_permissions; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.zkapp_permissions (id, edit_state, send, receive, set_delegate, set_permissions, set_verification_key, set_zkapp_uri, edit_sequence_state, set_token_symbol, increment_nonce, set_voting_for) FROM stdin;
1	signature	signature	none	signature	signature	signature	signature	signature	signature	signature	signature
2	proof	signature	none	signature	signature	signature	signature	proof	signature	signature	signature
3	signature	either	either	either	either	either	either	either	either	either	either
\.


--
-- Data for Name: zkapp_precondition_accounts; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.zkapp_precondition_accounts (id, balance_id, nonce_id, receipt_chain_hash, delegate_id, state_id, sequence_state_id, proved_state) FROM stdin;
\.


--
-- Data for Name: zkapp_network_precondition; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.zkapp_network_precondition (id, snarked_ledger_hash_id, timestamp_id, blockchain_length_id, min_window_density_id, total_currency_id, curr_global_slot_since_hard_fork, global_slot_since_genesis, staking_epoch_data_id, next_epoch_data_id) FROM stdin;
1	\N	\N	\N	\N	\N	\N	\N	1	2
2	\N	\N	\N	\N	\N	\N	\N	3	4
3	\N	\N	\N	\N	\N	\N	\N	5	6
4	\N	\N	\N	\N	\N	\N	\N	7	8
5	\N	\N	\N	\N	\N	\N	\N	9	10
6	\N	\N	\N	\N	\N	\N	\N	11	12
7	\N	\N	\N	\N	\N	\N	\N	13	14
8	\N	\N	\N	\N	\N	\N	\N	15	16
9	\N	\N	\N	\N	\N	\N	\N	17	18
\.


--
-- Data for Name: zkapp_sequence_states; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.zkapp_sequence_states (id, element_ids) FROM stdin;
1	{2,2,2,2,2}
\.


--
-- Data for Name: zkapp_state_data; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.zkapp_state_data (id, field) FROM stdin;
1	0
2	19777675955122618431670853529822242067051263606115426372178827525373304476695
\.


--
-- Data for Name: zkapp_state_data_array; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.zkapp_state_data_array (id, element_ids) FROM stdin;
\.


--
-- Data for Name: zkapp_states; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.zkapp_states (id, element_ids) FROM stdin;
1	{NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL}
2	{1,1,1,1,1,1,1,1}
\.


--
-- Data for Name: zkapp_timestamp_bounds; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.zkapp_timestamp_bounds (id, timestamp_lower_bound, timestamp_upper_bound) FROM stdin;
\.


--
-- Data for Name: zkapp_timing_info; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.zkapp_timing_info (id, initial_minimum_balance, cliff_time, cliff_amount, vesting_period, vesting_increment) FROM stdin;
\.


--
-- Data for Name: zkapp_token_id_bounds; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.zkapp_token_id_bounds (id, token_id_lower_bound, token_id_upper_bound) FROM stdin;
\.


--
-- Data for Name: zkapp_updates; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.zkapp_updates (id, app_state_id, delegate_id, verification_key_id, permissions_id, zkapp_uri_id, token_symbol_id, timing_id, voting_for_id) FROM stdin;
1	1	\N	\N	\N	\N	\N	\N	\N
2	1	\N	\N	\N	\N	\N	\N	\N
3	1	\N	1	2	\N	\N	\N	\N
4	1	\N	\N	\N	\N	\N	\N	\N
5	1	\N	\N	\N	2	\N	\N	\N
6	1	\N	\N	\N	\N	\N	\N	\N
7	1	\N	\N	3	\N	\N	\N	\N
8	1	\N	\N	\N	\N	\N	\N	\N
9	1	\N	\N	\N	\N	2	\N	\N
\.


--
-- Data for Name: zkapp_verification_keys; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.zkapp_verification_keys (id, verification_key, hash) FROM stdin;
1	AgICAQICAV5C0gy60/Jxb8eD84yj9wO/qNf18WtuAiVBlwRG9+YDRsYskWdyTvVNEUiiiPvh98HZ9vjlfAAUpWZvIMDXUwSLIdlWITGL4AI+F8DJubW75ZU6VrJoIkCCw0fM9kyRLw9kTd4Y3nK/b0Ex5QTMgmhZkXnUVKTd85x2nrgGTXMg3po6nkRbiiwaXmZX2SPoiKR61ogIMxBiJAaOm1/CKTMI4OwzR8n/+iOlSZVpEz/VCT4czOhrZeaKs5iwrk3sDh/wm/uUuy/OXKZVIkSL9M0ed5mrPWvLIbc+UR1EaZIGkqPMQw62hB5yu7WrtUJMm0dGW9uJePq67hMLApYSPSyUOFg8kgrZKg3ksugSjHYuGTG3K4QJQqX18h23SO1qKTWnEYdOlQ2NAA962rr+cjRTRBdYYP59hSo3u9OAdow87cRpPVK1/R90IdxIDApug0+2m05ehueo0KDboFbhyi/UeRHXccM94ha65LJHnxfP+4blJrkH229cSRLpFDaVFBmFW0do3n/ogVTmPT4pcjkGq+YoHqAIbqJTfUVLbMkwI3o6MbEfaLoGhtujQHFUimhB3Q8PGEanmlluIlEhIAUAAYBHpvDqnmkvWKTAG7tMpSqf7LDvfvTCnTkYt0eT0q456bwscr4imCZhlMeRXIaId49CU/DcKT1kqg7EP17DKjxqrrahPnAIyOWmDpQEXuiJxOIP4/2B8zw+o9T7vVDdBIM2+RQczwsIen0HMw7h7mpdWxkEqXvnGCvCpXpUPU8WY6FjAttHAaULKArPjcFglBiUUqkYuGLQKiazoHN1BBGQg11ifY8Kv+zF/8BcV4+ATvprs6IHUzWuMpAkLvcrG6nzu1P3oqLo8b324dU9u8MItUCCGrjB6u8FMYRKv24FjFQSY0TtaK4XgivQU2raPRin7ipy/6WKrwi6MLEkhjIJi8Y6KVb2Ha9wD8szEVFmLzwlFu2dGqFD0drLrak/CEWVy6fvKDICHQ1/INscxaRO+qZilhhARXaTCWatw0YGVz6qf7MwTvDsSDPx1RzeQ0Tshu4/opAGpD34jFzILQnoCayW4kja2yho7WVqYM/opwSnm90DjKltH6zW1VVzGICLFTUJC2cgLuRMuKNzXxRPwqLgA1z+v2Hl+22SCHkMzFsxmk/cUOpVZ3Y9deqvisf4I9jKu4fpkDWK72oNTjOpBMLDVC+ZIZCf59s1wPPqkxRixujBI/4szXuoTK/tP2OkoRP84gk3pxJt3drji+psEo2nzbbvgApgEX37wOQOZCF8YR6UQMPkMWss+HxmanC60jO240JpIe1TBOUErzlVbWi5bmdvrDhMhHRmw4bzP0cDp2PemT1y//woQIeJFgVtn7N+PmTF5zbuBiDCLR3i7MX5qeCjW6+dadxvRhgjrkQTwYj5xc7DNYQIS6e+c5rwHxM7wSTeU8dWN0Dzngqfcqtp4/gQwzq+ApUkRMst6BIvKgUu8tRGC99vKzWTBMGb/5mjk90C30W9qdojJSRYQ6jlED11PX4TNcVAbwY1l9mlolvytUJw7luO7eNbc+jsdUAIs+WsPBRDsVZHhiJQux4yfH1L6MyQApfYDkuUsiB8XmLetLNV8clQc5qrMKdc0RtnLF6zCsnOyksAQ1CAbCx+whcsmwV+A4h5u3U3qp9YhkTKB4TL+VNg+jr8qW74EjCbC+Kmd6gKpYQpzwQC5zwQ0AY6e/AwtG/AYGZNNnMr5LR2Q/EtoZAJIIjpFfcRZotkFNRbRDmA1YgZ/faih0/uwifLDh0P2FKEXTMJU34qgLPH4X5sWAIVOwcrB1c6iJTuh5WmgStunL1tESNju8Kq2ovYGbZslVE75zgQg64AS7fgsaG+/jdL6BQ9NwBmbl3x/wDPkHUsi0ErGk7kSWb6RHzLWJlkVvIHVaVABcrmlsJt9xGjVEu75AQ4jVxT2XHhup53CApHCETPvVk5B7pAYKVmXA9qMMEHi7T2ldxMv7q2xRa4nKBfDB4DnQu2dPrUhTYuEGsfccnhIn8Sz0w5Hx0M57hoAaEtkPYpBbxhMPeC3lw4A1fGX6Qw7N9dSr1EmbLB60WuO0o7dCotop6Y9CiXpJAodZu/e9cXRiHaQI6KySHHhmG5jwPLlBV1IVbvTj707AYY7hrHCZB91z3Lvy9Bs/xkk3krMU3uGBKE//uFYcJLcKqa4e5YyD3PATTGtHhT+7B/7DivsFcU5olJRw3VAO+4P+OX6TFkb494ofW7o44Pw9EoCyNMhR33lJLOzzsmvKOv85C7bmu9tIbZ3WE12X31F5vlC/kBCTN6nDa0KVM65msH4tBPmOj77BA7UMbyJcccvZfNeIA+KKaCd5ZM1lBF0zYumrCqCUOt2n7ugoy5btJfdbgNTCI=	19079293979474920563146704039152670161084248765333687110610215570697279088632
\.


--
-- Name: account_identifiers_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.account_identifiers_id_seq', 5, true);


--
-- Name: blocks_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.blocks_id_seq', 5, true);


--
-- Name: epoch_data_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.epoch_data_id_seq', 6, true);


--
-- Name: internal_commands_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.internal_commands_id_seq', 5, true);


--
-- Name: public_keys_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.public_keys_id_seq', 6, true);


--
-- Name: snarked_ledger_hashes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.snarked_ledger_hashes_id_seq', 1, true);


--
-- Name: timing_info_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.timing_info_id_seq', 5, true);


--
-- Name: token_symbols_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.token_symbols_id_seq', 2, true);


--
-- Name: tokens_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.tokens_id_seq', 1, true);


--
-- Name: user_commands_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.user_commands_id_seq', 149, true);


--
-- Name: voting_for_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.voting_for_id_seq', 1, true);


--
-- Name: zkapp_account_precondition_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.zkapp_account_precondition_id_seq', 2, true);


--
-- Name: zkapp_accounts_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.zkapp_accounts_id_seq', 1, true);


--
-- Name: zkapp_amount_bounds_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.zkapp_amount_bounds_id_seq', 1, false);


--
-- Name: zkapp_balance_bounds_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.zkapp_balance_bounds_id_seq', 1, false);


--
-- Name: zkapp_commands_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.zkapp_commands_id_seq', 4, true);


--
-- Name: zkapp_epoch_data_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.zkapp_epoch_data_id_seq', 18, true);


--
-- Name: zkapp_epoch_ledger_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.zkapp_epoch_ledger_id_seq', 18, true);


--
-- Name: zkapp_events_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.zkapp_events_id_seq', 1, true);


--
-- Name: zkapp_fee_payer_body_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.zkapp_fee_payer_body_id_seq', 4, true);


--
-- Name: zkapp_fee_payers_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.zkapp_fee_payers_id_seq', 4, true);


--
-- Name: zkapp_global_slot_bounds_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.zkapp_global_slot_bounds_id_seq', 1, false);


--
-- Name: zkapp_length_bounds_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.zkapp_length_bounds_id_seq', 1, false);


--
-- Name: zkapp_nonce_bounds_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.zkapp_nonce_bounds_id_seq', 1, false);


--
-- Name: zkapp_other_party_body_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.zkapp_other_party_body_id_seq', 5, true);


--
-- Name: zkapp_other_party_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.zkapp_other_party_id_seq', 5, true);


--
-- Name: zkapp_party_failures_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.zkapp_party_failures_id_seq', 1, false);


--
-- Name: zkapp_permissions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.zkapp_permissions_id_seq', 3, true);


--
-- Name: zkapp_precondition_accounts_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.zkapp_precondition_accounts_id_seq', 1, false);


--
-- Name: zkapp_network_precondition_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.zkapp_network_precondition_id_seq', 9, true);


--
-- Name: zkapp_sequence_states_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.zkapp_sequence_states_id_seq', 1, true);


--
-- Name: zkapp_state_data_array_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.zkapp_state_data_array_id_seq', 1, false);


--
-- Name: zkapp_state_data_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.zkapp_state_data_id_seq', 2, true);


--
-- Name: zkapp_states_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.zkapp_states_id_seq', 2, true);


--
-- Name: zkapp_timestamp_bounds_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.zkapp_timestamp_bounds_id_seq', 1, false);


--
-- Name: zkapp_timing_info_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.zkapp_timing_info_id_seq', 1, false);


--
-- Name: zkapp_token_id_bounds_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.zkapp_token_id_bounds_id_seq', 1, false);


--
-- Name: zkapp_updates_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.zkapp_updates_id_seq', 9, true);


--
-- Name: zkapp_uris_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.zkapp_uris_id_seq', 2, true);


--
-- Name: zkapp_verification_keys_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.zkapp_verification_keys_id_seq', 1, true);


--
-- Name: account_identifiers account_identifiers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_identifiers
    ADD CONSTRAINT account_identifiers_pkey PRIMARY KEY (id);


--
-- Name: account_identifiers account_identifiers_public_key_id_token_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_identifiers
    ADD CONSTRAINT account_identifiers_public_key_id_token_id_key UNIQUE (public_key_id, token_id);


--
-- Name: accounts_accessed accounts_accessed_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.accounts_accessed
    ADD CONSTRAINT accounts_accessed_pkey PRIMARY KEY (block_id, account_identifier_id);


--
-- Name: accounts_created accounts_created_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.accounts_created
    ADD CONSTRAINT accounts_created_pkey PRIMARY KEY (block_id, account_identifier_id);


--
-- Name: blocks_internal_commands blocks_internal_commands_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blocks_internal_commands
    ADD CONSTRAINT blocks_internal_commands_pkey PRIMARY KEY (block_id, internal_command_id, sequence_no, secondary_sequence_no);


--
-- Name: blocks blocks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blocks
    ADD CONSTRAINT blocks_pkey PRIMARY KEY (id);


--
-- Name: blocks blocks_state_hash_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blocks
    ADD CONSTRAINT blocks_state_hash_key UNIQUE (state_hash);


--
-- Name: blocks_user_commands blocks_user_commands_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blocks_user_commands
    ADD CONSTRAINT blocks_user_commands_pkey PRIMARY KEY (block_id, user_command_id, sequence_no);


--
-- Name: blocks_zkapp_commands blocks_zkapp_commands_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blocks_zkapp_commands
    ADD CONSTRAINT blocks_zkapp_commands_pkey PRIMARY KEY (block_id, zkapp_command_id, sequence_no);


--
-- Name: epoch_data epoch_data_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.epoch_data
    ADD CONSTRAINT epoch_data_pkey PRIMARY KEY (id);


--
-- Name: internal_commands internal_commands_hash_typ_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.internal_commands
    ADD CONSTRAINT internal_commands_hash_typ_key UNIQUE (hash, typ);


--
-- Name: internal_commands internal_commands_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.internal_commands
    ADD CONSTRAINT internal_commands_pkey PRIMARY KEY (id);


--
-- Name: public_keys public_keys_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.public_keys
    ADD CONSTRAINT public_keys_pkey PRIMARY KEY (id);


--
-- Name: public_keys public_keys_value_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.public_keys
    ADD CONSTRAINT public_keys_value_key UNIQUE (value);


--
-- Name: snarked_ledger_hashes snarked_ledger_hashes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.snarked_ledger_hashes
    ADD CONSTRAINT snarked_ledger_hashes_pkey PRIMARY KEY (id);


--
-- Name: snarked_ledger_hashes snarked_ledger_hashes_value_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.snarked_ledger_hashes
    ADD CONSTRAINT snarked_ledger_hashes_value_key UNIQUE (value);


--
-- Name: timing_info timing_info_account_identifier_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.timing_info
    ADD CONSTRAINT timing_info_account_identifier_id_key UNIQUE (account_identifier_id);


--
-- Name: timing_info timing_info_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.timing_info
    ADD CONSTRAINT timing_info_pkey PRIMARY KEY (id);


--
-- Name: token_symbols token_symbols_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.token_symbols
    ADD CONSTRAINT token_symbols_pkey PRIMARY KEY (id);


--
-- Name: tokens tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tokens
    ADD CONSTRAINT tokens_pkey PRIMARY KEY (id);


--
-- Name: tokens tokens_value_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tokens
    ADD CONSTRAINT tokens_value_key UNIQUE (value);


--
-- Name: user_commands user_commands_hash_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_commands
    ADD CONSTRAINT user_commands_hash_key UNIQUE (hash);


--
-- Name: user_commands user_commands_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_commands
    ADD CONSTRAINT user_commands_pkey PRIMARY KEY (id);


--
-- Name: voting_for voting_for_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.voting_for
    ADD CONSTRAINT voting_for_pkey PRIMARY KEY (id);


--
-- Name: zkapp_account_precondition zkapp_account_precondition_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_account_precondition
    ADD CONSTRAINT zkapp_account_precondition_pkey PRIMARY KEY (id);


--
-- Name: zkapp_accounts zkapp_accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_accounts
    ADD CONSTRAINT zkapp_accounts_pkey PRIMARY KEY (id);


--
-- Name: zkapp_amount_bounds zkapp_amount_bounds_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_amount_bounds
    ADD CONSTRAINT zkapp_amount_bounds_pkey PRIMARY KEY (id);


--
-- Name: zkapp_balance_bounds zkapp_balance_bounds_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_balance_bounds
    ADD CONSTRAINT zkapp_balance_bounds_pkey PRIMARY KEY (id);


--
-- Name: zkapp_commands zkapp_commands_hash_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_commands
    ADD CONSTRAINT zkapp_commands_hash_key UNIQUE (hash);


--
-- Name: zkapp_commands zkapp_commands_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_commands
    ADD CONSTRAINT zkapp_commands_pkey PRIMARY KEY (id);


--
-- Name: zkapp_epoch_data zkapp_epoch_data_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_epoch_data
    ADD CONSTRAINT zkapp_epoch_data_pkey PRIMARY KEY (id);


--
-- Name: zkapp_epoch_ledger zkapp_epoch_ledger_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_epoch_ledger
    ADD CONSTRAINT zkapp_epoch_ledger_pkey PRIMARY KEY (id);


--
-- Name: zkapp_events zkapp_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_events
    ADD CONSTRAINT zkapp_events_pkey PRIMARY KEY (id);


--
-- Name: zkapp_fee_payer_body zkapp_fee_payer_body_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_fee_payer_body
    ADD CONSTRAINT zkapp_fee_payer_body_pkey PRIMARY KEY (id);


--
-- Name: zkapp_fee_payers zkapp_fee_payers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_fee_payers
    ADD CONSTRAINT zkapp_fee_payers_pkey PRIMARY KEY (id);


--
-- Name: zkapp_global_slot_bounds zkapp_global_slot_bounds_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_global_slot_bounds
    ADD CONSTRAINT zkapp_global_slot_bounds_pkey PRIMARY KEY (id);


--
-- Name: zkapp_length_bounds zkapp_length_bounds_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_length_bounds
    ADD CONSTRAINT zkapp_length_bounds_pkey PRIMARY KEY (id);


--
-- Name: zkapp_nonce_bounds zkapp_nonce_bounds_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_nonce_bounds
    ADD CONSTRAINT zkapp_nonce_bounds_pkey PRIMARY KEY (id);


--
-- Name: zkapp_other_party_body zkapp_other_party_body_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_other_party_body
    ADD CONSTRAINT zkapp_other_party_body_pkey PRIMARY KEY (id);


--
-- Name: zkapp_other_party zkapp_other_party_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_other_party
    ADD CONSTRAINT zkapp_other_party_pkey PRIMARY KEY (id);


--
-- Name: zkapp_party_failures zkapp_party_failures_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_party_failures
    ADD CONSTRAINT zkapp_party_failures_pkey PRIMARY KEY (id);


--
-- Name: zkapp_permissions zkapp_permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_permissions
    ADD CONSTRAINT zkapp_permissions_pkey PRIMARY KEY (id);


--
-- Name: zkapp_precondition_accounts zkapp_precondition_accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_precondition_accounts
    ADD CONSTRAINT zkapp_precondition_accounts_pkey PRIMARY KEY (id);


--
-- Name: zkapp_network_precondition zkapp_network_precondition_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_network_precondition
    ADD CONSTRAINT zkapp_network_precondition_pkey PRIMARY KEY (id);


--
-- Name: zkapp_sequence_states zkapp_sequence_states_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_sequence_states
    ADD CONSTRAINT zkapp_sequence_states_pkey PRIMARY KEY (id);


--
-- Name: zkapp_state_data_array zkapp_state_data_array_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_state_data_array
    ADD CONSTRAINT zkapp_state_data_array_pkey PRIMARY KEY (id);


--
-- Name: zkapp_state_data zkapp_state_data_field_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_state_data
    ADD CONSTRAINT zkapp_state_data_field_key UNIQUE (field);


--
-- Name: zkapp_state_data zkapp_state_data_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_state_data
    ADD CONSTRAINT zkapp_state_data_pkey PRIMARY KEY (id);


--
-- Name: zkapp_states zkapp_states_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_states
    ADD CONSTRAINT zkapp_states_pkey PRIMARY KEY (id);


--
-- Name: zkapp_timestamp_bounds zkapp_timestamp_bounds_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_timestamp_bounds
    ADD CONSTRAINT zkapp_timestamp_bounds_pkey PRIMARY KEY (id);


--
-- Name: zkapp_timing_info zkapp_timing_info_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_timing_info
    ADD CONSTRAINT zkapp_timing_info_pkey PRIMARY KEY (id);


--
-- Name: zkapp_token_id_bounds zkapp_token_id_bounds_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_token_id_bounds
    ADD CONSTRAINT zkapp_token_id_bounds_pkey PRIMARY KEY (id);


--
-- Name: zkapp_updates zkapp_updates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_updates
    ADD CONSTRAINT zkapp_updates_pkey PRIMARY KEY (id);


--
-- Name: zkapp_uris zkapp_uris_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_uris
    ADD CONSTRAINT zkapp_uris_pkey PRIMARY KEY (id);


--
-- Name: zkapp_uris zkapp_uris_value_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_uris
    ADD CONSTRAINT zkapp_uris_value_key UNIQUE (value);


--
-- Name: zkapp_verification_keys zkapp_verification_keys_hash_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_verification_keys
    ADD CONSTRAINT zkapp_verification_keys_hash_key UNIQUE (hash);


--
-- Name: zkapp_verification_keys zkapp_verification_keys_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_verification_keys
    ADD CONSTRAINT zkapp_verification_keys_pkey PRIMARY KEY (id);


--
-- Name: zkapp_verification_keys zkapp_verification_keys_verification_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_verification_keys
    ADD CONSTRAINT zkapp_verification_keys_verification_key_key UNIQUE (verification_key);


--
-- Name: idx_accounts_accessed_block_account_identifier_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_accounts_accessed_block_account_identifier_id ON public.accounts_accessed USING btree (account_identifier_id);


--
-- Name: idx_accounts_accessed_block_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_accounts_accessed_block_id ON public.accounts_accessed USING btree (block_id);


--
-- Name: idx_accounts_created_block_account_identifier_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_accounts_created_block_account_identifier_id ON public.accounts_created USING btree (account_identifier_id);


--
-- Name: idx_accounts_created_block_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_accounts_created_block_id ON public.accounts_created USING btree (block_id);


--
-- Name: idx_blocks_creator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_blocks_creator_id ON public.blocks USING btree (creator_id);


--
-- Name: idx_blocks_height; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_blocks_height ON public.blocks USING btree (height);


--
-- Name: idx_blocks_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_blocks_id ON public.blocks USING btree (id);


--
-- Name: idx_blocks_internal_commands_block_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_blocks_internal_commands_block_id ON public.blocks_internal_commands USING btree (block_id);


--
-- Name: idx_blocks_internal_commands_internal_command_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_blocks_internal_commands_internal_command_id ON public.blocks_internal_commands USING btree (internal_command_id);


--
-- Name: idx_blocks_internal_commands_secondary_sequence_no; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_blocks_internal_commands_secondary_sequence_no ON public.blocks_internal_commands USING btree (secondary_sequence_no);


--
-- Name: idx_blocks_internal_commands_sequence_no; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_blocks_internal_commands_sequence_no ON public.blocks_internal_commands USING btree (sequence_no);


--
-- Name: idx_blocks_parent_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_blocks_parent_id ON public.blocks USING btree (parent_id);


--
-- Name: idx_blocks_user_commands_block_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_blocks_user_commands_block_id ON public.blocks_user_commands USING btree (block_id);


--
-- Name: idx_blocks_user_commands_sequence_no; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_blocks_user_commands_sequence_no ON public.blocks_user_commands USING btree (sequence_no);


--
-- Name: idx_blocks_user_commands_user_command_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_blocks_user_commands_user_command_id ON public.blocks_user_commands USING btree (user_command_id);


--
-- Name: idx_blocks_zkapp_commands_block_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_blocks_zkapp_commands_block_id ON public.blocks_zkapp_commands USING btree (block_id);


--
-- Name: idx_blocks_zkapp_commands_sequence_no; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_blocks_zkapp_commands_sequence_no ON public.blocks_zkapp_commands USING btree (sequence_no);


--
-- Name: idx_blocks_zkapp_commands_zkapp_command_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_blocks_zkapp_commands_zkapp_command_id ON public.blocks_zkapp_commands USING btree (zkapp_command_id);


--
-- Name: idx_chain_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_chain_status ON public.blocks USING btree (chain_status);


--
-- Name: idx_token_symbols_value; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_token_symbols_value ON public.token_symbols USING btree (value);


--
-- Name: idx_voting_for_value; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_voting_for_value ON public.voting_for USING btree (value);


--
-- Name: account_identifiers account_identifiers_public_key_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_identifiers
    ADD CONSTRAINT account_identifiers_public_key_id_fkey FOREIGN KEY (public_key_id) REFERENCES public.public_keys(id) ON DELETE CASCADE;


--
-- Name: account_identifiers account_identifiers_token_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_identifiers
    ADD CONSTRAINT account_identifiers_token_id_fkey FOREIGN KEY (token_id) REFERENCES public.tokens(id) ON DELETE CASCADE;


--
-- Name: accounts_accessed accounts_accessed_account_identifier_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.accounts_accessed
    ADD CONSTRAINT accounts_accessed_account_identifier_id_fkey FOREIGN KEY (account_identifier_id) REFERENCES public.account_identifiers(id);


--
-- Name: accounts_accessed accounts_accessed_block_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.accounts_accessed
    ADD CONSTRAINT accounts_accessed_block_id_fkey FOREIGN KEY (block_id) REFERENCES public.blocks(id);


--
-- Name: accounts_accessed accounts_accessed_delegate_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.accounts_accessed
    ADD CONSTRAINT accounts_accessed_delegate_id_fkey FOREIGN KEY (delegate_id) REFERENCES public.public_keys(id);


--
-- Name: accounts_accessed accounts_accessed_permissions_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.accounts_accessed
    ADD CONSTRAINT accounts_accessed_permissions_id_fkey FOREIGN KEY (permissions_id) REFERENCES public.zkapp_permissions(id);


--
-- Name: accounts_accessed accounts_accessed_timing_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.accounts_accessed
    ADD CONSTRAINT accounts_accessed_timing_id_fkey FOREIGN KEY (timing_id) REFERENCES public.timing_info(id);


--
-- Name: accounts_accessed accounts_accessed_token_symbol_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.accounts_accessed
    ADD CONSTRAINT accounts_accessed_token_symbol_id_fkey FOREIGN KEY (token_symbol_id) REFERENCES public.token_symbols(id);


--
-- Name: accounts_accessed accounts_accessed_voting_for_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.accounts_accessed
    ADD CONSTRAINT accounts_accessed_voting_for_id_fkey FOREIGN KEY (voting_for_id) REFERENCES public.voting_for(id);


--
-- Name: accounts_accessed accounts_accessed_zkapp_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.accounts_accessed
    ADD CONSTRAINT accounts_accessed_zkapp_id_fkey FOREIGN KEY (zkapp_id) REFERENCES public.zkapp_accounts(id);


--
-- Name: accounts_created accounts_created_account_identifier_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.accounts_created
    ADD CONSTRAINT accounts_created_account_identifier_id_fkey FOREIGN KEY (account_identifier_id) REFERENCES public.account_identifiers(id);


--
-- Name: accounts_created accounts_created_block_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.accounts_created
    ADD CONSTRAINT accounts_created_block_id_fkey FOREIGN KEY (block_id) REFERENCES public.blocks(id);


--
-- Name: blocks blocks_block_winner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blocks
    ADD CONSTRAINT blocks_block_winner_id_fkey FOREIGN KEY (block_winner_id) REFERENCES public.public_keys(id);


--
-- Name: blocks blocks_creator_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blocks
    ADD CONSTRAINT blocks_creator_id_fkey FOREIGN KEY (creator_id) REFERENCES public.public_keys(id);


--
-- Name: blocks_internal_commands blocks_internal_commands_block_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blocks_internal_commands
    ADD CONSTRAINT blocks_internal_commands_block_id_fkey FOREIGN KEY (block_id) REFERENCES public.blocks(id) ON DELETE CASCADE;


--
-- Name: blocks_internal_commands blocks_internal_commands_internal_command_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blocks_internal_commands
    ADD CONSTRAINT blocks_internal_commands_internal_command_id_fkey FOREIGN KEY (internal_command_id) REFERENCES public.internal_commands(id) ON DELETE CASCADE;


--
-- Name: blocks blocks_next_epoch_data_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blocks
    ADD CONSTRAINT blocks_next_epoch_data_id_fkey FOREIGN KEY (next_epoch_data_id) REFERENCES public.epoch_data(id);


--
-- Name: blocks blocks_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blocks
    ADD CONSTRAINT blocks_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.blocks(id);


--
-- Name: blocks blocks_snarked_ledger_hash_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blocks
    ADD CONSTRAINT blocks_snarked_ledger_hash_id_fkey FOREIGN KEY (snarked_ledger_hash_id) REFERENCES public.snarked_ledger_hashes(id);


--
-- Name: blocks blocks_staking_epoch_data_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blocks
    ADD CONSTRAINT blocks_staking_epoch_data_id_fkey FOREIGN KEY (staking_epoch_data_id) REFERENCES public.epoch_data(id);


--
-- Name: blocks_user_commands blocks_user_commands_block_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blocks_user_commands
    ADD CONSTRAINT blocks_user_commands_block_id_fkey FOREIGN KEY (block_id) REFERENCES public.blocks(id) ON DELETE CASCADE;


--
-- Name: blocks_user_commands blocks_user_commands_user_command_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blocks_user_commands
    ADD CONSTRAINT blocks_user_commands_user_command_id_fkey FOREIGN KEY (user_command_id) REFERENCES public.user_commands(id) ON DELETE CASCADE;


--
-- Name: blocks_zkapp_commands blocks_zkapp_commands_block_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blocks_zkapp_commands
    ADD CONSTRAINT blocks_zkapp_commands_block_id_fkey FOREIGN KEY (block_id) REFERENCES public.blocks(id) ON DELETE CASCADE;


--
-- Name: blocks_zkapp_commands blocks_zkapp_commands_zkapp_command_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blocks_zkapp_commands
    ADD CONSTRAINT blocks_zkapp_commands_zkapp_command_id_fkey FOREIGN KEY (zkapp_command_id) REFERENCES public.zkapp_commands(id) ON DELETE CASCADE;


--
-- Name: epoch_data epoch_data_ledger_hash_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.epoch_data
    ADD CONSTRAINT epoch_data_ledger_hash_id_fkey FOREIGN KEY (ledger_hash_id) REFERENCES public.snarked_ledger_hashes(id);


--
-- Name: internal_commands internal_commands_receiver_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.internal_commands
    ADD CONSTRAINT internal_commands_receiver_id_fkey FOREIGN KEY (receiver_id) REFERENCES public.account_identifiers(id);


--
-- Name: timing_info timing_info_account_identifier_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.timing_info
    ADD CONSTRAINT timing_info_account_identifier_id_fkey FOREIGN KEY (account_identifier_id) REFERENCES public.account_identifiers(id);


--
-- Name: tokens tokens_owner_public_key_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tokens
    ADD CONSTRAINT tokens_owner_public_key_id_fkey FOREIGN KEY (owner_public_key_id) REFERENCES public.public_keys(id) ON DELETE CASCADE;


--
-- Name: tokens tokens_owner_token_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tokens
    ADD CONSTRAINT tokens_owner_token_id_fkey FOREIGN KEY (owner_token_id) REFERENCES public.tokens(id);


--
-- Name: user_commands user_commands_fee_payer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_commands
    ADD CONSTRAINT user_commands_fee_payer_id_fkey FOREIGN KEY (fee_payer_id) REFERENCES public.account_identifiers(id);


--
-- Name: user_commands user_commands_receiver_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_commands
    ADD CONSTRAINT user_commands_receiver_id_fkey FOREIGN KEY (receiver_id) REFERENCES public.account_identifiers(id);


--
-- Name: user_commands user_commands_source_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_commands
    ADD CONSTRAINT user_commands_source_id_fkey FOREIGN KEY (source_id) REFERENCES public.account_identifiers(id);


--
-- Name: zkapp_account_precondition zkapp_account_precondition_precondition_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_account_precondition
    ADD CONSTRAINT zkapp_account_precondition_precondition_account_id_fkey FOREIGN KEY (precondition_account_id) REFERENCES public.zkapp_precondition_accounts(id);


--
-- Name: zkapp_accounts zkapp_accounts_app_state_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_accounts
    ADD CONSTRAINT zkapp_accounts_app_state_id_fkey FOREIGN KEY (app_state_id) REFERENCES public.zkapp_states(id);


--
-- Name: zkapp_accounts zkapp_accounts_sequence_state_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_accounts
    ADD CONSTRAINT zkapp_accounts_sequence_state_id_fkey FOREIGN KEY (sequence_state_id) REFERENCES public.zkapp_sequence_states(id);


--
-- Name: zkapp_accounts zkapp_accounts_verification_key_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_accounts
    ADD CONSTRAINT zkapp_accounts_verification_key_id_fkey FOREIGN KEY (verification_key_id) REFERENCES public.zkapp_verification_keys(id);


--
-- Name: zkapp_accounts zkapp_accounts_zkapp_uri_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_accounts
    ADD CONSTRAINT zkapp_accounts_zkapp_uri_id_fkey FOREIGN KEY (zkapp_uri_id) REFERENCES public.zkapp_uris(id);


--
-- Name: zkapp_commands zkapp_commands_zkapp_fee_payer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_commands
    ADD CONSTRAINT zkapp_commands_zkapp_fee_payer_id_fkey FOREIGN KEY (zkapp_fee_payer_body_id) REFERENCES public.zkapp_fee_payers(id);


--
-- Name: zkapp_epoch_data zkapp_epoch_data_epoch_ledger_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_epoch_data
    ADD CONSTRAINT zkapp_epoch_data_epoch_ledger_id_fkey FOREIGN KEY (epoch_ledger_id) REFERENCES public.zkapp_epoch_ledger(id);


--
-- Name: zkapp_epoch_data zkapp_epoch_data_epoch_length_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_epoch_data
    ADD CONSTRAINT zkapp_epoch_data_epoch_length_id_fkey FOREIGN KEY (epoch_length_id) REFERENCES public.zkapp_length_bounds(id);


--
-- Name: zkapp_epoch_ledger zkapp_epoch_ledger_hash_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_epoch_ledger
    ADD CONSTRAINT zkapp_epoch_ledger_hash_id_fkey FOREIGN KEY (hash_id) REFERENCES public.snarked_ledger_hashes(id);


--
-- Name: zkapp_epoch_ledger zkapp_epoch_ledger_total_currency_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_epoch_ledger
    ADD CONSTRAINT zkapp_epoch_ledger_total_currency_id_fkey FOREIGN KEY (total_currency_id) REFERENCES public.zkapp_amount_bounds(id);


--
-- Name: zkapp_fee_payer_body zkapp_fee_payer_body_account_identifier_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_fee_payer_body
    ADD CONSTRAINT zkapp_fee_payer_body_account_identifier_id_fkey FOREIGN KEY (account_identifier_id) REFERENCES public.account_identifiers(id);


--
-- Name: zkapp_fee_payers zkapp_fee_payers_body_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_fee_payers
    ADD CONSTRAINT zkapp_fee_payers_body_id_fkey FOREIGN KEY (body_id) REFERENCES public.zkapp_fee_payer_body(id);


--
-- Name: zkapp_other_party_body zkapp_other_party_body_account_identifier_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_other_party_body
    ADD CONSTRAINT zkapp_other_party_body_account_identifier_id_fkey FOREIGN KEY (account_identifier_id) REFERENCES public.account_identifiers(id);


--
-- Name: zkapp_other_party_body zkapp_other_party_body_call_data_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_other_party_body
    ADD CONSTRAINT zkapp_other_party_body_call_data_id_fkey FOREIGN KEY (call_data_id) REFERENCES public.zkapp_state_data(id);


--
-- Name: zkapp_other_party_body zkapp_other_party_body_events_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_other_party_body
    ADD CONSTRAINT zkapp_other_party_body_events_id_fkey FOREIGN KEY (events_id) REFERENCES public.zkapp_events(id);


--
-- Name: zkapp_other_party zkapp_other_party_body_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_other_party
    ADD CONSTRAINT zkapp_other_party_body_id_fkey FOREIGN KEY (body_id) REFERENCES public.zkapp_other_party_body(id);


--
-- Name: zkapp_other_party_body zkapp_other_party_body_sequence_events_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_other_party_body
    ADD CONSTRAINT zkapp_other_party_body_sequence_events_id_fkey FOREIGN KEY (sequence_events_id) REFERENCES public.zkapp_events(id);


--
-- Name: zkapp_other_party_body zkapp_other_party_body_update_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_other_party_body
    ADD CONSTRAINT zkapp_other_party_body_update_id_fkey FOREIGN KEY (update_id) REFERENCES public.zkapp_updates(id);


--
-- Name: zkapp_other_party_body zkapp_other_party_body_zkapp_account_precondition_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_other_party_body
    ADD CONSTRAINT zkapp_other_party_body_zkapp_account_precondition_id_fkey FOREIGN KEY (zkapp_account_precondition_id) REFERENCES public.zkapp_account_precondition(id);


--
-- Name: zkapp_other_party_body zkapp_other_party_body_zkapp_network_precondition_i_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_other_party_body
    ADD CONSTRAINT zkapp_other_party_body_zkapp_network_precondition_i_fkey FOREIGN KEY (zkapp_network_precondition_id) REFERENCES public.zkapp_network_precondition(id);


--
-- Name: zkapp_precondition_accounts zkapp_precondition_accounts_balance_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_precondition_accounts
    ADD CONSTRAINT zkapp_precondition_accounts_balance_id_fkey FOREIGN KEY (balance_id) REFERENCES public.zkapp_balance_bounds(id);


--
-- Name: zkapp_precondition_accounts zkapp_precondition_accounts_delegate_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_precondition_accounts
    ADD CONSTRAINT zkapp_precondition_accounts_delegate_id_fkey FOREIGN KEY (delegate_id) REFERENCES public.public_keys(id);


--
-- Name: zkapp_precondition_accounts zkapp_precondition_accounts_nonce_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_precondition_accounts
    ADD CONSTRAINT zkapp_precondition_accounts_nonce_id_fkey FOREIGN KEY (nonce_id) REFERENCES public.zkapp_nonce_bounds(id);


--
-- Name: zkapp_precondition_accounts zkapp_precondition_accounts_sequence_state_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_precondition_accounts
    ADD CONSTRAINT zkapp_precondition_accounts_sequence_state_id_fkey FOREIGN KEY (sequence_state_id) REFERENCES public.zkapp_state_data(id);


--
-- Name: zkapp_precondition_accounts zkapp_precondition_accounts_state_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_precondition_accounts
    ADD CONSTRAINT zkapp_precondition_accounts_state_id_fkey FOREIGN KEY (state_id) REFERENCES public.zkapp_states(id);


--
-- Name: zkapp_network_precondition zkapp_protocol_state_precondi_curr_global_slot_since_hard__fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_network_precondition
    ADD CONSTRAINT zkapp_protocol_state_precondi_curr_global_slot_since_hard__fkey FOREIGN KEY (curr_global_slot_since_hard_fork) REFERENCES public.zkapp_global_slot_bounds(id);


--
-- Name: zkapp_network_precondition zkapp_protocol_state_preconditio_global_slot_since_genesis_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_network_precondition
    ADD CONSTRAINT zkapp_protocol_state_preconditio_global_slot_since_genesis_fkey FOREIGN KEY (global_slot_since_genesis) REFERENCES public.zkapp_global_slot_bounds(id);


--
-- Name: zkapp_network_precondition zkapp_network_precondition_blockchain_length_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_network_precondition
    ADD CONSTRAINT zkapp_network_precondition_blockchain_length_id_fkey FOREIGN KEY (blockchain_length_id) REFERENCES public.zkapp_length_bounds(id);


--
-- Name: zkapp_network_precondition zkapp_network_precondition_min_window_density_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_network_precondition
    ADD CONSTRAINT zkapp_network_precondition_min_window_density_id_fkey FOREIGN KEY (min_window_density_id) REFERENCES public.zkapp_length_bounds(id);


--
-- Name: zkapp_network_precondition zkapp_network_precondition_next_epoch_data_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_network_precondition
    ADD CONSTRAINT zkapp_network_precondition_next_epoch_data_id_fkey FOREIGN KEY (next_epoch_data_id) REFERENCES public.zkapp_epoch_data(id);


--
-- Name: zkapp_network_precondition zkapp_network_precondition_snarked_ledger_hash_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_network_precondition
    ADD CONSTRAINT zkapp_network_precondition_snarked_ledger_hash_id_fkey FOREIGN KEY (snarked_ledger_hash_id) REFERENCES public.snarked_ledger_hashes(id);


--
-- Name: zkapp_network_precondition zkapp_network_precondition_staking_epoch_data_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_network_precondition
    ADD CONSTRAINT zkapp_network_precondition_staking_epoch_data_id_fkey FOREIGN KEY (staking_epoch_data_id) REFERENCES public.zkapp_epoch_data(id);


--
-- Name: zkapp_network_precondition zkapp_network_precondition_timestamp_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_network_precondition
    ADD CONSTRAINT zkapp_network_precondition_timestamp_id_fkey FOREIGN KEY (timestamp_id) REFERENCES public.zkapp_timestamp_bounds(id);


--
-- Name: zkapp_network_precondition zkapp_network_precondition_total_currency_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_network_precondition
    ADD CONSTRAINT zkapp_network_precondition_total_currency_id_fkey FOREIGN KEY (total_currency_id) REFERENCES public.zkapp_amount_bounds(id);


--
-- Name: zkapp_updates zkapp_updates_app_state_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_updates
    ADD CONSTRAINT zkapp_updates_app_state_id_fkey FOREIGN KEY (app_state_id) REFERENCES public.zkapp_states(id);


--
-- Name: zkapp_updates zkapp_updates_delegate_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_updates
    ADD CONSTRAINT zkapp_updates_delegate_id_fkey FOREIGN KEY (delegate_id) REFERENCES public.public_keys(id);


--
-- Name: zkapp_updates zkapp_updates_permissions_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_updates
    ADD CONSTRAINT zkapp_updates_permissions_id_fkey FOREIGN KEY (permissions_id) REFERENCES public.zkapp_permissions(id);


--
-- Name: zkapp_updates zkapp_updates_timing_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_updates
    ADD CONSTRAINT zkapp_updates_timing_id_fkey FOREIGN KEY (timing_id) REFERENCES public.zkapp_timing_info(id);


--
-- Name: zkapp_updates zkapp_updates_token_symbol_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_updates
    ADD CONSTRAINT zkapp_updates_token_symbol_id_fkey FOREIGN KEY (token_symbol_id) REFERENCES public.token_symbols(id);


--
-- Name: zkapp_updates zkapp_updates_verification_key_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_updates
    ADD CONSTRAINT zkapp_updates_verification_key_id_fkey FOREIGN KEY (verification_key_id) REFERENCES public.zkapp_verification_keys(id);


--
-- Name: zkapp_updates zkapp_updates_voting_for_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_updates
    ADD CONSTRAINT zkapp_updates_voting_for_id_fkey FOREIGN KEY (voting_for_id) REFERENCES public.voting_for(id);


--
-- Name: zkapp_updates zkapp_updates_zkapp_uri_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zkapp_updates
    ADD CONSTRAINT zkapp_updates_zkapp_uri_id_fkey FOREIGN KEY (zkapp_uri_id) REFERENCES public.zkapp_uris(id);


--
-- PostgreSQL database dump complete
--

