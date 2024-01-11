--
-- PostgreSQL database dump
--

-- Dumped from database version 12.16 (Ubuntu 12.16-0ubuntu0.20.04.1)
-- Dumped by pg_dump version 12.16 (Ubuntu 12.16-0ubuntu0.20.04.1)

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
    set_verification_key public.zkapp_auth_required_type NOT NULL,
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
146	148	1
147	149	1
148	150	1
149	151	1
150	97	1
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
10	1	1	1	285	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	2	1	1	1	\N
107	1	2	1	500	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	3	1	2	1	\N
81	1	3	1	331	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	4	1	3	1	\N
32	1	4	1	226	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	5	1	4	1	\N
12	1	5	1	123	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	6	1	5	1	\N
5	1	6	1	0	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	7	1	6	1	\N
78	1	7	1	292	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	8	1	7	1	\N
121	1	8	1	104	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	9	1	8	1	\N
176	1	9	1	10	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	10	1	9	1	\N
236	1	10	1	488	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	11	1	10	1	\N
226	1	11	1	469	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	12	1	11	1	\N
19	1	12	1	242	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	13	1	12	1	\N
128	1	13	1	135	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	14	1	13	1	\N
94	1	14	1	196	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	15	1	14	1	\N
153	1	15	1	79	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	16	1	15	1	\N
166	1	16	1	206	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	17	1	16	1	\N
137	1	17	1	340	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	18	1	17	1	\N
105	1	18	1	382	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	19	1	18	1	\N
70	1	19	1	488	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	20	1	19	1	\N
27	1	20	1	135	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	21	1	20	1	\N
46	1	21	1	126	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	22	1	21	1	\N
43	1	22	1	10	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	23	1	22	1	\N
117	1	23	1	278	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	24	1	23	1	\N
204	1	24	1	46	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	25	1	24	1	\N
187	1	25	1	104	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	26	1	25	1	\N
72	1	26	1	10	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	27	1	26	1	\N
216	1	27	1	271	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	28	1	27	1	\N
210	1	28	1	315	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	29	1	28	1	\N
79	1	29	1	162	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	30	1	29	1	\N
167	1	30	1	86	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	31	1	30	1	\N
181	1	31	1	409	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	32	1	31	1	\N
156	1	32	1	500	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	33	1	32	1	\N
96	1	33	1	57	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	34	1	33	1	\N
191	1	34	1	204	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	35	1	34	1	\N
132	1	35	1	262	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	36	1	35	1	\N
111	1	36	1	10	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	37	1	36	1	\N
171	1	37	1	156	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	38	1	37	1	\N
64	1	38	1	417	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	39	1	38	1	\N
68	1	39	1	10	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	40	1	39	1	\N
51	1	40	1	85	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	41	1	40	1	\N
227	1	41	1	103	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	42	1	41	1	\N
141	1	42	1	67	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	43	1	42	1	\N
42	1	43	1	10	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	44	1	43	1	\N
133	1	44	1	500	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	45	1	44	1	\N
82	1	45	1	198	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	46	1	45	1	\N
95	1	46	1	489	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	47	1	46	1	\N
188	1	47	1	298	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	48	1	47	1	\N
30	1	48	1	36	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	49	1	48	1	\N
90	1	49	1	334	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	50	1	49	1	\N
14	1	50	1	344	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	51	1	50	1	\N
35	1	51	1	451	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	52	1	51	1	\N
85	1	52	1	371	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	53	1	52	1	\N
127	1	53	1	234	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	54	1	53	1	\N
222	1	54	1	345	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	55	1	54	1	\N
76	1	55	1	282	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	56	1	55	1	\N
231	1	56	1	339	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	57	1	56	1	\N
15	1	57	1	215	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	58	1	57	1	\N
220	1	58	1	193	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	59	1	58	1	\N
16	1	59	1	60	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	60	1	59	1	\N
58	1	60	1	350	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	61	1	60	1	\N
146	1	61	1	223	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	62	1	61	1	\N
62	1	62	1	449	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	63	1	62	1	\N
185	1	63	1	142	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	64	1	63	1	\N
151	1	64	1	300	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	65	1	64	1	\N
165	1	65	1	256	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	66	1	65	1	\N
103	1	66	1	125	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	67	1	66	1	\N
41	1	67	1	236	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	68	1	67	1	\N
239	1	68	1	10	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	69	1	68	1	\N
110	1	69	1	179	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	70	1	69	1	\N
13	1	70	1	194	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	71	1	70	1	\N
26	1	71	1	185	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	72	1	71	1	\N
98	1	72	1	342	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	73	1	72	1	\N
215	1	73	1	157	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	74	1	73	1	\N
3	1	74	1	500000000000	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	75	1	74	1	\N
91	1	75	1	135	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	76	1	75	1	\N
159	1	76	1	456	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	77	1	76	1	\N
208	1	77	1	336	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	78	1	77	1	\N
207	1	78	1	280	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	79	1	78	1	\N
182	1	79	1	187	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	80	1	79	1	\N
157	1	80	1	387	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	81	1	80	1	\N
33	1	81	1	500	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	82	1	81	1	\N
201	1	82	1	151	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	83	1	82	1	\N
9	1	83	1	356	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	84	1	83	1	\N
234	1	84	1	24	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	85	1	84	1	\N
40	1	85	1	152	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	86	1	85	1	\N
18	1	86	1	10	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	87	1	86	1	\N
229	1	87	1	500	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	88	1	87	1	\N
20	1	88	1	186	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	89	1	88	1	\N
184	1	89	1	266	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	90	1	89	1	\N
139	1	90	1	81	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	91	1	90	1	\N
164	1	91	1	10	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	92	1	91	1	\N
199	1	92	1	379	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	93	1	92	1	\N
109	1	93	1	315	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	94	1	93	1	\N
47	1	94	1	226	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	95	1	94	1	\N
6	1	95	1	11550000000000000	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	97	1	95	1	\N
214	1	96	1	166	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	98	1	96	1	\N
112	1	97	1	302	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	99	1	97	1	\N
144	1	98	1	269	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	100	1	98	1	\N
178	1	99	1	172	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	101	1	99	1	\N
1	1	100	1	5000000000	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	102	1	100	1	\N
155	1	101	1	195	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	103	1	101	1	\N
38	1	102	1	243	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	104	1	102	1	\N
80	1	103	1	128	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	105	1	103	1	\N
147	1	104	1	349	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	106	1	104	1	\N
24	1	105	1	87	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	107	1	105	1	\N
126	1	106	1	424	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	108	1	106	1	\N
89	1	107	1	239	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	109	1	107	1	\N
135	1	108	1	316	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	110	1	108	1	\N
194	1	109	1	492	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	111	1	109	1	\N
190	1	110	1	294	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	112	1	110	1	\N
218	1	111	1	191	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	113	1	111	1	\N
93	1	112	1	380	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	114	1	112	1	\N
162	1	113	1	331	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	115	1	113	1	\N
221	1	114	1	459	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	116	1	114	1	\N
205	1	115	1	28	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	117	1	115	1	\N
195	1	116	1	472	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	118	1	116	1	\N
34	1	117	1	119	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	119	1	117	1	\N
213	1	118	1	10	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	120	1	118	1	\N
196	1	119	1	41	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	121	1	119	1	\N
104	1	120	1	27	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	122	1	120	1	\N
44	1	121	1	70	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	123	1	121	1	\N
52	1	122	1	337	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	124	1	122	1	\N
114	1	123	1	210	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	125	1	123	1	\N
177	1	124	1	495	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	126	1	124	1	\N
148	1	125	1	144	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	127	1	125	1	\N
100	1	126	1	148	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	128	1	126	1	\N
206	1	127	1	376	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	129	1	127	1	\N
28	1	128	1	329	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	130	1	128	1	\N
173	1	129	1	500	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	131	1	129	1	\N
130	1	130	1	500	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	132	1	130	1	\N
39	1	131	1	181	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	133	1	131	1	\N
212	1	132	1	200	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	134	1	132	1	\N
116	1	133	1	159	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	135	1	133	1	\N
48	1	134	1	319	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	136	1	134	1	\N
101	1	135	1	10	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	137	1	135	1	\N
203	1	136	1	365	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	138	1	136	1	\N
50	1	137	1	342	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	139	1	137	1	\N
59	1	138	1	237	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	140	1	138	1	\N
150	1	139	1	427	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	141	1	139	1	\N
180	1	140	1	315	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	142	1	140	1	\N
142	1	141	1	10	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	143	1	141	1	\N
23	1	142	1	378	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	144	1	142	1	\N
122	1	143	1	420	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	145	1	143	1	\N
115	1	144	1	411	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	146	1	144	1	\N
75	1	145	1	172	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	147	1	145	1	\N
77	1	146	1	309	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	148	1	146	1	\N
152	1	147	1	10	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	149	1	147	1	\N
120	1	148	1	154	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	150	1	148	1	\N
118	1	149	1	153	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	151	1	149	1	\N
7	1	150	1	0	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	97	1	150	1	\N
37	1	151	1	47	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	152	1	151	1	\N
168	1	152	1	87	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	153	1	152	1	\N
149	1	153	1	398	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	154	1	153	1	\N
29	1	154	1	452	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	155	1	154	1	\N
8	1	155	1	283	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	156	1	155	1	\N
88	1	156	1	291	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	157	1	156	1	\N
233	1	157	1	367	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	158	1	157	1	\N
83	1	158	1	500	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	159	1	158	1	\N
154	1	159	1	311	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	160	1	159	1	\N
4	1	160	1	11550000000000000	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	7	1	160	1	\N
175	1	161	1	258	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	162	1	161	1	\N
69	1	162	1	323	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	163	1	162	1	\N
63	1	163	1	405	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	164	1	163	1	\N
189	1	164	1	32	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	165	1	164	1	\N
92	1	165	1	130	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	166	1	165	1	\N
140	1	166	1	234	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	167	1	166	1	\N
17	1	167	1	500	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	168	1	167	1	\N
87	1	168	1	481	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	169	1	168	1	\N
183	1	169	1	240	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	170	1	169	1	\N
129	1	170	1	314	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	171	1	170	1	\N
193	1	171	1	183	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	172	1	171	1	\N
174	1	172	1	486	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	173	1	172	1	\N
57	1	173	1	178	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	174	1	173	1	\N
224	1	174	1	65	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	175	1	174	1	\N
232	1	175	1	277	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	176	1	175	1	\N
119	1	176	1	433	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	177	1	176	1	\N
55	1	177	1	100	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	178	1	177	1	\N
169	1	178	1	272	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	179	1	178	1	\N
125	1	179	1	10	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	180	1	179	1	\N
45	1	180	1	212	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	181	1	180	1	\N
60	1	181	1	151	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	182	1	181	1	\N
99	1	182	1	387	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	183	1	182	1	\N
179	1	183	1	158	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	184	1	183	1	\N
49	1	184	1	440	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	185	1	184	1	\N
230	1	185	1	438	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	186	1	185	1	\N
131	1	186	1	500	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	187	1	186	1	\N
0	1	187	1	1000	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	1	1	187	1	\N
186	1	188	1	290	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	188	1	188	1	\N
198	1	189	1	417	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	189	1	189	1	\N
202	1	190	1	375	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	190	1	190	1	\N
22	1	191	1	178	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	191	1	191	1	\N
102	1	192	1	59	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	192	1	192	1	\N
124	1	193	1	95	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	193	1	193	1	\N
200	1	194	1	394	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	194	1	194	1	\N
54	1	195	1	500	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	195	1	195	1	\N
225	1	196	1	256	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	196	1	196	1	\N
134	1	197	1	128	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	197	1	197	1	\N
97	1	198	1	199	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	198	1	198	1	\N
84	1	199	1	22	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	199	1	199	1	\N
161	1	200	1	276	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	200	1	200	1	\N
228	1	201	1	451	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	201	1	201	1	\N
238	1	202	1	133	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	202	1	202	1	\N
65	1	203	1	460	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	203	1	203	1	\N
219	1	204	1	500	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	204	1	204	1	\N
56	1	205	1	489	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	205	1	205	1	\N
2	1	206	1	65500000000000	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	75	1	206	1	\N
163	1	207	1	190	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	207	1	207	1	\N
192	1	208	1	221	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	208	1	208	1	\N
143	1	209	1	464	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	209	1	209	1	\N
61	1	210	1	10	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	210	1	210	1	\N
136	1	211	1	500	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	211	1	211	1	\N
71	1	212	1	353	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	212	1	212	1	\N
145	1	213	1	396	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	213	1	213	1	\N
106	1	214	1	417	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	214	1	214	1	\N
138	1	215	1	46	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	215	1	215	1	\N
158	1	216	1	305	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	216	1	216	1	\N
123	1	217	1	337	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	217	1	217	1	\N
25	1	218	1	444	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	218	1	218	1	\N
240	1	219	1	479	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	219	1	219	1	\N
211	1	220	1	344	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	220	1	220	1	\N
241	1	221	1	113	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	221	1	221	1	\N
197	1	222	1	236	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	222	1	222	1	\N
170	1	223	1	480	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	223	1	223	1	\N
31	1	224	1	160	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	224	1	224	1	\N
160	1	225	1	318	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	225	1	225	1	\N
21	1	226	1	214	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	226	1	226	1	\N
67	1	227	1	163	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	227	1	227	1	\N
66	1	228	1	500	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	228	1	228	1	\N
108	1	229	1	366	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	229	1	229	1	\N
86	1	230	1	320	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	230	1	230	1	\N
237	1	231	1	407	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	231	1	231	1	\N
74	1	232	1	204	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	232	1	232	1	\N
73	1	233	1	341	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	233	1	233	1	\N
217	1	234	1	18	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	234	1	234	1	\N
36	1	235	1	229	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	235	1	235	1	\N
172	1	236	1	477	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	236	1	236	1	\N
53	1	237	1	94	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	237	1	237	1	\N
235	1	238	1	126	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	238	1	238	1	\N
113	1	239	1	112	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	239	1	239	1	\N
223	1	240	1	387	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	240	1	240	1	\N
209	1	241	1	265	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	241	1	241	1	\N
11	1	242	1	269	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	242	1	242	1	\N
3	2	74	1	499750000000	1	2n1w5Q8vCgyxzKzp3mEEL371He1UmN2vmPreEnVSetrDqCo5aFP1	75	1	74	1	\N
7	2	150	1	725250000000	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	97	1	150	1	\N
4	2	160	1	11549995000000000	1	2n1AwgLqpEggvAPTKtdzEiKKbj1MkPDiqfKMELNobugxQTBAGsAJ	7	1	160	1	\N
3	3	74	1	496750000000	13	2n1bv5yhoZMQ811ATHE9TuQuK8MPYBusWztBD9e2PpRH99AgDSaF	75	1	74	1	\N
7	3	150	1	1558250000000	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	97	1	150	1	\N
4	3	160	1	11549885000000000	23	2mzhSXRbt7RBByzoboE1H5u4Ugea6YBq6RWz3X7HNm3byYNTpiWC	7	1	160	1	\N
5	4	6	1	833000000000	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	7	1	6	1	\N
3	4	74	1	496750000000	13	2n1bv5yhoZMQ811ATHE9TuQuK8MPYBusWztBD9e2PpRH99AgDSaF	75	1	74	1	\N
4	4	160	1	11549885000000000	23	2mzhSXRbt7RBByzoboE1H5u4Ugea6YBq6RWz3X7HNm3byYNTpiWC	7	1	160	1	\N
5	5	6	1	807000000000	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	7	1	6	1	\N
3	5	74	1	494750000000	21	2n2FyeU3yzAVZYYDQkyPnCouctK85idey24n4mHMtvdRfVjttPrT	75	1	74	1	\N
4	5	160	1	11549800000000000	40	2mzatzhRN9RCQYvJgsGBSF2LQdNxqP4XwWyjREaimE2T3LMk64ws	7	1	160	1	\N
3	6	74	1	492750000000	29	2mzYD6pTYYPtACSn4syfyNtbyDV6D5Y7cDA4fRXC39ak7cPrUE3J	75	1	74	1	\N
7	6	150	1	2365250000000	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	97	1	150	1	\N
4	6	160	1	11549715000000000	57	2n1SosT8PPnXsNimKGckCx1JXMHRkbvEnMkYXQZbTqEHGqsdH2pj	7	1	160	1	\N
5	7	6	1	1614250000000	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	7	1	6	1	\N
3	7	74	1	490500000000	38	2n19Pmphgs7JxTA6yhQp5ur8YqxotPKqoRFVYwwZF2CPgCRMXNTH	75	1	74	1	\N
4	7	160	1	11549630000000000	74	2n1HGuwvXhKmTucpYaJccqFTZhJZKy5jcLrje9wUfjG1mtgPpQzW	7	1	160	1	\N
3	8	74	1	490500000000	38	2n19Pmphgs7JxTA6yhQp5ur8YqxotPKqoRFVYwwZF2CPgCRMXNTH	75	1	74	1	\N
7	8	150	1	3172500000000	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	97	1	150	1	\N
4	8	160	1	11549630000000000	74	2n1HGuwvXhKmTucpYaJccqFTZhJZKy5jcLrje9wUfjG1mtgPpQzW	7	1	160	1	\N
5	9	6	1	2421250000000	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	7	1	6	1	\N
3	9	74	1	488500000000	46	2mzzMeB15JTeem44mZ4x6p6dFWM16p4UXFjP4fNJz7wXBFcMW5ps	75	1	74	1	\N
4	9	160	1	11549545000000000	91	2mzjiYE1H7C7yLejpd8tTFe7EbA2zs5PiN1ESTqRKwymEcd1sdnK	7	1	160	1	\N
5	10	6	1	3228500000000	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	7	1	6	1	\N
3	10	74	1	486250000000	55	2n2FKShqJCt1TnBmnFy5NXRFBzcXKVnvCoDKtdUGAvpmKYwmpz9J	75	1	74	1	\N
4	10	160	1	11549460000000000	108	2n1eJngaiKa7ZtTA5dDPNNekXRHiZrkeHWvAMLgeFLSnGnXNkj5j	7	1	160	1	\N
3	11	74	1	484250000000	63	2n1Sox1V2xJogEYVavNTYW8s8P5SXNCtyLHtCfxnCEhES1c7VDAm	75	1	74	1	\N
7	11	150	1	3172250000000	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	97	1	150	1	\N
4	11	160	1	11549375000000000	125	2n243vFgrwHQ7U7bhZdkfuDBUsRKaf3CRWcyQrD2fjVoxg5tAfGj	7	1	160	1	\N
5	12	6	1	4035750000000	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	7	1	6	1	\N
3	12	74	1	482000000000	72	2n1trpzwMbSEVQXbGrZ7e5Ug6xQVPB9GXScqKTApk33j6NnVb924	75	1	74	1	\N
4	12	160	1	11549290000000000	142	2n1rjkm5oSUpepSmi2uivxnsfChWPXWimdHNJThMU6B546k154JQ	7	1	160	1	\N
3	13	74	1	482000000000	72	2n1trpzwMbSEVQXbGrZ7e5Ug6xQVPB9GXScqKTApk33j6NnVb924	75	1	74	1	\N
7	13	150	1	3979500000000	0	2n1hGCgg3jCKQJzVBgfujGqyV6D9riKgq27zhXqYgTRVZM5kqfkm	97	1	150	1	\N
4	13	160	1	11549290000000000	142	2n1rjkm5oSUpepSmi2uivxnsfChWPXWimdHNJThMU6B546k154JQ	7	1	160	1	\N
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
1	3NLUQWTbi4vtHYzGM2MZic9v51R4QJJit3pbxx4dPMA1w1zhyeSP	\N	3NKiuQZnXcHcz1N99e7PnVdSNt8dc3Ku7KT1cNHUQhNJv9svMvhh	1	1	39cyg4ZmMtnb_aFUIerNAoAJV8qtkfOpq0zFzPspjgM=	1	1	2	77	{1,7,7,7,7,7,7,7,7,7,7}	23166005000061388	jxMSC7rer8PqzEig8LujhfSsqWu4AETJ5D7f23HCHrcWVYMZcXC	1	0	0	1	\N	1702331186000	canonical
2	3NKu2nh1N1i3AXgJVKenUAgRMsF4w1NxWVtwcHwhhCAqRz3UDtCx	1	3NLUQWTbi4vtHYzGM2MZic9v51R4QJJit3pbxx4dPMA1w1zhyeSP	97	96	9BYTAMp7Ga9Xmv4RaZKVDCCYzijXXytGVg1H_BdQhAM=	1	1	3	77	{2,7,7,7,7,7,7,7,7,7,7}	23166005000061388	jxu2GeeyU57CWkPnAcAV7e2qpfAKMYjnWUdL6vUwPJ9ULjwZUiz	2	4	4	1	\N	1702332024849	pending
3	3NLZvjMBG4R4AziCrmsyK9RJWLC1br9iMAxUMLCV9GvmcjR67sbj	2	3NKu2nh1N1i3AXgJVKenUAgRMsF4w1NxWVtwcHwhhCAqRz3UDtCx	97	96	h8O_l74faIHPkCwRwwS9_XXVigLPrrseq-M8l2-C5gA=	1	1	4	77	{3,7,7,7,7,7,7,7,7,7,7}	23166005000061388	jxobVoH4L3pBtnVgeghn4vJnZfTqayUxaXKnNHYYzKKH2a8hzMB	3	6	6	1	\N	1702332266000	pending
4	3NL4gERLJWc7yzHmEFgvrPEmgAfWYX41d92xD1yqD9kuWsEEig8q	2	3NKu2nh1N1i3AXgJVKenUAgRMsF4w1NxWVtwcHwhhCAqRz3UDtCx	7	161	jUWKsm4sn9tFlJo4YOcSDAkKVJjdvWaFalXYSGcU_Qc=	1	1	5	77	{3,7,7,7,7,7,7,7,7,7,7}	23166005000061388	jxJwQo5zgcXaXHSzB5Dcw51WLrnPndYvzzS25kzUWGEBYCWHPag	3	6	6	1	\N	1702332266000	pending
5	3NKngXmbkh1QboN7HcezcH2ziHFbVBuyt15tFMPStexZkkbcNwxu	3	3NLZvjMBG4R4AziCrmsyK9RJWLC1br9iMAxUMLCV9GvmcjR67sbj	7	161	8HV19ck0r8egQAHEh5B3FrbBeXb-JIyZ8uSEMZdPcwA=	1	1	6	77	{3,1,7,7,7,7,7,7,7,7,7}	23166005000061388	jwMytdxy2Qerb3ANLQF5Y8qt2A3BZNSTZANaWF1G5PAnATXC1Ng	4	7	7	1	\N	1702332446000	pending
6	3NL4SeyFfDxSooESJiLFfwogpkDVgKuNUPTLZMkF1tead7fapgdo	5	3NKngXmbkh1QboN7HcezcH2ziHFbVBuyt15tFMPStexZkkbcNwxu	97	96	MktfsU3LbeImP_dDMPetRn1hlXqJkqWb33t-Oi5DogY=	1	1	7	77	{3,2,7,7,7,7,7,7,7,7,7}	23166005000061388	jwBBsXxf5qM5hwUNyySf5TEWFaDSEhksJ4idbiRczEpvwjNNVPV	5	8	8	1	\N	1702332626000	pending
7	3NLdy7iVttfzGiNvscFGGCJyQQSDaQXkDi8MojhBV7CwaVfd9cTG	6	3NL4SeyFfDxSooESJiLFfwogpkDVgKuNUPTLZMkF1tead7fapgdo	7	161	kseLpLXYuoMANYaMbSnwhnJ_uKrDYZX5MUhgbZ0OUwk=	1	1	8	77	{3,3,7,7,7,7,7,7,7,7,7}	23166005000061388	jxnVAUTZPT2GLiyh5E3pWGmirn5RNCSRnK7oeukHTzppWDunP5q	6	9	9	1	\N	1702332806000	pending
8	3NKguNbqF2PfVt5CVrnxUKeAnmr7vkNA7DEiVHR2S1KzKo7s6Z8f	6	3NL4SeyFfDxSooESJiLFfwogpkDVgKuNUPTLZMkF1tead7fapgdo	97	96	WHiGP0j9g_aLyGFs8YLzptAksD7UShELzkeLV5CFSg0=	1	1	9	77	{3,3,7,7,7,7,7,7,7,7,7}	23166005000061388	jxA13f8pn9zNxM4uadzKiKJXBkM831SUf3SQzQdfHBtfgxaSEra	6	9	9	1	\N	1702332806000	pending
9	3NLV8muTbbUhjibRYWovz4z98e9RK64J713G95G15poCYvxvNWg4	7	3NLdy7iVttfzGiNvscFGGCJyQQSDaQXkDi8MojhBV7CwaVfd9cTG	7	161	K15Q0QjO62_mUnBHiwA0TLPSUlnBL6mNNmhAPeTNIQk=	1	1	10	77	{3,4,7,7,7,7,7,7,7,7,7}	23166005000061388	jxmhqTSmkVb8dxB9VnobwZwtDpZFC7m8vT8YUHpbinpwi1eySVd	7	10	10	1	\N	1702332986000	pending
10	3NL8eePFe6GCx1gVoWnU2zAZAsWjnJTLNCweptxahDXEsnDm1iMm	9	3NLV8muTbbUhjibRYWovz4z98e9RK64J713G95G15poCYvxvNWg4	7	161	lkM_prqO2YnhtIbpTnnreSmrHzg__DcmelI_iXrVjQ0=	1	1	11	77	{3,5,7,7,7,7,7,7,7,7,7}	23166005000061388	jxaUKY9NG6UXMEkPNpiy7AsJskppn39feVSFx7PivktEK42V5T6	8	11	11	1	\N	1702333166000	pending
11	3NKs8ugWuKYypPMDTPZz6PjZyFe3usVK5shzftFP4xPn9enWe1YF	10	3NL8eePFe6GCx1gVoWnU2zAZAsWjnJTLNCweptxahDXEsnDm1iMm	97	96	vij6SWXMhAp4VKJMWP_F5TNmJvNcIV3iVyNSq0WJ_wY=	1	1	12	77	{3,6,7,7,7,7,7,7,7,7,7}	23166005000061388	jxFe4HKTKU7yNdrrGs5n3D4GDizvtUoKfU7TPrAmFYu2BtDJnKX	9	12	12	1	\N	1702333346000	pending
12	3NK4VTsPEG1xLnL78qcAZNzDP8XC2n56U8xFQWMTfzCCc4QSYvKT	11	3NKs8ugWuKYypPMDTPZz6PjZyFe3usVK5shzftFP4xPn9enWe1YF	7	161	1KaD7jgdU0IA4U8wnJDFMd3tzsyswckMXsr5St4VVg4=	1	1	13	77	{3,7,7,7,7,7,7,7,7,7,7}	23166005000061388	jxz8dMnhGEyMuAUZxZwBdsWMF6PHymSBNqMJNWHtB4Wr6NKCaVq	10	13	13	1	\N	1702333526000	pending
13	3NKsyvrS5sw6LSq4BaNBnn5cXxFR4adRADyL21J1S8ZxrJPmAxcD	11	3NKs8ugWuKYypPMDTPZz6PjZyFe3usVK5shzftFP4xPn9enWe1YF	97	96	gJcea1QZdjSNdmG2NdW_so0DfHQwFHoNxIYKGHYEdgs=	1	1	14	77	{3,7,7,7,7,7,7,7,7,7,7}	23166005000061388	jxm4ovWL7ZhhRKPH3LTLj5kZyTR5U9pvicFhSGM1hvqWBgP1sxs	10	13	13	1	\N	1702333526000	pending
\.


--
-- Data for Name: blocks_internal_commands; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.blocks_internal_commands (block_id, internal_command_id, sequence_no, secondary_sequence_no, status, failure_reason) FROM stdin;
2	1	2	0	applied	\N
2	2	3	0	applied	\N
3	1	34	0	applied	\N
3	3	35	0	applied	\N
4	4	34	0	applied	\N
4	5	35	0	applied	\N
5	4	25	0	applied	\N
5	6	26	0	applied	\N
6	1	25	0	applied	\N
6	7	26	0	applied	\N
7	4	26	0	applied	\N
7	8	27	0	applied	\N
8	1	26	0	applied	\N
8	9	27	0	applied	\N
9	10	5	0	applied	\N
9	4	26	0	applied	\N
9	11	27	0	applied	\N
10	4	26	0	applied	\N
10	8	27	0	applied	\N
11	1	25	0	applied	\N
11	7	26	0	applied	\N
12	4	26	0	applied	\N
12	8	27	0	applied	\N
13	1	26	0	applied	\N
13	9	27	0	applied	\N
\.


--
-- Data for Name: blocks_user_commands; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.blocks_user_commands (block_id, user_command_id, sequence_no, status, failure_reason) FROM stdin;
2	1	1	applied	\N
3	2	22	applied	\N
3	3	23	applied	\N
3	4	24	applied	\N
3	5	25	applied	\N
3	6	26	applied	\N
3	7	27	applied	\N
3	8	28	applied	\N
3	9	29	applied	\N
3	10	30	applied	\N
3	11	31	applied	\N
3	12	32	applied	\N
3	13	33	applied	\N
4	2	22	applied	\N
4	3	23	applied	\N
4	4	24	applied	\N
4	5	25	applied	\N
4	6	26	applied	\N
4	7	27	applied	\N
4	8	28	applied	\N
4	9	29	applied	\N
4	10	30	applied	\N
4	11	31	applied	\N
4	12	32	applied	\N
4	13	33	applied	\N
5	14	17	applied	\N
5	15	18	applied	\N
5	16	19	applied	\N
5	17	20	applied	\N
5	18	21	applied	\N
5	19	22	applied	\N
5	20	23	applied	\N
5	21	24	applied	\N
6	22	17	applied	\N
6	23	18	applied	\N
6	24	19	applied	\N
6	25	20	applied	\N
6	26	21	applied	\N
6	27	22	applied	\N
6	28	23	applied	\N
6	29	24	applied	\N
7	30	17	applied	\N
7	31	18	applied	\N
7	32	19	applied	\N
7	33	20	applied	\N
7	34	21	applied	\N
7	35	22	applied	\N
7	36	23	applied	\N
7	37	24	applied	\N
7	38	25	applied	\N
8	30	17	applied	\N
8	31	18	applied	\N
8	32	19	applied	\N
8	33	20	applied	\N
8	34	21	applied	\N
8	35	22	applied	\N
8	36	23	applied	\N
8	37	24	applied	\N
8	38	25	applied	\N
9	39	18	applied	\N
9	40	19	applied	\N
9	41	20	applied	\N
9	42	21	applied	\N
9	43	22	applied	\N
9	44	23	applied	\N
9	45	24	applied	\N
9	46	25	applied	\N
10	47	17	applied	\N
10	48	18	applied	\N
10	49	19	applied	\N
10	50	20	applied	\N
10	51	21	applied	\N
10	52	22	applied	\N
10	53	23	applied	\N
10	54	24	applied	\N
10	55	25	applied	\N
11	56	17	applied	\N
11	57	18	applied	\N
11	58	19	applied	\N
11	59	20	applied	\N
11	60	21	applied	\N
11	61	22	applied	\N
11	62	23	applied	\N
11	63	24	applied	\N
12	64	17	applied	\N
12	65	18	applied	\N
12	66	19	applied	\N
12	67	20	applied	\N
12	68	21	applied	\N
12	69	22	applied	\N
12	70	23	applied	\N
12	71	24	applied	\N
12	72	25	applied	\N
13	64	17	applied	\N
13	65	18	applied	\N
13	66	19	applied	\N
13	67	20	applied	\N
13	68	21	applied	\N
13	69	22	applied	\N
13	70	23	applied	\N
13	71	24	applied	\N
13	72	25	applied	\N
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
4	2	0	failed	{3,2}
4	3	1	failed	{4}
4	4	2	failed	{3,2}
4	5	3	failed	{4}
4	6	4	failed	{3,2}
4	7	5	failed	{4}
4	8	6	failed	{3,2}
4	9	7	failed	{4}
4	10	8	failed	{3,2}
4	11	9	failed	{4}
4	12	10	failed	{3,2}
4	13	11	failed	{4}
4	14	12	failed	{3,2}
4	15	13	failed	{4}
4	16	14	failed	{3,2}
4	17	15	failed	{4}
4	18	16	failed	{3,2}
4	19	17	failed	{4}
4	20	18	failed	{3,2}
4	21	19	failed	{4}
4	22	20	failed	{3,2}
4	23	21	failed	{4}
5	24	0	failed	{3,2}
5	25	1	failed	{4}
5	26	2	failed	{3,2}
5	27	3	failed	{4}
5	28	4	failed	{3,2}
5	29	5	failed	{4}
5	30	6	failed	{3,2}
5	31	7	failed	{4}
5	32	8	failed	{3,2}
5	33	9	failed	{4}
5	34	10	failed	{3,2}
5	35	11	failed	{4}
5	36	12	failed	{3,2}
5	37	13	failed	{4}
5	38	14	failed	{3,2}
5	39	15	failed	{4}
5	40	16	failed	{3,2}
6	41	0	failed	{4}
6	42	1	failed	{3,2}
6	43	2	failed	{4}
6	44	3	failed	{3,2}
6	45	4	failed	{4}
6	46	5	failed	{3,2}
6	47	6	failed	{4}
6	48	7	failed	{3,2}
6	49	8	failed	{4}
6	50	9	failed	{3,2}
6	51	10	failed	{4}
6	52	11	failed	{3,2}
6	53	12	failed	{4}
6	54	13	failed	{3,2}
6	55	14	failed	{4}
6	56	15	failed	{3,2}
6	57	16	failed	{4}
7	58	0	failed	{3,2}
7	59	1	failed	{4}
7	60	2	failed	{3,2}
7	61	3	failed	{4}
7	62	4	failed	{3,2}
7	63	5	failed	{4}
7	64	6	failed	{3,2}
7	65	7	failed	{4}
7	66	8	failed	{3,2}
7	67	9	failed	{4}
7	68	10	failed	{3,2}
7	69	11	failed	{4}
7	70	12	failed	{3,2}
7	71	13	failed	{4}
7	72	14	failed	{3,2}
7	73	15	failed	{4}
7	74	16	failed	{3,2}
8	58	0	failed	{3,2}
8	59	1	failed	{4}
8	60	2	failed	{3,2}
8	61	3	failed	{4}
8	62	4	failed	{3,2}
8	63	5	failed	{4}
8	64	6	failed	{3,2}
8	65	7	failed	{4}
8	66	8	failed	{3,2}
8	67	9	failed	{4}
8	68	10	failed	{3,2}
8	69	11	failed	{4}
8	70	12	failed	{3,2}
8	71	13	failed	{4}
8	72	14	failed	{3,2}
8	73	15	failed	{4}
8	74	16	failed	{3,2}
9	75	0	failed	{4}
9	76	1	failed	{3,2}
9	77	2	failed	{4}
9	78	3	failed	{3,2}
9	79	4	failed	{4}
9	80	6	failed	{3,2}
9	81	7	failed	{4}
9	82	8	failed	{3,2}
9	83	9	failed	{4}
9	84	10	failed	{3,2}
9	85	11	failed	{4}
9	86	12	failed	{3,2}
9	87	13	failed	{4}
9	88	14	failed	{3,2}
9	89	15	failed	{4}
9	90	16	failed	{3,2}
9	91	17	failed	{4}
10	92	0	failed	{3,2}
10	93	1	failed	{4}
10	94	2	failed	{3,2}
10	95	3	failed	{4}
10	96	4	failed	{3,2}
10	97	5	failed	{4}
10	98	6	failed	{3,2}
10	99	7	failed	{4}
10	100	8	failed	{3,2}
10	101	9	failed	{4}
10	102	10	failed	{3,2}
10	103	11	failed	{4}
10	104	12	failed	{3,2}
10	105	13	failed	{4}
10	106	14	failed	{3,2}
10	107	15	failed	{4}
10	108	16	failed	{3,2}
11	109	0	failed	{4}
11	110	1	failed	{3,2}
11	111	2	failed	{4}
11	112	3	failed	{3,2}
11	113	4	failed	{4}
11	114	5	failed	{3,2}
11	115	6	failed	{4}
11	116	7	failed	{3,2}
11	117	8	failed	{4}
11	118	9	failed	{3,2}
11	119	10	failed	{4}
11	120	11	failed	{3,2}
11	121	12	failed	{4}
11	122	13	failed	{3,2}
11	123	14	failed	{4}
11	124	15	failed	{3,2}
11	125	16	failed	{4}
12	126	0	failed	{3,2}
12	127	1	failed	{4}
12	128	2	failed	{3,2}
12	129	3	failed	{4}
12	130	4	failed	{3,2}
12	131	5	failed	{4}
12	132	6	failed	{3,2}
12	133	7	failed	{4}
12	134	8	failed	{3,2}
12	135	9	failed	{4}
12	136	10	failed	{3,2}
12	137	11	failed	{4}
12	138	12	failed	{3,2}
12	139	13	failed	{4}
12	140	14	failed	{3,2}
12	141	15	failed	{4}
12	142	16	failed	{3,2}
13	126	0	failed	{3,2}
13	127	1	failed	{4}
13	128	2	failed	{3,2}
13	129	3	failed	{4}
13	130	4	failed	{3,2}
13	131	5	failed	{4}
13	132	6	failed	{3,2}
13	133	7	failed	{4}
13	134	8	failed	{3,2}
13	135	9	failed	{4}
13	136	10	failed	{3,2}
13	137	11	failed	{4}
13	138	12	failed	{3,2}
13	139	13	failed	{4}
13	140	14	failed	{3,2}
13	141	15	failed	{4}
13	142	16	failed	{3,2}
\.


--
-- Data for Name: epoch_data; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.epoch_data (id, seed, ledger_hash_id, total_currency, start_checkpoint, lock_checkpoint, epoch_length) FROM stdin;
1	2va9BGv9JrLTtrzZttiEMDYw1Zj6a6EHzXjmP9evHDTG3oEquURA	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	1
2	2vafPBQ3zQdHUEDDnFGuiNvJz7s2MhTLJgSzQSnu5fnZavT27cms	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKiuQZnXcHcz1N99e7PnVdSNt8dc3Ku7KT1cNHUQhNJv9svMvhh	2
3	2vbsGv2NCp6LgMJK4P3b1aUBWBnwiCVxUsbrLCNSpuZvWDax6hNs	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLUQWTbi4vtHYzGM2MZic9v51R4QJJit3pbxx4dPMA1w1zhyeSP	3
4	2vaks6urTp4b2NwswHNcZp9yscVZksZT3DDK5D4Zceh7fPfuduQs	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKu2nh1N1i3AXgJVKenUAgRMsF4w1NxWVtwcHwhhCAqRz3UDtCx	4
5	2vbMSfYQJ8F7emgtcxTJkMbzZVDaTbbantoZTZiU91bvbkJg44RW	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKu2nh1N1i3AXgJVKenUAgRMsF4w1NxWVtwcHwhhCAqRz3UDtCx	4
6	2vbTNzYZQP5GAyeP5KHGcEs6wEhHhcgdaYzJZjM46kYcMddiWAAQ	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLZvjMBG4R4AziCrmsyK9RJWLC1br9iMAxUMLCV9GvmcjR67sbj	5
7	2vax2DCf9J2hfNqFJ93KeAST9Bdjj3WHNJ87S7UD1YQoHbs5nrks	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKngXmbkh1QboN7HcezcH2ziHFbVBuyt15tFMPStexZkkbcNwxu	6
8	2vbkvA15w1b78QdPPhHFsfruUsXkfEagc5iyXxmJczrxiYYW23M2	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NL4SeyFfDxSooESJiLFfwogpkDVgKuNUPTLZMkF1tead7fapgdo	7
9	2vbwH8oyHeKLE83iP6SVTPGiEEbaumHRyuYyskXGyGoi5rkgf7GB	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NL4SeyFfDxSooESJiLFfwogpkDVgKuNUPTLZMkF1tead7fapgdo	7
10	2vbhDiSgExWQhbN9rP1KAEssdX1YQkgxtds6qYEWr48DEEtgwxyN	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLdy7iVttfzGiNvscFGGCJyQQSDaQXkDi8MojhBV7CwaVfd9cTG	8
11	2vagAy4Ro9GXhLqkqe9V4BthjX65dGuwJD4oRcAur1S6uxnovfRr	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLV8muTbbUhjibRYWovz4z98e9RK64J713G95G15poCYvxvNWg4	9
12	2va9x61YfMWtZ4pBFSe3ws6vbtPzy4dNxdVUNCDFPVAyDTpguSEQ	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NL8eePFe6GCx1gVoWnU2zAZAsWjnJTLNCweptxahDXEsnDm1iMm	10
13	2vaMa6FCmJPxvPYnhKPcLn3FVB15DtSgajkhbuXJcSyxqPqVSjU1	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKs8ugWuKYypPMDTPZz6PjZyFe3usVK5shzftFP4xPn9enWe1YF	11
14	2vaFEBYGMiMpSup5czSRuR4wcZpcfVfaFTtA7RmYak2xK1iABgFz	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKs8ugWuKYypPMDTPZz6PjZyFe3usVK5shzftFP4xPn9enWe1YF	11
\.


--
-- Data for Name: internal_commands; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.internal_commands (id, command_type, receiver_id, fee, hash) FROM stdin;
1	coinbase	97	720000000000	5JtttpfzEE76N9mHjZVGk4gBjwChqZkHJUSxwm4FZT3D6NhyJ1gG
2	fee_transfer	97	5250000000	5JvPncqZpYaNKDvRECP39eJL91ZmM154tBWYgxuai8F8kaWQ6Nx8
3	fee_transfer	97	113000000000	5JtsxheDWm7YTnZs8ia2YzmXPYWR2xn9jDXfLCVZPZsFdG3CC79b
4	coinbase	7	720000000000	5Jtc6mCx6x4URUsJajTyiGHKMs39PzRLBnhuMK6Cvtzchbxu74gj
5	fee_transfer	7	113000000000	5Jv91fBeZg3nusTHt682s6sEy22Nj6KRr9UayitGTLM37vZTLUf4
6	fee_transfer	7	87000000000	5JueeMhAxLHfiJpy5TC9xKR4xPfNie4Wz9xqBhD9Trj1D2d3srgi
7	fee_transfer	97	87000000000	5JuUDYowY2KbV1TWfs9fWWkCmTmc4XxRv4vf9A4fqZXp73t7BpNw
8	fee_transfer	7	87250000000	5JuR4kkLjkUWtbkFzUsBirSLnMNJjbpPRAeQ5rE9xE66MSt9LRQR
9	fee_transfer	97	87250000000	5JvQDdqEgWk3vuHG2n5vEg7ALdSPS86MpifikZZd6Ww3gn5na46f
10	fee_transfer	7	25000000000	5JtpeNeJ8iMycizs7sBEouahmoLomxnk17YVGfTgmS2hNZyYTQYF
11	fee_transfer	7	62000000000	5JvANvzZJTBsjcJ9qmnoBJ1KLxGGtjEUj8qNXazo3cuwbs7wSPU8
\.


--
-- Data for Name: protocol_versions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.protocol_versions (id, transaction, network, patch) FROM stdin;
1	3	1	0
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
7	B62qkBb2C54LdCSxhMVgdbyYUbb6E9psGrUg5xeqWPe2vFAgQGEQPZH
8	B62qoxkuzRkqEXbw2D7FS1EJctSvrKhFDjwo1s7UqaRbzAC9wW9CqXB
9	B62qk4Y4VLT1oUbD1NjPunSEUjz5yVNbiETWCfNTvT5VLrmbRwnKcMk
10	B62qnsdKhWmeQZjvas2bVuE7AcUjqWxSjb5B6pFqyVdtVbrro8D9p9F
11	B62qqDcNXt7LK6686QQ9TvLaFF5as6xRRSMEjfwXJUEk3hSHVXksUth
12	B62qmRRtdPM1XRnHpchjrVdVyRtUKFX5Nmrhu7MWSs3wDVsLuTQ54dV
13	B62qnT7rV3ZQ71n6Z2RaPZSn38zEniZq1A8CXEdArxrF7q6sTTWZdZc
14	B62qmnTkaf43Ctbxq1NgvtakVwKKcB1nk2vee61bMAcPfDB5FR5upJN
15	B62qpTgN6VhfdCGimamFjarhSBfiK1oGEKyrqHN5FHejeJR8Z2vgKYt
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
75	B62qkaVP4fyb2MmtpHHNJR5LKuALwag7BSSwahiqNqQmsWY8gMPc397
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
96	B62qkM1Tq15y3L3T37ERuZKmkX9XexAi1G5Jta8bHz52e2XEgnjm4H6
97	B62qowNMGN25wkMR8RdwACKorCgqTtxK5h2egm6sWXbNNeZGEgpUtoa
98	B62qitvFhawB29DGkGv9NEfGZ8d9hECEKnKMHAvtULVATdw5epPS2s6
99	B62qo81kkuqxFZw9cZAcoYb4ZeCjY9HodT3yDkh8Zxhg9omfRexyNAz
100	B62qmeDPPUDtPVVHqesiKD7ecz6YZvGDHzVw2swBa84EGs5NBKpGK4H
101	B62qqwLQXBrhJmfAtF7GUf7FNVS2xoTPrkyw7d4Pj9W431bpysAdr3V
102	B62qigMsAY8wRpqt62fTTbZ8jJM15g2wk67sZQtoJuaytPzQ9yrohE3
103	B62qkgcEQJ9qhjwQgt2XeN3RJpPTfjCrqFUUAW2NsVpzmyQwFbekNMM
104	B62qnAotEqbcE8sjbdyJkkvKnTzW3BCPaL5HrMEdHa4pVnfPBXWGXXW
105	B62qquzjE4bbK3mhk6jtFMnkm9BdzasTHuvMxx6JmhXeYKZkPbyZUry
106	B62qrj3VHfVadkyJCvmu7SvczS7QZy1Yk1uQjcjwkS4QqDt9oqi4eWf
107	B62qn6fTLLatKHi4aCX7p6Lg5rzZSq6VK2vrFVgX14gjaQqay8zHfsJ
108	B62qjrBApNy5mx6biRzL5AfRrDEarq3kv9Zcf5LcUR6iKAX9ve5vvud
109	B62qkdysBPreF3ef7bFEwCghYjbywFgumUHXYKDrBkUB89KgisAFGSV
110	B62qmRjcL489UysBEnabin5be824q7ok4VjyssKNutPq3YceMRSW4gi
111	B62qo3TjT6pu6i7UT8w39UVQc2Ljg8K69eng55vu5itof3Ma3qwcgZF
112	B62qpXFq7VJG6Spy7BSYjqSC1GBwKLCzfU8bcrUrALEFEXphpvjn3bG
113	B62qmp2xXJyj9LegRQUtFMCCGV3DQu337n6s6BK8a2kaYrMf1MmZHkT
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
161	B62qottYaFZ9TGcxQS1GNNGTTH3gHXMBajNsPznxA3ySkSZ9ZFA6U7e
162	B62qoayMYNMJvSh27WJog3K74996uSEFDCmHs7AwkBX6sXiEdzXn9SQ
163	B62qibjCrFmXT3RrSbHgjtLHQyb63Q89gBLUZgRj7KMCeesF9zEymPP
164	B62qrw63RAyz2QfqhHk8pttD2ussturr1rvneUWjAGuhsrGgzxr2ZRo
165	B62qmNVzYukv4VxXoukakohrGNK7yq1Tgjv5SuX1TTWmpvVwD5Xnu2L
166	B62qoucdKZheVHX8udLGmo3vieCnyje5dvAayiLm8trYEp3op9jxCMa
167	B62qo51F51yp7PcqmHd6G1hpNBAj3kwRSQvKmy5ybd675xVJJVtMBh8
168	B62qjHbDMJGPUz3M6JK2uC3tm6VPLaEtv4sMCcrMBz6hnD5hrET4RJM
169	B62qnyxTMk4JbYsaMx8EN2KmoZUsb9Zd3nvjwyrZr2GdAHC9nKF16PY
170	B62qrPo6f9vRwqDmgfNYzaFd9J3wTwQ1SC72yMAxwaGpjt2vJrxo4ri
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
206	B62qjsvgtDNVNinsUkephsGY2n81MKMuEpSfX4ACr7DxV9CfruDPRWz
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
243	B62qmPe9eC7BrNuxjgrx8yF7Nuf5KcR8rZZtwfhoF9icT8HSheD9JAt
\.


--
-- Data for Name: snarked_ledger_hashes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.snarked_ledger_hashes (id, value) FROM stdin;
1	jxMSC7rer8PqzEig8LujhfSsqWu4AETJ5D7f23HCHrcWVYMZcXC
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
1	payment	75	75	75	0	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtXeFoaKovpo9b8QFQdRiLruiMhWyqWmJFgz1FqWT4dSn4dbp73
2	payment	75	75	75	1	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jum5nP4UfexXsF6vCE5SmUWhn78cydz1GiENhtvJiTWEvKCrUXV
3	payment	75	75	75	2	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtzw6iQCVM9qWJFG3xsDye8U1F6hqvpqsLgrbkBrpKWonCr9R9X
4	payment	75	75	75	3	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvFrgqUjHYGdhE2nahudmd24fkVbs3JLuneTB6M1nrnWTTCrCKN
5	payment	75	75	75	4	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju8WfM7kCVn4Yj4nF7NNav1sRsZtUuU1xDm47ZHvLiEdrdZf15C
6	payment	75	75	75	5	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvMH3P4rY8NabhY2j6vPVBcFW9EbR9u43gJDBz3BCiYN24rhcRJ
7	payment	75	75	75	6	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtdasMtL9y9ur5KHUJiY8a6wimGFFuPkpxbhUeih2BfV4mZCb1Q
8	payment	75	75	75	7	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuorVAV8hsV2AuisyP92aarsrSYJp1KejEWJmFzv7Ah557tyTba
9	payment	75	75	75	8	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvQBwsxM6Gfek71eFoA8dawyXUVCdXBy886DH4mAeJVtm9GsTzi
10	payment	75	75	75	9	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtm7vfSN8df1nK5Woj6o8m4ouRFHqv1TQzb9B2Zh1pyorMt7xaT
11	payment	75	75	75	10	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuoAtnCBhSRAuFZpDvm94tEF27MMZxzt5zV9RZVuk7Ubm19fMvK
12	payment	75	75	75	11	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuGwGWUqvY68iS4TxtUPjrFXWmSdFgaANWv8YcnCu6H4Xra1g7z
13	payment	75	75	75	12	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtVWU4VNR6q6Mj8dfiFrZYygdsd96KRLduKctBTJSNcv5p3nTZB
14	payment	75	75	75	13	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju1xz6ANaWZXbBLkzHmtj39nuL4t6GiZqpRZj46FV89pnTKAQrs
15	payment	75	75	75	14	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtXP94xmPBZv8DXmhgHjFJKHpfmcSAp845TxNiYMBhhMVwu6dFy
16	payment	75	75	75	15	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuTjRJYEvGnoC7GjqAZE7yWtXoHaDdDXpP2QG1tMV5DrbtDNZHb
17	payment	75	75	75	16	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuCaMHxv3zTVc2acdopTCmCYWSN9z7xaW7rUxTKnXM83q8gAELG
18	payment	75	75	75	17	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju67riLqtFwnPc2QT1PkN3yz24FkuoqzgyguhRT46NbPtfQ9jg1
19	payment	75	75	75	18	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuTiovWKFDLQFFrdQAH9e4PGjgSX7g9Z7XmekPVzw5pG6JmzHik
20	payment	75	75	75	19	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvF3cRZmiT1vAZE3gwoAhAkbCe6bL6XCDN5dmsQr1FxEj29CATt
21	payment	75	75	75	20	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuQ5MVTaVG7PyKD1YCDuggpwM7UURe8YyWd82Wu1bPDYecChp9w
22	payment	75	75	75	21	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv8PBkTJW8MzoD6G2RRQim3s4bH927VVtuFi7wMYZrEtSdV8wcx
23	payment	75	75	75	22	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtaG98XGR1GGzu6e8bRNk54j868qEWE3YitBT2gcnqiYF5D2wfZ
24	payment	75	75	75	23	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuWeZwFsRQ9uXckr8biCFmcXdUxxuvqS4D8NKBY2CsNLjijggHx
25	payment	75	75	75	24	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv2FqGqAsMytrJsyRa2dMApz1K576HTyDY8whhmeBdKthnpfABb
26	payment	75	75	75	25	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju7UzcmsTdAdsQB8G5ZohRi2dqaZdsEAh9noyo1ZLZba9A2FJV2
27	payment	75	75	75	26	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju8dmwNGkmcQuDk3A2MG7iNvXL1v9fjZiyhocR3DB3HkHDzjdn8
28	payment	75	75	75	27	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JueRf36YtVe1ASbswagqLPU3HsZ3C3M3CGFGnV8moZVa9iJ2wyL
29	payment	75	75	75	28	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv4aPHkdvQ637HEDxJpDxdJws5XAerAY5czwa5234YKmZmB19bF
30	payment	75	75	75	29	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtauTCMDQXEiHjysPfnoWrfjhM1GH2w5aHVGhNqhVSKX7NXoGsx
31	payment	75	75	75	30	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvRt7hro1XvQRjEL3Puk8UFnkkkRXK2wWno9xqXqrrJUX8pFYdk
32	payment	75	75	75	31	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtkWrjUkeNGSrobQuNSJH3csLVLMpsvBAterTSqSci7piR517Bi
33	payment	75	75	75	32	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvD5fZyjvX2kEYianmREMbFgxknkHEp9CezcZGkt3zddfWsvpsN
34	payment	75	75	75	33	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuAJDmGdraicFYsLr1oL5y8jPRQNFEgYzdcnqhzdWTESA9gD7qj
35	payment	75	75	75	34	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jur52H3BFShsCJ93AyHWsQQ1iLwo42jeuVQUgZ8AS3ohJnhwW1M
36	payment	75	75	75	35	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv5kaWsiHaECcuqfRarUwDENpJPBi2wSq5HWzSuWXhYvud2akTe
37	payment	75	75	75	36	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju8NMbeNr5c9dWRHFeAM7Q8EuY8w7eDDaQWVtYmnYT6QBU2NaAj
38	payment	75	75	75	37	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juf3cKcAyD1FxGDJKwVsvSVsbSb31LckiBNHLcwNbkZjwsrhDPD
39	payment	75	75	75	38	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuokYvXbTZivtLohV4XKckTtBn3PbuQ7z2KgeDUQkZb7FFR7tzF
40	payment	75	75	75	39	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtkqJg2X6Bv8wK1fUaAfUUZoYTvfCoqkkasD8NNLFdpdugcBXXa
41	payment	75	75	75	40	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtxtGQyerEzkqv4V3P5scx7ty5caS4zFnHLhyrtvnvam6xACN3n
42	payment	75	75	75	41	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuskvShoyY5CvfHWW7ZuUUojRNZceqcc4SzCtjek6CAwgW2gq7D
43	payment	75	75	75	42	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtWYaxjaJpmhL5Ka8BdCWwrVk4rasyrTfUsbUNGmvLwxnxkXBKm
44	payment	75	75	75	43	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtrm6emPYLa54CSsxP7qfu22WfmQqGUp2t9MmGMg2dxZQoWn9Vc
45	payment	75	75	75	44	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JttP7dZEfgEGxcsGuzxvLiw8skfJ4a8J5prNqfwVhcoNPTyxLSC
46	payment	75	75	75	45	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvNi1wzYRkC6AHLA5oeR3wNHot8hbGfNPcx1Wx5K8oW8aUJUSbi
47	payment	75	75	75	46	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JurbamfTQJ4R3opDRM63x7zHAdrdnHaMWA9moptcBSspbZAFJkB
48	payment	75	75	75	47	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juy7CRpwF3akYh6kkmizz8Yi9pJVWpF4STK3PK7RLCvUFmNKnVN
49	payment	75	75	75	48	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuAHeVBKQoAQb8eRQCy7H4inprsRxLY9m3vXfq24GcUs5qkN49Y
50	payment	75	75	75	49	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtoy73vpCDuh3vCFcnDyUEG29Kz8Xk9HyEgfhMaY477qxyVAyen
51	payment	75	75	75	50	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuhYQddBBPWMR2MnXoMSPZL9QLeaqiBwPw11HEotm2KoUa9hu33
52	payment	75	75	75	51	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtvTMwXiZHEwKL29H7oY69ffuxoF3Nbj652M4gZ6N1aAK91fz7u
53	payment	75	75	75	52	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvKqedGrsX2eSv61TTWC4zXhd7rpL93A2Rre1ZDhVufVYCzK2Lo
54	payment	75	75	75	53	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jugd92H7MbNS4Hg76y7oBUEvw4j1Wfw2ymMi6dCh7q3tmduT3PK
55	payment	75	75	75	54	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv7Y2Dj9BgvAJRNTPY4tojNudWNMCjbkAgpSCqZq3sFry924rQE
56	payment	75	75	75	55	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuwJAtXD21b1S2KbkdrqnjouQkjvFDHTKHiwYCkMPpTyJ9phhfW
57	payment	75	75	75	56	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuK2HpTH5Txsp4ELfgw5eZXHvELNMQpxnEXMLwHpSfxLHfLzmEz
58	payment	75	75	75	57	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju16H9UW8EUoRiFvXbmpNoZBzBVqWgSCKjz6WCdstThuDJUvGMw
59	payment	75	75	75	58	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv4cXsMpH4oecbBWbSp1cpP1bqgm6UUMavWHoRH8yupWtFfHpar
60	payment	75	75	75	59	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuRBLvsnfD4ZGWG1bFGSvGhgaBmfTd1ha4XEwcCrE6GBFZ5ESHu
61	payment	75	75	75	60	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuRcsakUPYMv24cMX1z1bsXuhAoSjNQFMJZSmqV7ozRPiDfovgP
62	payment	75	75	75	61	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JudYJNK1yB1uxsXS6Ut8buMXLJuW6wCUNXNn9wQkyBb75mpLAL5
63	payment	75	75	75	62	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju1yM7TReVN87diz6TDWs2K9zebL1wRSEBXHZM1PucLCAjftJ1p
64	payment	75	75	75	63	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvFSMPevporo3YwXuv36ncqet6XJ4rNGyjpnXwGFNHiL9cL4DBM
65	payment	75	75	75	64	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuaMa5z2QoHo2iBVKSZmxM5unxQXzYBN38Jqc8wNujmyCgdQz2j
66	payment	75	75	75	65	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju3ZVbJNR2iLkVBv2NWVMHwq5evdNPdyioGfZbQgZwHWPieXJPV
67	payment	75	75	75	66	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuzWePWTYrWSrcfKwVwDUiXwb4Hb4iPBsumT4SJRqfZnNvsv4xj
68	payment	75	75	75	67	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuTyfmev93oB6YV4iJ63Go4mMY3Du4EcPk7chqeo6AozgAJWaqd
69	payment	75	75	75	68	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtjENWDRd7jCqZhViBav3jNt43FQJw5g7rSmT3oyMyTH1MFw85E
70	payment	75	75	75	69	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuWGjRpjENVZ8HJBxGzyKsEVdUL1cYLgBdMjWJWSqPSxLCKTsT3
71	payment	75	75	75	70	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvBcAePz2GQoZdsvTg6uHVw5dxMyJtGj29M6SU867z1rmKM1K4G
72	payment	75	75	75	71	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuzhAfXQXiFSwJBAYXb2YVqdfDacswsHNN91gMfyDTBvnugEMwU
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
\.


--
-- Data for Name: zkapp_account_update_body; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.zkapp_account_update_body (id, account_identifier_id, update_id, balance_change, increment_nonce, events_id, actions_id, call_data_id, call_depth, zkapp_network_precondition_id, zkapp_account_precondition_id, zkapp_valid_while_precondition_id, use_full_commitment, implicit_account_creation_fee, may_use_token, authorization_kind, verification_key_hash_id) FROM stdin;
1	95	1	-1000000000000	t	1	1	1	0	1	1	\N	f	f	No	Signature	\N
2	243	2	999000000000	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
3	95	1	-1000000000	t	1	1	1	0	1	3	\N	f	f	No	Signature	\N
4	243	1	1000000000	f	1	1	1	0	1	2	\N	f	f	No	None_given	\N
5	243	3	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
6	95	1	-1000000000	t	1	1	1	0	1	4	\N	f	f	No	Signature	\N
7	243	4	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
8	95	1	-1000000000	t	1	1	1	0	1	5	\N	f	f	No	Signature	\N
9	243	5	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
10	95	1	-1000000000	t	1	1	1	0	1	6	\N	f	f	No	Signature	\N
11	243	6	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
12	95	1	-1000000000	t	1	1	1	0	1	7	\N	f	f	No	Signature	\N
13	243	7	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
14	95	1	-1000000000	t	1	1	1	0	1	8	\N	f	f	No	Signature	\N
15	243	8	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
16	95	1	-1000000000	t	1	1	1	0	1	9	\N	f	f	No	Signature	\N
17	243	9	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
18	95	1	-1000000000	t	1	1	1	0	1	10	\N	f	f	No	Signature	\N
19	243	10	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
20	95	1	-1000000000	t	1	1	1	0	1	11	\N	f	f	No	Signature	\N
21	243	11	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
22	95	1	-1000000000	t	1	1	1	0	1	12	\N	f	f	No	Signature	\N
23	243	12	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
24	95	1	-1000000000	t	1	1	1	0	1	13	\N	f	f	No	Signature	\N
25	243	13	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
26	95	1	-1000000000	t	1	1	1	0	1	14	\N	f	f	No	Signature	\N
27	243	14	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
28	95	1	-1000000000	t	1	1	1	0	1	15	\N	f	f	No	Signature	\N
29	243	15	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
30	95	1	-1000000000	t	1	1	1	0	1	16	\N	f	f	No	Signature	\N
31	243	16	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
32	95	1	-1000000000	t	1	1	1	0	1	17	\N	f	f	No	Signature	\N
33	243	17	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
34	95	1	-1000000000	t	1	1	1	0	1	18	\N	f	f	No	Signature	\N
35	243	18	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
36	95	1	-1000000000	t	1	1	1	0	1	19	\N	f	f	No	Signature	\N
37	243	19	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
38	95	1	-1000000000	t	1	1	1	0	1	20	\N	f	f	No	Signature	\N
39	243	20	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
40	95	1	-1000000000	t	1	1	1	0	1	21	\N	f	f	No	Signature	\N
41	243	21	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
42	95	1	-1000000000	t	1	1	1	0	1	22	\N	f	f	No	Signature	\N
43	243	22	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
44	95	1	-1000000000	t	1	1	1	0	1	23	\N	f	f	No	Signature	\N
45	243	23	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
46	95	1	-1000000000	t	1	1	1	0	1	24	\N	f	f	No	Signature	\N
47	243	24	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
48	95	1	-1000000000	t	1	1	1	0	1	25	\N	f	f	No	Signature	\N
49	243	25	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
50	95	1	-1000000000	t	1	1	1	0	1	26	\N	f	f	No	Signature	\N
51	243	26	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
52	95	1	-1000000000	t	1	1	1	0	1	27	\N	f	f	No	Signature	\N
53	243	27	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
54	95	1	-1000000000	t	1	1	1	0	1	28	\N	f	f	No	Signature	\N
55	243	28	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
56	95	1	-1000000000	t	1	1	1	0	1	29	\N	f	f	No	Signature	\N
57	243	29	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
58	95	1	-1000000000	t	1	1	1	0	1	30	\N	f	f	No	Signature	\N
59	243	30	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
60	95	1	-1000000000	t	1	1	1	0	1	31	\N	f	f	No	Signature	\N
61	243	31	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
62	95	1	-1000000000	t	1	1	1	0	1	32	\N	f	f	No	Signature	\N
63	243	32	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
64	95	1	-1000000000	t	1	1	1	0	1	33	\N	f	f	No	Signature	\N
65	243	33	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
66	95	1	-1000000000	t	1	1	1	0	1	34	\N	f	f	No	Signature	\N
67	243	34	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
68	95	1	-1000000000	t	1	1	1	0	1	35	\N	f	f	No	Signature	\N
69	243	35	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
70	95	1	-1000000000	t	1	1	1	0	1	36	\N	f	f	No	Signature	\N
71	243	36	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
72	95	1	-1000000000	t	1	1	1	0	1	37	\N	f	f	No	Signature	\N
73	243	37	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
74	95	1	-1000000000	t	1	1	1	0	1	38	\N	f	f	No	Signature	\N
75	243	38	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
76	95	1	-1000000000	t	1	1	1	0	1	39	\N	f	f	No	Signature	\N
77	243	39	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
78	95	1	-1000000000	t	1	1	1	0	1	40	\N	f	f	No	Signature	\N
79	243	40	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
80	95	1	-1000000000	t	1	1	1	0	1	41	\N	f	f	No	Signature	\N
81	243	41	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
82	95	1	-1000000000	t	1	1	1	0	1	42	\N	f	f	No	Signature	\N
83	243	42	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
84	95	1	-1000000000	t	1	1	1	0	1	43	\N	f	f	No	Signature	\N
85	243	43	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
86	95	1	-1000000000	t	1	1	1	0	1	44	\N	f	f	No	Signature	\N
87	243	44	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
88	95	1	-1000000000	t	1	1	1	0	1	45	\N	f	f	No	Signature	\N
89	243	45	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
90	95	1	-1000000000	t	1	1	1	0	1	46	\N	f	f	No	Signature	\N
91	243	46	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
92	95	1	-1000000000	t	1	1	1	0	1	47	\N	f	f	No	Signature	\N
93	243	47	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
94	95	1	-1000000000	t	1	1	1	0	1	48	\N	f	f	No	Signature	\N
95	243	48	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
96	95	1	-1000000000	t	1	1	1	0	1	49	\N	f	f	No	Signature	\N
97	243	49	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
98	95	1	-1000000000	t	1	1	1	0	1	50	\N	f	f	No	Signature	\N
99	243	50	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
100	95	1	-1000000000	t	1	1	1	0	1	51	\N	f	f	No	Signature	\N
101	243	51	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
102	95	1	-1000000000	t	1	1	1	0	1	52	\N	f	f	No	Signature	\N
103	243	52	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
104	95	1	-1000000000	t	1	1	1	0	1	53	\N	f	f	No	Signature	\N
105	243	53	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
106	95	1	-1000000000	t	1	1	1	0	1	54	\N	f	f	No	Signature	\N
107	243	54	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
108	95	1	-1000000000	t	1	1	1	0	1	55	\N	f	f	No	Signature	\N
109	243	55	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
110	95	1	-1000000000	t	1	1	1	0	1	56	\N	f	f	No	Signature	\N
111	243	56	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
112	95	1	-1000000000	t	1	1	1	0	1	57	\N	f	f	No	Signature	\N
113	243	57	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
114	95	1	-1000000000	t	1	1	1	0	1	58	\N	f	f	No	Signature	\N
115	243	58	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
116	95	1	-1000000000	t	1	1	1	0	1	59	\N	f	f	No	Signature	\N
117	243	59	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
118	95	1	-1000000000	t	1	1	1	0	1	60	\N	f	f	No	Signature	\N
119	243	60	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
120	95	1	-1000000000	t	1	1	1	0	1	61	\N	f	f	No	Signature	\N
121	243	61	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
122	95	1	-1000000000	t	1	1	1	0	1	62	\N	f	f	No	Signature	\N
123	243	62	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
124	95	1	-1000000000	t	1	1	1	0	1	63	\N	f	f	No	Signature	\N
125	243	63	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
126	95	1	-1000000000	t	1	1	1	0	1	64	\N	f	f	No	Signature	\N
127	243	64	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
128	95	1	-1000000000	t	1	1	1	0	1	65	\N	f	f	No	Signature	\N
129	243	65	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
130	95	1	-1000000000	t	1	1	1	0	1	66	\N	f	f	No	Signature	\N
131	243	66	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
132	95	1	-1000000000	t	1	1	1	0	1	67	\N	f	f	No	Signature	\N
133	243	67	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
134	95	1	-1000000000	t	1	1	1	0	1	68	\N	f	f	No	Signature	\N
135	243	68	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
136	95	1	-1000000000	t	1	1	1	0	1	69	\N	f	f	No	Signature	\N
137	243	69	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
138	95	1	-1000000000	t	1	1	1	0	1	70	\N	f	f	No	Signature	\N
139	243	70	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
140	95	1	-1000000000	t	1	1	1	0	1	71	\N	f	f	No	Signature	\N
141	243	71	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
142	95	1	-1000000000	t	1	1	1	0	1	72	\N	f	f	No	Signature	\N
143	243	72	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
144	95	1	-1000000000	t	1	1	1	0	1	73	\N	f	f	No	Signature	\N
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
1	1	{1,2}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JteuR5EDsReohRGrVXa62vNzTAvpsLafryLnUDRXe896DusWsFx
2	2	{3,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvKrLm6GMYWvYgLTQhY54KCoLSNfAVPKrmAqbbt7qnLhgBZB65H
3	3	{5}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju6syDyEfcCWyuHdA3B1Rd1cxg6nr5Vs1YfpTQo49fkxrVscFxm
4	4	{6,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuhkKxsEchyq8RwL98hW25f6qVqvjPHcRDyZShMxTStKwCP9jTv
5	5	{7}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvL2BNdcqKimjX3W4qfyNdqCUaZJrSbEMxvFjgQpzV5aD3uZ8rw
6	6	{8,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juzsgrf4o3MxPQccWo3eK8umKeNf4QMLV6jaPdFqjNcxGPKUDE7
7	7	{9}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv5qLA1YJNi8TXFKDswNsZf4xDyad9rVibCK8Tc9zdP4kx4PFTj
8	8	{10,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv3vpXzAZsiXU2yAVwvwd3DDmp1FjbcQqHLnvCnHHzn1eDminUv
9	9	{11}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvEYEHemCAZctkyhy1QCHXVTVHWi88US8vmcT3Ta35ssoNyDrpW
10	10	{12,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtnG7yU2zSfMgcnFrTR2DLxao5Tc2xHP1Kz5dE4jatQwcYT6NNr
11	11	{13}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju7ZBNgpHDQmfmTpyw7cUNkJMs777ExCo4pNTY6yMw8ztVMgRFk
12	12	{14,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuhWBeZKd8aMCR2bCvrzZs9wwoX9xxKGV1AkLDfpR1aTMcdnmKR
13	13	{15}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuozDnfkXKuCpuwLzGBfUu24v8fBaB3U1hj4vjZUpLKFKPL5AkZ
14	14	{16,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtpLPxECVqQXpxkBg2Fmwwx44Vjm2pR9xABXkj5PLGhZsjLe1Mh
15	15	{17}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuwTaG454x6yzjL2w7ofNzsm2b5kuujJh8b8Mr3597PLkgwZvRN
16	16	{18,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju8G3QGtzCfSHDm4vYmHn2qW9GpHUeMK7Dwq6B9gssunYUuJFtT
17	17	{19}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtdHHLPBbBVabkBcvua2gDNjNfs4QFzoc7iet2BUFkbY6b27txd
18	18	{20,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvAzxsz6oUwMcw6svkZWfxPQCLmL5DZEPit275tUhfkWcY6i1DF
19	19	{21}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvL7bRyjd4h8QYuM18GYA4avySJ54hVGg8Rje8W987dfY2HcbnH
20	20	{22,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvKuyB9b6CpoDjtioaLYq68fxJgk1RjPZ8gvWUwdZvvJ31SHpzp
21	21	{23}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuaAvBXSAE5zFaGhj7oYpGNiHRw9CNw4LVCK67SqXDR42fq3PEf
22	22	{24,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtvo3Xfjz7JgHPtMqZ1WHQYfNyqwwXNBWABEfbADdKpBiwSB1iP
23	23	{25}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JugEP4SjDTKRkNv7M3rZdLrKC8x7U64bE5LLpBLfu98474VphDN
24	24	{26,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvGG3pZiyEQSn5EwPmKUQq1B7RZLr8Q4Yo27bHqTxMiKeb4infr
25	25	{27}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtoDSs88eJFpWSTdvsuH8KsHEnMdwLH6aF81caiUPdxQw2ESZSv
26	26	{28,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuvuRBWHQTfxy6F4BHVXe355zh636ufk2gFxgLitroHksQVy4VG
27	27	{29}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtyiiZgBHZkKLBN5SPP9eLxAKqmBU9awjCkJ55Ut7GSkBFuxBKN
28	28	{30,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JudXCk9EXganuDojgprLsyvdnfngbL77WkfQo7RHKjRKCZwwGSE
29	29	{31}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtaxzEA5MbfSHiCxEZ9YaeemLXVVnYXtFpgdPDxqSSukLgM2wmq
30	30	{32,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jubjb6xQAxgtJbXbXzTpN5bX4BpcP6Y6e5cm8cN7PbiVFLZ9CQ5
31	31	{33}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuXzGjT7k5oXroBJkduhRyvirfAveTTeM2sp7ht2c9qDDB5aoZn
32	32	{34,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuFeQ7KyX3Non1FMjEtvecPXuQWmKLdh6dPFkXASvWb2yQCSwYU
33	33	{35}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuzjPFjzBvdSxYG5E5p5Fy8ygNWxqqpweZ1phu4Ya9Pw1btcanc
34	34	{36,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtZHNmfMQXQbcwyiReXxSxvcuo3fnF37Q1sPoug6pLXwaCZR6qB
35	35	{37}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju3kpYBjk6jdNW6Eoe5YdQcdK6C7tzWbgTPsKt4H72bFLAR9gch
36	36	{38,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuUr9zRPBk5envU3Mw8WQAwth2RBKa5twC3rBHipJvByi3GGeAD
37	37	{39}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtqSXcqweheJyn75trnk14WW3qjCEPBLu29WUgMA9Xqec4QusvN
38	38	{40,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju67ka3BfR6UDewjy4h8gKGUdhaWVVnXfMEd4BToYt6NTwkE1Wc
39	39	{41}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtaok5ov4iA9ZCpmCZNr7hbLgrjb4PAwjf59xivNPTXBsVcXi5h
40	40	{42,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtaemneC9jzdgZWphdVWQLWMJsNCXnQkbiMjNCu7SmVnPBzWoAh
41	41	{43}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JteRgnvZXkY28c1hnKJdvx69aE3NFwyx9d5vrazum5aHYNiy5x3
42	42	{44,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JthcuVYtoE6eHgkgXPpaYWcwaHRXTgmPdWTaTy1Ks3VCamhFNYc
43	43	{45}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuVNDgzsHjikQ8Doj2uCN2iuepeGuUsdwyVmgmJznHoUHzxJKYt
44	44	{46,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuTKrowpVNESkmu5kWmwPhWYxDcDCZDJnE5jBgPR8DrehGdoT58
45	45	{47}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvQ73eDEb4K5nAwaXq8unzBEGMCQVWxCS6htdV8Va5mHyCgEQ7n
46	46	{48,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JudzGWnm2zsYBQH2VB81ruZax3M984sKEsdyPAwEb8MfDYrgMF2
47	47	{49}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtho8BWX7dK98DJqTAKFsDRsKf2w58rhP8GvjNjUytGi58u72Pk
48	48	{50,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuCWdrAtPEauPppS2VqXmuBWo9Ewdh5NC6hrLbJE5NriEPT7e2Q
49	49	{51}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtqHD7sTk7XdDZgnCWgPsLvjDbVtZUxVpYna8HtxwacxVdmRVPX
50	50	{52,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuL6vjw3oEdw7Ni3fUQvzKnAxWT3oM2VZpcn5D1Y4SU2hxTqgNs
51	51	{53}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvLbUsbCycY9KVDhPxgWSUUg5x9kywzcJSJQu1cNFujPTaMmLVY
52	52	{54,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvE9wTNAhttmuiFoh9XgEUJkf9BaBRUxEgQEeDdrDW7vmGX5X6z
53	53	{55}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvF8uJrF8uG5LPFiJj28bUWrmCP6PEh4jGtX9eJVHASGb2f9wNg
54	54	{56,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuSnB599ipXZKuVZrfKCe61rf4mceGnSsxYrEFKptgPrDdGeNiT
55	55	{57}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvM3uxpCcSTnp7Jrb65mDofJXjb3ZQ5CXSwZNvdtRF2akFuHT3Q
56	56	{58,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuRfXYpW4r8VsSbAuB6nYU1vhsVz9YfW8LQ9Q2PWbuGAErrqvDZ
57	57	{59}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv2mi9TgXjzr4ampeJYtjrcEgwWn3s2GQuAVnnpJwsM3oTzUBhu
58	58	{60,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv7AmFwdmZaAwetDvkiL8XnM3GL2VkePDczyaqTBLTbj8BehCzd
59	59	{61}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuB1hk3PTJeMSLSYVZk2bKbqMqNNnyNiqXYCzuTCp9eLLKFCwPF
60	60	{62,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtZL26chJAhWJhsWoA1p54C32EbBetYovTydz5Tx2jdZZHLrMwj
61	61	{63}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju2sBSn1xBUpW6iKR48au8RKVQv7RfJM8uLJ6hW9PemW4ALoCau
62	62	{64,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JthyC47p9pPvXbdixxepH6z9eNNGoxfoaC1avPMXLsK3p1nFWKZ
63	63	{65}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JucfJCJDSYtCisq5k7Z8RLaxajCn8r5zptZZDaRgwo4bxik8Hom
64	64	{66,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtmQodg1zTRKEs75N7TRrLUSwSMG2PEpXW1rzsWjvSDV1EJniJe
65	65	{67}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jts9VwWmxB8xMZmJ3Uzfw5hNK65WvyMDkn7VeRfefsYGa4hvXXr
66	66	{68,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju68NL5R56teph4bo4jT7RitAU4BbTMtw5ERSYt3B1fepkK4pkL
67	67	{69}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuamdkVkVgrYH3eaCvw1vCG1NhXAPUTdivkGzhTdMjmLqFmKbv9
68	68	{70,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtdT7TyM9G8P1MvXjxqEuJRGvpPvcmM1khvHsatC1rjh23PQaJA
69	69	{71}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtfuSbjFMC3CWitE9JCYgXsG4ftRfYXDNyvyeCfYmcR8kPDHUdi
70	70	{72,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuZTTPF7aKQPmHAdTHgkao6rboLq5zD61x9zUp4cGV6nrpCURxK
71	71	{73}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JucrdrKkG2rUVa255vYtTWtjAgYVKnKPaN48G4dReSrtjsa1wmk
72	72	{74,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JunwXwpsYzpEXAMSjLDwK1NNH1iiarUVCZwq8FWdwzgKk4qRzAM
73	73	{75}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtywiuhz1oN7f62YLnUk2pviBZmJQkKCVUsJLHaytzQmuLqNZ8i
74	74	{76,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtc2QGkeeqSANttPCUw3Jf6Uj6wmaDVnvgA8mvgQEQnDTGa4Nm1
75	75	{77}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju6ogqxSzekKFMmR2865RxVSPuJ58pwzjhXrM2zKth1hjK9FjfS
76	76	{78,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtW5VYTpzBo5x7aabp1aPejQGypcnU8496qP8ZoGAbcm1YGcEJ2
77	77	{79}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuBCNxxh7vzaStsMNGCfk9XtdAzV7zWiewRjYVSiwHfRxbhRXAn
78	78	{80,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtjJKdee3NydjyBYQmSuiACHmTafXu5RJN6pvqHP9fKDH5QAoPo
79	79	{81}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuRNxR2fR9SoYGETMiYbLADxFiTmtV9QaFAkE2RnYivNyecU9sJ
80	80	{82,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JunCejBdsf6qxKpmpno6ivgPoWFNzKVGBusdC8dJ4u7ADbK9LrE
81	81	{83}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvFdWR9V3Z72yKNE6CZSJrxXwwYuyCTZnFAd2dD6JgV26o8kELv
82	82	{84,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuTN3Kq8oSUcht6tAVQK4Nz2t1HppqKpcNhqhaxLiug1bagUKtn
83	83	{85}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtkqRTMcCxERegNDzMgmK7zAMaVv1yFekrBBzX6NiY76dCkYeQd
84	84	{86,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JukeBx8WLwBnxdWJdUagwpBQgRuSJSavG5eWXkvYyGVdV5RJHkc
85	85	{87}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuioqDjgGuk6FgUGXBNqxnELtYnvBhuhNngMPAaiaY1pQfmAEVk
86	86	{88,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvHRtgPbCM6McZGJibhbsJF67PnziCh5FAMykFogJR7W62T6osg
87	87	{89}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuywZTjs4aEQ5EBFEpfsLXsPSWxnAC2xaZbXdU2QFngBP5SoLmX
88	88	{90,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuGn9DLL2cnEGzLB9GZvLn8kRnrdyQhmvkcu17DgdJFJyvYokBk
89	89	{91}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvAsbzxbNz4AqPr1Du1SESobGWzVRFUAKCteBuP6HztvFDmvrr2
90	90	{92,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvDWyR7BvX8v7qNUqB6jGUP9PupypRjxS22d5pVPGeJL3W8ozQo
91	91	{93}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtxwndiZwgzVW1HqukWJeE18zVi2oz7jnArQekYEsrF7DX8LWS1
92	92	{94,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtwpBbvM5PL589K8LY6Rrj85gHavtPHqFPnNtXpydcwP3VaD1Ab
93	93	{95}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Judvs5EKQ7BGT34cLU5L5rVqtdKcs6quoEnygFChyg9pbKJYrNs
94	94	{96,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuGtbFXoMYQUb9ELV3Z9yJtneizzVigGhjSp4rYigGW9Ai2ZJ3b
95	95	{97}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jub5QsNc9kYn1BkEL2xoLxyQ4YqWQUHe1BL8uHbBLcQFXxM1AZA
96	96	{98,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JupDK9ubqD6ffyfTzPDXwE2p2B1brin4KPaXqmK4sH98kLqcvqv
97	97	{99}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuBjnS3UCFGjPhr7xuEvYNnSvcZC1wYpUfSQxQwrKFqSvCHBzR4
98	98	{100,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JusaNySwi9qWFhX6WAybjfyEeHChxPRRGbqBH2W7RJN4jQzdvbs
99	99	{101}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtkQWC6cvdmgpvKorvqvCZTHiqD9yvN5DWcJ3JKgY1ubdDy1HaH
100	100	{102,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JudhL5d4vehSQPwKaZPDXwuGu7171MK5PiWAXYQamAb3VQPCVQe
101	101	{103}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtrM6gUSFwJfxD4cgXH68jJa4e4Xb1gFPr8E749dWdfHKKSFxQp
102	102	{104,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JurCy5vktPntB3DycoZ2erfKn7w1W7AwbWc1Mkrqt52vU2rpWPA
103	103	{105}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuAzYwYF5aGjcchzHULsVbihMoEd1HbZ98eDA5yseuwyLnCRxm5
104	104	{106,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtdYLPY14WAX4JGGWUJ6wXJMg9L7Cni3ZZ5cvrmeaYP9GrJULQN
105	105	{107}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jte7SEkrHnTfxVVNcxHZZ2vNKQcyGWSsANUxqHu1EDrcRYuT5ic
106	106	{108,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JupKXAhKrVhWwFqYdMWKbx38ooWTUGUSFttdx7AMdqZmJRHN7jB
107	107	{109}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvALuK1XPr3vAF8tjfi9UWrDXbDqYQHCrLTi5noY2aQeiEDcS6h
108	108	{110,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtyJyVvj1Xrj85kyQWknwGuG7ss2VuAUv5KKXPTEQ4dYyap7knv
109	109	{111}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuPhYQ2NXTnKNEyZy3cZF8vZ5Wit8hJXZmDy6zpTuc4pzSxrskN
110	110	{112,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuXu76oRZfgwY2HbjkWjZQWnMZhGvdpoaBr7Q3c9wg1wotqwbzz
111	111	{113}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvDH6RyFvbdivGj2AdEYvnjKPAc19bEqPCgCvR4VGNHeuYkGocR
112	112	{114,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtjKQp5q1D8t3U5pdYcFPgB9kPAN7361rmnwmw9sWHEiV8PRs1m
113	113	{115}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jukr5Ltp4xSFw5Jueo48N9bK24FtWYU3xGMt7LUPg3fKcktrddH
114	114	{116,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jte1beWpUR5wSBKfHgcdtp6GZtK6fRQ82ZzQHQp62JyukB1Ro8E
115	115	{117}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv9YL3pueTdufupPszQzB91ENxKp2NsN6tdg7CXLJ67cABTCWco
116	116	{118,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuGawf58FKj47tGHvSGsHj7fh1xiMGq3SW4xvpcr1p6inrpMrsY
117	117	{119}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuDh9NHJYMK9gpewhRNJiJBHbjF3sUtzrkD5zmKrYFsV6ccEY1G
118	118	{120,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtk3Qbyopxzmc1asEhLyBKMkRDPMciDo9GU8pjicb2HLDhuPM8w
119	119	{121}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvBraYu2yBZ2RQhVTsg47grozwkbta3PyCV46QUuQo9AujXNWsP
120	120	{122,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv9JedvLMh7MQYFhCS73nLnLzMwa71DEmnX92TMFsrbqbnCGdzT
121	121	{123}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvMQ1W99aEaArU3yyhxoB75m8mK4vrxh8qFJmJH5D6veYt4DKqq
122	122	{124,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuueoFmvqPfN83reFmtJaYivVybwLSv9822wQYUPWjghRPf5Q5w
123	123	{125}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvDuvCPgCr4DPhbDC6GdvfrpoVFnSxNa4t9dQQgMyJsMwTsEgkk
124	124	{126,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtXVvKYo5ki1iw6WbLfpajb8HhjXC1yCkVVa32HCsVCUJXNjMML
125	125	{127}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvRFuAg4wcWzrPDaiG9HtgUuf7rU1z1JFMv96zgAr677xNob9i8
126	126	{128,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju4YFrTbzpxBpwiB7TsmsxvsPSBdygL9FqgSWUbAbUj6AKrS5xt
127	127	{129}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuaiYZiNcxPfn7qZsRgqqpieqQ5M3XSxtH7HuGyefo9D5ZbNXb1
128	128	{130,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuktLDkDJKi5e3RH47oUPE4i6LHMGjyyBgcfMS7hDwmmHsgrScX
129	129	{131}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JukdGhkpADk2r6bh7xnau7ckBFTeESwrVQ1ogP4EigxUzW9qwRY
130	130	{132,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvEMugRLM7wvaohXJTKWENhMaMSAFrq9bYEjnGxkVJASAJxTpHr
131	131	{133}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuR8dNxJ7kjorwQL2bVMYr6QANBShG6g14CoqonSGuNbNgoRMBq
132	132	{134,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtwbCwrYa4U18L7RjATqBRLEWJutFunRBoisb78KKPz22GVPPsH
133	133	{135}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuLrZ91DZNUcMuQCcdnDvdJCNfUxhAGcrUeHQvsYWGUgsvZ9yZw
134	134	{136,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv7TdhrsqhTtut5TyVPQ9oy3J3Rw4dobWzjKcTYy1LE5jtnJcVh
135	135	{137}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuggNroj87o1qSNz7yVfuHarrNLXbyWA7jVzzfkqP3dHuaxXQKQ
136	136	{138,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv8t1AJ8yzBYFNg2hBK7jTbpjmjKVcywDWrVhEgziwMAwRfZHRw
137	137	{139}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvBAoz2BgKqcfpCrdeM55VNCt1zNc4N6HGhckBLDco45UcZ1uZA
138	138	{140,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtdw42kC4w6QhPeXDpZdf2EZDjg6pXeRDqRE7DfdmAMVex66W5E
139	139	{141}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtkDXmVAfcbDBbme8fW864pbpkRWzHgWFXwvUyeia3Qua1E7HnP
140	140	{142,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuZZUNvgEveb4BZbBHVJzRcT5WUG5pYktts4GmZ9gDFCvTqvwjz
141	141	{143}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuJD2HqWshb4jwqz5Kvgy1Xz8rZyojj6XwcWWBRkqrsuoccD9xx
142	142	{144,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuMWvknDCZiaJ7KRaZDvJMjVHh5QrAQ7tcocPtRD7Up7CfcmDMd
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
1	161	5000000000	\N	0
2	161	5000000000	\N	1
3	161	5000000000	\N	2
4	161	5000000000	\N	3
5	161	5000000000	\N	4
6	161	5000000000	\N	5
7	161	5000000000	\N	6
8	161	5000000000	\N	7
9	161	5000000000	\N	8
10	161	5000000000	\N	9
11	161	5000000000	\N	10
12	161	5000000000	\N	11
13	161	5000000000	\N	12
14	161	5000000000	\N	13
15	161	5000000000	\N	14
16	161	5000000000	\N	15
17	161	5000000000	\N	16
18	161	5000000000	\N	17
19	161	5000000000	\N	18
20	161	5000000000	\N	19
21	161	5000000000	\N	20
22	161	5000000000	\N	21
23	161	5000000000	\N	22
24	161	5000000000	\N	23
25	161	5000000000	\N	24
26	161	5000000000	\N	25
27	161	5000000000	\N	26
28	161	5000000000	\N	27
29	161	5000000000	\N	28
30	161	5000000000	\N	29
31	161	5000000000	\N	30
32	161	5000000000	\N	31
33	161	5000000000	\N	32
34	161	5000000000	\N	33
35	161	5000000000	\N	34
36	161	5000000000	\N	35
37	161	5000000000	\N	36
38	161	5000000000	\N	37
39	161	5000000000	\N	38
40	161	5000000000	\N	39
41	161	5000000000	\N	40
42	161	5000000000	\N	41
43	161	5000000000	\N	42
44	161	5000000000	\N	43
45	161	5000000000	\N	44
46	161	5000000000	\N	45
47	161	5000000000	\N	46
48	161	5000000000	\N	47
49	161	5000000000	\N	48
50	161	5000000000	\N	49
51	161	5000000000	\N	50
52	161	5000000000	\N	51
53	161	5000000000	\N	52
54	161	5000000000	\N	53
55	161	5000000000	\N	54
56	161	5000000000	\N	55
57	161	5000000000	\N	56
58	161	5000000000	\N	57
59	161	5000000000	\N	58
60	161	5000000000	\N	59
61	161	5000000000	\N	60
62	161	5000000000	\N	61
63	161	5000000000	\N	62
64	161	5000000000	\N	63
65	161	5000000000	\N	64
66	161	5000000000	\N	65
67	161	5000000000	\N	66
68	161	5000000000	\N	67
69	161	5000000000	\N	68
70	161	5000000000	\N	69
71	161	5000000000	\N	70
72	161	5000000000	\N	71
73	161	5000000000	\N	72
74	161	5000000000	\N	73
75	161	5000000000	\N	74
76	161	5000000000	\N	75
77	161	5000000000	\N	76
78	161	5000000000	\N	77
79	161	5000000000	\N	78
80	161	5000000000	\N	79
81	161	5000000000	\N	80
82	161	5000000000	\N	81
83	161	5000000000	\N	82
84	161	5000000000	\N	83
85	161	5000000000	\N	84
86	161	5000000000	\N	85
87	161	5000000000	\N	86
88	161	5000000000	\N	87
89	161	5000000000	\N	88
90	161	5000000000	\N	89
91	161	5000000000	\N	90
92	161	5000000000	\N	91
93	161	5000000000	\N	92
94	161	5000000000	\N	93
95	161	5000000000	\N	94
96	161	5000000000	\N	95
97	161	5000000000	\N	96
98	161	5000000000	\N	97
99	161	5000000000	\N	98
100	161	5000000000	\N	99
101	161	5000000000	\N	100
102	161	5000000000	\N	101
103	161	5000000000	\N	102
104	161	5000000000	\N	103
105	161	5000000000	\N	104
106	161	5000000000	\N	105
107	161	5000000000	\N	106
108	161	5000000000	\N	107
109	161	5000000000	\N	108
110	161	5000000000	\N	109
111	161	5000000000	\N	110
112	161	5000000000	\N	111
113	161	5000000000	\N	112
114	161	5000000000	\N	113
115	161	5000000000	\N	114
116	161	5000000000	\N	115
117	161	5000000000	\N	116
118	161	5000000000	\N	117
119	161	5000000000	\N	118
120	161	5000000000	\N	119
121	161	5000000000	\N	120
122	161	5000000000	\N	121
123	161	5000000000	\N	122
124	161	5000000000	\N	123
125	161	5000000000	\N	124
126	161	5000000000	\N	125
127	161	5000000000	\N	126
128	161	5000000000	\N	127
129	161	5000000000	\N	128
130	161	5000000000	\N	129
131	161	5000000000	\N	130
132	161	5000000000	\N	131
133	161	5000000000	\N	132
134	161	5000000000	\N	133
135	161	5000000000	\N	134
136	161	5000000000	\N	135
137	161	5000000000	\N	136
138	161	5000000000	\N	137
139	161	5000000000	\N	138
140	161	5000000000	\N	139
141	161	5000000000	\N	140
142	161	5000000000	\N	141
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
\.


--
-- Data for Name: zkapp_permissions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.zkapp_permissions (id, edit_state, send, receive, access, set_delegate, set_permissions, set_verification_key, set_zkapp_uri, edit_action_state, set_token_symbol, increment_nonce, set_voting_for, set_timing) FROM stdin;
1	signature	signature	none	none	signature	signature	signature	signature	signature	signature	signature	signature	signature
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

SELECT pg_catalog.setval('public.blocks_id_seq', 13, true);


--
-- Name: epoch_data_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.epoch_data_id_seq', 14, true);


--
-- Name: internal_commands_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.internal_commands_id_seq', 11, true);


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

SELECT pg_catalog.setval('public.user_commands_id_seq', 72, true);


--
-- Name: voting_for_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.voting_for_id_seq', 1, true);


--
-- Name: zkapp_account_precondition_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_account_precondition_id_seq', 73, true);


--
-- Name: zkapp_account_update_body_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_account_update_body_id_seq', 144, true);


--
-- Name: zkapp_account_update_failures_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_account_update_failures_id_seq', 4, true);


--
-- Name: zkapp_account_update_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_account_update_id_seq', 144, true);


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

SELECT pg_catalog.setval('public.zkapp_commands_id_seq', 142, true);


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

SELECT pg_catalog.setval('public.zkapp_fee_payer_body_id_seq', 142, true);


--
-- Name: zkapp_field_array_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_field_array_id_seq', 1, false);


--
-- Name: zkapp_field_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_field_id_seq', 70, true);


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

SELECT pg_catalog.setval('public.zkapp_nonce_bounds_id_seq', 72, true);


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

SELECT pg_catalog.setval('public.zkapp_states_nullable_id_seq', 71, true);


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

SELECT pg_catalog.setval('public.zkapp_updates_id_seq', 72, true);


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
-- Name: protocol_versions protocol_versions_transaction_network_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.protocol_versions
    ADD CONSTRAINT protocol_versions_transaction_network_key UNIQUE (transaction, network);


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
-- Name: timing_info timing_info_account_identifier_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.timing_info
    ADD CONSTRAINT timing_info_account_identifier_id_key UNIQUE (account_identifier_id);


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

