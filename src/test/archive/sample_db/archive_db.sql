--
-- PostgreSQL database dump
--

-- Dumped from database version 14.18
-- Dumped by pg_dump version 16.8

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


ALTER SEQUENCE public.account_identifiers_id_seq OWNER TO postgres;

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


ALTER SEQUENCE public.blocks_id_seq OWNER TO postgres;

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


ALTER SEQUENCE public.epoch_data_id_seq OWNER TO postgres;

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


ALTER SEQUENCE public.internal_commands_id_seq OWNER TO postgres;

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


ALTER SEQUENCE public.protocol_versions_id_seq OWNER TO postgres;

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


ALTER SEQUENCE public.public_keys_id_seq OWNER TO postgres;

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


ALTER SEQUENCE public.snarked_ledger_hashes_id_seq OWNER TO postgres;

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


ALTER SEQUENCE public.timing_info_id_seq OWNER TO postgres;

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


ALTER SEQUENCE public.token_symbols_id_seq OWNER TO postgres;

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


ALTER SEQUENCE public.tokens_id_seq OWNER TO postgres;

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


ALTER SEQUENCE public.user_commands_id_seq OWNER TO postgres;

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


ALTER SEQUENCE public.voting_for_id_seq OWNER TO postgres;

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


ALTER SEQUENCE public.zkapp_account_precondition_id_seq OWNER TO postgres;

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


ALTER SEQUENCE public.zkapp_account_update_body_id_seq OWNER TO postgres;

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


ALTER SEQUENCE public.zkapp_account_update_failures_id_seq OWNER TO postgres;

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


ALTER SEQUENCE public.zkapp_account_update_id_seq OWNER TO postgres;

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


ALTER SEQUENCE public.zkapp_accounts_id_seq OWNER TO postgres;

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


ALTER SEQUENCE public.zkapp_action_states_id_seq OWNER TO postgres;

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


ALTER SEQUENCE public.zkapp_amount_bounds_id_seq OWNER TO postgres;

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


ALTER SEQUENCE public.zkapp_balance_bounds_id_seq OWNER TO postgres;

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


ALTER SEQUENCE public.zkapp_commands_id_seq OWNER TO postgres;

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


ALTER SEQUENCE public.zkapp_epoch_data_id_seq OWNER TO postgres;

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


ALTER SEQUENCE public.zkapp_epoch_ledger_id_seq OWNER TO postgres;

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


ALTER SEQUENCE public.zkapp_events_id_seq OWNER TO postgres;

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


ALTER SEQUENCE public.zkapp_fee_payer_body_id_seq OWNER TO postgres;

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


ALTER SEQUENCE public.zkapp_field_array_id_seq OWNER TO postgres;

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


ALTER SEQUENCE public.zkapp_field_id_seq OWNER TO postgres;

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


ALTER SEQUENCE public.zkapp_global_slot_bounds_id_seq OWNER TO postgres;

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


ALTER SEQUENCE public.zkapp_length_bounds_id_seq OWNER TO postgres;

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


ALTER SEQUENCE public.zkapp_network_precondition_id_seq OWNER TO postgres;

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


ALTER SEQUENCE public.zkapp_nonce_bounds_id_seq OWNER TO postgres;

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


ALTER SEQUENCE public.zkapp_permissions_id_seq OWNER TO postgres;

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
    element7 integer NOT NULL,
    element8 integer NOT NULL,
    element9 integer NOT NULL,
    element10 integer NOT NULL,
    element11 integer NOT NULL,
    element12 integer NOT NULL,
    element13 integer NOT NULL,
    element14 integer NOT NULL,
    element15 integer NOT NULL,
    element16 integer NOT NULL,
    element17 integer NOT NULL,
    element18 integer NOT NULL,
    element19 integer NOT NULL,
    element20 integer NOT NULL,
    element21 integer NOT NULL,
    element22 integer NOT NULL,
    element23 integer NOT NULL,
    element24 integer NOT NULL,
    element25 integer NOT NULL,
    element26 integer NOT NULL,
    element27 integer NOT NULL,
    element28 integer NOT NULL,
    element29 integer NOT NULL,
    element30 integer NOT NULL,
    element31 integer NOT NULL
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


ALTER SEQUENCE public.zkapp_states_id_seq OWNER TO postgres;

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
    element7 integer,
    element8 integer,
    element9 integer,
    element10 integer,
    element11 integer,
    element12 integer,
    element13 integer,
    element14 integer,
    element15 integer,
    element16 integer,
    element17 integer,
    element18 integer,
    element19 integer,
    element20 integer,
    element21 integer,
    element22 integer,
    element23 integer,
    element24 integer,
    element25 integer,
    element26 integer,
    element27 integer,
    element28 integer,
    element29 integer,
    element30 integer,
    element31 integer
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


ALTER SEQUENCE public.zkapp_states_nullable_id_seq OWNER TO postgres;

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


ALTER SEQUENCE public.zkapp_timing_info_id_seq OWNER TO postgres;

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


ALTER SEQUENCE public.zkapp_token_id_bounds_id_seq OWNER TO postgres;

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


ALTER SEQUENCE public.zkapp_updates_id_seq OWNER TO postgres;

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


ALTER SEQUENCE public.zkapp_uris_id_seq OWNER TO postgres;

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


ALTER SEQUENCE public.zkapp_verification_key_hashes_id_seq OWNER TO postgres;

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


ALTER SEQUENCE public.zkapp_verification_keys_id_seq OWNER TO postgres;

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
11	12	1
12	13	1
13	14	1
14	15	1
15	16	1
16	17	1
17	18	1
18	19	1
19	20	1
20	21	1
21	22	1
22	23	1
23	24	1
24	25	1
25	26	1
26	27	1
27	28	1
28	29	1
29	30	1
30	31	1
31	32	1
32	33	1
33	34	1
34	35	1
35	36	1
36	37	1
37	38	1
38	39	1
39	40	1
40	41	1
41	42	1
42	43	1
43	44	1
44	45	1
45	46	1
46	47	1
47	48	1
48	49	1
49	50	1
50	51	1
51	52	1
52	53	1
53	54	1
54	55	1
55	56	1
56	57	1
57	58	1
58	59	1
59	60	1
60	61	1
61	62	1
62	63	1
63	64	1
64	65	1
65	66	1
66	67	1
67	68	1
68	69	1
69	70	1
70	71	1
71	72	1
72	73	1
73	74	1
74	75	1
75	76	1
76	77	1
77	78	1
78	79	1
79	80	1
80	81	1
81	82	1
82	83	1
83	84	1
84	85	1
85	86	1
86	87	1
87	88	1
88	89	1
89	90	1
90	91	1
91	92	1
92	93	1
93	94	1
94	95	1
95	96	1
96	97	1
97	98	1
98	99	1
99	100	1
100	101	1
101	102	1
102	103	1
103	104	1
104	105	1
105	106	1
106	107	1
107	108	1
108	109	1
109	110	1
110	111	1
111	112	1
112	113	1
113	114	1
114	115	1
115	116	1
116	117	1
117	118	1
118	119	1
119	120	1
120	121	1
121	122	1
122	123	1
123	124	1
124	125	1
125	126	1
126	127	1
127	128	1
128	129	1
129	130	1
130	131	1
131	132	1
132	133	1
133	134	1
134	135	1
135	136	1
136	137	1
137	138	1
138	139	1
139	141	1
140	142	1
141	143	1
142	144	1
143	145	1
144	146	1
145	147	1
146	148	1
147	149	1
148	150	1
149	151	1
150	152	1
151	153	1
152	154	1
153	155	1
154	156	1
155	157	1
156	158	1
157	159	1
158	160	1
159	161	1
160	162	1
161	163	1
162	164	1
163	165	1
164	166	1
165	167	1
166	168	1
167	169	1
168	170	1
169	171	1
170	172	1
171	173	1
172	174	1
173	175	1
174	176	1
175	177	1
176	178	1
177	179	1
178	180	1
179	181	1
180	182	1
181	183	1
182	184	1
183	185	1
184	186	1
185	187	1
186	1	1
187	188	1
188	189	1
189	190	1
190	191	1
191	192	1
192	193	1
193	194	1
194	195	1
195	196	1
196	197	1
197	198	1
198	199	1
199	200	1
200	201	1
201	202	1
202	203	1
203	204	1
204	205	1
205	206	1
206	207	1
207	208	1
208	209	1
209	210	1
210	211	1
211	140	1
212	212	1
213	213	1
214	214	1
215	215	1
216	216	1
217	217	1
218	218	1
219	219	1
220	220	1
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
226	1	10	1	469	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	11	1	10	1	\N
19	1	11	1	242	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	12	1	11	1	\N
128	1	12	1	135	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	13	1	12	1	\N
94	1	13	1	196	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	14	1	13	1	\N
153	1	14	1	79	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	15	1	14	1	\N
166	1	15	1	206	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	16	1	15	1	\N
137	1	16	1	340	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	17	1	16	1	\N
105	1	17	1	382	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	18	1	17	1	\N
70	1	18	1	488	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	19	1	18	1	\N
27	1	19	1	135	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	20	1	19	1	\N
46	1	20	1	126	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	21	1	20	1	\N
43	1	21	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	22	1	21	1	\N
117	1	22	1	278	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	23	1	22	1	\N
204	1	23	1	46	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	24	1	23	1	\N
187	1	24	1	104	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	25	1	24	1	\N
72	1	25	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	26	1	25	1	\N
216	1	26	1	271	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	27	1	26	1	\N
210	1	27	1	315	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
79	1	28	1	162	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	29	1	28	1	\N
167	1	29	1	86	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	30	1	29	1	\N
181	1	30	1	409	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	31	1	30	1	\N
156	1	31	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	32	1	31	1	\N
96	1	32	1	57	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	33	1	32	1	\N
191	1	33	1	204	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	34	1	33	1	\N
132	1	34	1	262	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	35	1	34	1	\N
111	1	35	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	36	1	35	1	\N
171	1	36	1	156	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	37	1	36	1	\N
64	1	37	1	417	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	38	1	37	1	\N
68	1	38	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	39	1	38	1	\N
51	1	39	1	85	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	40	1	39	1	\N
227	1	40	1	103	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	41	1	40	1	\N
141	1	41	1	67	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	42	1	41	1	\N
42	1	42	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	43	1	42	1	\N
133	1	43	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	44	1	43	1	\N
82	1	44	1	198	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	45	1	44	1	\N
95	1	45	1	489	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	46	1	45	1	\N
188	1	46	1	298	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	47	1	46	1	\N
30	1	47	1	36	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	48	1	47	1	\N
90	1	48	1	334	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	49	1	48	1	\N
14	1	49	1	344	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	50	1	49	1	\N
35	1	50	1	451	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	51	1	50	1	\N
85	1	51	1	371	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	52	1	51	1	\N
127	1	52	1	234	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	53	1	52	1	\N
222	1	53	1	345	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	54	1	53	1	\N
76	1	54	1	282	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	55	1	54	1	\N
231	1	55	1	339	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	56	1	55	1	\N
15	1	56	1	215	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
220	1	57	1	193	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	58	1	57	1	\N
16	1	58	1	60	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	59	1	58	1	\N
58	1	59	1	350	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	60	1	59	1	\N
146	1	60	1	223	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	61	1	60	1	\N
62	1	61	1	449	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	62	1	61	1	\N
185	1	62	1	142	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	63	1	62	1	\N
151	1	63	1	300	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	64	1	63	1	\N
165	1	64	1	256	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	65	1	64	1	\N
103	1	65	1	125	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	66	1	65	1	\N
41	1	66	1	236	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	67	1	66	1	\N
239	1	67	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	68	1	67	1	\N
110	1	68	1	179	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	69	1	68	1	\N
13	1	69	1	194	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	70	1	69	1	\N
26	1	70	1	185	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	71	1	70	1	\N
98	1	71	1	342	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	72	1	71	1	\N
215	1	72	1	157	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	73	1	72	1	\N
91	1	73	1	135	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	74	1	73	1	\N
159	1	74	1	456	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	75	1	74	1	\N
208	1	75	1	336	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	76	1	75	1	\N
207	1	76	1	280	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	77	1	76	1	\N
182	1	77	1	187	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	78	1	77	1	\N
157	1	78	1	387	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	79	1	78	1	\N
33	1	79	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	80	1	79	1	\N
201	1	80	1	151	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	81	1	80	1	\N
9	1	81	1	356	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	82	1	81	1	\N
234	1	82	1	24	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	83	1	82	1	\N
40	1	83	1	152	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	84	1	83	1	\N
18	1	84	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	85	1	84	1	\N
229	1	85	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	86	1	85	1	\N
20	1	86	1	186	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	87	1	86	1	\N
184	1	87	1	266	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	88	1	87	1	\N
139	1	88	1	81	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	89	1	88	1	\N
164	1	89	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	90	1	89	1	\N
199	1	90	1	379	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	91	1	90	1	\N
109	1	91	1	315	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	92	1	91	1	\N
47	1	92	1	226	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	93	1	92	1	\N
214	1	93	1	166	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	94	1	93	1	\N
112	1	94	1	302	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	95	1	94	1	\N
144	1	95	1	269	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	96	1	95	1	\N
178	1	96	1	172	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	97	1	96	1	\N
155	1	97	1	195	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	98	1	97	1	\N
38	1	98	1	243	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	99	1	98	1	\N
80	1	99	1	128	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	100	1	99	1	\N
147	1	100	1	349	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	101	1	100	1	\N
24	1	101	1	87	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	102	1	101	1	\N
126	1	102	1	424	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	103	1	102	1	\N
89	1	103	1	239	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	104	1	103	1	\N
135	1	104	1	316	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	105	1	104	1	\N
194	1	105	1	492	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	106	1	105	1	\N
190	1	106	1	294	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	107	1	106	1	\N
218	1	107	1	191	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	108	1	107	1	\N
93	1	108	1	380	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	109	1	108	1	\N
5	1	109	1	0	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	110	1	109	1	\N
162	1	110	1	331	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	111	1	110	1	\N
1	1	111	1	5000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	112	1	111	1	\N
221	1	112	1	459	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	113	1	112	1	\N
205	1	113	1	28	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	114	1	113	1	\N
195	1	114	1	472	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	115	1	114	1	\N
34	1	115	1	119	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	116	1	115	1	\N
213	1	116	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	117	1	116	1	\N
196	1	117	1	41	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	118	1	117	1	\N
104	1	118	1	27	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	119	1	118	1	\N
44	1	119	1	70	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	120	1	119	1	\N
52	1	120	1	337	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	121	1	120	1	\N
114	1	121	1	210	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	122	1	121	1	\N
177	1	122	1	495	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	123	1	122	1	\N
148	1	123	1	144	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	124	1	123	1	\N
100	1	124	1	148	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	125	1	124	1	\N
206	1	125	1	376	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	126	1	125	1	\N
28	1	126	1	329	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	127	1	126	1	\N
173	1	127	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	128	1	127	1	\N
130	1	128	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	129	1	128	1	\N
39	1	129	1	181	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	130	1	129	1	\N
212	1	130	1	200	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	131	1	130	1	\N
116	1	131	1	159	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
48	1	132	1	319	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	133	1	132	1	\N
101	1	133	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	134	1	133	1	\N
7	1	134	1	0	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	135	1	134	1	\N
203	1	135	1	365	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	136	1	135	1	\N
50	1	136	1	342	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	137	1	136	1	\N
59	1	137	1	237	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	138	1	137	1	\N
2	1	138	1	65500000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	140	1	138	1	\N
150	1	139	1	427	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	141	1	139	1	\N
180	1	140	1	315	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	142	1	140	1	\N
142	1	141	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	143	1	141	1	\N
23	1	142	1	378	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	144	1	142	1	\N
122	1	143	1	420	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	145	1	143	1	\N
115	1	144	1	411	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	146	1	144	1	\N
75	1	145	1	172	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	147	1	145	1	\N
77	1	146	1	309	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	148	1	146	1	\N
152	1	147	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	149	1	147	1	\N
120	1	148	1	154	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	150	1	148	1	\N
118	1	149	1	153	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	151	1	149	1	\N
37	1	150	1	47	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	152	1	150	1	\N
168	1	151	1	87	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	153	1	151	1	\N
149	1	152	1	398	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	154	1	152	1	\N
29	1	153	1	452	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	155	1	153	1	\N
8	1	154	1	283	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	156	1	154	1	\N
88	1	155	1	291	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	157	1	155	1	\N
233	1	156	1	367	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	158	1	156	1	\N
83	1	157	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	159	1	157	1	\N
154	1	158	1	311	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	160	1	158	1	\N
175	1	159	1	258	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	161	1	159	1	\N
69	1	160	1	323	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	162	1	160	1	\N
63	1	161	1	405	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	163	1	161	1	\N
189	1	162	1	32	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	164	1	162	1	\N
92	1	163	1	130	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	165	1	163	1	\N
140	1	164	1	234	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	166	1	164	1	\N
17	1	165	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	167	1	165	1	\N
87	1	166	1	481	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	166	1	\N
183	1	167	1	240	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	169	1	167	1	\N
4	1	168	1	11550000000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	110	1	168	1	\N
129	1	169	1	314	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	171	1	169	1	\N
193	1	170	1	183	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	172	1	170	1	\N
174	1	171	1	486	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	173	1	171	1	\N
57	1	172	1	178	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	174	1	172	1	\N
224	1	173	1	65	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	175	1	173	1	\N
232	1	174	1	277	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	176	1	174	1	\N
119	1	175	1	433	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	177	1	175	1	\N
55	1	176	1	100	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	178	1	176	1	\N
169	1	177	1	272	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	179	1	177	1	\N
125	1	178	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	180	1	178	1	\N
45	1	179	1	212	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	181	1	179	1	\N
60	1	180	1	151	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	182	1	180	1	\N
99	1	181	1	387	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	183	1	181	1	\N
179	1	182	1	158	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	184	1	182	1	\N
49	1	183	1	440	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	185	1	183	1	\N
230	1	184	1	438	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	186	1	184	1	\N
131	1	185	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	187	1	185	1	\N
0	1	186	1	1000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	1	1	186	1	\N
186	1	187	1	290	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	188	1	187	1	\N
198	1	188	1	417	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	189	1	188	1	\N
202	1	189	1	375	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	190	1	189	1	\N
22	1	190	1	178	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	191	1	190	1	\N
102	1	191	1	59	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	192	1	191	1	\N
124	1	192	1	95	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	193	1	192	1	\N
200	1	193	1	394	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	194	1	193	1	\N
54	1	194	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	195	1	194	1	\N
225	1	195	1	256	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	196	1	195	1	\N
134	1	196	1	128	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	197	1	196	1	\N
97	1	197	1	199	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	198	1	197	1	\N
84	1	198	1	22	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	199	1	198	1	\N
161	1	199	1	276	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	200	1	199	1	\N
228	1	200	1	451	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	201	1	200	1	\N
238	1	201	1	133	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	202	1	201	1	\N
65	1	202	1	460	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	203	1	202	1	\N
219	1	203	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	204	1	203	1	\N
56	1	204	1	489	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	205	1	204	1	\N
163	1	205	1	190	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	206	1	205	1	\N
192	1	206	1	221	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	207	1	206	1	\N
143	1	207	1	464	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	208	1	207	1	\N
61	1	208	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	209	1	208	1	\N
136	1	209	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	210	1	209	1	\N
71	1	210	1	353	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	211	1	210	1	\N
3	1	211	1	500000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	140	1	211	1	\N
145	1	212	1	396	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	212	1	212	1	\N
106	1	213	1	417	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	213	1	213	1	\N
138	1	214	1	46	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	214	1	214	1	\N
158	1	215	1	305	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	215	1	215	1	\N
123	1	216	1	337	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	216	1	216	1	\N
25	1	217	1	444	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	217	1	217	1	\N
240	1	218	1	479	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	218	1	218	1	\N
211	1	219	1	344	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	219	1	219	1	\N
241	1	220	1	113	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	220	1	220	1	\N
197	1	221	1	236	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	221	1	221	1	\N
170	1	222	1	480	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	222	1	222	1	\N
31	1	223	1	160	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	223	1	223	1	\N
160	1	224	1	318	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	224	1	224	1	\N
21	1	225	1	214	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	225	1	225	1	\N
67	1	226	1	163	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
66	1	227	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	227	1	227	1	\N
108	1	228	1	366	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	228	1	228	1	\N
86	1	229	1	320	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	229	1	229	1	\N
237	1	230	1	407	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	230	1	230	1	\N
74	1	231	1	204	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	231	1	231	1	\N
73	1	232	1	341	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	232	1	232	1	\N
217	1	233	1	18	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	233	1	233	1	\N
6	1	234	1	11550000000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	135	1	234	1	\N
36	1	235	1	229	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	235	1	235	1	\N
172	1	236	1	477	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	236	1	\N
53	1	237	1	94	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	237	1	237	1	\N
235	1	238	1	126	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	238	1	238	1	\N
113	1	239	1	112	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	239	1	239	1	\N
223	1	240	1	387	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	240	1	240	1	\N
209	1	241	1	265	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	241	1	241	1	\N
11	1	242	1	269	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	242	1	242	1	\N
5	2	109	1	725250000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	110	1	109	1	\N
4	2	168	1	11549995000000000	1	2n1AuoZK2MM3Y5MqJ7euRoQdQ4tdJrS7eVPVDYDxR8hNqszS72Fc	110	1	168	1	\N
3	2	211	1	499750000000	1	2n2QLbfLa1HBQroCPEFobQAmFqKW2z76U52jQi3E91AdecUWNofi	140	1	211	1	\N
5	3	109	1	1460750000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	110	1	109	1	\N
4	3	168	1	11549980000000000	4	2n1aTDa2Frk1rpjAnTnuwxWWeyHDotUT62bjrb85nRLT5CsipEGH	110	1	168	1	\N
3	3	211	1	499250000000	3	2n1QvPzm8VY3NWhU5A75pE6mMypFrN163MiQms7bSkCiyCjztr6Q	140	1	211	1	\N
7	4	134	1	735500000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	135	1	134	1	\N
4	4	168	1	11549980000000000	4	2n1aTDa2Frk1rpjAnTnuwxWWeyHDotUT62bjrb85nRLT5CsipEGH	110	1	168	1	\N
3	4	211	1	499250000000	3	2n1QvPzm8VY3NWhU5A75pE6mMypFrN163MiQms7bSkCiyCjztr6Q	140	1	211	1	\N
7	5	134	1	791750000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	135	1	134	1	\N
4	5	168	1	11549910000000000	18	2n1Z96zhsXbMaiiQT1MAqH2Jr9KR97mMrnNqJ4HiUq6YVWLVye32	110	1	168	1	\N
3	5	211	1	497500000000	10	2mznVaPc8sdgJZu3G338NRqkuRo9DCtVxZv7EsyhheGiC3GshyDe	140	1	211	1	\N
5	6	109	1	2252500000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	110	1	109	1	\N
4	6	168	1	11549910000000000	18	2n1Z96zhsXbMaiiQT1MAqH2Jr9KR97mMrnNqJ4HiUq6YVWLVye32	110	1	168	1	\N
3	6	211	1	497500000000	10	2mznVaPc8sdgJZu3G338NRqkuRo9DCtVxZv7EsyhheGiC3GshyDe	140	1	211	1	\N
5	7	109	1	3034000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	110	1	109	1	\N
4	7	168	1	11549850000000000	30	2n1VPFH2QS6om1NGmXCEbHzymD9rGmjogmYstJx4NfYHG9KCW1fx	110	1	168	1	\N
3	7	211	1	496000000000	16	2n16E9LYcpsj4WNh5ttgqXahYE9nWSSMw1e1EThhhRr3ToNHKrfV	140	1	211	1	\N
5	8	109	1	3790000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	110	1	109	1	\N
4	8	168	1	11549815000000000	37	2mzyj4ExAn1YvDViykrTivGnwqZiKy9QKfovGmGBhCUvGCAhn5ib	110	1	168	1	\N
3	8	211	1	495000000000	20	2n1R739t3Zpk2WEzDRxH3xrgbugXoiXPicZo9pMT37jJWVr2p5BZ	140	1	211	1	\N
7	9	134	1	755750000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	135	1	134	1	\N
4	9	168	1	11549780000000000	44	2mzwqk59tNq2QhxykzULcLiSkkzY5hHFkHzwgvP81A5h25L9EuDF	110	1	168	1	\N
3	9	211	1	494250000000	23	2n1RAkU4xpySCumxwr3Rsfq2keVrVBAfzdpYyNmb2frwwYZVPXCT	140	1	211	1	\N
5	10	109	1	4576750000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	110	1	109	1	\N
4	10	168	1	11549715000000000	57	2n18ixyeSHrAxBeiz2CQufDZY3eXHNt2XdwNSRcvQX8p9fpuayTP	110	1	168	1	\N
3	10	211	1	492500000000	30	2mzq5ZdqVDF17yf5VFtKho4DDWqGk9T3XXYub71KcwnyWFCewfX6	140	1	211	1	\N
7	11	134	1	1542500000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	135	1	134	1	\N
4	11	168	1	11549715000000000	57	2n18ixyeSHrAxBeiz2CQufDZY3eXHNt2XdwNSRcvQX8p9fpuayTP	110	1	168	1	\N
3	11	211	1	492500000000	30	2mzq5ZdqVDF17yf5VFtKho4DDWqGk9T3XXYub71KcwnyWFCewfX6	140	1	211	1	\N
7	12	134	1	1511500000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	135	1	134	1	\N
4	12	168	1	11549680000000000	64	2mzrjG3qT79gV66zSuLp6wfEDKV8sZKp28gjd29rZFAZKasWJuwd	110	1	168	1	\N
3	12	211	1	491750000000	33	2n1hWWUbh5KWGbCozc9ah3RvZVcQfHHK9Bvxu9CAVAiJwuzRAjRW	140	1	211	1	\N
7	13	134	1	2262250000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	135	1	134	1	\N
4	13	168	1	11549650000000000	70	2mzq7XyvJq2zQ1btbpFLiYdw8zu1ivMr7MBTsgYtAzMCeNVbv4nh	110	1	168	1	\N
3	13	211	1	491000000000	36	2mzxUg9UJuwVDus7KZHaxtKD7YTCRmBxcEPM1FLSMerGJQGDx4Dd	140	1	211	1	\N
5	14	109	1	5327500000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	110	1	109	1	\N
4	14	168	1	11549620000000000	76	2n1p1mQmpJMzg1LLoMJwL7jxKH8LJFeJrERXcs5zMrrRcDLtenbZ	110	1	168	1	\N
3	14	211	1	490250000000	39	2n2MwgPrMJFpHabijjNAmVdB1iDwDrveLd1HUCuHZRqYGx8iYBDD	140	1	211	1	\N
5	15	109	1	6155000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	110	1	109	1	\N
4	15	168	1	11549515000000000	97	2mzfwdbhkBUdHK6doZURaQG6tvDqVcZ838AxPcB9bYkYgXTCNkNh	110	1	168	1	\N
3	15	211	1	487750000000	49	2n1mhGYXwczMaTVxzZ3p8LaNX9M8T2Pj9dgN8BsuepdhxGtUhHdZ	140	1	211	1	\N
5	16	109	1	6906000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	110	1	109	1	\N
4	16	168	1	11549485000000000	103	2n1gSUnwHs55FAbCbUvyB61x8qdJPZY6wUWPZAdYqdW7Uyuye1KV	110	1	168	1	\N
3	16	211	1	486750000000	53	2mzisxw8swzkCnUuektSwURJ8j2winBGF96stoHy6wVSM6Ms2spc	140	1	211	1	\N
5	18	109	1	7661750000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	110	1	109	1	\N
4	18	168	1	11549450000000000	110	2mzjHUGN7TBLmZuyhzHqAf6t9yoqeo2YsUWa1uvgM5JDhoQHE3bY	110	1	168	1	\N
3	18	211	1	486000000000	56	2mzpmkvbUXamGitKC1BGoWNDVEMw61uUii9AHFRrV12bnxw9dRvx	140	1	211	1	\N
5	20	109	1	7692500000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	110	1	109	1	\N
4	20	168	1	11549385000000000	123	2n1hdoPoxjZF2CGcQkfpv8EXMXfYFmaJFWRjbqioBc58K5NYHuKn	110	1	168	1	\N
3	20	211	1	484500000000	62	2n1y4JQhcutBxowznnQByJ3MJXCu9EgNsu798GQWsPr8PPAgGMez	140	1	211	1	\N
5	22	109	1	8443500000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	110	1	109	1	\N
4	22	168	1	11549325000000000	135	2n2AMXWVo9k2CDBUriivu1aL7gtrUhWuPsXUgrGkgHTuiLFrjPSu	110	1	168	1	\N
3	22	211	1	482750000000	69	2mzozzPi1XeMEkWJb8Zt2D1cxeaEScYEfYYiE2BE3H1yjWxPBErr	140	1	211	1	\N
5	24	109	1	9950000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	110	1	109	1	\N
4	24	168	1	11549260000000000	148	2n2M2HoFEcxTXLbdCQnKuCsrwEx9Yw48YfoLC2tK9ehK6TJ3RV3d	110	1	168	1	\N
3	24	211	1	481250000000	75	2n2P8eTGkcpukWfFxcyEY6cKVxMg49rkuzYqAjtXKWVR7iHzBZ4w	140	1	211	1	\N
5	26	109	1	10741750000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	110	1	109	1	\N
4	26	168	1	11549160000000000	168	2mzsRqdEwpizFtsYcLpfxemnS4d1Zcry1hfpx5w4CdA9K7oYrJwJ	110	1	168	1	\N
3	26	211	1	478750000000	85	2n1u33eWWSVbDGr29v1cAA14qh171kXy8W7E2asxKdWmRRSxFkx1	140	1	211	1	\N
5	28	109	1	11492500000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	110	1	109	1	\N
4	28	168	1	11549130000000000	174	2n2FSRhvEqUAwXm9f99uyng4DgPjsm7XM4pHE4DyDqKeRZex5vUb	110	1	168	1	\N
3	28	211	1	478000000000	88	2n1Nqu5ZqchoJHbfGTdtRyRsZ4jEC9zNeiFUSuXUKPaECFhndSdN	140	1	211	1	\N
7	17	134	1	3018000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	135	1	134	1	\N
4	17	168	1	11549450000000000	110	2mzjHUGN7TBLmZuyhzHqAf6t9yoqeo2YsUWa1uvgM5JDhoQHE3bY	110	1	168	1	\N
3	17	211	1	486000000000	56	2mzpmkvbUXamGitKC1BGoWNDVEMw61uUii9AHFRrV12bnxw9dRvx	140	1	211	1	\N
7	19	134	1	3804500000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	135	1	134	1	\N
4	19	168	1	11549385000000000	123	2n1hdoPoxjZF2CGcQkfpv8EXMXfYFmaJFWRjbqioBc58K5NYHuKn	110	1	168	1	\N
3	19	211	1	484500000000	62	2n1y4JQhcutBxowznnQByJ3MJXCu9EgNsu798GQWsPr8PPAgGMez	140	1	211	1	\N
7	21	134	1	3768750000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	135	1	134	1	\N
4	21	168	1	11549355000000000	129	2n2CJg4dPPr8cssjMP62w4hidR6XZXLoHrdaCZuhXYTxFWmbkVLJ	110	1	168	1	\N
3	21	211	1	483750000000	65	2n1vd5zdp4JFzjCfdnt7TjvMAR7mtxc1TBueVCPf5ZivxTUnivgn	140	1	211	1	\N
5	23	109	1	9199250000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	110	1	109	1	\N
4	23	168	1	11549290000000000	142	2n2LHK9NfGqrHt8zJTb4PQxRDeNUvMHo5LfPSjgny2fpARzHmN2B	110	1	168	1	\N
3	23	211	1	482000000000	72	2mztp5iFXK15qHYi9FqFbXWMYauJKGebuT5vZVBzXPXJoEZ5KoVK	140	1	211	1	\N
7	25	134	1	4519500000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	135	1	134	1	\N
4	25	168	1	11549230000000000	154	2n1YHu2ENAZGUcf3GViog5Xh6Zn1YBdcv4MYwXtJafzwmnsHvtBz	110	1	168	1	\N
3	25	211	1	480500000000	78	2n1pwzVpN5FeUBniS32Vmk9CDPUUiLSK1GSPSHw85KhNDoUt5cXL	140	1	211	1	\N
7	27	134	1	5270250000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	135	1	134	1	\N
4	27	168	1	11549130000000000	174	2n2FSRhvEqUAwXm9f99uyng4DgPjsm7XM4pHE4DyDqKeRZex5vUb	110	1	168	1	\N
3	27	211	1	478000000000	88	2n1Nqu5ZqchoJHbfGTdtRyRsZ4jEC9zNeiFUSuXUKPaECFhndSdN	140	1	211	1	\N
7	29	134	1	5306250000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	135	1	134	1	\N
4	29	168	1	11549065000000000	187	2mznoeEaFCC9QsExjRJVrpLe5U8fbMw38bLSL4usRzw9JfuhwCNV	110	1	168	1	\N
3	29	211	1	476250000000	95	2mzzUA38tGkjPNMnZBZE1zuaARCG4XYLgTu43Xwjb6REQHVotFdm	140	1	211	1	\N
5	30	109	1	12248250000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	110	1	109	1	\N
4	30	168	1	11549030000000000	194	2n264cMNcjSwU18LcTvkhhdsgo4Z4uBeaWMgDe58hps9aij8L5d7	110	1	168	1	\N
3	30	211	1	475500000000	98	2mzdw9Umo4xSKcELonJzb2fStmCLy7tzj4xzNHBha6J4gbF8DmnT	140	1	211	1	\N
7	31	134	1	6062000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	135	1	134	1	\N
4	31	168	1	11549030000000000	194	2n264cMNcjSwU18LcTvkhhdsgo4Z4uBeaWMgDe58hps9aij8L5d7	110	1	168	1	\N
3	31	211	1	475500000000	98	2mzdw9Umo4xSKcELonJzb2fStmCLy7tzj4xzNHBha6J4gbF8DmnT	140	1	211	1	\N
7	32	134	1	6812750000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	135	1	134	1	\N
4	32	168	1	11549000000000000	200	2n1z3hhaN4vzjoTjFy4bCAgFS76tPPq9YCew7ZusyFCF2PUWPMC6	110	1	168	1	\N
3	32	211	1	474750000000	101	2n2L9qVL8VUysNn5fy6tyVQrAkqFaM2D9bpEa4syKnrg65FaX6vb	140	1	211	1	\N
7	33	134	1	7594250000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	135	1	134	1	\N
4	33	168	1	11548940000000000	212	2n1sj9HoaeqrnCAXCGmKHQocnon2DYadi6UQwLEyjpQuYT3mc2Dz	110	1	168	1	\N
3	33	211	1	473250000000	107	2n22sKbnvU9FBXr9BuxjRZtSRUt3KHVjS1NHmzzVzVgSACT269kq	140	1	211	1	\N
5	34	109	1	12274000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	110	1	109	1	\N
4	34	168	1	11548940000000000	212	2n1sj9HoaeqrnCAXCGmKHQocnon2DYadi6UQwLEyjpQuYT3mc2Dz	110	1	168	1	\N
3	34	211	1	473250000000	107	2n22sKbnvU9FBXr9BuxjRZtSRUt3KHVjS1NHmzzVzVgSACT269kq	140	1	211	1	\N
5	35	109	1	13024750000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	110	1	109	1	\N
4	35	168	1	11548910000000000	218	2mzaP6eybip3bBLRTaXrxXQbD9jUBEEkhNR32LKWm4Vc8HXw8aPm	110	1	168	1	\N
3	35	211	1	472500000000	110	2n1tM5KX6rCB1NncHvqSHsnwdRJMA9mntyPd49CmvkyRpCgmRrLn	140	1	211	1	\N
1	36	111	1	5041000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	112	1	111	1	\N
7	36	134	1	7568459000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	135	1	134	1	\N
4	36	168	1	11548875000000000	225	2mzZFAy24HKUnm59wBu4jZyz7FnGVV4kgzYD63AZT4yijdpT1roK	110	1	168	1	\N
3	36	211	1	471750000000	113	2mzhWVQ8mK8e7pjLxtWgAqsnwpSN2cqs7R86vnTVVFPadHWLw6A6	140	1	211	1	\N
5	37	109	1	13780459000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	110	1	109	1	\N
1	37	111	1	5041000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	112	1	111	1	\N
4	37	168	1	11548875000000000	225	2mzZFAy24HKUnm59wBu4jZyz7FnGVV4kgzYD63AZT4yijdpT1roK	110	1	168	1	\N
3	37	211	1	471750000000	113	2mzhWVQ8mK8e7pjLxtWgAqsnwpSN2cqs7R86vnTVVFPadHWLw6A6	140	1	211	1	\N
1	38	111	1	5042000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	112	1	111	1	\N
7	38	134	1	7558499000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	135	1	134	1	\N
4	38	168	1	11548850000000000	230	2n2Du93WzNfMhXf6jhNo6qzGWLbucswz2Xf78LKKy4tBLXD2vYtW	110	1	168	1	\N
3	38	211	1	471000000000	116	2mzkQ2oN2uafjvnjr28qTARP3siPh4275fy2DC5ZcWExRetU1EoE	140	1	211	1	\N
1	39	111	1	5043000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	112	1	111	1	\N
7	39	134	1	8309248000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	135	1	134	1	\N
4	39	168	1	11548820000000000	236	2mzj6yBihaFXrxJZ1FuE1Vj8QJfLKvTwKCffprL161MkaJK6v2zy	110	1	168	1	\N
3	39	211	1	470250000000	119	2mzuV5UNmsDfmbBm5jLcyUVG4Gabi4LocgPBXvc9fpQ5iDmgbLCi	140	1	211	1	\N
1	40	111	1	5044000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	112	1	111	1	\N
7	40	134	1	9065247000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	135	1	134	1	\N
4	40	168	1	11548785000000000	243	2n1dM7ufJRbhLw21KpLZ3yBmuidBjUT6ix6XaipZhgctx6rKwmXf	110	1	168	1	\N
3	40	211	1	469250000000	123	2n2AGXJ6cD7tdJonMYs1VSTJGHgR9wpZytX7tUYN9y1W8YDNQ6rS	140	1	211	1	\N
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
18	3NK3Xd7DtYocdxyHPQoUbur7wTDJjeixhC5WvU2tsaHgvLere12Q	16	3NLhbR9cywFLQ5TYYqU2rdBD4YqNFFPxbp2LzRZnN7mcb7MsDwqh	110	170	1U_6I8wIZtG5SYmTsEctxDvwwrg2PfGg-SmL0dgYWgw=	1	1	19	77	{1,4,6,3,7,7,7,7,7,7,7}	23166005000061388	jxVCfXeTd6wMr8oYs8ZwYGjjGcVRpjxWFidVmR5mkJLMhhvKfv2	14	25	25	1	\N	1753129046000	orphaned
26	3NKu2ngryJHKNt1j34rv6wZ252DCmL18fUyWYvGwDMujUq5FaxqQ	25	3NKs6SqEDjQCFpDDUfrcxMZVJdB6buczzz1EMwbvYKzZNsGxbrdk	110	170	ot_XpoGTzhFY2CvIBUArHHMjUFTkbAvX5MK5iHyfDQA=	1	1	27	77	{1,4,6,4,6,7,7,7,7,7,7}	23166005000061388	jxrfsoRC4gqsgW4m2DzWt9YSGndVfTDScV1C6PsDppgMbRzqnMV	21	34	34	1	\N	1753129316000	canonical
24	3NKjhbbbrczR4n2YZAt3uofSTbQ8CNzW1noqrYsnizCmFzkupW3A	23	3NLKCwzSJP2rpMfU4XrVKYbb9ckn8y2WAtRY8uE1XiCGj3agTN5k	110	170	CsIlU5_XO2qiD8FqNQfQEOs2xdl3N42WjIwXK__ilAQ=	1	1	25	77	{1,4,6,4,4,7,7,7,7,7,7}	23166005000061388	jxZPaLr4Nc1apCsv1d3ak2N7eXdud36qKQSf6YBEvd7SgMT6D4w	19	31	31	1	\N	1753129226000	canonical
22	3NLQ7Smb2c5aUhuHcfsJZ3KW94ZjRj2TLsXZ2UwPuzrtXGJDkiLK	21	3NKTbCukh9SeSPNtLbszoGi9yBfvsMT9ceCipcEZgYJiUrRdZwdS	110	170	1xpFsHrFvVX-bKhhDZ4VgrD2muHII6JmxiBL2EaH0ws=	1	1	23	77	{1,4,6,4,2,7,7,7,7,7,7}	23166005000061388	jwhkk2QTKDFyCLCFtDuUEWyx4PRAyALj5XeZkRupQHPLwHWzQwa	17	29	29	1	\N	1753129166000	canonical
20	3NKavhzf7gfpFsJ44PHJex3Ss1AJ57UYq2qnRz68Tn6Lge9mDTRr	17	3NKxtcsYxd6Bzh1Nmhsn28KTjC4qVAk8BPauzF5qtc7D3r5GNKVq	110	170	tIW1jzaZpuRZD1wFKUzt1L1-jkJxkV0CIhf_rjvKJAo=	1	1	21	77	{1,4,6,4,7,7,7,7,7,7,7}	23166005000061388	jxN8iWrLaX97maqKjwYER8u9FLCbX3dRJQ9NW5Dbkj6jcZiEcfP	15	27	27	1	\N	1753129106000	canonical
4	3NKD2mrxmipaBDKp5doE8gY7bPfkPwP42Tw7wCX8m8Jgzo6468Ad	2	3NLNnSnBEepGBpTXdRRtQvhuSAhPWJorzUEDE1ReHiqjwgda3pFY	135	234	j1e8qajav9ZlH1Wkg98nmuqXfyTcaguGGZsuUMFGKA4=	1	1	5	77	{1,2,7,7,7,7,7,7,7,7,7}	23166005000061388	jxnpHppccSfxgkef45AucA5HxfKLe1LPWzPja6Fb7fY7ZS21vEt	3	9	9	1	\N	1753128566000	orphaned
5	3NKQzmLH2n7AEMZ3mERdzFrHKYPic8X9vJYU5v7H11vDsRvqYuPe	3	3NLSDD99jreRbAMcJ2Uwjh2L3nyr2uYKHxoPTWKnXhdK52dmDNRJ	135	234	gUKECMHn0N3f7Fp7Zx-2Spt-iz41hD2IZJkFXTm18Ac=	1	1	6	77	{1,3,7,7,7,7,7,7,7,7,7}	23166005000061388	jxu4mypqnBGmDsvCgRGEVP9UqSm6c1XGNkitaRs3nrnER6EfxtA	4	11	11	1	\N	1753128626000	orphaned
6	3NKpUCU9PiE6S6E7mBYQeywEeNYTsmSR8kp51s7PCeVCWLUmzJHy	3	3NLSDD99jreRbAMcJ2Uwjh2L3nyr2uYKHxoPTWKnXhdK52dmDNRJ	110	170	ChyZIJ0Zh_cZliF0sXbH8zKtZVlBa3Y0w115wilbNQA=	1	1	7	77	{1,3,7,7,7,7,7,7,7,7,7}	23166005000061388	jxJqjQLqgShntTB3nh8VeNRmPcVH6QXZmSnwMns5LTJ3Fosg79f	4	11	11	1	\N	1753128626000	canonical
3	3NLSDD99jreRbAMcJ2Uwjh2L3nyr2uYKHxoPTWKnXhdK52dmDNRJ	2	3NLNnSnBEepGBpTXdRRtQvhuSAhPWJorzUEDE1ReHiqjwgda3pFY	110	170	jvW_HzbqiC1ChumBynOu_ZBKf339PkNGnYMpJx2fqgg=	1	1	4	77	{1,2,7,7,7,7,7,7,7,7,7}	23166005000061388	jwjMdJvVBejym6oV878ymBAuGUaT4EXaDA4WmCKDwc9BRyx5ALs	3	9	9	1	\N	1753128566000	canonical
2	3NLNnSnBEepGBpTXdRRtQvhuSAhPWJorzUEDE1ReHiqjwgda3pFY	1	3NKLxd1v6xMPGDnokeJMSH89Bosn74nJTqQg5yisBb29TXEUgMVa	110	170	PQ9jIpx1I4rvOZZVU-g-_M9GNj8y9T8EUaKavBdinwE=	1	1	3	77	{1,1,7,7,7,7,7,7,7,7,7}	23166005000061388	jxHFd5yNDb7HrfseKZU3yxCU6hQUgdpsd3kxK5ePdVFb9Da9srC	2	8	8	1	\N	1753128536000	canonical
1	3NKLxd1v6xMPGDnokeJMSH89Bosn74nJTqQg5yisBb29TXEUgMVa	\N	3NL7ZPc6EtxWBEHBRVC4yayhKHT3AKsKyjCAYpSr42syzSr4EPN7	1	1	39cyg4ZmMtnb_aFUIerNAoAJV8qtkfOpq0zFzPspjgM=	1	1	2	77	{1,7,7,7,7,7,7,7,7,7,7}	23166005000061388	jxjULJM2RAdPYPcv7WPA7KrBx9sSnx4cuuWogWm3Nd1K7Y3YdHR	1	0	0	1	\N	1753128296000	canonical
11	3NLP5qkoYcYCxxvGrJXPX7q1vEKZyJzt2viqLtbodN9cTzhRPAeW	9	3NLmYjCp7Uq7d6EqaAetv4Ldq9JFNsKQzbVH9Ntc7mSM2uecszdZ	135	234	Jb8eeXe7xKq1nLNm0NKXU0PR_3NkJyu4TW3tRRX7SwU=	1	1	12	77	{1,4,3,7,7,7,7,7,7,7,7}	23166005000061388	jxWLSQbdVPnf9K14fxgHXo1TYeY8SaPQV8amntoZsxw9fnhMaBd	8	17	17	1	\N	1753128806000	orphaned
30	3NKWTJhidu5mDoAVA5hHZcQXAxgRQSLiqwepZo6ukU68y2L9VF2j	29	3NKmD7vAp4HQzEhReQxVR3qC94PSYRLTcs5R7h7xJn3zbTp4AMFG	110	170	0zFfRNSiars9Sl5aNFNyZmT03__QF97F1llZ-eQD9wM=	1	1	31	77	{1,4,6,4,6,3,7,7,7,7,7}	23166005000061388	jx3qtEdDTjdbJ1Vcfbd5zd1rWztSN6shpPLyjetmSDSkHrYZjme	24	38	38	1	\N	1753129436000	orphaned
36	3NLgAdn4VL4uQypVxTs8hCH8F39F1XHiMHgQBkvgVHe2UZPoJTp6	35	3NKAtX9aEwXgHmKwTXPEoZcLH4TMhXErcP8UHHaqPi261npdD88v	135	234	s30mydetkTqOFzGRVDjMceiEpUX_oPiRcOC4pTQKPgw=	1	1	37	77	{1,4,6,4,6,5,2,7,7,7,7}	23166005000061388	jwbCsu3brcXMGea4uwSuCNUG4kKDGG5D5Zqfnt8mc9EVZGYXavd	28	43	43	1	\N	1753129586000	orphaned
34	3NLXbJDMM44ictYcDt8FnTY4yfiXStNN39yUMtWQ9hcYLb1zApZA	32	3NKcvWraSZZZHxMtt1MMd1yUpBd8FRyB6Kcxq1ZvmY3kYUgL2ctM	110	170	ETBAi0grKNi-BfP3yZVKKedHAHwPg4WF9e47D9whoAU=	1	1	35	77	{1,4,6,4,6,5,7,7,7,7,7}	23166005000061388	jx41hPcjxwkEfh9tmyS8SJERhMxqBswffKT7f3GeTiiuKAUSuHa	26	41	41	1	\N	1753129526000	canonical
32	3NKcvWraSZZZHxMtt1MMd1yUpBd8FRyB6Kcxq1ZvmY3kYUgL2ctM	31	3NLoS9b9pvqXjJ6RcVhUWX7vZVK726ea1AEhGMqXZyW5xCSeZ2ha	135	234	Cf1N4Mr86thpp6d-w1cdUmBEFnqFmUBwmkIg8OoVbAU=	1	1	33	77	{1,4,6,4,6,4,7,7,7,7,7}	23166005000061388	jxJ2DGhr7Z1KEU3E5QXAPv8gyr2G3ExUzmhg5kfrrXV1AzDb3EB	25	39	39	1	\N	1753129466000	canonical
28	3NL3Vz61bPdmtdP2d553hFU2q3UxWQSMoPHTXNgbKcUPLznW1sgw	26	3NKu2ngryJHKNt1j34rv6wZ252DCmL18fUyWYvGwDMujUq5FaxqQ	110	170	VeWYkwI7MxQwKyzs9lyKK7s7b-uV9tZ-Gygp5HqstQQ=	1	1	29	77	{1,4,6,4,6,1,7,7,7,7,7}	23166005000061388	jw9ySc4365UQZF1E1meEaiXkeZ1RZz9RKAGSoPChJtDWdFFGrDr	22	35	35	1	\N	1753129346000	canonical
17	3NKxtcsYxd6Bzh1Nmhsn28KTjC4qVAk8BPauzF5qtc7D3r5GNKVq	16	3NLhbR9cywFLQ5TYYqU2rdBD4YqNFFPxbp2LzRZnN7mcb7MsDwqh	135	234	ZhG4ugCCgG4VKkKrhfCuni1sB3Zu_JmLucVQV6HJfAI=	1	1	18	77	{1,4,6,3,7,7,7,7,7,7,7}	23166005000061388	jxWqT4egP4TzDxt6GzmEmKeXfNBWzyXFSbPEPJMddJCVP3VUvFD	14	25	25	1	\N	1753129046000	canonical
16	3NLhbR9cywFLQ5TYYqU2rdBD4YqNFFPxbp2LzRZnN7mcb7MsDwqh	15	3NKeHkfeohsDweqCgtXuNr6q1Gvc1es8fsARfvspFHDnAYV9RyaY	110	170	rl-qK9HYi_dzHJkFTKbzSLXt_ERuqZh3gwz3cCELBws=	1	1	17	77	{1,4,6,2,7,7,7,7,7,7,7}	23166005000061388	jwcFZANeDNuGyfnj12i5vm7scwdGgFKvbjxzWvYJ9SBsbeCvLWK	13	24	24	1	\N	1753129016000	canonical
15	3NKeHkfeohsDweqCgtXuNr6q1Gvc1es8fsARfvspFHDnAYV9RyaY	14	3NKqRTyreS94DwfUi3ZXNVjYuDFVKWBqNwFW1d8fB2rUntTKVswX	110	170	ee-fpcPVGUzXGOpzp3OJwyl-7QOBEia2HmJFbDDm1gQ=	1	1	16	77	{1,4,6,1,7,7,7,7,7,7,7}	23166005000061388	jwjNyBPyk9AjK8v3E99zJjy1rrVSKVsGaR6bg2qsBypxtfebyUh	12	23	23	1	\N	1753128986000	canonical
14	3NKqRTyreS94DwfUi3ZXNVjYuDFVKWBqNwFW1d8fB2rUntTKVswX	13	3NLnM8ShSW88aDuDCxx2wBdEiCjGjvGqoUG2KteSGcbsJwtjQfbn	110	170	qL54aHnTGh2zAfP7oQkrtCMctNtm7MLWETKiLBMhhgE=	1	1	15	77	{1,4,6,7,7,7,7,7,7,7,7}	23166005000061388	jxCrz2hzpja63WxeK2yHKtHLnVjTnXQNiUwnb1kAEbTJY11WWp1	11	20	20	1	\N	1753128896000	canonical
13	3NLnM8ShSW88aDuDCxx2wBdEiCjGjvGqoUG2KteSGcbsJwtjQfbn	12	3NKBfzNi46JPDzZ8HaWm5hsqJ8jVPfMG8EGeWRq2qZ1T33bQVXaK	135	234	kOpgXcBWM2r-yD6VvOnehGFOW7F6qYhsQfc0sKUzWgs=	1	1	14	77	{1,4,5,7,7,7,7,7,7,7,7}	23166005000061388	jwqHsKrjRPZnoqfSxaqqr6uw8cAt9vN18fogEsAR8MCFrmRNijc	10	19	19	1	\N	1753128866000	canonical
12	3NKBfzNi46JPDzZ8HaWm5hsqJ8jVPfMG8EGeWRq2qZ1T33bQVXaK	10	3NL4u53vqb9E2QhPr1vPbiodhHaiprGG4QYCnU6fsperzUjKop5e	135	234	7jP8zWqhd05A5EciDnLuI2DmBAPR-0_o6mW1B258eQA=	1	1	13	77	{1,4,4,7,7,7,7,7,7,7,7}	23166005000061388	jxui9rXwZkUSeRqKSZ69sxfuBpJiChWrUGp2RQ5wEDMp7R894KH	9	18	18	1	\N	1753128836000	canonical
10	3NL4u53vqb9E2QhPr1vPbiodhHaiprGG4QYCnU6fsperzUjKop5e	9	3NLmYjCp7Uq7d6EqaAetv4Ldq9JFNsKQzbVH9Ntc7mSM2uecszdZ	110	170	WUqjeS51av9RwXGehdAAQ4DMBSaYGpRw81m0tgPcrAc=	1	1	11	77	{1,4,3,7,7,7,7,7,7,7,7}	23166005000061388	jxzyckKYxVBwvZ3DZM4ZRNDTvxBvA3nDayHmMHF4qabbii6zGvS	8	17	17	1	\N	1753128806000	canonical
9	3NLmYjCp7Uq7d6EqaAetv4Ldq9JFNsKQzbVH9Ntc7mSM2uecszdZ	8	3NKh7kN8DkuRLYL5ZqSLJsP39XqRnUst8xAVmsXdnDeNfSPdwVzo	135	234	kRZ_ltwXMq0j043y63rWxZbCkrCYktmQX2V6OBANXw4=	1	1	10	77	{1,4,2,7,7,7,7,7,7,7,7}	23166005000061388	jxZUFAdYuoQ7A1XqCVsnTsw8mHyziC1DafqtyRKuEWwru48qkfi	7	15	15	1	\N	1753128746000	canonical
8	3NKh7kN8DkuRLYL5ZqSLJsP39XqRnUst8xAVmsXdnDeNfSPdwVzo	7	3NLr9LLpsXeDPgPCWhwaBg1B7Yu8HLkRhypqFLkWQf3XSNM2ZGWd	110	170	GKR9XTg2Vn6dc3OKRxoulhdTaQBqBxsRf7cpGaz8BgU=	1	1	9	77	{1,4,1,7,7,7,7,7,7,7,7}	23166005000061388	jwwGh9JmpQpjYq71U1PfsrAFTyR9wuK9n99ghxJ4v7JPJAYswiV	6	14	14	1	\N	1753128716000	canonical
7	3NLr9LLpsXeDPgPCWhwaBg1B7Yu8HLkRhypqFLkWQf3XSNM2ZGWd	6	3NKpUCU9PiE6S6E7mBYQeywEeNYTsmSR8kp51s7PCeVCWLUmzJHy	110	170	kL14vTu2kT7oShi7_WJsGLtpSqbpnaJxIGOMQAlDtQ8=	1	1	8	77	{1,4,7,7,7,7,7,7,7,7,7}	23166005000061388	jwnEJWpAFsi8Ye1qYtXTqRKberHD2QMv4HjEuWmeZqYQ8Uteag5	5	13	13	1	\N	1753128686000	canonical
19	3NLYJr8pYe5qC82ipyfa7ejdJocjCzNF1bfMry71rYdiebrCdKt8	17	3NKxtcsYxd6Bzh1Nmhsn28KTjC4qVAk8BPauzF5qtc7D3r5GNKVq	135	234	t46wlSUY0TUZZ6g3btIgoRG1_YAtRcRdAFW4gHLuuQY=	1	1	20	77	{1,4,6,4,7,7,7,7,7,7,7}	23166005000061388	jxWzt4jXF5m3bmxVS4wnXrzd2V5i8nwX8D9R4s2xRrdTwa8sgds	15	27	27	1	\N	1753129106000	orphaned
27	3NKkanQ8fQ2pFC2qqAu27zr1jL1c4s3EBVbdrxy5Do9VNiTQ7TCR	26	3NKu2ngryJHKNt1j34rv6wZ252DCmL18fUyWYvGwDMujUq5FaxqQ	135	234	Vz3H_LshvllTA_SJm8O9cop1JhYMxWI1F1KT5GlkNQU=	1	1	28	77	{1,4,6,4,6,1,7,7,7,7,7}	23166005000061388	jxEcNno2aZ39C4dyXWQcsAD4w2QCTjNnUeq3B6N3Wa1L4ccET3Z	22	35	35	1	\N	1753129346000	orphaned
33	3NKG9Ak6bSM7s7C4dHjSmVuF59rivKT9efV9eMXtuVVix5dpjKhu	32	3NKcvWraSZZZHxMtt1MMd1yUpBd8FRyB6Kcxq1ZvmY3kYUgL2ctM	135	234	1xjHKRKVKVxGOL029W1OYzDWDLp8oWVIUpjy1m4kvwc=	1	1	34	77	{1,4,6,4,6,5,7,7,7,7,7}	23166005000061388	jwNj6JJYJkrKhXJBS6RqwFGnJHQ8iNkWXkJAuXJV28RX4iNp9rw	26	41	41	1	\N	1753129526000	orphaned
39	3NLZTbQ5Cav7wUBbmKn9J2xiq7Xq9s76iU3E6HWbr2GgGdxCaeke	38	3NKJ1cfyivdjwccuLb1tosw8LHbPMkdoW5tUT9NoWTYYKZpekgxZ	135	234	niApy27piSbNM4tEFMlascitm6QysKnInvDhOPt3CQM=	1	1	40	77	{1,4,6,4,6,5,4,7,7,7,7}	23166005000061388	jxvN2g4ngrDBXg9yd8zCFF4MhHk7wVQ96MAagtpaYTsnRXscbGH	30	45	45	1	\N	1753129646000	orphaned
40	3NLgde3iH7W16NyeAChFeya5xKv5jWvrd2DjfG9G2QNdSz4mHzsg	39	3NLZTbQ5Cav7wUBbmKn9J2xiq7Xq9s76iU3E6HWbr2GgGdxCaeke	135	234	mNjlCWOMp3g5ahesoJ7eCN5uAo65hlEHr-zbnZHaUgk=	1	1	41	77	{1,4,6,4,6,5,5,7,7,7,7}	23166005000061388	jwwF5Tuf3n9BtcBN9uECkgJg7qK7969hb8HNDTE5rZUisS93dxP	31	46	46	1	\N	1753129676000	canonical
38	3NKJ1cfyivdjwccuLb1tosw8LHbPMkdoW5tUT9NoWTYYKZpekgxZ	37	3NKvrGsJpErxwEEpT25rbyio7cJXyfFenbeBVpyJsi2J1taX4UzP	135	234	jLFVi3gu4gC8BVRtk29RvZvhbA81biEcK25G_-AZAws=	1	1	39	77	{1,4,6,4,6,5,3,7,7,7,7}	23166005000061388	jweRNtYtdTzE5xSNkLegFM2qb87f8rWvyKQzBrMJGy7sC5CCmk9	29	44	44	1	\N	1753129616000	canonical
37	3NKvrGsJpErxwEEpT25rbyio7cJXyfFenbeBVpyJsi2J1taX4UzP	35	3NKAtX9aEwXgHmKwTXPEoZcLH4TMhXErcP8UHHaqPi261npdD88v	110	170	5gNr9BJWEFEBmpqYBQeal__lFWs74cuuXx2yGq_HdQY=	1	1	38	77	{1,4,6,4,6,5,2,7,7,7,7}	23166005000061388	jx8zQhfkXb4xvtLjLSsxTgZnMguRMcQEUdUgbXeDyVHWbQahLoa	28	43	43	1	\N	1753129586000	canonical
35	3NKAtX9aEwXgHmKwTXPEoZcLH4TMhXErcP8UHHaqPi261npdD88v	34	3NLXbJDMM44ictYcDt8FnTY4yfiXStNN39yUMtWQ9hcYLb1zApZA	110	170	X4ls4xmwSW7n8-MAkVvsZ6oBu63dA4ItAcr_ILZergs=	1	1	36	77	{1,4,6,4,6,5,1,7,7,7,7}	23166005000061388	jwTXHsodp6gBDzZcHbRpBVUCP78yJGH5d8AipBC4mJn8or745xk	27	42	42	1	\N	1753129556000	canonical
31	3NLoS9b9pvqXjJ6RcVhUWX7vZVK726ea1AEhGMqXZyW5xCSeZ2ha	29	3NKmD7vAp4HQzEhReQxVR3qC94PSYRLTcs5R7h7xJn3zbTp4AMFG	135	234	arYIjKtIb_I2QSEUOrtP8TV1YofmRMpHNG0ovFgG7Qg=	1	1	32	77	{1,4,6,4,6,3,7,7,7,7,7}	23166005000061388	jxpw7ngwPovC3S7MGT2m25rCPhdNMnkTxt84pBbApZtH5q7yPNE	24	38	38	1	\N	1753129436000	canonical
29	3NKmD7vAp4HQzEhReQxVR3qC94PSYRLTcs5R7h7xJn3zbTp4AMFG	28	3NL3Vz61bPdmtdP2d553hFU2q3UxWQSMoPHTXNgbKcUPLznW1sgw	135	234	KqynjHkkikz7FKguQDYEr4GvT0mcUQP-LTjwmjKjDwc=	1	1	30	77	{1,4,6,4,6,2,7,7,7,7,7}	23166005000061388	jxFpMeYBiwsUivsroCCP7GbAk9RkcvE1ydtgZgzD86ewp14aQ5h	23	37	37	1	\N	1753129406000	canonical
25	3NKs6SqEDjQCFpDDUfrcxMZVJdB6buczzz1EMwbvYKzZNsGxbrdk	24	3NKjhbbbrczR4n2YZAt3uofSTbQ8CNzW1noqrYsnizCmFzkupW3A	135	234	zerxEQ3vX21mfXAkOnDspDGuvgR7idBWBgrzUbeOKA4=	1	1	26	77	{1,4,6,4,5,7,7,7,7,7,7}	23166005000061388	jxxNiqkvxxNxLVvYpGCgHpacHcebS3mXTsgMBqj39J2vgF1hUFU	20	32	32	1	\N	1753129256000	canonical
23	3NLKCwzSJP2rpMfU4XrVKYbb9ckn8y2WAtRY8uE1XiCGj3agTN5k	22	3NLQ7Smb2c5aUhuHcfsJZ3KW94ZjRj2TLsXZ2UwPuzrtXGJDkiLK	110	170	kbAB6pW6rXblwDdSWtSijXYYSI5tYQCqv0DkgF52hwQ=	1	1	24	77	{1,4,6,4,3,7,7,7,7,7,7}	23166005000061388	jwSQKyc4wxzNidRZ3eJLw5RCm6tGRttWGB1z1eH383gfNZz2kVB	18	30	30	1	\N	1753129196000	canonical
21	3NKTbCukh9SeSPNtLbszoGi9yBfvsMT9ceCipcEZgYJiUrRdZwdS	20	3NKavhzf7gfpFsJ44PHJex3Ss1AJ57UYq2qnRz68Tn6Lge9mDTRr	135	234	1H1oAviuAs8x_NmhPSrWzd0jXYnwmJuGwGPssNcUHA4=	1	1	22	77	{1,4,6,4,1,7,7,7,7,7,7}	23166005000061388	jxLRgamAGEqqNK6r7feMmFyjh56Nvsjz1DKSaWk7fH85Ftjsyji	16	28	28	1	\N	1753129136000	canonical
\.


--
-- Data for Name: blocks_internal_commands; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.blocks_internal_commands (block_id, internal_command_id, sequence_no, secondary_sequence_no, status, failure_reason) FROM stdin;
2	1	2	0	applied	\N
2	2	3	0	applied	\N
3	1	5	0	applied	\N
3	3	6	0	applied	\N
4	4	5	0	applied	\N
4	5	6	0	applied	\N
5	4	21	0	applied	\N
5	6	22	0	applied	\N
6	1	21	0	applied	\N
6	7	22	0	applied	\N
7	1	18	0	applied	\N
7	8	19	0	applied	\N
8	1	11	0	applied	\N
8	9	12	0	applied	\N
9	4	10	0	applied	\N
9	10	11	0	applied	\N
10	1	20	0	applied	\N
10	11	21	0	applied	\N
11	4	20	0	applied	\N
11	12	21	0	applied	\N
12	4	10	0	applied	\N
12	10	11	0	applied	\N
13	4	9	0	applied	\N
13	13	10	0	applied	\N
14	14	3	0	applied	\N
14	1	10	0	applied	\N
14	15	11	0	applied	\N
15	1	31	0	applied	\N
15	16	32	0	applied	\N
16	1	10	0	applied	\N
16	17	11	0	applied	\N
17	4	10	0	applied	\N
17	10	11	0	applied	\N
18	1	10	0	applied	\N
18	18	11	0	applied	\N
19	4	19	0	applied	\N
19	19	20	0	applied	\N
20	1	19	0	applied	\N
20	20	20	0	applied	\N
21	4	9	0	applied	\N
21	13	10	0	applied	\N
22	1	10	0	applied	\N
22	17	11	0	applied	\N
23	1	10	0	applied	\N
23	18	11	0	applied	\N
24	21	6	0	applied	\N
24	1	10	0	applied	\N
24	22	11	0	applied	\N
25	4	9	0	applied	\N
25	13	10	0	applied	\N
26	1	21	0	applied	\N
26	7	22	0	applied	\N
27	4	9	0	applied	\N
27	13	10	0	applied	\N
28	1	9	0	applied	\N
28	23	10	0	applied	\N
29	4	20	0	applied	\N
29	12	21	0	applied	\N
30	1	10	0	applied	\N
30	18	11	0	applied	\N
31	4	10	0	applied	\N
31	10	11	0	applied	\N
32	4	9	0	applied	\N
32	13	10	0	applied	\N
33	4	18	0	applied	\N
33	24	19	0	applied	\N
34	1	18	0	applied	\N
34	8	19	0	applied	\N
35	1	9	0	applied	\N
35	23	10	0	applied	\N
36	25	1	0	applied	\N
36	26	11	0	applied	\N
36	27	11	0	applied	\N
36	28	12	0	applied	\N
36	29	12	1	applied	\N
37	30	1	0	applied	\N
37	26	11	0	applied	\N
37	31	11	0	applied	\N
37	32	12	0	applied	\N
37	28	12	1	applied	\N
38	26	8	0	applied	\N
38	27	8	0	applied	\N
38	33	9	0	applied	\N
39	26	9	0	applied	\N
39	27	9	0	applied	\N
39	13	10	0	applied	\N
40	26	11	0	applied	\N
40	27	11	0	applied	\N
40	34	12	0	applied	\N
\.


--
-- Data for Name: blocks_user_commands; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.blocks_user_commands (block_id, user_command_id, sequence_no, status, failure_reason) FROM stdin;
2	1	1	applied	\N
3	2	3	applied	\N
3	3	4	applied	\N
4	2	3	applied	\N
4	3	4	applied	\N
5	4	14	applied	\N
5	5	15	applied	\N
5	6	16	applied	\N
5	7	17	applied	\N
5	8	18	applied	\N
5	9	19	applied	\N
5	10	20	applied	\N
6	4	14	applied	\N
6	5	15	applied	\N
6	6	16	applied	\N
6	7	17	applied	\N
6	8	18	applied	\N
6	9	19	applied	\N
6	10	20	applied	\N
7	11	12	applied	\N
7	12	13	applied	\N
7	13	14	applied	\N
7	14	15	applied	\N
7	15	16	applied	\N
7	16	17	applied	\N
8	17	7	applied	\N
8	18	8	applied	\N
8	19	9	applied	\N
8	20	10	applied	\N
9	21	7	applied	\N
9	22	8	applied	\N
9	23	9	applied	\N
10	24	13	applied	\N
10	25	14	applied	\N
10	26	15	applied	\N
10	27	16	applied	\N
10	28	17	applied	\N
10	29	18	applied	\N
10	30	19	applied	\N
11	24	13	applied	\N
11	25	14	applied	\N
11	26	15	applied	\N
11	27	16	applied	\N
11	28	17	applied	\N
11	29	18	applied	\N
11	30	19	applied	\N
12	31	7	applied	\N
12	32	8	applied	\N
12	33	9	applied	\N
13	34	6	applied	\N
13	35	7	applied	\N
13	36	8	applied	\N
14	37	7	applied	\N
14	38	8	applied	\N
14	39	9	applied	\N
15	40	21	applied	\N
15	41	22	applied	\N
15	42	23	applied	\N
15	43	24	applied	\N
15	44	25	applied	\N
15	45	26	applied	\N
15	46	27	applied	\N
15	47	28	applied	\N
15	48	29	applied	\N
15	49	30	applied	\N
16	50	6	applied	\N
16	51	7	applied	\N
16	52	8	applied	\N
16	53	9	applied	\N
17	54	7	applied	\N
17	55	8	applied	\N
17	56	9	applied	\N
18	54	7	applied	\N
18	55	8	applied	\N
18	56	9	applied	\N
19	57	13	applied	\N
19	58	14	applied	\N
19	59	15	applied	\N
19	60	16	applied	\N
19	61	17	applied	\N
19	62	18	applied	\N
20	57	13	applied	\N
20	58	14	applied	\N
20	59	15	applied	\N
20	60	16	applied	\N
20	61	17	applied	\N
20	62	18	applied	\N
21	63	6	applied	\N
21	64	7	applied	\N
21	65	8	applied	\N
22	66	6	applied	\N
22	67	7	applied	\N
22	68	8	applied	\N
22	69	9	applied	\N
23	70	7	applied	\N
23	71	8	applied	\N
23	72	9	applied	\N
24	73	7	applied	\N
24	74	8	applied	\N
24	75	9	applied	\N
25	76	6	applied	\N
25	77	7	applied	\N
25	78	8	applied	\N
26	79	14	applied	\N
26	80	15	applied	\N
26	81	16	applied	\N
26	82	17	applied	\N
26	83	18	applied	\N
26	84	19	applied	\N
26	85	20	applied	\N
27	86	6	applied	\N
27	87	7	applied	\N
27	88	8	applied	\N
28	86	6	applied	\N
28	87	7	applied	\N
28	88	8	applied	\N
29	89	13	applied	\N
29	90	14	applied	\N
29	91	15	applied	\N
29	92	16	applied	\N
29	93	17	applied	\N
29	94	18	applied	\N
29	95	19	applied	\N
30	96	7	applied	\N
30	97	8	applied	\N
30	98	9	applied	\N
31	96	7	applied	\N
31	97	8	applied	\N
31	98	9	applied	\N
32	99	6	applied	\N
32	100	7	applied	\N
32	101	8	applied	\N
33	102	12	applied	\N
33	103	13	applied	\N
33	104	14	applied	\N
33	105	15	applied	\N
33	106	16	applied	\N
33	107	17	applied	\N
34	102	12	applied	\N
34	103	13	applied	\N
34	104	14	applied	\N
34	105	15	applied	\N
34	106	16	applied	\N
34	107	17	applied	\N
35	108	6	applied	\N
35	109	7	applied	\N
35	110	8	applied	\N
36	111	8	applied	\N
36	112	9	applied	\N
36	113	10	applied	\N
37	111	8	applied	\N
37	112	9	applied	\N
37	113	10	applied	\N
38	114	5	applied	\N
38	115	6	applied	\N
38	116	7	applied	\N
39	117	6	applied	\N
39	118	7	applied	\N
39	119	8	applied	\N
40	120	7	applied	\N
40	121	8	applied	\N
40	122	9	applied	\N
40	123	10	applied	\N
\.


--
-- Data for Name: blocks_zkapp_commands; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.blocks_zkapp_commands (block_id, zkapp_command_id, sequence_no, status, failure_reasons_ids) FROM stdin;
2	1	0	failed	{1,2}
3	2	0	failed	{3,2}
3	3	1	failed	{4}
3	4	2	failed	{3,2}
4	2	0	failed	{3,2}
4	3	1	failed	{4}
4	4	2	failed	{3,2}
5	5	0	failed	{4}
5	6	1	failed	{3,2}
5	7	2	failed	{4}
5	8	3	failed	{3,2}
5	9	4	failed	{4}
5	10	5	failed	{3,2}
5	11	6	failed	{4}
5	12	7	failed	{3,2}
5	13	8	failed	{4}
5	14	9	failed	{3,2}
5	15	10	failed	{4}
5	16	11	failed	{3,2}
5	17	12	failed	{4}
5	18	13	failed	{3,2}
6	5	0	failed	{4}
6	6	1	failed	{3,2}
6	7	2	failed	{4}
6	8	3	failed	{3,2}
6	9	4	failed	{4}
6	10	5	failed	{3,2}
6	11	6	failed	{4}
6	12	7	failed	{3,2}
6	13	8	failed	{4}
6	14	9	failed	{3,2}
6	15	10	failed	{4}
6	16	11	failed	{3,2}
6	17	12	failed	{4}
6	18	13	failed	{3,2}
7	19	0	failed	{4}
7	20	1	failed	{3,2}
7	21	2	failed	{4}
7	22	3	failed	{3,2}
7	23	4	failed	{4}
7	24	5	failed	{3,2}
7	25	6	failed	{4}
7	26	7	failed	{3,2}
7	27	8	failed	{4}
7	28	9	failed	{3,2}
7	29	10	failed	{4}
7	30	11	failed	{3,2}
8	31	0	failed	{4}
8	32	1	failed	{3,2}
8	33	2	failed	{4}
8	34	3	failed	{3,2}
8	35	4	failed	{4}
8	36	5	failed	{3,2}
8	37	6	failed	{4}
9	38	0	failed	{3,2}
9	39	1	failed	{4}
9	40	2	failed	{3,2}
9	41	3	failed	{4}
9	42	4	failed	{3,2}
9	43	5	failed	{4}
9	44	6	failed	{3,2}
10	45	0	failed	{4}
10	46	1	failed	{3,2}
10	47	2	failed	{4}
10	48	3	failed	{3,2}
10	49	4	failed	{4}
10	50	5	failed	{3,2}
10	51	6	failed	{4}
10	52	7	failed	{3,2}
10	53	8	failed	{4}
10	54	9	failed	{3,2}
10	55	10	failed	{4}
10	56	11	failed	{3,2}
10	57	12	failed	{4}
11	45	0	failed	{4}
11	46	1	failed	{3,2}
11	47	2	failed	{4}
11	48	3	failed	{3,2}
11	49	4	failed	{4}
11	50	5	failed	{3,2}
11	51	6	failed	{4}
11	52	7	failed	{3,2}
11	53	8	failed	{4}
11	54	9	failed	{3,2}
11	55	10	failed	{4}
11	56	11	failed	{3,2}
11	57	12	failed	{4}
12	58	0	failed	{3,2}
12	59	1	failed	{4}
12	60	2	failed	{3,2}
12	61	3	failed	{4}
12	62	4	failed	{3,2}
12	63	5	failed	{4}
12	64	6	failed	{3,2}
13	65	0	failed	{4}
13	66	1	failed	{3,2}
13	67	2	failed	{4}
13	68	3	failed	{3,2}
13	69	4	failed	{4}
13	70	5	failed	{3,2}
14	71	0	failed	{4}
14	72	1	failed	{3,2}
14	73	2	failed	{4}
14	74	4	failed	{3,2}
14	75	5	failed	{4}
14	76	6	failed	{3,2}
15	77	0	failed	{4}
15	78	1	failed	{3,2}
15	79	2	failed	{4}
15	80	3	failed	{3,2}
15	81	4	failed	{4}
15	82	5	failed	{3,2}
15	83	6	failed	{4}
15	84	7	failed	{3,2}
15	85	8	failed	{4}
15	86	9	failed	{3,2}
15	87	10	failed	{4}
15	88	11	failed	{3,2}
15	89	12	failed	{4}
15	90	13	failed	{3,2}
15	91	14	failed	{4}
15	92	15	failed	{3,2}
15	93	16	failed	{4}
15	94	17	failed	{3,2}
15	95	18	failed	{4}
15	96	19	failed	{3,2}
15	97	20	failed	{4}
16	98	0	failed	{3,2}
16	99	1	failed	{4}
16	100	2	failed	{3,2}
16	101	3	failed	{4}
16	102	4	failed	{3,2}
16	103	5	failed	{4}
17	104	0	failed	{3,2}
17	105	1	failed	{4}
17	106	2	failed	{3,2}
17	107	3	failed	{4}
17	108	4	failed	{3,2}
17	109	5	failed	{4}
17	110	6	failed	{3,2}
18	104	0	failed	{3,2}
18	105	1	failed	{4}
18	106	2	failed	{3,2}
18	107	3	failed	{4}
18	108	4	failed	{3,2}
18	109	5	failed	{4}
18	110	6	failed	{3,2}
19	111	0	failed	{4}
19	112	1	failed	{3,2}
19	113	2	failed	{4}
19	114	3	failed	{3,2}
19	115	4	failed	{4}
19	116	5	failed	{3,2}
19	117	6	failed	{4}
19	118	7	failed	{3,2}
19	119	8	failed	{4}
19	120	9	failed	{3,2}
19	121	10	failed	{4}
19	122	11	failed	{3,2}
19	123	12	failed	{4}
20	111	0	failed	{4}
20	112	1	failed	{3,2}
20	113	2	failed	{4}
20	114	3	failed	{3,2}
20	115	4	failed	{4}
20	116	5	failed	{3,2}
20	117	6	failed	{4}
20	118	7	failed	{3,2}
20	119	8	failed	{4}
20	120	9	failed	{3,2}
20	121	10	failed	{4}
20	122	11	failed	{3,2}
20	123	12	failed	{4}
21	124	0	failed	{3,2}
21	125	1	failed	{4}
21	126	2	failed	{3,2}
21	127	3	failed	{4}
21	128	4	failed	{3,2}
21	129	5	failed	{4}
22	130	0	failed	{3,2}
22	131	1	failed	{4}
22	132	2	failed	{3,2}
22	133	3	failed	{4}
22	134	4	failed	{3,2}
22	135	5	failed	{4}
23	136	0	failed	{3,2}
23	137	1	failed	{4}
23	138	2	failed	{3,2}
23	139	3	failed	{4}
23	140	4	failed	{3,2}
23	141	5	failed	{4}
23	142	6	failed	{3,2}
24	143	0	failed	{4}
24	144	1	failed	{3,2}
24	145	2	failed	{4}
24	146	3	failed	{3,2}
24	147	4	failed	{4}
24	148	5	failed	{3,2}
25	149	0	failed	{4}
25	150	1	failed	{3,2}
25	151	2	failed	{4}
25	152	3	failed	{3,2}
25	153	4	failed	{4}
25	154	5	failed	{3,2}
26	155	0	failed	{4}
26	156	1	failed	{3,2}
26	157	2	failed	{4}
26	158	3	failed	{3,2}
26	159	4	failed	{4}
26	160	5	failed	{3,2}
26	161	6	failed	{4}
26	162	7	failed	{3,2}
26	163	8	failed	{4}
26	164	9	failed	{3,2}
26	165	10	failed	{4}
26	166	11	failed	{3,2}
26	167	12	failed	{4}
26	168	13	failed	{3,2}
27	169	0	failed	{4}
27	170	1	failed	{3,2}
27	171	2	failed	{4}
27	172	3	failed	{3,2}
27	173	4	failed	{4}
27	174	5	failed	{3,2}
28	169	0	failed	{4}
28	170	1	failed	{3,2}
28	171	2	failed	{4}
28	172	3	failed	{3,2}
28	173	4	failed	{4}
28	174	5	failed	{3,2}
29	175	0	failed	{4}
29	176	1	failed	{3,2}
29	177	2	failed	{4}
29	178	3	failed	{3,2}
29	179	4	failed	{4}
29	180	5	failed	{3,2}
29	181	6	failed	{4}
29	182	7	failed	{3,2}
29	183	8	failed	{4}
29	184	9	failed	{3,2}
29	185	10	failed	{4}
29	186	11	failed	{3,2}
29	187	12	failed	{4}
31	188	0	failed	{3,2}
31	189	1	failed	{4}
31	190	2	failed	{3,2}
31	191	3	failed	{4}
31	192	4	failed	{3,2}
31	193	5	failed	{4}
31	194	6	failed	{3,2}
33	201	0	failed	{4}
33	202	1	failed	{3,2}
33	203	2	failed	{4}
33	204	3	failed	{3,2}
33	205	4	failed	{4}
33	206	5	failed	{3,2}
33	207	6	failed	{4}
33	208	7	failed	{3,2}
33	209	8	failed	{4}
33	210	9	failed	{3,2}
33	211	10	failed	{4}
33	212	11	failed	{3,2}
35	213	0	failed	{4}
35	214	1	failed	{3,2}
35	215	2	failed	{4}
35	216	3	failed	{3,2}
35	217	4	failed	{4}
35	218	5	failed	{3,2}
30	188	0	failed	{3,2}
30	189	1	failed	{4}
30	190	2	failed	{3,2}
30	191	3	failed	{4}
30	192	4	failed	{3,2}
30	193	5	failed	{4}
30	194	6	failed	{3,2}
32	195	0	failed	{4}
32	196	1	failed	{3,2}
32	197	2	failed	{4}
32	198	3	failed	{3,2}
32	199	4	failed	{4}
32	200	5	failed	{3,2}
34	201	0	failed	{4}
34	202	1	failed	{3,2}
34	203	2	failed	{4}
34	204	3	failed	{3,2}
34	205	4	failed	{4}
34	206	5	failed	{3,2}
34	207	6	failed	{4}
34	208	7	failed	{3,2}
34	209	8	failed	{4}
34	210	9	failed	{3,2}
34	211	10	failed	{4}
34	212	11	failed	{3,2}
36	219	0	failed	{4}
36	220	2	failed	{3,2}
36	221	3	failed	{4}
36	222	4	failed	{3,2}
36	223	5	failed	{4}
36	224	6	failed	{3,2}
36	225	7	failed	{4}
37	219	0	failed	{4}
37	220	2	failed	{3,2}
37	221	3	failed	{4}
37	222	4	failed	{3,2}
37	223	5	failed	{4}
37	224	6	failed	{3,2}
37	225	7	failed	{4}
38	226	0	failed	{3,2}
38	227	1	failed	{4}
38	228	2	failed	{3,2}
38	229	3	failed	{4}
38	230	4	failed	{3,2}
39	231	0	failed	{4}
39	232	1	failed	{3,2}
39	233	2	failed	{4}
39	234	3	failed	{3,2}
39	235	4	failed	{4}
39	236	5	failed	{3,2}
40	237	0	failed	{4}
40	238	1	failed	{3,2}
40	239	2	failed	{4}
40	240	3	failed	{3,2}
40	241	4	failed	{4}
40	242	5	failed	{3,2}
40	243	6	failed	{4}
\.


--
-- Data for Name: epoch_data; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.epoch_data (id, seed, ledger_hash_id, total_currency, start_checkpoint, lock_checkpoint, epoch_length) FROM stdin;
1	2va9BGv9JrLTtrzZttiEMDYw1Zj6a6EHzXjmP9evHDTG3oEquURA	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	1
2	2vafPBQ3zQdHUEDDnFGuiNvJz7s2MhTLJgSzQSnu5fnZavT27cms	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NL7ZPc6EtxWBEHBRVC4yayhKHT3AKsKyjCAYpSr42syzSr4EPN7	2
3	2vbR4uey9WswwovzVCQ5setrJLGVG3R59zFxDYB6yK7JVDjNyMfo	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKLxd1v6xMPGDnokeJMSH89Bosn74nJTqQg5yisBb29TXEUgMVa	3
4	2vaurdiDeLF2Eoz5uF59M3sGUew9MbFHGTudnfrkXhLBrB8jRmZN	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLNnSnBEepGBpTXdRRtQvhuSAhPWJorzUEDE1ReHiqjwgda3pFY	4
5	2vaTV4ezDmcCZ5qChTAUJkK4MFCN3BWtTpuEtFc5pRxFF5vwzBVy	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLNnSnBEepGBpTXdRRtQvhuSAhPWJorzUEDE1ReHiqjwgda3pFY	4
6	2vaHfqPFsvYTNiX7KbzuaSVdnqtEWnzjyyFJLdWiUNSEttiXVLgN	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLSDD99jreRbAMcJ2Uwjh2L3nyr2uYKHxoPTWKnXhdK52dmDNRJ	5
7	2vad6vFaQBNy3rDTjrRCwTQiyD7SoCMuBKPYFWVcJ8BvqyGJrxCM	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLSDD99jreRbAMcJ2Uwjh2L3nyr2uYKHxoPTWKnXhdK52dmDNRJ	5
8	2vaAQRUMyLQgRvEQpHG3rdzDqP2PLe2Hu1FyvdMJ1VRSJvQWbeZ1	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKpUCU9PiE6S6E7mBYQeywEeNYTsmSR8kp51s7PCeVCWLUmzJHy	6
9	2vawzpbBn7us2tdu5QyCa7FULRB6ya3k1oBzchta1NUFPNvkfzNm	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLr9LLpsXeDPgPCWhwaBg1B7Yu8HLkRhypqFLkWQf3XSNM2ZGWd	7
10	2vbc9doRW9KVJxjYBihRwLcL8TFQmmixoLHHjgt4Kg9SxSDnxwJi	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKh7kN8DkuRLYL5ZqSLJsP39XqRnUst8xAVmsXdnDeNfSPdwVzo	8
11	2vawkFP6KQvW5b2SsoWmvZ5KMiooCvgwTdkJNsHvcoQ2JzG6RYEf	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLmYjCp7Uq7d6EqaAetv4Ldq9JFNsKQzbVH9Ntc7mSM2uecszdZ	9
12	2vap2NFiCEXrqDobirUVX7y1UW7bZTL8WDiTSgqSnw4uFuK9AVyL	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLmYjCp7Uq7d6EqaAetv4Ldq9JFNsKQzbVH9Ntc7mSM2uecszdZ	9
13	2vaaMyUnfS4X4qgjvbUTwLZj2Y1QuWoeCFocinMhmfGxJXr7E9Eo	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NL4u53vqb9E2QhPr1vPbiodhHaiprGG4QYCnU6fsperzUjKop5e	10
14	2vbVTEkiNtjqmgNp8hYMj14ccKtYWJSQ8AcsadCgnn4yFBtgHqpW	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKBfzNi46JPDzZ8HaWm5hsqJ8jVPfMG8EGeWRq2qZ1T33bQVXaK	11
15	2vb5Ajzbhqp1po1rRiz6E6H7YdrsGEcNgkU4BPF73UKEV78gpmC8	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLnM8ShSW88aDuDCxx2wBdEiCjGjvGqoUG2KteSGcbsJwtjQfbn	12
16	2vaA9zaaDMRiXXwqUPAuCN5v5LFiogphy8pZuN1HLkG1X7Nazxc5	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKqRTyreS94DwfUi3ZXNVjYuDFVKWBqNwFW1d8fB2rUntTKVswX	13
17	2vaFzcwKWtNzkG4ZA6eBDyTXdwuqqdCgXmLvJM6J1LTjtDEfD5Yr	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKeHkfeohsDweqCgtXuNr6q1Gvc1es8fsARfvspFHDnAYV9RyaY	14
18	2vabCFjFkwQWyqngCEtMibSbRzWFgymaWGU5PXWH8Pgvgc93yDmY	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLhbR9cywFLQ5TYYqU2rdBD4YqNFFPxbp2LzRZnN7mcb7MsDwqh	15
19	2vb5dHgnMwydx5HLfmHaZ5FCz2V75Ae2uNkgTHv61ThiNFwxYiTw	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLhbR9cywFLQ5TYYqU2rdBD4YqNFFPxbp2LzRZnN7mcb7MsDwqh	15
20	2vbc6WK6aieqwmoiiYtnUUxT69NWi7J9MexfGHBuVWjtHh9b4dmt	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKxtcsYxd6Bzh1Nmhsn28KTjC4qVAk8BPauzF5qtc7D3r5GNKVq	16
21	2vboCjZh1T8HeVs1pij8b65T1CwxeX6bW4KQPnu8soyg8oH5mhvR	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKxtcsYxd6Bzh1Nmhsn28KTjC4qVAk8BPauzF5qtc7D3r5GNKVq	16
22	2vbTrquA7zvjNQPF3ua33cCd7Z9pUJ8qmdfWJVRYooDB94GQV3NZ	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKavhzf7gfpFsJ44PHJex3Ss1AJ57UYq2qnRz68Tn6Lge9mDTRr	17
23	2vbjsS51TSc33CSpcK56JMLniUxhFJxVaDHQXaKdewMepNdCuNks	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKTbCukh9SeSPNtLbszoGi9yBfvsMT9ceCipcEZgYJiUrRdZwdS	18
24	2vbmVjZ4DmpJcoav1QwDhZPvj9C5agkypwWxbKkBuSzbnbmb1beV	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLQ7Smb2c5aUhuHcfsJZ3KW94ZjRj2TLsXZ2UwPuzrtXGJDkiLK	19
25	2vaz1i5caviLU2ZSLB264HcGrctQkY2r9eKtkESpLaH8VP6xPCir	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLKCwzSJP2rpMfU4XrVKYbb9ckn8y2WAtRY8uE1XiCGj3agTN5k	20
26	2vaYQME7bEhmy2YGqWbUKvKJj1NTRr5gvNrFSpuLNfcs5thVRGZi	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKjhbbbrczR4n2YZAt3uofSTbQ8CNzW1noqrYsnizCmFzkupW3A	21
27	2vaqZSJxtu7rvgbP3WhdnXcmcG3xjfRcJKG5F1WghhvedMh6CwL2	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKs6SqEDjQCFpDDUfrcxMZVJdB6buczzz1EMwbvYKzZNsGxbrdk	22
28	2vbX2kFrJFkV6txfsauLTf4CYrVVNhWBepUu5DeyHZ3t5FJmVTeJ	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKu2ngryJHKNt1j34rv6wZ252DCmL18fUyWYvGwDMujUq5FaxqQ	23
29	2vbJQKqLU2M924XixcEf7ynD98U5rd9QXne9L2PJAcoauMSPAwb5	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKu2ngryJHKNt1j34rv6wZ252DCmL18fUyWYvGwDMujUq5FaxqQ	23
30	2vbAroUYbkEFZMbRkRtYcrCLXoJDp2ELtAECfCZcRVQXB8bmKUrR	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NL3Vz61bPdmtdP2d553hFU2q3UxWQSMoPHTXNgbKcUPLznW1sgw	24
31	2vax4nwo4k7uLSs3fDSr6qZeWt3iH38rwEX243SHTcV8WJGu79pX	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKmD7vAp4HQzEhReQxVR3qC94PSYRLTcs5R7h7xJn3zbTp4AMFG	25
32	2vaXEhGri51NeQWe3KaYBe8kTJWzZm3sHGXNBBo5MBRmvT36YXbE	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKmD7vAp4HQzEhReQxVR3qC94PSYRLTcs5R7h7xJn3zbTp4AMFG	25
33	2vanc8kHqGtVjKmjxNz7KUjfvSJJbFEicE5TceprqDqkMabux9z3	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLoS9b9pvqXjJ6RcVhUWX7vZVK726ea1AEhGMqXZyW5xCSeZ2ha	26
34	2vbojG3GpgrbQinytRUkdcjofVQbTUGsaPX26m41WauiVHTdhT9u	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKcvWraSZZZHxMtt1MMd1yUpBd8FRyB6Kcxq1ZvmY3kYUgL2ctM	27
35	2vaoqXo2XQxYLE4PDv7DmHPsDVRQEB9wqrycwwrAnNeAaMrg2rmh	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKcvWraSZZZHxMtt1MMd1yUpBd8FRyB6Kcxq1ZvmY3kYUgL2ctM	27
36	2vbL28bTr4BuWB52cBEgXx3UHorRUwpHTT28E11eGsNRTwBSs2Ys	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLXbJDMM44ictYcDt8FnTY4yfiXStNN39yUMtWQ9hcYLb1zApZA	28
38	2vbTxrp1NqSDHdh7DJ5MNyMNy8gh9VqG4ZfYw3iYEFpbUuwgVJLm	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKAtX9aEwXgHmKwTXPEoZcLH4TMhXErcP8UHHaqPi261npdD88v	29
40	2vbFAtSuMPvXLaMoR74U5TJ4gEZ4Ev9tKum5TNaQ8sFnUX4oiawE	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKJ1cfyivdjwccuLb1tosw8LHbPMkdoW5tUT9NoWTYYKZpekgxZ	31
37	2vbfz1XzBP8ywDrNNiPPB6kri1X7kdvVWFi6qXa1esXCfwAjyB33	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKAtX9aEwXgHmKwTXPEoZcLH4TMhXErcP8UHHaqPi261npdD88v	29
39	2vaHDbYLRZdTWQGUYqGvzHKuaWTMzvXWeKah8YFPWueTRqAD8xdJ	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKvrGsJpErxwEEpT25rbyio7cJXyfFenbeBVpyJsi2J1taX4UzP	30
41	2vaFFixWPKXeJykqxsLpL2wBJZ4RVsyf8VMnKs2iuDPtnYnE3YGF	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLZTbQ5Cav7wUBbmKn9J2xiq7Xq9s76iU3E6HWbr2GgGdxCaeke	32
\.


--
-- Data for Name: internal_commands; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.internal_commands (id, command_type, receiver_id, fee, hash) FROM stdin;
1	coinbase	110	720000000000	5Jv9Lej4HEZharLn2Zur1woorVMXtPUPU7B6GPrx6cbRnRZ6C5Kt
2	fee_transfer	110	5250000000	5JtnPaBuEM2W9JF3JUNc5cY1jFErW8TwdKMN1qNJceDxnzZXL4nJ
3	fee_transfer	110	15500000000	5Ju6ji3RzQsxVTwB4vV433B6UbqCr7Rrj6wCNwS7R6QBd8xmEXoR
4	coinbase	135	720000000000	5JutouqHbdZdNnD4XMe34gijvKNDfkHpS2D17ujHaSXJ3mUzgjEZ
5	fee_transfer	135	15500000000	5JuEsu1dErTN4baExTzygVyUUKw7ssNwhPonZMi2XXTLMUHx72Ca
6	fee_transfer	135	71750000000	5JtZDfQdMzRhCtqaZuyWN9at1fFvoKmAF9hKaAYoZBrx1GCdDFSu
7	fee_transfer	110	71750000000	5Jun2Vf6vs7Vt58ZYEVQv4Qans9aHuYJivBCWusmJsm7rb3agb5M
8	fee_transfer	110	61500000000	5JumKufKBZBSV1Hz7fbhrEnastZYFusMJZpFDES8pvj1Z47iP4Jn
9	fee_transfer	110	36000000000	5JuLC2g1vWut1NFS36pZWEc3Qr3KV7zN884KNCPpSFqw8NatppP4
10	fee_transfer	135	35750000000	5JuW2HqGYmK6PRNmdjquFqgM6pxZjbDYYgh8mj9GkzF4WyMFCeWo
11	fee_transfer	110	66750000000	5Jtpe76FE37dCkRaZyhPKV7dNL8bWKtnjuNVzedzW8vHnA7vA64g
12	fee_transfer	135	66750000000	5JuVzwhfh46t7WMmSdHr2jGDsRw4R51SJcd8uTQRFqWpMW4GV8dk
13	fee_transfer	135	30750000000	5Ju2h2d3wL4aovk94DX362pL3raLcBdhD9kDR7LbEGSoCUvnRE5L
14	fee_transfer	110	15000000000	5JvPd7QupH5S69YZA2szLicF7FhenebrvigXqfvUkQ8qF9yzxd89
15	fee_transfer	110	15750000000	5JueaGguCfhoP3aZzqsBcVgAjFD5JnHmNKdxA1n2268LUyXe2meo
16	fee_transfer	110	107500000000	5Jv8ULmWeNf1mZGRqtLkHricsPJ4zuHVVNXT8eS7fAkeZYmUDovr
17	fee_transfer	110	31000000000	5JuN1ckJY6gqqC72t5ZRpjyfAjBH6gbPkvSdgLSa9KpXsSZK2eja
18	fee_transfer	110	35750000000	5Jts2EHqFjZ78zUB5L5dNobGA2PG5Fom4S35ahRjb9JneGHRcGZi
19	fee_transfer	135	66500000000	5JvF8mmh6RmN667pwxtLQQRVgepcS74ykU9m5Yp94ytRqN4KX1nj
20	fee_transfer	110	66500000000	5Juza1bqmPwAe25afXstsQ9LBgPtXGhjpVvESnrGHoU8KTBHbF2W
21	fee_transfer	110	30000000000	5JtdjcwEmm9Waua8ifcCG3hsdycHU9juuBEtjQcZXHXN8AWcHWGt
22	fee_transfer	110	750000000	5JutDT22QnjBVoY6kFYHhUhzZa4N8WsNJBxwCG7ZWjumGgE7LqSD
23	fee_transfer	110	30750000000	5Jtb3cVGGyYHRp3E32hBd5X3zVXEc9JPnEd4xGQuivD2eP7sPtoh
24	fee_transfer	135	61500000000	5JvCej67WoajWtTU2CfjaeY71owB2DjpjKvtb5UuZLDwHPBFcdNb
25	fee_transfer	135	5000000000	5Ju4Jgh4Dbzp5huiAQZGK2rvYL7c1PVvcRRTBGTWBXVj7DUpNFZn
26	fee_transfer_via_coinbase	112	1000000	5JuWf9dUfYSZtCpYTWpMKrhvMoJJTCvqvwm2XtrGVVJrjdUUhSgf
27	coinbase	135	720000000000	5JttvN2mkoqEYBPsbLZq5qzg1RGhrmbGhvX35wKyA9dFFUbdKgTQ
28	fee_transfer	112	40000000	5Ju8nfBKKxidkPJuit9DgnPYztNzoLXCSr3YaffVtTAE1f3uxpdn
29	fee_transfer	135	30710000000	5JvQX4sqqapPjN8eLNspZPsdbjBsttJcnmnQXTgLasaJz82sfCXT
30	fee_transfer	110	5000000000	5Ju41hJ4ZbAR9j7asFS9auMWEWmAA2eaoooPx8gGdYCX8Z43ra2q
31	coinbase	110	720000000000	5JufXoo3X1jvjv68SCrybVwkwBbLEU9757KsiEAznrAFQ56BeAeD
32	fee_transfer	110	30710000000	5JvKj4XVfar3gwSvLa9mrM7spjCdqTCyuFWEGiNBgSUyq2ko12yD
33	fee_transfer	135	25750000000	5JurBjc39PwR6Rqy2PerTtWyaarRa6vo7k2VmTbyVbZUaUwtABMH
34	fee_transfer	135	36000000000	5JuJDVvcobQ32WYZF4AiVS69xAkbDVRiKeeH8TkDqRfzKvVTtfox
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
11	B62qmRRtdPM1XRnHpchjrVdVyRtUKFX5Nmrhu7MWSs3wDVsLuTQ54dV
12	B62qnT7rV3ZQ71n6Z2RaPZSn38zEniZq1A8CXEdArxrF7q6sTTWZdZc
13	B62qmnTkaf43Ctbxq1NgvtakVwKKcB1nk2vee61bMAcPfDB5FR5upJN
14	B62qpTgN6VhfdCGimamFjarhSBfiK1oGEKyrqHN5FHejeJR8Z2vgKYt
15	B62qkaFHyAx1TMzuez3APX1hG33j2ZXCTXJFFzeSxgt8fA3henaeT84
16	B62qkCd6ftXqh39xPVb7qyJkSWZYa12QCsxFCaCmDrvfZoTNYmKQtkC
17	B62qrEWSxSXzp8QLDpvuJKeHWxybsE2iwaMPViMpdjptmUxQbtDV178
18	B62qnUCyUPAGE9ZXcu2TpkqUPaU3fhgzxRSEiyt5C8V7mcgNNvj1oc9
19	B62qiquMTUSJa6qqyd3hY2PjkxiUqgPEN2NXYhP56SqwhJoBsFfEF5T
20	B62qm174LzHrFzjwo3jRXst9LGSYjY3gLiCzniUkVDMW912gLBw63iZ
21	B62qrrLFhpise34oGcCsDZMSqZJmy9X6q7DsJ4gSAFSEAJakdwvPbVe
22	B62qo11BPUzNFEuVeskPRhXHYa3yzf2WoGjdZ2hmeBT9RmgFoaLE34A
23	B62qmSTojN3aDbB311Vxc1MwbkdLJ4NCau8d6ZURTuX9Z57RyBxWgZX
24	B62qiaEMrWiYdK7LcJ2ScdMyG8LzUxi7yaw17XvBD34on7UKfhAkRML
25	B62qoGEe4SECC5FouayhJM3BG1qP6kQLzp3W9Q2eYWQyKu5Y1CcSAy1
26	B62qn8rXK3r2GRDEnRQEgyQY6pax17ZZ9kiFNbQoNncMdtmiVGnNc8Y
27	B62qnjQ1xe7MS6R51vWE1qbG6QXi2xQtbEQxD3JQ4wQHXw3H9aKRPsA
28	B62qmzatbnJ4ErusAasA4c7jcuqoSHyte5ZDiLvkxnmB1sZDkabKua3
29	B62qrS1Ry5qJ6bQm2x7zk7WLidjWpShRig9KDAViM1A3viuv1GyH2q3
30	B62qqSTnNqUFqyXzH2SUzHrW3rt5sJKLv1JH1sgPnMM6mpePtfu7tTg
31	B62qkLh5vbFwcq4zs8d2tYynGYoxLVK5iP39WZHbTsqZCJdwMsme1nr
32	B62qiqUe1zktgV9SEmseUCL3tkf7aosu8F8HPZPQq8KDjqt3yc7yet8
33	B62qkNP2GF9j8DQUbpLoGKQXBYnBiP7jqNLoiNUguvebfCGSyCZWXrq
34	B62qr4z6pyzZvdfrDi33Ck7PnPe3wddZVaa7DYzWHUGivigyy9zEfPh
35	B62qiWZKC4ff7RKQggVKcxAy9xrc1yHaXPLJjxcUtjiaDKY4GDmAtCP
36	B62qqCpCJ7Lx7WuKCDSPQWYZzRWdVGHndW4jNARZ8C9JB4M5osqYnvw
37	B62qo9mUWwGSjKLpEpgm5Yuw5qTXRi9YNvo5prdB7PXMhGN6jeVmuKS
38	B62qpRvBE7SFJWG38WhDrSHsm3LXMAhdiXXeLkDqtGxhfexCNh4RPqZ
39	B62qoScK9pW5SBdJeMZagwkfqWfvKAKc6pgPFrP72CNktbGKzVUdRs3
40	B62qkT8tFTiFfZqPmehQMCT1SRRGon6MyUBVXYS3q9hPPJhusxHLi9L
41	B62qiw7Qam1FnvUHV4JYwffCf2mjcuz2s5F3LK9TBa5e4Vhh7gq2um1
42	B62qrncSq9df3SnHmSjFsk13W7PmQE5ujZb7TGnXggawp3SLb1zbuRR
43	B62qip9dMNE7fjTVpB7n2MCJhDw89YYKd9hMsXmKZ5cYuVzLrsS46ZG
44	B62qmMc2ec1D4V78sHZzhdfBA979SxUFGKTqHyYcKexgv2zJn6MUghv
45	B62qqmQhJaEqxcggMG9GepiXrY1j4WgerXXb2NwkmABwrkhRK671sSn
46	B62qp7yamrqYvcAv3jJ4RuwdvWnb8zFGfXchbfqR4BCkeub998mVJ3j
47	B62qk7NGhMEpPAwdwfqnxCbAuCm1qawX4YXh956nanhkfDdzZ4vZ91g
48	B62qnUPwKuUQZcNFnr5L5S5mpH9zcKDdi2FsKnAGQ1Vrd3F4HcH724A
49	B62qqMV93QdKFLmPnqvzaBE8T2jY38HVch4JW5xZr4kNHNYr1VtSUn8
50	B62qmtQmCLX8msSHASDTzNtXq81XQoNtLz6CUMhFeueMbJoQaYbyPCi
51	B62qp2Jgs8ChRsQSh93cL2SuDN8Umqp6GtDd9Ng7gpkxgw3Z9WXduAw
52	B62qo131ZAwzBd3mhd2GjTf3SjuNqdieDifuYqnCGkwRrD3VvHLM2N1
53	B62qo9XsygkAARYLKi5jHwXjPNxZaf537CVp88npjrUpaEHypF6TGLj
54	B62qnG8dAvhGtPGuAQkwUqcwpiAT9pNjQ7iCjpYw5k2UT3UZTFgDJW1
55	B62qj3u5Ensdc611cJpcmNKq1ddiQ63Xa8L2DnFqEBgNqBCAqVALeAK
56	B62qjw1BdYXp74JQGoeyZ7bWtnsPPd4iCxBzfUsiVjmQPLk8984dV9D
57	B62qpP2xUscwDA5TaQee71MGvU7dYXiTHffdL4ndRGktHBcj6fwqDcE
58	B62qo1he9m5vqVfbU26ZRqSdyWvkVURLxJZLLwPdu1oRAp3E7rCvyxk
59	B62qjzHRw1dhwS1NCWDH64yzovyxsbrvqBW846BRCaWmyJyoufddBSA
60	B62qkoANXg95uVHwpLAiQsT1PaGxuXBcrBzdjMgN3mP5WJxiE1uYcG9
61	B62qnzk698yW9rmyeC8mLCKhdmQZa2TRCG5hN3Z5NovZZqE1oou7Upc
62	B62qrQDYA9DvUNdgU87xp64MsQm3MxBeDRNuhuwwQ3hfS5sJhchipzu
63	B62qnSKLuJiF1gNnCEDHJeWFKPbYLKjXqz18pnLGE2pUq7PBYnU4h95
64	B62qk8onaP8h1VYVbJkQQ8kKtHszsA12Haw3ts5jm4AkpvNDkhUtKBH
65	B62qnbQoJyaGKvgRDthSPwWZPrYiYCpqeYoHhJ9415r1ws6DecWa8h9
66	B62qmpV1DwQvBMUmBxyDV6jJwSpS1zFWHHEZYuXYhPja4RWCbYG3Hv1
67	B62qiYSHjqf77rS6eBiBSiDwgqpsZEUf8KZZNmpxzULpxqm58u49m7M
68	B62qrULyp6Kp5PAmtJMHcRngmHyU2t9DF2oBpU4Q1GMvfrgsUBVUSm8
69	B62qpitzPa3MB2eqJucswcwQrN3ayxTTKNMWLW7SwsvjjR4kTpC57Cr
70	B62qpSfoFPJPXvyUwXWGJqTVya4kqThCH5LyEsdKrmqRm1mvDrgsz1V
71	B62qk9uVP24E5fE5x4FxnFxz17TBAZ4rrkmRDErheEZnVyFmCKvdBMH
72	B62qjeNbQNefZdv388wHg9ancPdFBw6Dj2Wxo6Jyw2EhR7J9kti48qx
73	B62qqwCS1S72xt9VPD6C6FjJkdwDghRCWJnYjebCagX8M2xzthqKDQC
74	B62qrGWHg32ZdFydA4UF7prU4zm3UH3dRxJZ5xAHW1QtNhgzuP2G62z
75	B62qkqZ1b8BkCK9PqWnQLjYueExVUVJon1Nn15SnZScG5AR3LqkEqzY
76	B62qkQ9tPTmzm9oD2i8HbDRERFBHvG7Mi3dz6XLa3BEJcwA4ZcQaDa8
77	B62qnt4FQxWNcP49W5HaQNEe5Q1KqTBQJnnyqn7KyvSfNb6Dskbhy9i
78	B62qoxTxNh4o9ftUHSRatjTQagToJy7pW1zh7zZdyFYr9ECNDvugmyx
79	B62qrPuf95oqANBTTmvcvM1BKkBNrsmaXnaNpHGJYersezYTHWq5BTh
80	B62qkBdApDjoUj9Lckf4Bg7fWJSzSnyJHyCNkvq7XsPVzWk97BeGkae
81	B62qs23tCNy7qbrYHBwMfVNyiA82aA7xtWKh3QkFr1fMog3ptyXhptq
82	B62qpMFwmJ6fMm4cUb9wLLwoKRPFpYUJQmYqDe7RRaXgvAHjJpnEz3f
83	B62qkF4qisEVJ3WBdxcWoianq4YLaYXw89yJRzc7cPRu2ujXqp4v8Ji
84	B62qmFcUZJgxBQpTxnQHjyHWdprnsmRDiTZe6NiMNF9drGTM8hh1tZf
85	B62qo4Pc6HKhbc55RZuPrDfzbVZfxDqxkG3hV7sRDSivAthXAjtWaGg
86	B62qoKioA9hueF4xhZszsACn6GT7o69wZZJUoErVyvgP7WPrj92e9Tv
87	B62qkoTczRzwCUr6AmSiNcr3UWwkgbWeihVZphwP8CEuiDzrNHvunTX
88	B62qpGkYNpBS3MBgortSQuwV1aXcK6bRRQyYz3wGW5tCpCLdvxk8J6q
89	B62qnYfsf8P7B7UYcjN9bwL7HPpNrAJh7fG5zqWvZnSsaQJP2Z1qD84
90	B62qpAwcFY3oTy2oFUEc3gB4x879CvPqHUqHqjT3PiGxggroaUYHxkm
91	B62qib1VQVfLQeCW6oAKEX2GRuvXjYaX2Lw9qqjkBPAvdshHPyJXVMv
92	B62qm5TQe1nz3gfHqb6S4FE7FWV92AaKzUuAyNSDNeNJYgND35JaK8w
93	B62qrmfQsKRd5pwg1EZNYXSmcbsgCekCkJAxxJcZhWyX7ChfExZtFAj
94	B62qitvFhawB29DGkGv9NEfGZ8d9hECEKnKMHAvtULVATdw5epPS2s6
95	B62qo81kkuqxFZw9cZAcoYb4ZeCjY9HodT3yDkh8Zxhg9omfRexyNAz
96	B62qmeDPPUDtPVVHqesiKD7ecz6YZvGDHzVw2swBa84EGs5NBKpGK4H
97	B62qqwLQXBrhJmfAtF7GUf7FNVS2xoTPrkyw7d4Pj9W431bpysAdr3V
98	B62qkgcEQJ9qhjwQgt2XeN3RJpPTfjCrqFUUAW2NsVpzmyQwFbekNMM
99	B62qnAotEqbcE8sjbdyJkkvKnTzW3BCPaL5HrMEdHa4pVnfPBXWGXXW
100	B62qquzjE4bbK3mhk6jtFMnkm9BdzasTHuvMxx6JmhXeYKZkPbyZUry
101	B62qrj3VHfVadkyJCvmu7SvczS7QZy1Yk1uQjcjwkS4QqDt9oqi4eWf
102	B62qn6fTLLatKHi4aCX7p6Lg5rzZSq6VK2vrFVgX14gjaQqay8zHfsJ
103	B62qjrBApNy5mx6biRzL5AfRrDEarq3kv9Zcf5LcUR6iKAX9ve5vvud
104	B62qkdysBPreF3ef7bFEwCghYjbywFgumUHXYKDrBkUB89KgisAFGSV
105	B62qmRjcL489UysBEnabin5be824q7ok4VjyssKNutPq3YceMRSW4gi
106	B62qo3TjT6pu6i7UT8w39UVQc2Ljg8K69eng55vu5itof3Ma3qwcgZF
107	B62qpXFq7VJG6Spy7BSYjqSC1GBwKLCzfU8bcrUrALEFEXphpvjn3bG
108	B62qmp2xXJyj9LegRQUtFMCCGV3DQu337n6s6BK8a2kaYrMf1MmZHkT
109	B62qpjkSafKdAeCBh6PV6ZizJjtfs3v1DuXu1WowkYq2Bcr5X7bmk7G
110	B62qo9hznZofKVEo1JdyVyDokd8NRxSZzHbx7u7WBpci44pXfPYihdH
111	B62qnjhGUFX636v8HyJsYKUkAS5ms58q9C9GtwNvPbMzMVy7FmRNhLG
112	B62qpctayraXoTe7gUkFnMJsi73Yssbo1zBU1VTR42Qy1uz16w8sKta
113	B62qoCS2htWnx3g8gFq2ypSLHMW1jkZF6XMTH8yKE8gYTH7jfrcdjCo
114	B62qk2wpLtL3PUEQZBYPeabiXcZi6yzbVimciFWZSCHpxufKFDTmhi6
115	B62qjWRcn5eRmdppcsDNudiogbnNPzW4jWC6XH2LczMRDXzjK9AgfA2
116	B62qjJrgSK4wa3HnZZqmfJzxtMfACK9r2zEHqo5Rm6UUvyFrk4UjdPW
117	B62qoq6uA96gWVYBDtMQLZC5hB4hgAVojbuhw9Z2CE1Acj6iESSS1cE
118	B62qkSpe1P6FgwWU3BfvU2FXnuYt2vR4DzsEZf5TbJynBgyZy7W9yyE
119	B62qr225GCSVzAGKBYxB7rKE6ibtQAcfcXMfYH84hvkqHWAnFzWR4RT
120	B62qkQT9sAztAWnYdxQMaQSxrA93DRa5f8LxWCEzYA3Y3tewDQKUMyQ
121	B62qieyc3j9pYR6aA8DC1rhoUNRiPacx1ij6qW534VwTtuk8rF2UBrk
122	B62qoFyzjU4pC3mFgUidmTFt9YBnHjke5SU6jcNe7vVcvvoj4CCXYJf
123	B62qihY3kUVYcMk965RMKfEAYRwgh9ATLBWDiTzivneCmeEahgWTE58
124	B62qm8kJSo4SZt7zmNP29aYAUqETjPq6ge2hj5TxZWxWK2JDscQtx1Y
125	B62qkY3LksqsR2ETeNmAHAmYxi7mZXsoSgGMEMujrPtXQjRwxe5Bmdn
126	B62qrJ9hFcVQ4sjveJpQUsXZenisBnXKVzDdPntw48PYXxP17DNdKg4
127	B62qpKCYLZz2Eyb9vFfaVPgWjTWf1p3VpBLnQSSme2RC3ob4m1p8fCv
128	B62qkFYQghamWpPuNxzr1zw6ARk1mKFwkdQWJqHvmxdM95d45AjwWXE
129	B62qnzhgbY3HD19eKMeQTFPZijFTvJN82pHeGYQ2xM9HxZRPv6xhtqe
130	B62qroho2SKx4wignPPRf2qPbGzvfRgQf4zCMioxnmwKyLZCg3reYPc
131	B62qm4jN36Cwbtyd8j3BLevPK7Yhpv8KtWTia5fuwMAyvcHLCosU4PN
132	B62qk9Dk1rwSVtSLCYdWNfPTXRPDWPPu3rR5sqvrawP82m9P1LhBZ94
133	B62qnR8RErysAmsLHk6E7teSg56Dr3RyF6qWycyVjQhoQCVC9GfQqhD
134	B62qo7XmFPKML7WfgUe9FvCMUrMihfapBPeCJh9Yxfka7zUwy1nNDCY
135	B62qkGhq3VihfRX4UYrk3srmeU5oppboanJctQuxhxTJsEjX46ma1A3
136	B62qqZw4bXrb8PCxvEvRJ9DPASPPaHyoAWXw1avG7mEjnkFy7jGLz1i
137	B62qkFKcfRwVgdQ1UDhhCoExwsMPNWFJStxnDtJ1hNVmLzzGsyCRLuo
138	B62qofSbCaTfL61ZybYEpAeGe14TK8wNN8VFDV8uUEVBGpqVDAxYePK
139	B62qqVaPpuZpZddxYtGMKBpCwVyuHfW7sh7ucRN33CPycmLBoM6HdSL
140	B62qia6hzqd1yvgEZeTq7yxLCdZjzqfiVWGbYxc1kjKhrjcXWf4eh9d
141	B62qn8Vo7WTK4mwQJ8sjiQvbWDavetBS4f3Gdi42KzQZmL3sri25rFp
142	B62qo6pZqSTym2umKYeZ53F1woYCuX3qHrUtTezBoztURNRDAiNbq5Q
143	B62qo8AvB3EoCWAogvUg6wezt5GkNRTZmYXCw5Gutj8tAg6cdffX3kr
144	B62qqF7gk2yFsigWL7JyW1R8sdUcQjAPkp32i9B6f9GRYMzFoLPdBqJ
145	B62qjdhhu4bsmbMFxykEgbhf4atVvgQWB4dizqsMEBbmQPe9GeXZ42N
146	B62qmCsUFPNLpExtzt6NUeosa8L5qb7cEKi9btkMdAQS2GnQzTMjUGM
147	B62qneAWh9zy9ufLxKJfgrccdGfbgeoswyjPJp2WLhBpWKM7wMJtLZM
148	B62qoqu7NDPVJAdZPJWjia4gW3MHk9Cy3JtpACiVbvBLPYw7pWyn2vL
149	B62qmwfTv4co8uACHkz9hJuUND9ubZfpP2FsAwvru9hSg5Hb8rtLbFS
150	B62qkhxmcB6vwRxLxKZV2R4ifFLfTSCdtxJ8nt94pKVbwWd9MshJadp
151	B62qjYRWXeQ52Y9ADFTp55p829ZE7DE4zn9Nd8puJc2QVyuiooBDTJ3
152	B62qo3b6pfzKVWNFgetepK6rXRekLgAYdfEAMHT6WwaSn2Ux8frnbmP
153	B62qncxbMSrL1mKqCSc6huUwDffg5qNDDD8FHtUob9d3CE9ZC2EFPhw
154	B62qpzLLC49Cb6rcpFyCroFiAtGtBCXny9xRbuMKi64vsU5QLoWDoaL
155	B62qj7bnmz2VYRtJMna4bKfUYX8DyQeqxKEmHaKSzE9L6v7fjfrMbjF
156	B62qnEQ9eQ94BxdECbFJjbkqCrPYH9wJd7B9rzKL7EeNqvYzAUCNxCT
157	B62qokmEKEJs6VUV7QwFaHHfEr6rRnFXQe9jbodnaDuWzfUK6YoXt2w
158	B62qpPJfgTfiSghnXisMvgTCNmyt7dA5MxXnpHfMaDGYGs8C3UdGWm7
159	B62qkzi5Dxf6oUaiJYzb5Kq78UG8fEKnnGuytPN78gJRdSK7qvkDK6A
160	B62qs2sRxQrpkcJSkzNF1WKiRTbvhTeh2X8LJxB9ydXbBNXimCgDQ8k
161	B62qoayMYNMJvSh27WJog3K74996uSEFDCmHs7AwkBX6sXiEdzXn9SQ
162	B62qibjCrFmXT3RrSbHgjtLHQyb63Q89gBLUZgRj7KMCeesF9zEymPP
163	B62qrw63RAyz2QfqhHk8pttD2ussturr1rvneUWjAGuhsrGgzxr2ZRo
164	B62qmNVzYukv4VxXoukakohrGNK7yq1Tgjv5SuX1TTWmpvVwD5Xnu2L
165	B62qoucdKZheVHX8udLGmo3vieCnyje5dvAayiLm8trYEp3op9jxCMa
166	B62qo51F51yp7PcqmHd6G1hpNBAj3kwRSQvKmy5ybd675xVJJVtMBh8
167	B62qjHbDMJGPUz3M6JK2uC3tm6VPLaEtv4sMCcrMBz6hnD5hrET4RJM
168	B62qnyxTMk4JbYsaMx8EN2KmoZUsb9Zd3nvjwyrZr2GdAHC9nKF16PY
169	B62qrPo6f9vRwqDmgfNYzaFd9J3wTwQ1SC72yMAxwaGpjt2vJrxo4ri
170	B62qkwjinSw9PUp9XzWvv5MNbkYftHb9ZzLWfszaxHJBntDSvoNkRuL
171	B62qoZXUxxowQuERSJWb6EkoyciRthxycW5csa4cQkZUfm151sn8BSa
172	B62qr7QqCysRpMbJGKpAw1JsrZyQfSyT4iYoP4MsTYungBDJgwx8vXg
173	B62qo3JqbYXcuW75ZHMSMnJX7qbU8QF3N9k9DhQGbw8RKNP6tNQsePE
174	B62qjCC8yevoQ4ucM7fw4pDUSvg3PDGAhvWxhdM3qrKsnXW5prfjo1o
175	B62qnAcTRHehWDEuKmERBqSakPM1dg8L3JPSZd5yKfg4UNaHdRhiwdd
176	B62qruGMQFShgABruLG24bvCPhF2yHw83eboSqhMFYA3HAZH9aR3am3
177	B62qiuFiD6eX5mf4w52b1GpFMpk1LHtL3GWdQ4hxGLcxHh36RRmjpei
178	B62qokvW3jFhj1yz915TzoHubhFuR6o8QFQReVaTFcj8zpPF52EU9Ux
179	B62qr6AEDV6T66apiAX1GxUkCjYRnjWphyiDro9t9waw93xr2MW6Wif
180	B62qjYBQ6kJ9PJTTPnytp4rnaonUQaE8YuKeimJXHQUfirJ8UX8Qz4L
181	B62qqB7CLD6r9M532oCDKxxfcevtffzkZarWxdzC3Dqf6LitoYhzBj9
182	B62qr87pihBCoZNsJPuzdpuixve37kkgnFJGq1sqzMcGsB95Ga5XUA6
183	B62qoRyE8Yqm4GNkjnYrbtGWJLYLNoqwWzSRRBw8MbmRUS1GDiPitV7
184	B62qm4NwW8rFhUh4XquVC23fn3t8MqumhfjGbovLwfeLdxXQ3KhA9Ai
185	B62qmAgWQ9WXHTPh4timV5KFuHWe1GLb4WRDRh31NULbyz9ub1oYf8u
186	B62qroqFW16P7JhyaZCFsUNaCYg5Ptutp9ECPrFFf1VXhb9SdHE8MHJ
187	B62qriG5CJaBLFwd5TESfXB4rgSDfPSFyYNmpjWw3hqw1LDxPvpfaV6
188	B62qjYVKAZ7qtXDoFyCXWVpf8xcEDpujXS5Jvg4sjQBEP8XoRNufD3S
189	B62qjBzcUxPayV8dJiWhtCYdBZYnrQeWjz28KiMYGYodYjgwgi961ir
190	B62qkG2Jg1Rs78D2t1DtQPjuyydvVSkfQMDxBb1hPi29HyzHt2ztc8B
191	B62qpNWv5cQySYSgCJubZUi6f4N8AHMkDdHSXaRLVwy7aG2orM3RWLp
192	B62qism2zDgKmJaAy5oHRpdUyk4EUi9K6iFfxc5K5xtARHRuUgHugUQ
193	B62qqaG9PpXK5CNPsPSZUdAUhkTzSoZKCtceGQ1efjMdHtRmuq7796d
194	B62qpk8ww1Vut3M3r2PYGrcwhw6gshqvK5PwmC4goSY4RQ1SbWDcb16
195	B62qqxvqA4qfjXgPxLbmMh84pp3kB4CSuj9mSttTA8hGeLeREfzLGiC
196	B62qnqFpzBPpxNkuazmDWbvcQX6KvuCZvenM1ev9hhjKj9cFj4dXSMb
197	B62qpdxyyVPG1v5LvPdTayyoUtp4BMYbYYwRSCkyW9n45383yrP2hJz
198	B62qohCkbCHvE3DxG8YejQtLtE1o86Z53mHEe1nmzMdjNPzLcaVhPx2
199	B62qiUvkf8HWS1tv8dNkHKJdrj36f5uxMcH1gdF61T2GDrFbfbeeyxY
200	B62qngQ2joTkrS8RAFystfTa7HSc9agnhLsBvvkevhLmn5JXxtmKMfv
201	B62qrCfZaRAK5LjjigtSNYRoZgN4W4bwWbAffkvdhQYUDkB7UzBdk6w
202	B62qq8p3wd6YjuLqTrrUC8ag4wYzxoMUBKu4bdkUmZegwC3oqoXpGy3
203	B62qqmgpUFj5gYxoS6yZj6pr22tQHpbKaFSKXkT8yzdxatLunCvWtSA
204	B62qrjk6agoyBBy13yFobKQRE6FurWwXwk5P1VrxavxpZhkiHXqsyuR
205	B62qr3YEZne4Hyu9jCsxA6nYTziPNpxoyyxZHCGZ7cJrvckX9hoxjC6
206	B62qm7tX4g8RCRVRuCe4MZJFdtqAx5vKgLGR75djzQib7StKiTfbWVy
207	B62qjaAVCFYmsKt2CR2yUs9EqwxvT1b3KWeRWwrDQuHhems1oC2DNrg
208	B62qj49MogZdnBobJZ6ju8njQUhP2Rp59xjPxw3LV9cCj6XGAxkENhE
209	B62qpc1zRxqn3eTYAmcEosHyP5My3etfokSBX9Ge2cxtuSztAWWhadt
210	B62qm4Kvpidd4gX4p4r71DGsQUnEmhi12H4D5k3F2rdxvWmWEiJyfU2
211	B62qjMzwAAoUbqpnuntqxeb1vf2qgDtzQwj4a3zkNeA7PVoKHEGwLXg
212	B62qmyLw1LNGHkvqkH5nsQZU6uJu3begXAe7WzavUH4HPSsjJNKP9po
213	B62qqmQY1gPzEv6qr6AbLBp1yLW5tVcMB4dwVPMF218gv2xPk48j3sb
214	B62qmmhQ2eQDnyFTdsgzztgLndmsSyQBBWtjALnRdGbZ87RkNeEuri1
215	B62qqCAQRnjJCnS5uwC1A3j4XmHqZrisvNdG534R8eMvzsFRx9h8hip
216	B62qoUdnygTtJyyivQ3mTrgffMeDpUG1dsgqswbXvrypvCa9z8MDSFz
217	B62qnt6Lu7cqkAiHg9qF6qcj9uFcqDCz3J6pTcLTbwrNde97KbR6rf6
218	B62qoTmf1JEAZTWPqWvMq66xAonpPVAhMtSR8UbbX3t8FhRKrdyTFbr
219	B62qiqiPtbo7ppvjDJ536Nf968zQM3BrYxQXoWeistF8J12BovP5e1F
220	B62qpP5T35yJUz1U25Eqi5VtLVkjbDyMMXaTa87FE9bhoEbtz7bzAXz
221	B62qqdtmbGF5LwL47qj7hMWjt6XYcwJnft3YgD8ydLgf1M59PFCHv44
222	B62qm8TrWwzu2px1bZG38QkpXC5JgU7RnCyqbVyiy2Fmh63N5d9cbA6
223	B62qnZXs2RGudz1q9eAgxxtZQnNNHi6P5RAzoznCKNdqvSyyWghmYX6
224	B62qo7dRx2VHmDKXZ8XffNNeUK1j4znWxFUvg48hrxrNChqwUrDBgiA
225	B62qke1AAPWuurJQ5p1zQ34uRbtogxsfHEdzfqufAHrqKKHba7ZYC2G
226	B62qjy64ysP1cHmvHqyrZ899gdUy48PvBCnAYRykM5EMpjHccdVZ4Fy
227	B62qjDFzBEMSsJX6i6ta6baPjCAoJmHY4a4xXUmgCJQv4sAXhQAAbpt
228	B62qrV4S63yeVPjcEUmCkAx1bKA5aSfzCLTgh3b8D5uPr7UrJoVxA6S
229	B62qnqEX8jNJxJNyCvnbhUPu87xo3ki4FXdRyUUjQuLCnyvZE2qxyTy
230	B62qpivmqu3HDNenKMHPNhie31sFD68nZkMteLW58R21gcorUfenmBB
231	B62qjoiPU3JM2UtM1BCWjJZ5mdDBr8SadyEMRtaREsr7iCGPabKbFXf
232	B62qoRBTLL6SgP2JkuA8VKnNVybUygRm3VaD9uUsmswb2HULLdGFue6
233	B62qpLj8UrCZtRWWGstWPsE6vYZc9gA8FBavUT7RToRxpxHYuT3xiKf
234	B62qix7awr6K8m1ZNvHU2S9hzxD3DrBqyk3MNnWP247MEpFQ5TpbEYi
235	B62qkZeQptw1qMSwe53pQN5HXj258zQN5bATF6bUz8gFLZ8Tj3vHdfa
236	B62qjzfgc1Z5tcbbuprWNtPmcA1aVEEf75EnDtss3VM3JrTyvWN5w8R
237	B62qkjyPMQDyVcBt4is9wamDeQBgvBTHbx6bYSFyGk6NndJJ3c1Te4Q
238	B62qjrZB4CzmYULfHB4NAXqjQoEnAESXmeyBAjxEfjCksXE1F7uLGtH
239	B62qkixmJk8DEY8wa7EQbVbZ4b36dCwGoW94rwPkzZnBkB8GjVaRMP5
240	B62qjkjpZtKLrVFyUE4i4hAhYEqaTQYYuJDoQrhisdFbpm61TEm1tE5
241	B62qrqndewerFzXSvc2JzDbFYNvoFTrbLsya4hTsy5bLTXmb9owUzcd
242	B62qrGPBCRyP4xiGWn8FNVveFbYuHWxKL677VZWteikeJJjWzHGzczB
243	B62qpUeZeCPoXYonoDjqGobv2UYGkRbKDPegAQFbTjwwibCBZZpgdQH
\.


--
-- Data for Name: snarked_ledger_hashes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.snarked_ledger_hashes (id, value) FROM stdin;
1	jxjULJM2RAdPYPcv7WPA7KrBx9sSnx4cuuWogWm3Nd1K7Y3YdHR
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
1	payment	140	140	140	0	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuWKXAk7GHE37pEr9Tck7oggy7XNtaEoyU7rncrQWfr5xY2eQNy
2	payment	140	140	140	1	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuFp2TqEi5D3ZAEGSu8yTcMQzafbihqGfpdx8S7mGsuGHYvPwTy
3	payment	140	140	140	2	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuoAZ3FqbtquXoKjvfHguLGwR815Vup5fD4AiefCuZ3rB1FGKCA
4	payment	140	140	140	3	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juq3sT9v7z2xrPWjJ6x16oK1rMTWVpnuPktkcSWEvynQyhu1YXh
5	payment	140	140	140	4	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvCnswkQJVsfa2pKfxbxmvsAFESQpyGe5im6Qwd6FAd2UTZ7sH3
6	payment	140	140	140	5	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvGMF39eBXmWwTQ8nGoXbfbgy7EKGeWVFG6xj1bUH7W5DzNfyVF
7	payment	140	140	140	6	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvEbWbzhGxnxSAp6UP3hYbapXy1vXbEu27jVEirghbWZCgZxQ58
8	payment	140	140	140	7	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvAe2HSj2k4Csben3b3rBXS6jtDEpHRc3Xw121LRZ7iCo6SFrCJ
9	payment	140	140	140	8	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtksHgx7wdoxEKXc5zvWYJrh4K1GfkBdCCuyBQRAgniFcUZQ3av
10	payment	140	140	140	9	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtffm8MiwmNTtwcvk7EZGaQwzbcw54kSXqbTEhsaHha9Y21njaE
11	payment	140	140	140	10	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv8AQ7UVefewhPWW5BW1HPwuVG9UMgae3kUyHpLDujHbiRsoP6D
12	payment	140	140	140	11	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv2e7FQgNhqc3sSGcVuAZ88iqhB3d2Uytq3eiGqzhfnVbHtQyLP
13	payment	140	140	140	12	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JufV5zahFiH4FdhGaCjhpcop8ALPDZo3euJa1RWQhRoK1ew7MKz
14	payment	140	140	140	13	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuD5rCrJBqxDwWZ8iz11nzrxS7Su9jBXFmhhxqfuMFGnoN4Jzun
15	payment	140	140	140	14	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju1RxSe2z1wJx1bHLXT8VAMWXocvKtyKfuRVTh5PPNtunKf4ZMV
16	payment	140	140	140	15	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvN2dHYw7WkAnszAbv1suNMss73HcWgfFzvi4WPdHHrTrCGBgNJ
17	payment	140	140	140	16	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juu8WWZujKebRpmjL8WeMb5q2ErweeSk7BUZYtYCAgGFLzML6r5
18	payment	140	140	140	17	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtpELzJKotkVyyKBVq7c3oA2Dtban9zKgffmMoLAEif7pq4YAZE
19	payment	140	140	140	18	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JunKae7y6AfsHFyniYPJ6cwYKvG2zrdRyBzF23VmFrgbJeGKwv5
20	payment	140	140	140	19	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtzFsKj7PmXT9zLeLBKzzQzb2Y5sUYGMfkCp7DfbmKWwLRpEabN
21	payment	140	140	140	20	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtnTdVpmy4FPTeeutUkDmsGX4U8xPpP9jGFkJZGP5f9d7GPf3hL
22	payment	140	140	140	21	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtuGYQaFyMcWeAFgWWfWcinSxKkanU1q8YKUhngrNZuFX4DiZRU
23	payment	140	140	140	22	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvQbuDoooP3HfkBy1GmXE9pWwmCni7dLkqqzwLTYax8Wg131ehA
24	payment	140	140	140	23	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuKpXXNE1PgjPBND3go5MRCHWRG8cY5CZh7groY9eCimt4QWd4V
25	payment	140	140	140	24	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv3wPSCLmyViy5E4RJaXo2w9YMaoKhZ4mcp3c2Ybvdbpp2UfCBF
26	payment	140	140	140	25	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtetizFxi7HbFVRgzZwQUHAxf5x6Lx1CUbWRv3GGJZu9JFnAiGR
27	payment	140	140	140	26	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtxtwMH4KFQxMhsc2bD8Gveom7WzbmNG1p7f1nV2ma5c22dXgqf
28	payment	140	140	140	27	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuimoxVAcXQJfcFgy6CDhwWy6bmtfk2LfMQ8geJxF7aTggfCYe6
29	payment	140	140	140	28	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuaUXu5HbdeKqB6dSXJgkXjEMTEYjJook2Cv3HQxtNqzha7FDva
30	payment	140	140	140	29	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuVYNWeQTWCWn6coWeyQPK5crZjBq5viHGb5GfhgV3rzauTf9Te
31	payment	140	140	140	30	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvP1kHx7k4meQ7SmvTg3SNbDbYV1dWHkEqrXzTVHrx43Yb4rmq5
32	payment	140	140	140	31	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuuHWMMbTmtXb6pkqNKZN9zxJ6dVtv5q2taFtbQTkgdFWo6MCPA
33	payment	140	140	140	32	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuW6kp7SSP159pba4SSNydZq67J67YueQ5dWW8Nnj7Y6KFV9RPB
34	payment	140	140	140	33	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvM1X9vbRr6Jv4z586ds4V5bhVVQja38fZyW1JftXQjtdGSroKj
35	payment	140	140	140	34	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuyQm7Psyd8oXyM3x8PrJQCq1k4WGtBpz7EvhM2sUwzDxwB94er
36	payment	140	140	140	35	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JthFoppt8VSGMSkAL5iQE6tpqWLMqNzMZDVybE3ZMRjXWcBL2bx
37	payment	140	140	140	36	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtYdWFNeoLbMrpATKDZtyHGhEdvMkstZWL16wk6C3hLCBsez6Qk
38	payment	140	140	140	37	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuWXpSba6vnMQR5R4juiWb7gy84FwC9AK9bp2Ug7dDtDVa3RmVy
39	payment	140	140	140	38	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuaUTwJoGPHTdQuUwv5EzYMi3gXY4GzQHGWmF3Lx8QaDHNSDd7M
40	payment	140	140	140	39	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuyC1f2jaWQt4WN5Jhpnf4QeNCUuBYuMS8zJhSRmSkGk4LvzDve
41	payment	140	140	140	40	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtv1Cro3mfFfeSAjARMnsN4SbGdTxRgvkjHQGPxv7LpZaudUbTh
42	payment	140	140	140	41	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv54AfwxtrBLKxRLnmUvryrojQkAMG3ZZCHUjxcTQ9Mjwn5aKyU
43	payment	140	140	140	42	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtYo89SiWiUME7ASu943zLLav9nGXaVW3XpwSviBHHjwVd13R5g
44	payment	140	140	140	43	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju9Nsn7i7M8MiC8LGboHEhSgZu9UpBpsftamJjuQRt7v2UyryUN
45	payment	140	140	140	44	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtevHXy1HkwTuCTQFbBfEYii4ve18ynHLZ3CJmtFbzzbLP5rzMg
46	payment	140	140	140	45	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvArWV7PTFv3UsKqdgBB4BfhcnKZ6fZQvznejAKUE1vHsD9Zkug
47	payment	140	140	140	46	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jurdo2zGHEa8z3ppxYEfpZGY5FuuivwFwnpR2zYVUeWSVuVFqqk
48	payment	140	140	140	47	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtmShG45sYiZdrA9F8iEKSW55doi3r564U6VQq7e7WuEq2h97FG
49	payment	140	140	140	48	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtVWoovAbcoLqKigeXj7RSdy8ipGnAJ3UcCdBMi93eRXizCpjY8
50	payment	140	140	140	49	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv6DUTFYn47wFn3YiFcWrRB48kiCESrWgj9dWy5dEWxBKsYQ2XN
51	payment	140	140	140	50	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuHotxj5eDyA6BanzCNTLFkJ9PW6S5h4ibunuj9HofDUHmoyRH5
52	payment	140	140	140	51	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtshay3deqUcLjrYPTSHLyC4GF3EHB2Wz6gPgLHtjwm6jCLKaD8
53	payment	140	140	140	52	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv4VCZZa6Cm6hf3tWF4m1pWSS57jPSrh9tKNy1vkSdu5P7eWGap
54	payment	140	140	140	53	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JubdRUVS5F26mPnf2y4mh98r6EhCJtGYTXSqbDtKCRHpCec7aRM
55	payment	140	140	140	54	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuKmyAnE1sU3TfFowDPqMWhqBaftpT6WiBXtVQf8E8QTXRk6456
56	payment	140	140	140	55	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuxAjDwZvdovJDjuaD4HpLBou9wHNEF7cc94r24hDQbZ7WC4qWS
57	payment	140	140	140	56	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvCVH1U4T2gcHmkGRoPPXoYXqVPYxh1NLwC7A21JfdSo2Td56BX
58	payment	140	140	140	57	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtsmK7ATFJF3ricwDT8QNDZUMmLmnfczPKLdDmTFteD7ZwyTmHi
59	payment	140	140	140	58	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuWaxy8s1GcWB5147VgAojmwGoSLsWG2r5TrsgvK4epMbARu5UD
60	payment	140	140	140	59	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JucNSqm7n2TG1RAvWRZRHjZ2YTdtwekfEJgjbay8TquMHjFhm5E
61	payment	140	140	140	60	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtXZod8DBwZSRbQFyzJkU7aZQwCPvnzikE2P1MAfdrW5mcp6mn4
62	payment	140	140	140	61	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvA2A85UpTA8VWuACGH6iyAfcwUzFYrZpMb6YxXuVE3e3LoBWKm
63	payment	140	140	140	62	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv1m8LJEHyAbf8quzL8YXhoxhDDzdPjdTEzS7cy7KSd58kWLRHp
64	payment	140	140	140	63	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuuGHrdFLSY725qABGwTG7BzA3ThPUZVVKWhspjezoy4v1j5cwo
65	payment	140	140	140	64	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JupwBmoWJtzxGz9QNYMXRrGy8FgGV9idSxDERqH95PNQ951Yyfd
66	payment	140	140	140	65	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jumf4E96pd1YMWzHTCZd9xW8sUhSgwnwBrMaXwWjjqMjWvpcNBu
67	payment	140	140	140	66	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuoGUWoMKpFES8QKH6zrBFXuDgYVUEg2DoNuGNfaLc8Mvdvge3X
68	payment	140	140	140	67	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jujooi5ms8cHuG4dXoHRzUpB5JFTmN2akoBcbNYwYR873kYoMJy
69	payment	140	140	140	68	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuUTNqHLYf9NRXrEje5kSX2FN12s8W89McXBJzbW9JFitxWLdZt
70	payment	140	140	140	69	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuDTrfqcUr9xnDKG3uSxZyhA4PQqP35SbHNprnUBWnSWNrSKApX
71	payment	140	140	140	70	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JugwcerqFA4GqFhRJmxL6kY8p5gxBnWtT62bcMDyV6AUktWtXoY
72	payment	140	140	140	71	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jthx8eXBywL9pnPQvYpzi7JtuKQFU5EmgMmVFEMVnqB28DMMDP6
73	payment	140	140	140	72	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuUqnsKyNumRUjqnkngAwkQhCxmKx6muHHGYvc5d5GNXkyTUXN6
74	payment	140	140	140	73	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvP16n9ahMo1TTLPWrxvaKBdJjz33fFLBZ9E7J7bzYW7y9XKPhY
75	payment	140	140	140	74	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvHSgKkJQM3RWmoadHV9M3HXazW2jzA7bo9c96sHG2N3CyS2Pan
76	payment	140	140	140	75	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuPiRKU8x9Rq9xTg1AJ1S8uZPWZyXvyrpkT75rPaHyDQ9n4VQDx
77	payment	140	140	140	76	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtstqr8y3unhnxbUr3h24zdBbXLYnuFKDFzQattVNdXaqTySSQ8
78	payment	140	140	140	77	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuVPex5KpdmGiQ3KsnhM75Lundg9ZouA6xHmAwRbTeX7K4T6AJA
79	payment	140	140	140	78	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvBF3qYvYJK1WvsY4MNkHkic5o68Us2bR8d7kojPXqdGCT6W8wx
80	payment	140	140	140	79	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuijbynX7w58K7r78ArYz3Q4MFETYaGGEutLW1UfhcwjGcYJUjp
81	payment	140	140	140	80	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtxx1mDiiwCHSffGgriQ5qZqEV3wgUgvSzDEHDknDMTi7RRApvD
82	payment	140	140	140	81	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuGoLQ51UbB4EJyBuNEtFLGVadq9nNpyVb6DhA46oLivTHcS5sb
83	payment	140	140	140	82	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtuLwcMoqV4oEnTKu8NDQ7gBz1icuE7n2TWPY4hCtGJQXXAgDzv
84	payment	140	140	140	83	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju2Nd6nXyMqUbJWyeZ2qAsBYGBdq3LnsaC2HEQa21w3fPVEeKCU
85	payment	140	140	140	84	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuhcHzsDxudWfN7aXAdYXSgGBUErYZ2tzmewD9SbFaFCvmaJhkg
86	payment	140	140	140	85	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtmZPsFb7U2mMtEtntxAC86ENTETeDYh5iXc388QkXfi87qWZYh
87	payment	140	140	140	86	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtaKmMGkFXQhwkiG8QBAsLsZZWYNwXfHadRSpZ3XRgykEvY3wxK
88	payment	140	140	140	87	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juo2Z4VyGejn5NzMsW62uupxe1J7FW5Mi88aaCEy3JZUr2wVoA9
89	payment	140	140	140	88	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtoDkJE9KUSudtt4227TeGHESqeqTiixWuTiY2Ykp2GRpi5RMkv
90	payment	140	140	140	89	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtvx9iLzTH3ranDJxcNVTDfaSJK2WVcLzyiSHW3gwA8WDywFVYX
91	payment	140	140	140	90	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuLZXVfBpg9FDy5DY9BBS8R3HyQnnDx31tBjH3d7WFqSuYBBimc
92	payment	140	140	140	91	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvBLNu5fpeqfhsEcsAku4EPELfrfPXjerJfMtVSJwSyeasPLMx8
93	payment	140	140	140	92	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtzbgxKRrBm8Hd9oUm1UBRCSuLpCvvzqDXAWuk4nyrb7CPdcGrB
94	payment	140	140	140	93	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuMMSUV36s99F3MWgpboGJPPHru6whSh2GLHqxoGxsjEYdqkk5A
95	payment	140	140	140	94	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvEVnXkYtFeck4rSXewSopcCZwr77NpjGSWa2gzZo73965SioB4
102	payment	140	140	140	101	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtWA3VZyTAvPyGgzvydPiD9pZ4tLR31tNG6DLjZAYr4AnHCaYj2
103	payment	140	140	140	102	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju8o2BTGoxMKCEe5LA6h2bCQSyJU7KtvVX7JVPbCYVW9whdEyPn
104	payment	140	140	140	103	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtvpkwJMUeb2wkJeDPLUrTd4A5TrJCeJozJX3a5s57RsrtqokRZ
105	payment	140	140	140	104	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju4nutccPyqoR47HeNMHVrRhWss5btJtnJHi4tF5WCXBxjqjBee
106	payment	140	140	140	105	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JubW93Qq5FQ4DYsipjfbRrqzhauGRsRgCLnH9sXP88CovEFExcE
107	payment	140	140	140	106	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv6qiMMcHV6wsVwmCJBRpWTy3c8YLknL4d9N1qKgyV8hVTNP9xw
108	payment	140	140	140	107	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jthktqk4ESdysG7tyZbZChLoQzzLT22kUhrdHW4Mu2gNcWxy3dZ
109	payment	140	140	140	108	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuyvbzVzs5qorLd1z9HDK1x6TYk5rwMgGDF13qSxUjQQbPMvNiZ
110	payment	140	140	140	109	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juc6XuLu96Z2FAxVTyucPK1y1zC4k6wxK4nufSweHwjR7cGyX4H
96	payment	140	140	140	95	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuBhYUn4CBRSFtnLyGjMPiAMCHaj1ozGPvmXTYhzY4eFhaiW3T2
97	payment	140	140	140	96	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuXNnvv1r9ZhrzVTDLN8VqsfNqisvxXtaZGgUe58tQEjigsujps
98	payment	140	140	140	97	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuCn6MDW8w3D4q9Do4t7N246MwK59LPS2VYhJc91UaaTwsGggfv
99	payment	140	140	140	98	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtwBtZFcE3RMHBdKbqF7SHj4tRrviHAT95Mcz6Zxj84YKcjsooS
100	payment	140	140	140	99	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv3Dz9dM9iMaqhnX4BUdjmuNwxUKt6ey1Cf1K3VW6QJ1NwCioGQ
101	payment	140	140	140	100	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jui2Ay176NpneeGKmsxGb4fP3Ruug7x7FnNHGeBo56Efw8wrox8
111	payment	140	140	140	110	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvJ438ueTCyGjQd7MWWLppQRYPfQVzgPzQG1x4FeSn8qKktjzr5
112	payment	140	140	140	111	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jux6QsWyspwu2rRJDhgtSL1PsaWp1GLdXyuVXRg93USAppz5aKW
113	payment	140	140	140	112	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtmijEVsVtVUjNgFw27vkxqJoNAgJyT6Lxakb7DbZUqrwUEmnJE
114	payment	140	140	140	113	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvGEoCQrXFf2c5TTgQvZq9RZeW6y7iZSzHZESNvubXsHAtjZZxh
115	payment	140	140	140	114	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JufDMtRfm4GJCDvHE462GMHLyAiKMu7B1bdVUwnw9fyjqoj5dzc
116	payment	140	140	140	115	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JutaQmPcqdf1LXmWBKc759H3FXtVPNuXvkucnez5AXiNsPjMZ3x
117	payment	140	140	140	116	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtohjrEh85T1H8qDN11TdJ1vyPF7EoCMEu3CjjvBgviftbPBLrN
118	payment	140	140	140	117	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtn2wdb3bm8zg42bfCcAEq4PjXdHbRsDrxULQbhsBj3xpeEydq3
119	payment	140	140	140	118	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvAESGCEX7v1YXFTVqApB7YFqGTR5bsrFPi4Lpp8qEkjPxahpvU
120	payment	140	140	140	119	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtgjUE1diCTHHW8275VqkkjBtqfzrszW7oiV84D1BYH9qSYXWJX
121	payment	140	140	140	120	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuQcct77DgpEU57YCmqeSsmAbVSLSEVKEv63eK4k72MzwVBrU4t
122	payment	140	140	140	121	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuiE7TbCWGCwYNX1tGUFoNgxHU1umNdnGmEmmKKxxn3NLCURdbm
123	payment	140	140	140	122	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv8evjmP7qrVQ8nE5iBxbmngE7LAKBDcDXSDwz2Au12Mn7W429F
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
239	239
240	240
241	241
242	242
243	243
244	244
245	245
233	233
234	234
235	235
236	236
237	237
238	238
\.


--
-- Data for Name: zkapp_account_update_body; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.zkapp_account_update_body (id, account_identifier_id, update_id, balance_change, increment_nonce, events_id, actions_id, call_data_id, call_depth, zkapp_network_precondition_id, zkapp_account_precondition_id, zkapp_valid_while_precondition_id, use_full_commitment, implicit_account_creation_fee, may_use_token, authorization_kind, verification_key_hash_id) FROM stdin;
1	234	1	-1000000000000	t	1	1	1	0	1	1	\N	f	f	No	Signature	\N
2	243	2	999000000000	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
3	234	1	-1000000000	t	1	1	1	0	1	3	\N	f	f	No	Signature	\N
4	243	1	1000000000	f	1	1	1	0	1	2	\N	f	f	No	None_given	\N
5	243	3	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
6	234	1	-1000000000	t	1	1	1	0	1	4	\N	f	f	No	Signature	\N
7	243	4	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
8	234	1	-1000000000	t	1	1	1	0	1	5	\N	f	f	No	Signature	\N
9	243	5	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
10	234	1	-1000000000	t	1	1	1	0	1	6	\N	f	f	No	Signature	\N
11	243	6	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
12	234	1	-1000000000	t	1	1	1	0	1	7	\N	f	f	No	Signature	\N
13	243	7	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
14	234	1	-1000000000	t	1	1	1	0	1	8	\N	f	f	No	Signature	\N
15	243	8	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
16	234	1	-1000000000	t	1	1	1	0	1	9	\N	f	f	No	Signature	\N
17	243	9	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
18	234	1	-1000000000	t	1	1	1	0	1	10	\N	f	f	No	Signature	\N
19	243	10	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
20	234	1	-1000000000	t	1	1	1	0	1	11	\N	f	f	No	Signature	\N
21	243	11	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
22	234	1	-1000000000	t	1	1	1	0	1	12	\N	f	f	No	Signature	\N
23	243	12	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
24	234	1	-1000000000	t	1	1	1	0	1	13	\N	f	f	No	Signature	\N
25	243	13	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
26	234	1	-1000000000	t	1	1	1	0	1	14	\N	f	f	No	Signature	\N
27	243	14	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
28	234	1	-1000000000	t	1	1	1	0	1	15	\N	f	f	No	Signature	\N
29	243	15	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
30	234	1	-1000000000	t	1	1	1	0	1	16	\N	f	f	No	Signature	\N
31	243	16	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
32	234	1	-1000000000	t	1	1	1	0	1	17	\N	f	f	No	Signature	\N
33	243	17	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
34	234	1	-1000000000	t	1	1	1	0	1	18	\N	f	f	No	Signature	\N
35	243	18	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
36	234	1	-1000000000	t	1	1	1	0	1	19	\N	f	f	No	Signature	\N
37	243	19	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
38	234	1	-1000000000	t	1	1	1	0	1	20	\N	f	f	No	Signature	\N
39	243	20	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
40	234	1	-1000000000	t	1	1	1	0	1	21	\N	f	f	No	Signature	\N
41	243	21	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
42	234	1	-1000000000	t	1	1	1	0	1	22	\N	f	f	No	Signature	\N
43	243	22	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
44	234	1	-1000000000	t	1	1	1	0	1	23	\N	f	f	No	Signature	\N
45	243	23	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
46	234	1	-1000000000	t	1	1	1	0	1	24	\N	f	f	No	Signature	\N
47	243	24	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
48	234	1	-1000000000	t	1	1	1	0	1	25	\N	f	f	No	Signature	\N
49	243	25	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
50	234	1	-1000000000	t	1	1	1	0	1	26	\N	f	f	No	Signature	\N
51	243	26	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
52	234	1	-1000000000	t	1	1	1	0	1	27	\N	f	f	No	Signature	\N
53	243	27	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
54	234	1	-1000000000	t	1	1	1	0	1	28	\N	f	f	No	Signature	\N
55	243	28	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
56	234	1	-1000000000	t	1	1	1	0	1	29	\N	f	f	No	Signature	\N
57	243	29	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
58	234	1	-1000000000	t	1	1	1	0	1	30	\N	f	f	No	Signature	\N
59	243	30	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
60	234	1	-1000000000	t	1	1	1	0	1	31	\N	f	f	No	Signature	\N
61	243	31	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
62	234	1	-1000000000	t	1	1	1	0	1	32	\N	f	f	No	Signature	\N
63	243	32	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
64	234	1	-1000000000	t	1	1	1	0	1	33	\N	f	f	No	Signature	\N
65	243	33	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
66	234	1	-1000000000	t	1	1	1	0	1	34	\N	f	f	No	Signature	\N
67	243	34	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
68	234	1	-1000000000	t	1	1	1	0	1	35	\N	f	f	No	Signature	\N
69	243	35	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
70	234	1	-1000000000	t	1	1	1	0	1	36	\N	f	f	No	Signature	\N
71	243	36	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
72	234	1	-1000000000	t	1	1	1	0	1	37	\N	f	f	No	Signature	\N
73	243	37	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
74	234	1	-1000000000	t	1	1	1	0	1	38	\N	f	f	No	Signature	\N
75	243	38	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
76	234	1	-1000000000	t	1	1	1	0	1	39	\N	f	f	No	Signature	\N
77	243	39	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
78	234	1	-1000000000	t	1	1	1	0	1	40	\N	f	f	No	Signature	\N
79	243	40	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
80	234	1	-1000000000	t	1	1	1	0	1	41	\N	f	f	No	Signature	\N
81	243	41	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
82	234	1	-1000000000	t	1	1	1	0	1	42	\N	f	f	No	Signature	\N
83	243	42	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
84	234	1	-1000000000	t	1	1	1	0	1	43	\N	f	f	No	Signature	\N
85	243	43	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
86	234	1	-1000000000	t	1	1	1	0	1	44	\N	f	f	No	Signature	\N
87	243	44	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
88	234	1	-1000000000	t	1	1	1	0	1	45	\N	f	f	No	Signature	\N
89	243	45	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
90	234	1	-1000000000	t	1	1	1	0	1	46	\N	f	f	No	Signature	\N
91	243	46	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
92	234	1	-1000000000	t	1	1	1	0	1	47	\N	f	f	No	Signature	\N
93	243	47	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
94	234	1	-1000000000	t	1	1	1	0	1	48	\N	f	f	No	Signature	\N
95	243	48	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
96	234	1	-1000000000	t	1	1	1	0	1	49	\N	f	f	No	Signature	\N
97	243	49	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
98	234	1	-1000000000	t	1	1	1	0	1	50	\N	f	f	No	Signature	\N
99	243	50	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
106	234	1	-1000000000	t	1	1	1	0	1	54	\N	f	f	No	Signature	\N
107	243	54	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
108	234	1	-1000000000	t	1	1	1	0	1	55	\N	f	f	No	Signature	\N
109	243	55	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
110	234	1	-1000000000	t	1	1	1	0	1	56	\N	f	f	No	Signature	\N
111	243	56	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
112	234	1	-1000000000	t	1	1	1	0	1	57	\N	f	f	No	Signature	\N
113	243	57	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
114	234	1	-1000000000	t	1	1	1	0	1	58	\N	f	f	No	Signature	\N
115	243	58	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
116	234	1	-1000000000	t	1	1	1	0	1	59	\N	f	f	No	Signature	\N
117	243	59	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
118	234	1	-1000000000	t	1	1	1	0	1	60	\N	f	f	No	Signature	\N
119	243	60	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
120	234	1	-1000000000	t	1	1	1	0	1	61	\N	f	f	No	Signature	\N
121	243	61	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
122	234	1	-1000000000	t	1	1	1	0	1	62	\N	f	f	No	Signature	\N
123	243	62	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
124	234	1	-1000000000	t	1	1	1	0	1	63	\N	f	f	No	Signature	\N
125	243	63	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
126	234	1	-1000000000	t	1	1	1	0	1	64	\N	f	f	No	Signature	\N
127	243	64	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
128	234	1	-1000000000	t	1	1	1	0	1	65	\N	f	f	No	Signature	\N
129	243	65	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
130	234	1	-1000000000	t	1	1	1	0	1	66	\N	f	f	No	Signature	\N
131	243	66	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
100	234	1	-1000000000	t	1	1	1	0	1	51	\N	f	f	No	Signature	\N
101	243	51	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
102	234	1	-1000000000	t	1	1	1	0	1	52	\N	f	f	No	Signature	\N
103	243	52	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
104	234	1	-1000000000	t	1	1	1	0	1	53	\N	f	f	No	Signature	\N
105	243	53	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
132	234	1	-1000000000	t	1	1	1	0	1	67	\N	f	f	No	Signature	\N
133	243	67	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
134	234	1	-1000000000	t	1	1	1	0	1	68	\N	f	f	No	Signature	\N
135	243	68	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
136	234	1	-1000000000	t	1	1	1	0	1	69	\N	f	f	No	Signature	\N
137	243	69	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
138	234	1	-1000000000	t	1	1	1	0	1	70	\N	f	f	No	Signature	\N
139	243	70	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
140	234	1	-1000000000	t	1	1	1	0	1	71	\N	f	f	No	Signature	\N
141	243	71	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
142	234	1	-1000000000	t	1	1	1	0	1	72	\N	f	f	No	Signature	\N
143	243	72	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
144	234	1	-1000000000	t	1	1	1	0	1	73	\N	f	f	No	Signature	\N
145	243	73	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
146	234	1	-1000000000	t	1	1	1	0	1	74	\N	f	f	No	Signature	\N
147	243	74	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
148	234	1	-1000000000	t	1	1	1	0	1	75	\N	f	f	No	Signature	\N
149	243	75	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
150	234	1	-1000000000	t	1	1	1	0	1	76	\N	f	f	No	Signature	\N
151	243	76	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
152	234	1	-1000000000	t	1	1	1	0	1	77	\N	f	f	No	Signature	\N
153	243	77	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
154	234	1	-1000000000	t	1	1	1	0	1	78	\N	f	f	No	Signature	\N
155	243	78	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
156	234	1	-1000000000	t	1	1	1	0	1	79	\N	f	f	No	Signature	\N
157	243	79	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
158	234	1	-1000000000	t	1	1	1	0	1	80	\N	f	f	No	Signature	\N
159	243	80	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
160	234	1	-1000000000	t	1	1	1	0	1	81	\N	f	f	No	Signature	\N
161	243	81	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
162	234	1	-1000000000	t	1	1	1	0	1	82	\N	f	f	No	Signature	\N
163	243	82	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
164	234	1	-1000000000	t	1	1	1	0	1	83	\N	f	f	No	Signature	\N
165	243	83	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
166	234	1	-1000000000	t	1	1	1	0	1	84	\N	f	f	No	Signature	\N
167	243	84	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
168	234	1	-1000000000	t	1	1	1	0	1	85	\N	f	f	No	Signature	\N
169	243	85	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
170	234	1	-1000000000	t	1	1	1	0	1	86	\N	f	f	No	Signature	\N
171	243	86	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
172	234	1	-1000000000	t	1	1	1	0	1	87	\N	f	f	No	Signature	\N
173	243	87	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
174	234	1	-1000000000	t	1	1	1	0	1	88	\N	f	f	No	Signature	\N
175	243	88	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
176	234	1	-1000000000	t	1	1	1	0	1	89	\N	f	f	No	Signature	\N
177	243	89	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
178	234	1	-1000000000	t	1	1	1	0	1	90	\N	f	f	No	Signature	\N
179	243	90	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
180	234	1	-1000000000	t	1	1	1	0	1	91	\N	f	f	No	Signature	\N
181	243	91	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
182	234	1	-1000000000	t	1	1	1	0	1	92	\N	f	f	No	Signature	\N
183	243	92	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
184	234	1	-1000000000	t	1	1	1	0	1	93	\N	f	f	No	Signature	\N
185	243	93	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
186	234	1	-1000000000	t	1	1	1	0	1	94	\N	f	f	No	Signature	\N
187	243	94	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
188	234	1	-1000000000	t	1	1	1	0	1	95	\N	f	f	No	Signature	\N
189	243	95	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
190	234	1	-1000000000	t	1	1	1	0	1	96	\N	f	f	No	Signature	\N
191	243	96	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
192	234	1	-1000000000	t	1	1	1	0	1	97	\N	f	f	No	Signature	\N
193	243	97	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
194	234	1	-1000000000	t	1	1	1	0	1	98	\N	f	f	No	Signature	\N
195	243	98	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
196	234	1	-1000000000	t	1	1	1	0	1	99	\N	f	f	No	Signature	\N
197	243	99	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
198	234	1	-1000000000	t	1	1	1	0	1	100	\N	f	f	No	Signature	\N
199	243	100	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
200	234	1	-1000000000	t	1	1	1	0	1	101	\N	f	f	No	Signature	\N
201	243	101	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
202	234	1	-1000000000	t	1	1	1	0	1	102	\N	f	f	No	Signature	\N
203	243	102	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
204	234	1	-1000000000	t	1	1	1	0	1	103	\N	f	f	No	Signature	\N
205	243	103	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
206	234	1	-1000000000	t	1	1	1	0	1	104	\N	f	f	No	Signature	\N
207	243	104	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
208	234	1	-1000000000	t	1	1	1	0	1	105	\N	f	f	No	Signature	\N
209	243	105	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
210	234	1	-1000000000	t	1	1	1	0	1	106	\N	f	f	No	Signature	\N
211	243	106	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
212	234	1	-1000000000	t	1	1	1	0	1	107	\N	f	f	No	Signature	\N
213	243	107	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
214	234	1	-1000000000	t	1	1	1	0	1	108	\N	f	f	No	Signature	\N
215	243	108	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
216	234	1	-1000000000	t	1	1	1	0	1	109	\N	f	f	No	Signature	\N
217	243	109	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
218	234	1	-1000000000	t	1	1	1	0	1	110	\N	f	f	No	Signature	\N
219	243	110	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
220	234	1	-1000000000	t	1	1	1	0	1	111	\N	f	f	No	Signature	\N
221	243	111	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
222	234	1	-1000000000	t	1	1	1	0	1	112	\N	f	f	No	Signature	\N
223	243	112	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
224	234	1	-1000000000	t	1	1	1	0	1	113	\N	f	f	No	Signature	\N
225	243	113	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
226	234	1	-1000000000	t	1	1	1	0	1	114	\N	f	f	No	Signature	\N
227	243	114	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
228	234	1	-1000000000	t	1	1	1	0	1	115	\N	f	f	No	Signature	\N
229	243	115	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
230	234	1	-1000000000	t	1	1	1	0	1	116	\N	f	f	No	Signature	\N
231	243	116	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
232	234	1	-1000000000	t	1	1	1	0	1	117	\N	f	f	No	Signature	\N
233	243	117	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
234	234	1	-1000000000	t	1	1	1	0	1	118	\N	f	f	No	Signature	\N
235	243	118	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
236	234	1	-1000000000	t	1	1	1	0	1	119	\N	f	f	No	Signature	\N
237	243	119	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
238	234	1	-1000000000	t	1	1	1	0	1	120	\N	f	f	No	Signature	\N
239	243	120	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
240	234	1	-1000000000	t	1	1	1	0	1	121	\N	f	f	No	Signature	\N
241	243	121	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
242	234	1	-1000000000	t	1	1	1	0	1	122	\N	f	f	No	Signature	\N
243	243	122	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
244	234	1	-1000000000	t	1	1	1	0	1	123	\N	f	f	No	Signature	\N
245	243	123	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
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
1	1	{1,2}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuPCSYGwmxqodzna6nNzbXQvTHnwSpyuBFiRMgAzJgGAUnYofh2
2	2	{3,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuwNNyeztAKTFybABkgMeYhmyzWvhyrdkadFa8ereE7zcCLXqE5
3	3	{5}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuYsJZhUxbywuag7Lb4oyZQKECZ6SyG8pGyyf2t17vcvJMcxDSD
4	4	{6,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuDBEPkqmSfQ5L8QxuSFEftAA3N5BpCFpvb1BeSiUeG8cCbsRTN
5	5	{7}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtuLWGaevVvSomG83WXKkiZJyZfFQqKpyo7kseffPNMWT6yYfh4
6	6	{8,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtjkjyHMUEGUCqdkLoAznKicczSAEYtVnU7BHbJxMiag9c16ygG
7	7	{9}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuUdmx41YEMotVFDi9awLx551GbVT3UczezdLnJkpusVHHHVKuB
8	8	{10,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuxzpVQrMkwSJv3HTbN2Q5A5awpw91cVb3TtzRn5AnyGii6SqAG
9	9	{11}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuLDGyit6icWZypbgUxPT2R9oTkkrfXeFDFtzzPCxjNv8qdxWf8
10	10	{12,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jus95FRsyGg4fQy4yZipjkBjwhHFPghDQE9eF7TABdJmamAmm6W
11	11	{13}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtoDAtbYmfV7UQZJcGhkU7g8es6BQAxg61yPdhKEjkAJs1iPZ5u
12	12	{14,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuRqeMWCo2yt55J3vhbhD75CcdTrPizRfHaJwKEhW4GZZxJuj3G
13	13	{15}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju6a2Sf7fh9t3M4iJ3uSJDnyRw8J3RBA8de3rVHsv91hB5mEsWe
14	14	{16,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuJsK7RrzX5kX9w43LXprHDMbERN1xFgZMpRTsK9UQuxiBxP5ZJ
15	15	{17}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtW77grJKYNaEPNwgVUFJKpvZukm93mQv47F2nswD72KsJLo7TQ
16	16	{18,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtosJ2ZonHdmiznjTwX9tMwmmkU4ULhqNBtpeSUziyBc3t53p4h
17	17	{19}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuFtyNLmvdmuDjn7YAE84DxKYoD9UEJF9U7w1LSgQjrq6HNC3S8
18	18	{20,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuNmb374GjryUgb6iYheyFRNr33GwKZMQxS92J3uBiyzZN2N9VR
19	19	{21}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JudUAAV5UWGJHYNoBCbkComhnVNyQPrhz5fcbWm3FzsHX57zo6n
20	20	{22,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtwYv8sY6ZWShRxEeg1TYBiGHYLDNCJV1PXczqX8pysw3RKF9t1
21	21	{23}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju1oxu5dkzh1aJoD8fVN1v6Z3m7HhHC9AzxCYA7rR7rx8TPwXeU
22	22	{24,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jua73wJzb3UyuUbkQ7LXJnzNspvuVcUKcKxwBEkvayqPvEfMQto
23	23	{25}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuybRZhtTtiPeZgBbZdWvcP1noTcSUU891NvbgZ4ggSCSH18Fyx
24	24	{26,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv44VvkcJQNS1aprQxaQWiAtB93qMuB5BuDMzfA9g2K6kQtkRdP
25	25	{27}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuZqLSQ3HqhDrFWo5EMwQYDZA9o7s9rEjAZkDhBh1oWtYEXDPgv
26	26	{28,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtcGFv7WYQWQPAapXZrwKMedevQw8mN7x61XFmL8shuRLW4rDdk
27	27	{29}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JutPCDpmiH9yyPN1GVqRkjC4pBWsSLgUqGfxD9Ev7zbEJeASciB
28	28	{30,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju4Xpu56hZpNoyShjPxzc8EDjUjKfR1vkQnjPPhrgHo3djzFoYT
29	29	{31}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtpz2qG7XLSb9gx4wfxM4cXLZvRY5DMh98QAroXGRKgfMau9ZjR
30	30	{32,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju2uNh8uA6Awzsm5CsA3tGp5CkQvF2N7EZK6pCmwfY9vf3dQbsT
31	31	{33}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtoy2dcax43Fid6fQaFQvXC27xMUb6Ab6q2JSTo3t23g7nYxRim
32	32	{34,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuuM8kgBtBbPA4Yi2SNWoCz2bSsbS6DAGi7NWYtn7WRLDHTm5g3
33	33	{35}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuEYTuKwmyi1QeuMSNNsbq7DvhhiLvVpqerViiGikmAs74cKX4r
34	34	{36,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvPBtxA4rMYnyfGwHGQsDgZTe5mamXTLQhYE3FEH9LVwV43YhwY
35	35	{37}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuramQrVnTLk1GD8eKVLXEbgVUWin7eFeJpML4nbZSyjfmwKTuL
36	36	{38,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv9NGWkRHaEQ4R5MYXo8P4yoTTV4XDUdayCVNjUbts6FqzjBFYQ
37	37	{39}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuxTgX4GRkEzTBkvMevCxHkmbjdwJbCQMc9qfwTDFDeVQGi5Hqg
38	38	{40,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju5ES2mS5BkYLKAcCnSRHriJzLLsXmLoYmhahsww7qvDxFY7hVN
39	39	{41}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtz14PsKZw9G9vRDguqzqbETEdchvjrqnHv2EKx92BhCm5wBatm
40	40	{42,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JufMaDPqQZTf7PdU7ErTzcJRJkW9LJo94SsTdwDPM2QubcJeUzz
41	41	{43}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JusxSfmbd1ZCRBqH22VfxUJdxkBA1QwMuYRtxuJU3j1YdAe8QoM
42	42	{44,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvMe4SBkzEiAwe6eB1CCkSKGTNQke83QJ3dZxNwfWSuZwpkirJP
43	43	{45}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JthSsok2Cava4Mj44wXYC8pQ7a4GinLxDjoLdEMgr4hsutSJ9fK
44	44	{46,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvEPoP8cBSMrLFEtgupnBX1pdZJpJR8EAfVRzbo2L8P57QFhXuD
45	45	{47}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvNMXb5vhCohtvaYHdNwWWgNEkKc7zS1TmHBeJz5hDYpyB9i2zN
46	46	{48,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv5jub9U2Y8U4vHX5y38HonQyum9mHkZz91KoszLyqC2YgcuMkV
47	47	{49}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtmHYBDEdYD993Ujx3h1VfiER8thxBLD4xi2ZyFovfsuWJhEdUE
48	48	{50,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtdKcKpMFjCpBafHLB2Fe6g8gTzKPoNiKb6ZpocVws7uJ39Xnyv
49	49	{51}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtaMe2PF32hy5khYwyYyoCceuc7Jx4EaKsjNoAW5KSghL2TBgPB
50	50	{52,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtxbQquYaTQU9vVJwPebCgRdM2DEWbmoSuFhav4ofuKigUTXKdv
51	51	{53}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvMXjMHRdLRRrfQvzz8jGoQooiKJ5njfBHC6973roEZKK2pcfVt
52	52	{54,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuApyN5SmYFrqkwfam1tP95dzrmU6R2zvbnWv453utKgGNd5wit
53	53	{55}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtZUDHzpgDRddiXnStbuni6Soh12yQMwaPgSJ1BSfwaDdKuAZiT
54	54	{56,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtZGBPNWzJxnrghJoQob6EdjJ4fP5x3LN2RDLhDxzmNSESwXuJ3
55	55	{57}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JunMcy4FN4bEa5xYaG1nZnW2og4KfJKybmAwXKnaZZX7HQ7yVm7
56	56	{58,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juur36FRj7SSvzREeAqRVh2YxShU6PLJnhvHcg2RcFnsXCjk6AV
57	57	{59}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuQnRrQtLz17foTEwyQbrNevQwR1ovimhh15ssJRQcNKMcMb1eb
58	58	{60,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuHxVFW3HeFNUSqTMDZUAeXhDFgeaM8VJ5Ue3cGCQXNCDbU2pNx
59	59	{61}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvCEt1gg149jtqi3QVqXA17MJqGECfLLza9qt8bJnXcpJNGfKVg
60	60	{62,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuFeCMAquBC2dn6jvafaHsKagnvPXtszMryozHXTK4HywuLqMHM
61	61	{63}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuhfWwSc1cyrQnFzMtNgWsX3Roj9RiQEj4PewtFhfWmN35uwuxH
62	62	{64,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JugSge74CFwmnTnFzZ68zFmYdtSMeXmCtWHhc8PS3xdo8GVGNd5
63	63	{65}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuDSVLZ2EejDNkNhz4NPYPpcNHp3hye7Ebd48p7BCQULA14DDEv
64	64	{66,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuHZ7EE2EHXmDKTtCMcdB6mRXSTUaT4TLxyXnjFPKnEE2UUKDEh
65	65	{67}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuKP3mom4tDUS4SnkBV9rPU3Q6UwYNa3JFn4iks1SJERuiLTUSN
66	66	{68,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtY9nitULkhgTxmSW1pHkbtmQkUHgosqvTy5dyAkVBdsxZqPeqq
67	67	{69}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtipdXKooy95NXnyY5XNjhSpeegdwPMwzyJsMZePUKn3doKvchT
68	68	{70,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JucEQWUW7p3d4bFSKyM5vfxfoD1ytFf6PPy8cvNyenAu198FHZ1
69	69	{71}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtvRF8XmaZFqa3MQHP2zynzDHv4BYxbPn5761CqWqarmYTsQXaC
70	70	{72,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju2CX9CoadRDxz6WKCKPJ79THP3qKzpSkJvUsu1g8cLmHGjR8S3
71	71	{73}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JugV9d8zi4zQjVRPu1QmBComTyftPpFc7VgGEQocXasBXJpv56f
72	72	{74,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuqLEtPgNzsb3vgE5nhDN8LckaxUZThrAv6ugXGJkLUTvENcwCN
73	73	{75}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtf3x6JXat56bTGsf7mbMtqTB8zwCdNiSMh89CSC1EnJSS3uDaT
74	74	{76,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtmPoTPcPU3fLu6NJp8FxH1QardSxDyFkCZkcvKsrnardUyzPsP
75	75	{77}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtqhWDUStU87fDLorgjkuALTW27egUJrMBnP4gu1WBcbeWdF1cd
76	76	{78,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtjUVE2WGvcFKjVzDenNybv1BMsSozi2wPURa2YpJhfwzBL57t6
77	77	{79}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvBovo5vkKexTQxR78jwLZ3xEttE4oMiPVkivgJPxyeghcSZ9Q9
78	78	{80,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuSa977boW8JBL6WAHPHw9APcTZZ4FPzYEpt91x9ek471nZmXJn
79	79	{81}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv1mUCPgjRBFEMpLkt23TEECGeFsjMVX96Voqij7LKdJJWYioQv
80	80	{82,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuM6P6a7TuESFLmoDnmHFo1VZ1fdtWZow7cRUiRMHx8tnAskD1y
81	81	{83}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtp1wzejoJZ42Q6rEdLTR1diJ9KLT6LaVHVotB2VxTibCGazYpS
82	82	{84,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuBkHvCyoECB6T2Fe3hY2bepkqour1KvWwQSGPbPNmEBqfKbzD5
83	83	{85}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtiYsZWEBXKbr3egPdgbE7Vc1CLFpAjAtxDezHqe4ntwcqf6bBy
84	84	{86,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuEbC4NNVLtA6qapSgBYm1geG9FudGrVTU2LMFwgM5kNepM3yvh
85	85	{87}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju2e938Shz1mYYfpegDQ55A4oTJNtzXrpQRFQaE9Qd6AemNsp6i
86	86	{88,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuqUP2Ym8ZT2YGMnDeQ2vRpaRSmqQ9kv9nxoA33QVdqBd6gaGJq
87	87	{89}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtcXGZSNzEguqGQ3wp1kzQXerhC5iwt96xztJyBuYDPpx5g88mY
88	88	{90,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvHz17XtL5L7Y1eiR2f4VSMcpkPQAdWKnuH2wKa5KBnimn89XyN
89	89	{91}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtibQPZu9cfwFQU6RBBuC58mhWEGTZrgjQNYXCRhxe33rD9Mi1z
90	90	{92,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvKwvQoXXe74bZZ8HPmWShuVDp34kT8CcmamYNNv6CqDoLtUk3u
91	91	{93}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtfuY6UG77hKuEqf9u7spSKRKNmGE9PadawwA5tttaRL6VMRHN5
92	92	{94,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jut6VSxKeonhgw7ohQKfa7CyrrEJLcVqztsNXTN1ebdCsdnbvnC
93	93	{95}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtjPtUGthbmnYBmpdnxyLLRuZLJtmdXgpVAmvzKHVurfcNUWmBX
94	94	{96,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuJCrq3WRvuFwkFncsWVbM27ypL7M93jm7rKDLHMhW5z3ANwwzD
95	95	{97}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvA93FdjY5VoQuyEXpnRfSuPiLEeDQJDc6ecUj7GmrUPoMG6NMD
96	96	{98,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jus2ddoEym4iTkEenMv3w6Jk6jdEZhYjUA9fmsVZQ2ts5yK4pwQ
97	97	{99}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JupLnZvqsRV2iBSAPnwGGENBHLQbSB2hW8d8j2JikhpuaiMvvJ7
104	104	{106,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JukXh7d6akiH8U7wFhzBWQAE9zdYprZxKcB9mh4QYE1vu6PYQ6o
105	105	{107}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvRUGTeCsua2vsSu9MjBysfTEGSr6hpcvRxJbMFeAdPPXZW4QQY
106	106	{108,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtYavXVUgfcmtqV7TFmEZLQaJxMsro1qj37qCbGRZLu4qcNXoak
107	107	{109}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuSWQnHVY2RmhG5t3gDAFXyHynoZtXqhYxLzy8JKouzeAMrrfjx
108	108	{110,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvQ3onMQRpLWo3S1KhCCpYqVZcew7wnvZHiqgdGV5EY6WU4z9ye
109	109	{111}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuN4bRirSjScoY55zPtbNBecPMnNo3MSDXpjSPwK6dL4WaJmtK6
110	110	{112,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuM6fFH7GYEn7jyRfgzU2J2K6JrdzSmGWN1DHhXtk7Yt3uF7wJV
111	111	{113}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvLhUJoGN7B5dPPY4iz8tU6WKzP5L3w16jFd2zHnrGdSSRS7drB
112	112	{114,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JurJu6DyYqMygWT3oAfdkSKfobvk7HAzdxgSwaCaScH52DH8qnv
113	113	{115}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtaxmQc4trxvcfd37qMrUbsV3SkLR8gDaxY9y5F1ZMKYAvSDtwC
114	114	{116,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv6Ekv1YPvchjQwwSHxUFpJw1MvZuVc1Cz3Z3HJxFxJzcvCnWUJ
115	115	{117}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvN2jqx5aBB7n14frcjodRwPLs3V9RiRtFnHRD1zMWGi5dX3Ew2
116	116	{118,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv1yXuE9XCV9AtoZx7mfnSPLahEbHvomeRgD8e4BhgFKp68YEY4
117	117	{119}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jttynh7anrJRF7xjBvxBBkCbsQyzzpcB71vFLKABvjYK2Eutoox
118	118	{120,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtgWQPEzotSfU4iKt2cnXJ6gdPAHuVNtfWL3sVxEWhS6Mi3KSMf
119	119	{121}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju3B2ExYn7GhoNzZBtWEiKma2CsMQL961eMv1SHrcYQ2UkgapkC
120	120	{122,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuGdKgEkVxrZ4HwNqdfHcUCooXYvosp3hQALcvhkmhEWRA2qwxo
121	121	{123}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JukKeYD3s9v1bXwxKq8MiZktB7XqyMfc31EJcCsBisQFSG8nRgs
122	122	{124,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtkpYpEXVreNJxLLFPkvbyswyYTyTrcHzKbPgW9VGK6aihioQG3
123	123	{125}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvDCqZb2sgs7Jsu9xFT3MnbD7xVYirM4QF2zyRaaG5EBXEZgRum
124	124	{126,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtXABPUoUZs7gXtrroikwL3YfHCifhT4itiuKGydp4wF4DWRwtt
125	125	{127}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju2j3PZFTGDgEy9xnTh9KkuJtWgMmmCmE3HSPyHevAsP3CEh1hq
126	126	{128,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv6rdgMF6m623B1xbeh1SSWDTc9u5ovkjV6CHQg6MQKXzuDNTth
127	127	{129}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtasdL8iLRwvG4VSQWwK9X1z6yFDLgwkMDakghhFeiu1712o7t7
128	128	{130,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtWFFn7hgS3kp4CWEp7SjHTubh1x5HaUsgbKFY2ukQc5WYW9xhR
129	129	{131}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuWx5h37fGjitW3DmYWH7huoUF4G3vrbmxPGkG9qJ1WTRbZxZsX
98	98	{100,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtYfbL1TemHiPRuFZ85Zpug5TpocafmxAA5XYxeeu6TW6z4JVDA
99	99	{101}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JurtCDUyUXTKZi3JnRVAxjp96HX5REtCVKxpcFanc5aQvXPgNkY
100	100	{102,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuE81CS4EAciVEUdrpA5RE5XmdvgdANFBY5pUyCCmDY5JZnsN34
101	101	{103}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv4RdVdf4By2JEcfeajAPRw2oVLqh6dtScGfbazdQqngAd5GLBQ
102	102	{104,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvEtHwvE4CjLHUq36GWvDSz9cCat5SPg27RuL8fPbgfbcpfuiM8
103	103	{105}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JttLvQNSbqKCFBxRapFA3chBYjq5LYV3dWzKqMBNwGVAD2kQKAB
130	130	{132,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuW9Jav8avpDmJ34uqyuMiATsH3b6wSppiie7JdAmbX7cMVn7zZ
131	131	{133}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuaejMKPNFosvJjp2mDQgT1XxcL9JD8A6AkETFhtYBWbs3f2Qgz
132	132	{134,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtaj71yqqAAMqh5b1MUeziPNfksLZ9pnUbGZyLMCeYDyQU5jGFN
133	133	{135}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtbq8pgtvrmP7jQfByKxMyyQa5AoAR4kvrsk1iiZy6FL8t8hDST
134	134	{136,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuMEqRmPbetFtqJcYJxpdM7uVQKzRJLmzMytXXriSpRHGa4qqxG
135	135	{137}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuidbTyvKRp8bHr4x9JqN96tVHxxKXDFxzBHR91HzGHiKtjUgB6
136	136	{138,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juihj1bD2WiUQbZ5GvtHLV4JmPBxQ4XEpfu6qBJzuuXcL6xUFUR
137	137	{139}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuUCoET9WaUNW9xrqmw5a61esLmqu26RaRub3Q3VSaLqksetLc5
138	138	{140,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JttkGYJggVSg25cxCvQTkwAEeNgVXFtcCcfcfdifT2d9bHk6d8N
139	139	{141}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuxfPEUU71cvByncRzkbaQGpw3owhVrh2mwFNPc4ev5CKDaMhMo
140	140	{142,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtwApRd13eM2Ap2128AtS24vNHaneWNjfuw8756CSBpokWnBvVJ
141	141	{143}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvCf9XgEBHA7zv8aWpXM6Y86KJskzR1tRHEjeCSK5bksW8QqGvL
142	142	{144,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvKppxCyF84HVx4xGUo7fp7XhCLbc54UUnUcETFkyisUJGUNCHP
143	143	{145}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuwbjaNB1J6J21dB2PB7HK3ZLCKb8Jf6UaKQ8s3BsHhdtJ35imQ
144	144	{146,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvPXFgp9tkrNedFjkfFYCUxzyHyHU4GbL6bnrapcp3W23VpqSEU
145	145	{147}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JutMwMt1FJYMnbnvFHaALHPPxmToiFgTtJVrQmsykMhYUQhUL1m
146	146	{148,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuJRiZvjkhgQMBp6MdSwK3yEtGvjWs8AgZ6h6M4KpUDSoYyPKzp
147	147	{149}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuegTwf1Nvpqe2LhFJ8sLgQDsJ1kEeXNBP2jZLcKfQRwXi38YhP
148	148	{150,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juc2dNU5sv8WxnSY1vFceS8DsPseXzbLX5aFGDHJeiynG6Ztu44
149	149	{151}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvNCis6YYwAV7n51KgWPHhj5scvvywCsDbrgv74gBMiQWt6WSVe
150	150	{152,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juv3T62UVNbAFfKjhmDj94Zfj43U4mVRBKD5Cso37pCQDzxFGcd
151	151	{153}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuSARhdLf3UVMidw7P6MCB74P8zPZVyFwcxCgZ8axaSP8U2x5id
152	152	{154,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtvxZhhXKr3M8Y8TFh2L22UXCHUB8da26XBw1qcB2Fypp493Fi1
153	153	{155}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju7P41bhXtHJXSTro2amSreZNWDsmrTkVrDdmhC5CTqgzzjoKG1
154	154	{156,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvKSKWo9q91CukUnNbXtFz6ENt7xM1MmyF3Cv4mEWrfHF5YE3ES
155	155	{157}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv98K64JVr13GiPKJgkqDKxcHhuwxN9qLHzTkthRQW9s3gRBjds
156	156	{158,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtshptyCU6qCckcynjWHKN5ZQWKa7pBma1Cm33orDi2a6uZJ1fy
157	157	{159}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuZrwKbBrxZg9iCqy4PeEmVi9bFbYFCJTiqtEq252TRz1ZeXM9T
158	158	{160,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv1TGwmqT2PCvJUchjs6V9fbNAgwsSNRDgdzhiWsjCbT1tQreWi
159	159	{161}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvL1QamCaDbPB1ze3sCLMChMbG5U11LSohWQWGfVe542SrgNDKU
160	160	{162,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuS8Qqnmn6pAUGkK3E7MRJLqhwUt4ZqspDHKKBhQypXqtuAcXDr
161	161	{163}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvMsAwNiu52rheGs6fgb7CPjLz6hHosiHs8FKDgekVVdULe2HYN
162	162	{164,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvGSGh3sBXom7WwmkJHU4rivpRKQDZ5cQTiiTsyAjwyu438tmbe
163	163	{165}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv1GBV6LsQzAJEZin8k1z73VHnRx4rXQhsDG8K8VuYbnQEw86La
164	164	{166,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtvukSauDcXRYH6rxyTnLWaMh89mUyiYcwjTAf5MQF7erdKHSVw
165	165	{167}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv31npDs9rBeDLsmu87dPoza2zUD5hSxQefiF4SQPTFEcbVrfcv
166	166	{168,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv6ZMhNDnXSJiuJm5naBciQVwPWn7PZY34TqAS4PCzwyafcrh9Y
167	167	{169}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuvkiugJRUPgGVTUPtZx79BYdH7LDZa3KPYyRX7vgK9jJKy5WWe
168	168	{170,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtX9AQFFzZdRWC9UdmEfkN8JQXcUmV7H3SDxTWxZkN2fYRQkP81
169	169	{171}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvJoAC8sijwckwQriQU5mz6ckrNiKG9apTW1H2V4RZ71w857sei
170	170	{172,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JukKSp7SBYvD1TCwUAK19QtXinveFvSa9MhEFmXko8JhHsNaVir
171	171	{173}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju13Y6qtB2GStNka6A5BNeJToZvmUkhA82WyK3QFoEJvqsJXmHi
172	172	{174,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuKahgnRwuuTn8G2JBkKUHsYBN4cUELxeWD6AV1Ns6MyZ5phmPP
173	173	{175}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuBJ3D9N5YZrhLrgUKFiFVEoW74dpkaoafMCCqLuwm1nE5PNn3M
174	174	{176,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuNZ7zTbYXd1C2BsfEGRxSG77U2Bb3xLmt5XBMda5zG6ppwr9W2
175	175	{177}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvPsh7J3BitAi5L7FSJjBtCvXKPfFyMYfgAkvp2vMvS6V6VmjEq
176	176	{178,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtrZsXfFwSyi6Uv8tXDB5SLrpuqJyv8zPUVtUcp1HPjvZgh8SXp
177	177	{179}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JujNiBagUgqVJiV9jpJxjcuJZhjbcnb5dYRiHhpuefbGjgZqkzu
178	178	{180,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuYc95B4hzgs55RUpKJi2feHq8ju3TqcWhhLwXJFMpS5thJxnfT
179	179	{181}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvEqvmrTRX6oa1uufTuzWTuLga5eczfJFh2BsjAXryqyDpAyJTD
180	180	{182,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuWnY8THpZvTxQaT4Ripfnfi9eGevQDeH5dFSGHRDLXYWD4mPrq
181	181	{183}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuDjqcavKP4bQBgf3yW38JX4YcQMrFkLAueQJS75LNxRzq5kxCR
182	182	{184,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuheQf3JdL7LYLf7ZdLAkxQMR5eADjFun3P165V9fkm1Cf2ry1p
183	183	{185}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtdm9gmn6UZuBpfoiFni6bD6VZJMB7CE9mxjZUwa4VC5LYiwbzF
184	184	{186,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuG9y95VkZXsdJRye43nqjLxH9Wjmys4ffTmBapyq1R9gEXfo8L
185	185	{187}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvARx4ky3EvG9LL4C7sVttETrpwKz39AqnUeSyuDvyMSvo1soPM
186	186	{188,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvBaEnJvrDCFihUXw7R2ZdfE3sCjXaJaw8NeVCEvEKerYVkJmJa
187	187	{189}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuHA8NGrTUAKPB4ZdAuYx1uD2s7TgA4DDvN2bUZStYbqFN3H28t
188	188	{190,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuKRh4Lf17YLH6eFcnDPL6xJ1594UB1C8oT7f89KmMvPPHqkv3v
189	189	{191}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juv6FNpPHAzpYkxLcVMwr3h4ou9zGDnRVkJ41j4XNCVCHoa8CVY
190	190	{192,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv1EcN4XCoKk2VrDCifhZ2dCARzQAnbNBmtY5hWuQ9kykAU5tRU
191	191	{193}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtjGvXfvq3pmRb4sbwXWeHiptH5oD5qfkgnZaqUkVTLsXeygSDJ
192	192	{194,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuMZh1otXtRQCM6xNHrzwUYwTCygBr2bxEecKaSXEtWsRAYmQ5Z
193	193	{195}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuQHapTDLeqPzukxCwdM1zQR1nf2V5LLmgyueBcBu8HSR1Rh2PR
194	194	{196,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvBVHFFUATvZazm5dvsbqaQXNjWYihBxsTqmbQSsGoyBhNBc2Nf
195	195	{197}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvKmWY6S1H812HPrdRfptA6qi7PVGUZRMCtYL6MJXq4Enp2rc3f
196	196	{198,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtggnQgB7ph8sjMg8zy8y4UPbwWE659PtGvMKCkSL4Ps7Nw7BFg
197	197	{199}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuELXLA2XnRjhWP77VbEHUkiEdKT9HKt54KEew3mdzHDmBG1x6W
198	198	{200,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvKbJdDBGvLX5o62Qe9aDWqeLf5YP4pCGF9jTWrzAqMsjRL1WH6
199	199	{201}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv2D1r7aduvC5Zypu3gLVT9T67wnDk2a8HTjLEbtqjxB2BgyeyB
200	200	{202,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuqXAhzrm7CutHB15oyz2ENVDe1aXXDWJrrV4otxAqsD9x6TMgf
201	201	{203}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv5LNtJ4Ur1XoC5p8MyGuP6wTgdbzHqoZkURRb7etJ338ukKhKJ
202	202	{204,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvQdhaN92kLn2p5pwb7BjAiENLunWMEgzXmN9UDnWAdqMQh5S7R
203	203	{205}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtfXxtT2ygNtPu4fojV2gQ6QYJPbByC1cPjpLeYFvZuRexeHNfZ
204	204	{206,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju4rNWf45MXtDjkmsNEGwkxEQdttsrDhDLMa6fDVSW6yUiNx3Kv
205	205	{207}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JujKHAVCFkSNug2zXtjMLaEYrcY2HxSQ246hqwtgzMJHVZhJtJr
206	206	{208,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JttDAsaQXgtUobwph7Maoy8mfSCMXxUk8SH3at6dw6DE6dzUPSz
207	207	{209}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuUcAftLaCtWV5PtcXzuKWGrH1CeK4Neh6kt5wcwUcDK8yzvadK
208	208	{210,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju7LLGaGbrVDvnNPTq76DSJ6zWxAWC4g4i9KufFXjRsKXQvMGHy
209	209	{211}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JucpgX6jkQH9JSvjWqoWCtWA1noJDCCL5siftEh6TvV1dW6iUYd
210	210	{212,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju65KumtZiazcpv8ZuamTk8kG6NQisZBZ6HJKU4MDMaLmeYziBT
211	211	{213}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtetr4RqSHsCeNx9aLzPEA6UWeD19zqs9RNULAwNoruEPVt8Jt4
212	212	{214,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JueowxBD9xuusmiL49HC7BmzfBoFEHeAuWFTQYUZ6weTqtgdacp
213	213	{215}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuddmLdaMQson19tCSyd6xmRru3yTZQc3w12ZPfUy8U9LJE3ZEa
214	214	{216,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtrJsYz92UJ5uRXtYgcuzwbRoiiNLN9MQhCt7yUJjiRx7mjEnX4
215	215	{217}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuTGoYuEXAt1ruoEQGyR6YFknGa9vgfJxBFE5C5jo3vaw6dqK6b
216	216	{218,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuuvYSJdMwp3qDjizG1WPKDW4mu9BSLwFkeSh632pkqTcdGGMVV
217	217	{219}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtvVuLiRoJksVb5Mgo49bfdhZP16e71e1wCBmVadSohA5p2h2uW
218	218	{220,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JufJwtHEDH6oz9CYTaB8LmXrjbnuj54e5m4BQZcHky62aoapKgm
219	219	{221}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juriv8sgB7BaVBa8GFCQ4mTDK63EAStdBKDVXhag4ipWDhv1WxY
220	220	{222,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuG5gc9kj1GLnUDHff7md8sX9pkphCXU65dmFkW56L4E7D6A2fz
221	221	{223}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuFS1psgFFLF8HNgANprGDh5aA2VNRgswAARgeS9RZirJYgcssW
222	222	{224,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju11xz6NubYsdASwTtPxpLB9eWFEQkgi6FnbQgPcferfnh9Rdzp
223	223	{225}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju7WqjYujdKavxczAdqFGkmeGi9oXugAtnjAMPm2sAz4DdvCswG
224	224	{226,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv7qsjKwXTVBuBv9YFbWzte9GYLicWTgWYNwWSMsEnZ2S9jbFM7
225	225	{227}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju3pvPigKeEZ5Be22KRmM18VBYfsjaLSbCV4zcJRinRcbWV3uzT
226	226	{228,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JurCgsygkSfVA7Ai5ozxApS49BocTCRU3xBJ2rkYMtC15b5Y7sf
227	227	{229}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv9arra2NbUFrYrtJ9xD1CnA87aoKrJ4ukoUHEyDGkAfwueAVMp
228	228	{230,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuoLjVhLYMZZxtorbVFuDQZscKuixXfKZ9hTwaQMPjXxQvaYJL4
229	229	{231}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuYuv3goJqZtXWM2AJswpPKXux4hLa3N9gXKVpCChNTXBNZMxTf
230	230	{232,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JusYEzi8UBk6bpsxP8sUkGts1B97dpPCYB7fsw1eAkKCtC5uFtc
231	231	{233}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtppY4HmMjCfHmucXRUS38b4KFjwt6n183Sw3U9WowupMQMKYFL
232	232	{234,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuhA8KL8HP8BVzEeDyJiNiwe5zuU6cfpZ3cHoEi1rWBf1SoEmzv
233	233	{235}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuFgYjVeoNhiiH9FJ4VZB7wadaCse1ynqgHGcaRKcbmozbmM34r
234	234	{236,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuhUtkoeE7FTMnPiqFLwtQ3aX2371fVtdP4fr5YTwLd9vKyfnYd
235	235	{237}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuuB3s5WUd4sH7gybDstj3aDFw8njgCc4sZ131xnpKUdUW14TRS
236	236	{238,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtyBSHJzKdyV9pDVjJR5N2rb4waQBqMXSPx5qqA2RaPjLfwbACe
237	237	{239}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtdZ827fWK3q4KLA7EU85DxGQfhygQpwzN7BfMokAFqRLuaYEQo
238	238	{240,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtrZhis66inLrYFmPDPnQMa18YC4MSVDrarMgDsQ1qe6T3PXDYy
239	239	{241}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuaVe3b87UbD2R5LBJrK7iQ3oV33EN8muUa3m3DAKr9GpHkZQtg
240	240	{242,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtuREDtpkKXMnp6fK31o1DENAdc57nqaH7Dt8jGoqME7HqsHWKf
241	241	{243}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuqbFGNwqTuUAXhVF9SanLhqxXmjMYJBGBo9yzngNodwWrCp9pN
242	242	{244,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtYGgsUbJ4XXsUHxHukkQvEtQ8kaPGkYE66uyqBgPRenpbSDRcY
243	243	{245}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv4823dCdg5MMRaxm42QKPFyCqGfkm4hDDxHK7BMYuDbyEKqZ8E
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
1	170	5000000000	\N	0
2	170	5000000000	\N	1
3	170	5000000000	\N	2
4	170	5000000000	\N	3
5	170	5000000000	\N	4
6	170	5000000000	\N	5
7	170	5000000000	\N	6
8	170	5000000000	\N	7
9	170	5000000000	\N	8
10	170	5000000000	\N	9
11	170	5000000000	\N	10
12	170	5000000000	\N	11
13	170	5000000000	\N	12
14	170	5000000000	\N	13
15	170	5000000000	\N	14
16	170	5000000000	\N	15
17	170	5000000000	\N	16
18	170	5000000000	\N	17
19	170	5000000000	\N	18
20	170	5000000000	\N	19
21	170	5000000000	\N	20
22	170	5000000000	\N	21
23	170	5000000000	\N	22
24	170	5000000000	\N	23
25	170	5000000000	\N	24
26	170	5000000000	\N	25
27	170	5000000000	\N	26
28	170	5000000000	\N	27
29	170	5000000000	\N	28
30	170	5000000000	\N	29
31	170	5000000000	\N	30
32	170	5000000000	\N	31
33	170	5000000000	\N	32
34	170	5000000000	\N	33
35	170	5000000000	\N	34
36	170	5000000000	\N	35
37	170	5000000000	\N	36
38	170	5000000000	\N	37
39	170	5000000000	\N	38
40	170	5000000000	\N	39
41	170	5000000000	\N	40
42	170	5000000000	\N	41
43	170	5000000000	\N	42
44	170	5000000000	\N	43
45	170	5000000000	\N	44
46	170	5000000000	\N	45
47	170	5000000000	\N	46
48	170	5000000000	\N	47
49	170	5000000000	\N	48
50	170	5000000000	\N	49
51	170	5000000000	\N	50
52	170	5000000000	\N	51
53	170	5000000000	\N	52
54	170	5000000000	\N	53
55	170	5000000000	\N	54
56	170	5000000000	\N	55
57	170	5000000000	\N	56
58	170	5000000000	\N	57
59	170	5000000000	\N	58
60	170	5000000000	\N	59
61	170	5000000000	\N	60
62	170	5000000000	\N	61
63	170	5000000000	\N	62
64	170	5000000000	\N	63
65	170	5000000000	\N	64
66	170	5000000000	\N	65
67	170	5000000000	\N	66
68	170	5000000000	\N	67
69	170	5000000000	\N	68
70	170	5000000000	\N	69
71	170	5000000000	\N	70
72	170	5000000000	\N	71
73	170	5000000000	\N	72
74	170	5000000000	\N	73
75	170	5000000000	\N	74
76	170	5000000000	\N	75
77	170	5000000000	\N	76
78	170	5000000000	\N	77
79	170	5000000000	\N	78
80	170	5000000000	\N	79
81	170	5000000000	\N	80
82	170	5000000000	\N	81
83	170	5000000000	\N	82
84	170	5000000000	\N	83
85	170	5000000000	\N	84
86	170	5000000000	\N	85
87	170	5000000000	\N	86
88	170	5000000000	\N	87
89	170	5000000000	\N	88
90	170	5000000000	\N	89
91	170	5000000000	\N	90
92	170	5000000000	\N	91
93	170	5000000000	\N	92
94	170	5000000000	\N	93
95	170	5000000000	\N	94
96	170	5000000000	\N	95
97	170	5000000000	\N	96
98	170	5000000000	\N	97
99	170	5000000000	\N	98
100	170	5000000000	\N	99
101	170	5000000000	\N	100
102	170	5000000000	\N	101
103	170	5000000000	\N	102
104	170	5000000000	\N	103
105	170	5000000000	\N	104
106	170	5000000000	\N	105
107	170	5000000000	\N	106
108	170	5000000000	\N	107
109	170	5000000000	\N	108
110	170	5000000000	\N	109
111	170	5000000000	\N	110
112	170	5000000000	\N	111
113	170	5000000000	\N	112
114	170	5000000000	\N	113
115	170	5000000000	\N	114
116	170	5000000000	\N	115
117	170	5000000000	\N	116
118	170	5000000000	\N	117
119	170	5000000000	\N	118
120	170	5000000000	\N	119
121	170	5000000000	\N	120
122	170	5000000000	\N	121
123	170	5000000000	\N	122
124	170	5000000000	\N	123
125	170	5000000000	\N	124
126	170	5000000000	\N	125
127	170	5000000000	\N	126
128	170	5000000000	\N	127
129	170	5000000000	\N	128
130	170	5000000000	\N	129
131	170	5000000000	\N	130
132	170	5000000000	\N	131
133	170	5000000000	\N	132
134	170	5000000000	\N	133
135	170	5000000000	\N	134
136	170	5000000000	\N	135
137	170	5000000000	\N	136
138	170	5000000000	\N	137
139	170	5000000000	\N	138
140	170	5000000000	\N	139
141	170	5000000000	\N	140
142	170	5000000000	\N	141
149	170	5000000000	\N	148
150	170	5000000000	\N	149
151	170	5000000000	\N	150
152	170	5000000000	\N	151
153	170	5000000000	\N	152
154	170	5000000000	\N	153
169	170	5000000000	\N	168
170	170	5000000000	\N	169
171	170	5000000000	\N	170
172	170	5000000000	\N	171
173	170	5000000000	\N	172
174	170	5000000000	\N	173
175	170	5000000000	\N	174
176	170	5000000000	\N	175
177	170	5000000000	\N	176
178	170	5000000000	\N	177
179	170	5000000000	\N	178
180	170	5000000000	\N	179
181	170	5000000000	\N	180
182	170	5000000000	\N	181
183	170	5000000000	\N	182
184	170	5000000000	\N	183
185	170	5000000000	\N	184
186	170	5000000000	\N	185
187	170	5000000000	\N	186
143	170	5000000000	\N	142
144	170	5000000000	\N	143
145	170	5000000000	\N	144
146	170	5000000000	\N	145
147	170	5000000000	\N	146
148	170	5000000000	\N	147
155	170	5000000000	\N	154
156	170	5000000000	\N	155
157	170	5000000000	\N	156
158	170	5000000000	\N	157
159	170	5000000000	\N	158
160	170	5000000000	\N	159
161	170	5000000000	\N	160
162	170	5000000000	\N	161
163	170	5000000000	\N	162
164	170	5000000000	\N	163
165	170	5000000000	\N	164
166	170	5000000000	\N	165
167	170	5000000000	\N	166
168	170	5000000000	\N	167
188	170	5000000000	\N	187
189	170	5000000000	\N	188
190	170	5000000000	\N	189
191	170	5000000000	\N	190
192	170	5000000000	\N	191
193	170	5000000000	\N	192
194	170	5000000000	\N	193
195	170	5000000000	\N	194
196	170	5000000000	\N	195
197	170	5000000000	\N	196
198	170	5000000000	\N	197
199	170	5000000000	\N	198
200	170	5000000000	\N	199
201	170	5000000000	\N	200
202	170	5000000000	\N	201
203	170	5000000000	\N	202
204	170	5000000000	\N	203
205	170	5000000000	\N	204
206	170	5000000000	\N	205
207	170	5000000000	\N	206
208	170	5000000000	\N	207
209	170	5000000000	\N	208
210	170	5000000000	\N	209
211	170	5000000000	\N	210
212	170	5000000000	\N	211
213	170	5000000000	\N	212
214	170	5000000000	\N	213
215	170	5000000000	\N	214
216	170	5000000000	\N	215
217	170	5000000000	\N	216
218	170	5000000000	\N	217
219	170	5000000000	\N	218
220	170	5000000000	\N	219
221	170	5000000000	\N	220
222	170	5000000000	\N	221
223	170	5000000000	\N	222
224	170	5000000000	\N	223
225	170	5000000000	\N	224
226	170	5000000000	\N	225
227	170	5000000000	\N	226
228	170	5000000000	\N	227
229	170	5000000000	\N	228
230	170	5000000000	\N	229
231	170	5000000000	\N	230
232	170	5000000000	\N	231
233	170	5000000000	\N	232
234	170	5000000000	\N	233
235	170	5000000000	\N	234
236	170	5000000000	\N	235
237	170	5000000000	\N	236
238	170	5000000000	\N	237
239	170	5000000000	\N	238
240	170	5000000000	\N	239
241	170	5000000000	\N	240
242	170	5000000000	\N	241
243	170	5000000000	\N	242
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

COPY public.zkapp_states (id, element0, element1, element2, element3, element4, element5, element6, element7, element8, element9, element10, element11, element12, element13, element14, element15, element16, element17, element18, element19, element20, element21, element22, element23, element24, element25, element26, element27, element28, element29, element30, element31) FROM stdin;
\.


--
-- Data for Name: zkapp_states_nullable; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.zkapp_states_nullable (id, element0, element1, element2, element3, element4, element5, element6, element7, element8, element9, element10, element11, element12, element13, element14, element15, element16, element17, element18, element19, element20, element21, element22, element23, element24, element25, element26, element27, element28, element29, element30, element31) FROM stdin;
1	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
2	1	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
3	2	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
4	3	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
5	4	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
6	5	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
7	6	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
8	7	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
9	8	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
10	9	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
11	10	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
12	11	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
13	12	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
14	13	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
15	14	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
16	15	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
17	16	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
18	17	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
19	18	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
20	19	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
21	20	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
22	21	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
23	22	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
24	23	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
25	24	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
26	25	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
27	26	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
28	27	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
29	28	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
30	29	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
31	30	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
32	31	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
33	32	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
34	33	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
35	34	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
36	35	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
37	36	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
38	37	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
39	38	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
40	39	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
41	40	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
42	41	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
43	42	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
44	43	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
45	44	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
46	45	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
47	46	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
48	47	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
49	48	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
50	49	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
51	50	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
52	51	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
53	52	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
54	53	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
55	54	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
56	55	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
57	56	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
58	57	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
59	58	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
60	59	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
61	60	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
62	61	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
63	62	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
64	63	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
65	64	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
66	65	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
67	66	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
68	67	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
69	68	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
70	69	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
71	70	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
72	71	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
73	72	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
74	73	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
75	74	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
76	75	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
77	76	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
78	77	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
79	78	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
80	79	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
81	80	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
82	81	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
83	82	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
84	83	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
85	84	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
86	85	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
87	86	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
88	87	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
89	88	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
90	89	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
91	90	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
92	91	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
93	92	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
94	93	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
95	94	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
96	95	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
97	96	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
98	97	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
99	98	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
100	99	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
101	100	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
102	101	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
103	102	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
104	103	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
105	104	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
106	105	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
107	106	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
108	107	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
109	108	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
110	109	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
111	110	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
112	111	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
113	112	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
114	113	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
115	114	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
116	115	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
117	116	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
118	117	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
119	118	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
120	119	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
121	120	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
122	121	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
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

SELECT pg_catalog.setval('public.blocks_id_seq', 40, true);


--
-- Name: epoch_data_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.epoch_data_id_seq', 41, true);


--
-- Name: internal_commands_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.internal_commands_id_seq', 34, true);


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

SELECT pg_catalog.setval('public.user_commands_id_seq', 123, true);


--
-- Name: voting_for_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.voting_for_id_seq', 1, true);


--
-- Name: zkapp_account_precondition_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_account_precondition_id_seq', 123, true);


--
-- Name: zkapp_account_update_body_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_account_update_body_id_seq', 245, true);


--
-- Name: zkapp_account_update_failures_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_account_update_failures_id_seq', 4, true);


--
-- Name: zkapp_account_update_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_account_update_id_seq', 245, true);


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

SELECT pg_catalog.setval('public.zkapp_commands_id_seq', 243, true);


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

SELECT pg_catalog.setval('public.zkapp_fee_payer_body_id_seq', 243, true);


--
-- Name: zkapp_field_array_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_field_array_id_seq', 1, false);


--
-- Name: zkapp_field_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_field_id_seq', 121, true);


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

SELECT pg_catalog.setval('public.zkapp_nonce_bounds_id_seq', 122, true);


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

SELECT pg_catalog.setval('public.zkapp_states_nullable_id_seq', 122, true);


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

SELECT pg_catalog.setval('public.zkapp_updates_id_seq', 123, true);


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
-- Name: zkapp_states zkapp_states_element10_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_states
    ADD CONSTRAINT zkapp_states_element10_fkey FOREIGN KEY (element10) REFERENCES public.zkapp_field(id);


--
-- Name: zkapp_states zkapp_states_element11_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_states
    ADD CONSTRAINT zkapp_states_element11_fkey FOREIGN KEY (element11) REFERENCES public.zkapp_field(id);


--
-- Name: zkapp_states zkapp_states_element12_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_states
    ADD CONSTRAINT zkapp_states_element12_fkey FOREIGN KEY (element12) REFERENCES public.zkapp_field(id);


--
-- Name: zkapp_states zkapp_states_element13_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_states
    ADD CONSTRAINT zkapp_states_element13_fkey FOREIGN KEY (element13) REFERENCES public.zkapp_field(id);


--
-- Name: zkapp_states zkapp_states_element14_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_states
    ADD CONSTRAINT zkapp_states_element14_fkey FOREIGN KEY (element14) REFERENCES public.zkapp_field(id);


--
-- Name: zkapp_states zkapp_states_element15_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_states
    ADD CONSTRAINT zkapp_states_element15_fkey FOREIGN KEY (element15) REFERENCES public.zkapp_field(id);


--
-- Name: zkapp_states zkapp_states_element16_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_states
    ADD CONSTRAINT zkapp_states_element16_fkey FOREIGN KEY (element16) REFERENCES public.zkapp_field(id);


--
-- Name: zkapp_states zkapp_states_element17_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_states
    ADD CONSTRAINT zkapp_states_element17_fkey FOREIGN KEY (element17) REFERENCES public.zkapp_field(id);


--
-- Name: zkapp_states zkapp_states_element18_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_states
    ADD CONSTRAINT zkapp_states_element18_fkey FOREIGN KEY (element18) REFERENCES public.zkapp_field(id);


--
-- Name: zkapp_states zkapp_states_element19_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_states
    ADD CONSTRAINT zkapp_states_element19_fkey FOREIGN KEY (element19) REFERENCES public.zkapp_field(id);


--
-- Name: zkapp_states zkapp_states_element1_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_states
    ADD CONSTRAINT zkapp_states_element1_fkey FOREIGN KEY (element1) REFERENCES public.zkapp_field(id);


--
-- Name: zkapp_states zkapp_states_element20_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_states
    ADD CONSTRAINT zkapp_states_element20_fkey FOREIGN KEY (element20) REFERENCES public.zkapp_field(id);


--
-- Name: zkapp_states zkapp_states_element21_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_states
    ADD CONSTRAINT zkapp_states_element21_fkey FOREIGN KEY (element21) REFERENCES public.zkapp_field(id);


--
-- Name: zkapp_states zkapp_states_element22_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_states
    ADD CONSTRAINT zkapp_states_element22_fkey FOREIGN KEY (element22) REFERENCES public.zkapp_field(id);


--
-- Name: zkapp_states zkapp_states_element23_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_states
    ADD CONSTRAINT zkapp_states_element23_fkey FOREIGN KEY (element23) REFERENCES public.zkapp_field(id);


--
-- Name: zkapp_states zkapp_states_element24_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_states
    ADD CONSTRAINT zkapp_states_element24_fkey FOREIGN KEY (element24) REFERENCES public.zkapp_field(id);


--
-- Name: zkapp_states zkapp_states_element25_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_states
    ADD CONSTRAINT zkapp_states_element25_fkey FOREIGN KEY (element25) REFERENCES public.zkapp_field(id);


--
-- Name: zkapp_states zkapp_states_element26_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_states
    ADD CONSTRAINT zkapp_states_element26_fkey FOREIGN KEY (element26) REFERENCES public.zkapp_field(id);


--
-- Name: zkapp_states zkapp_states_element27_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_states
    ADD CONSTRAINT zkapp_states_element27_fkey FOREIGN KEY (element27) REFERENCES public.zkapp_field(id);


--
-- Name: zkapp_states zkapp_states_element28_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_states
    ADD CONSTRAINT zkapp_states_element28_fkey FOREIGN KEY (element28) REFERENCES public.zkapp_field(id);


--
-- Name: zkapp_states zkapp_states_element29_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_states
    ADD CONSTRAINT zkapp_states_element29_fkey FOREIGN KEY (element29) REFERENCES public.zkapp_field(id);


--
-- Name: zkapp_states zkapp_states_element2_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_states
    ADD CONSTRAINT zkapp_states_element2_fkey FOREIGN KEY (element2) REFERENCES public.zkapp_field(id);


--
-- Name: zkapp_states zkapp_states_element30_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_states
    ADD CONSTRAINT zkapp_states_element30_fkey FOREIGN KEY (element30) REFERENCES public.zkapp_field(id);


--
-- Name: zkapp_states zkapp_states_element31_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_states
    ADD CONSTRAINT zkapp_states_element31_fkey FOREIGN KEY (element31) REFERENCES public.zkapp_field(id);


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
-- Name: zkapp_states zkapp_states_element8_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_states
    ADD CONSTRAINT zkapp_states_element8_fkey FOREIGN KEY (element8) REFERENCES public.zkapp_field(id);


--
-- Name: zkapp_states zkapp_states_element9_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_states
    ADD CONSTRAINT zkapp_states_element9_fkey FOREIGN KEY (element9) REFERENCES public.zkapp_field(id);


--
-- Name: zkapp_states_nullable zkapp_states_nullable_element0_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_states_nullable
    ADD CONSTRAINT zkapp_states_nullable_element0_fkey FOREIGN KEY (element0) REFERENCES public.zkapp_field(id);


--
-- Name: zkapp_states_nullable zkapp_states_nullable_element10_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_states_nullable
    ADD CONSTRAINT zkapp_states_nullable_element10_fkey FOREIGN KEY (element10) REFERENCES public.zkapp_field(id);


--
-- Name: zkapp_states_nullable zkapp_states_nullable_element11_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_states_nullable
    ADD CONSTRAINT zkapp_states_nullable_element11_fkey FOREIGN KEY (element11) REFERENCES public.zkapp_field(id);


--
-- Name: zkapp_states_nullable zkapp_states_nullable_element12_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_states_nullable
    ADD CONSTRAINT zkapp_states_nullable_element12_fkey FOREIGN KEY (element12) REFERENCES public.zkapp_field(id);


--
-- Name: zkapp_states_nullable zkapp_states_nullable_element13_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_states_nullable
    ADD CONSTRAINT zkapp_states_nullable_element13_fkey FOREIGN KEY (element13) REFERENCES public.zkapp_field(id);


--
-- Name: zkapp_states_nullable zkapp_states_nullable_element14_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_states_nullable
    ADD CONSTRAINT zkapp_states_nullable_element14_fkey FOREIGN KEY (element14) REFERENCES public.zkapp_field(id);


--
-- Name: zkapp_states_nullable zkapp_states_nullable_element15_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_states_nullable
    ADD CONSTRAINT zkapp_states_nullable_element15_fkey FOREIGN KEY (element15) REFERENCES public.zkapp_field(id);


--
-- Name: zkapp_states_nullable zkapp_states_nullable_element16_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_states_nullable
    ADD CONSTRAINT zkapp_states_nullable_element16_fkey FOREIGN KEY (element16) REFERENCES public.zkapp_field(id);


--
-- Name: zkapp_states_nullable zkapp_states_nullable_element17_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_states_nullable
    ADD CONSTRAINT zkapp_states_nullable_element17_fkey FOREIGN KEY (element17) REFERENCES public.zkapp_field(id);


--
-- Name: zkapp_states_nullable zkapp_states_nullable_element18_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_states_nullable
    ADD CONSTRAINT zkapp_states_nullable_element18_fkey FOREIGN KEY (element18) REFERENCES public.zkapp_field(id);


--
-- Name: zkapp_states_nullable zkapp_states_nullable_element19_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_states_nullable
    ADD CONSTRAINT zkapp_states_nullable_element19_fkey FOREIGN KEY (element19) REFERENCES public.zkapp_field(id);


--
-- Name: zkapp_states_nullable zkapp_states_nullable_element1_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_states_nullable
    ADD CONSTRAINT zkapp_states_nullable_element1_fkey FOREIGN KEY (element1) REFERENCES public.zkapp_field(id);


--
-- Name: zkapp_states_nullable zkapp_states_nullable_element20_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_states_nullable
    ADD CONSTRAINT zkapp_states_nullable_element20_fkey FOREIGN KEY (element20) REFERENCES public.zkapp_field(id);


--
-- Name: zkapp_states_nullable zkapp_states_nullable_element21_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_states_nullable
    ADD CONSTRAINT zkapp_states_nullable_element21_fkey FOREIGN KEY (element21) REFERENCES public.zkapp_field(id);


--
-- Name: zkapp_states_nullable zkapp_states_nullable_element22_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_states_nullable
    ADD CONSTRAINT zkapp_states_nullable_element22_fkey FOREIGN KEY (element22) REFERENCES public.zkapp_field(id);


--
-- Name: zkapp_states_nullable zkapp_states_nullable_element23_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_states_nullable
    ADD CONSTRAINT zkapp_states_nullable_element23_fkey FOREIGN KEY (element23) REFERENCES public.zkapp_field(id);


--
-- Name: zkapp_states_nullable zkapp_states_nullable_element24_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_states_nullable
    ADD CONSTRAINT zkapp_states_nullable_element24_fkey FOREIGN KEY (element24) REFERENCES public.zkapp_field(id);


--
-- Name: zkapp_states_nullable zkapp_states_nullable_element25_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_states_nullable
    ADD CONSTRAINT zkapp_states_nullable_element25_fkey FOREIGN KEY (element25) REFERENCES public.zkapp_field(id);


--
-- Name: zkapp_states_nullable zkapp_states_nullable_element26_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_states_nullable
    ADD CONSTRAINT zkapp_states_nullable_element26_fkey FOREIGN KEY (element26) REFERENCES public.zkapp_field(id);


--
-- Name: zkapp_states_nullable zkapp_states_nullable_element27_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_states_nullable
    ADD CONSTRAINT zkapp_states_nullable_element27_fkey FOREIGN KEY (element27) REFERENCES public.zkapp_field(id);


--
-- Name: zkapp_states_nullable zkapp_states_nullable_element28_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_states_nullable
    ADD CONSTRAINT zkapp_states_nullable_element28_fkey FOREIGN KEY (element28) REFERENCES public.zkapp_field(id);


--
-- Name: zkapp_states_nullable zkapp_states_nullable_element29_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_states_nullable
    ADD CONSTRAINT zkapp_states_nullable_element29_fkey FOREIGN KEY (element29) REFERENCES public.zkapp_field(id);


--
-- Name: zkapp_states_nullable zkapp_states_nullable_element2_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_states_nullable
    ADD CONSTRAINT zkapp_states_nullable_element2_fkey FOREIGN KEY (element2) REFERENCES public.zkapp_field(id);


--
-- Name: zkapp_states_nullable zkapp_states_nullable_element30_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_states_nullable
    ADD CONSTRAINT zkapp_states_nullable_element30_fkey FOREIGN KEY (element30) REFERENCES public.zkapp_field(id);


--
-- Name: zkapp_states_nullable zkapp_states_nullable_element31_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_states_nullable
    ADD CONSTRAINT zkapp_states_nullable_element31_fkey FOREIGN KEY (element31) REFERENCES public.zkapp_field(id);


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
-- Name: zkapp_states_nullable zkapp_states_nullable_element8_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_states_nullable
    ADD CONSTRAINT zkapp_states_nullable_element8_fkey FOREIGN KEY (element8) REFERENCES public.zkapp_field(id);


--
-- Name: zkapp_states_nullable zkapp_states_nullable_element9_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_states_nullable
    ADD CONSTRAINT zkapp_states_nullable_element9_fkey FOREIGN KEY (element9) REFERENCES public.zkapp_field(id);


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

