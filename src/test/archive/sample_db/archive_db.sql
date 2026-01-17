--
-- PostgreSQL database dump
--

-- Dumped from database version 12.22 (Ubuntu 12.22-0ubuntu0.20.04.4)
-- Dumped by pg_dump version 12.22 (Ubuntu 12.22-0ubuntu0.20.04.4)

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
5	1	36	1	0	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	37	1	36	1	\N
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
3	1	65	1	500000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	66	1	65	1	\N
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
1	1	90	1	5000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	91	1	90	1	\N
139	1	91	1	81	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	92	1	91	1	\N
164	1	92	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	93	1	92	1	\N
199	1	93	1	379	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	94	1	93	1	\N
109	1	94	1	315	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	95	1	94	1	\N
47	1	95	1	226	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	96	1	95	1	\N
214	1	96	1	166	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	97	1	96	1	\N
112	1	97	1	302	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	98	1	97	1	\N
144	1	98	1	269	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	99	1	98	1	\N
178	1	99	1	172	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	100	1	99	1	\N
155	1	100	1	195	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	101	1	100	1	\N
38	1	101	1	243	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	102	1	101	1	\N
80	1	102	1	128	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	103	1	102	1	\N
147	1	103	1	349	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	104	1	103	1	\N
24	1	104	1	87	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	105	1	104	1	\N
126	1	105	1	424	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	106	1	105	1	\N
89	1	106	1	239	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	107	1	106	1	\N
135	1	107	1	316	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	108	1	107	1	\N
194	1	108	1	492	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	109	1	108	1	\N
190	1	109	1	294	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	110	1	109	1	\N
218	1	110	1	191	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	111	1	110	1	\N
93	1	111	1	380	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	112	1	111	1	\N
162	1	112	1	331	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	113	1	112	1	\N
221	1	113	1	459	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	114	1	113	1	\N
205	1	114	1	28	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	115	1	114	1	\N
195	1	115	1	472	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	116	1	115	1	\N
34	1	116	1	119	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	117	1	116	1	\N
213	1	117	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	118	1	117	1	\N
196	1	118	1	41	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	119	1	118	1	\N
104	1	119	1	27	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	120	1	119	1	\N
44	1	120	1	70	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	121	1	120	1	\N
52	1	121	1	337	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	122	1	121	1	\N
114	1	122	1	210	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	123	1	122	1	\N
177	1	123	1	495	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	124	1	123	1	\N
148	1	124	1	144	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	125	1	124	1	\N
100	1	125	1	148	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	126	1	125	1	\N
206	1	126	1	376	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	127	1	126	1	\N
28	1	127	1	329	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	128	1	127	1	\N
173	1	128	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	129	1	128	1	\N
130	1	129	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	130	1	129	1	\N
39	1	130	1	181	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	131	1	130	1	\N
212	1	131	1	200	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
116	1	132	1	159	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	133	1	132	1	\N
48	1	133	1	319	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	134	1	133	1	\N
101	1	134	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	135	1	134	1	\N
203	1	135	1	365	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	136	1	135	1	\N
50	1	136	1	342	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	137	1	136	1	\N
59	1	137	1	237	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	138	1	137	1	\N
150	1	138	1	427	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	139	1	138	1	\N
180	1	139	1	315	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	140	1	139	1	\N
142	1	140	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	141	1	140	1	\N
23	1	141	1	378	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	142	1	141	1	\N
122	1	142	1	420	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	143	1	142	1	\N
115	1	143	1	411	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	144	1	143	1	\N
7	1	144	1	0	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	145	1	144	1	\N
75	1	145	1	172	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	146	1	145	1	\N
77	1	146	1	309	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	147	1	146	1	\N
152	1	147	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	148	1	147	1	\N
120	1	148	1	154	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	149	1	148	1	\N
118	1	149	1	153	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	150	1	149	1	\N
37	1	150	1	47	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	151	1	150	1	\N
168	1	151	1	87	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	152	1	151	1	\N
149	1	152	1	398	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	153	1	152	1	\N
29	1	153	1	452	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	154	1	153	1	\N
8	1	154	1	283	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	155	1	154	1	\N
88	1	155	1	291	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	156	1	155	1	\N
233	1	156	1	367	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	157	1	156	1	\N
83	1	157	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	158	1	157	1	\N
154	1	158	1	311	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	159	1	158	1	\N
175	1	159	1	258	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	160	1	159	1	\N
69	1	160	1	323	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	161	1	160	1	\N
63	1	161	1	405	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	162	1	161	1	\N
189	1	162	1	32	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	163	1	162	1	\N
92	1	163	1	130	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	164	1	163	1	\N
140	1	164	1	234	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	165	1	164	1	\N
17	1	165	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	166	1	165	1	\N
87	1	166	1	481	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	167	1	166	1	\N
183	1	167	1	240	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	167	1	\N
129	1	168	1	314	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	169	1	168	1	\N
2	1	169	1	65500000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	66	1	169	1	\N
193	1	170	1	183	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	171	1	170	1	\N
174	1	171	1	486	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	172	1	171	1	\N
6	1	172	1	11550000000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	145	1	172	1	\N
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
163	1	206	1	190	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	206	1	206	1	\N
192	1	207	1	221	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	207	1	207	1	\N
143	1	208	1	464	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	208	1	208	1	\N
61	1	209	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	209	1	209	1	\N
136	1	210	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	210	1	210	1	\N
71	1	211	1	353	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	211	1	211	1	\N
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
4	1	226	1	11550000000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	37	1	226	1	\N
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
7	2	144	1	360000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	145	1	144	1	\N
5	3	36	1	360000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	37	1	36	1	\N
3	4	65	1	499500000000	2	2n1YzYdgpSKsHUemqXTjquRRAoDyeXKHPd4Axk7t7ZafcvmQws5T	66	1	65	1	\N
7	4	144	1	735500000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	145	1	144	1	\N
4	4	226	1	11549985000000000	3	2n15kp4TN2U6popyTBaHLTr2Jfq8LtYDeKJsBVWnQNkF7xQ14RSV	37	1	226	1	\N
5	5	36	1	735750000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	37	1	36	1	\N
3	5	65	1	499250000000	3	2n27A2y97ntr9sdECG7ZW2fwWCa19PeYD4D8PmZF6E89moXk8PVH	66	1	65	1	\N
4	5	226	1	11549985000000000	3	2n15kp4TN2U6popyTBaHLTr2Jfq8LtYDeKJsBVWnQNkF7xQ14RSV	37	1	226	1	\N
3	6	65	1	498250000000	7	2n2NViyb1VFLjM5piUG1SzfkURQBFpqMKfF5FsoFRGZ21je7pfQX	66	1	65	1	\N
7	6	144	1	401000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	145	1	144	1	\N
4	6	226	1	11549945000000000	11	2n1coa1PUrX4MBu6iBbs3J1J4jnYgb5Do7SrsiSdpnFPQ3Dw6hJu	37	1	226	1	\N
5	7	36	1	1136750000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	37	1	36	1	\N
3	7	65	1	498250000000	7	2n2NViyb1VFLjM5piUG1SzfkURQBFpqMKfF5FsoFRGZ21je7pfQX	66	1	65	1	\N
4	7	226	1	11549945000000000	11	2n1coa1PUrX4MBu6iBbs3J1J4jnYgb5Do7SrsiSdpnFPQ3Dw6hJu	37	1	226	1	\N
3	8	65	1	498000000000	8	2n14vkQGfN4tGEvxFhjDqEegg78tgQn2CCLkQ51XykVCEQrxN8Te	66	1	65	1	\N
7	8	144	1	781250000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	145	1	144	1	\N
4	8	226	1	11549925000000000	15	2n1Yo6ykydmghCVZQvyhoKWNRH41wWStFqTmWHY3Gi13DMpoStxn	37	1	226	1	\N
5	9	36	1	1532500000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	37	1	36	1	\N
3	9	65	1	497500000000	10	2n1TnjzN3Q19fJbHn8CF3pEmXHQphReea9kziuLdYLR97pEBqgdM	66	1	65	1	\N
4	9	226	1	11549910000000000	18	2mzdV8wswvW36FxyrKRaxxzJ34B7Vp7bV8XZaN4cmFhQ2sP59NaH	37	1	226	1	\N
5	10	36	1	1908000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	37	1	36	1	\N
3	10	65	1	497000000000	12	2n17vxw5GmeMb8UUDupCtaRtwN7swHB5GLSpmj9kLdWMKLMZVfPe	66	1	65	1	\N
4	10	226	1	11549895000000000	21	2n22ibbot27YqaqXS2z7Jc7q9LFpfBRFvesv9kjBx97ENPbA84V2	37	1	226	1	\N
5	11	36	1	2309000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	37	1	36	1	\N
3	11	65	1	496000000000	16	2mzb6Jd646nr5hoCDVnRfGbwFxRdoX6FnnPHbRnDNm6vrEAz8k6n	66	1	65	1	\N
4	11	226	1	11549855000000000	29	2n1HmxnokKvWwQuTjcv6sWUgrRbFkqmj8NPwy5geET6sUk9DP5zu	37	1	226	1	\N
5	12	36	1	2684250000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	37	1	36	1	\N
3	12	65	1	495750000000	17	2n2NJ62fqDkqC2BoevpGsisSExy8MBcdy7KiWXgEnmyCudwsCgPt	66	1	65	1	\N
4	12	226	1	11549840000000000	32	2n24eUFx9xjfKZWMYNZX13v6EQhYuDn4wveCqCTE916RAvoH8SgS	37	1	226	1	\N
3	13	65	1	495750000000	17	2n2NJ62fqDkqC2BoevpGsisSExy8MBcdy7KiWXgEnmyCudwsCgPt	66	1	65	1	\N
7	13	144	1	416250000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	145	1	144	1	\N
4	13	226	1	11549840000000000	32	2n24eUFx9xjfKZWMYNZX13v6EQhYuDn4wveCqCTE916RAvoH8SgS	37	1	226	1	\N
5	14	36	1	3105750000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	37	1	36	1	\N
3	14	65	1	494250000000	23	2n1KZXQkiUMKsVNVKXbmX9hFSARH1ToECvHJBWhzWZ9i5acXkosC	66	1	65	1	\N
4	14	226	1	11549780000000000	44	2n1Mx3Ggr2Kf74PX21jv8iUE8zkmvtzu73BPC7t78693AAoy9Pn9	37	1	226	1	\N
5	15	36	1	3486250000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	37	1	36	1	\N
3	15	65	1	493750000000	25	2n1eXNXRcVd3WgaNLX2Ljdyv1peafJWGWxhAV1NRTLrPVK7Ks5jf	66	1	65	1	\N
4	15	226	1	11549760000000000	48	2n1V9mgWhwvqYbfdaunC2iQfyG59XqjxznhJxDFD7xs8Htm8nL8J	37	1	226	1	\N
5	16	36	1	3856500000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	37	1	36	1	\N
3	16	65	1	493500000000	26	2mzdbb4wDVKqqjAJV6V43nkoWndKhgmV3UragCvoaqd8JH7tVtfR	66	1	65	1	\N
4	16	226	1	11549750000000000	50	2n2GohH1AjdMmXffGBuG8nb7wadVSF7sF68YuweC7CXVkt4LN2r1	37	1	226	1	\N
3	17	65	1	493500000000	26	2mzdbb4wDVKqqjAJV6V43nkoWndKhgmV3UragCvoaqd8JH7tVtfR	66	1	65	1	\N
7	17	144	1	390750000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	145	1	144	1	\N
4	17	226	1	11549750000000000	50	2n2GohH1AjdMmXffGBuG8nb7wadVSF7sF68YuweC7CXVkt4LN2r1	37	1	226	1	\N
3	18	65	1	493000000000	28	2mzrRYifZiTVWyNfhnzGY6X9u3zf5UkA1TpU4YXp6L63xjNBGPNp	66	1	65	1	\N
7	18	144	1	766250000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	145	1	144	1	\N
4	18	226	1	11549735000000000	53	2n1J1uNHhhRJzWxDfPt7s7GKXeT3s2Ma4iiJdkWTJKRvhCnaSC5m	37	1	226	1	\N
3	20	65	1	492750000000	29	2n13tKF5D6TBYcVQreL4vqCRX6kqDdLaba8P5HU9Qcp2eg8obHRb	66	1	65	1	\N
7	20	144	1	1141500000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	145	1	144	1	\N
4	20	226	1	11549720000000000	56	2mzmQ3m84CeAFfH3NAQoSYKBBy3raJzjoLg1eQ5P1M6NsqZe9Mho	37	1	226	1	\N
3	22	65	1	491500000000	34	2n1Tm5QAb4LbwaKWYk6GNF4EerQYwQZsDHLpWf44TcaBMybCi2k4	66	1	65	1	\N
7	22	144	1	1912750000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	145	1	144	1	\N
4	22	226	1	11549670000000000	66	2n1Z5RJG9dLr2ytxAZfyuh4VwL4eq3xJDxbRVyp6rzWM7ZijrcQy	37	1	226	1	\N
5	19	36	1	4247250000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	37	1	36	1	\N
3	19	65	1	492750000000	29	2n13tKF5D6TBYcVQreL4vqCRX6kqDdLaba8P5HU9Qcp2eg8obHRb	66	1	65	1	\N
4	19	226	1	11549720000000000	56	2mzmQ3m84CeAFfH3NAQoSYKBBy3raJzjoLg1eQ5P1M6NsqZe9Mho	37	1	226	1	\N
3	21	65	1	492250000000	31	2n249pvQzvrKUYstA3J93uMmuv4xT8mCN4uEMHN2cKTn7Z8qJq9D	66	1	65	1	\N
7	21	144	1	1522000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	145	1	144	1	\N
4	21	226	1	11549700000000000	60	2n17Tnf2ex9G7qR91i4RaT6ThUxrHiMSEEDieckJxaLiSTg4WrAm	37	1	226	1	\N
5	23	36	1	4699500000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	37	1	36	1	\N
3	23	65	1	490500000000	38	2n1Z7JzEnzWBW5NorDhHpydWyLggfnga94CjAPvtev7xiiDmpQ9f	66	1	65	1	\N
4	23	226	1	11549630000000000	74	2n1UzTGLyBd9yNYAs9TufFAtk31N7NbVxeRseKiFB5DcR6oM3Dpv	37	1	226	1	\N
3	24	65	1	490500000000	38	2n1Z7JzEnzWBW5NorDhHpydWyLggfnga94CjAPvtev7xiiDmpQ9f	66	1	65	1	\N
7	24	144	1	2313750000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	145	1	144	1	\N
4	24	226	1	11549630000000000	74	2n1UzTGLyBd9yNYAs9TufFAtk31N7NbVxeRseKiFB5DcR6oM3Dpv	37	1	226	1	\N
3	25	65	1	489750000000	41	2n1NZbjhp8fe3hpkCf7raFFHCKXYEZeNy7BcVupiv9zVTTK5h4Uk	66	1	65	1	\N
7	25	144	1	2709500000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	145	1	144	1	\N
4	25	226	1	11549595000000000	81	2mzw3D868xBUFXpsngWxHyGWmtamC9zVQxtubD1cBXn8jA7kwTQH	37	1	226	1	\N
5	26	36	1	3542500000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	37	1	36	1	\N
3	26	65	1	489750000000	41	2n1NZbjhp8fe3hpkCf7raFFHCKXYEZeNy7BcVupiv9zVTTK5h4Uk	66	1	65	1	\N
4	26	226	1	11549595000000000	81	2mzw3D868xBUFXpsngWxHyGWmtamC9zVQxtubD1cBXn8jA7kwTQH	37	1	226	1	\N
3	27	65	1	488750000000	45	2n1ZU3gZWsf4MhpAbm94AikG5azmrpCDtp5cjXStuZ6eJMyRMP7a	66	1	65	1	\N
7	27	144	1	3105500000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	145	1	144	1	\N
4	27	226	1	11549560000000000	88	2n1c5Zu183c4bSnaYHun5GPLncS4mtmUJsQ4dczWGPJm146qxLsk	37	1	226	1	\N
5	28	36	1	3938500000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	37	1	36	1	\N
3	28	65	1	488750000000	45	2n1ZU3gZWsf4MhpAbm94AikG5azmrpCDtp5cjXStuZ6eJMyRMP7a	66	1	65	1	\N
4	28	226	1	11549560000000000	88	2n1c5Zu183c4bSnaYHun5GPLncS4mtmUJsQ4dczWGPJm146qxLsk	37	1	226	1	\N
5	29	36	1	4319000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	37	1	36	1	\N
3	29	65	1	488250000000	47	2n2PrJzAjpbWWCnn1JjSz7KfpiatT7nLVan3XqaVKjm1UtkgeaYU	66	1	65	1	\N
4	29	226	1	11549540000000000	92	2mzmsTQzBvvL6GPLmwsoA2rU56377YaQ43hQyRXuMpT8yc868fzS	37	1	226	1	\N
3	30	65	1	487500000000	50	2n14iWGxyFfAXieVzJsk4Qo9JnGe6nfC1kxykaFgsYqhjr4mmD7Z	66	1	65	1	\N
7	30	144	1	3516750000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	145	1	144	1	\N
4	30	226	1	11549510000000000	98	2n1kUu2p1gEceE2NYBEgbH1krS9cgdzwcdRBj3iKUatQsjPxzdUq	37	1	226	1	\N
3	31	65	1	487000000000	52	2n1abtRrTHWAxA6hmjtBjzepQPgqmwKjvDj5noiMooXR2ZPLeX1n	66	1	65	1	\N
7	31	144	1	3897250000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	145	1	144	1	\N
4	31	226	1	11549490000000000	102	2n1tsdtUxviNXJC4LtsiPLViyXAD94Ev39PQJvthNXSpzDcmkwzH	37	1	226	1	\N
7	32	144	1	4257250000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	145	1	144	1	\N
3	33	65	1	485500000000	58	2n1NJRdKuZnSnpM8yM5fmoKBWSuPkrZ4m6SqXztmbSqDya7HqL8s	66	1	65	1	\N
1	33	90	1	5013000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	91	1	90	1	\N
7	33	144	1	4673737000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	145	1	144	1	\N
4	33	226	1	11549435000000000	113	2n17bmyBz4RDs46zCwP7P2XzTp8eEMKu6ANmaemX96ZrSpwUwS6X	37	1	226	1	\N
3	34	65	1	484750000000	61	2n2QoMTxEX849Hyq7HBBYq8Tw8ukWk3qXpt2oA1K7QHHA8TyMSRv	66	1	65	1	\N
1	34	90	1	5014000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	91	1	90	1	\N
7	34	144	1	5074486000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	145	1	144	1	\N
4	34	226	1	11549395000000000	121	2mzozpBjQs2HFHZWnRJqEa3JZCw2syjkA3ukg1HXrGUK4jXtcJho	37	1	226	1	\N
5	35	36	1	3525748000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	37	1	36	1	\N
1	35	90	1	5016000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	91	1	90	1	\N
4	35	226	1	11549335000000000	133	2n1cG3qV4sTha8Yw79XLHovosVRXTsU4iCgGa5LGmUqq3mYgiTRZ	37	1	226	1	\N
5	36	36	1	3885747000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	37	1	36	1	\N
1	36	90	1	5017000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	91	1	90	1	\N
1	37	90	1	5017000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	91	1	90	1	\N
7	37	144	1	5494483000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	145	1	144	1	\N
4	37	226	1	11549335000000000	133	2n1cG3qV4sTha8Yw79XLHovosVRXTsU4iCgGa5LGmUqq3mYgiTRZ	37	1	226	1	\N
1	38	90	1	5017000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	91	1	90	1	\N
7	38	144	1	5434485000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	145	1	144	1	\N
5	39	36	1	4245746000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	37	1	36	1	\N
1	39	90	1	5018000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	91	1	90	1	\N
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
22	3NLEygSkSPuXnrZXpp1tdxQBW1syhqrdoAi2ixFDwkMp86pxJFQc	21	3NLgJ6juekbUcC8mA4BgWigmij97HR74jRPvkBg3kqN93CHVjsQ6	145	173	e_-wAnqfw74DfJ-eNL6zqV-sXyGJuAmhGbyJULML-QA=	1	1	23	77	{1,0,1,4,4,4,7,7,7,7,7}	23166005000061388	jx8NyNHeRWTTz19R2J21NTPNVXTNHLdyxVn77o1U7r7YAFy2eAa	14	39	39	1	\N	1763913788000	canonical
20	3NLsfFUAJvk8mZ6JS3q3tGbLjgLVzq1T8hMyMdoHJtwbbFPhzcez	18	3NLV4df2K8sUbF5MXtTSWtFHXAiG3gSwKJj18sF2RetffvKD48WL	145	173	1rFb8r0sB3KIu8uzmoWXYJnimoaHhpQMSLtuiXfeIwg=	1	1	21	77	{1,0,1,4,4,2,7,7,7,7,7}	23166005000061388	jxgNLaxjZp5pSRFeyM59YmnhCmGd1tU9Nwe1kctpHkVGoyDC9w7	12	36	36	1	\N	1763913700178	canonical
18	3NLV4df2K8sUbF5MXtTSWtFHXAiG3gSwKJj18sF2RetffvKD48WL	17	3NLJmt5sVy4JeRqfDt8HKmww4DVjw7DZ7ykbGBt3YbkkHDAxLgwR	145	173	gK-M9kn-QEyzINdXSqs0asoLZ0uEjp1TGDOXOEeSxws=	1	1	19	77	{1,0,1,4,4,1,7,7,7,7,7}	23166005000061388	jwktZ6QU8b3zC9ouEFxiBfe3zV6rMyymd65CeRZaq7b21852oih	11	35	35	1	\N	1763913674549	canonical
2	3NLhvGF3SpUTUBDrb1U8EmVAYY6x1X1PgCjnEDTnXRWxFJjgRhfy	1	3NKTWvnmtKkRFwkfvPrHrKKbGWsiaw4FcQUiG2ZUNJd7NEaGKYvx	145	173	kXhw2nkIp_kdA2qmJjSyIifyexvbTuWhxGDU75-Jlwc=	1	1	3	77	{1,0,1,7,7,7,7,7,7,7,7}	23166005000061388	jxP7NAcepT7Jt1xud389Mk1FJQwkKjPF1zDe1PsBKT9dw8aHvYd	2	19	19	1	\N	1763913188520	orphaned
4	3NK3briV2aPDMjK7iKPGnqqW3KdAKRKAt3f5mfFyZULnXX4UBxA8	2	3NLhvGF3SpUTUBDrb1U8EmVAYY6x1X1PgCjnEDTnXRWxFJjgRhfy	145	173	2l9FTXW-8gFmvwAOdhIUD_fN7IC17SRxAWLKZqmshwk=	1	1	5	77	{1,0,2,7,7,7,7,7,7,7,7}	23166005000061388	jwbi1XaHU26XsvZJpFikTams7Lc8rtLz8yJPPePXbUyLBMuS1JP	3	20	20	1	\N	1763913246729	orphaned
6	3NKUeXXioyFdtUfQh1n6rRHR3fSWpQTLPLoQXcs4mrfTo4qW832W	5	3NKFcqKHq1WYdH43dWSYcBfrQBaJFjxh56Hs573cSzia5B6UPfCy	145	173	nXPDo5exeoukA42WGvgTNA0BQ83zP1hXuNrY24a4pAY=	1	1	7	77	{1,0,1,2,7,7,7,7,7,7,7}	23166005000061388	jxnqmbzyUHp94MaaRnAdSqTfiuT9tqcrS3YpFm7JrCRXtTnCFsD	4	23	23	1	\N	1763913308000	orphaned
8	3NLAQ4dxpno3MFSB4u5Aqxx9L2Ug2v9YXZqRU3SqXf9XuGWGE6rV	6	3NKUeXXioyFdtUfQh1n6rRHR3fSWpQTLPLoQXcs4mrfTo4qW832W	145	173	4OiFtEBe7RWpeOlACC59CdhSAeGuS0MUo5dgN-C_8Ag=	1	1	9	77	{1,0,1,3,7,7,7,7,7,7,7}	23166005000061388	jwwKCjUaGxfyV4Dx7LRYhgcbexF85g1qYBhBKoG44qznAiesp8H	5	24	24	1	\N	1763913346090	orphaned
13	3NLaazZ8nsr7cdfe15pVpZ2AcZ5oSK7cXBeQMSKanb8vwMPq29g2	10	3NLKJaXsPVVuXXogeu5LDw7XeMJNiV5JjyNzcpJp82RaTTzNLrwN	145	173	cBp7-22pYQpzKpGXL9XzgcBXiSjt9ViAxdsFwl7-_A0=	1	1	14	77	{1,0,1,4,1,7,7,7,7,7,7}	23166005000061388	jxXoQBv4yUxmngUyjVYvGSFcVMBosRuU1cF1C2h7Q8wK3zbtkAW	7	29	29	1	\N	1763913488000	orphaned
15	3NK4WL1MxGbG5tWbVrRbcgDqxcrUo7N9UXKvfrHswM5fnDgSSe1E	14	3NK7zMd8uE8zffrcfM4iZpuxE2SPL6dnYaZ5STU92Rp68JATKWCw	37	226	hStM4FH6XXZsLI9cUcBsTFvyMoTXRX28gRA6_ncRfgU=	1	1	16	77	{1,0,1,4,4,7,7,7,7,7,7}	23166005000061388	jxpHkgV48kHCBKAeDj5Enf2mgDm9FFPKemWJ6tqXRynJbUMX1Ff	10	33	33	1	\N	1763913608000	orphaned
14	3NK7zMd8uE8zffrcfM4iZpuxE2SPL6dnYaZ5STU92Rp68JATKWCw	12	3NKwPcss997SNgMWkx3WSEaqqcs1d6x8dKC3DjSKpQstNAEHPCaz	37	226	J_b9UiBX0NwcjLZM6fBGe-Qp9-h_nUuhkJ5bGQp-Tww=	1	1	15	77	{1,0,1,4,3,7,7,7,7,7,7}	23166005000061388	jwQjoJKUdZ5eBmUUuFjbUMY5p2YbradopB9uuTAa3ZTCixbmW5o	9	32	32	1	\N	1763913578000	canonical
12	3NKwPcss997SNgMWkx3WSEaqqcs1d6x8dKC3DjSKpQstNAEHPCaz	11	3NLUPJn3fFzp8XHZBNc2TWbNEgvNfnyyaoJVRStBUW8ovXJZoqqz	37	226	-xnpiKvu2IV-8job8Qkb7msBcnz1sEhInfWuFZinTAM=	1	1	13	77	{1,0,1,4,2,7,7,7,7,7,7}	23166005000061388	jxfHP16VPxZu4yzwpoDU5BH2X2y8nixojtVxf9GoTAUtUKkioqd	8	29	29	1	\N	1763913488000	canonical
11	3NLUPJn3fFzp8XHZBNc2TWbNEgvNfnyyaoJVRStBUW8ovXJZoqqz	10	3NLKJaXsPVVuXXogeu5LDw7XeMJNiV5JjyNzcpJp82RaTTzNLrwN	37	226	otMGXKrW7JpDZNDBMK1ARf6w__RNmsnH6MnnBSHAcQA=	1	1	12	77	{1,0,1,4,1,7,7,7,7,7,7}	23166005000061388	jxEeqbiqWH3sQgCwFaQFbdZFYdVUJSmtbsDpaBBDzxKExz69xUM	7	28	28	1	\N	1763913458000	canonical
10	3NLKJaXsPVVuXXogeu5LDw7XeMJNiV5JjyNzcpJp82RaTTzNLrwN	9	3NKYwiNGdrSFWhm7zc3uYYywegGmD2k8kHuzVNKs3WpFCDfXS6C6	37	226	eG_hRSYIpqU4RZ-OMP6-NdkGsolEFV1Ws00s2e8nFwE=	1	1	11	77	{1,0,1,4,7,7,7,7,7,7,7}	23166005000061388	jwRdZj3xisSygkJfSc2Sd9V894nWVkUeEdaJrv9QDb5W4X1dECC	6	26	26	1	\N	1763913398000	canonical
9	3NKYwiNGdrSFWhm7zc3uYYywegGmD2k8kHuzVNKs3WpFCDfXS6C6	7	3NKvhxKRJF1bPVWm4jUgSk3visRxVFNHE64b7yqRrjTmeXMzncUc	37	226	dTt8LG4nf5oAd6xLoQZU_vpF7Pt9JXUKJCcrlYBTSgA=	1	1	10	77	{1,0,1,3,7,7,7,7,7,7,7}	23166005000061388	jwuroSgY7fMEKvohJ8896QwWR4AMC71sojJFZgphsUyWzWsJqLf	5	25	25	1	\N	1763913368000	canonical
7	3NKvhxKRJF1bPVWm4jUgSk3visRxVFNHE64b7yqRrjTmeXMzncUc	5	3NKFcqKHq1WYdH43dWSYcBfrQBaJFjxh56Hs573cSzia5B6UPfCy	37	226	bV1PJOfx8w_mcN28nTY8q4mPk4vigR52UbS1wPAeIAI=	1	1	8	77	{1,0,1,2,7,7,7,7,7,7,7}	23166005000061388	jxtYEfs879EtDbuWJ66ZbUqrHgoLurDBZPhTeUiADKzExuuxYiB	4	23	23	1	\N	1763913308000	canonical
5	3NKFcqKHq1WYdH43dWSYcBfrQBaJFjxh56Hs573cSzia5B6UPfCy	3	3NKaTb2EEadeFbv9MyCbHZckWvroG9SdtMBdoMB4asExPEy4Vhw3	37	226	tVJ38rRk_BDhE-KjV7PJOiJejz0X_Ckmdsi384BgUgs=	1	1	6	77	{1,0,1,1,7,7,7,7,7,7,7}	23166005000061388	jxmNKD4nzrEs5GMUt3P9zP9NPyoS2AneX3ndjFr8dHNJpUBZWM6	3	21	21	1	\N	1763913248000	canonical
3	3NKaTb2EEadeFbv9MyCbHZckWvroG9SdtMBdoMB4asExPEy4Vhw3	1	3NKTWvnmtKkRFwkfvPrHrKKbGWsiaw4FcQUiG2ZUNJd7NEaGKYvx	37	226	wGDOr5VbJtsFXA_RC6nzIBdi5hquV3ec6C-lWhG5FQo=	1	1	4	77	{1,0,1,7,7,7,7,7,7,7,7}	23166005000061388	jxD3tC4BQ1Kt6gtzEZVrnTyoLrvqjnfMRwM9wmULyGPV372C4bC	2	19	19	1	\N	1763913188357	canonical
1	3NKTWvnmtKkRFwkfvPrHrKKbGWsiaw4FcQUiG2ZUNJd7NEaGKYvx	\N	3NLfcWNw4jG14R7S9VjvvcR6tQupRoUwWY3QHSvDPVMNr3hFx54p	1	1	39cyg4ZmMtnb_aFUIerNAoAJV8qtkfOpq0zFzPspjgM=	1	1	2	77	{1,7,7,7,7,7,7,7,7,7,7}	23166005000061388	jx8Z1HuU1gWjC9rAdvvYfZnVX1F6BsLJfh8yLCgT6sA9driPpCm	1	0	0	1	\N	1763912618000	canonical
16	3NKVZcPMxq7EVhvQzWzX7NiuPdn1qEuE82HfPQBMSQkkR6dd1Z5e	15	3NK4WL1MxGbG5tWbVrRbcgDqxcrUo7N9UXKvfrHswM5fnDgSSe1E	37	226	bo7kPcFDl3hWsmg_3_UQg6J9ytt4tBKtJhJGgz2kigw=	1	1	17	77	{1,0,1,4,5,7,7,7,7,7,7}	23166005000061388	jwUs7hXAi1Hkdo4ABmAURVUU9yHQ1NgCojMDyxyMsRnEbhoSViZ	11	34	34	1	\N	1763913638000	orphaned
19	3NLyCvyHH9bc6N7PRnG21LfMbKouhWXMht9qNniwkQUGPVCT4WzN	16	3NKVZcPMxq7EVhvQzWzX7NiuPdn1qEuE82HfPQBMSQkkR6dd1Z5e	37	226	x2ck3e_gcGtVr-ELNZVo1G2AdCbYA5Peh3xtGZPYNAU=	1	1	20	77	{1,0,1,4,5,1,7,7,7,7,7}	23166005000061388	jwPZ2wenxncvTvUCRnHJTQaJ8rWr9txH5kBY5NZDWqB8F65xwau	12	36	36	1	\N	1763913698000	orphaned
23	3NLBJuY1PHXkmPXavFSArSu7R2hRxjo1nB1RXpuPd92QMrTWbza2	19	3NLyCvyHH9bc6N7PRnG21LfMbKouhWXMht9qNniwkQUGPVCT4WzN	37	226	pXb_7IBBBChnap7JUA3r0LMgby6JmednEgov3j1ehgg=	1	1	24	77	{1,0,1,4,5,2,7,7,7,7,7}	23166005000061388	jxnhL6x3LfsbVrZirtz2qm4VPueguhyC86usfC4wnTt96LsGdmy	13	41	41	1	\N	1763913848000	orphaned
26	3NKEDV2kuqgRRtZuyyyLiUVizwKqQbphbdTzRhX8C2wNKdGEVUou	22	3NLEygSkSPuXnrZXpp1tdxQBW1syhqrdoAi2ixFDwkMp86pxJFQc	37	226	HZaRXbbz1wLcW91r0sASdVq6wSYfhIma446G_8OpiQM=	1	1	27	77	{1,0,1,4,4,4,1,7,7,7,7}	23166005000061388	jxny9DShp1paQ5fKJARhyYHuvS9jswRu2xPReHanShK2t1J4GgZ	15	43	43	1	\N	1763913908000	orphaned
28	3NLF8ftXJP5cPuTkk4YWvKCLoZ48W1pTBTSBPW5jgfgnSsscxAFE	26	3NKEDV2kuqgRRtZuyyyLiUVizwKqQbphbdTzRhX8C2wNKdGEVUou	37	226	VAufdoM46a3GKldWQ999y7KXZY_T1T1G3QbiJ2QEjgg=	1	1	29	77	{1,0,1,4,4,4,2,7,7,7,7}	23166005000061388	jxQ2WZs6Z4L6jZYncVr1ezq4CgmT4zEgJn4RzYmturkiDiN6SYX	16	45	45	1	\N	1763913968000	orphaned
29	3NLbdywzHkJdm5C4PgNX1MCbTgbck7CkEKcRhrndMBZrbXiAiZyL	28	3NLF8ftXJP5cPuTkk4YWvKCLoZ48W1pTBTSBPW5jgfgnSsscxAFE	37	226	bOfY_6A7WW0zhg8hjwpYzYuuUXAKIfv-gowuTqPtdQ4=	1	1	30	77	{1,0,1,4,4,4,3,7,7,7,7}	23166005000061388	jwhcuxcyqaf4BvSTxMmTWXdpmwGmyM7o7ssZGTBBcx1yhgsnZg4	17	46	46	1	\N	1763914007836	orphaned
34	3NLDs1gcbvS7CTreCh546UnA7DS9e7ojj8vqooEBAV7VSyb8nUDU	33	3NLuQRUVtDvN3s7bFpwbcxsrzUUb7hC3sUPHh4pAKp7T9xVWJ1vB	145	173	Ts3zzm4pi_pdpkGsbStZXLbLgr9axFmRT0-ykv9OkgM=	1	1	35	77	{1,0,1,4,4,5,3,4,7,7,7}	23166005000061388	jwL3bXWxt4HSbG6n9hV9dj66EW8XjLKNuTxwmqP51pBHpCChz3T	22	54	54	1	\N	1763914238000	canonical
33	3NLuQRUVtDvN3s7bFpwbcxsrzUUb7hC3sUPHh4pAKp7T9xVWJ1vB	32	3NL4zrGVDVde42ALRpM4RDJ2RJp9q51dt8v9K6pns1TNd3ypFEre	145	173	i5Y7GYTKPyfCS1L7ZyOentJzHzBl7V3cXe1AJIwMQAY=	1	1	34	77	{1,0,1,4,4,5,3,3,7,7,7}	23166005000061388	jwwEcVUMiSDmoZoFh8hQsA8shUN54MtZpnaf9KMucJ2tsjwyC2f	21	52	52	1	\N	1763914178000	canonical
32	3NL4zrGVDVde42ALRpM4RDJ2RJp9q51dt8v9K6pns1TNd3ypFEre	31	3NK63JEKx6SXBXokXt2aevw1yHCPx9krfdc9uCZsSMf4tBxtj7W8	145	173	iYcJXyb0jqSZiERxlAR9srdBIylYoBnqoiuQPb8t-AY=	1	1	33	77	{1,0,1,4,4,5,3,2,7,7,7}	23166005000061388	jwPB9sw7PB3DZVrE6DqjPd3uv4KN8aLfppFFhd2UYCsPMyZ6NbC	20	50	50	1	\N	1763914118000	canonical
31	3NK63JEKx6SXBXokXt2aevw1yHCPx9krfdc9uCZsSMf4tBxtj7W8	30	3NL1NHkcyUpTpTLSg89Fg7Y74kCsYY5Zp8BsLnjBrCSbu1aEDb5Z	145	173	WHf29NONa2iWs8QaYYYxal0qY_ehMgvHiEMACjstpQ4=	1	1	32	77	{1,0,1,4,4,5,3,1,7,7,7}	23166005000061388	jxBowVh9bYFpJV15wVt9WMxx4R5ETahpEodVBCuzhqQc3baDQBz	19	49	49	1	\N	1763914088000	canonical
30	3NL1NHkcyUpTpTLSg89Fg7Y74kCsYY5Zp8BsLnjBrCSbu1aEDb5Z	27	3NKkZf5Y3voo7JDbtrgFVhUdi5kY3EX1jDAKnKHNAJerQm4VG7K6	145	173	WcP8UJxs-WyRxFqWmH_a9OkFfclBemvTFU7EKFBVRAs=	1	1	31	77	{1,0,1,4,4,5,3,7,7,7,7}	23166005000061388	jwTHgUeATSTodHwHb85sDePgQ8rhojjo2B9m7wdDSxe1VMvXS7q	18	48	48	1	\N	1763914058000	canonical
27	3NKkZf5Y3voo7JDbtrgFVhUdi5kY3EX1jDAKnKHNAJerQm4VG7K6	25	3NKKZ2pdhtzwwHxJx2RXEkNH9oumF3BMGrmdqEKLV3rkqJdVU1Po	145	173	Iib6zfC__E5cZh3DLqO6u3iNLTqBnzbrKy_i8QTfuQ4=	1	1	28	77	{1,0,1,4,4,5,2,7,7,7,7}	23166005000061388	jxEEAX7qB6zbXRV3jS1QLNRvKeR2Kobbck1WT8pfwmqKUw1F8Xv	17	45	45	1	\N	1763913968000	canonical
25	3NKKZ2pdhtzwwHxJx2RXEkNH9oumF3BMGrmdqEKLV3rkqJdVU1Po	24	3NLx1M28R8QYovrkucPyvmiLywPj6ytCreaZTAkuW8N18L5wYkNN	145	173	SrJ6lUle0aG3fwRG8mAOIUIeeTkxL5K9k2YqaMXEgg4=	1	1	26	77	{1,0,1,4,4,5,1,7,7,7,7}	23166005000061388	jxw57zQR6ZK9SrD8ci9THL2PC64dQQA6LFwTSQnQopsdBd4u9wp	16	43	43	1	\N	1763913908000	canonical
24	3NLx1M28R8QYovrkucPyvmiLywPj6ytCreaZTAkuW8N18L5wYkNN	22	3NLEygSkSPuXnrZXpp1tdxQBW1syhqrdoAi2ixFDwkMp86pxJFQc	145	173	GuvBBagEqpBEDh_Vl70E9TSKjxg4cMPMJAdSCQTDWgY=	1	1	25	77	{1,0,1,4,4,5,7,7,7,7,7}	23166005000061388	jwpHH7P83BmN1MEoiHMcf6ugWGe9o5vQnFtJzhNjgfKkH8zYScZ	15	41	41	1	\N	1763913848000	canonical
21	3NLgJ6juekbUcC8mA4BgWigmij97HR74jRPvkBg3kqN93CHVjsQ6	20	3NLsfFUAJvk8mZ6JS3q3tGbLjgLVzq1T8hMyMdoHJtwbbFPhzcez	145	173	HQed6wybJRNuo9kqDoe1P1r_l-672RBvwdwRXZGrXAE=	1	1	22	77	{1,0,1,4,4,3,7,7,7,7,7}	23166005000061388	jxZigX2RjBaRaVzuYzjjcHWbxvJRNuMcqyT2ZYmxDcsLN8NpZRw	13	37	37	1	\N	1763913738928	canonical
17	3NLJmt5sVy4JeRqfDt8HKmww4DVjw7DZ7ykbGBt3YbkkHDAxLgwR	14	3NK7zMd8uE8zffrcfM4iZpuxE2SPL6dnYaZ5STU92Rp68JATKWCw	145	173	8UpW0tejn6tvBXoU6kzEsGHYZjxgB20K0BGZHvfNAgA=	1	1	18	77	{1,0,1,4,4,7,7,7,7,7,7}	23166005000061388	jwJFq95xie6Ff7tX3cd221EJSzWrEdpyD4UmxcH5Myy7MLyxuE1	10	34	34	1	\N	1763913638000	canonical
36	3NK56TD3efj9BU3DsXeRYV6vAUrNkkw2iFv2FoWet1oyFfTRmBAc	35	3NL92EouWZR34WcaC2BRZq5778NwCLZ4u8EVBSXdni3gBY4H7dj6	37	226	dQln7L5fnhANiwyVkI2cWOe2cW_ho8sJ80Kwgk2VIA4=	1	1	37	77	{1,0,1,4,4,5,3,4,2,7,7}	23166005000061388	jxPKZeJtMpxEmDEh8iTwi3GA9cmKjyj4HNB5cjsJQ4gvvG1b29L	24	58	58	1	\N	1763914358000	orphaned
37	3NKmjzoDotXj1AnwRjJ9AGKJnDaN8sQ3y45f6rrja8rmmwy5a1TQ	34	3NLDs1gcbvS7CTreCh546UnA7DS9e7ojj8vqooEBAV7VSyb8nUDU	145	173	P74OT0zpKKUbkWRahpAjBgdtnCswc7jqGXPLDVATHw4=	1	1	38	77	{1,0,1,4,4,5,3,4,1,7,7}	23166005000061388	jwJ9P7wxT2AbMdHn4tsYYgpqiVgDFHstTrEoEpqbMXXsgXbGV8S	23	58	58	1	\N	1763914358000	orphaned
38	3NLTz4T69ojuBBmmAmqYGBnXgNBR4MQwbq2bkqhQJZjRr9SM8TEt	35	3NL92EouWZR34WcaC2BRZq5778NwCLZ4u8EVBSXdni3gBY4H7dj6	145	173	aY4DqAOSxnoli3anFZ5IOcytZ79dKowU0XWAkSmQzAM=	1	1	39	77	{1,0,1,4,4,5,3,4,2,7,7}	23166005000061388	jwVeArimK7JdutW1UFPP4Yda6Uc3spvTrNg1jwzffv9bcknpD2d	24	59	59	1	\N	1763914398709	orphaned
39	3NKngPyEaCp1bSk6sT5xBME3YbkhPtLF1XBhbzxaPf2Z6hAp1zUk	36	3NK56TD3efj9BU3DsXeRYV6vAUrNkkw2iFv2FoWet1oyFfTRmBAc	37	226	KWSMmRA1nXsl91nPlyze8e2PKdTaZY0BqHGHzG_flAs=	1	1	40	77	{1,0,1,4,4,5,3,4,3,7,7}	23166005000061388	jxxbaTQntP6QZoJr3GJrHtntphzxdJV3Pw2xUJbRtSCyUgD56Ga	25	60	60	1	\N	1763914418000	canonical
35	3NL92EouWZR34WcaC2BRZq5778NwCLZ4u8EVBSXdni3gBY4H7dj6	34	3NLDs1gcbvS7CTreCh546UnA7DS9e7ojj8vqooEBAV7VSyb8nUDU	37	226	GwJ3Y5FWtzD2OatO9HNQFFlGd3Oly6v5IklabiBKFQo=	1	1	36	77	{1,0,1,4,4,5,3,4,1,7,7}	23166005000061388	jwgrCvMPbv8cEokLLPHrQn8uCpixTytEXBL4F6iQSTiU5g3ASi3	23	57	57	1	\N	1763914328000	canonical
\.


--
-- Data for Name: blocks_internal_commands; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.blocks_internal_commands (block_id, internal_command_id, sequence_no, secondary_sequence_no, status, failure_reason) FROM stdin;
2	1	0	0	applied	\N
3	2	0	0	applied	\N
4	1	5	0	applied	\N
4	3	6	0	applied	\N
5	2	6	0	applied	\N
5	4	7	0	applied	\N
6	1	12	0	applied	\N
6	5	13	0	applied	\N
7	2	12	0	applied	\N
7	6	13	0	applied	\N
8	1	5	0	applied	\N
8	7	6	0	applied	\N
9	2	10	0	applied	\N
9	8	11	0	applied	\N
10	2	5	0	applied	\N
10	9	6	0	applied	\N
11	2	12	0	applied	\N
11	6	13	0	applied	\N
12	2	4	0	applied	\N
12	10	5	0	applied	\N
13	1	16	0	applied	\N
13	11	17	0	applied	\N
14	12	1	0	applied	\N
14	2	19	0	applied	\N
14	13	20	0	applied	\N
15	2	6	0	applied	\N
15	14	7	0	applied	\N
16	2	3	0	applied	\N
16	15	4	0	applied	\N
17	1	9	0	applied	\N
17	16	10	0	applied	\N
18	1	5	0	applied	\N
18	3	6	0	applied	\N
19	2	9	0	applied	\N
19	17	10	0	applied	\N
20	1	4	0	applied	\N
20	18	5	0	applied	\N
21	1	6	0	applied	\N
21	19	7	0	applied	\N
22	1	9	0	applied	\N
22	16	10	0	applied	\N
23	20	20	0	applied	\N
23	2	28	0	applied	\N
23	21	29	0	applied	\N
24	22	1	0	applied	\N
24	1	13	0	applied	\N
24	23	14	0	applied	\N
25	1	10	0	applied	\N
25	24	11	0	applied	\N
26	12	1	0	applied	\N
26	2	23	0	applied	\N
26	25	24	0	applied	\N
27	1	11	0	applied	\N
27	23	12	0	applied	\N
28	2	11	0	applied	\N
28	26	12	0	applied	\N
29	2	6	0	applied	\N
29	14	7	0	applied	\N
30	1	15	0	applied	\N
30	27	16	0	applied	\N
31	1	6	0	applied	\N
31	19	7	0	applied	\N
32	1	0	0	applied	\N
33	28	17	0	applied	\N
33	29	17	0	applied	\N
33	30	18	0	applied	\N
33	31	18	1	applied	\N
34	28	11	0	applied	\N
34	29	11	0	applied	\N
34	32	12	0	applied	\N
35	28	12	0	applied	\N
35	33	12	0	applied	\N
35	34	13	0	applied	\N
35	35	13	1	applied	\N
36	28	0	0	applied	\N
36	33	0	0	applied	\N
37	28	12	0	applied	\N
37	29	12	0	applied	\N
37	36	13	0	applied	\N
37	37	13	1	applied	\N
38	28	0	0	applied	\N
38	29	0	0	applied	\N
39	28	0	0	applied	\N
39	33	0	0	applied	\N
\.


--
-- Data for Name: blocks_user_commands; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.blocks_user_commands (block_id, user_command_id, sequence_no, status, failure_reason) FROM stdin;
4	1	3	applied	\N
4	2	4	applied	\N
5	1	3	applied	\N
5	2	4	applied	\N
5	3	5	applied	\N
6	4	8	applied	\N
6	5	9	applied	\N
6	6	10	applied	\N
6	7	11	applied	\N
7	4	8	applied	\N
7	5	9	applied	\N
7	6	10	applied	\N
7	7	11	applied	\N
8	8	4	applied	\N
9	8	7	applied	\N
9	9	8	applied	\N
9	10	9	applied	\N
10	11	3	applied	\N
10	12	4	applied	\N
11	13	8	applied	\N
11	14	9	applied	\N
11	15	10	applied	\N
11	16	11	applied	\N
12	17	3	applied	\N
13	13	11	applied	\N
13	14	12	applied	\N
13	15	13	applied	\N
13	16	14	applied	\N
13	17	15	applied	\N
14	18	13	applied	\N
14	19	14	applied	\N
14	20	15	applied	\N
14	21	16	applied	\N
14	22	17	applied	\N
14	23	18	applied	\N
15	24	4	applied	\N
15	25	5	applied	\N
16	26	2	applied	\N
17	24	6	applied	\N
17	25	7	applied	\N
17	26	8	applied	\N
18	27	3	applied	\N
18	28	4	applied	\N
19	27	6	applied	\N
19	28	7	applied	\N
19	29	8	applied	\N
20	29	3	applied	\N
21	30	4	applied	\N
21	31	5	applied	\N
22	32	6	applied	\N
22	33	7	applied	\N
22	34	8	applied	\N
23	30	18	applied	\N
23	31	19	applied	\N
23	32	21	applied	\N
23	33	22	applied	\N
23	34	23	applied	\N
23	35	24	applied	\N
23	36	25	applied	\N
23	37	26	applied	\N
23	38	27	applied	\N
24	35	9	applied	\N
24	36	10	applied	\N
24	37	11	applied	\N
24	38	12	applied	\N
25	39	7	applied	\N
25	40	8	applied	\N
25	41	9	applied	\N
26	35	16	applied	\N
26	36	17	applied	\N
26	37	18	applied	\N
26	38	19	applied	\N
26	39	20	applied	\N
26	40	21	applied	\N
26	41	22	applied	\N
27	42	7	applied	\N
27	43	8	applied	\N
27	44	9	applied	\N
27	45	10	applied	\N
28	42	7	applied	\N
28	43	8	applied	\N
28	44	9	applied	\N
28	45	10	applied	\N
29	46	4	applied	\N
29	47	5	applied	\N
30	46	10	applied	\N
30	47	11	applied	\N
30	48	12	applied	\N
30	49	13	applied	\N
30	50	14	applied	\N
31	51	4	applied	\N
31	52	5	applied	\N
33	53	11	applied	\N
33	54	12	applied	\N
33	55	13	applied	\N
33	56	14	applied	\N
33	57	15	applied	\N
33	58	16	applied	\N
34	59	8	applied	\N
34	60	9	applied	\N
34	61	10	applied	\N
\.


--
-- Data for Name: blocks_zkapp_commands; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.blocks_zkapp_commands (block_id, zkapp_command_id, sequence_no, status, failure_reasons_ids) FROM stdin;
4	1	0	failed	{1,2}
4	2	1	failed	{3,2}
4	3	2	failed	{4}
5	1	0	failed	{1,2}
5	2	1	failed	{3,2}
5	3	2	failed	{4}
6	4	0	failed	{3,2}
6	5	1	failed	{4}
6	6	2	failed	{3,2}
6	7	3	failed	{4}
6	8	4	failed	{3,2}
6	9	5	failed	{4}
6	10	6	failed	{3,2}
6	11	7	failed	{4}
7	4	0	failed	{3,2}
7	5	1	failed	{4}
7	6	2	failed	{3,2}
7	7	3	failed	{4}
7	8	4	failed	{3,2}
7	9	5	failed	{4}
7	10	6	failed	{3,2}
7	11	7	failed	{4}
8	12	0	failed	{3,2}
8	13	1	failed	{4}
8	14	2	failed	{3,2}
8	15	3	failed	{4}
9	12	0	failed	{3,2}
9	13	1	failed	{4}
9	14	2	failed	{3,2}
9	15	3	failed	{4}
9	16	4	failed	{3,2}
9	17	5	failed	{4}
9	18	6	failed	{3,2}
10	19	0	failed	{4}
10	20	1	failed	{3,2}
10	21	2	failed	{4}
11	22	0	failed	{3,2}
11	23	1	failed	{4}
11	24	2	failed	{3,2}
11	25	3	failed	{4}
11	26	4	failed	{3,2}
11	27	5	failed	{4}
11	28	6	failed	{3,2}
11	29	7	failed	{4}
12	30	0	failed	{3,2}
12	31	1	failed	{4}
12	32	2	failed	{3,2}
13	22	0	failed	{3,2}
13	23	1	failed	{4}
13	24	2	failed	{3,2}
13	25	3	failed	{4}
13	26	4	failed	{3,2}
13	27	5	failed	{4}
13	28	6	failed	{3,2}
13	29	7	failed	{4}
13	30	8	failed	{3,2}
13	31	9	failed	{4}
13	32	10	failed	{3,2}
14	33	0	failed	{4}
14	34	2	failed	{3,2}
14	35	3	failed	{4}
14	36	4	failed	{3,2}
14	37	5	failed	{4}
14	38	6	failed	{3,2}
14	39	7	failed	{4}
14	40	8	failed	{3,2}
14	41	9	failed	{4}
14	42	10	failed	{3,2}
14	43	11	failed	{4}
14	44	12	failed	{3,2}
15	45	0	failed	{4}
15	46	1	failed	{3,2}
15	47	2	failed	{4}
15	48	3	failed	{3,2}
16	49	0	failed	{4}
16	50	1	failed	{3,2}
17	45	0	failed	{4}
17	46	1	failed	{3,2}
17	47	2	failed	{4}
17	48	3	failed	{3,2}
17	49	4	failed	{4}
17	50	5	failed	{3,2}
18	51	0	failed	{4}
18	52	1	failed	{3,2}
18	53	2	failed	{4}
19	51	0	failed	{4}
19	52	1	failed	{3,2}
19	53	2	failed	{4}
19	54	3	failed	{3,2}
19	55	4	failed	{4}
19	56	5	failed	{3,2}
20	54	0	failed	{3,2}
20	55	1	failed	{4}
20	56	2	failed	{3,2}
21	57	0	failed	{4}
21	58	1	failed	{3,2}
21	59	2	failed	{4}
21	60	3	failed	{3,2}
22	61	0	failed	{4}
22	62	1	failed	{3,2}
22	63	2	failed	{4}
22	64	3	failed	{3,2}
22	65	4	failed	{4}
22	66	5	failed	{3,2}
23	57	0	failed	{4}
23	58	1	failed	{3,2}
23	59	2	failed	{4}
23	60	3	failed	{3,2}
23	61	4	failed	{4}
23	62	5	failed	{3,2}
23	63	6	failed	{4}
23	64	7	failed	{3,2}
23	65	8	failed	{4}
23	66	9	failed	{3,2}
23	67	10	failed	{4}
23	68	11	failed	{3,2}
23	69	12	failed	{4}
23	70	13	failed	{3,2}
23	71	14	failed	{4}
23	72	15	failed	{3,2}
23	73	16	failed	{4}
23	74	17	failed	{3,2}
24	67	0	failed	{4}
24	68	2	failed	{3,2}
24	69	3	failed	{4}
24	70	4	failed	{3,2}
24	71	5	failed	{4}
24	72	6	failed	{3,2}
24	73	7	failed	{4}
24	74	8	failed	{3,2}
25	75	0	failed	{4}
25	76	1	failed	{3,2}
25	77	2	failed	{4}
25	78	3	failed	{3,2}
25	79	4	failed	{4}
25	80	5	failed	{3,2}
25	81	6	failed	{4}
26	67	0	failed	{4}
26	68	2	failed	{3,2}
26	69	3	failed	{4}
26	70	4	failed	{3,2}
26	71	5	failed	{4}
26	72	6	failed	{3,2}
26	73	7	failed	{4}
26	74	8	failed	{3,2}
26	75	9	failed	{4}
26	76	10	failed	{3,2}
26	77	11	failed	{4}
26	78	12	failed	{3,2}
26	79	13	failed	{4}
26	80	14	failed	{3,2}
26	81	15	failed	{4}
27	82	0	failed	{3,2}
27	83	1	failed	{4}
27	84	2	failed	{3,2}
27	85	3	failed	{4}
27	86	4	failed	{3,2}
27	87	5	failed	{4}
27	88	6	failed	{3,2}
28	82	0	failed	{3,2}
28	83	1	failed	{4}
28	84	2	failed	{3,2}
28	85	3	failed	{4}
28	86	4	failed	{3,2}
28	87	5	failed	{4}
28	88	6	failed	{3,2}
29	89	0	failed	{4}
29	90	1	failed	{3,2}
29	91	2	failed	{4}
29	92	3	failed	{3,2}
30	89	0	failed	{4}
30	90	1	failed	{3,2}
30	91	2	failed	{4}
30	92	3	failed	{3,2}
30	93	4	failed	{4}
30	94	5	failed	{3,2}
30	95	6	failed	{4}
30	96	7	failed	{3,2}
30	97	8	failed	{4}
30	98	9	failed	{3,2}
31	99	0	failed	{4}
31	100	1	failed	{3,2}
31	101	2	failed	{4}
31	102	3	failed	{3,2}
33	103	0	failed	{4}
33	104	1	failed	{3,2}
33	105	2	failed	{4}
33	106	3	failed	{3,2}
33	107	4	failed	{4}
33	108	5	failed	{3,2}
33	109	6	failed	{4}
33	110	7	failed	{3,2}
33	111	8	failed	{4}
33	112	9	failed	{3,2}
33	113	10	failed	{4}
34	114	0	failed	{3,2}
34	115	1	failed	{4}
34	116	2	failed	{3,2}
34	117	3	failed	{4}
34	118	4	failed	{3,2}
34	119	5	failed	{4}
34	120	6	failed	{3,2}
34	121	7	failed	{4}
35	122	0	failed	{3,2}
35	123	1	failed	{4}
35	124	2	failed	{3,2}
35	125	3	failed	{4}
35	126	4	failed	{3,2}
35	127	5	failed	{4}
35	128	6	failed	{3,2}
35	129	7	failed	{4}
35	130	8	failed	{3,2}
35	131	9	failed	{4}
35	132	10	failed	{3,2}
35	133	11	failed	{4}
37	122	0	failed	{3,2}
37	123	1	failed	{4}
37	124	2	failed	{3,2}
37	125	3	failed	{4}
37	126	4	failed	{3,2}
37	127	5	failed	{4}
37	128	6	failed	{3,2}
37	129	7	failed	{4}
37	130	8	failed	{3,2}
37	131	9	failed	{4}
37	132	10	failed	{3,2}
37	133	11	failed	{4}
\.


--
-- Data for Name: epoch_data; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.epoch_data (id, seed, ledger_hash_id, total_currency, start_checkpoint, lock_checkpoint, epoch_length) FROM stdin;
1	2va9BGv9JrLTtrzZttiEMDYw1Zj6a6EHzXjmP9evHDTG3oEquURA	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	1
2	2vafPBQ3zQdHUEDDnFGuiNvJz7s2MhTLJgSzQSnu5fnZavT27cms	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLfcWNw4jG14R7S9VjvvcR6tQupRoUwWY3QHSvDPVMNr3hFx54p	2
3	2vaFCA2MacowMVur1B9rr2g79n42ZiN748Lfpv1Bwt1mT8DK91U3	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKTWvnmtKkRFwkfvPrHrKKbGWsiaw4FcQUiG2ZUNJd7NEaGKYvx	3
4	2vbvF9BocNJMwv729NaPuzsarbVRBP4d7vw2j3xJx4JU5WSHZH2Q	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKTWvnmtKkRFwkfvPrHrKKbGWsiaw4FcQUiG2ZUNJd7NEaGKYvx	3
5	2vbcDhsAe8yWZRUaJm489gKNtpWSoZ3VKnZWX83ieCjxQFiBjAjy	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLhvGF3SpUTUBDrb1U8EmVAYY6x1X1PgCjnEDTnXRWxFJjgRhfy	4
6	2vaAcy96ghFTS4h3mr8WyusWTdXtecQCEVMzGpCGTUEnzqatx2eg	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKaTb2EEadeFbv9MyCbHZckWvroG9SdtMBdoMB4asExPEy4Vhw3	4
7	2vaJXxySGkkt4D1z8f4DnKk6rpQ37NwpGHYp19vpDT677M4pm5mf	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKFcqKHq1WYdH43dWSYcBfrQBaJFjxh56Hs573cSzia5B6UPfCy	5
8	2vad93Xcee2QmUiSLRzuNyE4qmvM39Yw2qV91RVhfe2eVN6AEUP9	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKFcqKHq1WYdH43dWSYcBfrQBaJFjxh56Hs573cSzia5B6UPfCy	5
9	2vaUxAAuQut687cEfrWqUeQLtepEFHcMSE4tgRWTLovJ3aYEhdEF	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKUeXXioyFdtUfQh1n6rRHR3fSWpQTLPLoQXcs4mrfTo4qW832W	6
10	2vai4rNuFJF1wCJQPDmymf9LzTJ9P5tnsdfbnco4p8hmeSJWUD3U	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKvhxKRJF1bPVWm4jUgSk3visRxVFNHE64b7yqRrjTmeXMzncUc	6
11	2vaHEiXB8yj6B5C2d9rmKaVkc6Tmsc4UxXAxqpK6PmdJbeTx1fs7	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKYwiNGdrSFWhm7zc3uYYywegGmD2k8kHuzVNKs3WpFCDfXS6C6	7
12	2vahR8Yugh1Y8qX3XYB8XNXxPbTKHTNqa6dTrjE6ybts5rgsFP2x	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLKJaXsPVVuXXogeu5LDw7XeMJNiV5JjyNzcpJp82RaTTzNLrwN	8
13	2vb8W3UMAN9zPBBD24fzNVMFgUrjnzCJJmRNGH8R2qDfLyExEf6M	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLUPJn3fFzp8XHZBNc2TWbNEgvNfnyyaoJVRStBUW8ovXJZoqqz	9
14	2vasPAv8Ai7SZWoCcemuWtxZBMU2H9ZJsia9pG9q5Ut6EV5LC8VN	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLKJaXsPVVuXXogeu5LDw7XeMJNiV5JjyNzcpJp82RaTTzNLrwN	8
15	2va9T55DKxpD9JduGf3tG5Un93x1yJ3hPSmB84LaLpFJzJwMiz3S	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKwPcss997SNgMWkx3WSEaqqcs1d6x8dKC3DjSKpQstNAEHPCaz	10
16	2vbJCWffe2fnoHqXTWVkPvqgVat4hYJiiAgsnAJry3FmRRowLCBm	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NK7zMd8uE8zffrcfM4iZpuxE2SPL6dnYaZ5STU92Rp68JATKWCw	11
17	2vbcmbZJpWJfPRLgBiqvn9MT4cFHxd1EMghDMJR3hgzULd2cgVtj	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NK4WL1MxGbG5tWbVrRbcgDqxcrUo7N9UXKvfrHswM5fnDgSSe1E	12
18	2vaWAkpWpwNqJGCr8qW3aEAQxbcWwT2ZERqm3jHFMNoSxaFgup7m	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NK7zMd8uE8zffrcfM4iZpuxE2SPL6dnYaZ5STU92Rp68JATKWCw	11
19	2vbJ2iG3imNSLvVzct8xpJ77RsoTfNnTK2VmVxGq32mH252WYdqf	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLJmt5sVy4JeRqfDt8HKmww4DVjw7DZ7ykbGBt3YbkkHDAxLgwR	12
20	2vb4E1rXKEWUsFrtSdktQDsA8YuwjqCKmsNFyELH5Mpqp64PEE5C	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKVZcPMxq7EVhvQzWzX7NiuPdn1qEuE82HfPQBMSQkkR6dd1Z5e	13
21	2vaP2m4EwWy74jHHoAPLFoNZuyCxo9Wo3b5XseQo4tbb4XDbd8st	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLV4df2K8sUbF5MXtTSWtFHXAiG3gSwKJj18sF2RetffvKD48WL	13
22	2vbz3QuZjBAhKGbEtd7qLTBJwULa77qRaFZBDgcC2GTwF3dJFy74	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLsfFUAJvk8mZ6JS3q3tGbLjgLVzq1T8hMyMdoHJtwbbFPhzcez	14
23	2vaXXz5MY99MUZm9iVynQPgq5ztXx552EutrEHvxqKrPbFeMYt9j	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLgJ6juekbUcC8mA4BgWigmij97HR74jRPvkBg3kqN93CHVjsQ6	15
24	2vbFZbAH3iqYBeQt9J3cNdLL5Ri5TZpoM4xCMxSQko1jFzZVEcEJ	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLyCvyHH9bc6N7PRnG21LfMbKouhWXMht9qNniwkQUGPVCT4WzN	14
25	2vaTzudyLDD8spb5MFREuHEgVmEx2FG9RZujKHc7NhVeiX55gAzD	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLEygSkSPuXnrZXpp1tdxQBW1syhqrdoAi2ixFDwkMp86pxJFQc	16
26	2vahFC1fJRT9SzVbdHmCAWobRTbrgea4vA8DU2S6bMqgSrCQs8b8	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLx1M28R8QYovrkucPyvmiLywPj6ytCreaZTAkuW8N18L5wYkNN	17
27	2vbiNWuPrwXcX3PzXw6WinPWD16E75f5Fd11f8bWg4g5fGLoTxxR	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLEygSkSPuXnrZXpp1tdxQBW1syhqrdoAi2ixFDwkMp86pxJFQc	16
28	2vai2TTn8BJj2quebjTAh4nj1AggFifTPhgkidfZRVX4MFy7itrp	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKKZ2pdhtzwwHxJx2RXEkNH9oumF3BMGrmdqEKLV3rkqJdVU1Po	18
29	2vbETqtVpGbKH5QcEUeHubcgDFDG8ZU92pRKs7jxunkjC1FCxJsF	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKEDV2kuqgRRtZuyyyLiUVizwKqQbphbdTzRhX8C2wNKdGEVUou	17
30	2vaw4fLUuTfMWgGM5atGoqz5Xzu2aVnwQmMYKQf3zk7uN6B3hKk6	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLF8ftXJP5cPuTkk4YWvKCLoZ48W1pTBTSBPW5jgfgnSsscxAFE	18
31	2vaFtQetYZWV2oizJw3fPzF7UqdZa2Wv5o6goTthyaZkEnqLReJX	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKkZf5Y3voo7JDbtrgFVhUdi5kY3EX1jDAKnKHNAJerQm4VG7K6	19
32	2vbA5g6wk7Vf6aZoj2Mknwz7MvTMzWYrtfzzrN9fpLbfS5jkArD4	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NL1NHkcyUpTpTLSg89Fg7Y74kCsYY5Zp8BsLnjBrCSbu1aEDb5Z	20
33	2vapyRT1ZSnUr4vYCs7t1n1XpaqT6Pt6jE18sBVjiU9ycKX1jXNa	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NK63JEKx6SXBXokXt2aevw1yHCPx9krfdc9uCZsSMf4tBxtj7W8	21
34	2vaoAzigAkQFrRTDKPEarYL96G28ddNp9SizXkv5m6y9JEcVTTa3	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NL4zrGVDVde42ALRpM4RDJ2RJp9q51dt8v9K6pns1TNd3ypFEre	22
35	2vaEJbEwJgcL9jvJ2EbBsSd3LuKh9VEoJF6NR1xvQoc9r99dLoy7	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLuQRUVtDvN3s7bFpwbcxsrzUUb7hC3sUPHh4pAKp7T9xVWJ1vB	23
36	2vaNCyhPb9nDUPQhxMK2zEkwegaejXLAFpoeGojUeBj8punJfZ9X	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLDs1gcbvS7CTreCh546UnA7DS9e7ojj8vqooEBAV7VSyb8nUDU	24
37	2varsu7QTC2aWwyj5yMffYWg9RPYpX848NikF9T6GC6Qpxp8PtDV	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NL92EouWZR34WcaC2BRZq5778NwCLZ4u8EVBSXdni3gBY4H7dj6	25
38	2vbozxNHWHLfZYkfCg4ZmSr7fvnrLiE8qa4CLJqgpG8NzmNzHD7a	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLDs1gcbvS7CTreCh546UnA7DS9e7ojj8vqooEBAV7VSyb8nUDU	24
39	2vbWBABUMCompB43Uf9E7GDpttuNUXPC6drCQ8R1zp5XcaEpZrRn	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NL92EouWZR34WcaC2BRZq5778NwCLZ4u8EVBSXdni3gBY4H7dj6	25
40	2vaK9bk1AuJv59XHhM7BcFexWQpKHUAh9ntqhyHGMRgvSnDbzYdE	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NK56TD3efj9BU3DsXeRYV6vAUrNkkw2iFv2FoWet1oyFfTRmBAc	26
\.


--
-- Data for Name: internal_commands; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.internal_commands (id, command_type, receiver_id, fee, hash) FROM stdin;
1	coinbase	145	360000000000	5Ju8oSug8nUtH8uUHPN5vWKJYBm1ctpxgwzzEgZQu2vDafxfktAD
2	coinbase	37	360000000000	5JtpyH8BDr9VYkeFSeiHPsRGqFvqheHiTpAi4KZHZXNHK8jrMsmG
3	fee_transfer	145	15500000000	5JuHHBavUQ97ooLWWoaRqSGeNwnQcymJLvinFducBx7RxzrdYQj1
4	fee_transfer	37	15750000000	5JttvhRYyR4gizuhPXryMQpsXWrAd16pwaLPcakAHxeGmPtHWrEx
5	fee_transfer	145	41000000000	5JvCGCJX5jDiyuyRtsGSXvsSUQ7tygc6vWKrMF1KKoAoPawQwf82
6	fee_transfer	37	41000000000	5JvEGaYf3N5ds3N1uBdEBC6LKJB4fSR6EExKdUJ888xem1qXy6f4
7	fee_transfer	145	20250000000	5JuVVjJibtTZFHhm67xdvWXx4G5zLLVMTJAWVUnsPgxwuF5Nd1qr
8	fee_transfer	37	35750000000	5JuXdhCCVBgmGnmwR158o4RcKKJXdGYxgLT1V3WWptXe77PKNG94
9	fee_transfer	37	15500000000	5JujEDfu5HTMcfqDbWXH134oyR8YJAnqddQT8eSXxNiKEm3YR6JN
10	fee_transfer	37	15250000000	5JtcwZnsrH8xsn7wVuhTTcBuYZkdnfVAHNQcChfZvzxy4pLwPLQn
11	fee_transfer	145	56250000000	5Jtg3YsX6Y7QeidNUGiztQbmCnFTt4ZFLN9bx6AngvS3CGJ2ZXuV
12	fee_transfer	37	5000000000	5JvACcxN2N7Jt2jUJ5oxZGhFMFtJ8LbtbAg8ohtqtU64bjN3owhn
13	fee_transfer	37	56500000000	5JujdUcrP49YNciJyfAFLo9miJFgmuEh9unQe7RqenympPs9WsLL
14	fee_transfer	37	20500000000	5JtzAySS8d8SHDND2w9jGbX7AYqZqEh4xFuEoGjTF7NvabMY8KEw
15	fee_transfer	37	10250000000	5Jv4w9hvH4YQvXpC77upcebjsJsH5vXBzheHwGqPWVv8yFreyPV1
16	fee_transfer	145	30750000000	5JtvaFk4hMLWQdStJcR1qK8fpusD1mTC8UNBozXV8rQtoFpsx258
17	fee_transfer	37	30750000000	5Jv2ePNMyAfwBgoKJnLAUc3ruNfDoSM9wtE1QiU4a5fLxWa72452
18	fee_transfer	145	15250000000	5JvALMvYtfq98L5xzx4pXZYxcHmteF5cMpM9CRLtnXptAJtcqXJE
19	fee_transfer	145	20500000000	5JuQZW3PSyPVeoH94Y84hwynoPK3EYm2kDwJcL7G2THhY93phjt2
20	fee_transfer	37	90500000000	5JtkhHLMD8gwMK6c5E1o1iC8LGayRgudv97TX8weiHeWLnc8xWSA
21	fee_transfer	37	1750000000	5JuepprP3R3hsFHWYYTqxkRuLDoNBrFj5Kf28UtwZYL8biTkZJpT
22	fee_transfer	145	5000000000	5JvGNCQudBSWQxG2bQ3kiiAiUoTnsiVrAGZNYk489RYKGTQHfgYB
23	fee_transfer	145	36000000000	5Jv8x4sDT5yBov3VDYPFm7tvPb6FgBFbk32DSQABGiLcYzZUiGZb
24	fee_transfer	145	35750000000	5Jtnket3Ay6MM386j6hNs4rhVni1LYPdHzNZh3JgqjFCABaj8zTS
25	fee_transfer	37	71750000000	5JuMyA3LXJC4PB9cbbjnhw3cBkmzC1gt7vQfaxcfNrvCNn2FvHcC
26	fee_transfer	37	36000000000	5JuvZtRjhNhiYiepwaKoxDA2yQhQxRhbYk75xU4HtDaUKBdERnLK
27	fee_transfer	145	51250000000	5Jtjfmq3F1N7PdhCH9tcAaTb64ktBReGZsFMEuwM7MXKRo6PfKEz
28	fee_transfer_via_coinbase	91	1000000	5JuKeZgLXQcYjQNSR6Crr91LfnT515sXZ3bYUPaF3sNwDVu2CVti
29	coinbase	145	360000000000	5JuPNBCxCjMBkpkEsqbu7r2pa4e14wxegBqWqeeTUkuBXMHeRQDc
30	fee_transfer	91	12000000	5Jv1LTtvHEAh4txJHMDuWPVPNLeaQDXzLud9z9yJykaGrE1JPnqU
31	fee_transfer	145	56488000000	5JuQ6ityorkeKnBVTFZZ4YJiyku5g8dp3uAMYt4tWHQeCpjoT2HV
32	fee_transfer	145	40750000000	5JvG9QPfyJvPTEu4QFUZD1u1TLtUZFPhur17dtPzR5eP7rMABuG6
33	coinbase	37	360000000000	5JtbLEma7wxwU8Z66ZTWHRG9W7KYwy47BGazvhMKeX4WeAods2Fk
34	fee_transfer	37	59999000000	5Jtamwj7V51fNWUgLHz9RPqULHv6CmgmyrWrapxSNSBo8KJwBgXh
35	fee_transfer	91	1000000	5JuKeZgLXQcYjQNSR6Crr91LfnT515sXZ3bYUPaF3sNwDVu2CVti
36	fee_transfer	91	2000000	5JudybnQQMYxwgBGXn8ZndgVMMvtViW4SsbxZp73eAModNUHMMVD
37	fee_transfer	145	59998000000	5JuQ9yoPxM8NN8z5Ntyi16RGJkjeoUc1VgZem6psfq5PX26Jtng3
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
37	B62qrhZ9j56NuJefZeGADuBsMvLNkyiJC6u2G88SUUz8uEbqNW3AEDv
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
66	B62qrCV2xfWipHVW7KvdKSqXVqbTJLs4oNGhuDp8Ag34vy57mN4pcEi
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
91	B62qqaES4tiDsvzRW4sZ89M3JSuTG3Qk2WpRMhS78w6ToDDAVJrRCZq
92	B62qnYfsf8P7B7UYcjN9bwL7HPpNrAJh7fG5zqWvZnSsaQJP2Z1qD84
93	B62qpAwcFY3oTy2oFUEc3gB4x879CvPqHUqHqjT3PiGxggroaUYHxkm
94	B62qib1VQVfLQeCW6oAKEX2GRuvXjYaX2Lw9qqjkBPAvdshHPyJXVMv
95	B62qm5TQe1nz3gfHqb6S4FE7FWV92AaKzUuAyNSDNeNJYgND35JaK8w
96	B62qrmfQsKRd5pwg1EZNYXSmcbsgCekCkJAxxJcZhWyX7ChfExZtFAj
97	B62qitvFhawB29DGkGv9NEfGZ8d9hECEKnKMHAvtULVATdw5epPS2s6
98	B62qo81kkuqxFZw9cZAcoYb4ZeCjY9HodT3yDkh8Zxhg9omfRexyNAz
99	B62qmeDPPUDtPVVHqesiKD7ecz6YZvGDHzVw2swBa84EGs5NBKpGK4H
100	B62qqwLQXBrhJmfAtF7GUf7FNVS2xoTPrkyw7d4Pj9W431bpysAdr3V
101	B62qkgcEQJ9qhjwQgt2XeN3RJpPTfjCrqFUUAW2NsVpzmyQwFbekNMM
102	B62qnAotEqbcE8sjbdyJkkvKnTzW3BCPaL5HrMEdHa4pVnfPBXWGXXW
103	B62qquzjE4bbK3mhk6jtFMnkm9BdzasTHuvMxx6JmhXeYKZkPbyZUry
104	B62qrj3VHfVadkyJCvmu7SvczS7QZy1Yk1uQjcjwkS4QqDt9oqi4eWf
105	B62qn6fTLLatKHi4aCX7p6Lg5rzZSq6VK2vrFVgX14gjaQqay8zHfsJ
106	B62qjrBApNy5mx6biRzL5AfRrDEarq3kv9Zcf5LcUR6iKAX9ve5vvud
107	B62qkdysBPreF3ef7bFEwCghYjbywFgumUHXYKDrBkUB89KgisAFGSV
108	B62qmRjcL489UysBEnabin5be824q7ok4VjyssKNutPq3YceMRSW4gi
109	B62qo3TjT6pu6i7UT8w39UVQc2Ljg8K69eng55vu5itof3Ma3qwcgZF
110	B62qpXFq7VJG6Spy7BSYjqSC1GBwKLCzfU8bcrUrALEFEXphpvjn3bG
111	B62qmp2xXJyj9LegRQUtFMCCGV3DQu337n6s6BK8a2kaYrMf1MmZHkT
112	B62qpjkSafKdAeCBh6PV6ZizJjtfs3v1DuXu1WowkYq2Bcr5X7bmk7G
113	B62qnjhGUFX636v8HyJsYKUkAS5ms58q9C9GtwNvPbMzMVy7FmRNhLG
114	B62qoCS2htWnx3g8gFq2ypSLHMW1jkZF6XMTH8yKE8gYTH7jfrcdjCo
115	B62qk2wpLtL3PUEQZBYPeabiXcZi6yzbVimciFWZSCHpxufKFDTmhi6
116	B62qjWRcn5eRmdppcsDNudiogbnNPzW4jWC6XH2LczMRDXzjK9AgfA2
117	B62qjJrgSK4wa3HnZZqmfJzxtMfACK9r2zEHqo5Rm6UUvyFrk4UjdPW
118	B62qoq6uA96gWVYBDtMQLZC5hB4hgAVojbuhw9Z2CE1Acj6iESSS1cE
119	B62qkSpe1P6FgwWU3BfvU2FXnuYt2vR4DzsEZf5TbJynBgyZy7W9yyE
120	B62qr225GCSVzAGKBYxB7rKE6ibtQAcfcXMfYH84hvkqHWAnFzWR4RT
121	B62qkQT9sAztAWnYdxQMaQSxrA93DRa5f8LxWCEzYA3Y3tewDQKUMyQ
122	B62qieyc3j9pYR6aA8DC1rhoUNRiPacx1ij6qW534VwTtuk8rF2UBrk
123	B62qoFyzjU4pC3mFgUidmTFt9YBnHjke5SU6jcNe7vVcvvoj4CCXYJf
124	B62qihY3kUVYcMk965RMKfEAYRwgh9ATLBWDiTzivneCmeEahgWTE58
125	B62qm8kJSo4SZt7zmNP29aYAUqETjPq6ge2hj5TxZWxWK2JDscQtx1Y
126	B62qkY3LksqsR2ETeNmAHAmYxi7mZXsoSgGMEMujrPtXQjRwxe5Bmdn
127	B62qrJ9hFcVQ4sjveJpQUsXZenisBnXKVzDdPntw48PYXxP17DNdKg4
128	B62qpKCYLZz2Eyb9vFfaVPgWjTWf1p3VpBLnQSSme2RC3ob4m1p8fCv
129	B62qkFYQghamWpPuNxzr1zw6ARk1mKFwkdQWJqHvmxdM95d45AjwWXE
130	B62qnzhgbY3HD19eKMeQTFPZijFTvJN82pHeGYQ2xM9HxZRPv6xhtqe
131	B62qroho2SKx4wignPPRf2qPbGzvfRgQf4zCMioxnmwKyLZCg3reYPc
132	B62qm4jN36Cwbtyd8j3BLevPK7Yhpv8KtWTia5fuwMAyvcHLCosU4PN
133	B62qk9Dk1rwSVtSLCYdWNfPTXRPDWPPu3rR5sqvrawP82m9P1LhBZ94
134	B62qnR8RErysAmsLHk6E7teSg56Dr3RyF6qWycyVjQhoQCVC9GfQqhD
135	B62qo7XmFPKML7WfgUe9FvCMUrMihfapBPeCJh9Yxfka7zUwy1nNDCY
136	B62qqZw4bXrb8PCxvEvRJ9DPASPPaHyoAWXw1avG7mEjnkFy7jGLz1i
137	B62qkFKcfRwVgdQ1UDhhCoExwsMPNWFJStxnDtJ1hNVmLzzGsyCRLuo
138	B62qofSbCaTfL61ZybYEpAeGe14TK8wNN8VFDV8uUEVBGpqVDAxYePK
139	B62qn8Vo7WTK4mwQJ8sjiQvbWDavetBS4f3Gdi42KzQZmL3sri25rFp
140	B62qo6pZqSTym2umKYeZ53F1woYCuX3qHrUtTezBoztURNRDAiNbq5Q
141	B62qo8AvB3EoCWAogvUg6wezt5GkNRTZmYXCw5Gutj8tAg6cdffX3kr
142	B62qqF7gk2yFsigWL7JyW1R8sdUcQjAPkp32i9B6f9GRYMzFoLPdBqJ
143	B62qjdhhu4bsmbMFxykEgbhf4atVvgQWB4dizqsMEBbmQPe9GeXZ42N
144	B62qmCsUFPNLpExtzt6NUeosa8L5qb7cEKi9btkMdAQS2GnQzTMjUGM
145	B62qrtTgyssCJFm7Z44Hs99vDuLCmm7xZF6jbGf7xkmMg8mx4cXHZGA
146	B62qneAWh9zy9ufLxKJfgrccdGfbgeoswyjPJp2WLhBpWKM7wMJtLZM
147	B62qoqu7NDPVJAdZPJWjia4gW3MHk9Cy3JtpACiVbvBLPYw7pWyn2vL
148	B62qmwfTv4co8uACHkz9hJuUND9ubZfpP2FsAwvru9hSg5Hb8rtLbFS
149	B62qkhxmcB6vwRxLxKZV2R4ifFLfTSCdtxJ8nt94pKVbwWd9MshJadp
150	B62qjYRWXeQ52Y9ADFTp55p829ZE7DE4zn9Nd8puJc2QVyuiooBDTJ3
151	B62qo3b6pfzKVWNFgetepK6rXRekLgAYdfEAMHT6WwaSn2Ux8frnbmP
152	B62qncxbMSrL1mKqCSc6huUwDffg5qNDDD8FHtUob9d3CE9ZC2EFPhw
153	B62qpzLLC49Cb6rcpFyCroFiAtGtBCXny9xRbuMKi64vsU5QLoWDoaL
154	B62qj7bnmz2VYRtJMna4bKfUYX8DyQeqxKEmHaKSzE9L6v7fjfrMbjF
155	B62qnEQ9eQ94BxdECbFJjbkqCrPYH9wJd7B9rzKL7EeNqvYzAUCNxCT
156	B62qokmEKEJs6VUV7QwFaHHfEr6rRnFXQe9jbodnaDuWzfUK6YoXt2w
157	B62qpPJfgTfiSghnXisMvgTCNmyt7dA5MxXnpHfMaDGYGs8C3UdGWm7
158	B62qkzi5Dxf6oUaiJYzb5Kq78UG8fEKnnGuytPN78gJRdSK7qvkDK6A
159	B62qs2sRxQrpkcJSkzNF1WKiRTbvhTeh2X8LJxB9ydXbBNXimCgDQ8k
160	B62qoayMYNMJvSh27WJog3K74996uSEFDCmHs7AwkBX6sXiEdzXn9SQ
161	B62qibjCrFmXT3RrSbHgjtLHQyb63Q89gBLUZgRj7KMCeesF9zEymPP
162	B62qrw63RAyz2QfqhHk8pttD2ussturr1rvneUWjAGuhsrGgzxr2ZRo
163	B62qmNVzYukv4VxXoukakohrGNK7yq1Tgjv5SuX1TTWmpvVwD5Xnu2L
164	B62qoucdKZheVHX8udLGmo3vieCnyje5dvAayiLm8trYEp3op9jxCMa
165	B62qo51F51yp7PcqmHd6G1hpNBAj3kwRSQvKmy5ybd675xVJJVtMBh8
166	B62qjHbDMJGPUz3M6JK2uC3tm6VPLaEtv4sMCcrMBz6hnD5hrET4RJM
167	B62qnyxTMk4JbYsaMx8EN2KmoZUsb9Zd3nvjwyrZr2GdAHC9nKF16PY
168	B62qrPo6f9vRwqDmgfNYzaFd9J3wTwQ1SC72yMAxwaGpjt2vJrxo4ri
169	B62qoZXUxxowQuERSJWb6EkoyciRthxycW5csa4cQkZUfm151sn8BSa
170	B62qmmBab8MbaqgM8oXzzuda4weFpfjV9scHBDWnehdxngkqCpoTfch
171	B62qr7QqCysRpMbJGKpAw1JsrZyQfSyT4iYoP4MsTYungBDJgwx8vXg
172	B62qo3JqbYXcuW75ZHMSMnJX7qbU8QF3N9k9DhQGbw8RKNP6tNQsePE
173	B62qn1f2PoDgffHMTMohmM22GZPHBDqy9BENuVKRP3T7MedVqK5PRHG
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
226	B62qrrop16eMgHfQYSjryYvqW8EPDttxG7HVjHMBy1j14s2GnK6Gw8q
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
243	B62qqXCNwhXXxkrAqvYBifYeS12FEYtZVGCg8rijWkroy9XBJairWDM
\.


--
-- Data for Name: snarked_ledger_hashes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.snarked_ledger_hashes (id, value) FROM stdin;
1	jx8Z1HuU1gWjC9rAdvvYfZnVX1F6BsLJfh8yLCgT6sA9driPpCm
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
1	payment	66	66	66	0	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtv7W41Kj1SKvxhBM53NfFyTNgnn3nxcwnnBsEpDHSPKaSujHa2
2	payment	66	66	66	1	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JteFihNB5HDuQTKEPYqfM6giAFETqNuJkJiasQKbiEAMWrG1C3X
3	payment	66	66	66	2	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuvVd4pCgBv5tVccrGPyhZPJA46aFiChZNDQXkeympXNWnwMecF
4	payment	66	66	66	3	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuyoiKsPjpDicPPL2N2odHfhFwQUYEjD5JzsB51CWaR2CbkBxJi
5	payment	66	66	66	4	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv6orEaj6BYjYPFA94yY4CnvcWrhhyfgstsCmE4gzdMDX7BaBTT
6	payment	66	66	66	5	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuvQvinadsuPJAY8aBemqVLNZEH9NPiiWbcPpGqZ6g7QKsXPzev
7	payment	66	66	66	6	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtuGTQmq3qJTNLJ1nbDwaNgucyGrUnvUiYvAWTuwDBoRignbnKT
8	payment	66	66	66	7	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuMTUMJYGdVHNPdNZcKdTgcS1mHEBAu9HYPTkPvYZcHnBmd2d4w
9	payment	66	66	66	8	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JupjJuGVDpzNGkyFmTPqSZCpgW7akiyPukQqLa8o2GddWB6yd4C
10	payment	66	66	66	9	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuYDaqsr5pLq2V2P4Cq6RS8h7fWw4JLbpbCd2x566jjwPg7wPby
11	payment	66	66	66	10	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuV3JDBR2kyZanCna7Ug1quLYx14Lz2bRMq1m8k65mQkDV3e2xU
12	payment	66	66	66	11	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv5iXyW2odabVZ1qdJippi2Yhrm55R8cmYmDagUyBJWgwrdxJwy
13	payment	66	66	66	12	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuAZR3xvrhQCkff4HDKpmbg4EHQZGK6ehVeATiNNgg6uJJHaMV9
14	payment	66	66	66	13	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuwaB4viq5F3SupAXrRQwb4vYe3LK9C8iALDR2HbbEi9ttugvgd
15	payment	66	66	66	14	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuzF2HtpxuH5JCVUzaiGd5xKFPst7eakDJjh1zQzhzJi6k5oc8o
16	payment	66	66	66	15	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtx7WzT76LX2uvNRpyzMCC6ZrqQXsgNtboYX66fwd5dmqFnAiGg
17	payment	66	66	66	16	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv5kBWqQzrchgxx3ahtj5XuzFCjVqGQ77UwGSqRDHRShXwaCRrW
18	payment	66	66	66	17	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JufC8e9am73KEpsWZwtRde5sZiknvbYAZS2Edi5Z3mQTayaJXyZ
19	payment	66	66	66	18	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtnjaTLeD4vdHFFmYU743D2JBZZjVdeU7DKzxbPcLdqkAxJYbMb
20	payment	66	66	66	19	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtuxNorvvrwZn287Eypdnfruq2RNrTG1ABjt6dmY4yaBNG9Anje
21	payment	66	66	66	20	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JutM9n7ucon7ZPTBzdSzAM5AhSyAppddB3fgWW3QMoabSaTvTrS
22	payment	66	66	66	21	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvPiKbwaibRQG9fR24Zb6hE4FoevaYtSKtr7Z1QiXKwuE8pzsrF
23	payment	66	66	66	22	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juf9yi8HG3kXU1zkW1DeyKp6zyzB7SbW7oswfocpZ1JUyRn6L67
24	payment	66	66	66	23	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jup69XrsuHVjwNHHRPoGDfBwbh36wgAtxLDwHLqdqeyj33nVndo
25	payment	66	66	66	24	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtrkrbNaGPFKKk2yDUMwrCg4KxWa3haFTfo7U2pQ1C9DTYRt1Q5
26	payment	66	66	66	25	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvEuCc9gLdAA8Mh8yv3REheQXF7jB4voX2XaYPfjw1kqs73V9QH
27	payment	66	66	66	26	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv8DeGkuYrmKiMnd3gQrp9ME3VyeVvYVJMnDxZZh2d7kh2kWvef
28	payment	66	66	66	27	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JteENxG2mTraxN9vwcrRnFFWdoqsdpeVuGtWCy6czrk2Q6inWZ8
29	payment	66	66	66	28	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvGfKGio3CdZmG2YhZ8QdxKqYiRFv98myRV3ms6WzAPwC2zzhc4
30	payment	66	66	66	29	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvHXzk5MmAS2ZZvx3GwDeTbxHhQErYSKQEPg9xiTh3aPr1oeqFa
31	payment	66	66	66	30	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuhWqVaf3r8V2EB4hrR5KPN3kNpv3bVpD425LWKvNuXr1QdcbRR
32	payment	66	66	66	31	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JttRVYSJ4kQFcvCkbiyeVUDgTCg61Bumik7Y81fQc4a15RyevDy
33	payment	66	66	66	32	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvPgFYGqgCKjVSGD9cYma1e1taAPEXGKp4Z8s2jG4BjmdWgyxfY
34	payment	66	66	66	33	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvPmyZ4o5fGDH8RjFaqkYeRXCm7z8gjoG7XtNaE1abuVvAKnAg8
35	payment	66	66	66	34	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju924qQCjDRrGdgaTi5kZLKg55M868QsxLkvniZ1AxUHvXMc6yt
36	payment	66	66	66	35	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JusQntBMGbxcxfU5T6AA8wMbNbwkUM1EcW7ypULXbs4jNqKC8n3
37	payment	66	66	66	36	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JucGKi9EaKYWby3HxBD1EvTMuvAYY8baeRmpt9gefZmyPwXaK3w
38	payment	66	66	66	37	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv12wqHtmgpf45dav6c3NdLCQntDUEGgmqxmvfqhVpZ6QFSJa7E
39	payment	66	66	66	38	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuB4SNjYvHxMy6wJMUEbWC2ksB5rR6LUp4AmsjyhevzXd7GYdnN
40	payment	66	66	66	39	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuNPGQJWPkqFapS5rxacEvZpgmB138Y7dhYgkADZbP4jgaGNSTp
41	payment	66	66	66	40	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtbcfLGvao3u29NDC3XU2jy1VZVVFBga2ZcjAG97RmCvc5eGTJc
42	payment	66	66	66	41	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju1ENuqE2VP4NXF54U6BZEDQeZcAHVviRgP9cTFK2ESye6sPPUw
43	payment	66	66	66	42	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju46ED6USUFz2yiQwRPuxS21ZuWj2JD6AEGqW6mH7n91Gy8Z3JX
44	payment	66	66	66	43	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuBxMABdfBYT31dbdQe2VpDXky3YqgLW87yVui1x7Zbj8hkDkzx
45	payment	66	66	66	44	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtdMVdTPUc82JWKNQeQsY3YS1dPKCB7ZLb3acZWVMsPSWcfuzGQ
46	payment	66	66	66	45	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jug77rhsFcCQp734SN1vmM3aXmZWjSSp4Rxp9axVj3rZCqDtCVw
47	payment	66	66	66	46	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuD2CYsAuVUPUEXCDretdhJ3pdv4xTH4MqmyR5Gn3FZboMNmnN5
48	payment	66	66	66	47	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvGYRWV2XArDY8fD2WRCZK9af2pRNnic7GMwHBuimE6ah1TvWsL
49	payment	66	66	66	48	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtvQtPeQkbkn5yNt2H8qpehNK3QFD4pcFe9y5PXkimbWP6FNuFb
50	payment	66	66	66	49	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JubLCNePrTZK3vNwVXo63DCkEWTnJddhYFFjHX3q2etPQef1yJd
51	payment	66	66	66	50	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv8DeHANBgxiNa6hoPZGA55H7jhHnW6irMc8iFo8tBfXs29THng
52	payment	66	66	66	51	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jug2zXD1HkmYQGhG9byCMyYdAQ76pzamGpWvNmirTciHDzUrQJb
53	payment	66	66	66	52	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuRKFYaikY9CHsRaEFKbioa1zpR7Xe9T7WujGhx2KZ4pDZdiBBo
54	payment	66	66	66	53	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtoaxFiiNHaPSasVqBZjdLzEpd52165iJ6EKBsLgGuenpp1epfH
55	payment	66	66	66	54	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvNEtD21tycr6q2GZubBR6qAerhMonppw4hafxNrKgMFZoTWzNL
56	payment	66	66	66	55	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju2ahyFLq8fvLhCUyVNv9se3JWCPRPEXj51zH1njNS179ysnTV9
57	payment	66	66	66	56	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juyf4PPd8ViteJV2VmPrw5G8je2mWRh7LK2cAKVeJSoHErKzf5R
58	payment	66	66	66	57	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju2ksCZ9FnsLm4HaRHGRUFrsmxofPC2N9hocAU5WQnUZajPd7ri
59	payment	66	66	66	58	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtzqHxo8GgCMEnwzhBxwZSmECesT2sBCrm3QvR2CEjrFHrFVCiS
60	payment	66	66	66	59	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtrv8aV7bs5ngLRmu9g2sckhCW7c6qNwUYiX2JjfXMZPFmDLFRF
61	payment	66	66	66	60	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtoKoRSm6XT3wJCHvnuprwnWnmkGR9bSKotnohuA41gwx8iPLK8
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
\.


--
-- Data for Name: zkapp_account_update_body; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.zkapp_account_update_body (id, account_identifier_id, update_id, balance_change, increment_nonce, events_id, actions_id, call_data_id, call_depth, zkapp_network_precondition_id, zkapp_account_precondition_id, zkapp_valid_while_precondition_id, use_full_commitment, implicit_account_creation_fee, may_use_token, authorization_kind, verification_key_hash_id) FROM stdin;
1	172	1	-1000000000000	t	1	1	1	0	1	1	\N	f	f	No	Signature	\N
2	243	2	999000000000	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
3	172	1	-1000000000	t	1	1	1	0	1	3	\N	f	f	No	Signature	\N
4	243	1	1000000000	f	1	1	1	0	1	2	\N	f	f	No	None_given	\N
5	243	3	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
6	172	1	-1000000000	t	1	1	1	0	1	4	\N	f	f	No	Signature	\N
7	243	4	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
8	172	1	-1000000000	t	1	1	1	0	1	5	\N	f	f	No	Signature	\N
9	243	5	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
10	172	1	-1000000000	t	1	1	1	0	1	6	\N	f	f	No	Signature	\N
11	243	6	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
12	172	1	-1000000000	t	1	1	1	0	1	7	\N	f	f	No	Signature	\N
13	243	7	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
14	172	1	-1000000000	t	1	1	1	0	1	8	\N	f	f	No	Signature	\N
15	243	8	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
16	172	1	-1000000000	t	1	1	1	0	1	9	\N	f	f	No	Signature	\N
17	243	9	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
18	172	1	-1000000000	t	1	1	1	0	1	10	\N	f	f	No	Signature	\N
19	243	10	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
20	172	1	-1000000000	t	1	1	1	0	1	11	\N	f	f	No	Signature	\N
21	243	11	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
22	172	1	-1000000000	t	1	1	1	0	1	12	\N	f	f	No	Signature	\N
23	243	12	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
24	172	1	-1000000000	t	1	1	1	0	1	13	\N	f	f	No	Signature	\N
25	243	13	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
26	172	1	-1000000000	t	1	1	1	0	1	14	\N	f	f	No	Signature	\N
27	243	14	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
28	172	1	-1000000000	t	1	1	1	0	1	15	\N	f	f	No	Signature	\N
29	243	15	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
30	172	1	-1000000000	t	1	1	1	0	1	16	\N	f	f	No	Signature	\N
31	243	16	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
32	172	1	-1000000000	t	1	1	1	0	1	17	\N	f	f	No	Signature	\N
33	243	17	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
34	172	1	-1000000000	t	1	1	1	0	1	18	\N	f	f	No	Signature	\N
35	243	18	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
36	172	1	-1000000000	t	1	1	1	0	1	19	\N	f	f	No	Signature	\N
37	243	19	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
38	172	1	-1000000000	t	1	1	1	0	1	20	\N	f	f	No	Signature	\N
39	243	20	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
40	172	1	-1000000000	t	1	1	1	0	1	21	\N	f	f	No	Signature	\N
41	243	21	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
42	172	1	-1000000000	t	1	1	1	0	1	22	\N	f	f	No	Signature	\N
43	243	22	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
44	172	1	-1000000000	t	1	1	1	0	1	23	\N	f	f	No	Signature	\N
45	243	23	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
46	172	1	-1000000000	t	1	1	1	0	1	24	\N	f	f	No	Signature	\N
47	243	24	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
48	172	1	-1000000000	t	1	1	1	0	1	25	\N	f	f	No	Signature	\N
49	243	25	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
50	172	1	-1000000000	t	1	1	1	0	1	26	\N	f	f	No	Signature	\N
51	243	26	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
52	172	1	-1000000000	t	1	1	1	0	1	27	\N	f	f	No	Signature	\N
53	243	27	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
54	172	1	-1000000000	t	1	1	1	0	1	28	\N	f	f	No	Signature	\N
55	243	28	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
56	172	1	-1000000000	t	1	1	1	0	1	29	\N	f	f	No	Signature	\N
57	243	29	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
58	172	1	-1000000000	t	1	1	1	0	1	30	\N	f	f	No	Signature	\N
59	243	30	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
60	172	1	-1000000000	t	1	1	1	0	1	31	\N	f	f	No	Signature	\N
61	243	31	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
62	172	1	-1000000000	t	1	1	1	0	1	32	\N	f	f	No	Signature	\N
63	243	32	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
64	172	1	-1000000000	t	1	1	1	0	1	33	\N	f	f	No	Signature	\N
65	243	33	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
66	172	1	-1000000000	t	1	1	1	0	1	34	\N	f	f	No	Signature	\N
67	243	34	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
68	172	1	-1000000000	t	1	1	1	0	1	35	\N	f	f	No	Signature	\N
69	243	35	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
70	172	1	-1000000000	t	1	1	1	0	1	36	\N	f	f	No	Signature	\N
71	243	36	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
72	172	1	-1000000000	t	1	1	1	0	1	37	\N	f	f	No	Signature	\N
73	243	37	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
74	172	1	-1000000000	t	1	1	1	0	1	38	\N	f	f	No	Signature	\N
75	243	38	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
76	172	1	-1000000000	t	1	1	1	0	1	39	\N	f	f	No	Signature	\N
77	243	39	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
78	172	1	-1000000000	t	1	1	1	0	1	40	\N	f	f	No	Signature	\N
79	243	40	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
80	172	1	-1000000000	t	1	1	1	0	1	41	\N	f	f	No	Signature	\N
81	243	41	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
82	172	1	-1000000000	t	1	1	1	0	1	42	\N	f	f	No	Signature	\N
83	243	42	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
84	172	1	-1000000000	t	1	1	1	0	1	43	\N	f	f	No	Signature	\N
85	243	43	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
86	172	1	-1000000000	t	1	1	1	0	1	44	\N	f	f	No	Signature	\N
87	243	44	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
88	172	1	-1000000000	t	1	1	1	0	1	45	\N	f	f	No	Signature	\N
89	243	45	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
90	172	1	-1000000000	t	1	1	1	0	1	46	\N	f	f	No	Signature	\N
91	243	46	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
92	172	1	-1000000000	t	1	1	1	0	1	47	\N	f	f	No	Signature	\N
93	243	47	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
94	172	1	-1000000000	t	1	1	1	0	1	48	\N	f	f	No	Signature	\N
95	243	48	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
96	172	1	-1000000000	t	1	1	1	0	1	49	\N	f	f	No	Signature	\N
97	243	49	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
98	172	1	-1000000000	t	1	1	1	0	1	50	\N	f	f	No	Signature	\N
99	243	50	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
100	172	1	-1000000000	t	1	1	1	0	1	51	\N	f	f	No	Signature	\N
101	243	51	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
102	172	1	-1000000000	t	1	1	1	0	1	52	\N	f	f	No	Signature	\N
103	243	52	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
104	172	1	-1000000000	t	1	1	1	0	1	53	\N	f	f	No	Signature	\N
105	243	53	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
106	172	1	-1000000000	t	1	1	1	0	1	54	\N	f	f	No	Signature	\N
107	243	54	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
108	172	1	-1000000000	t	1	1	1	0	1	55	\N	f	f	No	Signature	\N
109	243	55	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
110	172	1	-1000000000	t	1	1	1	0	1	56	\N	f	f	No	Signature	\N
111	243	56	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
112	172	1	-1000000000	t	1	1	1	0	1	57	\N	f	f	No	Signature	\N
113	243	57	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
114	172	1	-1000000000	t	1	1	1	0	1	58	\N	f	f	No	Signature	\N
115	243	58	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
116	172	1	-1000000000	t	1	1	1	0	1	59	\N	f	f	No	Signature	\N
117	243	59	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
118	172	1	-1000000000	t	1	1	1	0	1	60	\N	f	f	No	Signature	\N
119	243	60	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
120	172	1	-1000000000	t	1	1	1	0	1	61	\N	f	f	No	Signature	\N
121	243	61	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
122	172	1	-1000000000	t	1	1	1	0	1	62	\N	f	f	No	Signature	\N
123	243	62	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
124	172	1	-1000000000	t	1	1	1	0	1	63	\N	f	f	No	Signature	\N
125	243	63	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
126	172	1	-1000000000	t	1	1	1	0	1	64	\N	f	f	No	Signature	\N
127	243	64	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
128	172	1	-1000000000	t	1	1	1	0	1	65	\N	f	f	No	Signature	\N
129	243	65	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
130	172	1	-1000000000	t	1	1	1	0	1	66	\N	f	f	No	Signature	\N
131	243	66	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
132	172	1	-1000000000	t	1	1	1	0	1	67	\N	f	f	No	Signature	\N
133	243	67	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
134	172	1	-1000000000	t	1	1	1	0	1	68	\N	f	f	No	Signature	\N
135	243	68	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
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
1	1	{1,2}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JttZt8FaPfDGG1yFoamb3bRVAFjt3nXABWH4ewvtJWsiXSLXpeP
2	2	{3,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juqgvm5yFXLhuKxRWXUW1YxKQKtrBLmqzyuhLGQSbcePraxuW1a
3	3	{5}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuXBoGh4YABngYF9idL11FzqvxmFJ2pkj6DCLg8q6pNFcB4hMn8
4	4	{6,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuDiaiMvxGLcgoc32m7kxWf67uiAyW7ZNngUZRwjeVajturhhhd
5	5	{7}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtWGtehL3S1D2hqUx66qosNhng1xmh5MHojc1MArurLceKb96HU
6	6	{8,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvMpuEArReJvDvUWt4k26pcjYyN3AUXLAYXWAnc7mPSAvja8CSi
7	7	{9}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuhqD51i16JfvgkJWb8fmv9peDqM46kDR65ySLcwbpjhjtM8C2L
8	8	{10,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvR1ZUNHSsxgEy1kWkYJ8Rr4bGTVMSPoNfBDgSCpg7vk56CEqB7
9	9	{11}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juztowrky1onw9CoehEJQcCeVTiPdRYHBbrW8mro3YmApTAUUcL
10	10	{12,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuD5TZ9zkTSqpLWLREYE48XK9o87c9y8BbHWiHSCNMs75zAQYZZ
11	11	{13}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuUEZ8p6HGmas1xc84QFx4mPWM1ppFTeVcZwmbf99mzFciTTuZh
12	12	{14,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuNcun4kwpPmmmMKbDKbsqsYcERx4LU8nkMhKWJdZSwzxAVJNYp
13	13	{15}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju2vfPJDYGzSRNKC5r4YiN6ytCfArHSZMxoKEyoPaRyZLpGrxCp
14	14	{16,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtbPZxHBpm3ArDJJHWAb6dHzPNboWo7TaN2i2UQUGgz4nGtpALG
15	15	{17}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtj4ZqXuxMu1iFJBHbqZjy3nR56QJ579Ks1txnAZrFBbwvHyteh
16	16	{18,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvJmXmnazwz75WqqGcdBf24Y3SsHCGfiynJHhVkHYVLcAPA3aWC
17	17	{19}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JutnQmKADY6t6vsPdf7Ja3AiSme7dZMCUL8rQVCKTUUWJH8mb6q
18	18	{20,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju5QoHwFfoLwvREtNQXfQhh9JgxKReSAXyrHvafG9MHfBZ1gE5E
19	19	{21}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv9cYzBJTQAyYushpRYsoVoLUvjptYfHNHui6Y44ez1L85asVpB
20	20	{22,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvNxKmCHxbnajbAqpSft4amBh9uPWh64oiRKpBQgnaa9djoUR7N
21	21	{23}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuVF2kuG5eiQCZQo9CAqu2k5fNNqn28WHn5bScsXw1RPcVQUxbD
22	22	{24,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtqY5j8nxvZVW2rLNGJt4RAxztW2EriMk5CRzb5rLjvHw73dyw6
23	23	{25}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuEJhR9ENRukxkGXmb311DmNtSditTJoJEBCdQ28zfJm7UtFJYA
24	24	{26,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtyEgcN1BE2vL3cH3QrxFUDbLegBBAWDrwsi6Hz1Lv9zEbWJjVL
25	25	{27}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv1gXk9LUqRefCAgLo2Y9osjhdS4H3gzxn5krPa6hH4mcwMNKWG
26	26	{28,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtwgCsPWoBzgjSabA8gyLhRdzwCoRSNefxipGf5dagVoasHZPYf
27	27	{29}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtmovUuSBhMC4hP7g8kiSMeqRjFdCiDNhwbVS66vBZ49MLwKhw8
28	28	{30,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtnGX92EppZLAudzJbbuMFvqS2rzcfipkAitxqMym1EaDYtYFAp
29	29	{31}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JutxaHd1iYX5JG9cjBfe7KTVZRfJErFyPSwjZL9Zh88aid2WzTU
30	30	{32,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuW5auuHAvWe7VZWABtbpJZ1iCqYdxABH39U2gkArEsrzy7hA1W
31	31	{33}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtpukH88qc1bDGkBnedMwdAU5kkxBhWmqMyLfTMyPx6VQPw3i7q
32	32	{34,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvJCjanN4oPUyz2J4wquokBtSbsZJipukWK4fe2FGe4tSzhvb2M
33	33	{35}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juc2ga2CAXTNuXRLz3qdsycZvPGFkcKy1DyRWDcTrk5AHn4SKkM
34	34	{36,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtYgQMZQvG3JPrmgvSiZN5F1iGHcCGv1H2wgros9L7ZwYeperPo
35	35	{37}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv359Q6QndxgL4bU8UeTH6VZF8En64bJTmT4NU1jLiUijczvcwg
36	36	{38,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtYMWwqyCenkhH2RRwm94E28YHhGaDBymL4qivjYGtokei27m6q
37	37	{39}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuwwM5UZCvsjkaPoSvH2QsdzFn95iDYSEeoAjWj52hL7v1vqfjJ
38	38	{40,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuLkKV3joz816dRNBCTvtQby57m9kAwTr8swPfLBjB3UnRLznVZ
39	39	{41}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuUuSCFyvKG3Z5YnZG2ke152n6wsbHSEHdcStjujox7pzHhE6wN
40	40	{42,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvBRMJgbqFugTfaviKFq6hJXYBUkTXDpipYP7Zz6imcMM87WyJB
41	41	{43}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JucD2avgM29KbCMkBxB9KWMHHFW4Qj3EHFLkqQsiAnkm8a9KVr2
42	42	{44,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JteknYooLkNCBzmv4a971bxiZ6D4c97nCeoPYtggRsMWCSzp8iP
43	43	{45}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvCAjSTbLfUv6HqXAqSyBLVQ4zacLSxjMeu6j6AHGquHhei822g
44	44	{46,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jueq4ZV7Hz6UrTSeiLUcVgrkhVYkFTFkATfU6kXFWakyuB58Ecw
45	45	{47}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuujMqLGbMfUJxAUhRQ8UHY6YroZ2aALS6J1UABH2oHdEDTRfAo
46	46	{48,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvP1eECj2QZxVBBZk5SHSB4otFe2pfBuCryFtqgmP245FHTDjAE
47	47	{49}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtoNMXNRUU4PW5uBjstKJ3fZW3mvfSetNkZ1ofEFB69752XAYa5
48	48	{50,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvAGmAcydzKE9mtZrb41mny2o77msGxtKV5gryRj2QByZ2W4NUn
49	49	{51}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju6VyoHYqmZjFKUhnv16udCoQcTHAM6prYr5XLa2SnzJUpxe4uZ
50	50	{52,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvCCy3WhVDamjygcGrFwatkxpsa5HhgPJzrAX8yuuQnqbGm6i34
51	51	{53}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju7noZVxpbvbtLLeRGgapc8swCTS4yWJYM69VbJ68pc1zP58WXc
52	52	{54,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JubxF5dSGVivtReM2yJeCs4A4F2YyNL2inrbh4XFcA1jVAtL5Ci
53	53	{55}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtuAMbtpcASSEPu5b5rr1Ji9fJsqv8tnVSmAdgGpxJgsLUUs7yu
54	54	{56,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju3DydG3taHmqdimMaq3tTCR6G1P2jpDmEjzDKtykdSgYWxPFWT
55	55	{57}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuJVqQPAkouEptho6tkWvZaQsaqGepXqJf444CWizC6KWRZNXzA
56	56	{58,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuQwjZ2jZfcDac3NEijo4vTc44ZnrArabuHzobkiWb4gEUN2z6N
57	57	{59}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju2QAX71n4QoKfFzYzBAFk1ysWcUCXgGkYc2yMapLDrgpCWWJrh
58	58	{60,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuYLbUAagkwqUN1rFJM8HDxdEk6u2pZGKkhNTG4r6N7McLrHzh9
59	59	{61}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuaWHq3qJ3SYBi9bt7w5DETJMTJat5EK5MUiFoEgGZLHXAeutPy
60	60	{62,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvCyiERP2y7N6hxm4nVuUWca5Z12WeMAxrdyAynzBceB3PoVG95
61	61	{63}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuLN3Vd8mgvwyAxWgGYY5cNx1ufWooqeET5qDtFaZjTTDGWPvCj
62	62	{64,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuqxpAx84f5pKhHUWtQx2dLSKF6qxkt1R3Vt1ahKgHVT45uehCj
63	63	{65}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuFFwuBBXVxYrcWzEsUrD5MvfxoW6FYp7oZzYM7PGWLG7YqA9T9
64	64	{66,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuoszeLsySmEuX4NUKi7cb38J4a7dULRtNatJseX23HJaEFFXsV
65	65	{67}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtuR4ZW7NmSsd2dFJFFycQuFAKcdeYrHdQoYzUnqWqcGBCJoa5w
66	66	{68,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuYEB5vNrxBpcsZUme52SkoC33H71tqL2WufWSakcPBuAQcWKda
67	67	{69}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JubgKjGagAX4FWUMNS8EbGYNefEyq6mRzegBCeSfRYc5njTUJNM
68	68	{70,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtuzC7jQT4v61GSTNCcVGFg9CgfhwUi8a3CCSYxkJF2oBqnBVqr
69	69	{71}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuvVJDz5E2HE9mQdpX94b8E8YhuFVFK6ooLhiTkgTZZ1BAoXkzH
70	70	{72,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuVneEwAdY1hXEt7FYqRPvTfqfRnVesvR3F1t5zQEaVv5z7ub7f
71	71	{73}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtY1UpGgcsrRLLEkGgZdeRShZVe1HZ72HR7pt18U2fJX98MAk3v
72	72	{74,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvNtDTpDLvgjX4LTyf5xSm6WStmg466FWZJHoNHLvQenpE3KH4U
73	73	{75}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuR61Crg5K2SyzLtJfu1AXyGJ5eqSPyeSiyfF3Uf9aytWPmae7M
74	74	{76,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtwMH43RkHnG7kjeWAJrSKrMB9ZWg4UzAmfNuC5UBYiv3w9FCM2
75	75	{77}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvPcYpmW1U7tXW7YoMGHni7B9sX7H8d9ATV61XY1QAxBUxnYvc8
76	76	{78,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuPC5gLwKM5nyoxHBtrBxMuHMkrUHD4HAL7sWHkBEc1GWEAtRju
77	77	{79}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuUAd1SiH5PBnRR1xy48NyLcMPqEQyLeh3GUpFo3DZyKUMGXDcV
78	78	{80,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtjepy41bFJRP8zXe8MF435PmYEFdspLSMJw9haJmDtQcf7ngVi
79	79	{81}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuvCxxmAGfw4AATYm5AGbM6ztDmCPjQef4LXLPKUPYFHQvHRj4D
80	80	{82,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvS6nrp4mUiNHt9TxAmiku7GZGZ7r4tznT4t9iieokG48dyU2iA
81	81	{83}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuhmvrcBgUptyegVs9az1kwoaZVeyXvGe36u4eWr89ZZAVG3byz
82	82	{84,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuDntg88Djnv9ziHbo4BgYLznCwhuReABoChX2szzwWvCHHR36Y
83	83	{85}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuT4x5H6uR4PjMQ36CDTdeSCnsZcFYhLEuitEAe9w7S8SWHCaTS
84	84	{86,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvPCDUD96xDy9Nk7n2wuaowgGzLbnsfBL6Y4fTWWhyN8XTMzv5Z
85	85	{87}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvC1C75Aqibitv2T1scWihM9Jx6EGXo1KTqcRE9BjU583pT3NMx
86	86	{88,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jte2CS3Jod6MEhRoydLSrTN5ynBAkxBNQyraHct6UX8NkGWV3EJ
87	87	{89}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvE3QZG9wiGgXqm9pHmt6Xot3b4xJS3EAnUzT1VKEZmfwJz2fCK
88	88	{90,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju7iV6xJfUTHGuBJWFRjHYjMWpFV4LxtSYoDQQtH4g84JQSU3SY
89	89	{91}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtg1VbMjGwN8F3v9TES7ashRUKMDRV9GguboNFA3yViAH6db7sf
90	90	{92,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju8ZzuExb687H87SDQRjwKs95SgYAsP6T3ZGHES8qLfBC5tATqc
91	91	{93}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju2pergF2gX8b5ap8ru9ftAQMN8aZr6cAsAqM1hgkZ1zt9P5SbH
92	92	{94,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuPYvcjq1jj6bjuVr7DsG6EhLtKD6AKE6p8g4m8Fqo8ipsSWSsW
93	93	{95}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JusQMq2BpkpoqzXLE2FSFLYDWYd24JbH9ypbr5A6hRB5dXxqDqV
94	94	{96,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jux8UMZUYNkEDagQiK4dUB61njcWZMmXTc92ZumATtukrPPtS7a
95	95	{97}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv79ng65kYxPVYFv5NJh8CVZV8UXkv1S21HTfnrLZv2nfEdw5Sx
96	96	{98,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv6oqWiB6zLSY8H8MQTeTcvyKCbvuE5wCz9XHBwAiQLG9N5xLF5
97	97	{99}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju3ZFbNTA3YdkP3CPtJYQo95TJUXxVyNuPGgRGJCQrbaXju7aHe
98	98	{100,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuMVp3Hbr3V5GHBUAnKqCQDFyk1xW2KZTX6adjEvbt5tzRt2vBT
99	99	{101}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuwNE3JyKbyU7Xoji3v34Rq1aZi3BpcBpd9Fi9W5evdpEusnDfa
100	100	{102,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvKLRoh84mPCV7opwq7qPPCYV7g6nCguA1L1rojQUKX9vswfSfU
101	101	{103}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtX7o2dqiePb5WhkQygGeW8Kue9HmPGEVf8YLLNqsdTgww1Ud6f
102	102	{104,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju9K5iZPe7WPwxSmprVuhFEbx6MqRyHiomuPW67ZkkJ79gWJVJn
103	103	{105}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtz5Hpisxfizer5AenvHgWrVxwhgyzQ6qjM3mCwAVsvLurcXqob
104	104	{106,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuX3oaQ9hzZRrf8sqLaxwdd98Jz4xSUa56h816jJoNoBkYytgng
105	105	{107}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvQCNxxn4dCiYBb87uwigGDfwCQDH5D49WwagXEZEGwtVZTRS2d
106	106	{108,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvRpUJsS5e7B7H2YEVouYoieYq1BKGRszPr8NZPfNwyKNbzfMXx
107	107	{109}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuPRt6TeheB3VHkqTQViqzpNnj5hY1CDmC2UAgcjuVsJjJdVbms
108	108	{110,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuXknQZYGY9ekJxWy7C7gEWChsr3EfqDrbhZFkNFch97WX7x9i2
109	109	{111}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuvzCEGLDRzP1Y8ry75eF9pffevkR4nKyvJLJCewZnnRkH88rPt
110	110	{112,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju2YVmBCwHRD58nGPzcF3TdKQY5YkGoDATCAqm5aTHRJdVpK8Uf
111	111	{113}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv7Ds6jXTjFeYJ1MbWn7rTejiE6oUke6BNRuy3sr4uJrCJdi5kJ
112	112	{114,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvNmQFLLhEQBrS91hiWqEStYYxxjJVAyYbwewN95cDeLo8s5S1W
113	113	{115}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvL5Jbr2GZnHigHRRpFyXTz2rVHhRdQc273wfvanhkXi2zoKUd6
114	114	{116,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtfQbnpgmi4NT2VH2XDTWcZ1eWzia6R3zZQAA9aDT1357HmeMVQ
115	115	{117}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JupXw6ErpYDS9qjbau54m6GZNhNu3BQFU3DDBCQTTxVPoFKDdQn
116	116	{118,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuLz1WA1HUCwHyK3hriXZmRJygMX24gLLozGDCzbDxtESdQHJpB
117	117	{119}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvLoav9GucUHawqJgQ8gGxKFAJgCA7xvpQDQhUZYFX8rrm4CixP
118	118	{120,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JumAw8yQaU9QqBmQ8cBM8MuqsRxEjbh1cjnGL4uHc2qkcgautez
119	119	{121}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv65F8ptoPt2LwAvfY15ixeu62R7LsP3gSJfiZNKmDn42irhyym
120	120	{122,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JufbNPC1uGbNJoLTG5oMmDbe4dpG9U6oCM2ptZwoGXRHMxqUtwV
121	121	{123}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvQvezE3kG1kD67sUoNC2hyFJYA5Vp1KZtcGE87FiQVvRvehDDb
122	122	{124,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuUVGMDZuphagtggQuhWGBXiqYVks8iAG82QJDL7x8GqhRQvDHS
123	123	{125}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuUxADrSwFsjAcT7aJhJmGVmDQD9jLaSaJPKKsMWYvfd4f2SUL7
124	124	{126,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JueQtW817hzpnCw5kJx9LGXU8i1wLnyhgCBXn8MQ1vJZmvYTVjb
125	125	{127}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuMpqg9ZcBeubyy87qxVugiqtP5pssG3BfAwEwXDsQUB2bxYJWs
126	126	{128,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtWyPeXcxwUBSrNqp9Zs7arnbLEmfcY9PY8h8m1hC5Ne5ea1eAj
127	127	{129}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juheg8PMs7Dh9qBjo8MDLeLwknjGPiJHMy41u8pNgRsrLeYPVfW
128	128	{130,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvHV1Xm5u2fznCdz93fLhU1mPzGS3jqq4SGXeArzq7Emwg9atgF
129	129	{131}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtwTS9VmBJeqo9T5HU98sWhWsehes2rYNhK6UvTvgYp88SrsaG5
130	130	{132,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtn9mauPtvDUvftRQg5c5yukLAZ8tXtLa3dH4jVATTrgUH4TLiX
131	131	{133}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvPeq2VKxVJDAfUps19JKb8LVuDbCbq36EJSaDMGHF6ZZXuxXeD
132	132	{134,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtjzdSzww3VnJBG7HprVpeBQXjt7x1uWrTF2noF1BQs3QKKCTgK
133	133	{135}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Junaiy8aGZ6nuYyZ8rCnUz3EMb6UG9UdvGMmVqQNB9dDrSWsgZA
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
1	226	5000000000	\N	0
2	226	5000000000	\N	1
3	226	5000000000	\N	2
4	226	5000000000	\N	3
5	226	5000000000	\N	4
6	226	5000000000	\N	5
7	226	5000000000	\N	6
8	226	5000000000	\N	7
9	226	5000000000	\N	8
10	226	5000000000	\N	9
11	226	5000000000	\N	10
12	226	5000000000	\N	11
13	226	5000000000	\N	12
14	226	5000000000	\N	13
15	226	5000000000	\N	14
16	226	5000000000	\N	15
17	226	5000000000	\N	16
18	226	5000000000	\N	17
19	226	5000000000	\N	18
20	226	5000000000	\N	19
21	226	5000000000	\N	20
22	226	5000000000	\N	21
23	226	5000000000	\N	22
24	226	5000000000	\N	23
25	226	5000000000	\N	24
26	226	5000000000	\N	25
27	226	5000000000	\N	26
28	226	5000000000	\N	27
29	226	5000000000	\N	28
30	226	5000000000	\N	29
31	226	5000000000	\N	30
32	226	5000000000	\N	31
33	226	5000000000	\N	32
34	226	5000000000	\N	33
35	226	5000000000	\N	34
36	226	5000000000	\N	35
37	226	5000000000	\N	36
38	226	5000000000	\N	37
39	226	5000000000	\N	38
40	226	5000000000	\N	39
41	226	5000000000	\N	40
42	226	5000000000	\N	41
43	226	5000000000	\N	42
44	226	5000000000	\N	43
45	226	5000000000	\N	44
46	226	5000000000	\N	45
47	226	5000000000	\N	46
48	226	5000000000	\N	47
49	226	5000000000	\N	48
50	226	5000000000	\N	49
51	226	5000000000	\N	50
52	226	5000000000	\N	51
53	226	5000000000	\N	52
54	226	5000000000	\N	53
55	226	5000000000	\N	54
56	226	5000000000	\N	55
57	226	5000000000	\N	56
58	226	5000000000	\N	57
59	226	5000000000	\N	58
60	226	5000000000	\N	59
61	226	5000000000	\N	60
62	226	5000000000	\N	61
63	226	5000000000	\N	62
64	226	5000000000	\N	63
65	226	5000000000	\N	64
66	226	5000000000	\N	65
67	226	5000000000	\N	66
68	226	5000000000	\N	67
69	226	5000000000	\N	68
70	226	5000000000	\N	69
71	226	5000000000	\N	70
72	226	5000000000	\N	71
73	226	5000000000	\N	72
74	226	5000000000	\N	73
75	226	5000000000	\N	74
76	226	5000000000	\N	75
77	226	5000000000	\N	76
78	226	5000000000	\N	77
79	226	5000000000	\N	78
80	226	5000000000	\N	79
81	226	5000000000	\N	80
82	226	5000000000	\N	81
83	226	5000000000	\N	82
84	226	5000000000	\N	83
85	226	5000000000	\N	84
86	226	5000000000	\N	85
87	226	5000000000	\N	86
88	226	5000000000	\N	87
89	226	5000000000	\N	88
90	226	5000000000	\N	89
91	226	5000000000	\N	90
92	226	5000000000	\N	91
93	226	5000000000	\N	92
94	226	5000000000	\N	93
95	226	5000000000	\N	94
96	226	5000000000	\N	95
97	226	5000000000	\N	96
98	226	5000000000	\N	97
99	226	5000000000	\N	98
100	226	5000000000	\N	99
101	226	5000000000	\N	100
102	226	5000000000	\N	101
103	226	5000000000	\N	102
104	226	5000000000	\N	103
105	226	5000000000	\N	104
106	226	5000000000	\N	105
107	226	5000000000	\N	106
108	226	5000000000	\N	107
109	226	5000000000	\N	108
110	226	5000000000	\N	109
111	226	5000000000	\N	110
112	226	5000000000	\N	111
113	226	5000000000	\N	112
114	226	5000000000	\N	113
115	226	5000000000	\N	114
116	226	5000000000	\N	115
117	226	5000000000	\N	116
118	226	5000000000	\N	117
119	226	5000000000	\N	118
120	226	5000000000	\N	119
121	226	5000000000	\N	120
122	226	5000000000	\N	121
123	226	5000000000	\N	122
124	226	5000000000	\N	123
125	226	5000000000	\N	124
126	226	5000000000	\N	125
127	226	5000000000	\N	126
128	226	5000000000	\N	127
129	226	5000000000	\N	128
130	226	5000000000	\N	129
131	226	5000000000	\N	130
132	226	5000000000	\N	131
133	226	5000000000	\N	132
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

SELECT pg_catalog.setval('public.blocks_id_seq', 39, true);


--
-- Name: epoch_data_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.epoch_data_id_seq', 40, true);


--
-- Name: internal_commands_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.internal_commands_id_seq', 37, true);


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

SELECT pg_catalog.setval('public.user_commands_id_seq', 61, true);


--
-- Name: voting_for_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.voting_for_id_seq', 1, true);


--
-- Name: zkapp_account_precondition_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_account_precondition_id_seq', 68, true);


--
-- Name: zkapp_account_update_body_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_account_update_body_id_seq', 135, true);


--
-- Name: zkapp_account_update_failures_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_account_update_failures_id_seq', 4, true);


--
-- Name: zkapp_account_update_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_account_update_id_seq', 135, true);


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

SELECT pg_catalog.setval('public.zkapp_commands_id_seq', 133, true);


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

SELECT pg_catalog.setval('public.zkapp_fee_payer_body_id_seq', 133, true);


--
-- Name: zkapp_field_array_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_field_array_id_seq', 1, false);


--
-- Name: zkapp_field_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_field_id_seq', 66, true);


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

SELECT pg_catalog.setval('public.zkapp_nonce_bounds_id_seq', 67, true);


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

SELECT pg_catalog.setval('public.zkapp_states_nullable_id_seq', 67, true);


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

SELECT pg_catalog.setval('public.zkapp_updates_id_seq', 68, true);


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

