--
-- PostgreSQL database dump
--

-- Dumped from database version 12.4
-- Dumped by pg_dump version 12.4

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
-- Name: migration_status; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.migration_status AS ENUM (
    'starting',
    'applied',
    'failed'
);


ALTER TYPE public.migration_status OWNER TO postgres;

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
    total_stake text,
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
    total_stake text,
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
-- Name: migration_history; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.migration_history (
    commit_start_at timestamp with time zone DEFAULT now() NOT NULL,
    protocol_version text NOT NULL,
    migration_version text NOT NULL,
    description text NOT NULL,
    status public.migration_status NOT NULL
);


ALTER TABLE public.migration_history OWNER TO postgres;

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
    events_id integer,
    actions_id integer,
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
4	6	1
5	7	1
6	8	1
7	5	1
8	1	1
9	9	1
\.


--
-- Data for Name: accounts_accessed; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.accounts_accessed (ledger_index, block_id, account_identifier_id, token_symbol_id, balance, nonce, receipt_chain_hash, delegate_id, voting_for_id, timing_id, permissions_id, zkapp_id) FROM stdin;
7	1	1	1	499000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	\N	1	1	1	\N
3	1	2	1	500000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	\N	1	2	1	\N
4	1	3	1	11550000000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	5	1	3	1	\N
1	1	4	1	5000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	\N	1	4	1	\N
2	1	5	1	65500000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	3	1	5	1	\N
6	1	6	1	11550000000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	2	1	6	1	\N
5	1	7	1	499000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	\N	1	7	1	\N
0	1	8	1	1000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	1	1	8	1	\N
7	2	1	1	859000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	\N	1	1	1	\N
5	3	7	1	859000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	\N	1	7	1	\N
4	4	3	1	11549990000000000	2	2n1Dz5rK9PVEqPH5s5sU1bjcktDiyNSqxonZr69EFVrvZ5zaWha3	5	1	3	1	\N
5	4	7	1	1229000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	\N	1	7	1	\N
7	5	1	1	1229000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	\N	1	1	1	\N
4	5	3	1	11549990000000000	2	2n1Dz5rK9PVEqPH5s5sU1bjcktDiyNSqxonZr69EFVrvZ5zaWha3	5	1	3	1	\N
7	6	1	1	1594000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	\N	1	1	1	\N
4	6	3	1	11549985000000000	3	2n1xWqaBcAMvoKHxt7DSc59J4Z47DA6bMCkAJ9nSBEhEd7LwrcVk	5	1	3	1	\N
4	7	3	1	11549975000000000	5	2n1BroaVuuB3MGQ44riWE5yPDEQCoCSkDemsUP282MVsbgGKbyVd	5	1	3	1	\N
1	7	4	1	5002000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	\N	1	4	1	\N
5	7	7	1	868998000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	\N	1	7	1	\N
4	8	3	1	11549965000000000	7	2n2BnKXJyXSdvjfHfh4r1wjdLcz2RGcpH1KhzoQbCYgj17oF8kUY	5	1	3	1	\N
1	8	4	1	5004000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	\N	1	4	1	\N
5	8	7	1	1238996000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	\N	1	7	1	\N
7	9	1	1	1963997000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	\N	1	1	1	\N
4	9	3	1	11549955000000000	9	2mzy7N9on5jPsqLTXv31nNSxv2juTmUL1AE6PCnjhpGjF1LHqWEL	5	1	3	1	\N
1	9	4	1	5007000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	\N	1	4	1	\N
4	10	3	1	11549955000000000	9	2mzy7N9on5jPsqLTXv31nNSxv2juTmUL1AE6PCnjhpGjF1LHqWEL	5	1	3	1	\N
1	10	4	1	5007000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	\N	1	4	1	\N
5	10	7	1	1608993000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	\N	1	7	1	\N
7	11	1	1	2333994000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	\N	1	1	1	\N
4	11	3	1	11549945000000000	11	2n28tYhDLFcYSJEN8Mx8MdarvwCSY57nNTEg2SJPzqKTBVitASc5	5	1	3	1	\N
1	11	4	1	5010000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	\N	1	4	1	\N
4	12	3	1	11549945000000000	11	2n28tYhDLFcYSJEN8Mx8MdarvwCSY57nNTEg2SJPzqKTBVitASc5	5	1	3	1	\N
1	12	4	1	5010000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	\N	1	4	1	\N
5	12	7	1	1608993000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	\N	1	7	1	\N
4	13	3	1	11549935000000000	13	2n1xtFGKpYiQzpFY3iLGhycnZFSXzNGjFVFzq2a1tiCwh96KkX41	5	1	3	1	\N
1	13	4	1	5014000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	\N	1	4	1	\N
5	13	7	1	1608992000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	\N	1	7	1	\N
4	14	3	1	11549925000000000	15	2mzYG4gJzrTrcKaARajmdL1Sk4TKNtEEYxzdhpDgYUn4aL8QVR3o	5	1	3	1	\N
1	14	4	1	5018000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	\N	1	4	1	\N
5	14	7	1	1978988000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	\N	1	7	1	\N
7	15	1	1	2703990000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	\N	1	1	1	\N
4	15	3	1	11549915000000000	17	2n2SdQHo3XxFXGEirA2jVyUBefv9UpVdHkmppWdcLGvciGS4r8zB	5	1	3	1	\N
1	15	4	1	5022000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	\N	1	4	1	\N
7	16	1	1	3073986000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	\N	1	1	1	\N
4	16	3	1	11549905000000000	19	2n16diHw2nKpr3FyFE3PxtLXNwBHonZ5tQ72mv6URg9gz1p2UP64	5	1	3	1	\N
1	16	4	1	5026000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	\N	1	4	1	\N
7	17	1	1	3443982000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	\N	1	1	1	\N
4	17	3	1	11549895000000000	21	2n1T36CDHEohapKRVN1GoaZtaXq8BV8AUHFr3G4nHTs7BGKdi6Xu	5	1	3	1	\N
1	17	4	1	5030000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	\N	1	4	1	\N
4	18	3	1	11549885000000000	23	2n117Hib7A2K6FPv8SZEodrV1UyrBH67CmbKsxrU4jLEKudz6b3C	5	1	3	1	\N
1	18	4	1	5034000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	\N	1	4	1	\N
5	18	7	1	2348984000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	\N	1	7	1	\N
4	19	3	1	11549875000000000	25	2n1hUEBUFkv53qP85gN5uNLCLUo7Qyrfcvz6MEGDQXkFoZJNoJqy	5	1	3	1	\N
1	19	4	1	5038000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	\N	1	4	1	\N
5	19	7	1	2718980000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	\N	1	7	1	\N
7	20	1	1	3813978000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	\N	1	1	1	\N
4	20	3	1	11549875000000000	25	2n1hUEBUFkv53qP85gN5uNLCLUo7Qyrfcvz6MEGDQXkFoZJNoJqy	5	1	3	1	\N
1	20	4	1	5038000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	\N	1	4	1	\N
7	21	1	1	3813978000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	\N	1	1	1	\N
4	21	3	1	11549865000000000	27	2n2PL2HLFkaQEN3SxfGCUwwNoxPgFPeksKyHiJmSdCV1n4LXYirx	5	1	3	1	\N
1	21	4	1	5042000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	\N	1	4	1	\N
4	22	3	1	11549865000000000	27	2n2PL2HLFkaQEN3SxfGCUwwNoxPgFPeksKyHiJmSdCV1n4LXYirx	5	1	3	1	\N
1	22	4	1	5042000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	\N	1	4	1	\N
5	22	7	1	3088976000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	\N	1	7	1	\N
7	23	1	1	4183974000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	\N	1	1	1	\N
4	23	3	1	11549855000000000	29	2n192KFNAA6WRmeBMQkntUzs4totYmUyhyHiodPBeCBSqDhSv2hY	5	1	3	1	\N
1	23	4	1	5046000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	\N	1	4	1	\N
7	25	1	1	4553970000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	\N	1	1	1	\N
4	25	3	1	11549845000000000	31	2n1nFTLN6Y3W9dDmWcq9zng59ZyUmcASCDW45i3yF6YmAVU9GQR2	5	1	3	1	\N
1	25	4	1	5050000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	\N	1	4	1	\N
7	27	1	1	4923966000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	\N	1	1	1	\N
4	27	3	1	11549835000000000	33	2n1sFUmM6aRBdQbjzR6HGhiBkXXDv4ZezBeVhAnE6vU4V9MUniqo	5	1	3	1	\N
1	27	4	1	5054000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	\N	1	4	1	\N
7	29	1	1	5288963000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	\N	1	1	1	\N
4	29	3	1	11549830000000000	34	2n1bv5AnQcm98zFK1fBwvdMa56TBakjx74BaHDQdKEtZZG2jbAVF	5	1	3	1	\N
1	29	4	1	5057000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	\N	1	4	1	\N
7	30	1	1	5293962000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	\N	1	1	1	\N
4	30	3	1	11549825000000000	35	2n1Vk4SR8Xc6q7b7p8c8muE8GhL15EURxyJbZJRfkZK7AVh2iqwb	5	1	3	1	\N
1	30	4	1	5058000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	\N	1	4	1	\N
7	33	1	1	5293962000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	\N	1	1	1	\N
4	33	3	1	11549825000000000	35	2n1Vk4SR8Xc6q7b7p8c8muE8GhL15EURxyJbZJRfkZK7AVh2iqwb	5	1	3	1	\N
1	33	4	1	5058000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	\N	1	4	1	\N
7	34	1	1	5663958000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	\N	1	1	1	\N
4	34	3	1	11549815000000000	37	2n1ndHnyfW9zah3ewGxbj13u7YiVwgx1wNTNHVxneazu4D62SgJy	5	1	3	1	\N
1	34	4	1	5062000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	\N	1	4	1	\N
4	35	3	1	11549815000000000	37	2n1ndHnyfW9zah3ewGxbj13u7YiVwgx1wNTNHVxneazu4D62SgJy	5	1	3	1	\N
1	35	4	1	5062000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	\N	1	4	1	\N
5	35	7	1	3088976000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	\N	1	7	1	\N
\.


--
-- Data for Name: accounts_created; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.accounts_created (block_id, account_identifier_id, creation_fee) FROM stdin;
\.


--
-- Data for Name: blocks; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.blocks (id, state_hash, parent_id, parent_hash, creator_id, block_winner_id, last_vrf_output, snarked_ledger_hash_id, staking_epoch_data_id, next_epoch_data_id, min_window_density, sub_window_densities, total_currency, total_stake, ledger_hash, height, global_slot_since_hard_fork, global_slot_since_genesis, protocol_version_id, proposed_protocol_version_id, "timestamp", chain_status) FROM stdin;
1	3NL7ZxMxonjaW5ojxmkaUaPnGB8TVtjwA9a7M3b44MiY63TXDMcu	\N	3NKe7M9bybCcqzQaZ8B53pUY6vZvgEYsyUjLzVABuJd5Bz7QjAgP	1	1	39cyg4ZmMtnb_aFUIerNAoAJV8qtkfOpq0zFzPspjgM=	1	1	2	77	{1,7,7,7,7,7,7,7,7,7,7}	23167003000001000	23165500000001000	jxmyYcnijqX2e4RxMN7AwZHaLo4bJYhoYXCdv6WTEdnLexSMNbu	1	0	0	1	\N	1789398227000	orphaned
3	3NKDR8oLxjx5KWZLVaRtow6RVjDTLEBTeABcyzRmALsqXFXEh2pt	1	3NL7ZxMxonjaW5ojxmkaUaPnGB8TVtjwA9a7M3b44MiY63TXDMcu	5	4	T2iEnuDsOcn9ZHtWzUnGBWdVZVyiaKQE5yzw4htijgk=	1	1	4	77	{2,7,7,7,7,7,7,7,7,7,7}	23167003000001000	23165500000001000	jxwG8VxXKyz7vYNULUCXeHjCasGF3e9ZUQq7YgX4rWe5oAa48x8	2	5	5	1	\N	1789398377000	orphaned
4	3NK6udDyTtztNdEYnJZxEdeBYV4AE2iCk8ZmdFErq92JoKQKYAy6	3	3NKDR8oLxjx5KWZLVaRtow6RVjDTLEBTeABcyzRmALsqXFXEh2pt	5	4	2xJ84CKiWHYgodtKe5Yi6SjXLFHpBLS-1ORca9z7PgA=	1	1	5	77	{3,7,7,7,7,7,7,7,7,7,7}	23167003000001000	23165500000001000	jx81cn2LdUnmAWv8RUXcHGX1x3YMB7C8TESZT4FNSZFMhNHpGng	3	6	6	1	\N	1789398407000	orphaned
10	3NLE1R2GZSTk1vVWJbL68tUL9Q3CR22bScCmucXDopWdToPNHjbu	8	3NKD3L28JzA8ZU3Qr8N9mwGbUqHVFczMp3icBswUks2ehzbzqgZj	5	4	zR9JBXXD6WMsVzht1L1fm3800RSX7iJDkZ6QRdzCEww=	1	1	11	77	{3,4,7,7,7,7,7,7,7,7,7}	23167003000001000	23165500000001000	jwQkhfmVN2rsVFRR8hWWWiZdrTnzHsNWnUr3N96NHLACKqjAm6R	7	11	11	1	\N	1789398557000	orphaned
12	3NKAqHGpu28M3rbeLdTteYdBBa9JHg2r8AAhNNDArJKH7CQZx2gt	9	3NLALrr7spMCiT2ernhfx57xQyFkKZQpBuzdr2caiGLUoSg5kdKD	5	4	B_EnNoI5BNvA_MKHT8OaI2pTvMy3JGFbSEVaKDWMpAM=	1	1	13	77	{3,5,7,7,7,7,7,7,7,7,7}	23167003000001000	23165500000001000	jwNrF9DzmLA3A5HkpTkStCoyoR518e5duqTm5vdFthqcf47VdGU	8	12	12	1	\N	1789398587000	orphaned
13	3NL62PhDeqStxPCzjcD16EZ3Nfzw5HV5KqyLAPA1smu4RSNtVsek	11	3NKXNhzvCm8S7KQ88Pq1CZpxiRLrBMSjhABGf2Y7C6BBuG3m7vgx	5	4	Iep8r0bQICO6WYUNjhX9ILUNDDdQcV8L-4La3BSMcAU=	2	1	14	77	{3,5,1,7,7,7,7,7,7,7,7}	23167363000001000	23165490000001000	jxLyDP63gHooadedWf44FApBXzFbMytmD8Bo1j7LY6VbcouP7Ti	9	14	14	1	\N	1789398647000	canonical
11	3NKXNhzvCm8S7KQ88Pq1CZpxiRLrBMSjhABGf2Y7C6BBuG3m7vgx	9	3NLALrr7spMCiT2ernhfx57xQyFkKZQpBuzdr2caiGLUoSg5kdKD	2	8	mYtI1COwxVBVSvk7vUlyxp--0qrSnCsFUNAuRUtojAo=	1	1	12	77	{3,5,7,7,7,7,7,7,7,7,7}	23167003000001000	23165500000001000	jwKbfL2h3RoYHjnJaBWUtd9CPJ1NDw7LrqRm3CKzs5zWtMWYwrX	8	12	12	1	\N	1789398587000	canonical
9	3NLALrr7spMCiT2ernhfx57xQyFkKZQpBuzdr2caiGLUoSg5kdKD	8	3NKD3L28JzA8ZU3Qr8N9mwGbUqHVFczMp3icBswUks2ehzbzqgZj	2	8	UP8l4DDZsGWxUvgJkbGaQnNdPOkQ06KAdY1M5kaDhg4=	1	1	10	77	{3,4,7,7,7,7,7,7,7,7,7}	23167003000001000	23165500000001000	jxjiYerrhhmVtb3BME4YkRHU5iUFY2dWsbkLqYm8YBetJQP5bGj	7	11	11	1	\N	1789398557000	canonical
8	3NKD3L28JzA8ZU3Qr8N9mwGbUqHVFczMp3icBswUks2ehzbzqgZj	7	3NKfazfasD7otJdx2sJjt2cKSM2FNfVYDSGZHPJRrKUJ9ZKHPmXW	5	4	ojeNksvqPlOESBv7lEPC3Xg3t8W1GeMw0XqrmizNvg8=	1	1	9	77	{3,3,7,7,7,7,7,7,7,7,7}	23167003000001000	23165500000001000	jxmKgGRe6RNEGvuLhBBBdaFKWtMjLjDBjRJ5XJNTiPtTrnhvtxv	6	9	9	1	\N	1789398497000	canonical
7	3NKfazfasD7otJdx2sJjt2cKSM2FNfVYDSGZHPJRrKUJ9ZKHPmXW	6	3NLZ49AXjPdAnHrb4YfLqKQdZHLhvMkuc22uRpkfzn6fTpTdJGgQ	5	4	73G_mejwpTufjxtx_oi_y41SKsFdJ86otR9XgrNWgwg=	1	1	8	77	{3,2,7,7,7,7,7,7,7,7,7}	23167003000001000	23165500000001000	jw7eXjLwt1ZTJz9Lgye7Ysmm71kyx5Vv8DLZyecJfh7osHuaDQ3	5	8	8	1	\N	1789398467000	canonical
6	3NLZ49AXjPdAnHrb4YfLqKQdZHLhvMkuc22uRpkfzn6fTpTdJGgQ	5	3NLJ9KYZRsGjuE1SA5RUQCUAeeca9f476G7kneDr8eDLqwcoPBZ1	2	8	UmQHMBauR3W3zuIHMH16GsOWwbfhoSM6wpRiMM_Vngk=	1	1	7	77	{3,1,7,7,7,7,7,7,7,7,7}	23167003000001000	23165500000001000	jxaLog3isnqxYcGveuVJzYtXo2D21BUFsewSXqa2qCyojtj4vSs	4	7	7	1	\N	1789398437000	canonical
5	3NLJ9KYZRsGjuE1SA5RUQCUAeeca9f476G7kneDr8eDLqwcoPBZ1	2	3NLVj7KoZQNpgxzBC1p2FYxPnDSb6Cfbjfbbr2somt8Tf4yM8MYa	2	8	7QBgHhu6G2UyFhMT34YJdU_342wlks9GM3L8Wpj8swQ=	1	1	6	77	{3,7,7,7,7,7,7,7,7,7,7}	23167003000001000	23165500000001000	jxarhmGpy15LxtkfRcAQyCgxRHxGQQGdeAcqtUmA7d2oimY6fdw	3	6	6	1	\N	1789398407000	canonical
2	3NLVj7KoZQNpgxzBC1p2FYxPnDSb6Cfbjfbbr2somt8Tf4yM8MYa	1	3NL7ZxMxonjaW5ojxmkaUaPnGB8TVtjwA9a7M3b44MiY63TXDMcu	2	8	3WDggxBLCeU7zSddyjp0LAnr69oPZuCYvezzYKXZtQw=	1	1	3	77	{2,7,7,7,7,7,7,7,7,7,7}	23167003000001000	23165500000001000	jxDmcQcFHC1QSeM6c83RqQqRpaRuYekLuGLidYBgo2hzgfQHG5V	2	4	4	1	\N	1789398374109	canonical
20	3NLo3tsJyqqVsgFu6bpLbsJRaSKqoRsvKhyKbxceXG6QeP4iX3Yg	18	3NLnjfyhDnxVC55Usi8HLTXKzvi4RcPLkeCY95Ww6ShzKweZz7V9	2	8	fvupMeu5JZq6FOB4270PdJHyE0MW5IOocDxIKYOwBgc=	8	1	21	77	{3,5,6,1,7,7,7,7,7,7,7}	23169883000001000	23165435000001000	jxHy3avK6tMPpfMCyLzKcpgpUBo1gNCx599DQxTwqtYMESfmQFC	15	21	21	1	\N	1789398857000	orphaned
22	3NKPMux2LPVLyz4UaoxVn7pE2cdRf7nfTXrxzLi745uDyHa8XGCb	19	3NKTUgVDuBAW4KfMmZprx4ym5a2tUCPP3zfb1Z185XFWnN3J5QAC	5	4	Xt8J1T1wTz_km3dPQ7I9V4F4fWIB9rZ6EUYeHWhWKwU=	9	1	23	77	{3,5,6,2,7,7,7,7,7,7,7}	23170243000001000	23165425000001000	jwjSbwPrdKMazzy9qv6kKUzZ6PHKLdmqyhE3X59dEy7Uw4D8DxF	16	23	23	1	\N	1789398917000	orphaned
24	3NKe4QPRdpss4gaqutGhrPCMkAyu58jX878ghfg7mhaPJAUjWkya	22	3NKPMux2LPVLyz4UaoxVn7pE2cdRf7nfTXrxzLi745uDyHa8XGCb	5	4	p_x2VwpTLCNxq9Sp6iohXjlkgRy07-aamTvB3zVvFAI=	9	1	25	77	{3,5,6,3,7,7,7,7,7,7,7}	23170243000001000	23165425000001000	jwjSbwPrdKMazzy9qv6kKUzZ6PHKLdmqyhE3X59dEy7Uw4D8DxF	17	25	25	1	\N	1789398977000	orphaned
26	3NKKs4bL6yLPEAwZUUC6uDJU1P4vZHeEKR1cwdXAvgxHdGfW3Aah	24	3NKe4QPRdpss4gaqutGhrPCMkAyu58jX878ghfg7mhaPJAUjWkya	5	4	8NyiKa6rqMjQks6841NNMeO5EKr-8JHTdOe37DQL4ww=	9	1	27	77	{3,5,6,4,7,7,7,7,7,7,7}	23170243000001000	23165425000001000	jwjSbwPrdKMazzy9qv6kKUzZ6PHKLdmqyhE3X59dEy7Uw4D8DxF	18	26	26	1	\N	1789399007000	orphaned
29	3NLYLn76KZxLpLCPQTQqUyVWFnT2ZMYxARTPshzuxGReezr9Pi3e	27	3NKk9bhbvDNA2emVzRMqvFcf4DPmYZabheCvrJrtBd8ZS6osKxzz	2	8	IMJ-RKnYoyO3mjVFA2gMwlROBxR74EDLwlVARngm4ws=	12	1	30	77	{3,5,6,6,7,7,7,7,7,7,7}	23171323000001000	23165395000001000	jxEqyx7TDgYco1nb5o5T3evjF86hABRsoicgCAVNetbSRLivYXX	20	27	27	1	\N	1789399037000	orphaned
27	3NKk9bhbvDNA2emVzRMqvFcf4DPmYZabheCvrJrtBd8ZS6osKxzz	25	3NL81iiDkRMVSS6wGDiM8P3ypsWPTdpsB3HBdLx3HY6ZG9bAc2R8	2	8	mg6Fmu4j0h7MqPWh0UfDCw7VJjRQSJYGZxSD5pSfngU=	12	1	28	77	{3,5,6,5,7,7,7,7,7,7,7}	23171323000001000	23165395000001000	jxjf9QZzV1E5KppgfUJyuEUDUF7yPUT6qhm4r7MJc36hQbQASVq	19	26	26	1	\N	1789399007000	canonical
25	3NL81iiDkRMVSS6wGDiM8P3ypsWPTdpsB3HBdLx3HY6ZG9bAc2R8	23	3NL89BVFUVR6h73FJC4zmAud2SZUk1V32xnvbHE8jb3NgBh5LiLP	2	8	WHGI52KDElC5MUEvvpfzSVcTJKBQLCRXb-3twIt-LAQ=	11	1	26	77	{3,5,6,4,7,7,7,7,7,7,7}	23170963000001000	23165405000001000	jy39PYnxvZinyKehwwhRdjtbaXAk3V6crkKQRoN96Dtpph7ESCC	18	25	25	1	\N	1789398977000	canonical
23	3NL89BVFUVR6h73FJC4zmAud2SZUk1V32xnvbHE8jb3NgBh5LiLP	21	3NLaXy6GDcDxbJMKZg9iNUagom5xukHoB7UuLqhzh3QQfhTe4ncV	2	8	aW3UZ2DW9C5m_9C3UmUcICPrysYAebJBdmjczBv1lwQ=	10	1	24	77	{3,5,6,3,7,7,7,7,7,7,7}	23170603000001000	23165415000001000	jwnLMYnmMoz6NjYi4kStsHLtEXaaNS4Qq8vFDB9mFRH1jk3jwRD	17	24	24	1	\N	1789398947000	canonical
21	3NLaXy6GDcDxbJMKZg9iNUagom5xukHoB7UuLqhzh3QQfhTe4ncV	19	3NKTUgVDuBAW4KfMmZprx4ym5a2tUCPP3zfb1Z185XFWnN3J5QAC	2	8	_q_6J60-nHD7HoDgFngjlt7qwzCS_QMEmT9d7CLtbgQ=	9	1	22	77	{3,5,6,2,7,7,7,7,7,7,7}	23170243000001000	23165425000001000	jxhsRfnf6F4c7Za46RcZWqEe9dfTXTnWgfd4xpbwc7aXiYVyZiX	16	22	22	1	\N	1789398887000	canonical
19	3NKTUgVDuBAW4KfMmZprx4ym5a2tUCPP3zfb1Z185XFWnN3J5QAC	18	3NLnjfyhDnxVC55Usi8HLTXKzvi4RcPLkeCY95Ww6ShzKweZz7V9	5	4	a3EZF78X-M_1XvzUpzdcD2kxUWDrOab56SXIZA7KqQk=	8	1	20	77	{3,5,6,1,7,7,7,7,7,7,7}	23169883000001000	23165435000001000	jwuhnsdzQVSfZ8Ws1mhRLP8PDtgb5V5XwExYado8JdPSvZVHsXa	15	21	21	1	\N	1789398857000	canonical
18	3NLnjfyhDnxVC55Usi8HLTXKzvi4RcPLkeCY95Ww6ShzKweZz7V9	17	3NLYvb7JWgUZwaJZnhPUVLuYqCzrWSZU8bhye5GV7Z8kCMVnUCEH	5	4	3mfvuhSUKz7bq_RqpfKS3MX6svDmZSwHF5pdi9SftQg=	7	1	19	77	{3,5,6,7,7,7,7,7,7,7,7}	23169523000001000	23165445000001000	jwojNUDscTSTwQUJ8RLnWq9HCRa8XGakgSzvmbmbnPQnAGsefGf	14	20	20	1	\N	1789398827000	canonical
17	3NLYvb7JWgUZwaJZnhPUVLuYqCzrWSZU8bhye5GV7Z8kCMVnUCEH	16	3NKbLqYrUSMVNBQrMzeicoTK7bVW4ANrjo6CsGiH8RCJJG469GyG	2	8	-O4lJM6ZfMw42bvM4Fa1PbRg0msxcknVObVFOYm2OAs=	6	1	18	77	{3,5,5,7,7,7,7,7,7,7,7}	23169163000001000	23165455000001000	jwZLmoydnP8ankgT5bbLKaP3CtTswtgYrU2iTkoD5ycmspNHS3q	13	18	18	1	\N	1789398767000	canonical
16	3NKbLqYrUSMVNBQrMzeicoTK7bVW4ANrjo6CsGiH8RCJJG469GyG	15	3NKKPj7znSQr6C47h3Z2QDyCorozbSiLH44oSWJJ5jXZ16Bz6Q3i	2	8	quETQ0ioqU6N9tgKjgIVT4tMWZ7bE4TT7iWnOLQ8KwU=	5	1	17	77	{3,5,4,7,7,7,7,7,7,7,7}	23168803000001000	23165465000001000	jxR7PPHg4g2yjfy7RqKfkEhZM46NUwVKFYn5Ap5pgGXGKAQx5Vs	12	17	17	1	\N	1789398737000	canonical
15	3NKKPj7znSQr6C47h3Z2QDyCorozbSiLH44oSWJJ5jXZ16Bz6Q3i	14	3NKNsxs8QA1SQCCMNa3LeZYxjnzxnbfAd7Dt3oBbRVUu3YwSYtzh	2	8	NyPPC0_bx2JEI5GRmS6UC0fAlt9Cs61dLYmflz8bOgY=	4	1	16	77	{3,5,3,7,7,7,7,7,7,7,7}	23168443000001000	23165475000001000	jwTxjDk2LRz7QRxaqtruDSHXadVBEKyjrCec29dZpvbWEmrEBSN	11	16	16	1	\N	1789398707000	canonical
14	3NKNsxs8QA1SQCCMNa3LeZYxjnzxnbfAd7Dt3oBbRVUu3YwSYtzh	13	3NL62PhDeqStxPCzjcD16EZ3Nfzw5HV5KqyLAPA1smu4RSNtVsek	5	4	a-wrLpNEh7P-BkZzkDFeb1IM3joSXuZgbG4hrsLhNA8=	3	1	15	77	{3,5,2,7,7,7,7,7,7,7,7}	23168083000001000	23165485000001000	jw7x93dXshJrt6eEFwg9Df8ib6geRjmsdmXucUKvLhfwieQpMaF	10	15	15	1	\N	1789398677000	canonical
30	3NLjZd9bdeLHkEWfkjjPagU2P3MB15Wd8GHukZrNVDStXPSj5qJm	28	3NLu5J3xqATNUvdGPft6rFckTbJ5Ebp7vr1C5GYRy7gEM6WisoRn	2	8	SpHon7pbFJPXiirroNUEWcLDMiZrZi2qslpYYAllxQ8=	13	1	31	77	{3,5,6,6,1,7,7,7,7,7,7}	23171683000001000	23165385000001000	jwVhi7hFuJvZvjGgiYH2PDjaU8oLAyAk5QgqLMypcft3pe2paEA	21	29	29	1	\N	1789399097000	orphaned
32	3NLijM1SFz9aPaGGbosfWNfyWqrfacQtzC3vWPmkCDynTMcarWzg	31	3NLotpbSFPBTxG6isWU7unKPc3jz8QXYAUNm1D4adhgZ1qqe6So9	5	4	T1xyjC59JjA8Bt35EwAEt6PwmE0vFtZrBfOwsw3-Rgc=	12	1	33	77	{3,5,6,6,2,7,7,7,7,7,7}	23171323000001000	23165395000001000	jxjf9QZzV1E5KppgfUJyuEUDUF7yPUT6qhm4r7MJc36hQbQASVq	22	30	30	1	\N	1789399127000	orphaned
34	3NLcCAdnrsV2mBiJiHBwSHefBwwYs4DdwPac8ty5g9DwiwyzWY9a	33	3NLGs1RzqfzqUZ5TRPDepfW8RdPqNFW85HsXTwsx9V9GcR4Msr7s	2	8	go4LaBI42y-GC59NWn58VW3SL6Kh3amOXxagDnNQZQk=	14	1	35	77	{3,5,6,6,3,7,7,7,7,7,7}	23172043000001000	23165375000001000	jx7jd8zhdrC2jHcRuVsW6AWgdSquSNeWUkHqrhjGHzuk8MNN68b	23	31	31	1	\N	1789399157000	orphaned
35	3NK4wPxePvrVbAMRdnzYkNdCLtN1pTNSjU1ZGBsHxsNix3p5kCyM	33	3NLGs1RzqfzqUZ5TRPDepfW8RdPqNFW85HsXTwsx9V9GcR4Msr7s	5	4	wUlzpryTiucNc-_B5ZWxe0ycGkoXgfkqsWVqsLGnag4=	14	1	36	77	{3,5,6,6,3,7,7,7,7,7,7}	23172043000001000	23165375000001000	jxgTeQT86bLNqcz2yUnpjm6kA8e9np17aqjSWq24Szron6yY6Mj	23	31	31	1	\N	1789399157000	canonical
33	3NLGs1RzqfzqUZ5TRPDepfW8RdPqNFW85HsXTwsx9V9GcR4Msr7s	31	3NLotpbSFPBTxG6isWU7unKPc3jz8QXYAUNm1D4adhgZ1qqe6So9	2	8	2vjyh5nhxZXQLTENetvxaxq4aRT47GjBtzG4rHcxxQA=	13	1	34	77	{3,5,6,6,2,7,7,7,7,7,7}	23171683000001000	23165385000001000	jwVhi7hFuJvZvjGgiYH2PDjaU8oLAyAk5QgqLMypcft3pe2paEA	22	30	30	1	\N	1789399127000	canonical
31	3NLotpbSFPBTxG6isWU7unKPc3jz8QXYAUNm1D4adhgZ1qqe6So9	28	3NLu5J3xqATNUvdGPft6rFckTbJ5Ebp7vr1C5GYRy7gEM6WisoRn	5	4	_WYQKstHC5NWAdEDaW_MU7vCRIJdLRbTduiJTrAs8gw=	12	1	32	77	{3,5,6,6,1,7,7,7,7,7,7}	23171323000001000	23165395000001000	jxjf9QZzV1E5KppgfUJyuEUDUF7yPUT6qhm4r7MJc36hQbQASVq	21	29	29	1	\N	1789399097000	canonical
28	3NLu5J3xqATNUvdGPft6rFckTbJ5Ebp7vr1C5GYRy7gEM6WisoRn	27	3NKk9bhbvDNA2emVzRMqvFcf4DPmYZabheCvrJrtBd8ZS6osKxzz	5	4	Elav1ZhH6IjS-TXp3KaE7mvkvb9MjIM73LJEiCZOFg0=	12	1	29	77	{3,5,6,6,7,7,7,7,7,7,7}	23171323000001000	23165395000001000	jxjf9QZzV1E5KppgfUJyuEUDUF7yPUT6qhm4r7MJc36hQbQASVq	20	27	27	1	\N	1789399037000	canonical
\.


--
-- Data for Name: blocks_internal_commands; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.blocks_internal_commands (block_id, internal_command_id, sequence_no, secondary_sequence_no, status, failure_reason) FROM stdin;
2	1	0	0	applied	\N
3	2	0	0	applied	\N
4	3	2	0	applied	\N
4	2	3	0	applied	\N
5	4	2	0	applied	\N
5	1	3	0	applied	\N
6	1	1	0	applied	\N
6	5	2	0	applied	\N
7	6	2	0	applied	\N
7	7	2	0	applied	\N
7	8	3	0	applied	\N
7	9	3	1	applied	\N
8	6	2	0	applied	\N
8	7	2	0	applied	\N
8	8	3	0	applied	\N
8	9	3	1	applied	\N
9	6	2	0	applied	\N
9	10	2	0	applied	\N
9	11	3	0	applied	\N
9	12	3	1	applied	\N
10	6	2	0	applied	\N
10	7	2	0	applied	\N
10	12	3	0	applied	\N
10	13	3	1	applied	\N
11	6	2	0	applied	\N
11	10	2	0	applied	\N
11	11	3	0	applied	\N
11	12	3	1	applied	\N
12	6	2	0	applied	\N
12	7	2	0	applied	\N
12	12	3	0	applied	\N
12	13	3	1	applied	\N
13	6	2	0	applied	\N
13	7	2	0	applied	\N
13	14	3	0	applied	\N
13	15	3	1	applied	\N
14	6	2	0	applied	\N
14	7	2	0	applied	\N
14	14	3	0	applied	\N
14	15	3	1	applied	\N
15	6	2	0	applied	\N
15	10	2	0	applied	\N
15	16	3	0	applied	\N
15	14	3	1	applied	\N
16	6	2	0	applied	\N
16	10	2	0	applied	\N
16	16	3	0	applied	\N
16	14	3	1	applied	\N
17	6	2	0	applied	\N
17	10	2	0	applied	\N
17	16	3	0	applied	\N
17	14	3	1	applied	\N
18	6	2	0	applied	\N
18	7	2	0	applied	\N
18	14	3	0	applied	\N
18	15	3	1	applied	\N
19	6	2	0	applied	\N
19	7	2	0	applied	\N
19	14	3	0	applied	\N
19	15	3	1	applied	\N
20	6	2	0	applied	\N
20	10	2	0	applied	\N
20	16	3	0	applied	\N
20	14	3	1	applied	\N
21	6	2	0	applied	\N
21	10	2	0	applied	\N
21	16	3	0	applied	\N
21	14	3	1	applied	\N
22	6	2	0	applied	\N
22	7	2	0	applied	\N
22	14	3	0	applied	\N
22	15	3	1	applied	\N
23	6	2	0	applied	\N
23	10	2	0	applied	\N
23	16	3	0	applied	\N
23	14	3	1	applied	\N
25	6	2	0	applied	\N
25	10	2	0	applied	\N
25	16	3	0	applied	\N
25	14	3	1	applied	\N
27	6	2	0	applied	\N
27	10	2	0	applied	\N
27	16	3	0	applied	\N
27	14	3	1	applied	\N
29	6	1	0	applied	\N
29	10	1	0	applied	\N
29	17	2	0	applied	\N
29	12	2	1	applied	\N
30	6	2	0	applied	\N
30	10	2	0	applied	\N
30	16	3	0	applied	\N
30	14	3	1	applied	\N
33	6	2	0	applied	\N
33	10	2	0	applied	\N
33	16	3	0	applied	\N
33	14	3	1	applied	\N
34	6	2	0	applied	\N
34	10	2	0	applied	\N
34	16	3	0	applied	\N
34	14	3	1	applied	\N
35	6	2	0	applied	\N
35	7	2	0	applied	\N
35	14	3	0	applied	\N
35	15	3	1	applied	\N
\.


--
-- Data for Name: blocks_user_commands; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.blocks_user_commands (block_id, user_command_id, sequence_no, status, failure_reason) FROM stdin;
\.


--
-- Data for Name: blocks_zkapp_commands; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.blocks_zkapp_commands (block_id, zkapp_command_id, sequence_no, status, failure_reasons_ids) FROM stdin;
4	1	0	failed	{1,2}
4	2	1	failed	{3,2}
5	1	0	failed	{1,2}
5	2	1	failed	{3,2}
6	3	0	failed	{4}
7	4	0	failed	{3,2}
7	5	1	failed	{4}
8	6	0	failed	{3,2}
8	7	1	failed	{4}
9	8	0	failed	{3,2}
9	9	1	failed	{4}
10	8	0	failed	{3,2}
10	9	1	failed	{4}
11	10	0	failed	{3,2}
11	11	1	failed	{4}
12	10	0	failed	{3,2}
12	11	1	failed	{4}
13	12	0	failed	{3,2}
13	13	1	failed	{4}
14	14	0	failed	{3,2}
14	15	1	failed	{4}
15	16	0	failed	{3,2}
15	17	1	failed	{4}
16	18	0	failed	{3,2}
16	19	1	failed	{4}
17	20	0	failed	{3,2}
17	21	1	failed	{4}
18	22	0	failed	{3,2}
18	23	1	failed	{4}
19	24	0	failed	{3,2}
19	25	1	failed	{4}
20	24	0	failed	{3,2}
20	25	1	failed	{4}
21	26	0	failed	{3,2}
21	27	1	failed	{4}
22	26	0	failed	{3,2}
22	27	1	failed	{4}
23	28	0	failed	{3,2}
23	29	1	failed	{4}
25	30	0	failed	{3,2}
25	31	1	failed	{4}
27	32	0	failed	{3,2}
27	33	1	failed	{4}
29	34	0	failed	{3,2}
30	34	0	failed	{3,2}
30	35	1	failed	{4}
33	34	0	failed	{3,2}
33	35	1	failed	{4}
34	36	0	failed	{3,2}
34	37	1	failed	{4}
35	36	0	failed	{3,2}
35	37	1	failed	{4}
\.


--
-- Data for Name: epoch_data; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.epoch_data (id, seed, ledger_hash_id, total_currency, total_stake, start_checkpoint, lock_checkpoint, epoch_length) FROM stdin;
1	2va9BGv9JrLTtrzZttiEMDYw1Zj6a6EHzXjmP9evHDTG3oEquURA	1	23167003000001000	23165500000001000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	1
2	2vafPBQ3zQdHUEDDnFGuiNvJz7s2MhTLJgSzQSnu5fnZavT27cms	1	23167003000001000	23165500000001000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKe7M9bybCcqzQaZ8B53pUY6vZvgEYsyUjLzVABuJd5Bz7QjAgP	2
3	2vbWh1f4myWMRoFmBxE2Vh8Z1bvUBzK54mPcUDbQXtuSjtqTUeay	1	23167003000001000	23165500000001000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NL7ZxMxonjaW5ojxmkaUaPnGB8TVtjwA9a7M3b44MiY63TXDMcu	3
4	2vaSGCHMbyLBJ1RcT3JSi6Pm6KoSbFGj2KhHpkH9UYkHpP3F25aR	1	23167003000001000	23165500000001000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NL7ZxMxonjaW5ojxmkaUaPnGB8TVtjwA9a7M3b44MiY63TXDMcu	3
5	2vbBLRGW1gJXuwnfvcYbci2uw88hv2jpQncArmFSeKoSLKpLwJWM	1	23167003000001000	23165500000001000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKDR8oLxjx5KWZLVaRtow6RVjDTLEBTeABcyzRmALsqXFXEh2pt	4
6	2vaYABZRUqmpiPiHsLuWzZq5V4J6rTH6GaRN8JP5MkWYWpVELueW	1	23167003000001000	23165500000001000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLVj7KoZQNpgxzBC1p2FYxPnDSb6Cfbjfbbr2somt8Tf4yM8MYa	4
7	2vb9ewNz8jUZkphWiRfAJ2YGDFD4FtQnzBD6mS1Pag8UUeMPeopL	1	23167003000001000	23165500000001000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLJ9KYZRsGjuE1SA5RUQCUAeeca9f476G7kneDr8eDLqwcoPBZ1	5
8	2vbBJv3oga5SfW9t2VErH6LfMFecuqgajfgaefgrNAh8je4PE32o	1	23167003000001000	23165500000001000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLZ49AXjPdAnHrb4YfLqKQdZHLhvMkuc22uRpkfzn6fTpTdJGgQ	6
9	2vacQmE7EibUpmekn9f8i7ZLVQmmJim8kd9XHEP1NAHvdZiVhRM6	1	23167003000001000	23165500000001000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKfazfasD7otJdx2sJjt2cKSM2FNfVYDSGZHPJRrKUJ9ZKHPmXW	7
10	2vbrjeGaycZWHJJKu1HUoX13AAL9fN8HnnMDR7y14qScbHKZxM6d	1	23167003000001000	23165500000001000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKD3L28JzA8ZU3Qr8N9mwGbUqHVFczMp3icBswUks2ehzbzqgZj	8
11	2vaiR4g3NSPohBoWYpSCGkf5zfhm3qNQUeG86BEfasMVAK4HxUkE	1	23167003000001000	23165500000001000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKD3L28JzA8ZU3Qr8N9mwGbUqHVFczMp3icBswUks2ehzbzqgZj	8
12	2vabjbrkbU2ozaeYHBRw98CWBcLvd3wswwY9ZhFruwtujghhfKaV	1	23167003000001000	23165500000001000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLALrr7spMCiT2ernhfx57xQyFkKZQpBuzdr2caiGLUoSg5kdKD	9
13	2vaFMtq8zauTXLZEAk9bEgqQ7BkLp9R6T4fzk9fJvM9Wx6abNyYo	1	23167003000001000	23165500000001000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLALrr7spMCiT2ernhfx57xQyFkKZQpBuzdr2caiGLUoSg5kdKD	9
14	2vbr5Zumuuqe9RdEVkFzbDczmXkU7vwNQmf3rfS9m61VEV5FENhK	1	23167003000001000	23165500000001000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKXNhzvCm8S7KQ88Pq1CZpxiRLrBMSjhABGf2Y7C6BBuG3m7vgx	10
15	2vbQc97XA3tBefgv2dhEyCqRFjHuQQNohwMuZCmay9wEvcCeYTpe	1	23167003000001000	23165500000001000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NL62PhDeqStxPCzjcD16EZ3Nfzw5HV5KqyLAPA1smu4RSNtVsek	11
16	2vaT4NnCifbyjxbKDiM9LmD34M8ZCizTfZdhH5PWqqihHoUZ7snr	1	23167003000001000	23165500000001000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKNsxs8QA1SQCCMNa3LeZYxjnzxnbfAd7Dt3oBbRVUu3YwSYtzh	12
17	2vaJr6YA8UKLU4xXum93Tv3JMXSJMnWAa3Rd8n6HnF5QBHCZeBJK	1	23167003000001000	23165500000001000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKKPj7znSQr6C47h3Z2QDyCorozbSiLH44oSWJJ5jXZ16Bz6Q3i	13
18	2vasbEvVUqeH2HfJ9QuMmmgcKZPPaWdTQyXH8jv3JWQCB1xdi8uP	1	23167003000001000	23165500000001000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKbLqYrUSMVNBQrMzeicoTK7bVW4ANrjo6CsGiH8RCJJG469GyG	14
19	2vaPGydzFwMeE8TKvSwMBK3yMYJtWRq5N8RNy5WxWmcCzo3zZzMk	1	23167003000001000	23165500000001000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLYvb7JWgUZwaJZnhPUVLuYqCzrWSZU8bhye5GV7Z8kCMVnUCEH	15
20	2vbETNYP4rsyu61gjGz2LZDN1SY6hKUDnXjPShbVky8JMQ1yEqz8	1	23167003000001000	23165500000001000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLnjfyhDnxVC55Usi8HLTXKzvi4RcPLkeCY95Ww6ShzKweZz7V9	16
21	2vbVZ3ydVP5TJjQibq2ewM2fZhpUs42TmbMu9KXxnZX7HmiF4cbG	1	23167003000001000	23165500000001000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLnjfyhDnxVC55Usi8HLTXKzvi4RcPLkeCY95Ww6ShzKweZz7V9	16
22	2vaAExU5Y59L5KtqDAVez1zS7CS1gYUH7uN8WdVL7wGNd63GMGeX	1	23167003000001000	23165500000001000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKTUgVDuBAW4KfMmZprx4ym5a2tUCPP3zfb1Z185XFWnN3J5QAC	17
23	2vbJfQWsoYd3nzKZGP5n6X55owsvRGmWgvdX8UnVquQR9idcZNRY	1	23167003000001000	23165500000001000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKTUgVDuBAW4KfMmZprx4ym5a2tUCPP3zfb1Z185XFWnN3J5QAC	17
24	2vazUmgJiDxFfmVDM7X1JmxVwVuowP2Kx48GdBWPgrCpZubbCEmE	1	23167003000001000	23165500000001000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLaXy6GDcDxbJMKZg9iNUagom5xukHoB7UuLqhzh3QQfhTe4ncV	18
25	2vaBW1GDacTe9G1dkUqAeqwmcP8F3wmra81iN73Yo61Z9giMECTw	1	23167003000001000	23165500000001000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKPMux2LPVLyz4UaoxVn7pE2cdRf7nfTXrxzLi745uDyHa8XGCb	18
26	2vbqUbT2knRicd15gfQRyNqwrRhZY3NWSVYmJsZJQ8LPFfLCrhqD	1	23167003000001000	23165500000001000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NL89BVFUVR6h73FJC4zmAud2SZUk1V32xnvbHE8jb3NgBh5LiLP	19
27	2vab9qhDVV15aaxj57vqZdQdHNQwfw7DtYnaUvWmj17B1ri5p7mY	1	23167003000001000	23165500000001000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKe4QPRdpss4gaqutGhrPCMkAyu58jX878ghfg7mhaPJAUjWkya	19
28	2vau171Q9NAc53wFKkbbeWfCiNk2oC58x33q4feTtNdrQVrVpisX	1	23167003000001000	23165500000001000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NL81iiDkRMVSS6wGDiM8P3ypsWPTdpsB3HBdLx3HY6ZG9bAc2R8	20
29	2vc5SE7mLi5KochHf4jvhKR6vULY2bnK7KXUHo7pM5EUwTDi7pak	1	23167003000001000	23165500000001000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKk9bhbvDNA2emVzRMqvFcf4DPmYZabheCvrJrtBd8ZS6osKxzz	21
30	2vbs5YTbVArSnd3PqWBnSdTXnncU82pd59tN7ucMphjRmVN3aMUz	1	23167003000001000	23165500000001000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKk9bhbvDNA2emVzRMqvFcf4DPmYZabheCvrJrtBd8ZS6osKxzz	21
31	2vbsEkmyJRJ27qDqRg5DE8NNPHgQESfAGhJZmRmcBUcPen5GC5rm	1	23167003000001000	23165500000001000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLu5J3xqATNUvdGPft6rFckTbJ5Ebp7vr1C5GYRy7gEM6WisoRn	22
32	2vats8TD5rKAF7SMJ8yDovchckXEZtzVybBv9r83zaHDkY8x6xEk	1	23167003000001000	23165500000001000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLu5J3xqATNUvdGPft6rFckTbJ5Ebp7vr1C5GYRy7gEM6WisoRn	22
33	2vaCA4yJojhZDQJdhfaXoYBiFiSnTfetvuRtAd11dC98Pj9F3tra	1	23167003000001000	23165500000001000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLotpbSFPBTxG6isWU7unKPc3jz8QXYAUNm1D4adhgZ1qqe6So9	23
34	2vbmbUqpjUXLjgFqvBUJMba2bJvKtUDD2WDbJiL39dGMPvF15oW5	1	23167003000001000	23165500000001000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLotpbSFPBTxG6isWU7unKPc3jz8QXYAUNm1D4adhgZ1qqe6So9	23
35	2vbVqAHuZvKug1TQc6RwMikv3aSZT1cqJpJde2jPrVeidcUgBAP8	1	23167003000001000	23165500000001000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLGs1RzqfzqUZ5TRPDepfW8RdPqNFW85HsXTwsx9V9GcR4Msr7s	24
36	2vbxLi5sXfrSRgMWANGJoeFcd7ejZufen13J4pJrBN9RqSsV87h6	1	23167003000001000	23165500000001000	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLGs1RzqfzqUZ5TRPDepfW8RdPqNFW85HsXTwsx9V9GcR4Msr7s	24
\.


--
-- Data for Name: internal_commands; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.internal_commands (id, command_type, receiver_id, fee, hash) FROM stdin;
1	coinbase	2	360000000000	5JuQHxUZDdG2y2hcEt2R3oFy2YRmHE62nssEZYHoZ37TNLCiQRcD
2	coinbase	5	360000000000	5JuPnEhvW9iwrJebMvcLbsRNMiK92k4EijNbNHWH3PHFWnYfWapE
3	fee_transfer	5	10000000000	5JuekWgPQEq8vnubXvVHdBcqdXkXJUAvkfDTcYrBL1jcvPX2CJew
4	fee_transfer	2	10000000000	5JukQcU3ggrWkWXy2q2U8RPjucVCKqEHLNdXFaBL7Nx4kqFAbJ5C
5	fee_transfer	2	5000000000	5JvBfvsbCBabNwtmJt5XQZHp3Gy3nQMkHiBa7pkf427XsktbxBAQ
6	fee_transfer_via_coinbase	6	1000000	5JtmKNC5DLuPjn3484VbyBLrVasmXrSF4jeNg6BmqxgFVxxELu1S
7	coinbase	5	360000000000	5Juzzy1NFVD3RyhaQ6HQUBgyvfhLwvDwCXaHzHtcwCFqGNQkLiJa
8	fee_transfer	6	1000000	5JtmKNC5DLuPjn3484VbyBLrVasmXrSF4jeNg6BmqxgFVxxELu1S
9	fee_transfer	5	9999000000	5JuGM7PaNdyPPFLRYPgTmdbzFZoEVrGn93QNJSoV5othVC7dcVxx
10	coinbase	2	360000000000	5JtbwX1caJtENRueucnnhKWQFfkBvKF5Dv5aYiZU8dkKSavuN3iF
11	fee_transfer	2	9998000000	5JuY7cjnpgBZnKfWMb61V9RZMw9YnsKJNb7EbwFjHhpxJfFJgBkA
12	fee_transfer	6	2000000	5JvPBT86wrrP6Tx6c6tPA1BgftwjtQgMoR9dKeXVS6Giyjenz3xN
13	fee_transfer	5	9998000000	5JutpMdzAnfTun9NNCNk78XUp4u4wnn5mYqB6y55uj336YKHmcJv
14	fee_transfer	6	3000000	5JuzKFHaru8vdxMaaK9ytWnUk96J3UP4GguxNHMoWPUVvHHAPpN2
15	fee_transfer	5	9997000000	5JvQmzDgtukyYxgJFu2GYqtGCTe77f6QE1PuVDsztt2TY24PmGb6
16	fee_transfer	2	9997000000	5JtttJAapNVrWQ9ryvBAPYSD4s3Hks1q2dG96n8hHhNGghVn1i5z
17	fee_transfer	2	4998000000	5JuPqqTTp7g4EruE9yrpc3g8isZ2yLcezL7LgaV3Fqz3Q7VQ1odB
\.


--
-- Data for Name: migration_history; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.migration_history (commit_start_at, protocol_version, migration_version, description, status) FROM stdin;
2026-09-14 15:03:42.12878+00	5.0.0	0.0.1	Created from create_schema.sql	applied
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
2	B62qpA4TVdBDfkJzE99FdQKFmvbakupzVCgj6P5xkFe3o7ywqjKvwQY
3	B62qpBuwgU38Xexzui6CZSVxYwnGx4VG7fFsbket1C4x5arhd5YkKrb
4	B62qppdAK5CwTxWEGPDhXJAdLNLpXazBfDj7KPAoGxx2qb7GnmQ2QmZ
5	B62qpWFo5wpBMbNra3WimcdZtiBreyT145N8MYutVkNnu8mdFCQCsR5
6	B62qjUa8LYjQCLMiZ37hsY43SqcBDuxf7f4rCEQGEEqjvoevtaegYZD
7	B62qrGLXjPCVNLG1o3XvAuLaVALK8hk4Ytq26VPZnpQpkmMEUnGUBoH
8	B62qksNmPw1N6acBCtQj1mu3xmrkWBhyxCAZdHmsY3cfJW1Y5qy6gjD
9	B62qo7Mvxqwc8TaJ1SWLodddd4vaN55h4doT2mzYYrrwAQcwh4tzeep
\.


--
-- Data for Name: snarked_ledger_hashes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.snarked_ledger_hashes (id, value) FROM stdin;
1	jxmyYcnijqX2e4RxMN7AwZHaLo4bJYhoYXCdv6WTEdnLexSMNbu
2	jxcWZ6E6yij3KwFVhDPKF46ymtzo9kfVmXadZxWmWg7w4z8dGEG
3	jxaLog3isnqxYcGveuVJzYtXo2D21BUFsewSXqa2qCyojtj4vSs
4	jw7eXjLwt1ZTJz9Lgye7Ysmm71kyx5Vv8DLZyecJfh7osHuaDQ3
5	jxmKgGRe6RNEGvuLhBBBdaFKWtMjLjDBjRJ5XJNTiPtTrnhvtxv
6	jxjiYerrhhmVtb3BME4YkRHU5iUFY2dWsbkLqYm8YBetJQP5bGj
7	jwKbfL2h3RoYHjnJaBWUtd9CPJ1NDw7LrqRm3CKzs5zWtMWYwrX
8	jxLyDP63gHooadedWf44FApBXzFbMytmD8Bo1j7LY6VbcouP7Ti
9	jw7x93dXshJrt6eEFwg9Df8ib6geRjmsdmXucUKvLhfwieQpMaF
10	jwTxjDk2LRz7QRxaqtruDSHXadVBEKyjrCec29dZpvbWEmrEBSN
11	jxR7PPHg4g2yjfy7RqKfkEhZM46NUwVKFYn5Ap5pgGXGKAQx5Vs
12	jwZLmoydnP8ankgT5bbLKaP3CtTswtgYrU2iTkoD5ycmspNHS3q
13	jwojNUDscTSTwQUJ8RLnWq9HCRa8XGakgSzvmbmbnPQnAGsefGf
14	jwuhnsdzQVSfZ8Ws1mhRLP8PDtgb5V5XwExYado8JdPSvZVHsXa
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
\.


--
-- Data for Name: zkapp_account_update_body; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.zkapp_account_update_body (id, account_identifier_id, update_id, balance_change, increment_nonce, events_id, actions_id, call_data_id, call_depth, zkapp_network_precondition_id, zkapp_account_precondition_id, zkapp_valid_while_precondition_id, use_full_commitment, implicit_account_creation_fee, may_use_token, authorization_kind, verification_key_hash_id) FROM stdin;
1	6	1	-1000000000000	t	\N	\N	1	0	1	1	\N	f	f	No	Signature	\N
2	9	2	999000000000	f	\N	\N	1	0	1	2	\N	t	f	No	Signature	\N
3	6	1	-1000000000	t	\N	\N	1	0	1	1	\N	f	f	No	Signature	\N
4	9	1	1000000000	f	\N	\N	1	0	1	2	\N	f	f	No	None_given	\N
5	9	3	0	f	\N	\N	1	0	1	2	\N	t	f	No	Signature	\N
6	6	1	-1000000000	t	\N	\N	1	0	1	3	\N	f	f	No	Signature	\N
7	9	4	0	f	\N	\N	1	0	1	2	\N	t	f	No	Signature	\N
8	6	1	-1000000000	t	\N	\N	1	0	1	4	\N	f	f	No	Signature	\N
9	9	5	0	f	\N	\N	1	0	1	2	\N	t	f	No	Signature	\N
10	6	1	-1000000000	t	\N	\N	1	0	1	5	\N	f	f	No	Signature	\N
11	9	6	0	f	\N	\N	1	0	1	2	\N	t	f	No	Signature	\N
12	6	1	-1000000000	t	\N	\N	1	0	1	6	\N	f	f	No	Signature	\N
13	9	7	0	f	\N	\N	1	0	1	2	\N	t	f	No	Signature	\N
14	6	1	-1000000000	t	\N	\N	1	0	1	7	\N	f	f	No	Signature	\N
15	9	8	0	f	\N	\N	1	0	1	2	\N	t	f	No	Signature	\N
16	6	1	-1000000000	t	\N	\N	1	0	1	8	\N	f	f	No	Signature	\N
17	9	9	0	f	\N	\N	1	0	1	2	\N	t	f	No	Signature	\N
18	6	1	-1000000000	t	\N	\N	1	0	1	9	\N	f	f	No	Signature	\N
19	9	10	0	f	\N	\N	1	0	1	2	\N	t	f	No	Signature	\N
20	6	1	-1000000000	t	\N	\N	1	0	1	10	\N	f	f	No	Signature	\N
21	9	11	0	f	\N	\N	1	0	1	2	\N	t	f	No	Signature	\N
22	6	1	-1000000000	t	\N	\N	1	0	1	11	\N	f	f	No	Signature	\N
23	9	12	0	f	\N	\N	1	0	1	2	\N	t	f	No	Signature	\N
24	6	1	-1000000000	t	\N	\N	1	0	1	12	\N	f	f	No	Signature	\N
25	9	13	0	f	\N	\N	1	0	1	2	\N	t	f	No	Signature	\N
26	6	1	-1000000000	t	\N	\N	1	0	1	13	\N	f	f	No	Signature	\N
27	9	14	0	f	\N	\N	1	0	1	2	\N	t	f	No	Signature	\N
28	6	1	-1000000000	t	\N	\N	1	0	1	14	\N	f	f	No	Signature	\N
29	9	15	0	f	\N	\N	1	0	1	2	\N	t	f	No	Signature	\N
30	6	1	-1000000000	t	\N	\N	1	0	1	15	\N	f	f	No	Signature	\N
31	9	16	0	f	\N	\N	1	0	1	2	\N	t	f	No	Signature	\N
32	6	1	-1000000000	t	\N	\N	1	0	1	16	\N	f	f	No	Signature	\N
33	9	17	0	f	\N	\N	1	0	1	2	\N	t	f	No	Signature	\N
34	6	1	-1000000000	t	\N	\N	1	0	1	17	\N	f	f	No	Signature	\N
35	9	18	0	f	\N	\N	1	0	1	2	\N	t	f	No	Signature	\N
36	6	1	-1000000000	t	\N	\N	1	0	1	18	\N	f	f	No	Signature	\N
37	9	19	0	f	\N	\N	1	0	1	2	\N	t	f	No	Signature	\N
38	6	1	-1000000000	t	\N	\N	1	0	1	19	\N	f	f	No	Signature	\N
39	9	20	0	f	\N	\N	1	0	1	2	\N	t	f	No	Signature	\N
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
1	1	{1,2}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuhZdU1k4UUs1JPSpxLQKApLRsEvcBjKijbQmXZpQ3DDwUZaJVP
2	2	{3,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvQKJtxAGJsgpA9unq3vaqJRk2MLuibG1MmVGZpfJyb4EMZGvvh
3	3	{5}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtezpXfRpmb2hFfyxjoBQpSDyd2sYA7v1hu4VEBh4mv5svRVzFX
4	4	{6,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju4PehsxVZrTBvQZMN31ryCeDWrosj1bmBqT1Zet2P72mVckRS1
5	5	{7}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuzFmTNySp468WYw26iux1viio3oBiTfMqsiq64tkwZUh1JnBVe
6	6	{8,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuVGaAgo6sMUNmSodsvi6UCSHTmxFHx3mrA1hcDmXVeY7zC4CHZ
7	7	{9}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juuxhtqto4pLWHwye1Cyb9gHZyVPuF9mHvbDZEssfXGtYamJeZ3
8	8	{10,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuZ6DmZWCwBLo6zHZyzgvMMhKfC3LUMpAN25zsMtNLQjipsnj7e
9	9	{11}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuZrJpDLYgvC56119YeGQAXt7pQzLuwYo5kK1968BKPP95KBqdC
10	10	{12,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv42NxpmF8M3kbbcWXaX3L3FBM6HT67b2uxCQWB3CjTBD1HQH64
11	11	{13}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuKp3aBQfAbid1iKFz6FdVFsZbY1FBWNRR54nA92hudjH8WQF4G
12	12	{14,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv6dnkDR29TiQeuqvGZ1Yji5JYfiwMWMS1BhbWr5wj8SBKNwb2i
13	13	{15}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JunmSB4odrYrEPuvKDW1beHhTM7BG9xmUNRwKyoQHEVN2Faucwx
14	14	{16,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvD8GfAUfu5FdGS5Zue8wiz77RB24cqK7APXW8ERgUEhmZFfvJh
15	15	{17}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JubvF5DjGHe91HYhpYzEjMiVqTNRMmZJkZ75vp6onCgbaywd1Hv
16	16	{18,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtnvifmvLcEkmPmkxhFmZNaMSdpDWhUPcejDeQKRtbAfzJjxE6z
17	17	{19}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuQf8X4Nkcho8HL5nRQkqE4coHYZr7GeQZL57rKrfTJ2JEYtKpt
18	18	{20,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JusJYfoPXxTcsSjFUvmQMWkw2mvbnoFdizWXpiZzmith5HHR2dE
19	19	{21}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtvHFnSAHh7QSeCg8gtakZ6NjsDrk6CvWEKCr9RdB2qdDjeuUyB
20	20	{22,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JumqkdU6xrDusBW6EqBHBYkNkqvVRQsRZzjGn5QtWMynBLqyZSJ
21	21	{23}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuysToEN1N4QoKkiSYtrn4rGupVfnpZ2MchFxLXRxj1BMMwi8Qf
22	22	{24,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuzWxStzri6rYa5tciR4cSHRBsfQMNpv6JVH4KMGwjQg3ANYZP7
23	23	{25}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtfSdqv1SWETVx8DTevcDHJbwr36GaVVhnTjFRxwiFywY5vrZ7B
24	24	{26,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuLe23CM9dKXKNDV47EP7nVEGJh23CdrLSFAnkDXXiTFiKUW9RU
25	25	{27}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtz2bFSWXytnUK7BRdpT4mqB5gREUGxLFni4kePGQ6nuS3rY8rq
26	26	{28,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuBZswQ9oNXQdSsveC53HUUEdi1SgRXRfMEZMMf7kRkF1MkAxAw
27	27	{29}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuREUP1DB18skDAuJJZ4tUrxjRBMWM4VPbovuK699GhLXqFx9mb
28	28	{30,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtq4zYDDgDi6FGcp32Ee8LcfPWqH8nt3vLSuAyNGmFCzo6yCNaH
29	29	{31}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju4PSt1qBU9S3GVz5Si2gtReyL15fwwLRc8zbdt1JU8UP5J2fjt
30	30	{32,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtmrJ71PitzLD6cpw3sMpcBuumAyj6AyaDbZ2nahLLGCHfvGAtG
31	31	{33}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv2QGewnqhXYvVy3FpKPVhyxoAtLLGoGhwXAuChgRDMSwNbM77G
32	32	{34,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuomvtudppuyiDALBHSjBFtRoST7b3jPVxbFPDuaeMjRYPyHw2E
33	33	{35}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuHMbE3SzAxeQ5v1orQPVKvydwsaJ9GcnzppnVXgMW6TJyLgv47
34	34	{36,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuyBeJgTWTs8b4r699HWarNLqwGtzhh2U6dfao8cuCcZxZ9Lsih
35	35	{37}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvAnre8jnFvFJ38Vbpqg17Gq5Esgj5hSeTQi4n9fgkyxVcTMd9t
36	36	{38,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtgeMWpe28r56xj2MzPfMnW4q7qVULZBwnNx6JpjLhhLjFBrMvU
37	37	{39}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju6jai4Rpb6i8jZEJy9vusCUNyvrDkUAuXBny9UdkvQHbLj1rCP
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
\.


--
-- Data for Name: zkapp_fee_payer_body; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.zkapp_fee_payer_body (id, public_key_id, fee, valid_until, nonce) FROM stdin;
1	4	5000000000	\N	0
2	4	5000000000	\N	1
3	4	5000000000	\N	2
4	4	5000000000	\N	3
5	4	5000000000	\N	4
6	4	5000000000	\N	5
7	4	5000000000	\N	6
8	4	5000000000	\N	7
9	4	5000000000	\N	8
10	4	5000000000	\N	9
11	4	5000000000	\N	10
12	4	5000000000	\N	11
13	4	5000000000	\N	12
14	4	5000000000	\N	13
15	4	5000000000	\N	14
16	4	5000000000	\N	15
17	4	5000000000	\N	16
18	4	5000000000	\N	17
19	4	5000000000	\N	18
20	4	5000000000	\N	19
21	4	5000000000	\N	20
22	4	5000000000	\N	21
23	4	5000000000	\N	22
24	4	5000000000	\N	23
25	4	5000000000	\N	24
26	4	5000000000	\N	25
27	4	5000000000	\N	26
28	4	5000000000	\N	27
29	4	5000000000	\N	28
30	4	5000000000	\N	29
31	4	5000000000	\N	30
32	4	5000000000	\N	31
33	4	5000000000	\N	32
34	4	5000000000	\N	33
35	4	5000000000	\N	34
36	4	5000000000	\N	35
37	4	5000000000	\N	36
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

SELECT pg_catalog.setval('public.account_identifiers_id_seq', 9, true);


--
-- Name: blocks_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.blocks_id_seq', 35, true);


--
-- Name: epoch_data_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.epoch_data_id_seq', 36, true);


--
-- Name: internal_commands_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.internal_commands_id_seq', 17, true);


--
-- Name: protocol_versions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.protocol_versions_id_seq', 1, true);


--
-- Name: public_keys_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.public_keys_id_seq', 9, true);


--
-- Name: snarked_ledger_hashes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.snarked_ledger_hashes_id_seq', 14, true);


--
-- Name: timing_info_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.timing_info_id_seq', 8, true);


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

SELECT pg_catalog.setval('public.user_commands_id_seq', 1, false);


--
-- Name: voting_for_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.voting_for_id_seq', 1, true);


--
-- Name: zkapp_account_precondition_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_account_precondition_id_seq', 19, true);


--
-- Name: zkapp_account_update_body_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_account_update_body_id_seq', 39, true);


--
-- Name: zkapp_account_update_failures_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_account_update_failures_id_seq', 4, true);


--
-- Name: zkapp_account_update_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_account_update_id_seq', 39, true);


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

SELECT pg_catalog.setval('public.zkapp_commands_id_seq', 37, true);


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

SELECT pg_catalog.setval('public.zkapp_events_id_seq', 1, false);


--
-- Name: zkapp_fee_payer_body_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_fee_payer_body_id_seq', 37, true);


--
-- Name: zkapp_field_array_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_field_array_id_seq', 1, false);


--
-- Name: zkapp_field_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_field_id_seq', 18, true);


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

SELECT pg_catalog.setval('public.zkapp_nonce_bounds_id_seq', 18, true);


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

SELECT pg_catalog.setval('public.zkapp_states_nullable_id_seq', 19, true);


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

SELECT pg_catalog.setval('public.zkapp_updates_id_seq', 20, true);


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
-- Name: migration_history migration_history_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.migration_history
    ADD CONSTRAINT migration_history_pkey PRIMARY KEY (commit_start_at);


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

