--
-- PostgreSQL database dump
--

-- Dumped from database version 14.13
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
-- Name: zkapp_account_permissions_precondition; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.zkapp_account_permissions_precondition (
    id integer NOT NULL,
    edit_state public.zkapp_auth_required_type,
    send public.zkapp_auth_required_type,
    receive public.zkapp_auth_required_type,
    access public.zkapp_auth_required_type,
    set_delegate public.zkapp_auth_required_type,
    set_permissions public.zkapp_auth_required_type,
    set_verification_key public.zkapp_auth_required_type,
    set_zkapp_uri public.zkapp_auth_required_type,
    edit_action_state public.zkapp_auth_required_type,
    set_token_symbol public.zkapp_auth_required_type,
    increment_nonce public.zkapp_auth_required_type,
    set_voting_for public.zkapp_auth_required_type,
    set_timing public.zkapp_auth_required_type
);


ALTER TABLE public.zkapp_account_permissions_precondition OWNER TO postgres;

--
-- Name: zkapp_account_permissions_precondition_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.zkapp_account_permissions_precondition_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.zkapp_account_permissions_precondition_id_seq OWNER TO postgres;

--
-- Name: zkapp_account_permissions_precondition_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.zkapp_account_permissions_precondition_id_seq OWNED BY public.zkapp_account_permissions_precondition.id;


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
    is_new boolean,
    permissions_id integer
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
-- Name: zkapp_account_permissions_precondition id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_account_permissions_precondition ALTER COLUMN id SET DEFAULT nextval('public.zkapp_account_permissions_precondition_id_seq'::regclass);


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
144	59	1
145	146	1
146	147	1
147	148	1
148	149	1
149	150	1
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
172	151	1
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
13	1	56	1	215	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	56	1	\N
1	1	57	1	65500000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	59	1	57	1	\N
241	1	58	1	131	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	60	1	58	1	\N
218	1	59	1	193	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	61	1	59	1	\N
14	1	60	1	60	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	62	1	60	1	\N
56	1	61	1	350	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	63	1	61	1	\N
144	1	62	1	223	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	64	1	62	1	\N
60	1	63	1	449	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	65	1	63	1	\N
183	1	64	1	142	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	66	1	64	1	\N
149	1	65	1	300	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	67	1	65	1	\N
163	1	66	1	256	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	68	1	66	1	\N
101	1	67	1	125	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	69	1	67	1	\N
39	1	68	1	236	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	70	1	68	1	\N
237	1	69	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	71	1	69	1	\N
108	1	70	1	179	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	72	1	70	1	\N
11	1	71	1	194	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	73	1	71	1	\N
24	1	72	1	185	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	74	1	72	1	\N
96	1	73	1	342	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	75	1	73	1	\N
213	1	74	1	157	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	76	1	74	1	\N
89	1	75	1	135	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	77	1	75	1	\N
157	1	76	1	456	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	78	1	76	1	\N
206	1	77	1	336	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	79	1	77	1	\N
205	1	78	1	280	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	80	1	78	1	\N
180	1	79	1	187	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	81	1	79	1	\N
155	1	80	1	387	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	82	1	80	1	\N
31	1	81	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	83	1	81	1	\N
199	1	82	1	151	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	84	1	82	1	\N
7	1	83	1	202	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	85	1	83	1	\N
6	1	84	1	0	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	86	1	84	1	\N
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
188	1	109	1	294	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	111	1	109	1	\N
216	1	110	1	191	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	112	1	110	1	\N
91	1	111	1	380	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	113	1	111	1	\N
160	1	112	1	331	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	114	1	112	1	\N
219	1	113	1	459	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	115	1	113	1	\N
203	1	114	1	28	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	116	1	114	1	\N
193	1	115	1	472	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	117	1	115	1	\N
32	1	116	1	119	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	118	1	116	1	\N
211	1	117	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	119	1	117	1	\N
194	1	118	1	41	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	120	1	118	1	\N
102	1	119	1	27	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	121	1	119	1	\N
42	1	120	1	70	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	122	1	120	1	\N
50	1	121	1	337	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	123	1	121	1	\N
112	1	122	1	210	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	124	1	122	1	\N
175	1	123	1	495	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	125	1	123	1	\N
146	1	124	1	144	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	126	1	124	1	\N
98	1	125	1	148	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	127	1	125	1	\N
204	1	126	1	376	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	128	1	126	1	\N
26	1	127	1	329	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	129	1	127	1	\N
171	1	128	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	130	1	128	1	\N
128	1	129	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	131	1	129	1	\N
37	1	130	1	181	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	130	1	\N
210	1	131	1	200	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	133	1	131	1	\N
114	1	132	1	159	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	134	1	132	1	\N
46	1	133	1	319	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	135	1	133	1	\N
99	1	134	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	136	1	134	1	\N
201	1	135	1	365	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	137	1	135	1	\N
48	1	136	1	342	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	138	1	136	1	\N
57	1	137	1	237	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	139	1	137	1	\N
148	1	138	1	427	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	140	1	138	1	\N
178	1	139	1	315	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	141	1	139	1	\N
140	1	140	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	142	1	140	1	\N
21	1	141	1	378	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	143	1	141	1	\N
120	1	142	1	420	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	144	1	142	1	\N
113	1	143	1	411	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	145	1	143	1	\N
2	1	144	1	500000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	59	1	144	1	\N
73	1	145	1	172	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	146	1	145	1	\N
75	1	146	1	309	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	147	1	146	1	\N
150	1	147	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	148	1	147	1	\N
118	1	148	1	154	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	149	1	148	1	\N
3	1	149	1	11550000000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	151	1	149	1	\N
116	1	150	1	153	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	152	1	150	1	\N
35	1	151	1	47	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	153	1	151	1	\N
166	1	152	1	87	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	154	1	152	1	\N
147	1	153	1	398	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	155	1	153	1	\N
27	1	154	1	452	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	156	1	154	1	\N
86	1	155	1	291	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	157	1	155	1	\N
231	1	156	1	367	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	158	1	156	1	\N
81	1	157	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	159	1	157	1	\N
152	1	158	1	311	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	160	1	158	1	\N
173	1	159	1	258	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	161	1	159	1	\N
67	1	160	1	323	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	162	1	160	1	\N
61	1	161	1	405	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	163	1	161	1	\N
187	1	162	1	32	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	164	1	162	1	\N
90	1	163	1	130	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	165	1	163	1	\N
138	1	164	1	234	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	166	1	164	1	\N
15	1	165	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	167	1	165	1	\N
85	1	166	1	481	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	166	1	\N
181	1	167	1	240	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	169	1	167	1	\N
127	1	168	1	314	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	170	1	168	1	\N
191	1	169	1	183	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	171	1	169	1	\N
172	1	170	1	486	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	172	1	170	1	\N
55	1	171	1	178	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	173	1	171	1	\N
4	1	172	1	0	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	151	1	172	1	\N
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
5	1	195	1	11550000000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	86	1	195	1	\N
223	1	196	1	256	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	197	1	196	1	\N
132	1	197	1	128	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	198	1	197	1	\N
95	1	198	1	199	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	199	1	198	1	\N
82	1	199	1	22	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	200	1	199	1	\N
159	1	200	1	276	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	201	1	200	1	\N
226	1	201	1	451	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	202	1	201	1	\N
236	1	202	1	133	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	203	1	202	1	\N
63	1	203	1	460	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	204	1	203	1	\N
217	1	204	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	205	1	204	1	\N
54	1	205	1	489	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	206	1	205	1	\N
161	1	206	1	190	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	207	1	206	1	\N
190	1	207	1	221	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	208	1	207	1	\N
141	1	208	1	464	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	209	1	208	1	\N
59	1	209	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	210	1	209	1	\N
134	1	210	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	211	1	210	1	\N
69	1	211	1	353	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	212	1	211	1	\N
143	1	212	1	396	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	213	1	212	1	\N
104	1	213	1	417	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	214	1	213	1	\N
136	1	214	1	46	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	215	1	214	1	\N
156	1	215	1	305	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	216	1	215	1	\N
121	1	216	1	337	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	217	1	216	1	\N
23	1	217	1	444	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	218	1	217	1	\N
238	1	218	1	479	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	219	1	218	1	\N
209	1	219	1	344	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	220	1	219	1	\N
239	1	220	1	113	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	221	1	220	1	\N
195	1	221	1	236	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	222	1	221	1	\N
168	1	222	1	480	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	223	1	222	1	\N
29	1	223	1	160	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	224	1	223	1	\N
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
3	3	144	1	499250000000	3	2n1t8Q8EZsEyBjvTjW3VMpnvjDXsLAmukN6FWpuqc6gJopP55Eot	59	1	144	1	\N
5	3	172	1	720750000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	151	1	172	1	\N
7	4	84	1	720750000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	86	1	84	1	\N
3	4	144	1	499250000000	3	2n1t8Q8EZsEyBjvTjW3VMpnvjDXsLAmukN6FWpuqc6gJopP55Eot	59	1	144	1	\N
7	5	84	1	722250000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	86	1	84	1	\N
3	5	144	1	497000000000	12	2n1cEQfoh87sG71CQQfgt5QpfqBdfpzdai4E4tL8BRKPHwKMSFjD	59	1	144	1	\N
7	6	84	1	1448500000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	86	1	84	1	\N
3	6	144	1	490750000000	37	2mzqrWgVtnqDTSK1rS9CQBTQGaZAV5Htj4SAnnEwwoet97F8HGdG	59	1	144	1	\N
7	7	84	1	2171500000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	86	1	84	1	\N
3	7	144	1	487750000000	49	2n2R1tJj1i9cZKCUQNPWLeiidasc98HV4JhaZh6QVMjQ2TyDbQrh	59	1	144	1	\N
7	8	84	1	2894500000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	86	1	84	1	\N
3	8	144	1	484750000000	61	2n1PxCgBamTgHEFMgbi3sVp1J4AgUyU5UNmaUVrvNDuKdDEArRTn	59	1	144	1	\N
3	9	144	1	481750000000	73	2n2MGvTts6LiTVLysRVrr3RrM53DcUWXx1MiVT8qepqRAoJF1RGd	59	1	144	1	\N
5	9	172	1	1443750000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	151	1	172	1	\N
7	10	84	1	3617500000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	86	1	84	1	\N
3	10	144	1	481750000000	73	2n2MGvTts6LiTVLysRVrr3RrM53DcUWXx1MiVT8qepqRAoJF1RGd	59	1	144	1	\N
7	11	84	1	4343750000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	86	1	84	1	\N
3	11	144	1	475500000000	98	2mzoUkZ7wu5SX9DzX1hW4zFmMUG5Mqu9JB1qGG3g395w8eF41AJo	59	1	144	1	\N
7	12	84	1	5066750000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	86	1	84	1	\N
3	12	144	1	472500000000	110	2mzXyvMwRqkhMaCq6yU3Hmr9FxgxtSsHes3HWmk1cHHoJ69QKdmY	59	1	144	1	\N
3	13	144	1	472500000000	110	2mzXyvMwRqkhMaCq6yU3Hmr9FxgxtSsHes3HWmk1cHHoJ69QKdmY	59	1	144	1	\N
5	13	172	1	1443750000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	151	1	172	1	\N
3	14	144	1	469500000000	122	2mzdWLpohrf6mkQH5TxB2udL9incQdZySJwMWZcDGMaK8SjBAZiB	59	1	144	1	\N
5	14	172	1	1443750000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	151	1	172	1	\N
3	15	144	1	466500000000	134	2n1NgHqWK4vzcCtCTJUGAzmWkz1aSfmspUZgs1QfBUQ1b12bSi1t	59	1	144	1	\N
5	15	172	1	2166750000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	151	1	172	1	\N
3	16	144	1	460250000000	159	2n1RxHt2ZzH1933uuCp8LENzbJqE9MkbLbZwQLnfLtd2ugFaBriz	59	1	144	1	\N
5	16	172	1	2893000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	151	1	172	1	\N
7	17	84	1	5793000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	86	1	84	1	\N
3	17	144	1	460250000000	159	2n1RxHt2ZzH1933uuCp8LENzbJqE9MkbLbZwQLnfLtd2ugFaBriz	59	1	144	1	\N
3	18	144	1	457250000000	171	2mzhMjRvTCsiAKET3yHejaAtSVMNPjmPbtVfL3ETD9swNd9gjP7Z	59	1	144	1	\N
5	18	172	1	2889750000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	151	1	172	1	\N
3	19	144	1	454250000000	183	2n1Ht4gTEF6Yctq7LAri2BPhPQCVoPYcw3hqqws8zawXvaouzaxS	59	1	144	1	\N
5	19	172	1	3612750000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	151	1	172	1	\N
7	20	84	1	6516000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	86	1	84	1	\N
3	20	144	1	451250000000	195	2n1cFqsYDf69iefH3tvPWKtyHr84hrBAWosqwZtoi7YSGcBrpXwP	59	1	144	1	\N
3	21	144	1	451250000000	195	2n1cFqsYDf69iefH3tvPWKtyHr84hrBAWosqwZtoi7YSGcBrpXwP	59	1	144	1	\N
5	21	172	1	4335750000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	151	1	172	1	\N
7	22	84	1	6516000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	86	1	84	1	\N
3	22	144	1	448250000000	207	2n26X7bLQvSnWiMpf992E8wd4u33ZJ3gBiQQ7wZ7iWk1Dy5wZA3M	59	1	144	1	\N
3	23	144	1	448250000000	207	2n26X7bLQvSnWiMpf992E8wd4u33ZJ3gBiQQ7wZ7iWk1Dy5wZA3M	59	1	144	1	\N
5	23	172	1	5058750000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	151	1	172	1	\N
3	24	144	1	445000000000	220	2n22J4Y7go3eLZCs3rYh5gjowwiSiVby6QRRWjQ7j1yGxMrwedFS	59	1	144	1	\N
5	24	172	1	5782000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	151	1	172	1	\N
7	25	84	1	6516250000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	86	1	84	1	\N
3	25	144	1	445000000000	220	2n22J4Y7go3eLZCs3rYh5gjowwiSiVby6QRRWjQ7j1yGxMrwedFS	59	1	144	1	\N
3	27	144	1	439000000000	244	2n1cvsDaQoM2vyMpHDUd8tpZq1UvKUZc6L7BAXKfrL3CM8TFUcpv	59	1	144	1	\N
5	27	172	1	7228000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	151	1	172	1	\N
7	29	84	1	6516000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	86	1	84	1	\N
3	29	144	1	436000000000	256	2n1o8APDJNPT5YBSx8dN7Cea2SFKxyVaKMKu3Ru2gcsdbiUJMBey	59	1	144	1	\N
7	31	84	1	6516000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	86	1	84	1	\N
3	31	144	1	423750000000	305	2n1A5SfZsTWemU2UHmjNU8JCRR2Hi7kz8DcWYukwxcnfVmjFntym	59	1	144	1	\N
3	33	144	1	420750000000	317	2n1NKRag3rUT5Y2PUKS64GHsyLAdkXf9D4Y2qMEvbQgPtTgWsyT1	59	1	144	1	\N
5	33	172	1	9403250000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	151	1	172	1	\N
7	35	84	1	7962000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	86	1	84	1	\N
3	35	144	1	417750000000	329	2n1Lk4qrsKFQqvvs3uj9u9SAbEWHjM24EK4ofY5ew7BqkQPxvgz6	59	1	144	1	\N
3	37	144	1	408500000000	366	2n1KH7c2msJqyBWAc4s1JvURDi7ankHAyoNxPzgjqLCzzPusTapw	59	1	144	1	\N
5	37	172	1	10126250000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	151	1	172	1	\N
7	39	84	1	9410936000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	86	1	84	1	\N
3	39	144	1	405750000000	377	2n2Pbd7Fi3BUbK7QzugR2dSPvhz7yh1oCyAyMjtweejYidirTRAn	59	1	144	1	\N
3	26	144	1	442000000000	232	2n1U6NKPjQV6HMm8dWmdco46VUhWqcXt3BqjBqQxKUBCxp8DUszV	59	1	144	1	\N
5	26	172	1	6505000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	151	1	172	1	\N
3	28	144	1	436000000000	256	2n1o8APDJNPT5YBSx8dN7Cea2SFKxyVaKMKu3Ru2gcsdbiUJMBey	59	1	144	1	\N
5	28	172	1	7951000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	151	1	172	1	\N
3	30	144	1	426750000000	293	2mzrNhHnirgGVrqX3TiUecZVF1DutJ7vETzDTwYmgM2XbNnddQVy	59	1	144	1	\N
5	30	172	1	8680250000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	151	1	172	1	\N
7	32	84	1	7239000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	86	1	84	1	\N
3	32	144	1	420750000000	317	2n1NKRag3rUT5Y2PUKS64GHsyLAdkXf9D4Y2qMEvbQgPtTgWsyT1	59	1	144	1	\N
3	34	144	1	417750000000	329	2n1Lk4qrsKFQqvvs3uj9u9SAbEWHjM24EK4ofY5ew7BqkQPxvgz6	59	1	144	1	\N
5	34	172	1	9403250000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	151	1	172	1	\N
7	36	84	1	7965186000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	86	1	84	1	\N
3	36	144	1	411500000000	354	2n18PQQp3RZ4pjLjwFDQFYR8HoJ16NARCeWZiR1QrkEzLKutWJtK	59	1	144	1	\N
1	36	235	1	5064000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	236	1	235	1	\N
7	38	84	1	8688186000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	86	1	84	1	\N
3	38	144	1	408500000000	366	2n1KH7c2msJqyBWAc4s1JvURDi7ankHAyoNxPzgjqLCzzPusTapw	59	1	144	1	\N
3	40	144	1	405750000000	377	2n2Pbd7Fi3BUbK7QzugR2dSPvhz7yh1oCyAyMjtweejYidirTRAn	59	1	144	1	\N
5	40	172	1	10126000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	151	1	172	1	\N
3	41	144	1	402750000000	389	2n2HDoE7g6CyKcEbHMRv32FGb7A9CECiz2Z6EAuzZwBAQN616Qsw	59	1	144	1	\N
5	41	172	1	10849000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	151	1	172	1	\N
3	42	144	1	399750000000	401	2n23oT86getyzEjMgDL8Nw5oRQo5bjxL1Q8xcDrp33hJDaPSs5R5	59	1	144	1	\N
5	42	172	1	11572000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	151	1	172	1	\N
7	43	84	1	9411186000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	86	1	84	1	\N
3	43	144	1	396750000000	413	2mzz1z19F9uYreTehXSL5mLreSHvycssY4eEFs9hc14PsvxXvxbj	59	1	144	1	\N
3	44	144	1	396750000000	413	2mzz1z19F9uYreTehXSL5mLreSHvycssY4eEFs9hc14PsvxXvxbj	59	1	144	1	\N
5	44	172	1	12295000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	151	1	172	1	\N
7	45	84	1	10134186000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	86	1	84	1	\N
3	45	144	1	393750000000	425	2n1TzKXXr7TTuuQXM5g7jo7qXRi33DXMDrLQFEzfUZUzCYhDvpFp	59	1	144	1	\N
3	46	144	1	393750000000	425	2n1TzKXXr7TTuuQXM5g7jo7qXRi33DXMDrLQFEzfUZUzCYhDvpFp	59	1	144	1	\N
5	46	172	1	12295000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	151	1	172	1	\N
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
44	3NL4KfUkq66wfdtdWMmyp7a2WiHEkmucAKSBm9xHesPtcwzjrTZv	42	3NLTzNs8e6z6n1NRbQG3W3Vma433DR89GNPhohW1FwkEGxhLmpiG	151	150	7sbZNSuyhlGpZxSEBEDZ4AUn8EZCA3lZlbt1EqX2ug4=	2	3	46	77	{5,6,6,5,6,2,7,7,7,7,7}	23166005000061388	jxRApi9cRybgSJiLfowAALpqWTmDKKjQpDvURGVrNMcdyg32jiX	30	36	36	1	\N	1729791664000	orphaned
46	3NKfXhFGPhMFAStDetUJCPqyGF28emoWxAV3yTRY48YZUCd3QeiG	43	3NLWa8E1pZytLBcexCUw2ot3STCbgAQR9RRNCZ1rfohyrhS8bKTC	151	150	ZhCZc7tRTC98a4HQyPoTqllPjCF-Scb-Yu0DLcX4JA4=	2	3	48	77	{5,6,6,5,6,3,7,7,7,7,7}	23166005000061388	jwVUrAWTJHRiQY3ouJoKiTvP2APpoQBp1aKmEAhbL9EWrbk52cU	31	37	37	1	\N	1729791844000	canonical
42	3NLTzNs8e6z6n1NRbQG3W3Vma433DR89GNPhohW1FwkEGxhLmpiG	41	3NLEvcXKLyi45F66JJGcM2r9nnMT2Khy6o2oFXy4DZUCBCXJTtVA	151	150	2WZg42mi1iZupn3BYZmHIvO0R0bMfyaAum85totT7go=	2	3	44	77	{5,6,6,5,6,1,7,7,7,7,7}	23166005000061388	jxZwDnX4qZwuNMikn8GypMBn4aSvcEn3EfwWD752X3awe5JK83a	29	35	35	1	\N	1729791484000	canonical
40	3NKLpVPw1nN183YfHpvvkz9QVDTJCoCdxmod2dunc2GYAHtXbTZZ	38	3NLg1kVvQMCTAx6468s6dzJgbFZpwy9nMTUZR5ThS8avrSmPA74f	151	150	hJxEHlT8rvfVA-8Dxxz4Si3-EvLsx1gzGCA0eDi7PQw=	2	3	42	77	{5,6,6,5,5,7,7,7,7,7,7}	23166005000061388	jxvdPcELJvM3snLH8ZLzy8a2rRKreLH4TTYrfPXqDskALywQ66f	27	33	33	1	\N	1729791124000	canonical
38	3NLg1kVvQMCTAx6468s6dzJgbFZpwy9nMTUZR5ThS8avrSmPA74f	36	3NLTte5mWw2qfrwzqseQk52xj3axGyyTJNtiXdd5zp3Bs471Mydp	86	196	d6fuB-3QOhuwhb9Evq649Z1_6wPgQSrYWQBHau-IMwM=	2	3	40	77	{5,6,6,5,4,7,7,7,7,7,7}	23166005000061388	jwyigE4MLVfFNYG4Ym3yk3V8w3jgo8XSfgV9rWVF1ZCmQx9XPrc	26	32	32	1	\N	1729790944000	canonical
36	3NLTte5mWw2qfrwzqseQk52xj3axGyyTJNtiXdd5zp3Bs471Mydp	34	3NKuHu37zQkaFALuzS3FrYAJq8ny26LtkpXaLRiwQy2sZsDA2faZ	86	196	H3o5NeXoCS-HJIGVbC6qwbBDm6n_Ij9QWVSsF2GJmgE=	2	3	38	77	{5,6,6,5,3,7,7,7,7,7,7}	23166005000061388	jwbDaXAgEZegwK7NrjhtNtF4QCauN3X4ABBh8A7x5xduX847pP7	25	31	31	1	\N	1729790764000	canonical
31	3NLcWtkJyNbKxEUzWhTb3Qk8c9EBxrbtYLCReRfB1tKwjhTg7Zxr	30	3NLdTDBe3oWrQVa65zExg9cu97Q5tfHcCFbqxGwVGfsNxMSvi1Tg	86	196	UuzOXrEeP6L8i5B0lZd-JAa23e0yT4Usj_4asXUjhww=	2	3	33	77	{5,6,6,5,7,7,7,7,7,7,7}	23166005000061388	jwmDSpYtb6Wcij4qoHED8Czh4mXzj76TkRaW2X8sneZJUZSDsXT	22	27	27	1	\N	1729790044000	canonical
27	3NLghxkgzdp9QSRnGw56Ft9RMMwdN7meCjGJSay2jGE1TvMaxRFx	26	3NKp69gQwaNR8nYuhryoUSEmwouBTrCPGJh6od8jCwA1UZxTguDr	151	150	OkkKw9kR_XbXR6yLXbI9cadOr5kQjxyQDjlhSGeb9wc=	2	3	29	77	{5,6,6,2,7,7,7,7,7,7,7}	23166005000061388	jxR35TSKJx4FxCaMw3XyCpWyuVsiXdu2FM4B7SS3wNjfcZFgWHr	19	22	22	1	\N	1729789144000	canonical
23	3NLbqXtSz61S1AyqtvL5SGtz4v1rUGkBfQn1Y5gdaGE3SB4ZYrG7	21	3NKasKxGydjWnh1XpoVyu4V345FaaVWQUHuHLRPdQvUEqkrs7DFy	151	150	YOw6dIKxQ0jszEgvC-XRlIOyHDn28y4swIZVo_66qwc=	2	3	25	77	{5,6,5,7,7,7,7,7,7,7,7}	23166005000061388	jwfUcJZ9GbVgAsTnS6N4P8xAG7dcgabmBUSF8dm2QAdoRmmV7Ky	16	19	19	1	\N	1729788604000	canonical
21	3NKasKxGydjWnh1XpoVyu4V345FaaVWQUHuHLRPdQvUEqkrs7DFy	19	3NKueCojy6o3uJjj8Dg6RTgdNLMij1DG8Yeb1cgk66hnhxuu99hp	151	150	QJLBwd3s_LJE8vT7SadFLCyumpOAE9PoY418vF8wYQs=	2	3	23	77	{5,6,4,7,7,7,7,7,7,7,7}	23166005000061388	jxQiMWvtBBqNE6hvbGKsbFymU9QUJV1FBMp2t87XcsYUGM9DvCs	15	18	18	1	\N	1729788424000	canonical
19	3NKueCojy6o3uJjj8Dg6RTgdNLMij1DG8Yeb1cgk66hnhxuu99hp	18	3NKfTafWoCELVVptmVRZ5J5vaVUjw1rSARzZ3rcMSRAyAkPdXZbr	151	150	CMC6qFuMVKEx8a68MM7-EPp1g-zKJFOSl0U3AmsdJwk=	2	3	21	77	{5,6,3,7,7,7,7,7,7,7,7}	23166005000061388	jwR4AFeS3yLFsR1X4fwmxLbpeVYcpFZN9aPuTvuE3hpCAVC8cnD	14	17	17	1	\N	1729788244000	canonical
37	3NLN9XNJzs9vM4RGErp5utLo18ESC7erDkjtApSuMpRdSj7eCQ61	36	3NLTte5mWw2qfrwzqseQk52xj3axGyyTJNtiXdd5zp3Bs471Mydp	151	150	ZT2xSFYyr6Hxm0FThgJ1B8oSayMBImgUtHFkeEkwxAI=	2	3	39	77	{5,6,6,5,4,7,7,7,7,7,7}	23166005000061388	jxwXMBRJ7iTUztrmpJt7cbTBdLk4um6wH9oaGxyxN96XdBi9o1H	26	32	32	1	\N	1729790944000	orphaned
39	3NLRWeVELwBJnWqVT7H6jvXMKQe2RCK9KxvsMSJLDDKwjeoS2dzp	38	3NLg1kVvQMCTAx6468s6dzJgbFZpwy9nMTUZR5ThS8avrSmPA74f	86	196	klj7mxE38bTzNhF5jNe1px3Wpo1xYEmQhZE-cTdhQQI=	2	3	41	77	{5,6,6,5,5,7,7,7,7,7,7}	23166005000061388	jxZrshTU3yGqwVE1Q7fqFbAiSSvC5C94hPyeFaKjB7yuVecyHU4	27	33	33	1	\N	1729791124000	orphaned
41	3NLEvcXKLyi45F66JJGcM2r9nnMT2Khy6o2oFXy4DZUCBCXJTtVA	40	3NKLpVPw1nN183YfHpvvkz9QVDTJCoCdxmod2dunc2GYAHtXbTZZ	151	150	TjxnFnk1sz1wnWiAs95AmMesCjFhj_wBzKetkEkwowg=	2	3	43	77	{5,6,6,5,6,7,7,7,7,7,7}	23166005000061388	jxb6HkKzGzy7jcsLkrJ79N6bhhmqZ6oURJ7KjHUboAyZ4rwskH7	28	34	34	1	\N	1729791304000	canonical
43	3NLWa8E1pZytLBcexCUw2ot3STCbgAQR9RRNCZ1rfohyrhS8bKTC	42	3NLTzNs8e6z6n1NRbQG3W3Vma433DR89GNPhohW1FwkEGxhLmpiG	86	196	eOQNykaIFpszU4tVbzb-94zOI1ofGuw2V4D55Hdm-ws=	2	3	45	77	{5,6,6,5,6,2,7,7,7,7,7}	23166005000061388	jwmWeiCK3fef2RXsPYFZKYWvDjjkTzCiQoYLd3TLmxbMynJa3XW	30	36	36	1	\N	1729791664000	orphaned
45	3NKjtbgzPMvDD6ewyey6sNpABfV3ik41vfPtnVEfPW57VzhowuSH	43	3NLWa8E1pZytLBcexCUw2ot3STCbgAQR9RRNCZ1rfohyrhS8bKTC	86	196	zUbCoJxzguHpuJH21igssB-lIN0Yujt_SL-JPuZlhAQ=	2	3	47	77	{5,6,6,5,6,3,7,7,7,7,7}	23166005000061388	jwmREHoFdmDwchUHa9fGpiGtQCo4mMNX1gW7ASNVoG1jouusc84	31	37	37	1	\N	1729791844000	orphaned
20	3NL1BJeRk167GoPLuXGuu5Hg7PquEKzPiUSh9WmMubmFQF8tVkCE	19	3NKueCojy6o3uJjj8Dg6RTgdNLMij1DG8Yeb1cgk66hnhxuu99hp	86	196	Y354mZom8_Fiw-TTl7t-LKhSvqR6JOuSWZh9PukT2Qg=	2	3	22	77	{5,6,4,7,7,7,7,7,7,7,7}	23166005000061388	jwJDQnJp2ds1qJTcmezbvhyQSTNuv78kC7oN4AwbGnkb7yB4EeK	15	18	18	1	\N	1729788424000	orphaned
22	3NKP6Hb2RFSFPB54CEgCcgqHyjPTw4rjioYB37Ukc578FMcGfkTg	21	3NKasKxGydjWnh1XpoVyu4V345FaaVWQUHuHLRPdQvUEqkrs7DFy	86	196	LVtHcBsLiAdb4HAOwc1BUI6WVLbg_7JMIxSxH9-OSQ4=	2	3	24	77	{5,6,5,7,7,7,7,7,7,7,7}	23166005000061388	jxzshc34U7z2Nr5uhQXJhZCuwiQHdD9Qgrj7A8nPbK77kArdNen	16	19	19	1	\N	1729788604000	orphaned
34	3NKuHu37zQkaFALuzS3FrYAJq8ny26LtkpXaLRiwQy2sZsDA2faZ	32	3NKmB8jerJwVZPKbjYnJp854XsZqXpbDnSAs9SLfBSXWs1TKJh8q	151	150	GhX4oFrO0cr58C29yNiJUUIoTvSfyZCoYO8c69wbRwU=	2	3	36	77	{5,6,6,5,2,7,7,7,7,7,7}	23166005000061388	jwpcqfPnwybjDMDMPhcKZwsP1KQPBDi6bQR7oM2B9Pts3yBR8Hb	24	29	29	1	\N	1729790404000	canonical
32	3NKmB8jerJwVZPKbjYnJp854XsZqXpbDnSAs9SLfBSXWs1TKJh8q	31	3NLcWtkJyNbKxEUzWhTb3Qk8c9EBxrbtYLCReRfB1tKwjhTg7Zxr	86	196	02HvevUUq3xlkkQonFpSU-7FqQid9z0qDeBbxKA9GA0=	2	3	34	77	{5,6,6,5,1,7,7,7,7,7,7}	23166005000061388	jwt1TaFGUuUHS7rPVZ2w8TAp2VGFDuFJwHP9sWDy4JPd4LFJCCF	23	28	28	1	\N	1729790224000	canonical
30	3NLdTDBe3oWrQVa65zExg9cu97Q5tfHcCFbqxGwVGfsNxMSvi1Tg	28	3NLP7mTNJNMDkUvtFx5kMJPBmpWyT3uzKLqz3KmftAD9gD8CZ8YP	151	150	QV1dXTVoNQoEloX_zi_TWO69yatT185BX7C6TfFDtQw=	2	3	32	77	{5,6,6,4,7,7,7,7,7,7,7}	23166005000061388	jxDxn1cem71ruaXUJMMxqWKyhsSqdHJGMA8WXZUoV328MFZJhq9	21	26	26	1	\N	1729789864000	canonical
28	3NLP7mTNJNMDkUvtFx5kMJPBmpWyT3uzKLqz3KmftAD9gD8CZ8YP	27	3NLghxkgzdp9QSRnGw56Ft9RMMwdN7meCjGJSay2jGE1TvMaxRFx	151	150	H84WHdnPEmdhEEISmTNymBwbPqH-mMkI7_Mdjm1R-gs=	2	3	30	77	{5,6,6,3,7,7,7,7,7,7,7}	23166005000061388	jxjM9q21v9jSQxvKuy3FNEybeKnVNJCQVtoZFCdicvMy8PeXy22	20	23	23	1	\N	1729789324000	canonical
26	3NKp69gQwaNR8nYuhryoUSEmwouBTrCPGJh6od8jCwA1UZxTguDr	24	3NKGPmsssmeZkZDZQ1Ki7wDL22Ai7EYkFFSqLVy97rLhQiX4aimE	151	150	RH4PjFLEUva0ZWDnOCw9FQpKO7OMeuYAVh0Fae_E6wA=	2	3	28	77	{5,6,6,1,7,7,7,7,7,7,7}	23166005000061388	jxZvK3E3kPEw5kDcgK8EebwmNWzLmU4FsRQW2NvwfrFuYaJxu7s	18	21	21	1	\N	1729788964000	canonical
35	3NKXczeqEcFqwpcjimPW8WP8PX455JqdffaFQEjgeGR8cMmkbz1p	32	3NKmB8jerJwVZPKbjYnJp854XsZqXpbDnSAs9SLfBSXWs1TKJh8q	86	196	dXzEnhCiAAsy0D2ojuL3FDjnUIXL8Mkf62iqJvjE6gQ=	2	3	37	77	{5,6,6,5,2,7,7,7,7,7,7}	23166005000061388	jwiDowQjcxxz7zWEvq31ResvSgqHsiYfkrcjRUyhJtqWUdCkA7i	24	29	29	1	\N	1729790404000	orphaned
1	3NKYBRdZ6HvrmhuSeBMDbt2JsBQaUGHy9dfEFT2d2bxxae9G4HGS	\N	3NKujQPSoCSYPRovP43k4HcRaruMoAPv91dPigFgRczcAJGGsx5K	1	1	39cyg4ZmMtnb_aFUIerNAoAJV8qtkfOpq0zFzPspjgM=	1	1	2	6	{1,2,2}	23166005000060590	jxiRVWEj4jhGbpRdkPJpD8gZ6fo8hCTBkmrRnxYs7g7fUQ7uAhd	1	0	0	1	\N	1729785184000	orphaned
4	3NLhbBBSvveCK63Kf2Jq6bVLSrS1jEL16G8CKpVCYutYnQ4yDzfo	2	3NKvwckEXTdfEMBDSZAHj2Yxb3wDg4AZUtZZb2C9BUuxcrjpaaGh	86	196	bgaYNpnSCHmlX61k2zPZg3wRz92BCBKyasn_Tg94xww=	2	3	6	77	{2,7,7,7,7,7,7,7,7,7,7}	23166005000061388	jxeDtPKNAEGXtH7rX6QUKjoXfPMuRYXhBwQUL473Fqc4pvYv3ar	2	2	2	1	\N	1729785544000	orphaned
9	3NKWMUdSsQxFKURXoX9ExfNt7T6FNvXWBoKW5kJfjpahBBdfNpsv	8	3NKxw72uHWG2jW5qXLodKSwP7VWfdostR8qVoubZy3FWvs2MkxAV	151	150	St-j1yfwPncLsnsUyc-yw2iTmHY9uvHy6r9_JGF3BgA=	2	3	11	77	{5,2,7,7,7,7,7,7,7,7,7}	23166005000061388	jwv6fir2zAegpe5gHPp9Az9pzfNxWRqAny6LS6RPUcneTCxLjNr	7	8	8	1	\N	1729786624000	orphaned
13	3NK4Nmf5HubKeC9dG6EjVB4ztkwZyAsEgpybRKF6GTYY9e5qMJKs	11	3NKPf1BBu3sjhk392nx5Ymm4jj2GpKbiAuTrFfgMfdeVyfJARJ1P	151	150	2G1PTCcMf1XgGqQ6LMFJaJf4DQnPR4eKlXsqanoYiwA=	2	3	15	77	{5,4,7,7,7,7,7,7,7,7,7}	23166005000061388	jx9FeYnZbaXfkpSKnAStd7JDJQvCYsf2EUjWhrMBmspjXfK8ajq	9	11	11	1	\N	1729787164000	orphaned
16	3NKPVzefvqJkRe5oDma8w4NBpyyhT474GPRsb8WAiiVemJmuYw7V	15	3NKn5Kui5eWkT7CeGP4W4ZBy1A2jZaK2xBhb8BA6jwv6e184U1G5	151	150	g0zEhGQvF_6y4J4up1j5AFG_Hn7k_19V5hOyJUksXgo=	2	3	18	77	{5,6,1,7,7,7,7,7,7,7,7}	23166005000061388	jxZdTYUut1HbUE7WRxzhMLrRUZX2jVSxYMJHTPNczMKGJdqoMHq	12	15	15	1	\N	1729787884000	orphaned
25	3NKQBoGHte32tAMVshMnHLTfbU568HRBCK85Dd6HhZUxoSw3SEtP	23	3NLbqXtSz61S1AyqtvL5SGtz4v1rUGkBfQn1Y5gdaGE3SB4ZYrG7	86	196	S-lQnQjAtl1yhQnIaavHooa9w2nPvHWepl-Zpyu0_w0=	2	3	27	77	{5,6,6,7,7,7,7,7,7,7,7}	23166005000061388	jxouZRyFSSQtqgZRuhCY9n42iQkgYxMrPctXnqYFojPAraC2HYp	17	20	20	1	\N	1729788784000	orphaned
29	3NKi2mKRcnyLzrQ2xnTFgjU2ymVXLuyieZUcq79vbULaUAVFJNtN	27	3NLghxkgzdp9QSRnGw56Ft9RMMwdN7meCjGJSay2jGE1TvMaxRFx	86	196	mqrGjE39cyX9VqqX4G04pLc4XnwiFoiiDBWCKt184wU=	2	3	31	77	{5,6,6,3,7,7,7,7,7,7,7}	23166005000061388	jwYPLQYQw2LhXma2gNAEF2ndee4o1tCzz6DAAEcHo1QnBAef4Gk	20	23	23	1	\N	1729789324000	orphaned
24	3NKGPmsssmeZkZDZQ1Ki7wDL22Ai7EYkFFSqLVy97rLhQiX4aimE	23	3NLbqXtSz61S1AyqtvL5SGtz4v1rUGkBfQn1Y5gdaGE3SB4ZYrG7	151	150	jrvrx1YTepHlrhmuDmIg5Ip3-vrg9CnroET_xBvOpgw=	2	3	26	77	{5,6,6,7,7,7,7,7,7,7,7}	23166005000061388	jwAd7KRC1ApqggQyqW3mdYqBQinqeNnuCiPX3gaiXS4yqbsjEFq	17	20	20	1	\N	1729788784000	canonical
18	3NKfTafWoCELVVptmVRZ5J5vaVUjw1rSARzZ3rcMSRAyAkPdXZbr	17	3NKyDGMzfkC74cX5cR7dUtJRgxaktrcdKRt9Uxzoxw2gbG3uzQyv	151	150	RR7GiI55IEcHR73sGnpidXlx9-Vr7KCpmdr-wQDIXgM=	2	3	20	77	{5,6,2,7,7,7,7,7,7,7,7}	23166005000061388	jxHPAnKVCwRD3fPYbLQydacokB9MP9AvHLoVbDaem27sBkUpjMy	13	16	16	1	\N	1729788064000	canonical
8	3NKxw72uHWG2jW5qXLodKSwP7VWfdostR8qVoubZy3FWvs2MkxAV	7	3NKKCwnDZy6xuQsJpw213a9z58hL9uvmHaudyiyafYxn2t9zfWMQ	86	196	oIfIL8Yj5lEWBr_kXs_Xp3NEV6JjEjPfY120B7GY6Qs=	2	3	10	77	{5,1,7,7,7,7,7,7,7,7,7}	23166005000061388	jxTBnBFhd4orzJpYe5JGWo25VRcY786MZ6tz2PuBSMVoexTYJkF	6	7	7	1	\N	1729786444000	canonical
7	3NKKCwnDZy6xuQsJpw213a9z58hL9uvmHaudyiyafYxn2t9zfWMQ	6	3NLAS5vdrbTafumdQTiknXdJWedF4kEP4nhBjMHQ1AK8Xtef2cwH	86	196	tYxCQHfdpu7GMt5F1ZrebBN6p-Ch3zjvv3_WG5gkEAU=	2	3	9	77	{5,7,7,7,7,7,7,7,7,7,7}	23166005000061388	jwP2sA7YgCjidXzNN1zooKNAuv7HnxVRuaTxa3H2yPX1kgryLtp	5	6	6	1	\N	1729786264000	canonical
6	3NLAS5vdrbTafumdQTiknXdJWedF4kEP4nhBjMHQ1AK8Xtef2cwH	5	3NKbywTAm7unW7FKoejr49UWbwVoid2e463x5um7rGsaGGnjKLy2	86	196	s3N55weRvwjWZId_jl2CYHwr6N31dtEcgLP1JxVvpwU=	2	3	8	77	{4,7,7,7,7,7,7,7,7,7,7}	23166005000061388	jxf3r9km9za24KtbS2UcdH76yPgKPzdcBJJB12zdBAmiHB8iPiP	4	5	5	1	\N	1729786084000	canonical
5	3NKbywTAm7unW7FKoejr49UWbwVoid2e463x5um7rGsaGGnjKLy2	3	3NKTMbVv9wLELoSTtTwbj9cnWEhBJsiVstkUiNiwxDDD7qaZ7SgM	86	196	nvlG7oQOBOoj52UUQI_q0tHSNRxb754YCRNRqTR8kAU=	2	3	7	77	{3,7,7,7,7,7,7,7,7,7,7}	23166005000061388	jwQnjUvVuPwteyomNosZnxvoK4oRQCRTr9v7vHZ1GUiXPGf8rWn	3	3	3	1	\N	1729785724000	canonical
3	3NKTMbVv9wLELoSTtTwbj9cnWEhBJsiVstkUiNiwxDDD7qaZ7SgM	2	3NKvwckEXTdfEMBDSZAHj2Yxb3wDg4AZUtZZb2C9BUuxcrjpaaGh	151	150	iWDsJyju2TLn1S26CKM3rGCeJUj9jfe4ArULTUIAZAk=	2	3	5	77	{2,7,7,7,7,7,7,7,7,7,7}	23166005000061388	jxw6h5d9zJGHcRCCnLxM5QdM2Z73ZSTg6dosHaQ6jkbdu77kTyz	2	2	2	1	\N	1729785544000	canonical
2	3NKvwckEXTdfEMBDSZAHj2Yxb3wDg4AZUtZZb2C9BUuxcrjpaaGh	\N	3NKfwfjGeMLxyoMj1o6zFtyNMoGvT9jjRPKN2T6SqW1ratMsyokY	1	1	39cyg4ZmMtnb_aFUIerNAoAJV8qtkfOpq0zFzPspjgM=	2	3	4	77	{1,7,7,7,7,7,7,7,7,7,7}	23166005000061388	jwuANmDySJTPUdDZ3rgr5WM5jpPU3K9AgXXqkQxpDbX8f2WiyT2	1	0	0	1	\N	1729785184000	canonical
33	3NKuDnsHub3gqef1rGrrJ7K3h3dq6RXpHKUMZ5ke28fbg7dgbWba	31	3NLcWtkJyNbKxEUzWhTb3Qk8c9EBxrbtYLCReRfB1tKwjhTg7Zxr	151	150	LGCL1tR38U70Br2feFORJHySO3Snu6IBygMUp-p-eQU=	2	3	35	77	{5,6,6,5,1,7,7,7,7,7,7}	23166005000061388	jxBe6L4gGB8Ab2WvBr9XhMRZrqh2e5Xm7t7qo8XBBMq3Wn6GcsT	23	28	28	1	\N	1729790224000	orphaned
17	3NKyDGMzfkC74cX5cR7dUtJRgxaktrcdKRt9Uxzoxw2gbG3uzQyv	15	3NKn5Kui5eWkT7CeGP4W4ZBy1A2jZaK2xBhb8BA6jwv6e184U1G5	86	196	NF5C8nViABDIukm9y15xqEWfZ94lQYJGzxY1sCSDjAY=	2	3	19	77	{5,6,1,7,7,7,7,7,7,7,7}	23166005000061388	jwDnbiDhYhGQkgpJjpeR324m8QqdiXeQogQkcCHYSfn6FpnRDiC	12	15	15	1	\N	1729787884000	canonical
15	3NKn5Kui5eWkT7CeGP4W4ZBy1A2jZaK2xBhb8BA6jwv6e184U1G5	14	3NKaB2ijf1rwsKK2kmWw18iyakrvMeZRWRHtpRGLUwHTNdxLsPTJ	151	150	KMfbYEidcKweQRcuIspLr5niUhKxlgncuncQ5dEHLQk=	2	3	17	77	{5,6,7,7,7,7,7,7,7,7,7}	23166005000061388	jxtQzexFKfZWWrH64EHjoS2pegNhzPZWzQWqXZ91tUkXD3ARXfM	11	13	13	1	\N	1729787524000	canonical
14	3NKaB2ijf1rwsKK2kmWw18iyakrvMeZRWRHtpRGLUwHTNdxLsPTJ	12	3NLbms6A2idn9guSHA5Mf3m4yU1KFXYEmBgiqhW1WXZ87sFMLvC5	151	150	W305m4HPLne-LgGtEDtP0xERPce8NaDxUHHogRy0GA8=	2	3	16	77	{5,5,7,7,7,7,7,7,7,7,7}	23166005000061388	jwrtYN6mBzT5DiQv7YCx14YbpwroHXFpcfV3V7zeye7hi5gu5PE	10	12	12	1	\N	1729787344000	canonical
12	3NLbms6A2idn9guSHA5Mf3m4yU1KFXYEmBgiqhW1WXZ87sFMLvC5	11	3NKPf1BBu3sjhk392nx5Ymm4jj2GpKbiAuTrFfgMfdeVyfJARJ1P	86	196	ve-VKzLuZUpz7OZCmgfc_l7I-znoSOyZ8pO0gyrIFQU=	2	3	14	77	{5,4,7,7,7,7,7,7,7,7,7}	23166005000061388	jwwDzvzB9nrLg2d5bxJshVxE7CG5eCU4VAwYMeudnMYivxy6VJW	9	11	11	1	\N	1729787164000	canonical
11	3NKPf1BBu3sjhk392nx5Ymm4jj2GpKbiAuTrFfgMfdeVyfJARJ1P	10	3NKf7uuJYQQP2qTeNJRnfiCrc1xJmhc9TXQGakf8rCVj7mZ92rK5	86	196	CV56gsmcN3cGxLNQcyFN-OFVmAym4VLduvrTL-K0lg8=	2	3	13	77	{5,3,7,7,7,7,7,7,7,7,7}	23166005000061388	jxP8HNxCZ4KPqgCnPfTw8qSCwsBUjkKiG4cRdTa25VqrPd4WdGX	8	10	10	1	\N	1729786984000	canonical
10	3NKf7uuJYQQP2qTeNJRnfiCrc1xJmhc9TXQGakf8rCVj7mZ92rK5	8	3NKxw72uHWG2jW5qXLodKSwP7VWfdostR8qVoubZy3FWvs2MkxAV	86	196	RP7JYE7bosysM4Ce41EYzV6RhwagsLKWgcqIzuwErwg=	2	3	12	77	{5,2,7,7,7,7,7,7,7,7,7}	23166005000061388	jwKArgR39Q7JG947kNznQYTQC6ypFDv2qXMcsHNg5H9x9E1wJFP	7	8	8	1	\N	1729786624000	canonical
\.


--
-- Data for Name: blocks_internal_commands; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.blocks_internal_commands (block_id, internal_command_id, sequence_no, secondary_sequence_no, status, failure_reason) FROM stdin;
3	1	3	0	applied	\N
3	2	4	0	applied	\N
4	3	3	0	applied	\N
4	4	4	0	applied	\N
5	3	9	0	applied	\N
5	5	10	0	applied	\N
6	3	25	0	applied	\N
6	6	26	0	applied	\N
7	3	12	0	applied	\N
7	7	13	0	applied	\N
8	3	12	0	applied	\N
8	7	13	0	applied	\N
9	1	12	0	applied	\N
9	8	13	0	applied	\N
10	3	12	0	applied	\N
10	7	13	0	applied	\N
11	3	25	0	applied	\N
11	6	26	0	applied	\N
12	3	12	0	applied	\N
12	7	13	0	applied	\N
13	1	12	0	applied	\N
13	8	13	0	applied	\N
14	9	1	0	applied	\N
14	1	13	0	applied	\N
14	10	14	0	applied	\N
15	1	12	0	applied	\N
15	8	13	0	applied	\N
16	1	25	0	applied	\N
16	11	26	0	applied	\N
17	3	25	0	applied	\N
17	6	26	0	applied	\N
18	1	12	0	applied	\N
18	8	13	0	applied	\N
19	1	12	0	applied	\N
19	8	13	0	applied	\N
20	3	12	0	applied	\N
20	7	13	0	applied	\N
21	1	12	0	applied	\N
21	8	13	0	applied	\N
22	3	12	0	applied	\N
22	7	13	0	applied	\N
23	1	12	0	applied	\N
23	8	13	0	applied	\N
24	1	13	0	applied	\N
24	12	14	0	applied	\N
25	3	13	0	applied	\N
25	13	14	0	applied	\N
26	14	2	0	applied	\N
26	1	13	0	applied	\N
26	15	14	0	applied	\N
27	1	12	0	applied	\N
27	8	13	0	applied	\N
28	1	12	0	applied	\N
28	8	13	0	applied	\N
29	3	12	0	applied	\N
29	7	13	0	applied	\N
30	1	37	0	applied	\N
30	16	38	0	applied	\N
31	3	12	0	applied	\N
31	7	13	0	applied	\N
32	3	12	0	applied	\N
32	7	13	0	applied	\N
33	1	12	0	applied	\N
33	8	13	0	applied	\N
34	1	12	0	applied	\N
34	8	13	0	applied	\N
35	3	12	0	applied	\N
35	7	13	0	applied	\N
36	17	6	0	applied	\N
36	18	26	0	applied	\N
36	19	26	0	applied	\N
36	20	27	0	applied	\N
36	21	27	1	applied	\N
37	1	12	0	applied	\N
37	8	13	0	applied	\N
38	3	12	0	applied	\N
38	7	13	0	applied	\N
39	3	11	0	applied	\N
39	22	12	0	applied	\N
40	1	11	0	applied	\N
40	10	12	0	applied	\N
41	1	12	0	applied	\N
41	8	13	0	applied	\N
42	1	12	0	applied	\N
42	8	13	0	applied	\N
43	3	12	0	applied	\N
43	7	13	0	applied	\N
44	1	12	0	applied	\N
44	8	13	0	applied	\N
45	3	12	0	applied	\N
45	7	13	0	applied	\N
46	1	12	0	applied	\N
46	8	13	0	applied	\N
\.


--
-- Data for Name: blocks_user_commands; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.blocks_user_commands (block_id, user_command_id, sequence_no, status, failure_reason) FROM stdin;
3	1	0	applied	\N
3	2	1	applied	\N
3	3	2	applied	\N
4	1	0	applied	\N
4	2	1	applied	\N
4	3	2	applied	\N
5	4	0	applied	\N
5	5	1	applied	\N
5	6	2	applied	\N
5	7	3	applied	\N
5	8	4	applied	\N
5	9	5	applied	\N
5	10	6	applied	\N
5	11	7	applied	\N
5	12	8	applied	\N
6	13	0	applied	\N
6	14	1	applied	\N
6	15	2	applied	\N
6	16	3	applied	\N
6	17	4	applied	\N
6	18	5	applied	\N
6	19	6	applied	\N
6	20	7	applied	\N
6	21	8	applied	\N
6	22	9	applied	\N
6	23	10	applied	\N
6	24	11	applied	\N
6	25	12	applied	\N
6	26	13	applied	\N
6	27	14	applied	\N
6	28	15	applied	\N
6	29	16	applied	\N
6	30	17	applied	\N
6	31	18	applied	\N
6	32	19	applied	\N
6	33	20	applied	\N
6	34	21	applied	\N
6	35	22	applied	\N
6	36	23	applied	\N
6	37	24	applied	\N
7	38	0	applied	\N
7	39	1	applied	\N
7	40	2	applied	\N
7	41	3	applied	\N
7	42	4	applied	\N
7	43	5	applied	\N
7	44	6	applied	\N
7	45	7	applied	\N
7	46	8	applied	\N
7	47	9	applied	\N
7	48	10	applied	\N
7	49	11	applied	\N
8	50	0	applied	\N
8	51	1	applied	\N
8	52	2	applied	\N
8	53	3	applied	\N
8	54	4	applied	\N
8	55	5	applied	\N
8	56	6	applied	\N
8	57	7	applied	\N
8	58	8	applied	\N
8	59	9	applied	\N
8	60	10	applied	\N
8	61	11	applied	\N
9	62	0	applied	\N
9	63	1	applied	\N
9	64	2	applied	\N
9	65	3	applied	\N
9	66	4	applied	\N
9	67	5	applied	\N
9	68	6	applied	\N
9	69	7	applied	\N
9	70	8	applied	\N
9	71	9	applied	\N
9	72	10	applied	\N
9	73	11	applied	\N
10	62	0	applied	\N
10	63	1	applied	\N
10	64	2	applied	\N
10	65	3	applied	\N
10	66	4	applied	\N
10	67	5	applied	\N
10	68	6	applied	\N
10	69	7	applied	\N
10	70	8	applied	\N
10	71	9	applied	\N
10	72	10	applied	\N
10	73	11	applied	\N
11	74	0	applied	\N
11	75	1	applied	\N
11	76	2	applied	\N
11	77	3	applied	\N
11	78	4	applied	\N
11	79	5	applied	\N
11	80	6	applied	\N
11	81	7	applied	\N
11	82	8	applied	\N
11	83	9	applied	\N
11	84	10	applied	\N
11	85	11	applied	\N
11	86	12	applied	\N
11	87	13	applied	\N
11	88	14	applied	\N
11	89	15	applied	\N
11	90	16	applied	\N
11	91	17	applied	\N
11	92	18	applied	\N
11	93	19	applied	\N
11	94	20	applied	\N
11	95	21	applied	\N
11	96	22	applied	\N
11	97	23	applied	\N
11	98	24	applied	\N
12	99	0	applied	\N
12	100	1	applied	\N
12	101	2	applied	\N
12	102	3	applied	\N
12	103	4	applied	\N
12	104	5	applied	\N
12	105	6	applied	\N
12	106	7	applied	\N
12	107	8	applied	\N
12	108	9	applied	\N
12	109	10	applied	\N
12	110	11	applied	\N
13	99	0	applied	\N
13	100	1	applied	\N
13	101	2	applied	\N
13	102	3	applied	\N
13	103	4	applied	\N
13	104	5	applied	\N
13	105	6	applied	\N
13	106	7	applied	\N
13	107	8	applied	\N
13	108	9	applied	\N
13	109	10	applied	\N
13	110	11	applied	\N
14	111	0	applied	\N
14	112	2	applied	\N
14	113	3	applied	\N
14	114	4	applied	\N
14	115	5	applied	\N
14	116	6	applied	\N
14	117	7	applied	\N
14	118	8	applied	\N
14	119	9	applied	\N
14	120	10	applied	\N
14	121	11	applied	\N
14	122	12	applied	\N
15	123	0	applied	\N
15	124	1	applied	\N
15	125	2	applied	\N
15	126	3	applied	\N
15	127	4	applied	\N
15	128	5	applied	\N
15	129	6	applied	\N
15	130	7	applied	\N
15	131	8	applied	\N
15	132	9	applied	\N
15	133	10	applied	\N
15	134	11	applied	\N
16	135	0	applied	\N
16	136	1	applied	\N
16	137	2	applied	\N
16	138	3	applied	\N
16	139	4	applied	\N
16	140	5	applied	\N
16	141	6	applied	\N
16	142	7	applied	\N
16	143	8	applied	\N
16	144	9	applied	\N
16	145	10	applied	\N
16	146	11	applied	\N
16	147	12	applied	\N
16	148	13	applied	\N
16	149	14	applied	\N
16	150	15	applied	\N
16	151	16	applied	\N
16	152	17	applied	\N
16	153	18	applied	\N
16	154	19	applied	\N
16	155	20	applied	\N
16	156	21	applied	\N
16	157	22	applied	\N
16	158	23	applied	\N
16	159	24	applied	\N
17	135	0	applied	\N
17	136	1	applied	\N
17	137	2	applied	\N
17	138	3	applied	\N
17	139	4	applied	\N
17	140	5	applied	\N
17	141	6	applied	\N
17	142	7	applied	\N
17	143	8	applied	\N
17	144	9	applied	\N
17	145	10	applied	\N
17	146	11	applied	\N
17	147	12	applied	\N
17	148	13	applied	\N
17	149	14	applied	\N
17	150	15	applied	\N
17	151	16	applied	\N
17	152	17	applied	\N
17	153	18	applied	\N
17	154	19	applied	\N
17	155	20	applied	\N
17	156	21	applied	\N
17	157	22	applied	\N
17	158	23	applied	\N
17	159	24	applied	\N
18	160	0	applied	\N
18	161	1	applied	\N
18	162	2	applied	\N
18	163	3	applied	\N
18	164	4	applied	\N
18	165	5	applied	\N
18	166	6	applied	\N
18	167	7	applied	\N
18	168	8	applied	\N
18	169	9	applied	\N
18	170	10	applied	\N
18	171	11	applied	\N
19	172	0	applied	\N
19	173	1	applied	\N
19	174	2	applied	\N
19	175	3	applied	\N
19	176	4	applied	\N
19	177	5	applied	\N
19	178	6	applied	\N
19	179	7	applied	\N
19	180	8	applied	\N
19	181	9	applied	\N
19	182	10	applied	\N
19	183	11	applied	\N
20	184	0	applied	\N
20	185	1	applied	\N
20	186	2	applied	\N
20	187	3	applied	\N
20	188	4	applied	\N
20	189	5	applied	\N
20	190	6	applied	\N
20	191	7	applied	\N
20	192	8	applied	\N
20	193	9	applied	\N
20	194	10	applied	\N
20	195	11	applied	\N
21	184	0	applied	\N
21	185	1	applied	\N
21	186	2	applied	\N
21	187	3	applied	\N
21	188	4	applied	\N
21	189	5	applied	\N
21	190	6	applied	\N
21	191	7	applied	\N
21	192	8	applied	\N
21	193	9	applied	\N
21	194	10	applied	\N
21	195	11	applied	\N
22	196	0	applied	\N
22	197	1	applied	\N
22	198	2	applied	\N
22	199	3	applied	\N
22	200	4	applied	\N
22	201	5	applied	\N
22	202	6	applied	\N
22	203	7	applied	\N
22	204	8	applied	\N
22	205	9	applied	\N
22	206	10	applied	\N
22	207	11	applied	\N
23	196	0	applied	\N
23	197	1	applied	\N
23	198	2	applied	\N
23	199	3	applied	\N
23	200	4	applied	\N
23	201	5	applied	\N
23	202	6	applied	\N
23	203	7	applied	\N
23	204	8	applied	\N
23	205	9	applied	\N
23	206	10	applied	\N
23	207	11	applied	\N
24	208	0	applied	\N
24	209	1	applied	\N
24	210	2	applied	\N
24	211	3	applied	\N
24	212	4	applied	\N
24	213	5	applied	\N
24	214	6	applied	\N
24	215	7	applied	\N
24	216	8	applied	\N
24	217	9	applied	\N
24	218	10	applied	\N
24	219	11	applied	\N
24	220	12	applied	\N
25	208	0	applied	\N
25	209	1	applied	\N
25	210	2	applied	\N
25	211	3	applied	\N
25	212	4	applied	\N
25	213	5	applied	\N
25	214	6	applied	\N
25	215	7	applied	\N
25	216	8	applied	\N
25	217	9	applied	\N
25	218	10	applied	\N
25	219	11	applied	\N
25	220	12	applied	\N
26	221	0	applied	\N
26	222	1	applied	\N
26	223	3	applied	\N
26	224	4	applied	\N
26	225	5	applied	\N
26	226	6	applied	\N
26	227	7	applied	\N
26	228	8	applied	\N
26	229	9	applied	\N
26	230	10	applied	\N
26	231	11	applied	\N
26	232	12	applied	\N
27	233	0	applied	\N
27	234	1	applied	\N
27	235	2	applied	\N
27	236	3	applied	\N
27	237	4	applied	\N
27	238	5	applied	\N
27	239	6	applied	\N
27	240	7	applied	\N
27	241	8	applied	\N
27	242	9	applied	\N
27	243	10	applied	\N
27	244	11	applied	\N
28	245	0	applied	\N
28	246	1	applied	\N
28	247	2	applied	\N
28	248	3	applied	\N
28	249	4	applied	\N
28	250	5	applied	\N
28	251	6	applied	\N
28	252	7	applied	\N
28	253	8	applied	\N
28	254	9	applied	\N
28	255	10	applied	\N
28	256	11	applied	\N
29	245	0	applied	\N
29	246	1	applied	\N
29	247	2	applied	\N
29	248	3	applied	\N
29	249	4	applied	\N
29	250	5	applied	\N
29	251	6	applied	\N
29	252	7	applied	\N
29	253	8	applied	\N
29	254	9	applied	\N
29	255	10	applied	\N
29	256	11	applied	\N
30	257	0	applied	\N
30	258	1	applied	\N
30	259	2	applied	\N
30	260	3	applied	\N
30	261	4	applied	\N
30	262	5	applied	\N
30	263	6	applied	\N
30	264	7	applied	\N
30	265	8	applied	\N
30	266	9	applied	\N
30	267	10	applied	\N
30	268	11	applied	\N
30	269	12	applied	\N
30	270	13	applied	\N
30	271	14	applied	\N
30	272	15	applied	\N
30	273	16	applied	\N
30	274	17	applied	\N
30	275	18	applied	\N
30	276	19	applied	\N
30	277	20	applied	\N
30	278	21	applied	\N
30	279	22	applied	\N
30	280	23	applied	\N
30	281	24	applied	\N
30	282	25	applied	\N
30	283	26	applied	\N
30	284	27	applied	\N
30	285	28	applied	\N
30	286	29	applied	\N
30	287	30	applied	\N
30	288	31	applied	\N
30	289	32	applied	\N
30	290	33	applied	\N
30	291	34	applied	\N
30	292	35	applied	\N
30	293	36	applied	\N
31	294	0	applied	\N
31	295	1	applied	\N
31	296	2	applied	\N
31	297	3	applied	\N
31	298	4	applied	\N
31	299	5	applied	\N
31	300	6	applied	\N
31	301	7	applied	\N
31	302	8	applied	\N
31	303	9	applied	\N
31	304	10	applied	\N
31	305	11	applied	\N
32	306	0	applied	\N
32	307	1	applied	\N
32	308	2	applied	\N
32	309	3	applied	\N
32	310	4	applied	\N
32	311	5	applied	\N
32	312	6	applied	\N
32	313	7	applied	\N
32	314	8	applied	\N
32	315	9	applied	\N
32	316	10	applied	\N
32	317	11	applied	\N
33	306	0	applied	\N
33	307	1	applied	\N
33	308	2	applied	\N
33	309	3	applied	\N
33	310	4	applied	\N
33	311	5	applied	\N
33	312	6	applied	\N
33	313	7	applied	\N
33	314	8	applied	\N
33	315	9	applied	\N
33	316	10	applied	\N
33	317	11	applied	\N
34	318	0	applied	\N
34	319	1	applied	\N
34	320	2	applied	\N
34	321	3	applied	\N
34	322	4	applied	\N
34	323	5	applied	\N
34	324	6	applied	\N
34	325	7	applied	\N
34	326	8	applied	\N
34	327	9	applied	\N
34	328	10	applied	\N
34	329	11	applied	\N
35	318	0	applied	\N
35	319	1	applied	\N
35	320	2	applied	\N
35	321	3	applied	\N
35	322	4	applied	\N
35	323	5	applied	\N
35	324	6	applied	\N
35	325	7	applied	\N
35	326	8	applied	\N
35	327	9	applied	\N
35	328	10	applied	\N
35	329	11	applied	\N
36	330	0	applied	\N
36	331	1	applied	\N
36	332	2	applied	\N
36	333	3	applied	\N
36	334	4	applied	\N
36	335	5	applied	\N
36	336	7	applied	\N
36	337	8	applied	\N
36	338	9	applied	\N
36	339	10	applied	\N
36	340	11	applied	\N
36	341	12	applied	\N
36	342	13	applied	\N
36	343	14	applied	\N
36	344	15	applied	\N
36	345	16	applied	\N
36	346	17	applied	\N
36	347	18	applied	\N
36	348	19	applied	\N
36	349	20	applied	\N
36	350	21	applied	\N
36	351	22	applied	\N
36	352	23	applied	\N
36	353	24	applied	\N
36	354	25	applied	\N
37	355	0	applied	\N
37	356	1	applied	\N
37	357	2	applied	\N
37	358	3	applied	\N
37	359	4	applied	\N
37	360	5	applied	\N
37	361	6	applied	\N
37	362	7	applied	\N
37	363	8	applied	\N
37	364	9	applied	\N
37	365	10	applied	\N
37	366	11	applied	\N
38	355	0	applied	\N
38	356	1	applied	\N
38	357	2	applied	\N
38	358	3	applied	\N
38	359	4	applied	\N
38	360	5	applied	\N
38	361	6	applied	\N
38	362	7	applied	\N
38	363	8	applied	\N
38	364	9	applied	\N
38	365	10	applied	\N
38	366	11	applied	\N
39	367	0	applied	\N
39	368	1	applied	\N
39	369	2	applied	\N
39	370	3	applied	\N
39	371	4	applied	\N
39	372	5	applied	\N
39	373	6	applied	\N
39	374	7	applied	\N
39	375	8	applied	\N
39	376	9	applied	\N
39	377	10	applied	\N
40	367	0	applied	\N
40	368	1	applied	\N
40	369	2	applied	\N
40	370	3	applied	\N
40	371	4	applied	\N
40	372	5	applied	\N
40	373	6	applied	\N
40	374	7	applied	\N
40	375	8	applied	\N
40	376	9	applied	\N
40	377	10	applied	\N
41	378	0	applied	\N
41	379	1	applied	\N
41	380	2	applied	\N
41	381	3	applied	\N
41	382	4	applied	\N
41	383	5	applied	\N
41	384	6	applied	\N
41	385	7	applied	\N
41	386	8	applied	\N
41	387	9	applied	\N
41	388	10	applied	\N
41	389	11	applied	\N
42	390	0	applied	\N
42	391	1	applied	\N
42	392	2	applied	\N
42	393	3	applied	\N
42	394	4	applied	\N
42	395	5	applied	\N
42	396	6	applied	\N
42	397	7	applied	\N
42	398	8	applied	\N
42	399	9	applied	\N
42	400	10	applied	\N
42	401	11	applied	\N
43	402	0	applied	\N
43	403	1	applied	\N
43	404	2	applied	\N
43	405	3	applied	\N
43	406	4	applied	\N
43	407	5	applied	\N
43	408	6	applied	\N
43	409	7	applied	\N
43	410	8	applied	\N
43	411	9	applied	\N
43	412	10	applied	\N
43	413	11	applied	\N
45	414	0	applied	\N
45	415	1	applied	\N
45	416	2	applied	\N
45	417	3	applied	\N
45	418	4	applied	\N
45	419	5	applied	\N
45	420	6	applied	\N
45	421	7	applied	\N
45	422	8	applied	\N
45	423	9	applied	\N
45	424	10	applied	\N
45	425	11	applied	\N
44	402	0	applied	\N
44	403	1	applied	\N
44	404	2	applied	\N
44	405	3	applied	\N
44	406	4	applied	\N
44	407	5	applied	\N
44	408	6	applied	\N
44	409	7	applied	\N
44	410	8	applied	\N
44	411	9	applied	\N
44	412	10	applied	\N
44	413	11	applied	\N
46	414	0	applied	\N
46	415	1	applied	\N
46	416	2	applied	\N
46	417	3	applied	\N
46	418	4	applied	\N
46	419	5	applied	\N
46	420	6	applied	\N
46	421	7	applied	\N
46	422	8	applied	\N
46	423	9	applied	\N
46	424	10	applied	\N
46	425	11	applied	\N
\.


--
-- Data for Name: blocks_zkapp_commands; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.blocks_zkapp_commands (block_id, zkapp_command_id, sequence_no, status, failure_reasons_ids) FROM stdin;
\.


--
-- Data for Name: epoch_data; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.epoch_data (id, seed, ledger_hash_id, total_currency, start_checkpoint, lock_checkpoint, epoch_length) FROM stdin;
1	2va9BGv9JrLTtrzZttiEMDYw1Zj6a6EHzXjmP9evHDTG3oEquURA	1	23166005000060590	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	1
2	2vafPBQ3zQdHUEDDnFGuiNvJz7s2MhTLJgSzQSnu5fnZavT27cms	1	23166005000060590	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKujQPSoCSYPRovP43k4HcRaruMoAPv91dPigFgRczcAJGGsx5K	2
3	2va9BGv9JrLTtrzZttiEMDYw1Zj6a6EHzXjmP9evHDTG3oEquURA	2	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	1
4	2vafPBQ3zQdHUEDDnFGuiNvJz7s2MhTLJgSzQSnu5fnZavT27cms	2	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKfwfjGeMLxyoMj1o6zFtyNMoGvT9jjRPKN2T6SqW1ratMsyokY	2
5	2vbUjr4Q98ZjiyeoA1E1daLty5mpvNRGJ7s7c5e7NpDJo4U4Ktuw	2	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKvwckEXTdfEMBDSZAHj2Yxb3wDg4AZUtZZb2C9BUuxcrjpaaGh	3
6	2vayzub5ykosVLHmxskefHKTXEgFdMZFv6fbDDcan2eppXTUmMio	2	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKvwckEXTdfEMBDSZAHj2Yxb3wDg4AZUtZZb2C9BUuxcrjpaaGh	3
7	2vabfNspYrbQHx38j1UgZJkUmPXzznnwZ4JpD8wBKjsDn5CF1dR5	2	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKTMbVv9wLELoSTtTwbj9cnWEhBJsiVstkUiNiwxDDD7qaZ7SgM	4
8	2vaPez6kpnZRogB2ydGXNahKYU3rLzDL9UzvNWSpPY9oLYGTfXQD	2	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKbywTAm7unW7FKoejr49UWbwVoid2e463x5um7rGsaGGnjKLy2	5
9	2vc4yVdRDiJzUu3GN3uKetg1kBcp7rtBRt5jQXG2y6oUtRdx7hxn	2	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLAS5vdrbTafumdQTiknXdJWedF4kEP4nhBjMHQ1AK8Xtef2cwH	6
10	2vbXjkHQNPXoZUvhLiCnWKuUroSig4sMnYbXw7BsaSxeLUgVdTPt	2	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKKCwnDZy6xuQsJpw213a9z58hL9uvmHaudyiyafYxn2t9zfWMQ	7
11	2vbTSy4rrhK9CkiHPtj8C8RstcAxq3cvz19gy8nm1KXqc42ms55g	2	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKxw72uHWG2jW5qXLodKSwP7VWfdostR8qVoubZy3FWvs2MkxAV	8
12	2vaix7ESeUHh4LzNpk64CRhCu53tKpygAtjoMfM1APn52iyqEcAN	2	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKxw72uHWG2jW5qXLodKSwP7VWfdostR8qVoubZy3FWvs2MkxAV	8
13	2vbqH15Wrd1czfC2UFMx5EQx9K4X7tht8yrPmdivuBTNr6USJjv1	2	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKf7uuJYQQP2qTeNJRnfiCrc1xJmhc9TXQGakf8rCVj7mZ92rK5	9
14	2vaQtsFHADrnEohbAumBsBugx6LiKRA2nZPDY5uFegR1NCvLgw4K	2	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKPf1BBu3sjhk392nx5Ymm4jj2GpKbiAuTrFfgMfdeVyfJARJ1P	10
15	2vbXAkRPFXUyiKdEX6jrVyxqP3PBqGBMiAH95DcF9zZD9VjZ73Hr	2	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKPf1BBu3sjhk392nx5Ymm4jj2GpKbiAuTrFfgMfdeVyfJARJ1P	10
16	2vbzRUjAzaARHwPEUeUHMcFHpqe5LTyY4ZuF5NtYQxvdL3uYdrq1	2	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLbms6A2idn9guSHA5Mf3m4yU1KFXYEmBgiqhW1WXZ87sFMLvC5	11
17	2vaESkuZTLNEdZsfBQ96a46W4aZ4JLGBivcNMy4B28adMa8snvvN	2	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKaB2ijf1rwsKK2kmWw18iyakrvMeZRWRHtpRGLUwHTNdxLsPTJ	12
18	2vbFXFgnmbmMFua1aACoHKw47uAjdABeGRD9sfMUmH9whBDEQwxW	2	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKn5Kui5eWkT7CeGP4W4ZBy1A2jZaK2xBhb8BA6jwv6e184U1G5	13
19	2vbqd8XFrpxZSWizeBNb1Qv8whNwLaJpy7zaG7xvBQBbkqGe6AGu	2	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKn5Kui5eWkT7CeGP4W4ZBy1A2jZaK2xBhb8BA6jwv6e184U1G5	13
20	2vaAwfR1ekVriszcHhTbANdPvPiGJxn3JdtD7f5oKVNwupXjs38a	2	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKyDGMzfkC74cX5cR7dUtJRgxaktrcdKRt9Uxzoxw2gbG3uzQyv	14
21	2vaUtL52254ehJzUh8mFAz279UMfxSAefVRt2WVdtCZ111JpQ6rT	2	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKfTafWoCELVVptmVRZ5J5vaVUjw1rSARzZ3rcMSRAyAkPdXZbr	15
22	2vb2jYMYKjrRCqb1J3w4bj7jVyVJKPFFZC1iirjGwhxKQM9SJpyH	2	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKueCojy6o3uJjj8Dg6RTgdNLMij1DG8Yeb1cgk66hnhxuu99hp	16
23	2vbbJmEPMq2awyLzfwScRvfPoC7gysjERojehQXXE9iBcMQhvFC2	2	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKueCojy6o3uJjj8Dg6RTgdNLMij1DG8Yeb1cgk66hnhxuu99hp	16
24	2varuDpphELUC9nmcFfQEEbRzZ12LimXwGMLyd653ttcWkGY81Tv	2	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKasKxGydjWnh1XpoVyu4V345FaaVWQUHuHLRPdQvUEqkrs7DFy	17
25	2vawbgGDuB9AubRSJ5DxpggqyCy5UrwYPW4suYSNibHaPpu9eNb8	2	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKasKxGydjWnh1XpoVyu4V345FaaVWQUHuHLRPdQvUEqkrs7DFy	17
26	2vaAjfzBYQffhsuusXQSaV1YA5FvKWFYTvEjh3nHJ51vyMTRGc2L	2	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLbqXtSz61S1AyqtvL5SGtz4v1rUGkBfQn1Y5gdaGE3SB4ZYrG7	18
27	2vbArhix16PeRypegsXK7FBqtnkRMBCAzdnhjmq9EtpgbGeicifG	2	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLbqXtSz61S1AyqtvL5SGtz4v1rUGkBfQn1Y5gdaGE3SB4ZYrG7	18
28	2vbcM55gi9rNMbxaq9zioC9xqB2ykbr2xrbRH9eejZfJcCiLpoS2	2	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKGPmsssmeZkZDZQ1Ki7wDL22Ai7EYkFFSqLVy97rLhQiX4aimE	19
29	2vaMtYbaGwkiBX6bmt8T36SEFrmQctXRz1YXjhEYjJWwdVS2JaFa	2	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKp69gQwaNR8nYuhryoUSEmwouBTrCPGJh6od8jCwA1UZxTguDr	20
30	2vb1CjqPN9rq5rTkB1yMC5oYWJP1nGgZvLoUE95SUwJ1xLsX5dEH	2	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLghxkgzdp9QSRnGw56Ft9RMMwdN7meCjGJSay2jGE1TvMaxRFx	21
31	2va9psoZZnNA9PPptvecUtmA9bJgXQNW7GG1a7xB3o7rjukzqtot	2	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLghxkgzdp9QSRnGw56Ft9RMMwdN7meCjGJSay2jGE1TvMaxRFx	21
32	2vbxGLxnhwCTwQqWngm4TrEDh296iuFUkMCKiDbnn5MPKUry9cr3	2	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLP7mTNJNMDkUvtFx5kMJPBmpWyT3uzKLqz3KmftAD9gD8CZ8YP	22
33	2vazwCFHgv5g9NfL3CTjCAAAjAu4eRuc1gpZrsqaZXSiPsw3Wa91	2	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLdTDBe3oWrQVa65zExg9cu97Q5tfHcCFbqxGwVGfsNxMSvi1Tg	23
34	2vaU67ntYTkkYUGygE6eqU3Phzsvy4wLeUfZA8SgUtvKU9mjRJEC	2	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLcWtkJyNbKxEUzWhTb3Qk8c9EBxrbtYLCReRfB1tKwjhTg7Zxr	24
35	2vaeftikmNLGgASZQMkKgnGcqoZy6pvpCpxpGMmqDSf1n7ib5Waw	2	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLcWtkJyNbKxEUzWhTb3Qk8c9EBxrbtYLCReRfB1tKwjhTg7Zxr	24
36	2vaNZTCkwFWc5hLFCdUZoXu19PXFtoPX8Mfo7PfTMYS66DXGN3Cr	2	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKmB8jerJwVZPKbjYnJp854XsZqXpbDnSAs9SLfBSXWs1TKJh8q	25
38	2vbnywrkubNSm1ZaAnKAqRiGMa4fQyzYcK2EgxY6CQogx7dqxBed	2	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKuHu37zQkaFALuzS3FrYAJq8ny26LtkpXaLRiwQy2sZsDA2faZ	26
40	2vb5jJKzEam81LGs44EA1qrpN4pKC7RcMjcyvjjd9vzzuBCxm5TY	2	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLTte5mWw2qfrwzqseQk52xj3axGyyTJNtiXdd5zp3Bs471Mydp	27
42	2vbMQHt4JXZC4MRGMsEEjixAUAppKdRWAif18ZZXS6GdYndN3nHW	2	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLg1kVvQMCTAx6468s6dzJgbFZpwy9nMTUZR5ThS8avrSmPA74f	28
44	2vbNaXHSZHkVgHBfimoCp3s7sxNjMmxfmCrcrFvhVD5jDQuvN277	2	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLEvcXKLyi45F66JJGcM2r9nnMT2Khy6o2oFXy4DZUCBCXJTtVA	30
46	2vbxBc5DrhJPmgsCJyDTdU5U7TAJcFBbMjCQzq4iJdV89sdyTsja	2	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLTzNs8e6z6n1NRbQG3W3Vma433DR89GNPhohW1FwkEGxhLmpiG	31
48	2vbY7gWs8DJRrijvMG3rdeV9YUJVYAVvkobea3mrLSjWWa4Q4wNs	2	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLWa8E1pZytLBcexCUw2ot3STCbgAQR9RRNCZ1rfohyrhS8bKTC	32
37	2vbmvdfJx9qvYoqwH7F8kwtqwVtnwtS5pT8xaAre16vzNeDoULwA	2	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKmB8jerJwVZPKbjYnJp854XsZqXpbDnSAs9SLfBSXWs1TKJh8q	25
39	2vaNAcVVajqSXENGeJfVnX7JLPdzj8DSBJnN1RPQdTJzU4dfAqcU	2	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLTte5mWw2qfrwzqseQk52xj3axGyyTJNtiXdd5zp3Bs471Mydp	27
41	2vb6BnttDQeCQV1Gc7bDAeRkVbbZimdZnqoFBU9MzxU1zuFVLqr5	2	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLg1kVvQMCTAx6468s6dzJgbFZpwy9nMTUZR5ThS8avrSmPA74f	28
43	2vbCiApk4CynnwyPFiZjthRYYVxtM3uU77eub2cpuHPP33irtnWe	2	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKLpVPw1nN183YfHpvvkz9QVDTJCoCdxmod2dunc2GYAHtXbTZZ	29
45	2vaCSABkZ4u6EVhmwEFiEqp5eKfRafptRXSMdfibsVap7X9CQW6i	2	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLTzNs8e6z6n1NRbQG3W3Vma433DR89GNPhohW1FwkEGxhLmpiG	31
47	2vahv1zuaNCRvG8GnZxvvgJx1bkq4gegzueZ4YsC4Dw2NRbSZ3MP	2	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLWa8E1pZytLBcexCUw2ot3STCbgAQR9RRNCZ1rfohyrhS8bKTC	32
\.


--
-- Data for Name: internal_commands; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.internal_commands (id, command_type, receiver_id, fee, hash) FROM stdin;
1	coinbase	151	20000000000	5JvB1DSEt7MjpA38dwy8RptVLjgZKgtiiW62hLkmD9bCvYRaq2DW
2	fee_transfer	151	750000000	5JuezS1HB6oawC2vEMpqrg2EQehgxruiLbx8EJSGHAJnfmtEDso9
3	coinbase	86	20000000000	5Jue63uB1Ey6UAqVowaT9ZCbKtgeX84dDB1rh6jS3bjJMvhtnxzk
4	fee_transfer	86	750000000	5JuaWqSNVh2LAhwdBFLKN8GH5uUUvH52G5skbc2KmENHn4MVDjs5
5	fee_transfer	86	2250000000	5Ju4CihbhRLQtcSjpKmPnuVm4GXoRL5cR9M7gyp7twnyGq8i4p6z
6	fee_transfer	86	6250000000	5JtdTP1HASeo23DiYTDZ5rikkPoSqvRrt9NHEU4QrvTqo1uwnjhb
7	fee_transfer	86	3000000000	5Juo7ZUd4oeqF9DwzrdiN2BvXH3MU7no8nyc3pdmfyz1Q9HhZ7wu
8	fee_transfer	151	3000000000	5JukPb5Vd9Hu3SERLn5JcK7LN7Sv2gYujiuCP6v6GHtfq7QE4W9L
9	fee_transfer	151	250000000	5JvGWbUa3MwUsJhiwkSp4FrT889CK2nCvc9CHMXkH2B667KHguGR
10	fee_transfer	151	2750000000	5Jtcx8P374nRbZFHGEYWtKJ4d1HgXNhai6aELaqDdtNT9eLSs7WZ
11	fee_transfer	151	6250000000	5JuAdkKx5QAam7yDZuSWT5GDkrJDoajhwAhqhDAgkDW3vDAiE1LA
12	fee_transfer	151	3250000000	5Juy4qqNdcYCfMz6CwEf6RbfWmM7dikaRAqMMQFSXmVSNtGrGNNs
13	fee_transfer	86	3250000000	5Jv9bNm6MfsNT4gPTTr9LFzPwoNjo6aQem7JhZqDdDz6RMsJmHj5
14	fee_transfer	151	500000000	5JtnuvugSFBm6yknSb1DpbuiskB88Y9B6Z8TRe3z7ZBhdruYHTy5
15	fee_transfer	151	2500000000	5JuAYRTeeXZkbFNBQoQ7wCuPg9upymnYyYL8quJdVfvGrr4jnb1Q
16	fee_transfer	151	9250000000	5JuFWWsNa7nus6vyfuiJuxqqNHvhPL8ykrcan7RCTnEcvEEuXTGx
17	fee_transfer	86	1500000000	5JuSH6RHkx4xhfyghBM1aR7YmQhtEQQ76N8L4og1HZjcr9wrj9A4
18	fee_transfer_via_coinbase	236	1000000	5JvEzNDEft8Evfke2L7hJh7y2vZQptBGjHrRzxvLdbEd8xW5GjV1
19	coinbase	86	20000000000	5JuLxQyzKTXkY8wPYAMJLdV8tYaqeZH4PMJbpsT92sdrQv74nSix
20	fee_transfer	86	4687000000	5Ju8k8GzhM4cWX2Z7QE8PeXrtBfe5rv9P9He2Kmnqn3zLcCtEWzD
21	fee_transfer	236	63000000	5Jv1A9YDc2rFtsbwTLueYgg2QPSzxmnf3yCLZ5DM5pAybimyCqLU
22	fee_transfer	86	2750000000	5Ju2d6EiCmoZ6eL6d9sLQ63umCwzyE7W5HmWsFTn1aRkFMd8SYZM
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
58	B62qqeegQ2efY2i87dHPbTY3URpAHVVz6nX6xzgh73pN2DUmF8BFyqw
59	B62qq1K5y1jdbzKLPe98GQVnscs5RWQEMLY9jSpxqTapgDvnhU9jVWZ
60	B62qn9R5QocBSRu88fnt8Vim7QT8ZyKpwuvnzBHDJMSVqfUjUgh2taG
61	B62qo1he9m5vqVfbU26ZRqSdyWvkVURLxJZLLwPdu1oRAp3E7rCvyxk
62	B62qjzHRw1dhwS1NCWDH64yzovyxsbrvqBW846BRCaWmyJyoufddBSA
63	B62qkoANXg95uVHwpLAiQsT1PaGxuXBcrBzdjMgN3mP5WJxiE1uYcG9
64	B62qnzk698yW9rmyeC8mLCKhdmQZa2TRCG5hN3Z5NovZZqE1oou7Upc
65	B62qrQDYA9DvUNdgU87xp64MsQm3MxBeDRNuhuwwQ3hfS5sJhchipzu
66	B62qnSKLuJiF1gNnCEDHJeWFKPbYLKjXqz18pnLGE2pUq7PBYnU4h95
67	B62qk8onaP8h1VYVbJkQQ8kKtHszsA12Haw3ts5jm4AkpvNDkhUtKBH
68	B62qnbQoJyaGKvgRDthSPwWZPrYiYCpqeYoHhJ9415r1ws6DecWa8h9
69	B62qmpV1DwQvBMUmBxyDV6jJwSpS1zFWHHEZYuXYhPja4RWCbYG3Hv1
70	B62qiYSHjqf77rS6eBiBSiDwgqpsZEUf8KZZNmpxzULpxqm58u49m7M
71	B62qrULyp6Kp5PAmtJMHcRngmHyU2t9DF2oBpU4Q1GMvfrgsUBVUSm8
72	B62qpitzPa3MB2eqJucswcwQrN3ayxTTKNMWLW7SwsvjjR4kTpC57Cr
73	B62qpSfoFPJPXvyUwXWGJqTVya4kqThCH5LyEsdKrmqRm1mvDrgsz1V
74	B62qk9uVP24E5fE5x4FxnFxz17TBAZ4rrkmRDErheEZnVyFmCKvdBMH
75	B62qjeNbQNefZdv388wHg9ancPdFBw6Dj2Wxo6Jyw2EhR7J9kti48qx
76	B62qqwCS1S72xt9VPD6C6FjJkdwDghRCWJnYjebCagX8M2xzthqKDQC
77	B62qrGWHg32ZdFydA4UF7prU4zm3UH3dRxJZ5xAHW1QtNhgzuP2G62z
78	B62qkqZ1b8BkCK9PqWnQLjYueExVUVJon1Nn15SnZScG5AR3LqkEqzY
79	B62qkQ9tPTmzm9oD2i8HbDRERFBHvG7Mi3dz6XLa3BEJcwA4ZcQaDa8
80	B62qnt4FQxWNcP49W5HaQNEe5Q1KqTBQJnnyqn7KyvSfNb6Dskbhy9i
81	B62qoxTxNh4o9ftUHSRatjTQagToJy7pW1zh7zZdyFYr9ECNDvugmyx
82	B62qrPuf95oqANBTTmvcvM1BKkBNrsmaXnaNpHGJYersezYTHWq5BTh
83	B62qkBdApDjoUj9Lckf4Bg7fWJSzSnyJHyCNkvq7XsPVzWk97BeGkae
84	B62qs23tCNy7qbrYHBwMfVNyiA82aA7xtWKh3QkFr1fMog3ptyXhptq
85	B62qpMFwmJ6fMm4cUb9wLLwoKRPFpYUJQmYqDe7RRaXgvAHjJpnEz3f
86	B62qkkXezNY521yNDXzntKbfLKrZHpDBGRFWCHjDpmGbsriyyqDcQo4
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
132	B62qroho2SKx4wignPPRf2qPbGzvfRgQf4zCMioxnmwKyLZCg3reYPc
133	B62qm4jN36Cwbtyd8j3BLevPK7Yhpv8KtWTia5fuwMAyvcHLCosU4PN
134	B62qk9Dk1rwSVtSLCYdWNfPTXRPDWPPu3rR5sqvrawP82m9P1LhBZ94
135	B62qnR8RErysAmsLHk6E7teSg56Dr3RyF6qWycyVjQhoQCVC9GfQqhD
136	B62qo7XmFPKML7WfgUe9FvCMUrMihfapBPeCJh9Yxfka7zUwy1nNDCY
137	B62qqZw4bXrb8PCxvEvRJ9DPASPPaHyoAWXw1avG7mEjnkFy7jGLz1i
138	B62qkFKcfRwVgdQ1UDhhCoExwsMPNWFJStxnDtJ1hNVmLzzGsyCRLuo
139	B62qofSbCaTfL61ZybYEpAeGe14TK8wNN8VFDV8uUEVBGpqVDAxYePK
140	B62qn8Vo7WTK4mwQJ8sjiQvbWDavetBS4f3Gdi42KzQZmL3sri25rFp
141	B62qo6pZqSTym2umKYeZ53F1woYCuX3qHrUtTezBoztURNRDAiNbq5Q
142	B62qo8AvB3EoCWAogvUg6wezt5GkNRTZmYXCw5Gutj8tAg6cdffX3kr
143	B62qqF7gk2yFsigWL7JyW1R8sdUcQjAPkp32i9B6f9GRYMzFoLPdBqJ
144	B62qjdhhu4bsmbMFxykEgbhf4atVvgQWB4dizqsMEBbmQPe9GeXZ42N
145	B62qmCsUFPNLpExtzt6NUeosa8L5qb7cEKi9btkMdAQS2GnQzTMjUGM
146	B62qneAWh9zy9ufLxKJfgrccdGfbgeoswyjPJp2WLhBpWKM7wMJtLZM
147	B62qoqu7NDPVJAdZPJWjia4gW3MHk9Cy3JtpACiVbvBLPYw7pWyn2vL
148	B62qmwfTv4co8uACHkz9hJuUND9ubZfpP2FsAwvru9hSg5Hb8rtLbFS
149	B62qkhxmcB6vwRxLxKZV2R4ifFLfTSCdtxJ8nt94pKVbwWd9MshJadp
150	B62qneGW8bizqp1ybJnqN5nzpdBqdS6icKypTDUcguYzVkuXDXCCBfw
151	B62qqwioujbhs3gG2G4mRRruSSsLBRtLzFVf6LnK3aMTAXQBgpAKK3f
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
196	B62qr1bVNmUQrv24AMCphiWKQ5FC2eoub2DaAiDyTDn9umQVqMp1zJy
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
227	B62qnd3TWhbQUxK5YXUYuAwDRKgjDiEdKNrEUv43CuZ4jRBCKRf27b4
228	B62qjy64ysP1cHmvHqyrZ899gdUy48PvBCnAYRykM5EMpjHccdVZ4Fy
229	B62qjDFzBEMSsJX6i6ta6baPjCAoJmHY4a4xXUmgCJQv4sAXhQAAbpt
230	B62qrV4S63yeVPjcEUmCkAx1bKA5aSfzCLTgh3b8D5uPr7UrJoVxA6S
231	B62qnqEX8jNJxJNyCvnbhUPu87xo3ki4FXdRyUUjQuLCnyvZE2qxyTy
232	B62qpivmqu3HDNenKMHPNhie31sFD68nZkMteLW58R21gcorUfenmBB
233	B62qjoiPU3JM2UtM1BCWjJZ5mdDBr8SadyEMRtaREsr7iCGPabKbFXf
234	B62qoRBTLL6SgP2JkuA8VKnNVybUygRm3VaD9uUsmswb2HULLdGFue6
235	B62qpLj8UrCZtRWWGstWPsE6vYZc9gA8FBavUT7RToRxpxHYuT3xiKf
236	B62qjwve4ngqVPAsSuNs7PVqSEyu4zeGFSNTn78FVebiSpAZk5o5Y2o
237	B62qkZeQptw1qMSwe53pQN5HXj258zQN5bATF6bUz8gFLZ8Tj3vHdfa
238	B62qjzfgc1Z5tcbbuprWNtPmcA1aVEEf75EnDtss3VM3JrTyvWN5w8R
239	B62qkjyPMQDyVcBt4is9wamDeQBgvBTHbx6bYSFyGk6NndJJ3c1Te4Q
240	B62qjrZB4CzmYULfHB4NAXqjQoEnAESXmeyBAjxEfjCksXE1F7uLGtH
241	B62qkixmJk8DEY8wa7EQbVbZ4b36dCwGoW94rwPkzZnBkB8GjVaRMP5
242	B62qjkjpZtKLrVFyUE4i4hAhYEqaTQYYuJDoQrhisdFbpm61TEm1tE5
243	B62qrqndewerFzXSvc2JzDbFYNvoFTrbLsya4hTsy5bLTXmb9owUzcd
244	B62qrGPBCRyP4xiGWn8FNVveFbYuHWxKL677VZWteikeJJjWzHGzczB
\.


--
-- Data for Name: snarked_ledger_hashes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.snarked_ledger_hashes (id, value) FROM stdin;
1	jxiRVWEj4jhGbpRdkPJpD8gZ6fo8hCTBkmrRnxYs7g7fUQ7uAhd
2	jwuANmDySJTPUdDZ3rgr5WM5jpPU3K9AgXXqkQxpDbX8f2WiyT2
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
1	payment	59	59	59	0	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuTEWm7pTYNGAhz56MdJHcM38DnLeXRseTLbH5WDA5Q4ydooEFz
2	payment	59	59	59	1	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuQTSE2fNrVvhNP2agtWSMJieqgqCg7bAWZohNA7DbqyawvHrXC
3	payment	59	59	59	2	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JudinH6HpDV9dx78zz9LnUfByRk89WNYftRrn3pnrejd1YAGNMX
4	payment	59	59	59	3	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtYg6cGD5FWCh8o5fNmkjwz4nu47j2XuohrqXqQUT6N5Apo3StA
5	payment	59	59	59	4	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvMw4REm7aDaSrVWHxvrqzFkVWLa5vbh51gZZGxoKkgSxWAbcD6
6	payment	59	59	59	5	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuimsivETvgGsTuZhtyLWVn53CsSgziojDQpp5FNduFKF6XpSA9
7	payment	59	59	59	6	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtZ6DGdHr919DD99uBNNJ3V1eS4uyHfvik3UDePRgj36tXC2MfU
8	payment	59	59	59	7	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuQTRYT8DA7zp3PYPT2wvZNNeqAQeZbHLypWkLEKwEaW1g6xj1H
9	payment	59	59	59	8	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuKYF9nVYJUN65Aw7KPrPQZ1aqK92ncpd4ppFP4fX1RLRJQWpsU
10	payment	59	59	59	9	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtYddbCsobkhYCgsJHZe38zDhJvX6pmft2hzGY3tLSDQidmA7Do
11	payment	59	59	59	10	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JurNE83MEspmHnFGpDrcocs8ZaKu32Z12cXPdETgnreNRWEPYgK
12	payment	59	59	59	11	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juckz5CbZfEpqnHxJpoq3gfRH99TNAmMNvEUrPcW9rWYDyAsmsL
13	payment	59	59	59	12	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JupJPc3avrg1GEgE158Euu7zSGFfjK1JtqN66tgfCD5p6UgqYdf
14	payment	59	59	59	13	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtdMEkdwt4x3cX11CnjhBQ481QLyaW6RePHb4hmLQALB6ThnCKw
15	payment	59	59	59	14	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JucZnMWnPvQFAxWYtkNBjx2ZzXWMzNGeu1FEpzDHCK8veHxKtpY
16	payment	59	59	59	15	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuWXYfbWHuBTPudbvdLjcY62BiJX8C19BBsoRfX3P4x31fJzeN1
17	payment	59	59	59	16	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juy2xo4WcwwHWUQBSazQKD6sa53ZDNjsw6nX9RRc3rKdiYoenjM
18	payment	59	59	59	17	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtqj9dy62BjQcriyLdQaKxjBhuKXdQRNmukqBUZnzaLT1Fe7n3p
19	payment	59	59	59	18	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuhvPRsWuBRsV8EiAdNEY62URup6Jc1W2RcKJpPA4rmVj9jALP2
20	payment	59	59	59	19	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv8yx3keHP4mXaSDUPcXjJvWe6sKP3LHvXsqoK5s1WHnHfvuqEZ
21	payment	59	59	59	20	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtdYDiCT54AtkYhsxM8LaWyWpL2WeTHL2iJKLWzg2Xw5LmY1DAa
22	payment	59	59	59	21	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JupwUaMBZB2X3CmexNLbCUCNshLTWs9pVKJDUthqYp2wY1TGNfZ
23	payment	59	59	59	22	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtrbFtaZhC8mNR5Bq7coSxRFVD6BiN4edJZXinyxCH5z8vAL4vP
24	payment	59	59	59	23	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvPf1siH9eTedSTm27apafD9Y8ZzjB2mXGV8ZrkbAeTnxu7BjHq
25	payment	59	59	59	24	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuGJzw3q7PZvAXqEAvVkKgTEq8JMW3V548Ur9Ga5ULowmtELhZD
26	payment	59	59	59	25	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JteE741o1sPGvwVbWyqBKPqHEaDuFhso3CV8gvtjez9V83S7P8t
27	payment	59	59	59	26	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuwhsGkUiN6aPpohV12QsnniffWJmJXbxBrzdG2pMdxnWhNzT7x
28	payment	59	59	59	27	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuDGPaZESqLAx9HkQS47GVdc3uA6UUQmfhCHUWEAgBnNhzk8kcC
29	payment	59	59	59	28	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtfCRGH1qH5QSBQ6or8peWxfKBT57D1GMrtfwDq5M1vT3y53DTL
30	payment	59	59	59	29	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvCgZyLnaH4sZ9mBWVvVqDyr3JT7mLhG5xY8ZTKTFWTqRzUqVR3
31	payment	59	59	59	30	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuDMPWUgq4KPw3Qe6CNTdxMeDtA1BiULfHLFrbj9FN153KmwcJe
32	payment	59	59	59	31	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuNqpStiv9wz4i4JPPrmkXKdU3p9cCHtCFEpVdoGm3crziVH7PJ
33	payment	59	59	59	32	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju8436AuZ178TRKw1ABYEpcKgn4EJpnaXtKwnqr9G8TGdJWSFnV
34	payment	59	59	59	33	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JucAQL57NHcGN9iByhPG23pHpk8RSbedZv9GvDD9Xtv8LGMJNpz
35	payment	59	59	59	34	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JubCpvtHxYFTB9rMPmrVkwgTFJwLbyUrE2aW2SL96jRwEUN4oyG
36	payment	59	59	59	35	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju4BeM8xzEt1EwR85Csq58hvRjC1UWGhhkMDjG4zbF5mzJSQXyM
37	payment	59	59	59	36	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuHXQtBfeqdE8eiD4FBQmtCnkkURCRBtM7CCSP4zw6W5f1kuRtU
38	payment	59	59	59	37	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtkVVs5Gf77BJrLBmtBMNyu4V36mvkpkDkcPimE1GiuADku9EjS
39	payment	59	59	59	38	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuZNvHSbYx1ZhDzo9pb9kp4d5VjNuwpRzvahpzk26kGzD6k45QL
40	payment	59	59	59	39	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JujUgQEnymbMNKXU2GUsaAyVTTw6ZL9YcTm8ZebGBJg15KzrcbV
41	payment	59	59	59	40	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuvufdkAmTYU1s9oFc1d54zNgNPb9jcFV5KnbapN1wKSEZBSqzd
42	payment	59	59	59	41	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvPkvekL7FL9LBHwGGPvX6XhVexWRiX69Qo3tPNgE5U8V6Ho9Eh
43	payment	59	59	59	42	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtaLwNatCYq9coLYDe2FttoP6idWRvqVo7HhTRx81gQvSp4WYuH
44	payment	59	59	59	43	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuxeGq1uELyjL6y1LNmPxvu1hva5sGF8MVrLmFZxw83uTsz93EK
45	payment	59	59	59	44	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtu2y9HUrZLxqFp4DHxafN4c1uxrjCAchHNfZZ7jsgKeoXwUjFr
46	payment	59	59	59	45	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuhRFvfgGH2WHo5Gq1dUoTgA7B52vCUJSExGwkykLtXxXKBZfTa
47	payment	59	59	59	46	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuWEyfhGTT8LvHDpxXp9TmgNaHW8bKsDdzPfmdS7sAYToWWM5Aj
48	payment	59	59	59	47	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju1LrZ2ZvitGomnJBfKjRNcaMnNU4ZfF2vtTBmADBtWWjfJj8i2
49	payment	59	59	59	48	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuQnh13DEhV5vNmNHavA6t4VJgrRKsZi4KShL7T9fAHaDX9e3tJ
50	payment	59	59	59	49	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JteUUvZ5BjcZ97KMWdeEkPWEvf7hrozNi8AAhJthQtohFN2GQzM
51	payment	59	59	59	50	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv6NCFNJnyq35wSZY8J7nDTDyTCJd7QMWqfNyVq8fkDiVFJLP6q
52	payment	59	59	59	51	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju3UW8kmXPW3PfumN236upjCHMhNpJ3QrYq28W6qK9dmsqa9kDV
53	payment	59	59	59	52	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvJfS1yJXCdPcXLjfS9Wv3tqonKFabzgMS8npti7FGEN78ixcQs
54	payment	59	59	59	53	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuDu2pcwz1QvLUoXCqBMfh4yrPqvnjzKWjcBKHKdfqirFhMpzqr
55	payment	59	59	59	54	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juz32RYcmSSYJGDSwcCF1XKxNcZvnRB4wkBXnLdcLDThGbDxZj8
56	payment	59	59	59	55	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvNS7CoZHndjofFd76cPyBMtPzteNxsvyDLwRdFd9Xuxnr24e8K
57	payment	59	59	59	56	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuFufnYqAFRtaawiLUzwp46vQqmBir3mPoxZD1UNDXiq15hcoFu
58	payment	59	59	59	57	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvHH3MJEsUnTyXhRDWukdhhP9JmziGAKSrH6eE5PDQqHaz7NVbz
59	payment	59	59	59	58	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juk5vHyTUzSEx6h3gAHdAJo6fg87QH6ARAo9epLFz4tAo9mGiTK
60	payment	59	59	59	59	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvCRXuiyAfknkrLfEveLZTKTZ1yCTsotrcSBBqUWLcD8SLmJwzJ
61	payment	59	59	59	60	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuQtRtNUkhyooE5uLkHz7Xf6sYZ7JUPpJDbuK49ndowo1xAQgYk
62	payment	59	59	59	61	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtup8dNutyRG7x5KiKUKbPVuumHKcjUA4YLtUD8jCuFWtiGqk12
63	payment	59	59	59	62	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JufhvV6tsUyFwfGiJB414hnUb3Jx4DWwSa6RpMP8Z4DZ4bEjCjC
64	payment	59	59	59	63	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JteuUYUo3iSvhxkrjfyT98LAWw1aYPWLB9hQq4oddE7kZVfPHig
65	payment	59	59	59	64	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvJRjwNMvvuqkEkufiLwmWSfeRjbmViYLv4GVNa93M2EsmwV1JH
66	payment	59	59	59	65	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuK6W4SSboM2TnXrMfbufeubYfGqsqVmwieifJaqwqzbYkqwqMM
67	payment	59	59	59	66	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju6Uj8uyx57hu75j4SwtTm9J8KW898ztprLBMKPfMGH6G2xT6Ui
68	payment	59	59	59	67	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtafJhGsWFFvrePp49u8CtTLPyejTnPCecr6omq6nh5SoR7LQa4
69	payment	59	59	59	68	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtzwWZraqyX93ooULnLswZNpi3vARB9XE8J2T7xtvbuxC37USeG
70	payment	59	59	59	69	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuTdrGa7cePEJqVyQd1726CsvDwEqKPiZoQJixSdb7QEwBLGmqx
71	payment	59	59	59	70	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuwZmc58rsxRcQYk8QmtBkGhYPN85bpDMbbMUwxKJXpzfb9XxQE
72	payment	59	59	59	71	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JteK69RjJNLioTU1MDfrxd4aVkfzuUEmbBvyqqPMraK265sv6gb
73	payment	59	59	59	72	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juo2uek8UwDKDXCBmHu4k7B2wJJG5ZQV75Epm8xXYach2D2BqPr
74	payment	59	59	59	73	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuzzR8N4NFRyUJheN8z7Hzd61mqRpqNzJrrrbdyZkcUfH9mw2aw
75	payment	59	59	59	74	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JufE4jhNMgV7vhGtnv3ygVhFmu3J3VeQFYqC6uUkPecHwUoXGRm
76	payment	59	59	59	75	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuCviwjPvSA5TUn3jX9dv4adqBHWaBJYuboL1cgZ7KBoWNMHQnD
77	payment	59	59	59	76	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv6PnjSS4AXe8YxZnAgRvcPvTYNbMFAdaPSPjf6jk7Z1h89RU1e
78	payment	59	59	59	77	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvNkDeiJ4ndMs56j5gHTNEF691q7Zg7HmNXyeziaUWusXaWKMfH
79	payment	59	59	59	78	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuDwsy5nDMrdpjPiYux6gpKzopKFHk7iYqH8wq4xm9taUu4aJ4a
80	payment	59	59	59	79	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuEEfp3YDyP1s3iNEgW3jwaNHoDSm3587fFRvRj1r37ahSF2XVC
81	payment	59	59	59	80	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuUFJbee1GaaURndbvd1AhwTAVjLPgUXnspS58vMWDtrSzvFtKS
82	payment	59	59	59	81	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtazjQovmY7XMbGm1mUvNbm3deuXwWnEwAuRxUKnodoTEYC2s89
83	payment	59	59	59	82	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuWWAibF9RkVMmR2YCGA9Rk63QHuoszXoM5DuoAeYsjebNYCEjF
84	payment	59	59	59	83	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtzprYVpGaY54NtDphGqgvNq3KTyG1QQ1xiwoKjEZTLTJBVg5of
85	payment	59	59	59	84	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuGckKGGxTCLvJofQh6WSgzWi18K92g6YXZ6ffjHarwjnBnACtH
86	payment	59	59	59	85	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtnEdqN7TimP3J1RnYH8dMCw3tKwB1gEP4ZS9gRdi593Mrgy7BQ
87	payment	59	59	59	86	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju6JL4XiscwLgkMyE6dr9HKMjbCJ31gDGYgrFQ1BnuKijmaqbX5
88	payment	59	59	59	87	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtuQRzT2agLXjaGM1MxibFw7f5eGtggCYQ48UadUrTU8Po5iJaz
89	payment	59	59	59	88	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvQ4LfeALBpzionj9Qf2A47Vtc8vprc6VnxirYpjTskfNeAsDZJ
90	payment	59	59	59	89	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuZsqmic2zC8qPgcb95ip5TDhUhE1DYggnxZUDu4T8zDuBQW5KN
91	payment	59	59	59	90	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtj1N5N4DmRgvikt2DnnGbzpANbYo8LxE6r2wdu56aNM4ZJTCzS
92	payment	59	59	59	91	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtVo78XrbNFYscrWbPrFAK6XZnxdegR8P6jQpHkbF3wW7yfxN73
93	payment	59	59	59	92	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jug8UCQptRzE5pWH8XeqcSdEdESb9bcNsGSD9gxAFKobYxCenPW
94	payment	59	59	59	93	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuR2z1ZTtVHyqGTBJCDm4RYGhMWrd1eJKoNgCT87YR2CC2gRzvL
95	payment	59	59	59	94	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju8msaWPyXodv94mvNfqovsCH37Zoj88MpFED5E6AnasPCkHhpc
96	payment	59	59	59	95	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju5mTBrGbAPCUFmfgdFvnutXpRR47gTdNMkNmHarR2LdRjdZukP
97	payment	59	59	59	96	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtiEUj5VfaX93EDXqken3Pj3cJj9z8gYmzd6TDEd3gSBoukYfKb
98	payment	59	59	59	97	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv9GK5DzqY4bbuaT6WhcuEcjX58XGwVc6kmt75XRqJaCnL2MDms
99	payment	59	59	59	98	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuTC6EserpCmx9gJTydB1N73KesgXwXK8QvznASVKbQdthQ6JfJ
100	payment	59	59	59	99	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuqJxirMXs2FLiGRELkThEFXan4EjCAfzLu2sTzxHSyPjp3qpyg
101	payment	59	59	59	100	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JugyrAPAskWjBqiokPDWw8XjVK3tP953jXA2or39XxqYxx4qSpN
102	payment	59	59	59	101	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuRKMwwhB9xP8ygDVkhK2TA3YHrhpuejzc8YxSar9nb4dBEBpZB
103	payment	59	59	59	102	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvPS4cCv6kXBKhHsJLpB6nSxWo9NjetrTawEPmv5nbpQnXetpyC
104	payment	59	59	59	103	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvKgyw6jnaCQzm2K9TV9tPumaQ1aiyBxsrEok5PGjES6dEegzd4
105	payment	59	59	59	104	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuP4CDk8qv5XRAW2FC8iRtFk2T8Eemzi3RSPphhFcJCKWe2CucZ
106	payment	59	59	59	105	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtebNSnHBgUZUEgzgYaRoSYbxAuhZqcpDWAz8pJgyBhS9L2q6WM
107	payment	59	59	59	106	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuFadCJayvJb7pCmt1Fp6RvqL24PC9ypVTunXCKxuvswKRen7st
108	payment	59	59	59	107	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JumZapJaTTTRbYv9esGJ2Np2nw1bjEfD44Wugff2mSeoRMB6VT7
109	payment	59	59	59	108	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jupoe52gFtjHZf8WMVajA8PLKEXC4vNDPQ9mhP1Dx4TAHu3Xg72
110	payment	59	59	59	109	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtde57PzJNYcA7zo8J9rpFTPhA4heLigdZZZaEZco9yscKhczF2
111	payment	59	59	59	110	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuosSPx19EuLeqHMcPvAbKtgptHGZE3WX2zQXyCRmSFnUemQorv
112	payment	59	59	59	111	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvATQgDWYyovZ4HnSwi3qGUnysYWjAUg1m7gc3mQ8C2qvUjmgy8
113	payment	59	59	59	112	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvAuBwdvWMao5UKa8GuUq5nH8wxikHZWAQDMeAdq3W6hd9WUJDy
114	payment	59	59	59	113	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JubPqDtsfinHPrwhojN6EpvL7PwzaZddtDL6WjcopAMjYS1t8M3
115	payment	59	59	59	114	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtg8indKnbXN9C8ZhNHQi4RX9XftNRS9ykUmWQCncqkvNCbL23C
116	payment	59	59	59	115	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv1JhKgSFTYNteWU2vCsbudLKPiyRBc3bLsNhH56m4uh51fLeVb
117	payment	59	59	59	116	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvFn3DeTxSy82XX3i9ukEDBWETMw276kdZ6UmjpN6WYbXV1hR6E
118	payment	59	59	59	117	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvJvLRMf341bJFYjUBWuLrG5G5Vs5VaWnFguDV9y7rzfkmchmhx
119	payment	59	59	59	118	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuSmdWAPQSSWEJBCq9qhKN13BZarEuQ71SFJf5ajwi84r1iu2jK
120	payment	59	59	59	119	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv9wPuhU2oC2DChJ64zm7EvuutkkMKB4AmJMJ4TXr7WUrxkxY8J
121	payment	59	59	59	120	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jum8DX4vWWKtWNJDpVGzn5Jwg7oN4SPhSpt2VKNRtC25GQZ6nnB
122	payment	59	59	59	121	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JueJxwWW3WkBrNZEygSmmt5frThe5zpAQEVV7nwcuycxQCPDdFG
123	payment	59	59	59	122	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtzxf3kkhXkvshTEEEn451SsPcpboECJiyH7DAXrbu1GyzrrPxG
124	payment	59	59	59	123	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JteavBjsDB84wgb37wTQJ36kGcWoxWiH39kvoHDZqvGWfAhwnje
125	payment	59	59	59	124	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv15DzsDSicweW8e7HZZdRok1pCVFq2wwWVFMCfERa6BEMSFi5S
126	payment	59	59	59	125	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtw1YqHKWu9BJANxEJgQ3Bk2VXrApt3e3G8YaiM1cRGP5WDyqDK
127	payment	59	59	59	126	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju4BRMwA9pXcD79MYb7YPdGX2NEQr76R1pyZ84bmHesJJb6rpk8
128	payment	59	59	59	127	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuTu2szFtap9xT338mFVhu6rEDzoDxm7Q2BH6csBe98Cvaco6Br
129	payment	59	59	59	128	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtzQucu36BLEdgzkA4hrBZt3aLAeB1RBfbeziwpxFewi4c31Lyb
130	payment	59	59	59	129	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtyanjpeVmQiarNPUNRM2BC5ESHFXUy4joJZtG3qYYmhQywbNUF
131	payment	59	59	59	130	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju68R4c5XLmY9M7Y8gHcVQVkTsgeGn1dEes9r5e5HKtjHKf2ALh
132	payment	59	59	59	131	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juga6eSV3SsqBi5GrtWpZQKKsmCdoLbFH6xyACRdjEpWhCLw5UF
133	payment	59	59	59	132	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju1vtZi2i5AtVGAcuG4n5ca9CRj3aQPJgiU2eKtM8NSY5Riz3ns
134	payment	59	59	59	133	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvPQ3LAeunigps8NJvrbzWPn3dP4rtNUkzKVpz8UEQqUpu5bXPX
135	payment	59	59	59	134	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtn8Nn6qw6NbQa7rPX4MsSLcx5kEpFL8GttzwhGT6kyvP8sBgdx
136	payment	59	59	59	135	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuciiEFXorLyHw2AUj2kKGYEFhiYhfZcdX5UGqKr2EE1qYsDRfK
137	payment	59	59	59	136	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtxH2BBCrSBCfTn6zkUtKYeNXWPriXRSrjG374338njqwkqyZmz
138	payment	59	59	59	137	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuinJ2vL328jv2Gbv3u97qZa32BGozZBvVT3XfejKuyBKq8QwNX
139	payment	59	59	59	138	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuxyRBWkDhPcUNCiyTNsLyh9KxqNLMCS2omZZw9tnWHmGYV5fnC
140	payment	59	59	59	139	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuSXq6fDvSvBxpdgyiFvW4NmAFfVis9WKv72HuHVYhYE57f6GMM
141	payment	59	59	59	140	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtpuHk1dBZoZAGo2niFGV9e1YPTttFLqJTU4V8wx3uThJEbw6VC
142	payment	59	59	59	141	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtiUC9B8DxmLEuuiEptMBf5FcSv4PBGeUb9KzWomq2ewzdcNWav
143	payment	59	59	59	142	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv2kBgqEmdCptJFrkaPucNsUK91AdezsRn2SpmQoZH9fptfFuK1
144	payment	59	59	59	143	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtu4mTY5uRJM8PbRTeFqKFamgmQuA6e32t3A6B3eSXXwmggGhJg
145	payment	59	59	59	144	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtz6fa2C9Z36BEPVamBBitaDrZ5JsjJcqjcsDxTYfSDBAvU9353
146	payment	59	59	59	145	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtsEwWFPvTwsvfmZcZM7c78k2n3fnHf3PkPgDEBqXa7ERrydnxB
147	payment	59	59	59	146	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvHgmHKWfuvxRjkzVZYCjphJZh9y1aP2dYnPXiN3WXzGFZyToNN
148	payment	59	59	59	147	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvMWDtYTxkX4f9dvYgGNVVUMs2pi1LBN5yKudHi5wiyNuUsTw6m
149	payment	59	59	59	148	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtWt2YPm73LWtNXNhxoUVTerhqcNERDeaKVJ6ZGJJY1Yw4FS7vm
150	payment	59	59	59	149	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JudqYoyQEpfQPUj9ztHbVDAGUVzfQQQanJ2xvg14Y7pAEiApTzo
151	payment	59	59	59	150	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuWp7s4UdzsdE2Xtm4zFZj5KgtdX7Hddp4fwWQTvsFMP7anfgAr
152	payment	59	59	59	151	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JufrkoxUweNNa9imDREnZDByrt9Hny8J7YC2b67QPKjGHqfVjDK
153	payment	59	59	59	152	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JthFUvndDj4G3TrszhzF8jXAqM6QYPiHQkCiULM2DjzhBWSTnZC
154	payment	59	59	59	153	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuMPMbphXLJYwEPtZGacn91d8CxhCvFDHrWT9MxJ5FooGN4e1PH
155	payment	59	59	59	154	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JttCM4yzrwmWhyeTUuWLHD3H5b6mD2BSC3EdX6Nuyq7uUKxp23o
156	payment	59	59	59	155	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtfF8SzJESCF3R76Ts2XE7JNPZV8inuhCLw891UgHYudBcoyKMt
157	payment	59	59	59	156	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtVeE8yLuZ5YBFZ3JzzsRNkEhBqNqqHymztJk4UP3XQ1ibAH2Vh
158	payment	59	59	59	157	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju5UmwAhGqVFdBFuwFefDrz1qx2tbVPgszQjcDaaorYjuFgzuos
159	payment	59	59	59	158	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuHGyrKDhkCk3sfkPVgaCSG9pxLAzNViPtgjD22ZPCjPJgJUkK2
160	payment	59	59	59	159	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvJLjbFMNFWRu9k2n4ksMNumrzsv2wzTrPxtkGu7syUUzDDGnUF
161	payment	59	59	59	160	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv2Gcv9HftzNEPz72qGjmcLzmLAD96dpQzTLRaFsf3ZGc6GvmsZ
162	payment	59	59	59	161	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtfkMUjFiJPy3h1rmh4oatEHFXKWBZBXY3k9XEMJbC7rdZcx3rM
163	payment	59	59	59	162	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuGMPZZbDCTHf8gKTq3EMmEkZRJkudMb5YsnqtcerGkbawcHKgJ
164	payment	59	59	59	163	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtkFzAxPn2e8eFFgLR39eMrgVc2hxwwmMmxQJTRNY9szPfiyAgD
165	payment	59	59	59	164	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juf92yLtYvfruhzhHMRtdwSQrYZRaLeZJPup4ZFeQ1ujaYHKLSx
166	payment	59	59	59	165	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuSkJrmNk3a9wEEoY1Zji61UcejvzX9TipgD7Z2pTchU17fgHuB
167	payment	59	59	59	166	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuYBYmHANNuFoi3KdrzfTy9dErZK7kMkrs6vGHKbLSU8jMo27U1
168	payment	59	59	59	167	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvKLG3c4D23En3iJkVJgK4285uGXCo1291EL8wU4M57cdUAUYXW
169	payment	59	59	59	168	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jusxdd97y4BF7VRzozuSrUeVWBFZikjV2dDzMJMbBTSFykqX1du
170	payment	59	59	59	169	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuFQAvu3YUG11ZTezaLQbgpw7ndjSXCx1DbRrXHveow98Aa5szm
171	payment	59	59	59	170	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuwfZkZ7FUG44W9KpAjZPmmCHiBGg4v16RDWYyPKcy5B6Eaqk8r
172	payment	59	59	59	171	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv6zX3VtCKiBdvgNYF6ySY67dtjuEWupoPfoHqW46ezzynwxop7
173	payment	59	59	59	172	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juw3Txr8ECoWL9KYMLmN4jthznFzst78fiH5iCv27yaAbSahnDF
174	payment	59	59	59	173	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvB7kUhMsLPPskqa1KcX2CMaQhttDUKeGY4NzDtsk3cdrkNBuPU
175	payment	59	59	59	174	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtvbvcSTmahsgkSAdEZNaHPXnVEGY59Bx57Cj9nmFPocoD5rD9X
176	payment	59	59	59	175	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtgHj2jRoQnYY1JboXBy1Pc9zWfaeR1tx57gxedJFB9APb4CrWT
177	payment	59	59	59	176	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtd6xHwypcHKvxMbvDursSUkLaiYKV76kVBvN4VcJyvgZ9ZtX3s
178	payment	59	59	59	177	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuNbMsYbDcpyVmziMPwpcaDuh2vZYRFX9TtofeRUxtC8RnaWEZG
179	payment	59	59	59	178	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvDrfpcPMYYtb8HkcLiRBfffULWBjRsqGhbahvRsTUvyjUg5BbE
180	payment	59	59	59	179	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv3WhSw8PXBd2RQYRw56Wsty9PZSMqQneeFvGxsn74iVRBG1o5V
181	payment	59	59	59	180	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtYoVQcUrr9GKzgsP4Nvw1gPf4yhaFSFfidCtA5VQ47wgPPJU7y
182	payment	59	59	59	181	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtZQbLAaC3uJ41GManHpbVihFvP9VZc5yeAFDQWoJVUDukREU3Y
183	payment	59	59	59	182	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuvjMt26eaZZ5ZCZ85LhTVq7c2w56YZ6qcV8UkwvtGwTR5zQWx3
184	payment	59	59	59	183	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtZWguEwUyPETyYDeod2BfZDRtpB13EWn7gmRxF2sCj3YmJ5rE4
185	payment	59	59	59	184	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JttDXBTu3BorYhTsZHipbSDmiQSUFrxiqDH34FVcUpkodiYct7U
186	payment	59	59	59	185	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtvRF1qLa9wdbRL3vq69Y6tmVhJTkVqg7NBKBWbdMyS3GmDxYDg
187	payment	59	59	59	186	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtmtg49QN5EuwfXws5qEAKkfVfaGLoM1fGbc7NTQmsXHezjHRVD
188	payment	59	59	59	187	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvHLwTMcL9SH65EVGXnhQWRgdZTtcaENRfcqsiWLCFSk6r2W1xg
189	payment	59	59	59	188	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuuX5FA525TBt8yJKYxWM6DtMiHfHqYbFD9xzibA6BGx3ZEqWMh
190	payment	59	59	59	189	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju3ekHMvAVp9xnroDXDo1V8oPTznE5TSQ8qnxTsDYVD5gVQgG4d
191	payment	59	59	59	190	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtW2m4y8LSm8YLHcS94Zre6KqiUX9T2LvVCoLEARcrMZqWEE6fo
192	payment	59	59	59	191	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuwxstBc57xnzXswSu4nBTtNsGbGSt7xDUGx4wZie3frW9a3t9H
193	payment	59	59	59	192	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtYvZaYVmLMKEET87DUsathHK2WrkGNdmtXKYSju9dJkShpgmKT
194	payment	59	59	59	193	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuHsTrGDWQtJAMCbujr9rsnbNahCG6qBZb2E1VPhFPfekqeG52j
195	payment	59	59	59	194	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju6DYrqpwqn5rLHonMVH24PAbxLD1g4pfvMEYT45Z76RUCQijC1
196	payment	59	59	59	195	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jts3ycVL81ecDG3XNwMs4VWo5fQHhcbjHbQQXLDLWKgZUCm1uwA
197	payment	59	59	59	196	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtvrBZUroQ2PZYLAU1yn5jCZrtk2uN9X3pJB254yzArDFBofyp1
198	payment	59	59	59	197	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jthf3zS3x7eFHq3CYPQNgNhxVxWnyK5yUR7s5ByEJJKg7Shc3Xz
199	payment	59	59	59	198	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvGie5U5WvWGwbJK1agV2dtiCCPcjQLa971ZXeJhpmj94DjEFx2
200	payment	59	59	59	199	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuSmFbZy3KgcJ7VzShBqQsQ4sjT1CMpscSRS3dS7UXA84AqnmgD
201	payment	59	59	59	200	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv7q54gyWabCiYf58x2jdaF4ZpncRWekbmnSVitFHkpod3F2ovA
202	payment	59	59	59	201	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju5JzLkfqFAjXTyUYpBLhGMuR7M3pzeH9he4envhCrimeuxGXAw
203	payment	59	59	59	202	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuWRtKBGVpJYWiWwy8QAfj8ckK6zAASTyVbjBu2B7V9kJ6icikx
204	payment	59	59	59	203	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtqbJ8Ln6L61C8w15n1ZbPXrzbDtQ1hutFNcddARoKPd9MBQC75
205	payment	59	59	59	204	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv71XZDtxRUCzhgnMVtjnexoaaC1z4RJ2vku5h8z77GjuJJNzSJ
206	payment	59	59	59	205	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtq96YjwicLzfgq2jgCecs2ijbwKES5uCjFKTh6RwaAK8irRMJn
207	payment	59	59	59	206	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juf7p6AK7WSRH8KfxXK26gcN2aLkw5Uo5BuDGpQZKoPwNnsKo3D
208	payment	59	59	59	207	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtrwKgrs8UurJ6dhu3Yx8fQoTKZLVUZ9jsiLBZiwQfxT3DUx7mx
209	payment	59	59	59	208	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jua3BRCcQam8cYbVjTELSw3KV1658nWGufQbHXjDzyKWvxUHnvT
210	payment	59	59	59	209	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Junyvwd1H4TAdqGjxPvymAMtTePc3Yax2ktsxhbYNKKWpNUvWSq
211	payment	59	59	59	210	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvD9AbGxgkv5m9pPfMLHffbJFs5zKsAqkgtvnYMmZLhauSPqzXw
212	payment	59	59	59	211	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv8SseYrp2DyadbcfTX9VNTmtPxaimq5mPvyJNNtU6aKjqicbM5
213	payment	59	59	59	212	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv1yd5USMzmUKduY1rBsUfzTurAWgDy2J4VA35Pp4Q93v3KX54j
214	payment	59	59	59	213	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuS5mEkskx1tUbAw1b7yLvccVGG8q2CCbpR5W9CJvaHQ11KzuFi
215	payment	59	59	59	214	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuuwdxesTH6cX9kuamADJyw6aFJZMRfp1VqcEwnm6Vy8dgTKaLz
216	payment	59	59	59	215	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtYiSRun4bTQjuG2GYooKMsjQnyEWukufuHMMmoLjxq1uxa8NFL
217	payment	59	59	59	216	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvPX4ZuCqfzh13ZadPW39S1iWqYDN8gE1UNcLqddDdYrYdSxUXa
218	payment	59	59	59	217	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtgLv5uzqmvSBHGjcJs3YeowKYW5GR78FYFQ7aL3bvNy7ES2y56
219	payment	59	59	59	218	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv3T6w1BA3pf5sPJ6RNmtz2VkNRH6Xkeegbp89asQFfNTbjUrTG
220	payment	59	59	59	219	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuPMoziP4NXFrMmtvQaZVQFPgTQk81FU4uHduyBm5T1mFDADqun
221	payment	59	59	59	220	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtWWyhsLUndWiGyHLGKN2rsZ3ewpSzKQsSc8coy23XXxKHtr3u8
222	payment	59	59	59	221	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtVnnVMF84inc2zWM5hz4r6pZYGbE6V61nKwkKP9g8ECUVHGQ5e
223	payment	59	59	59	222	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvMTsXU5U6pPc2DRfv49jsw7v2QapBijQZDHqRzP9MwypNmX6tT
224	payment	59	59	59	223	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JteckNgA2fDdZbeD8pJumkx7M3sQeBWA6rD5YEhkJM88iqniDxF
225	payment	59	59	59	224	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuLMwBrq5PYdh6vmkFFwriuExNFVibRkr3YwMttaQDUiQfsZjyd
226	payment	59	59	59	225	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvEbuSPdQ8dKX8n6R2fVKHeDY4a5VAoFHVo1W8b9NwY9mNenesU
227	payment	59	59	59	226	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jum8Ych4NYgheJtmKExpudzpgaF27qpbnVVYASrDVhSkFXvjh8E
228	payment	59	59	59	227	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuWGsPaXzgHScJioPS4UbfsXhswf8XGWGusra9vXj4yvBxAMeXx
229	payment	59	59	59	228	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtmSg7mFDpvYs6Ji2g11QnKCUSCZeJu6s35E5ZDkiD32yoJrvpp
230	payment	59	59	59	229	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuN5wQ3riUV87soNVKjwrETAudBF7BzYvVQkq8TDAAuCTdkJwmp
231	payment	59	59	59	230	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvEbnjKVX8EdSxPYzcFZ5aUqxXH9LUHAnx443VipcwSjzPtbWfy
232	payment	59	59	59	231	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtx33uE6KBKrj5tzpbGrUpb2fMxiGfpsHGmxhCmhnhGovd1icqp
233	payment	59	59	59	232	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuHpq6sVfPYZn3Mr4EQpiJD7D7A9YKPUstf8ZV33euPV1eEHb54
234	payment	59	59	59	233	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtwkyobUW2dp2A75skbVWc1d7sUG4ZkRd51Y5LKN3mcdDW8wueD
235	payment	59	59	59	234	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtikLmxaqjeyj4VyjdCsZFR4pGFuGFk8n4k3twzTeCot8BFmyJZ
236	payment	59	59	59	235	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvQScMRP3JhifYroLjPuyrA1sj9XQhrFm77vNyQjcVdBHLqfMco
237	payment	59	59	59	236	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuysTDYSvvf9xxwCkjZu7SUBTf7QCDPYiah5h1YuxgL5KAhJqSZ
238	payment	59	59	59	237	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtZwyj88HgwSRGzuHmy3kZG8zFYhkswCq8usz4bbXMNPLzd3PC4
239	payment	59	59	59	238	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuAAUiPnmujpYz13cAsyTRhPAtrbj1kckSPfqHejBB4n3mTWZHY
240	payment	59	59	59	239	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuCkriytdDuXP6DHPQ1ZQsEhbvXa1Zwu4znxW43dBUStYXRD5L6
241	payment	59	59	59	240	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuxG5iPUnfwvTK1zghL1R1YwWYWCjsUb7VoxLVZ9ZCKkg5fWv23
242	payment	59	59	59	241	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtuBiTkiQbxnWkFPVZJxhTzcmVdXmfogmfpxNUTeeJAAfZ4pxjz
243	payment	59	59	59	242	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju2QGkg6xkDUQQcaYtVv52455emy4rEEUvkSXfpYS1emZ7cAz31
244	payment	59	59	59	243	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juht587hDZTTCUQHmaaaYQWrhpFm8bW5Hrp3uY8QUhMn2kLet6x
245	payment	59	59	59	244	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju226aCRX4rNqdDtE3rPauJtZ2dQmBoxu8LWMUj8haPsMStJVDq
246	payment	59	59	59	245	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuHJwwe86zdM4Xr6QyGduT9JFcF7C9QZpRwFTMAMjydbsumhjui
247	payment	59	59	59	246	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuVUSsoVjn3t6HTLQ1dgJ6jDSeQv9DE9dw3gcgztgyLdW89pNf7
248	payment	59	59	59	247	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvRXp7edT77hye7ZzUN3pf4u6dvoc7w4koyqQW9exLkiAXXuFro
249	payment	59	59	59	248	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuVtTmK4tgskFtydNdhPB1X9e1NVpttXoPdtJaC3djqyJVk4VEh
250	payment	59	59	59	249	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtePZsEPH3oYRycPqKYnYbSDDy7sLnmvR575QseiJXusAWQMW8i
251	payment	59	59	59	250	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtzqXrnN4UPbpP576JG2u9Gvh5jyL78j7bKVv9hdjbjzFnh4D9s
252	payment	59	59	59	251	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtXcgwP7iZSGznRRU4d3cYpS68hMcMi7hz1iMLryUaVMA9FuXkD
253	payment	59	59	59	252	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtgajzRsi9py2TktMpneEKTXqgJHpR7r3g2LZbtW7A3BToEA1rw
254	payment	59	59	59	253	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juupu3J1VfFo9uwdnnKFSigBeXE4aGSysHHEBscVfiknkSuZ21y
255	payment	59	59	59	254	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju5hnmeJfsibnn6ooVKQcNhxhXUkHbj9L1xXDdy4PSttRbmmB8U
256	payment	59	59	59	255	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuUzXW6R4JMm89skHPxkospT6rb6mjoB9P2J6RzpDnoXwNTNebP
257	payment	59	59	59	256	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtpd7m13mKCf6GCAgTfhqyrPMX7vS6m8kxNFiDbAKAvTf2raMAM
258	payment	59	59	59	257	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuEwvjVekE21UT6bgAhJHCE5wMz1v3DJ7T3YNG4hdftqX55zp3S
259	payment	59	59	59	258	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju2jKjDmw8aCJKs1YM3htVEbMD9wWNEp3cisUzn1QSmPsZa7svk
260	payment	59	59	59	259	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuxKHfUnCbveKRunhpdXBusaPwRc1Con5cXdGqBTg8wVgTwsRNY
261	payment	59	59	59	260	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtWb1tyYNKBhZX2EFZCAwWfvCmpxWDSgYRXyzzWCdX1FdFcYkZA
262	payment	59	59	59	261	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv83HNWcqyGYnRP13P524MxYs7GX7tD4nXoJ7xSjKLoQHoAkB8i
263	payment	59	59	59	262	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuXYSN8j1umHfJj1gT8TJdod94MHaTUy1zDs4UN4oNKxT9Bb3Ls
264	payment	59	59	59	263	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv6TpYPNideH5iMSps9ivwrzmDXNJyWaYi5pcGBPj9mYKHZYLai
265	payment	59	59	59	264	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvCMUpwXCLeSfmsnGJmcQBMLPrKK1NvX4txz7FcpPTQzmec6waE
266	payment	59	59	59	265	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JubdUJcfAXVMHnHxUnPYqF6bzExrEsCV4GMj7ArLvzYULPHy5Qk
267	payment	59	59	59	266	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuiihhXGkvRJHXVkKoUzwUDRbe635nRxjwarXYXFcG77LRt3BA4
268	payment	59	59	59	267	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtaSScRbUEU7VBmbAfQK8wvPtLipBJg3nCyhfmkNw2RanNKTtJW
269	payment	59	59	59	268	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuQmRxkygUQT5Ysko82mTFrJNxWxbDwu1jJY14MtFXdm57pwoPa
270	payment	59	59	59	269	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvJ4VomSfAdhvj68qUDJFsCRPeZBJo6WgVvpSRc5KEk16rgVCts
271	payment	59	59	59	270	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuPrsjcabbbXG7pM15Ksv99n7fY6hTsFoLwVhLPgXQhEnZV5y91
272	payment	59	59	59	271	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtqpzvL6CUPNHfHTGwRzLGg8Sz5M9iHqvbAa56n1xqNEi3D5Nb6
273	payment	59	59	59	272	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuHpLrn1RVoWWXKYX47vYLahJqsdZMspqz1zQrb2M7bpi1gU6Bm
274	payment	59	59	59	273	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvGoP6wzNepZYdeH4KfipG47pe8jopcFE4sTrYNjrnyW51KPLQG
275	payment	59	59	59	274	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juymi8JomYc8R3BFecn5CpAcNwLdbK9UTGRp9Us5ZyLeZdiokvo
276	payment	59	59	59	275	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuXyEtfkBLv9qbpUH9dKUsvaqqTDkzE7JKmyQF5Rcz9tWB4vUBA
277	payment	59	59	59	276	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuFTFkefwQsWweKjx7hEn5j6QBkeDpcM92FdMnLs6aJCchU72ZT
278	payment	59	59	59	277	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuEZFfD2aTYmL21VHMw2YQK6RMZCq2xeXyeECXF2bMztnu37iLx
279	payment	59	59	59	278	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JurftZqVxsAoyQqHctAYn1MS7z9KMzGYmFNDpgNzbQCmbddBXqG
280	payment	59	59	59	279	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvLmaUDep7NRtAk1w1Uz7Zq4ttAxcZMRmntGN5qwfdtZqa417se
281	payment	59	59	59	280	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuBYrRMRvszMSZNaZ8T7N4MmVamAdeoiL4RzhtRH1raQwbd8ycd
282	payment	59	59	59	281	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtuvrWL7vTSW8gCCwTLMskMMuVyonSRRmoNHnRbovQvVsfzGpXR
283	payment	59	59	59	282	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvNBTnMU9jnx6HHYQye1tzDTe8hC9kmyJrfpZnXtvRbUG45JGNM
284	payment	59	59	59	283	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuQAoLsYFfhx7UdP7VPHUMQe57sQ6xs722tjdqYwPj2KBKXC1Lo
285	payment	59	59	59	284	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtw28NB1yWwEbBoR9me1MAkeSvr21WuXVNmCLR5ADVTg1N77AZn
286	payment	59	59	59	285	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtwqxrXaMH4iHUaHgmHjBnxEEHYaum6EGumsDyjwB1b7T3EdZ9q
287	payment	59	59	59	286	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JubQEeQ7vivggExj8Qty74CnS6cB6DDgKXLyJgE69Y9vU8hiw3w
288	payment	59	59	59	287	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtcc3QffcyH3yoCdg3dpQNPHzaofocawnFn7Uzh8mjgjHHA5RMw
289	payment	59	59	59	288	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtsVpLNTxtXSb3SZktetKjzNrar2YZnSHSjQ3A8RXFJaDRRTooz
290	payment	59	59	59	289	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JusE3QMSTsknD5PmsR4Nz1Gy7He2XGzjxLj8D6EScjwFPqR9L72
291	payment	59	59	59	290	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuXFU1HGPeFdzd6Z1ZzZpycMUhKEWU8n6eXi17rroUHtZ3bEjgb
292	payment	59	59	59	291	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtniu6PFq5dtBWSY7qe3ac4BgiK2gsELw1nYPqN8RMVwQRKBLPe
293	payment	59	59	59	292	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JujHcVAK9d2EbmgjAsGV6owpSdHD3boQCE9yLoYAAw5uXebGfjo
294	payment	59	59	59	293	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JthENsZMzg3dC1hP9tVMkoUNzx7ritGqf1YtbBZEUiMcuwCDsbb
295	payment	59	59	59	294	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtZ2SbUxqVtACLSwLTcr2csMMQRYPcujB6eL59ERBxRrAgyakiJ
296	payment	59	59	59	295	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv5u8AC7PQ8Fn916D9TV9jRYGZiZZkvKwfuwNoprRXwA3xd94ai
297	payment	59	59	59	296	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju1Y1vboe2qvHZCVPFZ2VhigrqZu3VMvgGvRtPFq24HjaFT14dt
298	payment	59	59	59	297	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JttxXPUtZkRc6hTaqhTSbf84wvXWj4hfuaQNpQ3wyxpb5vaqxqp
299	payment	59	59	59	298	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuQXipRWCnHy6meJbmR2nRLUt1UMScCpy5qkoszvVuadtDxAmKc
300	payment	59	59	59	299	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv2ciYK4ae1i2ARsWMJTAMpXCf7HXzQvP2rM3qJZuw5oHN12uvQ
301	payment	59	59	59	300	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtXr4MvuBCuXkt7mqvzSM4Qv62uooVai7XqfCxCTT6neUsvfomx
302	payment	59	59	59	301	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvMf6Ur9wWQ7WvFfzW7SXENi7vfxR5N78RgLUgkcrytq3eCNyqR
303	payment	59	59	59	302	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju4a1YYqvgNgbJfVTQiih6U3bqFSVtWxASv12zPgJFKnGvX719c
304	payment	59	59	59	303	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv9mGCHr28B1tTxsH3qZRxbuXA9UUSnefhDvL9FA1mwRTHJLwdV
305	payment	59	59	59	304	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JufSUi7YgQBcG37Zq23NHBfWSRNhzNWV1gY9wjqDPecvUkuXZD3
306	payment	59	59	59	305	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv7NJNTD5bwVpyDEahb7FWF5SAuJ7wS5bKfk5zr1nRNhwSw3HtM
307	payment	59	59	59	306	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtwJoLMWgUpAndMzNb1LJQe7x8aRk7ztv6LUXefq7rLcjJEiuSG
308	payment	59	59	59	307	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuUuPFpe2UA2gTsYERKkVGEoDg6pYkM4y2FnLHKAMbNpus2TCaV
309	payment	59	59	59	308	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtrX7daoKx4KPTHTFno3yNwEsbJsmcmsonvXHpT9Kvq2NBCnXWh
310	payment	59	59	59	309	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtekRLXNsMspXcCCs9e4KY8qcdMRzARTpuLymzoiXGTJbgk5ZKo
311	payment	59	59	59	310	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuLSLPUy6iwY9YUYhWKA3dPRfJ4awZkffBnXJXZUgU7NuPUQhb2
312	payment	59	59	59	311	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JudMqC5s3LvUVvmYKjGgc4Etr6viUQVmztevHapJuq3Fe3b2S3o
313	payment	59	59	59	312	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvDoy48y3kUy8rbU184QmKrKgB3CYAhBZeS3rRmAirtzAZKf2jr
314	payment	59	59	59	313	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv9g1s4zeVWUsAZFdyoTUR9e4ADQ7toELVY5gRdoVRaFgGregDZ
315	payment	59	59	59	314	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtWzJgQgipjFE62zykhcZfYCbryzW5A1fCbggWi8QKHdygFLS9N
316	payment	59	59	59	315	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuhXCYHxY2oxNq9Gz7Ez5gwt7kBNzaYf2YasaGTS5co4uQztR23
317	payment	59	59	59	316	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtbThunfT6i9SbT4Z6WF8qRTfa69A9kLARuSkokbrfnZu9vyNDx
318	payment	59	59	59	317	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv2CxHuyQ3A1PKHVGk7Rz7t8s4eP3LNetTmvte1m8iMDRPoo4bf
319	payment	59	59	59	318	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuuuzpEMTFmk4me4nWR66afdN3Y6KwkMCL7fcPbBMDHgijE1BmA
320	payment	59	59	59	319	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju9g4NcDNHMuCsEMvAW8yYHCG9tHbwsM7pL4eACch1xWxe4pEvF
321	payment	59	59	59	320	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuT2VMkzcFfK7LYF1ta6k4Cbiq91Au7gvKTXTr1WnAxbKyommFC
322	payment	59	59	59	321	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtz59XL6vm3YrKoc5FLX4JE6jaEmXvipTBXajtRS1H85fmVgjqD
323	payment	59	59	59	322	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvBwSKjoHtJ8jVJzD6RtRRtoRg5XAuyKGA2vuWiDo2fzsSa1R96
324	payment	59	59	59	323	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuEChR8t4SGGJs5TjSLBtKa5dooqbBr86evoZQo6GC7CXwkyFEf
325	payment	59	59	59	324	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juu7uZBHRZuq49f5wK3wPJ9CWSmV9YdFAsjPxi5XAxuRBh9eV1V
326	payment	59	59	59	325	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvFyaQj3nW5BhA6z5EfPRibhVQyd5rtyMBnTz1vTv7rKV5fYzwA
327	payment	59	59	59	326	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuPnahArXgpBLD6oUZ3aMc23575aWBQdHxrb9ic734beRymLimo
328	payment	59	59	59	327	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv14F9hcQcbPcFm8NCsJ8ZFvTHNgCXUQXUXEu9qxxJMAP88b2Wi
329	payment	59	59	59	328	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juoqim3aj3igS4jeRaJPTTfKsVdw94Dzzior1gCpSH3LdEo7noQ
330	payment	59	59	59	329	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuDpKQ4KyJARLNTDu9mFkLccbQKi9SpDLwtrXdM5ToMxKhdgpqY
331	payment	59	59	59	330	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtz4VC22CH8w8uBYQNCuFAJUET1wdsPZdZYWKowzYGPqGfKEC6Y
332	payment	59	59	59	331	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvJ9Ve8Pi55bkADcAT2kWjvhfbdT9x2X5jK1XWD68muoYBsKYUr
333	payment	59	59	59	332	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuP3TN5yG45m5mja9BU2csyGEegar2nG5EMjGEHF9oxEU3iFgbC
334	payment	59	59	59	333	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvHqHaTaAQew9B23JoW1m1vtPaUA2qTstsTjdkXPjSX9cAQ4jeo
335	payment	59	59	59	334	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuzH7JrRavsXhsBLYwJJZEMjXHGwnXk2QCBv6Ztnpi3pT3CAZzi
336	payment	59	59	59	335	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtpYqpk4NJfwrb9WMDsXhwLgf6j7r2psHRDwF7TajNBBapkwTDC
337	payment	59	59	59	336	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtdMyXCJCsRMqHabhxEFb8ghdWogwXRv6pDsRnLKdrmbniwNb54
338	payment	59	59	59	337	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtmc1Fm34KJtdkhu12ovfzJH2LWAjqtEKgK9R4WuAdkQ7NS7LRc
339	payment	59	59	59	338	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvRDDCGBFKNh9yGxfcJ9YQdX1hMoS1XJoh3TeWYECXgLWSaPSkR
340	payment	59	59	59	339	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juv2a4coTJnkX7rxMAKCCWP3pNZNxXeXuLJdsXf6t6dXdbCMDLR
341	payment	59	59	59	340	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuL2htqdqqt69mHaFu2QfKNkTyZx93iTagnyj2KuuYKcdp5m5aC
342	payment	59	59	59	341	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtheCssC8Xr8XMJRjVf5H7VRTs4ixt2vZWWGksc7g6639QTDM3q
343	payment	59	59	59	342	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JurvNjYeCftzE5ffsX4AyjMJ83wKHLenTdaPGhL8q4FhNigehjp
344	payment	59	59	59	343	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtfwUfmeLeAQXqrfDPz9JPpamn7YrvPw3yJ8koPbtVxcKjSUw9b
345	payment	59	59	59	344	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuKv8AdQfdPuQbt5aT6ayEdcso7JDUKcyXLdkSRH6MpQxLu4B2v
346	payment	59	59	59	345	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuHUceJZUBbgDi7HsVpYXFXsnGoPe9y1dvo7ZyfBsBAPD5sBETD
347	payment	59	59	59	346	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuZP6mED7kDjVMfsb1GAw2pomKSaCvAt3S3WSnNRnM8S3GdKfar
348	payment	59	59	59	347	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtmWyfh4gwwmjwGuW1TRyRM2VeME28fuJvGRKAZrD7DQ9p9BR14
349	payment	59	59	59	348	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvNfQbNUuxm3qijoJCJiKzNZmNfXtsfXZrqfpn6cvgiBSpPX3Ms
350	payment	59	59	59	349	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juaf4ogRzoFRHNLEDrTeEtbFdRpo8X216odNfGGJr9dLK3rVDuU
351	payment	59	59	59	350	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JudrQXWmYFbsPCSaLTSFQyxpo7PDAzTaafRiQq8QPsjxauHnm3o
352	payment	59	59	59	351	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvCFgGEKdP5svoKTik84mjHcty1Y1aZuj1kmjbmspFx176D3y7C
353	payment	59	59	59	352	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JttBmTopJWmiqoLxLUNnu9fBKZAdMSAErVM6tZNEzJpRWcmS2sQ
354	payment	59	59	59	353	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju8CK3y2jwVnpjDLrUJZoJcXnaVqZqRcoaiD53ouk3HHDshLSJh
355	payment	59	59	59	354	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtyecLmLcYcScbefCaRSUSBngq4e7CQ29LAYUM7rVnhRVYKmLDc
356	payment	59	59	59	355	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtpeJNWVgqLXkRiUchmCZb91zFyNe7WnQoPi5YWq8oTb4eUjFGD
357	payment	59	59	59	356	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv1SLZdnaeHow9T23VtupWGPaKafwZiSGsx6ncBdbptKvr9CeUA
358	payment	59	59	59	357	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuCewbvErHc3gm63131gGLoJbMJgvF5RkVi2w1E1QDpLnAjV7fe
359	payment	59	59	59	358	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvHZVaQFYdkSQzUvvdZKsiVzutYw7qx4VptRYvLgF6skWTFsQXS
360	payment	59	59	59	359	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JurQuWKatCqHES8Tqgr1yqtsoC56NFUVg1QCEdnovZ5d1pb6DjB
361	payment	59	59	59	360	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuTEZmSYGYmnSfm8AGVZSoSJ3YSsiCezEFZVEkbKgjkBUqhLCdU
362	payment	59	59	59	361	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv8pjLCHumXGY4nT5EAceETZZKpesM1tARXBXiofEYoXHdwZ8GY
363	payment	59	59	59	362	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JutP1WTfXZgEANgWqPr2mWrmXdqrskR3hEjVuaSq9LzqRuGpqXy
364	payment	59	59	59	363	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvJxWYFTdFvpB9GqZFAgLKjtroiWBG81ojSBSopKzuJxgNH6kMd
365	payment	59	59	59	364	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JucAZBrTzaGzx37hqeLUo8N8f9q14i7nsjgycde8R82Qxs4NcQv
366	payment	59	59	59	365	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JugobRHQSkgHX7ByRp1BNkDMkPLpkjxEXCU19PE2CwFHM1jmoTx
367	payment	59	59	59	366	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtrmwuHKt5BBqLmRu7EUPa37mA2sWWyRacXk3vyrJmyid48Ao2e
368	payment	59	59	59	367	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtkvyKMSgRTLVKtewvfMcYBHPnEyDw77r9KxkFzZyx1AveYbhx7
369	payment	59	59	59	368	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtjnrcuMMvZPMLsBVGPBER2JckVZGY15eqqvax4PJ2ArzJn18JT
370	payment	59	59	59	369	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtqqG1JEWSPSunGJksHrY9gZevhrdsFwuFMF8yqBi6aiqqnFLdg
371	payment	59	59	59	370	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JupKsJrX4VVoTi11atTJBrSD4pmAEZWtXAEhbyAD8EmNDidgMNs
372	payment	59	59	59	371	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuRXdzDVJ8Xpyq1YcS96a1o8cskPVUqWNGwQoZwTUc4enTXsHN5
373	payment	59	59	59	372	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtqsMtB3kKQquWz219ysmDhciEydTFDGoDXPnWnq3BYQoLrSvhu
374	payment	59	59	59	373	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju7dizgsUAetxxmnfnhrx13AWKTygqTQVWQ2UBdjrws1a6Hej2m
375	payment	59	59	59	374	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuApUc3bUSU6di4tHr87bLqKyAThA6uMy6dMTipWCcUjFWzd6ya
376	payment	59	59	59	375	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JusSziJVEzJ65fKnLUWTYyZkwNCF1TrNzDVjKwibwZcwVTX8e9U
377	payment	59	59	59	376	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuNc4EuoRU64nx5gejbPmHNzHB2NqomukbiYSTRMavo2FHaqpGD
378	payment	59	59	59	377	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtfy847RGdNHBmwj4jt54UvyExij2z9ykNVjPxn7tietG8kGfup
379	payment	59	59	59	378	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jux7iXgvYc8fBEfvCn76nex58JDyUPTMeUPZPhpJS8Uj1jdsdYv
380	payment	59	59	59	379	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuFEUa6wV6L4yTqGEnG74i23jupbKBgVQU3va9tfzPGtvAVevck
381	payment	59	59	59	380	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju9eqVAVza4FeBfszGfNkYqRzzkSj2ckst5B4anYpPX5p9nD7hF
382	payment	59	59	59	381	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtnYQ8h4XfP48nLg7r8DutCvYtfpRp5dB2BCSXUgFLSYAZmtFux
383	payment	59	59	59	382	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtgMsdBr1m4Vemr8dYKSC87BWWjd52PV6Ze6skskXJvY71tjLK9
384	payment	59	59	59	383	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuYgbpUU6rCqvEEjTbqnDZhdE94JGtk8rf6CHmQzp9gucbLP2zU
385	payment	59	59	59	384	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtfkpyFN5LVciTaaaihFtoTyxv33JESsUtiRvuofQMbKxJAVYC6
386	payment	59	59	59	385	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvR3WLzZzyPwcoSrtLxAKTj8WcYAe9tPUKEw2KWE2PkWdu9KxPW
387	payment	59	59	59	386	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuKSyRh7NuhMa4CtsqSyJf1ArB9FTu8bUzZAomcwn5KVp9Geyqr
388	payment	59	59	59	387	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv1ZP9PYTVoCTte947YKYEBvHHHnBaTk3L8gm9FTVHqxQT8UHRu
389	payment	59	59	59	388	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuAVNcSfojcjrwe5hzAUqbk6s8iJSaLd58UaoP2T6f61u1U3V85
390	payment	59	59	59	389	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtip3WZdHSosQkNdHPAAehwrNCd2iWcvE3uQeScfEfYCtqsfNdM
391	payment	59	59	59	390	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JttuKpQyL6NcvCa9GxoKwjEWmGQ3apGZJKVCMFs2BEvBnYj8xLF
392	payment	59	59	59	391	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuuvjsFoF7FGx2edp1WvqRJdHTCJwxjEQmpNhCrVRwQ9cSzjEge
393	payment	59	59	59	392	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvMwMC7hx5xLxbHF6ZSrf8ZN6Z6j51pPSH6cND5wYYVf415RT3G
394	payment	59	59	59	393	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuoV7R2smhwetpBz2voDPKCpstq5oCd6bfdtY9YKXVt2S6corMh
395	payment	59	59	59	394	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JugJVv6gFq7Xo2AEnd3krpFLwfAsbPjhRJ8q8gUK5J4uFcCsHcw
396	payment	59	59	59	395	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuXQee7KT9PTiaoXwWfac2SJ7usNP6956bTvf1V69D6ihpuh6V2
397	payment	59	59	59	396	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvD6CZdSjgap1dMvfn5nNKTUWpCTV9n4UW3ZkvQq3GNjDSagiPH
398	payment	59	59	59	397	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuLhX4E9x6WqY4VW8KTm1SXSBNXYCTLc3BUQtvwjmjQevZtYFkF
399	payment	59	59	59	398	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv36QzQUXcgzmF8ruFoBPGk9Zcrw26kVYBY5nix9Wx9UsQaDVhq
400	payment	59	59	59	399	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvPczsVs11uAegaBzB8PkZGNbLYycNgBJnneodnEhYXnkv5UQHa
401	payment	59	59	59	400	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuDZpUQY6FS1pP3NXKwbQ4gEB2UaHeriuvDe8us8mMJynB51dhk
402	payment	59	59	59	401	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuXWCyxZkaSiaGzMXqRGfk2qQ9bP9ubqGR3xrfxv6G5487nWasz
403	payment	59	59	59	402	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvLaGDC4tRpAVGdZAgHKxz87Skjx3XXaScjHauahr2yxuZQhNY2
404	payment	59	59	59	403	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuBnfkLFGs874Dexguj6XhSxqwq6Z3DnDkZAny6vvdxy7jimY1q
405	payment	59	59	59	404	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtrJGw3u3w2P5erzGegFhEETVXjDFsX7WYc65rXojZuMdwmDvvG
406	payment	59	59	59	405	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju3Yt6fwbf73DfWvy7urqt4BZBB5mKwGo2TGkZQCSvByJXGfbDo
407	payment	59	59	59	406	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtjWi2UWbMV8cLUwqVx28F3GS8dcuY2fVufy66S9JQwuSppNuu9
408	payment	59	59	59	407	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju13ikwQU4fMJ6R9AHhKWvzaie98HJUag3WzQKnaiEboaWuxfHN
409	payment	59	59	59	408	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JumYtfFpZHZ7vwP7zbJFNRZ76BcYKYYn9L9gHFre3VXKgsuV4uQ
410	payment	59	59	59	409	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtobk2sFWQWe2LkUPEMsCrNDqEgxeu5mkVfug4Ba2EygSqmDHsj
411	payment	59	59	59	410	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuZLSuDpcSDhZdAFFDYqk7XQMqt7N2rHvXWXjgZaP9yNvYc3H9v
412	payment	59	59	59	411	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju8AAAsiDk885rrUtNqhMvDeCwFdnMfHbXLbH5XDjAJcdzYLDd7
413	payment	59	59	59	412	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtjBBgZFUPqaVaF5emJczrvxTHk7tfsQAV7Q8JdwRcFoAajU4vK
414	payment	59	59	59	413	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jufuch8Q5MrUjAGwZ2hp7SCN3WrWG3M4CtzR73WJyrV2omMVU1M
415	payment	59	59	59	414	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv2iBCvRiwa4QnErTfrQ8dn92xTTsJ26r27QdYz8vMocBFGe7GL
416	payment	59	59	59	415	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv7SCQ3VAwvzkifBzBS37tJsoG6idbqU2AsMr7wc7PCjDesu7oP
417	payment	59	59	59	416	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuWQd8J3HzX7FcqVYcxKcxkbHeFRhJqDyw7ivV5oDRehwom51m3
418	payment	59	59	59	417	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju364Lmya3yQ6Z4HV6AsF4Tr99Zgy4Wt586tt1PAGACnEm5u5K4
419	payment	59	59	59	418	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jti8BrLo6HPkSquDshYiz7yvFvAE7wYiJFZrCjhZSRx4nmNEpbx
420	payment	59	59	59	419	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvLokrqWynwBUcr1tGmmBh44ddT37Zr3HeMdC62cWk5DFSa6W1b
421	payment	59	59	59	420	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuGmZ2ajSuQQRdeDZsYdQJ9aSLoswKeEcAzwA7LjoQcGgQLLdLv
422	payment	59	59	59	421	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuE13UD7ntxNU8VrsAK1hYN1ciiRHAZBkMhP9u5e4LuPgSvVug8
423	payment	59	59	59	422	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuQJricZuQTEtmshZsnGpS1ksDdwFhQGjyC7iGGwyaQtH6AKv1G
424	payment	59	59	59	423	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju2VJMqpHaKXpkpMqJShvPESXrmGhgHXQz5FUtZapxHDXUA4okC
425	payment	59	59	59	424	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvD9yWrwEKEKXYypScmtWZMedRND6fN4mKBcprDuc11THKLnBYb
\.


--
-- Data for Name: voting_for; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.voting_for (id, value) FROM stdin;
1	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x
\.


--
-- Data for Name: zkapp_account_permissions_precondition; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.zkapp_account_permissions_precondition (id, edit_state, send, receive, access, set_delegate, set_permissions, set_verification_key, set_zkapp_uri, edit_action_state, set_token_symbol, increment_nonce, set_voting_for, set_timing) FROM stdin;
\.


--
-- Data for Name: zkapp_account_precondition; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.zkapp_account_precondition (id, balance_id, nonce_id, receipt_chain_hash, delegate_id, state_id, action_state_id, proved_state, is_new, permissions_id) FROM stdin;
\.


--
-- Data for Name: zkapp_account_update; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.zkapp_account_update (id, body_id) FROM stdin;
\.


--
-- Data for Name: zkapp_account_update_body; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.zkapp_account_update_body (id, account_identifier_id, update_id, balance_change, increment_nonce, events_id, actions_id, call_data_id, call_depth, zkapp_network_precondition_id, zkapp_account_precondition_id, zkapp_valid_while_precondition_id, use_full_commitment, implicit_account_creation_fee, may_use_token, authorization_kind, verification_key_hash_id) FROM stdin;
\.


--
-- Data for Name: zkapp_account_update_failures; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.zkapp_account_update_failures (id, index, failures) FROM stdin;
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
\.


--
-- Data for Name: zkapp_epoch_data; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.zkapp_epoch_data (id, epoch_ledger_id, epoch_seed, start_checkpoint, lock_checkpoint, epoch_length_id) FROM stdin;
\.


--
-- Data for Name: zkapp_epoch_ledger; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.zkapp_epoch_ledger (id, hash_id, total_currency_id) FROM stdin;
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
\.


--
-- Data for Name: zkapp_field; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.zkapp_field (id, field) FROM stdin;
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
\.


--
-- Data for Name: zkapp_nonce_bounds; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.zkapp_nonce_bounds (id, nonce_lower_bound, nonce_upper_bound) FROM stdin;
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
\.


--
-- Data for Name: zkapp_verification_keys; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.zkapp_verification_keys (id, verification_key, hash_id) FROM stdin;
\.


--
-- Name: account_identifiers_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.account_identifiers_id_seq', 243, true);


--
-- Name: blocks_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.blocks_id_seq', 46, true);


--
-- Name: epoch_data_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.epoch_data_id_seq', 48, true);


--
-- Name: internal_commands_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.internal_commands_id_seq', 22, true);


--
-- Name: protocol_versions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.protocol_versions_id_seq', 1, true);


--
-- Name: public_keys_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.public_keys_id_seq', 244, true);


--
-- Name: snarked_ledger_hashes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.snarked_ledger_hashes_id_seq', 2, true);


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

SELECT pg_catalog.setval('public.user_commands_id_seq', 425, true);


--
-- Name: voting_for_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.voting_for_id_seq', 1, true);


--
-- Name: zkapp_account_permissions_precondition_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_account_permissions_precondition_id_seq', 1, false);


--
-- Name: zkapp_account_precondition_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_account_precondition_id_seq', 1, false);


--
-- Name: zkapp_account_update_body_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_account_update_body_id_seq', 1, false);


--
-- Name: zkapp_account_update_failures_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_account_update_failures_id_seq', 1, false);


--
-- Name: zkapp_account_update_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_account_update_id_seq', 1, false);


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

SELECT pg_catalog.setval('public.zkapp_commands_id_seq', 1, false);


--
-- Name: zkapp_epoch_data_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_epoch_data_id_seq', 1, false);


--
-- Name: zkapp_epoch_ledger_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_epoch_ledger_id_seq', 1, false);


--
-- Name: zkapp_events_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_events_id_seq', 1, false);


--
-- Name: zkapp_fee_payer_body_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_fee_payer_body_id_seq', 1, false);


--
-- Name: zkapp_field_array_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_field_array_id_seq', 1, false);


--
-- Name: zkapp_field_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_field_id_seq', 1, false);


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

SELECT pg_catalog.setval('public.zkapp_network_precondition_id_seq', 1, false);


--
-- Name: zkapp_nonce_bounds_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_nonce_bounds_id_seq', 1, false);


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

SELECT pg_catalog.setval('public.zkapp_states_nullable_id_seq', 1, false);


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

SELECT pg_catalog.setval('public.zkapp_updates_id_seq', 1, false);


--
-- Name: zkapp_uris_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_uris_id_seq', 1, false);


--
-- Name: zkapp_verification_key_hashes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_verification_key_hashes_id_seq', 1, false);


--
-- Name: zkapp_verification_keys_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_verification_keys_id_seq', 1, false);


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
-- Name: zkapp_account_permissions_precondition zkapp_account_permissions_precondition_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_account_permissions_precondition
    ADD CONSTRAINT zkapp_account_permissions_precondition_pkey PRIMARY KEY (id);


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
-- Name: zkapp_account_precondition zkapp_account_precondition_permissions_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zkapp_account_precondition
    ADD CONSTRAINT zkapp_account_precondition_permissions_id_fkey FOREIGN KEY (permissions_id) REFERENCES public.zkapp_account_permissions_precondition(id);


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

