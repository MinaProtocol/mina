--
-- PostgreSQL database dump
--

-- Dumped from database version 14.14
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
6	8	1
7	9	1
8	10	1
9	11	1
10	12	1
11	13	1
12	14	1
13	15	1
14	16	1
15	17	1
16	18	1
17	19	1
18	21	1
19	22	1
20	23	1
21	24	1
22	25	1
23	26	1
24	27	1
25	28	1
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
45	48	1
46	49	1
47	50	1
48	51	1
49	52	1
50	53	1
51	54	1
52	55	1
53	56	1
54	57	1
55	58	1
56	59	1
57	60	1
58	61	1
59	62	1
60	63	1
61	64	1
62	65	1
63	66	1
64	67	1
65	68	1
66	69	1
67	70	1
68	71	1
69	72	1
70	73	1
71	74	1
72	75	1
73	76	1
74	77	1
75	78	1
76	79	1
77	7	1
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
162	20	1
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
188	1	1
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
2	1	5	1	65500000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	7	1	5	1	\N
12	1	6	1	123	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	8	1	6	1	\N
78	1	7	1	292	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	9	1	7	1	\N
121	1	8	1	104	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	10	1	8	1	\N
176	1	9	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	11	1	9	1	\N
236	1	10	1	488	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	12	1	10	1	\N
226	1	11	1	469	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	13	1	11	1	\N
19	1	12	1	242	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	14	1	12	1	\N
128	1	13	1	135	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	15	1	13	1	\N
94	1	14	1	196	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	16	1	14	1	\N
153	1	15	1	79	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	17	1	15	1	\N
166	1	16	1	206	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	18	1	16	1	\N
4	1	17	1	11550000000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	20	1	17	1	\N
137	1	18	1	340	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	21	1	18	1	\N
105	1	19	1	382	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	22	1	19	1	\N
70	1	20	1	488	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	23	1	20	1	\N
27	1	21	1	135	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	24	1	21	1	\N
46	1	22	1	126	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	25	1	22	1	\N
43	1	23	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	26	1	23	1	\N
117	1	24	1	278	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	27	1	24	1	\N
204	1	25	1	46	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	25	1	\N
187	1	26	1	104	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	29	1	26	1	\N
7	1	27	1	0	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	30	1	27	1	\N
72	1	28	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	31	1	28	1	\N
216	1	29	1	271	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	32	1	29	1	\N
210	1	30	1	315	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	33	1	30	1	\N
79	1	31	1	162	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	34	1	31	1	\N
167	1	32	1	86	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	35	1	32	1	\N
181	1	33	1	409	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	36	1	33	1	\N
156	1	34	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	37	1	34	1	\N
96	1	35	1	57	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	38	1	35	1	\N
191	1	36	1	204	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	39	1	36	1	\N
132	1	37	1	262	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	40	1	37	1	\N
111	1	38	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	41	1	38	1	\N
171	1	39	1	156	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	42	1	39	1	\N
64	1	40	1	417	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	43	1	40	1	\N
68	1	41	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	44	1	41	1	\N
51	1	42	1	85	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	45	1	42	1	\N
227	1	43	1	103	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	46	1	43	1	\N
141	1	44	1	67	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	47	1	44	1	\N
42	1	45	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	48	1	45	1	\N
133	1	46	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	49	1	46	1	\N
82	1	47	1	198	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	50	1	47	1	\N
95	1	48	1	489	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	51	1	48	1	\N
188	1	49	1	298	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	52	1	49	1	\N
30	1	50	1	36	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	53	1	50	1	\N
90	1	51	1	334	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	54	1	51	1	\N
14	1	52	1	344	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	55	1	52	1	\N
35	1	53	1	451	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	56	1	53	1	\N
85	1	54	1	371	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	54	1	\N
127	1	55	1	234	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	58	1	55	1	\N
222	1	56	1	345	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	59	1	56	1	\N
76	1	57	1	282	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	60	1	57	1	\N
231	1	58	1	339	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	61	1	58	1	\N
15	1	59	1	215	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	62	1	59	1	\N
220	1	60	1	193	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	63	1	60	1	\N
16	1	61	1	60	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	64	1	61	1	\N
1	1	62	1	5000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	65	1	62	1	\N
58	1	63	1	350	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	66	1	63	1	\N
146	1	64	1	223	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	67	1	64	1	\N
62	1	65	1	449	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	68	1	65	1	\N
185	1	66	1	142	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	69	1	66	1	\N
151	1	67	1	300	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	70	1	67	1	\N
165	1	68	1	256	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	71	1	68	1	\N
103	1	69	1	125	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	72	1	69	1	\N
41	1	70	1	236	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	73	1	70	1	\N
239	1	71	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	74	1	71	1	\N
110	1	72	1	179	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	75	1	72	1	\N
13	1	73	1	194	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	76	1	73	1	\N
26	1	74	1	185	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	77	1	74	1	\N
98	1	75	1	342	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	78	1	75	1	\N
215	1	76	1	157	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	79	1	76	1	\N
3	1	77	1	500000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	7	1	77	1	\N
91	1	78	1	135	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	80	1	78	1	\N
159	1	79	1	456	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	81	1	79	1	\N
6	1	80	1	11550000000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	30	1	80	1	\N
208	1	81	1	336	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	83	1	81	1	\N
207	1	82	1	280	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	84	1	82	1	\N
182	1	83	1	187	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	85	1	83	1	\N
157	1	84	1	387	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	86	1	84	1	\N
33	1	85	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	87	1	85	1	\N
201	1	86	1	151	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	88	1	86	1	\N
9	1	87	1	356	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	89	1	87	1	\N
234	1	88	1	24	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	90	1	88	1	\N
40	1	89	1	152	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	91	1	89	1	\N
18	1	90	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	92	1	90	1	\N
229	1	91	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	93	1	91	1	\N
20	1	92	1	186	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	94	1	92	1	\N
184	1	93	1	266	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	95	1	93	1	\N
139	1	94	1	81	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	96	1	94	1	\N
164	1	95	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	97	1	95	1	\N
199	1	96	1	379	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	98	1	96	1	\N
109	1	97	1	315	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	99	1	97	1	\N
47	1	98	1	226	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	100	1	98	1	\N
214	1	99	1	166	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	101	1	99	1	\N
112	1	100	1	302	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	102	1	100	1	\N
144	1	101	1	269	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	103	1	101	1	\N
178	1	102	1	172	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	104	1	102	1	\N
155	1	103	1	195	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	105	1	103	1	\N
38	1	104	1	243	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	106	1	104	1	\N
80	1	105	1	128	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	107	1	105	1	\N
147	1	106	1	349	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	108	1	106	1	\N
24	1	107	1	87	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	109	1	107	1	\N
126	1	108	1	424	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	110	1	108	1	\N
89	1	109	1	239	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	111	1	109	1	\N
135	1	110	1	316	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	112	1	110	1	\N
194	1	111	1	492	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	113	1	111	1	\N
190	1	112	1	294	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	114	1	112	1	\N
218	1	113	1	191	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	115	1	113	1	\N
93	1	114	1	380	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	116	1	114	1	\N
162	1	115	1	331	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	117	1	115	1	\N
221	1	116	1	459	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	118	1	116	1	\N
205	1	117	1	28	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	119	1	117	1	\N
195	1	118	1	472	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	120	1	118	1	\N
34	1	119	1	119	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	121	1	119	1	\N
213	1	120	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	122	1	120	1	\N
196	1	121	1	41	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	123	1	121	1	\N
104	1	122	1	27	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	124	1	122	1	\N
44	1	123	1	70	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	125	1	123	1	\N
52	1	124	1	337	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	126	1	124	1	\N
114	1	125	1	210	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	127	1	125	1	\N
177	1	126	1	495	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	128	1	126	1	\N
148	1	127	1	144	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	129	1	127	1	\N
100	1	128	1	148	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	130	1	128	1	\N
206	1	129	1	376	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	131	1	129	1	\N
28	1	130	1	329	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	130	1	\N
173	1	131	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	133	1	131	1	\N
130	1	132	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	134	1	132	1	\N
39	1	133	1	181	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	135	1	133	1	\N
212	1	134	1	200	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	136	1	134	1	\N
116	1	135	1	159	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	137	1	135	1	\N
48	1	136	1	319	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	138	1	136	1	\N
101	1	137	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	139	1	137	1	\N
203	1	138	1	365	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	140	1	138	1	\N
50	1	139	1	342	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	141	1	139	1	\N
59	1	140	1	237	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	142	1	140	1	\N
150	1	141	1	427	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	143	1	141	1	\N
180	1	142	1	315	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	144	1	142	1	\N
142	1	143	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	145	1	143	1	\N
23	1	144	1	378	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	146	1	144	1	\N
122	1	145	1	420	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	147	1	145	1	\N
115	1	146	1	411	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	148	1	146	1	\N
75	1	147	1	172	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	149	1	147	1	\N
77	1	148	1	309	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	150	1	148	1	\N
152	1	149	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	151	1	149	1	\N
120	1	150	1	154	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	152	1	150	1	\N
118	1	151	1	153	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	153	1	151	1	\N
37	1	152	1	47	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	154	1	152	1	\N
168	1	153	1	87	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	155	1	153	1	\N
149	1	154	1	398	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	156	1	154	1	\N
29	1	155	1	452	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	157	1	155	1	\N
8	1	156	1	283	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	158	1	156	1	\N
88	1	157	1	291	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	159	1	157	1	\N
233	1	158	1	367	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	160	1	158	1	\N
83	1	159	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	161	1	159	1	\N
154	1	160	1	311	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	162	1	160	1	\N
175	1	161	1	258	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	163	1	161	1	\N
5	1	162	1	0	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	20	1	162	1	\N
69	1	163	1	323	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	164	1	163	1	\N
63	1	164	1	405	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	165	1	164	1	\N
189	1	165	1	32	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	166	1	165	1	\N
92	1	166	1	130	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	167	1	166	1	\N
140	1	167	1	234	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	168	1	167	1	\N
17	1	168	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	169	1	168	1	\N
87	1	169	1	481	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	170	1	169	1	\N
183	1	170	1	240	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	171	1	170	1	\N
129	1	171	1	314	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	172	1	171	1	\N
193	1	172	1	183	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	173	1	172	1	\N
174	1	173	1	486	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	174	1	173	1	\N
57	1	174	1	178	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	175	1	174	1	\N
224	1	175	1	65	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	176	1	175	1	\N
232	1	176	1	277	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	177	1	176	1	\N
119	1	177	1	433	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	178	1	177	1	\N
55	1	178	1	100	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	179	1	178	1	\N
169	1	179	1	272	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	180	1	179	1	\N
125	1	180	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	181	1	180	1	\N
45	1	181	1	212	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	182	1	181	1	\N
60	1	182	1	151	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	183	1	182	1	\N
99	1	183	1	387	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	184	1	183	1	\N
179	1	184	1	158	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	185	1	184	1	\N
49	1	185	1	440	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	186	1	185	1	\N
230	1	186	1	438	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	187	1	186	1	\N
131	1	187	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	188	1	187	1	\N
0	1	188	1	1000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	1	1	188	1	\N
186	1	189	1	290	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	189	1	189	1	\N
198	1	190	1	417	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	190	1	190	1	\N
202	1	191	1	375	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	191	1	191	1	\N
22	1	192	1	178	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	192	1	192	1	\N
102	1	193	1	59	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	193	1	193	1	\N
124	1	194	1	95	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	194	1	194	1	\N
200	1	195	1	394	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	195	1	195	1	\N
54	1	196	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	196	1	196	1	\N
225	1	197	1	256	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	197	1	197	1	\N
134	1	198	1	128	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	198	1	198	1	\N
97	1	199	1	199	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	199	1	199	1	\N
84	1	200	1	22	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	200	1	200	1	\N
161	1	201	1	276	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	201	1	201	1	\N
228	1	202	1	451	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	202	1	202	1	\N
238	1	203	1	133	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	203	1	203	1	\N
65	1	204	1	460	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	204	1	204	1	\N
219	1	205	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	205	1	205	1	\N
56	1	206	1	489	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	206	1	206	1	\N
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
5	2	162	1	720000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	20	1	162	1	\N
4	3	17	1	11549880000000000	24	2n1kA8ijqnav3ehWHVmicA5meC2fcXM9VBorzHz5ERYLT2kUCdwc	20	1	17	1	\N
7	3	27	1	847500000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	30	1	27	1	\N
3	3	77	1	492500000000	30	2n1pQfX9JYmSY5g4To55VPe5f8iAez6YaTtyW88Y6BLFvf1ETwQg	7	1	77	1	\N
4	4	17	1	11549760000000000	48	2n2P5uf5AzKeodvhz3WaAt3dtsnvHHo1ghgFyEyXxcqysLPDCDC8	20	1	17	1	\N
3	4	77	1	489750000000	41	2n22ZCyhgtU5tP3iC146FQg5LGgiiWbiDqwf8d58hZzA6G18UPD6	7	1	77	1	\N
5	4	162	1	1562750000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	20	1	162	1	\N
4	5	17	1	11549640000000000	72	2n1WfGtMvWMrsgkeWsqXd59oEAMe9ZkLw3Zyi1VwYxt995xppHLs	20	1	17	1	\N
3	5	77	1	487000000000	52	2n2DNqe7JzXKjb1948viQmKto1XPe1hTu5YR4VKQwRJa4P2ZcMVq	7	1	77	1	\N
5	5	162	1	2405500000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	20	1	162	1	\N
4	6	17	1	11549640000000000	72	2n1WfGtMvWMrsgkeWsqXd59oEAMe9ZkLw3Zyi1VwYxt995xppHLs	20	1	17	1	\N
7	6	27	1	1690250000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	30	1	27	1	\N
3	6	77	1	487000000000	52	2n2DNqe7JzXKjb1948viQmKto1XPe1hTu5YR4VKQwRJa4P2ZcMVq	7	1	77	1	\N
4	7	17	1	11549520000000000	96	2mzqexWN18PT4v1o8s3ttZUuA4DLAS6AKvt1DyohreqiXpJf7KpZ	20	1	17	1	\N
7	7	27	1	1690000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	30	1	27	1	\N
3	7	77	1	484500000000	62	2n1TJEToZaju6fjuZRvqC5UtTJZV6ibe7MzAqb5xdFjpr91NUme1	7	1	77	1	\N
4	8	17	1	11549520000000000	96	2mzqexWN18PT4v1o8s3ttZUuA4DLAS6AKvt1DyohreqiXpJf7KpZ	20	1	17	1	\N
3	8	77	1	484500000000	62	2n1TJEToZaju6fjuZRvqC5UtTJZV6ibe7MzAqb5xdFjpr91NUme1	7	1	77	1	\N
5	8	162	1	3248000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	20	1	162	1	\N
4	9	17	1	11549400000000000	120	2n1v3kgKoUjm4dtMC4tLiU8PfTzt2g8jriqSNUYgENyWh9RxfKR8	20	1	17	1	\N
3	9	77	1	481750000000	73	2n22RWE6T9QVKgP1xAEVoZxnYbAZvKDuDwyd41xwqFYsqMcvjbju	7	1	77	1	\N
5	9	162	1	3248250000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	20	1	162	1	\N
4	10	17	1	11549280000000000	144	2n1XgE7wzFX3UTPSEe3DrKuejR8ABMqbVSP9mASg4KLA4xxDDrEz	20	1	17	1	\N
3	10	77	1	479250000000	83	2mzc5P7mLidzC1sRQ59kFN3wP7ZGtHKL2p4YnEe52F7JMaipwb6i	7	1	77	1	\N
5	10	162	1	4090750000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	20	1	162	1	\N
4	11	17	1	11549160000000000	168	2mzuW22NDqJjt5YBNdneBcFxrqCu3Rfimjxn9renFMk16xo1541K	20	1	17	1	\N
3	11	77	1	476500000000	94	2n1dWRHwuPyc72oVB4zSwwdSujTggTGQ6xJSi2bdTo3BXcqMNKJB	7	1	77	1	\N
5	11	162	1	4933500000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	20	1	162	1	\N
4	12	17	1	11549160000000000	168	2mzuW22NDqJjt5YBNdneBcFxrqCu3Rfimjxn9renFMk16xo1541K	20	1	17	1	\N
7	12	27	1	2532750000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	30	1	27	1	\N
3	12	77	1	476500000000	94	2n1dWRHwuPyc72oVB4zSwwdSujTggTGQ6xJSi2bdTo3BXcqMNKJB	7	1	77	1	\N
4	13	17	1	11549040000000000	192	2n2Fn1qgsBvFL95mxfsoXL361TE1iossj1NQKv3GRSRLeQazruFM	20	1	17	1	\N
7	13	27	1	3375500000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	30	1	27	1	\N
3	13	77	1	473750000000	105	2n11bmvydXqi9g3f8mdBmBj7MAnyHiMroFRvYvzX2Lj3RkSYMuMB	7	1	77	1	\N
4	14	17	1	11548920000000000	216	2n2FVhq2miZ9aLJE8pZwQqWTLNGd3Xm87g5G49x7Nm6Dy17cSRNs	20	1	17	1	\N
7	14	27	1	4218000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	30	1	27	1	\N
3	14	77	1	471250000000	115	2n2D9SXJPefJ5G9shLEsUfdEGRD3XFi7Ds8ST9YvGsJN2TEeE7gh	7	1	77	1	\N
4	15	17	1	11548920000000000	216	2n2FVhq2miZ9aLJE8pZwQqWTLNGd3Xm87g5G49x7Nm6Dy17cSRNs	20	1	17	1	\N
3	15	77	1	471250000000	115	2n2D9SXJPefJ5G9shLEsUfdEGRD3XFi7Ds8ST9YvGsJN2TEeE7gh	7	1	77	1	\N
5	15	162	1	4933250000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	20	1	162	1	\N
4	16	17	1	11548800000000000	240	2n1BxBR8JDHXxPUeYg2fr2jpTLyjEk5KtAwNkWrwjV7yhiB1A2CS	20	1	17	1	\N
1	16	62	1	5064000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	65	1	62	1	\N
3	16	77	1	463250000000	147	2mzv43dTZUbWr97PhKsckmwehH6AfABtamRTSV2Ax5cPcG1B3DY1	7	1	77	1	\N
5	16	162	1	4938686000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	20	1	162	1	\N
4	17	17	1	11548680000000000	264	2n2QQbjMy3fBkCueAaX6PWco5kU6HhyYaJzSW2Fns4e3QkeE4iAo	20	1	17	1	\N
7	17	27	1	5060750000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	30	1	27	1	\N
3	17	77	1	460500000000	158	2n2RZNfr5fFxb9VjfNBeLcdGUGDZqFUjMrZaGRsiMBTZPUBwZtVT	7	1	77	1	\N
4	19	17	1	11548440000000000	312	2n1mYbFXddiZWo4NsALi2SwF92XKhsqxisPobKNJKeZKyELwPTq2	20	1	17	1	\N
1	19	62	1	5111000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	65	1	62	1	\N
3	19	77	1	452500000000	190	2n2CzhvfDwYQCuJ4p3o7QdgWcBZYdJDT8P9VmdQxoxWtsyP73sLi	7	1	77	1	\N
5	19	162	1	5781389000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	20	1	162	1	\N
4	21	17	1	11548200000000000	360	2mziEXQJTk6VQZy23VkHKja7KSTu6Jn9ESZmnFjVSKSYQA7EjxyF	20	1	17	1	\N
1	21	62	1	5128000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	65	1	62	1	\N
3	21	77	1	441750000000	233	2n2NAERHMm6KSUGdj4ouBgLF1RSbL2gJZHB8z56i8kbqTF12WH9h	7	1	77	1	\N
5	21	162	1	6629381000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	20	1	162	1	\N
4	23	17	1	11547960000000000	408	2n1fsfhoih9ipsHxGizW6SbJPWNbYh9petUQZvNHt8gHDQyd2aFH	20	1	17	1	\N
1	23	62	1	5159000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	65	1	62	1	\N
3	23	77	1	436250000000	255	2n1TAas7vMvabxFxGn5zG8qtekM8SjYPqVhh9quFELKiXMGST2nh	7	1	77	1	\N
5	23	162	1	8314850000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	20	1	162	1	\N
4	18	17	1	11548560000000000	288	2n2BySvG3NuHSTAUYGfW48QPUhfvrYXr36sSRHZibLpV931JP41b	20	1	17	1	\N
7	18	27	1	5906000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	30	1	27	1	\N
3	18	77	1	455250000000	179	2n1aBFS2jgM4vteXF621HhgtqQ81fQgm2YECBVk2AacprcgBKMCR	7	1	77	1	\N
4	20	17	1	11548320000000000	336	2n2G2NckswaUmnr9MwEKbqkugspo44tpMtamXNPBaytmWPqg6cwa	20	1	17	1	\N
7	20	27	1	6748741000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	30	1	27	1	\N
1	20	62	1	5120000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	65	1	62	1	\N
3	20	77	1	449750000000	201	2n1abH7CJrx5y5hy2aX8zXwaR8GBfHzviahjxzggM3ZEMNZmNqtr	7	1	77	1	\N
4	22	17	1	11548080000000000	384	2mzr2KZtJ7ZbRisjfXFjTbhfSGijQYJ391VoLLq5CAQvwtKfXwGg	20	1	17	1	\N
1	22	62	1	5150000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	65	1	62	1	\N
3	22	77	1	439000000000	244	2n1J8wsSSZhf7L3i8JGidmujkwgQMaQLQaM3mLxzBZgu5S512fMg	7	1	77	1	\N
5	22	162	1	7472109000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	20	1	162	1	\N
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
22	3NKeoDePFWH75HgFteAyhnu3tQ66s94g6xssAVq3V1usT9n63ttG	21	3NL5cTVUMCSzC7e2KjERVziq1BR4yTrFdrtsZq6SFAuqab2Cgqzj	20	19	LentADH5FEESQhM28kk7OFB7emJxYimLyjY-XbdWGgA=	1	1	23	77	{5,6,5,2,7,7,7,7,7,7,7}	23166005000061388	jx99vEsVYCKSekqFCHkbvg4QG7kUJA9PpYXMUY854LhnyDah4fs	18	24	24	1	\N	1733866487000	orphaned
20	3NKaaH6A8pZJdyWotjGGd1ajvNhLf9ecDkocN821Zgc38BDrU17G	19	3NL3FZkX6nEkNCrATETbRu2F1QNwUZ1da8f2FdjBeZ1tct7VgfjJ	30	82	dl0d9yUsyCwkurV3n7QX6ehaWxU4c0Z5ph3rmM8SsQ8=	1	1	21	77	{5,6,5,7,7,7,7,7,7,7,7}	23166005000061388	jx6zbVRNJURSCVE8dunyAY3pRssFzoGiSg4KjWS8EJikqb91qhE	16	20	20	1	\N	1733865767000	canonical
18	3NLHq7dAijLq7Du7efomstTrx4RCWtgpyBH9huGou4quPcZa1kkD	17	3NL84Cya3UCVmMxNHdRF7diEZSrRZxmCZF7gYREv5Fn5GDvdDo59	30	82	aMmUESofMgqMW2Rvat_krELdhJIdqfZ63VPtzRxyUQk=	1	1	19	77	{5,6,3,7,7,7,7,7,7,7,7}	23166005000061388	jxG3SD6wvhKHAm2oMZpiHDj5vU4xhb7ukZvjs4fA4JshKoCfLfa	14	18	18	1	\N	1733865407000	canonical
6	3NLNdcEVa78jvPegH6cSpBPR8JFPW9kBYkcg9yVL1F4yScXcwr2m	4	3NKUT2PSBGFQ5YHXmvG7eXnzNvqHu5yFsmQXFE7CGo2pTvCnpWv8	30	82	570nnNDa39WsCjEgBmnjgsNUpz3b2N1rXuI4-ffZHQU=	1	1	7	77	{5,7,7,7,7,7,7,7,7,7,7}	23166005000061388	jwnvKsCURL8g6tbHfVkGkpfmM6puvqxAaMEmvdqNvi8Q9b16KQ5	5	6	6	1	\N	1733863247000	orphaned
8	3NLbx5qBCiWfYfcSjuZzcwrYRdDKQndbjUyRGPhWsFkf5i1uxc4E	5	3NLQ6yw3xcguX7xyfBMTJzY9Un5YshPVznxxEuiiLpob6YxJG8wu	20	19	wkVNpBY50MN7cECV4NVHD2Ce7torBub8O_dTkcbo_gY=	1	1	9	77	{5,1,7,7,7,7,7,7,7,7,7}	23166005000061388	jwigGcs259xtFUpXcmNfi9kvMrG4XM1DEUzzQxh67D48e5Yd9BS	6	7	7	1	\N	1733863427000	orphaned
11	3NKoK7nM58YkgY594VnM9jGeUhE4bfSyhT6dGwq8LHe8V46JsnDw	10	3NKp7moTu5cz7BZia8sdFRPa1bEFuhugcqNb8qUQ4RTAFd5t2xcZ	20	19	eyiosT4qDhSw03y-qDHsVxEqJ8koWi-Tl1wG-_Tz3ww=	1	1	12	77	{5,4,7,7,7,7,7,7,7,7,7}	23166005000061388	jwsP5QefoLxvZwrNiGbXGiDaadkXApmWKZofxQM8wM8sAkFsqkG	9	10	10	1	\N	1733863967000	orphaned
14	3NK4VgkH23nXVtmtpU6iHUq23YgEkDtP3B4C1nhEbyGKLj7tz2sf	13	3NKDwjdVwFnqeinyjmtWC69EHzfEEeC6VMRzeYAjdncZvhFkQk6M	30	82	wSc8ci1hDeDBdnGHIGWo9BNzlhT7rFJam-KIpKsuGAI=	1	1	15	77	{5,6,7,7,7,7,7,7,7,7,7}	23166005000061388	jxhTeJvJqXCejmamBzQnprwJS6qWDUdSiuvzDWwXoH7tjdCSfpe	11	12	12	1	\N	1733864327000	canonical
13	3NKDwjdVwFnqeinyjmtWC69EHzfEEeC6VMRzeYAjdncZvhFkQk6M	12	3NLAj5mc6qr1vnsSJ8EKeDHnMzst2oeKUneqWndeQn9xHKA4rcds	30	82	WuJXp8xyu53AYgLzqWy2Tmv6eG7fNfITi2aUHUxJaAQ=	1	1	14	77	{5,5,7,7,7,7,7,7,7,7,7}	23166005000061388	jx1TgRTu7xJCRWD4ZZVW8SV9w2NUSnQNyNJKfAB2zDn9XJGYtpG	10	11	11	1	\N	1733864147000	canonical
12	3NLAj5mc6qr1vnsSJ8EKeDHnMzst2oeKUneqWndeQn9xHKA4rcds	10	3NKp7moTu5cz7BZia8sdFRPa1bEFuhugcqNb8qUQ4RTAFd5t2xcZ	30	82	8dFwXcllFNrFxjweH8cSZbWFCTViTwaPqt_FPO1KUgc=	1	1	13	77	{5,4,7,7,7,7,7,7,7,7,7}	23166005000061388	jwWwZ33xuC7oVrrGx3ynMJEaT9FHGeNaGy1PsEen11tpRkAJmrq	9	10	10	1	\N	1733863967000	canonical
10	3NKp7moTu5cz7BZia8sdFRPa1bEFuhugcqNb8qUQ4RTAFd5t2xcZ	9	3NLwJUSvFYFKMtpBrQJdzHwgQnUiuwgpmew3EWwgu4YP6jEcgJhj	20	19	TeyDuDA71cepHAMzOGQyDbCi9P7Icv5uLVa4Cv7aeg0=	1	1	11	77	{5,3,7,7,7,7,7,7,7,7,7}	23166005000061388	jx3XrKHTJBjcj5Xmc9nvsZSweGBvghabV4ofhEsncJmj1HjFtay	8	9	9	1	\N	1733863787000	canonical
9	3NLwJUSvFYFKMtpBrQJdzHwgQnUiuwgpmew3EWwgu4YP6jEcgJhj	7	3NLWdJnAPYaA4HLrprjdMFz29sKnoSfxj3NUghHRDLc59tT2A3BL	20	19	n5k8oZ3XHDues5YL_o0rX6Oh6yAAE5MTMCW1jsv0Zw4=	1	1	10	77	{5,2,7,7,7,7,7,7,7,7,7}	23166005000061388	jxyhuW8gB4Zav3aPZwyGBKAE5TjKJbbjV38m8MyvhA1BireJSnh	7	8	8	1	\N	1733863607000	canonical
7	3NLWdJnAPYaA4HLrprjdMFz29sKnoSfxj3NUghHRDLc59tT2A3BL	5	3NLQ6yw3xcguX7xyfBMTJzY9Un5YshPVznxxEuiiLpob6YxJG8wu	30	82	xI4Bu-P6MyFCJYx40kLWqrekkoohAQx-_c2C4YBwYwY=	1	1	8	77	{5,1,7,7,7,7,7,7,7,7,7}	23166005000061388	jwNHWNfc9e2ZhG4sQtCcYM1BqzPrLTV3xuU47TFb4Sz5PgYMSmo	6	7	7	1	\N	1733863427000	canonical
5	3NLQ6yw3xcguX7xyfBMTJzY9Un5YshPVznxxEuiiLpob6YxJG8wu	4	3NKUT2PSBGFQ5YHXmvG7eXnzNvqHu5yFsmQXFE7CGo2pTvCnpWv8	20	19	hqpgJ_xtlEF9RykHtctvDUPoc_Ruy-Sm5MwIC2yH6gc=	1	1	6	77	{5,7,7,7,7,7,7,7,7,7,7}	23166005000061388	jwLoewectxRQEA6Co3yk473dfsT2kNFTL5pwzuA5pUq47drrxtk	5	6	6	1	\N	1733863247000	canonical
4	3NKUT2PSBGFQ5YHXmvG7eXnzNvqHu5yFsmQXFE7CGo2pTvCnpWv8	3	3NK6SdK5cBW7UzqEw8ucK3KvbbYAjaeT7jP2X172XN596sGGQ5c8	20	19	roIfSCssVABO-AuAc5Fnc1u7Y5xG5X105fJRxOJ3SwI=	1	1	5	77	{4,7,7,7,7,7,7,7,7,7,7}	23166005000061388	jwAjiwjdVfHcWxWiQphXnpML1UWnKR9fvBxMYPHGrzJpHu8qxtd	4	5	5	1	\N	1733863067000	canonical
3	3NK6SdK5cBW7UzqEw8ucK3KvbbYAjaeT7jP2X172XN596sGGQ5c8	2	3NKhRLbSTHDoqqMwHzbgFXNCuWfzChKC89PYMt7ezRFoXF8z8nR9	30	82	Au7d6kb4XFIncBb-vPv35-rl1CE5NSkI09Q6w2m72QU=	1	1	4	77	{3,7,7,7,7,7,7,7,7,7,7}	23166005000061388	jwqxYqQQN9qArTuk8cVcL9fYJdYUj6kt5WzG7xYMPtZiakHh21b	3	4	4	1	\N	1733862887000	canonical
2	3NKhRLbSTHDoqqMwHzbgFXNCuWfzChKC89PYMt7ezRFoXF8z8nR9	1	3NLk7cTGaFSNoKastQyYDhgMe3RPzvVVcFWZWr2pBR32X7PbMjPg	20	19	LHRBKEVvtGd1E3hord_QWhx3YdaRSNdY1Ut-L6bU3Qs=	1	1	3	77	{2,7,7,7,7,7,7,7,7,7,7}	23166005000061388	jwHKoG7edFV24mC86V6ruBjDru66oxPRARZ1RMwBnw5Fo4vQ9gv	2	1	1	1	\N	1733862347000	canonical
1	3NLk7cTGaFSNoKastQyYDhgMe3RPzvVVcFWZWr2pBR32X7PbMjPg	\N	3NKoZQqKmsxnNEGqRRCzkMVGx4J33nifLXKL22q9eBUup3RRMKgQ	1	1	39cyg4ZmMtnb_aFUIerNAoAJV8qtkfOpq0zFzPspjgM=	1	1	2	77	{1,7,7,7,7,7,7,7,7,7,7}	23166005000061388	jw8KDH85vTLS1rjPuZ1bHxM4fhfvNwJRTci7zgNUVCqPCvmGJ6M	1	0	0	1	\N	1733862167000	canonical
15	3NLhFXgrRhdmZeHYVAeRF7SFCeRD8kCPFYqv3WXatyVJTBEA6hm4	13	3NKDwjdVwFnqeinyjmtWC69EHzfEEeC6VMRzeYAjdncZvhFkQk6M	20	19	arNRCh07gVeO1e3NsAvZI7TwldB-BdWGROYkUN35dgU=	1	1	16	77	{5,6,7,7,7,7,7,7,7,7,7}	23166005000061388	jxbsGr6VmjwQUv7bjEZVfth8HBkRxWbGkEoAEKv2KuC6SSX4TxR	11	12	12	1	\N	1733864327000	orphaned
23	3NKDEpuEbkZhJ9rsRqoAm9BQaByR4np6fjqZkVwmepUkHtGiBtfB	22	3NKeoDePFWH75HgFteAyhnu3tQ66s94g6xssAVq3V1usT9n63ttG	20	19	GKoGNH1hRwaBp9H4zAi1wuP8LzW8TDq3e8sBUdN5yAg=	1	1	24	77	{5,6,5,3,7,7,7,7,7,7,7}	23166005000061388	jxqz1yyk3SP3bquNhfvCSxXZY64J2r1YsH28QQcruEVQPXiFJRc	19	25	25	1	\N	1733866667000	canonical
21	3NL5cTVUMCSzC7e2KjERVziq1BR4yTrFdrtsZq6SFAuqab2Cgqzj	20	3NKaaH6A8pZJdyWotjGGd1ajvNhLf9ecDkocN821Zgc38BDrU17G	20	19	9KOQ3Maihzq0dTcuy2m3IY5HwKyjal93nn7w2Q0iKAs=	1	1	22	77	{5,6,5,1,7,7,7,7,7,7,7}	23166005000061388	jxGycvBxSCB1fHyWFn46McwCPP7F6pvtxdgHugZjU7BsAPQPvWk	17	23	23	1	\N	1733866307000	canonical
19	3NL3FZkX6nEkNCrATETbRu2F1QNwUZ1da8f2FdjBeZ1tct7VgfjJ	18	3NLHq7dAijLq7Du7efomstTrx4RCWtgpyBH9huGou4quPcZa1kkD	20	19	dvZiMWAf-K0kKBsmEwLB-AQvOu4e1ZwYKzGuRiY00AE=	1	1	20	77	{5,6,4,7,7,7,7,7,7,7,7}	23166005000061388	jxEwsPWVDiSvC6S2SAhdB2E1WS6z9TZG2d5JhuPs5uToh9TcZrK	15	19	19	1	\N	1733865587000	canonical
17	3NL84Cya3UCVmMxNHdRF7diEZSrRZxmCZF7gYREv5Fn5GDvdDo59	16	3NLc5Cm8nvce1gLBWqHGAVCXpig1AvTB625Y7ng22xig44jaQAy7	30	82	9eyZvB3hrcoHvx4Q5AOtsv9nRBDDk5znpi3oVLOfOwM=	1	1	18	77	{5,6,2,7,7,7,7,7,7,7,7}	23166005000061388	jwCkha4SBxKPq7Bcg8HkXVVmpKVd5KTg35zFMGLx995v2eSYQJv	13	16	16	1	\N	1733865047000	canonical
16	3NLc5Cm8nvce1gLBWqHGAVCXpig1AvTB625Y7ng22xig44jaQAy7	14	3NK4VgkH23nXVtmtpU6iHUq23YgEkDtP3B4C1nhEbyGKLj7tz2sf	20	19	e4z00lZdsnX4H1Vci56CpRAE9xLhn7de6MMvzowPmQ0=	1	1	17	77	{5,6,1,7,7,7,7,7,7,7,7}	23166005000061388	jwmXHqKXiYqT9wiiTZCSviXemnhZ424E6gUAVTtkzLc76NncRzP	12	15	15	1	\N	1733864867000	canonical
\.


--
-- Data for Name: blocks_internal_commands; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.blocks_internal_commands (block_id, internal_command_id, sequence_no, secondary_sequence_no, status, failure_reason) FROM stdin;
2	1	0	0	applied	\N
3	2	54	0	applied	\N
3	3	55	0	applied	\N
4	1	35	0	applied	\N
4	4	36	0	applied	\N
5	5	33	0	applied	\N
5	1	36	0	applied	\N
5	6	37	0	applied	\N
6	7	33	0	applied	\N
6	2	36	0	applied	\N
6	8	37	0	applied	\N
7	2	34	0	applied	\N
7	9	35	0	applied	\N
8	1	34	0	applied	\N
8	10	35	0	applied	\N
9	1	35	0	applied	\N
9	4	36	0	applied	\N
10	1	34	0	applied	\N
10	10	35	0	applied	\N
11	11	14	0	applied	\N
11	1	36	0	applied	\N
11	12	37	0	applied	\N
12	13	14	0	applied	\N
12	2	36	0	applied	\N
12	14	37	0	applied	\N
13	2	35	0	applied	\N
13	15	36	0	applied	\N
14	2	34	0	applied	\N
14	9	35	0	applied	\N
15	1	34	0	applied	\N
15	10	35	0	applied	\N
16	16	31	0	applied	\N
16	17	57	0	applied	\N
16	18	57	0	applied	\N
16	19	58	0	applied	\N
16	20	58	1	applied	\N
17	2	35	0	applied	\N
17	15	36	0	applied	\N
18	2	45	0	applied	\N
18	21	46	0	applied	\N
19	22	16	0	applied	\N
19	17	36	0	applied	\N
19	18	36	0	applied	\N
19	23	37	0	applied	\N
19	24	37	1	applied	\N
20	17	35	0	applied	\N
20	25	35	0	applied	\N
20	26	36	0	applied	\N
20	27	36	1	applied	\N
21	17	56	0	applied	\N
21	18	56	0	applied	\N
21	28	57	0	applied	\N
21	29	57	1	applied	\N
22	30	11	0	applied	\N
22	17	36	0	applied	\N
22	18	36	0	applied	\N
22	31	37	0	applied	\N
22	32	37	1	applied	\N
23	17	35	0	applied	\N
23	18	35	0	applied	\N
23	27	36	0	applied	\N
23	33	36	1	applied	\N
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
4	31	24	applied	\N
4	32	25	applied	\N
4	33	26	applied	\N
4	34	27	applied	\N
4	35	28	applied	\N
4	36	29	applied	\N
4	37	30	applied	\N
4	38	31	applied	\N
4	39	32	applied	\N
4	40	33	applied	\N
4	41	34	applied	\N
5	42	24	applied	\N
5	43	25	applied	\N
5	44	26	applied	\N
5	45	27	applied	\N
5	46	28	applied	\N
5	47	29	applied	\N
5	48	30	applied	\N
5	49	31	applied	\N
5	50	32	applied	\N
5	51	34	applied	\N
5	52	35	applied	\N
6	42	24	applied	\N
6	43	25	applied	\N
6	44	26	applied	\N
6	45	27	applied	\N
6	46	28	applied	\N
6	47	29	applied	\N
6	48	30	applied	\N
6	49	31	applied	\N
6	50	32	applied	\N
6	51	34	applied	\N
6	52	35	applied	\N
7	53	24	applied	\N
7	54	25	applied	\N
7	55	26	applied	\N
7	56	27	applied	\N
7	57	28	applied	\N
7	58	29	applied	\N
7	59	30	applied	\N
7	60	31	applied	\N
7	61	32	applied	\N
7	62	33	applied	\N
8	53	24	applied	\N
8	54	25	applied	\N
8	55	26	applied	\N
8	56	27	applied	\N
8	57	28	applied	\N
8	58	29	applied	\N
8	59	30	applied	\N
8	60	31	applied	\N
8	61	32	applied	\N
8	62	33	applied	\N
9	63	24	applied	\N
9	64	25	applied	\N
9	65	26	applied	\N
9	66	27	applied	\N
9	67	28	applied	\N
9	68	29	applied	\N
9	69	30	applied	\N
9	70	31	applied	\N
9	71	32	applied	\N
9	72	33	applied	\N
9	73	34	applied	\N
10	74	24	applied	\N
10	75	25	applied	\N
10	76	26	applied	\N
10	77	27	applied	\N
10	78	28	applied	\N
10	79	29	applied	\N
10	80	30	applied	\N
10	81	31	applied	\N
10	82	32	applied	\N
10	83	33	applied	\N
11	84	25	applied	\N
11	85	26	applied	\N
11	86	27	applied	\N
11	87	28	applied	\N
11	88	29	applied	\N
11	89	30	applied	\N
11	90	31	applied	\N
11	91	32	applied	\N
11	92	33	applied	\N
11	93	34	applied	\N
11	94	35	applied	\N
12	84	25	applied	\N
12	85	26	applied	\N
12	86	27	applied	\N
12	87	28	applied	\N
12	88	29	applied	\N
12	89	30	applied	\N
12	90	31	applied	\N
12	91	32	applied	\N
12	92	33	applied	\N
12	93	34	applied	\N
12	94	35	applied	\N
13	95	24	applied	\N
13	96	25	applied	\N
13	97	26	applied	\N
13	98	27	applied	\N
13	99	28	applied	\N
13	100	29	applied	\N
13	101	30	applied	\N
13	102	31	applied	\N
13	103	32	applied	\N
13	104	33	applied	\N
13	105	34	applied	\N
14	106	24	applied	\N
14	107	25	applied	\N
14	108	26	applied	\N
14	109	27	applied	\N
14	110	28	applied	\N
14	111	29	applied	\N
14	112	30	applied	\N
14	113	31	applied	\N
14	114	32	applied	\N
14	115	33	applied	\N
15	106	24	applied	\N
15	107	25	applied	\N
15	108	26	applied	\N
15	109	27	applied	\N
15	110	28	applied	\N
15	111	29	applied	\N
15	112	30	applied	\N
15	113	31	applied	\N
15	114	32	applied	\N
15	115	33	applied	\N
16	116	24	applied	\N
16	117	25	applied	\N
16	118	26	applied	\N
16	119	27	applied	\N
16	120	28	applied	\N
16	121	29	applied	\N
16	122	30	applied	\N
16	123	32	applied	\N
16	124	33	applied	\N
16	125	34	applied	\N
16	126	35	applied	\N
16	127	36	applied	\N
16	128	37	applied	\N
16	129	38	applied	\N
16	130	39	applied	\N
16	131	40	applied	\N
16	132	41	applied	\N
16	133	42	applied	\N
16	134	43	applied	\N
16	135	44	applied	\N
16	136	45	applied	\N
16	137	46	applied	\N
16	138	47	applied	\N
16	139	48	applied	\N
16	140	49	applied	\N
16	141	50	applied	\N
16	142	51	applied	\N
16	143	52	applied	\N
16	144	53	applied	\N
16	145	54	applied	\N
16	146	55	applied	\N
16	147	56	applied	\N
17	148	24	applied	\N
17	149	25	applied	\N
17	150	26	applied	\N
17	151	27	applied	\N
17	152	28	applied	\N
17	153	29	applied	\N
17	154	30	applied	\N
17	155	31	applied	\N
17	156	32	applied	\N
17	157	33	applied	\N
17	158	34	applied	\N
18	159	24	applied	\N
18	160	25	applied	\N
18	161	26	applied	\N
18	162	27	applied	\N
18	163	28	applied	\N
18	164	29	applied	\N
18	165	30	applied	\N
18	166	31	applied	\N
18	167	32	applied	\N
18	168	33	applied	\N
18	169	34	applied	\N
18	170	35	applied	\N
18	171	36	applied	\N
18	172	37	applied	\N
18	173	38	applied	\N
18	174	39	applied	\N
18	175	40	applied	\N
18	176	41	applied	\N
18	177	42	applied	\N
18	178	43	applied	\N
18	179	44	applied	\N
19	180	25	applied	\N
19	181	26	applied	\N
19	182	27	applied	\N
19	183	28	applied	\N
19	184	29	applied	\N
19	185	30	applied	\N
19	186	31	applied	\N
19	187	32	applied	\N
19	188	33	applied	\N
19	189	34	applied	\N
19	190	35	applied	\N
20	191	24	applied	\N
20	192	25	applied	\N
20	193	26	applied	\N
20	194	27	applied	\N
20	195	28	applied	\N
20	196	29	applied	\N
20	197	30	applied	\N
20	198	31	applied	\N
20	199	32	applied	\N
20	200	33	applied	\N
20	201	34	applied	\N
21	202	24	applied	\N
21	203	25	applied	\N
21	204	26	applied	\N
21	205	27	applied	\N
21	206	28	applied	\N
21	207	29	applied	\N
21	208	30	applied	\N
21	209	31	applied	\N
21	210	32	applied	\N
21	211	33	applied	\N
21	212	34	applied	\N
21	213	35	applied	\N
21	214	36	applied	\N
21	215	37	applied	\N
21	216	38	applied	\N
21	217	39	applied	\N
21	218	40	applied	\N
21	219	41	applied	\N
21	220	42	applied	\N
21	221	43	applied	\N
21	222	44	applied	\N
21	223	45	applied	\N
21	224	46	applied	\N
21	225	47	applied	\N
21	226	48	applied	\N
21	227	49	applied	\N
21	228	50	applied	\N
21	229	51	applied	\N
21	230	52	applied	\N
21	231	53	applied	\N
21	232	54	applied	\N
21	233	55	applied	\N
22	234	25	applied	\N
22	235	26	applied	\N
22	236	27	applied	\N
22	237	28	applied	\N
22	238	29	applied	\N
22	239	30	applied	\N
22	240	31	applied	\N
22	241	32	applied	\N
22	242	33	applied	\N
22	243	34	applied	\N
22	244	35	applied	\N
23	245	24	applied	\N
23	246	25	applied	\N
23	247	26	applied	\N
23	248	27	applied	\N
23	249	28	applied	\N
23	250	29	applied	\N
23	251	30	applied	\N
23	252	31	applied	\N
23	253	32	applied	\N
23	254	33	applied	\N
23	255	34	applied	\N
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
5	49	0	failed	{4}
5	50	1	failed	{3,2}
5	51	2	failed	{4}
5	52	3	failed	{3,2}
5	53	4	failed	{4}
5	54	5	failed	{3,2}
5	55	6	failed	{4}
5	56	7	failed	{3,2}
5	57	8	failed	{4}
5	58	9	failed	{3,2}
5	59	10	failed	{4}
5	60	11	failed	{3,2}
5	61	12	failed	{4}
5	62	13	failed	{3,2}
5	63	14	failed	{4}
5	64	15	failed	{3,2}
5	65	16	failed	{4}
5	66	17	failed	{3,2}
5	67	18	failed	{4}
5	68	19	failed	{3,2}
5	69	20	failed	{4}
5	70	21	failed	{3,2}
5	71	22	failed	{4}
5	72	23	failed	{3,2}
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
11	145	0	failed	{4}
11	146	1	failed	{3,2}
11	147	2	failed	{4}
11	148	3	failed	{3,2}
11	149	4	failed	{4}
11	150	5	failed	{3,2}
11	151	6	failed	{4}
11	152	7	failed	{3,2}
11	153	8	failed	{4}
11	154	9	failed	{3,2}
11	155	10	failed	{4}
11	156	11	failed	{3,2}
11	157	12	failed	{4}
11	158	13	failed	{3,2}
11	159	15	failed	{4}
11	160	16	failed	{3,2}
11	161	17	failed	{4}
11	162	18	failed	{3,2}
11	163	19	failed	{4}
11	164	20	failed	{3,2}
11	165	21	failed	{4}
11	166	22	failed	{3,2}
11	167	23	failed	{4}
11	168	24	failed	{3,2}
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
12	157	12	failed	{4}
12	158	13	failed	{3,2}
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
15	193	0	failed	{4}
15	194	1	failed	{3,2}
15	195	2	failed	{4}
15	196	3	failed	{3,2}
15	197	4	failed	{4}
15	198	5	failed	{3,2}
15	199	6	failed	{4}
15	200	7	failed	{3,2}
15	201	8	failed	{4}
15	202	9	failed	{3,2}
15	203	10	failed	{4}
15	204	11	failed	{3,2}
15	205	12	failed	{4}
15	206	13	failed	{3,2}
15	207	14	failed	{4}
15	208	15	failed	{3,2}
15	209	16	failed	{4}
15	210	17	failed	{3,2}
15	211	18	failed	{4}
15	212	19	failed	{3,2}
15	213	20	failed	{4}
15	214	21	failed	{3,2}
15	215	22	failed	{4}
15	216	23	failed	{3,2}
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
18	288	23	failed	{3,2}
19	289	0	failed	{4}
19	290	1	failed	{3,2}
19	291	2	failed	{4}
19	292	3	failed	{3,2}
19	293	4	failed	{4}
19	294	5	failed	{3,2}
19	295	6	failed	{4}
19	296	7	failed	{3,2}
19	297	8	failed	{4}
19	298	9	failed	{3,2}
19	299	10	failed	{4}
19	300	11	failed	{3,2}
19	301	12	failed	{4}
19	302	13	failed	{3,2}
19	303	14	failed	{4}
19	304	15	failed	{3,2}
19	305	17	failed	{4}
19	306	18	failed	{3,2}
19	307	19	failed	{4}
19	308	20	failed	{3,2}
19	309	21	failed	{4}
19	310	22	failed	{3,2}
19	311	23	failed	{4}
19	312	24	failed	{3,2}
20	313	0	failed	{4}
20	314	1	failed	{3,2}
20	315	2	failed	{4}
20	316	3	failed	{3,2}
20	317	4	failed	{4}
20	318	5	failed	{3,2}
20	319	6	failed	{4}
20	320	7	failed	{3,2}
20	321	8	failed	{4}
20	322	9	failed	{3,2}
20	323	10	failed	{4}
20	324	11	failed	{3,2}
20	325	12	failed	{4}
20	326	13	failed	{3,2}
20	327	14	failed	{4}
20	328	15	failed	{3,2}
20	329	16	failed	{4}
20	330	17	failed	{3,2}
20	331	18	failed	{4}
20	332	19	failed	{3,2}
20	333	20	failed	{4}
20	334	21	failed	{3,2}
20	335	22	failed	{4}
20	336	23	failed	{3,2}
21	337	0	failed	{4}
21	338	1	failed	{3,2}
21	339	2	failed	{4}
21	340	3	failed	{3,2}
21	341	4	failed	{4}
21	342	5	failed	{3,2}
21	343	6	failed	{4}
21	344	7	failed	{3,2}
21	345	8	failed	{4}
21	346	9	failed	{3,2}
21	347	10	failed	{4}
21	348	11	failed	{3,2}
21	349	12	failed	{4}
21	350	13	failed	{3,2}
21	351	14	failed	{4}
21	352	15	failed	{3,2}
21	353	16	failed	{4}
21	354	17	failed	{3,2}
21	355	18	failed	{4}
21	356	19	failed	{3,2}
21	357	20	failed	{4}
21	358	21	failed	{3,2}
21	359	22	failed	{4}
21	360	23	failed	{3,2}
22	361	0	failed	{4}
22	362	1	failed	{3,2}
22	363	2	failed	{4}
22	364	3	failed	{3,2}
22	365	4	failed	{4}
22	366	5	failed	{3,2}
22	367	6	failed	{4}
22	368	7	failed	{3,2}
22	369	8	failed	{4}
22	370	9	failed	{3,2}
22	371	10	failed	{4}
22	372	12	failed	{3,2}
22	373	13	failed	{4}
22	374	14	failed	{3,2}
22	375	15	failed	{4}
22	376	16	failed	{3,2}
22	377	17	failed	{4}
22	378	18	failed	{3,2}
22	379	19	failed	{4}
22	380	20	failed	{3,2}
22	381	21	failed	{4}
22	382	22	failed	{3,2}
22	383	23	failed	{4}
22	384	24	failed	{3,2}
23	385	0	failed	{4}
23	386	1	failed	{3,2}
23	387	2	failed	{4}
23	388	3	failed	{3,2}
23	389	4	failed	{4}
23	390	5	failed	{3,2}
23	391	6	failed	{4}
23	392	7	failed	{3,2}
23	393	8	failed	{4}
23	394	9	failed	{3,2}
23	395	10	failed	{4}
23	396	11	failed	{3,2}
23	397	12	failed	{4}
23	398	13	failed	{3,2}
23	399	14	failed	{4}
23	400	15	failed	{3,2}
23	401	16	failed	{4}
23	402	17	failed	{3,2}
23	403	18	failed	{4}
23	404	19	failed	{3,2}
23	405	20	failed	{4}
23	406	21	failed	{3,2}
23	407	22	failed	{4}
23	408	23	failed	{3,2}
\.


--
-- Data for Name: epoch_data; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.epoch_data (id, seed, ledger_hash_id, total_currency, start_checkpoint, lock_checkpoint, epoch_length) FROM stdin;
1	2va9BGv9JrLTtrzZttiEMDYw1Zj6a6EHzXjmP9evHDTG3oEquURA	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	1
2	2vafPBQ3zQdHUEDDnFGuiNvJz7s2MhTLJgSzQSnu5fnZavT27cms	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKoZQqKmsxnNEGqRRCzkMVGx4J33nifLXKL22q9eBUup3RRMKgQ	2
3	2vbFr42LgJmNfNgZd9mZZaKjfc2bLH2qCPu1M81EYVbEtP3LkqKX	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLk7cTGaFSNoKastQyYDhgMe3RPzvVVcFWZWr2pBR32X7PbMjPg	3
4	2vaA9UfjszbQsxyzw7a4nffZGnsmtChfjVn7qNtmFbLEpQD1cMp5	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKhRLbSTHDoqqMwHzbgFXNCuWfzChKC89PYMt7ezRFoXF8z8nR9	4
5	2vaNEcuKe5DTQrg4QKxDT8TFi9qMbbMFRpio2jgEKH8j2ZxEgsvK	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NK6SdK5cBW7UzqEw8ucK3KvbbYAjaeT7jP2X172XN596sGGQ5c8	5
6	2vbt3v1uCEAoCnMomsVVLFe6esGp2xrbStLtg9Xvm7zUSV5gr8Ua	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKUT2PSBGFQ5YHXmvG7eXnzNvqHu5yFsmQXFE7CGo2pTvCnpWv8	6
7	2vafxhpe3mWcf8YzwTJs2BNkXUajkVpqBRL9ijP8PwTWYTpvY1KN	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKUT2PSBGFQ5YHXmvG7eXnzNvqHu5yFsmQXFE7CGo2pTvCnpWv8	6
8	2vaMTkELniRBxWJQGxYBhWUsRUnyXCpCxrBQeYT4fEVMcz8W5Nx8	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLQ6yw3xcguX7xyfBMTJzY9Un5YshPVznxxEuiiLpob6YxJG8wu	7
9	2vbg6bHgWJW2xZXyfhDAsFrcJD4afDrXnV8hhnrjC19HLgLm9rEY	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLQ6yw3xcguX7xyfBMTJzY9Un5YshPVznxxEuiiLpob6YxJG8wu	7
10	2vaQdpVM8ixFdaEhGAtXXgavCZxbeDg5kTp8U8YbThweRgUTrrhD	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLWdJnAPYaA4HLrprjdMFz29sKnoSfxj3NUghHRDLc59tT2A3BL	8
11	2vacMfqstEiezC8tfCHE7RVgDQH3esHZodAvPxhAzdXQPcNT15SJ	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLwJUSvFYFKMtpBrQJdzHwgQnUiuwgpmew3EWwgu4YP6jEcgJhj	9
12	2vaHRCZAtF4tuqJJ4BXgFxM66yW34zvhMvoArWdW9CPd2dfiCxMj	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKp7moTu5cz7BZia8sdFRPa1bEFuhugcqNb8qUQ4RTAFd5t2xcZ	10
13	2vaxyTcFQANbyiLtUPT42hvN7yhsddp8WfNeWTozSSirxZsTnX1V	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKp7moTu5cz7BZia8sdFRPa1bEFuhugcqNb8qUQ4RTAFd5t2xcZ	10
14	2vbVyQdJQJWSXD62zysys6BioAaxcoxPZyunxVBSW9CquBvZbYNX	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLAj5mc6qr1vnsSJ8EKeDHnMzst2oeKUneqWndeQn9xHKA4rcds	11
15	2vaiusTyasiNU2L8FR93RShD2yqoDMTg23m4cnPoqia6zvMCg5sk	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKDwjdVwFnqeinyjmtWC69EHzfEEeC6VMRzeYAjdncZvhFkQk6M	12
16	2vbLvtjJDEqArmVvBGY3sFTSH5sDAKZTGe82i7d7TVbTULuyior1	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKDwjdVwFnqeinyjmtWC69EHzfEEeC6VMRzeYAjdncZvhFkQk6M	12
17	2vbjW1K3T4c52nogy5ohMHuo9aQceLvX1z4qDZ6BqMPT2umdUgCw	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NK4VgkH23nXVtmtpU6iHUq23YgEkDtP3B4C1nhEbyGKLj7tz2sf	13
18	2vbpygyRHYqRgbRu9FdwkYPg5dPB4wrwrujcRLuarkYKW4sytgoh	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLc5Cm8nvce1gLBWqHGAVCXpig1AvTB625Y7ng22xig44jaQAy7	14
19	2vbC9ymLXP9QrCLGDnqPxY5snZNDeoR3kYfwtqefqqTkEY9LcUyk	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NL84Cya3UCVmMxNHdRF7diEZSrRZxmCZF7gYREv5Fn5GDvdDo59	15
20	2vbKBsUXw8dThjq8SxD4kG7NqdpLXkuzywB5TjkihF6GPekcifJR	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLHq7dAijLq7Du7efomstTrx4RCWtgpyBH9huGou4quPcZa1kkD	16
21	2vaD4B89xX8dvhRE9YEXjYUnsGaKksAnQiFjEV6gLCQjsyW1g8ST	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NL3FZkX6nEkNCrATETbRu2F1QNwUZ1da8f2FdjBeZ1tct7VgfjJ	17
22	2vbH6jsf7vod6KVJYAi9vksqrDUwwxcARyz1JxeJ3Q2K1H9cYWpU	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKaaH6A8pZJdyWotjGGd1ajvNhLf9ecDkocN821Zgc38BDrU17G	18
23	2vbnXpCVCFZs2Hp87BtPjz5mvUNXv8hnSEFRn7vXz7sL9czwLK55	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NL5cTVUMCSzC7e2KjERVziq1BR4yTrFdrtsZq6SFAuqab2Cgqzj	19
24	2vadhcmFgaCLJu77vWuH8ZqChEb1MXZc1k1DMNyZGyZAEwrhkTVt	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKeoDePFWH75HgFteAyhnu3tQ66s94g6xssAVq3V1usT9n63ttG	20
\.


--
-- Data for Name: internal_commands; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.internal_commands (id, command_type, receiver_id, fee, hash) FROM stdin;
1	coinbase	20	720000000000	5JtoKfGCQ7Lur5e923DBbz6z6T8cHjmSidb2Tas6vx22WURJXvj5
2	coinbase	30	720000000000	5Ju98jFeVWdpvKRkb59B3i6Jk1ohwpjNLBG9Mco3mzbGFVaHJzHr
3	fee_transfer	30	127500000000	5JtcPvnfCAUq42o9nse2QaXvJNCLvdhUHxBxCCwhBef1RV6siysJ
4	fee_transfer	20	122750000000	5JuAU9yfAm4e3XtS3Myz1Ln95ZA55YnUhb7dyYKswBRPXecbgEvH
5	fee_transfer	20	122250000000	5Ju3TN2H6ZqrJMPb8ftJTY23bgVWHBKUsbXGrQ7Cmdou5Xg1xGvs
6	fee_transfer	20	500000000	5JtsNVY6qeYVRzQ4Q8ws4vCRhiqboC5JUtzSHrnFZsmKGCXanH3W
7	fee_transfer	30	122250000000	5JuYBRgUNF7XBi6MtuSLE9C5M8i21zSbDj69zMkYxubRPCHXmQh1
8	fee_transfer	30	500000000	5JuP7CEuahopV76w4Lm89sgAPKHdN4KAJ9CSbqjVsBxyAVGVbEry
9	fee_transfer	30	122500000000	5JubndkpAwzGteMjQBNGcVfuVrUzgsBGNk3pR528yLekLyNVKfvP
10	fee_transfer	20	122500000000	5JtqpCYQkMg4jqWihekoas2kM4vMR6dJB78v82esrsWrGfrPS1fT
11	fee_transfer	20	70000000000	5JtmwTJYedT8ggmMY8ExLY47wHj3uEdD18yCMmmjmizt9JeXdfZD
12	fee_transfer	20	52750000000	5JtdVqzNerngGLe2kg2QoXwXtohvkNPdEFusdv5ZJpoicPJbVjLw
13	fee_transfer	30	70000000000	5JuzJ1m1iY8bk7LEACUWorCeN9djuoHqsSazGRwwaFr2tmtrst77
14	fee_transfer	30	52750000000	5Jv7YCCYUnaWGpkyXVjXo9r8WJQpPgQjCn93yJPvkMCnLr4uFxhN
15	fee_transfer	30	122750000000	5JtuRjVTjPE6d3kJiwcV3DoDswvAUoZqTk2biQETavu3eZ28oDZY
16	fee_transfer	20	121750000000	5JtwmUYATGJGkWRvhV5LXbuaZjuitEzRsqG1NMCaQwWM6eafnptk
17	fee_transfer_via_coinbase	65	1000000	5JukhVuvR1yRS8Pbm8bsJmXShSZHnk77gwooNHNs9vuvHFA56Fpa
18	coinbase	20	720000000000	5JtzyXuzpTgZE9AmeM1AeuWPjSP8RPjwWqYNRWmknbmJGejnFYct
19	fee_transfer	65	63000000	5JuM7dSKBxN1dbFRfdySs5odZSofGcquc2aZgM35W95sK2dJQgHy
20	fee_transfer	20	6187000000	5Jur9gpPoqNLNjLZTFVetpMxuD1z61tCgJ6wUhdkYpjdhDkmvMrG
21	fee_transfer	30	125250000000	5Ju72RLGrW6xPwtuWGimmhfCqL2kYYCw4xfqQLZBrFquxoJxJne2
22	fee_transfer	20	80000000000	5Ju12Ain6vkzZMqVuJNUMPf3kyrq4TpR2Z73S521mpY5UmeqC76z
23	fee_transfer	65	46000000	5Jtdivn476sBfAPMPsEnz9NVmeWxvrgPpmLH1K3jEVGTMkcgAYms
24	fee_transfer	20	42704000000	5Jv4ceiXER2etzPZTygysWbCDBCYXGMaeBe8UraWC11aLMkrRPPC
25	coinbase	30	720000000000	5JuL4AaWWCmsytSE1NsYcE7PNGpPGMqyQ9pyj3oRYjymdRTQm4jz
26	fee_transfer	30	122742000000	5Jup7HaFeUU6UuYmVicTSpyTxWbG8QbMYU8SAteU5DsX5YtyR5wm
27	fee_transfer	65	8000000	5Jv44FcWsQf5G4NDNehC1MmgBUmGkcYGGYQohwYv3bogsgEakSjK
28	fee_transfer	65	7000000	5JtppggTpV2S1JFKQFLqw3XFRhzwbR9XffBzRbdwzWGXtiXHn5Nd
29	fee_transfer	20	127993000000	5Jv5B27QuWAazpDG4e3joUmspQHEFvZdq9gda83jUu2kLVZoBC1R
30	fee_transfer	20	55000000000	5JuLujwQL39Ya2BfYV5bhyivygEjnaWXdgL6f9s64s3dfeS2HxnV
31	fee_transfer	65	21000000	5Jv4ZgrtWV4H2H6atxKXgq5SexzX6ba9L21NUDQZTDcW9UVnjghJ
32	fee_transfer	20	67729000000	5JtYByXsnXd3S1YiMmsHioH1gWWgJWi5hxaLaNDzxb8egeQUCuqu
33	fee_transfer	20	122742000000	5JukTFm7tFmhUY5r2Hw4mh1eNNwQgoZupmYbdH4f9Cno5edKY1rW
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
6	B62qmYiXCD8guqqqX9y7rWYuJ3fAEwSq9KCxEJsLB3xdbDyXEVhtQtp
7	B62qs1CgZR9Ruyxn5NogBPYaECS8DhL5nYJSzN3G3NEExBkH726vf3N
8	B62qnzUQLreTeYj7TkkKyFR9s5REY6GTKc4sVK8K34Xvw8dfRPAUByg
9	B62qoxkuzRkqEXbw2D7FS1EJctSvrKhFDjwo1s7UqaRbzAC9wW9CqXB
10	B62qk4Y4VLT1oUbD1NjPunSEUjz5yVNbiETWCfNTvT5VLrmbRwnKcMk
11	B62qnsdKhWmeQZjvas2bVuE7AcUjqWxSjb5B6pFqyVdtVbrro8D9p9F
12	B62qqDcNXt7LK6686QQ9TvLaFF5as6xRRSMEjfwXJUEk3hSHVXksUth
13	B62qmRRtdPM1XRnHpchjrVdVyRtUKFX5Nmrhu7MWSs3wDVsLuTQ54dV
14	B62qnT7rV3ZQ71n6Z2RaPZSn38zEniZq1A8CXEdArxrF7q6sTTWZdZc
15	B62qmnTkaf43Ctbxq1NgvtakVwKKcB1nk2vee61bMAcPfDB5FR5upJN
16	B62qpTgN6VhfdCGimamFjarhSBfiK1oGEKyrqHN5FHejeJR8Z2vgKYt
17	B62qkaFHyAx1TMzuez3APX1hG33j2ZXCTXJFFzeSxgt8fA3henaeT84
18	B62qkCd6ftXqh39xPVb7qyJkSWZYa12QCsxFCaCmDrvfZoTNYmKQtkC
19	B62qjSyw3RHu5VnZ2N7J7eP4WCEVo22tKVX1TDtJxLL427g5mUNNZRt
20	B62qm2xGN7yhKzWsBAHb6wdpLoVuJLfucfshYbsxoxDcKXJMbV5Cif6
21	B62qrEWSxSXzp8QLDpvuJKeHWxybsE2iwaMPViMpdjptmUxQbtDV178
22	B62qnUCyUPAGE9ZXcu2TpkqUPaU3fhgzxRSEiyt5C8V7mcgNNvj1oc9
23	B62qiquMTUSJa6qqyd3hY2PjkxiUqgPEN2NXYhP56SqwhJoBsFfEF5T
24	B62qm174LzHrFzjwo3jRXst9LGSYjY3gLiCzniUkVDMW912gLBw63iZ
25	B62qrrLFhpise34oGcCsDZMSqZJmy9X6q7DsJ4gSAFSEAJakdwvPbVe
26	B62qo11BPUzNFEuVeskPRhXHYa3yzf2WoGjdZ2hmeBT9RmgFoaLE34A
27	B62qmSTojN3aDbB311Vxc1MwbkdLJ4NCau8d6ZURTuX9Z57RyBxWgZX
28	B62qiaEMrWiYdK7LcJ2ScdMyG8LzUxi7yaw17XvBD34on7UKfhAkRML
29	B62qoGEe4SECC5FouayhJM3BG1qP6kQLzp3W9Q2eYWQyKu5Y1CcSAy1
30	B62qqurx6PHhYqnMa9odUGUr2FTdrKgGcXaSRbRbZnAvMed4FhRWAxf
31	B62qn8rXK3r2GRDEnRQEgyQY6pax17ZZ9kiFNbQoNncMdtmiVGnNc8Y
32	B62qnjQ1xe7MS6R51vWE1qbG6QXi2xQtbEQxD3JQ4wQHXw3H9aKRPsA
33	B62qmzatbnJ4ErusAasA4c7jcuqoSHyte5ZDiLvkxnmB1sZDkabKua3
34	B62qrS1Ry5qJ6bQm2x7zk7WLidjWpShRig9KDAViM1A3viuv1GyH2q3
35	B62qqSTnNqUFqyXzH2SUzHrW3rt5sJKLv1JH1sgPnMM6mpePtfu7tTg
36	B62qkLh5vbFwcq4zs8d2tYynGYoxLVK5iP39WZHbTsqZCJdwMsme1nr
37	B62qiqUe1zktgV9SEmseUCL3tkf7aosu8F8HPZPQq8KDjqt3yc7yet8
38	B62qkNP2GF9j8DQUbpLoGKQXBYnBiP7jqNLoiNUguvebfCGSyCZWXrq
39	B62qr4z6pyzZvdfrDi33Ck7PnPe3wddZVaa7DYzWHUGivigyy9zEfPh
40	B62qiWZKC4ff7RKQggVKcxAy9xrc1yHaXPLJjxcUtjiaDKY4GDmAtCP
41	B62qqCpCJ7Lx7WuKCDSPQWYZzRWdVGHndW4jNARZ8C9JB4M5osqYnvw
42	B62qo9mUWwGSjKLpEpgm5Yuw5qTXRi9YNvo5prdB7PXMhGN6jeVmuKS
43	B62qpRvBE7SFJWG38WhDrSHsm3LXMAhdiXXeLkDqtGxhfexCNh4RPqZ
44	B62qoScK9pW5SBdJeMZagwkfqWfvKAKc6pgPFrP72CNktbGKzVUdRs3
45	B62qkT8tFTiFfZqPmehQMCT1SRRGon6MyUBVXYS3q9hPPJhusxHLi9L
46	B62qiw7Qam1FnvUHV4JYwffCf2mjcuz2s5F3LK9TBa5e4Vhh7gq2um1
47	B62qrncSq9df3SnHmSjFsk13W7PmQE5ujZb7TGnXggawp3SLb1zbuRR
48	B62qip9dMNE7fjTVpB7n2MCJhDw89YYKd9hMsXmKZ5cYuVzLrsS46ZG
49	B62qmMc2ec1D4V78sHZzhdfBA979SxUFGKTqHyYcKexgv2zJn6MUghv
50	B62qqmQhJaEqxcggMG9GepiXrY1j4WgerXXb2NwkmABwrkhRK671sSn
51	B62qp7yamrqYvcAv3jJ4RuwdvWnb8zFGfXchbfqR4BCkeub998mVJ3j
52	B62qk7NGhMEpPAwdwfqnxCbAuCm1qawX4YXh956nanhkfDdzZ4vZ91g
53	B62qnUPwKuUQZcNFnr5L5S5mpH9zcKDdi2FsKnAGQ1Vrd3F4HcH724A
54	B62qqMV93QdKFLmPnqvzaBE8T2jY38HVch4JW5xZr4kNHNYr1VtSUn8
55	B62qmtQmCLX8msSHASDTzNtXq81XQoNtLz6CUMhFeueMbJoQaYbyPCi
56	B62qp2Jgs8ChRsQSh93cL2SuDN8Umqp6GtDd9Ng7gpkxgw3Z9WXduAw
57	B62qo131ZAwzBd3mhd2GjTf3SjuNqdieDifuYqnCGkwRrD3VvHLM2N1
58	B62qo9XsygkAARYLKi5jHwXjPNxZaf537CVp88npjrUpaEHypF6TGLj
59	B62qnG8dAvhGtPGuAQkwUqcwpiAT9pNjQ7iCjpYw5k2UT3UZTFgDJW1
60	B62qj3u5Ensdc611cJpcmNKq1ddiQ63Xa8L2DnFqEBgNqBCAqVALeAK
61	B62qjw1BdYXp74JQGoeyZ7bWtnsPPd4iCxBzfUsiVjmQPLk8984dV9D
62	B62qpP2xUscwDA5TaQee71MGvU7dYXiTHffdL4ndRGktHBcj6fwqDcE
63	B62qo1he9m5vqVfbU26ZRqSdyWvkVURLxJZLLwPdu1oRAp3E7rCvyxk
64	B62qjzHRw1dhwS1NCWDH64yzovyxsbrvqBW846BRCaWmyJyoufddBSA
65	B62qr3kLexqVRMaswdWFDNisL5bDQtZ28hpXn8MLbmnia46LT8qPBsv
66	B62qkoANXg95uVHwpLAiQsT1PaGxuXBcrBzdjMgN3mP5WJxiE1uYcG9
67	B62qnzk698yW9rmyeC8mLCKhdmQZa2TRCG5hN3Z5NovZZqE1oou7Upc
68	B62qrQDYA9DvUNdgU87xp64MsQm3MxBeDRNuhuwwQ3hfS5sJhchipzu
69	B62qnSKLuJiF1gNnCEDHJeWFKPbYLKjXqz18pnLGE2pUq7PBYnU4h95
70	B62qk8onaP8h1VYVbJkQQ8kKtHszsA12Haw3ts5jm4AkpvNDkhUtKBH
71	B62qnbQoJyaGKvgRDthSPwWZPrYiYCpqeYoHhJ9415r1ws6DecWa8h9
72	B62qmpV1DwQvBMUmBxyDV6jJwSpS1zFWHHEZYuXYhPja4RWCbYG3Hv1
73	B62qiYSHjqf77rS6eBiBSiDwgqpsZEUf8KZZNmpxzULpxqm58u49m7M
74	B62qrULyp6Kp5PAmtJMHcRngmHyU2t9DF2oBpU4Q1GMvfrgsUBVUSm8
75	B62qpitzPa3MB2eqJucswcwQrN3ayxTTKNMWLW7SwsvjjR4kTpC57Cr
76	B62qpSfoFPJPXvyUwXWGJqTVya4kqThCH5LyEsdKrmqRm1mvDrgsz1V
77	B62qk9uVP24E5fE5x4FxnFxz17TBAZ4rrkmRDErheEZnVyFmCKvdBMH
78	B62qjeNbQNefZdv388wHg9ancPdFBw6Dj2Wxo6Jyw2EhR7J9kti48qx
79	B62qqwCS1S72xt9VPD6C6FjJkdwDghRCWJnYjebCagX8M2xzthqKDQC
80	B62qrGWHg32ZdFydA4UF7prU4zm3UH3dRxJZ5xAHW1QtNhgzuP2G62z
81	B62qkqZ1b8BkCK9PqWnQLjYueExVUVJon1Nn15SnZScG5AR3LqkEqzY
82	B62qjvz2ETAFLcenkJ5YQWpPzC7mgunMQW7V61h8XrpkE1P5jDXoXr8
83	B62qkQ9tPTmzm9oD2i8HbDRERFBHvG7Mi3dz6XLa3BEJcwA4ZcQaDa8
84	B62qnt4FQxWNcP49W5HaQNEe5Q1KqTBQJnnyqn7KyvSfNb6Dskbhy9i
85	B62qoxTxNh4o9ftUHSRatjTQagToJy7pW1zh7zZdyFYr9ECNDvugmyx
86	B62qrPuf95oqANBTTmvcvM1BKkBNrsmaXnaNpHGJYersezYTHWq5BTh
87	B62qkBdApDjoUj9Lckf4Bg7fWJSzSnyJHyCNkvq7XsPVzWk97BeGkae
88	B62qs23tCNy7qbrYHBwMfVNyiA82aA7xtWKh3QkFr1fMog3ptyXhptq
89	B62qpMFwmJ6fMm4cUb9wLLwoKRPFpYUJQmYqDe7RRaXgvAHjJpnEz3f
90	B62qkF4qisEVJ3WBdxcWoianq4YLaYXw89yJRzc7cPRu2ujXqp4v8Ji
91	B62qmFcUZJgxBQpTxnQHjyHWdprnsmRDiTZe6NiMNF9drGTM8hh1tZf
92	B62qo4Pc6HKhbc55RZuPrDfzbVZfxDqxkG3hV7sRDSivAthXAjtWaGg
93	B62qoKioA9hueF4xhZszsACn6GT7o69wZZJUoErVyvgP7WPrj92e9Tv
94	B62qkoTczRzwCUr6AmSiNcr3UWwkgbWeihVZphwP8CEuiDzrNHvunTX
95	B62qpGkYNpBS3MBgortSQuwV1aXcK6bRRQyYz3wGW5tCpCLdvxk8J6q
96	B62qnYfsf8P7B7UYcjN9bwL7HPpNrAJh7fG5zqWvZnSsaQJP2Z1qD84
97	B62qpAwcFY3oTy2oFUEc3gB4x879CvPqHUqHqjT3PiGxggroaUYHxkm
98	B62qib1VQVfLQeCW6oAKEX2GRuvXjYaX2Lw9qqjkBPAvdshHPyJXVMv
99	B62qm5TQe1nz3gfHqb6S4FE7FWV92AaKzUuAyNSDNeNJYgND35JaK8w
100	B62qrmfQsKRd5pwg1EZNYXSmcbsgCekCkJAxxJcZhWyX7ChfExZtFAj
101	B62qitvFhawB29DGkGv9NEfGZ8d9hECEKnKMHAvtULVATdw5epPS2s6
102	B62qo81kkuqxFZw9cZAcoYb4ZeCjY9HodT3yDkh8Zxhg9omfRexyNAz
103	B62qmeDPPUDtPVVHqesiKD7ecz6YZvGDHzVw2swBa84EGs5NBKpGK4H
104	B62qqwLQXBrhJmfAtF7GUf7FNVS2xoTPrkyw7d4Pj9W431bpysAdr3V
105	B62qkgcEQJ9qhjwQgt2XeN3RJpPTfjCrqFUUAW2NsVpzmyQwFbekNMM
106	B62qnAotEqbcE8sjbdyJkkvKnTzW3BCPaL5HrMEdHa4pVnfPBXWGXXW
107	B62qquzjE4bbK3mhk6jtFMnkm9BdzasTHuvMxx6JmhXeYKZkPbyZUry
108	B62qrj3VHfVadkyJCvmu7SvczS7QZy1Yk1uQjcjwkS4QqDt9oqi4eWf
109	B62qn6fTLLatKHi4aCX7p6Lg5rzZSq6VK2vrFVgX14gjaQqay8zHfsJ
110	B62qjrBApNy5mx6biRzL5AfRrDEarq3kv9Zcf5LcUR6iKAX9ve5vvud
111	B62qkdysBPreF3ef7bFEwCghYjbywFgumUHXYKDrBkUB89KgisAFGSV
112	B62qmRjcL489UysBEnabin5be824q7ok4VjyssKNutPq3YceMRSW4gi
113	B62qo3TjT6pu6i7UT8w39UVQc2Ljg8K69eng55vu5itof3Ma3qwcgZF
114	B62qpXFq7VJG6Spy7BSYjqSC1GBwKLCzfU8bcrUrALEFEXphpvjn3bG
115	B62qmp2xXJyj9LegRQUtFMCCGV3DQu337n6s6BK8a2kaYrMf1MmZHkT
116	B62qpjkSafKdAeCBh6PV6ZizJjtfs3v1DuXu1WowkYq2Bcr5X7bmk7G
117	B62qnjhGUFX636v8HyJsYKUkAS5ms58q9C9GtwNvPbMzMVy7FmRNhLG
118	B62qoCS2htWnx3g8gFq2ypSLHMW1jkZF6XMTH8yKE8gYTH7jfrcdjCo
119	B62qk2wpLtL3PUEQZBYPeabiXcZi6yzbVimciFWZSCHpxufKFDTmhi6
120	B62qjWRcn5eRmdppcsDNudiogbnNPzW4jWC6XH2LczMRDXzjK9AgfA2
121	B62qjJrgSK4wa3HnZZqmfJzxtMfACK9r2zEHqo5Rm6UUvyFrk4UjdPW
122	B62qoq6uA96gWVYBDtMQLZC5hB4hgAVojbuhw9Z2CE1Acj6iESSS1cE
123	B62qkSpe1P6FgwWU3BfvU2FXnuYt2vR4DzsEZf5TbJynBgyZy7W9yyE
124	B62qr225GCSVzAGKBYxB7rKE6ibtQAcfcXMfYH84hvkqHWAnFzWR4RT
125	B62qkQT9sAztAWnYdxQMaQSxrA93DRa5f8LxWCEzYA3Y3tewDQKUMyQ
126	B62qieyc3j9pYR6aA8DC1rhoUNRiPacx1ij6qW534VwTtuk8rF2UBrk
127	B62qoFyzjU4pC3mFgUidmTFt9YBnHjke5SU6jcNe7vVcvvoj4CCXYJf
128	B62qihY3kUVYcMk965RMKfEAYRwgh9ATLBWDiTzivneCmeEahgWTE58
129	B62qm8kJSo4SZt7zmNP29aYAUqETjPq6ge2hj5TxZWxWK2JDscQtx1Y
130	B62qkY3LksqsR2ETeNmAHAmYxi7mZXsoSgGMEMujrPtXQjRwxe5Bmdn
131	B62qrJ9hFcVQ4sjveJpQUsXZenisBnXKVzDdPntw48PYXxP17DNdKg4
132	B62qpKCYLZz2Eyb9vFfaVPgWjTWf1p3VpBLnQSSme2RC3ob4m1p8fCv
133	B62qkFYQghamWpPuNxzr1zw6ARk1mKFwkdQWJqHvmxdM95d45AjwWXE
134	B62qnzhgbY3HD19eKMeQTFPZijFTvJN82pHeGYQ2xM9HxZRPv6xhtqe
135	B62qroho2SKx4wignPPRf2qPbGzvfRgQf4zCMioxnmwKyLZCg3reYPc
136	B62qm4jN36Cwbtyd8j3BLevPK7Yhpv8KtWTia5fuwMAyvcHLCosU4PN
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
243	B62qrJbiCMHRWJjY3CydLPnysLENUcp37tdgtvRob6GTeK6Yfy12BjX
\.


--
-- Data for Name: snarked_ledger_hashes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.snarked_ledger_hashes (id, value) FROM stdin;
1	jw8KDH85vTLS1rjPuZ1bHxM4fhfvNwJRTci7zgNUVCqPCvmGJ6M
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
1	payment	7	7	7	0	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuHEg2qtp7JxzdmMcgPtwWUyxXEwg7JRNQnM5YW9WH49i3cn3YT
2	payment	7	7	7	1	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jug8uBSPNmW5zhjckq3p7ojpUsA4GMyatNitjivFTeoBJuZugxa
3	payment	7	7	7	2	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuPwnUWWSJ63baeUucsUBFkdeqNeAkxGNXkxguLmDYMB5KG99jw
4	payment	7	7	7	3	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JutAxWh1PAJN5EggcfTp6Snb9dD8E3EbXtN4WhJK4bXUL5ExiHy
5	payment	7	7	7	4	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuTkaYuugqurP1BgyexMsBJ2krKqY8JF5sh3EpnPjwqckS4JHeb
6	payment	7	7	7	5	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv6q6can9DniFV9Px8XqVAdrL32MXhRomy2jtdXXVgJuYZhQA7h
7	payment	7	7	7	6	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvRTW52aSiB7njNud747te7gXVgSbn76xxxdzPnYcP8Lx2BcQWu
8	payment	7	7	7	7	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtaxqdAvmrEMWbhsv7vWHcmY38cmy6jt74MqhmTW6Gn2YVr7VSp
9	payment	7	7	7	8	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju62ty4AzQSWVAF4p6a6av6TZxwNmA3nQxsAcYoEUqC1iwHyDiW
10	payment	7	7	7	9	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuFkDxETw6NP2Y5e4uuUq8X8swK8KcGe1yoGDbrB8fQP3JDNfdF
11	payment	7	7	7	10	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuSxEjrtkVFScsvbQZXi2FPTuhDNRrh91L3hQW7WhDm372mpQSr
12	payment	7	7	7	11	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juvtguy832r2sTGeU2886nDms5GEtEuAui7dW2ApvDcQvAvkgPe
13	payment	7	7	7	12	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JurNgH7mfMBcDSNsqiNGUw76r31G6Gr9KVjr319z9xGpkEfh5s3
14	payment	7	7	7	13	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvPEbS1S2m1kg9MPHABRUVZGGj2cnT66w45bK1Jzb14fhEJend8
15	payment	7	7	7	14	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtmimXobj3ZTaNaQvymFf8mGpV9RT5vVesi1YNbJ8JzjxTvJEQQ
16	payment	7	7	7	15	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtwFF7dVCE5FvmPxpdrmw34dzLuVHXLMa8RAMb3RoNTC6eCQjcu
17	payment	7	7	7	16	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtvdyaAjnSJ7QQffBnjL9KzM32jPXnyMSzoNu1oTrcEmbsHSWiz
18	payment	7	7	7	17	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuV5dgNrsAVvu9xveRUzvk2enpgWgNwoPRsxXiHj134VCrzmbqM
19	payment	7	7	7	18	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JugaLtteF2e8CuCGgnwVrMagrgTw7C3DqqwY4n8Szc6eJEJZdwP
20	payment	7	7	7	19	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuKqem61XmDWrQ8EMKR4w8Si89uXBCDfRP3DRJeCv8AfaTCv1YW
21	payment	7	7	7	20	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju2ihsQ8k6tyoWWUufgB66Gz2N3TzTrkA5cxfD4rzVephYj5AVs
22	payment	7	7	7	21	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuA9BPwS64xud9pCLWhRX3APRHC7hK26K9TEB3JGnht8tsT9piu
23	payment	7	7	7	22	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuUvyJoLfRx9vgRGGqdp3xHcHJJ611nf4y2djAdDCvXJVQdXxyj
24	payment	7	7	7	23	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuXQnRMGfAUVWueAPYhBRA25H4de8Za28iGdPbFRcGU73Q3YAyD
25	payment	7	7	7	24	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuWukQwvV3p1C2pwHsFLQueryWTNC2YrVSXmz8FJmjKuf4u9CXS
26	payment	7	7	7	25	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvLiHHT54u3u5GjR7zZXcDK2BWKs37BVnYzx5rAuEViscuqGaTJ
27	payment	7	7	7	26	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv3kgruQ6K5TbTQTMoKgLUhoyR7tqgL4Q1N226RmoebSAnubNdk
28	payment	7	7	7	27	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuU8j1exhmMjATAGanVzA7S8uhnz9t97A2YTi5iGBCgTu77evUy
29	payment	7	7	7	28	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jufg9BJdcwPxokJMVFsxnQETqfe3XdS6FPLG68U82SW5pZiy1Zk
30	payment	7	7	7	29	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv3uRhNYbpBsSEAWgLabX3ckQ6zrk6SNk2TXsedLyTSsXxFtnqc
31	payment	7	7	7	30	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JucbDMLboUMQ3c7bU4f7zWdFqbXYgHNNgazairAiThecBPPVyLu
32	payment	7	7	7	31	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuEmMoDbA5cbaWubB6pWaR3EEQttUVoNdJXDZk2jATDvmn2XThE
33	payment	7	7	7	32	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtgLxL54NWXCnxnZxpEoEvyFWQFPpYpmPUyNZvhFXpuZfsdAGvm
34	payment	7	7	7	33	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju6tVxbhnvvkhzLyB5Svxk85SwZx3ntNUojZBv5ihzJend3h6k1
35	payment	7	7	7	34	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtqWdMiX1dDbfQvRVShNyVjZmxXNGVs7aXjuZGxS7dLmUDhJR1Q
36	payment	7	7	7	35	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvS2icwzA5r8B8gabqfkB3xvqAD55N8mKeqJ4kX7UNM9oVEkU8F
37	payment	7	7	7	36	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtVnF2ag3UiMpRhDQT5Ajx7TFRLLqBMTFVPLN6fnTdeL9zbfRUU
38	payment	7	7	7	37	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtqaNjVWHCL9rQF54sWcbEFdyzvoBYSQxLCHbTjcu6fRYKbLAur
39	payment	7	7	7	38	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juu3eSu6ERHvz331UPCyuvQvgFFoVerrcy6z4Fg2XGSLDpQ8r24
40	payment	7	7	7	39	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuTw49AFSkrZxiHDRvYVE9Sotg2iBVDr9DwBq2uMp5Phd1dLVpu
41	payment	7	7	7	40	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuTWZ6kVQbDrrenCfq3cdZtm9Ug2vstAkgXR5z3hMB3N4JEjZtz
42	payment	7	7	7	41	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuaqfTe4j2tMaCkssD7jKkraVeemQfz8prLjv5dfqXne8ypZjXg
43	payment	7	7	7	42	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtXnMALMzvMCdCt4Smd2hbxm2JQe8dv12BcZtnG5sDFhrc9MH8S
44	payment	7	7	7	43	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtwvtxdAsTBJALZVmqzNhaxCX2QHA1vJnovB9BvVxbV8G39K5VS
45	payment	7	7	7	44	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtk5HC7sFnieWjuiYyvATraNxNPV8N8J6BdYoXvDr1Uonu2NhYt
46	payment	7	7	7	45	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv57AjsDJrkkrEcQobut7mao3d9xaBYXoWaMKYgS39Q81WS1pu6
47	payment	7	7	7	46	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtzz7toCCqpJaoAyoy9Z5cBjduWLpqqsGBhA4kX2CksrHj9jBKP
48	payment	7	7	7	47	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuZUEXHrSefThRAxp25vKr449aLsQjxyseyaEACybNbi1pcNoiM
49	payment	7	7	7	48	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuhRPoKGv12YQUm1Ap3rsu3rSfWpMRFVRJgFmyxJtf5q9GLjSbq
50	payment	7	7	7	49	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvQhbCMbMireYCp9KSdTiVNoWLKA89gSaUy21dntwnMTwPvLFUf
51	payment	7	7	7	50	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JueoheY5ySW7K2kLfN3HnRrAFeMmS6W824H9TcfAWJqFosNDJzd
52	payment	7	7	7	51	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuepbqTEpmrjhspnvK5iQS58kkAjgmFFiZdvdtyZyUztEi6ViLb
53	payment	7	7	7	52	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvDdSPYFSbsHuPT2Akku8SGjWy6R4ddEDgeagt9c2oCRGgxTR6R
54	payment	7	7	7	53	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtwsprPVZbHVzUHbWzPhbZUdvtwksym7sdg9TcoXtGeARrMa3b5
55	payment	7	7	7	54	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JthGKtdMWwfEc2o5ZUiLD1nkxdSesPgueajnEZpspu9RGSzG24P
56	payment	7	7	7	55	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuSddVS4dQoEiD5LDn948DxYyxm2QUsGqbQjUbqtQ4TrbDmKVbC
57	payment	7	7	7	56	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuRvy3SYVyBBRz6CXyCcZj1cwYM26YwqUfPCkvw856cPimwnW6Z
58	payment	7	7	7	57	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuLK8SYq44dwKCmSG1enZjWYCpCkK9EyGkRo3qvwEZPxjrJUcGo
59	payment	7	7	7	58	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju9HzC9R25gkaxZVYX3nhsTzGn8qXeJH8NjF1xudA1EbYLAgUSP
60	payment	7	7	7	59	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtznJVynYXcCXWpU59dKa6NtNh6qX7BhhKdNAAKURcKrnH4Ag2Y
61	payment	7	7	7	60	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvRT9XViihV5mxM51nY8hwPF4MSxXe1P7E2HTKAm41iGLUwoCPN
62	payment	7	7	7	61	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuuGeAPujinTKXendb8wyRi7KNDqhAV9jvWWMr3e23t1k7y75dL
63	payment	7	7	7	62	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv7BmLn12MS3foPDt4QhC6hZEJmBeTqybhx9FSPj6tvUnSbBjWj
64	payment	7	7	7	63	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv6hGsixemiZh44UMVRZMiW7KFq5woAsAbWEXdVqxUsrqULAkZx
65	payment	7	7	7	64	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuY65367sKFp9219YRS79fycjhXRi6vRizBq91ojwTocQzhw8Ag
66	payment	7	7	7	65	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvPm64g3Pio2VP6tst7bR42PgixKarLDALLatrm5MB3xKTKC1NC
67	payment	7	7	7	66	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtu5qE7xA9ziebEFBDfes8Um6rpGGesuq2SGGDZ2UzX2FsS66a5
68	payment	7	7	7	67	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JubgLiqFRqAf5BfjcYpraV2aj1uhYmQimkKRY9TpPrWL6ndXNNr
69	payment	7	7	7	68	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju9BTmxQHckg2AYkQWNaeJoGqwT3STebU3ir3T4CjP63tYwycjt
70	payment	7	7	7	69	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju9F6QkKGWvEBhmAYedXTaMWLgLhinj4T4jbYVE9pcK62ghw6zE
71	payment	7	7	7	70	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvNUTQJMkcXaY5NSxJoePN5p7x9MEAkcWMtsWVbvD9WVZd1xLpX
72	payment	7	7	7	71	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JteF8VDq97Gavgm1mrngG6M4bMxqdptxSMe5fYJmEH7LaowGjUT
73	payment	7	7	7	72	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jucx4onhhyxYmstpMTY1E3ZtDdRxsFYtew8UEkfxVkGzAHJ9HRx
74	payment	7	7	7	73	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv8e91RAdXwBTWNbTuAnqJZeMDZ9hbjJUAz5DnDNRXWQA7CooDc
75	payment	7	7	7	74	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtj8aZdL8ejT2gvQgPKZphSbEenbC5QZ4YJVHF38dfVhsjvi4Hm
76	payment	7	7	7	75	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju8Wsqc8y8jFyrjyRpVb7tyGvCBPA39dAmRSMrkoWykQ3gH6Xgr
77	payment	7	7	7	76	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JttiYhDzGg4u6xQYB4owAndDn9PQKVu8MNA4PTPQwT1PNv5PMmL
78	payment	7	7	7	77	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuBkpw4GtHoiyosqjxtZZhCZLgdcUJx6DL42QLsPGRqPYLQ5yzp
79	payment	7	7	7	78	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuyvX5Mcp6L8kw8NfuKDWZfFiXj1asrzjqHuhYH93xBi2cKD7pR
80	payment	7	7	7	79	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtWhbSdowtZCWE7XNH5CiytDa1G46x1eW8e6mcoUm3uCSfuUAbc
81	payment	7	7	7	80	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvP6hZ2xQXANeqMFZJpnoyTQNZo42fmnvU32G8PhbFsP4jCTvyE
82	payment	7	7	7	81	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuihG2FbsJ3mNDGvsETbTqKnhdZKhfFQGZ6STqi3qXUdtZPzBic
83	payment	7	7	7	82	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jugsy8VfgP3tW5bobVPTTBuKq9tyJGf92ZHzbavZvH2wYt4uVsN
106	payment	7	7	7	105	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtt9iAEUENEwhzYuMiwULav3w1yK3fB5D6SBsXoZBvs9XquixJv
107	payment	7	7	7	106	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuEp6SZ73BbxggecvfPttJnvrLdQ8psofE83RUvMdfnd4q2hkau
108	payment	7	7	7	107	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuiQwhoC8aw7BmfoZ22Yk6PdEhJeih6iX6KdjHHiWt8cVwesuZ8
109	payment	7	7	7	108	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtwwF5dXhVKteuFD5J5muXGK8rHp78JM1qzifJqjEZRJf4ADusy
110	payment	7	7	7	109	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jug5JF8uTxkHsGWytQwpyYL6Z8XsUS1HSMTWyyGKNPCiWGruyee
111	payment	7	7	7	110	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JugxKVYDrpauC4pE6TY5LqwzVyxFZgvUFAUmNUqCmoudJTwWLKD
112	payment	7	7	7	111	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtn5T8dmdZhQrqakFDd8WGQSoWTtBFYw78qA69v63LumTLAhgAa
113	payment	7	7	7	112	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuUYeHVp88poFdnp4GX6xHEqoJNoDxmG9cFDLGBijqaUHSioCk7
114	payment	7	7	7	113	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuegQiLbD1kj49zPsrGMrs2B7gqBTk2ZnBMZ6Fy7zsCfRZFk1pC
115	payment	7	7	7	114	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvP49iwx23crd9Eix76eXE3rtGKozfBer1F4eZB43j3Ne3UbwTH
84	payment	7	7	7	83	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv1s7qhmXcD4iC3EBoQJ6GDC1GpgvN4Bf7War1kf5zZZ3aASrvX
85	payment	7	7	7	84	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtiM2QYK7FayHuUWTjd5jYj99b8BbwEzdGMYhzFBbjr4ykQC5ST
86	payment	7	7	7	85	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuMcpAmAeoYaxU7mr128kDSgHYmfEXzhAGkvVbgyak9pAfGHrji
87	payment	7	7	7	86	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv1B5a37cv65vM4wfAJEZjxNfhPbsjmBoAWGuYKFcc7Bugkt95r
88	payment	7	7	7	87	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtZpkkW592QY6oBnXLVce6DbyvYHWdkhQ4sbtva1PKTAQnfSACk
89	payment	7	7	7	88	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuDNWjFJJhQCzrau3t1rpck7rvLxWDJeXbxwequB1nPeP75qsiq
90	payment	7	7	7	89	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvAwpT85kDVWmCAZ6VbuRZ2VVXbqFpD2bZWiw2CN3oJS2nAT9Qb
91	payment	7	7	7	90	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtdNzE1MBoCADcCgqaDSk45uj5QPqKbVqS9DnE2enmJ5ys5ZbVp
92	payment	7	7	7	91	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuTeiuXzrsgSTYscWmNR1J2CxBoAqgSfpV1MxvfgGUJnbWd5MR3
93	payment	7	7	7	92	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuraAvW1f1zeEUbjdz2rRNYtTUuxZ67h6B5D7BueoMQVTgycZvV
94	payment	7	7	7	93	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju3rj5xibmKgx4Ytc7xHii3CvXRZahuobbMxiot1JMXZjXskX1W
95	payment	7	7	7	94	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtadG5Ma6yv9s9jYuHUWsSjnURtrEA8GRJ2WaUt57U7P5cjDLk4
96	payment	7	7	7	95	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvFcuTqs16YbnwPu7woSNLcTywFDKDWw5DKvCfpQFnJnHvrVZcc
97	payment	7	7	7	96	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtcBkgzGLueu43C71ceqd2RvhsULMxUSdZ7hqzMTpFKvLYDSWjh
98	payment	7	7	7	97	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jud53CJCgQDMbmsrb4aR8Buu5VsFEE678YoU5DTL4iskHVnCyzk
99	payment	7	7	7	98	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuLeCrxPbmbao8qLANb3ZyWLCfxY37mXc1baNpJXAgE4N1ouP3p
100	payment	7	7	7	99	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtiTPveYRC6obntcMyyeG6ygQmmvFhYwjFryzCF27DK8JB4Prti
101	payment	7	7	7	100	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv9fWczxZAtsqu5B5AGJceoHdjVH5HdikiPEYZyToh73FsaMGzt
102	payment	7	7	7	101	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvCEojs7A7nuHaq6ENLNCZghAGaQykNpqiX72iwiggPkuci73PG
103	payment	7	7	7	102	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JueBp4tCYkvADHnGdpMFymkccSToPFfp7Kdo26EULBkpYrd3f6x
104	payment	7	7	7	103	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtrLGjmCRpSHB2rpYZGSbiyGK7oDUYAKDRyV8sKXobD4d9PLvj7
105	payment	7	7	7	104	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuN3wUpAPtHCCM7woFxz8Bc5QyL8tLhQnEYYakBLBi5ZhNH4fCB
116	payment	7	7	7	115	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju8bZopeWizycxrVcWzzkt1wTLHAyb2JqratG8yj2M3EcwWo7z1
117	payment	7	7	7	116	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju9TthEbKjfCnCGhCF32rPgLfTn1SNSP6DQ7DbWD3f1g2sK37oH
118	payment	7	7	7	117	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuuhdcBBxgYmyUPDjZtSXccvjpVUNJhoengJDQC3PCRokXBzxeq
119	payment	7	7	7	118	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtgq1nxbc7tsSb9wtFv7MCbgVGMfUtu7EtTt5SaNgkod2u3dSXM
120	payment	7	7	7	119	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuxnLNc231bewPHu2nVH7cFiW1kshDxHV4hmCBuFMswEJWPoVYM
121	payment	7	7	7	120	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvFnBTYrWGE4FCQdch8FwN72ESksQUubutgQkTXzXQYiGFcL7z8
122	payment	7	7	7	121	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuhtdQthnXBvauji8WPjwNJMX2GAcQM2oXd9NvonYq9PCKLE6Tv
123	payment	7	7	7	122	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvDdANfm57RprQvLadGpRVavV3PJQUtnQL927UBYL25YS2sCqHt
124	payment	7	7	7	123	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JteTM9gKCGgbcu5Zd1svjZX6nuyn7Pzr6DjKaCGDKMvfM3ojyBP
125	payment	7	7	7	124	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvNDbX5PfUXsgBvikAPwBEtMw9PZAzjW2V2oPyFjbWk1ZvSBjRY
126	payment	7	7	7	125	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvRBWvEJ6KHh5539wtqFX8HKLi3nC5Z81WJ7vtV8nrmjt3FnVmQ
127	payment	7	7	7	126	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtX8vJvahMd8mmNTCuCed23XjWhdTv7kfL6S1FwKk256rZSeCDk
128	payment	7	7	7	127	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juupu8ZVh5L8TUBvXKqXMRDW334LYmJx1cajS7RpGeQVaju432p
129	payment	7	7	7	128	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuHg3oTxTyCmxAa5xxYU3vFiNV1Bx33HFEd2NdxibjMtG34oJGz
130	payment	7	7	7	129	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JteGJzCcd1hz9B1QQA7uF1n26y5HRvaEMcEh9yCTGYsbrD2YWM2
131	payment	7	7	7	130	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtw8C1WYfV92f4Q6Kx23rXa7ecgMMEJAh6khktw6UmxGXVdnhMc
132	payment	7	7	7	131	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtdTm3Y7LHYGuGAcPcZoRNEAv4iSSMTU84Q7t8eoYzsQTXskdsw
133	payment	7	7	7	132	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvPAsPxh7WsnThQdwaWmzgWuKFvrEfShJ15DkM6MkAXifJkQsLa
134	payment	7	7	7	133	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtbzACYQddBhQrFxSBsNubVUdPQeMUTWZdYCkTmGe4YksFE5XNb
135	payment	7	7	7	134	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuBGwJrHSPN4PNKDbuG7fGLqH1BZh4KfcMjsuQiyETKSTUspEwT
136	payment	7	7	7	135	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvC6rP2h5hZJ9cioEjDvQEUkqRaq4MNqLxAQbKgYM1wMETf7t8F
137	payment	7	7	7	136	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuvBF3nmvbSYjuCSLkRaXdyfDbvcoWfsSxRBZgj5mFkjQANhdkg
138	payment	7	7	7	137	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtx42eYjoc8jTghPzsSu6rC1E3wD5WeTEnGcjxaprHSFzGXCQpa
139	payment	7	7	7	138	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvCmhGqTUR1Y5Sf6xMuKz7Y7yjaXny7VX2J4Zr8SNHoXdrWMoaY
140	payment	7	7	7	139	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtaZumw6YJdqmCNUfj6bFXCzLfBN9nYjbA9dfK93gVAi1Ck2ScB
141	payment	7	7	7	140	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvNjSeZH7j4x7gi6qS52daVZSmE3yJbKYfHotwhwxvdsFrBkhrM
142	payment	7	7	7	141	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvM7R41AzUYifytdaetX374ivNvQSyc64MnUTtM21KZ8iedNec7
143	payment	7	7	7	142	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtWrkpXAWJmN3SULbgssoo8vMYMU1KNkjbF3PrcaczbbswiWRn7
144	payment	7	7	7	143	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv4QQpJAt3QvEedBPdmkzPFGnC4CXQG33bWjwaKx8GK5EPiCeme
145	payment	7	7	7	144	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv679hDND3Dsva3CiG42p4573MSZo8GrVPMCviGHrRTnBzeLGUM
146	payment	7	7	7	145	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv1XLkaR76usAsXzgSZDC3GSaBdx6JLNxsQe3XLt4h5jqa4Uzbg
147	payment	7	7	7	146	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv3b7ZJKDVVjJpK6LysLNtujj9vxVfFtnCHW7GvkRgwy9qBsBFC
148	payment	7	7	7	147	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuZkUipjpb4dopJfoC4acnFsYKTBf9eDrGSPR4AmHNb3cmb8L9g
149	payment	7	7	7	148	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JufCyMX2ZFQEPvA2Zf6Y3hYs2JovLnaXCNz7J3c8JYTZdKKx9Cf
150	payment	7	7	7	149	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuFRBoqeKJw3nzskJrMUX16fV5YopdNCezgfdHZcqRj2y2i71MK
151	payment	7	7	7	150	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtnEbKtZbotdUsEd7UMSp4zovuuhUvqjGua5d1sMbVaRqxvJd1x
152	payment	7	7	7	151	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuD8RYpEpGe21f135yGg7qSkrfSA7w93GbS8e9wWx1L8aVnod5L
153	payment	7	7	7	152	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JthppEMCfSPfpPL6AyFcinLg56vV79WeNbc6rostfn9zKpxgAAw
154	payment	7	7	7	153	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtdnJkiShkcAKmjAWW25nK42AhrY4tQ5i5fyqC8pgmYF4wqQHWL
155	payment	7	7	7	154	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jti5EkZpdR5mhBZ4hoHbTp2K9jS7dYht36XW65cv4GWBuhwoyN2
156	payment	7	7	7	155	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv1jp7i8QzjP8ntZNLwPBh4oJs33Vb41cTqeHoh6dPeyTqjYuFY
157	payment	7	7	7	156	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuboWyUet3TBk8CZNAnwxUaoZcrvT1vaTxyas6cMKBeVKXcD55B
158	payment	7	7	7	157	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtynPyD5V2WgBdgp7aAEwgKyxB38RGj44zWSrdqDXrvnsQo9WC2
159	payment	7	7	7	158	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv1dC2pAGdM3yoPSpU7nirpKKEmhvt89dJm7PNWiz5rN22G3jnt
160	payment	7	7	7	159	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuM6iMTkNMEVDWhEemANmyPZjutoEWoxhcJEivMKPEzVcWHykVD
161	payment	7	7	7	160	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuQb4sJ5jUjBXs9N4EYPsRFCShzA2x2acbfxTPvxwCGa3KHAZV6
162	payment	7	7	7	161	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtky5prxY6bwidDVgscR27369H8CwTKDQTXjvVMFD6Le88wW4C4
163	payment	7	7	7	162	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juc6sAp8C5ctuLivqbqZZp6cztnLf1HYRoyu1XCKVArJi2nKXKP
164	payment	7	7	7	163	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuokYXwKqT7DvLbBpgRD4LD8iRxcweLZo9232cZaR9LAXW2KVq5
165	payment	7	7	7	164	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuMYcrZwbhSx4VVvtrsr9oGL54MTLRaxib1kzu9JY9ByqgcWFK3
166	payment	7	7	7	165	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jttnh6FTmCB2FT15BHB1QABqkaUhu2yPkoZXvnk1EsP5WBQYM5T
167	payment	7	7	7	166	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtt3a5PcuoAt56EbUYZ8x8CgSfEEio7mBccYen824QZHqRcdcLX
168	payment	7	7	7	167	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv9qaAXxGPonq7zJTpHynaA6gNZFCbfgntFhcJLazwfUJKe8Z2t
169	payment	7	7	7	168	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtrqUvUZAkjEHWA6yBejBYvvt2WC53YfJXBcc3WnnY2qMCzS7is
170	payment	7	7	7	169	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvJTiMqH6eefGp4TdnmFZCX6unhLC59GK7aoYgQ4grhCMx77rNh
171	payment	7	7	7	170	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv86raKxRUijJCvw6QVKebpskzrYXqvhY36LNZdcrDvsjv9r5Xi
172	payment	7	7	7	171	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtkrFMZX9U1FGgX7hX9LEPpqs6xLTtoQ9ELoKQhPmJe9kxXEKPR
173	payment	7	7	7	172	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvNvp1F8BuvhWFM9JCREGkXkZrLfThD47zGkkcPdszvofYp4U8T
174	payment	7	7	7	173	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuDjVe1ffBiQqZLiiHZuA27H4tvdSYcpasmb5ttAJCRoa5sTPpt
175	payment	7	7	7	174	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtdC7LkZgNYQjwSu9Q1UbmsjfGgoSbheipCCHFWEmK8x86Dy29N
176	payment	7	7	7	175	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtem9eFLwBBdSb9gjMYNqNVG3YwpdzF28NjmuqK2Q7MBnRYuJod
177	payment	7	7	7	176	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju6NGYU6SduieaC2XLWKmoC9E7qyGeoJMKSDphLBeqMqpLnMTyT
178	payment	7	7	7	177	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JueayJ2c65u6h21WxnwkgGGxZmCKPfjN5SAZSTzCrGyhYYF8abL
179	payment	7	7	7	178	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JukRuFZCowykfntWrgCoXCWiKaSW5LzBRmNREhvcXLad57d9rvW
180	payment	7	7	7	179	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuUjgKXj18DWVUMZCVQT7LupPgZJ12ggJ2igoSqL1AAdLMmZm3Y
181	payment	7	7	7	180	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuU1sAvjmfrMDL4RDYThKfBDCupvApgWxyTbyjaPDV1T3GrXeC1
182	payment	7	7	7	181	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtbrRcowV5uEQtwtYtwsR8ttYPjsbZmA5FJg5n26Luw3CXGj7Mb
183	payment	7	7	7	182	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuMtYXj9f5eotFEYfANRnyHLvKpZ4zRHYiT9HDTHG9i19AQNXDd
184	payment	7	7	7	183	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JujdCL6CfVfuhMpxaFnXmBVg161B3gm8Lf3kMuhVy3EgfY1e1vS
185	payment	7	7	7	184	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuZwZf3LhDSyr8qSFCGpyVcQHsmR2SP1jvxGz6ATqp4int8hnAC
186	payment	7	7	7	185	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtupva2wCPg5YQmCAcbGNprvY9pJgP9CXcZFbdodYAeSxeqGTMP
187	payment	7	7	7	186	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtaYBZjnsC7eKpvQ9ECiLyz2z7kniijDDffkJzcvq4oWrQviZuv
188	payment	7	7	7	187	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv5P8hodNaFABiGXPesuWsfP2mvX8tUoz7TCNhB6JdiDPzYxdVB
189	payment	7	7	7	188	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuLqeZB7TWHjwUpkbN4fe2tgt9GFggwzbNm2Y93CBQHnEXGQzpQ
190	payment	7	7	7	189	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JusFCrxHLsViSNC9riM6bHFVkSbqk16vQbvWJW7UYBGYvStzDZw
191	payment	7	7	7	190	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtwgES2FHnZ7B1gamFTT9kPeUwikufHszPF26zXqwhShvAG3fTz
192	payment	7	7	7	191	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtW1tqSs6Uja71T61GJ6K3yGjogCDWXwTm6TLDzZngaPXVFhPYw
193	payment	7	7	7	192	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvRTpkbJJhcvnx1ExomdXs7pDgqaBpZfcF3mvbMPZNsP7ieF3Wp
194	payment	7	7	7	193	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvKbEpn4axQReM3o8oa1KBvMEpcojjZ3BXowij3eMbbGQZAP3uH
195	payment	7	7	7	194	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv9Y5tm8U89xgqtuFcozHsiF3Qxxv81JQBS1NZMdnDKnt3Q85uP
196	payment	7	7	7	195	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JudyTE8SRHZ52Dp97hq6H4apHAMLZoV2Q9eCJt8HeTG5mHGtMKm
197	payment	7	7	7	196	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvRJeNVX2Wh7uATcnY9bEAEFPbK1Y4idE4NM6sUQyUGajaJDHvE
198	payment	7	7	7	197	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju4WrR9zGS52YLKirEVyZL6KgxdANUKmmfeYzWBjxPo442nrPBj
199	payment	7	7	7	198	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtw7SP6kzs7BiohEzm1j8xXLQYh8xRhc4rkq95KVfBqYFNmX42S
200	payment	7	7	7	199	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtdStdfNygd7y5WfuxHUJCpgK59uRZLEAoLAb83BD8iGTaXz7Ks
201	payment	7	7	7	200	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuoWcVXYRcidoqgs1LmqPhbgFRUdB6v8czMCHfMMjcj27nM1YU9
202	payment	7	7	7	201	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuZ2o1L1RdswM8k9xAGiqSd5bUMHA3VCZGfjAGGu2NaUJjotA2e
203	payment	7	7	7	202	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtyUbGmppj9fxWR3VuJcu4eW8XrNQC67nUzFHZkLysYu5t2saSB
204	payment	7	7	7	203	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju3QUVkHCfEesXzJaW8pCKd38DTny1CoGwNM6KVq31h6srx8Ghy
205	payment	7	7	7	204	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuDvMNJg4SEuQGDm1AZo9VyTCd7mXu1KPQcRvJ6K6yAzX682m3B
206	payment	7	7	7	205	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jum11Jjmu8eiRY9YBEwfoaRRoT9BE4j9TKhKu7tK8UYxy6vZMGs
207	payment	7	7	7	206	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuWfTMPaP7MD3L9cq7NU6DrT32LaYjHhUGzJ9nZCiP2EoRXihBD
208	payment	7	7	7	207	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv1f4keADpb9hA1upLfKkst1pmFbuyxmuuK5rkbijbpkuY9fFim
209	payment	7	7	7	208	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvQq3g1E1LwFfgRa12W9YPWowM6HnWQzjA6pvQT59emYUrg2uaw
210	payment	7	7	7	209	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtgd17EjzsmtyjhVrbmovhHH5BPpt8NZ1trhvhtzyTF2TtWt16L
211	payment	7	7	7	210	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju4wGN8jSZzNtSCB52DWkiU7xR46SoYv8thJi6P4HbvgF2U12mo
212	payment	7	7	7	211	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JugXCxntsJKdTr9nZE5bwg9Yb8woBd5KQr8D369NxCweuPR3Bnk
213	payment	7	7	7	212	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju5ZGVUFSa8nuoucx5rRNYDMHff4UEPthjYqtaT4VxxoYv1BAnN
214	payment	7	7	7	213	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtzP5kVLJFYRy9xHbfrQg4jr32oobBUN1Ac8oVvXYmpTAwWt81P
215	payment	7	7	7	214	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvNG4hEVK4bXMtViUkNyVxMLHrgHSqazSQzPCYZwZ2jmMs973RL
216	payment	7	7	7	215	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv6N2xUJpiyiKTEuRuKXgb49N6fCaZJ8JRk5Md1x2ySmtGcZi1h
217	payment	7	7	7	216	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvDRBh2oHkme4mrnAL58tbumyRAnJWuedLZsKiH5DPpc6igmF5N
218	payment	7	7	7	217	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtj3VZMPCR92XPzjkBL2KBU11UkZgVTUDeD2b3jT3HTcirBQbQU
219	payment	7	7	7	218	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtpoXdGnY7ecb4esXmVvxCtycuZGBbmqhtszhgvMu6FciSUtdcu
220	payment	7	7	7	219	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtj77zM9nsv5PVkjNrkSSnEdBZvotgJxkNhqa4A9q9hQ89fEk3R
221	payment	7	7	7	220	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuaR4SBsiGsuLmZzndvQmJt98gbEHF2q3NVXxfUehB8kXXtQ4EP
222	payment	7	7	7	221	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv2XMZSo4hkhFSt1nxGp7cG5PdwpGikte3arqCLkdR6rDUoiLXc
223	payment	7	7	7	222	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuFGUpQZQYMJrVCtmHhv8JACz8svheRKwwWMkoRjQvNeAZQUNcs
224	payment	7	7	7	223	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuFnPySpwXL5t2S1F7LZm2hVZUWphtUcjRwhg1Xebv6k6k9Ssmg
225	payment	7	7	7	224	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtyrFGfdJhfSsjdr99zG8Ek5G7PjAB8M33yTJQH7DCyxSBSD3D8
226	payment	7	7	7	225	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvKGkdABeBP5DPQwdj9Wgj3stceY98Ktn3B3Pkjybu8ppx1cGBf
227	payment	7	7	7	226	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuERgtyHEtp1HeCWSNhLzmPiHLbQgR17n4gfeiNr5WpLBgUBcT4
228	payment	7	7	7	227	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuXcyR48fDeQtr3Ezu1C98nxsdnXrVX4DcV3QGoPSGpfg8p8VyT
229	payment	7	7	7	228	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvR1Eds6cryZ58dVVihBRFDqpEKprbfWNey6pK8kUPt19UiN3Pi
230	payment	7	7	7	229	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvQrK7fhiCpurh9ZabA2Ye1ee6531qqzgyvUQcJkxJGTCe51YE8
231	payment	7	7	7	230	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju3JMMF64spkUNT5goYJNKf7j2raVzAah88fqEYLP723QDPRpdj
232	payment	7	7	7	231	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JujvHNStuiQ63vZhAiwhhbYGP84jVuY6J5Ade5UebZYuBfkPM5k
233	payment	7	7	7	232	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtkP4PB5zVcqDcAAqPeLL3jJrZDGxVQAznCCZQD7axqxHVuQgX1
245	payment	7	7	7	244	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtoiZsbMYZmtKq1rmWyYo2raWPDbDYenixM6tGLe9qXXEsyRyqj
246	payment	7	7	7	245	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuKwHnCyycLhJNVQQfJqGkjy1SyXhSQeHHcaaRStcL36ftAGXVB
247	payment	7	7	7	246	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jthc2dZazCsGYNUuKRkdxwP1Lgq8mwnmhNuGRuv79hKyVQYam95
248	payment	7	7	7	247	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JujomLVVhnxyVetGesFg8WQsnwxeX4CPzvuHWDFbxxRZGogohzs
249	payment	7	7	7	248	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuLvKoPp4nNke3EnZfrjTFAN29arb9keiCsgMUcK3iQ4YYriuGi
250	payment	7	7	7	249	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuPrhiJwkd232vhGc4EAjWpsRqWeaYALsi4Ra72dRaMBgJSYwuS
251	payment	7	7	7	250	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvML4osKaS6kf3CixLdCPbfSmfoRZtCoLS5BgzgFMuf73K3AtC6
252	payment	7	7	7	251	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtvu3uvv3QMoBLhfUnNnyR9tsgn8Suedg9QXNJ1gh3XMXvMEgkz
253	payment	7	7	7	252	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtnME4NWYzXmeLGPWDfgcBPPqGEqnggpoj6xwSKSAv1dkbWAbqf
254	payment	7	7	7	253	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuHi9A4Dvh2kY9FwPGnHBihwNGWFmPC4EvEF41mJhqrMpC1sYKs
255	payment	7	7	7	254	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JttmCJcRZsXwjeYNYFLjs1D7NuVddKDAHq9dtXdUuVy6bu9VJXC
234	payment	7	7	7	233	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtZYWsfax5P5KSiWz7132VH96x8nnWKadrMX8tpebaSfDtBDa2E
235	payment	7	7	7	234	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuMiPPhuidCRSpooS8th4GY6ARZSnJxRqwNwTppKUCDaopicjaj
236	payment	7	7	7	235	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JujcVqX1h1xCbbn9brm1VXH9gSarcfbuL6QxyHwBL1mjNi5WTDJ
237	payment	7	7	7	236	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtesQoodQghsyZMoEVXBMm23j5c228XzHZNF5Fv7EvVxCsTJtXr
238	payment	7	7	7	237	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvAHjuwBUymUCUp1EPUhmenXyatruRsXHLuxdFBqJVfS5KwTRND
239	payment	7	7	7	238	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuYDz4KMddB6hDxaqoAEkhdAS1caQsiyeXBik6kxRewXMxh78rQ
240	payment	7	7	7	239	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju3jk9HTLLc6KpcPbhjCRFUj3P4hjCKR5vhoatUJ2YyRkam1JXj
241	payment	7	7	7	240	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JugttAocm3NeRB6vT7SQsYP3VUgHmnYu5YwZ92zgZiG2dx52Kzp
242	payment	7	7	7	241	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuSUTZ5gncAg68QisnuUotVs4SX1WEdQreji8rBtko5sriDs7aG
243	payment	7	7	7	242	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JugH19APF58arsZRvcnWEcg1KVD96VB3QGCZNZUfFLkC5WAqvci
244	payment	7	7	7	243	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtss1e8WFjDR4SjCZFXxnJvxug1bLafn35fCvudoEBfgQtLtWyB
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
1	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
\.


--
-- Data for Name: zkapp_account_precondition; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.zkapp_account_precondition (id, balance_id, nonce_id, receipt_chain_hash, delegate_id, state_id, action_state_id, proved_state, is_new, permissions_id) FROM stdin;
1	\N	1	\N	\N	1	\N	\N	\N	1
2	\N	\N	\N	\N	1	\N	\N	\N	1
3	\N	2	\N	\N	1	\N	\N	\N	1
4	\N	3	\N	\N	1	\N	\N	\N	1
5	\N	4	\N	\N	1	\N	\N	\N	1
6	\N	5	\N	\N	1	\N	\N	\N	1
7	\N	6	\N	\N	1	\N	\N	\N	1
8	\N	7	\N	\N	1	\N	\N	\N	1
9	\N	8	\N	\N	1	\N	\N	\N	1
10	\N	9	\N	\N	1	\N	\N	\N	1
11	\N	10	\N	\N	1	\N	\N	\N	1
12	\N	11	\N	\N	1	\N	\N	\N	1
13	\N	12	\N	\N	1	\N	\N	\N	1
14	\N	13	\N	\N	1	\N	\N	\N	1
15	\N	14	\N	\N	1	\N	\N	\N	1
16	\N	15	\N	\N	1	\N	\N	\N	1
17	\N	16	\N	\N	1	\N	\N	\N	1
18	\N	17	\N	\N	1	\N	\N	\N	1
19	\N	18	\N	\N	1	\N	\N	\N	1
20	\N	19	\N	\N	1	\N	\N	\N	1
21	\N	20	\N	\N	1	\N	\N	\N	1
22	\N	21	\N	\N	1	\N	\N	\N	1
23	\N	22	\N	\N	1	\N	\N	\N	1
24	\N	23	\N	\N	1	\N	\N	\N	1
25	\N	24	\N	\N	1	\N	\N	\N	1
26	\N	25	\N	\N	1	\N	\N	\N	1
27	\N	26	\N	\N	1	\N	\N	\N	1
28	\N	27	\N	\N	1	\N	\N	\N	1
29	\N	28	\N	\N	1	\N	\N	\N	1
30	\N	29	\N	\N	1	\N	\N	\N	1
31	\N	30	\N	\N	1	\N	\N	\N	1
32	\N	31	\N	\N	1	\N	\N	\N	1
33	\N	32	\N	\N	1	\N	\N	\N	1
34	\N	33	\N	\N	1	\N	\N	\N	1
35	\N	34	\N	\N	1	\N	\N	\N	1
36	\N	35	\N	\N	1	\N	\N	\N	1
37	\N	36	\N	\N	1	\N	\N	\N	1
38	\N	37	\N	\N	1	\N	\N	\N	1
39	\N	38	\N	\N	1	\N	\N	\N	1
40	\N	39	\N	\N	1	\N	\N	\N	1
41	\N	40	\N	\N	1	\N	\N	\N	1
42	\N	41	\N	\N	1	\N	\N	\N	1
43	\N	42	\N	\N	1	\N	\N	\N	1
44	\N	43	\N	\N	1	\N	\N	\N	1
45	\N	44	\N	\N	1	\N	\N	\N	1
46	\N	45	\N	\N	1	\N	\N	\N	1
47	\N	46	\N	\N	1	\N	\N	\N	1
48	\N	47	\N	\N	1	\N	\N	\N	1
49	\N	48	\N	\N	1	\N	\N	\N	1
50	\N	49	\N	\N	1	\N	\N	\N	1
51	\N	50	\N	\N	1	\N	\N	\N	1
52	\N	51	\N	\N	1	\N	\N	\N	1
53	\N	52	\N	\N	1	\N	\N	\N	1
54	\N	53	\N	\N	1	\N	\N	\N	1
55	\N	54	\N	\N	1	\N	\N	\N	1
56	\N	55	\N	\N	1	\N	\N	\N	1
57	\N	56	\N	\N	1	\N	\N	\N	1
58	\N	57	\N	\N	1	\N	\N	\N	1
59	\N	58	\N	\N	1	\N	\N	\N	1
60	\N	59	\N	\N	1	\N	\N	\N	1
61	\N	60	\N	\N	1	\N	\N	\N	1
62	\N	61	\N	\N	1	\N	\N	\N	1
63	\N	62	\N	\N	1	\N	\N	\N	1
64	\N	63	\N	\N	1	\N	\N	\N	1
65	\N	64	\N	\N	1	\N	\N	\N	1
66	\N	65	\N	\N	1	\N	\N	\N	1
67	\N	66	\N	\N	1	\N	\N	\N	1
68	\N	67	\N	\N	1	\N	\N	\N	1
69	\N	68	\N	\N	1	\N	\N	\N	1
70	\N	69	\N	\N	1	\N	\N	\N	1
71	\N	70	\N	\N	1	\N	\N	\N	1
72	\N	71	\N	\N	1	\N	\N	\N	1
73	\N	72	\N	\N	1	\N	\N	\N	1
74	\N	73	\N	\N	1	\N	\N	\N	1
75	\N	74	\N	\N	1	\N	\N	\N	1
76	\N	75	\N	\N	1	\N	\N	\N	1
77	\N	76	\N	\N	1	\N	\N	\N	1
78	\N	77	\N	\N	1	\N	\N	\N	1
79	\N	78	\N	\N	1	\N	\N	\N	1
80	\N	79	\N	\N	1	\N	\N	\N	1
81	\N	80	\N	\N	1	\N	\N	\N	1
82	\N	81	\N	\N	1	\N	\N	\N	1
83	\N	82	\N	\N	1	\N	\N	\N	1
84	\N	83	\N	\N	1	\N	\N	\N	1
85	\N	84	\N	\N	1	\N	\N	\N	1
86	\N	85	\N	\N	1	\N	\N	\N	1
87	\N	86	\N	\N	1	\N	\N	\N	1
88	\N	87	\N	\N	1	\N	\N	\N	1
89	\N	88	\N	\N	1	\N	\N	\N	1
90	\N	89	\N	\N	1	\N	\N	\N	1
91	\N	90	\N	\N	1	\N	\N	\N	1
92	\N	91	\N	\N	1	\N	\N	\N	1
93	\N	92	\N	\N	1	\N	\N	\N	1
94	\N	93	\N	\N	1	\N	\N	\N	1
95	\N	94	\N	\N	1	\N	\N	\N	1
96	\N	95	\N	\N	1	\N	\N	\N	1
97	\N	96	\N	\N	1	\N	\N	\N	1
98	\N	97	\N	\N	1	\N	\N	\N	1
99	\N	98	\N	\N	1	\N	\N	\N	1
100	\N	99	\N	\N	1	\N	\N	\N	1
101	\N	100	\N	\N	1	\N	\N	\N	1
102	\N	101	\N	\N	1	\N	\N	\N	1
103	\N	102	\N	\N	1	\N	\N	\N	1
104	\N	103	\N	\N	1	\N	\N	\N	1
105	\N	104	\N	\N	1	\N	\N	\N	1
106	\N	105	\N	\N	1	\N	\N	\N	1
107	\N	106	\N	\N	1	\N	\N	\N	1
108	\N	107	\N	\N	1	\N	\N	\N	1
109	\N	108	\N	\N	1	\N	\N	\N	1
110	\N	109	\N	\N	1	\N	\N	\N	1
111	\N	110	\N	\N	1	\N	\N	\N	1
112	\N	111	\N	\N	1	\N	\N	\N	1
113	\N	112	\N	\N	1	\N	\N	\N	1
114	\N	113	\N	\N	1	\N	\N	\N	1
115	\N	114	\N	\N	1	\N	\N	\N	1
116	\N	115	\N	\N	1	\N	\N	\N	1
117	\N	116	\N	\N	1	\N	\N	\N	1
118	\N	117	\N	\N	1	\N	\N	\N	1
119	\N	118	\N	\N	1	\N	\N	\N	1
120	\N	119	\N	\N	1	\N	\N	\N	1
121	\N	120	\N	\N	1	\N	\N	\N	1
122	\N	121	\N	\N	1	\N	\N	\N	1
123	\N	122	\N	\N	1	\N	\N	\N	1
124	\N	123	\N	\N	1	\N	\N	\N	1
125	\N	124	\N	\N	1	\N	\N	\N	1
126	\N	125	\N	\N	1	\N	\N	\N	1
127	\N	126	\N	\N	1	\N	\N	\N	1
128	\N	127	\N	\N	1	\N	\N	\N	1
129	\N	128	\N	\N	1	\N	\N	\N	1
130	\N	129	\N	\N	1	\N	\N	\N	1
131	\N	130	\N	\N	1	\N	\N	\N	1
132	\N	131	\N	\N	1	\N	\N	\N	1
133	\N	132	\N	\N	1	\N	\N	\N	1
134	\N	133	\N	\N	1	\N	\N	\N	1
135	\N	134	\N	\N	1	\N	\N	\N	1
136	\N	135	\N	\N	1	\N	\N	\N	1
137	\N	136	\N	\N	1	\N	\N	\N	1
138	\N	137	\N	\N	1	\N	\N	\N	1
139	\N	138	\N	\N	1	\N	\N	\N	1
140	\N	139	\N	\N	1	\N	\N	\N	1
141	\N	140	\N	\N	1	\N	\N	\N	1
142	\N	141	\N	\N	1	\N	\N	\N	1
143	\N	142	\N	\N	1	\N	\N	\N	1
144	\N	143	\N	\N	1	\N	\N	\N	1
145	\N	144	\N	\N	1	\N	\N	\N	1
146	\N	145	\N	\N	1	\N	\N	\N	1
147	\N	146	\N	\N	1	\N	\N	\N	1
148	\N	147	\N	\N	1	\N	\N	\N	1
149	\N	148	\N	\N	1	\N	\N	\N	1
150	\N	149	\N	\N	1	\N	\N	\N	1
151	\N	150	\N	\N	1	\N	\N	\N	1
152	\N	151	\N	\N	1	\N	\N	\N	1
153	\N	152	\N	\N	1	\N	\N	\N	1
154	\N	153	\N	\N	1	\N	\N	\N	1
155	\N	154	\N	\N	1	\N	\N	\N	1
156	\N	155	\N	\N	1	\N	\N	\N	1
157	\N	156	\N	\N	1	\N	\N	\N	1
158	\N	157	\N	\N	1	\N	\N	\N	1
171	\N	170	\N	\N	1	\N	\N	\N	1
172	\N	171	\N	\N	1	\N	\N	\N	1
173	\N	172	\N	\N	1	\N	\N	\N	1
174	\N	173	\N	\N	1	\N	\N	\N	1
175	\N	174	\N	\N	1	\N	\N	\N	1
176	\N	175	\N	\N	1	\N	\N	\N	1
177	\N	176	\N	\N	1	\N	\N	\N	1
178	\N	177	\N	\N	1	\N	\N	\N	1
179	\N	178	\N	\N	1	\N	\N	\N	1
180	\N	179	\N	\N	1	\N	\N	\N	1
181	\N	180	\N	\N	1	\N	\N	\N	1
182	\N	181	\N	\N	1	\N	\N	\N	1
159	\N	158	\N	\N	1	\N	\N	\N	1
160	\N	159	\N	\N	1	\N	\N	\N	1
161	\N	160	\N	\N	1	\N	\N	\N	1
162	\N	161	\N	\N	1	\N	\N	\N	1
163	\N	162	\N	\N	1	\N	\N	\N	1
164	\N	163	\N	\N	1	\N	\N	\N	1
165	\N	164	\N	\N	1	\N	\N	\N	1
166	\N	165	\N	\N	1	\N	\N	\N	1
167	\N	166	\N	\N	1	\N	\N	\N	1
168	\N	167	\N	\N	1	\N	\N	\N	1
169	\N	168	\N	\N	1	\N	\N	\N	1
170	\N	169	\N	\N	1	\N	\N	\N	1
183	\N	182	\N	\N	1	\N	\N	\N	1
184	\N	183	\N	\N	1	\N	\N	\N	1
185	\N	184	\N	\N	1	\N	\N	\N	1
186	\N	185	\N	\N	1	\N	\N	\N	1
187	\N	186	\N	\N	1	\N	\N	\N	1
188	\N	187	\N	\N	1	\N	\N	\N	1
189	\N	188	\N	\N	1	\N	\N	\N	1
190	\N	189	\N	\N	1	\N	\N	\N	1
191	\N	190	\N	\N	1	\N	\N	\N	1
192	\N	191	\N	\N	1	\N	\N	\N	1
193	\N	192	\N	\N	1	\N	\N	\N	1
194	\N	193	\N	\N	1	\N	\N	\N	1
195	\N	194	\N	\N	1	\N	\N	\N	1
196	\N	195	\N	\N	1	\N	\N	\N	1
197	\N	196	\N	\N	1	\N	\N	\N	1
198	\N	197	\N	\N	1	\N	\N	\N	1
199	\N	198	\N	\N	1	\N	\N	\N	1
200	\N	199	\N	\N	1	\N	\N	\N	1
201	\N	200	\N	\N	1	\N	\N	\N	1
202	\N	201	\N	\N	1	\N	\N	\N	1
203	\N	202	\N	\N	1	\N	\N	\N	1
204	\N	203	\N	\N	1	\N	\N	\N	1
205	\N	204	\N	\N	1	\N	\N	\N	1
206	\N	205	\N	\N	1	\N	\N	\N	1
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
\.


--
-- Data for Name: zkapp_account_update_body; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.zkapp_account_update_body (id, account_identifier_id, update_id, balance_change, increment_nonce, events_id, actions_id, call_data_id, call_depth, zkapp_network_precondition_id, zkapp_account_precondition_id, zkapp_valid_while_precondition_id, use_full_commitment, implicit_account_creation_fee, may_use_token, authorization_kind, verification_key_hash_id) FROM stdin;
1	80	1	-1000000000000	t	1	1	1	0	1	1	\N	f	f	No	Signature	\N
2	243	2	999000000000	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
3	80	1	-1000000000	t	1	1	1	0	1	3	\N	f	f	No	Signature	\N
4	243	1	1000000000	f	1	1	1	0	1	2	\N	f	f	No	None_given	\N
5	243	3	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
6	80	1	-1000000000	t	1	1	1	0	1	4	\N	f	f	No	Signature	\N
7	243	4	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
8	80	1	-1000000000	t	1	1	1	0	1	5	\N	f	f	No	Signature	\N
9	243	5	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
10	80	1	-1000000000	t	1	1	1	0	1	6	\N	f	f	No	Signature	\N
11	243	6	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
12	80	1	-1000000000	t	1	1	1	0	1	7	\N	f	f	No	Signature	\N
13	243	7	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
14	80	1	-1000000000	t	1	1	1	0	1	8	\N	f	f	No	Signature	\N
15	243	8	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
16	80	1	-1000000000	t	1	1	1	0	1	9	\N	f	f	No	Signature	\N
17	243	9	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
18	80	1	-1000000000	t	1	1	1	0	1	10	\N	f	f	No	Signature	\N
19	243	10	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
20	80	1	-1000000000	t	1	1	1	0	1	11	\N	f	f	No	Signature	\N
21	243	11	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
22	80	1	-1000000000	t	1	1	1	0	1	12	\N	f	f	No	Signature	\N
23	243	12	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
24	80	1	-1000000000	t	1	1	1	0	1	13	\N	f	f	No	Signature	\N
25	243	13	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
26	80	1	-1000000000	t	1	1	1	0	1	14	\N	f	f	No	Signature	\N
27	243	14	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
28	80	1	-1000000000	t	1	1	1	0	1	15	\N	f	f	No	Signature	\N
29	243	15	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
30	80	1	-1000000000	t	1	1	1	0	1	16	\N	f	f	No	Signature	\N
31	243	16	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
32	80	1	-1000000000	t	1	1	1	0	1	17	\N	f	f	No	Signature	\N
33	243	17	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
34	80	1	-1000000000	t	1	1	1	0	1	18	\N	f	f	No	Signature	\N
35	243	18	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
36	80	1	-1000000000	t	1	1	1	0	1	19	\N	f	f	No	Signature	\N
37	243	19	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
38	80	1	-1000000000	t	1	1	1	0	1	20	\N	f	f	No	Signature	\N
39	243	20	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
40	80	1	-1000000000	t	1	1	1	0	1	21	\N	f	f	No	Signature	\N
41	243	21	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
42	80	1	-1000000000	t	1	1	1	0	1	22	\N	f	f	No	Signature	\N
43	243	22	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
44	80	1	-1000000000	t	1	1	1	0	1	23	\N	f	f	No	Signature	\N
45	243	23	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
46	80	1	-1000000000	t	1	1	1	0	1	24	\N	f	f	No	Signature	\N
47	243	24	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
48	80	1	-1000000000	t	1	1	1	0	1	25	\N	f	f	No	Signature	\N
49	243	25	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
50	80	1	-1000000000	t	1	1	1	0	1	26	\N	f	f	No	Signature	\N
51	243	26	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
52	80	1	-1000000000	t	1	1	1	0	1	27	\N	f	f	No	Signature	\N
53	243	27	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
54	80	1	-1000000000	t	1	1	1	0	1	28	\N	f	f	No	Signature	\N
55	243	28	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
56	80	1	-1000000000	t	1	1	1	0	1	29	\N	f	f	No	Signature	\N
57	243	29	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
58	80	1	-1000000000	t	1	1	1	0	1	30	\N	f	f	No	Signature	\N
59	243	30	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
60	80	1	-1000000000	t	1	1	1	0	1	31	\N	f	f	No	Signature	\N
61	243	31	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
62	80	1	-1000000000	t	1	1	1	0	1	32	\N	f	f	No	Signature	\N
63	243	32	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
64	80	1	-1000000000	t	1	1	1	0	1	33	\N	f	f	No	Signature	\N
65	243	33	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
66	80	1	-1000000000	t	1	1	1	0	1	34	\N	f	f	No	Signature	\N
67	243	34	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
68	80	1	-1000000000	t	1	1	1	0	1	35	\N	f	f	No	Signature	\N
69	243	35	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
70	80	1	-1000000000	t	1	1	1	0	1	36	\N	f	f	No	Signature	\N
71	243	36	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
72	80	1	-1000000000	t	1	1	1	0	1	37	\N	f	f	No	Signature	\N
73	243	37	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
74	80	1	-1000000000	t	1	1	1	0	1	38	\N	f	f	No	Signature	\N
75	243	38	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
76	80	1	-1000000000	t	1	1	1	0	1	39	\N	f	f	No	Signature	\N
77	243	39	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
78	80	1	-1000000000	t	1	1	1	0	1	40	\N	f	f	No	Signature	\N
79	243	40	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
80	80	1	-1000000000	t	1	1	1	0	1	41	\N	f	f	No	Signature	\N
81	243	41	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
82	80	1	-1000000000	t	1	1	1	0	1	42	\N	f	f	No	Signature	\N
83	243	42	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
84	80	1	-1000000000	t	1	1	1	0	1	43	\N	f	f	No	Signature	\N
85	243	43	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
86	80	1	-1000000000	t	1	1	1	0	1	44	\N	f	f	No	Signature	\N
87	243	44	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
88	80	1	-1000000000	t	1	1	1	0	1	45	\N	f	f	No	Signature	\N
89	243	45	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
90	80	1	-1000000000	t	1	1	1	0	1	46	\N	f	f	No	Signature	\N
91	243	46	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
92	80	1	-1000000000	t	1	1	1	0	1	47	\N	f	f	No	Signature	\N
93	243	47	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
94	80	1	-1000000000	t	1	1	1	0	1	48	\N	f	f	No	Signature	\N
95	243	48	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
96	80	1	-1000000000	t	1	1	1	0	1	49	\N	f	f	No	Signature	\N
97	243	49	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
98	80	1	-1000000000	t	1	1	1	0	1	50	\N	f	f	No	Signature	\N
99	243	50	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
100	80	1	-1000000000	t	1	1	1	0	1	51	\N	f	f	No	Signature	\N
101	243	51	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
102	80	1	-1000000000	t	1	1	1	0	1	52	\N	f	f	No	Signature	\N
103	243	52	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
104	80	1	-1000000000	t	1	1	1	0	1	53	\N	f	f	No	Signature	\N
105	243	53	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
106	80	1	-1000000000	t	1	1	1	0	1	54	\N	f	f	No	Signature	\N
107	243	54	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
108	80	1	-1000000000	t	1	1	1	0	1	55	\N	f	f	No	Signature	\N
109	243	55	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
110	80	1	-1000000000	t	1	1	1	0	1	56	\N	f	f	No	Signature	\N
111	243	56	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
112	80	1	-1000000000	t	1	1	1	0	1	57	\N	f	f	No	Signature	\N
113	243	57	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
114	80	1	-1000000000	t	1	1	1	0	1	58	\N	f	f	No	Signature	\N
115	243	58	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
116	80	1	-1000000000	t	1	1	1	0	1	59	\N	f	f	No	Signature	\N
117	243	59	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
118	80	1	-1000000000	t	1	1	1	0	1	60	\N	f	f	No	Signature	\N
119	243	60	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
120	80	1	-1000000000	t	1	1	1	0	1	61	\N	f	f	No	Signature	\N
121	243	61	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
122	80	1	-1000000000	t	1	1	1	0	1	62	\N	f	f	No	Signature	\N
123	243	62	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
124	80	1	-1000000000	t	1	1	1	0	1	63	\N	f	f	No	Signature	\N
125	243	63	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
126	80	1	-1000000000	t	1	1	1	0	1	64	\N	f	f	No	Signature	\N
127	243	64	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
128	80	1	-1000000000	t	1	1	1	0	1	65	\N	f	f	No	Signature	\N
129	243	65	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
130	80	1	-1000000000	t	1	1	1	0	1	66	\N	f	f	No	Signature	\N
131	243	66	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
132	80	1	-1000000000	t	1	1	1	0	1	67	\N	f	f	No	Signature	\N
133	243	67	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
134	80	1	-1000000000	t	1	1	1	0	1	68	\N	f	f	No	Signature	\N
135	243	68	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
136	80	1	-1000000000	t	1	1	1	0	1	69	\N	f	f	No	Signature	\N
137	243	69	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
138	80	1	-1000000000	t	1	1	1	0	1	70	\N	f	f	No	Signature	\N
139	243	70	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
140	80	1	-1000000000	t	1	1	1	0	1	71	\N	f	f	No	Signature	\N
141	243	71	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
142	80	1	-1000000000	t	1	1	1	0	1	72	\N	f	f	No	Signature	\N
143	243	72	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
144	80	1	-1000000000	t	1	1	1	0	1	73	\N	f	f	No	Signature	\N
145	243	73	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
146	80	1	-1000000000	t	1	1	1	0	1	74	\N	f	f	No	Signature	\N
147	243	74	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
148	80	1	-1000000000	t	1	1	1	0	1	75	\N	f	f	No	Signature	\N
149	243	75	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
150	80	1	-1000000000	t	1	1	1	0	1	76	\N	f	f	No	Signature	\N
151	243	76	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
152	80	1	-1000000000	t	1	1	1	0	1	77	\N	f	f	No	Signature	\N
153	243	77	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
154	80	1	-1000000000	t	1	1	1	0	1	78	\N	f	f	No	Signature	\N
155	243	78	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
156	80	1	-1000000000	t	1	1	1	0	1	79	\N	f	f	No	Signature	\N
157	243	79	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
158	80	1	-1000000000	t	1	1	1	0	1	80	\N	f	f	No	Signature	\N
159	243	80	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
160	80	1	-1000000000	t	1	1	1	0	1	81	\N	f	f	No	Signature	\N
161	243	81	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
162	80	1	-1000000000	t	1	1	1	0	1	82	\N	f	f	No	Signature	\N
163	243	82	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
164	80	1	-1000000000	t	1	1	1	0	1	83	\N	f	f	No	Signature	\N
165	243	83	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
166	80	1	-1000000000	t	1	1	1	0	1	84	\N	f	f	No	Signature	\N
167	243	84	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
168	80	1	-1000000000	t	1	1	1	0	1	85	\N	f	f	No	Signature	\N
169	243	85	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
170	80	1	-1000000000	t	1	1	1	0	1	86	\N	f	f	No	Signature	\N
171	243	86	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
172	80	1	-1000000000	t	1	1	1	0	1	87	\N	f	f	No	Signature	\N
173	243	87	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
174	80	1	-1000000000	t	1	1	1	0	1	88	\N	f	f	No	Signature	\N
175	243	88	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
176	80	1	-1000000000	t	1	1	1	0	1	89	\N	f	f	No	Signature	\N
177	243	89	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
178	80	1	-1000000000	t	1	1	1	0	1	90	\N	f	f	No	Signature	\N
179	243	90	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
180	80	1	-1000000000	t	1	1	1	0	1	91	\N	f	f	No	Signature	\N
181	243	91	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
182	80	1	-1000000000	t	1	1	1	0	1	92	\N	f	f	No	Signature	\N
183	243	92	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
184	80	1	-1000000000	t	1	1	1	0	1	93	\N	f	f	No	Signature	\N
185	243	93	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
186	80	1	-1000000000	t	1	1	1	0	1	94	\N	f	f	No	Signature	\N
187	243	94	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
188	80	1	-1000000000	t	1	1	1	0	1	95	\N	f	f	No	Signature	\N
189	243	95	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
190	80	1	-1000000000	t	1	1	1	0	1	96	\N	f	f	No	Signature	\N
191	243	96	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
192	80	1	-1000000000	t	1	1	1	0	1	97	\N	f	f	No	Signature	\N
193	243	97	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
194	80	1	-1000000000	t	1	1	1	0	1	98	\N	f	f	No	Signature	\N
195	243	98	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
196	80	1	-1000000000	t	1	1	1	0	1	99	\N	f	f	No	Signature	\N
197	243	99	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
198	80	1	-1000000000	t	1	1	1	0	1	100	\N	f	f	No	Signature	\N
199	243	100	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
200	80	1	-1000000000	t	1	1	1	0	1	101	\N	f	f	No	Signature	\N
201	243	101	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
202	80	1	-1000000000	t	1	1	1	0	1	102	\N	f	f	No	Signature	\N
203	243	102	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
204	80	1	-1000000000	t	1	1	1	0	1	103	\N	f	f	No	Signature	\N
205	243	103	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
206	80	1	-1000000000	t	1	1	1	0	1	104	\N	f	f	No	Signature	\N
207	243	104	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
208	80	1	-1000000000	t	1	1	1	0	1	105	\N	f	f	No	Signature	\N
209	243	105	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
210	80	1	-1000000000	t	1	1	1	0	1	106	\N	f	f	No	Signature	\N
211	243	106	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
212	80	1	-1000000000	t	1	1	1	0	1	107	\N	f	f	No	Signature	\N
213	243	107	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
214	80	1	-1000000000	t	1	1	1	0	1	108	\N	f	f	No	Signature	\N
215	243	108	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
216	80	1	-1000000000	t	1	1	1	0	1	109	\N	f	f	No	Signature	\N
217	243	109	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
218	80	1	-1000000000	t	1	1	1	0	1	110	\N	f	f	No	Signature	\N
219	243	110	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
220	80	1	-1000000000	t	1	1	1	0	1	111	\N	f	f	No	Signature	\N
221	243	111	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
222	80	1	-1000000000	t	1	1	1	0	1	112	\N	f	f	No	Signature	\N
223	243	112	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
224	80	1	-1000000000	t	1	1	1	0	1	113	\N	f	f	No	Signature	\N
225	243	113	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
226	80	1	-1000000000	t	1	1	1	0	1	114	\N	f	f	No	Signature	\N
227	243	114	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
228	80	1	-1000000000	t	1	1	1	0	1	115	\N	f	f	No	Signature	\N
229	243	115	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
230	80	1	-1000000000	t	1	1	1	0	1	116	\N	f	f	No	Signature	\N
231	243	116	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
232	80	1	-1000000000	t	1	1	1	0	1	117	\N	f	f	No	Signature	\N
233	243	117	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
234	80	1	-1000000000	t	1	1	1	0	1	118	\N	f	f	No	Signature	\N
235	243	118	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
236	80	1	-1000000000	t	1	1	1	0	1	119	\N	f	f	No	Signature	\N
237	243	119	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
238	80	1	-1000000000	t	1	1	1	0	1	120	\N	f	f	No	Signature	\N
239	243	120	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
240	80	1	-1000000000	t	1	1	1	0	1	121	\N	f	f	No	Signature	\N
241	243	121	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
242	80	1	-1000000000	t	1	1	1	0	1	122	\N	f	f	No	Signature	\N
243	243	122	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
244	80	1	-1000000000	t	1	1	1	0	1	123	\N	f	f	No	Signature	\N
245	243	123	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
246	80	1	-1000000000	t	1	1	1	0	1	124	\N	f	f	No	Signature	\N
247	243	124	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
248	80	1	-1000000000	t	1	1	1	0	1	125	\N	f	f	No	Signature	\N
249	243	125	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
250	80	1	-1000000000	t	1	1	1	0	1	126	\N	f	f	No	Signature	\N
251	243	126	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
252	80	1	-1000000000	t	1	1	1	0	1	127	\N	f	f	No	Signature	\N
253	243	127	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
254	80	1	-1000000000	t	1	1	1	0	1	128	\N	f	f	No	Signature	\N
255	243	128	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
256	80	1	-1000000000	t	1	1	1	0	1	129	\N	f	f	No	Signature	\N
257	243	129	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
258	80	1	-1000000000	t	1	1	1	0	1	130	\N	f	f	No	Signature	\N
259	243	130	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
260	80	1	-1000000000	t	1	1	1	0	1	131	\N	f	f	No	Signature	\N
261	243	131	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
262	80	1	-1000000000	t	1	1	1	0	1	132	\N	f	f	No	Signature	\N
263	243	132	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
264	80	1	-1000000000	t	1	1	1	0	1	133	\N	f	f	No	Signature	\N
265	243	133	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
266	80	1	-1000000000	t	1	1	1	0	1	134	\N	f	f	No	Signature	\N
267	243	134	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
268	80	1	-1000000000	t	1	1	1	0	1	135	\N	f	f	No	Signature	\N
269	243	135	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
270	80	1	-1000000000	t	1	1	1	0	1	136	\N	f	f	No	Signature	\N
271	243	136	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
272	80	1	-1000000000	t	1	1	1	0	1	137	\N	f	f	No	Signature	\N
273	243	137	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
274	80	1	-1000000000	t	1	1	1	0	1	138	\N	f	f	No	Signature	\N
275	243	138	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
276	80	1	-1000000000	t	1	1	1	0	1	139	\N	f	f	No	Signature	\N
277	243	139	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
278	80	1	-1000000000	t	1	1	1	0	1	140	\N	f	f	No	Signature	\N
279	243	140	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
280	80	1	-1000000000	t	1	1	1	0	1	141	\N	f	f	No	Signature	\N
281	243	141	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
282	80	1	-1000000000	t	1	1	1	0	1	142	\N	f	f	No	Signature	\N
283	243	142	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
284	80	1	-1000000000	t	1	1	1	0	1	143	\N	f	f	No	Signature	\N
285	243	143	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
286	80	1	-1000000000	t	1	1	1	0	1	144	\N	f	f	No	Signature	\N
287	243	144	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
288	80	1	-1000000000	t	1	1	1	0	1	145	\N	f	f	No	Signature	\N
289	243	145	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
290	80	1	-1000000000	t	1	1	1	0	1	146	\N	f	f	No	Signature	\N
291	243	146	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
292	80	1	-1000000000	t	1	1	1	0	1	147	\N	f	f	No	Signature	\N
293	243	147	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
294	80	1	-1000000000	t	1	1	1	0	1	148	\N	f	f	No	Signature	\N
295	243	148	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
296	80	1	-1000000000	t	1	1	1	0	1	149	\N	f	f	No	Signature	\N
297	243	149	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
298	80	1	-1000000000	t	1	1	1	0	1	150	\N	f	f	No	Signature	\N
299	243	150	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
300	80	1	-1000000000	t	1	1	1	0	1	151	\N	f	f	No	Signature	\N
301	243	151	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
302	80	1	-1000000000	t	1	1	1	0	1	152	\N	f	f	No	Signature	\N
303	243	152	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
304	80	1	-1000000000	t	1	1	1	0	1	153	\N	f	f	No	Signature	\N
305	243	153	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
306	80	1	-1000000000	t	1	1	1	0	1	154	\N	f	f	No	Signature	\N
307	243	154	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
308	80	1	-1000000000	t	1	1	1	0	1	155	\N	f	f	No	Signature	\N
309	243	155	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
310	80	1	-1000000000	t	1	1	1	0	1	156	\N	f	f	No	Signature	\N
311	243	156	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
312	80	1	-1000000000	t	1	1	1	0	1	157	\N	f	f	No	Signature	\N
313	243	157	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
314	80	1	-1000000000	t	1	1	1	0	1	158	\N	f	f	No	Signature	\N
315	243	158	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
316	80	1	-1000000000	t	1	1	1	0	1	159	\N	f	f	No	Signature	\N
317	243	159	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
318	80	1	-1000000000	t	1	1	1	0	1	160	\N	f	f	No	Signature	\N
319	243	160	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
320	80	1	-1000000000	t	1	1	1	0	1	161	\N	f	f	No	Signature	\N
321	243	161	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
322	80	1	-1000000000	t	1	1	1	0	1	162	\N	f	f	No	Signature	\N
323	243	162	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
324	80	1	-1000000000	t	1	1	1	0	1	163	\N	f	f	No	Signature	\N
325	243	163	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
326	80	1	-1000000000	t	1	1	1	0	1	164	\N	f	f	No	Signature	\N
327	243	164	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
328	80	1	-1000000000	t	1	1	1	0	1	165	\N	f	f	No	Signature	\N
329	243	165	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
330	80	1	-1000000000	t	1	1	1	0	1	166	\N	f	f	No	Signature	\N
331	243	166	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
332	80	1	-1000000000	t	1	1	1	0	1	167	\N	f	f	No	Signature	\N
333	243	167	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
334	80	1	-1000000000	t	1	1	1	0	1	168	\N	f	f	No	Signature	\N
335	243	168	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
336	80	1	-1000000000	t	1	1	1	0	1	169	\N	f	f	No	Signature	\N
337	243	169	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
338	80	1	-1000000000	t	1	1	1	0	1	170	\N	f	f	No	Signature	\N
339	243	170	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
340	80	1	-1000000000	t	1	1	1	0	1	171	\N	f	f	No	Signature	\N
341	243	171	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
342	80	1	-1000000000	t	1	1	1	0	1	172	\N	f	f	No	Signature	\N
343	243	172	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
344	80	1	-1000000000	t	1	1	1	0	1	173	\N	f	f	No	Signature	\N
345	243	173	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
346	80	1	-1000000000	t	1	1	1	0	1	174	\N	f	f	No	Signature	\N
347	243	174	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
348	80	1	-1000000000	t	1	1	1	0	1	175	\N	f	f	No	Signature	\N
349	243	175	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
350	80	1	-1000000000	t	1	1	1	0	1	176	\N	f	f	No	Signature	\N
351	243	176	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
352	80	1	-1000000000	t	1	1	1	0	1	177	\N	f	f	No	Signature	\N
353	243	177	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
354	80	1	-1000000000	t	1	1	1	0	1	178	\N	f	f	No	Signature	\N
355	243	178	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
356	80	1	-1000000000	t	1	1	1	0	1	179	\N	f	f	No	Signature	\N
357	243	179	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
358	80	1	-1000000000	t	1	1	1	0	1	180	\N	f	f	No	Signature	\N
359	243	180	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
360	80	1	-1000000000	t	1	1	1	0	1	181	\N	f	f	No	Signature	\N
361	243	181	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
362	80	1	-1000000000	t	1	1	1	0	1	182	\N	f	f	No	Signature	\N
363	243	182	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
364	80	1	-1000000000	t	1	1	1	0	1	183	\N	f	f	No	Signature	\N
365	243	183	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
366	80	1	-1000000000	t	1	1	1	0	1	184	\N	f	f	No	Signature	\N
367	243	184	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
368	80	1	-1000000000	t	1	1	1	0	1	185	\N	f	f	No	Signature	\N
369	243	185	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
370	80	1	-1000000000	t	1	1	1	0	1	186	\N	f	f	No	Signature	\N
371	243	186	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
372	80	1	-1000000000	t	1	1	1	0	1	187	\N	f	f	No	Signature	\N
373	243	187	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
374	80	1	-1000000000	t	1	1	1	0	1	188	\N	f	f	No	Signature	\N
375	243	188	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
376	80	1	-1000000000	t	1	1	1	0	1	189	\N	f	f	No	Signature	\N
377	243	189	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
378	80	1	-1000000000	t	1	1	1	0	1	190	\N	f	f	No	Signature	\N
379	243	190	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
380	80	1	-1000000000	t	1	1	1	0	1	191	\N	f	f	No	Signature	\N
381	243	191	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
382	80	1	-1000000000	t	1	1	1	0	1	192	\N	f	f	No	Signature	\N
383	243	192	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
384	80	1	-1000000000	t	1	1	1	0	1	193	\N	f	f	No	Signature	\N
385	243	193	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
386	80	1	-1000000000	t	1	1	1	0	1	194	\N	f	f	No	Signature	\N
387	243	194	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
388	80	1	-1000000000	t	1	1	1	0	1	195	\N	f	f	No	Signature	\N
389	243	195	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
390	80	1	-1000000000	t	1	1	1	0	1	196	\N	f	f	No	Signature	\N
391	243	196	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
392	80	1	-1000000000	t	1	1	1	0	1	197	\N	f	f	No	Signature	\N
393	243	197	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
394	80	1	-1000000000	t	1	1	1	0	1	198	\N	f	f	No	Signature	\N
395	243	198	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
396	80	1	-1000000000	t	1	1	1	0	1	199	\N	f	f	No	Signature	\N
397	243	199	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
398	80	1	-1000000000	t	1	1	1	0	1	200	\N	f	f	No	Signature	\N
399	243	200	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
400	80	1	-1000000000	t	1	1	1	0	1	201	\N	f	f	No	Signature	\N
401	243	201	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
402	80	1	-1000000000	t	1	1	1	0	1	202	\N	f	f	No	Signature	\N
403	243	202	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
404	80	1	-1000000000	t	1	1	1	0	1	203	\N	f	f	No	Signature	\N
405	243	203	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
406	80	1	-1000000000	t	1	1	1	0	1	204	\N	f	f	No	Signature	\N
407	243	204	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
408	80	1	-1000000000	t	1	1	1	0	1	205	\N	f	f	No	Signature	\N
409	243	205	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
410	80	1	-1000000000	t	1	1	1	0	1	206	\N	f	f	No	Signature	\N
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
1	1	{1,2}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuRAeMzvDd4cWqKv2uKGbdDfi6kjBdiFPRPHVGf2wiwoJonW1zT
2	2	{3,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtZXqMzYxGkWFaW8t3QmxsuWF2KuDW3xH8z9tymeZD5oX7CxrUF
3	3	{5}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtpt9Lbta5t8RLgy5SKkTZ5kcQNyg3FLWkA6XFWDgcKHkg39rWt
4	4	{6,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv71EvRZU6SdSUMnkzXjpKZeoy9ZYoJitD1zuwGWFknCfRJmwqv
5	5	{7}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv18H5xj8Er8mQ5CDQS2zeLiRPfizgNAq1XAhJWfPREu46ekxdT
6	6	{8,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuSPZ5eZ8gawsXPUDGiXSoNbyYCxcXnuETkYtqVpVrQ5WSfrLim
7	7	{9}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juh7kE4up5f2Gz7MfHxyumC6zjh36BPMcZgbYrvV56fUhkCoJFu
8	8	{10,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv92F6fmmpGabGjv3RQ11bL9rUtW2zHs6oBgS4h6gN8pQPB8TFy
9	9	{11}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvM4sgQAbYMRnchK362s6cncdqcsLPBT8vDsbqwHDDWxkGa7pmh
10	10	{12,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JufMkc8tgiYLqVhVS3QiJTCGvVaWWy81z4Sry7tCLgB6oc9nsSJ
11	11	{13}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuWboHrNNJnYXBy1nP5aUAmwzvWhJJ9GZf1q8nPYHRDnst7jFky
12	12	{14,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtnNsnGo2cmoKLQ9h2xywSuP34nVRjC8yd1Eg3H91BwfzpNeeUN
13	13	{15}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuyLnbXZ8x4sUyHYQS532YT8JoCzBHof2ADUBgcHUL6AYhRQUFX
14	14	{16,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv6Pg7iEDLcrqTSb3XAB3id5NyeZFcJUZ6bhoVXzM28r88vhdh5
15	15	{17}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuCDAa1TMr2idkkonGsC45GT1i6D16Mc3aCKhVyiz5wj3VHumKb
16	16	{18,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuaZ5GQJzMnPwNqWqvBsXsPv3DH23M8Hu5Gq6TJ99cJKfb2pktL
17	17	{19}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juwsv5TG5FPSYrreeyw7eDSwHBpvcrUcLqpHoX7B5vxbHXDxygd
18	18	{20,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvA9ZdeEYYqB8JB5XABJZbZbxyyaYvF6CjU5kz6W33QvcMVBs4K
19	19	{21}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JujGvxKsgJBVzxHADifSAnJDmWAG2KuiHj3gBa3Zisb3ytVzu8c
20	20	{22,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JusKvaTEqunL5LmD4zdZn6u85adwTVCNZnsm8rdxgDfosQxTU3h
21	21	{23}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtm8qzZ4biXUZn6fJ2uy6936WRiTZ3cjgkJriPb1Wh8Bwy3Sv7B
22	22	{24,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuHs8cdczEP2dmixGVRTDDKQkRXxdgAA2Yeex6X7FGPHpwKCyix
23	23	{25}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvNuX1ua6yJcPxTYrox2wU2ECrbYNwWhZ2LmBsH3nnqAYcgGVHz
24	24	{26,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juv1T265MqfvdmyHh3ZLVj8JF6LnQcjeGy6zauacesAfptnrM7K
25	25	{27}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuitJWKSy8MYowpxUrMfHjGYpb9prwi7PGpFmEFzG37Fy3Fcdzq
26	26	{28,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuFJobC57QFYmVt1TsMGAhTMZiCVU2LCZKPrUpvVKBsDz41inmV
27	27	{29}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuoJS4ykzEzD8vFAMRrLUhVFubASCSy6kJxuYann5kYHsZCEG9s
28	28	{30,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JugkTkMS6FMDfasxczqC4WUfZh6S99w2TXK9jrG4JN9mCkimmSa
29	29	{31}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuywvEQri6ewBdjXT53vJownGxE54oSx7qPhM9seMJ7bTBT88sW
30	30	{32,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jttx2bnvFJJv3dKcZWJJUDvfX3VWud3nPTdRKd2sBYjW69ppdvv
31	31	{33}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuzPpbMyX86fKdwbsjGwX7a5TedtwVsfHai5a8qpqHVFg2cRxAu
32	32	{34,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvLr5B23L65RRT46hW7SSFYq4UAXJUimF6W7BGY5cQHwg8ioNWg
33	33	{35}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuURtaPaUsC7fTJhAaisy2wqX6BhN29cDeWwA4qEuCr9aUzSSkk
34	34	{36,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtea1tAp5Th16pJT7K8frt9XCRiXpRcrbBJhztfDJnDwHvUG4GN
35	35	{37}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv8z3RxdVpvacbMKuZfioZH6PP1MMx1mUnEo69et5H5GjwTYtf9
36	36	{38,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuwRAzfNNKeBT2B8PcGJ6K6yAJFNRCWh3Xrc2ZhhYhQPXgDg4nn
37	37	{39}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtz2bfHyXiW4f89qpxjf3LR3oeM9y5hvmqhgv4P4gXpKsKZ6aEe
38	38	{40,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv21hyYecF5kPLh7jDFzkwK1YSP4XrJmALqmH3im6GDkYmgsaWb
39	39	{41}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvMo7ax2Z4dtxohdDJEiX6Hi371ECiXmcrgkPCo9vmW56UB7qjj
40	40	{42,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtbnhSu6Fu9qHt6qE6dBab69gXKo7Sb2LkLBBZ84UTgrY4mxEgV
41	41	{43}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuoQpmZqBHd6z1ZUAad4ApmnqAuST2VCvkeECDYbMjjxECgj6rP
42	42	{44,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuzbsPUjNW4ujvJYnSGAraQMrkPC7mk3LFA9h2UdXKq7jeGF9jS
43	43	{45}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtmoFLxx6dmqCkbq3NdSUM8kJj5YDXfqTB4AmPSkf8hBU5CXm2x
44	44	{46,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuVemCc7JHVfJ1uJ2Z9M3UwmvrqyUsYDXLrj1nnsBZsodLmMB92
45	45	{47}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuZchPrrjJ6UrrV4S3FU4ik5obkyXfvYLox7cKZotxbkzfAemhR
46	46	{48,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtdVmCnsUNE8gNf6EYQRFtc3YLeUrJjaKgEFtjg2z28frhmvwgU
47	47	{49}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuifCQkxaS2fuFikGy5HBzUr7NSQdEDPriBRPGEwYwMAsyznvSY
48	48	{50,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtxQSNLTFnVZDYAgtF1GaPuR1CPEEKrLddtY4QVhuAqLfrqGuVo
49	49	{51}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuuCrwHwdU9KFgAsnR3w6RRp8sGWk3NfrJTDwEpd6xjLJpqhT4o
50	50	{52,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv9J5BgWhVzxmCbar1RHBMDU6yXmztJ7cg7pkGNvSh7owuyojTN
51	51	{53}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtgtsZ4ptkbypgY4wWzyrPA3QnUf1t8iRddrtL7AScpve6KUjmx
52	52	{54,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvAKPvGEpa8GSJb5AKHRtzWBsXYq2QgAo2ZdfsZwHU1iPMSQXfn
53	53	{55}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuTZ2zC8RGw6njp8d8TvHNA8xX5dxHvK9qHSGZk2PnKmJXEAR7J
54	54	{56,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvLx2zV831FJyjrYJYBuf5q1NnSuoAAzeTc71ABn2xtKd8QpYHU
55	55	{57}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuKiv28Xh1DsSUbowhgMZXWANWeT1tGChjhtT5e977miRZhPH7L
56	56	{58,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv8j7SHBRhjNFfio1B8F8eEGYZGB4uYhLcPFwNqvZR54HzP9Eyd
57	57	{59}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuHFBAxX34nVffEdJ5pg1ByWYAwoTAYicPrcBNE7HvzbBaRCqpK
58	58	{60,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtxf7fVSE7FsEYQkKoeXWrviy3ftV1G2Lpcupm4WoQSWSyN9DP5
59	59	{61}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuWQSi8nXk4AppiwRdbKWK3pQVD9kZk1XsHLebhqf6FjkePnW25
60	60	{62,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv6dTanG6NjH3uLcsbn4ABVfhxxqmj4PxqxCZVfzbrptgtRYSTX
61	61	{63}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuhBxndL42ohYQ2VMEkJuZYZbdZFU9yV5XWbLNSgM4N1FD7BPpH
62	62	{64,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv5eRz7HaGPQiVChPZuoxkmh6Z2cWPCNcoHjznVtEpfJhdmVXHS
63	63	{65}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv1Gb9GMDHU3P4SaFQZsSPR6kyDLqoK6CbuZnhR9APtowkz5JMd
64	64	{66,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuVv8YsEXEHK9hZrLpVGibH7rkbthQuqaro224NnyjZjfxibpqC
65	65	{67}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju5XK8d6fF49sCJeoUpnWKvzrxmMPWgd2d4biP2pHzPNYNnQEAd
66	66	{68,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuGCn98JCJNPXMFE3vEVvMdwJHsGf11ivqQtzcuuBouz1Vxvp2j
67	67	{69}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JudwkufTtLnzTKPL7Y1y98i8iCmdVirD4FroCXakrEpAPoJtGb5
68	68	{70,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju3dejFPWxZYA67YAi7m2zShQx9vnqFm4ENY6eckMB4TCHs3g7c
69	69	{71}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvKPuYRj8ifuNxa7biP6rsAabZEasWJw3PKLF3GrwDumR4WUoAi
70	70	{72,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JukpPrHAqxPVBAVZdnnnrZBSfb4BJu9ppNvJkqbafm7KcFKcoHz
71	71	{73}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvDUB9xyjdKaRxHNeaURkjCiTY9CCk4F2Kgb9v6b9Tr81cnzeBt
72	72	{74,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtuZHcjo4no51Qn1mAgmzSNfZPziaQp2BDEQvDYbQV4nEPD8CTJ
73	73	{75}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtbz8ZsdggB8bgVe9udTWL3ZXkwpTcfMWRobUTLHvdTANNQq34b
74	74	{76,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtmadT1o2BVKEDUzaZcDmxaLopyxV2m3XEprtNfy7UaoKNLqsci
75	75	{77}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtqYvo9MPUAK4EL1vwRYzBXM44jrnEKWZVzciqdyXykqhEyDQAp
76	76	{78,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JttXyBR4fTzLuBGuJWvPA7ZtsRDwBW71n3xkLtDrzYbKUtUNNTr
77	77	{79}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juxoj2z7Qbeqq3CmRJbm7yReubB9fN7e7PSukHHLfhg977Ktx7W
78	78	{80,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuR4SDps8FEbmeTCMJYopXMfKcmrGNBun8gFWT33ZcKWpaYQ7qt
79	79	{81}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv7LG3GpZEcxWA7p5X5LePSBmQK1VaEN1h7SZaKgXY6pBLCrcrU
80	80	{82,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jurpah3rRayNGuU9VJq8r2BYg9KTcBYi9CjEJ7kZqQTnvu1SBEn
81	81	{83}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtagN5NqZyMN7F1WTitouw4prkWKxg7JPZa2GjBqmPx5ZPGqVf9
82	82	{84,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtx7y8rjiz6w23rZDpKh9W6jY6ranmPnugzMRWH5C3QdVtEX6sL
83	83	{85}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JutoSTzx7bKD7ADU45gAoW1iEqV75kFeahLGJXA1K9qBsJpdpEk
84	84	{86,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuzbJFBicb6NMdKU7srqCMaoM325B7TWYtpgB1w6j6YisabUnRX
85	85	{87}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju4agFt4snL7czyV9qRaeKJYW1zYTsddbKv8aHU4ZtNAZrp6zk5
86	86	{88,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtyrmEpFRgHXtAVUS4yR13Xnbb4PZogxyC2hQrrzyq8qnJDuWPe
87	87	{89}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JugwGhESrJaxyCGk16KuSLQw6ojrSVfazvfLt82S1GWUCMvutj5
88	88	{90,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv99rgPvhqtxPWXdX7iaJqngFX2bCD1CqGP9MGZARRKa3JvUwLa
89	89	{91}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jun8V5KrMRJ6heY341yt3sXeAPeUMP144PFHcwQa3yTXi4Npa88
90	90	{92,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuB2zy7Y6bZoA5suZsz7kfDffjB7Wg51HNahj3hvBXjAmx7qH7w
91	91	{93}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvGpMn6AUskm6izPcsDhgkq5caiqh627yMR6pdU8PmuBCRS4zWJ
92	92	{94,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtv4nkcWC7LmediwkGUBi7fXvhYj3TtoxRFm3L4jTcQwb5Y6DZo
93	93	{95}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juft48JQhxxaSySM4mfpq8Xtesvm7Vo2y1KTw9np11ArtDUZFcf
94	94	{96,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JthrpEnoSMw9oeZg4nSWTqVze1x8jUN2nwv8Ynr6fH4zv5DXDez
95	95	{97}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju1dWz7H8qy8t36CPhmwBL7VFXK4syHA1mu8sdLyDkQLdJPCL7T
96	96	{98,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvS4VXs6PnsLFnq8VBfQAm9UawpQoc9hcBEhVti4xAGuxw6wVBw
97	97	{99}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuSFGNaPBCmaMDBeE5Kw37skhukb87q2BAhAKee6LhBq567AJTE
98	98	{100,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtW1LzZVDya6D2uxwU4k5LvBuYucmATPsDwRvCH8dSzB73omR1M
99	99	{101}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juw1J4fUn9j5GMopf3KQGQ4yczfqYa1uNwVU5UyTvp7jS3wf8s5
100	100	{102,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtVYjyT7QH44atBY8ikP6F4oJtHqiwbJQmL2Hih3ETShRU36oF4
101	101	{103}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv9N2w17Wa9XnXq8DrwrL36FRJmVdmF4Z9gbFLV3A3qYCwUvVJE
102	102	{104,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtWEyWfUGqHzMiLZ9S69n8jPi2FadYDXUNwA15CcNBLgXZaNDFP
103	103	{105}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv1d2FyeidrA1Hfni6hqP1njmp3tiwqjSdecvycCE6911g94DDj
104	104	{106,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvKoHRi9RF4RfQCqCSfmRaHmxzen4sBoLBNhGJGSsFs5Zs7G59K
105	105	{107}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv6fxXEBmRvZraQxS1m2gvH78DDxUM4Ma7GueQMTH8KHu94i9r1
106	106	{108,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuvmxhMN9bLkF8xLmazx827aayMn9F4K2enxfw3jXw1dEJwvfYe
107	107	{109}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvR9BVVsPMpkuqrDRXSp72RzQ77Yfi14NnM4DVvpP2QTYBUD6pH
108	108	{110,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuN4LY7GfjZWaqZpCzVzXW7CUFMd7PbwFDSXy5NtKmnGQvWg9dW
109	109	{111}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JucjxuJ1CFDoH4yxxL9hQtDgt5Tc6mPGheCAGEvVq9osfjak3GV
110	110	{112,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtzwKWNFyut9uiNqkEYLFAoMWMDHivbvwx1GDK53j5qug9RfGQa
111	111	{113}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuYu9CoqjBZ2MCWKjK5aqq8JoivyLkhRKPy73wsowkmUdnGRWFN
112	112	{114,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JusasyyHDj67npPKgDdQRHBQGdeVBYjF2CkcMvVUNEnhykEmQ8x
113	113	{115}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtdjxD54ibR7ubrX5HvvQhB3oHpSh4oGodX5DAxC7W3xFUnsiy8
114	114	{116,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvGkDu1eZUYi4DoHw6SaY6MWta25uEFUhJ7M3WryKJAoCJK7pbe
115	115	{117}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv5dadiUUHnYjqmKavhcjcn6q5ZYfhK8CTBJRownNP6c2bRSiJU
116	116	{118,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuDaEiWVjaZTpj4CTAxbzbdkwKn3CZ8HBKPANNT7aJUbEjxecuz
117	117	{119}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuQYXv6GLrDoL7EFYJGdGk7AnuLM19eHWkFeYigghS4FSTZ5hzD
118	118	{120,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuKgcfpdVxE735Yeek95kxaZ58kkkvdcV19vcouVp4F8x2ScKDH
119	119	{121}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuKHWqESr6fPXgTc1gxqvvhBPFhkr7nKa2ngupx4Lev1C8kz8Sj
120	120	{122,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuoZepYcPTDqmZByCELqiQBjjBmBADmJawHAUTQmSagzNSpjNmr
121	121	{123}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuzR7ndY7ngninhhbCXx8PygFWEtTP28HG82YfBxFWr4xiPVS7g
122	122	{124,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju5ybc24CmfjhTNnJNrzGboETCrbQswMDKDv8FqbHSWRB8hSrTC
123	123	{125}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvADNdhHRGU7CHs7zFpp4JLT5jSc6kEXJhrVQ83meQt4phxvLuc
124	124	{126,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvHzcgDxFLVX26uuHbxopr9wwHECKbk3Yme693JHjGLjiaHUFuy
125	125	{127}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuDvdFRhGRDw1bp8mRN6siRatMZ8xiDLPk8i1jmuKt3bJMoLyB6
126	126	{128,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv1CpjFopLxe1Sm5h8dmNSN63HhmHf5ZtX6UbPH7izffMvDRV6d
127	127	{129}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtxUxk5eBBYHAsCdw5L8kuKHo7h939nyqJ8ffxsmt3SVYKED8P7
128	128	{130,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jui2EkpbHnP4HEzea8daH87czgCvQ7r67TnRvw278vAbWBpgnLb
129	129	{131}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuTJCZFCfAtRWN3iAbZaLbuZaZHVXVxf2fsoFhkAiPz3V2RUfAV
130	130	{132,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju6PyzHJHGLK3aRJBjcGt63nTQHuYtHxuofJE3nJVgv6NUdMvzC
131	131	{133}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuwK5hcSmUCXPGJ1NLkktP7PMfjqWmjAtSFzt2npHUjqUG2x4hq
132	132	{134,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuqquUrFcBHTZ3tvjYaAmvjRzSrmMCH4xFoo6s6y7aoaBRVnwNC
133	133	{135}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuZupNeJmVKz4jCWV149JqTCk1iLcLWLfxVZxhyGMaXxNPpihyB
134	134	{136,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju6JH8bqrYUmgSUmvExipUCVneToAnPeyQCmRhpirJ73aJEjCLD
135	135	{137}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju1zFhoJuVggzt8DEDLZh5keVFX5H6WSd5jGtNae1ZnYZ46QHGq
136	136	{138,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuqG6WZzqKPPWiaQG7QGrQaM7wYPPmD7jPKu3wpVHpcnoECPfAQ
137	137	{139}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtbR4vMDc4gvuwPz6L26kAP6vGqQANnymQZFFjqoJbsHFSyjLmt
138	138	{140,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuMfoAVF4P4yczDKeWinE5RNVGTwEoqY3YusF98Qzomprot3aBX
139	139	{141}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuhFFSD3UuVxnSkijtYAVxKJYPg4hGzYQNAP9KjkTqxZXiHeYu8
140	140	{142,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju5mW4AhtG9AiKMDqitpBX5D8oXcakEvNtiqaS5XW6MrGfAYDnA
141	141	{143}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuzGTn9tZ8C26p69LhZFxvgBgMhz2MXLe8vDVPVS2Kf8ctKaZmA
142	142	{144,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JutfYAwc7T1vftBmGSBLT7tmQ1Su3ZVtec8iQ66GRej9VEVmA2d
143	143	{145}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju2t2SAFZqPacPJnKMVPy1cXmXSubE6TvtEw1Y2QZcuPiWqZjrx
144	144	{146,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtXwV2wb7BLB9LPAmEUrbJC1oEwmfZUWWvrxjBbamcfiWx9VRYu
145	145	{147}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvHptKA6anoZjRPUtxhVpAJVUWiP4a3i15LymgcoyoKuptSAvF2
146	146	{148,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JueY7ojStS6v7iKeq4u1iP31kL8zmfAj9ADxjctjURLcF9873sd
147	147	{149}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuAy5QBi27T6jFn8uJqVMHc6PtLsMaqYQtNy3wFHwQvgXxeaTyP
148	148	{150,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv1p1Q7oTs1Dsg28huAgN65StX5TKBJLiLd9jM4mwfr6htn3UEY
149	149	{151}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtsmM4bqGmfqiycAy2nj2wRiouzdrY8cvjYjGkCnbfWfcDdQ7vb
150	150	{152,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvBQmYHSceqTtPC3YjuD1kR7ULhT6tVBDAkdjPDNsrNdKqz8AFs
151	151	{153}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtuC8QEsVKEdVnkGL1nQ5kFiebrsr3y4neHqpzRixd9fEuRt1BB
152	152	{154,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juu1VTEG5YdECbrpKmBcsoJZRNme9zNisaMqagrcF3zE7X8broH
153	153	{155}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtofHBawq6o1W51XFCuG4tWxqDAhBC19MkkyXzZSjpc1dbtxduf
154	154	{156,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvDwrxe7g3y6joAk1DtavdctVuaGA7RxAq1PPqdRd7Co8AkFEEG
155	155	{157}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv2pnfVfJS8VFu1rbqhot3MeUbMFpMqm5hvoHuAeeAdEqS2rxkD
156	156	{158,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuvuSUXk41zCmwMYGdg6SexfPYuZnPULetk5kfT196pinPQt3V5
157	157	{159}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv2q7F8VcDACey7KGeGbFCsHdSEKk1ad7WMWcPyaWywrwfyfbNs
158	158	{160,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuQ9hvokMPpN2iJSs9Xa1pxYgqKMDHYyr4fET6wuBcPMwXfytzD
159	159	{161}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv6TxRazuXQuLyVfxh4PCVeZ6vxAW9EpbfFLM1j5whARpmfv5Gx
160	160	{162,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv7BA2cVNy82ULZC3cKvikDV7ZhiJG5cw5WsGsZc7Zq3eft8LAN
161	161	{163}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuKVTzfWyTADTBpHwYXeDzoa3p6erz9P9U6jiLUbFyQuom7AKcD
162	162	{164,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuehHkZzkiRaViXoZWTpdcqvtTHbHkBKaocRUkVbvZo2HVV6tMH
163	163	{165}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju8Ceg7aYDNLenMUFYyYJmct5e874PAUMFowENNBLWAdkELWCzq
164	164	{166,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvA9AH3TqTV2a5h6vG92nG23mpyzwQ2EotwtQmnRTtJoQFebRYV
165	165	{167}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuRXdo9Nj6oZnLZybeKzjbtJQbBbjmb6a5kzMo9SovWa33PNMHP
166	166	{168,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuPLsYZBEG4c6ESbWSFJA97gnxW7YtqrrRusx1UnXkk64ez2HBY
167	167	{169}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv3jMk5ez4aTtmmJ5owcVVU9CwwaLBaYNk2SfCkdmL4HnpHPc4V
168	168	{170,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvL7FDqEbsT9wJdX2ewSUJJjLBMiTfYRFSAMcNkEUok16dfyXNK
169	169	{171}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JthW3W7Hbz8aitXY6hpd1QYc3qTLLWiN3ejvFWvnfM47R7gccir
170	170	{172,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtzhQaGcgdiDKDn5JjHwTP5pbuQfZjQgMNXugkfdBxGK2uWZoz1
171	171	{173}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju1Y2z6ZXsJeBEA5psoVhHJyB3EX2mB5JweT36zx9CTQAeHz2Zu
172	172	{174,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtkdaWjDiFpwhogMDHpdPcGvj23TBC4JR3rkFWc4peDWnN7bAwa
173	173	{175}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jugd2vW2gfzDhXxFSdjmm3HYq7GTJnEThFUaDWEPSsui75Po67K
174	174	{176,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuD2HKfAk3EzRxATqMF81bRnbnT3aSw6XjifK1vMraa51e7VJhz
175	175	{177}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JumdCXsUqPABJjuns94RXmYzjf85WTJ6RNqz6kDVXsSo7nnGv1K
176	176	{178,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuqoTDLrsX6w4FRUkBDpVQ8kDpWjkvriRx6PiMLCvFLfqbGYNJW
177	177	{179}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuJdTxnpSuoytaWLejyR6UE7m7nDv5CkHQrJ9CNHjxVk3mHKmjy
178	178	{180,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuFtADLNeCBFEsbFiaoNpRMify3bMGvAmmUzhfiZCnVnrLRtvGX
179	179	{181}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JutZMVJHqHw21w1TWPbJQKCPMqi3Fe1mHKiW3Ybqn5VSGwdvRhd
180	180	{182,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuRRVZHJKwjzS5ftEPz1MFt2zP9k7kw5QhGhdgtyHUD8iJ3FUFK
181	181	{183}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JupZVQXdZH1zS6JfeYpT4ghkgszT3sTRL2L8JggJoXv3Dk9MeFE
182	182	{184,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuN1aGLbFxNqKv27iFeBVPviJid9r8adWX63NwDnRaFg9d1xWUC
183	183	{185}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvRDNSXrRHvQTpe6K4jnPphpqS3xzzAJM9fARcEuVEcdr7PYEJe
184	184	{186,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JttX32zhCi3TAdtypkp3YHNFBvG7UnHFRTmFxstiZboFpXoh5S3
185	185	{187}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju6aK96WUYPZa4osLpUJLWLxdyf6zgmMEeuw58tLJszSAPbNYi9
186	186	{188,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv81xix8GEKzr8bpuRGiYzLtD4U1YGKjCPBJ5j7DXE6VfA7zjFb
187	187	{189}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtWm2VrKWsSWVcXmZutqQfzSjWfTUGYvYdbDLNqi3GSLQcoZL7b
188	188	{190,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv6A4K6mgtjDqneHC18h2jzr5o6m7AvCDNiBzp3wCRPLJVjYmns
189	189	{191}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JugBbZaGwji7kBtRR9A4a2Xx1bCUQhW4RVWGaXqtQJ6qv6ouKJq
190	190	{192,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtgHsshawM9gpyvioP6MYL1rLwbKsfdqcipcbFVCXEGt2Q18Trh
191	191	{193}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv8kET21LjAbtyT9d9ETMqaVTUwh5iwocNX8ihQJ4Ly6VtcF6gt
192	192	{194,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuQJEYjLiXfHbyBAvaSTo6xbFGy9Budi4irDCHKR7GLUe3nCxPZ
193	193	{195}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtj1C3bQEbs5XDJEzbAiVxo9TLr1AHHWMJgZAavMApdY9fbBRZm
194	194	{196,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juyn59KMsVxMdiyk4cUDZsH1CfywKsBwZZRBn2mXBCjEFJCpbsZ
195	195	{197}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuuTWtDDrnUxXSML3CAm8k38HEipfbHurqfsKwCGhYc3iBRJNAF
196	196	{198,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju8BgwNfkzpKRB4WsHtgXpQcYpRV95YVqanvEPT4pWc1RESk8bU
197	197	{199}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtp3yaTmntaicpPqxA9bxYogMP3HeETgPTpuGBLUAR7fY2enoZM
198	198	{200,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuDcHDRcgKR3NR42N9Lf75WT8HU4xUxzukjnpdc2nct9rQLgTbi
199	199	{201}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtdsCfBNxqURweN95jKAfLEVRYkpcu8EXgoSFrz2SCzDo8wk9nF
200	200	{202,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JteAM68n5ZDLWLpofYyp9eGaupj1QuvadRvb6F7w5SbaKDf26Tz
201	201	{203}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvJsfW2KQfedThJ1Mb7YazTgPNy489U2RZ414RE8xxqNrFFmTzF
202	202	{204,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtgTNRWoyuUddwUxUuMAvUAdgSyttQYBsk4wBZFRQ7dayUn9ETu
203	203	{205}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jug9YweJRFmmk4FUMfMXWVZUpWKiAfUVN91ZujjKd2qy7mrVdYb
204	204	{206,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju4jUdFjG91GgU1TmJ7Vs9AN4A3HYFh4DzStj85ocxAtVuCttsa
205	205	{207}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv9cXbyKobvcRMQNXRVnWNdtJ9HJWGUnFcrDkVsM28ez4ipRco7
206	206	{208,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JugkV7whc95uHVEd6K57KESNVhCbdFCrsMSMn8jCX5h1TYYqRfz
207	207	{209}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuPoAesfesmWkXwqE2gNVLwJPAPnGMdCp5iqBac4otfRQCfkrSD
208	208	{210,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuCZtCFyyTm4PriG6ybjWCNeGdyK2ufcvXHh5CnWGsxWJf7YQ7t
209	209	{211}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtWjUqGMdWm61yoBuDHDxMy9BbrXdfFAQTaSBHCH8Axu7RytBef
210	210	{212,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuP9K5t48h8MhmWAHE23kYsGcq6Z4hKhAa71xADbBS9GfuHwLBG
211	211	{213}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtf1jK46d6cb55neqmwbVxe5knJCKSmWbQ2DNJtGL94tjLCMii2
212	212	{214,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuAcuxWLHME35r9Y3E83MsY6t94dqMqbbXCc95xYynF94jKn7ut
213	213	{215}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvLrpzXAovcYXsrXp5C3MpDEk4BrvC2Uhe5mwYKgWsVhmh6NsCn
214	214	{216,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JufAjCsVFyeLL85dD6Y3BkSDYqZvzbMQEN6T6FVoxkQSFqEn5k3
215	215	{217}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuyTqjN3feBmKwbuKERz9S6c25s9HdGY4MQRSSAw4ygKMHdV3x2
216	216	{218,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtxJ3mEKtJe7kYWoYc92oyo24Qpb2DQ3QuuHX17jsNhojPZ2wKS
217	217	{219}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JukfNvw97pPoz1EdhATpNXuLAXajNABfXs211Jh6Xz5pYJvdnMq
218	218	{220,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju6V2U3xxejmGCPG6fedmoURyjN4iE42zBcuVHxAoN888LMsCpg
219	219	{221}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtVnxBquqvGAwUmMmfoMhAoQ1TtDF9Uv9goWKenRTpeFopRYg8L
220	220	{222,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvHyyTpEPBRzJB3HQ8NYXfZbitKg2hsVyZPYqTZabeoQKnoamoM
221	221	{223}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuSSbTwCNft12QPRGH7URbGy88vonk9U1DshKjschCpRv7GTvGR
222	222	{224,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtohh4nmFfoToiBumCVAGKFVAV2kUQaW35s121JhDSMGiWzhyKJ
223	223	{225}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtgh1qgWT2TEUqZ9va3U2DePEB3TeVaLjx9zkPp64cFdanXK5vj
224	224	{226,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvDbTogm2Zt2xwbyfDzcnLJLgkZW4uSNijx5MgpacqL5xd8LWnR
225	225	{227}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvLJepgiSbmv6wgSNSoAqQ6FmGfmEWWC7LVMQiy32rnBLgzg92w
226	226	{228,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju5Gg2TgRPQvEbyMR8pBGETKfuDd2V969PwRYmWgTgXRiVnyZxU
227	227	{229}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuFvrHStV6SnmQETAiwnKWtrDCYi1x7aQ5ziJr3N8iyPhmTzVLB
228	228	{230,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvNNJNZuP8F6mwge7ypjyYDhjDZBccc2eveeS7x7zxpTPBS6wNn
229	229	{231}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuJ5mH5vJ6MfBVtQ6dVGU8n55Y5M2gKrFyT6vJJywhLfMDM1YW9
230	230	{232,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JumnRXciwGet4SBptixxGhVgc2ajmpVSqF7JcRpYkXTf1W2GrFQ
231	231	{233}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju5Nr7AfbGMiYLaEPHwki5zL76FBtfFAJNJm6ahWfkecovNv9Ly
232	232	{234,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju8gT9kVtVSjzWXqsBQP4ZeqCXBqrWDYEXAxuijMTDQhRfjXyQ4
233	233	{235}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtZBw8ZBk9feMz6K9cZ5wCdgqs2kHAJyi2FiHzkjjqZvi1GVHHa
234	234	{236,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv2TyWD3xwqKxZgQVf2yQjkjTWgtF5avAKcnx5m8Ur1UvoM5QgJ
235	235	{237}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv5nSwAQJFPH7zCwTaLuYK7tmLLahZ3WtirrKZpSmSarSgyzY2f
236	236	{238,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv3PaE42KRNKML94Z7g48XFFukY8Nj7AMPht7Zg6GfVN37ER48x
237	237	{239}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtamjAiZmxg8RVuDD2D3LoQTVzN3YiUenjdksJRjkMMJ8y5iNby
238	238	{240,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtzAP3XBqjHXw5Lp4ZetL8zYy9FimYd5vU7g6B5tgCA6HTiwqDe
239	239	{241}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JufP4N1VREH3KiXn5pdDcvm2HrWntPkP61qg6zjS3aJkY7RhfMa
240	240	{242,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv3Vexo5P88NdQBn8bU8F3bBs7zbrHHSa3T29SHaCC4nbRifxyu
241	241	{243}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv7e4WUJQbMRB6LgCq7puvQhkLy5bk3rm5si6iGpVk1oBCeMGaN
242	242	{244,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuhxwXRcAa5kEUY81LxibdKmrEvnGV3h9EztmWgtJTS6etZUo14
243	243	{245}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuwC5iARFUJf33Bfy3XbT9QQAkN6h7g5sRmfhB4BogD9s5rrbgm
244	244	{246,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuNKtd9WTj243tyyPUhoXDVsmmPKirDKF7mTs2cguCsgskf8jSz
245	245	{247}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuctmG85KxqsPfx6jgdaeV1oT93pgAY37b2s1Krkazv9Jn732Md
246	246	{248,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv63xU5BbXZQFP2uBKFUCkxFpgbnftAE3qfLteKivHxm3r5Dpna
247	247	{249}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuLu8CSfKYR7YowAWQNXhLQ1dVa5Hb1MizPd5rN7RY53aK1k2AR
248	248	{250,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JthPo1nGGQeWo7H11oZziUVo5g4VjmjdEkzxLUUSk5DrN1pUjU2
249	249	{251}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju3vbUzBZUAbyZ8LWKrsjnpijtT1G1T56ntSAA58pyckzvxcC3z
250	250	{252,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuT5W76Nv12Qc5o2zPv8HBfVrC8mMRoaGCUZ9WidTA9Xeoso2MF
251	251	{253}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JucoePsYcC6jeNgUfso8anNegbrT8rr8qAuzfWNMVRwWTZukeLf
252	252	{254,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuEbHpLPmnc6uhpwiqb97tmTNu7KHig5d83UeWZK7tGgKKTegc6
253	253	{255}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvKUquBkZZzAy93gRo3ERyhiZ2zB1ZDZCm8N8LEZdgZ1LQDri5E
254	254	{256,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv2aCzNfZdAiBfyJWF9aZtbjHvt841PTtjF7XGVDUm5CwtW18RW
255	255	{257}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv7Lt9fNrskSeC5CH2PfgLfHCwrDsPHMuGX4YB5uSsbpVCNT6N6
256	256	{258,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuQ3gaDqSbUswhmqrcx7J5A4GfuqAt8xdjNt2UocbM5UtMqdmnp
257	257	{259}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtgwGzoUux47AEXhHFCmfBrYmVZ39fo6y8nxPyKnk6W3ToPP2dq
258	258	{260,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuMHpeLsSUE8hTgB9JWmjRa6pJyLVbywJkBHrwVrRre6ZbacPUF
259	259	{261}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuuSAQQHKmKq29GNijqYRyfJhFioAd2sdGLSDWv5DZPtcwnxoA2
260	260	{262,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtte77VUN23jeTJMq2Dip5CVqdi9jYq6dUuNYJXNv3FLijoJsEh
261	261	{263}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtWftgxwGtuGbcmP5iamNrwHdHEisRhA8gufesvAeKjbhxmbkR9
262	262	{264,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvQXXxqkxrTKC8NNEqTtP67QY2rF4hgUG1iZyBMSSeBjjZh1tii
263	263	{265}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtoiPpLeBUWGgzeE3pU7Tfoa6vSXHB7vWUwegADewzKKNAnvpqA
264	264	{266,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtuRMSXjE2i9RW99rTkqZMoATuxZsR9j38qhk6mQv5XBDUM3jx9
265	265	{267}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvLYhRJ61SrQWsV76kR6WmncTkKbjGipMufGTfDbgEdXe6bFBo2
266	266	{268,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JutDnimgJLZx5RWLMKkSG15riyPsVX9PtWaQvu7zVkE5DfzGcxR
267	267	{269}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtd7WkAVZ6Fxq3bsj4ZYE8HMj9Q4V2pyJFVp4DfbcrHbUE7MGgE
268	268	{270,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtaX31ZzawdXxJpaXoEmsA6Duh8TkM9ZAEJhi2qJgtE5JSaZCJo
269	269	{271}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuabdPqCtQuPA4muPnfb8rzRAFxo291mUWmd21HT5RaWrtAhKtu
270	270	{272,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvLccZhGvvb1Ldhm5NcWKVh88Yo7sQCGp1Nc9c6F1XFBn7HSYoZ
271	271	{273}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvNqHeYznEUkoP1URPXdSuKSX74w3Mfr2CnuDo4JGQtvib3k998
272	272	{274,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuUJSkWNPEkoWLf1WPNvg7JPvYgBgez4nsJbEQxj624sGWjE35k
273	273	{275}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtbxDVQkX7HhpTs14J1tinQZLpB2fBSehYkoMo7J3xqEmUu4AEU
274	274	{276,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jurc6snj384ysW9dE8GBwEnWoLUM8643XGPQNVCnzPLw6Uj1Gez
275	275	{277}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtqAP7EZBcLSgpUxPZPxRE8hdKE6LqfecYYLw6dkYB1SfJzvZdg
276	276	{278,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvDTYmMk5fGJErGp521BwYQLcWoscPJVvyfRe8z3eFxT73aBsET
277	277	{279}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuhTkqXckWGvZU5RYm48QpJfZEQeZxhE35GySukrJHM7Y4EmKsD
278	278	{280,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv5fFcs9xgFugrhhYxJeNF1jfbDbAWM93i9ssGiHAX2tYnRN9PR
279	279	{281}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuonvQtHQaL3FGqFbzAhCUnGg91xnKcuGyFqJ6pVyqmJ59MhK7m
280	280	{282,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuGMkeTuJpxqpagxH5jhwSK7dqKowfbpV3Du2U7qU2JFvDjWhms
281	281	{283}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juq6jzzbCoYFM9vGiQkhHspBEUNrTTRwvJrqkqrdKALopT7VqWE
282	282	{284,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtj1MuRaZFhufKMSv6Rf3cRiPfsQju6Pz919P5SLSwSVgXkotQU
283	283	{285}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvNqTdo7ekubz8imZoeu1wJafZcnp36cFpTJrQfjDtguELNDW2P
284	284	{286,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuS8s4usvtX5stSdGFVq3bi53t1hvxnJNr7NKxkiECyT7TXNoYD
285	285	{287}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuNkR9YEwcN4ZHKGdAm8oeQj7XG9yayWDTv7VHuYf5CuqUEE1WP
286	286	{288,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juvt6XocFq3jBCzJAe4PbkAKw53Rb661ETq1ru7ZVowJFseekv6
287	287	{289}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtyWiu6K9JbEp3Cbp156UKLUfahbG6Aqp8XgM5mYAC4YtjvhbBr
288	288	{290,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtu3RD4kkXeMv8n8SrVGxaRV2xTH5i9cyF4YbhgoBdBe9nZHTHo
289	289	{291}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtsiRK4sau4YQhvy47ftHJit2botgekTvHSToDb8QjLM4qTw5kM
290	290	{292,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju2mfwQZXuBNrSwQ5BjhKUvTEoAKgjZKgQes3grTk82hAUaB2AT
291	291	{293}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtzerTfKDaoLZEYScWUt3z3bNUNRBUa8V5mW2Zx76Nir16URyTc
292	292	{294,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuVrrS6B7XRbM7ZA1yd7CkqBggvpsvd5FFTKa3udBE6sqscuZ5J
293	293	{295}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv8717mFu2BaaMgJr6PChuoaxtiDVjvmpChkHp1TC7FTtusQzgU
294	294	{296,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv35AictSKMjPN2rVBxzfFG7asUqVKNyt7M7w2DaNoNKzCMvXem
295	295	{297}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvFcdJJpGRUKCUS3Y1osVkYJNxem5copavDJw2kvY63XzwQs1yQ
296	296	{298,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtyarBHExEoKznubwjQBUXJ3g61heyrqC14kezksr3EZpXvgo4J
297	297	{299}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju8UxAu986ghigLU3SQpYqXUSyjsng2a6m3xXfKX3m2NxhBHuo1
298	298	{300,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvBXJrTePFQkp7WmgAin4koqumPzHpbRDtsSQrNeYx5acnB3znS
299	299	{301}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JutnxgHDrv8w8wPR62fJF56kgVwPqoQcK8yE2s5cScUF6SXKMR8
300	300	{302,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvC6nBmxGFLmNCWhhGBQHJzvrKBUymzaGSDZWdwQNbkSjosFTPw
301	301	{303}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JujWEMYUT4A8Qpo7pYrSVLFPBgW7tEc1xV7YCazSksCrUF2KdDB
302	302	{304,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvL2YEEi1vfpGGe8ZwUY6s2F7XfKp12Aw4EUAR8vGkYW2TG75qN
303	303	{305}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju6eRWpo48934zgVrkHmy8tUDz731mcuZ8zM8GJjBR9WP7Tpw27
304	304	{306,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtxVFn1FrdjjQ9aj8H4yPu5YXWAkwqjvsGRoXHM7v6CpYUNxkjF
305	305	{307}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtdDzGZDtAhDRfsRr3YcQrXkkMf7gqMSAAxfe6nV38gavcErFL7
306	306	{308,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuwFCcyYKUGAMCYQC6HKZaUZqLrHe9XqQL2apwfkhZWFUFah5nf
307	307	{309}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvLiuV7cpo4EK5vDa3sBsNoWGoLhyTEn63fkBYWCaNKMAaDHZqs
308	308	{310,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jufstqks9eM2ocXHcXta5Y58D9hapBo5sVkNa6nLxHDJ2sfHadi
309	309	{311}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuDoCGLwmU4q8czPxZmiZpwWrk8DPqdRyocu6YwBsp45paMEi1A
310	310	{312,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtkTHAQeQHjd321ytwQLu9GwCtqGuTg48jB1QjrCD1SLKCHVsf9
311	311	{313}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv1G5UVfDnNsP5F72v361TxY4oTPH4cJmzeCmPdK9FH93XqTrgh
312	312	{314,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvLHuuMUzGm2FmWwPLyaGUFDbQNay6CUtmXEEEQn14hn8GTSnP6
313	313	{315}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtZeiosihCKtB8DFPA2GHEDsGPucoxYjNy1Yb5jPohfmEsh5rGM
314	314	{316,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtsFPo5bAJogbbfThmtpWoMxsSw5SS9swU4ALBCcxXBaaVkjfxS
315	315	{317}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JubvzYGU3g8UomhiXtjdYRUeAeMJgwstZPSBzqcWh2uyoXLHUkL
316	316	{318,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv1pb3nmJuJv6Uz7iivzDVXvfr85Ln63eCCj3E9FkuBuLQQqTTu
317	317	{319}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju248erxWwUFq5CxkPnrq7GhrwK548XHT2Gh5nsTHcJC3F7ZSX2
318	318	{320,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtuVFMWPLFuma3sos8VrXjaTb5SsJdqciVVT1HYSHHjb764Lczq
319	319	{321}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuBjACxJkT9Fm7ySSPno8rG9izrJFe7xgY2mnXKtK2vfpvJf7MK
320	320	{322,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuXds3nQWT7PBpaSYsDBqQqTkpFoFVsM69KjofFyHSmYqpTBbsS
321	321	{323}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jue4GoUq86RL1CC5ZP4yQgTcbZZyvQv4kAReUKuDF7E7YY7y2EC
322	322	{324,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvGRKToFLofAVA3M9As1sK5RvHysoPdThGW69JSy7Xcqs9LwJsG
323	323	{325}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuRgPN3qFX6CZXAGA8YRVvms6FZDs6Q3aWs3ikAwkiw5pqFSvnc
324	324	{326,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv7Q7gGkLRkCvASAb83KQ1rytgHYMnheLZDo8i1JKPfckWde8v8
325	325	{327}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JudnLNNrNfmWJP2fMkzQpRJuiVR9LkTHroqGQ3mXL7ETkD5Mmb7
326	326	{328,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtrT8LjgcvBBXx3ZQNS99ameCrp1NTRvyvo79cFiCHpbzwaB6J9
327	327	{329}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju4K7XmpysWsPSbH9Jpog62zpAB2333ELZtM4tXJtkMiC3Px1bo
328	328	{330,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtzDxUPx7wmMqdBb9cs1zja2QBJXTCuGoks7z7DLr1vtBB3mjBt
329	329	{331}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju1VtbgxMuqdYw8FgJWmDB9FFvotRSVu3d9LyTAnY2NPu1LrXrT
330	330	{332,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtuRa3tsoxsFB1ho7gt1EcTV22ayH3KWvQaCmB19kfhbD69ABfS
331	331	{333}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuQZ69YpzAXKEjUUuo2nUiin3o2uawnhTmhGbATuCu2o4Ws1ftf
332	332	{334,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtzbE8vDc5Z6Yq1PVVf3dSGXqM7tnkYiDKGA1SXy1TFUFX9iGqL
333	333	{335}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JugPhsQNQUxPqZ499DEwLDc6UNY6khzoDs7kc15kwNnr9S4sScs
334	334	{336,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JumBki8ZNfNWzfAUhQTDsRxFJD8TionJLdQcBpnhuj8CHHaWaJy
335	335	{337}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtxemM8Wn4Vcx6s4SfowCWG5EQpV1GArMf7ATEPiaPoBQz1MN1G
336	336	{338,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuwpF1Myt3ZMn2Xu41AgZWzxH12eaPx7EM5gLMKKJZfi7NYqezs
361	361	{363}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju1wcXmheH2sm6aK4ghEo9BBf4sqVTDf8Zj8HR5tgJdwuNCT2dM
362	362	{364,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JurxHPJmfP5KmRCn1fQ5P8uziSPqgoY7yekqUXiWxp7vPrfwF5T
363	363	{365}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvKcuyJw7BXCQ5tmGXVFaKk34y4irSeWUUf3uWp7ue6vYz7Rzfk
364	364	{366,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju3otqLdo3Mbc8Ap7vUfb2WygFESDjsQgCA3wRrCco3m3GHXwho
365	365	{367}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuPQLFiCd8LCmHFj3k9cEwigW18jn8P5Jcb3LiQQxp9aQmXgVs9
366	366	{368,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuQYPz4R1TkCbS6tmRqdNEYkqMDV5xmpxiXuf9BCTHbqmYbXB7J
367	367	{369}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuNHbiGfUomrhjhP2kWfR4NGzY4v5n7XEaToDzRtEhegEaTNwRp
368	368	{370,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtW76HnA6JaYEUqSUPxMheaLLda2d4hykjePqpCaWtKLv8c2Pnc
369	369	{371}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuGdnffS9crzUTNKfpKpmm4XQpACQ78EZezLgczypBUcESH4e18
370	370	{372,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtmDoUPYbHoWiHyPHFfQbW4fXEHsAjeJgjSSR6wg1vaXWdsmuAf
371	371	{373}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuGtvikMmuJtGnS5sDpc7L8rs74bkYWXTUiRY47ekhDQUsdXrsz
372	372	{374,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jthm6KFhyS3vqF5wdy7q6oyyJmPd8bN7f9nANqtBNSe33pbbaP9
373	373	{375}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jupau73r9oBUZsEAm8J3mGC36zRtJmC53v53yeYAJzqL64Mw6Ts
374	374	{376,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvD3a3ediygBRu3NYPL7woA8qgPHfy8uTHVbCUBHjZvsq2zp2Mx
375	375	{377}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju6vgDpne6nJF7RKnVUvJPe7TvBHiMb7a5BbTXBgzLkS9W9r8BR
376	376	{378,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuwWWV4Apkw5Z1D74UcKRnsn6Kn31J7FsQNGq97tv1BoKBiHNct
377	377	{379}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JthuDur4tqDWJL16rBhqriET1Cig5goq3wj1VqLJWzVoTnsRDZx
378	378	{380,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtgkRr6XnUTDFLdu1Y7zbKry3ZTtb4L3rEVVe2apaXWbVDhZjiX
379	379	{381}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuuGDNAZtx1UvHqTThNyy9CTS6PRkhT5g4BGo856Tfa7kZrGMyj
380	380	{382,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju5izD4kskpg4X9a4avpx9FcUm3Rw9AzpTpy6FWwZ2oidyAs4hd
381	381	{383}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju2gUzVM7ZonFQcZwnnC7L95rooQF3xxDJ1S1vCURHT8RCXMpvM
382	382	{384,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuwjdBcxa6qm1DXyd7sHG7FzRgA3NV93eRqsVN5fwxiBFHAFZ9z
383	383	{385}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvRp3nPfwBcjCjaEMjh8PMgpCbR72RV7P7WGX12ZVpcWHuNsDNd
384	384	{386,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtWDieYeoTrtfxZvTL4V8DJ8cw3GzhrdLeFpwbnc2chLgTSooGh
337	337	{339}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuShJiJpVEKdzCSBg2LxeWuavvnKyVnAV2tutLzzSS87DkS16z6
338	338	{340,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvAu2Nut87ntTdBUhToRSruAuZhcKungeYPjtNy4Z1FTgpCadcA
339	339	{341}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv9jE7DFm2ewgXkSmxFz5jdeSaGKjfiNxQXYPpJecWztYXAqzFq
340	340	{342,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuL6AFFMTvmbSzrbznwjjLyFJrpFx9Rn4KGc4scDj7x8rfzDsoF
341	341	{343}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtadP8Se1Ddv9R2WP1Aoba3dsoC96yEaxKddMGpAwDh7tX6KzMG
342	342	{344,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juk3tgC3KmCJWsdMPGojtAY2tidS7mMFMFezAWn7QHRRzRmKM5q
343	343	{345}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jux1Z372Lx5v1pZ5j2GN1r9sgKGAGFbHy7be7NCUZTF748kPPF3
344	344	{346,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju9PjhyXGU5xoAWn1xgqErmr5moKSH2Usa19PBjk3BCyu2fJJ5S
345	345	{347}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuzQGfsmCi48TGpywkvkqVq1mPBRwioWKtXg9zJHzVYXqvHTgHN
346	346	{348,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JttWFyEJDQfTaDaNjF3y2uRoEvYdMpmSyca8QB4U9odjL1q78Mh
347	347	{349}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuE2rUPGi1THAfctuSWtuJUgSzeLzHbHycn9SboiTFf4H2vuAS5
348	348	{350,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvHbcqzAWsFFPYvW2RPpgugj8tDt7LPBHAr8shGzqZRzQW9A6bb
349	349	{351}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuoEYQcC9VjzAa9h6mVpFFXogQ6MYm3ySNkS11tJiQAQhWxpPLQ
350	350	{352,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuwHrsakBrRCpP2x9Fr1ebn9cafTRaW7to62FXyBEbsWEX5cfkg
351	351	{353}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuVxSA8sgyvEyhj2xs9hbmuzRoSwsvGsQtNHHnMmzaBXBtoG4zM
352	352	{354,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvKCP4ts9afuU76s1kwhHiJZ98HhXVKS6cVBSwov3GJqkzXZoWT
353	353	{355}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtj4A3w1BrTkUy6d3MKwCoj1gdvWjPugpfCYBq9LwnS8NfJNUSk
354	354	{356,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuNtWDARrRm5QUamb8fwn64ohVHRwECY5sg4iTiEncwT3QtcoBC
355	355	{357}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvDDFP7GJ54dTSsHmypE2Q95RLD9pof3KUYCtZMQYrGgopzXrQ2
356	356	{358,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtWKSMMHWXA6JFPM94CGaYAaZujC1RUeVLYcL7jAQxFQekDGnwY
357	357	{359}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju8fbCreM4PR32fmGxUCXkNiXePGw7Mrtix5BKjsZ1MPZ89GDY3
358	358	{360,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuJzY8gxRQGHezyrpq6w4uZQ4kkb4CZMrzjPoTr1isyXy8ya3Bw
359	359	{361}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv9xeoH7S83pZW9Jp5MQP16hQRtafZSv8fbMBrdDZqfoRnGovXH
360	360	{362,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuPhjNYbjTnwhLM6m5U4LK27hcFuDdMnPzzFFcqAFt5LbSpe57M
385	385	{387}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtzeY7M6TPDNKpG5C2xW5fc2BbS86xP2B7ep6dX8MqaPVUqj7jj
386	386	{388,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuF4AgnP6wMPEwqDFaHtsmaKXkyNXVTZgtySNbsVNFS5gb8oaSm
387	387	{389}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuaSktuCwPKjE9inVvc2t69k36MWV6KVz4yNaWapgerFY5RezEY
388	388	{390,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtxk17x6HUSNofeM7mTTbEuyTo6i1eu1fvbuEA8USnwFnQqU1VG
389	389	{391}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju7uHvWmmyiPJPNbmt6EgKbAcJTHw2TwvvXeX1UkhGzWubV41WB
390	390	{392,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtixwqiyvcwWRTgf4w27nsWgqVscf8GcR7U64jxQvLR6gxhd8NL
391	391	{393}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuKDX2aakKLB2QKtgGBvX5eYDPQmNCirFtEb9YX5Dw5CFbhmFx3
392	392	{394,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuoSpjbjoLTvKtFukL8RvyvQxNQFCXTJiEdyf6x7h1ZdNLGEey8
393	393	{395}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JueBfSod7D4sdvQYANuSnLQEAMXvREQBqz1AUtUumZnkiyCfGwX
394	394	{396,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv5XVdpmuRTBKS9ktAFPqpjnMXFzfuWdFzdsZoCmTtzmbY3wyLs
395	395	{397}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju4dFhrc7Q9WHoQWGZt7yR7v9bYTNwXpP8QpMxGegL7yKMFg79d
396	396	{398,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuYYFftXDxYWVwJtd1D9twNC1w2gv7Tj5TaM2WbhAqvoDNm6Gmu
397	397	{399}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvCM9KhQDXYGk2kcuY4hjCgj61dghrhqLReMh66RSjhhWzaYfBZ
398	398	{400,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtaUTJ3GXAzAhvRMXndSFPUo1QtkNqguzAz4ez6GpYrCGG54VJU
399	399	{401}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuTLMg89rCDf6puaWNYbaXjoHq5BMvoJz6TkRhCF3bskffRgWLy
400	400	{402,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtWrr5Qw2mzgcfriMTA62nE2tumBPT7pNDYZSgW6rXSAYX4xw6d
401	401	{403}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuDUAKTddPZXKxwFZFRBRbkzcxqGwG4W7JdcY4U8bgqRUAmaX6o
402	402	{404,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvN8RuUyecngJ8pJFApyLTJjr31Ksei7FUssdAMXiDdPsafnj1z
403	403	{405}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju5txojEHkAkLvbEMRMMMS4wb3zPw38W8fEF35KMUadnbrxog7q
404	404	{406,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtogvjL3pzW8wojDf2XGcgcFHQo8nz4RMT9PmiYJkFMZy3NWLsH
405	405	{407}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuNwG83aJrSm91nJRGKb9hQt4WRtZC6b46bnTrgNHx8AKXZsNTH
406	406	{408,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv268SBECDtZZVcGpfWcxy8BHZvKKoGtrhejDMhg7KkKPbxnvJR
407	407	{409}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvEjZ3FuCptXhGvRc1a4ukxxUWgyjQWrmgp53Gqm9VUZqR2AZ39
408	408	{410,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuMB5T3hdiivfYUU6JaGZBRiYLYbwh2eEnRzqqpFxLByH51w6A4
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
1	19	5000000000	\N	0
2	19	5000000000	\N	1
3	19	5000000000	\N	2
4	19	5000000000	\N	3
5	19	5000000000	\N	4
6	19	5000000000	\N	5
7	19	5000000000	\N	6
8	19	5000000000	\N	7
9	19	5000000000	\N	8
10	19	5000000000	\N	9
11	19	5000000000	\N	10
12	19	5000000000	\N	11
13	19	5000000000	\N	12
14	19	5000000000	\N	13
15	19	5000000000	\N	14
16	19	5000000000	\N	15
17	19	5000000000	\N	16
18	19	5000000000	\N	17
19	19	5000000000	\N	18
20	19	5000000000	\N	19
21	19	5000000000	\N	20
22	19	5000000000	\N	21
23	19	5000000000	\N	22
24	19	5000000000	\N	23
25	19	5000000000	\N	24
26	19	5000000000	\N	25
27	19	5000000000	\N	26
28	19	5000000000	\N	27
29	19	5000000000	\N	28
30	19	5000000000	\N	29
31	19	5000000000	\N	30
32	19	5000000000	\N	31
33	19	5000000000	\N	32
34	19	5000000000	\N	33
35	19	5000000000	\N	34
36	19	5000000000	\N	35
37	19	5000000000	\N	36
38	19	5000000000	\N	37
39	19	5000000000	\N	38
40	19	5000000000	\N	39
41	19	5000000000	\N	40
42	19	5000000000	\N	41
43	19	5000000000	\N	42
44	19	5000000000	\N	43
45	19	5000000000	\N	44
46	19	5000000000	\N	45
47	19	5000000000	\N	46
48	19	5000000000	\N	47
49	19	5000000000	\N	48
50	19	5000000000	\N	49
51	19	5000000000	\N	50
52	19	5000000000	\N	51
53	19	5000000000	\N	52
54	19	5000000000	\N	53
55	19	5000000000	\N	54
56	19	5000000000	\N	55
57	19	5000000000	\N	56
58	19	5000000000	\N	57
59	19	5000000000	\N	58
60	19	5000000000	\N	59
61	19	5000000000	\N	60
62	19	5000000000	\N	61
63	19	5000000000	\N	62
64	19	5000000000	\N	63
65	19	5000000000	\N	64
66	19	5000000000	\N	65
67	19	5000000000	\N	66
68	19	5000000000	\N	67
69	19	5000000000	\N	68
70	19	5000000000	\N	69
71	19	5000000000	\N	70
72	19	5000000000	\N	71
73	19	5000000000	\N	72
74	19	5000000000	\N	73
75	19	5000000000	\N	74
76	19	5000000000	\N	75
77	19	5000000000	\N	76
78	19	5000000000	\N	77
79	19	5000000000	\N	78
80	19	5000000000	\N	79
81	19	5000000000	\N	80
82	19	5000000000	\N	81
83	19	5000000000	\N	82
84	19	5000000000	\N	83
85	19	5000000000	\N	84
86	19	5000000000	\N	85
87	19	5000000000	\N	86
88	19	5000000000	\N	87
89	19	5000000000	\N	88
90	19	5000000000	\N	89
91	19	5000000000	\N	90
92	19	5000000000	\N	91
93	19	5000000000	\N	92
94	19	5000000000	\N	93
95	19	5000000000	\N	94
96	19	5000000000	\N	95
97	19	5000000000	\N	96
98	19	5000000000	\N	97
99	19	5000000000	\N	98
100	19	5000000000	\N	99
101	19	5000000000	\N	100
102	19	5000000000	\N	101
103	19	5000000000	\N	102
104	19	5000000000	\N	103
105	19	5000000000	\N	104
106	19	5000000000	\N	105
107	19	5000000000	\N	106
108	19	5000000000	\N	107
109	19	5000000000	\N	108
110	19	5000000000	\N	109
111	19	5000000000	\N	110
112	19	5000000000	\N	111
113	19	5000000000	\N	112
114	19	5000000000	\N	113
115	19	5000000000	\N	114
116	19	5000000000	\N	115
117	19	5000000000	\N	116
118	19	5000000000	\N	117
119	19	5000000000	\N	118
120	19	5000000000	\N	119
121	19	5000000000	\N	120
122	19	5000000000	\N	121
123	19	5000000000	\N	122
124	19	5000000000	\N	123
125	19	5000000000	\N	124
126	19	5000000000	\N	125
127	19	5000000000	\N	126
128	19	5000000000	\N	127
129	19	5000000000	\N	128
130	19	5000000000	\N	129
131	19	5000000000	\N	130
132	19	5000000000	\N	131
133	19	5000000000	\N	132
134	19	5000000000	\N	133
135	19	5000000000	\N	134
136	19	5000000000	\N	135
137	19	5000000000	\N	136
138	19	5000000000	\N	137
139	19	5000000000	\N	138
140	19	5000000000	\N	139
141	19	5000000000	\N	140
142	19	5000000000	\N	141
143	19	5000000000	\N	142
144	19	5000000000	\N	143
145	19	5000000000	\N	144
146	19	5000000000	\N	145
147	19	5000000000	\N	146
148	19	5000000000	\N	147
149	19	5000000000	\N	148
150	19	5000000000	\N	149
151	19	5000000000	\N	150
152	19	5000000000	\N	151
153	19	5000000000	\N	152
154	19	5000000000	\N	153
155	19	5000000000	\N	154
156	19	5000000000	\N	155
157	19	5000000000	\N	156
158	19	5000000000	\N	157
159	19	5000000000	\N	158
160	19	5000000000	\N	159
161	19	5000000000	\N	160
162	19	5000000000	\N	161
163	19	5000000000	\N	162
164	19	5000000000	\N	163
165	19	5000000000	\N	164
166	19	5000000000	\N	165
167	19	5000000000	\N	166
168	19	5000000000	\N	167
169	19	5000000000	\N	168
170	19	5000000000	\N	169
171	19	5000000000	\N	170
172	19	5000000000	\N	171
173	19	5000000000	\N	172
174	19	5000000000	\N	173
175	19	5000000000	\N	174
176	19	5000000000	\N	175
177	19	5000000000	\N	176
178	19	5000000000	\N	177
179	19	5000000000	\N	178
180	19	5000000000	\N	179
181	19	5000000000	\N	180
182	19	5000000000	\N	181
183	19	5000000000	\N	182
184	19	5000000000	\N	183
185	19	5000000000	\N	184
186	19	5000000000	\N	185
187	19	5000000000	\N	186
188	19	5000000000	\N	187
189	19	5000000000	\N	188
190	19	5000000000	\N	189
191	19	5000000000	\N	190
192	19	5000000000	\N	191
193	19	5000000000	\N	192
194	19	5000000000	\N	193
195	19	5000000000	\N	194
196	19	5000000000	\N	195
197	19	5000000000	\N	196
198	19	5000000000	\N	197
199	19	5000000000	\N	198
200	19	5000000000	\N	199
201	19	5000000000	\N	200
202	19	5000000000	\N	201
203	19	5000000000	\N	202
204	19	5000000000	\N	203
205	19	5000000000	\N	204
206	19	5000000000	\N	205
207	19	5000000000	\N	206
208	19	5000000000	\N	207
209	19	5000000000	\N	208
210	19	5000000000	\N	209
211	19	5000000000	\N	210
212	19	5000000000	\N	211
213	19	5000000000	\N	212
214	19	5000000000	\N	213
215	19	5000000000	\N	214
216	19	5000000000	\N	215
217	19	5000000000	\N	216
218	19	5000000000	\N	217
219	19	5000000000	\N	218
220	19	5000000000	\N	219
221	19	5000000000	\N	220
222	19	5000000000	\N	221
223	19	5000000000	\N	222
224	19	5000000000	\N	223
225	19	5000000000	\N	224
226	19	5000000000	\N	225
227	19	5000000000	\N	226
228	19	5000000000	\N	227
229	19	5000000000	\N	228
230	19	5000000000	\N	229
231	19	5000000000	\N	230
232	19	5000000000	\N	231
233	19	5000000000	\N	232
234	19	5000000000	\N	233
235	19	5000000000	\N	234
236	19	5000000000	\N	235
237	19	5000000000	\N	236
238	19	5000000000	\N	237
239	19	5000000000	\N	238
240	19	5000000000	\N	239
241	19	5000000000	\N	240
242	19	5000000000	\N	241
243	19	5000000000	\N	242
244	19	5000000000	\N	243
245	19	5000000000	\N	244
246	19	5000000000	\N	245
247	19	5000000000	\N	246
248	19	5000000000	\N	247
249	19	5000000000	\N	248
250	19	5000000000	\N	249
251	19	5000000000	\N	250
252	19	5000000000	\N	251
253	19	5000000000	\N	252
254	19	5000000000	\N	253
255	19	5000000000	\N	254
256	19	5000000000	\N	255
257	19	5000000000	\N	256
258	19	5000000000	\N	257
259	19	5000000000	\N	258
260	19	5000000000	\N	259
261	19	5000000000	\N	260
262	19	5000000000	\N	261
263	19	5000000000	\N	262
264	19	5000000000	\N	263
265	19	5000000000	\N	264
266	19	5000000000	\N	265
267	19	5000000000	\N	266
268	19	5000000000	\N	267
269	19	5000000000	\N	268
270	19	5000000000	\N	269
271	19	5000000000	\N	270
272	19	5000000000	\N	271
273	19	5000000000	\N	272
274	19	5000000000	\N	273
275	19	5000000000	\N	274
276	19	5000000000	\N	275
277	19	5000000000	\N	276
278	19	5000000000	\N	277
279	19	5000000000	\N	278
280	19	5000000000	\N	279
281	19	5000000000	\N	280
282	19	5000000000	\N	281
283	19	5000000000	\N	282
284	19	5000000000	\N	283
285	19	5000000000	\N	284
286	19	5000000000	\N	285
287	19	5000000000	\N	286
288	19	5000000000	\N	287
289	19	5000000000	\N	288
290	19	5000000000	\N	289
291	19	5000000000	\N	290
292	19	5000000000	\N	291
293	19	5000000000	\N	292
294	19	5000000000	\N	293
295	19	5000000000	\N	294
296	19	5000000000	\N	295
297	19	5000000000	\N	296
298	19	5000000000	\N	297
299	19	5000000000	\N	298
300	19	5000000000	\N	299
301	19	5000000000	\N	300
302	19	5000000000	\N	301
303	19	5000000000	\N	302
304	19	5000000000	\N	303
305	19	5000000000	\N	304
306	19	5000000000	\N	305
307	19	5000000000	\N	306
308	19	5000000000	\N	307
309	19	5000000000	\N	308
310	19	5000000000	\N	309
311	19	5000000000	\N	310
312	19	5000000000	\N	311
313	19	5000000000	\N	312
314	19	5000000000	\N	313
315	19	5000000000	\N	314
316	19	5000000000	\N	315
317	19	5000000000	\N	316
318	19	5000000000	\N	317
319	19	5000000000	\N	318
320	19	5000000000	\N	319
321	19	5000000000	\N	320
322	19	5000000000	\N	321
323	19	5000000000	\N	322
324	19	5000000000	\N	323
325	19	5000000000	\N	324
326	19	5000000000	\N	325
327	19	5000000000	\N	326
328	19	5000000000	\N	327
329	19	5000000000	\N	328
330	19	5000000000	\N	329
331	19	5000000000	\N	330
332	19	5000000000	\N	331
333	19	5000000000	\N	332
334	19	5000000000	\N	333
335	19	5000000000	\N	334
336	19	5000000000	\N	335
337	19	5000000000	\N	336
338	19	5000000000	\N	337
339	19	5000000000	\N	338
340	19	5000000000	\N	339
341	19	5000000000	\N	340
342	19	5000000000	\N	341
343	19	5000000000	\N	342
344	19	5000000000	\N	343
345	19	5000000000	\N	344
346	19	5000000000	\N	345
347	19	5000000000	\N	346
348	19	5000000000	\N	347
349	19	5000000000	\N	348
350	19	5000000000	\N	349
351	19	5000000000	\N	350
352	19	5000000000	\N	351
353	19	5000000000	\N	352
354	19	5000000000	\N	353
355	19	5000000000	\N	354
356	19	5000000000	\N	355
357	19	5000000000	\N	356
358	19	5000000000	\N	357
359	19	5000000000	\N	358
360	19	5000000000	\N	359
361	19	5000000000	\N	360
362	19	5000000000	\N	361
363	19	5000000000	\N	362
364	19	5000000000	\N	363
365	19	5000000000	\N	364
366	19	5000000000	\N	365
367	19	5000000000	\N	366
368	19	5000000000	\N	367
369	19	5000000000	\N	368
370	19	5000000000	\N	369
371	19	5000000000	\N	370
372	19	5000000000	\N	371
373	19	5000000000	\N	372
374	19	5000000000	\N	373
375	19	5000000000	\N	374
376	19	5000000000	\N	375
377	19	5000000000	\N	376
378	19	5000000000	\N	377
379	19	5000000000	\N	378
380	19	5000000000	\N	379
381	19	5000000000	\N	380
382	19	5000000000	\N	381
383	19	5000000000	\N	382
384	19	5000000000	\N	383
385	19	5000000000	\N	384
386	19	5000000000	\N	385
387	19	5000000000	\N	386
388	19	5000000000	\N	387
389	19	5000000000	\N	388
390	19	5000000000	\N	389
391	19	5000000000	\N	390
392	19	5000000000	\N	391
393	19	5000000000	\N	392
394	19	5000000000	\N	393
395	19	5000000000	\N	394
396	19	5000000000	\N	395
397	19	5000000000	\N	396
398	19	5000000000	\N	397
399	19	5000000000	\N	398
400	19	5000000000	\N	399
401	19	5000000000	\N	400
402	19	5000000000	\N	401
403	19	5000000000	\N	402
404	19	5000000000	\N	403
405	19	5000000000	\N	404
406	19	5000000000	\N	405
407	19	5000000000	\N	406
408	19	5000000000	\N	407
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

SELECT pg_catalog.setval('public.blocks_id_seq', 23, true);


--
-- Name: epoch_data_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.epoch_data_id_seq', 24, true);


--
-- Name: internal_commands_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.internal_commands_id_seq', 33, true);


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

SELECT pg_catalog.setval('public.user_commands_id_seq', 255, true);


--
-- Name: voting_for_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.voting_for_id_seq', 1, true);


--
-- Name: zkapp_account_permissions_precondition_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_account_permissions_precondition_id_seq', 1, true);


--
-- Name: zkapp_account_precondition_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_account_precondition_id_seq', 206, true);


--
-- Name: zkapp_account_update_body_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_account_update_body_id_seq', 410, true);


--
-- Name: zkapp_account_update_failures_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_account_update_failures_id_seq', 4, true);


--
-- Name: zkapp_account_update_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_account_update_id_seq', 410, true);


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

SELECT pg_catalog.setval('public.zkapp_commands_id_seq', 408, true);


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

SELECT pg_catalog.setval('public.zkapp_fee_payer_body_id_seq', 408, true);


--
-- Name: zkapp_field_array_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_field_array_id_seq', 1, false);


--
-- Name: zkapp_field_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_field_id_seq', 203, true);


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

SELECT pg_catalog.setval('public.zkapp_nonce_bounds_id_seq', 205, true);


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

SELECT pg_catalog.setval('public.zkapp_states_nullable_id_seq', 204, true);


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

SELECT pg_catalog.setval('public.zkapp_updates_id_seq', 205, true);


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

