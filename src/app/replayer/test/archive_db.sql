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
-- Name: archive; Type: DATABASE; Schema: -; Owner: o1labs
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
5	2	1	1	1440000000000	293	2mzaNmmgKfkbziZZgGhdyMjYXgpnLDSZb3zsMmR7atQudvXuXFDn	2	1	1	1	\N
5	3	1	1	2880000000000	293	2mzaNmmgKfkbziZZgGhdyMjYXgpnLDSZb3zsMmR7atQudvXuXFDn	2	1	1	1	\N
5	4	1	1	4320000000000	293	2mzaNmmgKfkbziZZgGhdyMjYXgpnLDSZb3zsMmR7atQudvXuXFDn	2	1	1	1	\N
5	5	1	1	5781000000000	293	2mzaNmmgKfkbziZZgGhdyMjYXgpnLDSZb3zsMmR7atQudvXuXFDn	2	1	1	1	\N
1	5	3	1	999999972000000000	7	2mzjg8QPpfbeaSVNyWLS3Mjv2MJqwuDEkauY5NqkzRTjdEsrWFor	1	1	3	3	\N
4	5	6	1	7000000000	907	2n1VHJxAsZy8krLNTbTocdwMh2XLEexuz1Y21QJgMVNQjDGCqhKk	6	1	6	3	\N
5	6	1	1	7260000000000	293	2mzaNmmgKfkbziZZgGhdyMjYXgpnLDSZb3zsMmR7atQudvXuXFDn	2	1	1	1	\N
2	6	2	1	1000000000000000000	30	2n28bLJpCLPYEgNqp7rQosEHQdfqSzBSjwX52jMDZbe34d9wExef	3	1	2	2	\N
1	6	3	1	999999924000000000	20	2n2PeFGTvQ8FQF41c7jXDT6xr1vrkw6qjNKBgA43GQkybtNvHx1D	1	1	3	3	\N
4	6	6	1	16000000000	907	2n1VHJxAsZy8krLNTbTocdwMh2XLEexuz1Y21QJgMVNQjDGCqhKk	6	1	6	3	\N
5	7	1	1	8739000000000	293	2mzaNmmgKfkbziZZgGhdyMjYXgpnLDSZb3zsMmR7atQudvXuXFDn	2	1	1	1	\N
2	7	2	1	1000000000000000000	30	2n28bLJpCLPYEgNqp7rQosEHQdfqSzBSjwX52jMDZbe34d9wExef	3	1	2	2	\N
1	7	3	1	999999885000000000	33	2n2Rmug7hdxZNxxAUfR8atjEstp845z9KYHK6yz9Yu8uufk4sggy	1	1	3	3	\N
6	8	7	1	999000000000	0	2n1ucTgoVjGRwNjaasJRpXEC9i1RG9ir4LaPECaWkq4GLEv1Na1K	7	1	7	5	1
5	8	1	1	10216200000000	293	2mzaNmmgKfkbziZZgGhdyMjYXgpnLDSZb3zsMmR7atQudvXuXFDn	2	1	1	1	\N
2	8	2	1	1000000000000000000	30	2n28bLJpCLPYEgNqp7rQosEHQdfqSzBSjwX52jMDZbe34d9wExef	3	1	2	2	\N
1	8	3	1	999999852000000000	44	2n1ZjK68JoT92vraKnA1UDAKuA6R8gHaVULhAForfBHZ3myh8hcK	1	1	3	3	\N
3	8	4	1	100000000000000000	1	2n16Uzkm9ABP5XHKJj81zD3EnbURJf5GykKxhNRrspMus1NNeXvL	5	1	4	4	\N
0	8	5	1	999998995000000000	2	2n1GmLyvkTHpWjhNihsqXwzM4h4MUhT4E3y78gpmBUvdAJrbiPFa	1	1	5	3	\N
5	9	1	1	11694400000000	293	2mzaNmmgKfkbziZZgGhdyMjYXgpnLDSZb3zsMmR7atQudvXuXFDn	2	1	1	1	\N
2	9	2	1	1000000000000000000	30	2n28bLJpCLPYEgNqp7rQosEHQdfqSzBSjwX52jMDZbe34d9wExef	3	1	2	2	\N
1	9	3	1	999999813000000000	57	2n1rczadFC7rjDzYmizcxtzguoSRqu8xCJj2x82xZAbafKRF94XL	1	1	3	3	\N
3	9	4	1	100000000000000000	1	2n16Uzkm9ABP5XHKJj81zD3EnbURJf5GykKxhNRrspMus1NNeXvL	5	1	4	4	\N
5	10	1	1	13160600000000	293	2mzaNmmgKfkbziZZgGhdyMjYXgpnLDSZb3zsMmR7atQudvXuXFDn	2	1	1	1	\N
2	10	2	1	1000000000000000000	30	2n28bLJpCLPYEgNqp7rQosEHQdfqSzBSjwX52jMDZbe34d9wExef	3	1	2	2	\N
1	10	3	1	999999786000000000	66	2n1J9VqmR3yPoyZUWjsCTpdqdXSmpAHUqMxDBcQHeFtGEwdTrBZ6	1	1	3	3	\N
3	10	4	1	100000000000000000	1	2n16Uzkm9ABP5XHKJj81zD3EnbURJf5GykKxhNRrspMus1NNeXvL	5	1	4	4	\N
5	11	1	1	14638900000000	293	2mzaNmmgKfkbziZZgGhdyMjYXgpnLDSZb3zsMmR7atQudvXuXFDn	2	1	1	1	\N
2	11	2	1	1000000000000000000	30	2n28bLJpCLPYEgNqp7rQosEHQdfqSzBSjwX52jMDZbe34d9wExef	3	1	2	2	\N
1	11	3	1	999999747000000000	79	2n2Gj6MfYfhndFhGfZAFALXubv6aauMfKokD4LpsgNCmiLNAwXWo	1	1	3	3	\N
3	11	4	1	100000000000000000	1	2n16Uzkm9ABP5XHKJj81zD3EnbURJf5GykKxhNRrspMus1NNeXvL	5	1	4	4	\N
5	12	1	1	16116700000000	293	2mzaNmmgKfkbziZZgGhdyMjYXgpnLDSZb3zsMmR7atQudvXuXFDn	2	1	1	1	\N
2	12	2	1	1000000000000000000	30	2n28bLJpCLPYEgNqp7rQosEHQdfqSzBSjwX52jMDZbe34d9wExef	3	1	2	2	\N
1	12	3	1	999999701000000000	92	2n1uxEN2oeB7crJZC8wmeto9a34gSNkzWgNDH4DHg7F7zA4YoKoZ	1	1	3	3	\N
3	12	4	1	100000000000000000	1	2n16Uzkm9ABP5XHKJj81zD3EnbURJf5GykKxhNRrspMus1NNeXvL	5	1	4	4	\N
4	12	6	1	23000000000	907	2n1VHJxAsZy8krLNTbTocdwMh2XLEexuz1Y21QJgMVNQjDGCqhKk	6	1	6	3	\N
5	13	1	1	17591500000000	293	2mzaNmmgKfkbziZZgGhdyMjYXgpnLDSZb3zsMmR7atQudvXuXFDn	2	1	1	1	\N
1	13	3	1	999999653000000000	104	2mzf7dwdhKgnyH6gnsBz6z5g2BqCPaBynVsyrDQUMiTPqvC2hLGu	1	1	3	3	\N
3	13	4	1	100000000000000000	1	2n16Uzkm9ABP5XHKJj81zD3EnbURJf5GykKxhNRrspMus1NNeXvL	5	1	4	4	\N
4	13	6	1	35000000000	907	2n1VHJxAsZy8krLNTbTocdwMh2XLEexuz1Y21QJgMVNQjDGCqhKk	6	1	6	3	\N
5	14	1	1	19063400000000	293	2mzaNmmgKfkbziZZgGhdyMjYXgpnLDSZb3zsMmR7atQudvXuXFDn	2	1	1	1	\N
1	14	3	1	999999609000000000	115	2n1pcaVMvXMmtdkJUaogYax4PoSXnuuS6cwcS5zGdLz36oCEDAbs	1	1	3	3	\N
3	14	4	1	100000000000000000	1	2n16Uzkm9ABP5XHKJj81zD3EnbURJf5GykKxhNRrspMus1NNeXvL	5	1	4	4	\N
4	14	6	1	46000000000	907	2n1VHJxAsZy8krLNTbTocdwMh2XLEexuz1Y21QJgMVNQjDGCqhKk	6	1	6	3	\N
6	15	7	1	999000000000	0	2n19AJ5pKqSDoLwD1SEgTbNXN4JWHm5EH8LEMHM6wFe4g2H48h8H	7	1	7	5	2
5	15	1	1	20507600000000	293	2mzaNmmgKfkbziZZgGhdyMjYXgpnLDSZb3zsMmR7atQudvXuXFDn	2	1	1	1	\N
3	15	4	1	100000000000000000	1	2n16Uzkm9ABP5XHKJj81zD3EnbURJf5GykKxhNRrspMus1NNeXvL	5	1	4	4	\N
0	15	5	1	999998990000000000	3	2mztLbfyV9TPkVi3SLrTqMrDr62Lerb8ncBoqSzvQYyXGrav9VBZ	1	1	5	3	\N
\.


--
-- Data for Name: accounts_created; Type: TABLE DATA; Schema: public; Owner: o1labs
--

COPY public.accounts_created (block_id, account_identifier_id, creation_fee) FROM stdin;
8	7	1000000000
\.


--
-- Data for Name: blocks; Type: TABLE DATA; Schema: public; Owner: o1labs
--

COPY public.blocks (id, state_hash, parent_id, parent_hash, creator_id, block_winner_id, snarked_ledger_hash_id, staking_epoch_data_id, next_epoch_data_id, min_window_density, total_currency, ledger_hash, height, global_slot_since_hard_fork, global_slot_since_genesis, "timestamp", chain_status) FROM stdin;
1	3NKTeDhZz7LPD2pWzpKGk3sV5nEDLLLa6M2ZZ6mEUpP9na6BNj1j	\N	3NKMtrvkoBuVY58qanFNo2SJA3seFavWXLAUPKv4p73Ma5kRdhpX	1	1	1	1	2	77	3100000000000000000	jwNfyVexx2Ry6iTS3915DDuazSYwQDjEADkjpBkwpCrX5hEAnGa	1	0	0	1658989920000	canonical
2	3NKEw6FjXCoSjfgK7ZcwtgpaDjgKDGqCHY6md8CpyNptdLT2iLxF	1	3NKTeDhZz7LPD2pWzpKGk3sV5nEDLLLa6M2ZZ6mEUpP9na6BNj1j	1	4	1	1	3	77	3100000000000000000	jxbuWwcUG3c39oAK5qmoMcq5LkqEYB1tUV2Hrv2DgXcP3N8VXVo	2	5	5	1658990037057	pending
3	3NLugrL88StkhCs9jeRvhc7gJNrZCgnTXh8NyqiXzXc3wUQyVLTX	2	3NKEw6FjXCoSjfgK7ZcwtgpaDjgKDGqCHY6md8CpyNptdLT2iLxF	1	1	1	1	4	77	3100000000000000000	jxh34fQ5Z4KiuAjTzs3Q3D6ZXZ3R8Uq6CEbJGhzHuAdAhAgzGXD	3	6	6	1658990040000	pending
4	3NLgynf1XG9i8dfYPu6BRQDCJ2zpjBiGAF7tEuFbnCubMi5RsHMW	3	3NLugrL88StkhCs9jeRvhc7gJNrZCgnTXh8NyqiXzXc3wUQyVLTX	1	4	1	1	5	77	3100000000000000000	jxmvn9ucxe9YMe49gSSzxQ2Dv8y1y99A8gULH8AZNhTofhouNSK	4	7	7	1658990060000	pending
5	3NLHNvy8YTLEgttez9yznA7xYc7uusdRrmd1RWqpGJjF41REySbC	4	3NLgynf1XG9i8dfYPu6BRQDCJ2zpjBiGAF7tEuFbnCubMi5RsHMW	1	4	1	1	6	77	3100000000000000000	jwBRqqNph6feP73uU1RMWE6rDdRCDtqUkFUARd6NPoWMFbNG48X	5	9	9	1658990100000	pending
6	3NKq6s6iAEb3aPn2NciixbpyruFCyM3mjqP1mfcY3NMh5Gs2RKWh	5	3NLHNvy8YTLEgttez9yznA7xYc7uusdRrmd1RWqpGJjF41REySbC	1	4	1	1	7	77	3100000000000000000	jxtfipqQY4gofKhrXmCPNWmbZywN697UPxUe4usQJkmRhF4bkng	6	12	12	1658990160000	pending
7	3NKyASEHNtX8ECifTFTkw9fX8EzRr6B5uahRaxp3DKfCyzvLBe5u	6	3NKq6s6iAEb3aPn2NciixbpyruFCyM3mjqP1mfcY3NMh5Gs2RKWh	1	1	1	1	8	77	3100000000000000000	jwFPQMNA5R4AvGfRP8GQQ2xrkvh8tkn83BquWk4fGbrp1RXsauW	7	14	14	1658990200000	pending
8	3NKk2MbDLPpUj6nZA1WNtR6gemvQwFXxQikTW3cTGRbTXZxMF77q	7	3NKyASEHNtX8ECifTFTkw9fX8EzRr6B5uahRaxp3DKfCyzvLBe5u	1	1	1	1	9	77	3100000000000000000	jxHTStb7NSNz4NB6cj9QBXjXF7297BraK4L6RaPQuNVY8mZZz5Z	8	15	15	1658990220000	pending
9	3NL3cTgLwkLx71qebseYbaZUKvgM61EodNVRBHyAvHRzX6PP4kXp	8	3NKk2MbDLPpUj6nZA1WNtR6gemvQwFXxQikTW3cTGRbTXZxMF77q	1	4	1	1	10	77	3100000000000000000	jxFgJhmXzDMCBNR9DSAqVjg5A72QjwSTAXA4yXnXoQAp4UWSxVr	9	18	18	1658990280000	pending
10	3NLaxKJWwq7HuL1h72N62UFpEEihA255v7ddK2imaM5x2TMdAigX	9	3NL3cTgLwkLx71qebseYbaZUKvgM61EodNVRBHyAvHRzX6PP4kXp	1	1	1	1	11	77	3100000000000000000	jwMrC6XSFypTAJ1WNunyiEqzdd2dLC4hBartrmAvBYo9EmwvxDL	10	19	19	1658990300000	pending
11	3NL1dFhWp9tVA2iqjMsEWyg84UkYtv6dNauXyYGieVg8c72ywgDH	10	3NLaxKJWwq7HuL1h72N62UFpEEihA255v7ddK2imaM5x2TMdAigX	1	4	1	1	12	77	3100000000000000000	jxSWLJnSsSA1M1cKBJqjvkswxSZCnQxfmxx5zwp6miEdgM8Xssy	11	24	24	1658990400000	pending
12	3NKHjC17cYGyfZz8A3Gtdbf8brHmH3WghLxBzhpnsjgKNmTmAmRr	11	3NL1dFhWp9tVA2iqjMsEWyg84UkYtv6dNauXyYGieVg8c72ywgDH	1	4	1	1	13	77	3100000000000000000	jxGqD2tJNS1Tq4m96i88NBWD1iJLszkzvaJuUBnjGyQLqew29N9	12	25	25	1658990420000	pending
13	3NLhtQMBnyGzDbzfN1LpxUuAKJW9DJgEH8WW5VxkCYEKXfaZcMoU	12	3NKHjC17cYGyfZz8A3Gtdbf8brHmH3WghLxBzhpnsjgKNmTmAmRr	1	4	1	1	14	77	3100000000000000000	jxA9fRykixLWQzLyUw9bMLbi9eKqrptmPFEY8X2DskaGwYuZFdW	13	26	26	1658990440000	pending
14	3NKo4fgtu7waxo1mfSh724SYuRR4KxeqnmsE92ep6SZh8ufkMc4m	13	3NLhtQMBnyGzDbzfN1LpxUuAKJW9DJgEH8WW5VxkCYEKXfaZcMoU	1	4	1	1	15	77	3100000000000000000	jwMM53ZhyHxRwU2SKA3EcGSbUgttXZCjjpG6ZvpBqR52RhGYt76	14	29	29	1658990500000	pending
15	3NKrka2Y9C3mfevcJ3qqTMoLYD3wUvCzreMTYh6ZZWqQnz86zbCV	14	3NKo4fgtu7waxo1mfSh724SYuRR4KxeqnmsE92ep6SZh8ufkMc4m	1	1	1	1	16	77	3100000000000000000	jwPnpRU1rJzRfd1CnHdAo4UDBacmHXF53J15bUXW8pf5TXMvQvp	15	32	32	1658990560000	pending
\.


--
-- Data for Name: blocks_internal_commands; Type: TABLE DATA; Schema: public; Owner: o1labs
--

COPY public.blocks_internal_commands (block_id, internal_command_id, sequence_no, secondary_sequence_no, status, failure_reason) FROM stdin;
2	1	0	0	applied	\N
3	1	0	0	applied	\N
4	1	0	0	applied	\N
5	1	7	0	applied	\N
5	2	8	0	applied	\N
6	3	3	0	applied	\N
6	1	14	0	applied	\N
6	4	15	0	applied	\N
7	3	3	0	applied	\N
7	1	14	0	applied	\N
7	4	15	0	applied	\N
8	3	3	0	applied	\N
8	5	13	0	failed	Update_not_permitted_balance
8	6	13	0	applied	\N
8	7	14	0	applied	\N
8	8	14	1	failed	Update_not_permitted_balance
9	9	4	0	applied	\N
9	5	14	0	failed	Update_not_permitted_balance
9	6	14	0	applied	\N
9	10	15	0	applied	\N
9	8	15	1	failed	Update_not_permitted_balance
10	9	4	0	applied	\N
10	5	10	0	failed	Update_not_permitted_balance
10	6	10	0	applied	\N
10	11	11	0	applied	\N
10	8	11	1	failed	Update_not_permitted_balance
11	12	8	0	applied	\N
11	5	14	0	failed	Update_not_permitted_balance
11	6	14	0	applied	\N
11	13	15	0	applied	\N
11	14	15	1	failed	Update_not_permitted_balance
12	15	8	0	applied	\N
12	16	8	1	failed	Update_not_permitted_balance
12	5	14	0	failed	Update_not_permitted_balance
12	6	14	0	applied	\N
12	13	15	0	applied	\N
12	14	15	1	failed	Update_not_permitted_balance
13	15	8	0	applied	\N
13	16	8	1	failed	Update_not_permitted_balance
13	5	13	0	failed	Update_not_permitted_balance
13	6	13	0	applied	\N
13	17	14	0	applied	\N
13	14	14	1	failed	Update_not_permitted_balance
14	18	9	0	applied	\N
14	16	9	1	failed	Update_not_permitted_balance
14	5	12	0	failed	Update_not_permitted_balance
14	6	12	0	applied	\N
14	19	13	0	applied	\N
14	16	13	1	failed	Update_not_permitted_balance
15	5	1	0	failed	Update_not_permitted_balance
15	6	1	0	applied	\N
15	20	2	0	applied	\N
15	8	2	1	failed	Update_not_permitted_balance
\.


--
-- Data for Name: blocks_user_commands; Type: TABLE DATA; Schema: public; Owner: o1labs
--

COPY public.blocks_user_commands (block_id, user_command_id, sequence_no, status, failure_reason) FROM stdin;
5	1	0	applied	\N
5	2	1	applied	\N
5	3	2	applied	\N
5	4	3	applied	\N
5	5	4	applied	\N
5	6	5	applied	\N
5	7	6	applied	\N
6	8	0	applied	\N
6	9	1	applied	\N
6	10	2	applied	\N
6	11	4	applied	\N
6	12	5	applied	\N
6	13	6	applied	\N
6	14	7	applied	\N
6	15	8	applied	\N
6	16	9	applied	\N
6	17	10	failed	Update_not_permitted_balance
6	18	11	failed	Update_not_permitted_balance
6	19	12	failed	Update_not_permitted_balance
6	20	13	failed	Update_not_permitted_balance
7	21	0	failed	Update_not_permitted_balance
7	22	1	failed	Update_not_permitted_balance
7	23	2	failed	Update_not_permitted_balance
7	24	4	failed	Update_not_permitted_balance
7	25	5	failed	Update_not_permitted_balance
7	26	6	failed	Update_not_permitted_balance
7	27	7	failed	Update_not_permitted_balance
7	28	8	failed	Update_not_permitted_balance
7	29	9	failed	Update_not_permitted_balance
7	30	10	failed	Update_not_permitted_balance
7	31	11	failed	Update_not_permitted_balance
7	32	12	failed	Update_not_permitted_balance
7	33	13	failed	Update_not_permitted_balance
8	34	0	failed	Update_not_permitted_balance
8	35	1	failed	Update_not_permitted_balance
8	36	2	failed	Update_not_permitted_balance
8	37	4	failed	Update_not_permitted_balance
8	38	5	failed	Update_not_permitted_balance
8	39	6	failed	Update_not_permitted_balance
8	40	7	failed	Update_not_permitted_balance
8	41	8	failed	Update_not_permitted_balance
8	42	9	failed	Update_not_permitted_balance
8	43	10	failed	Update_not_permitted_balance
8	44	11	failed	Update_not_permitted_balance
9	45	0	failed	Update_not_permitted_balance
9	46	1	failed	Update_not_permitted_balance
9	47	2	failed	Update_not_permitted_balance
9	48	3	failed	Update_not_permitted_balance
9	49	5	failed	Update_not_permitted_balance
9	50	6	failed	Update_not_permitted_balance
9	51	7	failed	Update_not_permitted_balance
9	52	8	failed	Update_not_permitted_balance
9	53	9	failed	Update_not_permitted_balance
9	54	10	failed	Update_not_permitted_balance
9	55	11	failed	Update_not_permitted_balance
9	56	12	failed	Update_not_permitted_balance
9	57	13	failed	Update_not_permitted_balance
10	58	0	failed	Update_not_permitted_balance
10	59	1	failed	Update_not_permitted_balance
10	60	2	failed	Update_not_permitted_balance
10	61	3	failed	Update_not_permitted_balance
10	62	5	failed	Update_not_permitted_balance
10	63	6	failed	Update_not_permitted_balance
10	64	7	failed	Update_not_permitted_balance
10	65	8	failed	Update_not_permitted_balance
10	66	9	failed	Update_not_permitted_balance
11	67	0	failed	Update_not_permitted_balance
11	68	1	failed	Update_not_permitted_balance
11	69	2	failed	Update_not_permitted_balance
11	70	3	failed	Update_not_permitted_balance
11	71	4	failed	Update_not_permitted_balance
11	72	5	failed	Update_not_permitted_balance
11	73	6	failed	Update_not_permitted_balance
11	74	7	failed	Update_not_permitted_balance
11	75	9	failed	Update_not_permitted_balance
11	76	10	failed	Update_not_permitted_balance
11	77	11	failed	Update_not_permitted_balance
11	78	12	failed	Update_not_permitted_balance
11	79	13	failed	Update_not_permitted_balance
12	80	0	failed	Update_not_permitted_balance
12	81	1	failed	Update_not_permitted_balance
12	82	2	failed	Update_not_permitted_balance
12	83	3	failed	Update_not_permitted_balance
12	84	4	failed	Update_not_permitted_balance
12	85	5	failed	Update_not_permitted_balance
12	86	6	applied	\N
12	87	7	applied	\N
12	88	9	applied	\N
12	89	10	applied	\N
12	90	11	applied	\N
12	91	12	applied	\N
12	92	13	applied	\N
13	93	0	applied	\N
13	94	1	applied	\N
13	95	2	applied	\N
13	96	3	applied	\N
13	97	4	applied	\N
13	98	5	applied	\N
13	99	6	applied	\N
13	100	7	applied	\N
13	101	9	applied	\N
13	102	10	applied	\N
13	103	11	applied	\N
13	104	12	applied	\N
14	105	0	applied	\N
14	106	1	applied	\N
14	107	2	applied	\N
14	108	3	applied	\N
14	109	4	applied	\N
14	110	5	applied	\N
14	111	6	applied	\N
14	112	7	applied	\N
14	113	8	applied	\N
14	114	10	applied	\N
14	115	11	applied	\N
\.


--
-- Data for Name: blocks_zkapp_commands; Type: TABLE DATA; Schema: public; Owner: o1labs
--

COPY public.blocks_zkapp_commands (block_id, zkapp_command_id, sequence_no, status, failure_reasons_ids) FROM stdin;
8	1	12	applied	\N
15	2	0	applied	\N
\.


--
-- Data for Name: epoch_data; Type: TABLE DATA; Schema: public; Owner: o1labs
--

COPY public.epoch_data (id, seed, ledger_hash_id, total_currency, start_checkpoint, lock_checkpoint, epoch_length) FROM stdin;
1	2va9BGv9JrLTtrzZttiEMDYw1Zj6a6EHzXjmP9evHDTG3oEquURA	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	1
2	2vc1zQHJx2xN72vaR4YDH31KwFSr5WHSEH2dzcfcq8jxBPcGiJJA	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKMtrvkoBuVY58qanFNo2SJA3seFavWXLAUPKv4p73Ma5kRdhpX	2
3	2vbdSF4zisaadfFJeWR8x2qMVKs2GVdCunc11HhaecHxw9yA3CuU	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKTeDhZz7LPD2pWzpKGk3sV5nEDLLLa6M2ZZ6mEUpP9na6BNj1j	3
4	2vaozPzaRvM1i5fNbEFLz7NXVake8EJDGzdQ1WnDPbkJQkQoRV7M	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKEw6FjXCoSjfgK7ZcwtgpaDjgKDGqCHY6md8CpyNptdLT2iLxF	4
5	2vakXZ5oEMTmWhjpVy6GgYXtvTkiSpVzr9MYqXCzaYcVYXDfGV4R	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLugrL88StkhCs9jeRvhc7gJNrZCgnTXh8NyqiXzXc3wUQyVLTX	5
6	2vatu8cWuYX37YAAQEoqSVibYukVZzbc4f6kQGmLRSe7mik5cS6C	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLgynf1XG9i8dfYPu6BRQDCJ2zpjBiGAF7tEuFbnCubMi5RsHMW	6
7	2vb1mCgRBZ4TccnMwda6784sbr5x3JrH2wUxPdPgcjCYfsi9Tkmw	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLHNvy8YTLEgttez9yznA7xYc7uusdRrmd1RWqpGJjF41REySbC	7
8	2vaYVVVg5FGLBTULXX3FXwWE4vSbUD4ScCyDbN5pKjgN5jPxSJQ4	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKq6s6iAEb3aPn2NciixbpyruFCyM3mjqP1mfcY3NMh5Gs2RKWh	8
9	2vbKUnmtxuiK1gfzQ7fkkgtvbkDWuNXNi8dtMEsTBMENpUAq1pzB	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKyASEHNtX8ECifTFTkw9fX8EzRr6B5uahRaxp3DKfCyzvLBe5u	9
10	2vbHhmDA6XzxhErXkQPh6WvTyCU4esi6j45hhDC1u72tWKdXDdFs	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKk2MbDLPpUj6nZA1WNtR6gemvQwFXxQikTW3cTGRbTXZxMF77q	10
11	2vb6LykVWfxEcvqTuwxD6nX59iHpTCD7a9vFzJAZ53M1qPy97Nq3	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NL3cTgLwkLx71qebseYbaZUKvgM61EodNVRBHyAvHRzX6PP4kXp	11
12	2vbi7WWckR3BdCKYkvwJtyMtXa2CVQW64db4tSNcPMLe7p7FFaiJ	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLaxKJWwq7HuL1h72N62UFpEEihA255v7ddK2imaM5x2TMdAigX	12
13	2vbECqurbSLfcesdqAV3KLSzPSezrEWfmomWrDCXTAHK2p8XXwCa	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NL1dFhWp9tVA2iqjMsEWyg84UkYtv6dNauXyYGieVg8c72ywgDH	13
14	2vc1AAq8NeAU3nMpHrxrUqz74y2nH5cuyzcQg4cwsaJC3AVuStsm	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKHjC17cYGyfZz8A3Gtdbf8brHmH3WghLxBzhpnsjgKNmTmAmRr	14
15	2vbhSGerb5c68sw16RDd2dGAQpm1xBVJr9bAN5495XS3z1cQn2kw	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLhtQMBnyGzDbzfN1LpxUuAKJW9DJgEH8WW5VxkCYEKXfaZcMoU	15
16	2vbetd78qD5nAvE2Mqd7sZGQ4XCvFHzYYeA9hUHGqgmHMdgCk3Yq	1	3100000000000000000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKo4fgtu7waxo1mfSh724SYuRR4KxeqnmsE92ep6SZh8ufkMc4m	16
\.


--
-- Data for Name: internal_commands; Type: TABLE DATA; Schema: public; Owner: o1labs
--

COPY public.internal_commands (id, typ, receiver_id, fee, hash) FROM stdin;
1	coinbase	1	1440000000000	CkpZgubXr8RCo6SCYfqdctw9y4ryUUZbEH6c3cjfuWfisZ7cF9WbE
2	fee_transfer	1	21000000000	CkpZBoNL26bUcAdLfeg5PNNfTyWY9qkz5tuQVYcwSqWzMH43MjxBu
3	fee_transfer	1	9000000000	CkpZLZY5SNCVJiHpr1AVDr7X33fCs4dTntVFWMUM15hXYPR4ViiXT
4	fee_transfer	1	30000000000	CkpaAkCN2548ptUCvBhVyybMEnYsgpex3EVUHpjUzKsq6ocgP3VYT
5	fee_transfer_via_coinbase	4	100000000	CkpZkSM8yKVc23adGsNnn4FBXQS7sqHKkgAjpiZorvCSNNzEYYKP3
6	coinbase	1	1440000000000	Ckpa8gbdvf1ptoND7j6PiffqTrjUkxpJJ3V6whc8ZitiZpL4gU5mL
7	fee_transfer	1	28300000000	CkpYnQdg7LSdhFjmoEuT98dM5HVTNxuyjh9b7FcAUuWoQNZffghnK
8	fee_transfer	4	700000000	CkpZJfrL5GumP4TJj93Yjvoo5CipxrHjLCyHvCjY9JzLyH7chD5hJ
9	fee_transfer	1	12000000000	Ckpa9u2wCk8bvxVg6sVabhDPLm3WtxTiSi4p7oPHQkjvghxrsS2eK
10	fee_transfer	1	26300000000	CkpZQzyPi7j8j7PF97jsLMgXVJar9W7ReaBZ9NAXHQiJUbsNSpLm3
11	fee_transfer	1	14300000000	CkpYgs5wBm87qgfScF3ybDZjM1PhKMEfvUGVAGxukQ3VnYsGX8c7T
12	fee_transfer	1	24000000000	CkpYkasBTkTp97QiMnQdF1JQLpGk1HLY4SYkPw2BiETGHmkiZWKzY
13	fee_transfer	1	14400000000	CkpZEA531idkyAecCmY6F18sJQdKrZJ85bmcjH9nrT16q3P1HDjak
14	fee_transfer	4	600000000	CkpZhGoeKoEWHVb1Q4NKWhg3R9cTVLpxLyqQg7LDND27MrLUMWxak
15	fee_transfer	1	23500000000	CkpYXc7uaDQAFsUe4hQUCs4BivFptPpmDJj1x3KSxNzMpsNcKfKd2
16	fee_transfer	4	500000000	Ckpa6dM5e3ASgSuJYu9Qi1LWBvJBRTXe1BX1XGQEjuzWmuptj3j2d
17	fee_transfer	1	11400000000	CkpYsNPUJVmnrcCshv3PMXrN3Aq9CKr7Fd3cb2vN885TcCxweHhiW
18	fee_transfer	1	26500000000	CkpYZFwHTcMLzFTMXwiVe2FHaDh5y28uZX3QptkKtbnn7DycQ9ws5
19	fee_transfer	1	5500000000	CkpZpc4eifYzfKhLevAbScmwBkrvYLjA1fr5T431vQBPkegrvdfuR
20	fee_transfer	1	4300000000	CkpZBo21DjGLgJ6YYmb56uHKGrBH58MyPsJjjiipMLMMY38J2SkN6
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
7	B62qiZBzpLcVgt3DcMt6ctkuTzc4btyjRCwBvvZxvBNdq1ZKnq5tHAE
\.


--
-- Data for Name: snarked_ledger_hashes; Type: TABLE DATA; Schema: public; Owner: o1labs
--

COPY public.snarked_ledger_hashes (id, value) FROM stdin;
1	jwJKgjz7e3UbWXysSLTqiSSL3Z6FSfbV57js1ySugJqKw9kEdxb
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
1	payment	3	3	6	0	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZTYZsyKu7kWEenM8oxoP7eeX4N1ch3c3PGTzL64piTqzpUPFKj
2	payment	3	3	6	1	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	Ckpa9741LZwxhTbxRZDXMD1sP9Fv9GKPPzyScMGGQbYzQhnyZRE3d
3	payment	3	3	6	2	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZxuTRkVCfHpkhoSXnUM8Lc5jQSZ7B52Nb11a4a2b1f157H3bhG
4	payment	3	3	6	3	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpaGumXS1agYM5JjkTasBxNRzHEnTmZRHKavEnpnFDFMp8PvhYVZ
5	payment	3	3	6	4	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	Ckpa2evQBPYkxNFgyo5o4RC3GXzRmbR4PRe44Fb3S6XV7Eray9azA
6	payment	3	3	6	5	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYvJahzUDBCiGg7avzwRaKg7XcF6f39dcZS5sKHdiD4M25pMyX7
7	payment	3	3	6	6	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZjGLdBhE2wnbhTt55myG4cnf1hcjq9Hr3m4Mq7TqKn3Lq6xogA
8	payment	3	3	6	7	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZNuWsB1HZGHakSzKmCpRC9NATevMtaRH4u3xDo3hyTAgzEbwob
9	payment	3	3	6	8	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYsuFyKhRWvSgGb6Q7tbtpas2YfP8GXNr2Mhqvfss46G3Lrx5pZ
10	payment	3	3	6	9	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZE4Ezu8CC1KVyQf83iRA6fteyrCUq8MzmWMS19BQQ62kJxvZyD
11	payment	3	3	6	10	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpaET8ZTn8dWPZCUGM12kHQpLx13KboE5yQ98QmgRHuSt4NHuWP3
12	payment	3	3	6	11	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZdGDeYmmJi7y4sCBH75NETjWBwmDq9xBHYUCBhmuMsXFG2aQmj
13	payment	3	3	6	12	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYS8iS5mVLLXehD5b3MAtqUUK3Ap3Epb4F3AXKBbvpAAcrjP4eg
14	payment	3	3	6	13	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZPktx2rE1oPN684dBnoGuzZMCCLewC2XDizhjUwbdCRoq9TNhi
15	payment	3	3	6	14	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZh9z9MQCP2xhgFv5X9EgF9QHc2fhkG8zgVsz1EtQDhoh1hDDuN
16	payment	3	3	6	15	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYcfwsTarahfHnfkYjX5XoFNa9eu48yYLC9dMtzdtdcwy5utF5b
17	payment	3	3	2	16	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYYUwC8kUn2kyy8mVDgP4zMw1afTFMB9Lkd26sKsaZuvgyS1J73
18	payment	3	3	2	17	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZjvoHBQZVgfub1Z19rmLMHannBd4pWymgdrPPboNgetcbdVBsz
19	payment	3	3	2	18	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZqnuidyg4XJHy2YLw6orBoWbUa9ckAcXZXx9xqpbXrqJa287AK
20	payment	3	3	2	19	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpaBZigiVKa5Luw3Xh37WxuZbes51zKKfjdUMYmjYUMq9TtBCKdR
21	payment	3	3	2	20	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZHFvirbnwxzwAhxBB43o9m7qn1jQfXkqvQ2XNBwZuxNn55Hr3x
22	payment	3	3	2	21	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZcCg2TiHvBJNZTWsFBELrPYEtVLkrDgQ8idjYvMbPBNdHV2JkF
23	payment	3	3	2	22	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZszUP95wkgZdFmeFUUrwDCfRQye3YDTzhC82CqwLoDvE1sRMcr
24	payment	3	3	2	23	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYgqorucr16MnviAW5awRG24rwoc1d5cehF5me3mmX3h4z3w8UW
25	payment	3	3	2	24	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZRMc9jsTVKQUvZdzSgzGhSxZWaDuh19U2Hhdceocn9rSVPRK61
26	payment	3	3	2	25	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZPGjgaEpf5dgtW6tT1wKbr1zVaSM8R5mYukyqQr7Jva1T3CFXL
27	payment	3	3	2	26	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZBxPxxQzJhLy4UBKbfzJMQJQHjKf3zjEhNUTEGHhsSMNpgVz8g
28	payment	3	3	2	27	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZN7upPbkW2cjg73UVBgpEsuMzrTDzoSQzFzjPM8WYTtrqEjGS2
29	payment	3	3	2	28	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZZBNk8prW7ErFqZgF2RHoY2KLLkXXxnV52J8FCvNUjbYtY31LH
30	payment	3	3	2	29	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZ1Qe2vtZG5T8yyanBEj8wsfh8gRiWqNpefWTeJbau8HRaYTMgp
31	payment	3	3	2	30	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpaFat1E9FRgxV4VNgir7eenuy2XjMMuNow5e1YCEDXBfLEbYXEj
32	payment	3	3	2	31	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYV1BnoWgYodwGkGj6t4Pgf8QNKg8tHbcKEiSW4dPgqu3UgDgqp
33	payment	3	3	2	32	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZT8CsDmLadKt4CR39kLuJXRCC8kRgYVZYcHz1H3VaAt7YLFKCB
34	payment	3	3	2	33	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZMNCQvXncMt3nHsqbLyBZ5AqUwRdY7Xdpabk49iNbG1LYRDu1v
35	payment	3	3	2	34	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZESaniLfPVmB4ShykhpUFMR7c67udbm5vGhPugCUj4aAKuxWca
36	payment	3	3	2	35	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZ1he8SfJeamKhoZV1yZU1Dacu3kVMz5WNJNbZnS1CdK2wYiYV3
37	payment	3	3	2	36	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZnneB6XbPvoaKzzLZumq9JepuJx9fwbs8kgTkGVfnZ5VbeSKF3
38	payment	3	3	2	37	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	Ckpa7VjVSkMDFVpjrBQwDmiTEUivDe7r8pN5kdW7rFKrGZXqGGNm3
39	payment	3	3	2	38	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZRhFxHfYYrJHPwVpjiyEHkGgpocfUtp8aRHZXpsHGNbduNPMHE
40	payment	3	3	2	39	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpaGfykqy7hcDbmhnYYATbgufEuYMLieKbgqpvi6tZPsyvArkqBS
41	payment	3	3	2	40	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpaGSZ93fX7pT9gknGCMaLzWQFgiu2JLSaZcCYvS9DfBK6Eh91Db
42	payment	3	3	2	41	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	Ckpa98XL6KrGnSKCQJx7aKYExawyE9FNuRw44EKdkyRP738hys9LE
43	payment	3	3	2	42	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZGtSKKYYtFZ7ZirhPp2x3zkvd5TfCs6wmoFGjXqhNaghWWw4T9
44	payment	3	3	2	43	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZdYcaoPv33kP1wy3A55LN8Z91hyCKVYwpPsvWVerWACRYHwEeY
58	payment	3	3	2	57	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYf2rFeWy9Lfvj75nV9LDfunfqiiyNhbxFL59jmmyPR4eWoctPr
59	payment	3	3	2	58	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZAPYQfLnmvx4aoA3KudU5vMCaicnu1nibaq4QbBcexnnfTxXXj
60	payment	3	3	2	59	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZJfywBUkGfdXEikja4TVV29wJhPxQCBXsjpT3DTX1QHUmG46Y3
61	payment	3	3	2	60	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	Ckpa6yyVwVKdxFXBJkLo4a8867WHWJuesB5zqCsZhLLVMjPD1MVEg
62	payment	3	3	2	61	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZP67vpWEVx1yG7bDHM45hhGy25LdRhXX7n3Ef3n21JTySycHaJ
63	payment	3	3	2	62	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZZXRkWQxdHKFwo96tMZ4Bo2dHc1CoZT13VEcEWe1THv6Nrj1uh
64	payment	3	3	2	63	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYuozvAckm6UMgpmsyf71zg8rjezAMUdafc7i6pwq8yhCgokpnR
65	payment	3	3	2	64	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZNYc6KB1V7KytiguYjQQHfBJo4CDyE4NPHMbbV6rysTPuUEeuE
66	payment	3	3	2	65	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZHwgDaaaF55HraCtHdsghn1aACv165xyffdCCiRgxvrEEh44mr
45	payment	3	3	2	44	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZoRLnJtgbykrZ5YxwCUPxGAvifU7gKGNwMnXHGwFb4q3g8Luri
46	payment	3	3	2	45	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYiCdE6eVtRkZFqkkwMKYt9wnXn1NikTReG6uaph2SvJCfcNR6M
47	payment	3	3	2	46	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYqGFJ8aRR6sp7PwumVJ5MXs5BHa2vSoD5CN5TjEwYQj43nbiEm
48	payment	3	3	2	47	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYSk1F465zY4NvuRgA5kAFqK2rXfjnvWsEbNXPk6nddz38fJRiR
49	payment	3	3	2	48	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZCm93DDCE3PKYXLYsySWX6h52ou4btTo7Z7fGHAbXN4Sx7mc8n
50	payment	3	3	2	49	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpaDbHNsNd1GbzxpWiH8vPoLhH8sd9zX7YUwH5W3U1j34FaD2KEJ
51	payment	3	3	2	50	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYpTPN7fju4SjevvtDzGkxv3nDZUqB33VVCF9A7Ugz2v2DDtcF3
52	payment	3	3	2	51	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZ5DN74BgQufhg5jvfLu5DTxEjyTrTit9XwUTjrpozumQnzcBn3
53	payment	3	3	2	52	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYoVeWoXG2efdtoBpkkJKuvh2AwqqXpGPYEGqjyCcQ7j1RPUMx5
54	payment	3	3	2	53	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZ7uSBJh4hZKXuzQLUQGJVB88HMFMZjhwieBk3kVNGvGQvLkPQv
55	payment	3	3	2	54	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZKL7pPkRdUbtzbqSS5eP1WtXPMDQJhrqb737Yu9bYfMp4UmBL7
56	payment	3	3	2	55	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYZbWvTFwPbiFaEonLwJE8qcDbasis7M35wPPZWcPBYurHcDttk
57	payment	3	3	2	56	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZ6sNzAHoVbkba7DhEGZM1SgfGXwxifhYoQaLtsnHc9eienRJsz
67	payment	3	3	2	66	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYYTFabHY7pRa2AavGYaDFD5witioGPXYBj39A2MZoVno13SBFJ
68	payment	3	3	2	67	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYeTLC1R5KjcEd2Rme99kx6ejPP6SQYNRooEYwqTqAy5BZdKrcb
69	payment	3	3	2	68	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZXeHXLAD8tMj8BsnwoxmMLiBizSK1UTRif66vZ28kWfZNprkWD
70	payment	3	3	2	69	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZDgBqyLXePn2UCfkFP7bZj1cBnXvquMi6gAtNx5M6H9VBV8s6C
71	payment	3	3	2	70	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYvu4gqYUYWxm5yTAFbQR1J7FP9v5ip9G2jHxAgnMKf8uJAjKME
72	payment	3	3	2	71	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYTyuKvC8hvrD5PQkET2oHQqc4xKQp4KzyHv9nwefqnSLxetTfm
73	payment	3	3	2	72	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	Ckpa7KMVb8Ar93wtpLHVMxgVLhhn6FXHHcm7469beEdMxJ4doqbKM
74	payment	3	3	2	73	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYtBDSvQSwpJC2DZnZSy9DyqApEj17rAgHc7bUx6bRLaBEeStaQ
75	payment	3	3	2	74	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYmq4CpN5dRJwoNzuaZGNzCcefoSAeZqbREpQibtMNtuA6B2nCj
76	payment	3	3	2	75	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZeVvQ8AYAJe5sAYaL6dWib5MgXyQszTjVZVH9SsKKY5WbnpVRH
77	payment	3	3	2	76	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYbPCRxXFHrB3UbTSyxP13kpxPm78vk9BFPhZLjG5wBFqcApLvk
78	payment	3	3	2	77	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZkuv7QQtyThN3gDBXHpvCqp5mH28EwePF7ntp6szwApcLpmboe
79	payment	3	3	2	78	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYSg98GbYs9DLrm4ZZVjzmJSuP18TmxhbSrXrzbNneZxgfK7jNF
80	payment	3	3	2	79	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZpWg2gS3ERr7nPh5FAnB7jCiJSP8HhRQQR5CYHbGAeCWd2DBui
81	payment	3	3	2	80	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZiJ2sGjEpmfDxXDdYReGB8V6Qvr29tjLfyNYELVDFQU7knpVhd
82	payment	3	3	2	81	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZyW7yuCLBxUoPxMYQiMQbJonS7DdTnqnbZcDEhUa6uREVdfeuk
83	payment	3	3	2	82	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	Ckpa8KQFhb3m63RWjfwkGkgRQ8Ga29epZ5jqBSLrRq5KMptVm9pyf
84	payment	3	3	2	83	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZ5MsNbY46tTkVup9UGJBEJWhA7p1PwNzvVA3LNBGr3iBx3vJ5N
85	payment	3	3	2	84	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYfYtfRWWi8DzH8PTwxxmjRqbLW3jHGepWJyB2ycbqGrc9Svd9f
86	payment	3	3	6	85	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZtdyyieHNsk7D7L6zUznhms9xzpJLJHYu2nqgnq7uduvgQoURf
87	payment	3	3	6	86	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZ1kD1GP5vCWT2j7XcytjPWzUo8n1P4wwo4c14CA5esgaiLmgZm
88	payment	3	3	6	87	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZ8CjyHB5PvTdcqmCDQtGGpLPcLVvFP55SVc8J3nWKtfrNmiXXZ
89	payment	3	3	6	88	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYdR6uP6BcXJ1Ai4o6TYjBDr1rSHYqVqZHwKHrN4ZvAzzA7JxNG
90	payment	3	3	6	89	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYT8LpyGDWFF7btiFjhNQKktQXXJZjGoCAzSKrDASMySQCxuZC9
91	payment	3	3	6	90	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZS1c9pfsVqzGt7JE8Jsdr9bUwna5FgSJRa5XAFYrvygiR5JNR3
92	payment	3	3	6	91	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYc4eL6WSQixh1HYNNHLP8nsk5XFYvaUbToHQFCkf5r3P6jMb9U
93	payment	3	3	6	92	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYkTerFFqx5Y3jjYN5tQpK8TyE2tsMSs2sby8J34gdFkSyPYwEn
94	payment	3	3	6	93	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYtFZCLGZCaFUSHYWWzATNVNVmW14vR8GoLJB4QwmwEEUNoh5zc
95	payment	3	3	6	94	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpaHNuW643aLze2VkJQN33qeV2WYYxHKKFFpKFEj7QWCX8H9Giyj
96	payment	3	3	6	95	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYw56wC1aYn3ngDnsqtymr3ezuyzhJBtakPtcbgbvA2Mw1yzEe8
97	payment	3	3	6	96	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYnVwZ5Rm6cFdS1wp6dAsu1ex1b5v5kuN3dcmLjzG7JspLq7gop
98	payment	3	3	6	97	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYsCfxUDozmYv6E2cP5xWr3FqzV8L7VTFTy44N6RxRf68EXxAzi
99	payment	3	3	6	98	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	Ckpa39QfZxZA2zN25TpX4KYJxmEriGnCbbhrasPLmHkdUECTpwxQQ
100	payment	3	3	6	99	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	Ckpa2ZkDqvdBCNnQVkJmXmNtjMiUn1ruYuCyLQWfLcyPAMd2znrqh
101	payment	3	3	6	100	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZUsrsKYU1SpGQppKCBuQ4Q9KBvazJomrvBjQMtPeHxkVgQVcPM
102	payment	3	3	6	101	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZpfELkPzhjBL4x4taaVQfN84xMJsv4S2aTqFAoENBZehovcUxY
103	payment	3	3	6	102	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZLsTZJjsFSEzaHUNHnaS1KTh3GM2L1unPpF54cb14WkLqeBTkD
104	payment	3	3	6	103	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZoqHTWFRFoBeUT9vwJpLdFwHp5bYfoBtAqbQw6FMJ7tCMKUcwk
105	payment	3	3	6	104	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZCF6sdSvrbGzrqTXfWL934GLg9nqDU6Bxc9hJFyrbsx6B5VLTH
106	payment	3	3	6	105	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpaHYiSKCDg8hQ2xChws1rxMcNEvXG3hzwnvPCxibYUgWP96QcQk
107	payment	3	3	6	106	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZKSTMTbvCJoAY7CbuU6MH1tM6m4Tygzm2EXUfxey56dbo8m5SU
108	payment	3	3	6	107	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYgpphssmcAijQo8SRqN8FcX2U7ThUHoxf2EgKXCHMN9HbxKrZe
109	payment	3	3	6	108	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZqmGEbaqM2CG4pkvbf4KHGJnHDfFXzqk51swnboWPuWX5oby1a
110	payment	3	3	6	109	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpaDfWXxouMNPBQdxX7qpAnZzQYHaxZY8gt55vWUg33uiW7JrGp8
111	payment	3	3	6	110	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpaBZGtmyChE4t8RgS5g2GNV6qJxw8tCnuHiXK5HP11zckEqEeXx
112	payment	3	3	6	111	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZp5TMzSNiWePpNitPmH4J2FAPmUBGtbF4jAETiH2k3y28cZdCj
113	payment	3	3	6	112	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYq3NDmLLbhh5jGbyUExfky36WLiPhBqH9kXUQ723c1aVZp5TMT
114	payment	3	3	6	113	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZD1f98SCwNb1GKGWDbf8HyYC89qobzoQ6qJ3mtCBwZojj5ZnMS
115	payment	3	3	6	114	1000000000	3000000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpaGvKtsskNrA85BcsJqQQdVmTxHsFgEm8PXyjTbeb5i93hoXKNt
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
1	1	{1,2}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpZARwGvgC8RKzW39BnDKjhZrmhKf6ZBvtRtaBPtrzmcwXdcGoMm
2	2	{3}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	CkpYR8sbwegG3dSCnN52apBTNejwyt27ZudE9h5rLoD7BD19e74Jn
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

COPY public.zkapp_fee_payer_body (id, account_identifier_id, fee, valid_until, nonce) FROM stdin;
1	5	5000000000	\N	0
2	5	5000000000	\N	2
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
1	5	1	-1000000000000	t	1	1	1	0	1	1	f	call
2	7	2	999000000000	f	1	1	1	0	1	2	t	call
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

COPY public.zkapp_precondition_accounts (id, balance_id, nonce_id, receipt_chain_hash, delegate_id, state_id, sequence_state_id, proved_state, is_new) FROM stdin;
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
1	AmMmE/B7x2NWVWhlCFRrdpakPkaYmQAnkKke9Ds99bQu0mUA+xBWIaVqE5TVuIfXob5+Z/m182CzBZGjw6y8FzpxLhW5bZbiVJRspN+UXM0lPPMuPf2h0tmoks7SdJkDMaskhZLHI5djZMU8D7iV+ZtIR9hPZroKmMSn7stsLLkXpunJjfbpvKO3aNCUz78lbD+GHXZWgPXVIo4N/8aYYBP1I7PlSWgvKykt9+YrY5l3KlR+L8ha5Vmq8ZrpAwf6Eo9OKdk8Fylz0pfwJ/dyZmR8h/rjzCIiA5p5MOS8HIUIM8DL+xxtAeySXw58uGCS/xBLjL9zlak13mO2gWFi4gWDjxds64c96V+KiAaS47DsOndsQRB2lofz0bSAYzG1HgFQ6Rypx7Mg4+yMTVSwOmXLyr2NGCq5cjtX8kP4JFM9CXhUZQKffk3cD7dy19CFKD94+ewLSkvaoGk9pvshTClLzM+HuRc095aEzHYPc9UetMJt+3Zqa61ESW1YhzcvNPVgLPPXDzbf9UbbsfvKuZIoooS4cCoMu96QI9rJLjEg1bhXaHxTAsd+cPaEyRZCCT77T0HAwg6n0O3M80QuYi0AsmzfQiJklloq4XsQZ9Xij9MK9sOoIKGWioP9maY0TSIUh9j7Qdq0W4LS35AvW0PJqnQezInwiG1x3rRwcehMNE1lPJN6uAVJeTX27D0a5HC27468vuflT0hAIrsoHD0jVUPggnnoX8WDWApLNl20cALWRCfeCFZvdUeorLDJ5wVA0gafJhYcQybMV0tbSDmH3cAIOnEM0e3hPzCcjeCDLNoJBGOqlv/pJNFfJVEMXnTb8MbLhW2uR9xBafwgRlYxrrIt/BF46zUkSfRKnImaPwRElAFQ1OnLr1gJd4J3EQBrrO1xz8AzdSv/hGqK6PdJgJc9ReLEcId+xps7VDlJGQ7x01FlOlpO3RLRXfti60vOW/0Z31TCvHVV1pORMz0XRvbWvB6AIv4LJeyHiTCSRahGi/3oaJWW3bz2E72/OCSEAOwgx2XTjeTXw1ztPIayFepgzWnPhef9XUm9V0z9BhdB0hL1YG1hUeRDKQkY/aAs0094yBmauxEk2gSgbkYzjzaG5ronZc863UijB0w8VIV9XsFVNwCGLn5OI3VxRQxDT4piYex12gg4RWGGstSANeoGZyQU+fHQZtDV5/aOP45Fc+tiWUpOUECDMQFZu/LfCq2T/u7pZOpSzJsxJhwgr5Zxw0SLm6Sks6OQclx6mc77rXKD8205CG/rSzJifS8wln3kt2fyqYUDjiL9EaelbDwOgHvLo1ChPguYGRuoGgZPfVUi+9cravNRcWMVYO3p38rXEX/XNIMVLWfy4q4XRdwjzEZbAHKUHxfTblgeNgTcYwFvw0ZmZ0RxTCMbeCcxBbI3+CHrQu1cbpJ0v0iBgDDuztC+O18TxJbiC1mrJ9nSicofrOFDKLxdrCY+8L3jEItpoARXSqx1rEzu0Ps7NhgcQtmZZPtZGnhh8ZqVIoi2nBUZNht8DkHg2p9z6y6/v7h7Cr/60ThCGRF7zFQmbRaJaAmdW/elBIR95ik1FEdtUafuJSHJuiB+YSO1F64RSwsSZ7tkdAvBWWIIVkYyPSp+A0ex5gvoILi0CE7RCHEoLTGF1ybNkimpmODE0igVeS/dbcw9CwbkHw8Cs8hVsD0NqT5XQuJNY3LrzXMuPUWjVunp0IotjF0nw2liVPD2KsQ7mdinQ1yIiFdPdcY6oSVVB9PL3mRp8/Xe7H29uNL8t8/aEFi12trb6ns+QRflGHmaLkEBXCBV39pfuQQrvjyY1C1raaBEtxEBKPKnL4FBfDFVNGzJJJMFNIwNOyiUFWrFmYYOMXsdRYURvGokAOU2U9H/usobhggRY+0xLQ5dBta7C1z+imjx5rk4AzgZrsngtoQpJVEKCmnITtYKym2aQ4ryf4bavmpMswoKDRbr2k8AbO47wfaQyGOROSB3hjsoOLm6kYUl303F8ZnwLD9ZvXwrBbXq5AubIvPRjtmrEGRapWxhsvYUDw8qXYI2DUBlgmmM5IJr+0GK3odAeH89fm2jXbyMUTrJP24WbT2H7Qf9AiV5lt9Q+au3AuVpeWgSFNiXs9FQNZGo1VRUFNYihbQmrDmYmqSv2OAa69gaa4awd0QURPMA6IqhgaM0PKqMX/2f1EkdI2AuEgvvvOONAdJUnTcxu2jZGezOKS0Zr1MShBAKquzaQfr4O8Of48qvnXuLtNZp52DXh+SrMLPQ4X+dDGl5ZVc0l4Q5YV1j0aJWzcR5fZFVjcyz7tI4hV1/uelOsII3Opo8jgBJ+3y1BYWh3c2Z6IVDK1v7/xIveF4NGfGK556qv4x9c4EyY4vNcsLw98owGjwifniPHg==	10039682513917785606626708446169197638147193697184553601186114964497230606697
\.


--
-- Name: account_identifiers_id_seq; Type: SEQUENCE SET; Schema: public; Owner: o1labs
--

SELECT pg_catalog.setval('public.account_identifiers_id_seq', 7, true);


--
-- Name: blocks_id_seq; Type: SEQUENCE SET; Schema: public; Owner: o1labs
--

SELECT pg_catalog.setval('public.blocks_id_seq', 15, true);


--
-- Name: epoch_data_id_seq; Type: SEQUENCE SET; Schema: public; Owner: o1labs
--

SELECT pg_catalog.setval('public.epoch_data_id_seq', 16, true);


--
-- Name: internal_commands_id_seq; Type: SEQUENCE SET; Schema: public; Owner: o1labs
--

SELECT pg_catalog.setval('public.internal_commands_id_seq', 20, true);


--
-- Name: public_keys_id_seq; Type: SEQUENCE SET; Schema: public; Owner: o1labs
--

SELECT pg_catalog.setval('public.public_keys_id_seq', 7, true);


--
-- Name: snarked_ledger_hashes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: o1labs
--

SELECT pg_catalog.setval('public.snarked_ledger_hashes_id_seq', 1, true);


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

SELECT pg_catalog.setval('public.user_commands_id_seq', 115, true);


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
-- Name: zkapp_network_precondition zkapp_network_precondition_blockchain_length_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: o1labs
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

