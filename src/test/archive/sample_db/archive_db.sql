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
25	27	1
26	28	1
27	29	1
28	30	1
29	31	1
30	32	1
31	33	1
32	34	1
33	35	1
34	36	1
35	37	1
36	38	1
37	39	1
38	40	1
39	41	1
40	42	1
41	43	1
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
77	80	1
78	81	1
79	82	1
80	83	1
81	84	1
82	85	1
83	86	1
84	87	1
85	88	1
86	89	1
87	90	1
88	91	1
89	92	1
90	93	1
91	94	1
92	95	1
93	96	1
94	97	1
95	98	1
96	44	1
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
109	26	1
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
4	1	24	1	11550000000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	26	1	24	1	\N
187	1	25	1	104	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	27	1	25	1	\N
72	1	26	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	28	1	26	1	\N
216	1	27	1	271	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	29	1	27	1	\N
210	1	28	1	315	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	30	1	28	1	\N
79	1	29	1	162	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	31	1	29	1	\N
167	1	30	1	86	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	32	1	30	1	\N
181	1	31	1	409	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	33	1	31	1	\N
156	1	32	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	34	1	32	1	\N
96	1	33	1	57	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	35	1	33	1	\N
191	1	34	1	204	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	36	1	34	1	\N
132	1	35	1	262	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	37	1	35	1	\N
111	1	36	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	38	1	36	1	\N
171	1	37	1	156	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	39	1	37	1	\N
64	1	38	1	417	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	40	1	38	1	\N
68	1	39	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	41	1	39	1	\N
51	1	40	1	85	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	42	1	40	1	\N
6	1	41	1	11550000000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	44	1	41	1	\N
227	1	42	1	103	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	45	1	42	1	\N
141	1	43	1	67	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	46	1	43	1	\N
42	1	44	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	47	1	44	1	\N
133	1	45	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	48	1	45	1	\N
82	1	46	1	198	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	49	1	46	1	\N
95	1	47	1	489	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	50	1	47	1	\N
188	1	48	1	298	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	51	1	48	1	\N
30	1	49	1	36	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	52	1	49	1	\N
90	1	50	1	334	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	53	1	50	1	\N
14	1	51	1	344	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	54	1	51	1	\N
35	1	52	1	451	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	55	1	52	1	\N
85	1	53	1	371	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	56	1	53	1	\N
127	1	54	1	234	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	57	1	54	1	\N
222	1	55	1	345	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	58	1	55	1	\N
76	1	56	1	282	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	59	1	56	1	\N
231	1	57	1	339	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	60	1	57	1	\N
15	1	58	1	215	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	61	1	58	1	\N
220	1	59	1	193	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	62	1	59	1	\N
16	1	60	1	60	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	63	1	60	1	\N
58	1	61	1	350	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	64	1	61	1	\N
146	1	62	1	223	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	65	1	62	1	\N
62	1	63	1	449	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	66	1	63	1	\N
185	1	64	1	142	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	67	1	64	1	\N
151	1	65	1	300	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	68	1	65	1	\N
165	1	66	1	256	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	69	1	66	1	\N
103	1	67	1	125	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	70	1	67	1	\N
41	1	68	1	236	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	71	1	68	1	\N
239	1	69	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	72	1	69	1	\N
110	1	70	1	179	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	73	1	70	1	\N
13	1	71	1	194	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	74	1	71	1	\N
26	1	72	1	185	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	75	1	72	1	\N
98	1	73	1	342	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	76	1	73	1	\N
215	1	74	1	157	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	77	1	74	1	\N
91	1	75	1	135	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	78	1	75	1	\N
159	1	76	1	456	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	79	1	76	1	\N
208	1	77	1	336	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	80	1	77	1	\N
207	1	78	1	280	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	81	1	78	1	\N
182	1	79	1	187	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	82	1	79	1	\N
157	1	80	1	387	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	83	1	80	1	\N
33	1	81	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	84	1	81	1	\N
201	1	82	1	151	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	85	1	82	1	\N
9	1	83	1	356	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	86	1	83	1	\N
234	1	84	1	24	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	87	1	84	1	\N
40	1	85	1	152	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	88	1	85	1	\N
18	1	86	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	89	1	86	1	\N
229	1	87	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	90	1	87	1	\N
20	1	88	1	186	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	91	1	88	1	\N
184	1	89	1	266	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	92	1	89	1	\N
139	1	90	1	81	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	93	1	90	1	\N
164	1	91	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	94	1	91	1	\N
199	1	92	1	379	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	95	1	92	1	\N
109	1	93	1	315	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	96	1	93	1	\N
47	1	94	1	226	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	97	1	94	1	\N
214	1	95	1	166	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	98	1	95	1	\N
7	1	96	1	0	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	44	1	96	1	\N
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
5	1	109	1	0	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	26	1	109	1	\N
190	1	110	1	294	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	111	1	110	1	\N
218	1	111	1	191	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	112	1	111	1	\N
93	1	112	1	380	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	113	1	112	1	\N
162	1	113	1	331	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	114	1	113	1	\N
221	1	114	1	459	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	115	1	114	1	\N
205	1	115	1	28	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	116	1	115	1	\N
195	1	116	1	472	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	117	1	116	1	\N
34	1	117	1	119	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	118	1	117	1	\N
213	1	118	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	119	1	118	1	\N
196	1	119	1	41	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	120	1	119	1	\N
104	1	120	1	27	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	121	1	120	1	\N
44	1	121	1	70	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	122	1	121	1	\N
52	1	122	1	337	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	123	1	122	1	\N
114	1	123	1	210	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	124	1	123	1	\N
177	1	124	1	495	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	125	1	124	1	\N
148	1	125	1	144	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	126	1	125	1	\N
100	1	126	1	148	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	127	1	126	1	\N
206	1	127	1	376	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	128	1	127	1	\N
28	1	128	1	329	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	129	1	128	1	\N
173	1	129	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	130	1	129	1	\N
130	1	130	1	500	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	131	1	130	1	\N
39	1	131	1	181	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	132	1	131	1	\N
212	1	132	1	200	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	133	1	132	1	\N
116	1	133	1	159	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	134	1	133	1	\N
48	1	134	1	319	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	135	1	134	1	\N
101	1	135	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	136	1	135	1	\N
203	1	136	1	365	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	137	1	136	1	\N
50	1	137	1	342	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	138	1	137	1	\N
59	1	138	1	237	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	139	1	138	1	\N
150	1	139	1	427	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	140	1	139	1	\N
180	1	140	1	315	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	141	1	140	1	\N
142	1	141	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	142	1	141	1	\N
23	1	142	1	378	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	143	1	142	1	\N
122	1	143	1	420	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	144	1	143	1	\N
115	1	144	1	411	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	145	1	144	1	\N
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
3	1	158	1	500000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	159	1	158	1	\N
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
129	1	169	1	314	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	170	1	169	1	\N
193	1	170	1	183	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	171	1	170	1	\N
174	1	171	1	486	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	172	1	171	1	\N
57	1	172	1	178	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	173	1	172	1	\N
224	1	173	1	65	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	174	1	173	1	\N
232	1	174	1	277	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	175	1	174	1	\N
2	1	175	1	65500000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	159	1	175	1	\N
119	1	176	1	433	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	177	1	176	1	\N
55	1	177	1	100	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	178	1	177	1	\N
169	1	178	1	272	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	179	1	178	1	\N
125	1	179	1	10	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	180	1	179	1	\N
1	1	180	1	5000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	181	1	180	1	\N
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
4	2	24	1	11549925000000000	15	2mziMMKZX8axxMyZDsYTnWVkaWFwGT6RML4dXUYHkjuSe6XWCCzG	26	1	24	1	\N
7	2	96	1	797000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	44	1	96	1	\N
3	2	158	1	498000000000	8	2n17apmZe8mXQ6yNV1bu3EFB3GDgVzidNfnSZNcJL7MDbTShV84r	159	1	158	1	\N
4	3	24	1	11549815000000000	37	2n1MumNyEdMEmXiMvm9rLo1MrzWjHqhSE7Mc9dajKkkcXX7XGw4y	26	1	24	1	\N
7	3	96	1	1629750000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	44	1	96	1	\N
3	3	158	1	495250000000	19	2n1q8iiFRsXVG8yuVEPmtCkkZmbzS9ExYsxxLv3XLUxRLJpQnRCY	159	1	158	1	\N
4	4	24	1	11549710000000000	58	2n2JvATNsZpyooEoe1bf3JR44febr3Nk1drkRua1G3rATFfyGswW	26	1	24	1	\N
5	4	109	1	827750000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	26	1	109	1	\N
3	4	158	1	492500000000	30	2n1LfEY1be8sNJtheJefvwkXNUDzztpWPxsxV8QG261ArwUS2YmH	159	1	158	1	\N
4	5	24	1	11549600000000000	80	2mztGknZSwg8moxsodgy7n4SRCtuUwYxqohcTy8tCykbaCxkhR61	26	1	24	1	\N
7	5	96	1	2462500000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	44	1	96	1	\N
3	5	158	1	489750000000	41	2mzf1aRfdy77buqP4au563F3hgWSiLWaYEAKJqSx3HRdQ5y4H6gF	159	1	158	1	\N
4	6	24	1	11549495000000000	101	2n1VUyP7a8GvA6E3szyZCHjpeL58q6n9Abw9AosWxJcc5f7qUWWx	26	1	24	1	\N
5	6	109	1	1655500000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	26	1	109	1	\N
3	6	158	1	487000000000	52	2n1LpP6VMAoYkBLuK5zUjmNjR3aAqcRDk2SJmY6ofURuzy5pc19o	159	1	158	1	\N
4	7	24	1	11549385000000000	123	2n29PaFdpAWnrvMa5vvmhBpxDzNkEYd6qeqWxPULn6ht1gkc35fF	26	1	24	1	\N
7	7	96	1	3295000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	44	1	96	1	\N
3	7	158	1	484500000000	62	2n1mqNZAeauYLd69k9HC1GMyqrgs2YbgK7jqUqqHRmiFBdqAJ4E1	159	1	158	1	\N
4	8	24	1	11549385000000000	123	2n29PaFdpAWnrvMa5vvmhBpxDzNkEYd6qeqWxPULn6ht1gkc35fF	26	1	24	1	\N
5	8	109	1	2488000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	26	1	109	1	\N
3	8	158	1	484500000000	62	2n1mqNZAeauYLd69k9HC1GMyqrgs2YbgK7jqUqqHRmiFBdqAJ4E1	159	1	158	1	\N
4	9	24	1	11549265000000000	147	2n1KgkT8BAKdXYnUdG1ritSKkfu5eAk6zphC1SkShWzuV3EH8kSc	26	1	24	1	\N
5	9	109	1	2501000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	26	1	109	1	\N
3	9	158	1	479000000000	84	2mzzm1iZ5sscVeDhPNZwpfMPvCUKjdwGrFrdw88L4D2w7SjBWEab	159	1	158	1	\N
4	10	24	1	11549145000000000	171	2n2CNHf5HnNRPxWuGkuKQtxQ8Dhqq9twmaU4WyjfWDTMjPYhojgm	26	1	24	1	\N
7	10	96	1	4137750000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	44	1	96	1	\N
3	10	158	1	476250000000	95	2mzycPaVkLhSHaPyxBTp8k2FFtDKvoMt5YQob31Ev8JTnQpS35oj	159	1	158	1	\N
4	11	24	1	11549145000000000	171	2n2CNHf5HnNRPxWuGkuKQtxQ8Dhqq9twmaU4WyjfWDTMjPYhojgm	26	1	24	1	\N
5	11	109	1	3343750000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	26	1	109	1	\N
3	11	158	1	476250000000	95	2mzycPaVkLhSHaPyxBTp8k2FFtDKvoMt5YQob31Ev8JTnQpS35oj	159	1	158	1	\N
4	12	24	1	11549025000000000	195	2n1XfC2HT16T56uP8FJjEnierdGrN7dXcP7G1y1SPZPsULJ1eNgN	26	1	24	1	\N
7	12	96	1	4137750000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	44	1	96	1	\N
3	12	158	1	473500000000	106	2n1mSUo1kegeaMx94cSGNj4Qb7eaEEjEX8dooxWNh6A45Gsf5PPS	159	1	158	1	\N
4	13	24	1	11548905000000000	219	2n1rasDCZHjfQ8FooCu2rDVd1sYujK9MXJs6tRbheusKrhw5S2GS	26	1	24	1	\N
5	13	109	1	4189250000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	26	1	109	1	\N
3	13	158	1	468000000000	128	2mzY8F1knPnJRaqQeqMbPPS88f6y9WxG241YPmJXaptKareyK7nM	159	1	158	1	\N
4	14	24	1	11548785000000000	243	2mztdL5MwQuCxxNjfCZWKmjQW5yWrGUP6zcYf5pgPAwUSgAZf2VY	26	1	24	1	\N
5	14	109	1	5031686000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	26	1	109	1	\N
3	14	158	1	465500000000	138	2n1DNESuJmBJZipJQs3vJ89V6KBdG4vPgPvYx362KqLD6KRKtpjr	159	1	158	1	\N
1	14	180	1	5064000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	181	1	180	1	\N
4	15	24	1	11548785000000000	243	2mztdL5MwQuCxxNjfCZWKmjQW5yWrGUP6zcYf5pgPAwUSgAZf2VY	26	1	24	1	\N
7	15	96	1	4980186000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	44	1	96	1	\N
3	15	158	1	465500000000	138	2n1DNESuJmBJZipJQs3vJ89V6KBdG4vPgPvYx362KqLD6KRKtpjr	159	1	158	1	\N
1	15	180	1	5064000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	181	1	180	1	\N
4	16	24	1	11548665000000000	267	2n1Xuvtw5L6zbfforeW7Yvg8Ms6G49NyfuAKxcwp5YsN4VjYVnVj	26	1	24	1	\N
7	16	96	1	4983250000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	44	1	96	1	\N
3	16	158	1	460000000000	160	2n1wb8Fhhn39LvWuvzQMV8q5UBkW4psUZ1sWxL62mARRt56ugoHh	159	1	158	1	\N
4	18	24	1	11548545000000000	291	2mzuUZ1BKRKEYEi4D3vwyt7DvFCCsb82GpS1Ru2tHeU3ZQ6BTMAH	26	1	24	1	\N
5	18	109	1	5874436000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	26	1	109	1	\N
3	18	158	1	457250000000	171	2mzo8dQLbuNkeNEb8AnKs1RAwU7iJYVr1usxDgK73EEe1Xz4EF2J	159	1	158	1	\N
4	20	24	1	11548305000000000	339	2n21yLr7Pu4yoCrYUPCwYDPryLtrTVC4h7DsthwKeAe2UW9n46Zx	26	1	24	1	\N
5	20	109	1	5874186000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	26	1	109	1	\N
3	20	158	1	452000000000	192	2n1z9EFMBBmZKoSZPsiiPmPpAnyhmNEMqEsBF1CTTGCYqcWpMSQ3	159	1	158	1	\N
4	22	24	1	11548065000000000	387	2n2Ja99DqToxuTf77YzgM2sMcq7LvaRnzxSCx3dx1HLWdo6xu9Wn	26	1	24	1	\N
7	22	96	1	8362130000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	44	1	96	1	\N
3	22	158	1	438500000000	246	2mzinugNXk7nKAYLnmYxMT3qFbKEBckFzccN35vNan67Z9jYbbhH	159	1	158	1	\N
1	22	180	1	5184000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	181	1	180	1	\N
4	24	24	1	11547945000000000	411	2mzXn9ous9HetYRKPyLJ4whJpnAxxN5mCiwBMpXz1qmr8dMt55ws	26	1	24	1	\N
7	24	96	1	9204624000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	44	1	96	1	\N
3	24	158	1	436000000000	256	2n2RezvcBCMYXVdfknJ5HJT5TnHB3DxhPMQ2iuHvnqxGxwvi7yEx	159	1	158	1	\N
1	24	180	1	5190000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	181	1	180	1	\N
4	17	24	1	11548545000000000	291	2mzuUZ1BKRKEYEi4D3vwyt7DvFCCsb82GpS1Ru2tHeU3ZQ6BTMAH	26	1	24	1	\N
7	17	96	1	5826000000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	44	1	96	1	\N
3	17	158	1	457250000000	171	2mzo8dQLbuNkeNEb8AnKs1RAwU7iJYVr1usxDgK73EEe1Xz4EF2J	159	1	158	1	\N
4	19	24	1	11548425000000000	315	2n2PGVGGktNiS4r3WnkW5DaK2jPnWQc5MDMreEWfNZiCVDw4tCtX	26	1	24	1	\N
7	19	96	1	6668686000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	44	1	96	1	\N
3	19	158	1	454500000000	182	2n2HapxKtBEbY6eBkr6Ci3J94syc8XFqmRExRAxxCBV29YqzhBQb	159	1	158	1	\N
1	19	180	1	5128000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	181	1	180	1	\N
4	21	24	1	11548185000000000	363	2n1hBqNZyKNZypmfvBZibXRKrbDnccGuxiVco4DCRvEwUdHNEqA4	26	1	24	1	\N
7	21	96	1	7519436000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	44	1	96	1	\N
3	21	158	1	441250000000	235	2n2Ad9dJiDVAToyhg5UACXRMqWqDUph4EiAdxUqeuSadJGFKTmnb	159	1	158	1	\N
4	23	24	1	11547945000000000	411	2mzXn9ous9HetYRKPyLJ4whJpnAxxN5mCiwBMpXz1qmr8dMt55ws	26	1	24	1	\N
5	23	109	1	6716680000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	26	1	109	1	\N
3	23	158	1	436000000000	256	2n2RezvcBCMYXVdfknJ5HJT5TnHB3DxhPMQ2iuHvnqxGxwvi7yEx	159	1	158	1	\N
1	23	180	1	5190000000	0	2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe	181	1	180	1	\N
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
18	3NL3TYC7VvrPc1im2nniCKAA4MwFkXDyKMGYw9BnW24EmtbJiokQ	16	3NLLJeAwnX21PUJiKpLzi42Dz4zY7di2CVyEyhmSS4KGNuH5YASj	26	25	-jBFZa_wLmJWSHVcjQgeYDnLiyee1r1UXwUvfk459gE=	1	1	19	77	{6,5,3,7,7,7,7,7,7,7,7}	23166005000061388	jwhwuSKfZ4dHDqT5PhVTQoX222KhkPgJuGLVNWEWhGwrhrYW6G9	14	17	17	1	\N	1733340554000	orphaned
22	3NLmTKHiNzHsXvpi4o1kWLHVxoEfsZGPLBDTioSR51P4fXVM51Yr	21	3NLBa2WV9VFeoiseShWeazYGUod2M6bkNG7XYYtYLtPti873GUPa	44	43	EIKfK-4Y0TxBIl-q4LQehWsQfz2RCQ1QuZ5u95jDVA8=	1	1	23	77	{6,5,5,2,7,7,7,7,7,7,7}	23166005000061388	jws9wU4y1njs4EG6wURMy3geg5B8MquHhBin8t7T14kaAoMDHac	18	24	24	1	\N	1733341814000	orphaned
24	3NKvwaoNc4mFMzc7h3geQyxVsJU2gDyJqWB3CRJQ6PmfxQwV6D4J	22	3NLmTKHiNzHsXvpi4o1kWLHVxoEfsZGPLBDTioSR51P4fXVM51Yr	44	43	4Yb39YITsBN6xB8HWj52VWkiIJZrXvJ7_ay87qCMbgM=	1	1	25	77	{6,5,5,3,7,7,7,7,7,7,7}	23166005000061388	jwgjUWUj81mHRgiTXwUoqN6g47K1jWh6Mynfb5bUbrE81nqWxmy	19	25	25	1	\N	1733341994000	canonical
20	3NKFL2agT1Z8PWA6Vzby7nvMA8Q3wJWZ2ML6U8G9VfYancMvSNSj	19	3NKDEY9NZiLKre77oMrNtMiT4Q5nDnwWnTenAz1k8xxt4XHYQY13	26	25	rgvFEva4RbraJ3Jz7eCx_4C_C-B9fyVB5EEOekAceg8=	1	1	21	77	{6,5,5,7,7,7,7,7,7,7,7}	23166005000061388	jxKQGUPkXDu5Gqcbv9betJMTyWWdEPDqMyLrqo4yREvXaFRxLpm	16	19	19	1	\N	1733340914000	canonical
8	3NLAxHCmE6CaJ77K92YJSqSxrWuw5yhD2pSMZdb2xXMXHPGHiXsD	6	3NKHbhjenFFNgpR6dbwouS4nTRnxbwiUFMfbGhh5Z4YTrscEKeeE	26	25	tL-LvkJb2BV-WcZg6J74ll364X8lwZvTgLvUc0_FxQs=	1	1	9	77	{6,1,7,7,7,7,7,7,7,7,7}	23166005000061388	jwMhFHWvs89shZUttZGNTvi1EMxWaLqXqB6fZZWHi1EJEwhyKk5	7	7	7	1	\N	1733338754000	orphaned
10	3NLHrcPiuDyVi3uQbMZ7gs7o2h11v6228NFtHfCqzPfry3ZpEwHX	9	3NL77YUdjd6WzoRFH44P6Zhp81bhqWmsi8ZUCVmZN1YVJ24xXzGG	44	43	Euk1-3aSHt7MHXpnkpuwcV5IZNnn44d6-YmREUnH_AM=	1	1	11	77	{6,3,7,7,7,7,7,7,7,7,7}	23166005000061388	jwe7v1P66BBuNpKocrc2MbedsMXhxwZozsPPW7vM19tHoCLmMSH	9	10	10	1	\N	1733339294000	orphaned
14	3NKSdShh4g3Wtfe55zafNiD6qSewfzCiiv16t4W9PcAjkm694Ejz	13	3NKDZeJysvGwEDSrq2UwudVu8qorvSd6dCaiLz2FzH4aBSobmkVd	26	25	5TePDsK2tBKjgUuUlyghgVzW14be8QKL1dOwxRiOzw4=	1	1	15	77	{6,5,1,7,7,7,7,7,7,7,7}	23166005000061388	jxeQYfGHYUzRGD83AAYcdRRXe8TUeQvRVEGUs6rNgiT1pBVvXYL	12	14	14	1	\N	1733340014000	canonical
13	3NKDZeJysvGwEDSrq2UwudVu8qorvSd6dCaiLz2FzH4aBSobmkVd	12	3NLQyje5QoyKKTS1by8cqR58qW3VcjmnaeggV1KcJ2kZNskn5nnW	26	25	SKiEoBj5t_to7lMFr_cFjL86exrUYCRCXm1NLUkOwgU=	1	1	14	77	{6,5,7,7,7,7,7,7,7,7,7}	23166005000061388	jx43FSjEnKZffqZGF9FKBHUEjLq6eAbBUykZ171sGVHcGK9CYkP	11	13	13	1	\N	1733339834000	canonical
12	3NLQyje5QoyKKTS1by8cqR58qW3VcjmnaeggV1KcJ2kZNskn5nnW	11	3NL4wKDhZrE7QeCc3oxgRmfAvUGNrQLnkmthaDR589RKcHPHRwr8	44	43	9PWcVn2gvF3QUDXsum0EwXr6soWaQxn0FCreo8msSQk=	1	1	13	77	{6,4,7,7,7,7,7,7,7,7,7}	23166005000061388	jwN7vS8pNmKLh6WbEXfjyqRdsELG41YiEVMpQwpkJrKGya2jHA7	10	11	11	1	\N	1733339474000	canonical
11	3NL4wKDhZrE7QeCc3oxgRmfAvUGNrQLnkmthaDR589RKcHPHRwr8	9	3NL77YUdjd6WzoRFH44P6Zhp81bhqWmsi8ZUCVmZN1YVJ24xXzGG	26	25	kku-tfQIVl7WKqcmAcSITCostlWV4shB9suXckQ3JAM=	1	1	12	77	{6,3,7,7,7,7,7,7,7,7,7}	23166005000061388	jx4t9UrZxVcVDShuDzVeyC5f2kbYdSbERjYYrvTKq8akZcjHV1r	9	10	10	1	\N	1733339294000	canonical
9	3NL77YUdjd6WzoRFH44P6Zhp81bhqWmsi8ZUCVmZN1YVJ24xXzGG	7	3NLRByo19hEBqHsk93xfmnrVo7Gvedu12z3ZWcPR3BDjRWbWTGT7	26	25	GVMQYw5i4SXQODW5gReBpr3OkVBt0oEcMvNouYOr-wc=	1	1	10	77	{6,2,7,7,7,7,7,7,7,7,7}	23166005000061388	jxzwb3Tsr9GM54VVzNyATmY59qUPEaX8vRRuWzEnKDke4PRvFKs	8	9	9	1	\N	1733339114000	canonical
7	3NLRByo19hEBqHsk93xfmnrVo7Gvedu12z3ZWcPR3BDjRWbWTGT7	6	3NKHbhjenFFNgpR6dbwouS4nTRnxbwiUFMfbGhh5Z4YTrscEKeeE	44	43	KnXHgTEWXQ4cUt-PS29IWbwaEFq2wQwesTooRgUnfwI=	1	1	8	77	{6,1,7,7,7,7,7,7,7,7,7}	23166005000061388	jxLSU44BqY3HU3yKbD9aH1KwD2KiKa8tjt1N133t8boYCXvtTdq	7	7	7	1	\N	1733338754000	canonical
6	3NKHbhjenFFNgpR6dbwouS4nTRnxbwiUFMfbGhh5Z4YTrscEKeeE	5	3NLqUxSXQuT4NbqSEqWdpTaWcKCC9qcP6hG75prXErqrFVjRsboP	26	25	Iq-VNe-nXYS1nTvo5a37qAX2LQuMpM4WF7Wm3cc9awY=	1	1	7	77	{6,7,7,7,7,7,7,7,7,7,7}	23166005000061388	jx9whUd3x5UJsUJz8L9MGtckNPgULX7MaPoRaR6SMwGASXVdtyQ	6	6	6	1	\N	1733338574000	canonical
5	3NLqUxSXQuT4NbqSEqWdpTaWcKCC9qcP6hG75prXErqrFVjRsboP	4	3NLioVPDBh46Ss8buybzY7mE3Bgu97Bh4C5aESYHFmuxt8uMhowm	44	43	yguLyTjKk7rf27Z1UsNccOzRamdKsqly0A-zsAED0Qs=	1	1	6	77	{5,7,7,7,7,7,7,7,7,7,7}	23166005000061388	jwtRCGsfBRNDcUnTkwTReA5CicsBKS8v5zcTGERnRNF7DSzo9MG	5	5	5	1	\N	1733338394000	canonical
4	3NLioVPDBh46Ss8buybzY7mE3Bgu97Bh4C5aESYHFmuxt8uMhowm	3	3NKAmt8ZQVoBKjXWZLvCMXQRPa733WgKEeCDn645dXExhdoV6mjk	26	25	Enq3psfQL8T4Qrc5DRBQSViH61WLhpUwoU7uRmatbww=	1	1	5	77	{4,7,7,7,7,7,7,7,7,7,7}	23166005000061388	jxqUvDiJhkvmc8MthQgSb7nVuu3murKkSByWnHFemW1JBTpxduu	4	4	4	1	\N	1733338214000	canonical
3	3NKAmt8ZQVoBKjXWZLvCMXQRPa733WgKEeCDn645dXExhdoV6mjk	2	3NKSHBRCn27XoiY9MQjx1uKWdMEBfN1jnVpfrDtkxCWo94NvtwUi	44	43	rCH2JKHJxfT1svKOYzusgrbH4FKqjh7N5zx1-091KA0=	1	1	4	77	{3,7,7,7,7,7,7,7,7,7,7}	23166005000061388	jwRi4toX8iHZeSg8r9EqY7XgRkDjwXh9bmeQLiG3NuZMsC9EsSo	3	3	3	1	\N	1733338034000	canonical
2	3NKSHBRCn27XoiY9MQjx1uKWdMEBfN1jnVpfrDtkxCWo94NvtwUi	1	3NLhA17Jrf9vMyfSxDKmAuK2r8sDNs3aDnT5HKidt4iRXQrS8RXB	44	43	lIoj2Cv5AQkYmmgoRmc7dPWKckw9OxvfLLLp3vjiWgQ=	1	1	3	77	{2,7,7,7,7,7,7,7,7,7,7}	23166005000061388	jwf1BxRfBKgXpJcnptfjxCm1VcfaHvqs9QLLcDeAwS6JJjoxKAr	2	2	2	1	\N	1733337854000	canonical
1	3NLhA17Jrf9vMyfSxDKmAuK2r8sDNs3aDnT5HKidt4iRXQrS8RXB	\N	3NKL8Lpm5EMf8fxdaaTkpp4JNVF8KogNC1TSuhnWtGMazbYjmfWa	1	1	39cyg4ZmMtnb_aFUIerNAoAJV8qtkfOpq0zFzPspjgM=	1	1	2	77	{1,7,7,7,7,7,7,7,7,7,7}	23166005000061388	jxNuBV1viAexEqSfKYubHTvrtCBrjaNjHowN7a8ViuNFpH15bBp	1	0	0	1	\N	1733337494000	canonical
15	3NKkNS78zWXJFbULoRKmVzWwn1e9ExKQwxLuMhre8JfTC9qaK4me	13	3NKDZeJysvGwEDSrq2UwudVu8qorvSd6dCaiLz2FzH4aBSobmkVd	44	43	qJlj5Y79LtBcKKbnPqrBUf1awt2Iy8vTc7PfvVvgbQA=	1	1	16	77	{6,5,1,7,7,7,7,7,7,7,7}	23166005000061388	jxuUCr3qntzKMSG72wiKrC2ALkf6v9jSiNsJ3bzCv6NQpbvQLnR	12	14	14	1	\N	1733340014000	orphaned
23	3NLqmSZSbc3Euq1KWeNTMFgmsqEeX3oB83P3ubEPCKCJJQeDxbXD	22	3NLmTKHiNzHsXvpi4o1kWLHVxoEfsZGPLBDTioSR51P4fXVM51Yr	26	25	ZHTBfEueQ7NQXtyJB_JYMHwO9GeIe7-M-3KlFIax8w8=	1	1	24	77	{6,5,5,3,7,7,7,7,7,7,7}	23166005000061388	jxEvJVfxWJiNu9xxeeYhvVRxo35VzZfnGTx2TUMhTc9ZLtQ1Dp4	19	25	25	1	\N	1733341994000	orphaned
21	3NLBa2WV9VFeoiseShWeazYGUod2M6bkNG7XYYtYLtPti873GUPa	20	3NKFL2agT1Z8PWA6Vzby7nvMA8Q3wJWZ2ML6U8G9VfYancMvSNSj	44	43	D2JuVnwXPLT2wSt_yIweefokn7YedScEEz9y3ieC8wQ=	1	1	22	77	{6,5,5,1,7,7,7,7,7,7,7}	23166005000061388	jwSiM7CSXeQ3xeMHFCoDgt5hqb5yZprQcpzr2tZVajdcXCdJF8u	17	23	23	1	\N	1733341634000	canonical
19	3NKDEY9NZiLKre77oMrNtMiT4Q5nDnwWnTenAz1k8xxt4XHYQY13	17	3NLVLcmKmT34BfFTn9vvMAYzstd4vFUHQfpXwxRpWh6kssCrTrNh	44	43	TXsOkqdN3OLf25Pg0LKnObzQDowZMASPAPrqBAlZZAo=	1	1	20	77	{6,5,4,7,7,7,7,7,7,7,7}	23166005000061388	jwAJuQ3LrvWWHXkKTF5R7JAUfA5n6Nc6wHS6cvcLtYvJXGGo1fC	15	18	18	1	\N	1733340734000	canonical
17	3NLVLcmKmT34BfFTn9vvMAYzstd4vFUHQfpXwxRpWh6kssCrTrNh	16	3NLLJeAwnX21PUJiKpLzi42Dz4zY7di2CVyEyhmSS4KGNuH5YASj	44	43	VV2dgivSgSNlqnZr7xVElaZYYx_tcl3JVwXq3wFTpgo=	1	1	18	77	{6,5,3,7,7,7,7,7,7,7,7}	23166005000061388	jwbs3cVnUSRcu141Zaf3yta2q7FRU2BJBQiBtt2xwpPtXjK4Tzy	14	17	17	1	\N	1733340554000	canonical
16	3NLLJeAwnX21PUJiKpLzi42Dz4zY7di2CVyEyhmSS4KGNuH5YASj	14	3NKSdShh4g3Wtfe55zafNiD6qSewfzCiiv16t4W9PcAjkm694Ejz	44	43	iEc2iERaMnHBgcvgacFBZBoI6qlff5jNvKgrxAzJjgQ=	1	1	17	77	{6,5,2,7,7,7,7,7,7,7,7}	23166005000061388	jwpdi5SgnqanABw9RBUcuypQjEeqfRqu4NN2a7J7Kh2GP4isRDT	13	16	16	1	\N	1733340374000	canonical
\.


--
-- Data for Name: blocks_internal_commands; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.blocks_internal_commands (block_id, internal_command_id, sequence_no, secondary_sequence_no, status, failure_reason) FROM stdin;
2	1	23	0	applied	\N
2	2	24	0	applied	\N
3	1	33	0	applied	\N
3	3	34	0	applied	\N
4	4	32	0	applied	\N
4	5	33	0	applied	\N
5	3	33	0	applied	\N
5	1	34	0	applied	\N
6	4	32	0	applied	\N
6	5	33	0	applied	\N
7	1	32	0	applied	\N
7	6	33	0	applied	\N
8	4	32	0	applied	\N
8	7	33	0	applied	\N
9	4	46	0	applied	\N
9	8	47	0	applied	\N
10	9	10	0	applied	\N
10	1	36	0	applied	\N
10	10	37	0	applied	\N
11	11	10	0	applied	\N
11	4	36	0	applied	\N
11	12	37	0	applied	\N
12	1	35	0	applied	\N
12	13	36	0	applied	\N
13	4	46	0	applied	\N
13	8	47	0	applied	\N
14	14	15	0	applied	\N
14	15	35	0	applied	\N
14	16	35	0	applied	\N
14	17	36	0	applied	\N
14	18	36	1	applied	\N
15	19	15	0	applied	\N
15	15	35	0	applied	\N
15	20	35	0	applied	\N
15	21	36	0	applied	\N
15	18	36	1	applied	\N
16	1	46	0	applied	\N
16	22	47	0	applied	\N
17	1	35	0	applied	\N
17	13	36	0	applied	\N
18	4	35	0	applied	\N
18	23	36	0	applied	\N
19	24	21	0	applied	\N
19	15	36	0	applied	\N
19	20	36	0	applied	\N
19	25	37	0	applied	\N
19	18	37	1	applied	\N
20	4	34	0	applied	\N
20	26	35	0	applied	\N
21	1	67	0	applied	\N
21	27	68	0	applied	\N
22	28	6	0	applied	\N
22	15	36	0	applied	\N
22	20	36	0	applied	\N
22	29	37	0	applied	\N
22	30	37	1	applied	\N
23	15	34	0	applied	\N
23	16	34	0	applied	\N
23	31	35	0	applied	\N
23	32	35	1	applied	\N
24	15	34	0	applied	\N
24	20	34	0	applied	\N
24	33	35	0	applied	\N
24	32	35	1	applied	\N
\.


--
-- Data for Name: blocks_user_commands; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.blocks_user_commands (block_id, user_command_id, sequence_no, status, failure_reason) FROM stdin;
2	1	15	applied	\N
2	2	16	applied	\N
2	3	17	applied	\N
2	4	18	applied	\N
2	5	19	applied	\N
2	6	20	applied	\N
2	7	21	applied	\N
2	8	22	applied	\N
3	9	22	applied	\N
3	10	23	applied	\N
3	11	24	applied	\N
3	12	25	applied	\N
3	13	26	applied	\N
3	14	27	applied	\N
3	15	28	applied	\N
3	16	29	applied	\N
3	17	30	applied	\N
3	18	31	applied	\N
3	19	32	applied	\N
4	20	21	applied	\N
4	21	22	applied	\N
4	22	23	applied	\N
4	23	24	applied	\N
4	24	25	applied	\N
4	25	26	applied	\N
4	26	27	applied	\N
4	27	28	applied	\N
4	28	29	applied	\N
4	29	30	applied	\N
4	30	31	applied	\N
5	31	22	applied	\N
5	32	23	applied	\N
5	33	24	applied	\N
5	34	25	applied	\N
5	35	26	applied	\N
5	36	27	applied	\N
5	37	28	applied	\N
5	38	29	applied	\N
5	39	30	applied	\N
5	40	31	applied	\N
5	41	32	applied	\N
6	42	21	applied	\N
6	43	22	applied	\N
6	44	23	applied	\N
6	45	24	applied	\N
6	46	25	applied	\N
6	47	26	applied	\N
6	48	27	applied	\N
6	49	28	applied	\N
6	50	29	applied	\N
6	51	30	applied	\N
6	52	31	applied	\N
7	53	22	applied	\N
7	54	23	applied	\N
7	55	24	applied	\N
7	56	25	applied	\N
7	57	26	applied	\N
7	58	27	applied	\N
7	59	28	applied	\N
7	60	29	applied	\N
7	61	30	applied	\N
7	62	31	applied	\N
8	53	22	applied	\N
8	54	23	applied	\N
8	55	24	applied	\N
8	56	25	applied	\N
8	57	26	applied	\N
8	58	27	applied	\N
8	59	28	applied	\N
8	60	29	applied	\N
8	61	30	applied	\N
8	62	31	applied	\N
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
9	74	35	applied	\N
9	75	36	applied	\N
9	76	37	applied	\N
9	77	38	applied	\N
9	78	39	applied	\N
9	79	40	applied	\N
9	80	41	applied	\N
9	81	42	applied	\N
9	82	43	applied	\N
9	83	44	applied	\N
9	84	45	applied	\N
10	85	25	applied	\N
10	86	26	applied	\N
10	87	27	applied	\N
10	88	28	applied	\N
10	89	29	applied	\N
10	90	30	applied	\N
10	91	31	applied	\N
10	92	32	applied	\N
10	93	33	applied	\N
10	94	34	applied	\N
10	95	35	applied	\N
11	85	25	applied	\N
11	86	26	applied	\N
11	87	27	applied	\N
11	88	28	applied	\N
11	89	29	applied	\N
11	90	30	applied	\N
11	91	31	applied	\N
11	92	32	applied	\N
11	93	33	applied	\N
11	94	34	applied	\N
11	95	35	applied	\N
12	96	24	applied	\N
12	97	25	applied	\N
12	98	26	applied	\N
12	99	27	applied	\N
12	100	28	applied	\N
12	101	29	applied	\N
12	102	30	applied	\N
12	103	31	applied	\N
12	104	32	applied	\N
12	105	33	applied	\N
12	106	34	applied	\N
13	107	24	applied	\N
13	108	25	applied	\N
13	109	26	applied	\N
13	110	27	applied	\N
13	111	28	applied	\N
13	112	29	applied	\N
13	113	30	applied	\N
13	114	31	applied	\N
13	115	32	applied	\N
13	116	33	applied	\N
13	117	34	applied	\N
13	118	35	applied	\N
13	119	36	applied	\N
13	120	37	applied	\N
13	121	38	applied	\N
13	122	39	applied	\N
13	123	40	applied	\N
13	124	41	applied	\N
13	125	42	applied	\N
13	126	43	applied	\N
13	127	44	applied	\N
13	128	45	applied	\N
14	129	25	applied	\N
14	130	26	applied	\N
14	131	27	applied	\N
14	132	28	applied	\N
14	133	29	applied	\N
14	134	30	applied	\N
14	135	31	applied	\N
14	136	32	applied	\N
14	137	33	applied	\N
14	138	34	applied	\N
15	129	25	applied	\N
15	130	26	applied	\N
15	131	27	applied	\N
15	132	28	applied	\N
15	133	29	applied	\N
15	134	30	applied	\N
15	135	31	applied	\N
15	136	32	applied	\N
15	137	33	applied	\N
15	138	34	applied	\N
16	139	24	applied	\N
16	140	25	applied	\N
16	141	26	applied	\N
16	142	27	applied	\N
16	143	28	applied	\N
16	144	29	applied	\N
16	145	30	applied	\N
16	146	31	applied	\N
16	147	32	applied	\N
16	148	33	applied	\N
16	149	34	applied	\N
16	150	35	applied	\N
16	151	36	applied	\N
16	152	37	applied	\N
16	153	38	applied	\N
16	154	39	applied	\N
16	155	40	applied	\N
16	156	41	applied	\N
16	157	42	applied	\N
16	158	43	applied	\N
16	159	44	applied	\N
16	160	45	applied	\N
17	161	24	applied	\N
17	162	25	applied	\N
17	163	26	applied	\N
17	164	27	applied	\N
17	165	28	applied	\N
17	166	29	applied	\N
17	167	30	applied	\N
17	168	31	applied	\N
17	169	32	applied	\N
17	170	33	applied	\N
17	171	34	applied	\N
18	161	24	applied	\N
18	162	25	applied	\N
18	163	26	applied	\N
18	164	27	applied	\N
18	165	28	applied	\N
18	166	29	applied	\N
18	167	30	applied	\N
18	168	31	applied	\N
18	169	32	applied	\N
18	170	33	applied	\N
18	171	34	applied	\N
19	172	25	applied	\N
19	173	26	applied	\N
19	174	27	applied	\N
19	175	28	applied	\N
19	176	29	applied	\N
19	177	30	applied	\N
19	178	31	applied	\N
19	179	32	applied	\N
19	180	33	applied	\N
19	181	34	applied	\N
19	182	35	applied	\N
20	183	24	applied	\N
20	184	25	applied	\N
20	185	26	applied	\N
20	186	27	applied	\N
20	187	28	applied	\N
20	188	29	applied	\N
20	189	30	applied	\N
20	190	31	applied	\N
20	191	32	applied	\N
20	192	33	applied	\N
21	193	24	applied	\N
21	194	25	applied	\N
21	195	26	applied	\N
21	196	27	applied	\N
21	197	28	applied	\N
21	198	29	applied	\N
21	199	30	applied	\N
21	200	31	applied	\N
21	201	32	applied	\N
21	202	33	applied	\N
21	203	34	applied	\N
21	204	35	applied	\N
21	205	36	applied	\N
21	206	37	applied	\N
21	207	38	applied	\N
21	208	39	applied	\N
21	209	40	applied	\N
21	210	41	applied	\N
21	211	42	applied	\N
21	212	43	applied	\N
21	213	44	applied	\N
21	214	45	applied	\N
21	215	46	applied	\N
21	216	47	applied	\N
21	217	48	applied	\N
21	218	49	applied	\N
21	219	50	applied	\N
21	220	51	applied	\N
21	221	52	applied	\N
21	222	53	applied	\N
21	223	54	applied	\N
21	224	55	applied	\N
21	225	56	applied	\N
21	226	57	applied	\N
21	227	58	applied	\N
21	228	59	applied	\N
21	229	60	applied	\N
21	230	61	applied	\N
21	231	62	applied	\N
21	232	63	applied	\N
21	233	64	applied	\N
21	234	65	applied	\N
21	235	66	applied	\N
22	236	25	applied	\N
22	237	26	applied	\N
22	238	27	applied	\N
22	239	28	applied	\N
22	240	29	applied	\N
22	241	30	applied	\N
22	242	31	applied	\N
22	243	32	applied	\N
22	244	33	applied	\N
22	245	34	applied	\N
22	246	35	applied	\N
23	247	24	applied	\N
23	248	25	applied	\N
23	249	26	applied	\N
23	250	27	applied	\N
23	251	28	applied	\N
23	252	29	applied	\N
23	253	30	applied	\N
23	254	31	applied	\N
23	255	32	applied	\N
23	256	33	applied	\N
24	247	24	applied	\N
24	248	25	applied	\N
24	249	26	applied	\N
24	250	27	applied	\N
24	251	28	applied	\N
24	252	29	applied	\N
24	253	30	applied	\N
24	254	31	applied	\N
24	255	32	applied	\N
24	256	33	applied	\N
\.


--
-- Data for Name: blocks_zkapp_commands; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.blocks_zkapp_commands (block_id, zkapp_command_id, sequence_no, status, failure_reasons_ids) FROM stdin;
2	1	0	failed	{1,2}
2	2	1	failed	{3,2}
2	3	2	failed	{4}
2	4	3	failed	{3,2}
2	5	4	failed	{4}
2	6	5	failed	{3,2}
2	7	6	failed	{4}
2	8	7	failed	{3,2}
2	9	8	failed	{4}
2	10	9	failed	{3,2}
2	11	10	failed	{4}
2	12	11	failed	{3,2}
2	13	12	failed	{4}
2	14	13	failed	{3,2}
2	15	14	failed	{4}
3	16	0	failed	{3,2}
3	17	1	failed	{4}
3	18	2	failed	{3,2}
3	19	3	failed	{4}
3	20	4	failed	{3,2}
3	21	5	failed	{4}
3	22	6	failed	{3,2}
3	23	7	failed	{4}
3	24	8	failed	{3,2}
3	25	9	failed	{4}
3	26	10	failed	{3,2}
3	27	11	failed	{4}
3	28	12	failed	{3,2}
3	29	13	failed	{4}
3	30	14	failed	{3,2}
3	31	15	failed	{4}
3	32	16	failed	{3,2}
3	33	17	failed	{4}
3	34	18	failed	{3,2}
3	35	19	failed	{4}
3	36	20	failed	{3,2}
3	37	21	failed	{4}
4	38	0	failed	{3,2}
4	39	1	failed	{4}
4	40	2	failed	{3,2}
4	41	3	failed	{4}
4	42	4	failed	{3,2}
4	43	5	failed	{4}
4	44	6	failed	{3,2}
4	45	7	failed	{4}
4	46	8	failed	{3,2}
4	47	9	failed	{4}
4	48	10	failed	{3,2}
4	49	11	failed	{4}
4	50	12	failed	{3,2}
4	51	13	failed	{4}
4	52	14	failed	{3,2}
4	53	15	failed	{4}
4	54	16	failed	{3,2}
4	55	17	failed	{4}
4	56	18	failed	{3,2}
4	57	19	failed	{4}
4	58	20	failed	{3,2}
5	59	0	failed	{4}
5	60	1	failed	{3,2}
5	61	2	failed	{4}
5	62	3	failed	{3,2}
5	63	4	failed	{4}
5	64	5	failed	{3,2}
5	65	6	failed	{4}
5	66	7	failed	{3,2}
5	67	8	failed	{4}
5	68	9	failed	{3,2}
5	69	10	failed	{4}
5	70	11	failed	{3,2}
5	71	12	failed	{4}
5	72	13	failed	{3,2}
5	73	14	failed	{4}
5	74	15	failed	{3,2}
5	75	16	failed	{4}
5	76	17	failed	{3,2}
5	77	18	failed	{4}
5	78	19	failed	{3,2}
5	79	20	failed	{4}
5	80	21	failed	{3,2}
6	81	0	failed	{4}
6	82	1	failed	{3,2}
6	83	2	failed	{4}
6	84	3	failed	{3,2}
6	85	4	failed	{4}
6	86	5	failed	{3,2}
6	87	6	failed	{4}
6	88	7	failed	{3,2}
6	89	8	failed	{4}
6	90	9	failed	{3,2}
6	91	10	failed	{4}
6	92	11	failed	{3,2}
6	93	12	failed	{4}
6	94	13	failed	{3,2}
6	95	14	failed	{4}
6	96	15	failed	{3,2}
6	97	16	failed	{4}
6	98	17	failed	{3,2}
6	99	18	failed	{4}
6	100	19	failed	{3,2}
6	101	20	failed	{4}
7	102	0	failed	{3,2}
7	103	1	failed	{4}
7	104	2	failed	{3,2}
7	105	3	failed	{4}
7	106	4	failed	{3,2}
7	107	5	failed	{4}
7	108	6	failed	{3,2}
7	109	7	failed	{4}
7	110	8	failed	{3,2}
7	111	9	failed	{4}
7	112	10	failed	{3,2}
7	113	11	failed	{4}
7	114	12	failed	{3,2}
7	115	13	failed	{4}
7	116	14	failed	{3,2}
7	117	15	failed	{4}
7	118	16	failed	{3,2}
7	119	17	failed	{4}
7	120	18	failed	{3,2}
7	121	19	failed	{4}
7	122	20	failed	{3,2}
7	123	21	failed	{4}
8	102	0	failed	{3,2}
8	103	1	failed	{4}
8	104	2	failed	{3,2}
8	105	3	failed	{4}
8	106	4	failed	{3,2}
8	107	5	failed	{4}
8	108	6	failed	{3,2}
8	109	7	failed	{4}
8	110	8	failed	{3,2}
8	111	9	failed	{4}
8	112	10	failed	{3,2}
8	113	11	failed	{4}
8	114	12	failed	{3,2}
8	115	13	failed	{4}
8	116	14	failed	{3,2}
8	117	15	failed	{4}
8	118	16	failed	{3,2}
8	119	17	failed	{4}
8	120	18	failed	{3,2}
8	121	19	failed	{4}
8	122	20	failed	{3,2}
8	123	21	failed	{4}
9	124	0	failed	{3,2}
9	125	1	failed	{4}
9	126	2	failed	{3,2}
9	127	3	failed	{4}
9	128	4	failed	{3,2}
9	129	5	failed	{4}
9	130	6	failed	{3,2}
9	131	7	failed	{4}
9	132	8	failed	{3,2}
9	133	9	failed	{4}
9	134	10	failed	{3,2}
9	135	11	failed	{4}
9	136	12	failed	{3,2}
9	137	13	failed	{4}
9	138	14	failed	{3,2}
9	139	15	failed	{4}
9	140	16	failed	{3,2}
9	141	17	failed	{4}
9	142	18	failed	{3,2}
9	143	19	failed	{4}
9	144	20	failed	{3,2}
9	145	21	failed	{4}
9	146	22	failed	{3,2}
9	147	23	failed	{4}
10	148	0	failed	{3,2}
10	149	1	failed	{4}
10	150	2	failed	{3,2}
10	151	3	failed	{4}
10	152	4	failed	{3,2}
10	153	5	failed	{4}
10	154	6	failed	{3,2}
10	155	7	failed	{4}
10	156	8	failed	{3,2}
10	157	9	failed	{4}
10	158	11	failed	{3,2}
10	159	12	failed	{4}
10	160	13	failed	{3,2}
10	161	14	failed	{4}
10	162	15	failed	{3,2}
10	163	16	failed	{4}
10	164	17	failed	{3,2}
10	165	18	failed	{4}
10	166	19	failed	{3,2}
10	167	20	failed	{4}
10	168	21	failed	{3,2}
10	169	22	failed	{4}
10	170	23	failed	{3,2}
10	171	24	failed	{4}
11	148	0	failed	{3,2}
11	149	1	failed	{4}
11	150	2	failed	{3,2}
11	151	3	failed	{4}
11	152	4	failed	{3,2}
11	153	5	failed	{4}
11	154	6	failed	{3,2}
11	155	7	failed	{4}
11	156	8	failed	{3,2}
11	157	9	failed	{4}
11	158	11	failed	{3,2}
11	159	12	failed	{4}
11	160	13	failed	{3,2}
11	161	14	failed	{4}
11	162	15	failed	{3,2}
11	163	16	failed	{4}
11	164	17	failed	{3,2}
11	165	18	failed	{4}
11	166	19	failed	{3,2}
11	167	20	failed	{4}
11	168	21	failed	{3,2}
11	169	22	failed	{4}
11	170	23	failed	{3,2}
11	171	24	failed	{4}
12	172	0	failed	{3,2}
12	173	1	failed	{4}
12	174	2	failed	{3,2}
12	175	3	failed	{4}
12	176	4	failed	{3,2}
12	177	5	failed	{4}
12	178	6	failed	{3,2}
12	179	7	failed	{4}
12	180	8	failed	{3,2}
12	181	9	failed	{4}
12	182	10	failed	{3,2}
12	183	11	failed	{4}
12	184	12	failed	{3,2}
12	185	13	failed	{4}
12	186	14	failed	{3,2}
12	187	15	failed	{4}
12	188	16	failed	{3,2}
12	189	17	failed	{4}
12	190	18	failed	{3,2}
12	191	19	failed	{4}
12	192	20	failed	{3,2}
12	193	21	failed	{4}
12	194	22	failed	{3,2}
12	195	23	failed	{4}
13	196	0	failed	{3,2}
13	197	1	failed	{4}
13	198	2	failed	{3,2}
13	199	3	failed	{4}
13	200	4	failed	{3,2}
13	201	5	failed	{4}
13	202	6	failed	{3,2}
13	203	7	failed	{4}
13	204	8	failed	{3,2}
13	205	9	failed	{4}
13	206	10	failed	{3,2}
13	207	11	failed	{4}
13	208	12	failed	{3,2}
13	209	13	failed	{4}
13	210	14	failed	{3,2}
13	211	15	failed	{4}
13	212	16	failed	{3,2}
13	213	17	failed	{4}
13	214	18	failed	{3,2}
13	215	19	failed	{4}
13	216	20	failed	{3,2}
13	217	21	failed	{4}
13	218	22	failed	{3,2}
13	219	23	failed	{4}
14	220	0	failed	{3,2}
14	221	1	failed	{4}
14	222	2	failed	{3,2}
14	223	3	failed	{4}
14	224	4	failed	{3,2}
14	225	5	failed	{4}
14	226	6	failed	{3,2}
14	227	7	failed	{4}
14	228	8	failed	{3,2}
14	229	9	failed	{4}
14	230	10	failed	{3,2}
14	231	11	failed	{4}
14	232	12	failed	{3,2}
14	233	13	failed	{4}
14	234	14	failed	{3,2}
14	235	16	failed	{4}
14	236	17	failed	{3,2}
14	237	18	failed	{4}
14	238	19	failed	{3,2}
14	239	20	failed	{4}
14	240	21	failed	{3,2}
14	241	22	failed	{4}
14	242	23	failed	{3,2}
14	243	24	failed	{4}
15	220	0	failed	{3,2}
15	221	1	failed	{4}
15	222	2	failed	{3,2}
15	223	3	failed	{4}
15	224	4	failed	{3,2}
15	225	5	failed	{4}
15	226	6	failed	{3,2}
15	227	7	failed	{4}
15	228	8	failed	{3,2}
15	229	9	failed	{4}
15	230	10	failed	{3,2}
15	231	11	failed	{4}
15	232	12	failed	{3,2}
15	233	13	failed	{4}
15	234	14	failed	{3,2}
15	235	16	failed	{4}
15	236	17	failed	{3,2}
15	237	18	failed	{4}
15	238	19	failed	{3,2}
15	239	20	failed	{4}
15	240	21	failed	{3,2}
15	241	22	failed	{4}
15	242	23	failed	{3,2}
15	243	24	failed	{4}
16	244	0	failed	{3,2}
16	245	1	failed	{4}
16	246	2	failed	{3,2}
16	247	3	failed	{4}
16	248	4	failed	{3,2}
16	249	5	failed	{4}
16	250	6	failed	{3,2}
16	251	7	failed	{4}
16	252	8	failed	{3,2}
16	253	9	failed	{4}
16	254	10	failed	{3,2}
16	255	11	failed	{4}
16	256	12	failed	{3,2}
16	257	13	failed	{4}
16	258	14	failed	{3,2}
16	259	15	failed	{4}
16	260	16	failed	{3,2}
16	261	17	failed	{4}
16	262	18	failed	{3,2}
16	263	19	failed	{4}
16	264	20	failed	{3,2}
16	265	21	failed	{4}
16	266	22	failed	{3,2}
16	267	23	failed	{4}
17	268	0	failed	{3,2}
17	269	1	failed	{4}
17	270	2	failed	{3,2}
17	271	3	failed	{4}
17	272	4	failed	{3,2}
17	273	5	failed	{4}
17	274	6	failed	{3,2}
17	275	7	failed	{4}
17	276	8	failed	{3,2}
17	277	9	failed	{4}
17	278	10	failed	{3,2}
17	279	11	failed	{4}
17	280	12	failed	{3,2}
17	281	13	failed	{4}
17	282	14	failed	{3,2}
17	283	15	failed	{4}
17	284	16	failed	{3,2}
17	285	17	failed	{4}
17	286	18	failed	{3,2}
17	287	19	failed	{4}
17	288	20	failed	{3,2}
17	289	21	failed	{4}
17	290	22	failed	{3,2}
17	291	23	failed	{4}
19	292	0	failed	{3,2}
19	293	1	failed	{4}
19	294	2	failed	{3,2}
19	295	3	failed	{4}
19	296	4	failed	{3,2}
19	297	5	failed	{4}
19	298	6	failed	{3,2}
19	299	7	failed	{4}
19	300	8	failed	{3,2}
19	301	9	failed	{4}
19	302	10	failed	{3,2}
19	303	11	failed	{4}
19	304	12	failed	{3,2}
19	305	13	failed	{4}
19	306	14	failed	{3,2}
19	307	15	failed	{4}
19	308	16	failed	{3,2}
19	309	17	failed	{4}
19	310	18	failed	{3,2}
19	311	19	failed	{4}
19	312	20	failed	{3,2}
19	313	22	failed	{4}
19	314	23	failed	{3,2}
19	315	24	failed	{4}
18	268	0	failed	{3,2}
18	269	1	failed	{4}
18	270	2	failed	{3,2}
18	271	3	failed	{4}
18	272	4	failed	{3,2}
18	273	5	failed	{4}
18	274	6	failed	{3,2}
18	275	7	failed	{4}
18	276	8	failed	{3,2}
18	277	9	failed	{4}
18	278	10	failed	{3,2}
18	279	11	failed	{4}
18	280	12	failed	{3,2}
18	281	13	failed	{4}
18	282	14	failed	{3,2}
18	283	15	failed	{4}
18	284	16	failed	{3,2}
18	285	17	failed	{4}
18	286	18	failed	{3,2}
18	287	19	failed	{4}
18	288	20	failed	{3,2}
18	289	21	failed	{4}
18	290	22	failed	{3,2}
18	291	23	failed	{4}
20	316	0	failed	{3,2}
20	317	1	failed	{4}
20	318	2	failed	{3,2}
20	319	3	failed	{4}
20	320	4	failed	{3,2}
20	321	5	failed	{4}
20	322	6	failed	{3,2}
20	323	7	failed	{4}
20	324	8	failed	{3,2}
20	325	9	failed	{4}
20	326	10	failed	{3,2}
20	327	11	failed	{4}
20	328	12	failed	{3,2}
20	329	13	failed	{4}
20	330	14	failed	{3,2}
20	331	15	failed	{4}
20	332	16	failed	{3,2}
20	333	17	failed	{4}
20	334	18	failed	{3,2}
20	335	19	failed	{4}
20	336	20	failed	{3,2}
20	337	21	failed	{4}
20	338	22	failed	{3,2}
20	339	23	failed	{4}
21	340	0	failed	{3,2}
21	341	1	failed	{4}
21	342	2	failed	{3,2}
21	343	3	failed	{4}
21	344	4	failed	{3,2}
21	345	5	failed	{4}
21	346	6	failed	{3,2}
21	347	7	failed	{4}
21	348	8	failed	{3,2}
21	349	9	failed	{4}
21	350	10	failed	{3,2}
21	351	11	failed	{4}
21	352	12	failed	{3,2}
21	353	13	failed	{4}
21	354	14	failed	{3,2}
21	355	15	failed	{4}
21	356	16	failed	{3,2}
21	357	17	failed	{4}
21	358	18	failed	{3,2}
21	359	19	failed	{4}
21	360	20	failed	{3,2}
21	361	21	failed	{4}
21	362	22	failed	{3,2}
21	363	23	failed	{4}
22	364	0	failed	{3,2}
22	365	1	failed	{4}
22	366	2	failed	{3,2}
22	367	3	failed	{4}
22	368	4	failed	{3,2}
22	369	5	failed	{4}
22	370	7	failed	{3,2}
22	371	8	failed	{4}
22	372	9	failed	{3,2}
22	373	10	failed	{4}
22	374	11	failed	{3,2}
22	375	12	failed	{4}
22	376	13	failed	{3,2}
22	377	14	failed	{4}
22	378	15	failed	{3,2}
22	379	16	failed	{4}
22	380	17	failed	{3,2}
22	381	18	failed	{4}
22	382	19	failed	{3,2}
22	383	20	failed	{4}
22	384	21	failed	{3,2}
22	385	22	failed	{4}
22	386	23	failed	{3,2}
22	387	24	failed	{4}
23	388	0	failed	{3,2}
23	389	1	failed	{4}
23	390	2	failed	{3,2}
23	391	3	failed	{4}
23	392	4	failed	{3,2}
23	393	5	failed	{4}
23	394	6	failed	{3,2}
23	395	7	failed	{4}
23	396	8	failed	{3,2}
23	397	9	failed	{4}
23	398	10	failed	{3,2}
23	399	11	failed	{4}
23	400	12	failed	{3,2}
23	401	13	failed	{4}
23	402	14	failed	{3,2}
23	403	15	failed	{4}
23	404	16	failed	{3,2}
23	405	17	failed	{4}
23	406	18	failed	{3,2}
23	407	19	failed	{4}
23	408	20	failed	{3,2}
23	409	21	failed	{4}
23	410	22	failed	{3,2}
23	411	23	failed	{4}
24	388	0	failed	{3,2}
24	389	1	failed	{4}
24	390	2	failed	{3,2}
24	391	3	failed	{4}
24	392	4	failed	{3,2}
24	393	5	failed	{4}
24	394	6	failed	{3,2}
24	395	7	failed	{4}
24	396	8	failed	{3,2}
24	397	9	failed	{4}
24	398	10	failed	{3,2}
24	399	11	failed	{4}
24	400	12	failed	{3,2}
24	401	13	failed	{4}
24	402	14	failed	{3,2}
24	403	15	failed	{4}
24	404	16	failed	{3,2}
24	405	17	failed	{4}
24	406	18	failed	{3,2}
24	407	19	failed	{4}
24	408	20	failed	{3,2}
24	409	21	failed	{4}
24	410	22	failed	{3,2}
24	411	23	failed	{4}
\.


--
-- Data for Name: epoch_data; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.epoch_data (id, seed, ledger_hash_id, total_currency, start_checkpoint, lock_checkpoint, epoch_length) FROM stdin;
1	2va9BGv9JrLTtrzZttiEMDYw1Zj6a6EHzXjmP9evHDTG3oEquURA	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	1
2	2vafPBQ3zQdHUEDDnFGuiNvJz7s2MhTLJgSzQSnu5fnZavT27cms	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKL8Lpm5EMf8fxdaaTkpp4JNVF8KogNC1TSuhnWtGMazbYjmfWa	2
3	2vbxfmSu8dcjww51V7uZ8mEefwodfuzCxZbNhBbaWwZLKk2cz3rA	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLhA17Jrf9vMyfSxDKmAuK2r8sDNs3aDnT5HKidt4iRXQrS8RXB	3
4	2vbhv4jr7najDKs1Q5Z7VrHHC2rZx33ABC2WriqsM2nFQdjz8zHE	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKSHBRCn27XoiY9MQjx1uKWdMEBfN1jnVpfrDtkxCWo94NvtwUi	4
5	2vaAqUznBL4RWRfeRp97AuPaFYypkPM7FepV2DfEhzvRgFTqHT23	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKAmt8ZQVoBKjXWZLvCMXQRPa733WgKEeCDn645dXExhdoV6mjk	5
6	2vbR3pKYoXDbTYVV5DgT8WVAfUamEBRPsH1wch3vLUJ4yGRFj6wE	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLioVPDBh46Ss8buybzY7mE3Bgu97Bh4C5aESYHFmuxt8uMhowm	6
7	2vaVv8rqzkLkrgNvp4pFpWBFpnTEXSYDcXdrGx5oovDx9t7peQuV	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLqUxSXQuT4NbqSEqWdpTaWcKCC9qcP6hG75prXErqrFVjRsboP	7
8	2vc2uDUB9pyagc3WK8QWBgBtc6N9afTEKeV4eEJFLUtYewEs7Lj1	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKHbhjenFFNgpR6dbwouS4nTRnxbwiUFMfbGhh5Z4YTrscEKeeE	8
9	2vaTHkRoHcPMsEs398XanZZ6P8wkNGdiesLgeqprcBz6yFSnCEzJ	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKHbhjenFFNgpR6dbwouS4nTRnxbwiUFMfbGhh5Z4YTrscEKeeE	8
10	2vbQZZKUYoC4qMeF1tXCSh3A1vYDfoTuN5DPhp716H9iVvjg3Y1N	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLRByo19hEBqHsk93xfmnrVo7Gvedu12z3ZWcPR3BDjRWbWTGT7	9
11	2vagxVsRHH45zR3sd2MCTfo8zvzSqvAGSUVpSxmtzRSNFtb6i6ap	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NL77YUdjd6WzoRFH44P6Zhp81bhqWmsi8ZUCVmZN1YVJ24xXzGG	10
12	2vafyKJZyzDQhNT2T6FK4ELWBmVsBoA4h8z76mpawEUDSvdEPMRD	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NL77YUdjd6WzoRFH44P6Zhp81bhqWmsi8ZUCVmZN1YVJ24xXzGG	10
13	2vb28WeedMHDZSE4PRitUHA3FJ2oJwxC4DpWX4crmt7Ska1zZfBf	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NL4wKDhZrE7QeCc3oxgRmfAvUGNrQLnkmthaDR589RKcHPHRwr8	11
14	2vaF615a36EtLgvLXabiDHjBXUHqbAVGNCE86nsEM1xj6c5EEp5m	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLQyje5QoyKKTS1by8cqR58qW3VcjmnaeggV1KcJ2kZNskn5nnW	12
15	2vbVj8dTJMsPe7zFDucU3TGfJDRb5j35EY8BTbfHDxsLK27c7gtv	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKDZeJysvGwEDSrq2UwudVu8qorvSd6dCaiLz2FzH4aBSobmkVd	13
16	2vaTMiXzDTtnAKWGjmtZhrY4prMmBpT9MggQC6VK2K7tQmPXhKHG	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKDZeJysvGwEDSrq2UwudVu8qorvSd6dCaiLz2FzH4aBSobmkVd	13
17	2vaq1ahqrjryw4SKPGiRMvqQtuE3ACqQRLypaHrnbkbxWDTEcGQQ	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKSdShh4g3Wtfe55zafNiD6qSewfzCiiv16t4W9PcAjkm694Ejz	14
18	2vaeKaoir6iLLRLcLpp5HhN5jNAMEs33WqmREtyNw5bRCvWuiKrS	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLLJeAwnX21PUJiKpLzi42Dz4zY7di2CVyEyhmSS4KGNuH5YASj	15
19	2vbF58mARRDBLdvUAfoMp121iBiKLZdi5DubrijBUdY9rpLjecj8	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLLJeAwnX21PUJiKpLzi42Dz4zY7di2CVyEyhmSS4KGNuH5YASj	15
20	2vbtWFUf1zAm55Rh6JC2vMGfSjFXKQnxffgX8DiR44xFk1HTJt8X	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLVLcmKmT34BfFTn9vvMAYzstd4vFUHQfpXwxRpWh6kssCrTrNh	16
21	2vbEKtMvdaGpBauPuL5yKrnBFwFihVr27XQg9M8CYApPaTAGYoFE	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKDEY9NZiLKre77oMrNtMiT4Q5nDnwWnTenAz1k8xxt4XHYQY13	17
22	2vbG9988iY3Z8Ej4BJisaZZ6bZVr4cNtQTqY378a6rkz23EGL1P4	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NKFL2agT1Z8PWA6Vzby7nvMA8Q3wJWZ2ML6U8G9VfYancMvSNSj	18
23	2vbZBAEevAj43JCaXGhR7xRqeYXCKEPh8qPWk8LoShuuBtcd16qn	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLBa2WV9VFeoiseShWeazYGUod2M6bkNG7XYYtYLtPti873GUPa	19
24	2vaMPFTptoevGarTDxRmKFQx7vbwoexQ6m7MQuLF3wu5CkzadoCQ	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLmTKHiNzHsXvpi4o1kWLHVxoEfsZGPLBDTioSR51P4fXVM51Yr	20
25	2vaWzUrcDyKxAQ2f6ggyp6Wzyx9WQgA58vhf9WQwvgKUmbZoHo6U	1	23166005000061388	3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x	3NLmTKHiNzHsXvpi4o1kWLHVxoEfsZGPLBDTioSR51P4fXVM51Yr	20
\.


--
-- Data for Name: internal_commands; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.internal_commands (id, command_type, receiver_id, fee, hash) FROM stdin;
1	coinbase	44	720000000000	5Jux6N1JajFo5AoxH9v7T4r3abZJo9pn11Y2BuXeYaY2uKxj84Qf
2	fee_transfer	44	77000000000	5JuzuhCsdpUXDnSLZikQuv9bbQyGKsTLCuTCmTJaXRhhD6nqg2RG
3	fee_transfer	44	112750000000	5JuaWnV5u9R4DLXnzcZ5gxkDKjQvH1TFU9mnzDN7ziBMcaRCswyG
4	coinbase	26	720000000000	5JtpKQtT6U7SiJ9kkzCGBKhT1YGi2uXvdjugernt2zVEePqmL9Mv
5	fee_transfer	26	107750000000	5JtsUEhQgb1Sk8GrEsP64CSfUXUhPfZ9pyapoT23cVNUjbEaafKG
6	fee_transfer	44	112500000000	5Juwt7cNmhsDrzw7Xe1hMqqQg9EBZzoW1qRsD8fBAx1UEWNYj5q4
7	fee_transfer	26	112500000000	5Jv1PSbQT99x4Qzf6iKwozC4b9jaKrczAFWKRRkXZT2CgUAhQCT2
8	fee_transfer	26	125500000000	5JupZsNs8xFREFTH8q8gc4oh4faJWKgcevTqayGpMyAuXi2y7ARg
9	fee_transfer	44	50000000000	5Jv8SqcDEFppUwa7zGHDnokcvyGi9pZRFeAyrzu7grtR4h5o14mq
10	fee_transfer	44	72750000000	5Ju7VqN9gw6krpWvBQzdovosgQGUiTbkEyy37xNrym24UPQ1CVpb
11	fee_transfer	26	50000000000	5JvRsNLuTNZ6JrUBczRqQMYYxrLzkMLbkhQHFv8dviPFy4Ck5TSd
12	fee_transfer	26	72750000000	5JuE7i3KQuGm6haeSGr2ur3KkUAvduWPthp55tHjHkz6ueu8opYN
13	fee_transfer	44	122750000000	5Jugx1to9dsSS78zEXBjfCJwL4HMhgXgq48VQentsE8zZ1kugkzn
14	fee_transfer	26	75000000000	5Jv74ZRg6xqxZ6vEMvn8cf8mQLe1FoE9fgkfMZUPo12z4xK5nAQ9
15	fee_transfer_via_coinbase	181	1000000	5JvGEmagVf89ojd6GecJB6wqz2dtRpexbECK36GZsL9ShPyZUDwT
16	coinbase	26	720000000000	5JuHSagCXmJa5fJK8azcRxL3KkgBiCWo5zKjXqWEwrRCW6XsmFbK
17	fee_transfer	26	47437000000	5JuHvt2yo35oLLhjkhas2q4UiPz1VBZv9g7KuTddo9YL3ZVsR2n4
18	fee_transfer	181	63000000	5Jv577YSk1NBZpRW2rVj38nB2Ftbp16Y3V7qZ1cyQsb4aa4vsHAj
19	fee_transfer	44	75000000000	5Jv7PvhPeeLd4m5voHz34pfACGAGXZ72bQFaaJJjVUMNH7khzJue
20	coinbase	44	720000000000	5Jtr6434ZYHZp9uQ8AnVFCvbWzgaSC5KpGKVqSNiAN1iGbkiBuNn
21	fee_transfer	44	47437000000	5Ju8oQxg3GyiyuZisxAthmbGbz4rmHPkua3QQiR2opePqUtgEbFv
22	fee_transfer	44	125500000000	5JvE6D595vd1Qhf2sWGbLpYjoPSTHJ4zPDHqU2px7UfMVJK1jHD3
23	fee_transfer	26	122750000000	5JtXaqypnMiFHGNhPDSxP5tLmsY2ihu17t6hhFmMMzX2j4fAM4E2
24	fee_transfer	44	105000000000	5JuU9Xm7yfDiCm8Mi3i78QJQ6AVBC2yNEYMh2MAjuizRJmrg1eBb
25	fee_transfer	44	17687000000	5JvGnCZuFXJhEN39jCiDyCQzcNkC6njHS1wV7A8BUUZwv5LJWnsJ
26	fee_transfer	26	122500000000	5JucetAukK2fq9Me2L4qjgf9n58zu87oWTAuJs3WWZXCQk74p3JA
27	fee_transfer	44	130750000000	5Ju7mRa9vajAfqfRhaDkZZ5nuiVLiZpHQr1wfyX5a2iKe4HDca5J
28	fee_transfer	44	30000000000	5JuupW4zHeSFyJRwmgDUJTqApYtjzJn2ewihawexSY2b9mE47rDV
29	fee_transfer	44	92695000000	5JtXte1m3LF4AcemWS6wVdE4c8V4dmV2LAyWZ4mCHSUT4MW1NPyW
30	fee_transfer	181	55000000	5JvRoiQBQCypvW99AtRVpTXFDzWUL6SJeL8x2RuBocp7dqYTpMzq
31	fee_transfer	26	122495000000	5JtfV4vvRZ8FRwbEMXjNw5F2WiACnG6WvVJWWYF2AadYXZjYkHuz
32	fee_transfer	181	5000000	5Ju9oRqokvewtetjAQ5kEN1UCTS1FL9sMSxrNEPM6We5oX7mQ1n5
33	fee_transfer	44	122495000000	5JuHWUE8R3rTSwDzQPubb2c37RYeaeyoSApdym91TowPHjpQ7eAH
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
25	B62qmjJAouMKFsmqx9XMiMuF6pfavJnt7GZxqxnvju17mAwK96vC3pd
26	B62qqtGZ5sjKRMGQKHdemR1oiVM5r8G64Pz9v4xETThaRbcvssv8VNi
27	B62qoGEe4SECC5FouayhJM3BG1qP6kQLzp3W9Q2eYWQyKu5Y1CcSAy1
28	B62qn8rXK3r2GRDEnRQEgyQY6pax17ZZ9kiFNbQoNncMdtmiVGnNc8Y
29	B62qnjQ1xe7MS6R51vWE1qbG6QXi2xQtbEQxD3JQ4wQHXw3H9aKRPsA
30	B62qmzatbnJ4ErusAasA4c7jcuqoSHyte5ZDiLvkxnmB1sZDkabKua3
31	B62qrS1Ry5qJ6bQm2x7zk7WLidjWpShRig9KDAViM1A3viuv1GyH2q3
32	B62qqSTnNqUFqyXzH2SUzHrW3rt5sJKLv1JH1sgPnMM6mpePtfu7tTg
33	B62qkLh5vbFwcq4zs8d2tYynGYoxLVK5iP39WZHbTsqZCJdwMsme1nr
34	B62qiqUe1zktgV9SEmseUCL3tkf7aosu8F8HPZPQq8KDjqt3yc7yet8
35	B62qkNP2GF9j8DQUbpLoGKQXBYnBiP7jqNLoiNUguvebfCGSyCZWXrq
36	B62qr4z6pyzZvdfrDi33Ck7PnPe3wddZVaa7DYzWHUGivigyy9zEfPh
37	B62qiWZKC4ff7RKQggVKcxAy9xrc1yHaXPLJjxcUtjiaDKY4GDmAtCP
38	B62qqCpCJ7Lx7WuKCDSPQWYZzRWdVGHndW4jNARZ8C9JB4M5osqYnvw
39	B62qo9mUWwGSjKLpEpgm5Yuw5qTXRi9YNvo5prdB7PXMhGN6jeVmuKS
40	B62qpRvBE7SFJWG38WhDrSHsm3LXMAhdiXXeLkDqtGxhfexCNh4RPqZ
41	B62qoScK9pW5SBdJeMZagwkfqWfvKAKc6pgPFrP72CNktbGKzVUdRs3
42	B62qkT8tFTiFfZqPmehQMCT1SRRGon6MyUBVXYS3q9hPPJhusxHLi9L
43	B62qkyTdCfzbZNuMqaqiyTSP1tw97Jjzb3ud4hTFX4MgQn9fSpJ5stU
44	B62qjKk3Fki71pFuMbdWopW1FDN4PYktSaw9yjshkr1uiyMjaewC7dZ
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
150	B62qjYRWXeQ52Y9ADFTp55p829ZE7DE4zn9Nd8puJc2QVyuiooBDTJ3
151	B62qo3b6pfzKVWNFgetepK6rXRekLgAYdfEAMHT6WwaSn2Ux8frnbmP
152	B62qncxbMSrL1mKqCSc6huUwDffg5qNDDD8FHtUob9d3CE9ZC2EFPhw
153	B62qpzLLC49Cb6rcpFyCroFiAtGtBCXny9xRbuMKi64vsU5QLoWDoaL
154	B62qj7bnmz2VYRtJMna4bKfUYX8DyQeqxKEmHaKSzE9L6v7fjfrMbjF
155	B62qnEQ9eQ94BxdECbFJjbkqCrPYH9wJd7B9rzKL7EeNqvYzAUCNxCT
156	B62qokmEKEJs6VUV7QwFaHHfEr6rRnFXQe9jbodnaDuWzfUK6YoXt2w
157	B62qpPJfgTfiSghnXisMvgTCNmyt7dA5MxXnpHfMaDGYGs8C3UdGWm7
158	B62qkzi5Dxf6oUaiJYzb5Kq78UG8fEKnnGuytPN78gJRdSK7qvkDK6A
159	B62qmAWW9xVz36RAwXkUBu9jEUvPYsxT5uwbEGKkwJywZRWogTewdRc
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
176	B62qpRU2ZGEM91KzR6c1FU3P75GujdidGnf7eGGG3ox1Hee2qva2n4v
177	B62qiuFiD6eX5mf4w52b1GpFMpk1LHtL3GWdQ4hxGLcxHh36RRmjpei
178	B62qokvW3jFhj1yz915TzoHubhFuR6o8QFQReVaTFcj8zpPF52EU9Ux
179	B62qr6AEDV6T66apiAX1GxUkCjYRnjWphyiDro9t9waw93xr2MW6Wif
180	B62qjYBQ6kJ9PJTTPnytp4rnaonUQaE8YuKeimJXHQUfirJ8UX8Qz4L
181	B62qpjJj43Cta3ucG5qheCUp7aw1xC5sidVQZAJdZqbyEN5TxJg9LH3
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
243	B62qqXU8cCzEkeedeZBaFz1DGasNsnjjXFmfFqMJUNco9rys7UQPRHj
\.


--
-- Data for Name: snarked_ledger_hashes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.snarked_ledger_hashes (id, value) FROM stdin;
1	jxNuBV1viAexEqSfKYubHTvrtCBrjaNjHowN7a8ViuNFpH15bBp
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
1	payment	159	159	159	0	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtaYT6DaooeQLHcqr2mhtSSq4XPMxV8LP8MBeqVGf9nkXjtssL6
2	payment	159	159	159	1	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv6uFgywUgm1r7PY9uE6L1TyUFAdku5jNtqsNKtvQFFaXEgJcqd
3	payment	159	159	159	2	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuvwMSRCd1PBzfKc7FfXr8etwnbvpVGkgrw6nkhW6MDjzhPr24Y
4	payment	159	159	159	3	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv8acKf4148D6YXH2i4XoE4tXvf4Zomv8BM4ETEYojvj2Vm6yzM
5	payment	159	159	159	4	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv2zBx58Ct5Dhb2FbVi8pi1iEq6fGwH2fxybspCtBwcXMr5YrNp
6	payment	159	159	159	5	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuXGgAWWjNdL8pGmuWMi1uNQHQ6N2N1FyHuwrUCexBQzq6cXmxm
7	payment	159	159	159	6	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuLbtemf7cPcf9nigbosCWTPjVeEa3FMnsEFkf1nJwH3AY6sx47
8	payment	159	159	159	7	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JudttyLdAdMXZFMPJytHAoao4eriZgwsArEGRdyeCCRzEA7sNU1
9	payment	159	159	159	8	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuXH2fPCjwkRk3CbjQeXJZVEqTTsJwx6QC7yV1kQJ7Mu9xe4rZz
10	payment	159	159	159	9	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju5YTB4UcV2a1sTatZLY4ZDn9sDf5oSkKPNR8mrav34heSWP6Eo
11	payment	159	159	159	10	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtjhB3co9aAH8KQdaaekjKBqUu37aD6w9sLYiQBWif3fYwRna4y
12	payment	159	159	159	11	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvENgTn38NK6zkmr2sBUL4C5TSrWAdtid9URwahrVDzvona6YPt
13	payment	159	159	159	12	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuSqZhw4DSXSfK2cFEVtPUZduEC2i63Bkcu3u8w3957Z7VP6z6F
14	payment	159	159	159	13	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JugCpgBCM819VfZ2XXHjp9fQz15H1FrcKQMQcXDheBwMQKTgZZD
15	payment	159	159	159	14	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvK9az2t5yDtoab6McVqXRLDKMSRiy3qWbxF2CgD5KzpZHDMKEV
16	payment	159	159	159	15	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JukhxTkFHoPYttWCLCnXetWttTbuaqA24a2YXFWsiDj87f3yV3r
17	payment	159	159	159	16	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv4FCRtnfA6QSnaauoQ4WLvPaziGjohUi3pNyfE9SpUCFkTfS6j
18	payment	159	159	159	17	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvRKPggwN6jQy91n9aMvdXRL7RcuoX4Ds5wEoGWnEgntxm8vzyQ
19	payment	159	159	159	18	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuTEgURPPL4Q2yRpUeHfd9xWuR6Vrh7mKNFPYZzoVwL7qehysZG
20	payment	159	159	159	19	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvA6gdCzcFLpwAqjfhK7kPJjAFFWKnnKkV7Yd6wMfWMTniNd8Qi
21	payment	159	159	159	20	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtm2TgyziqBrbzFtJjAK6qLWJwXjtxNYgmkoaHyX7UvKYE7gizo
22	payment	159	159	159	21	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvJETkMpqhwG7yneHFgjT6rZDHU2KuKkZZfuADkcHeV25YZPwCs
23	payment	159	159	159	22	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jurun4rcunm3mEt1WsNQdqNbGYGKZDmKAbdtVejkR757r454gr3
24	payment	159	159	159	23	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvBo5diBsqRkz1RSHuVqmtvZXPL5ewxVYr7cZbDoMei6FRZbGuD
25	payment	159	159	159	24	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuquvMXdNNvDKmmMbzuH7npQsdYsnqSxZPdFB5r4VzgHUpWhkM7
26	payment	159	159	159	25	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuDtVRMPTZbxh7873bNfdLLQCTLdXPzsd5HkysaWHwqDztrK89o
27	payment	159	159	159	26	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuJagcFrqzH7ob3u8qzrS1TNZLrnZBATfH4xFA5kaShYb4ikwu4
28	payment	159	159	159	27	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvFeBAzsJK6AonZjNCsCddr4DJdWNM7YgMvVeN8J8ZhC1iTJJ4k
29	payment	159	159	159	28	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuUzUsxKpRonGLCfkt3xpvoNE46dtMLm4yEmNEJE5eSqWjqkmnw
30	payment	159	159	159	29	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JufpcfjFcSJtKxE3t2m1gr26giAh3GQjPZ64ZEWhZkyjHnDk6wV
31	payment	159	159	159	30	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvN4DJkeQSB2SvyPjMWos3B8aoLW6Nj51rWEa7vCxTtsfesoo9s
32	payment	159	159	159	31	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuuVaDDVQhnpQ34zv1wMu8TbG4kfa1qBbWDN4zfqBbcfZLK9kYj
33	payment	159	159	159	32	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuJqDPGddue7BrEMXpctWpm8LtLbxHhyt7QnU5dGEDhLY7xg2z2
34	payment	159	159	159	33	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtkzRkRfwZgni7WXapZvNvb6f4EaGKPHKgUg1MfuAsJ24YvAY5H
35	payment	159	159	159	34	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JufKKmnFwh5LWFQeTRDAZE2LXDRUd7Qr7nk2EPanZHKAEnS95aA
36	payment	159	159	159	35	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuLTCW4DTiePEBt6vSmFB7Z5rX9xGcVoLymkKwj41K4gfpWvFpB
37	payment	159	159	159	36	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvPJQppCTJQV9ne8gAy8jrdqAG3ML7XEyN3St7mz1BCQRWfS6jb
38	payment	159	159	159	37	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv9eunfdSKy2sdt2bZuqjPGP25zkK6ttkjm8BBEqgPUFJ4ugG6C
39	payment	159	159	159	38	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuZNVebYhpCn7ejGnvDKYJcVui8JVJtLL3E24qowpnc3AmUS7C9
40	payment	159	159	159	39	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju61sdMubJrR94PiQXH8CiugV5MPUY7A15T5qRJV5umtbW2TuEJ
41	payment	159	159	159	40	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JufBSkfjbCyDTH8NxDzAsmdqz62QDNi9vLKtXi47bCEBBknWh3t
42	payment	159	159	159	41	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jud6NtHd87fzFHFiafutZ99ZQgdagNpBrtUctgdx7RMNPVVfnKQ
43	payment	159	159	159	42	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtbGLUqGG8nRnV19ftgePQuWEzN7ByAq9kyEv85taMfFFLjWxTr
44	payment	159	159	159	43	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvFFekQqsfyukquzR8zbTLFX478nhkaUHDrEpFxoxAAtmf482ed
45	payment	159	159	159	44	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuokxpNTv7rGDJzDc9sMH834hQFtAE2UgSxmgbU3gctS6APuk5o
46	payment	159	159	159	45	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuPrucoChEdk1GCwYQX7mcMtPjL9ZVUhD3SToE35AeEFTWcxC4b
47	payment	159	159	159	46	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JusGrukHD67EsA9a5aKKscebREzeSLCA14rb8hWWP1i27W5hw4U
48	payment	159	159	159	47	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtZnKUXr8rbTYGvYkQ8S8gE7f7otpPmmEtRK5Wj5oiA4ueuifcB
49	payment	159	159	159	48	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuSz6wo38JgKM5vDzvLDF8VsRidtho11DEuqwVem6m9J7hNZMPU
50	payment	159	159	159	49	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvBwKfEtAWvnDEXhkoeVCxtTi8qWBBtNYSWEpwhLjubmtK3BHEJ
51	payment	159	159	159	50	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JttA5oZwcSRiB1GuU35ioBJ7nD3x6kLABzhGRUuCMWU17S6fF4G
52	payment	159	159	159	51	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuUh8rkgv4DzfShi1oRcntYc3kz7BX6phVhQrdPVanNPZHfdAMd
53	payment	159	159	159	52	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JutuyquQNturZEqkgzMYKFcQfGpxJAEphXQmujLZW2QaNtacS7g
54	payment	159	159	159	53	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtwVFvHk9x9FexeqAeryN7Fx56LhM4M3X7ADjVcQSocM8v4DxKE
55	payment	159	159	159	54	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JufW8GsmizgqtGsVXddzuQ5yBdhe1UMtBeAx77wif3Rqhp1wUYD
56	payment	159	159	159	55	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtenPk5NoogXW5HPpak9wQgvP7AN4h1xr3eXZNyq1aK2K7FWQC1
57	payment	159	159	159	56	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtkdyunQ9k651G6TGQja6T8K8GJG3gE7y7HCw7cJ2iSgdgKq2rE
58	payment	159	159	159	57	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuMXmXMd7pQRjrKgF8B5is6YukZH6Er1Uz9eAJX8AR2naRt8Lu6
59	payment	159	159	159	58	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JthdBgkG22Quo2pT3SYtoX5UzGg9DJez4sgwYUkh2KpzZHTEybh
60	payment	159	159	159	59	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuLmahgG2ERMVnhu2iT84or8qYgznTpXQXDctRVfcUihDHeKb5b
61	payment	159	159	159	60	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JunmPJRGn7PWHLX6VWU31FaHcDjzaKQuxjmqFR9cRNxAGPXZnoc
62	payment	159	159	159	61	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuLoHkkDDeA5Uj6Z1aP9uipSEuFAMQR5Fe5tkvdCrCv4z6jFD5A
63	payment	159	159	159	62	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JureQ9z8GeQVXcgENzPR4av3eZqtJe963yHswJiUK61yNGEFRkB
64	payment	159	159	159	63	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JutHoHXwvdjuxfA1phw9K95YzVGXBicGwbhuzrrcRV2A23ibwdV
65	payment	159	159	159	64	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv6DPpuYWM6qxzhTuZVrseqsmE54bWcHws9XcVjjUgvLWLqhP9Z
66	payment	159	159	159	65	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtvZEmqT1oAa7XB7idDSu2NqagfG7TVcyDg93vDQ1Cso6rS639U
67	payment	159	159	159	66	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtXCkvSaCQze82qmTDjSuAcKcAFaH9tytAv2iURoYbNpbyGJpUE
68	payment	159	159	159	67	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju4gvCSPFpVpKJVxDXfvViUwBuj1gzd5VAMwdaZUkRZ7GqqqLwh
69	payment	159	159	159	68	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv7qfooVkCVBzYYg6Lgg8xxjBa4evqAXbErAj4tqhq5Q1NF5h7v
70	payment	159	159	159	69	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuL3cVK5eTDAp8cRGGHx82mSiKgbEgyWZzoadd623TLgUCCaKoz
71	payment	159	159	159	70	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JttYLo1cThZMYFqQ8LL1jNcZw2x8UhaQG3PgUKerCWiEWfMWGuQ
72	payment	159	159	159	71	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JthCoBUBqTNfwKMxwS2hgLP6ifu2doCUCm5tu8NKX6b1N4wrrKb
73	payment	159	159	159	72	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvMkrSgizfb2GLyrdYVH5zr2FxoDJY28pET3pR1rXBNXQ5tF2pJ
74	payment	159	159	159	73	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvJRX6vBju5dnKjQRCfuT6eP3o2RDgz5EdL8GE43HZ275RwNStL
75	payment	159	159	159	74	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JurSkPBAFHTF9fzNQhVjPnssuQChhxGfHdVDKbamVbrP6RYzWu1
76	payment	159	159	159	75	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JubQCzsBgwSJ4n4cjdC2vJa7NAfuwUHvD16S7UUXMKu6457epT7
77	payment	159	159	159	76	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuMSm25Wna3nkxcgWsiU5UWpCRhRLe6mGtLUi9vW4aYtwbYhYPm
78	payment	159	159	159	77	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuErBz9WoTuXEtfE98jjaLdbe4ndfZR5urPEeZdyiMatkhRbYmX
79	payment	159	159	159	78	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvBS31x4UmTVCCpnHk7ocGcwGYT6aX9BzzN5HAdNquKqULYNpQk
80	payment	159	159	159	79	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtwT7ejiCJ1cfyh2RrAPQW79mzxpKWnnVfbYrenDj8ALTwWvnqF
81	payment	159	159	159	80	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JucEcD4veaHxMY2nSFRwszUXSCkQtdpLvAU4kmMo71YqwWJqu7N
82	payment	159	159	159	81	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JutYGkAbMJJTnZDAbTNxFML2zrNqELeLZuCEYsd8VNh2yfJ9YK1
83	payment	159	159	159	82	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvHwY6sgMMuTZDyC2gtcFhuhC7vhmYYGgivVyUuLgqkBQhiYBQz
84	payment	159	159	159	83	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuKvQ4fWmdqg7hm2fXAQWFUwppseFEJ8bKbrFA3TrjDTUUiTcYs
85	payment	159	159	159	84	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuBn8c324nKcwhohLGVCjeBBF5pFh987LFstgXYew76cgUXb5MN
86	payment	159	159	159	85	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju1XdBTNb1tgy1wz8djLc6V4Cv9FPDivNkL8GsSyAkWUQun8Uyk
87	payment	159	159	159	86	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtpmY5Vy1FdvTVqUxmJcw8eV3sTS1padsc6ctCTnxjwdEdNkNVs
88	payment	159	159	159	87	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju7k1mapBQzuu2yE7jdae9u9jrBooxJub6nw7ag5EJQ73ymsnpo
89	payment	159	159	159	88	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuPzeKHjg6181oEVie7d5VNvGQT6Phz1hAMygqpbhQStigvRTYq
90	payment	159	159	159	89	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuTbezcQeRpZNNt8iWTrDZpT1EPtGJCnzg1q5SMKc69xNBwwhv7
91	payment	159	159	159	90	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuGzyYBY1o4ido6YrdLK85YGXX55PbAnkkcxRyxzF7CSXEd58tw
92	payment	159	159	159	91	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtfCRQTPaSxbXJe15T7Rjb2tNhatyeLZc4etmLQGuGUoHo7ZpuM
93	payment	159	159	159	92	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv1X3UNWfCq8CiNRRonMUQHLaCZpsTnUwEzUFKCafsQKNh5MKcT
94	payment	159	159	159	93	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv7do4iddwQbUA7vb1kvj8RMSY8BeQ4293Bwsrw3azhedFQh2Fn
95	payment	159	159	159	94	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JucgsV2VZiMsFHpUsqas9bFxV64N1x9vmhwpHW6DEHpbPVBPHM8
96	payment	159	159	159	95	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JthqdnpGdY25swuw3CMAYh1a9HnBt4MgBTgns8JhhB238UMNQd9
97	payment	159	159	159	96	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuRBWH3EatiJo9VkdBqzSbbeYgSqvbhmBN6BBEQskDoefpgnVCa
98	payment	159	159	159	97	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuSeHAcvhJFGBKTzCL4xJgnfmNDqDvCGfk6hKyhSczg4esdCLSZ
99	payment	159	159	159	98	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtmVZ7kaokfHyieferGUscn7j3XfUCno7Wv7y1LJ3eS3JyN26NU
100	payment	159	159	159	99	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtaC6xYEut56PaTQcrvb7Pcw8Znch5hcoXHx2RcWZwLoaUhHssJ
101	payment	159	159	159	100	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvD7NhaFtSa1y5C9ozdf4Vw9YFNtbnNaMdEKguaKzfioV67bbay
102	payment	159	159	159	101	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jupsra6VA9jo1cZTYkaqUga9ehW8Z1FNvKBJLNJfUSJXF5R2nsq
103	payment	159	159	159	102	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuyEe7futRbye8J6og4EHQjsv4FisuX8UExyxxWsaxx92jcao88
104	payment	159	159	159	103	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvB349j5tfNbvYnpB6p17HEmdNrZBbX8Y84kNyKZDuKZksj8Een
105	payment	159	159	159	104	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuTzZqSxR9ELwV56dgCrL1fq2m9SJuytWrtchXxQzrNi9JW4h6t
106	payment	159	159	159	105	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtbeq28hEUR3KvPjwpY7bq3UgVzRX6ZuZkv8shRaX3Qbr4hrkWc
107	payment	159	159	159	106	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuLnKPP26gKzKA3cUQaRS2vqEjJ74BA7XiyGxXWYNLwBhTt4x3W
108	payment	159	159	159	107	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv53ewfbaiBSJhBv8HLcemP1rdyGvTz63HGGxZquVjcnbaDY18n
109	payment	159	159	159	108	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JujC4YoTPJGMS763g4x5FvTqP7HpPu534AGCJjry5wD4exdSxGo
110	payment	159	159	159	109	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuPSGVpMiHUnNhwkQY5V2GDzrXMuhRxUwx1tnYgvsnGwaLSZWhJ
111	payment	159	159	159	110	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuWZvSvCW2tykPRaHNQZ3in8QYxSh4YJQZayZFjDrVm52t2Twt6
112	payment	159	159	159	111	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuV6StBQeAAibzeHMhHZGBEP5qeRA4zT8z3Phz1opacvbtFseKy
113	payment	159	159	159	112	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JttPQiKU2g1U7apU59UwxXWrt2FjnccrRkSHGTc1XpyK7u9PbSy
114	payment	159	159	159	113	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuJh37MUt7ZDwXiQWTpVgsPBwmACEjdsF1ra6hcaaqRacKMnxVg
115	payment	159	159	159	114	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtv3KzNRoteBnAhGSSfSSiHLu9biJMhGGwjDUwZTuAKQxSXzH2K
116	payment	159	159	159	115	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jumg9NfHBJQoNkmGPgZnyNKiouC6XVR3jfH48PDhEZm3QuY3eLD
117	payment	159	159	159	116	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jte9RpCj6uMdUrKPJeLSm9D3CXvYiqhFVice5k2os1ccNkDHj13
118	payment	159	159	159	117	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvHRc5QLyg4QJ89nvvsJDb1gKgN2cRwNyZViLmQdUQcBMSLhN8u
119	payment	159	159	159	118	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju8Yf7zrkGtgGjovRNZt9ALRKAu1LFDpA8Nxib7kwRgWu5q3XAQ
120	payment	159	159	159	119	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvBNj7wG6jq8x2HydncD1qoMwEEC9ZEb4EP13bLJitwz7P1XxPu
121	payment	159	159	159	120	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv6j5tyzGvHffuZFNDH3vEphdfubdVpB6uMn5RZZ3wXg8YwBU2R
122	payment	159	159	159	121	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JttJbHxs7T6Nh5zb9CobbxRVfUayt763Ydxucw9iniaWxkpSKxC
123	payment	159	159	159	122	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvNumXqn9dzS3NZoGSxxTeEqzm4jS9AQEUWGsxXue4xpcc41bDf
124	payment	159	159	159	123	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtbKzUFwxFPRbD5kA6JJnPjNnpXPR1T8NaEBfmu4ic9WN1CrBFb
125	payment	159	159	159	124	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvHoKyZetfpbLxzRTveGuiPQjmj9gpgrLS8X6bLoc8SBrfEhq9m
126	payment	159	159	159	125	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju5H4oj3wg6UgNhgWionGQXvkwB9Y1MuZzt4RnmaW5qMWiyYtYb
127	payment	159	159	159	126	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtgyNf81wf2ZSyqTB3pSkWdrYeVcbPS6xPB9YNcn9nccgz7WcyM
128	payment	159	159	159	127	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuC7HQYVMh8kuvzdagc3qgMFpqvstFa6A7LAAdPtVVnPbrtXDiT
129	payment	159	159	159	128	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtZGMtxRdaUbkSBX7Vusevr5ogfDJfQRTXBLVR7ixdbYuspEQTL
130	payment	159	159	159	129	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juqo3nmGJSmume3Nb72YUBrda2s1rK9oFraLtqSp7gsFMHrB7ou
131	payment	159	159	159	130	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuSwqUg8U7f3yT6MW7KyUCzaiodqfd2vthbxGKzLfYadYXpVZq5
132	payment	159	159	159	131	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuEMA392Y64mpfDW7GS6LSSrcuKBH4NRxND9M1rcdBSYxZ8YtHE
133	payment	159	159	159	132	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuhD1Nai1AkodDXuStduWDdwqEZCyD9PFVn45Lh7CSnkD8bBLa8
134	payment	159	159	159	133	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtpcJiFBy22gagRbxY5g3WTcNGaWSdQV4NcvLXVubacRDRQ7fgB
135	payment	159	159	159	134	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvHj7KKTZigZ8dxBgggbRjUHtYNM29RvMZZnTgqKEMSZi52rrzQ
136	payment	159	159	159	135	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv4DqLtXyNP56MKDv6aZyufaZWiDAjnwgJAe5sKtq8vfHi2y2oD
137	payment	159	159	159	136	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvG225jzkgNHp9EWP6tdvEwN1e8wZKdtyyZVSpWu6XWKfoNvNDm
138	payment	159	159	159	137	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JujCmPaSuCeso7FWbJS6ohYyDTUr2dRqab3KDedw9TgduJoMboR
139	payment	159	159	159	138	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvRCLjhBLzGLqvmdq3cMA3tnfPE9uSCnKkb7GZ81Gr282qRRGrv
140	payment	159	159	159	139	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtbpcSaPrASbcdqZpB7kyxzeLqQgsKLNqd8B4HdVBtRVGVZjr4R
141	payment	159	159	159	140	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JutBrtpxLgTA9wo4EAHPpkygeSV8hDqyDZcaMb62zy4ZPAETdDs
142	payment	159	159	159	141	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JueXxqbbGyCbRu69APofSHzqEV6TQph38ovWKbxcQgU2vFfaZks
143	payment	159	159	159	142	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvA5K1hTAruSSxD5FzThghipsKUwtz7ATKSHTwVAMkor8QHndJX
144	payment	159	159	159	143	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuTZtPWojC9hXMwhY3814rJgHZcoW3vPxud9e4PEsxU1EQxnQsW
145	payment	159	159	159	144	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv6FhVZxnpZ4vdEcQZRCocSsrKqKVpqCX75gi1nQ4frXGPKz23j
146	payment	159	159	159	145	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JufTVm8a2nYhg4UbJVZQcPhD7AjDysZJkVwpW7PhsKJJcTde2BB
147	payment	159	159	159	146	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuLpBvCefgwfTq9d5e76ShTX8rqozT7GhT8P81799XaVvmnEMGR
148	payment	159	159	159	147	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtq16Jkx77PGXfQ9LpomU1wPkDMNu5oCJaqrPu3L6iYQ3961oww
149	payment	159	159	159	148	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JumuKeUDQo6mBKtyXv1uFAQHBU6CNPvgcTdcfEfYqYhFEuhGoDL
150	payment	159	159	159	149	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv2PiXzCDUyUQiWdoutcKcNtV3tzV3KDhDZCRnAympYhzxNkP8F
151	payment	159	159	159	150	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuTaQpHMqAMCemeDbKRvbFQB7KWr5cjNEggVgqcpopdq9eFYKAU
152	payment	159	159	159	151	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JusoCdVnmFEqRZsfZXxtjgiXYDwVWVdUwqHxxDrzhfLMkcgwK53
153	payment	159	159	159	152	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju6vF96WooQSi8JdW9Nx9UDhD7f4szQdYPuEmaMXo3GTrTzkFhj
154	payment	159	159	159	153	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuRFNoSUcvpVkvRNdJut1BxgSgvgQaeuiJKMYNbFZQEpyph89Pw
155	payment	159	159	159	154	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv3PXmvu21tzQuBrW7Xd5LiLtXrXxURJ53Zy1hmnZvg4B61qbWf
156	payment	159	159	159	155	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuWG1xtdbFwvo3EDdczojFvJqmLhaaF4pD3kWKX2vysTcPooKNf
157	payment	159	159	159	156	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvFVVQmWuT4P4yUug2qb6XA1bvJjNu5yZmDqWgzgWogedhpdzD5
158	payment	159	159	159	157	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JugokaqAwZGQZ5eTQdYPjq2PmTacxpKkG5gumzM16JU213Lnnq7
159	payment	159	159	159	158	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv3L4aTPRz7guMi1S2DMoW325n7XLsj5L6sH4NEWCXfVidKKhuf
160	payment	159	159	159	159	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtzsEHQt7dvSkYHKHmEtYUJj1fKLSeqUPMjVusXQHCu7FZih4g4
161	payment	159	159	159	160	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju9HwC31oihYk438V4mMrZdP7MjWoDKuUGZqJzeDT3GLWPoyH1N
162	payment	159	159	159	161	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju4T6ecggSCwtopcQwtVLC1sG18VzSJFbHSWqgFY5s6u14xi9Hq
163	payment	159	159	159	162	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtgxqUQcDVDhQSyjN3TpZ84h8norzpg1j3ePBh8AGCbf3fQrC4G
164	payment	159	159	159	163	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtiWEGbKPpnhfULnSoYuWUxZCaeBh1ns82cebT2bnaYnRLU5AeK
165	payment	159	159	159	164	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju339z7NNP6vSZRBXyH1Ah29FULYABAM3BGYBu4KZrQu4ufUThn
166	payment	159	159	159	165	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuNUXvtgoGEYgdJqvwzKw2ad6cDfRSrHE7X7Y2pPWCmPYKqEmoZ
167	payment	159	159	159	166	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuM7sQhBA7qZdexEm18zN8cQ3aRy6SUCWqBjCD4p2zUx7npwTU2
168	payment	159	159	159	167	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju1MsArRNobp3mx6RkRrgnm6zxhcNmjy2WZ2MhR1JGza3nYsyfF
169	payment	159	159	159	168	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtZj1wb2KQuWUEegtvaTLcM4WkzRqZ5pr44Cg1fsC6sF59rxvow
170	payment	159	159	159	169	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuSuZ1TNYmpdv1QZmX5TBt8HtPCosyAwnYCY6mYkCakV2JfRX2x
171	payment	159	159	159	170	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvRLK15cyk3VANJG3and9AogxyjhP3CTMvfGL8HUFrW87iiLzW4
172	payment	159	159	159	171	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuegJdjAJMuoVziHmSFxNzFXXPPS3DYF2crNj3SXWnqxrecEdHf
173	payment	159	159	159	172	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtXWbzy3wTDdcaynqo328F6SrRGm9QnqQswDHsu9JAeNpccdP7y
174	payment	159	159	159	173	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtyG9UuNm2UpfkVSu8iqHyN6kXuaRdtZQazvGjRnqVPRLbsYRDL
175	payment	159	159	159	174	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuAXxVhaCbYnBuMwyXnJHrQWyCi4hLpvnZXXBNDvwyWKgrMFTTw
176	payment	159	159	159	175	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvFEqNmtTnQXeJqzxN53dgAvpf4WJs8tccPJPQKANxK6t6TeVMt
177	payment	159	159	159	176	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvPQ4ZEdfMP58f7LMsuuamn8p1Kn4MUhWaLUg8eyhr1628LysBz
178	payment	159	159	159	177	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv5rCdgFptqd9fo7GGtCXFQ2tHadNM3ytN1CvCj3VYQ8B5S4t6i
179	payment	159	159	159	178	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuNnwXrDxja33kF36eEVYEA7P4vs6e9DFhf1foWwsu2GxJiu6sd
180	payment	159	159	159	179	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jun6dftjaWoTCp3v1hrbc4tzWth36a1Adr8xxGx4TimpwNsEz2s
181	payment	159	159	159	180	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juz33WaYFL2wA8wwq7DFQv58Nt1jQhAaRYZQCotk9SBG9QwPYXT
182	payment	159	159	159	181	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtbXkg3o4GB2V5H74NXjdFVTCvkpvkaMNUNkzJp6dGoY6cKvFbN
183	payment	159	159	159	182	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtX4XVvbnXGGZfKUweRzU3AG7q4kV93t8bQk1HgWTB4hnqhv6Nx
184	payment	159	159	159	183	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juge6AVN2JjqNwzawRfsFr1ayYFRCSGjKv5kHbpsc13vWcVf2QS
185	payment	159	159	159	184	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvAyRq75kN5NKMHZpsdf6P5b85z5MyxMKgvJGS3JPjgcnLGgVgU
186	payment	159	159	159	185	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JufRymfMeHEUoiZSwxF2mCctDJkdisDmukSAJBcr47NCHNS7PXQ
187	payment	159	159	159	186	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju5TXEeFDBLdDckvUo7hfhcYdgEANsY9rN9pkBerLnmyQnuCyFz
188	payment	159	159	159	187	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtXvyqq5weHK95wM2DV4dssJfyeFhLWJmwu3GZjgj6EER9EoB7X
189	payment	159	159	159	188	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvHuAH8WCmtSBf7AkewgdnCYgFLVq555V6tP3iSXcMiC6YzutNp
190	payment	159	159	159	189	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvJqCJQzRCiUpNienMVBrxFaSmR4nHxTTUqcKJKRnfAyexXS61C
191	payment	159	159	159	190	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtVWMk6uWfJpfcTSbDdjKa1arznkUD32jTT7v4hG93QVAGvPCze
192	payment	159	159	159	191	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JteeGgjbiJWfNNFPPjJgQounTgqjHQCciWXRxoEVKX7MT5o7RoH
193	payment	159	159	159	192	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuAnCNvKJgtCtXj1xX1wMgdZTcZYDe23TVefh1pXUq9PwB2V4qM
194	payment	159	159	159	193	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvNfQ5aDu8nFiS6weaicy4K4APmG4AexwPRLGKXWSpDAwA8Lj5n
195	payment	159	159	159	194	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuCp9yGWaQHc31SPLgPhneFTZR1vx9aaK3wFVz13HPUpPEFtyuw
196	payment	159	159	159	195	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvEz5grU5Pbr67ihEsVUDroA1njE9UBZaYztqY8omvrkgyRqN52
197	payment	159	159	159	196	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JunwVLGbJ68HcD4iZSXrqZBCk7EUmMN2pisGSgWmrAXTZgMk2du
198	payment	159	159	159	197	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuDxDchJHahAXhmRsERZRNJDr61cWybrjJ91JHqDBBHj5DEunoc
199	payment	159	159	159	198	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju9GzcaeNzdQ7Cq6zu4UiuqQEeGDE8fxqTgtuQvZh5Jj3Y3Dcnz
200	payment	159	159	159	199	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvC1RDX6FaNo1RnPJVPURCwASSgibEJjTzfgL6EsL9RTXV6gbEn
201	payment	159	159	159	200	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuE45LrWkzBiuASeDftPK4ftHhG9VTLiwkkSSCvDT1FeCgRR2sJ
202	payment	159	159	159	201	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju67CmFWHujBiNiECWZy1PScAHu1HypLi2wmqp1tVNMt4RTxwvw
203	payment	159	159	159	202	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JupV2TiBZGeWbDQsvyLSVBnK6F2owoAyeTRg73dR3BnmAwfC3fj
204	payment	159	159	159	203	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuCQHJ4f9azWNM2yjyaHac8kjdTSFhPYyP1UmbsTzzxvwEBUsfC
205	payment	159	159	159	204	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuqVqi1F61PUNDyAVHEyzTdpP9qMUvRj3WFWqitvx9zBQ8ujU9d
206	payment	159	159	159	205	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuC5opYZtySLjPkJS29jL6m7SnrrYRyi3JgYw6B61qbEvg8meuT
207	payment	159	159	159	206	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Judb35ngT7P46gFyncNeko9smYYMFzfo49qzKNstcs41Q3Goeyg
208	payment	159	159	159	207	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JufKAPEaS8cE8F4Y7vzCnRv5Mmckh7Ln8xCgpcvgkScXsdtM7nL
209	payment	159	159	159	208	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju3M6eX73YoGxrFK3A2MBNqQ2KXNFj7qCpdhBikfdAjiA7VeNUX
210	payment	159	159	159	209	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JusApARD7UyzYyp6Sxcdo68vLM51L1i784Zd2rtZPjDvvgrW5aC
211	payment	159	159	159	210	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtiNyFxyJf9SroxbXUZSCD77QG4dd2L5HAUetnKXbDMGUEkmeKT
212	payment	159	159	159	211	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvLXuoWvCFuk7deepshTUPUHRSENdNugWrEGSSTZmMUyBpkCeLK
213	payment	159	159	159	212	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtnpni85o98FAEszXvBC3KYnBqH2ZD8vJKiJ9xZrwNC7q5BPz4x
214	payment	159	159	159	213	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuYadH5C5ozHanyhts92HsuJMpa7aQ5oQQxcnCk5aYpByMkJEgK
215	payment	159	159	159	214	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvEkXXP91ugMDjzuWjfnMHBKk4cGHQYrLwj3Ytrpp7QBc8gW7T5
216	payment	159	159	159	215	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtbz9RpMzGezkctouGnFoVCoRVdVdPsUTiLzcXppMk5Jf4cmFSt
217	payment	159	159	159	216	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvKetxvRCozuzmngMngt9haRP21xbja5Sq1WyyMMcGQUGSri2nG
218	payment	159	159	159	217	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtvPKq1cZB3dfJmLMmH4avgKYqfSeCSGJzsgoLTNi5XWki3QeDe
219	payment	159	159	159	218	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JthrVaveVfCNnoXj5RMgbkT4LCbrtrjArD1xvgYMX4tfsYbqM6G
220	payment	159	159	159	219	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtuQUFtMdukEP3xfSGHUshTgBqdn72AmKjhCEaBLQ4Su4fFgrtC
221	payment	159	159	159	220	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuAUVGGoAwJ6TpmQg1HnwCA4ZG5o9W4QuydoWhsp6jSCdQ3nnWH
222	payment	159	159	159	221	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvJvkLxJeTJprYtKfFuSLKMzTnsvyeeraSwcB9SKQYLe3ELE2Zs
223	payment	159	159	159	222	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvH2QeRT2g27SdSXNzAatqQ4dSRwWtSc8eaffsjKg5E77qwWwV2
224	payment	159	159	159	223	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtbxr8oAomCkd7GMDLEsf8Vtb6A6Mxp92UoW6rmovbM599SFsuz
225	payment	159	159	159	224	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuV9ExSwZx7wXUjHrium4cMVWhTmJLudeRr2vWXZ3V9ZGY7WZXK
226	payment	159	159	159	225	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juorhir6Jo2BqSJqUr2ZFT77pwcYyi7ufcDqrr1diXGuJ2L1yRM
227	payment	159	159	159	226	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju1xXp1AT85pxMpCc5qd1dAUWMJSx1BSjJJJu3RcheRPEt6TvD6
228	payment	159	159	159	227	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuwMpa1BsLwr4qHd5oYembTNkCV9duw7Jc3MwQg29vrXPJ6uq5P
229	payment	159	159	159	228	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuBMXD1JZUEfQ7zXfQX2e4HJRt7gHEsFmXrstFDf3iFMTHqh4Z9
230	payment	159	159	159	229	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvNUDwg6MZedFn9goEEDY4bAB35ueF2ayEG2fx9upqkYky7opNp
231	payment	159	159	159	230	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuXj7uHgeZqMCdHD1fQbZBpzRUCiZkuVFeDue2eaM4U3XNaK7hA
232	payment	159	159	159	231	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvEJNi7b4ZjGWKPwdbNVqibr1MYUyPwrVhq9EpUs1x2fpCLn4L2
233	payment	159	159	159	232	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JumgGcQ9KKBnf5tsRbbVEXUwjyQr3UNpR6JbracZLWLkUVGjYuV
234	payment	159	159	159	233	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv3w2d5fUEaHvqqGJENEVrMh6qQcfRfWDPdicKeSXK3J27Lq2fs
235	payment	159	159	159	234	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtjvabJhwsqrXsK4qsPqRKdMHhXryNrU7ExXtYDyZoLgNSA9875
236	payment	159	159	159	235	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuNKgKD6hSuNd8gjFYudLpDU6E5eu8tLVLdRANCckN3s6WZQUVz
237	payment	159	159	159	236	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtug9Gfg2rD1CpbbZGYTddAfA1WHQL2XHVkNuTEqLyFqjU1Ub1W
238	payment	159	159	159	237	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv7j5VJpdd5p4pUVv6fho1tpP7MBsZQRz7VqXTUpbF82Pu9xYFG
239	payment	159	159	159	238	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuwFuD26aviMvsnErp7Dmjnjb3FQkksFTFzrptaC5zKpKLNghna
240	payment	159	159	159	239	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju1u9eZ9yy7YaLPtMiCSLjVZcrVcYLVVdxvws88GyYE9ik4yeA1
241	payment	159	159	159	240	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuF5NAaePCUkrbZtxcS3cdUXf8yN49ZsV9rJ73ZnRQvy6nghi8q
242	payment	159	159	159	241	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JttPddLXbN8WkzK9xkjH9Q8RtFSepWkK6reERDKZsTYYu8Nd4ZU
243	payment	159	159	159	242	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv3xtBxuB6ybwpc4RMebht93qHDzqJF1y2uGmZaahEfWW21esPc
244	payment	159	159	159	243	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju9GwzSUi1CnkJtGCxLa466UH1skNNxYmufFrsqWH1Wxyo9qRUX
245	payment	159	159	159	244	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtqo7bA9VNBQZ6rTETUfY6D4hSgTEryaTWbqEa5DkRe3asJVbEt
246	payment	159	159	159	245	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juo7G1mwTAGEFkKzptjZWPjWST8qN2kPF5BWzBazw8eyL5KLXiL
247	payment	159	159	159	246	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JusWakBtwy2sJTzkiFFFpNrP6HgaLMHSQZfj52ndThbRP1hJ3em
248	payment	159	159	159	247	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtcXAc7RMdGeAvq9Jj8hYJ5opYZiWAe2ZC4DoGPJz1yiuPxDHzN
249	payment	159	159	159	248	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuNM2on9f21Sf6jUAPsRA7n6tPmL5EHnahG6JNhftB6PUid3vWQ
250	payment	159	159	159	249	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv3MJuJLjLzAwiWxaQYPTtBK8VBNbwxRYnwizcGAtPF6BVfsd3C
251	payment	159	159	159	250	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JufNWv7hPraNxLkZ8HXUxdAizat3izhqYQZ7zwK5kKaJUR9dJAY
252	payment	159	159	159	251	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JugtrD2Rc6VWau2EtbnSke3PjZ8TKbJNioNjb9F1EHYspQk4Gqy
253	payment	159	159	159	252	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jud36kVv1nSgQAPCnCcb3YFz2VRZeR38wvPmNN3ZfJGGUxn1bxj
254	payment	159	159	159	253	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju8QzwrmMmuXuSa4uxmSrDGmDg1nMHAoDxrE7NWYrX14d6c6q6Z
255	payment	159	159	159	254	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvQRw5Xm9RhZjaRjG48YJ8keWDs9bATH4P9XM5X7Wx8x9jUNZ1o
256	payment	159	159	159	255	1000000000	250000000	\N	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuaMFtbnrjMTiUGmn3jYwHA2EBrim61kTRowBCHnUNeuRSHrEJw
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
159	\N	158	\N	\N	1	\N	\N	\N	1
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
183	\N	182	\N	\N	1	\N	\N	\N	1
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
171	\N	170	\N	\N	1	\N	\N	\N	1
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
207	\N	206	\N	\N	1	\N	\N	\N	1
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
\.


--
-- Data for Name: zkapp_account_update_body; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.zkapp_account_update_body (id, account_identifier_id, update_id, balance_change, increment_nonce, events_id, actions_id, call_data_id, call_depth, zkapp_network_precondition_id, zkapp_account_precondition_id, zkapp_valid_while_precondition_id, use_full_commitment, implicit_account_creation_fee, may_use_token, authorization_kind, verification_key_hash_id) FROM stdin;
1	41	1	-1000000000000	t	1	1	1	0	1	1	\N	f	f	No	Signature	\N
2	243	2	999000000000	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
3	41	1	-1000000000	t	1	1	1	0	1	3	\N	f	f	No	Signature	\N
4	243	1	1000000000	f	1	1	1	0	1	2	\N	f	f	No	None_given	\N
5	243	3	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
6	41	1	-1000000000	t	1	1	1	0	1	4	\N	f	f	No	Signature	\N
7	243	4	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
8	41	1	-1000000000	t	1	1	1	0	1	5	\N	f	f	No	Signature	\N
9	243	5	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
10	41	1	-1000000000	t	1	1	1	0	1	6	\N	f	f	No	Signature	\N
11	243	6	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
12	41	1	-1000000000	t	1	1	1	0	1	7	\N	f	f	No	Signature	\N
13	243	7	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
14	41	1	-1000000000	t	1	1	1	0	1	8	\N	f	f	No	Signature	\N
15	243	8	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
16	41	1	-1000000000	t	1	1	1	0	1	9	\N	f	f	No	Signature	\N
17	243	9	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
18	41	1	-1000000000	t	1	1	1	0	1	10	\N	f	f	No	Signature	\N
19	243	10	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
20	41	1	-1000000000	t	1	1	1	0	1	11	\N	f	f	No	Signature	\N
21	243	11	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
22	41	1	-1000000000	t	1	1	1	0	1	12	\N	f	f	No	Signature	\N
23	243	12	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
24	41	1	-1000000000	t	1	1	1	0	1	13	\N	f	f	No	Signature	\N
25	243	13	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
26	41	1	-1000000000	t	1	1	1	0	1	14	\N	f	f	No	Signature	\N
27	243	14	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
28	41	1	-1000000000	t	1	1	1	0	1	15	\N	f	f	No	Signature	\N
29	243	15	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
30	41	1	-1000000000	t	1	1	1	0	1	16	\N	f	f	No	Signature	\N
31	243	16	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
32	41	1	-1000000000	t	1	1	1	0	1	17	\N	f	f	No	Signature	\N
33	243	17	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
34	41	1	-1000000000	t	1	1	1	0	1	18	\N	f	f	No	Signature	\N
35	243	18	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
36	41	1	-1000000000	t	1	1	1	0	1	19	\N	f	f	No	Signature	\N
37	243	19	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
38	41	1	-1000000000	t	1	1	1	0	1	20	\N	f	f	No	Signature	\N
39	243	20	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
40	41	1	-1000000000	t	1	1	1	0	1	21	\N	f	f	No	Signature	\N
41	243	21	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
42	41	1	-1000000000	t	1	1	1	0	1	22	\N	f	f	No	Signature	\N
43	243	22	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
44	41	1	-1000000000	t	1	1	1	0	1	23	\N	f	f	No	Signature	\N
45	243	23	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
46	41	1	-1000000000	t	1	1	1	0	1	24	\N	f	f	No	Signature	\N
47	243	24	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
48	41	1	-1000000000	t	1	1	1	0	1	25	\N	f	f	No	Signature	\N
49	243	25	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
50	41	1	-1000000000	t	1	1	1	0	1	26	\N	f	f	No	Signature	\N
51	243	26	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
52	41	1	-1000000000	t	1	1	1	0	1	27	\N	f	f	No	Signature	\N
53	243	27	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
54	41	1	-1000000000	t	1	1	1	0	1	28	\N	f	f	No	Signature	\N
55	243	28	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
56	41	1	-1000000000	t	1	1	1	0	1	29	\N	f	f	No	Signature	\N
57	243	29	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
58	41	1	-1000000000	t	1	1	1	0	1	30	\N	f	f	No	Signature	\N
59	243	30	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
60	41	1	-1000000000	t	1	1	1	0	1	31	\N	f	f	No	Signature	\N
61	243	31	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
62	41	1	-1000000000	t	1	1	1	0	1	32	\N	f	f	No	Signature	\N
63	243	32	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
64	41	1	-1000000000	t	1	1	1	0	1	33	\N	f	f	No	Signature	\N
65	243	33	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
66	41	1	-1000000000	t	1	1	1	0	1	34	\N	f	f	No	Signature	\N
67	243	34	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
68	41	1	-1000000000	t	1	1	1	0	1	35	\N	f	f	No	Signature	\N
69	243	35	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
70	41	1	-1000000000	t	1	1	1	0	1	36	\N	f	f	No	Signature	\N
71	243	36	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
72	41	1	-1000000000	t	1	1	1	0	1	37	\N	f	f	No	Signature	\N
73	243	37	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
74	41	1	-1000000000	t	1	1	1	0	1	38	\N	f	f	No	Signature	\N
75	243	38	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
76	41	1	-1000000000	t	1	1	1	0	1	39	\N	f	f	No	Signature	\N
77	243	39	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
78	41	1	-1000000000	t	1	1	1	0	1	40	\N	f	f	No	Signature	\N
79	243	40	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
80	41	1	-1000000000	t	1	1	1	0	1	41	\N	f	f	No	Signature	\N
81	243	41	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
82	41	1	-1000000000	t	1	1	1	0	1	42	\N	f	f	No	Signature	\N
83	243	42	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
84	41	1	-1000000000	t	1	1	1	0	1	43	\N	f	f	No	Signature	\N
85	243	43	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
86	41	1	-1000000000	t	1	1	1	0	1	44	\N	f	f	No	Signature	\N
87	243	44	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
88	41	1	-1000000000	t	1	1	1	0	1	45	\N	f	f	No	Signature	\N
89	243	45	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
90	41	1	-1000000000	t	1	1	1	0	1	46	\N	f	f	No	Signature	\N
91	243	46	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
92	41	1	-1000000000	t	1	1	1	0	1	47	\N	f	f	No	Signature	\N
93	243	47	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
94	41	1	-1000000000	t	1	1	1	0	1	48	\N	f	f	No	Signature	\N
95	243	48	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
96	41	1	-1000000000	t	1	1	1	0	1	49	\N	f	f	No	Signature	\N
97	243	49	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
98	41	1	-1000000000	t	1	1	1	0	1	50	\N	f	f	No	Signature	\N
99	243	50	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
100	41	1	-1000000000	t	1	1	1	0	1	51	\N	f	f	No	Signature	\N
101	243	51	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
102	41	1	-1000000000	t	1	1	1	0	1	52	\N	f	f	No	Signature	\N
103	243	52	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
104	41	1	-1000000000	t	1	1	1	0	1	53	\N	f	f	No	Signature	\N
105	243	53	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
106	41	1	-1000000000	t	1	1	1	0	1	54	\N	f	f	No	Signature	\N
107	243	54	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
108	41	1	-1000000000	t	1	1	1	0	1	55	\N	f	f	No	Signature	\N
109	243	55	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
110	41	1	-1000000000	t	1	1	1	0	1	56	\N	f	f	No	Signature	\N
111	243	56	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
112	41	1	-1000000000	t	1	1	1	0	1	57	\N	f	f	No	Signature	\N
113	243	57	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
114	41	1	-1000000000	t	1	1	1	0	1	58	\N	f	f	No	Signature	\N
115	243	58	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
116	41	1	-1000000000	t	1	1	1	0	1	59	\N	f	f	No	Signature	\N
117	243	59	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
118	41	1	-1000000000	t	1	1	1	0	1	60	\N	f	f	No	Signature	\N
119	243	60	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
120	41	1	-1000000000	t	1	1	1	0	1	61	\N	f	f	No	Signature	\N
121	243	61	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
122	41	1	-1000000000	t	1	1	1	0	1	62	\N	f	f	No	Signature	\N
123	243	62	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
124	41	1	-1000000000	t	1	1	1	0	1	63	\N	f	f	No	Signature	\N
125	243	63	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
126	41	1	-1000000000	t	1	1	1	0	1	64	\N	f	f	No	Signature	\N
127	243	64	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
128	41	1	-1000000000	t	1	1	1	0	1	65	\N	f	f	No	Signature	\N
129	243	65	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
130	41	1	-1000000000	t	1	1	1	0	1	66	\N	f	f	No	Signature	\N
131	243	66	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
132	41	1	-1000000000	t	1	1	1	0	1	67	\N	f	f	No	Signature	\N
133	243	67	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
134	41	1	-1000000000	t	1	1	1	0	1	68	\N	f	f	No	Signature	\N
135	243	68	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
136	41	1	-1000000000	t	1	1	1	0	1	69	\N	f	f	No	Signature	\N
137	243	69	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
138	41	1	-1000000000	t	1	1	1	0	1	70	\N	f	f	No	Signature	\N
139	243	70	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
140	41	1	-1000000000	t	1	1	1	0	1	71	\N	f	f	No	Signature	\N
141	243	71	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
142	41	1	-1000000000	t	1	1	1	0	1	72	\N	f	f	No	Signature	\N
143	243	72	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
144	41	1	-1000000000	t	1	1	1	0	1	73	\N	f	f	No	Signature	\N
145	243	73	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
146	41	1	-1000000000	t	1	1	1	0	1	74	\N	f	f	No	Signature	\N
147	243	74	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
148	41	1	-1000000000	t	1	1	1	0	1	75	\N	f	f	No	Signature	\N
149	243	75	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
150	41	1	-1000000000	t	1	1	1	0	1	76	\N	f	f	No	Signature	\N
151	243	76	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
152	41	1	-1000000000	t	1	1	1	0	1	77	\N	f	f	No	Signature	\N
153	243	77	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
154	41	1	-1000000000	t	1	1	1	0	1	78	\N	f	f	No	Signature	\N
155	243	78	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
156	41	1	-1000000000	t	1	1	1	0	1	79	\N	f	f	No	Signature	\N
157	243	79	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
158	41	1	-1000000000	t	1	1	1	0	1	80	\N	f	f	No	Signature	\N
159	243	80	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
160	41	1	-1000000000	t	1	1	1	0	1	81	\N	f	f	No	Signature	\N
161	243	81	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
162	41	1	-1000000000	t	1	1	1	0	1	82	\N	f	f	No	Signature	\N
163	243	82	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
164	41	1	-1000000000	t	1	1	1	0	1	83	\N	f	f	No	Signature	\N
165	243	83	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
166	41	1	-1000000000	t	1	1	1	0	1	84	\N	f	f	No	Signature	\N
167	243	84	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
168	41	1	-1000000000	t	1	1	1	0	1	85	\N	f	f	No	Signature	\N
169	243	85	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
170	41	1	-1000000000	t	1	1	1	0	1	86	\N	f	f	No	Signature	\N
171	243	86	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
172	41	1	-1000000000	t	1	1	1	0	1	87	\N	f	f	No	Signature	\N
173	243	87	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
174	41	1	-1000000000	t	1	1	1	0	1	88	\N	f	f	No	Signature	\N
175	243	88	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
176	41	1	-1000000000	t	1	1	1	0	1	89	\N	f	f	No	Signature	\N
177	243	89	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
178	41	1	-1000000000	t	1	1	1	0	1	90	\N	f	f	No	Signature	\N
179	243	90	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
180	41	1	-1000000000	t	1	1	1	0	1	91	\N	f	f	No	Signature	\N
181	243	91	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
182	41	1	-1000000000	t	1	1	1	0	1	92	\N	f	f	No	Signature	\N
183	243	92	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
184	41	1	-1000000000	t	1	1	1	0	1	93	\N	f	f	No	Signature	\N
185	243	93	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
186	41	1	-1000000000	t	1	1	1	0	1	94	\N	f	f	No	Signature	\N
187	243	94	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
188	41	1	-1000000000	t	1	1	1	0	1	95	\N	f	f	No	Signature	\N
189	243	95	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
190	41	1	-1000000000	t	1	1	1	0	1	96	\N	f	f	No	Signature	\N
191	243	96	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
192	41	1	-1000000000	t	1	1	1	0	1	97	\N	f	f	No	Signature	\N
193	243	97	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
194	41	1	-1000000000	t	1	1	1	0	1	98	\N	f	f	No	Signature	\N
195	243	98	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
196	41	1	-1000000000	t	1	1	1	0	1	99	\N	f	f	No	Signature	\N
197	243	99	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
198	41	1	-1000000000	t	1	1	1	0	1	100	\N	f	f	No	Signature	\N
199	243	100	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
200	41	1	-1000000000	t	1	1	1	0	1	101	\N	f	f	No	Signature	\N
201	243	101	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
202	41	1	-1000000000	t	1	1	1	0	1	102	\N	f	f	No	Signature	\N
203	243	102	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
204	41	1	-1000000000	t	1	1	1	0	1	103	\N	f	f	No	Signature	\N
205	243	103	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
206	41	1	-1000000000	t	1	1	1	0	1	104	\N	f	f	No	Signature	\N
207	243	104	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
208	41	1	-1000000000	t	1	1	1	0	1	105	\N	f	f	No	Signature	\N
209	243	105	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
210	41	1	-1000000000	t	1	1	1	0	1	106	\N	f	f	No	Signature	\N
211	243	106	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
212	41	1	-1000000000	t	1	1	1	0	1	107	\N	f	f	No	Signature	\N
213	243	107	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
214	41	1	-1000000000	t	1	1	1	0	1	108	\N	f	f	No	Signature	\N
215	243	108	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
216	41	1	-1000000000	t	1	1	1	0	1	109	\N	f	f	No	Signature	\N
217	243	109	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
218	41	1	-1000000000	t	1	1	1	0	1	110	\N	f	f	No	Signature	\N
219	243	110	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
220	41	1	-1000000000	t	1	1	1	0	1	111	\N	f	f	No	Signature	\N
221	243	111	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
222	41	1	-1000000000	t	1	1	1	0	1	112	\N	f	f	No	Signature	\N
223	243	112	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
224	41	1	-1000000000	t	1	1	1	0	1	113	\N	f	f	No	Signature	\N
225	243	113	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
226	41	1	-1000000000	t	1	1	1	0	1	114	\N	f	f	No	Signature	\N
227	243	114	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
228	41	1	-1000000000	t	1	1	1	0	1	115	\N	f	f	No	Signature	\N
229	243	115	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
230	41	1	-1000000000	t	1	1	1	0	1	116	\N	f	f	No	Signature	\N
231	243	116	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
232	41	1	-1000000000	t	1	1	1	0	1	117	\N	f	f	No	Signature	\N
233	243	117	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
234	41	1	-1000000000	t	1	1	1	0	1	118	\N	f	f	No	Signature	\N
235	243	118	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
236	41	1	-1000000000	t	1	1	1	0	1	119	\N	f	f	No	Signature	\N
237	243	119	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
238	41	1	-1000000000	t	1	1	1	0	1	120	\N	f	f	No	Signature	\N
239	243	120	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
240	41	1	-1000000000	t	1	1	1	0	1	121	\N	f	f	No	Signature	\N
241	243	121	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
242	41	1	-1000000000	t	1	1	1	0	1	122	\N	f	f	No	Signature	\N
243	243	122	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
244	41	1	-1000000000	t	1	1	1	0	1	123	\N	f	f	No	Signature	\N
245	243	123	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
246	41	1	-1000000000	t	1	1	1	0	1	124	\N	f	f	No	Signature	\N
247	243	124	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
248	41	1	-1000000000	t	1	1	1	0	1	125	\N	f	f	No	Signature	\N
249	243	125	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
250	41	1	-1000000000	t	1	1	1	0	1	126	\N	f	f	No	Signature	\N
251	243	126	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
252	41	1	-1000000000	t	1	1	1	0	1	127	\N	f	f	No	Signature	\N
253	243	127	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
254	41	1	-1000000000	t	1	1	1	0	1	128	\N	f	f	No	Signature	\N
255	243	128	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
256	41	1	-1000000000	t	1	1	1	0	1	129	\N	f	f	No	Signature	\N
257	243	129	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
258	41	1	-1000000000	t	1	1	1	0	1	130	\N	f	f	No	Signature	\N
259	243	130	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
260	41	1	-1000000000	t	1	1	1	0	1	131	\N	f	f	No	Signature	\N
261	243	131	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
262	41	1	-1000000000	t	1	1	1	0	1	132	\N	f	f	No	Signature	\N
263	243	132	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
264	41	1	-1000000000	t	1	1	1	0	1	133	\N	f	f	No	Signature	\N
265	243	133	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
266	41	1	-1000000000	t	1	1	1	0	1	134	\N	f	f	No	Signature	\N
267	243	134	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
268	41	1	-1000000000	t	1	1	1	0	1	135	\N	f	f	No	Signature	\N
269	243	135	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
270	41	1	-1000000000	t	1	1	1	0	1	136	\N	f	f	No	Signature	\N
271	243	136	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
272	41	1	-1000000000	t	1	1	1	0	1	137	\N	f	f	No	Signature	\N
273	243	137	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
274	41	1	-1000000000	t	1	1	1	0	1	138	\N	f	f	No	Signature	\N
275	243	138	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
276	41	1	-1000000000	t	1	1	1	0	1	139	\N	f	f	No	Signature	\N
277	243	139	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
278	41	1	-1000000000	t	1	1	1	0	1	140	\N	f	f	No	Signature	\N
279	243	140	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
280	41	1	-1000000000	t	1	1	1	0	1	141	\N	f	f	No	Signature	\N
281	243	141	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
282	41	1	-1000000000	t	1	1	1	0	1	142	\N	f	f	No	Signature	\N
283	243	142	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
284	41	1	-1000000000	t	1	1	1	0	1	143	\N	f	f	No	Signature	\N
285	243	143	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
286	41	1	-1000000000	t	1	1	1	0	1	144	\N	f	f	No	Signature	\N
287	243	144	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
288	41	1	-1000000000	t	1	1	1	0	1	145	\N	f	f	No	Signature	\N
289	243	145	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
290	41	1	-1000000000	t	1	1	1	0	1	146	\N	f	f	No	Signature	\N
291	243	146	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
292	41	1	-1000000000	t	1	1	1	0	1	147	\N	f	f	No	Signature	\N
293	243	147	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
294	41	1	-1000000000	t	1	1	1	0	1	148	\N	f	f	No	Signature	\N
295	243	148	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
296	41	1	-1000000000	t	1	1	1	0	1	149	\N	f	f	No	Signature	\N
297	243	149	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
298	41	1	-1000000000	t	1	1	1	0	1	150	\N	f	f	No	Signature	\N
299	243	150	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
300	41	1	-1000000000	t	1	1	1	0	1	151	\N	f	f	No	Signature	\N
301	243	151	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
302	41	1	-1000000000	t	1	1	1	0	1	152	\N	f	f	No	Signature	\N
303	243	152	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
304	41	1	-1000000000	t	1	1	1	0	1	153	\N	f	f	No	Signature	\N
305	243	153	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
306	41	1	-1000000000	t	1	1	1	0	1	154	\N	f	f	No	Signature	\N
307	243	154	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
308	41	1	-1000000000	t	1	1	1	0	1	155	\N	f	f	No	Signature	\N
309	243	155	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
310	41	1	-1000000000	t	1	1	1	0	1	156	\N	f	f	No	Signature	\N
311	243	156	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
312	41	1	-1000000000	t	1	1	1	0	1	157	\N	f	f	No	Signature	\N
313	243	157	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
314	41	1	-1000000000	t	1	1	1	0	1	158	\N	f	f	No	Signature	\N
315	243	158	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
316	41	1	-1000000000	t	1	1	1	0	1	159	\N	f	f	No	Signature	\N
317	243	159	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
318	41	1	-1000000000	t	1	1	1	0	1	160	\N	f	f	No	Signature	\N
319	243	160	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
320	41	1	-1000000000	t	1	1	1	0	1	161	\N	f	f	No	Signature	\N
321	243	161	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
322	41	1	-1000000000	t	1	1	1	0	1	162	\N	f	f	No	Signature	\N
323	243	162	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
324	41	1	-1000000000	t	1	1	1	0	1	163	\N	f	f	No	Signature	\N
325	243	163	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
326	41	1	-1000000000	t	1	1	1	0	1	164	\N	f	f	No	Signature	\N
327	243	164	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
328	41	1	-1000000000	t	1	1	1	0	1	165	\N	f	f	No	Signature	\N
329	243	165	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
330	41	1	-1000000000	t	1	1	1	0	1	166	\N	f	f	No	Signature	\N
331	243	166	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
332	41	1	-1000000000	t	1	1	1	0	1	167	\N	f	f	No	Signature	\N
333	243	167	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
334	41	1	-1000000000	t	1	1	1	0	1	168	\N	f	f	No	Signature	\N
335	243	168	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
336	41	1	-1000000000	t	1	1	1	0	1	169	\N	f	f	No	Signature	\N
337	243	169	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
338	41	1	-1000000000	t	1	1	1	0	1	170	\N	f	f	No	Signature	\N
339	243	170	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
340	41	1	-1000000000	t	1	1	1	0	1	171	\N	f	f	No	Signature	\N
341	243	171	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
342	41	1	-1000000000	t	1	1	1	0	1	172	\N	f	f	No	Signature	\N
343	243	172	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
344	41	1	-1000000000	t	1	1	1	0	1	173	\N	f	f	No	Signature	\N
345	243	173	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
346	41	1	-1000000000	t	1	1	1	0	1	174	\N	f	f	No	Signature	\N
347	243	174	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
348	41	1	-1000000000	t	1	1	1	0	1	175	\N	f	f	No	Signature	\N
349	243	175	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
350	41	1	-1000000000	t	1	1	1	0	1	176	\N	f	f	No	Signature	\N
351	243	176	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
352	41	1	-1000000000	t	1	1	1	0	1	177	\N	f	f	No	Signature	\N
353	243	177	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
354	41	1	-1000000000	t	1	1	1	0	1	178	\N	f	f	No	Signature	\N
355	243	178	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
356	41	1	-1000000000	t	1	1	1	0	1	179	\N	f	f	No	Signature	\N
357	243	179	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
358	41	1	-1000000000	t	1	1	1	0	1	180	\N	f	f	No	Signature	\N
359	243	180	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
360	41	1	-1000000000	t	1	1	1	0	1	181	\N	f	f	No	Signature	\N
361	243	181	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
362	41	1	-1000000000	t	1	1	1	0	1	182	\N	f	f	No	Signature	\N
363	243	182	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
364	41	1	-1000000000	t	1	1	1	0	1	183	\N	f	f	No	Signature	\N
365	243	183	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
366	41	1	-1000000000	t	1	1	1	0	1	184	\N	f	f	No	Signature	\N
367	243	184	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
368	41	1	-1000000000	t	1	1	1	0	1	185	\N	f	f	No	Signature	\N
369	243	185	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
370	41	1	-1000000000	t	1	1	1	0	1	186	\N	f	f	No	Signature	\N
371	243	186	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
372	41	1	-1000000000	t	1	1	1	0	1	187	\N	f	f	No	Signature	\N
373	243	187	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
374	41	1	-1000000000	t	1	1	1	0	1	188	\N	f	f	No	Signature	\N
375	243	188	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
376	41	1	-1000000000	t	1	1	1	0	1	189	\N	f	f	No	Signature	\N
377	243	189	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
378	41	1	-1000000000	t	1	1	1	0	1	190	\N	f	f	No	Signature	\N
379	243	190	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
380	41	1	-1000000000	t	1	1	1	0	1	191	\N	f	f	No	Signature	\N
381	243	191	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
382	41	1	-1000000000	t	1	1	1	0	1	192	\N	f	f	No	Signature	\N
383	243	192	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
384	41	1	-1000000000	t	1	1	1	0	1	193	\N	f	f	No	Signature	\N
385	243	193	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
386	41	1	-1000000000	t	1	1	1	0	1	194	\N	f	f	No	Signature	\N
387	243	194	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
388	41	1	-1000000000	t	1	1	1	0	1	195	\N	f	f	No	Signature	\N
389	243	195	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
390	41	1	-1000000000	t	1	1	1	0	1	196	\N	f	f	No	Signature	\N
391	243	196	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
392	41	1	-1000000000	t	1	1	1	0	1	197	\N	f	f	No	Signature	\N
393	243	197	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
394	41	1	-1000000000	t	1	1	1	0	1	198	\N	f	f	No	Signature	\N
395	243	198	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
396	41	1	-1000000000	t	1	1	1	0	1	199	\N	f	f	No	Signature	\N
397	243	199	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
398	41	1	-1000000000	t	1	1	1	0	1	200	\N	f	f	No	Signature	\N
399	243	200	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
400	41	1	-1000000000	t	1	1	1	0	1	201	\N	f	f	No	Signature	\N
401	243	201	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
402	41	1	-1000000000	t	1	1	1	0	1	202	\N	f	f	No	Signature	\N
403	243	202	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
404	41	1	-1000000000	t	1	1	1	0	1	203	\N	f	f	No	Signature	\N
405	243	203	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
406	41	1	-1000000000	t	1	1	1	0	1	204	\N	f	f	No	Signature	\N
407	243	204	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
408	41	1	-1000000000	t	1	1	1	0	1	205	\N	f	f	No	Signature	\N
409	243	205	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
410	41	1	-1000000000	t	1	1	1	0	1	206	\N	f	f	No	Signature	\N
411	243	206	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
412	41	1	-1000000000	t	1	1	1	0	1	207	\N	f	f	No	Signature	\N
413	243	207	0	f	1	1	1	0	1	2	\N	t	f	No	Signature	\N
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
1	1	{1,2}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juz6p8ruryWZJCGAt9uXfsvJGZXmawiHmFRnw6nXaJNp6SySXvo
2	2	{3,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtdrCY6cak9gLhjugKcB8vNSKCv5Vk685cJqtQfjmCjwpJ576SA
3	3	{5}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuDYrf8Ns1bcQMqnWarrt9qGDdWAXDXuQhpkkt9GU1X78TDgUmo
4	4	{6,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuJULc7XxjspYJJv3vrXSgbEB2kNc2Z4bb9dWJe4dNVxkKkbFaA
5	5	{7}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtqVgpUh9kdigVmLmBx755XRVDnjPunVuKKh7W3sSWTnqHAjLbv
6	6	{8,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JttTTwDHiaB5jAZ7KsWy194nBPdoNV85RRrKqduzNebXoJFVZzW
7	7	{9}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuoXjth1RWSJRxBft2LWyxSpq2He3e4r71GAg3GoAT6Z2Z6hTUX
8	8	{10,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtgm6B8YSffCk4XKs6Yd975UbHuYxeyPonTneBKny7HVtdHm29b
9	9	{11}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juj2msuc8vbG8pvWcPPQQnEPx4zFw7hqgYo2oVSBExwWuuHguyN
10	10	{12,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuZAti6NFXr2eQiHmJSyzcru86ARcUQDSTpTDRHknBsyHRHaPTm
11	11	{13}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtqxXDt117EiHwDubJNYnJ2Wuo7K8Ujv16bKhT7kqGKEkLrJrbd
12	12	{14,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtZsHjuPTFHaK3CMEUvCSymRDuxhLSUTvfP4rv5a56CLCNUPmve
13	13	{15}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuAZfseJRzKvxTwFBj7swJG7i1VPeYL7jtFekUFe19VqPsZtN9C
14	14	{16,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuUyPkKUD6iVjecntZXZjV77aXpCDhsdrBb7e6RjmcnKBeUHmro
15	15	{17}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JueavYHdDhZXwVMozjpZu3jPdkB51wapTFps4F5xWj9axNDirbz
16	16	{18,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jux4JA2WjAQSK1YFSP9uiSxn8vpA86UbeN7Tf6sVxay9MsqKWEp
17	17	{19}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juu7b7M9ZEYFMh6MAT4i6iDBaypkfwNixyiW9hRbneKTr5AopYE
18	18	{20,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvCKd8RB8AJbq9PtWEEJjY6Ft1aib9y3594gfdpXMy52EMr1wwj
19	19	{21}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuHdZnreLr8e852HjPUMVUf3jDUrF62jTu11fWCzUs6bTbUPoTc
20	20	{22,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtxtJj57UFem5CAKzKFsZbQP3cHzsrGuhEWarfNXBfhzxM9e5rS
21	21	{23}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtuhZML5o7YJ2e75J8nT166PPk1ApqtCKfnhhCHZTAGrgKgoMGd
22	22	{24,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JteRhRKzdf6RM3eBKSaNS7zBaG5FAYtpPPoYrQrmSSQVs6Be6i4
23	23	{25}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuETCkHLz5UjfjxNegJLhDEEB9uVzCyZxcmaS5fC21qpMVmGH2Y
24	24	{26,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvAHY7xnUzC11vcqUsV5YcnhbPzRzBpWSie9qduzyveNjTpwoN1
25	25	{27}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvQFuY2JYFPJeVWDKEpFuNU3cHZcLGEpZ6V28tqnRfQPxJUjcji
26	26	{28,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtWy4igABP6bkm4m8thTBy5CA8Kdxnp7zdYZX6SxsAYMT446WmV
27	27	{29}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JumcdVdGq4e4atfx9A5tq3Fp67DdNB1zDvULFVPkbWqEpAj4Tzw
28	28	{30,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvBFQegXemWPWjNm2TCeeFARqRuK5QKSexyUrQcm2kCT5bqRtUE
29	29	{31}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuZeofLrSAmrvZmyCJgEHMKq2QM2Bn1kydMC5JcuePU4hufFTwp
30	30	{32,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juw7oG6G6fTrmjUkdC95mxnHTwxJUHUutCZ2xdzMb2PqQdBTEPL
31	31	{33}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuEifMWySoUFCntGFenR76W5u4GGNshE7Vw3EuHMkmwimyEFU2x
32	32	{34,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju81cYysS4BHYWGw8p1mX6SBEd6hedzHKqj3tMX1G56eLT82Rmw
33	33	{35}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuF3Qir7ZoPxUMdpYTrE2Pw26AH3vZJfTnrjbzWrmdM6ZEEbDvj
34	34	{36,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju8MusS6FNUTskfHHBa3f1KaxpSR9yuG6Gxffr8Qnf27GcN9aDy
35	35	{37}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juu1rB6H7rWzZSaUHP4y2pXLj6SktEzZCHjzh6gKbJ7jQ6ebGkm
36	36	{38,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju1tPzAAh65mt9CnJQ7ZG4JrfoJtU9xkAEiSDhF1cFhbdxSHfg5
37	37	{39}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuV4HSD1ozfE3rsRTR5wSGDJoyzFDaZrtFBRaa6PeECdEepRDBU
38	38	{40,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juthf7wN9ExtoRWMjuaBdWmJDpuSEo1Ba3rhcHPwRmDVNWs5Syu
39	39	{41}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv7m5SC7RZ4BYxxgEuABhNWFesYtZexhBZVmZrXYZv6N396zCTa
40	40	{42,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuMWU3P6dfJdb7urpeW2rpRiLFpYCa5Mz1GDm7PcLZ7CtJ3Fqq4
41	41	{43}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtmEMZhEThZy1mjNuADUPPEuQTAuQPvTXBSSPKG51snp6uR6Pu4
42	42	{44,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuHC4RfR1xmdJotzAFQ6LFqbGDTkZ2SuorFA7MSbxE4NdBKotRy
43	43	{45}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtzYHEFRA4TLNtJ5jebqYHsc1NV4TUDUjxKqwzCMxV7sZ8tbeX7
44	44	{46,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuZ4LWrw621PjLnRBPqVGcJ5cagf9o75R6xX76L7mXWTyEuABXg
45	45	{47}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvAmMuVdPDsHLLbFFp1kfDoFT7mLJpfb3HfH9tgRBt3L96AfUBP
46	46	{48,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtwZLFTkfKChw38AqXnt8PLm5fagvBQDhvhu2HBxaafw3kmhBhR
47	47	{49}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuCHxUMUBKFr7K6A9Q2cMUKKGDpmkXo2KyNAhyK3Xsbvh7audSa
48	48	{50,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuGoDTEn7Fa1b1nEbrwo7u87p8Ct9qbjdLedecRcQXqDd3oPvk9
49	49	{51}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuTNjmyaqprzXBgG5RZLdRsXzs7QVeyPYKWiQMNN3VYK3ofpFbU
50	50	{52,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuQXcVRY9H1kfTZRxoSdkhAkF1qxga7ppHnhQ3M9LHJYsQBechF
51	51	{53}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juoqhd3Au935tkvUHMduPCFs984LD7E557U1cS4GXEN6wN6KRav
52	52	{54,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JurrbVjdStbK3ygYbCriA64DrNGA3F5G4Nh7R1Ly8TKwxph3ZuD
53	53	{55}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuwxB1wnu5j6Sh3FQWMAx7zVGBQLNtKiEpULGLchDUTHxZH1b5x
54	54	{56,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuvwEJZt2kDY7uXAjhrqunupp6ZsD9RqxJHKo8DZJrcRFUiQU3N
55	55	{57}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvFQVq5YC9QaP9yJ6WXtsn6p3CuReS4MmsMiSmyBdUjwqGMLMCX
56	56	{58,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuKiSPNwdjTEAzcJeHcZwCej1kUDpDas4nEvJUVzeK7fsmZ89Pw
57	57	{59}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juekcr9fxeAHfxBTe2xQW34AXzCKnAuTKNDYtKboDnCXSUnaEpJ
58	58	{60,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuEzoKaw2161wwe4zXk2G2Gs1uq9MRhKaCuazF34w5kWXiYVKhV
59	59	{61}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JucTynAorGTMcHhoyucHkhwbzNWGTQ6tQTPnossP8d9qLrt54bw
60	60	{62,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtwAAkopw3dfyrBMeLkp7mKGAR6yJtZY1TSfoRcfRZ7bsJ3KEAK
61	61	{63}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtxqrkBSLjAaF7y8ytyC1VDCQtGXvMKhZWMhv6RTUXSwcA9xCsk
62	62	{64,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju37huoBW63rhm6arr4zH5Dwtdx4bfXQWdTW3MncoVboktBQ7Lh
63	63	{65}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv3VJwSPW7W4GybZUWt85qqMKnLSW8Fh2J4q4ZmERQbWbu1XoXt
64	64	{66,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juqgth2XrsuHHDQfSMzQRwritMP5LVaa3XLaWHAiEF9mfkPwgQd
65	65	{67}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvBfAa8XSc9vajma7k8DNXHcheb8mSaB4Pu3Mi1bW7oy5ytqYRw
66	66	{68,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuCoBj1qmET9bqBiN9HbiQyk3vN2YSkwnHdFgWm8pSGNyrvoNb7
67	67	{69}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtXeQqaYA4zXG7HwPZen5UV5ACyowsQbrJsGKdJCPmyewpdk531
68	68	{70,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuSLFc5CistELj8oTY4ZNZkueVMziBVP4rne8mXcNi5J9SuF6jH
69	69	{71}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juas9Au11X4QVJdVb5cGLyvywLfUJsprRJZScnKMamZxKftivi7
70	70	{72,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv8WGtzWUms4hLC6Wno7QxQ7da8ZtHb7imWaPhkvJBAdik4MLYh
71	71	{73}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvCecGk67DrmEgoPPKgaTNJ1e5N5cXmz4CL9bNLjUqHsDSt3qkY
72	72	{74,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JufXJRbVqWFiuJJxaNPjLYGAv32rgagMDS5b3mT5qz22VoQ92F8
73	73	{75}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvD7ea4xCgJ9YSEeVsYvAsZSn65r7DANcuYjJ2CXKUvdPuUo1ko
74	74	{76,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuLnfpqQhanc6E3oZj4PWNhkA92mNrvMiywhmKuYkPnr2bat2iG
75	75	{77}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtgdbH8oFQJK4JN5gRTxeoL7yoxpMFVrVeTn6vsaTJ1XfJCL57d
76	76	{78,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtnNC9sALH1GMEwEDSbc6u4Qp4P49eVERtvGLoA54f7erVa4ebx
77	77	{79}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvEaGiM6E4xVmvYkyPtbs1xEAhyJQdLUqnmrzBqHRSh9faHzHeM
78	78	{80,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvDY73HuaKHhLgiWek1SHCTEFQaNnKyEFYZzHWoW1GjEt1ZUcfQ
79	79	{81}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvCE6fStER3spfyn5xARanNwj5cLBoN95X9NvfEtarKTS2wtheY
80	80	{82,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvLYN8JNw79ShnKnj7SNPLR9RA3txdPeS3mAMcG2uviZXwSGUaA
81	81	{83}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juj2s7hoTqp9JxrZeyRpU74soTMmichhZmL1vbrqneFF7izXNuR
82	82	{84,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtofFFRn2DDUpZJ8ddUtzD2TXzMhZ3Xsfh4n3zGW7xXdHyqkfd1
83	83	{85}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuTFdEsBZVRHj2jJFg49p8mRTsoxyvUv22tVo52KdQ63Unj6kzH
84	84	{86,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuMo92TvAazbQbUWmUCvZTk7YbUqobSMKt89Rzb8AUZqA97SS6H
85	85	{87}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtaQBu6gEkdxeTnbiGPTc74CC423sCqXMFfeXtXhFg5QycivKzG
86	86	{88,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtksVgWTesSWm7BCTywSRcNf6LtWXaGrahj3oZsykQUcveyTjTH
87	87	{89}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv5o4SN4oViD6mqP9X6fHaDs7aVMXP2mnDL7tMzvJ2TF9fLRJPK
88	88	{90,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuT3ehXUQUboXMdY29nctyJEEkMaERa3Luq8YD6YAgs5sKyZ9cQ
89	89	{91}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuM8GKFjTs4kQ2FLJThcFYg6v2R8XHyCYmcoZVPceRuv1zcZBtu
90	90	{92,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju7t5eCi9HJR12wnixjpMLd2ufbd4wC6kUPsF61NB6G7YLH5T7d
91	91	{93}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuxXJoAqF6Tt65pU97wbqZ35By691SzWk1JMkMBW5og1majvVJC
92	92	{94,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju6Wzes4tPxBZVehswHwLnN77V1hjZhpH4SBrDaWeHESnGUzpde
93	93	{95}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JukSqCQ3CYz3WzAeD68Dsq4wodA7oVrtMRdnqzs3fbEKYzMVw4x
94	94	{96,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuHWMMq8xMRPnJNKpWFsvnix5g33NXeGsK7rKbmUQ6BVqtEyuuM
95	95	{97}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtw9vvtn8BUzEz8JLrqAGJeGJdBAEax3RaGwQEaXYzv4xrfCqCX
96	96	{98,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuZ7siquD5ki4GVNggjD6LZht4pCup1Ui5eTdhpzEzLZiWY9zsK
97	97	{99}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jttv7oebKNxBSwSw5VR7ycHVZJdRNoRTdduUGWNXeXfr8G2X1AB
98	98	{100,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuVXuvH6bvd7V5BBZPpKBeRAED8Ui9ru2jd8QE6ZynGuPTGazBR
99	99	{101}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jttn6ZdxLB52s8j2fkfBDYfXHRLZWeyHKTVWSzkkt4aiPdEz3JP
100	100	{102,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju1sB6dP65Zvhbrre6Mpqee21EBubLJqb2JADhWikf5ZcqW6GQ4
101	101	{103}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvDK2Ci6AAHEg7x1UbQAYyV6pF24cFaieZSTMhXi26MKUUSGA19
102	102	{104,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jts3vSh2rym55dNkF5A47eVtcnL5RwwZf9oSiLxX1Mb3Fk2akwt
103	103	{105}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juwon5W93TABuzdwbEoKzVjtCtdMgijCdMgiFYndmF8VuF2gfTn
104	104	{106,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuuWJhEhpngRAdRDLQxpdngcq7bTAzHgLJuszLXxJMzxJtmoFQW
105	105	{107}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuyQ3QQpX58TAjx9BihYnEhAbRfcJmeXzUVQTedUnVkxMSH2J1W
106	106	{108,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuJHmGViFQqAyR1SZ25sgE6K31MM897dFcCpDwayYxfUVaRpLS3
107	107	{109}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv5h54DtSJEnFGZg7YZDqaEwgCNxkRWPCALeJFLaUAjA62bdujw
108	108	{110,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvBc2zsx2itXhHvF4TwBMfqwsBW93Lmpsd1W33HRTt3PYH1GmwV
109	109	{111}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jthm4eUsTzDeG9Nn69jvHfXESvoP2gsgTBsRC9miZYMb9EXYrQc
110	110	{112,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv6xrUDdEqkEcox6qfo4EmWgwoJD2Y2iCxG5KKhaHaCDo6ohj7q
111	111	{113}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvKNkAAebyX21r8Pk1MZttMX6zW21LUy3U1ZxoTQkkteXUXwcBr
112	112	{114,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtzhdw431toUvcjfQkX8hRivYjc7BiZAVkfHwjGaFdzYALZJuE9
113	113	{115}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuSC9Y6XD1Rw5ReFNFnezGEMqMBRQNmU1KUqHDzA7UGFv6nKj9Y
114	114	{116,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju35buJJLK4H73PhA1UhVGzfp31kJT6mVTNLKAwXkazCQRLbzc2
115	115	{117}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JudgDAbNvrYf2ujTdN6FGW5Q8PzCNAb13zMJgEQCVrSRy3XZabm
116	116	{118,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvHoTmh7N9XTFEuJehJgDNf1amufDq9ySQAwijnzVxCoUJMwjUD
117	117	{119}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JughVW2t5no8zSQuSLxD4B9f3Uu2DbChDi7UhRQf6BDJ1hkAfbc
118	118	{120,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuHGKX8fk57XPnrXii4x1KV3iAEBxeis6Axit9k7UvWmxJVp464
119	119	{121}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtrmcfCF1hYiTcv83LqWUi2NoSizNpKUYhDKne4ZLE6EtG378KF
120	120	{122,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuRGXW968ahWYFKC4E3iN9LyQAeKTB6Mm8WRhEZ4RbDHSf8uM2b
121	121	{123}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtuVFiaHDXJbfz8CZ4cAxK9ifbyNNcPqoReFkDvyMDiwYZ2wBCB
122	122	{124,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JubZMDkJhhw3ucj5QkDqiWnKsxKBGTRwEX5CgvZE7pEHFs9H1Sd
123	123	{125}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtqSfAM77RaYXA1UWbabCsMMUfw2jLC6CaiZ2kiwkgXYJwY9pHg
124	124	{126,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtW7Jjfp4k1Pfgssmrd9XpQngEJtWsi6gek9hbJPogPmWndcSvB
125	125	{127}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju6UZz5cnKXgGehcZJ9tZJKhZRf7V5apaFbVyBTGoM4JK6rFMPP
126	126	{128,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuPgk5UGfTaGfYn8x3uw5iCLnbLANQASr4m2Eu3N5TxCNWAwcme
127	127	{129}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtvwtK94uY3EWsejQPs9JZvTtfEYA9tUPYPmaHm5b9jqyXb56wW
128	128	{130,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv959jcBy6cHtivdC2kLzNrUdPWexMQSndrLQSpVu7dMuPFtZs5
129	129	{131}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JutT1x7VDKPoewXGeJUpbHmWVB27t6EGvHUTHjsPzkixVj7Xgni
130	130	{132,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtfmtjPKGjZHgyeW7iKPzDcHVyLvoPKBZUmau391gRyY4uqCNX1
131	131	{133}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvS7qeHLfZYFfxeR4qBHTf9fY47CWtXLrdoL5m4a9pV612c5ppC
132	132	{134,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuUSd4535auDH65483tk6jnQVUBp8t3TxtGxZE4UpzJcYZ3A5zV
133	133	{135}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtssdcdH4rf9mtEez7nCRR32ERLsgig6SoxYYaiS44NB6JUY3ZZ
134	134	{136,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvChAPNmceCCYx9UqKzqi9qbb33VhT2D56LuJYyV8h6vpsixS5K
135	135	{137}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuCq6wbhYfoimPemvNMmAraEhsQeKzGYdWb5CU1nKSDRRS3mdhX
136	136	{138,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv8f9pArJt8H3E8kyBDSKhRQmDsi8rJasPb5DvfUgsK3ThzAbQo
137	137	{139}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JudNNwd1ukcm5di9PLT1XhMHbdEpLpqk1tzsAnyiz9c7MPFZ3xG
138	138	{140,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvJgEfDm3VfjaBZmy3w1BbVXWoaAzjgBbwgEbavMYuV43R8PW6K
139	139	{141}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuoRKQ4BGBDuJiTMLKeG9ogsYJmjBBwdnAs2J8mXVozC7f6mqmp
140	140	{142,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JucuWXJrVksqxrn1zPtMxN1Mv3rPUWuGsprkJcwXBMot1EGBzLe
141	141	{143}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juf7jpuhNyLkzwyNaB1tUCn2rYz5adb9Hoth543qsW9ZHYMGD4X
142	142	{144,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju9qMq1fPXSdthR6zqdSaCddj81Y6B4vwq1DuWJuN6gaNfhMoYU
143	143	{145}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvPYU2S73vuwGQ8FM56LC1v4DfAiPyPetrtJkKW78Pt6TsjcnjU
144	144	{146,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvB4CLMi96vEWoyFEQxTRCujYycnfcfBY8Mvz2jMyhpiBnMwyDY
145	145	{147}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuXykbCGmcvb4rp8z371RZsWfyTUVNtPFDETmWf8TNMJFGtUrcE
146	146	{148,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju8RsdxhttTCgPeJnUgnJotbmrZs4iPADoFWRHFoRZmoGr8HQL6
147	147	{149}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juqro45k28gVwQP3yQz3tE3RziLA57yJHj5XkfGg38ZUkCgmug7
148	148	{150,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju3Ug6whwLPUEjcMskYL8emP5oTtJYumqJCLsWQB1PRnG7FGA9T
149	149	{151}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuC2AE59oL7pGiADJEusJvYRehpy22QmLJrvUKJkUN2EBbaUTwY
150	150	{152,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JthjGhg1mQnt3BMo1ymUtr5wcq5kt5cSruHYePxdVSEU3z66i6e
151	151	{153}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuVWtZhpNKVdzQyWspxFz7iNYAL1iHHPir3va2BZ9oXjG8vEjoF
152	152	{154,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuVH7sFp27kAnJRJdoordRXvNEVRCHz67RbKEShusJap61cAwPW
153	153	{155}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvNy6jgnXbp4P4trR7wyk26BEdyk4WAEkvXssJ4F8B2kNeJTS9s
154	154	{156,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuZqJ1gdAMYNV3gacWriXwBG43qPmxppTVhqfaNmgPKB4FCtfkD
155	155	{157}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtr3nWTo3bJNKLG21g8XWRhqZGQUjrXteRBtZtYQG98sjTb3toY
156	156	{158,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv3NuyvDazBjm4N9qAC7joxiG1CMt7yGUcHkrrRfTJzy77SQ2ju
157	157	{159}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtvTPgez89HHFQGYrsksFbMouDLHk4UQuKtuDrLyrnZQXcvMgzC
158	158	{160,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuUnSwK1xTN3WfNWZeRhUwkssu29adwFkEkhWFqaZXNfgwG7sww
159	159	{161}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju9ko3qxrTZkyeLq4buLrX6gZPK42euiwdH2eBsQXN7SHev6QUp
160	160	{162,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuhkHPDAw7iaQZSJXJMNac27BsxgS9LnV4rS93aau6qnvpHcHn8
161	161	{163}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuoA4aXn7L36AoGTAGzUFCizdseyj5CNc3KfMmXeL1yxcU3Q9Ft
162	162	{164,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtvkF8L6cRp6Xbgg8Xxyw2ED2fRRdHXS75GgVeJwyANxciBgRFe
163	163	{165}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvMpbFNFAPkY3FVtEEx9TLZi1dXfMgMfarJZzRG3ZTbAFiwJPbW
164	164	{166,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuYfKaNmK4PFneD62ZfNjproFmJh3GBdGp6i2cZAu8rRtwF6d8t
165	165	{167}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtpb4753QficaaKWUT15v2keoWk4nREZ9a5DsSsX22Dvbw8B2uR
166	166	{168,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juc8Bz11VZqoyF9ER3ae7pUfto7cEQwntWbQNt8fTfHP6qQTCWN
167	167	{169}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuhNR2XbQ6zEFD4jRDAVRtrHTd7ywKJNqcKPcLJkXxGYpyCjsZH
168	168	{170,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuD8GzAR1afHNkMPeZSBp5naffJgu4Pmz36CXsBPHiz9LqfRJvB
169	169	{171}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuYkVvPZT6hK4NM9QjEQawP7tPRos6fpkq7b8bVuwYyg19tdMW6
170	170	{172,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jty6UvZ2hgXds93jg6n4jUyq7s8yEx784mMhsSeUSC8N1UTT6XM
171	171	{173}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtx1YKQDWeoezALwwf1vGDdi95FwA76LvWzjxFEej9MNnNydhF5
172	172	{174,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtcaybFci9wZNNua8W77GJW3z14VhfhYkJuSSeDiKrUrBCkeHvm
173	173	{175}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvPoPrsRaKPnJWMZHVrEXYAGjQezegsHsw8xdZ1qroUmtGsA2Ch
174	174	{176,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtaKhxP2JYcXXSVahs9CRE6xKVGEU3mDptRVz81UzzGrdGTr4Yy
175	175	{177}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv6NrMJo77arxkuUr7PDsVUBL9tDULZwNR9wrsBvdp2aigWbT5N
176	176	{178,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtvDbz8Ee7QiE761rUXv7jPokVWrp7tiS7Mf3GeVK6yt1QkDoX2
177	177	{179}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvHmVBfgjjW1x4dG1SMaCvYAt4FY4mmR7F25CGDQhfN2msWV55t
178	178	{180,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtoXLC2yqffVZTeksvNnjzd1iqNWoFNHfAn1DuphLRvZR5Dbv5m
179	179	{181}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju9PsCaeVZAZTHXpNwf9o6gVNwCJwQ87jBG64X258MLgnQAY7T4
180	180	{182,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuybyhnMAJNLayzTc8bSyMXSTMF2XyWccGHbdTKZH3yBbpJSehx
181	181	{183}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvEvRhvySPY6RRK4jZXivRFnPrVCPa5GRNkBC7bYXFJdWiVMdqz
182	182	{184,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuHyx6mxWDD8A8tBP4GEw3aCKcXA1eswYRx9mjdTH7VBSLPgMk1
183	183	{185}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuGVvfvL2ucH46dyoMa1u378aofFFi5M39nbo4GXzAuizE35WW6
184	184	{186,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jton2A6KLEP8MGQ61PRC9CceyueidPioe9LuRiuJyYZ2basocfb
185	185	{187}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JttGPdVCKEmJ19zbXZK2vh74WgowFmt3N73cbKoe4iMJxNk7Pwv
186	186	{188,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv8hJmuJB75BLxLk3sn2eyAkBwFLQmQx4QBzUTyiHh88bbtkFv9
187	187	{189}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuXRwAPjFKEwC1smRvUo32CbFH4ar9BxCaE8Wzxr6eEgNBY1CNh
188	188	{190,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvNJH2UfwLVDVGfaCVxT5kMvPJt1oV7A3SywhNY9exrnPLj7wc7
189	189	{191}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuhiBNshgRiiC6iqCxcVu9XK4uYwboegBhUBWY7Tc9TsAMKq5PD
190	190	{192,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju31krvrRFaSXCytAAbaeYirdiMAZFzsbRKxu3UXMV5434mrpAn
191	191	{193}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JucYtkcAqCJpTQ1mr3RQYYgZzrPrScp9MYfhbwy44fLvx6StPXt
192	192	{194,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtby6SdocApHZEtugRGGKTG4KXZn73mRPiTr2yXH5GWGU1EUSfp
193	193	{195}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuDLBHNgRXvG1LiZ4zLi8EHRJZCCdKAQrNEaNynSu8DkRnH2b6Q
194	194	{196,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtZeo3MEyt5usqVcqDTGLrXKEayeMP2uCnxhc2D1vwpNU4qJwxv
195	195	{197}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtgFFx1EHMcM2jvsnqDSE2TKFFkZktDTKQtZL1z6W9njmY8TKxD
196	196	{198,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuUktLtabCAFR3fLnC6vmrrrmPiiQJ744wPQQrtMuPre5mzdAma
197	197	{199}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtXdgBNXDfmnKdgV3ZWc7JE2HaSjL7Qc8xHKY4vJakLhkBNiMk3
198	198	{200,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtkagS6p1MMFQ92KGq6Tbv7H7bSLiS2cr2sMbxXWqVYrPdYsWdE
199	199	{201}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JttxVfwiBcNn7sqSeDJ4jpjPjypPnysUzeornR6k1snE8TmTsiz
200	200	{202,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtqsKnECy7ocEeSCFugAnWQiZyjm9ZNcqHKNpGCuueThPYUX8WF
201	201	{203}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JupLn7NnAXTZpoGhtvK4H4JN9uStvDyrvGM4LHikpMnd2LxTYLh
202	202	{204,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuTcDvVs9PWgtRyEfgdAEZPretQreWU8vxnYsG1eGLMid5Epq4Y
203	203	{205}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtxEHQHZoKQxDNLq6c1Hcqf4on8udj6U3EuEyfkmrYua5YBTYjk
204	204	{206,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuK4BnRXgRYfKo2wgvVXFmWvhy1KwKvYn4pyWTpypgVy5DRY7dH
205	205	{207}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuW9ERdEmopLvgDbyoZK3F2i6qAEzyzCaZYkLGgv973QF22HUht
206	206	{208,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtrBd12XyKYMAuYhT4acWYyUzdPgqpnnxbf6SFheoWfM1p6cZ8U
207	207	{209}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JueDd9q2C6NzLuVNjdPumJgk3f6HMxodjC7ZHdjBnTkgot9fXJW
208	208	{210,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jturqiv9MPLtSYC4DZWerahKuS9pJaajjU6soZr6VbDJNk1wf2E
209	209	{211}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtgLD3KgWgEkyuVvWraJxSjUL95SQyQdfAf9UHgf5nvbSL6Cw4A
210	210	{212,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv19LMhFNtGbWpyW2L8UwJ5z9Npux9dfdtjXKSCo8DAZbieaX2B
211	211	{213}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtmGkeT6PqBbekJQ4Kx7woRFMurPcsaE47wC43uvp3QpmS4j3rC
212	212	{214,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuteCGP8jKPkGCjjR96dk8LftbMQp5W32trZ9ELxzPaXph34muZ
213	213	{215}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvCPbD6piVShWU63t14MEQ6rdBPTUT2Aetk5vkMHRyB23x56rjL
214	214	{216,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvBiEg9v1TcRFuMwq7GtR9YUEZ732cTD6jCRHQ8ooJFrfMZGDno
215	215	{217}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtz2SxAjZJnQEbjjw9HKJMtdd8cSaXXPWvajrKpNqxPsnDBUYYL
216	216	{218,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JthnZwhygLkUKdy29X6rqAiqXyXg1e9qXHQE25Uizd4KCNPhTVq
217	217	{219}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtfD2jy5LERN41JMXnwMqPHXbwccXMs1DJoVTpcjyB9E6Wjxj3F
218	218	{220,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuMM1rV4Z2FP5kcc9h95twBfmFuQPHUMunLq7215QhxG2umN54A
219	219	{221}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtsTwr2ra5RvnwQaGC96ZYecGJEwwvPNYjUSQ8YmwE8bD9KvZAE
220	220	{222,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtZT53Ftvw4Lqiv2K3XVkZ2zv3wiBBnfDF6iy8PGoMQZJXLheg4
221	221	{223}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuiZMoxbnBbdk5rmRTrJbzWxeUe1RsCesrENr2mvA7sruW6aE5g
222	222	{224,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuPvC3ZLgdUmM3MFs9WeSEZM4E2zq6tum6ZhDdQenvdJwtfyqxG
223	223	{225}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju7Ly8zxDkxFDFzZqicL2u7KXdM4zDbfz1CsxHxbGqJvTzktiCr
224	224	{226,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JukEFQFRturPq1SdgdWgYizMvyBut1m9XkcPZjB9fsaBWUW8hPf
225	225	{227}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju8ccDshsZfuPmabpJkcxcmXK6M5bBXq1MFz7Pyi18RJZymeDfa
226	226	{228,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvMLWB35GjfSChtLKud2wfeJJ2Xsng6xXefdGN29TBwLvpbBUyo
227	227	{229}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvE5AS4Qq2JHQ6w36URYiQUNPdbzvcs3PJ3DdpL1PyamUe5fPJP
228	228	{230,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvNm3jinr6hYBCbTaZJW8zVxS7cX9FQft61q1Mdj9Cuiwb7edB7
229	229	{231}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv2agHjoWycMfgiTgC8GTdrwHXFVqVAGqrGgYjBgVCfjFcehwVC
230	230	{232,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtshonZWi6hcSegXe6pxgf1ibwRZWRXCrKKs4UFqqzdztkVAUHY
231	231	{233}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju8k2xmCpKR3jHeJtN1kPttAdTtLoouyW4Ew25hYfu2fgPkKWaU
232	232	{234,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuUFN3deMtAA2t3oQnBs5WnQ9DueCGTFAQBEnVE8kDHthok3xXv
233	233	{235}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvJ9TYLzU2ecZop13SPzHshKsqjCdqR4TuFTVEUhHjwXp97LYc4
234	234	{236,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JttcKhfVxT3nboqNgW4sZeEqDbbT1XDxz7Tjtm1zwbxTnz4tkxf
235	235	{237}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtWPnYkwXmMfg6KNEDcu8CRsfyq8nbNf52tmKUT17ehVPeVqgLo
236	236	{238,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv8en2PanAyvsL8dtHzjAmrd5eqdfnLVAHVMkSQoEKpVWtd9gUE
237	237	{239}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvDgMmGoKpXuWEkGJokDhoG5Bp7YH1XowzWEFZiwNtfkNPoR7er
238	238	{240,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jugb7Q8ehDrv12umcTxYsrEtGNpxz3QaAKjthtM3C4zEwjGLYza
239	239	{241}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuiUXPdL75qXGysMT1hGqcTCPBzPwArFi1G33d62nDY2KHMdq7f
240	240	{242,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtgm4BH3VQ1YRgoXttePVYWo1aZct6jEiCTRbyt65sy2JJVePvx
241	241	{243}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtZ4WmhWSu5x1E4ETpckeFsQKRw4kS13tqVwVfykX8aC1m55fjD
242	242	{244,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv529hYPCmcw3hbRD1zJxEbzs4YiR6AtMhGZY5CWe7zxYXK65Dy
243	243	{245}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuGiAPXG9f86xqQRb2yYmec4dPNdbWCDtSdFKA4NFXGEYaWjcQx
244	244	{246,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju7kGXFLq6SmLYVgCctb7xBtv4YrYY6Z9A2Dx5f6z6bL69gYCWv
245	245	{247}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuZsv7L6RRvZbVHByGyDQXhYAnavP5sHXkdzeVSETa9D6d1wSP5
246	246	{248,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtyn5K29jH4FCpBfuSUK3gLuYKXBJHAeaQAhkyxgmwx5cAAwcHr
247	247	{249}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuUjXpSd2Kq9ekLGFs3GFAHKkSYENuvijHLhCPyhgLKEx5jEWjg
248	248	{250,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuNkHBWhJLP4Fd5ehE51EqHeSEnMoBHXDkdR1McvaMgeVPJKBs8
249	249	{251}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv32ix9XSLr2t44fKJxn7Fca5hNQEwLzAbs6HvX4hUDxeQNkP76
250	250	{252,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtqJNXnVFdQMsMtdC9sSYk1T6XnmhAGZLtXEnncx45npf1fy2Cm
251	251	{253}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv6b6Soie1iZVoxxJd75PCEbpobt84wWn5ZKxt4yB4vDUQKqj7c
252	252	{254,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jth3fAcfn3AmYVPGRQhqy3hJ6pp8yXYP1CdijpxhWEFxgFG34fo
253	253	{255}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JumTVB7X8qTRvyMKx3xHMmd4SvqnxqWYwjJbeW3XLk5tp5iaFrB
254	254	{256,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuwHL939W6o4eYezH5jsn4tMMRV3jjUARoBznLvDHyqrPEsjNbH
255	255	{257}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtX3AGX81VHF76BbQFym3e2c9HBdVZjiQkz3kQ2LhLUbYDrkCLh
256	256	{258,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JticUdvfZXhx9vqt1NskjdfKXcz3EmCi4ydfJEBy3tZtcfLNXRz
257	257	{259}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju3LCcaWtwX6ujnFkB9BCdPC6oVuw6Q3yzHkkt9XjdiXhCh9rts
258	258	{260,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuH6ezq5bbDfTFo9PUFmcU2BJNgJAGYpYvDdQqXUjjnYZ4fTsPT
259	259	{261}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuJiuvZ1pssySnAi1fDpfR3qK7LTLQFq5pA2XnkifQ1bYjmRQpZ
260	260	{262,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtoC7YSFscYZUFSjZkxr3UH4F5Cy6imXwboyRRTD847tPznT5tF
261	261	{263}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuUtT3HX2VzWf3aATu15r2vXxV356X25XYpXSmuSHrH4KhiNNjN
262	262	{264,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuUax3upNCziZEGGsjr92A2sQy9UX3KF9xGp4S2rpWVH8SUAkLn
263	263	{265}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuyWRoGsLgmsV6EMcyZS3oY1w4HTMZX3YQcveTrvW9CZAudNi2E
264	264	{266,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtxMpyyVBaYqbdLYBTw5zRSErQ9WSACzbbnQ5LUe7hWGNY5TkRJ
265	265	{267}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv566c2mAEYXCx3hJBCT5xXnKCA4jpTRLUBtsE7mcThedDUHEXe
266	266	{268,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvMqGmcDCAgtuQ9NL2Hb9QHdapJoVs7Vs3t8GR4pZtHU1YsFUep
267	267	{269}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtct3xzh984gpVgvdfHArZoRckDkWktAo8MsDq55mgasPfke5oj
268	268	{270,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuvrqbGYwNkGrM1tHn21o3LpTKbSf2FcRpkwCbTgyDqqWHFQHoB
269	269	{271}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juxo69uXj1waJh1cXVu5tuQ5HjyN9etWPnuCBLTVU698CdZuZzK
270	270	{272,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtivikhgbswfrJF8pMTHHsPQ7PdXDvep1mKBMnuvAZg9dYEVE1m
271	271	{273}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JusB1qPdPxRcRrsakckz73QQXxh3FHwMeq6MCkL5u9DBoUnbMKZ
272	272	{274,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juhq8aa7zR4qBCz9qrZx3uXVZdUWJD46xaZUwTN9ZDi8QQmRi4j
273	273	{275}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuectwemgmvDFvnFSgtjjF7zzrHjGJH32w4afVcVogHGVij68F1
274	274	{276,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvHrNyGHUEobbHPzxJSCiZ412wE2AXjARKJDmq94p2ieM6aGwuh
275	275	{277}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtZULoA8pLQbSEFLd4UTTyExC32HjmdNB8qZ3A5w6jSM9NzrPXh
276	276	{278,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jufq4s1E6XKDtbLCbsnge6JHXhaNS2Rp9L69PZYgbB1WjZ14voD
277	277	{279}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuK9ha2jyw58a3Lcdaan1tmGZYQZAxEVLz4ZVnbDy1Nc3Xpn9SM
278	278	{280,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuzJtqGWb23sGMB1FtBQxYq63be8Snzm8sR81wSPDfwsDmAvrPv
279	279	{281}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtVV7ED38hB2hhjc4obJpYU8D7NBUo2fqR4ErRRh8k8og8YUWyz
280	280	{282,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtZN49qgjchzAG2q8xPZorGDnrKMpMZ4LWDZXNHQRBZq5DxhxUC
281	281	{283}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv98YZVrEZYPuhb8jTs82whghjGRrevsVvvdmkfow8cXuDkCcWx
282	282	{284,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuTPSBZFQ6GDzBpHF31fpnXhUnSaMRdpCMSnBSA8kcu2CRvvn7x
283	283	{285}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtzKFW6EkbTvCedxmtAqcbaz7BXFUf2QpHWFGFanHeahXYJxr4V
284	284	{286,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtsefMpoQwh3PR5oLA4S2CKr92gpUpi9iq4o4Vo6dqhvK2zgMXx
285	285	{287}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuRLh8arZcva6CoUHpyh5CKCufxAdoJNcCjSyteKA1yoFmriuyo
286	286	{288,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv28CxuBsyuDL7JXx98yvu8VPFXRcZpxvY3SK3UxphepdaQVwxW
287	287	{289}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuxdmhPdyFTXoTBC5FMszabUg5UZUQL6j2fM7p1CBzUB5wemGDv
288	288	{290,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JubbC9YjP8JGSrr3etbJ7WSaKGAtPHX9JnWFewejdrdXrfShSPB
289	289	{291}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtfM3MGP2ktSM9kuawdTgfXKBMLMNhed1S1rCfibZeNtGb8ehyY
290	290	{292,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuTAuA5M6aVqtfXtMrsFktka8Zy5SFtMnQ8xPm3tAHy6WcAPWd1
291	291	{293}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuDodYe3ux5kcH7WhH27VZRJ1YkbNq3aMjRvv1cZx1z8UWQ7vuy
292	292	{294,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtk76aNdZYNKqzrEfx35ewoYjWEFV2A2PfxzPqg3M8LfWuVmJBs
293	293	{295}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtxMbaGAjUhHhk9Aya2bAr998j7EfQz5vmjpDVW5ZkTMWZp4ZyD
294	294	{296,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv2te5XQtKRQqNBFgghg8wcXLWY7dmwmzWtMJ1PzpmH2JFc6T8W
295	295	{297}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv5npnw4AGcmCZ3GC9tTHnwfDuGFzvMvWpJwrHbXDJLaihQuHao
296	296	{298,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuU3s1i7jcN2hoJU1D4hQ5gexpPadJyHXWTM2RXiLhaBXNa3mek
297	297	{299}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtr66KDuzQpia15fNcZnxADkyPxBdqBM7z1ptDpwd89MDZ9pH4j
298	298	{300,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuFjVPDuUQ74u3ngCVvuQd1jTFfkZFedjckktxu1buXAu8gFDxh
299	299	{301}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvMvfKPN3RrNVAmYpERnKbkMx4v53qtTuj8jjFHSsu3rwVjWTYK
300	300	{302,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JusmQreSygm4pb4Lhi94Ex4QFEVDvNoTcQhVwKuzvJ6aKfLiYK7
301	301	{303}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuGef6ccnpBrcJcyQHz3m1yhcZxdMfmXy7aesSmP4K1RBHRFtN1
302	302	{304,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv44o5j6kooW5Mh3EbMYZmCGDS81trV46SP8d4asX5g8jEfWxmD
303	303	{305}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvFXLXdSfRpMG5Jb9g7LynHPr5EQ8NEoZMZk5jX1qt629C69Pdv
304	304	{306,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv1mcoNJLCyRd6Fddcsyc3Mx3kNaE4iHuoz8tywCSi9o1FR38Dy
305	305	{307}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jur27D9gmtsatoFFpL9oDcA2XCPqxeLpV82DiJn9DzieMZCM3zD
306	306	{308,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jugec9tYj9oMgw3LgkcKDzWbdtEZSsF48xszWWUxL9fAzdg4C5X
307	307	{309}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvCrHsMPRQco6mXD6MNgRrE6igmM2yx7GNA8JLCaKp1BgCeAwGZ
308	308	{310,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JutDcfVNVgVwtypfMZHi9uZR25dabQ3wDSCZPBXoHVsskn7aDUm
309	309	{311}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtWidWC8kGKNcLUjptWPw9Bg4nYC5xxfXyeuLB9R3Mq3vVB39eU
310	310	{312,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv4vPJ2rYAkccgagiJ3rJU8ano3G9jXjJ4digxBRfTNLk55S8m1
311	311	{313}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuVNPYCHu5jGPXpBevSLMAtdpy2fGc5UwKcuVAPRi1TV39pogD7
312	312	{314,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuBGWMKnRp4sGU7Vbis5CQC2nn9XQCb3MEFZuYRe4AyZvRRMerQ
313	313	{315}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuGerY56bHS5KvySQoyrrCpgwpBE35EwGo28mFW4mYZxvQGP5hW
314	314	{316,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtsAjAMEsTTTk8rajR6wgYcmTihHZenrRYZw8gBYYznKrbBGU6o
315	315	{317}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuXtFUwbmyPUUhmpyXhmU9HXHA771xv1G112zsLa6FsUf14mgAz
316	316	{318,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JudAbxbBv2BdgnmCjbVFyAbF646QiqWSoBw9VhD5XE43321zGns
317	317	{319}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtpV8JwA7aGQ5sXCfo4ka5R4bzCc6sBbhko1AgDvdfAm5pa2JPY
318	318	{320,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtcjF9iWApp3pZK1aKiSeSrNta18o6NtWHJuxLxJEvY3swGzXkv
319	319	{321}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtahiKNgD3MKMDfhhed56fzGjtTDgvaVXhoysMC73o6LGEjcsJd
320	320	{322,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JucFP5f6G31CCVynK2MNVZLepdKE1xpDKeTLdEqD4yjpTe4dVgu
321	321	{323}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtmiZ15DZDw7FV9xQoNYPY2ugVnJkgQQrRHv7BZheRyNNifcgLT
322	322	{324,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvQbjVqdi3cryDwkmskKnHjdsjgpPHRUGfWVd1xoyv9xLbg98UU
323	323	{325}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuJDgkXUicuuQ2uqM3c4ScfmaVd12gmEu1t7t3bEHxtFd47FVo2
324	324	{326,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuFeKZ3n7Wab6NkJEWsqDty9qkxK1RqXhVijty3SP5JgLWekdJD
325	325	{327}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtsWtV5YkycfPQjy2mPcJtfTeL5xtu8C2nKSnYgbjNaSieGQ6Rk
326	326	{328,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuYnQLpRpMrn1x198xXzF7obqfZvodLVJnqafbsvJcunY6eZdmA
327	327	{329}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuX3Rin6t38is2LDKyFNRtxtEfNAuSM7hizTqF3pU9tjzVvB6gL
328	328	{330,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtcpDeinh4GG5FRazPQBoUEn8k7PDWSc72uKHhqkz3xgczoyrxc
329	329	{331}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JupfKLepnbiNjoU4s5f9dtX1ruSP5QQpeXkJVbmz61ich7tjQu2
330	330	{332,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvFtZbffDt6YzbH5BSvj8iAkx2KcLZnG4BpWTibWnzWuZK1iVV8
331	331	{333}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtwd2hzfvx368XbJPj4juk2wHiYJdzWZMmvAf12ftmJu99cUQcP
332	332	{334,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jug1BzvSXxfG9ZeCKwASTQpDKxC9VSF4PhwgNaKEJTPYLhcEELR
333	333	{335}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jutn2SgXCG1ybBn6baVWP7tUTyV77tm8sa9Ea65mwGmWvimts4m
334	334	{336,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuSnsXFPU7ixYVohkGuBVAfzFiKWhWBt2xb4Aru4FgDrSUGBJ4x
335	335	{337}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuBSRKBbV1VuUcNe1YpBZzqixVDgn6ndsXqNgJmQVCJPUh4onAa
336	336	{338,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuCvH4egwGVcarp77JriFeuSR8qpT8ikuyCobuzQxbkwYSgRfXT
337	337	{339}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Juk3U7UDEz1YWTjEtUYzHm9GMDnsJCfSBjLR3a4qfH6FMHz1ZpQ
338	338	{340,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuooKjd9pDXiZGq5HZoYafjNtk3u8S2DY5e6ro9BF1JNdDhtapp
339	339	{341}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtZF2BtmCWEgUt6Li31WMTTbbYKKu1r2beHcbF6UeAMTxYpg2WK
340	340	{342,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtega5S4ZMWsPLmYVHDNBmHFQbZHi5Yz5X8vBd7HrgYrNsgdTdZ
341	341	{343}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtdfXbswNsMyPoeWhPgVeAFv1FDeDfNiZ1o4TV9MPn2rBi6Bgxw
342	342	{344,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtqC7hFpbe3FdeF1kSXq7TWdcZuZ6U9ueghkfD7HvF6BjKBisbh
343	343	{345}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv2VC1Vthxm1UaufmXtZmtMDKYr9CnPfUwNaNuuA4TuuMCbYFa8
344	344	{346,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuxKkC5DztPVmVnVyFTuiwDYbP69GfsZyFC6B2rARpSZzmsZ2zq
345	345	{347}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtb6tzvmenvNcZqH6PzeqfypdzB5Y8JdfoDb7Z2fiUgDEZzbtun
346	346	{348,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuWKLCLuC2xZvAHwuAGULxwbQFKXyaC4c2NFBQ1X7QNo85Pj3Pq
347	347	{349}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuY3nxvpxatBb2RUAyAqESFttQPH9Cr4DJvSnHXeMVZF4Y8tZti
348	348	{350,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtthQAj7d5TLEK23TWAVSWcvwwhqkEnWZNi4LSRAZAnHGK2gyFh
349	349	{351}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv4rRJ9wmgDbkrZCruBrZEHataG18uGayf3fhrCoWPifnR7vLwW
350	350	{352,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvAJKH4AwAfD6UQNKYhdV2gSRYWadZLGwVEopWKSWbc9cU2U6G3
351	351	{353}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtWDarmrvnFMzfGrAWZHMH5hDeUwJXpnwMFLJmt4QnGdye1UGdd
352	352	{354,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtaMzxNQ7uCiTfmhsBjfVBrQSLjf65K3u5kpoDqb9iNXj1eZPQQ
353	353	{355}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuKQvj8ZjawZgL4dauqxWBmABQKAPMrRaitRKykyfAfL32SyWkC
354	354	{356,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtXgQmKRjxpoHmXGRZLQoTswVnX5zspX3W8FTG5sd5yoH2w5TYM
355	355	{357}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuFkMUuViBff9qDWxoFNGRPJs8UyrvHsF6FLvYEChuhz9cFaQpU
356	356	{358,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuoM8yte3QC39VgCwgDpXj5KrfoW6ftFM3kxk4T4kQqRCgChCak
357	357	{359}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JusgeQuJGrftnsgEB3r8iMrucHYAGbxou1zFmHoP5F79ufefqgp
358	358	{360,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtc1SosPFrCqVtsCtv22NNKfs9ru8Ccu4f2mNotaCpdAb52Ev9D
359	359	{361}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtfe4bEio51pgM9EszGc2eqkvxpZJtTckVrj6CnUhFU2oByp5qh
360	360	{362,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju9r3xsoTdb4uoVABJeDCiUdci59RLN9ZqUH6E2ZDWhite3Xz9m
361	361	{363}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtxgQB8PuMn6u8vPboYgrTdU9jYcEmwAcpEgx5Y4VRcqf6DKutz
362	362	{364,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvCoKoGeP2LiYzHC342npQr3UGuHAL5rFTA5NDPtw3i6BZPSvo4
363	363	{365}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv4j6feFcZRyTzZr69JaiXtrpPJQ4U5ZA6QX7nDGhVoLnpHyp4o
364	364	{366,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuiNHEdEsTXiiruamJSGQD9tzbB7sMoR82WJs7UmXrjbYtBvcHH
365	365	{367}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtqVSN4GmGUfmysppAhF9jvZKBUYxBnkkjZwXK7Gvg7e9rKDtqf
366	366	{368,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvFG4xvmaXPMQQiRu4FLaGPuvPXFRnHsZCTVecdiHpzcBg4F9RD
367	367	{369}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuiM3zgvA4ReZA5xxFP2R7MhRtb41hp4c8jpq8coLiEzmcNLNNg
368	368	{370,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuCz1EvTRUovj2DSV4aV1D5SanosfG97VQ7n4tc1W8U3mTu6taC
369	369	{371}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv9z9ybJbccqz1E3uVkY6gHvVQuoZSJraFDzoVvwxpxTtLF7WEV
370	370	{372,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JttHSYQtSEaRXzPG67MXk53cNvPAqwdX3HPmSHMqjkYPSVF3CDU
371	371	{373}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuQzwCbjsEmBc8LwYqAiBH3wgjjYRbrFpZuwH431Xd84YyNevcn
372	372	{374,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuHL9kD7XUnq32Xy4ryKq1WUp47abmbCyi141ZwNDYatyTmEEvW
373	373	{375}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvBidpa66u9F5fCic6jWvWC5KHgypBTqD6He54Eme5LgtCJcK4e
374	374	{376,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtpoWkpaW4cNUXPLav9KnnKkihbkgWXYckqdsKJXJaB9zKDzQDZ
375	375	{377}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JufUWKQnpoQfnXkWh5NHzFong5DKHSKxVgFmMVHDmx5ngZXdzTL
376	376	{378,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvJJAJjSA9DuW6J3YiZ9DCaNGgeXmTp2r7PGixQzCP8G6ZH5TJy
377	377	{379}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtq2BNPef8fcjuhKjaUarAsYxaUU9RtabPJCHKf6GYtzuiQGi8f
378	378	{380,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtisGCDAU3mt18UbRBM4Pv4dWBK5TtRTrS4Nj6D4ReH7jV1iETY
379	379	{381}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju6KkeaWP8WsRqzLAure3rYyhgJNsU72F8aL3TUiRotiP538did
380	380	{382,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtvU78C56b5R6fxiwqbZPDfQ9BMv1MAuceyDmupMVQUFgBTmfNW
381	381	{383}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuHz3kX33cETxL2X47EXw8ePvDTGQq9EAD1z2xnV2gFRCRsLnfZ
382	382	{384,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtmUbeVzLtraJgVqWGs4yFF7KKRRLwW9fyuBswjH8taUEryBqPK
383	383	{385}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jum159PLFh3iHrE1nckuqhAKoXxJCYG8zJRGLWHA92t327C4u8T
384	384	{386,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuqcSDmq5RQnMAFVDuwZpVV5bA6s4m5fsQwgUVWVhq5ZSPyHUcq
385	385	{387}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvFcrrEez2mQfdveT4FKq1ThG1LxnLkDvC7q4zb9iVX7SGp27kA
386	386	{388,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuYfekyJNdQA9qRm3jt2c48v3ro6gTLbRukGGkKYNEhtmwxixij
387	387	{389}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jv8ZXte1ivTUdvMCQy1nXwv6nUavWdCpArQtgFsbujE95sQtEDT
388	388	{390,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtspxS7mTesYsrhroC6yNZvbEeiVkfid9K7MJXmaKpzR9EG9SFQ
389	389	{391}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtXZdRdccf9Acuadb2r6o8K3DTdekPTUrJseZezBdayigZ8V2RD
390	390	{392,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuH72kK96Fj2tP6dhzsYXi8JmmHAUg1K4weYnZxgtcaFkxdK1iS
391	391	{393}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuUxXxdxE1E9UtWw9KKEhaoSbY6cPvf5qJk9E8ETn4arszYvx5S
392	392	{394,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvRiBvesm3mYx2qGNkc7pVKggSbzpD4AyKVjZS7YgAx9EUenp44
393	393	{395}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuFLwZ32LdhePuhy91PbRmvv1zAF6gdKyrDjxi84icGDuztB1c1
394	394	{396,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JumkoEh1G5hqjiNh37vaZTKMFyEiMn245ThJRNXgNxCHkKqvfVb
395	395	{397}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuXU4aLR5qCJFVFcj3aaBvFZP89hpwHvqbyUWKyCbDJfcspbEfu
396	396	{398,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvPa7cLUkRPzh3pP3ffA2Btv1tnGff7n57bnVp1enLiGij7yiFZ
397	397	{399}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JvLRWw1urFgC5cmvFGRERJCkSCpHE7sQeL2Msaz99Cu38RnGdR5
398	398	{400,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuzRX2Eak5uXQnXbABfVj9rcJEV71ASrtcQxiRhr7L6RcdnNwHG
399	399	{401}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuFsYvkh93HqBVQDMpTh1CZiCN8su5TyiAjN1FLfkVDFR4a51Pr
400	400	{402,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JthPqzJA1TxJHk1sQjCnigtxC5DJDArP4YpDPrvn1MvyNfgBq5g
401	401	{403}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtppHBFhg4C4SsDLjBAxxs8H6Rjh3uCFdsKt1CPTxq2b5Yau7Ey
402	402	{404,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuEfpEyAwKRtq8YKfZWookeFeyMFoSrLux98NbmuUyDsQ1Xpzpp
403	403	{405}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuUpQ3nUM9G9SKDByJMWn87Nk19xQweSgkNVmz78g9KfpBPZ3zP
404	404	{406,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuBsy3gWiWvLjiBEycYHdYq7siwmS1mH9B2t2ZS6eJcab1qGpok
405	405	{407}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JtbAtpxTVVCf1HDrPknp31AhA89P1yN2GbEeq64NJMhAMHSeWWL
406	406	{408,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JujSdiRSK2Eb28kix51CLgt6Tkb83WmLSjLVWDeKZmYXjzcrQfB
407	407	{409}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju5cWZP4qWy9HsGC4o3dXJPDssaiYrmMAs7vTdDprULCv1ASPTY
408	408	{410,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Ju9nxLsUYzEda2Nsa7ZjwfjN6mtboK4g3CBXRzXRvrDre2SsS33
409	409	{411}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuZrqyx4d2EKX4Urop25cwa2q2z4Uh21CvCywje34jtwjMPUz8G
410	410	{412,4}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5Jtm8iqHN28ehiX8ESmZup816wo367qA8r2v7FyWaqJvJuPyqNUM
411	411	{413}	E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH	5JuKYu9iBs5h7V1WfRbK1k9e4UENBB9MeiNUYcPkGaHXK7ZjkTaE
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
1	25	5000000000	\N	0
2	25	5000000000	\N	1
3	25	5000000000	\N	2
4	25	5000000000	\N	3
5	25	5000000000	\N	4
6	25	5000000000	\N	5
7	25	5000000000	\N	6
8	25	5000000000	\N	7
9	25	5000000000	\N	8
10	25	5000000000	\N	9
11	25	5000000000	\N	10
12	25	5000000000	\N	11
13	25	5000000000	\N	12
14	25	5000000000	\N	13
15	25	5000000000	\N	14
16	25	5000000000	\N	15
17	25	5000000000	\N	16
18	25	5000000000	\N	17
19	25	5000000000	\N	18
20	25	5000000000	\N	19
21	25	5000000000	\N	20
22	25	5000000000	\N	21
23	25	5000000000	\N	22
24	25	5000000000	\N	23
25	25	5000000000	\N	24
26	25	5000000000	\N	25
27	25	5000000000	\N	26
28	25	5000000000	\N	27
29	25	5000000000	\N	28
30	25	5000000000	\N	29
31	25	5000000000	\N	30
32	25	5000000000	\N	31
33	25	5000000000	\N	32
34	25	5000000000	\N	33
35	25	5000000000	\N	34
36	25	5000000000	\N	35
37	25	5000000000	\N	36
38	25	5000000000	\N	37
39	25	5000000000	\N	38
40	25	5000000000	\N	39
41	25	5000000000	\N	40
42	25	5000000000	\N	41
43	25	5000000000	\N	42
44	25	5000000000	\N	43
45	25	5000000000	\N	44
46	25	5000000000	\N	45
47	25	5000000000	\N	46
48	25	5000000000	\N	47
49	25	5000000000	\N	48
50	25	5000000000	\N	49
51	25	5000000000	\N	50
52	25	5000000000	\N	51
53	25	5000000000	\N	52
54	25	5000000000	\N	53
55	25	5000000000	\N	54
56	25	5000000000	\N	55
57	25	5000000000	\N	56
58	25	5000000000	\N	57
59	25	5000000000	\N	58
60	25	5000000000	\N	59
61	25	5000000000	\N	60
62	25	5000000000	\N	61
63	25	5000000000	\N	62
64	25	5000000000	\N	63
65	25	5000000000	\N	64
66	25	5000000000	\N	65
67	25	5000000000	\N	66
68	25	5000000000	\N	67
69	25	5000000000	\N	68
70	25	5000000000	\N	69
71	25	5000000000	\N	70
72	25	5000000000	\N	71
73	25	5000000000	\N	72
74	25	5000000000	\N	73
75	25	5000000000	\N	74
76	25	5000000000	\N	75
77	25	5000000000	\N	76
78	25	5000000000	\N	77
79	25	5000000000	\N	78
80	25	5000000000	\N	79
81	25	5000000000	\N	80
82	25	5000000000	\N	81
83	25	5000000000	\N	82
84	25	5000000000	\N	83
85	25	5000000000	\N	84
86	25	5000000000	\N	85
87	25	5000000000	\N	86
88	25	5000000000	\N	87
89	25	5000000000	\N	88
90	25	5000000000	\N	89
91	25	5000000000	\N	90
92	25	5000000000	\N	91
93	25	5000000000	\N	92
94	25	5000000000	\N	93
95	25	5000000000	\N	94
96	25	5000000000	\N	95
97	25	5000000000	\N	96
98	25	5000000000	\N	97
99	25	5000000000	\N	98
100	25	5000000000	\N	99
101	25	5000000000	\N	100
102	25	5000000000	\N	101
103	25	5000000000	\N	102
104	25	5000000000	\N	103
105	25	5000000000	\N	104
106	25	5000000000	\N	105
107	25	5000000000	\N	106
108	25	5000000000	\N	107
109	25	5000000000	\N	108
110	25	5000000000	\N	109
111	25	5000000000	\N	110
112	25	5000000000	\N	111
113	25	5000000000	\N	112
114	25	5000000000	\N	113
115	25	5000000000	\N	114
116	25	5000000000	\N	115
117	25	5000000000	\N	116
118	25	5000000000	\N	117
119	25	5000000000	\N	118
120	25	5000000000	\N	119
121	25	5000000000	\N	120
122	25	5000000000	\N	121
123	25	5000000000	\N	122
124	25	5000000000	\N	123
125	25	5000000000	\N	124
126	25	5000000000	\N	125
127	25	5000000000	\N	126
128	25	5000000000	\N	127
129	25	5000000000	\N	128
130	25	5000000000	\N	129
131	25	5000000000	\N	130
132	25	5000000000	\N	131
133	25	5000000000	\N	132
134	25	5000000000	\N	133
135	25	5000000000	\N	134
136	25	5000000000	\N	135
137	25	5000000000	\N	136
138	25	5000000000	\N	137
139	25	5000000000	\N	138
140	25	5000000000	\N	139
141	25	5000000000	\N	140
142	25	5000000000	\N	141
143	25	5000000000	\N	142
144	25	5000000000	\N	143
145	25	5000000000	\N	144
146	25	5000000000	\N	145
147	25	5000000000	\N	146
148	25	5000000000	\N	147
149	25	5000000000	\N	148
150	25	5000000000	\N	149
151	25	5000000000	\N	150
152	25	5000000000	\N	151
153	25	5000000000	\N	152
154	25	5000000000	\N	153
155	25	5000000000	\N	154
156	25	5000000000	\N	155
157	25	5000000000	\N	156
158	25	5000000000	\N	157
159	25	5000000000	\N	158
160	25	5000000000	\N	159
161	25	5000000000	\N	160
162	25	5000000000	\N	161
163	25	5000000000	\N	162
164	25	5000000000	\N	163
165	25	5000000000	\N	164
166	25	5000000000	\N	165
167	25	5000000000	\N	166
168	25	5000000000	\N	167
169	25	5000000000	\N	168
170	25	5000000000	\N	169
171	25	5000000000	\N	170
172	25	5000000000	\N	171
173	25	5000000000	\N	172
174	25	5000000000	\N	173
175	25	5000000000	\N	174
176	25	5000000000	\N	175
177	25	5000000000	\N	176
178	25	5000000000	\N	177
179	25	5000000000	\N	178
180	25	5000000000	\N	179
181	25	5000000000	\N	180
182	25	5000000000	\N	181
183	25	5000000000	\N	182
184	25	5000000000	\N	183
185	25	5000000000	\N	184
186	25	5000000000	\N	185
187	25	5000000000	\N	186
188	25	5000000000	\N	187
189	25	5000000000	\N	188
190	25	5000000000	\N	189
191	25	5000000000	\N	190
192	25	5000000000	\N	191
193	25	5000000000	\N	192
194	25	5000000000	\N	193
195	25	5000000000	\N	194
196	25	5000000000	\N	195
197	25	5000000000	\N	196
198	25	5000000000	\N	197
199	25	5000000000	\N	198
200	25	5000000000	\N	199
201	25	5000000000	\N	200
202	25	5000000000	\N	201
203	25	5000000000	\N	202
204	25	5000000000	\N	203
205	25	5000000000	\N	204
206	25	5000000000	\N	205
207	25	5000000000	\N	206
208	25	5000000000	\N	207
209	25	5000000000	\N	208
210	25	5000000000	\N	209
211	25	5000000000	\N	210
212	25	5000000000	\N	211
213	25	5000000000	\N	212
214	25	5000000000	\N	213
215	25	5000000000	\N	214
216	25	5000000000	\N	215
217	25	5000000000	\N	216
218	25	5000000000	\N	217
219	25	5000000000	\N	218
220	25	5000000000	\N	219
221	25	5000000000	\N	220
222	25	5000000000	\N	221
223	25	5000000000	\N	222
224	25	5000000000	\N	223
225	25	5000000000	\N	224
226	25	5000000000	\N	225
227	25	5000000000	\N	226
228	25	5000000000	\N	227
229	25	5000000000	\N	228
230	25	5000000000	\N	229
231	25	5000000000	\N	230
232	25	5000000000	\N	231
233	25	5000000000	\N	232
234	25	5000000000	\N	233
235	25	5000000000	\N	234
236	25	5000000000	\N	235
237	25	5000000000	\N	236
238	25	5000000000	\N	237
239	25	5000000000	\N	238
240	25	5000000000	\N	239
241	25	5000000000	\N	240
242	25	5000000000	\N	241
243	25	5000000000	\N	242
244	25	5000000000	\N	243
245	25	5000000000	\N	244
246	25	5000000000	\N	245
247	25	5000000000	\N	246
248	25	5000000000	\N	247
249	25	5000000000	\N	248
250	25	5000000000	\N	249
251	25	5000000000	\N	250
252	25	5000000000	\N	251
253	25	5000000000	\N	252
254	25	5000000000	\N	253
255	25	5000000000	\N	254
256	25	5000000000	\N	255
257	25	5000000000	\N	256
258	25	5000000000	\N	257
259	25	5000000000	\N	258
260	25	5000000000	\N	259
261	25	5000000000	\N	260
262	25	5000000000	\N	261
263	25	5000000000	\N	262
264	25	5000000000	\N	263
265	25	5000000000	\N	264
266	25	5000000000	\N	265
267	25	5000000000	\N	266
268	25	5000000000	\N	267
269	25	5000000000	\N	268
270	25	5000000000	\N	269
271	25	5000000000	\N	270
272	25	5000000000	\N	271
273	25	5000000000	\N	272
274	25	5000000000	\N	273
275	25	5000000000	\N	274
276	25	5000000000	\N	275
277	25	5000000000	\N	276
278	25	5000000000	\N	277
279	25	5000000000	\N	278
280	25	5000000000	\N	279
281	25	5000000000	\N	280
282	25	5000000000	\N	281
283	25	5000000000	\N	282
284	25	5000000000	\N	283
285	25	5000000000	\N	284
286	25	5000000000	\N	285
287	25	5000000000	\N	286
288	25	5000000000	\N	287
289	25	5000000000	\N	288
290	25	5000000000	\N	289
291	25	5000000000	\N	290
292	25	5000000000	\N	291
293	25	5000000000	\N	292
294	25	5000000000	\N	293
295	25	5000000000	\N	294
296	25	5000000000	\N	295
297	25	5000000000	\N	296
298	25	5000000000	\N	297
299	25	5000000000	\N	298
300	25	5000000000	\N	299
301	25	5000000000	\N	300
302	25	5000000000	\N	301
303	25	5000000000	\N	302
304	25	5000000000	\N	303
305	25	5000000000	\N	304
306	25	5000000000	\N	305
307	25	5000000000	\N	306
308	25	5000000000	\N	307
309	25	5000000000	\N	308
310	25	5000000000	\N	309
311	25	5000000000	\N	310
312	25	5000000000	\N	311
313	25	5000000000	\N	312
314	25	5000000000	\N	313
315	25	5000000000	\N	314
316	25	5000000000	\N	315
317	25	5000000000	\N	316
318	25	5000000000	\N	317
319	25	5000000000	\N	318
320	25	5000000000	\N	319
321	25	5000000000	\N	320
322	25	5000000000	\N	321
323	25	5000000000	\N	322
324	25	5000000000	\N	323
325	25	5000000000	\N	324
326	25	5000000000	\N	325
327	25	5000000000	\N	326
328	25	5000000000	\N	327
329	25	5000000000	\N	328
330	25	5000000000	\N	329
331	25	5000000000	\N	330
332	25	5000000000	\N	331
333	25	5000000000	\N	332
334	25	5000000000	\N	333
335	25	5000000000	\N	334
336	25	5000000000	\N	335
337	25	5000000000	\N	336
338	25	5000000000	\N	337
339	25	5000000000	\N	338
340	25	5000000000	\N	339
341	25	5000000000	\N	340
342	25	5000000000	\N	341
343	25	5000000000	\N	342
344	25	5000000000	\N	343
345	25	5000000000	\N	344
346	25	5000000000	\N	345
347	25	5000000000	\N	346
348	25	5000000000	\N	347
349	25	5000000000	\N	348
350	25	5000000000	\N	349
351	25	5000000000	\N	350
352	25	5000000000	\N	351
353	25	5000000000	\N	352
354	25	5000000000	\N	353
355	25	5000000000	\N	354
356	25	5000000000	\N	355
357	25	5000000000	\N	356
358	25	5000000000	\N	357
359	25	5000000000	\N	358
360	25	5000000000	\N	359
361	25	5000000000	\N	360
362	25	5000000000	\N	361
363	25	5000000000	\N	362
364	25	5000000000	\N	363
365	25	5000000000	\N	364
366	25	5000000000	\N	365
367	25	5000000000	\N	366
368	25	5000000000	\N	367
369	25	5000000000	\N	368
370	25	5000000000	\N	369
371	25	5000000000	\N	370
372	25	5000000000	\N	371
373	25	5000000000	\N	372
374	25	5000000000	\N	373
375	25	5000000000	\N	374
376	25	5000000000	\N	375
377	25	5000000000	\N	376
378	25	5000000000	\N	377
379	25	5000000000	\N	378
380	25	5000000000	\N	379
381	25	5000000000	\N	380
382	25	5000000000	\N	381
383	25	5000000000	\N	382
384	25	5000000000	\N	383
385	25	5000000000	\N	384
386	25	5000000000	\N	385
387	25	5000000000	\N	386
388	25	5000000000	\N	387
389	25	5000000000	\N	388
390	25	5000000000	\N	389
391	25	5000000000	\N	390
392	25	5000000000	\N	391
393	25	5000000000	\N	392
394	25	5000000000	\N	393
395	25	5000000000	\N	394
396	25	5000000000	\N	395
397	25	5000000000	\N	396
398	25	5000000000	\N	397
399	25	5000000000	\N	398
400	25	5000000000	\N	399
401	25	5000000000	\N	400
402	25	5000000000	\N	401
403	25	5000000000	\N	402
404	25	5000000000	\N	403
405	25	5000000000	\N	404
406	25	5000000000	\N	405
407	25	5000000000	\N	406
408	25	5000000000	\N	407
409	25	5000000000	\N	408
410	25	5000000000	\N	409
411	25	5000000000	\N	410
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
205	204	\N	\N	\N	\N	\N	\N	\N
206	205	\N	\N	\N	\N	\N	\N	\N
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

SELECT pg_catalog.setval('public.blocks_id_seq', 24, true);


--
-- Name: epoch_data_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.epoch_data_id_seq', 25, true);


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

SELECT pg_catalog.setval('public.user_commands_id_seq', 256, true);


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

SELECT pg_catalog.setval('public.zkapp_account_precondition_id_seq', 207, true);


--
-- Name: zkapp_account_update_body_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_account_update_body_id_seq', 413, true);


--
-- Name: zkapp_account_update_failures_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_account_update_failures_id_seq', 4, true);


--
-- Name: zkapp_account_update_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_account_update_id_seq', 413, true);


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

SELECT pg_catalog.setval('public.zkapp_commands_id_seq', 411, true);


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

SELECT pg_catalog.setval('public.zkapp_fee_payer_body_id_seq', 411, true);


--
-- Name: zkapp_field_array_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_field_array_id_seq', 1, false);


--
-- Name: zkapp_field_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.zkapp_field_id_seq', 205, true);


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

SELECT pg_catalog.setval('public.zkapp_nonce_bounds_id_seq', 206, true);


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

SELECT pg_catalog.setval('public.zkapp_states_nullable_id_seq', 206, true);


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

SELECT pg_catalog.setval('public.zkapp_updates_id_seq', 207, true);


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

