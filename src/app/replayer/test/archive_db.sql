--
-- PostgreSQL database dump
--

-- Dumped from database version 12.17 (Ubuntu 12.17-0ubuntu0.20.04.1)
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
139	140	1
140	141	1
141	142	1
142	143	1
143	144	1
144	145	1
145	146	1
146	147	1
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
184	1	1
185	186	1
186	187	1
187	188	1
188	189	1
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
204	190	1
205	206	1
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
218	168	1
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
7	1	27	1	0	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
210	1	28	1	315	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	29	1	28	1	\N
79	1	29	1	162	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	30	1	29	1	\N
167	1	30	1	86	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	31	1	30	1	\N
181	1	31	1	409	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	32	1	31	1	\N
156	1	32	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	33	1	32	1	\N
96	1	33	1	57	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	34	1	33	1	\N
191	1	34	1	204	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	35	1	34	1	\N
132	1	35	1	262	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	36	1	35	1	\N
111	1	36	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	37	1	36	1	\N
171	1	37	1	156	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	38	1	37	1	\N
64	1	38	1	417	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	39	1	38	1	\N
68	1	39	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	40	1	39	1	\N
51	1	40	1	85	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	41	1	40	1	\N
227	1	41	1	103	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	42	1	41	1	\N
141	1	42	1	67	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	43	1	42	1	\N
42	1	43	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	44	1	43	1	\N
133	1	44	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	45	1	44	1	\N
82	1	45	1	198	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	46	1	45	1	\N
95	1	46	1	489	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	47	1	46	1	\N
188	1	47	1	298	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	48	1	47	1	\N
30	1	48	1	36	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	49	1	48	1	\N
90	1	49	1	334	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	50	1	49	1	\N
14	1	50	1	344	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	51	1	50	1	\N
35	1	51	1	451	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	52	1	51	1	\N
85	1	52	1	371	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	53	1	52	1	\N
127	1	53	1	234	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	54	1	53	1	\N
222	1	54	1	345	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	55	1	54	1	\N
76	1	55	1	282	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	56	1	55	1	\N
231	1	56	1	339	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
15	1	57	1	215	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	58	1	57	1	\N
220	1	58	1	193	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	59	1	58	1	\N
16	1	59	1	60	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	60	1	59	1	\N
58	1	60	1	350	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	61	1	60	1	\N
146	1	61	1	223	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	62	1	61	1	\N
62	1	62	1	449	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	63	1	62	1	\N
185	1	63	1	142	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	64	1	63	1	\N
151	1	64	1	300	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	65	1	64	1	\N
165	1	65	1	256	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	66	1	65	1	\N
103	1	66	1	125	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	67	1	66	1	\N
41	1	67	1	236	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	68	1	67	1	\N
239	1	68	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	69	1	68	1	\N
110	1	69	1	179	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	70	1	69	1	\N
13	1	70	1	194	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	71	1	70	1	\N
26	1	71	1	185	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	72	1	71	1	\N
98	1	72	1	342	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	73	1	72	1	\N
215	1	73	1	157	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	74	1	73	1	\N
91	1	74	1	135	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	75	1	74	1	\N
159	1	75	1	456	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	76	1	75	1	\N
208	1	76	1	336	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	77	1	76	1	\N
207	1	77	1	280	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	78	1	77	1	\N
182	1	78	1	187	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	79	1	78	1	\N
157	1	79	1	387	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	80	1	79	1	\N
33	1	80	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	81	1	80	1	\N
201	1	81	1	151	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	82	1	81	1	\N
9	1	82	1	356	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	83	1	82	1	\N
234	1	83	1	24	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	84	1	83	1	\N
40	1	84	1	152	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	85	1	84	1	\N
18	1	85	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	86	1	85	1	\N
229	1	86	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	87	1	86	1	\N
20	1	87	1	186	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	88	1	87	1	\N
184	1	88	1	266	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	89	1	88	1	\N
139	1	89	1	81	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	90	1	89	1	\N
164	1	90	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	91	1	90	1	\N
199	1	91	1	379	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	92	1	91	1	\N
109	1	92	1	315	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	93	1	92	1	\N
47	1	93	1	226	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	94	1	93	1	\N
214	1	94	1	166	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	95	1	94	1	\N
112	1	95	1	302	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	96	1	95	1	\N
144	1	96	1	269	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	97	1	96	1	\N
178	1	97	1	172	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	98	1	97	1	\N
155	1	98	1	195	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	99	1	98	1	\N
38	1	99	1	243	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	100	1	99	1	\N
80	1	100	1	128	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	101	1	100	1	\N
147	1	101	1	349	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	102	1	101	1	\N
24	1	102	1	87	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	103	1	102	1	\N
126	1	103	1	424	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	104	1	103	1	\N
89	1	104	1	239	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	105	1	104	1	\N
135	1	105	1	316	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	106	1	105	1	\N
194	1	106	1	492	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	107	1	106	1	\N
6	1	107	1	11550000000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	107	1	\N
190	1	108	1	294	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	109	1	108	1	\N
218	1	109	1	191	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	110	1	109	1	\N
93	1	110	1	380	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	111	1	110	1	\N
162	1	111	1	331	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	112	1	111	1	\N
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
203	1	134	1	365	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	135	1	134	1	\N
50	1	135	1	342	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	136	1	135	1	\N
59	1	136	1	237	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	137	1	136	1	\N
150	1	137	1	427	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	138	1	137	1	\N
180	1	138	1	315	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	139	1	138	1	\N
142	1	139	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	140	1	139	1	\N
23	1	140	1	378	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	141	1	140	1	\N
122	1	141	1	420	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	142	1	141	1	\N
115	1	142	1	411	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	143	1	142	1	\N
75	1	143	1	172	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	144	1	143	1	\N
77	1	144	1	309	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	145	1	144	1	\N
152	1	145	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	146	1	145	1	\N
120	1	146	1	154	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	147	1	146	1	\N
118	1	147	1	153	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	148	1	147	1	\N
37	1	148	1	47	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	149	1	148	1	\N
168	1	149	1	87	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	150	1	149	1	\N
149	1	150	1	398	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	151	1	150	1	\N
29	1	151	1	452	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	152	1	151	1	\N
8	1	152	1	283	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	153	1	152	1	\N
88	1	153	1	291	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	154	1	153	1	\N
233	1	154	1	367	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	155	1	154	1	\N
83	1	155	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	156	1	155	1	\N
154	1	156	1	311	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	157	1	156	1	\N
175	1	157	1	258	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	158	1	157	1	\N
69	1	158	1	323	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	159	1	158	1	\N
63	1	159	1	405	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	160	1	159	1	\N
189	1	160	1	32	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	161	1	160	1	\N
92	1	161	1	130	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	162	1	161	1	\N
140	1	162	1	234	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	163	1	162	1	\N
17	1	163	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	164	1	163	1	\N
87	1	164	1	481	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	165	1	164	1	\N
183	1	165	1	240	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	166	1	165	1	\N
4	1	166	1	11550000000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	166	1	\N
129	1	167	1	314	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	169	1	167	1	\N
193	1	168	1	183	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	170	1	168	1	\N
174	1	169	1	486	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	171	1	169	1	\N
57	1	170	1	178	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	172	1	170	1	\N
224	1	171	1	65	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	173	1	171	1	\N
232	1	172	1	277	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	174	1	172	1	\N
119	1	173	1	433	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	175	1	173	1	\N
55	1	174	1	100	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	176	1	174	1	\N
169	1	175	1	272	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	177	1	175	1	\N
125	1	176	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	178	1	176	1	\N
45	1	177	1	212	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	179	1	177	1	\N
60	1	178	1	151	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	180	1	178	1	\N
99	1	179	1	387	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	181	1	179	1	\N
179	1	180	1	158	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	182	1	180	1	\N
49	1	181	1	440	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	183	1	181	1	\N
230	1	182	1	438	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	184	1	182	1	\N
131	1	183	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	185	1	183	1	\N
0	1	184	1	1000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	1	1	184	1	\N
186	1	185	1	290	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	186	1	185	1	\N
198	1	186	1	417	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	187	1	186	1	\N
202	1	187	1	375	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	188	1	187	1	\N
2	1	188	1	65500000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	190	1	188	1	\N
22	1	189	1	178	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	191	1	189	1	\N
102	1	190	1	59	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	192	1	190	1	\N
124	1	191	1	95	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	193	1	191	1	\N
200	1	192	1	394	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	194	1	192	1	\N
54	1	193	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	195	1	193	1	\N
225	1	194	1	256	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	196	1	194	1	\N
134	1	195	1	128	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	197	1	195	1	\N
97	1	196	1	199	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	198	1	196	1	\N
84	1	197	1	22	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	199	1	197	1	\N
161	1	198	1	276	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	200	1	198	1	\N
228	1	199	1	451	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	201	1	199	1	\N
238	1	200	1	133	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	202	1	200	1	\N
65	1	201	1	460	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	203	1	201	1	\N
219	1	202	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	204	1	202	1	\N
56	1	203	1	489	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	205	1	203	1	\N
3	1	204	1	500000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	190	1	204	1	\N
163	1	205	1	190	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	206	1	205	1	\N
192	1	206	1	221	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	207	1	206	1	\N
143	1	207	1	464	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	208	1	207	1	\N
61	1	208	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	209	1	208	1	\N
136	1	209	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	210	1	209	1	\N
71	1	210	1	353	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	211	1	210	1	\N
145	1	211	1	396	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	212	1	211	1	\N
106	1	212	1	417	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	213	1	212	1	\N
138	1	213	1	46	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	214	1	213	1	\N
158	1	214	1	305	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	215	1	214	1	\N
123	1	215	1	337	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	216	1	215	1	\N
25	1	216	1	444	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	217	1	216	1	\N
240	1	217	1	479	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	218	1	217	1	\N
5	1	218	1	0	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
211	1	219	1	344	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	219	1	219	1	\N
241	1	220	1	113	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	220	1	220	1	\N
197	1	221	1	236	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	221	1	221	1	\N
170	1	222	1	480	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	222	1	222	1	\N
31	1	223	1	160	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	223	1	223	1	\N
160	1	224	1	318	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	224	1	224	1	\N
21	1	225	1	214	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	225	1	225	1	\N
1	1	226	1	5000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
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
4	2	166	1	11549995000000000	1	2n1kEFeyR8tixDSRZ5JAAeRiayWa5Ct2LB7MSSD93aR8Zwi6hxzY	168	1	166	1	\N
3	2	204	1	1225000000000	1	2n1WTtR1vaQB939oopqhNNbQFKYxW3gkqxmSXawpiENxXgLqFYZb	190	1	204	1	\N
4	3	166	1	11549935000000000	13	2n1xQqhhX5q4YbNPyPn484UcWgRZeWxJvoR6A37vKtnkntqd3vD2	168	1	166	1	\N
3	3	204	1	1223250000000	8	2mzwStBC1zA2BWs5GT5XBXAUgBqraN38mzz7TK6J1uPnWfrUjSLw	190	1	204	1	\N
5	3	218	1	781750000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
4	4	166	1	11549845000000000	31	2mzvQbg1c5xtu6jraeqEjNjDEowLsznevcb1fSd1tmRkbqwHoF2G	168	1	166	1	\N
3	4	204	1	1221250000000	16	2n2RWLp5JBrE9EXSDor1XJ2FPPwmx5tuuKEGDyDnPKmhGdhECyqY	190	1	204	1	\N
5	4	218	1	1593750000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
7	5	27	1	844500000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
4	5	166	1	11549725000000000	55	2n13yB7UNL2UrNK9Wn4ULYdbwCMXFqnQzqP4rLRwjfF3VpdUGozY	168	1	166	1	\N
3	5	204	1	1216750000000	34	2n1V2kAVBQyVQyhtjGoYqR6ZbNoinrAJY1wN5XzK2mSeziUSvvcD	190	1	204	1	\N
4	6	166	1	11549725000000000	55	2n13yB7UNL2UrNK9Wn4ULYdbwCMXFqnQzqP4rLRwjfF3VpdUGozY	168	1	166	1	\N
3	6	204	1	1216750000000	34	2n1V2kAVBQyVQyhtjGoYqR6ZbNoinrAJY1wN5XzK2mSeziUSvvcD	190	1	204	1	\N
5	6	218	1	2438250000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
7	7	27	1	842000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
4	7	166	1	11549605000000000	79	2n1mNKpAryzjgC4DPtUDchFVuJy5dczZAuW99RFMqW6PBA5KDZrw	168	1	166	1	\N
3	7	204	1	1214750000000	42	2n2FQ2vERGxo4rJ8WEBZC9Q4Xo9gJ1XSt1a4WpgMcdSXmsE2sZru	190	1	204	1	\N
7	8	27	1	1669250000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
4	8	166	1	11549500000000000	100	2n1p38RMbjG4699k5GKhSjfEvmjYHqwvBQanq6XdYbj4tu1hqq54	168	1	166	1	\N
3	8	204	1	1212500000000	51	2n1wsn6EYx4WjpuKaYpddr7b6wMj3Nvm8wWBqgDwVUU7fQHpirHM	190	1	204	1	\N
7	9	27	1	2476250000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
4	9	166	1	11549415000000000	117	2n19gbYcq1Pw2v2xy5RHa2jck9tVxYLnMayz1smJmdv24x6YSqRJ	168	1	166	1	\N
3	9	204	1	1210500000000	59	2mzguqHVWVKF4G2U1RBFrsL3q8YekFh4irV2sLi39Kb9VbjMvxnf	190	1	204	1	\N
4	10	166	1	11549295000000000	141	2n2DNMuMscscgVsxqAPAnVwRZWPFn8uT1THnyPxQNPjRQSTWu7Te	168	1	166	1	\N
3	10	204	1	1206000000000	77	2n1TAbrGgLUF1PK8r5do7gepRJ3cNC6SwmeX5918gmY2A2s2Rg5w	190	1	204	1	\N
5	10	218	1	3282750000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
7	11	27	1	3320750000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
4	11	166	1	11549295000000000	141	2n2DNMuMscscgVsxqAPAnVwRZWPFn8uT1THnyPxQNPjRQSTWu7Te	168	1	166	1	\N
3	11	204	1	1206000000000	77	2n1TAbrGgLUF1PK8r5do7gepRJ3cNC6SwmeX5918gmY2A2s2Rg5w	190	1	204	1	\N
4	12	166	1	11549175000000000	165	2n2QXt4wjw776QjvJ83yn3Xzq3z6yxcJUGtP1kc3dUmbJ5go7R3q	168	1	166	1	\N
3	12	204	1	1201750000000	94	2n19NR8Vzqe7RjWLRBGSUHQjtcnjboMSdoors6eDcPFb9oJzknSb	190	1	204	1	\N
5	12	218	1	3282500000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
4	13	166	1	11549055000000000	189	2n1CnKjCNrgPDPo8HH3q8JTvGk3UJEZM9uDMq4nuZW8NgR3FmfUe	168	1	166	1	\N
3	13	204	1	1199750000000	102	2n1ECpiLWRSpTLJyjP6NA4pJS1deCiboW4dfS13BSWParJMz1k36	190	1	204	1	\N
5	13	218	1	4124500000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
4	14	166	1	11548935000000000	213	2n1qFMQPBmjrkoUAFwshjXygCCxFKXHV5Gnuv16BhPapwm14jkpg	168	1	166	1	\N
3	14	204	1	1197500000000	111	2mzdvkAN7XoLiSm8exMS4YbctKYuRh3fE4xegjjdiev7ybPY77m6	190	1	204	1	\N
5	14	218	1	4966750000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
7	15	27	1	4164946000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
4	15	166	1	11548815000000000	237	2n1KbKPx3wP5vWJKJVvtuBKzHLzcgNZJNkbD9x6u8fHoKzGBQv2v	168	1	166	1	\N
3	15	204	1	1193250000000	128	2n1bozRGfVzqUA1uNvWBW742WdbkVzynZJ5UoUkks5EJ8EkJaGev	190	1	204	1	\N
1	15	226	1	5054000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	16	27	1	5009439000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
4	16	166	1	11548695000000000	261	2n13iFetJSCd4KS2oJuYToQtXEat4ovzfBDtuZ1zK43as19sJ1X6	168	1	166	1	\N
3	16	204	1	1188750000000	146	2n1c5Yqh76bsCuhfEAtRCstXzD3sYJJwhBnry5Xn4osjCeTyqBmB	190	1	204	1	\N
1	16	226	1	5061000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	18	27	1	5851689000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
4	18	166	1	11548455000000000	309	2n2Fq6W9rMxzrSiRky1BxvswZFNwrdiF3jUizE6FBk8cXnkU3h3M	168	1	166	1	\N
3	18	204	1	1184500000000	163	2n1fmnRaiC9s76t4pngW7aGF7De9ndi7mH1xjriorzTLK8Zy2zck	190	1	204	1	\N
4	20	166	1	11548215000000000	357	2mzqzYqaAYZbxQsv6n5k3X5BRtAzVf6LVEvc2oHTbR9SZLXyWTj7	168	1	166	1	\N
3	20	204	1	1178000000000	189	2n1TTEztWFGPEKhyTAEEJKHihh1Vs34eY6THNh3E1GfYck3KnBuT	190	1	204	1	\N
5	20	218	1	6652989000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	20	226	1	5081000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
4	22	166	1	11548155000000000	369	2n1zEWnKzYr4sRSorHhwW4zEMEztDA4eyhAwbu6Utz5Hhh8TwRmn	168	1	166	1	\N
5	22	218	1	8152978000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	22	226	1	5092000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	24	27	1	8213910000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
4	24	166	1	11548075000000000	385	2mzvLroyBchzPuRjzVYi4D7FpVctH3eG5T9AQ5LM3G3Y9Q31YxTQ	168	1	166	1	\N
1	24	226	1	5112000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
4	17	166	1	11548575000000000	285	2n1s31n2cmjaUUeJMydyHCd8y4MuiE8kAfLQxBD5KEYEVyRHjBU5	168	1	166	1	\N
3	17	204	1	1186750000000	154	2n1bwCCKX3ePfiygyHev1GBPSPKqEuNY1FXLtuAEs3mM4MU63W2j	190	1	204	1	\N
5	17	218	1	5808747000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	17	226	1	5064000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	19	27	1	6693930000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
4	19	166	1	11548335000000000	333	2n29HmZU9brF3Y7LYPrpzfmqqrdF3tYtDzDCVqmicMHYD9d3fmPV	168	1	166	1	\N
3	19	204	1	1182250000000	172	2n16qyup7fiMTy1HuTP3aMSQEDABTApgsYJyyeNnqd6p2RuF2rzL	190	1	204	1	\N
1	19	226	1	5073000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
4	21	166	1	11548180000000000	364	2mzcPNZXgnJXsustxofZ8gN1t18WGHb9f4BJYpF3NvwhsijPDnzi	168	1	166	1	\N
5	21	218	1	7407985000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	21	226	1	5085000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	23	27	1	7443922000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
4	23	166	1	11548125000000000	375	2n118ogZDhHyiy95ujmokEebD3zjR5iypHQgiNWooY2o1FEQyVCq	168	1	166	1	\N
1	23	226	1	5100000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
4	25	166	1	11548040000000000	392	2n19PocJoF2P1kR9JonWSZFHZnmLKxKaArqSU9hHWZsdfuN9uPaN	168	1	166	1	\N
5	25	218	1	8907969000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	25	226	1	5121000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	26	27	1	8968901000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
4	26	166	1	11548040000000000	392	2n19PocJoF2P1kR9JonWSZFHZnmLKxKaArqSU9hHWZsdfuN9uPaN	168	1	166	1	\N
1	26	226	1	5121000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
4	27	166	1	11547920000000000	416	2n17dM6GhgBov4G9QP8SZ4BSCK8jV55hAkX6trPHiQMsm3HeRBpY	168	1	166	1	\N
3	27	204	1	1168750000000	226	2n2REHpzot3yj7nY1S22bej1rwNpVe5KcguY2M4F34u98EMg6xPM	190	1	204	1	\N
5	27	218	1	9002217000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	27	226	1	5132000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	28	27	1	9818140000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
4	28	166	1	11547920000000000	416	2n17dM6GhgBov4G9QP8SZ4BSCK8jV55hAkX6trPHiQMsm3HeRBpY	168	1	166	1	\N
3	28	204	1	1168750000000	226	2n2REHpzot3yj7nY1S22bej1rwNpVe5KcguY2M4F34u98EMg6xPM	190	1	204	1	\N
1	28	226	1	5132000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	29	27	1	10603135000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
4	29	166	1	11547855000000000	429	2mzoGX4WQouRHcom7JgYS19fV6XjqyUYeGJM91AuBjatnstehhgQ	168	1	166	1	\N
1	29	226	1	5137000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	30	27	1	11368124000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
4	30	166	1	11547810000000000	438	2n1a6mausKYotkaDoJhMybzSMN65aMTUPEajmMckC3M2bMCAwnwM	168	1	166	1	\N
1	30	226	1	5148000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	31	27	1	12103121000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
4	31	166	1	11547795000000000	441	2n1CGu9GvQbPkDYg6r9dBtK4DDuCZsZAx1JY5zbjoibMNaYV8iYD	168	1	166	1	\N
1	31	226	1	5151000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
4	32	166	1	11547795000000000	441	2n1CGu9GvQbPkDYg6r9dBtK4DDuCZsZAx1JY5zbjoibMNaYV8iYD	168	1	166	1	\N
5	32	218	1	8887975000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	32	226	1	5151000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
4	33	166	1	11547780000000000	444	2mzugWPGy2Xhx2416mJhhCwuePp4DVe7GYC5BMygURRgV52VTGbL	168	1	166	1	\N
5	33	218	1	8887973000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	33	226	1	5156000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	34	27	1	12828118000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
4	34	166	1	11547775000000000	445	2n299N5RCZqsHES3E6B8CbNucweNhz2ReigmboRXq6rw1Fmce3hP	168	1	166	1	\N
1	34	226	1	5159000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	35	27	1	13553115000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
4	35	166	1	11547770000000000	446	2n19tigCd8yWhWqeWH25TCD1j4DdbB2XJ4nb8FTvVkUVhvfJfk8s	168	1	166	1	\N
1	35	226	1	5162000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	36	27	1	14278112000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
4	36	166	1	11547765000000000	447	2n1ebyhnZHGV6Yd5WENincAQKBwvjjoFjGvVuDAdaCFD69hh5AWS	168	1	166	1	\N
1	36	226	1	5165000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	37	27	1	15008108000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
4	37	166	1	11547755000000000	449	2n1kYu6u26HAxLkMegFr6QfSswhd6mZZBDAksRE4S7ozgDVu3H6B	168	1	166	1	\N
1	37	226	1	5169000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
4	39	166	1	11547700000000000	460	2n2ASsEnWWoY6kTYJEf9fsfmPriZSm97WGBA3pbDSb9pbEx749yV	168	1	166	1	\N
5	39	218	1	9627967000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	39	226	1	5184000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
4	41	166	1	11547685000000000	463	2n2FU2RUt43YqRkKbpJZE72eyYsHXpTLRHQ8MkqUt3GPNKs8zMrv	168	1	166	1	\N
5	41	218	1	10362962000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	41	226	1	5189000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	43	27	1	16513092000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
4	43	166	1	11547535000000000	493	2n2AJV5erGGdh4Ue5oj5gWC7V9kcT1pwjpzQz9MadKgLDTP1rKn6	168	1	166	1	\N
1	43	226	1	5201000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	45	27	1	17258089000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
4	45	166	1	11547510000000000	498	2mzfn4pnxFYGsvBSqDKY3CYzGUP26yUnB7MHmVgkT1xF6egtpkDw	168	1	166	1	\N
1	45	226	1	5204000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	47	27	1	17998083000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
4	47	166	1	11547485000000000	503	2n28S9xsvDVGsAghw8RB6bn7h4EUb6fK9BgEPE68h714QYSJ1yGa	168	1	166	1	\N
1	47	226	1	5213000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	49	27	1	17993084000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
4	49	166	1	11547470000000000	506	2n2HmcEEjwerqVnUwYqr3LB7jiugodCCD9qS1f5XYhMmBX45KePJ	168	1	166	1	\N
1	49	226	1	5218000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	38	27	1	15763099000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
4	38	166	1	11547720000000000	456	2n2MbgGux7D871ZAoSdj8QCoz2zC6VPiEEHfZpeEmgJNBaeH9cYK	168	1	166	1	\N
1	38	226	1	5178000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	40	27	1	16498094000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
4	40	166	1	11547685000000000	463	2n2FU2RUt43YqRkKbpJZE72eyYsHXpTLRHQ8MkqUt3GPNKs8zMrv	168	1	166	1	\N
1	40	226	1	5189000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
4	42	166	1	11547565000000000	487	2n1QAdwXr12RX5dUzezpozppkc4ahCvt8upmhkyVsF14EhMGoigw	168	1	166	1	\N
3	42	204	1	1167500000000	231	2mzmFJdV5J4QtevsotqHSDDg5A1f6x13zFUZ226CMkZfRJ8XaYhx	190	1	204	1	\N
5	42	218	1	11204207000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	42	226	1	5194000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
4	44	166	1	11547535000000000	493	2n2AJV5erGGdh4Ue5oj5gWC7V9kcT1pwjpzQz9MadKgLDTP1rKn6	168	1	166	1	\N
5	44	218	1	11954200000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	44	226	1	5201000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
4	46	166	1	11547505000000000	499	2n1jajr4RKtn7akvH9dJaLtJCiu8PCXUdnH9gFQQZ7hQPaiPZNrd	168	1	166	1	\N
5	46	218	1	11929204000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	46	226	1	5207000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
4	48	166	1	11547485000000000	503	2n28S9xsvDVGsAghw8RB6bn7h4EUb6fK9BgEPE68h714QYSJ1yGa	168	1	166	1	\N
5	48	218	1	12669198000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	48	226	1	5213000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
4	50	166	1	11547465000000000	507	2n1PqDhpCza51mJG8gaCKSK4TTtCaKuUgHhRFbHcyrssuVo38UoR	168	1	166	1	\N
5	50	218	1	13394195000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	50	226	1	5221000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	51	27	1	18718081000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
4	51	166	1	11547465000000000	507	2n1PqDhpCza51mJG8gaCKSK4TTtCaKuUgHhRFbHcyrssuVo38UoR	168	1	166	1	\N
1	51	226	1	5221000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
4	52	166	1	11547460000000000	508	2n1GeaG5gUJuc2asWr6g3ijbzmbX6WPkPfpK5sipq5n4DknXy77s	168	1	166	1	\N
5	52	218	1	14119192000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	52	226	1	5224000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	53	27	1	18718081000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
4	53	166	1	11547460000000000	508	2n1GeaG5gUJuc2asWr6g3ijbzmbX6WPkPfpK5sipq5n4DknXy77s	168	1	166	1	\N
1	53	226	1	5224000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	54	27	1	18718081000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
4	54	166	1	11547455000000000	509	2n1udX1Dibw7pdkqEs9rtrHRtniTxhYFg8n3gJJCtRw2QFkyVfxz	168	1	166	1	\N
1	54	226	1	5227000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
4	55	166	1	11547455000000000	509	2n1udX1Dibw7pdkqEs9rtrHRtniTxhYFg8n3gJJCtRw2QFkyVfxz	168	1	166	1	\N
5	55	218	1	14844189000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	55	226	1	5227000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	56	27	1	19503066000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
4	56	166	1	11547390000000000	522	2n1hoFqUyy8SNfXFMwkYy4mxZK7qP8Rs3bKfXTVQErT91VVyow7T	168	1	166	1	\N
1	56	226	1	5242000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
4	57	166	1	11547385000000000	523	2mzqsoiBvErmhrxtqoxrE4tJV9qRuseB72VK7sMEREJBSwYkMXwF	168	1	166	1	\N
5	57	218	1	14844189000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	57	226	1	5245000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	58	27	1	20238061000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
4	58	166	1	11547370000000000	526	2mziBG36cpDvcgjpEfU4cvzxHgNJWqydkpmfed6exddMMWXbsf1C	168	1	166	1	\N
1	58	226	1	5250000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	59	27	1	20968057000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
4	59	166	1	11547360000000000	528	2mzzANZUsyU7uknsJcifU3Hnz4Grm7afSE1AU9HUPemwhThH9Ur6	168	1	166	1	\N
1	59	226	1	5254000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
4	60	166	1	11547360000000000	528	2mzzANZUsyU7uknsJcifU3Hnz4Grm7afSE1AU9HUPemwhThH9Ur6	168	1	166	1	\N
5	60	218	1	15574185000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	60	226	1	5254000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
4	61	166	1	11547350000000000	530	2n1HhLL5V22Ja8S6LnLmGpRnerqKjx3co3V4Pk6pbBGARL3YerYK	168	1	166	1	\N
5	61	218	1	15574185000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	61	226	1	5258000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	63	27	1	21703052000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
4	63	166	1	11547335000000000	533	2n1MRwv7bQ9UbAMg8u9o9eZQ4TPQn2n8TSaFNeGzZvE1AasZm8v4	168	1	166	1	\N
1	63	226	1	5263000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
4	65	166	1	11547305000000000	539	2mzektMfS1LWJPqUhKKAbY9c8SaXn57eeTfn8JFbpVW3xJbypEBU	168	1	166	1	\N
5	65	218	1	17044175000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	65	226	1	5273000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
4	67	166	1	11547260000000000	548	2n1DXSgZaQWQFCJ4WjY7zUCW5dtekGVvLBC7Y1Djuee5YkwmSj1L	168	1	166	1	\N
5	67	218	1	17809164000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	67	226	1	5284000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
4	69	166	1	11547115000000000	577	2n2GJAo2sQmpuMUkPeBUmyuukwuJdbVmWJyvDhKeLdzmkPscqSxv	168	1	166	1	\N
5	69	218	1	18554161000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	69	226	1	5291000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	73	27	1	23274294000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
4	73	166	1	11547075000000000	585	2n1QytPX9b97xHAD3bzox2NAwUQCRAfYmq7x4jFkBeb9r6WFdYHu	168	1	166	1	\N
1	73	226	1	5303000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	75	27	1	23269295000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
4	75	166	1	11547070000000000	586	2n2ACqjvmYUmF7sy26ZjAm28JWeh4GPt6Xv96WQC9kpMfF1KiUyj	168	1	166	1	\N
1	75	226	1	5306000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
4	77	166	1	11547005000000000	599	2n265yNNBuegLw8BoAGPT4MRSPjunqt9T8LUUGEzyWgDVcXadtHR	168	1	166	1	\N
5	77	218	1	21539132000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	77	226	1	5323000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	79	27	1	23994292000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
4	79	166	1	11547000000000000	600	2n127QVCV7vySxZgHNJSmXsS3bhxNySWup27gqfvaX1R11ivVQzr	168	1	166	1	\N
1	79	226	1	5326000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
4	81	166	1	11546970000000000	606	2n15qubJABjd4mjQkwkHcZnRi3iNELpJApGYgQ12euJBaVgk6mfV	168	1	166	1	\N
5	81	218	1	22289124000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	81	226	1	5334000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	83	27	1	24724288000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
4	83	166	1	11546940000000000	612	2n1fQcpPovEPMzKvYVcGGDMcLQmLbSteR1ksBDNsVLHwX3HmQ3Tr	168	1	166	1	\N
1	83	226	1	5344000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	62	27	1	21698053000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
4	62	166	1	11547350000000000	530	2n1HhLL5V22Ja8S6LnLmGpRnerqKjx3co3V4Pk6pbBGARL3YerYK	168	1	166	1	\N
1	62	226	1	5258000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
4	64	166	1	11547320000000000	536	2n1Dsf7cbXDcYqxSEibPte9m8264XSubtuZaW6kH5jorNEKBF9au	168	1	166	1	\N
5	64	218	1	16309180000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	64	226	1	5268000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	66	27	1	22468041000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
4	66	166	1	11547260000000000	548	2n1DXSgZaQWQFCJ4WjY7zUCW5dtekGVvLBC7Y1Djuee5YkwmSj1L	168	1	166	1	\N
1	66	226	1	5284000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	68	27	1	22544298000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
4	68	166	1	11547140000000000	572	2n1E4k2Ab2XRcPS2JR41PcgLQX4M2tLZaqL6QPvWpLhfNWMk2tbk	168	1	166	1	\N
3	68	204	1	1166250000000	236	2n1vXXQPGqpGv57CUU9Y9dPYvg7VcuTXcxEY3hJ4fK1cpPtuzyff	190	1	204	1	\N
1	68	226	1	5288000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
4	70	166	1	11547085000000000	583	2mzk51FsTehi56XrBfqr59uqhvcyR9ECgV9JkyrGuBwbohstPZ7Q	168	1	166	1	\N
5	70	218	1	19304153000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	70	226	1	5299000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	71	27	1	23294290000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
4	71	166	1	11547085000000000	583	2mzk51FsTehi56XrBfqr59uqhvcyR9ECgV9JkyrGuBwbohstPZ7Q	168	1	166	1	\N
1	71	226	1	5299000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
4	72	166	1	11547075000000000	585	2n1QytPX9b97xHAD3bzox2NAwUQCRAfYmq7x4jFkBeb9r6WFdYHu	168	1	166	1	\N
5	72	218	1	20034149000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	72	226	1	5303000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
4	74	166	1	11547070000000000	586	2n2ACqjvmYUmF7sy26ZjAm28JWeh4GPt6Xv96WQC9kpMfF1KiUyj	168	1	166	1	\N
5	74	218	1	20759146000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	74	226	1	5306000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
4	76	166	1	11547065000000000	587	2n1eSWhrEevgobiB1kEuvQ9yz8YsdpdSnzYiqLtv6TcCoxTPh75f	168	1	166	1	\N
5	76	218	1	20759146000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	76	226	1	5309000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	78	27	1	24049281000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
4	78	166	1	11547005000000000	599	2n265yNNBuegLw8BoAGPT4MRSPjunqt9T8LUUGEzyWgDVcXadtHR	168	1	166	1	\N
1	78	226	1	5323000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	80	27	1	24739285000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
4	80	166	1	11546975000000000	605	2mzpnhk1tS2th62Bj4FSmgbCmRB76gVRH9KEAqWsZ2AzExjKrbqN	168	1	166	1	\N
1	80	226	1	5333000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
4	82	166	1	11546950000000000	610	2n26FzJk4jnw1fPrJk9sKRyzGH2YyecRHY6k51uWz7MdRNkTMfDs	168	1	166	1	\N
5	82	218	1	23029118000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	82	226	1	5340000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	84	27	1	25449285000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
4	84	166	1	11546935000000000	613	2n1n2CsDVL2BGGhP8AEsH7bUhpResqn6mvhTRHvGb7fhKYH4kdtu	168	1	166	1	\N
1	84	226	1	5347000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
4	85	166	1	11546935000000000	613	2n1n2CsDVL2BGGhP8AEsH7bUhpResqn6mvhTRHvGb7fhKYH4kdtu	168	1	166	1	\N
5	85	218	1	23754115000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	85	226	1	5347000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
4	86	166	1	11546930000000000	614	2n1zZtj8GBVXd8DRzRnHMNa91Kt2XhNfn1Azk3RKqZ8aEvURutGz	168	1	166	1	\N
5	86	218	1	23754115000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	86	226	1	5350000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
4	87	166	1	11546915000000000	617	2n1it2pdmdLipGzfTdezxr6kAWYfbJo5enhHKfeT6CMKzW2Adfhw	168	1	166	1	\N
5	87	218	1	24489110000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	87	226	1	5355000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	88	27	1	26184280000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
4	88	166	1	11546915000000000	617	2n1it2pdmdLipGzfTdezxr6kAWYfbJo5enhHKfeT6CMKzW2Adfhw	168	1	166	1	\N
1	88	226	1	5355000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	89	27	1	26234270000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
4	89	166	1	11546850000000000	630	2n1n85k5XMviHfS9FTfgE7wuGcRBAMtiChkFBdjmkCH5zzZQo4Bn	168	1	166	1	\N
1	89	226	1	5370000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
4	91	166	1	11546815000000000	637	2n2HGuEV6WPo2eqzjwwTnwUyiSP1c2CJ2HXKAmMbzWReDh3rwsvs	168	1	166	1	\N
5	91	218	1	25964099000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	91	226	1	5381000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	92	27	1	26969265000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
4	92	166	1	11546815000000000	637	2n2HGuEV6WPo2eqzjwwTnwUyiSP1c2CJ2HXKAmMbzWReDh3rwsvs	168	1	166	1	\N
1	92	226	1	5381000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
4	93	166	1	11546695000000000	661	2mzkrW91NX565gcFUznAXR5Xu7xeSX5ToWv8sYDTk2GScgDQTarD	168	1	166	1	\N
3	93	204	1	1165000000000	241	2n1TdnyPcnrspdQZTAzPScPVzrMkekozSir6TcK7QBD4ANa3BLAd	190	1	204	1	\N
5	93	218	1	26805345000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	93	226	1	5385000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
4	95	166	1	11546670000000000	666	2n2LLVrMT5kg4DFG4SWdDESx7ZwANLqeAiqjvE59WPLW4ubcDUSs	168	1	166	1	\N
5	95	218	1	26709096000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	95	226	1	5388000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
4	97	166	1	11546635000000000	673	2mzaFyxoXGxV3fyb2UWzKmr3skJUeESfExZWVRWqCAKKbKKjLtY3	168	1	166	1	\N
5	97	218	1	27464087000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	97	226	1	5397000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	99	27	1	28560503000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
4	99	166	1	11546575000000000	685	2n19NvxjbaNKTqvuL82jdJ4JGjiZ3r1Y14ZE1FCjV6L1wj1iaiG3	168	1	166	1	\N
1	99	226	1	5413000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
4	101	166	1	11546570000000000	686	2n1gwQSjxnJq7HxqbHXK2Mb8KGHgpCtw4Zz4VAcdU2YKJGAqjcs9	168	1	166	1	\N
5	101	218	1	28204081000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	101	226	1	5416000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
4	103	166	1	11546560000000000	688	2n16c3osgrhKuANPUvdavQNJkwt5y6BnpMv9hyBaDgxapaUaykZQ	168	1	166	1	\N
5	103	218	1	28929078000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	103	226	1	5422000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
4	105	166	1	11546550000000000	690	2n2Li7RVmQ8kh81h8cVM4zTtyKWvnkHaNZu6afvEfnpimHqnGk2i	168	1	166	1	\N
5	105	218	1	28934077000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	105	226	1	5426000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
4	107	166	1	11546510000000000	698	2n1vwCHdyLt9A7sErgCXbUTcRkzoZ1m3fw4XuoYiWbUyJDGcxDWA	168	1	166	1	\N
5	107	218	1	29684069000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	107	226	1	5438000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
4	109	166	1	11546480000000000	704	2n19NPvrvVPwfvbNqEfLghT74QnnXDQD9eJcehmpc3CUxCuTF5YF	168	1	166	1	\N
5	109	218	1	30434061000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	109	226	1	5446000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	111	27	1	31470489000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
4	111	166	1	11546470000000000	706	2n29XQfbCMB9KDsdweJcKiGwa81UtJNrV7Kt3LqpqwMmRyEeUK91	168	1	166	1	\N
1	111	226	1	5450000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	113	27	1	31475488000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
4	113	166	1	11546455000000000	709	2n13QjkWcxQkrJ5aYiymedetWBtfwpR2NfFBDJjXWssRshzmrMpY	168	1	166	1	\N
1	113	226	1	5455000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
4	90	166	1	11546830000000000	634	2n2Cx5mJT5hzy23iyAEqh1XBRmDPhpQwYxixNPP9mno9Gr9t88FU	168	1	166	1	\N
5	90	218	1	25229104000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	90	226	1	5376000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	94	27	1	27075516000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
4	94	166	1	11546695000000000	661	2mzkrW91NX565gcFUznAXR5Xu7xeSX5ToWv8sYDTk2GScgDQTarD	168	1	166	1	\N
3	94	204	1	1165000000000	241	2n1TdnyPcnrspdQZTAzPScPVzrMkekozSir6TcK7QBD4ANa3BLAd	190	1	204	1	\N
1	94	226	1	5385000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	96	27	1	27830507000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
4	96	166	1	11546635000000000	673	2mzaFyxoXGxV3fyb2UWzKmr3skJUeESfExZWVRWqCAKKbKKjLtY3	168	1	166	1	\N
1	96	226	1	5397000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
4	98	166	1	11546585000000000	683	2mzxmMLUDRcA2vdR7bKD8eiqbM4p81sN8X6QcUpzjvuXBHCpNjvT	168	1	166	1	\N
5	98	218	1	27479084000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	98	226	1	5409000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	100	27	1	29285500000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
4	100	166	1	11546570000000000	686	2n1gwQSjxnJq7HxqbHXK2Mb8KGHgpCtw4Zz4VAcdU2YKJGAqjcs9	168	1	166	1	\N
1	100	226	1	5416000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
4	102	166	1	11546565000000000	687	2mzckaY6PSShkAepJrRfZHrbqAmFQHyrFd7Y1t2cLe7NdT6JZkJP	168	1	166	1	\N
5	102	218	1	28204081000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	102	226	1	5419000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	104	27	1	30010497000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
4	104	166	1	11546560000000000	688	2n16c3osgrhKuANPUvdavQNJkwt5y6BnpMv9hyBaDgxapaUaykZQ	168	1	166	1	\N
1	104	226	1	5422000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	106	27	1	30740493000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
4	106	166	1	11546540000000000	692	2n1QFszUYeYWhaLYKGwvNs8h8qaqd7zooCCkp6G7ZpxxvyuejaHJ	168	1	166	1	\N
1	106	226	1	5430000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	108	27	1	31490485000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
4	108	166	1	11546510000000000	698	2n1vwCHdyLt9A7sErgCXbUTcRkzoZ1m3fw4XuoYiWbUyJDGcxDWA	168	1	166	1	\N
1	108	226	1	5438000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
4	110	166	1	11546470000000000	706	2n29XQfbCMB9KDsdweJcKiGwa81UtJNrV7Kt3LqpqwMmRyEeUK91	168	1	166	1	\N
5	110	218	1	31164057000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	110	226	1	5450000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
4	112	166	1	11546455000000000	709	2n13QjkWcxQkrJ5aYiymedetWBtfwpR2NfFBDJjXWssRshzmrMpY	168	1	166	1	\N
5	112	218	1	31899052000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	112	226	1	5455000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
4	114	166	1	11546445000000000	711	2n2BSSbmDMmW7mGDyU2ecDQefBaHL8KbJWiatEGeciQT2XArZK3Y	168	1	166	1	\N
5	114	218	1	31894053000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	114	226	1	5459000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	115	27	1	32205484000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
4	115	166	1	11546445000000000	711	2n2BSSbmDMmW7mGDyU2ecDQefBaHL8KbJWiatEGeciQT2XArZK3Y	168	1	166	1	\N
1	115	226	1	5459000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	116	27	1	32210483000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
4	116	166	1	11546430000000000	714	2n1dNx6ThrxFHXZMVJ7AV3nyeEdfVAWc6VBCoaBxid79Ana1j6iH	168	1	166	1	\N
1	116	226	1	5464000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
4	117	166	1	11546415000000000	717	2n1Vpf67NtzLX29jrp5suhSJWQowv41ch177wRozYadJD7s7dWUf	168	1	166	1	\N
5	117	218	1	32629048000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	117	226	1	5469000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	118	27	1	32945478000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
4	118	166	1	11546415000000000	717	2n1Vpf67NtzLX29jrp5suhSJWQowv41ch177wRozYadJD7s7dWUf	168	1	166	1	\N
1	118	226	1	5469000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
4	119	166	1	11546400000000000	720	2n1GGfc62DkaMcFpjwWjRtvh6ngbnP4P54PBJuctZgZzvXuA1HvU	168	1	166	1	\N
5	119	218	1	32629048000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	119	226	1	5474000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	120	27	1	33680473000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
4	120	166	1	11546400000000000	720	2n1GGfc62DkaMcFpjwWjRtvh6ngbnP4P54PBJuctZgZzvXuA1HvU	168	1	166	1	\N
1	120	226	1	5474000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
4	122	166	1	11546335000000000	733	2mziZgqrLhb6CtBUFQZzqde9aneRtovShCaL7GniXp21R8urQiyD	168	1	166	1	\N
5	122	218	1	33414036000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	122	226	1	5486000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	124	27	1	34465470000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
4	124	166	1	11546255000000000	749	2n1B537u5oQiv5U8vFn336EQVFJ6MrWWJncGSR9Zq3khtGsGtr1P	168	1	166	1	\N
1	124	226	1	5494000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	126	27	1	35190467000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
4	126	166	1	11546250000000000	750	2mzuoG5J7dCaH9e8jAbs7MfVJKLsp8qvJDZ724fLDup3S7cqSp6U	168	1	166	1	\N
1	126	226	1	5497000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	128	27	1	35915464000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
4	128	166	1	11546245000000000	751	2n1G79iM3rVpnXg1d1pN5hry6rzjAMsVdJh3K6uEVKg7gk2DDcv7	168	1	166	1	\N
1	128	226	1	5500000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
4	130	166	1	11546200000000000	760	2n1Y8pqc7foz4iE8NX7tzkLXvFHaaDs6EhXyjmzDX4qHPPoJtAvR	168	1	166	1	\N
5	130	218	1	34899023000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	130	226	1	5513000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
4	132	166	1	11546180000000000	764	2n128GEWZJcRh19a2UNkPMVdHPundTsLGcgV6avrHrFAg2XdAESV	168	1	166	1	\N
5	132	218	1	34884026000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	132	226	1	5519000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	134	27	1	38190435000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
4	134	166	1	11546100000000000	780	2mzxssLHJdvdxntwrZcGK2hYH8datTgLY193Tms3XKTgF7swp9V8	168	1	166	1	\N
1	134	226	1	5539000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
4	136	166	1	11546025000000000	795	2n26N8bLoWRMR8ZYWieViYEJCBBXZFHp4EtbD76JtMxWSXQs5Rap	168	1	166	1	\N
5	136	218	1	35674010000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	136	226	1	5558000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	138	27	1	40385422000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
4	138	166	1	11545995000000000	801	2n2QdafmGwT9pdoSVX5nHca74L98XoBhkNip5nhKScfk761bNLf8	168	1	166	1	\N
1	138	226	1	5568000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	140	27	1	41175406000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
4	140	166	1	11545905000000000	819	2n16aofpoHSeJRwv5jEynzzjN8sBdyRSMB83NUtPsSbJTmyYoray	168	1	166	1	\N
1	140	226	1	5590000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
3	142	204	1	1160250000000	260	2n1G6xTUfrLZYco7QEXFEUX5zLy6dDJHtF5vrvw6Yuw2z9nzJFrb	190	1	204	1	\N
5	142	218	1	37898735000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	142	226	1	5593000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
3	144	204	1	1159750000000	262	2n2LWSxqhazBMBPKdiqVWZ4Y6HsP5jbZi9ysuRYRpnTqpavrJgXq	190	1	204	1	\N
5	144	218	1	38619232000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	144	226	1	5600000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	146	27	1	41870411000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
4	146	166	1	11545890000000000	822	2n2QjZWJ1qsLdWckJaoa87ZSKo6tuZW7tpLwuiaVhkKTQVdWy5Y2	168	1	166	1	\N
1	146	226	1	5612000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	148	27	1	42595408000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
4	148	166	1	11545885000000000	823	2n29XV4FaxsvBFDAHseNNYQh6EqESnBKZFj1LJ88rNMaWcvfWsS5	168	1	166	1	\N
1	148	226	1	5623000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
3	150	204	1	1886996000000	273	2mzr3aN3ZggpjjBks4KugSQsnqxuM8dDi2ks4WDVqGVBEo3ipVLK	190	1	204	1	\N
5	150	218	1	40781965000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	150	226	1	5631000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	121	27	1	33730466000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
4	121	166	1	11546335000000000	733	2mziZgqrLhb6CtBUFQZzqde9aneRtovShCaL7GniXp21R8urQiyD	168	1	166	1	\N
1	121	226	1	5486000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	123	27	1	33730475000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
4	123	166	1	11546270000000000	746	2mzn2dNa7GFPLk4DUAGGuooU5ipgaQ7TqfebjQKWWqKn5aQm5DCw	168	1	166	1	\N
1	123	226	1	5489000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
4	125	166	1	11546255000000000	749	2n1B537u5oQiv5U8vFn336EQVFJ6MrWWJncGSR9Zq3khtGsGtr1P	168	1	166	1	\N
5	125	218	1	34149031000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	125	226	1	5494000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
4	127	166	1	11546250000000000	750	2mzuoG5J7dCaH9e8jAbs7MfVJKLsp8qvJDZ724fLDup3S7cqSp6U	168	1	166	1	\N
5	127	218	1	34139033000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	127	226	1	5497000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
4	129	166	1	11546235000000000	753	2mzosicbR3D1LKLwBZDABYvv3xxwnjd1SYn96STFvCeyDN7R6PvS	168	1	166	1	\N
5	129	218	1	34144032000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	129	226	1	5504000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	131	27	1	36670455000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
4	131	166	1	11546200000000000	760	2n1Y8pqc7foz4iE8NX7tzkLXvFHaaDs6EhXyjmzDX4qHPPoJtAvR	168	1	166	1	\N
1	131	226	1	5513000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	133	27	1	37440443000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
4	133	166	1	11546130000000000	774	2n1zwW7C59Rk6SmTKTq4tBUAfhtSdp2NY3CcZ1wx2jQM18KbBX1h	168	1	166	1	\N
1	133	226	1	5531000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	135	27	1	38915432000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
4	135	166	1	11546095000000000	781	2n19FZThywAoB3Sdrx24JP1Lzb3nYeBgdL2E34rvvAee95KoTcVA	168	1	166	1	\N
1	135	226	1	5542000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	137	27	1	39650427000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
4	137	166	1	11546010000000000	798	2n1xfpwQFXY79969E6JZ9P8ozaVTu9nqJrjeizAamsVJxotNjCuL	168	1	166	1	\N
1	137	226	1	5563000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
4	139	166	1	11545975000000000	805	2n1cs2FrbGKPqcVR7zzsPShPaeg41LtdrXVNefVYrLhR6sY7Vigt	168	1	166	1	\N
5	139	218	1	36414004000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	139	226	1	5574000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
4	141	166	1	11545935000000000	813	2n223dADPN2gUP4EVACGa3CZ46jnxVu543cqpRbExCPhKNaXttJP	168	1	166	1	\N
3	141	204	1	1163500000000	247	2n1WmREBgazJbxAsmcXqcgUDq6kKHQPwBjob66fSdCYscrxsc7C7	190	1	204	1	\N
5	141	218	1	37175488000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	141	226	1	5590000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	143	27	1	41125418000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
4	143	166	1	11545915000000000	817	2n1XvYrVdkmM765FC2YLCMbVZaWExUCF4AWEed7gT8NNc3wh3Xp9	168	1	166	1	\N
1	143	226	1	5597000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
3	145	204	1	1159000000000	265	2n1VampHic3TMssahKV52SbkpmVf66NMVGi6ggA8AZk5fGrFb6jt	190	1	204	1	\N
5	145	218	1	39339977000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	145	226	1	5605000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
3	147	204	1	1157500000000	271	2n1JBj7ndWab4kyL1ZqDHFTh5fijeGvwGV8o2QfgjoKZRueBBZt6	190	1	204	1	\N
5	147	218	1	40061469000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	147	226	1	5620000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
4	149	166	1	11545875000000000	825	2mzukXTx83QNgL7LSW8k1LNGdeDtkBdwesU5DXX4CrDsb4KqMD87	168	1	166	1	\N
3	149	204	1	1887496000000	271	2n1JBj7ndWab4kyL1ZqDHFTh5fijeGvwGV8o2QfgjoKZRueBBZt6	190	1	204	1	\N
1	149	226	1	5627000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
3	151	204	1	1886496000000	275	2n1nN4ksEBLhTuTjaRhLQ3gL7QfEf31KBytj6Cqg7JGJdD3KKCdC	190	1	204	1	\N
5	151	218	1	41502461000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	151	226	1	5635000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	152	27	1	43320654000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
4	152	166	1	11545870000000000	826	2n1r5FR5KxoyowftQ13Qup658y5mf2F1aBKVEtAZzht5BT71FSum	168	1	166	1	\N
3	152	204	1	1886746000000	274	2n1wfjpTBjL2TEhZiRhwGscvqRFsmDb2DLYHvUmKkhmF1Smij66b	190	1	204	1	\N
1	152	226	1	5635000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
3	153	204	1	1885996000000	277	2n1VrfZERF7iJMXVS6rGoimsNF6tTFWNJXgtUjmxU7oTVsXvUPRP	190	1	204	1	\N
5	153	218	1	42222957000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	153	226	1	5639000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	154	27	1	43320405000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
4	154	166	1	11545870000000000	826	2n1r5FR5KxoyowftQ13Qup658y5mf2F1aBKVEtAZzht5BT71FSum	168	1	166	1	\N
1	154	226	1	5642000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
3	155	204	1	1885746000000	278	2n1gsP7g7aVysEDzFxv7TXFLjiDB1sJiezHcfvYxSU1cJ472spiK	190	1	204	1	\N
5	155	218	1	42943204000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	155	226	1	5642000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
4	156	166	1	11545870000000000	826	2n1r5FR5KxoyowftQ13Qup658y5mf2F1aBKVEtAZzht5BT71FSum	168	1	166	1	\N
5	156	218	1	43668201000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	156	226	1	5645000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	157	27	1	43320405000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
4	157	166	1	11545870000000000	826	2n1r5FR5KxoyowftQ13Qup658y5mf2F1aBKVEtAZzht5BT71FSum	168	1	166	1	\N
1	157	226	1	5645000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	158	27	1	44040652000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
3	158	204	1	1885496000000	279	2n1hnBmH6T3Gej4qhQnG7eCS5T3ubG3gQSpfJzZBwFouFb9d5D8R	190	1	204	1	\N
1	158	226	1	5648000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
3	159	204	1	1885496000000	279	2n1hnBmH6T3Gej4qhQnG7eCS5T3ubG3gQSpfJzZBwFouFb9d5D8R	190	1	204	1	\N
5	159	218	1	43663451000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	159	226	1	5648000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
3	160	204	1	1884996000000	281	2n14DKnkDxX5rykBuR8UwAma39Gowz3DPtW8Yh5iNTBwfvmC6SK9	190	1	204	1	\N
5	160	218	1	44383947000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	160	226	1	5652000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
3	161	204	1	1884746000000	282	2mzrhw9T1tn9FHDKDDYCPArLBSgj5qLc5pKjFrVkQvWihHi4BodM	190	1	204	1	\N
5	161	218	1	45104194000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	161	226	1	5655000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
3	162	204	1	1883996000000	285	2mzbMh2jNS2Mj6CcJcvrCkrsdUJQRJsNCzLjsb6JKdTW4E1in45d	190	1	204	1	\N
5	162	218	1	45824939000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	162	226	1	5660000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	163	27	1	44041150000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
3	163	204	1	1883996000000	285	2mzbMh2jNS2Mj6CcJcvrCkrsdUJQRJsNCzLjsb6JKdTW4E1in45d	190	1	204	1	\N
1	163	226	1	5660000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	164	27	1	44043889000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
3	164	204	1	1880496000000	299	2n2QaJYuD1FmiTXqCUqpBeE7cz1KaQLV3C8D11SxUsxhqgJsezjc	190	1	204	1	\N
1	164	226	1	5676000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	165	27	1	44764883000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
3	165	204	1	1879496000000	303	2mzZYs3ahc8nrGRzwmPbfBYFPQw1hUmBkMMs3UXzR26ytfMPWHjN	190	1	204	1	\N
1	165	226	1	5682000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
3	166	204	1	1879496000000	303	2mzZYs3ahc8nrGRzwmPbfBYFPQw1hUmBkMMs3UXzR26ytfMPWHjN	190	1	204	1	\N
5	166	218	1	46545933000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	166	226	1	5682000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
3	167	204	1	1878996000000	305	2n2PwKagssMr1DYjdUkBffMcRai5uAXFiDQoCeUrfFBVJSnfNMoj	190	1	204	1	\N
5	167	218	1	46545435000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	167	226	1	5686000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
3	168	204	1	1877996000000	309	2n26oDSrYFpMCo2ZUGotgdh3wqcZFJFwiRGAxebi5UQD3bowBUTF	190	1	204	1	\N
5	168	218	1	47266429000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	168	226	1	5692000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
3	169	204	1	1877246000000	312	2n2K8ZpxzF2cQYnN4VrDMus5nSp5zFBcwgcqxDFcryHPoLGdMmoo	190	1	204	1	\N
5	169	218	1	47987174000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	169	226	1	5697000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	170	27	1	45485628000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
3	170	204	1	1876496000000	315	2n1r2DFSTnAimF7gmrwXzDQAmk9KyhvRcKtYJGqhe5qABWhpgYqe	190	1	204	1	\N
1	170	226	1	5702000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
3	171	204	1	1876496000000	315	2n1r2DFSTnAimF7gmrwXzDQAmk9KyhvRcKtYJGqhe5qABWhpgYqe	190	1	204	1	\N
5	171	218	1	48707919000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	171	226	1	5702000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
3	173	204	1	1873246000000	328	2n11jrGXxUjE9rrv5eesVMNQUVsydnU6McbmGxaXpsPncdj3gavf	190	1	204	1	\N
5	173	218	1	48710420000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	173	226	1	5706000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	177	27	1	47650607000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
3	177	204	1	1868246000000	348	2n2LHpJau5BTeQjwS5ftSLZgb7NHhaR1Ya5DMiyLhhJm6Kpvz22N	190	1	204	1	\N
1	177	226	1	5727000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	179	27	1	48370854000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
3	179	204	1	1867996000000	349	2mzafQZSFu3q8MFZBmYZUwJSP65rC1MFKW22MapS7oy2f7TwsSLs	190	1	204	1	\N
1	179	226	1	5730000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	181	27	1	48371103000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
3	181	204	1	1867496000000	351	2mzfJoWk1urkpewev8VBBUJHyTYN3gtG67ydFk7KFRKTtPZeagor	190	1	204	1	\N
1	181	226	1	5734000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
3	183	204	1	1863996000000	365	2mzmZv5gArcnn9Ycmuk3CxfxthZgqC41KkCF2TMs5AX3yRmezAhh	190	1	204	1	\N
5	183	218	1	50154151000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	183	226	1	5750000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	185	27	1	49813838000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
3	185	204	1	1861246000000	376	2mzozPZiPtRuEd3ui78siamHVonyPmz7QcgifDo6WQ8ksL6CWJDT	190	1	204	1	\N
1	185	226	1	5765000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
3	187	204	1	1858746000000	386	2n1ifPuiZ1B5RFwoDadc8SGhwDYfz5qfhrb3y1ry796myus8AjC8	190	1	204	1	\N
5	187	218	1	51596637000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	187	226	1	5779000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	189	27	1	51255328000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
3	189	204	1	1857996000000	389	2mzeioQRB4JjxscMP4ykjssv88nj1Nh1gM26a9Rog4YnwxkxpRMx	190	1	204	1	\N
1	189	226	1	5784000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
3	191	204	1	1853246000000	408	2n2E7xYmQvWjrirPijXJdmUt7pZNpADe4LjvgAJbzetJoyUHFg9P	190	1	204	1	\N
5	191	218	1	52321366000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	191	226	1	5805000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
3	193	204	1	1852496000000	411	2n1PxfsrqQPsv2zyojtBBdt6yYWWJEQYPvKEhMo5tHEM1hJcqVsP	190	1	204	1	\N
5	193	218	1	53042111000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	193	226	1	5810000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	172	27	1	46208874000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
3	172	204	1	1873246000000	328	2n11jrGXxUjE9rrv5eesVMNQUVsydnU6McbmGxaXpsPncdj3gavf	190	1	204	1	\N
1	172	226	1	5706000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
3	174	204	1	1871996000000	333	2n11LLeSxdG8rsCao6PfJetc8m4e5jCeu6jWUKdR5xJTM5oedggD	190	1	204	1	\N
5	174	218	1	49431668000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	174	226	1	5708000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	175	27	1	46206876000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
3	175	204	1	1871996000000	333	2n11LLeSxdG8rsCao6PfJetc8m4e5jCeu6jWUKdR5xJTM5oedggD	190	1	204	1	\N
1	175	226	1	5708000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	176	27	1	46927123000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
3	176	204	1	1871746000000	334	2mzjSqaAZscMhpEsUYFyEGmwcYCkdzm1CBGTxvVLs45ugECjVias	190	1	204	1	\N
1	176	226	1	5711000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
3	178	204	1	1868246000000	348	2n2LHpJau5BTeQjwS5ftSLZgb7NHhaR1Ya5DMiyLhhJm6Kpvz22N	190	1	204	1	\N
5	178	218	1	49433904000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	178	226	1	5727000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
3	180	204	1	1867996000000	349	2mzafQZSFu3q8MFZBmYZUwJSP65rC1MFKW22MapS7oy2f7TwsSLs	190	1	204	1	\N
5	180	218	1	49430667000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	180	226	1	5730000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
3	182	204	1	1867496000000	351	2mzfJoWk1urkpewev8VBBUJHyTYN3gtG67ydFk7KFRKTtPZeagor	190	1	204	1	\N
5	182	218	1	50151163000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	182	226	1	5734000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	184	27	1	49092346000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
3	184	204	1	1862746000000	370	2mzhTKnbZW42XLk8EHBMvKjoNZdC6ALZpx8qWqGq8pVnnNGcgzYQ	190	1	204	1	\N
1	184	226	1	5757000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
3	186	204	1	1859496000000	383	2n11SEtKz2NXvsq4DncdVKZkiYTghsJYPdDFkiptW59N9Bj9nLeZ	190	1	204	1	\N
5	186	218	1	50875892000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	186	226	1	5774000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	188	27	1	50534583000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
3	188	204	1	1858746000000	386	2n1ifPuiZ1B5RFwoDadc8SGhwDYfz5qfhrb3y1ry796myus8AjC8	190	1	204	1	\N
1	188	226	1	5779000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
3	190	204	1	1857996000000	389	2mzeioQRB4JjxscMP4ykjssv88nj1Nh1gM26a9Rog4YnwxkxpRMx	190	1	204	1	\N
5	190	218	1	51596637000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	190	226	1	5784000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	192	27	1	51255328000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
3	192	204	1	1852496000000	411	2n1PxfsrqQPsv2zyojtBBdt6yYWWJEQYPvKEhMo5tHEM1hJcqVsP	190	1	204	1	\N
1	192	226	1	5810000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	194	27	1	51976073000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
3	194	204	1	1851746000000	414	2n1Jxzi4TK2VExcR3MxwuJZQZCmb125kLkyTajAUwjBqpadq1qht	190	1	204	1	\N
1	194	226	1	5815000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
3	195	204	1	1850496000000	419	2n19jyCsjVw6f26tZBmg9DqPYJNxKqLq2cC3MJ2LeZdLwayf3Wnb	190	1	204	1	\N
5	195	218	1	53042612000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	195	226	1	5819000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	196	27	1	52697319000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
3	196	204	1	1850496000000	419	2n19jyCsjVw6f26tZBmg9DqPYJNxKqLq2cC3MJ2LeZdLwayf3Wnb	190	1	204	1	\N
1	196	226	1	5819000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
3	197	204	1	1849496000000	423	2n163pBm9qgA741uuXWTDq2whEtoPYqDdZdgAqbD4NMXWfkYSeBj	190	1	204	1	\N
5	197	218	1	53042363000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	197	226	1	5822000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	198	27	1	53418316000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
3	198	204	1	1849496000000	423	2n163pBm9qgA741uuXWTDq2whEtoPYqDdZdgAqbD4NMXWfkYSeBj	190	1	204	1	\N
1	198	226	1	5822000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	199	27	1	54138563000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
3	199	204	1	1849246000000	424	2mzeby2cGBGZsVMkMqvNPfnC7aJaJydNiPTeHKhfDA5AphXPJgi6	190	1	204	1	\N
1	199	226	1	5825000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
3	200	204	1	1848746000000	426	2n1UDMCHf9Ve2soerK5eS3QgPLvnGWMmH7q6cjWHn5KnuVCMh7UU	190	1	204	1	\N
5	200	218	1	53041862000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	200	226	1	5829000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	202	27	1	55579306000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
3	202	204	1	1848496000000	427	2mzeTQSonNqcYeobysnpMtZgHwiYFujDGRo9rFbvDg3D5ezHK9jt	190	1	204	1	\N
1	202	226	1	5832000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
3	204	204	1	1847246000000	432	2n2S9sjwWicT6t2U5TujrnX1LJrSv7MpaJKzqaZqzgGz3cxGXnbm	190	1	204	1	\N
5	204	218	1	53762856000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	204	226	1	5839000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
3	206	204	1	1846746000000	434	2n22zvAbKtaKCy7ts4NRvjYZTKMPeZAePnkWX2bv2aGgj8ii7L4F	190	1	204	1	\N
5	206	218	1	54483352000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	206	226	1	5843000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	208	27	1	55579306000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
3	208	204	1	1846496000000	435	2n181BhSYTW2hneen3c56utwwhZt737UXuGYiyLKyMVGpKjDnD9m	190	1	204	1	\N
1	208	226	1	5846000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	201	27	1	54859059000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
3	201	204	1	1848746000000	426	2n1UDMCHf9Ve2soerK5eS3QgPLvnGWMmH7q6cjWHn5KnuVCMh7UU	190	1	204	1	\N
1	201	226	1	5829000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
3	203	204	1	1848496000000	427	2mzeTQSonNqcYeobysnpMtZgHwiYFujDGRo9rFbvDg3D5ezHK9jt	190	1	204	1	\N
5	203	218	1	53041613000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	203	226	1	5832000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
7	205	27	1	55580302000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
3	205	204	1	1847246000000	432	2n2S9sjwWicT6t2U5TujrnX1LJrSv7MpaJKzqaZqzgGz3cxGXnbm	190	1	204	1	\N
1	205	226	1	5839000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
3	207	204	1	1846496000000	435	2n181BhSYTW2hneen3c56utwwhZt737UXuGYiyLKyMVGpKjDnD9m	190	1	204	1	\N
5	207	218	1	55203599000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	218	1	\N
1	207	226	1	5846000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	226	1	\N
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
5	3NKtmrTjvrsrFvn5oqEo8rTmERizvRJ8rgc84ibpKqc2yLyVrVDY	4	3NLqMciG5yuJi1d8TqRe6JKZTRLnbCvPRi2Ur2rcdJrxsGtBU8Rr	28	108	gc_oaxeQ5U5d0VW0oEvga9y1y0M07wbwKDvlYyECWww=	1	1	6	77	{4,1,7,7,7,7,7,7,7,7,7}	23166005000061388	jxQK8w3rdrXQmpBAqP81cth1LsQcz2YFFsYn2JPQdJQArtTgttx	5	8	8	1	\N	1708468929000	orphaned
1	3NL5Z5RR1SnPmbtqzGBA8qaRT6qbgaDW5t2ppx6Hrcs2vw3qspV2	\N	3NLAbGNyiw7uNC4c6ByC6HvDswaLswaEKYaqXjoDJeie4gpt4bTb	1	1	39cyg4ZmMtnb_aFUIerNAoAJV8qtkfOpq0zFzPspjgM=	1	1	2	77	{1,7,7,7,7,7,7,7,7,7,7}	23166005000061388	jwt7oozUdMiTd2ksapBTgkTzaAjbCkCmiztvoB43oepMw438qNq	1	0	0	1	\N	1708467489000	canonical
103	3NKeCaKdyYJR86vMTSuBE6VoMDf8sXgMkhq5oen1P7SbYaAWP2jr	102	3NKULg6fRnF2mrEfzhK3iiFwAiB7fq3fsmPEXPKEKCYxCi7XWu2S	168	167	wFwZrpcG5qB1KVtiju4a66yesH5qcubDTpfFb-bk_Q4=	1	1	104	77	{6,4,5,5,6,3,6,5,6,4,6}	23166005000061388	jwya4z1DG7iVGLMkeb5VwExsbrqKFu5uFhoyvHAcnkhBqbqSQ4U	78	111	111	1	\N	1708487469000	orphaned
107	3NLehyST2WYNNYRp5khDgLGHijhxAwaifX4zAi2thedYm6XvgqiV	106	3NL25Cap5umgDDVFffsMJ2wiMxcmMvmWgeHsmAG9rz7xQCwNWD1t	168	167	Xy7hHm-1jtPOK-AXz3tDHkB2oTEaF7_ZAusQmQ88PgU=	1	1	108	77	{6,4,5,5,6,3,6,5,6,4,6}	23166005000061388	jwNm3eGX2VXFe97ggQSBBWRkULwoLDn6qey67qM3DZdqvZ7RwME	81	115	115	1	\N	1708488189000	canonical
105	3NLHnGsen9XAWSp5CdQiYPwPWZySWyGuQ1UPwbTbcLKQUkAg2Cjw	104	3NKDipmjrwPdJ83zKjKF3tActw5w93sj4tKDNutGy5dopXG4efoa	168	167	Y9g5Lw8QdjKZ41TuIS23mrjuMYvG9xRiWe0dnIqWZAM=	1	1	106	77	{6,4,5,5,6,1,6,5,6,4,6}	23166005000061388	jwjy1JdGdq6r7PfR7vyjsM35nNu9QjqenBtLXkB3ttYwL6wFrkP	79	112	112	1	\N	1708487649000	canonical
169	3NKWaBouUxHh5gzZYwhQpZt5ozrqhhq74wHh8YyMyuLCB7jRssBn	168	3NLTSMbNTQ1pRSWk9NAwyLeeGxJy9Y9YWeN4jXFYiFYS1H3oF1oK	168	167	J-gHdXEVAAW89bHLwFrtGYwiILsGEG2aTJiVXWYeswM=	1	1	170	77	{5,7,5,2,6,5,5,6,3,5,5}	23166005000061388	jwMWrVJFL6MYJ4mCXehvKKXyt5cE6dG495dc1MozcD6SLud4PzZ	126	176	176	1	\N	1708499169000	canonical
167	3NKKxP9htp59qi7DFPrk1yXdeqjb4rwZ1rXmLEHGB9VR8kwRCEXk	165	3NLN5KGsN6EeQh3PwtxAngLPfiYaYTDRpxCeky15sedBYFXS9g2S	168	167	TEZZd-o9EQZfDNQ4m7e2YERFDnqP7ffPivHOyuTHMAY=	1	1	168	77	{5,7,5,5,6,5,5,6,3,5,5}	23166005000061388	jwtBiCZKMGSuYt6gezZH6223q3oQuuQ4cSXDD9qtLUk3MqK7s8Y	124	174	174	1	\N	1708498809000	canonical
165	3NLN5KGsN6EeQh3PwtxAngLPfiYaYTDRpxCeky15sedBYFXS9g2S	164	3NLMV8zkn7bYRzsRyvYGEDz8SmNQWFM9ew7WNFNFuTJwLBh9Wq9Y	28	108	hh4P-MVcBbnbwxtYi3ReHQ7-MySkZWyel-RPXngEfQY=	1	1	166	77	{5,7,4,5,6,5,5,6,3,5,5}	23166005000061388	jxmRMcLBjrproj1RwPxw9S2azSLVFKKpbSSg3z4LYhBWGr42Bqv	123	173	173	1	\N	1708498629000	canonical
161	3NKBcBUKLkjpDChp6YdrAfapHNJKJd3SwdnGYBCUKuTQt28qRjsf	160	3NLo54vkrXYBzRAv71bMYTzoresqf5KA3kJnGk4DVjjs8uwKp1wK	168	167	ajtr5FhWpmB0HW6Mika_yEP8GRxGBZwEF0Q5sRHzlA4=	1	1	162	77	{5,7,1,5,6,5,5,6,3,5,5}	23166005000061388	jw7Rp8r1VP51VCyrJoCZPe5mQi3mdy6ikutd7U7Q8kA9pQF3BSD	120	168	168	1	\N	1708497729000	canonical
159	3NKMRXmjdcVwGM3S5WSEbFqJ4ByLxBPRtyexSudBVcMTuZbTJVJs	157	3NLkwnDMz73b5Wz8sEDvKnW85n4aUkDNakzcNboQWxXVdgZgb7vV	168	167	PzvUOk6NYQph9uzEkGQHTHcFrRJvMJrRL23oHvDy3go=	1	1	160	77	{5,6,5,5,6,5,5,6,3,5,5}	23166005000061388	jxtYLSxtrUGwEfhd34a7tX2QAX9GHY2BpPV4Z9PYTrpVs4cvST9	118	166	166	1	\N	1708497369000	canonical
157	3NLkwnDMz73b5Wz8sEDvKnW85n4aUkDNakzcNboQWxXVdgZgb7vV	155	3NKj17RTcDNzH7ywCMu5TP3dM4Nx1H2JYLJCyAFyrAm7r9rZ8NU8	28	108	Uc1D0VTqyre9hgpFbEHWJIWg-2FvzYBAaGVdQQpqbgY=	1	1	158	77	{5,5,5,5,6,5,5,6,3,5,5}	23166005000061388	jy2o3mSsAu5xGF57WKmBshquUqYwcaGkxSB4GhGzo2SQihcsb1Z	117	165	165	1	\N	1708497189000	canonical
182	3NLMWTVt6Fw5xBDB8WTN8sX72ytPQtCwiSDSQgqsw8tGSGFSN2QP	180	3NKFSy3bp7PfVdDQxUJ7yFoTx8ukjuL7JjvA7axrrGxzKALQLSg1	168	167	ON9nY1EroH8JfdjgFn2Qh80jAUaMGSTB2dFUTMjH-w0=	1	1	183	77	{5,7,5,6,3,5,5,6,3,5,5}	23166005000061388	jxxDyaSqvBQgseAKR1SHQzvsyYeL6Nymgmy8fDzmf8GB3n3Qsf9	133	186	186	1	\N	1708500969000	orphaned
180	3NKFSy3bp7PfVdDQxUJ7yFoTx8ukjuL7JjvA7axrrGxzKALQLSg1	177	3NKCsGz4aapFxSANd8DRngkRaN2HptEmenrESiCWPczL33TENeDc	168	167	F6fb-5wdQGqxS8Fbw2NCtLkfCTlykTHqYTLZI9mi5gE=	1	1	181	77	{5,7,5,6,2,5,5,6,3,5,5}	23166005000061388	jwtMS3itmsqyChSS1FfV6iH8JbUS41GDKbMRwkaXXTDHVZ7vg1k	132	185	185	1	\N	1708500789000	canonical
6	3NLU5bow7DzUML7FpEqMu5qjW46d3bLuCZeBdZndAmaVWLwyfByp	4	3NLqMciG5yuJi1d8TqRe6JKZTRLnbCvPRi2Ur2rcdJrxsGtBU8Rr	168	167	Mpgk9OPWGeWOyuU7O7Ded1i_KNfV6wPQXrpa4NrzLgI=	1	1	7	77	{4,1,7,7,7,7,7,7,7,7,7}	23166005000061388	jxeEHrvZPcXQDHG2ud42fPqRVeyHuWwvM1ZeezptRZPtPS3nxVi	5	8	8	1	\N	1708468929000	canonical
10	3NL6XFrtsLovsnVvZ9DXCF4rMt1fzetbeMN1UzaQn2ck5uLMHipL	9	3NKM8xxfPnx92poaTSxaLjkGcdXHeYw4ef9wzRYo9vuBt9hewqh8	168	167	fTyDdUC9wuHxctGw0catJV7nlhjbM9WBLvWyIQOllAI=	1	1	11	77	{4,5,7,7,7,7,7,7,7,7,7}	23166005000061388	jxDi69CBKGdvZv9P46fcmGrm7rbqu3EwgBLGXjzLpx72AYC46qP	9	13	13	1	\N	1708469829000	orphaned
24	3NL8qmh4a4Gkf5ojEw6pBAu5ngCJJJpdCriKjFeFytPHA1SYAVBe	23	3NKukaVGJW89v4tDh9ZPD8hP2mcsLXNr165yN7t4mCrLUCjcUZFS	28	108	r9sXwcipK8Dfw2n-ZMRsuP4SaPDf-FDQs-6sVSVSqA4=	1	1	25	77	{4,5,4,6,3,7,7,7,7,7,7}	23166005000061388	jwSKUDkAfJMmphNkbgVkWERLJSv9Xr6ER7frhfome8bHo2QhsRp	22	34	34	1	\N	1708473609000	canonical
22	3NKVCp2QJ2Z8izhwP9RU81pbhWATm9RF5Q2Qg8nFM7UyA7DXKdQo	21	3NKn9cT9GsJHiwftF7v1ng2ZpCK8rsswbN1EXfZNuaz33VtjNFby	168	167	gUAAHaPp5nuZcS0R7EIal7zo5gTQOZ6aooX1ZedRLQ0=	1	1	23	77	{4,5,4,6,1,7,7,7,7,7,7}	23166005000061388	jxrgGixThPSQ8EGM17HMm2oGHJv4okEALq7XxdsTfeKQ139WWh4	20	29	29	1	\N	1708472709000	canonical
20	3NLMRezwnLdzy8oCYZmx2NMc55H7VAt8xLbSJeGpAjqom9JKxpQf	19	3NKpAtCdF2HcC4eZR6p71n1Z7LFy56kzgr5CfY9MmCLHhvds6t2w	168	167	QlaXW3HuQni9lJz-irzR-SOCOL3Duwect2jGrxOUsgQ=	1	1	21	77	{4,5,4,5,7,7,7,7,7,7,7}	23166005000061388	jx1aLG8VuXYSdu6yRcA4YyfJ3dytdjzrFp3gBjVJKmBqjmgtkfD	18	26	26	1	\N	1708472169000	canonical
18	3NLGorz75FdT92TsqRXuf2uiR9UJUmQuZhrrCZWyK74REvTVzq5u	17	3NLTuJ4Dgjwh5KZRN2WaW6hFCufFCQdX6bqy9AdeTuKggQTXkhFZ	28	108	usnQNxgnQiK2HSxDLSzaF21LPjk3R51PXRQr1bRXBgE=	1	1	19	77	{4,5,4,3,7,7,7,7,7,7,7}	23166005000061388	jxNRV9Xojkddj8jP75cyNGLZijNHe9YWpqMHG6iq3oDrqyyDV3E	16	23	23	1	\N	1708471629000	canonical
17	3NLTuJ4Dgjwh5KZRN2WaW6hFCufFCQdX6bqy9AdeTuKggQTXkhFZ	16	3NKQGgtugVERZZuDnqidQiNsz34KQiZ9f2hCAZPFoYKZaAfqmAPW	168	167	GdLl0476H4QHWNEWr9SsQDX9znDOWdxODClcNiVD9go=	1	1	18	77	{4,5,4,2,7,7,7,7,7,7,7}	23166005000061388	jxfmv6UAUtfLFSQWLcfQMvmUzqKL84kM2yChvHDnB1Ph271t6LT	15	22	22	1	\N	1708471449000	canonical
16	3NKQGgtugVERZZuDnqidQiNsz34KQiZ9f2hCAZPFoYKZaAfqmAPW	15	3NLbF1JVTuykjgTyixhWHLNXV23vbiqixCBibZDqTZcaoDEnSTrf	28	108	AhKQL3ZlRrjADGE4n3aUwo6Q-1CabOpK-RCnpWN55wY=	1	1	17	77	{4,5,4,1,7,7,7,7,7,7,7}	23166005000061388	jxMjWQpm8FD3kRuwHoFPSQ3QLuZp4W2gdCeKFs6PG4G8CrV54kM	14	21	21	1	\N	1708471269000	canonical
15	3NLbF1JVTuykjgTyixhWHLNXV23vbiqixCBibZDqTZcaoDEnSTrf	14	3NLZKAToehEDskTR4fGCSz59k7BycyX6aMUxC4on9PAfaM3HXPHP	28	108	Z_rzXk0ypB5FGWyv1Gut5Mu7UPzHmhUs3q4wWmwWtAg=	1	1	16	77	{4,5,4,7,7,7,7,7,7,7,7}	23166005000061388	jwX6vQA7YK6NcyexiVodJ7xbZmNbKhY72B4xmnSWMinL8RRYUXb	13	19	19	1	\N	1708470909000	canonical
14	3NLZKAToehEDskTR4fGCSz59k7BycyX6aMUxC4on9PAfaM3HXPHP	13	3NKhe3gKHoctj7pQGPekTVoDPETj8CZABzxK9SkPZrYX12nwiNqt	168	167	W-NOHe2cNbv0tp-gak27lDb6gNSfSojY1HQgsjfLcA4=	1	1	15	77	{4,5,3,7,7,7,7,7,7,7,7}	23166005000061388	jwhyjrHia5FUGWgqb94AwhA92kP2BZsMj9UyNiKdX2zCkjnqhzG	12	17	17	1	\N	1708470549000	canonical
13	3NKhe3gKHoctj7pQGPekTVoDPETj8CZABzxK9SkPZrYX12nwiNqt	12	3NKxQzTtASg5WycjhiwQQ8YmCYUrsLftdeWDBnVMf3Pe3SUUCppa	168	167	pPP-YOALGsTYMiqK7H-x7p26OZ-cHd26DuFMTPx0Jgw=	1	1	14	77	{4,5,2,7,7,7,7,7,7,7,7}	23166005000061388	jwaRbVWNvQ6MbnPhuKaDTk9Pxab3wAXjNZKiRwNneavNgEibwp1	11	16	16	1	\N	1708470369000	canonical
12	3NKxQzTtASg5WycjhiwQQ8YmCYUrsLftdeWDBnVMf3Pe3SUUCppa	11	3NKUQGtHKGohMcYBoLAqQ9vFGWx46pYXUwRqhuUsqRXN4b8vCZ5v	168	167	ohTJ6xJViZx_mK-vdtydi_p03ZULhTAcNLzLyvDQ6g4=	1	1	13	77	{4,5,1,7,7,7,7,7,7,7,7}	23166005000061388	jwzE8ZkYh2uTQFdaozFqQjGpjhPpX7hoS1a2kkC47iXubSrysSQ	10	15	15	1	\N	1708470189000	canonical
11	3NKUQGtHKGohMcYBoLAqQ9vFGWx46pYXUwRqhuUsqRXN4b8vCZ5v	9	3NKM8xxfPnx92poaTSxaLjkGcdXHeYw4ef9wzRYo9vuBt9hewqh8	28	108	jp5blVydUEKUxFnUKfE1toeEoHoMiZ21UvPFcJy8Jg8=	1	1	12	77	{4,5,7,7,7,7,7,7,7,7,7}	23166005000061388	jwBRsNNVzVZJCNYYkc5JX7bvHcUHmMjr8Fj2iBhpComKKMzdaEj	9	13	13	1	\N	1708469829000	canonical
9	3NKM8xxfPnx92poaTSxaLjkGcdXHeYw4ef9wzRYo9vuBt9hewqh8	8	3NKkuRbc1fLDkn841fE6dHxP1ctf6PdT5R1JK6TEVQ8WjcrQ8bKX	28	108	PvdDu7bj-dU2HayfPcEp1ziWC5adXMcN5-6oXw7aEwc=	1	1	10	77	{4,4,7,7,7,7,7,7,7,7,7}	23166005000061388	jxwrLQBZbG4zBLUm4HQQCj6TseUxQAoiY2KY29JpRdvWxEdnxNP	8	11	11	1	\N	1708469469000	canonical
8	3NKkuRbc1fLDkn841fE6dHxP1ctf6PdT5R1JK6TEVQ8WjcrQ8bKX	7	3NKKiN321BqN9jw1XJXECSKZBocWsFpreGZso5TnugGA5PDMZ4T4	28	108	QZUG_5gD8LK_gqFI_p7R6a_-goK5aZdrD-oGmOJIcA8=	1	1	9	77	{4,3,7,7,7,7,7,7,7,7,7}	23166005000061388	jwijbhzpuZ893XRafouVxKt93jdERxb4RdaXcm3j2a3psabT4ae	7	10	10	1	\N	1708469289000	canonical
7	3NKKiN321BqN9jw1XJXECSKZBocWsFpreGZso5TnugGA5PDMZ4T4	6	3NLU5bow7DzUML7FpEqMu5qjW46d3bLuCZeBdZndAmaVWLwyfByp	28	108	yxxvzhdaOEwKUgGH3GTe5VxiGmk4H2pgGi8RisePZwk=	1	1	8	77	{4,2,7,7,7,7,7,7,7,7,7}	23166005000061388	jwnKGmd2UpQ7crQHyww22qJyb94DzjSQ83gKkstnsDk6GTPp5ZL	6	9	9	1	\N	1708469109000	canonical
4	3NLqMciG5yuJi1d8TqRe6JKZTRLnbCvPRi2Ur2rcdJrxsGtBU8Rr	3	3NL5Nn1EY1NBBQMqGTavr4ZE91eDXMJd4Mtxaz2EJUKc1uG2YTPH	168	167	_eXxVH4puSdYbzyftTI3c8zTpOrwp3drNrJjuYbAmwU=	1	1	5	77	{4,7,7,7,7,7,7,7,7,7,7}	23166005000061388	jx1V3fJD3fzTCeR55yfXnm6wy4t9GZQ9Rfz5Z9K4nFrxzLfkm77	4	6	6	1	\N	1708468569000	canonical
32	3NLGJg44R8zn1NXVkGjk7RXwTRyt9E9w681MpDKe5R6ASJc6GHPq	30	3NKxD7GMAhmfpZXXkcvmzJW7KUbZXqpzm8sZLvbcPAdtHb9UxaLg	168	167	MHGY43irl8HfyjZDTf6XvGA9u8GC8HOrSgA5KTEANAg=	1	1	33	77	{4,5,4,6,3,3,2,7,7,7,7}	23166005000061388	jw8AfhkkAoeqsTKriJkBS1NnhphjZFWGMBCxz9o5ep3YkfQMnNW	27	44	44	1	\N	1708475409000	orphaned
40	3NKtjnAG4xBs1wjtMDekQEhGzFXaoaowdZjbrYtvbMawcFSt6epV	39	3NKtryhJQGzZF9bfuLwwDr6BzA4smmggMFYoKX56ESM69kFZnfDy	28	108	QJHfPziHiDfiDFButruYzbRLxluAT2lYhlUsKnODxAg=	1	1	41	77	{4,5,4,6,3,3,6,4,7,7,7}	23166005000061388	jxd4TbXnBp26kQaoSSqipK38Qjk6G8B5C7xyzQhj3t79jBmcJu2	35	54	54	1	\N	1708477209000	orphaned
44	3NK4mPrNRJF81bBhZKPSiMfei8k5VqNrm1rPT4BbJyZFQGRAA911	42	3NKbfGvj4DiCq3tUZUKKvgwY8s3v4fNGA3cMEfxCe8FZn9rG7zRC	168	167	G28l3l513IXw0xMIoUHttWV98tQcLBretGToUIZu8QQ=	1	1	45	77	{4,5,4,6,3,3,6,5,1,7,7}	23166005000061388	jwmg98CG13XwWyvj4r3YwrBjXTYQk2xuqDvdXx1zwwdat1siDS5	37	57	57	1	\N	1708477749000	orphaned
51	3NKyKwBhCS86ZMdBawyaDvmthWjbGj9NHVnSufs32dcfE2qtVxse	49	3NLWUzjs1xXPyZkoojpH9Xpzd9oWrvdjscELPQxNG9fS9gfzB29S	28	108	pgykF12FM2jBnVcO26UQltJlGWnOKaeGJO06dUSLRwc=	1	1	52	77	{4,5,4,6,3,3,6,5,6,7,7}	23166005000061388	jxRxrqZEWrAmFi9ggK3NxbqageeyAaytfwDDSXvVgXo8J95jAF4	42	62	62	1	\N	1708478649000	orphaned
25	3NLHp4DMNTytsndmfBE63TENmCe4DQyXKKj3SkHB5ijfWfFgG9Jk	24	3NL8qmh4a4Gkf5ojEw6pBAu5ngCJJJpdCriKjFeFytPHA1SYAVBe	168	167	nB79DkG5dgycjwXhe9Xsdl09lesRSH-05moDolYTfQY=	1	1	26	77	{4,5,4,6,3,1,7,7,7,7,7}	23166005000061388	jx2pDPQXcrtenbNvpAPvgqnAeJgiz4wmvG1FrB29xUFaDFrfYm4	23	36	36	1	\N	1708473969000	orphaned
48	3NK7pguxD4nfwcJwkNs1eCY9in4foFfsn47jtG2AF7gBTLdGeg4e	46	3NKmieZd7bhq4pHCUXHDFtpdHSAQm27o4K6E3Hy6TKKNX5SFusAT	168	167	N9VcymOV1VIKHoJnj6vE7QmTwh2DoPJcUq3H5hJ8KgA=	1	1	49	77	{4,5,4,6,3,3,6,5,4,7,7}	23166005000061388	jxSqZpAvJYn3BfWBD7KxjC4Ej11Mfaid3QLPTB4BZJyJdnhNmvt	40	60	60	1	\N	1708478289000	canonical
46	3NKmieZd7bhq4pHCUXHDFtpdHSAQm27o4K6E3Hy6TKKNX5SFusAT	45	3NKoLFf4o2FAUZESzoEW1PQzX723MsTH82wXN6eXsN3QQPv7H2PC	168	167	4SOECaJjoZU2ht1eG0gziQzJucMKKmJKm7S0QfuJGwI=	1	1	47	77	{4,5,4,6,3,3,6,5,3,7,7}	23166005000061388	jxZSzFiG7VFvu5ZpYELfDEbu1Aqjx8ijrAJEziyvMN4ECzjdEH8	39	59	59	1	\N	1708478109000	canonical
42	3NKbfGvj4DiCq3tUZUKKvgwY8s3v4fNGA3cMEfxCe8FZn9rG7zRC	41	3NLXospP1cWYfyShDdenwfKSWpZLehHrcswaVP3q9sAURoMrXtYz	168	167	QAryidW4w-rTz__5crfS3AxZxDs7vAzLeTpJyq0RYA8=	1	1	43	77	{4,5,4,6,3,3,6,5,7,7,7}	23166005000061388	jwYSm8oop9renPKPtojgTaE1pP8cmMUwsUTj1WGnR3w3TaLThpa	36	55	55	1	\N	1708477389000	canonical
38	3NL5acvCtK1UjwkLsLZqefCSzuGzi3i4NbSmzELciDvx6wVxRQt6	37	3NKkaLEJqBDN7CzYLVQhn3bnvA559VyQrGLYrgTeYSD6gunVKdfs	28	108	hh-oIkgxu00tNneNzOkfs6PXrGcXHXP72pK7kEActws=	1	1	39	77	{4,5,4,6,3,3,6,2,7,7,7}	23166005000061388	jwEgAAqPj7B5VNC4qfNt8aCTDtFFWDPQ3ddEBJXsrP1zTYgqjhr	33	51	51	1	\N	1708476669000	canonical
36	3NKHZLmJ3Nh5vYa9tk9Tbh7P4sxmAL5KWS8BcjuqscPSTh2DfXMP	35	3NLstYfLr6MJwFAGvYR2kFpAxUMBeTp2S3aSpWNDxoWoamqqDneb	28	108	him0AWazQ6yWqBfHzKrtFE39SstWqANOkPDHLRdlLAw=	1	1	37	77	{4,5,4,6,3,3,6,7,7,7,7}	23166005000061388	jxXLk1nXEu4GCgaCZyntupsUF319qEzi8CUmbvcumBcRUNrYKHt	31	48	48	1	\N	1708476129000	canonical
34	3NKsC9gEvPiAQdnUfMCBp1ymCLom2Jq19x6VDxC6hsriWCsSKbnB	33	3NKTZqfpteXNtUJmoabCoNH6fNFgNhx76jxv89Hpf4eypUhix58Q	28	108	z41DOE8QuZ3OZa-O9SiHr0O6MxR83G-8fDWxvfWT-gI=	1	1	35	77	{4,5,4,6,3,3,4,7,7,7,7}	23166005000061388	jxWt9c8Gx18tnqZ9ET1SiQjseWNijkcVnhwTX3Da9FXQjJxxXau	29	46	46	1	\N	1708475769000	canonical
30	3NKxD7GMAhmfpZXXkcvmzJW7KUbZXqpzm8sZLvbcPAdtHb9UxaLg	29	3NK7ANge6i3CWBXPzFZ8QWUHkH5b2wAsXMBMgHR55UWZin1HPwqT	28	108	Zz-7lzS5SD9-zwoTID-wG1ZUVciQDXOna1mrXPWepgA=	1	1	31	77	{4,5,4,6,3,3,1,7,7,7,7}	23166005000061388	jwJjwXR3ZBLRAn3wtmRio2W3yj5UY2F9ADL7WDfagX1Xu8MNUeV	26	43	43	1	\N	1708475229000	canonical
26	3NKDBhDWYoFoA2saZqhWu5sJ9W5GWjy597bMFPRF619XB8f5Mern	24	3NL8qmh4a4Gkf5ojEw6pBAu5ngCJJJpdCriKjFeFytPHA1SYAVBe	28	108	PIQzU_65AIQ_Xoxk9WwjLX9FT6siy2Y5pDdzrFLX7AM=	1	1	27	77	{4,5,4,6,3,1,7,7,7,7,7}	23166005000061388	jwMu4YgvJ3XwP5R954TQsWegCbXygX9zRnvU6CGDrcGgAKtx3P3	23	36	36	1	\N	1708473969000	canonical
23	3NKukaVGJW89v4tDh9ZPD8hP2mcsLXNr165yN7t4mCrLUCjcUZFS	22	3NKVCp2QJ2Z8izhwP9RU81pbhWATm9RF5Q2Qg8nFM7UyA7DXKdQo	28	108	KF3n2841AwXkJx798YRKvdEI05j5afneVMuP60DN1g4=	1	1	24	77	{4,5,4,6,2,7,7,7,7,7,7}	23166005000061388	jxa66wWEWMk42kV3ezypZPhZVSTQRVEvfbGFk5YJ4GMkwR8jvT3	21	31	31	1	\N	1708473069000	canonical
21	3NKn9cT9GsJHiwftF7v1ng2ZpCK8rsswbN1EXfZNuaz33VtjNFby	20	3NLMRezwnLdzy8oCYZmx2NMc55H7VAt8xLbSJeGpAjqom9JKxpQf	168	167	X4LGpSCJYq-hiaYnqRnbYaCYNrL8ZL5a--z82I0sAg4=	1	1	22	77	{4,5,4,6,7,7,7,7,7,7,7}	23166005000061388	jwfPBUqyGbM7dau8EQcbBCeiN7P9996HkbWK66us686pww18K7B	19	27	27	1	\N	1708472349000	canonical
19	3NKpAtCdF2HcC4eZR6p71n1Z7LFy56kzgr5CfY9MmCLHhvds6t2w	18	3NLGorz75FdT92TsqRXuf2uiR9UJUmQuZhrrCZWyK74REvTVzq5u	28	108	V7CXawKaE0u5incdYOgnargPTYw4Tdz1G-et8vDlQQA=	1	1	20	77	{4,5,4,4,7,7,7,7,7,7,7}	23166005000061388	jwiccMkVFTAspKdAVSNoPz58UtAUGNEbNLGeTYMA1CgemQEhF4M	17	24	24	1	\N	1708471809000	canonical
27	3NKXUFh2mVuV6JGpduS8tdzXiMt8Megyox8T2zJbTtfzHHDbhj4K	26	3NKDBhDWYoFoA2saZqhWu5sJ9W5GWjy597bMFPRF619XB8f5Mern	168	167	-PHIuWDfm_gcztYnFkYZ8oTTFNftdb_iCb0zghDRBw8=	1	1	28	77	{4,5,4,6,3,2,7,7,7,7,7}	23166005000061388	jx3WrkAbJdZcDEAbbo7VSuFe9yPoYBXGzYucEKk8bwTNafqxhSE	24	39	39	1	\N	1708474509000	orphaned
47	3NLd6FemRLoogGwmxcW1KMLKra4596jyBu2zsbSCshM61vzyYctz	46	3NKmieZd7bhq4pHCUXHDFtpdHSAQm27o4K6E3Hy6TKKNX5SFusAT	28	108	-bmMFEZtrDbYjrPQgQaHXFdf8x6soGWei3jOl8TC7A0=	1	1	48	77	{4,5,4,6,3,3,6,5,4,7,7}	23166005000061388	jwqP58KWJTQjvyDSmU2TpfYWx8ZUdXKwUbH7tvYGdB8zonXgr6t	40	60	60	1	\N	1708478289000	orphaned
53	3NLpZvp2qvbqL4GnVGGqr36dT7MRRXY83j3GzSGQynaZWjPnrbcP	50	3NKPhFdBvC9gqNEYnwRqBPDVqe6646Cggecrw7tgwX8XQNKeZ6WN	28	108	uaZ2M2Al-3G3ya_7pKO-mTYxvAYc7apIdAb2tbnmfgI=	1	1	54	77	{4,5,4,6,3,3,6,5,6,1,7}	23166005000061388	jwH3NQaPhZQK5t6HSYU6S6cJLFAKJPkp4TY5aKcAdjKNXyvjao4	43	63	63	1	\N	1708478829000	orphaned
55	3NLiyNzr1spxaBqLZoHHVoGSzjdpQMF7LJ2LtFsK2Mwo9vgTRaGX	52	3NKnCejm5DawMBoFdFcz6wesH9xhzu1Pp1YmqSYL8ffMgnoxvpqE	168	167	duPvkcbrM5ZHZjqG1kcouU3tNS0Ndi7FBTpDQt8yrAY=	1	1	56	77	{4,5,4,6,3,3,6,5,6,2,7}	23166005000061388	jwQUyaJ6u7CnnbM5Gbgjd9Y23tpx1UxvXKPzA7APbe5ZTNcfjs6	44	64	64	1	\N	1708479009000	orphaned
54	3NKyp2LGYJkGaPKsHaPtsQenAydTv6AzuTVC2Hi5SA9RxV6z3Q2L	52	3NKnCejm5DawMBoFdFcz6wesH9xhzu1Pp1YmqSYL8ffMgnoxvpqE	28	108	kweyeUZSFNTLOKLQwP0Xn6O2unUuGGtt09ewExEQnQE=	1	1	55	77	{4,5,4,6,3,3,6,5,6,2,7}	23166005000061388	jwtjodyh4nytcCpws8LctwGXxx7nhAtY1tfSRarPuF219TRnyjr	44	64	64	1	\N	1708479009000	canonical
52	3NKnCejm5DawMBoFdFcz6wesH9xhzu1Pp1YmqSYL8ffMgnoxvpqE	50	3NKPhFdBvC9gqNEYnwRqBPDVqe6646Cggecrw7tgwX8XQNKeZ6WN	168	167	Hmh787qVrFTcvcaEWybdPyrisM-b0p37kGxcUxkx2Qs=	1	1	53	77	{4,5,4,6,3,3,6,5,6,1,7}	23166005000061388	jxzFjxpaqesoMFQPyTCn2LeJPTVUDxKBoWYe7txWAKEjYKr6Njd	43	63	63	1	\N	1708478829000	canonical
49	3NLWUzjs1xXPyZkoojpH9Xpzd9oWrvdjscELPQxNG9fS9gfzB29S	48	3NK7pguxD4nfwcJwkNs1eCY9in4foFfsn47jtG2AF7gBTLdGeg4e	28	108	WNOTRWMJLc6r1Mb8RVsqRXiSku2p3maKb7chrTnAUAY=	1	1	50	77	{4,5,4,6,3,3,6,5,5,7,7}	23166005000061388	jx2J667tCXzUEsM1uoytJC7xkoQmFc5XoGJ2L3UtxDXWKz9aoeo	41	61	61	1	\N	1708478469000	canonical
45	3NKoLFf4o2FAUZESzoEW1PQzX723MsTH82wXN6eXsN3QQPv7H2PC	43	3NKgKaSMoG4JHgEM4qdmTyTtgJZ3o2uKdvMh81EKFwNaPpitP7sr	28	108	Kv_aS-boFV9vq424QAMJsrOcANfKmlhtb4RMTaPqkgM=	1	1	46	77	{4,5,4,6,3,3,6,5,2,7,7}	23166005000061388	jxXiMPJ9Q9YnmSD6jpHMcApBRuMm6u4GfXwyZvBLpyoYQR18sU7	38	58	58	1	\N	1708477929000	canonical
43	3NKgKaSMoG4JHgEM4qdmTyTtgJZ3o2uKdvMh81EKFwNaPpitP7sr	42	3NKbfGvj4DiCq3tUZUKKvgwY8s3v4fNGA3cMEfxCe8FZn9rG7zRC	28	108	s8cktm6tlPIuV0fpLUixPIEPWXAG8Lu6kZsYb6Rb3Ag=	1	1	44	77	{4,5,4,6,3,3,6,5,1,7,7}	23166005000061388	jxEZz71vovMnacB6YmoPG2NziSgAChujcSCmJSNk7cZj6p2wzqt	37	57	57	1	\N	1708477749000	canonical
41	3NLXospP1cWYfyShDdenwfKSWpZLehHrcswaVP3q9sAURoMrXtYz	39	3NKtryhJQGzZF9bfuLwwDr6BzA4smmggMFYoKX56ESM69kFZnfDy	168	167	_CDVEOrHOJFuRuY3hM0p2fla8eTFdmtYxCxIAcMbTg4=	1	1	42	77	{4,5,4,6,3,3,6,4,7,7,7}	23166005000061388	jwuyeFrEBScu2CVbkaDGPyh6deDMDKLwm2vWxVLx8QLs86qg7sJ	35	54	54	1	\N	1708477209000	canonical
39	3NKtryhJQGzZF9bfuLwwDr6BzA4smmggMFYoKX56ESM69kFZnfDy	38	3NL5acvCtK1UjwkLsLZqefCSzuGzi3i4NbSmzELciDvx6wVxRQt6	168	167	J21A-bkjDJitwOz5Fp8S1dPkOTBOKbIVqlSmgmXpHQU=	1	1	40	77	{4,5,4,6,3,3,6,3,7,7,7}	23166005000061388	jx3BMBQjaP9i1xB8Tc4A35JYjHHsbh6kT9PMd42Wk53HfQrPTBV	34	53	53	1	\N	1708477029000	canonical
37	3NKkaLEJqBDN7CzYLVQhn3bnvA559VyQrGLYrgTeYSD6gunVKdfs	36	3NKHZLmJ3Nh5vYa9tk9Tbh7P4sxmAL5KWS8BcjuqscPSTh2DfXMP	28	108	DACsgoW66twreizQH-TQl98SlLC7nWAgwcrHj001HwE=	1	1	38	77	{4,5,4,6,3,3,6,1,7,7,7}	23166005000061388	jwnE4SAYzp4ctPMAJWjkN1qVH8NL1DPntLRK2omS1wYyvfKvUyY	32	49	49	1	\N	1708476309000	canonical
35	3NLstYfLr6MJwFAGvYR2kFpAxUMBeTp2S3aSpWNDxoWoamqqDneb	34	3NKsC9gEvPiAQdnUfMCBp1ymCLom2Jq19x6VDxC6hsriWCsSKbnB	28	108	xpfsCoaG3TRIhsHorWbQInTYs5nGgk2xj8tdMaSrRg4=	1	1	36	77	{4,5,4,6,3,3,5,7,7,7,7}	23166005000061388	jxn8tqmf4D3ieHCVqq68rS1aS6zmTGfSfcV14ZBu77hTUCHysEz	30	47	47	1	\N	1708475949000	canonical
33	3NKTZqfpteXNtUJmoabCoNH6fNFgNhx76jxv89Hpf4eypUhix58Q	31	3NK2xKd9VysG2XEFFagegNFcb4cPKjwMYDq513uCNzapW1q5C2yN	168	167	cPinGkyFlMAV2ynK_IqALvTMc_YBNRyJkNbxjBSasQY=	1	1	34	77	{4,5,4,6,3,3,3,7,7,7,7}	23166005000061388	jxrLAvKSqUxidGt5GEvZQVmoceH3CX7LvG3kDqFUbPfNnyo2cc1	28	45	45	1	\N	1708475589000	canonical
31	3NK2xKd9VysG2XEFFagegNFcb4cPKjwMYDq513uCNzapW1q5C2yN	30	3NKxD7GMAhmfpZXXkcvmzJW7KUbZXqpzm8sZLvbcPAdtHb9UxaLg	28	108	Mk4TfzvFznT6i7bymTDhMxHqpGKjvKDxVTskDjAV9Qo=	1	1	32	77	{4,5,4,6,3,3,2,7,7,7,7}	23166005000061388	jxwvTR7zX9LPktDuvfQH2VThNonMKUdNtAFhp67ZtBbXjt1GXzA	27	44	44	1	\N	1708475409000	canonical
29	3NK7ANge6i3CWBXPzFZ8QWUHkH5b2wAsXMBMgHR55UWZin1HPwqT	28	3NK9seE5QLxAovFVmdNzmg5yr7UneQvJRf3tr1tZdjK392Ha9Vhx	28	108	Gv64YnwLGYDYw0xII223WLi8zMYYvHVEbNcd54HI9g0=	1	1	30	77	{4,5,4,6,3,3,7,7,7,7,7}	23166005000061388	jxmS2aUoqmoqygBRzcAR1S9sfbQMKcRsauGNs8A42yAhHTiSoHn	25	40	40	1	\N	1708474689000	canonical
60	3NL44322EQgfPEhLdo7NaZ1mc1YFf5nDdho3cDNFTyWnpGtXQjBw	58	3NLRpChaguWMsaAp5Y6cE82s3amMMP9rM8vZF5YnZ6MVWPC5Lfr5	168	167	gaw01oj9DaCeHAn3YUY9wFrM-B3vXHaVT6haGw_p2Qc=	1	1	61	77	{4,5,4,6,3,3,6,5,6,4,2}	23166005000061388	jxz2WuEBiRUxUSJzumE6PZL4apB3G9fUSUUtF8ya6CQoTe1ozE9	48	71	71	1	\N	1708480269000	orphaned
62	3NKteaCQVxMQ1ZiGYpuTddLwp7JrF4Mg1kvZYDnhwZPBLCvZJQSq	59	3NLv1x6e5VbXFxtYW3G69Tf2SmkrydV4QUqStJKFZySDbsVA5JkN	28	108	4eXw9KExASfuT5bHebicGKX7gDEIiuWzz0bqOHWjOAw=	1	1	63	77	{4,5,4,6,3,3,6,5,6,4,3}	23166005000061388	jx55RPEC1NxfqLrRqJahEm1FbSZ1EMPHNSkey3pUWFV5DeEXpDB	49	72	72	1	\N	1708480449000	orphaned
66	3NKBr3hKrjPNqzNmKFo6YFzhXuUZYpT6pCa4911buhqoj3JkyRjf	65	3NLCXe3PNnpPyRwzTFGi9tusfkJnLafcaMytNiRAKjwRNLf4R59M	28	108	XEHZhtOfo3WUcnznvHup43gNesnoAbpAabt5Rd7ZzAE=	1	1	67	77	{1,5,4,6,3,3,6,5,6,4,6}	23166005000061388	jwmjyw6mVJQ1czzWVJUWmNaxHim1UAf4tYPwrpjbjkFS4QT9P4Z	53	77	77	1	\N	1708481349000	orphaned
73	3NKN1fPaD3TQKBaM4FyPEX7SSjJPBVf55gQqw7ofbfsMsuSuHkeu	70	3NKF8z2sHbf5XsLy4ZuUr2RztYSj832j8ujiDGDGms6WvRfmFsQ7	28	108	TSQTPotaaYLI1L1rob-EBKqYrYLflmX9CLjj6c9CmQI=	1	1	74	77	{5,5,4,6,3,3,6,5,6,4,6}	23166005000061388	jwrmnvwinu2Fj94gV6ELkk7GS7D99nbTiod6nLwD5NmqHwYBhAW	57	82	82	1	\N	1708482249000	orphaned
77	3NLL3u5k46S3qdNjWBqp7LuG39yhtv9rbyt4DJ8i2oFMfxKRZaqW	76	3NKS7h4MJrPuVYR4YgjHbXg3AfCffmEVjKWzEVzmrYHbXow4M1Am	168	167	4bpHH4IYKhOrkziDV8uA4SPSLpOddvq2pI3g5nRErws=	1	1	78	77	{6,2,4,6,3,3,6,5,6,4,6}	23166005000061388	jwqrBDTHDHNjgiYwndoNNjJGnYcRuMZp5jSRivT6zUdDgaGXkVK	60	87	87	1	\N	1708483149000	canonical
75	3NKqfPmV19F4nvQ6DX86e3QTyvfP5ikhe4q53ngg176i7qtHAnVm	72	3NLijKePFfuaLQFsoiUzVftuQnksPFEUS8zfPFKCTRsehLCAuaxH	28	108	CA1jPrPKkHX40d_voWr9iKVluRCtn_4UsQQrTOdARwI=	1	1	76	77	{6,5,4,6,3,3,6,5,6,4,6}	23166005000061388	jwNYXwjeZAjMThWqkFBm3XKbAy9po6MMV7GqXDdLHu2MUf6y4YX	58	83	83	1	\N	1708482429000	canonical
69	3NLN5M462h7MFe6mgdz9qpEkHbdvRR8L5qY3hg8NSBbq93hrbafd	68	3NLuzcgds4Lu3w33kqwYaA3KjJM6rtEjTAYABo8QEBRkWLWWPvEY	168	167	wO9FwDDIilvNsYHvoHrmObgadWrsOFRETdBjP4aBrwI=	1	1	70	77	{3,5,4,6,3,3,6,5,6,4,6}	23166005000061388	jxSDKwbojKqtVuoQVx75ME8zuxmtLirGqhTWWoxfQGNszHQcybk	55	79	79	1	\N	1708481709000	canonical
68	3NLuzcgds4Lu3w33kqwYaA3KjJM6rtEjTAYABo8QEBRkWLWWPvEY	67	3NLXLGm3TCQMJimxSbcZ5E6xjgEZNkjZWAdRRuaJshqqmFwCfxHp	28	108	gnGfPyikinehtwAGxPLt0AsL5LNoti4qWNvEdcVnLAI=	1	1	69	77	{2,5,4,6,3,3,6,5,6,4,6}	23166005000061388	jxSqhoEtkFYnikW4CgmLAqfFgoMQ52w1DrwD3vMrCkod8xs8fNP	54	78	78	1	\N	1708481529000	canonical
67	3NLXLGm3TCQMJimxSbcZ5E6xjgEZNkjZWAdRRuaJshqqmFwCfxHp	65	3NLCXe3PNnpPyRwzTFGi9tusfkJnLafcaMytNiRAKjwRNLf4R59M	168	167	APXgJQLJlAczPQ7jf65dhOjNB9JGd8c52ccUEyk09wQ=	1	1	68	77	{1,5,4,6,3,3,6,5,6,4,6}	23166005000061388	jwUvmQv6SpDJC4d7SoYVmBYyYmvxhVGthvVzsTDLYKr25fuzZMz	53	77	77	1	\N	1708481349000	canonical
65	3NLCXe3PNnpPyRwzTFGi9tusfkJnLafcaMytNiRAKjwRNLf4R59M	64	3NKahh5Ca46xWfB59Van5y5btkuPQn5WuSxNpeXgvLuLv8k2KxZY	168	167	XOvUxWnJ_Qx9YhKJsiIboka44_4ecadkTPei6e1m_QE=	1	1	66	77	{4,5,4,6,3,3,6,5,6,4,6}	23166005000061388	jwAofsMuvXtmtqfrterjeBsFQuNgAdtqUHnXQELd6F8jGQU8Zoe	52	75	75	1	\N	1708480989000	canonical
64	3NKahh5Ca46xWfB59Van5y5btkuPQn5WuSxNpeXgvLuLv8k2KxZY	63	3NLfvcJ5qhz2vbJ4go6uZbEmfR4KiBePs9Cb2PThwsCFuUCRMZ3k	168	167	2BH8rzC8PQl8XfCxiR-REvSyXWXbTpliQO1L-6Ritgk=	1	1	65	77	{4,5,4,6,3,3,6,5,6,4,5}	23166005000061388	jxk5SHErFtsNonHMNmSwJMVjLLVKJk2syf817cUTnXmAS62Bqpc	51	74	74	1	\N	1708480809000	canonical
63	3NLfvcJ5qhz2vbJ4go6uZbEmfR4KiBePs9Cb2PThwsCFuUCRMZ3k	61	3NLYiggWGHz6WDiy2XqFcDms6A1rUn5RYvNVUUGh25rn3chUAhLs	28	108	1j-0TMEEFfx5QE25PxyzHqKfQC0KhTkY1fmRo6mRUwU=	1	1	64	77	{4,5,4,6,3,3,6,5,6,4,4}	23166005000061388	jwZpbuNs9p9HdFSHhKRw2cDbi1w43oCcnbZiohLHPmFfmPUoT49	50	73	73	1	\N	1708480629000	canonical
61	3NLYiggWGHz6WDiy2XqFcDms6A1rUn5RYvNVUUGh25rn3chUAhLs	59	3NLv1x6e5VbXFxtYW3G69Tf2SmkrydV4QUqStJKFZySDbsVA5JkN	168	167	UQyMyWBKZg3r40mauWoqXFiax9JKMRpyD_wYPCw4CgQ=	1	1	62	77	{4,5,4,6,3,3,6,5,6,4,3}	23166005000061388	jxk23nD5VgWThMbinL8zS5o1XTaxmNpmgHUCH8d72LJsPCXXFew	49	72	72	1	\N	1708480449000	canonical
59	3NLv1x6e5VbXFxtYW3G69Tf2SmkrydV4QUqStJKFZySDbsVA5JkN	58	3NLRpChaguWMsaAp5Y6cE82s3amMMP9rM8vZF5YnZ6MVWPC5Lfr5	28	108	_BoJCao9AzosyK3qRHJcW7PGvXCNaDv73adWHs-HdAs=	1	1	60	77	{4,5,4,6,3,3,6,5,6,4,2}	23166005000061388	jxYu6UmDAwer8ExNEtPER7mrJYkmi78JX5sqwJ6VvkPz8ydeqvj	48	71	71	1	\N	1708480269000	canonical
58	3NLRpChaguWMsaAp5Y6cE82s3amMMP9rM8vZF5YnZ6MVWPC5Lfr5	57	3NLGJ3jeuJW8pRDkvFwXgkUz44mXdjqr5d49PB3WNG2sNiR3Who8	28	108	R7AxZxo4QkV7hSzHM1WXXUjEEhPFsV-XkX4JpG7JcA0=	1	1	59	77	{4,5,4,6,3,3,6,5,6,4,1}	23166005000061388	jxyNn8Ct7F8iGnrDNn3wkyFmS7M4Bj5q3znRU97BiNNbvnUNgmC	47	70	70	1	\N	1708480089000	canonical
57	3NLGJ3jeuJW8pRDkvFwXgkUz44mXdjqr5d49PB3WNG2sNiR3Who8	56	3NKiAgdX3SsfA9KBMQYzkWoJV6ChAtprBzRYVC6wE2bFzHLg5hza	168	167	QnG-mmOiEjcQtYntz-_IWBbMBsNS3MAk5vottfb3dgQ=	1	1	58	77	{4,5,4,6,3,3,6,5,6,4,7}	23166005000061388	jxapBSBFmo98UfEgTUipqNJmC8dkteBd4nApUCB8JLA6uSb1msx	46	69	69	1	\N	1708479909000	canonical
88	3NKv9zjqPaJN9r9cuUDB8GY45Ejy6n51qhrowSsKkkFCADrTguak	86	3NLPyPHKcWomLLVKXAga8rUWPdAex8oQz4Jm89oz7ZDBVihERSXo	28	108	_JXMHSIe2Ag5JicFDNmxNeMNYbtmSfmWfWXTtKgUcA8=	1	1	89	77	{6,4,5,6,3,3,6,5,6,4,6}	23166005000061388	jwJUX3ZbQ7VTYkkj4WbssEyR5Ryd1LyFbUwyopwHD1ngJh4jGBj	67	96	96	1	\N	1708484769000	orphaned
92	3NLiSueMrPKVUSLjDHwC8KNHeeEJiJ3ztQf9W93oXxGKLKaGpTZd	90	3NLEy8KHUMC3A5YbQdWgrQMMFYgLaf8JHoC7fK7a7hQuSAAbaC7G	28	108	ARGmEe6WdD773lCU9DKu1smDK3xxsIsyB61KWCEkkQw=	1	1	93	77	{6,4,5,3,3,3,6,5,6,4,6}	23166005000061388	jx5bc53n5CT5pisSqmFMQnghhvprZ32MHUHwiG8GEqfWYxyPFCE	70	101	101	1	\N	1708485669000	orphaned
93	3NLZ3CVLNmFFEB68mX3mMgCP5Bp3ofxWJhdiMeCKcdqPD3vrRGc3	91	3NK33Z1gS9b81TgRv75md1KgQRb3DQ2HpkWUhjbc4Mc9jcv6wAmw	168	167	VDyW-2ryWoLVpk7slJ0Nb3oUBgokD5oI9iXkJf0LXQ0=	1	1	94	77	{6,4,5,4,3,3,6,5,6,4,6}	23166005000061388	jwykzKsmjqVnpLgToZBXsGZkTb6BsSMPnFebfdTUsDGo5T8X3rn	71	102	102	1	\N	1708485849000	orphaned
97	3NL5XWzh92Acvshi2HhPh3oMby1UtibnAm9yw8MU1kPFsrUfq2V8	95	3NLKCsMK6YTp3LWseV6nt9MQxHS9XUmEiKbswQWjoSr8RRcMnc8A	168	167	XzpLeICZXo2RQnDqN5dqdU27XP697WR6EAe-GPXtmQ8=	1	1	98	77	{6,4,5,5,1,3,6,5,6,4,6}	23166005000061388	jwXkREzrhszHxgejN1bzYXZ1kSgdAyPowvBqtyAyYPgj1qv2p9a	73	105	105	1	\N	1708486389000	orphaned
101	3NLSQGsCY8hHUCKqNUp1y9Uhho2YV1iNuLrFToZjEHhFWcupXriy	99	3NKmLfbVdDw5UgTANbHLhYQFqWjLRy8qWKme7TgRqeCW1Zk8dKWG	168	167	drOtZVdWWYVM-jxHfydflLDW060pmoNa3ng28-FblA4=	1	1	102	77	{6,4,5,5,4,3,6,5,6,4,6}	23166005000061388	jwRxmEXqS1KuBy8TCmw6maFtPWNL8xdhxpa3UrkXCfkNzQaAfVs	76	109	109	1	\N	1708487109000	orphaned
71	3NLybanCW6PmwJ9HqzXgcgZhVysvwr5Nfe7bm54D8kNFTd5XJqKJ	69	3NLN5M462h7MFe6mgdz9qpEkHbdvRR8L5qY3hg8NSBbq93hrbafd	28	108	jhUPlYv3uR_4Z9a2PzoBmdb22dgtFEYFk2sDYEsKhQA=	1	1	72	77	{4,5,4,6,3,3,6,5,6,4,6}	23166005000061388	jxieSmaf9HhSNVwkU7v7WSLQApLi4B7fq6R6Br3y6KctkrDAkUk	56	81	81	1	\N	1708482069000	orphaned
74	3NLrwKjY3H9SCXVdUzxj8GDySh2CrpPt8m486xanu5ggR3AbuvYg	72	3NLijKePFfuaLQFsoiUzVftuQnksPFEUS8zfPFKCTRsehLCAuaxH	168	167	qMRrhBXS1bBo7D-NjJhquzsdBZJi3QgZyMmI3TcjeA4=	1	1	75	77	{6,5,4,6,3,3,6,5,6,4,6}	23166005000061388	jxB5bmZtyM3ogdZq8w2aML3ga2x82E8bdcZATLkH3KjdnWE5oie	58	83	83	1	\N	1708482429000	orphaned
95	3NLKCsMK6YTp3LWseV6nt9MQxHS9XUmEiKbswQWjoSr8RRcMnc8A	94	3NLY2iRiJQzpZzUqcFKWT849tv8Cgz8MkefqyScNoWGEZdC71Vrx	168	167	WoVUGAJQ4H8E-GDgNHmiunE5JdP5s_R0l6se2R-dpQ4=	1	1	96	77	{6,4,5,5,3,3,6,5,6,4,6}	23166005000061388	jxniPbd2gw64Ecj9bz8yUfKYpc3yQKBMSjicZiWP2aw37iNagJd	72	103	103	1	\N	1708486029000	canonical
91	3NK33Z1gS9b81TgRv75md1KgQRb3DQ2HpkWUhjbc4Mc9jcv6wAmw	90	3NLEy8KHUMC3A5YbQdWgrQMMFYgLaf8JHoC7fK7a7hQuSAAbaC7G	168	167	u7BAmGCPmx_4bOFDe9FfGwSBJ8NZv9fU-0lw7VM16QM=	1	1	92	77	{6,4,5,3,3,3,6,5,6,4,6}	23166005000061388	jwwYm6D2zaEMSehgz9TzXCZAS1J9zjZV49dhMKqa3i7TzqcQJ7u	70	101	101	1	\N	1708485669000	canonical
89	3NLvVA2i4AgXhoH8FXg5LzMKRXsza9BFDyFQyrgaEvh8m6U3NnJ6	87	3NKSAPUXL8WNFqc6k3og9z9gS6fS5XqSF53wZgSYSCCcfPgN6VZT	28	108	AriGDNrY1dJqWBDKz4sBPJFFxmpncCtxj_BrJ5Ui9Qk=	1	1	90	77	{6,4,5,1,3,3,6,5,6,4,6}	23166005000061388	jx8Z87onPpA6xts41jft3bnoixf61BM3cXref7hTwjxDZM9Kge7	68	99	99	1	\N	1708485309000	canonical
87	3NKSAPUXL8WNFqc6k3og9z9gS6fS5XqSF53wZgSYSCCcfPgN6VZT	86	3NLPyPHKcWomLLVKXAga8rUWPdAex8oQz4Jm89oz7ZDBVihERSXo	168	167	LdxBIhDhehsWbLz9wiPQswyHRP1CHnt-fXEyjY5qkAo=	1	1	88	77	{6,4,5,6,3,3,6,5,6,4,6}	23166005000061388	jwbtS7odzUTP2RBHbu5i9maXaA69crYNcWVYEESPSSHhHciB8Rd	67	96	96	1	\N	1708484769000	canonical
83	3NLwcni1WxkziBdWwg8GGw9VwhA1duatYfpcj8wViuiap6Sct8aq	82	3NLDBeMtRCGFh2w8nnGesDkQ2U6GiW4iS1L5z3Wjx2omtuEa6ZL9	28	108	Ecpa9aVKLY4wqYGYWJ-bYcPrVN0HZiaeGOcA-k7bcw8=	1	1	84	77	{6,4,2,6,3,3,6,5,6,4,6}	23166005000061388	jwUGhNsqcuBhqg7GHQBAZgF9HHJcJYLZwxyxuHEJaUM7n8gBhMC	64	93	93	1	\N	1708484229000	canonical
81	3NLJYsqRYSMychHsvJh6qVCMt53pao3xtW2d35gqAXeWbTX6KQ9p	79	3NL4gJ7BsAhmWVTBed1bd9xaXUfn7TXfbbVcfMWfU1KCsNUW6HvU	168	167	cjiSkSsC4fl-bwan5ukrmRDuQY4BFFJ1AJSBu9bpiQ4=	1	1	82	77	{6,4,4,6,3,3,6,5,6,4,6}	23166005000061388	jy1WbeYXMNg1V14ewHLPLKPJyNSDXGPBdb7Nv7nT16eoEefv9p8	62	90	90	1	\N	1708483689000	canonical
76	3NKS7h4MJrPuVYR4YgjHbXg3AfCffmEVjKWzEVzmrYHbXow4M1Am	75	3NKqfPmV19F4nvQ6DX86e3QTyvfP5ikhe4q53ngg176i7qtHAnVm	168	167	-mMBpsKRKkHLIgkN3Ppi1pyl17N4Ik08KvJzbYLHfw4=	1	1	77	77	{6,1,4,6,3,3,6,5,6,4,6}	23166005000061388	jwmieafB1qd5VomrrXY8tFmSevpZAJcVWmdZyB4iMF2sKpDWojz	59	84	84	1	\N	1708482609000	canonical
72	3NLijKePFfuaLQFsoiUzVftuQnksPFEUS8zfPFKCTRsehLCAuaxH	70	3NKF8z2sHbf5XsLy4ZuUr2RztYSj832j8ujiDGDGms6WvRfmFsQ7	168	167	uP1iWSw39c4yWVtjYmYpk_y5laQFdqAPMGqZdIqu4wI=	1	1	73	77	{5,5,4,6,3,3,6,5,6,4,6}	23166005000061388	jwHXWRrZYKqw8PBFG5V8tRYtrM5jo4QnXvmfDABeLaSDHoBH9bw	57	82	82	1	\N	1708482249000	canonical
70	3NKF8z2sHbf5XsLy4ZuUr2RztYSj832j8ujiDGDGms6WvRfmFsQ7	69	3NLN5M462h7MFe6mgdz9qpEkHbdvRR8L5qY3hg8NSBbq93hrbafd	168	167	K0ufXnqkrXkxGd-YftxRnPstztSdt-o5p3cjthhvaQ0=	1	1	71	77	{4,5,4,6,3,3,6,5,6,4,6}	23166005000061388	jxLYbqNsymUmt18v4YbmPzrsVSrRCNsZESLFV1PnqCSeyFvajfo	56	81	81	1	\N	1708482069000	canonical
78	3NLTFRb3bYixpvg7iue1RTKPbMscJ5em9PeTJ37CwmW4BVE78uFW	76	3NKS7h4MJrPuVYR4YgjHbXg3AfCffmEVjKWzEVzmrYHbXow4M1Am	28	108	ZZigG1uw27I0YDtGtA2HcO6ar86cc32mTqViKUTKlQ8=	1	1	79	77	{6,2,4,6,3,3,6,5,6,4,6}	23166005000061388	jwXwgfgupCA5wPhahkWDuhVdWXF9qMZAdYfZn59mVBFzzKor1w8	60	87	87	1	\N	1708483149000	orphaned
80	3NKe9PCti7PayQ6ddSXfm36HAj2QU8yWH5QFZtqnQNHcfbdJW7rX	79	3NL4gJ7BsAhmWVTBed1bd9xaXUfn7TXfbbVcfMWfU1KCsNUW6HvU	28	108	04r1TpbHOy0FCeq5rWwRmDstzkAblZFDpxWQaPlU7Ag=	1	1	81	77	{6,4,4,6,3,3,6,5,6,4,6}	23166005000061388	jwnZT5psEa3yMqMLEApy6okDyKKxGisJzdhEAji1HHuvYmeZvCC	62	90	90	1	\N	1708483689000	orphaned
85	3NKCrsybTQYmci4pMN6jF34pAjLNHBbz17uLZCXJU7iS7U3gzvGN	83	3NLwcni1WxkziBdWwg8GGw9VwhA1duatYfpcj8wViuiap6Sct8aq	168	167	eN3LtQmMD9RYNKqjh4BS9ss9knBBhRbrMIrs7kDBQwM=	1	1	86	77	{6,4,3,6,3,3,6,5,6,4,6}	23166005000061388	jwfCkdADRFJSYKcJXgS7apaZHDiP8ubnquoYHj17my2RysqktgT	65	94	94	1	\N	1708484409000	orphaned
108	3NKjn7qFGVtwSxt4Z12NKTji45VsQFvgj7WKXjN3SsjCJxQ1UHNk	106	3NL25Cap5umgDDVFffsMJ2wiMxcmMvmWgeHsmAG9rz7xQCwNWD1t	28	108	Egv7NUKtGULzF2YBmpBv54iSz6Yb_1wfsTDepwtDTAQ=	1	1	109	77	{6,4,5,5,6,3,6,5,6,4,6}	23166005000061388	jxmtJ63FFJk3nQx3F3YC2UeD3SyuUS6LaNNf16QJj8ioGQZaULd	81	115	115	1	\N	1708488189000	orphaned
109	3NKU6if4yJMZWbZmxwVuYkjcQxh6eQPGBL7ABwE7Mp2ZMCoRSxq9	107	3NLehyST2WYNNYRp5khDgLGHijhxAwaifX4zAi2thedYm6XvgqiV	168	167	DuE4VT1SBvL-39tg-7H0w4Jsl7FWYZKF-XfC_mpaiAU=	1	1	110	77	{6,4,5,5,6,4,6,5,6,4,6}	23166005000061388	jwtF99DCfVisT6wJcQpaVWPutpCxQGnLys6dvgBnmomrfQgWqq8	82	117	117	1	\N	1708488549000	canonical
106	3NL25Cap5umgDDVFffsMJ2wiMxcmMvmWgeHsmAG9rz7xQCwNWD1t	105	3NLHnGsen9XAWSp5CdQiYPwPWZySWyGuQ1UPwbTbcLKQUkAg2Cjw	28	108	7VSWE8vGR9iQyaYMrAn6Ow1TUFDyZQn5t_kDBf-izA8=	1	1	107	77	{6,4,5,5,6,2,6,5,6,4,6}	23166005000061388	jxFYmxdwuV7ZdVUehQTyMetVkJC6fqSG7BtUhfvyKb3szD9EN4k	80	113	113	1	\N	1708487829000	canonical
104	3NKDipmjrwPdJ83zKjKF3tActw5w93sj4tKDNutGy5dopXG4efoa	102	3NKULg6fRnF2mrEfzhK3iiFwAiB7fq3fsmPEXPKEKCYxCi7XWu2S	28	108	l1CX5gEyeXlM5yj9Dsox5eyU6LrBYkNqf-nOuPYPtAw=	1	1	105	77	{6,4,5,5,6,3,6,5,6,4,6}	23166005000061388	jwoANfWGnNWh7hKsP2Pgwrd27r1aiNJThvqSdsVqaBXn7sw2DTN	78	111	111	1	\N	1708487469000	canonical
102	3NKULg6fRnF2mrEfzhK3iiFwAiB7fq3fsmPEXPKEKCYxCi7XWu2S	100	3NKN23ztkYLfpSGmg3HyZHTH1VBYXUxYoRR8aWpuDzA9R88dpcjm	168	167	opsgTGPTj50zPCpL4t_ulW-HjW2Mw4FR7A4m4_LBtwA=	1	1	103	77	{6,4,5,5,5,3,6,5,6,4,6}	23166005000061388	jxhZT8cWth9nXQsEbbosY8yqUdu9vdRYsEbUiaNLnscaGRNxwvE	77	110	110	1	\N	1708487289000	canonical
100	3NKN23ztkYLfpSGmg3HyZHTH1VBYXUxYoRR8aWpuDzA9R88dpcjm	99	3NKmLfbVdDw5UgTANbHLhYQFqWjLRy8qWKme7TgRqeCW1Zk8dKWG	28	108	XjMzI2WUHHA1qyIgFekylKK5AEEQyQQlientjatdaQw=	1	1	101	77	{6,4,5,5,4,3,6,5,6,4,6}	23166005000061388	jxz16gp2pMTqGCPiQzeFB1wc2voq9btgJ2BvB6JRNASVDKSqqFD	76	109	109	1	\N	1708487109000	canonical
98	3NKX12noMeXuvhXJp7xy97W1qV7jFsb92pD5KvtnY8w35BbnvCRg	96	3NK5hcnNPvUTYkBuHXiFD9YoncC9TxWzr5GyEtjiT8TSo3CJn95t	168	167	X6K3HM9AVGe02P_ocWgy-1Tjv11f9u6vEdQ9HJGdjwA=	1	1	99	77	{6,4,5,5,2,3,6,5,6,4,6}	23166005000061388	jwWneYcAMH1J3uePZPzeuM7MUz7G9FnCh5iXjq2bCVJmM1n2S43	74	107	107	1	\N	1708486749000	canonical
96	3NK5hcnNPvUTYkBuHXiFD9YoncC9TxWzr5GyEtjiT8TSo3CJn95t	95	3NLKCsMK6YTp3LWseV6nt9MQxHS9XUmEiKbswQWjoSr8RRcMnc8A	28	108	qDArNZlx24KeSI7OuzDJtcUXm9RKLdvW9mpfifDQzgw=	1	1	97	77	{6,4,5,5,1,3,6,5,6,4,6}	23166005000061388	jx1cptPowRargNQQcATrakEpVLodBGeN94BqDepMW3zTdBmvDkB	73	105	105	1	\N	1708486389000	canonical
94	3NLY2iRiJQzpZzUqcFKWT849tv8Cgz8MkefqyScNoWGEZdC71Vrx	91	3NK33Z1gS9b81TgRv75md1KgQRb3DQ2HpkWUhjbc4Mc9jcv6wAmw	28	108	0vnRur2VSJc-Ce9x_YRwLAVqQhwFKX1YpQn2vtJxJwM=	1	1	95	77	{6,4,5,4,3,3,6,5,6,4,6}	23166005000061388	jwVB2SEwTRwoJoR15nSs88epvDH5dfM9Tey337iuuTT1foWfzQ6	71	102	102	1	\N	1708485849000	canonical
90	3NLEy8KHUMC3A5YbQdWgrQMMFYgLaf8JHoC7fK7a7hQuSAAbaC7G	89	3NLvVA2i4AgXhoH8FXg5LzMKRXsza9BFDyFQyrgaEvh8m6U3NnJ6	168	167	YamAJ6VsCCeCV5ApROCoIwj2KWId6w51B_3DgEjkxwI=	1	1	91	77	{6,4,5,2,3,3,6,5,6,4,6}	23166005000061388	jxgmzbiMQSHa957nuCr3DSxsny1vdPRRzvSgU52bWp1j2WvsZse	69	100	100	1	\N	1708485489000	canonical
86	3NLPyPHKcWomLLVKXAga8rUWPdAex8oQz4Jm89oz7ZDBVihERSXo	84	3NLuSXxbCph21QERx4GqJSQ7npXun2KWUUP6K1snmCtZjeGWTrFL	168	167	wyuUibMtn6hIyMU9m07Qos4uSSsBBFss7_cs4Z95tQo=	1	1	87	77	{6,4,4,6,3,3,6,5,6,4,6}	23166005000061388	jwujJo8LViCZGPiqpMFrKU6wjQWjX5tL55dGxJew7G9Spy4ukHy	66	95	95	1	\N	1708484589000	canonical
84	3NLuSXxbCph21QERx4GqJSQ7npXun2KWUUP6K1snmCtZjeGWTrFL	83	3NLwcni1WxkziBdWwg8GGw9VwhA1duatYfpcj8wViuiap6Sct8aq	28	108	Ny4mtPz3rQHrqIb1N82PFuUgzCiMOoLa-jc3exVA2gI=	1	1	85	77	{6,4,3,6,3,3,6,5,6,4,6}	23166005000061388	jxwrHxZAaGrkotZxBxbbtMXMHUXxvyPpkW9ao24nNDGyzC8JkHk	65	94	94	1	\N	1708484409000	canonical
82	3NLDBeMtRCGFh2w8nnGesDkQ2U6GiW4iS1L5z3Wjx2omtuEa6ZL9	81	3NLJYsqRYSMychHsvJh6qVCMt53pao3xtW2d35gqAXeWbTX6KQ9p	168	167	eJXIB7tsp5xia9szziWmBbvXfp77ZhESotUUrjV32wA=	1	1	83	77	{6,4,1,6,3,3,6,5,6,4,6}	23166005000061388	jxoGapZTkVGQDsfNBK3uU3f5viupxvT1N6WnkpH2LY3j4HHpV2j	63	92	92	1	\N	1708484049000	canonical
111	3NKcgDmoAHnjHNqPiRyPt4EDbg5J6DTiDQD8eSQoKUiGN1oNteXh	109	3NKU6if4yJMZWbZmxwVuYkjcQxh6eQPGBL7ABwE7Mp2ZMCoRSxq9	28	108	BfgdctBKPOFdrSouo0O1CFBeRiVjIOP1A4bVGHZOQwE=	1	1	112	77	{6,4,5,5,6,5,6,5,6,4,6}	23166005000061388	jwPEP1FpcWp723bPWyqrSXj93kMTBRNUbXmj2zz9rLJ7GJfpQb6	83	118	118	1	\N	1708488729000	orphaned
112	3NLBkRK8MFwde2bNNNMUMpSA2A8G9LZDX6WD5cuihkSVNDFGtGaF	110	3NKqaAoYFxABrRCvaZ6pMCDdLLfXd2E1zjCyNEsUyNCvsnREoJWq	168	167	Bokco_-jQPHFp--a3ofgC6qaINgXkvKcA9H_ICylvAE=	1	1	113	77	{6,4,5,5,6,5,1,5,6,4,6}	23166005000061388	jwi4RHz1ocwc1UEm2WT66wFWiQ4KX79mpu1hYTpmkAMsUKZUPyN	84	119	119	1	\N	1708488909000	orphaned
115	3NKaHHjdZm35uN6hxdFpAKAi659YyQn1UFY7jKZy3Rv7tJM2AVy3	113	3NLfTpsccBX3uAHJwirtBtRZQgiqbgcPpLMiCRc95MbnZfM3V16c	28	108	4Uj8gAn1iwXoja2_J5ZXrowzBnZFCInCp-tUEimYnQY=	1	1	116	77	{6,4,5,5,6,5,2,5,6,4,6}	23166005000061388	jxQAu7EbA5dBV7MKLuZ7yvpsNJTUwugLEHw7Uj8zvvPgHTNfSjg	85	120	120	1	\N	1708489089000	orphaned
117	3NLWZAHbHyEeqYGGNaKgt93oGA6Dec5ts1MQXTu7f9ARGtDAGsKt	116	3NKz1c8VPXE2abKxDY2DQc68rtEHFrdcy3BGWL4gJ2ouVVtovy2W	168	167	CKoSP9KRxHxZpkWIPxV8oLbQpttlgiZi7dJJhuL7eQM=	1	1	118	77	{6,4,5,5,6,5,4,5,6,4,6}	23166005000061388	jwbyoLvuK3i7aucrjCRvdWdXzokXNsCCMjipnTR2CJC2iYWPUH8	87	122	122	1	\N	1708489449000	orphaned
120	3NKKA3gJeJMYf6iDB48P34AxYsBoJczunvNzM1h6z5F8iKiVBurR	118	3NKbUSqXJGLXxgxyua78QfwyXeQWoMzSzsSmzmpCpTpSnQserTqN	28	108	v3S_fqi6ICYXcsePocJ1ACAthRSLK0EgOTwoSRfPWwQ=	1	1	121	77	{6,4,5,5,6,5,5,5,6,4,6}	23166005000061388	jwXNKpzXKNkWZuHFXcfnXhY9PjaDPfaYG3xNWoCGhJvmf4Kro1u	88	123	123	1	\N	1708489629000	orphaned
121	3NKYCU4ix3yrYFZU8qZVPysqRB7V7cGHMtNzkdQZNTzMeYh7Gy8d	119	3NKRhMZt3QiAS7nH5T97NcGm9VjqDgtt2FHnKCJHrSer6awgwCtB	28	108	9jvEzJ8MpzS2oHHgv74nown4etXV8SWptut6jQzs2gU=	1	1	122	77	{6,4,5,5,6,5,5,1,6,4,6}	23166005000061388	jxDTWWF38ahyAmEnQGuiqUK8ixNp5XnYmRnRrF7Ejcx2HN1vfCN	89	126	126	1	\N	1708490169000	orphaned
125	3NKytPd1WkxUb2i17kZuJEZUKrt1sPkWo2V2N5jvefEYJTGiYUdU	123	3NL8Gum1iYPNQc3P66Yg6gpY1TWeQCW9N5Tumg46a2y4837zHUvw	168	167	i8G_AiuoIvuPn2uYLfZGvb3duGbiz-bNl79RKwQg-wI=	1	1	126	77	{6,4,5,5,6,5,5,3,6,4,6}	23166005000061388	jxBeCVmaPKwqk1j3ZJr9ngy9Pb9aq6BSjF4RZjPDd48gcyKqUEp	91	128	128	1	\N	1708490529000	orphaned
127	3NK4PV4zXeqgfFNrTicyUQn7hmNxHgSpgJS7HKHeF4vVG5pFode2	124	3NL3PJ7AuBWzSj2d9uYfTZufcY3PEkA3a4gQy9fx2PVHUn2vGnpA	168	167	m557yiNySnbSZ5MqTDAuHw0p_0YxOTbm7sWGdM4kJAo=	1	1	128	77	{6,4,5,5,6,5,5,4,6,4,6}	23166005000061388	jxks7D5EH6PujHg6Xsmm5N6B7mcaabSeeUVA1pSw63Xcu3sBfu1	92	129	129	1	\N	1708490709000	orphaned
129	3NLGHdRBBeMifiWzdaaaA16hLbNSRrcVC4bi2uu9tNeHAo2GLdkq	128	3NKJBmsXVuJMpcMGZayZj9VasjiWyeJZtUYSxwGmg5qS5yCNuPag	168	167	Cv801xYh6uSZdcPmlmaY4QhJ03Xgy0yfEcpSEwDbZAk=	1	1	130	77	{6,4,5,5,6,5,5,6,6,4,6}	23166005000061388	jxg39xRCkjCLLqgfJ4s3FFEbkTSP7f9XPRQRGW75MiFUknSdKZr	94	131	131	1	\N	1708491069000	canonical
123	3NL8Gum1iYPNQc3P66Yg6gpY1TWeQCW9N5Tumg46a2y4837zHUvw	122	3NLcW54aa8Sq8BJVv84Qfrw8piC5mjTHtcydmdoQUxmHhXxrZ5fa	28	108	YKJHzAMAVY4HGcVAwWSxdC4RZsJPrA884DXsY2PzHQQ=	1	1	124	77	{6,4,5,5,6,5,5,2,6,4,6}	23166005000061388	jwqB7KQ3ZkBD14EtYwqEZ1JBKqJjeBrSfrQhCfqhKgXBXBrEmCA	90	127	127	1	\N	1708490349000	canonical
122	3NLcW54aa8Sq8BJVv84Qfrw8piC5mjTHtcydmdoQUxmHhXxrZ5fa	119	3NKRhMZt3QiAS7nH5T97NcGm9VjqDgtt2FHnKCJHrSer6awgwCtB	168	167	ElSQYY8rsldCRZgqxHUmju-5tRqN--6rIUc3dLb4nwQ=	1	1	123	77	{6,4,5,5,6,5,5,1,6,4,6}	23166005000061388	jw9uMBaMvpzkWWUEm3iScWwRPhscQtaGXQcf3i3R1LH5bF9mV8r	89	126	126	1	\N	1708490169000	canonical
119	3NKRhMZt3QiAS7nH5T97NcGm9VjqDgtt2FHnKCJHrSer6awgwCtB	118	3NKbUSqXJGLXxgxyua78QfwyXeQWoMzSzsSmzmpCpTpSnQserTqN	168	167	aOvRrfUk32B9GjBcH8T6FsD_OWTjzG_pFk9OB96F1w0=	1	1	120	77	{6,4,5,5,6,5,5,5,6,4,6}	23166005000061388	jwRHtuhQxnZvArzvc6mJX1WpVmgR5eTo9RPx8FUzedTkqotrHQy	88	123	123	1	\N	1708489629000	canonical
118	3NKbUSqXJGLXxgxyua78QfwyXeQWoMzSzsSmzmpCpTpSnQserTqN	116	3NKz1c8VPXE2abKxDY2DQc68rtEHFrdcy3BGWL4gJ2ouVVtovy2W	28	108	F8i4DYFIAR0c5zs2qxzq-LPsGWhc5B5UfQIr_wh0SAE=	1	1	119	77	{6,4,5,5,6,5,4,5,6,4,6}	23166005000061388	jxJUXeDF456ftfP9mMztFHJLYiMTY7LdZtreXLfxp187JBCW4Qj	87	122	122	1	\N	1708489449000	canonical
116	3NKz1c8VPXE2abKxDY2DQc68rtEHFrdcy3BGWL4gJ2ouVVtovy2W	114	3NLPVSKBhRVjmcr7eJPjboX42wqf8SdFrKSDn27UGqu7cF9SHknp	28	108	22S0APz3X7UjA0oyfU2weAHLCRllpWocnhwxCptUUgU=	1	1	117	77	{6,4,5,5,6,5,3,5,6,4,6}	23166005000061388	jwPYEzjpGeYjru15K9NbMoL33EFm8iMYDHpXEPMoa9BrdgDvKe4	86	121	121	1	\N	1708489269000	canonical
114	3NLPVSKBhRVjmcr7eJPjboX42wqf8SdFrKSDn27UGqu7cF9SHknp	113	3NLfTpsccBX3uAHJwirtBtRZQgiqbgcPpLMiCRc95MbnZfM3V16c	168	167	iss_Olddx0EZuZwt_fwJn3_bWFRAMrjzC8BRmLYzpAs=	1	1	115	77	{6,4,5,5,6,5,2,5,6,4,6}	23166005000061388	jxDgSpYCYZbotLDWYKHvRGF9WhLfnQynCWbxzduQL7M8pymJdZ7	85	120	120	1	\N	1708489089000	canonical
113	3NLfTpsccBX3uAHJwirtBtRZQgiqbgcPpLMiCRc95MbnZfM3V16c	110	3NKqaAoYFxABrRCvaZ6pMCDdLLfXd2E1zjCyNEsUyNCvsnREoJWq	28	108	6PL-RxyREcvmBZhssuFVPYFz9wD6le_REbZySSkiIwc=	1	1	114	77	{6,4,5,5,6,5,1,5,6,4,6}	23166005000061388	jxpugsfFLRM91w3wo5Ja6DWDeRMx4gxwik9Mufd69r5mGpeGz3Z	84	119	119	1	\N	1708488909000	canonical
152	3NKVY9iGwyfWEapzWj4bD3R7TgP8tJr8psRjroM79fedF2juZJza	150	3NK7NLsbHww2pw1CyN86pZyuV9xE15X9eHdNd5GHjWDNrjBtVb4h	28	108	lTo781i73UmOe_IUxpd5dJAdCR-JFTBglW917AjQwgI=	1	1	153	77	{5,2,5,5,6,5,5,6,3,5,5}	23166005000061388	jxGaxg2CrZVR4RS9EFFUGafeeha2JzTxY2Tq9MoDYU3H4vRwZBQ	114	162	162	1	\N	1708496649000	orphaned
130	3NL1Deh142vH37gPCBD7R5Jjw8coicz4A7tUtCrvmfwx89YmuSSw	129	3NLGHdRBBeMifiWzdaaaA16hLbNSRrcVC4bi2uu9tNeHAo2GLdkq	168	167	2NrcL-n7e95AX0ZH4RbUeTwKwSjmbg8Ua59lmdd9eA8=	1	1	131	77	{6,4,5,5,6,5,5,6,1,4,6}	23166005000061388	jy1JgFd7PB22QkWEmCaxviC9vmPT328mFBmcFFpDDDA7gacKMkq	95	133	133	1	\N	1708491429000	orphaned
151	3NLQq1WwT1nXS1dLCNVTNZE8aiXG5SzRaqjMZkt7URsBSdBoAA35	150	3NK7NLsbHww2pw1CyN86pZyuV9xE15X9eHdNd5GHjWDNrjBtVb4h	168	167	Ut2HkZMRqmFe0p6C6Op3Y4epxf7Xv2L12Xxj2XF18QQ=	1	1	152	77	{5,2,5,5,6,5,5,6,3,5,5}	23166005000061388	jwBsU4pQ4reYvv9YKUFU12qDRXJqoHEj89Q13yuDXwbNDAzDWaJ	114	162	162	1	\N	1708496649000	canonical
149	3NLY7HP9Vm9UxfhKzjhkxa8bXNxcdLjTmzUXVBmH2iieaFNrJvGr	148	3NLaonChBYmX3Pqt94gdjicGXFKajzc668SiLxu6GmhrReBJeav3	190	189	6UBUkgTV-1lM7qZ4z1SiZex7rkJOXbhkpFoTN5FqFwA=	1	1	150	77	{5,4,5,5,6,5,5,6,3,5,5}	23166005000061388	jxU4s2uqqYxWPqPAUvGk7d7Uoh1aHyXzjHndb89LS2TubScbAjP	112	160	160	1	\N	1708496289000	canonical
147	3NKnDmgJ7SdPqxDi39hrvuuyv7W2XBWgU1NKPyXPriRNseQQrDg7	146	3NKCcKATvP6JuEK5bRVJBrRH2L1oNHhx9G9e1EHh5d1g3bybsG3c	168	167	0Ibk_fHHeHUOXFBBnylc3DveOrBPvKG8qVF7wu9OmAc=	1	1	148	77	{3,4,5,5,6,5,5,6,3,5,5}	23166005000061388	jxbUE7x2Ecbb26BUf5qHesdMYuacqMBzojnN5eQUenNdjryha2y	110	158	158	1	\N	1708495929000	canonical
145	3NLxvdBnuLbQWcZFh7L9PXeHV7B8kxbCFhaApGcPbbSPuZ7rzjbE	144	3NLRyqyeULxZKt5hf728yyYsN14KMVMGYMkhzitrU9LGSzBo4YjG	168	167	jMx8T_NMz4WBt3wDgGPy5bUi_5vclzoHaZN5cAGahQE=	1	1	146	77	{1,4,5,5,6,5,5,6,3,5,5}	23166005000061388	jwHEHGCdjxxJwwAP6qbL6vjDPc9KjpukgnDTY4ELam9oSuGPJEa	108	154	154	1	\N	1708495209000	canonical
143	3NK8gGLaNPr9NNr79JBb94KygePrLQmdoVmKthDxQ3ECUzqipNXt	142	3NLiEtShQFSjAd8Cp4itVLeAa9NydKA43g4Tun5XzBmpktjT1zYz	28	108	D04_s4N4xopaplAJYDcZXLBj2LeTvOFBnZhMgcnG0AE=	1	1	144	77	{6,4,5,5,6,5,5,6,3,5,4}	23166005000061388	jxYaFvxWU5VZ4UPqaBMc4dcVx2BL1KgMH6EJWVcGbwnn77q6p4n	106	152	152	1	\N	1708494849000	canonical
141	3NKegEqNTqtv6hxJxrH8KEGmJMwoSs5niXF7mh2kqwx8PVsoXwbN	139	3NKcajbQ2EGf33HsyzUEgn5EAg5Bs9KpPJk1zcP2ayzMp1S6Xiwo	168	167	L8mgxh4eFLnBeKA7nNGvzBi6OLjYfixbowxbiSP2mgA=	1	1	142	77	{6,4,5,5,6,5,5,6,3,5,2}	23166005000061388	jxZXQCPtPdFgD4DtBHzvWp33JBweGGy8TcMtzWBu5v2e4ckegmE	104	150	150	1	\N	1708494489000	canonical
139	3NKcajbQ2EGf33HsyzUEgn5EAg5Bs9KpPJk1zcP2ayzMp1S6Xiwo	138	3NLjp1aEj5Js6he7vTzxpuZNNLNcwPki3jyHNtbjYquVafewTf7U	168	167	C5vwOMOgQ4eZzLDcgbq_BwOOKz4e9LhQnuFF0YfIYgw=	1	1	140	77	{6,4,5,5,6,5,5,6,3,5,1}	23166005000061388	jxYDvWnQedrRGWwZifG75T5VAKt6gupeknfNi1uPHKUrvKH2pvZ	103	147	147	1	\N	1708493949000	canonical
137	3NLXbPzzkhSz89QJJhqw1XkZ9BVEP4Wdisqz3zeCPr2n6BVgbcgz	136	3NLoo2dHuJZPfmyf2Qr4sqJboSo5nLeamugugdZjxUYq9E6carX4	28	108	r_aOkTYHlqtzsk8_DCNm4AmDYndKZFPWCbmWRk8hsQo=	1	1	138	77	{6,4,5,5,6,5,5,6,3,4,6}	23166005000061388	jwZrGZo1bwKt1xauaPJdsd4wJqGzdi47fvZoQwX8dzwuHGz6L6H	101	145	145	1	\N	1708493589000	canonical
135	3NKEDtwe5VCrEdpohBoaoj2vS7njzU28StWEnRzrFQ1shkMkn9Rh	134	3NKCjiDRjvGMtFMRWaBaS13cAzaEfU2nFDHVK3jWJ5sJ3wCVzDio	28	108	OkM49GXsk8MsRY29TRtZY9nwlGQcL9BcKWZtrpbbAgY=	1	1	136	77	{6,4,5,5,6,5,5,6,3,2,6}	23166005000061388	jwcAQ4m6foCoANnZ2cWaTpG77Bp6tWhBMCMM6ZzdpcLGjLG33X8	99	141	141	1	\N	1708492869000	canonical
133	3NLpdLYLiYCrdZBTwABEVdqH8AabqkV68qfr1Fi1eDPDVavtTSjY	132	3NLEEpcjC54o68wqjPKBh7PBWG6fCHULz2uwWHxKW47aw6VZp5Lw	28	108	opD8w0-N50wxMKUKQLg61ZCfmV0TN7IfqM9h4LW1IQc=	1	1	134	77	{6,4,5,5,6,5,5,6,3,4,6}	23166005000061388	jxUuG5tzSWHpAdBvZyBcUD955Bv5m3gyVjVb3fBDYJM2xUxJySz	97	138	138	1	\N	1708492329000	canonical
132	3NLEEpcjC54o68wqjPKBh7PBWG6fCHULz2uwWHxKW47aw6VZp5Lw	131	3NLJ6M7u5qHyw7HM3pAf8bYFmMAooaLBsbhxWTkXm6D8uErwkgxn	168	167	n35mciIzo84ZZMi0yWKHGnA-ss-E19JlBvW7cb089A0=	1	1	133	77	{6,4,5,5,6,5,5,6,2,4,6}	23166005000061388	jwhNJKiPzAwsU8f76ygL5M2YpAkHHAfYo3dDA9uGMkS471joAZ8	96	135	135	1	\N	1708491789000	canonical
128	3NKJBmsXVuJMpcMGZayZj9VasjiWyeJZtUYSxwGmg5qS5yCNuPag	126	3NKNEK9UNTHXTgtziYUe1ZZDeu1JfuicYvzKr6xhSRTd4RujdxTz	28	108	HPrt4jh9tKeYBFGSqacIxonOAtzWapNJ4MhN865gnAw=	1	1	129	77	{6,4,5,5,6,5,5,5,6,4,6}	23166005000061388	jxXXAehVi2iL6vEEghPvHBSe6Srpu2SvhY1SuAsXWuHTZjFfCYR	93	130	130	1	\N	1708490889000	canonical
126	3NKNEK9UNTHXTgtziYUe1ZZDeu1JfuicYvzKr6xhSRTd4RujdxTz	124	3NL3PJ7AuBWzSj2d9uYfTZufcY3PEkA3a4gQy9fx2PVHUn2vGnpA	28	108	phMhiq8h15k5NrrctLdGLjs9V7PmPC5-RlChMJkAHQA=	1	1	127	77	{6,4,5,5,6,5,5,4,6,4,6}	23166005000061388	jwmkthrWseDsjkdc5xGniobSytqwGFRGkTfaB7gbGbwTWA7fjCc	92	129	129	1	\N	1708490709000	canonical
124	3NL3PJ7AuBWzSj2d9uYfTZufcY3PEkA3a4gQy9fx2PVHUn2vGnpA	123	3NL8Gum1iYPNQc3P66Yg6gpY1TWeQCW9N5Tumg46a2y4837zHUvw	28	108	ETh4aYJkSs28ONbEIKaTimkAXhIk2BC1-59pYBgBaQQ=	1	1	125	77	{6,4,5,5,6,5,5,3,6,4,6}	23166005000061388	jxNmr5c3Rm1GzJ3JtWALfShSQiitm6j3NKnm1fXjx2AJjF2YDpv	91	128	128	1	\N	1708490529000	canonical
140	3NLFxhSuHUh7SRAanTeKdcifww9Pe8mfLZau3zhVRVPANmtG8KgP	139	3NKcajbQ2EGf33HsyzUEgn5EAg5Bs9KpPJk1zcP2ayzMp1S6Xiwo	28	108	PL1H2M4Erb8woKdkBtATPv8yAfFU2nx9IeKDMtBdNw0=	1	1	141	77	{6,4,5,5,6,5,5,6,3,5,2}	23166005000061388	jwRKfedy1uxr94mVqLikgfuwz2aFyqBvh981LHhMmpFxX5ghCdn	104	150	150	1	\N	1708494489000	orphaned
154	3NKpBFBRJD4excJxvXNsx8nTKhkk9nyWMHbuCSib7UbmP2tRkxE3	153	3NL9hvVRoAQTy9xTrW1F5oi4rLC2SLDb4eRwf4hjW8tSkjhYQpid	28	108	GZY94NdQ64Hq_hLAXBS2i5qy9GV413WiPZTgp4fWgwY=	1	1	155	77	{5,4,5,5,6,5,5,6,3,5,5}	23166005000061388	jy1pT3vjcaKbZoZj69BjbdYP71WzZwZuHnQCsmKsrY6bReDaqB5	116	164	164	1	\N	1708497009000	orphaned
156	3NL2NeyUjBbDKgkbK5YMCbCXceXzWtktnzx9DJ696FpA9SjwMvPB	155	3NKj17RTcDNzH7ywCMu5TP3dM4Nx1H2JYLJCyAFyrAm7r9rZ8NU8	168	167	NvUu5YziNL9a9lYhsc1Eg-QS-86SRHgbLpkiT5zryQE=	1	1	157	77	{5,5,5,5,6,5,5,6,3,5,5}	23166005000061388	jxmT8MhSNxHBXPQQzM3D6LAAdQ4NxsCa8yRRH1Nmm4C9VgUCGnG	117	165	165	1	\N	1708497189000	orphaned
158	3NKx4Np3mZky4BtsJFwy4aSquuC5hfgUtdnkdedfBhqxhPqkUYk5	157	3NLkwnDMz73b5Wz8sEDvKnW85n4aUkDNakzcNboQWxXVdgZgb7vV	28	108	OFi0LMa1gagik4l7gpIDUv-AntjvJ6deg_TynZzIBAo=	1	1	159	77	{5,6,5,5,6,5,5,6,3,5,5}	23166005000061388	jwuLBGjNFjwMC81W4YfnaRfvS6xqcPXz4UQwZStTidrsSoYf5Tj	118	166	166	1	\N	1708497369000	orphaned
163	3NL8Kuf9x8Kb1TqX3ymsbapw69DZSAm1SNNSLxTbHqcwm1caQiXU	161	3NKBcBUKLkjpDChp6YdrAfapHNJKJd3SwdnGYBCUKuTQt28qRjsf	28	108	w0YposmcGs6-i-wzMpyQWVei1qmiH7L50sz1aQ1L9Aw=	1	1	164	77	{5,7,2,5,6,5,5,6,3,5,5}	23166005000061388	jwp4nj6KcH92fSB6TwXSYUa7gqXUUvK4D8jqHHS1V96iczrkA1m	121	169	169	1	\N	1708497909000	orphaned
162	3NLQWPAnWNR2xALL13oF5Ntr1tTY3yvoVWV1wxdtJWvtJnkYELt4	161	3NKBcBUKLkjpDChp6YdrAfapHNJKJd3SwdnGYBCUKuTQt28qRjsf	168	167	TEKToP8paU0IHs5a-d_bYZPIX15xUCGUC4Qg7m1Fjwc=	1	1	163	77	{5,7,2,5,6,5,5,6,3,5,5}	23166005000061388	jwu1HjUXnbvX8sHbKL25kqCXy6Viymz2BWTxeoUykhS5Gx7H7M9	121	169	169	1	\N	1708497909000	canonical
160	3NLo54vkrXYBzRAv71bMYTzoresqf5KA3kJnGk4DVjjs8uwKp1wK	159	3NKMRXmjdcVwGM3S5WSEbFqJ4ByLxBPRtyexSudBVcMTuZbTJVJs	168	167	rwh_EP3i1P-x5-AUfL43cUgkfFIzeA8sneSNDLAlXQ4=	1	1	161	77	{5,7,5,5,6,5,5,6,3,5,5}	23166005000061388	jwGPqfwC3jqK1wEePrVSkLc7tBR2HRv1DSmnMaww57vdLJsAaAu	119	167	167	1	\N	1708497549000	canonical
155	3NKj17RTcDNzH7ywCMu5TP3dM4Nx1H2JYLJCyAFyrAm7r9rZ8NU8	153	3NL9hvVRoAQTy9xTrW1F5oi4rLC2SLDb4eRwf4hjW8tSkjhYQpid	168	167	mEpChlyMRSY--FuM6UdWo0z1B2mn9PE95diAsJpRNwI=	1	1	156	77	{5,4,5,5,6,5,5,6,3,5,5}	23166005000061388	jwRpaG24u1qNpUU9PzLDznoBSvgZVMXoz7yssy4iNs2FvQK75LV	116	164	164	1	\N	1708497009000	canonical
150	3NK7NLsbHww2pw1CyN86pZyuV9xE15X9eHdNd5GHjWDNrjBtVb4h	149	3NLY7HP9Vm9UxfhKzjhkxa8bXNxcdLjTmzUXVBmH2iieaFNrJvGr	168	167	s2Z3U0sGhBdcJ9_Ym3IDndW38rd3gq6s8Dslzut_1QA=	1	1	151	77	{5,1,5,5,6,5,5,6,3,5,5}	23166005000061388	jwWwtxTLQW9LvCWARqeGSaoPcspkGqJpdcAyu1AQV9yV9puLwc4	113	161	161	1	\N	1708496469000	canonical
148	3NLaonChBYmX3Pqt94gdjicGXFKajzc668SiLxu6GmhrReBJeav3	147	3NKnDmgJ7SdPqxDi39hrvuuyv7W2XBWgU1NKPyXPriRNseQQrDg7	28	108	cNcmu368jxg00VLNeBNxoNUQCh3OOD9hxXJiXQVUxwY=	1	1	149	77	{4,4,5,5,6,5,5,6,3,5,5}	23166005000061388	jwzvv8kPerbGmFRz1JmNG87LzYyKcaEGTUvcmNV2kM82m4ZCHYM	111	159	159	1	\N	1708496109000	canonical
146	3NKCcKATvP6JuEK5bRVJBrRH2L1oNHhx9G9e1EHh5d1g3bybsG3c	145	3NLxvdBnuLbQWcZFh7L9PXeHV7B8kxbCFhaApGcPbbSPuZ7rzjbE	28	108	ABKpKWKUY9HOVxYLAWIKtNUFWp_aMkcHdYx_RH1vCgs=	1	1	147	77	{2,4,5,5,6,5,5,6,3,5,5}	23166005000061388	jy3A6ixupffAz7ewNumSXJuDvjdfoRfGK8kLpeKk1gGvAr2G8Mv	109	156	156	1	\N	1708495569000	canonical
144	3NLRyqyeULxZKt5hf728yyYsN14KMVMGYMkhzitrU9LGSzBo4YjG	143	3NK8gGLaNPr9NNr79JBb94KygePrLQmdoVmKthDxQ3ECUzqipNXt	168	167	7jiiC0i3M_CaCmYiEGK406BCV0xFhZEwQQ3wF0Fwjgo=	1	1	145	77	{6,4,5,5,6,5,5,6,3,5,5}	23166005000061388	jx1LgPayghsbMo5WWLp4vzYy7U6wsLEkUMeTjFCAM1JQmDFriCw	107	153	153	1	\N	1708495029000	canonical
142	3NLiEtShQFSjAd8Cp4itVLeAa9NydKA43g4Tun5XzBmpktjT1zYz	141	3NKegEqNTqtv6hxJxrH8KEGmJMwoSs5niXF7mh2kqwx8PVsoXwbN	168	167	t0TGkHfME8y0DmJbUj2wead7gHR23zYzZFlgjaxVOwM=	1	1	143	77	{6,4,5,5,6,5,5,6,3,5,3}	23166005000061388	jwtniTUAFzTqgiYZjPzja6EMk6EcGy5HysiXTCSHxVW2eRGzDrL	105	151	151	1	\N	1708494669000	canonical
138	3NLjp1aEj5Js6he7vTzxpuZNNLNcwPki3jyHNtbjYquVafewTf7U	137	3NLXbPzzkhSz89QJJhqw1XkZ9BVEP4Wdisqz3zeCPr2n6BVgbcgz	28	108	xpVcN3xkyK_oIvUfVpFIlNcUjx9q7t3zezjy5V4iMwg=	1	1	139	77	{6,4,5,5,6,5,5,6,3,5,6}	23166005000061388	jxfZpyByjBnHhnx1faf5XRVJigQt46oC1LnnNMEnvqcStSCrkc1	102	146	146	1	\N	1708493769000	canonical
136	3NLoo2dHuJZPfmyf2Qr4sqJboSo5nLeamugugdZjxUYq9E6carX4	135	3NKEDtwe5VCrEdpohBoaoj2vS7njzU28StWEnRzrFQ1shkMkn9Rh	168	167	6oHBoDMGlNZ8LgCiJc2WwZ8Sn7ekCez1j1WLDLVGgA0=	1	1	137	77	{6,4,5,5,6,5,5,6,3,3,6}	23166005000061388	jwLKXC43tLRngiDAKV3XmgFVGJBfKNHM9Z8GYZm2qW5j2GtQwMp	100	144	144	1	\N	1708493409000	canonical
134	3NKCjiDRjvGMtFMRWaBaS13cAzaEfU2nFDHVK3jWJ5sJ3wCVzDio	133	3NLpdLYLiYCrdZBTwABEVdqH8AabqkV68qfr1Fi1eDPDVavtTSjY	28	108	Z80OWsxcNpoeFExJW6KAYiaVnOckKiNh3tJc1uFdRg4=	1	1	135	77	{6,4,5,5,6,5,5,6,3,1,6}	23166005000061388	jxMcmfWhXx4fvTA6mxtqugpChXQ6NBSYgxuUqHReFsKoQp8WQA9	98	140	140	1	\N	1708492689000	canonical
166	3NLx5vXboJ6W97f4hCtFJqtFzjeR57HHpq8M3NDdzo8kCEnN6pf9	164	3NLMV8zkn7bYRzsRyvYGEDz8SmNQWFM9ew7WNFNFuTJwLBh9Wq9Y	168	167	tGPGF8X0tmvlwDq_bXtvuC8_khpFiv6YRjjeltHRJg4=	1	1	167	77	{5,7,4,5,6,5,5,6,3,5,5}	23166005000061388	jxReKt695tGJiTpRzF5q6i1yxnPAL9W7UGAQKx8uPdECsNp2mpu	123	173	173	1	\N	1708498629000	orphaned
171	3NKM3Yvi35PiLEy72bPVRZ9LuqFGKmH4bdYsmAJvwcbZtzY3RXS1	169	3NKWaBouUxHh5gzZYwhQpZt5ozrqhhq74wHh8YyMyuLCB7jRssBn	168	167	g5BKYytALlWFsC-dPOe52RbfQzWegwvbZM-1W7k_lQI=	1	1	172	77	{5,7,5,3,6,5,5,6,3,5,5}	23166005000061388	jxP5gZegfx7jiZE2UZtxfxahGUg6cvaXt2WKZJgwhgoq4e7uxUo	127	177	177	1	\N	1708499349000	orphaned
172	3NLGJPnJY5cKBhjGNwBqrgddMELutnABjyq9HBBtfLwXKTYUEc8d	170	3NLE1jsbRi1i6hRqMGchEPVtVw1dDsntJX7in1GFpm5GgYUL4mMP	28	108	RXT4yiwMOVV09QKQHYE-ibHePOEG3eppQh2ivOvUxgs=	1	1	173	77	{5,7,5,4,6,5,5,6,3,5,5}	23166005000061388	jxb9JxXWQ28YouQEc93Ra9VVzb9oDBJLA15g7a26GtMK93Yvawt	128	178	178	1	\N	1708499529000	orphaned
174	3NLaNYTnsvj7gcJtLJWnuf4FLJQghXkRsA1EDdzjYyciprZtc4vo	173	3NK93nNvm9YCj42QNw2S2Ci3AcaKvtrQfMyLo8xj3KK4Txx8owez	168	167	C_mDEvJ5N3eE1zbYCDGlstDOhh9H7JOcqrOAYHAc_gk=	1	1	175	77	{5,7,5,5,6,5,5,6,3,5,5}	23166005000061388	jwbHJhNzbNwDrTLJyXQdDBpvX33y55W9EXV4eEdEhW4vDbWjErJ	129	179	179	1	\N	1708499709000	orphaned
178	3NLSjZxgMdfFrz5Q1zcgMGR7Q5a1n2XpJtVeVhMzX7ma8D74wg6e	176	3NKSfxC5d9nSCghce7g6KJgbifnJe4Nohi62k1oEtPiUkHcf3Nbu	168	167	1ThqrFhWFbKZax3G2Ov8WvZRhS4JShMfk6rtBt1wiQU=	1	1	179	77	{5,7,5,6,1,5,5,6,3,5,5}	23166005000061388	jwMCd1xv3Zorq1otnMLcXMLK57oM84khAQPzpSxb1Xv3Mu3rqFi	131	184	184	1	\N	1708500609000	orphaned
179	3NKrRG2TcnKdRZFMwuDFg5D7BswKGnt89aS93ZfKPueDTvhm6Eo5	177	3NKCsGz4aapFxSANd8DRngkRaN2HptEmenrESiCWPczL33TENeDc	28	108	qrzbP3W7MHFkPH5MTu9BU6UqmCsiC2HGuJ7df5xVJAA=	1	1	180	77	{5,7,5,6,2,5,5,6,3,5,5}	23166005000061388	jwQPoAmRVADtG93TratE5PthmCeiTxQHZpTpnFGfFtBx44ySwGw	132	185	185	1	\N	1708500789000	orphaned
190	3NKm87s5oKWBEsHaUjEbQwwS9YPAsQBUZ9jt6zA2JpDdkxeNXqa6	188	3NLYis15CYedj5CCRihGLd1wMo3iFqgNj2edzJLQe9wbospdj47c	168	167	NMi7xKh__sBRWnvZ7XHC4SmuCP-UMqd3USAlT-ZlhAo=	1	1	191	77	{5,7,5,6,3,3,3,6,3,5,5}	23166005000061388	jwXqrpEB95SGavnUafDR8mRFqXwKiqbxr1dSB9hhPEHq8mNtSCm	139	198	198	1	\N	1708503129000	canonical
188	3NLYis15CYedj5CCRihGLd1wMo3iFqgNj2edzJLQe9wbospdj47c	186	3NKaH48tPQNTeBCNhKUEVR3DqPdg6p6hRuGX9FXVktWBuj9nFzLY	28	108	dQrpxOAq1ie9grekT-3AUq4g_6smyDjjAngN1Z1ShAA=	1	1	189	77	{5,7,5,6,3,3,2,6,3,5,5}	23166005000061388	jxpfVPTFEPoKt6bcTroV9LtLWWLfJgyisNBHFkDsYhhcdQCPJV8	138	197	197	1	\N	1708502949000	canonical
186	3NKaH48tPQNTeBCNhKUEVR3DqPdg6p6hRuGX9FXVktWBuj9nFzLY	185	3NL7m5C9MdKKACxM75L9KQnGDbFVWT1cNsZseUA22Nfo12muRLYH	168	167	B1XOpVEqpJ0S2eMz4gSyujxWglAPZG2Fx81pRySdqwM=	1	1	187	77	{5,7,5,6,3,3,1,6,3,5,5}	23166005000061388	jxi77J2yzKrWhz9GeCmZdWJCjQaarAHmjzrDV2hG5ovVaMkMWBq	137	196	196	1	\N	1708502769000	canonical
184	3NLukGpZoz5cHVXbwrKsqanJXyQrJ4NxgmqLFuZsBYHUaoePjpzB	183	3NLczS9PiUzSLBPHEQmkdvHMrY8zv8Kei77y964hoxcAQryV7PWy	28	108	BDOdkcXn3KDxfgIy2MGTR4LtoH6HzycgTfRWf8OaZwI=	1	1	185	77	{5,7,5,6,3,2,5,6,3,5,5}	23166005000061388	jwBe1Gr1GHhv1WAuz3DirPDY2bwZACJkmUZ6e6BwBpAvs5cNL5g	135	192	192	1	\N	1708502049000	canonical
177	3NKCsGz4aapFxSANd8DRngkRaN2HptEmenrESiCWPczL33TENeDc	176	3NKSfxC5d9nSCghce7g6KJgbifnJe4Nohi62k1oEtPiUkHcf3Nbu	28	108	9qXHf7pJdshErLzPiw1J47nyGWviAcVxkAjmfuYbzwI=	1	1	178	77	{5,7,5,6,1,5,5,6,3,5,5}	23166005000061388	jxRjfBL4NnF4Skqg2m6Wbf3v5GvgvjVvcLnGy3YR9qXF8E2cRJq	131	184	184	1	\N	1708500609000	canonical
176	3NKSfxC5d9nSCghce7g6KJgbifnJe4Nohi62k1oEtPiUkHcf3Nbu	175	3NL6HoGZfB1qUS3Av4thoX7sLQZLhVpcNf9HuHH2QbzEGSW6897E	28	108	n4CRBSzQySu0-23Nl_vFLmqCcvPRuNx3G7DL7syPVwM=	1	1	177	77	{5,7,5,6,6,5,5,6,3,5,5}	23166005000061388	jx75xfmvZUc2baDXVpk2KmtJsuJGf8gjMmFS11M61kYtBwf6Vau	130	180	180	1	\N	1708499889000	canonical
175	3NL6HoGZfB1qUS3Av4thoX7sLQZLhVpcNf9HuHH2QbzEGSW6897E	173	3NK93nNvm9YCj42QNw2S2Ci3AcaKvtrQfMyLo8xj3KK4Txx8owez	28	108	q_FBUPXc-T21WPgKahVGzs5Zmw_NMNas2hYWeU95ygg=	1	1	176	77	{5,7,5,5,6,5,5,6,3,5,5}	23166005000061388	jw9ryR44Myxuw1xQE6kUK69ZKwtpapWEDnNbx1KrFMh5KrZyqV6	129	179	179	1	\N	1708499709000	canonical
173	3NK93nNvm9YCj42QNw2S2Ci3AcaKvtrQfMyLo8xj3KK4Txx8owez	170	3NLE1jsbRi1i6hRqMGchEPVtVw1dDsntJX7in1GFpm5GgYUL4mMP	168	167	P2Skzt_B-OC2g4gZRh1pU0TV-9qSN6e0nbrVNmuMBww=	1	1	174	77	{5,7,5,4,6,5,5,6,3,5,5}	23166005000061388	jxRVj3ADJowSnQQFVMWv6z1LD3bKJ8sjEtDayRyj2Py8UVhtM2i	128	178	178	1	\N	1708499529000	canonical
170	3NLE1jsbRi1i6hRqMGchEPVtVw1dDsntJX7in1GFpm5GgYUL4mMP	169	3NKWaBouUxHh5gzZYwhQpZt5ozrqhhq74wHh8YyMyuLCB7jRssBn	28	108	s1_0X-6psU03VdBQDjNKGmO8djk2U3z8YCQMiIJQcAk=	1	1	171	77	{5,7,5,3,6,5,5,6,3,5,5}	23166005000061388	jx5TrwnjZSXVkeseXL61aK5ZxvFJ6Ljg631wLv1NcoyFt8SeJWn	127	177	177	1	\N	1708499349000	canonical
168	3NLTSMbNTQ1pRSWk9NAwyLeeGxJy9Y9YWeN4jXFYiFYS1H3oF1oK	167	3NKKxP9htp59qi7DFPrk1yXdeqjb4rwZ1rXmLEHGB9VR8kwRCEXk	168	167	LNFDPVqmebaxgUEQG9WfNi2q4BqJ0ntKhFCR0mncqg8=	1	1	169	77	{5,7,5,1,6,5,5,6,3,5,5}	23166005000061388	jwkEXVCf3Hx13SYZfuutGikYk7kTjLu9isFtZWV46SiTk9gHRZX	125	175	175	1	\N	1708498989000	canonical
200	3NLKgKNww6HW4TEPCMhqWmuW9jJHeqLx7Looif7FfafhSZ4ntEek	199	3NKbB6VFotiM1w4RdwFEjzYoZeLYhYZ9PmV8bhHZbiKgQjEYfjmB	168	167	x1Rr974AfWFIbThMTKmg5nkNhd3StMLb1xMXvHE2yQ4=	1	1	201	77	{5,7,5,6,3,3,4,6,3,5,5}	23166005000061388	jxtte82i3LCMS8R4AwyiaPdAVuLdWYBZ7Hceet8FxmdDupNUWED	146	208	208	1	\N	1708504929000	orphaned
202	3NKfZUaritxNVEz6esY4iiLPwm1HUZ7dhKVsXwRuav2fcUc7Btbp	201	3NLN99bdi63h9JNnjRnmy1p7vCjJGNe23BqBrgSqGUBUWJtXqaN4	28	108	VTmOQeANCY6U-Fbg0lwAkAi5nWSUAtg0SLmAuwOFGwY=	1	1	203	77	{5,7,5,6,3,3,4,7,3,5,5}	23166005000061388	jwfZSiZCr7X8MwC48qLHcGbrNYq8trHa6Q62a2bzKzYRCap1w9J	147	209	209	1	\N	1708505109000	orphaned
206	3NLyQWJwzFTTv6wYAZABwkch5UJxSk4cVLm29i1vyeLpr7mH9SL4	204	3NK5op5VwhtwS3qJuyPe7T7SjgTvLiYzPttCnFin6w2CpWK3P6XY	168	167	8DDnHcTkLoUXo-C-eQwF1wwwEnW7EE-NJfnvq_0MsAs=	1	1	207	77	{5,7,5,6,3,3,4,7,2,5,5}	23166005000061388	jx83FtYhzpuxNdZ8gxkjkPe3gstMRdvazybKPFPJQiuDmdrB6g3	149	212	212	1	\N	1708505649000	orphaned
187	3NKkVZHu6uupDZ6ScBjevfssMUxfxahZADfCrRu63jQ733CtF5qW	186	3NKaH48tPQNTeBCNhKUEVR3DqPdg6p6hRuGX9FXVktWBuj9nFzLY	168	167	KjNLhhk-6Ne5zpiyqX3ky7JEHQOtEyPrtkp7fq51Ygw=	1	1	188	77	{5,7,5,6,3,3,2,6,3,5,5}	23166005000061388	jwt4hASazoeUagLuBabUNSVJcUnrmuHxc5EHtWJ7f5b2noncxBc	138	197	197	1	\N	1708502949000	orphaned
189	3NKbKKCctrKv5nkJJ4XSSTA3zL9e5yLrTddhK1H5d28AQuTPb5LH	188	3NLYis15CYedj5CCRihGLd1wMo3iFqgNj2edzJLQe9wbospdj47c	28	108	kF9tF-I6vzSXj_bjkWoCCMaNwsNF4wPO1YXlF7aaYAk=	1	1	190	77	{5,7,5,6,3,3,3,6,3,5,5}	23166005000061388	jwYFYM6r3kP5NmSbN8RG3J4tX4YfG8ZmiEeia7iTAWPwGSc14kU	139	198	198	1	\N	1708503129000	orphaned
193	3NLNbSKcMnWv3ecr5RVUa7676W7VyZGr6KiBo1zJ2EkExPqW5SVd	191	3NKvEpg9DK8AqMLsRX9KwVxiXJFvwZWLBo5aypXsdDeq5Ja1EBhL	168	167	7qVZizFmwCyIm9CeWU-S26YX9je_eo2m6DPd3m8cvAM=	1	1	194	77	{5,7,5,6,3,3,4,1,3,5,5}	23166005000061388	jxFZLZPs1Se56XcU9LsrBfVuVaonDA84L5fKiZLtPs2Wyyp1SAz	141	203	203	1	\N	1708504029000	orphaned
195	3NLpuPAEgQU1PKGnkiVK7VkN7NJNhuoBEeRRdUVw5wScyXGUgpap	194	3NL2PGUSfZaq3M5g8QYrXGFSvhR5eVq963bme2DSZawN8kYcx6gz	168	167	I5BSopRUOmM0zzM82iB3yIy5dfkW1q3wt7clHZIjmww=	1	1	196	77	{5,7,5,6,3,3,4,3,3,5,5}	23166005000061388	jxpnrUkNEVnmfzpzw4Wn13Xbuhid1UjX96u2ENNF3M3zbgR7vRT	143	205	205	1	\N	1708504389000	orphaned
197	3NKw3jjhyzcGc1nyVjtSrXmPUzKpJNgVZmrS7TmJMSbUCvC88VmF	196	3NKFV4TEUgdmdauUgiSKbecX8qWaVySou3nEsJupQNiEmoD4ARek	168	167	DGUoAqyzUOY1mu57rFJs8mMdhQkHkJK_6-UY0JxkygQ=	1	1	198	77	{5,7,5,6,3,3,4,4,3,5,5}	23166005000061388	jwSYxiR5ceMPYfzCm9sESPZZbfpbVf5g6FG2XmbXR4dDoeG8hfa	144	206	206	1	\N	1708504569000	orphaned
204	3NK5op5VwhtwS3qJuyPe7T7SjgTvLiYzPttCnFin6w2CpWK3P6XY	203	3NLYwavy2ear9xZQvpTeC4oTFgPYkpLRKSGyiyHYw28gJJGMK1Kf	168	167	x5iFe78tXFd2Gf3tKMpCy4vPOcEXZl7_okiuAQagzAU=	1	1	205	77	{5,7,5,6,3,3,4,7,1,5,5}	23166005000061388	jxF8ZteWQkT7oZDfqDfEyuwriUNPNL87qihCspXx2VTzATe1jpg	148	211	211	1	\N	1708505469000	canonical
198	3NKpKpdKgnqu57WBSfpMEvbaT9AkrBRJgm1kvYSQYgAKuTxkiRbN	196	3NKFV4TEUgdmdauUgiSKbecX8qWaVySou3nEsJupQNiEmoD4ARek	28	108	6Cd5EXSTHAxFT-LmJmGe9vpCzYJK4mdcSTRAUcCh1wE=	1	1	199	77	{5,7,5,6,3,3,4,4,3,5,5}	23166005000061388	jxJSSkb9HYd3sniVXk39WGtoCvusdqBSWb8PnJR2M5bE1iG35Lz	144	206	206	1	\N	1708504569000	canonical
196	3NKFV4TEUgdmdauUgiSKbecX8qWaVySou3nEsJupQNiEmoD4ARek	194	3NL2PGUSfZaq3M5g8QYrXGFSvhR5eVq963bme2DSZawN8kYcx6gz	28	108	ZRjfBlMWpwiOSTQa8nSFT4FAhJMe4l8oUAmt7Pj-1QY=	1	1	197	77	{5,7,5,6,3,3,4,3,3,5,5}	23166005000061388	jwPZrbZ1Uaca7Utfksm3qJThwjuYj8DomaFNM2bPpRRGDfBYQ1h	143	205	205	1	\N	1708504389000	canonical
194	3NL2PGUSfZaq3M5g8QYrXGFSvhR5eVq963bme2DSZawN8kYcx6gz	192	3NKMSeXUpJM5wmXm8jBpAFuvrC5i6wknqDJEgYoydkLSZhgBb2xo	28	108	dHV6BNL_E6AuDTYQZxD7F5h7R2LC7sLiPwk3Rmap0gg=	1	1	195	77	{5,7,5,6,3,3,4,2,3,5,5}	23166005000061388	jwpw8ZVm5whqT4sGQoSULAvvikb8XeotAR9uDwLgLRmJ2mbBH8Q	142	204	204	1	\N	1708504209000	canonical
191	3NKvEpg9DK8AqMLsRX9KwVxiXJFvwZWLBo5aypXsdDeq5Ja1EBhL	190	3NKm87s5oKWBEsHaUjEbQwwS9YPAsQBUZ9jt6zA2JpDdkxeNXqa6	168	167	Iu9zl-LW7MlOnTPMhOHCGLzAY6iSgonQXbWRng77wAE=	1	1	192	77	{5,7,5,6,3,3,4,6,3,5,5}	23166005000061388	jwT1FcL4L4mUiB5drS4Mvt1gebf3yrETrr4pWCHkYbcwGuLGSgq	140	202	202	1	\N	1708503849000	canonical
185	3NL7m5C9MdKKACxM75L9KQnGDbFVWT1cNsZseUA22Nfo12muRLYH	184	3NLukGpZoz5cHVXbwrKsqanJXyQrJ4NxgmqLFuZsBYHUaoePjpzB	28	108	4f7UgaEE2lQr6WDX6p1ztk3OE6DnOwrmuws18qlkwQo=	1	1	186	77	{5,7,5,6,3,3,5,6,3,5,5}	23166005000061388	jwLcgDjDzbaJ9jUFa6YU3LcncbAKMEpMCrM2FgYnuKseXp73VBL	136	194	194	1	\N	1708502409000	canonical
183	3NLczS9PiUzSLBPHEQmkdvHMrY8zv8Kei77y964hoxcAQryV7PWy	181	3NKEfDzwiHVeabaVAJzQNSQXWZbypGjmdpFbQg8NiwtBHQtzYenq	168	167	v1v671u_5iDpwvjO10C_FF1_-5ojCIV9YQmq-d38TAw=	1	1	184	77	{5,7,5,6,3,1,5,6,3,5,5}	23166005000061388	jw8Qu7fHNWQAYTtb6AHb4RuDrRrRqteQ3TeegFBZtfoQQEyRHJ9	134	190	190	1	\N	1708501689000	canonical
181	3NKEfDzwiHVeabaVAJzQNSQXWZbypGjmdpFbQg8NiwtBHQtzYenq	180	3NKFSy3bp7PfVdDQxUJ7yFoTx8ukjuL7JjvA7axrrGxzKALQLSg1	28	108	iSTCcnx67aeYb0J7oaXwaWAC8IQZJvsZcknf91S7hAA=	1	1	182	77	{5,7,5,6,3,5,5,6,3,5,5}	23166005000061388	jxcrpeAEV1c8XEiAnJjGfy4hR9ai4oT3CdodDSxtNpDmkyqmVxJ	133	186	186	1	\N	1708500969000	canonical
205	3NL4gJ8V2ZRkQBUgcYWYo2G2xGPbwRC7m92GK1b51crpHz65edEG	203	3NLYwavy2ear9xZQvpTeC4oTFgPYkpLRKSGyiyHYw28gJJGMK1Kf	28	108	zsvIgWRyxqkZTLRFKuNb1FzpsyBhUztI-1gCUq-WWgs=	1	1	206	77	{5,7,5,6,3,3,4,7,1,5,5}	23166005000061388	jwJcLeRmByjai4fRL86aRreMU9VX5T6zDyB6PqXsnAbwB3Wh1ty	148	211	211	1	\N	1708505469000	orphaned
207	3NLuwj585psjwAw3bvg2Nthp4mh613joNkUsCn6VkuXzYF1oZjoy	206	3NLyQWJwzFTTv6wYAZABwkch5UJxSk4cVLm29i1vyeLpr7mH9SL4	168	167	c9UO0k40Xy0NLIoSg5Ydc1oJZvPXQNlQS2cTyMMLOA8=	1	1	208	77	{5,7,5,6,3,3,4,7,3,5,5}	23166005000061388	jw7tt1WtRmezeCXjNeHfdR2r8fhwfT5zzNKisbDQSrGnM7aeTHs	150	213	213	1	\N	1708505829000	orphaned
208	3NLbZ28M72eewCxYUCE3CwQo5c7wPzoiGcNC5Bbe8oEnrutXtZt9	206	3NLyQWJwzFTTv6wYAZABwkch5UJxSk4cVLm29i1vyeLpr7mH9SL4	28	108	gArqEF4L0ZAJumzoTbtMXyqp-ZqbwrtOF4LPWxnu9Aw=	1	1	209	77	{5,7,5,6,3,3,4,7,3,5,5}	23166005000061388	jwopnJfwUpK7Z5aNK6dzSriZW7yNcW8WG4UJx4sE2qW34XymnAa	150	213	213	1	\N	1708505829000	canonical
203	3NLYwavy2ear9xZQvpTeC4oTFgPYkpLRKSGyiyHYw28gJJGMK1Kf	201	3NLN99bdi63h9JNnjRnmy1p7vCjJGNe23BqBrgSqGUBUWJtXqaN4	168	167	uvQwAubBkSwf0fFxZDVf0-zmoAq54-CX6sB3k3-XJQY=	1	1	204	77	{5,7,5,6,3,3,4,7,3,5,5}	23166005000061388	jy2BMw9LFgEirob2xz7fFvZTCLiJRT1GT5Qw8z3mbXGHVnADBL4	147	209	209	1	\N	1708505109000	canonical
201	3NLN99bdi63h9JNnjRnmy1p7vCjJGNe23BqBrgSqGUBUWJtXqaN4	199	3NKbB6VFotiM1w4RdwFEjzYoZeLYhYZ9PmV8bhHZbiKgQjEYfjmB	28	108	xCqLKjeSOtFznctg4LWdpPNgVWTixAFRZ9HPpLsn9ww=	1	1	202	77	{5,7,5,6,3,3,4,6,3,5,5}	23166005000061388	jxGUxALukvh1LfkD5wDm7twvp8ojyaU2dpNkePB3mwGTNskPEnh	146	208	208	1	\N	1708504929000	canonical
199	3NKbB6VFotiM1w4RdwFEjzYoZeLYhYZ9PmV8bhHZbiKgQjEYfjmB	198	3NKpKpdKgnqu57WBSfpMEvbaT9AkrBRJgm1kvYSQYgAKuTxkiRbN	28	108	iHsbn297nKZkfl0NxBpnatvwQNw9-ezZjkx6dWdgkgI=	1	1	200	77	{5,7,5,6,3,3,4,5,3,5,5}	23166005000061388	jxhBx4JUMzo1kx5xUMV4m5ijNBd1Wab4nR43gjUXhfLKG1xzoVs	145	207	207	1	\N	1708504749000	canonical
192	3NKMSeXUpJM5wmXm8jBpAFuvrC5i6wknqDJEgYoydkLSZhgBb2xo	191	3NKvEpg9DK8AqMLsRX9KwVxiXJFvwZWLBo5aypXsdDeq5Ja1EBhL	28	108	NxHBIgzYQcrW-eWnu9aWds5gYwycG57ygAGEsoUcLQk=	1	1	193	77	{5,7,5,6,3,3,4,1,3,5,5}	23166005000061388	jwDbK6KYMncNSiBSGMFHsgdZjLr4xDR9dH3oY6qNzoaEAEMVabz	141	203	203	1	\N	1708504029000	canonical
164	3NLMV8zkn7bYRzsRyvYGEDz8SmNQWFM9ew7WNFNFuTJwLBh9Wq9Y	162	3NLQWPAnWNR2xALL13oF5Ntr1tTY3yvoVWV1wxdtJWvtJnkYELt4	28	108	nux6SBeWo0G5iuIv4KCUr1Aw4wGe-iy9Z0q-0sAMzgQ=	1	1	165	77	{5,7,3,5,6,5,5,6,3,5,5}	23166005000061388	jxmmPCwqCp3bXd1ax9qJPyLbCvFggbw3Q67Vtr3zMoifm7QpYUW	122	172	172	1	\N	1708498449000	canonical
153	3NL9hvVRoAQTy9xTrW1F5oi4rLC2SLDb4eRwf4hjW8tSkjhYQpid	151	3NLQq1WwT1nXS1dLCNVTNZE8aiXG5SzRaqjMZkt7URsBSdBoAA35	168	167	SqGPl17FXf-5XOXqmvsoT_SuHoe-sff-xbZbOgpNCwQ=	1	1	154	77	{5,3,5,5,6,5,5,6,3,5,5}	23166005000061388	jx7gHX5kgvEXqLuTwgDfjwAqpnTbwDVtg8B68kum1mpU4vwR3J2	115	163	163	1	\N	1708496829000	canonical
131	3NLJ6M7u5qHyw7HM3pAf8bYFmMAooaLBsbhxWTkXm6D8uErwkgxn	129	3NLGHdRBBeMifiWzdaaaA16hLbNSRrcVC4bi2uu9tNeHAo2GLdkq	28	108	W8POaGHMSXDr21Y3EWdZSt7OQulUQ0wTf17OIR4CkQY=	1	1	132	77	{6,4,5,5,6,5,5,6,1,4,6}	23166005000061388	jwRk1kTowxH56rvNrQ527Xu5h2P9sM9HmkVqrEw6N5572YWR1A2	95	133	133	1	\N	1708491429000	canonical
110	3NKqaAoYFxABrRCvaZ6pMCDdLLfXd2E1zjCyNEsUyNCvsnREoJWq	109	3NKU6if4yJMZWbZmxwVuYkjcQxh6eQPGBL7ABwE7Mp2ZMCoRSxq9	168	167	umn3d0fQ9ykoeLHBW1SjZO76XPBnxM_RNoAa9XUhtgg=	1	1	111	77	{6,4,5,5,6,5,6,5,6,4,6}	23166005000061388	jxqzqLqAYQaqRonvjYYuYgMXQUAqwxxGR3mHuw1LqY2c7fhKQps	83	118	118	1	\N	1708488729000	canonical
99	3NKmLfbVdDw5UgTANbHLhYQFqWjLRy8qWKme7TgRqeCW1Zk8dKWG	98	3NKX12noMeXuvhXJp7xy97W1qV7jFsb92pD5KvtnY8w35BbnvCRg	28	108	u3V1lht0zx1OQANtzxSp5diQC-SIUwqguK7PAH0HVQE=	1	1	100	77	{6,4,5,5,3,3,6,5,6,4,6}	23166005000061388	jxCZHWPDB1aPKVD6EaLmvXcQ81TAwmVCy7GrXLfEgVJNNwoStvX	75	108	108	1	\N	1708486929000	canonical
3	3NL5Nn1EY1NBBQMqGTavr4ZE91eDXMJd4Mtxaz2EJUKc1uG2YTPH	2	3NKfjMBoe7SUQzqvb6dNxKVHwmQUbYTxRz8AWmHgv6dyDJugbmE2	168	167	ph15x1JSlCJUG2zD1OhGPTkWDOdgwCuqBbfF-zGkpwk=	1	1	4	77	{3,7,7,7,7,7,7,7,7,7,7}	23166005000061388	jy27C49CuQ4FMWDy3oQeNTRtWD6jsiNWCzntupMCockAuXr8Cr7	3	5	5	1	\N	1708468389000	canonical
2	3NKfjMBoe7SUQzqvb6dNxKVHwmQUbYTxRz8AWmHgv6dyDJugbmE2	1	3NL5Z5RR1SnPmbtqzGBA8qaRT6qbgaDW5t2ppx6Hrcs2vw3qspV2	190	189	ewEeQcF_TKy5sldTE_rgYyDl1Nw3GD7nVUk23lc1FAA=	1	1	3	77	{2,7,7,7,7,7,7,7,7,7,7}	23166005000061388	jwLhzTCvf5oxDryJ6JVLdqYjiU3KYBVJZcr3dv3LbBQxUVG3bRu	2	4	4	1	\N	1708468235979	canonical
79	3NL4gJ7BsAhmWVTBed1bd9xaXUfn7TXfbbVcfMWfU1KCsNUW6HvU	77	3NLL3u5k46S3qdNjWBqp7LuG39yhtv9rbyt4DJ8i2oFMfxKRZaqW	28	108	aS2xUE5Jq4Zw2H9cq8PHgfwikfRmAkm2Jk7C9K6m3gY=	1	1	80	77	{6,3,4,6,3,3,6,5,6,4,6}	23166005000061388	jwDqcFU1mWeGPam4aCUUp576ZHUWS1UoUDNVcDxxd9V2nn1cG4q	61	88	88	1	\N	1708483329000	canonical
56	3NKiAgdX3SsfA9KBMQYzkWoJV6ChAtprBzRYVC6wE2bFzHLg5hza	54	3NKyp2LGYJkGaPKsHaPtsQenAydTv6AzuTVC2Hi5SA9RxV6z3Q2L	28	108	qP97eQZcXoOvscoCBJwhXPLjec_ybaFdFXj3wUM59ws=	1	1	57	77	{4,5,4,6,3,3,6,5,6,3,7}	23166005000061388	jxEg22JCQP4gU8ra88kuJka8cnfBhSUjshQNqMexFoaocABvukN	45	68	68	1	\N	1708479729000	canonical
50	3NKPhFdBvC9gqNEYnwRqBPDVqe6646Cggecrw7tgwX8XQNKeZ6WN	49	3NLWUzjs1xXPyZkoojpH9Xpzd9oWrvdjscELPQxNG9fS9gfzB29S	168	167	gswGCt6jSxpUFi3TSFhdHzpK_dj9bKz2W6rcj24SxgE=	1	1	51	77	{4,5,4,6,3,3,6,5,6,7,7}	23166005000061388	jxSSkHMw6wqTVyFJcweXjNFEVhw3jpnBNKQspvQHVz12thsDBoT	42	62	62	1	\N	1708478649000	canonical
28	3NK9seE5QLxAovFVmdNzmg5yr7UneQvJRf3tr1tZdjK392Ha9Vhx	26	3NKDBhDWYoFoA2saZqhWu5sJ9W5GWjy597bMFPRF619XB8f5Mern	28	108	GGpWrI70JCotGqhAKouAceTbiKmpSTlZ2tBcuTnk5wQ=	1	1	29	77	{4,5,4,6,3,2,7,7,7,7,7}	23166005000061388	jxrgBmaj9bvJVaCa7TYgWAkCkTJzkU8nGnbfa1qtK6r1pbvnTHn	24	39	39	1	\N	1708474509000	canonical
\.


--
-- Data for Name: blocks_internal_commands; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.blocks_internal_commands (block_id, internal_command_id, sequence_no, secondary_sequence_no, status, failure_reason) FROM stdin;
2	1	2	0	applied	\N
2	2	3	0	applied	\N
3	3	19	0	applied	\N
3	4	20	0	applied	\N
4	3	26	0	applied	\N
4	5	27	0	applied	\N
5	6	42	0	applied	\N
5	7	43	0	applied	\N
6	3	42	0	applied	\N
6	8	43	0	applied	\N
7	9	30	0	applied	\N
7	6	33	0	applied	\N
7	10	34	0	applied	\N
8	6	30	0	applied	\N
8	11	31	0	applied	\N
9	6	25	0	applied	\N
9	12	26	0	applied	\N
10	3	42	0	applied	\N
10	8	43	0	applied	\N
11	6	42	0	applied	\N
11	7	43	0	applied	\N
12	13	20	0	applied	\N
12	3	42	0	applied	\N
12	14	43	0	applied	\N
13	3	32	0	applied	\N
13	15	33	0	applied	\N
14	3	33	0	applied	\N
14	16	34	0	applied	\N
15	17	35	0	applied	\N
15	18	42	0	applied	\N
15	19	42	0	applied	\N
15	20	43	0	applied	\N
15	21	43	1	applied	\N
16	18	42	0	applied	\N
16	19	42	0	applied	\N
16	22	43	0	applied	\N
16	23	43	1	applied	\N
17	18	32	0	applied	\N
17	24	32	0	applied	\N
17	25	33	0	applied	\N
17	26	33	1	applied	\N
18	6	33	0	applied	\N
18	27	34	0	applied	\N
19	28	6	0	applied	\N
19	18	34	0	applied	\N
19	19	34	0	applied	\N
19	29	35	0	applied	\N
19	30	35	1	applied	\N
20	18	41	0	applied	\N
20	24	41	0	applied	\N
20	31	42	0	applied	\N
20	32	42	1	applied	\N
21	18	7	0	applied	\N
21	24	7	0	applied	\N
21	33	8	0	applied	\N
21	34	8	1	applied	\N
22	18	5	0	applied	\N
22	24	5	0	applied	\N
22	35	6	0	applied	\N
22	23	6	1	applied	\N
23	18	6	0	applied	\N
23	19	6	0	applied	\N
23	36	7	0	applied	\N
23	32	7	1	applied	\N
24	18	10	0	applied	\N
24	19	10	0	applied	\N
24	37	11	0	applied	\N
24	38	11	1	applied	\N
25	18	7	0	applied	\N
25	24	7	0	applied	\N
25	39	8	0	applied	\N
25	30	8	1	applied	\N
26	18	7	0	applied	\N
26	19	7	0	applied	\N
26	40	8	0	applied	\N
26	30	8	1	applied	\N
27	41	10	0	applied	\N
27	32	10	1	applied	\N
27	18	62	0	applied	\N
27	24	62	0	applied	\N
27	42	63	0	applied	\N
27	34	63	1	applied	\N
28	43	10	0	applied	\N
28	32	10	1	applied	\N
28	18	62	0	applied	\N
28	19	62	0	applied	\N
28	44	63	0	applied	\N
28	34	63	1	applied	\N
29	18	13	0	applied	\N
29	19	13	0	applied	\N
29	45	14	0	applied	\N
29	46	14	1	applied	\N
30	18	9	0	applied	\N
30	19	9	0	applied	\N
30	47	10	0	applied	\N
30	48	10	1	applied	\N
31	18	3	0	applied	\N
31	19	3	0	applied	\N
31	49	4	0	applied	\N
31	26	4	1	applied	\N
32	18	3	0	applied	\N
32	24	3	0	applied	\N
32	50	4	0	applied	\N
32	26	4	1	applied	\N
33	18	3	0	applied	\N
33	24	3	0	applied	\N
33	51	4	0	applied	\N
33	46	4	1	applied	\N
34	18	1	0	applied	\N
34	19	1	0	applied	\N
34	52	2	0	applied	\N
34	26	2	1	applied	\N
35	18	1	0	applied	\N
35	19	1	0	applied	\N
35	52	2	0	applied	\N
35	26	2	1	applied	\N
36	18	1	0	applied	\N
36	19	1	0	applied	\N
36	52	2	0	applied	\N
36	26	2	1	applied	\N
37	18	2	0	applied	\N
37	19	2	0	applied	\N
37	53	3	0	applied	\N
37	34	3	1	applied	\N
38	18	7	0	applied	\N
38	19	7	0	applied	\N
38	40	8	0	applied	\N
38	30	8	1	applied	\N
39	18	4	0	applied	\N
39	24	4	0	applied	\N
39	54	5	0	applied	\N
39	55	5	1	applied	\N
40	18	3	0	applied	\N
40	19	3	0	applied	\N
40	56	4	0	applied	\N
40	46	4	1	applied	\N
41	18	3	0	applied	\N
41	24	3	0	applied	\N
41	51	4	0	applied	\N
41	46	4	1	applied	\N
42	57	5	0	applied	\N
42	34	5	1	applied	\N
42	18	30	0	applied	\N
42	24	30	0	applied	\N
42	58	31	0	applied	\N
42	59	31	1	applied	\N
43	18	6	0	applied	\N
43	19	6	0	applied	\N
43	60	7	0	applied	\N
43	23	7	1	applied	\N
44	18	6	0	applied	\N
44	24	6	0	applied	\N
44	61	7	0	applied	\N
44	23	7	1	applied	\N
45	18	5	0	applied	\N
45	19	5	0	applied	\N
45	62	6	0	applied	\N
45	26	6	1	applied	\N
47	18	4	0	applied	\N
47	19	4	0	applied	\N
47	64	5	0	applied	\N
47	55	5	1	applied	\N
46	18	1	0	applied	\N
46	24	1	0	applied	\N
46	63	2	0	applied	\N
46	26	2	1	applied	\N
48	18	4	0	applied	\N
48	24	4	0	applied	\N
48	54	5	0	applied	\N
48	55	5	1	applied	\N
49	18	3	0	applied	\N
49	19	3	0	applied	\N
49	56	4	0	applied	\N
49	46	4	1	applied	\N
50	18	1	0	applied	\N
50	24	1	0	applied	\N
50	63	2	0	applied	\N
50	26	2	1	applied	\N
51	18	1	0	applied	\N
51	19	1	0	applied	\N
51	52	2	0	applied	\N
51	26	2	1	applied	\N
52	18	1	0	applied	\N
52	24	1	0	applied	\N
52	63	2	0	applied	\N
52	26	2	1	applied	\N
53	18	1	0	applied	\N
53	19	1	0	applied	\N
53	52	2	0	applied	\N
53	26	2	1	applied	\N
54	18	1	0	applied	\N
54	19	1	0	applied	\N
54	52	2	0	applied	\N
54	26	2	1	applied	\N
55	18	1	0	applied	\N
55	24	1	0	applied	\N
55	63	2	0	applied	\N
55	26	2	1	applied	\N
56	18	13	0	applied	\N
56	19	13	0	applied	\N
56	65	14	0	applied	\N
56	66	14	1	applied	\N
57	18	1	0	applied	\N
57	24	1	0	applied	\N
57	63	2	0	applied	\N
57	26	2	1	applied	\N
58	18	3	0	applied	\N
58	19	3	0	applied	\N
58	56	4	0	applied	\N
58	46	4	1	applied	\N
59	18	2	0	applied	\N
59	19	2	0	applied	\N
59	53	3	0	applied	\N
59	34	3	1	applied	\N
60	18	2	0	applied	\N
60	24	2	0	applied	\N
60	67	3	0	applied	\N
60	34	3	1	applied	\N
61	18	2	0	applied	\N
61	24	2	0	applied	\N
61	67	3	0	applied	\N
61	34	3	1	applied	\N
62	18	2	0	applied	\N
62	19	2	0	applied	\N
62	53	3	0	applied	\N
62	34	3	1	applied	\N
63	18	3	0	applied	\N
63	19	3	0	applied	\N
63	56	4	0	applied	\N
63	46	4	1	applied	\N
64	18	3	0	applied	\N
64	24	3	0	applied	\N
64	51	4	0	applied	\N
64	46	4	1	applied	\N
65	18	3	0	applied	\N
65	24	3	0	applied	\N
65	51	4	0	applied	\N
65	46	4	1	applied	\N
66	18	9	0	applied	\N
66	19	9	0	applied	\N
66	47	10	0	applied	\N
66	48	10	1	applied	\N
67	18	9	0	applied	\N
67	24	9	0	applied	\N
67	68	10	0	applied	\N
67	48	10	1	applied	\N
68	69	6	0	applied	\N
68	46	6	1	applied	\N
68	6	30	0	applied	\N
68	70	31	0	applied	\N
69	18	5	0	applied	\N
69	24	5	0	applied	\N
69	71	6	0	applied	\N
69	26	6	1	applied	\N
70	18	6	0	applied	\N
70	24	6	0	applied	\N
70	72	7	0	applied	\N
70	32	7	1	applied	\N
71	18	6	0	applied	\N
71	19	6	0	applied	\N
71	36	7	0	applied	\N
71	32	7	1	applied	\N
72	18	2	0	applied	\N
72	24	2	0	applied	\N
72	67	3	0	applied	\N
72	34	3	1	applied	\N
73	18	2	0	applied	\N
73	19	2	0	applied	\N
73	53	3	0	applied	\N
73	34	3	1	applied	\N
74	18	1	0	applied	\N
74	24	1	0	applied	\N
74	63	2	0	applied	\N
74	26	2	1	applied	\N
75	18	1	0	applied	\N
75	19	1	0	applied	\N
75	52	2	0	applied	\N
75	26	2	1	applied	\N
76	18	1	0	applied	\N
76	24	1	0	applied	\N
76	63	2	0	applied	\N
76	26	2	1	applied	\N
77	18	12	0	applied	\N
77	24	12	0	applied	\N
77	73	13	0	applied	\N
77	74	13	1	applied	\N
78	18	12	0	applied	\N
78	19	12	0	applied	\N
78	75	13	0	applied	\N
78	74	13	1	applied	\N
79	18	1	0	applied	\N
79	19	1	0	applied	\N
79	52	2	0	applied	\N
79	26	2	1	applied	\N
80	18	5	0	applied	\N
80	19	5	0	applied	\N
80	76	6	0	applied	\N
80	23	6	1	applied	\N
81	18	6	0	applied	\N
81	24	6	0	applied	\N
81	72	7	0	applied	\N
81	32	7	1	applied	\N
82	18	4	0	applied	\N
82	24	4	0	applied	\N
82	54	5	0	applied	\N
82	55	5	1	applied	\N
83	18	2	0	applied	\N
83	19	2	0	applied	\N
83	53	3	0	applied	\N
83	34	3	1	applied	\N
84	18	1	0	applied	\N
84	19	1	0	applied	\N
84	52	2	0	applied	\N
84	26	2	1	applied	\N
85	18	1	0	applied	\N
85	24	1	0	applied	\N
85	63	2	0	applied	\N
85	26	2	1	applied	\N
86	18	1	0	applied	\N
86	24	1	0	applied	\N
86	63	2	0	applied	\N
86	26	2	1	applied	\N
87	18	3	0	applied	\N
87	24	3	0	applied	\N
87	51	4	0	applied	\N
87	46	4	1	applied	\N
88	18	3	0	applied	\N
88	19	3	0	applied	\N
88	56	4	0	applied	\N
88	46	4	1	applied	\N
89	18	13	0	applied	\N
89	19	13	0	applied	\N
89	65	14	0	applied	\N
89	66	14	1	applied	\N
90	18	4	0	applied	\N
90	24	4	0	applied	\N
90	54	5	0	applied	\N
90	55	5	1	applied	\N
91	18	3	0	applied	\N
91	24	3	0	applied	\N
91	51	4	0	applied	\N
91	46	4	1	applied	\N
92	18	3	0	applied	\N
92	19	3	0	applied	\N
92	56	4	0	applied	\N
92	46	4	1	applied	\N
93	57	5	0	applied	\N
93	34	5	1	applied	\N
93	18	30	0	applied	\N
93	24	30	0	applied	\N
93	77	31	0	applied	\N
94	78	5	0	applied	\N
94	34	5	1	applied	\N
94	18	30	0	applied	\N
94	19	30	0	applied	\N
94	79	31	0	applied	\N
95	18	5	0	applied	\N
95	24	5	0	applied	\N
95	71	6	0	applied	\N
95	26	6	1	applied	\N
96	18	7	0	applied	\N
96	19	7	0	applied	\N
96	40	8	0	applied	\N
96	30	8	1	applied	\N
97	18	7	0	applied	\N
97	24	7	0	applied	\N
97	39	8	0	applied	\N
97	30	8	1	applied	\N
98	18	10	0	applied	\N
98	24	10	0	applied	\N
98	80	11	0	applied	\N
98	38	11	1	applied	\N
99	18	2	0	applied	\N
99	19	2	0	applied	\N
99	53	3	0	applied	\N
99	34	3	1	applied	\N
100	18	1	0	applied	\N
100	19	1	0	applied	\N
100	52	2	0	applied	\N
100	26	2	1	applied	\N
101	18	1	0	applied	\N
101	24	1	0	applied	\N
101	63	2	0	applied	\N
101	26	2	1	applied	\N
102	18	1	0	applied	\N
102	24	1	0	applied	\N
102	63	2	0	applied	\N
102	26	2	1	applied	\N
103	18	1	0	applied	\N
103	24	1	0	applied	\N
103	63	2	0	applied	\N
103	26	2	1	applied	\N
104	18	1	0	applied	\N
104	19	1	0	applied	\N
104	52	2	0	applied	\N
104	26	2	1	applied	\N
105	18	2	0	applied	\N
105	24	2	0	applied	\N
105	67	3	0	applied	\N
105	34	3	1	applied	\N
106	18	2	0	applied	\N
106	19	2	0	applied	\N
106	53	3	0	applied	\N
106	34	3	1	applied	\N
107	18	6	0	applied	\N
107	24	6	0	applied	\N
107	72	7	0	applied	\N
107	32	7	1	applied	\N
108	18	6	0	applied	\N
108	19	6	0	applied	\N
108	36	7	0	applied	\N
108	32	7	1	applied	\N
109	18	6	0	applied	\N
109	24	6	0	applied	\N
109	72	7	0	applied	\N
109	32	7	1	applied	\N
110	18	2	0	applied	\N
110	24	2	0	applied	\N
110	67	3	0	applied	\N
110	34	3	1	applied	\N
111	18	2	0	applied	\N
111	19	2	0	applied	\N
111	53	3	0	applied	\N
111	34	3	1	applied	\N
112	18	3	0	applied	\N
112	24	3	0	applied	\N
112	51	4	0	applied	\N
112	46	4	1	applied	\N
113	18	3	0	applied	\N
113	19	3	0	applied	\N
113	56	4	0	applied	\N
113	46	4	1	applied	\N
114	18	2	0	applied	\N
114	24	2	0	applied	\N
114	67	3	0	applied	\N
114	34	3	1	applied	\N
115	18	2	0	applied	\N
115	19	2	0	applied	\N
115	53	3	0	applied	\N
115	34	3	1	applied	\N
116	18	3	0	applied	\N
116	19	3	0	applied	\N
116	56	4	0	applied	\N
116	46	4	1	applied	\N
117	18	3	0	applied	\N
117	24	3	0	applied	\N
117	51	4	0	applied	\N
117	46	4	1	applied	\N
118	18	3	0	applied	\N
118	19	3	0	applied	\N
118	56	4	0	applied	\N
118	46	4	1	applied	\N
119	18	3	0	applied	\N
119	24	3	0	applied	\N
119	51	4	0	applied	\N
119	46	4	1	applied	\N
120	18	3	0	applied	\N
120	19	3	0	applied	\N
120	56	4	0	applied	\N
120	46	4	1	applied	\N
121	81	8	0	applied	\N
121	23	8	1	applied	\N
121	18	14	0	applied	\N
121	19	14	0	applied	\N
121	82	15	0	applied	\N
121	55	15	1	applied	\N
122	83	8	0	applied	\N
122	23	8	1	applied	\N
122	18	14	0	applied	\N
122	24	14	0	applied	\N
122	84	15	0	applied	\N
122	55	15	1	applied	\N
123	18	13	0	applied	\N
123	19	13	0	applied	\N
123	85	14	0	applied	\N
123	26	14	1	applied	\N
124	18	3	0	applied	\N
124	19	3	0	applied	\N
124	56	4	0	applied	\N
124	46	4	1	applied	\N
126	18	1	0	applied	\N
126	19	1	0	applied	\N
126	52	2	0	applied	\N
126	26	2	1	applied	\N
125	18	3	0	applied	\N
125	24	3	0	applied	\N
125	51	4	0	applied	\N
125	46	4	1	applied	\N
127	18	1	0	applied	\N
127	24	1	0	applied	\N
127	63	2	0	applied	\N
127	26	2	1	applied	\N
128	18	1	0	applied	\N
128	19	1	0	applied	\N
128	52	2	0	applied	\N
128	26	2	1	applied	\N
129	18	2	0	applied	\N
129	24	2	0	applied	\N
129	67	3	0	applied	\N
129	34	3	1	applied	\N
130	18	7	0	applied	\N
130	24	7	0	applied	\N
130	39	8	0	applied	\N
130	30	8	1	applied	\N
131	18	7	0	applied	\N
131	19	7	0	applied	\N
131	40	8	0	applied	\N
131	30	8	1	applied	\N
132	18	4	0	applied	\N
132	24	4	0	applied	\N
132	54	5	0	applied	\N
132	55	5	1	applied	\N
133	18	10	0	applied	\N
133	19	10	0	applied	\N
133	37	11	0	applied	\N
133	38	11	1	applied	\N
134	18	6	0	applied	\N
134	19	6	0	applied	\N
134	36	7	0	applied	\N
134	32	7	1	applied	\N
135	18	1	0	applied	\N
135	19	1	0	applied	\N
135	52	2	0	applied	\N
135	26	2	1	applied	\N
136	18	14	0	applied	\N
136	24	14	0	applied	\N
136	86	15	0	applied	\N
136	87	15	1	applied	\N
137	18	3	0	applied	\N
137	19	3	0	applied	\N
137	56	4	0	applied	\N
137	46	4	1	applied	\N
138	18	3	0	applied	\N
138	19	3	0	applied	\N
138	56	4	0	applied	\N
138	46	4	1	applied	\N
139	18	4	0	applied	\N
139	24	4	0	applied	\N
139	54	5	0	applied	\N
139	55	5	1	applied	\N
140	18	14	0	applied	\N
140	19	14	0	applied	\N
140	88	15	0	applied	\N
140	87	15	1	applied	\N
141	18	14	0	applied	\N
141	24	14	0	applied	\N
141	89	15	0	applied	\N
141	87	15	1	applied	\N
142	90	4	0	applied	\N
142	26	4	1	applied	\N
142	18	14	0	applied	\N
142	24	14	0	applied	\N
142	91	15	0	applied	\N
143	18	4	0	applied	\N
143	19	4	0	applied	\N
143	92	5	0	applied	\N
143	34	5	1	applied	\N
144	18	2	0	applied	\N
144	24	2	0	applied	\N
144	93	3	0	applied	\N
144	26	3	1	applied	\N
145	18	3	0	applied	\N
145	24	3	0	applied	\N
145	94	4	0	applied	\N
145	46	4	1	applied	\N
146	18	5	0	applied	\N
146	19	5	0	applied	\N
146	76	6	0	applied	\N
146	23	6	1	applied	\N
147	18	6	0	applied	\N
147	24	6	0	applied	\N
147	95	7	0	applied	\N
147	32	7	1	applied	\N
148	18	1	0	applied	\N
148	19	1	0	applied	\N
148	52	2	0	applied	\N
148	26	2	1	applied	\N
149	18	2	0	applied	\N
149	96	2	0	applied	\N
149	97	3	0	applied	\N
149	34	3	1	applied	\N
150	18	2	0	applied	\N
150	24	2	0	applied	\N
150	98	3	0	applied	\N
150	34	3	1	applied	\N
151	18	2	0	applied	\N
151	24	2	0	applied	\N
151	98	3	0	applied	\N
151	34	3	1	applied	\N
152	18	2	0	applied	\N
152	19	2	0	applied	\N
152	99	3	0	applied	\N
152	34	3	1	applied	\N
153	18	2	0	applied	\N
153	24	2	0	applied	\N
153	98	3	0	applied	\N
153	34	3	1	applied	\N
154	18	1	0	applied	\N
154	19	1	0	applied	\N
154	52	2	0	applied	\N
154	26	2	1	applied	\N
155	18	1	0	applied	\N
155	24	1	0	applied	\N
155	100	2	0	applied	\N
155	26	2	1	applied	\N
156	18	1	0	applied	\N
156	24	1	0	applied	\N
156	63	2	0	applied	\N
156	26	2	1	applied	\N
157	18	1	0	applied	\N
157	19	1	0	applied	\N
157	52	2	0	applied	\N
157	26	2	1	applied	\N
158	18	1	0	applied	\N
158	19	1	0	applied	\N
158	101	2	0	applied	\N
158	26	2	1	applied	\N
159	18	1	0	applied	\N
159	24	1	0	applied	\N
159	100	2	0	applied	\N
159	26	2	1	applied	\N
160	18	2	0	applied	\N
160	24	2	0	applied	\N
160	98	3	0	applied	\N
160	34	3	1	applied	\N
161	18	1	0	applied	\N
161	24	1	0	applied	\N
161	100	2	0	applied	\N
161	26	2	1	applied	\N
162	18	3	0	applied	\N
162	24	3	0	applied	\N
162	94	4	0	applied	\N
162	46	4	1	applied	\N
163	18	3	0	applied	\N
163	19	3	0	applied	\N
163	102	4	0	applied	\N
163	46	4	1	applied	\N
164	18	14	0	applied	\N
164	19	14	0	applied	\N
164	103	15	0	applied	\N
164	87	15	1	applied	\N
165	18	4	0	applied	\N
165	19	4	0	applied	\N
165	104	5	0	applied	\N
165	55	5	1	applied	\N
167	18	2	0	applied	\N
167	24	2	0	applied	\N
167	98	3	0	applied	\N
167	34	3	1	applied	\N
169	18	3	0	applied	\N
169	24	3	0	applied	\N
169	94	4	0	applied	\N
169	46	4	1	applied	\N
171	18	3	0	applied	\N
171	24	3	0	applied	\N
171	94	4	0	applied	\N
171	46	4	1	applied	\N
173	90	4	0	applied	\N
173	26	4	1	applied	\N
173	18	14	0	applied	\N
173	24	14	0	applied	\N
173	108	15	0	applied	\N
173	59	15	1	applied	\N
177	18	14	0	applied	\N
177	19	14	0	applied	\N
177	103	15	0	applied	\N
177	87	15	1	applied	\N
179	18	1	0	applied	\N
179	19	1	0	applied	\N
179	101	2	0	applied	\N
179	26	2	1	applied	\N
166	18	4	0	applied	\N
166	24	4	0	applied	\N
166	105	5	0	applied	\N
166	55	5	1	applied	\N
168	18	4	0	applied	\N
168	24	4	0	applied	\N
168	105	5	0	applied	\N
168	55	5	1	applied	\N
170	18	3	0	applied	\N
170	19	3	0	applied	\N
170	102	4	0	applied	\N
170	46	4	1	applied	\N
172	106	4	0	applied	\N
172	26	4	1	applied	\N
172	18	14	0	applied	\N
172	19	14	0	applied	\N
172	107	15	0	applied	\N
172	59	15	1	applied	\N
174	18	5	0	applied	\N
174	24	5	0	applied	\N
174	109	6	0	applied	\N
174	59	6	1	applied	\N
175	18	5	0	applied	\N
175	19	5	0	applied	\N
175	110	6	0	applied	\N
175	59	6	1	applied	\N
176	18	1	0	applied	\N
176	19	1	0	applied	\N
176	101	2	0	applied	\N
176	26	2	1	applied	\N
178	18	14	0	applied	\N
178	24	14	0	applied	\N
178	111	15	0	applied	\N
178	87	15	1	applied	\N
180	18	1	0	applied	\N
180	24	1	0	applied	\N
180	100	2	0	applied	\N
180	26	2	1	applied	\N
181	18	2	0	applied	\N
181	19	2	0	applied	\N
181	112	3	0	applied	\N
181	34	3	1	applied	\N
182	18	2	0	applied	\N
182	24	2	0	applied	\N
182	98	3	0	applied	\N
182	34	3	1	applied	\N
183	18	14	0	applied	\N
183	24	14	0	applied	\N
183	111	15	0	applied	\N
183	87	15	1	applied	\N
184	18	5	0	applied	\N
184	19	5	0	applied	\N
184	113	6	0	applied	\N
184	23	6	1	applied	\N
185	18	6	0	applied	\N
185	19	6	0	applied	\N
185	114	7	0	applied	\N
185	32	7	1	applied	\N
186	18	7	0	applied	\N
186	24	7	0	applied	\N
186	115	8	0	applied	\N
186	30	8	1	applied	\N
187	18	3	0	applied	\N
187	24	3	0	applied	\N
187	94	4	0	applied	\N
187	46	4	1	applied	\N
188	18	3	0	applied	\N
188	19	3	0	applied	\N
188	102	4	0	applied	\N
188	46	4	1	applied	\N
189	18	3	0	applied	\N
189	19	3	0	applied	\N
189	102	4	0	applied	\N
189	46	4	1	applied	\N
190	18	3	0	applied	\N
190	24	3	0	applied	\N
190	94	4	0	applied	\N
190	46	4	1	applied	\N
191	18	19	0	applied	\N
191	24	19	0	applied	\N
191	116	20	0	applied	\N
191	117	20	1	applied	\N
192	18	3	0	applied	\N
192	19	3	0	applied	\N
192	102	4	0	applied	\N
192	46	4	1	applied	\N
193	18	3	0	applied	\N
193	24	3	0	applied	\N
193	94	4	0	applied	\N
193	46	4	1	applied	\N
194	18	3	0	applied	\N
194	19	3	0	applied	\N
194	102	4	0	applied	\N
194	46	4	1	applied	\N
195	118	2	0	applied	\N
195	59	2	1	applied	\N
195	18	6	0	applied	\N
195	24	6	0	applied	\N
195	119	7	0	applied	\N
195	26	7	1	applied	\N
196	120	2	0	applied	\N
196	59	2	1	applied	\N
196	18	6	0	applied	\N
196	19	6	0	applied	\N
196	121	7	0	applied	\N
196	26	7	1	applied	\N
197	18	4	0	applied	\N
197	24	4	0	applied	\N
197	90	5	0	applied	\N
197	26	5	1	applied	\N
198	18	4	0	applied	\N
198	19	4	0	applied	\N
198	106	5	0	applied	\N
198	26	5	1	applied	\N
199	18	1	0	applied	\N
199	19	1	0	applied	\N
199	101	2	0	applied	\N
199	26	2	1	applied	\N
200	18	2	0	applied	\N
200	24	2	0	applied	\N
200	98	3	0	applied	\N
200	34	3	1	applied	\N
201	18	2	0	applied	\N
201	19	2	0	applied	\N
201	112	3	0	applied	\N
201	34	3	1	applied	\N
202	18	1	0	applied	\N
202	19	1	0	applied	\N
202	101	2	0	applied	\N
202	26	2	1	applied	\N
203	18	1	0	applied	\N
203	24	1	0	applied	\N
203	100	2	0	applied	\N
203	26	2	1	applied	\N
204	18	5	0	applied	\N
204	24	5	0	applied	\N
204	122	6	0	applied	\N
204	23	6	1	applied	\N
205	18	5	0	applied	\N
205	19	5	0	applied	\N
205	113	6	0	applied	\N
205	23	6	1	applied	\N
206	18	2	0	applied	\N
206	24	2	0	applied	\N
206	98	3	0	applied	\N
206	34	3	1	applied	\N
207	18	1	0	applied	\N
207	24	1	0	applied	\N
207	100	2	0	applied	\N
207	26	2	1	applied	\N
208	18	1	0	applied	\N
208	19	1	0	applied	\N
208	101	2	0	applied	\N
208	26	2	1	applied	\N
\.


--
-- Data for Name: blocks_user_commands; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.blocks_user_commands (block_id, user_command_id, sequence_no, status, failure_reason) FROM stdin;
2	1	1	applied	\N
3	2	12	applied	\N
3	3	13	applied	\N
3	4	14	applied	\N
3	5	15	applied	\N
3	6	16	applied	\N
3	7	17	applied	\N
3	8	18	applied	\N
4	9	18	applied	\N
4	10	19	applied	\N
4	11	20	applied	\N
4	12	21	applied	\N
4	13	22	applied	\N
4	14	23	applied	\N
4	15	24	applied	\N
4	16	25	applied	\N
5	17	24	applied	\N
5	18	25	applied	\N
5	19	26	applied	\N
5	20	27	applied	\N
5	21	28	applied	\N
5	22	29	applied	\N
5	23	30	applied	\N
5	24	31	applied	\N
5	25	32	applied	\N
5	26	33	applied	\N
5	27	34	applied	\N
5	28	35	applied	\N
5	29	36	applied	\N
5	30	37	applied	\N
5	31	38	applied	\N
5	32	39	applied	\N
5	33	40	applied	\N
5	34	41	applied	\N
6	17	24	applied	\N
6	18	25	applied	\N
6	19	26	applied	\N
6	20	27	applied	\N
6	21	28	applied	\N
6	22	29	applied	\N
6	23	30	applied	\N
6	24	31	applied	\N
6	25	32	applied	\N
6	26	33	applied	\N
6	27	34	applied	\N
6	28	35	applied	\N
6	29	36	applied	\N
6	30	37	applied	\N
6	31	38	applied	\N
6	32	39	applied	\N
6	33	40	applied	\N
6	34	41	applied	\N
7	35	24	applied	\N
7	36	25	applied	\N
7	37	26	applied	\N
7	38	27	applied	\N
7	39	28	applied	\N
7	40	29	applied	\N
7	41	31	applied	\N
7	42	32	applied	\N
8	43	21	applied	\N
8	44	22	applied	\N
8	45	23	applied	\N
8	46	24	applied	\N
8	47	25	applied	\N
8	48	26	applied	\N
8	49	27	applied	\N
8	50	28	applied	\N
8	51	29	applied	\N
9	52	17	applied	\N
9	53	18	applied	\N
9	54	19	applied	\N
9	55	20	applied	\N
9	56	21	applied	\N
9	57	22	applied	\N
9	58	23	applied	\N
9	59	24	applied	\N
10	60	24	applied	\N
10	61	25	applied	\N
10	62	26	applied	\N
10	63	27	applied	\N
10	64	28	applied	\N
10	65	29	applied	\N
10	66	30	applied	\N
10	67	31	applied	\N
10	68	32	applied	\N
10	69	33	applied	\N
10	70	34	applied	\N
10	71	35	applied	\N
10	72	36	applied	\N
10	73	37	applied	\N
10	74	38	applied	\N
10	75	39	applied	\N
10	76	40	applied	\N
10	77	41	applied	\N
11	60	24	applied	\N
11	61	25	applied	\N
11	62	26	applied	\N
11	63	27	applied	\N
11	64	28	applied	\N
11	65	29	applied	\N
11	66	30	applied	\N
11	67	31	applied	\N
11	68	32	applied	\N
11	69	33	applied	\N
11	70	34	applied	\N
11	71	35	applied	\N
11	72	36	applied	\N
11	73	37	applied	\N
11	74	38	applied	\N
11	75	39	applied	\N
11	76	40	applied	\N
11	77	41	applied	\N
12	78	25	applied	\N
12	79	26	applied	\N
12	80	27	applied	\N
12	81	28	applied	\N
12	82	29	applied	\N
12	83	30	applied	\N
12	84	31	applied	\N
12	85	32	applied	\N
12	86	33	applied	\N
12	87	34	applied	\N
12	88	35	applied	\N
12	89	36	applied	\N
12	90	37	applied	\N
12	91	38	applied	\N
12	92	39	applied	\N
12	93	40	applied	\N
12	94	41	applied	\N
13	95	24	applied	\N
13	96	25	applied	\N
13	97	26	applied	\N
13	98	27	applied	\N
13	99	28	applied	\N
13	100	29	applied	\N
13	101	30	applied	\N
13	102	31	applied	\N
14	103	24	applied	\N
14	104	25	applied	\N
14	105	26	applied	\N
14	106	27	applied	\N
14	107	28	applied	\N
14	108	29	applied	\N
14	109	30	applied	\N
14	110	31	applied	\N
14	111	32	applied	\N
15	112	24	applied	\N
15	113	25	applied	\N
15	114	26	applied	\N
15	115	27	applied	\N
15	116	28	applied	\N
15	117	29	applied	\N
15	118	30	applied	\N
15	119	31	applied	\N
15	120	32	applied	\N
15	121	33	applied	\N
15	122	34	applied	\N
15	123	36	applied	\N
15	124	37	applied	\N
15	125	38	applied	\N
15	126	39	applied	\N
15	127	40	applied	\N
15	128	41	applied	\N
16	129	24	applied	\N
16	130	25	applied	\N
16	131	26	applied	\N
16	132	27	applied	\N
16	133	28	applied	\N
16	134	29	applied	\N
16	135	30	applied	\N
16	136	31	applied	\N
16	137	32	applied	\N
16	138	33	applied	\N
16	139	34	applied	\N
16	140	35	applied	\N
16	141	36	applied	\N
16	142	37	applied	\N
16	143	38	applied	\N
16	144	39	applied	\N
16	145	40	applied	\N
16	146	41	applied	\N
17	147	24	applied	\N
17	148	25	applied	\N
17	149	26	applied	\N
17	150	27	applied	\N
17	151	28	applied	\N
17	152	29	applied	\N
17	153	30	applied	\N
17	154	31	applied	\N
18	155	24	applied	\N
18	156	25	applied	\N
18	157	26	applied	\N
18	158	27	applied	\N
18	159	28	applied	\N
18	160	29	applied	\N
18	161	30	applied	\N
18	162	31	applied	\N
18	163	32	applied	\N
19	164	25	applied	\N
19	165	26	applied	\N
19	166	27	applied	\N
19	167	28	applied	\N
19	168	29	applied	\N
19	169	30	applied	\N
19	170	31	applied	\N
19	171	32	applied	\N
19	172	33	applied	\N
20	173	24	applied	\N
20	174	25	applied	\N
20	175	26	applied	\N
20	176	27	applied	\N
20	177	28	applied	\N
20	178	29	applied	\N
20	179	30	applied	\N
20	180	31	applied	\N
20	181	32	applied	\N
20	182	33	applied	\N
20	183	34	applied	\N
20	184	35	applied	\N
20	185	36	applied	\N
20	186	37	applied	\N
20	187	38	applied	\N
20	188	39	applied	\N
20	189	40	applied	\N
27	190	25	applied	\N
27	191	26	applied	\N
27	192	27	applied	\N
27	193	28	applied	\N
27	194	29	applied	\N
27	195	30	applied	\N
27	196	31	applied	\N
27	197	32	applied	\N
27	198	33	applied	\N
27	199	34	applied	\N
27	200	35	applied	\N
27	201	36	applied	\N
27	202	37	applied	\N
27	203	38	applied	\N
27	204	39	applied	\N
27	205	40	applied	\N
27	206	41	applied	\N
27	207	42	applied	\N
27	208	43	applied	\N
27	209	44	applied	\N
27	210	45	applied	\N
27	211	46	applied	\N
27	212	47	applied	\N
27	213	48	applied	\N
27	214	49	applied	\N
27	215	50	applied	\N
27	216	51	applied	\N
27	217	52	applied	\N
27	218	53	applied	\N
27	219	54	applied	\N
27	220	55	applied	\N
27	221	56	applied	\N
27	222	57	applied	\N
27	223	58	applied	\N
27	224	59	applied	\N
27	225	60	applied	\N
27	226	61	applied	\N
28	190	25	applied	\N
28	191	26	applied	\N
28	192	27	applied	\N
28	193	28	applied	\N
28	194	29	applied	\N
28	195	30	applied	\N
28	196	31	applied	\N
28	197	32	applied	\N
28	198	33	applied	\N
28	199	34	applied	\N
28	200	35	applied	\N
28	201	36	applied	\N
28	202	37	applied	\N
28	203	38	applied	\N
28	204	39	applied	\N
28	205	40	applied	\N
28	206	41	applied	\N
28	207	42	applied	\N
28	208	43	applied	\N
28	209	44	applied	\N
28	210	45	applied	\N
28	211	46	applied	\N
28	212	47	applied	\N
28	213	48	applied	\N
28	214	49	applied	\N
28	215	50	applied	\N
28	216	51	applied	\N
28	217	52	applied	\N
28	218	53	applied	\N
28	219	54	applied	\N
28	220	55	applied	\N
28	221	56	applied	\N
28	222	57	applied	\N
28	223	58	applied	\N
28	224	59	applied	\N
28	225	60	applied	\N
28	226	61	applied	\N
42	227	25	applied	\N
42	228	26	applied	\N
42	229	27	applied	\N
42	230	28	applied	\N
42	231	29	applied	\N
68	232	25	applied	\N
68	233	26	applied	\N
68	234	27	applied	\N
68	235	28	applied	\N
68	236	29	applied	\N
93	237	25	applied	\N
93	238	26	applied	\N
93	239	27	applied	\N
93	240	28	applied	\N
93	241	29	applied	\N
94	237	25	applied	\N
94	238	26	applied	\N
94	239	27	applied	\N
94	240	28	applied	\N
94	241	29	applied	\N
141	242	8	applied	\N
141	243	9	applied	\N
141	244	10	applied	\N
141	245	11	applied	\N
141	246	12	applied	\N
141	247	13	applied	\N
142	248	0	applied	\N
142	249	1	applied	\N
142	250	2	applied	\N
142	251	3	applied	\N
142	252	5	applied	\N
142	253	6	applied	\N
142	254	7	applied	\N
142	255	8	applied	\N
142	256	9	applied	\N
142	257	10	applied	\N
142	258	11	applied	\N
142	259	12	applied	\N
142	260	13	applied	\N
144	261	0	applied	\N
144	262	1	applied	\N
145	263	0	applied	\N
145	264	1	applied	\N
145	265	2	applied	\N
147	266	0	applied	\N
147	267	1	applied	\N
147	268	2	applied	\N
147	269	3	applied	\N
147	270	4	applied	\N
147	271	5	applied	\N
150	272	0	applied	\N
150	273	1	applied	\N
151	274	0	applied	\N
151	275	1	applied	\N
152	274	1	applied	\N
153	276	0	applied	\N
153	277	1	applied	\N
155	278	0	applied	\N
158	279	0	applied	\N
159	279	0	applied	\N
160	280	0	applied	\N
160	281	1	applied	\N
161	282	0	applied	\N
162	283	0	applied	\N
162	284	1	applied	\N
162	285	2	applied	\N
163	283	0	applied	\N
163	284	1	applied	\N
163	285	2	applied	\N
164	286	0	applied	\N
164	287	1	applied	\N
164	288	2	applied	\N
164	289	3	applied	\N
164	290	4	applied	\N
164	291	5	applied	\N
164	292	6	applied	\N
164	293	7	applied	\N
164	294	8	applied	\N
164	295	9	applied	\N
164	296	10	applied	\N
164	297	11	applied	\N
164	298	12	applied	\N
164	299	13	applied	\N
165	300	0	applied	\N
165	301	1	applied	\N
165	302	2	applied	\N
165	303	3	applied	\N
166	300	0	applied	\N
166	301	1	applied	\N
166	302	2	applied	\N
166	303	3	applied	\N
167	304	0	applied	\N
167	305	1	applied	\N
168	306	0	applied	\N
168	307	1	applied	\N
168	308	2	applied	\N
168	309	3	applied	\N
169	310	0	applied	\N
169	311	1	applied	\N
169	312	2	applied	\N
170	313	0	applied	\N
170	314	1	applied	\N
170	315	2	applied	\N
171	313	0	applied	\N
171	314	1	applied	\N
171	315	2	applied	\N
172	316	0	applied	\N
172	317	1	applied	\N
172	318	2	applied	\N
172	319	3	applied	\N
172	320	5	applied	\N
172	321	6	applied	\N
172	322	7	applied	\N
172	323	8	applied	\N
172	324	9	applied	\N
172	325	10	applied	\N
172	326	11	applied	\N
172	327	12	applied	\N
172	328	13	applied	\N
173	316	0	applied	\N
173	317	1	applied	\N
173	318	2	applied	\N
173	319	3	applied	\N
173	320	5	applied	\N
173	321	6	applied	\N
173	322	7	applied	\N
173	323	8	applied	\N
173	324	9	applied	\N
173	325	10	applied	\N
173	326	11	applied	\N
173	327	12	applied	\N
173	328	13	applied	\N
174	329	0	applied	\N
174	330	1	applied	\N
174	331	2	applied	\N
174	332	3	applied	\N
174	333	4	applied	\N
175	329	0	applied	\N
175	330	1	applied	\N
175	331	2	applied	\N
175	332	3	applied	\N
175	333	4	applied	\N
176	334	0	applied	\N
177	335	0	applied	\N
177	336	1	applied	\N
177	337	2	applied	\N
177	338	3	applied	\N
177	339	4	applied	\N
177	340	5	applied	\N
177	341	6	applied	\N
177	342	7	applied	\N
177	343	8	applied	\N
177	344	9	applied	\N
177	345	10	applied	\N
177	346	11	applied	\N
177	347	12	applied	\N
177	348	13	applied	\N
178	335	0	applied	\N
178	336	1	applied	\N
178	337	2	applied	\N
178	338	3	applied	\N
178	339	4	applied	\N
178	340	5	applied	\N
178	341	6	applied	\N
178	342	7	applied	\N
178	343	8	applied	\N
178	344	9	applied	\N
178	345	10	applied	\N
178	346	11	applied	\N
178	347	12	applied	\N
178	348	13	applied	\N
179	349	0	applied	\N
180	349	0	applied	\N
181	350	0	applied	\N
181	351	1	applied	\N
182	350	0	applied	\N
182	351	1	applied	\N
183	352	0	applied	\N
183	353	1	applied	\N
183	354	2	applied	\N
183	355	3	applied	\N
183	356	4	applied	\N
183	357	5	applied	\N
183	358	6	applied	\N
183	359	7	applied	\N
183	360	8	applied	\N
183	361	9	applied	\N
183	362	10	applied	\N
183	363	11	applied	\N
183	364	12	applied	\N
183	365	13	applied	\N
184	366	0	applied	\N
184	367	1	applied	\N
184	368	2	applied	\N
184	369	3	applied	\N
184	370	4	applied	\N
185	371	0	applied	\N
185	372	1	applied	\N
185	373	2	applied	\N
185	374	3	applied	\N
185	375	4	applied	\N
185	376	5	applied	\N
186	377	0	applied	\N
186	378	1	applied	\N
186	379	2	applied	\N
186	380	3	applied	\N
186	381	4	applied	\N
186	382	5	applied	\N
186	383	6	applied	\N
187	384	0	applied	\N
187	385	1	applied	\N
187	386	2	applied	\N
188	384	0	applied	\N
188	385	1	applied	\N
188	386	2	applied	\N
189	387	0	applied	\N
189	388	1	applied	\N
189	389	2	applied	\N
190	387	0	applied	\N
190	388	1	applied	\N
190	389	2	applied	\N
191	390	0	applied	\N
191	391	1	applied	\N
191	392	2	applied	\N
191	393	3	applied	\N
191	394	4	applied	\N
191	395	5	applied	\N
191	396	6	applied	\N
191	397	7	applied	\N
191	398	8	applied	\N
191	399	9	applied	\N
191	400	10	applied	\N
191	401	11	applied	\N
191	402	12	applied	\N
191	403	13	applied	\N
191	404	14	applied	\N
191	405	15	applied	\N
191	406	16	applied	\N
191	407	17	applied	\N
191	408	18	applied	\N
192	409	0	applied	\N
192	410	1	applied	\N
192	411	2	applied	\N
193	409	0	applied	\N
193	410	1	applied	\N
193	411	2	applied	\N
194	412	0	applied	\N
194	413	1	applied	\N
194	414	2	applied	\N
195	415	0	applied	\N
195	416	1	applied	\N
195	417	3	applied	\N
195	418	4	applied	\N
195	419	5	applied	\N
196	415	0	applied	\N
196	416	1	applied	\N
196	417	3	applied	\N
196	418	4	applied	\N
196	419	5	applied	\N
198	420	0	applied	\N
198	421	1	applied	\N
198	422	2	applied	\N
198	423	3	applied	\N
200	425	0	applied	\N
200	426	1	applied	\N
197	420	0	applied	\N
197	421	1	applied	\N
197	422	2	applied	\N
197	423	3	applied	\N
199	424	0	applied	\N
201	425	0	applied	\N
201	426	1	applied	\N
202	427	0	applied	\N
203	427	0	applied	\N
204	428	0	applied	\N
204	429	1	applied	\N
204	430	2	applied	\N
204	431	3	applied	\N
204	432	4	applied	\N
205	428	0	applied	\N
205	429	1	applied	\N
205	430	2	applied	\N
205	431	3	applied	\N
205	432	4	applied	\N
206	433	0	applied	\N
206	434	1	applied	\N
207	435	0	applied	\N
208	435	0	applied	\N
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
4	14	0	failed	{3,2}
4	15	1	failed	{4}
4	16	2	failed	{3,2}
4	17	3	failed	{4}
4	18	4	failed	{3,2}
4	19	5	failed	{4}
4	20	6	failed	{3,2}
4	21	7	failed	{4}
4	22	8	failed	{3,2}
4	23	9	failed	{4}
4	24	10	failed	{3,2}
4	25	11	failed	{4}
4	26	12	failed	{3,2}
4	27	13	failed	{4}
4	28	14	failed	{3,2}
4	29	15	failed	{4}
4	30	16	failed	{3,2}
4	31	17	failed	{4}
5	32	0	failed	{3,2}
5	33	1	failed	{4}
5	34	2	failed	{3,2}
5	35	3	failed	{4}
5	36	4	failed	{3,2}
5	37	5	failed	{4}
5	38	6	failed	{3,2}
5	39	7	failed	{4}
5	40	8	failed	{3,2}
5	41	9	failed	{4}
5	42	10	failed	{3,2}
5	43	11	failed	{4}
5	44	12	failed	{3,2}
5	45	13	failed	{4}
5	46	14	failed	{3,2}
5	47	15	failed	{4}
5	48	16	failed	{3,2}
5	49	17	failed	{4}
5	50	18	failed	{3,2}
5	51	19	failed	{4}
5	52	20	failed	{3,2}
5	53	21	failed	{4}
5	54	22	failed	{3,2}
5	55	23	failed	{4}
6	32	0	failed	{3,2}
6	33	1	failed	{4}
6	34	2	failed	{3,2}
6	35	3	failed	{4}
6	36	4	failed	{3,2}
6	37	5	failed	{4}
6	38	6	failed	{3,2}
6	39	7	failed	{4}
6	40	8	failed	{3,2}
6	41	9	failed	{4}
6	42	10	failed	{3,2}
6	43	11	failed	{4}
6	44	12	failed	{3,2}
6	45	13	failed	{4}
6	46	14	failed	{3,2}
6	47	15	failed	{4}
6	48	16	failed	{3,2}
6	49	17	failed	{4}
6	50	18	failed	{3,2}
6	51	19	failed	{4}
6	52	20	failed	{3,2}
6	53	21	failed	{4}
6	54	22	failed	{3,2}
6	55	23	failed	{4}
7	56	0	failed	{3,2}
7	57	1	failed	{4}
7	58	2	failed	{3,2}
7	59	3	failed	{4}
7	60	4	failed	{3,2}
7	61	5	failed	{4}
7	62	6	failed	{3,2}
7	63	7	failed	{4}
7	64	8	failed	{3,2}
7	65	9	failed	{4}
7	66	10	failed	{3,2}
7	67	11	failed	{4}
7	68	12	failed	{3,2}
7	69	13	failed	{4}
7	70	14	failed	{3,2}
7	71	15	failed	{4}
7	72	16	failed	{3,2}
7	73	17	failed	{4}
7	74	18	failed	{3,2}
7	75	19	failed	{4}
7	76	20	failed	{3,2}
7	77	21	failed	{4}
7	78	22	failed	{3,2}
7	79	23	failed	{4}
8	80	0	failed	{3,2}
8	81	1	failed	{4}
8	82	2	failed	{3,2}
8	83	3	failed	{4}
8	84	4	failed	{3,2}
8	85	5	failed	{4}
8	86	6	failed	{3,2}
8	87	7	failed	{4}
8	88	8	failed	{3,2}
8	89	9	failed	{4}
8	90	10	failed	{3,2}
8	91	11	failed	{4}
8	92	12	failed	{3,2}
8	93	13	failed	{4}
8	94	14	failed	{3,2}
8	95	15	failed	{4}
8	96	16	failed	{3,2}
8	97	17	failed	{4}
8	98	18	failed	{3,2}
8	99	19	failed	{4}
8	100	20	failed	{3,2}
9	101	0	failed	{4}
9	102	1	failed	{3,2}
9	103	2	failed	{4}
9	104	3	failed	{3,2}
9	105	4	failed	{4}
9	106	5	failed	{3,2}
9	107	6	failed	{4}
9	108	7	failed	{3,2}
9	109	8	failed	{4}
9	110	9	failed	{3,2}
9	111	10	failed	{4}
9	112	11	failed	{3,2}
9	113	12	failed	{4}
9	114	13	failed	{3,2}
9	115	14	failed	{4}
9	116	15	failed	{3,2}
9	117	16	failed	{4}
10	118	0	failed	{3,2}
10	119	1	failed	{4}
10	120	2	failed	{3,2}
10	121	3	failed	{4}
10	122	4	failed	{3,2}
10	123	5	failed	{4}
10	124	6	failed	{3,2}
10	125	7	failed	{4}
10	126	8	failed	{3,2}
10	127	9	failed	{4}
10	128	10	failed	{3,2}
10	129	11	failed	{4}
10	130	12	failed	{3,2}
10	131	13	failed	{4}
10	132	14	failed	{3,2}
10	133	15	failed	{4}
10	134	16	failed	{3,2}
10	135	17	failed	{4}
10	136	18	failed	{3,2}
10	137	19	failed	{4}
10	138	20	failed	{3,2}
10	139	21	failed	{4}
10	140	22	failed	{3,2}
10	141	23	failed	{4}
11	118	0	failed	{3,2}
11	119	1	failed	{4}
11	120	2	failed	{3,2}
11	121	3	failed	{4}
11	122	4	failed	{3,2}
11	123	5	failed	{4}
11	124	6	failed	{3,2}
11	125	7	failed	{4}
11	126	8	failed	{3,2}
11	127	9	failed	{4}
11	128	10	failed	{3,2}
11	129	11	failed	{4}
11	130	12	failed	{3,2}
11	131	13	failed	{4}
11	132	14	failed	{3,2}
11	133	15	failed	{4}
11	134	16	failed	{3,2}
11	135	17	failed	{4}
11	136	18	failed	{3,2}
11	137	19	failed	{4}
11	138	20	failed	{3,2}
11	139	21	failed	{4}
11	140	22	failed	{3,2}
11	141	23	failed	{4}
12	142	0	failed	{3,2}
12	143	1	failed	{4}
12	144	2	failed	{3,2}
12	145	3	failed	{4}
12	146	4	failed	{3,2}
12	147	5	failed	{4}
12	148	6	failed	{3,2}
12	149	7	failed	{4}
12	150	8	failed	{3,2}
12	151	9	failed	{4}
12	152	10	failed	{3,2}
12	153	11	failed	{4}
12	154	12	failed	{3,2}
12	155	13	failed	{4}
12	156	14	failed	{3,2}
12	157	15	failed	{4}
12	158	16	failed	{3,2}
12	159	17	failed	{4}
12	160	18	failed	{3,2}
12	161	19	failed	{4}
12	162	21	failed	{3,2}
12	163	22	failed	{4}
12	164	23	failed	{3,2}
12	165	24	failed	{4}
13	166	0	failed	{3,2}
13	167	1	failed	{4}
13	168	2	failed	{3,2}
13	169	3	failed	{4}
13	170	4	failed	{3,2}
13	171	5	failed	{4}
13	172	6	failed	{3,2}
13	173	7	failed	{4}
13	174	8	failed	{3,2}
13	175	9	failed	{4}
13	176	10	failed	{3,2}
13	177	11	failed	{4}
13	178	12	failed	{3,2}
13	179	13	failed	{4}
13	180	14	failed	{3,2}
13	181	15	failed	{4}
13	182	16	failed	{3,2}
13	183	17	failed	{4}
13	184	18	failed	{3,2}
13	185	19	failed	{4}
13	186	20	failed	{3,2}
13	187	21	failed	{4}
13	188	22	failed	{3,2}
13	189	23	failed	{4}
14	190	0	failed	{3,2}
14	191	1	failed	{4}
14	192	2	failed	{3,2}
14	193	3	failed	{4}
14	194	4	failed	{3,2}
14	195	5	failed	{4}
14	196	6	failed	{3,2}
14	197	7	failed	{4}
14	198	8	failed	{3,2}
14	199	9	failed	{4}
14	200	10	failed	{3,2}
14	201	11	failed	{4}
14	202	12	failed	{3,2}
14	203	13	failed	{4}
14	204	14	failed	{3,2}
14	205	15	failed	{4}
14	206	16	failed	{3,2}
14	207	17	failed	{4}
14	208	18	failed	{3,2}
14	209	19	failed	{4}
14	210	20	failed	{3,2}
14	211	21	failed	{4}
14	212	22	failed	{3,2}
14	213	23	failed	{4}
15	214	0	failed	{3,2}
15	215	1	failed	{4}
15	216	2	failed	{3,2}
15	217	3	failed	{4}
15	218	4	failed	{3,2}
15	219	5	failed	{4}
15	220	6	failed	{3,2}
15	221	7	failed	{4}
15	222	8	failed	{3,2}
15	223	9	failed	{4}
15	224	10	failed	{3,2}
15	225	11	failed	{4}
15	226	12	failed	{3,2}
15	227	13	failed	{4}
15	228	14	failed	{3,2}
15	229	15	failed	{4}
15	230	16	failed	{3,2}
15	231	17	failed	{4}
15	232	18	failed	{3,2}
15	233	19	failed	{4}
15	234	20	failed	{3,2}
15	235	21	failed	{4}
15	236	22	failed	{3,2}
15	237	23	failed	{4}
16	238	0	failed	{3,2}
16	239	1	failed	{4}
16	240	2	failed	{3,2}
16	241	3	failed	{4}
16	242	4	failed	{3,2}
16	243	5	failed	{4}
16	244	6	failed	{3,2}
16	245	7	failed	{4}
16	246	8	failed	{3,2}
16	247	9	failed	{4}
16	248	10	failed	{3,2}
16	249	11	failed	{4}
16	250	12	failed	{3,2}
16	251	13	failed	{4}
16	252	14	failed	{3,2}
16	253	15	failed	{4}
16	254	16	failed	{3,2}
16	255	17	failed	{4}
16	256	18	failed	{3,2}
16	257	19	failed	{4}
16	258	20	failed	{3,2}
16	259	21	failed	{4}
16	260	22	failed	{3,2}
16	261	23	failed	{4}
17	262	0	failed	{3,2}
17	263	1	failed	{4}
17	264	2	failed	{3,2}
17	265	3	failed	{4}
17	266	4	failed	{3,2}
17	267	5	failed	{4}
17	268	6	failed	{3,2}
17	269	7	failed	{4}
17	270	8	failed	{3,2}
17	271	9	failed	{4}
17	272	10	failed	{3,2}
17	273	11	failed	{4}
17	274	12	failed	{3,2}
17	275	13	failed	{4}
17	276	14	failed	{3,2}
17	277	15	failed	{4}
17	278	16	failed	{3,2}
17	279	17	failed	{4}
17	280	18	failed	{3,2}
17	281	19	failed	{4}
17	282	20	failed	{3,2}
17	283	21	failed	{4}
17	284	22	failed	{3,2}
17	285	23	failed	{4}
18	286	0	failed	{3,2}
18	287	1	failed	{4}
18	288	2	failed	{3,2}
18	289	3	failed	{4}
18	290	4	failed	{3,2}
18	291	5	failed	{4}
18	292	6	failed	{3,2}
18	293	7	failed	{4}
18	294	8	failed	{3,2}
18	295	9	failed	{4}
18	296	10	failed	{3,2}
18	297	11	failed	{4}
18	298	12	failed	{3,2}
18	299	13	failed	{4}
18	300	14	failed	{3,2}
18	301	15	failed	{4}
18	302	16	failed	{3,2}
18	303	17	failed	{4}
18	304	18	failed	{3,2}
18	305	19	failed	{4}
18	306	20	failed	{3,2}
18	307	21	failed	{4}
18	308	22	failed	{3,2}
18	309	23	failed	{4}
19	310	0	failed	{3,2}
19	311	1	failed	{4}
19	312	2	failed	{3,2}
19	313	3	failed	{4}
19	314	4	failed	{3,2}
19	315	5	failed	{4}
19	316	7	failed	{3,2}
19	317	8	failed	{4}
19	318	9	failed	{3,2}
19	319	10	failed	{4}
19	320	11	failed	{3,2}
19	321	12	failed	{4}
19	322	13	failed	{3,2}
19	323	14	failed	{4}
19	324	15	failed	{3,2}
19	325	16	failed	{4}
19	326	17	failed	{3,2}
19	327	18	failed	{4}
19	328	19	failed	{3,2}
19	329	20	failed	{4}
19	330	21	failed	{3,2}
19	331	22	failed	{4}
19	332	23	failed	{3,2}
19	333	24	failed	{4}
20	334	0	failed	{3,2}
20	335	1	failed	{4}
20	336	2	failed	{3,2}
20	337	3	failed	{4}
20	338	4	failed	{3,2}
20	339	5	failed	{4}
20	340	6	failed	{3,2}
20	341	7	failed	{4}
20	342	8	failed	{3,2}
20	343	9	failed	{4}
20	344	10	failed	{3,2}
20	345	11	failed	{4}
20	346	12	failed	{3,2}
20	347	13	failed	{4}
20	348	14	failed	{3,2}
20	349	15	failed	{4}
20	350	16	failed	{3,2}
20	351	17	failed	{4}
20	352	18	failed	{3,2}
20	353	19	failed	{4}
20	354	20	failed	{3,2}
20	355	21	failed	{4}
20	356	22	failed	{3,2}
20	357	23	failed	{4}
21	358	0	failed	{3,2}
21	359	1	failed	{4}
21	360	2	failed	{3,2}
21	361	3	failed	{4}
21	362	4	failed	{3,2}
21	363	5	failed	{4}
21	364	6	failed	{3,2}
22	365	0	failed	{4}
22	366	1	failed	{3,2}
22	367	2	failed	{4}
22	368	3	failed	{3,2}
22	369	4	failed	{4}
23	370	0	failed	{3,2}
23	371	1	failed	{4}
23	372	2	failed	{3,2}
23	373	3	failed	{4}
23	374	4	failed	{3,2}
23	375	5	failed	{4}
24	376	0	failed	{3,2}
24	377	1	failed	{4}
24	378	2	failed	{3,2}
24	379	3	failed	{4}
24	380	4	failed	{3,2}
24	381	5	failed	{4}
24	382	6	failed	{3,2}
24	383	7	failed	{4}
24	384	8	failed	{3,2}
24	385	9	failed	{4}
25	386	0	failed	{3,2}
25	387	1	failed	{4}
25	388	2	failed	{3,2}
25	389	3	failed	{4}
25	390	4	failed	{3,2}
25	391	5	failed	{4}
25	392	6	failed	{3,2}
26	386	0	failed	{3,2}
26	387	1	failed	{4}
26	388	2	failed	{3,2}
26	389	3	failed	{4}
26	390	4	failed	{3,2}
26	391	5	failed	{4}
26	392	6	failed	{3,2}
27	393	0	failed	{4}
27	394	1	failed	{3,2}
27	395	2	failed	{4}
27	396	3	failed	{3,2}
27	397	4	failed	{4}
27	398	5	failed	{3,2}
27	399	6	failed	{4}
27	400	7	failed	{3,2}
27	401	8	failed	{4}
27	402	9	failed	{3,2}
27	403	11	failed	{4}
27	404	12	failed	{3,2}
27	405	13	failed	{4}
27	406	14	failed	{3,2}
27	407	15	failed	{4}
27	408	16	failed	{3,2}
27	409	17	failed	{4}
27	410	18	failed	{3,2}
27	411	19	failed	{4}
27	412	20	failed	{3,2}
27	413	21	failed	{4}
27	414	22	failed	{3,2}
27	415	23	failed	{4}
27	416	24	failed	{3,2}
28	393	0	failed	{4}
28	394	1	failed	{3,2}
28	395	2	failed	{4}
28	396	3	failed	{3,2}
28	397	4	failed	{4}
28	398	5	failed	{3,2}
28	399	6	failed	{4}
28	400	7	failed	{3,2}
28	401	8	failed	{4}
28	402	9	failed	{3,2}
28	403	11	failed	{4}
28	404	12	failed	{3,2}
28	405	13	failed	{4}
28	406	14	failed	{3,2}
28	407	15	failed	{4}
28	408	16	failed	{3,2}
28	409	17	failed	{4}
28	410	18	failed	{3,2}
28	411	19	failed	{4}
28	412	20	failed	{3,2}
28	413	21	failed	{4}
28	414	22	failed	{3,2}
28	415	23	failed	{4}
28	416	24	failed	{3,2}
29	417	0	failed	{4}
29	418	1	failed	{3,2}
29	419	2	failed	{4}
29	420	3	failed	{3,2}
29	421	4	failed	{4}
29	422	5	failed	{3,2}
29	423	6	failed	{4}
29	424	7	failed	{3,2}
29	425	8	failed	{4}
29	426	9	failed	{3,2}
29	427	10	failed	{4}
29	428	11	failed	{3,2}
29	429	12	failed	{4}
30	430	0	failed	{3,2}
30	431	1	failed	{4}
30	432	2	failed	{3,2}
30	433	3	failed	{4}
30	434	4	failed	{3,2}
30	435	5	failed	{4}
30	436	6	failed	{3,2}
30	437	7	failed	{4}
30	438	8	failed	{3,2}
31	439	0	failed	{4}
31	440	1	failed	{3,2}
31	441	2	failed	{4}
32	439	0	failed	{4}
32	440	1	failed	{3,2}
32	441	2	failed	{4}
33	442	0	failed	{3,2}
33	443	1	failed	{4}
33	444	2	failed	{3,2}
34	445	0	failed	{4}
35	446	0	failed	{3,2}
36	447	0	failed	{4}
37	448	0	failed	{3,2}
37	449	1	failed	{4}
38	450	0	failed	{3,2}
38	451	1	failed	{4}
38	452	2	failed	{3,2}
38	453	3	failed	{4}
38	454	4	failed	{3,2}
38	455	5	failed	{4}
38	456	6	failed	{3,2}
39	457	0	failed	{4}
39	458	1	failed	{3,2}
39	459	2	failed	{4}
39	460	3	failed	{3,2}
40	461	0	failed	{4}
40	462	1	failed	{3,2}
40	463	2	failed	{4}
41	461	0	failed	{4}
41	462	1	failed	{3,2}
41	463	2	failed	{4}
42	464	0	failed	{3,2}
42	465	1	failed	{4}
42	466	2	failed	{3,2}
42	467	3	failed	{4}
42	468	4	failed	{3,2}
42	469	6	failed	{4}
42	470	7	failed	{3,2}
42	471	8	failed	{4}
42	472	9	failed	{3,2}
42	473	10	failed	{4}
42	474	11	failed	{3,2}
42	475	12	failed	{4}
42	476	13	failed	{3,2}
42	477	14	failed	{4}
42	478	15	failed	{3,2}
42	479	16	failed	{4}
42	480	17	failed	{3,2}
42	481	18	failed	{4}
42	482	19	failed	{3,2}
42	483	20	failed	{4}
42	484	21	failed	{3,2}
42	485	22	failed	{4}
42	486	23	failed	{3,2}
42	487	24	failed	{4}
43	488	0	failed	{3,2}
43	489	1	failed	{4}
43	490	2	failed	{3,2}
43	491	3	failed	{4}
43	492	4	failed	{3,2}
43	493	5	failed	{4}
44	488	0	failed	{3,2}
44	489	1	failed	{4}
44	490	2	failed	{3,2}
44	491	3	failed	{4}
44	492	4	failed	{3,2}
44	493	5	failed	{4}
46	499	0	failed	{4}
48	500	0	failed	{3,2}
48	501	1	failed	{4}
48	502	2	failed	{3,2}
48	503	3	failed	{4}
45	494	0	failed	{3,2}
45	495	1	failed	{4}
45	496	2	failed	{3,2}
45	497	3	failed	{4}
45	498	4	failed	{3,2}
47	500	0	failed	{3,2}
47	501	1	failed	{4}
47	502	2	failed	{3,2}
47	503	3	failed	{4}
49	504	0	failed	{3,2}
49	505	1	failed	{4}
49	506	2	failed	{3,2}
50	507	0	failed	{4}
51	507	0	failed	{4}
52	508	0	failed	{3,2}
53	508	0	failed	{3,2}
54	509	0	failed	{4}
55	509	0	failed	{4}
56	510	0	failed	{3,2}
56	511	1	failed	{4}
56	512	2	failed	{3,2}
56	513	3	failed	{4}
56	514	4	failed	{3,2}
56	515	5	failed	{4}
56	516	6	failed	{3,2}
56	517	7	failed	{4}
56	518	8	failed	{3,2}
56	519	9	failed	{4}
56	520	10	failed	{3,2}
56	521	11	failed	{4}
56	522	12	failed	{3,2}
57	523	0	failed	{4}
58	524	0	failed	{3,2}
58	525	1	failed	{4}
58	526	2	failed	{3,2}
59	527	0	failed	{4}
59	528	1	failed	{3,2}
60	527	0	failed	{4}
60	528	1	failed	{3,2}
61	529	0	failed	{4}
61	530	1	failed	{3,2}
62	529	0	failed	{4}
62	530	1	failed	{3,2}
63	531	0	failed	{4}
63	532	1	failed	{3,2}
63	533	2	failed	{4}
64	534	0	failed	{3,2}
64	535	1	failed	{4}
64	536	2	failed	{3,2}
65	537	0	failed	{4}
65	538	1	failed	{3,2}
65	539	2	failed	{4}
66	540	0	failed	{3,2}
66	541	1	failed	{4}
66	542	2	failed	{3,2}
66	543	3	failed	{4}
66	544	4	failed	{3,2}
66	545	5	failed	{4}
66	546	6	failed	{3,2}
66	547	7	failed	{4}
66	548	8	failed	{3,2}
67	540	0	failed	{3,2}
67	541	1	failed	{4}
67	542	2	failed	{3,2}
67	543	3	failed	{4}
67	544	4	failed	{3,2}
67	545	5	failed	{4}
67	546	6	failed	{3,2}
67	547	7	failed	{4}
67	548	8	failed	{3,2}
68	549	0	failed	{4}
68	550	1	failed	{3,2}
68	551	2	failed	{4}
68	552	3	failed	{3,2}
68	553	4	failed	{4}
68	554	5	failed	{3,2}
68	555	7	failed	{4}
68	556	8	failed	{3,2}
68	557	9	failed	{4}
68	558	10	failed	{3,2}
68	559	11	failed	{4}
68	560	12	failed	{3,2}
68	561	13	failed	{4}
68	562	14	failed	{3,2}
68	563	15	failed	{4}
68	564	16	failed	{3,2}
68	565	17	failed	{4}
68	566	18	failed	{3,2}
68	567	19	failed	{4}
68	568	20	failed	{3,2}
68	569	21	failed	{4}
68	570	22	failed	{3,2}
68	571	23	failed	{4}
68	572	24	failed	{3,2}
69	573	0	failed	{4}
69	574	1	failed	{3,2}
69	575	2	failed	{4}
69	576	3	failed	{3,2}
69	577	4	failed	{4}
70	578	0	failed	{3,2}
70	579	1	failed	{4}
70	580	2	failed	{3,2}
70	581	3	failed	{4}
70	582	4	failed	{3,2}
70	583	5	failed	{4}
71	578	0	failed	{3,2}
71	579	1	failed	{4}
71	580	2	failed	{3,2}
71	581	3	failed	{4}
71	582	4	failed	{3,2}
71	583	5	failed	{4}
72	584	0	failed	{3,2}
72	585	1	failed	{4}
74	586	0	failed	{3,2}
76	587	0	failed	{4}
78	588	0	failed	{3,2}
78	589	1	failed	{4}
78	590	2	failed	{3,2}
78	591	3	failed	{4}
78	592	4	failed	{3,2}
78	593	5	failed	{4}
78	594	6	failed	{3,2}
78	595	7	failed	{4}
78	596	8	failed	{3,2}
78	597	9	failed	{4}
78	598	10	failed	{3,2}
78	599	11	failed	{4}
73	584	0	failed	{3,2}
73	585	1	failed	{4}
75	586	0	failed	{3,2}
77	588	0	failed	{3,2}
77	589	1	failed	{4}
77	590	2	failed	{3,2}
77	591	3	failed	{4}
77	592	4	failed	{3,2}
77	593	5	failed	{4}
77	594	6	failed	{3,2}
77	595	7	failed	{4}
77	596	8	failed	{3,2}
77	597	9	failed	{4}
77	598	10	failed	{3,2}
77	599	11	failed	{4}
79	600	0	failed	{3,2}
80	601	0	failed	{4}
80	602	1	failed	{3,2}
80	603	2	failed	{4}
80	604	3	failed	{3,2}
80	605	4	failed	{4}
81	601	0	failed	{4}
81	602	1	failed	{3,2}
81	603	2	failed	{4}
81	604	3	failed	{3,2}
81	605	4	failed	{4}
81	606	5	failed	{3,2}
82	607	0	failed	{4}
82	608	1	failed	{3,2}
82	609	2	failed	{4}
82	610	3	failed	{3,2}
83	611	0	failed	{4}
83	612	1	failed	{3,2}
84	613	0	failed	{4}
85	613	0	failed	{4}
86	614	0	failed	{3,2}
87	615	0	failed	{4}
87	616	1	failed	{3,2}
87	617	2	failed	{4}
88	615	0	failed	{4}
88	616	1	failed	{3,2}
88	617	2	failed	{4}
89	618	0	failed	{3,2}
89	619	1	failed	{4}
89	620	2	failed	{3,2}
89	621	3	failed	{4}
89	622	4	failed	{3,2}
89	623	5	failed	{4}
89	624	6	failed	{3,2}
89	625	7	failed	{4}
89	626	8	failed	{3,2}
89	627	9	failed	{4}
89	628	10	failed	{3,2}
89	629	11	failed	{4}
89	630	12	failed	{3,2}
90	631	0	failed	{4}
90	632	1	failed	{3,2}
90	633	2	failed	{4}
90	634	3	failed	{3,2}
91	635	0	failed	{4}
91	636	1	failed	{3,2}
91	637	2	failed	{4}
92	635	0	failed	{4}
92	636	1	failed	{3,2}
92	637	2	failed	{4}
93	638	0	failed	{3,2}
93	639	1	failed	{4}
93	640	2	failed	{3,2}
93	641	3	failed	{4}
93	642	4	failed	{3,2}
93	643	6	failed	{4}
93	644	7	failed	{3,2}
93	645	8	failed	{4}
93	646	9	failed	{3,2}
93	647	10	failed	{4}
93	648	11	failed	{3,2}
93	649	12	failed	{4}
93	650	13	failed	{3,2}
93	651	14	failed	{4}
93	652	15	failed	{3,2}
93	653	16	failed	{4}
93	654	17	failed	{3,2}
93	655	18	failed	{4}
93	656	19	failed	{3,2}
93	657	20	failed	{4}
93	658	21	failed	{3,2}
93	659	22	failed	{4}
93	660	23	failed	{3,2}
93	661	24	failed	{4}
94	638	0	failed	{3,2}
94	639	1	failed	{4}
94	640	2	failed	{3,2}
94	641	3	failed	{4}
94	642	4	failed	{3,2}
94	643	6	failed	{4}
94	644	7	failed	{3,2}
94	645	8	failed	{4}
94	646	9	failed	{3,2}
94	647	10	failed	{4}
94	648	11	failed	{3,2}
94	649	12	failed	{4}
94	650	13	failed	{3,2}
94	651	14	failed	{4}
94	652	15	failed	{3,2}
94	653	16	failed	{4}
94	654	17	failed	{3,2}
94	655	18	failed	{4}
94	656	19	failed	{3,2}
94	657	20	failed	{4}
94	658	21	failed	{3,2}
94	659	22	failed	{4}
94	660	23	failed	{3,2}
94	661	24	failed	{4}
96	667	0	failed	{4}
96	668	1	failed	{3,2}
96	669	2	failed	{4}
96	670	3	failed	{3,2}
96	671	4	failed	{4}
96	672	5	failed	{3,2}
96	673	6	failed	{4}
98	674	0	failed	{3,2}
98	675	1	failed	{4}
98	676	2	failed	{3,2}
98	677	3	failed	{4}
98	678	4	failed	{3,2}
98	679	5	failed	{4}
98	680	6	failed	{3,2}
98	681	7	failed	{4}
98	682	8	failed	{3,2}
98	683	9	failed	{4}
95	662	0	failed	{3,2}
95	663	1	failed	{4}
95	664	2	failed	{3,2}
95	665	3	failed	{4}
95	666	4	failed	{3,2}
97	667	0	failed	{4}
97	668	1	failed	{3,2}
97	669	2	failed	{4}
97	670	3	failed	{3,2}
97	671	4	failed	{4}
97	672	5	failed	{3,2}
97	673	6	failed	{4}
99	684	0	failed	{3,2}
99	685	1	failed	{4}
100	686	0	failed	{3,2}
101	686	0	failed	{3,2}
102	687	0	failed	{4}
103	688	0	failed	{3,2}
104	688	0	failed	{3,2}
105	689	0	failed	{4}
105	690	1	failed	{3,2}
106	691	0	failed	{4}
106	692	1	failed	{3,2}
107	693	0	failed	{4}
107	694	1	failed	{3,2}
107	695	2	failed	{4}
107	696	3	failed	{3,2}
107	697	4	failed	{4}
107	698	5	failed	{3,2}
108	693	0	failed	{4}
108	694	1	failed	{3,2}
108	695	2	failed	{4}
108	696	3	failed	{3,2}
108	697	4	failed	{4}
108	698	5	failed	{3,2}
109	699	0	failed	{4}
109	700	1	failed	{3,2}
109	701	2	failed	{4}
109	702	3	failed	{3,2}
109	703	4	failed	{4}
109	704	5	failed	{3,2}
110	705	0	failed	{4}
110	706	1	failed	{3,2}
111	705	0	failed	{4}
111	706	1	failed	{3,2}
112	707	0	failed	{4}
112	708	1	failed	{3,2}
112	709	2	failed	{4}
113	707	0	failed	{4}
113	708	1	failed	{3,2}
113	709	2	failed	{4}
114	710	0	failed	{3,2}
114	711	1	failed	{4}
115	710	0	failed	{3,2}
115	711	1	failed	{4}
116	712	0	failed	{3,2}
116	713	1	failed	{4}
116	714	2	failed	{3,2}
117	715	0	failed	{4}
117	716	1	failed	{3,2}
117	717	2	failed	{4}
118	715	0	failed	{4}
118	716	1	failed	{3,2}
118	717	2	failed	{4}
119	718	0	failed	{3,2}
119	719	1	failed	{4}
119	720	2	failed	{3,2}
120	718	0	failed	{3,2}
120	719	1	failed	{4}
120	720	2	failed	{3,2}
121	721	0	failed	{4}
121	722	1	failed	{3,2}
121	723	2	failed	{4}
121	724	3	failed	{3,2}
121	725	4	failed	{4}
121	726	5	failed	{3,2}
121	727	6	failed	{4}
121	728	7	failed	{3,2}
121	729	9	failed	{4}
121	730	10	failed	{3,2}
121	731	11	failed	{4}
121	732	12	failed	{3,2}
121	733	13	failed	{4}
122	721	0	failed	{4}
122	722	1	failed	{3,2}
122	723	2	failed	{4}
122	724	3	failed	{3,2}
122	725	4	failed	{4}
122	726	5	failed	{3,2}
122	727	6	failed	{4}
122	728	7	failed	{3,2}
122	729	9	failed	{4}
122	730	10	failed	{3,2}
122	731	11	failed	{4}
122	732	12	failed	{3,2}
122	733	13	failed	{4}
123	734	0	failed	{3,2}
123	735	1	failed	{4}
123	736	2	failed	{3,2}
123	737	3	failed	{4}
123	738	4	failed	{3,2}
123	739	5	failed	{4}
123	740	6	failed	{3,2}
123	741	7	failed	{4}
123	742	8	failed	{3,2}
123	743	9	failed	{4}
123	744	10	failed	{3,2}
123	745	11	failed	{4}
123	746	12	failed	{3,2}
125	747	0	failed	{4}
125	748	1	failed	{3,2}
125	749	2	failed	{4}
127	750	0	failed	{3,2}
129	752	0	failed	{3,2}
129	753	1	failed	{4}
131	754	0	failed	{3,2}
131	755	1	failed	{4}
131	756	2	failed	{3,2}
131	757	3	failed	{4}
131	758	4	failed	{3,2}
131	759	5	failed	{4}
131	760	6	failed	{3,2}
133	765	0	failed	{4}
133	766	1	failed	{3,2}
133	767	2	failed	{4}
133	768	3	failed	{3,2}
133	769	4	failed	{4}
133	770	5	failed	{3,2}
133	771	6	failed	{4}
133	772	7	failed	{3,2}
133	773	8	failed	{4}
133	774	9	failed	{3,2}
124	747	0	failed	{4}
124	748	1	failed	{3,2}
124	749	2	failed	{4}
126	750	0	failed	{3,2}
128	751	0	failed	{4}
130	754	0	failed	{3,2}
130	755	1	failed	{4}
130	756	2	failed	{3,2}
130	757	3	failed	{4}
130	758	4	failed	{3,2}
130	759	5	failed	{4}
130	760	6	failed	{3,2}
132	761	0	failed	{4}
132	762	1	failed	{3,2}
132	763	2	failed	{4}
132	764	3	failed	{3,2}
134	775	0	failed	{4}
134	776	1	failed	{3,2}
134	777	2	failed	{4}
134	778	3	failed	{3,2}
134	779	4	failed	{4}
134	780	5	failed	{3,2}
135	781	0	failed	{4}
136	782	0	failed	{3,2}
136	783	1	failed	{4}
136	784	2	failed	{3,2}
136	785	3	failed	{4}
136	786	4	failed	{3,2}
136	787	5	failed	{4}
136	788	6	failed	{3,2}
136	789	7	failed	{4}
136	790	8	failed	{3,2}
136	791	9	failed	{4}
136	792	10	failed	{3,2}
136	793	11	failed	{4}
136	794	12	failed	{3,2}
136	795	13	failed	{4}
137	796	0	failed	{3,2}
137	797	1	failed	{4}
137	798	2	failed	{3,2}
138	799	0	failed	{4}
138	800	1	failed	{3,2}
138	801	2	failed	{4}
139	802	0	failed	{3,2}
139	803	1	failed	{4}
139	804	2	failed	{3,2}
139	805	3	failed	{4}
140	806	0	failed	{3,2}
140	807	1	failed	{4}
140	808	2	failed	{3,2}
140	809	3	failed	{4}
140	810	4	failed	{3,2}
140	811	5	failed	{4}
140	812	6	failed	{3,2}
140	813	7	failed	{4}
140	814	8	failed	{3,2}
140	815	9	failed	{4}
140	816	10	failed	{3,2}
140	817	11	failed	{4}
140	818	12	failed	{3,2}
140	819	13	failed	{4}
141	806	0	failed	{3,2}
141	807	1	failed	{4}
141	808	2	failed	{3,2}
141	809	3	failed	{4}
141	810	4	failed	{3,2}
141	811	5	failed	{4}
141	812	6	failed	{3,2}
141	813	7	failed	{4}
143	814	0	failed	{3,2}
143	815	1	failed	{4}
143	816	2	failed	{3,2}
143	817	3	failed	{4}
146	818	0	failed	{3,2}
146	819	1	failed	{4}
146	820	2	failed	{3,2}
146	821	3	failed	{4}
146	822	4	failed	{3,2}
148	823	0	failed	{4}
149	824	0	failed	{3,2}
149	825	1	failed	{4}
152	826	0	failed	{3,2}
154	826	0	failed	{3,2}
156	826	0	failed	{3,2}
157	826	0	failed	{3,2}
\.


--
-- Data for Name: epoch_data; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.epoch_data (id, seed, ledger_hash_id, total_currency, start_checkpoint, lock_checkpoint, epoch_length) FROM stdin;
1	2va9BGv9JrLTtrzZttiEMDYw1Zj6a6EHzXjmP9evHDTG3oEquURA	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	1
2	2vafPBQ3zQdHUEDDnFGuiNvJz7s2MhTLJgSzQSnu5fnZavT27cms	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLAbGNyiw7uNC4c6ByC6HvDswaLswaEKYaqXjoDJeie4gpt4bTb	2
3	2vbQMUu27k3JfD1ZyUTqR26vF5mq2misSYi3VpGXtbAQ5kEUkEYV	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NL5Z5RR1SnPmbtqzGBA8qaRT6qbgaDW5t2ppx6Hrcs2vw3qspV2	3
4	2vbY2NvvMNo3bcEDG1tegXkoVPfvvHycc629pyyjb7Fbj6RfX1Ge	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKfjMBoe7SUQzqvb6dNxKVHwmQUbYTxRz8AWmHgv6dyDJugbmE2	4
5	2vbK1S4uJUQZfpU72Z3iX8L1WhQYpxjGSvgiGrQ2VnctbnCBsQ7p	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NL5Nn1EY1NBBQMqGTavr4ZE91eDXMJd4Mtxaz2EJUKc1uG2YTPH	5
6	2vbERs8189xWYyiy41SxRXCNdrkcdnKGN4uso2pDHie9Y45HSdqS	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLqMciG5yuJi1d8TqRe6JKZTRLnbCvPRi2Ur2rcdJrxsGtBU8Rr	6
7	2vaENzQSsRmUgUd1rnAo4viSfnmjGC4rEpqjTzUUhVHZa6ptLFpQ	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLqMciG5yuJi1d8TqRe6JKZTRLnbCvPRi2Ur2rcdJrxsGtBU8Rr	6
8	2vaLF37oMPKgPewNPgQjHdAqzES2CQe1hEKLZdo8xU3vF8j9eYTb	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLU5bow7DzUML7FpEqMu5qjW46d3bLuCZeBdZndAmaVWLwyfByp	7
9	2vbCubDTbTwadBtKuHuY7oNkYGdws4xRDpfwAoegYFEgcWYqXSNc	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKKiN321BqN9jw1XJXECSKZBocWsFpreGZso5TnugGA5PDMZ4T4	8
10	2vbhbRSChkZxG4f1N6vmCDGAKz6W2bZBWyXaAH4snvzNaXwgWum1	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKkuRbc1fLDkn841fE6dHxP1ctf6PdT5R1JK6TEVQ8WjcrQ8bKX	9
11	2vanV5YvNQV8XpewzGtNbVb9nt6UFBMhVBFL2gnfYY2CJLZC1ELn	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKM8xxfPnx92poaTSxaLjkGcdXHeYw4ef9wzRYo9vuBt9hewqh8	10
12	2vadCviSyNdKYLJWK1gHXuBv8pLEnS1367VkH4vD4KFFjoZNM6pT	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKM8xxfPnx92poaTSxaLjkGcdXHeYw4ef9wzRYo9vuBt9hewqh8	10
13	2vbACqmTfw4Zkwx8DHK4VhRJkxNrfuuTLHm4754ZLKeLrZUQTQAb	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKUQGtHKGohMcYBoLAqQ9vFGWx46pYXUwRqhuUsqRXN4b8vCZ5v	11
14	2vb2BFdwuuaqVmMYQu29NWGA5tucPkwYfRyk7HeD5iT8TXAV36Rp	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKxQzTtASg5WycjhiwQQ8YmCYUrsLftdeWDBnVMf3Pe3SUUCppa	12
15	2vbzm7HdyVovzzwTx1bcCrsDA3iqGjdZ7wPNkFPrCKpYB1RGUS4Q	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKhe3gKHoctj7pQGPekTVoDPETj8CZABzxK9SkPZrYX12nwiNqt	13
16	2vbfbLm63D9sAGH1RV4rGZyppGnnXmw4Dm5az7tC6K5vLCBrEZ2W	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLZKAToehEDskTR4fGCSz59k7BycyX6aMUxC4on9PAfaM3HXPHP	14
17	2vaPxprwdoZC8b6ySh9SRJuM3fPR2Qf8nqnMccb1pYjDrF2zKFgB	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLbF1JVTuykjgTyixhWHLNXV23vbiqixCBibZDqTZcaoDEnSTrf	15
18	2vb4Jzy9TFXPndyMhXqNVckQzLfxXy1F3fciXkL8fwfEntn1yUFx	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKQGgtugVERZZuDnqidQiNsz34KQiZ9f2hCAZPFoYKZaAfqmAPW	16
19	2vavAjAVBu4U9ysBGtexATKBy6x8aGDnR7CgfynewoeX4WcTVxCK	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLTuJ4Dgjwh5KZRN2WaW6hFCufFCQdX6bqy9AdeTuKggQTXkhFZ	17
20	2vbRBUSa3rbGN7fdji9M4SczHk99S7vk7nDRtXuEk4CyaBBpyzf8	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLGorz75FdT92TsqRXuf2uiR9UJUmQuZhrrCZWyK74REvTVzq5u	18
21	2vbtChPh6gLLLUVnurEexsXhYwstioaJWx2Ae4mQaQmtbDP3EV9B	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKpAtCdF2HcC4eZR6p71n1Z7LFy56kzgr5CfY9MmCLHhvds6t2w	19
22	2vaRG5SqGUqgnWc6K1g5JrjVnj4RNVLi5cn3bHfCdZQk7tH8ZD4b	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLMRezwnLdzy8oCYZmx2NMc55H7VAt8xLbSJeGpAjqom9JKxpQf	20
23	2vb1QjLxU4k9dCN4pAsugKUukAZPnRA6tRdvKvThGD9hBY9VJW9H	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKn9cT9GsJHiwftF7v1ng2ZpCK8rsswbN1EXfZNuaz33VtjNFby	21
24	2vbqY1YD8Lo9MshrMA1xX3MxHNKfZs8q6VoJkqkYzWAhS3wg568a	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKVCp2QJ2Z8izhwP9RU81pbhWATm9RF5Q2Qg8nFM7UyA7DXKdQo	22
25	2vatFSPXF1DSmVsDu9dq2wCzFZZuSQViBmggsf2fvHLPsd8u2xnQ	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKukaVGJW89v4tDh9ZPD8hP2mcsLXNr165yN7t4mCrLUCjcUZFS	23
26	2vaS5Vu4oJiKSBmWp8Nsdnyux4jQCKW3uLxnHjSCR4SGYbf6cAX1	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NL8qmh4a4Gkf5ojEw6pBAu5ngCJJJpdCriKjFeFytPHA1SYAVBe	24
27	2vaPDP9nWzFSaza6KSY2ey4UJQWNvasqXVdbVhea85QqpnkUttDU	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NL8qmh4a4Gkf5ojEw6pBAu5ngCJJJpdCriKjFeFytPHA1SYAVBe	24
28	2vbo3rbeY4Xypryii1fnW9nbPMpR6jKeGkGeBX2TjUeE6UujB4vh	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKDBhDWYoFoA2saZqhWu5sJ9W5GWjy597bMFPRF619XB8f5Mern	25
29	2vbqHcF4fTmdnTdhpQJCSseUiw6qVYrwTkh2szqPzFJG3YRnKsVU	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKDBhDWYoFoA2saZqhWu5sJ9W5GWjy597bMFPRF619XB8f5Mern	25
30	2vbNUctcTCTZweqaZLo8V6y5vfpg5wYsyqcCYh1cbUQCTDQKzGmc	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NK9seE5QLxAovFVmdNzmg5yr7UneQvJRf3tr1tZdjK392Ha9Vhx	26
31	2vaAVTCx3Kdbnp96RAaKE7h3gUtsopFypnNm4eSawKfvcFGpZroc	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NK7ANge6i3CWBXPzFZ8QWUHkH5b2wAsXMBMgHR55UWZin1HPwqT	27
32	2vbVoVnd2hv2pDMuDLtAqkyHz7e1wpcPWDzbok5WAyApAMhSm8kt	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKxD7GMAhmfpZXXkcvmzJW7KUbZXqpzm8sZLvbcPAdtHb9UxaLg	28
33	2vc1DGdmq244dCkoXSZ2T5CySAceNFVcmzo9wVbG8e3NmrMSVrmC	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKxD7GMAhmfpZXXkcvmzJW7KUbZXqpzm8sZLvbcPAdtHb9UxaLg	28
34	2vamQxV5QYbTBiFgWZsoCF4AVk8Swmif6rJ6ByL9c8PD2avgudX5	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NK2xKd9VysG2XEFFagegNFcb4cPKjwMYDq513uCNzapW1q5C2yN	29
35	2vaoaJPSxeYZKWiH1k3C7WLE3wJ5SfDsz7Zj56EoN6VoHYTQMqe7	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKTZqfpteXNtUJmoabCoNH6fNFgNhx76jxv89Hpf4eypUhix58Q	30
36	2vaDQ5Ec8wnCdsWKwVztLcDTUfjeSUAnGe4PC85Kc4fxKdQRUh2x	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKsC9gEvPiAQdnUfMCBp1ymCLom2Jq19x6VDxC6hsriWCsSKbnB	31
38	2vaokTkc1ELpxhpeKhuTZp64iDkWT26TbysafM8uhmhXai5W5wHb	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKHZLmJ3Nh5vYa9tk9Tbh7P4sxmAL5KWS8BcjuqscPSTh2DfXMP	33
40	2vbzaQyTcRfsH1hmwPCakLoj1eiq3nsiSGfAcQjjyacNo74L18aY	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NL5acvCtK1UjwkLsLZqefCSzuGzi3i4NbSmzELciDvx6wVxRQt6	35
42	2vb17QM7hgJWA9f5X5qD63DfNyW6iKA1X5PLUL2NiF21ZcJXuAnD	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKtryhJQGzZF9bfuLwwDr6BzA4smmggMFYoKX56ESM69kFZnfDy	36
44	2vaFjad7rBptwGnNtFTNuCPdyS5bFbad8WHywuotJsbNM8FzeSog	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKbfGvj4DiCq3tUZUKKvgwY8s3v4fNGA3cMEfxCe8FZn9rG7zRC	38
46	2vbCJYuBFs7wHExTmV1fR16CPx43MRBVZnyia9oxY4oQKTM7YnVL	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKgKaSMoG4JHgEM4qdmTyTtgJZ3o2uKdvMh81EKFwNaPpitP7sr	39
48	2vbkB2g3z6TY69j2n4cQGmD45MDV6EADGtpwV4kp1fTo4JcCfufa	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKmieZd7bhq4pHCUXHDFtpdHSAQm27o4K6E3Hy6TKKNX5SFusAT	41
50	2vatGx2qvSmsRvjFUHmLPwPNnb7Lp1Up6EQJgC3pnMuU8YgrBQH7	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NK7pguxD4nfwcJwkNs1eCY9in4foFfsn47jtG2AF7gBTLdGeg4e	42
37	2vaAYapgtH3xTHG1LeSAzqBVrb14it4yE9VC1wzcWBPzP88cDCs1	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLstYfLr6MJwFAGvYR2kFpAxUMBeTp2S3aSpWNDxoWoamqqDneb	32
39	2vbmUFCQYAP1DJzkS4FjBJ7CWeUHfJgWanooPMtTGaMEVstv3eM9	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKkaLEJqBDN7CzYLVQhn3bnvA559VyQrGLYrgTeYSD6gunVKdfs	34
41	2vaoWSoWLukoi8qAzory84brX6AfEDd7NayH7hktQ9Y9hNF9gibn	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKtryhJQGzZF9bfuLwwDr6BzA4smmggMFYoKX56ESM69kFZnfDy	36
43	2vbyPdf94T86jRfdnjxeHizxLT1sHT7pBRZxQU91w8qT1j9aS9vr	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLXospP1cWYfyShDdenwfKSWpZLehHrcswaVP3q9sAURoMrXtYz	37
45	2vbDu9w1nP6apRxc8t8hiwXTF7VHt4cB7zZSv9iLxx6S7BcxnSEz	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKbfGvj4DiCq3tUZUKKvgwY8s3v4fNGA3cMEfxCe8FZn9rG7zRC	38
47	2vbtni3HCGSaBdUBkTnpnaJBhdXdpzXzb4dED5STH9jgbDRZUosz	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKoLFf4o2FAUZESzoEW1PQzX723MsTH82wXN6eXsN3QQPv7H2PC	40
49	2vbeW42eH5zRXBYPwhtWz8xh7811Ft364N4TTMfXopKWf5BAECV1	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKmieZd7bhq4pHCUXHDFtpdHSAQm27o4K6E3Hy6TKKNX5SFusAT	41
51	2vayctYvKCNZeeuWwbeLZqFYRPAFwnSTtnzjycMQ3c21e1jvPMjK	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLWUzjs1xXPyZkoojpH9Xpzd9oWrvdjscELPQxNG9fS9gfzB29S	43
52	2vasifDwYPFhvWFsWPf5Beoou6igxxPj4drYUReFc1akkBYbD9Gq	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLWUzjs1xXPyZkoojpH9Xpzd9oWrvdjscELPQxNG9fS9gfzB29S	43
53	2vbjQyNQBR5iMdJUHbft78eBSxyzBnC6bmWH7yb386Xr8idxxdDA	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKPhFdBvC9gqNEYnwRqBPDVqe6646Cggecrw7tgwX8XQNKeZ6WN	44
54	2vbScYvhHM7SHuWhTMnkMXnhBvXUCEDsdaXyWi5wU7BBC734zNV5	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKPhFdBvC9gqNEYnwRqBPDVqe6646Cggecrw7tgwX8XQNKeZ6WN	44
55	2vaLzBeCN3vVR9VY6jw3MhNGFbBq9CzrU9T8jdpmeNZ1eKVCwSv7	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKnCejm5DawMBoFdFcz6wesH9xhzu1Pp1YmqSYL8ffMgnoxvpqE	45
56	2vatSTGsHkaiQ4d9rRVH8b7rZKDFMLMp1uHkJgMAy9MLbn9i1wDP	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKnCejm5DawMBoFdFcz6wesH9xhzu1Pp1YmqSYL8ffMgnoxvpqE	45
57	2vbdEmU8DkmTDmn2QSfjQLSrPFqG1PCpkLAnSxpw2ESKN6vF8oXJ	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKyp2LGYJkGaPKsHaPtsQenAydTv6AzuTVC2Hi5SA9RxV6z3Q2L	46
58	2vb7q3L4WsRNuq7wqwX5b2DXJ2dprKpzwmzK9zJrvSzYaYcuUzSD	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKiAgdX3SsfA9KBMQYzkWoJV6ChAtprBzRYVC6wE2bFzHLg5hza	47
59	2vb3gWos4cun6rC3Qgw7BuDdJ42vGo1WQeqzjGyqSHJXo7Wzzao1	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLGJ3jeuJW8pRDkvFwXgkUz44mXdjqr5d49PB3WNG2sNiR3Who8	48
60	2vaHERBLTfGy2YoyB3Djk9rHwrKAtXP7ucyjEQRCRLsmpfi8U1zt	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLRpChaguWMsaAp5Y6cE82s3amMMP9rM8vZF5YnZ6MVWPC5Lfr5	49
61	2vbV9TY21iv4ibgMhM9dNcZWra9RjoRCZKXN5jUvHdeGjqNzRSCS	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLRpChaguWMsaAp5Y6cE82s3amMMP9rM8vZF5YnZ6MVWPC5Lfr5	49
62	2vbrjDApwdB8f1D9pw7gK5oKwfEtBbw4ARAHthEUfQgnVzTgKpuD	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLv1x6e5VbXFxtYW3G69Tf2SmkrydV4QUqStJKFZySDbsVA5JkN	50
63	2vbwq3Z4y8nytj88ojpWC8nSYN1NMWTYqCVJg4oaGD85nrTesfep	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLv1x6e5VbXFxtYW3G69Tf2SmkrydV4QUqStJKFZySDbsVA5JkN	50
64	2vaCG4AtDW4TQ7YcxBi7UWtremdFivkG2jbQvrCRr883mE6WPqsb	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLYiggWGHz6WDiy2XqFcDms6A1rUn5RYvNVUUGh25rn3chUAhLs	51
65	2vbJ9ZDUGM5EyYjYadxhLy8XxZrGDZ8EkpBgaqRabpkP4FzcGW41	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLfvcJ5qhz2vbJ4go6uZbEmfR4KiBePs9Cb2PThwsCFuUCRMZ3k	52
66	2vaCyvvECiwmdaLzUGKEeJyH5hViTNdUYZTYvQoUirWfpGetaqqQ	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKahh5Ca46xWfB59Van5y5btkuPQn5WuSxNpeXgvLuLv8k2KxZY	53
67	2vb6L8FCxsNEDLTFiSCAkR15n2hPFfNtBQCqFhTMLfXU6g8SSc3N	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLCXe3PNnpPyRwzTFGi9tusfkJnLafcaMytNiRAKjwRNLf4R59M	54
68	2vb28duSTbn2PoUC8SSTY3N3agbhHEPEsYcBSJxNbpbEDvrR4xAL	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLCXe3PNnpPyRwzTFGi9tusfkJnLafcaMytNiRAKjwRNLf4R59M	54
69	2vbnJBdzMHVCnbNwDXyLNPya6Q9v52MwVYmdSvahaNo2kEu4UfzA	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLXLGm3TCQMJimxSbcZ5E6xjgEZNkjZWAdRRuaJshqqmFwCfxHp	55
70	2vbdXWsJURLWtYEwh6MBjuZ4yvpCYAS5EGyrUkKD7Nnfg116US5p	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLuzcgds4Lu3w33kqwYaA3KjJM6rtEjTAYABo8QEBRkWLWWPvEY	56
71	2vbvsVpFjp7tBsKGnRmo6KPjJT9zZdBxNAVZyMcWPpKs1ASTfn9k	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLN5M462h7MFe6mgdz9qpEkHbdvRR8L5qY3hg8NSBbq93hrbafd	57
72	2vbsFKkwL1KohrJ6umsYrY4BQuQxtE1ZNHHuQkjLjdbjNee6SybE	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLN5M462h7MFe6mgdz9qpEkHbdvRR8L5qY3hg8NSBbq93hrbafd	57
73	2vbtb9QnNoA7EmthpeyD58M4SqfAhqWcZSWxRX5m4Ed191jhuS6V	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKF8z2sHbf5XsLy4ZuUr2RztYSj832j8ujiDGDGms6WvRfmFsQ7	58
74	2vap3e7v3QkCfgqMwSoG56np9wFqsCNdfF3Ssk3WruzDwyFGnM8t	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKF8z2sHbf5XsLy4ZuUr2RztYSj832j8ujiDGDGms6WvRfmFsQ7	58
75	2vbYUk9mfTZMKkBQgYjVyCyBTiJiEGnYftAsnU2bc4xfmFV9JExh	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLijKePFfuaLQFsoiUzVftuQnksPFEUS8zfPFKCTRsehLCAuaxH	59
76	2vavdDnzKXML9wnkXKeCY51sczDdmdrZWxW7V6SMaYafHbEUDaxY	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLijKePFfuaLQFsoiUzVftuQnksPFEUS8zfPFKCTRsehLCAuaxH	59
77	2vbAuDJZGiaTXfTHvC1HFRU27u7jo1HCfwLn5XvPtaymZKpYmPiE	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKqfPmV19F4nvQ6DX86e3QTyvfP5ikhe4q53ngg176i7qtHAnVm	60
78	2vc3eTj5T882nHrVrHHtPymdcWMb9btBH2PuEYhoHm71Tz5Pqu1b	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKS7h4MJrPuVYR4YgjHbXg3AfCffmEVjKWzEVzmrYHbXow4M1Am	61
79	2vb7dtahhMkSdRixfQRjU3ZKATLK9RFRzmjPkg5D5sisRLsk7DKi	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKS7h4MJrPuVYR4YgjHbXg3AfCffmEVjKWzEVzmrYHbXow4M1Am	61
81	2vbp42aKv5oEX5vfkTBZzQus44REZADxqswVofKswjdndjjakp9V	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NL4gJ7BsAhmWVTBed1bd9xaXUfn7TXfbbVcfMWfU1KCsNUW6HvU	63
83	2vaecwh75G1cGzprkQ1nH1zjmji3YFwu3B1cQkJmoRcWJ4QM5se3	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLJYsqRYSMychHsvJh6qVCMt53pao3xtW2d35gqAXeWbTX6KQ9p	64
85	2vaN4ZSyPPLRTMQ2wSFTyJ6EN1ad5nhz4r3SSjcXqqfZFFq6nTRD	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLwcni1WxkziBdWwg8GGw9VwhA1duatYfpcj8wViuiap6Sct8aq	66
86	2vaokW8K1iaMrosc6Avn7PgjZbNY2Sk3Whbz5fBwTW3n5BqYf4nR	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLwcni1WxkziBdWwg8GGw9VwhA1duatYfpcj8wViuiap6Sct8aq	66
87	2vbamdXGgW51Wr2PukNDRx67b6HHrA6sDJVnNHUtQEhikEExr7oV	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLuSXxbCph21QERx4GqJSQ7npXun2KWUUP6K1snmCtZjeGWTrFL	67
91	2vbfHcVLt5FFWub9iBdoZG2xFvfUcBgPj3NADbTszGoEMdbnfEQf	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLvVA2i4AgXhoH8FXg5LzMKRXsza9BFDyFQyrgaEvh8m6U3NnJ6	70
95	2vak5mCRZfq5DMDtvFcE3aDy4objFN3TuTWnoa8Mbsh8woMetXgD	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NK33Z1gS9b81TgRv75md1KgQRb3DQ2HpkWUhjbc4Mc9jcv6wAmw	72
97	2vbvo6TNfCxsbifkzACBQb48qgwKRZ3HfeYhsAGHVpetyBa2bUVz	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLKCsMK6YTp3LWseV6nt9MQxHS9XUmEiKbswQWjoSr8RRcMnc8A	74
99	2vazBqdCT7pT6BkQm734Hi4hsAHzEuAP88HezFF4Pb2cUeC6BCKK	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NK5hcnNPvUTYkBuHXiFD9YoncC9TxWzr5GyEtjiT8TSo3CJn95t	75
101	2vbzDgVJWivaomSneK7D4L6JwAWeZJEPFS614xTzkZf5bEd8pkre	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKmLfbVdDw5UgTANbHLhYQFqWjLRy8qWKme7TgRqeCW1Zk8dKWG	77
103	2vaz32ipZZ2KGRDUgjnSnGUhViKjugiCqiBgXLy9TEH8FwffwbcX	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKN23ztkYLfpSGmg3HyZHTH1VBYXUxYoRR8aWpuDzA9R88dpcjm	78
105	2vaLUpnGPYZ22viQ5PxBQrgENooqjCzSGDsZd46iFfz89j6J7reA	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKULg6fRnF2mrEfzhK3iiFwAiB7fq3fsmPEXPKEKCYxCi7XWu2S	79
107	2vaDXoG3Pv9uMb417mXvvDF4FDAF2LCJixnoU6rHp8QDMBYqX5nz	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLHnGsen9XAWSp5CdQiYPwPWZySWyGuQ1UPwbTbcLKQUkAg2Cjw	81
109	2vba13kdbKcGLQdzvYwmGWL2NoVf8nMUKA6LYCUYruh8d5WUDwiX	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NL25Cap5umgDDVFffsMJ2wiMxcmMvmWgeHsmAG9rz7xQCwNWD1t	82
80	2vbB6KgPy3B6X29cEY3xKXC7eFXA14Ds8cY8NRgxUWJme9sJFrBA	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLL3u5k46S3qdNjWBqp7LuG39yhtv9rbyt4DJ8i2oFMfxKRZaqW	62
82	2vbZrq8XYLSgJY59GrerP7pJnErV3TSiL6cEVZLhFkYiCcWEVr1c	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NL4gJ7BsAhmWVTBed1bd9xaXUfn7TXfbbVcfMWfU1KCsNUW6HvU	63
84	2vaFvsEUKcvPXTjKg7jfKK2xDsn36p3LydRvs5AoWgExmPkPvS5S	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLDBeMtRCGFh2w8nnGesDkQ2U6GiW4iS1L5z3Wjx2omtuEa6ZL9	65
88	2vbB2yPJnHx7vWsNP5g1FH9eFyabstrZ4m9KKBJ7iWMEwpfsyxxV	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLPyPHKcWomLLVKXAga8rUWPdAex8oQz4Jm89oz7ZDBVihERSXo	68
89	2vbuYHdLrHN26koMEVM2ntKMyzqiF8VAFZdLwLKeukmCcrtwm1Rm	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLPyPHKcWomLLVKXAga8rUWPdAex8oQz4Jm89oz7ZDBVihERSXo	68
90	2vbJo1h5UH1LnodEn71McVZqHQ8Hi31pMRKLXZbtDotzfNdLTPzp	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKSAPUXL8WNFqc6k3og9z9gS6fS5XqSF53wZgSYSCCcfPgN6VZT	69
92	2vaU7hppAXaBbvDE1zHmLq1faYnAKuvNJjq8SFjLg8X23E9NNLzb	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLEy8KHUMC3A5YbQdWgrQMMFYgLaf8JHoC7fK7a7hQuSAAbaC7G	71
93	2vaazHEcVoG4a8UbT2aW9sisZc5b7q5Ndwqw93jgPzweXQtuo5aN	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLEy8KHUMC3A5YbQdWgrQMMFYgLaf8JHoC7fK7a7hQuSAAbaC7G	71
94	2vbdzmyGVtdHJpSQJdgq7bgyuLWRw369oZQge3vFsHueJXGRHAPc	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NK33Z1gS9b81TgRv75md1KgQRb3DQ2HpkWUhjbc4Mc9jcv6wAmw	72
96	2vbMjbwrRqwgBUX7VbK3rt8sthWcqGfEKkaSbCa5RQA3ywCvhDx8	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLY2iRiJQzpZzUqcFKWT849tv8Cgz8MkefqyScNoWGEZdC71Vrx	73
98	2vbsLxu7a4uGbg7UA1f2r82T9CZKYmLTGP55J6VqUk4Upj3RQQcD	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLKCsMK6YTp3LWseV6nt9MQxHS9XUmEiKbswQWjoSr8RRcMnc8A	74
100	2vbcxYQuU5AQ2GU8PWJvszd6FjfcDe95rdrJFfCv45MUhkMYVmNb	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKX12noMeXuvhXJp7xy97W1qV7jFsb92pD5KvtnY8w35BbnvCRg	76
102	2vbuHyjrqrZeTG6P3uwMcC27X3fnehSv1wedZ6UBpwwzpVxLmtEJ	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKmLfbVdDw5UgTANbHLhYQFqWjLRy8qWKme7TgRqeCW1Zk8dKWG	77
104	2vaFTYtSY9iYGfpCjSRt72uPiJ18Sv4Y6AtF2YEYDMAH8KqQndL4	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKULg6fRnF2mrEfzhK3iiFwAiB7fq3fsmPEXPKEKCYxCi7XWu2S	79
106	2vbqjNQHYPnZ3YSsaoSQcsDmsL2V2B4xXQkR5u5hi99KBi1pUDMH	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKDipmjrwPdJ83zKjKF3tActw5w93sj4tKDNutGy5dopXG4efoa	80
108	2vbg9Npmb8NwWyo9Y1r5bdM6aQERQvprQUxAfZoGDtPbpDdfXPia	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NL25Cap5umgDDVFffsMJ2wiMxcmMvmWgeHsmAG9rz7xQCwNWD1t	82
110	2vbPE81FTcWzRdJd9RXvo3hA1p8ruVzgUv9RpgWpfVXLrQgmSRpF	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLehyST2WYNNYRp5khDgLGHijhxAwaifX4zAi2thedYm6XvgqiV	83
111	2vb4m3Yr4uxEmVsfXCzmojgs58xrJPGzTu5nyjnCxgxkbghMFrhb	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKU6if4yJMZWbZmxwVuYkjcQxh6eQPGBL7ABwE7Mp2ZMCoRSxq9	84
112	2vbjasZYosemU1Hab9HzZx61HYtFBeyNDM9Lt7fprWoCPWBJbdnb	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKU6if4yJMZWbZmxwVuYkjcQxh6eQPGBL7ABwE7Mp2ZMCoRSxq9	84
113	2vadirS9GvcMaMdtsjsMWEqzK5aSsSsDdEuS32LLYVtDsnSzNkYF	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKqaAoYFxABrRCvaZ6pMCDdLLfXd2E1zjCyNEsUyNCvsnREoJWq	85
114	2vauTCaDJ427cQyRmpQnCt5iGXnEfEURRFG7692RktCjQ2o9NBYp	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKqaAoYFxABrRCvaZ6pMCDdLLfXd2E1zjCyNEsUyNCvsnREoJWq	85
115	2vaUgRP4pgrXkiHwZEgpwEJnZaLdkgh8696hSgtuYrNTFLm2d2HD	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLfTpsccBX3uAHJwirtBtRZQgiqbgcPpLMiCRc95MbnZfM3V16c	86
116	2vbLnxX2nw5whMCD2ediSkZW3xGAWS4HxbwFhzx3oGHBPdMzi7Nb	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLfTpsccBX3uAHJwirtBtRZQgiqbgcPpLMiCRc95MbnZfM3V16c	86
117	2vat7poaaQL1TP1Hrt9dHjbZ1hRi1j1JrETy8fNc5sZTLvhFTXd9	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLPVSKBhRVjmcr7eJPjboX42wqf8SdFrKSDn27UGqu7cF9SHknp	87
118	2vbE2hd5YCtjojRT7ysxyG3owp6MacBVbscoA9ixMDt3mrxjPQ42	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKz1c8VPXE2abKxDY2DQc68rtEHFrdcy3BGWL4gJ2ouVVtovy2W	88
119	2vakKKzHkQSsFk5WxTQKx39W8PTdAgsAvQSaSBZuHYTuAimCSzQk	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKz1c8VPXE2abKxDY2DQc68rtEHFrdcy3BGWL4gJ2ouVVtovy2W	88
120	2vbktSRrVPMN7DHT7na7nUV2e9Uz1kkQdERwQLert4qmfbsVMrbG	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKbUSqXJGLXxgxyua78QfwyXeQWoMzSzsSmzmpCpTpSnQserTqN	89
121	2vbSzAVi9yg3VRAwb4dhFdTmT69YittqpRfyycjWVRpZMTeAm6Rz	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKbUSqXJGLXxgxyua78QfwyXeQWoMzSzsSmzmpCpTpSnQserTqN	89
122	2vaKzv5qwhLYTNairaoJpsPP84edwU66MwTpbqyQ4UiCyQx1MBAr	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKRhMZt3QiAS7nH5T97NcGm9VjqDgtt2FHnKCJHrSer6awgwCtB	90
123	2vbAk2vWz4G6qd3RMZafQGkrtVKMGWVL8f4DuVQEwoRvxdNfgnvG	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKRhMZt3QiAS7nH5T97NcGm9VjqDgtt2FHnKCJHrSer6awgwCtB	90
124	2vbF7yFKNd1xZewLRHk5nmLc8F3Zv7RoHUNebBvV3hhMjbakTniR	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLcW54aa8Sq8BJVv84Qfrw8piC5mjTHtcydmdoQUxmHhXxrZ5fa	91
125	2vbuCyxAcgyKK1ibSs6RJeyfDxR88hsfnJdchYqKkeQa58YS9Hga	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NL8Gum1iYPNQc3P66Yg6gpY1TWeQCW9N5Tumg46a2y4837zHUvw	92
126	2vbttkfWbwGM4kxsCt5FKpSuSwRK4kSaLXQvZiMffQLTRDznazih	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NL8Gum1iYPNQc3P66Yg6gpY1TWeQCW9N5Tumg46a2y4837zHUvw	92
127	2vbbx5YPkjFokM51QnXD3HjKSHzsRVSJB3jiQqe61aZHJNtWgCfw	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NL3PJ7AuBWzSj2d9uYfTZufcY3PEkA3a4gQy9fx2PVHUn2vGnpA	93
128	2vb3D1gNGpvmRbEKLiZR49uQFvE7uvaGqUazRPKh5fXsta7KiPtD	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NL3PJ7AuBWzSj2d9uYfTZufcY3PEkA3a4gQy9fx2PVHUn2vGnpA	93
129	2vaSqtt3FkWb7MTqUTtiyERiXvAa5NScWLiqurgSqTUQCn6Z9NV3	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKNEK9UNTHXTgtziYUe1ZZDeu1JfuicYvzKr6xhSRTd4RujdxTz	94
131	2vbJuuksvTtx8UEueeeqmDATJFjUZYV8cBbQQx26k4g4m1wY7YKR	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLGHdRBBeMifiWzdaaaA16hLbNSRrcVC4bi2uu9tNeHAo2GLdkq	96
133	2vafkbu5EqooEJEYxgV4ii6uB4wQguHizcGhDQEUp2QJnvJqpwX3	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLJ6M7u5qHyw7HM3pAf8bYFmMAooaLBsbhxWTkXm6D8uErwkgxn	97
135	2vbeSES8UVBwwQJmYnDwWKHiXHVA8H1zKd1Zw51LQqJavZESmHsM	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLpdLYLiYCrdZBTwABEVdqH8AabqkV68qfr1Fi1eDPDVavtTSjY	99
137	2vb43gva22hCnEQa5ai6cyg4ExRFtD4eN1bvMojaaWH1Q9UEknb2	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKEDtwe5VCrEdpohBoaoj2vS7njzU28StWEnRzrFQ1shkMkn9Rh	101
139	2vakFcjry8cpWaGnDbzZTEiqNYHX49KobTvKQxYJuEqpBE6gNQMo	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLXbPzzkhSz89QJJhqw1XkZ9BVEP4Wdisqz3zeCPr2n6BVgbcgz	103
141	2vbA2d5PMTyuhV3G7vZ1AdX1o2VnQsRtJhmEqifmuzKjQV2avAz3	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKcajbQ2EGf33HsyzUEgn5EAg5Bs9KpPJk1zcP2ayzMp1S6Xiwo	105
143	2vc3iwFziS5tLwqt2PTqYR1nKFqUsFDmcY7uQ3hEy8XMj4YVPFsK	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKegEqNTqtv6hxJxrH8KEGmJMwoSs5niXF7mh2kqwx8PVsoXwbN	106
145	2vbvAaX8v7DYR2fW6hTw52VSixescT717vPU68frmn7TV3RMRtQA	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NK8gGLaNPr9NNr79JBb94KygePrLQmdoVmKthDxQ3ECUzqipNXt	108
147	2vbDSFdkb73yCPhEv7Pw7Cq57T7DhBB7TzFgvTU2fAy8hRTda71P	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLxvdBnuLbQWcZFh7L9PXeHV7B8kxbCFhaApGcPbbSPuZ7rzjbE	110
149	2vc4cm7G3fKh23brGwAoDduXVyGUdRJry7FptVfVRY4ykxwzdmuM	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKnDmgJ7SdPqxDi39hrvuuyv7W2XBWgU1NKPyXPriRNseQQrDg7	112
151	2vbbtxGipEv8cottCaMcQ4u8LLrU5jy52S9fV8VU4sKqVWMPp6ej	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLY7HP9Vm9UxfhKzjhkxa8bXNxcdLjTmzUXVBmH2iieaFNrJvGr	114
155	2vbMjCL9kj8m7XLXj2xb89EdCmsKj2GxqGqv7De7awBoTk84RohD	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NL9hvVRoAQTy9xTrW1F5oi4rLC2SLDb4eRwf4hjW8tSkjhYQpid	117
156	2vb31pussKqK867jYfceXzSVn38etpEA9i1VxbKiuEWXiHuTyESq	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NL9hvVRoAQTy9xTrW1F5oi4rLC2SLDb4eRwf4hjW8tSkjhYQpid	117
157	2vbQQiAouvc3RsyucyePUeV9a2bZQuTFTzDSBqSR3ADM2AZrmFuA	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKj17RTcDNzH7ywCMu5TP3dM4Nx1H2JYLJCyAFyrAm7r9rZ8NU8	118
159	2vbYKfdgSxHTJjVhZE9P3n39PzYyRhKFM91CtVrZy32KeWcjJvjR	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLkwnDMz73b5Wz8sEDvKnW85n4aUkDNakzcNboQWxXVdgZgb7vV	119
161	2vbFWMoYor3ezxyX9c1B5u2kspnocNCeYbuVH5EJFz7gnmPEi5Sb	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKMRXmjdcVwGM3S5WSEbFqJ4ByLxBPRtyexSudBVcMTuZbTJVJs	120
163	2vahC14a5oraYRr9STnzrpbaDrg4EQaQGG5pftxHomU9tMTSGVLz	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKBcBUKLkjpDChp6YdrAfapHNJKJd3SwdnGYBCUKuTQt28qRjsf	122
164	2vbeFjfZYC8P9q2Skn3cTM44vtMYivnZ4snMyBynffWHeLCzd9te	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKBcBUKLkjpDChp6YdrAfapHNJKJd3SwdnGYBCUKuTQt28qRjsf	122
165	2vbihQxxsmr1aAYVEgjEsgDSGwo35hbcjEoRkWzi2KdKsFS8JZns	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLQWPAnWNR2xALL13oF5Ntr1tTY3yvoVWV1wxdtJWvtJnkYELt4	123
167	2vajewW2j1UB8CMQSHhXXzDYJTfvvibp7sxMKfQAZoJttEuSUYcm	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLMV8zkn7bYRzsRyvYGEDz8SmNQWFM9ew7WNFNFuTJwLBh9Wq9Y	124
169	2vb84KjmF7NrTQzBe9rj9ZY5Kg3qXBazmSfA8tdFPiugu4DWXGw8	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKKxP9htp59qi7DFPrk1yXdeqjb4rwZ1rXmLEHGB9VR8kwRCEXk	126
130	2vbNodyYxgRGeTs4oEMLYFLxNxXdvBSVcuqhpsQFgdFyPcmVTwzo	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKJBmsXVuJMpcMGZayZj9VasjiWyeJZtUYSxwGmg5qS5yCNuPag	95
132	2vbNGU4RDcbXFMTbRyEBsRCsHVwudB7Ee3SavAk2FZnwfP9Kkh2A	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLGHdRBBeMifiWzdaaaA16hLbNSRrcVC4bi2uu9tNeHAo2GLdkq	96
134	2vafRrVeK4CM9HvCZJr7vccTSegYvwVYiPD9nhZUHocAQzcNUBJE	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLEEpcjC54o68wqjPKBh7PBWG6fCHULz2uwWHxKW47aw6VZp5Lw	98
136	2vbs8DFw2NqSSyNqRWaMhs5zfpDZscnm67VLwCaEL3FNKgiy5kTg	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKCjiDRjvGMtFMRWaBaS13cAzaEfU2nFDHVK3jWJ5sJ3wCVzDio	100
138	2vbJspid7FYLAfgCaQzgtJ7MgiLHLsMKuhTMxMgFpNxG9hdbNQLd	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLoo2dHuJZPfmyf2Qr4sqJboSo5nLeamugugdZjxUYq9E6carX4	102
140	2vbLKQnEb8WnVVCwCDXuye7K4ynH7MJ4Fr5t94aav7wVTBia7dvw	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLjp1aEj5Js6he7vTzxpuZNNLNcwPki3jyHNtbjYquVafewTf7U	104
142	2vb2gZNr6AZ6HahXv9ESYYhg2nCV2xLJv2bRtJVV4wApGfFgZz1X	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKcajbQ2EGf33HsyzUEgn5EAg5Bs9KpPJk1zcP2ayzMp1S6Xiwo	105
144	2vbfw8fv4bEkkfwbhD3rS7gc4XGdYpMR3TvYUAvYYzRPCy26ThGt	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLiEtShQFSjAd8Cp4itVLeAa9NydKA43g4Tun5XzBmpktjT1zYz	107
146	2vbAgS9ncSVwAcoJ4SHhBoqCmDWMmgxwUMXAJhnju5Bg2CAGuSCj	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLRyqyeULxZKt5hf728yyYsN14KMVMGYMkhzitrU9LGSzBo4YjG	109
148	2vb5Zq3hrP8Fy7bGyCMwu2SM56cadcvA2QpGBkXYjeZERSCdnkdg	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKCcKATvP6JuEK5bRVJBrRH2L1oNHhx9G9e1EHh5d1g3bybsG3c	111
150	2vc4hN26vSDMNpQjDxZcsLWNF8E5yznHxEZKzvzrwCtkayMk4TzX	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLaonChBYmX3Pqt94gdjicGXFKajzc668SiLxu6GmhrReBJeav3	113
152	2vaQh16R4D7Qvzswb436XpWSAqvyaPjNWfXVFJKVPvjHXu4WjAha	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NK7NLsbHww2pw1CyN86pZyuV9xE15X9eHdNd5GHjWDNrjBtVb4h	115
153	2vavMtVxhMjq2HKgt7FfiRzNhQmpod1akaSCzWt2EAvAQwkEdQuU	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NK7NLsbHww2pw1CyN86pZyuV9xE15X9eHdNd5GHjWDNrjBtVb4h	115
154	2vbcaUGsT5nrQgHRiKPfZAR5TqGKy4a8PtELvPUq2Q23PxXF1epX	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLQq1WwT1nXS1dLCNVTNZE8aiXG5SzRaqjMZkt7URsBSdBoAA35	116
158	2vaDfXMMEuDZUiiF3fbNMbcxjZLkKfEYTNx4fMYxLT4oiBtu88rk	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKj17RTcDNzH7ywCMu5TP3dM4Nx1H2JYLJCyAFyrAm7r9rZ8NU8	118
160	2vanmL9N1RNeJGJFJqhyGj6hiQQDW8y3ZWkhLnEd98W1hWUTLikB	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLkwnDMz73b5Wz8sEDvKnW85n4aUkDNakzcNboQWxXVdgZgb7vV	119
162	2vaJKxhoJtb1aj2fhqn59i2fgV9P24PHjXGWhiLk28vyDh3r886H	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLo54vkrXYBzRAv71bMYTzoresqf5KA3kJnGk4DVjjs8uwKp1wK	121
166	2vaQQNXPEYWue9bo3YJdPYgyGoetUPfAV3fJpZ2eUF8S1Pu98JBs	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLMV8zkn7bYRzsRyvYGEDz8SmNQWFM9ew7WNFNFuTJwLBh9Wq9Y	124
168	2vaToNedqpGeqkP5VdnRtwFhWi9UyTqtYWMF8aWhMv4q3xZhbhx9	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLN5KGsN6EeQh3PwtxAngLPfiYaYTDRpxCeky15sedBYFXS9g2S	125
170	2vbrkp6rL3A4ySrnFc5NTbEZgpo4B5MQaPn5Q2yEBYshnPhW2TP3	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLTSMbNTQ1pRSWk9NAwyLeeGxJy9Y9YWeN4jXFYiFYS1H3oF1oK	127
171	2vbMVwdXnsdVoKrqHTAcFnhGUa8fvQ7qv2KYusYmJ2sFt8NiosvV	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKWaBouUxHh5gzZYwhQpZt5ozrqhhq74wHh8YyMyuLCB7jRssBn	128
172	2vbw6XKgbw98mKhntB6XpPHbV8os4oinPxR6t4e5XYp64UBryMgt	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKWaBouUxHh5gzZYwhQpZt5ozrqhhq74wHh8YyMyuLCB7jRssBn	128
173	2vasvZ52qUSpzqfXe7onUMBsiZcE4hHrg4n4MpdJ3i8ptdyN9S6Y	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLE1jsbRi1i6hRqMGchEPVtVw1dDsntJX7in1GFpm5GgYUL4mMP	129
174	2vaYgAphPdcap1QrZfmoTU2vWrUKRJ89LfmeR6tvG7qbk7qRAwZB	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLE1jsbRi1i6hRqMGchEPVtVw1dDsntJX7in1GFpm5GgYUL4mMP	129
175	2vaZMPezGqqEpu1S8tes5tVW3UC5XR7HSUzTJ7f4RDjRiQoeWdpA	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NK93nNvm9YCj42QNw2S2Ci3AcaKvtrQfMyLo8xj3KK4Txx8owez	130
176	2vb2kmJhLUN8ZyRVtz4hUQqV5igGaPT8Gmgjkb2gqv6jJnVJJvpn	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NK93nNvm9YCj42QNw2S2Ci3AcaKvtrQfMyLo8xj3KK4Txx8owez	130
177	2vbHxz3eEjpRiueeTgHXCypUhE7VK4JL5cmHMxTxeLQtdpm7ki7s	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NL6HoGZfB1qUS3Av4thoX7sLQZLhVpcNf9HuHH2QbzEGSW6897E	131
178	2vbsJZYtKenbdASuFvQWFFJ7DDZ88jyMo19ELomw5NNBrQmuk6YC	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKSfxC5d9nSCghce7g6KJgbifnJe4Nohi62k1oEtPiUkHcf3Nbu	132
179	2vaHo4pRULDZHxUZRoxw3yxXXGLuhBiPgKTThRAggW5enqZSmJmo	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKSfxC5d9nSCghce7g6KJgbifnJe4Nohi62k1oEtPiUkHcf3Nbu	132
180	2vbGdZVuvqZQeYstFT7mVm5RroGdnnGWmdJVPRLeFBaXGGwk6Ybu	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKCsGz4aapFxSANd8DRngkRaN2HptEmenrESiCWPczL33TENeDc	133
181	2vaVgUgK3PWBgxqUC1dK4YUNEXzfqsqQJc9E5sivy5M7c7kWqugh	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKCsGz4aapFxSANd8DRngkRaN2HptEmenrESiCWPczL33TENeDc	133
182	2vbexi634RahSUuKKFW4efL4e5ttrzZznNKfChyExF2FTmFvZGP4	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKFSy3bp7PfVdDQxUJ7yFoTx8ukjuL7JjvA7axrrGxzKALQLSg1	134
183	2vbHcMHNecnbvk5WojAMaP7LUAA3PqgPjz1dCeRNv53qyRQnxZHE	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKFSy3bp7PfVdDQxUJ7yFoTx8ukjuL7JjvA7axrrGxzKALQLSg1	134
184	2vaHR6LTrvvXmLXctrRPnpUoKnZx5DCod9rWoiTa218LSA27r5UD	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKEfDzwiHVeabaVAJzQNSQXWZbypGjmdpFbQg8NiwtBHQtzYenq	135
185	2vaaXgcTBwU1fRkE2z8LE3hTwjBAiYLMSgbNDsqB67Ew6YqKqzDK	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLczS9PiUzSLBPHEQmkdvHMrY8zv8Kei77y964hoxcAQryV7PWy	136
186	2vbHvZtWKyXyKcJMr8jnK3eUijmq5fecEYj7jLbwoRWsTtZwrc6U	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLukGpZoz5cHVXbwrKsqanJXyQrJ4NxgmqLFuZsBYHUaoePjpzB	137
188	2vbatrDodjajQGa6g1XwZp2eeHLWLocohPdrzJhbxpPva4nhJEiU	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKaH48tPQNTeBCNhKUEVR3DqPdg6p6hRuGX9FXVktWBuj9nFzLY	139
190	2vbTXLG2XXkAfAEMfDjR9bsn7aekj2mFeSQe1UkyLJzmTTid76jp	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLYis15CYedj5CCRihGLd1wMo3iFqgNj2edzJLQe9wbospdj47c	140
192	2vbE1gc7ZP1cnwaDKWC3he23W4373EEELF77P4aAc96piufwbvgj	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKm87s5oKWBEsHaUjEbQwwS9YPAsQBUZ9jt6zA2JpDdkxeNXqa6	141
194	2vb2uHgxVN9aztbS4WGKbvZCduzCU4bAS5n5DJa8PJeXuUqqShcA	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKvEpg9DK8AqMLsRX9KwVxiXJFvwZWLBo5aypXsdDeq5Ja1EBhL	142
196	2vbvQRcpUD4njz9bUwpaqZdgD5in5xnmFXjFxQRtbT7Aq5v497rM	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NL2PGUSfZaq3M5g8QYrXGFSvhR5eVq963bme2DSZawN8kYcx6gz	144
198	2vbgNuNdyfUwt3sS2996NhHAKTt1arBcuegjzfUCqVfyviy5KZ3s	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKFV4TEUgdmdauUgiSKbecX8qWaVySou3nEsJupQNiEmoD4ARek	145
200	2vbydPPcAo2hKwR92rggckkeccH5e4QR6Sw2LuZfYCFFYLpy7N74	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKpKpdKgnqu57WBSfpMEvbaT9AkrBRJgm1kvYSQYgAKuTxkiRbN	146
202	2vbnyfFd3NHpVLHTDcoAoHVAxTwbhFodpKAqqzT5iEuue38ZZHgR	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKbB6VFotiM1w4RdwFEjzYoZeLYhYZ9PmV8bhHZbiKgQjEYfjmB	147
204	2vb5YNPUkyk4zxMce4UeVy1yN18S6MUJQkQWCQdm639Hh5LDiA1V	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLN99bdi63h9JNnjRnmy1p7vCjJGNe23BqBrgSqGUBUWJtXqaN4	148
206	2vawxZjGuiVByuDHd3hdPk48KNCf6sxpUruXwiwNWbGvKDH7cbE1	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLYwavy2ear9xZQvpTeC4oTFgPYkpLRKSGyiyHYw28gJJGMK1Kf	149
208	2vaieVkpcqsLZNT78ErprbdfSywKCsaDtRW5NsVQNVUpLNxpKZJQ	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLyQWJwzFTTv6wYAZABwkch5UJxSk4cVLm29i1vyeLpr7mH9SL4	151
187	2vbFyjiUvNc8sCVcGrjxsn4MWLaHys2Pj9eZtkQxaChDpkGghpmt	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NL7m5C9MdKKACxM75L9KQnGDbFVWT1cNsZseUA22Nfo12muRLYH	138
189	2vbvkSXH95LFx1aK1XvXJrTTGY2gurwS798snU9d4yvBuYUVWgMT	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKaH48tPQNTeBCNhKUEVR3DqPdg6p6hRuGX9FXVktWBuj9nFzLY	139
191	2vaWmmFUeSLBmrqt5EKN2TyRk35ep4TtAqt3PokdYC7tLGu2hUaf	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLYis15CYedj5CCRihGLd1wMo3iFqgNj2edzJLQe9wbospdj47c	140
193	2vaNXLYwzyeNuAhDAwXZaPEcxEDt6L6xtS5vzjReBL37iPYeQjDN	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKvEpg9DK8AqMLsRX9KwVxiXJFvwZWLBo5aypXsdDeq5Ja1EBhL	142
195	2vaq6gxL2px4m11N6yuvmYC8xW3fEEt9B367wfGMrr6XaFM3734P	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKMSeXUpJM5wmXm8jBpAFuvrC5i6wknqDJEgYoydkLSZhgBb2xo	143
197	2vbHPgyrQU5mswXAZpDwLAArep7sxMn4QQD8K913sSY22ge7nhvY	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NL2PGUSfZaq3M5g8QYrXGFSvhR5eVq963bme2DSZawN8kYcx6gz	144
199	2vavpgLgwVYg3LgfojhquXW6KJuRyJzPcaxps13F7Cx9KuGYJNhU	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKFV4TEUgdmdauUgiSKbecX8qWaVySou3nEsJupQNiEmoD4ARek	145
201	2vbi4NG9Qtm2BiUJotdcxoeV6BxWf3hR6aBT1GM3RWPXiSCLEMA1	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKbB6VFotiM1w4RdwFEjzYoZeLYhYZ9PmV8bhHZbiKgQjEYfjmB	147
203	2vaTuuiYTYYghd1NeEKSnnukjURScPiNZBHVn4PMVJqjHf7yHEeY	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLN99bdi63h9JNnjRnmy1p7vCjJGNe23BqBrgSqGUBUWJtXqaN4	148
205	2vacbAv8xxa3MoXmmTMpivZJU7CCMk9tUqNGwew2abchEEnrFHwr	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLYwavy2ear9xZQvpTeC4oTFgPYkpLRKSGyiyHYw28gJJGMK1Kf	149
207	2vaWF1MSzWSqVzUMuc3tA7KZsCsQmDcUQmYfQ8QGabMZqpT5j2Lx	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NK5op5VwhtwS3qJuyPe7T7SjgTvLiYzPttCnFin6w2CpWK3P6XY	150
209	2vaopQknqbSY5UCd8GpUjjCN6ZRi5rXGf7euPqcBUHipWiyBZn7w	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLyQWJwzFTTv6wYAZABwkch5UJxSk4cVLm29i1vyeLpr7mH9SL4	151
\.


--
-- Data for Name: internal_commands; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.internal_commands (id, command_type, receiver_id, fee, hash) FROM stdin;
1	coinbase	190	720000000000	5JtbsT3HbhHPj3BiynZe2TSKjR5YWZh2bSi15w4SjqLQVenmMFhG
2	fee_transfer	190	5250000000	5JvM75sP3wxdSu3UAP6EqLtSpWmG5HQ6niSm3Daw5ieEzcLs3auj
3	coinbase	168	720000000000	5JuM7b3TotApF4tNmfqGVvT7jy577gyCbM3ePazkmA82n7uFrJ9G
4	fee_transfer	168	61750000000	5JtrRSKwcKKyXfjpjjcXVbQGSMrxFNgueAToaDfsfva8U8ykcio4
5	fee_transfer	168	92000000000	5JusC68sg5rK2KbDm9e34Tj33wPQFn3RosDnhgkewSXy9dsbFMBU
6	coinbase	28	720000000000	5JvEHThSPKujqR3EDVjtBx5DALYmwiyiZstuYWJb3SNajWHauMeC
7	fee_transfer	28	124500000000	5JuUCVEkhJ2QiCGkAU9rMhERWNwrgZ3h434tbnHDysvNfcUcJVJu
8	fee_transfer	168	124500000000	5Ju9XvMzksMjMRBE7avoiJiJ57aXNHnyzuHhK9PMkU69F8PpFByy
9	fee_transfer	28	121500000000	5JuKwkLxSX8XqBHrd7HWJs7529sBtBsyrVzmS96otLWLYNipYagd
10	fee_transfer	28	500000000	5Juk7eV13N4y8ZEUiYKtydHzHziYRXSJJ3oRajrTEWEDGfdD1ZzP
11	fee_transfer	28	107250000000	5JurKQdmMsNSzbVJaqLHHE6J2N27aKtR42XTKxYYaLMBCF2t35gP
12	fee_transfer	28	87000000000	5JvEVNU4kaDDuPfFtjKruziXdnT69MguxYKEHLRDNtMWM3we3DZt
13	fee_transfer	168	100000000000	5JvGLw9i7tfi166cCGCBgnnxrvo4bSPasLqzDYhJgnBFEtcniLZp
14	fee_transfer	168	24250000000	5JtudnnLoiwnZ7shRSyWJ4ijQ5txbEToExVYqC5WSYWjH9x3mDCq
15	fee_transfer	168	122000000000	5JtdSpNUJku8YSsA6aX3rnttA46qQjme9taqdookMTZPbzCPBjad
16	fee_transfer	168	122250000000	5JuTniKWFhjrr9V4DprgktgKaFDMpbQZCBaynK4oGf7SAb2u8XsE
17	fee_transfer	28	122750000000	5Ju8y5o9vXj4375Z1thdMANm72Qx4oXa4Xhnao6A375aQJwoferU
18	fee_transfer_via_coinbase	226	1000000	5JtcBmxFmAVY8MkNdTKrVEw5dwUwpUdboVhAskhaNY5yeRq7825Z
19	coinbase	28	720000000000	5JuH4WzzNBeUvN4f6KMxGXXNSaQAVC9ThvhPDtK17ZnvtF3kaGQr
20	fee_transfer	28	1447000000	5JtifCcRwxMfT52toMj4bKwvuwqaEM7LCVBXoTbhW5R7YxgNNvSa
21	fee_transfer	226	53000000	5JtZXRvz7EPs5Vdv7tLpTrwxjArD2A52BamycTb2PyZDANQd84j7
22	fee_transfer	28	124494000000	5JufK1KQdGG422jp1gp97UXg8LgVfSxTTM6KodXG9S4YjhWSMx88
23	fee_transfer	226	6000000	5JtiphBRa11GwfN33oH2Pcy7NQkTa3jDoDpScRBi8MW1NM5QFkYS
24	coinbase	168	720000000000	5Ju3EzdZPHTxfHfNJwjYk2c37cw3zf4SYr7fqsQpjMjVUWzRJD65
25	fee_transfer	168	121998000000	5JvGP3cRcsP3SWQQw8TAi4DruyVQWp8XxjGPz2QvGHYbyjZmvjjq
26	fee_transfer	226	2000000	5JtnLazJyp2MHx3vS1ZgMyyb6XwetLFXPNH9TiF8DBaLFyjP45h1
27	fee_transfer	28	122250000000	5JuwUqJFAuUe7Bwj2aCYGWnpEP7GTVCcKRg1TKEyjszA3xHc9eFo
28	fee_transfer	28	30000000000	5JuTMYE1SwsUSq1YTV5dRMMBsTQzs1jCRXmwqYWzsGvuEgp9a1sR
29	fee_transfer	28	92242000000	5JuNvZvhWJpEqXX5k6dvwKDyBk6dKgrw8gV7826812KUQ7iQGgfM
30	fee_transfer	226	8000000	5JtvkxAr233G4ENbaH7VFnG3Dy5druUPZQad1TiUYN5CZQ5bwM4f
31	fee_transfer	168	124243000000	5JtvKykFRBVDePWcjy9eHWDbKE6mwPNKjMEELsrR2wZwnDYfvs86
32	fee_transfer	226	7000000	5Jtp9DeSxBNcv2CqLcn9jShTzXpLJqe5bob54He7ZTzB62k26q5Z
33	fee_transfer	168	34997000000	5JuGJ8xC3o5WiZL8sGCY3c6dgc5w6ZAG9m5K9vRNueh5tV86ZpKy
34	fee_transfer	226	3000000	5JtoWjqQDEn2kLasYkgCdWJeSMc2k6wGrrK9675hjXomD2P8gFdm
35	fee_transfer	168	24994000000	5JugF6PNVrE6GSFcn3FpTQYfVZVDAVFhFxh11v5sdHvUVgA9rp9o
36	fee_transfer	28	29993000000	5JuZc72fJq7Rkn6CaWT5Zmbx9AtQFbGo398oTeebcaVuREbT1agP
37	fee_transfer	28	49989000000	5Jtv2vkqjnw23LGSZrRBfUf6gkyusLzbW2oNZD6xqt84ZBrQsUFH
38	fee_transfer	226	11000000	5JtZgARqEku5rUx8KeNsrJLahQBRNTMYL8HrWCSNbYN14yPcGZ93
39	fee_transfer	168	34992000000	5Juw9Dy14exCbvGibPe58LKmX4EYmBPmUxGAMu9KzuNE6ug2vkc3
40	fee_transfer	28	34992000000	5JvGSeFxzRyPYxNTsM84AgDXd2rX1BqR3F2JEWCunjsw1Zdu9dgW
41	fee_transfer	168	49993000000	5JvDN4bZdRksigX884HxrqNu8d3UWnzoQ2Ww1dZEZj2nXFcVETjN
42	fee_transfer	168	79247000000	5JusfNRpXX5xkaAQB1cV3x9i97LHrScQuySRwbVZENuKN2gZgVxs
43	fee_transfer	28	49993000000	5JvHsHrhtHG9t8Pvsbw5Ri9Qzxa4brNUZBgpJNGG74ceLa8wX36L
44	fee_transfer	28	79247000000	5JvD3AvLZN3Vpivzkd26zhDL6T4LLKeUjWmk2qzZj7PHuadiQn4X
45	fee_transfer	28	64996000000	5JuyDZAsQsmZaF2CNRnDnMVArcJTqpgSjAarWQHSUcV4mWtGWenq
46	fee_transfer	226	4000000	5Juq9Upkjamd9zqK5BcdnQSmxC1YexetoYShgCxYh5HRVkYX4c6h
47	fee_transfer	28	44990000000	5JuiqJqSrEa3KwWfa42nYKRqJWkhMCizXevho8S7u29ZZ8Mn5i1Z
48	fee_transfer	226	10000000	5JvKS9zQuUditWKVrZgAJHp5mEiP1sXRAqAts6PhmXUx8Z7QvLSF
49	fee_transfer	28	14998000000	5JuY4Q9Rs4VexFDHG45s4cN9RZeYALCv1mCeyoh265WD1Dz7QERe
50	fee_transfer	168	14998000000	5JuN1n4EWdU2vK84As9xvPkgMmXdNpjCWvQdABHCkwC2twwAfQTM
51	fee_transfer	168	14996000000	5Jtx1jgTEmSa1GoZJveuyTR3ksfiKkXf1PCgDLLVNN1BnNBzcBKJ
52	fee_transfer	28	4998000000	5JvPzYajaUJTa1bKSXgyobdYbCGUP9eRdDxYeNYaXLBQJ5sQxR9h
53	fee_transfer	28	9997000000	5Jv7PKQoU27Kp2n8NzrbkZ1nxYVxwPqc3y7hofPK5xyn5GXRgpfZ
54	fee_transfer	168	19995000000	5JtVTR8WM2PAo2Zs2wrKNQczn4ZKHhL1DRcNEXZJrj6UwcWRL728
55	fee_transfer	226	5000000	5JtmHudESaaRwmMSPqWB3xcUgD9T5fa1ABcyWeKMsSpA9DmMsAYf
56	fee_transfer	28	14996000000	5JuZv1Fn3CETXcGNkDsSLEpxUQJPt9Ckpw9pCzGQVm4wuR5H8Ner
57	fee_transfer	168	24997000000	5JtvvqniZA55d8DwFyjxLbXk5vv3PdNmio94ssLtTTG7gDuGhMnB
58	fee_transfer	168	96249000000	5JuRuAa3hAXtj9kMMvGeC1QVRWh9g5bVG48by1KG6JA1zZt7sptx
59	fee_transfer	226	1000000	5JtcBmxFmAVY8MkNdTKrVEw5dwUwpUdboVhAskhaNY5yeRq7825Z
60	fee_transfer	28	29994000000	5Ju5fRDMXwD761oqq82gipJHQjv4iMVo4YGHWNA2BRj8AHgihGuC
61	fee_transfer	168	29994000000	5JvQLp86Kmr2USd2wiHFAK1b8gTML4S9VwLbpxfzZ4oivQL1cwwd
62	fee_transfer	28	24998000000	5JvQf1Mwa6oK5CeWkhtJ1skFnGBMSz26DPMKdp4FGu5P8vw8t8ym
63	fee_transfer	168	4998000000	5JuA9hZdRkn1GWQrhV127nDHcfHdeJDJTxWsiC824BTyd5Pmyjhn
64	fee_transfer	28	19995000000	5Jts3FMsBDVFdUoDqegjv89CmyTnGCqV5QtDDerFCBpzBRWJtZxo
65	fee_transfer	28	64986000000	5Ju1GpjNntszBjka9QsmPre3PthMX5uHXZTsfZa1r1sQkQTZhw5Q
66	fee_transfer	226	14000000	5JuFzjUGHe1RxEguJhCxEwDA6Rm4CPQ6cr5mgvCRsAW7omUuLqRY
67	fee_transfer	168	9997000000	5JteDsNtkaohZMFvWknwgeh943JUigHrA7JB7UVnHNSbxPbv3P7P
68	fee_transfer	168	44990000000	5JuCouuvFGYkwuUYvwyM6FuoTiiw4wm2YoNY19vNUgRQj1VJqwc1
69	fee_transfer	28	29996000000	5Juss2xPEJFE9HpASbWhNaRWrX4xZpSeTf6V9jnkZUXFdSP9nkgz
70	fee_transfer	28	91250000000	5JvGQsz2DzZebd6CQn5dePbNeKrjYY7BYj9EYV15j28aMgC56NFd
71	fee_transfer	168	24998000000	5JvF3eZH55ZkMov84684EgXSN8vzUwynCNZNHFzPEf8txaSkekt3
72	fee_transfer	168	29993000000	5JvFvrKGNK6wiqsukSnKQazgRuKP53ERVAaApp53gntgkKzPTnME
73	fee_transfer	168	59987000000	5JuhzE5C6F9cg73xiwiSSFGH8a7AKJ3vkXbeEb3jaWeogNHo9aQF
74	fee_transfer	226	13000000	5JuSG1kaUvmKBpBRKiHojT9n8GrwaxxE8LVyPUmHXuKhJHX26VDy
75	fee_transfer	28	59987000000	5Jv7czq73NFB3RmhPLT119V3Z1j9H1hBJrRX4QVwP4YmgpKBqgPw
76	fee_transfer	28	24994000000	5Jua4UTk2FF8SVbMp4zzkzL42axQtZCm2Vgou4EasshQf8ZkaGrK
78	fee_transfer	28	24997000000	5JuwFKN4enwPGJrPXF2R3kk1M5X4LeBoSjHHMav3bRgJbkqmkuvH
79	fee_transfer	28	96250000000	5Ju5RiK1EJZaSPHH3p73n9tyenCPP3ShdYec9TtPj4S4Bj8ahny3
80	fee_transfer	168	49989000000	5Ju1euge1nw57N7cmpzForVRZ4tZAE7Eam52MxUUhPN6tme74ve3
83	fee_transfer	168	39994000000	5JtWcyJEnKLyKUjFhKeNF9FW2YGLFodJWkiGUisUWsRoYHXmx5nx
84	fee_transfer	168	24995000000	5Juc3VbV5px67ZTGSTAESTS3ViWLGMo9xSeBE6qhc3cbGxj8rZ2S
86	fee_transfer	168	69985000000	5Jv6UAGAXn3JjXE4VUBga6kd7YmYYxyCm9dzTiuPUTmDnJmgt99T
87	fee_transfer	226	15000000	5Juu64xNHC6EocAsdDaQVUYpXkbqjsJ2MN3DY36J8nsMoTBPM8fm
88	fee_transfer	28	69985000000	5Jv77K3ZYRnSefp5r5eQUKQ7yY1sq2Dos6hUzFTCGhj4aksDzEUs
90	fee_transfer	168	998000000	5JvASVsJP3nzmM1rhcJXW7vK7rBo7fgXFDZc1VJ6Vh7mMdQ3Ghba
91	fee_transfer	168	2250000000	5JuZf4qk9HNsyQLWSM6psejPBhnBFjpyqRy5s7FQrdqPeGW9JFRK
93	fee_transfer	168	498000000	5Juzt7pjEvQuH1b98Z6sM2jF3mZo8nh6xh7tvbH3dU9qPkVPqw7r
98	fee_transfer	168	497000000	5JvCUUNUN88VYGxsiyxjr2miStZXqJWSU7197cqLCJEuzHfxhU24
100	fee_transfer	168	248000000	5JukL5HBQjTAGfTNY35LPXvYLUCJHZ48JCdWXKeohHgH4CEmhsci
101	fee_transfer	28	248000000	5JuTeSGzqLq8Vx5Chh2WtMchRsVE6ownBbyCFeDnYA1WbHKjgku2
102	fee_transfer	28	746000000	5JuvRBqAcbJ1QQGfCArrMfimKBs3ZB2UeWfVomTwKHTFAGbxoC78
103	fee_transfer	28	3485000000	5JuiA7y3TpeLQemQ4juvXRDHVjKsR4pVYvfZLm9H6VwqvUHHPs7C
105	fee_transfer	168	995000000	5Jv7RC4SvqiAZ57GQtQkQ72LYL2s3FJH7pdupL3ghA8wc8ee5viD
106	fee_transfer	28	998000000	5Ju9To1vbtwSXA9RFnyArxwCzAbESsm8CQAh8YhdcacRQj1tAFSU
107	fee_transfer	28	2249000000	5JuEiPC1hetFDFpN6jzxm2WNr6ppc4x12zNpcYLxyWwBLzMk3k8r
77	fee_transfer	168	96250000000	5JtwXgbux5AHtEAxxiFvJrPczMSoNJx99AsQ4hySMysgwaYoGbiP
81	fee_transfer	28	39994000000	5Ju3q98jxmkPBZkm8UJBe7CbhjSUofcRfz2d5rUZff5Vd2uzHpN5
82	fee_transfer	28	24995000000	5JugtqvZoQnfjmSsBobfhNGss6RMvcqijmV2h1pU2kSxeripAfXM
85	fee_transfer	28	64998000000	5JuCkDzRFsgSSiGiGcPXx9WHeHTi54gxPCDogHi41EA9N3p3SUs1
89	fee_transfer	168	41485000000	5JuWwNegfyYEdeus1b1H1mMwpCL2K8YoC82n2D6HwLzCmuFo4LL1
92	fee_transfer	28	19997000000	5JuFq8hBFNVYBfzQh4XaMsCRNPPYMAoGKvJdhk9godsYMMinwQKQ
94	fee_transfer	168	746000000	5Jv9adKKsLvfDxV2pnp8buPtRgSf1uAL3DhbJxoMA7yNEbfE6jTu
95	fee_transfer	168	1493000000	5JvLaAwx6b1Jd5XfMfZ9f1rcvnATCi9mEfX2GhtQ8a8eUpFTYsmx
96	coinbase	190	720000000000	5Jv3SHP6Fs8d7rUzrMV2KXsb6rduNrCyNDAJRxDAmbxcDCFR1y8c
97	fee_transfer	190	9997000000	5Ju9sFbVh1QHpWUF3g7dGYjQ7nyPPbQ92s1wqQqRtvsYpahJBJeZ
99	fee_transfer	28	5247000000	5JudPb9GKmNoGuXynaqjDvdTLvVPVPqNQ27VAqAKZ9cXjzP41uMp
104	fee_transfer	28	995000000	5JuNHgtXPRUmPNDvqYHUmwoNUGGQKHp66M5KgGD57iDMZiCN1R2y
108	fee_transfer	168	2249000000	5JubSSxuGwnGby9CqPZTTwB4WJjVNNSRPAAL5qMF92ZbVrLJ1VhP
109	fee_transfer	168	1249000000	5JtvgqxWznc78ZM74zfdCAYtoT7Mm5f5fdzRYMC7ennQUPCmULbU
110	fee_transfer	28	1249000000	5JuJomccyvMe6wVLZC4yQzgHpPqiJxgsZ6LQkyoFGsUKjEwmwwD9
111	fee_transfer	168	3485000000	5JuGkWMZz2SnJt79LbH1M3Q3vEjPRiyJUCAEwbb9bXfeUJjaDy1m
112	fee_transfer	28	497000000	5JtbnbY8q2L51SuFqQ7VuLKhNnw6bXqH9pafkFTrtYknY55cC42s
113	fee_transfer	28	1244000000	5JuU1yAX6LMExxPY8Y2jZRSVkWZ3cp9YZszs5zCojb1jicCcyvd8
114	fee_transfer	28	1493000000	5JtrVj35p8Gj5NtXgvE9t62MdsUhzLSQk9o9DnkFEknp7twcAVvC
115	fee_transfer	168	1742000000	5JuMdkKDwmzU4b757WbfLFns4tmK6FNPyZLc5ANb843AafRqXhi2
116	fee_transfer	168	4730000000	5JurMcJx6XJtr5Zwi7AXFXPri5VfkUMqrLfEZeW8ahA77pygKYnM
117	fee_transfer	226	20000000	5JuBygE3NuwR6LKJie95JF1KPSymsiUdLj24D6p8eyzhyggAbeNk
118	fee_transfer	168	499000000	5JuSXJZiPqArPvmJLHQd9sW2Tw4roUYAJJzueTbHDi4MHxtZSNUV
119	fee_transfer	168	748000000	5JvQJrgDmmsXRxgYWrBoyouyJ1akt1FiQt16rAYxdN16KzsGkC4u
120	fee_transfer	28	499000000	5JvAWTPiRAJ92qvNKcdwAWCVU3kyfBtfBErtEARAgAYQW31UHWtf
121	fee_transfer	28	748000000	5JtZBwD1LQZpfrXNqnAkq4GSvewSrdb7RPuPLdQFttzgknijPd75
122	fee_transfer	168	1244000000	5JuFY6czxWy4agFtVCPHJ4XRXRPXU6msBySVNfvKMJSHGoJ9AoZB
\.


--
-- Data for Name: protocol_versions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.protocol_versions (id, transaction, network, patch) FROM stdin;
1	2	0	0
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
28	B62qm43ocL8TcTp3rXakwtc5tFZavWr8VJ6o3fP8q3qtCV3KDNExGT6
29	B62qmzatbnJ4ErusAasA4c7jcuqoSHyte5ZDiLvkxnmB1sZDkabKua3
30	B62qrS1Ry5qJ6bQm2x7zk7WLidjWpShRig9KDAViM1A3viuv1GyH2q3
31	B62qqSTnNqUFqyXzH2SUzHrW3rt5sJKLv1JH1sgPnMM6mpePtfu7tTg
32	B62qkLh5vbFwcq4zs8d2tYynGYoxLVK5iP39WZHbTsqZCJdwMsme1nr
33	B62qiqUe1zktgV9SEmseUCL3tkf7aosu8F8HPZPQq8KDjqt3yc7yet8
34	B62qkNP2GF9j8DQUbpLoGKQXBYnBiP7jqNLoiNUguvebfCGSyCZWXrq
35	B62qr4z6pyzZvdfrDi33Ck7PnPe3wddZVaa7DYzWHUGivigyy9zEfPh
36	B62qiWZKC4ff7RKQggVKcxAy9xrc1yHaXPLJjxcUtjiaDKY4GDmAtCP
37	B62qqCpCJ7Lx7WuKCDSPQWYZzRWdVGHndW4jNARZ8C9JB4M5osqYnvw
38	B62qo9mUWwGSjKLpEpgm5Yuw5qTXRi9YNvo5prdB7PXMhGN6jeVmuKS
39	B62qpRvBE7SFJWG38WhDrSHsm3LXMAhdiXXeLkDqtGxhfexCNh4RPqZ
40	B62qoScK9pW5SBdJeMZagwkfqWfvKAKc6pgPFrP72CNktbGKzVUdRs3
41	B62qkT8tFTiFfZqPmehQMCT1SRRGon6MyUBVXYS3q9hPPJhusxHLi9L
42	B62qiw7Qam1FnvUHV4JYwffCf2mjcuz2s5F3LK9TBa5e4Vhh7gq2um1
43	B62qrncSq9df3SnHmSjFsk13W7PmQE5ujZb7TGnXggawp3SLb1zbuRR
44	B62qip9dMNE7fjTVpB7n2MCJhDw89YYKd9hMsXmKZ5cYuVzLrsS46ZG
45	B62qmMc2ec1D4V78sHZzhdfBA979SxUFGKTqHyYcKexgv2zJn6MUghv
46	B62qqmQhJaEqxcggMG9GepiXrY1j4WgerXXb2NwkmABwrkhRK671sSn
47	B62qp7yamrqYvcAv3jJ4RuwdvWnb8zFGfXchbfqR4BCkeub998mVJ3j
48	B62qk7NGhMEpPAwdwfqnxCbAuCm1qawX4YXh956nanhkfDdzZ4vZ91g
49	B62qnUPwKuUQZcNFnr5L5S5mpH9zcKDdi2FsKnAGQ1Vrd3F4HcH724A
50	B62qqMV93QdKFLmPnqvzaBE8T2jY38HVch4JW5xZr4kNHNYr1VtSUn8
51	B62qmtQmCLX8msSHASDTzNtXq81XQoNtLz6CUMhFeueMbJoQaYbyPCi
52	B62qp2Jgs8ChRsQSh93cL2SuDN8Umqp6GtDd9Ng7gpkxgw3Z9WXduAw
53	B62qo131ZAwzBd3mhd2GjTf3SjuNqdieDifuYqnCGkwRrD3VvHLM2N1
54	B62qo9XsygkAARYLKi5jHwXjPNxZaf537CVp88npjrUpaEHypF6TGLj
55	B62qnG8dAvhGtPGuAQkwUqcwpiAT9pNjQ7iCjpYw5k2UT3UZTFgDJW1
56	B62qj3u5Ensdc611cJpcmNKq1ddiQ63Xa8L2DnFqEBgNqBCAqVALeAK
57	B62qjw1BdYXp74JQGoeyZ7bWtnsPPd4iCxBzfUsiVjmQPLk8984dV9D
58	B62qpP2xUscwDA5TaQee71MGvU7dYXiTHffdL4ndRGktHBcj6fwqDcE
59	B62qo1he9m5vqVfbU26ZRqSdyWvkVURLxJZLLwPdu1oRAp3E7rCvyxk
60	B62qjzHRw1dhwS1NCWDH64yzovyxsbrvqBW846BRCaWmyJyoufddBSA
61	B62qkoANXg95uVHwpLAiQsT1PaGxuXBcrBzdjMgN3mP5WJxiE1uYcG9
62	B62qnzk698yW9rmyeC8mLCKhdmQZa2TRCG5hN3Z5NovZZqE1oou7Upc
63	B62qrQDYA9DvUNdgU87xp64MsQm3MxBeDRNuhuwwQ3hfS5sJhchipzu
64	B62qnSKLuJiF1gNnCEDHJeWFKPbYLKjXqz18pnLGE2pUq7PBYnU4h95
65	B62qk8onaP8h1VYVbJkQQ8kKtHszsA12Haw3ts5jm4AkpvNDkhUtKBH
66	B62qnbQoJyaGKvgRDthSPwWZPrYiYCpqeYoHhJ9415r1ws6DecWa8h9
67	B62qmpV1DwQvBMUmBxyDV6jJwSpS1zFWHHEZYuXYhPja4RWCbYG3Hv1
68	B62qiYSHjqf77rS6eBiBSiDwgqpsZEUf8KZZNmpxzULpxqm58u49m7M
69	B62qrULyp6Kp5PAmtJMHcRngmHyU2t9DF2oBpU4Q1GMvfrgsUBVUSm8
70	B62qpitzPa3MB2eqJucswcwQrN3ayxTTKNMWLW7SwsvjjR4kTpC57Cr
71	B62qpSfoFPJPXvyUwXWGJqTVya4kqThCH5LyEsdKrmqRm1mvDrgsz1V
72	B62qk9uVP24E5fE5x4FxnFxz17TBAZ4rrkmRDErheEZnVyFmCKvdBMH
73	B62qjeNbQNefZdv388wHg9ancPdFBw6Dj2Wxo6Jyw2EhR7J9kti48qx
74	B62qqwCS1S72xt9VPD6C6FjJkdwDghRCWJnYjebCagX8M2xzthqKDQC
75	B62qrGWHg32ZdFydA4UF7prU4zm3UH3dRxJZ5xAHW1QtNhgzuP2G62z
76	B62qkqZ1b8BkCK9PqWnQLjYueExVUVJon1Nn15SnZScG5AR3LqkEqzY
77	B62qkQ9tPTmzm9oD2i8HbDRERFBHvG7Mi3dz6XLa3BEJcwA4ZcQaDa8
78	B62qnt4FQxWNcP49W5HaQNEe5Q1KqTBQJnnyqn7KyvSfNb6Dskbhy9i
79	B62qoxTxNh4o9ftUHSRatjTQagToJy7pW1zh7zZdyFYr9ECNDvugmyx
80	B62qrPuf95oqANBTTmvcvM1BKkBNrsmaXnaNpHGJYersezYTHWq5BTh
81	B62qkBdApDjoUj9Lckf4Bg7fWJSzSnyJHyCNkvq7XsPVzWk97BeGkae
82	B62qs23tCNy7qbrYHBwMfVNyiA82aA7xtWKh3QkFr1fMog3ptyXhptq
83	B62qpMFwmJ6fMm4cUb9wLLwoKRPFpYUJQmYqDe7RRaXgvAHjJpnEz3f
84	B62qkF4qisEVJ3WBdxcWoianq4YLaYXw89yJRzc7cPRu2ujXqp4v8Ji
85	B62qmFcUZJgxBQpTxnQHjyHWdprnsmRDiTZe6NiMNF9drGTM8hh1tZf
86	B62qo4Pc6HKhbc55RZuPrDfzbVZfxDqxkG3hV7sRDSivAthXAjtWaGg
87	B62qoKioA9hueF4xhZszsACn6GT7o69wZZJUoErVyvgP7WPrj92e9Tv
88	B62qkoTczRzwCUr6AmSiNcr3UWwkgbWeihVZphwP8CEuiDzrNHvunTX
89	B62qpGkYNpBS3MBgortSQuwV1aXcK6bRRQyYz3wGW5tCpCLdvxk8J6q
90	B62qnYfsf8P7B7UYcjN9bwL7HPpNrAJh7fG5zqWvZnSsaQJP2Z1qD84
91	B62qpAwcFY3oTy2oFUEc3gB4x879CvPqHUqHqjT3PiGxggroaUYHxkm
92	B62qib1VQVfLQeCW6oAKEX2GRuvXjYaX2Lw9qqjkBPAvdshHPyJXVMv
93	B62qm5TQe1nz3gfHqb6S4FE7FWV92AaKzUuAyNSDNeNJYgND35JaK8w
94	B62qrmfQsKRd5pwg1EZNYXSmcbsgCekCkJAxxJcZhWyX7ChfExZtFAj
95	B62qitvFhawB29DGkGv9NEfGZ8d9hECEKnKMHAvtULVATdw5epPS2s6
96	B62qo81kkuqxFZw9cZAcoYb4ZeCjY9HodT3yDkh8Zxhg9omfRexyNAz
97	B62qmeDPPUDtPVVHqesiKD7ecz6YZvGDHzVw2swBa84EGs5NBKpGK4H
98	B62qqwLQXBrhJmfAtF7GUf7FNVS2xoTPrkyw7d4Pj9W431bpysAdr3V
99	B62qkgcEQJ9qhjwQgt2XeN3RJpPTfjCrqFUUAW2NsVpzmyQwFbekNMM
100	B62qnAotEqbcE8sjbdyJkkvKnTzW3BCPaL5HrMEdHa4pVnfPBXWGXXW
101	B62qquzjE4bbK3mhk6jtFMnkm9BdzasTHuvMxx6JmhXeYKZkPbyZUry
102	B62qrj3VHfVadkyJCvmu7SvczS7QZy1Yk1uQjcjwkS4QqDt9oqi4eWf
103	B62qn6fTLLatKHi4aCX7p6Lg5rzZSq6VK2vrFVgX14gjaQqay8zHfsJ
104	B62qjrBApNy5mx6biRzL5AfRrDEarq3kv9Zcf5LcUR6iKAX9ve5vvud
105	B62qkdysBPreF3ef7bFEwCghYjbywFgumUHXYKDrBkUB89KgisAFGSV
106	B62qmRjcL489UysBEnabin5be824q7ok4VjyssKNutPq3YceMRSW4gi
107	B62qo3TjT6pu6i7UT8w39UVQc2Ljg8K69eng55vu5itof3Ma3qwcgZF
108	B62qn3rRAtDFNpyRV3WPPEXiomexKzuDyG6MFaZLJrx3vaCnxMX5dm1
109	B62qpXFq7VJG6Spy7BSYjqSC1GBwKLCzfU8bcrUrALEFEXphpvjn3bG
110	B62qmp2xXJyj9LegRQUtFMCCGV3DQu337n6s6BK8a2kaYrMf1MmZHkT
111	B62qpjkSafKdAeCBh6PV6ZizJjtfs3v1DuXu1WowkYq2Bcr5X7bmk7G
112	B62qnjhGUFX636v8HyJsYKUkAS5ms58q9C9GtwNvPbMzMVy7FmRNhLG
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
135	B62qqZw4bXrb8PCxvEvRJ9DPASPPaHyoAWXw1avG7mEjnkFy7jGLz1i
136	B62qkFKcfRwVgdQ1UDhhCoExwsMPNWFJStxnDtJ1hNVmLzzGsyCRLuo
137	B62qofSbCaTfL61ZybYEpAeGe14TK8wNN8VFDV8uUEVBGpqVDAxYePK
138	B62qn8Vo7WTK4mwQJ8sjiQvbWDavetBS4f3Gdi42KzQZmL3sri25rFp
139	B62qo6pZqSTym2umKYeZ53F1woYCuX3qHrUtTezBoztURNRDAiNbq5Q
140	B62qo8AvB3EoCWAogvUg6wezt5GkNRTZmYXCw5Gutj8tAg6cdffX3kr
141	B62qqF7gk2yFsigWL7JyW1R8sdUcQjAPkp32i9B6f9GRYMzFoLPdBqJ
142	B62qjdhhu4bsmbMFxykEgbhf4atVvgQWB4dizqsMEBbmQPe9GeXZ42N
143	B62qmCsUFPNLpExtzt6NUeosa8L5qb7cEKi9btkMdAQS2GnQzTMjUGM
144	B62qneAWh9zy9ufLxKJfgrccdGfbgeoswyjPJp2WLhBpWKM7wMJtLZM
145	B62qoqu7NDPVJAdZPJWjia4gW3MHk9Cy3JtpACiVbvBLPYw7pWyn2vL
146	B62qmwfTv4co8uACHkz9hJuUND9ubZfpP2FsAwvru9hSg5Hb8rtLbFS
147	B62qkhxmcB6vwRxLxKZV2R4ifFLfTSCdtxJ8nt94pKVbwWd9MshJadp
148	B62qjYRWXeQ52Y9ADFTp55p829ZE7DE4zn9Nd8puJc2QVyuiooBDTJ3
149	B62qo3b6pfzKVWNFgetepK6rXRekLgAYdfEAMHT6WwaSn2Ux8frnbmP
150	B62qncxbMSrL1mKqCSc6huUwDffg5qNDDD8FHtUob9d3CE9ZC2EFPhw
151	B62qpzLLC49Cb6rcpFyCroFiAtGtBCXny9xRbuMKi64vsU5QLoWDoaL
152	B62qj7bnmz2VYRtJMna4bKfUYX8DyQeqxKEmHaKSzE9L6v7fjfrMbjF
153	B62qnEQ9eQ94BxdECbFJjbkqCrPYH9wJd7B9rzKL7EeNqvYzAUCNxCT
154	B62qokmEKEJs6VUV7QwFaHHfEr6rRnFXQe9jbodnaDuWzfUK6YoXt2w
155	B62qpPJfgTfiSghnXisMvgTCNmyt7dA5MxXnpHfMaDGYGs8C3UdGWm7
156	B62qkzi5Dxf6oUaiJYzb5Kq78UG8fEKnnGuytPN78gJRdSK7qvkDK6A
157	B62qs2sRxQrpkcJSkzNF1WKiRTbvhTeh2X8LJxB9ydXbBNXimCgDQ8k
158	B62qoayMYNMJvSh27WJog3K74996uSEFDCmHs7AwkBX6sXiEdzXn9SQ
159	B62qibjCrFmXT3RrSbHgjtLHQyb63Q89gBLUZgRj7KMCeesF9zEymPP
160	B62qrw63RAyz2QfqhHk8pttD2ussturr1rvneUWjAGuhsrGgzxr2ZRo
161	B62qmNVzYukv4VxXoukakohrGNK7yq1Tgjv5SuX1TTWmpvVwD5Xnu2L
162	B62qoucdKZheVHX8udLGmo3vieCnyje5dvAayiLm8trYEp3op9jxCMa
163	B62qo51F51yp7PcqmHd6G1hpNBAj3kwRSQvKmy5ybd675xVJJVtMBh8
164	B62qjHbDMJGPUz3M6JK2uC3tm6VPLaEtv4sMCcrMBz6hnD5hrET4RJM
165	B62qnyxTMk4JbYsaMx8EN2KmoZUsb9Zd3nvjwyrZr2GdAHC9nKF16PY
166	B62qrPo6f9vRwqDmgfNYzaFd9J3wTwQ1SC72yMAxwaGpjt2vJrxo4ri
167	B62qonVLk7hUC2QtbB8PkXL4DHTUeTX2CAhxPRWki6mg51G1pwuMB3g
168	B62qjESPZQAw7mW3cPnMQKZiPuPtyATP9ZPnp8QgnEGqdnUBrjidc8R
169	B62qoZXUxxowQuERSJWb6EkoyciRthxycW5csa4cQkZUfm151sn8BSa
170	B62qr7QqCysRpMbJGKpAw1JsrZyQfSyT4iYoP4MsTYungBDJgwx8vXg
171	B62qo3JqbYXcuW75ZHMSMnJX7qbU8QF3N9k9DhQGbw8RKNP6tNQsePE
172	B62qjCC8yevoQ4ucM7fw4pDUSvg3PDGAhvWxhdM3qrKsnXW5prfjo1o
173	B62qnAcTRHehWDEuKmERBqSakPM1dg8L3JPSZd5yKfg4UNaHdRhiwdd
174	B62qruGMQFShgABruLG24bvCPhF2yHw83eboSqhMFYA3HAZH9aR3am3
175	B62qiuFiD6eX5mf4w52b1GpFMpk1LHtL3GWdQ4hxGLcxHh36RRmjpei
176	B62qokvW3jFhj1yz915TzoHubhFuR6o8QFQReVaTFcj8zpPF52EU9Ux
177	B62qr6AEDV6T66apiAX1GxUkCjYRnjWphyiDro9t9waw93xr2MW6Wif
178	B62qjYBQ6kJ9PJTTPnytp4rnaonUQaE8YuKeimJXHQUfirJ8UX8Qz4L
179	B62qqB7CLD6r9M532oCDKxxfcevtffzkZarWxdzC3Dqf6LitoYhzBj9
180	B62qr87pihBCoZNsJPuzdpuixve37kkgnFJGq1sqzMcGsB95Ga5XUA6
181	B62qoRyE8Yqm4GNkjnYrbtGWJLYLNoqwWzSRRBw8MbmRUS1GDiPitV7
182	B62qm4NwW8rFhUh4XquVC23fn3t8MqumhfjGbovLwfeLdxXQ3KhA9Ai
183	B62qmAgWQ9WXHTPh4timV5KFuHWe1GLb4WRDRh31NULbyz9ub1oYf8u
184	B62qroqFW16P7JhyaZCFsUNaCYg5Ptutp9ECPrFFf1VXhb9SdHE8MHJ
185	B62qriG5CJaBLFwd5TESfXB4rgSDfPSFyYNmpjWw3hqw1LDxPvpfaV6
186	B62qjYVKAZ7qtXDoFyCXWVpf8xcEDpujXS5Jvg4sjQBEP8XoRNufD3S
187	B62qjBzcUxPayV8dJiWhtCYdBZYnrQeWjz28KiMYGYodYjgwgi961ir
188	B62qkG2Jg1Rs78D2t1DtQPjuyydvVSkfQMDxBb1hPi29HyzHt2ztc8B
189	B62qipTaeCfw1MVAKCLH3KHk6WY2zegYwfp2Yh3Nr8cXA4ATqUfEMkE
190	B62qnUuRC1tSxiyQ4TJFjy7LBhAWWQYwvUxLHtQ1bXQzxKf7jYE4ZcS
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
226	B62qkamwHMkTvY3t9wu4Aw4LJTDJY4m6Sk48pJ2kSMtV1fxKP2SSzWq
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
243	B62qqrW7e3gDoeYVkEcE44juMwNjaNK8omb8GhrHokajarNudRrfPRZ
\.


--
-- Data for Name: snarked_ledger_hashes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.snarked_ledger_hashes (id, value) FROM stdin;
1	jwt7oozUdMiTd2ksapBTgkTzaAjbCkCmiztvoB43oepMw438qNq
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
1	payment	190	190	190	0	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuvV14YG5bdcCKar8ywF6NPXBF9gZ7VvdpFF4MprbkdW8WeKxhn
2	payment	190	190	190	1	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jufk7aXp9eGqSQun1zYR7aPp5ZtGHTGbjPGKzf3dQbiB2TdbZKc
3	payment	190	190	190	2	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvAM71ECKeDyWw5mJFc92eNc8kB3BhNbiutKs4be5r1dHkKgUUi
4	payment	190	190	190	3	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju3SZg7P5NjJSYgdtCREqhv4Z4pKvVgPCD5qsJwzRhDeZGxi5SR
5	payment	190	190	190	4	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju6xqe1NThMhptYpTzHLKCNTofeaTNbkHxuTVy22vL115MvXwct
6	payment	190	190	190	5	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuDkdvQihDtXTiQw5ny42v7GFvJkb9GDnaDTrD39vBQbjDo5KdQ
7	payment	190	190	190	6	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuVz1Purf3Vo3P3i7V6wXdcro7VPxL75vgh3D45nptGk8a5UUTt
8	payment	190	190	190	7	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtzEg2Jujs1bj9HPneSfLTdTiWba6Q5T26Zz6UL3vqojPRuVStj
9	payment	190	190	190	8	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jts78dAS7uvVB5ycLAAUCuSGyTgLw9VP3ruw2jQeF6L7JBYeryu
10	payment	190	190	190	9	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv66W5b1QaTzoUC3h5Ngd8iQ2puCwrPtfEXnD4iH8QYN3bpQ9Ya
11	payment	190	190	190	10	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtptRsFySBpYyKsjFHmQsySf7nmeNxi9g5PWSvbyTX7qLqKfmam
12	payment	190	190	190	11	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvQhf6WJhtnY9ZcJAPqu3DshWXJfHNUVqajxQEeLTKyNbunhXuY
13	payment	190	190	190	12	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juvz2M6zttNF8vYopbdce47vKxrxS5AEW4Uqtr2KttSU3xKZAdP
14	payment	190	190	190	13	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuScEhPgDoXcgksppHadSe8EuAfMt672hzr9vRumQ7XGHPWBr3J
15	payment	190	190	190	14	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jugz3QB4Fn4yoYoMhfcS7F83j8eXeUZUTpUgwt6Gzsaqaf8HXSB
16	payment	190	190	190	15	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtgfgUUqyXUdzTJATcVpCT4tcj8g3WCAaZTwBQX57DAQ47QkJwT
17	payment	190	190	190	16	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuTrKbeoiP783AxUzSyGYZQNbNY3HW9A5a4ALBFJgiDuC4jM4un
18	payment	190	190	190	17	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuwJsJ4vWrcW9771BNeLHVRyj28iNFkEXWay5S3jZg1FfJW1NSJ
19	payment	190	190	190	18	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuufryESgsRErwDNxanTcTQHgMUoidtf9uqsMgw9LEpLjsp8ySb
20	payment	190	190	190	19	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtcQtucMvrTnx7H5KgeG9AaRs4TUJqx9zYB1Bzyn7Tmh5Bacd7w
21	payment	190	190	190	20	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuXtGJJhs98pqFBhXbwvtJvoisBzzLaShg6aTxaysfQPptSe7kY
22	payment	190	190	190	21	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuLnsQJnd8a2kj2XrSesfPfbb8E8CSRA8E3DW3potTePdEZkMDV
23	payment	190	190	190	22	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv11He48j1uqCUQ9aAyQx7vBL8Tt1KDxgqXmaicYW8vowf61SB5
24	payment	190	190	190	23	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuhL75SU7htrqxWmPqXsXaFGxHkE4sc8riXqovr2UZAsmL4t5dW
25	payment	190	190	190	24	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvGBzHLbK15RN9kWAaAqNAL7NMx9PGEMNaNHe3jZoq1pjX1uyYL
26	payment	190	190	190	25	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtwfXkzV9Lfgaoxh8FkQExQvtKyyYzZFy9Z9UyNwu3HPVmb78Nw
27	payment	190	190	190	26	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jthub1tXmKqS9rUH8r3jH8UDVq3bLjZUJd9wzgQiqFyeZud4Qgb
28	payment	190	190	190	27	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtwK5sQ5YaZwmtipt1Sczh9q8XqD2ksrBjyVsrYhpCnqQcRxgPV
29	payment	190	190	190	28	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvLTQYo4d3EmUCQqFYLdSM9kYLdW7bHyU7Mzis6EDUNrxGxPuas
30	payment	190	190	190	29	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvMGxgniedWGjRFqfGDCtxsSanBj3QxLCDHkWo3LMBvjAKkqLLW
31	payment	190	190	190	30	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvCXo8RuxfjNbKWizt4vNsMPturXJA3PXnTG8h2vyiEHL2bmhhC
32	payment	190	190	190	31	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JueuraBDwTG2igmh186FNJnQc3Ab7qty9nQ1JDzDVmQ1LbjTogr
33	payment	190	190	190	32	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtpAa5tgsoTav8gLwzVPCedpieBhXDmcGH5yEC2Ae1zowyaWXGp
34	payment	190	190	190	33	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtaHZUkBrWrf1bYPkgABqj8ccpL21qDwonBsxhaRwyPCob1rdCB
35	payment	190	190	190	34	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtrWViRJafiC41F7nXhzYZM2SZ3ubZiZQnU61VhgwXTxcYuWUHT
36	payment	190	190	190	35	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuAvuNiYy7qnbLcu872miPiGXiFNcBirnvnDCYK8cAadiLKjyg8
37	payment	190	190	190	36	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jttsip3YT6MtnJvfQE8YqjH9xQUD1U96VR8NLkTeuwHKRm5NBQB
38	payment	190	190	190	37	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JucsTrYKLBTZ3k6z1yYBKrPgfgL6oAtM5fZsNa8EPqyMsWXpBDB
39	payment	190	190	190	38	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuXwNroJ3529RVQDiHNvHoEfbbRpJ1bsgfcEE9Vsnd5LYZfRCy4
40	payment	190	190	190	39	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvBoGYpnJHKporyKPoa7fabPUmontNeM7N8vpAUgx2EGrkXZ4mH
41	payment	190	190	190	40	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvHBqVJwXk8cstAozpHpcw8pYFghTmDU9ZMPurp2DCkPKnLCNf1
42	payment	190	190	190	41	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuMuAsT2aNECdnWaAJKb1YPXaoMBrkMczn99jFfx2marvo28A5m
43	payment	190	190	190	42	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuBkJcqnDePavT4GzuvdVv97LYr3D5rVfeTZTnUCyNRxdxyBjaM
44	payment	190	190	190	43	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvRGZUzcDZhHfwK3BVkxPxfmJTvbCh2cwCyw3o9j6mtfYCMkwKn
45	payment	190	190	190	44	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju9XupZ5WqYCrndoYfsmoqjyMfGMoketB164kN22kf7oXoa9oFq
46	payment	190	190	190	45	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvNSMJjYCdYwA9X35RymD6AWKQZsSYkVsiQsZW6Cg4vo5VkWwRi
47	payment	190	190	190	46	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtin73rdgKqp4CsKBceoNTzr1rYcEHw7o1q2sYBTjrPPATiu94A
48	payment	190	190	190	47	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtbSKhxRfTTFEqej1Saivm5TwWtiefvjj7dzzPQptjn7qYg1SVG
49	payment	190	190	190	48	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juc1o2sKdF7ptkLVuNbbEJQvRUZ8tES1p4ap6BeqwmVbC7nfMeq
50	payment	190	190	190	49	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuqitPPyPu5bUuPwj4Tmacy8Ce3c2DQarGsMCCdAPyzZmi8ugXm
51	payment	190	190	190	50	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtkaLU8Py3PBh9hdxSQW5vAKSBteVzDuuiFW9nzwKMXXP9GYELb
52	payment	190	190	190	51	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtk1TyamY6L4GaVxAVzhgjmiJRtNch32AYLqcXUP5ZH5Hr7pqyN
53	payment	190	190	190	52	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtehvPeKUgBSQjDtTZaFVwR1GdscKqU6WEqoorfsqdJWvnXyBHK
54	payment	190	190	190	53	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuHeFtThM7rGxibReH2JQ7XrUpwXBzQ8R95rSE4hjCPYDwpfBBj
55	payment	190	190	190	54	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuaPVP2eH7MNCjwzBCzZuttszoMem1AW8UG3Zx6aEMkG7sybj5U
56	payment	190	190	190	55	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvRpd2mGGXDNtAi44gp2GA1o5TnkHvKKAvnQ7XLG1LDKEutYATf
57	payment	190	190	190	56	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtcRuL3WVrMdzYkwXoMLtRRrhea46NwJ1hcUeMQVkBmBdVLWZQQ
58	payment	190	190	190	57	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv29iUW9CehUrbHCKg6cRd8eUZQjbPQNR7nSDRcFffuSQ9zQBpr
59	payment	190	190	190	58	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvMRTNnVXHmhwGpTWLcjorEncvnFhnavvEi3XFrFBKYMivDp7zP
60	payment	190	190	190	59	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtYPS9AA6G8LUsCcwsbqyyAtyYg8t6Pmcf3r2osPNnreekpe2Wu
61	payment	190	190	190	60	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JukQRxwP1pUTtGGBJjUwhuKUFWsBDy5cVPQsnX4YHyPp4v3CeEB
62	payment	190	190	190	61	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuJb4c4XLuLrtp83dm8AHGPFkekmGjqZqA87SVUnG1BH1oYHSFm
63	payment	190	190	190	62	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuAyR3MtJaLQDZo7v3c71oa7yrWRUptAVEKsJQaA9YMXgykjbcs
64	payment	190	190	190	63	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtZcc6gmWPL76M2PQvvyvJUCZKczPnJ5Gb7nWCe7Y8kFGWeuFGe
65	payment	190	190	190	64	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv4x2NQacyA5ucAGZAB5AgdF15kyRi9ehFMQ861v7kZdAcKwj8d
66	payment	190	190	190	65	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvPwTd22ikN6D8KnXd2ucTaeSv9QdP7DJp5XTxvfaCTNnEYESn4
67	payment	190	190	190	66	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv1RnLStVo6AgeNNoCtU36LuWHPFj1gHuCcvnaJ5J8zTq2BFju7
68	payment	190	190	190	67	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JubRxc9JzF4iz7TUZxb3gkJFkrWqmWG8FuWAXLrsShv9peJNnxu
69	payment	190	190	190	68	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtmw1oVYpRhVaURQCL5YepxfVhpfcKpGKXWez4xtUPHe8rMT5zg
70	payment	190	190	190	69	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtcm82JXcMa9me3m2kKThwZPGSvjQveFCZR6JJqJkfLRKhkis8Q
71	payment	190	190	190	70	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuV17UYRi4Hg53BKrya7zrgUbNddFBzegrBc1p8p8VDeRXszEda
72	payment	190	190	190	71	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuSfDXcTLAeGe1Vv2B5TxxxqQQ5iSaVHZWHwGzQcY7Lr9a4zPJG
73	payment	190	190	190	72	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtt83EEw3r141HpiyLVUnQAxh2tfsbi27QamMW2jyNvbaWLgLww
74	payment	190	190	190	73	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuMtzefZwTPQ5b8p6B7EUFwG5pzpXRwktp5wa1ZDoJRJWsUf4c2
75	payment	190	190	190	74	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuFcxdQzTrDWEBwuGWQd9BFkGk4tGn47VenqdecUmLCL9CkVBae
76	payment	190	190	190	75	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuvDiDGhqERCMMEzrpQiLgvkfSz7ViP81j62BZRAHGNDqRz7a8T
77	payment	190	190	190	76	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvPf45k5By933rhmhXND1uBVZM6o9F5wL5GjLwJXwa4nLrxuke3
78	payment	190	190	190	77	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuhbyjqexdXbqhmRKqmYzfWwu1GBhqPjv9gQbKNMgVYsEiYCyKW
79	payment	190	190	190	78	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtcgKwwmLdEB9jGHDWmGQ6J5pvKgRPYcNV4577d1cRmb7JoAXhB
80	payment	190	190	190	79	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtzjbZg7tytRHyjMErp5neKR9yY6KktvkpCGZTeZo7ZkEtySWpd
81	payment	190	190	190	80	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju7Se9voUKBaDGwtWbqob11hZfEJ19epqGuYx4AuSmVBqKFRD4S
82	payment	190	190	190	81	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtfre4qzVBRrQDsr9CrqLxGzgZqyYTKJv5jXY7CEs8cFCS7Vceh
83	payment	190	190	190	82	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuU1SkcJ9SVo6uR8bwvvRsPdnNDHBKq4m8smBcq7VudUVgRNizm
84	payment	190	190	190	83	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuqhvrmB5DEoQUYjiJR8C6rXpqHE44eYqPJutF5F62kYxTwMB4H
85	payment	190	190	190	84	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuLbqs31mZbcC2jFR5wLbQqpWZBKDCXJYEQ1HhQt2F4indgZXwE
86	payment	190	190	190	85	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuYPAqWswbfbKegpHogdi1BYvCdpUm5bNoN8vDERVTNtCn5FXPa
87	payment	190	190	190	86	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuiUa1dKCZFFrzmvmuPR4UvV5qB8xsxeMgC191izE4w7dRoffze
88	payment	190	190	190	87	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtom8S2XQikiLJMgaJiBMX1mMvLKD8VheoH8jPwBMeogjhpCB42
89	payment	190	190	190	88	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv71pyNL1EwAcZbHGTw3YuotZBr4nMs6hZRveY9UYsFgBzKddur
90	payment	190	190	190	89	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtYVwVeFj8dyq3eTHCLFQkEnsQJXpntjdJgUEWfcpbgXZGXyFzE
91	payment	190	190	190	90	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JudqN9QzDQaVPK39xv3AzpFh5yB5pR6PFVb6CVcnDswajEs7ZYv
92	payment	190	190	190	91	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtv8Jj7a5Ee5oWR4MKYqnRTQy61j1xTH6Tu9HWaPVejUcT5CGnV
93	payment	190	190	190	92	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvCwSoDYSKd76Yq82qf9Upk3V5zE8pxw7GCrJ9GtHuVEC2vdRPi
94	payment	190	190	190	93	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuBXmiUpHmbzG8JhYS5LpZfN2og58H6nVkQToYnWZ6cH3yp9FFU
103	payment	190	190	190	102	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtxh6ZrSyayi5N9G1HbUeWR1bKdKunU54fCdeLUzJJiwqyaLx8C
104	payment	190	190	190	103	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju2abEcvnysvUrsjgpAUJWdbXBrKvsopL9VNf15n8hCfwuNYwWp
105	payment	190	190	190	104	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv9c9bEYLne8KrMNc5YNA8xaHfZFkkjTbzshCtSc1Y23P8EJKN9
106	payment	190	190	190	105	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuKb6AzA7jkFPRpKiLSUsAaazQmXsiNSLHFiZzDmRygjaqqNTqD
107	payment	190	190	190	106	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvJafNSnhv2iyadYhssQo3rJmXNXycEqgL8CLndg6288T8F3mqM
108	payment	190	190	190	107	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju4WyiD8Ye3MBhJZnVncfBgdyNeg1aBzjx1DcMP54b6hhMVqe8X
109	payment	190	190	190	108	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuLFy4whZ4NeLgqGPjZHjZY27F1aLVbkRHqn6J3yKF5Rwh7ZWQ3
110	payment	190	190	190	109	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtXv59xtQhc5TrNQpwfCTo3iNuhGav8NfvnfCAMotqfnjwsLBad
111	payment	190	190	190	110	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuuGgGNodjF2GGd8EWLnXiTzoomsnfMdw1WNFWhsFG5UnpRShUa
95	payment	190	190	190	94	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtdvZ37YAcWoRN1znBcNnJzfCv5ZEPX3d5RpY1FdWq48PXhLdBM
96	payment	190	190	190	95	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuefrEeMJfJjaDAdBVEWscXS5hHQRGxR7oGyaT8p3m1eiNxezAP
97	payment	190	190	190	96	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuoC5WvjpYaRpMYJ9L4yXb95DJE2YVfGCJ1nLcUrdgNQK8h9dHw
98	payment	190	190	190	97	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuQNGycmqifbqJb11rFo4DdchCTrmr9o94Vez2af8vfWEau7cJg
99	payment	190	190	190	98	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuddkK2fyhr4UYWNX7D6Aw5VNRm8aNjjA2x99Ln8uLAoF8z1SUu
100	payment	190	190	190	99	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuvzQPX9cpvMwsPB3ffjHibgBzgEgKp1EHkJHndgwSx5oVj8vVH
101	payment	190	190	190	100	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuivWmaQZ4jjkB5pHuWZ7KnQbyPrqwTmwFMMhgYy93vLQCuWJEp
102	payment	190	190	190	101	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuVeNVEF5yysQUY2Rk2BqDG3MkXmMcJ9cevRbryWkc8Cx26jntF
112	payment	190	190	190	111	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtaSauPcTMKj5Q9XUckzTiiDTzaL8cTyk9SLqu5no2GWe4zbX8d
113	payment	190	190	190	112	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juv1XFjVxMRmWXdNKvyBNEqJdyBcn9wmcqr51cwvCaEdmMamtjg
114	payment	190	190	190	113	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv8HqqscujsVNZCNvqTGdXZty2FV383o4zRKkwJLkjZWE22riWy
115	payment	190	190	190	114	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju67FodJFx6YJdh46n3PKoUwFnV9eq1Bb2GyBkgdQg6Ty5BceLB
116	payment	190	190	190	115	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvRPtu6Ce8vPWK4qtz2EJGX6gKRNLC3NDJcpEaCrapQiTi2yX4V
117	payment	190	190	190	116	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvPsD4FeN5JiWA7BmrAtV9AxmdCbobz7HhPh5oM92NDNffkSqzp
118	payment	190	190	190	117	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvF71di6hKRYNtBm6ekHrpy5xBBk6Z1aVLM2AJTHfH6pZji4tMo
119	payment	190	190	190	118	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtZT9w7YS7pyGdQzMReLs8kjBcsthBbnGs9UQ78DWw8ZUUf5HZ2
120	payment	190	190	190	119	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv8RCx4V7dfqXEYcebaFGkKiz7QAH1mNmocPM1QtV8ZyxKybjWZ
121	payment	190	190	190	120	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvK78AyaYE18PuDQNCnnGTS8kiXL5sBnVwUYPX92BbXhqnkVm6r
122	payment	190	190	190	121	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuHQ7MLKELQ6RdJVqwyJRLJnCAoUxw6bdpGcgWZQq1xbzfYr4Xg
123	payment	190	190	190	122	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv7FKMxpzEYborNBgemwd2MACNxzDTas2mqg46SK9fbCD5Zx55q
124	payment	190	190	190	123	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuQAe3Yxp5q7cruTeHw3tUmaAcx8rUghZqR7GsUfwyBhwUWEtRh
125	payment	190	190	190	124	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JusraoBbqhXjC1kN7dowBQZ32hZXkeNYjDJLe6tp2EfnJPgnREf
126	payment	190	190	190	125	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JubA8M6iWFqBQmiotmbpYbuFKJCBcwPo2SzCog7wygw2WaB6FVZ
127	payment	190	190	190	126	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuJUfYaajYMYLcgFw7GyrwMgsNdFgS1w7yqZn8Ak2xJ26Z8ARLc
128	payment	190	190	190	127	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtjsKpZjNj1kCzh26VuAigXw67K45s85MAcgQiJukpyJNdLztYt
129	payment	190	190	190	128	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvHYWQgWqaxpvekwHtJ6SLBrV9txMEQpFimCQ6t1un1gWP5Qy14
130	payment	190	190	190	129	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JumjsyjWiauumYkpj5y6EcdS4Umapn4B2F1JsSxCM8bvV5sfRvw
131	payment	190	190	190	130	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvS1yUR9NGfsivMx4DQq8LepEniEptiPw4f23fmn1JFfPDVAmS8
132	payment	190	190	190	131	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvEPYv8XBJR9X5aQzxxceQ1dpUvbCbSt1xUvC12nAowdyzJLjXJ
133	payment	190	190	190	132	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuJypDWuwDC4UMV2DMdYenUvqhaLyqUpDdWF8PiYgKh2ayZAUfZ
134	payment	190	190	190	133	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JttarZz76PuorJ4t4Cy9aez8dSUxGjkSS7FzeK8UaeV7KjU4fcY
135	payment	190	190	190	134	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtXodErTaZXXLcCaWvQ1BDF5dbqLJpig552qfy1fSQjjrsVVcKX
136	payment	190	190	190	135	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtozhkqxujQy92nJ14ri9vzyYCJxSqnBRMXgeVVYvMnxGpfxqDw
137	payment	190	190	190	136	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju9iin3FVMazBu2AtW7PuXwWv7tWCJnbCuSDEzwoprsF1BC3Dw8
138	payment	190	190	190	137	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juxmxm7N22a9PdFwCDSiAbMqTC7286weToDNQK9M5u2Jb7YkCb6
139	payment	190	190	190	138	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju8N3nkK6w16wf3tVsauA1gW7bpkMvjqNAYbktyNFTGzFMrnmdc
140	payment	190	190	190	139	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvMrh9jSXYfJbD7knckoTQ6zBhsXWjwsXgPGJT6wbofsfaPtNQW
141	payment	190	190	190	140	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtbCt7CJLJX3cACAwPdsvD35Qv7KcAheUWmBpvgD5RPeRj4Ryha
142	payment	190	190	190	141	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtW9L9a2vYuQQ96RbtNrfCPqcFBKorg32SbdFPfJkk12Mtyp5Y7
143	payment	190	190	190	142	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv2sjTCscrLQqJRNVYnvXogctN7smjh6AgfP17yL25D8ZCn2axp
144	payment	190	190	190	143	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JunrmfwcRUiEy2h5PgtZJb4ftUcTmUB1uK3MBrpHaMbd7G81rgp
145	payment	190	190	190	144	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvR4V1VBUUBHfLSd9giwmeRJYdRp1bE9JotYSuT3ZLvHt7psAzU
146	payment	190	190	190	145	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuzgETT2pxoWdzVJK6gJ6YkbpiRCAXnJJn8qBWUSy7wwEFtBJL2
155	payment	190	190	190	154	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JukttRYoTQohTLezhaWmtdco9TVxbBBYenA6qyFcfVSJyqyFdAh
156	payment	190	190	190	155	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuFzNP8CEAd43iZWcif4znQSBgkszYhQeSRdG9Q2jSkEdGoeMs1
157	payment	190	190	190	156	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JudGxt4KiNXGbxh9FWePMFNUGwXJdtvHPYAooCsV7e2d7HbTT9W
158	payment	190	190	190	157	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuYxJDxvJjJUERKdVKJinWQeRUrypj4JAqJaW1f6msiYTZwQ2Xf
159	payment	190	190	190	158	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtfYdc32U4JQyt8kScqPEkFFwcyQL6oTasqRkZ1TTS7NkxVwR4t
160	payment	190	190	190	159	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvN2JWvkRdSKeK7pS4CHKuVGSRTxL1An81Jy5AtQhJtZVR5db5Z
161	payment	190	190	190	160	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv9J5YE3Jk7T6T6d798dsbdH2C84UVfELownvRoNUeMLfJU2fpv
162	payment	190	190	190	161	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuV47dxKxYMotLtcQmHrHP79SPUSs29eMY1MWmHrEGVLcYjWPRf
163	payment	190	190	190	162	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuTneSvaZ1QB2WiCRgtZekRwWvbeFce9WoPp9j4uJiXAy6kaqAD
173	payment	190	190	190	172	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuW3v2smvLPhrhfCAy3r5QSZdxKVS8Kjd6uAZVQLs7FR3mmhQSx
174	payment	190	190	190	173	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv1Vb2sbeTyp4xPduPiokTALAUALGmjWP3XYVZeRb2Jk6LgJkPA
175	payment	190	190	190	174	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juhw9xi7DdFhLXLabAqoJJBHps6peDeG2aq9sZJVKzmdWcoHcTQ
176	payment	190	190	190	175	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuvSWZLSfkRALcNvA3dCvdnv62gpwfSaAonHD61q5q2XuTydTHt
177	payment	190	190	190	176	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtzZqyEdoRZXCbfBgrUhjXb2c5M3peKWfiEmhWPxtzSjgjsZWJm
178	payment	190	190	190	177	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JufCoXrWKGejJxXswUFx8kKcMmR34s26aCmcWreVY8PP4NfMKFd
179	payment	190	190	190	178	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuqeXPXEi9HnFSeeQFDRmq4y1weoj2CH2BfPvYxnQgwBZ8ryDgE
180	payment	190	190	190	179	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju98EPybtUU6ocXURfKNMo65RD89cwsvEp5hwvbMLtCx7mo9Hpk
181	payment	190	190	190	180	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuTK6fZDqGpELrH7CPRwhKpEvyQjFVpESwDMooS4xeEZgXFM7Rr
182	payment	190	190	190	181	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuFG8rYMSz65KNfJwYwq1BbmVwA4Pp6GystJ1Gjy8ekHFbWBvJ7
183	payment	190	190	190	182	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvLJUTAWobWJGXmMdSUTfqYeA9ynBijB8V388XJZYTcCbXyvbsv
184	payment	190	190	190	183	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuHV7NKZfcFKDcnCf1LmRqD16S9frP48MWjUisXM1UvqAyKz4Fu
185	payment	190	190	190	184	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuL3YrqKgKFrW8Toq4GXYeyii33WCQXrjQyGZjRVhj8W5h3EXFH
186	payment	190	190	190	185	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtz6mKAVDtBgVidzBU9LWAKwi6yKeNJPZvLHkBsHnmu2kKGFYTg
187	payment	190	190	190	186	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvGBZqNtfPXjW5aeJPaBsvDQ1PYFCWdSLtuCpyTGEoNhTiq9Pfx
188	payment	190	190	190	187	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvNXhfkX2wT7MKTtBZCfuDJ3u955ym7ZP66YFwTzRi3EqRJc8m6
189	payment	190	190	190	188	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtiStzhYfUiaTU74ThM7zVfzWPZ59ubtxtSKBE269ogCiHYTZX5
147	payment	190	190	190	146	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuauhuzSAwsA1V8MsxEoaEfofUBkh22pMQ6Vbe95hAbE3d3nF1W
148	payment	190	190	190	147	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jui3pdRaZSG8KG567VDRX6mk4Qh6JWDRxck9QGFAqq392jg3RUY
149	payment	190	190	190	148	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvPEMyafpEmntEyAMs1iVW9PCqvvbb5HApuDQPTLSXvrZ55GnL7
150	payment	190	190	190	149	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvE9G5HdDxVaCZHK8VUa75Dim3UUFz6jT6X424vTwiBuDAVn1kt
151	payment	190	190	190	150	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JutqyPvrp64U13vzNo33t6DSiTKQsMj6unStGRydoHyU9C5TWx3
152	payment	190	190	190	151	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtw1t2rb9ieNtE4DrZ58iNQ3R76fYwu2QYLwHJP7Dp6PVNXNeAi
153	payment	190	190	190	152	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtaB9E3DTGSei9mX5nnfmw8oE1HhJYrNtarTfeQn4RQG6xzRRBm
154	payment	190	190	190	153	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvDaS4HVvy95g52fqy7qBVjDf5kPv2p1ddX95zLfsVXu2yUVZ98
164	payment	190	190	190	163	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju9jvKNqVgrfjYHYZmeKp6GDZ41XM5vGrj3uF1qe4LU1r7TaES8
165	payment	190	190	190	164	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuFQgmHASheh1WxjqWp1RRyTZZJSyGvnZ6hDhStjqTWagP544sW
166	payment	190	190	190	165	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvS1TMAZ8PQwhnvLxWq7ScYEbstUq9ewiny6Drt3Foa9RKFJHXp
167	payment	190	190	190	166	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju6f3KBvm8QCqJMHWF2kfciZxqtgNTBAUYZdfPvivRrP7ZAiccA
168	payment	190	190	190	167	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtqdLaesnrLW9TTb7jpfdDZhpj6F88ziRKs1pciyGd9gRmziQqL
169	payment	190	190	190	168	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv5yoiFHZD4LpKLLCoWyuk61JEzh5DJNQWcA9z9TCbJnJjTvNBo
170	payment	190	190	190	169	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtgGXHTjDdkMzEgk93GsTiATVnn9x8N7cPT8S71CzXvbTX8ZAft
171	payment	190	190	190	170	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv52q6cvEddgdD8PMzeHE111eX27qLz7XZdpoBq8Bb3GtTYMxFf
172	payment	190	190	190	171	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvRWpXquy3KaL3k1d5LNpFq4nasyGn7RAcXL4AZ8Rbo9XoDoSM9
190	payment	190	190	190	189	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju2WPjtwCVrus5dbR2KDoRu1obELHMpJq2jmKHH57fVe2uGNrBe
191	payment	190	190	190	190	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju7dK88YLkNXA5Z8tn1rG352mXNHoZciWRbwziMFJx4zctELQHY
192	payment	190	190	190	191	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvAydDDuNqVgF1ciZoPKcFWjJRZJDcammvq1zQTELYmcAoVGYcE
193	payment	190	190	190	192	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuCcfXCetqjrArwZkFPgudGDvpxiwieZTaWaRtYtJdTPHq3sERR
194	payment	190	190	190	193	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jun6e2RJbaKNZCgbi3ZoCfKxXsFZW87KsGn9wxiU3GvsVHz1zQU
195	payment	190	190	190	194	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JutAFScSV7vrrHMxqcmHrgR6EGn13YHW2WcccPMgwTqRwqsqd69
196	payment	190	190	190	195	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvF5FvM8T43A7xeZN2azBYzkGq6D6V14X59wqJMJZtXwxWMSQGi
197	payment	190	190	190	196	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvGwQ2pKQwTs4p5vBMWx6x4SabEYrsqLcW8jBbvKvf7daSd72PX
198	payment	190	190	190	197	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtpGZUX7ipbsxTtKWKHc6nbGufhtK7TgETxsFLRT9rpLfA9YGP7
199	payment	190	190	190	198	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju67sBKs9wJT1HGYYXAQvokbHJfgJe6niY2ctfdvBbuFwq9ro9Q
200	payment	190	190	190	199	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuE7vw3gM6bJouX21dDKhL7JWbUbfrzyW6LqbErRmZF9CamjfLg
201	payment	190	190	190	200	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtsmCyQvxQDmcfaEZFofMNZG5VqhSyzTwPR64vDCo2B6hSQWpeh
202	payment	190	190	190	201	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuzScsYNPTG5BkrPXbzSjehK7Tq9BXmuP7qTWh3LHm8xZRgCiQb
203	payment	190	190	190	202	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv3XKiUVHKW5NNQqRy34qzheE8SSPKrbRcRPgJ5McUp4hsXHZrh
204	payment	190	190	190	203	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuSugejVm7j9byCATwUQL8CLPSp6MfrsMLyiRbMZbKpjjEawbCZ
205	payment	190	190	190	204	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv49a1c8LsSW8sKTriRmxm3QuPDmJnPoFMQ8JBf5CgpypGBzLYH
206	payment	190	190	190	205	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jte44EMY91JQq3dVJRNJNBHrZMpjjrD6uW7Au6XybWTDiVB1U66
207	payment	190	190	190	206	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuwUyCTonrRzpYQyfe2z1Dn6HBiCVXgBaebC7jSbZfVa75WwyEY
208	payment	190	190	190	207	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuLsTfxtz2YmMLeQUStDuYbWUpC3KciZShgs3EByvhXaXaCWgH9
209	payment	190	190	190	208	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JucAaymYXNwqPNvojhCkqZDhVwsgiGfxNz2Vp9T9WM33qN5VLYV
210	payment	190	190	190	209	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuPXw7fvXpADyJNECAPBKZxydgmqji2pfMZ8hRh1DKYJUH3RehB
211	payment	190	190	190	210	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvGd1gQ9XNb2bKz4jGEQCbHL9RvwUK4PXW1REiubJGG8mW4VPPy
212	payment	190	190	190	211	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv4XHKFgse56VVxtfwrB35CZQD1fUZfAdPFTVVTzavTCG1UAoD7
213	payment	190	190	190	212	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtYMWEHmfMpiLRVpb7jLuhsFiy83LVJygiEQtQKnDygHAaQnGYb
214	payment	190	190	190	213	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jug8mNQNvS8X1Z6v8ATWLHAiSLYjBo2Tk7G2naAyr9t3DEFmoz3
215	payment	190	190	190	214	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv2X7qQUgzTVdNvzK5gExNk2fHQUCbBrFdgaJwyHQGgPvj7Npxj
216	payment	190	190	190	215	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvAQ37Ra683tuYUu9SLQKznxkAcUwd4orUZf41J2tsqdbrNigYj
217	payment	190	190	190	216	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtZSEymNsinjhVcopfWLAd1WRMnEbCXks7CdNxxBA7i4FxS4sBP
218	payment	190	190	190	217	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvKGREQmSu4ZeCCETmK4AYcn6Bukz1co9UbmL3rAgaT3GaLeCkk
219	payment	190	190	190	218	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtp6wSkN2KstSPGJykGVwnVqPi2CA3dJufA5xMRqGSz4AykiRCb
220	payment	190	190	190	219	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtiuKwVEDXAqRmR4iBbMiKLRjPJBJwMHvSnhpX1s9rKWbttdTAY
221	payment	190	190	190	220	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuaadAsMuUfzNQ8PWXpoESWJgu7vWNcK4u84BJt1pbbWQNP3TNw
222	payment	190	190	190	221	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv1P6yhak6xKMRfRXhYKivTQAhNexJAVvbw9tcDMnQwmH2z3CzL
223	payment	190	190	190	222	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtWy8JTBYgVPEVeBpKrJ7PxMuwpsVwZz2Up7r7uM9N1dH2xSWhe
224	payment	190	190	190	223	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuiPTyvt6Q2J3pboADpg2cCw3ZgZ4attv3c6Miv2aHvjk8EwEkH
225	payment	190	190	190	224	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvMmS3WNgfDzXj397SZkcdkDizGtz1cPsG3yBKeTbmBTHPLKJDE
226	payment	190	190	190	225	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuBEcmLeH1hLFtKyLS1pjdYNoeoHjoofbbY92yUr57sYasufqZ3
227	payment	190	190	190	226	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtv2GVMo1tQ5ff7bSc2fh4snRXfSxUdTDmk6adKvrfyPPaPXKfn
228	payment	190	190	190	227	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuiSi9Tsm5WorfE3YgBGccgQT5ZpKJBR61J9f3VS9ViFuH2nRdm
229	payment	190	190	190	228	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuArjqgwbUsDMmoTProaq2rcyVJ8egUvb1HFXRo81k8Wbzjqskh
230	payment	190	190	190	229	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtYUxqwdRZWGFyfRs57hjEuTH2u6Qh3K9PmQgtDbpQvsREohaQc
231	payment	190	190	190	230	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv6SNA7UbTBunWRzs17G2UnH9ie9x1uGwQwjxYtpA9ty9eTXWfw
232	payment	190	190	190	231	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtrmbjRxS2LBwaztwcQVMKcjSr1htihMHFK1nnXbBRrRASQyTVC
233	payment	190	190	190	232	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvJj43fH37yhivWEeat223xM8ysMNXFHusm3AxZfwsRHPw6mLax
234	payment	190	190	190	233	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtoUM5Wdn5NS4vcg3vmBUqYusVF24WeTSjNnWFxtEvXgF93xQsC
235	payment	190	190	190	234	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvReKC21CoYXDfTULX58qfHTkKGiyNb7tH5SbqH77G5mxVSDrMW
236	payment	190	190	190	235	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuqvMmegCPqdjeZ1Njwn95qM11qDfgogbSM5Xft9zW9kPuzNULF
237	payment	190	190	190	236	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvAppL7YEHqQdpPWCiqKaHkyqYCbm36336AmGg5c4MJjYw2P9Gs
238	payment	190	190	190	237	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju2ZBVK3Fw2M5ZW7r2NP3vSA6dEsUsc3xVpvL7WDNUsw17FGnYG
239	payment	190	190	190	238	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuVumCELjgswfvgTFDbmYKh5wPAVSZx4nUDziuhaJgP2nKBkZse
240	payment	190	190	190	239	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju71X8zvoDjk78jdPcGK8wTdc8tMNpzJ4ais2LWFeYmvUS9braD
241	payment	190	190	190	240	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuKibsby2TQ3usyrhiRZA8Mmf2v5HnrgmtALwTuv5Sho1vnVCNf
242	payment	190	190	190	241	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtVZhjibaEd8pBe6z2qa7px1vzWW9RUmpV7VH7PtHNSu22i93H6
243	payment	190	190	190	242	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JthvcfJD9ycvwn6w4jHkmUVPa2qtS1RSNNquL6QXu1rvi9gr4uN
244	payment	190	190	190	243	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuhCgYdXgxB3M55JCQc9fGzcfaEtbQue3f5ibG2CcPJoRWxXhjd
245	payment	190	190	190	244	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtfyv5yabVszN7P6Z7GLT6rstXdDY8zpuvn3qtn1qop8QzhGwN5
246	payment	190	190	190	245	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvN5Zfw8HDzcUsxe85BqRwAUfaq9EMMSMkBUFWNpVbnkhuKdDGy
247	payment	190	190	190	246	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvGq3Jp8Q5HMyeg9gJR6dtkBPmjuaa93p56szB8Rs5ExewfvRmM
248	payment	190	190	190	247	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jug1YN29uj7bhho4Spgte5rGFKj14XNZVyBLa5zZvTBKzYHbfa9
249	payment	190	190	190	248	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuAg5QRGjC6Be7xHVuNGuhJJaanaR72jKKpyZTWYv5PTpbMxqCx
250	payment	190	190	190	249	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtkpdFj7G1NoisoNqj5LMPj4m7nQZtswjCFLDixdiVjrQ2Poy3y
251	payment	190	190	190	250	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvKEuJ3stAR7SYgh7ZCpXm1eE72gebvA9tyKJcsVMXW9oGxSwRV
252	payment	190	190	190	251	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtmZwubV7aWU8ueFwjJ6RmtSpRoKfBBsRZGiAbnwMYBXzaQFu6o
253	payment	190	190	190	252	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv9S3QRtAYSXpKkE8ZsuhYcjWfy8YcBPdkekiThjAHqHwnsM2t5
254	payment	190	190	190	253	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jupwmp6nGDdKKU55RhF3nDdsxVLBfGUvcpEeRv1cD9UvEBA2FKj
255	payment	190	190	190	254	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv7Wdrf5CLikaixzFzym7nVqf66tKFGCFr2P29TJsEqfncMgurY
256	payment	190	190	190	255	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JupRVZXdT1bWuCX7aJXUGAHAR53cnir4XdDHm2pPZRBHFGYgiDA
257	payment	190	190	190	256	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuEoX93CwxmsjmvVoCGkL6zA3KMh9RGB8LgECph765BkWaaebCv
258	payment	190	190	190	257	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtiKnAsBfKMZtMWCkWqfRiDP3MfU1VdTmBHZp7d7B5esu4TDsQc
259	payment	190	190	190	258	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvAJdRvP6qw2voHNcc4nUv1njxrFwggLQugn3zRNFxSzbJg74xy
260	payment	190	190	190	259	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuhE26x4wPicrQseL9Hk3j7QfxpTSDu7R6r8paQKvPR2UNyz1mW
261	payment	190	190	190	260	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuZ12yjqHFooSQYVqbhDGokCRQ4E18AoeRfBa2BdsC5QUb5Ci7c
262	payment	190	190	190	261	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv6DNsRFEaNzih6vahxGckYzuXCcL4bxNW3AQqVHSi8RMZ3pikz
263	payment	190	190	190	262	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuVtCcmwcpCyCSyADoM5DtDdfHaES9kt8DjJxK13PhtGGHWDytS
264	payment	190	190	190	263	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtiJESdUwZGxzpr83TDteo2ZhLFxMZaFggdKT8DPCLNnPUEMQem
265	payment	190	190	190	264	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JteFQbLyMue9UDzZHrCzVAbFWKK6pgVMKQyV4uikU1YB54AMxKs
266	payment	190	190	190	265	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtvEeyUXx38neeEycQuS8UzwacEyfE3qkqGXFfwa4HjGjrstRg6
267	payment	190	190	190	266	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuYEirEB2YWiydxkZwJEcCWVTdeFTGwkdFvtVAxd7aZxEjJpDqi
268	payment	190	190	190	267	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuuztrDERoqFNderfgJFU75D2qt1Cg1aVvSxS1uHqmPphE9zFx4
269	payment	190	190	190	268	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvKZRN6oKMirtsHumARA99y4szbhEWvF71uuy41JAsnrEyuZJnq
270	payment	190	190	190	269	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju6Dgwdv8CLw4Gk7sVSsFrZBnSTyQUdJT45RmMEgUAWFNF4RabZ
271	payment	190	190	190	270	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvHLB98CjanA5pZYWF5hpPP4Ea3nTkpj6D4nkZ9NTpYUTi8twur
272	payment	190	190	190	271	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtyRWTLTDpgV2rf3Ua96JKZkh29sVXgcKWgiuJKfLsper7eMoQM
273	payment	190	190	190	272	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuRtNNpkFyR67SpKqtWGMEVNmrCvjwf1ckH2LMiKnrHHs3fD3Ai
274	payment	190	190	190	273	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuYCNfYf6WEPyVvaRpyrVchZ3imXZLbbXt3pxnsRSp9BbBRBvwK
275	payment	190	190	190	274	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuDbBPFKWETtNmN8ZAGK7N7KqcmJ2dN9ieSvdzrZqRxagKt3ncj
276	payment	190	190	190	275	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuVJU1tSjhtUUrPWYn4E6Qbp3d8MLH6gzYSc4fZJfrt8o1eWzKH
277	payment	190	190	190	276	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JujmZJMDPLrTMhT6HSLg4fjWEBrECHKUgRWYTECEJaegQ9MyRcX
278	payment	190	190	190	277	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuNRMfGxLv8pbAy8SZFbvF3Xsr4wycrZqykQLdETG7d6mECGvk5
279	payment	190	190	190	278	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jukz6N3ZZXvDfzW2YM6WZjfoeFjzWgKjeyykcb3M1hnLe1f1gnS
280	payment	190	190	190	279	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtbTpKfPg2CWyvNuoFTirPySuLEKCC4Ef7k3KTwJ8ckd7QcEGiz
281	payment	190	190	190	280	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jut99YJ3zmvCLHm6T7JyddrZUZjtZTg7TdCxF6qgp15hfRmeZGq
282	payment	190	190	190	281	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtdzUt2fv7uBF3ATQuyW3Na8jzpZyWwpeJZf5NHBn5fyksEGgM3
283	payment	190	190	190	282	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuxVkgAkukGVCuZwwDs9QCztnpHXnFFNo8xvVCmStbChEQ5GtRT
284	payment	190	190	190	283	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juws93fh8o3WaHDHwu2AtzZSrUiMrfYHEafKxp9RSfbLaHErnzi
285	payment	190	190	190	284	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuaHkBqth9h3dK9ZcYUDWm4TYVKKqqu9vnLEvyPxc1PCPmcLGwc
286	payment	190	190	190	285	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju2YvujCwF4KYjZV8RjZ3rQEzeFY7gXK2jBnWEK9kpHhAuxfTG1
287	payment	190	190	190	286	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuykYR9nmdhDKZhrN9jCZsEMrESieYyFRv4DrNra1sHnyYUp4sP
288	payment	190	190	190	287	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvDfAJtGRqMEYMVGXvo8hYn2BTExmdTkmsnwCnShQxPYwEfKxnA
289	payment	190	190	190	288	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtmZchQCtFJiTFiYX164MzuxzBnFASPuYyfh1azin8gt8MkwccB
290	payment	190	190	190	289	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuimoTibeYmiz2zzQgkTSXKgJKuyFcLZSGZVD7mcCEoa4TZdrMn
291	payment	190	190	190	290	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvNs5FmuVMbRxNdKjnSPvjmhPeU38brKuLFq9ZpbEedjdVu8ZMe
292	payment	190	190	190	291	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvDjuziWm5Sp1wyZhf6coyV37d5GzJ1YFq26ZjR3AoR53mBBqQo
293	payment	190	190	190	292	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtuUNjRdktrqvSsiZ5KK718EXBmLSppYVhkGsbao3wd1nHWAjQt
294	payment	190	190	190	293	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuXJCZ597VTtcecexhRhQ7mpR5MiRT5dMiL5Cm9KmbiLHBKXu3i
295	payment	190	190	190	294	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtgCgggVEyVepBVHna5FYmFonxPAvMQaZdRfEUVrS14VZvFeoTw
296	payment	190	190	190	295	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvBwkmaJ49xDj3vzAYCThnNf77WCoxBonPxje5MqX2Z1YgqcnLs
297	payment	190	190	190	296	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JutLftvbtifamgKm7XY4sjtSWbM5JvUTVzHs6Gdd8XSL5vqX6ir
298	payment	190	190	190	297	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv4Hg1do7U6oKrn8xQxTJKrypL4BMCFERrgF5YDbTe1pYLbTDqq
299	payment	190	190	190	298	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv48FbH2nm2SNkQx9NUoab8ZwtNbyUTRK9eK1nfqbdX77mUwKFj
306	payment	190	190	190	305	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuNouokfAGJU5KMYjTUpAe9nqXKxzpN6MjqCVoeXtUrvhSZYzaT
307	payment	190	190	190	306	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvFqryTyf41BAnLNQYU3D1rdzGJvswyzai8aR8NtQc1cE1BtGzU
308	payment	190	190	190	307	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JubeikZYsjWUuTPwyaQkKDxHajCf2cTsi6GEihCoxAHxAHkzgCC
309	payment	190	190	190	308	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtgjr6ws3n6kN7RcL9ofaJW9b4cUEhLQbWh1hKQAmfxnqsUzTma
313	payment	190	190	190	312	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuhBJamHyHUDvgph1mMt186GFogb3DgqKeDjAThpDADZ8vFYvMP
314	payment	190	190	190	313	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtnGDRbUnHv6iyfssiVFAh5W5CY26TUcFFMFHuoDPRNrg2xA4Ue
315	payment	190	190	190	314	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuwN6Z1zQgApia1BEzdFbigJQxpriBhyCehF4fe6FyTFgag7KbZ
316	payment	190	190	190	315	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvD1nWRHREU39cawCuWdqE3i5YLifiUXCj6CkmTrzUZ2mrFDfbA
317	payment	190	190	190	316	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv5A3YvjRfaZLm2hXLqdQKXzMxAPcfAVN8L8n3YeLPvMVRXmgFh
318	payment	190	190	190	317	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju687zseeHaP1JTNKsFs9kw65DRsxD28LrRuBSMeEtBoJ1owyQ9
319	payment	190	190	190	318	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv29WMmgtUwP3ReGz83rwzu7QWWx1Bqqa9RhHVeExYVarCnd5qu
320	payment	190	190	190	319	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuMTTsJqqrTVPUydg9PaBPttCk8CjWWYToKGCT6EE8diPzRvu7w
321	payment	190	190	190	320	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtwQuk12fndpxf3dGGDMUaT5EUWWgTeWQFmxZDgqdm2QGZ3Dnop
322	payment	190	190	190	321	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuYqFMyyQnvjr2j16UPHag39VY27ukKTph44LJGR84K3TYt1GkY
323	payment	190	190	190	322	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtvEiB5WPd8bKKLfHry2kA5hBCJ7qJUedfhrBmCm2rwivc2kxgh
324	payment	190	190	190	323	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvNQmzVJTLsUyiMrkUfAGDm8AiUwYJcMEpd4iwPtPhEwz5Qp748
325	payment	190	190	190	324	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuE8sixGECw1oACtSdWZxZn51DtWEaWwuvRq99aqqLFNkXi8TDt
326	payment	190	190	190	325	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvDtAFQpK8WiiryrBZQkmWSg7vmi5YRhxgx7Zzq4cfmKaAqYHAn
327	payment	190	190	190	326	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JteUzEzbBUAvecYLqXqARe3ToEYJ7sgFxHW8STRWQYYRY95q98d
328	payment	190	190	190	327	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuztCRJSk12JffeR1kwUTx1QyTm6BL1AJVQhapBGxWivAVW36dG
329	payment	190	190	190	328	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv2vfkLC8ArqWvPpqkvFByB9XDRvbhi174VoheM6uPzQmQBFxdG
330	payment	190	190	190	329	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuatjBNCn9gzbeq3SskLTKqnRW3nGXGnRJuXzN7h38zP3Lw4nhj
331	payment	190	190	190	330	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvEzsGLQWT1AdQvos7gMr5eSZs4mP8mHHM3JpBQXHBvarZrEdtE
332	payment	190	190	190	331	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtyJdo4esJMToMqVZHRs9ztMDV1viETZ9N7feuZDRrZe2GTA1jc
333	payment	190	190	190	332	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuAH3EsJ9WwLpnbBNn6ZZhgkK3KBFnygUb3iNU91sxU3qbgEhAB
334	payment	190	190	190	333	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtVSSrx4QquTLZMtVmEn94swEFe1bhKseypK6P4f4nNV2QUKMD6
300	payment	190	190	190	299	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JueHundKw4WdeMHXmQCzrG7nQGckixf4Fpby1DAw4dzyQ6MH1UW
301	payment	190	190	190	300	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju8aMWHj9SisHMSVoWtQiJrEALznt9EfEfLbu6iH9VyCqyjQdTZ
302	payment	190	190	190	301	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtoABGM3FLtGExXqQgcs7JHqg4TBoHCoBBqGrSPSQYyQCq4sFTx
303	payment	190	190	190	302	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvEGW6zNKofAEMnrFR4Li3FxyNVFutPs4Jbwa9xUr8jAau6DW2w
304	payment	190	190	190	303	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuV9NWRDx4B3M9d1neLjfxeKiSrA8SMPPGM97mgj85EtFXY9e7E
305	payment	190	190	190	304	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtjsfnP8uCcqHu2B7a8y1zQ2YTTUXgByDct1TJiEMhYB31dtdtQ
310	payment	190	190	190	309	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuPUTHtu7WBrjExHtqNLAU9oRkbXYkc4U4dXREVw6Y48eRg5BgH
311	payment	190	190	190	310	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jte5SFALp6ZjuPWJpBnMKN9FgTqPk6K3QYLR9orqPcuAhRKPw9h
312	payment	190	190	190	311	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv91sP27pHxQpGc3xyxRma5PAJHXkeTFGKSFUwDiVo4ZvP4Lgtr
335	payment	190	190	190	334	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvM9vt5u8HQG2PtkfCSGEMnXXGapGi7Qhtbk9RhHZjYpCvVv1UE
336	payment	190	190	190	335	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtaZUQWn4cLuatS8vHZbqyhFgpbHktG7NziVUeJL4bfgrZBv7f5
337	payment	190	190	190	336	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvFEm4ytR4NSUhWrz91PoviRi6RvBBvTmWLLZewEx3g76udnY9J
338	payment	190	190	190	337	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv9Lfu9fNAtLboYAW5tWFth1fG5sk9pzqKu2JQWr1uMcyJAGhjN
339	payment	190	190	190	338	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuGpz2YU1mTsP6bjnEh3pimtAuTJ6giRsAyQQ5XgLEVZez5uKxE
340	payment	190	190	190	339	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuG3QLNTgbEwFEHXVan9UHggAfgETq3eQVBnq713mRa9mUA2bDx
341	payment	190	190	190	340	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jurw3TU8m5xsMTayNroT4gixCaMur34Vc8NBhS4CUmDwAzHAyjN
342	payment	190	190	190	341	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtbKnWzLxg5ZjoEmZir1HFiYzg69t2we8gXYLB4PQYyzksAudLM
343	payment	190	190	190	342	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtoxSrF33q3a1bLTmdGG8uMo4T15FBiBvYqcToLwevMPC4R1G3d
344	payment	190	190	190	343	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju7Sqv5wrU4KfJtjoNCa2LnEEBYgJQyRZipH9tWXPFFLmwZvGR5
345	payment	190	190	190	344	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtgZTbHZ59ENdBhrSUr6LWyZguBqVjJ1mMQg969wnBq8N2PQdAg
346	payment	190	190	190	345	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jung1KRGWPEboxAd4syYknicy7S6w8ypPMb9mpvJSfosTiDSwUX
347	payment	190	190	190	346	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuSMrXy7CseLegA3emSLzhdrchp24Kq4GXRycWuCSuxQfBTd4Zv
348	payment	190	190	190	347	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuuknSGdb61VF9bC9K1YNd8w4gkZGRPE5PFfNNtPcWaWSJAtK2Q
349	payment	190	190	190	348	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuMEj7UNv19omnppC1NkX2aZJ193i9Hh5oXzRyCBvRsLt9cokWw
350	payment	190	190	190	349	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuVipsLhowkMBmEP1TUfrrjA4pU8bAtZ3hstBXsbtze4gWXgNNR
351	payment	190	190	190	350	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuRiRkNA2emBJsvpCxPj1Gs4KG942kCiP8iK53zYjdazPTbPpbN
352	payment	190	190	190	351	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JujRiWH9qWAbPCejDXzJ3oSjTNKqzWQ72MSmMxihDPAsmtAwsLm
353	payment	190	190	190	352	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuM9suf7mZyUbnn8RBW2CPWmL7mpHUwMVxNgkhKWzUDTMgTk2nX
354	payment	190	190	190	353	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuyZFm45SfC1gDVHMoF6p63UgS6g8joVw45NnL1EtqeF7yVKfN8
355	payment	190	190	190	354	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuzBMRPHFGmXUAHKv9dCUg1dCHxtvdTVj7rBJC4VbFDYuLzjiDG
356	payment	190	190	190	355	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv7YA1ywdMDTJTB8wPFJXkEMKFhvygCPhsPF2SaQS2fHm84qUBP
357	payment	190	190	190	356	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuoNMRaFSSmim8LTT2VpWAFWShHAeRGpDU8DZBNyj4y2dAmMAoq
358	payment	190	190	190	357	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JueWAu8UtZvZZdb1Z7dKUZMdJ5WjHBzu2bDJpsTGXLZaE4rMDQn
359	payment	190	190	190	358	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuX7vbxLZtonF43N3rYYe53CKtsYtx2Br5u2qAeTkjTivr775gU
360	payment	190	190	190	359	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju9rq18nLEQVywxmnGFMcSJTX6VDKMZNo3rijH7LHVdWdoaztfr
361	payment	190	190	190	360	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju42bysrc4xom7MvZHLjekL687eH8xuqvWArXYvhZN7x4Bh2jVv
362	payment	190	190	190	361	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuP33ZMqtMC6cTTgC53yBSatbYfxYbYec1k1K7FfQA8Rs45ryv8
363	payment	190	190	190	362	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuJrCddCDBsHuyMW1xbKCp7SHeMG2FGq7euXYqKziJCTgaADTbc
364	payment	190	190	190	363	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtm6kZq1cr9FcMfyPYfwkKjb7Auo2MFrHRBdBTWbfngwnLWSX2W
365	payment	190	190	190	364	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv4kJ6VDopHFk5moNTUQmMa1hEkMkuZrTaztmp4AvyaJibZcmAR
366	payment	190	190	190	365	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvLH2ifdXCRmh57eJST2fHXxrgG3cjwqT6AMEionHS3G5z5gSoN
367	payment	190	190	190	366	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvK6USePKohAvSAkKAe2YknKGsJtL79Hd9DWDC1WXtrftvLYvpx
368	payment	190	190	190	367	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv5D43aiXt4Xe8brEJBjkqc3SLwZjcK39ZZpDaiXSLuJzhTJ79d
369	payment	190	190	190	368	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuLPFBxMTv9GnSCtHukQ7ZfPmRn2H2CpXh8AocLb9DeRorpLK1f
370	payment	190	190	190	369	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju222NRs6J1hkTmjxqNt4pt3X2KTRsjxRjg5E98HMTAgZtTcxM3
377	payment	190	190	190	376	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuVcUpsoz8L2Q3j3Q8edKMePJy1wzMa85YuPzAEBan3WsW5Z4BK
378	payment	190	190	190	377	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jto2Th5mf7kmEVtaQbeZdviht19XQHTzuqhXT5WyUhsUwgoX5b7
379	payment	190	190	190	378	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvDomj8y9gnpXRXGc9VbW1xixiCPavFZPzmgVs1LoUhtRfBisW5
380	payment	190	190	190	379	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtouiLHZzrDzV2AV1ChX9Uoo6CC3TdnP8KYyqmmCbsvTRivs28v
381	payment	190	190	190	380	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuAsfaGAKYMLPEZ31yzw99jWUjdKhMeV9bqLKNSHMejryEk5W5m
382	payment	190	190	190	381	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv5SxJa5ZMuxhTUtue9M1zrArFzabuuzajmpG9DrFer9LB9Nr92
383	payment	190	190	190	382	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JupxXbFqdMa8DgeZDpyvsWrwm6nusbFFAMenjVvjLgG4fENFMpc
409	payment	190	190	190	408	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuAGXCrR9xHLiabDDLPLqsXDmBDKRAHEVhyUB7tn6dLJtT1o3Dz
410	payment	190	190	190	409	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtWjc8F9UUn5UePpNgLmEcAumHrC8rxryCdDExpHujxkY9prwpB
411	payment	190	190	190	410	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuFGo4wRcknRoxmjZpahPU1cNfvUxwwAtWydhWg5fcAXr3P1URo
412	payment	190	190	190	411	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtvJiJEgSyW9Bj1gBLf9pqmW2RRi6RGgJm953aaxXx3MtCSvfWb
413	payment	190	190	190	412	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuX96qJVmHC8vwpwogpfrYDsVyKhAk6be6XWp1DtfR2pfi9mPnL
414	payment	190	190	190	413	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtnRZmLavH8MmdKdywYtQg3CQDqtc4QyaZ2Zoar8FUVGqeCoi71
425	payment	190	190	190	424	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtWgfxBbF2uMh9y8HHfJgTcT5cKqGpCZvM2gNiiFnSp4JS6JF5U
426	payment	190	190	190	425	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv49PM11UmDySrByrachyhdfygHggLNbytUvqtuQXRn1i6WZL64
427	payment	190	190	190	426	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtiR7GE6CvZbrRWXcDnM9GVZuQgwJiCq5MSuEUsUWnDstXhdCd1
428	payment	190	190	190	427	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JttGavCzJN2P9MTZxNhirCbRjVGhbFQwrrigXsbWa8EHxjop3Wu
429	payment	190	190	190	428	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juh1ptMpnymjeAa4fj3KGmzPu4i2sTdYeGmq7uXTEUSu26NPAxd
430	payment	190	190	190	429	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juu7tidvi3KiJxwqGCFHAm8SrzWVYJycEWefS49Aa38VQ1bqefo
431	payment	190	190	190	430	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju1AsjLMK6AmrYjE69AuhHdGs95CTeqjxSskXfxsRajdQ4gN4oP
432	payment	190	190	190	431	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv2RLnYg65bqTDsje7A3syRDkvBGMZ4hS7FM5pU8wumQQr2Bw7A
433	payment	190	190	190	432	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtaEZ3w3VCsyzUXas9YNX4271GQWuaYtDLPDMw3JYBq2tGiaSyr
434	payment	190	190	190	433	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JumjRT3FPP2YPYixLykxUvFh9rNND9iMcnG2axN5GmY6CuupokR
371	payment	190	190	190	370	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvHQpZ4R6T9Z4x6mYY6aodMUHxzRfB4uSYX19tqjZxD5JAimYak
372	payment	190	190	190	371	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuGA3fV6CrG2j57NQq8own4qPUcoPivRu1HcZX2zunnnut2FWdm
373	payment	190	190	190	372	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtoMgmARWyZtQBYSumdW1NMfwNGJerXD3rkHQDAiUBiBqCViPHY
374	payment	190	190	190	373	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvP89kJZsfcCrDjrwv7ema8Q7RwPWebHpnjUaMSSnd2FVCbTgRX
375	payment	190	190	190	374	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvP7WLKiERSyN1Ce6efSTfoKvn4A4fbPfF7HSUDXzFC1BoraAuU
376	payment	190	190	190	375	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvREaFFX2dVQAPDnqP6zsGQbBjfq3H1qpV3YTnGKbciCjMdSDX3
384	payment	190	190	190	383	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuCiZ3XQCjBpESdyBiBHZTSi4mmZHFKDyzYRzfawmiy76obovo7
385	payment	190	190	190	384	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuKFx36p7isBKGbgEnq19ArYSL8WjBykCgTPriRzFjbQFCm3ztb
386	payment	190	190	190	385	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtaW4teDUMrPhCBL4j5JKwh6mrq8b5wCE3eK5usJ3yDkbFhLfrS
387	payment	190	190	190	386	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvLeRwAkkaAmwy4Z8uqLsvjP8GiphRf1DkbYiyPEaGquhc2RBPy
388	payment	190	190	190	387	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtsbiCWY5oz8UmmQh5Xp38HVSjztSP32Bu9nM9vjRmheC3wtwM9
389	payment	190	190	190	388	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuUXLoBudoRhjrjgUkoAhEp5qx1nephjAbAwpQKSaUsxaehtF2p
390	payment	190	190	190	389	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtXM6WRftH5v9DucqB5SZujTEDscB1BUpiE5JRkBy3Kxs1zAU14
391	payment	190	190	190	390	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuRNn9pHwR5Y79VPXWpuAmjXBn8uWtVkRq4MoTfBspShNihr8iF
392	payment	190	190	190	391	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuLQbUeZ6389sGzVCYEBMHMY7ae8Ugg3jr5X9Z6ZbFkR86gBTnA
393	payment	190	190	190	392	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuEE2YJ4vUfDDrfmJJyAsXdfb27mpGtAuSkQTyjZTa8uG6Bw3GB
394	payment	190	190	190	393	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvHrktJuGokHgU6tuBy88pGYmMprNoPjwjGH65LHqdXgxJvuEuK
395	payment	190	190	190	394	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuNHkGEmbkwEXUNjX3x6bsuWeFMYfS7BxDowqwoi5rW1vfRr6g5
396	payment	190	190	190	395	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuaTAo5bnLCbfmck4H3ku6NTRTF5qNDU1zsPFYKfhsYFbiYX6RR
397	payment	190	190	190	396	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvCDNHHdseAR3mb65Pad2fYj59EykALEiNrsEPf51CCt18c4Ygz
398	payment	190	190	190	397	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvHg5Pqz5akHHzLApeZ7Cj4xRMeV4yNrQQkvXMyZk2uZoHHF39M
399	payment	190	190	190	398	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuLTW6A2teupZTAo63ViNN4mMDjMWZnedsemdfckP7n6aU6QXhi
400	payment	190	190	190	399	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtbY6Hj6Lzku4Ex2anjf6h76gQ3Y1u3Xd6yBNrBG4rsZm7Sr2cT
401	payment	190	190	190	400	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuEcCaMDJvqGVQEVdpybA37cNZijdGiHY1vbhzzGwdj9ANk3bQg
402	payment	190	190	190	401	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvGSxW74tGmkuibTtL1MorkGYFjHeepi6s4SoEZEJJtZEYY7pSZ
403	payment	190	190	190	402	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuBM5WW8DY2jsEv7B8pNnfFdNCUvUH7DD4icDYysbE6s73RN47T
404	payment	190	190	190	403	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtiVF6jpWWNyK477vWW8QAGBHwYtZ8tfsy2GWBMFzkS2f3udoUj
405	payment	190	190	190	404	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JubBdxPFvBoTUQmsGQ3LEdGMpCxPQawXAhLBcKciYUPnp6UpABu
406	payment	190	190	190	405	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JujCZwuotrsM8nzkZ3pf9PNs4z19HEHh5rToT3p5msq9nQ4Hqtj
407	payment	190	190	190	406	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju94YVqhTxukL5yPwp5caovLcnzeRMLG8PwXpecZm94EgysBTHv
408	payment	190	190	190	407	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvNm8m28qQwUpdxUjqvyeXmnjJwNWJXnh71aunH6rT2ms1vvpzS
415	payment	190	190	190	414	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuBe1VwbrM8CRj9HSZb3xMqmQ3xfbRWjDwYQ8ahdrch1A4nnveB
416	payment	190	190	190	415	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuXJMUYYn4ctcFmnv4XbdT6UEhNBTBm3niisgHtPZWZuFFwjKaD
417	payment	190	190	190	416	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv64poSfxTWa4kEkmnGJRUUzZ12ML6VmFfGbJ982TrHz4DUoGmb
418	payment	190	190	190	417	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtfZso21oYzeKrj4rR3b9wcxcrr11377wSJrxa1wJp1NEsvii45
419	payment	190	190	190	418	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juf4cZZdYfdfz9cZWgadBmsgB6Y3f7F6PCFnH9E9WJhNa3D5kXt
420	payment	190	190	190	419	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuDWuM2zmyMXqpCACsXnAxKBjvpC3trBenG158FAVzDnadSiUxg
421	payment	190	190	190	420	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JumomTXY5SdCrALoZ3cw9qyhc8jUYdRMEriRUUvKMbxjc7sKY4Z
422	payment	190	190	190	421	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuLycqH2WHLSwdr9XgBUWPaiLYJWp88xWZiRa8NLY7ysUrdQzF8
423	payment	190	190	190	422	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvRRk6EYoqUfCevfLFXUrf32XaatR6kYVHd98YPFTXg9BkyyZKu
424	payment	190	190	190	423	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtXgboZaf9tLnpXrE3WrScKTAr2QRDcSRansqW7KcmbdEftZK3t
435	payment	190	190	190	434	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtvNkzh7ivJf6Kf9Nh59LQ8MhyfbLuhCYpDMHsbdRvdNjRyAvV3
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
242	\N	241	\N	\N	1	\N	\N	\N
243	\N	242	\N	\N	1	\N	\N	\N
244	\N	243	\N	\N	1	\N	\N	\N
245	\N	244	\N	\N	1	\N	\N	\N
246	\N	245	\N	\N	1	\N	\N	\N
247	\N	246	\N	\N	1	\N	\N	\N
248	\N	247	\N	\N	1	\N	\N	\N
249	\N	248	\N	\N	1	\N	\N	\N
250	\N	249	\N	\N	1	\N	\N	\N
251	\N	250	\N	\N	1	\N	\N	\N
252	\N	251	\N	\N	1	\N	\N	\N
253	\N	252	\N	\N	1	\N	\N	\N
254	\N	253	\N	\N	1	\N	\N	\N
255	\N	254	\N	\N	1	\N	\N	\N
256	\N	255	\N	\N	1	\N	\N	\N
257	\N	256	\N	\N	1	\N	\N	\N
258	\N	257	\N	\N	1	\N	\N	\N
259	\N	258	\N	\N	1	\N	\N	\N
260	\N	259	\N	\N	1	\N	\N	\N
261	\N	260	\N	\N	1	\N	\N	\N
262	\N	261	\N	\N	1	\N	\N	\N
263	\N	262	\N	\N	1	\N	\N	\N
264	\N	263	\N	\N	1	\N	\N	\N
265	\N	264	\N	\N	1	\N	\N	\N
266	\N	265	\N	\N	1	\N	\N	\N
267	\N	266	\N	\N	1	\N	\N	\N
268	\N	267	\N	\N	1	\N	\N	\N
269	\N	268	\N	\N	1	\N	\N	\N
270	\N	269	\N	\N	1	\N	\N	\N
271	\N	270	\N	\N	1	\N	\N	\N
272	\N	271	\N	\N	1	\N	\N	\N
273	\N	272	\N	\N	1	\N	\N	\N
274	\N	273	\N	\N	1	\N	\N	\N
275	\N	274	\N	\N	1	\N	\N	\N
276	\N	275	\N	\N	1	\N	\N	\N
277	\N	276	\N	\N	1	\N	\N	\N
278	\N	277	\N	\N	1	\N	\N	\N
279	\N	278	\N	\N	1	\N	\N	\N
280	\N	279	\N	\N	1	\N	\N	\N
281	\N	280	\N	\N	1	\N	\N	\N
282	\N	281	\N	\N	1	\N	\N	\N
283	\N	282	\N	\N	1	\N	\N	\N
284	\N	283	\N	\N	1	\N	\N	\N
285	\N	284	\N	\N	1	\N	\N	\N
286	\N	285	\N	\N	1	\N	\N	\N
287	\N	286	\N	\N	1	\N	\N	\N
288	\N	287	\N	\N	1	\N	\N	\N
289	\N	288	\N	\N	1	\N	\N	\N
290	\N	289	\N	\N	1	\N	\N	\N
291	\N	290	\N	\N	1	\N	\N	\N
292	\N	291	\N	\N	1	\N	\N	\N
293	\N	292	\N	\N	1	\N	\N	\N
294	\N	293	\N	\N	1	\N	\N	\N
295	\N	294	\N	\N	1	\N	\N	\N
296	\N	295	\N	\N	1	\N	\N	\N
297	\N	296	\N	\N	1	\N	\N	\N
298	\N	297	\N	\N	1	\N	\N	\N
299	\N	298	\N	\N	1	\N	\N	\N
300	\N	299	\N	\N	1	\N	\N	\N
301	\N	300	\N	\N	1	\N	\N	\N
302	\N	301	\N	\N	1	\N	\N	\N
303	\N	302	\N	\N	1	\N	\N	\N
304	\N	303	\N	\N	1	\N	\N	\N
305	\N	304	\N	\N	1	\N	\N	\N
306	\N	305	\N	\N	1	\N	\N	\N
307	\N	306	\N	\N	1	\N	\N	\N
308	\N	307	\N	\N	1	\N	\N	\N
309	\N	308	\N	\N	1	\N	\N	\N
310	\N	309	\N	\N	1	\N	\N	\N
311	\N	310	\N	\N	1	\N	\N	\N
312	\N	311	\N	\N	1	\N	\N	\N
313	\N	312	\N	\N	1	\N	\N	\N
314	\N	313	\N	\N	1	\N	\N	\N
315	\N	314	\N	\N	1	\N	\N	\N
316	\N	315	\N	\N	1	\N	\N	\N
317	\N	316	\N	\N	1	\N	\N	\N
318	\N	317	\N	\N	1	\N	\N	\N
319	\N	318	\N	\N	1	\N	\N	\N
320	\N	319	\N	\N	1	\N	\N	\N
321	\N	320	\N	\N	1	\N	\N	\N
322	\N	321	\N	\N	1	\N	\N	\N
323	\N	322	\N	\N	1	\N	\N	\N
324	\N	323	\N	\N	1	\N	\N	\N
325	\N	324	\N	\N	1	\N	\N	\N
326	\N	325	\N	\N	1	\N	\N	\N
327	\N	326	\N	\N	1	\N	\N	\N
328	\N	327	\N	\N	1	\N	\N	\N
329	\N	328	\N	\N	1	\N	\N	\N
330	\N	329	\N	\N	1	\N	\N	\N
331	\N	330	\N	\N	1	\N	\N	\N
332	\N	331	\N	\N	1	\N	\N	\N
333	\N	332	\N	\N	1	\N	\N	\N
334	\N	333	\N	\N	1	\N	\N	\N
335	\N	334	\N	\N	1	\N	\N	\N
336	\N	335	\N	\N	1	\N	\N	\N
337	\N	336	\N	\N	1	\N	\N	\N
338	\N	337	\N	\N	1	\N	\N	\N
339	\N	338	\N	\N	1	\N	\N	\N
340	\N	339	\N	\N	1	\N	\N	\N
341	\N	340	\N	\N	1	\N	\N	\N
342	\N	341	\N	\N	1	\N	\N	\N
343	\N	342	\N	\N	1	\N	\N	\N
344	\N	343	\N	\N	1	\N	\N	\N
345	\N	344	\N	\N	1	\N	\N	\N
346	\N	345	\N	\N	1	\N	\N	\N
347	\N	346	\N	\N	1	\N	\N	\N
348	\N	347	\N	\N	1	\N	\N	\N
349	\N	348	\N	\N	1	\N	\N	\N
350	\N	349	\N	\N	1	\N	\N	\N
351	\N	350	\N	\N	1	\N	\N	\N
352	\N	351	\N	\N	1	\N	\N	\N
353	\N	352	\N	\N	1	\N	\N	\N
354	\N	353	\N	\N	1	\N	\N	\N
355	\N	354	\N	\N	1	\N	\N	\N
356	\N	355	\N	\N	1	\N	\N	\N
357	\N	356	\N	\N	1	\N	\N	\N
358	\N	357	\N	\N	1	\N	\N	\N
359	\N	358	\N	\N	1	\N	\N	\N
360	\N	359	\N	\N	1	\N	\N	\N
361	\N	360	\N	\N	1	\N	\N	\N
362	\N	361	\N	\N	1	\N	\N	\N
363	\N	362	\N	\N	1	\N	\N	\N
364	\N	363	\N	\N	1	\N	\N	\N
365	\N	364	\N	\N	1	\N	\N	\N
366	\N	365	\N	\N	1	\N	\N	\N
367	\N	366	\N	\N	1	\N	\N	\N
368	\N	367	\N	\N	1	\N	\N	\N
369	\N	368	\N	\N	1	\N	\N	\N
370	\N	369	\N	\N	1	\N	\N	\N
371	\N	370	\N	\N	1	\N	\N	\N
372	\N	371	\N	\N	1	\N	\N	\N
373	\N	372	\N	\N	1	\N	\N	\N
374	\N	373	\N	\N	1	\N	\N	\N
375	\N	374	\N	\N	1	\N	\N	\N
376	\N	375	\N	\N	1	\N	\N	\N
377	\N	376	\N	\N	1	\N	\N	\N
378	\N	377	\N	\N	1	\N	\N	\N
379	\N	378	\N	\N	1	\N	\N	\N
380	\N	379	\N	\N	1	\N	\N	\N
381	\N	380	\N	\N	1	\N	\N	\N
382	\N	381	\N	\N	1	\N	\N	\N
383	\N	382	\N	\N	1	\N	\N	\N
384	\N	383	\N	\N	1	\N	\N	\N
385	\N	384	\N	\N	1	\N	\N	\N
386	\N	385	\N	\N	1	\N	\N	\N
387	\N	386	\N	\N	1	\N	\N	\N
388	\N	387	\N	\N	1	\N	\N	\N
389	\N	388	\N	\N	1	\N	\N	\N
390	\N	389	\N	\N	1	\N	\N	\N
391	\N	390	\N	\N	1	\N	\N	\N
392	\N	391	\N	\N	1	\N	\N	\N
393	\N	392	\N	\N	1	\N	\N	\N
394	\N	393	\N	\N	1	\N	\N	\N
395	\N	394	\N	\N	1	\N	\N	\N
396	\N	395	\N	\N	1	\N	\N	\N
397	\N	396	\N	\N	1	\N	\N	\N
398	\N	397	\N	\N	1	\N	\N	\N
399	\N	398	\N	\N	1	\N	\N	\N
400	\N	399	\N	\N	1	\N	\N	\N
401	\N	400	\N	\N	1	\N	\N	\N
402	\N	401	\N	\N	1	\N	\N	\N
403	\N	402	\N	\N	1	\N	\N	\N
404	\N	403	\N	\N	1	\N	\N	\N
405	\N	404	\N	\N	1	\N	\N	\N
406	\N	405	\N	\N	1	\N	\N	\N
407	\N	406	\N	\N	1	\N	\N	\N
408	\N	407	\N	\N	1	\N	\N	\N
409	\N	408	\N	\N	1	\N	\N	\N
410	\N	409	\N	\N	1	\N	\N	\N
411	\N	410	\N	\N	1	\N	\N	\N
412	\N	411	\N	\N	1	\N	\N	\N
413	\N	412	\N	\N	1	\N	\N	\N
414	\N	413	\N	\N	1	\N	\N	\N
415	\N	414	\N	\N	1	\N	\N	\N
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
481	481
482	482
483	483
484	484
485	485
486	486
487	487
488	488
489	489
501	501
509	509
510	510
511	511
512	512
513	513
514	514
515	515
516	516
517	517
518	518
519	519
520	520
521	521
522	522
523	523
524	524
526	526
527	527
528	528
536	536
537	537
538	538
490	490
491	491
492	492
493	493
494	494
495	495
496	496
497	497
498	498
499	499
500	500
502	502
503	503
504	504
505	505
506	506
507	507
508	508
525	525
529	529
530	530
531	531
532	532
533	533
534	534
535	535
539	539
540	540
541	541
542	542
543	543
544	544
545	545
546	546
547	547
548	548
549	549
550	550
551	551
552	552
553	553
554	554
555	555
556	556
557	557
558	558
559	559
560	560
561	561
562	562
563	563
564	564
565	565
566	566
567	567
568	568
569	569
570	570
571	571
572	572
573	573
574	574
575	575
576	576
577	577
578	578
579	579
580	580
581	581
582	582
583	583
584	584
585	585
586	586
587	587
588	588
589	589
590	590
591	591
592	592
593	593
594	594
595	595
596	596
597	597
598	598
599	599
600	600
601	601
602	602
603	603
604	604
605	605
606	606
607	607
608	608
609	609
610	610
611	611
612	612
613	613
614	614
615	615
616	616
617	617
618	618
619	619
620	620
621	621
622	622
623	623
624	624
625	625
626	626
627	627
628	628
629	629
630	630
631	631
632	632
633	633
634	634
635	635
636	636
637	637
638	638
639	639
640	640
641	641
642	642
643	643
644	644
645	645
646	646
647	647
648	648
649	649
650	650
651	651
652	652
653	653
654	654
655	655
656	656
657	657
658	658
659	659
660	660
661	661
662	662
663	663
664	664
665	665
666	666
667	667
668	668
669	669
670	670
671	671
672	672
673	673
674	674
675	675
676	676
677	677
678	678
679	679
680	680
681	681
682	682
683	683
684	684
685	685
686	686
687	687
688	688
689	689
690	690
691	691
692	692
693	693
694	694
695	695
696	696
697	697
698	698
699	699
700	700
701	701
702	702
703	703
704	704
705	705
706	706
707	707
708	708
709	709
710	710
711	711
712	712
713	713
714	714
715	715
716	716
717	717
718	718
719	719
720	720
721	721
722	722
723	723
724	724
725	725
726	726
727	727
728	728
729	729
730	730
731	731
732	732
733	733
734	734
735	735
736	736
737	737
738	738
739	739
740	740
741	741
742	742
743	743
744	744
745	745
746	746
747	747
748	748
754	754
755	755
767	767
768	768
769	769
770	770
771	771
772	772
773	773
774	774
775	775
776	776
749	749
750	750
751	751
752	752
753	753
756	756
757	757
758	758
759	759
760	760
761	761
762	762
763	763
764	764
765	765
766	766
777	777
778	778
779	779
780	780
781	781
782	782
783	783
784	784
785	785
786	786
787	787
788	788
789	789
790	790
791	791
792	792
793	793
794	794
795	795
796	796
797	797
798	798
799	799
800	800
801	801
802	802
803	803
804	804
805	805
806	806
807	807
808	808
809	809
810	810
811	811
812	812
813	813
814	814
815	815
816	816
817	817
818	818
819	819
820	820
821	821
822	822
823	823
824	824
825	825
826	826
827	827
828	828
\.


--
-- Data for Name: zkapp_account_update_body; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.zkapp_account_update_body (id, account_identifier_id, update_id, balance_change, increment_nonce, events_id, actions_id, call_data_id, call_depth, zkapp_network_precondition_id, zkapp_account_precondition_id, zkapp_valid_while_precondition_id, use_full_commitment, implicit_account_creation_fee, may_use_token, authorization_kind, verification_key_hash_id) FROM stdin;
1	107	1	-1000000000000	t	1	1	1	0	1	1	\N	f	f	No	Signature	\N
2	243	2	999000000000	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
3	107	1	-1000000000	t	1	1	1	0	1	3	\N	f	f	No	Signature	\N
4	243	1	1000000000	f	1	1	1	0	1	2	\N	f	f	No	None_given	\N
5	243	3	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
6	107	1	-1000000000	t	1	1	1	0	1	4	\N	f	f	No	Signature	\N
7	243	4	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
8	107	1	-1000000000	t	1	1	1	0	1	5	\N	f	f	No	Signature	\N
9	243	5	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
10	107	1	-1000000000	t	1	1	1	0	1	6	\N	f	f	No	Signature	\N
11	243	6	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
12	107	1	-1000000000	t	1	1	1	0	1	7	\N	f	f	No	Signature	\N
13	243	7	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
14	107	1	-1000000000	t	1	1	1	0	1	8	\N	f	f	No	Signature	\N
15	243	8	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
16	107	1	-1000000000	t	1	1	1	0	1	9	\N	f	f	No	Signature	\N
17	243	9	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
18	107	1	-1000000000	t	1	1	1	0	1	10	\N	f	f	No	Signature	\N
19	243	10	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
20	107	1	-1000000000	t	1	1	1	0	1	11	\N	f	f	No	Signature	\N
21	243	11	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
22	107	1	-1000000000	t	1	1	1	0	1	12	\N	f	f	No	Signature	\N
23	243	12	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
24	107	1	-1000000000	t	1	1	1	0	1	13	\N	f	f	No	Signature	\N
25	243	13	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
26	107	1	-1000000000	t	1	1	1	0	1	14	\N	f	f	No	Signature	\N
27	243	14	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
28	107	1	-1000000000	t	1	1	1	0	1	15	\N	f	f	No	Signature	\N
29	243	15	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
30	107	1	-1000000000	t	1	1	1	0	1	16	\N	f	f	No	Signature	\N
31	243	16	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
32	107	1	-1000000000	t	1	1	1	0	1	17	\N	f	f	No	Signature	\N
33	243	17	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
34	107	1	-1000000000	t	1	1	1	0	1	18	\N	f	f	No	Signature	\N
35	243	18	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
36	107	1	-1000000000	t	1	1	1	0	1	19	\N	f	f	No	Signature	\N
37	243	19	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
38	107	1	-1000000000	t	1	1	1	0	1	20	\N	f	f	No	Signature	\N
39	243	20	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
40	107	1	-1000000000	t	1	1	1	0	1	21	\N	f	f	No	Signature	\N
41	243	21	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
42	107	1	-1000000000	t	1	1	1	0	1	22	\N	f	f	No	Signature	\N
43	243	22	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
44	107	1	-1000000000	t	1	1	1	0	1	23	\N	f	f	No	Signature	\N
45	243	23	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
46	107	1	-1000000000	t	1	1	1	0	1	24	\N	f	f	No	Signature	\N
47	243	24	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
48	107	1	-1000000000	t	1	1	1	0	1	25	\N	f	f	No	Signature	\N
49	243	25	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
50	107	1	-1000000000	t	1	1	1	0	1	26	\N	f	f	No	Signature	\N
51	243	26	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
52	107	1	-1000000000	t	1	1	1	0	1	27	\N	f	f	No	Signature	\N
53	243	27	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
54	107	1	-1000000000	t	1	1	1	0	1	28	\N	f	f	No	Signature	\N
55	243	28	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
56	107	1	-1000000000	t	1	1	1	0	1	29	\N	f	f	No	Signature	\N
57	243	29	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
58	107	1	-1000000000	t	1	1	1	0	1	30	\N	f	f	No	Signature	\N
59	243	30	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
60	107	1	-1000000000	t	1	1	1	0	1	31	\N	f	f	No	Signature	\N
61	243	31	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
62	107	1	-1000000000	t	1	1	1	0	1	32	\N	f	f	No	Signature	\N
63	243	32	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
64	107	1	-1000000000	t	1	1	1	0	1	33	\N	f	f	No	Signature	\N
65	243	33	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
66	107	1	-1000000000	t	1	1	1	0	1	34	\N	f	f	No	Signature	\N
67	243	34	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
68	107	1	-1000000000	t	1	1	1	0	1	35	\N	f	f	No	Signature	\N
69	243	35	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
70	107	1	-1000000000	t	1	1	1	0	1	36	\N	f	f	No	Signature	\N
71	243	36	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
72	107	1	-1000000000	t	1	1	1	0	1	37	\N	f	f	No	Signature	\N
73	243	37	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
74	107	1	-1000000000	t	1	1	1	0	1	38	\N	f	f	No	Signature	\N
75	243	38	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
76	107	1	-1000000000	t	1	1	1	0	1	39	\N	f	f	No	Signature	\N
77	243	39	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
78	107	1	-1000000000	t	1	1	1	0	1	40	\N	f	f	No	Signature	\N
79	243	40	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
80	107	1	-1000000000	t	1	1	1	0	1	41	\N	f	f	No	Signature	\N
81	243	41	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
82	107	1	-1000000000	t	1	1	1	0	1	42	\N	f	f	No	Signature	\N
83	243	42	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
84	107	1	-1000000000	t	1	1	1	0	1	43	\N	f	f	No	Signature	\N
85	243	43	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
86	107	1	-1000000000	t	1	1	1	0	1	44	\N	f	f	No	Signature	\N
87	243	44	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
88	107	1	-1000000000	t	1	1	1	0	1	45	\N	f	f	No	Signature	\N
89	243	45	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
90	107	1	-1000000000	t	1	1	1	0	1	46	\N	f	f	No	Signature	\N
91	243	46	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
92	107	1	-1000000000	t	1	1	1	0	1	47	\N	f	f	No	Signature	\N
93	243	47	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
94	107	1	-1000000000	t	1	1	1	0	1	48	\N	f	f	No	Signature	\N
95	243	48	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
96	107	1	-1000000000	t	1	1	1	0	1	49	\N	f	f	No	Signature	\N
97	243	49	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
98	107	1	-1000000000	t	1	1	1	0	1	50	\N	f	f	No	Signature	\N
99	243	50	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
100	107	1	-1000000000	t	1	1	1	0	1	51	\N	f	f	No	Signature	\N
101	243	51	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
102	107	1	-1000000000	t	1	1	1	0	1	52	\N	f	f	No	Signature	\N
103	243	52	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
104	107	1	-1000000000	t	1	1	1	0	1	53	\N	f	f	No	Signature	\N
105	243	53	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
106	107	1	-1000000000	t	1	1	1	0	1	54	\N	f	f	No	Signature	\N
107	243	54	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
108	107	1	-1000000000	t	1	1	1	0	1	55	\N	f	f	No	Signature	\N
109	243	55	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
110	107	1	-1000000000	t	1	1	1	0	1	56	\N	f	f	No	Signature	\N
111	243	56	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
112	107	1	-1000000000	t	1	1	1	0	1	57	\N	f	f	No	Signature	\N
113	243	57	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
114	107	1	-1000000000	t	1	1	1	0	1	58	\N	f	f	No	Signature	\N
115	243	58	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
116	107	1	-1000000000	t	1	1	1	0	1	59	\N	f	f	No	Signature	\N
117	243	59	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
118	107	1	-1000000000	t	1	1	1	0	1	60	\N	f	f	No	Signature	\N
119	243	60	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
120	107	1	-1000000000	t	1	1	1	0	1	61	\N	f	f	No	Signature	\N
121	243	61	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
122	107	1	-1000000000	t	1	1	1	0	1	62	\N	f	f	No	Signature	\N
123	243	62	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
124	107	1	-1000000000	t	1	1	1	0	1	63	\N	f	f	No	Signature	\N
125	243	63	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
126	107	1	-1000000000	t	1	1	1	0	1	64	\N	f	f	No	Signature	\N
127	243	64	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
128	107	1	-1000000000	t	1	1	1	0	1	65	\N	f	f	No	Signature	\N
129	243	65	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
130	107	1	-1000000000	t	1	1	1	0	1	66	\N	f	f	No	Signature	\N
131	243	66	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
132	107	1	-1000000000	t	1	1	1	0	1	67	\N	f	f	No	Signature	\N
133	243	67	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
134	107	1	-1000000000	t	1	1	1	0	1	68	\N	f	f	No	Signature	\N
135	243	68	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
136	107	1	-1000000000	t	1	1	1	0	1	69	\N	f	f	No	Signature	\N
137	243	69	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
138	107	1	-1000000000	t	1	1	1	0	1	70	\N	f	f	No	Signature	\N
139	243	70	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
140	107	1	-1000000000	t	1	1	1	0	1	71	\N	f	f	No	Signature	\N
141	243	71	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
142	107	1	-1000000000	t	1	1	1	0	1	72	\N	f	f	No	Signature	\N
143	243	72	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
144	107	1	-1000000000	t	1	1	1	0	1	73	\N	f	f	No	Signature	\N
145	243	73	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
146	107	1	-1000000000	t	1	1	1	0	1	74	\N	f	f	No	Signature	\N
147	243	74	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
148	107	1	-1000000000	t	1	1	1	0	1	75	\N	f	f	No	Signature	\N
149	243	75	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
150	107	1	-1000000000	t	1	1	1	0	1	76	\N	f	f	No	Signature	\N
151	243	76	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
152	107	1	-1000000000	t	1	1	1	0	1	77	\N	f	f	No	Signature	\N
153	243	77	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
154	107	1	-1000000000	t	1	1	1	0	1	78	\N	f	f	No	Signature	\N
155	243	78	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
156	107	1	-1000000000	t	1	1	1	0	1	79	\N	f	f	No	Signature	\N
157	243	79	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
158	107	1	-1000000000	t	1	1	1	0	1	80	\N	f	f	No	Signature	\N
159	243	80	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
160	107	1	-1000000000	t	1	1	1	0	1	81	\N	f	f	No	Signature	\N
161	243	81	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
162	107	1	-1000000000	t	1	1	1	0	1	82	\N	f	f	No	Signature	\N
163	243	82	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
164	107	1	-1000000000	t	1	1	1	0	1	83	\N	f	f	No	Signature	\N
165	243	83	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
166	107	1	-1000000000	t	1	1	1	0	1	84	\N	f	f	No	Signature	\N
167	243	84	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
168	107	1	-1000000000	t	1	1	1	0	1	85	\N	f	f	No	Signature	\N
169	243	85	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
170	107	1	-1000000000	t	1	1	1	0	1	86	\N	f	f	No	Signature	\N
171	243	86	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
172	107	1	-1000000000	t	1	1	1	0	1	87	\N	f	f	No	Signature	\N
173	243	87	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
174	107	1	-1000000000	t	1	1	1	0	1	88	\N	f	f	No	Signature	\N
175	243	88	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
176	107	1	-1000000000	t	1	1	1	0	1	89	\N	f	f	No	Signature	\N
177	243	89	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
178	107	1	-1000000000	t	1	1	1	0	1	90	\N	f	f	No	Signature	\N
179	243	90	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
180	107	1	-1000000000	t	1	1	1	0	1	91	\N	f	f	No	Signature	\N
181	243	91	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
182	107	1	-1000000000	t	1	1	1	0	1	92	\N	f	f	No	Signature	\N
183	243	92	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
184	107	1	-1000000000	t	1	1	1	0	1	93	\N	f	f	No	Signature	\N
185	243	93	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
186	107	1	-1000000000	t	1	1	1	0	1	94	\N	f	f	No	Signature	\N
187	243	94	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
188	107	1	-1000000000	t	1	1	1	0	1	95	\N	f	f	No	Signature	\N
189	243	95	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
190	107	1	-1000000000	t	1	1	1	0	1	96	\N	f	f	No	Signature	\N
191	243	96	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
192	107	1	-1000000000	t	1	1	1	0	1	97	\N	f	f	No	Signature	\N
193	243	97	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
194	107	1	-1000000000	t	1	1	1	0	1	98	\N	f	f	No	Signature	\N
195	243	98	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
196	107	1	-1000000000	t	1	1	1	0	1	99	\N	f	f	No	Signature	\N
197	243	99	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
198	107	1	-1000000000	t	1	1	1	0	1	100	\N	f	f	No	Signature	\N
199	243	100	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
200	107	1	-1000000000	t	1	1	1	0	1	101	\N	f	f	No	Signature	\N
201	243	101	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
202	107	1	-1000000000	t	1	1	1	0	1	102	\N	f	f	No	Signature	\N
203	243	102	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
204	107	1	-1000000000	t	1	1	1	0	1	103	\N	f	f	No	Signature	\N
205	243	103	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
206	107	1	-1000000000	t	1	1	1	0	1	104	\N	f	f	No	Signature	\N
207	243	104	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
208	107	1	-1000000000	t	1	1	1	0	1	105	\N	f	f	No	Signature	\N
209	243	105	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
210	107	1	-1000000000	t	1	1	1	0	1	106	\N	f	f	No	Signature	\N
211	243	106	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
212	107	1	-1000000000	t	1	1	1	0	1	107	\N	f	f	No	Signature	\N
213	243	107	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
214	107	1	-1000000000	t	1	1	1	0	1	108	\N	f	f	No	Signature	\N
215	243	108	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
216	107	1	-1000000000	t	1	1	1	0	1	109	\N	f	f	No	Signature	\N
217	243	109	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
218	107	1	-1000000000	t	1	1	1	0	1	110	\N	f	f	No	Signature	\N
219	243	110	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
220	107	1	-1000000000	t	1	1	1	0	1	111	\N	f	f	No	Signature	\N
221	243	111	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
222	107	1	-1000000000	t	1	1	1	0	1	112	\N	f	f	No	Signature	\N
223	243	112	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
224	107	1	-1000000000	t	1	1	1	0	1	113	\N	f	f	No	Signature	\N
225	243	113	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
226	107	1	-1000000000	t	1	1	1	0	1	114	\N	f	f	No	Signature	\N
227	243	114	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
228	107	1	-1000000000	t	1	1	1	0	1	115	\N	f	f	No	Signature	\N
229	243	115	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
230	107	1	-1000000000	t	1	1	1	0	1	116	\N	f	f	No	Signature	\N
231	243	116	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
232	107	1	-1000000000	t	1	1	1	0	1	117	\N	f	f	No	Signature	\N
233	243	117	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
234	107	1	-1000000000	t	1	1	1	0	1	118	\N	f	f	No	Signature	\N
235	243	118	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
236	107	1	-1000000000	t	1	1	1	0	1	119	\N	f	f	No	Signature	\N
237	243	119	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
238	107	1	-1000000000	t	1	1	1	0	1	120	\N	f	f	No	Signature	\N
239	243	120	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
240	107	1	-1000000000	t	1	1	1	0	1	121	\N	f	f	No	Signature	\N
241	243	121	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
242	107	1	-1000000000	t	1	1	1	0	1	122	\N	f	f	No	Signature	\N
243	243	122	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
244	107	1	-1000000000	t	1	1	1	0	1	123	\N	f	f	No	Signature	\N
245	243	123	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
246	107	1	-1000000000	t	1	1	1	0	1	124	\N	f	f	No	Signature	\N
247	243	124	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
248	107	1	-1000000000	t	1	1	1	0	1	125	\N	f	f	No	Signature	\N
249	243	125	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
250	107	1	-1000000000	t	1	1	1	0	1	126	\N	f	f	No	Signature	\N
251	243	126	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
252	107	1	-1000000000	t	1	1	1	0	1	127	\N	f	f	No	Signature	\N
253	243	127	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
254	107	1	-1000000000	t	1	1	1	0	1	128	\N	f	f	No	Signature	\N
255	243	128	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
256	107	1	-1000000000	t	1	1	1	0	1	129	\N	f	f	No	Signature	\N
257	243	129	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
258	107	1	-1000000000	t	1	1	1	0	1	130	\N	f	f	No	Signature	\N
259	243	130	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
260	107	1	-1000000000	t	1	1	1	0	1	131	\N	f	f	No	Signature	\N
261	243	131	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
262	107	1	-1000000000	t	1	1	1	0	1	132	\N	f	f	No	Signature	\N
263	243	132	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
264	107	1	-1000000000	t	1	1	1	0	1	133	\N	f	f	No	Signature	\N
265	243	133	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
266	107	1	-1000000000	t	1	1	1	0	1	134	\N	f	f	No	Signature	\N
267	243	134	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
268	107	1	-1000000000	t	1	1	1	0	1	135	\N	f	f	No	Signature	\N
269	243	135	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
270	107	1	-1000000000	t	1	1	1	0	1	136	\N	f	f	No	Signature	\N
271	243	136	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
272	107	1	-1000000000	t	1	1	1	0	1	137	\N	f	f	No	Signature	\N
273	243	137	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
274	107	1	-1000000000	t	1	1	1	0	1	138	\N	f	f	No	Signature	\N
275	243	138	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
276	107	1	-1000000000	t	1	1	1	0	1	139	\N	f	f	No	Signature	\N
277	243	139	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
278	107	1	-1000000000	t	1	1	1	0	1	140	\N	f	f	No	Signature	\N
279	243	140	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
280	107	1	-1000000000	t	1	1	1	0	1	141	\N	f	f	No	Signature	\N
281	243	141	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
282	107	1	-1000000000	t	1	1	1	0	1	142	\N	f	f	No	Signature	\N
283	243	142	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
284	107	1	-1000000000	t	1	1	1	0	1	143	\N	f	f	No	Signature	\N
285	243	143	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
286	107	1	-1000000000	t	1	1	1	0	1	144	\N	f	f	No	Signature	\N
287	243	144	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
288	107	1	-1000000000	t	1	1	1	0	1	145	\N	f	f	No	Signature	\N
289	243	145	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
290	107	1	-1000000000	t	1	1	1	0	1	146	\N	f	f	No	Signature	\N
291	243	146	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
292	107	1	-1000000000	t	1	1	1	0	1	147	\N	f	f	No	Signature	\N
293	243	147	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
294	107	1	-1000000000	t	1	1	1	0	1	148	\N	f	f	No	Signature	\N
295	243	148	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
296	107	1	-1000000000	t	1	1	1	0	1	149	\N	f	f	No	Signature	\N
297	243	149	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
298	107	1	-1000000000	t	1	1	1	0	1	150	\N	f	f	No	Signature	\N
299	243	150	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
300	107	1	-1000000000	t	1	1	1	0	1	151	\N	f	f	No	Signature	\N
301	243	151	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
302	107	1	-1000000000	t	1	1	1	0	1	152	\N	f	f	No	Signature	\N
303	243	152	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
304	107	1	-1000000000	t	1	1	1	0	1	153	\N	f	f	No	Signature	\N
305	243	153	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
306	107	1	-1000000000	t	1	1	1	0	1	154	\N	f	f	No	Signature	\N
307	243	154	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
308	107	1	-1000000000	t	1	1	1	0	1	155	\N	f	f	No	Signature	\N
309	243	155	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
310	107	1	-1000000000	t	1	1	1	0	1	156	\N	f	f	No	Signature	\N
311	243	156	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
312	107	1	-1000000000	t	1	1	1	0	1	157	\N	f	f	No	Signature	\N
313	243	157	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
314	107	1	-1000000000	t	1	1	1	0	1	158	\N	f	f	No	Signature	\N
315	243	158	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
316	107	1	-1000000000	t	1	1	1	0	1	159	\N	f	f	No	Signature	\N
317	243	159	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
318	107	1	-1000000000	t	1	1	1	0	1	160	\N	f	f	No	Signature	\N
319	243	160	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
320	107	1	-1000000000	t	1	1	1	0	1	161	\N	f	f	No	Signature	\N
321	243	161	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
322	107	1	-1000000000	t	1	1	1	0	1	162	\N	f	f	No	Signature	\N
323	243	162	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
324	107	1	-1000000000	t	1	1	1	0	1	163	\N	f	f	No	Signature	\N
325	243	163	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
326	107	1	-1000000000	t	1	1	1	0	1	164	\N	f	f	No	Signature	\N
327	243	164	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
328	107	1	-1000000000	t	1	1	1	0	1	165	\N	f	f	No	Signature	\N
329	243	165	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
330	107	1	-1000000000	t	1	1	1	0	1	166	\N	f	f	No	Signature	\N
331	243	166	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
332	107	1	-1000000000	t	1	1	1	0	1	167	\N	f	f	No	Signature	\N
333	243	167	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
334	107	1	-1000000000	t	1	1	1	0	1	168	\N	f	f	No	Signature	\N
335	243	168	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
336	107	1	-1000000000	t	1	1	1	0	1	169	\N	f	f	No	Signature	\N
337	243	169	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
338	107	1	-1000000000	t	1	1	1	0	1	170	\N	f	f	No	Signature	\N
339	243	170	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
340	107	1	-1000000000	t	1	1	1	0	1	171	\N	f	f	No	Signature	\N
341	243	171	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
342	107	1	-1000000000	t	1	1	1	0	1	172	\N	f	f	No	Signature	\N
343	243	172	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
344	107	1	-1000000000	t	1	1	1	0	1	173	\N	f	f	No	Signature	\N
345	243	173	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
346	107	1	-1000000000	t	1	1	1	0	1	174	\N	f	f	No	Signature	\N
347	243	174	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
348	107	1	-1000000000	t	1	1	1	0	1	175	\N	f	f	No	Signature	\N
349	243	175	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
350	107	1	-1000000000	t	1	1	1	0	1	176	\N	f	f	No	Signature	\N
351	243	176	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
352	107	1	-1000000000	t	1	1	1	0	1	177	\N	f	f	No	Signature	\N
353	243	177	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
354	107	1	-1000000000	t	1	1	1	0	1	178	\N	f	f	No	Signature	\N
355	243	178	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
356	107	1	-1000000000	t	1	1	1	0	1	179	\N	f	f	No	Signature	\N
357	243	179	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
358	107	1	-1000000000	t	1	1	1	0	1	180	\N	f	f	No	Signature	\N
359	243	180	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
360	107	1	-1000000000	t	1	1	1	0	1	181	\N	f	f	No	Signature	\N
361	243	181	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
362	107	1	-1000000000	t	1	1	1	0	1	182	\N	f	f	No	Signature	\N
363	243	182	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
364	107	1	-1000000000	t	1	1	1	0	1	183	\N	f	f	No	Signature	\N
365	243	183	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
366	107	1	-1000000000	t	1	1	1	0	1	184	\N	f	f	No	Signature	\N
367	243	184	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
368	107	1	-1000000000	t	1	1	1	0	1	185	\N	f	f	No	Signature	\N
369	243	185	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
370	107	1	-1000000000	t	1	1	1	0	1	186	\N	f	f	No	Signature	\N
371	243	186	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
372	107	1	-1000000000	t	1	1	1	0	1	187	\N	f	f	No	Signature	\N
373	243	187	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
374	107	1	-1000000000	t	1	1	1	0	1	188	\N	f	f	No	Signature	\N
375	243	188	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
376	107	1	-1000000000	t	1	1	1	0	1	189	\N	f	f	No	Signature	\N
377	243	189	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
378	107	1	-1000000000	t	1	1	1	0	1	190	\N	f	f	No	Signature	\N
379	243	190	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
380	107	1	-1000000000	t	1	1	1	0	1	191	\N	f	f	No	Signature	\N
381	243	191	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
382	107	1	-1000000000	t	1	1	1	0	1	192	\N	f	f	No	Signature	\N
383	243	192	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
384	107	1	-1000000000	t	1	1	1	0	1	193	\N	f	f	No	Signature	\N
385	243	193	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
386	107	1	-1000000000	t	1	1	1	0	1	194	\N	f	f	No	Signature	\N
387	243	194	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
388	107	1	-1000000000	t	1	1	1	0	1	195	\N	f	f	No	Signature	\N
389	243	195	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
390	107	1	-1000000000	t	1	1	1	0	1	196	\N	f	f	No	Signature	\N
391	243	196	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
392	107	1	-1000000000	t	1	1	1	0	1	197	\N	f	f	No	Signature	\N
393	243	197	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
394	107	1	-1000000000	t	1	1	1	0	1	198	\N	f	f	No	Signature	\N
395	243	198	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
396	107	1	-1000000000	t	1	1	1	0	1	199	\N	f	f	No	Signature	\N
397	243	199	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
398	107	1	-1000000000	t	1	1	1	0	1	200	\N	f	f	No	Signature	\N
399	243	200	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
400	107	1	-1000000000	t	1	1	1	0	1	201	\N	f	f	No	Signature	\N
401	243	201	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
402	107	1	-1000000000	t	1	1	1	0	1	202	\N	f	f	No	Signature	\N
403	243	202	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
404	107	1	-1000000000	t	1	1	1	0	1	203	\N	f	f	No	Signature	\N
405	243	203	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
406	107	1	-1000000000	t	1	1	1	0	1	204	\N	f	f	No	Signature	\N
407	243	204	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
408	107	1	-1000000000	t	1	1	1	0	1	205	\N	f	f	No	Signature	\N
409	243	205	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
410	107	1	-1000000000	t	1	1	1	0	1	206	\N	f	f	No	Signature	\N
411	243	206	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
412	107	1	-1000000000	t	1	1	1	0	1	207	\N	f	f	No	Signature	\N
413	243	207	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
414	107	1	-1000000000	t	1	1	1	0	1	208	\N	f	f	No	Signature	\N
415	243	208	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
416	107	1	-1000000000	t	1	1	1	0	1	209	\N	f	f	No	Signature	\N
417	243	209	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
418	107	1	-1000000000	t	1	1	1	0	1	210	\N	f	f	No	Signature	\N
419	243	210	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
420	107	1	-1000000000	t	1	1	1	0	1	211	\N	f	f	No	Signature	\N
421	243	211	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
422	107	1	-1000000000	t	1	1	1	0	1	212	\N	f	f	No	Signature	\N
423	243	212	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
424	107	1	-1000000000	t	1	1	1	0	1	213	\N	f	f	No	Signature	\N
425	243	213	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
426	107	1	-1000000000	t	1	1	1	0	1	214	\N	f	f	No	Signature	\N
427	243	214	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
428	107	1	-1000000000	t	1	1	1	0	1	215	\N	f	f	No	Signature	\N
429	243	215	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
430	107	1	-1000000000	t	1	1	1	0	1	216	\N	f	f	No	Signature	\N
431	243	216	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
432	107	1	-1000000000	t	1	1	1	0	1	217	\N	f	f	No	Signature	\N
433	243	217	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
434	107	1	-1000000000	t	1	1	1	0	1	218	\N	f	f	No	Signature	\N
435	243	218	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
436	107	1	-1000000000	t	1	1	1	0	1	219	\N	f	f	No	Signature	\N
437	243	219	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
438	107	1	-1000000000	t	1	1	1	0	1	220	\N	f	f	No	Signature	\N
439	243	220	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
440	107	1	-1000000000	t	1	1	1	0	1	221	\N	f	f	No	Signature	\N
441	243	221	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
442	107	1	-1000000000	t	1	1	1	0	1	222	\N	f	f	No	Signature	\N
443	243	222	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
444	107	1	-1000000000	t	1	1	1	0	1	223	\N	f	f	No	Signature	\N
445	243	223	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
446	107	1	-1000000000	t	1	1	1	0	1	224	\N	f	f	No	Signature	\N
447	243	224	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
448	107	1	-1000000000	t	1	1	1	0	1	225	\N	f	f	No	Signature	\N
449	243	225	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
450	107	1	-1000000000	t	1	1	1	0	1	226	\N	f	f	No	Signature	\N
451	243	226	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
452	107	1	-1000000000	t	1	1	1	0	1	227	\N	f	f	No	Signature	\N
453	243	227	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
454	107	1	-1000000000	t	1	1	1	0	1	228	\N	f	f	No	Signature	\N
455	243	228	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
456	107	1	-1000000000	t	1	1	1	0	1	229	\N	f	f	No	Signature	\N
457	243	229	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
458	107	1	-1000000000	t	1	1	1	0	1	230	\N	f	f	No	Signature	\N
459	243	230	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
460	107	1	-1000000000	t	1	1	1	0	1	231	\N	f	f	No	Signature	\N
461	243	231	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
462	107	1	-1000000000	t	1	1	1	0	1	232	\N	f	f	No	Signature	\N
463	243	232	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
464	107	1	-1000000000	t	1	1	1	0	1	233	\N	f	f	No	Signature	\N
465	243	233	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
466	107	1	-1000000000	t	1	1	1	0	1	234	\N	f	f	No	Signature	\N
467	243	234	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
468	107	1	-1000000000	t	1	1	1	0	1	235	\N	f	f	No	Signature	\N
469	243	235	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
470	107	1	-1000000000	t	1	1	1	0	1	236	\N	f	f	No	Signature	\N
471	243	236	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
472	107	1	-1000000000	t	1	1	1	0	1	237	\N	f	f	No	Signature	\N
473	243	237	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
474	107	1	-1000000000	t	1	1	1	0	1	238	\N	f	f	No	Signature	\N
475	243	238	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
476	107	1	-1000000000	t	1	1	1	0	1	239	\N	f	f	No	Signature	\N
477	243	239	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
478	107	1	-1000000000	t	1	1	1	0	1	240	\N	f	f	No	Signature	\N
479	243	240	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
480	107	1	-1000000000	t	1	1	1	0	1	241	\N	f	f	No	Signature	\N
481	243	241	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
482	107	1	-1000000000	t	1	1	1	0	1	242	\N	f	f	No	Signature	\N
483	243	242	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
484	107	1	-1000000000	t	1	1	1	0	1	243	\N	f	f	No	Signature	\N
485	243	243	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
486	107	1	-1000000000	t	1	1	1	0	1	244	\N	f	f	No	Signature	\N
487	243	244	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
488	107	1	-1000000000	t	1	1	1	0	1	245	\N	f	f	No	Signature	\N
489	243	245	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
490	107	1	-1000000000	t	1	1	1	0	1	246	\N	f	f	No	Signature	\N
491	243	246	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
492	107	1	-1000000000	t	1	1	1	0	1	247	\N	f	f	No	Signature	\N
493	243	247	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
494	107	1	-1000000000	t	1	1	1	0	1	248	\N	f	f	No	Signature	\N
495	243	248	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
496	107	1	-1000000000	t	1	1	1	0	1	249	\N	f	f	No	Signature	\N
497	243	249	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
498	107	1	-1000000000	t	1	1	1	0	1	250	\N	f	f	No	Signature	\N
499	243	250	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
500	107	1	-1000000000	t	1	1	1	0	1	251	\N	f	f	No	Signature	\N
501	243	251	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
502	107	1	-1000000000	t	1	1	1	0	1	252	\N	f	f	No	Signature	\N
503	243	252	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
504	107	1	-1000000000	t	1	1	1	0	1	253	\N	f	f	No	Signature	\N
505	243	253	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
506	107	1	-1000000000	t	1	1	1	0	1	254	\N	f	f	No	Signature	\N
507	243	254	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
508	107	1	-1000000000	t	1	1	1	0	1	255	\N	f	f	No	Signature	\N
509	243	255	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
510	107	1	-1000000000	t	1	1	1	0	1	256	\N	f	f	No	Signature	\N
511	243	256	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
512	107	1	-1000000000	t	1	1	1	0	1	257	\N	f	f	No	Signature	\N
513	243	257	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
514	107	1	-1000000000	t	1	1	1	0	1	258	\N	f	f	No	Signature	\N
515	243	258	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
516	107	1	-1000000000	t	1	1	1	0	1	259	\N	f	f	No	Signature	\N
517	243	259	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
518	107	1	-1000000000	t	1	1	1	0	1	260	\N	f	f	No	Signature	\N
519	243	260	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
520	107	1	-1000000000	t	1	1	1	0	1	261	\N	f	f	No	Signature	\N
521	243	261	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
522	107	1	-1000000000	t	1	1	1	0	1	262	\N	f	f	No	Signature	\N
523	243	262	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
524	107	1	-1000000000	t	1	1	1	0	1	263	\N	f	f	No	Signature	\N
525	243	263	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
526	107	1	-1000000000	t	1	1	1	0	1	264	\N	f	f	No	Signature	\N
527	243	264	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
528	107	1	-1000000000	t	1	1	1	0	1	265	\N	f	f	No	Signature	\N
536	107	1	-1000000000	t	1	1	1	0	1	269	\N	f	f	No	Signature	\N
537	243	269	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
538	107	1	-1000000000	t	1	1	1	0	1	270	\N	f	f	No	Signature	\N
529	243	265	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
530	107	1	-1000000000	t	1	1	1	0	1	266	\N	f	f	No	Signature	\N
531	243	266	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
532	107	1	-1000000000	t	1	1	1	0	1	267	\N	f	f	No	Signature	\N
533	243	267	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
534	107	1	-1000000000	t	1	1	1	0	1	268	\N	f	f	No	Signature	\N
535	243	268	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
539	243	270	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
540	107	1	-1000000000	t	1	1	1	0	1	271	\N	f	f	No	Signature	\N
541	243	271	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
542	107	1	-1000000000	t	1	1	1	0	1	272	\N	f	f	No	Signature	\N
543	243	272	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
544	107	1	-1000000000	t	1	1	1	0	1	273	\N	f	f	No	Signature	\N
545	243	273	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
546	107	1	-1000000000	t	1	1	1	0	1	274	\N	f	f	No	Signature	\N
547	243	274	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
548	107	1	-1000000000	t	1	1	1	0	1	275	\N	f	f	No	Signature	\N
549	243	275	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
550	107	1	-1000000000	t	1	1	1	0	1	276	\N	f	f	No	Signature	\N
551	243	276	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
552	107	1	-1000000000	t	1	1	1	0	1	277	\N	f	f	No	Signature	\N
553	243	277	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
554	107	1	-1000000000	t	1	1	1	0	1	278	\N	f	f	No	Signature	\N
555	243	278	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
556	107	1	-1000000000	t	1	1	1	0	1	279	\N	f	f	No	Signature	\N
557	243	279	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
558	107	1	-1000000000	t	1	1	1	0	1	280	\N	f	f	No	Signature	\N
559	243	280	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
560	107	1	-1000000000	t	1	1	1	0	1	281	\N	f	f	No	Signature	\N
561	243	281	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
562	107	1	-1000000000	t	1	1	1	0	1	282	\N	f	f	No	Signature	\N
563	243	282	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
564	107	1	-1000000000	t	1	1	1	0	1	283	\N	f	f	No	Signature	\N
565	243	283	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
566	107	1	-1000000000	t	1	1	1	0	1	284	\N	f	f	No	Signature	\N
567	243	284	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
568	107	1	-1000000000	t	1	1	1	0	1	285	\N	f	f	No	Signature	\N
569	243	285	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
570	107	1	-1000000000	t	1	1	1	0	1	286	\N	f	f	No	Signature	\N
571	243	286	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
572	107	1	-1000000000	t	1	1	1	0	1	287	\N	f	f	No	Signature	\N
573	243	287	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
574	107	1	-1000000000	t	1	1	1	0	1	288	\N	f	f	No	Signature	\N
575	243	288	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
576	107	1	-1000000000	t	1	1	1	0	1	289	\N	f	f	No	Signature	\N
577	243	289	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
578	107	1	-1000000000	t	1	1	1	0	1	290	\N	f	f	No	Signature	\N
579	243	290	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
580	107	1	-1000000000	t	1	1	1	0	1	291	\N	f	f	No	Signature	\N
581	243	291	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
582	107	1	-1000000000	t	1	1	1	0	1	292	\N	f	f	No	Signature	\N
583	243	292	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
584	107	1	-1000000000	t	1	1	1	0	1	293	\N	f	f	No	Signature	\N
585	243	293	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
586	107	1	-1000000000	t	1	1	1	0	1	294	\N	f	f	No	Signature	\N
587	243	294	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
588	107	1	-1000000000	t	1	1	1	0	1	295	\N	f	f	No	Signature	\N
589	243	295	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
590	107	1	-1000000000	t	1	1	1	0	1	296	\N	f	f	No	Signature	\N
591	243	296	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
592	107	1	-1000000000	t	1	1	1	0	1	297	\N	f	f	No	Signature	\N
593	243	297	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
594	107	1	-1000000000	t	1	1	1	0	1	298	\N	f	f	No	Signature	\N
595	243	298	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
596	107	1	-1000000000	t	1	1	1	0	1	299	\N	f	f	No	Signature	\N
597	243	299	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
598	107	1	-1000000000	t	1	1	1	0	1	300	\N	f	f	No	Signature	\N
599	243	300	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
600	107	1	-1000000000	t	1	1	1	0	1	301	\N	f	f	No	Signature	\N
601	243	301	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
602	107	1	-1000000000	t	1	1	1	0	1	302	\N	f	f	No	Signature	\N
603	243	302	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
604	107	1	-1000000000	t	1	1	1	0	1	303	\N	f	f	No	Signature	\N
605	243	303	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
606	107	1	-1000000000	t	1	1	1	0	1	304	\N	f	f	No	Signature	\N
607	243	304	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
608	107	1	-1000000000	t	1	1	1	0	1	305	\N	f	f	No	Signature	\N
609	243	305	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
610	107	1	-1000000000	t	1	1	1	0	1	306	\N	f	f	No	Signature	\N
611	243	306	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
612	107	1	-1000000000	t	1	1	1	0	1	307	\N	f	f	No	Signature	\N
613	243	307	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
614	107	1	-1000000000	t	1	1	1	0	1	308	\N	f	f	No	Signature	\N
615	243	308	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
616	107	1	-1000000000	t	1	1	1	0	1	309	\N	f	f	No	Signature	\N
617	243	309	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
618	107	1	-1000000000	t	1	1	1	0	1	310	\N	f	f	No	Signature	\N
619	243	310	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
620	107	1	-1000000000	t	1	1	1	0	1	311	\N	f	f	No	Signature	\N
621	243	311	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
622	107	1	-1000000000	t	1	1	1	0	1	312	\N	f	f	No	Signature	\N
623	243	312	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
624	107	1	-1000000000	t	1	1	1	0	1	313	\N	f	f	No	Signature	\N
625	243	313	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
626	107	1	-1000000000	t	1	1	1	0	1	314	\N	f	f	No	Signature	\N
627	243	314	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
628	107	1	-1000000000	t	1	1	1	0	1	315	\N	f	f	No	Signature	\N
629	243	315	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
630	107	1	-1000000000	t	1	1	1	0	1	316	\N	f	f	No	Signature	\N
631	243	316	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
632	107	1	-1000000000	t	1	1	1	0	1	317	\N	f	f	No	Signature	\N
637	243	319	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
638	107	1	-1000000000	t	1	1	1	0	1	320	\N	f	f	No	Signature	\N
639	243	320	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
640	107	1	-1000000000	t	1	1	1	0	1	321	\N	f	f	No	Signature	\N
641	243	321	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
642	107	1	-1000000000	t	1	1	1	0	1	322	\N	f	f	No	Signature	\N
643	243	322	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
644	107	1	-1000000000	t	1	1	1	0	1	323	\N	f	f	No	Signature	\N
645	243	323	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
646	107	1	-1000000000	t	1	1	1	0	1	324	\N	f	f	No	Signature	\N
647	243	324	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
648	107	1	-1000000000	t	1	1	1	0	1	325	\N	f	f	No	Signature	\N
649	243	325	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
650	107	1	-1000000000	t	1	1	1	0	1	326	\N	f	f	No	Signature	\N
651	243	326	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
652	107	1	-1000000000	t	1	1	1	0	1	327	\N	f	f	No	Signature	\N
653	243	327	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
654	107	1	-1000000000	t	1	1	1	0	1	328	\N	f	f	No	Signature	\N
655	243	328	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
656	107	1	-1000000000	t	1	1	1	0	1	329	\N	f	f	No	Signature	\N
657	243	329	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
658	107	1	-1000000000	t	1	1	1	0	1	330	\N	f	f	No	Signature	\N
659	243	330	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
660	107	1	-1000000000	t	1	1	1	0	1	331	\N	f	f	No	Signature	\N
661	243	331	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
662	107	1	-1000000000	t	1	1	1	0	1	332	\N	f	f	No	Signature	\N
663	243	332	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
633	243	317	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
634	107	1	-1000000000	t	1	1	1	0	1	318	\N	f	f	No	Signature	\N
635	243	318	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
636	107	1	-1000000000	t	1	1	1	0	1	319	\N	f	f	No	Signature	\N
664	107	1	-1000000000	t	1	1	1	0	1	333	\N	f	f	No	Signature	\N
665	243	333	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
666	107	1	-1000000000	t	1	1	1	0	1	334	\N	f	f	No	Signature	\N
667	243	334	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
668	107	1	-1000000000	t	1	1	1	0	1	335	\N	f	f	No	Signature	\N
669	243	335	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
670	107	1	-1000000000	t	1	1	1	0	1	336	\N	f	f	No	Signature	\N
671	243	336	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
672	107	1	-1000000000	t	1	1	1	0	1	337	\N	f	f	No	Signature	\N
673	243	337	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
674	107	1	-1000000000	t	1	1	1	0	1	338	\N	f	f	No	Signature	\N
675	243	338	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
676	107	1	-1000000000	t	1	1	1	0	1	339	\N	f	f	No	Signature	\N
677	243	339	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
678	107	1	-1000000000	t	1	1	1	0	1	340	\N	f	f	No	Signature	\N
679	243	340	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
680	107	1	-1000000000	t	1	1	1	0	1	341	\N	f	f	No	Signature	\N
681	243	341	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
682	107	1	-1000000000	t	1	1	1	0	1	342	\N	f	f	No	Signature	\N
683	243	342	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
684	107	1	-1000000000	t	1	1	1	0	1	343	\N	f	f	No	Signature	\N
685	243	343	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
686	107	1	-1000000000	t	1	1	1	0	1	344	\N	f	f	No	Signature	\N
687	243	344	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
688	107	1	-1000000000	t	1	1	1	0	1	345	\N	f	f	No	Signature	\N
689	243	345	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
690	107	1	-1000000000	t	1	1	1	0	1	346	\N	f	f	No	Signature	\N
691	243	346	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
692	107	1	-1000000000	t	1	1	1	0	1	347	\N	f	f	No	Signature	\N
693	243	347	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
694	107	1	-1000000000	t	1	1	1	0	1	348	\N	f	f	No	Signature	\N
695	243	348	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
696	107	1	-1000000000	t	1	1	1	0	1	349	\N	f	f	No	Signature	\N
697	243	349	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
698	107	1	-1000000000	t	1	1	1	0	1	350	\N	f	f	No	Signature	\N
699	243	350	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
700	107	1	-1000000000	t	1	1	1	0	1	351	\N	f	f	No	Signature	\N
701	243	351	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
702	107	1	-1000000000	t	1	1	1	0	1	352	\N	f	f	No	Signature	\N
703	243	352	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
704	107	1	-1000000000	t	1	1	1	0	1	353	\N	f	f	No	Signature	\N
705	243	353	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
706	107	1	-1000000000	t	1	1	1	0	1	354	\N	f	f	No	Signature	\N
707	243	354	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
708	107	1	-1000000000	t	1	1	1	0	1	355	\N	f	f	No	Signature	\N
709	243	355	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
710	107	1	-1000000000	t	1	1	1	0	1	356	\N	f	f	No	Signature	\N
711	243	356	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
712	107	1	-1000000000	t	1	1	1	0	1	357	\N	f	f	No	Signature	\N
713	243	357	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
714	107	1	-1000000000	t	1	1	1	0	1	358	\N	f	f	No	Signature	\N
715	243	358	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
716	107	1	-1000000000	t	1	1	1	0	1	359	\N	f	f	No	Signature	\N
717	243	359	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
718	107	1	-1000000000	t	1	1	1	0	1	360	\N	f	f	No	Signature	\N
719	243	360	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
720	107	1	-1000000000	t	1	1	1	0	1	361	\N	f	f	No	Signature	\N
721	243	361	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
722	107	1	-1000000000	t	1	1	1	0	1	362	\N	f	f	No	Signature	\N
723	243	362	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
724	107	1	-1000000000	t	1	1	1	0	1	363	\N	f	f	No	Signature	\N
725	243	363	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
726	107	1	-1000000000	t	1	1	1	0	1	364	\N	f	f	No	Signature	\N
727	243	364	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
728	107	1	-1000000000	t	1	1	1	0	1	365	\N	f	f	No	Signature	\N
729	243	365	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
730	107	1	-1000000000	t	1	1	1	0	1	366	\N	f	f	No	Signature	\N
731	243	366	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
732	107	1	-1000000000	t	1	1	1	0	1	367	\N	f	f	No	Signature	\N
733	243	367	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
734	107	1	-1000000000	t	1	1	1	0	1	368	\N	f	f	No	Signature	\N
735	243	368	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
736	107	1	-1000000000	t	1	1	1	0	1	369	\N	f	f	No	Signature	\N
737	243	369	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
738	107	1	-1000000000	t	1	1	1	0	1	370	\N	f	f	No	Signature	\N
739	243	370	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
740	107	1	-1000000000	t	1	1	1	0	1	371	\N	f	f	No	Signature	\N
741	243	371	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
742	107	1	-1000000000	t	1	1	1	0	1	372	\N	f	f	No	Signature	\N
743	243	372	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
744	107	1	-1000000000	t	1	1	1	0	1	373	\N	f	f	No	Signature	\N
745	243	373	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
746	107	1	-1000000000	t	1	1	1	0	1	374	\N	f	f	No	Signature	\N
747	243	374	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
748	107	1	-1000000000	t	1	1	1	0	1	375	\N	f	f	No	Signature	\N
754	107	1	-1000000000	t	1	1	1	0	1	378	\N	f	f	No	Signature	\N
755	243	378	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
767	243	384	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
768	107	1	-1000000000	t	1	1	1	0	1	385	\N	f	f	No	Signature	\N
769	243	385	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
770	107	1	-1000000000	t	1	1	1	0	1	386	\N	f	f	No	Signature	\N
771	243	386	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
772	107	1	-1000000000	t	1	1	1	0	1	387	\N	f	f	No	Signature	\N
773	243	387	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
774	107	1	-1000000000	t	1	1	1	0	1	388	\N	f	f	No	Signature	\N
775	243	388	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
776	107	1	-1000000000	t	1	1	1	0	1	389	\N	f	f	No	Signature	\N
749	243	375	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
750	107	1	-1000000000	t	1	1	1	0	1	376	\N	f	f	No	Signature	\N
751	243	376	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
752	107	1	-1000000000	t	1	1	1	0	1	377	\N	f	f	No	Signature	\N
753	243	377	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
756	107	1	-1000000000	t	1	1	1	0	1	379	\N	f	f	No	Signature	\N
757	243	379	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
758	107	1	-1000000000	t	1	1	1	0	1	380	\N	f	f	No	Signature	\N
759	243	380	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
760	107	1	-1000000000	t	1	1	1	0	1	381	\N	f	f	No	Signature	\N
761	243	381	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
762	107	1	-1000000000	t	1	1	1	0	1	382	\N	f	f	No	Signature	\N
763	243	382	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
764	107	1	-1000000000	t	1	1	1	0	1	383	\N	f	f	No	Signature	\N
765	243	383	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
766	107	1	-1000000000	t	1	1	1	0	1	384	\N	f	f	No	Signature	\N
777	243	389	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
778	107	1	-1000000000	t	1	1	1	0	1	390	\N	f	f	No	Signature	\N
779	243	390	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
780	107	1	-1000000000	t	1	1	1	0	1	391	\N	f	f	No	Signature	\N
781	243	391	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
782	107	1	-1000000000	t	1	1	1	0	1	392	\N	f	f	No	Signature	\N
783	243	392	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
784	107	1	-1000000000	t	1	1	1	0	1	393	\N	f	f	No	Signature	\N
785	243	393	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
786	107	1	-1000000000	t	1	1	1	0	1	394	\N	f	f	No	Signature	\N
787	243	394	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
788	107	1	-1000000000	t	1	1	1	0	1	395	\N	f	f	No	Signature	\N
789	243	395	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
790	107	1	-1000000000	t	1	1	1	0	1	396	\N	f	f	No	Signature	\N
791	243	396	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
792	107	1	-1000000000	t	1	1	1	0	1	397	\N	f	f	No	Signature	\N
793	243	397	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
794	107	1	-1000000000	t	1	1	1	0	1	398	\N	f	f	No	Signature	\N
795	243	398	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
796	107	1	-1000000000	t	1	1	1	0	1	399	\N	f	f	No	Signature	\N
797	243	399	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
798	107	1	-1000000000	t	1	1	1	0	1	400	\N	f	f	No	Signature	\N
799	243	400	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
800	107	1	-1000000000	t	1	1	1	0	1	401	\N	f	f	No	Signature	\N
801	243	401	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
802	107	1	-1000000000	t	1	1	1	0	1	402	\N	f	f	No	Signature	\N
803	243	402	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
804	107	1	-1000000000	t	1	1	1	0	1	403	\N	f	f	No	Signature	\N
805	243	403	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
806	107	1	-1000000000	t	1	1	1	0	1	404	\N	f	f	No	Signature	\N
807	243	404	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
808	107	1	-1000000000	t	1	1	1	0	1	405	\N	f	f	No	Signature	\N
809	243	405	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
810	107	1	-1000000000	t	1	1	1	0	1	406	\N	f	f	No	Signature	\N
811	243	406	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
812	107	1	-1000000000	t	1	1	1	0	1	407	\N	f	f	No	Signature	\N
813	243	407	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
814	107	1	-1000000000	t	1	1	1	0	1	408	\N	f	f	No	Signature	\N
815	243	408	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
816	107	1	-1000000000	t	1	1	1	0	1	409	\N	f	f	No	Signature	\N
817	243	409	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
818	107	1	-1000000000	t	1	1	1	0	1	410	\N	f	f	No	Signature	\N
819	243	410	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
820	107	1	-1000000000	t	1	1	1	0	1	411	\N	f	f	No	Signature	\N
821	243	411	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
822	107	1	-1000000000	t	1	1	1	0	1	412	\N	f	f	No	Signature	\N
823	243	412	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
824	107	1	-1000000000	t	1	1	1	0	1	413	\N	f	f	No	Signature	\N
825	243	413	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
826	107	1	-1000000000	t	1	1	1	0	1	414	\N	f	f	No	Signature	\N
827	243	414	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
828	107	1	-1000000000	t	1	1	1	0	1	415	\N	f	f	No	Signature	\N
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
1	1	{1,2}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jux8H9ZWV7yAsgjgmVkZXoK63edsyDKYS9XJ7xdKTkDT4kfxgZx
2	2	{3,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv9NkbN1SN1EfGzupHQd8sxwxsJDLM9KZMH2m7mJfeQ8yKMuzct
3	3	{5}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtxJkcPAojy5bFeqrbqk4e2j7HtKexa9KdMstxJKP6xQPj2VBM3
4	4	{6,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju3CGTkWB6DUJmDzSnUA81Gagp8j1Dh3EtiErMuiWWVoiSboQ7Y
5	5	{7}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtyMfvkSio6L8854hywTkDUwhcUeM2WZDxNoN7r7G6G69YTbEgm
6	6	{8,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv8c8vRC1GQkR3LgZAJMYi2D4X7RybzFkNcdjCC6MsA7MqpbdGr
7	7	{9}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuFjgQsKrmJrBdRyLq5YwminpgJFbpmiwyJeSdHJBYLbXM35F84
8	8	{10,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtoGcybogYUB6bH2mXcywZqFT8Xypqp9N1UaAT4cuGzDqH9zQ74
9	9	{11}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtgudqkRyqzR6Mu8W6iwtQ5Zt7BNfWgXykTJJ1Lte7zsUaA4qkk
10	10	{12,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtrGj6e2xKYy5h2YEwU9dGtNt9CVfbzwkdMQq9bPraEgC5Gfupp
11	11	{13}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuABSoW5cL9irzt8WEEpDYgqQjj6BPHSw5aGDcxiyAhEu8ekqRZ
12	12	{14,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtw9PvajfVpQvkuv23hK3KxvjPK1xmpR8q3yB4UDffmZD7Bs4an
13	13	{15}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuLt1gR7EVJvyBj8RHwn29werNz5iaqV4aLNUJE7kxgNC2ixbd9
14	14	{16,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuMau9AnbYR6FD8ymtQigkZf5bxobnsMoeN2tW6QHtZon31Z3BK
15	15	{17}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv9Mpacwj9QsYQeAhSft76DSyMTo4eHhifcCTPiVu45xNBedkru
16	16	{18,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuD3NKcGGB4ARALrHUj6GUEhF61muv4wMUKT453CKod8zZnRGCM
17	17	{19}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv12EM8itzQsjX2pEW2jWJpUsJMVezHj1ktn1pTMLbkEz99L8Mz
18	18	{20,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuTfRzfYpEsiwsab8eGZEb6nYvKv6r1A51HshmVn367RPFtfDLR
19	19	{21}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jutaz7ufma5M1CqkFDBhNrdcj2uHkT2np1c6kqZ5q225BHwMDdf
20	20	{22,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuChckpyWfzetBzD2uNHjXZ1JFXzGcwmdJqNj3fD7xw1rXA2dNG
21	21	{23}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvHJgWLaNXwXLt41nTn3qg2pXZEuogi7hxsiwdhn6C7DbRnWgcp
22	22	{24,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtqxnVZQXyn4ji8rT71qpohShwkDEvxRwwu54crmm9pc9uvLcvh
23	23	{25}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju6ctdfFzvG5DfRCtWYmFGfbqGMPRBNDppvMhUzRfgTikb6msHb
24	24	{26,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuhwpVrkaJ85tY9MbV3dYHbYmus6ccnGAZCFFsdSPweaNTULYV1
25	25	{27}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtYxdpkK4XVPy4hJD13jC42m6v19xUHfCM9bUxGb3qBQVg5yuKN
26	26	{28,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvRejYVEuqiMP4wkZfpiYS2mA3MmS8Qgwwi2pMFJaqcRZS6eQqJ
27	27	{29}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtqCop6TuESDTwhEDQA2XqwekbBjLTg1dSL2kM15QrWLWryc5vv
28	28	{30,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv1a8QuXsL6REtFhBYqHSWHrC2K9XtVVmUCJqE4vyUUDNKJEi7Z
29	29	{31}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuUh5mCJE6jQwLtDGL5bXWcs6p6Qm8cPFRUaKhqRqGqwczoiTq1
30	30	{32,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuGfFAL7pqeMFVpSNJd92yMmcQBY3qLsv1DDmnusBegfzCYcxzZ
31	31	{33}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvHodPM7YmfRLyAdapw1MoEcGTHmhrKpKVdv2MFQauPsK2CMS89
32	32	{34,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvLLjbCbHaLwqNSgffUde7hG46Q8b3moDTURsssaggAGfTJBBGc
33	33	{35}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jub5SH4sEcr8NCPcv4BrDeMDeH67J3EaLomygEJeFeCMeTMPUY1
34	34	{36,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtWeXKQh6EyDSNkrw31Efv5641iKb3YWeaBhoNL9ZMz1jfnUeWS
35	35	{37}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuaFWLjDLigEdQv2c8RYHGWsCKvC6FmBKbg3JQbQ5YYjPGhsuKh
36	36	{38,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuESc7NRxqsLeMnzLNvupkqriLobDhoBSuSteo9J5i8J1i8peaS
37	37	{39}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuDyPVheLv3jdjbsBxK4fmVeWKfDL4ExUkdBc8zTZ1d7ZAMNhet
38	38	{40,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju8scNkdptUE9uWqx6j8mzF3uJWQ5Bo6xKCsG2KRqTgK2RcmKw4
39	39	{41}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju7XCgf47ckGwPaToP8KiyfdFFsMVBveyPuSvDAqyqsMX9Mwr8X
40	40	{42,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuS3srLVrStqJZp2J2P4826GnaxHb4cAbQ2Wrj6XGs8jdrVcS7r
41	41	{43}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuYmthe54hcFwEQQA4MYgJfhjckzZMVNL56JZanJNYzcEZR2qGF
42	42	{44,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv9p2o9r11mZzknRmNdfVqC11CUaL9SxrodGkdMFPGYMb5RsJAz
43	43	{45}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtgh3UBKafLSTmedpTzsWDGkL4U61njYrDQRqYGKemZxVijU3Ma
44	44	{46,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtnrMnnsGBc8JR76qHyCA1XVQc5Tc3dwg9BRGujS7HTNREteL97
45	45	{47}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvQaAvVpZBeXbZD8S76sNpuEAXuaDwCQ6LjZC1Zn9GBFwtXSJKY
46	46	{48,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvRf5AXmMaZCJCDyRjfe7s4BV8CAmmyZFGN9CmXtfZMRmrgCMvQ
47	47	{49}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvJd5cXqe6QuhbrTV3WhEgoP65LpUkSVjGoPq7gYUCm2iJLBwJA
48	48	{50,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JubyUvopWqsyGqzyhY7Fj3kX6zdvYAscU6zwWb2VLmx8JSVxmnS
49	49	{51}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtcGYTeG25BgTirTBZroBkzxpSJNTnpPxV471BcLtzEPipMjbvR
50	50	{52,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtX1fGhUpBy48gg73CZ7tCjBUMAkdmsqHBcrG891YUFeXME7t5h
51	51	{53}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtc6QmLYZnUjjiVwcAnS341Y77SjKXgM2qin1GNFvRJK5kzVJda
52	52	{54,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvFWJsrKnSkY9Tid378PRphY6Kx4bpRYA5drtssbAbkAEX1pg7P
53	53	{55}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvQBjyhbpkNYGc23S6kGjvTkGN4pMyYM2K2ZCPHWHn8hW5XyJF6
54	54	{56,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvQQxxVcUUTHJ9CBMxVcFoWCjqt4bDgoxhMWn8jqfjm72kvpsa1
55	55	{57}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juxrf9Pxq7UvfRz9zsKrEJmUKcDj9iJefX7asA9quTF79j71Qx6
56	56	{58,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvRRztnywDCnCWXYW9kr4D7Zez6RF5KnnK3P2TL39ohK1RxtuBT
57	57	{59}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JupDQXN5ckwY1kTLVHfZ78Yt95vLG4db9Aw9Gxrmt9rpWMb2zKM
58	58	{60,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvKCfwAkPqS7AGRC3x7oDpg4GHAyMMHqoGm4jy7MsvF36uTxidG
59	59	{61}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju9LNQackzwsqJjKebbPS9dCCpgUcFdchKfTLo4wcpD6pdudkFb
60	60	{62,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju6Eg5eU4f5hvDsoMFXGJ8kuRjwZucBtdLYQi4cM2aoyK2c1MbQ
61	61	{63}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuP38n3JYMLbD2j7HW1Kq26S4B4t85Laebvi4omhXGkRAtcrwqF
62	62	{64,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv9KfTyZ1edW1q6keB1UBG323aBmFV8bxiLmdXgVHspS67Lk8tJ
63	63	{65}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv494YSVZWxGE4DqYccPHmDhLkoaVZ1XRPRm6Gp4xrPWHLCvaX4
64	64	{66,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvHJgg4YrnU5qKUMN8MG2BNwdujHuCHc3h4aRfM5WParnRVxaKd
65	65	{67}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuQE9WtjTmqeGBs5vzU8kYU8J888VZPMvm8xKEpNLqMrLFyWe4D
66	66	{68,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtp86QJ1J13GTQh91jqipyD1BGQVAe9QA94M7WGpcq3NDohKjGe
67	67	{69}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtzXY49xFoB56o7PRyVApeFcN9wSNWNr8ShUDLN3h5xYQpNXeLa
68	68	{70,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtnrnMwapDvWBWzSq8KUoBYCT5ZVmt8HVGEXmKqdbFyH3CpXcJR
69	69	{71}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju95mCEfzqBbjvLxFWKe4aJsgLSDvVNJdVW8r73LSLuapESyjbA
70	70	{72,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuxbMupEZm8PRSHe7WHK9oDSUvs98ZVB2EtFSuVx8LUUxeLqRY6
71	71	{73}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juvxu4y5AERcXf3dLubU1ZeNTh7eZPZAYtPppeN5UvWjrRnfP6K
72	72	{74,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuPo7tsQDtsGVVe5ocmrHsjqZu7DRcoGWKYezerZwhu43cDDDkD
73	73	{75}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju1FBfSz8EXuvcRcU3Vz36yEdz4RMoKVBkpVAygZrzTL1Neaj9k
74	74	{76,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JusXGkLk84hnaNC8nUhsGrtBW9ZWkTr6kZAU2eQYiiRABeYxR7V
75	75	{77}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv1W2qqqP2HGrEHG6Zgb9MD9LNxPz7CUtNvSzyxgeK8XgQkomfL
76	76	{78,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvPLKo2K7fqgs4JwKeyMqb5yV2Yv6sHVfQtP8WLLaFXPPC6GrRv
77	77	{79}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvK8xvJ4ifjSfkU1pW1Psy9jfLzMgBnUGHQURnpepYgGyZheecj
78	78	{80,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juie7DNHmVep9iqhPhQsHAfosRuH9V5ALY7vyT39BgNzihrsg23
79	79	{81}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuEcKqtiibo7bPpaQRSMAEx9AknHXBEiuDAjvRry6rVuHV2m2CD
80	80	{82,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JujvS2WdjEAfDkzmhrCw7RFMmyTgAdUeQq5MjqTQ7uLwKYdJJ9J
81	81	{83}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju8qZM93XoU1JJGG6dJ1xx2LsYenCedcxuMamgbSCAZFVZ1aQ3T
82	82	{84,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuDgm8CXQAgyi8My4aTN9E6zyR3EE2CzGri4Yvr9GZ5isMxXy6W
83	83	{85}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtVpWn46pqQ3drLVnXUZ23U7dLZfMUc3SrCDButCCHm4MMing7D
84	84	{86,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juq5bB6HppGxf1w2VnLkKLe3vbqWjfPb8zhcaTCMSFA6eHcfrSK
85	85	{87}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtx46AwatkUuyFkfKZSbHi2oYM7EiywzfJqNtgy9NCz54DgRRXE
86	86	{88,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuhJxr2TRzaKLvXudi7JciJ53ZgqmFf7YM5ZXVA3zJPMLCRogJZ
87	87	{89}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JturUjLtxLtj8cA2t9NmWDATPuijKksqCVgKf7KPyoiEAX3VHWA
88	88	{90,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvCXsSPjQSthy4pfqwpSd9V96ifpVEwnzLuHJo7jNkW2AKpHyoE
89	89	{91}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtm28pRa4rTeyGLeVr9eTmQM84vFGLi7PM8vBETNpV2xBgw5crx
90	90	{92,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JugJ9qxtCAGnqwJxcie42n7LC4j1swN1BKzK2DQoruRVihJZJ7H
91	91	{93}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv1Qx9vQmtcEaaNGqVz8M92fKwmnGY9y7PuCFV6fJjC8ZejETPC
92	92	{94,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtdBJwQQibeF9Gs49WrRLgmLawLttjiagU2hrDWxzxhTXaXfXxt
93	93	{95}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtyz56gZnWSX8zAPQcqgJRwt65gheWNo4FndY3iQxbgxSgxw24w
94	94	{96,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtv1ZkW9DKRbVjkyuhX5ieSDBPmshoj5NeAkoMHWtcb6kGthrXL
95	95	{97}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuNxpdzLP73Mm7CoXwvGPvpHyQDcnQ569uFKQmYvytfPgMLMVZk
96	96	{98,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv4gY7Pt1AEx5ipUMYrizuur6dHnAtbYiJ7bZvCpg18eZw5bjdb
97	97	{99}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju5EvSk48vHecniAygC2PEwYTxziW5W4DL8LR6uDygTmYTvDEyc
98	98	{100,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JttbcbAZuD9uMP76A9tvyuBPUXrLUuHLSeiujF3fyoKiKbRuVct
99	99	{101}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv55E1wXQCyK8w6Gwa2tyTTbF1WQB6SRBVMLADRfAH1UvdyJ2J6
100	100	{102,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuvDMu2yTYTGLLrbRrFTWn6Zfve6NaK71up6FQjn14QgZySV85S
101	101	{103}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtkJEoqv9mcaLrGq3tobdzsKw88dSczzMnK9hQBDC7ANKcJzWm6
102	102	{104,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JthEQPVo21tgfgsy4hhf9KoxHqMm4YsYmiVpu6t7D9CgxpVS5Pe
103	103	{105}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuLh7eKduSHFiZLyMweqPWKeLqKiqFNgqzPcs5b4vHaEEaWa2f1
104	104	{106,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuEc57L3kCawBURW3btohbL3Jq6Nig7wMkohzNnn77GFFZMWdFg
105	105	{107}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju5Tzh9rJVrjJogE5LRohZuCwcZ7XYLGFDJgrrhPG8bpn5nv1k3
106	106	{108,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jud84z8qixe2p7hkFcs2pytS43epakpyPhVNmz5gjJkHt7zDnKX
107	107	{109}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jti1h3WMgVZ1A4mLgbhUfrCcQhibqCBUewLTi8bj72Tmm5MonKW
108	108	{110,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju2NnTPdtFLKuko1WKVNFemdT1U8WVPWQE8wqKVJWTdLKaTvfiT
109	109	{111}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JumhWYLmZwAViZw6PqQHW15ENoXDrfAanMpTgmPcipqf8rdU9or
110	110	{112,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtyXeYqzCiYYSewxB2LGEUNgQaBir3hgEct5KD8CzEk3aWu1gNX
111	111	{113}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuFZyAAFmSpg3cH6z8Wg2XRGM1s3BSTf5ach6eYzaqFAbbS5jw3
112	112	{114,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuKGBe98nWaMkqgzD56gLaF9vr5JDbyt9Kw5o9MU8ohhS3yopCn
113	113	{115}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtWjSDFdqVCsadUzRLFoyun5N1gaQntaSm7pTFXx8dCyM8jTS52
114	114	{116,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuYw44wAphQYZbvqFeioQ691XK9HYhsAUKM3ynrvdQvMjDHZy2w
115	115	{117}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtZJn4AFhkfZt3iA3Q87icGwm7TyLDyhzbS72bbSxvdJtxy5jf5
116	116	{118,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtrbL7P3HU9XCArdKAL1At7563HRpG4effwK3Z4oYv3ywPDvazS
117	117	{119}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtt8qwRTh3ASZvx4piNSq8tfgF1q2NDj7jXaDLjKz3taSY5fqFc
118	118	{120,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuTek5BvUdMAf6d3N5rcofJtXdhWxBfvr2HepbrGRDBuLKetPCs
119	119	{121}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juq3AFKZ8njrNDTzEkERKccykCApGE23LxEqaWGd1EER6f4579Z
120	120	{122,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtdGgQwPf6jLgVdhNo1iHPxcBhryqFVPcBBDr2DXf57YEK6pGA2
121	121	{123}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jusai9VkQA9tozAVn6M9DuCSAaw6p55BonCJfqCSNNbGZeNdLB9
122	122	{124,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuygEFU5Ti3wvNZN59GhFbJf9bgTEYtThMYs8GqpGMmpbU6pvJW
123	123	{125}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju5LTtvcKxR7tW8xw85urPkgxZTU4NAaMbXeSBdfyzqn5JVppHk
124	124	{126,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuQgWt9GS4cbEqG623aZPfhx82Y4gRudJsfPQhF21dM9pGE9KL3
125	125	{127}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv1R63zEN5tj6FEKp1nsvGkxcX5Q2vHHbdX7JmNLXDv6UqZ9LtR
126	126	{128,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtd1bDo1qUjF39E4namp5ig2BLtfy3Zbb3B7AcmPEayrFi5jxig
127	127	{129}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtkQRsYrDUaD6sfZ64PZanFXAeXdTKbi5YTxgmADN3F7K5xd7G6
128	128	{130,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtfoLWchr35nsMTh69z4d2QKhYxzxueK6WQEguXWkwnnVBSVVpU
129	129	{131}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JurRbfysJJnjhsAhzJtYsB6BXN6E5h6pjcYJZprarAEU5sqoSTe
130	130	{132,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuHy8vVbNtMB6Ja1kV7TsRMiXV9rHLywteEpxJUadAc8fWNnSZN
131	131	{133}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtcHHtSsd8dVrda1vCg2UZf5aUfRkUjfWzm8ytfL7mp3scGpc2G
132	132	{134,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvMF3ZQ7Au7x2cT9sm5YnvCR6Cs1FNejDWyjWj3cWwbbPvuR7je
133	133	{135}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JufkyRX4nCsSc2yp1AxGRDifgj1f9J28wApaJ5gYek1j5fEQUNU
134	134	{136,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtsKVQF5NTUZdk2mjmr6g3LhcZ2s3xWz2WHSGRF7g1gdAUZhCoq
135	135	{137}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtwewrwWi9pZ8aggYm2iBdt3RVKy7Z6KHxDoGqrZ66UqLHH69gH
136	136	{138,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtsRZ99FG59eW5i1E1w6X9qNS9UThGi6eHCcnN253mgdoi4hyQx
137	137	{139}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvE26MMw6UN1QhHKzZxZW78mb66xqzbic62n1wgF4yEqNETSjPg
138	138	{140,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtaAnE96imXTriK1PYiy8jFjEqSJgp4MWfsSgb53vgAUjyApNsg
139	139	{141}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtXaK9MX1wx4ZFMrQ21k2mhr9iTYMApg4JbZezrowjCosEuKdcV
140	140	{142,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvJZy4h27hQWmeMyo5qn1t6RAYJXf5oANpgujqzB3xcPJnTd8Mi
141	141	{143}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtpaWgcyhQMo9DWVG7Bno5NqtvxLMKggWkGLNj9sehGrM28rX7M
142	142	{144,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv7CHRd9mggL4e1NkrnQ6Phh8NrxPQtQry5Xh8kAKVyZVrXqL66
143	143	{145}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv2JzQezqVZoiJ8nGz98VzLFtf7L84rihP7QefjDstzdxswvcoU
144	144	{146,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtaexekBW3Uz7NhRNyU2wDjgexLhVNwCGAMw3RZQr1LbKd7Keo4
145	145	{147}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JunswWGhpoafQmp5wqrLmbP7gjpVpFSYh6hcXfdAa7Jq6P8UP5e
146	146	{148,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv4h1KLLkBPHLmkqB3UTLDS5JJ4GhNG5SxzJDMbeDubQ3SB2iwz
147	147	{149}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JufEnxvLLSeF6mTKXeVPBG3kuU3yby5CzBF1jWgeJ99CUjhPfQW
148	148	{150,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuKGBTQ55CFpjFrHKseKc5iPxr54RHkuiqhBz6tVVxn6Tywkgyz
149	149	{151}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JujNpXmUn857KszZafjSG1zyHPDd5YobL997RVgZFWAppKWMJ6Y
150	150	{152,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju6P1AHBimBNTWAiMcGTa9tegjjP9VPQEmnYXa9XEAaR1x1gAWd
151	151	{153}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JttswRkxTZCPPHacehbqpkyYz4ButJVCDMGtYBQZmhywbkvgCAW
152	152	{154,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JubFEErsvpYwD5wmAR5QgLSXdBiA61SCW6KTdn2fa7rAryRmcpc
153	153	{155}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtghXqhLJxBxR4mUjbfZMsGb2QTo55SNoPLhafM5zKRRMBaan6J
154	154	{156,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtjLSAuN5HVvdQbf5MHcvdLvgmRtKD4ftWsuJQHcfnM6wSDQgsC
155	155	{157}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtczVMUdTnaRcqLyhwzyiF8q2sAqVtBNDETEczQzazDQNRwbNzu
156	156	{158,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuarCvQbtGiRDGPpn9QWjhiUMGePvZb8eqvb1LaNiE7HAaygggR
157	157	{159}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuWoNV4cgy2Qi6x89g9d6oURpsaCFsVusm9zENnt44GgPfhAUg4
158	158	{160,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JusapPsCVQ3STh4r1fm1yEUMXerYQtinxZPwmzWimuWMYMm2sEn
159	159	{161}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JthTiHqJfmPKFGVL1M6sJVkYZ7NHtVzW9cyqJNHbgCSjnD635AS
160	160	{162,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvEFPx8pmyS2j2XaEaMRccMuvyui85cbxWeWAsbeo2Z17JwZZQG
161	161	{163}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuyHxVKKxc8rqdmzFzJEQNHcFeqCrMn1akeaVd83iLX4obUNyeR
162	162	{164,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju2mhBzTJYYG1Fi3m27HMDCwW2vtmGVdhGrjnDUxDkcDtGU9n1h
163	163	{165}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvRr4q89LKEAjuMKSLnDrbmoyrTmD5D9nCZwnSc86eVGjivnDhF
164	164	{166,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtZK3FpVDfL4SjUiGVcQsz3yqXVoFK2Po1bFMqMUaLM8JzEQzoN
165	165	{167}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juya9hgTxVfpYFXU94BVBt4SYCbb4wybDfZEaKAAqCEAXAWLwMe
166	166	{168,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtg4mKGdDxUw8EZtkYXC21BBJWtzVWfwDWpPWPn7FmPVPruExgb
167	167	{169}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuEUJJ8PHau7AMH2Zeg2hUvrRumFVJrhLSnqoWiN1FTCxbgE9gy
168	168	{170,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuKLhipk5Gz7bwXpP5kMCzX2XhktCg93pWdmTLJkhKsxy9TA4nW
169	169	{171}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jus2STHkQXFZg4NGuNDiNZKENy2GmEybP1MBx4Ks2MCqs9MhQBq
170	170	{172,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtsB9c3uwHwqKbJheTCAxNcwdghpWEz9CHMP7SiHaSZ9xuYGcPJ
171	171	{173}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuduPzfxSDYmu8hwqcSb7i4tu85zhZFa4eu4pW9vXTzhRj3Cgwm
172	172	{174,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvJVqaxuCFcnuYBjUNb86GCZiSWaLP9LowPJFJ34A34S929tCqo
173	173	{175}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv7srKSXa17ALY3SPqozXJDwj94FkQTdkVaUFZyf5xBdXh7bsDK
174	174	{176,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvHkXMPfLyZj7Z8RRNPjDqRANJ181cij3StiXR5HYG2dhp3RjAr
175	175	{177}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuJ4nmyEEY5v2L1a7LZW6FRPgbFko7PT4F3cpa6rjf9NVjvwocC
176	176	{178,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jukwi1GNDoHJMmPPTcSXsNCSVXRJeeEpjuVsSjMznTYFZDcPUtQ
177	177	{179}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtfA6SP5H1HJScDuMDu4nksCv8PBi5LosAQhdzX4rV1uZ1LXn8n
178	178	{180,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv3tp1FvRBzdcnUiYZLqsPmdpQtGtujxKgn9wWVBZXA2MGgqNGo
179	179	{181}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvHeSerdqr3osZPGeZQhsYEqiDkRhiGsxLnxxCRXaciDMPg7QaC
180	180	{182,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv4HBGT4Uqy7oewHQcZ4sA4MAkJ63h4iZce17NWFwaABzk5hyzE
181	181	{183}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuBMVrGPnRJ7kY5aHK4Tsbs41xZXbhovkhvnNCDfz2jWffasgtR
182	182	{184,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuKyATdTuqzbwe2Q2Tdfr5rN2NkH2ccCZ7QfKv3XZxCRBwFnnsT
183	183	{185}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvFASd3pUZpn3v8WJR28FngbatTZ1A5pEZhn4E8eJx3a1KDwFLw
184	184	{186,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju2gKgF782ct8VHQJ392mspUpREMrBbhCY8poYxHg289AiP7pHX
185	185	{187}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuZEExzb6pBHyLUJkqfozV5WAi76aFTEmzQz3eVGoeBX33A4r93
186	186	{188,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju398omJfaGoFamaqk7nTxd6jFSmKn6Gpn4TjqeqVczCZ7hCsKF
187	187	{189}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuESJ2BQvS3BVfPQA3oR4gFt7zGVc6Q7G8PoaHZPsyvz5j88U6X
188	188	{190,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvBA8G2tEBFAGyS7WVfGDqrczqyqA79j1WitjyskTvQPrjkyELB
189	189	{191}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtxbogy1wJKKQPWuBCjheWmoH97D227jU6xHBTbsE3HaouRdAjH
190	190	{192,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtmPFF5vwRt8KMYS5QWRCWogLswZbzpj8XikgoTBbUTKsAheLCL
191	191	{193}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtbbHQPteCUfmtR2he8hNneEEpz5MP3gY2TgVodcADTAWhD5T6n
192	192	{194,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtngVfJg4JyeffwdrbTix1He9pgZCR41r552Hdw38dh4tXcpdyw
193	193	{195}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuAGitPCXWN4coxGLcA5QKd3FCKsJgE2M3PAtBH5zhz578CD4v3
194	194	{196,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuBoUo2SFKmXmVpawvq1Ukzpri81L92nTT3782SQ9ZkugedYvMM
195	195	{197}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jutv6nUdtgW24dzsqZCzgHCbqCfWaYhAPvk3r1gfNSMZEVqMShA
196	196	{198,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuUX1vcNXZkBWJcnArFhhrcmR2gS4JYz72a7dquJsppX581fQHC
197	197	{199}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtc6yYnTn94Uo51a8ndE9dZ3tDtNHbC5gfyuuM5cRAGrYiyC11G
198	198	{200,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtcPRiPwyK9QwpNaPFvNPEU2YcRTT5jMENKvPmtHmPD7PhPcAKV
199	199	{201}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JujTpMYiEtEuat3iKU13jFp71XdB2JAMYobcKuHnb9SN2R6fwDx
200	200	{202,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuLjUf2tfJDJ7MmLMjNzMcnMS4fZ3YAzWWrpWzfLEcgV7nj4LQP
201	201	{203}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv2HmECmmDhdFNJ9UJYVMEYBLQP5RTFdu3gKJDVHdbdYMnxCkCf
202	202	{204,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuStoVurdhwTWT2NbCUFU1vc8qnXgrHZmRRVwGZkkde2EAyp77m
203	203	{205}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtebG6BtrzRLhE382BwgV78eqqyZvgzE456syz9fC64DwKt5Mkt
204	204	{206,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuT2KG2bVpYQyyWqwHL5mBAS44TKRV47TUWQtPkRggHwytz6yLU
205	205	{207}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtqabdfPBaRcu1VaJcjfzwXQ2Y9PRW8hxFwR3GyqHDhZjTTCqVV
206	206	{208,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JthNnWDRNYLmGYeUucejWCHTLWg4vydnxdarj9tnHVsRXLEZgMn
207	207	{209}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvBzkjwNoMLTKQ8o2EsPKZC1jNvxEsGLMt56t3J36yarvAycsAS
208	208	{210,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtpp6hX6eAWQQnVRwzmdgd7KwguMKiC1fyMPse5z1cEPLdenp8n
209	209	{211}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuiN2YeNAuCMp5ykMXik2F42MDJKVuC7ZeuvhHgG4vzisqEsLER
210	210	{212,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtWewTHDwReMKp647K3N54Z1hVvgryT3vtKHJzSyxHSQAjfcQ8A
211	211	{213}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuKFrykM3TMyoT9L1mM1g7NtP7CTNiEUA7fZfa3XiudnVuGBsFB
212	212	{214,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju7AWzprFLtJN6sNuRdi99n7E54EYPbEnh4L1p16CdadHvitZcL
213	213	{215}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuePsU1uHLwT6SQCkGyXytcDbVDYtBcKjXP9WPj4LvEwAMkJUai
214	214	{216,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju1Tht3RSLgKnLjE7N6R1qYkfmWWyX8mEk1Gid76Wj5fmBXxKFp
215	215	{217}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvQZYURwQoiBdxoWFSiBeUSEBAFhLGJ5frvMMDkDYBND76Y8ctw
216	216	{218,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JubMmjGGUhGQZCfqoBJAukagqNvWpmgo7JPoVLAgfAC34s9JG9K
217	217	{219}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuajddxArebBrGTgyP5NM8ZXtRXXKQsQA6vYBnYvdXmrw49EzRt
218	218	{220,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuZLfoz6VxDzm8Cs1DyHZG13MjRWH91y8rFN5EAortUedReSeVa
219	219	{221}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuXTzAFaNhU26MBvKb5wPg2x1hsidT5uBBCFdvHA34WkYvFoC8t
220	220	{222,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuEKCAjDymY53Sweb4AdPhyaTV659wAggsz6EpW5L3guNg6L4Pu
221	221	{223}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuFKdCa2tA9zssoRP6E5dnZyKmXkS3esMejMomsU1qGkjkbXUSA
222	222	{224,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuqU4uvc2Zft4BuDBHCjeuCaSJmxFp6wwNGSQi9okhwciAK41QT
223	223	{225}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvDDEp51dh4g4j9z9PyNSYoZVrc3WBA8r6ACvhoVdHuNpPU6Vgz
224	224	{226,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtVURgUhwAYSBVNdQYbkeiSa7DzaoJUYpeJQFY6NpSkusbDjLEe
225	225	{227}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv2TYeVc8xom3fTm8sHbmwAXqiayn6bQiQdwSa7c4sLPnTEM8B6
226	226	{228,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juey3NdxHC94u3NLSykwVScviMJMP2UKBTRtkobnQCewfoz1EWo
227	227	{229}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuUfejpNpokubMZE7VZSqaLySnPq8DsyZQterm58ck77Cwa1gKv
228	228	{230,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv48HrQMbiJjKS4dDTfqMnAnZ1vZiBqxMbGeNEU8QPXbti6qa4k
229	229	{231}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtnCpqxDaeoGbKbfwt4S6TwV6eTRxWdXpcC1FiqAFBYxqKjRqaE
230	230	{232,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv5u43RiEvpuxVyTGNeer9rtzChXm8hWsRrEgL1xFoHqc5FLrtV
231	231	{233}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtrK1C92MJuUwKZUzJbdb9cmMZA46Vee7Tk91afkqVsqdpDD2RN
232	232	{234,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvPjH2QkUfkoonZNpkVrLmqY1HQbbVZDSBHtbYExScvC7oMUE5h
233	233	{235}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuUeMPJQT7Q7YbVCBFtG5NMrQWqv8RoSTQByR5VdgAH9u9R64KR
234	234	{236,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvDXLqRgAxX7QGzt7dEcFYoos2DGipNj8zesVfLDt7Gc72WMjit
235	235	{237}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuPyLEoAe7c3WU35ekJZJr5scwibd6CP4rCSn6H75S9buCBFv9V
236	236	{238,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtwuN4Bd7SJYBdFkYA185VbwE2S5P2swpJ242RaJ2zfeNg81Mb2
237	237	{239}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtuMJq54icp5er4GE2LfHvbjotWjWhwHSyx8V5p7BqXZ6dEzo51
238	238	{240,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JufxiuXqacRNbAqtTnutNdHi8DoENpZ1wA5wy3wUiq2qxzJb1tJ
239	239	{241}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtWV3i2NcRu37CaZKP8uckKYVz8RYzYuHWX1BLcMLnMc6RippWN
240	240	{242,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jthm3tggL42MmLtpmWpibJP4TzgbzhQ32dbU23DPawZEVGMMrs9
241	241	{243}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuMtJztSh9WGVc4vc5C6p3romD1TZrjbgBqJyFjbbR4C4TShswP
242	242	{244,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvBeeYMzVtnzSv32Her26cU7oEsJ1ZAG7UYR6uVTfNnN5wE99NT
243	243	{245}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvL65QVuQxiHu8CAEH6mkF89FQ1FPQQWE5kXM1FTz2AVAi74yMt
244	244	{246,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvDp3Wvr9wFM3aw4jfbm3BKhP97BdjNLR6bVsYaupzvfW2QqHoC
245	245	{247}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jts1wNupB4EZNMwZprr1v5G2VQRbAyJw64m5MkRo8MUR91vBx6y
246	246	{248,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvNmS2kU4eHdrK3aib4MLYhANzkj4ETptdeEZHFCK4xBe4o4pTA
247	247	{249}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju3jx19oq4FsC4LqLK14zXp1rUdMekB3tV5DQrkr7DANSH8YPY7
248	248	{250,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtdJSj4mUmW29L2aaFytME3FV68bD7zBVukvzM7QzMJT12ar9cM
249	249	{251}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuHhFfRZAqiubPCgJ5kJzLw51WaEaFddeWMg9u2azKEdZJ9Fvhc
250	250	{252,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtZKjMaZU4a37uuiTsTzCc6LagzRjTgserYYzQVW1PgZ9VXKjJL
251	251	{253}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JucGyYqwm2cRHUj1LNvH3vd5nm6hhR47UZb6vHvajupwe1Jr68V
252	252	{254,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtpqq6tN8QBFeSG2UUatcDctu66MsWZP3G1SbQ5Bd5fDevrzD28
253	253	{255}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuhVHf17mQu579hPde2epV2MZhwSsRuEhkeUkUdhejyEJ3QzkKD
254	254	{256,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv8zXiUVUKYCm7NhKSYvWSApe9gbkHUEBK7eNEJ8bMkithUEtgE
255	255	{257}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtamLe9r76LQuDhxBnK21amtZxTGDdDff1i4Mvd8wM1WfeivA5R
256	256	{258,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuDeoonxWBuhF6ndHr9Qvcs4cN9ba8fSz9P6z4L3zoBwmg91MaN
257	257	{259}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JunUqChYUbKbyLxDUcDwMNRdLKYRsMfMEJPCp9fpo1Cp7kkGx3r
258	258	{260,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju9G9Q4BLgMhPbm7gnPH1SkuUng7Ph5sDfYUvoj7HjD3jtM4n6j
259	259	{261}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvKFRMSvFE9fH7875P5C3YbBydKpvL3YAAPkqpeNxGR9Frz4RHP
260	260	{262,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuJmFL9SwqRdDeHNZHe4uvzrvbaW1Sr28yxuqcXurWUtsLK3Uqf
261	261	{263}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv9w9ANyEhsR1epbah8VumGF7T5b3wySoqvRgT9ijzJjpdPD7v1
262	262	{264,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvGFPPSrmn5P523SSHVzHzbQoUcZy8orWRTA9FGtdLUPhGJUjxG
263	263	{265}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuMJFHsPsub1UJSwnwi3vgY7XWxSCsjwj68gsHJ86xBvcCKeK6X
264	264	{266,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuWLeLSGJ2EEwsM4HesBxEg45dS63ZwHkCjgmcYLEJ5eBHSMPML
265	265	{267}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuHmNRHzTryFrNVqnZU3HDaPK1A5QZzUW1XoX2s2dAgutxntbJX
266	266	{268,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtvsTC665CCGpY8gTJ2EaWw46c4Kjxtdq4LMor63BKTUpyQoeW6
267	267	{269}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvCyms2cD77YA1Sxvy5XZYsRqDG8u3SrQR7pff7VfT1xrqocyip
268	268	{270,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JttSX4E8YApx2ZfcKkpJEbcPaWXU9idFm3BdAaxLLzhQyroBSh1
269	269	{271}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuYtFU6enYQp9cPfCUYq5utYZ9ee4JJVVpSVq92BKFFP1xEStbK
270	270	{272,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju5Pe8A4zWfSJBkGD2ubCwCLGY4cgivBqEqyud9UCVf8eE2GXP4
271	271	{273}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtwa8a3RDDqEkzHqEkPMB6ak4u6zURwWKqENE4iQWhiyqs3pERp
272	272	{274,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvCNuYpAXuH9fQwJNV7oPozEPPsKGjFboYKEiMxG6FjR6tVGDnu
273	273	{275}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtsajs3yk3dpncdxZSKJRfHPTa129EcuzMK14Hbq4ziDayoA1yD
274	274	{276,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JujPkRrSvmC7fdbfVv9achtX9qQHXrv1zfHcVVL3b6dcCrs2qbM
275	275	{277}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju6R4c5QCwLLh5CYLwwdM3afRSAcgxjDGh3XgxUpXHK5eKNumWY
276	276	{278,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtZoc5FtHdr4yEax5ekdZjYyEX94tajNnhn3nbKNYMqgHYPPsMq
277	277	{279}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju3LCdVv5sLCy9iTJZdswj6bDcJ9e2RDDCeyRkazoNfUsCfeN6L
278	278	{280,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuRgYZACMXPpU2yriti3UAQnpRzVnGm28Kvb6xzETiN5eGwCBNb
279	279	{281}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtioPgq1w6jSb14ernestpG59Ae5uSRQgmjFNUaSQoxMKFKQsGb
280	280	{282,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtb8u5E95weUBYsM9BduUZZPwTpQX4N6Xjxt7A1MYASBn43fvcX
281	281	{283}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JurxgrighB6f2jCkY33hJvSNVWHPgbBM4YnudJzb9dBrPd2tB1w
282	282	{284,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtpvxDg6vAmmug8XFCVpdxA1iNR9hUNGARnfYpcE2EUChDPoc4w
283	283	{285}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju2DPexLsVNtqmRwEK8gWfon4uEaHFosC2sLqyTuTwodX8GgsEH
284	284	{286,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuxmuPqoc7SvEFqZWB6ZYvmMeQUmapxXouWoMUBBMm9daiyoSfj
285	285	{287}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtnADSf1Rx9WCKVSpKZrfGvcRoMyNr1wmwPD6mGKBmNy1yfEHRe
286	286	{288,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JthWHoZTcoyTovBRtg9Sog41ax8vRpSBjfq7yedUiAGkTy8NoVc
287	287	{289}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtgUXFcEbUWdF7zWrpKgzM4D5cXc4AATL5gCpxvCpNHmoCKtcqa
288	288	{290,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvJjZ3g24rn43jSgS99AuTYHG4M7heGETSvzN5hmzsSafieTAMN
289	289	{291}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvJVb5Wjejyioh6qLvZ6SUMrB6Cif7bHYRjy4nv5veSu3cmKMC5
290	290	{292,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtYSgj29yTeWSC9D1t7GTvZF9p4NykpoqXRsqFfCw4R6RJPmdj8
291	291	{293}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtZuu42i39djY99sqfxERHN61G6zVgVVWAht3m3LUE4eEcJc9yB
292	292	{294,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuZfVZnWHvGbcHWcENU7ajK3J9tEu3mdQCgA1kjYNGe82TmucC3
293	293	{295}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtf5uAv24mj8PrPNdTGPyXFcB7Ffh7wWs7SVqXtRLFQLbYS1GdA
294	294	{296,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtwFhC8t6UWFiXo7aLeyMmQj5u3VGZJNP1U5E6uvPhq2KWiQcJj
295	295	{297}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvQByPDga98h6vkAqRMbP1EDEWkpNJczTSaBXXbjWuGfnsBAZ4W
296	296	{298,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtsUqegKQ8YhWGvR46SWuag6kzKKuNwpCZyqHjEZAWkNtJJQTg2
297	297	{299}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuqFsFfHjUbpQv45BEUacv1MvRsGgSY7wLbybispwYz6v5UxYjS
298	298	{300,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuZG8b3AUPg8yLiu8cBFXtjAL7YqpLVsQhnwcw7qhCTfENEmZo6
299	299	{301}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuXgANzQAmYGsMAQxnHJsbk9h8BStTLzEEJVsFJwhjvadb5fanF
300	300	{302,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuPH1EY19C66pNq6FCpxS5mzitSd7bwNzGZawHDBBq79Q2V1NQz
301	301	{303}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuSZnvAGLFAZapM8syw4dTs3t2P7YvjTWjMKFFFGPNRJUTiiA75
302	302	{304,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv7TzAA7KPquxJMpAEFQ2w4NPF4usUhqYq8Vwppit1KHaU6D7Tv
303	303	{305}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuP81kYuDhzsELFQVFVzbxbA12hSG2xxDKp11kuAV4WsgpTKmHP
304	304	{306,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juby1bf257DwnY2JwCVaWKgWFX2imj13XoGGyStqPh6yyKNtGMq
305	305	{307}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv2t3yJHibpXkH8QfrHycerky7PGwPgjiZ1fjJ6SzkFLS6qXb7f
306	306	{308,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvA4miAJfnAqGVbNnPaaC2C2m9gxL3Q48HwjaKBwZV3hJzB1BTB
307	307	{309}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuvpAj8BYHLgHWWQVZb4rV48o9pfRbF1evk6NNGk11ETTijeYor
308	308	{310,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv2JjEEwvavoBbwFi6RtiZo4wVtYpFeYB8CiFy44QX7FcqLVaF4
309	309	{311}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju78ZKmcZx6rftB4qGPanEXova19MxBwtn1EBbKy58GWbbAEDXK
334	334	{336,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JthoUoL5Xc1tjAGNZvTaNstU3wptz5pgnoFgotN9kAm53BsrhUt
335	335	{337}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JubpCy4sY7zaRbV9yt8XuCUb6VmCMqxTZn32xGnWRftsx8Bz8ii
336	336	{338,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtf9K17qf5AMxSsU2ARNZ79T5gyBj4Wih2jT44rLLjv7p5BMx81
337	337	{339}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuM8yKRGRv2XgCn1aXVjJ1GLzKQFT2Zq9KtwzyUe2FEdFjRs4xF
338	338	{340,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv8GTvykQboviUiHMRcM63yw94jm8Tuk2LATtQmtnYJb59wmcVJ
339	339	{341}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvGmjGd8oaJd52pjJ1XuxuHk48TSXJ3iNik1QuVkvffgj6Qzuhj
340	340	{342,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuCGeqnVDbneTSkCcwmi3wHhFGP6qHTNNaCEFZ4EwvCYbSmpE1f
341	341	{343}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvRrh2jjvpxFVQ1GTiH9sY2aL2ppZ2FHChVxYYA6FHYH2m1zzCj
342	342	{344,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtd7cmigJczEgamY6Hve5tifWCHQECFyEDzeg6jLuHemDRHFJBY
343	343	{345}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv1akvh4XpKDmn6vV8vFKv3MHu4FtQKQZ1Z6Z9RUxnAerU13BEp
344	344	{346,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju8s4sj8PEpM3MS6N5JD5dmeo45PfKr4wPxqWxZ3UWLeyMyDuxK
345	345	{347}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju4sezi7QW9exDzMNUAU559Yaw5tFXij1qmVZKMMrJKxXoMW2S4
346	346	{348,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv2aDHRAvhRXQu5cqVmVwomyZE3EUZFwG3NFYUrRLZzd5FHigX2
347	347	{349}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtbq8GSYGFhs5dn2RPsazqnTkePgZfChnFr8SA5xmjvm5QQmVZg
348	348	{350,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju8uyAxbkF5EBidLP484hC6HjD7vVdzsSmKqz1daDZGbzVdTfZe
349	349	{351}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juc1Fv2f2nDhdGEiWNT3rwrBuNxpmtVJcWWkyKn4FoWWwZ6bxxb
350	350	{352,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuqXnRPvsk3CWWdiAErcp8KwUSLGQE6yVrXX5vr6YYDrsTUuxAF
351	351	{353}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv7hQxjmELPtNcWsMrZM3D53ZWDtC4a9uw9pbjQL4Ld3VUerewP
352	352	{354,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtokK9hsWp1QReGqWuLgFAQQ9WtdYx8ZeL5kDNroYDbqVdPokYT
353	353	{355}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuWPdHFcb2ZCniZiS9WLePKY1U6AmZRGULRKxjatpKZMYJsJnRK
354	354	{356,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuHkdPg16tytXHcuarvTckLA3GA7n1YtnWoVyDG23YMS6kqUpVH
355	355	{357}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JurBNMTnf95uGhPY8iCZUcoAMVGRWLxBkGUCo3NnHnnueepHK9f
356	356	{358,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuQYh7gHhekJWJKtoBzTccgnQS2XC3KhvzLA1YP8DzeNBfEaGrK
357	357	{359}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv6Wgz7PsMrPn61r2u8Y9yj1pLVroTuQe2pDeoP7a7EibxGZLyi
310	310	{312,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JufBygpqxGDDS8VfbkrKDwYgrHjWSnTE7RXDPRFuv3Kme2QWs4a
311	311	{313}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtjuFUU5Ga3HZbidugJLYAxMaBAJqqP3zcTg1M8Sw9Z8MaLUKn5
312	312	{314,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuE9757YeZAk9megLAa1sLMapxz9oLRVMJHHyei3DwLLLTkA1da
313	313	{315}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvKCioGG3jMdymPFdyC7P3inGTgURce3EBQ4t1K1MHmaZgChEPz
314	314	{316,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvAL36iXRbKE75i1t8DgMsEQYhKXpukdkmJV5qJgvShow1kkNU7
315	315	{317}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuKT1h6khvRPDxFL8scTaUuughbBfAnVApVQv8xCzRMLVp91yy9
316	316	{318,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JujYPbqdWssbfSw8GUW5iBjwVM6ragFcro46bph2QRsBvBb7dz7
317	317	{319}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv7TTfyZuEa596Jy5CwG6jiyRS6gvQm4DFNpXYrsJ9i3tZ6qj7t
318	318	{320,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuMBG6y5uuLvrDnXpw7PVCwbHfGfNWJqw5164vyf2Kg7V1AzrJs
319	319	{321}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtr6ZkBmqJLQsdHgW8k8P7r3kTmaVr68WCoKuR3ZEBvxC4fYj3U
320	320	{322,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtWs1a6FEi3TfiqXYCyuB4pymCjJCFqiRcfUJjijTKmmH1MKN9P
321	321	{323}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtntKqH1xjGYMGCXggUFfCGmCJLA2i3BheugHXZ8sHdoa5R5NVF
322	322	{324,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuYGxhKoGigd9SKGFeLhPZKYXngKGg39gomdNvbheXKjQc15ndr
323	323	{325}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtWGdDYuVSHzXNxnvwfUW3H4teN7WVvKJnhBRQyHCpzFmXaKYL4
324	324	{326,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jui68fpoQDjJfUAoSkK67Q17nvBL74M9wVA69qXfULGo1xSNEC9
325	325	{327}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JudnAwxtoZiVDUGZ1nfvF4LdCoCF2gz6RnVeRX4Bb1XGU72Sawx
326	326	{328,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtjCjU2gJKcUVwFXVdRtF1R6JbUBpvssQJBJyMfp4ychWfCVHre
327	327	{329}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtcAwFeJhyMre2QaTePxcgSGwaNVkaUMYFairEZuS1ohnGnJjrw
328	328	{330,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JttVqyEhzBrvMwjvA9voVgRxFD8am6ZX65RuJuRygCHehB4RwaE
329	329	{331}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvQV34bHfWLjSuYWQ5zr62tYmTyjsGdDQbEWD5fLhPcoAmN8tSv
330	330	{332,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuhHyTwYqRk1thRiHKoqqxzRFyG9LpjQj9G9y7ZkhyuUAwgTMNW
331	331	{333}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtWXjm6hFh1CFL8p4CBpJPKAFXNDgDWaSy9JERZgz73L7vshZex
332	332	{334,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv5sW4qfRM8NYMAbLbioBwKyECYgVsMGBhBCXgqd1D9idBDxHfa
333	333	{335}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JusB9BH64uKuCKpcSabFYytmFQivoVsmTQPRCuPacBP2ieN3Vut
358	358	{360,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvEsF6igJKURStUi7TREmNLiJ2Qjhe44xHZBGLNhd1j7mvSxNuT
359	359	{361}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtjEMN4cBA1j12KknkBkKu3RQCP3jGpvRaBvASdESco7Uzuuj1G
360	360	{362,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JueDAqrdMYwSXeZPnjmPSU1gUpADZUUrxcFddzqhib3MxxrsLG7
361	361	{363}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtpgWZgM2gDT2hQfaaUoUGWwRz9dduosr6FPCCyrDRcCWZDh9Rm
362	362	{364,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtrjVeKA8sqwvucB3UVMPPWTf1pPe8n63otPutcddq4i3kwsm2T
363	363	{365}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvL3Eo4Hxi4822KyJrAVwU9hgkFBE6Zi9xL92dg3aq9cWd1TFdW
364	364	{366,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtwTUK1DzpCBt2NgRrrgCzmVn1eeVuBEUdEuUfWVN6EqoVAxCcF
365	365	{367}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtXGyh7aVu1uvupybo93zVdPENJYFPxEMAhMmH5ZuACAGwVHDPS
366	366	{368,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju5NdL4pnxQ24mW1sH2KFM3eenAeDfgmDWLidLdcBBLod13KjfK
367	367	{369}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtymB8Ui7ryi4M2s3xFexg5gAdbkJqsWqUWhQn8eZjJWp62HwkJ
368	368	{370,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuHfbS5eJ4ZM25pBvsee7kr9C2R4qmYFTamcdCVtAL4GKopM6g2
369	369	{371}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuxqtH25t6J6nzFZ1vyaJHiceqhotQMbtqMPRBUg6SXP2BSpBgQ
370	370	{372,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtxAS6U9ddBFX1kSB9kwBSixXyRBXQKGugaNDMrF2QZUFLrb7we
371	371	{373}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtrxfzi7Y3jd9hC5Pk9NQvmAcTwUS5vcD8F6RCLfD2DENRrDFGi
372	372	{374,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtzGkoi5Z6PMiH7zoUD8p3xLSgssvwbNx8vMATP7hJLwnVC3sTe
373	373	{375}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuyoGWnMXja75Srf1y7M1srzQxTWvmwsV4jdddiVgY92DaJy9Am
374	374	{376,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jub5j6VmbYq8eT8RAhPPQFYkZ1bei7cWJ4zbvpVN8PzAgXAntG9
375	375	{377}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juzhr1inqFBHUQwQVGnqbz8cLXUue4Thi1u3qsZNzFiofi6oAcY
376	376	{378,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuiGZPchXLndeiJVPXbPkQNvTJWLtygyjC8mjK4NnLvNkCxZaY8
377	377	{379}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JurS4uhin3M3eLCUsNPFyLuN7obhdpc4xVhDSJaqamvoNufQ7LS
378	378	{380,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuEiMN5jkFZM6AzDvWxBeRBmJKmn6oGZmepzTFsykJ72CRKDmsM
379	379	{381}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv4jxGqJM6jwbUY7epSDH6wHgFC3rMkFaL7BgpfN5UJmwPoetQW
380	380	{382,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvFSjfZLV7uPM3zmEQK3veiXB3fa9bvcooQ2ZmtFwmJVkfGHEmD
381	381	{383}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvMdmVobM1AcYVce6TDRPz6EoYwWeuEzGtq4V8HJymjKKK8vKyo
382	382	{384,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvR7pvEgjwr4wnQ4333cmUqZ6vKoJbgdGKmzGgbRKCXA7VLcc5d
383	383	{385}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuPVBXvSPX82K7kkdg9Bd2J8SySnwjbDdZUUuR546GbaxTq9PsX
384	384	{386,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juf8nhwyDX2rK8sZuEbHMUaT8Eb7sDwtWVV8FryTrLohXh1C83R
385	385	{387}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jufv5SEY97yLVzprTqroLSUseuZkbemecZADV8GzmsQkf2a9Z4x
430	430	{432,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv9Wma9JvAWznQdyY8rHbBZWopVc5ueVcBM9YaGZ52w3iaWEDHs
431	431	{433}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv5d6MsECjkTZcA7YH7rvdSV8Lmpy4LQxxn76jouckSfZACQ28s
432	432	{434,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuJC28vWr9RXA3KrDNSceA36doqRerRA2jgaZuTkkE5r2bC7ato
433	433	{435}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuGpYjfG9dLF4X3RVtoL5BPef1DPua1VUccubz86LGbtzrVNnKn
434	434	{436,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JujRBYjtK5kvZYrseCHpYRdvY1zP3VT5tM51uJbz5U6shwFpoRe
435	435	{437}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv3s2f3GCgjRhajBaQqyiwxRQbJqNHWqB4iA9W2LNwskWm7C1T5
436	436	{438,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju6Ef3qPnzcxn8BgAq9ghocYcxqDQzDq1SoduDvchTzPQMz3c3B
437	437	{439}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtkDtb9uhPP1rKXWgFoXnJzyY6wdLTjhEtufNYQr2zXVsv4bEsX
438	438	{440,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jue2PXmNe1C677pjVb8EE862L3gy8vUZYfQKzKiUhLYpQ7wZU5A
386	386	{388,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuL9WPtpHENrp4N9PHdahjUs9vhc5HcVk5o4y6DtXeeaKXzSUxt
387	387	{389}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv3nTvRgyMBPtGnTHpLUevXUmEAAQDxX49bhUC2qyHHJPCBo3yT
388	388	{390,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv8S4j3ytZFkgAhRzXheh57Zmi8EZYiJP1fcjxbFTxmJ3t3kW9T
389	389	{391}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuPC6D4MeM32KhUXADeBehfk2es5BbFNuUPFWRWbZY1VDYpFnKJ
390	390	{392,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju8g11nAGaEh7ir6RxZCAumWXLsoUgtumQPt59HdTX2vUnAXJ2w
391	391	{393}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvJTr2DWZfJsDbWtHW27AJ89Bd4hnNg7a44dDiwi4hqdRmNPDYz
392	392	{394,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuHcYTSLS91Dv8j97UeFquFDQ87u1uyxPAKLGSHqRHUd1FXXZP9
393	393	{395}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuEyzm5HN3hUHT6hS6WASXtcBkMH97iyh8pTDwcjYt8CjNobT5k
394	394	{396,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jus8osWYVxxNy44JUNhHQEb3XPfVVV1mFbwFVdTBdr5GdkWJrN5
395	395	{397}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuhRyUtiZMnAExUGCmAkoTXh454zXGxYcCBuA3ms6UwuKVVnDCK
396	396	{398,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JteQiSuAtVDRVuVycQGqisjb2pb8CVw2zz5Hytcus6N26tqpjhi
397	397	{399}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JukSXsSDrqY2TRsp97ajZocYnfcA1UtjPFGqXmXd71ouZVD1Fzk
398	398	{400,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JthPC57CsDEj8PvJyvzwGKx9UpPEqqRE3VhuEzmxHcCQuBUEbrD
399	399	{401}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JufAXARyocKxaF6r9gioE3ykuyCwbx167azWHwBC5PcFLYN1R7i
400	400	{402,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtqKTUToKdCobn65EmtWP5d4vWfkP5qU4TqD1kfb5ypkVptLqZF
401	401	{403}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvBKjavsBWLXJT5LUgo5Ea7mURP6sgkGkjxe8yLGqf7MyQQw4gz
402	402	{404,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juu3MmBuePXjdNzPViaQkoKPzFwVCDhgNZqRqC3rR8fjNNfvTPc
403	403	{405}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju9iNpvJ8ny1t9kwEgUekNFhShwJq89M25YUj58VsE84gGiaLjA
404	404	{406,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvHy3ETswBftRe4q6htvK2r83pWt3GrJeSBmDEGHoeB55qf4MGb
405	405	{407}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtqQb4ZKnd6SnGHUTonzNnxDR3aXD2Bgy2YsGypXx2ZdeYmecHc
406	406	{408,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvFtCu3vX6ugiFLYdWTA72sQvtUB811LeK5iskixHSYTnzmesM8
407	407	{409}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuvNAw4nNp1ckn1a4UGBHMD9ybdKTLmtpp2A4FEJK8379GjeS2t
408	408	{410,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvEn96xYHCiyQxZvmx541T4Lo6bASUqgkgdyQpfBVUq2JQuxchu
409	409	{411}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju92n6k6ydEfWWX1jVk4C7hfYyAXYiUHcchNq6X3v8W7rzrseB8
410	410	{412,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtuf9zYVyqzNQ73hJTh8G9TKTn7j3aiVgV3mEuxiC49zZ6WwJBL
411	411	{413}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju45et6eSfdaBTVmFBjAk3vZ8moNb4zf7v6cpt4EwNB6gaorcY7
412	412	{414,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JukMvY8jSdSunU7No5UExKCntAHPVy72xzdrwHoT5gXnWrf3ikE
413	413	{415}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuB19SJx9c9boE3sqbidJShmfbdTc9sBBYyiyGU98HDrRSmyMqk
414	414	{416,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Judz9KY9yb2S8mxZ6QzQcCrwR6ZK2XmWaVLz5uGivZLsXJ8XLLg
415	415	{417}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuknQbXx8ZgSj3H3kNWUuaiFQCgNzvstvudHVaYHS7GEwjekxaV
416	416	{418,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JunUTqzT7FWpKZnHvK3LnohZSZvBQggUZH8HtAV18PN7LjG4f3b
417	417	{419}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju22y3Yrm24KpfVG6CVqbjiyXXFqBP2nmxA71rgLeYXRUbR8vKH
418	418	{420,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuFEK19XLzmHDkZdwPfYXCQJHwJxs7QXnJMpk2XsYsdDeFuS2WT
419	419	{421}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuZ3proi2qrWrssKEW5sfcsnWhdfzdaZyWkha8CiRWxG1Tg2HrM
420	420	{422,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JutmKfuqCLvShXHW31pUSP6k11RHMpxyRN5bLRtRV1mfZ6BSfUW
421	421	{423}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtcT6ARLcQTyzt1AYhDK4MVos2E6v8PvbV1odFR1gTeszvYKCfk
422	422	{424,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtzk18ip5eR4nJa3vwYdWVsv3n4VqJsHGiVhMXmvKQvBzb2exRN
423	423	{425}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvAvT7zZvhgrsMSMRtuGpP1aUt4PbsHQNhievJo26SG9EZrGSsW
424	424	{426,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv6LaJeboAnSBrkw5q62xDQHZ3Ubfq5LedpLf5PebM51r9ZDgN6
425	425	{427}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtWtt8mydCJQLsw5W7uREDsNSERXwoNdWjjgjeu2RZWqvfinnTt
426	426	{428,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju9kfXGRTU66zGcxycmcW52x25nYWyRoCpn5mZ9NSEEgLXeN4K4
427	427	{429}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuWQvAyXsBkEpYeYo3sWdBjxXFR4aAnMkhtp1i5sUyy4X1QoGVz
428	428	{430,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvFR9UhLquLAKFvKLxey8Bf3kWjPLEPTg8U4qvxhCqigBFxyAxF
429	429	{431}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtw8FXjppHkLM5jEAAPequDnoWWSaunafPsjFzaNW4QPw9Ab3Ma
439	439	{441}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtvjn34SMYTRKgRYpVBA5iNkHq8z7oj18oJjPKCDZq42iRQHkHD
440	440	{442,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JthGxeSGi12ExnKVmJd7w9zKF4axArrXRP1uL1xCzkmYEmU84go
441	441	{443}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju1aJVBvcpeFnnBVmY1Ss1D1SXTvZLYF7RcCXiXkadGgJ8bh4cM
442	442	{444,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuipysVyJ9sfFTRCJ2GfwdCAwPzRtJe4uZNQx2ddy73bw3AcxYd
443	443	{445}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juh45SwWX2twjRt5wt2awB5uvoRdhbDqeaMUEp8TKLXKVEWRqpV
444	444	{446,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuveBwBQ92a9gxjaEWc5VBM8G5C2Ub8ZnzpcAjiwCzrC58cdZNo
445	445	{447}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvP6PoPCsH9a3yMkMymgyhY7zUJzt79YWTsK2Qm3dRXkLPA5NSn
446	446	{448,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju2Z8ppDraUK7sa92cb63PgFQyXn5mf1bbANxYGGVdsfDSgt67n
447	447	{449}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jun7dkV4iDMzood7z13ewib6WHaVLGEBrYqKUtM5rHhmz6nUQiN
448	448	{450,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtZHjixeafQ9Qg1JFVhzSVvszwdtEdw2xQo5DHcmeMDGySQbJ8B
449	449	{451}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv1gubMhQKpscd9XUybbFsifhUyVPCAo3Bs9JeqviLCu3aqJj7o
450	450	{452,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvCebkS1n4GDYRoFW3w1c7Jyr8r3exrfBXsGjHqvKH39VZK5N4y
451	451	{453}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuerBCMuqBvsvbtyPPZU2bPLWN7o9aDUDxmR7XAoqZ1ZMNh9t4T
452	452	{454,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvKFXvHSKW3gcTwL1EhU4eFF5BYuTukWxKTZxogBqjJ2qj6BEzK
453	453	{455}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvHQEnecL5UvDF8XVxJPBzV8qcvgpA5UBczB7GyrpF7JxPz56b8
454	454	{456,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuUUeSgRzHYMuZfi7dgF1fR7F3birVyrGwi8fqLoo93Ebvads3t
455	455	{457}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtpVViQp9irtLZSCYtxV32umfun7tsmV6WnRxSGRgxHVP6Zv5QQ
456	456	{458,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju1tSsDvasQqefFX6fzcCMSgtSkgMvD8FhpwDMSiv6Cymcg3M1C
457	457	{459}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuW63p4HFDRRTsUYHHe3VybnqeX8etXkfoLCYezkiS8XN1UNebp
458	458	{460,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvE3qMmb7b5BCzTDjpXdcebF68FWCXXutddo7srcrAvTa1pPmPg
459	459	{461}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuXrFYzJxZfntEx7uPssEyjDFiYnorCpcGKkMnAp7seuEF7PL8u
460	460	{462,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv1AA8TYacxptAGQFELcw5wEXQ5Hd4F2uaSUdM37Harw4PafmqN
461	461	{463}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JurRbgLXbWnpqGCiXHmTaJV2AMVDhiJii6zVnG2oLWNhWqCpomG
462	462	{464,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuWdoxnFi7eCyF5nQqV6jmR4Ls2G3npzu7JEFFey6wNZ9frh5Gr
463	463	{465}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju7tzihMU775WkBVceszWgve8McRRhLGMrP2zLQpJBH6o1veA4S
464	464	{466,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju1Unbz5fshFuiY3zrGxsww2FFikBs8HwRdP5KjLztDsPKHt1RS
465	465	{467}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtyNn8eHNRBsVeWRfWHfqQrqfxTJqgeLeUuDiHZYMJU4axy95sx
466	466	{468,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtxAFMc7ScLC8qhVTJ4pA4CRiHNU1uTTxGdxMPynUpjiSYKezTB
467	467	{469}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juj6YPs1z1j1xE1BCAzTANF9RMQGQZE6ndupymBrUjJSWydH13y
468	468	{470,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv9gveHPdgbS4ULosBvrmkoNrjXFG7LEzQ4tySjbNZjVxLwjvCS
469	469	{471}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuSTpm9jfUEB7wdY87aRns1LifEJaALaXAPe3184YkHiCNWCpwd
470	470	{472,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtskAvSxm5Xzt99JirzvBV72FZMJRuYPmppdG8rYCMJZhxR3UD9
471	471	{473}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtY1jF8LtLeq8EYUnDeYWcGj1pQX2Nh4gu6rmKNzZP3zcfrPD6A
472	472	{474,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv4ekPeYPZvJ5pHzcNQjb7KTAKMZXxD29jgovy7vxdaHK4pE3EJ
473	473	{475}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvHzZcFSV2AzNYgkNntKVYxFi1QC9EArSkpCdFv2b3NxeeMbSmh
474	474	{476,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtaupxLHKmH3WvQbM3ef9ruQ1NAE9u3gjvA9JjQKJwch1eY4EzT
475	475	{477}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtdRB1CNQmjPFJZyK4CvDBpsvPRLLpQJ8ZFmJ9bZfke9KsrJFs8
476	476	{478,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv3xJzybLvo5vhNqBxpkAfw2jroauVHtGjGoqgCkEZXp1p2cqQ1
477	477	{479}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv27oqCkaHXsCHmLkRqhvrUFh3mHWzwmY6M6Kn1bFEc2PjsQyWA
478	478	{480,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtoELj7fBsyFgiDVDZccmRGedcSf6ztwQG4nNHWnHMiWSbG3qeY
479	479	{481}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv4vFfXhxYzjaTbzQJ9HKq53zYnCcRw5FanRra5KexYUi66rJtu
480	480	{482,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvEcnWuZNZBgynTxc81QKKcsDdAFegD8p3t2umpJXka9ADi26Jf
481	481	{483}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juzbru4avoPEEbEqNaXPbAtKJL9QLCCWBL97VcRd6FwXS2tboJK
482	482	{484,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuXG3iUYnJtS9MA1UWbYv8e3jy4otHaLBje8pGdHYBWUcpYGMwZ
483	483	{485}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtwfLKY4kcX3vVxQLX2QPFSiAG1NGViL1Lo5ZM718UevD2xo9PX
484	484	{486,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv9ZCtS3hh8ev8WyUEdt7YoX1rrZZ1aGnq6PoQyQXyVbuv192EE
485	485	{487}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv629iqbDfzYMakBhYfRfwNPHjj5TcwiFhfVKyUEgNgXn7hXug4
486	486	{488,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv5CbQ7yX4BLKpiuPcNcFnmMvgyiDLjHaYoZeLtKzpf2kK5yic5
487	487	{489}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JubbztUQJi1KfVsBhE3Y9Y3EDDbXTpwMEjDFxmm6tGivFqGoZ8M
488	488	{490,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtoeaLdTLxqXjZcfQ8MFkCYCjouzuPURXihg4ZZLUUEiKRj2pYk
489	489	{491}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuUmsyHHGB83V1YNMPbxpyWa2Qgk8j5FsU3bEoPEFEeR4UdXw2v
490	490	{492,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtrTFyGgreVKzGpvmutT2wjxg2YSGoBLyhV35dmE1WHU2arDoLG
491	491	{493}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvGy1FiWT4h9disiWaDYUMjBmZqRYwzPX8G8s8nGSQRwHKeRpwq
492	492	{494,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juu8oPsoAgMTbRfNe8iASbUyZW1cFooGvxDAQbECswFtpfcaWVA
493	493	{495}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv2m6Zvm8wvvoHRSojkD7m5ZbRcM2Go4ibqtSqqnuqaHc1vGUGz
494	494	{496,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtfwJxMArCzBzLAJRb9X7See2rxfeYbziqxo7nawNe3nt6kwCqb
495	495	{497}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtVXnBQZXJXtWdc9XCm1SuJCejHQ3xzdtYTHUUHZu7mVLQ31eFU
496	496	{498,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv1BDr1unmwHdaeJQb5WduwVjhAJSfUoNn4YqN8zzBucY1XN4H9
497	497	{499}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvPmbgKRaqQVKrd2Sg5W9fCZENpgDC2miD4HFKukgtwmG17bijQ
498	498	{500,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuLDXet8zYie7xkG5K67PvozGmKfuZTHoPNiF5A9raUkghNCjhW
500	500	{502,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuYMHeyz8poJ6o8ATPSma1XNNRcEdnoekZ92GGMNGNQieFZf9S2
501	501	{503}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JttsZ18c4xnM6HdfW8AK9jUFPTXqZ2ihx2KsP6ThdmsnkZRWs9b
502	502	{504,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JucGgMjBkkFcgkJBxBDUHT1toCDhGLFzd99WA2t1U9EhvFmVTCY
503	503	{505}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtqw8ThVATgqMbqoBodsNu5txzjz9zw71rP5DfREwJgkhQ3yxEy
504	504	{506,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jujjg1kkQkhArSjbqvzaz1ZiNdW71vgrEPQY49QaELDFAS4gbes
505	505	{507}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuvPzMVWW55QGonW8NJ3xLJxX8vcjPu2SreravcptAey3hfrG2z
506	506	{508,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuLQUHfMgyNuMegi1csiwyuGahbZfgggYeAiaXb9uxHfh6h9y66
523	523	{525}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv9caSEjjPhgnTeH3uHHLEnM3Hj2kdkXFDkST6SB4NmC4kaytdG
527	527	{529}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuqZrdpKXQPqqefM8byXco6HJZ56JLN6jXjHgBsfsrkTVigSAUj
528	528	{530,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtk41JHrHGYctWj2jqHm9A4jcTQBuYoGpUGHnAjGoyhTinCULwS
529	529	{531}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtjrCS6AnLZk7PvPtSaVFqWdo72h96EpEwuxk2CtrQsYyALzrsU
530	530	{532,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuVEjXhTNcywpKSukFTyLPNq2wGosQcuhcURY8bBU2KxBhkBo9j
531	531	{533}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuyYs2qP4KyyGFFQiULY7nu3SpBpyLRGwKBtAPjBQiED7VkBcdV
532	532	{534,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvEo1NW3s5RPBcqLyRxNSZv8qGJz93b2rS677bs2ownBYzcwb2a
533	533	{535}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvPVimX3QkMXtWYNoZRZiZrXmd5j3C3fFScMF2RHJoQ49BVgYkQ
537	537	{539}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtzYEXKCi9SEjPnBBYk8yUBfmCC21UHLsq79Gfwy3oXkeV4LecS
538	538	{540,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jum1tYbyhh2tZC52F9Wvtv1N7REpaxWTssjzTvUdvAbg4YeXssu
539	539	{541}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtk5sD3yCEr6uefy8EmyZhhyWe67tcqEFZZZHQg3qh8WE5Xy9Dx
499	499	{501}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuC2EGBjJKUWc9FCWaeY2q4Ju6aeFexmoFZPxUiuMnBuPQ4iDTr
507	507	{509}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuGRJKm2FoEoxPEBy1urAChugXvSxTvpb8R9rR72rKKSGQ42mQ5
508	508	{510,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuD7iNCpxavP6X3LzH97yZH8Kw3Yz2nSDdRmqbinZBDXWqs58js
509	509	{511}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtjXfoeZqPPBt7xWmA7LSzvcm3BtQKHJxz5TJsB3JpNd2mNLCYE
510	510	{512,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtsDqC3ndD4MFqVxhDg5Lg51EXcYkjyjmH7CtHipd8QnCmBuU3N
511	511	{513}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju6ySque3JAybeVpkCVjm1EuxnW5GhnKqqmk82FncpqjcMKhGPa
512	512	{514,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv6RBfYVNN5MLZZc7khX6UNbppovjt2u2su4WJjA9nSu3q9Xd1Y
513	513	{515}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtw3YhJsLw9kBuz6UGDuJJNMkVG5WVdp17FCaLH6Fw8wn2kSnYp
514	514	{516,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv7YVWwb98WFBURwMc3bwDYhLUXbD1qPYhc79qmWzZaA3tUxaU4
515	515	{517}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv5zhzJmjDJc3NL1KXupUWD6TTk2LmJJHTAePCW8bRxUEfgnBmW
516	516	{518,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtwUba8GJ2vribm7oWDDkL2eYZ21ASBSEK54KEQt4kV65rgAhgU
517	517	{519}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtdEuFHnVeQNXnmWUBgSpFqQNsQpi1LYu5LKfpoWejLaierYJCM
518	518	{520,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juia4t3ZkVfoGd8eonR3VYDPCjjqmurpDkR7SPGL5pURFCxoEUj
519	519	{521}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv87bt6xYwUuaCEHsvWUhtCVCZ8RU22iss7TGgdf6XV5gEvnxVw
520	520	{522,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuwH9X7Bbh5E5eCfjExw1s1HhdxeMmpWcE9ANbwqcynLs6nJcQ6
521	521	{523}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtc3MP6pvjr8MVYYDyj6h8qxy2n6QvZsBdqVm3sU5xwFsEnvqzk
522	522	{524,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuYMAWJuKXhSDE6s7UoSoXzy8vWQpduRn5qP8Mi9ge62tEezHyB
524	524	{526,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtbqoNU1qAvLctdmnVA4v3KR2TnfywbxnEUpfMtnQctmWsav8Qg
525	525	{527}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju8nBvtbWFYJMgtSAdyrybuYvmY2TqHVzikCrHkCwy9Jvtd5REX
526	526	{528,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jth4AJxbQzEc8SvU6ZzzsvgRQRncpKaWWpghTYxHNFfxQEdUe6b
534	534	{536,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvBWfBwgUM2hp9h8d1gBAtu7gs9jYDzqY2DVfmVfs8YQ5WXMnaR
535	535	{537}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtk1daGMgkFPKZSZSucUPyaXorREphYLydeGdoGebA4gY5eTmw1
536	536	{538,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtpb9kZLX6UiWyiorGFhRscFqxXjAcieobRpqX1y2Bx3jRHNUXQ
540	540	{542,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvJMbs15P2aXWd3bW62gMZBpBQwZMygYeost2xfw37TXSHoWqAb
541	541	{543}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvCJDatcYvyvyth1y8sAR4VN7DYan9TN8SmrWk7PNe3kk5hJsQY
542	542	{544,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuLx6cgz92LHSZZh2PRuoZmjHQ4uunFoH9Ka3dXJrxqtJ7LUQbd
543	543	{545}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv8THLij9jFKUJdP1bpEPyHJKNogNmiEgEUWTK1okXaSng7Gn7a
544	544	{546,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtphCxnoTRLPuxBjBkadCWMHXwMRL9do8cTCD7aufWpQhqhznc1
545	545	{547}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvBskrzjbLWTrYZRbfrJ9oAysNdaFK1KUYUVXSRDSbmHHJtHr1W
546	546	{548,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuDFndfvt7ZuLiYzCeeGKZc83Q4VDSCQZAbeYt14nSfrqasWWmM
547	547	{549}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuXhpVCRFSmajzYhyRQaYRgkZXjPW2LAvKGFFdXAGTtnGfY3F1t
548	548	{550,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JujxTLgobw199dN9rkXkoix8GUGPHULx5ffP4QirEguKg3HfMok
549	549	{551}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvJV87t9Fk6X3aCVyZFiMo3SUDtopcbSaWz6g1BVkwJiDHGwQZJ
550	550	{552,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuGDCU59FKcGBQsPKSYd5yZXdLrrpYEmhTHKMag3q6UMR1wBhNP
551	551	{553}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuT5xM2aDgML4d5YcHXUgQxCfkZYgMqDn8jQ876Hgp2jurtCFRB
552	552	{554,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtdnhn5h2FPYnLkr728QBx6qGcGM4A7XUGDispvxRw9oFRCS8C9
553	553	{555}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtkgygarRMXkvsEQZQDemUMFJm9foVeMonsjhrzRr9MSd7PzCiT
554	554	{556,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtcE79nMDPjxDbnSLct8cqEepF9m1P7bXfQyAi8mwN3LMesmPzf
555	555	{557}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jto4G5v63hw7c4Vk8DuzGUb32RVY18Spo7fi7xzRGqrXf8Shyub
556	556	{558,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuecsR57fw724qQShvXieK5q11yZreXaTUq9gugoCecw9iX2iSW
557	557	{559}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuetUxeEgb36T9kcXQ1D286robS744kyPdFPUJRmNcGKxfyUc1c
558	558	{560,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvNLsbWrDd3XDrhEeqKqkJJBhKfAaaZSqrDnT58Pk4xnSsqP2NT
559	559	{561}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuJtQJbgeVPKmQqxn2PXPgq7NiurtGTzynCKBcuBBN1AuccQwmH
560	560	{562,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv3LRML3Dy6h6N7Fboc7GYatYMPhmWScwJnMYJ1AgCwqsYKnW6M
561	561	{563}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jta9XpHTF6F3QjdJCyKHYmjg2r3ykd5SheKPfX49AdfLvCFijjH
562	562	{564,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuzdWvozx914kTWFMYjb6i4MbSSssA1f8YvwnAcvTL6vf7RDz3E
563	563	{565}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtfk2UAg5pXFqUPhHC74mvnbyoVdEYoG8rXuBYSZnyM9BQpKUbE
564	564	{566,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtpzzNPykoiYgGqfXnquV96MzoxeEvjnKY5myKQzRKjb1vin2qS
565	565	{567}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtVZFS3QacTb1iYhMWdrYwGJGqmnNPh3wVRXLSFyvC6yF3MMENS
566	566	{568,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju9qm9QWXeNa3nrqtRbzViZ1NfmH31ZhahowKuBS3NJW1GM64rn
567	567	{569}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jut8f2nD5HmrUu8ddWp5b3homfuJYS74rPiFhBw3HEMgrLX7q2c
568	568	{570,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvKQeNjVRcFDuqbpeGj8Da3J7CCnmSpDZGD2qj2NGcnG4ghCHM3
569	569	{571}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuEbGDLFyuSJHY7LNsw1keF6MDNY9N5nmCFeyDgdoLmb5Kf9XYw
570	570	{572,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtopXKSgPEcpQv68e2dQq7vYpYumqAvj5AHLxP1wXNpVFt7Vif4
571	571	{573}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv2hRguPY5DNTE2YrrDBARAJJeU68R7uder7W3rXHaPTvpXRRHK
572	572	{574,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvDxSqyqja5Du46thXEgmT9ivda23LxfmZg8S1SzXmHwnQNSuvF
573	573	{575}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtuCci22Cg9LrAMnNVfCD5BiNekVrLjt8FBPrXeSRRMyAJYWNgS
574	574	{576,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JukPHrEcHpq3EdUh468813U2125EG58i9KV2CLbLBvjSezXgojg
575	575	{577}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JthTeJbvPPUgw91bxLUsEmqfJubo8wnxkMZbGgfKLtcJjmUzBTh
576	576	{578,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvLknVfdAvbWgHGvvYtKRX9ujZcSuDiimv3r4Brnh3Hd6q4bwq7
577	577	{579}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju9ydsdagA7M6g3vJo5gVHgaS1aHWuzXpWjZEwVzZU6TZrCv4rv
578	578	{580,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuVTDDE327JLgk9VTdM8EBURBekhiSXzfh8SSjQLkToAHHe8pHV
579	579	{581}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju4TT78Faib664J3gKfTo4cZvibDoU1xSJZKCbcNXV6EGhKtwqU
580	580	{582,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtimx748TLMmsq8brQ2T1BxnudC5UjUZfTWj29YubUjMRTCz9uT
581	581	{583}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvKKfF2BW9DRoMgHKPqVKnzs8tZKU9Z71ZpX3oJ3BPHJHJXPPhK
582	582	{584,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju4oMfQFimFvoDELck4Q791q9eL12Nytfqq1YbTwH7JszuUBYCe
583	583	{585}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv4Fsvx34kzsmZ2zc3KbzkS3jBCkh5CkvoDbdkRCmzNcrVD5CVp
584	584	{586,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuzjyeA8nFDmTNZu9uZFLEQTULsxKzQ7J4Q7FfL8VUS6uf5JmtT
585	585	{587}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju4FfzHgoJ3yVeL2bHCMhAWGyUTtZbQnwrBZhD7gPjhe9GAyuqa
586	586	{588,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju7By5DRRR8iRZz9HBvGeBvK99BD1aYbboxbjyyUL3XhmDkc4P5
587	587	{589}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuDS74eMTowKYJ8Up8gocc21sp3PJFWuHR1PHYsiQmaHrPWqrZz
588	588	{590,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JteWR3YoPxAq8Gdtjryd6zJXsS3RTPqb4qm4UBXXGteE1Js8XR4
589	589	{591}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju47BL1ECsFmybQUdHF3vX73XgWwJ5qJ9LUYypoXd1AJ7PCxxDe
590	590	{592,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JubinzcU4dbon88DgJdbmTNVSicsC6XCjmxNZHQrAn3EAUxunpb
591	591	{593}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuWpmYSDvRV6G5mbMSVH8QpaktgpLjT98k5x451NjV3CAjVFjAp
592	592	{594,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuRy1iubQF7WxRjgaVjiS8JtLY2sGuiJc6r8xU96nXxQgzXFtGW
593	593	{595}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtp8D5fPLqvRddsBqWLHyYM5nMcPi5Eya2oK4CbX12GyK5y6ksK
594	594	{596,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvP65ye37g4itQKEe6C1dYZ3uMhbN9nVfdbxrmcdbLXNwtJ6Kbu
595	595	{597}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtapbbWP1pVCkcHUEcdX1x4pXGVAWgzZvcGKFiP3cmR6D3SiXGT
596	596	{598,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juo6NGDEwDgrmafsZ9kfLTAovwnmf93RTY4UctZffXga7eks9Gg
597	597	{599}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juoq1zaXzTeEy3sit1xLTJFMXnGeB7YSBkXwShuyJUFKFkKYMjv
598	598	{600,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvDoMA9SBdapg2f3UcmDa5ZCBTiQMUfCfxNhUxfrdSfqjmzpJo4
599	599	{601}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtiz5kiJ4TDoyo5NiPqZAfztvNyaLsGLeizjvnasaUjEasBp97Z
600	600	{602,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtchHCTbCoKL78DJqjYuP2yB5HZ7F8oUaxJaDtYZUZzw4hchu46
601	601	{603}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JthchzjzNZQ38hsx5NcyoidLEJEs972ETyUTsQ8KQeTqDzNcQNG
602	602	{604,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuH63sdi7xLhENwVsLvW5yKKjA4rJHeim7ZqsfXXh6YchpkppWi
603	603	{605}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JujrFeJE8csUQ5M4ZuKdv5y4N6ovLJGacxxyeoUPwvnbATpYsGC
604	604	{606,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtXRuGk7jGmZTKHZv963ucCRWWw4ADsh256EaGxYcsXtXXMBn2w
605	605	{607}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju1YtyCPqEqkCUhEAYQVAYrvfv1k3cxJET95epDr9UogSDXyYaX
606	606	{608,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtdxc5vptS8ZHiULBJb3KxNcynAwprHZmssUonF3E75NyPM7dCD
607	607	{609}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuTfPbyhEk8C3oxLFvjxWBuC3XNW4tBeDNNohRP4HbgATqByAmp
608	608	{610,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JthUMguAZ48h9RypYrqKxL3XWaR39sLxEoAsMa6dhW6hJfNQZNV
609	609	{611}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtkQ5a6aU1vMVL2QjdUEzjT3kbC527dnvJYEpX5aEESPMMkVaZD
610	610	{612,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jun2zxAroEN7yFPsYLdFqCj44UWrzeALc5ss1tvp8bRuwXhRn6T
611	611	{613}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvQ4na5FUry5sTohPoQPpQPWZ1Cx64qksdf781GRgUwZyoUkdzj
612	612	{614,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv1pPrEo9JrRKMTf6k946v4jyKUYErpP6w5qqR3JqLUvmhdGnmb
615	615	{617}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtkwDEaNLBgo8sJsRwrRudCtLqbP8U9azkV4NErUHbJnsYPDy4u
616	616	{618,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JumTxtRoCgRCFo6UmyPXcKHKbQH1v9cbjBFpqE6GbpXJmM1Sb8M
617	617	{619}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtWigi57fBXVfVwEhHP2BxMhox8uSH9b7cXUt4PRFcd6CvmSaNZ
618	618	{620,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvGboyD4kKFZvVZVkCXKAEbNMkiAH1tHrKbErZ4RtKqzMTC2Y6B
619	619	{621}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuPD8Qnf8VGCp3VMDkgPn8tfcwWuNvQ6kaWymFZt842ArdzttNd
620	620	{622,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvDHuh8qQMakDMwRf8d3Q8VWg8Gv8sLF87DgxKuVZbWKfwZ38ZA
621	621	{623}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv7yqTFg3HSg8xDwsssGnMNf7MDbU2hmEu9y67zAZwUzgytwhS6
622	622	{624,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jte5SUQ5FfTiY5mLDGQDJYPHsjNecLJNUmxwrzLknyUFN9rTfej
623	623	{625}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtXMhDTSMjFWLGfsXWjnWP7FhLk9W5LVCtjkd65dU9c6wprdCt9
624	624	{626,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtcou2FfWKbJBm3VNaTm7v7AKr5a3nUqEmihyoeJNvpBVEsUpj5
625	625	{627}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju1AtQjVxvV4bkosXpDME1Vgw98V8H7NeZuFzy7ZekKSqoD2j5K
626	626	{628,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jur5SsX5Hx8UjB5vWABQFEM3jc4cfpu48igYiV65Prfo1JUNrBU
627	627	{629}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JubofJrMnj1buqFaHBd1ACRBY4bGMy8PJK1fuMq2MSdFZKESFhm
628	628	{630,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvRWbEATR5Cj3L1DkjECEAdtkz1TrJCj2brzko8MZXgvtFjKAF3
629	629	{631}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuNY9gXFV7nBdHNBNyLSvdgEpTBd8rKHCtE48kciSArTvqWfAyg
630	630	{632,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuDwX3TMJGzNqXqpZHgTaGCBxQ9nheZQvHBp4QK9crarxj6foVh
635	635	{637}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuNFyGcTQq1E46Rthi1usaLUTGvedT8ERSHcazqDfxYcF6gigWN
636	636	{638,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtaVgVSeB31jQHGZeoZ2UTL32PpmtLpknFzKg2abMLhCY1zAB2z
637	637	{639}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juoek5pg1azVjLapLjuERjQ3qrMV5PXwPmS9NN5F9C2o43Wntpq
638	638	{640,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtfe3QgDWM8HHzcVUGgTZfBVuf8Um6AicsqdBMdC8SRz5VAcJio
639	639	{641}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtuUYuRi3Hr7ikwkL2BStk85AdXpbPwGLkrYTPGSdFoHg52M7mh
640	640	{642,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtYhTJWStiYJftkWsixTbzWVNqsbDGsqGj46brSgDvgZcQgAmf3
641	641	{643}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juf57WMdytRuVx8PzyUvrYijoG1uwRSCRgx9dd6LisT6aNxDpga
642	642	{644,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuSP7k38NaGmJcNiSy63Bp58mfR4A24utWYobAT2BYpouSvKciA
643	643	{645}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuZsVvtbboMV1J74yeiXjJwVR8vsjrzvbQfyD5oqsH18d671ujm
644	644	{646,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju25Ec7M2yFjF2zJYEqGDcjku7uRbiL53k4XEkuAixSjcSG7Jxh
645	645	{647}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuJqEyC4zH4CUZXRCp4Yfc2P7GREyW14kV7Jww7zL7r5Xeiynq9
646	646	{648,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtoq6qZBD8nbHML31z5zJny2jcZg41yVA3kQqi9CRC7dV8CumVi
647	647	{649}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuM6YpMyjH8RpUXcnEdGmzfxFX8m4btVPC4WqzRqsPNpiH8i1B3
648	648	{650,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtWtphC5EDWrdwKPPb1tZdrAsTgCkvHJSES7PyDmPMLuxHZapXu
649	649	{651}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuSs8TFLwbMWr6jd7QpnsfTiHNa7LYK4zA2yhoz2vywFp9p1997
650	650	{652,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvD7tRiEWcZERGvfGxS9nJSZ13TUtLkhuRaaN6x6zctCmGVZkh3
651	651	{653}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jux9LqBK6ridsJnDE3BFBJ9VZ6ncPyrKVJ4MmaMNDbnhEZaLHtD
652	652	{654,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtmtVHorxsAyxH2UEsK6JGdMTN17oJq4yRXGTp1TkK1iWi22635
653	653	{655}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuTXg28K7ipdcYgr9YyJgaLwB5V9faehyvj6MwQmEEfgkzEo2BL
654	654	{656,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuXdanxby4SsdEaEX2KWZYxCu7r6TQhKZ9ufKDdZh2LVHoef1fN
655	655	{657}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JukpmPvhFBx1KybUphsPVUE35FDdPvTqGLXY79dApNQGWVriAtT
656	656	{658,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju5wZrk6FJCgV6Gv1WQpbGTMKXvJzRT4HNGCXPHCS2bYYjZg4pj
657	657	{659}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juw4zeiEpEsd1ndCPBxgTjHgi59QjTM9fYCo8cnfprdkVTo6WUh
658	658	{660,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuoQ1tXHS3V5K48KwbSME1bdbR3LEyfvAoQuRihykst3NbiLGZH
659	659	{661}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtcMKi3iQWdvBz5Dcy9LciHDHdhPMwkRZLLGbqS3yc7JyhnppV3
660	660	{662,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuNMiwPQCYmr35x8xbbKDG6mJbsmp3srquy8x1qbVba3NAKSNsq
661	661	{663}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju2s83FVB3Kuu3z6tqYthgQzqzcakHBAHxTdUsQ7AsZvdoxk4mk
613	613	{615}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv6asMhmLZafb2RAhYFkXcX8aKFRGmBjoM5rcA5FHy5FudAr7JN
614	614	{616,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtrKz7D5ucGnk67QMiNbb8T1kFJfabydevoj2G7UeFFaWmq6HoH
631	631	{633}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuovM7CnYbuV6V8iKfmwsB9tBmSzJPq3UxZYiKMYjpBKup55jZu
632	632	{634,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuUMML1T2SwCZfvLvyHTLmR4dkoBgwCrVuk5K4vNJAWPYrE5DNc
633	633	{635}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju7vNhF9PpM9XAadvoWxQ9TYeXck7VSHXNHt8ArzjFa5MoUoNC9
634	634	{636,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtYHzXtm8JmZNTxiWgu7fzBCrfQn3qSsLgd7rxjbkrAogKoYVhk
662	662	{664,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtxftPvig5JmAj7oLgkiV3FVNRFQE9daV6osoxpQkphAxCUASGD
663	663	{665}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuCoWEybAwMWgTJ4oakzis3ddjL2AZ6tVBv1H2jYfSFF6KoVG1i
664	664	{666,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JufWszX4ocBoJuCA8ymYSdfzy8MieM1AwNjz8TifBxnAZZ31TFx
665	665	{667}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv9C7x72JpZkrFSzEDzbwEmaeD4PRjDoBQbJGDNKFJkHTT1j1xn
666	666	{668,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju24PgTrRf8YRLtqBEnPdjnKmLnyHAe9vKScQbYBRq1V1boYswW
667	667	{669}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jufbm64RVtQR73WbpoYtmPnz1mEGdssfyFY3xdKY8Mbmtz2WxV7
668	668	{670,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvRxGMC3vB6aNAKaXuax9DTAsWdTjaeixWyHzeu1vqZBs2EJyzJ
669	669	{671}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuBQFD7NozdxGTJAhcqMQWB14iTFjHw3nmKNTpagVDELxfZfhXa
670	670	{672,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtfc4hDATXfaHMwm4KK9cJ2Q2Hy38KQt4RdUivWbecY17cTwXr7
671	671	{673}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv78BZ8ViUnKKJbemrHGvdSKnfXT6ZPQ9AfYoccGKuoWvrhuZC2
672	672	{674,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtpzKvvUxU12cgED2BX14w1aHg6txvbodSp2WxtNEnZdV11Uqiw
673	673	{675}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuExuzwCF3a9AiSZPQAhtfmh89eZwDGj7LMr9BNRTv2JJyA3EgU
674	674	{676,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuyYRrB4yLKhh2m1HqxsbcUxeEeSopPBaDn4retEpoKZGEezjaW
675	675	{677}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuwUWub7GiYY3ZpsuqibJxv8cECWohxLtZKT4dRjf27VhHJJyAg
676	676	{678,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JttVbJNUMLt1nnV1QEddFcaqjnZuhQQCZ28WPJ1hXp4vWBbZj7g
677	677	{679}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jupnx784atFxv63Tz8XEbbYaVkbsSujY2hP9saoKGurV3EYXco3
678	678	{680,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtpjCkBRVtsfbbrPUeNULQ1CEeVy1ZWhnYxL34NNFHSHk76BuWN
679	679	{681}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvJuRk9i5aG7QX3G9iN3V67fUvoinxHAcCfdVZ3mC3i931G2cHk
680	680	{682,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juhv38ghC37nzJw2xKmpsFqugPMECKdRmGFNiR8T1QXj3ZQBmn2
681	681	{683}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvLxkiHB4uQr7wAVPYULDSCqRHUX5WpcNXAsS3EshAgBfeybP7p
682	682	{684,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtZfKNKArUJkc1f4v1jcWi3S1PCuqtUa6HPgjCPaQXFfa8TNUGx
683	683	{685}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtuJoDdWfaNDVVcxtpUoR2WeYB4XTDuCtT7Jvfw1cEZViXXvsEv
684	684	{686,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvGjdabz6nq7rkajRbMQkuoYcdMgc61VzDGY5g3wu51wJGJs1Jm
685	685	{687}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtdBawLofP1oqBJq5iBaL8cPgxDdwajaZuuxcAPgEHLYpb9qoeQ
686	686	{688,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtr12j2uKk2qJcNg6yzZXKFG65zaESaJLD5qoj1G1xuQPydiH7M
687	687	{689}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtuw7JEBYtZ91F3rxJRg2gkkRNcMuSu3bgaz1pLJPNS5u9k6Nge
688	688	{690,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju7PKp6xzAvuLzaGA2YevPtC9hTX76qUjXny9Reogy6fPzV69iA
689	689	{691}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuXFhyg7UK9NkJgbqsK4ZjcxJVmy76y9Gsnd6Pr8DG5W6Vt9ZnS
690	690	{692,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuBKjX3m5EUoMbCpVACEwfg1Xy1NY7UNDzqBUwiPmxNqQvbSASB
691	691	{693}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtVYVRWFt7uLPwSHtYwraKE64WLmEQWSzzDR6WzSoHubbUZdW4Y
692	692	{694,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuyvF6jBcR5kJx11TFcwynbfqUJuWTWt5TjRjP5WWzaruqYogFM
693	693	{695}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuYihVAcKrYLfXLPE1NeENnJXbVkLiSRTEfTLvQDirXfXEYA8ym
694	694	{696,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju6HFUSt8JfTVE8WA9jLN1Mk8y8a1qV5Rkn3pYxtL65TJ96m9kp
695	695	{697}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JujBLHNK6vihUxW1mBQf1PhyXEN9CWM36k3pRcDqFxmdxxjgYTj
696	696	{698,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju5E7n5Z6SxqBjrtryi6vJDP8onuQEuiw5cnuNo9V335o6wfDwn
697	697	{699}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtYeVpXFJ3HGXbDb6KSWJubutFKZt8P4YqgX2qUQuPWAQdnENXw
698	698	{700,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju3B5P1gLJYiyRza69k51uutGJtfvabyWMLiXbqSxx4hGnSC77B
699	699	{701}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtiWngsdjsN4fwS297kgMRA4DFMTPCfrTXboYEasde419dBu7SR
700	700	{702,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju6BenWRRyhzQTKeiUpXb4sVnUGQ6c96f6XzpqXaqi9UrmkYJBD
701	701	{703}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuMuN1hP5xZ7zZeeZVZRf91mgC72TvJSa3ungmAEEvPGfb8ggZR
702	702	{704,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvJr3c5wjmRVLcEgQShPrSRfY7FUS6v5fRztSwchoqbq77sLjon
703	703	{705}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JudMogNFHNw3opRU9p8MSCH9SV6oFX5JvYk2ZyeYi7AAGBakiEq
704	704	{706,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju3vCMA1rEgpghm61YtSY93AwSzwfAGvW51YSSy2ECF527R66Y7
715	715	{717}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtbt528yWXDeScJasQUEGpXoGmSXRfjYD4cJAMLZFXrFj54faG8
716	716	{718,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtv4wLm6TpFwxQhGkjPpc63zKqeVg66KGJ5sSDNmTchDdYzAyzn
717	717	{719}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuJgafAaYW65VcUd8ZWU7WhoQniATWfAfesy1k1bevPfzs4LCxT
718	718	{720,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuQj4LktWysvac9qLAikrgFpeTTm2xYGDitoEfp9M7Zt8QK7wBp
719	719	{721}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtqoVotdR25jZM7LrAWuBS2ftAYJFuacd4DRtCEb4qvzDS31UJ4
720	720	{722,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju5Zv4RTj8FGzZrxouYNvTVeM2f7L55Q9Sx1JcBzHihR2iVsmgR
721	721	{723}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JttttBZJ4yvsAkLL95zE14nadZ5NC4gM2c4ZWXv81jheebmy1do
722	722	{724,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvCRn1YLSPK1w1TGC6f7qLCad5zpD2AuvZiNYdWMjq938LqQD44
723	723	{725}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvRf4hP4322q6USSksUQE2qhj8PvPnqMR7m9SDvd9roACGrU4zU
724	724	{726,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvPwDKc5LGkqcXc3ryztMvGrWpZvYURV7GREv9vWHaqxjBhBzGG
725	725	{727}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtoQhp2HK7kimdVVQUAmc5wUM21J2Twjd1sCsBi95UGJDMsereV
726	726	{728,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuA155x8ALGzYyDhjvbVeB74P3swJf9TEAYo8zPFM3JeLU8TFfc
727	727	{729}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuunWS2JUzbNWqX3mjk5SkqMfuFYkD7z5dgavfajY8mcQt9v75e
728	728	{730,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtm76k35hMwi2nPpkQp6Y5WxDJcJxydno6MqPwSFtfGb5s4bUq3
729	729	{731}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv2euifFvM9QUeCYY3rg2uHQkqQw3vQxMzeSbFjvdRWKfMcCpdB
730	730	{732,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JunA9WMCLbdRCdSdSmthe3qaLXDrw2tn4HPJyHjGg187rRw5NsU
731	731	{733}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuU4gG6QjgkENY7TBsjKazFSdgPurS7S1cUzdYyz5j7d5ESims1
732	732	{734,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuppSS47qB8qM17o3vrAQESJEAKnJww49kRGn5Zda5FiJvQZDGQ
733	733	{735}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvS51XbePjqK8Wj1m8kT3WNebbCDLjx9wNMqtopJMu6b41AH7Kt
734	734	{736,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtXQywReNsMrPt5keZN3BsrSpneW3iErM6o5MVGRnXdyRDupLD9
735	735	{737}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JugpD95bbCAAJ3HMagDf9fGhHRzQrP5ws64p8t3WryVFrQG3JPu
736	736	{738,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuzGV6ZThDNAHn8FoboXYg7Tf2M9NuTCCMMBfHRbTuXfPxQ8RQT
737	737	{739}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuYxTip6ap8oGQcqBUGfPxDUEGCzeZKLr8r43tNjJRJNzfi4pot
738	738	{740,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvNV1Qr3ftVZUTZk5LddvB8cuXiKdZHZpCmHWFHUnbLxvM7MHR5
739	739	{741}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuANxMiTWgxHUupuEXpMJsUeFS1GDXiBmwKWdXU5SHPCBH5yMgX
740	740	{742,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju4xoj4PqKZ64hNhciAhWYaFjYi6uorPQc5xBeHAg8NNqNgsyZr
741	741	{743}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju6Wydeo7UHEA44Jc66WcuZzv5DCRvGNQJeWdDbcVZvD9aDSAEH
742	742	{744,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JudgV2wCvnAgpvVWXjssVx5Pb8upkocVTV4g2z6xUCmgm1uj1LA
743	743	{745}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju5V13GibjqvBHRu5G7Ayk9WiGQgBv6JSxQZPDa4utNinpAMgrD
744	744	{746,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuzPtoELR7AZTkXF1obAAoycM2ZjiS23JxKjWwjJNt6kZ5RLPZ8
745	745	{747}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvAucBhakhqNQEmFRjbSmA2dK8EGQw2GG7LoMDxxRkpdy9W63Yr
746	746	{748,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuxneQrseZWR1NZT6ZufXFCwRcWgetvfmArtnL6RdEwAVpU9e7Q
752	752	{754,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuPJTcz6MyMdZk7XggECYhZ6cZaayWFn3TEo3F4kKsqTndperkV
753	753	{755}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juk9yqwaWV8U8ovsEHfGFr7KDvmxGcXNmz57SDwRmDbjy8hdqgK
765	765	{767}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtViYgw7EPkyveY2eKQ2jS1YJAVJqS1zNhhHBVj8yRSLetLanJE
766	766	{768,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JudLSJ2AqJ1nGiiw959q4coXn9jKkpmCqFvdYYdXyxerL43DW9M
767	767	{769}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtpn1pLdAS4ffjSCVCCwJCia3DvgPGG1RjNcjNr684gDczSziUA
768	768	{770,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuQH4umh7uByM1VYZvUNWuxAhY7SgKgqhoys6fQcDLS8qfrjof6
769	769	{771}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JthhJcEiXVFLAnZMVMi6cYKnApAfaPej177XRPJ869UjTsgxt74
770	770	{772,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuxuUvJD4ZumMYEv92ZcT929ERktczQsjrHwdnTh4cmPrtyQtuJ
771	771	{773}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtoRMC29Sv9XYGf3sKbYuYzJyU4VkkVcygrxtgqdcBwtiz2sabg
772	772	{774,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtk5GG1BynwnhC2RNNAu8dkaXgc57mhsUhds3TijCUihXcfBHiQ
773	773	{775}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtb2QXsmr1UjhSSuPpt77C8RQjiUHdvns7oqZrVgk8SSePzwk4z
774	774	{776,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuEe7Wfm8NWx4RFQ3sWfV7h7RYSgQLWEtwXCrwk6B7oDtUaxaNi
705	705	{707}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju1XS49Z3Sm1ZJ8Cav8RCMLbypUje56NR7amDwxw4GTf7TUzKSA
706	706	{708,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju1H79UsMGKeUDUdLCsJSTLZGnkaJpNf89jWh7r3nXR58YqX7v1
707	707	{709}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuPALAkocDLFDM5gXE8WwhC72kcY93q8YoviKSpC1eG8p8fV6qn
708	708	{710,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju2nTfWm7mfZqkwmmxDLRdYyEUXS5FAvFVwko9pzui84jvXfVJW
709	709	{711}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuK46CFDQ44g9tXqER9X8QuqC2pk9G3a7Ksvh4ufw3NWpUvCU2h
710	710	{712,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtthGPjWR1qCspkdLDCK5eJLga6doAdt7iqQfwHRxRDYoWTwJMp
711	711	{713}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvNx68aWm3Y2UXnpfFBMjsJ8BkSjW4w9raB3UzQdSUYDGR9qJzP
712	712	{714,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JufeQNKU58cV2yahjY5KAZr696pCyFssSycnMXTLsL911JE9Qm1
713	713	{715}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvG15zBzpEPZ6Er1ijknNmCdwwwGQcwpxigbALH53Mp3j6EyP8M
714	714	{716,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juq2rucLQz8QMucpsiCkJ1DqKubLULuPxqies7141DzuYqjGLFw
747	747	{749}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtYEMBpc6ShwUgmFDXCWiJWSrf1TYrUpanQbxfrJL8k9GZafoUd
748	748	{750,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtg1YuArKLwNTjBdcaBBd7onBC3tvFJQXJCfWfVojM3kEu6kNYn
749	749	{751}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju1puSYVuvNfyFDrKybxYhtM87aVyhKVTwKv83Na2NEvGoKzDPh
750	750	{752,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtvGsiB1jL81TvAbxyBSeRSS6qVSz3DaxZ4spKzUzEfyAcNqVKi
751	751	{753}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju9NNkPKe9obkNN6fu522AjgQAV9WSFhmwJgXhKAR4mhzy9QTNc
754	754	{756,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuBHXVtur1JvzaNcofQRkkQKq2a9iFWCqGiFCXvXs87MxReCpYr
755	755	{757}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuyS1DAXe2sJMbJaMe4CbVV2XWY3C7N5nh2wuhFHjQtgzB7bBV7
756	756	{758,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JupVrRW5cZwnFMafh65vj1SDXzH8CTrDxT5Yta7R1Gzem4TuruM
757	757	{759}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju9zB5bG5smPVwDaUkafop9R9vjNnv3tTcikjtV1SsobyCrEk6d
758	758	{760,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuK7dqmcU344zoMHBZaaHGtEnimfZo4vFBhp5YiPdWJHf4jgbCs
759	759	{761}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JucArhcFzZw76jYzxuuepNPoynGTvxK11uJMm5J3KApNStUNV7j
760	760	{762,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuhqHenbYZ45XSKWcqq4qHjwvNtB1V15j5V5kEYUFC7d46XpnDX
761	761	{763}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvAbHYn7FjRnT152bf9rAfPgTAXzSEy928hhVASyLrRCAcc9VsK
762	762	{764,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvPv5reCkiCQxWJoAAT3ALHgd1q6XuzZ8F1E4jKjWkHHVSqJsRA
763	763	{765}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuxbHeiYHGrBZG7Gm6y9yxT7EwHe5jPG8YBCuzXtRFACrBwSQra
764	764	{766,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtczUeuNG42AdHeNBs35fQopARyALLvgXp3hMfNGx4vQQcjmMg2
775	775	{777}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuaejCnvjXqYhHF8FHSaxSdF981E2Fd2kBdt8EeCY8abBTar93Q
776	776	{778,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtdtQkb2iy8SMZxENbUs9USKzX1gkoN4WNj7LtYAKa9D2VP84eF
777	777	{779}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvHMVjQxBWLUpvnjQPHVF3tqXALVB2FieZN5iCHdS83zEreSEqR
778	778	{780,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JubXNz6S7dYaY7xJzPuLjueoFYhhdTF5jm89nh2gGieBmh5xpRE
779	779	{781}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtXCjERT5bHtjdVS7VXYyvUnrYgYmD6NLLXh48KzGHP17JFU2hT
780	780	{782,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtkk3rwSNjoGp9zJ1GKWpTJew6jtVArQK1iQZGoG5mZNoxmEBbc
781	781	{783}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuBVfPv1PwjqFHuWXXX3E1nQboUiJyhtYsJwatFVzsqHj4nCQzf
782	782	{784,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvF5u8vSsymvYfg44C694MyESpTYkNKKj1vuFRMJTHWXEgq9Ub6
783	783	{785}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv823ExVNjVseYJArW7bdgeHSpGSdYWvegvEqx3BbsJPimNoTx2
784	784	{786,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuZ887etGq65wRNwgS2a5PxTtoHuDR5fS4riPkDHDjwucPvkinY
785	785	{787}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuQntdA4fToXrkuZSJ7TL1TwX3Xz4AMyw2SS2ZtYcp7gnXoUmcf
786	786	{788,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvPBfd7ZwdxBn1FbNvb8wRt1B14dqF2UFbYEFch6QyqProYdeq9
787	787	{789}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju9h1aHT7h5YfPP7fm29XctfsRNvSt8Q1Wydd6d4tMt7sthphKk
788	788	{790,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv5opjovBWWsC2DSp3hWQtHnLENGT3tTx177R4iKXdEyiVJEzse
789	789	{791}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvEaJt8qdQNDLuXdZNd78quS3vciz9hQAEqpZzSGjHyHYSK68MK
790	790	{792,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuaZjXRf4x8kNg8xCRx8A3hC6FZVYzJYu5t6peGhuDEUrG2s7YR
791	791	{793}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv3eGM6ovKD33iqBj4xXKHbAqsir8w6hDfwMUzJufYdKNPiyyjc
792	792	{794,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju42qzgB51F4mhy4DL7H1DKq1RcFGpx8jGJfJqGnZTbzJVqFxZE
793	793	{795}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtdqn4fc4Atm8HMr4zJSgq938ahYskmkTvJp7avLCqdDiKnvwy4
794	794	{796,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuYQXDLx22b5VBevhFriZLWSNRQe877JUTzhERRWToWsQvCHmcZ
795	795	{797}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jubsb6ioPy9FJF7YJq9TaWkWUft9cK4gxk4fwqTQNUZVZfFtKAX
796	796	{798,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv9QsuFaHB6SrgetwF2xBSuCjxkxUft76pyoeSmHomvwghXG9Z1
797	797	{799}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuKddGUpcgYvagLzVAmwzvetoqg7aKTuRPTiRiwHyj7mpmh5fSq
798	798	{800,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju6BW8Ntyc2oB4cZb5FkzdakYxBqTzc9TBcssU65tPqwMKXaGkf
802	802	{804,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju7rgPpvd3Zm6PWFD5JJ4fQ9h2NFfbc5sjsHW9BBZndv9RmTBoj
803	803	{805}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuoKmfs1KBR8NKvDJmbM71KWZSiBSqAZG8M9yMK5TXqTYLsDBEh
804	804	{806,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuWN3kQNZLD658GCWHX2iqz8buCbNp1LL773X5Y6EERcrdctcV2
805	805	{807}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtfBvuHnwAvqWVmdFaMDLtu7z8tXNFE6vUCaUckCLzjJWuhSKug
824	824	{826,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtbz1ebafRa4jaFijh4qqH1pE52aCvaT8vCHsAZscyCXDnwt1RD
825	825	{827}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juqet45SQBJhFNKx1FWyPshcTvWhRGCD6i3T4ff8PBzfJyvtx9X
826	826	{828,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtq7kzmGHfoVXcVTBWw6558day7kHfsumSHKh8oaGaEpJch5XXo
799	799	{801}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuHFq8cuvkWoPff8EfxT2tiV69AwxYSzoSse9AV1CkMjzcHmrMU
800	800	{802,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuaidQs11f4QNXZPkEhUc4wjGkrpmK9TN41Tpps8saUNYGkorJm
801	801	{803}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv8SVVGk8ak4pDgxqqrhry5PLphJvdFFGiC1H4A7Dddq4Mz1xk5
806	806	{808,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtfLMGBR1XJZKcPDzcGrmPXC5zMfBihw9xAdw69ZqsTLPJhjRRn
807	807	{809}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvEFHUPXEQhVpufv1WsVnsMRy6Nd54LAvZLasU9SCYfmwJHJvwR
808	808	{810,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuiR9QnUnPYiivzYZEc1LH6jLCGBeZsHhe4LvwAKRdNUNjvYiKn
809	809	{811}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtZx8821h2FHagjHDivxdxtRTpDZDmL5VsS7anZch89N6bJPWbi
810	810	{812,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvKsot8wX6xnqaLBxf53srDqBqjaWkiBsHyMP1AwwrqMvKs4PdX
811	811	{813}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtmXX15T9H7MNAeSisYAmknJLhSKjz5cUBSUv1ZEvjKv938rcC2
812	812	{814,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuFvPM5XFQPZbmMTdBVds7gpdyxWedL3DurU8t84DJjaysrXFwb
813	813	{815}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JunYhooa8Kr5Lba92BcR2xH6U7Zzrh4U8UPa5Xvg7Fharg8SrmB
814	814	{816,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtXFpk48dwFzhrafTJifhZSiaLW8axGPkc8FLZpRhyEzHNco7WS
815	815	{817}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvHC7PK6YmduqnDqKVSkrKmP6TKZCqLcVzX76G7AQE4ZLG6kBFL
816	816	{818,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jup7Wc8QWWgphvVsFGwYk726pj8RSHaYGMAC48PU9i1oUoyHcDf
817	817	{819}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju6jD9Yyi91FppS14e8ms8G9dVu4pR1noRCiKeqDh5M3XtJrBYF
818	818	{820,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuorCzPAQJn2UKeXASo2nTmunufbM9QvjqpYNvvfZVqsoCX7Sjf
819	819	{821}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtjRZsAheNBzFeQQyZY1nxN1AfaQckAVR1BxNTMFU6MQet98FPL
820	820	{822,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvC4Vys3mKUWdoMdba18KJMtf99Bv84htNK8eMcHSzWPn8opFcN
821	821	{823}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtas8uJCgUwQzfvv7sK5pNBBHB3pQ9eiNrMt37iDvhHrAz7GzBD
822	822	{824,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju5UoTd35gGvFphTScRaDWSntYJGjV9GPzSnM9h4775zergZnAS
823	823	{825}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv8ExAN8d11VU4eJrZD4YMQHgEyg8qnGKpaKZFNRJa4hVn8o7hw
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
1	167	5000000000	\N	0
2	167	5000000000	\N	1
3	167	5000000000	\N	2
4	167	5000000000	\N	3
5	167	5000000000	\N	4
6	167	5000000000	\N	5
7	167	5000000000	\N	6
8	167	5000000000	\N	7
9	167	5000000000	\N	8
10	167	5000000000	\N	9
11	167	5000000000	\N	10
12	167	5000000000	\N	11
13	167	5000000000	\N	12
14	167	5000000000	\N	13
15	167	5000000000	\N	14
16	167	5000000000	\N	15
17	167	5000000000	\N	16
18	167	5000000000	\N	17
19	167	5000000000	\N	18
20	167	5000000000	\N	19
21	167	5000000000	\N	20
22	167	5000000000	\N	21
23	167	5000000000	\N	22
24	167	5000000000	\N	23
25	167	5000000000	\N	24
26	167	5000000000	\N	25
27	167	5000000000	\N	26
28	167	5000000000	\N	27
29	167	5000000000	\N	28
30	167	5000000000	\N	29
31	167	5000000000	\N	30
32	167	5000000000	\N	31
33	167	5000000000	\N	32
34	167	5000000000	\N	33
35	167	5000000000	\N	34
36	167	5000000000	\N	35
37	167	5000000000	\N	36
38	167	5000000000	\N	37
39	167	5000000000	\N	38
40	167	5000000000	\N	39
41	167	5000000000	\N	40
42	167	5000000000	\N	41
43	167	5000000000	\N	42
44	167	5000000000	\N	43
45	167	5000000000	\N	44
46	167	5000000000	\N	45
47	167	5000000000	\N	46
48	167	5000000000	\N	47
49	167	5000000000	\N	48
50	167	5000000000	\N	49
51	167	5000000000	\N	50
52	167	5000000000	\N	51
53	167	5000000000	\N	52
54	167	5000000000	\N	53
55	167	5000000000	\N	54
56	167	5000000000	\N	55
57	167	5000000000	\N	56
58	167	5000000000	\N	57
59	167	5000000000	\N	58
60	167	5000000000	\N	59
61	167	5000000000	\N	60
62	167	5000000000	\N	61
63	167	5000000000	\N	62
64	167	5000000000	\N	63
65	167	5000000000	\N	64
66	167	5000000000	\N	65
67	167	5000000000	\N	66
68	167	5000000000	\N	67
69	167	5000000000	\N	68
70	167	5000000000	\N	69
71	167	5000000000	\N	70
72	167	5000000000	\N	71
73	167	5000000000	\N	72
74	167	5000000000	\N	73
75	167	5000000000	\N	74
76	167	5000000000	\N	75
77	167	5000000000	\N	76
78	167	5000000000	\N	77
79	167	5000000000	\N	78
80	167	5000000000	\N	79
81	167	5000000000	\N	80
82	167	5000000000	\N	81
83	167	5000000000	\N	82
84	167	5000000000	\N	83
85	167	5000000000	\N	84
86	167	5000000000	\N	85
87	167	5000000000	\N	86
88	167	5000000000	\N	87
89	167	5000000000	\N	88
90	167	5000000000	\N	89
91	167	5000000000	\N	90
92	167	5000000000	\N	91
93	167	5000000000	\N	92
94	167	5000000000	\N	93
95	167	5000000000	\N	94
96	167	5000000000	\N	95
97	167	5000000000	\N	96
98	167	5000000000	\N	97
99	167	5000000000	\N	98
100	167	5000000000	\N	99
101	167	5000000000	\N	100
102	167	5000000000	\N	101
103	167	5000000000	\N	102
104	167	5000000000	\N	103
105	167	5000000000	\N	104
106	167	5000000000	\N	105
107	167	5000000000	\N	106
108	167	5000000000	\N	107
109	167	5000000000	\N	108
110	167	5000000000	\N	109
111	167	5000000000	\N	110
112	167	5000000000	\N	111
113	167	5000000000	\N	112
114	167	5000000000	\N	113
115	167	5000000000	\N	114
116	167	5000000000	\N	115
117	167	5000000000	\N	116
118	167	5000000000	\N	117
119	167	5000000000	\N	118
120	167	5000000000	\N	119
121	167	5000000000	\N	120
122	167	5000000000	\N	121
123	167	5000000000	\N	122
124	167	5000000000	\N	123
125	167	5000000000	\N	124
126	167	5000000000	\N	125
127	167	5000000000	\N	126
128	167	5000000000	\N	127
129	167	5000000000	\N	128
130	167	5000000000	\N	129
131	167	5000000000	\N	130
132	167	5000000000	\N	131
133	167	5000000000	\N	132
134	167	5000000000	\N	133
135	167	5000000000	\N	134
136	167	5000000000	\N	135
137	167	5000000000	\N	136
138	167	5000000000	\N	137
139	167	5000000000	\N	138
140	167	5000000000	\N	139
141	167	5000000000	\N	140
142	167	5000000000	\N	141
143	167	5000000000	\N	142
144	167	5000000000	\N	143
145	167	5000000000	\N	144
146	167	5000000000	\N	145
147	167	5000000000	\N	146
148	167	5000000000	\N	147
149	167	5000000000	\N	148
150	167	5000000000	\N	149
151	167	5000000000	\N	150
152	167	5000000000	\N	151
153	167	5000000000	\N	152
154	167	5000000000	\N	153
155	167	5000000000	\N	154
156	167	5000000000	\N	155
157	167	5000000000	\N	156
158	167	5000000000	\N	157
159	167	5000000000	\N	158
160	167	5000000000	\N	159
161	167	5000000000	\N	160
162	167	5000000000	\N	161
163	167	5000000000	\N	162
164	167	5000000000	\N	163
165	167	5000000000	\N	164
166	167	5000000000	\N	165
167	167	5000000000	\N	166
168	167	5000000000	\N	167
169	167	5000000000	\N	168
170	167	5000000000	\N	169
171	167	5000000000	\N	170
172	167	5000000000	\N	171
173	167	5000000000	\N	172
174	167	5000000000	\N	173
175	167	5000000000	\N	174
176	167	5000000000	\N	175
177	167	5000000000	\N	176
178	167	5000000000	\N	177
179	167	5000000000	\N	178
180	167	5000000000	\N	179
181	167	5000000000	\N	180
182	167	5000000000	\N	181
183	167	5000000000	\N	182
184	167	5000000000	\N	183
185	167	5000000000	\N	184
186	167	5000000000	\N	185
187	167	5000000000	\N	186
188	167	5000000000	\N	187
189	167	5000000000	\N	188
190	167	5000000000	\N	189
191	167	5000000000	\N	190
192	167	5000000000	\N	191
193	167	5000000000	\N	192
194	167	5000000000	\N	193
195	167	5000000000	\N	194
196	167	5000000000	\N	195
197	167	5000000000	\N	196
198	167	5000000000	\N	197
199	167	5000000000	\N	198
200	167	5000000000	\N	199
201	167	5000000000	\N	200
202	167	5000000000	\N	201
203	167	5000000000	\N	202
204	167	5000000000	\N	203
205	167	5000000000	\N	204
206	167	5000000000	\N	205
207	167	5000000000	\N	206
208	167	5000000000	\N	207
209	167	5000000000	\N	208
210	167	5000000000	\N	209
211	167	5000000000	\N	210
212	167	5000000000	\N	211
213	167	5000000000	\N	212
214	167	5000000000	\N	213
215	167	5000000000	\N	214
216	167	5000000000	\N	215
217	167	5000000000	\N	216
218	167	5000000000	\N	217
219	167	5000000000	\N	218
220	167	5000000000	\N	219
221	167	5000000000	\N	220
222	167	5000000000	\N	221
223	167	5000000000	\N	222
224	167	5000000000	\N	223
225	167	5000000000	\N	224
226	167	5000000000	\N	225
227	167	5000000000	\N	226
228	167	5000000000	\N	227
229	167	5000000000	\N	228
230	167	5000000000	\N	229
231	167	5000000000	\N	230
232	167	5000000000	\N	231
233	167	5000000000	\N	232
234	167	5000000000	\N	233
235	167	5000000000	\N	234
236	167	5000000000	\N	235
237	167	5000000000	\N	236
238	167	5000000000	\N	237
239	167	5000000000	\N	238
240	167	5000000000	\N	239
241	167	5000000000	\N	240
242	167	5000000000	\N	241
243	167	5000000000	\N	242
244	167	5000000000	\N	243
245	167	5000000000	\N	244
246	167	5000000000	\N	245
247	167	5000000000	\N	246
248	167	5000000000	\N	247
249	167	5000000000	\N	248
250	167	5000000000	\N	249
251	167	5000000000	\N	250
252	167	5000000000	\N	251
253	167	5000000000	\N	252
254	167	5000000000	\N	253
255	167	5000000000	\N	254
256	167	5000000000	\N	255
257	167	5000000000	\N	256
258	167	5000000000	\N	257
259	167	5000000000	\N	258
260	167	5000000000	\N	259
261	167	5000000000	\N	260
262	167	5000000000	\N	261
263	167	5000000000	\N	262
264	167	5000000000	\N	263
265	167	5000000000	\N	264
266	167	5000000000	\N	265
267	167	5000000000	\N	266
268	167	5000000000	\N	267
269	167	5000000000	\N	268
270	167	5000000000	\N	269
271	167	5000000000	\N	270
272	167	5000000000	\N	271
273	167	5000000000	\N	272
274	167	5000000000	\N	273
275	167	5000000000	\N	274
276	167	5000000000	\N	275
277	167	5000000000	\N	276
278	167	5000000000	\N	277
279	167	5000000000	\N	278
280	167	5000000000	\N	279
281	167	5000000000	\N	280
282	167	5000000000	\N	281
283	167	5000000000	\N	282
284	167	5000000000	\N	283
285	167	5000000000	\N	284
286	167	5000000000	\N	285
287	167	5000000000	\N	286
288	167	5000000000	\N	287
289	167	5000000000	\N	288
290	167	5000000000	\N	289
291	167	5000000000	\N	290
292	167	5000000000	\N	291
293	167	5000000000	\N	292
294	167	5000000000	\N	293
295	167	5000000000	\N	294
296	167	5000000000	\N	295
297	167	5000000000	\N	296
298	167	5000000000	\N	297
299	167	5000000000	\N	298
300	167	5000000000	\N	299
301	167	5000000000	\N	300
302	167	5000000000	\N	301
303	167	5000000000	\N	302
304	167	5000000000	\N	303
305	167	5000000000	\N	304
306	167	5000000000	\N	305
307	167	5000000000	\N	306
308	167	5000000000	\N	307
309	167	5000000000	\N	308
310	167	5000000000	\N	309
311	167	5000000000	\N	310
312	167	5000000000	\N	311
313	167	5000000000	\N	312
314	167	5000000000	\N	313
315	167	5000000000	\N	314
316	167	5000000000	\N	315
317	167	5000000000	\N	316
318	167	5000000000	\N	317
319	167	5000000000	\N	318
320	167	5000000000	\N	319
321	167	5000000000	\N	320
322	167	5000000000	\N	321
323	167	5000000000	\N	322
324	167	5000000000	\N	323
325	167	5000000000	\N	324
326	167	5000000000	\N	325
327	167	5000000000	\N	326
328	167	5000000000	\N	327
329	167	5000000000	\N	328
330	167	5000000000	\N	329
331	167	5000000000	\N	330
332	167	5000000000	\N	331
333	167	5000000000	\N	332
334	167	5000000000	\N	333
335	167	5000000000	\N	334
336	167	5000000000	\N	335
337	167	5000000000	\N	336
338	167	5000000000	\N	337
339	167	5000000000	\N	338
340	167	5000000000	\N	339
341	167	5000000000	\N	340
342	167	5000000000	\N	341
343	167	5000000000	\N	342
344	167	5000000000	\N	343
345	167	5000000000	\N	344
346	167	5000000000	\N	345
347	167	5000000000	\N	346
348	167	5000000000	\N	347
349	167	5000000000	\N	348
350	167	5000000000	\N	349
351	167	5000000000	\N	350
352	167	5000000000	\N	351
353	167	5000000000	\N	352
354	167	5000000000	\N	353
355	167	5000000000	\N	354
356	167	5000000000	\N	355
357	167	5000000000	\N	356
358	167	5000000000	\N	357
359	167	5000000000	\N	358
360	167	5000000000	\N	359
361	167	5000000000	\N	360
362	167	5000000000	\N	361
363	167	5000000000	\N	362
364	167	5000000000	\N	363
365	167	5000000000	\N	364
366	167	5000000000	\N	365
367	167	5000000000	\N	366
368	167	5000000000	\N	367
369	167	5000000000	\N	368
370	167	5000000000	\N	369
371	167	5000000000	\N	370
372	167	5000000000	\N	371
373	167	5000000000	\N	372
374	167	5000000000	\N	373
375	167	5000000000	\N	374
376	167	5000000000	\N	375
377	167	5000000000	\N	376
378	167	5000000000	\N	377
379	167	5000000000	\N	378
380	167	5000000000	\N	379
381	167	5000000000	\N	380
382	167	5000000000	\N	381
383	167	5000000000	\N	382
384	167	5000000000	\N	383
385	167	5000000000	\N	384
386	167	5000000000	\N	385
387	167	5000000000	\N	386
388	167	5000000000	\N	387
389	167	5000000000	\N	388
390	167	5000000000	\N	389
391	167	5000000000	\N	390
392	167	5000000000	\N	391
393	167	5000000000	\N	392
394	167	5000000000	\N	393
395	167	5000000000	\N	394
396	167	5000000000	\N	395
397	167	5000000000	\N	396
398	167	5000000000	\N	397
399	167	5000000000	\N	398
400	167	5000000000	\N	399
401	167	5000000000	\N	400
402	167	5000000000	\N	401
403	167	5000000000	\N	402
404	167	5000000000	\N	403
405	167	5000000000	\N	404
406	167	5000000000	\N	405
407	167	5000000000	\N	406
408	167	5000000000	\N	407
409	167	5000000000	\N	408
410	167	5000000000	\N	409
411	167	5000000000	\N	410
412	167	5000000000	\N	411
413	167	5000000000	\N	412
414	167	5000000000	\N	413
415	167	5000000000	\N	414
416	167	5000000000	\N	415
417	167	5000000000	\N	416
418	167	5000000000	\N	417
419	167	5000000000	\N	418
420	167	5000000000	\N	419
421	167	5000000000	\N	420
422	167	5000000000	\N	421
423	167	5000000000	\N	422
424	167	5000000000	\N	423
425	167	5000000000	\N	424
426	167	5000000000	\N	425
427	167	5000000000	\N	426
428	167	5000000000	\N	427
429	167	5000000000	\N	428
439	167	5000000000	\N	438
440	167	5000000000	\N	439
441	167	5000000000	\N	440
442	167	5000000000	\N	441
443	167	5000000000	\N	442
444	167	5000000000	\N	443
430	167	5000000000	\N	429
431	167	5000000000	\N	430
432	167	5000000000	\N	431
433	167	5000000000	\N	432
434	167	5000000000	\N	433
435	167	5000000000	\N	434
436	167	5000000000	\N	435
437	167	5000000000	\N	436
438	167	5000000000	\N	437
445	167	5000000000	\N	444
446	167	5000000000	\N	445
447	167	5000000000	\N	446
448	167	5000000000	\N	447
449	167	5000000000	\N	448
450	167	5000000000	\N	449
451	167	5000000000	\N	450
452	167	5000000000	\N	451
453	167	5000000000	\N	452
454	167	5000000000	\N	453
455	167	5000000000	\N	454
456	167	5000000000	\N	455
457	167	5000000000	\N	456
458	167	5000000000	\N	457
459	167	5000000000	\N	458
460	167	5000000000	\N	459
461	167	5000000000	\N	460
462	167	5000000000	\N	461
463	167	5000000000	\N	462
464	167	5000000000	\N	463
465	167	5000000000	\N	464
466	167	5000000000	\N	465
467	167	5000000000	\N	466
468	167	5000000000	\N	467
469	167	5000000000	\N	468
470	167	5000000000	\N	469
471	167	5000000000	\N	470
472	167	5000000000	\N	471
473	167	5000000000	\N	472
474	167	5000000000	\N	473
475	167	5000000000	\N	474
476	167	5000000000	\N	475
477	167	5000000000	\N	476
478	167	5000000000	\N	477
479	167	5000000000	\N	478
480	167	5000000000	\N	479
481	167	5000000000	\N	480
482	167	5000000000	\N	481
483	167	5000000000	\N	482
484	167	5000000000	\N	483
485	167	5000000000	\N	484
486	167	5000000000	\N	485
487	167	5000000000	\N	486
488	167	5000000000	\N	487
489	167	5000000000	\N	488
490	167	5000000000	\N	489
491	167	5000000000	\N	490
492	167	5000000000	\N	491
493	167	5000000000	\N	492
494	167	5000000000	\N	493
495	167	5000000000	\N	494
496	167	5000000000	\N	495
497	167	5000000000	\N	496
498	167	5000000000	\N	497
499	167	5000000000	\N	498
500	167	5000000000	\N	499
501	167	5000000000	\N	500
502	167	5000000000	\N	501
503	167	5000000000	\N	502
504	167	5000000000	\N	503
505	167	5000000000	\N	504
506	167	5000000000	\N	505
507	167	5000000000	\N	506
508	167	5000000000	\N	507
509	167	5000000000	\N	508
510	167	5000000000	\N	509
511	167	5000000000	\N	510
512	167	5000000000	\N	511
513	167	5000000000	\N	512
514	167	5000000000	\N	513
515	167	5000000000	\N	514
516	167	5000000000	\N	515
517	167	5000000000	\N	516
518	167	5000000000	\N	517
519	167	5000000000	\N	518
520	167	5000000000	\N	519
521	167	5000000000	\N	520
522	167	5000000000	\N	521
523	167	5000000000	\N	522
524	167	5000000000	\N	523
525	167	5000000000	\N	524
526	167	5000000000	\N	525
527	167	5000000000	\N	526
528	167	5000000000	\N	527
529	167	5000000000	\N	528
530	167	5000000000	\N	529
531	167	5000000000	\N	530
532	167	5000000000	\N	531
533	167	5000000000	\N	532
534	167	5000000000	\N	533
535	167	5000000000	\N	534
536	167	5000000000	\N	535
537	167	5000000000	\N	536
538	167	5000000000	\N	537
539	167	5000000000	\N	538
540	167	5000000000	\N	539
541	167	5000000000	\N	540
542	167	5000000000	\N	541
543	167	5000000000	\N	542
544	167	5000000000	\N	543
545	167	5000000000	\N	544
546	167	5000000000	\N	545
547	167	5000000000	\N	546
548	167	5000000000	\N	547
549	167	5000000000	\N	548
550	167	5000000000	\N	549
551	167	5000000000	\N	550
552	167	5000000000	\N	551
553	167	5000000000	\N	552
554	167	5000000000	\N	553
555	167	5000000000	\N	554
556	167	5000000000	\N	555
557	167	5000000000	\N	556
558	167	5000000000	\N	557
559	167	5000000000	\N	558
560	167	5000000000	\N	559
561	167	5000000000	\N	560
562	167	5000000000	\N	561
563	167	5000000000	\N	562
564	167	5000000000	\N	563
565	167	5000000000	\N	564
566	167	5000000000	\N	565
567	167	5000000000	\N	566
568	167	5000000000	\N	567
569	167	5000000000	\N	568
570	167	5000000000	\N	569
571	167	5000000000	\N	570
572	167	5000000000	\N	571
573	167	5000000000	\N	572
574	167	5000000000	\N	573
575	167	5000000000	\N	574
576	167	5000000000	\N	575
577	167	5000000000	\N	576
578	167	5000000000	\N	577
579	167	5000000000	\N	578
580	167	5000000000	\N	579
581	167	5000000000	\N	580
582	167	5000000000	\N	581
583	167	5000000000	\N	582
584	167	5000000000	\N	583
585	167	5000000000	\N	584
586	167	5000000000	\N	585
587	167	5000000000	\N	586
588	167	5000000000	\N	587
589	167	5000000000	\N	588
590	167	5000000000	\N	589
591	167	5000000000	\N	590
592	167	5000000000	\N	591
593	167	5000000000	\N	592
594	167	5000000000	\N	593
595	167	5000000000	\N	594
596	167	5000000000	\N	595
597	167	5000000000	\N	596
598	167	5000000000	\N	597
599	167	5000000000	\N	598
600	167	5000000000	\N	599
601	167	5000000000	\N	600
602	167	5000000000	\N	601
603	167	5000000000	\N	602
604	167	5000000000	\N	603
605	167	5000000000	\N	604
606	167	5000000000	\N	605
607	167	5000000000	\N	606
608	167	5000000000	\N	607
609	167	5000000000	\N	608
610	167	5000000000	\N	609
611	167	5000000000	\N	610
612	167	5000000000	\N	611
613	167	5000000000	\N	612
614	167	5000000000	\N	613
615	167	5000000000	\N	614
616	167	5000000000	\N	615
617	167	5000000000	\N	616
618	167	5000000000	\N	617
619	167	5000000000	\N	618
620	167	5000000000	\N	619
621	167	5000000000	\N	620
622	167	5000000000	\N	621
623	167	5000000000	\N	622
624	167	5000000000	\N	623
625	167	5000000000	\N	624
626	167	5000000000	\N	625
627	167	5000000000	\N	626
628	167	5000000000	\N	627
629	167	5000000000	\N	628
630	167	5000000000	\N	629
631	167	5000000000	\N	630
632	167	5000000000	\N	631
633	167	5000000000	\N	632
634	167	5000000000	\N	633
635	167	5000000000	\N	634
636	167	5000000000	\N	635
637	167	5000000000	\N	636
638	167	5000000000	\N	637
639	167	5000000000	\N	638
640	167	5000000000	\N	639
641	167	5000000000	\N	640
642	167	5000000000	\N	641
643	167	5000000000	\N	642
644	167	5000000000	\N	643
645	167	5000000000	\N	644
646	167	5000000000	\N	645
647	167	5000000000	\N	646
648	167	5000000000	\N	647
649	167	5000000000	\N	648
650	167	5000000000	\N	649
651	167	5000000000	\N	650
652	167	5000000000	\N	651
653	167	5000000000	\N	652
654	167	5000000000	\N	653
655	167	5000000000	\N	654
656	167	5000000000	\N	655
657	167	5000000000	\N	656
658	167	5000000000	\N	657
659	167	5000000000	\N	658
660	167	5000000000	\N	659
661	167	5000000000	\N	660
662	167	5000000000	\N	661
663	167	5000000000	\N	662
664	167	5000000000	\N	663
665	167	5000000000	\N	664
666	167	5000000000	\N	665
667	167	5000000000	\N	666
668	167	5000000000	\N	667
669	167	5000000000	\N	668
670	167	5000000000	\N	669
671	167	5000000000	\N	670
672	167	5000000000	\N	671
673	167	5000000000	\N	672
674	167	5000000000	\N	673
675	167	5000000000	\N	674
676	167	5000000000	\N	675
677	167	5000000000	\N	676
678	167	5000000000	\N	677
679	167	5000000000	\N	678
680	167	5000000000	\N	679
681	167	5000000000	\N	680
682	167	5000000000	\N	681
683	167	5000000000	\N	682
684	167	5000000000	\N	683
685	167	5000000000	\N	684
686	167	5000000000	\N	685
687	167	5000000000	\N	686
688	167	5000000000	\N	687
689	167	5000000000	\N	688
690	167	5000000000	\N	689
691	167	5000000000	\N	690
692	167	5000000000	\N	691
693	167	5000000000	\N	692
694	167	5000000000	\N	693
695	167	5000000000	\N	694
696	167	5000000000	\N	695
697	167	5000000000	\N	696
698	167	5000000000	\N	697
699	167	5000000000	\N	698
700	167	5000000000	\N	699
701	167	5000000000	\N	700
702	167	5000000000	\N	701
703	167	5000000000	\N	702
704	167	5000000000	\N	703
705	167	5000000000	\N	704
706	167	5000000000	\N	705
707	167	5000000000	\N	706
708	167	5000000000	\N	707
709	167	5000000000	\N	708
710	167	5000000000	\N	709
711	167	5000000000	\N	710
712	167	5000000000	\N	711
713	167	5000000000	\N	712
714	167	5000000000	\N	713
747	167	5000000000	\N	746
748	167	5000000000	\N	747
749	167	5000000000	\N	748
750	167	5000000000	\N	749
751	167	5000000000	\N	750
754	167	5000000000	\N	753
755	167	5000000000	\N	754
756	167	5000000000	\N	755
757	167	5000000000	\N	756
758	167	5000000000	\N	757
759	167	5000000000	\N	758
760	167	5000000000	\N	759
761	167	5000000000	\N	760
762	167	5000000000	\N	761
763	167	5000000000	\N	762
764	167	5000000000	\N	763
775	167	5000000000	\N	774
776	167	5000000000	\N	775
777	167	5000000000	\N	776
778	167	5000000000	\N	777
779	167	5000000000	\N	778
780	167	5000000000	\N	779
715	167	5000000000	\N	714
716	167	5000000000	\N	715
717	167	5000000000	\N	716
718	167	5000000000	\N	717
719	167	5000000000	\N	718
720	167	5000000000	\N	719
721	167	5000000000	\N	720
722	167	5000000000	\N	721
723	167	5000000000	\N	722
724	167	5000000000	\N	723
725	167	5000000000	\N	724
726	167	5000000000	\N	725
727	167	5000000000	\N	726
728	167	5000000000	\N	727
729	167	5000000000	\N	728
730	167	5000000000	\N	729
731	167	5000000000	\N	730
732	167	5000000000	\N	731
733	167	5000000000	\N	732
734	167	5000000000	\N	733
735	167	5000000000	\N	734
736	167	5000000000	\N	735
737	167	5000000000	\N	736
738	167	5000000000	\N	737
739	167	5000000000	\N	738
740	167	5000000000	\N	739
741	167	5000000000	\N	740
742	167	5000000000	\N	741
743	167	5000000000	\N	742
744	167	5000000000	\N	743
745	167	5000000000	\N	744
746	167	5000000000	\N	745
752	167	5000000000	\N	751
753	167	5000000000	\N	752
765	167	5000000000	\N	764
766	167	5000000000	\N	765
767	167	5000000000	\N	766
768	167	5000000000	\N	767
769	167	5000000000	\N	768
770	167	5000000000	\N	769
771	167	5000000000	\N	770
772	167	5000000000	\N	771
773	167	5000000000	\N	772
774	167	5000000000	\N	773
781	167	5000000000	\N	780
782	167	5000000000	\N	781
783	167	5000000000	\N	782
784	167	5000000000	\N	783
785	167	5000000000	\N	784
786	167	5000000000	\N	785
787	167	5000000000	\N	786
788	167	5000000000	\N	787
789	167	5000000000	\N	788
790	167	5000000000	\N	789
791	167	5000000000	\N	790
792	167	5000000000	\N	791
793	167	5000000000	\N	792
794	167	5000000000	\N	793
795	167	5000000000	\N	794
796	167	5000000000	\N	795
797	167	5000000000	\N	796
798	167	5000000000	\N	797
799	167	5000000000	\N	798
800	167	5000000000	\N	799
801	167	5000000000	\N	800
802	167	5000000000	\N	801
803	167	5000000000	\N	802
804	167	5000000000	\N	803
805	167	5000000000	\N	804
806	167	5000000000	\N	805
807	167	5000000000	\N	806
808	167	5000000000	\N	807
809	167	5000000000	\N	808
810	167	5000000000	\N	809
811	167	5000000000	\N	810
812	167	5000000000	\N	811
813	167	5000000000	\N	812
814	167	5000000000	\N	813
815	167	5000000000	\N	814
816	167	5000000000	\N	815
817	167	5000000000	\N	816
818	167	5000000000	\N	817
819	167	5000000000	\N	818
820	167	5000000000	\N	819
821	167	5000000000	\N	820
822	167	5000000000	\N	821
823	167	5000000000	\N	822
824	167	5000000000	\N	823
825	167	5000000000	\N	824
826	167	5000000000	\N	825
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
230	229
231	230
232	231
233	232
234	233
235	234
236	235
237	236
238	237
239	238
240	239
241	240
242	241
243	242
249	248
228	227
229	228
244	243
245	244
246	245
247	246
248	247
250	249
251	250
252	251
253	252
254	253
255	254
256	255
257	256
258	257
259	258
260	259
261	260
262	261
263	262
264	263
265	264
266	265
267	266
268	267
269	268
270	269
271	270
272	271
273	272
274	273
275	274
276	275
277	276
278	277
279	278
280	279
281	280
282	281
283	282
284	283
285	284
286	285
287	286
288	287
289	288
290	289
291	290
292	291
293	292
294	293
295	294
296	295
297	296
298	297
299	298
300	299
301	300
302	301
303	302
304	303
305	304
306	305
307	306
308	307
309	308
310	309
311	310
312	311
313	312
314	313
315	314
316	315
317	316
318	317
319	318
320	319
321	320
322	321
323	322
324	323
325	324
326	325
327	326
328	327
329	328
330	329
331	330
332	331
333	332
334	333
335	334
336	335
337	336
338	337
339	338
340	339
341	340
342	341
343	342
344	343
345	344
346	345
347	346
348	347
349	348
350	349
351	350
352	351
353	352
354	353
355	354
356	355
357	356
358	357
359	358
360	359
361	360
362	361
363	362
364	363
365	364
366	365
367	366
368	367
369	368
370	369
371	370
372	371
373	372
374	373
375	374
376	375
377	376
378	377
379	378
380	379
381	380
382	381
383	382
384	383
385	384
386	385
387	386
388	387
389	388
390	389
391	390
392	391
393	392
394	393
395	394
396	395
397	396
398	397
399	398
400	399
401	400
402	401
403	402
404	403
405	404
406	405
407	406
408	407
409	408
410	409
411	410
412	411
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
241	241	241
242	242	242
243	243	243
244	244	244
245	245	245
246	246	246
247	247	247
248	248	248
249	249	249
250	250	250
251	251	251
252	252	252
253	253	253
254	254	254
255	255	255
256	256	256
257	257	257
258	258	258
259	259	259
260	260	260
261	261	261
262	262	262
263	263	263
264	264	264
265	265	265
266	266	266
267	267	267
268	268	268
269	269	269
270	270	270
271	271	271
272	272	272
273	273	273
274	274	274
275	275	275
276	276	276
277	277	277
278	278	278
279	279	279
280	280	280
281	281	281
282	282	282
283	283	283
284	284	284
285	285	285
286	286	286
287	287	287
288	288	288
289	289	289
290	290	290
291	291	291
292	292	292
293	293	293
294	294	294
295	295	295
296	296	296
297	297	297
298	298	298
299	299	299
300	300	300
301	301	301
302	302	302
303	303	303
304	304	304
305	305	305
306	306	306
307	307	307
308	308	308
309	309	309
310	310	310
311	311	311
312	312	312
313	313	313
314	314	314
315	315	315
316	316	316
317	317	317
318	318	318
319	319	319
320	320	320
321	321	321
322	322	322
323	323	323
324	324	324
325	325	325
326	326	326
327	327	327
328	328	328
329	329	329
330	330	330
331	331	331
332	332	332
333	333	333
334	334	334
335	335	335
336	336	336
337	337	337
338	338	338
339	339	339
340	340	340
341	341	341
342	342	342
343	343	343
344	344	344
345	345	345
346	346	346
347	347	347
348	348	348
349	349	349
350	350	350
351	351	351
352	352	352
353	353	353
354	354	354
355	355	355
356	356	356
357	357	357
358	358	358
359	359	359
360	360	360
361	361	361
362	362	362
363	363	363
364	364	364
365	365	365
366	366	366
367	367	367
368	368	368
369	369	369
370	370	370
371	371	371
372	372	372
373	373	373
374	374	374
375	375	375
376	376	376
377	377	377
378	378	378
379	379	379
380	380	380
381	381	381
382	382	382
383	383	383
384	384	384
385	385	385
386	386	386
387	387	387
388	388	388
389	389	389
390	390	390
391	391	391
392	392	392
393	393	393
394	394	394
395	395	395
396	396	396
397	397	397
398	398	398
399	399	399
400	400	400
401	401	401
402	402	402
403	403	403
404	404	404
405	405	405
406	406	406
407	407	407
408	408	408
409	409	409
410	410	410
411	411	411
412	412	412
413	413	413
414	414	414
\.


--
-- Data for Name: zkapp_permissions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.zkapp_permissions (id, edit_state, send, receive, access, set_delegate, set_permissions, set_verification_key_auth, set_verification_key_txn_version, set_zkapp_uri, edit_action_state, set_token_symbol, increment_nonce, set_voting_for, set_timing) FROM stdin;
1	signature	signature	none	none	signature	signature	signature	2	signature	signature	signature	signature	signature	signature
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
187	186	\N	\N	\N	\N	\N	\N	\N
188	187	\N	\N	\N	\N	\N	\N	\N
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
220	219	\N	\N	\N	\N	\N	\N	\N
221	220	\N	\N	\N	\N	\N	\N	\N
222	221	\N	\N	\N	\N	\N	\N	\N
225	224	\N	\N	\N	\N	\N	\N	\N
229	228	\N	\N	\N	\N	\N	\N	\N
230	229	\N	\N	\N	\N	\N	\N	\N
245	244	\N	\N	\N	\N	\N	\N	\N
246	245	\N	\N	\N	\N	\N	\N	\N
247	246	\N	\N	\N	\N	\N	\N	\N
248	247	\N	\N	\N	\N	\N	\N	\N
249	248	\N	\N	\N	\N	\N	\N	\N
251	250	\N	\N	\N	\N	\N	\N	\N
252	251	\N	\N	\N	\N	\N	\N	\N
189	188	\N	\N	\N	\N	\N	\N	\N
190	189	\N	\N	\N	\N	\N	\N	\N
191	190	\N	\N	\N	\N	\N	\N	\N
192	191	\N	\N	\N	\N	\N	\N	\N
193	192	\N	\N	\N	\N	\N	\N	\N
216	215	\N	\N	\N	\N	\N	\N	\N
217	216	\N	\N	\N	\N	\N	\N	\N
218	217	\N	\N	\N	\N	\N	\N	\N
219	218	\N	\N	\N	\N	\N	\N	\N
223	222	\N	\N	\N	\N	\N	\N	\N
224	223	\N	\N	\N	\N	\N	\N	\N
226	225	\N	\N	\N	\N	\N	\N	\N
227	226	\N	\N	\N	\N	\N	\N	\N
228	227	\N	\N	\N	\N	\N	\N	\N
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
241	240	\N	\N	\N	\N	\N	\N	\N
242	241	\N	\N	\N	\N	\N	\N	\N
243	242	\N	\N	\N	\N	\N	\N	\N
244	243	\N	\N	\N	\N	\N	\N	\N
250	249	\N	\N	\N	\N	\N	\N	\N
253	252	\N	\N	\N	\N	\N	\N	\N
254	253	\N	\N	\N	\N	\N	\N	\N
255	254	\N	\N	\N	\N	\N	\N	\N
256	255	\N	\N	\N	\N	\N	\N	\N
257	256	\N	\N	\N	\N	\N	\N	\N
258	257	\N	\N	\N	\N	\N	\N	\N
259	258	\N	\N	\N	\N	\N	\N	\N
260	259	\N	\N	\N	\N	\N	\N	\N
261	260	\N	\N	\N	\N	\N	\N	\N
262	261	\N	\N	\N	\N	\N	\N	\N
263	262	\N	\N	\N	\N	\N	\N	\N
264	263	\N	\N	\N	\N	\N	\N	\N
265	264	\N	\N	\N	\N	\N	\N	\N
266	265	\N	\N	\N	\N	\N	\N	\N
267	266	\N	\N	\N	\N	\N	\N	\N
268	267	\N	\N	\N	\N	\N	\N	\N
269	268	\N	\N	\N	\N	\N	\N	\N
270	269	\N	\N	\N	\N	\N	\N	\N
271	270	\N	\N	\N	\N	\N	\N	\N
272	271	\N	\N	\N	\N	\N	\N	\N
273	272	\N	\N	\N	\N	\N	\N	\N
274	273	\N	\N	\N	\N	\N	\N	\N
275	274	\N	\N	\N	\N	\N	\N	\N
276	275	\N	\N	\N	\N	\N	\N	\N
277	276	\N	\N	\N	\N	\N	\N	\N
278	277	\N	\N	\N	\N	\N	\N	\N
279	278	\N	\N	\N	\N	\N	\N	\N
280	279	\N	\N	\N	\N	\N	\N	\N
281	280	\N	\N	\N	\N	\N	\N	\N
282	281	\N	\N	\N	\N	\N	\N	\N
283	282	\N	\N	\N	\N	\N	\N	\N
284	283	\N	\N	\N	\N	\N	\N	\N
285	284	\N	\N	\N	\N	\N	\N	\N
286	285	\N	\N	\N	\N	\N	\N	\N
287	286	\N	\N	\N	\N	\N	\N	\N
288	287	\N	\N	\N	\N	\N	\N	\N
289	288	\N	\N	\N	\N	\N	\N	\N
290	289	\N	\N	\N	\N	\N	\N	\N
291	290	\N	\N	\N	\N	\N	\N	\N
292	291	\N	\N	\N	\N	\N	\N	\N
293	292	\N	\N	\N	\N	\N	\N	\N
294	293	\N	\N	\N	\N	\N	\N	\N
295	294	\N	\N	\N	\N	\N	\N	\N
296	295	\N	\N	\N	\N	\N	\N	\N
297	296	\N	\N	\N	\N	\N	\N	\N
298	297	\N	\N	\N	\N	\N	\N	\N
299	298	\N	\N	\N	\N	\N	\N	\N
300	299	\N	\N	\N	\N	\N	\N	\N
301	300	\N	\N	\N	\N	\N	\N	\N
302	301	\N	\N	\N	\N	\N	\N	\N
303	302	\N	\N	\N	\N	\N	\N	\N
304	303	\N	\N	\N	\N	\N	\N	\N
305	304	\N	\N	\N	\N	\N	\N	\N
306	305	\N	\N	\N	\N	\N	\N	\N
307	306	\N	\N	\N	\N	\N	\N	\N
308	307	\N	\N	\N	\N	\N	\N	\N
309	308	\N	\N	\N	\N	\N	\N	\N
310	309	\N	\N	\N	\N	\N	\N	\N
311	310	\N	\N	\N	\N	\N	\N	\N
312	311	\N	\N	\N	\N	\N	\N	\N
313	312	\N	\N	\N	\N	\N	\N	\N
314	313	\N	\N	\N	\N	\N	\N	\N
315	314	\N	\N	\N	\N	\N	\N	\N
316	315	\N	\N	\N	\N	\N	\N	\N
317	316	\N	\N	\N	\N	\N	\N	\N
318	317	\N	\N	\N	\N	\N	\N	\N
319	318	\N	\N	\N	\N	\N	\N	\N
320	319	\N	\N	\N	\N	\N	\N	\N
321	320	\N	\N	\N	\N	\N	\N	\N
322	321	\N	\N	\N	\N	\N	\N	\N
323	322	\N	\N	\N	\N	\N	\N	\N
324	323	\N	\N	\N	\N	\N	\N	\N
325	324	\N	\N	\N	\N	\N	\N	\N
326	325	\N	\N	\N	\N	\N	\N	\N
327	326	\N	\N	\N	\N	\N	\N	\N
328	327	\N	\N	\N	\N	\N	\N	\N
329	328	\N	\N	\N	\N	\N	\N	\N
330	329	\N	\N	\N	\N	\N	\N	\N
331	330	\N	\N	\N	\N	\N	\N	\N
332	331	\N	\N	\N	\N	\N	\N	\N
333	332	\N	\N	\N	\N	\N	\N	\N
334	333	\N	\N	\N	\N	\N	\N	\N
335	334	\N	\N	\N	\N	\N	\N	\N
336	335	\N	\N	\N	\N	\N	\N	\N
337	336	\N	\N	\N	\N	\N	\N	\N
338	337	\N	\N	\N	\N	\N	\N	\N
339	338	\N	\N	\N	\N	\N	\N	\N
340	339	\N	\N	\N	\N	\N	\N	\N
341	340	\N	\N	\N	\N	\N	\N	\N
342	341	\N	\N	\N	\N	\N	\N	\N
343	342	\N	\N	\N	\N	\N	\N	\N
344	343	\N	\N	\N	\N	\N	\N	\N
345	344	\N	\N	\N	\N	\N	\N	\N
346	345	\N	\N	\N	\N	\N	\N	\N
347	346	\N	\N	\N	\N	\N	\N	\N
348	347	\N	\N	\N	\N	\N	\N	\N
349	348	\N	\N	\N	\N	\N	\N	\N
350	349	\N	\N	\N	\N	\N	\N	\N
351	350	\N	\N	\N	\N	\N	\N	\N
352	351	\N	\N	\N	\N	\N	\N	\N
353	352	\N	\N	\N	\N	\N	\N	\N
354	353	\N	\N	\N	\N	\N	\N	\N
355	354	\N	\N	\N	\N	\N	\N	\N
356	355	\N	\N	\N	\N	\N	\N	\N
357	356	\N	\N	\N	\N	\N	\N	\N
358	357	\N	\N	\N	\N	\N	\N	\N
359	358	\N	\N	\N	\N	\N	\N	\N
360	359	\N	\N	\N	\N	\N	\N	\N
361	360	\N	\N	\N	\N	\N	\N	\N
362	361	\N	\N	\N	\N	\N	\N	\N
363	362	\N	\N	\N	\N	\N	\N	\N
364	363	\N	\N	\N	\N	\N	\N	\N
365	364	\N	\N	\N	\N	\N	\N	\N
366	365	\N	\N	\N	\N	\N	\N	\N
367	366	\N	\N	\N	\N	\N	\N	\N
368	367	\N	\N	\N	\N	\N	\N	\N
369	368	\N	\N	\N	\N	\N	\N	\N
370	369	\N	\N	\N	\N	\N	\N	\N
371	370	\N	\N	\N	\N	\N	\N	\N
372	371	\N	\N	\N	\N	\N	\N	\N
373	372	\N	\N	\N	\N	\N	\N	\N
374	373	\N	\N	\N	\N	\N	\N	\N
375	374	\N	\N	\N	\N	\N	\N	\N
376	375	\N	\N	\N	\N	\N	\N	\N
377	376	\N	\N	\N	\N	\N	\N	\N
378	377	\N	\N	\N	\N	\N	\N	\N
379	378	\N	\N	\N	\N	\N	\N	\N
380	379	\N	\N	\N	\N	\N	\N	\N
381	380	\N	\N	\N	\N	\N	\N	\N
382	381	\N	\N	\N	\N	\N	\N	\N
383	382	\N	\N	\N	\N	\N	\N	\N
384	383	\N	\N	\N	\N	\N	\N	\N
385	384	\N	\N	\N	\N	\N	\N	\N
386	385	\N	\N	\N	\N	\N	\N	\N
387	386	\N	\N	\N	\N	\N	\N	\N
388	387	\N	\N	\N	\N	\N	\N	\N
389	388	\N	\N	\N	\N	\N	\N	\N
390	389	\N	\N	\N	\N	\N	\N	\N
391	390	\N	\N	\N	\N	\N	\N	\N
392	391	\N	\N	\N	\N	\N	\N	\N
393	392	\N	\N	\N	\N	\N	\N	\N
394	393	\N	\N	\N	\N	\N	\N	\N
395	394	\N	\N	\N	\N	\N	\N	\N
396	395	\N	\N	\N	\N	\N	\N	\N
397	396	\N	\N	\N	\N	\N	\N	\N
398	397	\N	\N	\N	\N	\N	\N	\N
399	398	\N	\N	\N	\N	\N	\N	\N
400	399	\N	\N	\N	\N	\N	\N	\N
401	400	\N	\N	\N	\N	\N	\N	\N
402	401	\N	\N	\N	\N	\N	\N	\N
403	402	\N	\N	\N	\N	\N	\N	\N
404	403	\N	\N	\N	\N	\N	\N	\N
405	404	\N	\N	\N	\N	\N	\N	\N
406	405	\N	\N	\N	\N	\N	\N	\N
407	406	\N	\N	\N	\N	\N	\N	\N
408	407	\N	\N	\N	\N	\N	\N	\N
409	408	\N	\N	\N	\N	\N	\N	\N
410	409	\N	\N	\N	\N	\N	\N	\N
411	410	\N	\N	\N	\N	\N	\N	\N
412	411	\N	\N	\N	\N	\N	\N	\N
413	412	\N	\N	\N	\N	\N	\N	\N
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
190	189	\N	\N	\N	\N	\N	\N	\N
191	190	\N	\N	\N	\N	\N	\N	\N
192	191	\N	\N	\N	\N	\N	\N	\N
193	192	\N	\N	\N	\N	\N	\N	\N
194	193	\N	\N	\N	\N	\N	\N	\N
217	216	\N	\N	\N	\N	\N	\N	\N
218	217	\N	\N	\N	\N	\N	\N	\N
219	218	\N	\N	\N	\N	\N	\N	\N
220	219	\N	\N	\N	\N	\N	\N	\N
224	223	\N	\N	\N	\N	\N	\N	\N
225	224	\N	\N	\N	\N	\N	\N	\N
227	226	\N	\N	\N	\N	\N	\N	\N
228	227	\N	\N	\N	\N	\N	\N	\N
229	228	\N	\N	\N	\N	\N	\N	\N
232	231	\N	\N	\N	\N	\N	\N	\N
233	232	\N	\N	\N	\N	\N	\N	\N
234	233	\N	\N	\N	\N	\N	\N	\N
235	234	\N	\N	\N	\N	\N	\N	\N
236	235	\N	\N	\N	\N	\N	\N	\N
237	236	\N	\N	\N	\N	\N	\N	\N
238	237	\N	\N	\N	\N	\N	\N	\N
239	238	\N	\N	\N	\N	\N	\N	\N
240	239	\N	\N	\N	\N	\N	\N	\N
241	240	\N	\N	\N	\N	\N	\N	\N
242	241	\N	\N	\N	\N	\N	\N	\N
243	242	\N	\N	\N	\N	\N	\N	\N
244	243	\N	\N	\N	\N	\N	\N	\N
245	244	\N	\N	\N	\N	\N	\N	\N
187	186	\N	\N	\N	\N	\N	\N	\N
188	187	\N	\N	\N	\N	\N	\N	\N
189	188	\N	\N	\N	\N	\N	\N	\N
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
221	220	\N	\N	\N	\N	\N	\N	\N
222	221	\N	\N	\N	\N	\N	\N	\N
223	222	\N	\N	\N	\N	\N	\N	\N
226	225	\N	\N	\N	\N	\N	\N	\N
230	229	\N	\N	\N	\N	\N	\N	\N
231	230	\N	\N	\N	\N	\N	\N	\N
246	245	\N	\N	\N	\N	\N	\N	\N
247	246	\N	\N	\N	\N	\N	\N	\N
248	247	\N	\N	\N	\N	\N	\N	\N
249	248	\N	\N	\N	\N	\N	\N	\N
250	249	\N	\N	\N	\N	\N	\N	\N
251	250	\N	\N	\N	\N	\N	\N	\N
252	251	\N	\N	\N	\N	\N	\N	\N
253	252	\N	\N	\N	\N	\N	\N	\N
254	253	\N	\N	\N	\N	\N	\N	\N
255	254	\N	\N	\N	\N	\N	\N	\N
256	255	\N	\N	\N	\N	\N	\N	\N
257	256	\N	\N	\N	\N	\N	\N	\N
258	257	\N	\N	\N	\N	\N	\N	\N
259	258	\N	\N	\N	\N	\N	\N	\N
260	259	\N	\N	\N	\N	\N	\N	\N
261	260	\N	\N	\N	\N	\N	\N	\N
262	261	\N	\N	\N	\N	\N	\N	\N
263	262	\N	\N	\N	\N	\N	\N	\N
264	263	\N	\N	\N	\N	\N	\N	\N
265	264	\N	\N	\N	\N	\N	\N	\N
266	265	\N	\N	\N	\N	\N	\N	\N
267	266	\N	\N	\N	\N	\N	\N	\N
268	267	\N	\N	\N	\N	\N	\N	\N
269	268	\N	\N	\N	\N	\N	\N	\N
270	269	\N	\N	\N	\N	\N	\N	\N
271	270	\N	\N	\N	\N	\N	\N	\N
272	271	\N	\N	\N	\N	\N	\N	\N
273	272	\N	\N	\N	\N	\N	\N	\N
274	273	\N	\N	\N	\N	\N	\N	\N
275	274	\N	\N	\N	\N	\N	\N	\N
276	275	\N	\N	\N	\N	\N	\N	\N
277	276	\N	\N	\N	\N	\N	\N	\N
278	277	\N	\N	\N	\N	\N	\N	\N
279	278	\N	\N	\N	\N	\N	\N	\N
280	279	\N	\N	\N	\N	\N	\N	\N
281	280	\N	\N	\N	\N	\N	\N	\N
282	281	\N	\N	\N	\N	\N	\N	\N
283	282	\N	\N	\N	\N	\N	\N	\N
284	283	\N	\N	\N	\N	\N	\N	\N
285	284	\N	\N	\N	\N	\N	\N	\N
286	285	\N	\N	\N	\N	\N	\N	\N
287	286	\N	\N	\N	\N	\N	\N	\N
288	287	\N	\N	\N	\N	\N	\N	\N
289	288	\N	\N	\N	\N	\N	\N	\N
290	289	\N	\N	\N	\N	\N	\N	\N
291	290	\N	\N	\N	\N	\N	\N	\N
292	291	\N	\N	\N	\N	\N	\N	\N
293	292	\N	\N	\N	\N	\N	\N	\N
294	293	\N	\N	\N	\N	\N	\N	\N
295	294	\N	\N	\N	\N	\N	\N	\N
296	295	\N	\N	\N	\N	\N	\N	\N
297	296	\N	\N	\N	\N	\N	\N	\N
298	297	\N	\N	\N	\N	\N	\N	\N
299	298	\N	\N	\N	\N	\N	\N	\N
300	299	\N	\N	\N	\N	\N	\N	\N
301	300	\N	\N	\N	\N	\N	\N	\N
302	301	\N	\N	\N	\N	\N	\N	\N
303	302	\N	\N	\N	\N	\N	\N	\N
304	303	\N	\N	\N	\N	\N	\N	\N
305	304	\N	\N	\N	\N	\N	\N	\N
306	305	\N	\N	\N	\N	\N	\N	\N
307	306	\N	\N	\N	\N	\N	\N	\N
308	307	\N	\N	\N	\N	\N	\N	\N
309	308	\N	\N	\N	\N	\N	\N	\N
310	309	\N	\N	\N	\N	\N	\N	\N
311	310	\N	\N	\N	\N	\N	\N	\N
312	311	\N	\N	\N	\N	\N	\N	\N
313	312	\N	\N	\N	\N	\N	\N	\N
314	313	\N	\N	\N	\N	\N	\N	\N
315	314	\N	\N	\N	\N	\N	\N	\N
316	315	\N	\N	\N	\N	\N	\N	\N
317	316	\N	\N	\N	\N	\N	\N	\N
318	317	\N	\N	\N	\N	\N	\N	\N
319	318	\N	\N	\N	\N	\N	\N	\N
320	319	\N	\N	\N	\N	\N	\N	\N
321	320	\N	\N	\N	\N	\N	\N	\N
322	321	\N	\N	\N	\N	\N	\N	\N
323	322	\N	\N	\N	\N	\N	\N	\N
324	323	\N	\N	\N	\N	\N	\N	\N
325	324	\N	\N	\N	\N	\N	\N	\N
326	325	\N	\N	\N	\N	\N	\N	\N
327	326	\N	\N	\N	\N	\N	\N	\N
328	327	\N	\N	\N	\N	\N	\N	\N
329	328	\N	\N	\N	\N	\N	\N	\N
330	329	\N	\N	\N	\N	\N	\N	\N
331	330	\N	\N	\N	\N	\N	\N	\N
332	331	\N	\N	\N	\N	\N	\N	\N
333	332	\N	\N	\N	\N	\N	\N	\N
334	333	\N	\N	\N	\N	\N	\N	\N
335	334	\N	\N	\N	\N	\N	\N	\N
336	335	\N	\N	\N	\N	\N	\N	\N
337	336	\N	\N	\N	\N	\N	\N	\N
338	337	\N	\N	\N	\N	\N	\N	\N
339	338	\N	\N	\N	\N	\N	\N	\N
340	339	\N	\N	\N	\N	\N	\N	\N
341	340	\N	\N	\N	\N	\N	\N	\N
342	341	\N	\N	\N	\N	\N	\N	\N
343	342	\N	\N	\N	\N	\N	\N	\N
344	343	\N	\N	\N	\N	\N	\N	\N
345	344	\N	\N	\N	\N	\N	\N	\N
346	345	\N	\N	\N	\N	\N	\N	\N
347	346	\N	\N	\N	\N	\N	\N	\N
348	347	\N	\N	\N	\N	\N	\N	\N
349	348	\N	\N	\N	\N	\N	\N	\N
350	349	\N	\N	\N	\N	\N	\N	\N
351	350	\N	\N	\N	\N	\N	\N	\N
352	351	\N	\N	\N	\N	\N	\N	\N
353	352	\N	\N	\N	\N	\N	\N	\N
354	353	\N	\N	\N	\N	\N	\N	\N
355	354	\N	\N	\N	\N	\N	\N	\N
356	355	\N	\N	\N	\N	\N	\N	\N
357	356	\N	\N	\N	\N	\N	\N	\N
358	357	\N	\N	\N	\N	\N	\N	\N
359	358	\N	\N	\N	\N	\N	\N	\N
360	359	\N	\N	\N	\N	\N	\N	\N
361	360	\N	\N	\N	\N	\N	\N	\N
362	361	\N	\N	\N	\N	\N	\N	\N
363	362	\N	\N	\N	\N	\N	\N	\N
364	363	\N	\N	\N	\N	\N	\N	\N
365	364	\N	\N	\N	\N	\N	\N	\N
366	365	\N	\N	\N	\N	\N	\N	\N
367	366	\N	\N	\N	\N	\N	\N	\N
368	367	\N	\N	\N	\N	\N	\N	\N
369	368	\N	\N	\N	\N	\N	\N	\N
370	369	\N	\N	\N	\N	\N	\N	\N
371	370	\N	\N	\N	\N	\N	\N	\N
372	371	\N	\N	\N	\N	\N	\N	\N
373	372	\N	\N	\N	\N	\N	\N	\N
374	373	\N	\N	\N	\N	\N	\N	\N
375	374	\N	\N	\N	\N	\N	\N	\N
376	375	\N	\N	\N	\N	\N	\N	\N
377	376	\N	\N	\N	\N	\N	\N	\N
378	377	\N	\N	\N	\N	\N	\N	\N
379	378	\N	\N	\N	\N	\N	\N	\N
380	379	\N	\N	\N	\N	\N	\N	\N
381	380	\N	\N	\N	\N	\N	\N	\N
382	381	\N	\N	\N	\N	\N	\N	\N
383	382	\N	\N	\N	\N	\N	\N	\N
384	383	\N	\N	\N	\N	\N	\N	\N
385	384	\N	\N	\N	\N	\N	\N	\N
386	385	\N	\N	\N	\N	\N	\N	\N
387	386	\N	\N	\N	\N	\N	\N	\N
388	387	\N	\N	\N	\N	\N	\N	\N
389	388	\N	\N	\N	\N	\N	\N	\N
390	389	\N	\N	\N	\N	\N	\N	\N
391	390	\N	\N	\N	\N	\N	\N	\N
392	391	\N	\N	\N	\N	\N	\N	\N
393	392	\N	\N	\N	\N	\N	\N	\N
394	393	\N	\N	\N	\N	\N	\N	\N
395	394	\N	\N	\N	\N	\N	\N	\N
396	395	\N	\N	\N	\N	\N	\N	\N
397	396	\N	\N	\N	\N	\N	\N	\N
398	397	\N	\N	\N	\N	\N	\N	\N
399	398	\N	\N	\N	\N	\N	\N	\N
400	399	\N	\N	\N	\N	\N	\N	\N
403	402	\N	\N	\N	\N	\N	\N	\N
404	403	\N	\N	\N	\N	\N	\N	\N
414	413	\N	\N	\N	\N	\N	\N	\N
401	400	\N	\N	\N	\N	\N	\N	\N
402	401	\N	\N	\N	\N	\N	\N	\N
405	404	\N	\N	\N	\N	\N	\N	\N
406	405	\N	\N	\N	\N	\N	\N	\N
407	406	\N	\N	\N	\N	\N	\N	\N
408	407	\N	\N	\N	\N	\N	\N	\N
409	408	\N	\N	\N	\N	\N	\N	\N
410	409	\N	\N	\N	\N	\N	\N	\N
411	410	\N	\N	\N	\N	\N	\N	\N
412	411	\N	\N	\N	\N	\N	\N	\N
413	412	\N	\N	\N	\N	\N	\N	\N
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
1	101528634667963766790697738438344942387722756582531456051441109482660027582
\.


--
-- Data for Name: zkapp_verification_keys; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.zkapp_verification_keys (id, verification_key, hash_id) FROM stdin;
1	AAAxHIvaXF+vRj2/+pyAfE6U29d1K5GmGbhiKR9lTC6LJ2o1ygGxXERl1oQh6DBxf/hDUD0HOeg/JajCp3V6b5wytil2mfx8v2DB5RuNQ7VxJWkha0TSnJJsOl0FxhjldBbOY3tUZzZxHpPhHOKHz/ZAXRYFIsf2x+7boXC0iPurETHN7j5IevHIgf2fSW8WgHZYn83hpVI33LBdN1pIbUc7oWAUQVmmgp04jRqTCYK1oNg+Y9DeIuT4EVbp/yN7eS7Ay8ahic2sSAZvtn08MdRyk/jm2cLlJbeAAad6Xyz/H9l7JrkbVwDMMPxvHVHs27tNoJCzIlrRzB7pg3ju9aQOu4h3thDr+WSgFQWKvcRPeL7f3TFjIr8WZ2457RgMcTwXwORKbqJCcyKVNOE+FlNwVkOKER+WIpC0OlgGuayPFwQQkbb91jaRlJvahfwkbF2+AJmDnavmNpop9T+/Xak1adXIrsRPeOjC+qIKxIbGimoMOoYzYlevKA80LnJ7HC0IxR+yNLvoSYxDDPNRD+OCCxk5lM2h8IDUiCNWH4FZNJ+doiigKjyZlu/xZ7jHcX7qibu/32KFTX85DPSkQM8dABl309Ne9XzDAjA7rvef7vicw7KNgt56kWcEUki0o3M1yfbB8UxOSuOP07pw5+vrNHINMmJAuEKtNPwa5HvXBA4KR89XcqLS/NP7lwCEej/L8q8R7sKGMCXmgFYluWH4JBSPDgvMxScfjFS33oBNb7po8cLnAORzohXoYTSgztklD0mKn6EegLbkLtwwr9ObsLz3m7fp/3wkNWFRkY5xzSZN1VybbQbmpyQNCpxd/kdDsvlszqlowkyC8HnKbhnvE0Mrz3ZIk4vSs/UGBSXAoESFCFCPcTq11TCOhE5rumMJErv5LusDHJgrBtQUMibLU9A1YbF7SPDAR2QZd0yx3wZoHstfG3lbbtZcnaUabgu8tRdZiwRfX+rV+EBDCClOIpZn5V2SIpPpehhCpEBgDKUT0y2dgMO53Wc7OBDUFfkNX+JGhhD4fuA7IGFdIdthrwcbckBm0CBsRcVLlp+qlQ7a7ryGkxT8Bm3kEjVuRCYk6CbAfdT5lbKbQ7xYK4E2PfzQ2lMDwwuxRP+K2iQgP8UoGIBiUYI0lRvphhDkbCweEg0Owjz1pTUF/uiiMyVPsAyeoyh5fvmUgaNBkf5Hjh0xOGUbSHzawovjubcH7qWjIZoghZJ16QB1c0ryiAfHB48OHhs2p/JZWz8Dp7kfcPkeg2Of2NbupJlNVMLIH4IGWaPAscBRkZ+F4oLqOhJ5as7fAzzU8PQdeZi0YgssGDJVmNEHP61I16KZNcxQqR0EUVwhyMmYmpVjvtfhHi/6IxY/aPPEtcmsYEuy/JUaIuM0ZvnPNyB2E2Ckec+wJmooYjWXxYrXimjXWgv3IUGOiLDuQ0uGmrG5Bk+gyhZ5bhlVmlVsP8zA+xuHylyiww/Lercce7cq0YA5PtYS3ge9IDYwXckBUXb5ikD3alrrv5mvMu6itB7ix2f8lbiF9Fkmc4Bk2ycIWXJDCuBN+2sTFqzUeoT6xY8XWaOcnDvqOgSm/CCSv38umiOE2jEpsKYxhRc6W70UJkrzd3hr2DiSF1I2B+krpUVK1GeOdCLC5sl7YPzk+pF8183uI9wse6UTlqIiroKqsggzLBy/IjAfxS0BxFy5zywXqp+NogFkoTEJmR5MaqOkPfap+OsD1lGScY6+X4WW/HqCWrmA3ZTqDGngQMTGXLCtl6IS/cQpihS1NRbNqOtKTaCB9COQu0oz6RivBlywuaj3MKUdmbQ2gVDj+SGQItCNaXawyPSBjB9VT+68SoJVySQsYPCuEZCb0V/40n/a7RAbyrnNjP+2HwD7p27Pl1RSzqq35xiPdnycD1UeEPLpx/ON65mYCkn+KLQZmkqPio+vA2KmJngWTx+ol4rVFimGm76VT0xCFDsu2K0YX0yoLNH4u2XfmT9NR8gGfkVRCnnNjlbgHQmEwC75+GmEJ5DjD3d+s6IXTQ60MHvxbTHHlnfmPbgKn2SAI0uVoewKC9GyK6dSaboLw3C48jl0E2kyc+7umhCk3kEeWmt//GSjRNhoq+B+mynXiOtgFs/Am2v1TBjSb+6tcijsf5tFJmeGxlCjJnTdNWBkSHpMoo6OFkkpA6/FBAUHLSM7Yv8oYyd0GtwF5cCwQ6aRTbl9oG/mUn5Q92OnDMQcUjpgEho0Dcp2OqZyyxqQSPrbIIZZQrS2HkxBgjcfcSTuSHo7ONqlRjLUpO5yS95VLGXBLLHuCiIMGT+DW6DoJRtRIS+JieVWBoX0YsWgYInXrVlWUv6gDng5AyVFkUIFwZk7/3mVAgvXO83ArVKA4S747jT60w5bgV4Jy55slDM=	1
\.


--
-- Name: account_identifiers_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.account_identifiers_id_seq', 243, true);


--
-- Name: blocks_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.blocks_id_seq', 208, true);


--
-- Name: epoch_data_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.epoch_data_id_seq', 209, true);


--
-- Name: internal_commands_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.internal_commands_id_seq', 122, true);


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

SELECT pg_catalog.setval('public.user_commands_id_seq', 435, true);


--
-- Name: voting_for_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.voting_for_id_seq', 1, true);


--
-- Name: zkapp_account_precondition_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_account_precondition_id_seq', 415, true);


--
-- Name: zkapp_account_update_body_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_account_update_body_id_seq', 828, true);


--
-- Name: zkapp_account_update_failures_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_account_update_failures_id_seq', 4, true);


--
-- Name: zkapp_account_update_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_account_update_id_seq', 828, true);


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

SELECT pg_catalog.setval('public.zkapp_commands_id_seq', 826, true);


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

SELECT pg_catalog.setval('public.zkapp_fee_payer_body_id_seq', 826, true);


--
-- Name: zkapp_field_array_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_field_array_id_seq', 1, false);


--
-- Name: zkapp_field_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_field_id_seq', 412, true);


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

SELECT pg_catalog.setval('public.zkapp_nonce_bounds_id_seq', 414, true);


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

SELECT pg_catalog.setval('public.zkapp_states_nullable_id_seq', 413, true);


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

SELECT pg_catalog.setval('public.zkapp_updates_id_seq', 414, true);


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

