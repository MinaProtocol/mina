--
-- PostgreSQL database dump
--

-- Dumped from database version 12.18 (Ubuntu 12.18-0ubuntu0.20.04.1)
-- Dumped by pg_dump version 14.6

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
134	136	1
135	137	1
136	138	1
137	139	1
138	140	1
139	141	1
140	142	1
141	143	1
142	144	1
143	145	1
144	146	1
145	147	1
146	113	1
147	148	1
148	149	1
149	150	1
150	151	1
151	152	1
152	153	1
153	154	1
154	155	1
155	156	1
156	157	1
157	158	1
158	159	1
159	160	1
160	161	1
161	162	1
162	163	1
163	164	1
164	165	1
165	166	1
166	167	1
167	168	1
168	169	1
169	170	1
170	171	1
171	172	1
172	173	1
173	174	1
174	175	1
175	176	1
176	177	1
177	178	1
178	179	1
179	180	1
180	181	1
181	182	1
182	183	1
183	184	1
184	185	1
185	186	1
186	187	1
187	1	1
188	188	1
189	189	1
190	190	1
191	191	1
192	192	1
193	193	1
194	194	1
195	195	1
196	196	1
197	197	1
198	198	1
199	199	1
200	200	1
201	201	1
202	202	1
203	203	1
204	204	1
205	205	1
206	206	1
207	207	1
208	208	1
209	209	1
210	210	1
211	211	1
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
5	1	14	1	0	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	15	1	14	1	\N
153	1	15	1	79	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	16	1	15	1	\N
166	1	16	1	206	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	17	1	16	1	\N
137	1	17	1	340	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	18	1	17	1	\N
105	1	18	1	382	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	19	1	18	1	\N
70	1	19	1	488	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	20	1	19	1	\N
27	1	20	1	135	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	21	1	20	1	\N
46	1	21	1	126	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	22	1	21	1	\N
43	1	22	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	23	1	22	1	\N
117	1	23	1	278	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	24	1	23	1	\N
204	1	24	1	46	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	25	1	24	1	\N
187	1	25	1	104	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	26	1	25	1	\N
72	1	26	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	27	1	26	1	\N
216	1	27	1	271	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
210	1	28	1	315	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	29	1	28	1	\N
79	1	29	1	162	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	30	1	29	1	\N
167	1	30	1	86	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	31	1	30	1	\N
181	1	31	1	409	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	32	1	31	1	\N
156	1	32	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	33	1	32	1	\N
96	1	33	1	57	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	34	1	33	1	\N
191	1	34	1	204	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	35	1	34	1	\N
3	1	35	1	500000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	36	1	35	1	\N
132	1	36	1	262	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	37	1	36	1	\N
111	1	37	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	38	1	37	1	\N
171	1	38	1	156	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	39	1	38	1	\N
64	1	39	1	417	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	40	1	39	1	\N
68	1	40	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	41	1	40	1	\N
51	1	41	1	85	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	42	1	41	1	\N
227	1	42	1	103	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	43	1	42	1	\N
141	1	43	1	67	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	44	1	43	1	\N
42	1	44	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	45	1	44	1	\N
133	1	45	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	46	1	45	1	\N
82	1	46	1	198	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	47	1	46	1	\N
95	1	47	1	489	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	48	1	47	1	\N
188	1	48	1	298	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	49	1	48	1	\N
30	1	49	1	36	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	50	1	49	1	\N
90	1	50	1	334	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	51	1	50	1	\N
14	1	51	1	344	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	52	1	51	1	\N
35	1	52	1	451	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	53	1	52	1	\N
85	1	53	1	371	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	54	1	53	1	\N
127	1	54	1	234	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	55	1	54	1	\N
222	1	55	1	345	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	56	1	55	1	\N
76	1	56	1	282	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
231	1	57	1	339	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	58	1	57	1	\N
15	1	58	1	215	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	59	1	58	1	\N
220	1	59	1	193	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	60	1	59	1	\N
16	1	60	1	60	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	61	1	60	1	\N
58	1	61	1	350	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	62	1	61	1	\N
146	1	62	1	223	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	63	1	62	1	\N
62	1	63	1	449	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	64	1	63	1	\N
185	1	64	1	142	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	65	1	64	1	\N
151	1	65	1	300	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	66	1	65	1	\N
165	1	66	1	256	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	67	1	66	1	\N
103	1	67	1	125	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	68	1	67	1	\N
41	1	68	1	236	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	69	1	68	1	\N
239	1	69	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	70	1	69	1	\N
110	1	70	1	179	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	71	1	70	1	\N
13	1	71	1	194	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	72	1	71	1	\N
26	1	72	1	185	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	73	1	72	1	\N
98	1	73	1	342	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	74	1	73	1	\N
215	1	74	1	157	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	75	1	74	1	\N
91	1	75	1	135	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	76	1	75	1	\N
159	1	76	1	456	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	77	1	76	1	\N
208	1	77	1	336	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	78	1	77	1	\N
207	1	78	1	280	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	79	1	78	1	\N
182	1	79	1	187	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	80	1	79	1	\N
157	1	80	1	387	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	81	1	80	1	\N
33	1	81	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	82	1	81	1	\N
201	1	82	1	151	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	83	1	82	1	\N
9	1	83	1	356	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	84	1	83	1	\N
234	1	84	1	24	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	85	1	84	1	\N
40	1	85	1	152	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	86	1	85	1	\N
18	1	86	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	87	1	86	1	\N
229	1	87	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	88	1	87	1	\N
20	1	88	1	186	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	89	1	88	1	\N
184	1	89	1	266	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	90	1	89	1	\N
139	1	90	1	81	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	91	1	90	1	\N
164	1	91	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	92	1	91	1	\N
199	1	92	1	379	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	93	1	92	1	\N
109	1	93	1	315	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	94	1	93	1	\N
47	1	94	1	226	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	95	1	94	1	\N
214	1	95	1	166	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	96	1	95	1	\N
112	1	96	1	302	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	97	1	96	1	\N
144	1	97	1	269	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	98	1	97	1	\N
178	1	98	1	172	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	99	1	98	1	\N
155	1	99	1	195	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	100	1	99	1	\N
38	1	100	1	243	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	101	1	100	1	\N
80	1	101	1	128	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	102	1	101	1	\N
147	1	102	1	349	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	103	1	102	1	\N
24	1	103	1	87	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	104	1	103	1	\N
126	1	104	1	424	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	105	1	104	1	\N
89	1	105	1	239	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	106	1	105	1	\N
135	1	106	1	316	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	107	1	106	1	\N
194	1	107	1	492	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	108	1	107	1	\N
190	1	108	1	294	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	109	1	108	1	\N
4	1	109	1	11550000000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	15	1	109	1	\N
218	1	110	1	191	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	111	1	110	1	\N
6	1	111	1	11550000000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	113	1	111	1	\N
93	1	112	1	380	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	114	1	112	1	\N
162	1	113	1	331	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	115	1	113	1	\N
221	1	114	1	459	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	116	1	114	1	\N
205	1	115	1	28	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	117	1	115	1	\N
195	1	116	1	472	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	118	1	116	1	\N
34	1	117	1	119	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	119	1	117	1	\N
213	1	118	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	120	1	118	1	\N
196	1	119	1	41	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	121	1	119	1	\N
104	1	120	1	27	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	122	1	120	1	\N
44	1	121	1	70	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	123	1	121	1	\N
52	1	122	1	337	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	124	1	122	1	\N
114	1	123	1	210	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	125	1	123	1	\N
177	1	124	1	495	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	126	1	124	1	\N
148	1	125	1	144	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	127	1	125	1	\N
100	1	126	1	148	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	128	1	126	1	\N
206	1	127	1	376	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	129	1	127	1	\N
28	1	128	1	329	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	130	1	128	1	\N
173	1	129	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	131	1	129	1	\N
130	1	130	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	130	1	\N
39	1	131	1	181	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	133	1	131	1	\N
212	1	132	1	200	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	134	1	132	1	\N
116	1	133	1	159	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	135	1	133	1	\N
48	1	134	1	319	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	136	1	134	1	\N
101	1	135	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	137	1	135	1	\N
203	1	136	1	365	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	138	1	136	1	\N
50	1	137	1	342	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	139	1	137	1	\N
59	1	138	1	237	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	140	1	138	1	\N
150	1	139	1	427	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	141	1	139	1	\N
180	1	140	1	315	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	142	1	140	1	\N
142	1	141	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	143	1	141	1	\N
23	1	142	1	378	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	144	1	142	1	\N
122	1	143	1	420	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	145	1	143	1	\N
115	1	144	1	411	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	146	1	144	1	\N
75	1	145	1	172	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	147	1	145	1	\N
7	1	146	1	0	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	113	1	146	1	\N
77	1	147	1	309	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	148	1	147	1	\N
152	1	148	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	149	1	148	1	\N
120	1	149	1	154	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	150	1	149	1	\N
118	1	150	1	153	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	151	1	150	1	\N
37	1	151	1	47	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	152	1	151	1	\N
168	1	152	1	87	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	153	1	152	1	\N
149	1	153	1	398	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	154	1	153	1	\N
29	1	154	1	452	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	155	1	154	1	\N
8	1	155	1	283	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	156	1	155	1	\N
88	1	156	1	291	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	157	1	156	1	\N
233	1	157	1	367	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	158	1	157	1	\N
83	1	158	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	159	1	158	1	\N
154	1	159	1	311	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	160	1	159	1	\N
175	1	160	1	258	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	161	1	160	1	\N
69	1	161	1	323	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	162	1	161	1	\N
63	1	162	1	405	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	163	1	162	1	\N
189	1	163	1	32	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	164	1	163	1	\N
92	1	164	1	130	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	165	1	164	1	\N
140	1	165	1	234	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	166	1	165	1	\N
17	1	166	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	167	1	166	1	\N
87	1	167	1	481	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	167	1	\N
183	1	168	1	240	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	169	1	168	1	\N
2	1	169	1	65500000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	36	1	169	1	\N
129	1	170	1	314	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	171	1	170	1	\N
193	1	171	1	183	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	172	1	171	1	\N
174	1	172	1	486	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	173	1	172	1	\N
57	1	173	1	178	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	174	1	173	1	\N
224	1	174	1	65	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	175	1	174	1	\N
232	1	175	1	277	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	176	1	175	1	\N
119	1	176	1	433	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	177	1	176	1	\N
55	1	177	1	100	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	178	1	177	1	\N
169	1	178	1	272	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	179	1	178	1	\N
125	1	179	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	180	1	179	1	\N
45	1	180	1	212	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	181	1	180	1	\N
60	1	181	1	151	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	182	1	181	1	\N
99	1	182	1	387	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	183	1	182	1	\N
179	1	183	1	158	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	184	1	183	1	\N
49	1	184	1	440	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	185	1	184	1	\N
230	1	185	1	438	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	186	1	185	1	\N
131	1	186	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	187	1	186	1	\N
0	1	187	1	1000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	1	1	187	1	\N
186	1	188	1	290	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	188	1	188	1	\N
198	1	189	1	417	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	189	1	189	1	\N
202	1	190	1	375	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	190	1	190	1	\N
22	1	191	1	178	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	191	1	191	1	\N
102	1	192	1	59	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	192	1	192	1	\N
124	1	193	1	95	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	193	1	193	1	\N
200	1	194	1	394	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	194	1	194	1	\N
54	1	195	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	195	1	195	1	\N
225	1	196	1	256	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	196	1	196	1	\N
134	1	197	1	128	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	197	1	197	1	\N
97	1	198	1	199	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	198	1	198	1	\N
84	1	199	1	22	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	199	1	199	1	\N
161	1	200	1	276	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	200	1	200	1	\N
228	1	201	1	451	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	201	1	201	1	\N
238	1	202	1	133	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	202	1	202	1	\N
65	1	203	1	460	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	203	1	203	1	\N
219	1	204	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	204	1	204	1	\N
56	1	205	1	489	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	205	1	205	1	\N
1	1	206	1	5000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	206	1	206	1	\N
163	1	207	1	190	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	207	1	207	1	\N
192	1	208	1	221	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	208	1	208	1	\N
143	1	209	1	464	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	209	1	209	1	\N
61	1	210	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	210	1	210	1	\N
136	1	211	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	211	1	211	1	\N
71	1	212	1	353	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	212	1	212	1	\N
145	1	213	1	396	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	213	1	213	1	\N
106	1	214	1	417	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	214	1	214	1	\N
138	1	215	1	46	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	215	1	215	1	\N
158	1	216	1	305	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	216	1	216	1	\N
123	1	217	1	337	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	217	1	217	1	\N
25	1	218	1	444	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	218	1	218	1	\N
240	1	219	1	479	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	219	1	219	1	\N
211	1	220	1	344	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	220	1	220	1	\N
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
5	2	14	1	720000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	15	1	14	1	\N
5	3	14	1	1568500000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	15	1	14	1	\N
3	3	35	1	491500000000	34	2n1z5stsMDFMiUtemQU8VwEMTvULZmQbApkQyFokhadbFp3yCtKc	36	1	35	1	\N
4	3	109	1	11549880000000000	24	2n29HSpmgeg9kMT32ha89aru8EjhntSZ1DgFCmj5YxPM535VMXgS	15	1	109	1	\N
3	4	35	1	489250000000	43	2mzrXWXtsDpdkrpfMRddaUkzKbcGYj7rY85ZW7EB7VULhefU16ct	36	1	35	1	\N
4	4	109	1	11549760000000000	48	2mzzTbePrvAG6JDtHdNMfdSkApgx34jNka9XEzMgWbsNP5vAaiKf	15	1	109	1	\N
7	4	146	1	842250000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	113	1	146	1	\N
5	5	14	1	2410750000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	15	1	14	1	\N
3	5	35	1	489250000000	43	2mzrXWXtsDpdkrpfMRddaUkzKbcGYj7rY85ZW7EB7VULhefU16ct	36	1	35	1	\N
4	5	109	1	11549760000000000	48	2mzzTbePrvAG6JDtHdNMfdSkApgx34jNka9XEzMgWbsNP5vAaiKf	15	1	109	1	\N
3	6	35	1	487250000000	51	2mzuqTwLP57f3QTXNAFhUo6VrbqF4NMjMd1914efUDxyNBXb2diJ	36	1	35	1	\N
4	6	109	1	11549640000000000	72	2n1jAshxC8Ty6DhicFYuDGgrrvtcneoEDjbm8AAaVYH2Q4TvxEaw	15	1	109	1	\N
7	6	146	1	1684250000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	113	1	146	1	\N
5	7	14	1	2410750000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	15	1	14	1	\N
3	7	35	1	485000000000	60	2mzwFEa1t4BjhCuqcG8wvUsvoVscAHN1bAv4p8p6KBYTAKMqfWTA	36	1	35	1	\N
4	7	109	1	11549520000000000	96	2n2CoiarG4e2r6DT8aV4rkRAqcafTe3c2TuiLFHft6cehKgbn6or	15	1	109	1	\N
3	8	35	1	485000000000	60	2mzwFEa1t4BjhCuqcG8wvUsvoVscAHN1bAv4p8p6KBYTAKMqfWTA	36	1	35	1	\N
4	8	109	1	11549520000000000	96	2n2CoiarG4e2r6DT8aV4rkRAqcafTe3c2TuiLFHft6cehKgbn6or	15	1	109	1	\N
7	8	146	1	2526500000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	113	1	146	1	\N
5	9	14	1	3254750000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	15	1	14	1	\N
3	9	35	1	481000000000	76	2n1d95VTSqjZjPXqxXofgpPV8VCe6w91k7df4vPTmCySTyfwACFW	36	1	35	1	\N
4	9	109	1	11549400000000000	120	2n12d9hTfETMCV873pn4QwZ2whtUG7djtZbSJg3LBoxMqSTpVY8B	15	1	109	1	\N
3	10	35	1	478750000000	85	2n1UcpwWdKFBSBBC5rC4XZbaEs3KYFNBQvgzSRXwL8W3VmskQiAU	36	1	35	1	\N
4	10	109	1	11549280000000000	144	2n1gbLyeTdpnfKLW6P4f8PegMmSrmyd5b2rBHteyM7zS4qmqrZZE	15	1	109	1	\N
7	10	146	1	2526500000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	113	1	146	1	\N
5	11	14	1	4097000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	15	1	14	1	\N
3	11	35	1	478750000000	85	2n1UcpwWdKFBSBBC5rC4XZbaEs3KYFNBQvgzSRXwL8W3VmskQiAU	36	1	35	1	\N
4	11	109	1	11549280000000000	144	2n1gbLyeTdpnfKLW6P4f8PegMmSrmyd5b2rBHteyM7zS4qmqrZZE	15	1	109	1	\N
5	12	14	1	4099000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	15	1	14	1	\N
3	12	35	1	474500000000	102	2n1agLrnbWeDuf8yTZvPMWE19sVdavZoi8f95hfSFh5Jfbfm2VTa	36	1	35	1	\N
4	12	109	1	11549160000000000	168	2mzvJPF6SUbsv71GgcLJUzvwcvmngUjtAdvR4CNVnNWHMGngDgQK	15	1	109	1	\N
5	13	14	1	4941000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	15	1	14	1	\N
3	13	35	1	472500000000	110	2n1ZELGn5Gw9srQ8FN9nHgwh1uH3rPuhr6V3tjSBCqwbNWic8pm6	36	1	35	1	\N
4	13	109	1	11549040000000000	192	2mzq2XbKMFFAfXC5ubBeUDfCL6DnmELXABWJJDE71nT1risx8bmM	15	1	109	1	\N
5	14	14	1	5783250000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	15	1	14	1	\N
3	14	35	1	470250000000	119	2n1j3cn9VhZuAfEB8pRRZbEYEAwtMw8ffSmMcE8LkHJqN6nvXPWQ	36	1	35	1	\N
4	14	109	1	11548920000000000	216	2mzmvZBk6nQR7iEXdKySWH9Qa6FeaRc7XyWzkHhcpzkd8FDb3UEV	15	1	109	1	\N
3	15	35	1	468000000000	128	2n1tt9uL3gXbBXPyKzbWQ2TTnF97FvPxz4SKso2ZEpv5BrRbUQcL	36	1	35	1	\N
4	15	109	1	11548800000000000	240	2mzyTahSbrSqBFvtcjtYGtPqJpBwPhi9KidvqZLPkKcMf7BbkxHG	15	1	109	1	\N
7	15	146	1	3368710000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	113	1	146	1	\N
1	15	206	1	5040000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	206	1	206	1	\N
5	16	14	1	6625460000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	15	1	14	1	\N
3	16	35	1	468000000000	128	2n1tt9uL3gXbBXPyKzbWQ2TTnF97FvPxz4SKso2ZEpv5BrRbUQcL	36	1	35	1	\N
4	16	109	1	11548800000000000	240	2mzyTahSbrSqBFvtcjtYGtPqJpBwPhi9KidvqZLPkKcMf7BbkxHG	15	1	109	1	\N
1	16	206	1	5040000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	206	1	206	1	\N
3	18	35	1	464000000000	144	2n1kdXrncKfzRwzAGw55fNCjhVHH2sm1s8chZG719tKp5JpPHSMm	36	1	35	1	\N
4	18	109	1	11548565000000000	287	2n25TrGT8CXUBfU1uTrH4TrgGCmpStiqBQXLeGkHUFU3UgqSTBRH	15	1	109	1	\N
7	18	146	1	5047702000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	113	1	146	1	\N
1	18	206	1	5048000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	206	1	206	1	\N
3	20	35	1	461750000000	153	2mzjmshVp5yrNtJfodkwhTbce2NhrNDqeCESFBqXqZyAyELYp8mY	36	1	35	1	\N
4	20	109	1	11548480000000000	304	2n2FfroDJnD7Zc3SMCZA4FsGjgGsp4mrPM7QCoLXcsWboLQHeaCb	15	1	109	1	\N
7	20	146	1	5854948000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	113	1	146	1	\N
1	20	206	1	5052000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	206	1	206	1	\N
5	22	14	1	7439731000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	15	1	14	1	\N
3	22	35	1	452500000000	190	2mzrqP3v3uCdABkqgSCKE4nhjBDQb8JzUGg68aXfqvWvhDnGKUrh	36	1	35	1	\N
4	22	109	1	11548305000000000	339	2mzzGRHPofSNxXnQSjYa5QkvN8tyHwXSUAhuXd1nUeT59T4UGxqj	15	1	109	1	\N
1	22	206	1	5073000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	206	1	206	1	\N
5	24	14	1	8254728000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	15	1	14	1	\N
4	24	109	1	11548210000000000	358	2n1HJKt1iLjwyDQY45XUa6hAKYZzEXRRBTFwUhqWSXsQzDA9JCJx	15	1	109	1	\N
1	24	206	1	5076000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	206	1	206	1	\N
3	17	35	1	466000000000	136	2n2QZjjFuU8oYJx9wJV5rcaxuSFbt6oCqA8fnMVCtBCM2zYbPbVJ	36	1	35	1	\N
4	17	109	1	11548680000000000	264	2n1s51DuNK84KqT7sfwUxJyJs3fb3zQZeEv28St49nUL7xphaVM2	15	1	109	1	\N
7	17	146	1	4210707000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	113	1	146	1	\N
1	17	206	1	5043000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	206	1	206	1	\N
5	19	14	1	6590496000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	15	1	14	1	\N
3	19	35	1	461750000000	153	2mzjmshVp5yrNtJfodkwhTbce2NhrNDqeCESFBqXqZyAyELYp8mY	36	1	35	1	\N
4	19	109	1	11548480000000000	304	2n2FfroDJnD7Zc3SMCZA4FsGjgGsp4mrPM7QCoLXcsWboLQHeaCb	15	1	109	1	\N
1	19	206	1	5052000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	206	1	206	1	\N
4	21	109	1	11548425000000000	315	2mzaCPXTQaGKxF3kWAs3BGFE3QBEFbw4UXFtkyN9qPKnAPb3St1T	15	1	109	1	\N
7	21	146	1	5822696000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	113	1	146	1	\N
1	21	206	1	5058000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	206	1	206	1	\N
3	23	35	1	452500000000	190	2mzrqP3v3uCdABkqgSCKE4nhjBDQb8JzUGg68aXfqvWvhDnGKUrh	36	1	35	1	\N
4	23	109	1	11548305000000000	339	2mzzGRHPofSNxXnQSjYa5QkvN8tyHwXSUAhuXd1nUeT59T4UGxqj	15	1	109	1	\N
7	23	146	1	6671931000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	113	1	146	1	\N
1	23	206	1	5073000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	206	1	206	1	\N
5	25	14	1	8989723000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	15	1	14	1	\N
4	25	109	1	11548195000000000	361	2n1sCrqLnXDQm9qDzPwTBdzdp1DRVB5WzHZ36apR1uVYe2CTceUW	15	1	109	1	\N
1	25	206	1	5081000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	206	1	206	1	\N
4	26	109	1	11548185000000000	363	2n1qhETcnr9PKHmxn3XNaaGYU1dTVuwMYrT5x6xb4jTqaHg9RpfR	15	1	109	1	\N
7	26	146	1	6552692000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	113	1	146	1	\N
1	26	206	1	5085000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	206	1	206	1	\N
5	27	14	1	9719719000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	15	1	14	1	\N
4	27	109	1	11548185000000000	363	2n1qhETcnr9PKHmxn3XNaaGYU1dTVuwMYrT5x6xb4jTqaHg9RpfR	15	1	109	1	\N
1	27	206	1	5085000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	206	1	206	1	\N
5	28	14	1	9714720000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	15	1	14	1	\N
4	28	109	1	11548180000000000	364	2n2KghP5irRJuiU1LsnHNEnq3z5xZvcuW7j6qp6PyrxRNAQ15Yd6	15	1	109	1	\N
1	28	206	1	5088000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	206	1	206	1	\N
4	29	109	1	11548175000000000	365	2n2Sw6RAuKvfCY58AcYstTQ7P675sQWcaX67rMpnXuPSamyBy8rA	15	1	109	1	\N
7	29	146	1	7277689000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	113	1	146	1	\N
1	29	206	1	5091000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	206	1	206	1	\N
5	30	14	1	10439717000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	15	1	14	1	\N
4	30	109	1	11548170000000000	366	2n1P5LpYsJXQWMpcmVFZ9PGHPE6En88hw7hKwNT1fDjuDSHwJ1eu	15	1	109	1	\N
1	30	206	1	5094000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	206	1	206	1	\N
4	31	109	1	11548170000000000	366	2n1P5LpYsJXQWMpcmVFZ9PGHPE6En88hw7hKwNT1fDjuDSHwJ1eu	15	1	109	1	\N
7	31	146	1	8002686000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	113	1	146	1	\N
1	31	206	1	5094000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	206	1	206	1	\N
5	32	14	1	11174712000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	15	1	14	1	\N
4	32	109	1	11548155000000000	369	2n1x4uNDfLfRQWNjncJkfNZzR92BiEDTFJwD8CLUCQeTNUkvWtuC	15	1	109	1	\N
1	32	206	1	5099000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	206	1	206	1	\N
4	33	109	1	11548140000000000	372	2mzrSSGpP7fyc3iyWZK7qSretfNS35Uo43PNsFAfgekvkkaLBYr7	15	1	109	1	\N
7	33	146	1	8012684000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	113	1	146	1	\N
1	33	206	1	5104000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	206	1	206	1	\N
5	34	14	1	11914706000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	15	1	14	1	\N
4	34	109	1	11548120000000000	376	2mzt9vDXwNYK879ty3Rqyjch5Zi2kEfTXLvb9bCS4jeUSGp8WRop	15	1	109	1	\N
1	34	206	1	5110000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	206	1	206	1	\N
4	35	109	1	11548115000000000	377	2mzw43kFHJDbqyyGGjg1dJRwMJM9guxm2VdFEzecg8fVGzXG6yA5	15	1	109	1	\N
7	35	146	1	8737681000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	113	1	146	1	\N
1	35	206	1	5113000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	206	1	206	1	\N
5	36	14	1	12639703000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	15	1	14	1	\N
4	36	109	1	11548115000000000	377	2mzw43kFHJDbqyyGGjg1dJRwMJM9guxm2VdFEzecg8fVGzXG6yA5	15	1	109	1	\N
1	36	206	1	5113000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	206	1	206	1	\N
4	37	109	1	11548105000000000	379	2mzcS8T9W61bY8qvhWteKgeo3xL5cixeQSH6L2wHGrU5zPsR9WGg	15	1	109	1	\N
7	37	146	1	9467677000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	113	1	146	1	\N
1	37	206	1	5117000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	206	1	206	1	\N
5	38	14	1	12644702000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	15	1	14	1	\N
4	38	109	1	11548105000000000	379	2mzcS8T9W61bY8qvhWteKgeo3xL5cixeQSH6L2wHGrU5zPsR9WGg	15	1	109	1	\N
1	38	206	1	5117000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	206	1	206	1	\N
3	39	35	1	443250000000	227	2n2AZwvcGANGFz4wDWhYc6qPWKLVrWERywc5jNpfnZhHGaV2Uase	36	1	35	1	\N
4	39	109	1	11547985000000000	403	2mzbTw74M9DAoFK2YtiQCJYcQnzDZfdbDZvm65wRvmiM8TD2pPnN	15	1	109	1	\N
7	39	146	1	9586919000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	113	1	146	1	\N
1	39	206	1	5129000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	206	1	206	1	\N
5	41	14	1	14174689000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	15	1	14	1	\N
4	41	109	1	11547895000000000	421	2n21Lwd3QCoX4DdW3ouARqdbHWmb7AvGhPfgL1jAKKrEFPUU9SVr	15	1	109	1	\N
1	41	206	1	5142000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	206	1	206	1	\N
4	43	109	1	11547875000000000	425	2mzxf2AYYVKdWbKEAXGjUctw6wSUDHFME7VbHR9koSqNbhPCNMM2	15	1	109	1	\N
7	43	146	1	10326915000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	113	1	146	1	\N
1	43	206	1	5146000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	206	1	206	1	\N
4	45	109	1	11547865000000000	427	2mzy3qSVcL1GVBT7LarngBPq5De6iR1vdT4EUQfcmcLocWW4rtuF	15	1	109	1	\N
7	45	146	1	10316916000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	113	1	146	1	\N
1	45	206	1	5149000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	206	1	206	1	\N
4	47	109	1	11547830000000000	434	2mzjjqppH3fwdec3dxuGzzWpts5im7DzsBQV1WEVBEG8tPYfRfRv	15	1	109	1	\N
7	47	146	1	10321914000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	113	1	146	1	\N
1	47	206	1	5160000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	206	1	206	1	\N
5	49	14	1	17854666000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	15	1	14	1	\N
4	49	109	1	11547800000000000	440	2n1YrPLc2PuxvSs4cjoZERFEpzekwin4E1t7LuaEs8ebTQedCvcU	15	1	109	1	\N
1	49	206	1	5170000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	206	1	206	1	\N
5	51	14	1	18594660000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	15	1	14	1	\N
4	51	109	1	11547730000000000	454	2n1HoYTgRDXN2x7TcRJ45Dt6KgX4RndmGgNfqxRTjaq3mXqM1Hjs	15	1	109	1	\N
1	51	206	1	5188000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	206	1	206	1	\N
4	52	109	1	11547730000000000	454	2n1HoYTgRDXN2x7TcRJ45Dt6KgX4RndmGgNfqxRTjaq3mXqM1Hjs	15	1	109	1	\N
7	52	146	1	11831896000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	113	1	146	1	\N
1	52	206	1	5188000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	206	1	206	1	\N
5	40	14	1	13429695000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	15	1	14	1	\N
4	40	109	1	11547920000000000	416	2mzZ3Ty5ASmyY1yguZz8v961miTbPASk7LkJ3eusWBHJ5eMYSjki	15	1	109	1	\N
1	40	206	1	5136000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	206	1	206	1	\N
5	42	14	1	14914685000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	15	1	14	1	\N
4	42	109	1	11547875000000000	425	2mzxf2AYYVKdWbKEAXGjUctw6wSUDHFME7VbHR9koSqNbhPCNMM2	15	1	109	1	\N
1	42	206	1	5146000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	206	1	206	1	\N
5	44	14	1	15644682000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	15	1	14	1	\N
4	44	109	1	11547865000000000	427	2mzy3qSVcL1GVBT7LarngBPq5De6iR1vdT4EUQfcmcLocWW4rtuF	15	1	109	1	\N
1	44	206	1	5149000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	206	1	206	1	\N
5	46	14	1	16384676000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	15	1	14	1	\N
4	46	109	1	11547845000000000	431	2n1U1UDaWGFn565AZVZ5PUgQHRdGYsqzkLApShuq36LX8t1ghBLV	15	1	109	1	\N
1	46	206	1	5155000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	206	1	206	1	\N
5	48	14	1	17109673000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	15	1	14	1	\N
4	48	109	1	11547825000000000	435	2n1ivurMkWS28XszaKkDU8kPze4UNUjnkV76hpcHFf3UezH9Vnk2	15	1	109	1	\N
1	48	206	1	5163000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	206	1	206	1	\N
4	50	109	1	11547750000000000	450	2n1Ph7kefANYSLu4kbfuFbVbXDJ2uTmB6XAqmcVrZpcgSYMmCvN8	15	1	109	1	\N
7	50	146	1	11091902000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	113	1	146	1	\N
1	50	206	1	5182000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	206	1	206	1	\N
5	53	14	1	19435906000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	15	1	14	1	\N
3	53	35	1	442000000000	232	2n1TBE8MyFnLbfqtvomncoVteqBdshYW49r4NdcDmZdDqSdT1Evc	36	1	35	1	\N
4	53	109	1	11547610000000000	478	2n1yjv6ebnkPQTiqJUWgamnZCNRvdosFgqgLnHcSWjVMUgDbc3og	15	1	109	1	\N
1	53	206	1	5192000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	206	1	206	1	\N
3	54	35	1	442000000000	232	2n1TBE8MyFnLbfqtvomncoVteqBdshYW49r4NdcDmZdDqSdT1Evc	36	1	35	1	\N
4	54	109	1	11547610000000000	478	2n1yjv6ebnkPQTiqJUWgamnZCNRvdosFgqgLnHcSWjVMUgDbc3og	15	1	109	1	\N
7	54	146	1	11933148000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	113	1	146	1	\N
1	54	206	1	5192000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	206	1	206	1	\N
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
5	3NLVE3hVSnZzQSqx7nbdZUMH5uF4DpNLVFLWLuxAoVMX9LNXkbfS	3	3NKmdmAN1LRtn4PU5zD3P56GoPCBZGQ18UScUWp6RrHqs8DnNA8n	15	110	hC3eCubeXT10sZnIN9cQfFkQMzpc967TzjlewqZLVgc=	1	1	6	77	{2,2,7,7,7,7,7,7,7,7,7}	23166005000061388	jxsxKP2EibhvtKw1ZZfbW8fppYZELxETA7cAnp1CDUuHfhD8kcz	4	9	9	1	\N	1711534575000	orphaned
20	3NLuYEMnqf5zN4QX1U4fbpKUdKSZFPK5kPDvw6kh5xPVF2wyGAJZ	18	3NKc3vVKsd32mRYY6rUwhwWcLwNvdZhTB77G4WApRGRMLz5U6R6j	113	112	bv6m8z-qHuzcHPyhzNHUKNcx3m8WzNQQsC92FZWCsg4=	1	1	21	77	{2,5,6,2,7,7,7,7,7,7,7}	23166005000061388	jxufD2ryaE8w4SBtm7KRjJ2VSuYBWoZU9g4n4E6Rph9snaLNaQp	15	22	22	1	\N	1711536915000	orphaned
23	3NLMhxuc2XSxPwttViVCxEbnnUDd5BjiW3PYNUN5o72mjCWY2iyD	21	3NL7HLRrPzSKM6BHz9txYrBP5yXsixsCtn4hV43d1DCnM27Y7pQV	113	112	67_IsgKUwdSDPu0qa0qxZnvFX0EJsFTvG_9ewGVYQAE=	1	1	24	77	{2,5,6,3,1,7,7,7,7,7,7}	23166005000061388	jxsN9Jf4NrPhWeEcPqqsWLbSP1BP35MSfd8J7j7wMtG8UEtzWcn	17	28	28	1	\N	1711537995000	orphaned
49	3NKVq8vTqzsXJ3x2EuC8DEuipPkbG68BNEbAMLARi6pswkjktsMk	48	3NL1N7BWom4A3ELvTKFKi2GD8zArsg6nZtBmwRBHf7P4ErhztjUt	15	110	US9R0sL7vmSMR0SitF0ReM2Dbk7u3G7DCN4uBycJpg0=	1	1	50	77	{2,5,6,3,7,5,5,4,7,7,7}	23166005000061388	jwR14CzUpKmkXMmpVLVornH6xturZ1rHdBPPReiQute6n51DERV	37	54	54	1	\N	1711542675000	canonical
53	3NKiP1JD8ViAiAjtfxA7waDrtt9ioVpdgzw7FcsSEEJxUqqavqJN	51	3NKTs8YsCz4fALC2hErYzv5tUCwgAQ6bF4nNhsDSST97EPWN15WA	15	110	tUCIm12LBDrfsXtQrKQOw0BkHL1bJzL9gI5RLH6kzg4=	1	1	54	77	{2,5,6,3,7,5,5,4,3,7,7}	23166005000061388	jxYNJWktfoz7hpVzHhviAzZxVobYa7aB9TGy3UcwfRfuuPfExTn	40	60	60	1	\N	1711543755000	orphaned
52	3NKRgSfvaTnfLgaLNPgNqtfNV7aB7FDgBMwJsSo8hP39jHxt7rV5	50	3NLQMa6zbyBryUEJ1sfgydCLn9obo8NGQQdjpbWbmGPHxyKbanM3	113	112	crek0F0BHr3B9FqWCNFtZtQbikC8EVmTR2LftwYQRgA=	1	1	53	77	{2,5,6,3,7,5,5,4,2,7,7}	23166005000061388	jwn47rv3HyGZ8cY4d7KE6TogDeqemcNtg5EgXkWNm3JpPxDsrVp	39	59	59	1	\N	1711543575000	orphaned
17	3NKuMG7Yrwp4Qs1RTaPD5tsd392chm3mKneuzSB1eDdQ7t8EVfdM	15	3NLAjCR9vhNEB6dTYuqtZVtsiYYvvBbYuLQXtsbBRaex2GHroXCd	113	112	h6Jja-rrKEQE5dVFtVlMiBxgLOTYGIhwTA_PVboR6gU=	1	1	18	77	{2,5,6,7,7,7,7,7,7,7,7}	23166005000061388	jwWpmbdaahT3BuBcyUJnyF8uRU3utiZFiQpzYvdUQwkc5xVvY4N	13	20	20	1	\N	1711536555000	canonical
31	3NKcy5tiseckwaJJkFNXb24gTgje3S5ihQMVmbueNC6yrbKS6NoX	29	3NLXRtHiYQVKULckBi1jB7QLnt2N1FYyK31jyzRMHcD7nQTb2hEe	113	112	4W56AnLEQ3J1kYSEnObMz55muQpe0O3bCxmj2AJn7QQ=	1	1	32	77	{2,5,6,3,7,7,7,7,7,7,7}	23166005000061388	jxPdT5Krf1vwyPrcM29bmGyAfvVazcsGKdaQ2w9n5jE6bHVognW	23	34	34	1	\N	1711539075000	orphaned
27	3NLvDYTUoKHqZY895kWadKUCQEiJGA7fnXy5GUTqHLEDjsQ7iuEg	25	3NLt1CDP3tmiKbiFiJR7vwQd6ikfmrx11SBdw91UEwthbbGKYSg4	15	110	sX3YFlerfnqgKQgaQtDzeSQaWYCVuY51iwVfXo748gg=	1	1	28	77	{2,5,6,3,4,7,7,7,7,7,7}	23166005000061388	jwGeRr737P3gPDNh35G2MXkcS9D437t1aADnyP8sYb7nEqyVSuh	20	31	31	1	\N	1711538535000	orphaned
13	3NK3zThH4kzZsq2mqLpshGV6YCr7rfL3KpvdxwSJNoJafqtxZXxQ	12	3NLs57Bs3BPJ9F9qaLdq2oL3YMdWSJ3oFsRmm1Evdj56Vh9sdx9A	15	110	p-m63yGt5Q6l__XOIju9SpQSwN9p8us4ji4quWLt2Ao=	1	1	14	77	{2,5,3,7,7,7,7,7,7,7,7}	23166005000061388	jxfTx6HDwtAJfx97VNAz46A4h38wsx4HNdu4B1Jh1GyX76SuJoP	10	17	17	1	\N	1711536015000	canonical
8	3NLjQUpfvWrdoMZTqvZvUZk7YnpQYRfqQNeAcYJ7bfDAj8j86AZE	6	3NLUBt5PHX2jpL52iWXfvYsjfN5dCNwVp4khWzuzoe4VV7THqq5b	113	112	uoz2noigyn0ya2I61Kd48zmDCsEVm6acFxrFNY3YrA8=	1	1	9	77	{2,4,7,7,7,7,7,7,7,7,7}	23166005000061388	jxmGhPvoMDmXUPvsDjs68JKK4MxS1WXQM1MWyTWannJyzCxKgUd	6	11	11	1	\N	1711534935000	orphaned
11	3NLdER697sJn9ECaBZdJc6uvPwfHkZ1dCNobT8kp5Y8m5TgEQA6k	9	3NL4npdHK9EBwQ969kwHGoQCfd28m6XgxiMRipjvxuKxtc3eV1vo	15	110	82-0VKexyGMn-nXOkDgv0A4H7yLp8nDtBlgL8SMv3Ac=	1	1	12	77	{2,5,1,7,7,7,7,7,7,7,7}	23166005000061388	jwBM7q1KXYCvo2j61uE3aSRAoNGFXnYdHs59BzTneU9u55zGCzs	8	14	14	1	\N	1711535475000	orphaned
16	3NLYJkkWFEaCjgYQH5efDbDkouQ55DpjaGJSHUcGqxLgAgCoeiqG	14	3NLDtntHPCiageEmrD2C6Sp2H9ZgF6GdVtGEKpeyTYovkxwGViv4	15	110	7xmbeqnvx_3013l2PvhKIyzDFxisbinL3Bm6BtU2LgI=	1	1	17	77	{2,5,5,7,7,7,7,7,7,7,7}	23166005000061388	jwaJm2wvz3zvf3F92WM4VH76if4k5cFJ8wV6EhaFbLVvnK6tB9s	12	19	19	1	\N	1711536375000	orphaned
36	3NLcLoBEC7zz7wZkK8rSxH7tLJ56LdjCtAusZvUnb9WT2rpwDKFd	34	3NKf18ZsF3eGYTCoGMcG6vH9oEaD7iD3VKmWb82w6XzAmaEh7PA7	15	110	SJhEFTH_tAv2sTk0rNz5PTbObJImB7aymoVuc9f6Igo=	1	1	37	77	{2,5,6,3,7,4,7,7,7,7,7}	23166005000061388	jxC3bfZZaj6B8h6ASSTFpM9EAexcwgUdYNRFYwwf6QPQ6knqYWN	27	39	39	1	\N	1711539975000	orphaned
54	3NLSgfHnrKDjk2KFA4wddpA7pf1EP5Nuh6TKGxd2Fo81daewURUs	51	3NKTs8YsCz4fALC2hErYzv5tUCwgAQ6bF4nNhsDSST97EPWN15WA	113	112	3CtXyA1a3q3SbgqATRDrP1qbFKvpglEJzITCA3Uh3QI=	1	1	55	77	{2,5,6,3,7,5,5,4,3,7,7}	23166005000061388	jxg8qVhUxpFkaYN9fVuMkz2dtnKQg9NnMupc1Vt5GpGWoviLDqu	40	60	60	1	\N	1711543755000	canonical
50	3NLQMa6zbyBryUEJ1sfgydCLn9obo8NGQQdjpbWbmGPHxyKbanM3	49	3NKVq8vTqzsXJ3x2EuC8DEuipPkbG68BNEbAMLARi6pswkjktsMk	113	112	3TJcLrJA31OglxnkPWx5OtpsakHW0L5r7d-O6-f_fgQ=	1	1	51	77	{2,5,6,3,7,5,5,4,1,7,7}	23166005000061388	jwwiwhAS4dvEQWRk5fxohELRBYJc9VZ7rkaARbHxJ4HH3QvXqAc	38	57	57	1	\N	1711543215000	canonical
40	3NKFpDeoLLKAQai1rvKfiDz5b5zVEvgjws2oFCHEhuBeNh9vfZuY	39	3NLtwaemze8vowHaZYTLSTxiYXtLPCb5kapbC9LTWb2dPAhVCQ5s	15	110	qZPn2-pL2ui_OeDfJ6GTJnR2y2s4FOnESPqSV8nZUQE=	1	1	41	77	{2,5,6,3,7,5,2,7,7,7,7}	23166005000061388	jwazm3Ucnxu3SS46QBvSDWFF7bLK4tdHirCeHueByNbiuV3ttKV	30	45	45	1	\N	1711541055000	canonical
14	3NLDtntHPCiageEmrD2C6Sp2H9ZgF6GdVtGEKpeyTYovkxwGViv4	13	3NK3zThH4kzZsq2mqLpshGV6YCr7rfL3KpvdxwSJNoJafqtxZXxQ	15	110	QkMuV0TPx--3qPBgcLIsv_k6B4DZWEAnSwZ6eu-ufAk=	1	1	15	77	{2,5,4,7,7,7,7,7,7,7,7}	23166005000061388	jxYqFuLZ6AaNQAsHYHaAEfcRu4ghvbMQTAfuJXR981GY7z78RT1	11	18	18	1	\N	1711536195000	canonical
12	3NLs57Bs3BPJ9F9qaLdq2oL3YMdWSJ3oFsRmm1Evdj56Vh9sdx9A	10	3NK9SePsfC7rzGojWJzfwmq4Ci9LmHtaeKuiE1odBXmLYrgVvUyg	15	110	hk_ZCRXtHpu5zYh_Cnmgei13t1vkFy2Yl0OlH4kv_gI=	1	1	13	77	{2,5,2,7,7,7,7,7,7,7,7}	23166005000061388	jxXByRdvXBtrMuCnWbCKJJBWeY7aGLJEUWBWZYWDQ1jSCHemmwB	9	16	16	1	\N	1711535835000	canonical
37	3NK3MvLuZ8HhobbtFSMSuj9wfQeaqojHhZ6ubmk6pZu3ErFd8rDm	35	3NKNFST7eVsc4JvbPMzRe8vW9e4PDwgCyiU8qZu1mup5PsQASvPN	113	112	PL3yTM5PtIDq1-amhR36u4RjLuFEwgOib9_4RRx90w0=	1	1	38	77	{2,5,6,3,7,5,7,7,7,7,7}	23166005000061388	jwDc65iiMA9EALm1aKq8GnacuTVBraQkRMZeW67rxvN4E1xeppq	28	40	40	1	\N	1711540155000	orphaned
43	3NLw4MQF3zjx94P5TE2hR64cRzfJUX8j4Ff7TaQV6mU4KXhwX7kZ	41	3NKWRGzEYr8EAzYreRQHqTGijmtcTDZUZoJ7LfEnixYoZStEEZLp	113	112	u41pmYA8fuUDreN_ctU6y6ereOzTzYdzVKHgPQ1jXQA=	1	1	44	77	{2,5,6,3,7,5,4,7,7,7,7}	23166005000061388	jwyP5pjzRbkvn8X7gzwCscXrpVhnfdhyXCKMsScHyJe7oUBNzgg	32	47	47	1	\N	1711541415000	orphaned
45	3NK6RnVkGsx4c2aq2gtoyvEJCVV7UBiswtshwiT7DeZRjrFp95Ey	42	3NKSQPMp6jN8RbteazTCYVZQDBi36G2geKwoNdeQoYfhaMzb2ttE	113	112	JF6Pc14xCTy8bISdcecCDQ_vJl9e30afgRof7dSW0wk=	1	1	46	77	{2,5,6,3,7,5,5,7,7,7,7}	23166005000061388	jy1Jg2nFAmpbKRJAY3Kjk26A5w7K5wYJTyrRKEms45MrfT1AmQ3	33	48	48	1	\N	1711541595000	orphaned
51	3NKTs8YsCz4fALC2hErYzv5tUCwgAQ6bF4nNhsDSST97EPWN15WA	50	3NLQMa6zbyBryUEJ1sfgydCLn9obo8NGQQdjpbWbmGPHxyKbanM3	15	110	4XE_Qvp7-DBU8VGbDSqgPAizfQYdVeyEbCasIhcTpgQ=	1	1	52	77	{2,5,6,3,7,5,5,4,2,7,7}	23166005000061388	jwbuqN6qggxjQCCPkzAiukkF7EVnJgf4xpRaoLS2joQSucTqGvE	39	59	59	1	\N	1711543575000	orphaned
32	3NKuRjdJfFERadvsnhfVDahovSWgutoXpQhkrx5UMiePn85jkw2y	30	3NKhvALP75aWx4J5Ng61APjRwVTz3jAt4Q9BtvTi6XBRcGnFnUxk	15	110	y2L8Kxph4_89jYemoEA0agJHwvGQ-YUWJCr74UfQNAg=	1	1	33	77	{2,5,6,3,7,1,7,7,7,7,7}	23166005000061388	jww9FmrPdJbZL6zHaswdfBVHwWcaXRbtcCxMn5eqyx6zTvnChza	24	35	35	1	\N	1711539255000	canonical
15	3NLAjCR9vhNEB6dTYuqtZVtsiYYvvBbYuLQXtsbBRaex2GHroXCd	14	3NLDtntHPCiageEmrD2C6Sp2H9ZgF6GdVtGEKpeyTYovkxwGViv4	113	112	xf0VXWM79ZVOapcCiszkg8FPoKZBZK24HQCy6eVHEwo=	1	1	16	77	{2,5,5,7,7,7,7,7,7,7,7}	23166005000061388	jxkrbc9TjY22gXM4QGMJeJSwY2Uh44zfRpc2P5HmbT938uiVp9Z	12	19	19	1	\N	1711536375000	canonical
10	3NK9SePsfC7rzGojWJzfwmq4Ci9LmHtaeKuiE1odBXmLYrgVvUyg	9	3NL4npdHK9EBwQ969kwHGoQCfd28m6XgxiMRipjvxuKxtc3eV1vo	113	112	on7A6mv19JsFwf5JQXJIwZqpVXfoL075TPb2sYARzwo=	1	1	11	77	{2,5,1,7,7,7,7,7,7,7,7}	23166005000061388	jwJ9k7xxKB4XTFGP4Pwb846qKhFbAK3kxHoad2U8mSyKRsLXpTY	8	14	14	1	\N	1711535475000	canonical
9	3NL4npdHK9EBwQ969kwHGoQCfd28m6XgxiMRipjvxuKxtc3eV1vo	7	3NKP3kQ4pnEQVB4KyKbtWFiFTcCiDcQMcZJN5FfaCZDw1MHHrDBM	15	110	Uevr_z8zH91XZs4egxlXCteXA-VVVzyInCRGGVXCiwU=	1	1	10	77	{2,5,7,7,7,7,7,7,7,7,7}	23166005000061388	jxUy3kXGzpg4tgdv53NJLZAJEn9EZtTzsCzu5wttLHzARa5Tg28	7	13	13	1	\N	1711535295000	canonical
7	3NKP3kQ4pnEQVB4KyKbtWFiFTcCiDcQMcZJN5FfaCZDw1MHHrDBM	6	3NLUBt5PHX2jpL52iWXfvYsjfN5dCNwVp4khWzuzoe4VV7THqq5b	15	110	A7XETQQLRfvPWjJT_UWVSBnPzVal5vqIO-ib0fJ2two=	1	1	8	77	{2,4,7,7,7,7,7,7,7,7,7}	23166005000061388	jwUxvvr4CirbL2C574bmJyD2JVHXKCfVDUi1Qc1siBmJjBZXwB4	6	11	11	1	\N	1711534935000	canonical
6	3NLUBt5PHX2jpL52iWXfvYsjfN5dCNwVp4khWzuzoe4VV7THqq5b	4	3NLSvRBYAq2FBTTduWZ6fQEkGRJEA8v9rKH4bissemXjtbWnimc8	113	112	jlFriKUWOBrmQT3OcaHe2VK-5ZgIlMPdl7gPgL7uGAQ=	1	1	7	77	{2,3,7,7,7,7,7,7,7,7,7}	23166005000061388	jxF6BNkeESkfjhq13CPwnTAc2o7SvKKDD2DpedmuBHahL8LsYHt	5	10	10	1	\N	1711534755000	canonical
4	3NLSvRBYAq2FBTTduWZ6fQEkGRJEA8v9rKH4bissemXjtbWnimc8	3	3NKmdmAN1LRtn4PU5zD3P56GoPCBZGQ18UScUWp6RrHqs8DnNA8n	113	112	ALhPHafW7JNl6f7r92fNsVHaaJJxvcQwFvf1UMD94wQ=	1	1	5	77	{2,2,7,7,7,7,7,7,7,7,7}	23166005000061388	jwyA8Ku3QX5Ue5oB72wbgqop39xqxXHNX77LgACizQs1TzaRkNt	4	9	9	1	\N	1711534575000	canonical
3	3NKmdmAN1LRtn4PU5zD3P56GoPCBZGQ18UScUWp6RrHqs8DnNA8n	2	3NKwwK3tjP8HcHTgFhZEywnnLa358kj3g57UM8pXdJSnc5JaZhkz	15	110	s_dBeb627SU4rPEXPFxGzHVgcqO4YIMN4fw5BZyPxQo=	1	1	4	77	{2,1,7,7,7,7,7,7,7,7,7}	23166005000061388	jxEaYc4Uhd7a8k2W7KjhYFL4gy8m3ArU7kmvJNu8Jt8uq6fdwfV	3	8	8	1	\N	1711534395000	canonical
2	3NKwwK3tjP8HcHTgFhZEywnnLa358kj3g57UM8pXdJSnc5JaZhkz	1	3NLsxSxxCrohG8UatbXz4wPpEgG5a7GmQ1H9j77qxM8VZYwJZaLM	15	110	mRgmy8SwXBZMqgtl9mwHszSthdZcZ7C7bG0ePmsQngE=	1	1	3	77	{2,7,7,7,7,7,7,7,7,7,7}	23166005000061388	jxUnPdjjsx34Agp4sorcW3mzAgYKG3c2X1YaTGDQPkhyKhDStBN	2	5	5	1	\N	1711533855000	canonical
1	3NLsxSxxCrohG8UatbXz4wPpEgG5a7GmQ1H9j77qxM8VZYwJZaLM	\N	3NKYHXDsp1zorCnjjp6LD4SnN9TATbqyVwZXandyPKmn7ez62QdV	1	1	39cyg4ZmMtnb_aFUIerNAoAJV8qtkfOpq0zFzPspjgM=	1	1	2	77	{1,7,7,7,7,7,7,7,7,7,7}	23166005000061388	jwovXkYDcnbjEh8einaQhw2ZXkpv8fEKJDkHfVtNBRWACbNyBMa	1	0	0	1	\N	1711532955000	canonical
47	3NKxCKgA2gEn4GLng53bFr1JKssVrkJoA9rfQ7BgUAYTeD9n2pKv	46	3NKd9qshsE5inNPLa3Etibo28UFv7bHbnA11M3UZZGereoeocdyj	113	112	tNkz31uA-7JFIulh7TlnT8XtjScorRGxrsAVAzGYsAo=	1	1	48	77	{2,5,6,3,7,5,5,2,7,7,7}	23166005000061388	jwthHmmZFGAe5mLekQJQgT8iYQxWA2dmfBQzQ7DjRyaGpg81WFt	35	51	51	1	\N	1711542135000	canonical
46	3NKd9qshsE5inNPLa3Etibo28UFv7bHbnA11M3UZZGereoeocdyj	44	3NLt8U8TUExPFkHFTh47Zcq53eagFZA9enJhp6htkfTKnjMgNXEL	15	110	-PQaXjCdw1S9haWj9-oQIvT46ZIAlbjKbeHR56fkHQw=	1	1	47	77	{2,5,6,3,7,5,5,1,7,7,7}	23166005000061388	jx3FNS4qfEhefmD2Vj3SYTRVTuxmweM8D5oKFUGQa4nUbW8oKKN	34	50	50	1	\N	1711541955000	canonical
44	3NLt8U8TUExPFkHFTh47Zcq53eagFZA9enJhp6htkfTKnjMgNXEL	42	3NKSQPMp6jN8RbteazTCYVZQDBi36G2geKwoNdeQoYfhaMzb2ttE	15	110	2xaUZsHBunhlVECK1SCvMe3prHIt-kQsB5j2FmK9uQY=	1	1	45	77	{2,5,6,3,7,5,5,7,7,7,7}	23166005000061388	jwCxR4u1f297BPa6WesZZStp7uMX1sg1FXiTpiAL5guVd3WAD6i	33	48	48	1	\N	1711541595000	canonical
42	3NKSQPMp6jN8RbteazTCYVZQDBi36G2geKwoNdeQoYfhaMzb2ttE	41	3NKWRGzEYr8EAzYreRQHqTGijmtcTDZUZoJ7LfEnixYoZStEEZLp	15	110	XNI0o_r8hw0aArajeA8L8fx0zwLxjadhvUBb53W0-ww=	1	1	43	77	{2,5,6,3,7,5,4,7,7,7,7}	23166005000061388	jwbvbaBqFoEJJsjYvJRzvJajaEvsJNyfN6TRWU7i6xRbVAMpgok	32	47	47	1	\N	1711541415000	canonical
41	3NKWRGzEYr8EAzYreRQHqTGijmtcTDZUZoJ7LfEnixYoZStEEZLp	40	3NKFpDeoLLKAQai1rvKfiDz5b5zVEvgjws2oFCHEhuBeNh9vfZuY	15	110	h-S3RGvODVwx0ng3l8kvqTcJWcySVaMKCXs2fnDCSQE=	1	1	42	77	{2,5,6,3,7,5,3,7,7,7,7}	23166005000061388	jwLTCab3tGumL7j4kRQeMmcMraucvXYnetPXMwypLNB8H4d5qv7	31	46	46	1	\N	1711541235000	canonical
39	3NLtwaemze8vowHaZYTLSTxiYXtLPCb5kapbC9LTWb2dPAhVCQ5s	38	3NLKaDkjuJTr8yLcjMiRaDANKuUL2sbisgXYjzwCP29a5G8CNcFd	113	112	DVrFnjWuHFAf6Cjb0QiRn3dX_ch-lxDMOGlZyHjc4gI=	1	1	40	77	{2,5,6,3,7,5,1,7,7,7,7}	23166005000061388	jxV4Dg4u5oLmRq51u7YfLXFbsM8wARVtFx7syRdqAPjxhC6tvtF	29	43	43	1	\N	1711540695000	canonical
38	3NLKaDkjuJTr8yLcjMiRaDANKuUL2sbisgXYjzwCP29a5G8CNcFd	35	3NKNFST7eVsc4JvbPMzRe8vW9e4PDwgCyiU8qZu1mup5PsQASvPN	15	110	yYYStWIpJngt2lpYl8m3NGWpr-oqSMSdzJSZnUZE2wM=	1	1	39	77	{2,5,6,3,7,5,7,7,7,7,7}	23166005000061388	jwkHFBNuvAtLV2vW3a1ArLRdUGGftMhbHmHHEksoLW757FXZghk	28	40	40	1	\N	1711540155000	canonical
35	3NKNFST7eVsc4JvbPMzRe8vW9e4PDwgCyiU8qZu1mup5PsQASvPN	34	3NKf18ZsF3eGYTCoGMcG6vH9oEaD7iD3VKmWb82w6XzAmaEh7PA7	113	112	xPyCwqprwl_9HYuPs17_ykePw9ulFs_7q7k4oroozww=	1	1	36	77	{2,5,6,3,7,4,7,7,7,7,7}	23166005000061388	jxX2UjsWvKsqKur5RCVLyWHwMS1n9hiZBFCzBQAxT82bxNhErCq	27	39	39	1	\N	1711539975000	canonical
33	3NKrv1oxG7VpGEqyBk6jUnXedRN9owfQXndxxhQmwTTrz1HQmPDh	32	3NKuRjdJfFERadvsnhfVDahovSWgutoXpQhkrx5UMiePn85jkw2y	113	112	axMLc0wBR5DKWQN1LpnooNxBvWMS6_cLgCWX2B5nIwY=	1	1	34	77	{2,5,6,3,7,2,7,7,7,7,7}	23166005000061388	jwRr7NCqr6uPxDyDMvpn2oiA8vmSdGxS66sos4LKJ1ErYu96wHF	25	36	36	1	\N	1711539435000	canonical
30	3NKhvALP75aWx4J5Ng61APjRwVTz3jAt4Q9BtvTi6XBRcGnFnUxk	29	3NLXRtHiYQVKULckBi1jB7QLnt2N1FYyK31jyzRMHcD7nQTb2hEe	15	110	h384hJcSd-uSxKTwq0-_sR-ELYeyF-GY3MILLyK00AU=	1	1	31	77	{2,5,6,3,7,7,7,7,7,7,7}	23166005000061388	jxhpELAG4i1gfQLWp4SJGQdskQe81U12vHCjyEKxxS1tq46dPc5	23	34	34	1	\N	1711539075000	canonical
29	3NLXRtHiYQVKULckBi1jB7QLnt2N1FYyK31jyzRMHcD7nQTb2hEe	28	3NKtRpWbZWgnRLMR6PgRQpfwaJPK8ry233fUYosEuXUPsufakWm6	113	112	IGM8NIbqXHCfWU3OxYqm0TuaU2HWqw0LPruF7e4DPAQ=	1	1	30	77	{2,5,6,3,6,7,7,7,7,7,7}	23166005000061388	jwCa1sZJNzt6nxcGsuRTTS9hGW9GSgZxobSjgrmekuD2tgjvJbX	22	33	33	1	\N	1711538895000	canonical
28	3NKtRpWbZWgnRLMR6PgRQpfwaJPK8ry233fUYosEuXUPsufakWm6	26	3NKNHXP8SFnuPdV1gkpznzhs9W7d4xDD8nN1Th81aNzmxzcXeXbW	15	110	CsbUwHIkluf-iUAk07NQMyxfwFgB7lAoj1jUSEQdGgo=	1	1	29	77	{2,5,6,3,5,7,7,7,7,7,7}	23166005000061388	jxBDVUyq6DqizBVUgUeX5tpaA4MN37LxVrkDcTgkcDsfgkrTuYV	21	32	32	1	\N	1711538715000	canonical
26	3NKNHXP8SFnuPdV1gkpznzhs9W7d4xDD8nN1Th81aNzmxzcXeXbW	25	3NLt1CDP3tmiKbiFiJR7vwQd6ikfmrx11SBdw91UEwthbbGKYSg4	113	112	f_ZAZuM3ZEvT2o3T0H2qW2ErRrgPW5SkzIUVAqm2cgE=	1	1	27	77	{2,5,6,3,4,7,7,7,7,7,7}	23166005000061388	jwFdRZCr6rTpB41oz1ZtZfHa6FY8Pd88RpGhF1NjiPvg1gFNLpM	20	31	31	1	\N	1711538535000	canonical
24	3NLcFWjMHCjM6gtkcpGYd8VGdDChDJJbBZQnRnSNSDq8z3qCTXvZ	22	3NKMUTkTfXeTcLxBcxXDBTZya7y2z5Ka8iUN3mZdmzy8nMbuTQAG	15	110	rwBolC5fcvRLFeKh9a1MH8GCSqZJl_MNGbmMi3rm6Ao=	1	1	25	77	{2,5,6,3,2,7,7,7,7,7,7}	23166005000061388	jwMWGKRPwe2RDBVCbrGG9UVfqMK1qjVts194MjmQiX2gY7ucofU	18	29	29	1	\N	1711538175000	canonical
22	3NKMUTkTfXeTcLxBcxXDBTZya7y2z5Ka8iUN3mZdmzy8nMbuTQAG	21	3NL7HLRrPzSKM6BHz9txYrBP5yXsixsCtn4hV43d1DCnM27Y7pQV	15	110	rvJzkEiRybEtCSiu7PBcf_v_zy260K5k5KZxQeJJdgI=	1	1	23	77	{2,5,6,3,1,7,7,7,7,7,7}	23166005000061388	jw9qaJ9HN6rGjSF7Gn8qzHWzTdN7zDpoLkFuZeJDUthVYBU2QJ5	17	28	28	1	\N	1711537995000	canonical
18	3NKc3vVKsd32mRYY6rUwhwWcLwNvdZhTB77G4WApRGRMLz5U6R6j	17	3NKuMG7Yrwp4Qs1RTaPD5tsd392chm3mKneuzSB1eDdQ7t8EVfdM	113	112	sO7GvMIzofLtw6VkdAkaoUMmSecUlnTi1DY6164WPAE=	1	1	19	77	{2,5,6,1,7,7,7,7,7,7,7}	23166005000061388	jxujgigXNUxwSK3XSjNTHtZwHHMLMJmLGFCyrwpckUNEYnHox6s	14	21	21	1	\N	1711536735000	canonical
48	3NL1N7BWom4A3ELvTKFKi2GD8zArsg6nZtBmwRBHf7P4ErhztjUt	47	3NKxCKgA2gEn4GLng53bFr1JKssVrkJoA9rfQ7BgUAYTeD9n2pKv	15	110	-lWx95DVUpAcueNxEeKtuvZwc-C1fThHw7rN1-CbLwg=	1	1	49	77	{2,5,6,3,7,5,5,3,7,7,7}	23166005000061388	jxgvXRTCdAqGtxfms5uLNUQdmTJsD72zWm5Zx218NRySdSUENmZ	36	52	52	1	\N	1711542315000	canonical
34	3NKf18ZsF3eGYTCoGMcG6vH9oEaD7iD3VKmWb82w6XzAmaEh7PA7	33	3NKrv1oxG7VpGEqyBk6jUnXedRN9owfQXndxxhQmwTTrz1HQmPDh	15	110	d_SbEhqSiZdwCPd6TZu7ZbWCteugNVfoBDwNPwQM7QQ=	1	1	35	77	{2,5,6,3,7,3,7,7,7,7,7}	23166005000061388	jxtBhszJzv66v4vMFoHiNwmw1eeAcGXqZRaqbZaMNKLUkMM3EQZ	26	38	38	1	\N	1711539795000	canonical
25	3NLt1CDP3tmiKbiFiJR7vwQd6ikfmrx11SBdw91UEwthbbGKYSg4	24	3NLcFWjMHCjM6gtkcpGYd8VGdDChDJJbBZQnRnSNSDq8z3qCTXvZ	15	110	rF1M-4a0zQMk18fiFia3wHqIxO3hv0KBKRcAc428XQU=	1	1	26	77	{2,5,6,3,3,7,7,7,7,7,7}	23166005000061388	jxLUuepsLmDwpnDnMgMSq2uEHkGZwLeJSrW5peUtwniy4GRmZsB	19	30	30	1	\N	1711538355000	canonical
21	3NL7HLRrPzSKM6BHz9txYrBP5yXsixsCtn4hV43d1DCnM27Y7pQV	19	3NK58Bu1kqj14gXnAEP2iK9zqdDZqLivU3isGb9tdZNd6hQMDqKc	113	112	oi3UrQpfqseucDnZJkAbwy1oa922rVEsUbLEMN379wk=	1	1	22	77	{2,5,6,3,7,7,7,7,7,7,7}	23166005000061388	jxCVeVRW6JV3cFWgJg8nAJnKV96u1Ab9vPyQA6VjVRSxAQ2npV1	16	24	24	1	\N	1711537275000	canonical
19	3NK58Bu1kqj14gXnAEP2iK9zqdDZqLivU3isGb9tdZNd6hQMDqKc	18	3NKc3vVKsd32mRYY6rUwhwWcLwNvdZhTB77G4WApRGRMLz5U6R6j	15	110	IHdagKL_loHAMaO5a5G8RXuXgh6jm41nq6Ab6FXXlQo=	1	1	20	77	{2,5,6,2,7,7,7,7,7,7,7}	23166005000061388	jxK2oLxny44HNREaNHKc9R17wxhCdkiBXsYSwGcYjMstazYNyA1	15	22	22	1	\N	1711536915000	canonical
\.


--
-- Data for Name: blocks_internal_commands; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.blocks_internal_commands (block_id, internal_command_id, sequence_no, secondary_sequence_no, status, failure_reason) FROM stdin;
2	1	0	0	applied	\N
3	1	58	0	applied	\N
3	2	59	0	applied	\N
4	3	33	0	applied	\N
4	4	34	0	applied	\N
5	1	33	0	applied	\N
5	5	34	0	applied	\N
6	6	31	0	applied	\N
6	3	33	0	applied	\N
6	7	34	0	applied	\N
7	1	33	0	applied	\N
7	5	34	0	applied	\N
8	3	33	0	applied	\N
8	4	34	0	applied	\N
9	1	40	0	applied	\N
9	8	41	0	applied	\N
10	3	33	0	applied	\N
10	4	34	0	applied	\N
11	1	33	0	applied	\N
11	5	34	0	applied	\N
12	9	12	0	applied	\N
12	1	42	0	applied	\N
12	10	43	0	applied	\N
13	1	32	0	applied	\N
13	11	33	0	applied	\N
14	1	33	0	applied	\N
14	5	34	0	applied	\N
15	12	27	0	applied	\N
15	13	34	0	applied	\N
15	14	34	0	applied	\N
15	15	35	0	applied	\N
15	16	35	1	applied	\N
16	17	27	0	applied	\N
16	13	34	0	applied	\N
16	18	34	0	applied	\N
16	19	35	0	applied	\N
16	16	35	1	applied	\N
17	13	32	0	applied	\N
17	14	32	0	applied	\N
17	20	33	0	applied	\N
17	21	33	1	applied	\N
18	13	31	0	applied	\N
18	14	31	0	applied	\N
18	22	32	0	applied	\N
18	23	32	1	applied	\N
19	13	26	0	applied	\N
19	18	26	0	applied	\N
19	24	27	0	applied	\N
19	25	27	1	applied	\N
20	13	26	0	applied	\N
20	14	26	0	applied	\N
20	26	27	0	applied	\N
20	25	27	1	applied	\N
21	13	11	0	applied	\N
21	14	11	0	applied	\N
21	27	12	0	applied	\N
21	28	12	1	applied	\N
22	29	11	0	applied	\N
22	30	11	1	applied	\N
22	13	62	0	applied	\N
22	18	62	0	applied	\N
22	31	63	0	applied	\N
22	32	63	1	applied	\N
23	33	11	0	applied	\N
23	30	11	1	applied	\N
23	13	62	0	applied	\N
23	14	62	0	applied	\N
23	34	63	0	applied	\N
23	32	63	1	applied	\N
24	13	19	0	applied	\N
24	18	19	0	applied	\N
24	35	20	0	applied	\N
24	21	20	1	applied	\N
25	13	3	0	applied	\N
25	18	3	0	applied	\N
25	36	4	0	applied	\N
25	23	4	1	applied	\N
26	13	2	0	applied	\N
26	14	2	0	applied	\N
26	37	3	0	applied	\N
26	25	3	1	applied	\N
27	13	2	0	applied	\N
27	18	2	0	applied	\N
27	38	3	0	applied	\N
27	25	3	1	applied	\N
28	13	1	0	applied	\N
28	18	1	0	applied	\N
28	39	2	0	applied	\N
28	21	2	1	applied	\N
29	13	1	0	applied	\N
29	14	1	0	applied	\N
29	40	2	0	applied	\N
29	21	2	1	applied	\N
30	13	1	0	applied	\N
30	18	1	0	applied	\N
30	39	2	0	applied	\N
30	21	2	1	applied	\N
31	13	1	0	applied	\N
31	14	1	0	applied	\N
31	40	2	0	applied	\N
31	21	2	1	applied	\N
32	13	3	0	applied	\N
32	18	3	0	applied	\N
32	36	4	0	applied	\N
32	23	4	1	applied	\N
33	13	3	0	applied	\N
33	14	3	0	applied	\N
33	41	4	0	applied	\N
33	23	4	1	applied	\N
34	13	4	0	applied	\N
34	18	4	0	applied	\N
34	42	5	0	applied	\N
34	28	5	1	applied	\N
35	13	1	0	applied	\N
35	14	1	0	applied	\N
35	40	2	0	applied	\N
35	21	2	1	applied	\N
36	13	1	0	applied	\N
36	18	1	0	applied	\N
36	39	2	0	applied	\N
36	21	2	1	applied	\N
37	13	2	0	applied	\N
37	14	2	0	applied	\N
37	37	3	0	applied	\N
37	25	3	1	applied	\N
38	13	2	0	applied	\N
38	18	2	0	applied	\N
38	38	3	0	applied	\N
38	25	3	1	applied	\N
39	43	13	0	applied	\N
39	44	13	1	applied	\N
39	13	62	0	applied	\N
39	14	62	0	applied	\N
39	45	63	0	applied	\N
40	13	13	0	applied	\N
40	18	13	0	applied	\N
40	46	14	0	applied	\N
40	30	14	1	applied	\N
41	13	5	0	applied	\N
41	18	5	0	applied	\N
41	47	6	0	applied	\N
41	28	6	1	applied	\N
42	13	4	0	applied	\N
42	18	4	0	applied	\N
42	48	5	0	applied	\N
42	25	5	1	applied	\N
43	13	4	0	applied	\N
43	14	4	0	applied	\N
43	49	5	0	applied	\N
43	25	5	1	applied	\N
44	13	2	0	applied	\N
44	18	2	0	applied	\N
44	50	3	0	applied	\N
44	21	3	1	applied	\N
45	13	2	0	applied	\N
45	14	2	0	applied	\N
45	51	3	0	applied	\N
45	21	3	1	applied	\N
47	13	3	0	applied	\N
47	14	3	0	applied	\N
47	41	4	0	applied	\N
47	23	4	1	applied	\N
46	13	4	0	applied	\N
46	18	4	0	applied	\N
46	42	5	0	applied	\N
46	28	5	1	applied	\N
48	13	1	0	applied	\N
48	18	1	0	applied	\N
48	39	2	0	applied	\N
48	21	2	1	applied	\N
49	13	5	0	applied	\N
49	18	5	0	applied	\N
49	52	6	0	applied	\N
49	30	6	1	applied	\N
50	13	10	0	applied	\N
50	14	10	0	applied	\N
50	53	11	0	applied	\N
50	44	11	1	applied	\N
51	13	4	0	applied	\N
51	18	4	0	applied	\N
51	42	5	0	applied	\N
51	28	5	1	applied	\N
52	13	4	0	applied	\N
52	14	4	0	applied	\N
52	54	5	0	applied	\N
52	28	5	1	applied	\N
53	55	6	0	applied	\N
53	23	6	1	applied	\N
53	1	30	0	applied	\N
53	56	31	0	applied	\N
54	57	6	0	applied	\N
54	23	6	1	applied	\N
54	3	30	0	applied	\N
54	58	31	0	applied	\N
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
3	22	45	applied	\N
3	23	46	applied	\N
3	24	47	applied	\N
3	25	48	applied	\N
3	26	49	applied	\N
3	27	50	applied	\N
3	28	51	applied	\N
3	29	52	applied	\N
3	30	53	applied	\N
3	31	54	applied	\N
3	32	55	applied	\N
3	33	56	applied	\N
3	34	57	applied	\N
4	35	24	applied	\N
4	36	25	applied	\N
4	37	26	applied	\N
4	38	27	applied	\N
4	39	28	applied	\N
4	40	29	applied	\N
4	41	30	applied	\N
4	42	31	applied	\N
4	43	32	applied	\N
5	35	24	applied	\N
5	36	25	applied	\N
5	37	26	applied	\N
5	38	27	applied	\N
5	39	28	applied	\N
5	40	29	applied	\N
5	41	30	applied	\N
5	42	31	applied	\N
5	43	32	applied	\N
6	44	24	applied	\N
6	45	25	applied	\N
6	46	26	applied	\N
6	47	27	applied	\N
6	48	28	applied	\N
6	49	29	applied	\N
6	50	30	applied	\N
6	51	32	applied	\N
7	52	24	applied	\N
7	53	25	applied	\N
7	54	26	applied	\N
7	55	27	applied	\N
7	56	28	applied	\N
7	57	29	applied	\N
7	58	30	applied	\N
7	59	31	applied	\N
7	60	32	applied	\N
8	52	24	applied	\N
8	53	25	applied	\N
8	54	26	applied	\N
8	55	27	applied	\N
8	56	28	applied	\N
8	57	29	applied	\N
8	58	30	applied	\N
8	59	31	applied	\N
8	60	32	applied	\N
9	61	24	applied	\N
9	62	25	applied	\N
9	63	26	applied	\N
9	64	27	applied	\N
9	65	28	applied	\N
9	66	29	applied	\N
9	67	30	applied	\N
9	68	31	applied	\N
9	69	32	applied	\N
9	70	33	applied	\N
9	71	34	applied	\N
9	72	35	applied	\N
9	73	36	applied	\N
9	74	37	applied	\N
9	75	38	applied	\N
9	76	39	applied	\N
10	77	24	applied	\N
10	78	25	applied	\N
10	79	26	applied	\N
10	80	27	applied	\N
10	81	28	applied	\N
10	82	29	applied	\N
10	83	30	applied	\N
10	84	31	applied	\N
10	85	32	applied	\N
11	77	24	applied	\N
11	78	25	applied	\N
11	79	26	applied	\N
11	80	27	applied	\N
11	81	28	applied	\N
11	82	29	applied	\N
11	83	30	applied	\N
11	84	31	applied	\N
11	85	32	applied	\N
12	86	25	applied	\N
12	87	26	applied	\N
12	88	27	applied	\N
12	89	28	applied	\N
12	90	29	applied	\N
12	91	30	applied	\N
12	92	31	applied	\N
12	93	32	applied	\N
12	94	33	applied	\N
12	95	34	applied	\N
12	96	35	applied	\N
12	97	36	applied	\N
12	98	37	applied	\N
12	99	38	applied	\N
12	100	39	applied	\N
12	101	40	applied	\N
12	102	41	applied	\N
13	103	24	applied	\N
13	104	25	applied	\N
13	105	26	applied	\N
13	106	27	applied	\N
13	107	28	applied	\N
13	108	29	applied	\N
13	109	30	applied	\N
13	110	31	applied	\N
14	111	24	applied	\N
14	112	25	applied	\N
14	113	26	applied	\N
14	114	27	applied	\N
14	115	28	applied	\N
14	116	29	applied	\N
14	117	30	applied	\N
14	118	31	applied	\N
14	119	32	applied	\N
15	120	24	applied	\N
15	121	25	applied	\N
15	122	26	applied	\N
15	123	28	applied	\N
15	124	29	applied	\N
15	125	30	applied	\N
15	126	31	applied	\N
15	127	32	applied	\N
15	128	33	applied	\N
16	120	24	applied	\N
16	121	25	applied	\N
16	122	26	applied	\N
16	123	28	applied	\N
16	124	29	applied	\N
16	125	30	applied	\N
16	126	31	applied	\N
16	127	32	applied	\N
16	128	33	applied	\N
17	129	24	applied	\N
17	130	25	applied	\N
17	131	26	applied	\N
17	132	27	applied	\N
17	133	28	applied	\N
17	134	29	applied	\N
17	135	30	applied	\N
17	136	31	applied	\N
18	137	23	applied	\N
18	138	24	applied	\N
18	139	25	applied	\N
18	140	26	applied	\N
18	141	27	applied	\N
18	142	28	applied	\N
18	143	29	applied	\N
18	144	30	applied	\N
19	145	17	applied	\N
19	146	18	applied	\N
19	147	19	applied	\N
19	148	20	applied	\N
19	149	21	applied	\N
19	150	22	applied	\N
19	151	23	applied	\N
19	152	24	applied	\N
19	153	25	applied	\N
20	145	17	applied	\N
20	146	18	applied	\N
20	147	19	applied	\N
20	148	20	applied	\N
20	149	21	applied	\N
20	150	22	applied	\N
20	151	23	applied	\N
20	152	24	applied	\N
20	153	25	applied	\N
22	154	25	applied	\N
22	155	26	applied	\N
22	156	27	applied	\N
22	157	28	applied	\N
22	158	29	applied	\N
22	159	30	applied	\N
22	160	31	applied	\N
22	161	32	applied	\N
22	162	33	applied	\N
22	163	34	applied	\N
22	164	35	applied	\N
22	165	36	applied	\N
22	166	37	applied	\N
22	167	38	applied	\N
22	168	39	applied	\N
22	169	40	applied	\N
22	170	41	applied	\N
22	171	42	applied	\N
22	172	43	applied	\N
22	173	44	applied	\N
22	174	45	applied	\N
22	175	46	applied	\N
22	176	47	applied	\N
22	177	48	applied	\N
22	178	49	applied	\N
22	179	50	applied	\N
22	180	51	applied	\N
22	181	52	applied	\N
22	182	53	applied	\N
22	183	54	applied	\N
22	184	55	applied	\N
22	185	56	applied	\N
22	186	57	applied	\N
22	187	58	applied	\N
22	188	59	applied	\N
22	189	60	applied	\N
22	190	61	applied	\N
23	154	25	applied	\N
23	155	26	applied	\N
23	156	27	applied	\N
23	157	28	applied	\N
23	158	29	applied	\N
23	159	30	applied	\N
23	160	31	applied	\N
23	161	32	applied	\N
23	162	33	applied	\N
23	163	34	applied	\N
23	164	35	applied	\N
23	165	36	applied	\N
23	166	37	applied	\N
23	167	38	applied	\N
23	168	39	applied	\N
23	169	40	applied	\N
23	170	41	applied	\N
23	171	42	applied	\N
23	172	43	applied	\N
23	173	44	applied	\N
23	174	45	applied	\N
23	175	46	applied	\N
23	176	47	applied	\N
23	177	48	applied	\N
23	178	49	applied	\N
23	179	50	applied	\N
23	180	51	applied	\N
23	181	52	applied	\N
23	182	53	applied	\N
23	183	54	applied	\N
23	184	55	applied	\N
23	185	56	applied	\N
23	186	57	applied	\N
23	187	58	applied	\N
23	188	59	applied	\N
23	189	60	applied	\N
23	190	61	applied	\N
39	191	25	applied	\N
39	192	26	applied	\N
39	193	27	applied	\N
39	194	28	applied	\N
39	195	29	applied	\N
39	196	30	applied	\N
39	197	31	applied	\N
39	198	32	applied	\N
39	199	33	applied	\N
39	200	34	applied	\N
39	201	35	applied	\N
39	202	36	applied	\N
39	203	37	applied	\N
39	204	38	applied	\N
39	205	39	applied	\N
39	206	40	applied	\N
39	207	41	applied	\N
39	208	42	applied	\N
39	209	43	applied	\N
39	210	44	applied	\N
39	211	45	applied	\N
39	212	46	applied	\N
39	213	47	applied	\N
39	214	48	applied	\N
39	215	49	applied	\N
39	216	50	applied	\N
39	217	51	applied	\N
39	218	52	applied	\N
39	219	53	applied	\N
39	220	54	applied	\N
39	221	55	applied	\N
39	222	56	applied	\N
39	223	57	applied	\N
39	224	58	applied	\N
39	225	59	applied	\N
39	226	60	applied	\N
39	227	61	applied	\N
53	228	25	applied	\N
53	229	26	applied	\N
53	230	27	applied	\N
53	231	28	applied	\N
53	232	29	applied	\N
54	228	25	applied	\N
54	229	26	applied	\N
54	230	27	applied	\N
54	231	28	applied	\N
54	232	29	applied	\N
\.


--
-- Data for Name: blocks_zkapp_commands; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.blocks_zkapp_commands (block_id, zkapp_command_id, sequence_no, status, failure_reasons_ids) FROM stdin;
3	1	0	failed	{1,2}
3	2	1	failed	{3,2}
3	3	2	failed	{4}
3	4	3	failed	{3,2}
3	5	4	failed	{4}
3	6	5	failed	{3,2}
3	7	6	failed	{4}
3	8	7	failed	{3,2}
3	9	8	failed	{4}
3	10	9	failed	{3,2}
3	11	10	failed	{4}
3	12	11	failed	{3,2}
3	13	12	failed	{4}
3	14	13	failed	{3,2}
3	15	14	failed	{4}
3	16	15	failed	{3,2}
3	17	16	failed	{4}
3	18	17	failed	{3,2}
3	19	18	failed	{4}
3	20	19	failed	{3,2}
3	21	20	failed	{4}
3	22	21	failed	{3,2}
3	23	22	failed	{4}
3	24	23	failed	{3,2}
4	25	0	failed	{4}
4	26	1	failed	{3,2}
4	27	2	failed	{4}
4	28	3	failed	{3,2}
4	29	4	failed	{4}
4	30	5	failed	{3,2}
4	31	6	failed	{4}
4	32	7	failed	{3,2}
4	33	8	failed	{4}
4	34	9	failed	{3,2}
4	35	10	failed	{4}
4	36	11	failed	{3,2}
4	37	12	failed	{4}
4	38	13	failed	{3,2}
4	39	14	failed	{4}
4	40	15	failed	{3,2}
4	41	16	failed	{4}
4	42	17	failed	{3,2}
4	43	18	failed	{4}
4	44	19	failed	{3,2}
4	45	20	failed	{4}
4	46	21	failed	{3,2}
4	47	22	failed	{4}
4	48	23	failed	{3,2}
5	25	0	failed	{4}
5	26	1	failed	{3,2}
5	27	2	failed	{4}
5	28	3	failed	{3,2}
5	29	4	failed	{4}
5	30	5	failed	{3,2}
5	31	6	failed	{4}
5	32	7	failed	{3,2}
5	33	8	failed	{4}
5	34	9	failed	{3,2}
5	35	10	failed	{4}
5	36	11	failed	{3,2}
5	37	12	failed	{4}
5	38	13	failed	{3,2}
5	39	14	failed	{4}
5	40	15	failed	{3,2}
5	41	16	failed	{4}
5	42	17	failed	{3,2}
5	43	18	failed	{4}
5	44	19	failed	{3,2}
5	45	20	failed	{4}
5	46	21	failed	{3,2}
5	47	22	failed	{4}
5	48	23	failed	{3,2}
6	49	0	failed	{4}
6	50	1	failed	{3,2}
6	51	2	failed	{4}
6	52	3	failed	{3,2}
6	53	4	failed	{4}
6	54	5	failed	{3,2}
6	55	6	failed	{4}
6	56	7	failed	{3,2}
6	57	8	failed	{4}
6	58	9	failed	{3,2}
6	59	10	failed	{4}
6	60	11	failed	{3,2}
6	61	12	failed	{4}
6	62	13	failed	{3,2}
6	63	14	failed	{4}
6	64	15	failed	{3,2}
6	65	16	failed	{4}
6	66	17	failed	{3,2}
6	67	18	failed	{4}
6	68	19	failed	{3,2}
6	69	20	failed	{4}
6	70	21	failed	{3,2}
6	71	22	failed	{4}
6	72	23	failed	{3,2}
7	73	0	failed	{4}
7	74	1	failed	{3,2}
7	75	2	failed	{4}
7	76	3	failed	{3,2}
7	77	4	failed	{4}
7	78	5	failed	{3,2}
7	79	6	failed	{4}
7	80	7	failed	{3,2}
7	81	8	failed	{4}
7	82	9	failed	{3,2}
7	83	10	failed	{4}
7	84	11	failed	{3,2}
7	85	12	failed	{4}
7	86	13	failed	{3,2}
7	87	14	failed	{4}
7	88	15	failed	{3,2}
7	89	16	failed	{4}
7	90	17	failed	{3,2}
7	91	18	failed	{4}
7	92	19	failed	{3,2}
7	93	20	failed	{4}
7	94	21	failed	{3,2}
7	95	22	failed	{4}
7	96	23	failed	{3,2}
8	73	0	failed	{4}
8	74	1	failed	{3,2}
8	75	2	failed	{4}
8	76	3	failed	{3,2}
8	77	4	failed	{4}
8	78	5	failed	{3,2}
8	79	6	failed	{4}
8	80	7	failed	{3,2}
8	81	8	failed	{4}
8	82	9	failed	{3,2}
8	83	10	failed	{4}
8	84	11	failed	{3,2}
8	85	12	failed	{4}
8	86	13	failed	{3,2}
8	87	14	failed	{4}
8	88	15	failed	{3,2}
8	89	16	failed	{4}
8	90	17	failed	{3,2}
8	91	18	failed	{4}
8	92	19	failed	{3,2}
8	93	20	failed	{4}
8	94	21	failed	{3,2}
8	95	22	failed	{4}
8	96	23	failed	{3,2}
9	97	0	failed	{4}
9	98	1	failed	{3,2}
9	99	2	failed	{4}
9	100	3	failed	{3,2}
9	101	4	failed	{4}
9	102	5	failed	{3,2}
9	103	6	failed	{4}
9	104	7	failed	{3,2}
9	105	8	failed	{4}
9	106	9	failed	{3,2}
9	107	10	failed	{4}
9	108	11	failed	{3,2}
9	109	12	failed	{4}
9	110	13	failed	{3,2}
9	111	14	failed	{4}
9	112	15	failed	{3,2}
9	113	16	failed	{4}
9	114	17	failed	{3,2}
9	115	18	failed	{4}
9	116	19	failed	{3,2}
9	117	20	failed	{4}
9	118	21	failed	{3,2}
9	119	22	failed	{4}
9	120	23	failed	{3,2}
10	121	0	failed	{4}
10	122	1	failed	{3,2}
10	123	2	failed	{4}
10	124	3	failed	{3,2}
10	125	4	failed	{4}
10	126	5	failed	{3,2}
10	127	6	failed	{4}
10	128	7	failed	{3,2}
10	129	8	failed	{4}
10	130	9	failed	{3,2}
10	131	10	failed	{4}
10	132	11	failed	{3,2}
10	133	12	failed	{4}
10	134	13	failed	{3,2}
10	135	14	failed	{4}
10	136	15	failed	{3,2}
10	137	16	failed	{4}
10	138	17	failed	{3,2}
10	139	18	failed	{4}
10	140	19	failed	{3,2}
10	141	20	failed	{4}
10	142	21	failed	{3,2}
10	143	22	failed	{4}
10	144	23	failed	{3,2}
11	121	0	failed	{4}
11	122	1	failed	{3,2}
11	123	2	failed	{4}
11	124	3	failed	{3,2}
11	125	4	failed	{4}
11	126	5	failed	{3,2}
11	127	6	failed	{4}
11	128	7	failed	{3,2}
11	129	8	failed	{4}
11	130	9	failed	{3,2}
11	131	10	failed	{4}
11	132	11	failed	{3,2}
11	133	12	failed	{4}
11	134	13	failed	{3,2}
11	135	14	failed	{4}
11	136	15	failed	{3,2}
11	137	16	failed	{4}
11	138	17	failed	{3,2}
11	139	18	failed	{4}
11	140	19	failed	{3,2}
11	141	20	failed	{4}
11	142	21	failed	{3,2}
11	143	22	failed	{4}
11	144	23	failed	{3,2}
12	145	0	failed	{4}
12	146	1	failed	{3,2}
12	147	2	failed	{4}
12	148	3	failed	{3,2}
12	149	4	failed	{4}
12	150	5	failed	{3,2}
12	151	6	failed	{4}
12	152	7	failed	{3,2}
12	153	8	failed	{4}
12	154	9	failed	{3,2}
12	155	10	failed	{4}
12	156	11	failed	{3,2}
12	157	13	failed	{4}
12	158	14	failed	{3,2}
12	159	15	failed	{4}
12	160	16	failed	{3,2}
12	161	17	failed	{4}
12	162	18	failed	{3,2}
12	163	19	failed	{4}
12	164	20	failed	{3,2}
12	165	21	failed	{4}
12	166	22	failed	{3,2}
12	167	23	failed	{4}
12	168	24	failed	{3,2}
13	169	0	failed	{4}
13	170	1	failed	{3,2}
13	171	2	failed	{4}
13	172	3	failed	{3,2}
13	173	4	failed	{4}
13	174	5	failed	{3,2}
13	175	6	failed	{4}
13	176	7	failed	{3,2}
13	177	8	failed	{4}
13	178	9	failed	{3,2}
13	179	10	failed	{4}
13	180	11	failed	{3,2}
13	181	12	failed	{4}
13	182	13	failed	{3,2}
13	183	14	failed	{4}
13	184	15	failed	{3,2}
13	185	16	failed	{4}
13	186	17	failed	{3,2}
13	187	18	failed	{4}
13	188	19	failed	{3,2}
13	189	20	failed	{4}
13	190	21	failed	{3,2}
13	191	22	failed	{4}
13	192	23	failed	{3,2}
14	193	0	failed	{4}
14	194	1	failed	{3,2}
14	195	2	failed	{4}
14	196	3	failed	{3,2}
14	197	4	failed	{4}
14	198	5	failed	{3,2}
14	199	6	failed	{4}
14	200	7	failed	{3,2}
14	201	8	failed	{4}
14	202	9	failed	{3,2}
14	203	10	failed	{4}
14	204	11	failed	{3,2}
14	205	12	failed	{4}
14	206	13	failed	{3,2}
14	207	14	failed	{4}
14	208	15	failed	{3,2}
14	209	16	failed	{4}
14	210	17	failed	{3,2}
14	211	18	failed	{4}
14	212	19	failed	{3,2}
14	213	20	failed	{4}
14	214	21	failed	{3,2}
14	215	22	failed	{4}
14	216	23	failed	{3,2}
15	217	0	failed	{4}
15	218	1	failed	{3,2}
15	219	2	failed	{4}
15	220	3	failed	{3,2}
15	221	4	failed	{4}
15	222	5	failed	{3,2}
15	223	6	failed	{4}
15	224	7	failed	{3,2}
15	225	8	failed	{4}
15	226	9	failed	{3,2}
15	227	10	failed	{4}
15	228	11	failed	{3,2}
15	229	12	failed	{4}
15	230	13	failed	{3,2}
15	231	14	failed	{4}
15	232	15	failed	{3,2}
15	233	16	failed	{4}
15	234	17	failed	{3,2}
15	235	18	failed	{4}
15	236	19	failed	{3,2}
15	237	20	failed	{4}
15	238	21	failed	{3,2}
15	239	22	failed	{4}
15	240	23	failed	{3,2}
16	217	0	failed	{4}
16	218	1	failed	{3,2}
16	219	2	failed	{4}
16	220	3	failed	{3,2}
16	221	4	failed	{4}
16	222	5	failed	{3,2}
16	223	6	failed	{4}
16	224	7	failed	{3,2}
16	225	8	failed	{4}
16	226	9	failed	{3,2}
16	227	10	failed	{4}
16	228	11	failed	{3,2}
16	229	12	failed	{4}
16	230	13	failed	{3,2}
16	231	14	failed	{4}
16	232	15	failed	{3,2}
16	233	16	failed	{4}
16	234	17	failed	{3,2}
16	235	18	failed	{4}
16	236	19	failed	{3,2}
16	237	20	failed	{4}
16	238	21	failed	{3,2}
16	239	22	failed	{4}
16	240	23	failed	{3,2}
18	265	0	failed	{4}
18	266	1	failed	{3,2}
18	267	2	failed	{4}
18	268	3	failed	{3,2}
18	269	4	failed	{4}
18	270	5	failed	{3,2}
18	271	6	failed	{4}
18	272	7	failed	{3,2}
18	273	8	failed	{4}
18	274	9	failed	{3,2}
18	275	10	failed	{4}
18	276	11	failed	{3,2}
18	277	12	failed	{4}
18	278	13	failed	{3,2}
18	279	14	failed	{4}
18	280	15	failed	{3,2}
18	281	16	failed	{4}
18	282	17	failed	{3,2}
18	283	18	failed	{4}
18	284	19	failed	{3,2}
18	285	20	failed	{4}
18	286	21	failed	{3,2}
18	287	22	failed	{4}
17	241	0	failed	{4}
17	242	1	failed	{3,2}
17	243	2	failed	{4}
17	244	3	failed	{3,2}
17	245	4	failed	{4}
17	246	5	failed	{3,2}
17	247	6	failed	{4}
17	248	7	failed	{3,2}
17	249	8	failed	{4}
17	250	9	failed	{3,2}
17	251	10	failed	{4}
17	252	11	failed	{3,2}
17	253	12	failed	{4}
17	254	13	failed	{3,2}
17	255	14	failed	{4}
17	256	15	failed	{3,2}
17	257	16	failed	{4}
17	258	17	failed	{3,2}
17	259	18	failed	{4}
17	260	19	failed	{3,2}
17	261	20	failed	{4}
17	262	21	failed	{3,2}
17	263	22	failed	{4}
17	264	23	failed	{3,2}
19	288	0	failed	{3,2}
19	289	1	failed	{4}
19	290	2	failed	{3,2}
19	291	3	failed	{4}
19	292	4	failed	{3,2}
19	293	5	failed	{4}
19	294	6	failed	{3,2}
19	295	7	failed	{4}
19	296	8	failed	{3,2}
19	297	9	failed	{4}
19	298	10	failed	{3,2}
19	299	11	failed	{4}
19	300	12	failed	{3,2}
19	301	13	failed	{4}
19	302	14	failed	{3,2}
19	303	15	failed	{4}
19	304	16	failed	{3,2}
20	288	0	failed	{3,2}
20	289	1	failed	{4}
20	290	2	failed	{3,2}
20	291	3	failed	{4}
20	292	4	failed	{3,2}
20	293	5	failed	{4}
20	294	6	failed	{3,2}
20	295	7	failed	{4}
20	296	8	failed	{3,2}
20	297	9	failed	{4}
20	298	10	failed	{3,2}
20	299	11	failed	{4}
20	300	12	failed	{3,2}
20	301	13	failed	{4}
20	302	14	failed	{3,2}
20	303	15	failed	{4}
20	304	16	failed	{3,2}
21	305	0	failed	{4}
21	306	1	failed	{3,2}
21	307	2	failed	{4}
21	308	3	failed	{3,2}
21	309	4	failed	{4}
21	310	5	failed	{3,2}
21	311	6	failed	{4}
21	312	7	failed	{3,2}
21	313	8	failed	{4}
21	314	9	failed	{3,2}
21	315	10	failed	{4}
22	316	0	failed	{3,2}
22	317	1	failed	{4}
22	318	2	failed	{3,2}
22	319	3	failed	{4}
22	320	4	failed	{3,2}
22	321	5	failed	{4}
22	322	6	failed	{3,2}
22	323	7	failed	{4}
22	324	8	failed	{3,2}
22	325	9	failed	{4}
22	326	10	failed	{3,2}
22	327	12	failed	{4}
22	328	13	failed	{3,2}
22	329	14	failed	{4}
22	330	15	failed	{3,2}
22	331	16	failed	{4}
22	332	17	failed	{3,2}
22	333	18	failed	{4}
22	334	19	failed	{3,2}
22	335	20	failed	{4}
22	336	21	failed	{3,2}
22	337	22	failed	{4}
22	338	23	failed	{3,2}
22	339	24	failed	{4}
23	316	0	failed	{3,2}
23	317	1	failed	{4}
23	318	2	failed	{3,2}
23	319	3	failed	{4}
23	320	4	failed	{3,2}
23	321	5	failed	{4}
23	322	6	failed	{3,2}
23	323	7	failed	{4}
23	324	8	failed	{3,2}
23	325	9	failed	{4}
23	326	10	failed	{3,2}
23	327	12	failed	{4}
23	328	13	failed	{3,2}
23	329	14	failed	{4}
23	330	15	failed	{3,2}
23	331	16	failed	{4}
23	332	17	failed	{3,2}
23	333	18	failed	{4}
23	334	19	failed	{3,2}
23	335	20	failed	{4}
23	336	21	failed	{3,2}
23	337	22	failed	{4}
23	338	23	failed	{3,2}
23	339	24	failed	{4}
24	340	0	failed	{3,2}
24	341	1	failed	{4}
24	342	2	failed	{3,2}
24	343	3	failed	{4}
24	344	4	failed	{3,2}
24	345	5	failed	{4}
24	346	6	failed	{3,2}
24	347	7	failed	{4}
24	348	8	failed	{3,2}
24	349	9	failed	{4}
24	350	10	failed	{3,2}
24	351	11	failed	{4}
24	352	12	failed	{3,2}
24	353	13	failed	{4}
24	354	14	failed	{3,2}
24	355	15	failed	{4}
24	356	16	failed	{3,2}
24	357	17	failed	{4}
24	358	18	failed	{3,2}
25	359	0	failed	{4}
25	360	1	failed	{3,2}
25	361	2	failed	{4}
26	362	0	failed	{3,2}
26	363	1	failed	{4}
27	362	0	failed	{3,2}
27	363	1	failed	{4}
28	364	0	failed	{3,2}
29	365	0	failed	{4}
30	366	0	failed	{3,2}
31	366	0	failed	{3,2}
32	367	0	failed	{4}
32	368	1	failed	{3,2}
32	369	2	failed	{4}
33	370	0	failed	{3,2}
33	371	1	failed	{4}
33	372	2	failed	{3,2}
34	373	0	failed	{4}
34	374	1	failed	{3,2}
34	375	2	failed	{4}
34	376	3	failed	{3,2}
35	377	0	failed	{4}
36	377	0	failed	{4}
37	378	0	failed	{3,2}
37	379	1	failed	{4}
38	378	0	failed	{3,2}
38	379	1	failed	{4}
39	380	0	failed	{3,2}
39	381	1	failed	{4}
39	382	2	failed	{3,2}
39	383	3	failed	{4}
39	384	4	failed	{3,2}
39	385	5	failed	{4}
39	386	6	failed	{3,2}
39	387	7	failed	{4}
39	388	8	failed	{3,2}
39	389	9	failed	{4}
39	390	10	failed	{3,2}
39	391	11	failed	{4}
39	392	12	failed	{3,2}
39	393	14	failed	{4}
39	394	15	failed	{3,2}
39	395	16	failed	{4}
39	396	17	failed	{3,2}
39	397	18	failed	{4}
39	398	19	failed	{3,2}
39	399	20	failed	{4}
39	400	21	failed	{3,2}
39	401	22	failed	{4}
39	402	23	failed	{3,2}
39	403	24	failed	{4}
40	404	0	failed	{3,2}
40	405	1	failed	{4}
40	406	2	failed	{3,2}
40	407	3	failed	{4}
40	408	4	failed	{3,2}
40	409	5	failed	{4}
40	410	6	failed	{3,2}
40	411	7	failed	{4}
40	412	8	failed	{3,2}
40	413	9	failed	{4}
40	414	10	failed	{3,2}
40	415	11	failed	{4}
40	416	12	failed	{3,2}
41	417	0	failed	{4}
41	418	1	failed	{3,2}
41	419	2	failed	{4}
41	420	3	failed	{3,2}
41	421	4	failed	{4}
42	422	0	failed	{3,2}
42	423	1	failed	{4}
42	424	2	failed	{3,2}
42	425	3	failed	{4}
43	422	0	failed	{3,2}
43	423	1	failed	{4}
43	424	2	failed	{3,2}
43	425	3	failed	{4}
44	426	0	failed	{3,2}
44	427	1	failed	{4}
45	426	0	failed	{3,2}
45	427	1	failed	{4}
46	428	0	failed	{3,2}
46	429	1	failed	{4}
46	430	2	failed	{3,2}
46	431	3	failed	{4}
47	432	0	failed	{3,2}
47	433	1	failed	{4}
47	434	2	failed	{3,2}
48	435	0	failed	{4}
49	436	0	failed	{3,2}
49	437	1	failed	{4}
49	438	2	failed	{3,2}
49	439	3	failed	{4}
49	440	4	failed	{3,2}
50	441	0	failed	{4}
50	442	1	failed	{3,2}
50	443	2	failed	{4}
50	444	3	failed	{3,2}
50	445	4	failed	{4}
50	446	5	failed	{3,2}
50	447	6	failed	{4}
50	448	7	failed	{3,2}
50	449	8	failed	{4}
50	450	9	failed	{3,2}
51	451	0	failed	{4}
51	452	1	failed	{3,2}
51	453	2	failed	{4}
51	454	3	failed	{3,2}
52	451	0	failed	{4}
52	452	1	failed	{3,2}
52	453	2	failed	{4}
52	454	3	failed	{3,2}
53	455	0	failed	{4}
53	456	1	failed	{3,2}
53	457	2	failed	{4}
53	458	3	failed	{3,2}
53	459	4	failed	{4}
53	460	5	failed	{3,2}
53	461	7	failed	{4}
53	462	8	failed	{3,2}
53	463	9	failed	{4}
53	464	10	failed	{3,2}
53	465	11	failed	{4}
53	466	12	failed	{3,2}
53	467	13	failed	{4}
53	468	14	failed	{3,2}
53	469	15	failed	{4}
53	470	16	failed	{3,2}
53	471	17	failed	{4}
53	472	18	failed	{3,2}
53	473	19	failed	{4}
53	474	20	failed	{3,2}
53	475	21	failed	{4}
53	476	22	failed	{3,2}
53	477	23	failed	{4}
53	478	24	failed	{3,2}
54	455	0	failed	{4}
54	456	1	failed	{3,2}
54	457	2	failed	{4}
54	458	3	failed	{3,2}
54	459	4	failed	{4}
54	460	5	failed	{3,2}
54	461	7	failed	{4}
54	462	8	failed	{3,2}
54	463	9	failed	{4}
54	464	10	failed	{3,2}
54	465	11	failed	{4}
54	466	12	failed	{3,2}
54	467	13	failed	{4}
54	468	14	failed	{3,2}
54	469	15	failed	{4}
54	470	16	failed	{3,2}
54	471	17	failed	{4}
54	472	18	failed	{3,2}
54	473	19	failed	{4}
54	474	20	failed	{3,2}
54	475	21	failed	{4}
54	476	22	failed	{3,2}
54	477	23	failed	{4}
54	478	24	failed	{3,2}
\.


--
-- Data for Name: epoch_data; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.epoch_data (id, seed, ledger_hash_id, total_currency, start_checkpoint, lock_checkpoint, epoch_length) FROM stdin;
1	2va9BGv9JrLTtrzZttiEMDYw1Zj6a6EHzXjmP9evHDTG3oEquURA	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	1
2	2vafPBQ3zQdHUEDDnFGuiNvJz7s2MhTLJgSzQSnu5fnZavT27cms	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKYHXDsp1zorCnjjp6LD4SnN9TATbqyVwZXandyPKmn7ez62QdV	2
3	2vbNaPS2GwgNFJHVCyoG4WmLMPXmxfAtC8XRSFbLkU4eBkwLR4JX	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLsxSxxCrohG8UatbXz4wPpEgG5a7GmQ1H9j77qxM8VZYwJZaLM	3
4	2vbbEiRgvv6pVS8SgfysfYxzE8Ebtg68a1zSXCS2vGFummiGpNwh	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKwwK3tjP8HcHTgFhZEywnnLa358kj3g57UM8pXdJSnc5JaZhkz	4
5	2vb3dNbkHULdE88id23rhRYiUVSfqo5PPHHLNnHdyi8f89zfyfD5	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKmdmAN1LRtn4PU5zD3P56GoPCBZGQ18UScUWp6RrHqs8DnNA8n	5
6	2vbQk2iPK1xSzhrRdDXK6YEsNPXiA1eostyyeeyWKpCnTJtUSGvh	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKmdmAN1LRtn4PU5zD3P56GoPCBZGQ18UScUWp6RrHqs8DnNA8n	5
7	2vb7TWkpzzM1E8Sgx3X9mXTssmxqphdgQn9eAU8kAmjZtvYqZzEc	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLSvRBYAq2FBTTduWZ6fQEkGRJEA8v9rKH4bissemXjtbWnimc8	6
8	2vas6Vdum5aJ3u8xhhZT3FdiQe2ux62tajcQoCX3khyjWtEbnJ3z	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLUBt5PHX2jpL52iWXfvYsjfN5dCNwVp4khWzuzoe4VV7THqq5b	7
9	2vbYteGUD87D3a1j1WSbt4tWgYo3EqH6VmuwNzefNy7RSF9RzGcy	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLUBt5PHX2jpL52iWXfvYsjfN5dCNwVp4khWzuzoe4VV7THqq5b	7
10	2vaTvoYEQRvcsJ2fDRb39J6JwkfVLqXom8G6sGFriM6nsikPaJ2X	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKP3kQ4pnEQVB4KyKbtWFiFTcCiDcQMcZJN5FfaCZDw1MHHrDBM	8
11	2vbQngfZbfrnYHkN6vXZGYipoEtamsFAMPZmUKDtdAdDV8c5UBQE	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NL4npdHK9EBwQ969kwHGoQCfd28m6XgxiMRipjvxuKxtc3eV1vo	9
12	2vagPevX892fsTo1FQZi8P3ciV7eKrExdEHrctaHQNE9Gdndgr9y	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NL4npdHK9EBwQ969kwHGoQCfd28m6XgxiMRipjvxuKxtc3eV1vo	9
13	2vaHZXYmGVWdQn7qdTm1nFJdUJfSyhMtCwRymdhaHRGTwbjo6KVw	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NK9SePsfC7rzGojWJzfwmq4Ci9LmHtaeKuiE1odBXmLYrgVvUyg	10
14	2vbSctEduoPvvob7MCYgTZpDjTvsiXH4ZYCWP8RKmTtCx8ouz6Si	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLs57Bs3BPJ9F9qaLdq2oL3YMdWSJ3oFsRmm1Evdj56Vh9sdx9A	11
15	2vb5PBE7NnY69hGeDTHbEk3wnFZ2YgLeteA6LLs89VqMw2DHRVEL	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NK3zThH4kzZsq2mqLpshGV6YCr7rfL3KpvdxwSJNoJafqtxZXxQ	12
16	2vaUGrMJNMsUS6yY4VX5mduMkH1jDAkjfso2iemccpSR6xKUrV7L	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLDtntHPCiageEmrD2C6Sp2H9ZgF6GdVtGEKpeyTYovkxwGViv4	13
17	2vb8qaNVdmZ7kaMmbttRrsrEWpRxqAWhBcwYHqzNHghusx1qXJxP	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLDtntHPCiageEmrD2C6Sp2H9ZgF6GdVtGEKpeyTYovkxwGViv4	13
18	2vaK2Dxq8ptr1AvNXNejjDEKs6FVfkfD2g3wUtvzF9T23wc64qT5	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLAjCR9vhNEB6dTYuqtZVtsiYYvvBbYuLQXtsbBRaex2GHroXCd	14
19	2vaUAYr6YuDoTAtvQj6eRzR8nLY3w9LCeLbmWLMMsdbya6mJK2es	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKuMG7Yrwp4Qs1RTaPD5tsd392chm3mKneuzSB1eDdQ7t8EVfdM	15
20	2vaQS2JCGA5QH9P5X9jvBm57pYUhURmc3ELZ1WjhmvWQnWDsBeo5	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKc3vVKsd32mRYY6rUwhwWcLwNvdZhTB77G4WApRGRMLz5U6R6j	16
21	2vbZmZ4n5Cv8ZDz4eFjM3wN8M5LfpnsmcZB1y6zQB8mv7do39GmK	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKc3vVKsd32mRYY6rUwhwWcLwNvdZhTB77G4WApRGRMLz5U6R6j	16
22	2vaFQGXAgnMDEReNr6AhJNDEJaybGq8GoSGVk9hG4vk9uj2cF4EY	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NK58Bu1kqj14gXnAEP2iK9zqdDZqLivU3isGb9tdZNd6hQMDqKc	17
23	2vbCZ9DUxhUaarrFivApx6zzzHyLHqYb1yG4MpZ7wAk5fKLz6sAs	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NL7HLRrPzSKM6BHz9txYrBP5yXsixsCtn4hV43d1DCnM27Y7pQV	18
24	2vc4dErVeGBYy8827xrK6a9b6PsXvDXvLwdUGsHVFvxqwxDAQXdj	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NL7HLRrPzSKM6BHz9txYrBP5yXsixsCtn4hV43d1DCnM27Y7pQV	18
25	2vbwvf3DAWWVA2nfbfe5kZRHbH3PpNJWAuM8AMqrriucTEmivuZj	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKMUTkTfXeTcLxBcxXDBTZya7y2z5Ka8iUN3mZdmzy8nMbuTQAG	19
26	2vasZSzr5icmXW2hRkE3D7hRnBA2V9NG3jTfcRrXthjrwjS1NRE8	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLcFWjMHCjM6gtkcpGYd8VGdDChDJJbBZQnRnSNSDq8z3qCTXvZ	20
27	2vaq2ZDkVPa1jJPMRqy3uqDKcYNhc64VzcoPiSEwwLX1TKp8JP5N	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLt1CDP3tmiKbiFiJR7vwQd6ikfmrx11SBdw91UEwthbbGKYSg4	21
28	2vbiwiHCWJ9Z6U9yte7A3WwyoExgGji5XVZ6GXe5Y6iZCJjoTLJR	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLt1CDP3tmiKbiFiJR7vwQd6ikfmrx11SBdw91UEwthbbGKYSg4	21
29	2vbhzPAxQct1h8bByfzyfpbK3TAZGrMk8SGk7bLQFHxqtiRiZcEz	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKNHXP8SFnuPdV1gkpznzhs9W7d4xDD8nN1Th81aNzmxzcXeXbW	22
30	2vbSEn8vtrgSnZBgH133rhWw1XYpitcEtHyT4DiNVoXMQXFW6Ypz	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKtRpWbZWgnRLMR6PgRQpfwaJPK8ry233fUYosEuXUPsufakWm6	23
31	2vbhJLCcxpEijygc66Sj7kAWZMU6TfEk8EcUwbuiFS2aNhnY9P9F	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLXRtHiYQVKULckBi1jB7QLnt2N1FYyK31jyzRMHcD7nQTb2hEe	24
32	2vbCHsjZarwPRhbPDGZysQoP6sSDXFMYcQVZrEJYghPJgozDNcGe	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLXRtHiYQVKULckBi1jB7QLnt2N1FYyK31jyzRMHcD7nQTb2hEe	24
33	2vb1BDV5P6DqKde1hiFw1WLb5GdK6vHJnE8h1mFStu5U4D2MWpXt	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKhvALP75aWx4J5Ng61APjRwVTz3jAt4Q9BtvTi6XBRcGnFnUxk	25
34	2vawDRD8nMaFaN6LLopX6nrFsriqRCjfzh88NBAPoQDEx7qrwo16	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKuRjdJfFERadvsnhfVDahovSWgutoXpQhkrx5UMiePn85jkw2y	26
35	2vayFxgZxyZWQBSjAKpfJAqcBefGgyJWwStjStn4Kr5TAfofMjGb	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKrv1oxG7VpGEqyBk6jUnXedRN9owfQXndxxhQmwTTrz1HQmPDh	27
36	2vb2XNy7z7mejuJW7biq5e1GQrF5rCaJT4annGJ787q6wgqUYQt3	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKf18ZsF3eGYTCoGMcG6vH9oEaD7iD3VKmWb82w6XzAmaEh7PA7	28
38	2vaJwnA1sHw5KfQsfy3kk78Bpk4V54AVmiKtqbChHoNowNKpuq6F	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKNFST7eVsc4JvbPMzRe8vW9e4PDwgCyiU8qZu1mup5PsQASvPN	29
39	2vb29Wy2yurYSXbSgxnL2pZeMsDBZ2UDurg9EvGBfxtxqD4DZH3d	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKNFST7eVsc4JvbPMzRe8vW9e4PDwgCyiU8qZu1mup5PsQASvPN	29
40	2vaUarSYyoYW7bBZN189H9BKdHwNyEQdYNazdmKMTtvL8uCgpi5H	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLKaDkjuJTr8yLcjMiRaDANKuUL2sbisgXYjzwCP29a5G8CNcFd	30
42	2vaeZ3F9ESnvwhUEzVECcErWC1XyZJuZnvhTiSs2ghfEjAbJFfE4	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKFpDeoLLKAQai1rvKfiDz5b5zVEvgjws2oFCHEhuBeNh9vfZuY	32
44	2vbg5vFNEEqZjAYWne3B4u36XmGiEFnbV4GhgNfEsWA5yAnVpuTP	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKWRGzEYr8EAzYreRQHqTGijmtcTDZUZoJ7LfEnixYoZStEEZLp	33
46	2vaY7wnytZrUJujWXJnfh7Qc31FgfGoFrjXqsjTJhdpPFfiSiMPa	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKSQPMp6jN8RbteazTCYVZQDBi36G2geKwoNdeQoYfhaMzb2ttE	34
48	2vaRfcm3UFrBcTxqV5qzJ78kydnPEgm1F73DBqsjbCpDm9DvMjZR	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKd9qshsE5inNPLa3Etibo28UFv7bHbnA11M3UZZGereoeocdyj	36
50	2vbcEqTdj8xy4H4Qxqw1RWm5aV6mh1tzkBR7ouG3qEVoJAqmAPMA	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NL1N7BWom4A3ELvTKFKi2GD8zArsg6nZtBmwRBHf7P4ErhztjUt	38
37	2vbuEtkD4rTs9CzAuqPdDPz8NxBALoPuDoFZXhWSiLwEcXvLvvCx	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKf18ZsF3eGYTCoGMcG6vH9oEaD7iD3VKmWb82w6XzAmaEh7PA7	28
41	2vbdNWiBtsrJpUkz9L8uVKHgj3rV7WVDjgp8XqaZEsXc5vQqjp55	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLtwaemze8vowHaZYTLSTxiYXtLPCb5kapbC9LTWb2dPAhVCQ5s	31
43	2vaGnU8iSfUtUJyuvQS4eGqp7sqTA2JKML1KVjdYVjoANiYHzfMC	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKWRGzEYr8EAzYreRQHqTGijmtcTDZUZoJ7LfEnixYoZStEEZLp	33
45	2vaZ7GnAz2ihXxRS3YqvPv7JRsArykPgWaeqTGm14BHa4pp8B7eM	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKSQPMp6jN8RbteazTCYVZQDBi36G2geKwoNdeQoYfhaMzb2ttE	34
47	2vbMwys6FK64HoT6KqRnKzTUvtUp77BhGxSGHW8gZbxBEgftwUdz	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLt8U8TUExPFkHFTh47Zcq53eagFZA9enJhp6htkfTKnjMgNXEL	35
49	2vbqdj6ztdgB933qjFT4ja4hMM1deny2jq4YMdMxo23xRmXi421Q	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKxCKgA2gEn4GLng53bFr1JKssVrkJoA9rfQ7BgUAYTeD9n2pKv	37
51	2vc2hDhUh8tndmV32k4fc2t16QeAHX13T4VvhFT9qdXFHbm16jZu	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKVq8vTqzsXJ3x2EuC8DEuipPkbG68BNEbAMLARi6pswkjktsMk	39
52	2vajbTy4BH34wecWa1U8s6zzJaSNGazNA7NqFJxpHpZxFkswACcf	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLQMa6zbyBryUEJ1sfgydCLn9obo8NGQQdjpbWbmGPHxyKbanM3	40
53	2vbbHQaaoutaXTBPe9zoJMt3YUMWa7f3a88WfMxrRBMPA96utawy	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLQMa6zbyBryUEJ1sfgydCLn9obo8NGQQdjpbWbmGPHxyKbanM3	40
54	2vbMP8xsukUrEqBkhVD4aoZNgFsoog6WBcbG9NAf3AxdtXyJ6SBB	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKTs8YsCz4fALC2hErYzv5tUCwgAQ6bF4nNhsDSST97EPWN15WA	41
55	2vaB2caMPDbJSSbmmYMnrmcGh7ZJqKDdBEpmmgHfUTTWGmD7TC5b	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKTs8YsCz4fALC2hErYzv5tUCwgAQ6bF4nNhsDSST97EPWN15WA	41
\.


--
-- Data for Name: internal_commands; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.internal_commands (id, command_type, receiver_id, fee, hash) FROM stdin;
1	coinbase	15	720000000000	5JuDCBXQtsvcKNMpe3n6Xq2TVmG94StwVmFaGffnpQTVwHKmtvg9
2	fee_transfer	15	128500000000	5JuZxQU5tJJ6gSyG8UkKfeBrW4GP1GP7LT6N5J29Hgn9rBaTSr3a
3	coinbase	113	720000000000	5JtW4jpn9piSgtUDFtRGFWnX6kgtNhDKjDzLnmTCQSkzp4Eao6Vr
4	fee_transfer	113	122250000000	5JuTtWeUqUM1KeDh4XsvaB9BHf9ES7bs3yWArm1qCpV5YfBKp8qw
5	fee_transfer	15	122250000000	5JuK4DVeVFiX4bmx6zKq3sXoDsEJ9KU7GYFtMQU8SJRgWwKuCC5D
6	fee_transfer	113	121750000000	5JvERMHvjT6THCwNcTYygr8XFSrW9VbFDAUTttKQfvRcBCpmS5dk
7	fee_transfer	113	250000000	5Jtvk8ik4bx8srgf4RFYX13aniNNj6UcZx8CrLAQwa4MMoP9F1cV
8	fee_transfer	15	124000000000	5JudtVzewjaai3px3o1Stt9ysTCfs2duPNfaAwwPdA7Vy3R6scHo
9	fee_transfer	15	60000000000	5JvJFtghh5EB7pPRgGA6HRPNwERx9ZALCspqAmkboMWEjCcTgCfa
10	fee_transfer	15	64250000000	5Jtnsjut5BUQadB4remN1EmudURwXGD4jcPsxfze1BBFAuDYggNr
11	fee_transfer	15	122000000000	5Juxj6k3byf8oGL1vX1ZEfjMaKWUGRdAEE8ZyD4dPkP9K3gTFKXv
12	fee_transfer	113	120750000000	5JuUVzKQR7i5rWtFsHuFZ3Rg7r372gf7NLqXktQ6vcRzFhcEoEWs
13	fee_transfer_via_coinbase	206	1000000	5JvAL4m619JGW3tbBHgz9QTZdQGE8Y73tQaH1cwPQ7S7dn6bXnpK
14	coinbase	113	720000000000	5JvDpxm8JeVYenwrfhJFMsLJsqPPFUA5Tzw9XgvKkvmeEhLoyvpQ
15	fee_transfer	113	1461000000	5JuCZEi3jp7UvQd6Dnzk7S3LiZGhgmmtxXugnwDs8dwCrYc8MNtj
16	fee_transfer	206	39000000	5Jtj1PtiEZDoLZ2QkysK1KF9AwyMWWmkfGFUottEzrz6YjWZVqBh
17	fee_transfer	15	120750000000	5JvR2EHao11nHVAANuzGJsXyumHdfYbThh1wkj4PWhUWVPou6MM2
18	coinbase	15	720000000000	5JudDNsZrf9XPD4mqfJCfwkt9M58rJJAZXUMFpEH86Lv9MD3fHhA
19	fee_transfer	15	1461000000	5JvKPDh9bPsJAkYHnWRBqTwb2R6qUCpS1u9TwLNLfFnwimKpXLSX
20	fee_transfer	113	121998000000	5JttTvybSS5uvyfWDDpV5pC8YpprQxVeabPFfuxU9U9Z5NcxuVTu
21	fee_transfer	206	2000000	5Jtq5tF8jnxfwYoDMoLpCPUhNf2HXgiQn7LgGivbn2Lb51GGE4nU
22	fee_transfer	113	116996000000	5JuDMAneYgFaHTtvmb4xqJdS9rYjBdwtqNVQYtivgFiw54pHx324
23	fee_transfer	206	4000000	5JuoqCP15QPBMA4Md1QqQpg7qaz3xTZ3rRUucEtfN8s3AMDbvArT
24	fee_transfer	15	87247000000	5JufnxmkyttTdC7Hi6SSE7VYGMsBERui6BaVJ4iAAEFHXFpGkEPq
25	fee_transfer	206	3000000	5JuTyuRZDZVoKWvb5pni8N7KUM6JJqRLRL3FDSeye677x2WEysD3
26	fee_transfer	113	87247000000	5JuBaj4pd2ybcnur2Y6uDJvcaiQd44g8gPfm9o9cdwDdgo2mEUoW
27	fee_transfer	113	54995000000	5JuctuumYjgcD3C6HZpDfBKMn8hn8DHx843N1vZDWQGYEUY93Sgk
28	fee_transfer	206	5000000	5JuBDLuhmgyDiQNBEjMUWPh2crLZHLo8o6JszxZN5nKXRPF5cKcv
29	fee_transfer	15	54994000000	5JvKHwhHpFzeuvXQY88FZJCqqFK7fG84rxXDn7xR3wfUWam8a4Pc
30	fee_transfer	206	6000000	5Jtus5b4YSkLzwgFvVcAbjUPcV2mrvHJ9zWMW3M65vfjZx4khyJG
31	fee_transfer	15	74242000000	5JuwwzyRKUEpLDLyvH8tL29oW4khPen1ReUgKXnFJ9Bc3ZSfF67e
32	fee_transfer	206	8000000	5JvGvDQefbMRHjL39hdmapjJx3YVDYjqHdLc948zBXpNpzMAkdTu
33	fee_transfer	113	54994000000	5JtgpaA3oJfrcPPEiBrmkwjFKJHjiGTH3CfMtuCm7hRayagtcp2K
34	fee_transfer	113	74242000000	5JuTS8MdQzx3BgrYWEWUhANiL6s23VeopyDVpgpXmiqDHa8VjwTk
35	fee_transfer	15	94998000000	5JvMzSiuZLqLce8rr2trxRms3mC9wcgxjzDxhHfWzAhxiqf7Mn7h
36	fee_transfer	15	14996000000	5JuqirEUtgSWp1g5Qi72SXN3hgejgdtJZy6kHGFqRqYDTvv6Tbcc
37	fee_transfer	113	9997000000	5JttGBSKWBpLijZPw9FPbGuRdfw59SWTtyE42Vn8NiNHXtEbjRFS
38	fee_transfer	15	9997000000	5Jtrocqcxvf749DwwYBaNeRetx7rLUHsaaZn849PRpXPYUedHoV2
39	fee_transfer	15	4998000000	5Ju5Yetyu1xqtGSoyadQpaVSdx2eZY4K7JrWAGkgadnuRgdRDGRn
40	fee_transfer	113	4998000000	5JuKGPzwpX6RDRHJ75rBbWuGhibyWd8Gh3muwtRFuqsoTaJSfAvt
41	fee_transfer	113	14996000000	5JttU24YEfCniZzc5zszni5RhAR995vhgFiq1ZY15S2hfCLEMCU3
42	fee_transfer	15	19995000000	5Jtj1N1JbJhWukxtYhafZ25F3WgdjHeQcYMyGzyg34FZjdFCZUPf
43	fee_transfer	113	64989000000	5JuxNtaZ7sZhAf34Tsmd8cu86mhG6ZHC4BV5SBfbxtHimrrMPmn1
44	fee_transfer	206	11000000	5JvHVEir41xiu3LYKdbeQ897QvRQ97HMrKzpozXaRSJ68U67DjmM
45	fee_transfer	113	64250000000	5Juu1PHNxBUhnSm92DqNhhaAigRRW6fH4tNhnwcPcFauc16C7B8W
46	fee_transfer	15	64994000000	5JuCaqRqn4AJnY2xksGQDWtjMYQAEhTbKTUqCN7VHDv8bAod4jL4
47	fee_transfer	15	24995000000	5JuvzhisWr4p2sM8kL8gMGJxhPxbM2ZaASTnrPiEs6T2CQ1W3Auk
48	fee_transfer	15	19997000000	5Jub9ubvGW2XGwKYhRyDQc6XHBawLKDuZe6Piwy78CrczEpFokrX
49	fee_transfer	113	19997000000	5Jui2kPFdHsi2MdZ6PF5RUAWv2hVmqzqLKGifN5UC1YxcpjtCNSN
50	fee_transfer	15	9998000000	5Jv6mRx6LtZ4Gwy7u1UUsGSBEcQ8Swb811CngcztNJ56SQpYd6to
51	fee_transfer	113	9998000000	5Jtf1X7VvNBsdMs4xcTWCnzXLWPXRUMT8tCYnq9D9jMaQLrbmQqX
52	fee_transfer	15	24994000000	5JuzVwebs3JuJVS3res1SwR88HTqBgoFKuQ7xg7bFJA7yLeeuJK7
53	fee_transfer	113	49989000000	5JuV3acPub14LnF1mfMnrtpiEohLTjZTmRhoXXVKAx59z3HjMeiB
54	fee_transfer	113	19995000000	5JuHNGRSbhRa5As29tj1WQ1obSMATgkm6pBaexrzjuoPz8rSh5pv
55	fee_transfer	15	29996000000	5JtezNP9aEajRApLA7TmN79AkjYGm47ehhyioFRmWUE1tZsG394G
56	fee_transfer	15	91250000000	5JtzKJkt4RaJ26DCGLav9915kRAVDzZ9Qjqs18gWLoVzA436bDuz
57	fee_transfer	113	29996000000	5JtrU7xWymbA9xcsagL6RMUcc34bYdtHnhfY2xLew2VYYprM7pGE
58	fee_transfer	113	91250000000	5Ju2rChu94ZSm5cnf33etnz9Y78mrh4Ts5Z81ghburxAFv8VZckc
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
15	B62qr7HhRDB6Me7FFXme5MFcoqRa452etDR4mNgT9Zi6U73R238ytmz
16	B62qkaFHyAx1TMzuez3APX1hG33j2ZXCTXJFFzeSxgt8fA3henaeT84
17	B62qkCd6ftXqh39xPVb7qyJkSWZYa12QCsxFCaCmDrvfZoTNYmKQtkC
18	B62qrEWSxSXzp8QLDpvuJKeHWxybsE2iwaMPViMpdjptmUxQbtDV178
19	B62qnUCyUPAGE9ZXcu2TpkqUPaU3fhgzxRSEiyt5C8V7mcgNNvj1oc9
20	B62qiquMTUSJa6qqyd3hY2PjkxiUqgPEN2NXYhP56SqwhJoBsFfEF5T
21	B62qm174LzHrFzjwo3jRXst9LGSYjY3gLiCzniUkVDMW912gLBw63iZ
22	B62qrrLFhpise34oGcCsDZMSqZJmy9X6q7DsJ4gSAFSEAJakdwvPbVe
23	B62qo11BPUzNFEuVeskPRhXHYa3yzf2WoGjdZ2hmeBT9RmgFoaLE34A
24	B62qmSTojN3aDbB311Vxc1MwbkdLJ4NCau8d6ZURTuX9Z57RyBxWgZX
25	B62qiaEMrWiYdK7LcJ2ScdMyG8LzUxi7yaw17XvBD34on7UKfhAkRML
26	B62qoGEe4SECC5FouayhJM3BG1qP6kQLzp3W9Q2eYWQyKu5Y1CcSAy1
27	B62qn8rXK3r2GRDEnRQEgyQY6pax17ZZ9kiFNbQoNncMdtmiVGnNc8Y
28	B62qnjQ1xe7MS6R51vWE1qbG6QXi2xQtbEQxD3JQ4wQHXw3H9aKRPsA
29	B62qmzatbnJ4ErusAasA4c7jcuqoSHyte5ZDiLvkxnmB1sZDkabKua3
30	B62qrS1Ry5qJ6bQm2x7zk7WLidjWpShRig9KDAViM1A3viuv1GyH2q3
31	B62qqSTnNqUFqyXzH2SUzHrW3rt5sJKLv1JH1sgPnMM6mpePtfu7tTg
32	B62qkLh5vbFwcq4zs8d2tYynGYoxLVK5iP39WZHbTsqZCJdwMsme1nr
33	B62qiqUe1zktgV9SEmseUCL3tkf7aosu8F8HPZPQq8KDjqt3yc7yet8
34	B62qkNP2GF9j8DQUbpLoGKQXBYnBiP7jqNLoiNUguvebfCGSyCZWXrq
35	B62qr4z6pyzZvdfrDi33Ck7PnPe3wddZVaa7DYzWHUGivigyy9zEfPh
36	B62qov6t5ahQQMdoanV8tgeS8ddpqsL5MCntfh8qzr1aNqGsgnhhvV5
37	B62qiWZKC4ff7RKQggVKcxAy9xrc1yHaXPLJjxcUtjiaDKY4GDmAtCP
38	B62qqCpCJ7Lx7WuKCDSPQWYZzRWdVGHndW4jNARZ8C9JB4M5osqYnvw
39	B62qo9mUWwGSjKLpEpgm5Yuw5qTXRi9YNvo5prdB7PXMhGN6jeVmuKS
40	B62qpRvBE7SFJWG38WhDrSHsm3LXMAhdiXXeLkDqtGxhfexCNh4RPqZ
41	B62qoScK9pW5SBdJeMZagwkfqWfvKAKc6pgPFrP72CNktbGKzVUdRs3
42	B62qkT8tFTiFfZqPmehQMCT1SRRGon6MyUBVXYS3q9hPPJhusxHLi9L
43	B62qiw7Qam1FnvUHV4JYwffCf2mjcuz2s5F3LK9TBa5e4Vhh7gq2um1
44	B62qrncSq9df3SnHmSjFsk13W7PmQE5ujZb7TGnXggawp3SLb1zbuRR
45	B62qip9dMNE7fjTVpB7n2MCJhDw89YYKd9hMsXmKZ5cYuVzLrsS46ZG
46	B62qmMc2ec1D4V78sHZzhdfBA979SxUFGKTqHyYcKexgv2zJn6MUghv
47	B62qqmQhJaEqxcggMG9GepiXrY1j4WgerXXb2NwkmABwrkhRK671sSn
48	B62qp7yamrqYvcAv3jJ4RuwdvWnb8zFGfXchbfqR4BCkeub998mVJ3j
49	B62qk7NGhMEpPAwdwfqnxCbAuCm1qawX4YXh956nanhkfDdzZ4vZ91g
50	B62qnUPwKuUQZcNFnr5L5S5mpH9zcKDdi2FsKnAGQ1Vrd3F4HcH724A
51	B62qqMV93QdKFLmPnqvzaBE8T2jY38HVch4JW5xZr4kNHNYr1VtSUn8
52	B62qmtQmCLX8msSHASDTzNtXq81XQoNtLz6CUMhFeueMbJoQaYbyPCi
53	B62qp2Jgs8ChRsQSh93cL2SuDN8Umqp6GtDd9Ng7gpkxgw3Z9WXduAw
54	B62qo131ZAwzBd3mhd2GjTf3SjuNqdieDifuYqnCGkwRrD3VvHLM2N1
55	B62qo9XsygkAARYLKi5jHwXjPNxZaf537CVp88npjrUpaEHypF6TGLj
56	B62qnG8dAvhGtPGuAQkwUqcwpiAT9pNjQ7iCjpYw5k2UT3UZTFgDJW1
57	B62qj3u5Ensdc611cJpcmNKq1ddiQ63Xa8L2DnFqEBgNqBCAqVALeAK
58	B62qjw1BdYXp74JQGoeyZ7bWtnsPPd4iCxBzfUsiVjmQPLk8984dV9D
59	B62qpP2xUscwDA5TaQee71MGvU7dYXiTHffdL4ndRGktHBcj6fwqDcE
60	B62qo1he9m5vqVfbU26ZRqSdyWvkVURLxJZLLwPdu1oRAp3E7rCvyxk
61	B62qjzHRw1dhwS1NCWDH64yzovyxsbrvqBW846BRCaWmyJyoufddBSA
62	B62qkoANXg95uVHwpLAiQsT1PaGxuXBcrBzdjMgN3mP5WJxiE1uYcG9
63	B62qnzk698yW9rmyeC8mLCKhdmQZa2TRCG5hN3Z5NovZZqE1oou7Upc
64	B62qrQDYA9DvUNdgU87xp64MsQm3MxBeDRNuhuwwQ3hfS5sJhchipzu
65	B62qnSKLuJiF1gNnCEDHJeWFKPbYLKjXqz18pnLGE2pUq7PBYnU4h95
66	B62qk8onaP8h1VYVbJkQQ8kKtHszsA12Haw3ts5jm4AkpvNDkhUtKBH
67	B62qnbQoJyaGKvgRDthSPwWZPrYiYCpqeYoHhJ9415r1ws6DecWa8h9
68	B62qmpV1DwQvBMUmBxyDV6jJwSpS1zFWHHEZYuXYhPja4RWCbYG3Hv1
69	B62qiYSHjqf77rS6eBiBSiDwgqpsZEUf8KZZNmpxzULpxqm58u49m7M
70	B62qrULyp6Kp5PAmtJMHcRngmHyU2t9DF2oBpU4Q1GMvfrgsUBVUSm8
71	B62qpitzPa3MB2eqJucswcwQrN3ayxTTKNMWLW7SwsvjjR4kTpC57Cr
72	B62qpSfoFPJPXvyUwXWGJqTVya4kqThCH5LyEsdKrmqRm1mvDrgsz1V
73	B62qk9uVP24E5fE5x4FxnFxz17TBAZ4rrkmRDErheEZnVyFmCKvdBMH
74	B62qjeNbQNefZdv388wHg9ancPdFBw6Dj2Wxo6Jyw2EhR7J9kti48qx
75	B62qqwCS1S72xt9VPD6C6FjJkdwDghRCWJnYjebCagX8M2xzthqKDQC
76	B62qrGWHg32ZdFydA4UF7prU4zm3UH3dRxJZ5xAHW1QtNhgzuP2G62z
77	B62qkqZ1b8BkCK9PqWnQLjYueExVUVJon1Nn15SnZScG5AR3LqkEqzY
78	B62qkQ9tPTmzm9oD2i8HbDRERFBHvG7Mi3dz6XLa3BEJcwA4ZcQaDa8
79	B62qnt4FQxWNcP49W5HaQNEe5Q1KqTBQJnnyqn7KyvSfNb6Dskbhy9i
80	B62qoxTxNh4o9ftUHSRatjTQagToJy7pW1zh7zZdyFYr9ECNDvugmyx
81	B62qrPuf95oqANBTTmvcvM1BKkBNrsmaXnaNpHGJYersezYTHWq5BTh
82	B62qkBdApDjoUj9Lckf4Bg7fWJSzSnyJHyCNkvq7XsPVzWk97BeGkae
83	B62qs23tCNy7qbrYHBwMfVNyiA82aA7xtWKh3QkFr1fMog3ptyXhptq
84	B62qpMFwmJ6fMm4cUb9wLLwoKRPFpYUJQmYqDe7RRaXgvAHjJpnEz3f
85	B62qkF4qisEVJ3WBdxcWoianq4YLaYXw89yJRzc7cPRu2ujXqp4v8Ji
86	B62qmFcUZJgxBQpTxnQHjyHWdprnsmRDiTZe6NiMNF9drGTM8hh1tZf
87	B62qo4Pc6HKhbc55RZuPrDfzbVZfxDqxkG3hV7sRDSivAthXAjtWaGg
88	B62qoKioA9hueF4xhZszsACn6GT7o69wZZJUoErVyvgP7WPrj92e9Tv
89	B62qkoTczRzwCUr6AmSiNcr3UWwkgbWeihVZphwP8CEuiDzrNHvunTX
90	B62qpGkYNpBS3MBgortSQuwV1aXcK6bRRQyYz3wGW5tCpCLdvxk8J6q
91	B62qnYfsf8P7B7UYcjN9bwL7HPpNrAJh7fG5zqWvZnSsaQJP2Z1qD84
92	B62qpAwcFY3oTy2oFUEc3gB4x879CvPqHUqHqjT3PiGxggroaUYHxkm
93	B62qib1VQVfLQeCW6oAKEX2GRuvXjYaX2Lw9qqjkBPAvdshHPyJXVMv
94	B62qm5TQe1nz3gfHqb6S4FE7FWV92AaKzUuAyNSDNeNJYgND35JaK8w
95	B62qrmfQsKRd5pwg1EZNYXSmcbsgCekCkJAxxJcZhWyX7ChfExZtFAj
96	B62qitvFhawB29DGkGv9NEfGZ8d9hECEKnKMHAvtULVATdw5epPS2s6
97	B62qo81kkuqxFZw9cZAcoYb4ZeCjY9HodT3yDkh8Zxhg9omfRexyNAz
98	B62qmeDPPUDtPVVHqesiKD7ecz6YZvGDHzVw2swBa84EGs5NBKpGK4H
99	B62qqwLQXBrhJmfAtF7GUf7FNVS2xoTPrkyw7d4Pj9W431bpysAdr3V
100	B62qkgcEQJ9qhjwQgt2XeN3RJpPTfjCrqFUUAW2NsVpzmyQwFbekNMM
101	B62qnAotEqbcE8sjbdyJkkvKnTzW3BCPaL5HrMEdHa4pVnfPBXWGXXW
102	B62qquzjE4bbK3mhk6jtFMnkm9BdzasTHuvMxx6JmhXeYKZkPbyZUry
103	B62qrj3VHfVadkyJCvmu7SvczS7QZy1Yk1uQjcjwkS4QqDt9oqi4eWf
104	B62qn6fTLLatKHi4aCX7p6Lg5rzZSq6VK2vrFVgX14gjaQqay8zHfsJ
105	B62qjrBApNy5mx6biRzL5AfRrDEarq3kv9Zcf5LcUR6iKAX9ve5vvud
106	B62qkdysBPreF3ef7bFEwCghYjbywFgumUHXYKDrBkUB89KgisAFGSV
107	B62qmRjcL489UysBEnabin5be824q7ok4VjyssKNutPq3YceMRSW4gi
108	B62qo3TjT6pu6i7UT8w39UVQc2Ljg8K69eng55vu5itof3Ma3qwcgZF
109	B62qpXFq7VJG6Spy7BSYjqSC1GBwKLCzfU8bcrUrALEFEXphpvjn3bG
110	B62qmYXqVz13eCpiHEEbvkWDU7jQAwfuf6zv4HLfiRthmLMZMQDXLPi
111	B62qmp2xXJyj9LegRQUtFMCCGV3DQu337n6s6BK8a2kaYrMf1MmZHkT
112	B62qkXPw6LbqeY3kaEYHrc6MeP6Wi7wcDc5fzbegn5yRoj2UvyCoe7M
113	B62qmQsYKF97qxFVUuwHdmJySUM6F6qNnNYvxfrvYDPdLPzBspCPYLS
114	B62qpjkSafKdAeCBh6PV6ZizJjtfs3v1DuXu1WowkYq2Bcr5X7bmk7G
115	B62qnjhGUFX636v8HyJsYKUkAS5ms58q9C9GtwNvPbMzMVy7FmRNhLG
116	B62qoCS2htWnx3g8gFq2ypSLHMW1jkZF6XMTH8yKE8gYTH7jfrcdjCo
117	B62qk2wpLtL3PUEQZBYPeabiXcZi6yzbVimciFWZSCHpxufKFDTmhi6
118	B62qjWRcn5eRmdppcsDNudiogbnNPzW4jWC6XH2LczMRDXzjK9AgfA2
119	B62qjJrgSK4wa3HnZZqmfJzxtMfACK9r2zEHqo5Rm6UUvyFrk4UjdPW
120	B62qoq6uA96gWVYBDtMQLZC5hB4hgAVojbuhw9Z2CE1Acj6iESSS1cE
121	B62qkSpe1P6FgwWU3BfvU2FXnuYt2vR4DzsEZf5TbJynBgyZy7W9yyE
122	B62qr225GCSVzAGKBYxB7rKE6ibtQAcfcXMfYH84hvkqHWAnFzWR4RT
123	B62qkQT9sAztAWnYdxQMaQSxrA93DRa5f8LxWCEzYA3Y3tewDQKUMyQ
124	B62qieyc3j9pYR6aA8DC1rhoUNRiPacx1ij6qW534VwTtuk8rF2UBrk
125	B62qoFyzjU4pC3mFgUidmTFt9YBnHjke5SU6jcNe7vVcvvoj4CCXYJf
126	B62qihY3kUVYcMk965RMKfEAYRwgh9ATLBWDiTzivneCmeEahgWTE58
127	B62qm8kJSo4SZt7zmNP29aYAUqETjPq6ge2hj5TxZWxWK2JDscQtx1Y
128	B62qkY3LksqsR2ETeNmAHAmYxi7mZXsoSgGMEMujrPtXQjRwxe5Bmdn
129	B62qrJ9hFcVQ4sjveJpQUsXZenisBnXKVzDdPntw48PYXxP17DNdKg4
130	B62qpKCYLZz2Eyb9vFfaVPgWjTWf1p3VpBLnQSSme2RC3ob4m1p8fCv
131	B62qkFYQghamWpPuNxzr1zw6ARk1mKFwkdQWJqHvmxdM95d45AjwWXE
132	B62qnzhgbY3HD19eKMeQTFPZijFTvJN82pHeGYQ2xM9HxZRPv6xhtqe
133	B62qroho2SKx4wignPPRf2qPbGzvfRgQf4zCMioxnmwKyLZCg3reYPc
134	B62qm4jN36Cwbtyd8j3BLevPK7Yhpv8KtWTia5fuwMAyvcHLCosU4PN
135	B62qk9Dk1rwSVtSLCYdWNfPTXRPDWPPu3rR5sqvrawP82m9P1LhBZ94
136	B62qnR8RErysAmsLHk6E7teSg56Dr3RyF6qWycyVjQhoQCVC9GfQqhD
137	B62qo7XmFPKML7WfgUe9FvCMUrMihfapBPeCJh9Yxfka7zUwy1nNDCY
138	B62qqZw4bXrb8PCxvEvRJ9DPASPPaHyoAWXw1avG7mEjnkFy7jGLz1i
139	B62qkFKcfRwVgdQ1UDhhCoExwsMPNWFJStxnDtJ1hNVmLzzGsyCRLuo
140	B62qofSbCaTfL61ZybYEpAeGe14TK8wNN8VFDV8uUEVBGpqVDAxYePK
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
170	B62qpXKjMPqNsUBPeAGhpjao8BE8FqdYdk8zS2RwxaEBadByS3nbfD1
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
206	B62qo5raDfFWM6oaooevrgMxMXmp3NnxMGbus3yubqaexzNodKDmock
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
243	B62qnKA96mXta3xWx3wUQR9rPsHcBU4twjyCbA5dnEebh78aar7vSbr
\.


--
-- Data for Name: snarked_ledger_hashes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.snarked_ledger_hashes (id, value) FROM stdin;
1	jwovXkYDcnbjEh8einaQhw2ZXkpv8fEKJDkHfVtNBRWACbNyBMa
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
1	payment	36	36	36	0	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JunBsG2pFzbNGMBJGhjcUgGATZFu7JaazrQuudkRx1fmUXqA7QW
2	payment	36	36	36	1	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JugYzrr18rpiWb67HxPa6F9XPqnabypLmsVFM2k69pCNA8THeiE
3	payment	36	36	36	2	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JunzsremAnZudTrGb3xyXL3hVUKc99YALZkFBjGiwafLhiFeqqq
4	payment	36	36	36	3	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvFdA3Q9fhNHQnHZusLyGAikXzFsQB1Yx97LfBSERk9XaKHRqWT
5	payment	36	36	36	4	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuhEjxMPbQrxwVi8vMMCKoLa3A1dWnpjrS6NaativYvSCVi3Kb5
6	payment	36	36	36	5	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuGg2NX4EpW3JgfdvgKcsVSerBixoPj3CUVNd6Ge4GQ3fkyT71v
7	payment	36	36	36	6	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtZYK5xFycop4Dvgmcwb1DASwNk2FqfBGtfTEaVh1ywHtUX6ymS
8	payment	36	36	36	7	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv6kisopTDVmRLmHAA86Wf8NmocHLZhCRv8PReadRwaDtpP61bc
9	payment	36	36	36	8	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuX6UiPZCcXqVGKNT7XtcMWC3ruAh1y7JzvNtt3qoQsGQe2ppRM
10	payment	36	36	36	9	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuM5z6oQbQPjNP4Trn3picwtPP8cZ7mw7B9yGkdjAeTe5pfnPMJ
11	payment	36	36	36	10	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JupR2A8EwuiMH5SKjSb2mgsfNxG4dRWyv6xx7SqQnN3nh953D1o
12	payment	36	36	36	11	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv3E86nsEDWMZGyPoQZUmNhjiLWCQjBRiKsL41uRRu7ujVzU6Ha
13	payment	36	36	36	12	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtzyQVeE24B2yYRNeuSLyMeHcvZr8kJKgSKC7eLZkD3Y4XZrniB
14	payment	36	36	36	13	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtiqNmPE45WUXXYtYvetFLjG58Hip4ERCdyinRoGbh9ef4M3wuo
15	payment	36	36	36	14	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juh8njDT8hWxqvyAoJMQVzBJuVSoQJozZtck8dwxR8DiR8n5mxg
16	payment	36	36	36	15	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvQTqRYH84QYn91gdpgTYsUFgw18b2vSAFuXr2b1eKRpKzBb1rR
17	payment	36	36	36	16	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JusqyT2K5MsfKeofcR4KjGLdzEVpfpa4j13WYHRoVCo71KNziAu
18	payment	36	36	36	17	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvBHiwRZhfMf5BALF7xefA8tCHZNXqFFUmSkGtX3Bg4jnY2MAeD
19	payment	36	36	36	18	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuvAS6WoPGxHtPQsfGVhRXTyskabm1ggaUp7n3SYsUcJhoeTBYR
20	payment	36	36	36	19	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvL1xigkLbvJBVfSA3Uwnazwo6xUMjx2WHtL9wGzCr28zV1au9c
21	payment	36	36	36	20	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuBQunMneBisrpxcds58np1NVSbVyRxho9egsGsohBaVtbxGcaD
22	payment	36	36	36	21	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju5XbTMALzabYTSZsNt9jgcMYfZ9prhZ3wmPoXeyAJMLuTfgJfH
23	payment	36	36	36	22	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JukuhGL1842M412iTJQFTjeL564zTpoXvTMJANcJKgarpQgm53M
24	payment	36	36	36	23	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvEp8jYFgteCq4ZXCjicCfX8KPH2ChDknUraU5bJBa9Q71WC8Eh
25	payment	36	36	36	24	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuytQUk6BkToq6HU95hKvL6vM1CGDj24nQC3H5BUkMwXQphqrjq
26	payment	36	36	36	25	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuwDcg19QWn7gGE4WU9isGHgDowvQ3ahQ7cHYVvjqT1Hwg4McVK
27	payment	36	36	36	26	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv1BmzjFVcL4XRowg8p59TERoHdjoUAjgd8hF2hexZYGJjFdgjE
28	payment	36	36	36	27	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtXm1Qte6C1XGpKbnTp13rXPUUzWWdWeqR3EnuEcQXFTkdUg1LP
29	payment	36	36	36	28	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuFY6VCSeBkMQ4UfMZSonmEDg6CvNVLy6ZCdaXuyZfR9bSm7zX8
30	payment	36	36	36	29	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuxJomCiN1CTUpKyZBHy1cbbP6ahRrtWrSoKzKtJwEZLfchveL4
31	payment	36	36	36	30	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvEx1ou8p6ViGzE5RpTFEfbXUW6TruJJuCcjzXSjDVVv5fPR2Mz
32	payment	36	36	36	31	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtbaiMVo5AndAKML4GsZcubJi5wrYokArN317yh6swwjLHFVFpr
33	payment	36	36	36	32	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtceNVpCw2ww2CnEPki2HqDJWAxz9UyH7vFujDQh9iK791XpDCG
34	payment	36	36	36	33	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtpdngymF2fSPJd6egmQZYzvSJdRa1jpTpWqXwEDBw7D2pEk75E
35	payment	36	36	36	34	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju27jNYBopiBPDvSkcrgbFVSz8ttzYmZerxjonzcRzUH9SxXe5a
36	payment	36	36	36	35	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtz8RPAX9QkSmFmzRRiWKwCRXZdNW53bBPmss7XtmENNo8bvrLL
37	payment	36	36	36	36	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju5Wpi9sM5yyxtX4nuDXy9v4r5KXq3ghqnVgsR2mfCQRvvhGNqu
38	payment	36	36	36	37	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtw87iuecZazT1B9gvnxuHEXnTAQycJWmJPJxfGqFDNGFh3d5ZZ
39	payment	36	36	36	38	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jukkg21wMLgGtescAAiWfZW7XzQGKQLwNhysYuYT36GrkpZPaTw
40	payment	36	36	36	39	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtfGftvmXxstssYHZ91VfQNgmJZgvPFmG639kjonicQJzP5BJTH
41	payment	36	36	36	40	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JueiSMDGQT6Zf3GGEQrLh9pD5nvZ2jFjyJMzJJ14cBJKvnxvG77
42	payment	36	36	36	41	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvE3iMMvNeEvEx3rcukwFc6zf4nGNBXpJnuvV9ER6ByrzmkjCTj
43	payment	36	36	36	42	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juiacf5UrNbjBvXRyxcWMm9UPykryL2Agrs3X11dFf1uUmFV5GM
44	payment	36	36	36	43	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju6xTiuwCguVeQimNjkv9e15qvWS2ic3g9huB9bCa16up5JXw7J
45	payment	36	36	36	44	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju6z1gLNjaAdMCypQQzjxrjd5X1gVqLeWWkdCeoTHyHfUpbG7cc
46	payment	36	36	36	45	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv4udUHt4EN8kYzERRjBYZiCESrXmdu1ZFJCfA7PhJuVsN7hT5T
47	payment	36	36	36	46	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtbwu5sEXZ6uj7Duu6MgT5LGr4YRsHAoXxMPn9M8o34hewGd2kJ
48	payment	36	36	36	47	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuLaXabQ7UPxuUwRmJSay2bDf4qEtzdkzivhk55S39ZazHE7bMY
49	payment	36	36	36	48	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JufWopZhdQsBFbRMKHHhu2zEGz7neM9tiu6UB3HmxYqZDFR3LKm
50	payment	36	36	36	49	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvFjwUMfavgziYCgwJnnrBLCfJY62MdGcQrdLzv5mBY3A4tpXFC
51	payment	36	36	36	50	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuiPJYTqSQsWBwx9xhJLJWUF3c6tHBVVStqECTfMEB2fnW1zBfn
52	payment	36	36	36	51	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvBumh8vh8AidRv2MFovKqZjpGDZeKqn18y776qvLTchETYqyw5
53	payment	36	36	36	52	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvAjEaY5CdUHDXBFm96cUF6ZkeXXAXPqiP8Bzet5FRs26yE7wKr
54	payment	36	36	36	53	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv1jWLib2ECd58ySkwFr2Z3E3gBSogbhFwKoWZdbnFFU8Cv9S1L
55	payment	36	36	36	54	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv2iQBgAuFtaezMTmb8WQeWifmDWGHyKnFfEpDwTgXG8ieUDq8b
56	payment	36	36	36	55	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuJPTUGDXNReBVxtW9w1UqTJf2kC5vkGjMeC3XM2BLhLBLSL4Vg
57	payment	36	36	36	56	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtsuKpHcmduTDrueZ8jgbdazwt4E7c6QxEMt41i4iSesQmW9622
58	payment	36	36	36	57	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuQEqe4tJ894WVopXPiErK8USXTQNaZppCSGtmhbd9iSaNXUB4D
59	payment	36	36	36	58	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvKmuondXMj98UogbspnQ61MWuFzMNAiYVCoJFWCsvQ2pN5EqgC
60	payment	36	36	36	59	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvGgoRtAaV44a69FebLHfv6ALfWcMxX5q27BHPBZrwgoF8D6oGg
61	payment	36	36	36	60	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtjgedc2aZG4fDNbzvte3VQvutBnPBfSn33NkYc9mcaYoZiYGHK
62	payment	36	36	36	61	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv9bwJpTgGXLE6BXgWHGAwTdpa7HcuyY3JAWp7wTkoZAc5SY7ob
63	payment	36	36	36	62	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuiXQEj99SJj9dTjEeuERSx7MhzBLzzpcr9WHWpymnGfts7Dnf7
64	payment	36	36	36	63	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JudNMyUvX3ogxPHqNgScroiSBDACk6kSGatPuoPLifQ2naE2AMC
65	payment	36	36	36	64	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JthY2wmxDcHX77i7DwbkUTFMYG5KfWQNxd3EXYc5B6e4rMG7iXV
66	payment	36	36	36	65	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtfBaXSEh5JM5fbvGFdVmyP2s86Rt68KCJbk1wy77PpqwEFEGaq
67	payment	36	36	36	66	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvFstzeViccM4Xw91SiNHiUewcQjsPTNMeBUrT5vm6k7pbEesw9
68	payment	36	36	36	67	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuiUh6UsXBfNF1xHkiS4tKGAiZwZuy9KvKWGGogUFghruTs1xXn
69	payment	36	36	36	68	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtn86jxdDGoAZnoGXc8BPVhywZgQNgXUNvADCEiiUQtvFvGsRmk
70	payment	36	36	36	69	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvRGwjN1BSMVgL6trU6C2vLVSC8Y4UFxjZZ9CWFz7bcyHB2vXqw
71	payment	36	36	36	70	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuvEqaihm6aLhEi6mEGznz5T8v176ZRGejiQX57yU78WqDYK7XF
72	payment	36	36	36	71	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JusbN4mTbkrSN4iPVpSbUjGDKdt3qkTKMgyrxsKzNKPXM1zmbzX
73	payment	36	36	36	72	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuLhHr24YUZ4BBkXAv7jssEbGSokC39NZJgnYJfRzw1h1oFummp
74	payment	36	36	36	73	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JusafubJs9B5dYmRrAWGTkmHTC8ED4RgZin9CFzxm3CgcTNpeaw
75	payment	36	36	36	74	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuNgK3XNhECydnwoWHgRdLxncx8g57h2r4bQWUVjV5Jc35QiHKz
76	payment	36	36	36	75	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtsYiBuPSt45VCG78VMkrvjoQUTVcmxAytF5ASge6A9bM2kC7S8
77	payment	36	36	36	76	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtzKSXiG6HTbqdFcX3DPVp8gumskNaroPCfDRHt58Q11MSGUoGE
78	payment	36	36	36	77	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juh87HJDx2JYjCFYea9uVkXNu8P75RPKxHLkUEt86o8Rx5QVYyx
79	payment	36	36	36	78	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuMcRMdaWAdpPPKXMQCjkr3x4sd4j154LFYdkHiSpXNAaQnar2c
80	payment	36	36	36	79	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtoo9P9WiuGaPVUNzu1r7cRdbvFbfh4vY3qML2gjWW8CdPwFGRH
81	payment	36	36	36	80	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvBssLZrXUbZ2V3ay6XYNb7Qebvf4PZMr53j7MUNsJYcP2GXVae
82	payment	36	36	36	81	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju66Fq52A9mEfxABGhJjkEWRP8SHmv43vmL1NkRxDBCkFpX2qtD
83	payment	36	36	36	82	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtwjbMRVorAuQr2KxSQcmGCdVvDk9sWYVDTpgp7aXk3JruyjTEG
84	payment	36	36	36	83	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuympdJm9wp8LYPyPk6Scu77Ud2LHYb4QyaMQnyEUb7cd1ie6Uz
85	payment	36	36	36	84	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju68CDvFuEjVDQSR5Tc1Z6nWsEKuY1tXjgBG2oUyxYvezvN8uap
86	payment	36	36	36	85	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuxpJBhEF4mRDqpsFVf2hq9BrbBfeH7VNK87ex5PQxCdy28CyH2
87	payment	36	36	36	86	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju8Towr5MS9rcb2a97tn2TZdDJKZ5UgLKwnZcH4xTJonAWaSKM6
88	payment	36	36	36	87	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtZkrva1o4XkZnrsvmNVvGBdVLaPgWVxE6zCPgt3ELmMcYR3xJ2
89	payment	36	36	36	88	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuhT49KKce9sAzUhoufbykWx6WqNHd9xDJz8abc3CiiMQ92bsed
90	payment	36	36	36	89	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv72NbPeXS1RXNwDgmiTrz7tMvMXDkWVjN66LiejwqWV5WXwNno
91	payment	36	36	36	90	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtvh42xNJeh6wRXZdppTQW3PaCYXHMsdRvezvDqDVUaZqv6ngqE
92	payment	36	36	36	91	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juh9BqnnwyiDgug2HcRPBcP1mY3X35Ps5eJ2Urkvwdq7XJpxUVN
93	payment	36	36	36	92	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuhTooTWEzGkgLdPLSVfeYE1iYwMuoxz9NYgaRufKuLYMZRo6Bo
94	payment	36	36	36	93	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuZSUnhbznFLZZ65E8wGSH6bczgHuNBx3ZDkQ637iNKAYgv54W7
95	payment	36	36	36	94	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JttzLj8nqyCMgbAWQ9VMA7EmeRUc6HUkRQHK2TTFaZpRbtha7KH
96	payment	36	36	36	95	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvD4CZS23WCEUsS6abXRqTtURGQ6P8P7wwG9ii6QvjQHzR4cRJ1
97	payment	36	36	36	96	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtwFVVTA8JWme5tMwJMaZZTHYkCksWq3N1ELhYpGTtqvJedM9tG
98	payment	36	36	36	97	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuRUR5zVZPqUCxboA56Y9f46C9Bn8TfUuEBfZmt6NWtTqZ9k851
99	payment	36	36	36	98	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju7FqAsAjmKHJFgaVyE4ibEpY9mDjwFagEPtjC49k1zwarUy6NT
100	payment	36	36	36	99	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuEM5ALMptw2zkRFMAU14oi6ZJoLNGwBnJJwcyX6ioN586UbcSH
101	payment	36	36	36	100	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuCn3Txc1KWJF6aATbbgYXHibq1vT5pfrnU59yGPh6sSyeHoedZ
102	payment	36	36	36	101	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtm4aJKU23ZE4JtUDM2eCGCAQLiN8FLMAnmgUtS8K8JEwM66Jwi
103	payment	36	36	36	102	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuitxxCnqqETcLxa5PpF1DY24FE15mnNn5he41sttcFJQtGMc2M
104	payment	36	36	36	103	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuSE6ji4HmYF58EP4Fv5HvMmmAoPvbYuTg7p7g9gK4gPxDCSHqH
105	payment	36	36	36	104	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvJiaY5vFWFMSTqnRj5Wc5jfSUSEHpDwfnV5sVCA8jPJGc2v5jt
106	payment	36	36	36	105	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtyaRJQjuMFC2BCG5aqDARyEeknB4m1ydrMiJd2A87YVDAQ9HvY
107	payment	36	36	36	106	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtpFQeAuwY33GAJWFaXei8JjjcA8LBFs5DJRuPEKaUeusdMzSjg
108	payment	36	36	36	107	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvCP5xHeBReuBKndiLcmoqQzXxWKqxFagi8t4NTkzti3yiLkhgR
109	payment	36	36	36	108	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtqxU3tQcGUAyNdME2tubdt3yjnr54EVzKmpiJaR9Xp7bDm8uDs
110	payment	36	36	36	109	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju6XcAFLZVSL4XydZAKX3RNqgUNMJBerR39Pac6P788xrXYPGie
111	payment	36	36	36	110	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvAonZsGMraswjTAc2MEY735SwJtPZ6rQcj9T3KkznFxnbz2rxQ
112	payment	36	36	36	111	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtxRhqhXjuTyB936GCMwzomHjfMen2jKmqk7Nf6XNwcFzTUPaKS
113	payment	36	36	36	112	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvLVRDubcjwhuYNa31EgKsohkRWWXgDHxPsoVJeJBSFpctdQq5B
114	payment	36	36	36	113	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvMXV3o9T7CVXWefSNAUhCDMMWVkUYaLn5W9p7aYMmFCwyr6BXq
115	payment	36	36	36	114	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtwU6SwBxc9PpfyLiTxf9xJG4udVeAQCof8BXdEVSqWfwdHhoT7
116	payment	36	36	36	115	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvKiqhhC7V1gxPodp7sUKyRug7LKQJRgp2ZWCFiB8YReGifYFWg
117	payment	36	36	36	116	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtsnMpGgTkMHomzWbpdeEoddGSX3zNpcEXWCTam6jiXxyhgfUk3
118	payment	36	36	36	117	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju3U59D53uysvxVUyAwn58YBDirqCJuWhRNj6tyJUQaJ5w3aUT9
119	payment	36	36	36	118	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv3kZkykSeBGpwohucYNmDAMqXsApt3UsSCKeptMZhEMb6ZKLFQ
120	payment	36	36	36	119	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jurxfej5fGYkBKKMN4UddmYyWd4pYFPE6j6KadnMahFm5PRTXcX
121	payment	36	36	36	120	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JunSkwVbPxpQBAzUEfu6paP4jbRgBjDLuaawC7NJ96PC7D13jyq
122	payment	36	36	36	121	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvJXaV4RMcFko6y1DkZxCMarmzPZUEnAXQ8KdN18QnhCYRRRe4A
123	payment	36	36	36	122	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuiWGC36y4LpTt6WKjyjeAZbZL2DF3dGtXiSn8yfbxvTsM7qwjr
124	payment	36	36	36	123	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvBgepNvvkWWDgJ56Y2cLgyWqc65k5TQydD4a3muXtUHSNfdHhQ
125	payment	36	36	36	124	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvM4DfpsHkoxmdvGdB1HGG9YybSGWy5FDRzTbGkU2QpMNqCutsz
126	payment	36	36	36	125	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JupUqbMy9zuZ7ciKba5krpe7nTjFXgrPv1J8zQoyBr1ptHJRmJU
127	payment	36	36	36	126	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuK9K99JSApfbLGL3NqubUgQQAVe3HqPvTaKETa9FnjtKypdfwZ
128	payment	36	36	36	127	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JudNhmyrZ3ZPuPnuRMHYByAVaqCgKqGJgB4iDZ5oRNjkMYur2bX
129	payment	36	36	36	128	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuVuh2oSCP21Wr6gop4j5QjugiKz8QZW6aw17us6bYqJPuepckP
130	payment	36	36	36	129	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju2BYg5EmaQPrCYdPPHVXQzcJfpTfoKZMaNPuwJZ8CHbXPH2Ayn
131	payment	36	36	36	130	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv6c8nkC9La9twkZZPgjtEZ5j9nmdTKzJiBSX8NPgpKmN5Q7x18
132	payment	36	36	36	131	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvLymczXkGdAgTo9pxX1FXDoA95fqbQJXQHoo9NkYhWhtKbtrbk
133	payment	36	36	36	132	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju7azKF6TSVyPMFX7ow3pUm7BYxjVSKT2Z4j1F7EG6H29m5yT5c
134	payment	36	36	36	133	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtpz9anPiibVZix7jxZ2TULph4DPni7UsocFwWR6oSFfZYZ6K58
135	payment	36	36	36	134	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvEGdWcH4V3nBuM4XJzt6b2RVWobBbofd1owJ6bsMYZE2a8zn2q
136	payment	36	36	36	135	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuzUxfZzPvL2reTtWGogLxk2i9DiuRo8pc8oUQr9rJwMXnP7ofU
137	payment	36	36	36	136	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuB27XrgSzjg1L6PQ57EikCpXUpf5jwq2GTLamSDKq8pMvgDFNc
138	payment	36	36	36	137	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtnYTcytrrk4zVRo1TR48XfZQGfSvpqfwiYXFfbKTbG5MV1LNtJ
139	payment	36	36	36	138	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jttgq3KgXAL5paFcKL1BXSGCNic2Kso8Ue6WanSckGNnVYpSYB1
140	payment	36	36	36	139	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtgVnpqwYB4Q6ZV7w3muZDZA8VruJmmDSPDH2C4A5tYbmGMQLmP
141	payment	36	36	36	140	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jup79CrnceWFYXPB9jU5PywgNfKCWjvMWDjegfAawqw3LammyyQ
142	payment	36	36	36	141	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtjjS9CfQF89su9AGCoFVEsTkW49exuVKHBxGWRbC12ckRN1hai
143	payment	36	36	36	142	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuXqvSz3aorT5ccxBHFnDa7LkP5QJkPjbJzeMxmaVkKgpKxuDBN
144	payment	36	36	36	143	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtcXK7pm62F31wLp4ZSMSqAXXam388zQxEFL22j5Ln1Naosenzr
154	payment	36	36	36	153	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jug1XcQarkzbAAdBDyirH2Cd2QqQqxkCRuWdM2GAjizn6TCF68n
155	payment	36	36	36	154	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuBNHk9NR2gXJZitc2ig77mcTGxusabXoDSHh4rDPoEFFreXNtH
156	payment	36	36	36	155	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuKXzZUMs9vfNYyvxrFWhM2qAWDsH5tEJSMisGR8887VFzJrpFn
157	payment	36	36	36	156	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtdFxHmcpp7WtAPcVUPK4QynaVo54yGsPiz56MukQL7pjyXjUMC
158	payment	36	36	36	157	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtqZvUYPmpzb6V8STq5Nm2BJKx6euiuTQTa7UNxcNwonpEjbn8t
159	payment	36	36	36	158	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuEjUaBc1yNxizHdkzBGqsLexLeqB8pjpA57F6UHXcU2QFN6Tng
160	payment	36	36	36	159	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuBVXdvguH1FRyxAq9Qbion7j7AUZQ6VnoypiZC65KRcVX8WDXh
161	payment	36	36	36	160	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuNpsEWX6Z5FsyX3gUz8qvP8LLuFKyW8UrkXoCj544B6QzTcJGz
162	payment	36	36	36	161	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtrPva5pso2xvz3Rt98GYQVbrno7e4XBtu6zocY68CqTRbc4hn5
163	payment	36	36	36	162	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuCXXiUymWTSvz3gUum6M2KYvFyt532qjBA94f3Sxz1xNcaMBvX
164	payment	36	36	36	163	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvCWtJfWs87s59zeJAeE1SeVMNjAaLZ1yPWu8K8wSjjH4kNZ5nH
165	payment	36	36	36	164	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvBGvopEmfof9K5Yp44ecmX7jcg2rNJ8ipu6brquKjUL2CuKz9X
166	payment	36	36	36	165	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JueFfr4tpe3ZuuAeWkVmvgkhjzj724x5K28BynfjU1wyH7NySWy
167	payment	36	36	36	166	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JufkDqACU1qTwM9t5q5hntyYFxZqVU2pyKc1CXw99CfzpzQFxmq
168	payment	36	36	36	167	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuNeo8vwosptP6FKUnhS4kijchUwGADSVnyWsEJRx3eEBZpk8Nn
169	payment	36	36	36	168	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juq1ApcVGdozCSC54X4JPY45C8mBwXPjJX3ku87VdojDhPZe1NQ
170	payment	36	36	36	169	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvFP5y8oDtEXyDeoFG3n1733NMmrVFTiW9cvgQshRfjK2k9AgS2
171	payment	36	36	36	170	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju8rDn6JQzxmRjoqgu4D2gRmqUTyC5om6aWwqbJzxqgsufWjBAP
172	payment	36	36	36	171	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvR8ssWCtYaJwSCJyoSuY5QKcX8L7smG8LjE2U9iYRCH5Lsg5ah
173	payment	36	36	36	172	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvFmJYEm4GPdYEqSyqEb265fRqvjFzzDFiE7RUtxRmd8xtjq6zW
174	payment	36	36	36	173	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvP1GTzXro8izea66jYN5tCZP3gSQ6bUotnMUqu3j4ZfCY9t1J4
175	payment	36	36	36	174	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JumZEzpKzB1V7jQc37in2gf41rwfAT6BW2ZmjJ61g469kyJeXvM
176	payment	36	36	36	175	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv2vq1y9JYbPTuqAsp7iBbFXdJf7Fk2t8tm7f9h8X6UnSn3pHJf
177	payment	36	36	36	176	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv2TNwjh995V8a1RijG6KDxLgQsZdnMVkAJk1BSKjvtkHMu6oiv
178	payment	36	36	36	177	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtfVEaMSqdvo8YMWMxHczwYMVQfMjGHUmzaFDqAzaT483twqyQT
179	payment	36	36	36	178	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtXMGd4irDqJ5MWAeZ9GP5NRcFKasnak3FDMkVN3zmHyRHAZk7y
180	payment	36	36	36	179	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuZsGnLeRYh9Sq5ATM5VgN9tNEZfkTY8bZkaMC3SsZNSP7GyLhG
181	payment	36	36	36	180	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuSNDo32i2XP2oYrGdGTW7bxFYA4REFi4t5367TLpCstsbkVogn
182	payment	36	36	36	181	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JueJYfhU38oYb191QhXPnHSMHvCRNKyCZ1CJKdyqraykPwGMa7x
183	payment	36	36	36	182	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuoUnRe3MiGNsHvHueiddb8TVG5SqGszXMX2fFydoFx9keHXEo7
184	payment	36	36	36	183	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuF5zkuofAZzqMgFr44Rwu2yvVqqUL8j2W1yZqyzDNP1rzCkAGV
185	payment	36	36	36	184	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JusLWPJKJhGM9RBGNH6LchceSxz1L32529HPHBtro346wswUCET
186	payment	36	36	36	185	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtf8BBo3qdFjWaQ39XVM5mkPa9TogvNxSMdkMNjZF6VvwGP2NzN
187	payment	36	36	36	186	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtvbkNojTwPE2Hkfb3TR1H1b9etFB2QnCztFgAkpuQJVL8bx5MW
188	payment	36	36	36	187	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju8gaketQKv3XEtuv3Ui6h9DhLxwfCmhf4g5Hqe5Sad7PbPkTmc
189	payment	36	36	36	188	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuSvQqwzAguefzA1dJTGXogPrrpwCTJ4cyCkqXjiFT5jMXU3q9p
190	payment	36	36	36	189	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JttEH1BXWYvpDpXzx4iseHDeFoCwp5TCkdAuE7fkCyE9FmcWc9P
145	payment	36	36	36	144	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtqfc5XjFFdBTumNMABCBvyVxNtP5waNPPs7c5XdHAvF3ZroqUo
146	payment	36	36	36	145	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju8hWMenm3TVc4ayP3hmvz5wTakqY5tRhsr5fHS7GdusFZyWHfw
147	payment	36	36	36	146	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JucodLC5Dra1U9UuE35mFqPzLXZPHBGNRXSmd6a7ekwUJQ5aXCb
148	payment	36	36	36	147	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juz9gWEKuCozz4jWP2mwCjUKQ6CB8JXe48YWMPZkM64cuWupeSk
149	payment	36	36	36	148	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvRw3g4xf4hKmZxPwW2C3h15CiJURw9JrEiJi2NHpg7ayAoDejX
150	payment	36	36	36	149	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuEz8Z7iaPtq2PJkZ4eozUE35WPUkXRKiPKv62PD6zhAYgH2NPY
151	payment	36	36	36	150	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtk7kfY7qEA5C7Dyky2VQWow9LYWs5che7atdGC9bwU2Y1SB5cD
152	payment	36	36	36	151	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuQLqmfyTrGpBMf6qQ9buuYKkGK4ZZ1n86aS6WRNJJmtZTCEtzc
153	payment	36	36	36	152	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtu2UdFmfVjJVUqYVC3wnoeUcxymCnyeraDBSJZeQHHf9x9gxaK
191	payment	36	36	36	190	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuwskPLTvetWZBnDP3ns9Z1aP9VtGGsGSdiS4nQsCWn6MCwq2eQ
192	payment	36	36	36	191	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtXSo13eerNCiZ4JPvu3eBazbtUoyntMgzuDiMTX5GEjbUHWCUx
193	payment	36	36	36	192	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuzscbcxefMLS8B11J97mJEtbMfh4XnYyJdYjHryySPsC4g7t9V
194	payment	36	36	36	193	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtqmKspTAVwRt67rqJHHcGGCxcCLSxx4TcGSPkof5TEDrYLKFTL
195	payment	36	36	36	194	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuqAtnegnKVoEQ8ipdoYLDwnqc2AxyAQkQ7DroqNzS2VBbYq11R
196	payment	36	36	36	195	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuN9MhobG4oMkLdmLqp7TDjpknvS4zka7jxmcc5ksgW2ktMNAhB
197	payment	36	36	36	196	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtgF3UZCcjMyLmwiodFDzFRkqKKoDZ8sHnjjb9Zpi4avSH3WzmG
198	payment	36	36	36	197	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtYimHkKQ9DXv1qMSsUQVQKjh9eezJ8opF21ArXZ5jADF9gQWUU
199	payment	36	36	36	198	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtvwMPxyFUMD65rMHgK6jqCaFRqcS7seCb11Zb1bVtTgZn6Qc9o
200	payment	36	36	36	199	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvPPz6CV8UhoCLo3qe16Xn1SqsgpcMMrhtYViEYeEZwWpKFRR1X
201	payment	36	36	36	200	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuBuYt89a76s1SzVWjthF3VXpSxpqC3LP1XHU4bNVRj52E9kiMr
202	payment	36	36	36	201	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuVjo7FEN476qQ4XcsqPcdoUu1QPK5VAawzKn6ADfEu776BLC6K
203	payment	36	36	36	202	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jui7MRcZWWoVEwkFdpKD1kAfdCBwFaxaCgiJn38e72Pmc89qFHh
204	payment	36	36	36	203	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtbjY4e6nbMEWHoYpC3DpT3cLJtqWcW4rsRdGpMvCFkdJqGawKE
205	payment	36	36	36	204	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtZMdh7ptMiUhYm1a7gvnMkDoevg542QG99Sjnk9dvB4kQw3RXg
206	payment	36	36	36	205	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuzouzoU2nMRdT6woTW3bC5bau7NgnWDLzP1GsYJnjKWD1LgSta
207	payment	36	36	36	206	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuwC3ZL94cwCZjx1dN4WCpCvd4km7zh8g5xy49faHUZEybioGdc
208	payment	36	36	36	207	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JubMDcaRwfa1Gk8RtAbXF5RNb6fW6wWP8JibKfG91ZJYCos9XKf
209	payment	36	36	36	208	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtbbBPG83EyvKoCX3Bp66fuEBMMSQSZvMcWC1uMLcu6ghZjTCvR
210	payment	36	36	36	209	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtWpksX8uqLrWciy6QroaaQ16DNp4kx6o8u1fmoziC1HftJ3gkq
211	payment	36	36	36	210	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JucqufkVoV4LvoEDdqsaL8riu988MiXTpFqP4Rix4ghzV7SqMAQ
212	payment	36	36	36	211	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju3vfFGZb854jw4zBqWsc2KAoscGTUsDyNPAJFCkv2sRKfGWAKy
213	payment	36	36	36	212	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtwTPASZC4WoHVcGZhyUi3oBmZcCV8Bpv7393uf5f6B69xCuidh
214	payment	36	36	36	213	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvEJMUbyyVLAdkA4qx9MuM6NMb1he4uGQJ8tarWVtjNPfQLenxj
215	payment	36	36	36	214	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuDc4J8m4E5JigVkVsyT8iav1FbehKaqoku3kvj2HmwKfgHN3Yy
216	payment	36	36	36	215	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JteDxb4ZGQma7N3dhEChjTeDiRXchq6Q5gurZxzT3wLXPQfvdC4
217	payment	36	36	36	216	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju2cH66D4Jp2YsofaGkF7i4shiuNnT8kQaHMUYziVMryZSgSgDX
218	payment	36	36	36	217	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtbgi5FSWPedRHXATWVUH8nEGXmL2jxU89JZ9RNzKGcKeGizKTM
219	payment	36	36	36	218	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuZvPquBRFfHH4JnAGxHQsAxwEZjrM2YY14AXdCdjoYxha958GV
220	payment	36	36	36	219	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuR5PNtqEpmuRSQbY5mQhwCAEzMirzsxhUCtafWRwDLViThbPUT
221	payment	36	36	36	220	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuT4p8RfMxaX3REritSUYtuHuhEXTBEjZs5ADRBTjXTvtnv5CHV
222	payment	36	36	36	221	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuCwUjH4BNnQStcTMiL2mZ9urqZWXf8R8uk7hGBcXzLuKM9Pf96
223	payment	36	36	36	222	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuPCLpwgAeQ6uKBmpYtzaEVJ4oAdEKSgDrtEVinWkNciwPYXbes
224	payment	36	36	36	223	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv9hG46Yv3e7UwNddsn7HwPC8q9w2avWF68K32chJSZAxvE6isp
225	payment	36	36	36	224	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jui6M4KmQRCtgqgmmz1rJu5TZZushGdKnBPZbMrD354cXZFBqkw
226	payment	36	36	36	225	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtcRXb8mkoUoo1cE3KWSSiPoXpSwWxkggtRwP1LqDAbFeLFnLU6
227	payment	36	36	36	226	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju3CwNc12usiQXQCUSpWfDbpsNW54KUguHNFix9n4XPDfGykP6G
228	payment	36	36	36	227	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuSpfM37p9hBHWRQ8oLGnaNiCncGVNnjNUcZWcSFeLriPsKF1Lo
229	payment	36	36	36	228	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvGC45vDpsmS36nbDVWj32UC6knTnm8JK6wMsQFYjqMSmR6WVk3
230	payment	36	36	36	229	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jun5bQgjbzHYWn1erKNmmbpL88dfkB5wQWghsKmVbrXGj7otBdX
231	payment	36	36	36	230	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju2SPe6mxW4YwgT4B6wpGHLezuztZdRSLrMwLjSxRnsJZwaLqCY
232	payment	36	36	36	231	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuPFry9ujTSWgqrSLeksg2UFisfDC1XwwEVZx6y7txfRNeSxfzC
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
182	\N	181	\N	\N	1	\N	\N	\N
160	\N	159	\N	\N	1	\N	\N	\N
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
183	\N	182	\N	\N	1	\N	\N	\N
184	\N	183	\N	\N	1	\N	\N	\N
185	\N	184	\N	\N	1	\N	\N	\N
186	\N	185	\N	\N	1	\N	\N	\N
187	\N	186	\N	\N	1	\N	\N	\N
188	\N	187	\N	\N	1	\N	\N	\N
189	\N	188	\N	\N	1	\N	\N	\N
190	\N	189	\N	\N	1	\N	\N	\N
191	\N	190	\N	\N	1	\N	\N	\N
192	\N	191	\N	\N	1	\N	\N	\N
193	\N	192	\N	\N	1	\N	\N	\N
194	\N	193	\N	\N	1	\N	\N	\N
195	\N	194	\N	\N	1	\N	\N	\N
196	\N	195	\N	\N	1	\N	\N	\N
197	\N	196	\N	\N	1	\N	\N	\N
198	\N	197	\N	\N	1	\N	\N	\N
199	\N	198	\N	\N	1	\N	\N	\N
200	\N	199	\N	\N	1	\N	\N	\N
201	\N	200	\N	\N	1	\N	\N	\N
202	\N	201	\N	\N	1	\N	\N	\N
203	\N	202	\N	\N	1	\N	\N	\N
204	\N	203	\N	\N	1	\N	\N	\N
205	\N	204	\N	\N	1	\N	\N	\N
206	\N	205	\N	\N	1	\N	\N	\N
207	\N	206	\N	\N	1	\N	\N	\N
208	\N	207	\N	\N	1	\N	\N	\N
209	\N	208	\N	\N	1	\N	\N	\N
210	\N	209	\N	\N	1	\N	\N	\N
211	\N	210	\N	\N	1	\N	\N	\N
212	\N	211	\N	\N	1	\N	\N	\N
213	\N	212	\N	\N	1	\N	\N	\N
214	\N	213	\N	\N	1	\N	\N	\N
215	\N	214	\N	\N	1	\N	\N	\N
216	\N	215	\N	\N	1	\N	\N	\N
217	\N	216	\N	\N	1	\N	\N	\N
218	\N	217	\N	\N	1	\N	\N	\N
219	\N	218	\N	\N	1	\N	\N	\N
220	\N	219	\N	\N	1	\N	\N	\N
221	\N	220	\N	\N	1	\N	\N	\N
222	\N	221	\N	\N	1	\N	\N	\N
223	\N	222	\N	\N	1	\N	\N	\N
224	\N	223	\N	\N	1	\N	\N	\N
225	\N	224	\N	\N	1	\N	\N	\N
226	\N	225	\N	\N	1	\N	\N	\N
227	\N	226	\N	\N	1	\N	\N	\N
228	\N	227	\N	\N	1	\N	\N	\N
229	\N	228	\N	\N	1	\N	\N	\N
230	\N	229	\N	\N	1	\N	\N	\N
231	\N	230	\N	\N	1	\N	\N	\N
232	\N	231	\N	\N	1	\N	\N	\N
233	\N	232	\N	\N	1	\N	\N	\N
234	\N	233	\N	\N	1	\N	\N	\N
235	\N	234	\N	\N	1	\N	\N	\N
236	\N	235	\N	\N	1	\N	\N	\N
237	\N	236	\N	\N	1	\N	\N	\N
238	\N	237	\N	\N	1	\N	\N	\N
239	\N	238	\N	\N	1	\N	\N	\N
240	\N	239	\N	\N	1	\N	\N	\N
241	\N	240	\N	\N	1	\N	\N	\N
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
378	378
379	379
380	380
381	381
382	382
383	383
384	384
385	385
386	386
387	387
388	388
389	389
390	390
391	391
392	392
393	393
394	394
395	395
396	396
397	397
398	398
399	399
400	400
401	401
402	402
403	403
404	404
405	405
406	406
407	407
408	408
409	409
410	410
411	411
412	412
413	413
414	414
415	415
416	416
417	417
418	418
419	419
420	420
421	421
422	422
423	423
424	424
425	425
426	426
427	427
428	428
429	429
430	430
431	431
432	432
433	433
434	434
435	435
436	436
437	437
438	438
439	439
440	440
441	441
442	442
443	443
444	444
445	445
446	446
447	447
448	448
449	449
450	450
451	451
452	452
453	453
454	454
455	455
456	456
457	457
458	458
459	459
460	460
461	461
462	462
463	463
464	464
465	465
466	466
467	467
468	468
469	469
470	470
471	471
472	472
473	473
474	474
475	475
476	476
477	477
478	478
479	479
480	480
\.


--
-- Data for Name: zkapp_account_update_body; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.zkapp_account_update_body (id, account_identifier_id, update_id, balance_change, increment_nonce, events_id, actions_id, call_data_id, call_depth, zkapp_network_precondition_id, zkapp_account_precondition_id, zkapp_valid_while_precondition_id, use_full_commitment, implicit_account_creation_fee, may_use_token, authorization_kind, verification_key_hash_id) FROM stdin;
1	111	1	-1000000000000	t	1	1	1	0	1	1	\N	f	f	No	Signature	\N
2	243	2	999000000000	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
3	111	1	-1000000000	t	1	1	1	0	1	3	\N	f	f	No	Signature	\N
4	243	1	1000000000	f	1	1	1	0	1	2	\N	f	f	No	None_given	\N
5	243	3	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
6	111	1	-1000000000	t	1	1	1	0	1	4	\N	f	f	No	Signature	\N
7	243	4	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
8	111	1	-1000000000	t	1	1	1	0	1	5	\N	f	f	No	Signature	\N
9	243	5	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
10	111	1	-1000000000	t	1	1	1	0	1	6	\N	f	f	No	Signature	\N
11	243	6	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
12	111	1	-1000000000	t	1	1	1	0	1	7	\N	f	f	No	Signature	\N
13	243	7	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
14	111	1	-1000000000	t	1	1	1	0	1	8	\N	f	f	No	Signature	\N
15	243	8	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
16	111	1	-1000000000	t	1	1	1	0	1	9	\N	f	f	No	Signature	\N
17	243	9	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
18	111	1	-1000000000	t	1	1	1	0	1	10	\N	f	f	No	Signature	\N
19	243	10	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
20	111	1	-1000000000	t	1	1	1	0	1	11	\N	f	f	No	Signature	\N
21	243	11	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
22	111	1	-1000000000	t	1	1	1	0	1	12	\N	f	f	No	Signature	\N
23	243	12	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
24	111	1	-1000000000	t	1	1	1	0	1	13	\N	f	f	No	Signature	\N
25	243	13	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
26	111	1	-1000000000	t	1	1	1	0	1	14	\N	f	f	No	Signature	\N
27	243	14	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
28	111	1	-1000000000	t	1	1	1	0	1	15	\N	f	f	No	Signature	\N
29	243	15	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
30	111	1	-1000000000	t	1	1	1	0	1	16	\N	f	f	No	Signature	\N
31	243	16	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
32	111	1	-1000000000	t	1	1	1	0	1	17	\N	f	f	No	Signature	\N
33	243	17	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
34	111	1	-1000000000	t	1	1	1	0	1	18	\N	f	f	No	Signature	\N
35	243	18	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
36	111	1	-1000000000	t	1	1	1	0	1	19	\N	f	f	No	Signature	\N
37	243	19	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
38	111	1	-1000000000	t	1	1	1	0	1	20	\N	f	f	No	Signature	\N
39	243	20	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
40	111	1	-1000000000	t	1	1	1	0	1	21	\N	f	f	No	Signature	\N
41	243	21	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
42	111	1	-1000000000	t	1	1	1	0	1	22	\N	f	f	No	Signature	\N
43	243	22	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
44	111	1	-1000000000	t	1	1	1	0	1	23	\N	f	f	No	Signature	\N
45	243	23	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
46	111	1	-1000000000	t	1	1	1	0	1	24	\N	f	f	No	Signature	\N
47	243	24	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
48	111	1	-1000000000	t	1	1	1	0	1	25	\N	f	f	No	Signature	\N
49	243	25	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
50	111	1	-1000000000	t	1	1	1	0	1	26	\N	f	f	No	Signature	\N
51	243	26	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
52	111	1	-1000000000	t	1	1	1	0	1	27	\N	f	f	No	Signature	\N
53	243	27	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
54	111	1	-1000000000	t	1	1	1	0	1	28	\N	f	f	No	Signature	\N
55	243	28	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
56	111	1	-1000000000	t	1	1	1	0	1	29	\N	f	f	No	Signature	\N
57	243	29	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
58	111	1	-1000000000	t	1	1	1	0	1	30	\N	f	f	No	Signature	\N
59	243	30	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
60	111	1	-1000000000	t	1	1	1	0	1	31	\N	f	f	No	Signature	\N
61	243	31	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
62	111	1	-1000000000	t	1	1	1	0	1	32	\N	f	f	No	Signature	\N
63	243	32	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
64	111	1	-1000000000	t	1	1	1	0	1	33	\N	f	f	No	Signature	\N
65	243	33	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
66	111	1	-1000000000	t	1	1	1	0	1	34	\N	f	f	No	Signature	\N
67	243	34	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
68	111	1	-1000000000	t	1	1	1	0	1	35	\N	f	f	No	Signature	\N
69	243	35	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
70	111	1	-1000000000	t	1	1	1	0	1	36	\N	f	f	No	Signature	\N
71	243	36	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
72	111	1	-1000000000	t	1	1	1	0	1	37	\N	f	f	No	Signature	\N
73	243	37	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
74	111	1	-1000000000	t	1	1	1	0	1	38	\N	f	f	No	Signature	\N
75	243	38	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
76	111	1	-1000000000	t	1	1	1	0	1	39	\N	f	f	No	Signature	\N
77	243	39	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
78	111	1	-1000000000	t	1	1	1	0	1	40	\N	f	f	No	Signature	\N
79	243	40	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
80	111	1	-1000000000	t	1	1	1	0	1	41	\N	f	f	No	Signature	\N
81	243	41	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
82	111	1	-1000000000	t	1	1	1	0	1	42	\N	f	f	No	Signature	\N
83	243	42	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
84	111	1	-1000000000	t	1	1	1	0	1	43	\N	f	f	No	Signature	\N
85	243	43	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
86	111	1	-1000000000	t	1	1	1	0	1	44	\N	f	f	No	Signature	\N
87	243	44	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
88	111	1	-1000000000	t	1	1	1	0	1	45	\N	f	f	No	Signature	\N
89	243	45	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
90	111	1	-1000000000	t	1	1	1	0	1	46	\N	f	f	No	Signature	\N
91	243	46	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
92	111	1	-1000000000	t	1	1	1	0	1	47	\N	f	f	No	Signature	\N
93	243	47	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
94	111	1	-1000000000	t	1	1	1	0	1	48	\N	f	f	No	Signature	\N
95	243	48	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
96	111	1	-1000000000	t	1	1	1	0	1	49	\N	f	f	No	Signature	\N
97	243	49	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
98	111	1	-1000000000	t	1	1	1	0	1	50	\N	f	f	No	Signature	\N
99	243	50	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
100	111	1	-1000000000	t	1	1	1	0	1	51	\N	f	f	No	Signature	\N
101	243	51	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
102	111	1	-1000000000	t	1	1	1	0	1	52	\N	f	f	No	Signature	\N
103	243	52	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
104	111	1	-1000000000	t	1	1	1	0	1	53	\N	f	f	No	Signature	\N
105	243	53	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
106	111	1	-1000000000	t	1	1	1	0	1	54	\N	f	f	No	Signature	\N
107	243	54	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
108	111	1	-1000000000	t	1	1	1	0	1	55	\N	f	f	No	Signature	\N
109	243	55	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
110	111	1	-1000000000	t	1	1	1	0	1	56	\N	f	f	No	Signature	\N
111	243	56	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
112	111	1	-1000000000	t	1	1	1	0	1	57	\N	f	f	No	Signature	\N
113	243	57	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
114	111	1	-1000000000	t	1	1	1	0	1	58	\N	f	f	No	Signature	\N
115	243	58	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
116	111	1	-1000000000	t	1	1	1	0	1	59	\N	f	f	No	Signature	\N
117	243	59	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
118	111	1	-1000000000	t	1	1	1	0	1	60	\N	f	f	No	Signature	\N
119	243	60	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
120	111	1	-1000000000	t	1	1	1	0	1	61	\N	f	f	No	Signature	\N
121	243	61	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
122	111	1	-1000000000	t	1	1	1	0	1	62	\N	f	f	No	Signature	\N
123	243	62	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
124	111	1	-1000000000	t	1	1	1	0	1	63	\N	f	f	No	Signature	\N
125	243	63	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
126	111	1	-1000000000	t	1	1	1	0	1	64	\N	f	f	No	Signature	\N
127	243	64	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
128	111	1	-1000000000	t	1	1	1	0	1	65	\N	f	f	No	Signature	\N
129	243	65	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
130	111	1	-1000000000	t	1	1	1	0	1	66	\N	f	f	No	Signature	\N
131	243	66	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
132	111	1	-1000000000	t	1	1	1	0	1	67	\N	f	f	No	Signature	\N
133	243	67	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
134	111	1	-1000000000	t	1	1	1	0	1	68	\N	f	f	No	Signature	\N
135	243	68	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
136	111	1	-1000000000	t	1	1	1	0	1	69	\N	f	f	No	Signature	\N
137	243	69	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
138	111	1	-1000000000	t	1	1	1	0	1	70	\N	f	f	No	Signature	\N
139	243	70	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
140	111	1	-1000000000	t	1	1	1	0	1	71	\N	f	f	No	Signature	\N
141	243	71	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
142	111	1	-1000000000	t	1	1	1	0	1	72	\N	f	f	No	Signature	\N
143	243	72	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
144	111	1	-1000000000	t	1	1	1	0	1	73	\N	f	f	No	Signature	\N
145	243	73	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
146	111	1	-1000000000	t	1	1	1	0	1	74	\N	f	f	No	Signature	\N
147	243	74	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
148	111	1	-1000000000	t	1	1	1	0	1	75	\N	f	f	No	Signature	\N
149	243	75	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
150	111	1	-1000000000	t	1	1	1	0	1	76	\N	f	f	No	Signature	\N
151	243	76	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
152	111	1	-1000000000	t	1	1	1	0	1	77	\N	f	f	No	Signature	\N
153	243	77	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
154	111	1	-1000000000	t	1	1	1	0	1	78	\N	f	f	No	Signature	\N
155	243	78	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
156	111	1	-1000000000	t	1	1	1	0	1	79	\N	f	f	No	Signature	\N
157	243	79	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
158	111	1	-1000000000	t	1	1	1	0	1	80	\N	f	f	No	Signature	\N
159	243	80	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
160	111	1	-1000000000	t	1	1	1	0	1	81	\N	f	f	No	Signature	\N
161	243	81	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
162	111	1	-1000000000	t	1	1	1	0	1	82	\N	f	f	No	Signature	\N
163	243	82	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
164	111	1	-1000000000	t	1	1	1	0	1	83	\N	f	f	No	Signature	\N
165	243	83	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
166	111	1	-1000000000	t	1	1	1	0	1	84	\N	f	f	No	Signature	\N
167	243	84	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
168	111	1	-1000000000	t	1	1	1	0	1	85	\N	f	f	No	Signature	\N
169	243	85	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
170	111	1	-1000000000	t	1	1	1	0	1	86	\N	f	f	No	Signature	\N
171	243	86	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
172	111	1	-1000000000	t	1	1	1	0	1	87	\N	f	f	No	Signature	\N
173	243	87	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
174	111	1	-1000000000	t	1	1	1	0	1	88	\N	f	f	No	Signature	\N
175	243	88	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
176	111	1	-1000000000	t	1	1	1	0	1	89	\N	f	f	No	Signature	\N
177	243	89	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
178	111	1	-1000000000	t	1	1	1	0	1	90	\N	f	f	No	Signature	\N
179	243	90	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
180	111	1	-1000000000	t	1	1	1	0	1	91	\N	f	f	No	Signature	\N
181	243	91	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
182	111	1	-1000000000	t	1	1	1	0	1	92	\N	f	f	No	Signature	\N
183	243	92	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
184	111	1	-1000000000	t	1	1	1	0	1	93	\N	f	f	No	Signature	\N
185	243	93	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
186	111	1	-1000000000	t	1	1	1	0	1	94	\N	f	f	No	Signature	\N
187	243	94	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
188	111	1	-1000000000	t	1	1	1	0	1	95	\N	f	f	No	Signature	\N
189	243	95	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
190	111	1	-1000000000	t	1	1	1	0	1	96	\N	f	f	No	Signature	\N
191	243	96	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
192	111	1	-1000000000	t	1	1	1	0	1	97	\N	f	f	No	Signature	\N
193	243	97	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
194	111	1	-1000000000	t	1	1	1	0	1	98	\N	f	f	No	Signature	\N
195	243	98	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
196	111	1	-1000000000	t	1	1	1	0	1	99	\N	f	f	No	Signature	\N
197	243	99	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
198	111	1	-1000000000	t	1	1	1	0	1	100	\N	f	f	No	Signature	\N
199	243	100	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
200	111	1	-1000000000	t	1	1	1	0	1	101	\N	f	f	No	Signature	\N
201	243	101	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
202	111	1	-1000000000	t	1	1	1	0	1	102	\N	f	f	No	Signature	\N
203	243	102	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
204	111	1	-1000000000	t	1	1	1	0	1	103	\N	f	f	No	Signature	\N
205	243	103	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
206	111	1	-1000000000	t	1	1	1	0	1	104	\N	f	f	No	Signature	\N
207	243	104	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
208	111	1	-1000000000	t	1	1	1	0	1	105	\N	f	f	No	Signature	\N
209	243	105	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
210	111	1	-1000000000	t	1	1	1	0	1	106	\N	f	f	No	Signature	\N
211	243	106	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
212	111	1	-1000000000	t	1	1	1	0	1	107	\N	f	f	No	Signature	\N
213	243	107	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
214	111	1	-1000000000	t	1	1	1	0	1	108	\N	f	f	No	Signature	\N
215	243	108	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
216	111	1	-1000000000	t	1	1	1	0	1	109	\N	f	f	No	Signature	\N
217	243	109	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
218	111	1	-1000000000	t	1	1	1	0	1	110	\N	f	f	No	Signature	\N
219	243	110	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
220	111	1	-1000000000	t	1	1	1	0	1	111	\N	f	f	No	Signature	\N
221	243	111	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
222	111	1	-1000000000	t	1	1	1	0	1	112	\N	f	f	No	Signature	\N
223	243	112	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
224	111	1	-1000000000	t	1	1	1	0	1	113	\N	f	f	No	Signature	\N
225	243	113	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
226	111	1	-1000000000	t	1	1	1	0	1	114	\N	f	f	No	Signature	\N
227	243	114	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
228	111	1	-1000000000	t	1	1	1	0	1	115	\N	f	f	No	Signature	\N
229	243	115	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
230	111	1	-1000000000	t	1	1	1	0	1	116	\N	f	f	No	Signature	\N
231	243	116	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
232	111	1	-1000000000	t	1	1	1	0	1	117	\N	f	f	No	Signature	\N
233	243	117	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
234	111	1	-1000000000	t	1	1	1	0	1	118	\N	f	f	No	Signature	\N
235	243	118	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
236	111	1	-1000000000	t	1	1	1	0	1	119	\N	f	f	No	Signature	\N
237	243	119	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
238	111	1	-1000000000	t	1	1	1	0	1	120	\N	f	f	No	Signature	\N
239	243	120	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
240	111	1	-1000000000	t	1	1	1	0	1	121	\N	f	f	No	Signature	\N
241	243	121	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
242	111	1	-1000000000	t	1	1	1	0	1	122	\N	f	f	No	Signature	\N
243	243	122	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
244	111	1	-1000000000	t	1	1	1	0	1	123	\N	f	f	No	Signature	\N
245	243	123	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
246	111	1	-1000000000	t	1	1	1	0	1	124	\N	f	f	No	Signature	\N
247	243	124	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
248	111	1	-1000000000	t	1	1	1	0	1	125	\N	f	f	No	Signature	\N
249	243	125	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
250	111	1	-1000000000	t	1	1	1	0	1	126	\N	f	f	No	Signature	\N
251	243	126	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
252	111	1	-1000000000	t	1	1	1	0	1	127	\N	f	f	No	Signature	\N
253	243	127	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
254	111	1	-1000000000	t	1	1	1	0	1	128	\N	f	f	No	Signature	\N
255	243	128	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
256	111	1	-1000000000	t	1	1	1	0	1	129	\N	f	f	No	Signature	\N
257	243	129	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
258	111	1	-1000000000	t	1	1	1	0	1	130	\N	f	f	No	Signature	\N
259	243	130	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
260	111	1	-1000000000	t	1	1	1	0	1	131	\N	f	f	No	Signature	\N
261	243	131	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
262	111	1	-1000000000	t	1	1	1	0	1	132	\N	f	f	No	Signature	\N
263	243	132	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
264	111	1	-1000000000	t	1	1	1	0	1	133	\N	f	f	No	Signature	\N
265	243	133	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
266	111	1	-1000000000	t	1	1	1	0	1	134	\N	f	f	No	Signature	\N
267	243	134	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
268	111	1	-1000000000	t	1	1	1	0	1	135	\N	f	f	No	Signature	\N
269	243	135	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
270	111	1	-1000000000	t	1	1	1	0	1	136	\N	f	f	No	Signature	\N
271	243	136	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
272	111	1	-1000000000	t	1	1	1	0	1	137	\N	f	f	No	Signature	\N
273	243	137	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
274	111	1	-1000000000	t	1	1	1	0	1	138	\N	f	f	No	Signature	\N
275	243	138	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
276	111	1	-1000000000	t	1	1	1	0	1	139	\N	f	f	No	Signature	\N
277	243	139	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
278	111	1	-1000000000	t	1	1	1	0	1	140	\N	f	f	No	Signature	\N
279	243	140	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
280	111	1	-1000000000	t	1	1	1	0	1	141	\N	f	f	No	Signature	\N
281	243	141	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
282	111	1	-1000000000	t	1	1	1	0	1	142	\N	f	f	No	Signature	\N
283	243	142	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
284	111	1	-1000000000	t	1	1	1	0	1	143	\N	f	f	No	Signature	\N
285	243	143	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
286	111	1	-1000000000	t	1	1	1	0	1	144	\N	f	f	No	Signature	\N
287	243	144	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
288	111	1	-1000000000	t	1	1	1	0	1	145	\N	f	f	No	Signature	\N
289	243	145	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
290	111	1	-1000000000	t	1	1	1	0	1	146	\N	f	f	No	Signature	\N
291	243	146	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
292	111	1	-1000000000	t	1	1	1	0	1	147	\N	f	f	No	Signature	\N
293	243	147	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
294	111	1	-1000000000	t	1	1	1	0	1	148	\N	f	f	No	Signature	\N
295	243	148	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
296	111	1	-1000000000	t	1	1	1	0	1	149	\N	f	f	No	Signature	\N
297	243	149	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
298	111	1	-1000000000	t	1	1	1	0	1	150	\N	f	f	No	Signature	\N
299	243	150	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
300	111	1	-1000000000	t	1	1	1	0	1	151	\N	f	f	No	Signature	\N
301	243	151	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
302	111	1	-1000000000	t	1	1	1	0	1	152	\N	f	f	No	Signature	\N
303	243	152	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
304	111	1	-1000000000	t	1	1	1	0	1	153	\N	f	f	No	Signature	\N
305	243	153	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
306	111	1	-1000000000	t	1	1	1	0	1	154	\N	f	f	No	Signature	\N
307	243	154	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
308	111	1	-1000000000	t	1	1	1	0	1	155	\N	f	f	No	Signature	\N
309	243	155	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
310	111	1	-1000000000	t	1	1	1	0	1	156	\N	f	f	No	Signature	\N
311	243	156	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
312	111	1	-1000000000	t	1	1	1	0	1	157	\N	f	f	No	Signature	\N
313	243	157	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
314	111	1	-1000000000	t	1	1	1	0	1	158	\N	f	f	No	Signature	\N
315	243	158	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
316	111	1	-1000000000	t	1	1	1	0	1	159	\N	f	f	No	Signature	\N
317	243	159	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
318	111	1	-1000000000	t	1	1	1	0	1	160	\N	f	f	No	Signature	\N
319	243	160	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
320	111	1	-1000000000	t	1	1	1	0	1	161	\N	f	f	No	Signature	\N
321	243	161	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
322	111	1	-1000000000	t	1	1	1	0	1	162	\N	f	f	No	Signature	\N
323	243	162	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
324	111	1	-1000000000	t	1	1	1	0	1	163	\N	f	f	No	Signature	\N
325	243	163	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
326	111	1	-1000000000	t	1	1	1	0	1	164	\N	f	f	No	Signature	\N
327	243	164	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
328	111	1	-1000000000	t	1	1	1	0	1	165	\N	f	f	No	Signature	\N
329	243	165	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
330	111	1	-1000000000	t	1	1	1	0	1	166	\N	f	f	No	Signature	\N
331	243	166	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
332	111	1	-1000000000	t	1	1	1	0	1	167	\N	f	f	No	Signature	\N
333	243	167	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
334	111	1	-1000000000	t	1	1	1	0	1	168	\N	f	f	No	Signature	\N
335	243	168	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
336	111	1	-1000000000	t	1	1	1	0	1	169	\N	f	f	No	Signature	\N
337	243	169	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
338	111	1	-1000000000	t	1	1	1	0	1	170	\N	f	f	No	Signature	\N
339	243	170	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
340	111	1	-1000000000	t	1	1	1	0	1	171	\N	f	f	No	Signature	\N
341	243	171	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
342	111	1	-1000000000	t	1	1	1	0	1	172	\N	f	f	No	Signature	\N
343	243	172	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
344	111	1	-1000000000	t	1	1	1	0	1	173	\N	f	f	No	Signature	\N
345	243	173	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
346	111	1	-1000000000	t	1	1	1	0	1	174	\N	f	f	No	Signature	\N
347	243	174	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
348	111	1	-1000000000	t	1	1	1	0	1	175	\N	f	f	No	Signature	\N
349	243	175	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
350	111	1	-1000000000	t	1	1	1	0	1	176	\N	f	f	No	Signature	\N
351	243	176	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
352	111	1	-1000000000	t	1	1	1	0	1	177	\N	f	f	No	Signature	\N
353	243	177	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
354	111	1	-1000000000	t	1	1	1	0	1	178	\N	f	f	No	Signature	\N
355	243	178	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
356	111	1	-1000000000	t	1	1	1	0	1	179	\N	f	f	No	Signature	\N
357	243	179	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
358	111	1	-1000000000	t	1	1	1	0	1	180	\N	f	f	No	Signature	\N
359	243	180	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
360	111	1	-1000000000	t	1	1	1	0	1	181	\N	f	f	No	Signature	\N
364	111	1	-1000000000	t	1	1	1	0	1	183	\N	f	f	No	Signature	\N
365	243	183	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
366	111	1	-1000000000	t	1	1	1	0	1	184	\N	f	f	No	Signature	\N
368	111	1	-1000000000	t	1	1	1	0	1	185	\N	f	f	No	Signature	\N
369	243	185	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
370	111	1	-1000000000	t	1	1	1	0	1	186	\N	f	f	No	Signature	\N
371	243	186	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
375	243	188	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
376	111	1	-1000000000	t	1	1	1	0	1	189	\N	f	f	No	Signature	\N
377	243	189	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
378	111	1	-1000000000	t	1	1	1	0	1	190	\N	f	f	No	Signature	\N
361	243	181	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
362	111	1	-1000000000	t	1	1	1	0	1	182	\N	f	f	No	Signature	\N
363	243	182	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
367	243	184	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
372	111	1	-1000000000	t	1	1	1	0	1	187	\N	f	f	No	Signature	\N
373	243	187	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
374	111	1	-1000000000	t	1	1	1	0	1	188	\N	f	f	No	Signature	\N
379	243	190	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
380	111	1	-1000000000	t	1	1	1	0	1	191	\N	f	f	No	Signature	\N
381	243	191	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
382	111	1	-1000000000	t	1	1	1	0	1	192	\N	f	f	No	Signature	\N
383	243	192	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
384	111	1	-1000000000	t	1	1	1	0	1	193	\N	f	f	No	Signature	\N
385	243	193	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
386	111	1	-1000000000	t	1	1	1	0	1	194	\N	f	f	No	Signature	\N
387	243	194	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
388	111	1	-1000000000	t	1	1	1	0	1	195	\N	f	f	No	Signature	\N
389	243	195	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
390	111	1	-1000000000	t	1	1	1	0	1	196	\N	f	f	No	Signature	\N
391	243	196	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
392	111	1	-1000000000	t	1	1	1	0	1	197	\N	f	f	No	Signature	\N
393	243	197	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
394	111	1	-1000000000	t	1	1	1	0	1	198	\N	f	f	No	Signature	\N
395	243	198	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
396	111	1	-1000000000	t	1	1	1	0	1	199	\N	f	f	No	Signature	\N
397	243	199	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
398	111	1	-1000000000	t	1	1	1	0	1	200	\N	f	f	No	Signature	\N
399	243	200	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
400	111	1	-1000000000	t	1	1	1	0	1	201	\N	f	f	No	Signature	\N
401	243	201	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
402	111	1	-1000000000	t	1	1	1	0	1	202	\N	f	f	No	Signature	\N
403	243	202	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
404	111	1	-1000000000	t	1	1	1	0	1	203	\N	f	f	No	Signature	\N
405	243	203	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
406	111	1	-1000000000	t	1	1	1	0	1	204	\N	f	f	No	Signature	\N
407	243	204	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
408	111	1	-1000000000	t	1	1	1	0	1	205	\N	f	f	No	Signature	\N
409	243	205	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
410	111	1	-1000000000	t	1	1	1	0	1	206	\N	f	f	No	Signature	\N
411	243	206	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
412	111	1	-1000000000	t	1	1	1	0	1	207	\N	f	f	No	Signature	\N
413	243	207	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
414	111	1	-1000000000	t	1	1	1	0	1	208	\N	f	f	No	Signature	\N
415	243	208	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
416	111	1	-1000000000	t	1	1	1	0	1	209	\N	f	f	No	Signature	\N
417	243	209	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
418	111	1	-1000000000	t	1	1	1	0	1	210	\N	f	f	No	Signature	\N
419	243	210	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
420	111	1	-1000000000	t	1	1	1	0	1	211	\N	f	f	No	Signature	\N
421	243	211	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
422	111	1	-1000000000	t	1	1	1	0	1	212	\N	f	f	No	Signature	\N
423	243	212	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
424	111	1	-1000000000	t	1	1	1	0	1	213	\N	f	f	No	Signature	\N
425	243	213	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
426	111	1	-1000000000	t	1	1	1	0	1	214	\N	f	f	No	Signature	\N
427	243	214	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
428	111	1	-1000000000	t	1	1	1	0	1	215	\N	f	f	No	Signature	\N
429	243	215	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
430	111	1	-1000000000	t	1	1	1	0	1	216	\N	f	f	No	Signature	\N
431	243	216	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
432	111	1	-1000000000	t	1	1	1	0	1	217	\N	f	f	No	Signature	\N
433	243	217	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
434	111	1	-1000000000	t	1	1	1	0	1	218	\N	f	f	No	Signature	\N
435	243	218	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
436	111	1	-1000000000	t	1	1	1	0	1	219	\N	f	f	No	Signature	\N
437	243	219	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
438	111	1	-1000000000	t	1	1	1	0	1	220	\N	f	f	No	Signature	\N
439	243	220	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
440	111	1	-1000000000	t	1	1	1	0	1	221	\N	f	f	No	Signature	\N
441	243	221	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
442	111	1	-1000000000	t	1	1	1	0	1	222	\N	f	f	No	Signature	\N
443	243	222	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
444	111	1	-1000000000	t	1	1	1	0	1	223	\N	f	f	No	Signature	\N
445	243	223	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
446	111	1	-1000000000	t	1	1	1	0	1	224	\N	f	f	No	Signature	\N
447	243	224	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
448	111	1	-1000000000	t	1	1	1	0	1	225	\N	f	f	No	Signature	\N
449	243	225	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
450	111	1	-1000000000	t	1	1	1	0	1	226	\N	f	f	No	Signature	\N
451	243	226	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
452	111	1	-1000000000	t	1	1	1	0	1	227	\N	f	f	No	Signature	\N
453	243	227	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
454	111	1	-1000000000	t	1	1	1	0	1	228	\N	f	f	No	Signature	\N
455	243	228	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
456	111	1	-1000000000	t	1	1	1	0	1	229	\N	f	f	No	Signature	\N
457	243	229	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
458	111	1	-1000000000	t	1	1	1	0	1	230	\N	f	f	No	Signature	\N
459	243	230	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
460	111	1	-1000000000	t	1	1	1	0	1	231	\N	f	f	No	Signature	\N
461	243	231	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
462	111	1	-1000000000	t	1	1	1	0	1	232	\N	f	f	No	Signature	\N
463	243	232	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
464	111	1	-1000000000	t	1	1	1	0	1	233	\N	f	f	No	Signature	\N
465	243	233	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
466	111	1	-1000000000	t	1	1	1	0	1	234	\N	f	f	No	Signature	\N
467	243	234	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
468	111	1	-1000000000	t	1	1	1	0	1	235	\N	f	f	No	Signature	\N
469	243	235	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
470	111	1	-1000000000	t	1	1	1	0	1	236	\N	f	f	No	Signature	\N
471	243	236	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
472	111	1	-1000000000	t	1	1	1	0	1	237	\N	f	f	No	Signature	\N
473	243	237	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
474	111	1	-1000000000	t	1	1	1	0	1	238	\N	f	f	No	Signature	\N
475	243	238	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
476	111	1	-1000000000	t	1	1	1	0	1	239	\N	f	f	No	Signature	\N
477	243	239	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
478	111	1	-1000000000	t	1	1	1	0	1	240	\N	f	f	No	Signature	\N
479	243	240	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
480	111	1	-1000000000	t	1	1	1	0	1	241	\N	f	f	No	Signature	\N
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
1	1	{1,2}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtWHTiFfV3p78uEAPs17s2bmxXwR5ZqyufkBFsYemk4NRtt4oKc
2	2	{3,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju8VaaodCTBG4a7jvwPqVuCda4dYoxPLaD7YD4MGy3Gt4r9A8P7
3	3	{5}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvAGAYondT1vvsXx25KCx7iaqiCiPXaDmxyYHV9UTK82xpRVac9
4	4	{6,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuuB3aRTbXSkrJvj96c9EDxTqw3SiNcWZNaru5xbER1zuVJrirR
5	5	{7}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvLTxmHaP2iZzyLWZeLniPiFVGCZi9ZXBnCJBrXjmEUQLezFWHp
6	6	{8,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv33gBDR8mhioU2ezcty1aR3QfzhtPDYVRLQMPFyYH883dTGFpZ
7	7	{9}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtdKWdnBmascB1Q9qDV8rLNZkaRd1wvubtJstqL5CafNPMPbTnv
8	8	{10,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv5vL9qXLcavaULrTdn1YCWt9ZtGuDZjdkNbsJVPzDAHSttmoEg
9	9	{11}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jui93Zf2UyR5Ge5vLLMouNM95R6XupVTs9pSnGBw8JN17fJPU2E
10	10	{12,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuaZTXrre5HBt9FkDfn8VXFjzSDqXCG3xZb9zkugUPWpeT1iyYj
11	11	{13}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JutLA9HGpbzAiJJzRufLsG2CgnEZnW2C8RycL7pEskUjWA82Q47
12	12	{14,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JteAMeKUF7p31ZqaHT41EspT2SApomAHLasum2ovdhRdn24Ykj8
13	13	{15}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtiHj9qPnFWYCJ1qeyH8g8tLXkY13BDkvomAVjbdu9pXPHpR3GD
14	14	{16,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuTRNTkhCyLwhwUpX3NrAVm3BC2Vsj9iSZ9e91h4fo66tcVLpoA
15	15	{17}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtx4zJK6Xuw5adWWwWaqdkLWWkvA7dc72jwiSj291XpxTTE6Fum
16	16	{18,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuCtrdQdndk69fwpYKRNUGn4YG3nSQtbg4QbceGV48MxD8S1Jrq
17	17	{19}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv2DwDRJW3Zr2D2dsPGh3hMKFACbjhUonoZv6qYAoLGxjLTfs8y
18	18	{20,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuQZwsPcaWoVA7aZG663RekV7ifvB72wZTuMMAFGRNzm2FcxpPP
19	19	{21}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuB9Hp6XhJAsZRXdYMAVa9cuJZTb8JV2ZwgaSPhCDTTFJ3k8FXr
20	20	{22,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtYKdn3whKqp1qFtiWGuuJLKbv5jrXe3mKJkzbtECLTf4PyNVBr
21	21	{23}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JumEF3rEqZZutJXerRzEPH8Zj74CpMgecNn3uZ5zyq7jHqHLeTc
22	22	{24,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JudJR2ZPc88DmTsRGCMQH9DECXKBzuPHRJwcKELMc6m784p24HA
23	23	{25}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvLEkxm1nqMCqMdPouVLXihDZiDQgrqG5fninuy6oafdThyQgKx
24	24	{26,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuZTLJoWNm6APvtH53CxKGabEPxtzorSqBdJ6BNJ1hvWsusNDvt
25	25	{27}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvD8PZyYExobbsduz8itC6UFkBHrp3Lxwos772y3a6DXkZgK7PW
26	26	{28,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtcDpVwxZW8NXjiFUZ1j15SHN7xM2VQZaHRvXdYGt6mmE5YiiaR
27	27	{29}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuUEaTfzFL9j1AsKLA1aBPr5gkrxQsTUnoB6GT9LkU5vsQHW7A4
28	28	{30,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvFbXuC4CYqX54i1XP8fzozwvgg5QSMomeHnRfgvHowhcmrUfVK
29	29	{31}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtdT5mVCnCZwZVMJk2JPiJN8PFonxdpmek7ZvgTZwzBMXzTxPsP
30	30	{32,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvDgGD54ix5h5gMAiPR2V7FbM6ZNAkDhLF97UWmdw3TuFpPqgRV
31	31	{33}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv3webTvET2RpoiyrJLm1V3H1soFeYNHPMTiz9emwAMsUo9NRUv
32	32	{34,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juw8CV9q5UAWQyvREzpoQqtUaSuBWAN2K77Bbi7kHNeRHQuiNk3
33	33	{35}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvD8cmkBvPKPz81g2Gn6Fm7XLfBG7DL1JZrw6f5UexaTXLKb3Au
34	34	{36,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuF6aF9eLAmiZBaLC75aZyfgc7jeQBwZZWn4c53Xu5Sq3yGVzmP
35	35	{37}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuNm13Ee3rK2ZwWYoUVnMRFTP3yXk7ND1n1kandzQ4zXES7DFQK
36	36	{38,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv3JTQtsKTCz1VXfYbocbx1DedxnatPNkMdrdKWkj8Bm26s8bMU
37	37	{39}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvK2NSwkhQHw4yPMkLujmgyhTfYJT7ff1M711CbrtME92575SWw
38	38	{40,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuXeh1CZzGZAtDCZJfnwP9Y5de4QbKGXpBGdu753BTHwiic4jVT
39	39	{41}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvJzeQZCCwFsZnGJh9wAY75NkLmuQaKQnLx5aSPGyX3fx5xb2yv
40	40	{42,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv8BnwhoKtP3Pt4aBKocmano1osqUzNpSvv3bi6qqzY4sKU4KHo
41	41	{43}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtiuLe3pD3QWQ76puP7MGT5xKMDUWFkGbjDR3Au9hnjcVzamcsN
42	42	{44,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv2tpTruBG235e46K5paSRWgNiy12a9Zpet2ALnFtnup8s2k2v1
43	43	{45}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtfMMoGBnmWwgqQ9a8L9DJdQSEH78k8qpfgjLw1mRfR6ZnWyCeX
44	44	{46,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JudgeW9XptHzabRk1tL8Gs4HnRrD6yGMmgqcqvJCTY5wZdx2woN
45	45	{47}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuVADwT7X2hJM3sZieNBij9DJkDPNAZKDqV5PT2Zm56JkJApoEv
46	46	{48,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtcVGyoVtpuD65JrE2XN99EsSyE51gCp88wwPhniN2pwBdkS4bM
47	47	{49}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtWvEU5Vteak45mTMyAjzyePgzGsSyPQW9aDVGL2xiako2CTnjU
48	48	{50,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtc5hMPEqWePrHCuRpTqka5yfcV7mmXv5nxbSEdHPQLfVi8L7du
49	49	{51}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JujNBeLUFyDtuxjRk3VMHBXEGNEnpxsQMSv5rUWQhgeNe2KRdGN
50	50	{52,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvKBor9hP4ogUGgeKVMMY44Lhfz9v7HuuAdpxrvQtjK1Zw95bEW
51	51	{53}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JueXqbAXALMbPq6ne5i9x9f5wYaALGzboR3GVLMbtw1N1NcNQAs
52	52	{54,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju3RLnrEs7u3UPyqcRQDBjjs8fdLdgkR1LCZ2r3wfzroQXGpKPJ
53	53	{55}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JucSoea1FSGJ8bCd1T6yJakNzDpbMSsjNXvnDJ7vAL7iyR2Zabz
54	54	{56,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvGNNVMJrd8aWdfbqTsRAQBZcA4kDVzQsrXczfR1LsXSd82yUAt
55	55	{57}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuM15TapEWR9emmyjka71ccMHGiSBQbPEBJ5HjKYkMQh1aBTVC5
56	56	{58,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtntDFKQA1HiCj7rtenNPrQSwCQYZCRbr3BSpHS2sdieRJWJjeB
57	57	{59}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvDGKDoUKRLB27GwE6dtwELDvYbHDc4VbJLvmuR7mZn7zgWyWSx
58	58	{60,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtumPMU4rEJxWzigebaXyb7u1bgxG1MQCuhXeJtN1uWbTK79WZW
59	59	{61}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtqfFtc7kQvs4ynLKYYnCDhVNFHgMw1JzZ4HvFdm2iQVafh3F83
60	60	{62,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuRn5q13j2fePQDExsawUhkVx6aQfzXiTSKQ1dM5sHuhJfKkh3o
61	61	{63}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtqAcVMBpCs8iRn6yzdWu6BSbhkEztXUuWV4Q9qooUwoSQB1me7
62	62	{64,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuhCM2xqdRkd1Q2R6nfVUVxY8oCsRCMrckPJLfPWnKf4hLKY4zA
63	63	{65}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuibJVGT5kespht7WVHCk4xkjjAnoB6JHwcooTMcNUDUCNhu2Xk
64	64	{66,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtiy9BxHuivLVeXrrULbRGrAhb8sKx69yy4JtRVcz17VKFZ6HQm
65	65	{67}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JufW48Fb8eTzq2jP4M7psVaNRdYigmBzc6DGkH31vsud2B8gECR
66	66	{68,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtyCSMcU2UDSvR5CM61kozu4NLmF3rtMFka7bNVmp8Lfhg99xvA
67	67	{69}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtshN4iUsVpKrdLYo5oaiqMr4dCDLDy5NMs1Yx2tm3SpGJLcUP3
68	68	{70,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv2pHsK2qXQtvJpP23aQJcE9ea4dVZFH7caAodrBkDxgN2bRHnX
69	69	{71}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuX57L45VinjdESua3B85EAEsrWaKVhsuvCmWSe4jsefaWCn6cc
70	70	{72,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtpj8T6nzuawtG57Jft3bdNB5Xx4ugQivv1gh7GjLaif6YRMnwq
71	71	{73}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuWjfGZofCWp7kpgsj2sPRoi3cF8jsF9jrnjfYD3nsjq1KNyFkL
72	72	{74,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvBFpS2YaDioHMNaYB77ynLKVVUmNut9iXsKCv16fmDwYi279Ay
73	73	{75}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvCsCQaoxA3LH5ZQcRcogWiE8njtFsiBoA7FBxHyGfeWcHMZ9dh
74	74	{76,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuDQKadKo5pA1sCG9BQKCJ2rptTS9enoPCMauNP5vRp4J6whBpn
75	75	{77}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju4acRR3BVGv5cyZck5juwtAbM794mE7GsUH2ktFNgUZu8KFbS3
76	76	{78,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuRjofwKp7yfCzBcr2U9uZ7ZV754Nv98wg8RC81Hhoc1Vkv6wKa
77	77	{79}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuXa1Ub5PLhMNn7e7eJaFUEuFcMuhgFM1FSFZ6RLydGzYMfxsXq
78	78	{80,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuRRiYeXuHVrDUsJMBqpiHU9aSuDKrSNXCDTJNvBDPV2fdwMDcu
79	79	{81}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvNUZNrHpjmXCKLgut7qXLmyd7At8c46JY49kw8poNwfQV5K4J3
80	80	{82,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtwq6KvPTWdXek8wmiAqAZUMJhBgTBjA5hUv4WeMXD4tjuxnJth
81	81	{83}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvG8NzZ7tUgausdH6tFJydHNjASNaFMGCUTiDTqeFj3JemnB233
82	82	{84,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvNkQuHZLtfuvHZw52gRBSVwcPCqLnSs62oY5iLB44h7mUx94iP
83	83	{85}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtc5B4h3PKdZxGPb4EgGyo6eZmz1Ur2gP1QRzu8sk5fBgYUb57T
84	84	{86,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuFanvdwn6KNTr5t6rmjGvr8mCutv6VVQdUnb862i3wdg19aYGd
85	85	{87}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv4Fo3ngtmZGuVn5tgPTtd6SjWTwfLZhVBeUtdkXUbHzAwLNjhD
86	86	{88,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JumXqfV1nizA6zmYejemiT89G6emWEscUsQxeQpYQEc1sC2PsZk
87	87	{89}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JumHPFDsdrxnwzY14DwCwHgMP3aMzMt2LyCv9xLQjPF6eZeahSD
88	88	{90,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvLwgauTrhzVDaqAzguq7VeeAATiLudCkWKQX6EnHBMQSmLHBRr
89	89	{91}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvPXD3uDL5QtFBeFy227J7eHR3ffQ9cwiynBKUW3QEpfChZqnkt
90	90	{92,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvLp1srcepauETEtyVzewijA8NtQ5pCvqhKJAkerLan7T148Z5R
91	91	{93}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuipFVbVZMY5tZVWKRyFPDumaxVCeUTkbEUAwukhu7gbBd7VpAv
92	92	{94,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuEFupC9Ec9F46YW89ZHzhyeTmyK2DMhjXugPo31i2Et1NJxTsa
93	93	{95}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv1kXWLqwVcqbSzgC8fuqTHHPDNZVuDqmmeBrZhLHBbzDmC1zou
94	94	{96,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JthyoTBigSRy5A5qTotVo7j64Xs1jkgmQmHxifCGny4vBjCKtAv
95	95	{97}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuyAwP6QXP3rZV9M6XW49Jj17qLGZYz3DsdynaTyiPaTB2Cy9Cb
96	96	{98,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv529H5NDmyKNfCWcJnBLZ2jCFbCvo56Ea4yaikhiPGaYF674j6
97	97	{99}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvCKFxJVhk1mXMDSLfuzsAxU6avobk2XbUdAvguLSTP8gy9ozRL
98	98	{100,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jurq6sHU6nRxyBHWSF37VyU6zUJ2r2Dhc2HkktXFTBp4q6ELQWW
99	99	{101}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuQTDYAxbybCxyDkLi9qZkmM1tTerbiJB9y17eS97bv2WdTaSus
100	100	{102,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtpE4wkd83TRJMt7hckGzNKRE8dkVY2xc8vuTQ9uYheHSeDJShM
101	101	{103}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuhxbbZepyDMAy871uihiXFx9pXt4k73beGDePHkaSgb4KzRVuz
102	102	{104,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv3pGz5RiJzf4yL2ZWSax3ihUJkMQ9jdJ7qagSnDjvSSdonZuZR
103	103	{105}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju76FNfHWAEg5AnsyLNFnT1EWqGLe3ByuzaYrytgEXWrHJe2F8c
104	104	{106,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv5L8N7BAG9xeu7adaV41QK7EJjjxQdxMCNjA187EQgpHUxnTep
105	105	{107}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuDnmm4GXREddT64ZZum4ySw18YyKf7pMaHAEKuPtRj2KJGQ8UB
106	106	{108,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jundniav7gSrLWpzd5SY8RKijHjAq5mmvvztdqjgKcRwEYJ1hrB
107	107	{109}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtkCFHduVedfFuSbo7wVdfMHL6r5U2BE6rc7SNSX1itc6RXivM8
108	108	{110,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvHYRAmKGuaFdc78sRcXLY7hufaPgTRLKio57jP7A1Tj8wPM3WW
109	109	{111}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juu9fVcu6HHxZ6aMqkbxpwDXkSe7J4x9UWgTvag5uKxr7AxN3mA
110	110	{112,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jut75Q7SMWTzQb97NTrk1oiEje35pD6buLwnpc7gP7mg6Y2Aozu
111	111	{113}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuWnZiYKZJ7KDsBk6UHD2iGCh83fkPwXdXYcBznZYgkUeETdvn7
112	112	{114,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuSb5eHUWGDV6pnCLoFEtvi6ywb6dwPHuTmEsfvzXAQhJRdAjPc
113	113	{115}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvJkYo6CGPc2TH9H55fXQxzHdLCE9gA8C72Y3Vm7Atwk5Xjw32v
114	114	{116,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jttmsd1Bqj5cWfdWmuM5e8GdZyHxKZq9eWbndr9JoyW2fY6yqtU
115	115	{117}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuL6ewRbKofQUhiHbFGe3rrWRWWSRuJW5rXfTQ62uLTRJXVXTkm
116	116	{118,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JusyK4GvCmMCPEca3ujYZtH3TCijDguE3fJZZPQjia7omYoHDtL
117	117	{119}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuAzYXxgZATuDXrMptrBKF1DTjQ5noF9JdCvkCtqcWGh7M9cpa4
118	118	{120,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuZYosMT5kRDCPmHNDkh8TdxxLMar5UMLdxk3uijEv5aT8T69sE
119	119	{121}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv4nPkMa6MmxQbAS6N14hLqJZ8hZZmYfcar9ZVSq7XT8gXZHWLt
120	120	{122,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtxS8X9eQE3yEFBAmoVsY1XECQF92dY2GuJZHqe3CRGK5fRkS5S
121	121	{123}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuNgjqcJ34rhhnjNDrVSKqYRqn9rmTb7go5PUqpM7ZsHEMEatxd
122	122	{124,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JteLEwCFs9bCV3mVAE2ikZfsS6EoYBvcRQA537zvd3yncosaXNC
123	123	{125}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtXegrUz12iaP4J8Wr4EkGVYuxaDbrBp6YQFor7gDs2fEw47J8o
124	124	{126,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtr2KuxCyEnD36AkU82ySH5yUVmqTMW1RDnfxnx3UXE1FDW66Jo
125	125	{127}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juim7JTA3SMNujFoLF4tDd3FHuE8A9X5aKCNskR5vDzxzWNuQ2D
126	126	{128,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvJ3Edc78n5CWfkFmbUdm7D8MmuVqsK1KqUMbSPDHgn4PK3KMYd
127	127	{129}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtadJ7kU81WY4nCcoLrbhCrBx1HSxuU37NgzUfeQUEB2ECG3H6W
128	128	{130,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtw23bTukjGt7wkS6DWtznrRys2q3V731CxbUkfrnXbHqdw46VE
129	129	{131}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jthvsq7ny7K421pkEGbHYCESL1A3GHPmHuxWAnNGQcZQiSWoANt
130	130	{132,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju6adDjPRHchQ4D2pQycrKTDbBHAD3d2VcYDdMf4uDnV4LPmEgQ
131	131	{133}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtuf73V94f9t2EaVMGMTQ3TPbDAWtDbUnuAM1MPugaNGKg2QPG3
132	132	{134,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jug4npLAy9qhfH6KeM8BrzyaJtN7z3d5C7vMFa5hgyrYFxmrtMZ
133	133	{135}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuxKMApjCeTjFciJMNRgjnKKxax5iHWrh5PwsqzCBVKCqrzZyNT
134	134	{136,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvH5LHo93nUDwqgYD8KbXx6E5rqdKVgNZ9NHDVvFhGasTHbDC3G
135	135	{137}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvQd5bGPRpyr1YBvf1aAbPQh2W9WDWinaDLUKPHG7bHpawmKbpj
136	136	{138,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuCpr7AQAUBMf7NXKg9AjVa6D1QH5iLCqtw8tt8fqnLQthQaQeR
137	137	{139}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtzTR4zTub88Z1FGGnUQTp1tNe6nnxU6E7ezkrpNnUz1Qgj4FAe
138	138	{140,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuCxrVdBi8rUJjcbJe5fTWj7tKu8apZz9KYWgDJE2TFnyBkX8Wq
139	139	{141}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuQ2cpUindGbKyGhFZZ9surgtWvgmitreZv8v1ESQb7nH1m675V
140	140	{142,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuFYZXGVzVx5WYeACjsWuyeSvK4Y8Qnm6VEzjfNAjVdM2ugYsuc
141	141	{143}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv5Ksbesd8f1h1ShHnYmePqN1acCcrLbND5nXss378iLWm4Edyx
142	142	{144,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JufBChAEo3XtTtjnP7V93xDBZ9kCDmraqRP29HLptX6kqmyY26Z
143	143	{145}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju7Mfimo3jgNTNjdcR7p439MjTPJhiPEHJAZisM3Qz3SCMoBpGo
144	144	{146,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju8mgBygYe3zWkckJB4bbrLLYGMwQz5ZAqb3CbG8VgbcrAu5f7G
145	145	{147}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JusJ7DAwyWxU83rB2YkNsdn2fbbHbe9K4fpuMok4gkYFVxMSjNg
146	146	{148,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JubVe3EZGFNdpcny2pQxZXrLtcGCjiKNrbYYaw5GmvJqiqgiJ2F
147	147	{149}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv9b73nDjo7dfzmiYEVaWsR4UkGDBjXBNP8PS2fVxfZykkCArgR
148	148	{150,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtwRiVjgYixEPAr79P8SVxHcoAT7yHdnGeZxNSkMw8bPFv4oMG8
149	149	{151}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvNuk42xhkPLz2GaHyNFQukjFeTccjbecyzqih8QRpi57mYbAwx
150	150	{152,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtj2pprC5GBDmMsCN9UBaa4BZNvfpEgzNsKEbDSvQuziNJ4j2vG
151	151	{153}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvMEY7VueCrk8K3vWahBUq95V4snnos8bU7nmezTARdZd3dsmbi
152	152	{154,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju2yuYykWVkQQR9eS8rmC7jrWdM6smBEXxAk3UkCHbRtgqhRkbP
153	153	{155}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvCDD4CQZ5YrAENKoiQdErR4mKFZBdgFNqBiu6yVhDKzL11jwk9
154	154	{156,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juk2QYnz2nFbQ6xoZQWmNJMLRTNwuXHZ2541wpASQYiZNQLVUyR
155	155	{157}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtmPVL17VRPVNddWFFgoLnv59NZdCSpZwqWmSbe1QRwT4L5BrAn
156	156	{158,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JutSLQMPpYPCAy7aJM7DzRR3uaM6kiyCzMHWQntzxYXieHXUEHp
157	157	{159}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtu4YMhV7W4uLHPRqW645Z6LHyQfNDAexXmg1aTdDSrj6zCVrAW
158	158	{160,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju7bRRQyVBRdnp521J1vUfPjAv5hFDTvco64WjXwiHt7HG8Exct
159	159	{161}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juq15Xz5iLhp92YsbDjkAbN7GyBiGVGhtx9ATiAWwPPwA974c2r
160	160	{162,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuDyFNLnyuiAdg3H6v7dcA4MuHLC9qBGzsvfT5ZZiZ14fX8YvkV
161	161	{163}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuyogPJHU331SeV181ppyVUujuna3euVwgpnzWc3speR2P2VYuA
162	162	{164,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JucRuF9q9T2mt1PEDQBHqiLB4JnQWqydMJ5ZHFgDQ5UK8V188vV
163	163	{165}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuR4799MUBKaoA3x9ManWTgjzVoBa4so1bdB1o4E4uSAnKZ3Jv7
164	164	{166,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtYhvb96nekNMzEo7rZiF24NdJQKJckeG6PqrjDyBUhNDF7D1KL
165	165	{167}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv5QpM4Av8HBs3rDfuqaqsGSEy5QFNRgErHJ8KGHksNWXZXShud
166	166	{168,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuQxMXcYzYQXgha4nPP8ySKXwhSSTeebc46t7xkZN3vkqkL2qr7
167	167	{169}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuSw9gUA2gfgFnRQ2TrUHhVhdj5VR6YgUsQfWs5skQ1uyCyQmVe
168	168	{170,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuXLkdLq5PardKvdro3qE6SJDc8VFRNW6yj7pHDy8cYB1YZWEi1
169	169	{171}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juy2BHH9mXVy4hbYs1psEHmhguYg8iehuX6uXmbmfc8ub1bD5q4
170	170	{172,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtanPQ7Duvy9hXJtFwjKXgf9LEmueDmUiccS1iKaJPzRjrXsEc6
171	171	{173}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuiPUCvCQzcExrkxEEH5rRmbNtzD2ES7BCWitwodEJt3uAFg4VJ
172	172	{174,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju1oqtFDWHTjvQ5oQgpza76kUg5mjczNqzvxK7pMTPLW4yH1ziG
173	173	{175}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtcoMHzNXLrR3v5zwuXMD67Y785okKW2HWKwxD2eSMKngFFDSFe
174	174	{176,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuXLW4GHobBqQVNzH4VNEN8mcb4BfvvRPrHjQPqxuR5ecoXXwF8
175	175	{177}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtjczYbEG7n39RdmkViK8MZm1B3e9JXBcWJaUsRYSRwQk8KesiU
176	176	{178,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju8sAkMFJbADJtqqxPUmcSujzB7cMu4DxLYeYnH6qeZdUL37X8z
177	177	{179}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju3xe5j5o1HPqWJjPxZEpwhyJZiFVAsb3hYgEvH3B7eQ91nSz7G
178	178	{180,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuUHsATud4NGTwQ6CSHezT9BP7RnUKbs99Ubzo67p8W178Et9ZC
179	179	{181}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtgF4EuusftBDyKjr5K8zbJS4stPuicacS6zbG9sQzLkpV8uv7o
180	180	{182,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvBJQmZsxwy2shEc5LQuArrUUmGD46t3tT6ED8uBe7cXTddQpE2
181	181	{183}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juz6tfMgBW3VDSNqjZjNgHtGpsa4REfwBZg36x4cR3E4xjF2qhw
182	182	{184,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvGGKxXfpQHxk2a6mCZBtckHiZD6GT1BpFET1b4e2JEkD5dKGBF
183	183	{185}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuyZMqB9zz6dueVDwbBcmrr19TR6u2qyQUxpvyq2tGy9cArrQ61
184	184	{186,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtqGj7ELA1hGA6MZE8KPQtdgwEZEPhVGrTJ4xgG9d5f9gPZmXDw
185	185	{187}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtkhzfMwvkfPuN4Dnta4a4mXXjGQia9cnHSCJnDGQNRL5piYp9P
186	186	{188,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juu8JE1K9EyXKiYijT53jDW49aEuFrBuMCbzwwMCMcop2NkqNpz
187	187	{189}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtbG4F1qRZa1SkSi2zod9mtsPjoxiUAULLptn61pXuM2cFuRXXs
188	188	{190,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuNiy96sdq9wvsMQM8VYuFsEFqCHubrm15t8zcSiZAs6FqcddcA
189	189	{191}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuM78qskFgb5qgi3i6ZUwEGpQzAckYuikRGJiQvCtR2SQJMixo6
190	190	{192,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtnZoGkveyzpDcMmkCDsZ1DLXK2jBJfrS656NHcmjHZcHBMNwzK
191	191	{193}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juir7czNx8Gb32U6g3u9sAJwM1aburHfLW16HyEMhqniMf94VH6
192	192	{194,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtgXt9VYME6i6kNoshciZriCcki2c223cM4FXmR84GoFdHVniNu
193	193	{195}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JubFx62yNVVFiKUhnTVmgeLGeuiQkXpUrWhvKHzjKJDNGofbSyn
194	194	{196,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuPbK4dbqUZDoWiRuRHZ79rq9PvyvPmNUSh23xBiRyeZNwJwemN
195	195	{197}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtcdjjtdqwVN52MXY2K8AfBfXeEaF88hfLMxTzDhic5WFtWdzbE
196	196	{198,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuRhWJfXWkA4nMKuzRgb5BHK5ZiC45ksV8Rmjak2Foi7v6Mqyge
197	197	{199}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv7Fa7BxbXRDbMs3XseveTS3HUq3xBptTxbJQmCiAkK4FkUKmXV
198	198	{200,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JueHKE7y9RF9W29G3PvaqX81WA8BB6emyehTDFum8A7xyS7gSu1
199	199	{201}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtymf68DXtxeUjXvovP7rpWX3wxuHxuCpQvCpCpYoPWTnk7QSDW
200	200	{202,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvL73Jjg6XVZWe24vSkXTCM4zKfYfVu6cQQ5mymA2VSvAPKs1B9
201	201	{203}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtfJ4hG16Mr8KBc7pgTBdjRAEZnSFQCAi8jxtJG6aHBKFDrPYZ7
202	202	{204,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juhq67zgF9YjiPMXm8acwwcFgZ1e3p5qZTRLivsyhT92Lg4ZQAX
203	203	{205}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtyMN3uYHo4kjxLEsYLF6iGwYBe6H2i6CZ3EYBkTMB76aHGKSTY
204	204	{206,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuE8BxfGugCnEbgnVHnTyeoiyFzoG2PXdMrRzpVygPkcFdUvdKs
205	205	{207}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuCw5syNZ1Qd8gZRwjTfWGsTUZ7eo1xtw2Bre1jBuyz5yRBfJEV
206	206	{208,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtq4WKPqSHxgsVbKycFvSXWdPWucmZPQ89rvpxxyS5dKRzGWd6x
207	207	{209}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuRTFyRJiACfTALUjpRjqfeBcTKMfXfmz3bxr9F4tML5zGQPKLA
208	208	{210,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuPcJZcJVjTVv3Yh9Hz2gyqr5rdKwP9ZHE3MVsunkAW5siRtzdN
209	209	{211}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuTxuufGu9ucGavdGbHyAbcF56uoRbS6X5w3CYDvJLdmqUMYkVr
210	210	{212,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju7myiMz9KgoY8eM7ANaS5mxYHgcDAnH6RjBESHL2Eqa3D8TcSy
211	211	{213}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju4U5iyWSEUBABUi2nvpdk7aCV9Gvy4SJ1giX9eX4owgGfsq5yP
212	212	{214,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvEeTVMcHXqSgm8nbBx3UFMzxxfziYZh1U4xZzG3sKsTVmsmLCP
213	213	{215}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuF4NSeL6DfJKigMiKZuWRLAW2tGDK31G5qw2yG6MezKFSgrnLN
214	214	{216,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuGmpXYssBa3DC3Y7JQjLhrJWmEzfJ6xeYzX41vYNCuzxzsWKv3
215	215	{217}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju6B63VZW2C7ftBxhiyzDepnSnrcXPAuzS9G8QqZaZee3YPzHGT
216	216	{218,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JthZG6HyvfbQXMBMtXxDkj2EET3Dk7VV2i2nadM7BQBmZANrExn
217	217	{219}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvCQBktbQZYVZ2rv44TjFnkSi5N9Hnq1EJxtFeUnBiMqZe2qQX9
218	218	{220,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juu7kstgyvzLUmYGjHWRpy7dpb2c5PCNdEWaPVDGULRbDBvDNRS
219	219	{221}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju5rGBFpheh7VmKAQAfsFVMna1gGQSHFL8BqmuVyZFBnzhTDH79
220	220	{222,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juu6MpV5JJe2UHcCmwU1Ww4JADmHn2ccmw4DLZBKbLARhoESvyy
221	221	{223}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv9JmZB8EaKwZ6oxBjob5H1SYsJE3msCrQEuQVS3y8jxM2Hkvd3
222	222	{224,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtm1mpqtuwC7dXpwWkmhuzj521iFvizFMCaKaZM4RuWdfCwFVkb
223	223	{225}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juu2jCKvxrZpwkamjgnbLa39pq2ah2VT2Wz3Af8C3irDwfdgo8f
224	224	{226,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuwG6waTxWeDuQB9ygkyWimF5LL4g7NKtyZXqTXpePhKXb1Lqd1
225	225	{227}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju9LeDwCwC3hgPzYvf5to3EzHmbWsSisVivAN1U4LTQoqhFVnC6
226	226	{228,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuY5hY5JcnZM8Cgbhsp56vtLrjACCUBXuxCJHMpqMTz175XMbYx
227	227	{229}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuRhrdz58rmrLvsffSwHe12zxEGVAnJm1yWfZJRzoi3s7KHZ2z7
228	228	{230,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuTDRQanBxkY3AsXTuk2Xpo4kCi4rjPDChxZzmVdqYFf7BudpK7
229	229	{231}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtZgm3xdn9xzeojoov7EtQ32K6PGZh7kGEtreY56uSJtgaV97tx
230	230	{232,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvLHcoSzJVt1h81g5J9i2BvqqbAx3vRfpAH1tJNEm5Y5ih7yjNH
231	231	{233}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuHP5JCwrB2CWf4MFydHq7ZbUdgAXTy26QsyefX8QTX1XxrDRf8
232	232	{234,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JthtDZvnRwaGmg7SYJM7SBHZ7HwUrED4Mmd6rjBL1QtJC74tNTm
233	233	{235}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuLeo9ZTKnMa2pUHvNQcooXi65TVYnvVFmDCUu91BsFUEzojU3p
234	234	{236,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuzDmmDcrQTMa2Q6eUfAn9eh8x8nZnE9ZMW4bq6uqusk51q5DpV
235	235	{237}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jus4gkoDV32RjYMxPsRTD66nY11GtWMfSi2WyL3cMPhPLLXyYRv
236	236	{238,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtd6aqaqB19uKNQuyJzhShvNyktg6UoJ19xPYi61cG32jZyXcUB
237	237	{239}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv5gbZDSWP7C7GZioSzd2QwaoqymVdkYSEZZdh1751CDa8p3Mzx
238	238	{240,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvGNJKwzxkRRhS6KPjNxJSgrn6MrKyCXQwNZ5EdLF2NLAwa23By
239	239	{241}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtWFy9XPinJHmwmSiiE4uYDxmhcNCuKcLWcHPxhBUfdNZ5xtTRn
240	240	{242,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuCdk3p1mGLaY7UFxGon2CA5CCfUhGf8RcwBX5LWkKRMtcTxxQ6
241	241	{243}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtnTRkqN2XDfaHTHVGrY4FyEurAvRLc7UwpaNmw1iPnUAvbtLLp
242	242	{244,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jth7cZvSRfdc94cF7WSg9QMJj1FMgQfsbijGYkxCoucCJ5ZtHBr
243	243	{245}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuQKmV3CjKcPkpo1o6gx3g69Bo95PBLhVXzrqWU4MXQbBS8rX9s
244	244	{246,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtWCGRjAjzRJsgSQieNs8qjKQRTk5KhL2r2UqraEHEiTrwJnFi1
245	245	{247}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuDiB1XadKajy3CsxL4YBxs84w2Fa3R1EFPna3yCVXGPE8fpf2q
246	246	{248,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuGtV1NBk3t1edxnW6Jj6WKqmhrxo5LyLYdEGKNvk6R9XrpRZ5B
247	247	{249}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtZwwzTYBSKKpn6HuZpjvmRW8bCf2gKcdrgcfq9BL3q6c5GrY61
248	248	{250,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuNgxrs5VF6pwj42QqVfyg7W9sKVc1XifjqTi94HKYxPbSPw9AQ
249	249	{251}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuwrHAJag9BU8Xg3eqczxgoyV8MKzjDrjtwEADhw1Ef8bMLq2oz
250	250	{252,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvS64WdbbdZhKp5rwuUext9kKwxic6QeMRpEvveXs9bvkGwzn9s
251	251	{253}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv3PNRupyowXQvkw4pnEszSyQpXHf36UPWmkNmnkzoinUERkXAT
252	252	{254,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JteJzhS9ksZtrV2N7He7JRdcheUHDcCSkw19wKLQLL2BTVipc6q
253	253	{255}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuGRh2RyaCw1KKrfxoJHFASeqAVCEBMgzHqwSd7rzpH4KPX8AsZ
254	254	{256,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv9iMzBHoodymXr9v1wzKh3YxdFSZbnC4EkwnNx8SfL5DLNrgho
255	255	{257}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtkjYZ6axbNayuZVeQVQCBtWLB8hSdpGK3op4oBcJUxYJc5uiMo
256	256	{258,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtcJqi5PJJrqapaaPEJw81rQH3nywjtdiRkKALwFJ52XRzVZwoo
257	257	{259}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtz2Q95WEQD2cEcL7KJt6QJvsa5u4oK1dtYmJSXycerz5PfnbDQ
258	258	{260,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JusVZzm9iu13UsvVTE7PN2kitw2yDLtXKHZpdvnfwrWUP4Qv3dF
259	259	{261}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuqgoqoFyLKR9pRWBCP1eXnm6zF86xBtE8fBGsH7vT66hDuwANZ
260	260	{262,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtrb6tpe31sadbtonjFRTv8eCCS7sCWUhiRA1pBvSKKVy1tWMrg
261	261	{263}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JumarDfWvgw6zxGa8qbv89zUyXTmRuwkNj6aje2W1XcAaivgMhX
262	262	{264,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuTMptteyzGRfFSi8WZP2uP531Bp4GomMqrf9QDTjZZDFtDB14p
263	263	{265}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv8UkUhdpxsB54cNYgtMnK4hmmcXqJ3gigE3SBedyAP6kPQ4ATG
264	264	{266,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv9775wgATzTE5iyx89reveYq9UwDJ8RH99KgeRYTB5MLLd63L6
265	265	{267}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtrQ8vHJ2k5xRvjz8bEWqffzrspTTYUpZ36NGmQTW8iDCvD5k8v
266	266	{268,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jten64s9ZAEmCRLs4RoRCW2cGTbobhjsAVVW2ZV33j4N3GmwADa
267	267	{269}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuUL2vGm7A3bfXRGfWtwq4hSiBVhz3oSwXQpL2XHmsGGD7isYjn
268	268	{270,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtZSU3w49Tzp1dpw7CUgq8afgcmbmNMVthvwxPB8UExttdBMHsn
269	269	{271}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuHxiLiMV9B6QEEyfrgJK9uUGJcNUKpY5E2NYJrVifRxDjpJNoR
270	270	{272,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvA7rQ9MKcFSUHtg7kX9BKPgS9jsRJGSN6FPizG7A89FXQgPaWb
271	271	{273}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JteEtReHnNtHH4Qj2JMwJ7PhcpVcK1PHbXv2i4Mr6m7DMtCMH3D
272	272	{274,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JurwkgDSyVQ2if8euroV6rjEke6cUhzWF11M9kUEMVegv1Q3KCv
273	273	{275}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtZsGbNA2GDHi8FKBeypAkRoqzuTHdjM3gLC8iaX1gbLJerCt3G
274	274	{276,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtpDMXxWsDo6sTNJfgsUk1Kyfgo8dKjyKPbxqTPHSsD94BTATgP
275	275	{277}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuaeYboao7j1Y7hK6jqXUSFqJC4dQH9qpuH8M3vnCyL1KU8VSvW
276	276	{278,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv52zsK7FrRSJHQFZqvA7GnrZEKVP9FDHkN7qFBzm81xm4E7NiK
277	277	{279}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuENPhUhwCiXrzBpa8wGkGSjJCHativujauSTGFgvV2X6jstz2A
278	278	{280,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuFy9tGxqDSzU2KBRgCZbqPKBF7gMvEaEMAYJkmnuuqm9M7wdzp
279	279	{281}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jusa6f61hLHMYtWxEtFnfFwPnjh1BvYz1k88oHsgmf8Msm4vV7o
280	280	{282,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuRPCqZMsNRA5W57WjZo7S5b2jEnvb2Pk5yeTC3motvE7j261uQ
281	281	{283}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtYwyk4wqknjBKPGuW4v95MckGnP5oL6k9yhRiGd4JiLMVvq7Qo
282	282	{284,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtf4UxFGM5ZHrTGB4ad7MRfdizFNNEA66XVWTfuehKR57xgeMCB
283	283	{285}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jue3HC2WE6h61AMf1nhQr2vXCWe8GCjhcg8J5Umue1r6Wv2HiM8
284	284	{286,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jto7Ch1WERZFAsH8YwuPboYCrYtLmHYWq1iNUQqs6h2L8L5unPP
285	285	{287}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvL2LgQgNupEmZho1JL9KZRHJ5SiqxmKt3EerJjhPVoJH6Ygkvp
286	286	{288,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuNsEmP9xvdbViKzSnfLsKMsfQifu7XMCYcUqhKhBfNZx7xKUbM
287	287	{289}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv6ubCbwq9y4Qak9nbFpmZneePL3gDyUvmUJ5azyfZpby3qSC3H
288	288	{290,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvHyvcz8zk3J3q4GeTJyuXWzxWCi37gQ8DjRxNvNEh1HGSXau8j
289	289	{291}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuX3xwnwjDrjy7FVCPu9HtapvezFJ5dM6N3hcVRe8xZyKDUmCSA
290	290	{292,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv6gpSFT6vVLYgdtF2LEY3UEzFuVRGQ9R9mQjVbyRPySH6P3F4D
291	291	{293}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtwEiSbWccLnYyqGLhF4JCv8fvYVScVvVWeUmiQpZPxv4cEYi5x
292	292	{294,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtdLUbpWPnGNVeGkfxbsFWy67EmrsxxSoANaM5pnLTTNUDQRg22
293	293	{295}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JthxDMNwW6c1xunrKsDLB3SrSqivZip1Bj9Yfph4FVrSTCwyE86
294	294	{296,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv1WguCbzDh2pivjw64NiZLdE4s2Rf9mCAJWh2SkgyX55GkYLLK
295	295	{297}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JthbvG3ZDsfx8ugg4K1jB4RQXk5dCSJHFapoR8cFppzKsxuH4y8
296	296	{298,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtytzWKLwM7pXkdEKcGjLDtjo5iVq3SsE1L3t6G4PFkSJJAPhh7
297	297	{299}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuJ2kceo6zmfhRGpqnYafhFmsgdHwCDKG2R7P76jYtHujgKsjhK
298	298	{300,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv9w9fH36s642CVY1iJ5X5VRAa7qYCjBNEBmKiHZYMyskVSZ64p
299	299	{301}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtsKyfi56jy1qCtHP4gopQ4X59RgpmRBN7SMeQXGeHazA3dDFon
300	300	{302,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju9jT1M7JTjzV2AgB2AT2ga2n22VvSk7DBzHqBaSaz3jz6UH9Sh
301	301	{303}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtdv1XvACqD8NkmP1pAEmc7TVtzvgzCSn7a6F4YL8eQqoNAbWFf
302	302	{304,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtiySBWt7AfoQSkim3ZjCeHxjF2eWxyBgfwUL5B9icCLrQPUwei
303	303	{305}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuzTw5vf75c8jL5mo4g5mzEiMAQng5WidNSHi6EKbrxxUTzv963
304	304	{306,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuDTgNLE1Su6Ewr6HdCJVJj9px52W5VEfvcWgx2yW8SgUWZTEFR
305	305	{307}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvKzMTMudK6xDeEw15ssSjGbEBBpPoXsooLSq4TmUFq1BBRcg9w
306	306	{308,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtwGBkpF2MnwBFKgBwNxPH3swtp7BbjueVuRMuLprtQ4Yi7pRPw
307	307	{309}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvLyDWokMmuX9L6ULpermYUbQZf5e8A8aPUpkF8vg75m6WJxvZF
308	308	{310,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtwHCmeec1ESaJhh4pZHPHA7N9w7MqtQbcv1HjSn7cAVaFvKdEy
309	309	{311}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvB9gsdd3eECcVcRSNND8cteZrdbUqh6pEd1pcCTjZHSKDv9QqB
310	310	{312,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju8JwueDBHoVSvsfdL4jmJeA958p25v8Cjgs1L1sJkajs14JVUz
311	311	{313}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuPBkfHvfUoLkDXvN3pQnwJyo9GVJqkNoRizpUnGY9X9DQV2WKZ
312	312	{314,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtbTwyQcrWVV7We3f1TrVrmKfdeFpin7yEteYGAXP1cuU7LYz2X
313	313	{315}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuF5MKaXUACjVzsSc4hNxSGqxqkP6fV2CUoe94iKaXstTxDHAMM
314	314	{316,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvGqEWABL4WGuGJZgU8y5aQJsdC7xBdjh3msqfcYxtUNebYR7SE
315	315	{317}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jufovjir7HwsNCbxLP3Gbbrp34PdyyPx1TkRM5fdAgJgwM2baT8
316	316	{318,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtZ4EZMBGkpQZbcw4wKomb7Bu1xzPnsFzkXCUZvsveKVXoe19w2
317	317	{319}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtnizWFhoSMU5mJxDEXUCna9agC6e7qqtqmEWnwvsu9625Nt4V5
318	318	{320,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JttLFj9apurVASmHMrDUs9qYczDm5co2wrtmeQhvrxVR6ckUdQK
319	319	{321}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuW9nLKCBDiwDHjFHisQ591SjRbwhkBnukjBdbPvsgbtKAXDKEL
320	320	{322,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuPTPsyXMeAbiMsmKQq5EWocDTWoimXQP8rjJ8DvaV9rxLQvp27
321	321	{323}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtZvo46GcaC25FFaC2PgHF7WrAsHo8DvfabjkrLiy5mqp7MqU68
322	322	{324,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju1v6yZtAgWmk4HqLHVGCsCiwefvPyPmFjzCZmNWUMNfgkczFvW
323	323	{325}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtfci5d4ZTt49CkMosKL4TS8jBaYiBLvbHAKi43AMV2Y1DX4zn8
324	324	{326,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuBSmNNiTEPfGeWFEPKKKUFN2JcUGNcJUkvqNcev5qyHPcnuvuj
325	325	{327}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuzijuHkspm9rBumzkZbY8277CgVXb61nCp58PNoQW1xNHfSCwW
326	326	{328,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtodTWLpF3XqbN6bjMB8fGezPSx8TrAug5wynQRjQ97i2CnEs4h
327	327	{329}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv2GrrHAejGYeciMmMWBgTT44gJ4omC3fX3poWfuThQj9kpYaPH
328	328	{330,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtnkvenBidycAWVr8pKwbuUq21TfYnDErGCxFqQDYpfJUP16XA5
329	329	{331}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtzYtBAoXG5rZrR6981EybSzALnkHpfwnRgi3Ud6KjNWUyEvHkP
330	330	{332,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtpSh3sKjRqA6cYEu1QKsAjoiFnNzhNfdkS2PSqzbc3AejdvSFp
331	331	{333}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtfmSkyadTYdua1NrS73xHt5VzWwgvgWVFdTMRW9YLYcxe1zWec
332	332	{334,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jua8ppq4QYkFRFG6bweJgZQDoPUiGHcDjTAzQ6VsYUu4VRme9Uc
333	333	{335}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuSP8cL4xPWqB1uz7W93G7h2bkGN9zAJ29PH9t1KzXu9wUReuFo
334	334	{336,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuxbUJ1hhVjvqffL7fjQgxDKAFpcxa5gj1VkWaWjvsgNzE4WpEP
335	335	{337}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtf4QGkRAMAQfWDAMfGTezXsxsYgGCcb8dNWLUPuGakUnmgNzoz
336	336	{338,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JucMKu16TieNnZzanLnV5yTVzPQY81DU99nPEPmksxTaVN1UtuP
337	337	{339}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtsAotQft8n8pp9CpLz7BkaZeFBGKJQveHECmKXuhKncvuBCW4g
338	338	{340,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuumFsvbQos3djrK5mG2gN8L6hWVBecEmBDaKCDXkaEAr8vsNQM
339	339	{341}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvJM2E4ebzeARRpcxsvvZz3RmVPa6H4mCdUp1ycE1b2ygMK3BDf
340	340	{342,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuWTnhVSSoTMqEEkxaWx8GLchXnysXVaDeCBBE2rNJ1E8kuzt68
341	341	{343}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvPDAw7VXhkDKQ1kCp61BpvumiSbaMhhT3gPNZ6ugAm3ZM5pzm9
342	342	{344,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv2VoiVbxezGRjKhWigUmaSuanHEfHe7vY6kGGWwtKZEoCzPAPi
343	343	{345}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtqTEtjq33cJ3UAHoC3HnmEF5MAcydmMGDLC665d4BaH83cprXB
344	344	{346,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtWwTyMBCAggp7sHoPeGj6W5jiAoaHZkzmaFGnhXSQVTdFUUv7Q
345	345	{347}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juu1m7qQLV3QCTX6MrJvXbB1pAFHUHMfcNtMsCgNuRNZGW4KMqb
346	346	{348,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv4fhZMundHintV7tpFFHiY6G6mHjocrXJToLw2iNeu9vbGsJF5
347	347	{349}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JthPjP8Wj1SncDifAEmEuh5Ng3U2NXqPDrLEVrtdjes4RXxgtJV
348	348	{350,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvQh1Q3dno31urNdBukjEeFvHEAHEyBhzkHbrSrcNNCAbxPm7J9
349	349	{351}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JujcsGKH5YjK3PoU9TqqyeKa6T4FQPyrpEYpvrUfSVboeoskYpZ
350	350	{352,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju8BiEGTjwdWNGr1gbksKAWkSb9GyrjGkxUqMno64wzSBqmEfng
351	351	{353}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtca5bgfXVLFb821ZwNwBL3vqdSeZ1o8vFTi9HpRzYrqFCGKE1U
352	352	{354,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtxfCesExUdkNDuAcjfDezx2V3ajsiFhFJ2wVGGWm6z4H5Gq4ri
353	353	{355}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvEbNgA6WtWPdS9bb8QgoAjaiG6DN2q2kq5uTGvtLeB4XpCThiT
354	354	{356,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvLuhBBZse7ipJANw6qVdobxqSasGKnd98Cs8aauhBsKiKVYYS7
355	355	{357}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtwtN99PkBkPxEsumReyX6atUwp5AiCtAtV61ir5a3UniMmXrbr
356	356	{358,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvLrLmSekqNV1x95SCJj46fk61x6ThZvSAXLmTELfrAh7kGumh3
357	357	{359}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtnPF1MgBKVkqJVMqmSUtJPA8nZVGHPevFnsGbadmk1wcz1Btjg
358	358	{360,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jugdb3SEfhXkTDbrcehTqEnE4kJvcJnKnAjnn3CZS6JiTYMnRhZ
362	362	{364,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvNHL4LhqKXWK6kfi33pj7GC2GuWjr4CmkuJ3RMF7ia9kVjd3W3
363	363	{365}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtYydRWHBc1uXCgUjpt54ZCy7Ld9yNPwtBa6iwoimR2pHV6ZV9V
364	364	{366,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtc2YTzzTxCWLt8kw3jaPG1Hf4v3xeboVWmNZrGoSWqkCTbWgxU
366	366	{368,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtiob8b2m52iCh1tEaYpoiGokEwFfAtpG9RWq45VA3ZYXqCVa2q
367	367	{369}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuT4C3oog1AiG5YLnXbX1FzY91bSP3siXMGSzPw47c1EgtgAjCo
368	368	{370,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtt5URD9wAic4KVfFMoAvmXjb1K4RTQEy13Ni8gusSP9gdTEaqp
369	369	{371}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JubKjhd8ZtXBiMvw6dv69n8rW2RFA8GLtggnvkjNLZZDqG1AjUu
373	373	{375}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtg7LfHFpYqLD8EqUyiwmLCFFxXeKcai76EkGHfnuP3UHjsfNhv
374	374	{376,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtgrHgdDkUbXUpzjUUzowmVGiCdnh9DceeQSmJ7QNkxHPuc2EEb
375	375	{377}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtjwrpLcHMXHMR9rJVvgUko3sBw3tYjjAE9zaZig7yaG3JQUEY4
376	376	{378,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtqRf66uHLG9E621rgum7yFUn3rBCXSgWwVWMm2GmtXREgwPLJg
359	359	{361}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuozzzKvuCGpoXr7cMxh31K5wDfH1rR5piQtJvFUibZWHCTt7Zo
360	360	{362,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv2NRkJrn5nCCy6tLAWrmq8a52qM79am1wXnJ9pNwgtFKtoKkNp
361	361	{363}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtk7UttEC6Q2LdnvpntuXAkK24xZVMpPbBNDkK2yX8gF99yb4sY
365	365	{367}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv2EHZzaG5hFi3G4HfTrEn77ghrZoDRkVYJ7jVQC8B724s9aXU8
370	370	{372,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtnGQJaRjHF9Xs84wcuG9mxFAtThi3fSVU1T9PB2vRmAPEoj3EP
371	371	{373}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JubDfAxReNRDTnzG34oDeg6BD8yneAySXkVy36HYnJ6Lq2eR68A
372	372	{374,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JunAdM1YFpx7tU63PoyLVCBe7UhUQ2WkGRouJAZ5FLG4hq9LHEb
377	377	{379}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtgYUUYK12eg3sqwcbShWyT3JUWa5uYhR5CHn2yey6bKxYZcYh5
378	378	{380,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuGUmu1CjmCvRwavt8jkBkngSLW68UdiJkUM3MDDEssp8mjq6dz
379	379	{381}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv5pCHvS6TCn5BpkfqYxy6F1TrU8f1wcPMhjT8RmSQnMDccDrm9
380	380	{382,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuHBqGduffVL1NVv71n8Dhk9mUvK6cQCEFkugpSsfGiorcU5ZwY
381	381	{383}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuzRBeQwfKzn8Swo4JoVgJcM5xNCXd7fy4JLuoFRLip6pxXfcpx
382	382	{384,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv6xhhLdtxH1UnGjvdTqEcGJvUnJn9Gc1RK3GcAYRTzFQ8TrhVs
383	383	{385}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju3zEXZKmgqo91NMCXkijexNTZWMwzeXZUXXkSXBUvvMpAPpTey
384	384	{386,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvExu4n9giwEF9JGoGpF62bVo8dRgpqUySeDQiGdNo2G9f9XDLT
385	385	{387}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvLwrpkuBJCDy98oJeF6gTeAKqkYBWJ2aKaNT4YmYamTD34K26p
386	386	{388,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvQMniSXbUT26QTNpkbQWUzTGPm4Dk38dPMBuafasBBWWNpzvXy
387	387	{389}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtwdpJxKJgQimmPFDJ66j1GfMSLYRDuUSbMb2ytJSKriJcbGjYW
388	388	{390,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Judxxc56YMr5JsyvSwbKrPGd7sCh7VZq4QvzeNFweGbbmwihV6D
389	389	{391}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JukVBpXb6rqdMdqZHb2WP7gYXBmmRR4rhAD4WrSXcR1DvWuAsMA
390	390	{392,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtbopxv16AsGZCm1BAXS1aARcSprKpVmCtkLduzsq4mmNjD7XW1
391	391	{393}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtxK2UsX2CLvpRi3vQ7RsY7cvdXYRgN6RjB7bTZrLkaEu74jhBB
392	392	{394,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtjC7e1px7SoN3fm5dauMQEcyqCiXXDdZJNvDktMGKTN7RWvJkB
393	393	{395}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju9geBmYVE7Fr9SUoMjojog1TnfcB6z9A3SkWDgv1zmKJ8hVTgV
394	394	{396,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtkSNBotE2LZgeVRY6bni4M3595o64PpoQnPQdF8QXeDp4USDR6
395	395	{397}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtmpEgXJQGfbEqUoh5q3LqX6QppA2wJhKBVqxWd2AB6efGT7TUr
396	396	{398,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtWCfPgELPJoY2vDSTWngPA9NjFLFGuBCf7Ggk5ot2zQyc8E62f
397	397	{399}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuRZAuaFURf9uW4BFJeeF9sSRc1rmSeFrLGjLayDGexdxB24DMN
398	398	{400,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtvNNr5EAm2qM43U6JA6J2C8dsr11x252dV4Sy6H96es1oWGbmY
399	399	{401}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtwd8LaQXKvTE795ZffznyM9J4zkYUiSAqviMQqYPLG8HcEGvzp
400	400	{402,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juyf1tSbJ11EC1K6qDhmPKDGi9HmTPF2wXZrjGsycrnbzPFNWqP
401	401	{403}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtcbJsB1H7uZ23L4gDfNYiqb7XVk79b5mCHQuwPWN5C6XUGwCMa
402	402	{404,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju6tHg6JZA61H4XsQm6wFZyo8GXYYffqsnUZy4oXZo9VHF4gy4N
403	403	{405}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JucEUVLSoHB9zu88fdt3MKc2eaymUhrmPb5aig3Xqn8VjbRX3qc
404	404	{406,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv6yS5NopBxFLStpsj51Kv8cxuCWRgzrrxYspaAyanM4thYnmL3
405	405	{407}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JurVaGUaVkF7LEWMgYfhViaM5jJCzGajjDoTR8Kqm7JSkig5hVN
406	406	{408,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvGmXuZQQrnnG6QzDdkMCVWKhYDQhXSpcUfvt2t8PH4r7mYRhjL
407	407	{409}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuHALkRU3Ef4D2b2S7JG9orqnMi18b9oS6rPMG3HGqbmZV4dF4N
408	408	{410,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuN5ujgBjkxkofdwvuM73zuy4J6a5nPxXnmWuong8egZQZFfvDK
409	409	{411}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvP2qQmzazhTuMBL3PwxAf4BiyxdS413XL2qh3Z9oichMxc2Ltu
410	410	{412,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv9P9vFqCWUX2a5qZHxJkVEEdAiRxR8L22hNSYjTepXLr3gKNKj
411	411	{413}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuGvj6Z1cRbrQx7LXxeXSosxycxFozgeTtYW9DSctNNbff1iM8W
412	412	{414,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juo22uHdb1qj5W5iVym5SbAFhP4Rekt8AiJgJmJANJSvf9QnXPc
413	413	{415}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvBLjVusuPkqKZn5iSEVsdoc6SCeN6Tnb89BDn7c38crVSEYRFf
414	414	{416,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtziZat6VbNwGE3e3i3GevkEPjVivDboTywpDpL8zJfYimkVdgG
415	415	{417}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuWURiBHPKkXbwPhEKBeUPWvwtz7aePi5WKhKucF2i9J495DsCc
416	416	{418,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuUHdKGbp9EXjL6f1JXV4twvYPharjAEev3BJfWrJ5utNECyb3L
417	417	{419}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvDHhDy97M7SiMzeuhngbCa5tq8D41nT6GNYJPgRW4zaZdW67mZ
418	418	{420,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuYhPo4BMb7hboL18t9jECss5U46AiU2L44qttzrhS2CVd3a2gn
419	419	{421}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtyvScydFJM7fa7YZEy7PxMM8GvrfYLo2h8LfPji82LMmUwtcvA
420	420	{422,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JucFrnGGC9H7uQiyL73785efYGL4nSA1Pw566K4QjVZF9Lus1wB
421	421	{423}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvEZqZErN8UC2nizzwggQfdm2Ft8GFCzqCKzyKZfve9KHkSJTnS
432	432	{434,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuMYKYmfwtJMt3ERWrp2SdDBBzswiaSEpmSPxvYibeGnbMb3dp8
433	433	{435}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuJi13ctz7uPP8BSbLdQ5CnnxhHVBbbMgHH5Tqch97HiELhYzZQ
434	434	{436,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju5hUUU7VKjr2hjhna47mWhyyWLaWNR4ruA6ZcDeCxJy1as5ejF
436	436	{438,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvJ2N35Ug2nFtkeePX673b8GTEDiZn1ShCm1e5h26Mv8ZoyETkh
437	437	{439}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuPYmsJUHBKbngvriuo7eG59uVUWjtmMo46X8Get9PPPQTKwgCC
438	438	{440,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JupmJoZxmQRQ9dNfNZCq7XbGczw8TQYAkmF1Fg2VSpVFG1yerig
439	439	{441}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvHrSxT8nr2kiNwNfUe6raH6rY8Koa8s2ZHNL63hU3MrHjMcW78
440	440	{442,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvAsdQHxkz3UQqGqCbwv6Mu35d4QPmdVAxsY94A4mqFaYKpYwUo
451	451	{453}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuUqbzacNfP59RSTeZ2iZzTkJUxaQ8yqEZ3RwfGUuzr6wc1MVsN
452	452	{454,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtjywKqoaWALJWWoQLAitqiPTBsQQUnePanPJeM3nbsjHRoaKF8
453	453	{455}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju7ZfvtszfuP4PSFcnDRg98KuzWdjS4vff2m3vQCB81JyJSUHqW
454	454	{456,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju8PDSDA5QBC7Si9EBTFGh2TdVRqSjctYjqS9RLmttt8ELBp358
455	455	{457}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuWeZRQJq4YX98H1MrVU1x9NDLVPhFMxnbBszbJfFDNQAchHNse
456	456	{458,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvQYhTRSgSDPU1udW2UuHwfVCr11iThaDoQqZArrpvEaVksdZXQ
457	457	{459}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvDzrLTi1TUsD8oGcWG6cM5EJad7QgPVdNPgvpDbA1ZYqWa6KxR
458	458	{460,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvS5GdUnZDwxnszFyo2E52BygPdmH2NLGFPpz94BLuHnshvYJ4D
459	459	{461}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv61EWWCa6Rukn6qNtG9pKLSvBYLA7BFU9U75kkbBzjmzjirXGw
460	460	{462,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuDSzbhW1PKRaHRGvH4Mm2dsyTS3Ya5vgzDuQzhJh1Hbq3sXjV9
461	461	{463}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvDJmUYfCD43NCo4X5wEp2NauwqvKBJ1mspXsiQ4jSZqzvxNnsQ
462	462	{464,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtyXvJbLPv2T9o9P8zRVK9g21eEZdVpeEeWmXeboJ5CjZrg5JzW
463	463	{465}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvGHLQw3LNhxjE9cz5siLa2CaHUoNzTsakiqMreqbpdPJYz9B97
464	464	{466,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvMB8BBcMUw7WvuzyBedsXhQ74caJ9qnhrLpszoxNofhWCpCfqL
465	465	{467}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuDpLuwuuHroLKsgkh9dmF17eHiwn2QuVwrLRCSTtVoaQMds2pH
466	466	{468,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuFspawYPXqtJwJoGjBefrJ4z6pXfzWwcp1np5Jo9tyGDf3mZCE
467	467	{469}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuFE8iU1fVguEvcozpTLGLtpsgXEkR9EXGvAjyVdaQKXR97wPgd
468	468	{470,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv66zG5yoxcCbQjXRFhn4UwfhwpcLg32R299Syq8xQm6ZMttxNh
469	469	{471}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuduavVC2JrgaER5Wv9DMZ36Hqk3UQv4Sp3Cbiqsw7AJTPfZXok
470	470	{472,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JthxKdb4w1apyUx3ahmPPzXmagrM1nMqNck6CigmZXsmCBiZnCK
471	471	{473}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuJVyK4MTiKtw6zFMibgMRJXmvGYahc2BX2wCwJ6adn6LgUgpQo
472	472	{474,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuYrjLX1x45xebZufBkJwA6ucgiSDLQ7YuY5Z4hTtzw6q4Nt2C7
473	473	{475}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtcBDA33CRqiThT4mgJDUdhpWcpogVoRvK5rT1FgAqu5LVcsmC6
474	474	{476,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtwzJF8v2zV9iLbTZ9mttoAEneiavgyzGig5yyBtzuGUigGfH2T
475	475	{477}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuEjgxfjhTwz4LzEnEuy198VCSnJr8uxuubMF2RmLFrpUPXnVP7
476	476	{478,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtXMb6rUb8CBRYhzyx4ubEWX3w5h14fLcmdjvjKcAB9mL395FTw
477	477	{479}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvQvV92CpRXXVgLE7kWL4fZYQq5MjbX2VzWWHLUkyYP7NHD1Et3
478	478	{480,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvMHujGnm89VARvcPWgiudmnLbSKReNPhG141V1nJtoCsrb4QtD
422	422	{424,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvDPkfQzcPXoTQVFaevgDVTusMa43B4ZmioS5pgyzaWDd8eudDk
423	423	{425}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuF9qHdqBkuJWoffnAsmt6BAWzX5njyAirUNiebMq54SLSp7gP1
424	424	{426,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv6Lpe7waUnDhtbe5UksbZtBSQCf7mYBS8uCF9GBLehp7epDLJd
425	425	{427}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvDSvYi8LT9FhqDjnNKv7dMTmhV1AA4AQJukGEg2ZswyBg7eife
426	426	{428,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtzXf31xTVQpWez8Vj8J4zFX1gF9fFhAzdjLuG7k4svcHXnnpmg
427	427	{429}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JudYSHf9PGqvMvr9zFWPWUNWNCBBN9JJkEH39sYKvKzGTqYbKHS
428	428	{430,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuqfjqG3bvF5uu8fc9GccYA98w5PeWMqzuAteoonFg72Xu3CPm8
429	429	{431}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuNqoaaxgNSgvDYMufnw8v8gd6qWa3FULkDtoBxJpi6BoDE3X6q
430	430	{432,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuVc6UnykPqgGQtsJdoPYe7wqdWZoRogh5BZExmvGinHDdcnnix
431	431	{433}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtgJ7gwcXGmcATDrn75Hg5UcSxXH8y2mkuDhQSKdYbvxD68Sz3k
435	435	{437}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JufdnsnHC1dMjT8stk7kD93jiDMvrKVnZYT1UJsKLEfQAdRaRMM
441	441	{443}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvAzpJhz2iGcMnhGH3JWijRXNKpvfhPn1NJ9yQYpCm4zFpyGSRS
442	442	{444,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuUZBee8TyUgMZq3X2pRteeNUC77Zd3fk6bhBfpa8NkYCGM9eqA
443	443	{445}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtmQYppQhCaK1HepnRo8as6ebE9q7YnfKnFhwN5QSwvoLnrR4Xy
444	444	{446,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuiJbD3twgT4a8FdzFcTsB3N24JQcrtTcq8LxtZ7jV8JZynxgJw
445	445	{447}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju2XLwvDPEJLzpv9Zd3bz3GZFF616jLvssdraeDqmZghFUaTCHT
446	446	{448,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju75pR9AePdctHGrAMybvCoBW9LWzyyXn8yndjL3fqtTEqoB2d1
447	447	{449}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuaZJV6uCb6JmWJwJaGjfV1KRFfqYUsgzufh7kF7SnYamUoeTF8
448	448	{450,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtwopb35ojYSYq7bKehE31Rfw6zdvoENnSiqc2hZqF8yQrVs22V
449	449	{451}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuGKB56ksSXrs2m7QZYNsobW8BvQ2mhsTxhxTZ6X9VsMYAXEgQ3
450	450	{452,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juhds47xCS7iPK7h26aoMeQxpstXGB4AfoWvY4Cp11ZAYSjqWTL
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
1	110	5000000000	\N	0
2	110	5000000000	\N	1
3	110	5000000000	\N	2
4	110	5000000000	\N	3
5	110	5000000000	\N	4
6	110	5000000000	\N	5
7	110	5000000000	\N	6
8	110	5000000000	\N	7
9	110	5000000000	\N	8
10	110	5000000000	\N	9
11	110	5000000000	\N	10
12	110	5000000000	\N	11
13	110	5000000000	\N	12
14	110	5000000000	\N	13
15	110	5000000000	\N	14
16	110	5000000000	\N	15
17	110	5000000000	\N	16
18	110	5000000000	\N	17
19	110	5000000000	\N	18
20	110	5000000000	\N	19
21	110	5000000000	\N	20
22	110	5000000000	\N	21
23	110	5000000000	\N	22
24	110	5000000000	\N	23
25	110	5000000000	\N	24
26	110	5000000000	\N	25
27	110	5000000000	\N	26
28	110	5000000000	\N	27
29	110	5000000000	\N	28
30	110	5000000000	\N	29
31	110	5000000000	\N	30
32	110	5000000000	\N	31
33	110	5000000000	\N	32
34	110	5000000000	\N	33
35	110	5000000000	\N	34
36	110	5000000000	\N	35
37	110	5000000000	\N	36
38	110	5000000000	\N	37
39	110	5000000000	\N	38
40	110	5000000000	\N	39
41	110	5000000000	\N	40
42	110	5000000000	\N	41
43	110	5000000000	\N	42
44	110	5000000000	\N	43
45	110	5000000000	\N	44
46	110	5000000000	\N	45
47	110	5000000000	\N	46
48	110	5000000000	\N	47
49	110	5000000000	\N	48
50	110	5000000000	\N	49
51	110	5000000000	\N	50
52	110	5000000000	\N	51
53	110	5000000000	\N	52
54	110	5000000000	\N	53
55	110	5000000000	\N	54
56	110	5000000000	\N	55
57	110	5000000000	\N	56
58	110	5000000000	\N	57
59	110	5000000000	\N	58
60	110	5000000000	\N	59
61	110	5000000000	\N	60
62	110	5000000000	\N	61
63	110	5000000000	\N	62
64	110	5000000000	\N	63
65	110	5000000000	\N	64
66	110	5000000000	\N	65
67	110	5000000000	\N	66
68	110	5000000000	\N	67
69	110	5000000000	\N	68
70	110	5000000000	\N	69
71	110	5000000000	\N	70
72	110	5000000000	\N	71
73	110	5000000000	\N	72
74	110	5000000000	\N	73
75	110	5000000000	\N	74
76	110	5000000000	\N	75
77	110	5000000000	\N	76
78	110	5000000000	\N	77
79	110	5000000000	\N	78
80	110	5000000000	\N	79
81	110	5000000000	\N	80
82	110	5000000000	\N	81
83	110	5000000000	\N	82
84	110	5000000000	\N	83
85	110	5000000000	\N	84
86	110	5000000000	\N	85
87	110	5000000000	\N	86
88	110	5000000000	\N	87
89	110	5000000000	\N	88
90	110	5000000000	\N	89
91	110	5000000000	\N	90
92	110	5000000000	\N	91
93	110	5000000000	\N	92
94	110	5000000000	\N	93
95	110	5000000000	\N	94
96	110	5000000000	\N	95
97	110	5000000000	\N	96
98	110	5000000000	\N	97
99	110	5000000000	\N	98
100	110	5000000000	\N	99
101	110	5000000000	\N	100
102	110	5000000000	\N	101
103	110	5000000000	\N	102
104	110	5000000000	\N	103
105	110	5000000000	\N	104
106	110	5000000000	\N	105
107	110	5000000000	\N	106
108	110	5000000000	\N	107
109	110	5000000000	\N	108
110	110	5000000000	\N	109
111	110	5000000000	\N	110
112	110	5000000000	\N	111
113	110	5000000000	\N	112
114	110	5000000000	\N	113
115	110	5000000000	\N	114
116	110	5000000000	\N	115
117	110	5000000000	\N	116
118	110	5000000000	\N	117
119	110	5000000000	\N	118
120	110	5000000000	\N	119
121	110	5000000000	\N	120
122	110	5000000000	\N	121
123	110	5000000000	\N	122
124	110	5000000000	\N	123
125	110	5000000000	\N	124
126	110	5000000000	\N	125
127	110	5000000000	\N	126
128	110	5000000000	\N	127
129	110	5000000000	\N	128
130	110	5000000000	\N	129
131	110	5000000000	\N	130
132	110	5000000000	\N	131
133	110	5000000000	\N	132
134	110	5000000000	\N	133
135	110	5000000000	\N	134
136	110	5000000000	\N	135
137	110	5000000000	\N	136
138	110	5000000000	\N	137
139	110	5000000000	\N	138
140	110	5000000000	\N	139
141	110	5000000000	\N	140
142	110	5000000000	\N	141
143	110	5000000000	\N	142
144	110	5000000000	\N	143
145	110	5000000000	\N	144
146	110	5000000000	\N	145
147	110	5000000000	\N	146
148	110	5000000000	\N	147
149	110	5000000000	\N	148
150	110	5000000000	\N	149
151	110	5000000000	\N	150
152	110	5000000000	\N	151
153	110	5000000000	\N	152
154	110	5000000000	\N	153
155	110	5000000000	\N	154
156	110	5000000000	\N	155
157	110	5000000000	\N	156
158	110	5000000000	\N	157
159	110	5000000000	\N	158
160	110	5000000000	\N	159
161	110	5000000000	\N	160
162	110	5000000000	\N	161
163	110	5000000000	\N	162
164	110	5000000000	\N	163
165	110	5000000000	\N	164
166	110	5000000000	\N	165
167	110	5000000000	\N	166
168	110	5000000000	\N	167
169	110	5000000000	\N	168
170	110	5000000000	\N	169
171	110	5000000000	\N	170
172	110	5000000000	\N	171
173	110	5000000000	\N	172
174	110	5000000000	\N	173
175	110	5000000000	\N	174
176	110	5000000000	\N	175
177	110	5000000000	\N	176
178	110	5000000000	\N	177
179	110	5000000000	\N	178
180	110	5000000000	\N	179
181	110	5000000000	\N	180
182	110	5000000000	\N	181
183	110	5000000000	\N	182
184	110	5000000000	\N	183
185	110	5000000000	\N	184
186	110	5000000000	\N	185
187	110	5000000000	\N	186
188	110	5000000000	\N	187
189	110	5000000000	\N	188
190	110	5000000000	\N	189
191	110	5000000000	\N	190
192	110	5000000000	\N	191
193	110	5000000000	\N	192
194	110	5000000000	\N	193
195	110	5000000000	\N	194
196	110	5000000000	\N	195
197	110	5000000000	\N	196
198	110	5000000000	\N	197
199	110	5000000000	\N	198
200	110	5000000000	\N	199
201	110	5000000000	\N	200
202	110	5000000000	\N	201
203	110	5000000000	\N	202
204	110	5000000000	\N	203
205	110	5000000000	\N	204
206	110	5000000000	\N	205
207	110	5000000000	\N	206
208	110	5000000000	\N	207
209	110	5000000000	\N	208
210	110	5000000000	\N	209
211	110	5000000000	\N	210
212	110	5000000000	\N	211
213	110	5000000000	\N	212
214	110	5000000000	\N	213
215	110	5000000000	\N	214
216	110	5000000000	\N	215
217	110	5000000000	\N	216
218	110	5000000000	\N	217
219	110	5000000000	\N	218
220	110	5000000000	\N	219
221	110	5000000000	\N	220
222	110	5000000000	\N	221
223	110	5000000000	\N	222
224	110	5000000000	\N	223
225	110	5000000000	\N	224
226	110	5000000000	\N	225
227	110	5000000000	\N	226
228	110	5000000000	\N	227
229	110	5000000000	\N	228
230	110	5000000000	\N	229
231	110	5000000000	\N	230
232	110	5000000000	\N	231
233	110	5000000000	\N	232
234	110	5000000000	\N	233
235	110	5000000000	\N	234
236	110	5000000000	\N	235
237	110	5000000000	\N	236
238	110	5000000000	\N	237
239	110	5000000000	\N	238
240	110	5000000000	\N	239
241	110	5000000000	\N	240
242	110	5000000000	\N	241
243	110	5000000000	\N	242
244	110	5000000000	\N	243
245	110	5000000000	\N	244
246	110	5000000000	\N	245
247	110	5000000000	\N	246
248	110	5000000000	\N	247
249	110	5000000000	\N	248
250	110	5000000000	\N	249
251	110	5000000000	\N	250
252	110	5000000000	\N	251
253	110	5000000000	\N	252
254	110	5000000000	\N	253
255	110	5000000000	\N	254
256	110	5000000000	\N	255
257	110	5000000000	\N	256
258	110	5000000000	\N	257
259	110	5000000000	\N	258
260	110	5000000000	\N	259
261	110	5000000000	\N	260
262	110	5000000000	\N	261
263	110	5000000000	\N	262
264	110	5000000000	\N	263
265	110	5000000000	\N	264
266	110	5000000000	\N	265
267	110	5000000000	\N	266
268	110	5000000000	\N	267
269	110	5000000000	\N	268
270	110	5000000000	\N	269
271	110	5000000000	\N	270
272	110	5000000000	\N	271
273	110	5000000000	\N	272
274	110	5000000000	\N	273
275	110	5000000000	\N	274
276	110	5000000000	\N	275
277	110	5000000000	\N	276
278	110	5000000000	\N	277
279	110	5000000000	\N	278
280	110	5000000000	\N	279
281	110	5000000000	\N	280
282	110	5000000000	\N	281
283	110	5000000000	\N	282
284	110	5000000000	\N	283
285	110	5000000000	\N	284
286	110	5000000000	\N	285
287	110	5000000000	\N	286
288	110	5000000000	\N	287
289	110	5000000000	\N	288
290	110	5000000000	\N	289
291	110	5000000000	\N	290
292	110	5000000000	\N	291
293	110	5000000000	\N	292
294	110	5000000000	\N	293
295	110	5000000000	\N	294
296	110	5000000000	\N	295
297	110	5000000000	\N	296
298	110	5000000000	\N	297
299	110	5000000000	\N	298
300	110	5000000000	\N	299
301	110	5000000000	\N	300
302	110	5000000000	\N	301
303	110	5000000000	\N	302
304	110	5000000000	\N	303
305	110	5000000000	\N	304
306	110	5000000000	\N	305
307	110	5000000000	\N	306
308	110	5000000000	\N	307
309	110	5000000000	\N	308
310	110	5000000000	\N	309
311	110	5000000000	\N	310
312	110	5000000000	\N	311
313	110	5000000000	\N	312
314	110	5000000000	\N	313
315	110	5000000000	\N	314
316	110	5000000000	\N	315
317	110	5000000000	\N	316
318	110	5000000000	\N	317
319	110	5000000000	\N	318
320	110	5000000000	\N	319
321	110	5000000000	\N	320
322	110	5000000000	\N	321
323	110	5000000000	\N	322
324	110	5000000000	\N	323
325	110	5000000000	\N	324
326	110	5000000000	\N	325
327	110	5000000000	\N	326
328	110	5000000000	\N	327
329	110	5000000000	\N	328
330	110	5000000000	\N	329
331	110	5000000000	\N	330
332	110	5000000000	\N	331
333	110	5000000000	\N	332
334	110	5000000000	\N	333
335	110	5000000000	\N	334
336	110	5000000000	\N	335
337	110	5000000000	\N	336
338	110	5000000000	\N	337
339	110	5000000000	\N	338
340	110	5000000000	\N	339
341	110	5000000000	\N	340
342	110	5000000000	\N	341
343	110	5000000000	\N	342
344	110	5000000000	\N	343
345	110	5000000000	\N	344
346	110	5000000000	\N	345
347	110	5000000000	\N	346
348	110	5000000000	\N	347
349	110	5000000000	\N	348
350	110	5000000000	\N	349
351	110	5000000000	\N	350
352	110	5000000000	\N	351
353	110	5000000000	\N	352
354	110	5000000000	\N	353
355	110	5000000000	\N	354
356	110	5000000000	\N	355
357	110	5000000000	\N	356
358	110	5000000000	\N	357
359	110	5000000000	\N	358
360	110	5000000000	\N	359
361	110	5000000000	\N	360
362	110	5000000000	\N	361
363	110	5000000000	\N	362
364	110	5000000000	\N	363
365	110	5000000000	\N	364
366	110	5000000000	\N	365
367	110	5000000000	\N	366
368	110	5000000000	\N	367
369	110	5000000000	\N	368
370	110	5000000000	\N	369
371	110	5000000000	\N	370
372	110	5000000000	\N	371
373	110	5000000000	\N	372
374	110	5000000000	\N	373
375	110	5000000000	\N	374
376	110	5000000000	\N	375
377	110	5000000000	\N	376
378	110	5000000000	\N	377
379	110	5000000000	\N	378
380	110	5000000000	\N	379
381	110	5000000000	\N	380
382	110	5000000000	\N	381
383	110	5000000000	\N	382
384	110	5000000000	\N	383
385	110	5000000000	\N	384
386	110	5000000000	\N	385
387	110	5000000000	\N	386
388	110	5000000000	\N	387
389	110	5000000000	\N	388
390	110	5000000000	\N	389
391	110	5000000000	\N	390
392	110	5000000000	\N	391
393	110	5000000000	\N	392
394	110	5000000000	\N	393
395	110	5000000000	\N	394
396	110	5000000000	\N	395
397	110	5000000000	\N	396
398	110	5000000000	\N	397
399	110	5000000000	\N	398
400	110	5000000000	\N	399
401	110	5000000000	\N	400
402	110	5000000000	\N	401
403	110	5000000000	\N	402
404	110	5000000000	\N	403
405	110	5000000000	\N	404
406	110	5000000000	\N	405
407	110	5000000000	\N	406
408	110	5000000000	\N	407
409	110	5000000000	\N	408
410	110	5000000000	\N	409
411	110	5000000000	\N	410
412	110	5000000000	\N	411
413	110	5000000000	\N	412
414	110	5000000000	\N	413
415	110	5000000000	\N	414
416	110	5000000000	\N	415
417	110	5000000000	\N	416
418	110	5000000000	\N	417
419	110	5000000000	\N	418
420	110	5000000000	\N	419
421	110	5000000000	\N	420
422	110	5000000000	\N	421
423	110	5000000000	\N	422
424	110	5000000000	\N	423
425	110	5000000000	\N	424
426	110	5000000000	\N	425
427	110	5000000000	\N	426
428	110	5000000000	\N	427
429	110	5000000000	\N	428
430	110	5000000000	\N	429
431	110	5000000000	\N	430
435	110	5000000000	\N	434
441	110	5000000000	\N	440
442	110	5000000000	\N	441
443	110	5000000000	\N	442
444	110	5000000000	\N	443
445	110	5000000000	\N	444
446	110	5000000000	\N	445
447	110	5000000000	\N	446
448	110	5000000000	\N	447
449	110	5000000000	\N	448
450	110	5000000000	\N	449
432	110	5000000000	\N	431
433	110	5000000000	\N	432
434	110	5000000000	\N	433
436	110	5000000000	\N	435
437	110	5000000000	\N	436
438	110	5000000000	\N	437
439	110	5000000000	\N	438
440	110	5000000000	\N	439
451	110	5000000000	\N	450
452	110	5000000000	\N	451
453	110	5000000000	\N	452
454	110	5000000000	\N	453
455	110	5000000000	\N	454
456	110	5000000000	\N	455
457	110	5000000000	\N	456
458	110	5000000000	\N	457
459	110	5000000000	\N	458
460	110	5000000000	\N	459
461	110	5000000000	\N	460
462	110	5000000000	\N	461
463	110	5000000000	\N	462
464	110	5000000000	\N	463
465	110	5000000000	\N	464
466	110	5000000000	\N	465
467	110	5000000000	\N	466
468	110	5000000000	\N	467
469	110	5000000000	\N	468
470	110	5000000000	\N	469
471	110	5000000000	\N	470
472	110	5000000000	\N	471
473	110	5000000000	\N	472
474	110	5000000000	\N	473
475	110	5000000000	\N	474
476	110	5000000000	\N	475
477	110	5000000000	\N	476
478	110	5000000000	\N	477
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
188	187
189	188
190	189
191	190
192	191
193	192
194	193
195	194
196	195
197	196
198	197
199	198
200	199
201	200
202	201
203	202
204	203
205	204
206	205
207	206
208	207
209	208
210	209
211	210
212	211
213	212
214	213
215	214
216	215
217	216
218	217
219	218
220	219
221	220
222	221
223	222
224	223
225	224
226	225
227	226
228	227
229	228
230	229
231	230
232	231
233	232
234	233
235	234
236	235
237	236
238	237
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
181	181	181
159	159	159
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
182	182	182
183	183	183
184	184	184
185	185	185
186	186	186
187	187	187
188	188	188
189	189	189
190	190	190
191	191	191
192	192	192
193	193	193
194	194	194
195	195	195
196	196	196
197	197	197
198	198	198
199	199	199
200	200	200
201	201	201
202	202	202
203	203	203
204	204	204
205	205	205
206	206	206
207	207	207
208	208	208
209	209	209
210	210	210
211	211	211
212	212	212
213	213	213
214	214	214
215	215	215
216	216	216
217	217	217
218	218	218
219	219	219
220	220	220
221	221	221
222	222	222
223	223	223
224	224	224
225	225	225
226	226	226
227	227	227
228	228	228
229	229	229
230	230	230
231	231	231
232	232	232
233	233	233
234	234	234
235	235	235
236	236	236
237	237	237
238	238	238
239	239	239
240	240	240
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
189	188	\N	\N	\N	\N	\N	\N	\N
190	189	\N	\N	\N	\N	\N	\N	\N
191	190	\N	\N	\N	\N	\N	\N	\N
192	191	\N	\N	\N	\N	\N	\N	\N
193	192	\N	\N	\N	\N	\N	\N	\N
194	193	\N	\N	\N	\N	\N	\N	\N
195	194	\N	\N	\N	\N	\N	\N	\N
196	195	\N	\N	\N	\N	\N	\N	\N
197	196	\N	\N	\N	\N	\N	\N	\N
198	197	\N	\N	\N	\N	\N	\N	\N
199	198	\N	\N	\N	\N	\N	\N	\N
200	199	\N	\N	\N	\N	\N	\N	\N
201	200	\N	\N	\N	\N	\N	\N	\N
202	201	\N	\N	\N	\N	\N	\N	\N
209	208	\N	\N	\N	\N	\N	\N	\N
210	209	\N	\N	\N	\N	\N	\N	\N
211	210	\N	\N	\N	\N	\N	\N	\N
217	216	\N	\N	\N	\N	\N	\N	\N
219	218	\N	\N	\N	\N	\N	\N	\N
220	219	\N	\N	\N	\N	\N	\N	\N
226	225	\N	\N	\N	\N	\N	\N	\N
227	226	\N	\N	\N	\N	\N	\N	\N
228	227	\N	\N	\N	\N	\N	\N	\N
229	228	\N	\N	\N	\N	\N	\N	\N
230	229	\N	\N	\N	\N	\N	\N	\N
231	230	\N	\N	\N	\N	\N	\N	\N
232	231	\N	\N	\N	\N	\N	\N	\N
233	232	\N	\N	\N	\N	\N	\N	\N
234	233	\N	\N	\N	\N	\N	\N	\N
235	234	\N	\N	\N	\N	\N	\N	\N
236	235	\N	\N	\N	\N	\N	\N	\N
237	236	\N	\N	\N	\N	\N	\N	\N
238	237	\N	\N	\N	\N	\N	\N	\N
239	238	\N	\N	\N	\N	\N	\N	\N
187	186	\N	\N	\N	\N	\N	\N	\N
188	187	\N	\N	\N	\N	\N	\N	\N
203	202	\N	\N	\N	\N	\N	\N	\N
204	203	\N	\N	\N	\N	\N	\N	\N
205	204	\N	\N	\N	\N	\N	\N	\N
206	205	\N	\N	\N	\N	\N	\N	\N
207	206	\N	\N	\N	\N	\N	\N	\N
208	207	\N	\N	\N	\N	\N	\N	\N
212	211	\N	\N	\N	\N	\N	\N	\N
213	212	\N	\N	\N	\N	\N	\N	\N
214	213	\N	\N	\N	\N	\N	\N	\N
215	214	\N	\N	\N	\N	\N	\N	\N
216	215	\N	\N	\N	\N	\N	\N	\N
218	217	\N	\N	\N	\N	\N	\N	\N
221	220	\N	\N	\N	\N	\N	\N	\N
222	221	\N	\N	\N	\N	\N	\N	\N
223	222	\N	\N	\N	\N	\N	\N	\N
224	223	\N	\N	\N	\N	\N	\N	\N
225	224	\N	\N	\N	\N	\N	\N	\N
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
188	187	\N	\N	\N	\N	\N	\N	\N
189	188	\N	\N	\N	\N	\N	\N	\N
190	189	\N	\N	\N	\N	\N	\N	\N
191	190	\N	\N	\N	\N	\N	\N	\N
192	191	\N	\N	\N	\N	\N	\N	\N
193	192	\N	\N	\N	\N	\N	\N	\N
194	193	\N	\N	\N	\N	\N	\N	\N
195	194	\N	\N	\N	\N	\N	\N	\N
196	195	\N	\N	\N	\N	\N	\N	\N
197	196	\N	\N	\N	\N	\N	\N	\N
198	197	\N	\N	\N	\N	\N	\N	\N
199	198	\N	\N	\N	\N	\N	\N	\N
200	199	\N	\N	\N	\N	\N	\N	\N
201	200	\N	\N	\N	\N	\N	\N	\N
202	201	\N	\N	\N	\N	\N	\N	\N
203	202	\N	\N	\N	\N	\N	\N	\N
204	203	\N	\N	\N	\N	\N	\N	\N
205	204	\N	\N	\N	\N	\N	\N	\N
206	205	\N	\N	\N	\N	\N	\N	\N
207	206	\N	\N	\N	\N	\N	\N	\N
208	207	\N	\N	\N	\N	\N	\N	\N
209	208	\N	\N	\N	\N	\N	\N	\N
210	209	\N	\N	\N	\N	\N	\N	\N
211	210	\N	\N	\N	\N	\N	\N	\N
212	211	\N	\N	\N	\N	\N	\N	\N
213	212	\N	\N	\N	\N	\N	\N	\N
214	213	\N	\N	\N	\N	\N	\N	\N
215	214	\N	\N	\N	\N	\N	\N	\N
216	215	\N	\N	\N	\N	\N	\N	\N
217	216	\N	\N	\N	\N	\N	\N	\N
218	217	\N	\N	\N	\N	\N	\N	\N
219	218	\N	\N	\N	\N	\N	\N	\N
220	219	\N	\N	\N	\N	\N	\N	\N
221	220	\N	\N	\N	\N	\N	\N	\N
222	221	\N	\N	\N	\N	\N	\N	\N
223	222	\N	\N	\N	\N	\N	\N	\N
224	223	\N	\N	\N	\N	\N	\N	\N
225	224	\N	\N	\N	\N	\N	\N	\N
226	225	\N	\N	\N	\N	\N	\N	\N
227	226	\N	\N	\N	\N	\N	\N	\N
228	227	\N	\N	\N	\N	\N	\N	\N
229	228	\N	\N	\N	\N	\N	\N	\N
230	229	\N	\N	\N	\N	\N	\N	\N
231	230	\N	\N	\N	\N	\N	\N	\N
232	231	\N	\N	\N	\N	\N	\N	\N
233	232	\N	\N	\N	\N	\N	\N	\N
234	233	\N	\N	\N	\N	\N	\N	\N
235	234	\N	\N	\N	\N	\N	\N	\N
236	235	\N	\N	\N	\N	\N	\N	\N
237	236	\N	\N	\N	\N	\N	\N	\N
238	237	\N	\N	\N	\N	\N	\N	\N
239	238	\N	\N	\N	\N	\N	\N	\N
240	239	\N	\N	\N	\N	\N	\N	\N
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

SELECT pg_catalog.setval('public.blocks_id_seq', 54, true);


--
-- Name: epoch_data_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.epoch_data_id_seq', 55, true);


--
-- Name: internal_commands_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.internal_commands_id_seq', 58, true);


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

SELECT pg_catalog.setval('public.user_commands_id_seq', 232, true);


--
-- Name: voting_for_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.voting_for_id_seq', 1, true);


--
-- Name: zkapp_account_precondition_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_account_precondition_id_seq', 241, true);


--
-- Name: zkapp_account_update_body_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_account_update_body_id_seq', 480, true);


--
-- Name: zkapp_account_update_failures_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_account_update_failures_id_seq', 4, true);


--
-- Name: zkapp_account_update_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_account_update_id_seq', 480, true);


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

SELECT pg_catalog.setval('public.zkapp_commands_id_seq', 478, true);


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

SELECT pg_catalog.setval('public.zkapp_fee_payer_body_id_seq', 478, true);


--
-- Name: zkapp_field_array_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_field_array_id_seq', 1, false);


--
-- Name: zkapp_field_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_field_id_seq', 238, true);


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

SELECT pg_catalog.setval('public.zkapp_nonce_bounds_id_seq', 240, true);


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

SELECT pg_catalog.setval('public.zkapp_states_nullable_id_seq', 239, true);


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

SELECT pg_catalog.setval('public.zkapp_updates_id_seq', 240, true);


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
-- PostgreSQL database dump complete
--

