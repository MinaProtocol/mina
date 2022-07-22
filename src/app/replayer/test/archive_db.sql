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
-- Name: archiver; Type: DATABASE; Schema: -; Owner: o1labs
--

CREATE DATABASE archiver WITH TEMPLATE = template0 ENCODING = 'UTF8'  LC_COLLATE = 'en_US.UTF-8' LC_CTYPE = 'en_US.UTF-8';

\connect archiver

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
-- Name: call_type_type; Type: TYPE; Schema: public; Owner: o1labs
--

CREATE TYPE public.call_type_type AS ENUM (
    'call',
    'delegate_call'
);

--
-- Name: chain_status_type; Type: TYPE; Schema: public; Owner: o1labs
--

CREATE TYPE public.chain_status_type AS ENUM (
    'canonical',
    'orphaned',
    'pending'
);

--
-- Name: internal_command_type; Type: TYPE; Schema: public; Owner: o1labs
--

CREATE TYPE public.internal_command_type AS ENUM (
    'fee_transfer_via_coinbase',
    'fee_transfer',
    'coinbase'
);

--
-- Name: transaction_status; Type: TYPE; Schema: public; Owner: o1labs
--

CREATE TYPE public.transaction_status AS ENUM (
    'applied',
    'failed'
);

--
-- Name: user_command_type; Type: TYPE; Schema: public; Owner: o1labs
--

CREATE TYPE public.user_command_type AS ENUM (
    'payment',
    'delegation'
);

--
-- Name: zkapp_auth_required_type; Type: TYPE; Schema: public; Owner: o1labs
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
-- Name: zkapp_authorization_kind_type; Type: TYPE; Schema: public; Owner: o1labs
--

CREATE TYPE public.zkapp_authorization_kind_type AS ENUM (
    'proof',
    'signature',
    'none_given'
);

--
-- Name: zkapp_precondition_type; Type: TYPE; Schema: public; Owner: o1labs
--

CREATE TYPE public.zkapp_precondition_type AS ENUM (
    'full',
    'nonce',
    'accept'
);


SET default_tablespace = '';

--
-- Name: account_identifiers; Type: TABLE; Schema: public; Owner: o1labs
--

CREATE TABLE public.account_identifiers (
    id integer NOT NULL,
    public_key_id integer NOT NULL,
    token_id integer NOT NULL
);

--
-- Name: account_identifiers_id_seq; Type: SEQUENCE; Schema: public; Owner: o1labs
--

CREATE SEQUENCE public.account_identifiers_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: account_identifiers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: o1labs
--

ALTER SEQUENCE public.account_identifiers_id_seq OWNED BY public.account_identifiers.id;


--
-- Name: accounts_accessed; Type: TABLE; Schema: public; Owner: o1labs
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
-- Name: accounts_created; Type: TABLE; Schema: public; Owner: o1labs
--

CREATE TABLE public.accounts_created (
    block_id integer NOT NULL,
    account_identifier_id integer NOT NULL,
    creation_fee text NOT NULL
);

--
-- Name: blocks; Type: TABLE; Schema: public; Owner: o1labs
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
-- Name: blocks_id_seq; Type: SEQUENCE; Schema: public; Owner: o1labs
--

CREATE SEQUENCE public.blocks_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: blocks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: o1labs
--

ALTER SEQUENCE public.blocks_id_seq OWNED BY public.blocks.id;


--
-- Name: blocks_internal_commands; Type: TABLE; Schema: public; Owner: o1labs
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
-- Name: blocks_user_commands; Type: TABLE; Schema: public; Owner: o1labs
--

CREATE TABLE public.blocks_user_commands (
    block_id integer NOT NULL,
    user_command_id integer NOT NULL,
    sequence_no integer NOT NULL,
    status public.transaction_status NOT NULL,
    failure_reason text
);


--
-- Name: blocks_zkapp_commands; Type: TABLE; Schema: public; Owner: o1labs
--

CREATE TABLE public.blocks_zkapp_commands (
    block_id integer NOT NULL,
    zkapp_command_id integer NOT NULL,
    sequence_no integer NOT NULL,
    status public.transaction_status NOT NULL,
    failure_reasons_ids integer[]
);

--
-- Name: epoch_data; Type: TABLE; Schema: public; Owner: o1labs
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
-- Name: epoch_data_id_seq; Type: SEQUENCE; Schema: public; Owner: o1labs
--

CREATE SEQUENCE public.epoch_data_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: epoch_data_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: o1labs
--

ALTER SEQUENCE public.epoch_data_id_seq OWNED BY public.epoch_data.id;


--
-- Name: internal_commands; Type: TABLE; Schema: public; Owner: o1labs
--

CREATE TABLE public.internal_commands (
    id integer NOT NULL,
    typ public.internal_command_type NOT NULL,
    receiver_id integer NOT NULL,
    fee text NOT NULL,
    hash text NOT NULL
);

--
-- Name: internal_commands_id_seq; Type: SEQUENCE; Schema: public; Owner: o1labs
--

CREATE SEQUENCE public.internal_commands_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: internal_commands_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: o1labs
--

ALTER SEQUENCE public.internal_commands_id_seq OWNED BY public.internal_commands.id;


--
-- Name: public_keys; Type: TABLE; Schema: public; Owner: o1labs
--

CREATE TABLE public.public_keys (
    id integer NOT NULL,
    value text NOT NULL
);

--
-- Name: public_keys_id_seq; Type: SEQUENCE; Schema: public; Owner: o1labs
--

CREATE SEQUENCE public.public_keys_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: public_keys_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: o1labs
--

ALTER SEQUENCE public.public_keys_id_seq OWNED BY public.public_keys.id;


--
-- Name: snarked_ledger_hashes; Type: TABLE; Schema: public; Owner: o1labs
--

CREATE TABLE public.snarked_ledger_hashes (
    id integer NOT NULL,
    value text NOT NULL
);


 

--
-- Name: snarked_ledger_hashes_id_seq; Type: SEQUENCE; Schema: public; Owner: o1labs
--

CREATE SEQUENCE public.snarked_ledger_hashes_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


 

--
-- Name: snarked_ledger_hashes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: o1labs
--

ALTER SEQUENCE public.snarked_ledger_hashes_id_seq OWNED BY public.snarked_ledger_hashes.id;


--
-- Name: timing_info; Type: TABLE; Schema: public; Owner: o1labs
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
-- Name: timing_info_id_seq; Type: SEQUENCE; Schema: public; Owner: o1labs
--

CREATE SEQUENCE public.timing_info_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


 

--
-- Name: timing_info_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: o1labs
--

ALTER SEQUENCE public.timing_info_id_seq OWNED BY public.timing_info.id;


--
-- Name: token_symbols; Type: TABLE; Schema: public; Owner: o1labs
--

CREATE TABLE public.token_symbols (
    id integer NOT NULL,
    value text NOT NULL
);


 

--
-- Name: token_symbols_id_seq; Type: SEQUENCE; Schema: public; Owner: o1labs
--

CREATE SEQUENCE public.token_symbols_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


 

--
-- Name: token_symbols_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: o1labs
--

ALTER SEQUENCE public.token_symbols_id_seq OWNED BY public.token_symbols.id;


--
-- Name: tokens; Type: TABLE; Schema: public; Owner: o1labs
--

CREATE TABLE public.tokens (
    id integer NOT NULL,
    value text NOT NULL,
    owner_public_key_id integer,
    owner_token_id integer
);


 

--
-- Name: tokens_id_seq; Type: SEQUENCE; Schema: public; Owner: o1labs
--

CREATE SEQUENCE public.tokens_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


 

--
-- Name: tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: o1labs
--

ALTER SEQUENCE public.tokens_id_seq OWNED BY public.tokens.id;


--
-- Name: user_commands; Type: TABLE; Schema: public; Owner: o1labs
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
-- Name: user_commands_id_seq; Type: SEQUENCE; Schema: public; Owner: o1labs
--

CREATE SEQUENCE public.user_commands_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


 

--
-- Name: user_commands_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: o1labs
--

ALTER SEQUENCE public.user_commands_id_seq OWNED BY public.user_commands.id;


--
-- Name: voting_for; Type: TABLE; Schema: public; Owner: o1labs
--

CREATE TABLE public.voting_for (
    id integer NOT NULL,
    value text NOT NULL
);


 

--
-- Name: voting_for_id_seq; Type: SEQUENCE; Schema: public; Owner: o1labs
--

CREATE SEQUENCE public.voting_for_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


 

--
-- Name: voting_for_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: o1labs
--

ALTER SEQUENCE public.voting_for_id_seq OWNED BY public.voting_for.id;


--
-- Name: zkapp_account_precondition; Type: TABLE; Schema: public; Owner: o1labs
--

CREATE TABLE public.zkapp_account_precondition (
    id integer NOT NULL,
    kind public.zkapp_precondition_type NOT NULL,
    precondition_account_id integer,
    nonce bigint
);


 

--
-- Name: zkapp_account_precondition_id_seq; Type: SEQUENCE; Schema: public; Owner: o1labs
--

CREATE SEQUENCE public.zkapp_account_precondition_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


 

--
-- Name: zkapp_account_precondition_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: o1labs
--

ALTER SEQUENCE public.zkapp_account_precondition_id_seq OWNED BY public.zkapp_account_precondition.id;


--
-- Name: zkapp_accounts; Type: TABLE; Schema: public; Owner: o1labs
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
-- Name: zkapp_accounts_id_seq; Type: SEQUENCE; Schema: public; Owner: o1labs
--

CREATE SEQUENCE public.zkapp_accounts_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


 

--
-- Name: zkapp_accounts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: o1labs
--

ALTER SEQUENCE public.zkapp_accounts_id_seq OWNED BY public.zkapp_accounts.id;


--
-- Name: zkapp_amount_bounds; Type: TABLE; Schema: public; Owner: o1labs
--

CREATE TABLE public.zkapp_amount_bounds (
    id integer NOT NULL,
    amount_lower_bound text NOT NULL,
    amount_upper_bound text NOT NULL
);


 

--
-- Name: zkapp_amount_bounds_id_seq; Type: SEQUENCE; Schema: public; Owner: o1labs
--

CREATE SEQUENCE public.zkapp_amount_bounds_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


 

--
-- Name: zkapp_amount_bounds_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: o1labs
--

ALTER SEQUENCE public.zkapp_amount_bounds_id_seq OWNED BY public.zkapp_amount_bounds.id;


--
-- Name: zkapp_balance_bounds; Type: TABLE; Schema: public; Owner: o1labs
--

CREATE TABLE public.zkapp_balance_bounds (
    id integer NOT NULL,
    balance_lower_bound text NOT NULL,
    balance_upper_bound text NOT NULL
);


 

--
-- Name: zkapp_balance_bounds_id_seq; Type: SEQUENCE; Schema: public; Owner: o1labs
--

CREATE SEQUENCE public.zkapp_balance_bounds_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


 

--
-- Name: zkapp_balance_bounds_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: o1labs
--

ALTER SEQUENCE public.zkapp_balance_bounds_id_seq OWNED BY public.zkapp_balance_bounds.id;


--
-- Name: zkapp_commands; Type: TABLE; Schema: public; Owner: o1labs
--

CREATE TABLE public.zkapp_commands (
    id integer NOT NULL,
    zkapp_fee_payer_body_id integer NOT NULL,
    zkapp_other_parties_ids integer[] NOT NULL,
    memo text NOT NULL,
    hash text NOT NULL
);


 

--
-- Name: zkapp_commands_id_seq; Type: SEQUENCE; Schema: public; Owner: o1labs
--

CREATE SEQUENCE public.zkapp_commands_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


 

--
-- Name: zkapp_commands_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: o1labs
--

ALTER SEQUENCE public.zkapp_commands_id_seq OWNED BY public.zkapp_commands.id;


--
-- Name: zkapp_epoch_data; Type: TABLE; Schema: public; Owner: o1labs
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
-- Name: zkapp_epoch_data_id_seq; Type: SEQUENCE; Schema: public; Owner: o1labs
--

CREATE SEQUENCE public.zkapp_epoch_data_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


 

--
-- Name: zkapp_epoch_data_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: o1labs
--

ALTER SEQUENCE public.zkapp_epoch_data_id_seq OWNED BY public.zkapp_epoch_data.id;


--
-- Name: zkapp_epoch_ledger; Type: TABLE; Schema: public; Owner: o1labs
--

CREATE TABLE public.zkapp_epoch_ledger (
    id integer NOT NULL,
    hash_id integer,
    total_currency_id integer
);


 

--
-- Name: zkapp_epoch_ledger_id_seq; Type: SEQUENCE; Schema: public; Owner: o1labs
--

CREATE SEQUENCE public.zkapp_epoch_ledger_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


 

--
-- Name: zkapp_epoch_ledger_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: o1labs
--

ALTER SEQUENCE public.zkapp_epoch_ledger_id_seq OWNED BY public.zkapp_epoch_ledger.id;


--
-- Name: zkapp_events; Type: TABLE; Schema: public; Owner: o1labs
--

CREATE TABLE public.zkapp_events (
    id integer NOT NULL,
    element_ids integer[] NOT NULL
);


 

--
-- Name: zkapp_events_id_seq; Type: SEQUENCE; Schema: public; Owner: o1labs
--

CREATE SEQUENCE public.zkapp_events_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


 

--
-- Name: zkapp_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: o1labs
--

ALTER SEQUENCE public.zkapp_events_id_seq OWNED BY public.zkapp_events.id;


--
-- Name: zkapp_fee_payer_body; Type: TABLE; Schema: public; Owner: o1labs
--

CREATE TABLE public.zkapp_fee_payer_body (
    id integer NOT NULL,
    account_identifier_id integer NOT NULL,
    fee text NOT NULL,
    valid_until bigint,
    nonce bigint NOT NULL
);


 

--
-- Name: zkapp_fee_payer_body_id_seq; Type: SEQUENCE; Schema: public; Owner: o1labs
--

CREATE SEQUENCE public.zkapp_fee_payer_body_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


 

--
-- Name: zkapp_fee_payer_body_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: o1labs
--

ALTER SEQUENCE public.zkapp_fee_payer_body_id_seq OWNED BY public.zkapp_fee_payer_body.id;


--
-- Name: zkapp_global_slot_bounds; Type: TABLE; Schema: public; Owner: o1labs
--

CREATE TABLE public.zkapp_global_slot_bounds (
    id integer NOT NULL,
    global_slot_lower_bound bigint NOT NULL,
    global_slot_upper_bound bigint NOT NULL
);


 

--
-- Name: zkapp_global_slot_bounds_id_seq; Type: SEQUENCE; Schema: public; Owner: o1labs
--

CREATE SEQUENCE public.zkapp_global_slot_bounds_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


 

--
-- Name: zkapp_global_slot_bounds_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: o1labs
--

ALTER SEQUENCE public.zkapp_global_slot_bounds_id_seq OWNED BY public.zkapp_global_slot_bounds.id;


--
-- Name: zkapp_length_bounds; Type: TABLE; Schema: public; Owner: o1labs
--

CREATE TABLE public.zkapp_length_bounds (
    id integer NOT NULL,
    length_lower_bound bigint NOT NULL,
    length_upper_bound bigint NOT NULL
);


 

--
-- Name: zkapp_length_bounds_id_seq; Type: SEQUENCE; Schema: public; Owner: o1labs
--

CREATE SEQUENCE public.zkapp_length_bounds_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


 

--
-- Name: zkapp_length_bounds_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: o1labs
--

ALTER SEQUENCE public.zkapp_length_bounds_id_seq OWNED BY public.zkapp_length_bounds.id;


--
-- Name: zkapp_network_precondition; Type: TABLE; Schema: public; Owner: o1labs
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
-- Name: zkapp_network_precondition_id_seq; Type: SEQUENCE; Schema: public; Owner: o1labs
--

CREATE SEQUENCE public.zkapp_network_precondition_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


 

--
-- Name: zkapp_network_precondition_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: o1labs
--

ALTER SEQUENCE public.zkapp_network_precondition_id_seq OWNED BY public.zkapp_network_precondition.id;


--
-- Name: zkapp_nonce_bounds; Type: TABLE; Schema: public; Owner: o1labs
--

CREATE TABLE public.zkapp_nonce_bounds (
    id integer NOT NULL,
    nonce_lower_bound bigint NOT NULL,
    nonce_upper_bound bigint NOT NULL
);


 

--
-- Name: zkapp_nonce_bounds_id_seq; Type: SEQUENCE; Schema: public; Owner: o1labs
--

CREATE SEQUENCE public.zkapp_nonce_bounds_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


 

--
-- Name: zkapp_nonce_bounds_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: o1labs
--

ALTER SEQUENCE public.zkapp_nonce_bounds_id_seq OWNED BY public.zkapp_nonce_bounds.id;


--
-- Name: zkapp_other_party; Type: TABLE; Schema: public; Owner: o1labs
--

CREATE TABLE public.zkapp_other_party (
    id integer NOT NULL,
    body_id integer NOT NULL,
    authorization_kind public.zkapp_authorization_kind_type NOT NULL
);


 

--
-- Name: zkapp_other_party_body; Type: TABLE; Schema: public; Owner: o1labs
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
-- Name: zkapp_other_party_body_id_seq; Type: SEQUENCE; Schema: public; Owner: o1labs
--

CREATE SEQUENCE public.zkapp_other_party_body_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


 

--
-- Name: zkapp_other_party_body_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: o1labs
--

ALTER SEQUENCE public.zkapp_other_party_body_id_seq OWNED BY public.zkapp_other_party_body.id;


--
-- Name: zkapp_other_party_id_seq; Type: SEQUENCE; Schema: public; Owner: o1labs
--

CREATE SEQUENCE public.zkapp_other_party_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


 

--
-- Name: zkapp_other_party_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: o1labs
--

ALTER SEQUENCE public.zkapp_other_party_id_seq OWNED BY public.zkapp_other_party.id;


--
-- Name: zkapp_party_failures; Type: TABLE; Schema: public; Owner: o1labs
--

CREATE TABLE public.zkapp_party_failures (
    id integer NOT NULL,
    index integer NOT NULL,
    failures text[] NOT NULL
);


 

--
-- Name: zkapp_party_failures_id_seq; Type: SEQUENCE; Schema: public; Owner: o1labs
--

CREATE SEQUENCE public.zkapp_party_failures_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


 

--
-- Name: zkapp_party_failures_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: o1labs
--

ALTER SEQUENCE public.zkapp_party_failures_id_seq OWNED BY public.zkapp_party_failures.id;


--
-- Name: zkapp_permissions; Type: TABLE; Schema: public; Owner: o1labs
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
-- Name: zkapp_permissions_id_seq; Type: SEQUENCE; Schema: public; Owner: o1labs
--

CREATE SEQUENCE public.zkapp_permissions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


 

--
-- Name: zkapp_permissions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: o1labs
--

ALTER SEQUENCE public.zkapp_permissions_id_seq OWNED BY public.zkapp_permissions.id;


--
-- Name: zkapp_precondition_accounts; Type: TABLE; Schema: public; Owner: o1labs
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
-- Name: zkapp_precondition_accounts_id_seq; Type: SEQUENCE; Schema: public; Owner: o1labs
--

CREATE SEQUENCE public.zkapp_precondition_accounts_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


 

--
-- Name: zkapp_precondition_accounts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: o1labs
--

ALTER SEQUENCE public.zkapp_precondition_accounts_id_seq OWNED BY public.zkapp_precondition_accounts.id;


--
-- Name: zkapp_sequence_states; Type: TABLE; Schema: public; Owner: o1labs
--

CREATE TABLE public.zkapp_sequence_states (
    id integer NOT NULL,
    element_ids integer[] NOT NULL
);


 

--
-- Name: zkapp_sequence_states_id_seq; Type: SEQUENCE; Schema: public; Owner: o1labs
--

CREATE SEQUENCE public.zkapp_sequence_states_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


 

--
-- Name: zkapp_sequence_states_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: o1labs
--

ALTER SEQUENCE public.zkapp_sequence_states_id_seq OWNED BY public.zkapp_sequence_states.id;


--
-- Name: zkapp_state_data; Type: TABLE; Schema: public; Owner: o1labs
--

CREATE TABLE public.zkapp_state_data (
    id integer NOT NULL,
    field text NOT NULL
);


 

--
-- Name: zkapp_state_data_array; Type: TABLE; Schema: public; Owner: o1labs
--

CREATE TABLE public.zkapp_state_data_array (
    id integer NOT NULL,
    element_ids integer[] NOT NULL
);


 

--
-- Name: zkapp_state_data_array_id_seq; Type: SEQUENCE; Schema: public; Owner: o1labs
--

CREATE SEQUENCE public.zkapp_state_data_array_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


 

--
-- Name: zkapp_state_data_array_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: o1labs
--

ALTER SEQUENCE public.zkapp_state_data_array_id_seq OWNED BY public.zkapp_state_data_array.id;


--
-- Name: zkapp_state_data_id_seq; Type: SEQUENCE; Schema: public; Owner: o1labs
--

CREATE SEQUENCE public.zkapp_state_data_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


 

--
-- Name: zkapp_state_data_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: o1labs
--

ALTER SEQUENCE public.zkapp_state_data_id_seq OWNED BY public.zkapp_state_data.id;


--
-- Name: zkapp_states; Type: TABLE; Schema: public; Owner: o1labs
--

CREATE TABLE public.zkapp_states (
    id integer NOT NULL,
    element_ids integer[] NOT NULL
);


 

--
-- Name: zkapp_states_id_seq; Type: SEQUENCE; Schema: public; Owner: o1labs
--

CREATE SEQUENCE public.zkapp_states_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


 

--
-- Name: zkapp_states_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: o1labs
--

ALTER SEQUENCE public.zkapp_states_id_seq OWNED BY public.zkapp_states.id;


--
-- Name: zkapp_timestamp_bounds; Type: TABLE; Schema: public; Owner: o1labs
--

CREATE TABLE public.zkapp_timestamp_bounds (
    id integer NOT NULL,
    timestamp_lower_bound text NOT NULL,
    timestamp_upper_bound text NOT NULL
);


 

--
-- Name: zkapp_timestamp_bounds_id_seq; Type: SEQUENCE; Schema: public; Owner: o1labs
--

CREATE SEQUENCE public.zkapp_timestamp_bounds_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


 

--
-- Name: zkapp_timestamp_bounds_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: o1labs
--

ALTER SEQUENCE public.zkapp_timestamp_bounds_id_seq OWNED BY public.zkapp_timestamp_bounds.id;


--
-- Name: zkapp_timing_info; Type: TABLE; Schema: public; Owner: o1labs
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
-- Name: zkapp_timing_info_id_seq; Type: SEQUENCE; Schema: public; Owner: o1labs
--

CREATE SEQUENCE public.zkapp_timing_info_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


 

--
-- Name: zkapp_timing_info_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: o1labs
--

ALTER SEQUENCE public.zkapp_timing_info_id_seq OWNED BY public.zkapp_timing_info.id;


--
-- Name: zkapp_token_id_bounds; Type: TABLE; Schema: public; Owner: o1labs
--

CREATE TABLE public.zkapp_token_id_bounds (
    id integer NOT NULL,
    token_id_lower_bound text NOT NULL,
    token_id_upper_bound text NOT NULL
);


 

--
-- Name: zkapp_token_id_bounds_id_seq; Type: SEQUENCE; Schema: public; Owner: o1labs
--

CREATE SEQUENCE public.zkapp_token_id_bounds_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


 

--
-- Name: zkapp_token_id_bounds_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: o1labs
--

ALTER SEQUENCE public.zkapp_token_id_bounds_id_seq OWNED BY public.zkapp_token_id_bounds.id;


--
-- Name: zkapp_updates; Type: TABLE; Schema: public; Owner: o1labs
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
-- Name: zkapp_updates_id_seq; Type: SEQUENCE; Schema: public; Owner: o1labs
--

CREATE SEQUENCE public.zkapp_updates_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


 

--
-- Name: zkapp_updates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: o1labs
--

ALTER SEQUENCE public.zkapp_updates_id_seq OWNED BY public.zkapp_updates.id;


--
-- Name: zkapp_uris; Type: TABLE; Schema: public; Owner: o1labs
--

CREATE TABLE public.zkapp_uris (
    id integer NOT NULL,
    value text NOT NULL
);


 

--
-- Name: zkapp_uris_id_seq; Type: SEQUENCE; Schema: public; Owner: o1labs
--

CREATE SEQUENCE public.zkapp_uris_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


 

--
-- Name: zkapp_uris_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: o1labs
--

ALTER SEQUENCE public.zkapp_uris_id_seq OWNED BY public.zkapp_uris.id;


--
-- Name: zkapp_verification_keys; Type: TABLE; Schema: public; Owner: o1labs
--

CREATE TABLE public.zkapp_verification_keys (
    id integer NOT NULL,
    verification_key text NOT NULL,
    hash text NOT NULL
);


 

--
-- Name: zkapp_verification_keys_id_seq; Type: SEQUENCE; Schema: public; Owner: o1labs
--

CREATE SEQUENCE public.zkapp_verification_keys_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


 

--
-- Name: zkapp_verification_keys_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: o1labs
--

ALTER SEQUENCE public.zkapp_verification_keys_id_seq OWNED BY public.zkapp_verification_keys.id;


--
-- Name: account_identifiers id; Type: DEFAULT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.account_identifiers ALTER COLUMN id SET DEFAULT nextval('public.account_identifiers_id_seq'::regclass);


--
-- Name: blocks id; Type: DEFAULT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.blocks ALTER COLUMN id SET DEFAULT nextval('public.blocks_id_seq'::regclass);


--
-- Name: epoch_data id; Type: DEFAULT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.epoch_data ALTER COLUMN id SET DEFAULT nextval('public.epoch_data_id_seq'::regclass);


--
-- Name: internal_commands id; Type: DEFAULT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.internal_commands ALTER COLUMN id SET DEFAULT nextval('public.internal_commands_id_seq'::regclass);


--
-- Name: public_keys id; Type: DEFAULT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.public_keys ALTER COLUMN id SET DEFAULT nextval('public.public_keys_id_seq'::regclass);


--
-- Name: snarked_ledger_hashes id; Type: DEFAULT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.snarked_ledger_hashes ALTER COLUMN id SET DEFAULT nextval('public.snarked_ledger_hashes_id_seq'::regclass);


--
-- Name: timing_info id; Type: DEFAULT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.timing_info ALTER COLUMN id SET DEFAULT nextval('public.timing_info_id_seq'::regclass);


--
-- Name: token_symbols id; Type: DEFAULT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.token_symbols ALTER COLUMN id SET DEFAULT nextval('public.token_symbols_id_seq'::regclass);


--
-- Name: tokens id; Type: DEFAULT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.tokens ALTER COLUMN id SET DEFAULT nextval('public.tokens_id_seq'::regclass);


--
-- Name: user_commands id; Type: DEFAULT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.user_commands ALTER COLUMN id SET DEFAULT nextval('public.user_commands_id_seq'::regclass);


--
-- Name: voting_for id; Type: DEFAULT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.voting_for ALTER COLUMN id SET DEFAULT nextval('public.voting_for_id_seq'::regclass);


--
-- Name: zkapp_account_precondition id; Type: DEFAULT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_account_precondition ALTER COLUMN id SET DEFAULT nextval('public.zkapp_account_precondition_id_seq'::regclass);


--
-- Name: zkapp_accounts id; Type: DEFAULT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_accounts ALTER COLUMN id SET DEFAULT nextval('public.zkapp_accounts_id_seq'::regclass);


--
-- Name: zkapp_amount_bounds id; Type: DEFAULT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_amount_bounds ALTER COLUMN id SET DEFAULT nextval('public.zkapp_amount_bounds_id_seq'::regclass);


--
-- Name: zkapp_balance_bounds id; Type: DEFAULT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_balance_bounds ALTER COLUMN id SET DEFAULT nextval('public.zkapp_balance_bounds_id_seq'::regclass);


--
-- Name: zkapp_commands id; Type: DEFAULT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_commands ALTER COLUMN id SET DEFAULT nextval('public.zkapp_commands_id_seq'::regclass);


--
-- Name: zkapp_epoch_data id; Type: DEFAULT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_epoch_data ALTER COLUMN id SET DEFAULT nextval('public.zkapp_epoch_data_id_seq'::regclass);


--
-- Name: zkapp_epoch_ledger id; Type: DEFAULT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_epoch_ledger ALTER COLUMN id SET DEFAULT nextval('public.zkapp_epoch_ledger_id_seq'::regclass);


--
-- Name: zkapp_events id; Type: DEFAULT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_events ALTER COLUMN id SET DEFAULT nextval('public.zkapp_events_id_seq'::regclass);


--
-- Name: zkapp_fee_payer_body id; Type: DEFAULT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_fee_payer_body ALTER COLUMN id SET DEFAULT nextval('public.zkapp_fee_payer_body_id_seq'::regclass);


--
-- Name: zkapp_global_slot_bounds id; Type: DEFAULT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_global_slot_bounds ALTER COLUMN id SET DEFAULT nextval('public.zkapp_global_slot_bounds_id_seq'::regclass);


--
-- Name: zkapp_length_bounds id; Type: DEFAULT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_length_bounds ALTER COLUMN id SET DEFAULT nextval('public.zkapp_length_bounds_id_seq'::regclass);


--
-- Name: zkapp_network_precondition id; Type: DEFAULT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_network_precondition ALTER COLUMN id SET DEFAULT nextval('public.zkapp_network_precondition_id_seq'::regclass);


--
-- Name: zkapp_nonce_bounds id; Type: DEFAULT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_nonce_bounds ALTER COLUMN id SET DEFAULT nextval('public.zkapp_nonce_bounds_id_seq'::regclass);


--
-- Name: zkapp_other_party id; Type: DEFAULT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_other_party ALTER COLUMN id SET DEFAULT nextval('public.zkapp_other_party_id_seq'::regclass);


--
-- Name: zkapp_other_party_body id; Type: DEFAULT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_other_party_body ALTER COLUMN id SET DEFAULT nextval('public.zkapp_other_party_body_id_seq'::regclass);


--
-- Name: zkapp_party_failures id; Type: DEFAULT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_party_failures ALTER COLUMN id SET DEFAULT nextval('public.zkapp_party_failures_id_seq'::regclass);


--
-- Name: zkapp_permissions id; Type: DEFAULT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_permissions ALTER COLUMN id SET DEFAULT nextval('public.zkapp_permissions_id_seq'::regclass);


--
-- Name: zkapp_precondition_accounts id; Type: DEFAULT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_precondition_accounts ALTER COLUMN id SET DEFAULT nextval('public.zkapp_precondition_accounts_id_seq'::regclass);


--
-- Name: zkapp_sequence_states id; Type: DEFAULT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_sequence_states ALTER COLUMN id SET DEFAULT nextval('public.zkapp_sequence_states_id_seq'::regclass);


--
-- Name: zkapp_state_data id; Type: DEFAULT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_state_data ALTER COLUMN id SET DEFAULT nextval('public.zkapp_state_data_id_seq'::regclass);


--
-- Name: zkapp_state_data_array id; Type: DEFAULT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_state_data_array ALTER COLUMN id SET DEFAULT nextval('public.zkapp_state_data_array_id_seq'::regclass);


--
-- Name: zkapp_states id; Type: DEFAULT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_states ALTER COLUMN id SET DEFAULT nextval('public.zkapp_states_id_seq'::regclass);


--
-- Name: zkapp_timestamp_bounds id; Type: DEFAULT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_timestamp_bounds ALTER COLUMN id SET DEFAULT nextval('public.zkapp_timestamp_bounds_id_seq'::regclass);


--
-- Name: zkapp_timing_info id; Type: DEFAULT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_timing_info ALTER COLUMN id SET DEFAULT nextval('public.zkapp_timing_info_id_seq'::regclass);


--
-- Name: zkapp_token_id_bounds id; Type: DEFAULT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_token_id_bounds ALTER COLUMN id SET DEFAULT nextval('public.zkapp_token_id_bounds_id_seq'::regclass);


--
-- Name: zkapp_updates id; Type: DEFAULT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_updates ALTER COLUMN id SET DEFAULT nextval('public.zkapp_updates_id_seq'::regclass);


--
-- Name: zkapp_uris id; Type: DEFAULT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_uris ALTER COLUMN id SET DEFAULT nextval('public.zkapp_uris_id_seq'::regclass);


--
-- Name: zkapp_verification_keys id; Type: DEFAULT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_verification_keys ALTER COLUMN id SET DEFAULT nextval('public.zkapp_verification_keys_id_seq'::regclass);


--
-- Data for Name: account_identifiers; Type: TABLE DATA; Schema: public; Owner: o1labs
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
-- Data for Name: accounts_accessed; Type: TABLE DATA; Schema: public; Owner: o1labs
--

COPY public.accounts_accessed (ledger_index, block_id, account_identifier_id, token_symbol_id, balance, nonce, receipt_chain_hash, delegate_id, voting_for_id, timing_id, permissions_id, zkapp_id) FROM stdin;
5	1	1	1	0	293	2mzaNmmgKfkbziZZgGhdyMjYXgpnLDSZb3zsMmR7atQudvXuXFDn	2	1	1	1	\N
2	1	2	1	1000000000000000000	30	2n28bLJpCLPYEgNqp7rQosEHQdfqSzBSjwX52jMDZbe34d9wExef	3	1	2	2	\N
1	1	3	1	1000000000000000000	0	2mzhRazYextcWnQ81n5CGTrFD2Rx5dAS6rYjAeYCEyfhUjZUzYFy	1	1	3	3	\N
3	1	4	1	100000000000000000	1	2n16Uzkm9ABP5XHKJj81zD3EnbURJf5GykKxhNRrspMus1NNeXvL	5	1	4	4	\N
0	1	5	1	1000000000000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	1	1	5	3	\N
4	1	6	1	0	907	2n1VHJxAsZy8krLNTbTocdwMh2XLEexuz1Y21QJgMVNQjDGCqhKk	6	1	6	3	\N
2	3	2	1	1000000000000000000	30	2n28bLJpCLPYEgNqp7rQosEHQdfqSzBSjwX52jMDZbe34d9wExef	3	1	2	2	\N
5	4	1	1	1000000000	293	2mzaNmmgKfkbziZZgGhdyMjYXgpnLDSZb3zsMmR7atQudvXuXFDn	2	1	1	1	\N
2	4	2	1	999999994000000000	31	2n21egVC6pzypDyyRQpe3Ht5XaTfXn9tcLgp56uT3hc8AA6achZ1	3	1	2	2	\N
5	5	1	1	2000000000	293	2mzaNmmgKfkbziZZgGhdyMjYXgpnLDSZb3zsMmR7atQudvXuXFDn	2	1	1	1	\N
2	5	2	1	999999988000000000	32	2mzvQPMuCpFNqi5gaaSFjSA4LmpdPaWbyHudVpxVxua6Z3LQ6z4a	3	1	2	2	\N
2	6	2	1	999999988000000000	32	2mzvQPMuCpFNqi5gaaSFjSA4LmpdPaWbyHudVpxVxua6Z3LQ6z4a	3	1	2	2	\N
5	7	1	1	4000000000	293	2mzaNmmgKfkbziZZgGhdyMjYXgpnLDSZb3zsMmR7atQudvXuXFDn	2	1	1	1	\N
2	7	2	1	999999976000000000	34	2n1aPwFEuuZJvrFviDMFscYN3uMBhaXaK88XYDdFtdjasgqnkddG	3	1	2	2	\N
5	8	1	1	5000000000	293	2mzaNmmgKfkbziZZgGhdyMjYXgpnLDSZb3zsMmR7atQudvXuXFDn	2	1	1	1	\N
2	8	2	1	999999970000000000	35	2n1NMoEaczejqEFDbGvm7Fo8ZYJ5g8psV1AaLnh3d5tz94Ma2BLz	3	1	2	2	\N
2	9	2	1	999999970000000000	35	2n1NMoEaczejqEFDbGvm7Fo8ZYJ5g8psV1AaLnh3d5tz94Ma2BLz	3	1	2	2	\N
5	10	1	1	8000000000	293	2mzaNmmgKfkbziZZgGhdyMjYXgpnLDSZb3zsMmR7atQudvXuXFDn	2	1	1	1	\N
2	10	2	1	999999952000000000	38	2n1TqRTUuBJc6oKX3Mzi2PkY1qwtTYqXDjJuME4fjh8t2MiakCX4	3	1	2	2	\N
3	10	4	1	100000000000000000	1	2n16Uzkm9ABP5XHKJj81zD3EnbURJf5GykKxhNRrspMus1NNeXvL	5	1	4	4	\N
5	11	1	1	10000000000	293	2mzaNmmgKfkbziZZgGhdyMjYXgpnLDSZb3zsMmR7atQudvXuXFDn	2	1	1	1	\N
2	11	2	1	999999940000000000	40	2mzX59zGn8PjKyFfxruS8Wggr9PKJKoh3UgY8n4oQvrFCJaEwsyo	3	1	2	2	\N
3	11	4	1	100000000000000000	1	2n16Uzkm9ABP5XHKJj81zD3EnbURJf5GykKxhNRrspMus1NNeXvL	5	1	4	4	\N
2	12	2	1	999999940000000000	40	2mzX59zGn8PjKyFfxruS8Wggr9PKJKoh3UgY8n4oQvrFCJaEwsyo	3	1	2	2	\N
3	12	4	1	100000000000000000	1	2n16Uzkm9ABP5XHKJj81zD3EnbURJf5GykKxhNRrspMus1NNeXvL	5	1	4	4	\N
5	13	1	1	13000000000	293	2mzaNmmgKfkbziZZgGhdyMjYXgpnLDSZb3zsMmR7atQudvXuXFDn	2	1	1	1	\N
2	13	2	1	999999922000000000	43	2n1Ni7cQ9JKGwQuDNQ7LA22VspYEDUR7rMZYgkdjdSb1NLi8sqUF	3	1	2	2	\N
3	13	4	1	100000000000000000	1	2n16Uzkm9ABP5XHKJj81zD3EnbURJf5GykKxhNRrspMus1NNeXvL	5	1	4	4	\N
2	14	2	1	999999922000000000	43	2n1Ni7cQ9JKGwQuDNQ7LA22VspYEDUR7rMZYgkdjdSb1NLi8sqUF	3	1	2	2	\N
5	15	1	1	16000000000	293	2mzaNmmgKfkbziZZgGhdyMjYXgpnLDSZb3zsMmR7atQudvXuXFDn	2	1	1	1	\N
2	15	2	1	999999904000000000	46	2mzqdunG6z7XTNp6qT5M8oF6PhHvkdhg2TkZDUe2ECJv9QAu67wN	3	1	2	2	\N
3	15	4	1	100000000000000000	1	2n16Uzkm9ABP5XHKJj81zD3EnbURJf5GykKxhNRrspMus1NNeXvL	5	1	4	4	\N
5	16	1	1	17000000000	293	2mzaNmmgKfkbziZZgGhdyMjYXgpnLDSZb3zsMmR7atQudvXuXFDn	2	1	1	1	\N
2	16	2	1	999999898000000000	47	2n1Msp6VFeEe1k1aWDsQDmVuAoWuuq2Z55Tgr1PTxKPtVsyNUEA1	3	1	2	2	\N
5	17	1	1	19000000000	293	2mzaNmmgKfkbziZZgGhdyMjYXgpnLDSZb3zsMmR7atQudvXuXFDn	2	1	1	1	\N
2	17	2	1	999999886000000000	49	2n1T8oyx85nD1gGszS5KzT2r2YSeHWiQPDrGeVKJw7AFiqdDCxdY	3	1	2	2	\N
3	17	4	1	100000000000000000	1	2n16Uzkm9ABP5XHKJj81zD3EnbURJf5GykKxhNRrspMus1NNeXvL	5	1	4	4	\N
2	18	2	1	999999886000000000	49	2n1T8oyx85nD1gGszS5KzT2r2YSeHWiQPDrGeVKJw7AFiqdDCxdY	3	1	2	2	\N
5	19	1	1	20000000000	293	2mzaNmmgKfkbziZZgGhdyMjYXgpnLDSZb3zsMmR7atQudvXuXFDn	2	1	1	1	\N
2	19	2	1	999999880000000000	50	2n2JCSs8gtmeMDAfhHM9wgutAeVVka2Lu1j9z5tCaP1m23dVoksL	3	1	2	2	\N
5	20	1	1	24000000000	293	2mzaNmmgKfkbziZZgGhdyMjYXgpnLDSZb3zsMmR7atQudvXuXFDn	2	1	1	1	\N
2	20	2	1	999999856000000000	54	2n1Jsmba2ygp5D81nRSACrBHsGd18vQPk47ctARgiqX26B6YxT2U	3	1	2	2	\N
3	20	4	1	100000000000000000	1	2n16Uzkm9ABP5XHKJj81zD3EnbURJf5GykKxhNRrspMus1NNeXvL	5	1	4	4	\N
5	21	1	1	25000000000	293	2mzaNmmgKfkbziZZgGhdyMjYXgpnLDSZb3zsMmR7atQudvXuXFDn	2	1	1	1	\N
2	21	2	1	999999850000000000	55	2n26dMJP7yWedqRvpKZUfdgnN2WW1iDHoM5bpNDpNqXRzwQ9zvFq	3	1	2	2	\N
3	21	4	1	100000000000000000	1	2n16Uzkm9ABP5XHKJj81zD3EnbURJf5GykKxhNRrspMus1NNeXvL	5	1	4	4	\N
5	22	1	1	26000000000	293	2mzaNmmgKfkbziZZgGhdyMjYXgpnLDSZb3zsMmR7atQudvXuXFDn	2	1	1	1	\N
2	22	2	1	999999844000000000	56	2n1yvxDRZ2QhqGrKfdW2mFN3APWtoBivV6xERDGs7YxSEwYGk7Jz	3	1	2	2	\N
3	22	4	1	100000000000000000	1	2n16Uzkm9ABP5XHKJj81zD3EnbURJf5GykKxhNRrspMus1NNeXvL	5	1	4	4	\N
5	23	1	1	27000000000	293	2mzaNmmgKfkbziZZgGhdyMjYXgpnLDSZb3zsMmR7atQudvXuXFDn	2	1	1	1	\N
2	23	2	1	999999838000000000	57	2n1RDmCsEnYXe6ygNL6n7UfhVZC3KVoHGN99A6aUkjGbQfgPRaWR	3	1	2	2	\N
2	24	2	1	999999838000000000	57	2n1RDmCsEnYXe6ygNL6n7UfhVZC3KVoHGN99A6aUkjGbQfgPRaWR	3	1	2	2	\N
5	25	1	1	30000000000	293	2mzaNmmgKfkbziZZgGhdyMjYXgpnLDSZb3zsMmR7atQudvXuXFDn	2	1	1	1	\N
2	25	2	1	999999820000000000	60	2n2KMsHSGL3aLYgPJHAj7CbvGuQ98hRY2J9VgzL22njJC7T7wLL7	3	1	2	2	\N
3	25	4	1	100000000000000000	1	2n16Uzkm9ABP5XHKJj81zD3EnbURJf5GykKxhNRrspMus1NNeXvL	5	1	4	4	\N
5	27	1	1	33000000000	293	2mzaNmmgKfkbziZZgGhdyMjYXgpnLDSZb3zsMmR7atQudvXuXFDn	2	1	1	1	\N
2	27	2	1	999999802000000000	63	2n29ZLXXgtU4M3aXEHNsoj9PANep74tsMM1Z4bqXd2sSQahy5EQK	3	1	2	2	\N
3	27	4	1	100000000000000000	1	2n16Uzkm9ABP5XHKJj81zD3EnbURJf5GykKxhNRrspMus1NNeXvL	5	1	4	4	\N
5	26	1	1	32000000000	293	2mzaNmmgKfkbziZZgGhdyMjYXgpnLDSZb3zsMmR7atQudvXuXFDn	2	1	1	1	\N
2	26	2	1	999999808000000000	62	2mzue1oQmpyUzaNFYB6nWzu4QzH6thB1bnV7y3tB6728oEGRQYA5	3	1	2	2	\N
3	26	4	1	100000000000000000	1	2n16Uzkm9ABP5XHKJj81zD3EnbURJf5GykKxhNRrspMus1NNeXvL	5	1	4	4	\N
2	28	2	1	999999802000000000	63	2n29ZLXXgtU4M3aXEHNsoj9PANep74tsMM1Z4bqXd2sSQahy5EQK	3	1	2	2	\N
3	28	4	1	100000000000000000	1	2n16Uzkm9ABP5XHKJj81zD3EnbURJf5GykKxhNRrspMus1NNeXvL	5	1	4	4	\N
5	29	1	1	35000000000	293	2mzaNmmgKfkbziZZgGhdyMjYXgpnLDSZb3zsMmR7atQudvXuXFDn	2	1	1	1	\N
2	29	2	1	999999790000000000	65	2n21huCahcxPKM2sMX8dLbFTL4ucnPfyru1zuH1DDcWCvUp7m7dH	3	1	2	2	\N
3	29	4	1	100000000000000000	1	2n16Uzkm9ABP5XHKJj81zD3EnbURJf5GykKxhNRrspMus1NNeXvL	5	1	4	4	\N
5	30	1	1	36000000000	293	2mzaNmmgKfkbziZZgGhdyMjYXgpnLDSZb3zsMmR7atQudvXuXFDn	2	1	1	1	\N
2	30	2	1	999999784000000000	66	2n24RZHYbXihQgrrSC2h6Mr73Y4rd7PhCeRLzeDydAdf4YUcPffb	3	1	2	2	\N
3	30	4	1	100000000000000000	1	2n16Uzkm9ABP5XHKJj81zD3EnbURJf5GykKxhNRrspMus1NNeXvL	5	1	4	4	\N
2	31	2	1	999999784000000000	66	2n24RZHYbXihQgrrSC2h6Mr73Y4rd7PhCeRLzeDydAdf4YUcPffb	3	1	2	2	\N
3	31	4	1	100000000000000000	1	2n16Uzkm9ABP5XHKJj81zD3EnbURJf5GykKxhNRrspMus1NNeXvL	5	1	4	4	\N
5	32	1	1	39000000000	293	2mzaNmmgKfkbziZZgGhdyMjYXgpnLDSZb3zsMmR7atQudvXuXFDn	2	1	1	1	\N
2	32	2	1	999999766000000000	69	2n1uBzRm3A6ddJxPghPdosjLygWDR4LzC6bfLnMUPPCNQJdVgh4f	3	1	2	2	\N
3	32	4	1	100000000000000000	1	2n16Uzkm9ABP5XHKJj81zD3EnbURJf5GykKxhNRrspMus1NNeXvL	5	1	4	4	\N
5	33	1	1	41000000000	293	2mzaNmmgKfkbziZZgGhdyMjYXgpnLDSZb3zsMmR7atQudvXuXFDn	2	1	1	1	\N
2	33	2	1	999999754000000000	71	2mzc1nJaeh4XqsiTg3PvnQc7QW5dMKUR3K8MjNhuWAwyLUcSRdHL	3	1	2	2	\N
3	33	4	1	100000000000000000	1	2n16Uzkm9ABP5XHKJj81zD3EnbURJf5GykKxhNRrspMus1NNeXvL	5	1	4	4	\N
2	34	2	1	999999754000000000	71	2mzc1nJaeh4XqsiTg3PvnQc7QW5dMKUR3K8MjNhuWAwyLUcSRdHL	3	1	2	2	\N
5	35	1	1	46000000000	293	2mzaNmmgKfkbziZZgGhdyMjYXgpnLDSZb3zsMmR7atQudvXuXFDn	2	1	1	1	\N
2	35	2	1	999999724000000000	76	2n1hi3rp7N24L3FSM94i3p9mpC8GZofgTPvUv9GZHueFkJdmENCh	3	1	2	2	\N
3	35	4	1	100000000000000000	1	2n16Uzkm9ABP5XHKJj81zD3EnbURJf5GykKxhNRrspMus1NNeXvL	5	1	4	4	\N
2	36	2	1	999999724000000000	76	2n1hi3rp7N24L3FSM94i3p9mpC8GZofgTPvUv9GZHueFkJdmENCh	3	1	2	2	\N
2	37	2	1	999999724000000000	76	2n1hi3rp7N24L3FSM94i3p9mpC8GZofgTPvUv9GZHueFkJdmENCh	3	1	2	2	\N
3	37	4	1	100000000000000000	1	2n16Uzkm9ABP5XHKJj81zD3EnbURJf5GykKxhNRrspMus1NNeXvL	5	1	4	4	\N
2	38	2	1	999999724000000000	76	2n1hi3rp7N24L3FSM94i3p9mpC8GZofgTPvUv9GZHueFkJdmENCh	3	1	2	2	\N
3	38	4	1	100000000000000000	1	2n16Uzkm9ABP5XHKJj81zD3EnbURJf5GykKxhNRrspMus1NNeXvL	5	1	4	4	\N
5	39	1	1	49000000000	293	2mzaNmmgKfkbziZZgGhdyMjYXgpnLDSZb3zsMmR7atQudvXuXFDn	2	1	1	1	\N
2	39	2	1	999999706000000000	79	2mzs6nqrkSo8A6L2aNWvyUZwPVh6y4H2N6ohzCxxeNyLidF2Brvi	3	1	2	2	\N
6	39	7	1	9999000000	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	7	1	7	5	1
3	39	4	1	100000000000000000	1	2n16Uzkm9ABP5XHKJj81zD3EnbURJf5GykKxhNRrspMus1NNeXvL	5	1	4	4	\N
0	39	5	1	999999985000000000	2	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	1	1	5	3	\N
5	40	1	1	55000000000	293	2mzaNmmgKfkbziZZgGhdyMjYXgpnLDSZb3zsMmR7atQudvXuXFDn	2	1	1	1	\N
2	40	2	1	999999670000000000	85	2n1p8sUeMFwquxxmMJ88jbPw8uJfFYP3ieBvdAR5nQGJkzyjyZmy	3	1	2	2	\N
3	40	4	1	100000000000000000	1	2n16Uzkm9ABP5XHKJj81zD3EnbURJf5GykKxhNRrspMus1NNeXvL	5	1	4	4	\N
5	41	1	1	56000000000	293	2mzaNmmgKfkbziZZgGhdyMjYXgpnLDSZb3zsMmR7atQudvXuXFDn	2	1	1	1	\N
2	41	2	1	999999664000000000	86	2n2811XKfA7xvLD1vFVLuNrKHe8RheG2ioM4aWnRJxkE9DbCTULH	3	1	2	2	\N
3	41	4	1	100000000000000000	1	2n16Uzkm9ABP5XHKJj81zD3EnbURJf5GykKxhNRrspMus1NNeXvL	5	1	4	4	\N
5	42	1	1	57000000000	293	2mzaNmmgKfkbziZZgGhdyMjYXgpnLDSZb3zsMmR7atQudvXuXFDn	2	1	1	1	\N
2	42	2	1	999999658000000000	87	2mzuhmpsk1DJC32LJp8ouL6dTwyX17gnTSuQzwKo7mL5sjPZRY11	3	1	2	2	\N
3	42	4	1	100000000000000000	1	2n16Uzkm9ABP5XHKJj81zD3EnbURJf5GykKxhNRrspMus1NNeXvL	5	1	4	4	\N
2	43	2	1	999999658000000000	87	2mzuhmpsk1DJC32LJp8ouL6dTwyX17gnTSuQzwKo7mL5sjPZRY11	3	1	2	2	\N
2	44	2	1	999999658000000000	87	2mzuhmpsk1DJC32LJp8ouL6dTwyX17gnTSuQzwKo7mL5sjPZRY11	3	1	2	2	\N
5	45	1	1	61000000000	293	2mzaNmmgKfkbziZZgGhdyMjYXgpnLDSZb3zsMmR7atQudvXuXFDn	2	1	1	1	\N
2	45	2	1	999999634000000000	91	2n1tAvG6jFmrW7y9bPfL4DuicXmppdiK2u9mvaMK8C8up85Q5z4b	3	1	2	2	\N
3	45	4	1	100000000000000000	1	2n16Uzkm9ABP5XHKJj81zD3EnbURJf5GykKxhNRrspMus1NNeXvL	5	1	4	4	\N
5	46	1	1	62000000000	293	2mzaNmmgKfkbziZZgGhdyMjYXgpnLDSZb3zsMmR7atQudvXuXFDn	2	1	1	1	\N
2	46	2	1	999999628000000000	92	2n16ewqGWr2FsfBmUqNoYCAGiXj2YKayL1rgbuW2bCYSrgvm4dP5	3	1	2	2	\N
3	46	4	1	100000000000000000	1	2n16Uzkm9ABP5XHKJj81zD3EnbURJf5GykKxhNRrspMus1NNeXvL	5	1	4	4	\N
5	47	1	1	63000000000	293	2mzaNmmgKfkbziZZgGhdyMjYXgpnLDSZb3zsMmR7atQudvXuXFDn	2	1	1	1	\N
2	47	2	1	999999622000000000	93	2n1gbXmd1AKjL34nMnTu4PEDTZEgvMprsARgNhCRv1fSN8FiNmt9	3	1	2	2	\N
3	47	4	1	100000000000000000	1	2n16Uzkm9ABP5XHKJj81zD3EnbURJf5GykKxhNRrspMus1NNeXvL	5	1	4	4	\N
5	48	1	1	64000000000	293	2mzaNmmgKfkbziZZgGhdyMjYXgpnLDSZb3zsMmR7atQudvXuXFDn	2	1	1	1	\N
2	48	2	1	999999616000000000	94	2mzqbuzB6F4coNhy6SrAewWYqyeozwTQrVdLusG88qfoaiyoE6cn	3	1	2	2	\N
3	48	4	1	100000000000000000	1	2n16Uzkm9ABP5XHKJj81zD3EnbURJf5GykKxhNRrspMus1NNeXvL	5	1	4	4	\N
5	50	1	1	66000000000	293	2mzaNmmgKfkbziZZgGhdyMjYXgpnLDSZb3zsMmR7atQudvXuXFDn	2	1	1	1	\N
2	50	2	1	999999604000000000	96	2mztkQ7uTRqZhyjrHA949oBp89LEfHtMdBq1d44YC6cNWrmKnJUh	3	1	2	2	\N
3	50	4	1	100000000000000000	1	2n16Uzkm9ABP5XHKJj81zD3EnbURJf5GykKxhNRrspMus1NNeXvL	5	1	4	4	\N
2	49	2	1	999999616000000000	94	2mzqbuzB6F4coNhy6SrAewWYqyeozwTQrVdLusG88qfoaiyoE6cn	3	1	2	2	\N
5	51	1	1	67000000000	293	2mzaNmmgKfkbziZZgGhdyMjYXgpnLDSZb3zsMmR7atQudvXuXFDn	2	1	1	1	\N
2	51	2	1	999999598000000000	97	2n1KaQUUdth87m8z8wFfj5xZLKYVtvVAEtngimc848ssFgqpjiV2	3	1	2	2	\N
6	51	7	1	9999000000	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	7	1	7	5	2
0	51	5	1	999999980000000000	3	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	1	1	5	3	\N
5	52	1	1	69000000000	293	2mzaNmmgKfkbziZZgGhdyMjYXgpnLDSZb3zsMmR7atQudvXuXFDn	2	1	1	1	\N
2	52	2	1	999999586000000000	99	2mzwxNc896n57FrVcAoC8jLzuzyraskbgfG7vtKEUbS95zhHBSsp	3	1	2	2	\N
3	52	4	1	100000000000000000	1	2n16Uzkm9ABP5XHKJj81zD3EnbURJf5GykKxhNRrspMus1NNeXvL	5	1	4	4	\N
5	53	1	1	70000000000	293	2mzaNmmgKfkbziZZgGhdyMjYXgpnLDSZb3zsMmR7atQudvXuXFDn	2	1	1	1	\N
2	53	2	1	999999580000000000	100	2mzivQuQ8KoxKibh6Ke8zgzanV9Y8dUkyrBXYfhJ57draonhrdbD	3	1	2	2	\N
2	54	2	1	999999580000000000	100	2mzivQuQ8KoxKibh6Ke8zgzanV9Y8dUkyrBXYfhJ57draonhrdbD	3	1	2	2	\N
5	55	1	1	74000000000	293	2mzaNmmgKfkbziZZgGhdyMjYXgpnLDSZb3zsMmR7atQudvXuXFDn	2	1	1	1	\N
2	55	2	1	999999556000000000	104	2n1nEFm15dFtGa4iBbmAft6eCXMSqhfk3JBDKtx6V6T7XN7htQbV	3	1	2	2	\N
3	55	4	1	100000000000000000	1	2n16Uzkm9ABP5XHKJj81zD3EnbURJf5GykKxhNRrspMus1NNeXvL	5	1	4	4	\N
5	56	1	1	76000000000	293	2mzaNmmgKfkbziZZgGhdyMjYXgpnLDSZb3zsMmR7atQudvXuXFDn	2	1	1	1	\N
2	56	2	1	999999544000000000	106	2n1anWyThnTRtfP8SrBSt7LvofKJdfKPXWEKFWZz8Ft9zqtZDPdB	3	1	2	2	\N
3	56	4	1	100000000000000000	1	2n16Uzkm9ABP5XHKJj81zD3EnbURJf5GykKxhNRrspMus1NNeXvL	5	1	4	4	\N
5	57	1	1	77000000000	293	2mzaNmmgKfkbziZZgGhdyMjYXgpnLDSZb3zsMmR7atQudvXuXFDn	2	1	1	1	\N
2	57	2	1	999999538000000000	107	2n1RR7w9Ls2WMHiYjugMdnQpqzL6mMpffSCp6VQnN4WBHbY11bVR	3	1	2	2	\N
3	57	4	1	100000000000000000	1	2n16Uzkm9ABP5XHKJj81zD3EnbURJf5GykKxhNRrspMus1NNeXvL	5	1	4	4	\N
2	58	2	1	999999538000000000	107	2n1RR7w9Ls2WMHiYjugMdnQpqzL6mMpffSCp6VQnN4WBHbY11bVR	3	1	2	2	\N
2	59	2	1	999999538000000000	107	2n1RR7w9Ls2WMHiYjugMdnQpqzL6mMpffSCp6VQnN4WBHbY11bVR	3	1	2	2	\N
2	60	2	1	999999538000000000	107	2n1RR7w9Ls2WMHiYjugMdnQpqzL6mMpffSCp6VQnN4WBHbY11bVR	3	1	2	2	\N
3	60	4	1	100000000000000000	1	2n16Uzkm9ABP5XHKJj81zD3EnbURJf5GykKxhNRrspMus1NNeXvL	5	1	4	4	\N
2	61	2	1	999999538000000000	107	2n1RR7w9Ls2WMHiYjugMdnQpqzL6mMpffSCp6VQnN4WBHbY11bVR	3	1	2	2	\N
3	61	4	1	100000000000000000	1	2n16Uzkm9ABP5XHKJj81zD3EnbURJf5GykKxhNRrspMus1NNeXvL	5	1	4	4	\N
2	62	2	1	999999538000000000	107	2n1RR7w9Ls2WMHiYjugMdnQpqzL6mMpffSCp6VQnN4WBHbY11bVR	3	1	2	2	\N
3	62	4	1	100000000000000000	1	2n16Uzkm9ABP5XHKJj81zD3EnbURJf5GykKxhNRrspMus1NNeXvL	5	1	4	4	\N
2	63	2	1	999999538000000000	107	2n1RR7w9Ls2WMHiYjugMdnQpqzL6mMpffSCp6VQnN4WBHbY11bVR	3	1	2	2	\N
3	63	4	1	100000000000000000	1	2n16Uzkm9ABP5XHKJj81zD3EnbURJf5GykKxhNRrspMus1NNeXvL	5	1	4	4	\N
\.


--
-- Data for Name: accounts_created; Type: TABLE DATA; Schema: public; Owner: o1labs
--

COPY public.accounts_created (block_id, account_identifier_id, creation_fee) FROM stdin;
39	7	1000000
\.


--
-- Data for Name: blocks; Type: TABLE DATA; Schema: public; Owner: o1labs
--

COPY public.blocks (id, state_hash, parent_id, parent_hash, creator_id, block_winner_id, snarked_ledger_hash_id, staking_epoch_data_id, next_epoch_data_id, min_window_density, total_currency, ledger_hash, height, global_slot_since_hard_fork, global_slot_since_genesis, "timestamp", chain_status) FROM stdin;
4	3NLDjLvtRLQno8uBh6YEsJQi7dXvMRejUXCpw47NihQvdNPbS98K	3	3NKVovdAdj2BTwXiJzvLCqSpPuu2MutZnBHN5vHBuJPSfMm3biRv	3	3	1	1	5	6	3100000000000000000	jxRTkUQsQBXDF4YBmjETmJSvzuyJt9t68odpobV1PLUgYi2GU73	3	67	67	1655790554000	canonical
5	3NLkijnwBFRefzJeVhtb6dsbHiubpTTN5tmrBrcmpzjNtAFzQoSd	4	3NLDjLvtRLQno8uBh6YEsJQi7dXvMRejUXCpw47NihQvdNPbS98K	3	3	1	1	6	6	3100000000000000000	jxiv8LUzFmQPVwRzv3Uv4oM2u3KpEnW7jpuE6BWSrrQPBXEMtJf	4	68	68	1655790556000	canonical
6	3NLdWkbiGZYAcm7tFgoPxowrmgzxQsu65ns1uBtxWADrm8mrNePZ	5	3NLkijnwBFRefzJeVhtb6dsbHiubpTTN5tmrBrcmpzjNtAFzQoSd	3	3	1	1	7	6	3100000000000000000	jxiv8LUzFmQPVwRzv3Uv4oM2u3KpEnW7jpuE6BWSrrQPBXEMtJf	5	70	70	1655790560000	canonical
7	3NKzqXxqqU4J1NacW7vQLjt5Xp5ocLswYRNuzDa8Uzk9N3hJLJTy	6	3NLdWkbiGZYAcm7tFgoPxowrmgzxQsu65ns1uBtxWADrm8mrNePZ	3	3	1	1	8	6	3100000000000000000	jwb4eaiJXcS5oEdTM2vrKjr9PMZjiNse1q976ZRyGHrJT38rFCY	6	71	71	1655790562000	canonical
8	3NKZMJh49ksivk9xDhQfgD38x5dbaUpQGQNLE8vDLTYobsWzjtmp	7	3NKzqXxqqU4J1NacW7vQLjt5Xp5ocLswYRNuzDa8Uzk9N3hJLJTy	3	3	1	1	9	6	3100000000000000000	jwM1ddu7XKYQYpTzPWGGdaMXZVgptjQ2Fwg4JUTtxHTpptTPdUe	7	72	72	1655790564000	canonical
9	3NKbz2MZrxQuAbgsuoMeCujMvY3A8PwCmn8h16hCCmc7eKE5wnix	8	3NKZMJh49ksivk9xDhQfgD38x5dbaUpQGQNLE8vDLTYobsWzjtmp	3	3	1	1	10	6	3100000000000000000	jwM1ddu7XKYQYpTzPWGGdaMXZVgptjQ2Fwg4JUTtxHTpptTPdUe	8	73	73	1655790566000	canonical
10	3NLF8J1KyTsqDHS5BNaCueH2zavRKoDGntWyVdZbv2Te3BFd7tCc	9	3NKbz2MZrxQuAbgsuoMeCujMvY3A8PwCmn8h16hCCmc7eKE5wnix	3	3	1	1	11	6	3100000000000000000	jxgLT6fw3h7cvzjUd5StU5GergJnwH6vXex195tx95fjG6DBpuS	9	78	78	1655790576000	canonical
11	3NLGLJqs3QxzKXeHpUBweRsqBEPH8989JbKkGgfbYUuZbhx45vBb	10	3NLF8J1KyTsqDHS5BNaCueH2zavRKoDGntWyVdZbv2Te3BFd7tCc	3	3	1	1	12	6	3100000000000000000	jwPrJaiR6bEetVXUPtUHN3uxQx1cwaLkqT3wsuiFC9gYWjMXJsz	10	81	81	1655790582000	canonical
13	3NKyhCcUwSn86CnMWcYysjuhdP6DUGSmFD3kd7j85YBTkLuQQxE3	12	3NKy5jA6rXAkcpt9YFoeGtkgbmQjAfRfZXZPxXzgMeF3kWHtt5mp	3	3	1	1	14	6	3100000000000000000	jwjyCrh5ihAbg2vnv6hb7re6eQfn4nJLJ6ZHzrha8nv7u7mRCKb	12	86	86	1655790592000	canonical
14	3NKizyBvJf1ydTTup7ncBCKFSsPWvPkKjvNhj5fMgfhWtKNExoyL	13	3NKyhCcUwSn86CnMWcYysjuhdP6DUGSmFD3kd7j85YBTkLuQQxE3	3	3	1	1	15	6	3100000000000000000	jwjyCrh5ihAbg2vnv6hb7re6eQfn4nJLJ6ZHzrha8nv7u7mRCKb	13	90	90	1655790600000	canonical
15	3NLvZwbYanPJcG3fbz5Tvfawg9Ui2dVN2wzkBPkSPMrkQE6sdQ3u	14	3NKizyBvJf1ydTTup7ncBCKFSsPWvPkKjvNhj5fMgfhWtKNExoyL	3	3	1	1	16	6	3100000000000000000	jxmCa8kuV5TqzekXMubLQCsR6rtJ8m8Dd4ctaNjqLzCvaTRTKBR	14	91	91	1655790602000	canonical
16	3NLaDqV3M9Mb4BYVUArvgTAEkFNB9pAQaxnavnGfWgDo4JPjcYRV	15	3NLvZwbYanPJcG3fbz5Tvfawg9Ui2dVN2wzkBPkSPMrkQE6sdQ3u	3	3	1	1	17	6	3100000000000000000	jwpEaZSugL1FaqFubu1vEfoFqDtR6SUu6aaCAbVmZGRS7SzEEvd	15	93	93	1655790606000	canonical
17	3NL5eUZC3AWAhuqowjoHwodcsafnZtmdfd6U6BuxrTe5BotNMyT8	16	3NLaDqV3M9Mb4BYVUArvgTAEkFNB9pAQaxnavnGfWgDo4JPjcYRV	3	3	1	1	18	6	3100000000000000000	jxBmNTnqJ81uSrZJyHBUPXARphwN4ABFCQ8i2wmH2SihcDuDfuq	16	96	96	1655790612000	canonical
18	3NK9ovXze3B5U8XFsAuKwJEWh5n55cTWnPTyehmovHDwEcGZMdG4	17	3NL5eUZC3AWAhuqowjoHwodcsafnZtmdfd6U6BuxrTe5BotNMyT8	3	3	1	1	19	6	3100000000000000000	jxBmNTnqJ81uSrZJyHBUPXARphwN4ABFCQ8i2wmH2SihcDuDfuq	17	97	97	1655790614000	canonical
19	3NLiBVAhQZseXsJF7tf8ZUaiULPxxzX78b7EtcSUJEhYsGVnDNQ8	18	3NK9ovXze3B5U8XFsAuKwJEWh5n55cTWnPTyehmovHDwEcGZMdG4	3	3	1	1	20	6	3100000000000000000	jxyRvPgt2h9fcQWLo6xJawJtkefXc7aVS8b28mWQmY7DgyrzBW6	18	98	98	1655790616000	canonical
20	3NLfL7Xw437KBEUFNX9H6KSpwrfYZvdSCCmYpdySkmnEFaxiQY6k	19	3NLiBVAhQZseXsJF7tf8ZUaiULPxxzX78b7EtcSUJEhYsGVnDNQ8	3	3	1	1	21	6	3100000000000000000	jx31XkD3t3fzKN2mx2ZgGgjmtsw7GSCx1xVXn7rmtjq9fKps2k3	19	104	104	1655790628000	canonical
21	3NL6XEvymsnMsBRRDHnALUYzJAdfNNGhVpSn7CYe9DVcXU598Qjq	20	3NLfL7Xw437KBEUFNX9H6KSpwrfYZvdSCCmYpdySkmnEFaxiQY6k	3	3	1	1	22	6	3100000000000000000	jxFE3sqjkyHVcp7dyN9erVwdCUkMHqEWGsb9f6D6dcwVMfwYxdC	20	106	106	1655790632000	canonical
22	3NKUZpvXM4TgLmR6HGWX1FzbdQR7QRu9ZAs8skdGmu4QtnnKE73R	21	3NL6XEvymsnMsBRRDHnALUYzJAdfNNGhVpSn7CYe9DVcXU598Qjq	3	3	1	1	23	6	3100000000000000000	jwqbRpjvxvVUr7cZheCsazCm2cKUz18AKQuoKiYcv3CWopd5oh2	21	108	108	1655790636000	canonical
23	3NKXyw2yCSnqHTpo32WQN8YzSPobjgJ7gXbAPiuKbDp6bRqpE2hR	22	3NKUZpvXM4TgLmR6HGWX1FzbdQR7QRu9ZAs8skdGmu4QtnnKE73R	3	3	1	1	24	6	3100000000000000000	jwM4dXyqa5b1QX6N7QvLMVjoFYSkJg3NBxx5PPVpFP5eiuac4Yn	22	109	109	1655790638000	canonical
24	3NLi7YK7Wiyr5rj26jnzesw6Bh4j12foEBFHzHQxZaXgUatRfU1m	23	3NKXyw2yCSnqHTpo32WQN8YzSPobjgJ7gXbAPiuKbDp6bRqpE2hR	3	3	1	1	25	6	3100000000000000000	jwM4dXyqa5b1QX6N7QvLMVjoFYSkJg3NBxx5PPVpFP5eiuac4Yn	23	111	111	1655790642000	canonical
25	3NLnKryfAFSQ3ouShgGkTb8DDbRo5FgRfxPmzBPYTKoTr5Q8HY1D	24	3NLi7YK7Wiyr5rj26jnzesw6Bh4j12foEBFHzHQxZaXgUatRfU1m	3	3	2	1	26	6	3099999990000000000	jxYf9KhF6LzLGyz3SSLeEcHTzRNDjpKGoq11GJVGrJAf5HpMSr4	24	115	115	1655790650000	canonical
26	3NKAgQusAAyHqJfRQx9gYdD1EFitp6WfC3aRWq6Y76PmLpUZn6PP	25	3NLnKryfAFSQ3ouShgGkTb8DDbRo5FgRfxPmzBPYTKoTr5Q8HY1D	3	3	2	1	27	6	3099999990000000000	jxY3DMZpjN1eiKrF57TsCkjrnNCoYYu6gB6rde2eJ4ZDvUZBSLG	25	118	118	1655790656000	canonical
27	3NKL3KTq6kqgERsu8LKBxnFvs2jxGJPRBXZXdAiamF1JGprM9wkk	26	3NKAgQusAAyHqJfRQx9gYdD1EFitp6WfC3aRWq6Y76PmLpUZn6PP	3	3	2	1	28	6	3099999990000000000	jxDomvKT7XxTJ2HCi6dkVYsrvSQiQJRtdx9e9WQ69YfkSWBGYTh	26	119	119	1655790658000	canonical
28	3NKzuB8axHmg4ptFUdYQtDRxoR99heqnuMBA7Dk4rmQkczKmgiNF	27	3NKL3KTq6kqgERsu8LKBxnFvs2jxGJPRBXZXdAiamF1JGprM9wkk	3	3	3	1	29	6	3099999975000000000	jxDomvKT7XxTJ2HCi6dkVYsrvSQiQJRtdx9e9WQ69YfkSWBGYTh	27	120	120	1655790660000	canonical
2	3NLXYfmuCn2rvpFHNyhTY15QKP5RE6CqbWqfEfsxZPcHGsjwkhXH	\N	3NKNSRrnpkVFny3qojaH3CkX6kSi8b6mKs42veKrBbrpeLZibgMo	1	1	1	1	3	6	3100000000000000000	jxAm6uC7mNHDE1riiRhSLkFcXB8yWJm9BGQ22iFn68rSjHW4Gwb	1	0	0	1655790420000	canonical
1	3NKPn7XcufwtiePu3ygMRmWeMoHGmNkwvTwQZnbHtR3sbeZLTgsE	\N	3NKuUmRgF8gbewNX7ZqwFyBtCz1kGYMtRXwwuMy2bxjCKMUxJhpj	1	1	1	1	2	6	3100000000000000000	jxAm6uC7mNHDE1riiRhSLkFcXB8yWJm9BGQ22iFn68rSjHW4Gwb	1	0	0	1655790360000	orphaned
3	3NKVovdAdj2BTwXiJzvLCqSpPuu2MutZnBHN5vHBuJPSfMm3biRv	2	3NLXYfmuCn2rvpFHNyhTY15QKP5RE6CqbWqfEfsxZPcHGsjwkhXH	3	3	1	1	4	6	3100000000000000000	jxAm6uC7mNHDE1riiRhSLkFcXB8yWJm9BGQ22iFn68rSjHW4Gwb	2	65	65	1655790550000	canonical
29	3NKAmhYCZiGA9quFGzazuWvqPnk22bLoxHbj3XmuxnmZkeeEf6HD	28	3NKzuB8axHmg4ptFUdYQtDRxoR99heqnuMBA7Dk4rmQkczKmgiNF	3	3	3	1	30	6	3099999975000000000	jwhgxtQ9u8ZgAxKyiWCgJSVZbrEJoQyiybWPvZWe3ERk2p5G9xe	28	123	123	1655790666000	canonical
31	3NKxU1ZS74vz2tu64U77vLfBiYYmCtxTz5z2g1Ue2qpRJeXVUh2h	30	3NKBnsTr7LnGS3cHwqEoec5MjyNxAsGKEx9JDrv93mpYBydvynJc	3	3	3	1	32	6	3099999975000000000	jwDkLsbxhrUVvkV2ZQK34pFAqLLyyFcS5CZSvW4wyy7EqGJY4d1	30	126	126	1655790672000	canonical
33	3NKYKFHXvK7za1Mdn2TXdwW8dNujK4QWocouDgLKNAribmSfLZaY	32	3NLaKZh74eJSShNo66wExJf84qaoaMre8SebZDqK3vaCBQ6FSisn	3	3	5	1	34	6	3099999935000000000	jwhBffzY1Nv3VPXm3kEisfDm3yomtdrephXkbC4cN7kDpsAVuds	32	132	132	1655790684000	canonical
35	3NLJcyoSaBqRvCXjfeha8TNvEbcQ9uENgs92AWYV8vsuQzJNUcDB	34	3NKdvytV1F8s8shCjLHkf4AKr5hV4pc7koa5G9hEJg3yCki9bEzT	3	3	6	1	36	6	3099999915000000000	jw9GtM6fmn1KcDCJKkxbXxRFGcKwPKrCX9FmcES44fRskVdYLJs	34	140	140	1655790700000	canonical
37	3NKsQkqyuQxBaajpQ22JVs6MKAnmbHj6Frcuc9SLWEwixR44z8HU	36	3NK3gpR43H7ux9ouuXNbvGzpYeWaQ1LuAg6FjDVAxSqq2vghFvTm	3	3	6	1	38	6	3099999915000000000	jw9GtM6fmn1KcDCJKkxbXxRFGcKwPKrCX9FmcES44fRskVdYLJs	36	142	142	1655790704000	canonical
39	3NKowcs35em2VY3JAXWgVqg5ZmMnBTj7AEvwAAby44znD7FzERF6	38	3NKYcgWLXNaWo2EBiMdv6dmae9gToWEAkKDBCm8URBshAEzkMHGL	3	3	7	1	40	6	3099999900000000000	jwNn2gnKZw6kFf49xXQAH494LJ8H5uBDmRQtbrLbAM1U23Aqm5n	38	147	147	1655790714000	canonical
12	3NKy5jA6rXAkcpt9YFoeGtkgbmQjAfRfZXZPxXzgMeF3kWHtt5mp	11	3NLGLJqs3QxzKXeHpUBweRsqBEPH8989JbKkGgfbYUuZbhx45vBb	3	3	1	1	13	6	3100000000000000000	jwPrJaiR6bEetVXUPtUHN3uxQx1cwaLkqT3wsuiFC9gYWjMXJsz	11	82	82	1655790584000	canonical
40	3NLDc3xTSccMgBE4HLR1wxGrn2Qfu9rdLtrUf45jZhVjoMtJDAcA	39	3NKowcs35em2VY3JAXWgVqg5ZmMnBTj7AEvwAAby44znD7FzERF6	3	3	8	1	41	6	3099999875000000000	jwEpQVVo65Ypptd18j3bE9kW8LPnHaXP2hs4uT2X8DbmrohXiec	39	156	156	1655790732000	pending
41	3NKfEzBTVMFvt8Ans5waZreaKdWPwopQGdYmEPXbkEYLYKQxq8a3	40	3NLDc3xTSccMgBE4HLR1wxGrn2Qfu9rdLtrUf45jZhVjoMtJDAcA	3	3	8	1	42	6	3099999875000000000	jxx1CbfQbPFVThGmfVfs2bjheZQGCmhjFt1tke8iWWf9E9zEzNM	40	158	158	1655790736000	pending
42	3NL52mQdiSUmv8rpCpgk5AGp6pf3gRL26tDuBCAL8YCnSiJBaLnW	41	3NKfEzBTVMFvt8Ans5waZreaKdWPwopQGdYmEPXbkEYLYKQxq8a3	3	3	9	1	43	6	3099999865000000000	jwWhvbPfacar7crMRUX6k6MoMPkmy5PyrtGHu19Xyzn1vkqxmCc	41	160	160	1655790740000	pending
43	3NKBgatvDnQtQvjjvFMNJmVeK811rB4dAqxbu1x5A4trM9LgWYs2	42	3NL52mQdiSUmv8rpCpgk5AGp6pf3gRL26tDuBCAL8YCnSiJBaLnW	3	3	9	1	44	6	3099999865000000000	jwWhvbPfacar7crMRUX6k6MoMPkmy5PyrtGHu19Xyzn1vkqxmCc	42	163	163	1655790746000	pending
44	3NKj8XB5h638uiZfzkdQVvEwci4sLSwLmTRSKUbKqz8LzY9bQRDL	43	3NKBgatvDnQtQvjjvFMNJmVeK811rB4dAqxbu1x5A4trM9LgWYs2	3	3	9	1	45	6	3099999865000000000	jwWhvbPfacar7crMRUX6k6MoMPkmy5PyrtGHu19Xyzn1vkqxmCc	43	164	164	1655790748000	pending
45	3NLBevLMvc69VXxdXofaURApd6rq2n4YPikMGC3d1cLXQ5rfqFn9	44	3NKj8XB5h638uiZfzkdQVvEwci4sLSwLmTRSKUbKqz8LzY9bQRDL	3	3	10	1	46	6	3099999840000000000	jwg83bU1W5TXW9kC7P5cAEMTihxRA3LGyjnNikZLXY4QgExwV6b	44	169	169	1655790758000	pending
46	3NLnbMPRY6DjCiXJjvLc6RgSLYchBVsavq7rXQSNi65sQuX2xCvb	45	3NLBevLMvc69VXxdXofaURApd6rq2n4YPikMGC3d1cLXQ5rfqFn9	3	3	10	1	47	6	3099999840000000000	jxAGzViB7dWNGpptiqfjBGxgvfX3hUd2e3sfN3H97yZy2RCNwpF	45	172	172	1655790764000	pending
47	3NKvagwdWyPNUd6b9x82j4FLCyzJfYS7jsfQGfrRSdGeDu6QYGPt	46	3NLnbMPRY6DjCiXJjvLc6RgSLYchBVsavq7rXQSNi65sQuX2xCvb	3	3	10	1	48	6	3099999840000000000	jwtjS1qN4CvpJPZEFK3kD9b4e1EMAh3ZPH4CCdL6m7gDYmaZeu4	46	173	173	1655790766000	pending
48	3NLXn6YNUHPje9pGkuiocPbZEaRuqipnJop7C4XgTNqavTpeg56U	47	3NKvagwdWyPNUd6b9x82j4FLCyzJfYS7jsfQGfrRSdGeDu6QYGPt	3	3	11	1	49	6	3099999825000000000	jxKHvHUXMHArY5vbXnj33iCQemrqjCAwEwZojpsrSUtj387Mzu4	47	174	174	1655790768000	pending
49	3NKsPRQGyiS8xX4Q6ciCpWhRrC4NRn3u6nkifrUsTewotWYypxmm	48	3NLXn6YNUHPje9pGkuiocPbZEaRuqipnJop7C4XgTNqavTpeg56U	3	3	11	1	50	6	3099999825000000000	jxKHvHUXMHArY5vbXnj33iCQemrqjCAwEwZojpsrSUtj387Mzu4	48	177	177	1655790774000	pending
50	3NKAg3c3A6kqWeMxwCySDmcs3wRv786V6hGD9pphyVFj1nw9ngYb	49	3NKsPRQGyiS8xX4Q6ciCpWhRrC4NRn3u6nkifrUsTewotWYypxmm	3	3	12	1	51	6	3099999810000000000	jwuFU72b4YpqUz1kJrn3sFKrEwFaRbRAw9FU8SwtUPuqmYQZhQT	49	178	178	1655790776000	pending
51	3NKFETN8gVHHFnZDhCMBpmT44snkgXC2u9nD3ckQ5oPonkfruuDV	50	3NKAg3c3A6kqWeMxwCySDmcs3wRv786V6hGD9pphyVFj1nw9ngYb	3	3	12	1	52	6	3099999810000000000	jwBHoKmxc1vK9iiypLWxWjHMEy41zxVVMn7Y6EuScFykcGUbWAt	50	181	181	1655790782000	pending
52	3NKX4Pm777ZSLrbJQWmR5GVhexv7Jzuv9LvkZDoCEWwxQ4xqM62P	51	3NKFETN8gVHHFnZDhCMBpmT44snkgXC2u9nD3ckQ5oPonkfruuDV	3	3	13	1	53	6	3099999795000000000	jwAMRUKBt32AcVWLsVwZRfphABpN2uzFzv9Ssdr4xzUgVVMQrSm	51	184	184	1655790788000	pending
53	3NKNMYuk2j3DhQqNRbrq4FXf7SQSrkcAW5vcsfSgAGUUDiQuXn1u	52	3NKX4Pm777ZSLrbJQWmR5GVhexv7Jzuv9LvkZDoCEWwxQ4xqM62P	3	3	13	1	54	6	3099999795000000000	jwdxwiUoG85ZihtgngYFaTkSWjgpnqM4cxbPZpfuV6Cq7sGMyFp	52	186	186	1655790792000	pending
54	3NLVi4o6oY4gnbBVduScZsDUpX9q93PMkEFaWkKy8z2rGCPcBAzE	53	3NKNMYuk2j3DhQqNRbrq4FXf7SQSrkcAW5vcsfSgAGUUDiQuXn1u	3	3	13	1	55	6	3099999795000000000	jwdxwiUoG85ZihtgngYFaTkSWjgpnqM4cxbPZpfuV6Cq7sGMyFp	53	187	187	1655790794000	pending
55	3NKkJHuArc9txMJo8XW1diHdAwEZQBC6YZAV8vLrnv73HtscRfRk	54	3NLVi4o6oY4gnbBVduScZsDUpX9q93PMkEFaWkKy8z2rGCPcBAzE	3	3	14	1	56	6	3099999770000000000	jx4UGEBNkTfjYpVVq14q6gSWyP8bjbNWdL77sQmgwazYzGhE9on	54	193	193	1655790806000	pending
30	3NKBnsTr7LnGS3cHwqEoec5MjyNxAsGKEx9JDrv93mpYBydvynJc	29	3NKAmhYCZiGA9quFGzazuWvqPnk22bLoxHbj3XmuxnmZkeeEf6HD	3	3	3	1	31	6	3099999975000000000	jwDkLsbxhrUVvkV2ZQK34pFAqLLyyFcS5CZSvW4wyy7EqGJY4d1	29	124	124	1655790668000	canonical
56	3NKxyz4NttpigbANzussxAXbWeAyjy5u77Bt6UfFb3kEi4HWCV7g	55	3NKkJHuArc9txMJo8XW1diHdAwEZQBC6YZAV8vLrnv73HtscRfRk	3	3	14	1	57	6	3099999770000000000	jxV8MMoAJsaduMzECJzXiCWUkvbLSTLYuohoJ8R9UJ2wpwqVTAL	55	196	196	1655790812000	pending
57	3NL3onn5Ds6EEvLgqvvMndynAcDgB2FDiE3ty344s4aj3ueQUDpT	56	3NKxyz4NttpigbANzussxAXbWeAyjy5u77Bt6UfFb3kEi4HWCV7g	3	3	15	1	58	6	3099999750000000000	jxEpdsT54jS1e9dY2NJ1rfn6HkCg5Nmw9TewAMsrYHbvfKj7TVd	56	199	199	1655790818000	pending
32	3NLaKZh74eJSShNo66wExJf84qaoaMre8SebZDqK3vaCBQ6FSisn	31	3NKxU1ZS74vz2tu64U77vLfBiYYmCtxTz5z2g1Ue2qpRJeXVUh2h	3	3	4	1	33	6	3099999950000000000	jxHvbRUUW5aJzSy2FWLp8pPGgHpGS2nvV3cHpdFqFAHndfRWa7h	31	130	130	1655790680000	canonical
58	3NLWoovxKTp7vcTJLiQMDx4EwGGPbcMT33cLTd6QEpTx5o4tJ8Uv	57	3NL3onn5Ds6EEvLgqvvMndynAcDgB2FDiE3ty344s4aj3ueQUDpT	3	3	15	1	59	6	3099999750000000000	jxEpdsT54jS1e9dY2NJ1rfn6HkCg5Nmw9TewAMsrYHbvfKj7TVd	57	203	203	1655790826000	pending
59	3NKJiCEx4Uh8bkM4SwdvryYXqGBthhuQWNFyNtBuXqSoPxXTq4Y9	58	3NLWoovxKTp7vcTJLiQMDx4EwGGPbcMT33cLTd6QEpTx5o4tJ8Uv	3	3	15	1	60	6	3099999750000000000	jxEpdsT54jS1e9dY2NJ1rfn6HkCg5Nmw9TewAMsrYHbvfKj7TVd	58	204	204	1655790828000	pending
34	3NKdvytV1F8s8shCjLHkf4AKr5hV4pc7koa5G9hEJg3yCki9bEzT	33	3NKYKFHXvK7za1Mdn2TXdwW8dNujK4QWocouDgLKNAribmSfLZaY	3	3	5	1	35	6	3099999935000000000	jwhBffzY1Nv3VPXm3kEisfDm3yomtdrephXkbC4cN7kDpsAVuds	33	139	139	1655790698000	canonical
60	3NK5n8jCv1rkfMMrpRcpdD8oR6dyg77k2otVZR4m8a8RKx1USSjv	59	3NKJiCEx4Uh8bkM4SwdvryYXqGBthhuQWNFyNtBuXqSoPxXTq4Y9	3	3	15	1	61	6	3099999750000000000	jxEpdsT54jS1e9dY2NJ1rfn6HkCg5Nmw9TewAMsrYHbvfKj7TVd	59	205	205	1655790830000	pending
61	3NLssdYxbbMi9sP5NwRbKdLRHuE8NpEkLnGQmgjSEs4Bfr34naox	60	3NK5n8jCv1rkfMMrpRcpdD8oR6dyg77k2otVZR4m8a8RKx1USSjv	3	3	15	1	62	6	3099999750000000000	jxEpdsT54jS1e9dY2NJ1rfn6HkCg5Nmw9TewAMsrYHbvfKj7TVd	60	206	206	1655790832000	pending
63	3NKUWoVRqhmpWrVJmJeSDsJnf5xCSkbenSyrj7RKsqm47qy3G8Jf	62	3NKgzHmGNdSzgDqHJv1q6RN7efRzTUj2kbJp3rk56M6hcnbJdYZw	3	3	15	1	64	6	3099999750000000000	jxEpdsT54jS1e9dY2NJ1rfn6HkCg5Nmw9TewAMsrYHbvfKj7TVd	62	211	211	1655790842000	pending
36	3NK3gpR43H7ux9ouuXNbvGzpYeWaQ1LuAg6FjDVAxSqq2vghFvTm	35	3NLJcyoSaBqRvCXjfeha8TNvEbcQ9uENgs92AWYV8vsuQzJNUcDB	3	3	6	1	37	6	3099999915000000000	jw9GtM6fmn1KcDCJKkxbXxRFGcKwPKrCX9FmcES44fRskVdYLJs	35	141	141	1655790702000	canonical
62	3NKgzHmGNdSzgDqHJv1q6RN7efRzTUj2kbJp3rk56M6hcnbJdYZw	61	3NLssdYxbbMi9sP5NwRbKdLRHuE8NpEkLnGQmgjSEs4Bfr34naox	3	3	15	1	63	6	3099999750000000000	jxEpdsT54jS1e9dY2NJ1rfn6HkCg5Nmw9TewAMsrYHbvfKj7TVd	61	209	209	1655790838000	pending
38	3NKYcgWLXNaWo2EBiMdv6dmae9gToWEAkKDBCm8URBshAEzkMHGL	37	3NKsQkqyuQxBaajpQ22JVs6MKAnmbHj6Frcuc9SLWEwixR44z8HU	3	3	6	1	39	6	3099999915000000000	jw9GtM6fmn1KcDCJKkxbXxRFGcKwPKrCX9FmcES44fRskVdYLJs	37	145	145	1655790710000	canonical
\.


--
-- Data for Name: blocks_internal_commands; Type: TABLE DATA; Schema: public; Owner: o1labs
--

COPY public.blocks_internal_commands (block_id, internal_command_id, sequence_no, secondary_sequence_no, status, failure_reason) FROM stdin;
3	1	0	0	failed	Update_not_permitted_balance
4	1	1	0	failed	Update_not_permitted_balance
4	2	2	0	failed	Update_not_permitted_balance
5	1	1	0	failed	Update_not_permitted_balance
5	2	2	0	failed	Update_not_permitted_balance
6	1	0	0	failed	Update_not_permitted_balance
7	1	2	0	failed	Update_not_permitted_balance
7	3	3	0	failed	Update_not_permitted_balance
8	1	1	0	failed	Update_not_permitted_balance
8	2	2	0	failed	Update_not_permitted_balance
9	1	0	0	failed	Update_not_permitted_balance
10	4	3	0	failed	Update_not_permitted_balance
10	5	3	0	failed	Update_not_permitted_balance
10	6	4	0	failed	Update_not_permitted_balance
10	7	4	1	failed	Update_not_permitted_balance
11	3	2	0	failed	Update_not_permitted_balance
11	4	3	0	failed	Update_not_permitted_balance
11	5	3	0	failed	Update_not_permitted_balance
12	4	0	0	failed	Update_not_permitted_balance
12	5	0	0	failed	Update_not_permitted_balance
13	4	3	0	failed	Update_not_permitted_balance
13	5	3	0	failed	Update_not_permitted_balance
13	8	4	0	failed	Update_not_permitted_balance
13	9	4	1	failed	Update_not_permitted_balance
14	1	0	0	failed	Update_not_permitted_balance
15	4	3	0	failed	Update_not_permitted_balance
15	5	3	0	failed	Update_not_permitted_balance
15	3	4	0	failed	Update_not_permitted_balance
15	10	4	1	failed	Update_not_permitted_balance
16	1	1	0	failed	Update_not_permitted_balance
16	2	2	0	failed	Update_not_permitted_balance
17	4	2	0	failed	Update_not_permitted_balance
17	5	2	0	failed	Update_not_permitted_balance
17	2	3	0	failed	Update_not_permitted_balance
17	10	3	1	failed	Update_not_permitted_balance
18	1	0	0	failed	Update_not_permitted_balance
19	1	1	0	failed	Update_not_permitted_balance
19	2	2	0	failed	Update_not_permitted_balance
20	4	4	0	failed	Update_not_permitted_balance
20	5	4	0	failed	Update_not_permitted_balance
20	8	5	0	failed	Update_not_permitted_balance
20	11	5	1	failed	Update_not_permitted_balance
21	2	1	0	failed	Update_not_permitted_balance
21	4	2	0	failed	Update_not_permitted_balance
21	5	2	0	failed	Update_not_permitted_balance
22	4	1	0	failed	Update_not_permitted_balance
22	5	1	0	failed	Update_not_permitted_balance
22	10	2	0	failed	Update_not_permitted_balance
23	1	1	0	failed	Update_not_permitted_balance
23	2	2	0	failed	Update_not_permitted_balance
24	1	0	0	failed	Update_not_permitted_balance
25	4	3	0	failed	Update_not_permitted_balance
25	5	3	0	failed	Update_not_permitted_balance
25	12	4	0	failed	Update_not_permitted_balance
25	13	4	1	failed	Update_not_permitted_balance
26	3	2	0	failed	Update_not_permitted_balance
26	4	3	0	failed	Update_not_permitted_balance
26	5	3	0	failed	Update_not_permitted_balance
27	4	1	0	failed	Update_not_permitted_balance
27	5	1	0	failed	Update_not_permitted_balance
27	10	2	0	failed	Update_not_permitted_balance
28	4	0	0	failed	Update_not_permitted_balance
28	5	0	0	failed	Update_not_permitted_balance
29	3	2	0	failed	Update_not_permitted_balance
29	4	3	0	failed	Update_not_permitted_balance
29	5	3	0	failed	Update_not_permitted_balance
30	4	1	0	failed	Update_not_permitted_balance
30	5	1	0	failed	Update_not_permitted_balance
30	14	2	0	failed	Update_not_permitted_balance
30	7	2	1	failed	Update_not_permitted_balance
31	4	0	0	failed	Update_not_permitted_balance
31	5	0	0	failed	Update_not_permitted_balance
32	12	2	0	failed	Update_not_permitted_balance
32	15	2	1	failed	Update_not_permitted_balance
32	4	4	0	failed	Update_not_permitted_balance
32	5	4	0	failed	Update_not_permitted_balance
32	16	5	0	failed	Update_not_permitted_balance
32	17	5	1	failed	Update_not_permitted_balance
33	4	2	0	failed	Update_not_permitted_balance
33	5	2	0	failed	Update_not_permitted_balance
33	12	3	0	failed	Update_not_permitted_balance
33	15	3	1	failed	Update_not_permitted_balance
34	1	0	0	failed	Update_not_permitted_balance
35	4	5	0	failed	Update_not_permitted_balance
35	5	5	0	failed	Update_not_permitted_balance
35	18	6	0	failed	Update_not_permitted_balance
35	13	6	1	failed	Update_not_permitted_balance
36	1	0	0	failed	Update_not_permitted_balance
37	4	0	0	failed	Update_not_permitted_balance
37	5	0	0	failed	Update_not_permitted_balance
38	4	0	0	failed	Update_not_permitted_balance
38	5	0	0	failed	Update_not_permitted_balance
39	4	4	0	failed	Update_not_permitted_balance
39	5	4	0	failed	Update_not_permitted_balance
39	19	5	0	failed	Update_not_permitted_balance
39	10	5	1	failed	Update_not_permitted_balance
40	4	6	0	failed	Update_not_permitted_balance
40	5	6	0	failed	Update_not_permitted_balance
40	20	7	0	failed	Update_not_permitted_balance
40	13	7	1	failed	Update_not_permitted_balance
42	4	1	0	failed	Update_not_permitted_balance
42	5	1	0	failed	Update_not_permitted_balance
42	21	2	0	failed	Update_not_permitted_balance
42	9	2	1	failed	Update_not_permitted_balance
44	1	0	0	failed	Update_not_permitted_balance
46	2	1	0	failed	Update_not_permitted_balance
46	4	2	0	failed	Update_not_permitted_balance
46	5	2	0	failed	Update_not_permitted_balance
48	4	1	0	failed	Update_not_permitted_balance
48	5	1	0	failed	Update_not_permitted_balance
48	2	2	0	failed	Update_not_permitted_balance
50	4	2	0	failed	Update_not_permitted_balance
50	5	2	0	failed	Update_not_permitted_balance
50	23	3	0	failed	Update_not_permitted_balance
50	13	3	1	failed	Update_not_permitted_balance
41	4	1	0	failed	Update_not_permitted_balance
41	5	1	0	failed	Update_not_permitted_balance
41	10	2	0	failed	Update_not_permitted_balance
43	1	0	0	failed	Update_not_permitted_balance
45	4	4	0	failed	Update_not_permitted_balance
45	5	4	0	failed	Update_not_permitted_balance
45	22	5	0	failed	Update_not_permitted_balance
45	13	5	1	failed	Update_not_permitted_balance
47	4	1	0	failed	Update_not_permitted_balance
47	5	1	0	failed	Update_not_permitted_balance
47	10	2	0	failed	Update_not_permitted_balance
49	1	0	0	failed	Update_not_permitted_balance
51	1	2	0	failed	Update_not_permitted_balance
51	3	3	0	failed	Update_not_permitted_balance
52	4	2	0	failed	Update_not_permitted_balance
52	5	2	0	failed	Update_not_permitted_balance
52	23	3	0	failed	Update_not_permitted_balance
52	13	3	1	failed	Update_not_permitted_balance
53	1	1	0	failed	Update_not_permitted_balance
53	2	2	0	failed	Update_not_permitted_balance
54	1	0	0	failed	Update_not_permitted_balance
55	4	4	0	failed	Update_not_permitted_balance
55	5	4	0	failed	Update_not_permitted_balance
55	22	5	0	failed	Update_not_permitted_balance
55	13	5	1	failed	Update_not_permitted_balance
56	2	1	0	failed	Update_not_permitted_balance
56	4	3	0	failed	Update_not_permitted_balance
56	5	3	0	failed	Update_not_permitted_balance
56	10	4	0	failed	Update_not_permitted_balance
57	4	1	0	failed	Update_not_permitted_balance
57	5	1	0	failed	Update_not_permitted_balance
57	21	2	0	failed	Update_not_permitted_balance
57	9	2	1	failed	Update_not_permitted_balance
58	1	0	0	failed	Update_not_permitted_balance
59	1	0	0	failed	Update_not_permitted_balance
60	4	0	0	failed	Update_not_permitted_balance
60	5	0	0	failed	Update_not_permitted_balance
61	4	0	0	failed	Update_not_permitted_balance
61	5	0	0	failed	Update_not_permitted_balance
62	4	0	0	failed	Update_not_permitted_balance
62	5	0	0	failed	Update_not_permitted_balance
63	4	0	0	failed	Update_not_permitted_balance
63	5	0	0	failed	Update_not_permitted_balance
\.


--
-- Data for Name: blocks_user_commands; Type: TABLE DATA; Schema: public; Owner: o1labs
--

COPY public.blocks_user_commands (block_id, user_command_id, sequence_no, status, failure_reason) FROM stdin;
4	1	0	applied	\N
5	2	0	applied	\N
7	3	0	applied	\N
7	4	1	applied	\N
8	5	0	applied	\N
10	6	0	applied	\N
10	7	1	applied	\N
10	8	2	applied	\N
11	9	0	applied	\N
11	10	1	applied	\N
13	11	0	applied	\N
13	12	1	applied	\N
13	13	2	applied	\N
15	14	0	applied	\N
15	15	1	applied	\N
15	16	2	applied	\N
16	17	0	applied	\N
17	18	0	applied	\N
17	19	1	applied	\N
19	20	0	applied	\N
20	21	0	applied	\N
20	22	1	applied	\N
20	23	2	applied	\N
20	24	3	applied	\N
21	25	0	applied	\N
22	26	0	applied	\N
23	27	0	applied	\N
25	28	0	applied	\N
25	29	1	applied	\N
25	30	2	applied	\N
26	31	0	applied	\N
26	32	1	applied	\N
27	33	0	applied	\N
29	34	0	applied	\N
29	35	1	applied	\N
30	36	0	applied	\N
32	37	0	applied	\N
32	38	1	applied	\N
32	39	3	applied	\N
33	40	0	applied	\N
33	41	1	applied	\N
35	42	0	applied	\N
35	43	1	applied	\N
35	44	2	applied	\N
35	45	3	applied	\N
35	46	4	applied	\N
39	47	0	applied	\N
39	48	1	applied	\N
39	49	2	applied	\N
40	50	0	applied	\N
40	51	1	applied	\N
40	52	2	applied	\N
40	53	3	applied	\N
40	54	4	applied	\N
40	55	5	applied	\N
41	56	0	applied	\N
42	57	0	applied	\N
45	58	0	applied	\N
45	59	1	applied	\N
45	60	2	applied	\N
45	61	3	applied	\N
46	62	0	applied	\N
47	63	0	applied	\N
48	64	0	applied	\N
50	65	0	applied	\N
50	66	1	applied	\N
51	67	0	applied	\N
52	68	0	applied	\N
52	69	1	applied	\N
53	70	0	applied	\N
55	71	0	applied	\N
55	72	1	applied	\N
55	73	2	applied	\N
55	74	3	applied	\N
56	75	0	applied	\N
56	76	2	applied	\N
57	77	0	applied	\N
\.


--
-- Data for Name: blocks_zkapp_commands; Type: TABLE DATA; Schema: public; Owner: o1labs
--

COPY public.blocks_zkapp_commands (block_id, zkapp_command_id, sequence_no, status, failure_reasons_ids) FROM stdin;
39	1	3	applied	\N
51	2	1	applied	\N
\.


--
-- Data for Name: epoch_data; Type: TABLE DATA; Schema: public; Owner: o1labs
--

COPY public.epoch_data (id, seed, ledger_hash_id, total_currency, start_checkpoint, lock_checkpoint, epoch_length) FROM stdin;
1	2va9BGv9JrLTtrzZttiEMDYw1Zj6a6EHzXjmP9evHDTG3oEquURA	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	1
2	2vc1zQHJx2xN72vaR4YDH31KwFSr5WHSEH2dzcfcq8jxBPcGiJJA	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKuUmRgF8gbewNX7ZqwFyBtCz1kGYMtRXwwuMy2bxjCKMUxJhpj	2
3	2vc1zQHJx2xN72vaR4YDH31KwFSr5WHSEH2dzcfcq8jxBPcGiJJA	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKNSRrnpkVFny3qojaH3CkX6kSi8b6mKs42veKrBbrpeLZibgMo	2
4	2vbwJyLrptxzUgtdBEhq8tf7pRoxTeno8PC8GuWHvFRCzgXv3Lv7	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLXYfmuCn2rvpFHNyhTY15QKP5RE6CqbWqfEfsxZPcHGsjwkhXH	3
5	2vasxLskjrhBKQcuM2dAEyfPCAyC74U4jzCEvUCpMz9dNkXCBhaF	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKVovdAdj2BTwXiJzvLCqSpPuu2MutZnBHN5vHBuJPSfMm3biRv	4
6	2vbzJpzRZFDUMK83Sk5ZW3txxvz2RCXdHu66tASzUoNXWVPyQykc	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLDjLvtRLQno8uBh6YEsJQi7dXvMRejUXCpw47NihQvdNPbS98K	5
7	2vah4q6Z2vMMEMRVQWp63fioJsaLkswVsWgrtxcECnkm8fqeCv1P	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLkijnwBFRefzJeVhtb6dsbHiubpTTN5tmrBrcmpzjNtAFzQoSd	6
8	2vaKgVNmzLn2h3MPbmA1xrqWt4bqW6c2ZeZW2LLp6SRyFk8JMZ4Q	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLdWkbiGZYAcm7tFgoPxowrmgzxQsu65ns1uBtxWADrm8mrNePZ	7
9	2vbLx7528deLUsKkHrX2R8ZSEBDS2yVNwC6W5ntoJCF9nzfts5Fg	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKzqXxqqU4J1NacW7vQLjt5Xp5ocLswYRNuzDa8Uzk9N3hJLJTy	8
10	2vb3WUAcuWPc3Bs9urfD5g4j88tcyi8gcLiisFxYiHQeMCoG27dq	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKZMJh49ksivk9xDhQfgD38x5dbaUpQGQNLE8vDLTYobsWzjtmp	9
11	2vbTgRTT51ciw1Bh6k4ApP5VpARJqvfgyWFBKjXPF6QknoAdTV6g	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKbz2MZrxQuAbgsuoMeCujMvY3A8PwCmn8h16hCCmc7eKE5wnix	10
12	2vabEnxvXewt2KBFfFe9wqb18QUw4V5npsrJbwM3eMpRRw9NPeNG	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLF8J1KyTsqDHS5BNaCueH2zavRKoDGntWyVdZbv2Te3BFd7tCc	11
13	2vaHipQJgX2WuLg3Dakgdam9XEEf2Zg39GUaRLxCgqamYr3ubPrs	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLGLJqs3QxzKXeHpUBweRsqBEPH8989JbKkGgfbYUuZbhx45vBb	12
14	2vbHp5M7K2SvQJjDvMwcDifDwyGY37eZXP5W9dKdYHMRWVz62qRB	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKy5jA6rXAkcpt9YFoeGtkgbmQjAfRfZXZPxXzgMeF3kWHtt5mp	13
15	2vap92BrAhCPPoZPrMPyjMPx9Fn3QMN7XRejS21pEuxRFU9FbfVp	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKyhCcUwSn86CnMWcYysjuhdP6DUGSmFD3kd7j85YBTkLuQQxE3	14
16	2vbYH2LrvdbGuRmfB7QDxYRgpD8cBJqq5sFwH7nEoRBuRPtiscMN	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKizyBvJf1ydTTup7ncBCKFSsPWvPkKjvNhj5fMgfhWtKNExoyL	15
17	2vbYL87JdZpDXGCnvJucmAFQvk125uXDhe7h4dxw8nPAh9XVaqoA	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLvZwbYanPJcG3fbz5Tvfawg9Ui2dVN2wzkBPkSPMrkQE6sdQ3u	16
18	2vbyrRkC6Xochgtfijim61zkTMKHtZBiAEJZfnYYdpwRHmd9xaP7	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLaDqV3M9Mb4BYVUArvgTAEkFNB9pAQaxnavnGfWgDo4JPjcYRV	17
19	2vbGhfDPoMobXEMjMZmhWWjAWYh1MRxSeLAuZUSMubvbznjiDFze	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NL5eUZC3AWAhuqowjoHwodcsafnZtmdfd6U6BuxrTe5BotNMyT8	18
20	2vbK6d5soZeK1E4hpGpa3yP83s5mdxo61Qg3ZtdsW8wFrpZCcLYk	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NK9ovXze3B5U8XFsAuKwJEWh5n55cTWnPTyehmovHDwEcGZMdG4	19
21	2vbB9oMWAHxaSby6zfDK4gUWXLRCNWNM11Q9ADZxR84m94pQdmBB	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLiBVAhQZseXsJF7tf8ZUaiULPxxzX78b7EtcSUJEhYsGVnDNQ8	20
22	2vaR6GGj4cJ45dgpEvatcrbsdn5A3Sh8PF2CJTRuidQp8ZsAvPMx	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLfL7Xw437KBEUFNX9H6KSpwrfYZvdSCCmYpdySkmnEFaxiQY6k	21
23	2vadKRv58bdnuLzFhJi17csPm6B4o4TMx8dKb8NN3zpxs9rggRWY	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NL6XEvymsnMsBRRDHnALUYzJAdfNNGhVpSn7CYe9DVcXU598Qjq	22
24	2vaE1jAph9uni9fnNcAvTRrRjnALMF4uxqYunSVegHLVLEM9XfJh	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKUZpvXM4TgLmR6HGWX1FzbdQR7QRu9ZAs8skdGmu4QtnnKE73R	23
25	2vaBNuwApVVKJD5FCk4BUZYRDi4CBMvki2PawBuaSfq1md67arZG	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKXyw2yCSnqHTpo32WQN8YzSPobjgJ7gXbAPiuKbDp6bRqpE2hR	24
26	2vazefEnugvM8ykkiQR8X7CszqwGpgHabQ5tTzkAsaC6eR7Zcanc	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLi7YK7Wiyr5rj26jnzesw6Bh4j12foEBFHzHQxZaXgUatRfU1m	25
27	2vbkR8X62Np66YNxWzycpsNS6wLqV1d2MbTGUw3wZosp1kDUbkx5	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLnKryfAFSQ3ouShgGkTb8DDbRo5FgRfxPmzBPYTKoTr5Q8HY1D	26
28	2vb6M1Z24qYLu5BvzCywAetTdfsK476bNgxWpapnLkrQ2M3TrNYS	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKAgQusAAyHqJfRQx9gYdD1EFitp6WfC3aRWq6Y76PmLpUZn6PP	27
29	2vbYX6crXLt28jkA6E3nt2j1o856qPaZVSoNtGRNmVmFvEdyqiTh	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKL3KTq6kqgERsu8LKBxnFvs2jxGJPRBXZXdAiamF1JGprM9wkk	28
30	2vbHPZqL1mapQv3V6dHmuJeqadeYizMZFAzchiRkgDJwyWtPyQTF	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKzuB8axHmg4ptFUdYQtDRxoR99heqnuMBA7Dk4rmQkczKmgiNF	29
31	2vaP1dKbdTucAoMbhvrQPP3V4nLgsxmEdJJRvXMifx8PkZAbKuvP	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKAmhYCZiGA9quFGzazuWvqPnk22bLoxHbj3XmuxnmZkeeEf6HD	30
32	2vaUTZJvNf9THLN2Mdzts79fuEZrTytm74qi6DZHnMskQrzsfAVX	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKBnsTr7LnGS3cHwqEoec5MjyNxAsGKEx9JDrv93mpYBydvynJc	31
33	2vbQR14h7hVV7rRsWC4DRpKUHWxK6uDbvspVfmes71iYkjqKbQxK	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKxU1ZS74vz2tu64U77vLfBiYYmCtxTz5z2g1Ue2qpRJeXVUh2h	32
34	2vbXNH2kjjcZ43e8irwNAvoyPxeipLvRhBEE1stKroKZCxd21xno	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLaKZh74eJSShNo66wExJf84qaoaMre8SebZDqK3vaCBQ6FSisn	33
35	2vaWDHpTxNKvyowPgDiNTctonoc57pGm35iuNpT6vrzbqKL4xsjn	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKYKFHXvK7za1Mdn2TXdwW8dNujK4QWocouDgLKNAribmSfLZaY	34
36	2vbYq5Mvpcz3XPWAGZ1AC1wzpiaK44YiKGkbYEh39pEjHTnAVd4K	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKdvytV1F8s8shCjLHkf4AKr5hV4pc7koa5G9hEJg3yCki9bEzT	35
38	2vaCGQVinUGtgRa2mNszYsQqKF2xg4dtfrZDyEwYGYQchg184Akc	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NK3gpR43H7ux9ouuXNbvGzpYeWaQ1LuAg6FjDVAxSqq2vghFvTm	37
40	2vbPDyJgWunTspFmrf4sZc9U6XbEzxbExj9dfu5rkpUjiaiF9215	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKYcgWLXNaWo2EBiMdv6dmae9gToWEAkKDBCm8URBshAEzkMHGL	39
42	2vbTXtioQYNnzT4d1q3HT5st3XdgYbGGzxaPkMb4stwkEwZNvgBx	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLDc3xTSccMgBE4HLR1wxGrn2Qfu9rdLtrUf45jZhVjoMtJDAcA	41
44	2vbkx7yfJgmx7teis8cRSEKr73ibabVcgs68YTdUNnhraBkVTc2g	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NL52mQdiSUmv8rpCpgk5AGp6pf3gRL26tDuBCAL8YCnSiJBaLnW	43
46	2vc1XH594mL3qxjHyE2jZpiCAG9W5RkrfJpUDKUZ3y2nfCFfEdGr	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKj8XB5h638uiZfzkdQVvEwci4sLSwLmTRSKUbKqz8LzY9bQRDL	45
48	2vachFh4sdN5yY6Mqa3JxNHiDjCgdiXSTof1R5GBGZiMWmUFbZbm	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLnbMPRY6DjCiXJjvLc6RgSLYchBVsavq7rXQSNi65sQuX2xCvb	47
50	2vbJXym8HjJVhx4KFXcn1uH5DesZNsLad6WYnjp5frhKutEzPD5H	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLXn6YNUHPje9pGkuiocPbZEaRuqipnJop7C4XgTNqavTpeg56U	49
52	2vayxY9qd6zKfPGNitKJCYv7EQtUwY8JzPkTy3vcChbNYcYvHcLc	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKAg3c3A6kqWeMxwCySDmcs3wRv786V6hGD9pphyVFj1nw9ngYb	51
37	2vaxxNk4Wu32y3JYKNzho8PY3SYp5iyUiM3wT27TmfT31uoy7hXz	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLJcyoSaBqRvCXjfeha8TNvEbcQ9uENgs92AWYV8vsuQzJNUcDB	36
39	2vbxAXbfAvoabdtcLqmLpx1PQtrxaxakB8WN1o3QDHq81dQJK3s7	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKsQkqyuQxBaajpQ22JVs6MKAnmbHj6Frcuc9SLWEwixR44z8HU	38
41	2vaaRZYSpmFLYz7dPga1H2JYphVXPoYV1GRaj1qx1LPyLkbkuzFT	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKowcs35em2VY3JAXWgVqg5ZmMnBTj7AEvwAAby44znD7FzERF6	40
43	2vawpEBi38JHbZxbVoSjLUp9amGbPfnvZHgvBehT9FH76uWSERga	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKfEzBTVMFvt8Ans5waZreaKdWPwopQGdYmEPXbkEYLYKQxq8a3	42
45	2vaQ3c2nimvkuQrdw4gBtdNSvkydfcYBwDrKRoa39QeoR8VVX3a7	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKBgatvDnQtQvjjvFMNJmVeK811rB4dAqxbu1x5A4trM9LgWYs2	44
47	2vbcjx9gLubzuCdLowAm7V4cEboPzqvsoYyGSQKYnawdvHmjF4zX	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLBevLMvc69VXxdXofaURApd6rq2n4YPikMGC3d1cLXQ5rfqFn9	46
49	2vaiiuX9fBwxMxeJ1VgFjgbYsXMkUjqJPgexCCHwhF6rVpTYveiA	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKvagwdWyPNUd6b9x82j4FLCyzJfYS7jsfQGfrRSdGeDu6QYGPt	48
51	2vbKDd53jf98aP8HhutKM7erZhGJCLZGv8hypbkG1gACVd4CX9Sb	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKsPRQGyiS8xX4Q6ciCpWhRrC4NRn3u6nkifrUsTewotWYypxmm	50
53	2vbkCf9wQFiwEGTsXHJDcVSkMR4PrZ8LRBhgWgXLhXV2W263FLcw	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKFETN8gVHHFnZDhCMBpmT44snkgXC2u9nD3ckQ5oPonkfruuDV	52
54	2vb15Ag3ahZF7xVHZ2vHWcPJCqpaqdTeA9vencp7iu3NuuH4YmPL	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKX4Pm777ZSLrbJQWmR5GVhexv7Jzuv9LvkZDoCEWwxQ4xqM62P	53
55	2vbCUz8SS1hY9ps2ztwKiZ5kQdV69ArhGsrzJFkvuQgcAnNRegPb	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKNMYuk2j3DhQqNRbrq4FXf7SQSrkcAW5vcsfSgAGUUDiQuXn1u	54
56	2vaweQg8mx5jWoPQU4NtBn8jDtXvWDstBUffhaKjP2o4PkEihHYU	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLVi4o6oY4gnbBVduScZsDUpX9q93PMkEFaWkKy8z2rGCPcBAzE	55
57	2vbHE7RmwyVDXACRWuux8cc7L1wH3nJKkq88va2xiPcNNcmLeFzC	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKkJHuArc9txMJo8XW1diHdAwEZQBC6YZAV8vLrnv73HtscRfRk	56
58	2vbJD8Yiybw677APuKScQTTa6NiJ45zk9fybpYB8u7H8fN2JxaPh	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKxyz4NttpigbANzussxAXbWeAyjy5u77Bt6UfFb3kEi4HWCV7g	57
59	2vb68kdjfCMivXMq41jtnMvkJVFK2cror8rX5Anp3vvjNY428Qq5	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NL3onn5Ds6EEvLgqvvMndynAcDgB2FDiE3ty344s4aj3ueQUDpT	58
60	2var7ddzYTHD3Nd69C1uGkZ9CHrdX1cPkhyt7tQ979f167bZYiX5	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLWoovxKTp7vcTJLiQMDx4EwGGPbcMT33cLTd6QEpTx5o4tJ8Uv	59
61	2vbJLqcpSy1ED75Ux2GHsNBuCp4vuWTsavPyqfBjAPZjiwTbJMX4	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKJiCEx4Uh8bkM4SwdvryYXqGBthhuQWNFyNtBuXqSoPxXTq4Y9	60
62	2vbuH1hP7Zp8qd6nWmRmN6HoNDRgXj6t7j6NwwX7ZAvuBhk3rRSU	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NK5n8jCv1rkfMMrpRcpdD8oR6dyg77k2otVZR4m8a8RKx1USSjv	61
63	2va9WN4fURhxEEaz6CWLoADfATSi6bTQMuaZbktEd6QkZXUkynnd	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLssdYxbbMi9sP5NwRbKdLRHuE8NpEkLnGQmgjSEs4Bfr34naox	62
64	2vbKaj1RQSeEKS8qva5kECq4SVY5UnTx5pUinewXchbYiS4GbcgY	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKgzHmGNdSzgDqHJv1q6RN7efRzTUj2kbJp3rk56M6hcnbJdYZw	63
\.


--
-- Data for Name: internal_commands; Type: TABLE DATA; Schema: public; Owner: o1labs
--

COPY public.internal_commands (id, typ, receiver_id, fee, hash) FROM stdin;
1	coinbase	2	40000000000	CkpaChkGmAbXvA2o7ZNa7WZGUo3CibNfJJE9KxWp9kQX3rHT87Esq
2	fee_transfer	2	5000000000	CkpaF3sf9zfCkXY68ZVqct7SgXVYkFxjBUJGwsUAmUXUUYRxn3GGE
3	fee_transfer	2	10000000000	Ckpa2ciXbaC2LnM5Yo85jbkefXQia8UGSF6uqGGGqMwDDbr2q76yW
4	fee_transfer_via_coinbase	4	1000000000	CkpZ4n4cJs4ey68tpfajw8jQeSTeqvkAPG5DjLjDvyU76rWxY4RiE
5	coinbase	2	40000000000	CkpYj73JZsYJfGLA4stxDPeGEANMFAXABfJ8qu52hbYo1uxqm6Qmj
6	fee_transfer	2	12000000000	CkpYqsaYEU59rQvb95yP8FccPp5ox5gimLrrcHMAdyVTkdbgbjdj5
7	fee_transfer	4	3000000000	CkpZrE7rtFegZpGhfoBtwAN5BHymhj82bLPWp3jLtXYXADzDZA5zL
8	fee_transfer	2	14000000000	CkpZoVF6Pb7KfoiwRR2LRq1xGrYkvUbErwRQHoUoMpZ26GPRVLJMG
9	fee_transfer	4	1000000000	CkpZ4n4cJs4ey68tpfajw8jQeSTeqvkAPG5DjLjDvyU76rWxY4RiE
10	fee_transfer	4	5000000000	Ckpa1QKtD7uUB5oebtfcaPmpAMBQE13oz7Nj5fF2wdPf8AA5jQaNS
11	fee_transfer	4	6000000000	CkpaEKhJtfdiPVkUA9BJemweLk8QKZTmfG2B9aqiFeHdMBhUf6tf3
12	fee_transfer	2	8000000000	CkpYiPxesv6DDBUGAvaR6baCBTQnK95Vy5XmcTRR2VbT6Sc5t4GtY
13	fee_transfer	4	7000000000	CkpYxLgrcmTGFz94jH9uvG5mJVpP9whkvdnXGtrqPqZgkZuHM43Pi
14	fee_transfer	2	2000000000	CkpYzaiV79cUH5bbrJZbYLSrj1cjaeHEzr29CaL4G5jVB5RRMP5Na
15	fee_transfer	4	2000000000	CkpZyLJgnS3xxoD2rvfZRE4zB8djvo3mrzJdgesSjPuuAA2nCoQYR
16	fee_transfer	2	1000000000	CkpZci5cV8Nf75uqQjMRja3yPj79oDFmqef5i9UquUe9KKux4uf7R
17	fee_transfer	4	4000000000	CkpaAeQXeCc4p6JzQr2fNzkTjRJEUBBZFnxc8zUpdXUtmCR6ihyxk
18	fee_transfer	2	18000000000	CkpYrzSDbHUWA4tx926HqX7RGGpikrbFoJ6aJEcenTyauRcusLw83
19	fee_transfer	2	15000000000	CkpZQuKKhfUHWQ8YvpMarTWSBNJubADyM2cTgRjeV72YHmApSLQqo
20	fee_transfer	2	23000000000	CkpZbNECVr2PxQGt9iamoQdGnXs2hUXig9nWFBgAL6ezSbFMmdhiR
21	fee_transfer	2	4000000000	CkpZ8cqtiYf5AJcuUj9q7mLgjnUYhdHozNYVfycEEWZkQVtm9vHqd
22	fee_transfer	2	13000000000	CkpZWTxaxoermAZEvEaxZ1WyCRGMNL1WiJjwAHLsiCLojgN7Z4adc
23	fee_transfer	2	3000000000	CkpZpNgFB1TCMgpVhshE4SJhcyZETkdBfCQxmx8ctBv3htLasb5Uq
\.


--
-- Data for Name: public_keys; Type: TABLE DATA; Schema: public; Owner: o1labs
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
-- Data for Name: snarked_ledger_hashes; Type: TABLE DATA; Schema: public; Owner: o1labs
--

COPY public.snarked_ledger_hashes (id, value) FROM stdin;
1	jxAm6uC7mNHDE1riiRhSLkFcXB8yWJm9BGQ22iFn68rSjHW4Gwb
2	jxiv8LUzFmQPVwRzv3Uv4oM2u3KpEnW7jpuE6BWSrrQPBXEMtJf
3	jwM1ddu7XKYQYpTzPWGGdaMXZVgptjQ2Fwg4JUTtxHTpptTPdUe
4	jwPrJaiR6bEetVXUPtUHN3uxQx1cwaLkqT3wsuiFC9gYWjMXJsz
5	jwjyCrh5ihAbg2vnv6hb7re6eQfn4nJLJ6ZHzrha8nv7u7mRCKb
6	jwpEaZSugL1FaqFubu1vEfoFqDtR6SUu6aaCAbVmZGRS7SzEEvd
7	jxyRvPgt2h9fcQWLo6xJawJtkefXc7aVS8b28mWQmY7DgyrzBW6
8	jxFE3sqjkyHVcp7dyN9erVwdCUkMHqEWGsb9f6D6dcwVMfwYxdC
9	jwM4dXyqa5b1QX6N7QvLMVjoFYSkJg3NBxx5PPVpFP5eiuac4Yn
10	jxY3DMZpjN1eiKrF57TsCkjrnNCoYYu6gB6rde2eJ4ZDvUZBSLG
11	jwhgxtQ9u8ZgAxKyiWCgJSVZbrEJoQyiybWPvZWe3ERk2p5G9xe
12	jxHybkSRqw7EZhH61GG87ahyiDZipXBsxQQbXMiFVijwJY6RAiv
13	jwhBffzY1Nv3VPXm3kEisfDm3yomtdrephXkbC4cN7kDpsAVuds
14	jw9GtM6fmn1KcDCJKkxbXxRFGcKwPKrCX9FmcES44fRskVdYLJs
15	jwNn2gnKZw6kFf49xXQAH494LJ8H5uBDmRQtbrLbAM1U23Aqm5n
\.


--
-- Data for Name: timing_info; Type: TABLE DATA; Schema: public; Owner: o1labs
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
-- Data for Name: token_symbols; Type: TABLE DATA; Schema: public; Owner: o1labs
--

COPY public.token_symbols (id, value) FROM stdin;
1	
\.


--
-- Data for Name: tokens; Type: TABLE DATA; Schema: public; Owner: o1labs
--

COPY public.tokens (id, value, owner_public_key_id, owner_token_id) FROM stdin;
1	wSHV2S4qX9jFsLjQo8r1BsMLH2ZRKsZx6EJd1sbozGPieEC4Jf	\N	\N
\.


--
-- Data for Name: user_commands; Type: TABLE DATA; Schema: public; Owner: o1labs
--

COPY public.user_commands (id, typ, fee_payer_id, source_id, receiver_id, nonce, amount, fee, valid_until, memo, hash) FROM stdin;
1	payment	2	2	1	30	1000000000	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	Ckpa4GL2ujiqVNQ45VnsG81CjXdv6q2opjYxgE5wmqFVphtXAViiJ
2	payment	2	2	1	31	1000000000	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZuQqvJefB341xnXGT8dJnwok5DeBhEEnAfxLUSXrk3UmhaU9zx
3	payment	2	2	1	32	1000000000	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZM89rC4FMsntDiVCrVgAqDfxXuMwM8Jjn1V7pTANpCLjeQv644
4	payment	2	2	1	33	1000000000	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYhmVZpms6DfNzyhmZGU8SQ4AdACdYhWsJNh5JVPVoUAASuhN9V
5	payment	2	2	1	34	1000000000	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYYwsCBEGrhajCyeLpt2KxSiEKuTCSSPiCLdu1GcnpLdLUutXA1
6	payment	2	2	1	35	1000000000	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZHWLNmmzHCGseThzysM1awFQxmMkfg8uivEsJabkXyBEczvvKh
7	payment	2	2	1	36	1000000000	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpaCqyESL1cCLN4TYFR12j31K3SVAUvigHoCdTGggg2NCMqdkEic
8	payment	2	2	1	37	1000000000	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZLL6bD36gUen6RWwzJL6Ga34CsT4fixZSwzK3kGyTBTX7wrDix
9	payment	2	2	1	38	1000000000	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpaCjxRgdYEW6T9EJU5qNKJCyPWmJToKRPKqPERyhKDbCYtwVDf4
10	payment	2	2	1	39	1000000000	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZ5gRT8HuqBCfEG35zfuew6yqXegtKXXuZYijW3x1C3bf7vRJ9N
11	payment	2	2	1	40	1000000000	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYqgbYtPK4PHj4k9BExHj5ZHgpsVD7BK3pUcpYSE8DjmiLDefER
12	payment	2	2	1	41	1000000000	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYtniQcjUs4osS6sccL4wTJyp5DuLCCCuf984w4BKjnurjNc3kM
13	payment	2	2	1	42	1000000000	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYaGEkV8mBtevwM8RXoWmrAn1YRssoM5FMgD6kNna1DmhutNssz
14	payment	2	2	1	43	1000000000	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYdY8wEYjZaieP6uABGSbJybjxmQhHBZ9eF47bPdRdnfg5ESqJS
15	payment	2	2	1	44	1000000000	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpaHtWoJKRCqu9GC83jvx5QtfqzsH8VyPHtV2dMkrFKnFPYBJg32
16	payment	2	2	1	45	1000000000	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYxMQ8FtqPPVz4uXvZDzqAh1L2VkWabwV4xZ7RrmrkNMdJQk4xR
17	payment	2	2	1	46	1000000000	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZJau7msEKGHpW1iFbp6bzvvx26d2QVwrFXYgsYXsB7vnreb4RD
18	payment	2	2	1	47	1000000000	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpaGeGvtk7Wov2vZxn1Xa8p22tYf51wLyHzwtaVmheLxY1DyFpCH
19	payment	2	2	1	48	1000000000	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	Ckpa9N3uwJnFxdsyJu4rztmykStrGa6p3CbfcA9XBegwUXJFwv9uT
20	payment	2	2	1	49	1000000000	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	Ckpa4VqMtkP1fzUjQegX9oF3AHtGBB1Z8gDavuxaAa6UhQRazHHmh
21	payment	2	2	1	50	1000000000	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZQCudFLFCF66HQNGcxe3SkBShqjJYkJSD3E7YunQsoDTsRG7TD
22	payment	2	2	1	51	1000000000	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZAPgo4PvgdoFtuFLu88eTKA33dQQw6pC2zFtZmomAfv6WRA1bq
23	payment	2	2	1	52	1000000000	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZpPTT8wAooqaBoy1KbrpqCXFqJXyT89kfZaJL6RiwDDJAQCWnN
24	payment	2	2	1	53	1000000000	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYtXmHMRU7Ar97k4MXXqsnrXxj3qzyLnp1cwYYtyj6t23V74k2S
25	payment	2	2	1	54	1000000000	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYytDCVuLsTudMXTyEeCaRaVhv32S3bMiMpdvyumqkSn1VnC7a5
26	payment	2	2	1	55	1000000000	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYrjSYvVb3aRmocxfXDV7H5W5o54Yc27mmcYoAupqh2jm98VAJX
27	payment	2	2	1	56	1000000000	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZXCe7wmuVv7qsL8ZvmJE9aATrttLWsfdN7Yd6uRqM5JUBULdpE
28	payment	2	2	1	57	1000000000	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZRGm5AzecJQ1a1tc43xAeaoqcMascMwWsr492TyVLzhV4XUvND
29	payment	2	2	1	58	1000000000	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYVGWmKWFmNuTyp5TbYS16U2X8Y2PmLSTTfjuhwP5iH35Brocgx
30	payment	2	2	1	59	1000000000	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYt2zJtM6JCCZwwGdNvJVR3raNd9NpwpjPL19aDrkxF7wkNxS4t
31	payment	2	2	1	60	1000000000	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpaFw5yjg7ZDuhtUyTxFWCrBTf6a73gc6vUCZ5AVm1ooQsVS2mkS
32	payment	2	2	1	61	1000000000	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYqvePFzmTkMGwZgGRmudG9EZLTcdH7BMpn3Usbrb3Wva7bMnXc
33	payment	2	2	1	62	1000000000	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZN1mxtVPoPc4FmEU9BdrnmXP95gcECHcLkyhaSsXMJvvi2o6ut
34	payment	2	2	1	63	1000000000	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZvFA2xehcuhoUzjMkHRmUEsixhbeLhiEUrk6CgWSi3wmnUBzvS
35	payment	2	2	1	64	1000000000	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZSbuzcVK9nMMGzv5BXUQa7RKF4sV4fpnwDoY8gXiJANiXahjcr
36	payment	2	2	1	65	1000000000	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	Ckpa4wgJEb5Yf6cMUrdyqR8LDYLrYLF5j8YSem6CuYNU22jqtMpn2
37	payment	2	2	1	66	1000000000	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYjxXPMbiA6XNNfgPmuTobspod5bTALvu7uyDSd2wY1PhRKxPBq
38	payment	2	2	1	67	1000000000	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	Ckpa4U74GiPQydP8Fqb9a6uWZc9nTVRChpX78FU5CUNNaXCbmC7eq
39	payment	2	2	1	68	1000000000	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYvsVtjqXjTc9qrfG2NM1dW2go3egC3wddjAFqSQywWLPoC9R5q
40	payment	2	2	1	69	1000000000	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZ5SbNBWvLnRYmFbpnez2FMo8vEWq8VR1Kr6tDxCuDt8WjhJ73E
41	payment	2	2	1	70	1000000000	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZUDYpoqRob9V1wA2A4Xoq5hufGXz2wadKKqXTRSQ6drKjS3CBo
42	payment	2	2	1	71	1000000000	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZqBcTJ4rB6vMS1mHxe7HrUB5C6KBycKuFqQYv114ahQTetPBQS
43	payment	2	2	1	72	1000000000	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYXkhvaTDHmy88qfBSUsK4bndPVUkz26LrrbZ6Tze452adwygf9
44	payment	2	2	1	73	1000000000	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYwyGTCDPDmd9ej13VeSGvMCBW1BWeXgExXDiTALN1n3LgVVcS9
45	payment	2	2	1	74	1000000000	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	Ckpa2YwqR1pkDHiYe6gbfrDtYntQrjo92Bw8GrpytZdvMLVn9zser
46	payment	2	2	1	75	1000000000	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	Ckpa9sDvJzx5fnQ2kKoXBRsZgu7wNTKjnv9V6JA7MsZRM9Q2RBjBt
47	payment	2	2	1	76	1000000000	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	Ckpa9dwb6ym7gcaJNqaUMrGiz4utv5tnhtk9VMu77ao15JXy2WkhK
48	payment	2	2	1	77	1000000000	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZ4CpkRiVaY1KoBk5VFcYBqjaCWQqz1uJAvrY9tYVSJBHwUBba2
49	payment	2	2	1	78	1000000000	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZLoLaZewBg4K6jLZrgBkvEDYV1fpFPNuW8P4LCgMcUuuvMmRsP
56	payment	2	2	1	85	1000000000	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYWDLcd9KGdeFdRRm6RcVmbZ8rRKC3KJPGMZpcrnqa9TEdNnyJN
58	payment	2	2	1	87	1000000000	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZ1SioS4numjSG4ifxjZcKGWK3qEMse4yuwxmXZV93esMtQn28Z
59	payment	2	2	1	88	1000000000	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYYEBJDUjp8iTBvrFtAbHbeeTH26anLSPytwDehMF8gqhU8CfRL
60	payment	2	2	1	89	1000000000	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpaHgSJWvQb82UZv4dbqBX6838X4tNB5fqvPnsuWmkdeoLkoMrwC
61	payment	2	2	1	90	1000000000	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpaFS1q5Rs4uR9488mnULvLDWxwnZszET4mvmtecNZpVpMP7xTC7
63	payment	2	2	1	92	1000000000	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZc5FZbKXmyVKCi7oPxKkevE2Sv38WrjFjxkXBEbguffvs8Tay2
67	payment	2	2	1	96	1000000000	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZaN48syWgdXQP1ntkt7RVxUkoGUCVFmyx3BRZA7zcXHwHNrsSw
50	payment	2	2	1	79	1000000000	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZy2KbGwwreG6VKa11zyfbWVRCKJUq6CcenDu4QS5NdeJQsmbci
51	payment	2	2	1	80	1000000000	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZtujRc7zgPif28xFJaMkx11S8UkvXHYNi37Di4f3gLvxi8x9Qn
52	payment	2	2	1	81	1000000000	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYRZUtRa23kHowA8LC7hhM4aNJqhKRVG9MuzM96CbNagSCkMZk8
53	payment	2	2	1	82	1000000000	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYbYH7V8wg8m9x2pW6qfiLPvvmcSSanDhrCWoFv8gYtijYcgtE8
54	payment	2	2	1	83	1000000000	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYhjYBwgbN1qxE1qzeNYx8xNZw7Z4NU1r4vQkEx1XkUMY15jyvn
55	payment	2	2	1	84	1000000000	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpaKYtRntAFLNJeX5mPFQTNyqoqFCs9gWfa3DjvFYCMMi7L1Ggw1
57	payment	2	2	1	86	1000000000	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	Ckpa8oPV3epWyq1bfifQbQV68ebjwyycbNH3S92tpuXUmnqqjsSnn
62	payment	2	2	1	91	1000000000	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZZMpdB1CRxbUqVscrfF2ajVQkQV9S8LnE5g6pGBLyiZokUSosU
64	payment	2	2	1	93	1000000000	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYg2f5XYSx2LC8RKWHDyjvRvK1zYYhKXAwppBLyXn8co24m86Wk
65	payment	2	2	1	94	1000000000	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZvAbsNTQXzW1qsmvMDwt2c7RmB1jrM29ZxfyLW5ydGLn6rU2Xp
66	payment	2	2	1	95	1000000000	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZDoTX8RjVmTF8e2LsJn6TaHDMgP8PbgZhNHS9Z5wTTaKV88kEi
68	payment	2	2	1	97	1000000000	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYZYEgrmBYtufEMwCjhpixSGuNnNAuspKZ28MwN6Cc18gBXKHDf
69	payment	2	2	1	98	1000000000	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZbSykdUD7P9aK93B9c5MFaZRuAruVd9yf2SB3SvrRie9iKrHG5
70	payment	2	2	1	99	1000000000	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYdhUkYuxbxR4vGhfMdNC8Ej4k9C35Mzd3k7qJHMsp26pzDSj7X
71	payment	2	2	1	100	1000000000	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZoCg46HxAqtSZ95SwGwWF7XBgNLxNWQ4tGRrUwPiG3G5awdU4x
72	payment	2	2	1	101	1000000000	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZJUhNS88nMpjYxXj2Bt4fCcU35vA19fHFpHjirTzswjhAJPDND
73	payment	2	2	1	102	1000000000	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZkWC2C5UxSgvsnTU2SiQtP8MmqKYQoVS3bUbMBPJF14eF3mbGw
74	payment	2	2	1	103	1000000000	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYvXDcWb2tbnwQEpw6Bk7Zve9Vb6GFh1SFJDK1zh1H74EyQSbLY
75	payment	2	2	1	104	1000000000	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpaEe6HizXQfuSs6TLkKyAXtRcx7N8KNxyNnCP8cSo8tB9X8dKfc
76	payment	2	2	1	105	1000000000	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpaEyoEpsmmzR1mp8mivGEkr89g2db8PUQbjJCkkWWwiTntKrj85
77	payment	2	2	1	106	1000000000	5000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZ6MgywygWeA6yANHDzBK9ndpb7pKbFvR8vQW35Zgvt1gkwqrTw
\.


--
-- Data for Name: voting_for; Type: TABLE DATA; Schema: public; Owner: o1labs
--

COPY public.voting_for (id, value) FROM stdin;
1	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x
\.


--
-- Data for Name: zkapp_account_precondition; Type: TABLE DATA; Schema: public; Owner: o1labs
--

COPY public.zkapp_account_precondition (id, kind, precondition_account_id, nonce) FROM stdin;
1	nonce	\N	1
2	accept	\N	\N
\.


--
-- Data for Name: zkapp_accounts; Type: TABLE DATA; Schema: public; Owner: o1labs
--

COPY public.zkapp_accounts (id, app_state_id, verification_key_id, zkapp_version, sequence_state_id, last_sequence_slot, proved_state, zkapp_uri_id) FROM stdin;
1	2	1	0	1	0	f	1
2	3	1	0	1	0	t	1
\.


--
-- Data for Name: zkapp_amount_bounds; Type: TABLE DATA; Schema: public; Owner: o1labs
--

COPY public.zkapp_amount_bounds (id, amount_lower_bound, amount_upper_bound) FROM stdin;
\.


--
-- Data for Name: zkapp_balance_bounds; Type: TABLE DATA; Schema: public; Owner: o1labs
--

COPY public.zkapp_balance_bounds (id, balance_lower_bound, balance_upper_bound) FROM stdin;
\.


--
-- Data for Name: zkapp_commands; Type: TABLE DATA; Schema: public; Owner: o1labs
--

COPY public.zkapp_commands (id, zkapp_fee_payer_body_id, zkapp_other_parties_ids, memo, hash) FROM stdin;
1	1	{1,2}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZNiZPqkrxDjG8LM1nv6x9M9Y8z6vWmAxRR6QeVAt9CHD73DQk2
2	2	{3}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZ7jXjRxsoVKwQc7VkqMtdpztxGqb3N9XDbJRUgCSniAUWN1qDC
\.


--
-- Data for Name: zkapp_epoch_data; Type: TABLE DATA; Schema: public; Owner: o1labs
--

COPY public.zkapp_epoch_data (id, epoch_ledger_id, epoch_seed, start_checkpoint, lock_checkpoint, epoch_length_id) FROM stdin;
1	1	\N	\N	\N	\N
\.


--
-- Data for Name: zkapp_epoch_ledger; Type: TABLE DATA; Schema: public; Owner: o1labs
--

COPY public.zkapp_epoch_ledger (id, hash_id, total_currency_id) FROM stdin;
1	\N	\N
\.


--
-- Data for Name: zkapp_events; Type: TABLE DATA; Schema: public; Owner: o1labs
--

COPY public.zkapp_events (id, element_ids) FROM stdin;
1	{}
\.


--
-- Data for Name: zkapp_fee_payer_body; Type: TABLE DATA; Schema: public; Owner: o1labs
--

COPY public.zkapp_fee_payer_body (id, account_identifier_id, update_id, fee, events_id, sequence_events_id, zkapp_network_precondition_id, nonce) FROM stdin;
1	5	1	5000000000	1	1	1	0
2	5	1	5000000000	1	1	1	2
\.


--
-- Data for Name: zkapp_global_slot_bounds; Type: TABLE DATA; Schema: public; Owner: o1labs
--

COPY public.zkapp_global_slot_bounds (id, global_slot_lower_bound, global_slot_upper_bound) FROM stdin;
\.


--
-- Data for Name: zkapp_length_bounds; Type: TABLE DATA; Schema: public; Owner: o1labs
--

COPY public.zkapp_length_bounds (id, length_lower_bound, length_upper_bound) FROM stdin;
\.


--
-- Data for Name: zkapp_network_precondition; Type: TABLE DATA; Schema: public; Owner: o1labs
--

COPY public.zkapp_network_precondition (id, snarked_ledger_hash_id, timestamp_id, blockchain_length_id, min_window_density_id, total_currency_id, curr_global_slot_since_hard_fork, global_slot_since_genesis, staking_epoch_data_id, next_epoch_data_id) FROM stdin;
1	\N	\N	\N	\N	\N	\N	\N	1	1
\.


--
-- Data for Name: zkapp_nonce_bounds; Type: TABLE DATA; Schema: public; Owner: o1labs
--

COPY public.zkapp_nonce_bounds (id, nonce_lower_bound, nonce_upper_bound) FROM stdin;
\.


--
-- Data for Name: zkapp_other_party; Type: TABLE DATA; Schema: public; Owner: o1labs
--

COPY public.zkapp_other_party (id, body_id, authorization_kind) FROM stdin;
1	1	signature
2	2	signature
3	3	proof
\.


--
-- Data for Name: zkapp_other_party_body; Type: TABLE DATA; Schema: public; Owner: o1labs
--

COPY public.zkapp_other_party_body (id, account_identifier_id, update_id, balance_change, increment_nonce, events_id, sequence_events_id, call_data_id, call_depth, zkapp_network_precondition_id, zkapp_account_precondition_id, use_full_commitment, caller) FROM stdin;
1	5	1	-10000000000	t	1	1	1	0	1	1	f	call
2	7	2	9999000000	f	1	1	1	0	1	2	t	call
3	7	3	0	f	1	1	1	0	1	2	t	call
\.


--
-- Data for Name: zkapp_party_failures; Type: TABLE DATA; Schema: public; Owner: o1labs
--

COPY public.zkapp_party_failures (id, index, failures) FROM stdin;
\.


--
-- Data for Name: zkapp_permissions; Type: TABLE DATA; Schema: public; Owner: o1labs
--

COPY public.zkapp_permissions (id, edit_state, send, receive, set_delegate, set_permissions, set_verification_key, set_zkapp_uri, edit_sequence_state, set_token_symbol, increment_nonce, set_voting_for) FROM stdin;
1	signature	signature	none	signature	proof	signature	none	signature	signature	none	none
2	signature	signature	signature	signature	signature	signature	none	none	none	none	none
3	signature	signature	none	signature	signature	signature	none	none	none	none	none
4	signature	signature	proof	signature	signature	signature	none	none	none	none	none
5	proof	signature	none	signature	signature	signature	signature	proof	signature	signature	signature
\.


--
-- Data for Name: zkapp_precondition_accounts; Type: TABLE DATA; Schema: public; Owner: o1labs
--

COPY public.zkapp_precondition_accounts (id, balance_id, nonce_id, receipt_chain_hash, delegate_id, state_id, sequence_state_id, proved_state) FROM stdin;
\.


--
-- Data for Name: zkapp_sequence_states; Type: TABLE DATA; Schema: public; Owner: o1labs
--

COPY public.zkapp_sequence_states (id, element_ids) FROM stdin;
1	{2,2,2,2,2}
\.


--
-- Data for Name: zkapp_state_data; Type: TABLE DATA; Schema: public; Owner: o1labs
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
-- Data for Name: zkapp_state_data_array; Type: TABLE DATA; Schema: public; Owner: o1labs
--

COPY public.zkapp_state_data_array (id, element_ids) FROM stdin;
\.


--
-- Data for Name: zkapp_states; Type: TABLE DATA; Schema: public; Owner: o1labs
--

COPY public.zkapp_states (id, element_ids) FROM stdin;
1	{NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL}
2	{1,1,1,1,1,1,1,1}
3	{3,4,5,6,7,8,9,10}
\.


--
-- Data for Name: zkapp_timestamp_bounds; Type: TABLE DATA; Schema: public; Owner: o1labs
--

COPY public.zkapp_timestamp_bounds (id, timestamp_lower_bound, timestamp_upper_bound) FROM stdin;
\.


--
-- Data for Name: zkapp_timing_info; Type: TABLE DATA; Schema: public; Owner: o1labs
--

COPY public.zkapp_timing_info (id, initial_minimum_balance, cliff_time, cliff_amount, vesting_period, vesting_increment) FROM stdin;
\.


--
-- Data for Name: zkapp_token_id_bounds; Type: TABLE DATA; Schema: public; Owner: o1labs
--

COPY public.zkapp_token_id_bounds (id, token_id_lower_bound, token_id_upper_bound) FROM stdin;
\.


--
-- Data for Name: zkapp_updates; Type: TABLE DATA; Schema: public; Owner: o1labs
--

COPY public.zkapp_updates (id, app_state_id, delegate_id, verification_key_id, permissions_id, zkapp_uri_id, token_symbol_id, timing_id, voting_for_id) FROM stdin;
1	1	\N	\N	\N	\N	\N	\N	\N
2	1	\N	1	5	\N	\N	\N	\N
3	3	\N	\N	\N	\N	\N	\N	\N
\.


--
-- Data for Name: zkapp_uris; Type: TABLE DATA; Schema: public; Owner: o1labs
--

COPY public.zkapp_uris (id, value) FROM stdin;
1	
\.


--
-- Data for Name: zkapp_verification_keys; Type: TABLE DATA; Schema: public; Owner: o1labs
--

COPY public.zkapp_verification_keys (id, verification_key, hash) FROM stdin;
1	AgICAQICAQ4aZW6B3tEebZVOFLu4oZnVSQAjf+807KLAK5AQGckPRdSl5KFVERk6XKXpSCrRNDLx15NghlyKgNOWWGG3RiHbNpmDHOBczZkAEon0rYjNiqywgwZ3Gfz5VO0vn/yMCUF4Ygfnj40d0Cppw0MKXSWEsPhOmlq1+1sKCgPF+KAnJJZmKTh2AD9bXvo6ehSc62bed5Qk22pJSkUez0puNB2T/Nyj1awBPVCRAmEFtNQOrf7KAjBafLUNHzzYaj5GF8QPGVnG5dT5Dnxts+HuCghD1+IPvPOX6NGkYyeMuZ4kOw6zw7oy/V5bh56AtLJR1fp9qgVqVbPaeNt4BMTDxyYovpik9RsI48Nu7j+UtUzUjg8MJ9jjNnoi7AHIZbIGK5b8cSxuHhDnj0otNrHhrAUAAvjCsRDsz9yqVqMi5ao8zSKPjhJwYmDyVPeflPMMVnDd0iLAThKBTwC1jDVDYS3pVZA4vgpnCB+iYYQdWejY2d/W5merCXl/Hu+TKwiUKpZqpVc4/82s3IEQRgu61U6vFo7jQ/sFV8hactvYYuwVMGky6i2zpyoQo1sm5jQm/VKkzJz/40W3cdB2s1uU5AwAAecMXjv0Jr3u6T2LxlcoOi9hHEisjkdcPDA2LinxJEsG7Kn0uVYFEsBL5EJQ3mPNPWdFnoiRqhppR6qVl/nbdhuuHnyALPeoZvmv4dqryUrpHbtz3i6rx2WzcwwuC9zfH9QBoXdcixtNYzJMcU6Gu21nFqrcbIylqXQNyKoGKF4fHU80bVfWKDyPo0vo/jy9Qj22hyo2/GsqVO4B0PQQXR9AClEgJMmQ27u3M8hyrxp9s3b5WHTsiA6SmMRg+WjYDqZgik+y6Dy7/J394AZvcMiAN5nZtIBRj6gn7wnujSUnU1VDGz3Gj6BJhVDlsGl06ZTOiCzCnxdIDsb6gpXR4ibZ+rlAo0m7yRg13SmDbj1BcOU+iVosVTiW53HvHNx8CKluy3d3UVW2wYq1ZrdCwqcv+4SdEi/wrPmwpW2VEkUkTvohSTUHnZXriR7kiHfM1q5XIaJx7z4T76f0NWOzZhkcWQJVg4GNIP3LdvHQGvpctwLiufDvNl/dUVL+kM3+OugPXiwIKyzRsjLjhyYqYQbPxbZdA+WT9CCH+seFFxsLK4u3ZAZNA7Dla4UD5RzHrvJ/7rz34lANcAedbLUsrj6hVlHPlgj+IS0CKUfh1foHB9NVM1Unp50m8OasxKvhKWtCC/VfcH3z1tgTEbX4OBqi9IWSia1lHjr+5+oJ+aI0abp6cVguxjxOqglEmCLbOED6QMXWK4UwKLBOCxXTrjdNoURgIcIhUNR8P+t7Cy+Ct5o2YsiNE+AV/yH6Odv3ORqSY9GUnrD9nzc8Rb7rnbWy+6IlNelB5iUjB71BGUkqLodFZq+hRASArWoma2VX9s5xGBbI/je1hZYTFrFumRMaJ0szmimlbrRHJA+RpANN5ygBJow9TNNTt6Kzi76zFkrPbjSfq+vQtDYYGC0q+mq01ZghmHZRdwLiNKOrEAEKxjVVsMnAIBAi8qs0LhknwX7o7lxIhsyzAwU2/8/NnjtfqG+0XkIBWOVJQlQhZgij69wvNRp702FipUd9QaTZAQLZkBUQ8Yv+1sTk7ybPVW8oEbjTP8S0ZJB/vllVlzMR9P71Lbe2V2W2x8xT87EXS3e6++aYkh6wfxMN3DwvXzexpZMn0N6Jtqkp64mPMrGg0kL7iMlT6KKUXKG8O5vaN91NUCp/i+/m8zoOpiZaLDdZ9sX6jLB/+/NizGi4B1cPLJl856fgiL4wsCUGPSnadRfuMMqcCj9owEYvxRNdMBPSdb8oNqhpH1WIY8H064G0UveS8AIZ/B5TF9Zz4IolHABoYt6leIZabczW2UZDNeVhsvhdtzhR+Rb/PS7bq+EkF6kgtXFhrLj3B40/wZELbfVW53lzKQZxXoq+mnSD5eMnQPDCCpdAQ1Ii/VNsWs4X68Wf87ahJaj7ZVFcdO+qOBsXcv6q/3f3m+vQ7Xwle6GxagvIq16E/fbZvK5q3CCyPgRHOuIcqOptxe017rvx171OIjS3H7+WiQfh5N/5cf4GWaF40m5qXabatDZ+IVKdqVIHaXWolAMjgxG0QZ5fXCo6kkdT/UbMy8yPZ6EhiD/gO9iTRCSZarkGMZx58ne7DcQOws+pN1auEDF1SCM9zjOCGA7OLgsGV7FE204SR/I2nYEdSDTpqN5UXvrbSkV35/Pt7QYDKas8kJKq/lAM8h77vHmxMjZNsdlIvkw1rfKmgdrVo5JEeuxlwfbSfyQSKDcSPdknnBpX02WnN8qX25sbUHyENj1FiWCmIikcYFoV4ARZUKlOkR/llDtFj/Pmn6oZlt9cJBpH9k0eZLjJFxU=	4477517463051215094183084084475291894669824955933082137376892140589951222603
\.


--
-- Name: account_identifiers_id_seq; Type: SEQUENCE SET; Schema: public; Owner: o1labs
--

SELECT pg_catalog.setval('public.account_identifiers_id_seq', 7, true);


--
-- Name: blocks_id_seq; Type: SEQUENCE SET; Schema: public; Owner: o1labs
--

SELECT pg_catalog.setval('public.blocks_id_seq', 63, true);


--
-- Name: epoch_data_id_seq; Type: SEQUENCE SET; Schema: public; Owner: o1labs
--

SELECT pg_catalog.setval('public.epoch_data_id_seq', 64, true);


--
-- Name: internal_commands_id_seq; Type: SEQUENCE SET; Schema: public; Owner: o1labs
--

SELECT pg_catalog.setval('public.internal_commands_id_seq', 23, true);


--
-- Name: public_keys_id_seq; Type: SEQUENCE SET; Schema: public; Owner: o1labs
--

SELECT pg_catalog.setval('public.public_keys_id_seq', 7, true);


--
-- Name: snarked_ledger_hashes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: o1labs
--

SELECT pg_catalog.setval('public.snarked_ledger_hashes_id_seq', 15, true);


--
-- Name: timing_info_id_seq; Type: SEQUENCE SET; Schema: public; Owner: o1labs
--

SELECT pg_catalog.setval('public.timing_info_id_seq', 7, true);


--
-- Name: token_symbols_id_seq; Type: SEQUENCE SET; Schema: public; Owner: o1labs
--

SELECT pg_catalog.setval('public.token_symbols_id_seq', 1, true);


--
-- Name: tokens_id_seq; Type: SEQUENCE SET; Schema: public; Owner: o1labs
--

SELECT pg_catalog.setval('public.tokens_id_seq', 1, true);


--
-- Name: user_commands_id_seq; Type: SEQUENCE SET; Schema: public; Owner: o1labs
--

SELECT pg_catalog.setval('public.user_commands_id_seq', 77, true);


--
-- Name: voting_for_id_seq; Type: SEQUENCE SET; Schema: public; Owner: o1labs
--

SELECT pg_catalog.setval('public.voting_for_id_seq', 1, true);


--
-- Name: zkapp_account_precondition_id_seq; Type: SEQUENCE SET; Schema: public; Owner: o1labs
--

SELECT pg_catalog.setval('public.zkapp_account_precondition_id_seq', 2, true);


--
-- Name: zkapp_accounts_id_seq; Type: SEQUENCE SET; Schema: public; Owner: o1labs
--

SELECT pg_catalog.setval('public.zkapp_accounts_id_seq', 2, true);


--
-- Name: zkapp_amount_bounds_id_seq; Type: SEQUENCE SET; Schema: public; Owner: o1labs
--

SELECT pg_catalog.setval('public.zkapp_amount_bounds_id_seq', 1, false);


--
-- Name: zkapp_balance_bounds_id_seq; Type: SEQUENCE SET; Schema: public; Owner: o1labs
--

SELECT pg_catalog.setval('public.zkapp_balance_bounds_id_seq', 1, false);


--
-- Name: zkapp_commands_id_seq; Type: SEQUENCE SET; Schema: public; Owner: o1labs
--

SELECT pg_catalog.setval('public.zkapp_commands_id_seq', 2, true);


--
-- Name: zkapp_epoch_data_id_seq; Type: SEQUENCE SET; Schema: public; Owner: o1labs
--

SELECT pg_catalog.setval('public.zkapp_epoch_data_id_seq', 1, true);


--
-- Name: zkapp_epoch_ledger_id_seq; Type: SEQUENCE SET; Schema: public; Owner: o1labs
--

SELECT pg_catalog.setval('public.zkapp_epoch_ledger_id_seq', 1, true);


--
-- Name: zkapp_events_id_seq; Type: SEQUENCE SET; Schema: public; Owner: o1labs
--

SELECT pg_catalog.setval('public.zkapp_events_id_seq', 1, true);


--
-- Name: zkapp_fee_payer_body_id_seq; Type: SEQUENCE SET; Schema: public; Owner: o1labs
--

SELECT pg_catalog.setval('public.zkapp_fee_payer_body_id_seq', 2, true);


--
-- Name: zkapp_global_slot_bounds_id_seq; Type: SEQUENCE SET; Schema: public; Owner: o1labs
--

SELECT pg_catalog.setval('public.zkapp_global_slot_bounds_id_seq', 1, false);


--
-- Name: zkapp_length_bounds_id_seq; Type: SEQUENCE SET; Schema: public; Owner: o1labs
--

SELECT pg_catalog.setval('public.zkapp_length_bounds_id_seq', 1, false);


--
-- Name: zkapp_network_precondition_id_seq; Type: SEQUENCE SET; Schema: public; Owner: o1labs
--

SELECT pg_catalog.setval('public.zkapp_network_precondition_id_seq', 1, true);


--
-- Name: zkapp_nonce_bounds_id_seq; Type: SEQUENCE SET; Schema: public; Owner: o1labs
--

SELECT pg_catalog.setval('public.zkapp_nonce_bounds_id_seq', 1, false);


--
-- Name: zkapp_other_party_body_id_seq; Type: SEQUENCE SET; Schema: public; Owner: o1labs
--

SELECT pg_catalog.setval('public.zkapp_other_party_body_id_seq', 3, true);


--
-- Name: zkapp_other_party_id_seq; Type: SEQUENCE SET; Schema: public; Owner: o1labs
--

SELECT pg_catalog.setval('public.zkapp_other_party_id_seq', 3, true);


--
-- Name: zkapp_party_failures_id_seq; Type: SEQUENCE SET; Schema: public; Owner: o1labs
--

SELECT pg_catalog.setval('public.zkapp_party_failures_id_seq', 1, false);


--
-- Name: zkapp_permissions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: o1labs
--

SELECT pg_catalog.setval('public.zkapp_permissions_id_seq', 5, true);


--
-- Name: zkapp_precondition_accounts_id_seq; Type: SEQUENCE SET; Schema: public; Owner: o1labs
--

SELECT pg_catalog.setval('public.zkapp_precondition_accounts_id_seq', 1, false);


--
-- Name: zkapp_sequence_states_id_seq; Type: SEQUENCE SET; Schema: public; Owner: o1labs
--

SELECT pg_catalog.setval('public.zkapp_sequence_states_id_seq', 1, true);


--
-- Name: zkapp_state_data_array_id_seq; Type: SEQUENCE SET; Schema: public; Owner: o1labs
--

SELECT pg_catalog.setval('public.zkapp_state_data_array_id_seq', 1, false);


--
-- Name: zkapp_state_data_id_seq; Type: SEQUENCE SET; Schema: public; Owner: o1labs
--

SELECT pg_catalog.setval('public.zkapp_state_data_id_seq', 10, true);


--
-- Name: zkapp_states_id_seq; Type: SEQUENCE SET; Schema: public; Owner: o1labs
--

SELECT pg_catalog.setval('public.zkapp_states_id_seq', 3, true);


--
-- Name: zkapp_timestamp_bounds_id_seq; Type: SEQUENCE SET; Schema: public; Owner: o1labs
--

SELECT pg_catalog.setval('public.zkapp_timestamp_bounds_id_seq', 1, false);


--
-- Name: zkapp_timing_info_id_seq; Type: SEQUENCE SET; Schema: public; Owner: o1labs
--

SELECT pg_catalog.setval('public.zkapp_timing_info_id_seq', 1, false);


--
-- Name: zkapp_token_id_bounds_id_seq; Type: SEQUENCE SET; Schema: public; Owner: o1labs
--

SELECT pg_catalog.setval('public.zkapp_token_id_bounds_id_seq', 1, false);


--
-- Name: zkapp_updates_id_seq; Type: SEQUENCE SET; Schema: public; Owner: o1labs
--

SELECT pg_catalog.setval('public.zkapp_updates_id_seq', 3, true);


--
-- Name: zkapp_uris_id_seq; Type: SEQUENCE SET; Schema: public; Owner: o1labs
--

SELECT pg_catalog.setval('public.zkapp_uris_id_seq', 1, true);


--
-- Name: zkapp_verification_keys_id_seq; Type: SEQUENCE SET; Schema: public; Owner: o1labs
--

SELECT pg_catalog.setval('public.zkapp_verification_keys_id_seq', 1, true);


--
-- Name: account_identifiers account_identifiers_pkey; Type: CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.account_identifiers
    ADD CONSTRAINT account_identifiers_pkey PRIMARY KEY (id);


--
-- Name: account_identifiers account_identifiers_public_key_id_token_id_key; Type: CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.account_identifiers
    ADD CONSTRAINT account_identifiers_public_key_id_token_id_key UNIQUE (public_key_id, token_id);


--
-- Name: accounts_accessed accounts_accessed_pkey; Type: CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.accounts_accessed
    ADD CONSTRAINT accounts_accessed_pkey PRIMARY KEY (block_id, account_identifier_id);


--
-- Name: accounts_created accounts_created_pkey; Type: CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.accounts_created
    ADD CONSTRAINT accounts_created_pkey PRIMARY KEY (block_id, account_identifier_id);


--
-- Name: blocks_internal_commands blocks_internal_commands_pkey; Type: CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.blocks_internal_commands
    ADD CONSTRAINT blocks_internal_commands_pkey PRIMARY KEY (block_id, internal_command_id, sequence_no, secondary_sequence_no);


--
-- Name: blocks blocks_pkey; Type: CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.blocks
    ADD CONSTRAINT blocks_pkey PRIMARY KEY (id);


--
-- Name: blocks blocks_state_hash_key; Type: CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.blocks
    ADD CONSTRAINT blocks_state_hash_key UNIQUE (state_hash);


--
-- Name: blocks_user_commands blocks_user_commands_pkey; Type: CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.blocks_user_commands
    ADD CONSTRAINT blocks_user_commands_pkey PRIMARY KEY (block_id, user_command_id, sequence_no);


--
-- Name: blocks_zkapp_commands blocks_zkapp_commands_pkey; Type: CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.blocks_zkapp_commands
    ADD CONSTRAINT blocks_zkapp_commands_pkey PRIMARY KEY (block_id, zkapp_command_id, sequence_no);


--
-- Name: epoch_data epoch_data_pkey; Type: CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.epoch_data
    ADD CONSTRAINT epoch_data_pkey PRIMARY KEY (id);


--
-- Name: internal_commands internal_commands_hash_typ_key; Type: CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.internal_commands
    ADD CONSTRAINT internal_commands_hash_typ_key UNIQUE (hash, typ);


--
-- Name: internal_commands internal_commands_pkey; Type: CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.internal_commands
    ADD CONSTRAINT internal_commands_pkey PRIMARY KEY (id);


--
-- Name: public_keys public_keys_pkey; Type: CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.public_keys
    ADD CONSTRAINT public_keys_pkey PRIMARY KEY (id);


--
-- Name: public_keys public_keys_value_key; Type: CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.public_keys
    ADD CONSTRAINT public_keys_value_key UNIQUE (value);


--
-- Name: snarked_ledger_hashes snarked_ledger_hashes_pkey; Type: CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.snarked_ledger_hashes
    ADD CONSTRAINT snarked_ledger_hashes_pkey PRIMARY KEY (id);


--
-- Name: snarked_ledger_hashes snarked_ledger_hashes_value_key; Type: CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.snarked_ledger_hashes
    ADD CONSTRAINT snarked_ledger_hashes_value_key UNIQUE (value);


--
-- Name: timing_info timing_info_account_identifier_id_key; Type: CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.timing_info
    ADD CONSTRAINT timing_info_account_identifier_id_key UNIQUE (account_identifier_id);


--
-- Name: timing_info timing_info_pkey; Type: CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.timing_info
    ADD CONSTRAINT timing_info_pkey PRIMARY KEY (id);


--
-- Name: token_symbols token_symbols_pkey; Type: CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.token_symbols
    ADD CONSTRAINT token_symbols_pkey PRIMARY KEY (id);


--
-- Name: tokens tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.tokens
    ADD CONSTRAINT tokens_pkey PRIMARY KEY (id);


--
-- Name: tokens tokens_value_key; Type: CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.tokens
    ADD CONSTRAINT tokens_value_key UNIQUE (value);


--
-- Name: user_commands user_commands_hash_key; Type: CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.user_commands
    ADD CONSTRAINT user_commands_hash_key UNIQUE (hash);


--
-- Name: user_commands user_commands_pkey; Type: CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.user_commands
    ADD CONSTRAINT user_commands_pkey PRIMARY KEY (id);


--
-- Name: voting_for voting_for_pkey; Type: CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.voting_for
    ADD CONSTRAINT voting_for_pkey PRIMARY KEY (id);


--
-- Name: zkapp_account_precondition zkapp_account_precondition_pkey; Type: CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_account_precondition
    ADD CONSTRAINT zkapp_account_precondition_pkey PRIMARY KEY (id);


--
-- Name: zkapp_accounts zkapp_accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_accounts
    ADD CONSTRAINT zkapp_accounts_pkey PRIMARY KEY (id);


--
-- Name: zkapp_amount_bounds zkapp_amount_bounds_pkey; Type: CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_amount_bounds
    ADD CONSTRAINT zkapp_amount_bounds_pkey PRIMARY KEY (id);


--
-- Name: zkapp_balance_bounds zkapp_balance_bounds_pkey; Type: CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_balance_bounds
    ADD CONSTRAINT zkapp_balance_bounds_pkey PRIMARY KEY (id);


--
-- Name: zkapp_commands zkapp_commands_hash_key; Type: CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_commands
    ADD CONSTRAINT zkapp_commands_hash_key UNIQUE (hash);


--
-- Name: zkapp_commands zkapp_commands_pkey; Type: CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_commands
    ADD CONSTRAINT zkapp_commands_pkey PRIMARY KEY (id);


--
-- Name: zkapp_epoch_data zkapp_epoch_data_pkey; Type: CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_epoch_data
    ADD CONSTRAINT zkapp_epoch_data_pkey PRIMARY KEY (id);


--
-- Name: zkapp_epoch_ledger zkapp_epoch_ledger_pkey; Type: CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_epoch_ledger
    ADD CONSTRAINT zkapp_epoch_ledger_pkey PRIMARY KEY (id);


--
-- Name: zkapp_events zkapp_events_pkey; Type: CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_events
    ADD CONSTRAINT zkapp_events_pkey PRIMARY KEY (id);


--
-- Name: zkapp_fee_payer_body zkapp_fee_payer_body_pkey; Type: CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_fee_payer_body
    ADD CONSTRAINT zkapp_fee_payer_body_pkey PRIMARY KEY (id);


--
-- Name: zkapp_global_slot_bounds zkapp_global_slot_bounds_pkey; Type: CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_global_slot_bounds
    ADD CONSTRAINT zkapp_global_slot_bounds_pkey PRIMARY KEY (id);


--
-- Name: zkapp_length_bounds zkapp_length_bounds_pkey; Type: CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_length_bounds
    ADD CONSTRAINT zkapp_length_bounds_pkey PRIMARY KEY (id);


--
-- Name: zkapp_network_precondition zkapp_network_precondition_pkey; Type: CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_network_precondition
    ADD CONSTRAINT zkapp_network_precondition_pkey PRIMARY KEY (id);


--
-- Name: zkapp_nonce_bounds zkapp_nonce_bounds_pkey; Type: CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_nonce_bounds
    ADD CONSTRAINT zkapp_nonce_bounds_pkey PRIMARY KEY (id);


--
-- Name: zkapp_other_party_body zkapp_other_party_body_pkey; Type: CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_other_party_body
    ADD CONSTRAINT zkapp_other_party_body_pkey PRIMARY KEY (id);


--
-- Name: zkapp_other_party zkapp_other_party_pkey; Type: CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_other_party
    ADD CONSTRAINT zkapp_other_party_pkey PRIMARY KEY (id);


--
-- Name: zkapp_party_failures zkapp_party_failures_pkey; Type: CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_party_failures
    ADD CONSTRAINT zkapp_party_failures_pkey PRIMARY KEY (id);


--
-- Name: zkapp_permissions zkapp_permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_permissions
    ADD CONSTRAINT zkapp_permissions_pkey PRIMARY KEY (id);


--
-- Name: zkapp_precondition_accounts zkapp_precondition_accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_precondition_accounts
    ADD CONSTRAINT zkapp_precondition_accounts_pkey PRIMARY KEY (id);


--
-- Name: zkapp_sequence_states zkapp_sequence_states_pkey; Type: CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_sequence_states
    ADD CONSTRAINT zkapp_sequence_states_pkey PRIMARY KEY (id);


--
-- Name: zkapp_state_data_array zkapp_state_data_array_pkey; Type: CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_state_data_array
    ADD CONSTRAINT zkapp_state_data_array_pkey PRIMARY KEY (id);


--
-- Name: zkapp_state_data zkapp_state_data_field_key; Type: CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_state_data
    ADD CONSTRAINT zkapp_state_data_field_key UNIQUE (field);


--
-- Name: zkapp_state_data zkapp_state_data_pkey; Type: CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_state_data
    ADD CONSTRAINT zkapp_state_data_pkey PRIMARY KEY (id);


--
-- Name: zkapp_states zkapp_states_pkey; Type: CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_states
    ADD CONSTRAINT zkapp_states_pkey PRIMARY KEY (id);


--
-- Name: zkapp_timestamp_bounds zkapp_timestamp_bounds_pkey; Type: CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_timestamp_bounds
    ADD CONSTRAINT zkapp_timestamp_bounds_pkey PRIMARY KEY (id);


--
-- Name: zkapp_timing_info zkapp_timing_info_pkey; Type: CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_timing_info
    ADD CONSTRAINT zkapp_timing_info_pkey PRIMARY KEY (id);


--
-- Name: zkapp_token_id_bounds zkapp_token_id_bounds_pkey; Type: CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_token_id_bounds
    ADD CONSTRAINT zkapp_token_id_bounds_pkey PRIMARY KEY (id);


--
-- Name: zkapp_updates zkapp_updates_pkey; Type: CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_updates
    ADD CONSTRAINT zkapp_updates_pkey PRIMARY KEY (id);


--
-- Name: zkapp_uris zkapp_uris_pkey; Type: CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_uris
    ADD CONSTRAINT zkapp_uris_pkey PRIMARY KEY (id);


--
-- Name: zkapp_uris zkapp_uris_value_key; Type: CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_uris
    ADD CONSTRAINT zkapp_uris_value_key UNIQUE (value);


--
-- Name: zkapp_verification_keys zkapp_verification_keys_hash_key; Type: CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_verification_keys
    ADD CONSTRAINT zkapp_verification_keys_hash_key UNIQUE (hash);


--
-- Name: zkapp_verification_keys zkapp_verification_keys_pkey; Type: CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_verification_keys
    ADD CONSTRAINT zkapp_verification_keys_pkey PRIMARY KEY (id);


--
-- Name: zkapp_verification_keys zkapp_verification_keys_verification_key_key; Type: CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_verification_keys
    ADD CONSTRAINT zkapp_verification_keys_verification_key_key UNIQUE (verification_key);


--
-- Name: idx_accounts_accessed_block_account_identifier_id; Type: INDEX; Schema: public; Owner: o1labs
--

CREATE INDEX idx_accounts_accessed_block_account_identifier_id ON public.accounts_accessed USING btree (account_identifier_id);


--
-- Name: idx_accounts_accessed_block_id; Type: INDEX; Schema: public; Owner: o1labs
--

CREATE INDEX idx_accounts_accessed_block_id ON public.accounts_accessed USING btree (block_id);


--
-- Name: idx_accounts_created_block_account_identifier_id; Type: INDEX; Schema: public; Owner: o1labs
--

CREATE INDEX idx_accounts_created_block_account_identifier_id ON public.accounts_created USING btree (account_identifier_id);


--
-- Name: idx_accounts_created_block_id; Type: INDEX; Schema: public; Owner: o1labs
--

CREATE INDEX idx_accounts_created_block_id ON public.accounts_created USING btree (block_id);


--
-- Name: idx_blocks_creator_id; Type: INDEX; Schema: public; Owner: o1labs
--

CREATE INDEX idx_blocks_creator_id ON public.blocks USING btree (creator_id);


--
-- Name: idx_blocks_height; Type: INDEX; Schema: public; Owner: o1labs
--

CREATE INDEX idx_blocks_height ON public.blocks USING btree (height);


--
-- Name: idx_blocks_internal_commands_block_id; Type: INDEX; Schema: public; Owner: o1labs
--

CREATE INDEX idx_blocks_internal_commands_block_id ON public.blocks_internal_commands USING btree (block_id);


--
-- Name: idx_blocks_internal_commands_internal_command_id; Type: INDEX; Schema: public; Owner: o1labs
--

CREATE INDEX idx_blocks_internal_commands_internal_command_id ON public.blocks_internal_commands USING btree (internal_command_id);


--
-- Name: idx_blocks_internal_commands_secondary_sequence_no; Type: INDEX; Schema: public; Owner: o1labs
--

CREATE INDEX idx_blocks_internal_commands_secondary_sequence_no ON public.blocks_internal_commands USING btree (secondary_sequence_no);


--
-- Name: idx_blocks_internal_commands_sequence_no; Type: INDEX; Schema: public; Owner: o1labs
--

CREATE INDEX idx_blocks_internal_commands_sequence_no ON public.blocks_internal_commands USING btree (sequence_no);


--
-- Name: idx_blocks_parent_id; Type: INDEX; Schema: public; Owner: o1labs
--

CREATE INDEX idx_blocks_parent_id ON public.blocks USING btree (parent_id);


--
-- Name: idx_blocks_user_commands_block_id; Type: INDEX; Schema: public; Owner: o1labs
--

CREATE INDEX idx_blocks_user_commands_block_id ON public.blocks_user_commands USING btree (block_id);


--
-- Name: idx_blocks_user_commands_sequence_no; Type: INDEX; Schema: public; Owner: o1labs
--

CREATE INDEX idx_blocks_user_commands_sequence_no ON public.blocks_user_commands USING btree (sequence_no);


--
-- Name: idx_blocks_user_commands_user_command_id; Type: INDEX; Schema: public; Owner: o1labs
--

CREATE INDEX idx_blocks_user_commands_user_command_id ON public.blocks_user_commands USING btree (user_command_id);


--
-- Name: idx_blocks_zkapp_commands_block_id; Type: INDEX; Schema: public; Owner: o1labs
--

CREATE INDEX idx_blocks_zkapp_commands_block_id ON public.blocks_zkapp_commands USING btree (block_id);


--
-- Name: idx_blocks_zkapp_commands_sequence_no; Type: INDEX; Schema: public; Owner: o1labs
--

CREATE INDEX idx_blocks_zkapp_commands_sequence_no ON public.blocks_zkapp_commands USING btree (sequence_no);


--
-- Name: idx_blocks_zkapp_commands_zkapp_command_id; Type: INDEX; Schema: public; Owner: o1labs
--

CREATE INDEX idx_blocks_zkapp_commands_zkapp_command_id ON public.blocks_zkapp_commands USING btree (zkapp_command_id);


--
-- Name: idx_chain_status; Type: INDEX; Schema: public; Owner: o1labs
--

CREATE INDEX idx_chain_status ON public.blocks USING btree (chain_status);


--
-- Name: idx_token_symbols_value; Type: INDEX; Schema: public; Owner: o1labs
--

CREATE INDEX idx_token_symbols_value ON public.token_symbols USING btree (value);


--
-- Name: idx_voting_for_value; Type: INDEX; Schema: public; Owner: o1labs
--

CREATE INDEX idx_voting_for_value ON public.voting_for USING btree (value);


--
-- Name: account_identifiers account_identifiers_public_key_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.account_identifiers
    ADD CONSTRAINT account_identifiers_public_key_id_fkey FOREIGN KEY (public_key_id) REFERENCES public.public_keys(id) ON DELETE CASCADE;


--
-- Name: account_identifiers account_identifiers_token_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.account_identifiers
    ADD CONSTRAINT account_identifiers_token_id_fkey FOREIGN KEY (token_id) REFERENCES public.tokens(id) ON DELETE CASCADE;


--
-- Name: accounts_accessed accounts_accessed_account_identifier_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.accounts_accessed
    ADD CONSTRAINT accounts_accessed_account_identifier_id_fkey FOREIGN KEY (account_identifier_id) REFERENCES public.account_identifiers(id);


--
-- Name: accounts_accessed accounts_accessed_block_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.accounts_accessed
    ADD CONSTRAINT accounts_accessed_block_id_fkey FOREIGN KEY (block_id) REFERENCES public.blocks(id);


--
-- Name: accounts_accessed accounts_accessed_delegate_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.accounts_accessed
    ADD CONSTRAINT accounts_accessed_delegate_id_fkey FOREIGN KEY (delegate_id) REFERENCES public.public_keys(id);


--
-- Name: accounts_accessed accounts_accessed_permissions_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.accounts_accessed
    ADD CONSTRAINT accounts_accessed_permissions_id_fkey FOREIGN KEY (permissions_id) REFERENCES public.zkapp_permissions(id);


--
-- Name: accounts_accessed accounts_accessed_timing_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.accounts_accessed
    ADD CONSTRAINT accounts_accessed_timing_id_fkey FOREIGN KEY (timing_id) REFERENCES public.timing_info(id);


--
-- Name: accounts_accessed accounts_accessed_token_symbol_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.accounts_accessed
    ADD CONSTRAINT accounts_accessed_token_symbol_id_fkey FOREIGN KEY (token_symbol_id) REFERENCES public.token_symbols(id);


--
-- Name: accounts_accessed accounts_accessed_voting_for_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.accounts_accessed
    ADD CONSTRAINT accounts_accessed_voting_for_id_fkey FOREIGN KEY (voting_for_id) REFERENCES public.voting_for(id);


--
-- Name: accounts_accessed accounts_accessed_zkapp_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.accounts_accessed
    ADD CONSTRAINT accounts_accessed_zkapp_id_fkey FOREIGN KEY (zkapp_id) REFERENCES public.zkapp_accounts(id);


--
-- Name: accounts_created accounts_created_account_identifier_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.accounts_created
    ADD CONSTRAINT accounts_created_account_identifier_id_fkey FOREIGN KEY (account_identifier_id) REFERENCES public.account_identifiers(id);


--
-- Name: accounts_created accounts_created_block_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.accounts_created
    ADD CONSTRAINT accounts_created_block_id_fkey FOREIGN KEY (block_id) REFERENCES public.blocks(id);


--
-- Name: blocks blocks_block_winner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.blocks
    ADD CONSTRAINT blocks_block_winner_id_fkey FOREIGN KEY (block_winner_id) REFERENCES public.public_keys(id);


--
-- Name: blocks blocks_creator_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.blocks
    ADD CONSTRAINT blocks_creator_id_fkey FOREIGN KEY (creator_id) REFERENCES public.public_keys(id);


--
-- Name: blocks_internal_commands blocks_internal_commands_block_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.blocks_internal_commands
    ADD CONSTRAINT blocks_internal_commands_block_id_fkey FOREIGN KEY (block_id) REFERENCES public.blocks(id) ON DELETE CASCADE;


--
-- Name: blocks_internal_commands blocks_internal_commands_internal_command_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.blocks_internal_commands
    ADD CONSTRAINT blocks_internal_commands_internal_command_id_fkey FOREIGN KEY (internal_command_id) REFERENCES public.internal_commands(id) ON DELETE CASCADE;


--
-- Name: blocks blocks_next_epoch_data_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.blocks
    ADD CONSTRAINT blocks_next_epoch_data_id_fkey FOREIGN KEY (next_epoch_data_id) REFERENCES public.epoch_data(id);


--
-- Name: blocks blocks_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.blocks
    ADD CONSTRAINT blocks_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.blocks(id);


--
-- Name: blocks blocks_snarked_ledger_hash_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.blocks
    ADD CONSTRAINT blocks_snarked_ledger_hash_id_fkey FOREIGN KEY (snarked_ledger_hash_id) REFERENCES public.snarked_ledger_hashes(id);


--
-- Name: blocks blocks_staking_epoch_data_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.blocks
    ADD CONSTRAINT blocks_staking_epoch_data_id_fkey FOREIGN KEY (staking_epoch_data_id) REFERENCES public.epoch_data(id);


--
-- Name: blocks_user_commands blocks_user_commands_block_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.blocks_user_commands
    ADD CONSTRAINT blocks_user_commands_block_id_fkey FOREIGN KEY (block_id) REFERENCES public.blocks(id) ON DELETE CASCADE;


--
-- Name: blocks_user_commands blocks_user_commands_user_command_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.blocks_user_commands
    ADD CONSTRAINT blocks_user_commands_user_command_id_fkey FOREIGN KEY (user_command_id) REFERENCES public.user_commands(id) ON DELETE CASCADE;


--
-- Name: blocks_zkapp_commands blocks_zkapp_commands_block_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.blocks_zkapp_commands
    ADD CONSTRAINT blocks_zkapp_commands_block_id_fkey FOREIGN KEY (block_id) REFERENCES public.blocks(id) ON DELETE CASCADE;


--
-- Name: blocks_zkapp_commands blocks_zkapp_commands_zkapp_command_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.blocks_zkapp_commands
    ADD CONSTRAINT blocks_zkapp_commands_zkapp_command_id_fkey FOREIGN KEY (zkapp_command_id) REFERENCES public.zkapp_commands(id) ON DELETE CASCADE;


--
-- Name: epoch_data epoch_data_ledger_hash_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.epoch_data
    ADD CONSTRAINT epoch_data_ledger_hash_id_fkey FOREIGN KEY (ledger_hash_id) REFERENCES public.snarked_ledger_hashes(id);


--
-- Name: internal_commands internal_commands_receiver_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.internal_commands
    ADD CONSTRAINT internal_commands_receiver_id_fkey FOREIGN KEY (receiver_id) REFERENCES public.account_identifiers(id);


--
-- Name: timing_info timing_info_account_identifier_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.timing_info
    ADD CONSTRAINT timing_info_account_identifier_id_fkey FOREIGN KEY (account_identifier_id) REFERENCES public.account_identifiers(id);


--
-- Name: tokens tokens_owner_public_key_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.tokens
    ADD CONSTRAINT tokens_owner_public_key_id_fkey FOREIGN KEY (owner_public_key_id) REFERENCES public.public_keys(id) ON DELETE CASCADE;


--
-- Name: tokens tokens_owner_token_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.tokens
    ADD CONSTRAINT tokens_owner_token_id_fkey FOREIGN KEY (owner_token_id) REFERENCES public.tokens(id);


--
-- Name: user_commands user_commands_fee_payer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.user_commands
    ADD CONSTRAINT user_commands_fee_payer_id_fkey FOREIGN KEY (fee_payer_id) REFERENCES public.account_identifiers(id);


--
-- Name: user_commands user_commands_receiver_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.user_commands
    ADD CONSTRAINT user_commands_receiver_id_fkey FOREIGN KEY (receiver_id) REFERENCES public.account_identifiers(id);


--
-- Name: user_commands user_commands_source_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.user_commands
    ADD CONSTRAINT user_commands_source_id_fkey FOREIGN KEY (source_id) REFERENCES public.account_identifiers(id);


--
-- Name: zkapp_account_precondition zkapp_account_precondition_precondition_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_account_precondition
    ADD CONSTRAINT zkapp_account_precondition_precondition_account_id_fkey FOREIGN KEY (precondition_account_id) REFERENCES public.zkapp_precondition_accounts(id);


--
-- Name: zkapp_accounts zkapp_accounts_app_state_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_accounts
    ADD CONSTRAINT zkapp_accounts_app_state_id_fkey FOREIGN KEY (app_state_id) REFERENCES public.zkapp_states(id);


--
-- Name: zkapp_accounts zkapp_accounts_sequence_state_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_accounts
    ADD CONSTRAINT zkapp_accounts_sequence_state_id_fkey FOREIGN KEY (sequence_state_id) REFERENCES public.zkapp_sequence_states(id);


--
-- Name: zkapp_accounts zkapp_accounts_verification_key_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_accounts
    ADD CONSTRAINT zkapp_accounts_verification_key_id_fkey FOREIGN KEY (verification_key_id) REFERENCES public.zkapp_verification_keys(id);


--
-- Name: zkapp_accounts zkapp_accounts_zkapp_uri_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_accounts
    ADD CONSTRAINT zkapp_accounts_zkapp_uri_id_fkey FOREIGN KEY (zkapp_uri_id) REFERENCES public.zkapp_uris(id);


--
-- Name: zkapp_commands zkapp_commands_zkapp_fee_payer_body_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_commands
    ADD CONSTRAINT zkapp_commands_zkapp_fee_payer_body_id_fkey FOREIGN KEY (zkapp_fee_payer_body_id) REFERENCES public.zkapp_fee_payer_body(id);


--
-- Name: zkapp_epoch_data zkapp_epoch_data_epoch_ledger_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_epoch_data
    ADD CONSTRAINT zkapp_epoch_data_epoch_ledger_id_fkey FOREIGN KEY (epoch_ledger_id) REFERENCES public.zkapp_epoch_ledger(id);


--
-- Name: zkapp_epoch_data zkapp_epoch_data_epoch_length_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_epoch_data
    ADD CONSTRAINT zkapp_epoch_data_epoch_length_id_fkey FOREIGN KEY (epoch_length_id) REFERENCES public.zkapp_length_bounds(id);


--
-- Name: zkapp_epoch_ledger zkapp_epoch_ledger_hash_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_epoch_ledger
    ADD CONSTRAINT zkapp_epoch_ledger_hash_id_fkey FOREIGN KEY (hash_id) REFERENCES public.snarked_ledger_hashes(id);


--
-- Name: zkapp_epoch_ledger zkapp_epoch_ledger_total_currency_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_epoch_ledger
    ADD CONSTRAINT zkapp_epoch_ledger_total_currency_id_fkey FOREIGN KEY (total_currency_id) REFERENCES public.zkapp_amount_bounds(id);


--
-- Name: zkapp_fee_payer_body zkapp_fee_payer_body_account_identifier_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_fee_payer_body
    ADD CONSTRAINT zkapp_fee_payer_body_account_identifier_id_fkey FOREIGN KEY (account_identifier_id) REFERENCES public.account_identifiers(id);


--
<<<<<<< HEAD
-- Name: zkapp_fee_payer_body zkapp_fee_payer_body_events_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_fee_payer_body
    ADD CONSTRAINT zkapp_fee_payer_body_events_id_fkey FOREIGN KEY (events_id) REFERENCES public.zkapp_events(id);


--
-- Name: zkapp_fee_payer_body zkapp_fee_payer_body_sequence_events_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_fee_payer_body
    ADD CONSTRAINT zkapp_fee_payer_body_sequence_events_id_fkey FOREIGN KEY (sequence_events_id) REFERENCES public.zkapp_events(id);


--
-- Name: zkapp_fee_payer_body zkapp_fee_payer_body_update_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_fee_payer_body
    ADD CONSTRAINT zkapp_fee_payer_body_update_id_fkey FOREIGN KEY (update_id) REFERENCES public.zkapp_updates(id);


--
-- Name: zkapp_fee_payer_body zkapp_fee_payer_body_zkapp_network_precondition_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_fee_payer_body
    ADD CONSTRAINT zkapp_fee_payer_body_zkapp_network_precondition_id_fkey FOREIGN KEY (zkapp_network_precondition_id) REFERENCES public.zkapp_network_precondition(id);


--
-- Name: zkapp_network_precondition zkapp_network_precondition_blockchain_length_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: o1labs
=======
-- Name: zkapp_fee_payers zkapp_fee_payers_body_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
>>>>>>> origin/fix/payments-using-zkapp-accounts
--

ALTER TABLE ONLY public.zkapp_network_precondition
    ADD CONSTRAINT zkapp_network_precondition_blockchain_length_id_fkey FOREIGN KEY (blockchain_length_id) REFERENCES public.zkapp_length_bounds(id);


--
-- Name: zkapp_network_precondition zkapp_network_precondition_curr_global_slot_since_hard_for_fkey; Type: FK CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_network_precondition
    ADD CONSTRAINT zkapp_network_precondition_curr_global_slot_since_hard_for_fkey FOREIGN KEY (curr_global_slot_since_hard_fork) REFERENCES public.zkapp_global_slot_bounds(id);


--
-- Name: zkapp_network_precondition zkapp_network_precondition_global_slot_since_genesis_fkey; Type: FK CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_network_precondition
    ADD CONSTRAINT zkapp_network_precondition_global_slot_since_genesis_fkey FOREIGN KEY (global_slot_since_genesis) REFERENCES public.zkapp_global_slot_bounds(id);


--
-- Name: zkapp_network_precondition zkapp_network_precondition_min_window_density_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_network_precondition
    ADD CONSTRAINT zkapp_network_precondition_min_window_density_id_fkey FOREIGN KEY (min_window_density_id) REFERENCES public.zkapp_length_bounds(id);


--
-- Name: zkapp_network_precondition zkapp_network_precondition_next_epoch_data_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_network_precondition
    ADD CONSTRAINT zkapp_network_precondition_next_epoch_data_id_fkey FOREIGN KEY (next_epoch_data_id) REFERENCES public.zkapp_epoch_data(id);


--
-- Name: zkapp_network_precondition zkapp_network_precondition_snarked_ledger_hash_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_network_precondition
    ADD CONSTRAINT zkapp_network_precondition_snarked_ledger_hash_id_fkey FOREIGN KEY (snarked_ledger_hash_id) REFERENCES public.snarked_ledger_hashes(id);


--
-- Name: zkapp_network_precondition zkapp_network_precondition_staking_epoch_data_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_network_precondition
    ADD CONSTRAINT zkapp_network_precondition_staking_epoch_data_id_fkey FOREIGN KEY (staking_epoch_data_id) REFERENCES public.zkapp_epoch_data(id);


--
-- Name: zkapp_network_precondition zkapp_network_precondition_timestamp_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_network_precondition
    ADD CONSTRAINT zkapp_network_precondition_timestamp_id_fkey FOREIGN KEY (timestamp_id) REFERENCES public.zkapp_timestamp_bounds(id);


--
-- Name: zkapp_network_precondition zkapp_network_precondition_total_currency_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_network_precondition
    ADD CONSTRAINT zkapp_network_precondition_total_currency_id_fkey FOREIGN KEY (total_currency_id) REFERENCES public.zkapp_amount_bounds(id);


--
-- Name: zkapp_other_party_body zkapp_other_party_body_account_identifier_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_other_party_body
    ADD CONSTRAINT zkapp_other_party_body_account_identifier_id_fkey FOREIGN KEY (account_identifier_id) REFERENCES public.account_identifiers(id);


--
-- Name: zkapp_other_party_body zkapp_other_party_body_call_data_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_other_party_body
    ADD CONSTRAINT zkapp_other_party_body_call_data_id_fkey FOREIGN KEY (call_data_id) REFERENCES public.zkapp_state_data(id);


--
-- Name: zkapp_other_party_body zkapp_other_party_body_events_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_other_party_body
    ADD CONSTRAINT zkapp_other_party_body_events_id_fkey FOREIGN KEY (events_id) REFERENCES public.zkapp_events(id);


--
-- Name: zkapp_other_party zkapp_other_party_body_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_other_party
    ADD CONSTRAINT zkapp_other_party_body_id_fkey FOREIGN KEY (body_id) REFERENCES public.zkapp_other_party_body(id);


--
-- Name: zkapp_other_party_body zkapp_other_party_body_sequence_events_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_other_party_body
    ADD CONSTRAINT zkapp_other_party_body_sequence_events_id_fkey FOREIGN KEY (sequence_events_id) REFERENCES public.zkapp_events(id);


--
-- Name: zkapp_other_party_body zkapp_other_party_body_update_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_other_party_body
    ADD CONSTRAINT zkapp_other_party_body_update_id_fkey FOREIGN KEY (update_id) REFERENCES public.zkapp_updates(id);


--
-- Name: zkapp_other_party_body zkapp_other_party_body_zkapp_account_precondition_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_other_party_body
    ADD CONSTRAINT zkapp_other_party_body_zkapp_account_precondition_id_fkey FOREIGN KEY (zkapp_account_precondition_id) REFERENCES public.zkapp_account_precondition(id);


--
-- Name: zkapp_other_party_body zkapp_other_party_body_zkapp_network_precondition_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_other_party_body
    ADD CONSTRAINT zkapp_other_party_body_zkapp_network_precondition_id_fkey FOREIGN KEY (zkapp_network_precondition_id) REFERENCES public.zkapp_network_precondition(id);


--
-- Name: zkapp_precondition_accounts zkapp_precondition_accounts_balance_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_precondition_accounts
    ADD CONSTRAINT zkapp_precondition_accounts_balance_id_fkey FOREIGN KEY (balance_id) REFERENCES public.zkapp_balance_bounds(id);


--
-- Name: zkapp_precondition_accounts zkapp_precondition_accounts_delegate_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_precondition_accounts
    ADD CONSTRAINT zkapp_precondition_accounts_delegate_id_fkey FOREIGN KEY (delegate_id) REFERENCES public.public_keys(id);


--
-- Name: zkapp_precondition_accounts zkapp_precondition_accounts_nonce_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_precondition_accounts
    ADD CONSTRAINT zkapp_precondition_accounts_nonce_id_fkey FOREIGN KEY (nonce_id) REFERENCES public.zkapp_nonce_bounds(id);


--
-- Name: zkapp_precondition_accounts zkapp_precondition_accounts_sequence_state_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_precondition_accounts
    ADD CONSTRAINT zkapp_precondition_accounts_sequence_state_id_fkey FOREIGN KEY (sequence_state_id) REFERENCES public.zkapp_state_data(id);


--
-- Name: zkapp_precondition_accounts zkapp_precondition_accounts_state_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_precondition_accounts
    ADD CONSTRAINT zkapp_precondition_accounts_state_id_fkey FOREIGN KEY (state_id) REFERENCES public.zkapp_states(id);


--
-- Name: zkapp_updates zkapp_updates_app_state_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_updates
    ADD CONSTRAINT zkapp_updates_app_state_id_fkey FOREIGN KEY (app_state_id) REFERENCES public.zkapp_states(id);


--
-- Name: zkapp_updates zkapp_updates_delegate_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_updates
    ADD CONSTRAINT zkapp_updates_delegate_id_fkey FOREIGN KEY (delegate_id) REFERENCES public.public_keys(id);


--
-- Name: zkapp_updates zkapp_updates_permissions_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_updates
    ADD CONSTRAINT zkapp_updates_permissions_id_fkey FOREIGN KEY (permissions_id) REFERENCES public.zkapp_permissions(id);


--
-- Name: zkapp_updates zkapp_updates_timing_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_updates
    ADD CONSTRAINT zkapp_updates_timing_id_fkey FOREIGN KEY (timing_id) REFERENCES public.zkapp_timing_info(id);


--
-- Name: zkapp_updates zkapp_updates_token_symbol_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_updates
    ADD CONSTRAINT zkapp_updates_token_symbol_id_fkey FOREIGN KEY (token_symbol_id) REFERENCES public.token_symbols(id);


--
-- Name: zkapp_updates zkapp_updates_verification_key_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_updates
    ADD CONSTRAINT zkapp_updates_verification_key_id_fkey FOREIGN KEY (verification_key_id) REFERENCES public.zkapp_verification_keys(id);


--
-- Name: zkapp_updates zkapp_updates_voting_for_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_updates
    ADD CONSTRAINT zkapp_updates_voting_for_id_fkey FOREIGN KEY (voting_for_id) REFERENCES public.voting_for(id);


--
-- Name: zkapp_updates zkapp_updates_zkapp_uri_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: o1labs
--

ALTER TABLE ONLY public.zkapp_updates
    ADD CONSTRAINT zkapp_updates_zkapp_uri_id_fkey FOREIGN KEY (zkapp_uri_id) REFERENCES public.zkapp_uris(id);


--
-- PostgreSQL database dump complete
--

