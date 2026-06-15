--
-- PostgreSQL database dump
--

-- Dumped from database version 16.8
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
109	76	1
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
211	212	1
212	213	1
213	214	1
214	215	1
215	216	1
216	217	1
217	218	1
218	219	1
219	220	1
220	221	1
221	222	1
222	223	1
223	224	1
224	225	1
225	226	1
226	227	1
227	228	1
228	229	1
229	230	1
230	231	1
231	232	1
232	233	1
233	234	1
234	235	1
235	236	1
236	237	1
237	238	1
238	239	1
239	240	1
240	241	1
241	242	1
242	243	1
243	244	1
244	245	1
\.


--
-- Data for Name: accounts_accessed; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.accounts_accessed (ledger_index, block_id, account_identifier_id, token_symbol_id, balance, nonce, receipt_chain_hash, delegate_id, voting_for_id, timing_id, permissions_id, zkapp_id) FROM stdin;
8	1	1	1	285	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	2	1	1	1	\N
105	1	2	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	3	1	2	1	\N
79	1	3	1	331	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	4	1	3	1	\N
30	1	4	1	226	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	5	1	4	1	\N
10	1	5	1	123	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	6	1	5	1	\N
76	1	6	1	292	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	7	1	6	1	\N
119	1	7	1	104	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	8	1	7	1	\N
174	1	8	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	9	1	8	1	\N
234	1	9	1	488	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	10	1	9	1	\N
224	1	10	1	469	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	11	1	10	1	\N
17	1	11	1	242	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	12	1	11	1	\N
126	1	12	1	135	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	13	1	12	1	\N
92	1	13	1	196	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	14	1	13	1	\N
151	1	14	1	79	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	15	1	14	1	\N
164	1	15	1	206	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	16	1	15	1	\N
135	1	16	1	340	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	17	1	16	1	\N
103	1	17	1	382	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	18	1	17	1	\N
68	1	18	1	488	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	19	1	18	1	\N
25	1	19	1	135	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	20	1	19	1	\N
44	1	20	1	126	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	21	1	20	1	\N
41	1	21	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	22	1	21	1	\N
115	1	22	1	278	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	23	1	22	1	\N
202	1	23	1	46	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	24	1	23	1	\N
185	1	24	1	104	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	25	1	24	1	\N
70	1	25	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	26	1	25	1	\N
214	1	26	1	271	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	27	1	26	1	\N
208	1	27	1	315	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	27	1	\N
77	1	28	1	162	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	29	1	28	1	\N
165	1	29	1	86	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	30	1	29	1	\N
179	1	30	1	409	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	31	1	30	1	\N
154	1	31	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	32	1	31	1	\N
94	1	32	1	57	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	33	1	32	1	\N
189	1	33	1	204	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	34	1	33	1	\N
130	1	34	1	262	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	35	1	34	1	\N
109	1	35	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	36	1	35	1	\N
169	1	36	1	156	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	37	1	36	1	\N
62	1	37	1	417	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	38	1	37	1	\N
66	1	38	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	39	1	38	1	\N
49	1	39	1	85	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	40	1	39	1	\N
225	1	40	1	103	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	41	1	40	1	\N
139	1	41	1	67	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	42	1	41	1	\N
40	1	42	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	43	1	42	1	\N
131	1	43	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	44	1	43	1	\N
80	1	44	1	198	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	45	1	44	1	\N
93	1	45	1	489	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	46	1	45	1	\N
186	1	46	1	298	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	47	1	46	1	\N
28	1	47	1	36	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	48	1	47	1	\N
88	1	48	1	334	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	49	1	48	1	\N
12	1	49	1	344	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	50	1	49	1	\N
33	1	50	1	451	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	51	1	50	1	\N
83	1	51	1	371	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	52	1	51	1	\N
125	1	52	1	234	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	53	1	52	1	\N
220	1	53	1	345	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	54	1	53	1	\N
74	1	54	1	282	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	55	1	54	1	\N
229	1	55	1	339	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	56	1	55	1	\N
6	1	56	1	499000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
13	1	57	1	215	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	58	1	57	1	\N
241	1	58	1	131	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	59	1	58	1	\N
218	1	59	1	193	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	60	1	59	1	\N
14	1	60	1	60	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	61	1	60	1	\N
56	1	61	1	350	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	62	1	61	1	\N
144	1	62	1	223	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	63	1	62	1	\N
60	1	63	1	449	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	64	1	63	1	\N
183	1	64	1	142	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	65	1	64	1	\N
149	1	65	1	300	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	66	1	65	1	\N
163	1	66	1	256	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	67	1	66	1	\N
101	1	67	1	125	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	68	1	67	1	\N
39	1	68	1	236	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	69	1	68	1	\N
237	1	69	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	70	1	69	1	\N
108	1	70	1	179	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	71	1	70	1	\N
11	1	71	1	194	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	72	1	71	1	\N
24	1	72	1	185	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	73	1	72	1	\N
96	1	73	1	342	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	74	1	73	1	\N
1	1	74	1	65500000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	76	1	74	1	\N
213	1	75	1	157	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	77	1	75	1	\N
89	1	76	1	135	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	78	1	76	1	\N
157	1	77	1	456	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	79	1	77	1	\N
206	1	78	1	336	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	80	1	78	1	\N
205	1	79	1	280	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	81	1	79	1	\N
180	1	80	1	187	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	82	1	80	1	\N
155	1	81	1	387	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	83	1	81	1	\N
31	1	82	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	84	1	82	1	\N
199	1	83	1	151	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	85	1	83	1	\N
7	1	84	1	202	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	86	1	84	1	\N
232	1	85	1	24	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	87	1	85	1	\N
38	1	86	1	152	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	88	1	86	1	\N
16	1	87	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	89	1	87	1	\N
227	1	88	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	90	1	88	1	\N
18	1	89	1	186	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	91	1	89	1	\N
182	1	90	1	266	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	92	1	90	1	\N
137	1	91	1	81	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	93	1	91	1	\N
162	1	92	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	94	1	92	1	\N
197	1	93	1	379	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	95	1	93	1	\N
107	1	94	1	315	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	96	1	94	1	\N
45	1	95	1	226	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	97	1	95	1	\N
212	1	96	1	166	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	98	1	96	1	\N
110	1	97	1	302	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	99	1	97	1	\N
142	1	98	1	269	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	100	1	98	1	\N
176	1	99	1	172	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	101	1	99	1	\N
153	1	100	1	195	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	102	1	100	1	\N
36	1	101	1	243	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	103	1	101	1	\N
78	1	102	1	128	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	104	1	102	1	\N
145	1	103	1	349	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	105	1	103	1	\N
22	1	104	1	87	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	106	1	104	1	\N
124	1	105	1	424	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	107	1	105	1	\N
87	1	106	1	239	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	108	1	106	1	\N
133	1	107	1	316	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	109	1	107	1	\N
192	1	108	1	492	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	110	1	108	1	\N
2	1	109	1	500000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	76	1	109	1	\N
188	1	110	1	294	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	111	1	110	1	\N
216	1	111	1	191	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	112	1	111	1	\N
91	1	112	1	380	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	113	1	112	1	\N
160	1	113	1	331	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	114	1	113	1	\N
219	1	114	1	459	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	115	1	114	1	\N
203	1	115	1	28	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	116	1	115	1	\N
193	1	116	1	472	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	117	1	116	1	\N
32	1	117	1	119	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	118	1	117	1	\N
211	1	118	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	119	1	118	1	\N
194	1	119	1	41	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	120	1	119	1	\N
102	1	120	1	27	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	121	1	120	1	\N
42	1	121	1	70	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	122	1	121	1	\N
50	1	122	1	337	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	123	1	122	1	\N
112	1	123	1	210	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	124	1	123	1	\N
175	1	124	1	495	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	125	1	124	1	\N
146	1	125	1	144	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	126	1	125	1	\N
98	1	126	1	148	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	127	1	126	1	\N
204	1	127	1	376	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	128	1	127	1	\N
26	1	128	1	329	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	129	1	128	1	\N
171	1	129	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	130	1	129	1	\N
128	1	130	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	131	1	130	1	\N
4	1	131	1	499000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
37	1	132	1	181	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	133	1	132	1	\N
210	1	133	1	200	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	134	1	133	1	\N
114	1	134	1	159	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	135	1	134	1	\N
46	1	135	1	319	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	136	1	135	1	\N
99	1	136	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	137	1	136	1	\N
201	1	137	1	365	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	138	1	137	1	\N
48	1	138	1	342	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	139	1	138	1	\N
57	1	139	1	237	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	140	1	139	1	\N
148	1	140	1	427	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	141	1	140	1	\N
178	1	141	1	315	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	142	1	141	1	\N
140	1	142	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	143	1	142	1	\N
21	1	143	1	378	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	144	1	143	1	\N
120	1	144	1	420	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	145	1	144	1	\N
113	1	145	1	411	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	146	1	145	1	\N
5	1	146	1	11550000000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	146	1	\N
73	1	147	1	172	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	148	1	147	1	\N
75	1	148	1	309	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	149	1	148	1	\N
150	1	149	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	150	1	149	1	\N
118	1	150	1	154	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	151	1	150	1	\N
116	1	151	1	153	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	152	1	151	1	\N
35	1	152	1	47	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	153	1	152	1	\N
166	1	153	1	87	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	154	1	153	1	\N
147	1	154	1	398	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	155	1	154	1	\N
27	1	155	1	452	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	156	1	155	1	\N
86	1	156	1	291	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	157	1	156	1	\N
231	1	157	1	367	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	158	1	157	1	\N
81	1	158	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	159	1	158	1	\N
152	1	159	1	311	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	160	1	159	1	\N
173	1	160	1	258	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	161	1	160	1	\N
67	1	161	1	323	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	162	1	161	1	\N
61	1	162	1	405	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	163	1	162	1	\N
187	1	163	1	32	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	164	1	163	1	\N
90	1	164	1	130	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	165	1	164	1	\N
138	1	165	1	234	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	166	1	165	1	\N
15	1	166	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	167	1	166	1	\N
85	1	167	1	481	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	167	1	\N
181	1	168	1	240	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	169	1	168	1	\N
127	1	169	1	314	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	170	1	169	1	\N
191	1	170	1	183	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	171	1	170	1	\N
172	1	171	1	486	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	172	1	171	1	\N
55	1	172	1	178	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	173	1	172	1	\N
222	1	173	1	65	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	174	1	173	1	\N
230	1	174	1	277	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	175	1	174	1	\N
117	1	175	1	433	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	176	1	175	1	\N
53	1	176	1	100	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	177	1	176	1	\N
167	1	177	1	272	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	178	1	177	1	\N
123	1	178	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	179	1	178	1	\N
43	1	179	1	212	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	180	1	179	1	\N
58	1	180	1	151	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	181	1	180	1	\N
97	1	181	1	387	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	182	1	181	1	\N
177	1	182	1	158	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	183	1	182	1	\N
47	1	183	1	440	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	184	1	183	1	\N
228	1	184	1	438	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	185	1	184	1	\N
129	1	185	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	186	1	185	1	\N
184	1	186	1	290	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	187	1	186	1	\N
196	1	187	1	417	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	188	1	187	1	\N
200	1	188	1	375	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	189	1	188	1	\N
20	1	189	1	178	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	190	1	189	1	\N
100	1	190	1	59	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	191	1	190	1	\N
122	1	191	1	95	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	192	1	191	1	\N
198	1	192	1	394	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	193	1	192	1	\N
240	1	193	1	486	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	194	1	193	1	\N
52	1	194	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	195	1	194	1	\N
223	1	195	1	256	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	196	1	195	1	\N
132	1	196	1	128	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	197	1	196	1	\N
95	1	197	1	199	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	198	1	197	1	\N
82	1	198	1	22	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	199	1	198	1	\N
159	1	199	1	276	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	200	1	199	1	\N
226	1	200	1	451	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	201	1	200	1	\N
236	1	201	1	133	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	202	1	201	1	\N
63	1	202	1	460	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	203	1	202	1	\N
217	1	203	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	204	1	203	1	\N
54	1	204	1	489	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	205	1	204	1	\N
161	1	205	1	190	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	206	1	205	1	\N
190	1	206	1	221	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	207	1	206	1	\N
141	1	207	1	464	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	208	1	207	1	\N
59	1	208	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	209	1	208	1	\N
134	1	209	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	210	1	209	1	\N
69	1	210	1	353	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	211	1	210	1	\N
143	1	211	1	396	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	212	1	211	1	\N
104	1	212	1	417	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	213	1	212	1	\N
136	1	213	1	46	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	214	1	213	1	\N
156	1	214	1	305	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	215	1	214	1	\N
121	1	215	1	337	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	216	1	215	1	\N
23	1	216	1	444	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	217	1	216	1	\N
238	1	217	1	479	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	218	1	217	1	\N
209	1	218	1	344	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	219	1	218	1	\N
239	1	219	1	113	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	220	1	219	1	\N
195	1	220	1	236	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	221	1	220	1	\N
168	1	221	1	480	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	222	1	221	1	\N
29	1	222	1	160	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	223	1	222	1	\N
3	1	223	1	11550000000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	223	1	\N
158	1	224	1	318	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	225	1	224	1	\N
19	1	225	1	214	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	226	1	225	1	\N
242	1	226	1	22	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	227	1	226	1	\N
65	1	227	1	163	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	228	1	227	1	\N
64	1	228	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	229	1	228	1	\N
106	1	229	1	366	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	230	1	229	1	\N
84	1	230	1	320	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	231	1	230	1	\N
235	1	231	1	407	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	232	1	231	1	\N
72	1	232	1	204	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	233	1	232	1	\N
71	1	233	1	341	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	234	1	233	1	\N
215	1	234	1	18	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	235	1	234	1	\N
0	1	235	1	5000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
34	1	236	1	229	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	237	1	236	1	\N
170	1	237	1	477	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	238	1	237	1	\N
51	1	238	1	94	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	239	1	238	1	\N
233	1	239	1	126	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	240	1	239	1	\N
111	1	240	1	112	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	241	1	240	1	\N
221	1	241	1	387	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	242	1	241	1	\N
207	1	242	1	265	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	243	1	242	1	\N
9	1	243	1	269	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	244	1	243	1	\N
6	2	56	1	859000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
4	3	131	1	859000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
6	4	56	1	1219000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
4	5	131	1	1219000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
4	6	131	1	1584000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
3	6	223	1	11549995000000000	1	2n2LHYQC7SoWzJ72EfCdJ86uqiEmQgx5gMyixotbJ8P8mQMxjzA1	132	1	223	1	\N
6	7	56	1	1219000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
6	8	56	1	1579000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
4	9	131	1	1944000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
6	10	56	1	1579250000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
2	10	109	1	499750000000	1	2n21BwtsL5SDfWbbpj1Euc7xWn5dc41rnghxBdL99jy4pakF2X9a	76	1	109	1	\N
2	11	109	1	499500000000	2	2n2P9HjpXi4sWpTSJLJA4YqqyotnpjETMN55FJfe3qwC835Sq2Ht	76	1	109	1	\N
4	11	131	1	2304250000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
6	12	56	1	1944249000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
3	12	223	1	11549990000000000	2	2n2EgduUfh6UyA6zhZEBKr3RDZ9fNVfRdDZiQ6hPohALjTWJHoAG	132	1	223	1	\N
0	12	235	1	5001000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
6	13	56	1	2309246000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
3	13	223	1	11549985000000000	3	2mzhxFzJR7gtsAf9gY818xyNrSwck2dEa1eLRpT1v1UhEXzNtcRQ	132	1	223	1	\N
0	13	235	1	5004000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
2	14	109	1	499250000000	3	2n1BuVDMNzKf2DFJU5mYztCWBFMWNdTNs7664fteEYtmVSrRbHbH	76	1	109	1	\N
4	14	131	1	2669500000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
3	14	223	1	11549980000000000	4	2n2H1AgFjGVwU4fwx9nSBdjWABzSeofsvUoF4Hm5mJ68wA6K1EyR	132	1	223	1	\N
6	15	56	1	2674492000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
2	15	109	1	499000000000	4	2n1bsizpfMGoG3vu5xgTEPosCnQr8NuP8Wx6W1bSbvVmUWMHxaqV	76	1	109	1	\N
3	15	223	1	11549975000000000	5	2n11FffH96WyentsRp3GTUeXRyxx8YywydDKwpkrrRfF4TErR7s1	132	1	223	1	\N
0	15	235	1	5008000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
6	16	56	1	3039492000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
3	16	223	1	11549970000000000	6	2n2MuhDMjpYc8cKwFNDd7JBXobNRNrncxfgYubGpzyQFRTu43Gvd	132	1	223	1	\N
6	17	56	1	3399492000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
2	18	109	1	498750000000	5	2n1DF4ZVciCfo71R4f4N7bk17PA9vbwvRME7ZwzcYVZEa9oie1mn	76	1	109	1	\N
4	18	131	1	3044744000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
3	18	223	1	11549955000000000	9	2n1VfjZdSBvE98hk9RqdNTVEMDuLuv1ZCsvEXcMoMmoMq8LV8aGe	132	1	223	1	\N
0	18	235	1	5014000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
6	19	56	1	3759741000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
2	19	109	1	498500000000	6	2n1H2qwzFGcta6Agt2NL2GszLGscFg55qy4MVSfauG7KY95tqK19	76	1	109	1	\N
0	19	235	1	5015000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
4	20	131	1	3409739000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
3	20	223	1	11549950000000000	10	2n1MLYKS2eNem3tMLE4jtVfvDSRFMTATv4z6VzTr8eEpHYGx2Wh4	132	1	223	1	\N
0	20	235	1	5020000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
4	21	131	1	3774739000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
3	21	223	1	11549945000000000	11	2n1CG2rbxjgZSYJtamJGt8yCRa2z6gJztXdLEe8CjsDcfgLavein	132	1	223	1	\N
6	22	56	1	4124741000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
3	22	223	1	11549945000000000	11	2n1CG2rbxjgZSYJtamJGt8yCRa2z6gJztXdLEe8CjsDcfgLavein	132	1	223	1	\N
4	23	131	1	3769739000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
2	24	109	1	498250000000	7	2mzs7reAC9mjYAhvMjvpfk61JwSRGJ9gm2zc7RYjHwMiC5rAbHQZ	76	1	109	1	\N
4	24	131	1	4139982000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
3	24	223	1	11549935000000000	13	2n2CQ4nbSXY2zZ5gtfHjhUqXwmQJsaUzbZgxNSPPErdVV9JggdCt	132	1	223	1	\N
0	24	235	1	5027000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
2	25	109	1	498000000000	8	2n2FUXxreYhPtScdpGydWxVpyB4zmjdfqUUTHE6LHmMrJQfsoXUw	76	1	109	1	\N
4	25	131	1	4500232000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
4	26	131	1	4865225000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
3	26	223	1	11549930000000000	14	2mzyRjt9562LdpSnybdAZaERvLjEUXgzhh7JtXSicZmZ9VvY1Pk2	132	1	223	1	\N
0	26	235	1	5034000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
6	27	56	1	4489734000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
3	27	223	1	11549930000000000	14	2mzyRjt9562LdpSnybdAZaERvLjEUXgzhh7JtXSicZmZ9VvY1Pk2	132	1	223	1	\N
0	27	235	1	5034000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
4	28	131	1	5230225000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
3	28	223	1	11549925000000000	15	2n1MTF359v7VZJBemoEm5fXCoTjVmBa4hnhtQjWuTEP4QZz8z8Nh	132	1	223	1	\N
2	29	109	1	497750000000	9	2n1sr922iLEi3hf3CZbyLPoFuYiJeAgEjf1hWjmv2aEZo1Dt6rUC	76	1	109	1	\N
4	29	131	1	5590474000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
0	29	235	1	5035000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
6	30	56	1	4484990000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
2	30	109	1	497750000000	9	2n1sr922iLEi3hf3CZbyLPoFuYiJeAgEjf1hWjmv2aEZo1Dt6rUC	76	1	109	1	\N
0	30	235	1	5035000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
4	31	131	1	5955467000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
3	31	223	1	11549920000000000	16	2n292Gco47Cs5gE6rKfxszay3Z9tP1PRjZLLBCSrMk1xTCELitms	132	1	223	1	\N
0	31	235	1	5042000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
6	32	56	1	4489734000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
3	32	223	1	11549920000000000	16	2n292Gco47Cs5gE6rKfxszay3Z9tP1PRjZLLBCSrMk1xTCELitms	132	1	223	1	\N
0	32	235	1	5042000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
6	33	56	1	4494990000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
2	33	109	1	497500000000	10	2n13YZNMuEEXzhb72AFrFG7Zjiubzz2Eu63yJ1B5VrvczfNyT65W	76	1	109	1	\N
3	33	223	1	11549910000000000	18	2n1pu9AfR1Qk5WDeZxMDMDuEReSJF3aiWB8u2XWGn5ivGEgkQBUg	132	1	223	1	\N
0	33	235	1	5043000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
2	34	109	1	497500000000	10	2n13YZNMuEEXzhb72AFrFG7Zjiubzz2Eu63yJ1B5VrvczfNyT65W	76	1	109	1	\N
4	34	131	1	6325716000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
3	34	223	1	11549910000000000	18	2n1pu9AfR1Qk5WDeZxMDMDuEReSJF3aiWB8u2XWGn5ivGEgkQBUg	132	1	223	1	\N
0	34	235	1	5043000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
6	35	56	1	4870233000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
2	35	109	1	497250000000	11	2n1meDbo49poNHLygCiPxALBemLJYKELUcmDNgT5t7SEyGopxXru	76	1	109	1	\N
3	35	223	1	11549895000000000	21	2n1QQhzvpdzwaYy6hABJyScHXWxG1vceeBjCAz6kyi9TGVdCeWWz	132	1	223	1	\N
0	35	235	1	5050000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
4	36	131	1	6315467000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
6	37	56	1	5230233000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
6	38	56	1	5235475000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
2	38	109	1	497000000000	12	2mztjgaNGh1ENXVv8fwUdJGWmvdyi9rVMiBbG9D4YGZsaRSuvuFb	76	1	109	1	\N
3	38	223	1	11549890000000000	22	2n1tsGZfUcpatQAhVUg9jiHrrSwktS58PWnJmJ35E9qKmKrtGYrG	132	1	223	1	\N
0	38	235	1	5058000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
4	39	131	1	6680467000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
3	39	223	1	11549885000000000	23	2n2DPGMQ5y15Z72BAHMAHr9whRxuVD5yNBrKXduzR2muwT3UA9tg	132	1	223	1	\N
6	40	56	1	5595475000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
4	41	131	1	7040467000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
2	42	109	1	496750000000	13	2mzbXqMqqmb9QKz3MUb77tQQ7YhmGqNNQqxcb9xSABezj861n3cj	76	1	109	1	\N
4	42	131	1	7405709000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
3	42	223	1	11549880000000000	24	2n1CW9bS1h3rZM4AS8DXwQTLTugjStVvqNwXW4XGJzPsU5NvAWaC	132	1	223	1	\N
0	42	235	1	5066000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
6	43	56	1	5600717000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
2	43	109	1	496750000000	13	2mzbXqMqqmb9QKz3MUb77tQQ7YhmGqNNQqxcb9xSABezj861n3cj	76	1	109	1	\N
3	43	223	1	11549880000000000	24	2n1CW9bS1h3rZM4AS8DXwQTLTugjStVvqNwXW4XGJzPsU5NvAWaC	132	1	223	1	\N
0	43	235	1	5066000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
4	44	131	1	7405467000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
3	44	223	1	11549875000000000	25	2n1GtNi9aV6ZsHk1G3TiAzRrB6Lf4kZSYFCJy2Vm3thdQeTcCyBZ	132	1	223	1	\N
6	45	56	1	5965717000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
3	45	223	1	11549875000000000	25	2n1GtNi9aV6ZsHk1G3TiAzRrB6Lf4kZSYFCJy2Vm3thdQeTcCyBZ	132	1	223	1	\N
4	46	131	1	7400467000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
6	47	56	1	6330959000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
2	47	109	1	496500000000	14	2mzyBH59jzKxCkWVsqFNQNhWXUxkNasWteYTGJQdLAM7s3t6PX6L	76	1	109	1	\N
3	47	223	1	11549870000000000	26	2n1eMw5BacsZAgg7Qd48RJtrnBpka7fqFE2dWm6EDyUKQE8ZWtMg	132	1	223	1	\N
0	47	235	1	5074000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
6	48	56	1	6695959000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
3	48	223	1	11549865000000000	27	2n29bYvbf8EGaUydg3AQ5d9C6LPHXXBuN1sfL92hDAYaeYiaAGmY	132	1	223	1	\N
6	49	56	1	7055959000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
2	50	109	1	496250000000	15	2n1jWiy3GyBZ1HzPfcXA66fKtGfELkQ1Sw9UTBSkzzLML7D9B1GC	76	1	109	1	\N
4	50	131	1	7765709000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
3	50	223	1	11549860000000000	28	2n1PeyDmECczKihPbRroGNczEyg9hAtwQM9GB7b13j7qQtvX3Zu9	132	1	223	1	\N
0	50	235	1	5082000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
6	51	56	1	7421201000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
2	51	109	1	496250000000	15	2n1jWiy3GyBZ1HzPfcXA66fKtGfELkQ1Sw9UTBSkzzLML7D9B1GC	76	1	109	1	\N
3	51	223	1	11549860000000000	28	2n1PeyDmECczKihPbRroGNczEyg9hAtwQM9GB7b13j7qQtvX3Zu9	132	1	223	1	\N
0	51	235	1	5082000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
6	52	56	1	7420959000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
3	52	223	1	11549855000000000	29	2n1DC5VaA2K6wrCdTuFCFow1J68PTKpL9fyY4RkkVxW4KJDTNmbP	132	1	223	1	\N
4	53	131	1	8125709000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
6	54	56	1	7780959000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
2	55	109	1	496000000000	16	2n1MXEsFsf8nqjXuWyZNi7xnVZ66wxRLvCeTRnttuLiEfwevpgHK	76	1	109	1	\N
4	55	131	1	8495951000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
3	55	223	1	11549845000000000	31	2n2G6QiPrjA7HHzsSxkBcMC6DbeunaetByfF6NM454EKCgrpFiFC	132	1	223	1	\N
0	55	235	1	5090000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
6	56	56	1	7786208000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
2	56	109	1	495750000000	17	2n1uyGscWRkJdh3hqhdMgZ4BVCMxS46XmZSN8BH4i6dQmGABWMdT	76	1	109	1	\N
3	56	223	1	11549840000000000	32	2mzu1PvKkLQiAAn3ARR1SgQaNwGv1HrVmLpGvED6eF2SbKCDX3Rk	132	1	223	1	\N
0	56	235	1	5091000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
6	57	56	1	8151201000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
3	57	223	1	11549835000000000	33	2n1MYLsxfzMNzdQsxmBwZeeFLsgrLjTgGwjy8BqcbsjbgCcsHHzH	132	1	223	1	\N
0	57	235	1	5098000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
2	58	109	1	495500000000	18	2mzh4Qz8mWhmQ7t85Ds8cU4nqptEpcPWkMjmG5ev2hsU2taoYMoN	76	1	109	1	\N
4	58	131	1	8861201000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
3	58	223	1	11549830000000000	34	2n1uxcBJLeJd1nJfji3rkMe5v8J7jEVcipAGp5eeQZgn8dQo3dTv	132	1	223	1	\N
6	59	56	1	8516193000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
3	59	223	1	11549825000000000	35	2n1jxJRc42Vf6G3jVXkPtZKt9QVyHLhpJkiS7CjaDNADmdWLnNTW	132	1	223	1	\N
0	59	235	1	5106000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
2	60	109	1	495250000000	19	2n2AJ1jGDysZc2LPQzisTr6nP4Fui2kmhaRhCm7WcVxALT1jh5jg	76	1	109	1	\N
4	60	131	1	9226451000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
3	60	223	1	11549820000000000	36	2n24LLredmfQVFhjhdTxciNpvBtTeFDWNKXae6quNe99TWTLZ8vQ	132	1	223	1	\N
4	61	131	1	9586451000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
2	62	109	1	495000000000	20	2n2RzCjzuiNA8DJabBT98xjpU21wikwboBHKQrQJo8NUGDoscZfD	76	1	109	1	\N
4	62	131	1	9951693000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
3	62	223	1	11549815000000000	37	2n1Wu9suqF7KbgsunRQAJKXfAuHuHYQdf9n2Gpt7z6iwxBjLWxxL	132	1	223	1	\N
0	62	235	1	5114000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
6	63	56	1	8881193000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
3	63	223	1	11549810000000000	38	2mzXmntC6ZYsFGABtCPvqEaz3d5WwdwpETVpJnVw3denj7RME76Y	132	1	223	1	\N
4	64	131	1	10316693000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
3	64	223	1	11549810000000000	38	2mzXmntC6ZYsFGABtCPvqEaz3d5WwdwpETVpJnVw3denj7RME76Y	132	1	223	1	\N
4	65	131	1	10676693000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
6	66	56	1	8876193000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
2	67	109	1	494750000000	21	2mziS6ikH6VpybxwbEWQxibaxNw6xrjJLhcnxJeKpv5JbCqzPfeY	76	1	109	1	\N
4	67	131	1	11041935000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
3	67	223	1	11549805000000000	39	2n21pUZuk4yyxmW9nhCZpoEADHpCLoGj9y8ecH6B7jgmV7iKrV5J	132	1	223	1	\N
0	67	235	1	5122000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
4	68	131	1	11406935000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
3	68	223	1	11549800000000000	40	2n21PG556vzVbQWVSbDHLCyT5Ari2ANkmUYeBrv43h4qc1bwsj8x	132	1	223	1	\N
4	69	131	1	11766935000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
6	70	56	1	8876193000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
6	71	56	1	8886435000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
2	71	109	1	494500000000	22	2mze3bTu13gst9oKCfsVnaBtvvg5MAuDd4i4BYhM18E4vukFWVHQ	76	1	109	1	\N
3	71	223	1	11549790000000000	42	2mzdZVYYAXdesF3VNDZhuCwH2khwVJjkMk5Et1AEWBMxf6SUyVuH	132	1	223	1	\N
0	71	235	1	5130000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
2	72	109	1	494500000000	22	2mze3bTu13gst9oKCfsVnaBtvvg5MAuDd4i4BYhM18E4vukFWVHQ	76	1	109	1	\N
4	72	131	1	12137177000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
3	72	223	1	11549790000000000	42	2mzdZVYYAXdesF3VNDZhuCwH2khwVJjkMk5Et1AEWBMxf6SUyVuH	132	1	223	1	\N
0	72	235	1	5130000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
2	73	109	1	494250000000	23	2n11QAqwWyHoaMdCdjM63rrchxDE6D8p4uQpbdyh628D7zJDk4WZ	76	1	109	1	\N
4	73	131	1	12137180000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
3	73	223	1	11549780000000000	44	2mzYzaGQkR1AbZSNVhfiCDdLajT94J3QEgSFZguHCHYXbQTz4qm3	132	1	223	1	\N
0	73	235	1	5135000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
6	74	56	1	9256680000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
2	74	109	1	494250000000	23	2n11QAqwWyHoaMdCdjM63rrchxDE6D8p4uQpbdyh628D7zJDk4WZ	76	1	109	1	\N
3	74	223	1	11549780000000000	44	2mzYzaGQkR1AbZSNVhfiCDdLajT94J3QEgSFZguHCHYXbQTz4qm3	132	1	223	1	\N
0	74	235	1	5135000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
6	75	56	1	9251432000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
3	75	223	1	11549775000000000	45	2mzkGvCRqvLJeyvEz2G8UYMBqwAR395q2AqVJ7jK98nyrtRHCkkD	132	1	223	1	\N
0	75	235	1	5138000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
6	76	56	1	9616676000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
2	76	109	1	494000000000	24	2n1pNt61FF7pytkedxCAC1hCgfNf3fGrYKnsfcpfwtUnuJZhvdm5	76	1	109	1	\N
3	76	223	1	11549770000000000	46	2n2Qn3Jyvp4psDQWoR7D3ofF5yNzxgUfUUNn734eP5ET5Jsh2gPA	132	1	223	1	\N
0	76	235	1	5144000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
2	77	109	1	494000000000	24	2n1pNt61FF7pytkedxCAC1hCgfNf3fGrYKnsfcpfwtUnuJZhvdm5	76	1	109	1	\N
4	77	131	1	12502424000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
3	77	223	1	11549770000000000	46	2n2Qn3Jyvp4psDQWoR7D3ofF5yNzxgUfUUNn734eP5ET5Jsh2gPA	132	1	223	1	\N
0	77	235	1	5144000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
6	78	56	1	9616680000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
2	78	109	1	493750000000	25	2mzzndZs7RHTBp1YJPXDd4e2PGEnXhRvBg48n7m9nbTDDHNyqU4D	76	1	109	1	\N
3	78	223	1	11549765000000000	47	2n1quh8McoiT4sPvLpRyUteuSi2Q1LuE4gaRUJbAwffQ2tFM1RyE	132	1	223	1	\N
0	78	235	1	5146000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
2	79	109	1	493750000000	25	2mzzndZs7RHTBp1YJPXDd4e2PGEnXhRvBg48n7m9nbTDDHNyqU4D	76	1	109	1	\N
4	79	131	1	12867672000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
3	79	223	1	11549765000000000	47	2n1quh8McoiT4sPvLpRyUteuSi2Q1LuE4gaRUJbAwffQ2tFM1RyE	132	1	223	1	\N
0	79	235	1	5146000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
6	80	56	1	9611432000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
4	81	131	1	13227672000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
6	82	56	1	9621424000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
3	82	223	1	11549755000000000	49	2n1d23E9FqJvLVfeCTEkdXWZj9gaTvFrHqzBy33w4UQAyKxLgSbP	132	1	223	1	\N
0	82	235	1	5154000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
2	83	109	1	493500000000	26	2mzmY4Xqcpkbjf4YJihgryJbKSSSoMN7MgjtDafuc84W9BfcaUih	76	1	109	1	\N
4	83	131	1	13587922000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
4	84	131	1	13947922000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
4	85	131	1	14317914000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
3	85	223	1	11549745000000000	51	2n1ikJ12MMnshUc4GGYdydDC2GzHscqrPq5Ew2DkbvKqACqxMg3a	132	1	223	1	\N
0	85	235	1	5162000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
6	86	56	1	9991416000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
3	86	223	1	11549745000000000	51	2n1ikJ12MMnshUc4GGYdydDC2GzHscqrPq5Ew2DkbvKqACqxMg3a	132	1	223	1	\N
0	86	235	1	5162000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
2	87	109	1	493250000000	27	2n2Bxim5W2iSwVoMRa5hbKvEWvPqDmad8q7N6HfHwiwN1oVuq1TY	76	1	109	1	\N
4	87	131	1	14308172000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
4	88	131	1	14668172000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
6	89	56	1	10361658000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
2	89	109	1	493000000000	28	2n13m4nQneEFwgYvpGP4LCs7NTQ3HJNKpnQcrpdo92k8JSU6D4j1	76	1	109	1	\N
3	89	223	1	11549735000000000	53	2n1ZudFqGa9emPDRYYWLCWHthB7jfYRwui4pAJFfZ1WM6eLCEP8j	132	1	223	1	\N
0	89	235	1	5170000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
2	90	109	1	493000000000	28	2n13m4nQneEFwgYvpGP4LCs7NTQ3HJNKpnQcrpdo92k8JSU6D4j1	76	1	109	1	\N
4	90	131	1	15038414000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
3	90	223	1	11549735000000000	53	2n1ZudFqGa9emPDRYYWLCWHthB7jfYRwui4pAJFfZ1WM6eLCEP8j	132	1	223	1	\N
0	90	235	1	5170000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
4	91	131	1	15038171000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
3	91	223	1	11549725000000000	55	2mzmGV928ZZhqheNqcoj73Tk2JxdLaoyNme7C6qFAezEVPinvvoE	132	1	223	1	\N
0	91	235	1	5171000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
6	92	56	1	10731901000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
2	92	109	1	492750000000	29	2n26XKtwysr5srMiB8cRAou9ihgKBesPiwa7Aj7dbMCVUegeJR2b	76	1	109	1	\N
3	92	223	1	11549715000000000	57	2n1x4vxWPSA5JgnSsDq4xiQnX6erpGj8i1eFAex8ybAkiRpwv5uc	132	1	223	1	\N
0	92	235	1	5178000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
2	93	109	1	492750000000	29	2n26XKtwysr5srMiB8cRAou9ihgKBesPiwa7Aj7dbMCVUegeJR2b	76	1	109	1	\N
4	93	131	1	15408414000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
3	93	223	1	11549715000000000	57	2n1x4vxWPSA5JgnSsDq4xiQnX6erpGj8i1eFAex8ybAkiRpwv5uc	132	1	223	1	\N
0	93	235	1	5178000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
2	94	109	1	492500000000	30	2n24oFZR3NjYSTwTLaszHpT7mU9DHkSg1v3L4rAH9cFJ92MZmfiF	76	1	109	1	\N
4	94	131	1	15773658000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
3	94	223	1	11549710000000000	58	2mzqgZ14ZhGAtrkUr1uTaJTwoXd1N1cdNvZswCjCouziaWyXR1nA	132	1	223	1	\N
0	94	235	1	5184000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
6	95	56	1	10726656000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
3	95	223	1	11549705000000000	59	2mzuXxsnKFexGQnKXNLKJ7di2A1qgosrkbfJd7JTBSFNLbcwUWYM	132	1	223	1	\N
0	95	235	1	5186000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
4	96	131	1	16138656000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
3	96	223	1	11549705000000000	59	2mzuXxsnKFexGQnKXNLKJ7di2A1qgosrkbfJd7JTBSFNLbcwUWYM	132	1	223	1	\N
0	96	235	1	5186000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
2	97	109	1	492250000000	31	2n1i7UdLeNBjzyf5LvhuTske9ZQVjgbxi2PVGSL1MjUv7xicv3rm	76	1	109	1	\N
4	97	131	1	16138902000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
3	97	223	1	11549700000000000	60	2n1mRwWyZcJHGxYDKMgXrb8f4vcAGPen7X5SXfmsSx8D3TgJDt2F	132	1	223	1	\N
0	97	235	1	5192000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
6	98	56	1	11091654000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
3	98	223	1	11549695000000000	61	2n2Gp5sbHEjZKzeikEjSM3quN4W2nwUYApCqQVx7tiqFzfAKJvyu	132	1	223	1	\N
0	98	235	1	5194000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
2	99	109	1	492000000000	32	2n1cqdmeSCx1iLzVVuJKVenoM1tiJ4oLv9D7HJKzYpxP4bvZzUE6	76	1	109	1	\N
4	99	131	1	16499151000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
0	99	235	1	5195000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
6	100	56	1	11451903000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
2	100	109	1	492000000000	32	2n1cqdmeSCx1iLzVVuJKVenoM1tiJ4oLv9D7HJKzYpxP4bvZzUE6	76	1	109	1	\N
0	100	235	1	5195000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
6	101	56	1	11816896000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
3	101	223	1	11549690000000000	62	2n1W1EnqUC178xtW7MMQA1rB4m3JyZAJ4KQre43xd2wR3vfJx5co	132	1	223	1	\N
0	101	235	1	5202000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
4	102	131	1	16503902000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
3	102	223	1	11549685000000000	63	2mzsz9P5PxcZZkMCkWF89SeBfBh2tG4roYdzGuy7sGdN4jmVtkBS	132	1	223	1	\N
6	103	56	1	12181896000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
3	103	223	1	11549685000000000	63	2mzsz9P5PxcZZkMCkWF89SeBfBh2tG4roYdzGuy7sGdN4jmVtkBS	132	1	223	1	\N
4	104	131	1	16863902000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
6	105	56	1	12187138000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
2	105	109	1	491750000000	33	2n1RoNxQh1k7T3vDT4hMNvyRfrj7C2RBQiDgmexA2uuynV6KN1Ja	76	1	109	1	\N
3	105	223	1	11549675000000000	65	2n1VDZKXYH36rS22SK2FiV4WzLcvi7guW6CCCSK8J1Hf9FTQQA4N	132	1	223	1	\N
0	105	235	1	5210000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
6	106	56	1	12547388000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
2	106	109	1	491500000000	34	2mzgGN5MDNpfFUREf1R4CTpePrsFjKDjKPNr1SwpyBC1WpPMN4Bv	76	1	109	1	\N
4	107	131	1	17228894000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
3	107	223	1	11549670000000000	66	2n1R273RP2djnuVdHN7yqjaG3rjnpYhKaTcySFjVTU2QffnWfdo8	132	1	223	1	\N
0	107	235	1	5218000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
6	108	56	1	12917638000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
2	108	109	1	491250000000	35	2n1aYeyC6MjSAwCP4GU726JztM1UQBGPXVFrmHCCwNBdzTjmS2LV	76	1	109	1	\N
3	108	223	1	11549660000000000	68	2n21BWScFzcgakbLe91AF3UqVQaLTfzPHxJg4GW7Zw2RgUKxQrDF	132	1	223	1	\N
4	109	131	1	17593886000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
3	109	223	1	11549655000000000	69	2n1y2HvUVZKbArgDAormq7mLp7CkowrjC3WVmuSBrLd2qURKWxzE	132	1	223	1	\N
0	109	235	1	5226000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
6	110	56	1	13282630000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
3	110	223	1	11549655000000000	69	2n1y2HvUVZKbArgDAormq7mLp7CkowrjC3WVmuSBrLd2qURKWxzE	132	1	223	1	\N
0	110	235	1	5226000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
6	111	56	1	13647880000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
2	111	109	1	491000000000	36	2mzsbtti6N2jZ9hi5ba2fS7epQQSEUu8FKsUoBnVVAxfgPmM5YNV	76	1	109	1	\N
3	111	223	1	11549650000000000	70	2mzbpWE9tq654yskihPtVTyE9j1hChCnhsiiVGvvX2wMm3HVte5U	132	1	223	1	\N
6	112	56	1	14007880000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
4	113	131	1	17588894000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
6	114	56	1	14018122000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
2	114	109	1	490750000000	37	2n1J1z5rwkytsCX19yNR4VdJUCdRhBYTthcGMQJSukLL8SUeUzKF	76	1	109	1	\N
3	114	223	1	11549640000000000	72	2mzcDBk9VWCQPgNPdyEMfraBWWHyiADEBwEybhDaXYjQUV6FM8pw	132	1	223	1	\N
0	114	235	1	5234000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
6	115	56	1	14383122000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
3	115	223	1	11549635000000000	73	2n1VGtoTJV9vSpr8uvFi8ftT9xKe8gDKW96A8e37P2fGafgJpGEf	132	1	223	1	\N
4	116	131	1	17953894000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
3	116	223	1	11549635000000000	73	2n1VGtoTJV9vSpr8uvFi8ftT9xKe8gDKW96A8e37P2fGafgJpGEf	132	1	223	1	\N
2	117	109	1	490500000000	38	2n17ePbsb3wCx9e7LwhBanYVWUSHvbWfP4WFm3C17cTemAjvotht	76	1	109	1	\N
4	117	131	1	18314136000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
0	117	235	1	5242000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
4	118	131	1	18684136000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
3	118	223	1	11549625000000000	75	2mzcaswR2og63LZGJBZ8DLFQgGFg5qncxVqjgGkZ35uLfQQ4TZhs	132	1	223	1	\N
2	119	109	1	850500000000	38	2n17ePbsb3wCx9e7LwhBanYVWUSHvbWfP4WFm3C17cTemAjvotht	76	1	109	1	\N
2	120	109	1	850000000000	40	2n12zG7aknm1M6JR4UZW2haDseBCVhheW5RGtbr3qYoF9aEgcHKe	76	1	109	1	\N
4	120	131	1	19064628000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
3	120	223	1	11549605000000000	79	2n23FdkeRJybRvohwmaBz3Ah2kxZnKTdcfNrZG5PMpujEPydcxM2	132	1	223	1	\N
0	120	235	1	5250000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
2	121	109	1	849750000000	41	2n2DsUGw6xDDZKWBuMywJ5AFGbFLutjDSESJ4pDnzpLVxzBxSwZ5	76	1	109	1	\N
4	121	131	1	19424870000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
0	121	235	1	5258000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
4	122	131	1	19794870000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
3	122	223	1	11549595000000000	81	2n1JHPkFuHdEh4sFbCo1QYcGBN7dV5cn1kRV5ChjXKUmg8CfZtGd	132	1	223	1	\N
6	123	56	1	14388122000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
3	123	223	1	11549595000000000	81	2n1JHPkFuHdEh4sFbCo1QYcGBN7dV5cn1kRV5ChjXKUmg8CfZtGd	132	1	223	1	\N
6	124	56	1	14748122000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
4	125	131	1	19784870000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
2	126	109	1	849250000000	43	2mzjYZAxx6Em9dWZBccVsBEF9acuZbyT8A3RxVyYm8tshHQgeoBD	76	1	109	1	\N
4	126	131	1	20155362000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
3	126	223	1	11549585000000000	83	2n22eTyBkQDEnEZwGFndra7MTGqZDvM9gMqk1wbSZ5RAbUtVBWcP	132	1	223	1	\N
0	126	235	1	5266000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
6	127	56	1	14758614000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
2	127	109	1	849250000000	43	2mzjYZAxx6Em9dWZBccVsBEF9acuZbyT8A3RxVyYm8tshHQgeoBD	76	1	109	1	\N
3	127	223	1	11549585000000000	83	2n22eTyBkQDEnEZwGFndra7MTGqZDvM9gMqk1wbSZ5RAbUtVBWcP	132	1	223	1	\N
0	127	235	1	5266000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
6	128	56	1	15128608000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
3	128	223	1	11549575000000000	85	2n1uB4xnYPzL5Tjnu8LRt1xMtpnriWa1azxizH9iEG9HHrNRcQHF	132	1	223	1	\N
0	128	235	1	5272000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
6	129	56	1	15488856000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
2	129	109	1	849000000000	44	2n1WThPsi73DJNXhvUvZgmwxaQvYtHbiooLBmrpL1jK7z1ktXxEH	76	1	109	1	\N
0	129	235	1	5274000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
6	130	56	1	15853855000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
3	130	223	1	11549570000000000	86	2n1xehvXT2HFS2fBaYbh37yNB5m6XU6eQfTs2VPVdV92R7wnSCNt	132	1	223	1	\N
0	130	235	1	5275000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
6	131	56	1	16218848000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
3	131	223	1	11549565000000000	87	2n1LugS9Hbnj4skeDMKnHQ8sYcdtMKQ45DyYBoYYqXCE5c37P5Pq	132	1	223	1	\N
0	131	235	1	5282000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
2	132	109	1	848750000000	45	2mzudzGsbpQyDuUrcRKpLQncQz4gvqyGjAh3V8NNC5y35S1m3Fpv	76	1	109	1	\N
4	132	131	1	20150120000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
3	132	223	1	11549560000000000	88	2mzZxq2rNkTwZQbJrBytZGe1gUyJJF1k1H1rKxJq7C4Pqg3trVjD	132	1	223	1	\N
2	133	109	1	848500000000	46	2n1m3nZkynGZAFegWDkBdH7647R6dXKH2LPEqack4SsTyWC2ZNGy	76	1	109	1	\N
4	133	131	1	20520362000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
3	133	223	1	11549550000000000	90	2n2Ff8ivfVP7FLNb4rhAY2wkGifdN1jkdRjg53nfk7gvwVBhLnar	132	1	223	1	\N
0	133	235	1	5290000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
4	134	131	1	20885362000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
3	134	223	1	11549545000000000	91	2n2CvwggPZiiAzUB3oKfbeCAUPqQcAciSvMPd6E4vudbMviC4aPS	132	1	223	1	\N
6	135	56	1	16589090000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
2	135	109	1	848250000000	47	2mziDBtUosaVKn2ziUL8Baq4TdqF1yASKiUiY6yhjP6itB829bF7	76	1	109	1	\N
3	135	223	1	11549535000000000	93	2n1P8ke7gNF33fG8rU4HgoEmVFJeMjtd9Ccw5TGM7fD4rpowkjQY	132	1	223	1	\N
0	135	235	1	5298000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
6	136	56	1	16954339000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
2	136	109	1	848000000000	48	2n2EuDuFgSfTutBjdJ9bxxCUCn36DPzudn2gF7EyG6eVo6s1WexB	76	1	109	1	\N
3	136	223	1	11549530000000000	94	2n2RJ2zTM67GnsiTaQV51A4Zx7oW6mYTYc6zBAb24hBCbJbYTsDK	132	1	223	1	\N
0	136	235	1	5299000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
6	137	56	1	17319332000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
3	137	223	1	11549525000000000	95	2n1CKKBfS8HmBqdhVGeG74WW4CxYv3xNYPuxQohpHUT2iKMDaiNf	132	1	223	1	\N
0	137	235	1	5306000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
6	138	56	1	17679582000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
2	138	109	1	847750000000	49	2mzk4yxGWk5fBUCVayArn3oNuwY3ZPJzgxpShpJoEs6eZ78StnLa	76	1	109	1	\N
2	139	109	1	847750000000	49	2mzk4yxGWk5fBUCVayArn3oNuwY3ZPJzgxpShpJoEs6eZ78StnLa	76	1	109	1	\N
4	139	131	1	21245612000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
6	140	56	1	17679332000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
6	141	56	1	18054574000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
2	141	109	1	847500000000	50	2n1iz9LTKQYviqmXx28G9WxhLtgbEVdLdUBLRCcZe3VGyeAscDJ5	76	1	109	1	\N
3	141	223	1	11549510000000000	98	2mzcCNe6Bx3WAd8Li8jZrqyyjVafhUpAQco7Yz85mN9BkFoQiWfn	132	1	223	1	\N
0	141	235	1	5314000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
2	142	109	1	847500000000	50	2n1iz9LTKQYviqmXx28G9WxhLtgbEVdLdUBLRCcZe3VGyeAscDJ5	76	1	109	1	\N
4	142	131	1	21620854000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
3	142	223	1	11549510000000000	98	2mzcCNe6Bx3WAd8Li8jZrqyyjVafhUpAQco7Yz85mN9BkFoQiWfn	132	1	223	1	\N
0	142	235	1	5314000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
4	143	131	1	21610611000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
3	143	223	1	11549505000000000	99	2n1CFrzFcEAZLJHC5dGbqrhqaaZzFEJZMzk9hrRXnCnAmoWrJBNp	132	1	223	1	\N
0	143	235	1	5315000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
2	144	109	1	847000000000	52	2n2DCvhgeW7QdN6ZtmjMtMyeF835Tfw9Q9Hnv1dBxeqrzXpo7mYP	76	1	109	1	\N
4	144	131	1	21981104000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
3	144	223	1	11549495000000000	101	2n1vaPo6tVbMm4TSswmxHgRNookwpog28FXoqiTf111912eLZjko	132	1	223	1	\N
0	144	235	1	5322000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
6	145	56	1	18425067000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
2	145	109	1	847000000000	52	2n2DCvhgeW7QdN6ZtmjMtMyeF835Tfw9Q9Hnv1dBxeqrzXpo7mYP	76	1	109	1	\N
3	145	223	1	11549495000000000	101	2n1vaPo6tVbMm4TSswmxHgRNookwpog28FXoqiTf111912eLZjko	132	1	223	1	\N
0	145	235	1	5322000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
6	146	56	1	18414574000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
4	147	131	1	22351096000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
3	147	223	1	11549485000000000	103	2n19D6pCbfhdyj8dnrzo6V84ZfGemtfDkGNc63DHegDQb5pEpDsY	132	1	223	1	\N
0	147	235	1	5330000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
6	148	56	1	18774824000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
2	148	109	1	846750000000	53	2mzXzcei7LtKr1AoGCX3vtp1zQErKSSBB1CKWg8zU7sttGQ755cZ	76	1	109	1	\N
6	149	56	1	19134824000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
6	150	56	1	19504816000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
3	150	223	1	11549475000000000	105	2n2KnJYeygAFmHJNQq4ks8R52tcfHDpoXCkdV6jEJZdF5MixVvpb	132	1	223	1	\N
0	150	235	1	5338000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
4	151	131	1	22721088000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
3	151	223	1	11549475000000000	105	2n2KnJYeygAFmHJNQq4ks8R52tcfHDpoXCkdV6jEJZdF5MixVvpb	132	1	223	1	\N
0	151	235	1	5338000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
2	152	109	1	846500000000	54	2n1q11tZKthZDv5s61yGDmyu9v2d1zfV6H45W4KgfKV9jjZyn4SX	76	1	109	1	\N
4	152	131	1	23086338000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
3	152	223	1	11549470000000000	106	2mzj7kYgJpBrjUXymik3aRGFYQ5VCL7ugnYkFCCCqpPmzKb3cCfR	132	1	223	1	\N
6	153	56	1	19499816000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
3	153	223	1	11549465000000000	107	2n1edSe9Kw9BJexhdSPd2WLb7NU727aVKwbQqVgyXSEZJKxwDUzp	132	1	223	1	\N
0	153	235	1	5346000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
2	154	109	1	846250000000	55	2n1KLDyPqBW49sWEEpZuC5oLHmDH79EJ2gdCrg9aaNFuZGvZYjQJ	76	1	109	1	\N
4	154	131	1	23446588000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
6	155	56	1	19864815000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
3	155	223	1	11549460000000000	108	2mznfJG8GAg2JhjEnvNqAoTpiyS94mte4HwJg5KuL4BYQzvU2M9B	132	1	223	1	\N
0	155	235	1	5347000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
6	156	56	1	20230058000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
2	156	109	1	846000000000	56	2n11Z7xYEf76oMV5abQkAdSx79P4b7eHqgrTNXzKtYza4PesfWJY	76	1	109	1	\N
3	156	223	1	11549455000000000	109	2mzdCrQFNi4aRKVeSz7QZTSCkkobB6sRdKNcFBfP2V6LvvNzUWdW	132	1	223	1	\N
0	156	235	1	5354000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
4	157	131	1	23811588000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
3	157	223	1	11549450000000000	110	2n2TLUw5YMGt6NeLoJy7nTYoBG7cN877d92NzRJXQFDD9BW7kD46	132	1	223	1	\N
6	158	56	1	20595050000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
3	158	223	1	11549445000000000	111	2mzgBJJC2XoUcSqSaLpZgT3KoBNprAayks1aqTQEiwbgEgwC4WVB	132	1	223	1	\N
0	158	235	1	5362000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
2	159	109	1	845750000000	57	2n1QAj9YPKS88PSRYbUJqnA9Lq9dAjYXCRqN7CD2h4RCMWwuRan9	76	1	109	1	\N
4	159	131	1	24171838000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
6	160	56	1	20965044000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
3	160	223	1	11549435000000000	113	2n1AFqED5RnnN9bu2BsVmjzCH7Pjw9Lgf3jQadzkuHbMRq8EuL3q	132	1	223	1	\N
0	160	235	1	5368000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
2	161	109	1	845250000000	59	2n1tKdZ4Dtp8f6aRgg4WcTsWA7MHUVWVzdw44cJceqkVQf2aFSpq	76	1	109	1	\N
4	161	131	1	24547333000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
3	161	223	1	11549420000000000	116	2mzdqp8uvXGYXq1x7Xqe6bzzmBJn4H12XCae6wv5Ke2hvWrF5eNE	132	1	223	1	\N
0	161	235	1	5373000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
6	162	56	1	21330039000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
3	162	223	1	11549415000000000	117	2mzkb5LXKdx3uKM3u992nhH7fgRqFXYQAM2tZLfwUzRmTJbbLZ5e	132	1	223	1	\N
0	162	235	1	5378000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
4	163	131	1	24912328000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
3	163	223	1	11549415000000000	117	2mzkb5LXKdx3uKM3u992nhH7fgRqFXYQAM2tZLfwUzRmTJbbLZ5e	132	1	223	1	\N
0	163	235	1	5378000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
2	164	109	1	845000000000	60	2mzuQBSg2xsd9H6sXB3G2vzgTvHqeK2kBq1Up1hjdC8e5dNjym53	76	1	109	1	\N
4	164	131	1	24912577000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
3	164	223	1	11549410000000000	118	2mzX5xs3BGQRQdVUHMrNbqVdWYDS5aytPsmhbFezjQbAa2aWX29N	132	1	223	1	\N
0	164	235	1	5384000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
6	165	56	1	21695283000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
2	165	109	1	845000000000	60	2mzuQBSg2xsd9H6sXB3G2vzgTvHqeK2kBq1Up1hjdC8e5dNjym53	76	1	109	1	\N
3	165	223	1	11549410000000000	118	2mzX5xs3BGQRQdVUHMrNbqVdWYDS5aytPsmhbFezjQbAa2aWX29N	132	1	223	1	\N
0	165	235	1	5384000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
6	166	56	1	21695287000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
2	166	109	1	844750000000	61	2n1DsBdZ54MbSYBTPyxCbc4HgyPzYZPEp628f737omZuaeuQpDZ5	76	1	109	1	\N
3	166	223	1	11549405000000000	119	2mzguH19H9ic3r2U3N7JY5YWaiCcgfoB6wDGaQtsUDGaE1mCdKqL	132	1	223	1	\N
0	166	235	1	5386000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
6	167	56	1	22055287000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
4	168	131	1	25272577000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
6	169	56	1	22065279000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
3	169	223	1	11549395000000000	121	2n2HGGMTAfpx3bY8XQ2TtNVcd1kW9Qyhy7GuFJq68QLvMmJePfuY	132	1	223	1	\N
0	169	235	1	5394000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
2	170	109	1	844500000000	62	2n1K2q7wgHqMu5BCigY1Yf6K4k1a6y7aVrBxtQiXa27NfFy7AagB	76	1	109	1	\N
4	170	131	1	25632827000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
4	171	131	1	25992827000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
4	172	131	1	26362819000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
3	172	223	1	11549385000000000	123	2n19qwzeqyttsLQSnbo3Wsv8mtTWuS1LbTmdv4VecWNjA2QZYuGA	132	1	223	1	\N
0	172	235	1	5402000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
2	173	109	1	844250000000	63	2mzZihw8MuVKEusZJuCx5SUEZodjrYhvb1pRzWsP4nKEYnqDRW5m	76	1	109	1	\N
4	173	131	1	26728069000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
3	173	223	1	11549380000000000	124	2n1nCBKTrLG8ZeczyRKeM1TgtMasK83ct8nyvZt5yoa31KVjSh98	132	1	223	1	\N
6	174	56	1	22430271000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
3	174	223	1	11549375000000000	125	2n1YgesTUNu4GFU3CBnwmiMumgYT5hGwmbu2wQsh2kMoDB1j1SC4	132	1	223	1	\N
0	174	235	1	5410000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
6	175	56	1	22790521000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
2	175	109	1	844000000000	64	2n1mz8am8qZx3uWQu5J2KnygD5BWEg1PNha9CbbMDEE1qrDiDw7n	76	1	109	1	\N
2	176	109	1	844000000000	64	2n1mz8am8qZx3uWQu5J2KnygD5BWEg1PNha9CbbMDEE1qrDiDw7n	76	1	109	1	\N
4	176	131	1	27088319000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
6	177	56	1	23155520000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
3	177	223	1	11549370000000000	126	2mzbSGHjKLn3twsU1ZXbQmDn7kgwWe4kMkTUUCMMrezuT8Ee1K7M	132	1	223	1	\N
0	177	235	1	5411000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
4	178	131	1	27093062000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
3	178	223	1	11549365000000000	127	2mzkRobqr2uXDdtnTw9zjjtaxz9uB4ZbZHKV4qypRNoRDX6aApXi	132	1	223	1	\N
0	178	235	1	5418000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
2	179	109	1	843750000000	65	2mztFak5c9BTMSaQA7a9ZPAoWogYcRmz56q58nwKkkChFBbNrriN	76	1	109	1	\N
4	179	131	1	27453312000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
6	180	56	1	23515770000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
2	180	109	1	843750000000	65	2mztFak5c9BTMSaQA7a9ZPAoWogYcRmz56q58nwKkkChFBbNrriN	76	1	109	1	\N
4	181	131	1	27453062000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
4	182	131	1	27823054000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
3	182	223	1	11549355000000000	129	2mzZg33YUzZvg6X7ToDmUDwvJF1rXiukDqQrasmXAaXVqA1qnKA9	132	1	223	1	\N
0	182	235	1	5426000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
6	183	56	1	23881020000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
2	183	109	1	843500000000	66	2mzcK3e4GMtd1dmP4u36Ev2beLv3owvvtBMFjknY6imXbLfrt4Zt	76	1	109	1	\N
3	183	223	1	11549350000000000	130	2n2Ss1hSkwCAc22DkVHjVz1paTpEH6XzPBKF7b7KqgdCZK6CPJug	132	1	223	1	\N
4	184	131	1	28188046000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
3	184	223	1	11549345000000000	131	2n1rKr7KvdZgPEuGuJgprUbLwF6czjN2icqwF2xVGQNZB6vsu6d5	132	1	223	1	\N
0	184	235	1	5434000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
6	185	56	1	24241270000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
2	185	109	1	843250000000	67	2mzjnbFMDEvV8ANw7sYtH1D59qbGnm3gt2e74e2VAfgybfZqMv5N	76	1	109	1	\N
4	186	131	1	28553045000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
3	186	223	1	11549340000000000	132	2n1qpCdqBZCQvc4gjg9dzey1u5yNaiyqLgLUs896piPVZo9Ce6rg	132	1	223	1	\N
0	186	235	1	5435000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
4	187	131	1	28918038000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
3	187	223	1	11549335000000000	133	2mzYmjwS5rN5SgX2UriEFfxqhXt1vc1EQBvoNEZGqgtiLtqLgE7V	132	1	223	1	\N
0	187	235	1	5442000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
6	188	56	1	24606263000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
3	188	223	1	11549335000000000	133	2mzYmjwS5rN5SgX2UriEFfxqhXt1vc1EQBvoNEZGqgtiLtqLgE7V	132	1	223	1	\N
0	188	235	1	5442000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
2	189	109	1	843000000000	68	2n2RLVm1WYQrEeXyksCQgk2hP3PNGbaerfmWbPFuU6AxEUSbz6aX	76	1	109	1	\N
4	189	131	1	28913295000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
6	190	56	1	24966513000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
2	190	109	1	843000000000	68	2n2RLVm1WYQrEeXyksCQgk2hP3PNGbaerfmWbPFuU6AxEUSbz6aX	76	1	109	1	\N
4	191	131	1	28913045000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
6	192	56	1	25336755000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
2	192	109	1	842750000000	69	2n2CgCkDkD9VuN25T2MzDMtQQDMbT3yjWvNo6E4gwHe4n7t1JVRE	76	1	109	1	\N
3	192	223	1	11549325000000000	135	2n1GLBt2Ep9Zv8nMgji6T6ZRJk65DNcJTw9CzAbm4zS7VgCQomUq	132	1	223	1	\N
0	192	235	1	5450000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
6	193	56	1	25701755000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
3	193	223	1	11549320000000000	136	2mztv4kSwy2h2JzWHHTqhCPMVtbtDjrSRaHTJaFmmd15DX8n75N9	132	1	223	1	\N
6	194	56	1	26066747000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
3	194	223	1	11549315000000000	137	2n1RiiMKkFQYWKhMgX8ooH8LZCjUH63m3bs5yzzksC8u6usMzfHE	132	1	223	1	\N
0	194	235	1	5458000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
4	195	131	1	29278037000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
3	195	223	1	11549315000000000	137	2n1RiiMKkFQYWKhMgX8ooH8LZCjUH63m3bs5yzzksC8u6usMzfHE	132	1	223	1	\N
0	195	235	1	5458000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
6	196	56	1	26426997000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
2	196	109	1	842500000000	70	2mzwq61FSwbxXyL4T5VibTtedKnn7W3KYY7dyn7vzBpdErTM8vGs	76	1	109	1	\N
4	197	131	1	29278044000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
3	197	223	1	11549310000000000	138	2mzvFFyZh2gw5CUYeqxAH9EJgLaerPCpBQtpbkSFTs2YcWdCx5KE	132	1	223	1	\N
0	197	235	1	5459000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
6	198	56	1	26791990000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
3	198	223	1	11549305000000000	139	2n1H8suGnP8MvW35bMGzvyBQA4dgfEXQ8A56GSoARKtZoreXkUj6	132	1	223	1	\N
0	198	235	1	5466000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
6	199	56	1	27152240000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
2	199	109	1	842250000000	71	2n11BmUR3wotXcAZKAaeSJdFmre4iBQwUsK7Kbf8c6GdftsNb5ai	76	1	109	1	\N
2	200	109	1	842250000000	71	2n11BmUR3wotXcAZKAaeSJdFmre4iBQwUsK7Kbf8c6GdftsNb5ai	76	1	109	1	\N
4	200	131	1	29638294000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
2	201	109	1	1202500000000	71	2n11BmUR3wotXcAZKAaeSJdFmre4iBQwUsK7Kbf8c6GdftsNb5ai	76	1	109	1	\N
6	202	56	1	27151990000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
6	203	56	1	27521982000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
3	203	223	1	11549295000000000	141	2n1WWsqAwdQaZTvJjdvVgYaPCHpWcmSXVGvyYjy4Y71syihRCgnD	132	1	223	1	\N
0	203	235	1	5474000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
2	204	109	1	1202250000000	72	2mziMtHgkV3UQU5Lo6Su7hGtjinY9NYCNi6ZcoV2bjtwwoK2vYLX	76	1	109	1	\N
4	204	131	1	29638294000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
6	205	56	1	27882232000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
2	205	109	1	1202250000000	72	2mziMtHgkV3UQU5Lo6Su7hGtjinY9NYCNi6ZcoV2bjtwwoK2vYLX	76	1	109	1	\N
4	206	131	1	29998294000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
6	207	56	1	27892224000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
2	207	109	1	1202000000000	73	2n2CUw8hYVBDM4acHxVYnjfCjVTY74JfkzNzBTA3z3W14cfAPyyr	76	1	109	1	\N
3	207	223	1	11549285000000000	143	2n2BZ7cEU85bPtZotvDvg55UdppAXPSXt25BVJrbrNP5y9aRgX8E	132	1	223	1	\N
0	207	235	1	5482000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
4	208	131	1	30363294000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
3	208	223	1	11549280000000000	144	2mzmmP1bJq6BYNDvmcr1VWDMhikC4zxThMFeZ7ensh2EtY4uKNsC	132	1	223	1	\N
4	209	131	1	30728286000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
3	209	223	1	11549275000000000	145	2n15raywQRSkErrWhYWrWUwa2YourmCB9evnL9PuMPqirn8kQJt2	132	1	223	1	\N
0	209	235	1	5490000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
2	210	109	1	1201750000000	74	2n2QeHYz9CSEFXkDcHzysbUWCtH9L1GFzdWxgyMqPBMPBT4xY74V	76	1	109	1	\N
4	210	131	1	31088536000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
2	211	109	1	1201500000000	75	2n1jeAqv7yp4nvYVZHXdebyzmrZSt52w5maadzFCWuLnnuoP2XTa	76	1	109	1	\N
4	211	131	1	31463780000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
3	211	223	1	11549260000000000	148	2n1gaapyV86PP5FZhvoYerKdQRgNWAEEj8yh4MZ2CYuoPJPv6DMJ	132	1	223	1	\N
0	211	235	1	5496000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
6	212	56	1	28257222000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
3	212	223	1	11549255000000000	149	2mzbvYHqc27LLkVKyUKv8tfQ5GHNg3GLSqQ8osBBRwz2UXKPp94o	132	1	223	1	\N
0	212	235	1	5498000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
2	213	109	1	1201250000000	76	2n1CLqKV94ozGDe59vwNqdRVark6ybUWj9kzczmkmxcK3Lx89UZ4	76	1	109	1	\N
4	213	131	1	31824022000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
0	213	235	1	5506000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
2	214	109	1	1201000000000	77	2n2EAtFYHjT2A9ZCi1h7UrbbkvkDEVWf57D4wQnnVczSKHic2chp	76	1	109	1	\N
4	214	131	1	32194272000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
3	214	223	1	11549245000000000	151	2n13wHYHqnhPQgwtuFEDmkCq1LNYZQHpEfP43VgNqYZdVvr6jdks	132	1	223	1	\N
6	215	56	1	28622214000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
3	215	223	1	11549240000000000	152	2n1QcTd4gh6pXqo9ckiCfrdJYMUAQpFPcP39APY4cwBVfXghCzgk	132	1	223	1	\N
0	215	235	1	5514000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
4	216	131	1	32559264000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
3	216	223	1	11549240000000000	152	2n1QcTd4gh6pXqo9ckiCfrdJYMUAQpFPcP39APY4cwBVfXghCzgk	132	1	223	1	\N
0	216	235	1	5514000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
6	217	56	1	28622472000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
2	217	109	1	1200750000000	78	2mzwXBkvCDNL3W3ZQ3Sv8RvN33Wddxo3LRhuecKRjWedZYpD3L5M	76	1	109	1	\N
3	217	223	1	11549235000000000	153	2n2QnyKoTQ5ZEhWfB5mMEnRUVTaDuDgz6PhidxcReJbEwV8h5NTx	132	1	223	1	\N
2	218	109	1	1200750000000	78	2mzwXBkvCDNL3W3ZQ3Sv8RvN33Wddxo3LRhuecKRjWedZYpD3L5M	76	1	109	1	\N
4	218	131	1	32924514000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
3	218	223	1	11549235000000000	153	2n2QnyKoTQ5ZEhWfB5mMEnRUVTaDuDgz6PhidxcReJbEwV8h5NTx	132	1	223	1	\N
4	219	131	1	32919264000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
6	220	56	1	28982472000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
6	221	56	1	29352464000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
3	221	223	1	11549225000000000	155	2n1FQPrNJ11Te1LyYR2vVY9cdYG6PYnvc5cB3DrjY4ApjjKGtzYd	132	1	223	1	\N
0	221	235	1	5522000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
6	222	56	1	29717714000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
2	222	109	1	1200500000000	79	2n1fG8CjLv6ppX1EpfcpWTi3wiXfdUzK7afhpb2cvddkTuugLhYE	76	1	109	1	\N
3	222	223	1	11549220000000000	156	2n1rG8EKX4Z65AKaDwbk7vGL8TurRxoznP5nXquwX1uS7WiPgiwn	132	1	223	1	\N
2	223	109	1	1200250000000	80	2mzePU5wKNRi7gtjEfhYa3W8PRYxaQQpmVDiVnBM3hHbtYhxWEDZ	76	1	109	1	\N
4	223	131	1	32924506000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
3	223	223	1	11549215000000000	157	2n23m4gpSbbqJt4rwFYx8s575FR6HKL5ie4x3gtqgvUMHw5EazKz	132	1	223	1	\N
0	223	235	1	5530000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
2	224	109	1	1200000000000	81	2mzeVbFRprR9YSoUvptPYf3i9N4741DtgNNi1BxuoSBuCw13wKzx	76	1	109	1	\N
4	224	131	1	33294755000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
3	224	223	1	11549205000000000	159	2mzmbLhGG5yvVmerYpD6BoKQpQDYptRKwWadWSwpBDiuQD1mopXn	132	1	223	1	\N
0	224	235	1	5531000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
6	225	56	1	30087963000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
2	225	109	1	1200000000000	81	2mzeVbFRprR9YSoUvptPYf3i9N4741DtgNNi1BxuoSBuCw13wKzx	76	1	109	1	\N
3	225	223	1	11549205000000000	159	2mzmbLhGG5yvVmerYpD6BoKQpQDYptRKwWadWSwpBDiuQD1mopXn	132	1	223	1	\N
0	225	235	1	5531000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
4	226	131	1	33659748000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
3	226	223	1	11549200000000000	160	2n2Kkb8erQ6RET1Vvu9Tvmg3aoDogbYZoUjeSfhNjsPD9eXcC8wt	132	1	223	1	\N
0	226	235	1	5538000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
4	227	131	1	34024748000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
3	227	223	1	11549195000000000	161	2n2GrMRAGMCPoVACBqpS4GMgVBnrEfh5XBECEWXJFsenaXvix9zL	132	1	223	1	\N
4	228	131	1	34384748000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
6	229	56	1	30082956000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
2	229	109	1	1199750000000	82	2mzjSgCS2DoTXwXGY5Tc1bX3axnrXPRAHJbRecsVBQPMivHJaeLW	76	1	109	1	\N
3	229	223	1	11549190000000000	162	2n29xezAJBE176GAK2tvLEkTKXy6kSJ2XLpyh3Wc5bUKENFVYYN9	132	1	223	1	\N
0	229	235	1	5546000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
2	230	109	1	1199500000000	83	2n2NQvAisGaMganmUmY7GEWWEQhc96asGxxc9fPyALo3jg1awWDJ	76	1	109	1	\N
4	230	131	1	34749998000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
3	230	223	1	11549185000000000	163	2mztNygF8YpVeFKfjANrobvBSE6uhF3veSqhpea53z9fpbRCaPNn	132	1	223	1	\N
4	231	131	1	35114990000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
3	231	223	1	11549180000000000	164	2mzfcQZKSdKTfnnUYiyNHmNwmzTSC2pKuUSg2TNAtTorFYFeahi8	132	1	223	1	\N
0	231	235	1	5554000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
6	232	56	1	30447948000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
3	232	223	1	11549180000000000	164	2mzfcQZKSdKTfnnUYiyNHmNwmzTSC2pKuUSg2TNAtTorFYFeahi8	132	1	223	1	\N
0	232	235	1	5554000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
6	233	56	1	30447956000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
3	233	223	1	11549175000000000	165	2n17v4wC9KDTqpGCCoqMX1sAb5oHJxT8Mcj1KP3Q5U4jfndEcdb6	132	1	223	1	\N
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
4	3NKk1b3sM64NMXxUqqC3ee6QPThAMaMpL3FS1uFV2zFKbXJcNqWF	2	3NKH9d2oj3G5oQvQjkzhNvgUwqrQhPsY1KaR4BUsHRZg5jxKay1c	57	147	tMD5YzIhADF1LPlkon0kcf_eiAqRn7M0IW9dpzRztgk=	1	1	5	77	{1,2,7,7,7,7,7,7,7,7,7}	23167003000060590	jw98a3c6WsSdpqZdHkfzWi7CWEMsMhKqTMXPyJ4uSFXinDGuMrv	3	10	10	1	\N	1781507498000	orphaned
5	3NKrMpJQ7bxoe1vRdBRentQk2j7YV6v9cQ3hTBBeZE6QajpuCqPS	3	3NLEjTNpksz6wP2bLHwFSshkpHWqGon6Jfdb2wWVGBrBiyW9aqsB	132	224	yO6yJ5H5DvOqr3j0ayexIGX8MWbHVUDBsnowGTG5gw4=	1	1	6	77	{1,3,7,7,7,7,7,7,7,7,7}	23167003000060590	jxFfKaoKjA7nSBaHiCkMTfQhDKzHDywHxcjp1RfbFAVQkxKY4vx	4	11	11	1	\N	1781507528000	canonical
3	3NLEjTNpksz6wP2bLHwFSshkpHWqGon6Jfdb2wWVGBrBiyW9aqsB	2	3NKH9d2oj3G5oQvQjkzhNvgUwqrQhPsY1KaR4BUsHRZg5jxKay1c	132	224	QZh5XAB-PlTPUeOnRHXRP3Kleg3Bsy0o7pHutCYSvwo=	1	1	4	77	{1,2,7,7,7,7,7,7,7,7,7}	23167003000060590	jxzXvqrYqNWZ9DFtdw7SVhXPWE4U9YtTYegU1AoP114uuHPABYe	3	10	10	1	\N	1781507498000	canonical
2	3NKH9d2oj3G5oQvQjkzhNvgUwqrQhPsY1KaR4BUsHRZg5jxKay1c	1	3NLTXTNHiVghip2xMjmutp762UyqT9R3BiuGVdNywjdsJ9jSiF85	57	147	UqyxQEpYzbA8JUucaWQTjxTF9AqrnY-lQ1oHcRkccgI=	1	1	3	77	{1,1,7,7,7,7,7,7,7,7,7}	23167003000060590	jxDWiidueczVWKbxwXT7MgowpKKD4XgJccuVuc94qzMip47KHwz	2	9	9	1	\N	1781507468000	canonical
1	3NLTXTNHiVghip2xMjmutp762UyqT9R3BiuGVdNywjdsJ9jSiF85	\N	3NL7XzbJEY9p5iMEdCazinA3SEGHECzs145HCp2dEowsKfjwzWqm	1	1	39cyg4ZmMtnb_aFUIerNAoAJV8qtkfOpq0zFzPspjgM=	1	1	2	77	{1,7,7,7,7,7,7,7,7,7,7}	23167003000060590	jxR6T25M71V5r13xNVLuKGbJ7DVbJx9Vti1SH2KrczwnUDpovH4	1	0	0	1	\N	1781507198000	canonical
8	3NKB2tx1r53S2Mg4XLCy79GGqrpudk6h7XnGaHqD46YQzVvz87bT	7	3NLcsCywdyAZb2oQ2qqLUrZHXsq2q8MB3KF6znfaobERRZt6LPp5	57	147	fXq0raJu5Xfsk_eEfcnpvjyKvHBbe3f-TTBGIqujOQw=	1	1	9	77	{1,5,1,7,7,7,7,7,7,7,7}	23167003000060590	jx2eHqQvHsMs7fx4VK9k9JHV1tHh4V2hAvqs3HnSvfX9aHgcLd1	7	14	14	1	\N	1781507618000	orphaned
21	3NKQENdBxYEmZQfhWwWRfbcfU8f8ATjAHjz7ts6A9Bgf5VV2T9gm	20	3NKJg898sT8yyftZjiC8RP2Cw3gQBDKdqqQAzZfovm92dFtpfdes	132	224	ZQDvh79TySA7xr9dU-rZCqC8SNjKsH941jcWM2Df3ww=	1	1	22	77	{1,5,6,5,2,7,7,7,7,7,7}	23167003000060590	jwVf46G1BV9np9cN66jQwK9h4DSZTrG2TUrAn7EyeWXPAQSpw9Y	19	29	29	1	\N	1781508068000	orphaned
20	3NKJg898sT8yyftZjiC8RP2Cw3gQBDKdqqQAzZfovm92dFtpfdes	19	3NKLwLyHeQEARroVJrs7JPzsSM1GVa7mFhrmPGkpfSRwVmR9FXT7	132	224	RPoD6NYNkVi0Gz8w7Lh5hWJ4h18tR4CR9xymvlJDSQk=	1	1	21	77	{1,5,6,5,1,7,7,7,7,7,7}	23167003000060590	jxC3ZnBpQh6rurWvHuSUo4VvcQm5LPx3Yy657ERAseHt8pQmCFg	18	28	28	1	\N	1781508038000	canonical
19	3NKLwLyHeQEARroVJrs7JPzsSM1GVa7mFhrmPGkpfSRwVmR9FXT7	18	3NLDk7vfSLcqgct7cqZsYNHKRDywuvKhFyBYGMZBVxHpEmpYd6KE	57	147	2zZN4wNcIjEqCsJh2LkeCYLPTvLZARZkuT_pYkrUbww=	1	1	20	77	{1,5,6,5,7,7,7,7,7,7,7}	23167003000060590	jxf9YPZ8WT1zgmaXCemokwCkBJLA3yPo7dRRugykRgqU6qrJNEa	17	27	27	1	\N	1781508008000	canonical
18	3NLDk7vfSLcqgct7cqZsYNHKRDywuvKhFyBYGMZBVxHpEmpYd6KE	17	3NLm1wKru3qRAjUof7HaMRFa1zxJNZdSqKyfFS5YJwoRnWgmThbU	132	224	6AUarOVaJZHnf7lxOsYJcpb3cSkLb8jw33Da4M7CSww=	1	1	19	77	{1,5,6,4,7,7,7,7,7,7,7}	23167003000060590	jwSCgfbmrX1ri1DEAM1SiooTiD1GoyQ1Zbbx51fnNzprRQxZP6Y	16	26	26	1	\N	1781507978000	canonical
17	3NLm1wKru3qRAjUof7HaMRFa1zxJNZdSqKyfFS5YJwoRnWgmThbU	16	3NKPNJkrVMAKb55k69GZDq51MyRs8WsxedhkoXSHr7efusbgLhtC	57	147	G0q99n_u1Z1Q5YHzMejZtgCxbnxdJVSStLMFLrJ1EAs=	1	1	18	77	{1,5,6,3,7,7,7,7,7,7,7}	23167003000060590	jx3F38FW1ZM3F6UrcSHxiqPLLZt6umZGpYBoyyqCCFtuUKK3aAx	15	24	24	1	\N	1781507918000	canonical
16	3NKPNJkrVMAKb55k69GZDq51MyRs8WsxedhkoXSHr7efusbgLhtC	15	3NLBhrUuiLaJZSx9AXouzc9kPLf8nuSSPsHb71KUA2WQ4RekBqUN	57	147	Fv9nlWg7KMJToN_Pt2b38LPzcl0UuezL6BrJ8Uw6SA8=	1	1	17	77	{1,5,6,2,7,7,7,7,7,7,7}	23167003000060590	jxTA3NUkZNoU1xdJVARJ6ap6sq51x7X61ZwNqcKJSmgbVKovCvR	14	23	23	1	\N	1781507888000	canonical
15	3NLBhrUuiLaJZSx9AXouzc9kPLf8nuSSPsHb71KUA2WQ4RekBqUN	14	3NLJ6PQsjfmz8GXa47iQD663FkDZ9vGWVSErRfUETcvQzb1B5CtK	57	147	JeguMEJEAfM4f98XPpA151yVoJzUed40S4twBpZnGww=	1	1	16	77	{1,5,6,1,7,7,7,7,7,7,7}	23167003000060590	jxMUmQQybTvW5CSLoi7nKW7S2juskwv1zT8SpC3tVVwYpaasbhx	13	22	22	1	\N	1781507858000	canonical
14	3NLJ6PQsjfmz8GXa47iQD663FkDZ9vGWVSErRfUETcvQzb1B5CtK	13	3NLtDQq4cViDRVM9NZHjWZFun2zkwsEE3a3AeocXSctx8VjaTeN1	132	224	m0eSCCljKc0mmJMWjSbBv-f5J2exkRz-FIYEwve0rw4=	1	1	15	77	{1,5,6,7,7,7,7,7,7,7,7}	23167003000060590	jwwfgi66SvWhkuvSaKhkBdYKrN32VKScszB5dYyMbw95SeM1X1h	12	20	20	1	\N	1781507798000	canonical
13	3NLtDQq4cViDRVM9NZHjWZFun2zkwsEE3a3AeocXSctx8VjaTeN1	12	3NKXj92UQeTsLnAECaCCKASAH7pTaWGWcPQBCW3tswPQ45XUDqYk	57	147	ZIRh3G_eQnQCePlyJw1Hk_evSPfVan5bO6wjkDS_AA8=	1	1	14	77	{1,5,5,7,7,7,7,7,7,7,7}	23167003000060590	jwA8LPTtCPfqDHnMYrnXi1THZ4f3CsFso8jrGAPmC2PnZ9up7Nu	11	18	18	1	\N	1781507738000	canonical
12	3NKXj92UQeTsLnAECaCCKASAH7pTaWGWcPQBCW3tswPQ45XUDqYk	11	3NKuDjk8N3S4MvyXXL7XrtJsz8TXsfFote95gefZPy1oW7JfqEgp	57	147	vJ0AnUGrYg9mV52N7ElT1K4x8bArYPh2XN8-Q793uQA=	1	1	13	77	{1,5,4,7,7,7,7,7,7,7,7}	23167003000060590	jxXNp1vyPi7t4TKMEyTbBk7R3FZKLDWJ7WWu8NBHLzeKxQfv3yC	10	17	17	1	\N	1781507708000	canonical
11	3NKuDjk8N3S4MvyXXL7XrtJsz8TXsfFote95gefZPy1oW7JfqEgp	10	3NK5mG4oNDRgGXKdRhqN318gTmGKUMtrXnCkYJ66MCgGm43asmK4	132	224	Hq4408cbbvO4eJk54hb8-TlkiwA17_hoFkMWojl7dgE=	1	1	12	77	{1,5,3,7,7,7,7,7,7,7,7}	23167003000060590	jxUktD5NnUNFYKvFFEzwQ7NjQRjTRTy8WGAhwgz9ZCyZr7N3uko	9	16	16	1	\N	1781507678000	canonical
10	3NK5mG4oNDRgGXKdRhqN318gTmGKUMtrXnCkYJ66MCgGm43asmK4	9	3NK7q6FYeAWLXnH7tXChbNWdvzrfZpFZPHs2ZKQhT2Y1i6N3zbuR	57	147	gDULRp7QfaC_FdxLVYWWZIDm0Qp35YHrM4HdllgjTgc=	1	1	11	77	{1,5,2,7,7,7,7,7,7,7,7}	23167003000060590	jwdR6pCopvBvr4BDkwoypEzUju9UNCfkE25UDKjL3Fp5QAz4x9i	8	15	15	1	\N	1781507648000	canonical
9	3NK7q6FYeAWLXnH7tXChbNWdvzrfZpFZPHs2ZKQhT2Y1i6N3zbuR	7	3NLcsCywdyAZb2oQ2qqLUrZHXsq2q8MB3KF6znfaobERRZt6LPp5	132	224	WfKUkVUiHnzY2eL1mr66YWkAP-W5ZlkK077YI0rQIwU=	1	1	10	77	{1,5,1,7,7,7,7,7,7,7,7}	23167003000060590	jxT5cYEzC6mLfFjXdgdpQAek5tgDzABvNDKoaReXdkLBoFiUiWJ	7	14	14	1	\N	1781507618000	canonical
7	3NLcsCywdyAZb2oQ2qqLUrZHXsq2q8MB3KF6znfaobERRZt6LPp5	6	3NKxkHRUjVf7cvDYro7pb65dabPbfbzK5xY886ZH7mUPVmqb7J63	57	147	zTSau9Oq7Km8Zw_hROmQdIU6Ey1xnLA5saZvkxoigAQ=	1	1	8	77	{1,5,7,7,7,7,7,7,7,7,7}	23167003000060590	jxPaoVZj9GCs9zJVneBTuP4PsjgVvogbZxruK7EAmNbyi6QGHs5	6	13	13	1	\N	1781507588000	canonical
6	3NKxkHRUjVf7cvDYro7pb65dabPbfbzK5xY886ZH7mUPVmqb7J63	5	3NKrMpJQ7bxoe1vRdBRentQk2j7YV6v9cQ3hTBBeZE6QajpuCqPS	132	224	o1Z4AznDkHUTQemzBOzFNwiONpD8ucDDEIriv6hSWw4=	1	1	7	77	{1,4,7,7,7,7,7,7,7,7,7}	23167003000060590	jxRVBvjcRL3Rsp7ELpEbN2wKWobCHykDdmjbddffr746VjW6kT7	5	12	12	1	\N	1781507558000	canonical
27	3NLFNBLFMEyZ827aXK9m3G6C3UYarMKWTUvDtrQe2ZR5QsMyVBsR	25	3NKd9H6Us1qJSxcdWJbhbneEBbnGoWVBU7y9ZqjhEtorfWGEgQyc	57	147	xImNT9ecnXcds1258Sjv4DM5KICSIQ4esUFsBlYhlwk=	1	1	27	77	{1,5,6,5,6,7,7,7,7,7,7}	23167003000060590	jwKedWEg4dhokLYz3fp4HVwzMkrrBUJsE2zpsy9JWNc6NuvRJoX	23	34	34	1	\N	1781508218000	orphaned
30	3NKTgyzSZDo6Cs1h7b3tWe5HExkKtx9epaKVKBDEKh86diqynUpa	28	3NK9shKatM4NnJo4Liw7T215LmvR8FEpaa1MmUXrHEyRgMw4b3yK	57	147	MVpjm8ED63gEdtHAzUcY3MLtemRrgKfYMcJAPDAKhQA=	1	1	29	77	{1,5,6,5,6,2,7,7,7,7,7}	23167003000060590	jxnmj8MfnjfSBkATQZfGuY81a4uZ8iT64QdipYPHgyBDvu4oUYH	25	36	36	1	\N	1781508278000	orphaned
32	3NL51m5VaFZAqTX7TSByZE8hFWiHkpDyaCh4PS2kteoEYJ4yTMtG	29	3NL62Mrf3Rn4Zzjxp5RHszNVz9kb4VLJAcwodAHp39WfesEv213X	57	147	zGmnXLDxkIFP8flrk7e1RPmW0de3_gVt4Aop4lQC0wo=	2	1	30	77	{1,5,6,5,6,3,7,7,7,7,7}	23169163000060590	jx7jMZgCJLFo3U2hPY8kdBbAvc6xTCHauw7cfv8tqTMT8UayGoW	26	37	37	1	\N	1781508308000	orphaned
34	3NKaVjJtfSmezMAWTuKjpfZthHzw356sCQSS3VpmPKP6hqZCmBfq	31	3NLaWaKXvVNL3UFpaM49fTgCDmWdXr8o7McKkG6VMqYt7adebMCN	132	224	I3pNQ0LtmV6yYipfUM2xzIRUobrUuLPmwQMlmtKnVQY=	2	1	31	77	{1,5,6,5,6,4,7,7,7,7,7}	23169163000060590	jx7zj7xiawaeb2wKCsaAsrRoNtDYQJfkd7cE9Fv88YLfeE2MSu9	27	40	40	1	\N	1781508398000	orphaned
37	3NKZXZdKePZjoq7n3XPSegjgjdD3SAL6r5HzSpjoDCLthd7ZsKPo	35	3NLBxaTNQCEGdNnKpSPdknZqqeHE7dfRnYc36Ebadthun4hz4jor	57	147	Cx2rEP_uXon4UlEnxZnGNczZz6TIrTjkKKRotw5a6AU=	3	1	33	77	{1,5,6,5,6,4,2,7,7,7,7}	23169883000060590	jwoRae6qeudZxHea6RE5ZMpBjGqeAUr6nomDhrj9sCHHLjmBfp8	29	44	44	1	\N	1781508518000	orphaned
38	3NLBEofibQFdqRdnXcwWkiTGevoC77C6ams7aj4EyYiKXKmw5zMF	36	3NL5Y4MaGPdbzdtW6SbVq1oKjC2hBcqgnGy2NgfBELezPQXqhjs1	57	147	Du_hhwYzvZ3my-4xxwtDam5fH3BYs_3plHlK-AZAIQM=	4	1	34	77	{1,5,6,5,6,4,3,7,7,7,7}	23170963000060590	jxaERznRiJoM2pbUpuTjqn5y5dERnRKgiPq1aDsSaPEjnBCPFRc	30	45	45	1	\N	1781508548000	canonical
36	3NL5Y4MaGPdbzdtW6SbVq1oKjC2hBcqgnGy2NgfBELezPQXqhjs1	35	3NLBxaTNQCEGdNnKpSPdknZqqeHE7dfRnYc36Ebadthun4hz4jor	132	224	10eL2d8mZgESFoDjo6qUcL99Es7eOHSiajIuYM9PWwU=	3	1	33	77	{1,5,6,5,6,4,2,7,7,7,7}	23169883000060590	jxdKR8KGoTasei6UGTJ5bkdi1wR9qer7s9MYnMzsyvqxXBfjnHs	29	44	44	1	\N	1781508518000	canonical
35	3NLBxaTNQCEGdNnKpSPdknZqqeHE7dfRnYc36Ebadthun4hz4jor	33	3NKwvwgAC3Kg2m3W1Z9CEe6zAvLN1R4A6qiHyTRi5tXv2QjvuR5s	57	147	fy6bi9HffBfhIQJa2wSrfJyVGcGQbibe3m7MFTZXXgE=	3	1	32	77	{1,5,6,5,6,4,1,7,7,7,7}	23169883000060590	jwPMYVAg2kGvX3dMChYLk1NqgiWnjMGMqa838dkkJcZnfLFcdrv	28	43	43	1	\N	1781508488000	canonical
33	3NKwvwgAC3Kg2m3W1Z9CEe6zAvLN1R4A6qiHyTRi5tXv2QjvuR5s	31	3NLaWaKXvVNL3UFpaM49fTgCDmWdXr8o7McKkG6VMqYt7adebMCN	57	147	4Z2D1V1mbISoZSiqRQS4VPPnN4SLc1DoHUpIAVNTjAg=	2	1	31	77	{1,5,6,5,6,4,7,7,7,7,7}	23169163000060590	jwvBvHEhS8zrwx4KaF6Jb8hdvanxNGy3i41k5PySGKLzw46Hexz	27	40	40	1	\N	1781508398000	canonical
31	3NLaWaKXvVNL3UFpaM49fTgCDmWdXr8o7McKkG6VMqYt7adebMCN	29	3NL62Mrf3Rn4Zzjxp5RHszNVz9kb4VLJAcwodAHp39WfesEv213X	132	224	DtLGSdVRwoXhFXjbBCQsTLMomnrPZjRhXEZmI-H4BQg=	2	1	30	77	{1,5,6,5,6,3,7,7,7,7,7}	23169163000060590	jxed9xiCAwZ7ZMe4ccVwBamFmzfZqq9VgiCTVfrnqmd5iUZzuKP	26	37	37	1	\N	1781508308000	canonical
29	3NL62Mrf3Rn4Zzjxp5RHszNVz9kb4VLJAcwodAHp39WfesEv213X	28	3NK9shKatM4NnJo4Liw7T215LmvR8FEpaa1MmUXrHEyRgMw4b3yK	132	224	HfqcbOSH1YO5J_vYqn80hnOSJTN5eD349f-e6rC9mAM=	1	1	29	77	{1,5,6,5,6,2,7,7,7,7,7}	23167003000060590	jx3PWyUCztoy7v47a7fwKdGtHB8yZSPyAQ2yaynwGcmbf4Ye1Y2	25	36	36	1	\N	1781508278000	canonical
28	3NK9shKatM4NnJo4Liw7T215LmvR8FEpaa1MmUXrHEyRgMw4b3yK	26	3NKGNgDkQPXYnCg3xY9AGzosidgLUjCtW1voXqa8Q31WCamhwqZC	132	224	k3xCz9Wsjc5nBdmbTR5czyplhMgQSRDGqY-ac-YTJAY=	1	1	28	77	{1,5,6,5,6,1,7,7,7,7,7}	23167003000060590	jxKvwFwU2EXibg6aYVY4zT4vxdgF7QsJ9k6YSC1tKncY39kUndo	24	35	35	1	\N	1781508248000	canonical
26	3NKGNgDkQPXYnCg3xY9AGzosidgLUjCtW1voXqa8Q31WCamhwqZC	25	3NKd9H6Us1qJSxcdWJbhbneEBbnGoWVBU7y9ZqjhEtorfWGEgQyc	132	224	Vh9fdmy1GWC4_LdNzPIfwmVnyTAH0lJ419R5iwijHA4=	1	1	27	77	{1,5,6,5,6,7,7,7,7,7,7}	23167003000060590	jxMkh2hWvuNRkfpakrfNf67YnFFFkrzkBPamQHswzbZiN8DbiPD	23	34	34	1	\N	1781508218000	canonical
25	3NKd9H6Us1qJSxcdWJbhbneEBbnGoWVBU7y9ZqjhEtorfWGEgQyc	24	3NKkkfyesXo6KLx5ZKGWoZWgFmXkRzhFqLQN6qnmS4jk8LtUzLvc	132	224	sVjP1V525TfKfVfi8FCsOmCG7dT_8-fF7GGmUKBmug0=	1	1	26	77	{1,5,6,5,5,7,7,7,7,7,7}	23167003000060590	jw8xpfkpe2fsKvJ1iJ41BHiZYftQ2ZyJkwSFutiDF2Z2Xuu1g3U	22	33	33	1	\N	1781508188000	canonical
24	3NKkkfyesXo6KLx5ZKGWoZWgFmXkRzhFqLQN6qnmS4jk8LtUzLvc	23	3NLxGRVp1e67tZtgZVW4sP5ZV4MiXXxUbvmXYxYSxMg4XmZhDjzT	132	224	Tlxq_Dn3GQ9zKK-IvEF1UEATXtIaXVLZLP-ZiWqXXwA=	1	1	25	77	{1,5,6,5,4,7,7,7,7,7,7}	23167003000060590	jx8fNvAxGWSySD48JpbEtKzyEXRt5oL1epb1KHT6azpMK3iwghk	21	32	32	1	\N	1781508158000	canonical
23	3NLxGRVp1e67tZtgZVW4sP5ZV4MiXXxUbvmXYxYSxMg4XmZhDjzT	22	3NKWPY7NYAC9yvHSZYZeecmcs2deiGbhJt7iLbusrvGspbQsN3t6	132	224	TkUFR-OK7oqAr1InkEnIOthKSwmwYCJJJnvJsqxJCQg=	1	1	24	77	{1,5,6,5,3,7,7,7,7,7,7}	23167003000060590	jxZToM9a3QDRnjhznNMAM2jZYWKSvNTQQLTBobZajsudxVCrNFE	20	30	30	1	\N	1781508098000	canonical
40	3NKSaV17qDUsjDh9vRUjuSv3UE1UCrFYyAyS7dEoQLVXCcRhRZgJ	39	3NLRQnW8fU1aM78LaL43ZipynEXEsP1aDBgREN7TLFA82rkx9bYk	57	147	HpliOu1NIf1iXeHZWTfBrevRR4tapmVtjzFylkwIhAQ=	4	1	36	77	{1,5,6,5,6,4,5,7,7,7,7}	23170963000060590	jwDN12g9mdUkZxRPaECo4kmwNgo2c2yZgUxebdEFXkw2CzmRCRZ	32	47	47	1	\N	1781508608000	orphaned
42	3NKv6QzXUaCsNb65ggpgnm3GySUx4yofYs2Tx6npyiMq3uoDQPma	41	3NLkW4gXiadSXwMXwTDBa7L7KEqgoPhirAqyB9UTWvVmmUTb9ASx	132	224	3ywp9qQ5ZI2YCjU8zKsc9zR4RNjo8A4CYAgkQTLAswU=	5	36	37	77	{1,5,6,5,6,4,6,7,7,7,7}	23172043000060590	jx4NHWqZ3E8t2bNCYmaZytYvXPF8SqUYMxJTK2wK83t5TtZW6WR	33	48	48	1	\N	1781508638000	orphaned
44	3NLPgUFnC7WQMXmXA4pCVSK3bEQwEhtVKvi61w7C8yGL4pXW4Qj9	43	3NKLShq3u9QfGAw7UMceMxTMouhUumv53EHyV2QCL8v1NH9684ba	132	224	F_QZBeCFPZ_IFE3PcFgy_-FqU81hLgP_aHr5ERPNzQ4=	5	36	39	77	{1,5,6,5,6,4,6,1,7,7,7}	23172043000060590	jwnhjTvSndzRG3mokke9yvQnaYrqjzWE4rss1eSM4xWy4CS4eL6	34	49	49	1	\N	1781508668000	orphaned
51	3NKz4Mrdg14u97penBxiAkqj8T98f3wbmk9BG4gMgX3PUC9J6A2k	49	3NKpdsLCXrAQ2fu8pwzKK5ULTUeQve3VatnAy1iJm8DDXCvTwFKN	57	147	SB1LfuT3Jo4TIoejyRJO36zwD2ZtfQFr3EJTksqf4gI=	7	36	46	77	{1,5,6,5,6,4,6,6,7,7,7}	23173843000060590	jwEZRhNtE5s7RXSXkJfSPWqerH6n7CyyKdz3srYX67e15nNExqR	39	54	54	1	\N	1781508818000	orphaned
54	3NKVMPSCxQnVodgjTtSwcDEz8PhpV2amuYxcPuaDu11nvavdbDJs	52	3NKyQd1PKf8eH3yaPD8JSmiom1KEmhikb6QbbUFNCo6EFucT8Tj9	57	147	njH6oYOQt7f8UAzSdk7Ldzyl7v-KLPdd8z5I2n4FFwE=	7	36	49	77	{1,5,6,5,6,4,6,7,1,7,7}	23173843000060590	jxynTHtGRtXFG5ceCwrUSrMk97DX5gjmmwdZDyLnEKGNDe5pmCT	41	56	56	1	\N	1781508878000	orphaned
55	3NKCxs6xb8vdBNSsiCQTJyJMt4LveM2tJYCmjxw5FhGqGihHE1RH	53	3NLZtXk3FPhzitkmRH7TF6QshLzVVdwhLipW1znKMQ6tKgwNk52Q	132	224	wWHyzGJ9I0ywbCTFa-MMl2oBWY6kvG5Ynpb3EFvoRAU=	8	36	50	77	{1,5,6,5,6,4,6,7,2,7,7}	23174563000060590	jxXUVbUXBM9bYfuoBK8fjj7QAGq54Nfw37hSMtaBstLtPVY6rwb	42	58	58	1	\N	1781508938000	canonical
53	3NLZtXk3FPhzitkmRH7TF6QshLzVVdwhLipW1znKMQ6tKgwNk52Q	52	3NKyQd1PKf8eH3yaPD8JSmiom1KEmhikb6QbbUFNCo6EFucT8Tj9	132	224	p3Sw1G4E7jmSAgmvqk1uIsS72LOr6N_IZHhl1EYbrwA=	7	36	48	77	{1,5,6,5,6,4,6,7,1,7,7}	23173843000060590	jxnvErwafBmjwqjnUTnNDfVP2JC1oCnzJqkJowUpcF6zdsxGMLN	41	56	56	1	\N	1781508878000	canonical
52	3NKyQd1PKf8eH3yaPD8JSmiom1KEmhikb6QbbUFNCo6EFucT8Tj9	50	3NKLxr1B3atFDD4A6Yd1ZZD716anXbv8t5ZvxNUV6v1189ebqPr6	57	147	9x2pMXOn_ABt1Ytgr6eBmgTE7k6LMxZOsYN49vqrTQI=	7	36	47	77	{1,5,6,5,6,4,6,7,7,7,7}	23173843000060590	jx3YzESC25FypzvKc1fC7heeMCfQxVSfcCiJXLbrAHvbcsebt6j	40	55	55	1	\N	1781508848000	canonical
50	3NKLxr1B3atFDD4A6Yd1ZZD716anXbv8t5ZvxNUV6v1189ebqPr6	49	3NKpdsLCXrAQ2fu8pwzKK5ULTUeQve3VatnAy1iJm8DDXCvTwFKN	132	224	LhRN0C5c4C29d6aRiA81y7cFdP8cfipGnbTb0wuYKQY=	7	36	45	77	{1,5,6,5,6,4,6,6,7,7,7}	23173843000060590	jxKv6KT8tWS81m7H3NScRzbFsZrDfbknx9hv3WXAP6DzgBMF3Fc	39	54	54	1	\N	1781508818000	canonical
49	3NKpdsLCXrAQ2fu8pwzKK5ULTUeQve3VatnAy1iJm8DDXCvTwFKN	48	3NLxFex2juNnVTG5ed69w93kB2kmQr2sD8YP8CjBRSZX35qzHXPR	57	147	fFWBwAY32hDl5woDtoFGju9nSNzpa2OkqzuNmMNNAwk=	6	36	44	77	{1,5,6,5,6,4,6,5,7,7,7}	23172403000060590	jxLMAv2XmcZLEmVCqkPN5v1Pw2dXkCtGa1qFoS6yPXN5PxUsimB	38	53	53	1	\N	1781508788000	canonical
48	3NLxFex2juNnVTG5ed69w93kB2kmQr2sD8YP8CjBRSZX35qzHXPR	47	3NK6MgTBa3yfZrXjmcL3gb9YVD6siy9DfyroyjNKNk24TKeV94yP	57	147	sfszKvPMEh-xJ65TyvHHdfXXNDlR_OgpN3rW7L7W1As=	6	36	43	77	{1,5,6,5,6,4,6,4,7,7,7}	23172403000060590	jxZroqmSMNYqf297mM4qa1uveeePqYED2UEWqfJx8ndUoWKXGVX	37	52	52	1	\N	1781508758000	canonical
47	3NK6MgTBa3yfZrXjmcL3gb9YVD6siy9DfyroyjNKNk24TKeV94yP	46	3NKYARdXgLLwW1u1hjDaKnvsA4bTTiCLkC1xDBRAtyXFLhcGTK2X	57	147	XjaKW6jmTFvvn_6klj7zZX6Z3brEBbIUvsi0GlnhWgo=	6	36	42	77	{1,5,6,5,6,4,6,3,7,7,7}	23172403000060590	jwryVHbnrbjpkSofbLEY8dkEL4WknVQXuXhnxjTfcEpBaz6XfBC	36	51	51	1	\N	1781508728000	canonical
46	3NKYARdXgLLwW1u1hjDaKnvsA4bTTiCLkC1xDBRAtyXFLhcGTK2X	45	3NKzb9A9PYb8VDB73UD6Y7r7QJdBrc47fWEhREkmYb9qexkgehE9	132	224	S5Y-RGzj7pGIqAG6JHrTzkPTJsG85mYJ0q4h8g469gc=	5	36	41	77	{1,5,6,5,6,4,6,2,7,7,7}	23172043000060590	jxbBvSengyDPdE5wSVyhHhSxYRsqNQuonC3J9DgEVGrZWYbjos1	35	50	50	1	\N	1781508698000	canonical
45	3NKzb9A9PYb8VDB73UD6Y7r7QJdBrc47fWEhREkmYb9qexkgehE9	43	3NKLShq3u9QfGAw7UMceMxTMouhUumv53EHyV2QCL8v1NH9684ba	57	147	VGM25tS6xBuShjS7MNYmVl-xkzV8gC5YxfJzx1GfDQw=	5	36	40	77	{1,5,6,5,6,4,6,1,7,7,7}	23172043000060590	jxxHspZ2whRL8BC6D7jejwkSy9XwKordRYVGsSQNJpsLrmMN1RW	34	49	49	1	\N	1781508668000	canonical
43	3NKLShq3u9QfGAw7UMceMxTMouhUumv53EHyV2QCL8v1NH9684ba	41	3NLkW4gXiadSXwMXwTDBa7L7KEqgoPhirAqyB9UTWvVmmUTb9ASx	57	147	slpqlWbETaOzuZFmnzrU6KN9huYOvqZt7HorLvDYDAI=	5	36	38	77	{1,5,6,5,6,4,6,7,7,7,7}	23172043000060590	jwJ3PeA67C6WAnF8toysda3o9AHia4w819nrTxac38hM2x91qq7	33	48	48	1	\N	1781508638000	canonical
41	3NLkW4gXiadSXwMXwTDBa7L7KEqgoPhirAqyB9UTWvVmmUTb9ASx	39	3NLRQnW8fU1aM78LaL43ZipynEXEsP1aDBgREN7TLFA82rkx9bYk	132	224	EraFqi8kGwZzPhXm1SGUAZY4bZJ_Htl38z0BhQIHFQY=	4	1	36	77	{1,5,6,5,6,4,5,7,7,7,7}	23170963000060590	jxPkNwndfva5UNi6gwEVrtdSjaAcH9oYrjmjV4V2399nmsTzp3F	32	47	47	1	\N	1781508608000	canonical
63	3NKCXheE71vet8mjvFJPonL9ZUFYZPHbEdCgW7Ya5CTDS44qJ4FH	62	3NKmfkydaXhTgeGrTMtBECWCq11EHkja2eTNmA4QWVKLjGsUApgj	57	147	fCEJA37heZHoIIkzXqmpxA6XGLGyeuM-D40Vtj4QDAo=	11	36	58	77	{1,5,6,5,6,4,6,7,5,5,7}	23177083000060590	jy2oh6d19R4fEaXgzhY4K8vMCLmDTzozNixzniYgdnRQCWfuyXh	50	68	68	1	\N	1781509238000	orphaned
66	3NLwnCMcS6qZNJ6c8UpJb5C8kreGmmGE7B3vJZB7URnejVWhsVJc	64	3NKf2VbcuQ72C4WqViWArWmuog7LXBVfCFQYKxL9fVzPt2v1VuJf	57	147	xOM0eoDPrZE5esFoEQWzl7Bmr7whiyu3OViWQ-SB4AQ=	11	36	61	77	{1,5,6,5,6,4,6,7,5,6,7}	23177083000060590	jwVjS6kuFQcav3CYjQi7sgVyFgAjhGRum9zBnzCagNxH7SZLYHw	51	69	69	1	\N	1781509268000	orphaned
70	3NLt1DkU6ELahcDQf6URRxrH2VmXfDFD6ed45aKMrXJFwJ7MbAtA	68	3NLGq2m7MdPJc7NcQzqKivxzrSYs5gVtUY9jhja17ZVDRTU4vkq1	57	147	S5n9onLFcP8S3ZEzssD30-Rnw1XdYaivvRftHe_l1gU=	12	36	65	77	{1,5,6,5,6,4,6,7,5,6,3}	23178163000060590	jxE4VjNvRhDXmSsRnSmF2QWU8MDLRfZLqCY69vPgFNyJzR3yzfg	54	73	73	1	\N	1781509388000	orphaned
72	3NKha3zVcGLUWsz3twWoWHWGmzUqKdimFfkyfPYgCs95w6MMb7Lv	69	3NLgNn3N62eb6zUoMowgJzUZwAYPNYHF9gpkLk4rtbBPKHTPs5tx	132	224	TwhxZRV6IR2Pt8ZvNMhLqn1YInAp_MiUd-W-zOOlhgM=	13	36	67	77	{1,5,6,5,6,4,6,7,5,6,4}	23179243000060590	jxPn7jmYQds7XjsKPNULU1hWYHrt9ADDev2qjzVqQ3SLZ4ZDm1S	55	74	74	1	\N	1781509418000	orphaned
71	3NLjLj6z2tt7tHP6zRki65k5MQjq3mAPgEXjjMdiBXGonj2EDEV5	69	3NLgNn3N62eb6zUoMowgJzUZwAYPNYHF9gpkLk4rtbBPKHTPs5tx	57	147	RAwZkHeX_LtMexSZMZivPfFSzswe6kwwZMhMqfpTUAc=	13	36	66	77	{1,5,6,5,6,4,6,7,5,6,4}	23179243000060590	jwSgTisismp487dznaneQM34BnDkBDYCLYkUJ4Xt1HhpxyN6iHF	55	74	74	1	\N	1781509418000	canonical
69	3NLgNn3N62eb6zUoMowgJzUZwAYPNYHF9gpkLk4rtbBPKHTPs5tx	68	3NLGq2m7MdPJc7NcQzqKivxzrSYs5gVtUY9jhja17ZVDRTU4vkq1	132	224	DGDzuhWVSLqATmZ0yEF9BanObHzhYsK_JDI4og984Qw=	12	36	64	77	{1,5,6,5,6,4,6,7,5,6,3}	23178163000060590	jwPuiZANgypahUjNRDuMx4ZzPCTSSXhPzzJwqCLL6F8A72nxWJs	54	73	73	1	\N	1781509388000	canonical
68	3NLGq2m7MdPJc7NcQzqKivxzrSYs5gVtUY9jhja17ZVDRTU4vkq1	67	3NLGFYpf5boXY5jhhEuHPQJDKActiQALCRsdV6PgVDunDK2f5b2D	132	224	DsNiHxc01lPS8HxBsV0Yx2lzV4SY1Oh62HcpefmyqAc=	12	36	63	77	{1,5,6,5,6,4,6,7,5,6,2}	23178163000060590	jwNgA67zAQCgQxqfKmGwwAmLB6YUxqTvCuWq3ryZmLiZf5vmafm	53	71	71	1	\N	1781509328000	canonical
67	3NLGFYpf5boXY5jhhEuHPQJDKActiQALCRsdV6PgVDunDK2f5b2D	65	3NLreCfY3D5md7RAcDpBmLxxgNkgdi1JaVQisH5RovPwrnf5ecmo	132	224	vw_dJ9auKsSYsGZltljm6F_RuKk2_mJrBMYr1zW34w0=	12	36	62	77	{1,5,6,5,6,4,6,7,5,6,1}	23178163000060590	jwjNvTv2pxUu89jFbmMibV4ahCYEWHVRDf9KoShUsXmkABAgRpt	52	70	70	1	\N	1781509298000	canonical
65	3NLreCfY3D5md7RAcDpBmLxxgNkgdi1JaVQisH5RovPwrnf5ecmo	64	3NKf2VbcuQ72C4WqViWArWmuog7LXBVfCFQYKxL9fVzPt2v1VuJf	132	224	Kd_zN8UVFeWpUrNQs1m_3tdClNlXlMb5r_Iexj6BCQk=	11	36	60	77	{1,5,6,5,6,4,6,7,5,6,7}	23177083000060590	jwb1vFxcwjMn8j3K7FDRnVjb5Un6ZkoM8zkcatXJi4bJWA4VW24	51	69	69	1	\N	1781509268000	canonical
64	3NKf2VbcuQ72C4WqViWArWmuog7LXBVfCFQYKxL9fVzPt2v1VuJf	62	3NKmfkydaXhTgeGrTMtBECWCq11EHkja2eTNmA4QWVKLjGsUApgj	132	224	l6uj5PNB8Ob4lnNE9CErKJDMs7hvbJAJxh_qdJcGMAo=	11	36	59	77	{1,5,6,5,6,4,6,7,5,5,7}	23177083000060590	jxQQsaXrt6tunvunuVVzaUZRamauWzcPkfQxEUTJdgPcrBxH3cZ	50	68	68	1	\N	1781509238000	canonical
62	3NKmfkydaXhTgeGrTMtBECWCq11EHkja2eTNmA4QWVKLjGsUApgj	61	3NKL7cRQSeZUcCFPgomfYKpFNuj2WfKWHcF3GwTVSePmXuVw9sMv	132	224	pa08EcC08BS4a3ItTMZmjSB7QKc0LM-rKKYsjCQVIQo=	11	36	57	77	{1,5,6,5,6,4,6,7,5,4,7}	23177083000060590	jxwVNtnkWfdR9Zzsj58Zv3XP4QxArJQy1hxpmURBnSRXwrPfBdx	49	67	67	1	\N	1781509208000	canonical
61	3NKL7cRQSeZUcCFPgomfYKpFNuj2WfKWHcF3GwTVSePmXuVw9sMv	60	3NK7fi76UsGthEFvNwD3SsmSwejBEHiQCYRgrRzXbnnvxmTJyFVo	132	224	_YRjrAun3JAd4YzkvbPQI8DpBX90F5bDlBaQ5JfEOwI=	10	36	56	77	{1,5,6,5,6,4,6,7,5,3,7}	23176003000060590	jxsMJ3P8qeDuhiYgYjFQ2KPn7uTsndxPceBjHQM6ZZnveQV6YEN	48	66	66	1	\N	1781509178000	canonical
60	3NK7fi76UsGthEFvNwD3SsmSwejBEHiQCYRgrRzXbnnvxmTJyFVo	59	3NKdGhaqsHP7155dK34Zwqx1PgruXeFyTdVrEr8Pte8eDtBBRC1f	132	224	L2WgrwgTDXOpA9w5KnJKB4-EOuQAQsHRHggp9KjbGQU=	10	36	55	77	{1,5,6,5,6,4,6,7,5,2,7}	23176003000060590	jy3KSknM9vsmEt5BBLimWtfXNonWZRzyjCQubPP7N6GuF2XVPJ2	47	65	65	1	\N	1781509148000	canonical
59	3NKdGhaqsHP7155dK34Zwqx1PgruXeFyTdVrEr8Pte8eDtBBRC1f	58	3NKm5TWd8Qc7vFJ94jZ7VeigffjBfhVTbrWfFYsbfd5V1fWnsC6t	57	147	LKuaPmg7n0ISqgpG-oFmAwnwQKOK11S9qHJ4D6s_OQE=	10	36	54	77	{1,5,6,5,6,4,6,7,5,1,7}	23176003000060590	jxiVYjqxgHAwRVa7rc6UZVzhxEziPaQDewWZihxL1mW9ZxuviwR	46	63	63	1	\N	1781509088000	canonical
58	3NKm5TWd8Qc7vFJ94jZ7VeigffjBfhVTbrWfFYsbfd5V1fWnsC6t	57	3NLJ9aMRt5uRAd8ZBj9HmSnNRy6bKmkXs4EYNkTDnfHPfe4KZiRd	132	224	MYct_SJ6kpPmrMcH0_e5pv5Qkf6w_s3SWL1XJNdr4g8=	9	36	53	77	{1,5,6,5,6,4,6,7,5,7,7}	23175283000060590	jwA2dJgZ3XNbJcaNZ4TZXGrykUAaG4bTeskF54N4j79vMnTLJn5	45	62	62	1	\N	1781509058000	canonical
57	3NLJ9aMRt5uRAd8ZBj9HmSnNRy6bKmkXs4EYNkTDnfHPfe4KZiRd	56	3NLfJ6AQqkWKtLGmzDbCCsPC4FhPR8VKRPNAeU6gd7shf3RB57sr	57	147	J9Ww0sMmRH2bTA6jRc_MceiB26jh0FB_BS1mrYT5WAI=	9	36	52	77	{1,5,6,5,6,4,6,7,4,7,7}	23175283000060590	jxAscJ4fMRBueBKFVfU86camXrSNQJi3JaAbBTNMx7hrEsgWvHZ	44	61	61	1	\N	1781509028000	canonical
74	3NKweKKhzKX8XkHSgUn9cscBGpC1rBg7Q4qQyAtgMG5wEyJmBM1P	71	3NLjLj6z2tt7tHP6zRki65k5MQjq3mAPgEXjjMdiBXGonj2EDEV5	57	147	GLcax8bYHB92G9Qlmblux7KAm0YgOEAuwsgD0lcmZgk=	13	36	69	77	{1,5,6,5,6,4,6,7,5,6,4}	23179243000060590	jwJWx5TMjGcy6JgaqFbAWZp6nQRrPWKcjHzjQS5Z4swiLNUmgrv	56	77	77	1	\N	1781509508000	orphaned
76	3NLFubVuVmq1U9V5z48hwDjBKxonQ4YLbh5gNfHHXzjVxHhLgFqQ	75	3NKNQy96ewZn99AcPQgxNAsGVYQmfku7N961mwtDG9Dhtg2ecQqb	57	147	E9lJGQWSUpfxTvpzou8zE-h1pXPJSjpRS239h4J0VQc=	14	36	71	77	{3,5,6,5,6,4,6,7,5,6,4}	23180323000060590	jx1Fi1GSecXvUioMJUVxeySUAvsQDJzKipNosxXmEstBTs36NTk	58	79	79	1	\N	1781509568000	orphaned
78	3NKChmpGfMNcLEcKWLNbtMrSwEPiLKRrmdp9NmwAW4Jpxtyeoce2	77	3NKWCpyS7UCGYQx78sWhbL8GPrkZkzgN3BffcNTWbWoD1PGn24VF	57	147	eKZcDIjjFrmefzEc-js_440GxEfOZm3Gzo0WFAtbeQ4=	15	36	73	77	{4,5,6,5,6,4,6,7,5,6,4}	23181403000060590	jxNBMDE9qMFsadMnsnsgiZJZaNNWDw3jeG4KwYse3g6ExhkT91X	59	81	81	1	\N	1781509628000	orphaned
80	3NKeVkcxhNPZ6pkDVke51MyYykXoPZVHD3f7eKbTUzy2KwALVwHq	79	3NKqMY748wW5sng3MER8TN3PpXhs96rJDmHKMmGfM7Js7VNXNF8g	57	147	u_vraF-0JNbVJYkSP-0nKUeojoOWYNcYR6QGVS-uJAs=	15	36	74	77	{5,5,6,5,6,4,6,7,5,6,4}	23181403000060590	jwqQvNLejri7pLh8541h92pWywtrB5NK9Jwm5ykaLkFr2ahpY2E	60	82	82	1	\N	1781509658000	orphaned
85	3NL4j8qpV4ERrr9D2WSS3KNvhFS4zMvJdgFK25LjcQJwidX4jeKb	84	3NKbcpDgyiKmvtsmWDYSnbSqJ8bdQU8NupPLXaUnQm2ZL597yyH1	132	224	RuylILyr59Q7prMYIF9AkbFEvXAx-CLWBuHjA0Ph7g0=	17	36	78	60	{6,3,6,5,6,4,6,7,5,6,4}	23182843000060590	jw7WAV8SKnK4ooWvUd6LzgxTsoJKRgdxcquoC26dpFj9AyhM7vx	64	86	86	1	\N	1781509778000	orphaned
90	3NKbim4x4gvMxrn6gKM76FhGaG6WCvjWXfGgCtszLim854HSgoV7	88	3NKMm1iB8vePswQg1RJPdZHGA2ge73Xy9VZr6ku7mk9EgAB2xqUE	132	224	Xu4jXk-13h7Wc8DH5uIigX7p6nTnkfmiptu4rJw6dQw=	18	36	81	60	{6,6,6,5,6,4,6,7,5,6,4}	23183923000060590	jwPQMpVwuTUEnXXAcXiLXYgQZqrBKKeVkC79MSRreFgTQ7SFrcM	67	90	90	1	\N	1781509898000	orphaned
88	3NKMm1iB8vePswQg1RJPdZHGA2ge73Xy9VZr6ku7mk9EgAB2xqUE	87	3NLiA2cACWvES1u8EM5knbx6JGt2HUVwPmpRnD3d1yk4eNzFbuFf	132	224	uJvmMgjDnJsd8OthL-KmXf_sg7Rl4I6gfxWTuirsCAI=	17	36	80	60	{6,5,6,5,6,4,6,7,5,6,4}	23182843000060590	jwaEQaDPTeMXaDHR7MNWwNsfhmWynNKSZMTACSn2DuY12JTXY3E	66	88	88	1	\N	1781509838000	canonical
87	3NLiA2cACWvES1u8EM5knbx6JGt2HUVwPmpRnD3d1yk4eNzFbuFf	86	3NKK1mZPVEQssu22xLNHcyoirn3B21x4pPurxkJiRMy8MutgyZFz	132	224	Hwp3X-Eizkq6OEiucarPF6TtR1WRGBiy_EieOWjQYQ8=	17	36	79	60	{6,4,6,5,6,4,6,7,5,6,4}	23182843000060590	jwKLJv86jiajf5o9QMdM1wZN2TNuzqN19DnKKPTrpHgHhZChffA	65	87	87	1	\N	1781509808000	canonical
86	3NKK1mZPVEQssu22xLNHcyoirn3B21x4pPurxkJiRMy8MutgyZFz	84	3NKbcpDgyiKmvtsmWDYSnbSqJ8bdQU8NupPLXaUnQm2ZL597yyH1	57	147	7C0JbqaTqbsT-O-K4bYsWyOCYUfsNAP3G907gt0CEAo=	17	36	78	60	{6,3,6,5,6,4,6,7,5,6,4}	23182843000060590	jwZAyZKPVeyMzbwBFPBtF5PJfvCZH2j76bXUiPh3ShTEW7DMLxY	64	86	86	1	\N	1781509778000	canonical
84	3NKbcpDgyiKmvtsmWDYSnbSqJ8bdQU8NupPLXaUnQm2ZL597yyH1	83	3NKwSevt8vzoD91NBZS5ayGvCJBqnvtCB4RUPUvNGfhpkT7EBa6n	132	224	_pnpjTgoR0qn26nHfb29hOuu63A9Fc4nGw8ZTDDJ-wg=	16	36	77	60	{6,2,6,5,6,4,6,7,5,6,4}	23181763000060590	jxmiELwGNHHKDbcvBKuYg7F5h4RvoYYwV3rqWaqpckRosWf8LKw	63	85	85	1	\N	1781509748000	canonical
83	3NKwSevt8vzoD91NBZS5ayGvCJBqnvtCB4RUPUvNGfhpkT7EBa6n	82	3NLWqozM5or8ix35epaDBUF128gCWx2wdP9mvPjQ6E5ATaaf1qCe	132	224	Awldg8HnY4pmqJHdJn3fz5kfBLok0HkRxDAkGVJkVgw=	16	36	76	60	{6,1,6,5,6,4,6,7,5,6,4}	23181763000060590	jwTP6uYvoqk4GoKyaYC5cgdVYWZJej3sTuPm6iMDs29itFUCJRF	62	84	84	1	\N	1781509718000	canonical
82	3NLWqozM5or8ix35epaDBUF128gCWx2wdP9mvPjQ6E5ATaaf1qCe	81	3NLpSuQrEvHuntJ7vsrgmqtP2PRCDx5x3eWTRvzeL9awvV75QLeJ	57	147	vGHFzLKV_QuQQP-eIrPvHn8LN8wRw3uYO3Gd6Ww2ugY=	16	36	75	77	{6,5,6,5,6,4,6,7,5,6,4}	23181763000060590	jxKT3q4DzEbT6p3voASZMndPjwSXFGWQUFx2kGFhsH2UXJJzCtB	61	83	83	1	\N	1781509688000	canonical
81	3NLpSuQrEvHuntJ7vsrgmqtP2PRCDx5x3eWTRvzeL9awvV75QLeJ	79	3NKqMY748wW5sng3MER8TN3PpXhs96rJDmHKMmGfM7Js7VNXNF8g	132	224	aJZZoj708SnuIdOk-VzzWY_0_lP_0c9lhbQq7S6clwg=	15	36	74	77	{5,5,6,5,6,4,6,7,5,6,4}	23181403000060590	jwM1VZJsRYcmVFTRAiW8nDWMpZkHSui8LWVFUt4EDcpFErEECcc	60	82	82	1	\N	1781509658000	canonical
79	3NKqMY748wW5sng3MER8TN3PpXhs96rJDmHKMmGfM7Js7VNXNF8g	77	3NKWCpyS7UCGYQx78sWhbL8GPrkZkzgN3BffcNTWbWoD1PGn24VF	132	224	5Zn60TjVmuomn29CJCJyTJ22-PsO0RoYFeYSin69kAE=	15	36	73	77	{4,5,6,5,6,4,6,7,5,6,4}	23181403000060590	jxp4vBHxoeVkCMCTW6PCPoRmBi1Wzx4GPAdeYkUaFb7SwnqBxi3	59	81	81	1	\N	1781509628000	canonical
77	3NKWCpyS7UCGYQx78sWhbL8GPrkZkzgN3BffcNTWbWoD1PGn24VF	75	3NKNQy96ewZn99AcPQgxNAsGVYQmfku7N961mwtDG9Dhtg2ecQqb	132	224	NpXMjdD2H-2CI2BWGT1MG1SOAfV1lCZl5LXQaS_AoQk=	14	36	72	77	{3,5,6,5,6,4,6,7,5,6,4}	23180323000060590	jxENLQgd7CsP3RgrGzE8ydRvuH8QwWhDBK1S6LMxcn6JwBZ3TUp	58	79	79	1	\N	1781509568000	canonical
75	3NKNQy96ewZn99AcPQgxNAsGVYQmfku7N961mwtDG9Dhtg2ecQqb	73	3NK8jXoEaYgmNNsNqFoPfTCDgZi7bdgy7Bx93r9SJy7xV3zvqcYQ	57	147	63UXRzDaEXuQM6OmCg8NvCgcbYz0wX7E4LckVtdB6Ao=	14	36	70	77	{2,5,6,5,6,4,6,7,5,6,4}	23180323000060590	jxBwQwdBjG8JaecSDZG1k9z3cpkJ67h6q2Dhu7xx96b5S7zpneJ	57	78	78	1	\N	1781509538000	canonical
92	3NL37WSW6FfdRphEw2DKJ9DXGNvBZ3U8dbKA5Zo8dSKtZt1apGFE	91	3NLqwjbG2b7AywAZnf1UrwnSPdTLPSTsLrjai1XPHeUbv2CFHcwq	57	147	d7gHrjur423fiJo-VJCkeuRwls_ma2AiTeh0juL2RQg=	19	36	83	60	{6,6,2,5,6,4,6,7,5,6,4}	23185003000060590	jwbu6Xtb5pTe7MLbha8d6GtF41nVvDPUk3SZbbZYjNJ3Ho79SN6	69	95	95	1	\N	1781510048000	orphaned
96	3NKEtnovyogn9TwB1xnQqJqyiw123yyq6xZqjoVXynpnMXnTKB74	94	3NK3xLpLj6cwD7qxNx2msGjUi7PCPLAayhHVQKZdL2HMpYy6B6Tx	132	224	_f4ITD7o_GOe18nmlMahz6JcPMh8JrsB6lc2dkflMAY=	20	83	86	60	{6,6,4,5,6,4,6,7,5,6,4}	23186083000060590	jwZ9rgQeAc94fXd2rUSHm3QzDgbPiCDh6mbAqh48ionRMktkRgU	71	97	97	1	\N	1781510108000	orphaned
99	3NKNCEGjXb5C7eaLWM9BgpJRyqFWx43afCZUg5iDL4r9Vzsn7eZp	98	3NKugbT6s52N1iZeasxRBAdpaqeAShuunL4q2krtME8917QrfC4g	132	224	2JyA8h9QkdYJxPiclwbU_K3ZBi0KlCwZdiRFIJq7bAg=	21	83	89	59	{6,6,4,3,6,4,6,7,5,6,4}	23186443000060590	jxrS98WsosGQHb6V2ZFnuoQzoHp5vENtaoEvGvBAb13uiRy6QkS	74	101	101	1	\N	1781510228000	orphaned
103	3NK3Xm3vgUPv5MzLPfFdCk2KzZXSGZEHgM6mHBV4XXX9SSzzZURe	101	3NKL2kXwPucxgkZ9Dm3E76coTGy1fWZjoYejWdKnEu77HnhmsQay	57	147	DrPiTOWbajE_2HSUMeWCMUKviqZMrdXmY6W6UkmDAAs=	22	83	93	59	{6,6,4,5,6,4,6,7,5,6,4}	23187163000060590	jwKWteuSR9CvxaDomDb7bWDpxxgywv6Q9gUuqwJB32Jf9RX9H2Q	76	103	103	1	\N	1781510288000	orphaned
106	3NKgNymJAAtvAA3DqgTCEkRwmKHZZ3n5Gjjha3aCBdS3R4DDC7nN	105	3NKmY2xDjHKEMTGeMmCDzb92Ahtw9PGK9N1gTJp3cGvFWJhUvdNL	57	147	b33yyP4AbUBkGMUGpx90huBsLznl_I2nZhJFWSfKog8=	23	83	96	59	{6,6,4,6,2,4,6,7,5,6,4}	23188243000060590	jwZ2f9ZM3u21hwY7E28RmDxS1uB42r5VG32JADsGZndbuiXKNa2	79	107	107	1	\N	1781510408000	canonical
105	3NKmY2xDjHKEMTGeMmCDzb92Ahtw9PGK9N1gTJp3cGvFWJhUvdNL	104	3NLd48zBg6j3pC6fZtP2dXm5ZNFJMFxuWMumyk7on5tLos8fbZGq	57	147	PMARuIIGuWeNMB-nY_l4zu0EMLwCaC3z00fwRvtwNQ0=	23	83	95	59	{6,6,4,6,1,4,6,7,5,6,4}	23188243000060590	jxMo1UxfqcgTDsjNTg8vXh454AXDw3dfCeHX4m6yq1QE4pbtSsR	78	106	106	1	\N	1781510378000	canonical
104	3NLd48zBg6j3pC6fZtP2dXm5ZNFJMFxuWMumyk7on5tLos8fbZGq	102	3NLrPM2Zs8gRUVT4BXQj1xZLv1Dw9Kb1EW6GDeHBQTQUnGvYK7vS	132	224	XSLSlKUFMCMmBmyTkltOpJDYZHXAZBDdpK7QVoEyyAI=	22	83	94	59	{6,6,4,6,6,4,6,7,5,6,4}	23187163000060590	jwpf9N7PJczd5GyaogJBAzh4TraVsvsm6aVXtFRFhGRqritMWUw	77	104	104	1	\N	1781510318000	canonical
102	3NLrPM2Zs8gRUVT4BXQj1xZLv1Dw9Kb1EW6GDeHBQTQUnGvYK7vS	101	3NKL2kXwPucxgkZ9Dm3E76coTGy1fWZjoYejWdKnEu77HnhmsQay	132	224	zbIRR1Xwz5hKo3bjlF5U4Ovj_ulAeFCC_p1DbDEL_Ak=	22	83	92	59	{6,6,4,5,6,4,6,7,5,6,4}	23187163000060590	jxxb4USZ16UMwaxCDg7eCULmmnbkUogKTrjsKq8dnpRnUs3miz2	76	103	103	1	\N	1781510288000	canonical
101	3NKL2kXwPucxgkZ9Dm3E76coTGy1fWZjoYejWdKnEu77HnhmsQay	100	3NKsQk9jrxSkvC2W5F98VUgrzQSYbVFTLU5Nyq5hNjQMF95zzqqw	57	147	yr_qoBuuxe4jndyBI_klxmI30mqk2FqSf4DHz84n8wQ=	22	83	91	59	{6,6,4,4,6,4,6,7,5,6,4}	23187163000060590	jxMNHJHVhMWSdbySKxQ9Dp5xiT4YPTMCgvwBZ2cEJWowpRPYWNa	75	102	102	1	\N	1781510258000	canonical
100	3NKsQk9jrxSkvC2W5F98VUgrzQSYbVFTLU5Nyq5hNjQMF95zzqqw	98	3NKugbT6s52N1iZeasxRBAdpaqeAShuunL4q2krtME8917QrfC4g	57	147	aZT4V7t8KNMPulUZiUaqPzqlMO3FZG7S4LNU-uduhws=	21	83	90	59	{6,6,4,3,6,4,6,7,5,6,4}	23186443000060590	jwj2GWRkgeKk9pjrWpeZxRZscdZSjMfipR3jFi3QdoK5CeYPn9y	74	101	101	1	\N	1781510228000	canonical
98	3NKugbT6s52N1iZeasxRBAdpaqeAShuunL4q2krtME8917QrfC4g	97	3NLWqk3oqohhvfWHqU9f4zrxpYYw9UvQev1YvPd38Um1BEkBngHY	57	147	8EJDa594zuHPsB2F6KWg9_j2T7WUZOjpd2dqmK7VCQM=	21	83	88	59	{6,6,4,2,6,4,6,7,5,6,4}	23186443000060590	jwv8vbvrsJK3txo3o4BBwEcAzf6zLa5DAG5DgumXfQV99KQMer4	73	100	100	1	\N	1781510198000	canonical
97	3NLWqk3oqohhvfWHqU9f4zrxpYYw9UvQev1YvPd38Um1BEkBngHY	95	3NKzw1qUU27jTn8GJoVhMfEs14R2XTpy6MM2orbJNwUCsMCE2srE	132	224	xCGFq6Y70P8YCiB4kaUrgqFefg9igIZ3VJ2K-dialAI=	20	83	87	59	{6,6,4,1,6,4,6,7,5,6,4}	23186083000060590	jxUWFodc2dvs7AKPXPSoafcX6sA2uYUgtXPwETppYagaEqNbJGi	72	99	99	1	\N	1781510168000	canonical
95	3NKzw1qUU27jTn8GJoVhMfEs14R2XTpy6MM2orbJNwUCsMCE2srE	94	3NK3xLpLj6cwD7qxNx2msGjUi7PCPLAayhHVQKZdL2HMpYy6B6Tx	57	147	A9G7Yz7yVe9Yg0IIGS1ij7Q0uOWW49XXsjbLKB0GfwY=	20	83	85	60	{6,6,4,5,6,4,6,7,5,6,4}	23186083000060590	jwqv1o7TuUjvQSV1ihpSm3qkYifqqBssMrGbykCZd5hEtf7c4aE	71	97	97	1	\N	1781510108000	canonical
94	3NK3xLpLj6cwD7qxNx2msGjUi7PCPLAayhHVQKZdL2HMpYy6B6Tx	93	3NL4RbFLjKT7L4VVn7DEMMfrxP7NwFiDCNSPanmbTDqjAzGgz5tD	132	224	6SECSd_-TqP7TRmSwX7HJqEEm2-nxu8RQBP_1wOsHAQ=	19	83	84	60	{6,6,3,5,6,4,6,7,5,6,4}	23185003000060590	jwfr8vNpYN4Kqq1WKDcEh3ttVs2BNVHi7GgYAx1ne79qmd2ZZnM	70	96	96	1	\N	1781510078000	canonical
93	3NL4RbFLjKT7L4VVn7DEMMfrxP7NwFiDCNSPanmbTDqjAzGgz5tD	91	3NLqwjbG2b7AywAZnf1UrwnSPdTLPSTsLrjai1XPHeUbv2CFHcwq	132	224	6gtqVARDIn3dVw9Dx10q3hKAfPN1trsNw4NcZYNzego=	19	36	83	60	{6,6,2,5,6,4,6,7,5,6,4}	23185003000060590	jwdjVPchYCDqbVrviMcyA46tR435mzDkKYRSC2LuxftWpwJi8AB	69	95	95	1	\N	1781510048000	canonical
91	3NLqwjbG2b7AywAZnf1UrwnSPdTLPSTsLrjai1XPHeUbv2CFHcwq	89	3NLeWtbyfKVejnvYSVX7G4goUytaaGAe1y5bv3g68CwCVFFNwwEW	132	224	qbk6nbTPs0kARwbvdf2PtkJjxtN9SksPljem0sFHzAw=	18	36	82	60	{6,6,1,5,6,4,6,7,5,6,4}	23183923000060590	jxhRGcvjpBERyLy3QziMycCs2Gn3XSfpN1r5xRJUThkuGadcp5w	68	92	92	1	\N	1781509958000	canonical
109	3NLbihn6cWQQzhGEkaxmvGPMeTQZmcfZFSrUW1SJrak3Y5pxLv2i	108	3NK9sPmmgHoNkwfRHWgaa7ras4LSfUwjznD3zjo4wB87Mfmqhx9J	132	224	243rZtJpaSzk2rlasSmjWKLr2cAvei-RRt4rzXVBBQE=	25	83	99	58	{6,6,4,6,4,1,6,7,5,6,4}	23190403000060590	jwdSAiLa7SDJD2xUvH8NjK3wVXv3vKqCDPVgoyxS33a4TBzp6Dk	82	112	112	1	\N	1781510558000	orphaned
112	3NKGfKc5f2na5WyE53vkR2zkona64ij9G2ucLGtRrNwWyTQkT5cR	111	3NKPwdmJthjrQRukvP2JUst7VgzPsMKq1jhZt1K234hUYqoQpfxr	57	147	KLC2--vrUGnaUtvBHdKb6F4y2KTHbmD0LGNNoSw88QI=	25	83	102	58	{6,6,4,6,4,3,6,7,5,6,4}	23190403000060590	jwbgN1xRnCx7L7aQxSathas83YcVe3J4SZMqtFwueoCVEoJkxW4	84	114	114	1	\N	1781510618000	orphaned
115	3NLhWQ42sZXwaF7GPyMjrPRxUVyVgTh7JXHwZ6FyBLLcK2pyWonq	114	3NKdPQcsTYR7HvVJYnxJs1aw3yqiCaWEChzFQbvTAQ8p638W6o69	57	147	A_0JDZwRZ-g3d61vXfeTioMFt55ZZn-fwWJAABzNSQk=	26	83	105	58	{6,6,4,6,4,5,6,7,5,6,4}	23190763000060590	jwNbg5qvaaXAZeyhiRA7gVGCFEKfwjkDnLqwHRHMSxTvnx4ZmKe	86	117	117	1	\N	1781510708000	orphaned
122	3NLcK5qVMy2Wd7GANF2fvz22z2ovYSKUg7uKwLEk1aLAmMZUVing	121	3NKMy5GHxtvAr9qNnjUuVszmgwDUG1YHUjTBKiiD2vK7UuYS5bAB	132	224	IkWubkEWYvnOYvlM-j3J-GEzmLvL3wQl2tykXrTLVww=	29	83	112	56	{6,6,4,6,4,6,2,3,5,6,4}	23192923000060590	jwNtaZrjZAeAPX3HjeQ4CmwLu88sC7qF1kYU5zQdrX4BVJsYkiL	92	129	129	1	\N	1781511068000	orphaned
124	3NLdGhKksBpGmBkG1SQ6KV36YqonFLLGgfsut83CrhgDdPWbnGyH	123	3NK862ynHqAtM3RBPXbCtyrjRA8LhMs8M4ELpMrAenCYNoxQZWih	57	147	X5WoUjOq36p8IQ3EvLJeZMfq4SoTN5gKQNUksntZrwg=	29	83	113	56	{6,6,4,6,4,6,2,4,5,6,4}	23192923000060590	jxSWUv3Q1gr7qD4z5skNa8ZczieSBzXmeUDZQTcKLPTj5uGZjmx	93	130	130	1	\N	1781511098000	orphaned
121	3NKMy5GHxtvAr9qNnjUuVszmgwDUG1YHUjTBKiiD2vK7UuYS5bAB	120	3NL6MPb5BBCLn7Evh5iRSdoESkGnHfmx5pSAfX5ZQcaDzjjcPMgN	132	224	4jKBB5aDgisGNcI9j_maRuhS0MPJ0-8edF4Wf8M1lQY=	29	83	111	56	{6,6,4,6,4,6,2,2,5,6,4}	23192923000060590	jwGqf1J2fUX9GfsQcRwUNMKfHthRmER2CJPRS61vg3jNPBKfWMJ	91	127	127	1	\N	1781511008000	canonical
120	3NL6MPb5BBCLn7Evh5iRSdoESkGnHfmx5pSAfX5ZQcaDzjjcPMgN	119	3NLLY71i6mKExBj8F14J4Z71aM8zGTsy8WMyAAbvo7aymgsdQGiR	132	224	gh1qHYOb4fa_06JA4u-MczJsPzaHVYHyMkKdycH6gw4=	28	83	110	56	{6,6,4,6,4,6,2,1,5,6,4}	23192203000060590	jx8RDufEQY9Vm1Bzm18uxrT84sEwcyJkPCF35VtNk2rqaXQB5XY	90	126	126	1	\N	1781510978000	canonical
119	3NLLY71i6mKExBj8F14J4Z71aM8zGTsy8WMyAAbvo7aymgsdQGiR	118	3NLRhNHJuHZZmSD4Zq8JkvZL5FpkCRQHgfkNG3zbrCbjki8fPajg	76	75	3nMJmFozguM4X42JQ8nsSJ6CqLqybFF4OQSvhYTjEwA=	27	83	109	58	{6,6,4,6,4,6,2,7,5,6,4}	23191483000060590	jwYDiVDjTKm19kyA77XYeqSrDzAuDtVnvc1tBxY1UBdnPK5gpW6	89	122	122	1	\N	1781510858000	canonical
118	3NLRhNHJuHZZmSD4Zq8JkvZL5FpkCRQHgfkNG3zbrCbjki8fPajg	117	3NKDsSaSdXBk4fCnnd3bbZJ4n7Jf6XKbcxpLBxVXhTVVLQcZ3cJT	132	224	-uHH2h6gb8L0e7RQco-_vppp3tPSmqOylkxi_ytrdQM=	27	83	108	58	{6,6,4,6,4,6,1,7,5,6,4}	23191483000060590	jxGqXDwna5LDAFgtn1suegSNjgcsVdJct6XxAhpLbTY9CjWJekk	88	120	120	1	\N	1781510798000	canonical
117	3NKDsSaSdXBk4fCnnd3bbZJ4n7Jf6XKbcxpLBxVXhTVVLQcZ3cJT	116	3NLjXASvew4q1ebEZTaXwvRTkYDNS8RSoyU4CDA7UpeHMeftzAet	132	224	gSC4NBxdbXD8NajCYBFyEFWK05KByMIqh2eer9zadwU=	27	83	107	58	{6,6,4,6,4,6,6,7,5,6,4}	23191483000060590	jx1kHEnWJq4PxJSNfjKSNcDKxBRMdTi1CZeEGDZD8opQJnSGTun	87	118	118	1	\N	1781510738000	canonical
116	3NLjXASvew4q1ebEZTaXwvRTkYDNS8RSoyU4CDA7UpeHMeftzAet	114	3NKdPQcsTYR7HvVJYnxJs1aw3yqiCaWEChzFQbvTAQ8p638W6o69	132	224	9b0zUUOAcVr5TRIfu8itnYskCtKI2DcK4W9GISl8RgM=	26	83	106	58	{6,6,4,6,4,5,6,7,5,6,4}	23190763000060590	jwAYKfUEmQ85Jx4pVUdLKgFjYJZMoRrAz6p27pXjEMr8CzM8Hxw	86	117	117	1	\N	1781510708000	canonical
114	3NKdPQcsTYR7HvVJYnxJs1aw3yqiCaWEChzFQbvTAQ8p638W6o69	113	3NKS7o7eH5yF3poMviwbC8hk5R8B431fQ8B64tCdJ2w5ccikv3Q6	57	147	HQtd4aKT-gBVv-_rkCl-nQxF5D9zUCS-2fYrTu0fmwI=	26	83	104	58	{6,6,4,6,4,4,6,7,5,6,4}	23190763000060590	jxwrD8SQT5TKjagk1VyaZzTzwqipZkmoAfsJHpWoNZeh8YPyymk	85	116	116	1	\N	1781510678000	canonical
113	3NKS7o7eH5yF3poMviwbC8hk5R8B431fQ8B64tCdJ2w5ccikv3Q6	111	3NKPwdmJthjrQRukvP2JUst7VgzPsMKq1jhZt1K234hUYqoQpfxr	132	224	1GN7WNv8UUOA03M-oNwM_G1GzPYFM0SEGurmO36R9g0=	25	83	103	58	{6,6,4,6,4,3,6,7,5,6,4}	23190403000060590	jwDPkEMMb5xwYZh4NPbDXm7rWmjQ7Y5MGfGuj33dh6WR1v36mAF	84	114	114	1	\N	1781510618000	canonical
111	3NKPwdmJthjrQRukvP2JUst7VgzPsMKq1jhZt1K234hUYqoQpfxr	110	3NKSbS3zBuS2Hebon4U6WMmRNkNfaFsFwi1ipVU3wmKZCH4avEyv	57	147	8oXdKYTmwgr6fZe145etHerL7yJFNY3qS61ydv8Kwwc=	25	83	101	58	{6,6,4,6,4,2,6,7,5,6,4}	23190403000060590	jx6PKJNmsP3BFCHDXFwRyoCWGY879VqnRZ3AhX7qkJeGwcpnAqc	83	113	113	1	\N	1781510588000	canonical
110	3NKSbS3zBuS2Hebon4U6WMmRNkNfaFsFwi1ipVU3wmKZCH4avEyv	108	3NK9sPmmgHoNkwfRHWgaa7ras4LSfUwjznD3zjo4wB87Mfmqhx9J	57	147	FqaYtCFuLNXBq7A8orTXdwqorMEvwhWMeuTP0753BgQ=	25	83	100	58	{6,6,4,6,4,1,6,7,5,6,4}	23190403000060590	jxTQXk8gd9E1cMFLfeWaGGdNL2b1WwP4bJdBjG6nBjepfgcGSVx	82	112	112	1	\N	1781510558000	canonical
108	3NK9sPmmgHoNkwfRHWgaa7ras4LSfUwjznD3zjo4wB87Mfmqhx9J	107	3NK7c1K7HQYQXcGeyZsvQMZcCSBYkLPpuYr5UpxrBnEJzofp6KWB	57	147	NGDKCqG_pQIpkOFRMN7QFswoyhdUqjBKv_WEJvqyNwU=	24	83	98	59	{6,6,4,6,4,4,6,7,5,6,4}	23189323000060590	jxJG3TLve9NCWAUV9k7C6xnNyvv113RDMnqPN3Yz8rKPjGvKCp7	81	111	111	1	\N	1781510528000	canonical
126	3NKRWvaQAPcRhtXwRp7cq81y4ngSjmfszoQPfHXXyz51UNUCbCXv	125	3NLM4ooNBYwBG9xEZfRit5gZvfet8jBPx9PfozacGfxzwovKUkcc	132	224	QHCbDDsBKCnq0wpMJlUsUZbi2KzmPiWxvl8yUyERxwk=	30	83	114	56	{6,6,4,6,4,6,2,5,5,6,4}	23194363000060590	jwFoZZ4XrRyUdqhwGEZci2rCcSRwXLMVCJJ96nuV4f2jwdHqjSD	94	132	132	1	\N	1781511158000	orphaned
138	3NKjAVeGQooMrPTWt36efHbi1cnUSu5GgLyFeQgzSL7oj8Ts1z2c	137	3NL2iqkBvWXk3bA1FkfxymeNYtAu8gsGvWYDAdt28rrVrZGia4Mt	57	147	qvLXyW7pyQVbWKJviuzNxVE-utAlMbdPgtvLQNGq1A0=	35	121	125	51	{6,6,4,6,4,6,2,5,5,3,3}	23198683000060590	jxfmmtxRhPibLwmZqPxWyRcEkyoRtPyWWYbbVtLgYVM1a5eqf7o	105	149	149	1	\N	1781511668000	orphaned
140	3NL483QxnbeP7rctjCed4mN6CY5ue5qRqSCQDvJMBmM5pBBdYQGS	139	3NKLZ3BSU3e5j3T3ht7jL8sLT3JoKz3LRp2Xby1UxRHuH1J5j1kY	57	147	oyxF7-g4uCBTjDKQBgMGk_56JHeoHBMRobmXwc2maAo=	35	121	127	51	{6,6,4,6,4,6,2,5,5,3,4}	23198683000060590	jwMiTysmt4PdjQQFKqy6r7Ab4QCqxZyHrpgGjj9UswgQheUSTM7	106	151	151	1	\N	1781511728000	canonical
139	3NKLZ3BSU3e5j3T3ht7jL8sLT3JoKz3LRp2Xby1UxRHuH1J5j1kY	137	3NL2iqkBvWXk3bA1FkfxymeNYtAu8gsGvWYDAdt28rrVrZGia4Mt	132	224	DZ1D4N4vmBDMPXJMMy6hOnt0VgS6f9OXrkQEovMKMgA=	35	121	126	51	{6,6,4,6,4,6,2,5,5,3,3}	23198683000060590	jwe4fEjsSHniiNgsZEAPyNWCJ7W3bsY6o567gxTXJ12vL4SCmkK	105	149	149	1	\N	1781511668000	canonical
137	3NL2iqkBvWXk3bA1FkfxymeNYtAu8gsGvWYDAdt28rrVrZGia4Mt	136	3NLUdJ4ZFfrxtW1ZFTqkpMsx6xnFqv29Z1vzaA89pigKC269iFoX	57	147	TLrhjyuawSOy-CO2TpPD1hGxPKMyQdWm_k2DmCCSPw8=	35	121	124	51	{6,6,4,6,4,6,2,5,5,3,2}	23198683000060590	jxp6E6f2CbYQGsg6WcNY9MLXZX1Xc5ZLcKq1xvEH6YoPJGw9AVF	104	148	148	1	\N	1781511638000	canonical
136	3NLUdJ4ZFfrxtW1ZFTqkpMsx6xnFqv29Z1vzaA89pigKC269iFoX	135	3NL1h88UYpD3Gp42qAPeAK9yjiZrSf82t5Wp3TbZuQojWY5nu7yk	57	147	lkSNlKMfc5BPysuxNXLDeUWKEYFMqmKRzjsfl8v39wc=	34	121	123	51	{6,6,4,6,4,6,2,5,5,3,1}	23197603000060590	jwuVzHRnjYdu9xsAxAxRMmnYLQYuxmrCGQPtNd5Tp4LGi3CuxUn	103	147	147	1	\N	1781511608000	canonical
135	3NL1h88UYpD3Gp42qAPeAK9yjiZrSf82t5Wp3TbZuQojWY5nu7yk	134	3NKrYZfL32Eg8WAaWbYSVZadLV2qKRwJomV7tyPaVUsMAqAeXTEj	57	147	k3fhC-6q6XZeSZIHP0uDNobmecF1iU2skd2lL-jGEwc=	34	121	122	54	{6,6,4,6,4,6,2,5,5,3,4}	23197603000060590	jwhCawVeTP5pbyoWBnSR3NDsXpbfxAtH9hjHeu1A3SZ2NVz5DuV	102	146	146	1	\N	1781511578000	canonical
134	3NKrYZfL32Eg8WAaWbYSVZadLV2qKRwJomV7tyPaVUsMAqAeXTEj	133	3NKNdjmpZcCsGvAR1w4kPtnRgV9FLkRieZZmh1uZqAPMMJfVVeSe	132	224	DxmlslOYBUm5WmLyy0ezWvdLJPwueWIhj5d0dJyrRQQ=	33	83	121	54	{6,6,4,6,4,6,2,5,5,2,4}	23196883000060590	jwomumS1Fc6pkBxt2wyN9RK2JYTriyN6qJ4bt9dmT6H2XroT1HM	101	143	143	1	\N	1781511488000	canonical
133	3NKNdjmpZcCsGvAR1w4kPtnRgV9FLkRieZZmh1uZqAPMMJfVVeSe	132	3NKXub3ua2An2bQKzeEJYQkss3ugeAURqAhVE6Uaj83vqzCEksn8	132	224	XIyy6tHJJpcVvhBDraKohFjJb_zkSSnZq9w2Iuit4wk=	33	83	120	54	{6,6,4,6,4,6,2,5,5,1,4}	23196883000060590	jw8KZr198Qx6Rh8pEayjp3JYGKxHm3gnwC9HAkv8gN2wz35Hgwu	100	142	142	1	\N	1781511458000	canonical
132	3NKXub3ua2An2bQKzeEJYQkss3ugeAURqAhVE6Uaj83vqzCEksn8	131	3NLpb4t5atSoGVFm8syGvs97zpT5mL2iicYQpH5cfV7wEgLAHwwR	132	224	nDZpa8sed4IekEr6yh9-6RIwilhPlJZtynARKdRFOgc=	32	83	119	54	{6,6,4,6,4,6,2,5,5,6,4}	23195803000060590	jxqoCwASNsXWv5Qgi3uaeBgYJR9V8bdjHY5KwfC2HKTR4xuMBcT	99	139	139	1	\N	1781511368000	canonical
131	3NLpb4t5atSoGVFm8syGvs97zpT5mL2iicYQpH5cfV7wEgLAHwwR	130	3NKkUYZsDTizD1yAWwPdychhgwVvq7JJ6CXpG5iaMSHyU5MeapzE	57	147	JZOzSSVMCMOKCc2_mpMGDRtSjAXfb4iWTq5p2Ho_fAg=	32	83	118	54	{6,6,4,6,4,6,2,5,4,6,4}	23195803000060590	jxj68B7kY18LJa3uPXGxyh1QyvVZFS1nJFBfaTd8dejDLpMF6gb	98	137	137	1	\N	1781511308000	canonical
130	3NKkUYZsDTizD1yAWwPdychhgwVvq7JJ6CXpG5iaMSHyU5MeapzE	129	3NK6d1dJNWqpocFYaiiYBQJqmy6aCGqJqZ5FEL1oiXUydQWpejAa	57	147	2_9p5u5NHvEE8nQW9f1VdNKFutQzw1RAnAW_Y0f2HQE=	31	83	117	54	{6,6,4,6,4,6,2,5,3,6,4}	23195083000060590	jxEe9uxZ9e2CWZjwKu5yxdGNyjHNbi5ryeTy4JWr4ux4qDNbc2F	97	136	136	1	\N	1781511278000	canonical
129	3NK6d1dJNWqpocFYaiiYBQJqmy6aCGqJqZ5FEL1oiXUydQWpejAa	128	3NLwxszmVcAsyLgv1CrLZEK7Lb58ePrZtAF5HJxT5b5cFMq2Zihh	57	147	6fa8kmpWGV1p8BVD93GtPN5Ck5WR3JgG2pwXwzNKggI=	31	83	116	54	{6,6,4,6,4,6,2,5,2,6,4}	23195083000060590	jxN3uSNS5nj4wiXr7wedepeq5K69cRLd6m5x6SwNLQFX1h2hRnW	96	135	135	1	\N	1781511248000	canonical
128	3NLwxszmVcAsyLgv1CrLZEK7Lb58ePrZtAF5HJxT5b5cFMq2Zihh	127	3NLZp8YQroB7M4gyXSoP3eEguWAZSwsu5wC2TuH6NEorKUNXTgmp	57	147	eYpdWK0A1U8ztBsHnBebpHifhfcEYYEUohXuXArFxQ4=	30	83	115	54	{6,6,4,6,4,6,2,5,1,6,4}	23194363000060590	jwn1w4xB6AWLFHAvdC1rrG3eWaHso5cKbRQ9Pqpe91bzhEVSjqz	95	134	134	1	\N	1781511218000	canonical
127	3NLZp8YQroB7M4gyXSoP3eEguWAZSwsu5wC2TuH6NEorKUNXTgmp	125	3NLM4ooNBYwBG9xEZfRit5gZvfet8jBPx9PfozacGfxzwovKUkcc	57	147	YzgjwwK2HJ7ijUYxbcNq4NYw3Ycs-PgvQEeFgH24Hw4=	30	83	114	56	{6,6,4,6,4,6,2,5,5,6,4}	23194363000060590	jwDS1bpVML9jZLATLNetx9a4BzR8aqropc4KrMMaqABU7GhdpN4	94	132	132	1	\N	1781511158000	canonical
125	3NLM4ooNBYwBG9xEZfRit5gZvfet8jBPx9PfozacGfxzwovKUkcc	123	3NK862ynHqAtM3RBPXbCtyrjRA8LhMs8M4ELpMrAenCYNoxQZWih	132	224	qv54bWFaMPs9RjyOiStRmVDIsMamf2d4r4-0hkx0Zg0=	29	83	113	56	{6,6,4,6,4,6,2,4,5,6,4}	23192923000060590	jxW8PLsb4YhGWtHTzkwGgiGuK18JCktAbXbPn9FXc8GtfffLiG9	93	130	130	1	\N	1781511098000	canonical
142	3NK7VmYapybhZWuZ6XN1a17Jdxn5qzfn5osPewtoMNbwSBQoAaqw	140	3NL483QxnbeP7rctjCed4mN6CY5ue5qRqSCQDvJMBmM5pBBdYQGS	132	224	gYbBkPbbmZGkk8PtTSlHidfC-OtiCnsce8tMX_tKqwM=	36	121	129	51	{6,6,4,6,4,6,2,5,5,3,5}	23199043000060590	jxfQPe3KxiZgQrYVQAGWt7o4aDzQfSywehTnJenBKXHm4rCgs7P	107	153	153	1	\N	1781511788000	orphaned
145	3NLJym3Xn2P29JxWXi89FpmofQ1PtVf1gZPnECNkixzhM5caR8Xc	143	3NK7BYvDfccvu28cwJJDeBCC8rusoLihqnhWykxnnVGXJsZ4MK5h	57	147	zIE3uSx552oZzNUfcahPsdtMtSmIF3Ycwqg0QwtfpQE=	37	121	132	51	{2,6,4,6,4,6,2,5,5,3,5}	23200123000060590	jxPNjSoc7oPwpX4YZvsAqXguna3fpy7NH6yucwSbb2VSbMgzNRm	109	158	158	1	\N	1781511938000	orphaned
150	3NKQ9pCi2x4Rqu3fDBBbyms3cYHeasPnZomndpHYF45NEgGsjNsa	149	3NLQp2xkczmM63kpzEQdRop9QFQWRJ6vL7LBqfsyNDDYyPc2mmLZ	57	147	_LCNyFuRwAKnnilJ5QqeTEvJuStvJz3ffACrplh0DA0=	39	121	137	50	{4,3,4,6,4,6,2,5,5,3,5}	23201203000060590	jwKTa3VwWNoEfjVBtVGTMFMfQNH6yatmnWpYKSmiwMg2yZ1Ezr4	114	163	163	1	\N	1781512088000	orphaned
157	3NLYPvgh9x5GivMn5m7NLb98tzDupCE19PQpkobgC58mnGkiuyev	156	3NKcooBzxvW4kwGKssewzApEymKhy9qrP8pdtPAxYHCaya7J8bTm	132	224	Y8g0I2vnEAoFYshEDz1td3XROBN_KyiSV8pvqx4zJAc=	41	121	144	50	{4,7,2,6,4,6,2,5,5,3,5}	23203003000060590	jwUGyCwbAkPWEMBMEGBnw65co2aXGh78QYVoR9NkaPzmtYbJvjd	120	170	170	1	\N	1781512298000	canonical
156	3NKcooBzxvW4kwGKssewzApEymKhy9qrP8pdtPAxYHCaya7J8bTm	155	3NLLnN3Y2E3QP2akdTTKKvfW98NuSGLKsf84n2QbRkrjsX6gLFH7	57	147	CO6FuXjX2oZby9QJJxnLY0LCW2y-KexHdLseHYotdgw=	41	121	143	50	{4,7,1,6,4,6,2,5,5,3,5}	23203003000060590	jxJbtEBvE7SPH95mFktxkikvnBDWR8dC5VDmcyyZwdz6EJ2Dgi6	119	169	169	1	\N	1781512268000	canonical
155	3NLLnN3Y2E3QP2akdTTKKvfW98NuSGLKsf84n2QbRkrjsX6gLFH7	154	3NLD1FdPyddumMDd6dtSst7dUcuaLevyH36PAiKdAA2P7sRzhZvM	57	147	r9YIN9nVJWOb7GoEdOibMjZEsydX2U1khg9GnBo3vAI=	40	121	142	50	{4,7,4,6,4,6,2,5,5,3,5}	23202283000060590	jxijJaUUB9dR8i4JvoivQxFfYPvKehWy9S7sVGx9ReFF6fRkRqd	118	167	167	1	\N	1781512208000	canonical
154	3NLD1FdPyddumMDd6dtSst7dUcuaLevyH36PAiKdAA2P7sRzhZvM	153	3NLiKKr4ao5dYD4iwqZ5FQYbCHmFAQTuMV3fCpRvZZ7qCYgky5Xa	132	224	Oyrg0s0orcqVl-FxS-ZRaysxY664-bCKTAHlp7eAmgg=	40	121	141	50	{4,6,4,6,4,6,2,5,5,3,5}	23202283000060590	jwp1JCvedP9cZnaGr2vyCApxgBJr1W7NL4Cd9SYJeT2uiojxgqq	117	166	166	1	\N	1781512178000	canonical
153	3NLiKKr4ao5dYD4iwqZ5FQYbCHmFAQTuMV3fCpRvZZ7qCYgky5Xa	152	3NLimf64JHeNpUZh55FDws2ZpuUtG8fZxKbDNs822zcvEzUzbyKK	57	147	5sThSKRmFemCfj2LiiEt-KNauaxQ1SHzBD8cA_qfZgE=	40	121	140	50	{4,5,4,6,4,6,2,5,5,3,5}	23202283000060590	jw84DaMFYHN9uk11DEk2XAjYGMDoAeAfz2YMukUjMYEMNdTHmzG	116	165	165	1	\N	1781512148000	canonical
152	3NLimf64JHeNpUZh55FDws2ZpuUtG8fZxKbDNs822zcvEzUzbyKK	151	3NLHHRPstXo8Mio2T7LTkawj3d4M7QjKhR4duQtCKyB9EKQ9sTMM	132	224	AtQb1rTUBtRNsKsZpHxuBFXSvhLf6pevq2pLBaM1UQ8=	39	121	139	50	{4,4,4,6,4,6,2,5,5,3,5}	23201203000060590	jx3fgTFEpunnX2HEjX8rJBP3iqRw6fpEugwMH1qYCuwjy8dZtwK	115	164	164	1	\N	1781512118000	canonical
151	3NLHHRPstXo8Mio2T7LTkawj3d4M7QjKhR4duQtCKyB9EKQ9sTMM	149	3NLQp2xkczmM63kpzEQdRop9QFQWRJ6vL7LBqfsyNDDYyPc2mmLZ	132	224	yj_2ij0frVQmB6oio3rN224M1D87nKapAboW3hAuZwU=	39	121	138	50	{4,3,4,6,4,6,2,5,5,3,5}	23201203000060590	jxtVJRhZRCZRFADG7Ac75MUwextgbDBu6r4VDE4ubgQSSYFen68	114	163	163	1	\N	1781512088000	canonical
149	3NLQp2xkczmM63kpzEQdRop9QFQWRJ6vL7LBqfsyNDDYyPc2mmLZ	148	3NLC12Pe4biW7Xg7oRwMGYLNYj3FmEHFbT5E9K5u5p6JjuQvsiaA	57	147	sEtHtm5OR5vy6UIQr0dxPMHVZ4S_bfdo-E3SdolvUgw=	38	121	136	50	{4,2,4,6,4,6,2,5,5,3,5}	23200483000060590	jwTRzsaSWYBPvqqm9sCZSfBzEiHYPBu1BEM7p2xRCoX63AEKe1V	113	162	162	1	\N	1781512058000	canonical
148	3NLC12Pe4biW7Xg7oRwMGYLNYj3FmEHFbT5E9K5u5p6JjuQvsiaA	147	3NLv2ZqNUfm1RLeSXjMm51rBgmRMT6jFnvpA8tCM2P3fapagJoJx	57	147	Owi_6XCUSkT66SkSNN-8nypw_F4oOP7Y2IUrrfVa2AQ=	38	121	135	50	{4,1,4,6,4,6,2,5,5,3,5}	23200483000060590	jw7sdBed5ZotNC2PG1mhaWmPszC5Apa974cDaUrbXQyGA9qaNTC	112	161	161	1	\N	1781512028000	canonical
147	3NLv2ZqNUfm1RLeSXjMm51rBgmRMT6jFnvpA8tCM2P3fapagJoJx	146	3NLFiH3WzyK1vTW5NRiuZZ3ypJwgGJqBZ2Uch9R9cp4petWLRKht	132	224	IHNdcDxSx1RG7vts8QqAhgJA2F1bxTQL0Ke1dcN9swE=	38	121	134	51	{4,6,4,6,4,6,2,5,5,3,5}	23200483000060590	jwkajpqAmJCSifTitgwmpH3xTFMiJRfoDuqPZgik7vmUMBF91x2	111	160	160	1	\N	1781511998000	canonical
146	3NLFiH3WzyK1vTW5NRiuZZ3ypJwgGJqBZ2Uch9R9cp4petWLRKht	144	3NKkU7yUVL3bxQYzyw7TVr8UncCSMdf9VKcBKdU65t64oXXfjrzp	57	147	XEEnNSM56C6sx1F2PfdvHyJ-9wnMtN6j0M1Y5aJyIQc=	37	121	133	51	{3,6,4,6,4,6,2,5,5,3,5}	23200123000060590	jx1EdaJFhr7JmAmBA4MGNoyhHQzi15PHymGWaMsCajPMx4dLoJ6	110	159	159	1	\N	1781511968000	canonical
144	3NKkU7yUVL3bxQYzyw7TVr8UncCSMdf9VKcBKdU65t64oXXfjrzp	143	3NK7BYvDfccvu28cwJJDeBCC8rusoLihqnhWykxnnVGXJsZ4MK5h	132	224	M-cJDvFvVbsl54XErbvuFa35KGiw4ETXsSIgBs-2mgg=	37	121	131	51	{2,6,4,6,4,6,2,5,5,3,5}	23200123000060590	jwEfnQ7A9pnSTRwssdDafuUCVzPoNQQUWCy87i9nGTUPbZuVu9z	109	158	158	1	\N	1781511938000	canonical
143	3NK7BYvDfccvu28cwJJDeBCC8rusoLihqnhWykxnnVGXJsZ4MK5h	141	3NLUU3inLaZgPemiCHQ4xJD1qLL4z16xgQ6euSsqKuf1vKb1uNww	132	224	pb1ah8h_PtPQNDEErCJVfcil5VH2qqJdTp53aAUSkwk=	36	121	130	51	{1,6,4,6,4,6,2,5,5,3,5}	23199043000060590	jwszF3XDKTV5m7MZxhnjWNpaEJah2gLwU9VYiDYzEVbFm6eue1f	108	154	154	1	\N	1781511818000	canonical
163	3NKt5RTPAkeswHi72avCcNJEa5kqWbAzBA4ffTLh51Wq4YAJCJWN	161	3NL2EVHPBPEEGjx2meviT47j7XZMvj5zADn9gBtERoSrePCfJCD6	132	224	fRgweiRZlZS_J0CwjsztlL5zHNehki5ImXPvMJeGYQU=	44	121	149	50	{4,7,5,2,4,6,2,5,5,3,5}	23205163000060590	jx1AdR88YtjddSiFNrgaZCwR2KwFLVfvUmXKbXmwXcfbieMtWNx	125	180	180	1	\N	1781512598000	orphaned
165	3NKxWnZsF2zNm2sbzZfcqZWixheAqnvRiWQvouAZka7zXJ5kSmRu	162	3NLroBBQT7zn764QocH6T9xWM1nYbNyvDakGRUYMg7cfJefkGBbQ	57	147	Ao3fuq5ExN3s5N02BZBqZw9BQv0-P2uloM3jywaERgI=	44	121	150	50	{4,7,5,3,4,6,2,5,5,3,5}	23205163000060590	jwjuuptP7CGXShkKQ1G7EKzpgLhF55iutQC25ffB9Qp6ms9Ecca	126	181	181	1	\N	1781512628000	orphaned
167	3NK47s77tSwLrKv8EfHEBdD38PjLbkM9a4xbdBT1Au2JrgRGbyjz	166	3NKXbHW7Mc5fJarcsHzpEBgSoC8akAAZJZhtgctFoUS3nJr2x2TY	57	147	cgAnioMlkmZDfJ7AKLdOAqnTnSEY4BKZ4g-so-abNQs=	45	121	152	49	{4,7,5,3,2,6,2,5,5,3,5}	23206243000060590	jxUdMKD1GfV22gzbQ5mRBYdWDQsmBxBV7TyAKG88bN6bJhu2dqD	128	184	184	1	\N	1781512718000	orphaned
174	3NKwnP4qUMBCxUwTBcwsoqH1wtaUga2Tmp8ZACEaEpvi8CHEjaYv	173	3NKWbLbt42cdyGjrDaMLcrUK7quinf3E1qdrZyX6JrEHGkwnvprp	57	147	PYabTBJUoQqt9JaqCHS3SFaLS_JzEGGOrzlgZrEOrws=	48	121	158	49	{4,7,5,3,6,2,2,5,5,3,5}	23208763000060590	jwgDbkqBbT1DEbqfip1ceTEzCwcUivoNzT7q5rhnYkJSYR1ipWd	134	191	191	1	\N	1781512928000	canonical
173	3NKWbLbt42cdyGjrDaMLcrUK7quinf3E1qdrZyX6JrEHGkwnvprp	172	3NKtofojxVYWL22rEMqMbfaWt1SrA9cxAGBD1bryHduNvdBPWYy1	132	224	26QBf6y-2ZVgxZGweO5VeX305Bvu116_T0kHnGya3AA=	47	121	157	49	{4,7,5,3,6,1,2,5,5,3,5}	23208043000060590	jwu9FmmbyE5vZik6CT3y7iooXAuxEr6c7xkfWskGyyD2hrxvAZR	133	190	190	1	\N	1781512898000	canonical
172	3NKtofojxVYWL22rEMqMbfaWt1SrA9cxAGBD1bryHduNvdBPWYy1	171	3NLq4AYYnzY1ErpDwKJEE9PWd2ffZFpKFAgZcmEBbcS5CRwHJHdo	132	224	fjP5vbdvBE0xgbKvCB-NeHzEPuEaYsgWMkDtOJ_Qiw4=	47	121	156	49	{4,7,5,3,6,6,2,5,5,3,5}	23208043000060590	jxbYbxKD4qAMRZ3xe7kJNfonf9rnT96u4JLXJy3CuFpbhLza81G	132	188	188	1	\N	1781512838000	canonical
171	3NLq4AYYnzY1ErpDwKJEE9PWd2ffZFpKFAgZcmEBbcS5CRwHJHdo	170	3NKz7t4RidtYSBU1btjCpM81bSczAmqbpAvx9QCemzSkwVny5RqX	132	224	1s2aOmntd2C0vDh9djAZ0HsMx4VFi0Vh0AmB_YOSXQA=	46	121	155	49	{4,7,5,3,5,6,2,5,5,3,5}	23207323000060590	jx3ZV9GZ3aHi2XHmgjCvGsHTepCUKqPEmY2v4DdKCuL3H19RYvF	131	187	187	1	\N	1781512808000	canonical
170	3NKz7t4RidtYSBU1btjCpM81bSczAmqbpAvx9QCemzSkwVny5RqX	169	3NKUuCJLRgEindNf2uruwcZypAxnF2ThcmQYuP2KWSh3gCaagmnn	132	224	IJQUdEPL4RfmTzZX-HTbZtfxS6ZgE8OYHfLV30T0yAw=	46	121	154	49	{4,7,5,3,4,6,2,5,5,3,5}	23207323000060590	jxZi3GKkUk19ZVYxqgjXFmhxUNWiXXGz1KWMrgvJ9SsCkgrsNEs	130	186	186	1	\N	1781512778000	canonical
169	3NKUuCJLRgEindNf2uruwcZypAxnF2ThcmQYuP2KWSh3gCaagmnn	168	3NK81b8m4BS8jqWZEboNNsCtYrfPYq5uLGXrnabDdnBZWR6wmjJw	57	147	wsw_lcpagHIgcrjBt1bt6Fhh0CujBcuGvOXtB3TrNA0=	46	121	153	49	{4,7,5,3,3,6,2,5,5,3,5}	23207323000060590	jwsCzgfoS28cFWvZPVvqSYpuT3UdQVXdDDtbSiqKvaRgQJUSwtP	129	185	185	1	\N	1781512748000	canonical
168	3NK81b8m4BS8jqWZEboNNsCtYrfPYq5uLGXrnabDdnBZWR6wmjJw	166	3NKXbHW7Mc5fJarcsHzpEBgSoC8akAAZJZhtgctFoUS3nJr2x2TY	132	224	6dLaSr0PBk3xzhmdovLic3yicUuz9x13lcarL3lwHwE=	45	121	152	49	{4,7,5,3,2,6,2,5,5,3,5}	23206243000060590	jx9Zon4g24gPyqesLh2JNR2cwA4DgN7N6HEL4iZQpo54QsQHDbJ	128	184	184	1	\N	1781512718000	canonical
166	3NKXbHW7Mc5fJarcsHzpEBgSoC8akAAZJZhtgctFoUS3nJr2x2TY	164	3NKnNCjMeBu67XPeGBWx93xUdFpZosLyuWaXGiZFdCpJGHEWxRig	57	147	iVZ2MEV8gbsnxQi-dTTK-iRfSQhPXHJR-ICT2tQYsAs=	45	121	151	49	{4,7,5,3,1,6,2,5,5,3,5}	23206243000060590	jxjaHYBdQZ1zfmuPkgR6Q2zMYq9QUBt12hPUuYd5jVxfdCUTLnk	127	183	183	1	\N	1781512688000	canonical
164	3NKnNCjMeBu67XPeGBWx93xUdFpZosLyuWaXGiZFdCpJGHEWxRig	162	3NLroBBQT7zn764QocH6T9xWM1nYbNyvDakGRUYMg7cfJefkGBbQ	132	224	5jkTDLkk2y1QOJluvxhGem2nA2q_sOn7Wn33H0SJnAE=	44	121	150	50	{4,7,5,3,4,6,2,5,5,3,5}	23205163000060590	jwxfDAUafo4ebbG7QGkwfgPbzrA6awURtGSGseRdz5hExXzkaDT	126	181	181	1	\N	1781512628000	canonical
162	3NLroBBQT7zn764QocH6T9xWM1nYbNyvDakGRUYMg7cfJefkGBbQ	161	3NL2EVHPBPEEGjx2meviT47j7XZMvj5zADn9gBtERoSrePCfJCD6	57	147	CAGs3zlKuWKdcWx8NesGGDFkAGowt1qwddS6kvi2fgs=	44	121	149	50	{4,7,5,2,4,6,2,5,5,3,5}	23205163000060590	jxCndToSvh2Y17JmtwtquxCMTgxR47RuQ2kjZEnJkgxY3UnMB6t	125	180	180	1	\N	1781512598000	canonical
161	3NL2EVHPBPEEGjx2meviT47j7XZMvj5zADn9gBtERoSrePCfJCD6	160	3NKDdbd4nanjjyxjB6fSRdE41AaASARKYFMbgKYdKhHxPZYpoz9S	132	224	QBHy7Eh7tmKOMcuhJ337KKo2c4nXdoJcGB1SwzNhsAE=	43	121	148	50	{4,7,5,1,4,6,2,5,5,3,5}	23204803000060590	jxNH4vWkSej3ysLF2QyiAJrnLyDnRKqdveh8UMmmAE2pZefb1zM	124	179	179	1	\N	1781512568000	canonical
160	3NKDdbd4nanjjyxjB6fSRdE41AaASARKYFMbgKYdKhHxPZYpoz9S	159	3NLMTCVnT6VENjTowuomzP9ZcehLQBrL8nyi3Hx7cMdKqAhesJJk	57	147	ZSb8TkFIpVeTpmZo2Mq0aZ39ibrgsC_rf1DRwSeswAk=	42	121	147	50	{4,7,5,6,4,6,2,5,5,3,5}	23203363000060590	jwYhqNTeQS7H1qce2wLtrL8MfXDvPHR4ZgeqGFrPuSYf363S8oX	123	174	174	1	\N	1781512418000	canonical
159	3NLMTCVnT6VENjTowuomzP9ZcehLQBrL8nyi3Hx7cMdKqAhesJJk	158	3NKHsmpgtrQrw1KFHnnzEo5PVGLESjciiLKy5oUEvqYUCRFPLzCW	132	224	4plkYtEQJN8kqcHy9ztz-Y3mtbSatgnzP_dAvM5EDQQ=	42	121	146	50	{4,7,4,6,4,6,2,5,5,3,5}	23203363000060590	jwkpcJdFruAoh2rmVmtDFsf7Cw64RoqXzG8hPJXvddMzgQr8MiB	122	172	172	1	\N	1781512358000	canonical
176	3NKB3QVF6CQGsH5Nx18DbpjxUiVy7rjGCzJLwqbzRV638LZe63vk	174	3NKwnP4qUMBCxUwTBcwsoqH1wtaUga2Tmp8ZACEaEpvi8CHEjaYv	132	224	djDupuM597hc1Ngr799JKPJYFqqrgs5-h30aXrzD5wk=	48	158	160	49	{4,7,5,3,6,3,2,5,5,3,5}	23208763000060590	jxFJSCUaaRMFxaBLQKDoFrvvrw1ZgM9gDZqrMSxRZRmD1ATf28X	135	192	192	1	\N	1781512958030	orphaned
179	3NKnVsU58cHJtDGSHJLcY9JFTy2WMNNkn1oZdG98X43TfmnDyPLe	178	3NKWBAGYWuKTJpCPRZpzbpzhw3CpcRtJby1N9gC4H75W2XWtSs13	132	224	N6bs8bTBf7OQePpm9fDfvN5MJvJp1YQOB2GwcuH0mAo=	49	158	163	49	{4,7,5,3,6,6,2,5,5,3,5}	23209843000060590	jxhbuLVCMdiEmdrdVcCoJk7GeV8VCG84BAGtZ7s59j4VAhWrVxq	138	195	195	1	\N	1781513048000	orphaned
187	3NLNxJ5b3DfqjGZikgqKXJWmui8hVmLhwBuM1kQqA1K7Wt8y8eT3	186	3NKbAcJbMm4QzcBuCbuVpHoMWVi1ho6v6G9u6sQGjbsFYUkgHdif	132	224	k9OTthCueKW9hW80Gxhjs0HhH_-Wo7YHrbVCArssWAM=	52	158	171	49	{4,7,5,3,6,6,7,5,5,3,5}	23211643000060590	jwfW1F8Zyk1Yfp11FjQMVfcAyAUGsXsATvfhsZCcnk1poUsRmED	145	202	202	1	\N	1781513258000	orphaned
189	3NLpKctzVGZcTeUrtL7NU15uTCJ3odbehzn5pFtN3YXT3KZuNKPr	188	3NLVbPUsjxX4LSmfp8ML1zaWAQuXAsapguQGzSoBBgCgbjDwUMUF	132	224	ByAfwJ_HxGJ_rDkY0ZZrwrZ0AoU5y7ocoKsDPw1AJA8=	52	158	173	49	{4,7,5,3,6,6,7,1,5,3,5}	23211643000060590	jxdy7eJyTaNn9wEL4CSTEJ8EuQQGKRJTxmdYff6EAehAynbLsFt	146	203	203	1	\N	1781513288000	orphaned
191	3NKgn6W3qhxtAtkpgv47eJfjTZvSVxnp1Eid13CMk1kkaXKmNSoW	190	3NKZ7UM9xn1YXX37eBM8ffK3WBCLmn6re1a8wY5ofpwSJLBbSn5C	132	224	uKnShSzPIW84Q93WqHxzKDHxdr6CrA2WC8UONml8yAU=	52	158	175	49	{4,7,5,3,6,6,7,2,5,3,5}	23211643000060590	jx2bhoThNp9eM8MqwyUwEDY1juYyxDqWnKANSN8gmr6y2qiRCa5	147	205	205	1	\N	1781513348000	canonical
190	3NKZ7UM9xn1YXX37eBM8ffK3WBCLmn6re1a8wY5ofpwSJLBbSn5C	188	3NLVbPUsjxX4LSmfp8ML1zaWAQuXAsapguQGzSoBBgCgbjDwUMUF	57	147	vOQDLc2jVD5nJi5tjqFo5K5-uXG1pVZKjXXwlNeGLQs=	52	158	174	49	{4,7,5,3,6,6,7,1,5,3,5}	23211643000060590	jwd4r3ZYXKJbdt95VTmXxauEfCi6iU6vxJEWPjUkokxf42xQ3ST	146	203	203	1	\N	1781513288000	canonical
188	3NLVbPUsjxX4LSmfp8ML1zaWAQuXAsapguQGzSoBBgCgbjDwUMUF	186	3NKbAcJbMm4QzcBuCbuVpHoMWVi1ho6v6G9u6sQGjbsFYUkgHdif	57	147	L1wsJ0ntOB_wkbAyQUi4Jy-yz5I-NeXGwo1c4nsc4As=	52	158	172	49	{4,7,5,3,6,6,7,5,5,3,5}	23211643000060590	jwncBLL12xQ2GHd5qzwLCxGSb4GdrbHPNK8A1gtzNnXwfQdGshE	145	202	202	1	\N	1781513258000	canonical
186	3NKbAcJbMm4QzcBuCbuVpHoMWVi1ho6v6G9u6sQGjbsFYUkgHdif	185	3NK4zN3h1HYHTt2LmHLF29RqTcyFTWEAwFdti4FGL4yy4xr5UaNE	132	224	i9mqiE3GGKR2CMQvvkecDZrI7RmpzAvd7c5TRnjTeAs=	51	158	170	49	{4,7,5,3,6,6,6,5,5,3,5}	23210923000060590	jx1Ex1RAkWLUmZiBRr9vKsbQTJjaj1S3pFELBqBEed7szf4VNae	144	201	201	1	\N	1781513228000	canonical
185	3NK4zN3h1HYHTt2LmHLF29RqTcyFTWEAwFdti4FGL4yy4xr5UaNE	184	3NLVh84pEbYQp81NAGeVGvNtohLtCRCXyyGY1escEuyzWgHNjZE6	57	147	8YvQgWV7uLLiN_UPF7iilS3unQJS2v9H57PfjZ5e8wo=	51	158	169	49	{4,7,5,3,6,6,5,5,5,3,5}	23210923000060590	jxDZ6mhDkny2hHEuZrMrtX5DRuYjYhovEJUEUDFoNhBv2mR9FBg	143	200	200	1	\N	1781513198000	canonical
184	3NLVh84pEbYQp81NAGeVGvNtohLtCRCXyyGY1escEuyzWgHNjZE6	183	3NLcKWsdK9pD7ZR2wSGi2bhUwFU5UvJ9MiWtJGDL1skGzmDsfeMA	132	224	td5YXNfoyiX4J1U7fp9Wg9bdO132Ykg0wvitvUGdSwY=	51	158	168	49	{4,7,5,3,6,6,4,5,5,3,5}	23210923000060590	jxYQPEMYQQEnxEN7yJNJ36ZKPVt1vjnABcexQbU5VDeZHJxN7ZX	142	199	199	1	\N	1781513168000	canonical
183	3NLcKWsdK9pD7ZR2wSGi2bhUwFU5UvJ9MiWtJGDL1skGzmDsfeMA	182	3NLAcbL2K5zXEVvf5kBaajJQy5Xy8KTtiZ3P6Mi5pfApSUftqvCz	57	147	IctzqLIb_CzfwIuOBUpfoDIF_LtuQtutPw2b6xGKWQs=	50	158	167	49	{4,7,5,3,6,6,3,5,5,3,5}	23210563000060590	jwqyC6PNuZVaX9U3SfH2DavdgajDfB8GoQxseqUCme62dvtZHRH	141	198	198	1	\N	1781513138000	canonical
182	3NLAcbL2K5zXEVvf5kBaajJQy5Xy8KTtiZ3P6Mi5pfApSUftqvCz	181	3NLLzqVtQWfhbuv5hzNeqnPPMSZLtrEQ77vR8wYRSDdTirEbzaUq	132	224	5gK3_U2RySjaWAmGu2uUk7l28KfhrLhg1_VADzZAjAw=	50	158	166	49	{4,7,5,3,6,6,2,5,5,3,5}	23210563000060590	jxyPzs3eLn5EquNrhTahB9wMBK5Y96KpieEGoYiygqnNfBWgxSY	140	197	197	1	\N	1781513108000	canonical
181	3NLLzqVtQWfhbuv5hzNeqnPPMSZLtrEQ77vR8wYRSDdTirEbzaUq	180	3NK716o9tMtEp4mzTQLYHkTpin8sWtfDmA73Vj3kNaES7wzQSLJC	132	224	Pimz1UJZnK_HZCPL-8lqVkHlLn6hEUTNxJcAaPz0FAo=	49	158	165	49	{4,7,5,3,6,6,1,5,5,3,5}	23209843000060590	jw8iSXdfGYCBhLYGrZfnpkXvS8hkVtQub2WphDfBdvtJSSmV1LF	139	196	196	1	\N	1781513078000	canonical
180	3NK716o9tMtEp4mzTQLYHkTpin8sWtfDmA73Vj3kNaES7wzQSLJC	178	3NKWBAGYWuKTJpCPRZpzbpzhw3CpcRtJby1N9gC4H75W2XWtSs13	57	147	P_tFiEAjYl9uRylHOv_bhl8Adez3hOcl4JGf1gBEUgE=	49	158	164	49	{4,7,5,3,6,6,2,5,5,3,5}	23209843000060590	jxac7d95gUJYYDJK9XsCE8UQWfzBJZoJBZrmPBK93bmXN5Qga3Y	138	195	195	1	\N	1781513048000	canonical
178	3NKWBAGYWuKTJpCPRZpzbpzhw3CpcRtJby1N9gC4H75W2XWtSs13	177	3NKLoNKhFcj1iXRnosu4pqyxMKp1n8uwAXLJPSFeUa1DJzjTM3iP	132	224	uB_ZFN-_Ch-7bzqPSC32W0BndNeenA0PRqWtZQBZjQU=	49	158	162	49	{4,7,5,3,6,5,2,5,5,3,5}	23209843000060590	jwBxZAQ2u1LioVXdk6kJkyW7v6DAXeHNv47U13e4zaasq9E4jcz	137	194	194	1	\N	1781513018000	canonical
177	3NKLoNKhFcj1iXRnosu4pqyxMKp1n8uwAXLJPSFeUa1DJzjTM3iP	175	3NKv5M5cYnoKtiKRqg2zcG3bQ53HnFhSFhp5CpiXY9bvRV3QwJaz	57	147	foG9DY_8H1bHiAawbyAFyWAnrwCKlXNiCX5l32D2fQU=	48	158	161	49	{4,7,5,3,6,4,2,5,5,3,5}	23208763000060590	jxoW871xWLw9GwkuHjZyKDVvkLkvUWALJnPMDS78fTaep9ZPxoy	136	193	193	1	\N	1781512988000	canonical
195	3NL9TjbLFbKv2Uenac1CgnuC5atZfoN7ydzqM2YDZbJ27GvEG4qQ	193	3NKupaQPTcV4auGkm5X6UFfXxryGgJ6qXLzv3dznYEAFXU7XCYW2	132	224	QgZSo56j47KQVEOpBZeyx6Iw1Nnn22jkiagQlz51xQk=	54	158	179	49	{4,7,5,3,6,6,7,5,5,3,5}	23213803000060590	jwz1r4X4x2Xfm8GDaph6ikZChCfQNqZQ5kSEFrKQqKF2puUFvrE	150	208	208	1	\N	1781513438000	orphaned
199	3NKVjkPpeqWGncnJWadNrRZaA93n75QVA5TSrBundXSTEe4bCGbB	198	3NLeZZmkRX5iAR8oT5AqxyAC7MWD5mUAif886cX2xjJP7KaXCHSt	57	147	Q01uTr7jr47FC4U-J-_-IN1aVZLzFzl_j6C7leFOKgM=	55	158	183	49	{4,7,5,3,6,6,7,6,3,3,5}	23214523000060590	jxauVirVnFxMm9sjvVLN1L7dubNcry8wCgUac5y48azEYATZtvc	154	212	212	1	\N	1781513558000	orphaned
200	3NK7qQNKdW2cA4g3nhSvbnYDxL5Zi4XGyNVTbNsj3GotnF669mto	198	3NLeZZmkRX5iAR8oT5AqxyAC7MWD5mUAif886cX2xjJP7KaXCHSt	132	224	dQRAzt6GJ626W_HcXDEHcDt5N-cSzRHIgA6H2bQq6wM=	55	158	184	49	{4,7,5,3,6,6,7,6,3,3,5}	23214523000060590	jxx9qPrCRJuRauV4mCz6WR1zRNgkAyc1pbxg1RkEvH1o1SEbSEB	154	212	212	1	\N	1781513558000	orphaned
205	3NKq3C97KpAurDbMCHYasYqPjpocdMUPZhcLjmKRG41mQsBMou67	203	3NKt4RC1zfBwpcY1iVLH2zKRZjQzfBSEgT9cgRMZWcnD93LSuuJf	57	147	I5JGBNVr1J-katOCGbkzwONW3NAPynovG3CXrzqPQQ4=	56	158	189	49	{4,7,5,3,6,6,7,6,6,3,5}	23215243000060590	jwooPHj9UkgBCPgzAZFCZwgF7uRmy2uJz6otraK6sp8r8skQ82r	157	215	215	1	\N	1781513648000	orphaned
208	3NK7xJ39b5US7c8Rq2QDRoJWBjEMrp9UQEf5x2jgWdQP1Aydjeob	207	3NLiRbrEy35HK7X9znjiG9MzCdqApLHrwGqHtNPbeDQ7ZjkWvz3B	132	224	r5xqnDBZm3igzWqbriLLy_n5qcl3DTvU1rC0emGQWwA=	57	158	192	49	{4,7,5,3,6,6,7,6,7,2,5}	23216683000060590	jwvvqzwNS64H5cST2q1CwnqbMWSVhkeCNpG2g7wgRuP89FKvGGX	160	218	218	1	\N	1781513738000	canonical
207	3NLiRbrEy35HK7X9znjiG9MzCdqApLHrwGqHtNPbeDQ7ZjkWvz3B	206	3NLtH6WSePCmU4ik8LYpovKPa2nMjR2EMwS35udQJ3sZEchdcvZ7	57	147	OKSetPNkPHtx7XqVTxu4U0src-3aZj2zn_M-lcAfrwk=	57	158	191	49	{4,7,5,3,6,6,7,6,7,1,5}	23216683000060590	jx8zBw8Q5ME8aAWwT389JQLaSvLH5CRpDbHEd2DLPvvXUUoyFWS	159	217	217	1	\N	1781513708000	canonical
206	3NLtH6WSePCmU4ik8LYpovKPa2nMjR2EMwS35udQJ3sZEchdcvZ7	204	3NKse9idNYGHKEp9nWYm271vn9sTZ7Jc2UCFznKssBRJCAHxs6V2	132	224	Kxla2dhYQKo2WuEiJQ-2ebFIVimFiSwIPznOALWCvgc=	56	158	190	49	{4,7,5,3,6,6,7,6,7,3,5}	23215243000060590	jxwXMMSyx9QeAFpjeWw9y67Bnp542ES3EuBcvoAkb7XL21zcfjB	158	216	216	1	\N	1781513678000	canonical
204	3NKse9idNYGHKEp9nWYm271vn9sTZ7Jc2UCFznKssBRJCAHxs6V2	203	3NKt4RC1zfBwpcY1iVLH2zKRZjQzfBSEgT9cgRMZWcnD93LSuuJf	132	224	KAecNnhJ0i2V_oQZUmwKKZzBOb-xctsU0PA2vJOPKQ0=	56	158	188	49	{4,7,5,3,6,6,7,6,6,3,5}	23215243000060590	jxHmRwyNpn9xhZL6uJivZMvRoNdyXBhrnxvXRtbZ2oxU4124hXo	157	215	215	1	\N	1781513648000	canonical
203	3NKt4RC1zfBwpcY1iVLH2zKRZjQzfBSEgT9cgRMZWcnD93LSuuJf	202	3NLvsknHDFRSUQsZKcDftGTYJnnaUg3npcGR4rwD1Azhs81gYuGZ	57	147	NzNqfX5cxcinWPuzucdhvhIaBc3SeKfz80pms6qP0go=	56	158	187	49	{4,7,5,3,6,6,7,6,5,3,5}	23215243000060590	jx1ePCsTgwCjPnrpWXPqGgfCpMFsi9QcX3dNUrRSJu9ctNYCK8f	156	214	214	1	\N	1781513618000	canonical
202	3NLvsknHDFRSUQsZKcDftGTYJnnaUg3npcGR4rwD1Azhs81gYuGZ	201	3NL8GvSV2kNoQ8H84T4L5sbT1JvjrNiagTdt7VFwoTXAbRpDRhVw	57	147	nYgS0Y5wp9-z51LwntiRZTG1nVwuF8fMc09QErsETgM=	55	158	186	49	{4,7,5,3,6,6,7,6,4,3,5}	23214523000060590	jwiSePhGH57E8wcTEQ7vuG8xEudnAB79APSNqeN44sYxaZHunXZ	155	213	213	1	\N	1781513588000	canonical
201	3NL8GvSV2kNoQ8H84T4L5sbT1JvjrNiagTdt7VFwoTXAbRpDRhVw	198	3NLeZZmkRX5iAR8oT5AqxyAC7MWD5mUAif886cX2xjJP7KaXCHSt	76	75	O6j4BM5mB4kTxVtUiNnT7HgUCHB0uux0yZfh6swqGQA=	55	158	185	49	{4,7,5,3,6,6,7,6,3,3,5}	23214523000060590	jxkWzsmTA8Xmx78ZdzEwRKHBiZ3BKNSc2tqJqx2BFjg918s42sr	154	212	212	1	\N	1781513558000	canonical
198	3NLeZZmkRX5iAR8oT5AqxyAC7MWD5mUAif886cX2xjJP7KaXCHSt	197	3NL7sbpk2t8aQ7PGeABvT2gaSVZAKYDJBm2NVJ3sQLvSMjhBiZ8H	57	147	uhWqbufAia2Y90iRASqWO6neD8se4eKAo3OY3utl5wo=	55	158	182	49	{4,7,5,3,6,6,7,6,2,3,5}	23214523000060590	jwGd7DjtKtmi4iJRfijU4HijeACnD8VW57g8DVcMeDMfZmfXCoY	153	211	211	1	\N	1781513528000	canonical
197	3NL7sbpk2t8aQ7PGeABvT2gaSVZAKYDJBm2NVJ3sQLvSMjhBiZ8H	196	3NKmTsT33eZJN8WbSgY87kqhoQfh4XKidMPsCRN5jo79cDWPPymB	132	224	eX2CG-coKhgTEdG_1y4hxTYm8LmrYdL2Z6CFiDFRxwA=	54	158	181	49	{4,7,5,3,6,6,7,6,1,3,5}	23213803000060590	jwDgwsEDbMfpwh1MGKTfiHjvoKFuE7HjQSDLMuzUp1uDkiji29U	152	210	210	1	\N	1781513498000	canonical
196	3NKmTsT33eZJN8WbSgY87kqhoQfh4XKidMPsCRN5jo79cDWPPymB	194	3NLkToZDpTZs5LgJaSGHF5XZifWit3sRtUxLEo9w7cMMx1jeJzqV	57	147	ytHmAAF3WlyVlT2Ls4mhFL_6CUrMlFvVpvP8Qq5rNwQ=	54	158	180	49	{4,7,5,3,6,6,7,6,5,3,5}	23213803000060590	jxRfmoTgFnoPZCxSNrC78BZqPYqetHud4o3pDQ2f2pA4KLd6qj5	151	209	209	1	\N	1781513468000	canonical
194	3NLkToZDpTZs5LgJaSGHF5XZifWit3sRtUxLEo9w7cMMx1jeJzqV	193	3NKupaQPTcV4auGkm5X6UFfXxryGgJ6qXLzv3dznYEAFXU7XCYW2	57	147	dkGe5XqDAx-BUNfG62KMsIk6t2pbALmcObioZDygrwA=	54	158	178	49	{4,7,5,3,6,6,7,5,5,3,5}	23213803000060590	jxGBgCAfk5fnBorjLWi39wLj6mhVT5cqGXk3bpu9eGaMBykTJQ3	150	208	208	1	\N	1781513438000	canonical
193	3NKupaQPTcV4auGkm5X6UFfXxryGgJ6qXLzv3dznYEAFXU7XCYW2	192	3NL7ZdXJbS75izBdrA1bi1HGNKypZ2TVtS7trfN4YhfCyXToo5bd	57	147	aV5wlSvxuQTseTzyDsAbBsry7xApbmAqGK7lsvR6hg4=	53	158	177	49	{4,7,5,3,6,6,7,4,5,3,5}	23212723000060590	jx1ECwvpbngCoA4ZqgMh3skEEMG6anh2zcWwFyRB7MQrwoeCdBC	149	207	207	1	\N	1781513408000	canonical
215	3NLfbZF3t17k2Dpqy3vMdyNtoaD7AcjZLoCjgWUQxzow6JLSE837	214	3NKbBTZ3xoET5aKW7URzvgXJbmGmK4wSA5EonKdmqEtLk2QzRvfJ	57	147	tw7h4WKJH4YGVzwgeqW5qWy4U7VkIck443dBT6po7AU=	61	158	199	49	{4,7,5,3,6,6,7,6,7,4,5}	23220283000060590	jxcvGMJgwHSmXipKSqV9NARYXxp15St3B8rM3wjikNrbWp7JNYB	167	230	230	1	\N	1781514098000	orphaned
218	3NKPHQyF3MeX6rWJ3ZPX3DpnecFwSdmC7wQYEGw8x6QedkPGaGqi	216	3NKZbSNmZAoS16XFaJx1tRFtY9KwQfRVqJg6uTob7CubZETkvGwd	132	224	8D1bVJ-jSC1IrF10FEyCKCo9NdM6i3ieIHnFBZbnDw4=	61	158	200	49	{1,7,5,3,6,6,7,6,7,4,5}	23220283000060590	jxsbYbNaPvZSzodXtg1wyZhsBFwDRPW3zVqgBePdZ2TznLLtipv	168	232	232	1	\N	1781514158000	orphaned
219	3NLK7whhz5o6BcPQp9LHm4BjNjhVnxCoKw8UdYauucQCGafxagu8	217	3NKLZKpPrWRtnLYHtmw1tsnoYx86fQbiPMN3rwTkcqXWLegjHs8g	132	224	nGpT32caXjjNuk9WX27QSMOMLqMVKlprSdIuYuWioQs=	61	158	201	49	{2,7,5,3,6,6,7,6,7,4,5}	23220283000060590	jxVkjvTdjXgyrj1TmVobkSroxmgYSRk5QKhq7fkP6vaHjuw6dWV	169	233	233	1	\N	1781514188000	orphaned
225	3NKudSad3WJ5j7yWaFjJDGGXFvKDEeBAM8eW2AJ99uC2KAnER7Gd	223	3NKmXxADED2SzUDnMzHGwSgjC1siDFVPu7HKiwKBMzgwC1ZR6LVn	57	147	nG3NsDKq6qOXqPJ5MO8P9Oo0ZsUFjFGKVof__shfvwg=	63	204	206	49	{5,1,5,3,6,6,7,6,7,4,5}	23222443000060590	jx4cxKfS2YnYecUbTNdD3feh6ba1U5YKWbxeq4kRHvkD8bBrFSH	173	240	240	1	\N	1781514398032	orphaned
224	3NKFbzCEXMjPGNbT2CwXE4ieBDWK1vapH2DA8GX9hXpDgajcCnyM	223	3NKmXxADED2SzUDnMzHGwSgjC1siDFVPu7HKiwKBMzgwC1ZR6LVn	132	224	iTCRq5h_rsT_5kwJNvCISw7y59Q94_oZrWlfLoUriAM=	63	204	205	49	{5,1,5,3,6,6,7,6,7,4,5}	23222443000060590	jwFJfDV7hTf34S7B59JTpPTu1dSkpugFbWWsJe3sWxS9cgXXYrB	173	240	240	1	\N	1781514398029	canonical
223	3NKmXxADED2SzUDnMzHGwSgjC1siDFVPu7HKiwKBMzgwC1ZR6LVn	222	3NLFc2YiT8HsLbopC7VWL9YzNWHyJww4Rg6mvaUHd9fuoFaThUsN	132	224	xytLzBGwFajy5fTSHjI9eDT3lC-HRqFLIP_KYAIV3QE=	63	158	204	49	{5,7,5,3,6,6,7,6,7,4,5}	23222443000060590	jxYhoLDRNNnAP2rQM2TDAjmUeFKHySD55pDEvZoZVmEnVVbbo3o	172	237	237	1	\N	1781514308000	canonical
222	3NLFc2YiT8HsLbopC7VWL9YzNWHyJww4Rg6mvaUHd9fuoFaThUsN	221	3NKP7mJKnrWVQPcBDkBHRZZxQ3K8puLjN4ourrWA5PCtMVZHULqo	57	147	aj7JJYODF2cz0iqIVgY9mM7MOXX_iKETUjIBSKj5Zwo=	62	158	203	49	{4,7,5,3,6,6,7,6,7,4,5}	23221003000060590	jxqNQAD8XMAH9CYuj8DkQMG9uH1bidyDacUS1vYYrkx68ym1KWy	171	235	235	1	\N	1781514248000	canonical
221	3NKP7mJKnrWVQPcBDkBHRZZxQ3K8puLjN4ourrWA5PCtMVZHULqo	220	3NKGB9mnDkuvwHEjptuno3gGKhK1Z8pj4KKBPZnVoxtoMesSJkqy	57	147	412BHzkHT9eBWSCz_4wV0QPMLJtTbQlCrAsyFUUjEwo=	62	158	202	49	{3,7,5,3,6,6,7,6,7,4,5}	23221003000060590	jxVeNeEK2aSzbdXwmX5gCPRVr4WjdQJpUKWBmyauN8hMFECSjod	170	234	234	1	\N	1781514218000	canonical
220	3NKGB9mnDkuvwHEjptuno3gGKhK1Z8pj4KKBPZnVoxtoMesSJkqy	217	3NKLZKpPrWRtnLYHtmw1tsnoYx86fQbiPMN3rwTkcqXWLegjHs8g	57	147	tUWsmmUgBmqJs7GzPXF8xxdM-TXRDmqXPhbI2ulksAA=	61	158	201	49	{2,7,5,3,6,6,7,6,7,4,5}	23220283000060590	jwW2R4BZxubMZ6GNKB3MhhYEkHxx3r9yXzMsamgMa8yCRqJWST6	169	233	233	1	\N	1781514188000	canonical
217	3NKLZKpPrWRtnLYHtmw1tsnoYx86fQbiPMN3rwTkcqXWLegjHs8g	216	3NKZbSNmZAoS16XFaJx1tRFtY9KwQfRVqJg6uTob7CubZETkvGwd	57	57	Ua0V8NCaMfYsRdoWU1dc8vKpkCdOxlTteZZg84fwBQA=	61	158	200	49	{1,7,5,3,6,6,7,6,7,4,5}	23220283000060590	jxQjbyde97agbEdepVyev6kjNrShPk5hvGrmF3DPzUDnSczCjYo	168	232	232	1	\N	1781514158000	canonical
216	3NKZbSNmZAoS16XFaJx1tRFtY9KwQfRVqJg6uTob7CubZETkvGwd	214	3NKbBTZ3xoET5aKW7URzvgXJbmGmK4wSA5EonKdmqEtLk2QzRvfJ	132	224	ZVMhYa1OfOFJultE8Vl5N-J-QkbMK83cw4-PfKKK7QY=	61	158	199	49	{4,7,5,3,6,6,7,6,7,4,5}	23220283000060590	jx8JqzjwVGvuBzndujmve4v9KdisaZydCQmMiUDuLFj4rTTwFMf	167	230	230	1	\N	1781514098000	canonical
214	3NKbBTZ3xoET5aKW7URzvgXJbmGmK4wSA5EonKdmqEtLk2QzRvfJ	213	3NLJ2d59oB7pJswtrm4NNdH8LXSRDjGyMCRDcTGBinaMf1nhgj7y	132	224	PRbkijro9ky-mvdv-8e0rB5DvePzweKfDM53YWeQxQ0=	60	158	198	49	{4,7,5,3,6,6,7,6,7,4,4}	23219563000060590	jxLUDF3WChW64Sto2qCS6yCUKVQkV4BYw9iyH2AkE7WZSPWnRTi	166	229	229	1	\N	1781514068000	canonical
213	3NLJ2d59oB7pJswtrm4NNdH8LXSRDjGyMCRDcTGBinaMf1nhgj7y	212	3NKSsHsonGBneAYyoBGj5JoKcWumivo2o5TgmvVoZUNLx9m67iPU	132	224	cVLFJnZ0zBVz8GLpB9wfqua49EMpfwmYOnEkt8dVfwI=	60	158	197	49	{4,7,5,3,6,6,7,6,7,4,3}	23219563000060590	jx31u6FCooH49x1DQkmWr7RjLQsb9e4N7xUKc6Qm8tNsijZnayL	165	226	226	1	\N	1781513978000	canonical
212	3NKSsHsonGBneAYyoBGj5JoKcWumivo2o5TgmvVoZUNLx9m67iPU	211	3NLoXapjsFcLbDdajU4cYzL9RpFs4kDvr6pGGBeXs11LFpiGzRDn	57	147	wbk12RkcK7Hzq3HH06jQQ_1BHzbLDKlZuwY0Ukkz9gE=	59	158	196	49	{4,7,5,3,6,6,7,6,7,4,2}	23218123000060590	jwQfruY6B8ZWerykH7eZLf1yVnS884kqWgJpHQdsSER4Eq24e5S	164	225	225	1	\N	1781513948000	canonical
211	3NLoXapjsFcLbDdajU4cYzL9RpFs4kDvr6pGGBeXs11LFpiGzRDn	210	3NKwgLgc5q7bB1woAUTLN9YQvUAAMcYjGjxSwJw3GSjJcSchH8dz	132	224	BgqMYrZWuo1pALhJDgMw_MxnOW9nvZevAY74SMNZagk=	58	158	195	49	{4,7,5,3,6,6,7,6,7,4,1}	23217403000060590	jx6FHfsSTWMNAh3HdkopCPNdMkXi7A9h3EUrgxwSFBPPUUGwxRp	163	224	224	1	\N	1781513918000	canonical
210	3NKwgLgc5q7bB1woAUTLN9YQvUAAMcYjGjxSwJw3GSjJcSchH8dz	209	3NL2Mokrh2oCDeXN6xGNH8NJFTJnvCtyPFen9VhreXpJ5X8jNBGt	132	224	msnXay8JAeQrqFsZzldkGc5yj63jNSv_7AfOMS6AoAw=	58	158	194	49	{4,7,5,3,6,6,7,6,7,4,5}	23217403000060590	jwDMzMiyi9zUvG7EETqQzaKfBCSJvPLS7qUdvqFKX4Se8qte8Mz	162	220	220	1	\N	1781513798000	canonical
232	3NK6pzxh1eQPsqmF6zpWrr9tgtMfU8wY7K5Q9q9qLDBxTnxVjZpW	230	3NLf8Dv22tr7ir4MziPGdfRCYQ8BBDSVJY5vTDZJRdrhxvbrzZkj	57	147	o_qP6kG3IDWaqkIZ8D5-j7L8BfooJnSeWAdi9ORPHwE=	66	204	213	49	{5,5,2,3,6,6,7,6,7,4,5}	23224963000060590	jxPZV3ZpXBahdYxFyx7NhJYBsBQk7Z25CHP8CLZ4Bu5QEdAiBjZ	179	247	247	1	\N	1781514608000	orphaned
233	3NLushsKeAUT6dKiiSbqVm6oxk4oHatqNtYLyoA5GyZ1qc4Gksi3	231	3NKYm6zd6DULT1NC5oW1jPLBjvsEfdvCGCwYv6BqyrmMEAgByRkC	57	147	tVMkqbplabYW3bdBKROOl2NuYJZV-0eoa1dNKYuR7AA=	66	204	214	49	{5,5,3,3,6,6,7,6,7,4,5}	23224963000060590	jxXUyjvKE4FYaBoCqiX4oVAYf8ZqFbR2gJfKvKXtDrhMhkVBMeo	180	248	248	1	\N	1781514638000	canonical
231	3NKYm6zd6DULT1NC5oW1jPLBjvsEfdvCGCwYv6BqyrmMEAgByRkC	230	3NLf8Dv22tr7ir4MziPGdfRCYQ8BBDSVJY5vTDZJRdrhxvbrzZkj	132	224	mu_Yj79FF0O62PADIZRnnXzBkgfwxgxHJ7pqQQz0HAI=	66	204	212	49	{5,5,2,3,6,6,7,6,7,4,5}	23224963000060590	jxKoE3Ci2oHmFjXioT8Y2LSngdEA3T1AkQVB5QSxhtJjiQ3vEuB	179	247	247	1	\N	1781514608000	canonical
230	3NLf8Dv22tr7ir4MziPGdfRCYQ8BBDSVJY5vTDZJRdrhxvbrzZkj	229	3NKJAsoYTPQ3iWRtrj8YRMtX6MgUERx2QPS1yv65dLHPhRedM5Ar	132	224	N5B6BtUzEeKTA6l3B-bumYDbraE20sdFr5hZtsfwkg0=	65	204	211	49	{5,5,1,3,6,6,7,6,7,4,5}	23224243000060590	jxbHssCoQBj1y3C2kP4teWevkoCBek7GoHSFB4aBCAmTw3hFBx1	178	246	246	1	\N	1781514578000	canonical
229	3NKJAsoYTPQ3iWRtrj8YRMtX6MgUERx2QPS1yv65dLHPhRedM5Ar	228	3NLeuVCWf7u3PRtn2iE8kbxF4ZqhErsBfeYcfRP63P6yzSRXawTn	57	147	UNFLhG9Gerwxfch02RI8xSARttRZVRPFZj2jDQwasAw=	65	204	210	49	{5,5,5,3,6,6,7,6,7,4,5}	23224243000060590	jwpNcji8frHKs4JvqDdrHy7hMpVEo1ohhTtG7Tkj47Qph8WM1Tn	177	244	244	1	\N	1781514518000	canonical
228	3NLeuVCWf7u3PRtn2iE8kbxF4ZqhErsBfeYcfRP63P6yzSRXawTn	227	3NL7TexeQHm1XXyTGKeo9YLGKqnvjWoNxXzdcrRpsmEgsP8cdCZa	132	224	x3BDSRYUCes15Lp58uw1sFt1ulwGNQptE-fjflWy6w4=	64	204	209	49	{5,4,5,3,6,6,7,6,7,4,5}	23223523000060590	jwumzpfYFSWQwzPtYSwXJWJgjB1qULZawaFgELEHpTBv32xifNS	176	243	243	1	\N	1781514488000	canonical
227	3NL7TexeQHm1XXyTGKeo9YLGKqnvjWoNxXzdcrRpsmEgsP8cdCZa	226	3NKSNkwzgzUrSiHagjnZcquLTWZXL9oxqaxEFpXQY5bhp1FWDUxK	132	224	J0aNgbwKShC60XtVZvQgHfdXjyyqwmj2f6XJz55gEg0=	64	204	208	49	{5,3,5,3,6,6,7,6,7,4,5}	23223523000060590	jxCUG8mFgieu8Bm8pbV69RwSpANkJtt8gjvHhF5PoK5zptU7Fm6	175	242	242	1	\N	1781514458000	canonical
226	3NKSNkwzgzUrSiHagjnZcquLTWZXL9oxqaxEFpXQY5bhp1FWDUxK	224	3NKFbzCEXMjPGNbT2CwXE4ieBDWK1vapH2DA8GX9hXpDgajcCnyM	132	224	TlU-VVFmbI9NOhmkQ95NLNCYOKFC8i2xMI1XCiFmrQ8=	64	204	207	49	{5,2,5,3,6,6,7,6,7,4,5}	23223523000060590	jxRLrsL4bZr2ynn2ffhKcj9Bi5t5w9EVEW1Do6bhNUzdQMsB5RR	174	241	241	1	\N	1781514428000	canonical
209	3NL2Mokrh2oCDeXN6xGNH8NJFTJnvCtyPFen9VhreXpJ5X8jNBGt	208	3NK7xJ39b5US7c8Rq2QDRoJWBjEMrp9UQEf5x2jgWdQP1Aydjeob	132	224	frVg_on6XH97x00Xt-z0pE3fujMNxNengKZMsNMe2w8=	58	158	193	49	{4,7,5,3,6,6,7,6,7,3,5}	23217403000060590	jxuPnexEjWiQf3DegQktAx4XCh9x2yREsrLRUqfpYXth6cDfYH7	161	219	219	1	\N	1781513768000	canonical
192	3NL7ZdXJbS75izBdrA1bi1HGNKypZ2TVtS7trfN4YhfCyXToo5bd	191	3NKgn6W3qhxtAtkpgv47eJfjTZvSVxnp1Eid13CMk1kkaXKmNSoW	57	147	0baMRpRasibuJnghthrg0bUeXA-2bnrtW6VvTcZzHwE=	53	158	176	49	{4,7,5,3,6,6,7,3,5,3,5}	23212723000060590	jxU5EiAQd5X8z4TEVbr4aZcr7ZsnhUMh8TjCwmpCyusCNEy5Bex	148	206	206	1	\N	1781513378000	canonical
175	3NKv5M5cYnoKtiKRqg2zcG3bQ53HnFhSFhp5CpiXY9bvRV3QwJaz	174	3NKwnP4qUMBCxUwTBcwsoqH1wtaUga2Tmp8ZACEaEpvi8CHEjaYv	57	147	zCOcTCREQMI_pxSslK_edo_bUqCp7bbFnTPYJkiijAg=	48	158	159	49	{4,7,5,3,6,3,2,5,5,3,5}	23208763000060590	jxmwPZsUv5C9Xb7RwZdJwkTS63mQVr2WM8mTCA3Ro6TjPNFWYvB	135	192	192	1	\N	1781512958000	canonical
158	3NKHsmpgtrQrw1KFHnnzEo5PVGLESjciiLKy5oUEvqYUCRFPLzCW	157	3NLYPvgh9x5GivMn5m7NLb98tzDupCE19PQpkobgC58mnGkiuyev	57	147	Ei1Ui_nMw-qvDYyO85pI2xxXnovuuNCvDXLSUi1Sbg0=	42	121	145	50	{4,7,3,6,4,6,2,5,5,3,5}	23203363000060590	jwEQg8ey4D9Nn3Xmj46DqZF5hQg8FoLe7A7yHswPTyHcCgiDcxZ	121	171	171	1	\N	1781512328000	canonical
141	3NLUU3inLaZgPemiCHQ4xJD1qLL4z16xgQ6euSsqKuf1vKb1uNww	140	3NL483QxnbeP7rctjCed4mN6CY5ue5qRqSCQDvJMBmM5pBBdYQGS	57	147	cF73GyQC8II2XtW-qG8oMjxAG8lKrO0yA74fcfoe5gA=	36	121	128	51	{6,6,4,6,4,6,2,5,5,3,5}	23199043000060590	jwcDqeWVMNFzWAVQgm8BchKHhwhE5AVPbhb7uY8ue221tMPJyxC	107	153	153	1	\N	1781511788000	canonical
123	3NK862ynHqAtM3RBPXbCtyrjRA8LhMs8M4ELpMrAenCYNoxQZWih	121	3NKMy5GHxtvAr9qNnjUuVszmgwDUG1YHUjTBKiiD2vK7UuYS5bAB	57	147	Zhh5A5HU2-mtZsr477VGvSCWz1EFd5Ki_Uj-F8zfNAo=	29	83	112	56	{6,6,4,6,4,6,2,3,5,6,4}	23192923000060590	jwSVrubmtgCcVupswQVbM2EvwXweREBfdN4zChpjgdTbDkXxHV2	92	129	129	1	\N	1781511068000	canonical
107	3NK7c1K7HQYQXcGeyZsvQMZcCSBYkLPpuYr5UpxrBnEJzofp6KWB	106	3NKgNymJAAtvAA3DqgTCEkRwmKHZZ3n5Gjjha3aCBdS3R4DDC7nN	132	224	GSLnn8uv6yA6GBNPH5lDvMOHqOi6zHERJevx9GR-IQs=	24	83	97	59	{6,6,4,6,3,4,6,7,5,6,4}	23189323000060590	jy36jXVXP4cNA29au4zrLZLhZGcFvphuvPc1xLmTbFzD3QiXbUJ	80	108	108	1	\N	1781510438000	canonical
89	3NLeWtbyfKVejnvYSVX7G4goUytaaGAe1y5bv3g68CwCVFFNwwEW	88	3NKMm1iB8vePswQg1RJPdZHGA2ge73Xy9VZr6ku7mk9EgAB2xqUE	57	147	ys52KzBIZP2lAG5AaLabaOniNIdg44ndLalN3necCgs=	18	36	81	60	{6,6,6,5,6,4,6,7,5,6,4}	23183923000060590	jxxLj251RbC1NrFa9Mf9bc7Uhk23iHzZ1snW11vdSTZ5JGMS3UP	67	90	90	1	\N	1781509898000	canonical
73	3NK8jXoEaYgmNNsNqFoPfTCDgZi7bdgy7Bx93r9SJy7xV3zvqcYQ	71	3NLjLj6z2tt7tHP6zRki65k5MQjq3mAPgEXjjMdiBXGonj2EDEV5	132	224	pwk6hXbiFN4Ge8ZbklJTM5W9aDySJyX8xC0e8yeW4wQ=	13	36	68	77	{1,5,6,5,6,4,6,7,5,6,4}	23179243000060590	jxbUWL7DhZzPNbKA5FmLyArosk9PBGc6Zg7uVcZ4TscHTQwTvhe	56	77	77	1	\N	1781509508000	canonical
56	3NLfJ6AQqkWKtLGmzDbCCsPC4FhPR8VKRPNAeU6gd7shf3RB57sr	55	3NKCxs6xb8vdBNSsiCQTJyJMt4LveM2tJYCmjxw5FhGqGihHE1RH	57	147	xwDM6KS1QFzsho8HQTi8yimnQG2CTeli9-bAXCvyNQQ=	8	36	51	77	{1,5,6,5,6,4,6,7,3,7,7}	23174563000060590	jwTzcFR22RvhUkDh6wA1K1yRuQYWMx44yE4ZUMrUnapJ718s5KP	43	60	60	1	\N	1781508998000	canonical
39	3NLRQnW8fU1aM78LaL43ZipynEXEsP1aDBgREN7TLFA82rkx9bYk	38	3NLBEofibQFdqRdnXcwWkiTGevoC77C6ams7aj4EyYiKXKmw5zMF	132	224	SZFPOe92QAg4aeBvHcDhr-s0ixfzuNqs1j9NF3At7Ak=	4	1	35	77	{1,5,6,5,6,4,4,7,7,7,7}	23170963000060590	jwnL3gDq41PifCgDokvakN91KVqPR7WYrhs8KLPgBdP9s7NJvii	31	46	46	1	\N	1781508578000	canonical
22	3NKWPY7NYAC9yvHSZYZeecmcs2deiGbhJt7iLbusrvGspbQsN3t6	20	3NKJg898sT8yyftZjiC8RP2Cw3gQBDKdqqQAzZfovm92dFtpfdes	57	147	s4AY7PeL-Nadzps1RN7aGtf0AiNTZhwsOWN3d93zTg8=	1	1	23	77	{1,5,6,5,2,7,7,7,7,7,7}	23167003000060590	jwrsvPGFcH9VJwqTJsSeFA9YoNPBFshyGrdEC2MK4pGSVNefx6K	19	29	29	1	\N	1781508068000	canonical
\.


--
-- Data for Name: blocks_internal_commands; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.blocks_internal_commands (block_id, internal_command_id, sequence_no, secondary_sequence_no, status, failure_reason) FROM stdin;
2	1	0	0	applied	\N
3	2	0	0	applied	\N
4	1	0	0	applied	\N
5	2	0	0	applied	\N
6	2	1	0	applied	\N
6	3	2	0	applied	\N
7	1	0	0	applied	\N
8	1	0	0	applied	\N
9	2	0	0	applied	\N
10	1	1	0	applied	\N
10	4	2	0	applied	\N
11	2	1	0	applied	\N
11	5	2	0	applied	\N
12	6	1	0	applied	\N
12	7	2	0	applied	\N
12	8	2	0	applied	\N
13	7	1	0	applied	\N
13	8	1	0	applied	\N
13	9	2	0	applied	\N
13	10	2	1	applied	\N
14	2	2	0	applied	\N
14	11	3	0	applied	\N
15	7	2	0	applied	\N
15	8	2	0	applied	\N
15	12	3	0	applied	\N
15	13	3	1	applied	\N
16	1	1	0	applied	\N
16	6	2	0	applied	\N
17	1	0	0	applied	\N
18	7	4	0	applied	\N
18	14	4	0	applied	\N
18	15	5	0	applied	\N
18	16	5	1	applied	\N
19	4	1	0	applied	\N
19	7	2	0	applied	\N
19	8	2	0	applied	\N
20	7	1	0	applied	\N
20	14	1	0	applied	\N
20	17	2	0	applied	\N
20	18	2	1	applied	\N
21	2	1	0	applied	\N
21	3	2	0	applied	\N
22	1	1	0	applied	\N
22	6	2	0	applied	\N
23	2	0	0	applied	\N
24	7	3	0	applied	\N
24	14	3	0	applied	\N
24	19	4	0	applied	\N
24	20	4	1	applied	\N
25	2	1	0	applied	\N
25	5	2	0	applied	\N
26	7	1	0	applied	\N
26	14	1	0	applied	\N
26	21	2	0	applied	\N
26	20	2	1	applied	\N
27	7	1	0	applied	\N
27	8	1	0	applied	\N
27	22	2	0	applied	\N
27	20	2	1	applied	\N
28	2	1	0	applied	\N
28	3	2	0	applied	\N
29	5	1	0	applied	\N
29	7	2	0	applied	\N
29	14	2	0	applied	\N
30	4	1	0	applied	\N
30	7	2	0	applied	\N
30	8	2	0	applied	\N
31	7	1	0	applied	\N
31	14	1	0	applied	\N
31	21	2	0	applied	\N
31	20	2	1	applied	\N
32	7	1	0	applied	\N
32	8	1	0	applied	\N
32	22	2	0	applied	\N
32	20	2	1	applied	\N
33	23	3	0	applied	\N
33	7	4	0	applied	\N
33	8	4	0	applied	\N
34	24	3	0	applied	\N
34	7	4	0	applied	\N
34	14	4	0	applied	\N
35	7	4	0	applied	\N
35	8	4	0	applied	\N
35	25	5	0	applied	\N
35	20	5	1	applied	\N
36	2	0	0	applied	\N
37	1	0	0	applied	\N
38	7	2	0	applied	\N
38	8	2	0	applied	\N
38	26	3	0	applied	\N
38	27	3	1	applied	\N
39	2	1	0	applied	\N
39	3	2	0	applied	\N
40	1	0	0	applied	\N
41	2	0	0	applied	\N
42	7	2	0	applied	\N
42	14	2	0	applied	\N
42	28	3	0	applied	\N
42	27	3	1	applied	\N
43	7	2	0	applied	\N
43	8	2	0	applied	\N
43	26	3	0	applied	\N
43	27	3	1	applied	\N
44	2	1	0	applied	\N
44	3	2	0	applied	\N
45	1	1	0	applied	\N
45	6	2	0	applied	\N
46	2	0	0	applied	\N
47	7	2	0	applied	\N
47	8	2	0	applied	\N
47	26	3	0	applied	\N
47	27	3	1	applied	\N
48	1	1	0	applied	\N
48	6	2	0	applied	\N
49	1	0	0	applied	\N
50	7	2	0	applied	\N
50	14	2	0	applied	\N
50	28	3	0	applied	\N
50	27	3	1	applied	\N
51	7	2	0	applied	\N
51	8	2	0	applied	\N
51	26	3	0	applied	\N
51	27	3	1	applied	\N
52	1	1	0	applied	\N
52	6	2	0	applied	\N
53	2	0	0	applied	\N
54	1	0	0	applied	\N
55	7	3	0	applied	\N
55	14	3	0	applied	\N
55	29	4	0	applied	\N
55	27	4	1	applied	\N
56	30	2	0	applied	\N
56	7	3	0	applied	\N
56	8	3	0	applied	\N
57	7	1	0	applied	\N
57	8	1	0	applied	\N
57	22	2	0	applied	\N
57	20	2	1	applied	\N
58	2	2	0	applied	\N
58	11	3	0	applied	\N
59	7	1	0	applied	\N
59	8	1	0	applied	\N
59	31	2	0	applied	\N
59	27	2	1	applied	\N
60	2	2	0	applied	\N
60	11	3	0	applied	\N
61	2	0	0	applied	\N
62	7	2	0	applied	\N
62	14	2	0	applied	\N
62	28	3	0	applied	\N
62	27	3	1	applied	\N
63	1	1	0	applied	\N
63	6	2	0	applied	\N
64	2	1	0	applied	\N
64	3	2	0	applied	\N
65	2	0	0	applied	\N
66	1	0	0	applied	\N
67	7	2	0	applied	\N
67	14	2	0	applied	\N
67	28	3	0	applied	\N
67	27	3	1	applied	\N
68	2	1	0	applied	\N
68	3	2	0	applied	\N
69	2	0	0	applied	\N
70	1	0	0	applied	\N
71	7	3	0	applied	\N
71	8	3	0	applied	\N
71	32	4	0	applied	\N
71	27	4	1	applied	\N
72	7	3	0	applied	\N
72	14	3	0	applied	\N
72	29	4	0	applied	\N
72	27	4	1	applied	\N
73	33	2	0	applied	\N
73	7	4	0	applied	\N
73	14	4	0	applied	\N
73	34	5	0	applied	\N
73	18	5	1	applied	\N
74	35	2	0	applied	\N
74	7	4	0	applied	\N
74	8	4	0	applied	\N
74	36	5	0	applied	\N
74	18	5	1	applied	\N
75	7	1	0	applied	\N
75	8	1	0	applied	\N
75	9	2	0	applied	\N
75	10	2	1	applied	\N
76	6	1	0	applied	\N
76	7	3	0	applied	\N
76	8	3	0	applied	\N
76	37	4	0	applied	\N
76	16	4	1	applied	\N
77	3	1	0	applied	\N
77	7	3	0	applied	\N
77	14	3	0	applied	\N
77	38	4	0	applied	\N
77	16	4	1	applied	\N
78	7	2	0	applied	\N
78	8	2	0	applied	\N
78	39	3	0	applied	\N
78	40	3	1	applied	\N
79	7	2	0	applied	\N
79	14	2	0	applied	\N
79	41	3	0	applied	\N
79	40	3	1	applied	\N
80	1	0	0	applied	\N
81	2	0	0	applied	\N
82	7	2	0	applied	\N
82	8	2	0	applied	\N
82	42	3	0	applied	\N
82	27	3	1	applied	\N
83	2	1	0	applied	\N
83	5	2	0	applied	\N
84	2	0	0	applied	\N
85	7	2	0	applied	\N
85	14	2	0	applied	\N
85	43	3	0	applied	\N
85	27	3	1	applied	\N
86	7	2	0	applied	\N
86	8	2	0	applied	\N
86	42	3	0	applied	\N
86	27	3	1	applied	\N
87	2	1	0	applied	\N
87	5	2	0	applied	\N
88	2	0	0	applied	\N
89	7	3	0	applied	\N
89	8	3	0	applied	\N
89	32	4	0	applied	\N
89	27	4	1	applied	\N
90	7	3	0	applied	\N
90	14	3	0	applied	\N
90	29	4	0	applied	\N
90	27	4	1	applied	\N
91	33	2	0	applied	\N
91	7	3	0	applied	\N
91	14	3	0	applied	\N
92	7	3	0	applied	\N
92	8	3	0	applied	\N
92	44	4	0	applied	\N
92	20	4	1	applied	\N
93	7	3	0	applied	\N
93	14	3	0	applied	\N
93	19	4	0	applied	\N
93	20	4	1	applied	\N
94	3	1	0	applied	\N
94	7	3	0	applied	\N
94	14	3	0	applied	\N
94	38	4	0	applied	\N
94	16	4	1	applied	\N
95	7	1	0	applied	\N
95	8	1	0	applied	\N
95	45	2	0	applied	\N
95	40	2	1	applied	\N
96	7	1	0	applied	\N
96	14	1	0	applied	\N
96	46	2	0	applied	\N
96	40	2	1	applied	\N
97	3	1	0	applied	\N
97	7	3	0	applied	\N
97	14	3	0	applied	\N
97	38	4	0	applied	\N
97	16	4	1	applied	\N
98	7	1	0	applied	\N
98	8	1	0	applied	\N
98	45	2	0	applied	\N
98	40	2	1	applied	\N
99	5	1	0	applied	\N
99	7	2	0	applied	\N
99	14	2	0	applied	\N
100	4	1	0	applied	\N
100	7	2	0	applied	\N
100	8	2	0	applied	\N
101	7	1	0	applied	\N
101	8	1	0	applied	\N
101	22	2	0	applied	\N
101	20	2	1	applied	\N
102	2	1	0	applied	\N
102	3	2	0	applied	\N
103	1	1	0	applied	\N
103	6	2	0	applied	\N
104	2	0	0	applied	\N
105	7	3	0	applied	\N
105	8	3	0	applied	\N
105	32	4	0	applied	\N
105	27	4	1	applied	\N
106	1	1	0	applied	\N
106	4	2	0	applied	\N
107	7	1	0	applied	\N
107	14	1	0	applied	\N
107	47	2	0	applied	\N
107	27	2	1	applied	\N
108	1	3	0	applied	\N
108	23	4	0	applied	\N
109	7	1	0	applied	\N
109	14	1	0	applied	\N
109	47	2	0	applied	\N
109	27	2	1	applied	\N
110	7	1	0	applied	\N
110	8	1	0	applied	\N
110	31	2	0	applied	\N
110	27	2	1	applied	\N
111	1	2	0	applied	\N
111	30	3	0	applied	\N
112	1	0	0	applied	\N
113	2	0	0	applied	\N
114	7	3	0	applied	\N
114	8	3	0	applied	\N
114	32	4	0	applied	\N
114	27	4	1	applied	\N
115	1	1	0	applied	\N
115	6	2	0	applied	\N
116	2	1	0	applied	\N
116	3	2	0	applied	\N
117	7	1	0	applied	\N
117	14	1	0	applied	\N
117	48	2	0	applied	\N
117	27	2	1	applied	\N
118	2	2	0	applied	\N
118	33	3	0	applied	\N
119	49	0	0	applied	\N
120	7	6	0	applied	\N
120	14	6	0	applied	\N
120	50	7	0	applied	\N
120	27	7	1	applied	\N
121	7	1	0	applied	\N
121	14	1	0	applied	\N
121	48	2	0	applied	\N
121	27	2	1	applied	\N
122	2	2	0	applied	\N
122	33	3	0	applied	\N
123	1	2	0	applied	\N
123	35	3	0	applied	\N
124	1	0	0	applied	\N
125	2	0	0	applied	\N
126	7	4	0	applied	\N
126	14	4	0	applied	\N
126	51	5	0	applied	\N
126	27	5	1	applied	\N
127	7	4	0	applied	\N
127	8	4	0	applied	\N
127	52	5	0	applied	\N
127	27	5	1	applied	\N
128	6	1	0	applied	\N
128	7	3	0	applied	\N
128	8	3	0	applied	\N
128	53	4	0	applied	\N
128	16	4	1	applied	\N
129	7	1	0	applied	\N
129	8	1	0	applied	\N
129	54	2	0	applied	\N
129	40	2	1	applied	\N
130	6	1	0	applied	\N
130	7	2	0	applied	\N
130	8	2	0	applied	\N
131	7	1	0	applied	\N
131	8	1	0	applied	\N
131	22	2	0	applied	\N
131	20	2	1	applied	\N
132	2	2	0	applied	\N
132	11	3	0	applied	\N
133	7	3	0	applied	\N
133	14	3	0	applied	\N
133	29	4	0	applied	\N
133	27	4	1	applied	\N
134	2	1	0	applied	\N
134	3	2	0	applied	\N
135	7	3	0	applied	\N
135	8	3	0	applied	\N
135	32	4	0	applied	\N
135	27	4	1	applied	\N
136	30	2	0	applied	\N
136	7	3	0	applied	\N
136	8	3	0	applied	\N
137	7	1	0	applied	\N
137	8	1	0	applied	\N
137	22	2	0	applied	\N
137	20	2	1	applied	\N
138	1	1	0	applied	\N
138	4	2	0	applied	\N
139	2	1	0	applied	\N
139	5	2	0	applied	\N
140	1	0	0	applied	\N
141	7	4	0	applied	\N
141	8	4	0	applied	\N
141	55	5	0	applied	\N
141	27	5	1	applied	\N
142	7	4	0	applied	\N
142	14	4	0	applied	\N
142	56	5	0	applied	\N
142	27	5	1	applied	\N
143	3	1	0	applied	\N
143	7	2	0	applied	\N
143	14	2	0	applied	\N
144	7	4	0	applied	\N
144	14	4	0	applied	\N
144	57	5	0	applied	\N
144	20	5	1	applied	\N
145	7	4	0	applied	\N
145	8	4	0	applied	\N
145	58	5	0	applied	\N
145	20	5	1	applied	\N
146	1	0	0	applied	\N
147	7	2	0	applied	\N
147	14	2	0	applied	\N
147	43	3	0	applied	\N
147	27	3	1	applied	\N
148	1	1	0	applied	\N
148	4	2	0	applied	\N
149	1	0	0	applied	\N
150	7	2	0	applied	\N
150	8	2	0	applied	\N
150	42	3	0	applied	\N
150	27	3	1	applied	\N
151	7	2	0	applied	\N
151	14	2	0	applied	\N
151	43	3	0	applied	\N
151	27	3	1	applied	\N
152	2	2	0	applied	\N
152	11	3	0	applied	\N
153	7	1	0	applied	\N
153	8	1	0	applied	\N
153	31	2	0	applied	\N
153	27	2	1	applied	\N
154	2	1	0	applied	\N
154	5	2	0	applied	\N
155	6	1	0	applied	\N
155	7	2	0	applied	\N
155	8	2	0	applied	\N
156	7	2	0	applied	\N
156	8	2	0	applied	\N
156	59	3	0	applied	\N
156	20	3	1	applied	\N
157	2	1	0	applied	\N
157	3	2	0	applied	\N
158	7	1	0	applied	\N
158	8	1	0	applied	\N
158	31	2	0	applied	\N
158	27	2	1	applied	\N
159	2	1	0	applied	\N
159	5	2	0	applied	\N
160	6	1	0	applied	\N
160	7	3	0	applied	\N
160	8	3	0	applied	\N
160	53	4	0	applied	\N
160	16	4	1	applied	\N
161	60	4	0	applied	\N
161	10	4	1	applied	\N
161	7	6	0	applied	\N
161	14	6	0	applied	\N
161	61	7	0	applied	\N
161	10	7	1	applied	\N
162	7	1	0	applied	\N
162	8	1	0	applied	\N
162	62	2	0	applied	\N
162	18	2	1	applied	\N
163	7	1	0	applied	\N
163	14	1	0	applied	\N
163	17	2	0	applied	\N
163	18	2	1	applied	\N
164	3	1	0	applied	\N
164	7	3	0	applied	\N
164	14	3	0	applied	\N
164	38	4	0	applied	\N
164	16	4	1	applied	\N
165	6	1	0	applied	\N
165	7	3	0	applied	\N
165	8	3	0	applied	\N
165	37	4	0	applied	\N
165	16	4	1	applied	\N
166	7	2	0	applied	\N
166	8	2	0	applied	\N
166	39	3	0	applied	\N
166	40	3	1	applied	\N
167	1	0	0	applied	\N
168	2	0	0	applied	\N
169	7	2	0	applied	\N
169	8	2	0	applied	\N
169	42	3	0	applied	\N
169	27	3	1	applied	\N
170	2	1	0	applied	\N
170	5	2	0	applied	\N
171	2	0	0	applied	\N
172	7	2	0	applied	\N
172	14	2	0	applied	\N
172	43	3	0	applied	\N
172	27	3	1	applied	\N
173	2	2	0	applied	\N
173	11	3	0	applied	\N
174	7	1	0	applied	\N
174	8	1	0	applied	\N
174	31	2	0	applied	\N
174	27	2	1	applied	\N
175	1	1	0	applied	\N
175	4	2	0	applied	\N
176	2	1	0	applied	\N
176	5	2	0	applied	\N
177	6	1	0	applied	\N
177	7	2	0	applied	\N
177	8	2	0	applied	\N
178	7	1	0	applied	\N
178	14	1	0	applied	\N
178	21	2	0	applied	\N
178	20	2	1	applied	\N
179	2	1	0	applied	\N
179	5	2	0	applied	\N
180	1	1	0	applied	\N
180	4	2	0	applied	\N
181	2	0	0	applied	\N
182	7	2	0	applied	\N
182	14	2	0	applied	\N
182	43	3	0	applied	\N
182	27	3	1	applied	\N
183	1	2	0	applied	\N
183	30	3	0	applied	\N
184	7	1	0	applied	\N
184	14	1	0	applied	\N
184	47	2	0	applied	\N
184	27	2	1	applied	\N
185	1	1	0	applied	\N
185	4	2	0	applied	\N
186	3	1	0	applied	\N
186	7	2	0	applied	\N
186	14	2	0	applied	\N
187	7	1	0	applied	\N
187	14	1	0	applied	\N
187	21	2	0	applied	\N
187	20	2	1	applied	\N
188	7	1	0	applied	\N
188	8	1	0	applied	\N
188	22	2	0	applied	\N
188	20	2	1	applied	\N
189	2	1	0	applied	\N
189	5	2	0	applied	\N
190	1	1	0	applied	\N
190	4	2	0	applied	\N
191	2	0	0	applied	\N
192	7	3	0	applied	\N
192	8	3	0	applied	\N
192	32	4	0	applied	\N
192	27	4	1	applied	\N
193	1	1	0	applied	\N
193	6	2	0	applied	\N
194	7	1	0	applied	\N
194	8	1	0	applied	\N
194	31	2	0	applied	\N
194	27	2	1	applied	\N
195	7	1	0	applied	\N
195	14	1	0	applied	\N
195	47	2	0	applied	\N
195	27	2	1	applied	\N
196	1	1	0	applied	\N
196	4	2	0	applied	\N
197	3	1	0	applied	\N
197	7	2	0	applied	\N
197	14	2	0	applied	\N
198	7	1	0	applied	\N
198	8	1	0	applied	\N
198	22	2	0	applied	\N
198	20	2	1	applied	\N
199	1	1	0	applied	\N
199	4	2	0	applied	\N
200	2	1	0	applied	\N
200	5	2	0	applied	\N
201	49	1	0	applied	\N
201	63	2	0	applied	\N
202	1	0	0	applied	\N
203	7	2	0	applied	\N
203	8	2	0	applied	\N
203	42	3	0	applied	\N
203	27	3	1	applied	\N
204	2	1	0	applied	\N
204	5	2	0	applied	\N
205	1	1	0	applied	\N
205	4	2	0	applied	\N
206	2	0	0	applied	\N
207	7	3	0	applied	\N
207	8	3	0	applied	\N
207	32	4	0	applied	\N
207	27	4	1	applied	\N
208	2	1	0	applied	\N
208	3	2	0	applied	\N
209	7	1	0	applied	\N
209	14	1	0	applied	\N
209	47	2	0	applied	\N
209	27	2	1	applied	\N
210	2	1	0	applied	\N
210	5	2	0	applied	\N
211	3	1	0	applied	\N
211	7	5	0	applied	\N
211	14	5	0	applied	\N
211	64	6	0	applied	\N
211	16	6	1	applied	\N
212	7	1	0	applied	\N
212	8	1	0	applied	\N
212	45	2	0	applied	\N
212	40	2	1	applied	\N
213	7	1	0	applied	\N
213	14	1	0	applied	\N
213	48	2	0	applied	\N
213	27	2	1	applied	\N
214	2	3	0	applied	\N
214	24	4	0	applied	\N
215	7	1	0	applied	\N
215	8	1	0	applied	\N
215	31	2	0	applied	\N
215	27	2	1	applied	\N
216	7	1	0	applied	\N
216	14	1	0	applied	\N
216	47	2	0	applied	\N
216	27	2	1	applied	\N
217	1	2	0	applied	\N
217	30	3	0	applied	\N
218	2	2	0	applied	\N
218	11	3	0	applied	\N
219	2	0	0	applied	\N
220	1	0	0	applied	\N
221	7	2	0	applied	\N
221	8	2	0	applied	\N
221	42	3	0	applied	\N
221	27	3	1	applied	\N
222	1	2	0	applied	\N
222	30	3	0	applied	\N
223	7	2	0	applied	\N
223	14	2	0	applied	\N
223	28	3	0	applied	\N
223	27	3	1	applied	\N
224	24	3	0	applied	\N
224	7	4	0	applied	\N
224	14	4	0	applied	\N
225	23	3	0	applied	\N
225	7	4	0	applied	\N
225	8	4	0	applied	\N
226	7	1	0	applied	\N
226	14	1	0	applied	\N
226	21	2	0	applied	\N
226	20	2	1	applied	\N
227	2	1	0	applied	\N
227	3	2	0	applied	\N
228	2	0	0	applied	\N
229	7	2	0	applied	\N
229	8	2	0	applied	\N
229	26	3	0	applied	\N
229	27	3	1	applied	\N
230	2	2	0	applied	\N
230	11	3	0	applied	\N
231	7	1	0	applied	\N
231	14	1	0	applied	\N
231	47	2	0	applied	\N
231	27	2	1	applied	\N
232	7	1	0	applied	\N
232	8	1	0	applied	\N
232	31	2	0	applied	\N
232	27	2	1	applied	\N
233	1	1	0	applied	\N
233	6	2	0	applied	\N
\.


--
-- Data for Name: blocks_user_commands; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.blocks_user_commands (block_id, user_command_id, sequence_no, status, failure_reason) FROM stdin;
10	1	0	applied	\N
11	2	0	applied	\N
14	3	1	applied	\N
15	4	1	applied	\N
18	5	3	applied	\N
19	6	0	applied	\N
24	7	2	applied	\N
25	8	0	applied	\N
29	9	0	applied	\N
30	9	0	applied	\N
33	10	2	applied	\N
34	10	2	applied	\N
35	11	3	applied	\N
38	12	1	applied	\N
42	13	1	applied	\N
43	13	1	applied	\N
47	14	1	applied	\N
50	15	1	applied	\N
51	15	1	applied	\N
55	16	2	applied	\N
56	17	1	applied	\N
58	18	1	applied	\N
60	19	1	applied	\N
62	20	1	applied	\N
67	21	1	applied	\N
71	22	2	applied	\N
72	22	2	applied	\N
73	23	3	applied	\N
74	23	3	applied	\N
76	24	2	applied	\N
77	24	2	applied	\N
78	25	1	applied	\N
79	25	1	applied	\N
83	26	0	applied	\N
87	27	0	applied	\N
89	28	2	applied	\N
90	28	2	applied	\N
92	29	2	applied	\N
93	29	2	applied	\N
94	30	2	applied	\N
97	31	2	applied	\N
99	32	0	applied	\N
100	32	0	applied	\N
105	33	2	applied	\N
106	34	0	applied	\N
108	35	2	applied	\N
111	36	1	applied	\N
114	37	2	applied	\N
117	38	0	applied	\N
120	39	4	applied	\N
120	40	5	applied	\N
121	41	0	applied	\N
126	42	2	applied	\N
126	43	3	applied	\N
127	42	2	applied	\N
127	43	3	applied	\N
129	44	0	applied	\N
132	45	1	applied	\N
133	46	2	applied	\N
135	47	2	applied	\N
136	48	1	applied	\N
138	49	0	applied	\N
139	49	0	applied	\N
141	50	3	applied	\N
142	50	3	applied	\N
144	51	2	applied	\N
144	52	3	applied	\N
145	51	2	applied	\N
145	52	3	applied	\N
148	53	0	applied	\N
152	54	1	applied	\N
154	55	0	applied	\N
156	56	1	applied	\N
159	57	0	applied	\N
161	58	3	applied	\N
161	59	5	applied	\N
164	60	2	applied	\N
165	60	2	applied	\N
166	61	1	applied	\N
170	62	0	applied	\N
173	63	1	applied	\N
175	64	0	applied	\N
176	64	0	applied	\N
179	65	0	applied	\N
180	65	0	applied	\N
183	66	1	applied	\N
185	67	0	applied	\N
189	68	0	applied	\N
190	68	0	applied	\N
192	69	2	applied	\N
196	70	0	applied	\N
199	71	0	applied	\N
200	71	0	applied	\N
201	71	0	applied	\N
204	72	0	applied	\N
205	72	0	applied	\N
207	73	2	applied	\N
210	74	0	applied	\N
211	75	4	applied	\N
213	76	0	applied	\N
214	77	2	applied	\N
217	78	1	applied	\N
218	78	1	applied	\N
222	79	1	applied	\N
223	80	1	applied	\N
224	81	2	applied	\N
225	81	2	applied	\N
229	82	1	applied	\N
230	83	1	applied	\N
\.


--
-- Data for Name: blocks_zkapp_commands; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.blocks_zkapp_commands (block_id, zkapp_command_id, sequence_no, status, failure_reasons_ids) FROM stdin;
6	1	0	failed	{1,2}
12	2	0	failed	{3,2}
13	3	0	failed	{4}
14	4	0	failed	{3,2}
15	5	0	failed	{4}
16	6	0	failed	{3,2}
18	7	0	failed	{4}
18	8	1	failed	{3,2}
18	9	2	failed	{4}
20	10	0	failed	{3,2}
21	11	0	failed	{4}
22	11	0	failed	{4}
24	12	0	failed	{3,2}
24	13	1	failed	{4}
26	14	0	failed	{3,2}
27	14	0	failed	{3,2}
28	15	0	failed	{4}
31	16	0	failed	{3,2}
32	16	0	failed	{3,2}
33	17	0	failed	{4}
33	18	1	failed	{3,2}
34	17	0	failed	{4}
34	18	1	failed	{3,2}
35	19	0	failed	{4}
35	20	1	failed	{3,2}
35	21	2	failed	{4}
38	22	0	failed	{3,2}
39	23	0	failed	{4}
42	24	0	failed	{3,2}
43	24	0	failed	{3,2}
44	25	0	failed	{4}
45	25	0	failed	{4}
47	26	0	failed	{3,2}
48	27	0	failed	{4}
50	28	0	failed	{3,2}
51	28	0	failed	{3,2}
52	29	0	failed	{4}
55	30	0	failed	{3,2}
55	31	1	failed	{4}
56	32	0	failed	{3,2}
57	33	0	failed	{4}
58	34	0	failed	{3,2}
59	35	0	failed	{4}
60	36	0	failed	{3,2}
62	37	0	failed	{4}
63	38	0	failed	{3,2}
64	38	0	failed	{3,2}
67	39	0	failed	{4}
68	40	0	failed	{3,2}
71	41	0	failed	{4}
71	42	1	failed	{3,2}
72	41	0	failed	{4}
72	42	1	failed	{3,2}
73	43	0	failed	{4}
73	44	1	failed	{3,2}
74	43	0	failed	{4}
74	44	1	failed	{3,2}
75	45	0	failed	{4}
76	46	0	failed	{3,2}
77	46	0	failed	{3,2}
78	47	0	failed	{4}
79	47	0	failed	{4}
82	48	0	failed	{3,2}
82	49	1	failed	{4}
85	50	0	failed	{3,2}
85	51	1	failed	{4}
86	50	0	failed	{3,2}
86	51	1	failed	{4}
89	52	0	failed	{3,2}
89	53	1	failed	{4}
90	52	0	failed	{3,2}
90	53	1	failed	{4}
91	54	0	failed	{3,2}
91	55	1	failed	{4}
92	56	0	failed	{3,2}
92	57	1	failed	{4}
93	56	0	failed	{3,2}
93	57	1	failed	{4}
94	58	0	failed	{3,2}
95	59	0	failed	{4}
96	59	0	failed	{4}
97	60	0	failed	{3,2}
98	61	0	failed	{4}
101	62	0	failed	{3,2}
102	63	0	failed	{4}
103	63	0	failed	{4}
105	64	0	failed	{3,2}
105	65	1	failed	{4}
107	66	0	failed	{3,2}
108	67	0	failed	{4}
108	68	1	failed	{3,2}
109	69	0	failed	{4}
110	69	0	failed	{4}
111	70	0	failed	{3,2}
114	71	0	failed	{4}
114	72	1	failed	{3,2}
115	73	0	failed	{4}
116	73	0	failed	{4}
118	74	0	failed	{3,2}
118	75	1	failed	{4}
120	76	0	failed	{3,2}
120	77	1	failed	{4}
120	78	2	failed	{3,2}
120	79	3	failed	{4}
122	80	0	failed	{3,2}
122	81	1	failed	{4}
123	80	0	failed	{3,2}
123	81	1	failed	{4}
126	82	0	failed	{3,2}
126	83	1	failed	{4}
127	82	0	failed	{3,2}
127	83	1	failed	{4}
128	84	0	failed	{3,2}
128	85	2	failed	{4}
130	86	0	failed	{3,2}
131	87	0	failed	{4}
132	88	0	failed	{3,2}
133	89	0	failed	{4}
133	90	1	failed	{3,2}
134	91	0	failed	{4}
135	92	0	failed	{3,2}
135	93	1	failed	{4}
136	94	0	failed	{3,2}
137	95	0	failed	{4}
141	96	0	failed	{3,2}
141	97	1	failed	{4}
141	98	2	failed	{3,2}
142	96	0	failed	{3,2}
142	97	1	failed	{4}
142	98	2	failed	{3,2}
143	99	0	failed	{4}
144	100	0	failed	{3,2}
144	101	1	failed	{4}
145	100	0	failed	{3,2}
145	101	1	failed	{4}
147	102	0	failed	{3,2}
147	103	1	failed	{4}
150	104	0	failed	{3,2}
150	105	1	failed	{4}
151	104	0	failed	{3,2}
151	105	1	failed	{4}
152	106	0	failed	{3,2}
153	107	0	failed	{4}
155	108	0	failed	{3,2}
156	109	0	failed	{4}
157	110	0	failed	{3,2}
158	111	0	failed	{4}
160	112	0	failed	{3,2}
160	113	2	failed	{4}
161	114	0	failed	{3,2}
161	115	1	failed	{4}
161	116	2	failed	{3,2}
162	117	0	failed	{4}
163	117	0	failed	{4}
164	118	0	failed	{3,2}
165	118	0	failed	{3,2}
166	119	0	failed	{4}
169	120	0	failed	{3,2}
169	121	1	failed	{4}
172	122	0	failed	{3,2}
172	123	1	failed	{4}
173	124	0	failed	{3,2}
174	125	0	failed	{4}
177	126	0	failed	{3,2}
178	127	0	failed	{4}
182	128	0	failed	{3,2}
182	129	1	failed	{4}
183	130	0	failed	{3,2}
184	131	0	failed	{4}
186	132	0	failed	{3,2}
187	133	0	failed	{4}
188	133	0	failed	{4}
192	134	0	failed	{3,2}
192	135	1	failed	{4}
193	136	0	failed	{3,2}
194	137	0	failed	{4}
195	137	0	failed	{4}
197	138	0	failed	{3,2}
198	139	0	failed	{4}
203	140	0	failed	{3,2}
203	141	1	failed	{4}
207	142	0	failed	{3,2}
207	143	1	failed	{4}
208	144	0	failed	{3,2}
209	145	0	failed	{4}
211	146	0	failed	{3,2}
211	147	2	failed	{4}
211	148	3	failed	{3,2}
212	149	0	failed	{4}
214	150	0	failed	{3,2}
214	151	1	failed	{4}
215	152	0	failed	{3,2}
216	152	0	failed	{3,2}
217	153	0	failed	{4}
218	153	0	failed	{4}
221	154	0	failed	{3,2}
221	155	1	failed	{4}
222	156	0	failed	{3,2}
223	157	0	failed	{4}
224	158	0	failed	{3,2}
224	159	1	failed	{4}
225	158	0	failed	{3,2}
225	159	1	failed	{4}
226	160	0	failed	{3,2}
227	161	0	failed	{4}
229	162	0	failed	{3,2}
230	163	0	failed	{4}
231	164	0	failed	{3,2}
232	164	0	failed	{3,2}
233	165	0	failed	{4}
\.


--
-- Data for Name: epoch_data; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.epoch_data (id, seed, ledger_hash_id, total_currency, start_checkpoint, lock_checkpoint, epoch_length) FROM stdin;
1	2va9BGv9JrLTtrzZttiEMDYw1Zj6a6EHzXjmP9evHDTG3oEquURA	1	23167003000060590	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	1
2	2vafPBQ3zQdHUEDDnFGuiNvJz7s2MhTLJgSzQSnu5fnZavT27cms	1	23167003000060590	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NL7XzbJEY9p5iMEdCazinA3SEGHECzs145HCp2dEowsKfjwzWqm	2
3	2varmnQBktKxrhyCKeetu32ZeRgPaDV8G6KJKYELinax5evz74yd	1	23167003000060590	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLTXTNHiVghip2xMjmutp762UyqT9R3BiuGVdNywjdsJ9jSiF85	3
4	2vc4kfv4xyoc5jASn6byRehcykfQzuoFAkrW4ngPgE4kSzPetZ7Y	1	23167003000060590	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKH9d2oj3G5oQvQjkzhNvgUwqrQhPsY1KaR4BUsHRZg5jxKay1c	4
5	2vbJ33iMJStiKhjVYR4f7S8o42vVz9eJd5QzVf1obyqbQheRvxSA	1	23167003000060590	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKH9d2oj3G5oQvQjkzhNvgUwqrQhPsY1KaR4BUsHRZg5jxKay1c	4
6	2vafV3kh5dwb6N6UzooFY7sKafQzgsbRsNmLa6E6j4HLVNCg4rcy	1	23167003000060590	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLEjTNpksz6wP2bLHwFSshkpHWqGon6Jfdb2wWVGBrBiyW9aqsB	5
7	2vbd2LTJ69RHKYp9BZoTzTXJx9pdQ9imdccVyHKtGNAZGJFLe3ca	1	23167003000060590	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKrMpJQ7bxoe1vRdBRentQk2j7YV6v9cQ3hTBBeZE6QajpuCqPS	6
8	2vaxGStN1Zu8SShvRXuHdArnxnppvykwoE1xoNTeNo3MgEGZcGWY	1	23167003000060590	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKxkHRUjVf7cvDYro7pb65dabPbfbzK5xY886ZH7mUPVmqb7J63	7
9	2vaqTHejVCSCRasYv18BgvHWwTrouEMT5VSZwa75mGMDrABoRKMm	1	23167003000060590	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLcsCywdyAZb2oQ2qqLUrZHXsq2q8MB3KF6znfaobERRZt6LPp5	8
10	2vbCzz3d9YZFXPdXizyTX3d9vJBNoc69PayiqiLWDeteszkuHYVX	1	23167003000060590	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLcsCywdyAZb2oQ2qqLUrZHXsq2q8MB3KF6znfaobERRZt6LPp5	8
11	2vaK9n6R5VpWFhUYm5tqkWfQ9E1eedcZkrEs31iVsvsweSho26eF	1	23167003000060590	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NK7q6FYeAWLXnH7tXChbNWdvzrfZpFZPHs2ZKQhT2Y1i6N3zbuR	9
12	2vbjAZpv8gDdiFGQB1AyFL8WCiZaqCJyVhrzbbDtp1N62g2jBaGu	1	23167003000060590	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NK5mG4oNDRgGXKdRhqN318gTmGKUMtrXnCkYJ66MCgGm43asmK4	10
13	2vbRGn3pv2BnwGahNfFitAUFsNMyS3idvtB2d21tWKpc3kCC64uj	1	23167003000060590	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKuDjk8N3S4MvyXXL7XrtJsz8TXsfFote95gefZPy1oW7JfqEgp	11
14	2vb3zPKpq1VZCz5TrLSYi4Sm3RARAnhKBrDc5RnYtHp2soaDryTq	1	23167003000060590	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKXj92UQeTsLnAECaCCKASAH7pTaWGWcPQBCW3tswPQ45XUDqYk	12
15	2vbzKXWzuezzqWmUnXE21EdSUdtVbUEQpUXpwq4GDshR7ExcnDTj	1	23167003000060590	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLtDQq4cViDRVM9NZHjWZFun2zkwsEE3a3AeocXSctx8VjaTeN1	13
16	2vaxKtxn4jE9bPbFXTJvKRRopqtkwBiBEiD1T1q7ty3GeYFmNczP	1	23167003000060590	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLJ6PQsjfmz8GXa47iQD663FkDZ9vGWVSErRfUETcvQzb1B5CtK	14
17	2vbjFCzE6u9ikeKrWeVQ5PDknvJLTzYUR9sDL2KaTfD9ef71Xmj4	1	23167003000060590	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLBhrUuiLaJZSx9AXouzc9kPLf8nuSSPsHb71KUA2WQ4RekBqUN	15
18	2vc2hSgLpq6K5mBDWgSBwKCdKgTnQhCNSYcrx8MRxUSKhfePt3vx	1	23167003000060590	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKPNJkrVMAKb55k69GZDq51MyRs8WsxedhkoXSHr7efusbgLhtC	16
19	2vbGMKDWLQbZyRLwKvJejwGLBSHahmwE4H7Sz5CxkH48H81hqBPN	1	23167003000060590	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLm1wKru3qRAjUof7HaMRFa1zxJNZdSqKyfFS5YJwoRnWgmThbU	17
20	2vbGHKY3z8Yk3zjqy7ny9tenrnJ3Ntm7wCWMUCqP7hKoDii6tmEa	1	23167003000060590	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLDk7vfSLcqgct7cqZsYNHKRDywuvKhFyBYGMZBVxHpEmpYd6KE	18
21	2vaxcrx4kP5AeZw6u2Pu7CKH4r5nH7BRyiQ9wXmPJD3y8Sxu9uPm	1	23167003000060590	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKLwLyHeQEARroVJrs7JPzsSM1GVa7mFhrmPGkpfSRwVmR9FXT7	19
22	2vbWQWpvLM5PwWg82YNbC3gsnZnyJr3xWUMiuTsiUA7rdRPhbfqj	1	23167003000060590	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKJg898sT8yyftZjiC8RP2Cw3gQBDKdqqQAzZfovm92dFtpfdes	20
23	2vapkuN9ZxAjhPHE6MguEP5LgJrdgis1GEAzGTtbtGw96gbjNPXe	1	23167003000060590	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKJg898sT8yyftZjiC8RP2Cw3gQBDKdqqQAzZfovm92dFtpfdes	20
24	2vb7yJ9v2WxcbFhdNeFb4at3AhKLtmjv4KbKrnnisyxjzz8EsGv1	1	23167003000060590	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKWPY7NYAC9yvHSZYZeecmcs2deiGbhJt7iLbusrvGspbQsN3t6	21
25	2vb7yJ9v2WxcbFhdNeFb4at3AhKLtmjv4KbKrnnisyxjzz8EsGv1	1	23167003000060590	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKWPY7NYAC9yvHSZYZeecmcs2deiGbhJt7iLbusrvGspbQsN3t6	22
26	2vb7yJ9v2WxcbFhdNeFb4at3AhKLtmjv4KbKrnnisyxjzz8EsGv1	1	23167003000060590	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKWPY7NYAC9yvHSZYZeecmcs2deiGbhJt7iLbusrvGspbQsN3t6	23
27	2vb7yJ9v2WxcbFhdNeFb4at3AhKLtmjv4KbKrnnisyxjzz8EsGv1	1	23167003000060590	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKWPY7NYAC9yvHSZYZeecmcs2deiGbhJt7iLbusrvGspbQsN3t6	24
28	2vb7yJ9v2WxcbFhdNeFb4at3AhKLtmjv4KbKrnnisyxjzz8EsGv1	1	23167003000060590	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKWPY7NYAC9yvHSZYZeecmcs2deiGbhJt7iLbusrvGspbQsN3t6	25
29	2vb7yJ9v2WxcbFhdNeFb4at3AhKLtmjv4KbKrnnisyxjzz8EsGv1	1	23167003000060590	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKWPY7NYAC9yvHSZYZeecmcs2deiGbhJt7iLbusrvGspbQsN3t6	26
30	2vb7yJ9v2WxcbFhdNeFb4at3AhKLtmjv4KbKrnnisyxjzz8EsGv1	1	23167003000060590	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKWPY7NYAC9yvHSZYZeecmcs2deiGbhJt7iLbusrvGspbQsN3t6	27
31	2vb7yJ9v2WxcbFhdNeFb4at3AhKLtmjv4KbKrnnisyxjzz8EsGv1	1	23167003000060590	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKWPY7NYAC9yvHSZYZeecmcs2deiGbhJt7iLbusrvGspbQsN3t6	28
32	2vb7yJ9v2WxcbFhdNeFb4at3AhKLtmjv4KbKrnnisyxjzz8EsGv1	1	23167003000060590	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKWPY7NYAC9yvHSZYZeecmcs2deiGbhJt7iLbusrvGspbQsN3t6	29
33	2vb7yJ9v2WxcbFhdNeFb4at3AhKLtmjv4KbKrnnisyxjzz8EsGv1	1	23167003000060590	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKWPY7NYAC9yvHSZYZeecmcs2deiGbhJt7iLbusrvGspbQsN3t6	30
34	2vb7yJ9v2WxcbFhdNeFb4at3AhKLtmjv4KbKrnnisyxjzz8EsGv1	1	23167003000060590	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKWPY7NYAC9yvHSZYZeecmcs2deiGbhJt7iLbusrvGspbQsN3t6	31
35	2vb7yJ9v2WxcbFhdNeFb4at3AhKLtmjv4KbKrnnisyxjzz8EsGv1	1	23167003000060590	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKWPY7NYAC9yvHSZYZeecmcs2deiGbhJt7iLbusrvGspbQsN3t6	32
36	2vb7yJ9v2WxcbFhdNeFb4at3AhKLtmjv4KbKrnnisyxjzz8EsGv1	1	23167003000060590	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKWPY7NYAC9yvHSZYZeecmcs2deiGbhJt7iLbusrvGspbQsN3t6	33
37	2vbVcfrVJMoTCF4cydJAYizZDzfAmC5c48RKuniR38GBSb2di2JB	4	23172043000060590	3NLkW4gXiadSXwMXwTDBa7L7KEqgoPhirAqyB9UTWvVmmUTb9ASx	3NLkW4gXiadSXwMXwTDBa7L7KEqgoPhirAqyB9UTWvVmmUTb9ASx	1
38	2vbn68RFQ6rHpoD4JuapVvLzkQoUj6TP5yVUEvRc4Y66rPiSng6w	4	23172043000060590	3NLkW4gXiadSXwMXwTDBa7L7KEqgoPhirAqyB9UTWvVmmUTb9ASx	3NLkW4gXiadSXwMXwTDBa7L7KEqgoPhirAqyB9UTWvVmmUTb9ASx	1
39	2vaGNuGRsGJLV6ZV7h8wjXST4Kcy4qtnwd78dENwSRsU8FHWSrim	4	23172043000060590	3NLkW4gXiadSXwMXwTDBa7L7KEqgoPhirAqyB9UTWvVmmUTb9ASx	3NKLShq3u9QfGAw7UMceMxTMouhUumv53EHyV2QCL8v1NH9684ba	2
40	2vaWRbTC7E1tAcd5npehduaBkmuaawcapAXU2UkHtTHNhFVXyZL1	4	23172043000060590	3NLkW4gXiadSXwMXwTDBa7L7KEqgoPhirAqyB9UTWvVmmUTb9ASx	3NKLShq3u9QfGAw7UMceMxTMouhUumv53EHyV2QCL8v1NH9684ba	2
41	2vaMVNrshB74i5Qx9SQ5Y592YWder5LHiEs31Kxge76RA6yL6xJd	4	23172043000060590	3NLkW4gXiadSXwMXwTDBa7L7KEqgoPhirAqyB9UTWvVmmUTb9ASx	3NKzb9A9PYb8VDB73UD6Y7r7QJdBrc47fWEhREkmYb9qexkgehE9	3
42	2vbzJNLEysZPXAGEDYAZsgVHnMoG8pBmh5AndVL5ZgfqKGm8iXA1	4	23172043000060590	3NLkW4gXiadSXwMXwTDBa7L7KEqgoPhirAqyB9UTWvVmmUTb9ASx	3NKYARdXgLLwW1u1hjDaKnvsA4bTTiCLkC1xDBRAtyXFLhcGTK2X	4
43	2vbUrvpVP2KjR9oiu9vy65pXFyiZ3yB9tgfsTuYhRDVmAXWYo7YX	4	23172043000060590	3NLkW4gXiadSXwMXwTDBa7L7KEqgoPhirAqyB9UTWvVmmUTb9ASx	3NK6MgTBa3yfZrXjmcL3gb9YVD6siy9DfyroyjNKNk24TKeV94yP	5
44	2vbk5Z58MFb67WdiwmZuQwxXwMPYkKyUjW49Gv7pgkfa8Z6NCcTL	4	23172043000060590	3NLkW4gXiadSXwMXwTDBa7L7KEqgoPhirAqyB9UTWvVmmUTb9ASx	3NLxFex2juNnVTG5ed69w93kB2kmQr2sD8YP8CjBRSZX35qzHXPR	6
45	2vaRoEirvGsbp9B6yjogr5maJLL4qssm3R5F5ehrMotpfi1ni8Ku	4	23172043000060590	3NLkW4gXiadSXwMXwTDBa7L7KEqgoPhirAqyB9UTWvVmmUTb9ASx	3NKpdsLCXrAQ2fu8pwzKK5ULTUeQve3VatnAy1iJm8DDXCvTwFKN	7
46	2vat37v3jMt1N1GddywKb7z9Xr4SzCXxT9zjqinN4V2noWsCeGvB	4	23172043000060590	3NLkW4gXiadSXwMXwTDBa7L7KEqgoPhirAqyB9UTWvVmmUTb9ASx	3NKpdsLCXrAQ2fu8pwzKK5ULTUeQve3VatnAy1iJm8DDXCvTwFKN	7
47	2vaQXG21ndKsvLiGWV61kdwE3PHGdesZeaqH255WcDTUqV439pxP	4	23172043000060590	3NLkW4gXiadSXwMXwTDBa7L7KEqgoPhirAqyB9UTWvVmmUTb9ASx	3NKLxr1B3atFDD4A6Yd1ZZD716anXbv8t5ZvxNUV6v1189ebqPr6	8
48	2vabix3spca3nU2WUpAjNkrVWfk2C1EbEsFeyoCn3XbCnxJ88e88	4	23172043000060590	3NLkW4gXiadSXwMXwTDBa7L7KEqgoPhirAqyB9UTWvVmmUTb9ASx	3NKyQd1PKf8eH3yaPD8JSmiom1KEmhikb6QbbUFNCo6EFucT8Tj9	9
49	2vaKdiFDYqtAsfkUUiySSbpYwe2XfGkXo6zerUUeGZvkbRxV64r5	4	23172043000060590	3NLkW4gXiadSXwMXwTDBa7L7KEqgoPhirAqyB9UTWvVmmUTb9ASx	3NKyQd1PKf8eH3yaPD8JSmiom1KEmhikb6QbbUFNCo6EFucT8Tj9	9
50	2vb4qU3Q2Gu8hDacEcAhxjqPCmg6AqFRfdknFQteKStEdCQi1kEg	4	23172043000060590	3NLkW4gXiadSXwMXwTDBa7L7KEqgoPhirAqyB9UTWvVmmUTb9ASx	3NLZtXk3FPhzitkmRH7TF6QshLzVVdwhLipW1znKMQ6tKgwNk52Q	10
51	2vc53Bh1DU9MQjgpWvbnuAGWwwnC5sRxmqEgANxSTpypKEyirTVh	4	23172043000060590	3NLkW4gXiadSXwMXwTDBa7L7KEqgoPhirAqyB9UTWvVmmUTb9ASx	3NKCxs6xb8vdBNSsiCQTJyJMt4LveM2tJYCmjxw5FhGqGihHE1RH	11
52	2vay1EBkBypso6A9ZxvCWvd39t9sqVvNhfdPUYPVrfi4ZrxtVUpd	4	23172043000060590	3NLkW4gXiadSXwMXwTDBa7L7KEqgoPhirAqyB9UTWvVmmUTb9ASx	3NLfJ6AQqkWKtLGmzDbCCsPC4FhPR8VKRPNAeU6gd7shf3RB57sr	12
53	2vbWwSBTxPmhunzmDB5gTKdre3jhB97BL4hXnjm5vdNZSxiLem1H	4	23172043000060590	3NLkW4gXiadSXwMXwTDBa7L7KEqgoPhirAqyB9UTWvVmmUTb9ASx	3NLJ9aMRt5uRAd8ZBj9HmSnNRy6bKmkXs4EYNkTDnfHPfe4KZiRd	13
54	2vbg9vdoPGKFYCiyMzdce22k2K7BFzj9BphNnS7GfWPoyrQWcyWw	4	23172043000060590	3NLkW4gXiadSXwMXwTDBa7L7KEqgoPhirAqyB9UTWvVmmUTb9ASx	3NKm5TWd8Qc7vFJ94jZ7VeigffjBfhVTbrWfFYsbfd5V1fWnsC6t	14
55	2vaE7jwvVXPZAHysVC2o1MeEBhKXf4QkRkMccxkwj6PqNmz8H6mZ	4	23172043000060590	3NLkW4gXiadSXwMXwTDBa7L7KEqgoPhirAqyB9UTWvVmmUTb9ASx	3NKdGhaqsHP7155dK34Zwqx1PgruXeFyTdVrEr8Pte8eDtBBRC1f	15
56	2vbmPRkjLFproETknD2cEYZXtSF3nwVQdmgz1yNPx23ErV7KQUUU	4	23172043000060590	3NLkW4gXiadSXwMXwTDBa7L7KEqgoPhirAqyB9UTWvVmmUTb9ASx	3NK7fi76UsGthEFvNwD3SsmSwejBEHiQCYRgrRzXbnnvxmTJyFVo	16
57	2vaasWFLjPJY88PEYNyfuUtH3yW9pSuSWEwb1PrUVmBf8ct1myjA	4	23172043000060590	3NLkW4gXiadSXwMXwTDBa7L7KEqgoPhirAqyB9UTWvVmmUTb9ASx	3NKL7cRQSeZUcCFPgomfYKpFNuj2WfKWHcF3GwTVSePmXuVw9sMv	17
58	2vbqmhRQqiHZn9jSE8hWZJfUUr5hZieSvoANPPsfTU8D91zuQiEA	4	23172043000060590	3NLkW4gXiadSXwMXwTDBa7L7KEqgoPhirAqyB9UTWvVmmUTb9ASx	3NKmfkydaXhTgeGrTMtBECWCq11EHkja2eTNmA4QWVKLjGsUApgj	18
59	2vbqfP5ueegsbu1vaCvnFFkKNAFxnH3trMnxfBj4mMUbG5NHRvdd	4	23172043000060590	3NLkW4gXiadSXwMXwTDBa7L7KEqgoPhirAqyB9UTWvVmmUTb9ASx	3NKmfkydaXhTgeGrTMtBECWCq11EHkja2eTNmA4QWVKLjGsUApgj	18
60	2vawhCWRdnN9pPcYkfUQaXtos4wS93S6Vh1UcaPUN4FvabXJBnXk	4	23172043000060590	3NLkW4gXiadSXwMXwTDBa7L7KEqgoPhirAqyB9UTWvVmmUTb9ASx	3NKf2VbcuQ72C4WqViWArWmuog7LXBVfCFQYKxL9fVzPt2v1VuJf	19
61	2vaJQvtWN4uPPHS6VAkYPsS1E1bDemt81uRzVvu4W41He1hWjmLd	4	23172043000060590	3NLkW4gXiadSXwMXwTDBa7L7KEqgoPhirAqyB9UTWvVmmUTb9ASx	3NKf2VbcuQ72C4WqViWArWmuog7LXBVfCFQYKxL9fVzPt2v1VuJf	19
62	2vbHsknQgppVK1YgzwYnrgYcXNRfuJpgTjd1k7yq1Cr5W6ZbigAP	4	23172043000060590	3NLkW4gXiadSXwMXwTDBa7L7KEqgoPhirAqyB9UTWvVmmUTb9ASx	3NLreCfY3D5md7RAcDpBmLxxgNkgdi1JaVQisH5RovPwrnf5ecmo	20
63	2vaka4eX3Md1HdmXyyDQPocrPoxxJkg2LU6EWYBZa9hVWmaGgEnj	4	23172043000060590	3NLkW4gXiadSXwMXwTDBa7L7KEqgoPhirAqyB9UTWvVmmUTb9ASx	3NLGFYpf5boXY5jhhEuHPQJDKActiQALCRsdV6PgVDunDK2f5b2D	21
64	2vbdgBQ2nCZfuxu3TrZ14p12midrFm6w6XFfAvNCi2HS79m6Aa1g	4	23172043000060590	3NLkW4gXiadSXwMXwTDBa7L7KEqgoPhirAqyB9UTWvVmmUTb9ASx	3NLGq2m7MdPJc7NcQzqKivxzrSYs5gVtUY9jhja17ZVDRTU4vkq1	22
65	2vbQpEw1E2thyANTXZhJF5q6A1oAAWNvpJJBX1kv5GxpdANg9HS5	4	23172043000060590	3NLkW4gXiadSXwMXwTDBa7L7KEqgoPhirAqyB9UTWvVmmUTb9ASx	3NLGq2m7MdPJc7NcQzqKivxzrSYs5gVtUY9jhja17ZVDRTU4vkq1	22
66	2vakmbcwSbQ635SXH4nqFx7d7N6TGyHJqsyLeX4AxediyBYmvSqw	4	23172043000060590	3NLkW4gXiadSXwMXwTDBa7L7KEqgoPhirAqyB9UTWvVmmUTb9ASx	3NLgNn3N62eb6zUoMowgJzUZwAYPNYHF9gpkLk4rtbBPKHTPs5tx	23
67	2vandNeqmDFVjPJacvvwDctsqQZ7GXTsrCe2YcN1Xb8rTVFH43Zn	4	23172043000060590	3NLkW4gXiadSXwMXwTDBa7L7KEqgoPhirAqyB9UTWvVmmUTb9ASx	3NLgNn3N62eb6zUoMowgJzUZwAYPNYHF9gpkLk4rtbBPKHTPs5tx	23
68	2vaNDAF4xGAbDZZaegqrGhCt7ugHGJwA7NiARV5qooRUcBS9MTu1	4	23172043000060590	3NLkW4gXiadSXwMXwTDBa7L7KEqgoPhirAqyB9UTWvVmmUTb9ASx	3NLjLj6z2tt7tHP6zRki65k5MQjq3mAPgEXjjMdiBXGonj2EDEV5	24
69	2vaTEGm6KFdtVSEeEwWhpUQTbwfGchpNamnuVEJ57iu6VcpjfE7x	4	23172043000060590	3NLkW4gXiadSXwMXwTDBa7L7KEqgoPhirAqyB9UTWvVmmUTb9ASx	3NLjLj6z2tt7tHP6zRki65k5MQjq3mAPgEXjjMdiBXGonj2EDEV5	24
70	2vbk3woohE1WU9diyCxaVtsnmFpAsHWRGTF2PUjNao6ceGsvBdGn	4	23172043000060590	3NLkW4gXiadSXwMXwTDBa7L7KEqgoPhirAqyB9UTWvVmmUTb9ASx	3NK8jXoEaYgmNNsNqFoPfTCDgZi7bdgy7Bx93r9SJy7xV3zvqcYQ	25
71	2vc4qW6VWGYSDBGJUk3LjruJhFUggvbrQxv3Ztnv3634sAexosiJ	4	23172043000060590	3NLkW4gXiadSXwMXwTDBa7L7KEqgoPhirAqyB9UTWvVmmUTb9ASx	3NKNQy96ewZn99AcPQgxNAsGVYQmfku7N961mwtDG9Dhtg2ecQqb	26
72	2vb1tKUWSwr2jf5W1JKoAUSpu17reMLnssEWzMq8e89hdrsDFdHy	4	23172043000060590	3NLkW4gXiadSXwMXwTDBa7L7KEqgoPhirAqyB9UTWvVmmUTb9ASx	3NKNQy96ewZn99AcPQgxNAsGVYQmfku7N961mwtDG9Dhtg2ecQqb	26
73	2vb1tKUWSwr2jf5W1JKoAUSpu17reMLnssEWzMq8e89hdrsDFdHy	4	23172043000060590	3NLkW4gXiadSXwMXwTDBa7L7KEqgoPhirAqyB9UTWvVmmUTb9ASx	3NKNQy96ewZn99AcPQgxNAsGVYQmfku7N961mwtDG9Dhtg2ecQqb	27
74	2vb1tKUWSwr2jf5W1JKoAUSpu17reMLnssEWzMq8e89hdrsDFdHy	4	23172043000060590	3NLkW4gXiadSXwMXwTDBa7L7KEqgoPhirAqyB9UTWvVmmUTb9ASx	3NKNQy96ewZn99AcPQgxNAsGVYQmfku7N961mwtDG9Dhtg2ecQqb	28
75	2vb1tKUWSwr2jf5W1JKoAUSpu17reMLnssEWzMq8e89hdrsDFdHy	4	23172043000060590	3NLkW4gXiadSXwMXwTDBa7L7KEqgoPhirAqyB9UTWvVmmUTb9ASx	3NKNQy96ewZn99AcPQgxNAsGVYQmfku7N961mwtDG9Dhtg2ecQqb	29
76	2vb1tKUWSwr2jf5W1JKoAUSpu17reMLnssEWzMq8e89hdrsDFdHy	4	23172043000060590	3NLkW4gXiadSXwMXwTDBa7L7KEqgoPhirAqyB9UTWvVmmUTb9ASx	3NKNQy96ewZn99AcPQgxNAsGVYQmfku7N961mwtDG9Dhtg2ecQqb	30
77	2vb1tKUWSwr2jf5W1JKoAUSpu17reMLnssEWzMq8e89hdrsDFdHy	4	23172043000060590	3NLkW4gXiadSXwMXwTDBa7L7KEqgoPhirAqyB9UTWvVmmUTb9ASx	3NKNQy96ewZn99AcPQgxNAsGVYQmfku7N961mwtDG9Dhtg2ecQqb	31
78	2vb1tKUWSwr2jf5W1JKoAUSpu17reMLnssEWzMq8e89hdrsDFdHy	4	23172043000060590	3NLkW4gXiadSXwMXwTDBa7L7KEqgoPhirAqyB9UTWvVmmUTb9ASx	3NKNQy96ewZn99AcPQgxNAsGVYQmfku7N961mwtDG9Dhtg2ecQqb	32
79	2vb1tKUWSwr2jf5W1JKoAUSpu17reMLnssEWzMq8e89hdrsDFdHy	4	23172043000060590	3NLkW4gXiadSXwMXwTDBa7L7KEqgoPhirAqyB9UTWvVmmUTb9ASx	3NKNQy96ewZn99AcPQgxNAsGVYQmfku7N961mwtDG9Dhtg2ecQqb	33
80	2vb1tKUWSwr2jf5W1JKoAUSpu17reMLnssEWzMq8e89hdrsDFdHy	4	23172043000060590	3NLkW4gXiadSXwMXwTDBa7L7KEqgoPhirAqyB9UTWvVmmUTb9ASx	3NKNQy96ewZn99AcPQgxNAsGVYQmfku7N961mwtDG9Dhtg2ecQqb	34
81	2vb1tKUWSwr2jf5W1JKoAUSpu17reMLnssEWzMq8e89hdrsDFdHy	4	23172043000060590	3NLkW4gXiadSXwMXwTDBa7L7KEqgoPhirAqyB9UTWvVmmUTb9ASx	3NKNQy96ewZn99AcPQgxNAsGVYQmfku7N961mwtDG9Dhtg2ecQqb	35
82	2vb1tKUWSwr2jf5W1JKoAUSpu17reMLnssEWzMq8e89hdrsDFdHy	4	23172043000060590	3NLkW4gXiadSXwMXwTDBa7L7KEqgoPhirAqyB9UTWvVmmUTb9ASx	3NKNQy96ewZn99AcPQgxNAsGVYQmfku7N961mwtDG9Dhtg2ecQqb	36
83	2vb1tKUWSwr2jf5W1JKoAUSpu17reMLnssEWzMq8e89hdrsDFdHy	4	23172043000060590	3NLkW4gXiadSXwMXwTDBa7L7KEqgoPhirAqyB9UTWvVmmUTb9ASx	3NKNQy96ewZn99AcPQgxNAsGVYQmfku7N961mwtDG9Dhtg2ecQqb	37
84	2vb7rKrPQ8f4AvHPby8TgDm18wdjcBS7oaYprbTDd729vTcra5mX	19	23185003000060590	3NL4RbFLjKT7L4VVn7DEMMfrxP7NwFiDCNSPanmbTDqjAzGgz5tD	3NL4RbFLjKT7L4VVn7DEMMfrxP7NwFiDCNSPanmbTDqjAzGgz5tD	1
85	2vbU9WBp6UhFZYaYYy1aMn3WM4yXz91RfunUE7bBCc4fnCsx6dZU	19	23185003000060590	3NL4RbFLjKT7L4VVn7DEMMfrxP7NwFiDCNSPanmbTDqjAzGgz5tD	3NK3xLpLj6cwD7qxNx2msGjUi7PCPLAayhHVQKZdL2HMpYy6B6Tx	2
86	2vbZtUz4fP52RkXP82DGfQDZ13S3h8h5x8N66nez8StRw4tyDg1Z	19	23185003000060590	3NL4RbFLjKT7L4VVn7DEMMfrxP7NwFiDCNSPanmbTDqjAzGgz5tD	3NK3xLpLj6cwD7qxNx2msGjUi7PCPLAayhHVQKZdL2HMpYy6B6Tx	2
87	2vc4if6FnVCAEYHPUgxF1k1y6onGWCd4uJhJQCEWmNfw2928yogx	19	23185003000060590	3NL4RbFLjKT7L4VVn7DEMMfrxP7NwFiDCNSPanmbTDqjAzGgz5tD	3NKzw1qUU27jTn8GJoVhMfEs14R2XTpy6MM2orbJNwUCsMCE2srE	3
88	2vbbi9pxnWJ6FzAv9LEE1UcP6QGU7xqJ7kc6KAy8STpfSCRK84gh	19	23185003000060590	3NL4RbFLjKT7L4VVn7DEMMfrxP7NwFiDCNSPanmbTDqjAzGgz5tD	3NLWqk3oqohhvfWHqU9f4zrxpYYw9UvQev1YvPd38Um1BEkBngHY	4
89	2vbkpjgY5oPsoXQ8TW3zSoCcucLgT6KzWSnSj24XtHcozPXgSqTD	19	23185003000060590	3NL4RbFLjKT7L4VVn7DEMMfrxP7NwFiDCNSPanmbTDqjAzGgz5tD	3NKugbT6s52N1iZeasxRBAdpaqeAShuunL4q2krtME8917QrfC4g	5
90	2vbMqKYy5gL8SGxDBZz9GUj9eCVPkEtPJ7XrihZmf9NmpXiUXnJn	19	23185003000060590	3NL4RbFLjKT7L4VVn7DEMMfrxP7NwFiDCNSPanmbTDqjAzGgz5tD	3NKugbT6s52N1iZeasxRBAdpaqeAShuunL4q2krtME8917QrfC4g	5
91	2vbW8xVqthevh3s6jEbxYtv18vAroy1EpQQhQn8AQbDV1MnenKE2	19	23185003000060590	3NL4RbFLjKT7L4VVn7DEMMfrxP7NwFiDCNSPanmbTDqjAzGgz5tD	3NKsQk9jrxSkvC2W5F98VUgrzQSYbVFTLU5Nyq5hNjQMF95zzqqw	6
92	2vbPo3whpNjtTCNmY1wtqctFW1WMs9yZ29UgB3J3cfrmi4is2GCU	19	23185003000060590	3NL4RbFLjKT7L4VVn7DEMMfrxP7NwFiDCNSPanmbTDqjAzGgz5tD	3NKL2kXwPucxgkZ9Dm3E76coTGy1fWZjoYejWdKnEu77HnhmsQay	7
93	2vaa68JsWY2t8qDNNfjRfWH6D459gYvAU2pANVNfTEMiQLH8uJTs	19	23185003000060590	3NL4RbFLjKT7L4VVn7DEMMfrxP7NwFiDCNSPanmbTDqjAzGgz5tD	3NKL2kXwPucxgkZ9Dm3E76coTGy1fWZjoYejWdKnEu77HnhmsQay	7
94	2vbhyJcm5hHiUxCxjB4CyvxYvuWJaRBdxQzxQykAVF12rgUEvBFP	19	23185003000060590	3NL4RbFLjKT7L4VVn7DEMMfrxP7NwFiDCNSPanmbTDqjAzGgz5tD	3NLrPM2Zs8gRUVT4BXQj1xZLv1Dw9Kb1EW6GDeHBQTQUnGvYK7vS	8
95	2vakkRLRQo8a2gkPP7CdKQYXxdNEyrvrnvMxfRNSoJBa31DVcg3B	19	23185003000060590	3NL4RbFLjKT7L4VVn7DEMMfrxP7NwFiDCNSPanmbTDqjAzGgz5tD	3NLd48zBg6j3pC6fZtP2dXm5ZNFJMFxuWMumyk7on5tLos8fbZGq	9
96	2vbPyy7Td5joS4ZPhXysC74D6EtCReKMX88hTGQUN5PbuubjHDE7	19	23185003000060590	3NL4RbFLjKT7L4VVn7DEMMfrxP7NwFiDCNSPanmbTDqjAzGgz5tD	3NKmY2xDjHKEMTGeMmCDzb92Ahtw9PGK9N1gTJp3cGvFWJhUvdNL	10
97	2vaUEHM2AJ7JsHiGjeCUYYY7hQDVsrWzVWgvC6DLLsAPPxkp21sU	19	23185003000060590	3NL4RbFLjKT7L4VVn7DEMMfrxP7NwFiDCNSPanmbTDqjAzGgz5tD	3NKgNymJAAtvAA3DqgTCEkRwmKHZZ3n5Gjjha3aCBdS3R4DDC7nN	11
98	2vbbPgNBrogAM4UF9SGAH1jKcK2M8r7zPB9FhM1hDTuY7qp6mY9Z	19	23185003000060590	3NL4RbFLjKT7L4VVn7DEMMfrxP7NwFiDCNSPanmbTDqjAzGgz5tD	3NK7c1K7HQYQXcGeyZsvQMZcCSBYkLPpuYr5UpxrBnEJzofp6KWB	12
99	2vc5QWKqcjcNG7Pu35sATvjdzeDXZ7SSmkv76sTTyEdRnVGLXKDr	19	23185003000060590	3NL4RbFLjKT7L4VVn7DEMMfrxP7NwFiDCNSPanmbTDqjAzGgz5tD	3NK9sPmmgHoNkwfRHWgaa7ras4LSfUwjznD3zjo4wB87Mfmqhx9J	13
100	2vb8QkycJYXEYmESa2AUy5AUx3xJ3vQ4huJpLtbE4ai1ACCPos9Z	19	23185003000060590	3NL4RbFLjKT7L4VVn7DEMMfrxP7NwFiDCNSPanmbTDqjAzGgz5tD	3NK9sPmmgHoNkwfRHWgaa7ras4LSfUwjznD3zjo4wB87Mfmqhx9J	13
101	2vbodxAD5VRNdcGWjCVGebEQXRKdmyYcttv3QE4Hc3yoehvK2Xwp	19	23185003000060590	3NL4RbFLjKT7L4VVn7DEMMfrxP7NwFiDCNSPanmbTDqjAzGgz5tD	3NKSbS3zBuS2Hebon4U6WMmRNkNfaFsFwi1ipVU3wmKZCH4avEyv	14
102	2vaJMWMT2EUzgEGtdAwdoYXiiYU5JQWEWVimCVbTpFaVBhMzpr34	19	23185003000060590	3NL4RbFLjKT7L4VVn7DEMMfrxP7NwFiDCNSPanmbTDqjAzGgz5tD	3NKPwdmJthjrQRukvP2JUst7VgzPsMKq1jhZt1K234hUYqoQpfxr	15
103	2vbTNcnmugAET3147uDxCJAFxAhb6qvmuVzjmumLwSqhU4FBPVzu	19	23185003000060590	3NL4RbFLjKT7L4VVn7DEMMfrxP7NwFiDCNSPanmbTDqjAzGgz5tD	3NKPwdmJthjrQRukvP2JUst7VgzPsMKq1jhZt1K234hUYqoQpfxr	15
104	2vbG9nMb5uQoZQFG3v2jm7eJ3dDrrpDovtoneb77QFSBa3Wkf4t9	19	23185003000060590	3NL4RbFLjKT7L4VVn7DEMMfrxP7NwFiDCNSPanmbTDqjAzGgz5tD	3NKS7o7eH5yF3poMviwbC8hk5R8B431fQ8B64tCdJ2w5ccikv3Q6	16
105	2vb8fdenjSuv7jdvPcNstD6X6D5JyXDLsfQf6za8g6D4digj6GXc	19	23185003000060590	3NL4RbFLjKT7L4VVn7DEMMfrxP7NwFiDCNSPanmbTDqjAzGgz5tD	3NKdPQcsTYR7HvVJYnxJs1aw3yqiCaWEChzFQbvTAQ8p638W6o69	17
106	2vaJJGZYVWYQSac3Ap1jkf98Lh2LRTa2NjKfuUCjNKH4FEXJUkAF	19	23185003000060590	3NL4RbFLjKT7L4VVn7DEMMfrxP7NwFiDCNSPanmbTDqjAzGgz5tD	3NKdPQcsTYR7HvVJYnxJs1aw3yqiCaWEChzFQbvTAQ8p638W6o69	17
107	2vavE2xGADiuRjf7FMbZeWtmpouW4pGvvPjzWeXAz8FkZpZ3eCtd	19	23185003000060590	3NL4RbFLjKT7L4VVn7DEMMfrxP7NwFiDCNSPanmbTDqjAzGgz5tD	3NLjXASvew4q1ebEZTaXwvRTkYDNS8RSoyU4CDA7UpeHMeftzAet	18
108	2vadXdUptwH3UpvKvcNMH4HApSDootHe6Ai64gARQAAvWTXdsPDG	19	23185003000060590	3NL4RbFLjKT7L4VVn7DEMMfrxP7NwFiDCNSPanmbTDqjAzGgz5tD	3NKDsSaSdXBk4fCnnd3bbZJ4n7Jf6XKbcxpLBxVXhTVVLQcZ3cJT	19
109	2vc1R4HzDHDgLekbTCEEMT82eenuLeyGMenePa1EgFZFoypZVQ2k	19	23185003000060590	3NL4RbFLjKT7L4VVn7DEMMfrxP7NwFiDCNSPanmbTDqjAzGgz5tD	3NLRhNHJuHZZmSD4Zq8JkvZL5FpkCRQHgfkNG3zbrCbjki8fPajg	20
110	2vaAt7zGYF4oDH1s8Px6REQMtbV16YmNzMoqEDYVSrpgtUBe2HuT	19	23185003000060590	3NL4RbFLjKT7L4VVn7DEMMfrxP7NwFiDCNSPanmbTDqjAzGgz5tD	3NLLY71i6mKExBj8F14J4Z71aM8zGTsy8WMyAAbvo7aymgsdQGiR	21
111	2vaQ3wc5A5vGPUWYLdH2EhGRH5B66EhCQFPyZyL1s75kMoYF2Aeo	19	23185003000060590	3NL4RbFLjKT7L4VVn7DEMMfrxP7NwFiDCNSPanmbTDqjAzGgz5tD	3NL6MPb5BBCLn7Evh5iRSdoESkGnHfmx5pSAfX5ZQcaDzjjcPMgN	22
112	2vaQ3wc5A5vGPUWYLdH2EhGRH5B66EhCQFPyZyL1s75kMoYF2Aeo	19	23185003000060590	3NL4RbFLjKT7L4VVn7DEMMfrxP7NwFiDCNSPanmbTDqjAzGgz5tD	3NL6MPb5BBCLn7Evh5iRSdoESkGnHfmx5pSAfX5ZQcaDzjjcPMgN	23
113	2vaQ3wc5A5vGPUWYLdH2EhGRH5B66EhCQFPyZyL1s75kMoYF2Aeo	19	23185003000060590	3NL4RbFLjKT7L4VVn7DEMMfrxP7NwFiDCNSPanmbTDqjAzGgz5tD	3NL6MPb5BBCLn7Evh5iRSdoESkGnHfmx5pSAfX5ZQcaDzjjcPMgN	24
114	2vaQ3wc5A5vGPUWYLdH2EhGRH5B66EhCQFPyZyL1s75kMoYF2Aeo	19	23185003000060590	3NL4RbFLjKT7L4VVn7DEMMfrxP7NwFiDCNSPanmbTDqjAzGgz5tD	3NL6MPb5BBCLn7Evh5iRSdoESkGnHfmx5pSAfX5ZQcaDzjjcPMgN	25
115	2vaQ3wc5A5vGPUWYLdH2EhGRH5B66EhCQFPyZyL1s75kMoYF2Aeo	19	23185003000060590	3NL4RbFLjKT7L4VVn7DEMMfrxP7NwFiDCNSPanmbTDqjAzGgz5tD	3NL6MPb5BBCLn7Evh5iRSdoESkGnHfmx5pSAfX5ZQcaDzjjcPMgN	26
116	2vaQ3wc5A5vGPUWYLdH2EhGRH5B66EhCQFPyZyL1s75kMoYF2Aeo	19	23185003000060590	3NL4RbFLjKT7L4VVn7DEMMfrxP7NwFiDCNSPanmbTDqjAzGgz5tD	3NL6MPb5BBCLn7Evh5iRSdoESkGnHfmx5pSAfX5ZQcaDzjjcPMgN	27
117	2vaQ3wc5A5vGPUWYLdH2EhGRH5B66EhCQFPyZyL1s75kMoYF2Aeo	19	23185003000060590	3NL4RbFLjKT7L4VVn7DEMMfrxP7NwFiDCNSPanmbTDqjAzGgz5tD	3NL6MPb5BBCLn7Evh5iRSdoESkGnHfmx5pSAfX5ZQcaDzjjcPMgN	28
118	2vaQ3wc5A5vGPUWYLdH2EhGRH5B66EhCQFPyZyL1s75kMoYF2Aeo	19	23185003000060590	3NL4RbFLjKT7L4VVn7DEMMfrxP7NwFiDCNSPanmbTDqjAzGgz5tD	3NL6MPb5BBCLn7Evh5iRSdoESkGnHfmx5pSAfX5ZQcaDzjjcPMgN	29
119	2vaQ3wc5A5vGPUWYLdH2EhGRH5B66EhCQFPyZyL1s75kMoYF2Aeo	19	23185003000060590	3NL4RbFLjKT7L4VVn7DEMMfrxP7NwFiDCNSPanmbTDqjAzGgz5tD	3NL6MPb5BBCLn7Evh5iRSdoESkGnHfmx5pSAfX5ZQcaDzjjcPMgN	30
120	2vaQ3wc5A5vGPUWYLdH2EhGRH5B66EhCQFPyZyL1s75kMoYF2Aeo	19	23185003000060590	3NL4RbFLjKT7L4VVn7DEMMfrxP7NwFiDCNSPanmbTDqjAzGgz5tD	3NL6MPb5BBCLn7Evh5iRSdoESkGnHfmx5pSAfX5ZQcaDzjjcPMgN	31
121	2vaQ3wc5A5vGPUWYLdH2EhGRH5B66EhCQFPyZyL1s75kMoYF2Aeo	19	23185003000060590	3NL4RbFLjKT7L4VVn7DEMMfrxP7NwFiDCNSPanmbTDqjAzGgz5tD	3NL6MPb5BBCLn7Evh5iRSdoESkGnHfmx5pSAfX5ZQcaDzjjcPMgN	32
122	2vasmnJnGPGmbweMcYV6DSuxY33GrvqymgzNNiUNX8aZD7zbvi4q	33	23197603000060590	3NKrYZfL32Eg8WAaWbYSVZadLV2qKRwJomV7tyPaVUsMAqAeXTEj	3NKrYZfL32Eg8WAaWbYSVZadLV2qKRwJomV7tyPaVUsMAqAeXTEj	1
123	2vaCwzAzpJwwkwdSqXhw53T6sTVVwoaVyEzxGY9bvd9MqCrisnEp	33	23197603000060590	3NKrYZfL32Eg8WAaWbYSVZadLV2qKRwJomV7tyPaVUsMAqAeXTEj	3NL1h88UYpD3Gp42qAPeAK9yjiZrSf82t5Wp3TbZuQojWY5nu7yk	2
124	2vbUvLzdwsXAKVLotBZ16RBvvVkjwqkPcNbiF4RYAm8yLwvdoWUG	33	23197603000060590	3NKrYZfL32Eg8WAaWbYSVZadLV2qKRwJomV7tyPaVUsMAqAeXTEj	3NLUdJ4ZFfrxtW1ZFTqkpMsx6xnFqv29Z1vzaA89pigKC269iFoX	3
125	2vacH6XYKY9tMBPdurq3G3fxK1aWKqnV2Z2jkvP3kFC7TA4efh55	33	23197603000060590	3NKrYZfL32Eg8WAaWbYSVZadLV2qKRwJomV7tyPaVUsMAqAeXTEj	3NL2iqkBvWXk3bA1FkfxymeNYtAu8gsGvWYDAdt28rrVrZGia4Mt	4
126	2vaqqadLE5QfNM67MQYvx6Eshn8ffKSNSoFANNSpTqVWg4tyP8UY	33	23197603000060590	3NKrYZfL32Eg8WAaWbYSVZadLV2qKRwJomV7tyPaVUsMAqAeXTEj	3NL2iqkBvWXk3bA1FkfxymeNYtAu8gsGvWYDAdt28rrVrZGia4Mt	4
127	2vbNc22HZsm9z76sJy6LXDvyh5iVbuD8nd43UYRjD8nSkLzsJfA8	33	23197603000060590	3NKrYZfL32Eg8WAaWbYSVZadLV2qKRwJomV7tyPaVUsMAqAeXTEj	3NKLZ3BSU3e5j3T3ht7jL8sLT3JoKz3LRp2Xby1UxRHuH1J5j1kY	5
128	2vbsrYV7t8V8zdHR5dsQBCsCQGAqRMEhjHEUTmzoMuTjKhwkf4Sg	33	23197603000060590	3NKrYZfL32Eg8WAaWbYSVZadLV2qKRwJomV7tyPaVUsMAqAeXTEj	3NL483QxnbeP7rctjCed4mN6CY5ue5qRqSCQDvJMBmM5pBBdYQGS	6
129	2vbVLFyQd2swpRU74Hm3cZx8RGJg4LasN73UV6QSvjF2fARepu1s	33	23197603000060590	3NKrYZfL32Eg8WAaWbYSVZadLV2qKRwJomV7tyPaVUsMAqAeXTEj	3NL483QxnbeP7rctjCed4mN6CY5ue5qRqSCQDvJMBmM5pBBdYQGS	6
130	2vaMmvBXeLZaVd8BQbaq3QwsFn55MwF72nKxgkZvihQYXHXm6y7n	33	23197603000060590	3NKrYZfL32Eg8WAaWbYSVZadLV2qKRwJomV7tyPaVUsMAqAeXTEj	3NLUU3inLaZgPemiCHQ4xJD1qLL4z16xgQ6euSsqKuf1vKb1uNww	7
131	2vbUZgt4yNCenFP9bkUR6BqzFBh7caP9CA1PpYJCV917gSw1qbhP	33	23197603000060590	3NKrYZfL32Eg8WAaWbYSVZadLV2qKRwJomV7tyPaVUsMAqAeXTEj	3NK7BYvDfccvu28cwJJDeBCC8rusoLihqnhWykxnnVGXJsZ4MK5h	8
132	2vb6to9ePrYUhwuCtTE24dLnJWwuxBYjJRA35p4xA1oXuA1GvBQa	33	23197603000060590	3NKrYZfL32Eg8WAaWbYSVZadLV2qKRwJomV7tyPaVUsMAqAeXTEj	3NK7BYvDfccvu28cwJJDeBCC8rusoLihqnhWykxnnVGXJsZ4MK5h	8
133	2vaDqbGhmRTVo6QvGBWAkEvdeUStEdDgqxQy6zTeoQrEeSfNm8hN	33	23197603000060590	3NKrYZfL32Eg8WAaWbYSVZadLV2qKRwJomV7tyPaVUsMAqAeXTEj	3NKkU7yUVL3bxQYzyw7TVr8UncCSMdf9VKcBKdU65t64oXXfjrzp	9
134	2vaP1A7VZ71VR9gJTGqj8sxJckG5LxQ6XtxAA8aiCjdvpRr6vpzQ	33	23197603000060590	3NKrYZfL32Eg8WAaWbYSVZadLV2qKRwJomV7tyPaVUsMAqAeXTEj	3NLFiH3WzyK1vTW5NRiuZZ3ypJwgGJqBZ2Uch9R9cp4petWLRKht	10
135	2vbd5KSHrVsayVqGj9aVE9xGvuB7cde6cy4RjTnRTVXvjezYF76W	33	23197603000060590	3NKrYZfL32Eg8WAaWbYSVZadLV2qKRwJomV7tyPaVUsMAqAeXTEj	3NLv2ZqNUfm1RLeSXjMm51rBgmRMT6jFnvpA8tCM2P3fapagJoJx	11
136	2vbWFDqV12kLetTGzDfPJSEcWDenwEthExXaV8FuCnSRH7mZCvzS	33	23197603000060590	3NKrYZfL32Eg8WAaWbYSVZadLV2qKRwJomV7tyPaVUsMAqAeXTEj	3NLC12Pe4biW7Xg7oRwMGYLNYj3FmEHFbT5E9K5u5p6JjuQvsiaA	12
137	2vc3ffa2fQPsWRTTVk6AAd784YshRukRD5D8RqQCZNxBDrNTteqj	33	23197603000060590	3NKrYZfL32Eg8WAaWbYSVZadLV2qKRwJomV7tyPaVUsMAqAeXTEj	3NLQp2xkczmM63kpzEQdRop9QFQWRJ6vL7LBqfsyNDDYyPc2mmLZ	13
138	2vajbBekkXnztRehtgaZpb8kA7P9qtKe9HJpH66VbHpNFvWXTggR	33	23197603000060590	3NKrYZfL32Eg8WAaWbYSVZadLV2qKRwJomV7tyPaVUsMAqAeXTEj	3NLQp2xkczmM63kpzEQdRop9QFQWRJ6vL7LBqfsyNDDYyPc2mmLZ	13
139	2vbzo2ATXGr8aZbw2KUqsEFn4C8kbNahbaxx5qsiJfFhFCovqVe5	33	23197603000060590	3NKrYZfL32Eg8WAaWbYSVZadLV2qKRwJomV7tyPaVUsMAqAeXTEj	3NLHHRPstXo8Mio2T7LTkawj3d4M7QjKhR4duQtCKyB9EKQ9sTMM	14
140	2vbn2bZmFy9BxaEaTgm6ng4pgVgfJb9yhN6gD884Sh97ga26sMNt	33	23197603000060590	3NKrYZfL32Eg8WAaWbYSVZadLV2qKRwJomV7tyPaVUsMAqAeXTEj	3NLimf64JHeNpUZh55FDws2ZpuUtG8fZxKbDNs822zcvEzUzbyKK	15
141	2vb7VP4aNHiPvQK1unT3Eshc98smcNNsbZYLe9FMsj136MGfqvey	33	23197603000060590	3NKrYZfL32Eg8WAaWbYSVZadLV2qKRwJomV7tyPaVUsMAqAeXTEj	3NLiKKr4ao5dYD4iwqZ5FQYbCHmFAQTuMV3fCpRvZZ7qCYgky5Xa	16
142	2vartQCJzpmhjrfNeJna4aQSMr5w13JAcQtu2To1KR8LKhhHpoWe	33	23197603000060590	3NKrYZfL32Eg8WAaWbYSVZadLV2qKRwJomV7tyPaVUsMAqAeXTEj	3NLD1FdPyddumMDd6dtSst7dUcuaLevyH36PAiKdAA2P7sRzhZvM	17
143	2vahJSX3TA8SU7UhAu3b7EDpbVmmhCL1oqLinkGiVdhXzzHEcX19	33	23197603000060590	3NKrYZfL32Eg8WAaWbYSVZadLV2qKRwJomV7tyPaVUsMAqAeXTEj	3NLLnN3Y2E3QP2akdTTKKvfW98NuSGLKsf84n2QbRkrjsX6gLFH7	18
144	2vbBHCw4rdAnTbZYih2KBnpJrx9gU1cWSseMVxy2kvM2idp8zq9b	33	23197603000060590	3NKrYZfL32Eg8WAaWbYSVZadLV2qKRwJomV7tyPaVUsMAqAeXTEj	3NKcooBzxvW4kwGKssewzApEymKhy9qrP8pdtPAxYHCaya7J8bTm	19
145	2vbQ5qwPLtpx9j1AWKncam9evB8UNoyFxPfPLRqoMqGwY5r316dA	33	23197603000060590	3NKrYZfL32Eg8WAaWbYSVZadLV2qKRwJomV7tyPaVUsMAqAeXTEj	3NLYPvgh9x5GivMn5m7NLb98tzDupCE19PQpkobgC58mnGkiuyev	20
146	2vaLQbPyNTUm8xqu2MC1fta8K1T6MtRctX68FFqUeCXnvjbGKgaA	33	23197603000060590	3NKrYZfL32Eg8WAaWbYSVZadLV2qKRwJomV7tyPaVUsMAqAeXTEj	3NKHsmpgtrQrw1KFHnnzEo5PVGLESjciiLKy5oUEvqYUCRFPLzCW	21
147	2vaC3sbhtG3RtKsYWTMW1gLq3MXQsBt5u5wyfKAaiywsTE7Ym2EP	33	23197603000060590	3NKrYZfL32Eg8WAaWbYSVZadLV2qKRwJomV7tyPaVUsMAqAeXTEj	3NLMTCVnT6VENjTowuomzP9ZcehLQBrL8nyi3Hx7cMdKqAhesJJk	22
148	2vaC3sbhtG3RtKsYWTMW1gLq3MXQsBt5u5wyfKAaiywsTE7Ym2EP	33	23197603000060590	3NKrYZfL32Eg8WAaWbYSVZadLV2qKRwJomV7tyPaVUsMAqAeXTEj	3NLMTCVnT6VENjTowuomzP9ZcehLQBrL8nyi3Hx7cMdKqAhesJJk	23
149	2vaC3sbhtG3RtKsYWTMW1gLq3MXQsBt5u5wyfKAaiywsTE7Ym2EP	33	23197603000060590	3NKrYZfL32Eg8WAaWbYSVZadLV2qKRwJomV7tyPaVUsMAqAeXTEj	3NLMTCVnT6VENjTowuomzP9ZcehLQBrL8nyi3Hx7cMdKqAhesJJk	24
150	2vaC3sbhtG3RtKsYWTMW1gLq3MXQsBt5u5wyfKAaiywsTE7Ym2EP	33	23197603000060590	3NKrYZfL32Eg8WAaWbYSVZadLV2qKRwJomV7tyPaVUsMAqAeXTEj	3NLMTCVnT6VENjTowuomzP9ZcehLQBrL8nyi3Hx7cMdKqAhesJJk	25
151	2vaC3sbhtG3RtKsYWTMW1gLq3MXQsBt5u5wyfKAaiywsTE7Ym2EP	33	23197603000060590	3NKrYZfL32Eg8WAaWbYSVZadLV2qKRwJomV7tyPaVUsMAqAeXTEj	3NLMTCVnT6VENjTowuomzP9ZcehLQBrL8nyi3Hx7cMdKqAhesJJk	26
152	2vaC3sbhtG3RtKsYWTMW1gLq3MXQsBt5u5wyfKAaiywsTE7Ym2EP	33	23197603000060590	3NKrYZfL32Eg8WAaWbYSVZadLV2qKRwJomV7tyPaVUsMAqAeXTEj	3NLMTCVnT6VENjTowuomzP9ZcehLQBrL8nyi3Hx7cMdKqAhesJJk	27
153	2vaC3sbhtG3RtKsYWTMW1gLq3MXQsBt5u5wyfKAaiywsTE7Ym2EP	33	23197603000060590	3NKrYZfL32Eg8WAaWbYSVZadLV2qKRwJomV7tyPaVUsMAqAeXTEj	3NLMTCVnT6VENjTowuomzP9ZcehLQBrL8nyi3Hx7cMdKqAhesJJk	28
154	2vaC3sbhtG3RtKsYWTMW1gLq3MXQsBt5u5wyfKAaiywsTE7Ym2EP	33	23197603000060590	3NKrYZfL32Eg8WAaWbYSVZadLV2qKRwJomV7tyPaVUsMAqAeXTEj	3NLMTCVnT6VENjTowuomzP9ZcehLQBrL8nyi3Hx7cMdKqAhesJJk	29
155	2vaC3sbhtG3RtKsYWTMW1gLq3MXQsBt5u5wyfKAaiywsTE7Ym2EP	33	23197603000060590	3NKrYZfL32Eg8WAaWbYSVZadLV2qKRwJomV7tyPaVUsMAqAeXTEj	3NLMTCVnT6VENjTowuomzP9ZcehLQBrL8nyi3Hx7cMdKqAhesJJk	30
156	2vaC3sbhtG3RtKsYWTMW1gLq3MXQsBt5u5wyfKAaiywsTE7Ym2EP	33	23197603000060590	3NKrYZfL32Eg8WAaWbYSVZadLV2qKRwJomV7tyPaVUsMAqAeXTEj	3NLMTCVnT6VENjTowuomzP9ZcehLQBrL8nyi3Hx7cMdKqAhesJJk	31
157	2vaC3sbhtG3RtKsYWTMW1gLq3MXQsBt5u5wyfKAaiywsTE7Ym2EP	33	23197603000060590	3NKrYZfL32Eg8WAaWbYSVZadLV2qKRwJomV7tyPaVUsMAqAeXTEj	3NLMTCVnT6VENjTowuomzP9ZcehLQBrL8nyi3Hx7cMdKqAhesJJk	32
158	2vaC3sbhtG3RtKsYWTMW1gLq3MXQsBt5u5wyfKAaiywsTE7Ym2EP	33	23197603000060590	3NKrYZfL32Eg8WAaWbYSVZadLV2qKRwJomV7tyPaVUsMAqAeXTEj	3NLMTCVnT6VENjTowuomzP9ZcehLQBrL8nyi3Hx7cMdKqAhesJJk	33
159	2vaV6rtkPf9R58aw2dt6vmh9EP6H37Ps3H5ZYbNmYuHZd5pQ9y4p	48	23208763000060590	3NKwnP4qUMBCxUwTBcwsoqH1wtaUga2Tmp8ZACEaEpvi8CHEjaYv	3NKwnP4qUMBCxUwTBcwsoqH1wtaUga2Tmp8ZACEaEpvi8CHEjaYv	1
160	2vbeMHPKWyZKz9skCzW5XowrKXjP8Y6NhQxgMGFvqn1V1YLgJHvg	48	23208763000060590	3NKwnP4qUMBCxUwTBcwsoqH1wtaUga2Tmp8ZACEaEpvi8CHEjaYv	3NKwnP4qUMBCxUwTBcwsoqH1wtaUga2Tmp8ZACEaEpvi8CHEjaYv	1
161	2vbFXudvZCKYbM4j2Rg4Gpw2834VfLPBe9NDniYvPGtU3ZuruzZ5	48	23208763000060590	3NKwnP4qUMBCxUwTBcwsoqH1wtaUga2Tmp8ZACEaEpvi8CHEjaYv	3NKv5M5cYnoKtiKRqg2zcG3bQ53HnFhSFhp5CpiXY9bvRV3QwJaz	2
162	2vbmcWNH1JuSHM4rCBWF8KuEgcpePARZjibhpgctS7Khv8zKhbve	48	23208763000060590	3NKwnP4qUMBCxUwTBcwsoqH1wtaUga2Tmp8ZACEaEpvi8CHEjaYv	3NKLoNKhFcj1iXRnosu4pqyxMKp1n8uwAXLJPSFeUa1DJzjTM3iP	3
163	2vb5dmDkP1GHiCxd8KDkE3XMXQPQw3sFACubrnksiEEeeNeQqHRo	48	23208763000060590	3NKwnP4qUMBCxUwTBcwsoqH1wtaUga2Tmp8ZACEaEpvi8CHEjaYv	3NKWBAGYWuKTJpCPRZpzbpzhw3CpcRtJby1N9gC4H75W2XWtSs13	4
164	2vaiwdPEQDVZvzf8hFptceqZoMd1m6ufXU1WecDK8WD7qMiAhCwU	48	23208763000060590	3NKwnP4qUMBCxUwTBcwsoqH1wtaUga2Tmp8ZACEaEpvi8CHEjaYv	3NKWBAGYWuKTJpCPRZpzbpzhw3CpcRtJby1N9gC4H75W2XWtSs13	4
165	2vbu51BczY4FE21FUv9Lby6r3Yzp31VppC5fShG4Sx6zDEDrFHWD	48	23208763000060590	3NKwnP4qUMBCxUwTBcwsoqH1wtaUga2Tmp8ZACEaEpvi8CHEjaYv	3NK716o9tMtEp4mzTQLYHkTpin8sWtfDmA73Vj3kNaES7wzQSLJC	5
166	2vbQ6i7HnC5yZ2aJZMHSs16qCbiPCrXZLC4aXuH1PYugMiredM1Y	48	23208763000060590	3NKwnP4qUMBCxUwTBcwsoqH1wtaUga2Tmp8ZACEaEpvi8CHEjaYv	3NLLzqVtQWfhbuv5hzNeqnPPMSZLtrEQ77vR8wYRSDdTirEbzaUq	6
167	2vaN7h9Wcw9G926L6hg2U8N67CvnJopWb5iBLDVd6FWNwZmRYSqy	48	23208763000060590	3NKwnP4qUMBCxUwTBcwsoqH1wtaUga2Tmp8ZACEaEpvi8CHEjaYv	3NLAcbL2K5zXEVvf5kBaajJQy5Xy8KTtiZ3P6Mi5pfApSUftqvCz	7
168	2vbuLuk8ZcWgtd4sUpronKpzV6NAYLmzmwse7toU5SKn72RSX3U1	48	23208763000060590	3NKwnP4qUMBCxUwTBcwsoqH1wtaUga2Tmp8ZACEaEpvi8CHEjaYv	3NLcKWsdK9pD7ZR2wSGi2bhUwFU5UvJ9MiWtJGDL1skGzmDsfeMA	8
169	2vadQX6RG17pmcJMbFotDDN5UpkkV6mqQjp6TtvP1Tp7bXYcANvL	48	23208763000060590	3NKwnP4qUMBCxUwTBcwsoqH1wtaUga2Tmp8ZACEaEpvi8CHEjaYv	3NLVh84pEbYQp81NAGeVGvNtohLtCRCXyyGY1escEuyzWgHNjZE6	9
170	2vbKLusp8UtnUHpGBTqYARzMifiA4rYyfZcmPymPPRjzQB7WuEJ1	48	23208763000060590	3NKwnP4qUMBCxUwTBcwsoqH1wtaUga2Tmp8ZACEaEpvi8CHEjaYv	3NK4zN3h1HYHTt2LmHLF29RqTcyFTWEAwFdti4FGL4yy4xr5UaNE	10
171	2vaQv29X9rY19d3kp5i7aSU9KPDDE1XgYwz8HSsHWnWoxk7raU7t	48	23208763000060590	3NKwnP4qUMBCxUwTBcwsoqH1wtaUga2Tmp8ZACEaEpvi8CHEjaYv	3NKbAcJbMm4QzcBuCbuVpHoMWVi1ho6v6G9u6sQGjbsFYUkgHdif	11
172	2vaAHcDWcdhuASnWHcTVSSos33XZ1UXx2ZSet9vGUE3z95nFiSYE	48	23208763000060590	3NKwnP4qUMBCxUwTBcwsoqH1wtaUga2Tmp8ZACEaEpvi8CHEjaYv	3NKbAcJbMm4QzcBuCbuVpHoMWVi1ho6v6G9u6sQGjbsFYUkgHdif	11
173	2vaQv3RSghs4t1sJ2M6XQJ4tBi33fxknGXSNpCF6Nh19PZaKJyoy	48	23208763000060590	3NKwnP4qUMBCxUwTBcwsoqH1wtaUga2Tmp8ZACEaEpvi8CHEjaYv	3NLVbPUsjxX4LSmfp8ML1zaWAQuXAsapguQGzSoBBgCgbjDwUMUF	12
174	2vbBjyhg9b28FDVgWmTxkpC5yttyGqDzLpJq2fGt6raDuRd5gqcA	48	23208763000060590	3NKwnP4qUMBCxUwTBcwsoqH1wtaUga2Tmp8ZACEaEpvi8CHEjaYv	3NLVbPUsjxX4LSmfp8ML1zaWAQuXAsapguQGzSoBBgCgbjDwUMUF	12
175	2vaQsi9XZVcHrCKgMUiB6XZNv5drc2tB1F5uNSfQ3LjK9tnbXFph	48	23208763000060590	3NKwnP4qUMBCxUwTBcwsoqH1wtaUga2Tmp8ZACEaEpvi8CHEjaYv	3NKZ7UM9xn1YXX37eBM8ffK3WBCLmn6re1a8wY5ofpwSJLBbSn5C	13
176	2vb7MUp6XcDJgx76owT6y5S6YZEZr1SujGYtcnpwXG4XKvwMsD2x	48	23208763000060590	3NKwnP4qUMBCxUwTBcwsoqH1wtaUga2Tmp8ZACEaEpvi8CHEjaYv	3NKgn6W3qhxtAtkpgv47eJfjTZvSVxnp1Eid13CMk1kkaXKmNSoW	14
177	2vaApBttjNKRgp5TEUwYDvhZ3Z8jvkry2ogNfgvAtWQU3vs9UvR8	48	23208763000060590	3NKwnP4qUMBCxUwTBcwsoqH1wtaUga2Tmp8ZACEaEpvi8CHEjaYv	3NL7ZdXJbS75izBdrA1bi1HGNKypZ2TVtS7trfN4YhfCyXToo5bd	15
178	2vawTbFxBSRxu6nj7432LHbLX1TKy9RbKY5mYAV7kpybxqmxFCc3	48	23208763000060590	3NKwnP4qUMBCxUwTBcwsoqH1wtaUga2Tmp8ZACEaEpvi8CHEjaYv	3NKupaQPTcV4auGkm5X6UFfXxryGgJ6qXLzv3dznYEAFXU7XCYW2	16
179	2vbYZCCT36GB1FUffwE6edioLT5LygNGA3shTFro5jpvpMrvtC7c	48	23208763000060590	3NKwnP4qUMBCxUwTBcwsoqH1wtaUga2Tmp8ZACEaEpvi8CHEjaYv	3NKupaQPTcV4auGkm5X6UFfXxryGgJ6qXLzv3dznYEAFXU7XCYW2	16
180	2vagheBYdLHZ5A5BHJkBRV8r7MGk7ZvLNKfs35JQUvFiiY5kbLdn	48	23208763000060590	3NKwnP4qUMBCxUwTBcwsoqH1wtaUga2Tmp8ZACEaEpvi8CHEjaYv	3NLkToZDpTZs5LgJaSGHF5XZifWit3sRtUxLEo9w7cMMx1jeJzqV	17
181	2vaMghHppCdGnDscbNLN2hqMjUVtX6KRQyHir1BD5zFiV1WG4RZp	48	23208763000060590	3NKwnP4qUMBCxUwTBcwsoqH1wtaUga2Tmp8ZACEaEpvi8CHEjaYv	3NKmTsT33eZJN8WbSgY87kqhoQfh4XKidMPsCRN5jo79cDWPPymB	18
182	2vazu3mgCLKosN3rP1xapwp9ynwjWhvh8YfdF2AZJbdHVrPLTxna	48	23208763000060590	3NKwnP4qUMBCxUwTBcwsoqH1wtaUga2Tmp8ZACEaEpvi8CHEjaYv	3NL7sbpk2t8aQ7PGeABvT2gaSVZAKYDJBm2NVJ3sQLvSMjhBiZ8H	19
183	2vaTVZ6THkkf8acQ1VTXCkzegfrUhErYRpvrxffVyCu9qZATkjvW	48	23208763000060590	3NKwnP4qUMBCxUwTBcwsoqH1wtaUga2Tmp8ZACEaEpvi8CHEjaYv	3NLeZZmkRX5iAR8oT5AqxyAC7MWD5mUAif886cX2xjJP7KaXCHSt	20
184	2vaAFxy4MtLGiS2F9AFigb7nGyymU5YnB4o5KSKkaFZPVc2EKVvz	48	23208763000060590	3NKwnP4qUMBCxUwTBcwsoqH1wtaUga2Tmp8ZACEaEpvi8CHEjaYv	3NLeZZmkRX5iAR8oT5AqxyAC7MWD5mUAif886cX2xjJP7KaXCHSt	20
185	2vatz2UGCXkDigQ3nxdjJaNPgSydP8UgaQcvbvaLQ1goEEYEgwJR	48	23208763000060590	3NKwnP4qUMBCxUwTBcwsoqH1wtaUga2Tmp8ZACEaEpvi8CHEjaYv	3NLeZZmkRX5iAR8oT5AqxyAC7MWD5mUAif886cX2xjJP7KaXCHSt	20
186	2vavQCSXVxVBe8CAtaBSE6EvGubZsGir5ZpbaXC6KGDbEHiDg3bH	48	23208763000060590	3NKwnP4qUMBCxUwTBcwsoqH1wtaUga2Tmp8ZACEaEpvi8CHEjaYv	3NL8GvSV2kNoQ8H84T4L5sbT1JvjrNiagTdt7VFwoTXAbRpDRhVw	21
187	2vbiXQwqhUkkfShZtEo6TQyUhhM81Xprrr8bXMonnXNvqUEmPsNR	48	23208763000060590	3NKwnP4qUMBCxUwTBcwsoqH1wtaUga2Tmp8ZACEaEpvi8CHEjaYv	3NLvsknHDFRSUQsZKcDftGTYJnnaUg3npcGR4rwD1Azhs81gYuGZ	22
188	2vandKtgp5H6HRUvvp2kKXZ4gkjEgZmexLGBtu57Z3LPZa6TnpR7	48	23208763000060590	3NKwnP4qUMBCxUwTBcwsoqH1wtaUga2Tmp8ZACEaEpvi8CHEjaYv	3NKt4RC1zfBwpcY1iVLH2zKRZjQzfBSEgT9cgRMZWcnD93LSuuJf	23
189	2vbnLFQ5fERiW5Se15QZN9Dgk2CK6US5SRKgmzcrx7JpMbn2HgP9	48	23208763000060590	3NKwnP4qUMBCxUwTBcwsoqH1wtaUga2Tmp8ZACEaEpvi8CHEjaYv	3NKt4RC1zfBwpcY1iVLH2zKRZjQzfBSEgT9cgRMZWcnD93LSuuJf	23
190	2vbCKmYMRNuvL8tiPCmyZQTFPjCHVZAdj1engmN7mT8s2iBeM4uQ	48	23208763000060590	3NKwnP4qUMBCxUwTBcwsoqH1wtaUga2Tmp8ZACEaEpvi8CHEjaYv	3NKse9idNYGHKEp9nWYm271vn9sTZ7Jc2UCFznKssBRJCAHxs6V2	24
191	2vb34sN1n1Mzx9cmKy7pLPLnSDqeNprQ7SVAXXMLidtEXEdLzfrs	48	23208763000060590	3NKwnP4qUMBCxUwTBcwsoqH1wtaUga2Tmp8ZACEaEpvi8CHEjaYv	3NLtH6WSePCmU4ik8LYpovKPa2nMjR2EMwS35udQJ3sZEchdcvZ7	25
192	2vaowsHd9HrHdqZMp4oqCiG4nSmDgE8ct34gRBD7krptjTCEQtz3	48	23208763000060590	3NKwnP4qUMBCxUwTBcwsoqH1wtaUga2Tmp8ZACEaEpvi8CHEjaYv	3NLiRbrEy35HK7X9znjiG9MzCdqApLHrwGqHtNPbeDQ7ZjkWvz3B	26
193	2vbyYmgCkitStd9pWnxzqFA5j7xGjnbxoP2NmzDEwQPPRFmdJNGR	48	23208763000060590	3NKwnP4qUMBCxUwTBcwsoqH1wtaUga2Tmp8ZACEaEpvi8CHEjaYv	3NK7xJ39b5US7c8Rq2QDRoJWBjEMrp9UQEf5x2jgWdQP1Aydjeob	27
194	2vaWKHnEGDfq5MxtYiQyU9UknPgXtBHSZcDsEmFyS4knrMUwzM94	48	23208763000060590	3NKwnP4qUMBCxUwTBcwsoqH1wtaUga2Tmp8ZACEaEpvi8CHEjaYv	3NL2Mokrh2oCDeXN6xGNH8NJFTJnvCtyPFen9VhreXpJ5X8jNBGt	28
195	2vaWKHnEGDfq5MxtYiQyU9UknPgXtBHSZcDsEmFyS4knrMUwzM94	48	23208763000060590	3NKwnP4qUMBCxUwTBcwsoqH1wtaUga2Tmp8ZACEaEpvi8CHEjaYv	3NL2Mokrh2oCDeXN6xGNH8NJFTJnvCtyPFen9VhreXpJ5X8jNBGt	29
196	2vaWKHnEGDfq5MxtYiQyU9UknPgXtBHSZcDsEmFyS4knrMUwzM94	48	23208763000060590	3NKwnP4qUMBCxUwTBcwsoqH1wtaUga2Tmp8ZACEaEpvi8CHEjaYv	3NL2Mokrh2oCDeXN6xGNH8NJFTJnvCtyPFen9VhreXpJ5X8jNBGt	30
197	2vaWKHnEGDfq5MxtYiQyU9UknPgXtBHSZcDsEmFyS4knrMUwzM94	48	23208763000060590	3NKwnP4qUMBCxUwTBcwsoqH1wtaUga2Tmp8ZACEaEpvi8CHEjaYv	3NL2Mokrh2oCDeXN6xGNH8NJFTJnvCtyPFen9VhreXpJ5X8jNBGt	31
198	2vaWKHnEGDfq5MxtYiQyU9UknPgXtBHSZcDsEmFyS4knrMUwzM94	48	23208763000060590	3NKwnP4qUMBCxUwTBcwsoqH1wtaUga2Tmp8ZACEaEpvi8CHEjaYv	3NL2Mokrh2oCDeXN6xGNH8NJFTJnvCtyPFen9VhreXpJ5X8jNBGt	32
199	2vaWKHnEGDfq5MxtYiQyU9UknPgXtBHSZcDsEmFyS4knrMUwzM94	48	23208763000060590	3NKwnP4qUMBCxUwTBcwsoqH1wtaUga2Tmp8ZACEaEpvi8CHEjaYv	3NL2Mokrh2oCDeXN6xGNH8NJFTJnvCtyPFen9VhreXpJ5X8jNBGt	33
200	2vaWKHnEGDfq5MxtYiQyU9UknPgXtBHSZcDsEmFyS4knrMUwzM94	48	23208763000060590	3NKwnP4qUMBCxUwTBcwsoqH1wtaUga2Tmp8ZACEaEpvi8CHEjaYv	3NL2Mokrh2oCDeXN6xGNH8NJFTJnvCtyPFen9VhreXpJ5X8jNBGt	34
201	2vaWKHnEGDfq5MxtYiQyU9UknPgXtBHSZcDsEmFyS4knrMUwzM94	48	23208763000060590	3NKwnP4qUMBCxUwTBcwsoqH1wtaUga2Tmp8ZACEaEpvi8CHEjaYv	3NL2Mokrh2oCDeXN6xGNH8NJFTJnvCtyPFen9VhreXpJ5X8jNBGt	35
202	2vaWKHnEGDfq5MxtYiQyU9UknPgXtBHSZcDsEmFyS4knrMUwzM94	48	23208763000060590	3NKwnP4qUMBCxUwTBcwsoqH1wtaUga2Tmp8ZACEaEpvi8CHEjaYv	3NL2Mokrh2oCDeXN6xGNH8NJFTJnvCtyPFen9VhreXpJ5X8jNBGt	36
203	2vaWKHnEGDfq5MxtYiQyU9UknPgXtBHSZcDsEmFyS4knrMUwzM94	48	23208763000060590	3NKwnP4qUMBCxUwTBcwsoqH1wtaUga2Tmp8ZACEaEpvi8CHEjaYv	3NL2Mokrh2oCDeXN6xGNH8NJFTJnvCtyPFen9VhreXpJ5X8jNBGt	37
204	2vaWKHnEGDfq5MxtYiQyU9UknPgXtBHSZcDsEmFyS4knrMUwzM94	48	23208763000060590	3NKwnP4qUMBCxUwTBcwsoqH1wtaUga2Tmp8ZACEaEpvi8CHEjaYv	3NL2Mokrh2oCDeXN6xGNH8NJFTJnvCtyPFen9VhreXpJ5X8jNBGt	38
205	2vbGRNLafGVu4Q8qy4euqwmbg89P1NkE9ncAZNq39b2ZVoVov3dS	63	23222443000060590	3NKmXxADED2SzUDnMzHGwSgjC1siDFVPu7HKiwKBMzgwC1ZR6LVn	3NKmXxADED2SzUDnMzHGwSgjC1siDFVPu7HKiwKBMzgwC1ZR6LVn	1
206	2vbocFvK7DarFvZuvZDLi5JWFK4ytuK9Nxs57HVVxq3uGtYdBguY	63	23222443000060590	3NKmXxADED2SzUDnMzHGwSgjC1siDFVPu7HKiwKBMzgwC1ZR6LVn	3NKmXxADED2SzUDnMzHGwSgjC1siDFVPu7HKiwKBMzgwC1ZR6LVn	1
207	2vb8CaCCFNpjifza81go1wuGT8t4GVS88Fut5fd8hdqZpG1BUidD	63	23222443000060590	3NKmXxADED2SzUDnMzHGwSgjC1siDFVPu7HKiwKBMzgwC1ZR6LVn	3NKFbzCEXMjPGNbT2CwXE4ieBDWK1vapH2DA8GX9hXpDgajcCnyM	2
208	2vaYsTk2BwPBns8ovRCcTrYaF8bu53LNFU59JjisZqcTJcEL19ec	63	23222443000060590	3NKmXxADED2SzUDnMzHGwSgjC1siDFVPu7HKiwKBMzgwC1ZR6LVn	3NKSNkwzgzUrSiHagjnZcquLTWZXL9oxqaxEFpXQY5bhp1FWDUxK	3
209	2vbmBDG4BWRdBSdyPz3AScknzHqVXj9Su24F8KmVCEZFXDBghE4t	63	23222443000060590	3NKmXxADED2SzUDnMzHGwSgjC1siDFVPu7HKiwKBMzgwC1ZR6LVn	3NL7TexeQHm1XXyTGKeo9YLGKqnvjWoNxXzdcrRpsmEgsP8cdCZa	4
210	2vbVL5R4p8ke1LHEswzGvWqGhfC3GDhyac4cy83sWqnzgFffwcCZ	63	23222443000060590	3NKmXxADED2SzUDnMzHGwSgjC1siDFVPu7HKiwKBMzgwC1ZR6LVn	3NLeuVCWf7u3PRtn2iE8kbxF4ZqhErsBfeYcfRP63P6yzSRXawTn	5
211	2vbLSeNLamq2XZ7LN8snHqKZYmw2UTMAALPSo5hruxL3fbUwa9cc	63	23222443000060590	3NKmXxADED2SzUDnMzHGwSgjC1siDFVPu7HKiwKBMzgwC1ZR6LVn	3NKJAsoYTPQ3iWRtrj8YRMtX6MgUERx2QPS1yv65dLHPhRedM5Ar	6
212	2vbEwhGwDZZeGiEZYGJ2xAqDNdPLzTAYv6zLFAEKvYoQj5FoP5m1	63	23222443000060590	3NKmXxADED2SzUDnMzHGwSgjC1siDFVPu7HKiwKBMzgwC1ZR6LVn	3NLf8Dv22tr7ir4MziPGdfRCYQ8BBDSVJY5vTDZJRdrhxvbrzZkj	7
213	2vacqV4sD3Q28aZACUqUwgcuGiwjsfYmB4eiHDR5qnvPBXVR8NMD	63	23222443000060590	3NKmXxADED2SzUDnMzHGwSgjC1siDFVPu7HKiwKBMzgwC1ZR6LVn	3NLf8Dv22tr7ir4MziPGdfRCYQ8BBDSVJY5vTDZJRdrhxvbrzZkj	7
214	2vamBJXPUg3Bv7gEkZGp8Q1zZH2ZFFJ98gDSFr8Pq1eLwcxjBNqm	63	23222443000060590	3NKmXxADED2SzUDnMzHGwSgjC1siDFVPu7HKiwKBMzgwC1ZR6LVn	3NKYm6zd6DULT1NC5oW1jPLBjvsEfdvCGCwYv6BqyrmMEAgByRkC	8
\.


--
-- Data for Name: internal_commands; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.internal_commands (id, command_type, receiver_id, fee, hash) FROM stdin;
1	coinbase	57	360000000000	5Jv8N1YxknjcfqVb3LFfZPJarp6Q1uXpjArhQJwFrZZdssqKFCMT
2	coinbase	132	360000000000	5JuAucVRsR4sbVGrHLSHQdWDNTiW244PvZryWuTgByv4ZSwvXuAD
3	fee_transfer	132	5000000000	5Jtk3vUosN6uBLEqp46WuZtiPc3kzh4gB7Ew4xQm6iNACnsiJVpN
4	fee_transfer	57	250000000	5JtYjtZfrVbNP9JRy4vc1h6Hkn7JAhULQmWLeHr9VAtmzAPTaK8T
5	fee_transfer	132	250000000	5JuWtsgAeDCnFfsZv4nF1tHv1gPXjscpgPh63Dqcvgc3KHypU1d2
6	fee_transfer	57	5000000000	5Ju9przZwChKT1mWff6KmMD1Ad7K7qCp43vXcPtMiRKHaQaji1iM
7	fee_transfer_via_coinbase	236	1000000	5Jv1JLti34YRAenMXRkSbQ15JAa1mL9Cmr81yQ6Ym5nTU7M1j3MB
8	coinbase	57	360000000000	5JtkbJiSF8xuCs9EpQFAPjntLn3oWEtyrMpzBWQWAsckzoWzjjHH
9	fee_transfer	57	4998000000	5Jv9oex791GnyzxNfkjFgHmZvbDfN2KePBNi7bd646E5BF1dHR3X
10	fee_transfer	236	2000000	5JtdJKy1NhpiqgbJvUhD65AaMCzbiLeMxoDTKx1kPwQMb9fuYWt9
11	fee_transfer	132	5250000000	5JuNryVoajVehWX5xsvQKdVdbDuafJCMfP3rn7GtHmrxJ74eWtBg
12	fee_transfer	57	5247000000	5JttACeAvzCHn5Q3UVM2qScwgxDxknyW5jjWwLdh3BGesEiAvn5P
13	fee_transfer	236	3000000	5Jtr3MJ1Hh4n1GceoGe7JKuFvCJvKAGWf9cDBLEVAYmi4aQt2uUB
14	coinbase	132	360000000000	5JtkgR4zWLXGePgtuxRgHvuk74FW1gUMPFdgja7a9MGsXxigAhN5
15	fee_transfer	132	15245000000	5JtydqhAeaRNYzU3sB2KU4MMLBQ4xU1p65c6xzNPUhpiQwDbccoA
16	fee_transfer	236	5000000	5Ju8WgPLuG1b1E9cmqCkPHi4cb85z329JjUM3BQbTSike4LbLrAL
17	fee_transfer	132	4996000000	5Jv4Qm2ig7y3UfXD81axzfvagz4gK8EqJHhZwzrsJtqnmc4kzZRe
18	fee_transfer	236	4000000	5JtwqvUgSUma5U7hVsj7MLobXG8WPDoYCPBRBsc8vqFQA92uiWSq
19	fee_transfer	132	10244000000	5Ju1k7xudeHgYEMvVy5CLxMMSDoJepWuC2tms9kgr3FW5AF7HACL
20	fee_transfer	236	6000000	5JuKuaShJrMHCCGaXvxnBJnBijtnM86JTdncxAYK4LXTuNmfbt9w
21	fee_transfer	132	4994000000	5JtZrpYdEN46WLBWwzCEqPcnzhr78FNqNrSe4V3yP9GWhyoy1JZo
22	fee_transfer	57	4994000000	5JuexCyjDGJPMx9cpwvW9RiB9vPEKfPn9baEzdR1uUNKhgBqtmpF
23	fee_transfer	57	10250000000	5JtuD1Wp1zD6FYE6L897ZLAeCY2cisr3FADpHsjhHjNvscGK4TYS
24	fee_transfer	132	10250000000	5JuX7uSr6fXCaR7VF7tjvF3qs2pm5BHsbu3c8Let1FCDM9uJcL8U
25	fee_transfer	57	15244000000	5JvKVdBtwspc3zqBSPsDHDMBa6dLMbSJ4fYYJgU3KwSs3jDoyK57
26	fee_transfer	57	5243000000	5JtWPLzhsN2e69w6fQWPf8Cdq1vxK8amYn8ohJ5u4HQ8Rsutps3R
27	fee_transfer	236	7000000	5Ju4m5ZNymm8M8NojyQZu8i9D2u9MVqjrc8MSrZxUviUMAKTxFM5
28	fee_transfer	132	5243000000	5JuCU9hfRHRyJWD9LnG16cv8UJsSqgqYHmGxZ63hgdGkvhw7ugJt
29	fee_transfer	132	10243000000	5JvFNb4jG9ysif3AU7AQRy89EUJcbT6Lmy71iBQe9gY3KitJbNEg
30	fee_transfer	57	5250000000	5JuGYTwvJ8einG85Tk567WvsVtGPZfgbqU6tkYGtJCs6KfJ69KWF
31	fee_transfer	57	4993000000	5Juqwr6o3pwzaU33MuY9uwELXc5oPTFVQjH5m69PT4VVwmoYf8Eq
32	fee_transfer	57	10243000000	5JtcSq2zuhvbnL7yf5VjCBzBm5vx6wKXazTphKcoZJVKPA6dFL4g
33	fee_transfer	132	10000000000	5JtZNLk5xTEPF4G8TgsGgGEjuQzBAGq2oEYjNpvW4rv2zMzgHtqL
34	fee_transfer	132	246000000	5JuaHc9F7PSMCn4GwYAV3poroqeU5WN4CAzq8nfc5BC5DyiYKrCs
35	fee_transfer	57	10000000000	5Jv598UmHegX8ENaviejjVJDRY7NimJdSqgztnhTNpn71UrfnWTs
36	fee_transfer	57	246000000	5Jv3C8F6praoLmP1PtQ5cNYtDUyb2sEQYkZCfUuZN3Eoy84wNDP6
37	fee_transfer	57	245000000	5JuggsRTCLPnEGCBWSqwktkhWidv249J9FrbHptWahyrxgMVG2wB
38	fee_transfer	132	245000000	5Jub6f6uU52JvBMcYHBpoHdkLKWMdeDTf6yEy6s8FoJcUW3bMJMJ
39	fee_transfer	57	5249000000	5JtjUsPpV6ug86HsG8aVyBJ5yqh6qnrmwSLDTRFjyKj2S2S6Vmzg
40	fee_transfer	236	1000000	5Jv1JLti34YRAenMXRkSbQ15JAa1mL9Cmr81yQ6Ym5nTU7M1j3MB
41	fee_transfer	132	5249000000	5JuE9fSZviAehMbpz53vjedt7oZF57KiZYE2A3PKMcHmmobFxEiY
42	fee_transfer	57	9993000000	5JuxE1kpVYRLQYDxDSxAnnasyotZCTUEyKqb3ya4rQiDK3wSL6xN
43	fee_transfer	132	9993000000	5JvCPnWtQU1T4wneAhv5WUJSpCTfYAvtFUswcx2PiLdNtgmrCNPy
44	fee_transfer	57	10244000000	5JuUifhQmRMBZpqTVZjeMQbvChRHXi71h18rLuepfTLGNK3mi45z
45	fee_transfer	57	4999000000	5Ju7B1NviNnS15sKE4nwQtJANUz4WiX5cMHctbsgKaPmWLhcMxYZ
46	fee_transfer	132	4999000000	5JupvucY1VVwspcuZSsf8SACDCjswdjsuBZEruPrei9pub7Tn3rD
47	fee_transfer	132	4993000000	5JtcdVNNujeDzZMKYk9TEm1wYDNMMoJ6Vm8m1KSY1YDBZAYxm3P5
48	fee_transfer	132	243000000	5JtkjdaYVKFH8FmHB3NfjviUwmggfBsqGdYhrqWWhyVTj1EMyMGx
49	coinbase	76	360000000000	5Jti64MduTdFtPsLQbSMV2q1YhjahuWkVsz2mPTP2Adt6BSxjBvj
50	fee_transfer	132	20493000000	5Ju16yHhhaXxiWP9tPzGeymo3HSm9BYLXruYJLsyXBHwkjiGZg9b
51	fee_transfer	132	10493000000	5JurVdUBh9heM4rUr6QJNrEEVzZyBgjkq3B5EYn2dPhTto33qnr2
52	fee_transfer	57	10493000000	5JuL6BK873oKydXS8o7VJREETUWvpNQQJJRcydiMRA3FSiqRxtoT
53	fee_transfer	57	4995000000	5Jv5XeXNkFtsdsrRvKboQ5bBnHxy4EbRrdNvDuDnHctUXzTBYUa5
54	fee_transfer	57	249000000	5JtkSmPjVSMGJ3UDZaUURf7RyurMTa6WUoecQEyTEpYJnjxd5NBH
55	fee_transfer	57	15243000000	5Juz5R8BRBY7xfWq8Gos6om4ZZ6pNsYDS4JxfYVV3Lut7t1QjFCb
56	fee_transfer	132	15243000000	5JvFrc2UQKnDqxCbTq84QVxBwnftotzbmyAP7ei2mUn1Fk9FSrYU
57	fee_transfer	132	10494000000	5JvCfEw7qUfWBYA4dKk6hRsVZyB2AaTYatc44yccq65nc3jGyYL9
58	fee_transfer	57	10494000000	5JtykV3zRdJtPBX997DVPyqNrda3QqEJ6BJRDkbWbgspQn35iPfu
59	fee_transfer	57	5244000000	5Jv4JyMZANd7Ss6LjdLX98RaWWunxshv1ak4rA6YTNvwHaGrkUBu
60	fee_transfer	132	15248000000	5JvK3hs1yTELYpVpQruYKtaqbcSE6wo8iNgVCyEZjPeP9N3ZHzkx
61	fee_transfer	132	248000000	5JtdktSM1fQ6SCVbLxGABF3Sd39LvQCkVywUXBxEjzLGdDc8ZU9Y
62	fee_transfer	57	4996000000	5JuhGAL3WfCHSYKHHBczrEg5pM3bAruCqftHGqS5hh1aoQsz2FuL
63	fee_transfer	76	250000000	5JuqLQuABCQRgTG1U2WaiSM5QxvufFdh4GEKuerny1maXRPdsAcR
64	fee_transfer	132	10245000000	5JuMfAhperMqRVnKHFFN1HFgCDv37oivTW6rgfgjeEoDR1w5vwyB
\.


--
-- Data for Name: protocol_versions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.protocol_versions (id, transaction, network, patch) FROM stdin;
1	4	0	0
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
57	B62qiuKGbehtxZ2U1b37aubMBzmYEHZuVfB19pLpVHPgqSieLT3qobf
58	B62qpP2xUscwDA5TaQee71MGvU7dYXiTHffdL4ndRGktHBcj6fwqDcE
59	B62qn9R5QocBSRu88fnt8Vim7QT8ZyKpwuvnzBHDJMSVqfUjUgh2taG
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
75	B62qpTp8RZFF5yTXTGWEXbfT7i4ufYSkUF6dYcJ6YHcMGa2TJ52nWP4
76	B62qnXZhPbjmUmHEkzzqY3RqzMuXSMgubpe9Sz11dN83gH4ookuMS6a
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
131	B62qnzhgbY3HD19eKMeQTFPZijFTvJN82pHeGYQ2xM9HxZRPv6xhtqe
132	B62qkFBCqtoob3PYU3LhnG4SZGRVJYUocfzqE1WLtE7JMxjfRS7E6i6
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
147	B62qrEfc2YrczcB2rH4Qdfybvy8UDgXrfwHGr5ckaiiL9Her8X92UPn
148	B62qneAWh9zy9ufLxKJfgrccdGfbgeoswyjPJp2WLhBpWKM7wMJtLZM
149	B62qoqu7NDPVJAdZPJWjia4gW3MHk9Cy3JtpACiVbvBLPYw7pWyn2vL
150	B62qmwfTv4co8uACHkz9hJuUND9ubZfpP2FsAwvru9hSg5Hb8rtLbFS
151	B62qkhxmcB6vwRxLxKZV2R4ifFLfTSCdtxJ8nt94pKVbwWd9MshJadp
152	B62qjYRWXeQ52Y9ADFTp55p829ZE7DE4zn9Nd8puJc2QVyuiooBDTJ3
153	B62qo3b6pfzKVWNFgetepK6rXRekLgAYdfEAMHT6WwaSn2Ux8frnbmP
154	B62qncxbMSrL1mKqCSc6huUwDffg5qNDDD8FHtUob9d3CE9ZC2EFPhw
155	B62qpzLLC49Cb6rcpFyCroFiAtGtBCXny9xRbuMKi64vsU5QLoWDoaL
156	B62qj7bnmz2VYRtJMna4bKfUYX8DyQeqxKEmHaKSzE9L6v7fjfrMbjF
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
170	B62qoZXUxxowQuERSJWb6EkoyciRthxycW5csa4cQkZUfm151sn8BSa
171	B62qr7QqCysRpMbJGKpAw1JsrZyQfSyT4iYoP4MsTYungBDJgwx8vXg
172	B62qo3JqbYXcuW75ZHMSMnJX7qbU8QF3N9k9DhQGbw8RKNP6tNQsePE
173	B62qjCC8yevoQ4ucM7fw4pDUSvg3PDGAhvWxhdM3qrKsnXW5prfjo1o
174	B62qnAcTRHehWDEuKmERBqSakPM1dg8L3JPSZd5yKfg4UNaHdRhiwdd
175	B62qruGMQFShgABruLG24bvCPhF2yHw83eboSqhMFYA3HAZH9aR3am3
176	B62qiuFiD6eX5mf4w52b1GpFMpk1LHtL3GWdQ4hxGLcxHh36RRmjpei
177	B62qokvW3jFhj1yz915TzoHubhFuR6o8QFQReVaTFcj8zpPF52EU9Ux
178	B62qr6AEDV6T66apiAX1GxUkCjYRnjWphyiDro9t9waw93xr2MW6Wif
179	B62qjYBQ6kJ9PJTTPnytp4rnaonUQaE8YuKeimJXHQUfirJ8UX8Qz4L
180	B62qqB7CLD6r9M532oCDKxxfcevtffzkZarWxdzC3Dqf6LitoYhzBj9
181	B62qr87pihBCoZNsJPuzdpuixve37kkgnFJGq1sqzMcGsB95Ga5XUA6
182	B62qoRyE8Yqm4GNkjnYrbtGWJLYLNoqwWzSRRBw8MbmRUS1GDiPitV7
183	B62qm4NwW8rFhUh4XquVC23fn3t8MqumhfjGbovLwfeLdxXQ3KhA9Ai
184	B62qmAgWQ9WXHTPh4timV5KFuHWe1GLb4WRDRh31NULbyz9ub1oYf8u
185	B62qroqFW16P7JhyaZCFsUNaCYg5Ptutp9ECPrFFf1VXhb9SdHE8MHJ
186	B62qriG5CJaBLFwd5TESfXB4rgSDfPSFyYNmpjWw3hqw1LDxPvpfaV6
187	B62qjYVKAZ7qtXDoFyCXWVpf8xcEDpujXS5Jvg4sjQBEP8XoRNufD3S
188	B62qjBzcUxPayV8dJiWhtCYdBZYnrQeWjz28KiMYGYodYjgwgi961ir
189	B62qkG2Jg1Rs78D2t1DtQPjuyydvVSkfQMDxBb1hPi29HyzHt2ztc8B
190	B62qpNWv5cQySYSgCJubZUi6f4N8AHMkDdHSXaRLVwy7aG2orM3RWLp
191	B62qism2zDgKmJaAy5oHRpdUyk4EUi9K6iFfxc5K5xtARHRuUgHugUQ
192	B62qqaG9PpXK5CNPsPSZUdAUhkTzSoZKCtceGQ1efjMdHtRmuq7796d
193	B62qpk8ww1Vut3M3r2PYGrcwhw6gshqvK5PwmC4goSY4RQ1SbWDcb16
194	B62qo3X73MPaBWtksxR1vqUtcTbjrjURmiP7XCD975gQupi19NDdQgS
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
224	B62qrNv9sg32p4tAictPCaQrhy88CU9Bb9bwR1tN7iUYDFenNv5NwaJ
225	B62qo7dRx2VHmDKXZ8XffNNeUK1j4znWxFUvg48hrxrNChqwUrDBgiA
226	B62qke1AAPWuurJQ5p1zQ34uRbtogxsfHEdzfqufAHrqKKHba7ZYC2G
227	B62qnd3TWhbQUxK5YXUYuAwDRKgjDiEdKNrEUv43CuZ4jRBCKRf27b4
228	B62qjy64ysP1cHmvHqyrZ899gdUy48PvBCnAYRykM5EMpjHccdVZ4Fy
229	B62qjDFzBEMSsJX6i6ta6baPjCAoJmHY4a4xXUmgCJQv4sAXhQAAbpt
230	B62qrV4S63yeVPjcEUmCkAx1bKA5aSfzCLTgh3b8D5uPr7UrJoVxA6S
231	B62qnqEX8jNJxJNyCvnbhUPu87xo3ki4FXdRyUUjQuLCnyvZE2qxyTy
232	B62qpivmqu3HDNenKMHPNhie31sFD68nZkMteLW58R21gcorUfenmBB
233	B62qjoiPU3JM2UtM1BCWjJZ5mdDBr8SadyEMRtaREsr7iCGPabKbFXf
234	B62qoRBTLL6SgP2JkuA8VKnNVybUygRm3VaD9uUsmswb2HULLdGFue6
235	B62qpLj8UrCZtRWWGstWPsE6vYZc9gA8FBavUT7RToRxpxHYuT3xiKf
236	B62qjbLXPGXR4YPYeo9YH99DK8qsvgpa3GXLV4JXUHX5tHXjViJp7rK
237	B62qkZeQptw1qMSwe53pQN5HXj258zQN5bATF6bUz8gFLZ8Tj3vHdfa
238	B62qjzfgc1Z5tcbbuprWNtPmcA1aVEEf75EnDtss3VM3JrTyvWN5w8R
239	B62qkjyPMQDyVcBt4is9wamDeQBgvBTHbx6bYSFyGk6NndJJ3c1Te4Q
240	B62qjrZB4CzmYULfHB4NAXqjQoEnAESXmeyBAjxEfjCksXE1F7uLGtH
241	B62qkixmJk8DEY8wa7EQbVbZ4b36dCwGoW94rwPkzZnBkB8GjVaRMP5
242	B62qjkjpZtKLrVFyUE4i4hAhYEqaTQYYuJDoQrhisdFbpm61TEm1tE5
243	B62qrqndewerFzXSvc2JzDbFYNvoFTrbLsya4hTsy5bLTXmb9owUzcd
244	B62qrGPBCRyP4xiGWn8FNVveFbYuHWxKL677VZWteikeJJjWzHGzczB
245	B62qpVBVcMuwCboMzmGMUzHEPMhB7XvoCd53p2XjpxduFvphvCVAHoB
\.


--
-- Data for Name: snarked_ledger_hashes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.snarked_ledger_hashes (id, value) FROM stdin;
1	jxR6T25M71V5r13xNVLuKGbJ7DVbJx9Vti1SH2KrczwnUDpovH4
2	jxT5cYEzC6mLfFjXdgdpQAek5tgDzABvNDKoaReXdkLBoFiUiWJ
3	jxv8nMAiaHr3giPXGK3bTRT9wjDd5DzKdRLJMtgEMh8kHfCjzYH
4	jwwfgi66SvWhkuvSaKhkBdYKrN32VKScszB5dYyMbw95SeM1X1h
5	jx3F38FW1ZM3F6UrcSHxiqPLLZt6umZGpYBoyyqCCFtuUKK3aAx
6	jwJWMpiQfAs32H5om2XNV39wWVTuN9ZxqffXMEqTzM25fnsssLm
7	jxZToM9a3QDRnjhznNMAM2jZYWKSvNTQQLTBobZajsudxVCrNFE
8	jw8xpfkpe2fsKvJ1iJ41BHiZYftQ2ZyJkwSFutiDF2Z2Xuu1g3U
9	jwPHdciry3jRYFpewjja11xkt4xTQ4CHjUbqKzuhpqDih55CvT8
10	jxS5xaGuWEoLbB5QsRpxAkLSiFKJq9o8YgU4MYbqNyyPahVhScr
11	jxdKR8KGoTasei6UGTJ5bkdi1wR9qer7s9MYnMzsyvqxXBfjnHs
12	jxPkNwndfva5UNi6gwEVrtdSjaAcH9oYrjmjV4V2399nmsTzp3F
13	jxbBvSengyDPdE5wSVyhHhSxYRsqNQuonC3J9DgEVGrZWYbjos1
14	jxLMAv2XmcZLEmVCqkPN5v1Pw2dXkCtGa1qFoS6yPXN5PxUsimB
15	jxnvErwafBmjwqjnUTnNDfVP2JC1oCnzJqkJowUpcF6zdsxGMLN
16	jxMzW8rXAumLMiy2jMsh2axEmJFkfp5GqHfuZfiVCbeNS9jsjNe
17	jwA2dJgZ3XNbJcaNZ4TZXGrykUAaG4bTeskF54N4j79vMnTLJn5
18	jxsMJ3P8qeDuhiYgYjFQ2KPn7uTsndxPceBjHQM6ZZnveQV6YEN
19	jwb1vFxcwjMn8j3K7FDRnVjb5Un6ZkoM8zkcatXJi4bJWA4VW24
20	jwPuiZANgypahUjNRDuMx4ZzPCTSSXhPzzJwqCLL6F8A72nxWJs
21	jwrqx9sAPDY3tQ5DqZJhSqdtbUagbGBpvDZ1GxSSfEatRiMvaNL
22	jw95iUEXihcujprFCjZZSqjHcMq55dLoni1sS8CGRYmsPZ6urTV
23	jwM1VZJsRYcmVFTRAiW8nDWMpZkHSui8LWVFUt4EDcpFErEECcc
24	jxmiELwGNHHKDbcvBKuYg7F5h4RvoYYwV3rqWaqpckRosWf8LKw
25	jwaEQaDPTeMXaDHR7MNWwNsfhmWynNKSZMTACSn2DuY12JTXY3E
26	jxZNEEW2zKpQBxQRzR1UTj8dqGCgTZF8oes2pDrZrtUz9wZc67G
27	jx7TBYcHByaPkkMuc1855FHTSi9JkgSX5jVETgc77nFy4Lbg2re
28	jxn8gbPM86pbuVANnKgrZ6nDo4t2rA6atSEf7j3ZNJmZKUGQrNM
29	jxjMoygWjKiSM88TrcQbpEnfdE8ZPhzv2Shm4do6arMfRPTpSQA
30	jwpf9N7PJczd5GyaogJBAzh4TraVsvsm6aVXtFRFhGRqritMWUw
31	jwZ2f9ZM3u21hwY7E28RmDxS1uB42r5VG32JADsGZndbuiXKNa2
32	jxJG3TLve9NCWAUV9k7C6xnNyvv113RDMnqPN3Yz8rKPjGvKCp7
33	jwDPkEMMb5xwYZh4NPbDXm7rWmjQ7Y5MGfGuj33dh6WR1v36mAF
34	jwAYKfUEmQ85Jx4pVUdLKgFjYJZMoRrAz6p27pXjEMr8CzM8Hxw
35	jwYDiVDjTKm19kyA77XYeqSrDzAuDtVnvc1tBxY1UBdnPK5gpW6
36	jx8RDufEQY9Vm1Bzm18uxrT84sEwcyJkPCF35VtNk2rqaXQB5XY
37	jxW8PLsb4YhGWtHTzkwGgiGuK18JCktAbXbPn9FXc8GtfffLiG9
38	jx4gRPNHh3AUPKGhFu47ZBvLpAauxP6GxJ7C7LR9hWdaoFvw5Y9
39	jy2Kp9SqboG2uqwjBa6Fc3dvZ52CSr5z8Gtgeb9D7Tx28FhoqQC
40	jxqoCwASNsXWv5Qgi3uaeBgYJR9V8bdjHY5KwfC2HKTR4xuMBcT
41	jwomumS1Fc6pkBxt2wyN9RK2JYTriyN6qJ4bt9dmT6H2XroT1HM
42	jwT8LZn5TtjmzRfHFdFfHADPFkHcsuCrM8skE2zhgfGJVMg31w9
43	jwMiTysmt4PdjQQFKqy6r7Ab4QCqxZyHrpgGjj9UswgQheUSTM7
44	jxDdpc8E2jhWr7g4p2uUf4iuaSVBwo5Q5jK52CMrJGPJ5VRPDCH
45	jx1EdaJFhr7JmAmBA4MGNoyhHQzi15PHymGWaMsCajPMx4dLoJ6
46	jwTRzsaSWYBPvqqm9sCZSfBzEiHYPBu1BEM7p2xRCoX63AEKe1V
47	jx3fgTFEpunnX2HEjX8rJBP3iqRw6fpEugwMH1qYCuwjy8dZtwK
48	jwWTqLaV3F5hYf7TMeVmaNMRAQ2tT7c3BB1iwQbtPpHk9vRaLU4
49	jwUGyCwbAkPWEMBMEGBnw65co2aXGh78QYVoR9NkaPzmtYbJvjd
50	jxQt8ZvU9DQcweTodiLFA1VBCUA5rPziM42WR5Ehm8x8A2E949i
51	jxF1rvQnz2MS4KXpbr6ft8BtDRwSXk9VRLTj1DJNsqAacwp32zY
52	jxTg7Su6GPiPkqTFGsqbBaoD29dFJ5yYFGt1FWVo3FHUwZkvZtK
53	jx9Zon4g24gPyqesLh2JNR2cwA4DgN7N6HEL4iZQpo54QsQHDbJ
54	jx3ZV9GZ3aHi2XHmgjCvGsHTepCUKqPEmY2v4DdKCuL3H19RYvF
55	jwu9FmmbyE5vZik6CT3y7iooXAuxEr6c7xkfWskGyyD2hrxvAZR
56	jxf4s7JVNnNufvDpvKPCicnRFETTVUbn7UXoVMZBiPetPnRjzVo
57	jw8iSXdfGYCBhLYGrZfnpkXvS8hkVtQub2WphDfBdvtJSSmV1LF
58	jwqyC6PNuZVaX9U3SfH2DavdgajDfB8GoQxseqUCme62dvtZHRH
59	jxLLt39fGxbXDAmwf5f956hXCDcQ37AZ7Y1sHX6g9DWzj2NJYco
60	jx2bhoThNp9eM8MqwyUwEDY1juYyxDqWnKANSN8gmr6y2qiRCa5
61	jx1ECwvpbngCoA4ZqgMh3skEEMG6anh2zcWwFyRB7MQrwoeCdBC
62	jwKL6svTqQaMq6vGgKbUn4NiAbpvrEpmqnnNfKJfLR4x6fCtQeg
63	jwiSePhGH57E8wcTEQ7vuG8xEudnAB79APSNqeN44sYxaZHunXZ
64	jxwXMMSyx9QeAFpjeWw9y67Bnp542ES3EuBcvoAkb7XL21zcfjB
65	jwvvqzwNS64H5cST2q1CwnqbMWSVhkeCNpG2g7wgRuP89FKvGGX
66	jwyJsypgCBjgj1A85sNWNrUU4ADHZgTyQGtPLN6TLnuDbaCrHyE
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
243	243	0	0	0	0	0
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
1	payment	76	76	76	0	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuXgJBAtMxe8aLuBHoTyeqs4rmtfbNYjpr6ZJxZazh8PkWKqFtr
2	payment	76	76	76	1	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtzE19ShR2c9pRkiJCa1MP8govn1UxEx1Swa3oHYnb6mPgpKKVc
3	payment	76	76	76	2	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtaKj6942U4CGQJJx5k8UYnyE7qmN45aM5xye91oQ1pZbLTWc3k
4	payment	76	76	76	3	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtcWs6KWMZBcd3p11hX11fgZCoSrjW1K16NiXhrDV3h3ZysxCry
5	payment	76	76	76	4	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtu5vuLF6sk2PL8E6sdEBSyNVQa9XrcQ6bRLvpCxVozSa3sr3jc
6	payment	76	76	76	5	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JueH3CDwTHm717rAF7fhBtQFe2D33awZXJNqYFbUAiemL5Hyf5h
7	payment	76	76	76	6	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtbaDNGx4adXKYEn3oPLjsY3aCfPPKcCJwBraaSp4vN6hSP3fuD
8	payment	76	76	76	7	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju5VJ3iKyP4QmL9pARSTd9QueA6Hso5XWnwwNK6xCPb8PLEb95b
9	payment	76	76	76	8	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvQHvBc22yx9aCMEuupjiqZ2M3uLf1kGSSkoLRXwnTDBEpEh9mZ
10	payment	76	76	76	9	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JunWpjJ57mhpEVxgqM63sfc9VJj8VXnwwjpGDsokCzoi4QLUZsw
11	payment	76	76	76	10	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvHoVnHdyikWnSyd9Q86o5CkUd9J61w4sHm1QcR3opphC1X59et
12	payment	76	76	76	11	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuXrkGs6hmztKkdqXmhvhECE6hLc44YdAu8ZgPgRgfyB9Ujhzgq
13	payment	76	76	76	12	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju68UX5pAPJQEZ5paCwZyxUcVrWcEb6BFs8iJa2PWJzR7PWP5Xp
14	payment	76	76	76	13	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuMc1Lg4LbrzAJiDbamdYG2ic4iuY15bBz2bRibLT13sU7XvosD
15	payment	76	76	76	14	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvQ3yJBzTgWuV5kdMkSWR3YmcuNikRQ28MM8KAr2BDf7gq5NCBS
16	payment	76	76	76	15	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvHMHBjB6NeKa1xNWDzS7yBGg3hFMH1DwtDRSL7HEpp6evd1Hd4
17	payment	76	76	76	16	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuzZydJyDwQgRT47PVRGUKFchqzEembaUZKFffJnPZGBB9GXYkD
18	payment	76	76	76	17	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtycyoXk7i41mPBUEbU3qGujfHGw2BSEYcmfMUhLUQboyFAcAY5
19	payment	76	76	76	18	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtbcWQzMiPVs4tfKGerR1yHsvCC776MF2ZyChGoE57RN3RUEyHw
20	payment	76	76	76	19	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuJ6cNrrs47oQqMF1nkQacTjbdcfuspMyoHqNJHh9RDiXLoZUbZ
21	payment	76	76	76	20	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jutvs5RevbkAXFazbecAPwYEaWHGPcScdAwd6gUGVdVajXDp9VY
22	payment	76	76	76	21	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju7X86M1yLbmsZgUf29ZBbaHFi5TeQJijVTWg7t6TY365G4Dit3
23	payment	76	76	76	22	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvEwTccmpDhqMaECFohBi3k9m6w2s1R5Tx1o8Le7yqh8Ri8KNg2
24	payment	76	76	76	23	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuqfqdEuLVTQuGkafSLDYyEL2p1Re2ekHPkzY1VJMo5rSSN82K5
25	payment	76	76	76	24	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv4GvmQ96E1gm7KXa5uMmy9HZWH1yf8rqCc2AZ1bfyE3RdUjs7r
26	payment	76	76	76	25	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuqgtH8R1NUnnrY3P3MTR549tjV7VFgbWwnwgqntnJkkVDBfo1x
27	payment	76	76	76	26	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtkBskqG5r1uqB8T25KrhkSjSDvdXo4NXR4UxeKfbDjR4mJGqDD
28	payment	76	76	76	27	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuLLhuC4wiAc6EdKwRUNNP8geKDKvMLx8f2FXiN7gAYtThJopLQ
29	payment	76	76	76	28	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtkfbJn484EHiaTkMYipzuQnAmRG2kPMWuzUmxW9RvdMpAYbrDe
30	payment	76	76	76	29	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtfPDjzKuoZRFFoFY98RN988bWWsWGciFajt7eLXe4Fvf9VHYFp
31	payment	76	76	76	30	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtk34M6nhx5VTzgqLHxgfUXyyhjzdNwXvALhn3nuVmWvC3DHxv5
32	payment	76	76	76	31	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvHAUdwypQeGPYRrTjYYSpLDauYpwyoSF6XKfk5NaWZpEXEv3Bx
33	payment	76	76	76	32	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuQSSrHqYF85wruKrUCfMLtaAstsQf8Xw2z6eV4dPZZGB4VZhit
34	payment	76	76	76	33	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtj6KmQ7UM6cuwnTb98568YwfZs3s9RsT7mAMLQjaGBmf39s4s9
35	payment	76	76	76	34	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv8LFodfNtaRzSZKgBYU7o4MMCM92mwFoPt8wMXJpGWtE9nraeQ
36	payment	76	76	76	35	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuzjfVo5YvnKVuXjdu9J4PxogQXN4NdYxCCiCBkcBE4ck2crPFS
37	payment	76	76	76	36	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuzVTNNCqPBi99JiN8sXwNkrz3xSk3btbrqAPZX3SgLKKbT2oBr
38	payment	76	76	76	37	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuBsjNGNBkBv5iwiL8WDYb1Ac2nsHde3Gd6Xwd35T4MdAsTheah
39	payment	76	76	76	38	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuCUT9oBy2XEmGa56bxrTpTgJmFfv2KEFMa6ke3hY8APaySvdyt
40	payment	76	76	76	39	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuSMDKpiUZMhaTdVdZ4xaGSiHZFyAzorB9QZ9R1NhcFeJ34wf5P
41	payment	76	76	76	40	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvAmBnzYtyu4YmwWyEh6qxC7acFbEzG1PfzuJJpnMZNK1S3A97c
42	payment	76	76	76	41	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtu4d9as5VkCdc6yyCkJGVzGhDZP2Ur8mBWY9u6BGWjFxnR9Vm8
43	payment	76	76	76	42	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JurV3CQGM65GMQe8hB6se7VRDjYjCJhnk3CuHFnBoSBQ6XRzHok
44	payment	76	76	76	43	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtmUHzAuKbCKtYK9otrSmf2zbeUyfD62UKc8efZprrFwqNxXRNC
45	payment	76	76	76	44	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtYySivuHMoeJnhJdRKBTKJNT7jrmgHGD56b9upw8P6vhgQ7tgK
46	payment	76	76	76	45	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv6He2bwTTVNQRSwxUSKGktFZvQ9vUZZZcZ7gKefLBfvZY1dvpc
47	payment	76	76	76	46	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JusimPdkavyg38Wjr2W8TfP4YdJQKt9RL14c6B89yjVrcktJctm
48	payment	76	76	76	47	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju9RFFg6wmCqL52ofUNfg5ajMYgPEMyrCP6pk7pchmm1rDAXEFu
49	payment	76	76	76	48	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtj4FhYkG7u7tNdGnpc7FyHM2i6J5EycnhvG2gtybeh7zdf4HyR
50	payment	76	76	76	49	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvMqvkU1qHsc2fYHd1xgfce3wRAFdB5QfaVvhXzkLQSEP1avFjq
51	payment	76	76	76	50	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvAAPnbGmP49a2dKEZKks9qcAEn1wJnNQqCsWFPhcp5yymuoeZ9
52	payment	76	76	76	51	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuANAPrTbcTWqK8DPKYQTpGQrufoj4q2zUihbGaBqNjTadgtFwT
53	payment	76	76	76	52	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JudpgTJ6QoFMbLMShQsjKcg861ukBAuPRTM639ZmebRbXZiRqrp
54	payment	76	76	76	53	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvLLRtf18uD5jYiwqaU4XFHj4RNNPRwvMsuBiVNDbdKi9DfZTfr
55	payment	76	76	76	54	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuXf6HgMahhrFJPMQJkhJzZAwBptz526ZGMwNpip8vfRUgzmp3b
56	payment	76	76	76	55	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvR1enb5Z4FQAuEhFaVGy8iDc478MPoFy1kiBrXT2A2vYSFakqs
57	payment	76	76	76	56	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JthF8yNCYtVZgqKw4ydaeXPKvTkQ8gcvvWCYZxT8vf3cZN58UF3
58	payment	76	76	76	57	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtdG9hZzHpjHQnKzT43KTpAQDTHsF3L5vJBcRrfUJNYBSgzm9FJ
59	payment	76	76	76	58	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju7d4YoLFvn4XXpVotJP1Q4qs87mtwq9x9mXrH4PTLan6gvrJwF
60	payment	76	76	76	59	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju74asCqtr5S2cvi434mFZ1WuB4dGY6JhfL7WYbgqHyRzZe8R3k
61	payment	76	76	76	60	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju95Yxv8GcRvkRj35PzQ8o3hBBNSaRqLN1pJ8oMzLBFwPa5o5hd
62	payment	76	76	76	61	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju54D9zEfrDPuV5AW88yfJwSLHtN1UbgrKQU6Aj72eWRv7bDBu1
63	payment	76	76	76	62	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtWeJLv5PDHLiYej9YoDpK4taG1825ZAQ47rL1P7a7oZHABQoE8
64	payment	76	76	76	63	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvEofE2Aod7ik9HjacKYxD8te8Tft4rU9iKFmk7PZ157gLA5hiF
65	payment	76	76	76	64	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jup4ZStZMaGjVvhVGpbovAJeBR2MRtV6UQob6r9WUUPESkyZZjK
66	payment	76	76	76	65	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JumyBvKVikDMs9LshGUTioeu91XWeFojjEmBeZxi1NeUvrShfZx
67	payment	76	76	76	66	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvP6doZY8CkpX7qCg7GaXLkBBuiZ5ajaaqkAy57TPXpUYKi98zF
68	payment	76	76	76	67	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuaKAZpis2xHoSyHj6YLhweVgzcrqSJ4e1PZdCbAqyDqPP8ND9r
69	payment	76	76	76	68	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvJngwHpzWHpxr2BVUbkDQWvL5YNGyzikTZjgZt3FjjkwBEscUF
70	payment	76	76	76	69	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JteYjwYAQvhU1xBjNm9NXuUr3deQwtY5HtPG1urwxiaQTykeaGN
71	payment	76	76	76	70	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jud8ezdv2ZtMw3rfonapPdm4MEqXPUC9ok3WgTtmRQTLaSU3UoL
72	payment	76	76	76	71	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuXhUBQs2LDqSPYuEfyo8HoueAPt4paC836xhRe8mb8YP3uUvwf
73	payment	76	76	76	72	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv1evgrsZdGFyyfbNE3utE9BhaWwCgCzFA1vDcqgZmZQQ7KHfsQ
74	payment	76	76	76	73	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuUFPbNWZEEeye7iTnxa64Tf4MPKbi3Hob6pQv7GcMkFuas51o2
75	payment	76	76	76	74	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtuQ3pjjAnL8trKp9yacK4RCxzmf7qkxKEvjnk2d6MNwmLQW1yf
76	payment	76	76	76	75	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvRdqRwZ7sSX1C1eqpfFdQNdSrPyg9SapTAqjTwW5CTCbiKWMNA
77	payment	76	76	76	76	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuccLteBq7U54kRTiQ2uNZY5QycPEXJvnqFxaUfqksdMR2FAZtj
78	payment	76	76	76	77	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JteCncyZvFT96SuoZoTUm6Drs4ohJvqgt5AT9ZRq3h92KVhi97b
79	payment	76	76	76	78	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv6gUrhFZJNEnNq8XA9PE1k2zVX7XwPySRZtJqcgrLQ82DHAmtb
80	payment	76	76	76	79	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtuVgZ7eYGL4erZUgfU7P3TZvhzEYuYVZBBPjRikeGhBVbG1QFu
81	payment	76	76	76	80	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuouycyGAxMQjubggwHMKNfdKEzmnywKsM9PhZaPBgjyGeP9nDJ
82	payment	76	76	76	81	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv92AKK7Xxg7xTnkoH9AE9muLGU9m2YSAAtxQrjgyS8eYEWUqMY
83	payment	76	76	76	82	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JttGwdusmhaYV1FcPz2fjPp74NvFRen7stcqkGhdgq4j2NUwxig
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
\.


--
-- Data for Name: zkapp_account_update_body; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.zkapp_account_update_body (id, account_identifier_id, update_id, balance_change, increment_nonce, events_id, actions_id, call_data_id, call_depth, zkapp_network_precondition_id, zkapp_account_precondition_id, zkapp_valid_while_precondition_id, use_full_commitment, implicit_account_creation_fee, may_use_token, authorization_kind, verification_key_hash_id) FROM stdin;
1	146	1	-1000000000000	t	1	1	1	0	1	1	\N	f	f	No	Signature	\N
2	244	2	999000000000	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
3	146	1	-1000000000	t	1	1	1	0	1	1	\N	f	f	No	Signature	\N
4	244	1	1000000000	f	1	1	1	0	1	2	\N	f	f	No	None_given	\N
5	244	3	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
6	146	1	-1000000000	t	1	1	1	0	1	3	\N	f	f	No	Signature	\N
7	244	4	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
8	146	1	-1000000000	t	1	1	1	0	1	4	\N	f	f	No	Signature	\N
9	244	5	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
10	146	1	-1000000000	t	1	1	1	0	1	5	\N	f	f	No	Signature	\N
11	244	6	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
12	146	1	-1000000000	t	1	1	1	0	1	6	\N	f	f	No	Signature	\N
13	244	7	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
14	146	1	-1000000000	t	1	1	1	0	1	7	\N	f	f	No	Signature	\N
15	244	8	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
16	146	1	-1000000000	t	1	1	1	0	1	8	\N	f	f	No	Signature	\N
17	244	9	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
18	146	1	-1000000000	t	1	1	1	0	1	9	\N	f	f	No	Signature	\N
19	244	10	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
20	146	1	-1000000000	t	1	1	1	0	1	10	\N	f	f	No	Signature	\N
21	244	11	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
22	146	1	-1000000000	t	1	1	1	0	1	11	\N	f	f	No	Signature	\N
23	244	12	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
24	146	1	-1000000000	t	1	1	1	0	1	12	\N	f	f	No	Signature	\N
25	244	13	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
26	146	1	-1000000000	t	1	1	1	0	1	13	\N	f	f	No	Signature	\N
27	244	14	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
28	146	1	-1000000000	t	1	1	1	0	1	14	\N	f	f	No	Signature	\N
29	244	15	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
30	146	1	-1000000000	t	1	1	1	0	1	15	\N	f	f	No	Signature	\N
31	244	16	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
32	146	1	-1000000000	t	1	1	1	0	1	16	\N	f	f	No	Signature	\N
33	244	17	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
34	146	1	-1000000000	t	1	1	1	0	1	17	\N	f	f	No	Signature	\N
35	244	18	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
36	146	1	-1000000000	t	1	1	1	0	1	18	\N	f	f	No	Signature	\N
37	244	19	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
38	146	1	-1000000000	t	1	1	1	0	1	19	\N	f	f	No	Signature	\N
39	244	20	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
40	146	1	-1000000000	t	1	1	1	0	1	20	\N	f	f	No	Signature	\N
41	244	21	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
42	146	1	-1000000000	t	1	1	1	0	1	21	\N	f	f	No	Signature	\N
43	244	22	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
44	146	1	-1000000000	t	1	1	1	0	1	22	\N	f	f	No	Signature	\N
45	244	23	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
46	146	1	-1000000000	t	1	1	1	0	1	23	\N	f	f	No	Signature	\N
47	244	24	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
48	146	1	-1000000000	t	1	1	1	0	1	24	\N	f	f	No	Signature	\N
49	244	25	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
50	146	1	-1000000000	t	1	1	1	0	1	25	\N	f	f	No	Signature	\N
51	244	26	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
52	146	1	-1000000000	t	1	1	1	0	1	26	\N	f	f	No	Signature	\N
53	244	27	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
54	146	1	-1000000000	t	1	1	1	0	1	27	\N	f	f	No	Signature	\N
55	244	28	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
56	146	1	-1000000000	t	1	1	1	0	1	28	\N	f	f	No	Signature	\N
57	244	29	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
58	146	1	-1000000000	t	1	1	1	0	1	29	\N	f	f	No	Signature	\N
59	244	30	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
60	146	1	-1000000000	t	1	1	1	0	1	30	\N	f	f	No	Signature	\N
61	244	31	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
62	146	1	-1000000000	t	1	1	1	0	1	31	\N	f	f	No	Signature	\N
63	244	32	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
64	146	1	-1000000000	t	1	1	1	0	1	32	\N	f	f	No	Signature	\N
65	244	33	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
66	146	1	-1000000000	t	1	1	1	0	1	33	\N	f	f	No	Signature	\N
67	244	34	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
68	146	1	-1000000000	t	1	1	1	0	1	34	\N	f	f	No	Signature	\N
69	244	35	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
70	146	1	-1000000000	t	1	1	1	0	1	35	\N	f	f	No	Signature	\N
71	244	36	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
72	146	1	-1000000000	t	1	1	1	0	1	36	\N	f	f	No	Signature	\N
73	244	37	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
74	146	1	-1000000000	t	1	1	1	0	1	37	\N	f	f	No	Signature	\N
75	244	38	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
76	146	1	-1000000000	t	1	1	1	0	1	38	\N	f	f	No	Signature	\N
77	244	39	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
78	146	1	-1000000000	t	1	1	1	0	1	39	\N	f	f	No	Signature	\N
79	244	40	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
80	146	1	-1000000000	t	1	1	1	0	1	40	\N	f	f	No	Signature	\N
81	244	41	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
82	146	1	-1000000000	t	1	1	1	0	1	41	\N	f	f	No	Signature	\N
83	244	42	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
84	146	1	-1000000000	t	1	1	1	0	1	42	\N	f	f	No	Signature	\N
85	244	43	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
86	146	1	-1000000000	t	1	1	1	0	1	43	\N	f	f	No	Signature	\N
87	244	44	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
88	146	1	-1000000000	t	1	1	1	0	1	44	\N	f	f	No	Signature	\N
89	244	45	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
90	146	1	-1000000000	t	1	1	1	0	1	45	\N	f	f	No	Signature	\N
91	244	46	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
92	146	1	-1000000000	t	1	1	1	0	1	46	\N	f	f	No	Signature	\N
93	244	47	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
94	146	1	-1000000000	t	1	1	1	0	1	47	\N	f	f	No	Signature	\N
95	244	48	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
96	146	1	-1000000000	t	1	1	1	0	1	48	\N	f	f	No	Signature	\N
97	244	49	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
98	146	1	-1000000000	t	1	1	1	0	1	49	\N	f	f	No	Signature	\N
99	244	50	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
100	146	1	-1000000000	t	1	1	1	0	1	50	\N	f	f	No	Signature	\N
101	244	51	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
102	146	1	-1000000000	t	1	1	1	0	1	51	\N	f	f	No	Signature	\N
103	244	52	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
104	146	1	-1000000000	t	1	1	1	0	1	52	\N	f	f	No	Signature	\N
105	244	53	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
106	146	1	-1000000000	t	1	1	1	0	1	53	\N	f	f	No	Signature	\N
107	244	54	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
108	146	1	-1000000000	t	1	1	1	0	1	54	\N	f	f	No	Signature	\N
109	244	55	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
110	146	1	-1000000000	t	1	1	1	0	1	55	\N	f	f	No	Signature	\N
111	244	56	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
112	146	1	-1000000000	t	1	1	1	0	1	56	\N	f	f	No	Signature	\N
113	244	57	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
114	146	1	-1000000000	t	1	1	1	0	1	57	\N	f	f	No	Signature	\N
115	244	58	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
116	146	1	-1000000000	t	1	1	1	0	1	58	\N	f	f	No	Signature	\N
117	244	59	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
118	146	1	-1000000000	t	1	1	1	0	1	59	\N	f	f	No	Signature	\N
119	244	60	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
120	146	1	-1000000000	t	1	1	1	0	1	60	\N	f	f	No	Signature	\N
121	244	61	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
122	146	1	-1000000000	t	1	1	1	0	1	61	\N	f	f	No	Signature	\N
123	244	62	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
124	146	1	-1000000000	t	1	1	1	0	1	62	\N	f	f	No	Signature	\N
125	244	63	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
126	146	1	-1000000000	t	1	1	1	0	1	63	\N	f	f	No	Signature	\N
127	244	64	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
128	146	1	-1000000000	t	1	1	1	0	1	64	\N	f	f	No	Signature	\N
129	244	65	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
130	146	1	-1000000000	t	1	1	1	0	1	65	\N	f	f	No	Signature	\N
131	244	66	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
132	146	1	-1000000000	t	1	1	1	0	1	66	\N	f	f	No	Signature	\N
133	244	67	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
134	146	1	-1000000000	t	1	1	1	0	1	67	\N	f	f	No	Signature	\N
135	244	68	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
136	146	1	-1000000000	t	1	1	1	0	1	68	\N	f	f	No	Signature	\N
137	244	69	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
138	146	1	-1000000000	t	1	1	1	0	1	69	\N	f	f	No	Signature	\N
139	244	70	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
140	146	1	-1000000000	t	1	1	1	0	1	70	\N	f	f	No	Signature	\N
141	244	71	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
142	146	1	-1000000000	t	1	1	1	0	1	71	\N	f	f	No	Signature	\N
143	244	72	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
144	146	1	-1000000000	t	1	1	1	0	1	72	\N	f	f	No	Signature	\N
145	244	73	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
146	146	1	-1000000000	t	1	1	1	0	1	73	\N	f	f	No	Signature	\N
147	244	74	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
148	146	1	-1000000000	t	1	1	1	0	1	74	\N	f	f	No	Signature	\N
149	244	75	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
150	146	1	-1000000000	t	1	1	1	0	1	75	\N	f	f	No	Signature	\N
151	244	76	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
152	146	1	-1000000000	t	1	1	1	0	1	76	\N	f	f	No	Signature	\N
153	244	77	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
154	146	1	-1000000000	t	1	1	1	0	1	77	\N	f	f	No	Signature	\N
155	244	78	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
156	146	1	-1000000000	t	1	1	1	0	1	78	\N	f	f	No	Signature	\N
157	244	79	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
158	146	1	-1000000000	t	1	1	1	0	1	79	\N	f	f	No	Signature	\N
159	244	80	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
160	146	1	-1000000000	t	1	1	1	0	1	80	\N	f	f	No	Signature	\N
161	244	81	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
162	146	1	-1000000000	t	1	1	1	0	1	81	\N	f	f	No	Signature	\N
163	244	82	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
164	146	1	-1000000000	t	1	1	1	0	1	82	\N	f	f	No	Signature	\N
165	244	83	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
166	146	1	-1000000000	t	1	1	1	0	1	83	\N	f	f	No	Signature	\N
167	244	84	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
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
1	1	{1,2}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JugFaRW6yBmUtDumRdBND2NqyffDdFcfu9rnVTTFyGPRCnN9v8A
2	2	{3,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuegitQcrXyF9oshMVUTJjEvkLcaAVUfjKCXVaTLe1aU6Ldc6cC
3	3	{5}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtW7cXnmZBDFKkY87iQ5c6TYkuzUkKwSk6obBot4nenSamMjXYq
4	4	{6,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv83Auw3Pruvtht1exBo7exzSqYhSrNtXNuQDEVRfrM67JNkFuD
5	5	{7}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juk7XzyRpcsVZTj2kAY7WsVQzrx3iVU6jKnJnbJPRaqSPrUNywj
6	6	{8,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuimHWqMnR5wijz86i8zL6mjgXd5tnpjehxMM1oihSkPGTqi3Qv
7	7	{9}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuJoHM1xMUrf4g2X5GUQVp6nk4Vbu2k454CxX4YNKz9KwEaBHSh
8	8	{10,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuXvBprdMybDs3moTMX4Vi9bpFX6KS6nMyrqKhLcHwpjncseqDh
9	9	{11}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtwLMPiAh5kzUsDPstA4JzFzdZmGY3E1GpTJiod3Ud3K5qHKen1
10	10	{12,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuBdZuQRrNd8NckhHAhU94JNMV7gq8jEvjKPjGjhgcPtT3B9GbS
11	11	{13}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuUH7cPBx2pfSePPasJsBGUjhGvazGb9pi4m56PzsGhWpYGqdNq
12	12	{14,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuCKvrKU7wro3coAewjfit7bMmSQSrLh1jLmU4SLRF39BqLWX9Z
13	13	{15}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtpGb5NUD5dC5ZXpoQsCDwwyUNVkNcEXhJRXj8WaUAFhfGqXNys
14	14	{16,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvLGdEnaLi5keM6f6BzQFHy3qhC3SMLAF7dagJ9QSPZMq8faLG6
15	15	{17}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JufTBSZN79Ki7MzghPHkNq7RTA5DgUmGUpatr6yZBazjCxXCq4B
16	16	{18,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juqj3i4jPdWujN58jwZDV1hakMd4F73siSt9u6r1Y9JHgJF76sd
17	17	{19}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv9kJNsrVqQZVULhrCNpwUYu5CftYjLR4VQ7yYWSmjCyv3TjkeD
18	18	{20,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuuLS2rqPRpFs8WATvcNe9pkmhp1bRe4xpnu3g2YNvRg7QhYhVc
19	19	{21}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv2kfAFk5oJ4Bdf848RQ2JtMkhB1aKTGahWV2jDGBEF5nd3ouJr
20	20	{22,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JunmNNarSo8EZ9xiWEoaTbHjFrWSFHHo79RRbEoD789bM4QobYQ
21	21	{23}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvAf2ABjsLZgiPQbhf1d7wfKfh6JdrYva4AUohkKLGJdjLFp1vh
22	22	{24,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju951hoxeTzaWxrk6aGvwuuxfPvCgDrsZ1x8eKpBRbFavYcBRKw
23	23	{25}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv26xtTBU3F4EHMkB4358HLcaxNYwWNK1MbPQJvX5huaDJ8mAon
24	24	{26,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvCUk6bRFLV45dLAwzGYhGYVqm7VfDhSY2EMFqfcK75qZZrxWJP
25	25	{27}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuB6hLmX3HtuxtUcvoW5RbNPWWqxtuBpJiTj1sMjTaeVwJiVumz
26	26	{28,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtVncsw9o1GYYzXTtH2ZKXSwZkt68umhXABWRYwWq8ZDsVCmjpe
27	27	{29}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuLZNHUbHPe1ncZDfyaKSRWXpZamsKL7uGJqYPi6YjQjkDoF6Yr
28	28	{30,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtZHQ4gBpb8WkrJFATGiWnHZDtcK7cLq7GEAB1YNobckgGZqgzr
29	29	{31}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju6DPZ15UkAEq66axKpEFPpFFA8kGibDJTbbNdNAwj9JxWuyS2P
30	30	{32,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtktVh1qjueYfFGEZcqbB8rY9zs2EvqBC5oEMdzzo8X2s4MWj1v
31	31	{33}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JueioeRryWpsvMzzVF1YPmzrB5CeHXBScfMhX1hFisZdAq8US8c
32	32	{34,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju85eKfZZJCp7cxfDsANwBchDJ3UQ2wUFDa2ixrv4n4gDzjfTVj
33	33	{35}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvH1qHNBrMqJ1Ft2S5JU7MtU6kb88p8y3ivxjSRnQALbbXjxN1U
34	34	{36,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuCxQjYmTx8qyTqYjmBa6Y8ZPvH6ZD8aArts9eW5xpB3k125sin
35	35	{37}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuvjuekvopZG8KGuwm9fKGZyz791sfUBjKzMDfv8yc6tyAcub32
36	36	{38,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvDL2ZA5FLiVDFrGHqJ8AXPH7gDCeM3bnTiyWBdNMxnBqx9mkVs
37	37	{39}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtyzcWePVVCkg65mQCQJ4RrvVDvDwELww9LdpUZq2JNZFj3xM8b
38	38	{40,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtkKAgJSjT7q6qMjJ2JiVXHUbH3agbq7zNJhvkpcvbJ2tk634qh
39	39	{41}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuvGvGdbtWkG2MmU8zsnkqSp7xfjMyrfCN1jtTjGWeUG1k3bKGg
40	40	{42,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvA8dswhWzwCQ4ArGKBMWrWeeKU5pWrJ6owLzf8yKqXQZo3DeGt
41	41	{43}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv1pBGnsqsqYQRaYSNkLqbgKxrE9BdJsQTpZdNsmWLCHVsU52NC
42	42	{44,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv9aMh9N2jArYWMRXtZtbTf1MCobLqZf4ZBVaWHTC12UUoLAxcw
43	43	{45}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvJHEKnYsxG1etsgMU3Eqnxak3gLwjteYkQWJY995gs3WskyK1K
44	44	{46,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtp7cN2dQyx37Vohqybja3XXaZXqD1735kDCt4ViUuyTeUHtvZM
45	45	{47}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvMPAgdWzWyPTn6cMnAhgkGjP3peZ7SFjMn9ZWCDycNNYB9KSmN
46	46	{48,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuxdCkxiwRFyZrfdbPYZSpAMtv2bHWwNUjhGdqeJq7ThkMnPcFn
47	47	{49}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuSjQ1pL381UxwaSCKfqFGR3ogSnvXxxSysC5kgYR7iL58KTy8e
48	48	{50,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuQSMdSkPUXRrnZQdbHW1LrT53gqRocjsGwuZGt2HkGXSMpSiJs
49	49	{51}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtehYRWanhHPv7oMpv8F8dXPeEwty58Suf91Zqy1hz6fjjCVhxg
50	50	{52,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JunzFEV1VhsdBj2GtAQYcz5MCTTXYNFr45e2fHmB4YREkTuU2qH
51	51	{53}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtdDNKjooFnzfeGpeEGzA51jRZBtiFe461SDi2NQv68AfwCFUuV
52	52	{54,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuEiZreMLskoGtnPbC7XXxc3GfNpGRD1znf6aWxxcDbUyi7Y7z5
53	53	{55}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JucdqWykNqmMPAs9bcGMRLAc9ees6GS7rZSWKHoLbYCCHPozAPZ
54	54	{56,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju6aNPJAMTUMfLJYHZgmtwfwtxbAvijNRFNegNjCobHV5jHH4RW
55	55	{57}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtbnuMnCHxSEweME2QRyZxLPpnDf3TvcuuPkNRGeY7DUyWNn8Fx
56	56	{58,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtd3Xq2vFqAr3F5XuLEa1DukXtNDnKzYE78jhoN26xZKDiyiqzE
57	57	{59}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuwqAFzPqAgxQTPpmg8CshDbUcXpQNesEwQneYhK8WcoGANBmYF
58	58	{60,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtXJBHtFZqZpSFbNJEKev4yNE4aPcEpiQGAuNbKHtVA7LuDH7b8
59	59	{61}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuYjYMZHpcHNaDz5zcWuQasXnbgPiKs7dsvdievcuP3jfzyn57Q
60	60	{62,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvHN2Hnbj8oP9FCT5QrCr9y7gX2uFT8tXV9imZZuDijxyVkdvXM
61	61	{63}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvLWWKt9JEJrfN2CuqJpdNLKKdboCbSpVV8aQ6f5NKChtNt7Eck
62	62	{64,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jub1y9oXCxCWPAL4ehq2QvjMjkGES9nNXq6Bm3bija2LoHfLr4v
63	63	{65}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtni5RgNo6khiUs49sLWCmPYRHCZFto7YaVrEyB21Zr6xMY8Tas
64	64	{66,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuXdWXUkoSHCHKo3TTqSFMAkkgaerjzGUQh6MEtAttJv8FL33tS
65	65	{67}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtaQHoh7opC45TosgpPBMcBWvMi2u2wXz1v4Tk9LAARtQKf1GKa
66	66	{68,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvH1eSBUW3uEKRs2LaXmM3y56vjsun1XjpysBtq2FK9JiVU9Drw
67	67	{69}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtqpJ1LqzC2QWHf6zMpJgg7immCo91ymrzWYea59JRX6XrUHHhk
68	68	{70,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuCFBchDrmzaFxMeJwtUxgNvPhb6vTkyNW2SNcKmKoCWM2bazsC
69	69	{71}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuM4gAB1rmTEXqdYEtMpJhEpQFvGE6RaphHNBJq1DRnECG5tc1s
70	70	{72,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuLSRKDTRSqoFR1m8k6Eqa55JEgqxsfMWx65dicUBVPRVyirDX3
71	71	{73}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtwQ1BPPd8nHHfR7wM85d3y9XMuVd4uanrwuAqheyoy7UJc3F1P
72	72	{74,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvLduMjCBcSAjs8fmEnFbBias15iRp2ZwtXHPdxLVcfuTkvkkry
73	73	{75}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtzjmdv2pQr4D8jaeCWPMqtcGj1NHprfKd3p58kg3r5MXqiSUSL
74	74	{76,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuxP8goVU257Hy5v6wDZ7qPvkoapw1jrV9sfWkwPMi7rWVKJGbJ
75	75	{77}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtmwjBkc3pN99UFLJeSRWWEicQp9i5TNBu7ZMbH6VgcEQhYw4Tg
76	76	{78,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju2tZhHuLBxTu4MD7zYpMYU7T5CWXu7R6CsnFrdoufFUCAw7m9z
77	77	{79}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtcXr8UAGPm9AhsVBzBfWvNnvcg5nNubozgHonAgHCmeKaLANhN
78	78	{80,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvAdb6v4q9X6oLFY4JmNKxp2h7ENwVoKR9U3FHVg1mPqnnxNXGH
79	79	{81}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JusTt27HwBScgquhQeAA3BedYV3UYtQG8vT4Xkxck1c2JV4UJJZ
80	80	{82,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juf8bKgKpFPMfnsbSM3skiTLAtsbKNziz13Uk44CkHkLjKE5zUk
81	81	{83}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv2YqLJ3vJjWyxBNYnojCs1FS1ZmKr4KzXbnxqA8XqrGiu7JTFN
82	82	{84,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtYe1aK8qBoqXf2wry1dMHXbP1LreVrhw9RZ1Lj23iECu64BM6W
83	83	{85}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuBhJ6JFMg6UAmHJK3Jq97bPbqRhBZs9v5nCfb5jH4N1FrDZSq2
84	84	{86,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuQwvvDyTgSu9mh9RqrRC3H7Xwuj56ntKP7hdM1m5Gs6PYWpyUu
85	85	{87}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JurzLcUusfdDvoGXMjMPjKcz36pbYNdeWeAJPGDE9RtfeAyHLRf
86	86	{88,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtc5GwWNSnHKVE85E9YfhtcJaSHeTtymnpDM3EiRwsVygZPknAR
87	87	{89}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju1VYShKnoYr576j6GDnRa98853gzapUwtouZzeRQxtwLFEfbUs
88	88	{90,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtwBW2ZcRXRCx9ngPBy5BQAy2NnqoqnzCeBVNif5jKmNrSakzxy
89	89	{91}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JthgnTbtUynrRteSnXmR4hLmZtLnZSG3SEk89jetmATA11uR8BA
90	90	{92,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtiaUYngTsGeL1paXwHFQnWngCSQMKcRv6kw8rH91shgpVmtGwC
91	91	{93}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuYqPTBNrheBRYAJWaC4APgEbdBu3LRSVf4gTxjL53CeChZrxvX
92	92	{94,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuShY4HrCQDXfpDE6Cj4Ucb5F1w8itQ7EB6JjsmZP8uzRKPcyNA
93	93	{95}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtc4wwNXjSNSWukeC7vsZ4bBf5AXsAwUoorNbv1aA3Y6cxix6dx
94	94	{96,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvPUdPhvsFTRvvfRwbeAuk2bH9XGRb9ENpZhtTcmof3D7u7VJTh
95	95	{97}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuQPjafA6PK4R8oXFwzse7rarG8uYzTYkbRn7Achxg9zFhDg6rR
96	96	{98,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv9LG1KuTmN2XvqQZDaYFaE1FLovA3mkCsvE1AUfiacaHfmytaF
97	97	{99}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuYZLsZyYcRsbbrkgRHX9mc8atuVnBz75bCBX4K5ZDoNTW7AZKn
98	98	{100,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtaSmm6r5SGbLPS59iFKS1DV38JMgAHRFpAEGmDAZTu5BgRViYY
99	99	{101}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JueYqZQEpazZMV2facuHApgr1Gy5A4Q2X9njUeR7YXBFLPQrGLn
100	100	{102,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuLSFkqDoJ4kTCanP8vjGvkjxFVuq7wNYtnRmiMTYrDPPcJEqju
101	101	{103}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuqHbGAoKVmBNqDKDuna9QLrhbaVmvwZJjSDjcB73ArUXNF3UiW
102	102	{104,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtjbBaPkJkkfRNNX6hXsXf18GxPhwUnaZqEbDdbPtfrZx8bxTdJ
103	103	{105}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtVSCQA8BKEucisDmT7Q8ywhzs5BebxFRyfK4Y1SQudnV4uxetp
104	104	{106,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuC72zqo3TaSPhmK366MKkiBe6jRw5kNzUUBrRkta8hnLenGpyd
105	105	{107}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju32zcLZZw4q7X3U7vQZq5azjTJApNjrtnjJWhhhUreAxn95XhL
106	106	{108,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtjd2RRW62phTtVtjcCYTFSqeNXKSNaL73nRnJTEE1Y5P4A2cjE
107	107	{109}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuXzs94kNSQsZpvszBtmsQr1kxCa8TRQXKS7AJyAAAwvNstqU5r
108	108	{110,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuZfAVo1J4FLp3SjEKSZwezgfEGgZzSDhqv6EC2bzimJiPKbmfh
109	109	{111}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuoKF5BMPSb7WRzZEBUUbt8ZUScj4VvAejH7zTkpmazs5FLVKTZ
110	110	{112,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JusjHDq6nxEDr8qR2cuLYUUP8fP2vb7Aq6Fn9cHqhLYu7VCD5XG
111	111	{113}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju2we9bxANPky1JgVPHqTiDDLhgCpnnaBnWunGuyHWKLFfCQZrt
112	112	{114,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jug2Y3edHK7dRdNr1FQrLKWGWbQB4npD5RQrUzZ6xA2xK1R2QvW
113	113	{115}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuyBLQb54w4uWCJ3yYUjKRwnY41oK9oLN99Ho1FyvTGYN4C6bvc
114	114	{116,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv4Sm6g2nicyqjArrPJNQ1Cz2WQ7eXmiUj1xm54yp4eLJZxvues
115	115	{117}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvAjkfJK5N89CygsyPTnkGDSDiWVMzDuRFRLkpNLQQjsofyiRVR
116	116	{118,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju8unsH6DHRgpXZygzx3FSaR1D6Pr75529HP7BJ7dsGUYfykJyw
117	117	{119}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuAiC4pnMhsSSMYb8qriX6AYvuuhSQvV55Y3A7HGvL5c6pLTSL1
118	118	{120,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jup7bFM1h1AGpjgw7H4iVqdhg41czj4WunyvGpS9BykbYgzWUUX
119	119	{121}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv6JXMZWLv2h8EmNEoMfxMfpJqnsqRAbeVgeR5kHQMrCeZmtjjH
120	120	{122,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju3LMehFdN8Qsv93farSk5JURguwRGSB3C9n4P7S93Z89FD7kqq
121	121	{123}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtVfN4mVKpWb1ApeP6oavveu8CFaEZpRUAcxvcEB2x4XfP1vu58
122	122	{124,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuicHcWrJWShaoKFu8yATfN7WnKo7okvnT6pNeDm3Fx8B2d1USQ
123	123	{125}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JurSf7jF8QEjbHJz6K1CUsSuRCiJSBS61ndr8Na3HjYiGoK4dB5
124	124	{126,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju3Py2Ean7BcoLvXuZ9LaoRpQPabRQhrkEMdjNTg3f92QmX1u2V
125	125	{127}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuLNKRYn1gxouNwD9MGpnRKB84ffJGuw4EUKJBfDrVAhWfJyYQr
126	126	{128,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juw8VyjUrxXuCubQmuX1rCHAjAmtVZwYERWWErZXR7fjtQFtxsy
127	127	{129}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvN73f1T4AMkcVbXwEeeM7x68ZJ35vrGaFaPemwNckPUQRCFt57
128	128	{130,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtqt3aGWEPeQ1bRBsiQP3roFU9Zmd7DBZgzqbmZ1SkcvjnhD3mN
129	129	{131}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv36QUYdAii3hYBWJQpTNN6WUSxQw3ynJDLNZENWecZQgRFe3Jo
130	130	{132,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtzF4uVvckspTce2yNEeQvzUpHJgpAGFxhj2SB8ityULCSXaTuQ
131	131	{133}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuUaVQFM4f7M8Bb6a2aTfAnEgAiW254yMQThkBAwcTNvqyEgaV2
132	132	{134,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuXLRhAzvxwEGzCBWmFZojmpUW64M2VP1S4cEiKVMc32ig5JAYh
133	133	{135}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuAQfoUTKfCvnoisEYC4HQUuyWqvu83prmYi7Z5dLhYWAmEoQt3
134	134	{136,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv9EBswMNVwwmyUAbomk7LaXADd4qjR2t3aZG6icea7C5XLBkBv
135	135	{137}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JttUC4pL2aAvu4PHrxPggrGnjpF49vuJNCzL6Gh5Kwcmgz5w3ij
136	136	{138,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtqBdcL62H7N5rHiVXVjhEBkeKU9AUK4SnAZXgktXmbcfnNHUoU
137	137	{139}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JubwanJJwbtDLZE6N7SiSKyAdg2Pi8bF6Ug7Mp6phar1BBuP42X
138	138	{140,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtYmhDPpZtfxyLpuLBuRGTkQrgaWzS72siZB647anpybMgossDj
139	139	{141}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju6qEA9H6gtMtHCLwz4mAxdxQ5aQYJtUTZQjhWfFGY57otmcwnv
140	140	{142,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv6ZerogtEbSP9ZnCx6SPB5YcqH2Mzw9G3WWnfvytZEr64Wg65z
141	141	{143}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv4ZU7bwoQyZHGbSchjbk8RzGSPs7dtiPHuGj5ngCsMtV3Fb1oY
142	142	{144,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JthRrUnr1UnmMzTztAV3abkWkHXqvYzNHWEUNPiPnmJYiPqan1y
143	143	{145}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv2gtHc7NnxNs7xnX7hbDJzrhoWXjw5YoMCZSxGtNrmoKbo1C28
144	144	{146,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuQ8FfPXdwz8iY9mmkLM5M6GSBfSNn1gcdcv8MM3biJ6oeHJDEm
145	145	{147}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtqiN6P7A9E3K1998u8KJjLAYoG4jQpTHKgxKiTLzTijCzfLkTH
146	146	{148,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju4QHcPsVG9az26YfQa68EcHNy7mPaUGNNpMRczLYcjrr6k4QEP
147	147	{149}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jut6Ba6fujr77iR18nzhwVLZoGZrdXyhcS5widjoMMVrZcNX1Ng
148	148	{150,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juq2DjvHKSEBziftp8dsBgVc3d9RQb62SHNwoxS4Y54pJqpLCLP
149	149	{151}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuyLeBSWwSeqBh2SnQrDFUENzQPEwUh4ipm7W6uhgwy3sxLDHY5
150	150	{152,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv8kfGa54iVAncdp82emfVaV2bRFygHyzvRi2B27zHkAHpMXTMK
151	151	{153}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv527yMxmZZB7X7khrX8h29yyQ8ZsnLVWJfN5BQQZku3mThsb66
152	152	{154,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvExYPsxYefr1nUqGEvSxRoX9AaPAMoMN13H87iZGx6AYDLVeHb
153	153	{155}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuJzT9MNLhSwNi5ppg8696bZxMg8DtYj8LAzer8dE268i3iLt9c
154	154	{156,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtq9z88wdoCtUFqvoXjR2UsDxSkAUG7U2d3UZ2srCWsQnDND5Lr
155	155	{157}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtmSudTMPikj9JfbPJLN8JhnbPKVqF8zWgr6FbL3PG31WrrZzj9
156	156	{158,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtiDwRFUpS2osbfSMXcSzMZjQ3F58F9r55F3r12rZibhjtZt4tR
157	157	{159}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuScoab1Hpu8quPBkhANDN9NBszXaqPXm3tqyvFYDXwnmQRDKPg
158	158	{160,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuxPJCEZqYj3PUpPjtmBuq3WVJzTkkTxFUuRAcAoEJ3UMTrcuby
159	159	{161}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju92dYpTTDxQUsNXj147sg46digo1Wb9obwBnDT8Pr7oNrN4bzi
160	160	{162,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juvr7TtaEXSHWWqEsbNvoP1WWaaZP7BPGDYizk4oGTTiqrpMFU5
161	161	{163}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuUY9WG9q2TdaZWShABfjo8RqmvwXgpiTaSjBCz7jf28i3UKhZM
162	162	{164,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jutyn3wbjiFUHnsRYaQ7hrKcg6f8waagG5rfkzrS4UuQut46S2Z
163	163	{165}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvRwSFj2SeVc4CvihJMUVc37cmBhHJrJs6PdNmwbijEeab9xAoz
164	164	{166,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuuRdkSbST5bg3mmxaJE3s1mjLxoeNZdxAXzzHaTbR1GAptQHh8
165	165	{167}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuN2U3JixMBFNtxbwbvpxiWH3Z9miojHT3Ctsrmd63Cm1HpiKTp
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
1	224	5000000000	\N	0
2	224	5000000000	\N	1
3	224	5000000000	\N	2
4	224	5000000000	\N	3
5	224	5000000000	\N	4
6	224	5000000000	\N	5
7	224	5000000000	\N	6
8	224	5000000000	\N	7
9	224	5000000000	\N	8
10	224	5000000000	\N	9
11	224	5000000000	\N	10
12	224	5000000000	\N	11
13	224	5000000000	\N	12
14	224	5000000000	\N	13
15	224	5000000000	\N	14
16	224	5000000000	\N	15
17	224	5000000000	\N	16
18	224	5000000000	\N	17
19	224	5000000000	\N	18
20	224	5000000000	\N	19
21	224	5000000000	\N	20
22	224	5000000000	\N	21
23	224	5000000000	\N	22
24	224	5000000000	\N	23
25	224	5000000000	\N	24
26	224	5000000000	\N	25
27	224	5000000000	\N	26
28	224	5000000000	\N	27
29	224	5000000000	\N	28
30	224	5000000000	\N	29
31	224	5000000000	\N	30
32	224	5000000000	\N	31
33	224	5000000000	\N	32
34	224	5000000000	\N	33
35	224	5000000000	\N	34
36	224	5000000000	\N	35
37	224	5000000000	\N	36
38	224	5000000000	\N	37
39	224	5000000000	\N	38
40	224	5000000000	\N	39
41	224	5000000000	\N	40
42	224	5000000000	\N	41
43	224	5000000000	\N	42
44	224	5000000000	\N	43
45	224	5000000000	\N	44
46	224	5000000000	\N	45
47	224	5000000000	\N	46
48	224	5000000000	\N	47
49	224	5000000000	\N	48
50	224	5000000000	\N	49
51	224	5000000000	\N	50
52	224	5000000000	\N	51
53	224	5000000000	\N	52
54	224	5000000000	\N	53
55	224	5000000000	\N	54
56	224	5000000000	\N	55
57	224	5000000000	\N	56
58	224	5000000000	\N	57
59	224	5000000000	\N	58
60	224	5000000000	\N	59
61	224	5000000000	\N	60
62	224	5000000000	\N	61
63	224	5000000000	\N	62
64	224	5000000000	\N	63
65	224	5000000000	\N	64
66	224	5000000000	\N	65
67	224	5000000000	\N	66
68	224	5000000000	\N	67
69	224	5000000000	\N	68
70	224	5000000000	\N	69
71	224	5000000000	\N	70
72	224	5000000000	\N	71
73	224	5000000000	\N	72
74	224	5000000000	\N	73
75	224	5000000000	\N	74
76	224	5000000000	\N	75
77	224	5000000000	\N	76
78	224	5000000000	\N	77
79	224	5000000000	\N	78
80	224	5000000000	\N	79
81	224	5000000000	\N	80
82	224	5000000000	\N	81
83	224	5000000000	\N	82
84	224	5000000000	\N	83
85	224	5000000000	\N	84
86	224	5000000000	\N	85
87	224	5000000000	\N	86
88	224	5000000000	\N	87
89	224	5000000000	\N	88
90	224	5000000000	\N	89
91	224	5000000000	\N	90
92	224	5000000000	\N	91
93	224	5000000000	\N	92
94	224	5000000000	\N	93
95	224	5000000000	\N	94
96	224	5000000000	\N	95
97	224	5000000000	\N	96
98	224	5000000000	\N	97
99	224	5000000000	\N	98
100	224	5000000000	\N	99
101	224	5000000000	\N	100
102	224	5000000000	\N	101
103	224	5000000000	\N	102
104	224	5000000000	\N	103
105	224	5000000000	\N	104
106	224	5000000000	\N	105
107	224	5000000000	\N	106
108	224	5000000000	\N	107
109	224	5000000000	\N	108
110	224	5000000000	\N	109
111	224	5000000000	\N	110
112	224	5000000000	\N	111
113	224	5000000000	\N	112
114	224	5000000000	\N	113
115	224	5000000000	\N	114
116	224	5000000000	\N	115
117	224	5000000000	\N	116
118	224	5000000000	\N	117
119	224	5000000000	\N	118
120	224	5000000000	\N	119
121	224	5000000000	\N	120
122	224	5000000000	\N	121
123	224	5000000000	\N	122
124	224	5000000000	\N	123
125	224	5000000000	\N	124
126	224	5000000000	\N	125
127	224	5000000000	\N	126
128	224	5000000000	\N	127
129	224	5000000000	\N	128
130	224	5000000000	\N	129
131	224	5000000000	\N	130
132	224	5000000000	\N	131
133	224	5000000000	\N	132
134	224	5000000000	\N	133
135	224	5000000000	\N	134
136	224	5000000000	\N	135
137	224	5000000000	\N	136
138	224	5000000000	\N	137
139	224	5000000000	\N	138
140	224	5000000000	\N	139
141	224	5000000000	\N	140
142	224	5000000000	\N	141
143	224	5000000000	\N	142
144	224	5000000000	\N	143
145	224	5000000000	\N	144
146	224	5000000000	\N	145
147	224	5000000000	\N	146
148	224	5000000000	\N	147
149	224	5000000000	\N	148
150	224	5000000000	\N	149
151	224	5000000000	\N	150
152	224	5000000000	\N	151
153	224	5000000000	\N	152
154	224	5000000000	\N	153
155	224	5000000000	\N	154
156	224	5000000000	\N	155
157	224	5000000000	\N	156
158	224	5000000000	\N	157
159	224	5000000000	\N	158
160	224	5000000000	\N	159
161	224	5000000000	\N	160
162	224	5000000000	\N	161
163	224	5000000000	\N	162
164	224	5000000000	\N	163
165	224	5000000000	\N	164
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
\.


--
-- Data for Name: zkapp_permissions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.zkapp_permissions (id, edit_state, send, receive, access, set_delegate, set_permissions, set_verification_key_auth, set_verification_key_txn_version, set_zkapp_uri, edit_action_state, set_token_symbol, increment_nonce, set_voting_for, set_timing) FROM stdin;
1	signature	signature	none	none	signature	signature	signature	4	signature	signature	signature	signature	signature	signature
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

SELECT pg_catalog.setval('public.account_identifiers_id_seq', 244, true);


--
-- Name: blocks_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.blocks_id_seq', 233, true);


--
-- Name: epoch_data_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.epoch_data_id_seq', 214, true);


--
-- Name: internal_commands_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.internal_commands_id_seq', 64, true);


--
-- Name: protocol_versions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.protocol_versions_id_seq', 1, true);


--
-- Name: public_keys_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.public_keys_id_seq', 245, true);


--
-- Name: snarked_ledger_hashes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.snarked_ledger_hashes_id_seq', 66, true);


--
-- Name: timing_info_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.timing_info_id_seq', 243, true);


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

SELECT pg_catalog.setval('public.user_commands_id_seq', 83, true);


--
-- Name: voting_for_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.voting_for_id_seq', 1, true);


--
-- Name: zkapp_account_precondition_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_account_precondition_id_seq', 83, true);


--
-- Name: zkapp_account_update_body_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_account_update_body_id_seq', 167, true);


--
-- Name: zkapp_account_update_failures_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_account_update_failures_id_seq', 4, true);


--
-- Name: zkapp_account_update_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_account_update_id_seq', 167, true);


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

SELECT pg_catalog.setval('public.zkapp_commands_id_seq', 165, true);


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

SELECT pg_catalog.setval('public.zkapp_fee_payer_body_id_seq', 165, true);


--
-- Name: zkapp_field_array_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_field_array_id_seq', 1, false);


--
-- Name: zkapp_field_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_field_id_seq', 82, true);


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

SELECT pg_catalog.setval('public.zkapp_nonce_bounds_id_seq', 82, true);


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

SELECT pg_catalog.setval('public.zkapp_states_nullable_id_seq', 83, true);


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

SELECT pg_catalog.setval('public.zkapp_updates_id_seq', 84, true);


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
-- PostgreSQL database dump complete
--

