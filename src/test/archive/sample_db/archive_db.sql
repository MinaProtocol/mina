--
-- PostgreSQL database dump
--

-- Dumped from database version 12.20 (Ubuntu 12.20-0ubuntu0.20.04.1)
-- Dumped by pg_dump version 15.6

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
-- Name: public; Type: SCHEMA; Schema: -; Owner: postgres
--

-- *not* creating schema, since initdb creates it


ALTER SCHEMA public OWNER TO postgres;

--
-- Name: authorization_kind_type; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.authorization_kind_type AS ENUM (
    'None_given',
    'Signature',
    'Proof'
);


ALTER TYPE public.authorization_kind_type OWNER TO postgres;

--
-- Name: chain_status_type; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.chain_status_type AS ENUM (
    'canonical',
    'orphaned',
    'pending'
);


ALTER TYPE public.chain_status_type OWNER TO postgres;

--
-- Name: internal_command_type; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.internal_command_type AS ENUM (
    'fee_transfer_via_coinbase',
    'fee_transfer',
    'coinbase'
);


ALTER TYPE public.internal_command_type OWNER TO postgres;

--
-- Name: may_use_token; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.may_use_token AS ENUM (
    'No',
    'ParentsOwnToken',
    'InheritFromParent'
);


ALTER TYPE public.may_use_token OWNER TO postgres;

--
-- Name: transaction_status; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.transaction_status AS ENUM (
    'applied',
    'failed'
);


ALTER TYPE public.transaction_status OWNER TO postgres;

--
-- Name: user_command_type; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.user_command_type AS ENUM (
    'payment',
    'delegation'
);


ALTER TYPE public.user_command_type OWNER TO postgres;

--
-- Name: zkapp_auth_required_type; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.zkapp_auth_required_type AS ENUM (
    'none',
    'either',
    'proof',
    'signature',
    'both',
    'impossible'
);


ALTER TYPE public.zkapp_auth_required_type OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: account_identifiers; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.account_identifiers (
    id integer NOT NULL,
    public_key_id integer NOT NULL,
    token_id integer NOT NULL
);


ALTER TABLE public.account_identifiers OWNER TO postgres;

--
-- Name: account_identifiers_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.account_identifiers_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.account_identifiers_id_seq OWNER TO postgres;

--
-- Name: account_identifiers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.account_identifiers_id_seq OWNED BY public.account_identifiers.id;


--
-- Name: accounts_accessed; Type: TABLE; Schema: public; Owner: postgres
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


ALTER TABLE public.accounts_accessed OWNER TO postgres;

--
-- Name: accounts_created; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.accounts_created (
    block_id integer NOT NULL,
    account_identifier_id integer NOT NULL,
    creation_fee text NOT NULL
);


ALTER TABLE public.accounts_created OWNER TO postgres;

--
-- Name: blocks; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.blocks (
    id integer NOT NULL,
    state_hash text NOT NULL,
    parent_id integer,
    parent_hash text NOT NULL,
    creator_id integer NOT NULL,
    block_winner_id integer NOT NULL,
    last_vrf_output text NOT NULL,
    snarked_ledger_hash_id integer NOT NULL,
    staking_epoch_data_id integer NOT NULL,
    next_epoch_data_id integer NOT NULL,
    min_window_density bigint NOT NULL,
    sub_window_densities bigint[] NOT NULL,
    total_currency text NOT NULL,
    ledger_hash text NOT NULL,
    height bigint NOT NULL,
    global_slot_since_hard_fork bigint NOT NULL,
    global_slot_since_genesis bigint NOT NULL,
    protocol_version_id integer NOT NULL,
    proposed_protocol_version_id integer,
    "timestamp" text NOT NULL,
    chain_status public.chain_status_type NOT NULL
);


ALTER TABLE public.blocks OWNER TO postgres;

--
-- Name: blocks_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.blocks_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.blocks_id_seq OWNER TO postgres;

--
-- Name: blocks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.blocks_id_seq OWNED BY public.blocks.id;


--
-- Name: blocks_internal_commands; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.blocks_internal_commands (
    block_id integer NOT NULL,
    internal_command_id integer NOT NULL,
    sequence_no integer NOT NULL,
    secondary_sequence_no integer NOT NULL,
    status public.transaction_status NOT NULL,
    failure_reason text
);


ALTER TABLE public.blocks_internal_commands OWNER TO postgres;

--
-- Name: blocks_user_commands; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.blocks_user_commands (
    block_id integer NOT NULL,
    user_command_id integer NOT NULL,
    sequence_no integer NOT NULL,
    status public.transaction_status NOT NULL,
    failure_reason text
);


ALTER TABLE public.blocks_user_commands OWNER TO postgres;

--
-- Name: blocks_zkapp_commands; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.blocks_zkapp_commands (
    block_id integer NOT NULL,
    zkapp_command_id integer NOT NULL,
    sequence_no integer NOT NULL,
    status public.transaction_status NOT NULL,
    failure_reasons_ids integer[]
);


ALTER TABLE public.blocks_zkapp_commands OWNER TO postgres;

--
-- Name: epoch_data; Type: TABLE; Schema: public; Owner: postgres
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


ALTER TABLE public.epoch_data OWNER TO postgres;

--
-- Name: epoch_data_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.epoch_data_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.epoch_data_id_seq OWNER TO postgres;

--
-- Name: epoch_data_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.epoch_data_id_seq OWNED BY public.epoch_data.id;


--
-- Name: internal_commands; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.internal_commands (
    id integer NOT NULL,
    command_type public.internal_command_type NOT NULL,
    receiver_id integer NOT NULL,
    fee text NOT NULL,
    hash text NOT NULL
);


ALTER TABLE public.internal_commands OWNER TO postgres;

--
-- Name: internal_commands_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.internal_commands_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.internal_commands_id_seq OWNER TO postgres;

--
-- Name: internal_commands_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.internal_commands_id_seq OWNED BY public.internal_commands.id;


--
-- Name: protocol_versions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.protocol_versions (
    id integer NOT NULL,
    transaction integer NOT NULL,
    network integer NOT NULL,
    patch integer NOT NULL
);


ALTER TABLE public.protocol_versions OWNER TO postgres;

--
-- Name: protocol_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.protocol_versions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.protocol_versions_id_seq OWNER TO postgres;

--
-- Name: protocol_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.protocol_versions_id_seq OWNED BY public.protocol_versions.id;


--
-- Name: public_keys; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.public_keys (
    id integer NOT NULL,
    value text NOT NULL
);


ALTER TABLE public.public_keys OWNER TO postgres;

--
-- Name: public_keys_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.public_keys_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.public_keys_id_seq OWNER TO postgres;

--
-- Name: public_keys_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.public_keys_id_seq OWNED BY public.public_keys.id;


--
-- Name: snarked_ledger_hashes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.snarked_ledger_hashes (
    id integer NOT NULL,
    value text NOT NULL
);


ALTER TABLE public.snarked_ledger_hashes OWNER TO postgres;

--
-- Name: snarked_ledger_hashes_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.snarked_ledger_hashes_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.snarked_ledger_hashes_id_seq OWNER TO postgres;

--
-- Name: snarked_ledger_hashes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.snarked_ledger_hashes_id_seq OWNED BY public.snarked_ledger_hashes.id;


--
-- Name: timing_info; Type: TABLE; Schema: public; Owner: postgres
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


ALTER TABLE public.timing_info OWNER TO postgres;

--
-- Name: timing_info_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.timing_info_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.timing_info_id_seq OWNER TO postgres;

--
-- Name: timing_info_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.timing_info_id_seq OWNED BY public.timing_info.id;


--
-- Name: token_symbols; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.token_symbols (
    id integer NOT NULL,
    value text NOT NULL
);


ALTER TABLE public.token_symbols OWNER TO postgres;

--
-- Name: token_symbols_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.token_symbols_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.token_symbols_id_seq OWNER TO postgres;

--
-- Name: token_symbols_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.token_symbols_id_seq OWNED BY public.token_symbols.id;


--
-- Name: tokens; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tokens (
    id integer NOT NULL,
    value text NOT NULL,
    owner_public_key_id integer,
    owner_token_id integer
);


ALTER TABLE public.tokens OWNER TO postgres;

--
-- Name: tokens_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.tokens_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.tokens_id_seq OWNER TO postgres;

--
-- Name: tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.tokens_id_seq OWNED BY public.tokens.id;


--
-- Name: user_commands; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.user_commands (
    id integer NOT NULL,
    command_type public.user_command_type NOT NULL,
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


ALTER TABLE public.user_commands OWNER TO postgres;

--
-- Name: user_commands_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.user_commands_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.user_commands_id_seq OWNER TO postgres;

--
-- Name: user_commands_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.user_commands_id_seq OWNED BY public.user_commands.id;


--
-- Name: voting_for; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.voting_for (
    id integer NOT NULL,
    value text NOT NULL
);


ALTER TABLE public.voting_for OWNER TO postgres;

--
-- Name: voting_for_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.voting_for_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.voting_for_id_seq OWNER TO postgres;

--
-- Name: voting_for_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.voting_for_id_seq OWNED BY public.voting_for.id;


--
-- Name: zkapp_account_precondition; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.zkapp_account_precondition (
    id integer NOT NULL,
    balance_id integer,
    nonce_id integer,
    receipt_chain_hash text,
    delegate_id integer,
    state_id integer NOT NULL,
    action_state_id integer,
    proved_state boolean,
    is_new boolean
);


ALTER TABLE public.zkapp_account_precondition OWNER TO postgres;

--
-- Name: zkapp_account_precondition_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.zkapp_account_precondition_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.zkapp_account_precondition_id_seq OWNER TO postgres;

--
-- Name: zkapp_account_precondition_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.zkapp_account_precondition_id_seq OWNED BY public.zkapp_account_precondition.id;


--
-- Name: zkapp_account_update; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.zkapp_account_update (
    id integer NOT NULL,
    body_id integer NOT NULL
);


ALTER TABLE public.zkapp_account_update OWNER TO postgres;

--
-- Name: zkapp_account_update_body; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.zkapp_account_update_body (
    id integer NOT NULL,
    account_identifier_id integer NOT NULL,
    update_id integer NOT NULL,
    balance_change text NOT NULL,
    increment_nonce boolean NOT NULL,
    events_id integer NOT NULL,
    actions_id integer NOT NULL,
    call_data_id integer NOT NULL,
    call_depth integer NOT NULL,
    zkapp_network_precondition_id integer NOT NULL,
    zkapp_account_precondition_id integer NOT NULL,
    zkapp_valid_while_precondition_id integer,
    use_full_commitment boolean NOT NULL,
    implicit_account_creation_fee boolean NOT NULL,
    may_use_token public.may_use_token NOT NULL,
    authorization_kind public.authorization_kind_type NOT NULL,
    verification_key_hash_id integer
);


ALTER TABLE public.zkapp_account_update_body OWNER TO postgres;

--
-- Name: zkapp_account_update_body_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.zkapp_account_update_body_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.zkapp_account_update_body_id_seq OWNER TO postgres;

--
-- Name: zkapp_account_update_body_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.zkapp_account_update_body_id_seq OWNED BY public.zkapp_account_update_body.id;


--
-- Name: zkapp_account_update_failures; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.zkapp_account_update_failures (
    id integer NOT NULL,
    index integer NOT NULL,
    failures text[] NOT NULL
);


ALTER TABLE public.zkapp_account_update_failures OWNER TO postgres;

--
-- Name: zkapp_account_update_failures_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.zkapp_account_update_failures_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.zkapp_account_update_failures_id_seq OWNER TO postgres;

--
-- Name: zkapp_account_update_failures_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.zkapp_account_update_failures_id_seq OWNED BY public.zkapp_account_update_failures.id;


--
-- Name: zkapp_account_update_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.zkapp_account_update_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.zkapp_account_update_id_seq OWNER TO postgres;

--
-- Name: zkapp_account_update_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.zkapp_account_update_id_seq OWNED BY public.zkapp_account_update.id;


--
-- Name: zkapp_accounts; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.zkapp_accounts (
    id integer NOT NULL,
    app_state_id integer NOT NULL,
    verification_key_id integer,
    zkapp_version bigint NOT NULL,
    action_state_id integer NOT NULL,
    last_action_slot bigint NOT NULL,
    proved_state boolean NOT NULL,
    zkapp_uri_id integer NOT NULL
);


ALTER TABLE public.zkapp_accounts OWNER TO postgres;

--
-- Name: zkapp_accounts_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.zkapp_accounts_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.zkapp_accounts_id_seq OWNER TO postgres;

--
-- Name: zkapp_accounts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.zkapp_accounts_id_seq OWNED BY public.zkapp_accounts.id;


--
-- Name: zkapp_action_states; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.zkapp_action_states (
    id integer NOT NULL,
    element0 integer NOT NULL,
    element1 integer NOT NULL,
    element2 integer NOT NULL,
    element3 integer NOT NULL,
    element4 integer NOT NULL
);


ALTER TABLE public.zkapp_action_states OWNER TO postgres;

--
-- Name: zkapp_action_states_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.zkapp_action_states_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.zkapp_action_states_id_seq OWNER TO postgres;

--
-- Name: zkapp_action_states_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.zkapp_action_states_id_seq OWNED BY public.zkapp_action_states.id;


--
-- Name: zkapp_amount_bounds; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.zkapp_amount_bounds (
    id integer NOT NULL,
    amount_lower_bound text NOT NULL,
    amount_upper_bound text NOT NULL
);


ALTER TABLE public.zkapp_amount_bounds OWNER TO postgres;

--
-- Name: zkapp_amount_bounds_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.zkapp_amount_bounds_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.zkapp_amount_bounds_id_seq OWNER TO postgres;

--
-- Name: zkapp_amount_bounds_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.zkapp_amount_bounds_id_seq OWNED BY public.zkapp_amount_bounds.id;


--
-- Name: zkapp_balance_bounds; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.zkapp_balance_bounds (
    id integer NOT NULL,
    balance_lower_bound text NOT NULL,
    balance_upper_bound text NOT NULL
);


ALTER TABLE public.zkapp_balance_bounds OWNER TO postgres;

--
-- Name: zkapp_balance_bounds_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.zkapp_balance_bounds_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.zkapp_balance_bounds_id_seq OWNER TO postgres;

--
-- Name: zkapp_balance_bounds_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.zkapp_balance_bounds_id_seq OWNED BY public.zkapp_balance_bounds.id;


--
-- Name: zkapp_commands; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.zkapp_commands (
    id integer NOT NULL,
    zkapp_fee_payer_body_id integer NOT NULL,
    zkapp_account_updates_ids integer[] NOT NULL,
    memo text NOT NULL,
    hash text NOT NULL
);


ALTER TABLE public.zkapp_commands OWNER TO postgres;

--
-- Name: zkapp_commands_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.zkapp_commands_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.zkapp_commands_id_seq OWNER TO postgres;

--
-- Name: zkapp_commands_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.zkapp_commands_id_seq OWNED BY public.zkapp_commands.id;


--
-- Name: zkapp_epoch_data; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.zkapp_epoch_data (
    id integer NOT NULL,
    epoch_ledger_id integer,
    epoch_seed text,
    start_checkpoint text,
    lock_checkpoint text,
    epoch_length_id integer
);


ALTER TABLE public.zkapp_epoch_data OWNER TO postgres;

--
-- Name: zkapp_epoch_data_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.zkapp_epoch_data_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.zkapp_epoch_data_id_seq OWNER TO postgres;

--
-- Name: zkapp_epoch_data_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.zkapp_epoch_data_id_seq OWNED BY public.zkapp_epoch_data.id;


--
-- Name: zkapp_epoch_ledger; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.zkapp_epoch_ledger (
    id integer NOT NULL,
    hash_id integer,
    total_currency_id integer
);


ALTER TABLE public.zkapp_epoch_ledger OWNER TO postgres;

--
-- Name: zkapp_epoch_ledger_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.zkapp_epoch_ledger_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.zkapp_epoch_ledger_id_seq OWNER TO postgres;

--
-- Name: zkapp_epoch_ledger_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.zkapp_epoch_ledger_id_seq OWNED BY public.zkapp_epoch_ledger.id;


--
-- Name: zkapp_events; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.zkapp_events (
    id integer NOT NULL,
    element_ids integer[] NOT NULL
);


ALTER TABLE public.zkapp_events OWNER TO postgres;

--
-- Name: zkapp_events_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.zkapp_events_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.zkapp_events_id_seq OWNER TO postgres;

--
-- Name: zkapp_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.zkapp_events_id_seq OWNED BY public.zkapp_events.id;


--
-- Name: zkapp_fee_payer_body; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.zkapp_fee_payer_body (
    id integer NOT NULL,
    public_key_id integer NOT NULL,
    fee text NOT NULL,
    valid_until bigint,
    nonce bigint NOT NULL
);


ALTER TABLE public.zkapp_fee_payer_body OWNER TO postgres;

--
-- Name: zkapp_fee_payer_body_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.zkapp_fee_payer_body_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.zkapp_fee_payer_body_id_seq OWNER TO postgres;

--
-- Name: zkapp_fee_payer_body_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.zkapp_fee_payer_body_id_seq OWNED BY public.zkapp_fee_payer_body.id;


--
-- Name: zkapp_field; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.zkapp_field (
    id integer NOT NULL,
    field text NOT NULL
);


ALTER TABLE public.zkapp_field OWNER TO postgres;

--
-- Name: zkapp_field_array; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.zkapp_field_array (
    id integer NOT NULL,
    element_ids integer[] NOT NULL
);


ALTER TABLE public.zkapp_field_array OWNER TO postgres;

--
-- Name: zkapp_field_array_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.zkapp_field_array_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.zkapp_field_array_id_seq OWNER TO postgres;

--
-- Name: zkapp_field_array_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.zkapp_field_array_id_seq OWNED BY public.zkapp_field_array.id;


--
-- Name: zkapp_field_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.zkapp_field_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.zkapp_field_id_seq OWNER TO postgres;

--
-- Name: zkapp_field_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.zkapp_field_id_seq OWNED BY public.zkapp_field.id;


--
-- Name: zkapp_global_slot_bounds; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.zkapp_global_slot_bounds (
    id integer NOT NULL,
    global_slot_lower_bound bigint NOT NULL,
    global_slot_upper_bound bigint NOT NULL
);


ALTER TABLE public.zkapp_global_slot_bounds OWNER TO postgres;

--
-- Name: zkapp_global_slot_bounds_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.zkapp_global_slot_bounds_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.zkapp_global_slot_bounds_id_seq OWNER TO postgres;

--
-- Name: zkapp_global_slot_bounds_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.zkapp_global_slot_bounds_id_seq OWNED BY public.zkapp_global_slot_bounds.id;


--
-- Name: zkapp_length_bounds; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.zkapp_length_bounds (
    id integer NOT NULL,
    length_lower_bound bigint NOT NULL,
    length_upper_bound bigint NOT NULL
);


ALTER TABLE public.zkapp_length_bounds OWNER TO postgres;

--
-- Name: zkapp_length_bounds_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.zkapp_length_bounds_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.zkapp_length_bounds_id_seq OWNER TO postgres;

--
-- Name: zkapp_length_bounds_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.zkapp_length_bounds_id_seq OWNED BY public.zkapp_length_bounds.id;


--
-- Name: zkapp_network_precondition; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.zkapp_network_precondition (
    id integer NOT NULL,
    snarked_ledger_hash_id integer,
    blockchain_length_id integer,
    min_window_density_id integer,
    total_currency_id integer,
    global_slot_since_genesis integer,
    staking_epoch_data_id integer,
    next_epoch_data_id integer
);


ALTER TABLE public.zkapp_network_precondition OWNER TO postgres;

--
-- Name: zkapp_network_precondition_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.zkapp_network_precondition_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.zkapp_network_precondition_id_seq OWNER TO postgres;

--
-- Name: zkapp_network_precondition_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.zkapp_network_precondition_id_seq OWNED BY public.zkapp_network_precondition.id;


--
-- Name: zkapp_nonce_bounds; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.zkapp_nonce_bounds (
    id integer NOT NULL,
    nonce_lower_bound bigint NOT NULL,
    nonce_upper_bound bigint NOT NULL
);


ALTER TABLE public.zkapp_nonce_bounds OWNER TO postgres;

--
-- Name: zkapp_nonce_bounds_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.zkapp_nonce_bounds_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.zkapp_nonce_bounds_id_seq OWNER TO postgres;

--
-- Name: zkapp_nonce_bounds_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.zkapp_nonce_bounds_id_seq OWNED BY public.zkapp_nonce_bounds.id;


--
-- Name: zkapp_permissions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.zkapp_permissions (
    id integer NOT NULL,
    edit_state public.zkapp_auth_required_type NOT NULL,
    send public.zkapp_auth_required_type NOT NULL,
    receive public.zkapp_auth_required_type NOT NULL,
    access public.zkapp_auth_required_type NOT NULL,
    set_delegate public.zkapp_auth_required_type NOT NULL,
    set_permissions public.zkapp_auth_required_type NOT NULL,
    set_verification_key_auth public.zkapp_auth_required_type NOT NULL,
    set_verification_key_txn_version integer NOT NULL,
    set_zkapp_uri public.zkapp_auth_required_type NOT NULL,
    edit_action_state public.zkapp_auth_required_type NOT NULL,
    set_token_symbol public.zkapp_auth_required_type NOT NULL,
    increment_nonce public.zkapp_auth_required_type NOT NULL,
    set_voting_for public.zkapp_auth_required_type NOT NULL,
    set_timing public.zkapp_auth_required_type NOT NULL
);


ALTER TABLE public.zkapp_permissions OWNER TO postgres;

--
-- Name: zkapp_permissions_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.zkapp_permissions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.zkapp_permissions_id_seq OWNER TO postgres;

--
-- Name: zkapp_permissions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.zkapp_permissions_id_seq OWNED BY public.zkapp_permissions.id;


--
-- Name: zkapp_states; Type: TABLE; Schema: public; Owner: postgres
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


ALTER TABLE public.zkapp_states OWNER TO postgres;

--
-- Name: zkapp_states_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.zkapp_states_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.zkapp_states_id_seq OWNER TO postgres;

--
-- Name: zkapp_states_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.zkapp_states_id_seq OWNED BY public.zkapp_states.id;


--
-- Name: zkapp_states_nullable; Type: TABLE; Schema: public; Owner: postgres
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


ALTER TABLE public.zkapp_states_nullable OWNER TO postgres;

--
-- Name: zkapp_states_nullable_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.zkapp_states_nullable_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.zkapp_states_nullable_id_seq OWNER TO postgres;

--
-- Name: zkapp_states_nullable_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.zkapp_states_nullable_id_seq OWNED BY public.zkapp_states_nullable.id;


--
-- Name: zkapp_timing_info; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.zkapp_timing_info (
    id integer NOT NULL,
    initial_minimum_balance text NOT NULL,
    cliff_time bigint NOT NULL,
    cliff_amount text NOT NULL,
    vesting_period bigint NOT NULL,
    vesting_increment text NOT NULL
);


ALTER TABLE public.zkapp_timing_info OWNER TO postgres;

--
-- Name: zkapp_timing_info_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.zkapp_timing_info_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.zkapp_timing_info_id_seq OWNER TO postgres;

--
-- Name: zkapp_timing_info_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.zkapp_timing_info_id_seq OWNED BY public.zkapp_timing_info.id;


--
-- Name: zkapp_token_id_bounds; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.zkapp_token_id_bounds (
    id integer NOT NULL,
    token_id_lower_bound text NOT NULL,
    token_id_upper_bound text NOT NULL
);


ALTER TABLE public.zkapp_token_id_bounds OWNER TO postgres;

--
-- Name: zkapp_token_id_bounds_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.zkapp_token_id_bounds_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.zkapp_token_id_bounds_id_seq OWNER TO postgres;

--
-- Name: zkapp_token_id_bounds_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.zkapp_token_id_bounds_id_seq OWNED BY public.zkapp_token_id_bounds.id;


--
-- Name: zkapp_updates; Type: TABLE; Schema: public; Owner: postgres
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


ALTER TABLE public.zkapp_updates OWNER TO postgres;

--
-- Name: zkapp_updates_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.zkapp_updates_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.zkapp_updates_id_seq OWNER TO postgres;

--
-- Name: zkapp_updates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.zkapp_updates_id_seq OWNED BY public.zkapp_updates.id;


--
-- Name: zkapp_uris; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.zkapp_uris (
    id integer NOT NULL,
    value text NOT NULL
);


ALTER TABLE public.zkapp_uris OWNER TO postgres;

--
-- Name: zkapp_uris_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.zkapp_uris_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.zkapp_uris_id_seq OWNER TO postgres;

--
-- Name: zkapp_uris_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.zkapp_uris_id_seq OWNED BY public.zkapp_uris.id;


--
-- Name: zkapp_verification_key_hashes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.zkapp_verification_key_hashes (
    id integer NOT NULL,
    value text NOT NULL
);


ALTER TABLE public.zkapp_verification_key_hashes OWNER TO postgres;

--
-- Name: zkapp_verification_key_hashes_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.zkapp_verification_key_hashes_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.zkapp_verification_key_hashes_id_seq OWNER TO postgres;

--
-- Name: zkapp_verification_key_hashes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.zkapp_verification_key_hashes_id_seq OWNED BY public.zkapp_verification_key_hashes.id;


--
-- Name: zkapp_verification_keys; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.zkapp_verification_keys (
    id integer NOT NULL,
    verification_key text NOT NULL,
    hash_id integer NOT NULL
);


ALTER TABLE public.zkapp_verification_keys OWNER TO postgres;

--
-- Name: zkapp_verification_keys_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.zkapp_verification_keys_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.zkapp_verification_keys_id_seq OWNER TO postgres;

--
-- Name: zkapp_verification_keys_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.zkapp_verification_keys_id_seq OWNED BY public.zkapp_verification_keys.id;


--
-- Name: account_identifiers id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.account_identifiers ALTER COLUMN id SET DEFAULT nextval('public.account_identifiers_id_seq'::regclass);


--
-- Name: blocks id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.blocks ALTER COLUMN id SET DEFAULT nextval('public.blocks_id_seq'::regclass);


--
-- Name: epoch_data id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.epoch_data ALTER COLUMN id SET DEFAULT nextval('public.epoch_data_id_seq'::regclass);


--
-- Name: internal_commands id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.internal_commands ALTER COLUMN id SET DEFAULT nextval('public.internal_commands_id_seq'::regclass);


--
-- Name: protocol_versions id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.protocol_versions ALTER COLUMN id SET DEFAULT nextval('public.protocol_versions_id_seq'::regclass);


--
-- Name: public_keys id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.public_keys ALTER COLUMN id SET DEFAULT nextval('public.public_keys_id_seq'::regclass);


--
-- Name: snarked_ledger_hashes id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.snarked_ledger_hashes ALTER COLUMN id SET DEFAULT nextval('public.snarked_ledger_hashes_id_seq'::regclass);


--
-- Name: timing_info id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.timing_info ALTER COLUMN id SET DEFAULT nextval('public.timing_info_id_seq'::regclass);


--
-- Name: token_symbols id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.token_symbols ALTER COLUMN id SET DEFAULT nextval('public.token_symbols_id_seq'::regclass);


--
-- Name: tokens id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tokens ALTER COLUMN id SET DEFAULT nextval('public.tokens_id_seq'::regclass);


--
-- Name: user_commands id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_commands ALTER COLUMN id SET DEFAULT nextval('public.user_commands_id_seq'::regclass);


--
-- Name: voting_for id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.voting_for ALTER COLUMN id SET DEFAULT nextval('public.voting_for_id_seq'::regclass);


--
-- Name: zkapp_account_precondition id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_account_precondition ALTER COLUMN id SET DEFAULT nextval('public.zkapp_account_precondition_id_seq'::regclass);


--
-- Name: zkapp_account_update id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_account_update ALTER COLUMN id SET DEFAULT nextval('public.zkapp_account_update_id_seq'::regclass);


--
-- Name: zkapp_account_update_body id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_account_update_body ALTER COLUMN id SET DEFAULT nextval('public.zkapp_account_update_body_id_seq'::regclass);


--
-- Name: zkapp_account_update_failures id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_account_update_failures ALTER COLUMN id SET DEFAULT nextval('public.zkapp_account_update_failures_id_seq'::regclass);


--
-- Name: zkapp_accounts id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_accounts ALTER COLUMN id SET DEFAULT nextval('public.zkapp_accounts_id_seq'::regclass);


--
-- Name: zkapp_action_states id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_action_states ALTER COLUMN id SET DEFAULT nextval('public.zkapp_action_states_id_seq'::regclass);


--
-- Name: zkapp_amount_bounds id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_amount_bounds ALTER COLUMN id SET DEFAULT nextval('public.zkapp_amount_bounds_id_seq'::regclass);


--
-- Name: zkapp_balance_bounds id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_balance_bounds ALTER COLUMN id SET DEFAULT nextval('public.zkapp_balance_bounds_id_seq'::regclass);


--
-- Name: zkapp_commands id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_commands ALTER COLUMN id SET DEFAULT nextval('public.zkapp_commands_id_seq'::regclass);


--
-- Name: zkapp_epoch_data id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_epoch_data ALTER COLUMN id SET DEFAULT nextval('public.zkapp_epoch_data_id_seq'::regclass);


--
-- Name: zkapp_epoch_ledger id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_epoch_ledger ALTER COLUMN id SET DEFAULT nextval('public.zkapp_epoch_ledger_id_seq'::regclass);


--
-- Name: zkapp_events id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_events ALTER COLUMN id SET DEFAULT nextval('public.zkapp_events_id_seq'::regclass);


--
-- Name: zkapp_fee_payer_body id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_fee_payer_body ALTER COLUMN id SET DEFAULT nextval('public.zkapp_fee_payer_body_id_seq'::regclass);


--
-- Name: zkapp_field id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_field ALTER COLUMN id SET DEFAULT nextval('public.zkapp_field_id_seq'::regclass);


--
-- Name: zkapp_field_array id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_field_array ALTER COLUMN id SET DEFAULT nextval('public.zkapp_field_array_id_seq'::regclass);


--
-- Name: zkapp_global_slot_bounds id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_global_slot_bounds ALTER COLUMN id SET DEFAULT nextval('public.zkapp_global_slot_bounds_id_seq'::regclass);


--
-- Name: zkapp_length_bounds id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_length_bounds ALTER COLUMN id SET DEFAULT nextval('public.zkapp_length_bounds_id_seq'::regclass);


--
-- Name: zkapp_network_precondition id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_network_precondition ALTER COLUMN id SET DEFAULT nextval('public.zkapp_network_precondition_id_seq'::regclass);


--
-- Name: zkapp_nonce_bounds id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_nonce_bounds ALTER COLUMN id SET DEFAULT nextval('public.zkapp_nonce_bounds_id_seq'::regclass);


--
-- Name: zkapp_permissions id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_permissions ALTER COLUMN id SET DEFAULT nextval('public.zkapp_permissions_id_seq'::regclass);


--
-- Name: zkapp_states id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_states ALTER COLUMN id SET DEFAULT nextval('public.zkapp_states_id_seq'::regclass);


--
-- Name: zkapp_states_nullable id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_states_nullable ALTER COLUMN id SET DEFAULT nextval('public.zkapp_states_nullable_id_seq'::regclass);


--
-- Name: zkapp_timing_info id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_timing_info ALTER COLUMN id SET DEFAULT nextval('public.zkapp_timing_info_id_seq'::regclass);


--
-- Name: zkapp_token_id_bounds id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_token_id_bounds ALTER COLUMN id SET DEFAULT nextval('public.zkapp_token_id_bounds_id_seq'::regclass);


--
-- Name: zkapp_updates id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_updates ALTER COLUMN id SET DEFAULT nextval('public.zkapp_updates_id_seq'::regclass);


--
-- Name: zkapp_uris id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_uris ALTER COLUMN id SET DEFAULT nextval('public.zkapp_uris_id_seq'::regclass);


--
-- Name: zkapp_verification_key_hashes id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_verification_key_hashes ALTER COLUMN id SET DEFAULT nextval('public.zkapp_verification_key_hashes_id_seq'::regclass);


--
-- Name: zkapp_verification_keys id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_verification_keys ALTER COLUMN id SET DEFAULT nextval('public.zkapp_verification_keys_id_seq'::regclass);


--
-- Data for Name: account_identifiers; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.account_identifiers (id, public_key_id, token_id) FROM stdin;
1	2	1
2	3	1
3	4	1
4	5	1
5	6	1
6	7	1
7	8	1
8	9	1
9	10	1
10	11	1
11	13	1
12	14	1
13	15	1
14	16	1
15	17	1
16	18	1
17	19	1
18	20	1
19	21	1
20	22	1
21	23	1
22	24	1
23	25	1
24	26	1
25	27	1
26	29	1
27	30	1
28	31	1
29	32	1
30	33	1
31	34	1
32	35	1
33	36	1
34	37	1
35	38	1
36	39	1
37	40	1
38	41	1
39	42	1
40	43	1
41	44	1
42	45	1
43	46	1
44	47	1
45	28	1
46	48	1
47	49	1
48	50	1
49	51	1
50	52	1
51	53	1
52	54	1
53	55	1
54	56	1
55	57	1
56	58	1
57	59	1
58	60	1
59	61	1
60	62	1
61	63	1
62	64	1
63	65	1
64	66	1
65	67	1
66	68	1
67	69	1
68	70	1
69	71	1
70	72	1
71	73	1
72	74	1
73	75	1
74	76	1
75	77	1
76	78	1
77	79	1
78	80	1
79	81	1
80	82	1
81	83	1
82	84	1
83	85	1
84	86	1
85	87	1
86	88	1
87	89	1
88	90	1
89	91	1
90	92	1
91	93	1
92	94	1
93	95	1
94	96	1
95	97	1
96	98	1
97	99	1
98	100	1
99	101	1
100	102	1
101	103	1
102	104	1
103	105	1
104	106	1
105	107	1
106	108	1
107	109	1
108	110	1
109	111	1
110	112	1
111	113	1
112	114	1
113	115	1
114	116	1
115	117	1
116	118	1
117	119	1
118	120	1
119	121	1
120	122	1
121	123	1
122	124	1
123	125	1
124	126	1
125	127	1
126	128	1
127	129	1
128	130	1
129	131	1
130	132	1
131	133	1
132	134	1
133	135	1
134	137	1
135	138	1
136	139	1
137	140	1
138	141	1
139	142	1
140	143	1
141	144	1
142	145	1
143	146	1
144	147	1
145	148	1
146	149	1
147	150	1
148	151	1
149	152	1
150	153	1
151	154	1
152	155	1
153	156	1
154	157	1
155	158	1
156	159	1
157	160	1
158	161	1
159	162	1
160	163	1
161	164	1
162	165	1
163	166	1
164	167	1
165	168	1
166	169	1
167	170	1
168	171	1
169	172	1
170	173	1
171	174	1
172	175	1
173	176	1
174	177	1
175	178	1
176	179	1
177	180	1
178	181	1
179	182	1
180	183	1
181	184	1
182	185	1
183	186	1
184	187	1
185	188	1
186	1	1
187	189	1
188	190	1
189	191	1
190	192	1
191	193	1
192	194	1
193	195	1
194	196	1
195	197	1
196	198	1
197	199	1
198	200	1
199	201	1
200	202	1
201	203	1
202	204	1
203	205	1
204	206	1
205	12	1
206	207	1
207	208	1
208	209	1
209	210	1
210	211	1
211	212	1
212	213	1
213	214	1
214	215	1
215	216	1
216	217	1
217	218	1
218	219	1
219	220	1
220	136	1
221	221	1
222	222	1
223	223	1
224	224	1
225	225	1
226	226	1
227	227	1
228	228	1
229	229	1
230	230	1
231	231	1
232	232	1
233	233	1
234	234	1
235	235	1
236	236	1
237	237	1
238	238	1
239	239	1
240	240	1
241	241	1
242	242	1
243	243	1
\.


--
-- Data for Name: accounts_accessed; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.accounts_accessed (ledger_index, block_id, account_identifier_id, token_symbol_id, balance, nonce, receipt_chain_hash, delegate_id, voting_for_id, timing_id, permissions_id, zkapp_id) FROM stdin;
10	1	1	1	285	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	2	1	1	1	\N
107	1	2	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	3	1	2	1	\N
81	1	3	1	331	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	4	1	3	1	\N
32	1	4	1	226	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	5	1	4	1	\N
12	1	5	1	123	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	6	1	5	1	\N
78	1	6	1	292	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	7	1	6	1	\N
121	1	7	1	104	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	8	1	7	1	\N
176	1	8	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	9	1	8	1	\N
236	1	9	1	488	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	10	1	9	1	\N
4	1	10	1	11550000000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	12	1	10	1	\N
226	1	11	1	469	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	13	1	11	1	\N
19	1	12	1	242	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	14	1	12	1	\N
128	1	13	1	135	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	15	1	13	1	\N
94	1	14	1	196	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	16	1	14	1	\N
153	1	15	1	79	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	17	1	15	1	\N
166	1	16	1	206	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	18	1	16	1	\N
137	1	17	1	340	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	19	1	17	1	\N
105	1	18	1	382	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	20	1	18	1	\N
70	1	19	1	488	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	21	1	19	1	\N
27	1	20	1	135	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	22	1	20	1	\N
46	1	21	1	126	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	23	1	21	1	\N
43	1	22	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	24	1	22	1	\N
117	1	23	1	278	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	25	1	23	1	\N
204	1	24	1	46	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	26	1	24	1	\N
6	1	25	1	11550000000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	25	1	\N
187	1	26	1	104	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	29	1	26	1	\N
72	1	27	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	30	1	27	1	\N
216	1	28	1	271	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	31	1	28	1	\N
210	1	29	1	315	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	32	1	29	1	\N
79	1	30	1	162	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	33	1	30	1	\N
167	1	31	1	86	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	34	1	31	1	\N
181	1	32	1	409	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	35	1	32	1	\N
156	1	33	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	36	1	33	1	\N
96	1	34	1	57	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	37	1	34	1	\N
191	1	35	1	204	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	38	1	35	1	\N
132	1	36	1	262	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	39	1	36	1	\N
111	1	37	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	40	1	37	1	\N
171	1	38	1	156	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	41	1	38	1	\N
64	1	39	1	417	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	42	1	39	1	\N
68	1	40	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	43	1	40	1	\N
51	1	41	1	85	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	44	1	41	1	\N
227	1	42	1	103	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	45	1	42	1	\N
141	1	43	1	67	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	46	1	43	1	\N
42	1	44	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	47	1	44	1	\N
7	1	45	1	0	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	45	1	\N
133	1	46	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	48	1	46	1	\N
82	1	47	1	198	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	49	1	47	1	\N
95	1	48	1	489	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	50	1	48	1	\N
188	1	49	1	298	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	51	1	49	1	\N
30	1	50	1	36	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	52	1	50	1	\N
90	1	51	1	334	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	53	1	51	1	\N
14	1	52	1	344	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	54	1	52	1	\N
35	1	53	1	451	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	55	1	53	1	\N
85	1	54	1	371	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	56	1	54	1	\N
127	1	55	1	234	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	55	1	\N
222	1	56	1	345	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	58	1	56	1	\N
76	1	57	1	282	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	59	1	57	1	\N
231	1	58	1	339	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	60	1	58	1	\N
15	1	59	1	215	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	61	1	59	1	\N
220	1	60	1	193	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	62	1	60	1	\N
16	1	61	1	60	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	63	1	61	1	\N
58	1	62	1	350	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	64	1	62	1	\N
146	1	63	1	223	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	65	1	63	1	\N
62	1	64	1	449	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	66	1	64	1	\N
185	1	65	1	142	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	67	1	65	1	\N
151	1	66	1	300	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	68	1	66	1	\N
165	1	67	1	256	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	69	1	67	1	\N
103	1	68	1	125	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	70	1	68	1	\N
41	1	69	1	236	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	71	1	69	1	\N
239	1	70	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	72	1	70	1	\N
110	1	71	1	179	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	73	1	71	1	\N
13	1	72	1	194	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	74	1	72	1	\N
26	1	73	1	185	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	75	1	73	1	\N
98	1	74	1	342	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	76	1	74	1	\N
215	1	75	1	157	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	77	1	75	1	\N
91	1	76	1	135	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	78	1	76	1	\N
159	1	77	1	456	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	79	1	77	1	\N
208	1	78	1	336	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	80	1	78	1	\N
207	1	79	1	280	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	81	1	79	1	\N
182	1	80	1	187	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	82	1	80	1	\N
157	1	81	1	387	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	83	1	81	1	\N
33	1	82	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	84	1	82	1	\N
201	1	83	1	151	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	85	1	83	1	\N
9	1	84	1	356	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	86	1	84	1	\N
234	1	85	1	24	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	87	1	85	1	\N
40	1	86	1	152	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	88	1	86	1	\N
18	1	87	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	89	1	87	1	\N
229	1	88	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	90	1	88	1	\N
20	1	89	1	186	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	91	1	89	1	\N
184	1	90	1	266	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	92	1	90	1	\N
139	1	91	1	81	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	93	1	91	1	\N
164	1	92	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	94	1	92	1	\N
199	1	93	1	379	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	95	1	93	1	\N
109	1	94	1	315	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	96	1	94	1	\N
47	1	95	1	226	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	97	1	95	1	\N
214	1	96	1	166	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	98	1	96	1	\N
112	1	97	1	302	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	99	1	97	1	\N
144	1	98	1	269	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	100	1	98	1	\N
178	1	99	1	172	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	101	1	99	1	\N
155	1	100	1	195	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	102	1	100	1	\N
38	1	101	1	243	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	103	1	101	1	\N
80	1	102	1	128	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	104	1	102	1	\N
147	1	103	1	349	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	105	1	103	1	\N
24	1	104	1	87	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	106	1	104	1	\N
126	1	105	1	424	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	107	1	105	1	\N
89	1	106	1	239	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	108	1	106	1	\N
135	1	107	1	316	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	109	1	107	1	\N
194	1	108	1	492	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	110	1	108	1	\N
190	1	109	1	294	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	111	1	109	1	\N
218	1	110	1	191	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	112	1	110	1	\N
93	1	111	1	380	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	113	1	111	1	\N
162	1	112	1	331	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	114	1	112	1	\N
221	1	113	1	459	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	115	1	113	1	\N
205	1	114	1	28	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	116	1	114	1	\N
195	1	115	1	472	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	117	1	115	1	\N
34	1	116	1	119	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	118	1	116	1	\N
213	1	117	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	119	1	117	1	\N
196	1	118	1	41	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	120	1	118	1	\N
104	1	119	1	27	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	121	1	119	1	\N
44	1	120	1	70	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	122	1	120	1	\N
52	1	121	1	337	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	123	1	121	1	\N
114	1	122	1	210	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	124	1	122	1	\N
177	1	123	1	495	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	125	1	123	1	\N
148	1	124	1	144	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	126	1	124	1	\N
100	1	125	1	148	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	127	1	125	1	\N
206	1	126	1	376	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	128	1	126	1	\N
28	1	127	1	329	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	129	1	127	1	\N
173	1	128	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	130	1	128	1	\N
1	1	129	1	5000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	131	1	129	1	\N
130	1	130	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	130	1	\N
39	1	131	1	181	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	133	1	131	1	\N
212	1	132	1	200	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	134	1	132	1	\N
2	1	133	1	65500000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	136	1	133	1	\N
116	1	134	1	159	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	137	1	134	1	\N
48	1	135	1	319	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	138	1	135	1	\N
101	1	136	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	139	1	136	1	\N
203	1	137	1	365	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	140	1	137	1	\N
50	1	138	1	342	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	141	1	138	1	\N
59	1	139	1	237	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	142	1	139	1	\N
150	1	140	1	427	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	143	1	140	1	\N
180	1	141	1	315	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	144	1	141	1	\N
142	1	142	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	145	1	142	1	\N
23	1	143	1	378	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	146	1	143	1	\N
122	1	144	1	420	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	147	1	144	1	\N
115	1	145	1	411	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	148	1	145	1	\N
75	1	146	1	172	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	149	1	146	1	\N
77	1	147	1	309	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	150	1	147	1	\N
152	1	148	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	151	1	148	1	\N
120	1	149	1	154	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	152	1	149	1	\N
118	1	150	1	153	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	153	1	150	1	\N
37	1	151	1	47	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	154	1	151	1	\N
168	1	152	1	87	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	155	1	152	1	\N
149	1	153	1	398	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	156	1	153	1	\N
29	1	154	1	452	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	157	1	154	1	\N
8	1	155	1	283	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	158	1	155	1	\N
88	1	156	1	291	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	159	1	156	1	\N
233	1	157	1	367	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	160	1	157	1	\N
83	1	158	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	161	1	158	1	\N
154	1	159	1	311	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	162	1	159	1	\N
175	1	160	1	258	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	163	1	160	1	\N
69	1	161	1	323	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	164	1	161	1	\N
63	1	162	1	405	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	165	1	162	1	\N
189	1	163	1	32	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	166	1	163	1	\N
92	1	164	1	130	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	167	1	164	1	\N
140	1	165	1	234	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	165	1	\N
17	1	166	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	169	1	166	1	\N
87	1	167	1	481	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	170	1	167	1	\N
183	1	168	1	240	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	171	1	168	1	\N
129	1	169	1	314	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	172	1	169	1	\N
193	1	170	1	183	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	173	1	170	1	\N
174	1	171	1	486	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	174	1	171	1	\N
57	1	172	1	178	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	175	1	172	1	\N
224	1	173	1	65	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	176	1	173	1	\N
232	1	174	1	277	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	177	1	174	1	\N
119	1	175	1	433	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	178	1	175	1	\N
55	1	176	1	100	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	179	1	176	1	\N
169	1	177	1	272	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	180	1	177	1	\N
125	1	178	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	181	1	178	1	\N
45	1	179	1	212	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	182	1	179	1	\N
60	1	180	1	151	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	183	1	180	1	\N
99	1	181	1	387	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	184	1	181	1	\N
179	1	182	1	158	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	185	1	182	1	\N
49	1	183	1	440	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	186	1	183	1	\N
230	1	184	1	438	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	187	1	184	1	\N
131	1	185	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	188	1	185	1	\N
0	1	186	1	1000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	1	1	186	1	\N
186	1	187	1	290	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	189	1	187	1	\N
198	1	188	1	417	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	190	1	188	1	\N
202	1	189	1	375	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	191	1	189	1	\N
22	1	190	1	178	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	192	1	190	1	\N
102	1	191	1	59	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	193	1	191	1	\N
124	1	192	1	95	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	194	1	192	1	\N
200	1	193	1	394	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	195	1	193	1	\N
54	1	194	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	196	1	194	1	\N
225	1	195	1	256	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	197	1	195	1	\N
134	1	196	1	128	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	198	1	196	1	\N
97	1	197	1	199	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	199	1	197	1	\N
84	1	198	1	22	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	200	1	198	1	\N
161	1	199	1	276	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	201	1	199	1	\N
228	1	200	1	451	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	202	1	200	1	\N
238	1	201	1	133	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	203	1	201	1	\N
65	1	202	1	460	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	204	1	202	1	\N
219	1	203	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	205	1	203	1	\N
56	1	204	1	489	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	206	1	204	1	\N
5	1	205	1	0	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	12	1	205	1	\N
163	1	206	1	190	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	207	1	206	1	\N
192	1	207	1	221	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	208	1	207	1	\N
143	1	208	1	464	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	209	1	208	1	\N
61	1	209	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	210	1	209	1	\N
136	1	210	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	211	1	210	1	\N
71	1	211	1	353	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	212	1	211	1	\N
145	1	212	1	396	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	213	1	212	1	\N
106	1	213	1	417	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	214	1	213	1	\N
138	1	214	1	46	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	215	1	214	1	\N
158	1	215	1	305	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	216	1	215	1	\N
123	1	216	1	337	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	217	1	216	1	\N
25	1	217	1	444	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	218	1	217	1	\N
240	1	218	1	479	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	219	1	218	1	\N
211	1	219	1	344	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	220	1	219	1	\N
3	1	220	1	500000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	136	1	220	1	\N
241	1	221	1	113	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	221	1	221	1	\N
197	1	222	1	236	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	222	1	222	1	\N
170	1	223	1	480	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	223	1	223	1	\N
31	1	224	1	160	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	224	1	224	1	\N
160	1	225	1	318	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	225	1	225	1	\N
21	1	226	1	214	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
67	1	227	1	163	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	227	1	227	1	\N
66	1	228	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	228	1	228	1	\N
108	1	229	1	366	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	229	1	229	1	\N
86	1	230	1	320	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	230	1	230	1	\N
237	1	231	1	407	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	231	1	231	1	\N
74	1	232	1	204	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	232	1	232	1	\N
73	1	233	1	341	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	233	1	233	1	\N
217	1	234	1	18	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	234	1	234	1	\N
36	1	235	1	229	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	235	1	235	1	\N
172	1	236	1	477	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	236	1	\N
53	1	237	1	94	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	237	1	237	1	\N
235	1	238	1	126	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	238	1	238	1	\N
113	1	239	1	112	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	239	1	239	1	\N
223	1	240	1	387	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	240	1	240	1	\N
209	1	241	1	265	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	241	1	241	1	\N
11	1	242	1	269	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	242	1	242	1	\N
4	2	10	1	11549995000000000	1	2n1bukwjaKPG9k1wRnriz86Aa2bGdEGZL9hd6CQgWg3RJLZrq5XS	12	1	10	1	\N
7	2	45	1	725000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	45	1	\N
4	3	10	1	11549875000000000	25	2n1ihUz2KPqRqvFkp8cNoHwRAEUaGhRVWjCVLkbcbC1dd9P8G75N	12	1	10	1	\N
7	3	45	1	1570250000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	45	1	\N
3	3	220	1	494750000000	21	2n1nrEFx972QuRB8bV8gkGU7fMh3Ak6EwyTqzQTYXQWUkrYBHju9	136	1	220	1	\N
4	4	10	1	11549755000000000	49	2n2MxYgbZxwzx2M1bKV7UY82UbAnfApBR3UjTs9AUYPTZPAbKmqz	12	1	10	1	\N
7	4	45	1	2416500000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	45	1	\N
3	4	220	1	488500000000	46	2mztduXaaYKNuaFb9576TPBjoyb4Y4VXP9wRTZN7DhznZwEzufHp	136	1	220	1	\N
4	5	10	1	11549755000000000	49	2n2MxYgbZxwzx2M1bKV7UY82UbAnfApBR3UjTs9AUYPTZPAbKmqz	12	1	10	1	\N
5	5	205	1	846250000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	12	1	205	1	\N
3	5	220	1	488500000000	46	2mztduXaaYKNuaFb9576TPBjoyb4Y4VXP9wRTZN7DhznZwEzufHp	136	1	220	1	\N
4	6	10	1	11549635000000000	73	2n1dW6KBhxqH1opxoPpZP5amkVB6J6XqqBS7tpRYwXzqFwHj4ijE	12	1	10	1	\N
7	6	45	1	2412000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	45	1	\N
3	6	220	1	486750000000	53	2n2BEekZKpqEKRxbida8Z8yu4Eanjs96XJjHoW8GJWKUkUBnuDBz	136	1	220	1	\N
4	7	10	1	11549515000000000	97	2mzdGv8wHGhg1qugeRyXgiWhsNEUtvyk3fh2t5mRieaJs6ohJCKA	12	1	10	1	\N
5	7	205	1	1688250000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	12	1	205	1	\N
3	7	220	1	484750000000	61	2n1ddtQK9K1caxvxnJ2ShCNnoL8CLA4pkcV7uRTkVoMvHo2wSyHB	136	1	220	1	\N
4	8	10	1	11549395000000000	121	2n1uGF7oJCMSFyXWtyNHuUFTGewSFd3DYystYGcHtqDjyVMaFRQJ	12	1	10	1	\N
5	8	205	1	2530250000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	12	1	205	1	\N
3	8	220	1	482750000000	69	2n1HZxaqisgai3qPZ46N4V6MVAFPS3EFgLjSKXsKDuTYv28Qqdck	136	1	220	1	\N
4	9	10	1	11549395000000000	121	2n1uGF7oJCMSFyXWtyNHuUFTGewSFd3DYystYGcHtqDjyVMaFRQJ	12	1	10	1	\N
7	9	45	1	3254000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	45	1	\N
3	9	220	1	482750000000	69	2n1HZxaqisgai3qPZ46N4V6MVAFPS3EFgLjSKXsKDuTYv28Qqdck	136	1	220	1	\N
4	10	10	1	11549275000000000	145	2n1it8Do6XpixvpGxC4GokfXQQ35mSg9Ub8gsraoKd6tJHnoYHtb	12	1	10	1	\N
5	10	205	1	3372250000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	12	1	205	1	\N
3	10	220	1	480750000000	77	2n15jLvQu6vxGrFWozCaSLQ4tpXNRTQWJuLZc87JNCJv6McRY2dD	136	1	220	1	\N
4	11	10	1	11549275000000000	145	2n1it8Do6XpixvpGxC4GokfXQQ35mSg9Ub8gsraoKd6tJHnoYHtb	12	1	10	1	\N
7	11	45	1	3254000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	45	1	\N
3	11	220	1	480750000000	77	2n15jLvQu6vxGrFWozCaSLQ4tpXNRTQWJuLZc87JNCJv6McRY2dD	136	1	220	1	\N
4	12	10	1	11549155000000000	169	2mzokqGar4BqaMkAkJsVoVfVU7arnX4M2TNFQ1kZ5PbyAQoJ66Mb	12	1	10	1	\N
5	12	205	1	3372250000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	12	1	205	1	\N
3	12	220	1	478750000000	85	2n2Cqc5d82rQQqLJuqqekkT2SKu6j7PcnG8i9it6UGrJrEB7K4Uf	136	1	220	1	\N
4	13	10	1	11549075000000000	185	2n1TcCsdTRBEY5yw2QVvFHFeggxYBDq77qkc9MY6RJ9fCiMPwNAU	12	1	10	1	\N
5	13	205	1	4174250000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	12	1	205	1	\N
3	13	220	1	476750000000	93	2n1aGA7RAT7nYfBqvEjTFQWNfixH3wJjG9XnEpCdi7c5gJgbb1zi	136	1	220	1	\N
4	14	10	1	11548955000000000	209	2n1tGvNWJXRKEtQXnkdyee2qLuyWWdeC2d6B7wttdq37587CVJeU	12	1	10	1	\N
7	14	45	1	4098250000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	45	1	\N
3	14	220	1	472500000000	110	2n285dxSNYvZ9KkAPLZrdVxLWjy8PZjgWiXRwm4M3xJD5wyx4oCY	136	1	220	1	\N
4	15	10	1	11548835000000000	233	2n1JComoo2VkNitppGRMXjBfaUx5RN8y9ogj7hz7sE7XjQJhYBRi	12	1	10	1	\N
5	15	205	1	5016250000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	12	1	205	1	\N
3	15	220	1	470500000000	118	2n1SJWDB3sGZaiQ6xrdF61dAgZ8sZbJEHzJLmyiHaQawE8Pj818m	136	1	220	1	\N
4	16	10	1	11548835000000000	233	2n1JComoo2VkNitppGRMXjBfaUx5RN8y9ogj7hz7sE7XjQJhYBRi	12	1	10	1	\N
7	16	45	1	4940250000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	45	1	\N
3	16	220	1	470500000000	118	2n1SJWDB3sGZaiQ6xrdF61dAgZ8sZbJEHzJLmyiHaQawE8Pj818m	136	1	220	1	\N
4	17	10	1	11548715000000000	257	2n1fJsFbWypjgsNDqYHMqUn6rEuFewzsuzUvc1ryWtChnQnNGoh2	12	1	10	1	\N
7	17	45	1	5784445000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	45	1	\N
1	17	129	1	5055000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	131	1	129	1	\N
3	17	220	1	466250000000	135	2mzv2umtYbp48NYViKan6Pf1wsCTDqawAvXN9HarspcyLa8BXXj9	136	1	220	1	\N
4	19	10	1	11548595000000000	281	2n12Ei1aGGeJ1kwdPw1uobibAem59P1awGFJp3oo5CsX4DEscjkR	12	1	10	1	\N
1	19	129	1	5059000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	131	1	129	1	\N
5	19	205	1	5016246000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	12	1	205	1	\N
3	19	220	1	464250000000	143	2n1tuZeqCPgYpZVCf8ForKWD4N2JL3d913usA28bakPQ7mCUhEjf	136	1	220	1	\N
4	21	10	1	11548420000000000	316	2n1mAU6yGboPFU9VZ9xpzDi1g5eMmmo1DRxSFFSgym9MQnc6XJxa	12	1	10	1	\N
7	21	45	1	8245436000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	45	1	\N
1	21	129	1	5064000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	131	1	129	1	\N
3	21	220	1	460250000000	159	2n1S7HB2CxhXFTbb7m13Syy4FFJCEDUDs4M7j4VGuduVDku1k5Wp	136	1	220	1	\N
4	23	10	1	11548335000000000	333	2n19fdGomQ4tpK34HqiiCNzCALAL1Uou4KSCyUD9NYyVgYse5th3	12	1	10	1	\N
7	23	45	1	9052430000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	45	1	\N
1	23	129	1	5070000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	131	1	129	1	\N
3	23	220	1	458250000000	167	2mztns59WG9jDjtGgphc9FVMfyFoMBihWBC1ZxJKRuvEG3Vbd7qu	136	1	220	1	\N
4	25	10	1	11548255000000000	349	2n1NEuFADHn7gWYphVu6eBzRbEQ6BnjohXQ5pyM9yacVNHzfwYXd	12	1	10	1	\N
7	25	45	1	9854427000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	45	1	\N
1	25	129	1	5073000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	131	1	129	1	\N
3	25	220	1	456250000000	175	2n1DsnGodJsmyro7XSHuVmoJycdzFgqviiGuZ3TgsDww8WpBQJxB	136	1	220	1	\N
4	18	10	1	11548595000000000	281	2n12Ei1aGGeJ1kwdPw1uobibAem59P1awGFJp3oo5CsX4DEscjkR	12	1	10	1	\N
7	18	45	1	6626441000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	45	1	\N
1	18	129	1	5059000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	131	1	129	1	\N
3	18	220	1	464250000000	143	2n1tuZeqCPgYpZVCf8ForKWD4N2JL3d913usA28bakPQ7mCUhEjf	136	1	220	1	\N
4	20	10	1	11548500000000000	300	2mzyJN51qJ8SmW7t3JoQhQP3pNtNxi6UQRoB1Uz9zjF15amMgN5e	12	1	10	1	\N
7	20	45	1	7443438000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	45	1	\N
1	20	129	1	5062000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	131	1	129	1	\N
3	20	220	1	462250000000	151	2n18R5Q9K5tNQLomJ5aTtWmvz6ZctPEVrrZRpyJmWVTvXFNpbJTq	136	1	220	1	\N
4	22	10	1	11548335000000000	333	2n19fdGomQ4tpK34HqiiCNzCALAL1Uou4KSCyUD9NYyVgYse5th3	12	1	10	1	\N
1	22	129	1	5070000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	131	1	129	1	\N
5	22	205	1	4981244000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	12	1	205	1	\N
3	22	220	1	458250000000	167	2mztns59WG9jDjtGgphc9FVMfyFoMBihWBC1ZxJKRuvEG3Vbd7qu	136	1	220	1	\N
4	24	10	1	11548255000000000	349	2n1NEuFADHn7gWYphVu6eBzRbEQ6BnjohXQ5pyM9yacVNHzfwYXd	12	1	10	1	\N
1	24	129	1	5073000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	131	1	129	1	\N
5	24	205	1	4976247000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	12	1	205	1	\N
3	24	220	1	456250000000	175	2n1DsnGodJsmyro7XSHuVmoJycdzFgqviiGuZ3TgsDww8WpBQJxB	136	1	220	1	\N
4	26	10	1	11548175000000000	365	2n2JgggUSRkxLiaKHwqs632pUJz9GwToHdJgyCvUuBDCy6ME85AC	12	1	10	1	\N
7	26	45	1	9853677000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	45	1	\N
1	26	129	1	5076000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	131	1	129	1	\N
3	26	220	1	455000000000	180	2n2JD1HLP3d5VHXMBgbkbsvcxKujQwd9SvNDWkKye7MS7nXYtLqp	136	1	220	1	\N
4	27	10	1	11548175000000000	365	2n2JgggUSRkxLiaKHwqs632pUJz9GwToHdJgyCvUuBDCy6ME85AC	12	1	10	1	\N
1	27	129	1	5076000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	131	1	129	1	\N
5	27	205	1	5777494000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	12	1	205	1	\N
3	27	220	1	455000000000	180	2n2JD1HLP3d5VHXMBgbkbsvcxKujQwd9SvNDWkKye7MS7nXYtLqp	136	1	220	1	\N
4	28	10	1	11548170000000000	366	2n1MqAE6s3VQk63rYVsmtHyx9HSMJSRaysB573ZEBmu6Ldkczvki	12	1	10	1	\N
7	28	45	1	10578674000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	45	1	\N
1	28	129	1	5079000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	131	1	129	1	\N
4	29	10	1	11548140000000000	372	2n1ddLu9U1jggd3c5irAJ9peTGLnrUzxAHA1etrBaiJDgyKcUv7Q	12	1	10	1	\N
1	29	129	1	5087000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	131	1	129	1	\N
5	29	205	1	5726239000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	12	1	205	1	\N
4	30	10	1	11548135000000000	373	2n1rLcoasQnE4f8XA1xFwyHJDN6G8V8XZZq11b1KukVkwZWUsAoF	12	1	10	1	\N
7	30	45	1	11303671000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	45	1	\N
1	30	129	1	5090000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	131	1	129	1	\N
4	31	10	1	11548135000000000	373	2n1rLcoasQnE4f8XA1xFwyHJDN6G8V8XZZq11b1KukVkwZWUsAoF	12	1	10	1	\N
1	31	129	1	5090000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	131	1	129	1	\N
5	31	205	1	6451236000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	12	1	205	1	\N
4	32	10	1	11548130000000000	374	2n2BbPcY1771BF1Ai67WaRyrLsUBLE2JTsBcQ9TWR9fAXwnnQ3LX	12	1	10	1	\N
7	32	45	1	12028668000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	45	1	\N
1	32	129	1	5093000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	131	1	129	1	\N
4	33	10	1	11548125000000000	375	2mzfetbEEonw7VsPg1Udo1qNbamVtsgfQ1naXMzcmibtQzkHx7zZ	12	1	10	1	\N
7	33	45	1	12753665000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	45	1	\N
1	33	129	1	5096000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	131	1	129	1	\N
4	34	10	1	11548125000000000	375	2mzfetbEEonw7VsPg1Udo1qNbamVtsgfQ1naXMzcmibtQzkHx7zZ	12	1	10	1	\N
1	34	129	1	5096000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	131	1	129	1	\N
5	34	205	1	6451236000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	12	1	205	1	\N
\.


--
-- Data for Name: accounts_created; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.accounts_created (block_id, account_identifier_id, creation_fee) FROM stdin;
\.


--
-- Data for Name: blocks; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.blocks (id, state_hash, parent_id, parent_hash, creator_id, block_winner_id, last_vrf_output, snarked_ledger_hash_id, staking_epoch_data_id, next_epoch_data_id, min_window_density, sub_window_densities, total_currency, ledger_hash, height, global_slot_since_hard_fork, global_slot_since_genesis, protocol_version_id, proposed_protocol_version_id, "timestamp", chain_status) FROM stdin;
34	3NKS5X1AK8DXGRz1iAtLF2Wf7448y1KAts1TXSgpCouFbrprpgY9	32	3NL4cysEfp9U33dRJGcZ1Pv6i26mz19VKqimvMEDae94dtx7YUvC	12	11	kmG5MK_naWISKRP5oavCH1RPzjswUlsUGU7RwAKIdwU=	1	1	35	77	{3,5,5,7,4,7,7,7,7,7,7}	23166005000061388	jx639957zZGEjSCBtdvtrBJNTiNeZtRHL1S2B6Dcxh3c8S7z1Hg	24	32	32	1	\N	1730893602000	pending
22	3NKzLRAAFyZS4a9s6SFCsJcAjaN9kcb3z3TbKnoYRKhaNDiVebNj	21	3NLgq7VP5Dt3tiDtB1oegAmkmA6SeeuznaokdFEj9jmv9RB6iP2v	12	11	4xZsvrml1Aq2umWduXc_jjkqqf1JIPJN6MUt3ot0qwo=	1	1	23	77	{3,5,5,4,7,7,7,7,7,7,7}	23166005000061388	jxPnURhN7QPNQ2Z6Timh3KVb4E2bFJfRXmF4NSPBkD6Ms4yRbrd	17	24	24	1	\N	1730892162000	orphaned
30	3NKmJVLcqNfQYjTfKHAB2JfqTeNEQtncq5UfBrncPqjrgpTW1oCD	29	3NL7QDSGRRUCa9GdegCM32vpQhytGkrUnYAu48wZbK2ekQqSCkQo	28	27	_A93wlJNFQImNPWRsXm6K17J4FjDTCoVCFD6O41qcgY=	1	1	31	77	{3,5,5,7,2,7,7,7,7,7,7}	23166005000061388	jxotH4BZtTUZKZn1XW5oGMJLCLnPDAQDAz91HtBpBnUaQQUUuZy	22	30	30	1	\N	1730893242000	orphaned
32	3NL4cysEfp9U33dRJGcZ1Pv6i26mz19VKqimvMEDae94dtx7YUvC	30	3NKmJVLcqNfQYjTfKHAB2JfqTeNEQtncq5UfBrncPqjrgpTW1oCD	28	27	gg9fan2iQc7kpqBMB4fBYVWfC4WH3beEtymjxTch0gg=	1	1	33	77	{3,5,5,7,3,7,7,7,7,7,7}	23166005000061388	jwFJUP95jza3oxyReQV1xrmxzW6tc1C78inXXVYTwEpdGTngteq	23	31	31	1	\N	1730893422000	canonical
26	3NKPvMa4FYW2y8V1ShtJHyqfo85jXWKGrnB86f4Xbz4WZ2BYQdfn	24	3NL1x9ocYFXzN3DcQQoSA8tqu9z4Tnb1o5H3Jx5tVKRNh9PfHvcL	28	27	e1ebiXX_ONBxsweUrJIDlbEijVLTx7bwJBxyY1XviQQ=	1	1	27	77	{3,5,5,6,7,7,7,7,7,7,7}	23166005000061388	jxgXdtVoRxMzMoEZWSm3Fgpn6bKRbMzgpxjT4rQW5c8sYZwShNi	19	26	26	1	\N	1730892522000	canonical
24	3NL1x9ocYFXzN3DcQQoSA8tqu9z4Tnb1o5H3Jx5tVKRNh9PfHvcL	23	3NLTFZdRKtAmMUsHV5n4XtcsmXVV9yapeoAHNdbGEBz7Gavfs2LM	12	11	kS0OAOpB0f8dscfmZkLJ5zdTW1Bh9dX46M3MFZt9ZA4=	1	1	25	77	{3,5,5,5,7,7,7,7,7,7,7}	23166005000061388	jwWerA97pcq1DmXoRz3AYUpxGWdeytq1fRwHt2BAV33h7ujfFP3	18	25	25	1	\N	1730892342000	canonical
20	3NKETBQh7QDTA8QAZUbwzXWfANXtPekVhPfuCadt7xE7jo9VNMQV	18	3NKx7owsixNAwSmvUFM7R6qUTXtT79dpHguPrecu4mvcHuKoexZL	28	27	gOplYiacHj1WsK_s6Fks0mUsF_JjCYN7DUkyMvfDwgg=	1	1	21	77	{3,5,5,2,7,7,7,7,7,7,7}	23166005000061388	jxM6H4j1Sz2ffq5y6FuwryLyPX4xhUk9D3Cxewapdiis474acgC	15	22	22	1	\N	1730891802000	canonical
18	3NKx7owsixNAwSmvUFM7R6qUTXtT79dpHguPrecu4mvcHuKoexZL	17	3NLRGNt3oBAHAsnA68wpmHdrTnQK1Q2ReCoH5mzpGCkuSL2roWdV	28	27	WHgO7LXqfUtwN4Ol8Ks8pjDEmIjQc4gRMBoz3AnG6QM=	1	1	19	77	{3,5,5,1,7,7,7,7,7,7,7}	23166005000061388	jxB7un944by6zSHwNPWgwZvPi52emfrwzbFzwwtR6dtUR2svxcm	14	21	21	1	\N	1730891622000	canonical
28	3NLUzJGgnrE93Ts9WYyGVPtX3Ji85D9DxqRc2vq6vueUjrtcH2Pt	26	3NKPvMa4FYW2y8V1ShtJHyqfo85jXWKGrnB86f4Xbz4WZ2BYQdfn	28	27	9TjQC6mAbl3wyo7zUGN-GuYVlcE6kP4--w8sZHYuHws=	1	1	29	77	{3,5,5,7,7,7,7,7,7,7,7}	23166005000061388	jxUkgH3dy1pAZdkSreSwrdqTKC4e92GXGhXTMkEwovJ4arPjB95	20	27	27	1	\N	1730892702000	pending
33	3NLU1Q9dB6VpxXjxtGQ6KBT9L2N1ibMU5hKiPcrzLy2YUB1Q5xDZ	32	3NL4cysEfp9U33dRJGcZ1Pv6i26mz19VKqimvMEDae94dtx7YUvC	28	27	IYllzj1u7z-IZ-uoBgXMQPzxYcyqbW_lZmqDR5k_UA4=	1	1	34	77	{3,5,5,7,4,7,7,7,7,7,7}	23166005000061388	jwsn7MhPWV3Crnw3xsgDZukjHurZKwuCKu2qyMdYY87Mw9B8FXy	24	32	32	1	\N	1730893602000	pending
4	3NLcTf6EheuXM4PGHBaL49GNWm1vZfX1RMtAvsNoeUKkgdW9t8Vh	3	3NLbqs9rpKheXqJQjoLL88HG4ekwQ3suf5syJB4xevT3B1JcAe2D	28	27	XzlZUd4dI4Bb3jGvMXRPDXzKqjSZow2UffJZkZCiqQk=	1	1	5	77	{3,1,7,7,7,7,7,7,7,7,7}	23166005000061388	jxnyzMp9ktsttxipFERuPjQZPoAzpUysKyMDMbEsqQKTkicbNkH	4	9	9	1	\N	1730889462000	orphaned
9	3NLcSn11bFPQjFPVNDWN8P212fF57Yzh68rMaN1TWvZbPgQKTZ4d	7	3NKHgWfiFJ9e9PoFBRQWTw3g35m5zzKV3N74LvMC4vTKtffuKBb7	28	27	gFMJhwvcKX7npZUcB6jv_BrN9psICh0aYQtlp3Y0Kgk=	1	1	10	77	{3,4,7,7,7,7,7,7,7,7,7}	23166005000061388	jx76XATaZdCwpbfiFwsLZCbQBusPb5BkLU2imUzifZprTcNUnjM	7	12	12	1	\N	1730890002000	orphaned
8	3NKCdNgLvzwFzAqivAXQe1zDbLLBpeU88MzpzCc4vjhGaK7irjV7	7	3NKHgWfiFJ9e9PoFBRQWTw3g35m5zzKV3N74LvMC4vTKtffuKBb7	12	11	P5p2KXby4iNt9uwyuxnNLLmXCspgqkfJ3DwbraVg6gs=	1	1	9	77	{3,4,7,7,7,7,7,7,7,7,7}	23166005000061388	jxy5i6Ad7bCS4QDU4Aex5bdG4F9JweRyr6vsrpE8SrKYGcXXkxQ	7	12	12	1	\N	1730890002000	canonical
7	3NKHgWfiFJ9e9PoFBRQWTw3g35m5zzKV3N74LvMC4vTKtffuKBb7	6	3NKNm4oMSdJK4AP6pvoVpZFkvZFwEePzfF94ojpnWwxyjVfTR2DQ	12	11	yqTtTfhzEW74hN3_JC8LZcLWPY_9FZ_X87zkl7ZwpAM=	1	1	8	77	{3,3,7,7,7,7,7,7,7,7,7}	23166005000061388	jxVPN5vcWSyXxHAuWjvL5XHumb11A8V5MMgAdJqJk9z5vn4kP2F	6	11	11	1	\N	1730889822000	canonical
6	3NKNm4oMSdJK4AP6pvoVpZFkvZFwEePzfF94ojpnWwxyjVfTR2DQ	5	3NLtAE2VC7ukNKvCahnL31BYcH8eu2946U7JFf7ahLeuifZhvGQe	28	27	q5IeSyaWPMHbUi1H-4F9R1lYgMJHdC_CAsWRlBjVtgE=	1	1	7	77	{3,2,7,7,7,7,7,7,7,7,7}	23166005000061388	jway7pMz8MUAxnSFCJxubB3srZCc5HFHamnVfgidEefWfaE8U5X	5	10	10	1	\N	1730889642000	canonical
5	3NLtAE2VC7ukNKvCahnL31BYcH8eu2946U7JFf7ahLeuifZhvGQe	3	3NLbqs9rpKheXqJQjoLL88HG4ekwQ3suf5syJB4xevT3B1JcAe2D	12	11	dLaDJUcerQgcuq4L-t9NQiVy5pMxY4sOK7btlyj-ugw=	1	1	6	77	{3,1,7,7,7,7,7,7,7,7,7}	23166005000061388	jwZHUCUHXEq8A4rj98vTzc9uSNJLZ3v1QhqSMMcemAbdMdTK67U	4	9	9	1	\N	1730889462000	canonical
3	3NLbqs9rpKheXqJQjoLL88HG4ekwQ3suf5syJB4xevT3B1JcAe2D	2	3NLfncaZJRKHEkBFPaDbuyzkRK85jH5aRKJxvHALs4W7dFW3zB5a	28	27	GoJZyqAX2mVXc_82e-VjFA_1S2gw-xsYhLR3gCSoxAA=	1	1	4	77	{3,7,7,7,7,7,7,7,7,7,7}	23166005000061388	jwtSSJ3ZFVZNBt8jhon4VuxtYd4mm5hDcoUsQi5KCxL9sZngeCF	3	6	6	1	\N	1730888922000	canonical
2	3NLfncaZJRKHEkBFPaDbuyzkRK85jH5aRKJxvHALs4W7dFW3zB5a	1	3NKNPUsWQbLYw4YwWxPQ6hu9vP1zrCyvoSNCAGtTHD5oZYkb6WrE	28	27	-Ji6RtQx0z78DqAXj1hE0bB4X3bKfDjXwNdx7UOhVAQ=	1	1	3	77	{2,7,7,7,7,7,7,7,7,7,7}	23166005000061388	jwsAmQ1zJ5xdMzqGVk39E7mYb2iLtUosjt1jsgnMPGeoAH3EWmd	2	3	3	1	\N	1730888466112	canonical
1	3NKNPUsWQbLYw4YwWxPQ6hu9vP1zrCyvoSNCAGtTHD5oZYkb6WrE	\N	3NKz4NPodCRbicX8g1GuWe4axp4FyRncnozQsQyh1a5Um459kBy3	1	1	39cyg4ZmMtnb_aFUIerNAoAJV8qtkfOpq0zFzPspjgM=	1	1	2	77	{1,7,7,7,7,7,7,7,7,7,7}	23166005000061388	jwf5XDUhK1mhEdSgdymmrd1v7aWCBn5QuMmvyzVfxgx6kHBEstj	1	0	0	1	\N	1730887842000	canonical
10	3NL4RAbgrh9jVsGkkJYtTcUDjNRDrmegz6FCzAefpebsYSdTdAF6	8	3NKCdNgLvzwFzAqivAXQe1zDbLLBpeU88MzpzCc4vjhGaK7irjV7	12	11	Ul4MJ0pXTiYWjAVOriY47qoKxZSc7eJWg0oc4oUW_Qk=	1	1	11	77	{3,5,7,7,7,7,7,7,7,7,7}	23166005000061388	jxcpetwbAWj8zXxu8TFAGEVg1ZKFTKtDiL8yZo22H3RiJCZVitZ	8	13	13	1	\N	1730890182000	orphaned
15	3NLNx94fbuYFEJ1Goq8imv2FKDyu27TqfvMWQ8B79dmpKRcB2Pmo	14	3NKexh6yVWTGC6LeF7XPvTvCD9Mhn9tGivjk8yvKDb8fp5aZYgfx	12	11	5zGBGNJHiVGIvXrlxGoSVlNnN4SIV2SLlA2IAJdgQg0=	1	1	16	77	{3,5,4,7,7,7,7,7,7,7,7}	23166005000061388	jwEy6vDWE2oAfxjT9V1MwYubUGXuEFn6QAnsvj1cDzar3sW8dqx	12	18	18	1	\N	1730891082000	orphaned
19	3NKq3Ksk8DmY3N7sCgqFzxkf97dAbam89dRDkh6j6nVp9pLJr26E	17	3NLRGNt3oBAHAsnA68wpmHdrTnQK1Q2ReCoH5mzpGCkuSL2roWdV	12	11	Qbm7CZjZj4S9OkSqwGzhg63mRJEo9vGQ3ZMx4Na2sAM=	1	1	20	77	{3,5,5,1,7,7,7,7,7,7,7}	23166005000061388	jx8ZpRJqdYxBgTU8cM4WpoM54LijvkFfFL8Rgwc8FApZtLbnbRd	14	21	21	1	\N	1730891622000	orphaned
25	3NLbb1GL39ZGwW5JGJmsEAfoyNkkWDCcWEnLd8ofacPxB2o3wMms	23	3NLTFZdRKtAmMUsHV5n4XtcsmXVV9yapeoAHNdbGEBz7Gavfs2LM	28	27	RrUuYian_ZyQ80GEdFDP-Odv-RqjnCFcZAo26UE53w0=	1	1	26	77	{3,5,5,5,7,7,7,7,7,7,7}	23166005000061388	jxjzocRutNaDf8SU4d1w1tnYzPjpXU4uBSKPaY3b8DVWGe2YmLo	18	25	25	1	\N	1730892342000	orphaned
31	3NKoKzEKXRqThADc3coS2QKTxU1hroP8vHHjswS9NTLGMzSS8ma7	29	3NL7QDSGRRUCa9GdegCM32vpQhytGkrUnYAu48wZbK2ekQqSCkQo	12	11	1l4tM5uvmf-kTg2nvUwk22Jw496NGxBJfZl_T0oMNwA=	1	1	32	77	{3,5,5,7,2,7,7,7,7,7,7}	23166005000061388	jxU8fAoQJVBZLfkQSC3ou9H16WD8fQSLuGL6HAkUZCjqcxaUjrb	22	30	30	1	\N	1730893242000	orphaned
29	3NL7QDSGRRUCa9GdegCM32vpQhytGkrUnYAu48wZbK2ekQqSCkQo	28	3NLUzJGgnrE93Ts9WYyGVPtX3Ji85D9DxqRc2vq6vueUjrtcH2Pt	12	11	zxNb2kF-oydC8H9BWEvO-ft3Ci6UDAZOtenVp4zgjQE=	1	1	30	77	{3,5,5,7,1,7,7,7,7,7,7}	23166005000061388	jwPVPMTmUK9Dnb7bxJnMPX9AZXKmngvtCQ4mYae8hAeXLNtHGvQ	21	29	29	1	\N	1730893062000	canonical
23	3NLTFZdRKtAmMUsHV5n4XtcsmXVV9yapeoAHNdbGEBz7Gavfs2LM	21	3NLgq7VP5Dt3tiDtB1oegAmkmA6SeeuznaokdFEj9jmv9RB6iP2v	28	27	zTxi1EYqzt-TLEoOBTTSM5GkrMgvf_5TeZy07YSSywg=	1	1	24	77	{3,5,5,4,7,7,7,7,7,7,7}	23166005000061388	jwYUji3nMjJdtLHsLe717AQZLx7JyYhbDTAMJx9xY9nAvmGVMPW	17	24	24	1	\N	1730892162000	canonical
21	3NLgq7VP5Dt3tiDtB1oegAmkmA6SeeuznaokdFEj9jmv9RB6iP2v	20	3NKETBQh7QDTA8QAZUbwzXWfANXtPekVhPfuCadt7xE7jo9VNMQV	28	27	8uoxCFs0OprDI7eVUky6inIbb_LOg6rfNg5rQjEEmw4=	1	1	22	77	{3,5,5,3,7,7,7,7,7,7,7}	23166005000061388	jwGszi2EV1umbRZjcJCHxxF7USxgGKxusPSRbHBBM1oNXR9bRRQ	16	23	23	1	\N	1730891982000	canonical
17	3NLRGNt3oBAHAsnA68wpmHdrTnQK1Q2ReCoH5mzpGCkuSL2roWdV	16	3NKTJQc5p5ijJW26bZ6UBbSqaXSXmPibh2ZSLzcEpCSnsUgN1iZy	28	27	vo9Ecoo2QWX85m5G4h1aCP5EvvqNj3SusjrSq5WwfAQ=	1	1	18	77	{3,5,5,7,7,7,7,7,7,7,7}	23166005000061388	jwT7SaJb2kBk8GLCbeq3SK5ibEqxbwGeyEUoXDi9Pu7uqbzB5GD	13	20	20	1	\N	1730891442000	canonical
16	3NKTJQc5p5ijJW26bZ6UBbSqaXSXmPibh2ZSLzcEpCSnsUgN1iZy	14	3NKexh6yVWTGC6LeF7XPvTvCD9Mhn9tGivjk8yvKDb8fp5aZYgfx	28	27	oX45OyIARCYTuaLxCrenxh_4D6yUw58cwcwQwm6N7Ak=	1	1	17	77	{3,5,4,7,7,7,7,7,7,7,7}	23166005000061388	jxpPBTZrxoizWjvMaf2ysiKts9tVigh9e3UbNwQto5TtPxDFYvT	12	18	18	1	\N	1730891082000	canonical
14	3NKexh6yVWTGC6LeF7XPvTvCD9Mhn9tGivjk8yvKDb8fp5aZYgfx	13	3NLrHZF25mheLp2EyqWGbQqcLhR3ZaMJHreGh32CczBozZftmKQC	28	27	c2_fSRwgzm8fLwdGkSM9axfKE4SZu3fy5yGNY6eJLgw=	1	1	15	77	{3,5,3,7,7,7,7,7,7,7,7}	23166005000061388	jwxmU6uB8erfpJa1JZsRZBRs5B44xi1FUW9a3ide4UL6q6JYP1d	11	17	17	1	\N	1730890902000	canonical
13	3NLrHZF25mheLp2EyqWGbQqcLhR3ZaMJHreGh32CczBozZftmKQC	12	3NKCwhGwD4kScQP8HbXUN7pn17LsEnRA5UWE5PMWZGx1v7Q9vc9S	12	11	zgo-v32oKXqPfKbd3Va5MKwrtWzs0lhJ8szTTKyT9wc=	1	1	14	77	{3,5,2,7,7,7,7,7,7,7,7}	23166005000061388	jxAsFjvTL2WPudJn7GLsZ5xb88PoBhbrRsPMd8mcdZA44vdyEUM	10	15	15	1	\N	1730890542000	canonical
12	3NKCwhGwD4kScQP8HbXUN7pn17LsEnRA5UWE5PMWZGx1v7Q9vc9S	11	3NKbGB6MEjKq3W7RzX84eR8wKuvrUjwtyofaLUfzbvohKQ5YKNsr	12	11	ogkl4eHD1puplz_ORU-0ts26g-z4lhU2q5-Tv2AyCgo=	1	1	13	77	{3,5,1,7,7,7,7,7,7,7,7}	23166005000061388	jxVmBmaXimQdqBW8nLBn3RaHxDTd8538eyJG19EcugvrVGVyBPN	9	14	14	1	\N	1730890362000	canonical
11	3NKbGB6MEjKq3W7RzX84eR8wKuvrUjwtyofaLUfzbvohKQ5YKNsr	8	3NKCdNgLvzwFzAqivAXQe1zDbLLBpeU88MzpzCc4vjhGaK7irjV7	28	27	yfp7rddw9WJuz5m4R3gnQYGBxugIXDeKULf8cLxfIgs=	1	1	12	77	{3,5,7,7,7,7,7,7,7,7,7}	23166005000061388	jwjexwS9qmo7WrjtZazWCYnCbFhteoZ3dq5LBATXVRWnRmYjCCt	8	13	13	1	\N	1730890182000	canonical
27	3NL5ktrWvG8uXG5wYEyXBJQVUT7K16bixp6eWqgRm1UYpVkuWuM3	24	3NL1x9ocYFXzN3DcQQoSA8tqu9z4Tnb1o5H3Jx5tVKRNh9PfHvcL	12	11	2dc2sTYICZnaz5rxrzwiJboltWv3Dlenr4V3biPY6Q8=	1	1	28	77	{3,5,5,6,7,7,7,7,7,7,7}	23166005000061388	jwLkY5d8Aux4MehbxVjPqMvgSsywDr3D5BpvdkGpamSSD4po41K	19	26	26	1	\N	1730892522000	pending
\.


--
-- Data for Name: blocks_internal_commands; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.blocks_internal_commands (block_id, internal_command_id, sequence_no, secondary_sequence_no, status, failure_reason) FROM stdin;
2	1	1	0	applied	\N
2	2	2	0	applied	\N
3	1	45	0	applied	\N
3	3	46	0	applied	\N
4	1	49	0	applied	\N
4	4	50	0	applied	\N
5	5	49	0	applied	\N
5	6	50	0	applied	\N
6	7	26	0	applied	\N
6	1	32	0	applied	\N
6	8	33	0	applied	\N
7	5	32	0	applied	\N
7	9	33	0	applied	\N
8	5	32	0	applied	\N
8	9	33	0	applied	\N
9	1	32	0	applied	\N
9	10	33	0	applied	\N
10	5	32	0	applied	\N
10	9	33	0	applied	\N
11	1	32	0	applied	\N
11	10	33	0	applied	\N
12	11	18	0	applied	\N
12	5	33	0	applied	\N
12	12	34	0	applied	\N
13	5	24	0	applied	\N
13	13	25	0	applied	\N
14	1	41	0	applied	\N
14	14	42	0	applied	\N
15	5	32	0	applied	\N
15	9	33	0	applied	\N
16	1	32	0	applied	\N
16	10	33	0	applied	\N
17	15	8	0	applied	\N
17	16	42	0	applied	\N
17	17	42	0	applied	\N
17	18	43	0	applied	\N
17	19	43	1	applied	\N
18	16	32	0	applied	\N
18	17	32	0	applied	\N
18	20	33	0	applied	\N
18	21	33	1	applied	\N
19	16	32	0	applied	\N
19	22	32	0	applied	\N
19	21	33	0	applied	\N
19	23	33	1	applied	\N
20	16	27	0	applied	\N
20	17	27	0	applied	\N
20	24	28	0	applied	\N
20	25	28	1	applied	\N
21	16	24	0	applied	\N
21	17	24	0	applied	\N
21	26	25	0	applied	\N
21	27	25	1	applied	\N
22	28	3	0	applied	\N
22	16	26	0	applied	\N
22	22	26	0	applied	\N
22	29	27	0	applied	\N
22	30	27	1	applied	\N
23	31	3	0	applied	\N
23	16	26	0	applied	\N
23	17	26	0	applied	\N
23	32	27	0	applied	\N
23	29	27	1	applied	\N
24	16	24	0	applied	\N
24	22	24	0	applied	\N
24	25	25	0	applied	\N
24	33	25	1	applied	\N
25	16	24	0	applied	\N
25	17	24	0	applied	\N
25	34	25	0	applied	\N
25	25	25	1	applied	\N
26	16	21	0	applied	\N
26	17	21	0	applied	\N
26	35	22	0	applied	\N
26	25	22	1	applied	\N
27	16	21	0	applied	\N
27	22	21	0	applied	\N
27	25	22	0	applied	\N
27	36	22	1	applied	\N
28	16	1	0	applied	\N
28	17	1	0	applied	\N
28	37	2	0	applied	\N
28	25	2	1	applied	\N
29	16	6	0	applied	\N
29	22	6	0	applied	\N
29	38	7	0	applied	\N
29	39	7	1	applied	\N
30	16	1	0	applied	\N
30	17	1	0	applied	\N
30	37	2	0	applied	\N
30	25	2	1	applied	\N
31	16	1	0	applied	\N
31	22	1	0	applied	\N
31	25	2	0	applied	\N
31	40	2	1	applied	\N
32	16	1	0	applied	\N
32	17	1	0	applied	\N
32	37	2	0	applied	\N
32	25	2	1	applied	\N
33	16	1	0	applied	\N
33	17	1	0	applied	\N
33	37	2	0	applied	\N
33	25	2	1	applied	\N
34	16	1	0	applied	\N
34	22	1	0	applied	\N
34	25	2	0	applied	\N
34	40	2	1	applied	\N
\.


--
-- Data for Name: blocks_user_commands; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.blocks_user_commands (block_id, user_command_id, sequence_no, status, failure_reason) FROM stdin;
3	1	24	applied	\N
3	2	25	applied	\N
3	3	26	applied	\N
3	4	27	applied	\N
3	5	28	applied	\N
3	6	29	applied	\N
3	7	30	applied	\N
3	8	31	applied	\N
3	9	32	applied	\N
3	10	33	applied	\N
3	11	34	applied	\N
3	12	35	applied	\N
3	13	36	applied	\N
3	14	37	applied	\N
3	15	38	applied	\N
3	16	39	applied	\N
3	17	40	applied	\N
3	18	41	applied	\N
3	19	42	applied	\N
3	20	43	applied	\N
3	21	44	applied	\N
4	22	24	applied	\N
4	23	25	applied	\N
4	24	26	applied	\N
4	25	27	applied	\N
4	26	28	applied	\N
4	27	29	applied	\N
4	28	30	applied	\N
4	29	31	applied	\N
4	30	32	applied	\N
4	31	33	applied	\N
4	32	34	applied	\N
4	33	35	applied	\N
4	34	36	applied	\N
4	35	37	applied	\N
4	36	38	applied	\N
4	37	39	applied	\N
4	38	40	applied	\N
4	39	41	applied	\N
4	40	42	applied	\N
4	41	43	applied	\N
4	42	44	applied	\N
4	43	45	applied	\N
4	44	46	applied	\N
4	45	47	applied	\N
4	46	48	applied	\N
5	22	24	applied	\N
5	23	25	applied	\N
5	24	26	applied	\N
5	25	27	applied	\N
5	26	28	applied	\N
5	27	29	applied	\N
5	28	30	applied	\N
5	29	31	applied	\N
5	30	32	applied	\N
5	31	33	applied	\N
5	32	34	applied	\N
5	33	35	applied	\N
5	34	36	applied	\N
5	35	37	applied	\N
5	36	38	applied	\N
5	37	39	applied	\N
5	38	40	applied	\N
5	39	41	applied	\N
5	40	42	applied	\N
5	41	43	applied	\N
5	42	44	applied	\N
5	43	45	applied	\N
5	44	46	applied	\N
5	45	47	applied	\N
5	46	48	applied	\N
6	47	24	applied	\N
6	48	25	applied	\N
6	49	27	applied	\N
6	50	28	applied	\N
6	51	29	applied	\N
6	52	30	applied	\N
6	53	31	applied	\N
7	54	24	applied	\N
7	55	25	applied	\N
7	56	26	applied	\N
7	57	27	applied	\N
7	58	28	applied	\N
7	59	29	applied	\N
7	60	30	applied	\N
7	61	31	applied	\N
8	62	24	applied	\N
8	63	25	applied	\N
8	64	26	applied	\N
8	65	27	applied	\N
8	66	28	applied	\N
8	67	29	applied	\N
8	68	30	applied	\N
8	69	31	applied	\N
9	62	24	applied	\N
9	63	25	applied	\N
9	64	26	applied	\N
9	65	27	applied	\N
9	66	28	applied	\N
9	67	29	applied	\N
9	68	30	applied	\N
9	69	31	applied	\N
10	70	24	applied	\N
10	71	25	applied	\N
10	72	26	applied	\N
10	73	27	applied	\N
10	74	28	applied	\N
10	75	29	applied	\N
10	76	30	applied	\N
10	77	31	applied	\N
11	70	24	applied	\N
11	71	25	applied	\N
11	72	26	applied	\N
11	73	27	applied	\N
11	74	28	applied	\N
11	75	29	applied	\N
11	76	30	applied	\N
11	77	31	applied	\N
12	78	25	applied	\N
12	79	26	applied	\N
12	80	27	applied	\N
12	81	28	applied	\N
12	82	29	applied	\N
12	83	30	applied	\N
12	84	31	applied	\N
12	85	32	applied	\N
13	86	16	applied	\N
13	87	17	applied	\N
13	88	18	applied	\N
13	89	19	applied	\N
13	90	20	applied	\N
13	91	21	applied	\N
13	92	22	applied	\N
13	93	23	applied	\N
14	94	24	applied	\N
14	95	25	applied	\N
14	96	26	applied	\N
14	97	27	applied	\N
14	98	28	applied	\N
14	99	29	applied	\N
14	100	30	applied	\N
14	101	31	applied	\N
14	102	32	applied	\N
14	103	33	applied	\N
14	104	34	applied	\N
14	105	35	applied	\N
14	106	36	applied	\N
14	107	37	applied	\N
14	108	38	applied	\N
14	109	39	applied	\N
14	110	40	applied	\N
15	111	24	applied	\N
15	112	25	applied	\N
15	113	26	applied	\N
15	114	27	applied	\N
15	115	28	applied	\N
15	116	29	applied	\N
15	117	30	applied	\N
15	118	31	applied	\N
16	111	24	applied	\N
16	112	25	applied	\N
16	113	26	applied	\N
16	114	27	applied	\N
16	115	28	applied	\N
16	116	29	applied	\N
16	117	30	applied	\N
16	118	31	applied	\N
17	119	25	applied	\N
17	120	26	applied	\N
17	121	27	applied	\N
17	122	28	applied	\N
17	123	29	applied	\N
17	124	30	applied	\N
17	125	31	applied	\N
17	126	32	applied	\N
17	127	33	applied	\N
17	128	34	applied	\N
17	129	35	applied	\N
17	130	36	applied	\N
17	131	37	applied	\N
17	132	38	applied	\N
17	133	39	applied	\N
17	134	40	applied	\N
17	135	41	applied	\N
18	136	24	applied	\N
18	137	25	applied	\N
18	138	26	applied	\N
18	139	27	applied	\N
18	140	28	applied	\N
18	141	29	applied	\N
18	142	30	applied	\N
18	143	31	applied	\N
19	136	24	applied	\N
19	137	25	applied	\N
19	138	26	applied	\N
19	139	27	applied	\N
19	140	28	applied	\N
19	141	29	applied	\N
19	142	30	applied	\N
19	143	31	applied	\N
20	144	19	applied	\N
20	145	20	applied	\N
20	146	21	applied	\N
20	147	22	applied	\N
20	148	23	applied	\N
20	149	24	applied	\N
20	150	25	applied	\N
20	151	26	applied	\N
21	152	16	applied	\N
21	153	17	applied	\N
21	154	18	applied	\N
21	155	19	applied	\N
21	156	20	applied	\N
21	157	21	applied	\N
21	158	22	applied	\N
21	159	23	applied	\N
22	160	18	applied	\N
22	161	19	applied	\N
22	162	20	applied	\N
22	163	21	applied	\N
22	164	22	applied	\N
22	165	23	applied	\N
22	166	24	applied	\N
22	167	25	applied	\N
23	160	18	applied	\N
23	161	19	applied	\N
23	162	20	applied	\N
23	163	21	applied	\N
23	164	22	applied	\N
23	165	23	applied	\N
23	166	24	applied	\N
23	167	25	applied	\N
24	168	16	applied	\N
24	169	17	applied	\N
24	170	18	applied	\N
24	171	19	applied	\N
24	172	20	applied	\N
24	173	21	applied	\N
24	174	22	applied	\N
24	175	23	applied	\N
25	168	16	applied	\N
25	169	17	applied	\N
25	170	18	applied	\N
25	171	19	applied	\N
25	172	20	applied	\N
25	173	21	applied	\N
25	174	22	applied	\N
25	175	23	applied	\N
26	176	16	applied	\N
26	177	17	applied	\N
26	178	18	applied	\N
26	179	19	applied	\N
26	180	20	applied	\N
27	176	16	applied	\N
27	177	17	applied	\N
27	178	18	applied	\N
27	179	19	applied	\N
27	180	20	applied	\N
\.


--
-- Data for Name: blocks_zkapp_commands; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.blocks_zkapp_commands (block_id, zkapp_command_id, sequence_no, status, failure_reasons_ids) FROM stdin;
2	1	0	failed	{1,2}
3	2	0	failed	{3,2}
3	3	1	failed	{4}
3	4	2	failed	{3,2}
3	5	3	failed	{4}
3	6	4	failed	{3,2}
3	7	5	failed	{4}
3	8	6	failed	{3,2}
3	9	7	failed	{4}
3	10	8	failed	{3,2}
3	11	9	failed	{4}
3	12	10	failed	{3,2}
3	13	11	failed	{4}
3	14	12	failed	{3,2}
3	15	13	failed	{4}
3	16	14	failed	{3,2}
3	17	15	failed	{4}
3	18	16	failed	{3,2}
3	19	17	failed	{4}
3	20	18	failed	{3,2}
3	21	19	failed	{4}
3	22	20	failed	{3,2}
3	23	21	failed	{4}
3	24	22	failed	{3,2}
3	25	23	failed	{4}
4	26	0	failed	{3,2}
4	27	1	failed	{4}
4	28	2	failed	{3,2}
4	29	3	failed	{4}
4	30	4	failed	{3,2}
4	31	5	failed	{4}
4	32	6	failed	{3,2}
4	33	7	failed	{4}
4	34	8	failed	{3,2}
4	35	9	failed	{4}
4	36	10	failed	{3,2}
4	37	11	failed	{4}
4	38	12	failed	{3,2}
4	39	13	failed	{4}
4	40	14	failed	{3,2}
4	41	15	failed	{4}
4	42	16	failed	{3,2}
4	43	17	failed	{4}
4	44	18	failed	{3,2}
4	45	19	failed	{4}
4	46	20	failed	{3,2}
4	47	21	failed	{4}
4	48	22	failed	{3,2}
4	49	23	failed	{4}
5	26	0	failed	{3,2}
5	27	1	failed	{4}
5	28	2	failed	{3,2}
5	29	3	failed	{4}
5	30	4	failed	{3,2}
5	31	5	failed	{4}
5	32	6	failed	{3,2}
5	33	7	failed	{4}
5	34	8	failed	{3,2}
5	35	9	failed	{4}
5	36	10	failed	{3,2}
5	37	11	failed	{4}
5	38	12	failed	{3,2}
5	39	13	failed	{4}
5	40	14	failed	{3,2}
5	41	15	failed	{4}
5	42	16	failed	{3,2}
5	43	17	failed	{4}
5	44	18	failed	{3,2}
5	45	19	failed	{4}
5	46	20	failed	{3,2}
5	47	21	failed	{4}
5	48	22	failed	{3,2}
5	49	23	failed	{4}
6	50	0	failed	{3,2}
6	51	1	failed	{4}
6	52	2	failed	{3,2}
6	53	3	failed	{4}
6	54	4	failed	{3,2}
6	55	5	failed	{4}
6	56	6	failed	{3,2}
6	57	7	failed	{4}
6	58	8	failed	{3,2}
6	59	9	failed	{4}
6	60	10	failed	{3,2}
6	61	11	failed	{4}
6	62	12	failed	{3,2}
6	63	13	failed	{4}
6	64	14	failed	{3,2}
6	65	15	failed	{4}
6	66	16	failed	{3,2}
6	67	17	failed	{4}
6	68	18	failed	{3,2}
6	69	19	failed	{4}
6	70	20	failed	{3,2}
6	71	21	failed	{4}
6	72	22	failed	{3,2}
6	73	23	failed	{4}
7	74	0	failed	{3,2}
7	75	1	failed	{4}
7	76	2	failed	{3,2}
7	77	3	failed	{4}
7	78	4	failed	{3,2}
7	79	5	failed	{4}
7	80	6	failed	{3,2}
7	81	7	failed	{4}
7	82	8	failed	{3,2}
7	83	9	failed	{4}
7	84	10	failed	{3,2}
7	85	11	failed	{4}
7	86	12	failed	{3,2}
7	87	13	failed	{4}
7	88	14	failed	{3,2}
7	89	15	failed	{4}
7	90	16	failed	{3,2}
7	91	17	failed	{4}
7	92	18	failed	{3,2}
7	93	19	failed	{4}
7	94	20	failed	{3,2}
7	95	21	failed	{4}
7	96	22	failed	{3,2}
7	97	23	failed	{4}
9	98	0	failed	{3,2}
9	99	1	failed	{4}
9	100	2	failed	{3,2}
9	101	3	failed	{4}
9	102	4	failed	{3,2}
9	103	5	failed	{4}
9	104	6	failed	{3,2}
9	105	7	failed	{4}
9	106	8	failed	{3,2}
9	107	9	failed	{4}
9	108	10	failed	{3,2}
9	109	11	failed	{4}
9	110	12	failed	{3,2}
9	111	13	failed	{4}
9	112	14	failed	{3,2}
9	113	15	failed	{4}
9	114	16	failed	{3,2}
9	115	17	failed	{4}
9	116	18	failed	{3,2}
9	117	19	failed	{4}
9	118	20	failed	{3,2}
9	119	21	failed	{4}
9	120	22	failed	{3,2}
9	121	23	failed	{4}
8	98	0	failed	{3,2}
8	99	1	failed	{4}
8	100	2	failed	{3,2}
8	101	3	failed	{4}
8	102	4	failed	{3,2}
8	103	5	failed	{4}
8	104	6	failed	{3,2}
8	105	7	failed	{4}
8	106	8	failed	{3,2}
8	107	9	failed	{4}
8	108	10	failed	{3,2}
8	109	11	failed	{4}
8	110	12	failed	{3,2}
8	111	13	failed	{4}
8	112	14	failed	{3,2}
8	113	15	failed	{4}
8	114	16	failed	{3,2}
8	115	17	failed	{4}
8	116	18	failed	{3,2}
8	117	19	failed	{4}
8	118	20	failed	{3,2}
8	119	21	failed	{4}
8	120	22	failed	{3,2}
8	121	23	failed	{4}
10	122	0	failed	{3,2}
10	123	1	failed	{4}
10	124	2	failed	{3,2}
10	125	3	failed	{4}
10	126	4	failed	{3,2}
10	127	5	failed	{4}
10	128	6	failed	{3,2}
10	129	7	failed	{4}
10	130	8	failed	{3,2}
10	131	9	failed	{4}
10	132	10	failed	{3,2}
10	133	11	failed	{4}
10	134	12	failed	{3,2}
10	135	13	failed	{4}
10	136	14	failed	{3,2}
10	137	15	failed	{4}
10	138	16	failed	{3,2}
10	139	17	failed	{4}
10	140	18	failed	{3,2}
10	141	19	failed	{4}
10	142	20	failed	{3,2}
10	143	21	failed	{4}
10	144	22	failed	{3,2}
10	145	23	failed	{4}
11	122	0	failed	{3,2}
11	123	1	failed	{4}
11	124	2	failed	{3,2}
11	125	3	failed	{4}
11	126	4	failed	{3,2}
11	127	5	failed	{4}
11	128	6	failed	{3,2}
11	129	7	failed	{4}
11	130	8	failed	{3,2}
11	131	9	failed	{4}
11	132	10	failed	{3,2}
11	133	11	failed	{4}
11	134	12	failed	{3,2}
11	135	13	failed	{4}
11	136	14	failed	{3,2}
11	137	15	failed	{4}
11	138	16	failed	{3,2}
11	139	17	failed	{4}
11	140	18	failed	{3,2}
11	141	19	failed	{4}
11	142	20	failed	{3,2}
11	143	21	failed	{4}
11	144	22	failed	{3,2}
11	145	23	failed	{4}
12	146	0	failed	{3,2}
12	147	1	failed	{4}
12	148	2	failed	{3,2}
12	149	3	failed	{4}
12	150	4	failed	{3,2}
12	151	5	failed	{4}
12	152	6	failed	{3,2}
12	153	7	failed	{4}
12	154	8	failed	{3,2}
12	155	9	failed	{4}
12	156	10	failed	{3,2}
12	157	11	failed	{4}
12	158	12	failed	{3,2}
12	159	13	failed	{4}
12	160	14	failed	{3,2}
12	161	15	failed	{4}
12	162	16	failed	{3,2}
12	163	17	failed	{4}
12	164	19	failed	{3,2}
12	165	20	failed	{4}
12	166	21	failed	{3,2}
12	167	22	failed	{4}
12	168	23	failed	{3,2}
12	169	24	failed	{4}
13	170	0	failed	{3,2}
13	171	1	failed	{4}
13	172	2	failed	{3,2}
13	173	3	failed	{4}
13	174	4	failed	{3,2}
13	175	5	failed	{4}
13	176	6	failed	{3,2}
13	177	7	failed	{4}
13	178	8	failed	{3,2}
13	179	9	failed	{4}
13	180	10	failed	{3,2}
13	181	11	failed	{4}
13	182	12	failed	{3,2}
13	183	13	failed	{4}
13	184	14	failed	{3,2}
13	185	15	failed	{4}
14	186	0	failed	{3,2}
14	187	1	failed	{4}
14	188	2	failed	{3,2}
14	189	3	failed	{4}
14	190	4	failed	{3,2}
14	191	5	failed	{4}
14	192	6	failed	{3,2}
14	193	7	failed	{4}
14	194	8	failed	{3,2}
14	195	9	failed	{4}
14	196	10	failed	{3,2}
14	197	11	failed	{4}
14	198	12	failed	{3,2}
14	199	13	failed	{4}
14	200	14	failed	{3,2}
14	201	15	failed	{4}
14	202	16	failed	{3,2}
14	203	17	failed	{4}
14	204	18	failed	{3,2}
14	205	19	failed	{4}
14	206	20	failed	{3,2}
14	207	21	failed	{4}
14	208	22	failed	{3,2}
14	209	23	failed	{4}
15	210	0	failed	{3,2}
15	211	1	failed	{4}
15	212	2	failed	{3,2}
15	213	3	failed	{4}
15	214	4	failed	{3,2}
15	215	5	failed	{4}
15	216	6	failed	{3,2}
15	217	7	failed	{4}
15	218	8	failed	{3,2}
15	219	9	failed	{4}
15	220	10	failed	{3,2}
15	221	11	failed	{4}
15	222	12	failed	{3,2}
15	223	13	failed	{4}
15	224	14	failed	{3,2}
15	225	15	failed	{4}
15	226	16	failed	{3,2}
15	227	17	failed	{4}
15	228	18	failed	{3,2}
15	229	19	failed	{4}
15	230	20	failed	{3,2}
15	231	21	failed	{4}
15	232	22	failed	{3,2}
15	233	23	failed	{4}
16	210	0	failed	{3,2}
16	211	1	failed	{4}
16	212	2	failed	{3,2}
16	213	3	failed	{4}
16	214	4	failed	{3,2}
16	215	5	failed	{4}
16	216	6	failed	{3,2}
16	217	7	failed	{4}
16	218	8	failed	{3,2}
16	219	9	failed	{4}
16	220	10	failed	{3,2}
16	221	11	failed	{4}
16	222	12	failed	{3,2}
16	223	13	failed	{4}
16	224	14	failed	{3,2}
16	225	15	failed	{4}
16	226	16	failed	{3,2}
16	227	17	failed	{4}
16	228	18	failed	{3,2}
16	229	19	failed	{4}
16	230	20	failed	{3,2}
16	231	21	failed	{4}
16	232	22	failed	{3,2}
16	233	23	failed	{4}
17	234	0	failed	{3,2}
17	235	1	failed	{4}
17	236	2	failed	{3,2}
17	237	3	failed	{4}
17	238	4	failed	{3,2}
17	239	5	failed	{4}
17	240	6	failed	{3,2}
17	241	7	failed	{4}
17	242	9	failed	{3,2}
17	243	10	failed	{4}
17	244	11	failed	{3,2}
17	245	12	failed	{4}
17	246	13	failed	{3,2}
17	247	14	failed	{4}
17	248	15	failed	{3,2}
17	249	16	failed	{4}
17	250	17	failed	{3,2}
17	251	18	failed	{4}
17	252	19	failed	{3,2}
17	253	20	failed	{4}
17	254	21	failed	{3,2}
17	255	22	failed	{4}
17	256	23	failed	{3,2}
17	257	24	failed	{4}
18	258	0	failed	{3,2}
18	259	1	failed	{4}
18	260	2	failed	{3,2}
18	261	3	failed	{4}
18	262	4	failed	{3,2}
18	263	5	failed	{4}
18	264	6	failed	{3,2}
18	265	7	failed	{4}
18	266	8	failed	{3,2}
18	267	9	failed	{4}
18	268	10	failed	{3,2}
18	269	11	failed	{4}
18	270	12	failed	{3,2}
18	271	13	failed	{4}
18	272	14	failed	{3,2}
18	273	15	failed	{4}
18	274	16	failed	{3,2}
18	275	17	failed	{4}
18	276	18	failed	{3,2}
18	277	19	failed	{4}
18	278	20	failed	{3,2}
18	279	21	failed	{4}
18	280	22	failed	{3,2}
18	281	23	failed	{4}
20	282	0	failed	{3,2}
20	283	1	failed	{4}
20	284	2	failed	{3,2}
20	285	3	failed	{4}
20	286	4	failed	{3,2}
20	287	5	failed	{4}
20	288	6	failed	{3,2}
20	289	7	failed	{4}
20	290	8	failed	{3,2}
20	291	9	failed	{4}
20	292	10	failed	{3,2}
20	293	11	failed	{4}
20	294	12	failed	{3,2}
20	295	13	failed	{4}
20	296	14	failed	{3,2}
20	297	15	failed	{4}
20	298	16	failed	{3,2}
20	299	17	failed	{4}
20	300	18	failed	{3,2}
19	258	0	failed	{3,2}
19	259	1	failed	{4}
19	260	2	failed	{3,2}
19	261	3	failed	{4}
19	262	4	failed	{3,2}
19	263	5	failed	{4}
19	264	6	failed	{3,2}
19	265	7	failed	{4}
19	266	8	failed	{3,2}
19	267	9	failed	{4}
19	268	10	failed	{3,2}
19	269	11	failed	{4}
19	270	12	failed	{3,2}
19	271	13	failed	{4}
19	272	14	failed	{3,2}
19	273	15	failed	{4}
19	274	16	failed	{3,2}
19	275	17	failed	{4}
19	276	18	failed	{3,2}
19	277	19	failed	{4}
19	278	20	failed	{3,2}
19	279	21	failed	{4}
19	280	22	failed	{3,2}
19	281	23	failed	{4}
21	301	0	failed	{4}
21	302	1	failed	{3,2}
21	303	2	failed	{4}
21	304	3	failed	{3,2}
21	305	4	failed	{4}
21	306	5	failed	{3,2}
21	307	6	failed	{4}
21	308	7	failed	{3,2}
21	309	8	failed	{4}
21	310	9	failed	{3,2}
21	311	10	failed	{4}
21	312	11	failed	{3,2}
21	313	12	failed	{4}
21	314	13	failed	{3,2}
21	315	14	failed	{4}
21	316	15	failed	{3,2}
22	317	0	failed	{4}
22	318	1	failed	{3,2}
22	319	2	failed	{4}
22	320	4	failed	{3,2}
22	321	5	failed	{4}
22	322	6	failed	{3,2}
22	323	7	failed	{4}
22	324	8	failed	{3,2}
22	325	9	failed	{4}
22	326	10	failed	{3,2}
22	327	11	failed	{4}
22	328	12	failed	{3,2}
22	329	13	failed	{4}
22	330	14	failed	{3,2}
22	331	15	failed	{4}
22	332	16	failed	{3,2}
22	333	17	failed	{4}
23	317	0	failed	{4}
23	318	1	failed	{3,2}
23	319	2	failed	{4}
23	320	4	failed	{3,2}
23	321	5	failed	{4}
23	322	6	failed	{3,2}
23	323	7	failed	{4}
23	324	8	failed	{3,2}
23	325	9	failed	{4}
23	326	10	failed	{3,2}
23	327	11	failed	{4}
23	328	12	failed	{3,2}
23	329	13	failed	{4}
23	330	14	failed	{3,2}
23	331	15	failed	{4}
23	332	16	failed	{3,2}
23	333	17	failed	{4}
24	334	0	failed	{3,2}
24	335	1	failed	{4}
24	336	2	failed	{3,2}
24	337	3	failed	{4}
24	338	4	failed	{3,2}
24	339	5	failed	{4}
24	340	6	failed	{3,2}
24	341	7	failed	{4}
24	342	8	failed	{3,2}
24	343	9	failed	{4}
24	344	10	failed	{3,2}
24	345	11	failed	{4}
24	346	12	failed	{3,2}
24	347	13	failed	{4}
24	348	14	failed	{3,2}
24	349	15	failed	{4}
25	334	0	failed	{3,2}
25	335	1	failed	{4}
25	336	2	failed	{3,2}
25	337	3	failed	{4}
25	338	4	failed	{3,2}
25	339	5	failed	{4}
25	340	6	failed	{3,2}
25	341	7	failed	{4}
25	342	8	failed	{3,2}
25	343	9	failed	{4}
25	344	10	failed	{3,2}
25	345	11	failed	{4}
25	346	12	failed	{3,2}
25	347	13	failed	{4}
25	348	14	failed	{3,2}
25	349	15	failed	{4}
26	350	0	failed	{3,2}
26	351	1	failed	{4}
26	352	2	failed	{3,2}
26	353	3	failed	{4}
26	354	4	failed	{3,2}
26	355	5	failed	{4}
26	356	6	failed	{3,2}
26	357	7	failed	{4}
26	358	8	failed	{3,2}
26	359	9	failed	{4}
26	360	10	failed	{3,2}
26	361	11	failed	{4}
26	362	12	failed	{3,2}
26	363	13	failed	{4}
26	364	14	failed	{3,2}
26	365	15	failed	{4}
27	350	0	failed	{3,2}
27	351	1	failed	{4}
27	352	2	failed	{3,2}
27	353	3	failed	{4}
27	354	4	failed	{3,2}
27	355	5	failed	{4}
27	356	6	failed	{3,2}
27	357	7	failed	{4}
27	358	8	failed	{3,2}
27	359	9	failed	{4}
27	360	10	failed	{3,2}
27	361	11	failed	{4}
27	362	12	failed	{3,2}
27	363	13	failed	{4}
27	364	14	failed	{3,2}
27	365	15	failed	{4}
28	366	0	failed	{3,2}
29	367	0	failed	{4}
29	368	1	failed	{3,2}
29	369	2	failed	{4}
29	370	3	failed	{3,2}
29	371	4	failed	{4}
29	372	5	failed	{3,2}
30	373	0	failed	{4}
31	373	0	failed	{4}
32	374	0	failed	{3,2}
33	375	0	failed	{4}
34	375	0	failed	{4}
\.


--
-- Data for Name: epoch_data; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.epoch_data (id, seed, ledger_hash_id, total_currency, start_checkpoint, lock_checkpoint, epoch_length) FROM stdin;
1	2va9BGv9JrLTtrzZttiEMDYw1Zj6a6EHzXjmP9evHDTG3oEquURA	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	1
2	2vafPBQ3zQdHUEDDnFGuiNvJz7s2MhTLJgSzQSnu5fnZavT27cms	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKz4NPodCRbicX8g1GuWe4axp4FyRncnozQsQyh1a5Um459kBy3	2
3	2vbeM4HaSLxQJDFWp5g8g3fYPZMakHrx4o3HQMdzV9Ts5VL3MNon	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKNPUsWQbLYw4YwWxPQ6hu9vP1zrCyvoSNCAGtTHD5oZYkb6WrE	3
4	2vbBioiwvmmA77BMv2WQJcKRbkYAUjomXeHFMFzuUcW1snEmXufv	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLfncaZJRKHEkBFPaDbuyzkRK85jH5aRKJxvHALs4W7dFW3zB5a	4
5	2vaBAntWKxZEn19qbZn1Z4WufHAyeQEJbbJGeib5HkZ2Rfyet8xJ	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLbqs9rpKheXqJQjoLL88HG4ekwQ3suf5syJB4xevT3B1JcAe2D	5
6	2vbNmL57Q95z8subuevjCE54go6mq44fFPJmekMu4WnaWxpG6sp5	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLbqs9rpKheXqJQjoLL88HG4ekwQ3suf5syJB4xevT3B1JcAe2D	5
7	2var47mScGoHUTeXDjFxvTNz8Parh3gPDsyKWBHgYHFrb1k5BpLs	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLtAE2VC7ukNKvCahnL31BYcH8eu2946U7JFf7ahLeuifZhvGQe	6
8	2vbCxDtaMd1FRwmpv4qcdTyn4zBB92As4qDVGfNPDmCDe8SA1CdX	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKNm4oMSdJK4AP6pvoVpZFkvZFwEePzfF94ojpnWwxyjVfTR2DQ	7
9	2vbfd9rQxH85ydH41XqNaHJHkHPhQjkTyj5HPVHu7MgFpt5yEetz	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKHgWfiFJ9e9PoFBRQWTw3g35m5zzKV3N74LvMC4vTKtffuKBb7	8
10	2vbgzS3ARQemmvmbadsbxPWa6nk37FWQLVQ2CW3H5m4dqStpb52n	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKHgWfiFJ9e9PoFBRQWTw3g35m5zzKV3N74LvMC4vTKtffuKBb7	8
11	2vc53gLdUktJKjwc11kUXouGfw1X3Qpmvqmb538BP2FwfrhVGYRX	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKCdNgLvzwFzAqivAXQe1zDbLLBpeU88MzpzCc4vjhGaK7irjV7	9
12	2vaF6mMaJCFoxs5J1F2tKbBzMmjP6LmRZ4xfGFYHsyMnSuh7Np6Q	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKCdNgLvzwFzAqivAXQe1zDbLLBpeU88MzpzCc4vjhGaK7irjV7	9
13	2vabBwhdubr9tdMeKe8wAYLTgVNDMYsB7gP6uqhXbvMYjkPM3KH5	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKbGB6MEjKq3W7RzX84eR8wKuvrUjwtyofaLUfzbvohKQ5YKNsr	10
14	2vaPjk5f6Ca6fp1cuWivjBwXkLBmQa8TSLuJeh1hGoRhm48HPBxE	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKCwhGwD4kScQP8HbXUN7pn17LsEnRA5UWE5PMWZGx1v7Q9vc9S	11
15	2vaoi1TrjWG5fVhVZnf2sb4hdg3zoRDwetMeBctYBGfs2wyS64aN	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLrHZF25mheLp2EyqWGbQqcLhR3ZaMJHreGh32CczBozZftmKQC	12
16	2vawwLgfk7gYyoUW7sW8XS41wpPRgSy3HoTmWCt4o8tz4boh3ME1	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKexh6yVWTGC6LeF7XPvTvCD9Mhn9tGivjk8yvKDb8fp5aZYgfx	13
17	2vb7fKMU4rsA5qrGcuynPdCiTG19nHLKExWkTYFuuZ2wrQM8VNxb	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKexh6yVWTGC6LeF7XPvTvCD9Mhn9tGivjk8yvKDb8fp5aZYgfx	13
18	2vbkXtCEamePbAD6hyMhcjixRV8oXFi1HJeDVcuhSPQFdU61b5MZ	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKTJQc5p5ijJW26bZ6UBbSqaXSXmPibh2ZSLzcEpCSnsUgN1iZy	14
19	2vaBkH2Z39MfiNrF2WrcvnngzEMNfCsC1sJFsyGfeygS2xbWJXf1	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLRGNt3oBAHAsnA68wpmHdrTnQK1Q2ReCoH5mzpGCkuSL2roWdV	15
20	2vbRnotsbebyeKvrGCAyNagV583Zn8zDBxiGGMc6hQQe2LrFL4Ry	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLRGNt3oBAHAsnA68wpmHdrTnQK1Q2ReCoH5mzpGCkuSL2roWdV	15
21	2vaoAMkAkEMrf4wBaXAjyF2xWN8muUBgfyDnnQQuMz4PfNtLQuUs	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKx7owsixNAwSmvUFM7R6qUTXtT79dpHguPrecu4mvcHuKoexZL	16
22	2vaC1ZUAYkL4mkrTafTVzBU9zAgTqpSurmpvSdYL8a8F5u433KKc	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKETBQh7QDTA8QAZUbwzXWfANXtPekVhPfuCadt7xE7jo9VNMQV	17
23	2vc32zvssiPmYUFMJASwwLHb7KHtsqP63aMkbwv7obf4QNq2Y72A	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLgq7VP5Dt3tiDtB1oegAmkmA6SeeuznaokdFEj9jmv9RB6iP2v	18
24	2vbLyFPTDxzyTswgM6qVoNZWMEDDtYTLoJgWLKhKy8Fo8K3L4S7J	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLgq7VP5Dt3tiDtB1oegAmkmA6SeeuznaokdFEj9jmv9RB6iP2v	18
25	2vbguEnssnuY73xM3BbY8WWTFjeZUxFQqaELtZvFBUn1NpRpvAqo	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLTFZdRKtAmMUsHV5n4XtcsmXVV9yapeoAHNdbGEBz7Gavfs2LM	19
26	2vbaaRguw68xvCS38HERA6jSgkt4xvbSBKYu8b9eKU3rcg1y1tp1	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLTFZdRKtAmMUsHV5n4XtcsmXVV9yapeoAHNdbGEBz7Gavfs2LM	19
27	2vc4yUURVu5dpeEpa1Se6TcX6XeK8DzT6vjxi85ZsEUiEAD3Cm3T	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NL1x9ocYFXzN3DcQQoSA8tqu9z4Tnb1o5H3Jx5tVKRNh9PfHvcL	20
28	2vbpWmjc1YUgiMT23YTzA2U19i6eGmchFnhxg5MJuRPMpbWWJBDQ	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NL1x9ocYFXzN3DcQQoSA8tqu9z4Tnb1o5H3Jx5tVKRNh9PfHvcL	20
29	2vbMD7g2KgNeLehjdB6X2pxB5vuggTfX99jxchTCriUsNwV1HcrX	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKPvMa4FYW2y8V1ShtJHyqfo85jXWKGrnB86f4Xbz4WZ2BYQdfn	21
30	2vauDURiTyXNAhZHCPtMQbrGv6YvamX9BuxANfB3YUm77pML7UDR	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLUzJGgnrE93Ts9WYyGVPtX3Ji85D9DxqRc2vq6vueUjrtcH2Pt	22
31	2vaUJ8549mQGjAhKF1efm17ydN9dYEuimnt7jBaKT59d3ffe76GJ	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NL7QDSGRRUCa9GdegCM32vpQhytGkrUnYAu48wZbK2ekQqSCkQo	23
32	2vbXGpBf1hwNpnLfJKxrSHvBh4gmSur1bAj78evNgPENdKJjvXos	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NL7QDSGRRUCa9GdegCM32vpQhytGkrUnYAu48wZbK2ekQqSCkQo	23
33	2vbooWxyMN5NL31LXU6g9KneLxs85eKifUZ9BSmopxofg9bjCWs5	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKmJVLcqNfQYjTfKHAB2JfqTeNEQtncq5UfBrncPqjrgpTW1oCD	24
34	2vc27WPKLbeqFy4M2jBCQoCZyPUyijPRL96ZiG5sFhEgENiurijr	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NL4cysEfp9U33dRJGcZ1Pv6i26mz19VKqimvMEDae94dtx7YUvC	25
35	2vahn4hUmptdHEGXrDAmEqp3Uac698xb88eixCcdc8fSmnuj1yLT	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NL4cysEfp9U33dRJGcZ1Pv6i26mz19VKqimvMEDae94dtx7YUvC	25
\.


--
-- Data for Name: internal_commands; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.internal_commands (id, command_type, receiver_id, fee, hash) FROM stdin;
1	coinbase	28	720000000000	5JuWtfFw6YWHQ6fPohNXwjjUA43VY47ZjHVUEaY6U3yXDA4XCXpv
2	fee_transfer	28	5000000000	5JtcBc6Gvm1MUWxzoENEUpj8ZKpVRFvt1HMXx6s7AHnXJkuPPDUi
3	fee_transfer	28	125250000000	5JtzveiFLvKmS8duLiuKD1bJC6z2E8b8cSDZEj8kmCfwPNtXZfjs
4	fee_transfer	28	126250000000	5Jtt6avGtcDtMcZS11JYgTbPKCPVBgbxBSHAhE39fmpPSdPAVf1j
5	coinbase	12	720000000000	5JuZFwXkGah51rP39SxJZgbgEHE3nBhjjzbY9HALPCJ6gGoFH7mQ
6	fee_transfer	12	126250000000	5Juo3XnQfg36tPTgAWLybgeBeJf5VM5s74nV35BHw1v9gwWx2nP6
7	fee_transfer	28	120500000000	5JuCxs9XrEhpJJ1t9Trgr2vAWxYt8L59DCcPNB8r4xHP156ucN21
8	fee_transfer	28	1250000000	5JumUQdXgkiNL74v8ktkxKF4bM6ZXgRotUvVkawsLsUP5c6sE93t
9	fee_transfer	12	122000000000	5JtmdAwc4yEXJiju2bxM52pG8RG44BcFg9yd7sG4iPaa19uriDh6
10	fee_transfer	28	122000000000	5JvPyUWQi1sEeBseu2pTqxBVz2fXHakbhZpJZh6KFzpcsLWDKZpJ
11	fee_transfer	12	90000000000	5JuDyT19bxg2B8SSGhevUPiXSPhJrVBvcKGZbkpYjU3vWK2hMQzw
12	fee_transfer	12	32000000000	5JuLsVcijYQ1rBQkgYmRSe9SJWtS6PZEbtM1sH9a7P2LWj56tKoV
13	fee_transfer	12	82000000000	5JthpWFTqWkJPECxxHru5sAxTzRHxr9hfQ2bgSvH7DXyywXpy2VE
14	fee_transfer	28	124250000000	5JtwRLeXXZqXWV6BSSXuurLjZZkAcLiq4HiJ4EQmLnNkXeAHTfWp
15	fee_transfer	28	40000000000	5JtWgStkV99PuT7hhPdZEUxHuoC8c5vQU8wypwKYjrEccXTQHJ7M
16	fee_transfer_via_coinbase	131	1000000	5Jtq1kqCJSCoJsrrD3bPdUibFiskHrG5Ai2PBmHBVcbXaFhTq95f
17	coinbase	28	720000000000	5Juj9wCLqZb91WfW46ZcrBq6CErBvwkDtug5tsdugJAQP2vaaLpU
18	fee_transfer	28	84196000000	5Jv4DjfgLhWs9xinEfRxG9XFueHQNCJg2dBuc1KuPe5mPdGscC9P
19	fee_transfer	131	54000000	5JvQ5sLMyLVsDd6YRLLbUugbYV6MuSPAAB74nxuwhtcatsz3JXEB
20	fee_transfer	28	121997000000	5JtViNfKhnALQUMc8uPwB7j2gVhiB1mfYLuJVsuBo3itp9VaBksu
21	fee_transfer	131	3000000	5JuL1UErnHXQnxMgAFKzJmhhu814TqA1LcrjKYiJ2GtU6tdSGqYV
22	coinbase	12	720000000000	5Juu4vsbDqUN4qmbhPqmeLj4Y25QA2vbAKP6AcTbkRJcwcoBCuvu
23	fee_transfer	12	121997000000	5JvN6TMfw82VPeiTB9gD1AGr4NCpSWHG2Cu1BUDnvjTzV5x2VPxC
24	fee_transfer	28	96998000000	5JvBSzperGMyuAhFScgyoYYxpAbSvzDLjoZdcsxbHaNAKsHnk5fS
25	fee_transfer	131	2000000	5JtwuwYGpuihPuk7n7nBoujpDpageYQU5BN78wqDR82HLc54E3xf
26	fee_transfer	28	81999000000	5Ju33FSr3y53HhEuTJtCTWVmHp4XT4ZmCxgsarydjs9K5Wx5jNrk
27	fee_transfer	131	1000000	5Jtq1kqCJSCoJsrrD3bPdUibFiskHrG5Ai2PBmHBVcbXaFhTq95f
28	fee_transfer	12	15000000000	5JvAtpYQ8qKE5yi9ggxZwFdmLJBZe3UPe18zsmu1NMNQNu48mtsf
29	fee_transfer	131	5000000	5JtkuXxwEXtCVjPo3Cts8QteVfV9K5fTZ89L4tGRp5UbLhRENkW5
30	fee_transfer	12	71995000000	5JuE8MC9hwFTAqqERzaV4LK98g8e3UZ84NvG8bymGc36knxBEKZR
31	fee_transfer	28	15000000000	5Jv8jrTyPSXUvoak4yqkAci6vypSha57FfkEwYppW1pJYwwgmtCN
32	fee_transfer	28	71995000000	5JuzsyBCs7FVdZkhLnUeZrhe5B7d1EM5bRiJc8E3QZSWDNEBXY9r
33	fee_transfer	12	81998000000	5Ju7NNPW6ioqJsnjGy7DvMg4VFW9ovMzYqEPDDeqiy9WsspEcS31
34	fee_transfer	28	81998000000	5Ju3BDiStEmoTzMxXMPGiU5jih5bDR1ype7AViw3wu2pUPMVVPzL
35	fee_transfer	28	81248000000	5JtkusZjsvEXiNGrrsxXF1NoXKq1sCY88nEcb2riCG6U9HL2yghz
36	fee_transfer	12	81248000000	5JvGH2vwaQuxyYgH6fCjaSjh4SCkEcBpcXA2yFWKZ8V2J96wFnhs
37	fee_transfer	28	4998000000	5JvB1cjWKb1d2Cc9QRu32QKnwo25inGkzTUpwmo57xLMkiQxZEuL
38	fee_transfer	131	7000000	5Ju4kwsrikVwSccZNKZTbiHaLKEiUjykDUN1CeHsrLyj6hCxsZbg
39	fee_transfer	12	29993000000	5JuRavvr7fz5o4UDao6jFFyS7QLa4XWQkrzGPdHVEdx7nKe15sqK
40	fee_transfer	12	4998000000	5JvK8iNLhVAH9v82r9NtMEmvwV7xHQCxh7ZGF5mMW1wtqWtPBpdQ
\.


--
-- Data for Name: protocol_versions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.protocol_versions (id, transaction, network, patch) FROM stdin;
1	3	0	0
\.


--
-- Data for Name: public_keys; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.public_keys (id, value) FROM stdin;
1	B62qiy32p8kAKnny8ZFwoMhYpBppM1DWVCqAPBYNcXnsAHhnfAAuXgg
2	B62qp3Wu9Ayd7rkDrJDvoi6zMKciG1Jv6imE9SRUJzdUbQHVttKPWPF
3	B62qr6VZXBDXUntN5bcwu69ae4oqsB7J7cHYaUWKhWygfujRCtFu4C3
4	B62qnFJWYYYbTuDWQ5oCRhP4hT8sc8F1xDf34wyxhvTzosxnV6UYNDP
5	B62qmmV9zHiWwXj2Do14t2bUtT7onfHwsNa7KSJxrFhpXbunUd9gLEi
6	B62qnzUQLreTeYj7TkkKyFR9s5REY6GTKc4sVK8K34Xvw8dfRPAUByg
7	B62qoxkuzRkqEXbw2D7FS1EJctSvrKhFDjwo1s7UqaRbzAC9wW9CqXB
8	B62qk4Y4VLT1oUbD1NjPunSEUjz5yVNbiETWCfNTvT5VLrmbRwnKcMk
9	B62qnsdKhWmeQZjvas2bVuE7AcUjqWxSjb5B6pFqyVdtVbrro8D9p9F
10	B62qqDcNXt7LK6686QQ9TvLaFF5as6xRRSMEjfwXJUEk3hSHVXksUth
11	B62qqPeku1tmtDG2pRHFg9ZQvvx8wpYUqJ3QTh9jRfVB1Hx63E93swL
12	B62qpQEAe8zRTmWuMuaqsRwHE7BoUFBXiYQEwcbPF5kYcv3yrZhMspm
13	B62qmRRtdPM1XRnHpchjrVdVyRtUKFX5Nmrhu7MWSs3wDVsLuTQ54dV
14	B62qnT7rV3ZQ71n6Z2RaPZSn38zEniZq1A8CXEdArxrF7q6sTTWZdZc
15	B62qmnTkaf43Ctbxq1NgvtakVwKKcB1nk2vee61bMAcPfDB5FR5upJN
16	B62qpTgN6VhfdCGimamFjarhSBfiK1oGEKyrqHN5FHejeJR8Z2vgKYt
17	B62qkaFHyAx1TMzuez3APX1hG33j2ZXCTXJFFzeSxgt8fA3henaeT84
18	B62qkCd6ftXqh39xPVb7qyJkSWZYa12QCsxFCaCmDrvfZoTNYmKQtkC
19	B62qrEWSxSXzp8QLDpvuJKeHWxybsE2iwaMPViMpdjptmUxQbtDV178
20	B62qnUCyUPAGE9ZXcu2TpkqUPaU3fhgzxRSEiyt5C8V7mcgNNvj1oc9
21	B62qiquMTUSJa6qqyd3hY2PjkxiUqgPEN2NXYhP56SqwhJoBsFfEF5T
22	B62qm174LzHrFzjwo3jRXst9LGSYjY3gLiCzniUkVDMW912gLBw63iZ
23	B62qrrLFhpise34oGcCsDZMSqZJmy9X6q7DsJ4gSAFSEAJakdwvPbVe
24	B62qo11BPUzNFEuVeskPRhXHYa3yzf2WoGjdZ2hmeBT9RmgFoaLE34A
25	B62qmSTojN3aDbB311Vxc1MwbkdLJ4NCau8d6ZURTuX9Z57RyBxWgZX
26	B62qiaEMrWiYdK7LcJ2ScdMyG8LzUxi7yaw17XvBD34on7UKfhAkRML
27	B62qqk3XMJoiGGfoXuT3KeZVZpgNA7EN5gSDcENgSRHEuvHdQMkXRXW
28	B62qqcgKQdaK6PtmR3ZdkGkhZ5pq9CLtDvC5UGVm9H1Bbjzy1ThUkXM
29	B62qoGEe4SECC5FouayhJM3BG1qP6kQLzp3W9Q2eYWQyKu5Y1CcSAy1
30	B62qn8rXK3r2GRDEnRQEgyQY6pax17ZZ9kiFNbQoNncMdtmiVGnNc8Y
31	B62qnjQ1xe7MS6R51vWE1qbG6QXi2xQtbEQxD3JQ4wQHXw3H9aKRPsA
32	B62qmzatbnJ4ErusAasA4c7jcuqoSHyte5ZDiLvkxnmB1sZDkabKua3
33	B62qrS1Ry5qJ6bQm2x7zk7WLidjWpShRig9KDAViM1A3viuv1GyH2q3
34	B62qqSTnNqUFqyXzH2SUzHrW3rt5sJKLv1JH1sgPnMM6mpePtfu7tTg
35	B62qkLh5vbFwcq4zs8d2tYynGYoxLVK5iP39WZHbTsqZCJdwMsme1nr
36	B62qiqUe1zktgV9SEmseUCL3tkf7aosu8F8HPZPQq8KDjqt3yc7yet8
37	B62qkNP2GF9j8DQUbpLoGKQXBYnBiP7jqNLoiNUguvebfCGSyCZWXrq
38	B62qr4z6pyzZvdfrDi33Ck7PnPe3wddZVaa7DYzWHUGivigyy9zEfPh
39	B62qiWZKC4ff7RKQggVKcxAy9xrc1yHaXPLJjxcUtjiaDKY4GDmAtCP
40	B62qqCpCJ7Lx7WuKCDSPQWYZzRWdVGHndW4jNARZ8C9JB4M5osqYnvw
41	B62qo9mUWwGSjKLpEpgm5Yuw5qTXRi9YNvo5prdB7PXMhGN6jeVmuKS
42	B62qpRvBE7SFJWG38WhDrSHsm3LXMAhdiXXeLkDqtGxhfexCNh4RPqZ
43	B62qoScK9pW5SBdJeMZagwkfqWfvKAKc6pgPFrP72CNktbGKzVUdRs3
44	B62qkT8tFTiFfZqPmehQMCT1SRRGon6MyUBVXYS3q9hPPJhusxHLi9L
45	B62qiw7Qam1FnvUHV4JYwffCf2mjcuz2s5F3LK9TBa5e4Vhh7gq2um1
46	B62qrncSq9df3SnHmSjFsk13W7PmQE5ujZb7TGnXggawp3SLb1zbuRR
47	B62qip9dMNE7fjTVpB7n2MCJhDw89YYKd9hMsXmKZ5cYuVzLrsS46ZG
48	B62qmMc2ec1D4V78sHZzhdfBA979SxUFGKTqHyYcKexgv2zJn6MUghv
49	B62qqmQhJaEqxcggMG9GepiXrY1j4WgerXXb2NwkmABwrkhRK671sSn
50	B62qp7yamrqYvcAv3jJ4RuwdvWnb8zFGfXchbfqR4BCkeub998mVJ3j
51	B62qk7NGhMEpPAwdwfqnxCbAuCm1qawX4YXh956nanhkfDdzZ4vZ91g
52	B62qnUPwKuUQZcNFnr5L5S5mpH9zcKDdi2FsKnAGQ1Vrd3F4HcH724A
53	B62qqMV93QdKFLmPnqvzaBE8T2jY38HVch4JW5xZr4kNHNYr1VtSUn8
54	B62qmtQmCLX8msSHASDTzNtXq81XQoNtLz6CUMhFeueMbJoQaYbyPCi
55	B62qp2Jgs8ChRsQSh93cL2SuDN8Umqp6GtDd9Ng7gpkxgw3Z9WXduAw
56	B62qo131ZAwzBd3mhd2GjTf3SjuNqdieDifuYqnCGkwRrD3VvHLM2N1
57	B62qo9XsygkAARYLKi5jHwXjPNxZaf537CVp88npjrUpaEHypF6TGLj
58	B62qnG8dAvhGtPGuAQkwUqcwpiAT9pNjQ7iCjpYw5k2UT3UZTFgDJW1
59	B62qj3u5Ensdc611cJpcmNKq1ddiQ63Xa8L2DnFqEBgNqBCAqVALeAK
60	B62qjw1BdYXp74JQGoeyZ7bWtnsPPd4iCxBzfUsiVjmQPLk8984dV9D
61	B62qpP2xUscwDA5TaQee71MGvU7dYXiTHffdL4ndRGktHBcj6fwqDcE
62	B62qo1he9m5vqVfbU26ZRqSdyWvkVURLxJZLLwPdu1oRAp3E7rCvyxk
63	B62qjzHRw1dhwS1NCWDH64yzovyxsbrvqBW846BRCaWmyJyoufddBSA
64	B62qkoANXg95uVHwpLAiQsT1PaGxuXBcrBzdjMgN3mP5WJxiE1uYcG9
65	B62qnzk698yW9rmyeC8mLCKhdmQZa2TRCG5hN3Z5NovZZqE1oou7Upc
66	B62qrQDYA9DvUNdgU87xp64MsQm3MxBeDRNuhuwwQ3hfS5sJhchipzu
67	B62qnSKLuJiF1gNnCEDHJeWFKPbYLKjXqz18pnLGE2pUq7PBYnU4h95
68	B62qk8onaP8h1VYVbJkQQ8kKtHszsA12Haw3ts5jm4AkpvNDkhUtKBH
69	B62qnbQoJyaGKvgRDthSPwWZPrYiYCpqeYoHhJ9415r1ws6DecWa8h9
70	B62qmpV1DwQvBMUmBxyDV6jJwSpS1zFWHHEZYuXYhPja4RWCbYG3Hv1
71	B62qiYSHjqf77rS6eBiBSiDwgqpsZEUf8KZZNmpxzULpxqm58u49m7M
72	B62qrULyp6Kp5PAmtJMHcRngmHyU2t9DF2oBpU4Q1GMvfrgsUBVUSm8
73	B62qpitzPa3MB2eqJucswcwQrN3ayxTTKNMWLW7SwsvjjR4kTpC57Cr
74	B62qpSfoFPJPXvyUwXWGJqTVya4kqThCH5LyEsdKrmqRm1mvDrgsz1V
75	B62qk9uVP24E5fE5x4FxnFxz17TBAZ4rrkmRDErheEZnVyFmCKvdBMH
76	B62qjeNbQNefZdv388wHg9ancPdFBw6Dj2Wxo6Jyw2EhR7J9kti48qx
77	B62qqwCS1S72xt9VPD6C6FjJkdwDghRCWJnYjebCagX8M2xzthqKDQC
78	B62qrGWHg32ZdFydA4UF7prU4zm3UH3dRxJZ5xAHW1QtNhgzuP2G62z
79	B62qkqZ1b8BkCK9PqWnQLjYueExVUVJon1Nn15SnZScG5AR3LqkEqzY
80	B62qkQ9tPTmzm9oD2i8HbDRERFBHvG7Mi3dz6XLa3BEJcwA4ZcQaDa8
81	B62qnt4FQxWNcP49W5HaQNEe5Q1KqTBQJnnyqn7KyvSfNb6Dskbhy9i
82	B62qoxTxNh4o9ftUHSRatjTQagToJy7pW1zh7zZdyFYr9ECNDvugmyx
83	B62qrPuf95oqANBTTmvcvM1BKkBNrsmaXnaNpHGJYersezYTHWq5BTh
84	B62qkBdApDjoUj9Lckf4Bg7fWJSzSnyJHyCNkvq7XsPVzWk97BeGkae
85	B62qs23tCNy7qbrYHBwMfVNyiA82aA7xtWKh3QkFr1fMog3ptyXhptq
86	B62qpMFwmJ6fMm4cUb9wLLwoKRPFpYUJQmYqDe7RRaXgvAHjJpnEz3f
87	B62qkF4qisEVJ3WBdxcWoianq4YLaYXw89yJRzc7cPRu2ujXqp4v8Ji
88	B62qmFcUZJgxBQpTxnQHjyHWdprnsmRDiTZe6NiMNF9drGTM8hh1tZf
89	B62qo4Pc6HKhbc55RZuPrDfzbVZfxDqxkG3hV7sRDSivAthXAjtWaGg
90	B62qoKioA9hueF4xhZszsACn6GT7o69wZZJUoErVyvgP7WPrj92e9Tv
91	B62qkoTczRzwCUr6AmSiNcr3UWwkgbWeihVZphwP8CEuiDzrNHvunTX
92	B62qpGkYNpBS3MBgortSQuwV1aXcK6bRRQyYz3wGW5tCpCLdvxk8J6q
93	B62qnYfsf8P7B7UYcjN9bwL7HPpNrAJh7fG5zqWvZnSsaQJP2Z1qD84
94	B62qpAwcFY3oTy2oFUEc3gB4x879CvPqHUqHqjT3PiGxggroaUYHxkm
95	B62qib1VQVfLQeCW6oAKEX2GRuvXjYaX2Lw9qqjkBPAvdshHPyJXVMv
96	B62qm5TQe1nz3gfHqb6S4FE7FWV92AaKzUuAyNSDNeNJYgND35JaK8w
97	B62qrmfQsKRd5pwg1EZNYXSmcbsgCekCkJAxxJcZhWyX7ChfExZtFAj
98	B62qitvFhawB29DGkGv9NEfGZ8d9hECEKnKMHAvtULVATdw5epPS2s6
99	B62qo81kkuqxFZw9cZAcoYb4ZeCjY9HodT3yDkh8Zxhg9omfRexyNAz
100	B62qmeDPPUDtPVVHqesiKD7ecz6YZvGDHzVw2swBa84EGs5NBKpGK4H
101	B62qqwLQXBrhJmfAtF7GUf7FNVS2xoTPrkyw7d4Pj9W431bpysAdr3V
102	B62qkgcEQJ9qhjwQgt2XeN3RJpPTfjCrqFUUAW2NsVpzmyQwFbekNMM
103	B62qnAotEqbcE8sjbdyJkkvKnTzW3BCPaL5HrMEdHa4pVnfPBXWGXXW
104	B62qquzjE4bbK3mhk6jtFMnkm9BdzasTHuvMxx6JmhXeYKZkPbyZUry
105	B62qrj3VHfVadkyJCvmu7SvczS7QZy1Yk1uQjcjwkS4QqDt9oqi4eWf
106	B62qn6fTLLatKHi4aCX7p6Lg5rzZSq6VK2vrFVgX14gjaQqay8zHfsJ
107	B62qjrBApNy5mx6biRzL5AfRrDEarq3kv9Zcf5LcUR6iKAX9ve5vvud
108	B62qkdysBPreF3ef7bFEwCghYjbywFgumUHXYKDrBkUB89KgisAFGSV
109	B62qmRjcL489UysBEnabin5be824q7ok4VjyssKNutPq3YceMRSW4gi
110	B62qo3TjT6pu6i7UT8w39UVQc2Ljg8K69eng55vu5itof3Ma3qwcgZF
111	B62qpXFq7VJG6Spy7BSYjqSC1GBwKLCzfU8bcrUrALEFEXphpvjn3bG
112	B62qmp2xXJyj9LegRQUtFMCCGV3DQu337n6s6BK8a2kaYrMf1MmZHkT
113	B62qpjkSafKdAeCBh6PV6ZizJjtfs3v1DuXu1WowkYq2Bcr5X7bmk7G
114	B62qnjhGUFX636v8HyJsYKUkAS5ms58q9C9GtwNvPbMzMVy7FmRNhLG
115	B62qoCS2htWnx3g8gFq2ypSLHMW1jkZF6XMTH8yKE8gYTH7jfrcdjCo
116	B62qk2wpLtL3PUEQZBYPeabiXcZi6yzbVimciFWZSCHpxufKFDTmhi6
117	B62qjWRcn5eRmdppcsDNudiogbnNPzW4jWC6XH2LczMRDXzjK9AgfA2
118	B62qjJrgSK4wa3HnZZqmfJzxtMfACK9r2zEHqo5Rm6UUvyFrk4UjdPW
119	B62qoq6uA96gWVYBDtMQLZC5hB4hgAVojbuhw9Z2CE1Acj6iESSS1cE
120	B62qkSpe1P6FgwWU3BfvU2FXnuYt2vR4DzsEZf5TbJynBgyZy7W9yyE
121	B62qr225GCSVzAGKBYxB7rKE6ibtQAcfcXMfYH84hvkqHWAnFzWR4RT
122	B62qkQT9sAztAWnYdxQMaQSxrA93DRa5f8LxWCEzYA3Y3tewDQKUMyQ
123	B62qieyc3j9pYR6aA8DC1rhoUNRiPacx1ij6qW534VwTtuk8rF2UBrk
124	B62qoFyzjU4pC3mFgUidmTFt9YBnHjke5SU6jcNe7vVcvvoj4CCXYJf
125	B62qihY3kUVYcMk965RMKfEAYRwgh9ATLBWDiTzivneCmeEahgWTE58
126	B62qm8kJSo4SZt7zmNP29aYAUqETjPq6ge2hj5TxZWxWK2JDscQtx1Y
127	B62qkY3LksqsR2ETeNmAHAmYxi7mZXsoSgGMEMujrPtXQjRwxe5Bmdn
128	B62qrJ9hFcVQ4sjveJpQUsXZenisBnXKVzDdPntw48PYXxP17DNdKg4
129	B62qpKCYLZz2Eyb9vFfaVPgWjTWf1p3VpBLnQSSme2RC3ob4m1p8fCv
130	B62qkFYQghamWpPuNxzr1zw6ARk1mKFwkdQWJqHvmxdM95d45AjwWXE
131	B62qidsh4uKyukgEfB4cUS6rekXPYcgGYwoJsCpESySE6YkwaUE9stu
132	B62qnzhgbY3HD19eKMeQTFPZijFTvJN82pHeGYQ2xM9HxZRPv6xhtqe
133	B62qroho2SKx4wignPPRf2qPbGzvfRgQf4zCMioxnmwKyLZCg3reYPc
134	B62qm4jN36Cwbtyd8j3BLevPK7Yhpv8KtWTia5fuwMAyvcHLCosU4PN
135	B62qs2YqK7gE8ztNdJdn4FRbiFBbQRETaHTAUdbjWvbAKxEbXQeZQGt
136	B62qj7FPxEA3TNeBDjKFoyvS1iaFdqtBYmMrjyk4CxVnj1LEBMCJWPo
137	B62qk9Dk1rwSVtSLCYdWNfPTXRPDWPPu3rR5sqvrawP82m9P1LhBZ94
138	B62qnR8RErysAmsLHk6E7teSg56Dr3RyF6qWycyVjQhoQCVC9GfQqhD
139	B62qo7XmFPKML7WfgUe9FvCMUrMihfapBPeCJh9Yxfka7zUwy1nNDCY
140	B62qqZw4bXrb8PCxvEvRJ9DPASPPaHyoAWXw1avG7mEjnkFy7jGLz1i
141	B62qkFKcfRwVgdQ1UDhhCoExwsMPNWFJStxnDtJ1hNVmLzzGsyCRLuo
142	B62qofSbCaTfL61ZybYEpAeGe14TK8wNN8VFDV8uUEVBGpqVDAxYePK
143	B62qn8Vo7WTK4mwQJ8sjiQvbWDavetBS4f3Gdi42KzQZmL3sri25rFp
144	B62qo6pZqSTym2umKYeZ53F1woYCuX3qHrUtTezBoztURNRDAiNbq5Q
145	B62qo8AvB3EoCWAogvUg6wezt5GkNRTZmYXCw5Gutj8tAg6cdffX3kr
146	B62qqF7gk2yFsigWL7JyW1R8sdUcQjAPkp32i9B6f9GRYMzFoLPdBqJ
147	B62qjdhhu4bsmbMFxykEgbhf4atVvgQWB4dizqsMEBbmQPe9GeXZ42N
148	B62qmCsUFPNLpExtzt6NUeosa8L5qb7cEKi9btkMdAQS2GnQzTMjUGM
149	B62qneAWh9zy9ufLxKJfgrccdGfbgeoswyjPJp2WLhBpWKM7wMJtLZM
150	B62qoqu7NDPVJAdZPJWjia4gW3MHk9Cy3JtpACiVbvBLPYw7pWyn2vL
151	B62qmwfTv4co8uACHkz9hJuUND9ubZfpP2FsAwvru9hSg5Hb8rtLbFS
152	B62qkhxmcB6vwRxLxKZV2R4ifFLfTSCdtxJ8nt94pKVbwWd9MshJadp
153	B62qjYRWXeQ52Y9ADFTp55p829ZE7DE4zn9Nd8puJc2QVyuiooBDTJ3
154	B62qo3b6pfzKVWNFgetepK6rXRekLgAYdfEAMHT6WwaSn2Ux8frnbmP
155	B62qncxbMSrL1mKqCSc6huUwDffg5qNDDD8FHtUob9d3CE9ZC2EFPhw
156	B62qpzLLC49Cb6rcpFyCroFiAtGtBCXny9xRbuMKi64vsU5QLoWDoaL
157	B62qj7bnmz2VYRtJMna4bKfUYX8DyQeqxKEmHaKSzE9L6v7fjfrMbjF
158	B62qnEQ9eQ94BxdECbFJjbkqCrPYH9wJd7B9rzKL7EeNqvYzAUCNxCT
159	B62qokmEKEJs6VUV7QwFaHHfEr6rRnFXQe9jbodnaDuWzfUK6YoXt2w
160	B62qpPJfgTfiSghnXisMvgTCNmyt7dA5MxXnpHfMaDGYGs8C3UdGWm7
161	B62qkzi5Dxf6oUaiJYzb5Kq78UG8fEKnnGuytPN78gJRdSK7qvkDK6A
162	B62qs2sRxQrpkcJSkzNF1WKiRTbvhTeh2X8LJxB9ydXbBNXimCgDQ8k
163	B62qoayMYNMJvSh27WJog3K74996uSEFDCmHs7AwkBX6sXiEdzXn9SQ
164	B62qibjCrFmXT3RrSbHgjtLHQyb63Q89gBLUZgRj7KMCeesF9zEymPP
165	B62qrw63RAyz2QfqhHk8pttD2ussturr1rvneUWjAGuhsrGgzxr2ZRo
166	B62qmNVzYukv4VxXoukakohrGNK7yq1Tgjv5SuX1TTWmpvVwD5Xnu2L
167	B62qoucdKZheVHX8udLGmo3vieCnyje5dvAayiLm8trYEp3op9jxCMa
168	B62qo51F51yp7PcqmHd6G1hpNBAj3kwRSQvKmy5ybd675xVJJVtMBh8
169	B62qjHbDMJGPUz3M6JK2uC3tm6VPLaEtv4sMCcrMBz6hnD5hrET4RJM
170	B62qnyxTMk4JbYsaMx8EN2KmoZUsb9Zd3nvjwyrZr2GdAHC9nKF16PY
171	B62qrPo6f9vRwqDmgfNYzaFd9J3wTwQ1SC72yMAxwaGpjt2vJrxo4ri
172	B62qoZXUxxowQuERSJWb6EkoyciRthxycW5csa4cQkZUfm151sn8BSa
173	B62qr7QqCysRpMbJGKpAw1JsrZyQfSyT4iYoP4MsTYungBDJgwx8vXg
174	B62qo3JqbYXcuW75ZHMSMnJX7qbU8QF3N9k9DhQGbw8RKNP6tNQsePE
175	B62qjCC8yevoQ4ucM7fw4pDUSvg3PDGAhvWxhdM3qrKsnXW5prfjo1o
176	B62qnAcTRHehWDEuKmERBqSakPM1dg8L3JPSZd5yKfg4UNaHdRhiwdd
177	B62qruGMQFShgABruLG24bvCPhF2yHw83eboSqhMFYA3HAZH9aR3am3
178	B62qiuFiD6eX5mf4w52b1GpFMpk1LHtL3GWdQ4hxGLcxHh36RRmjpei
179	B62qokvW3jFhj1yz915TzoHubhFuR6o8QFQReVaTFcj8zpPF52EU9Ux
180	B62qr6AEDV6T66apiAX1GxUkCjYRnjWphyiDro9t9waw93xr2MW6Wif
181	B62qjYBQ6kJ9PJTTPnytp4rnaonUQaE8YuKeimJXHQUfirJ8UX8Qz4L
182	B62qqB7CLD6r9M532oCDKxxfcevtffzkZarWxdzC3Dqf6LitoYhzBj9
183	B62qr87pihBCoZNsJPuzdpuixve37kkgnFJGq1sqzMcGsB95Ga5XUA6
184	B62qoRyE8Yqm4GNkjnYrbtGWJLYLNoqwWzSRRBw8MbmRUS1GDiPitV7
185	B62qm4NwW8rFhUh4XquVC23fn3t8MqumhfjGbovLwfeLdxXQ3KhA9Ai
186	B62qmAgWQ9WXHTPh4timV5KFuHWe1GLb4WRDRh31NULbyz9ub1oYf8u
187	B62qroqFW16P7JhyaZCFsUNaCYg5Ptutp9ECPrFFf1VXhb9SdHE8MHJ
188	B62qriG5CJaBLFwd5TESfXB4rgSDfPSFyYNmpjWw3hqw1LDxPvpfaV6
189	B62qjYVKAZ7qtXDoFyCXWVpf8xcEDpujXS5Jvg4sjQBEP8XoRNufD3S
190	B62qjBzcUxPayV8dJiWhtCYdBZYnrQeWjz28KiMYGYodYjgwgi961ir
191	B62qkG2Jg1Rs78D2t1DtQPjuyydvVSkfQMDxBb1hPi29HyzHt2ztc8B
192	B62qpNWv5cQySYSgCJubZUi6f4N8AHMkDdHSXaRLVwy7aG2orM3RWLp
193	B62qism2zDgKmJaAy5oHRpdUyk4EUi9K6iFfxc5K5xtARHRuUgHugUQ
194	B62qqaG9PpXK5CNPsPSZUdAUhkTzSoZKCtceGQ1efjMdHtRmuq7796d
195	B62qpk8ww1Vut3M3r2PYGrcwhw6gshqvK5PwmC4goSY4RQ1SbWDcb16
196	B62qqxvqA4qfjXgPxLbmMh84pp3kB4CSuj9mSttTA8hGeLeREfzLGiC
197	B62qnqFpzBPpxNkuazmDWbvcQX6KvuCZvenM1ev9hhjKj9cFj4dXSMb
198	B62qpdxyyVPG1v5LvPdTayyoUtp4BMYbYYwRSCkyW9n45383yrP2hJz
199	B62qohCkbCHvE3DxG8YejQtLtE1o86Z53mHEe1nmzMdjNPzLcaVhPx2
200	B62qiUvkf8HWS1tv8dNkHKJdrj36f5uxMcH1gdF61T2GDrFbfbeeyxY
201	B62qngQ2joTkrS8RAFystfTa7HSc9agnhLsBvvkevhLmn5JXxtmKMfv
202	B62qrCfZaRAK5LjjigtSNYRoZgN4W4bwWbAffkvdhQYUDkB7UzBdk6w
203	B62qq8p3wd6YjuLqTrrUC8ag4wYzxoMUBKu4bdkUmZegwC3oqoXpGy3
204	B62qqmgpUFj5gYxoS6yZj6pr22tQHpbKaFSKXkT8yzdxatLunCvWtSA
205	B62qrjk6agoyBBy13yFobKQRE6FurWwXwk5P1VrxavxpZhkiHXqsyuR
206	B62qr3YEZne4Hyu9jCsxA6nYTziPNpxoyyxZHCGZ7cJrvckX9hoxjC6
207	B62qm7tX4g8RCRVRuCe4MZJFdtqAx5vKgLGR75djzQib7StKiTfbWVy
208	B62qjaAVCFYmsKt2CR2yUs9EqwxvT1b3KWeRWwrDQuHhems1oC2DNrg
209	B62qj49MogZdnBobJZ6ju8njQUhP2Rp59xjPxw3LV9cCj6XGAxkENhE
210	B62qpc1zRxqn3eTYAmcEosHyP5My3etfokSBX9Ge2cxtuSztAWWhadt
211	B62qm4Kvpidd4gX4p4r71DGsQUnEmhi12H4D5k3F2rdxvWmWEiJyfU2
212	B62qjMzwAAoUbqpnuntqxeb1vf2qgDtzQwj4a3zkNeA7PVoKHEGwLXg
213	B62qmyLw1LNGHkvqkH5nsQZU6uJu3begXAe7WzavUH4HPSsjJNKP9po
214	B62qqmQY1gPzEv6qr6AbLBp1yLW5tVcMB4dwVPMF218gv2xPk48j3sb
215	B62qmmhQ2eQDnyFTdsgzztgLndmsSyQBBWtjALnRdGbZ87RkNeEuri1
216	B62qqCAQRnjJCnS5uwC1A3j4XmHqZrisvNdG534R8eMvzsFRx9h8hip
217	B62qoUdnygTtJyyivQ3mTrgffMeDpUG1dsgqswbXvrypvCa9z8MDSFz
218	B62qnt6Lu7cqkAiHg9qF6qcj9uFcqDCz3J6pTcLTbwrNde97KbR6rf6
219	B62qoTmf1JEAZTWPqWvMq66xAonpPVAhMtSR8UbbX3t8FhRKrdyTFbr
220	B62qiqiPtbo7ppvjDJ536Nf968zQM3BrYxQXoWeistF8J12BovP5e1F
221	B62qpP5T35yJUz1U25Eqi5VtLVkjbDyMMXaTa87FE9bhoEbtz7bzAXz
222	B62qqdtmbGF5LwL47qj7hMWjt6XYcwJnft3YgD8ydLgf1M59PFCHv44
223	B62qm8TrWwzu2px1bZG38QkpXC5JgU7RnCyqbVyiy2Fmh63N5d9cbA6
224	B62qnZXs2RGudz1q9eAgxxtZQnNNHi6P5RAzoznCKNdqvSyyWghmYX6
225	B62qo7dRx2VHmDKXZ8XffNNeUK1j4znWxFUvg48hrxrNChqwUrDBgiA
226	B62qke1AAPWuurJQ5p1zQ34uRbtogxsfHEdzfqufAHrqKKHba7ZYC2G
227	B62qjy64ysP1cHmvHqyrZ899gdUy48PvBCnAYRykM5EMpjHccdVZ4Fy
228	B62qjDFzBEMSsJX6i6ta6baPjCAoJmHY4a4xXUmgCJQv4sAXhQAAbpt
229	B62qrV4S63yeVPjcEUmCkAx1bKA5aSfzCLTgh3b8D5uPr7UrJoVxA6S
230	B62qnqEX8jNJxJNyCvnbhUPu87xo3ki4FXdRyUUjQuLCnyvZE2qxyTy
231	B62qpivmqu3HDNenKMHPNhie31sFD68nZkMteLW58R21gcorUfenmBB
232	B62qjoiPU3JM2UtM1BCWjJZ5mdDBr8SadyEMRtaREsr7iCGPabKbFXf
233	B62qoRBTLL6SgP2JkuA8VKnNVybUygRm3VaD9uUsmswb2HULLdGFue6
234	B62qpLj8UrCZtRWWGstWPsE6vYZc9gA8FBavUT7RToRxpxHYuT3xiKf
235	B62qkZeQptw1qMSwe53pQN5HXj258zQN5bATF6bUz8gFLZ8Tj3vHdfa
236	B62qjzfgc1Z5tcbbuprWNtPmcA1aVEEf75EnDtss3VM3JrTyvWN5w8R
237	B62qkjyPMQDyVcBt4is9wamDeQBgvBTHbx6bYSFyGk6NndJJ3c1Te4Q
238	B62qjrZB4CzmYULfHB4NAXqjQoEnAESXmeyBAjxEfjCksXE1F7uLGtH
239	B62qkixmJk8DEY8wa7EQbVbZ4b36dCwGoW94rwPkzZnBkB8GjVaRMP5
240	B62qjkjpZtKLrVFyUE4i4hAhYEqaTQYYuJDoQrhisdFbpm61TEm1tE5
241	B62qrqndewerFzXSvc2JzDbFYNvoFTrbLsya4hTsy5bLTXmb9owUzcd
242	B62qrGPBCRyP4xiGWn8FNVveFbYuHWxKL677VZWteikeJJjWzHGzczB
243	B62qo41VUZdjEdSM1f4KUKqjr3hAuhrXJEadMSXknUVASBprQsgw3Ha
\.


--
-- Data for Name: snarked_ledger_hashes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.snarked_ledger_hashes (id, value) FROM stdin;
1	jwf5XDUhK1mhEdSgdymmrd1v7aWCBn5QuMmvyzVfxgx6kHBEstj
\.


--
-- Data for Name: timing_info; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.timing_info (id, account_identifier_id, initial_minimum_balance, cliff_time, cliff_amount, vesting_period, vesting_increment) FROM stdin;
1	1	0	0	0	0	0
2	2	0	0	0	0	0
3	3	0	0	0	0	0
4	4	0	0	0	0	0
5	5	0	0	0	0	0
6	6	0	0	0	0	0
7	7	0	0	0	0	0
8	8	0	0	0	0	0
9	9	0	0	0	0	0
10	10	0	0	0	0	0
11	11	0	0	0	0	0
12	12	0	0	0	0	0
13	13	0	0	0	0	0
14	14	0	0	0	0	0
15	15	0	0	0	0	0
16	16	0	0	0	0	0
17	17	0	0	0	0	0
18	18	0	0	0	0	0
19	19	0	0	0	0	0
20	20	0	0	0	0	0
21	21	0	0	0	0	0
22	22	0	0	0	0	0
23	23	0	0	0	0	0
24	24	0	0	0	0	0
25	25	0	0	0	0	0
26	26	0	0	0	0	0
27	27	0	0	0	0	0
28	28	0	0	0	0	0
29	29	0	0	0	0	0
30	30	0	0	0	0	0
31	31	0	0	0	0	0
32	32	0	0	0	0	0
33	33	0	0	0	0	0
34	34	0	0	0	0	0
35	35	0	0	0	0	0
36	36	0	0	0	0	0
37	37	0	0	0	0	0
38	38	0	0	0	0	0
39	39	0	0	0	0	0
40	40	0	0	0	0	0
41	41	0	0	0	0	0
42	42	0	0	0	0	0
43	43	0	0	0	0	0
44	44	0	0	0	0	0
45	45	0	0	0	0	0
46	46	0	0	0	0	0
47	47	0	0	0	0	0
48	48	0	0	0	0	0
49	49	0	0	0	0	0
50	50	0	0	0	0	0
51	51	0	0	0	0	0
52	52	0	0	0	0	0
53	53	0	0	0	0	0
54	54	0	0	0	0	0
55	55	0	0	0	0	0
56	56	0	0	0	0	0
57	57	0	0	0	0	0
58	58	0	0	0	0	0
59	59	0	0	0	0	0
60	60	0	0	0	0	0
61	61	0	0	0	0	0
62	62	0	0	0	0	0
63	63	0	0	0	0	0
64	64	0	0	0	0	0
65	65	0	0	0	0	0
66	66	0	0	0	0	0
67	67	0	0	0	0	0
68	68	0	0	0	0	0
69	69	0	0	0	0	0
70	70	0	0	0	0	0
71	71	0	0	0	0	0
72	72	0	0	0	0	0
73	73	0	0	0	0	0
74	74	0	0	0	0	0
75	75	0	0	0	0	0
76	76	0	0	0	0	0
77	77	0	0	0	0	0
78	78	0	0	0	0	0
79	79	0	0	0	0	0
80	80	0	0	0	0	0
81	81	0	0	0	0	0
82	82	0	0	0	0	0
83	83	0	0	0	0	0
84	84	0	0	0	0	0
85	85	0	0	0	0	0
86	86	0	0	0	0	0
87	87	0	0	0	0	0
88	88	0	0	0	0	0
89	89	0	0	0	0	0
90	90	0	0	0	0	0
91	91	0	0	0	0	0
92	92	0	0	0	0	0
93	93	0	0	0	0	0
94	94	0	0	0	0	0
95	95	0	0	0	0	0
96	96	0	0	0	0	0
97	97	0	0	0	0	0
98	98	0	0	0	0	0
99	99	0	0	0	0	0
100	100	0	0	0	0	0
101	101	0	0	0	0	0
102	102	0	0	0	0	0
103	103	0	0	0	0	0
104	104	0	0	0	0	0
105	105	0	0	0	0	0
106	106	0	0	0	0	0
107	107	0	0	0	0	0
108	108	0	0	0	0	0
109	109	0	0	0	0	0
110	110	0	0	0	0	0
111	111	0	0	0	0	0
112	112	0	0	0	0	0
113	113	0	0	0	0	0
114	114	0	0	0	0	0
115	115	0	0	0	0	0
116	116	0	0	0	0	0
117	117	0	0	0	0	0
118	118	0	0	0	0	0
119	119	0	0	0	0	0
120	120	0	0	0	0	0
121	121	0	0	0	0	0
122	122	0	0	0	0	0
123	123	0	0	0	0	0
124	124	0	0	0	0	0
125	125	0	0	0	0	0
126	126	0	0	0	0	0
127	127	0	0	0	0	0
128	128	0	0	0	0	0
129	129	0	0	0	0	0
130	130	0	0	0	0	0
131	131	0	0	0	0	0
132	132	0	0	0	0	0
133	133	0	0	0	0	0
134	134	0	0	0	0	0
135	135	0	0	0	0	0
136	136	0	0	0	0	0
137	137	0	0	0	0	0
138	138	0	0	0	0	0
139	139	0	0	0	0	0
140	140	0	0	0	0	0
141	141	0	0	0	0	0
142	142	0	0	0	0	0
143	143	0	0	0	0	0
144	144	0	0	0	0	0
145	145	0	0	0	0	0
146	146	0	0	0	0	0
147	147	0	0	0	0	0
148	148	0	0	0	0	0
149	149	0	0	0	0	0
150	150	0	0	0	0	0
151	151	0	0	0	0	0
152	152	0	0	0	0	0
153	153	0	0	0	0	0
154	154	0	0	0	0	0
155	155	0	0	0	0	0
156	156	0	0	0	0	0
157	157	0	0	0	0	0
158	158	0	0	0	0	0
159	159	0	0	0	0	0
160	160	0	0	0	0	0
161	161	0	0	0	0	0
162	162	0	0	0	0	0
163	163	0	0	0	0	0
164	164	0	0	0	0	0
165	165	0	0	0	0	0
166	166	0	0	0	0	0
167	167	0	0	0	0	0
168	168	0	0	0	0	0
169	169	0	0	0	0	0
170	170	0	0	0	0	0
171	171	0	0	0	0	0
172	172	0	0	0	0	0
173	173	0	0	0	0	0
174	174	0	0	0	0	0
175	175	0	0	0	0	0
176	176	0	0	0	0	0
177	177	0	0	0	0	0
178	178	0	0	0	0	0
179	179	0	0	0	0	0
180	180	0	0	0	0	0
181	181	0	0	0	0	0
182	182	0	0	0	0	0
183	183	0	0	0	0	0
184	184	0	0	0	0	0
185	185	0	0	0	0	0
186	186	0	0	0	0	0
187	187	0	0	0	0	0
188	188	0	0	0	0	0
189	189	0	0	0	0	0
190	190	0	0	0	0	0
191	191	0	0	0	0	0
192	192	0	0	0	0	0
193	193	0	0	0	0	0
194	194	0	0	0	0	0
195	195	0	0	0	0	0
196	196	0	0	0	0	0
197	197	0	0	0	0	0
198	198	0	0	0	0	0
199	199	0	0	0	0	0
200	200	0	0	0	0	0
201	201	0	0	0	0	0
202	202	0	0	0	0	0
203	203	0	0	0	0	0
204	204	0	0	0	0	0
205	205	0	0	0	0	0
206	206	0	0	0	0	0
207	207	0	0	0	0	0
208	208	0	0	0	0	0
209	209	0	0	0	0	0
210	210	0	0	0	0	0
211	211	0	0	0	0	0
212	212	0	0	0	0	0
213	213	0	0	0	0	0
214	214	0	0	0	0	0
215	215	0	0	0	0	0
216	216	0	0	0	0	0
217	217	0	0	0	0	0
218	218	0	0	0	0	0
219	219	0	0	0	0	0
220	220	0	0	0	0	0
221	221	0	0	0	0	0
222	222	0	0	0	0	0
223	223	0	0	0	0	0
224	224	0	0	0	0	0
225	225	0	0	0	0	0
226	226	0	0	0	0	0
227	227	0	0	0	0	0
228	228	0	0	0	0	0
229	229	0	0	0	0	0
230	230	0	0	0	0	0
231	231	0	0	0	0	0
232	232	0	0	0	0	0
233	233	0	0	0	0	0
234	234	0	0	0	0	0
235	235	0	0	0	0	0
236	236	0	0	0	0	0
237	237	0	0	0	0	0
238	238	0	0	0	0	0
239	239	0	0	0	0	0
240	240	0	0	0	0	0
241	241	0	0	0	0	0
242	242	0	0	0	0	0
\.


--
-- Data for Name: token_symbols; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.token_symbols (id, value) FROM stdin;
1	
\.


--
-- Data for Name: tokens; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tokens (id, value, owner_public_key_id, owner_token_id) FROM stdin;
1	wSHV2S4qX9jFsLjQo8r1BsMLH2ZRKsZx6EJd1sbozGPieEC4Jf	\N	\N
\.


--
-- Data for Name: user_commands; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.user_commands (id, command_type, fee_payer_id, source_id, receiver_id, nonce, amount, fee, valid_until, memo, hash) FROM stdin;
1	payment	136	136	136	0	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuE9H9djLWznhP6wBTtmEChc4fReffohgc4oU5eRMqveFRL4wcM
2	payment	136	136	136	1	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtsdicHoWE33TZJorg687Lrhp6uHicCfKP6LqHTUCYZwSJ5PYWj
3	payment	136	136	136	2	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuoyZEu3zwpyhj5Sj1NeNPmGJkfhV6eFrhJKgeu7p8LJR55enwD
4	payment	136	136	136	3	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuBJ5cPtMbzcvTAWVmq6C5oioQ2QtBciqcxmKNwebrLBPnz7QHz
5	payment	136	136	136	4	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuSDbZ2XqYGCB2mf4Pbes6uyBSaEn96TP7BbgpzdLQSPp6kxmDN
6	payment	136	136	136	5	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtwo1bLSd9u1Yr6XCKMwR6Z58hNh1SYGBFMbYJRSBPAVCYf5fDg
7	payment	136	136	136	6	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuL6ckrz3kJTXFYgywMYjZbsDzPu2w4X4VJ4DU1MCiwNJqKEw6t
8	payment	136	136	136	7	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuiJjihBJG91S9KipVmiGChh6e1Zb2o9pY5SDyqoQEMgX6qVXwE
9	payment	136	136	136	8	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtowNUEoJiUe9dDzPyhwig1gS1LFaArJVWLDFrD8287zV2TStb2
10	payment	136	136	136	9	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juact3L87zphwDbXPZz8b71Zn7jdnSeXaVB2jfN8tAa5LfoTU6k
11	payment	136	136	136	10	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuvfrRaBFZPQQkEVLLpBQLFkhLPzW4RrKHLjeB9qE5d8HGGxd6h
12	payment	136	136	136	11	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtXK9xV8vq8UwYknv78mppHa2jZ87bDLDjfxtXPEpMfgmmkbTke
13	payment	136	136	136	12	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JudGfhxdZmCSvqdgJyAypZeCDSMzHU4JrkTVvyjT5GShpxFhCqh
14	payment	136	136	136	13	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuiANhvWEGx42iaY6vYfuc8QpH9wQE72jf2ammzFczQp1Y2HZEy
15	payment	136	136	136	14	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtmywfiZ4Dpw9Jyww2JcpSaRUNguziTKuDXDwMepGdofSPLRMzA
16	payment	136	136	136	15	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuL7qkbcmaeaWC6Tob6naU1ZAsrVfzUVd47zScCGxq1p9D6L5en
17	payment	136	136	136	16	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv61nSqAdJqdhE6wGtxFj4oEYNgeq114nwBUT7WnRdqqeMHTBZK
18	payment	136	136	136	17	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtzQyEKKqxvFv2ASA9tMu4htNPUNoXruHMw5qhXWnSYF2fvpZo6
19	payment	136	136	136	18	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuZjXR9qocHqoKyXPSEi2t1eUgKXZbTo8hLc1AAE1dxXSsmcrzw
20	payment	136	136	136	19	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvDw6HPt5H4eUuWcpFh6yPxHd8m1bA98uQcyUCa3QZw95tg1jWj
21	payment	136	136	136	20	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuaeDGy3aeia1TvrxMTX5LhXLeZnoPs62VTQgopAwXmZX3Z7gJ7
22	payment	136	136	136	21	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuXFxzHGY74u6hKozBYCPpCFHkijZbdRkYdJ4gbcjaFuxVCgECy
23	payment	136	136	136	22	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JthfmQUrWMhqGcUdig8eqa17GGP2CNCZaSPg22UN7uTeFdumxa5
24	payment	136	136	136	23	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuUHyGYiLwfLH5imj6xuc8s6GCiNSfA5FXX6miguCkYn9NEMPSm
25	payment	136	136	136	24	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JusZNAbNhBEcSx9qghUb7DdjAYNtf2sGnSWmgtP2D5YTu6VcPRJ
26	payment	136	136	136	25	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvGEKHziXYuj2FHgGgXGmKxruVxMXKKKr73eBxQM2v2kZQY6vB3
27	payment	136	136	136	26	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuNAsdUSgxV39iMRcdT7v23gT1WTxeSPxewEn6FgqeshHJvVT2U
28	payment	136	136	136	27	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JufdK9QUVvWmRuQX941NkR1MCjNdoE6XprmaCvxSorGgvy8EitV
29	payment	136	136	136	28	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvDBk2abxZSVfefxKXcjCN7Pmrvv2fNiRqJ82hux7hKz3XVWXJY
30	payment	136	136	136	29	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JucEKQHMYcL6Eh7prVKCGhMLKWAV6qfRXJTPHmNSrTwJk8ij4Wn
31	payment	136	136	136	30	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvKrudpxE6jEPgporMNQ46fRD5iBHvCHhuFhCjxtfGZMCbdWXm9
32	payment	136	136	136	31	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juie4QtKwb6thqhTkVjFpH7VK3LULm5tJbodeX2gFc6MLaQUAwq
33	payment	136	136	136	32	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuzLvR8wgBeEFBSDYEDnoe4Veo5y7gRpfuSGxeeY86sxjGopvWc
34	payment	136	136	136	33	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtaxbSRgbYXSgxpsTX1TRKk8ByN6hX6xpzzgSzb5CtoeV1QBmAu
35	payment	136	136	136	34	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtsU67Qw7deMyCJoS7GD7BPqzyXS7PneP38wSiqJX23kaxRrHfj
36	payment	136	136	136	35	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtn9RYS4rmkNbqd4MwiLtRY2u1aaEs94TrjuzGNqibb67eXezyY
37	payment	136	136	136	36	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtya9821Akivrjar1yQh1qpxyybQ55opyygkVdC718BwUj2rWqv
38	payment	136	136	136	37	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JumhKxq1cxobeRL4jb9efC3aviEDg7wuL8m1CLegfA6BiABDPKo
39	payment	136	136	136	38	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvPx4maBhdb4FXQXAp885d4uwx8jn5BHuhBMG3umxLZjVN7ejDQ
40	payment	136	136	136	39	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juhrmsy94dQWhC7JyrKrGWLDzfN9XG5xdjtzdhnFT3KUDvWLsDL
41	payment	136	136	136	40	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuPSVPXfPairaVjg9TSUzqT9ZXWPmDeGjn8MrtYkHSMCT7aA9CS
42	payment	136	136	136	41	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtfRjwLAP93Pxd4KkL6SEqNZBcRXf3dyuJoF6mcBtrHbzDTMuNg
43	payment	136	136	136	42	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JunHeMwM12Gnc9LLqkgAbYQ1gLJoFz2ieSzTg6QnQewnw5vHisx
44	payment	136	136	136	43	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv6WHajVtpEuJRyKmLJ9QJCxUbxg1o7vQGiagzkQGZcjR2XLPTo
45	payment	136	136	136	44	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtsWBWC6s3MjKQ2fDZWWnPCyXs9LSHBPN5uXN4TVFmvcs6puLFZ
46	payment	136	136	136	45	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvRKud5QLNnqG5gYaLnNJnozB8CjtbJn1ZYZ4DLKMhcZsJVLxa1
47	payment	136	136	136	46	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtfxEvxCtpgAgkEj2btNxX9tuf49owoAZCSdp3moguhdjxRufkZ
48	payment	136	136	136	47	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuR27CnFcafV7EgyNP8PmWnr5FHtLCGLpPFXmG9e3LXqyFK9H8J
49	payment	136	136	136	48	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju9EtmCyxWjLxmC4C1iJSzybdJZFJEBu32jAFUf4AYDCVgEDiDJ
50	payment	136	136	136	49	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuHDGZiZNF3kVZgjYU6aADMrJTC4SpTsVNuN6sFGSTGk6bRjnG8
51	payment	136	136	136	50	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juh3aBSfZvyTGNnG1SsXP6PthsC1g8W1RaRCr544kYP5FLgp1JE
52	payment	136	136	136	51	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuFZTpPRFAK7eUK9D5ngRMQ7Zs4T2yCYkg6ReNkg3r2ZD5X4STX
53	payment	136	136	136	52	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtY42yCDQuA8R12PCRe1ZSRvfpfJggMmHR7Ec1Qu51Bs6AwusDH
54	payment	136	136	136	53	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtsDsUe1LYAsfMuUT2tRWF1zLn22oYegXZgCfVpuSwqGMARmFcB
55	payment	136	136	136	54	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtWYPfqLbdMzS68mpNC1KNB3coBEr5Dp2naheA2bREKqiWf6yxj
56	payment	136	136	136	55	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtqGxMxGj5vgKJri65aVrEj5mk9S1eyQ8ccgugts8kQaRPk1JcY
57	payment	136	136	136	56	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JukgivPi4uetCWf51xyBb29VhmEGKeqQ49d4WZ2AmWKLFsXGgwi
58	payment	136	136	136	57	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju8usuEUYaAP7jET7Dxmux7FAH37xjz17Th1B4Sntjwfyh55Wrw
59	payment	136	136	136	58	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju1qsdz3QGnxDUuVNoJ3MReLPU23YAkrAgxAA7hG88Q98y68gPT
60	payment	136	136	136	59	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jur7R7kmmWzFAGtSdYBDvASqphCxXcj9RR5W8je8vTi3xqJP9ww
61	payment	136	136	136	60	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juq1ntf7LG4bkcSs3YuZhSQyqxN1ZcsZmdDsxRm2YM2HReQaq8t
62	payment	136	136	136	61	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtdghqheDh2iDA8EHahWuHVGK8gFGfbasRkLMnWs1LqpuaYFkQb
63	payment	136	136	136	62	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv2qLymeUvgiJHCk8LFv1KLmEKqtt7Tkp8da8dJxwcA1wiF6Whw
64	payment	136	136	136	63	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuF74V37qgsK5vbfj2SoZT9gTEX6RyD4796mNwQEReJkxpeTWVD
65	payment	136	136	136	64	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JutwqDnZTUjir7Lo8UUrHAhg5V6NocHZNEeXbQ6FqPzc4sBS6cc
66	payment	136	136	136	65	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JttD8ZfpmxWBknnU1fMT2poF1QgGQfE7neKcpRdA2AvBogdAv9d
67	payment	136	136	136	66	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtXfvVzP1MUsv8CAy8fmdefH2psBweKHwbAgxH8gWbEHdaZnhdr
68	payment	136	136	136	67	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtjhAJJAvwy7ihcL3eX6mXciKkqv2mnLCLWtbKW2J5N4Nbx7TFF
69	payment	136	136	136	68	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvMxFx9Xd9edt55zRWoVSpK64FWorhR735DovQQ1jk6ELhCaSvu
70	payment	136	136	136	69	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvLt563vxKY6w6tZcU6nGwLHBXJiHFYaUwUFqkGXih2aAEjm8cz
71	payment	136	136	136	70	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JusB5LxfThNxRtyi6CkYUsf7DUA1vMiG4ezkaLtVGkPwvaQ4Zqi
72	payment	136	136	136	71	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvG3ZifiTy75d9eXDjPJBC9joWAkZn4gxbTW7BHBNjTq29U3nRd
73	payment	136	136	136	72	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuHY42UfebszYunk61tU3vqLFyBNNuSDTeEUH4mkxxnD6TwCL8F
74	payment	136	136	136	73	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JupCEZL96xCkkvF2N1wmp8Pp44o4NYFDDgUfH9WhNKYnLXzS6Xk
75	payment	136	136	136	74	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuVvUp4z823VGRBq2i7ncMkyBuTSMRJcM9YUB8vj7uQ9FaqHakc
76	payment	136	136	136	75	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuBHpRNWTq5m88tVjaDwrdLGCrzDVNi8wu9mRu9hxfu2FRiuogw
77	payment	136	136	136	76	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvPsYmXZx7rRP6a4adRLsCn5WRujU7cbJ31BTY9wuwXPcJdEtMZ
78	payment	136	136	136	77	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JueXg5wrioNEHf9WVrTNL7RP14bpGe5vJ3WSPTRqsw4JZq8uJxc
79	payment	136	136	136	78	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvBUkQouogEVPWgicu8YV2HZEdSwSL2tenKQC9h4Z4u3LKDt6y7
80	payment	136	136	136	79	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuYt3Y5Y9cK3T5hDBoGpURBL3kL2cwKwtwRKd8BiZjNg7Yrrad2
81	payment	136	136	136	80	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JusSrvCicQ7NwNhFZT2hkBNHz58hEurnq5FZhz2tGsNnmjKqqLS
82	payment	136	136	136	81	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvP9rjXJTwN3LjEGBh1zbGGZ3zM7Soi3qLRjf2T4vvXxf9gtaDv
83	payment	136	136	136	82	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuyVzgaVXNnw9swdxc4Ptqc8iPFkuZ8tzQ89EpcX2GYz6BAyagG
84	payment	136	136	136	83	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuH8zJrJsWEnPnuA13gEGDEbjnPuuuKSmj2GpkPTBFrdQUGuqBo
85	payment	136	136	136	84	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuEAGawmkQL1n5oF1R5dacFcYfkbRM4DjtLeVAjW1TGyhNp4yi1
94	payment	136	136	136	93	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juc5iWtdoJX4BzYzZYvnyL1Frj9GvyQBPDiRgYkycELUAoSwjks
95	payment	136	136	136	94	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtiPtNiH516FhWYbYnpqra61v1ixHMbyZCHcTjDPjAziTpwEu7s
96	payment	136	136	136	95	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvGcyCksX2V1PYb1hCzV2kxbVVSVVeCNsNcUMVdLGDijNgaaFNM
97	payment	136	136	136	96	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvEAZkT2FAtnr7HA3r2wD3R7P2MCxJVAX8BJzrc9Zu3V1u9AoW2
98	payment	136	136	136	97	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JukVoMDGw57k27FFUseC2gDHnfZjY9MasxkR7vddB2ocoKDqWTd
99	payment	136	136	136	98	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtWruwADddEyBKvh3LZNy1DG9t3ZkEoCoJ4BH9hvHMzDmY6KA7V
100	payment	136	136	136	99	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv7mLVkzys3ot347viiLTg1nomYmG1A6JTo63BVVwuSsWEdgpTt
101	payment	136	136	136	100	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtzELccMBPtANmJmaycmZxWGkqrqShWNzkbMQDQG4htAyu87Di9
102	payment	136	136	136	101	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JugaWQ5WphpNY4DesvPu9pE3oSyfSyVNArWE9BujhdSaRpeA6xT
103	payment	136	136	136	102	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju53p75h8zQpinZaibry6BTshdp6KfBb2PkGbY5nGKNUFp2KJu1
104	payment	136	136	136	103	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JujajRsDBoRY8ksb4DdjyE49gyVpMmVPg7gr29H78kbTTUMEJ4B
105	payment	136	136	136	104	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuW1e95oth8FRTRUMWPHd3a867Xf8Rt1b6vGUgb6zPrkaZe3Pup
106	payment	136	136	136	105	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuDGhoJd7RxM5TXVZBSf4bvyD5bNAukoi6usRfV42bMJkPvAsQj
107	payment	136	136	136	106	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juz9MGwBjSXRrSx4w8YuxQGpEhFzZTMVfQ2WaF5wuq9U4hJFqqa
108	payment	136	136	136	107	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtxRpo7ojN8GpyGwzQ7z1itGJxSDVtXfkPGmrgSfE5LMx8BAKru
109	payment	136	136	136	108	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuDiz3k88bcTjxf3ymLQfCV2tsEqxuwBYUFpzKkD4d5dZs4by18
110	payment	136	136	136	109	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JumsQFduT6x9tg8F4XpCnGNjSHjGTjoLXV1v5x7t5swjRvMpTyD
86	payment	136	136	136	85	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtv7M7wYXYFJLY1jB15eQWN81QCAcxeHnKEg5Q5BhjHRRUKNncP
87	payment	136	136	136	86	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juf2FgxRdBV9usvh6oNjTchjUVArx6frZWjZE3KKp9HPs2VzV9i
88	payment	136	136	136	87	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuMgeG2sdQdUjJ29eKsyEBydviSYWZCnTFWyLSVTxbcz3GjT6tP
89	payment	136	136	136	88	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JucFyxix6LFbzAEiZFNbDcqV4NyNZwDEGx7ZHrXvd3ttyyjJSDc
90	payment	136	136	136	89	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JumFmt8SuHs6Ay2dmN7hAjnKFktaQEFWUQVDfSTsvAp4M8hqS7y
91	payment	136	136	136	90	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvBPamW6aTQB35vww8c4VnFq7H956Y7KYLn1HvWWH6FGmsNzZwh
92	payment	136	136	136	91	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtdBMyMoHi7UMvgmFiz6tfZVkZTq9JaQhgsr2XJbv1eLXdGx8gE
93	payment	136	136	136	92	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuKZYqEiS11CCaCetLxdwvhUCVpKvXp9UzPyyUPsB6DrWsvwbxg
111	payment	136	136	136	110	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JucvADKnCbxypQwFBrP8eZ63cALLU64fqPkCBizLgAFsR9bVJHh
112	payment	136	136	136	111	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju7ZUw2bki7HF7TewZ5ryRupuy5Vh9Wtcx3sTSTzPzG7jHcKc4H
113	payment	136	136	136	112	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuxVf7qV2kecGEvJccrbZ8WxvLJ816nQuWc5eiTEfvSrMh4TWFK
114	payment	136	136	136	113	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuSnKnQMzGQGqZ5VxcNHdn6Z4bqnPUZfk73Sfid9ooEMAR8Lsbe
115	payment	136	136	136	114	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju3ijY8zrxE983aNbkS87fgxBgHTc5U13dAxaZ9Y1e4aBiuNyon
116	payment	136	136	136	115	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JttjLEUbTH21wq6sy8L6FcRZuCXae6PVj6UnJprGBxmE8UrcUuE
117	payment	136	136	136	116	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JthEzziqFTVJFLjiQFsHWU22A3nHtbQVEaKWUaEfoMgEWCgEqX7
118	payment	136	136	136	117	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtjAHq4CTjvixv16XGW6XopF7jNBgTDytQj4CSzuEV7LzmD8WQu
119	payment	136	136	136	118	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuhDXztMNGeqmpGXyP5drdRE97qsY4A7oA5oikh6xUqCQQhjwxU
120	payment	136	136	136	119	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuGMFwYbbFqWmJ3rhPVSPpzFpQDW3kkErZTPTEpCXBvo29zsGzD
121	payment	136	136	136	120	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvNmpYUKqR8q85HvJsP4UbTh8s7RyDeWWAukK8FtrYTTRm8rWCw
122	payment	136	136	136	121	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuJMtMm2wgLN8bG4n6bXxHvUp8Fgu6PSvDi6ogr2fPnYu7VSaPq
123	payment	136	136	136	122	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvF756QB3mrSKEpskWijEumRCiuCtLgh3oCpZD6pBerTkxBh9Bw
124	payment	136	136	136	123	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju57mMeNwBs2JwZtS2Tt6bFwjaftUrwNxxdnNtB1WQBqc4K1mKA
125	payment	136	136	136	124	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuawRGBBtXQdrqE3TxDapd39YU3swj8FJn8tp7c6CqDuTFuHBEL
126	payment	136	136	136	125	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvC52jT5fLgjsmFJARZgqU2smE3B31aBR6YebEskBrjjWVCvYpB
127	payment	136	136	136	126	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtn4HqYdGK9C81r3AzHtuRegXXDdQyC7zXhnAF9UxrkAcrspCFk
128	payment	136	136	136	127	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtd4fM5hbjaVho4fsf9Pmk8juACJKr56Vs52Vf4STGaG89te12Y
129	payment	136	136	136	128	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuPuzAPqDcGb54HhmGZxf8Ssgn4t2hrp1ky7pM5bMuo68DFqDVT
130	payment	136	136	136	129	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JudLN7ejrC7f6ghaDTvteC2sqM7WkUyL7UTsKGVxY6yDuCEKndG
131	payment	136	136	136	130	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jug3Fh3ywJtmkkqoSN8GAsgF6xEJW6ZzqXLaFDzQXd79fSLkhBt
132	payment	136	136	136	131	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuvzGwKLB42ktGFUdmeCjXnyNQjnFyWaGu3GEHmvtzG1xoHcQ2j
133	payment	136	136	136	132	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvGWatAWBg2cmJXsKXPWWfUyE9s7WtwzKuTwvReSGnrboYfYqh9
134	payment	136	136	136	133	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuEQhbYuw5hs4GJMasa8yxhrgJTxANgNtiuioiAY82GULgDR5dH
135	payment	136	136	136	134	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuDGaYGu5rbCYicDt13Hf8mrTGbPbGs5xALw5TG1UZwRqUsNLP9
136	payment	136	136	136	135	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtsdJYV5EPirs9Y7Sj7HhPHV5UV2NKP4AxraCrdekRwXvqbRWmA
137	payment	136	136	136	136	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JteNNavyuKZDDXjy1B39ayJJ811DwQCEcAbJRcQJmAs88f3TqHV
138	payment	136	136	136	137	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvC67eUbdTuuJPcbqaqk3Q3zwAYd9DVEF4evfbFnvU3PH85Yvgy
139	payment	136	136	136	138	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtWDvZNvbRk2uW9jpWXuVfRYQPvLwCXr82D3yi6eQsrkPGVeaxE
140	payment	136	136	136	139	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuSDCRs1Uni5kxqXWhezPWaRVRkNDNHqsEtyYM9Qy2jVfY2V9ir
141	payment	136	136	136	140	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuFTmXadYcLf6RQB9rY6YN9FPe5HKTgoV2rcogpiGqMnAysfNSN
142	payment	136	136	136	141	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvNXLt4j4rsjLEQR2YYCENB4XcnKGGmFCxQbWGgeKW89ibNNeD7
143	payment	136	136	136	142	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuMPVqaGX5G2EMbKL3sVs2V1TUkTrSa4wsgkbUuAUuCQv8tPqsh
144	payment	136	136	136	143	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtcLZNkKfYDWmZ2N1YEpGueXURkK2Gn5HS5SX13TFN1rToKZaKb
145	payment	136	136	136	144	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtZpi9iuuu2dc5mDwWvbBBdWcnCn7DW6JgoTeYL2hG1jptXL1RT
146	payment	136	136	136	145	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtaWjeieNd2bjpdD6qHHY8H5dDGsyXnG2NMC5H1pADpKLeZM2UW
147	payment	136	136	136	146	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JukJv6D2vJt1jS8m4s76o6cUZYmi2Tvecn3WWyDNJ5qiYVmYUf9
148	payment	136	136	136	147	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvQEbUDysXAvuBzLK5ijb5UZuHW3c2reuxPeNL42LfPbj9Gau2T
149	payment	136	136	136	148	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuwfyPQ7pziQAsGDKSxJUg4pWvvmkECHDtXtRzKgu9XD4Z5DAj2
150	payment	136	136	136	149	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju5CRJkc1wBD1J2BRS2uKZ575gCabuMma2WNjZJ4kkMdXANn1GX
151	payment	136	136	136	150	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuAAUQZgNzsktQnmBwgzSUb6V9nfHGK9TMmZkwg1HzHDXyFaG9n
160	payment	136	136	136	159	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvLrXsj4ZAmv5m1pLA4794t4Gjm6L2KFJAcTBseH176acNBAKth
161	payment	136	136	136	160	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvEcDx9vp2nKc4JVTE5miNtSrgQLE31XLyJnDiqtkvAfFuYcEPR
162	payment	136	136	136	161	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtg1E4GdEKeHG9Y2NjCWtqieuSAcBR8pVCkhTG7EZE8qpSW9XZf
163	payment	136	136	136	162	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuhorwTMApnao8CpcrP71c4zqDUB7K1a3WqHMCHJQFCgJUZuTd8
164	payment	136	136	136	163	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvKV9q9xuZd7hZAyincWYXV774LsiY23zWmeL4no3NQYSLFFFd7
165	payment	136	136	136	164	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtma3dV7MyARo7SJuVShG8oBh3MwdEHRUWZ3sQHE323GYcJ14LQ
166	payment	136	136	136	165	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuPPiauJWFMMjRxenoPS5hnxKYorH9DP8MRDS44bKsUY6NZMxTT
167	payment	136	136	136	166	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuTvbWg3qpfbSfdYtdB8PunnXLvbCExkUo9zfrBrmcvvoA6mVXJ
168	payment	136	136	136	167	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jug4rbC2UtQW81bZeztw248S31JmUrLZpRvKuX48vMXo8A4Qetn
169	payment	136	136	136	168	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuNyicxTbf52fgqxZKHzNPqFB9ZFAGRji2PqQdE19bbWJNjKt7B
170	payment	136	136	136	169	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju5GK8goLJ1ujLreC5g8718uHfHexvzDcSTQgbEWWv3YYHdqQ6D
171	payment	136	136	136	170	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuAKYfZghzfWrFRdV9WyWS1kB1aaDHs3xy5NXB3GMqoaV9TG1R6
172	payment	136	136	136	171	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuAU8AgUXiCrbNFqJk3is8jVHHGeYYRHXNauVJ8eGytF8NwApgb
173	payment	136	136	136	172	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuCmc1Vgq1hXKSGrDQKPa3SeY6jHpDmeisKokgrp5hYeETLq3gj
174	payment	136	136	136	173	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuTu87d9UThHcVkg1GcMFnjhkws1nXmJk94DVRTVuyFVUAR3x4o
175	payment	136	136	136	174	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuvybSyZQPyWodZ65PvJ3yUeBBK8RRLsgprKuqv5jK8znd8kqgr
152	payment	136	136	136	151	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JugBmnEqDzGmjgbs57DNbyNLNQWLFcCWkjoURm4qwPtQdRR6Rjp
153	payment	136	136	136	152	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtzcHkRuzDBZumq9oofFuA8V7uRmzA8eSqNZLPgkPifrAxCNrZU
154	payment	136	136	136	153	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvBisgjHjy56Dh2ru5yNkPGDDkJK6Q4WxTNv4FCsd1mWS9V7PmU
155	payment	136	136	136	154	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv2mUp94PcqVJUf7XRhA1Gzrxy946EiWcgBDhnDtzWk1dseHaau
156	payment	136	136	136	155	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtrsmH7U8RaCzFuQ138aoycy1dW9Uu7Fg35Nfj3cknZNoHuoV5w
157	payment	136	136	136	156	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juujg55sNMNjjBhcT5SG89fmgfWe5Ak4Z4jPVwXS1iu81BobEsk
158	payment	136	136	136	157	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JttzpN6jvhBm5vdQZvpeH9LyhbdeypTKmDDGAnS8MXwigFBR6S4
159	payment	136	136	136	158	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvNsXyYsuRhPjcJxG48mU7WdLMigoikgw2QyHC7cJdGurJSsddW
176	payment	136	136	136	175	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtdtMaVDK3kS2NsLuR52JVoxmiAbP96pz7BRtPUu1QmGCBPauBS
177	payment	136	136	136	176	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JurN2ErqJWxZNumNnx7eLjNtweCttD5wPkx3HMYXC9nS7e87tgx
178	payment	136	136	136	177	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuVye3eZxpzVGWmUeGgkjbAB45811KW3BQQc3Vj8Qi4VNpjrtGJ
179	payment	136	136	136	178	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JufvVjSkgTWhtcb7jCCMpAAV5J38FkfQWyw94RduZkZLVgSE3oQ
180	payment	136	136	136	179	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtqr2YRJZG8GPiyZD9aGCWnzz1X3FFMCtKD4ZCb3zb7HXrbGC7v
\.


--
-- Data for Name: voting_for; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.voting_for (id, value) FROM stdin;
1	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x
\.


--
-- Data for Name: zkapp_account_precondition; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.zkapp_account_precondition (id, balance_id, nonce_id, receipt_chain_hash, delegate_id, state_id, action_state_id, proved_state, is_new) FROM stdin;
1	\N	1	\N	\N	1	\N	\N	\N
2	\N	\N	\N	\N	1	\N	\N	\N
3	\N	2	\N	\N	1	\N	\N	\N
4	\N	3	\N	\N	1	\N	\N	\N
5	\N	4	\N	\N	1	\N	\N	\N
6	\N	5	\N	\N	1	\N	\N	\N
7	\N	6	\N	\N	1	\N	\N	\N
8	\N	7	\N	\N	1	\N	\N	\N
9	\N	8	\N	\N	1	\N	\N	\N
10	\N	9	\N	\N	1	\N	\N	\N
11	\N	10	\N	\N	1	\N	\N	\N
12	\N	11	\N	\N	1	\N	\N	\N
13	\N	12	\N	\N	1	\N	\N	\N
14	\N	13	\N	\N	1	\N	\N	\N
15	\N	14	\N	\N	1	\N	\N	\N
16	\N	15	\N	\N	1	\N	\N	\N
17	\N	16	\N	\N	1	\N	\N	\N
18	\N	17	\N	\N	1	\N	\N	\N
19	\N	18	\N	\N	1	\N	\N	\N
20	\N	19	\N	\N	1	\N	\N	\N
21	\N	20	\N	\N	1	\N	\N	\N
22	\N	21	\N	\N	1	\N	\N	\N
23	\N	22	\N	\N	1	\N	\N	\N
24	\N	23	\N	\N	1	\N	\N	\N
25	\N	24	\N	\N	1	\N	\N	\N
26	\N	25	\N	\N	1	\N	\N	\N
27	\N	26	\N	\N	1	\N	\N	\N
28	\N	27	\N	\N	1	\N	\N	\N
29	\N	28	\N	\N	1	\N	\N	\N
30	\N	29	\N	\N	1	\N	\N	\N
31	\N	30	\N	\N	1	\N	\N	\N
32	\N	31	\N	\N	1	\N	\N	\N
33	\N	32	\N	\N	1	\N	\N	\N
34	\N	33	\N	\N	1	\N	\N	\N
35	\N	34	\N	\N	1	\N	\N	\N
36	\N	35	\N	\N	1	\N	\N	\N
37	\N	36	\N	\N	1	\N	\N	\N
38	\N	37	\N	\N	1	\N	\N	\N
39	\N	38	\N	\N	1	\N	\N	\N
40	\N	39	\N	\N	1	\N	\N	\N
41	\N	40	\N	\N	1	\N	\N	\N
42	\N	41	\N	\N	1	\N	\N	\N
43	\N	42	\N	\N	1	\N	\N	\N
44	\N	43	\N	\N	1	\N	\N	\N
45	\N	44	\N	\N	1	\N	\N	\N
46	\N	45	\N	\N	1	\N	\N	\N
47	\N	46	\N	\N	1	\N	\N	\N
48	\N	47	\N	\N	1	\N	\N	\N
49	\N	48	\N	\N	1	\N	\N	\N
50	\N	49	\N	\N	1	\N	\N	\N
51	\N	50	\N	\N	1	\N	\N	\N
52	\N	51	\N	\N	1	\N	\N	\N
53	\N	52	\N	\N	1	\N	\N	\N
54	\N	53	\N	\N	1	\N	\N	\N
55	\N	54	\N	\N	1	\N	\N	\N
56	\N	55	\N	\N	1	\N	\N	\N
57	\N	56	\N	\N	1	\N	\N	\N
58	\N	57	\N	\N	1	\N	\N	\N
59	\N	58	\N	\N	1	\N	\N	\N
60	\N	59	\N	\N	1	\N	\N	\N
61	\N	60	\N	\N	1	\N	\N	\N
62	\N	61	\N	\N	1	\N	\N	\N
63	\N	62	\N	\N	1	\N	\N	\N
64	\N	63	\N	\N	1	\N	\N	\N
65	\N	64	\N	\N	1	\N	\N	\N
66	\N	65	\N	\N	1	\N	\N	\N
67	\N	66	\N	\N	1	\N	\N	\N
68	\N	67	\N	\N	1	\N	\N	\N
69	\N	68	\N	\N	1	\N	\N	\N
70	\N	69	\N	\N	1	\N	\N	\N
71	\N	70	\N	\N	1	\N	\N	\N
72	\N	71	\N	\N	1	\N	\N	\N
73	\N	72	\N	\N	1	\N	\N	\N
74	\N	73	\N	\N	1	\N	\N	\N
75	\N	74	\N	\N	1	\N	\N	\N
76	\N	75	\N	\N	1	\N	\N	\N
77	\N	76	\N	\N	1	\N	\N	\N
78	\N	77	\N	\N	1	\N	\N	\N
79	\N	78	\N	\N	1	\N	\N	\N
80	\N	79	\N	\N	1	\N	\N	\N
81	\N	80	\N	\N	1	\N	\N	\N
82	\N	81	\N	\N	1	\N	\N	\N
83	\N	82	\N	\N	1	\N	\N	\N
84	\N	83	\N	\N	1	\N	\N	\N
85	\N	84	\N	\N	1	\N	\N	\N
86	\N	85	\N	\N	1	\N	\N	\N
87	\N	86	\N	\N	1	\N	\N	\N
88	\N	87	\N	\N	1	\N	\N	\N
89	\N	88	\N	\N	1	\N	\N	\N
90	\N	89	\N	\N	1	\N	\N	\N
91	\N	90	\N	\N	1	\N	\N	\N
92	\N	91	\N	\N	1	\N	\N	\N
93	\N	92	\N	\N	1	\N	\N	\N
94	\N	93	\N	\N	1	\N	\N	\N
95	\N	94	\N	\N	1	\N	\N	\N
96	\N	95	\N	\N	1	\N	\N	\N
97	\N	96	\N	\N	1	\N	\N	\N
98	\N	97	\N	\N	1	\N	\N	\N
99	\N	98	\N	\N	1	\N	\N	\N
100	\N	99	\N	\N	1	\N	\N	\N
101	\N	100	\N	\N	1	\N	\N	\N
102	\N	101	\N	\N	1	\N	\N	\N
103	\N	102	\N	\N	1	\N	\N	\N
104	\N	103	\N	\N	1	\N	\N	\N
105	\N	104	\N	\N	1	\N	\N	\N
106	\N	105	\N	\N	1	\N	\N	\N
107	\N	106	\N	\N	1	\N	\N	\N
108	\N	107	\N	\N	1	\N	\N	\N
109	\N	108	\N	\N	1	\N	\N	\N
110	\N	109	\N	\N	1	\N	\N	\N
111	\N	110	\N	\N	1	\N	\N	\N
112	\N	111	\N	\N	1	\N	\N	\N
113	\N	112	\N	\N	1	\N	\N	\N
114	\N	113	\N	\N	1	\N	\N	\N
115	\N	114	\N	\N	1	\N	\N	\N
116	\N	115	\N	\N	1	\N	\N	\N
117	\N	116	\N	\N	1	\N	\N	\N
118	\N	117	\N	\N	1	\N	\N	\N
119	\N	118	\N	\N	1	\N	\N	\N
120	\N	119	\N	\N	1	\N	\N	\N
121	\N	120	\N	\N	1	\N	\N	\N
122	\N	121	\N	\N	1	\N	\N	\N
123	\N	122	\N	\N	1	\N	\N	\N
124	\N	123	\N	\N	1	\N	\N	\N
125	\N	124	\N	\N	1	\N	\N	\N
126	\N	125	\N	\N	1	\N	\N	\N
127	\N	126	\N	\N	1	\N	\N	\N
128	\N	127	\N	\N	1	\N	\N	\N
129	\N	128	\N	\N	1	\N	\N	\N
130	\N	129	\N	\N	1	\N	\N	\N
131	\N	130	\N	\N	1	\N	\N	\N
132	\N	131	\N	\N	1	\N	\N	\N
133	\N	132	\N	\N	1	\N	\N	\N
134	\N	133	\N	\N	1	\N	\N	\N
135	\N	134	\N	\N	1	\N	\N	\N
136	\N	135	\N	\N	1	\N	\N	\N
137	\N	136	\N	\N	1	\N	\N	\N
138	\N	137	\N	\N	1	\N	\N	\N
139	\N	138	\N	\N	1	\N	\N	\N
140	\N	139	\N	\N	1	\N	\N	\N
141	\N	140	\N	\N	1	\N	\N	\N
142	\N	141	\N	\N	1	\N	\N	\N
143	\N	142	\N	\N	1	\N	\N	\N
144	\N	143	\N	\N	1	\N	\N	\N
145	\N	144	\N	\N	1	\N	\N	\N
146	\N	145	\N	\N	1	\N	\N	\N
147	\N	146	\N	\N	1	\N	\N	\N
148	\N	147	\N	\N	1	\N	\N	\N
149	\N	148	\N	\N	1	\N	\N	\N
150	\N	149	\N	\N	1	\N	\N	\N
151	\N	150	\N	\N	1	\N	\N	\N
152	\N	151	\N	\N	1	\N	\N	\N
153	\N	152	\N	\N	1	\N	\N	\N
154	\N	153	\N	\N	1	\N	\N	\N
155	\N	154	\N	\N	1	\N	\N	\N
156	\N	155	\N	\N	1	\N	\N	\N
157	\N	156	\N	\N	1	\N	\N	\N
158	\N	157	\N	\N	1	\N	\N	\N
159	\N	158	\N	\N	1	\N	\N	\N
160	\N	159	\N	\N	1	\N	\N	\N
186	\N	185	\N	\N	1	\N	\N	\N
187	\N	186	\N	\N	1	\N	\N	\N
188	\N	187	\N	\N	1	\N	\N	\N
161	\N	160	\N	\N	1	\N	\N	\N
162	\N	161	\N	\N	1	\N	\N	\N
163	\N	162	\N	\N	1	\N	\N	\N
164	\N	163	\N	\N	1	\N	\N	\N
165	\N	164	\N	\N	1	\N	\N	\N
166	\N	165	\N	\N	1	\N	\N	\N
167	\N	166	\N	\N	1	\N	\N	\N
168	\N	167	\N	\N	1	\N	\N	\N
169	\N	168	\N	\N	1	\N	\N	\N
170	\N	169	\N	\N	1	\N	\N	\N
171	\N	170	\N	\N	1	\N	\N	\N
172	\N	171	\N	\N	1	\N	\N	\N
173	\N	172	\N	\N	1	\N	\N	\N
174	\N	173	\N	\N	1	\N	\N	\N
175	\N	174	\N	\N	1	\N	\N	\N
176	\N	175	\N	\N	1	\N	\N	\N
177	\N	176	\N	\N	1	\N	\N	\N
178	\N	177	\N	\N	1	\N	\N	\N
179	\N	178	\N	\N	1	\N	\N	\N
180	\N	179	\N	\N	1	\N	\N	\N
181	\N	180	\N	\N	1	\N	\N	\N
182	\N	181	\N	\N	1	\N	\N	\N
183	\N	182	\N	\N	1	\N	\N	\N
184	\N	183	\N	\N	1	\N	\N	\N
185	\N	184	\N	\N	1	\N	\N	\N
189	\N	188	\N	\N	1	\N	\N	\N
\.


--
-- Data for Name: zkapp_account_update; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.zkapp_account_update (id, body_id) FROM stdin;
1	1
2	2
3	3
4	4
5	5
6	6
7	7
8	8
9	9
10	10
11	11
12	12
13	13
14	14
15	15
16	16
17	17
18	18
19	19
20	20
21	21
22	22
23	23
24	24
25	25
26	26
27	27
28	28
29	29
30	30
31	31
32	32
33	33
34	34
35	35
36	36
37	37
38	38
39	39
40	40
41	41
42	42
43	43
44	44
45	45
46	46
47	47
48	48
49	49
50	50
51	51
52	52
53	53
54	54
55	55
56	56
57	57
58	58
59	59
60	60
61	61
62	62
63	63
64	64
65	65
66	66
67	67
68	68
69	69
70	70
71	71
72	72
73	73
74	74
75	75
76	76
77	77
78	78
79	79
80	80
81	81
82	82
83	83
84	84
85	85
86	86
87	87
88	88
89	89
90	90
91	91
92	92
93	93
94	94
95	95
96	96
97	97
98	98
99	99
100	100
101	101
102	102
103	103
104	104
105	105
106	106
107	107
108	108
109	109
110	110
111	111
112	112
113	113
114	114
115	115
116	116
117	117
118	118
119	119
120	120
121	121
122	122
123	123
124	124
125	125
126	126
127	127
128	128
129	129
130	130
131	131
132	132
133	133
134	134
135	135
136	136
137	137
138	138
139	139
140	140
141	141
142	142
143	143
144	144
145	145
146	146
147	147
148	148
149	149
150	150
151	151
152	152
153	153
154	154
155	155
156	156
157	157
158	158
159	159
160	160
161	161
162	162
163	163
164	164
165	165
166	166
167	167
168	168
169	169
170	170
171	171
172	172
173	173
174	174
175	175
176	176
177	177
178	178
179	179
180	180
181	181
182	182
183	183
184	184
185	185
186	186
187	187
188	188
189	189
190	190
191	191
192	192
193	193
194	194
195	195
196	196
197	197
198	198
199	199
200	200
201	201
202	202
203	203
204	204
205	205
206	206
207	207
208	208
209	209
210	210
211	211
212	212
213	213
214	214
215	215
216	216
217	217
218	218
219	219
220	220
221	221
222	222
223	223
224	224
225	225
226	226
227	227
228	228
229	229
230	230
231	231
232	232
233	233
234	234
235	235
236	236
237	237
238	238
239	239
240	240
241	241
242	242
243	243
244	244
245	245
246	246
247	247
248	248
249	249
250	250
251	251
252	252
253	253
254	254
255	255
256	256
257	257
258	258
259	259
260	260
261	261
262	262
263	263
264	264
265	265
266	266
267	267
268	268
269	269
270	270
271	271
272	272
273	273
274	274
275	275
276	276
277	277
278	278
279	279
280	280
281	281
282	282
283	283
284	284
285	285
286	286
287	287
288	288
289	289
290	290
291	291
292	292
293	293
294	294
295	295
296	296
297	297
298	298
299	299
300	300
301	301
302	302
303	303
304	304
305	305
306	306
307	307
308	308
309	309
310	310
311	311
312	312
313	313
314	314
315	315
316	316
317	317
318	318
319	319
320	320
321	321
322	322
323	323
324	324
325	325
326	326
327	327
328	328
329	329
330	330
331	331
332	332
333	333
334	334
335	335
336	336
337	337
338	338
339	339
340	340
341	341
342	342
343	343
344	344
345	345
346	346
347	347
348	348
349	349
350	350
351	351
352	352
353	353
354	354
355	355
356	356
357	357
358	358
359	359
360	360
361	361
362	362
363	363
364	364
365	365
366	366
367	367
368	368
369	369
370	370
371	371
372	372
373	373
374	374
375	375
376	376
377	377
\.


--
-- Data for Name: zkapp_account_update_body; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.zkapp_account_update_body (id, account_identifier_id, update_id, balance_change, increment_nonce, events_id, actions_id, call_data_id, call_depth, zkapp_network_precondition_id, zkapp_account_precondition_id, zkapp_valid_while_precondition_id, use_full_commitment, implicit_account_creation_fee, may_use_token, authorization_kind, verification_key_hash_id) FROM stdin;
1	25	1	-1000000000000	t	1	1	1	0	1	1	\N	f	f	No	Signature	\N
2	243	2	999000000000	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
3	25	1	-1000000000	t	1	1	1	0	1	3	\N	f	f	No	Signature	\N
4	243	1	1000000000	f	1	1	1	0	1	2	\N	f	f	No	None_given	\N
5	243	3	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
6	25	1	-1000000000	t	1	1	1	0	1	4	\N	f	f	No	Signature	\N
7	243	4	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
8	25	1	-1000000000	t	1	1	1	0	1	5	\N	f	f	No	Signature	\N
9	243	5	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
10	25	1	-1000000000	t	1	1	1	0	1	6	\N	f	f	No	Signature	\N
11	243	6	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
12	25	1	-1000000000	t	1	1	1	0	1	7	\N	f	f	No	Signature	\N
13	243	7	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
14	25	1	-1000000000	t	1	1	1	0	1	8	\N	f	f	No	Signature	\N
15	243	8	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
16	25	1	-1000000000	t	1	1	1	0	1	9	\N	f	f	No	Signature	\N
17	243	9	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
18	25	1	-1000000000	t	1	1	1	0	1	10	\N	f	f	No	Signature	\N
19	243	10	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
20	25	1	-1000000000	t	1	1	1	0	1	11	\N	f	f	No	Signature	\N
21	243	11	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
22	25	1	-1000000000	t	1	1	1	0	1	12	\N	f	f	No	Signature	\N
23	243	12	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
24	25	1	-1000000000	t	1	1	1	0	1	13	\N	f	f	No	Signature	\N
25	243	13	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
26	25	1	-1000000000	t	1	1	1	0	1	14	\N	f	f	No	Signature	\N
27	243	14	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
28	25	1	-1000000000	t	1	1	1	0	1	15	\N	f	f	No	Signature	\N
29	243	15	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
30	25	1	-1000000000	t	1	1	1	0	1	16	\N	f	f	No	Signature	\N
31	243	16	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
32	25	1	-1000000000	t	1	1	1	0	1	17	\N	f	f	No	Signature	\N
33	243	17	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
34	25	1	-1000000000	t	1	1	1	0	1	18	\N	f	f	No	Signature	\N
35	243	18	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
36	25	1	-1000000000	t	1	1	1	0	1	19	\N	f	f	No	Signature	\N
37	243	19	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
38	25	1	-1000000000	t	1	1	1	0	1	20	\N	f	f	No	Signature	\N
39	243	20	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
40	25	1	-1000000000	t	1	1	1	0	1	21	\N	f	f	No	Signature	\N
41	243	21	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
42	25	1	-1000000000	t	1	1	1	0	1	22	\N	f	f	No	Signature	\N
43	243	22	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
44	25	1	-1000000000	t	1	1	1	0	1	23	\N	f	f	No	Signature	\N
45	243	23	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
46	25	1	-1000000000	t	1	1	1	0	1	24	\N	f	f	No	Signature	\N
47	243	24	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
48	25	1	-1000000000	t	1	1	1	0	1	25	\N	f	f	No	Signature	\N
49	243	25	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
50	25	1	-1000000000	t	1	1	1	0	1	26	\N	f	f	No	Signature	\N
51	243	26	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
52	25	1	-1000000000	t	1	1	1	0	1	27	\N	f	f	No	Signature	\N
53	243	27	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
54	25	1	-1000000000	t	1	1	1	0	1	28	\N	f	f	No	Signature	\N
55	243	28	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
56	25	1	-1000000000	t	1	1	1	0	1	29	\N	f	f	No	Signature	\N
57	243	29	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
58	25	1	-1000000000	t	1	1	1	0	1	30	\N	f	f	No	Signature	\N
59	243	30	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
60	25	1	-1000000000	t	1	1	1	0	1	31	\N	f	f	No	Signature	\N
61	243	31	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
62	25	1	-1000000000	t	1	1	1	0	1	32	\N	f	f	No	Signature	\N
63	243	32	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
64	25	1	-1000000000	t	1	1	1	0	1	33	\N	f	f	No	Signature	\N
65	243	33	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
66	25	1	-1000000000	t	1	1	1	0	1	34	\N	f	f	No	Signature	\N
67	243	34	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
68	25	1	-1000000000	t	1	1	1	0	1	35	\N	f	f	No	Signature	\N
69	243	35	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
70	25	1	-1000000000	t	1	1	1	0	1	36	\N	f	f	No	Signature	\N
71	243	36	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
72	25	1	-1000000000	t	1	1	1	0	1	37	\N	f	f	No	Signature	\N
73	243	37	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
74	25	1	-1000000000	t	1	1	1	0	1	38	\N	f	f	No	Signature	\N
75	243	38	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
76	25	1	-1000000000	t	1	1	1	0	1	39	\N	f	f	No	Signature	\N
77	243	39	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
78	25	1	-1000000000	t	1	1	1	0	1	40	\N	f	f	No	Signature	\N
79	243	40	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
80	25	1	-1000000000	t	1	1	1	0	1	41	\N	f	f	No	Signature	\N
81	243	41	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
82	25	1	-1000000000	t	1	1	1	0	1	42	\N	f	f	No	Signature	\N
83	243	42	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
84	25	1	-1000000000	t	1	1	1	0	1	43	\N	f	f	No	Signature	\N
85	243	43	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
86	25	1	-1000000000	t	1	1	1	0	1	44	\N	f	f	No	Signature	\N
87	243	44	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
88	25	1	-1000000000	t	1	1	1	0	1	45	\N	f	f	No	Signature	\N
89	243	45	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
90	25	1	-1000000000	t	1	1	1	0	1	46	\N	f	f	No	Signature	\N
91	243	46	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
92	25	1	-1000000000	t	1	1	1	0	1	47	\N	f	f	No	Signature	\N
93	243	47	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
94	25	1	-1000000000	t	1	1	1	0	1	48	\N	f	f	No	Signature	\N
95	243	48	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
96	25	1	-1000000000	t	1	1	1	0	1	49	\N	f	f	No	Signature	\N
97	243	49	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
98	25	1	-1000000000	t	1	1	1	0	1	50	\N	f	f	No	Signature	\N
99	243	50	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
100	25	1	-1000000000	t	1	1	1	0	1	51	\N	f	f	No	Signature	\N
101	243	51	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
102	25	1	-1000000000	t	1	1	1	0	1	52	\N	f	f	No	Signature	\N
103	243	52	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
104	25	1	-1000000000	t	1	1	1	0	1	53	\N	f	f	No	Signature	\N
105	243	53	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
106	25	1	-1000000000	t	1	1	1	0	1	54	\N	f	f	No	Signature	\N
107	243	54	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
108	25	1	-1000000000	t	1	1	1	0	1	55	\N	f	f	No	Signature	\N
109	243	55	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
110	25	1	-1000000000	t	1	1	1	0	1	56	\N	f	f	No	Signature	\N
111	243	56	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
112	25	1	-1000000000	t	1	1	1	0	1	57	\N	f	f	No	Signature	\N
113	243	57	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
114	25	1	-1000000000	t	1	1	1	0	1	58	\N	f	f	No	Signature	\N
115	243	58	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
116	25	1	-1000000000	t	1	1	1	0	1	59	\N	f	f	No	Signature	\N
117	243	59	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
118	25	1	-1000000000	t	1	1	1	0	1	60	\N	f	f	No	Signature	\N
119	243	60	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
120	25	1	-1000000000	t	1	1	1	0	1	61	\N	f	f	No	Signature	\N
121	243	61	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
122	25	1	-1000000000	t	1	1	1	0	1	62	\N	f	f	No	Signature	\N
123	243	62	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
124	25	1	-1000000000	t	1	1	1	0	1	63	\N	f	f	No	Signature	\N
125	243	63	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
126	25	1	-1000000000	t	1	1	1	0	1	64	\N	f	f	No	Signature	\N
127	243	64	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
128	25	1	-1000000000	t	1	1	1	0	1	65	\N	f	f	No	Signature	\N
129	243	65	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
130	25	1	-1000000000	t	1	1	1	0	1	66	\N	f	f	No	Signature	\N
131	243	66	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
132	25	1	-1000000000	t	1	1	1	0	1	67	\N	f	f	No	Signature	\N
133	243	67	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
134	25	1	-1000000000	t	1	1	1	0	1	68	\N	f	f	No	Signature	\N
135	243	68	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
136	25	1	-1000000000	t	1	1	1	0	1	69	\N	f	f	No	Signature	\N
137	243	69	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
138	25	1	-1000000000	t	1	1	1	0	1	70	\N	f	f	No	Signature	\N
139	243	70	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
140	25	1	-1000000000	t	1	1	1	0	1	71	\N	f	f	No	Signature	\N
141	243	71	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
142	25	1	-1000000000	t	1	1	1	0	1	72	\N	f	f	No	Signature	\N
143	243	72	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
144	25	1	-1000000000	t	1	1	1	0	1	73	\N	f	f	No	Signature	\N
145	243	73	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
146	25	1	-1000000000	t	1	1	1	0	1	74	\N	f	f	No	Signature	\N
147	243	74	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
148	25	1	-1000000000	t	1	1	1	0	1	75	\N	f	f	No	Signature	\N
149	243	75	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
150	25	1	-1000000000	t	1	1	1	0	1	76	\N	f	f	No	Signature	\N
151	243	76	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
152	25	1	-1000000000	t	1	1	1	0	1	77	\N	f	f	No	Signature	\N
153	243	77	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
154	25	1	-1000000000	t	1	1	1	0	1	78	\N	f	f	No	Signature	\N
155	243	78	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
156	25	1	-1000000000	t	1	1	1	0	1	79	\N	f	f	No	Signature	\N
157	243	79	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
158	25	1	-1000000000	t	1	1	1	0	1	80	\N	f	f	No	Signature	\N
159	243	80	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
160	25	1	-1000000000	t	1	1	1	0	1	81	\N	f	f	No	Signature	\N
161	243	81	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
162	25	1	-1000000000	t	1	1	1	0	1	82	\N	f	f	No	Signature	\N
163	243	82	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
164	25	1	-1000000000	t	1	1	1	0	1	83	\N	f	f	No	Signature	\N
165	243	83	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
166	25	1	-1000000000	t	1	1	1	0	1	84	\N	f	f	No	Signature	\N
167	243	84	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
168	25	1	-1000000000	t	1	1	1	0	1	85	\N	f	f	No	Signature	\N
169	243	85	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
170	25	1	-1000000000	t	1	1	1	0	1	86	\N	f	f	No	Signature	\N
171	243	86	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
172	25	1	-1000000000	t	1	1	1	0	1	87	\N	f	f	No	Signature	\N
173	243	87	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
174	25	1	-1000000000	t	1	1	1	0	1	88	\N	f	f	No	Signature	\N
175	243	88	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
176	25	1	-1000000000	t	1	1	1	0	1	89	\N	f	f	No	Signature	\N
177	243	89	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
178	25	1	-1000000000	t	1	1	1	0	1	90	\N	f	f	No	Signature	\N
179	243	90	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
180	25	1	-1000000000	t	1	1	1	0	1	91	\N	f	f	No	Signature	\N
181	243	91	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
182	25	1	-1000000000	t	1	1	1	0	1	92	\N	f	f	No	Signature	\N
183	243	92	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
184	25	1	-1000000000	t	1	1	1	0	1	93	\N	f	f	No	Signature	\N
185	243	93	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
186	25	1	-1000000000	t	1	1	1	0	1	94	\N	f	f	No	Signature	\N
187	243	94	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
188	25	1	-1000000000	t	1	1	1	0	1	95	\N	f	f	No	Signature	\N
189	243	95	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
190	25	1	-1000000000	t	1	1	1	0	1	96	\N	f	f	No	Signature	\N
191	243	96	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
192	25	1	-1000000000	t	1	1	1	0	1	97	\N	f	f	No	Signature	\N
193	243	97	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
194	25	1	-1000000000	t	1	1	1	0	1	98	\N	f	f	No	Signature	\N
195	243	98	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
196	25	1	-1000000000	t	1	1	1	0	1	99	\N	f	f	No	Signature	\N
197	243	99	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
198	25	1	-1000000000	t	1	1	1	0	1	100	\N	f	f	No	Signature	\N
199	243	100	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
200	25	1	-1000000000	t	1	1	1	0	1	101	\N	f	f	No	Signature	\N
201	243	101	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
202	25	1	-1000000000	t	1	1	1	0	1	102	\N	f	f	No	Signature	\N
203	243	102	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
204	25	1	-1000000000	t	1	1	1	0	1	103	\N	f	f	No	Signature	\N
205	243	103	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
206	25	1	-1000000000	t	1	1	1	0	1	104	\N	f	f	No	Signature	\N
207	243	104	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
208	25	1	-1000000000	t	1	1	1	0	1	105	\N	f	f	No	Signature	\N
209	243	105	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
210	25	1	-1000000000	t	1	1	1	0	1	106	\N	f	f	No	Signature	\N
211	243	106	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
212	25	1	-1000000000	t	1	1	1	0	1	107	\N	f	f	No	Signature	\N
213	243	107	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
214	25	1	-1000000000	t	1	1	1	0	1	108	\N	f	f	No	Signature	\N
215	243	108	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
216	25	1	-1000000000	t	1	1	1	0	1	109	\N	f	f	No	Signature	\N
217	243	109	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
218	25	1	-1000000000	t	1	1	1	0	1	110	\N	f	f	No	Signature	\N
219	243	110	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
220	25	1	-1000000000	t	1	1	1	0	1	111	\N	f	f	No	Signature	\N
221	243	111	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
222	25	1	-1000000000	t	1	1	1	0	1	112	\N	f	f	No	Signature	\N
223	243	112	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
224	25	1	-1000000000	t	1	1	1	0	1	113	\N	f	f	No	Signature	\N
225	243	113	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
226	25	1	-1000000000	t	1	1	1	0	1	114	\N	f	f	No	Signature	\N
227	243	114	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
228	25	1	-1000000000	t	1	1	1	0	1	115	\N	f	f	No	Signature	\N
229	243	115	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
230	25	1	-1000000000	t	1	1	1	0	1	116	\N	f	f	No	Signature	\N
231	243	116	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
232	25	1	-1000000000	t	1	1	1	0	1	117	\N	f	f	No	Signature	\N
233	243	117	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
234	25	1	-1000000000	t	1	1	1	0	1	118	\N	f	f	No	Signature	\N
235	243	118	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
236	25	1	-1000000000	t	1	1	1	0	1	119	\N	f	f	No	Signature	\N
237	243	119	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
238	25	1	-1000000000	t	1	1	1	0	1	120	\N	f	f	No	Signature	\N
239	243	120	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
240	25	1	-1000000000	t	1	1	1	0	1	121	\N	f	f	No	Signature	\N
241	243	121	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
242	25	1	-1000000000	t	1	1	1	0	1	122	\N	f	f	No	Signature	\N
243	243	122	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
244	25	1	-1000000000	t	1	1	1	0	1	123	\N	f	f	No	Signature	\N
245	243	123	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
246	25	1	-1000000000	t	1	1	1	0	1	124	\N	f	f	No	Signature	\N
247	243	124	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
248	25	1	-1000000000	t	1	1	1	0	1	125	\N	f	f	No	Signature	\N
249	243	125	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
250	25	1	-1000000000	t	1	1	1	0	1	126	\N	f	f	No	Signature	\N
251	243	126	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
252	25	1	-1000000000	t	1	1	1	0	1	127	\N	f	f	No	Signature	\N
253	243	127	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
254	25	1	-1000000000	t	1	1	1	0	1	128	\N	f	f	No	Signature	\N
255	243	128	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
256	25	1	-1000000000	t	1	1	1	0	1	129	\N	f	f	No	Signature	\N
257	243	129	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
258	25	1	-1000000000	t	1	1	1	0	1	130	\N	f	f	No	Signature	\N
259	243	130	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
260	25	1	-1000000000	t	1	1	1	0	1	131	\N	f	f	No	Signature	\N
261	243	131	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
262	25	1	-1000000000	t	1	1	1	0	1	132	\N	f	f	No	Signature	\N
263	243	132	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
264	25	1	-1000000000	t	1	1	1	0	1	133	\N	f	f	No	Signature	\N
265	243	133	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
266	25	1	-1000000000	t	1	1	1	0	1	134	\N	f	f	No	Signature	\N
267	243	134	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
268	25	1	-1000000000	t	1	1	1	0	1	135	\N	f	f	No	Signature	\N
269	243	135	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
270	25	1	-1000000000	t	1	1	1	0	1	136	\N	f	f	No	Signature	\N
271	243	136	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
272	25	1	-1000000000	t	1	1	1	0	1	137	\N	f	f	No	Signature	\N
273	243	137	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
274	25	1	-1000000000	t	1	1	1	0	1	138	\N	f	f	No	Signature	\N
275	243	138	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
276	25	1	-1000000000	t	1	1	1	0	1	139	\N	f	f	No	Signature	\N
277	243	139	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
278	25	1	-1000000000	t	1	1	1	0	1	140	\N	f	f	No	Signature	\N
279	243	140	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
280	25	1	-1000000000	t	1	1	1	0	1	141	\N	f	f	No	Signature	\N
281	243	141	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
282	25	1	-1000000000	t	1	1	1	0	1	142	\N	f	f	No	Signature	\N
283	243	142	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
284	25	1	-1000000000	t	1	1	1	0	1	143	\N	f	f	No	Signature	\N
285	243	143	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
286	25	1	-1000000000	t	1	1	1	0	1	144	\N	f	f	No	Signature	\N
287	243	144	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
288	25	1	-1000000000	t	1	1	1	0	1	145	\N	f	f	No	Signature	\N
289	243	145	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
290	25	1	-1000000000	t	1	1	1	0	1	146	\N	f	f	No	Signature	\N
291	243	146	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
292	25	1	-1000000000	t	1	1	1	0	1	147	\N	f	f	No	Signature	\N
293	243	147	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
294	25	1	-1000000000	t	1	1	1	0	1	148	\N	f	f	No	Signature	\N
295	243	148	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
296	25	1	-1000000000	t	1	1	1	0	1	149	\N	f	f	No	Signature	\N
297	243	149	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
298	25	1	-1000000000	t	1	1	1	0	1	150	\N	f	f	No	Signature	\N
299	243	150	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
300	25	1	-1000000000	t	1	1	1	0	1	151	\N	f	f	No	Signature	\N
301	243	151	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
302	25	1	-1000000000	t	1	1	1	0	1	152	\N	f	f	No	Signature	\N
303	243	152	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
304	25	1	-1000000000	t	1	1	1	0	1	153	\N	f	f	No	Signature	\N
305	243	153	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
306	25	1	-1000000000	t	1	1	1	0	1	154	\N	f	f	No	Signature	\N
307	243	154	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
308	25	1	-1000000000	t	1	1	1	0	1	155	\N	f	f	No	Signature	\N
309	243	155	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
310	25	1	-1000000000	t	1	1	1	0	1	156	\N	f	f	No	Signature	\N
311	243	156	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
312	25	1	-1000000000	t	1	1	1	0	1	157	\N	f	f	No	Signature	\N
313	243	157	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
314	25	1	-1000000000	t	1	1	1	0	1	158	\N	f	f	No	Signature	\N
315	243	158	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
316	25	1	-1000000000	t	1	1	1	0	1	159	\N	f	f	No	Signature	\N
317	243	159	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
318	25	1	-1000000000	t	1	1	1	0	1	160	\N	f	f	No	Signature	\N
319	243	160	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
320	25	1	-1000000000	t	1	1	1	0	1	161	\N	f	f	No	Signature	\N
321	243	161	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
322	25	1	-1000000000	t	1	1	1	0	1	162	\N	f	f	No	Signature	\N
323	243	162	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
324	25	1	-1000000000	t	1	1	1	0	1	163	\N	f	f	No	Signature	\N
325	243	163	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
326	25	1	-1000000000	t	1	1	1	0	1	164	\N	f	f	No	Signature	\N
327	243	164	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
328	25	1	-1000000000	t	1	1	1	0	1	165	\N	f	f	No	Signature	\N
329	243	165	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
330	25	1	-1000000000	t	1	1	1	0	1	166	\N	f	f	No	Signature	\N
331	243	166	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
332	25	1	-1000000000	t	1	1	1	0	1	167	\N	f	f	No	Signature	\N
333	243	167	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
334	25	1	-1000000000	t	1	1	1	0	1	168	\N	f	f	No	Signature	\N
335	243	168	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
336	25	1	-1000000000	t	1	1	1	0	1	169	\N	f	f	No	Signature	\N
337	243	169	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
338	25	1	-1000000000	t	1	1	1	0	1	170	\N	f	f	No	Signature	\N
339	243	170	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
340	25	1	-1000000000	t	1	1	1	0	1	171	\N	f	f	No	Signature	\N
341	243	171	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
342	25	1	-1000000000	t	1	1	1	0	1	172	\N	f	f	No	Signature	\N
343	243	172	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
344	25	1	-1000000000	t	1	1	1	0	1	173	\N	f	f	No	Signature	\N
345	243	173	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
346	25	1	-1000000000	t	1	1	1	0	1	174	\N	f	f	No	Signature	\N
347	243	174	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
348	25	1	-1000000000	t	1	1	1	0	1	175	\N	f	f	No	Signature	\N
349	243	175	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
350	25	1	-1000000000	t	1	1	1	0	1	176	\N	f	f	No	Signature	\N
351	243	176	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
352	25	1	-1000000000	t	1	1	1	0	1	177	\N	f	f	No	Signature	\N
353	243	177	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
354	25	1	-1000000000	t	1	1	1	0	1	178	\N	f	f	No	Signature	\N
355	243	178	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
356	25	1	-1000000000	t	1	1	1	0	1	179	\N	f	f	No	Signature	\N
357	243	179	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
358	25	1	-1000000000	t	1	1	1	0	1	180	\N	f	f	No	Signature	\N
359	243	180	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
360	25	1	-1000000000	t	1	1	1	0	1	181	\N	f	f	No	Signature	\N
361	243	181	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
362	25	1	-1000000000	t	1	1	1	0	1	182	\N	f	f	No	Signature	\N
363	243	182	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
364	25	1	-1000000000	t	1	1	1	0	1	183	\N	f	f	No	Signature	\N
365	243	183	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
366	25	1	-1000000000	t	1	1	1	0	1	184	\N	f	f	No	Signature	\N
367	243	184	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
368	25	1	-1000000000	t	1	1	1	0	1	185	\N	f	f	No	Signature	\N
369	243	185	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
370	25	1	-1000000000	t	1	1	1	0	1	186	\N	f	f	No	Signature	\N
371	243	186	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
372	25	1	-1000000000	t	1	1	1	0	1	187	\N	f	f	No	Signature	\N
373	243	187	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
374	25	1	-1000000000	t	1	1	1	0	1	188	\N	f	f	No	Signature	\N
375	243	188	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
376	25	1	-1000000000	t	1	1	1	0	1	189	\N	f	f	No	Signature	\N
377	243	189	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
\.


--
-- Data for Name: zkapp_account_update_failures; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.zkapp_account_update_failures (id, index, failures) FROM stdin;
1	2	{Cancelled}
2	1	{Account_nonce_precondition_unsatisfied}
3	2	{Invalid_fee_excess}
4	1	{Invalid_fee_excess}
\.


--
-- Data for Name: zkapp_accounts; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.zkapp_accounts (id, app_state_id, verification_key_id, zkapp_version, action_state_id, last_action_slot, proved_state, zkapp_uri_id) FROM stdin;
\.


--
-- Data for Name: zkapp_action_states; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.zkapp_action_states (id, element0, element1, element2, element3, element4) FROM stdin;
\.


--
-- Data for Name: zkapp_amount_bounds; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.zkapp_amount_bounds (id, amount_lower_bound, amount_upper_bound) FROM stdin;
\.


--
-- Data for Name: zkapp_balance_bounds; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.zkapp_balance_bounds (id, balance_lower_bound, balance_upper_bound) FROM stdin;
\.


--
-- Data for Name: zkapp_commands; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.zkapp_commands (id, zkapp_fee_payer_body_id, zkapp_account_updates_ids, memo, hash) FROM stdin;
1	1	{1,2}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtu8Vq65D58gky88oqAVuCAx7RbjqkRNqXy1AeYU6XRZ8atmUQT
2	2	{3,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juh2GZtBwa9f1qQvouLoUBENvucM5dPUv12yATocLYLYVDwy21s
3	3	{5}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuoDMcCZVtqrJHhhNg5MgJQc5o8bnAgQK9obS8TjDudPDVB7dHa
4	4	{6,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvNv5u1gvTFeJ9reU4sPGEgGg27swHwFVAPHuVWKFdzoacA3gFe
5	5	{7}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtqMVedP1ewnD7BUFtGfMzG6Mki7r8mh5Y5jSr2adxxMAMMXyy7
6	6	{8,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JubjUHrWNP4viugYvg52Nnxuzu62ekL2Z2mKQFenohJ3sMpnXmX
7	7	{9}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JupmR5uD7rS33UYfBW98pyVHsRd5n34fvw7EzNS3ExkroSRcAYc
8	8	{10,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtpZiqYvLig6W1Aa3PWwpduTK5b7LNQraLaiW1Ru7w98Asj2uTm
9	9	{11}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JudWRrnaRg2YnpN8cXEczaynjMfvqW4XesMth7xC3rBb5Etby37
10	10	{12,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JumLb3umz1DHG8mfe8pfB1EUJhZFK7i2XaydpEeU7LyURjF7XaC
11	11	{13}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvKRgQ6aMUM1Q1tudwaAMraLfhjb465EDGHt2UncGryqAGAsNB1
12	12	{14,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JujPKzkz4f32RSHHrjVvKNSMKPfqXc2Nt6kiPmRyHSfhdtd5aHu
13	13	{15}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvLSMz9bbvgeXh1aFzTbnPsj3GSx6pkSatX3Y2p7WM7e6BWqWcP
14	14	{16,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuMyx2HyouhtzJZWKhfv4F5mqH2VBsugQjDK1Kzhz7WnkxqGEuR
15	15	{17}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju3WxG7FVAnVn5XyvYAaj3Z6YgS3vBxgCqRwj47vs1NVftyoQpk
16	16	{18,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvQuwie54Jc6Urf5jqNkWedjF5FfE4a6H8XQxybbWAbnRPde5ud
17	17	{19}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtZdLUyiwnhTHYDDreuoa6QsTVQV4pcFfsLsmeadB6wxmdAXkan
18	18	{20,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvGBgv3UrmCEiKE4wcSZKapcNGtwWb8WZASvL8gDCFERVvwDwxV
19	19	{21}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuDzcAeGa57aFS2XYdAcuKr5cutFJ8Y5kjagKaKpBDa7fPotYXa
20	20	{22,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtfRMH95znx5QPidURy8o5vtAg1RshguRiuq8PSJKR2z7nB6XPs
21	21	{23}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtZVVJv1ezKUE1gLfjvZS98vcCaxzVCr4fi67vUBJuNM1P9dc8D
22	22	{24,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JujjHnvfTBePqGs2QTQ2vHw1S6dpw3hczRB8EqfxpfntTN7DmqW
23	23	{25}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv1GDHo3w7f363dk9bdKTWN43MHJCxZhV8jWMb48RGnHGB5dDwq
24	24	{26,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju14PP2aMeXe6ziaS9B2PZV3VfU9uv7SmsvauJ43gmQfmtn5Fam
25	25	{27}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvKV9hKW4XCRZ12hBbYtcH5VnyzGzS29pBv9ydJ6UXMeJzXgxj5
26	26	{28,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvQDov1aSZTcGsL3okghWWRdkrNGBdYFewviz2wfYyBbArtkTpo
27	27	{29}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuYeTVTvfF1yQMY3wLcdeBSzxA5qiK4jnoVDgeEfBP7mytEdRyN
28	28	{30,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv2jRiw9APuoqpWx1hQqd4Lq86EneZyoCzE4JEPkwm4kRgFwXEr
29	29	{31}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuyCnjLv8vinTj9TMcA6AT49Ta14jmEELoy57GEinQZSaBMtJpv
30	30	{32,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuDmnWFfD1Nvis8VxLv5C1dDaCBJgfU8WU9NZeTtU4krQJEG4qM
31	31	{33}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvP6uJK5JWM5JkD1zuuN5BDbTpKt1JKk9drUy8wpJrkskCHd9DA
32	32	{34,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtjn9aaHcto45VDkxkS4cP2K1Qdh42UWrWLtUZzSw81joticM3g
33	33	{35}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuphYvMToCeAt7FqyQJBfGsDQASeMxn7TobeG8VLeDVRLcn5pp2
34	34	{36,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuTck8btkgRDjTEu79nJumHDGAbGomwDu3MMzfrwxAk9Y96QEtC
35	35	{37}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JufyMtMuFmN5MHZfidzxetTAyLi6eouFN4d9pN18sjfHabmGvY1
36	36	{38,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv4cVFitw7SdH9xvMQK9yxoN5MbUA9RckHHWgkyKxntqFpgwDgQ
37	37	{39}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtib3V5BnZPmYUrRDcUMdiEYGZeoUHbABWcTes1tDov3WxoNReQ
38	38	{40,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuPpkMRE1dTD61NRwJnxpD3kJyKFB7q2UB5onD9nbCHCis32X9J
39	39	{41}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuUh6Wvk33hRiftQQyYtWFtUo1K3RuQt4PwTBKwRP3hE8weyoys
40	40	{42,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuKes4MFbu3vre3WgAFcer6fmLWqQDj9Ghv492i99rSoau8d6yg
41	41	{43}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtvSTgbitB17iyYRmAX7TJMJmviUE3fek2fHHax9GjTzk6znu5T
42	42	{44,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv3X4oyNP86VUz2WyfEyPmnUL8eMpKBMTNtErxrKG7ayHrw2qYJ
43	43	{45}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvQyNZjxkVYb5zvJEr7g4WTqDbBtfYJB9ETrKCtWGqa5eUBfWkw
44	44	{46,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv7DfZ4qtxv14WEPZqXe29gQrZ1ABgaEsTbRdSwkZTHzrRx9d9b
45	45	{47}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuLQZZkorxRs2XvD83pFmmYW5ScuJW6XnrcVGcNQCBPfjgxqZai
46	46	{48,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju5XgHcXdhCNAXPhuxzy9EfdmUhScr7uEwaJGY59tzERdYMJCFf
47	47	{49}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuTyY56JGYFiet4n7FDrF7UYUR3cKKuxVxwTbR27vuDJoS8SV7t
48	48	{50,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtqN3kKNU4nACcGa1LF2L3Q3Sd1GXGeVa4ZA3oGF6zeQfjfbWaX
49	49	{51}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuQ7xgN7Wde3zq8NQsdQXr8v8uTAJJQKXAkDhazruF2NSLU1veD
50	50	{52,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvKBMFAccY4NTQzxbCTDJDweUfiauThE46tsYg7J3fqyKFRsehK
51	51	{53}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuBpynrNrmuiqftb5Jv2uP5GEqXym2ybv8dgnDRFk7nU9SoaUwW
52	52	{54,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuS83G2LtaTV4rQTya7tpvaNqU63MMTe7DUjpak1uh7ooDCmKFq
53	53	{55}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtXf7zp6LpKEuqoyxQpY1htoRfrNoPH8W4zD62ajd3KErv6tonp
54	54	{56,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvGRvwm5wRHDnfy6He36vykMfTJCNgXDb3U1Kg4FEoekiBza2DH
55	55	{57}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuqFYa3cWsnnCBeDevQ2PKgmMoH2aXZ4RJXrTgYKnMivTrxTW8t
56	56	{58,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtuvNWWhn3PosEd4NTMZzCXQJUXHV5LmeWSExT99mpyXnFosehM
57	57	{59}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuJ68nKYx4kASJckhrDhwu8QgwT45DcGH7tQ48T1rgGK7Wa2hcm
58	58	{60,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juk4c9i5aiAQQZ5od4R4g5upA6z6zypbBQ7wctdJVFiySrEMAsj
59	59	{61}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv1jGq4Qmh3FEmKa4txFWV1g7ofUsAt9aTuS7UE8fbQYJHxFTV3
60	60	{62,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuMMjCba2iQ9VkuAKVH4cRKwdjbbYJGP6XSNivgBbCJNh1LpKqZ
61	61	{63}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtu7oXxv1aFb9jF7Ss5DgYBiC2Qs4Q77HautFbZjb86VT6spwhb
62	62	{64,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtYaM6MAqGmC4ebtmJwHkDX2QS1Qr1p1j89yL8Y554ujCVWawTj
63	63	{65}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv9FQT7ELDVRTJH8wnGx2NDxrGATryQGruJJ4C38CoD1e8MqzEY
64	64	{66,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juz3VsduZWeeCshAk9MeP5wyN8sBnB1Fa4HMnJFQAaBWz5dmhKA
65	65	{67}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtvFSfQ3w1qs2jZEHLV2VYMhd13pgrk3UeovfFsHmou9RGDUUZY
66	66	{68,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvJKkqt8uWfwHiPcXdsWR88ENSbGvoeFQoz5AzvjDhHRFMFubxJ
67	67	{69}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtkhCNwpG6m5JKj9qFjQzjMuQyr9R4NqnYjTUtJsxYvLkNcKcgu
68	68	{70,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuJReC49fyhEBc1QRyn5HyMSUPmnvMq7bsbbuDHYdZbM3KqtGDF
69	69	{71}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuRZzVC1UTj9fnN4aHVqte4D54ZD1x1nfeoNseQVaVzRA3TzF9Z
70	70	{72,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvJMu6X4Rg1xdLvYG1QzpMoEsdRBWYxjuoRTjyT82uDSQaPaSMu
71	71	{73}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv2mrfXMMubmXBKWFv2h46tbtCKpq5QT6dQXAUdoEuYAZTq3PfC
72	72	{74,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuyE4Ey3QeLSx4fwcPxFzcsAgxX9SLg1QMcKc8aqBP7qzFf2Ckz
73	73	{75}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuXu5yL8Sii95CxuPXJnvYzVPjf2o6wi2Lc1NXFFx1uACTMwkA4
74	74	{76,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju2q8rZFAK2jN1bnTVDEwwmBpPDbj8Ssj7ZURtj8VR6ETFAkSMs
75	75	{77}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvBM2UBKs38KoxjLSuoceQCovo3h6wNUhs6nRXopTUGEAjvRaZE
76	76	{78,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuJR6b4bZ1MjEzLTeP2mDHnM13Y6skDPPgfnF1SaGmxbqmff91U
77	77	{79}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuCsqo8cr4qYnjjeq4JJWUix18VNn15YneZtbK7WcY7Xpgot3gG
78	78	{80,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvMLiETpebSPc7Mb4MFh3ksFa3zrVSd1uc3g1LRjHkjWKnBWCyr
79	79	{81}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JucyySthCFvYCvAixGfW5b6Ba6xyqUfqMLeyQQLDqVKpK9GPPBS
80	80	{82,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtwacEY6zueqr9tTTPHEhwMxxiEvbh3WX1e5SZByrCXfbPdzJih
81	81	{83}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuYjsvvyTU2BF9Rk2pobcj967DHThL9pRdnB8fHwicpZqREACSn
82	82	{84,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv9ZnwxuoLP6WCsXpM4MSTg3ZWRYHoK4PfYar4pEZoikMRyXwSW
83	83	{85}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuSDaAErq77WEFdu8M19uR8KfFhHRQU5mAx6iGxEDvrU4m3Dd3n
84	84	{86,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtmyp1wFxSEwLLm3BVzCoHXt3uotzxYUisNFW6tDMpuwrAFWe8i
85	85	{87}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtenvD63Hws7nTz4KTrpAumqxi6pVBhveoTUZau1TiQFotVNieD
86	86	{88,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuvEzGZDRUkGnjtMyMmdLecEoeE32twB4RYvEtmbWm4xitskWUc
87	87	{89}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtxaSwUKR4zvKvyExuieQPTDBbcRDYjboDQtUFgofjQezh62UmS
88	88	{90,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juex7PimGbF5DCUYrQjGK9BuXc8DuQebA5cG165asdN7wYRLM36
89	89	{91}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju83xvGNDjrFaKyEtpNPj5U6DggWLsj67uV3E52VYasXJ3wymer
90	90	{92,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtrbXnd2BcciZhQ4r2bNBMpjW2GW8JYkyEVcRXNSovoJoypy9gF
91	91	{93}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvBbxUeiskR3j6X4x4mkE9dnVLjCagJSGrovpHifyHpvSeWunur
92	92	{94,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvQi92znoq7k8dj3RycT1r41UeCHrXYYn24F5wn7Xj7KdkXk3Aw
93	93	{95}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuZDHxw3jiaZmLpNpAn51Q7jvEgwXd8yttPQTRFo1pcuDiTDZUH
94	94	{96,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuJL8Wi42roDi6Xzknyk86mSF38cNjMfsp6R2b8Gbkvb2H851nj
95	95	{97}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtj4JZbKFU744M1hfsQChVSPudWypYRMCUmMcNX5we7HdDV97zj
96	96	{98,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv5tRffnRLNxUwg2pVXjGAS5ZskAWeFKN7XxW6xdv2x5srG4krb
97	97	{99}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuucLmYjDmFK1BZpPo8EJhvSAo3fRjDjKTJeWQcLq7osj1XaXXR
98	98	{100,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv71uYghPN9Z4BQehLZ3MLFSR6QcVoTA3EF6KMyzhQXMNG2RfyQ
99	99	{101}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtgBaqWFDU77fCUcNHkwcx3V4D2tSEYf6SBTicecTxSGNAMqAVJ
100	100	{102,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtjdHBPkEipQR8xAbU3EQXFuU6M5ZU5GSmUsWPXQzNWdAe9G6EW
101	101	{103}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvARyZef3ev1KWk7QJXY5m8roMRbVznSV3Wo8wxWXdbECyGBCZA
102	102	{104,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtpbsP3AkTNGQ6ptxNqhzn5mxC4zT9ZCf2PY2kkHGisFQ1tZ1MJ
103	103	{105}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv6kZBBDzYpUyv1rgjB17kXUeNm7N71mthci9VmX6t8DUeDSq1b
104	104	{106,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuhgxCkejiCuA2DJWtvCxFkX7o8JF54C7XxvwiTCWyYhaj9db58
105	105	{107}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuBk9e9FkDttnFiykWkkE2mgG51UPrWLZTqzBc6ksChVrJuCKx7
106	106	{108,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvHbDLqjJzghLNwxuvAhPEJhpbQjrW6ezBGBuGzdjzmtZmHBcQ5
107	107	{109}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv6aZi74iSevUhMpTUCcF7KRnNxGk7WtLifXkL9uBa26h1EE3cZ
108	108	{110,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtaqVc9xGmaUdGPp2kVa6ezLTf6rYxnL7B9xdZnVwJYEKDtFmBc
109	109	{111}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtfB2u5iemoLUUr18Ch1ms2DoPdz6dgSV22rzEscZ4HfgPaRC4f
110	110	{112,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvPx66XdNm5rSg5Eqf1aXEdsFNWuSfS84xUyevARq2LDk3QwJj2
111	111	{113}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juf1dL8SbyzTG38YDNEaDuRo5sqqgeyqCtqziyqexjTTd7brYDQ
112	112	{114,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtoSJLJZ376nGLNxLmUzzujEE5ET7bDBa2dnMPsophwEEzvyMFy
113	113	{115}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtpEja88Z1UkzVwoKZyZGCYDViJZECgPZnygKeToU4pJ2tCnxFe
114	114	{116,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuXq8KRBGi5YztPm58nkazXpYfACHSSJq6wch2crtTAaZwzGmDv
115	115	{117}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuRqCUdLmPjWokUb4qNUYL84U8jctfe4ZmkxkqnQLawea1UYBmT
116	116	{118,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju6rVhrM6v6V3iPGKg2uRHZ12PCNR1pePHg79U8if25koLYdgYz
117	117	{119}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JupCUHKR4jTMhGvKXuMHozk9aDCBhxKphVC2C9ro7r3BCC8oXBW
118	118	{120,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jud41YSvwjgn4vZjTyLYDL12AiRNmKvCRrAsF8JNV5c4x1PhYB2
119	119	{121}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtyd1c6iq6wj7wtUJDt81hvAasdZEnkL2CzxTrgNmJd9y1sNzS3
120	120	{122,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtvYR63Pe9iJWGXLGZDCAuKHwVVWGQCR6vxWgtAsXmJGRhoXD4r
121	121	{123}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvJrH7FDo3VJhfr1FdsCY9XsouoTKeCouSDCAdRpbNYaR7S8T5a
122	122	{124,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtXyu3SLLQ2pkh4SG31sjgFx1bqwmuhPRxQPjQktQmSYySNr3Rt
123	123	{125}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtoxNKpUUG5qpcSqYfaT3hZYiZFCrwLYmP7GrY48crhB7wr2hrx
124	124	{126,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Judb4duLPdcPLoQMnpFjMPPkze6s2s9jXdWt3ZYAgykHHuXTxk4
125	125	{127}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuyBXyA9hTB3SVWXzhxK6etW7hBWjd6EK6f8r19Ek3eKtx6jgby
126	126	{128,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuWTa7t578EXdswx44u7z96xSTWCoHMGhPn3mxUTt6rU88QT74W
127	127	{129}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JufcYf221UaDWZxCWCr8m7Xb2V1Be4uAxoS7nYtgDf23wmc7Yw8
128	128	{130,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvM6oX4bZAUpu4gVDoH92QkMSxtykahgkkL2aQQCpktiD3gCT1R
129	129	{131}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju4Ht2FT2xWjJRJHEZ8CYUTy7uyr5DP65YwKx1kMTjtKKF5A1pK
130	130	{132,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuK5WeZzzToY8M94nFYuLM8XcetF4uLKk4KSEHMhCEwmbdRy3Cc
131	131	{133}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtorD3VcJMbN2AHfGveqwjpd8RxDBi4hJTQRkuS5xAY2x6YuUsZ
132	132	{134,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtbYQnfQ9DkbWkcEAxu1RMx1SvYUGNuZgXMxLM6G8UNifVrGH4L
133	133	{135}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JufMA6wiDMkcebBut9C57pZbe9vGhwyRVEByYAeubxTax6vBUtY
134	134	{136,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JudDhcpjtyeM14jyEGdgVWav77sAKn8HGaZXdoqSE1q44YXKX1E
135	135	{137}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju4dphAyHLrkQdsDTbNsUsUcL9T8BzmfxWvBdhgMTXQSTH7VaUd
136	136	{138,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuJqWYvDFQ7YRizMd7L3Z1r4rdZ9fPxzdgtKh9u6Ah7iw1Trdv2
137	137	{139}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jumx6DmiJjMTeyvbfuKUpUcqv2q7rsERyGMtp8TswgJrntRPnTV
138	138	{140,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv6vrD9DFSoZqKUgRuDaLUzDWjeLY5nXhdt7MEULhSBAGMwExAS
139	139	{141}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JthrPFEwHWL5miyQWmqbyhStB2H8DeyTHxUDqgsaMnGVvGgZp9c
140	140	{142,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jucbeh6xPpZB8JWCedkMFY8SfK5XN7NFru4APBLdGGXdYzk8C5v
141	141	{143}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvGu2JMa5mByH8t2kLAE3PR9FwMRkPM4B7vrEzqBxAbs6Y7GjdU
142	142	{144,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvA4d5mLa1pvgUXS5DAVmGoTSpASUSEiabzxpRQiTDnsWGrKR9t
143	143	{145}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuFzSTo2qTkAHjM4s36TEv5e2ToUNRgRiKjVFoyBj3wEswA1n7A
144	144	{146,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuqKugCPsERQ9TkEXshErjM1qGs6Sq3bGBx6L9N1NLCxiQ4adMa
145	145	{147}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuSZrTYg2qWka4fXNkBkvAZV2B99DcNg3UhJYcfpNPL6Z5JbWCA
146	146	{148,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuAXXYFQUrGrpLH5M7qHtxK6Gbaf62oQcjhx2TbHeL2coFsAtqb
147	147	{149}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuMrhGeS97nw1EhkFRrT2pSC892hEgTRG8Uw73n3tGAPcKgGULZ
148	148	{150,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv3jTGcz2XqobBi9jofvdrb7LmjLyewp26gNCUN9RqkqPoMGweH
149	149	{151}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju7HCZ2dkn1KegDVKKYTK14PfLcFiGy5yhmcM3MAARbJHdyfSVC
150	150	{152,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv5pKNdHu2JtTMRBm8eKyLkjPMpvxJ31pksrh59n2ZX3Gav5Aqh
151	151	{153}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvM8jerj4kbdjvm42Z1Ldv7cbE4kFyfHhUMPzQbnrxQBG9Kn6p1
152	152	{154,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JutUh8zWJcwS94Gup8RBRn3AXJFqS1xYfLPfNwDLjJjpUJ1b47S
153	153	{155}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtji7DJKHAminvgfnFKokL8EK4B3dwCMBTxqiPpbMePYVc5qGn6
154	154	{156,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jto44fS4qReG9LYK1zLCQ6YwnrTkvogdRrXt2PeprvDkEY2wPUf
155	155	{157}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtpckMMFhsmssP87ngX2pDAvbNv6cRNkTBPpxRSR3RghpfcjDZZ
156	156	{158,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtwBxcWWxFz89GsycbAv2qwDVnxacgyjt6sJEHinKVP3LUbTpnx
157	157	{159}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtvKR4ina2UFg1gWjhL3uqzDxqvJ8bnxjbmTYSeg44rxwk5WtnK
158	158	{160,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuXeEitn3EuShRLg7bieXSZjRAwndXX6AUxrh9sWyTYaMZ7Ae4h
159	159	{161}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuwmmhdP5saVBXXGRQnyqYKsUNgjy2ihKXT7QFa4bbtjkQd1tmN
160	160	{162,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuQhe6a4TU995q8tUkTizzdJygwvF1uN7bJK1Yy1oSiGrCPhMfV
161	161	{163}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JurPMgo5UDLBDEiiydicyNT5D5HN5rbCvNVmp9o7Qzz1RCjkg8H
162	162	{164,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtucyFLrirwhvtG5682vD1DLUqJsBK2LeXhXqpNEZdfXi6ibFbo
163	163	{165}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv2vL9q5yrMGXZJgUdsQv6SyCivKAS6rm2wEE82xj8a56XbBXEb
164	164	{166,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuYXKvWFJv8rFkQeZaEB5V1Dbjg8jBoKKom5TH4wSxcK7SngqWq
165	165	{167}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jua2AQ4TNYQyLnp2wjABz7QaoVhJu1KYxxV8Q5z79WDA7U3GzV3
166	166	{168,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtcRKZYkAEo98956RHukWBAxfsutok9ZbQRqpMy391H3pdBnECf
167	167	{169}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuL8f4FMp6MAujAQTHeqfQZ6WcLdLBEASPXGq69nXa9PHDzarSE
168	168	{170,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuAKwRUXMcvC63GCx1znuHLxvh9r7rVDJYaG7eXpLJrwRhsd8tr
169	169	{171}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtewEpk4REXm7LdtLcKdeGRC9RokDH8cqxvLZZGscvDpVQWN1xR
170	170	{172,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuVVL9KakApatMRSLUAXbLP8w429rcBzeCUuptFHdewJMeRQcLD
171	171	{173}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvQX6QLsFN7gnSnn4rJkcTycKXdMH4nMs3YfdoJs7Ed5FQX5bpK
172	172	{174,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju8yjcAFgnWeQefUeJGyZA1aJEYJ7BsyedMF5smjZZiv119PgTv
173	173	{175}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtYJa3SNhB4oG3LiXZ6LqZm8aLh6MtHsCqmx2eKrbeLyEJup8iZ
174	174	{176,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtxkfXcd8eA6rmUSZqgfHnR2i4bVQN919puB8yHmGmVnuLaqCXd
175	175	{177}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuvtS8bpEjenSFybzceYVFdUkf19oakavbg3xyzD9ucDsDyoiVF
176	176	{178,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvKKWcomoY1v79ckxBHwZ2LGi81E3ker8PF1dnScMzVcc4K75eU
177	177	{179}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jua2mmW7xQntAbrUVPr1J4WBh8bfsCStXugYC3dmSG1suJK5XGg
178	178	{180,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JukZgtNKs3j52pmNjMU5YtQL7GZS5ADCWyS5cbV3tDvnA328Bwd
179	179	{181}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju5rpmdEr2R2dkBwoECVxHWi1TFSetMDu49uYDtEei3zZkv3q9B
180	180	{182,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvJAycidannpyW3tpQKAgMn6FttkCsBa3nT8KYG1YQW8reWnsa4
181	181	{183}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvGz9jAmgV76R73aYncNCY5685SQTkxz4acpK7QVLsgEhzXbYtZ
182	182	{184,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuPkxGA9HJsVwxSaZqkRzugauVLys1mE26pRG1cRP2oG7FaTnu1
183	183	{185}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtuP8uJpADBSNvyg3GcQyFpHhjfwstL9cnhrfgc7GRm4T87abJk
184	184	{186,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv1wM8PoMpe7FyxxviEd7CcWhx4NmULMZoGrY7N2zqHk3xa4sAe
185	185	{187}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuxBzYrfWvW5G1d5fCafvDa7t3e3KiFoF8xUWcriVGYJiQJpQDe
186	186	{188,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuZo37AJX8ppjrmXzycfsuanRg7JMq2U4NMCftkae59EJySC2Ar
187	187	{189}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv1qn6xSVjFNh7n7cqHJsBeP6DjKX8k34qQmTF3GPmaHqveCiDz
188	188	{190,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtXTHAJra3wkoW4faA2BQdndmmNQJhaVd8NbjNNZJyxD1KzptRo
189	189	{191}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvFh9U1FGtDaD1X58jBYo4foZWwabTsnQFj291XLEiDyqHnce3h
190	190	{192,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv54dzSwy5nborn6SX4CMg47DeopcjHbifSveRnaLGQBwV7wj4h
191	191	{193}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju6WaegwUf2HGi3VryrtHeXrnrd3F6MRCqS9YvHRm1tYGSkqS1y
192	192	{194,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JujVLtSV5h2WfgmzNhXcJFqg73QwwX35T6utA2FK54W5ypd9Pe6
193	193	{195}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuCajk5dZsrdVU3XmaXRexPRaWzLeDHoki4LvGmxnxfhdNo99Fb
194	194	{196,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvDJXEdG4Xo1vRPih5VM2UFJcXMsvxvKgXsX6WjgJqmhec2hd82
195	195	{197}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv7BgMriwEuriXU8v76zyiAiVABP3axHy8XJPCiJBw8MD8KaXTf
196	196	{198,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuU88PCzTrXBGAYwKLb6buq7gPQ58iXmB2zFrXwfpugjUnqt5tx
197	197	{199}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvL6nnWxdSw6q9FnsG3EQq8LkNoG71BXG2SCD8Wt6zMT5xgdAgC
198	198	{200,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtbXamasLNARw4jKfY67yipRzGEJXB3MjEJ4RLMbsEzf1154yvc
199	199	{201}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuchYUoq9m35WHffJBrpWE9Cd1X5M3MeV32RJWaVYpbXskBCuzT
200	200	{202,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtcSQDmC6y3wPWT2im59mxr5j4UvXrUQJtpTvT9fHiyAdqch7qJ
201	201	{203}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtj843ZwJyEE6mxSYu4HxNbvUxfzmefozf2ZvB4nNLdrxvgsoAK
202	202	{204,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtuHMT1nmq3W5Y2Go517w432wE2bFjRopNzjF3n1TVxXtit1QyB
203	203	{205}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtaC3w122BcKkjacAsjPL6UKgHrryuk7KDPZceJBQRmyAsg9thg
204	204	{206,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuPLtdRFGHEKcSRxSLSy3hH4ajkwtYJqU6kKf4tQj9bJYJENsmk
205	205	{207}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtkwvid9PC3ap69YBvWsQEuari5eXJZWomY8tCsNtMa8qAv9vBo
206	206	{208,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtjzTdYWXjfMaJq4xvP2tyxUPu5T4UBSBwdWAqfqmv7qLB39imj
207	207	{209}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JthDYkjCw4tDVMwnMe2P3LtJ8kbwMnGwNAFWcxrXkK1NR6AC7tw
208	208	{210,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JucvND1GnS7TMueKJg41AvPA6p58UyCdhZ6bUocVYmDF1gWoiV7
209	209	{211}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv8DRkxHLNZSxhB62zKAPQwG9nJBXQU27A9o6duw35U8PT7jyTC
210	210	{212,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuMJ4SXvb7NBfgLYeXfN1gkfFGorRiQ77tLtE7Z86CdkwPczPVH
211	211	{213}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv5vcwtKKgjqqBVuV5HHVaNXG3jrVHYJUeqnn743w1s9DK6xm2B
212	212	{214,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuaKHhPikiBYnehH5bRYABtJsewdhqF3nVNAyPvYpGoZP7jYyxn
213	213	{215}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jun13YEpd9f7HEhZppcpswQKnJpfTd4GaSLBzeg5ZBHGiTd7tyc
214	214	{216,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv1u2Jf7phak9mkEQMhHL29zAoWPaYm2mBobXBdUsWQUqE6W2Q2
215	215	{217}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju1rFKK2Nt3Pw5sDmFTXJovm4q7JXiPmWXfMrNTmqcC6hD5gPAw
216	216	{218,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuasamyPgYeok5hi33ujE2jX5wjVaTnYU4iHSLZcqipp2dCk4Cg
217	217	{219}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JthB2v5hWuWPEReF47AJt72AuToxFMgqxP8tq2o5CdzPYvuYHh2
218	218	{220,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jte51Uvos7ZSE7aBZW8HUXUVGKLmcpCz8RZWezoUnmsZeu5v7by
219	219	{221}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv6ffT2WGzamfna8ALTjMmvSBmSnvPvfo5ApNhYFKBf9QbTYxa9
220	220	{222,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuRNzozZcoMu31KsQLnJGJ6tnzm4PTmpRwyUCxXJhWT7gSco5KL
221	221	{223}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuNtH45FJYe6bTnnWEZ44hffxju7w25uzqkFhJjoDuR4N8w7Ppw
222	222	{224,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtsRfpr99Xh1zLPfU2XDrK3zDQ71wRZfcvLmDKkqkbLaCqLMGGX
223	223	{225}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtYERk5bTNTXQizMtoQnhYaWJMqV19HwFYAMpSiUZnKwXKPHheL
224	224	{226,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuvioN5UKL6rKtY2EN33xL86ES6Zep94yYL8tk3MHF5qDPNp1tc
225	225	{227}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvDavqs8k8XU5dWjZQCpW4BsRGQVfSHG2KjTv1s4viDG93tJACp
226	226	{228,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvKE8msBaiRcR4SYaseSK7L8wMCz3ZRHsq1iBrB6NeHrGzHoAEZ
227	227	{229}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuK5yetFBHAcddRbveYNB82n6YQNNp1qQciXeMVfZiqxx1JeiwA
228	228	{230,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuqstF6zTayFX6PDCJT1PNc1FVt8174cSNkvUBXBppE56BsPLiK
229	229	{231}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju4poC6GBauRkQ23UThbedZjVUZMhLFeZapLYhEPhrYL28iHQBo
230	230	{232,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jup6xyk5kH1aUix4Xcb3ZDTbekCzam7qTsKV2PA4fhg9MdxBMgz
231	231	{233}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtdeS8T1BzhcdbECDm1FJDGJsNd6nxP5SLe9D5doQT8i8rhRuAK
232	232	{234,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JurBQLwAyAmF8jmr5YQ2SRzD1iZZARMCvvsQ7rxsYujYg7s3Rjp
233	233	{235}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtiqw7vUYnz8q97rBFLRzErNXb1C9HG7sGsi5QQPn5mL8KktZGA
234	234	{236,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juys2pWgu6WGCuJQgZQpD5SXrHuUXxFP3tGuEXsakg3xv8ZdYgN
235	235	{237}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JubCc4Mfsp6wBen7kcWw1orjCWoJrQyPm8B5Gg5sZTrvfQHNU65
236	236	{238,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuqkdsDhv7gwWTXzww5WPMmJBuEfWpPEeDbfFvAq2vV8t7JKMx4
237	237	{239}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvBN8M4jt3cnjoxxaQ2sWxMCuxcqvSwWVHnrp1eqN8HZWxyAkjm
238	238	{240,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvCHad2b77fLAqDMncxtoCv35Rczh91ho9bhEyd6Q7ReAaJWB8v
239	239	{241}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtpwQpVJ46mFZubPttgXhPnbWmZi4BcvYZ8H2Df1zS67TVdVS9q
240	240	{242,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuaaW1BF9DvFdAwKvvNiKBsoy7fiEXMmyJmpu1smfQghymFCmuW
241	241	{243}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvK6F4hiEsQ7rcHdhvxc54dURDqzwect4tLL1TxV5DgxwFiPzzh
242	242	{244,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv7aeq24AirN3P4R5sTj4CmqyZdXWeTncksiTchaQ8PfgkbTvJ3
243	243	{245}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jun9Usv4Jfwg5GBz14XXoLHKFMySkqWSCnMkYCzMs6iusdKADsz
244	244	{246,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju3Br95FQnKosoURMJNwBp49b9DU1JmRsfxt5PjfZeytVAiFiLh
245	245	{247}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuHHD6KNEePrzJzku7MuGemhDRbKnKXNmuPnerRaJVpjaZbJGUz
246	246	{248,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuHJgfTjfiVwkgo1vWpRtFfh4U8DosU5HLdkLg8pAmUf1yrP9U8
247	247	{249}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JukFKpSbXC1hPRwd2Jqg7kSZLTBzH41zwEWPmeS6Jzoqjk9BJSX
248	248	{250,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtu136kGDjqiPg7YNiQ2eXy5vpDDTUbNZZ4UqCCg9gL3XARDPa4
249	249	{251}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuTGVwT2MVhvQUt5zPQL84pNJjSMZwQzJDDN1pUHHqigHhMTR3F
250	250	{252,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtYW1691CedHpPAWSU7AuiZYTr2SyNfc5fQngUBxaFW9UU2DACR
251	251	{253}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JumQPodT8mz5sge3CroyC9wX662u6m5Juo5ByPmiR9irVLpW8Be
252	252	{254,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvM69TJytn49MfZAaK9zWoPqR7Buf3kiCgkjBgjvAtBfzHYKdFV
253	253	{255}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju9cxmW25JnCURucV4PScobmpzhqVrFHBSnHeZ2fYHEwdx7S7M3
254	254	{256,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvCUshnyaZnpAkVBXzdYppNvDeW4JDsf4RkSDQadseiZcdBf3r2
255	255	{257}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuEJ5ZR4orWzMnTCgc4sQJVWvGgCb5VJ6yS4GJo59pusKJbV5Ad
256	256	{258,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuJtwQmSGr4RvMppnyL4Ezq8UZvLYZHijTYsZVYSz86kHbigToJ
257	257	{259}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtkKBEGqQUsZcV9qetmcFpi5ZhgVLcJeF7xv2ZJYthu6DPoZesU
258	258	{260,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvGaWPSWbWBosAU6K9Qryv2cP2bAKaSJhmMPsf7oRFXabWavsmJ
259	259	{261}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtzB9QgybLhBjtJrtVF7KgisuyriNTQrsYu25aSh9LqEFmbfheA
260	260	{262,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtsoJt1qpP8raMm9s8xwSU9pm8zNbsRD5yYnL672TEKkf13hXPn
261	261	{263}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jttf3DFFYGQeUTfthZFJzudzJTy2RyHPtxFomH3X4nJuQHzqg1R
262	262	{264,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtmmJ8urDnNfcXpLs38T1GryTLXrN1EwP5fjsCvsTCmyQwzgPEX
263	263	{265}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvAsjXGJxZ7BFhP6rTZgrXJME731nMJ37ZoKmUrXsJzsNSaAhfm
264	264	{266,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juo5rxFYyt9KUW1mUuFVHyuZ8XS73aeHE5GoYFyQGnfwPBKk4Hy
265	265	{267}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuXXL2HdMUz9LoUDSRf9v4AWQN46EVWMUyeaeH4KBZwzqHe9WgJ
266	266	{268,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtfpm9i5YFtD51oih4BEHyjYcjmXcXLzNs4kzKaVt1cEYFMxSiA
267	267	{269}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jufu343SG4N46YbVHt8rqAoha2VyAsyVPMRWAtt1CK2en5iW7t2
268	268	{270,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuEu1kkxCvTfBeXhTjLkAFBgocx6HJzWj2SWXR3uXhaDrziLUgs
269	269	{271}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvLMLJTbNHjp8kbAVcFHS6CDkA4t9PCMRMn4MR3MEbkb4wV42Ji
270	270	{272,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtcFDR5YdZkGjCszyN8BZfTd8t1x1ETrHKWNMvx2FnSX2U4s19C
271	271	{273}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuvA9RMy673oibAN1SPcTcc2x9rNdfPoMsnDRGbqm7HQZqrfjj9
272	272	{274,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuX99mmumu5Cjz31ooHYXWVLv2aMRyjZarmXrSUcHi1eCGgcjjk
273	273	{275}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv1Wdh972pz9dWYCEEXvD1y7hSKo4Yos6XzVb61qQtC77tQ94i7
274	274	{276,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtjjjUSwhXzo2R3pKrjax91CaBmeVgscCMBqhLgtJjgtaCvPByq
275	275	{277}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvEYpnx1rBj3J9M2otXewgvFgaWko4TYPWtYLWkNDM6HWGxd2sZ
276	276	{278,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuK3Lj2wE4VC9XzTxSQrj4vg5114bYxcB955R8NQ8HjLMEPeTAX
277	277	{279}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv6pxoettV4NGJQfkShJznS2X97dhNToyMforzPC581vxZexA4L
278	278	{280,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuPKnKTVnALYyxGtSLayoDSPVoRwqp4tPR5aUEsk9ktqeoeoYG1
279	279	{281}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtpf4cuu8M7q5vz3f4wY7zYhddLFKTHRekAQi82B28eLSwQcL3e
280	280	{282,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JthojkZ1FXJYB4s1DuSV5sSvBPHrBvByiXr8BJ1qeuJFChsk1bs
281	281	{283}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtpgUU69gjSEYGThxk8usnrQMSHyx3xy4ZPxqQSbtFTDUMWvFcd
282	282	{284,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvFNkL3yntvTuiGWY9PBZxAm6hjQui1jkZVTtuP9rA8v7p8kisi
283	283	{285}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuWw8wqmkAktiPwA3fSDc42CS1c3ujFXCZxgMfbbHXAJBK6rDVx
284	284	{286,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JujuhtrTaeiewv5BePDt9b372KrjgkHj14gBHaxdabocDUyLKQY
285	285	{287}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuqcX8ErRaoqQdEnNmBDNs9eKP9d6LWAorixogZMW94bWXSjZfq
286	286	{288,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvRnJAVhdnmdhyTS3Wf4ipWdq83i3Uk7gWLwzTUAo31gGEQ6QE8
287	287	{289}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuhDRHJsST3C2WC1CaSAd8TGFzXu5sfbrrmC9Q3WBd4GAeytrir
288	288	{290,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuSFhzvLaHu2N14g1U5FAG252EsiqSQvQhaJfp4tBVZYgNDsFJu
289	289	{291}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvDZrV7EHjx8HRcFSpx76d36pR3n7GSEKXD36A44QpRKoF8D1T9
290	290	{292,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jur8zj1gYqhJG1ArKdjFgSpDmGT8eTMQDWScRduG1TjpZ5MhvxK
291	291	{293}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuMzMZZxwRNXDPK9X5DhiEBT5TFajmBYvfgR25SoDcby8rt6zRj
292	292	{294,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvAtrexvVtxei37N72tUS7cMAz1AjE2fmam7UZkwDUnmKYoQfHv
293	293	{295}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuArPx6EgPkYJRyaQmjQk9aBzyWYkBCjcejJrSSrSDx3mf4x7SZ
294	294	{296,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtxcmV5gJR5Cpx6pdNsEDzB7qyxcXXt2RsVfC1UXbpXJCxp55YE
295	295	{297}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtrwPsUfmaDwbUnDYNSJhf5E5RVrmCu6R29chXMA3siC1TDbyvf
296	296	{298,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuXACrmLu2sVAP3kdjD3BLhRcMYYf5qtJYbGZZPhYtdKKj5Vqfk
297	297	{299}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv47GF4ee4JbZ9GYQ9viGYToPVMPxE98ej5yizanGSc6eQR5Q7D
298	298	{300,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jty3jBwH8DgTSvh6r2ZeUkXq2QBHXBwb4XtkGSPDokUSGsYj5TC
299	299	{301}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuoLVUW9poMqdpdFhKWKafqx7fdCmSBkBSAbcR3DQxqU7Ufkc1c
300	300	{302,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv88FDQBhRZ71muTd3sfrAkNwBm6kU2reh8ube4wgK6TVqyP1Lw
301	301	{303}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvKgS4XtFWNMACasSCrkWohBQSu9jyymPcxZWLbQqSNFbewsKbd
302	302	{304,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuTkz4htoEc8hfaD2FDCoynzDLmRyRoQWj73SeYWyMH1DLmsx2w
303	303	{305}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuU86tjuoUaAMn3Fs69cSNahRJ4o9Lz39LFHRHmHzaiJ1Am13KK
304	304	{306,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuF86PiX3QW5mpYxQPVgQLu5XtvK14LXkP9G7rNUv81tQBUPdjd
305	305	{307}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv11WpvY8tNohKzYuQNBsy4CdyVXFj7nCZg5dGMGHwaveJdXQR4
306	306	{308,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju5C1s6RzePRYFF5pZs6t9ubQtnFRf9TXfg3qd3nW8vp3q81tYS
307	307	{309}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvKi8oFdP7MC6CWPBuujefLYJLZPtmfJomTo9FSn6dtEMmZbDCr
308	308	{310,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju7nj9L6gDGyQCHhehZxy4mF8iiVo44RvbhHWeNoc6o4XTZrhgW
309	309	{311}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvJHu1VAM7XhzYdHn6WK1SYz5kvhy9ZfvGcKkZKECZaWHKEfTdN
310	310	{312,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JumZhGF8fgmy2bW98ekyJbcZTV8a3sxGCVF8Z9H4sC3zvm8bFv6
311	311	{313}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuZTRRV8FDHpyim7THzNeXcpnEd2bxoz27BjRqQrEAvbUrvaw2T
312	312	{314,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuuGaT3offKW4STsj3q29H5FPsVc7oCRaio5gFnsgjEjTfzTESi
313	313	{315}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtorG5vm3PUTi48kBNd69DTSEGWnSbXrB9N3TuTvby8u2mbn6pu
314	314	{316,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JufGGTd7WQuBQsmid4WBiqHTFHAkzFzWFdqd7QyRVw51DRL5gRk
315	315	{317}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv4hjy5iPeXS5T9FZLfhNY6KxwpFq7yNiEa6HgVKFDejwjgMVGy
316	316	{318,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuVDd4DY4kNyWZXGUvPWhQbRuLqA6ea3ucmkzf3tQ2yUWh4QYU2
317	317	{319}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtWxoPYKUZoW27qoFKCWPhoq4yQCACACowHsNuq61AbM8kCno51
318	318	{320,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvMmtv6FjM6WqfiX6vvT975vXFhW9XXSEdDbmBRhVL5hVSnDYRV
319	319	{321}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtWFLAoZ6JgG13kJaiJvShRipqkWLigTrPRHqFrvcqGpM3AnGdp
320	320	{322,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuLf48e3233XaKjxraP3tcaAcX2FhMFCRZGhLjZ9HzWFoLyQBRx
321	321	{323}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JutuJRFAYqqRKAgPboPacEBhBLRoHaXxQRALATvuXVeS2oskMrp
322	322	{324,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju6fPtf8TH4XPvYEKiqfAbKHPitFzRdxCopbnY9ynVShuDgpjc9
323	323	{325}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JubMwXwLjfd5HYE1g2BGYJ5fZiy1MML8cTByWVTvc3h7woVZBk2
324	324	{326,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtcjJSiiZKxxVPnMLFHENVf9zjQfxR6sqMRAnWc4PU34MKstGHM
325	325	{327}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvR8SwBVgipKc26DgJrpGVUnnf33Gtfj2P1CfDjATsD1sMeMpfT
326	326	{328,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JueQETG3VqDEghZqVH23CWVFBCqNgAdUxMY5LFM6yYVj6Tp5uFm
327	327	{329}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtfJNZEPJsawxMVg3cKUk746FrWhf34h6WcFH249gSrGmVtpMH5
328	328	{330,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvCCwEpYf8XbcniMrMwnumw2mToz5c63ta8YaKiGax9Fudvoopa
329	329	{331}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju83Mkges3WQEun5tWQUSP2ZAFfKxsvAAHzdbKEMdwoWH6rkZ9n
330	330	{332,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuRfWDY9MKCGhYotWWwtgcetVpz3GrF1SsVLC4mbJhDvz4mzaSD
331	331	{333}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv6SvN7o8jEA5tWVENSb8344vgcr8ZBb3dpUgxw2PREfxeemB2w
332	332	{334,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuMLaT8hGDJ3gbWMuGVY7XfbH9zVMxwqZMJs1ZuyE8Hfq2ywowF
333	333	{335}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juva1XjMFXyNY9Tsi7jxzqrtFSvnAYNy68wTRVeikQgS15BpFS1
334	334	{336,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvFjNv3w7FtxMHy8reG6AGJZknvGGrDfarTtdYcafNPvbL2qWTG
335	335	{337}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvA5mZxF3GHGTggUbY4eM96xjtnhcygBQyEmaTGJQKEASKMBdiV
336	336	{338,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jut9vZUY4sHDa5qXVvumyvcYi186LC57a8zHPMmdbsYMJMbyA2B
337	337	{339}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jupaofa58RbP2Pdn3jHfoY28z1MhnbEqM2CE7pAmGLyumQ7aiKQ
338	338	{340,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvS6yBgnfxmpX7GQJBZno6KYfrKXj6JCPAmakiyqCKhe1Ytzkhn
339	339	{341}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juz1x1ncRyJSRF48yKyrvYB994xfRRqWDsaosfiYpByF8VBKJuq
340	340	{342,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JutarLQg2t7ejwKnP8iqAsd2yXHCWCLwxrQpZSbzWJgLuMUzMBv
341	341	{343}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuLTd3EvBHvbsMztHuy4VWComuuWY4GbhA8kzMXRym1bKfEwMrr
342	342	{344,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jua9fWRianTggxijMb97ajXcSER4P6HV2nD9mBnxiXHDzvXyKRV
343	343	{345}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvE764L74s9QcFpVCS7mykFfJYxAc1e3zGrweocPqfZK5hKZqF8
344	344	{346,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju7zM6bBzQt7WXMnX9JQDFvDsPb7zCCWZmbLv8v48kWPsaaa1dM
345	345	{347}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtr1LFEwN3btfHT5jLe7GhERkBpiJupcZNSVwg47MfmM6ycFD9t
346	346	{348,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JutkayxtGqeNc324DVVuCK6fUJzjbMR1S3a3cChMyDn4moVQh1s
347	347	{349}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvDjQojYY9Qooyxd275s9RBNSpg3mJpzGtGoYPTXs7P3ZT58UjD
348	348	{350,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvCKfAnF55kNdQyTiQkhcnDpfmLpmsMooPUM3owtasrCH7vavUP
349	349	{351}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuDw779QBZVkqQ4uT8zoJxZ9YNvsMY4ha9sHURgavrNVv7Dr2N8
350	350	{352,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuzoZ9KhGQM6wrgCUdYboUHi3supk6cEbynLxhTCwZPWAh6v61M
351	351	{353}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtn66SR43E9iGePcx5VSVVjzjCM68B7tBkTiEcSeZREf2wLm3qe
352	352	{354,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtZGB9ZmdF9GuX7aMSmER57YiQhBzYh8Zbx2YgBur1vKfemhBpo
353	353	{355}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jux3HtREw8cTqCQTXFyCTukqJ1yA7r9vFwbqMbGdLWDqCNkasRk
354	354	{356,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju4g5C9wecntuah7HWmGNofPH7SqYsU8KcqGs4jLdrnBbBDxXXU
355	355	{357}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuLdeTgWMQ2qqvvUksTwzdG7DmLBsvkXEndiq8YLTRQ1we6cD8T
356	356	{358,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuCLvpSfHC2acjjBaHx8GTCWjjwdN25k6TByGaczLJfDMgFrAJ7
357	357	{359}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvMbhpUL9FMQZUVFWfXBEp2ssNc8xm8Eao5prRK37Rc8pWxQ2bV
358	358	{360,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juo3tTWMvR2boVi3VJbYKJQnfprP4X9LHfnZ4PB7vr9YBbP1WHV
359	359	{361}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvCUf93dxjjhTXT8JECY6VvwFGtzXK2xsRr3MxpnBsQrWa48S4R
360	360	{362,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuedNBHQ4fkoCGcHiidVWMD2Lm5CohpPt5TLv4PB7CmehK4PJ32
361	361	{363}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jud8VrPF5azvWgFHy5QQPxasdSTrWkFNuYkpJdfryvTSBD7xHdP
362	362	{364,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuwSFo1uhodGStmbCq21LLp3dzJBC8h4Qu8iCpcvpDxQ1JQnBFE
363	363	{365}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuvNnctLn7FRsrd5Z3kFmf19r42kxCs88VKsbvSt6ae5ZVvu2jJ
364	364	{366,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv35LVBVXeFS4s6i1gtDd33onayaRf9pebgp8h9obGFUn5bYKzh
365	365	{367}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuujN3qXykoCvas8rjKqkcBkji6NEpBugHdmqvBP6aS5nvc8tR9
366	366	{368,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtWRxd8pMhqv53rqqbb7f79f8NaT9GKAmBRueKgtYnFX1vX5du8
367	367	{369}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuvU814qvQC5wPsDCvavtWa95zZxEnW3RMKXf7qX1xwdjchcPF5
368	368	{370,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv5T841k7LHCChWCRX7rCzYEMqRE538oUKZrUFxMxaqzk2dUipj
369	369	{371}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv8kctzfFjiuPZ1urHLdbHaVtjx1PRqLvHkmbJTipwwzvbhReqZ
370	370	{372,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtkmkuYzrs881pMoF2gu7wdGfQSP2jUCZo8zwRS1W8QvR4P37xB
371	371	{373}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuAmGa9g9RoAwmjYYLrsjAcou2TWJ2HsNDyHa2JVSFdcvLBLb3F
372	372	{374,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtYXjPfHWEMVrkbSWkQh6RfwqLexX67dWzPGCtV1PDJSf3rrJ8h
373	373	{375}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtzDgTNUNnEqD3sd2eZqwDik434UP9ozMLZVjAm7cXdwLhaqoGv
374	374	{376,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvR1Hcq43kRK6zAkvue7eLQwxX8zGRDz4fKTdgVksSHEQfnjKsn
375	375	{377}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtXbpzKvgTn5g19gQR71mSxAPLocjXYVh5sHjcLU5SGVzkEHVB5
\.


--
-- Data for Name: zkapp_epoch_data; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.zkapp_epoch_data (id, epoch_ledger_id, epoch_seed, start_checkpoint, lock_checkpoint, epoch_length_id) FROM stdin;
1	1	\N	\N	\N	\N
\.


--
-- Data for Name: zkapp_epoch_ledger; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.zkapp_epoch_ledger (id, hash_id, total_currency_id) FROM stdin;
1	\N	\N
\.


--
-- Data for Name: zkapp_events; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.zkapp_events (id, element_ids) FROM stdin;
1	{}
\.


--
-- Data for Name: zkapp_fee_payer_body; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.zkapp_fee_payer_body (id, public_key_id, fee, valid_until, nonce) FROM stdin;
1	11	5000000000	\N	0
2	11	5000000000	\N	1
3	11	5000000000	\N	2
4	11	5000000000	\N	3
5	11	5000000000	\N	4
6	11	5000000000	\N	5
7	11	5000000000	\N	6
8	11	5000000000	\N	7
9	11	5000000000	\N	8
10	11	5000000000	\N	9
11	11	5000000000	\N	10
12	11	5000000000	\N	11
13	11	5000000000	\N	12
14	11	5000000000	\N	13
15	11	5000000000	\N	14
16	11	5000000000	\N	15
17	11	5000000000	\N	16
18	11	5000000000	\N	17
19	11	5000000000	\N	18
20	11	5000000000	\N	19
21	11	5000000000	\N	20
22	11	5000000000	\N	21
23	11	5000000000	\N	22
24	11	5000000000	\N	23
25	11	5000000000	\N	24
26	11	5000000000	\N	25
27	11	5000000000	\N	26
28	11	5000000000	\N	27
29	11	5000000000	\N	28
30	11	5000000000	\N	29
31	11	5000000000	\N	30
32	11	5000000000	\N	31
33	11	5000000000	\N	32
34	11	5000000000	\N	33
35	11	5000000000	\N	34
36	11	5000000000	\N	35
37	11	5000000000	\N	36
38	11	5000000000	\N	37
39	11	5000000000	\N	38
40	11	5000000000	\N	39
41	11	5000000000	\N	40
42	11	5000000000	\N	41
43	11	5000000000	\N	42
44	11	5000000000	\N	43
45	11	5000000000	\N	44
46	11	5000000000	\N	45
47	11	5000000000	\N	46
48	11	5000000000	\N	47
49	11	5000000000	\N	48
50	11	5000000000	\N	49
51	11	5000000000	\N	50
52	11	5000000000	\N	51
53	11	5000000000	\N	52
54	11	5000000000	\N	53
55	11	5000000000	\N	54
56	11	5000000000	\N	55
57	11	5000000000	\N	56
58	11	5000000000	\N	57
59	11	5000000000	\N	58
60	11	5000000000	\N	59
61	11	5000000000	\N	60
62	11	5000000000	\N	61
63	11	5000000000	\N	62
64	11	5000000000	\N	63
65	11	5000000000	\N	64
66	11	5000000000	\N	65
67	11	5000000000	\N	66
68	11	5000000000	\N	67
69	11	5000000000	\N	68
70	11	5000000000	\N	69
71	11	5000000000	\N	70
72	11	5000000000	\N	71
73	11	5000000000	\N	72
74	11	5000000000	\N	73
75	11	5000000000	\N	74
76	11	5000000000	\N	75
77	11	5000000000	\N	76
78	11	5000000000	\N	77
79	11	5000000000	\N	78
80	11	5000000000	\N	79
81	11	5000000000	\N	80
82	11	5000000000	\N	81
83	11	5000000000	\N	82
84	11	5000000000	\N	83
85	11	5000000000	\N	84
86	11	5000000000	\N	85
87	11	5000000000	\N	86
88	11	5000000000	\N	87
89	11	5000000000	\N	88
90	11	5000000000	\N	89
91	11	5000000000	\N	90
92	11	5000000000	\N	91
93	11	5000000000	\N	92
94	11	5000000000	\N	93
95	11	5000000000	\N	94
96	11	5000000000	\N	95
97	11	5000000000	\N	96
98	11	5000000000	\N	97
99	11	5000000000	\N	98
100	11	5000000000	\N	99
101	11	5000000000	\N	100
102	11	5000000000	\N	101
103	11	5000000000	\N	102
104	11	5000000000	\N	103
105	11	5000000000	\N	104
106	11	5000000000	\N	105
107	11	5000000000	\N	106
108	11	5000000000	\N	107
109	11	5000000000	\N	108
110	11	5000000000	\N	109
111	11	5000000000	\N	110
112	11	5000000000	\N	111
113	11	5000000000	\N	112
114	11	5000000000	\N	113
115	11	5000000000	\N	114
116	11	5000000000	\N	115
117	11	5000000000	\N	116
118	11	5000000000	\N	117
119	11	5000000000	\N	118
120	11	5000000000	\N	119
121	11	5000000000	\N	120
122	11	5000000000	\N	121
123	11	5000000000	\N	122
124	11	5000000000	\N	123
125	11	5000000000	\N	124
126	11	5000000000	\N	125
127	11	5000000000	\N	126
128	11	5000000000	\N	127
129	11	5000000000	\N	128
130	11	5000000000	\N	129
131	11	5000000000	\N	130
132	11	5000000000	\N	131
133	11	5000000000	\N	132
134	11	5000000000	\N	133
135	11	5000000000	\N	134
136	11	5000000000	\N	135
137	11	5000000000	\N	136
138	11	5000000000	\N	137
139	11	5000000000	\N	138
140	11	5000000000	\N	139
141	11	5000000000	\N	140
142	11	5000000000	\N	141
143	11	5000000000	\N	142
144	11	5000000000	\N	143
145	11	5000000000	\N	144
146	11	5000000000	\N	145
147	11	5000000000	\N	146
148	11	5000000000	\N	147
149	11	5000000000	\N	148
150	11	5000000000	\N	149
151	11	5000000000	\N	150
152	11	5000000000	\N	151
153	11	5000000000	\N	152
154	11	5000000000	\N	153
155	11	5000000000	\N	154
156	11	5000000000	\N	155
157	11	5000000000	\N	156
158	11	5000000000	\N	157
159	11	5000000000	\N	158
160	11	5000000000	\N	159
161	11	5000000000	\N	160
162	11	5000000000	\N	161
163	11	5000000000	\N	162
164	11	5000000000	\N	163
165	11	5000000000	\N	164
166	11	5000000000	\N	165
167	11	5000000000	\N	166
168	11	5000000000	\N	167
169	11	5000000000	\N	168
170	11	5000000000	\N	169
171	11	5000000000	\N	170
172	11	5000000000	\N	171
173	11	5000000000	\N	172
174	11	5000000000	\N	173
175	11	5000000000	\N	174
176	11	5000000000	\N	175
177	11	5000000000	\N	176
178	11	5000000000	\N	177
179	11	5000000000	\N	178
180	11	5000000000	\N	179
181	11	5000000000	\N	180
182	11	5000000000	\N	181
183	11	5000000000	\N	182
184	11	5000000000	\N	183
185	11	5000000000	\N	184
186	11	5000000000	\N	185
187	11	5000000000	\N	186
188	11	5000000000	\N	187
189	11	5000000000	\N	188
190	11	5000000000	\N	189
191	11	5000000000	\N	190
192	11	5000000000	\N	191
193	11	5000000000	\N	192
194	11	5000000000	\N	193
195	11	5000000000	\N	194
196	11	5000000000	\N	195
197	11	5000000000	\N	196
198	11	5000000000	\N	197
199	11	5000000000	\N	198
200	11	5000000000	\N	199
201	11	5000000000	\N	200
202	11	5000000000	\N	201
203	11	5000000000	\N	202
204	11	5000000000	\N	203
205	11	5000000000	\N	204
206	11	5000000000	\N	205
207	11	5000000000	\N	206
208	11	5000000000	\N	207
209	11	5000000000	\N	208
210	11	5000000000	\N	209
211	11	5000000000	\N	210
212	11	5000000000	\N	211
213	11	5000000000	\N	212
214	11	5000000000	\N	213
215	11	5000000000	\N	214
216	11	5000000000	\N	215
217	11	5000000000	\N	216
218	11	5000000000	\N	217
219	11	5000000000	\N	218
220	11	5000000000	\N	219
221	11	5000000000	\N	220
222	11	5000000000	\N	221
223	11	5000000000	\N	222
224	11	5000000000	\N	223
225	11	5000000000	\N	224
226	11	5000000000	\N	225
227	11	5000000000	\N	226
228	11	5000000000	\N	227
229	11	5000000000	\N	228
230	11	5000000000	\N	229
231	11	5000000000	\N	230
232	11	5000000000	\N	231
233	11	5000000000	\N	232
234	11	5000000000	\N	233
235	11	5000000000	\N	234
236	11	5000000000	\N	235
237	11	5000000000	\N	236
238	11	5000000000	\N	237
239	11	5000000000	\N	238
240	11	5000000000	\N	239
241	11	5000000000	\N	240
242	11	5000000000	\N	241
243	11	5000000000	\N	242
244	11	5000000000	\N	243
245	11	5000000000	\N	244
246	11	5000000000	\N	245
247	11	5000000000	\N	246
248	11	5000000000	\N	247
249	11	5000000000	\N	248
250	11	5000000000	\N	249
251	11	5000000000	\N	250
252	11	5000000000	\N	251
253	11	5000000000	\N	252
254	11	5000000000	\N	253
255	11	5000000000	\N	254
256	11	5000000000	\N	255
257	11	5000000000	\N	256
258	11	5000000000	\N	257
259	11	5000000000	\N	258
260	11	5000000000	\N	259
261	11	5000000000	\N	260
262	11	5000000000	\N	261
263	11	5000000000	\N	262
264	11	5000000000	\N	263
265	11	5000000000	\N	264
266	11	5000000000	\N	265
267	11	5000000000	\N	266
268	11	5000000000	\N	267
269	11	5000000000	\N	268
270	11	5000000000	\N	269
271	11	5000000000	\N	270
272	11	5000000000	\N	271
273	11	5000000000	\N	272
274	11	5000000000	\N	273
275	11	5000000000	\N	274
276	11	5000000000	\N	275
277	11	5000000000	\N	276
278	11	5000000000	\N	277
279	11	5000000000	\N	278
280	11	5000000000	\N	279
281	11	5000000000	\N	280
282	11	5000000000	\N	281
283	11	5000000000	\N	282
284	11	5000000000	\N	283
285	11	5000000000	\N	284
286	11	5000000000	\N	285
287	11	5000000000	\N	286
288	11	5000000000	\N	287
289	11	5000000000	\N	288
290	11	5000000000	\N	289
291	11	5000000000	\N	290
292	11	5000000000	\N	291
293	11	5000000000	\N	292
294	11	5000000000	\N	293
295	11	5000000000	\N	294
296	11	5000000000	\N	295
297	11	5000000000	\N	296
298	11	5000000000	\N	297
299	11	5000000000	\N	298
300	11	5000000000	\N	299
301	11	5000000000	\N	300
302	11	5000000000	\N	301
303	11	5000000000	\N	302
304	11	5000000000	\N	303
305	11	5000000000	\N	304
306	11	5000000000	\N	305
307	11	5000000000	\N	306
308	11	5000000000	\N	307
309	11	5000000000	\N	308
310	11	5000000000	\N	309
311	11	5000000000	\N	310
312	11	5000000000	\N	311
313	11	5000000000	\N	312
314	11	5000000000	\N	313
315	11	5000000000	\N	314
316	11	5000000000	\N	315
317	11	5000000000	\N	316
318	11	5000000000	\N	317
319	11	5000000000	\N	318
320	11	5000000000	\N	319
321	11	5000000000	\N	320
322	11	5000000000	\N	321
323	11	5000000000	\N	322
324	11	5000000000	\N	323
325	11	5000000000	\N	324
326	11	5000000000	\N	325
327	11	5000000000	\N	326
328	11	5000000000	\N	327
329	11	5000000000	\N	328
330	11	5000000000	\N	329
331	11	5000000000	\N	330
332	11	5000000000	\N	331
333	11	5000000000	\N	332
334	11	5000000000	\N	333
335	11	5000000000	\N	334
336	11	5000000000	\N	335
337	11	5000000000	\N	336
338	11	5000000000	\N	337
339	11	5000000000	\N	338
340	11	5000000000	\N	339
341	11	5000000000	\N	340
342	11	5000000000	\N	341
343	11	5000000000	\N	342
344	11	5000000000	\N	343
345	11	5000000000	\N	344
346	11	5000000000	\N	345
347	11	5000000000	\N	346
348	11	5000000000	\N	347
349	11	5000000000	\N	348
350	11	5000000000	\N	349
351	11	5000000000	\N	350
352	11	5000000000	\N	351
353	11	5000000000	\N	352
354	11	5000000000	\N	353
355	11	5000000000	\N	354
356	11	5000000000	\N	355
357	11	5000000000	\N	356
358	11	5000000000	\N	357
359	11	5000000000	\N	358
360	11	5000000000	\N	359
361	11	5000000000	\N	360
362	11	5000000000	\N	361
363	11	5000000000	\N	362
364	11	5000000000	\N	363
365	11	5000000000	\N	364
366	11	5000000000	\N	365
367	11	5000000000	\N	366
368	11	5000000000	\N	367
369	11	5000000000	\N	368
370	11	5000000000	\N	369
371	11	5000000000	\N	370
372	11	5000000000	\N	371
373	11	5000000000	\N	372
374	11	5000000000	\N	373
375	11	5000000000	\N	374
\.


--
-- Data for Name: zkapp_field; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.zkapp_field (id, field) FROM stdin;
1	0
2	1
3	2
4	3
5	4
6	5
7	6
8	7
9	8
10	9
11	10
12	11
13	12
14	13
15	14
16	15
17	16
18	17
19	18
20	19
21	20
22	21
23	22
24	23
25	24
26	25
27	26
28	27
29	28
30	29
31	30
32	31
33	32
34	33
35	34
36	35
37	36
38	37
39	38
40	39
41	40
42	41
43	42
44	43
45	44
46	45
47	46
48	47
49	48
50	49
51	50
52	51
53	52
54	53
55	54
56	55
57	56
58	57
59	58
60	59
61	60
62	61
63	62
64	63
65	64
66	65
67	66
68	67
69	68
70	69
71	70
72	71
73	72
74	73
75	74
76	75
77	76
78	77
79	78
80	79
81	80
82	81
83	82
84	83
85	84
86	85
87	86
88	87
89	88
90	89
91	90
92	91
93	92
94	93
95	94
96	95
97	96
98	97
99	98
100	99
101	100
102	101
103	102
104	103
105	104
106	105
107	106
108	107
109	108
110	109
111	110
112	111
113	112
114	113
115	114
116	115
117	116
118	117
119	118
120	119
121	120
122	121
123	122
124	123
125	124
126	125
127	126
128	127
129	128
130	129
131	130
132	131
133	132
134	133
135	134
136	135
137	136
138	137
139	138
140	139
141	140
142	141
143	142
144	143
145	144
146	145
147	146
148	147
149	148
150	149
151	150
152	151
153	152
154	153
155	154
156	155
157	156
158	157
159	158
160	159
161	160
162	161
163	162
164	163
165	164
166	165
167	166
168	167
169	168
170	169
171	170
172	171
173	172
174	173
175	174
176	175
177	176
178	177
179	178
180	179
181	180
182	181
183	182
184	183
185	184
186	185
187	186
\.


--
-- Data for Name: zkapp_field_array; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.zkapp_field_array (id, element_ids) FROM stdin;
\.


--
-- Data for Name: zkapp_global_slot_bounds; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.zkapp_global_slot_bounds (id, global_slot_lower_bound, global_slot_upper_bound) FROM stdin;
\.


--
-- Data for Name: zkapp_length_bounds; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.zkapp_length_bounds (id, length_lower_bound, length_upper_bound) FROM stdin;
\.


--
-- Data for Name: zkapp_network_precondition; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.zkapp_network_precondition (id, snarked_ledger_hash_id, blockchain_length_id, min_window_density_id, total_currency_id, global_slot_since_genesis, staking_epoch_data_id, next_epoch_data_id) FROM stdin;
1	\N	\N	\N	\N	\N	1	1
\.


--
-- Data for Name: zkapp_nonce_bounds; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.zkapp_nonce_bounds (id, nonce_lower_bound, nonce_upper_bound) FROM stdin;
1	1	1
2	2	2
3	3	3
4	4	4
5	5	5
6	6	6
7	7	7
8	8	8
9	9	9
10	10	10
11	11	11
12	12	12
13	13	13
14	14	14
15	15	15
16	16	16
17	17	17
18	18	18
19	19	19
20	20	20
21	21	21
22	22	22
23	23	23
24	24	24
25	25	25
26	26	26
27	27	27
28	28	28
29	29	29
30	30	30
31	31	31
32	32	32
33	33	33
34	34	34
35	35	35
36	36	36
37	37	37
38	38	38
39	39	39
40	40	40
41	41	41
42	42	42
43	43	43
44	44	44
45	45	45
46	46	46
47	47	47
48	48	48
49	49	49
50	50	50
51	51	51
52	52	52
53	53	53
54	54	54
55	55	55
56	56	56
57	57	57
58	58	58
59	59	59
60	60	60
61	61	61
62	62	62
63	63	63
64	64	64
65	65	65
66	66	66
67	67	67
68	68	68
69	69	69
70	70	70
71	71	71
72	72	72
73	73	73
74	74	74
75	75	75
76	76	76
77	77	77
78	78	78
79	79	79
80	80	80
81	81	81
82	82	82
83	83	83
84	84	84
85	85	85
86	86	86
87	87	87
88	88	88
89	89	89
90	90	90
91	91	91
92	92	92
93	93	93
94	94	94
95	95	95
96	96	96
97	97	97
98	98	98
99	99	99
100	100	100
101	101	101
102	102	102
103	103	103
104	104	104
105	105	105
106	106	106
107	107	107
108	108	108
109	109	109
110	110	110
111	111	111
112	112	112
113	113	113
114	114	114
115	115	115
116	116	116
117	117	117
118	118	118
119	119	119
120	120	120
121	121	121
122	122	122
123	123	123
124	124	124
125	125	125
126	126	126
127	127	127
128	128	128
129	129	129
130	130	130
131	131	131
132	132	132
133	133	133
134	134	134
135	135	135
136	136	136
137	137	137
138	138	138
139	139	139
140	140	140
141	141	141
142	142	142
143	143	143
144	144	144
145	145	145
146	146	146
147	147	147
148	148	148
149	149	149
150	150	150
151	151	151
152	152	152
153	153	153
154	154	154
155	155	155
156	156	156
157	157	157
158	158	158
159	159	159
185	185	185
186	186	186
187	187	187
160	160	160
161	161	161
162	162	162
163	163	163
164	164	164
165	165	165
166	166	166
167	167	167
168	168	168
169	169	169
170	170	170
171	171	171
172	172	172
173	173	173
174	174	174
175	175	175
176	176	176
177	177	177
178	178	178
179	179	179
180	180	180
181	181	181
182	182	182
183	183	183
184	184	184
188	188	188
\.


--
-- Data for Name: zkapp_permissions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.zkapp_permissions (id, edit_state, send, receive, access, set_delegate, set_permissions, set_verification_key_auth, set_verification_key_txn_version, set_zkapp_uri, edit_action_state, set_token_symbol, increment_nonce, set_voting_for, set_timing) FROM stdin;
1	signature	signature	none	none	signature	signature	signature	3	signature	signature	signature	signature	signature	signature
\.


--
-- Data for Name: zkapp_states; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.zkapp_states (id, element0, element1, element2, element3, element4, element5, element6, element7) FROM stdin;
\.


--
-- Data for Name: zkapp_states_nullable; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.zkapp_states_nullable (id, element0, element1, element2, element3, element4, element5, element6, element7) FROM stdin;
1	\N	\N	\N	\N	\N	\N	\N	\N
2	1	\N	\N	\N	\N	\N	\N	\N
3	2	\N	\N	\N	\N	\N	\N	\N
4	3	\N	\N	\N	\N	\N	\N	\N
5	4	\N	\N	\N	\N	\N	\N	\N
6	5	\N	\N	\N	\N	\N	\N	\N
7	6	\N	\N	\N	\N	\N	\N	\N
8	7	\N	\N	\N	\N	\N	\N	\N
9	8	\N	\N	\N	\N	\N	\N	\N
10	9	\N	\N	\N	\N	\N	\N	\N
11	10	\N	\N	\N	\N	\N	\N	\N
12	11	\N	\N	\N	\N	\N	\N	\N
13	12	\N	\N	\N	\N	\N	\N	\N
14	13	\N	\N	\N	\N	\N	\N	\N
15	14	\N	\N	\N	\N	\N	\N	\N
16	15	\N	\N	\N	\N	\N	\N	\N
17	16	\N	\N	\N	\N	\N	\N	\N
18	17	\N	\N	\N	\N	\N	\N	\N
19	18	\N	\N	\N	\N	\N	\N	\N
20	19	\N	\N	\N	\N	\N	\N	\N
21	20	\N	\N	\N	\N	\N	\N	\N
22	21	\N	\N	\N	\N	\N	\N	\N
23	22	\N	\N	\N	\N	\N	\N	\N
24	23	\N	\N	\N	\N	\N	\N	\N
25	24	\N	\N	\N	\N	\N	\N	\N
26	25	\N	\N	\N	\N	\N	\N	\N
27	26	\N	\N	\N	\N	\N	\N	\N
28	27	\N	\N	\N	\N	\N	\N	\N
29	28	\N	\N	\N	\N	\N	\N	\N
30	29	\N	\N	\N	\N	\N	\N	\N
31	30	\N	\N	\N	\N	\N	\N	\N
32	31	\N	\N	\N	\N	\N	\N	\N
33	32	\N	\N	\N	\N	\N	\N	\N
34	33	\N	\N	\N	\N	\N	\N	\N
35	34	\N	\N	\N	\N	\N	\N	\N
36	35	\N	\N	\N	\N	\N	\N	\N
37	36	\N	\N	\N	\N	\N	\N	\N
38	37	\N	\N	\N	\N	\N	\N	\N
39	38	\N	\N	\N	\N	\N	\N	\N
40	39	\N	\N	\N	\N	\N	\N	\N
41	40	\N	\N	\N	\N	\N	\N	\N
42	41	\N	\N	\N	\N	\N	\N	\N
43	42	\N	\N	\N	\N	\N	\N	\N
44	43	\N	\N	\N	\N	\N	\N	\N
45	44	\N	\N	\N	\N	\N	\N	\N
46	45	\N	\N	\N	\N	\N	\N	\N
47	46	\N	\N	\N	\N	\N	\N	\N
48	47	\N	\N	\N	\N	\N	\N	\N
49	48	\N	\N	\N	\N	\N	\N	\N
50	49	\N	\N	\N	\N	\N	\N	\N
51	50	\N	\N	\N	\N	\N	\N	\N
52	51	\N	\N	\N	\N	\N	\N	\N
53	52	\N	\N	\N	\N	\N	\N	\N
54	53	\N	\N	\N	\N	\N	\N	\N
55	54	\N	\N	\N	\N	\N	\N	\N
56	55	\N	\N	\N	\N	\N	\N	\N
57	56	\N	\N	\N	\N	\N	\N	\N
58	57	\N	\N	\N	\N	\N	\N	\N
59	58	\N	\N	\N	\N	\N	\N	\N
60	59	\N	\N	\N	\N	\N	\N	\N
61	60	\N	\N	\N	\N	\N	\N	\N
62	61	\N	\N	\N	\N	\N	\N	\N
63	62	\N	\N	\N	\N	\N	\N	\N
64	63	\N	\N	\N	\N	\N	\N	\N
65	64	\N	\N	\N	\N	\N	\N	\N
66	65	\N	\N	\N	\N	\N	\N	\N
67	66	\N	\N	\N	\N	\N	\N	\N
68	67	\N	\N	\N	\N	\N	\N	\N
69	68	\N	\N	\N	\N	\N	\N	\N
70	69	\N	\N	\N	\N	\N	\N	\N
71	70	\N	\N	\N	\N	\N	\N	\N
72	71	\N	\N	\N	\N	\N	\N	\N
73	72	\N	\N	\N	\N	\N	\N	\N
74	73	\N	\N	\N	\N	\N	\N	\N
75	74	\N	\N	\N	\N	\N	\N	\N
76	75	\N	\N	\N	\N	\N	\N	\N
77	76	\N	\N	\N	\N	\N	\N	\N
78	77	\N	\N	\N	\N	\N	\N	\N
79	78	\N	\N	\N	\N	\N	\N	\N
80	79	\N	\N	\N	\N	\N	\N	\N
81	80	\N	\N	\N	\N	\N	\N	\N
82	81	\N	\N	\N	\N	\N	\N	\N
83	82	\N	\N	\N	\N	\N	\N	\N
84	83	\N	\N	\N	\N	\N	\N	\N
85	84	\N	\N	\N	\N	\N	\N	\N
86	85	\N	\N	\N	\N	\N	\N	\N
87	86	\N	\N	\N	\N	\N	\N	\N
88	87	\N	\N	\N	\N	\N	\N	\N
89	88	\N	\N	\N	\N	\N	\N	\N
90	89	\N	\N	\N	\N	\N	\N	\N
91	90	\N	\N	\N	\N	\N	\N	\N
92	91	\N	\N	\N	\N	\N	\N	\N
93	92	\N	\N	\N	\N	\N	\N	\N
94	93	\N	\N	\N	\N	\N	\N	\N
95	94	\N	\N	\N	\N	\N	\N	\N
96	95	\N	\N	\N	\N	\N	\N	\N
97	96	\N	\N	\N	\N	\N	\N	\N
98	97	\N	\N	\N	\N	\N	\N	\N
99	98	\N	\N	\N	\N	\N	\N	\N
100	99	\N	\N	\N	\N	\N	\N	\N
101	100	\N	\N	\N	\N	\N	\N	\N
102	101	\N	\N	\N	\N	\N	\N	\N
103	102	\N	\N	\N	\N	\N	\N	\N
104	103	\N	\N	\N	\N	\N	\N	\N
105	104	\N	\N	\N	\N	\N	\N	\N
106	105	\N	\N	\N	\N	\N	\N	\N
107	106	\N	\N	\N	\N	\N	\N	\N
108	107	\N	\N	\N	\N	\N	\N	\N
109	108	\N	\N	\N	\N	\N	\N	\N
110	109	\N	\N	\N	\N	\N	\N	\N
111	110	\N	\N	\N	\N	\N	\N	\N
112	111	\N	\N	\N	\N	\N	\N	\N
113	112	\N	\N	\N	\N	\N	\N	\N
114	113	\N	\N	\N	\N	\N	\N	\N
115	114	\N	\N	\N	\N	\N	\N	\N
116	115	\N	\N	\N	\N	\N	\N	\N
117	116	\N	\N	\N	\N	\N	\N	\N
118	117	\N	\N	\N	\N	\N	\N	\N
119	118	\N	\N	\N	\N	\N	\N	\N
120	119	\N	\N	\N	\N	\N	\N	\N
121	120	\N	\N	\N	\N	\N	\N	\N
122	121	\N	\N	\N	\N	\N	\N	\N
123	122	\N	\N	\N	\N	\N	\N	\N
124	123	\N	\N	\N	\N	\N	\N	\N
125	124	\N	\N	\N	\N	\N	\N	\N
126	125	\N	\N	\N	\N	\N	\N	\N
127	126	\N	\N	\N	\N	\N	\N	\N
128	127	\N	\N	\N	\N	\N	\N	\N
129	128	\N	\N	\N	\N	\N	\N	\N
130	129	\N	\N	\N	\N	\N	\N	\N
131	130	\N	\N	\N	\N	\N	\N	\N
132	131	\N	\N	\N	\N	\N	\N	\N
133	132	\N	\N	\N	\N	\N	\N	\N
134	133	\N	\N	\N	\N	\N	\N	\N
135	134	\N	\N	\N	\N	\N	\N	\N
136	135	\N	\N	\N	\N	\N	\N	\N
137	136	\N	\N	\N	\N	\N	\N	\N
138	137	\N	\N	\N	\N	\N	\N	\N
139	138	\N	\N	\N	\N	\N	\N	\N
140	139	\N	\N	\N	\N	\N	\N	\N
141	140	\N	\N	\N	\N	\N	\N	\N
142	141	\N	\N	\N	\N	\N	\N	\N
143	142	\N	\N	\N	\N	\N	\N	\N
144	143	\N	\N	\N	\N	\N	\N	\N
145	144	\N	\N	\N	\N	\N	\N	\N
146	145	\N	\N	\N	\N	\N	\N	\N
147	146	\N	\N	\N	\N	\N	\N	\N
148	147	\N	\N	\N	\N	\N	\N	\N
149	148	\N	\N	\N	\N	\N	\N	\N
150	149	\N	\N	\N	\N	\N	\N	\N
151	150	\N	\N	\N	\N	\N	\N	\N
152	151	\N	\N	\N	\N	\N	\N	\N
153	152	\N	\N	\N	\N	\N	\N	\N
154	153	\N	\N	\N	\N	\N	\N	\N
155	154	\N	\N	\N	\N	\N	\N	\N
156	155	\N	\N	\N	\N	\N	\N	\N
157	156	\N	\N	\N	\N	\N	\N	\N
158	157	\N	\N	\N	\N	\N	\N	\N
159	158	\N	\N	\N	\N	\N	\N	\N
160	159	\N	\N	\N	\N	\N	\N	\N
161	160	\N	\N	\N	\N	\N	\N	\N
162	161	\N	\N	\N	\N	\N	\N	\N
163	162	\N	\N	\N	\N	\N	\N	\N
164	163	\N	\N	\N	\N	\N	\N	\N
165	164	\N	\N	\N	\N	\N	\N	\N
166	165	\N	\N	\N	\N	\N	\N	\N
167	166	\N	\N	\N	\N	\N	\N	\N
168	167	\N	\N	\N	\N	\N	\N	\N
169	168	\N	\N	\N	\N	\N	\N	\N
170	169	\N	\N	\N	\N	\N	\N	\N
171	170	\N	\N	\N	\N	\N	\N	\N
172	171	\N	\N	\N	\N	\N	\N	\N
173	172	\N	\N	\N	\N	\N	\N	\N
174	173	\N	\N	\N	\N	\N	\N	\N
175	174	\N	\N	\N	\N	\N	\N	\N
176	175	\N	\N	\N	\N	\N	\N	\N
177	176	\N	\N	\N	\N	\N	\N	\N
178	177	\N	\N	\N	\N	\N	\N	\N
179	178	\N	\N	\N	\N	\N	\N	\N
180	179	\N	\N	\N	\N	\N	\N	\N
181	180	\N	\N	\N	\N	\N	\N	\N
182	181	\N	\N	\N	\N	\N	\N	\N
183	182	\N	\N	\N	\N	\N	\N	\N
184	183	\N	\N	\N	\N	\N	\N	\N
185	184	\N	\N	\N	\N	\N	\N	\N
186	185	\N	\N	\N	\N	\N	\N	\N
188	187	\N	\N	\N	\N	\N	\N	\N
187	186	\N	\N	\N	\N	\N	\N	\N
\.


--
-- Data for Name: zkapp_timing_info; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.zkapp_timing_info (id, initial_minimum_balance, cliff_time, cliff_amount, vesting_period, vesting_increment) FROM stdin;
\.


--
-- Data for Name: zkapp_token_id_bounds; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.zkapp_token_id_bounds (id, token_id_lower_bound, token_id_upper_bound) FROM stdin;
\.


--
-- Data for Name: zkapp_updates; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.zkapp_updates (id, app_state_id, delegate_id, verification_key_id, permissions_id, zkapp_uri_id, token_symbol_id, timing_id, voting_for_id) FROM stdin;
1	1	\N	\N	\N	\N	\N	\N	\N
2	1	\N	1	1	\N	\N	\N	\N
3	2	\N	\N	\N	\N	\N	\N	\N
4	3	\N	\N	\N	\N	\N	\N	\N
5	4	\N	\N	\N	\N	\N	\N	\N
6	5	\N	\N	\N	\N	\N	\N	\N
7	6	\N	\N	\N	\N	\N	\N	\N
8	7	\N	\N	\N	\N	\N	\N	\N
9	8	\N	\N	\N	\N	\N	\N	\N
10	9	\N	\N	\N	\N	\N	\N	\N
11	10	\N	\N	\N	\N	\N	\N	\N
12	11	\N	\N	\N	\N	\N	\N	\N
13	12	\N	\N	\N	\N	\N	\N	\N
14	13	\N	\N	\N	\N	\N	\N	\N
15	14	\N	\N	\N	\N	\N	\N	\N
16	15	\N	\N	\N	\N	\N	\N	\N
17	16	\N	\N	\N	\N	\N	\N	\N
18	17	\N	\N	\N	\N	\N	\N	\N
19	18	\N	\N	\N	\N	\N	\N	\N
20	19	\N	\N	\N	\N	\N	\N	\N
21	20	\N	\N	\N	\N	\N	\N	\N
22	21	\N	\N	\N	\N	\N	\N	\N
23	22	\N	\N	\N	\N	\N	\N	\N
24	23	\N	\N	\N	\N	\N	\N	\N
25	24	\N	\N	\N	\N	\N	\N	\N
26	25	\N	\N	\N	\N	\N	\N	\N
27	26	\N	\N	\N	\N	\N	\N	\N
28	27	\N	\N	\N	\N	\N	\N	\N
29	28	\N	\N	\N	\N	\N	\N	\N
30	29	\N	\N	\N	\N	\N	\N	\N
31	30	\N	\N	\N	\N	\N	\N	\N
32	31	\N	\N	\N	\N	\N	\N	\N
33	32	\N	\N	\N	\N	\N	\N	\N
34	33	\N	\N	\N	\N	\N	\N	\N
35	34	\N	\N	\N	\N	\N	\N	\N
36	35	\N	\N	\N	\N	\N	\N	\N
37	36	\N	\N	\N	\N	\N	\N	\N
38	37	\N	\N	\N	\N	\N	\N	\N
39	38	\N	\N	\N	\N	\N	\N	\N
40	39	\N	\N	\N	\N	\N	\N	\N
41	40	\N	\N	\N	\N	\N	\N	\N
42	41	\N	\N	\N	\N	\N	\N	\N
43	42	\N	\N	\N	\N	\N	\N	\N
44	43	\N	\N	\N	\N	\N	\N	\N
45	44	\N	\N	\N	\N	\N	\N	\N
46	45	\N	\N	\N	\N	\N	\N	\N
47	46	\N	\N	\N	\N	\N	\N	\N
48	47	\N	\N	\N	\N	\N	\N	\N
49	48	\N	\N	\N	\N	\N	\N	\N
50	49	\N	\N	\N	\N	\N	\N	\N
51	50	\N	\N	\N	\N	\N	\N	\N
52	51	\N	\N	\N	\N	\N	\N	\N
53	52	\N	\N	\N	\N	\N	\N	\N
54	53	\N	\N	\N	\N	\N	\N	\N
55	54	\N	\N	\N	\N	\N	\N	\N
56	55	\N	\N	\N	\N	\N	\N	\N
57	56	\N	\N	\N	\N	\N	\N	\N
58	57	\N	\N	\N	\N	\N	\N	\N
59	58	\N	\N	\N	\N	\N	\N	\N
60	59	\N	\N	\N	\N	\N	\N	\N
61	60	\N	\N	\N	\N	\N	\N	\N
62	61	\N	\N	\N	\N	\N	\N	\N
63	62	\N	\N	\N	\N	\N	\N	\N
64	63	\N	\N	\N	\N	\N	\N	\N
65	64	\N	\N	\N	\N	\N	\N	\N
66	65	\N	\N	\N	\N	\N	\N	\N
67	66	\N	\N	\N	\N	\N	\N	\N
68	67	\N	\N	\N	\N	\N	\N	\N
69	68	\N	\N	\N	\N	\N	\N	\N
70	69	\N	\N	\N	\N	\N	\N	\N
71	70	\N	\N	\N	\N	\N	\N	\N
72	71	\N	\N	\N	\N	\N	\N	\N
73	72	\N	\N	\N	\N	\N	\N	\N
74	73	\N	\N	\N	\N	\N	\N	\N
75	74	\N	\N	\N	\N	\N	\N	\N
76	75	\N	\N	\N	\N	\N	\N	\N
77	76	\N	\N	\N	\N	\N	\N	\N
78	77	\N	\N	\N	\N	\N	\N	\N
79	78	\N	\N	\N	\N	\N	\N	\N
80	79	\N	\N	\N	\N	\N	\N	\N
81	80	\N	\N	\N	\N	\N	\N	\N
82	81	\N	\N	\N	\N	\N	\N	\N
83	82	\N	\N	\N	\N	\N	\N	\N
84	83	\N	\N	\N	\N	\N	\N	\N
85	84	\N	\N	\N	\N	\N	\N	\N
86	85	\N	\N	\N	\N	\N	\N	\N
87	86	\N	\N	\N	\N	\N	\N	\N
88	87	\N	\N	\N	\N	\N	\N	\N
89	88	\N	\N	\N	\N	\N	\N	\N
90	89	\N	\N	\N	\N	\N	\N	\N
91	90	\N	\N	\N	\N	\N	\N	\N
92	91	\N	\N	\N	\N	\N	\N	\N
93	92	\N	\N	\N	\N	\N	\N	\N
94	93	\N	\N	\N	\N	\N	\N	\N
95	94	\N	\N	\N	\N	\N	\N	\N
96	95	\N	\N	\N	\N	\N	\N	\N
97	96	\N	\N	\N	\N	\N	\N	\N
98	97	\N	\N	\N	\N	\N	\N	\N
99	98	\N	\N	\N	\N	\N	\N	\N
100	99	\N	\N	\N	\N	\N	\N	\N
101	100	\N	\N	\N	\N	\N	\N	\N
102	101	\N	\N	\N	\N	\N	\N	\N
103	102	\N	\N	\N	\N	\N	\N	\N
104	103	\N	\N	\N	\N	\N	\N	\N
105	104	\N	\N	\N	\N	\N	\N	\N
106	105	\N	\N	\N	\N	\N	\N	\N
107	106	\N	\N	\N	\N	\N	\N	\N
108	107	\N	\N	\N	\N	\N	\N	\N
109	108	\N	\N	\N	\N	\N	\N	\N
110	109	\N	\N	\N	\N	\N	\N	\N
111	110	\N	\N	\N	\N	\N	\N	\N
112	111	\N	\N	\N	\N	\N	\N	\N
113	112	\N	\N	\N	\N	\N	\N	\N
114	113	\N	\N	\N	\N	\N	\N	\N
115	114	\N	\N	\N	\N	\N	\N	\N
116	115	\N	\N	\N	\N	\N	\N	\N
117	116	\N	\N	\N	\N	\N	\N	\N
118	117	\N	\N	\N	\N	\N	\N	\N
119	118	\N	\N	\N	\N	\N	\N	\N
120	119	\N	\N	\N	\N	\N	\N	\N
121	120	\N	\N	\N	\N	\N	\N	\N
122	121	\N	\N	\N	\N	\N	\N	\N
123	122	\N	\N	\N	\N	\N	\N	\N
124	123	\N	\N	\N	\N	\N	\N	\N
125	124	\N	\N	\N	\N	\N	\N	\N
126	125	\N	\N	\N	\N	\N	\N	\N
127	126	\N	\N	\N	\N	\N	\N	\N
128	127	\N	\N	\N	\N	\N	\N	\N
129	128	\N	\N	\N	\N	\N	\N	\N
130	129	\N	\N	\N	\N	\N	\N	\N
131	130	\N	\N	\N	\N	\N	\N	\N
132	131	\N	\N	\N	\N	\N	\N	\N
133	132	\N	\N	\N	\N	\N	\N	\N
134	133	\N	\N	\N	\N	\N	\N	\N
135	134	\N	\N	\N	\N	\N	\N	\N
136	135	\N	\N	\N	\N	\N	\N	\N
137	136	\N	\N	\N	\N	\N	\N	\N
138	137	\N	\N	\N	\N	\N	\N	\N
139	138	\N	\N	\N	\N	\N	\N	\N
140	139	\N	\N	\N	\N	\N	\N	\N
141	140	\N	\N	\N	\N	\N	\N	\N
142	141	\N	\N	\N	\N	\N	\N	\N
143	142	\N	\N	\N	\N	\N	\N	\N
144	143	\N	\N	\N	\N	\N	\N	\N
145	144	\N	\N	\N	\N	\N	\N	\N
146	145	\N	\N	\N	\N	\N	\N	\N
147	146	\N	\N	\N	\N	\N	\N	\N
148	147	\N	\N	\N	\N	\N	\N	\N
149	148	\N	\N	\N	\N	\N	\N	\N
150	149	\N	\N	\N	\N	\N	\N	\N
151	150	\N	\N	\N	\N	\N	\N	\N
152	151	\N	\N	\N	\N	\N	\N	\N
153	152	\N	\N	\N	\N	\N	\N	\N
154	153	\N	\N	\N	\N	\N	\N	\N
155	154	\N	\N	\N	\N	\N	\N	\N
156	155	\N	\N	\N	\N	\N	\N	\N
157	156	\N	\N	\N	\N	\N	\N	\N
158	157	\N	\N	\N	\N	\N	\N	\N
159	158	\N	\N	\N	\N	\N	\N	\N
160	159	\N	\N	\N	\N	\N	\N	\N
161	160	\N	\N	\N	\N	\N	\N	\N
162	161	\N	\N	\N	\N	\N	\N	\N
163	162	\N	\N	\N	\N	\N	\N	\N
164	163	\N	\N	\N	\N	\N	\N	\N
165	164	\N	\N	\N	\N	\N	\N	\N
166	165	\N	\N	\N	\N	\N	\N	\N
167	166	\N	\N	\N	\N	\N	\N	\N
168	167	\N	\N	\N	\N	\N	\N	\N
169	168	\N	\N	\N	\N	\N	\N	\N
170	169	\N	\N	\N	\N	\N	\N	\N
171	170	\N	\N	\N	\N	\N	\N	\N
172	171	\N	\N	\N	\N	\N	\N	\N
173	172	\N	\N	\N	\N	\N	\N	\N
174	173	\N	\N	\N	\N	\N	\N	\N
175	174	\N	\N	\N	\N	\N	\N	\N
176	175	\N	\N	\N	\N	\N	\N	\N
177	176	\N	\N	\N	\N	\N	\N	\N
178	177	\N	\N	\N	\N	\N	\N	\N
179	178	\N	\N	\N	\N	\N	\N	\N
180	179	\N	\N	\N	\N	\N	\N	\N
181	180	\N	\N	\N	\N	\N	\N	\N
182	181	\N	\N	\N	\N	\N	\N	\N
183	182	\N	\N	\N	\N	\N	\N	\N
184	183	\N	\N	\N	\N	\N	\N	\N
185	184	\N	\N	\N	\N	\N	\N	\N
186	185	\N	\N	\N	\N	\N	\N	\N
187	186	\N	\N	\N	\N	\N	\N	\N
189	188	\N	\N	\N	\N	\N	\N	\N
188	187	\N	\N	\N	\N	\N	\N	\N
\.


--
-- Data for Name: zkapp_uris; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.zkapp_uris (id, value) FROM stdin;
\.


--
-- Data for Name: zkapp_verification_key_hashes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.zkapp_verification_key_hashes (id, value) FROM stdin;
1	330109536550383627416201330124291596191867681867265169258470531313815097966
\.


--
-- Data for Name: zkapp_verification_keys; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.zkapp_verification_keys (id, verification_key, hash_id) FROM stdin;
1	AACcenc1yLdGBm4xtUN1dpModROI0zovuy5rz2a94vfdBgG1C75BqviU4vw6JUYqODF8n9ivtfeU5s9PcpEGIP0htil2mfx8v2DB5RuNQ7VxJWkha0TSnJJsOl0FxhjldBbOY3tUZzZxHpPhHOKHz/ZAXRYFIsf2x+7boXC0iPurEX9VcnaJIq+YxxmnSfeYYxHkjxO9lrDBqjXzd5AHMnYyjTPC69B+5In7AOGS6R+A/g3/aR/MKDa4eDVrnsF9Oy/Ay8ahic2sSAZvtn08MdRyk/jm2cLlJbeAAad6Xyz/H9l7JrkbVwDMMPxvHVHs27tNoJCzIlrRzB7pg3ju9aQOu4h3thDr+WSgFQWKvcRPeL7f3TFjIr8WZ2457RgMcTwXwORKbqJCcyKVNOE+FlNwVkOKER+WIpC0OlgGuayPFwQQkbb91jaRlJvahfwkbF2+AJmDnavmNpop9T+/Xak1adXIrsRPeOjC+qIKxIbGimoMOoYzYlevKA80LnJ7HC0IxR+yNLvoSYxDDPNRD+OCCxk5lM2h8IDUiCNWH4FZNJ+doiigKjyZlu/xZ7jHcX7qibu/32KFTX85DPSkQM8dABl309Ne9XzDAjA7rvef7vicw7KNgt56kWcEUki0o3M1yfbB8UxOSuOP07pw5+vrNHINMmJAuEKtNPwa5HvXBA4KR89XcqLS/NP7lwCEej/L8q8R7sKGMCXmgFYluWH4JBSPDgvMxScfjFS33oBNb7po8cLnAORzohXoYTSgztklD0mKn6EegLbkLtwwr9ObsLz3m7fp/3wkNWFRkY5xzSZN1VybbQbmpyQNCpxd/kdDsvlszqlowkyC8HnKbhnvE0Mrz3ZIk4vSs/UGBSXAoESFCFCPcTq11TCOhE5rumMJErv5LusDHJgrBtQUMibLU9A1YbF7SPDAR2QZd0yx3wZoHstfG3lbbtZcnaUabgu8tRdZiwRfX+rV+EBDCClOIpZn5V2SIpPpehhCpEBgDKUT0y2dgMO53Wc7OBDUFfkNX+JGhhD4fuA7IGFdIdthrwcbckBm0CBsRcVLlp+qlQ7a7ryGkxT8Bm3kEjVuRCYk6CbAfdT5lbKbQ7xYK4E2PfzQ2lMDwwuxRP+K2iQgP8UoGIBiUYI0lRvphhDkbCweEg0Owjz1pTUF/uiiMyVPsAyeoyh5fvmUgaNBkf5Hjh0xOGUbSHzawovjubcH7qWjIZoghZJ16QB1c0ryiAfHB48OHhs2p/JZWz8Dp7kfcPkeg2Of2NbupJlNVMLIH4IGWaPAscBRkZ+F4oLqOhJ5as7fAzzU8PQdeZi0YgssGDJVmNEHP61I16KZNcxQqR0EUVwhyMmYmpVjvtfhHi/6IxY/aPPEtcmsYEuy/JUaIuM0ZvnPNyB2E2Ckec+wJmooYjWXxYrXimjXWgv3IUGOiLDuQ0uGmrG5Bk+gyhZ5bhlVmlVsP8zA+xuHylyiww/Lercce7cq0YA5PtYS3ge9IDYwXckBUXb5ikD3alrrv5mvMu6itB7ix2f8lbiF9Fkmc4Bk2ycIWXJDCuBN+2sTFqzUeoT6xY8XWaOcnDvqOgSm/CCSv38umiOE2jEpsKYxhRc6W70UJkrzd3hr2DiSF1I2B+krpUVK1GeOdCLC5sl7YPzk+pF8183uI9wse6UTlqIiroKqsggzLBy/IjAfxS0BxFy5zywXqp+NogFkoTEJmR5MaqOkPfap+OsD1lGScY6+X4WW/HqCWrmA3ZTqDGngQMTGXLCtl6IS/cQpihS1NRbNqOtKTaCB9COQu0oz6RivBlywuaj3MKUdmbQ2gVDj+SGQItCNaXawyPSBjB9VT+68SoJVySQsYPCuEZCb0V/40n/a7RAbyrnNjP+2HwD7p27Pl1RSzqq35xiPdnycD1UeEPLpx/ON65mYCkn+KLQZmkqPio+vA2KmJngWTx+ol4rVFimGm76VT0xCFDsu2K0YX0yoLNH4u2XfmT9NR8gGfkVRCnnNjlbgHQmEwC75+GmEJ5DjD3d+s6IXTQ60MHvxbTHHlnfmPbgKn2SAI0uVoewKC9GyK6dSaboLw3C48jl0E2kyc+7umhCk3kEeWmt//GSjRNhoq+B+mynXiOtgFs/Am2v1TBjSb+6tcijsf5tFJmeGxlCjJnTdNWBkSHpMoo6OFkkpA6/FBAUHLSM7Yv8oYyd0GtwF5cCwQ6aRTbl9oG/mUn5Q92OnDMQcUjpgEho0Dcp2OqZyyxqQSPrbIIZZQrS2HkxBgjcfcSTuSHo7ONqlRjLUpO5yS95VLGXBLLHuCiIMGT+DW6DoJRtRIS+JieVWBoX0YsWgYInXrVlWUv6gDng5AyVFkUIFwZk7/3mVAgvXO83ArVKA4S747jT60w5bgV4Jy55slDM=	1
\.


--
-- Name: account_identifiers_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.account_identifiers_id_seq', 243, true);


--
-- Name: blocks_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.blocks_id_seq', 34, true);


--
-- Name: epoch_data_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.epoch_data_id_seq', 35, true);


--
-- Name: internal_commands_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.internal_commands_id_seq', 40, true);


--
-- Name: protocol_versions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.protocol_versions_id_seq', 1, true);


--
-- Name: public_keys_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.public_keys_id_seq', 243, true);


--
-- Name: snarked_ledger_hashes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.snarked_ledger_hashes_id_seq', 1, true);


--
-- Name: timing_info_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.timing_info_id_seq', 242, true);


--
-- Name: token_symbols_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.token_symbols_id_seq', 1, true);


--
-- Name: tokens_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.tokens_id_seq', 1, true);


--
-- Name: user_commands_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.user_commands_id_seq', 180, true);


--
-- Name: voting_for_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.voting_for_id_seq', 1, true);


--
-- Name: zkapp_account_precondition_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_account_precondition_id_seq', 189, true);


--
-- Name: zkapp_account_update_body_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_account_update_body_id_seq', 377, true);


--
-- Name: zkapp_account_update_failures_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_account_update_failures_id_seq', 4, true);


--
-- Name: zkapp_account_update_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_account_update_id_seq', 377, true);


--
-- Name: zkapp_accounts_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_accounts_id_seq', 1, false);


--
-- Name: zkapp_action_states_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_action_states_id_seq', 1, false);


--
-- Name: zkapp_amount_bounds_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_amount_bounds_id_seq', 1, false);


--
-- Name: zkapp_balance_bounds_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_balance_bounds_id_seq', 1, false);


--
-- Name: zkapp_commands_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_commands_id_seq', 375, true);


--
-- Name: zkapp_epoch_data_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_epoch_data_id_seq', 1, true);


--
-- Name: zkapp_epoch_ledger_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_epoch_ledger_id_seq', 1, true);


--
-- Name: zkapp_events_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_events_id_seq', 1, true);


--
-- Name: zkapp_fee_payer_body_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_fee_payer_body_id_seq', 375, true);


--
-- Name: zkapp_field_array_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_field_array_id_seq', 1, false);


--
-- Name: zkapp_field_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_field_id_seq', 187, true);


--
-- Name: zkapp_global_slot_bounds_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_global_slot_bounds_id_seq', 1, false);


--
-- Name: zkapp_length_bounds_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_length_bounds_id_seq', 1, false);


--
-- Name: zkapp_network_precondition_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_network_precondition_id_seq', 1, true);


--
-- Name: zkapp_nonce_bounds_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_nonce_bounds_id_seq', 188, true);


--
-- Name: zkapp_permissions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_permissions_id_seq', 1, true);


--
-- Name: zkapp_states_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_states_id_seq', 1, false);


--
-- Name: zkapp_states_nullable_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_states_nullable_id_seq', 188, true);


--
-- Name: zkapp_timing_info_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_timing_info_id_seq', 1, false);


--
-- Name: zkapp_token_id_bounds_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_token_id_bounds_id_seq', 1, false);


--
-- Name: zkapp_updates_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_updates_id_seq', 189, true);


--
-- Name: zkapp_uris_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_uris_id_seq', 1, false);


--
-- Name: zkapp_verification_key_hashes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_verification_key_hashes_id_seq', 1, true);


--
-- Name: zkapp_verification_keys_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_verification_keys_id_seq', 1, true);


--
-- Name: account_identifiers account_identifiers_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.account_identifiers
    ADD CONSTRAINT account_identifiers_pkey PRIMARY KEY (id);


--
-- Name: account_identifiers account_identifiers_public_key_id_token_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.account_identifiers
    ADD CONSTRAINT account_identifiers_public_key_id_token_id_key UNIQUE (public_key_id, token_id);


--
-- Name: accounts_accessed accounts_accessed_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.accounts_accessed
    ADD CONSTRAINT accounts_accessed_pkey PRIMARY KEY (block_id, account_identifier_id);


--
-- Name: accounts_created accounts_created_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.accounts_created
    ADD CONSTRAINT accounts_created_pkey PRIMARY KEY (block_id, account_identifier_id);


--
-- Name: blocks_internal_commands blocks_internal_commands_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.blocks_internal_commands
    ADD CONSTRAINT blocks_internal_commands_pkey PRIMARY KEY (block_id, internal_command_id, sequence_no, secondary_sequence_no);


--
-- Name: blocks blocks_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.blocks
    ADD CONSTRAINT blocks_pkey PRIMARY KEY (id);


--
-- Name: blocks blocks_state_hash_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.blocks
    ADD CONSTRAINT blocks_state_hash_key UNIQUE (state_hash);


--
-- Name: blocks_user_commands blocks_user_commands_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.blocks_user_commands
    ADD CONSTRAINT blocks_user_commands_pkey PRIMARY KEY (block_id, user_command_id, sequence_no);


--
-- Name: blocks_zkapp_commands blocks_zkapp_commands_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.blocks_zkapp_commands
    ADD CONSTRAINT blocks_zkapp_commands_pkey PRIMARY KEY (block_id, zkapp_command_id, sequence_no);


--
-- Name: epoch_data epoch_data_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.epoch_data
    ADD CONSTRAINT epoch_data_pkey PRIMARY KEY (id);


--
-- Name: epoch_data epoch_data_seed_ledger_hash_id_total_currency_start_checkpo_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.epoch_data
    ADD CONSTRAINT epoch_data_seed_ledger_hash_id_total_currency_start_checkpo_key UNIQUE (seed, ledger_hash_id, total_currency, start_checkpoint, lock_checkpoint, epoch_length);


--
-- Name: internal_commands internal_commands_hash_command_type_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.internal_commands
    ADD CONSTRAINT internal_commands_hash_command_type_key UNIQUE (hash, command_type);


--
-- Name: internal_commands internal_commands_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.internal_commands
    ADD CONSTRAINT internal_commands_pkey PRIMARY KEY (id);


--
-- Name: protocol_versions protocol_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.protocol_versions
    ADD CONSTRAINT protocol_versions_pkey PRIMARY KEY (id);


--
-- Name: protocol_versions protocol_versions_transaction_network_patch_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.protocol_versions
    ADD CONSTRAINT protocol_versions_transaction_network_patch_key UNIQUE (transaction, network, patch);


--
-- Name: public_keys public_keys_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.public_keys
    ADD CONSTRAINT public_keys_pkey PRIMARY KEY (id);


--
-- Name: public_keys public_keys_value_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.public_keys
    ADD CONSTRAINT public_keys_value_key UNIQUE (value);


--
-- Name: snarked_ledger_hashes snarked_ledger_hashes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.snarked_ledger_hashes
    ADD CONSTRAINT snarked_ledger_hashes_pkey PRIMARY KEY (id);


--
-- Name: snarked_ledger_hashes snarked_ledger_hashes_value_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.snarked_ledger_hashes
    ADD CONSTRAINT snarked_ledger_hashes_value_key UNIQUE (value);


--
-- Name: timing_info timing_info_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.timing_info
    ADD CONSTRAINT timing_info_pkey PRIMARY KEY (id);


--
-- Name: token_symbols token_symbols_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.token_symbols
    ADD CONSTRAINT token_symbols_pkey PRIMARY KEY (id);


--
-- Name: tokens tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tokens
    ADD CONSTRAINT tokens_pkey PRIMARY KEY (id);


--
-- Name: tokens tokens_value_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tokens
    ADD CONSTRAINT tokens_value_key UNIQUE (value);


--
-- Name: user_commands user_commands_hash_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_commands
    ADD CONSTRAINT user_commands_hash_key UNIQUE (hash);


--
-- Name: user_commands user_commands_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_commands
    ADD CONSTRAINT user_commands_pkey PRIMARY KEY (id);


--
-- Name: voting_for voting_for_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.voting_for
    ADD CONSTRAINT voting_for_pkey PRIMARY KEY (id);


--
-- Name: zkapp_account_precondition zkapp_account_precondition_balance_id_receipt_chain_hash_de_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_account_precondition
    ADD CONSTRAINT zkapp_account_precondition_balance_id_receipt_chain_hash_de_key UNIQUE (balance_id, receipt_chain_hash, delegate_id, state_id, action_state_id, proved_state, is_new, nonce_id);


--
-- Name: zkapp_account_precondition zkapp_account_precondition_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_account_precondition
    ADD CONSTRAINT zkapp_account_precondition_pkey PRIMARY KEY (id);


--
-- Name: zkapp_account_update_body zkapp_account_update_body_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_account_update_body
    ADD CONSTRAINT zkapp_account_update_body_pkey PRIMARY KEY (id);


--
-- Name: zkapp_account_update_failures zkapp_account_update_failures_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_account_update_failures
    ADD CONSTRAINT zkapp_account_update_failures_pkey PRIMARY KEY (id);


--
-- Name: zkapp_account_update zkapp_account_update_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_account_update
    ADD CONSTRAINT zkapp_account_update_pkey PRIMARY KEY (id);


--
-- Name: zkapp_accounts zkapp_accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_accounts
    ADD CONSTRAINT zkapp_accounts_pkey PRIMARY KEY (id);


--
-- Name: zkapp_action_states zkapp_action_states_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_action_states
    ADD CONSTRAINT zkapp_action_states_pkey PRIMARY KEY (id);


--
-- Name: zkapp_amount_bounds zkapp_amount_bounds_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_amount_bounds
    ADD CONSTRAINT zkapp_amount_bounds_pkey PRIMARY KEY (id);


--
-- Name: zkapp_balance_bounds zkapp_balance_bounds_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_balance_bounds
    ADD CONSTRAINT zkapp_balance_bounds_pkey PRIMARY KEY (id);


--
-- Name: zkapp_commands zkapp_commands_hash_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_commands
    ADD CONSTRAINT zkapp_commands_hash_key UNIQUE (hash);


--
-- Name: zkapp_commands zkapp_commands_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_commands
    ADD CONSTRAINT zkapp_commands_pkey PRIMARY KEY (id);


--
-- Name: zkapp_epoch_data zkapp_epoch_data_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_epoch_data
    ADD CONSTRAINT zkapp_epoch_data_pkey PRIMARY KEY (id);


--
-- Name: zkapp_epoch_ledger zkapp_epoch_ledger_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_epoch_ledger
    ADD CONSTRAINT zkapp_epoch_ledger_pkey PRIMARY KEY (id);


--
-- Name: zkapp_events zkapp_events_element_ids_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_events
    ADD CONSTRAINT zkapp_events_element_ids_key UNIQUE (element_ids);


--
-- Name: zkapp_events zkapp_events_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_events
    ADD CONSTRAINT zkapp_events_pkey PRIMARY KEY (id);


--
-- Name: zkapp_fee_payer_body zkapp_fee_payer_body_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_fee_payer_body
    ADD CONSTRAINT zkapp_fee_payer_body_pkey PRIMARY KEY (id);


--
-- Name: zkapp_field_array zkapp_field_array_element_ids_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_field_array
    ADD CONSTRAINT zkapp_field_array_element_ids_key UNIQUE (element_ids);


--
-- Name: zkapp_field_array zkapp_field_array_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_field_array
    ADD CONSTRAINT zkapp_field_array_pkey PRIMARY KEY (id);


--
-- Name: zkapp_field zkapp_field_field_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_field
    ADD CONSTRAINT zkapp_field_field_key UNIQUE (field);


--
-- Name: zkapp_field zkapp_field_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_field
    ADD CONSTRAINT zkapp_field_pkey PRIMARY KEY (id);


--
-- Name: zkapp_global_slot_bounds zkapp_global_slot_bounds_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_global_slot_bounds
    ADD CONSTRAINT zkapp_global_slot_bounds_pkey PRIMARY KEY (id);


--
-- Name: zkapp_length_bounds zkapp_length_bounds_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_length_bounds
    ADD CONSTRAINT zkapp_length_bounds_pkey PRIMARY KEY (id);


--
-- Name: zkapp_network_precondition zkapp_network_precondition_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_network_precondition
    ADD CONSTRAINT zkapp_network_precondition_pkey PRIMARY KEY (id);


--
-- Name: zkapp_nonce_bounds zkapp_nonce_bounds_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_nonce_bounds
    ADD CONSTRAINT zkapp_nonce_bounds_pkey PRIMARY KEY (id);


--
-- Name: zkapp_permissions zkapp_permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_permissions
    ADD CONSTRAINT zkapp_permissions_pkey PRIMARY KEY (id);


--
-- Name: zkapp_states_nullable zkapp_states_nullable_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_states_nullable
    ADD CONSTRAINT zkapp_states_nullable_pkey PRIMARY KEY (id);


--
-- Name: zkapp_states zkapp_states_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_states
    ADD CONSTRAINT zkapp_states_pkey PRIMARY KEY (id);


--
-- Name: zkapp_timing_info zkapp_timing_info_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_timing_info
    ADD CONSTRAINT zkapp_timing_info_pkey PRIMARY KEY (id);


--
-- Name: zkapp_token_id_bounds zkapp_token_id_bounds_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_token_id_bounds
    ADD CONSTRAINT zkapp_token_id_bounds_pkey PRIMARY KEY (id);


--
-- Name: zkapp_updates zkapp_updates_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_updates
    ADD CONSTRAINT zkapp_updates_pkey PRIMARY KEY (id);


--
-- Name: zkapp_uris zkapp_uris_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_uris
    ADD CONSTRAINT zkapp_uris_pkey PRIMARY KEY (id);


--
-- Name: zkapp_uris zkapp_uris_value_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_uris
    ADD CONSTRAINT zkapp_uris_value_key UNIQUE (value);


--
-- Name: zkapp_verification_key_hashes zkapp_verification_key_hashes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_verification_key_hashes
    ADD CONSTRAINT zkapp_verification_key_hashes_pkey PRIMARY KEY (id);


--
-- Name: zkapp_verification_key_hashes zkapp_verification_key_hashes_value_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_verification_key_hashes
    ADD CONSTRAINT zkapp_verification_key_hashes_value_key UNIQUE (value);


--
-- Name: zkapp_verification_keys zkapp_verification_keys_hash_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_verification_keys
    ADD CONSTRAINT zkapp_verification_keys_hash_id_key UNIQUE (hash_id);


--
-- Name: zkapp_verification_keys zkapp_verification_keys_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_verification_keys
    ADD CONSTRAINT zkapp_verification_keys_pkey PRIMARY KEY (id);


--
-- Name: zkapp_verification_keys zkapp_verification_keys_verification_key_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_verification_keys
    ADD CONSTRAINT zkapp_verification_keys_verification_key_key UNIQUE (verification_key);


--
-- Name: idx_accounts_accessed_block_account_identifier_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_accounts_accessed_block_account_identifier_id ON public.accounts_accessed USING btree (account_identifier_id);


--
-- Name: idx_accounts_accessed_block_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_accounts_accessed_block_id ON public.accounts_accessed USING btree (block_id);


--
-- Name: idx_accounts_created_block_account_identifier_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_accounts_created_block_account_identifier_id ON public.accounts_created USING btree (account_identifier_id);


--
-- Name: idx_accounts_created_block_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_accounts_created_block_id ON public.accounts_created USING btree (block_id);


--
-- Name: idx_blocks_creator_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_blocks_creator_id ON public.blocks USING btree (creator_id);


--
-- Name: idx_blocks_height; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_blocks_height ON public.blocks USING btree (height);


--
-- Name: idx_blocks_internal_commands_block_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_blocks_internal_commands_block_id ON public.blocks_internal_commands USING btree (block_id);


--
-- Name: idx_blocks_internal_commands_internal_command_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_blocks_internal_commands_internal_command_id ON public.blocks_internal_commands USING btree (internal_command_id);


--
-- Name: idx_blocks_internal_commands_secondary_sequence_no; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_blocks_internal_commands_secondary_sequence_no ON public.blocks_internal_commands USING btree (secondary_sequence_no);


--
-- Name: idx_blocks_internal_commands_sequence_no; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_blocks_internal_commands_sequence_no ON public.blocks_internal_commands USING btree (sequence_no);


--
-- Name: idx_blocks_parent_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_blocks_parent_id ON public.blocks USING btree (parent_id);


--
-- Name: idx_blocks_user_commands_block_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_blocks_user_commands_block_id ON public.blocks_user_commands USING btree (block_id);


--
-- Name: idx_blocks_user_commands_sequence_no; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_blocks_user_commands_sequence_no ON public.blocks_user_commands USING btree (sequence_no);


--
-- Name: idx_blocks_user_commands_user_command_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_blocks_user_commands_user_command_id ON public.blocks_user_commands USING btree (user_command_id);


--
-- Name: idx_blocks_zkapp_commands_block_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_blocks_zkapp_commands_block_id ON public.blocks_zkapp_commands USING btree (block_id);


--
-- Name: idx_blocks_zkapp_commands_sequence_no; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_blocks_zkapp_commands_sequence_no ON public.blocks_zkapp_commands USING btree (sequence_no);


--
-- Name: idx_blocks_zkapp_commands_zkapp_command_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_blocks_zkapp_commands_zkapp_command_id ON public.blocks_zkapp_commands USING btree (zkapp_command_id);


--
-- Name: idx_chain_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_chain_status ON public.blocks USING btree (chain_status);


--
-- Name: idx_token_symbols_value; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_token_symbols_value ON public.token_symbols USING btree (value);


--
-- Name: idx_voting_for_value; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_voting_for_value ON public.voting_for USING btree (value);


--
-- Name: idx_zkapp_events_element_ids; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_zkapp_events_element_ids ON public.zkapp_events USING btree (element_ids);


--
-- Name: idx_zkapp_field_array_element_ids; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_zkapp_field_array_element_ids ON public.zkapp_field_array USING btree (element_ids);


--
-- Name: account_identifiers account_identifiers_public_key_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.account_identifiers
    ADD CONSTRAINT account_identifiers_public_key_id_fkey FOREIGN KEY (public_key_id) REFERENCES public.public_keys(id) ON DELETE CASCADE;


--
-- Name: account_identifiers account_identifiers_token_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.account_identifiers
    ADD CONSTRAINT account_identifiers_token_id_fkey FOREIGN KEY (token_id) REFERENCES public.tokens(id) ON DELETE CASCADE;


--
-- Name: accounts_accessed accounts_accessed_account_identifier_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.accounts_accessed
    ADD CONSTRAINT accounts_accessed_account_identifier_id_fkey FOREIGN KEY (account_identifier_id) REFERENCES public.account_identifiers(id);


--
-- Name: accounts_accessed accounts_accessed_block_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.accounts_accessed
    ADD CONSTRAINT accounts_accessed_block_id_fkey FOREIGN KEY (block_id) REFERENCES public.blocks(id);


--
-- Name: accounts_accessed accounts_accessed_delegate_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.accounts_accessed
    ADD CONSTRAINT accounts_accessed_delegate_id_fkey FOREIGN KEY (delegate_id) REFERENCES public.public_keys(id);


--
-- Name: accounts_accessed accounts_accessed_permissions_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.accounts_accessed
    ADD CONSTRAINT accounts_accessed_permissions_id_fkey FOREIGN KEY (permissions_id) REFERENCES public.zkapp_permissions(id);


--
-- Name: accounts_accessed accounts_accessed_timing_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.accounts_accessed
    ADD CONSTRAINT accounts_accessed_timing_id_fkey FOREIGN KEY (timing_id) REFERENCES public.timing_info(id);


--
-- Name: accounts_accessed accounts_accessed_token_symbol_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.accounts_accessed
    ADD CONSTRAINT accounts_accessed_token_symbol_id_fkey FOREIGN KEY (token_symbol_id) REFERENCES public.token_symbols(id);


--
-- Name: accounts_accessed accounts_accessed_voting_for_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.accounts_accessed
    ADD CONSTRAINT accounts_accessed_voting_for_id_fkey FOREIGN KEY (voting_for_id) REFERENCES public.voting_for(id);


--
-- Name: accounts_accessed accounts_accessed_zkapp_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.accounts_accessed
    ADD CONSTRAINT accounts_accessed_zkapp_id_fkey FOREIGN KEY (zkapp_id) REFERENCES public.zkapp_accounts(id);


--
-- Name: accounts_created accounts_created_account_identifier_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.accounts_created
    ADD CONSTRAINT accounts_created_account_identifier_id_fkey FOREIGN KEY (account_identifier_id) REFERENCES public.account_identifiers(id);


--
-- Name: accounts_created accounts_created_block_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.accounts_created
    ADD CONSTRAINT accounts_created_block_id_fkey FOREIGN KEY (block_id) REFERENCES public.blocks(id);


--
-- Name: blocks blocks_block_winner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.blocks
    ADD CONSTRAINT blocks_block_winner_id_fkey FOREIGN KEY (block_winner_id) REFERENCES public.public_keys(id);


--
-- Name: blocks blocks_creator_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.blocks
    ADD CONSTRAINT blocks_creator_id_fkey FOREIGN KEY (creator_id) REFERENCES public.public_keys(id);


--
-- Name: blocks_internal_commands blocks_internal_commands_block_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.blocks_internal_commands
    ADD CONSTRAINT blocks_internal_commands_block_id_fkey FOREIGN KEY (block_id) REFERENCES public.blocks(id) ON DELETE CASCADE;


--
-- Name: blocks_internal_commands blocks_internal_commands_internal_command_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.blocks_internal_commands
    ADD CONSTRAINT blocks_internal_commands_internal_command_id_fkey FOREIGN KEY (internal_command_id) REFERENCES public.internal_commands(id) ON DELETE CASCADE;


--
-- Name: blocks blocks_next_epoch_data_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.blocks
    ADD CONSTRAINT blocks_next_epoch_data_id_fkey FOREIGN KEY (next_epoch_data_id) REFERENCES public.epoch_data(id);


--
-- Name: blocks blocks_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.blocks
    ADD CONSTRAINT blocks_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.blocks(id);


--
-- Name: blocks blocks_proposed_protocol_version_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.blocks
    ADD CONSTRAINT blocks_proposed_protocol_version_id_fkey FOREIGN KEY (proposed_protocol_version_id) REFERENCES public.protocol_versions(id);


--
-- Name: blocks blocks_protocol_version_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.blocks
    ADD CONSTRAINT blocks_protocol_version_id_fkey FOREIGN KEY (protocol_version_id) REFERENCES public.protocol_versions(id);


--
-- Name: blocks blocks_snarked_ledger_hash_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.blocks
    ADD CONSTRAINT blocks_snarked_ledger_hash_id_fkey FOREIGN KEY (snarked_ledger_hash_id) REFERENCES public.snarked_ledger_hashes(id);


--
-- Name: blocks blocks_staking_epoch_data_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.blocks
    ADD CONSTRAINT blocks_staking_epoch_data_id_fkey FOREIGN KEY (staking_epoch_data_id) REFERENCES public.epoch_data(id);


--
-- Name: blocks_user_commands blocks_user_commands_block_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.blocks_user_commands
    ADD CONSTRAINT blocks_user_commands_block_id_fkey FOREIGN KEY (block_id) REFERENCES public.blocks(id) ON DELETE CASCADE;


--
-- Name: blocks_user_commands blocks_user_commands_user_command_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.blocks_user_commands
    ADD CONSTRAINT blocks_user_commands_user_command_id_fkey FOREIGN KEY (user_command_id) REFERENCES public.user_commands(id) ON DELETE CASCADE;


--
-- Name: blocks_zkapp_commands blocks_zkapp_commands_block_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.blocks_zkapp_commands
    ADD CONSTRAINT blocks_zkapp_commands_block_id_fkey FOREIGN KEY (block_id) REFERENCES public.blocks(id) ON DELETE CASCADE;


--
-- Name: blocks_zkapp_commands blocks_zkapp_commands_zkapp_command_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.blocks_zkapp_commands
    ADD CONSTRAINT blocks_zkapp_commands_zkapp_command_id_fkey FOREIGN KEY (zkapp_command_id) REFERENCES public.zkapp_commands(id) ON DELETE CASCADE;


--
-- Name: epoch_data epoch_data_ledger_hash_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.epoch_data
    ADD CONSTRAINT epoch_data_ledger_hash_id_fkey FOREIGN KEY (ledger_hash_id) REFERENCES public.snarked_ledger_hashes(id);


--
-- Name: internal_commands internal_commands_receiver_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.internal_commands
    ADD CONSTRAINT internal_commands_receiver_id_fkey FOREIGN KEY (receiver_id) REFERENCES public.public_keys(id);


--
-- Name: timing_info timing_info_account_identifier_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.timing_info
    ADD CONSTRAINT timing_info_account_identifier_id_fkey FOREIGN KEY (account_identifier_id) REFERENCES public.account_identifiers(id);


--
-- Name: tokens tokens_owner_public_key_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tokens
    ADD CONSTRAINT tokens_owner_public_key_id_fkey FOREIGN KEY (owner_public_key_id) REFERENCES public.public_keys(id) ON DELETE CASCADE;


--
-- Name: tokens tokens_owner_token_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tokens
    ADD CONSTRAINT tokens_owner_token_id_fkey FOREIGN KEY (owner_token_id) REFERENCES public.tokens(id);


--
-- Name: user_commands user_commands_fee_payer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_commands
    ADD CONSTRAINT user_commands_fee_payer_id_fkey FOREIGN KEY (fee_payer_id) REFERENCES public.public_keys(id);


--
-- Name: user_commands user_commands_receiver_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_commands
    ADD CONSTRAINT user_commands_receiver_id_fkey FOREIGN KEY (receiver_id) REFERENCES public.public_keys(id);


--
-- Name: user_commands user_commands_source_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_commands
    ADD CONSTRAINT user_commands_source_id_fkey FOREIGN KEY (source_id) REFERENCES public.public_keys(id);


--
-- Name: zkapp_account_precondition zkapp_account_precondition_action_state_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_account_precondition
    ADD CONSTRAINT zkapp_account_precondition_action_state_id_fkey FOREIGN KEY (action_state_id) REFERENCES public.zkapp_field(id);


--
-- Name: zkapp_account_precondition zkapp_account_precondition_balance_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_account_precondition
    ADD CONSTRAINT zkapp_account_precondition_balance_id_fkey FOREIGN KEY (balance_id) REFERENCES public.zkapp_balance_bounds(id);


--
-- Name: zkapp_account_precondition zkapp_account_precondition_delegate_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_account_precondition
    ADD CONSTRAINT zkapp_account_precondition_delegate_id_fkey FOREIGN KEY (delegate_id) REFERENCES public.public_keys(id);


--
-- Name: zkapp_account_precondition zkapp_account_precondition_nonce_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_account_precondition
    ADD CONSTRAINT zkapp_account_precondition_nonce_id_fkey FOREIGN KEY (nonce_id) REFERENCES public.zkapp_nonce_bounds(id);


--
-- Name: zkapp_account_precondition zkapp_account_precondition_state_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_account_precondition
    ADD CONSTRAINT zkapp_account_precondition_state_id_fkey FOREIGN KEY (state_id) REFERENCES public.zkapp_states_nullable(id);


--
-- Name: zkapp_account_update_body zkapp_account_update_body_account_identifier_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_account_update_body
    ADD CONSTRAINT zkapp_account_update_body_account_identifier_id_fkey FOREIGN KEY (account_identifier_id) REFERENCES public.account_identifiers(id);


--
-- Name: zkapp_account_update_body zkapp_account_update_body_actions_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_account_update_body
    ADD CONSTRAINT zkapp_account_update_body_actions_id_fkey FOREIGN KEY (actions_id) REFERENCES public.zkapp_events(id);


--
-- Name: zkapp_account_update_body zkapp_account_update_body_call_data_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_account_update_body
    ADD CONSTRAINT zkapp_account_update_body_call_data_id_fkey FOREIGN KEY (call_data_id) REFERENCES public.zkapp_field(id);


--
-- Name: zkapp_account_update_body zkapp_account_update_body_events_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_account_update_body
    ADD CONSTRAINT zkapp_account_update_body_events_id_fkey FOREIGN KEY (events_id) REFERENCES public.zkapp_events(id);


--
-- Name: zkapp_account_update zkapp_account_update_body_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_account_update
    ADD CONSTRAINT zkapp_account_update_body_id_fkey FOREIGN KEY (body_id) REFERENCES public.zkapp_account_update_body(id);


--
-- Name: zkapp_account_update_body zkapp_account_update_body_update_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_account_update_body
    ADD CONSTRAINT zkapp_account_update_body_update_id_fkey FOREIGN KEY (update_id) REFERENCES public.zkapp_updates(id);


--
-- Name: zkapp_account_update_body zkapp_account_update_body_verification_key_hash_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_account_update_body
    ADD CONSTRAINT zkapp_account_update_body_verification_key_hash_id_fkey FOREIGN KEY (verification_key_hash_id) REFERENCES public.zkapp_verification_key_hashes(id);


--
-- Name: zkapp_account_update_body zkapp_account_update_body_zkapp_account_precondition_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_account_update_body
    ADD CONSTRAINT zkapp_account_update_body_zkapp_account_precondition_id_fkey FOREIGN KEY (zkapp_account_precondition_id) REFERENCES public.zkapp_account_precondition(id);


--
-- Name: zkapp_account_update_body zkapp_account_update_body_zkapp_network_precondition_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_account_update_body
    ADD CONSTRAINT zkapp_account_update_body_zkapp_network_precondition_id_fkey FOREIGN KEY (zkapp_network_precondition_id) REFERENCES public.zkapp_network_precondition(id);


--
-- Name: zkapp_account_update_body zkapp_account_update_body_zkapp_valid_while_precondition_i_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_account_update_body
    ADD CONSTRAINT zkapp_account_update_body_zkapp_valid_while_precondition_i_fkey FOREIGN KEY (zkapp_valid_while_precondition_id) REFERENCES public.zkapp_global_slot_bounds(id);


--
-- Name: zkapp_accounts zkapp_accounts_action_state_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_accounts
    ADD CONSTRAINT zkapp_accounts_action_state_id_fkey FOREIGN KEY (action_state_id) REFERENCES public.zkapp_action_states(id);


--
-- Name: zkapp_accounts zkapp_accounts_app_state_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_accounts
    ADD CONSTRAINT zkapp_accounts_app_state_id_fkey FOREIGN KEY (app_state_id) REFERENCES public.zkapp_states(id);


--
-- Name: zkapp_accounts zkapp_accounts_verification_key_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_accounts
    ADD CONSTRAINT zkapp_accounts_verification_key_id_fkey FOREIGN KEY (verification_key_id) REFERENCES public.zkapp_verification_keys(id);


--
-- Name: zkapp_accounts zkapp_accounts_zkapp_uri_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_accounts
    ADD CONSTRAINT zkapp_accounts_zkapp_uri_id_fkey FOREIGN KEY (zkapp_uri_id) REFERENCES public.zkapp_uris(id);


--
-- Name: zkapp_action_states zkapp_action_states_element0_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_action_states
    ADD CONSTRAINT zkapp_action_states_element0_fkey FOREIGN KEY (element0) REFERENCES public.zkapp_field(id);


--
-- Name: zkapp_action_states zkapp_action_states_element1_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_action_states
    ADD CONSTRAINT zkapp_action_states_element1_fkey FOREIGN KEY (element1) REFERENCES public.zkapp_field(id);


--
-- Name: zkapp_action_states zkapp_action_states_element2_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_action_states
    ADD CONSTRAINT zkapp_action_states_element2_fkey FOREIGN KEY (element2) REFERENCES public.zkapp_field(id);


--
-- Name: zkapp_action_states zkapp_action_states_element3_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_action_states
    ADD CONSTRAINT zkapp_action_states_element3_fkey FOREIGN KEY (element3) REFERENCES public.zkapp_field(id);


--
-- Name: zkapp_action_states zkapp_action_states_element4_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_action_states
    ADD CONSTRAINT zkapp_action_states_element4_fkey FOREIGN KEY (element4) REFERENCES public.zkapp_field(id);


--
-- Name: zkapp_commands zkapp_commands_zkapp_fee_payer_body_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_commands
    ADD CONSTRAINT zkapp_commands_zkapp_fee_payer_body_id_fkey FOREIGN KEY (zkapp_fee_payer_body_id) REFERENCES public.zkapp_fee_payer_body(id);


--
-- Name: zkapp_epoch_data zkapp_epoch_data_epoch_ledger_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_epoch_data
    ADD CONSTRAINT zkapp_epoch_data_epoch_ledger_id_fkey FOREIGN KEY (epoch_ledger_id) REFERENCES public.zkapp_epoch_ledger(id);


--
-- Name: zkapp_epoch_data zkapp_epoch_data_epoch_length_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_epoch_data
    ADD CONSTRAINT zkapp_epoch_data_epoch_length_id_fkey FOREIGN KEY (epoch_length_id) REFERENCES public.zkapp_length_bounds(id);


--
-- Name: zkapp_epoch_ledger zkapp_epoch_ledger_hash_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_epoch_ledger
    ADD CONSTRAINT zkapp_epoch_ledger_hash_id_fkey FOREIGN KEY (hash_id) REFERENCES public.snarked_ledger_hashes(id);


--
-- Name: zkapp_epoch_ledger zkapp_epoch_ledger_total_currency_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_epoch_ledger
    ADD CONSTRAINT zkapp_epoch_ledger_total_currency_id_fkey FOREIGN KEY (total_currency_id) REFERENCES public.zkapp_amount_bounds(id);


--
-- Name: zkapp_fee_payer_body zkapp_fee_payer_body_public_key_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_fee_payer_body
    ADD CONSTRAINT zkapp_fee_payer_body_public_key_id_fkey FOREIGN KEY (public_key_id) REFERENCES public.public_keys(id);


--
-- Name: zkapp_network_precondition zkapp_network_precondition_blockchain_length_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_network_precondition
    ADD CONSTRAINT zkapp_network_precondition_blockchain_length_id_fkey FOREIGN KEY (blockchain_length_id) REFERENCES public.zkapp_length_bounds(id);


--
-- Name: zkapp_network_precondition zkapp_network_precondition_global_slot_since_genesis_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_network_precondition
    ADD CONSTRAINT zkapp_network_precondition_global_slot_since_genesis_fkey FOREIGN KEY (global_slot_since_genesis) REFERENCES public.zkapp_global_slot_bounds(id);


--
-- Name: zkapp_network_precondition zkapp_network_precondition_min_window_density_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_network_precondition
    ADD CONSTRAINT zkapp_network_precondition_min_window_density_id_fkey FOREIGN KEY (min_window_density_id) REFERENCES public.zkapp_length_bounds(id);


--
-- Name: zkapp_network_precondition zkapp_network_precondition_next_epoch_data_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_network_precondition
    ADD CONSTRAINT zkapp_network_precondition_next_epoch_data_id_fkey FOREIGN KEY (next_epoch_data_id) REFERENCES public.zkapp_epoch_data(id);


--
-- Name: zkapp_network_precondition zkapp_network_precondition_snarked_ledger_hash_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_network_precondition
    ADD CONSTRAINT zkapp_network_precondition_snarked_ledger_hash_id_fkey FOREIGN KEY (snarked_ledger_hash_id) REFERENCES public.snarked_ledger_hashes(id);


--
-- Name: zkapp_network_precondition zkapp_network_precondition_staking_epoch_data_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_network_precondition
    ADD CONSTRAINT zkapp_network_precondition_staking_epoch_data_id_fkey FOREIGN KEY (staking_epoch_data_id) REFERENCES public.zkapp_epoch_data(id);


--
-- Name: zkapp_network_precondition zkapp_network_precondition_total_currency_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_network_precondition
    ADD CONSTRAINT zkapp_network_precondition_total_currency_id_fkey FOREIGN KEY (total_currency_id) REFERENCES public.zkapp_amount_bounds(id);


--
-- Name: zkapp_states zkapp_states_element0_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_states
    ADD CONSTRAINT zkapp_states_element0_fkey FOREIGN KEY (element0) REFERENCES public.zkapp_field(id);


--
-- Name: zkapp_states zkapp_states_element1_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_states
    ADD CONSTRAINT zkapp_states_element1_fkey FOREIGN KEY (element1) REFERENCES public.zkapp_field(id);


--
-- Name: zkapp_states zkapp_states_element2_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_states
    ADD CONSTRAINT zkapp_states_element2_fkey FOREIGN KEY (element2) REFERENCES public.zkapp_field(id);


--
-- Name: zkapp_states zkapp_states_element3_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_states
    ADD CONSTRAINT zkapp_states_element3_fkey FOREIGN KEY (element3) REFERENCES public.zkapp_field(id);


--
-- Name: zkapp_states zkapp_states_element4_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_states
    ADD CONSTRAINT zkapp_states_element4_fkey FOREIGN KEY (element4) REFERENCES public.zkapp_field(id);


--
-- Name: zkapp_states zkapp_states_element5_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_states
    ADD CONSTRAINT zkapp_states_element5_fkey FOREIGN KEY (element5) REFERENCES public.zkapp_field(id);


--
-- Name: zkapp_states zkapp_states_element6_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_states
    ADD CONSTRAINT zkapp_states_element6_fkey FOREIGN KEY (element6) REFERENCES public.zkapp_field(id);


--
-- Name: zkapp_states zkapp_states_element7_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_states
    ADD CONSTRAINT zkapp_states_element7_fkey FOREIGN KEY (element7) REFERENCES public.zkapp_field(id);


--
-- Name: zkapp_states_nullable zkapp_states_nullable_element0_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_states_nullable
    ADD CONSTRAINT zkapp_states_nullable_element0_fkey FOREIGN KEY (element0) REFERENCES public.zkapp_field(id);


--
-- Name: zkapp_states_nullable zkapp_states_nullable_element1_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_states_nullable
    ADD CONSTRAINT zkapp_states_nullable_element1_fkey FOREIGN KEY (element1) REFERENCES public.zkapp_field(id);


--
-- Name: zkapp_states_nullable zkapp_states_nullable_element2_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_states_nullable
    ADD CONSTRAINT zkapp_states_nullable_element2_fkey FOREIGN KEY (element2) REFERENCES public.zkapp_field(id);


--
-- Name: zkapp_states_nullable zkapp_states_nullable_element3_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_states_nullable
    ADD CONSTRAINT zkapp_states_nullable_element3_fkey FOREIGN KEY (element3) REFERENCES public.zkapp_field(id);


--
-- Name: zkapp_states_nullable zkapp_states_nullable_element4_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_states_nullable
    ADD CONSTRAINT zkapp_states_nullable_element4_fkey FOREIGN KEY (element4) REFERENCES public.zkapp_field(id);


--
-- Name: zkapp_states_nullable zkapp_states_nullable_element5_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_states_nullable
    ADD CONSTRAINT zkapp_states_nullable_element5_fkey FOREIGN KEY (element5) REFERENCES public.zkapp_field(id);


--
-- Name: zkapp_states_nullable zkapp_states_nullable_element6_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_states_nullable
    ADD CONSTRAINT zkapp_states_nullable_element6_fkey FOREIGN KEY (element6) REFERENCES public.zkapp_field(id);


--
-- Name: zkapp_states_nullable zkapp_states_nullable_element7_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_states_nullable
    ADD CONSTRAINT zkapp_states_nullable_element7_fkey FOREIGN KEY (element7) REFERENCES public.zkapp_field(id);


--
-- Name: zkapp_updates zkapp_updates_app_state_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_updates
    ADD CONSTRAINT zkapp_updates_app_state_id_fkey FOREIGN KEY (app_state_id) REFERENCES public.zkapp_states_nullable(id);


--
-- Name: zkapp_updates zkapp_updates_delegate_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_updates
    ADD CONSTRAINT zkapp_updates_delegate_id_fkey FOREIGN KEY (delegate_id) REFERENCES public.public_keys(id);


--
-- Name: zkapp_updates zkapp_updates_permissions_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_updates
    ADD CONSTRAINT zkapp_updates_permissions_id_fkey FOREIGN KEY (permissions_id) REFERENCES public.zkapp_permissions(id);


--
-- Name: zkapp_updates zkapp_updates_timing_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_updates
    ADD CONSTRAINT zkapp_updates_timing_id_fkey FOREIGN KEY (timing_id) REFERENCES public.zkapp_timing_info(id);


--
-- Name: zkapp_updates zkapp_updates_token_symbol_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_updates
    ADD CONSTRAINT zkapp_updates_token_symbol_id_fkey FOREIGN KEY (token_symbol_id) REFERENCES public.token_symbols(id);


--
-- Name: zkapp_updates zkapp_updates_verification_key_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_updates
    ADD CONSTRAINT zkapp_updates_verification_key_id_fkey FOREIGN KEY (verification_key_id) REFERENCES public.zkapp_verification_keys(id);


--
-- Name: zkapp_updates zkapp_updates_voting_for_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_updates
    ADD CONSTRAINT zkapp_updates_voting_for_id_fkey FOREIGN KEY (voting_for_id) REFERENCES public.voting_for(id);


--
-- Name: zkapp_updates zkapp_updates_zkapp_uri_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_updates
    ADD CONSTRAINT zkapp_updates_zkapp_uri_id_fkey FOREIGN KEY (zkapp_uri_id) REFERENCES public.zkapp_uris(id);


--
-- Name: zkapp_verification_keys zkapp_verification_keys_hash_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_verification_keys
    ADD CONSTRAINT zkapp_verification_keys_hash_id_fkey FOREIGN KEY (hash_id) REFERENCES public.zkapp_verification_key_hashes(id);


--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE USAGE ON SCHEMA public FROM PUBLIC;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--

